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

// -----------------------------------------------------------------------------
// ---  RCS information:
// ---    $Author: neira $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/DWC_pcie_pm_pkg.svh#6 $
// -----------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_PM_PKG__SVH__
`define __GUARD__DWC_PCIE_PM_PKG__SVH__

// -----------------------------------------------------------------------------
// --- Package Description: Enumerated types to define PM FSM state encodings
// -----------------------------------------------------------------------------

package DWC_pcie_pm_pkg;





// -----------------------------------------------------------------------------
// Parameter definitions
// -----------------------------------------------------------------------------
  parameter NL                      = `CX_NL;
  parameter PWDN_WIDTH              = `CX_PHY_PDOWN_WD;
  parameter P1CPM                   = `CX_PIPE43_P1CPM_ENCODING;
  parameter CORE_SYNC_DEPTH         = `CX_PCIE_SYNC_DEPTH;
  parameter PHY_RATE_WD = (`CX_GEN5_SPEED_VALUE == 1) ? 3 : (`CX_GEN3_SPEED_VALUE == 1) ? 2 : 1;

parameter RXSTATUS_WIDTH = 3;
parameter [(PWDN_WIDTH - 1) : 0] P0 = 4'h0;
parameter [(PWDN_WIDTH - 1) : 0] P0S = 4'h1;
parameter [(PWDN_WIDTH - 1) : 0] P1 = 4'h2;
parameter [(PWDN_WIDTH - 1) : 0] P2 = 4'h3;
parameter [2:0] RX_PRESENT = 3'h3;
parameter RXSTATUS_WD = 3;

endpackage // DWC_pcie_pm_ctrl_package

`endif // __GUARD__DWC_PCIE_PM_PKG__SVH__
