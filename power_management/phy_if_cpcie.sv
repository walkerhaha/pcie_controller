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
// ---    $DateTime: 2020/09/28 04:46:26 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/phy_if_cpcie.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module description: This module contains MUX logic on PHY interface
// outputs as well as the shadowing logic for state retention.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"


 module phy_if_cpcie #(
    // Parameters
    parameter INST = 0,
    parameter PDWN_WIDTH = 2,
    parameter NL = 1,
    parameter PHY_NB = 1,
    parameter PHY_RATE_WD = (`CX_GEN5_SPEED_VALUE == 1) ? 3 : (`CX_GEN3_SPEED_VALUE == 1) ? 12 : 1,
    parameter PHY_WIDTH_WD = `CX_PHY_WIDTH_WD,
    parameter [(PDWN_WIDTH - 1) : 0] P1 = {PDWN_WIDTH{1'b0}},
    parameter ORIG_DATA_WD = PHY_NB * 8,
    parameter SERDES_DATA_WD = PHY_NB * 10,
    parameter PIPE_DATA_WD = (`CX_PIPE_SERDES_ARCH_VALUE) ? (NL * SERDES_DATA_WD) : (NL * ORIG_DATA_WD),
    parameter TX_DATAK_WD = NL * PHY_NB,
    parameter TX_DEEMPH_WD = 2,
    parameter PHY_TXEI_WD = `CX_PHY_TXEI_WD,
    parameter NL_X2 = NL * 2,
    parameter L2NL = 1,
    parameter P_R_WD = `PCLK_RATE_WD
) (
    // Inputs
    input                           clk,
    input                           rst_n,
    input                           hold_data,
    input                           update,
    input                           hold_perst,
    input                           update_perst,
    input                           phy_type
    ,
    input [31:0]                    cfg_phy_control
    ,
    input                           cfg_elastic_buffer_mode
    ,
    input [(PDWN_WIDTH - 1) : 0]      mac_phy_powerdown,
    input [(NL*PHY_TXEI_WD - 1) : 0]  mac_phy_txelecidle
    ,
    input [(PIPE_DATA_WD - 1) : 0]    mac_phy_txdata,
    input [(TX_DATAK_WD - 1) : 0]   mac_phy_txdatak,
    input [(NL - 1) : 0]            mac_phy_txdetectrx_loopback,
    input [(NL - 1) : 0]            mac_phy_txcompliance,
    input [(NL - 1) : 0]            mac_phy_rxpolarity,
    input [(PHY_WIDTH_WD - 1) : 0]  mac_phy_width,
    input [P_R_WD-1 : 0]            mac_phy_pclk_rate,
    input [(NL - 1) : 0]            mac_phy_rxstandby,
    input [(NL - 1) : 0]            ltssm_rxpolarity
    ,
    input                           rx_lane_flip_en,
    input                           tx_lane_flip_en,
    input [L2NL-1:0]                smlh_lane_flip_ctrl
    // Outputs
    ,
    output wire [31:0]                      phy_if_cfg_phy_control
    ,
    input [1 : 0]                           mac_phy_pclkreq_n,
    output wire [1 : 0]                     phy_if_cpcie_pclkreq_n
    ,
    output wire [(PDWN_WIDTH - 1) : 0]      phy_if_cpcie_powerdown,
    output wire [(NL*PHY_TXEI_WD - 1) : 0]  phy_if_cpcie_txelecidle
    ,
    output wire [(PIPE_DATA_WD - 1) : 0]      phy_if_cpcie_txdata,
    output wire [(TX_DATAK_WD - 1) : 0]     phy_if_cpcie_txdatak,
    output wire [(NL - 1) : 0]              phy_if_cpcie_txdetectrx_loopback,
    output wire [(NL - 1) : 0]              phy_if_cpcie_txcompliance,
    output wire [(NL - 1) : 0]              phy_if_cpcie_rxpolarity,
    output wire [(PHY_WIDTH_WD -1) : 0]     phy_if_cpcie_width,
    output wire [P_R_WD-1 : 0]              phy_if_cpcie_pclk_rate,
    output wire [(NL - 1) : 0]              phy_if_cpcie_rxstandby
    ,
    output wire                             phy_if_cpcie_phy_type
    ,
    output wire [L2NL - 1 : 0]              pm_rx_lane_flip_ctrl,
    output wire [L2NL - 1 : 0]              pm_tx_lane_flip_ctrl,
    output wire [L2NL - 1 : 0]              pm_rx_pol_lane_flip_ctrl
    ,
    output wire                             phy_if_elasticbuffermode
);

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire [(NL - 1) : 0] int_cpcie_txdetectrx_loopback;
wire [(NL - 1) : 0] int_cpcie_txcompliance;
wire [(NL - 1) : 0] int_cpcie_rxpolarity;
wire [(PHY_WIDTH_WD -1) : 0] int_cpcie_width;
wire [P_R_WD-1 : 0] int_cpcie_pclk_rate;
wire [(NL - 1) : 0] int_cpcie_rxstandby;


