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
// ---    $DateTime: 2020/10/02 12:40:52 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_shadow.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains shadow registers which are used to retain
// --- information during low power states.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_shadow
    // Parameters
    #(
        parameter INST = 0,
        parameter NL = 0
    )
    (
    // Inputs
    input                                       aux_clk,                // always on clock
    input                                       pwr_rst_n,              // power on reset
    input                                       smlh_link_up,           // Link status from smlh
    input                                       pm_hold,                // request to hold value
    input                                       pm_update,              // Update values
    input                                       rstctl_ltssm_enable,    // LTSSM enable to be shadowed in always on domain 
    input [2:0]                                 current_data_rate,      // Current data rate from LTSSM
    input                                       radm_idle,              // RADM Idle indication
    // Outputs
    output wire                                 pm_smlh_link_up,        // SMLH link status mirrored in always on domain
    output wire                                 pm_ltssm_enable,        // LTSSM enable shadowed in always on domain
    output wire [2:0]                           pm_current_data_rate    // Current data rate shadowed in always on domain
    ,
    output wire                                 pm_radm_idle_n            // RADM Idle active low

);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
parameter  TP = `TP;
localparam SHADOW_REG_SIZE = 5; // hardcoded to match the sum of the width of all signals
                                // input to the array of shadow registers

// ----------------------------------------------------------------------------
// Wire Declarations
// ----------------------------------------------------------------------------
wire    [SHADOW_REG_SIZE - 1 : 0]   int_shadow_in_s;
wire    [SHADOW_REG_SIZE - 1 : 0]   int_shadow_out_s;
wire                                int_sel_epm_en_s;

// ----------------------------------------------------------------------------
// Logic
// ----------------------------------------------------------------------------
assign int_sel_epm_en_s = 1'b0;

// Concatenate signals to be shadowed to create input bus to array of instances
assign int_shadow_in_s = {
smlh_link_up, rstctl_ltssm_enable, current_data_rate};

// Instantiate the shadow register
shadow_reg

#(.INST (INST)) u_shadow_reg[SHADOW_REG_SIZE - 1 : 0] (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (int_shadow_in_s),
    // Outputs
    .shadow_data    (int_shadow_out_s)
);

// Assignment of outputs from array of instances
assign {
pm_smlh_link_up, pm_ltssm_enable, pm_current_data_rate}
 = int_shadow_out_s;





shadow_reg

#(.INST (INST)) u_radm_idle_shadow_reg (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (!radm_idle),
    // Outputs
    .shadow_data    (pm_radm_idle_n)
);




endmodule
