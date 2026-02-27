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
// ---    $DateTime: 2019/06/06 16:32:01 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/phy_if_cpcie_mux.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module description:  This module contains MUX which drives the PHY interface
// output signals in CPCIE mode dependent on the PHY type.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module phy_if_cpcie_mux #(
    // Parameters
    parameter INST = 0,
    parameter PDWN_WIDTH = 2,
    parameter NL = 1,
    parameter PHY_NB = 1,
    parameter PHY_RATE_WD = (`CX_GEN5_SPEED_VALUE == 1) ? 3 : (`CX_GEN3_SPEED_VALUE == 1) ? 2 : 1,
    parameter PHY_WIDTH_WD = `CX_PHY_WIDTH_WD,
    parameter [(PDWN_WIDTH - 1) : 0] P1 = {PDWN_WIDTH{1'b0}},
    parameter ORIG_DATA_WD = PHY_NB * 8,
    parameter SERDES_DATA_WD = PHY_NB * 10,
    parameter PIPE_DATA_WD = (`CX_PIPE_SERDES_ARCH_VALUE) ? (NL * SERDES_DATA_WD) : (NL * ORIG_DATA_WD),
    parameter TX_DATAK_WD = NL * PHY_NB,
    parameter TX_DEEMPH_WD = 2,
    parameter PHY_TXEI_WD = `CX_PHY_TXEI_WD,
    parameter NL_X2 = NL * 2,
    parameter P_R_WD = `PCLK_RATE_WD
) (
    // Inputs
    input                           phy_type
    ,
    input [(PDWN_WIDTH - 1) : 0]      mac_phy_powerdown,
    input [(NL*PHY_TXEI_WD - 1) : 0]  mac_phy_txelecidle
    ,
    input [(PIPE_DATA_WD - 1) : 0]    mac_phy_txdata,
    input [(TX_DATAK_WD - 1) : 0]   mac_phy_txdatak,
    input [(NL - 1) : 0]            mac_phy_txdetectrx_loopback,
    input [(NL - 1) : 0]            mac_phy_txcompliance,
    input [(NL - 1) : 0]            mac_phy_rxpolarity,
    input [(PHY_WIDTH_WD -1) : 0]   mac_phy_width,
    input [P_R_WD-1 : 0]            mac_phy_pclk_rate,
    input [(NL - 1) : 0]            mac_phy_rxstandby
    // Outputs
    ,
    input [1 : 0]                             mac_phy_pclkreq_n,
    output logic [1 : 0]                      phy_if_cpcie_mux_pclkreq_n
    ,
    output logic [(PDWN_WIDTH - 1) : 0]       phy_if_cpcie_mux_powerdown,
    output logic [(NL*PHY_TXEI_WD - 1) : 0]   phy_if_cpcie_mux_txelecidle
    ,
    output logic [(PIPE_DATA_WD - 1) : 0]     phy_if_cpcie_mux_txdata,
    output logic [(TX_DATAK_WD - 1) : 0]      phy_if_cpcie_mux_txdatak,
    output logic [(NL - 1) : 0]               phy_if_cpcie_mux_txdetectrx_loopback,
    output logic [(NL - 1) : 0]               phy_if_cpcie_mux_txcompliance,
    output logic [(NL - 1) : 0]               phy_if_cpcie_mux_rxpolarity,
    output logic [(PHY_WIDTH_WD -1) : 0]      phy_if_cpcie_mux_width,
    output logic [P_R_WD-1 : 0]               phy_if_cpcie_mux_pclk_rate,
    output logic [(NL - 1) : 0]               phy_if_cpcie_mux_rxstandby
);

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire    int_bypass_mux_s;
wire    int_phy_type_match_s;

// ----------------------------------------------------------------------------
// Logic implementation
// ----------------------------------------------------------------------------
// When selectable PHY is not enabled the MUX is bypassed
assign int_bypass_mux_s = 1'b1;

