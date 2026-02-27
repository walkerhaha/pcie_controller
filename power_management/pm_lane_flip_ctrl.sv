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
// ---    $DateTime: 2018/08/30 02:24:02 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_lane_flip_ctrl.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description: 
// --- Control of the lane flip logic in the controller
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_lane_flip_ctrl #(
  parameter NL = `CX_NL,
  parameter L2NL = NL==1 ? 1 : `CX_LOGBASE2(NL)  // log2 number of NL
)
(
  // Inputs
  input             aux_clk,
  input             pwr_rst_n,
  input             rx_lane_flip_en,
  input             tx_lane_flip_en,
  input [L2NL-1:0]  smlh_lane_flip_ctrl,
  input [NL-1:0]    mac_phy_rxpolarity,
  input             pm_update,
  input             pm_hold,
  // Outputs
  output [L2NL-1:0] pm_rx_lane_flip_ctrl,
  output [L2NL-1:0] pm_tx_lane_flip_ctrl,
  output [L2NL-1:0] pm_rx_pol_lane_flip_ctrl
);

// -----------------------------------------------------------------------------
// Net Declarations
// -----------------------------------------------------------------------------
wire  [L2NL-1:0]  int_rx_lane_flip_en_s;
wire  [L2NL-1:0]  int_tx_lane_flip_en_s;
wire              int_sel_epm_en_s;
wire              int_rxpolarity_or_s;
wire              int_rxpolarity_re_s;
wire  [L2NL-1:0]  int_rx_pol_lane_flip_en_s;
wire  [L2NL-1:0]  int_tx_lane_flip_en_mux_s;

// -----------------------------------------------------------------------------
// Register Declarations
// -----------------------------------------------------------------------------
reg               int_rxpolarity_or_r;
reg  [L2NL-1:0]   int_tx_lane_flip_en_r;

assign int_sel_epm_en_s = 1'b0;

assign int_rx_lane_flip_en_s = smlh_lane_flip_ctrl | (L2NL==1 ? rx_lane_flip_en : {rx_lane_flip_en, {(L2NL-1){1'b0}}});

shadow_reg
 u_rx_lane_flip_shadow [L2NL-1:0] (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (int_rx_lane_flip_en_s),
    // Outputs
    .shadow_data    (pm_rx_lane_flip_ctrl)
);

assign int_tx_lane_flip_en_s = smlh_lane_flip_ctrl | (L2NL==1 ? tx_lane_flip_en : {tx_lane_flip_en, {(L2NL-1){1'b0}}});

shadow_reg
 u_tx_lane_flip_shadow [L2NL-1:0] (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (int_tx_lane_flip_en_s),
    // Outputs
    .shadow_data    (pm_tx_lane_flip_ctrl)
);

assign int_rxpolarity_or_s = pm_hold ? int_rxpolarity_or_r : (|mac_phy_rxpolarity);
assign int_rxpolarity_re_s = int_rxpolarity_or_s && !int_rxpolarity_or_r;

// Updated when a change on rxpolarity is detected otherwise hold the value
assign int_tx_lane_flip_en_mux_s = int_rxpolarity_re_s ? int_tx_lane_flip_en_s : int_tx_lane_flip_en_r;

always @ (posedge aux_clk or negedge pwr_rst_n) begin : lane_flip_ctrl_PROC
  if(!pwr_rst_n) begin
    int_rxpolarity_or_r   <= #`TP 1'b0;
    int_tx_lane_flip_en_r <= #`TP {L2NL{1'b0}};
  end
  else begin
    int_rxpolarity_or_r   <= #`TP int_rxpolarity_or_s;
    int_tx_lane_flip_en_r <= #`TP int_tx_lane_flip_en_mux_s;
  end
end : lane_flip_ctrl_PROC

assign int_rx_pol_lane_flip_en_s = int_rxpolarity_or_r ? int_tx_lane_flip_en_r : int_tx_lane_flip_en_s;

shadow_reg
 u_rx_pol_lane_flip_shadow [L2NL-1:0] (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (int_rx_pol_lane_flip_en_s),
    // Outputs
    .shadow_data    (pm_rx_pol_lane_flip_ctrl)
);

endmodule
