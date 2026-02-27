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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/pipe_adapter.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module provides the pipe datapath interface/adapter
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pipe_adapter
#(
    parameter INST = 0, // The uniquifying parameter for each port logic instance
    parameter NL = `CX_NL,
    parameter TX_COEF_WD = 18,
    parameter AW            = `CX_ANB_WD,
    parameter TP = `TP,
    parameter WIDTH_WD = `CX_PHY_WIDTH_WD,
    parameter P_R_WD = `PCLK_RATE_WD
)
(
    input                         clk,
    input                         rst_n,
    

    input                         cfg_elastic_buffer_mode,
    input  [2:0]                  rate,
    input  [1:0]                  powerdown,

    output [3:0]                  pipe_powerdown,
    output     [WIDTH_WD-1:0]     pipe_width,
    output     [P_R_WD-1:0]       pipe_pclk_rate // extended to 4-bit from 3-bit for CCIX
);


`define DEFAULT_SUPPORT_POWER_STATE_PHY_SPECIFIC 2'b00


assign pipe_powerdown = ({`DEFAULT_SUPPORT_POWER_STATE_PHY_SPECIFIC, powerdown});

// PIPE Data Path Width
// 0 8 bits
// 1 16 bits
// 2 32 bits
// 3 64 bits
// 4 128 bits
// Core uses
// 1 8 bits
// 2 16 bits
// 4 32 bits
// 8 64 bits
// 16 128 bits
assign pipe_width =
                               (
           (`CX_PHY_NB_GEN1 ==   4) ? 2  :
           (`CX_PHY_NB_GEN1 ==   2) ? 1  :
                                      0 );



// PIPE PCLK rate
// 0 62.5 Mhz
// 1 125 Mhz
// 2 250 Mhz
// 3 500 Mhz
// 4 1000 Mhz
// 5 2000 MHz
// 6 Reserved
// 7 Reserved
// 8 625Mhz
// 9 781.25 Mhz
// A 1250 Mhz
// B 1562.5 Mhz
// C Reserved
// D Reserved
// E Reserved
// F Reserved
// g1 : 1s(dp)->500MHz(3)    / 1s,2s(dp)->250MHz(2)  / 2s->125MHz(1)  / 4s->62.5MHz(0)
// g1 : 1s(dp)->500MHz(3)    / 1s,2s(dp)->250MHz(2)  / 2s->125MHz(1)  / 4s->62.5MHz(0)
// g2 : 1s,2s(dp)->500MHz(3) / 2s->250MHz(2)         / 4s->125MHz(1)
// g3 : 1s->1000MHz(4)       / 2s->500MHz(3)         / 4s->250MHz(2)   / 8s->125MHz(1) / 16s->62.5MHz(0)
// g4 : 1s->N/A              / 2s->1000MHz(4)        / 4s->500MHz(3)   / 8s->250MHz(2) / 16s->125MHz(1)
// g5 : 1s->N/A              / 2s->2000MHz(5)        / 4s->1000MHz(4)  / 8s->500MHz(2) / 16s->250MHz(2)

assign pipe_pclk_rate =
                               (
           (`CX_PHY_SMODE_GEN1 == 4016)? 4  : // g1_4s_dt16 (1000Mhz)
           (`CX_PHY_SMODE_GEN1 == 408) ? 3  : // g1_4s_dt8 (500Mhz)
           (`CX_PHY_SMODE_GEN1 == 404) ? 2  : // g1_4s_dt4 (250Mhz)
           (`CX_PHY_SMODE_GEN1 == 402) ? 1  : // g1_4s_dt2 (125Mhz)
           (`CX_PHY_SMODE_GEN1 == 208) ? 4  : // g1_2s_dt8 (1000Mhz)
           (`CX_PHY_SMODE_GEN1 == 204) ? 3  : // g1_2s_dt4 (500Mhz)
           (`CX_PHY_SMODE_GEN1 == 202) ? 2  : // g1_2s_dt2 (250Mhz)
           (`CX_PHY_SMODE_GEN1 == 104) ? 4  : // g1_1s_dt4 (1000Mhz)
           (`CX_PHY_SMODE_GEN1 == 102) ? 3  : // g1_1s_dt2 (500Mhz)
           (`CX_PHY_SMODE_GEN1 ==   4) ? 0  : // g1_4s (62.5Mhz)
           (`CX_PHY_SMODE_GEN1 ==   2) ? 1  : // g1_2s (125Mhz)
                                         2 ); // g1_1s (250Mhz)


endmodule
