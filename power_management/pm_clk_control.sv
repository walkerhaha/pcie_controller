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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_clk_control.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module is responsible for generating clock related control signals
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_clk_control
    // Parameters
    #(
        parameter TP = `TP
    )
    (
    // Inputs
    input                       aux_clk,                    // aux clock
    input                       pwr_rst_n,                  // power on reset
    input                       aux_clk_active,             // aux clock active indication
    input                       pm_rst_sel_aux_clk,         // Select slow clock for aux_clk on reset
    input                       pm_linkst_sel_aux_clk,      // PM Link state select slow clock for aux_clk
    input                       pm_linkst_en_core_clk,      // enable core_clk
    input                       pm_l1sub_sel_aux_clk,       // l1 sub-states clock switch request
    input                       phystatus_if_sel_aux_clk,   // Wait for phystatus to be low after reset before switching to PCLK
    // Outputs
    output logic                pm_clk_sel_aux_clk,         // Aux clock switch select signal
    output logic                pm_clk_en_core_clk,         // Enable for core_clk 
    output logic                pm_clk_aux_clk_active       // aux_clk active indication
    ,output logic                pm_clk_aux_clk_inactive       // aux_clk inactive indication
);

logic ssel_aux_clk;

assign ssel_aux_clk = pm_rst_sel_aux_clk || pm_linkst_sel_aux_clk || pm_l1sub_sel_aux_clk || phystatus_if_sel_aux_clk;

pm_clk_control_fsm
 u_pm_clk_control_fsm (
  .sel_aux_clk        (ssel_aux_clk),
  .perst_sel_aux_clk  (pm_rst_sel_aux_clk),
  .en_core_clk        (pm_linkst_en_core_clk),
  .aux_clk_active     (aux_clk_active),
  .aux_clk            (aux_clk),
  .pwr_rst_n          (pwr_rst_n),
  .pm_en_core_clk     (pm_clk_fsm_en_core_clk),
  .pm_sel_aux_clk     (pm_clk_fsm_sel_aux_clk),
  .pm_aux_clk_active  (pm_clk_aux_clk_active)
  ,.pm_aux_clk_inactive  (pm_clk_aux_clk_inactive)
);

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : fsm_out_PROC
  if (!pwr_rst_n) begin
    pm_clk_en_core_clk <= #TP 1'b0;
    pm_clk_sel_aux_clk <= #TP 1'b1;
  end else begin
    pm_clk_en_core_clk <= #TP pm_clk_fsm_en_core_clk;
    pm_clk_sel_aux_clk <= #TP pm_clk_fsm_sel_aux_clk;
  end
end : fsm_out_PROC

endmodule
