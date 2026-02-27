// ------------------------------------------------------------------------------
// 
// Copyright 2002 - 2020 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// 
// Component Name   : DWC_pcie_ctl
// Component Version: 5.90a
// Release Type     : GA
// ------------------------------------------------------------------------------

// -------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2020/09/11 01:49:10 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc/DW_sbc.sv#3 $
// -------------------------------------------------------------------------
/*
 --
 -- Description  : S - SEGMENTED : B - BUFFER : C - CONTROLLER
 --                The purpose of this module is to allow a single RAM
 --                to be used for multiple buffers.
 --                The RAM may be split into any number of segments -
 --                where each segment is a different buffer/fifo.
 --                For packet based data it supports the termination
 --                of received packets (via a keep signal) and a
 --                predictive read that does not affect the buffer
 --                pointer (via a look signal)
 --
 -- Modification History:
 -- Date                 By      Version Change  Description
 -- =====================================================================
 -- See CVS log
 -- =====================================================================
 */

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DW_sbc
   (
    clk,
    rst_n,
    srst_n,

    // Push side
    sb_push_i,
    sb_push_start_i,
    sb_push_keep_i,
    sb_push_drop_i,
    sb_push_seg_i,
    sb_push_data_i,
    sb_reset_push_ptr,
    sb_reset_push_seg_i,

    // Pop side
    sb_pop_i,
    sb_pop_seg_i,
    sb_pop_look_i,
    sb_pop_data_o,
    sb_reset_pop_ptr,
    sb_reset_pop_seg_i,

    // Segment size interface
    sb_init_i,
    sb_init_seg_sizes_i,
    sb_init_done_o,
    sb_init_num_segs_i,

    sb_seg_start_i,
    sb_seg_end_i,

    // Info interface
    sb_empty_o,
    sb_empty_p_1_o,
    sb_full_o,
    sb_full_m_1_o,
    sb_full_m_2_o,
    sb_seg_pkt_avail_o,

    // Memory interface
    sb_waddr_o,
    sb_wen_n_o,
    sb_wdata_o,
    sb_raddr_o,
    sb_ren_n_o,
    sb_par_chk_val_o,
    sb_rdata_i

    );

//----------------------------------------------------------------------
// PARAMETERS.
//----------------------------------------------------------------------
parameter SEGS = 5;                             // Number of segments
parameter SEG_W = 3;                            // Width of segment register
parameter RAM_W = 64;                           // RAM data width
parameter RAM_WEC = 64;                         // RAM w/ECC data width
parameter RAM_AW = 8;                           // RAM address width

parameter GEN_STARTEND_ADDRS = 1;               // Controls wether this module
                                                // will generate start/end
                                                // addresses from the segment
                                                // size inputs or use the
                                                // segment start end address
                                                // inputs directly.

parameter HOLD_RADDR = 1;                       // 0 => Read address to memory will
                                                //      increment after pop access.
                                                // 1 => Read address to memory will
                                                //      not change until another pop
                                                //      access.
                                                // The read address has to be
                                                // registered to hold it until the
                                                // pop access, so setting this
                                                // parameter to 1 has an area cost of
                                                // RAM_AW flops + RAM_AW 2*1 mux.

parameter NHQ = `CX_NHQ;                        // Number of Header Queues per VC
parameter GEN_FULL_M_2 = 1;                     // Control whether full minus 2 logic is instantiated.

parameter SEG_SIZES_W = SEGS * RAM_AW;          // Width of number of segments
                                                // times RAM address width.
parameter TP                        = `TP;                      // Clock to Q delay (simulator insurance)

