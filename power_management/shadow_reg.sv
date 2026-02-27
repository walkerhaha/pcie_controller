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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/shadow_reg.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description: This module contains shadow registers which are
// --- used to retain information during low power states.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module shadow_reg
    // Parameters
    #(
        parameter INST = 0,
        parameter RESET_VALUE = 0,
        parameter EN_HOLD_BYPASS_MUX = 1'b1,
        parameter DIS_SHADOW_MUX = 1'b0,
        parameter WIDTH = 1
    )
    (
    // Inputs
    input                         clk,        // Clock
    input                         rst_n,      // Asynchronous reset de-assertion synchronous to clk
    input                         en_shadow,  // Enabling the shadow register if set to 0 the shadow register is bypassed
    input                         hold_data,  // request to hold value
    input                         update,     // Update values
    input [(WIDTH - 1) : 0]       data,       // Data to be shadowed
    // Outputs
    output wire [(WIDTH - 1) : 0] shadow_data // Shadowed data
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
parameter  TP = `TP;

// ----------------------------------------------------------------------------
// Register Declarations
// ----------------------------------------------------------------------------
reg [(WIDTH - 1) : 0] int_data_r;

// ----------------------------------------------------------------------------
// Wire Declarations
// ----------------------------------------------------------------------------
wire  [(WIDTH - 1) : 0] int_data_hold_s;

// ----------------------------------------------------------------------------
// Shadow register 
// ----------------------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        int_data_r <= #TP RESET_VALUE;
    else
    begin
        if(hold_data)
            int_data_r <= #TP int_data_r;
        else if(update)
            int_data_r <= #TP data;
    end
end

// With EN_HOLD_BYPASS_MUX set to 1 this MUX will be used to bypass the shadow register
// when hold is cleared.
// With EN_HOLD_BYPASS_MUX set to 0 this MUX will be bypassed and the shadow register will
// be passed through
assign int_data_hold_s = EN_HOLD_BYPASS_MUX ? (hold_data ? int_data_r : data) : int_data_r;

// Note if the parameter DIS_SHADOW_MUX is set there will be no MUX
// This will prevent the possibility of a timing loop if the shadowed 
// data is feedback to the input data
generate
  if ( DIS_SHADOW_MUX ) begin : shadow_mux
    assign shadow_data = int_data_hold_s;
  end
  else begin : shadow_mux
    assign shadow_data = en_shadow ? int_data_hold_s : data;
  end
endgenerate

endmodule
