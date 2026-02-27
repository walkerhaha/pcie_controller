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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/rxeidle_squelch.sv#4 $
// -------------------------------------------------------------------------
// --- Description:
// --- Captures negedges on rxelecidle that come in from the PHY.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rxeidle_squelch (
  output ophy_mac_rxelecidle,
  input  iphy_mac_rxelecidle,
  input  aux_clk,
  input  rst_n
);

  localparam SYNC_DEPTH = 2;

  reg    pc_rxelecidle;
  always @(posedge aux_clk or negedge iphy_mac_rxelecidle)
  begin : ResetSet_PROC
      if (!iphy_mac_rxelecidle)
        pc_rxelecidle <= 1'b0;
      else
        pc_rxelecidle <= 1'b1;
  end

  //double reg
    DWC_pcie_ctl_bcm41
    
  #(
    .WIDTH      (1),
    .RST_VAL    (1),
    .F_SYNC_TYPE (SYNC_DEPTH)
  ) u_sync (
    .clk_d      (aux_clk),
    .rst_d_n    (rst_n),
    .data_s     (pc_rxelecidle),
    .data_d     (ophy_mac_rxelecidle)
  );

endmodule
