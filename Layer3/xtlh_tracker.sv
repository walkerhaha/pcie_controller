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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_tracker.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module tracks TLP's through the XTLH and generates a pending flag
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xtlh_tracker
  // Parameters
  #(
    parameter TP  = `TP,
    parameter NW  = `CX_NW,
    parameter EOT_WD = (NW>2) ? NW : 1
  ) (
    // Inputs
    input                     core_clk,
    input                     core_rst_n,
    input                     xadm_xtlh_hv,     // TLP header valid from XADM
    input                     xtlh_xadm_halt,   // XTLH halt to the XADM
    input [(EOT_WD - 1) : 0]  xtlh_xdlh_eot,    // End of TLP to the XDLH
    input                     xdlh_xtlh_halt,   // XDLH halt to the XTLH
    input                     flush_req,        // flush request used to clear pending counter
    input                     rasdp_flush_req,  // RAS flush request used to clear pending counter
    // Outputs
    output  logic             xtlh_tlp_pending  // XTLH tlp pending indication
);

localparam XTLH_CTRL_REGOUT = `CX_XTLH_CTRL_REGOUT;
localparam EOT_CNT_WD       = ((NW>2) ? 2 : 1);
localparam CRC_LATENCY_XTLH = `CX_CRC_LATENCY_XTLH;
// xtlh_merge fifo + output register (with stalling) + crc pipeline + crc register stage if applicable
localparam MAX_TLP_CNT      = ((NW>2) ? 5 : 1) + (XTLH_CTRL_REGOUT ? 2 : 0) + 1 + CRC_LATENCY_XTLH;
localparam CNT_WD           = ((MAX_TLP_CNT == 1) ? 1 : ((MAX_TLP_CNT > 7) ? 4 : ((MAX_TLP_CNT) > 3 ? 3 : 2)));

logic [(EOT_CNT_WD - 1) : 0]  int_eot_cnt;
logic [CNT_WD : 0]            int_tlp_cnt_b;
logic [CNT_WD : 0]            int_tlp_cnt_r;
logic int_inc_cnt;
logic int_xdlh_grant;
logic int_hv_req;
logic int_clear_pending;
logic int_flush_req_r;

assign int_hv_req = xadm_xtlh_hv && !xtlh_xadm_halt;
assign int_xdlh_grant = |(xtlh_xdlh_eot) && !xdlh_xtlh_halt;
assign int_inc_cnt = int_hv_req && !int_xdlh_grant;

// Track the number of TLP's output from Layer3
// The counter increments by the number of TLP's output if there is no new TLP input
always_comb begin : eot_cnt_PROC
  integer i;
  int_eot_cnt = {EOT_CNT_WD{1'b0}};
  for(i = 0; i < EOT_WD; i = i + 1) begin
    if(xtlh_xdlh_eot[i] && !xdlh_xtlh_halt)
      int_eot_cnt = int_eot_cnt + 1'b1;
  end
end : eot_cnt_PROC

// Generate the clear for the pending counter
// The flush request is extended to account for single cycle 1->0->1 transition
always_ff @(posedge core_clk or negedge core_rst_n) begin : flush_req_PROC
  if(!core_rst_n) begin
    int_flush_req_r <= #TP 1'b0;
  end else begin
    int_flush_req_r <= #TP flush_req;
  end
end : flush_req_PROC

assign int_clear_pending = (flush_req || int_flush_req_r) || rasdp_flush_req;

// Count the pending TLP's in Layer3.
// The counter increments when a new TLP is input and no TLP is being output
// If no new TLP is being input the counter is decremented by the number of TLP's
// being output. Otherwise the counter is decremented by the number of TLP's minus 1 
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The TLP counter maximum value is constrained by the datapath so by design the counter cannot overflow.
always_comb begin : tx_cnt_PROC
  if(int_clear_pending)
    int_tlp_cnt_b = {CNT_WD{1'b0}};
  else if(int_inc_cnt)
    int_tlp_cnt_b = int_tlp_cnt_r + 1'b1;
  else if(int_xdlh_grant)
    int_tlp_cnt_b = int_tlp_cnt_r - (int_eot_cnt - int_hv_req);
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

assign xtlh_tlp_pending = !(int_tlp_cnt_r == {CNT_WD{1'b0}});


endmodule
