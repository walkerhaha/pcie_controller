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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_cfg_pme.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module manages the latching of the cdm pme capabilities
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_cfg_pme
  // Parameters
  #(
    parameter TP = `TP,
    parameter INST = 0,
    parameter NF = 1,
    parameter NVFUNC = 1,
    parameter NFUNC_WD = 1
  )
  (
  // Inputs
  input                             aux_clk,
  input                             pwr_rst_n,
  input [(NF - 1) : 0]              cfg_upd_pme_cap,
  input [((NF*5) - 1) : 0]          cfg_pme_cap,
  input                             pm_core_rst_done,
  input                             pm_active_state,
  // Outputs
  output reg [((5*NF) - 1) : 0]     pm_cfg_pme_cap
);

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------

// when device is programmed to enable the power management message event
// generation, according to spec, the capability of PME of each D state 
// will allow to issue pme event message.
always @(posedge aux_clk or negedge pwr_rst_n)
begin : update_pme_cap

    integer FUNC_NUM;

    if (!pwr_rst_n)
    begin
        for(FUNC_NUM = 0; FUNC_NUM < NF; FUNC_NUM = FUNC_NUM + 1)
      // spyglass disable_block NonConstReset-ML
      // SMD: Invalid reset condition, RHS should be a static value. 
      // SJ: FUNC_NUM is a constant which is used in the definition of PME_SUPPORT. 
            pm_cfg_pme_cap[((5*FUNC_NUM) + 4) -: 5] <= #TP `PME_SUPPORT;
      // spyglass enable_block NonConstReset-ML
    end
    else
    begin
        for(FUNC_NUM = 0; FUNC_NUM < NF; FUNC_NUM = FUNC_NUM + 1)
        begin
            if (cfg_upd_pme_cap[FUNC_NUM])
                pm_cfg_pme_cap[((5*FUNC_NUM) + 4) -: 5] <= #TP cfg_pme_cap[((5*FUNC_NUM) + 4) -: 5];
        end
    end
end


endmodule

