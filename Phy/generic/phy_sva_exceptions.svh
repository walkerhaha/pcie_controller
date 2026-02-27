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
// ---    $DateTime: 2020/09/18 02:33:28 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/phy_sva_exceptions.svh#11 $
// -----------------------------------------------------------------------------

// --------------------------------------------------------
// Disabling specific PIPE SVA failures
//
// The PIPE SVA checker which is part of VTB may flag PHY
// violations which are known or that will be fixed at a 
// later stage.
//
// The code below can be used to disable specific checks
// throughout the simulation
// --------------------------------------------------------

import uvm_pkg::*;

initial begin
  #0.2;

  `ifdef CX_PCIE_OVER_CIO_ENABLE
    // Disable Pipe SVA's for all lanes.
    //force `SUBSYS_PATH.pipe_assertions.disable_sva      = 1'b1; 
    // Disable Pipe SVA's for lanes 1-NL
    force `SUBSYS_PATH.pipe_assertions_protocol.disable_sva_perlane = {{(NL-1){1'b1}}, 1'b0}; 
    force `SUBSYS_PATH.pipe_assertions_datapath.disable_sva_perlane = {{(NL-1){1'b1}}, 1'b0}
    //force `SUBSYS_PATH.pipe_assertions.disabled_lanes = {{(NL-1){1'b1}}, 1'b0};
  `endif
    
  //  disabled  due to rate change in p2
   `PIPE_SVA_PER_LANE_OFF(`VTB_DUT_SUBSYS_PATH, pipe_mac_sva.a_pclk_not_running_P2) 
   
    
    
end

