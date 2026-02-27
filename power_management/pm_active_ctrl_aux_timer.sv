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
// ---    $DateTime: 2019/10/09 17:27:32 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_ctrl_aux_timer.sv#7 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- The following module provides a 1us clock enable reference to allow other modules to count time using aux_clk.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_active_ctrl_aux_timer
//#(
//    //parameter ...
//)
(
    input       aux_clk,
    input       pwr_rst_n,
    input [9:0] aux_clk_freq, // aux_clk frequency in MHz, 10 bits (1024 =~ 10^3) are needed to cover a 1000x range (1MHz-1GHz)
                              // aux_clk frequencies lower than 1MHz imply a loss of accuracy. A value of 0 is interpreted as 1024.

    output reg  aux_clk_en_1us // clock enable to mark 1us time intervals
);

parameter TP = `TP;                  // Clock to Q delay (simulator insurance)

reg [9:0] aux_timer;
wire [10:0] aux_time_1us; // The number of aux_clk cycles in a 1us interval.


assign aux_time_1us = (aux_clk_freq==0) ? 1024 : {1'b0, aux_clk_freq}; // 0 is treated as 1024

always @(posedge aux_clk or negedge pwr_rst_n) begin : aux_clk_en_1us_PROC
    if (!pwr_rst_n) begin
        aux_timer <= #TP 0;
        aux_clk_en_1us <= #TP 0;
    end else if (aux_timer >= (aux_time_1us - 1)) begin
        aux_timer <= #TP 0;
        aux_clk_en_1us <= #TP 1;
    end else begin
        aux_timer <= #TP aux_timer + 1;
        aux_clk_en_1us <= #TP 0;
    end
end


endmodule // pm_active_ctrl_aux_timer
