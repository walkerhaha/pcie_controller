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
// ---    $DateTime: 2019/10/03 14:27:33 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_idle_detect.sv#2 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// RADM Idle detection: This module implements a shift register, the depth
// of which has been determined based on the number of pipeline stages in the design.
// The shift register is loaded either when a request is presented at the interface
// or when there is data in one of the pipeline stages. The shift register is unloaded
// when there is nothing pending in the RADM or no request is active. When the shift
// register has been fully unloaded the idle indication is asserted.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
 
module radm_idle_detect
  #(
    parameter TP  = `TP,
    parameter DEPTH = 3
  ) 
                         (
  input         clk,
  input         rst_n,
  input         req,
  input         pending,
  output logic  radm_idle
);

logic [(DEPTH - 1) : 0] idle_r;
logic [(DEPTH - 1) : 0] shift_in_s;
logic                   not_idle_s;

assign not_idle_s = req || pending;

assign shift_in_s = {not_idle_s, idle_r[(DEPTH - 1) : 1]};

always_ff @(posedge clk or negedge rst_n) begin : idle_PROC
  if(!rst_n) begin
    idle_r <= #TP {DEPTH{1'b0}};
  end
  else begin
    idle_r <= #TP shift_in_s;
  end
end : idle_PROC

assign radm_idle = !(|shift_in_s);

endmodule
