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

// ---------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2018/08/30 02:24:02 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_outq_mgr_ctl.sv#2 $
// ---------------------------------------------------------------------------------------
// Description:
// ---------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module radm_outq_mgr_ctl
 #(
  // Number of data queues
  parameter NDQ                              = 4,
  // log2(NDQ)
  parameter NDQ_LOG2                         = 2,
  // Number of segments
  parameter NUM_SEGMENTS                     = 3,
  // log2(NUM_SEGMENTS)
  parameter NUM_SEGMENTS_LOG2                = 2,
  // CLK to Q delay
  parameter TP                               = `TP
  )
  (
  // -------------------------------------------------------------------------------------
  // Clocks and Resets
  // -------------------------------------------------------------------------------------
  input                                              core_clk,
  input                                              core_rst_n,
  // -------------------------------------------------------------------------------------
  // Order Q Read Interface
  // -------------------------------------------------------------------------------------
  input                                              ordrq_rd_req,
  output wire                                        qctl_req_ack,
  input       [NUM_SEGMENTS_LOG2-1:0]                ordrq_rd_seg_num,
  input                                              ordrq_rd_tlp_w_pyld,
  input                                              ordrq_rd_4trgt0,
  input                                              cfg_is_cut_through,
  // -------------------------------------------------------------------------------------
  // Data Q Info Interface
  // -------------------------------------------------------------------------------------
  input       [NDQ-1:0]                              dataq_rd_end,
  // -------------------------------------------------------------------------------------
  // Header Q Read Interface
  // -------------------------------------------------------------------------------------
  input       [NUM_SEGMENTS-1:0]                     hdrq_empty,
  output wire                                        qctl_hdrq_rd_en,
  // -------------------------------------------------------------------------------------
  // Data Q Read Interface
  // -------------------------------------------------------------------------------------
  output wire                                        qctl_dataq_rd_en,
  output wire [NDQ-1:0]                              qctl_dataq_par_chk_val,
  input       [NUM_SEGMENTS-1:0]                     dataq_empty,
  // -------------------------------------------------------------------------------------
  // Data Q Control Interface
  // -------------------------------------------------------------------------------------
  output wire [NDQ-1:0]                              qctl_eot,
  output wire [NUM_SEGMENTS_LOG2-1:0]                qctl_rd_seg_num,
  output wire                                        qctl_rd_tlp_w_pyld,
  output wire                                        qctl_rd_4trgt0,
  output wire                                        qctl_is_cut_through,
  input                                              halt
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam READ_HDR_DATA = 1'b0;
  localparam READ_MORE_DATA = 1'b1;
  localparam MAX_NUM_QDW_PER_BEAT = NDQ;

  // -------------------------------------------------------------------------------------
  // Wires/Regs
  // -------------------------------------------------------------------------------------
  reg                                                r_halt;

  reg                                                s_rd_fsm_state;
  reg                                                r_rd_fsm_state;

  wire                                               s_hdrq_empty;

  logic [NDQ-1:0]                                    s_seg_empty;
  reg                                                s_dataq_seg_empty;
  reg                                                s_dataq_seg_empty_p_1;

  reg  [NDQ_LOG2:0]                                  s_rd_num_qdws_per_beat;

  reg                                                s_req_ack;
  reg                                                s_hdrq_rd_en;
  reg  [NDQ-1:0]                                     s_dataq_rd_en;
  reg  [NDQ-1:0]                                     s_eot;
  reg  [NUM_SEGMENTS_LOG2-1:0]                       s_rd_seg_num;
  reg  [NUM_SEGMENTS_LOG2-1:0]                       r_rd_seg_num;
  reg                                                s_rd_tlp_w_pyld;
  reg                                                r_rd_tlp_w_pyld;
  reg                                                s_rd_4trgt0;
  reg                                                r_rd_4trgt0;
  reg                                                s_is_cut_through;
  reg                                                r_is_cut_through;

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // Register the halt input signal. Note: The additional pop cycle of data/hdr info is 
  // absorbed by the data/hdr pop pipeline stage.
  // Registering the halt avoids feedthrough paths from the TRGT* interface halt inputs to
  // the data/hdr queue read address outputs.
   always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_halt
     if (!core_rst_n) begin
       r_halt <= # TP 0;
     end else begin
       r_halt <= # TP halt;
     end   
   end

  // Hold read segment number
  always @(*) begin : proc_comb_rd_seg_num
   s_rd_seg_num = r_rd_seg_num;
   // Update when FSM returns to IDLE and read request pending otherwiswe hold
   // segment number
   if (ordrq_rd_req && (r_rd_fsm_state==READ_HDR_DATA) && !r_halt) begin
     s_rd_seg_num = ordrq_rd_seg_num;
   end
  end

  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_rd_seg_num
    if (!core_rst_n) begin
      r_rd_seg_num <= # TP 0;
    end else if (!r_halt) begin
      r_rd_seg_num <= # TP s_rd_seg_num;
    end
  end

  // -------------------------------------------------------------------------------------
  // Extract the header queue empty flag.
  // Ensure the TLP is not read until header info is pushed to the queue. 
  // For 256b configurations resolving clashes to the header RAMs can result in order queue
  // request being issued before the header RAM is written.
  // -------------------------------------------------------------------------------------
  assign s_hdrq_empty = hdrq_empty[s_rd_seg_num];

  // -------------------------------------------------------------------------------------
  // Extract the data queue empty flags. Flags organsied as follows:
  // -------------------------------------------------------------------------------------
  assign s_seg_empty = dataq_empty[s_rd_seg_num];

  // -------------------------------------------------------------------------------------
  // Calculate the number of QDWs per beat
  // -------------------------------------------------------------------------------------
  always @(*) begin : proc_comb_rd_num_qdws_per_beat
    s_rd_num_qdws_per_beat = 0;
    if (|dataq_rd_end) begin
      s_rd_num_qdws_per_beat = fn_first_one_pos(dataq_rd_end) + 1;  
    end else begin
      s_rd_num_qdws_per_beat = NDQ;
    end
  end

  // -------------------------------------------------------------------------------------
  // Read FSM
  // -------------------------------------------------------------------------------------
  always @(*) begin : proc_comb_rd_fsm
    integer i,j;

    // Initialise
    s_rd_fsm_state   = r_rd_fsm_state;
    s_req_ack        = 1'b0;
    s_hdrq_rd_en     = 1'b0;
    s_dataq_rd_en    = {NDQ{1'b0}};
    s_eot            = {NDQ{1'b0}};
    s_rd_tlp_w_pyld  = r_rd_tlp_w_pyld;
    s_rd_4trgt0      = r_rd_4trgt0;
    s_is_cut_through = r_is_cut_through;

    if (!r_halt) begin

      case (r_rd_fsm_state)
        READ_HDR_DATA : begin
          if (ordrq_rd_req) begin
            // Capture request info
            s_rd_tlp_w_pyld  = ordrq_rd_tlp_w_pyld;
            s_rd_4trgt0      = ordrq_rd_4trgt0;
            s_is_cut_through = cfg_is_cut_through;

            if (!s_hdrq_empty) begin
              if (!ordrq_rd_tlp_w_pyld || (ordrq_rd_tlp_w_pyld && |dataq_rd_end)) begin // single beat tlp
                if (!ordrq_rd_tlp_w_pyld) begin // hdr only
                  s_eot[0] = 1'b1; 
                  s_req_ack = s_eot[0];
                  s_hdrq_rd_en = s_eot[0];
                end else begin // hdr + data
                  for (i=0; i<NDQ; i=i+1) begin
                    // In cut-thru mode wait for all QDWs to be available before reading from the q
                    if ((s_rd_num_qdws_per_beat==i+1) && !s_seg_empty[i]) begin 
                      // avoid non constant terminator for xprop
                      for (j=0; j<NDQ; j=j+1) begin
                        if(j<=i) begin
                          s_dataq_rd_en[j] = 1'b1;
                        end
                      end
                      s_eot[i] = 1'b1; 
                    end
                  end
                  s_hdrq_rd_en = |s_eot;
                  s_req_ack = |s_eot;
                end
              end else begin // multi-cycle tlp
                // In cut-thru mode wait for all QDWs to be available before reading from the q
                s_dataq_rd_en = {NDQ{!s_seg_empty[NDQ-1]}};
                if (|s_dataq_rd_en) begin
                  s_req_ack = 1'b1;
                  s_hdrq_rd_en = 1'b1;
                  s_rd_fsm_state = READ_MORE_DATA;
                end
              end
            end
          end
        end
        READ_MORE_DATA : begin
          if (|dataq_rd_end) begin // last beat
            for (i=0; i<NDQ; i=i+1) begin
              // In cut-thru mode wait for all QDWs to be available before reading from the q
              if ((s_rd_num_qdws_per_beat==i+1) && !s_seg_empty[i]) begin 
                // avoid non constant terminator for xprop
                for (j=0; j<NDQ; j=j+1) begin
                  if(j<=i) begin
                    s_dataq_rd_en[j] = 1'b1;
                  end
                end
                s_eot[i] = 1'b1; 
                s_rd_fsm_state = READ_HDR_DATA;
              end
            end
          end else begin // intermediate beats
            // In cut-thru mode wait for all QDWs to be available before reading from the q
            s_dataq_rd_en = {NDQ{!s_seg_empty[NDQ-1]}};
          end
        end
      endcase
    end
  end

  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_rd_fsm
    if (!core_rst_n) begin
      r_rd_fsm_state   <= # TP READ_HDR_DATA;
      r_rd_tlp_w_pyld  <= # TP 0;
      r_rd_4trgt0      <= # TP 0;
      r_is_cut_through <= # TP 0;
    end else if (!r_halt) begin
      r_rd_fsm_state   <= # TP s_rd_fsm_state;
      r_rd_tlp_w_pyld  <= # TP s_rd_tlp_w_pyld;
      r_rd_4trgt0      <= # TP s_rd_4trgt0;
      r_is_cut_through <= # TP s_is_cut_through;
    end  
  end

  // -------------------------------------------------------------------------------------
  // Assign outputs
  // -------------------------------------------------------------------------------------
  assign qctl_req_ack           = s_req_ack;
  assign qctl_hdrq_rd_en        = s_hdrq_rd_en;
  assign qctl_dataq_rd_en       = |s_dataq_rd_en;
  assign qctl_dataq_par_chk_val = s_dataq_rd_en;
  assign qctl_eot               = s_eot; 
  assign qctl_rd_seg_num        = s_rd_seg_num;
  assign qctl_rd_tlp_w_pyld     = s_rd_tlp_w_pyld;
  assign qctl_rd_4trgt0         = s_rd_4trgt0;
  assign qctl_is_cut_through    = s_is_cut_through;

  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  // Find the first vector bit position set to one, searching right to left.
  function automatic [NDQ_LOG2-1:0] fn_first_one_pos;
    integer j;

    input [NDQ-1:0]      vec;
    reg   [NDQ_LOG2-1:0] first_one_pos;
    reg                  found;

    begin
      // Initialise
      first_one_pos = 0;
      found = 0;

      for (j=0; j<NDQ; j=j+1) begin
        if (vec[j] && !found) begin
          found = 1'b1;
          first_one_pos = j;
        end
      end
      fn_first_one_pos = first_one_pos;
    end
  endfunction

`ifndef SYNTHESIS
  // -------------------------------------------------------------------------------------
  // Enumerate FSM states
  // -------------------------------------------------------------------------------------
   wire [16*8:1] RD_FSM;

   assign RD_FSM = (r_rd_fsm_state == READ_HDR_DATA)  ?  "HDR_DATA"  :
                   (r_rd_fsm_state == READ_MORE_DATA) ?  "MORE_DATA" :
                   "UNDEF";

`endif

endmodule
