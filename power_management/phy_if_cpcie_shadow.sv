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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/phy_if_cpcie_shadow.sv#7 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module description:  This module contains PHY interface outputs shadowing
// logic
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module phy_if_cpcie_shadow #(
    // Parameters
    parameter INST = 0,
    parameter NL = 1,
    parameter PHY_RATE_WD = (`CX_GEN5_SPEED_VALUE == 1) ? 3 : (`CX_GEN3_SPEED_VALUE == 1) ? 2 : 1,
    parameter PHY_WIDTH_WD = `CX_PHY_WIDTH_WD,
    parameter TX_DEEMPH_WD = 2,
    parameter NL_X2 = NL * 2,
    parameter P_R_WD = `PCLK_RATE_WD
) (
    // Shadow register signals
    input                           clk,
    input                           rst_n,
    input                           hold_data,
    input                           update,
    input                           hold_perst,
    input                           update_perst
    ,
    input                           cfg_elastic_buffer_mode
    ,
    input [31:0]                    cfg_phy_control
    // PHY interface signals
    ,
    input [(NL - 1) : 0]            mac_phy_txdetectrx_loopback,
    input [(NL - 1) : 0]            mac_phy_txcompliance,
    input [(NL - 1) : 0]            mac_phy_rxpolarity,
    input [(PHY_WIDTH_WD -1) : 0]   mac_phy_width,
    input [P_R_WD-1 : 0]            mac_phy_pclk_rate,
    input [(NL - 1) : 0]            mac_phy_rxstandby
    // Outputs
    ,
    output logic [(NL - 1) : 0]               phy_if_cpcie_shadow_txdetectrx_loopback,
    output logic [(NL - 1) : 0]               phy_if_cpcie_shadow_txcompliance,
    output logic [(NL - 1) : 0]               phy_if_cpcie_shadow_rxpolarity,
    output logic [(PHY_WIDTH_WD -1) : 0]      phy_if_cpcie_shadow_width,
    output logic [P_R_WD-1 : 0]               phy_if_cpcie_shadow_pclk_rate,
    output logic [(NL - 1) : 0]               phy_if_cpcie_shadow_rxstandby
    ,
    output logic                             phy_if_elasticbuffermode
    ,
    output logic [31:0]                      phy_if_cfg_phy_control
);

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire    int_en_shadow_s;
wire    int_en_l2_shadow_s;

// ----------------------------------------------------------------------------
// Logic implementation
// ----------------------------------------------------------------------------
// Shadow logic is only enabled if support for power gating in L1 substates in enabled
assign int_en_shadow_s = 1'b0;

assign int_en_l2_shadow_s = 1'b0;

// ----------------------------------------------------------------------------
// Common Pipe Signals
// ----------------------------------------------------------------------------
struct packed {
  logic [NL-1:0]            txdetectrx_loopback;
  logic [NL-1:0]            txcompliance;
  logic [NL-1:0]            rxpolarity;
  logic [NL-1:0]            rxstandby;
  logic [PHY_WIDTH_WD-1:0]  width;
  logic [P_R_WD-1:0]        pclk_rate;
}  int_common_pipe_data_in_s, int_common_pipe_data_out_s;

localparam int  COMMON_PIPE_BUS_WD = $bits(int_common_pipe_data_in_s);

wire global_hold;
wire global_update;
wire global_shadow;

assign global_hold   = hold_perst   || hold_data;
assign global_update = update_perst || update;
assign global_shadow = int_en_l2_shadow_s || int_en_shadow_s;

// MUX input
always_comb begin: int_common_pipe_data_in_s_PROC
  int_common_pipe_data_in_s.txdetectrx_loopback = mac_phy_txdetectrx_loopback;
  int_common_pipe_data_in_s.txcompliance = mac_phy_txcompliance;
  int_common_pipe_data_in_s.rxpolarity = mac_phy_rxpolarity;
  int_common_pipe_data_in_s.rxstandby = mac_phy_rxstandby;
  int_common_pipe_data_in_s.width = mac_phy_width;
  int_common_pipe_data_in_s.pclk_rate = mac_phy_pclk_rate;
end: int_common_pipe_data_in_s_PROC

// Output assignment
always_comb begin: int_common_pipe_data_out_s_PROC
  phy_if_cpcie_shadow_txdetectrx_loopback = int_common_pipe_data_out_s.txdetectrx_loopback;
  phy_if_cpcie_shadow_txcompliance = int_common_pipe_data_out_s.txcompliance;
  phy_if_cpcie_shadow_rxpolarity = int_common_pipe_data_out_s.rxpolarity;
  phy_if_cpcie_shadow_rxstandby = int_common_pipe_data_out_s.rxstandby;
  phy_if_cpcie_shadow_width = int_common_pipe_data_out_s.width;
  phy_if_cpcie_shadow_pclk_rate = int_common_pipe_data_out_s.pclk_rate;
end: int_common_pipe_data_out_s_PROC

// Array of shadow register instances
// Note mac_phy_txdetectrx_loopback, mac_phy_txcompliance, and mac_phy_rxpolarity are shadowed in L1.2. This is covered by the first 3 * NL replications of int_en_shadow_s.
// Note mac_phy_rxstandby, mac_phy_width, and mac_phy_pclk_rate are being shadowed in L2 aswell as L1.2 this is to prevent a rate/width change in L2. This is covered by the NL + 2 + P_R_WD replications of shadow_width_rate_s.
shadow_reg
 #(
    .INST   (INST)
) u_common_pipe_shadow [(COMMON_PIPE_BUS_WD - 1) : 0] (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (int_common_pipe_data_in_s),
    // Outputs
    .shadow_data    (int_common_pipe_data_out_s)
);






// GPIO control bus for PHY
shadow_reg

 #(
    .INST               (INST),
    .WIDTH              (32),
    .EN_HOLD_BYPASS_MUX (1'b0),
    .RESET_VALUE        (`DEFAULT_PHY_CONTROL)
) u_cfg_phy_control (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (cfg_phy_control),
    // Outputs
    .shadow_data    (phy_if_cfg_phy_control)
);



shadow_reg
 #(
    .INST   (INST)
) u_elastic_buffer_shadow (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (cfg_elastic_buffer_mode),
    // Outputs
    .shadow_data    (phy_if_elasticbuffermode)
);

endmodule