`define SBC_INSTANTIATE_BOUND_INIT              // If this is defined the the boundary initialisation will be instantiated.
                                                // Remove this macro to get synthesis to remove the block.

input                             clk;                          // System clock
input                             rst_n;                        // System reset
input                             srst_n;                       // Synchronous reset
input                             sb_push_i;                    // Asserted to initiate a push access.
input                             sb_push_start_i;              // Asserted for first cycle of packet.  If asserted without end or keep for previous packet, discard previous packet.
input                             sb_push_keep_i;               // Asserted along with sb_push_i if packet is good.
input                             sb_push_drop_i;               // Asserted without sb_push_i to clear unkept data.
input [SEG_W-1:0]                 sb_push_seg_i;                // Segment to push into
input [RAM_W-1:0]                 sb_push_data_i;               // Write data for push accesses.
input                             sb_reset_push_ptr;            // pulse to perform reset
input [SEG_W-1:0]                 sb_reset_push_seg_i;          // Segment to reset

input                             sb_pop_i;                     // Asserted to initiate a pop access.
input [SEG_W-1:0]                 sb_pop_seg_i;                 // Segment to pop from.
input                             sb_pop_look_i;                // If asserted at the same time as "POP", don't increment the buffer pointer .
output [RAM_WEC-1:0]              sb_pop_data_o;                // Valid 1 cycle after sb_pop_i asserted.
input                             sb_reset_pop_ptr;             // pulse to perform reset
input [SEG_W-1:0]                 sb_reset_pop_seg_i;           // Segment to reset


input                             sb_init_i;                    // Pulsed when initialization for segment pointers needs to occur
input [SEG_SIZES_W-1:0]           sb_init_seg_sizes_i;          // List of sizes for each segment: [RAM_AW-1:0] = Segment 0 ; [2*RAM_AW-1:RAM_AW] = Segment 1 ...

output                            sb_init_done_o;               // Asserted when boundary initialisation is finished. Set to 0 on reset and rising edge of sb_init_i

input [SEG_SIZES_W-1:0]           sb_seg_start_i;               // Segments start addresses.
input [SEG_SIZES_W-1:0]           sb_seg_end_i;                 // Segments end addresses.
input [SEG_W :0]                  sb_init_num_segs_i;           // Number of segments. Allows number of segments to be dynamicaly reduced.

output [SEGS-1:0]                 sb_empty_o;                   // Segment is empty.
output [SEGS-1:0]                 sb_empty_p_1_o;               // Segment is 1 away from empty.
output [SEGS-1:0]                 sb_full_o;                    // Segment is full.
output [SEGS-1:0]                 sb_full_m_1_o;                // Segment has 1 entry left.
output [SEGS-1:0]                 sb_full_m_2_o;                // Segment has 2 entries left.
output [SEGS-1:0]                 sb_seg_pkt_avail_o;           // Segment has at least part of a "kept" packet available.
output [RAM_AW-1:0]               sb_waddr_o;                   // Write address to memory.
output                            sb_wen_n_o;                   // Write enable to memory.
output [RAM_W-1:0]                sb_wdata_o;                   // Write data to memory.
output [RAM_AW-1:0]               sb_raddr_o;                   // Read address to memory.
output                            sb_ren_n_o;                   // Read enable to memory.
output [NHQ-1:0]                  sb_par_chk_val_o;             // Parity Check enable to memory
input [RAM_WEC-1:0]               sb_rdata_i;                   // Read data from memory.



wire                              sb_init_done_int_o;           // "done" signal from boundary
                                                                // initialisation module, connected to
                                                                // "done" output port if
                                                                // GEN_STARTEND_ADDRS == 1.

wire                              sb_init_done_red_int_o;       // "done" rising edge detect signal from
                                                                // boundary initialisation module.
                                                                // Connected to input of push and pop
                                                                // side modules if
                                                                // GEN_STARTEND_ADDRS == 1.

reg                               sb_init_done_o;               // Asserted when boundary initialisation is
                                                                // finished. Set to 0 on reset and rising edge of sb_init_i

reg                               sb_init_done_red_o;           // Module interconnect for boundary init.
                                                                // done rising edge detect signal.

wire                              push_seg_wrap_o;              // Pulsed when current push segment (write pointer) wraps around.
wire                              pop_seg_wrap_o;               // Pulsed when current pop segment (read pointer) wraps around.
                                                                // pointer control connection wires
reg [RAM_AW-1:0]                  rptrs_dout_i [SEGS-1:0];
reg [SEGS-1:0]                    rptrs_dout_i_eq_end;

reg [RAM_AW-1:0]                  wptrs_dout_i [SEGS-1:0];
reg [SEGS-1:0]                    wptrs_dout_i_eq_end;



reg [RAM_AW-1:0]                  start_addr   [SEGS-1:0];      // start_addr of seg 0 is tied to all 0s
reg [RAM_AW-1:0]                  end_addr_m1  [SEGS-1:0];

wire   [SEG_W-1:0]                 push_seg_i;                  // Segment to push into
wire   [SEG_W-1:0]                 pop_seg_i;                   // Segment to pop from.

wire [RAM_AW-1:0]                 pop_next_addr_c;
reg [RAM_AW-1:0]                  push_next_addr_c;

wire [SEG_W-1:0]                  sb_init_fsm_seg_num_d1;
wire [RAM_AW-1:0]                 add_result_r;                 // Result from the adder in DW_sbc_bound_init.

reg [SEGS-1:0]                    empty_e;
reg [SEGS-1:0]                    empty_p_1_e;
reg [SEGS-1:0]                    full_e;
reg [SEGS-1:0]                    full_m_1_e;
logic [SEGS-1:0]                  full_m_2_e;
reg [SEGS-1:0]                 seg_pkt_avail_e;

wire                           drop_at_pop_seg;
wire                           push_at_pop_seg;
wire                           pop_at_push_seg;

reg [RAM_AW:0]                 elements      [SEGS-1:0];
reg [RAM_AW:0]                 unkept;

reg [RAM_AW-1:0]               seg_size_m2   [SEGS-1:0];        // this should really be just a wire connection
reg [RAM_AW-1:0]               seg_size_m3   [SEGS-1:0];        // this should really be just a wire connection
reg [RAM_AW:0]                 curr_elements;
reg [SEG_W-1:0]                curr_seg;
reg                            curr_seg_valid;

wire                           pop_look_jstfd_c;                        // "look" signal justified by sb_pop_i.
wire                           pop_seg_empty_c;                                 // Asserted if the current pop segment is empty.
wire                           incr_pop_addr_c;                 // Asserted to increment the pop address.
wire [RAM_AW-1:0]              pop_current_addr_c;              // Incremented version of current pop address.
reg [RAM_AW-1:0]               pop_crnt_addr_hold_r;            // Register to hold the most recent pop address.
wire [RAM_AW-1:0]              pop_crnt_addr_held_c;            // Mux output between current pop address and hold current pop addr reg.

wire                           push_start_jstfd_c;              // start signal justified with push signal.
wire                           push_keep_jstfd_c;               // keep signal justified with push signal.
wire [RAM_AW-1:0]              push_current_addr_c;             // Current push addr to the RAM.
wire                           current_push_seg_end;            // Asserted when current push address is at the end of the segment.
wire [RAM_AW-1:0]              push_seg_start_addr;             // Start address of current push segment.
wire [RAM_AW-1:0]              push_seg_end_addr_m1;         // End address of current push segment.
reg                            push_working_addr_r_eq_end;

reg [RAM_AW-1:0]               push_working_addr_r;             // The "working address for push accesses, gets loaded into the current push segment's
// write pointer register when "keep" is asserted.
wire [RAM_AW:0]                working_elements;
wire [RAM_AW:0]                working_seg_size_m3;
wire [RAM_AW:0]                working_elements_pop;
wire [RAM_AW:0]                next_elements_push_seg;
wire                           update_elements_push_seg;
wire [RAM_AW:0]                next_curr_elements;

wire                           update_curr_elements;
wire                           update_elements_pop_seg;

reg                            pop_to_empty_p_1;
reg                            drop_to_empty_p_1_w_pop;
reg                            drop_to_empty_p_1;
reg                            push_from_empty_2_empty_p_1;
reg                            pop_to_empty_2_empty_p_1;
reg                            drop_to_empty_2_empty_p_1;
reg                            push_from_empty_p_1;


wire                           pop_from_full_2_full_m_1;
wire                           drop_from_full_2_full_m_1;
wire                           push_to_full_m_1;
wire                           drop_from_full_m_1;
wire                           pop_from_full_m_1;
wire                           push_from_full_m_1;

wire                           pop_from_full_m_1_2_full_m_2;
wire                           drop_from_full_2_full_m_2;
wire                           drop_from_full_m_1_2_full_m_2;
wire                           push_to_full_m_2;
wire                           drop_from_full_m_2;
wire                           pop_from_full_m_2;
wire                           push_from_full_m_2;

wire                           pop_to_empty;
wire                           drop_to_empty;
wire                           drop_to_empty_w_pop;

wire                           push_to_full;
wire                           pop_from_full;

wire                           load_curr_element_p_1;
wire                           load_curr_elements;
wire                           incr_elements;
wire                           sb_init_save_result_sa;
wire                           sb_init_save_result_ea;

//----------------------------------------------------------------------
// Instantiate the boundary initialisation module.
//----------------------------------------------------------------------
DW_sbc_bound_init

    #(SEGS,
      SEG_W,
      RAM_AW
      )
        u_DW_sbc_bound_init
   (
    .clk                        (clk),
    .rst_n                      (rst_n),
    .srst_n                     (srst_n),

    // Segment size interface
    .sb_init_i                  (sb_init_i),
    .sb_init_seg_sizes_i        (sb_init_seg_sizes_i),
    .sb_init_num_segs_i         (sb_init_num_segs_i),

    .sb_init_done_o             (sb_init_done_int_o),
    .sb_init_done_red_o         (sb_init_done_red_int_o),
    .sb_init_save_result_sa     (sb_init_save_result_sa),
    .sb_init_save_result_ea     (sb_init_save_result_ea),
    .sb_init_fsm_seg_num_d1     (sb_init_fsm_seg_num_d1),

    .add_result_r               (add_result_r)

    );

//----------------------------------------------------------------------
// Only use the outputs from DW_sbc_bound_init if internaly generated
// start & end addresses are being used.
//----------------------------------------------------------------------

// Register these signals to help with timing
always @(posedge clk or negedge rst_n)
begin : init_done_reg_PROC
    if(rst_n == 1'b0) begin
        sb_init_done_o        <= #TP 1'b0;
        sb_init_done_red_o    <= #TP 1'b0;
    end else if (srst_n == 1'b0) begin
        sb_init_done_o        <= #TP 1'b0;
        sb_init_done_red_o    <= #TP 1'b0;
    end else begin
        sb_init_done_o        <= #TP (GEN_STARTEND_ADDRS == 1) ? sb_init_done_int_o    : 1'b0;
        sb_init_done_red_o    <= #TP (GEN_STARTEND_ADDRS == 1) ? sb_init_done_red_int_o: 1'b0;
    end
end // init_done_reg_PROC

assign drop_at_pop_seg = sb_push_drop_i && (sb_push_seg_i == sb_pop_seg_i);
assign push_at_pop_seg = sb_push_i && (sb_push_seg_i == sb_pop_seg_i);
assign pop_at_push_seg = sb_pop_i && (sb_push_seg_i == sb_pop_seg_i);

//----------------------------------------------------------------------
// POP LOGIC, formerly in DW_sbc_pop_side.v
//----------------------------------------------------------------------
assign pop_look_jstfd_c   = sb_pop_look_i & sb_pop_i;  // Justified versions of this signal by anding with sb_push_i.
assign pop_seg_empty_c    = empty_e[sb_pop_seg_i];

// This signal tells us when to increment the current pop address.
// If "pop" is asserted and neither "look" nor pop_seg_empty_c are asserted.
assign incr_pop_addr_c    = sb_pop_i & !pop_look_jstfd_c  & !pop_seg_empty_c;
assign pop_seg_wrap_o     = rptrs_dout_i_eq_end[sb_pop_seg_i]  & incr_pop_addr_c;
assign pop_next_addr_c    = pop_seg_wrap_o ? start_addr[sb_pop_seg_i] : rptrs_dout_i[sb_pop_seg_i]  + 1'b1;

assign pop_current_addr_c = rptrs_dout_i[sb_pop_seg_i];

   reg sb_pop_i_d;
   always @(posedge clk or negedge rst_n)
   begin : sb_pop_i_register
      if (!rst_n) begin
        sb_pop_i_d    <= #TP 0;
      end else begin
        sb_pop_i_d    <= #TP sb_pop_i;
      end
   end

   assign sb_par_chk_val_o = {{(NHQ-1){1'b0}}, sb_pop_i_d};

//----------------------------------------------------------------------
// This register holds the most recent pop address.
// We use this so that we hold the current pop address on the read
// data output until sb_pop_i is asserted again.
//----------------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin : pop_crnt_addr_hold_r_PROC
   if(rst_n == 1'b0)
     pop_crnt_addr_hold_r <= #TP {RAM_AW{1'b0}};
   else if (srst_n == 1'b0)
     pop_crnt_addr_hold_r <= #TP {RAM_AW{1'b0}};
   else if(sb_pop_i)
     pop_crnt_addr_hold_r <= #TP pop_current_addr_c;
end // pop_crnt_addr_hold_r_PROC

// Here we mux between the current pop address hold register and the
// current pop address. If sb_pop_i is asserted we use the current pop
// address, at all other times we use the current pop address hold register.
assign pop_crnt_addr_held_c = sb_pop_i   ? pop_current_addr_c   : pop_crnt_addr_hold_r;

assign sb_raddr_o           = HOLD_RADDR ? pop_crnt_addr_held_c : pop_current_addr_c;
assign sb_ren_n_o           = !sb_pop_i;
assign sb_pop_data_o        = sb_rdata_i;

//----------------------------------------------------------------------
// PUSH LOGIC,  formerly in DW_sbc_push_side.v
//----------------------------------------------------------------------
assign push_start_jstfd_c   = sb_push_start_i & sb_push_i;  // Justified versions of these signals by "anding" with sb_push_i.
assign push_keep_jstfd_c    = sb_push_keep_i  & sb_push_i;

// For the start of a packet push  - when "start & push" are asserted we use the address stored in the push segments write pointer register.
// For all pushes after this we use the working address register.
// Except if drop is asserted, then we reload the working pointer from the push segments write pointer register.
assign push_current_addr_c  = (push_start_jstfd_c | sb_push_drop_i) ? wptrs_dout_i[sb_push_seg_i]        : push_working_addr_r;
assign current_push_seg_end = (push_start_jstfd_c | sb_push_drop_i) ? wptrs_dout_i_eq_end[sb_push_seg_i] : push_working_addr_r_eq_end;
assign push_seg_wrap_o      = current_push_seg_end & sb_push_i;
assign push_seg_start_addr  = start_addr[sb_push_seg_i];
assign push_seg_end_addr_m1 = end_addr_m1[sb_push_seg_i];

always @(/*AUTOSENSE*/push_current_addr_c or push_seg_start_addr
                 or push_seg_wrap_o or sb_push_i)
begin : push_next_addr_PROC
   if(push_seg_wrap_o) begin
      push_next_addr_c = push_seg_start_addr;
   end else if(sb_push_i) begin
      push_next_addr_c = push_current_addr_c + 1'b1;
   end else begin
      push_next_addr_c = push_current_addr_c;
   end
end // push_next_addr_PROC

always @(posedge clk or negedge rst_n)
begin : push_working_addr_PROC                   // Working address register logic.
    if(rst_n == 1'b0) begin                      // This register stores the address of the current push access, for all
        push_working_addr_r <= #TP {RAM_AW{1'b0}};   // but the first push of a packet i.e. when "start" is asserted.
    end else if (srst_n == 1'b0) begin
       push_working_addr_r <= #TP {RAM_AW{1'b0}};
    end else begin                               // When keep is asserted the value on this register gets loaded into
        push_working_addr_r <= #TP push_next_addr_c; // the segment write pointer register of the current push segment.
    end                                          // If the current push segment has it's pointers reset we
end                                              // load in the current push segments start address.

always @(posedge clk or negedge rst_n)
begin : push_working_addr_eq_end_PROC
    if(rst_n == 1'b0) begin
        push_working_addr_r_eq_end <= #TP 1'b0;
    end else if (srst_n == 1'b0) begin
       push_working_addr_r_eq_end <= #TP 1'b0;
    end else if (sb_push_i) begin
        push_working_addr_r_eq_end <= #TP (push_current_addr_c==push_seg_end_addr_m1);
    end
end

assign sb_wdata_o = sb_push_data_i;
assign sb_wen_n_o = ~sb_push_i;
assign sb_waddr_o = push_current_addr_c;

//----------------------------------------------------------------------
// Pointer storage and control
//----------------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin: SegBoundary_storage_start
integer seg_num;
   if (rst_n == 1'b0) begin
      start_addr[0] <= #TP {RAM_AW{1'b0}};
      for(seg_num=1 ; seg_num<SEGS ; seg_num=seg_num+1) begin
         start_addr[seg_num]  <= #TP {RAM_AW{1'b0}};
      end
   end else if (srst_n == 1'b0) begin
      start_addr[0] <= #TP {RAM_AW{1'b0}};
      for(seg_num=1 ; seg_num<SEGS ; seg_num=seg_num+1) begin
         start_addr[seg_num]  <= #TP {RAM_AW{1'b0}};
      end
   end else if (sb_init_save_result_sa) begin
        start_addr[sb_init_fsm_seg_num_d1]  <= #TP add_result_r;
   end
end

always @(posedge clk or negedge rst_n)
begin: SegBoundary_storage_end
integer seg_num;
   if (rst_n == 1'b0) begin
      for(seg_num=0 ; seg_num<SEGS ; seg_num=seg_num+1) begin
         end_addr_m1[seg_num] <= #TP {RAM_AW{1'b0}};
      end
   end else if (srst_n == 1'b0) begin
      for(seg_num=0 ; seg_num<SEGS ; seg_num=seg_num+1) begin
         end_addr_m1[seg_num] <= #TP {RAM_AW{1'b0}};
      end
   end else if (  sb_init_save_result_ea
                & (sb_init_fsm_seg_num_d1!=0)) begin
      end_addr_m1[sb_init_fsm_seg_num_d1] <= #TP add_result_r - 1;
   end else if (sb_init_i) begin
      end_addr_m1[0]   <= #TP sb_init_seg_sizes_i[RAM_AW-1:0] - 1;
   end
end

assign push_seg_i = (sb_reset_push_ptr                              ? sb_reset_push_seg_i    :
                     sb_init_save_result_sa                         ? sb_init_fsm_seg_num_d1 :
                     (!sb_reset_push_ptr & !sb_init_save_result_sa) ? sb_push_seg_i          :{SEG_W{1'b0}} );

assign pop_seg_i  = (sb_reset_pop_ptr                               ? sb_reset_pop_seg_i     :
                     sb_init_save_result_sa                         ? sb_init_fsm_seg_num_d1 :
                     (!sb_reset_pop_ptr & !sb_init_save_result_sa)  ? sb_pop_seg_i           :{SEG_W{1'b0}} );

always @(posedge clk or negedge rst_n)
begin: Ptr_storage
integer seg_num;
    if (rst_n == 1'b0) begin  // CAN WE eliminate the async RESET?  YES, but LEDA might complain.
       for(seg_num=0 ; seg_num<SEGS ; seg_num=seg_num+1) begin
          rptrs_dout_i[seg_num] <= #TP 'd0;
          wptrs_dout_i[seg_num] <= #TP 'd0;
       end
       rptrs_dout_i_eq_end <= #TP 'd0;
       wptrs_dout_i_eq_end <= #TP 'd0;
    end else if (srst_n == 1'b0) begin
       for(seg_num=0 ; seg_num<SEGS ; seg_num=seg_num+1) begin
          rptrs_dout_i[seg_num] <= #TP 'd0;
          wptrs_dout_i[seg_num] <= #TP 'd0;
       end
       rptrs_dout_i_eq_end <= #TP 'd0;
       wptrs_dout_i_eq_end <= #TP 'd0;
    end else begin
       if (sb_pop_i               |
           sb_reset_pop_ptr       |
           sb_init_save_result_sa  )


         // Give highest priority to sb_reset_pop_ptr. Enables next pop pointer to be reset while popping from
         // current pop pointer.
         rptrs_dout_i[pop_seg_i]   <= #TP ( sb_reset_pop_ptr           ? start_addr[pop_seg_i]  :
                                            sb_pop_i                   ? pop_next_addr_c        :
                                            sb_init_save_result_sa     ? add_result_r           : {RAM_AW{1'b0}} );

       if (sb_push_keep_i & sb_push_i |
           sb_reset_push_ptr          |
           sb_init_save_result_sa      )

         // Give highest priority to sb_reset_push_ptr. Enables next push pointer to be reset while pushing to
         // current write pointer.
         wptrs_dout_i[push_seg_i]  <= #TP ( sb_reset_push_ptr          ? start_addr[push_seg_i] :
                                            sb_push_keep_i & sb_push_i ? push_next_addr_c       :
                                            sb_init_save_result_sa     ? add_result_r           : {RAM_AW{1'b0}} );

       if (sb_pop_i | sb_reset_pop_ptr)
         rptrs_dout_i_eq_end[pop_seg_i]  <= #TP sb_reset_pop_ptr ? 1'b0 :((rptrs_dout_i[sb_pop_seg_i])==end_addr_m1[sb_pop_seg_i]);

       if (sb_push_keep_i & sb_push_i | sb_reset_push_ptr)
         wptrs_dout_i_eq_end[push_seg_i] <= #TP sb_reset_push_ptr ? 1'b0 : (push_current_addr_c==end_addr_m1[sb_push_seg_i]);
    end
end

//----------------------------------------------------------------------
// FIFO Element Tracking
//----------------------------------------------------------------------
// In this method of implementing full, full_m_1, empty and empty_p_1 we track the number of elements in the fifo, stored in a memory
// NOTE: elements needs to be one bit wider because 0=empty, so if RAM_AW=3, than the max num of elements is 8, not 7

//----------------------------------------------------------------------
// Empty detection
//----------------------------------------------------------------------
assign pop_to_empty             = sb_pop_i & !push_at_pop_seg & empty_p_1_e[sb_pop_seg_i] /*& !drop_at_pop_seg*/;
assign drop_to_empty            = (0 == elements[sb_push_seg_i]) &  sb_push_drop_i; // unkept not required  since elements retain's only kept push'es
assign drop_to_empty_w_pop      = (1 == elements[sb_push_seg_i]) &  sb_push_drop_i & pop_at_push_seg;  // unkept not required  since elements retain's only kept push'es

always @(posedge clk or negedge rst_n)
begin: EmptyElements
   if (rst_n == 1'b0)
     empty_e                   <= #TP {SEGS{1'b1}}; // we are empty upon reset
   else if (srst_n == 1'b0)
     empty_e                   <= #TP {SEGS{1'b1}};
   else begin
      /*  if we are doing a push to a segment then we won't be empty in the next clock */
      if (sb_push_i /* & ~pop_at_push_seg */)
        empty_e[sb_push_seg_i] <= #TP 1'b0;        // clear empty @ push segment

      if (pop_to_empty)
        empty_e[sb_pop_seg_i]  <= #TP 1'b1;        // set empty @ pop segment

      if (drop_to_empty || drop_to_empty_w_pop)
        empty_e[sb_push_seg_i] <= #TP 1'b1;        // set empty @ push segment
   end
end

//----------------------------------------------------------------------
// empty_p_1 detection
//----------------------------------------------------------------------

assign working_elements_pop = (curr_seg_valid & (curr_seg==sb_pop_seg_i)) ? curr_elements : elements[sb_pop_seg_i];

always@(*) pop_to_empty_p_1                 = (working_elements_pop==2) & sb_pop_i & !push_at_pop_seg & !drop_at_pop_seg;
always@(*) drop_to_empty_p_1_w_pop          = (2==elements[sb_push_seg_i]) &  sb_push_drop_i /* & !sb_push_i*/ &  pop_at_push_seg; // unkept not required  since elements retain's only kept push'es
always@(*) drop_to_empty_p_1                = (1==elements[sb_push_seg_i]) &  sb_push_drop_i /* & !sb_push_i*/ & !pop_at_push_seg; // unkept not required  since elements retain's only kept push'es
always@(*) push_from_empty_2_empty_p_1      = empty_e[sb_push_seg_i]  & sb_push_i  & !pop_at_push_seg;
always@(*) pop_to_empty_2_empty_p_1         = empty_p_1_e[sb_pop_seg_i]  & sb_pop_i & !push_at_pop_seg;
always@(*) drop_to_empty_2_empty_p_1        = empty_p_1_e[sb_push_seg_i]  & sb_push_drop_i;
always@(*) push_from_empty_p_1              = empty_p_1_e[sb_push_seg_i]  & sb_push_i  & !pop_at_push_seg;

always @(posedge clk or negedge rst_n)
begin: Empty_P1_Elements
    if (rst_n == 1'b0)
        empty_p_1_e                     <= #TP {SEGS{1'b0}};
    else if (srst_n == 1'b0)
        empty_p_1_e                     <= #TP {SEGS{1'b0}};
    else begin
        if (push_from_empty_p_1 || drop_to_empty_2_empty_p_1)
            empty_p_1_e[sb_push_seg_i]  <= #TP 1'b0;        // clear empty_p_1 @ push segment

        if (pop_to_empty_2_empty_p_1)
            empty_p_1_e[sb_pop_seg_i]   <= #TP 1'b0;        // clear empty_p_1 @ pop segment


        if (push_from_empty_2_empty_p_1 || drop_to_empty_p_1 || drop_to_empty_p_1_w_pop)
            empty_p_1_e[sb_push_seg_i]  <= #TP 1'b1;        // set empty_p_1   @ push segment

        if (pop_to_empty_p_1)
            empty_p_1_e[sb_pop_seg_i]   <= #TP 1'b1;        // set empty_p_1   @ pop segment
    end
end


//----------------------------------------------------------------------
// full detection
//----------------------------------------------------------------------
//assign push_to_full   = sb_push_i & ~pop_at_push_seg & full_m_1_e[sb_push_seg_i];
assign push_to_full   = sb_push_i & ~pop_at_push_seg & (working_elements==(seg_size_m2[sb_push_seg_i]+1));
assign pop_from_full  = /*full_e[sb_pop_seg] &*/ sb_pop_i & ~push_at_pop_seg;

always @(posedge clk or negedge rst_n)
begin: FullElements
    if (rst_n == 1'b0)
        full_e     <= #TP 'd0;
    else if (srst_n == 1'b0)
        full_e     <= #TP 'd0;
    else begin
        if (push_to_full)
            full_e[sb_push_seg_i] <= #TP 1'b1;      // set full @ push segement // ccx_line: u_axi_bridge.u_ib.u_mcb.u_sbc,u_axi_bridge.u_ob.u_cmp.u_ctl.u_data_DW_sbc; REDUNDANT: Segmented buffer segments are sized to take the maximum request size plus two positions so full and full-1 conditions never occur.

        if (/*full_e[sb_push_seg] & */ sb_push_drop_i)
            full_e[sb_push_seg_i] <= #TP 1'b0;      // clear full @ push segment

        if (pop_from_full)
            full_e[sb_pop_seg_i]  <= #TP 1'b0;      // clear full @ pop segment
    end
end

//----------------------------------------------------------------------
// full_m_1 detection
//----------------------------------------------------------------------
always @(sb_init_seg_sizes_i)
begin: Slice_SEG_SIZE_M2
integer i, j;
reg [RAM_AW-1:0] seg_size_slice;
    for (i=0; i<SEGS; i=i+1) begin
        for(j=0 ; j<RAM_AW ; j=j+1) begin
            seg_size_slice[j] = sb_init_seg_sizes_i[(i*RAM_AW)+j];
        end
        seg_size_m2[i] = seg_size_slice - 1; // do the math here against this incomming constant;
    end
end


assign working_elements          = sb_push_start_i ? elements[sb_push_seg_i]    : curr_elements;
assign pop_from_full_2_full_m_1  = full_e[sb_pop_seg_i] & sb_pop_i & ~push_at_pop_seg & ~drop_at_pop_seg;
assign drop_from_full_2_full_m_1 = full_e[sb_push_seg_i] & sb_push_drop_i & (unkept==1) & ~pop_at_push_seg;
assign push_to_full_m_1          = sb_push_i & (working_elements[RAM_AW-1:0]==seg_size_m2[sb_push_seg_i]) & ~pop_at_push_seg;
assign drop_from_full_m_1        = full_m_1_e[sb_push_seg_i] & sb_push_drop_i;
assign pop_from_full_m_1         = full_m_1_e[sb_pop_seg_i] & sb_pop_i & ~push_at_pop_seg;
assign push_from_full_m_1        = full_m_1_e[sb_push_seg_i] & sb_push_i & ~pop_at_push_seg;

always @(posedge clk or negedge rst_n)
begin: Full_M1_Elements
    if (rst_n == 1'b0)
        full_m_1_e     <= #TP {SEGS{1'b0}};
    else if (srst_n == 1'b0)
        full_m_1_e     <= #TP {SEGS{1'b0}};
    else begin

        if (pop_from_full_m_1)
            full_m_1_e[sb_pop_seg_i] <= #TP 1'b0;   // clear full_m_1 @ pop_segment // ccx_line: u_axi_bridge.u_ob.u_cmp.u_ctl.u_data_DW_sbc; REDUNDANT: Segmented buffer segments are sized to take the maximum request size plus two positions so full and full-1 conditions never occur.

        if (drop_from_full_m_1 | push_from_full_m_1)
            full_m_1_e[sb_push_seg_i]  <= #TP 1'b0; // clear full_m_1 @ push segment // ccx_line: u_axi_bridge.u_ib.u_mcb.u_sbc; REDUNDANT: Segmented buffer segments are sized to take the maximum request size plus two positions so full and full-1 conditions never occur.

        if (pop_from_full_2_full_m_1)
            full_m_1_e[sb_pop_seg_i]  <= #TP 1'b1;  // set full_m_1 @ pop segment // ccx_line: u_axi_bridge.u_ib.u_mcb.u_sbc,u_axi_bridge.u_ob.u_cmp.u_ctl.u_data_DW_sbc; REDUNDANT: Segmented buffer segments are sized to take the maximum request size plus two positions so full and full-1 conditions never occur.

        if (push_to_full_m_1 || drop_from_full_2_full_m_1)
            full_m_1_e[sb_push_seg_i]  <= #TP 1'b1; // set full_m_1 @ push segment

    end
end

  generate
    if (GEN_FULL_M_2==1) begin : gen_full_m_2
//----------------------------------------------------------------------
// full_m_2 detection
//----------------------------------------------------------------------
      always @(sb_init_seg_sizes_i) begin: Slice_SEG_SIZE_M3
      integer i, j;
      reg [RAM_AW-1:0] seg_size_slice;
        for (i=0; i<SEGS; i=i+1) begin
          for(j=0 ; j<RAM_AW ; j=j+1) begin
            seg_size_slice[j] = sb_init_seg_sizes_i[(i*RAM_AW)+j];
          end
          seg_size_m3[i] = seg_size_slice - 2; // do the math here against this incoming constant;
        end
      end
      assign working_seg_size_m3           = {1'b0, seg_size_m3[sb_push_seg_i]};
      assign pop_from_full_m_1_2_full_m_2  = full_m_1_e[sb_pop_seg_i] & sb_pop_i & ~push_at_pop_seg & ~drop_at_pop_seg;
      assign drop_from_full_2_full_m_2     = full_e[sb_push_seg_i] & sb_push_drop_i & (unkept==2) & ~pop_at_push_seg;
      assign drop_from_full_m_1_2_full_m_2 = full_m_1_e[sb_push_seg_i] & sb_push_drop_i & (unkept==1) & ~pop_at_push_seg;
      assign push_to_full_m_2              = sb_push_i & (working_elements==working_seg_size_m3) & ~pop_at_push_seg;
      assign drop_from_full_m_2            = full_m_2_e[sb_push_seg_i] & sb_push_drop_i;
      assign pop_from_full_m_2             = full_m_2_e[sb_pop_seg_i] & sb_pop_i & ~push_at_pop_seg;
      assign push_from_full_m_2            = full_m_2_e[sb_push_seg_i] & sb_push_i & ~pop_at_push_seg;

      always @(posedge clk or negedge rst_n) begin: Full_M2_Elements
        if (rst_n == 1'b0)
          full_m_2_e     <= #TP {SEGS{1'b0}};
        else if (srst_n == 1'b0)
          full_m_2_e     <= #TP {SEGS{1'b0}};
        else begin

          if (pop_from_full_m_2)
            full_m_2_e[sb_pop_seg_i] <= #TP 1'b0;   // clear full_m_1 @ pop_segment

          if (drop_from_full_m_2 | push_from_full_m_2)
            full_m_2_e[sb_push_seg_i]  <= #TP 1'b0; // clear full_m_1 @ push segment

          if (pop_from_full_m_1_2_full_m_2)
            full_m_2_e[sb_pop_seg_i]  <= #TP 1'b1;  // set full_m_1 @ pop segment  // ccx_line: u_axi_bridge.u_ob.u_cmp.u_ctl.u_data_DW_sbc; REDUNDANT: Segmented buffer segments are sized to take the maximum request size plus two positions so full and full-1 conditions never occur.
          if (push_to_full_m_2 || drop_from_full_2_full_m_2 || drop_from_full_m_1_2_full_m_2)
            full_m_2_e[sb_push_seg_i]  <= #TP 1'b1; // set full_m_1 @ push segment

        end
      end

    end else begin : gen_zero_full_m_2

      assign full_m_2_e = 0;

    end
  endgenerate

//----------------------------------------------------------------------
// Elements Tracking Control
//----------------------------------------------------------------------
assign load_curr_element_p_1            =  sb_push_i & sb_push_keep_i & !sb_push_start_i & !pop_at_push_seg;
assign load_curr_elements               =  sb_push_i & sb_push_keep_i & !sb_push_start_i &  pop_at_push_seg;
assign incr_elements                    =  sb_push_i & sb_push_keep_i &  sb_push_start_i & !pop_at_push_seg;

assign update_elements_push_seg         = load_curr_element_p_1  || load_curr_elements || incr_elements
                                          ;

assign next_elements_push_seg           =   ( load_curr_element_p_1   ? curr_elements + 1           :
                                              | load_curr_elements    ? curr_elements               :
                                              | incr_elements         ? elements[sb_push_seg_i] + 1 :
                                              {RAM_AW+1{1'b0}});

assign update_elements_pop_seg          = sb_pop_i && !(sb_push_keep_i && push_at_pop_seg ); // Drop cannot effect elements

//----------------------------------------------------------------------
// Elements Tracking storage
//----------------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin: Elements
integer seg_num;
    if (rst_n == 1'b0)     begin
        seg_pkt_avail_e  <= #TP 'd0;
        for(seg_num=0 ; seg_num<SEGS ; seg_num=seg_num+1) begin
            elements[seg_num]    <= #TP 'd0;
        end
    end else if (srst_n == 1'b0) begin
        seg_pkt_avail_e  <= #TP 'd0;
        for(seg_num=0 ; seg_num<SEGS ; seg_num=seg_num+1) begin
            elements[seg_num]    <= #TP 'd0;
        end
    end else begin

        if(update_elements_pop_seg) begin
            elements[sb_pop_seg_i]         <= #TP elements[sb_pop_seg_i]  - 1;

            seg_pkt_avail_e[sb_pop_seg_i]  <= #TP |(elements[sb_pop_seg_i]-1);
        end

        // NOTE: for push we will need to copy the current number of elements locally,
        //       then update local copy, then only when we get a sb_push_keep_i, write back into elements array

        if(update_elements_push_seg) begin
            elements[sb_push_seg_i] <= #TP next_elements_push_seg;

            seg_pkt_avail_e[sb_push_seg_i] <= #TP |next_elements_push_seg;

        end // if (update_elements_push_seg)

    end
end


//----------------------------------------------------------------------
// Current Element Tracking Control/storage
//----------------------------------------------------------------------

assign next_curr_elements =     sb_push_i & sb_push_start_i  & !pop_at_push_seg ? elements[sb_push_seg_i] + 1 :
                                sb_push_i & sb_push_start_i  & pop_at_push_seg  ? elements[sb_push_seg_i]     :
                                sb_push_i & !sb_push_start_i & !pop_at_push_seg ? curr_elements + 1           :
                                sb_push_i & !sb_push_start_i &  pop_at_push_seg ? curr_elements               :
                                !sb_push_i & !sb_push_start_i & pop_at_push_seg ? curr_elements - 1           : {RAM_AW+1{1'b0}};

assign update_curr_elements =  (sb_push_i & sb_push_start_i  & !pop_at_push_seg
                                | sb_push_i & sb_push_start_i  & pop_at_push_seg
                                | sb_push_i & !sb_push_start_i & !pop_at_push_seg
                                | !sb_push_i & !sb_push_start_i & pop_at_push_seg);


always @(posedge clk or negedge rst_n)
begin: Current_Elments_storage
    if (rst_n == 1'b0) begin
        curr_elements <= #TP 'd0;
        unkept        <= #TP 'd0;
    end else if (srst_n == 1'b0) begin
        curr_elements <= #TP 'd0;
        unkept        <= #TP 'd0;
    end else begin
        if (update_curr_elements)
            curr_elements <= #TP next_curr_elements;

        if (sb_push_keep_i)
            unkept <= #TP  'd0;
        else if (sb_push_i)
            unkept <= #TP unkept + 1;
    end
end

always @(posedge clk or negedge rst_n)
begin:Current_seg_proc
   if (rst_n == 1'b0) begin
      curr_seg                <= #TP 'd0;
      curr_seg_valid          <= #TP 1'b0;
   end else if (srst_n == 1'b0) begin
      curr_seg                <= #TP 'd0;
      curr_seg_valid          <= #TP 1'b0;
   end else begin
      if (sb_push_start_i)
        curr_seg            <= #TP sb_push_seg_i;
      if (sb_push_start_i && !sb_push_keep_i)
        curr_seg_valid      <= #TP 1'b1;
      else if (sb_push_keep_i || sb_push_drop_i)
        curr_seg_valid      <= #TP 1'b0;
   end
end

assign sb_empty_o         = empty_e;
assign sb_empty_p_1_o     = empty_p_1_e;
assign sb_full_o          = full_e;
assign sb_full_m_1_o      = full_m_1_e;
assign sb_full_m_2_o      = full_m_2_e;
assign sb_seg_pkt_avail_o = seg_pkt_avail_e;



endmodule

