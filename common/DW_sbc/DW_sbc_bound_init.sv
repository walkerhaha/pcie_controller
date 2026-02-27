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
// ---    $DateTime: 2019/06/14 03:54:27 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc/DW_sbc_bound_init.sv#3 $
// -------------------------------------------------------------------------
/*
-- Description  : This module is responsible for generating the start
--                and end addresses for each segment in the RAM.
--                This module should be removed at synthesis if
--                the start/end addresses on the i/o ports of the
--                DW_sbc are being used.
--
-- Modification History:
-- Date                 By      Version Change  Description
-- =====================================================================
-- See CVS log
-- =====================================================================
*/

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DW_sbc_bound_init (
   clk,
   rst_n,
   srst_n,

   // Segment size interface
   sb_init_i,
   sb_init_seg_sizes_i,
   sb_init_done_o,
   sb_init_done_red_o,
   sb_init_num_segs_i,

   sb_init_save_result_sa,
   sb_init_save_result_ea,
   sb_init_fsm_seg_num_d1,
   add_result_r

);

//----------------------------------------------------------------------
// Parameters.
//----------------------------------------------------------------------
  parameter SEGS = 3;             // Number of segments
  parameter SEG_W = 2;            // Width of segment register
  parameter RAM_AW = 12;          // RAM address width
  parameter SEG_SIZES_W = SEGS * RAM_AW; // Number of segments times
                                         // memory address width
  parameter TP                        = `TP;                     // Clock to Q delay (simulator insurance)

//----------------------------------------------------------------------
// Macros.
//----------------------------------------------------------------------



  // FSM state width.
  localparam FSM_W = 2;

  // FSM state names.
  localparam FSM_IDLE = 2'b00;
  localparam FSM_ADD_1 = 2'b01;
  localparam FSM_ADD_SIZE = 2'b10;

  // Add operand A select macros.
  localparam SEL_OP_A_S0_SIZE = 1'b1;
  localparam SEL_OP_A_RESULT  = 1'b0;

  // Add operand B select macros.
  localparam SEL_OP_B_ONE = {SEG_W{1'b0}};


//----------------------------------------------------------------------
// Module ports declaration
//----------------------------------------------------------------------
input                   clk;                    // System clock
input                   rst_n;                  // System reset
input                   srst_n;                 //Synchronous reset


//----------------------------------------------------------------------
// Segment size interface
//----------------------------------------------------------------------
input                   sb_init_i;              // Pulsed when initialization for segment pointers needs to occur

input [SEG_SIZES_W-1:0] sb_init_seg_sizes_i;    // List of sizes for each
                                                // segment: [RAM_AW-1:0]
                                                // = Segment 0
                                                // [2*RAM_AW-1:RAM_AW]
                                                // = Segment 1 ...

output                  sb_init_done_o;         // Asserted when boundary initialisation is
                                                // finished. Set to 0 on reset and rising edge
                                                // of sb_init_i

output                  sb_init_done_red_o;     // Rising edge detect of sb_init_done_o;


input [SEG_W :0]        sb_init_num_segs_i;     // Number of segments.
                                                // Allows number of segments
                                                // to be dynamicaly
                                                // reduced.

output                  sb_init_save_result_sa;
output                  sb_init_save_result_ea;
output [SEG_W-1:0]      sb_init_fsm_seg_num_d1; //
output [RAM_AW-1:0]     add_result_r;           // Result from the adder.



//----------------------------------------------------------------------
// Reg variables.
//----------------------------------------------------------------------
reg [FSM_W-1:0]        fsm_state;             // Current state.
reg [FSM_W-1:0]        fsm_next_state;        // Next state.
reg [FSM_W-1:0]        fsm_prev_state;        // Previous state.

reg [SEG_W-1:0]         fsm_seg_num;           // Represents the segment number whose
                                               // start/end addresses the FSM is
                                               // currently calculating.

reg [SEG_W-1:0]         fsm_seg_num_d1;        // 1 clk cycle delayed version of
                                               // fsm_seg_num.

reg                     sel_op_a;              // FSM controlled. Selects add operand a.
reg [SEG_W-1:0]         sel_op_b;              // FSM controlled. Selects add operand b.


reg                     load_op_a;             // FSM controlled. Loads operand a register.
reg                     load_op_b;             // FSM controlled. Loads operand b register.

reg                     load_result;           // FSM controlled. Loads add result register.

reg                     save_result_sa;        // FSM controlled. Saves the add result into the
                                               // register that will contain all the
                                               // segment start addresses when boundary
                                               // initialisation is complete.

reg                     save_result_ea;        // FSM controlled. Saves the add result into the
                                               // register that will contain all the
                                               // segment end addresses when boundary
                                               // initialisation is complete.

reg                     fsm_init_done_pulse_c; // Pulsed for 1 clk cycle when fsm has
                                               // completed boundary initialisation.

reg                     fsm_init_done_r;       // Set to 1 by fsm_init_done_pulse_c, cleared
                                               // by sb_init_i==1.
reg                     fsm_init_done_d1;      // 1 clk delayed fsm_init_done_r.
                                               // The "done" output is taken from this.
                                               // The delay is necessary as the final result
                                               // will not be stored in its register
                                               // until this time.
reg                     fsm_init_done_d2;      // 2 clk delayed fsm_init_done_r.
                                               // Used to generate rising edge detect.


reg [RAM_AW-1:0]        add_op_a_r;            // Operand A to the adder.
reg [RAM_AW-1:0]        add_op_b_r;            // Operand B to the adder.

reg [RAM_AW-1:0]        add_result_r;          // Result from the adder.

reg                                               sb_init_d1_r;          // 1 clk delayed version of sb_init_i.


//----------------------------------------------------------------------
// Wire variables.
//----------------------------------------------------------------------
wire [RAM_AW-1:0]                                 add_op_a;           // Pre-register wires for operand A & B
wire [RAM_AW-1:0]                                 add_op_b;           // to the adder.

wire                                              sb_init_done_red_c; // Internal rising edge detect of

// "init done" signal.
wire [SEG_W-1:0]                                  seg_num_1_const;


 generate
   if (SEG_W == 1) begin : gen_seg_w_1
      assign seg_num_1_const = 1'b1;
   end else begin : gen_seg_w_not_1 
      assign seg_num_1_const = {{(SEG_W-1){1'b0}}, 1'b1};
   end
 endgenerate

assign sb_init_save_result_sa = save_result_sa;
assign sb_init_save_result_ea = save_result_ea;
assign sb_init_fsm_seg_num_d1 = fsm_seg_num_d1;

//----------------------------------------------------------------------
// BOUNDARY INITIALISATION LOGIC
//----------------------------------------------------------------------

// Create 1 clk delayed version of sb_init_i.
  always @(posedge clk or negedge rst_n)
  begin : sb_init_d1_PROC
    if(rst_n == 1'b0) begin
      sb_init_d1_r <= #TP 1'b0;
    end else if (srst_n == 1'b0) begin
      sb_init_d1_r <= #TP 1'b0;
    end else begin
      sb_init_d1_r <= #TP sb_init_i;
    end
  end // sb_init_d1_PROC


// Next state logic.
  always @(sb_init_i          or
           sb_init_d1_r       or
           fsm_seg_num        or
           fsm_state          or
           fsm_prev_state     or
           seg_num_1_const    or
           sb_init_num_segs_i
          )
  begin : bound_init_fsm_nstate_PROC

    sel_op_a              = 1'b0;
    sel_op_b              = {SEG_W{1'b0}};
    load_op_a             = 1'b0;
    load_op_b             = 1'b0;
    load_result           = 1'b0;
    save_result_sa        = 1'b0;
    save_result_ea        = 1'b0;
    fsm_init_done_pulse_c = 1'b0;
    fsm_next_state        = FSM_IDLE;

    case(fsm_state)

      FSM_IDLE : begin

        // If "init" is asserted, start the boundary
        // initialisation process.
   // www.marcw: 29/07/09:
   // If we only have one segment then no need
   // to start initialisation.
        if(sb_init_i && (sb_init_num_segs_i != {{SEG_W{1'b0}}, 1'b1})) begin
          fsm_next_state = FSM_ADD_1;
        end else begin

     // www.marcw: 29/07/09:
     // If we only have one segment then we need
     // to indicate we are done to set the end
     // address for the segment.
     if(sb_init_d1_r && (sb_init_num_segs_i == {{SEG_W{1'b0}}, 1'b1})) begin
       fsm_init_done_pulse_c = 1'b1;
     end
          fsm_next_state = FSM_IDLE;
        end

        // If we came here from FSM_ADD_SIZE there is
        // a valid end address on the add result register,
        // so we assert save_result_ea to put it into
        // the end address shift register
        // and deassert load_result, to hold the result register.
        if(fsm_prev_state == FSM_ADD_SIZE) begin
          save_result_ea = 1'b1;
        end

      end // FSM_IDLE


      FSM_ADD_1 : begin

        // Operand A to the adder is segment 0 size
        // if we are caluculating segment 1 start/end
        // addresses, and the current add result
        // in call other cases.
        if(fsm_seg_num == seg_num_1_const) begin
          sel_op_a = SEL_OP_A_S0_SIZE;
        end else begin
          sel_op_a = SEL_OP_A_RESULT;
        end

        // In this state operand B is always 1'b1.
        sel_op_b = SEL_OP_B_ONE;

        // If we came here from FSM_ADD_SIZE there is
        // a valid end address on the add result register,
        // so we assert save_result_ea to put it into
        // the end address shift register
        // and deassert load_result, to hold the result register.
        if(fsm_prev_state == FSM_ADD_SIZE) begin
          save_result_ea = 1'b1;
          load_result = 1'b0;
        end


        // If "init" is asserted return to this state.
        if(sb_init_i == 1'b1) begin
          // ccx_line: u_edma_rdbuff.u_DW_sbc; STIMULUS: Verification hole due to insufficient randomization. Covered on coverage database. Testbench needs to be improved to be always covered.
          // ccx_line: u_axi_bridge.u_mcb.u_sbc.u_DW_sbc_bound_init,u_axi_bridge.u_ob.u_cmp.u_ctl.u_data_DW_sbc.u_DW_sbc_bound_init; REDUNDANT: In this instance sb_init_i is asserted only once immediately after reset
          fsm_next_state = FSM_ADD_1;
        end else begin

          // For the first cycle in this state we
          // assert the "load" signals.
          // Also assert if sb_init_i was asserted in the previous
          // cycle, as we return to this state if sb_init_i is
          // asserted when the fsm is not in FSM_IDLE.
          if(   (fsm_prev_state != FSM_ADD_1)
             || (sb_init_d1_r == 1'b1)
            ) begin
            load_op_a      = 1'b1;
            load_op_b      = 1'b1;
            fsm_next_state = FSM_ADD_1;

          // For the second cycle in this state we
          // deassert the operand load signals, and assert
          // the load result signal.
          // We deassert save_result_ea also which would be
          // asserted if we were saving an end address in the
          // previous cycle.
          end else begin
            load_op_a      = 1'b0;
            load_op_b      = 1'b0;
            load_result    = 1'b1;
            save_result_ea = 1'b0;
            fsm_next_state = FSM_ADD_SIZE;
          end

        end
      end // FSM_ADD_1


      FSM_ADD_SIZE : begin
        // Operand A to the adder is always the previous add
        // result in this state.
        sel_op_a = SEL_OP_A_RESULT;

        // In this state operand B is always the current
        // segments size.
        sel_op_b = fsm_seg_num;

        // If we came here from FSM_ADD_1 there is
        // a valid start address on the add result register,
        // so we assert save_result_sa to put it into
        // the start address shift register
        // and deassert load_result, to hold the result register.
        if(fsm_prev_state == FSM_ADD_1) begin
          save_result_sa = 1'b1;
          load_result    = 1'b0;
        end


        // If "init" is asserted return to idle
        // to start again.
        if(sb_init_i == 1'b1) begin
          // ccx_line: u_edma_rdbuff.u_DW_sbc; STIMULUS: Verification hole due to insufficient randomization. Covered on coverage database. Testbench needs to be improved to be always covered.
          // ccx_line: u_axi_bridge.u_mcb.u_sbc.u_DW_sbc_bound_init,u_axi_bridge.u_ob.u_cmp.u_ctl.u_data_DW_sbc.u_DW_sbc_bound_init; REDUNDANT: In this instance sb_init_i is asserted only once immediately after reset
          fsm_next_state = FSM_ADD_1;
        end else begin

          // For the first cycle in this state we
          // assert the "load" signals.
          if(fsm_prev_state != FSM_ADD_SIZE) begin
            load_op_a      = 1'b1;
            load_op_b      = 1'b1;
            fsm_next_state = FSM_ADD_SIZE;

          // For the second cycle in this state we
          // deassert the operand load signals, and assert
          // the load result signal.
          // We deassert save_result_sa also which would be
          // asserted if we were saving a start address result
          // in the previous cycle.
          end else begin
            load_op_a      = 1'b0;
            load_op_b      = 1'b0;
            load_result    = 1'b1;
            save_result_sa = 1'b0;

            // fsm_seg_num counts from 0 to sb_init_num_segs_i-1,
            // so compare to sb_init_num_segs_i-1 as our condition
            // to complete boundary initialisation.
            if(fsm_seg_num != (sb_init_num_segs_i-1)) begin
              fsm_next_state = FSM_ADD_1;

            // Finished boundary initialisation. Assert "done".
            end else begin
              fsm_next_state = FSM_IDLE;
              fsm_init_done_pulse_c = 1'b1;
            end
          end

        end

      end // FSM_ADD_SIZE


      default : begin
        fsm_next_state = FSM_IDLE;
      end

    endcase

  end // bound_init_fsm_nstate_PROC


//----------------------------------------------------------------------
// Current state and previous state registers.
//----------------------------------------------------------------------
  always @(posedge clk or negedge rst_n)
  begin : fsm_state_reg_PROC
    if(rst_n == 1'b0) begin
      fsm_state      <= #TP FSM_IDLE;
      fsm_prev_state <= #TP FSM_IDLE;
    end else if (srst_n == 1'b0) begin
      fsm_state      <= #TP FSM_IDLE;
      fsm_prev_state <= #TP FSM_IDLE;
    end else begin
      fsm_state      <= #TP fsm_next_state;
      fsm_prev_state <= #TP fsm_state;
    end
  end // fsm_state_reg_PROC

//----------------------------------------------------------------------
// Segment number register.
// Tells us what segment the FSM is currently calculating start/end
// addresses for. Used for the operand b select mux.
// Set to 1 when sb_init_i is asserted because no calculations are
// required to calculate the start/end addresses for segment 0.
// Incremented on every transition from FSM_ADD_SIZE to FSM_ADD_1.
//----------------------------------------------------------------------
  always @(posedge clk or negedge rst_n)
  begin : fsm_seg_num_PROC
    if(rst_n == 1'b0) begin
      fsm_seg_num <= #TP {SEG_W{1'b0}};
    end else if (srst_n == 1'b0) begin
      fsm_seg_num <= #TP {SEG_W{1'b0}};
    end else begin
      if(sb_init_i) begin
        fsm_seg_num <= #TP seg_num_1_const;
      end else begin
        if(   (fsm_state == FSM_ADD_SIZE)
           && (fsm_next_state == FSM_ADD_1)) begin
          fsm_seg_num <= #TP fsm_seg_num + 1'b1;
        end
      end
    end
  end // fsm_seg_num_PROC


//----------------------------------------------------------------------
// Generate 1 clk delayed version of fsm_seg_num.
//----------------------------------------------------------------------
  always @(posedge clk or negedge rst_n)
  begin : fsm_seg_num_d1_PROC
    if(rst_n == 1'b0) begin
      fsm_seg_num_d1 <= #TP {SEG_W{1'b0}};
    end else if (srst_n == 1'b0) begin
      fsm_seg_num_d1 <= #TP {SEG_W{1'b0}};
    end else begin
      fsm_seg_num_d1 <= #TP fsm_seg_num;
    end
  end // fsm_seg_num_d1_PROC



//----------------------------------------------------------------------
// Add operand select muxes.
//----------------------------------------------------------------------

  // 2 possibilities for the operand A mux.
  // If sel_op_a == SEL_OP_S0_SIZE : segment 0 size
  // If sel_op_a == SEL_OP_A_RESULT  : current add result
  assign add_op_a = (sel_op_a == SEL_OP_A_S0_SIZE) ?
                      sb_init_seg_sizes_i[RAM_AW-1:0]
                    : add_result_r;


//  // Create one hot version of sel_op_b.
//  reg [SEGS-1:0]                                 sel_op_b_onehot;                                             // Onehot version of sel_op_b.
//  always @(sel_op_b)
//  begin : sel_op_b_onehot_PROC
//    integer seg_num;
//    sel_op_b_onehot = {SEGS{1'b0}};
//
//    for(seg_num=0 ; seg_num<SEGS ; seg_num=seg_num+1) begin
//      if(sel_op_b == seg_num) sel_op_b_onehot[seg_num] = 1'b1;
//    end
//
//  end // push_current_seg_oh_PROC
//
//  // This module implements the operand B select mux.
//  // This muxes between all segment sizes - except segment 0,
//  // and {(RAM_AW-1){1'b0}, 1'b1}.
//  DW_sbc_busmux
//  #(SEGS, RAM_AW)
//  u_op_b_select_mux (
//    .sel  (sel_op_b_onehot),
//    .din  ({sb_init_seg_sizes_i[SEG_SIZES_W-1:RAM_AW],
//            {{(RAM_AW-1){1'b0}}, 1'b1} }
//          ),
//    .dout (add_op_b)
//  );
//
// temporary removal of busmux, this code likely to
// be replaced.

reg [RAM_AW-1:0] demuxed_seg_size;
   always @ (sel_op_b or sb_init_seg_sizes_i) begin : mux_add_op_b
      integer seg_num, j;
      demuxed_seg_size  = {RAM_AW{1'b0}};
      if (sel_op_b == 0)
        demuxed_seg_size = {{(RAM_AW-1){1'b0}}, 1'b1};
      for (seg_num = 1; seg_num < SEGS; seg_num = seg_num + 1) begin
         if(sel_op_b == seg_num)
           for (j = 0; j < RAM_AW; j = j + 1) begin
              demuxed_seg_size[j] = sb_init_seg_sizes_i[RAM_AW*seg_num +j];
           end
      end
   end // always

assign add_op_b = demuxed_seg_size;


//----------------------------------------------------------------------
// Add operand registers.
//----------------------------------------------------------------------
  always @(posedge clk or negedge rst_n)
  begin : add_operation_PROC
    if(rst_n == 1'b0) begin
      add_op_a_r <= #TP {RAM_AW{1'b0}};
      add_op_b_r <= #TP {RAM_AW{1'b0}};
    end else if (srst_n == 1'b0) begin
      add_op_a_r <= #TP {RAM_AW{1'b0}};
      add_op_b_r <= #TP {RAM_AW{1'b0}};
    end else begin
      if(load_op_a) add_op_a_r <= #TP add_op_a;
      if(load_op_b) add_op_b_r <= #TP add_op_b;
    end
  end // add_operation_PROC


//----------------------------------------------------------------------
// Add operation and result register.
//----------------------------------------------------------------------
  always @(posedge clk or negedge rst_n)
  begin : add_op_res_reg_PROC
    if(rst_n == 1'b0) begin
      add_result_r <= #TP {RAM_AW{1'b0}};
    end else if (srst_n == 1'b0) begin
      add_result_r <= #TP {RAM_AW{1'b0}};
    end else begin
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
      add_result_r <= #TP add_op_a_r + add_op_b_r;
      // spyglass enable_block W164a
    end
  end // add_op_res_reg_PROC

//----------------------------------------------------------------------
// Start and end address registers.
// Note how the registers do not store start or end addresses for
// segment 0, as these are 0 and segment 0 size respectfully.
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Generation of sb_init_done_o and related signals.
// The FSM generates the 1 cycle pulse fsm_init_done_pulse_c when
// it is finished boundary initialisation.
// But we need to wait 2 cycles before we can assert this on the output
// as the final add result will not be stored until this time.
// An assertion of fsm_init_done_pulse_c will set the register
// fsm_init_done_r to 1'b1, and it is cleared by an assertion of
// sb_init_i.
// The signal fsm_init_done_r gets fed into a register delay chain,
// where fsm_init_done_d1 is the actual sb_init_done_o output,
// fsm_init_done_d2 is used to generate the internal signal
// sb_init_done_red_c, which is a pulse that is output to the push and
// pop logic blocks to initialise the read and write pointers with the
// segment start addresses.
//----------------------------------------------------------------------
  always @(posedge clk or negedge rst_n)
  begin : fsm_init_done_d1_PROC
    if(rst_n == 1'b0) begin
      fsm_init_done_r  <= #TP 1'b0;
      fsm_init_done_d1 <= #TP 1'b0;
      fsm_init_done_d2 <= #TP 1'b0;
    end else if (srst_n == 1'b0) begin
      fsm_init_done_r  <= #TP 1'b0;
      fsm_init_done_d1 <= #TP 1'b0;
      fsm_init_done_d2 <= #TP 1'b0;
    end else begin

      if(sb_init_i) begin
        fsm_init_done_r  <= #TP 1'b0;
        fsm_init_done_d1 <= #TP 1'b0;
        fsm_init_done_d2 <= #TP 1'b0;
      end else begin
        if(fsm_init_done_pulse_c) fsm_init_done_r <= #TP 1'b1;
        fsm_init_done_d1 <= #TP fsm_init_done_r;
        fsm_init_done_d2 <= #TP fsm_init_done_d1;
      end

    end
  end // fsm_init_done_d1_PROC

  assign sb_init_done_red_c = (fsm_init_done_d1 & ~fsm_init_done_d2);


//----------------------------------------------------------------------
// Ouput Stage.
//----------------------------------------------------------------------
  assign sb_init_done_o     = fsm_init_done_d1;

  assign sb_init_done_red_o = sb_init_done_red_c;

`ifndef SYNTHESIS
//VCS coverage off
   // Waveform aliasing for the state names
   reg [14*8:0] state_name;
   always @(fsm_state)
     case (fsm_state)
       FSM_IDLE     : state_name = "     FSM_IDLE";
       FSM_ADD_1    : state_name = "    FSM_ADD_1";
       FSM_ADD_SIZE : state_name = " FSM_ADD_SIZE";
       default       : state_name = "    UNDEFINED";
     endcase

   // minimum number of segments is two, so sb_init_seg_sizes_i will be at least (RAM_AW*2)-1:0
   wire [RAM_AW-1:0] s0_size;
   assign s0_size = sb_init_seg_sizes_i[RAM_AW-1:0];

   wire [RAM_AW-1:0] s1_size;
   assign s1_size = sb_init_seg_sizes_i[(RAM_AW*2)-1:RAM_AW];

   // want to be able to have visibility for segment 2 size
   //   must calculate a multiplier so we don't try to index out of range
   //   if there are more than 2 segments then index normally
   //   otherwise make s2_size equivalent to s0_size
   wire [RAM_AW-1:0] s2_size;
   parameter S2_MULT   = (SEGS>2) ? 3 : 1;
   assign s2_size = sb_init_seg_sizes_i[(RAM_AW*S2_MULT)-1:(RAM_AW*(S2_MULT-1))];
//VCS coverage on
`endif // SYNTHESIS

endmodule

