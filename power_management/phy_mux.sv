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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/phy_mux.sv#2 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module description: This module contains PHY interface mux 
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module phy_mux #(
    parameter INST = 0,
    parameter WIDTH = 1
) (
    // Inputs
    input [(WIDTH - 1) : 0]         mac_to_phy, // MAC signalling to PHY
    input [(WIDTH - 1) : 0]         def_value,  // Default value to PHY
    input                           bypass,     // Bypass the MUX logic
    input                           sel,        // Select for first MUX
    // Outputs
    output wire [(WIDTH - 1) : 0]   phy_mux_mac_to_phy  // Output to PHY
);

// -----------------------------------------------------------------------------
// Net Declarations
// -----------------------------------------------------------------------------
wire [(WIDTH - 1) : 0]  int_phy_type_mux_out_s;


// -----------------------------------------------------------------------------
// Logic implementation
// -----------------------------------------------------------------------------

// First MUX selects between MAC output and default value
assign int_phy_type_mux_out_s = sel ? mac_to_phy : def_value;

// Second MUX is bypass MUX which passes input directly to output
assign phy_mux_mac_to_phy = bypass ? mac_to_phy : int_phy_type_mux_out_s;

endmodule