// ----------------------------------------------------------------------------
// PHY type
// ----------------------------------------------------------------------------
    assign phy_if_cpcie_phy_type = `CX_PHY_TYPE;

// ----------------------------------------------------------------------------
// PHY interface MUX
// ----------------------------------------------------------------------------
phy_if_cpcie_mux
 #(
    // Parameters
    .INST           (INST),
    .PDWN_WIDTH     (PDWN_WIDTH),
    .NL             (NL),
    .PHY_NB         (PHY_NB),
    .TX_DEEMPH_WD   (TX_DEEMPH_WD),
    .PHY_RATE_WD    (PHY_RATE_WD),
    .PHY_WIDTH_WD   (PHY_WIDTH_WD),
    .P1             (P1),
    .NL_X2          (NL_X2)
) u_phy_if_cpcie_mux (
    // Inputs
    .phy_type                               (phy_if_cpcie_phy_type)
    ,
    .mac_phy_powerdown                      (mac_phy_powerdown),
    .mac_phy_txelecidle                     (mac_phy_txelecidle)
    ,
    .mac_phy_txdata                         (mac_phy_txdata),
    .mac_phy_txdatak                        (mac_phy_txdatak),
    .mac_phy_txdetectrx_loopback            (mac_phy_txdetectrx_loopback),
    .mac_phy_txcompliance                   (mac_phy_txcompliance),
    .mac_phy_rxpolarity                     (mac_phy_rxpolarity),
    .mac_phy_width                          (mac_phy_width),
    .mac_phy_pclk_rate                      (mac_phy_pclk_rate),
    .mac_phy_rxstandby                      (mac_phy_rxstandby)
    // Outputs
    ,
    .mac_phy_pclkreq_n                      (mac_phy_pclkreq_n),
    .phy_if_cpcie_mux_pclkreq_n             (phy_if_cpcie_pclkreq_n)
    ,
    .phy_if_cpcie_mux_powerdown             (phy_if_cpcie_powerdown),
    .phy_if_cpcie_mux_txelecidle            (phy_if_cpcie_txelecidle)
    ,
    .phy_if_cpcie_mux_txdata                (phy_if_cpcie_txdata),
    .phy_if_cpcie_mux_txdatak               (phy_if_cpcie_txdatak),
    .phy_if_cpcie_mux_txdetectrx_loopback   (int_cpcie_txdetectrx_loopback),
    .phy_if_cpcie_mux_txcompliance          (int_cpcie_txcompliance),
    .phy_if_cpcie_mux_rxpolarity            (int_cpcie_rxpolarity),
    .phy_if_cpcie_mux_width                 (int_cpcie_width),
    .phy_if_cpcie_mux_pclk_rate             (int_cpcie_pclk_rate),
    .phy_if_cpcie_mux_rxstandby             (int_cpcie_rxstandby)
);

// ----------------------------------------------------------------------------
// PHY interface Shadowing
// ----------------------------------------------------------------------------
phy_if_cpcie_shadow
 #(
    // Parameters
    .INST           (INST),
    .NL             (NL),
    .TX_DEEMPH_WD   (TX_DEEMPH_WD),
    .PHY_RATE_WD    (PHY_RATE_WD),
    .PHY_WIDTH_WD   (PHY_WIDTH_WD),
    .NL_X2          (NL_X2)
) u_phy_if_cpcie_shadow (
    // Inputs
    .clk                                    (clk),
    .rst_n                                  (rst_n),
    .hold_data                              (hold_data),
    .update                                 (update),
    .hold_perst                             (hold_perst),
    .update_perst                           (update_perst)
    ,
    .cfg_phy_control                        (cfg_phy_control)
    ,
    .cfg_elastic_buffer_mode                (cfg_elastic_buffer_mode)
    ,
    .mac_phy_txdetectrx_loopback            (int_cpcie_txdetectrx_loopback),
    .mac_phy_txcompliance                   (int_cpcie_txcompliance),
    .mac_phy_rxpolarity                     (int_cpcie_rxpolarity),
    .mac_phy_width                          (int_cpcie_width),
    .mac_phy_pclk_rate                      (int_cpcie_pclk_rate),
    .mac_phy_rxstandby                      (int_cpcie_rxstandby)
    // Outputs
    ,
    .phy_if_cfg_phy_control                    (phy_if_cfg_phy_control)
    ,
    .phy_if_cpcie_shadow_txdetectrx_loopback   (phy_if_cpcie_txdetectrx_loopback),
    .phy_if_cpcie_shadow_txcompliance          (phy_if_cpcie_txcompliance),
    .phy_if_cpcie_shadow_rxpolarity            (phy_if_cpcie_rxpolarity),
    .phy_if_cpcie_shadow_width                 (phy_if_cpcie_width),
    .phy_if_cpcie_shadow_pclk_rate             (phy_if_cpcie_pclk_rate),
    .phy_if_cpcie_shadow_rxstandby             (phy_if_cpcie_rxstandby)
    ,
    .phy_if_elasticbuffermode                  (phy_if_elasticbuffermode)
);

pm_lane_flip_ctrl
 #(
  .NL   (NL),
  .L2NL (L2NL)
) u_lane_flip_ctrl (
  // Inputs
  .aux_clk                    (clk),
  .pwr_rst_n                  (rst_n),
  .rx_lane_flip_en            (rx_lane_flip_en), 
  .tx_lane_flip_en            (tx_lane_flip_en),
  .smlh_lane_flip_ctrl        (smlh_lane_flip_ctrl),
  .mac_phy_rxpolarity         (ltssm_rxpolarity),
  .pm_update                  (update),
  .pm_hold                    (hold_data),
  // Outputs
  .pm_rx_lane_flip_ctrl       (pm_rx_lane_flip_ctrl),
  .pm_tx_lane_flip_ctrl       (pm_tx_lane_flip_ctrl),
  .pm_rx_pol_lane_flip_ctrl   (pm_rx_pol_lane_flip_ctrl)
);

endmodule