// PHY type match
assign int_phy_type_match_s = (phy_type == `PHY_TYPE_CPCIE);


// ----------------------------------------------------------------------------
// mac_phy_pclkreq_n (used for ref clk removal)
// ----------------------------------------------------------------------------
// Array of MUX instances
phy_mux
 #(
    .INST   (INST)
) u_pclkreq_mux[1 : 0] (
    // Inputs
    .mac_to_phy         (mac_phy_pclkreq_n),
    .def_value          (2'b00),
    .bypass             (int_bypass_mux_s),
    .sel                (int_phy_type_match_s),
    // Outputs
    .phy_mux_mac_to_phy (phy_if_cpcie_mux_pclkreq_n)
);

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// Array of MUX instances
phy_mux
 #(
    .INST   (INST),
    .WIDTH  (PDWN_WIDTH)
) u_powerdown_mux (
    // Inputs
    .mac_to_phy         (mac_phy_powerdown),
    .def_value          (P1),
    .bypass             (int_bypass_mux_s),
    .sel                (int_phy_type_match_s),
    // Outputs
    .phy_mux_mac_to_phy (phy_if_cpcie_mux_powerdown)
);

// ----------------------------------------------------------------------------
// PHY txelecidle signal
// ----------------------------------------------------------------------------
wire    int_txelecidle_bypass_s;

// Txelecidle is always driven directly by the logic
assign int_txelecidle_bypass_s = 1'b1;

// Array of MUX instances
phy_mux
 #(
    .INST   (INST)
) u_txelecidle_mux [(NL*PHY_TXEI_WD - 1) : 0] (
    // Inputs
    .mac_to_phy         (mac_phy_txelecidle),
    .def_value          ({NL*PHY_TXEI_WD{1'b1}}),
    .bypass             (int_txelecidle_bypass_s),
    .sel                (int_phy_type_match_s),
    // Outputs
    .phy_mux_mac_to_phy (phy_if_cpcie_mux_txelecidle)
);

// ----------------------------------------------------------------------------
// Common Pipe Signals
// ----------------------------------------------------------------------------
struct packed {
  logic [PIPE_DATA_WD-1:0]  txdata;
  logic [TX_DATAK_WD-1:0]   txdatak;
  logic [NL-1:0]            txdetectrx_loopback;
  logic [NL-1:0]            txcompliance;
  logic [NL-1:0]            rxpolarity;
  logic [NL-1:0]            rxstandby;
  logic [PHY_WIDTH_WD-1:0]  width;
  logic [P_R_WD-1:0]        pclk_rate;
}  int_common_pipe_mux_in_s, int_common_pipe_mux_out_s, int_common_pipe_def_s;

localparam int  COMMON_PIPE_BUS_WD = $bits(int_common_pipe_mux_in_s);

// Mux input
always_comb begin: int_common_pipe_mux_in_s_PROC
  int_common_pipe_mux_in_s.txdata = mac_phy_txdata;
  int_common_pipe_mux_in_s.txdatak = mac_phy_txdatak;
  int_common_pipe_mux_in_s.txdetectrx_loopback = mac_phy_txdetectrx_loopback;
  int_common_pipe_mux_in_s.txcompliance = mac_phy_txcompliance;
  int_common_pipe_mux_in_s.rxpolarity = mac_phy_rxpolarity;
  int_common_pipe_mux_in_s.rxstandby = mac_phy_rxstandby;
  int_common_pipe_mux_in_s.width = mac_phy_width;
  int_common_pipe_mux_in_s.pclk_rate = mac_phy_pclk_rate;
end: int_common_pipe_mux_in_s_PROC

// Default values
always_comb begin: int_common_pipe_def_s_PROC
  int_common_pipe_def_s.txdata = '0;
  int_common_pipe_def_s.txdatak = '0;
  int_common_pipe_def_s.txdetectrx_loopback = '0;
  int_common_pipe_def_s.txcompliance = '0;
  int_common_pipe_def_s.rxpolarity = '0;
  int_common_pipe_def_s.rxstandby = '0;
  int_common_pipe_def_s.width = '0;
  int_common_pipe_def_s.pclk_rate = '0;
end: int_common_pipe_def_s_PROC

// Output assignment
always_comb begin: int_common_pipe_mux_out_s_PROC
  phy_if_cpcie_mux_txdata = int_common_pipe_mux_out_s.txdata;
  phy_if_cpcie_mux_txdatak = int_common_pipe_mux_out_s.txdatak;
  phy_if_cpcie_mux_txdetectrx_loopback = int_common_pipe_mux_out_s.txdetectrx_loopback;
  phy_if_cpcie_mux_txcompliance = int_common_pipe_mux_out_s.txcompliance;
  phy_if_cpcie_mux_rxpolarity = int_common_pipe_mux_out_s.rxpolarity;
  phy_if_cpcie_mux_rxstandby = int_common_pipe_mux_out_s.rxstandby;
  phy_if_cpcie_mux_width = int_common_pipe_mux_out_s.width;
  phy_if_cpcie_mux_pclk_rate = int_common_pipe_mux_out_s.pclk_rate;
end: int_common_pipe_mux_out_s_PROC

// Array of MUX instances
phy_mux
 #(
    .INST   (INST)
) u_common_pipe_mux [(COMMON_PIPE_BUS_WD - 1) : 0] (
    // Inputs
    .mac_to_phy         (int_common_pipe_mux_in_s),
    .def_value          (int_common_pipe_def_s),
    .bypass             (int_bypass_mux_s),
    .sel                (int_phy_type_match_s),
    // Outputs
    .phy_mux_mac_to_phy (int_common_pipe_mux_out_s)
);



  


endmodule
