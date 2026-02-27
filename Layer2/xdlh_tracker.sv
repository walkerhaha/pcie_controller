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
// ---    $DateTime: 2020/06/26 01:14:06 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_tracker.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module tracks TLP's through the XDLH and generates a pending flag
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xdlh_tracker
  // Parameters
  #(
    parameter TP      = `TP,
    parameter NW      = `CX_NW,
    parameter SOT_WD  = 1
  ) (
    // Inputs
    input                     core_clk,
    input                     core_rst_n,
    input [(SOT_WD - 1) : 0]  xtlh_xdlh_sot,          // Start of TLP indication to XDLH
    input                     xdlh_xtlh_halt,         // XDLH halt to the XTLH
    input [(NW - 1) : 0]      xdlh_xmlh_eot,          // End of TLP indication to XMLH
    input                     xmlh_xdlh_halt,         // XMLH halt to the XDLH
    input [(NW - 1) : 0]      xdlh_xmlh_dllp,         // Position of DLLP EOT in the datapath
    input [(SOT_WD - 1) : 0]  rbuf_xmt_sot,           // Start of TLP indication from retrybuffer
    input                     rbuf_halt,              // Halt of retrybuffer
    input                     clear_pending,          // flag to clear the pending
    input                     xdlh_in_reply,          // retry buffer FSM replay state
    input                     xdlh_not_expecting_ack, // Ack/Nak DLLP pending
    // Outputs
    output  logic             xdlh_tlp_pending,       // XDLH TLP pending
    output  logic             xdlh_retry_pending      // XDLH retry pending indication 
);

localparam XDLH_TLP_REGOUT  = `CX_XDLH_TLP_REGOUT;
localparam XDLH_PKT_PENDING = `XDLH_PKT_PENDING_REG;
localparam CRC_LATENCY_XDLH = `CX_CRC_LATENCY_XDLH;
localparam RASDP_PIPE_DELAY = `CX_RASDP_XDLH_PIPE_EN;
localparam CXL_ENABLE       = 0 ;
localparam EOT_CNT_WD       = ((NW==16) ? 3 : ((NW>=4) ? 2 : 1));
localparam DELAY_CAN_STALL = ((XDLH_TLP_REGOUT + XDLH_PKT_PENDING) == 2) ? 1 : 0;
localparam CNT_WD = (((CRC_LATENCY_XDLH + 1) + (XDLH_TLP_REGOUT + XDLH_PKT_PENDING + DELAY_CAN_STALL)) > 3) ? 3 : 2;
//
logic [(EOT_CNT_WD - 1) : 0]  int_eot_cnt;
logic [CNT_WD : 0]            int_tlp_cnt_b;
logic [CNT_WD : 0]            int_tlp_cnt_r;
logic int_sot_req;
logic int_rbuf_req;
logic int_xmlh_grant;
logic int_inc_cnt;

// Track the number of TLP's output from Layer2
// If an EOT is detected and it is not part of DLLP increment the EOT counter
always_comb begin : eot_cnt_PROC
  integer i;
  int_eot_cnt = {EOT_CNT_WD{1'b0}};
  for(i = 0; i < NW; i = i + 1) begin
    if(xdlh_xmlh_eot[i] && !xmlh_xdlh_halt && !xdlh_xmlh_dllp[i])
      int_eot_cnt = int_eot_cnt + 1'b1;
  end
end : eot_cnt_PROC

// SOT can either come from Layer3 or from retrybuffer
assign int_rbuf_req = (|rbuf_xmt_sot) && !rbuf_halt;
// SOT from Layer3
assign int_sot_req = ((|xtlh_xdlh_sot) && !xdlh_xtlh_halt) || int_rbuf_req;
assign int_xmlh_grant = |(xdlh_xmlh_eot) && !xmlh_xdlh_halt;
assign int_inc_cnt = int_sot_req && !int_xmlh_grant;

// Count the pending TLP's in Layer2.
// The counter increments when a new TLP is input and no TLP is being output
// If no new TLP is being input the counter is decremented by the number of TLP's
// being output. Otherwise the counter is decremented by the number of TLP's minus 1 
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The TLP counter maximum value is constrained by the datapath so by design the counter cannot overflow.
always_comb begin : tx_cnt_PROC
  if(clear_pending)
    int_tlp_cnt_b = {CNT_WD{1'b0}};
  else if(int_inc_cnt)
    int_tlp_cnt_b = int_tlp_cnt_r + 1'b1;
  else if(int_xmlh_grant)
    int_tlp_cnt_b = int_tlp_cnt_r - (int_eot_cnt - int_sot_req);
  else
    int_tlp_cnt_b = int_tlp_cnt_r;
end : tx_cnt_PROC
// spyglass enable_block W164a


always_ff @(posedge core_clk or negedge core_rst_n) begin : tx_mon_PROC
  if(!core_rst_n) begin
    int_tlp_cnt_r <= #TP {CNT_WD{1'b0}};
  end else begin
    int_tlp_cnt_r <= #TP int_tlp_cnt_b;
  end
end

// The pending tracks TLP's in and out of the XDLH
assign xdlh_tlp_pending = !(int_tlp_cnt_r == {CNT_WD{1'b0}});

// The busy flag takes into account the XDLH retry buffer FSM state since
// during the PM L1_WAIT_LAST_TLP_ACK state we need to know that the retry
// buffer is IDLE
assign xdlh_retry_pending = xdlh_tlp_pending || xdlh_in_reply || !xdlh_not_expecting_ack;


endmodule
