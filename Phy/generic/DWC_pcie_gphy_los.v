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
// ---    $DateTime: 2020/02/14 05:18:19 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_los.v#6 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:  SerDes Dependent Module (SDM)
// -----------------------------------------------------------------------------
// --- This module generates the rxelectrical 
// --- 
// -----------------------------------------------------------------------------
module DWC_pcie_gphy_los #(
  parameter   TP = 0,                      // Clock to Q delay (simulator insurance)
  parameter   NL = 0
) (
  input                rst_n,                      // reset
  input [NL-1:0]       rxp,                        // serial receive data (pos)
  input [NL-1:0]       rxn,                        // serial receive data (neg)
  input [2:0]          rate,                       // current data rate
  input [NL-1:0]       rx_clock_off,
  input                rxelecidle_disable,         // gate the LoS
  input [3:0]          mac_phy_powerdown,
  `ifdef GPHY_ESM_SUPPORT
  input [NL-1:0]       esm_enable,
  input [NL*7-1:0]     esm_data_rate0,
  input [NL*7-1:0]     esm_data_rate1, 
  `endif // GPHY_ESM_SUPPORT
 
  output [NL-1:0]      rxelecidle_unfiltered,      // electrical idle detected
  output [NL-1:0]      rxelecidle_filtered,        // electrical idle detected filtered
  output [NL-1:0]      rxelecidle_noise
);

wire [NL-1:0] lane_rxelecidle_disable;

genvar lane;
generate
for (lane = 0; lane<NL; lane = lane + 1) begin : genloslane

assign lane_rxelecidle_disable[lane] = rxelecidle_disable || (mac_phy_powerdown == `GPHY_PDOWN_P2_NOBEACON);

//==============================================================================
// Los logic 
//==============================================================================
DWC_pcie_gphy_los_lane #(
    .TP (TP)
) u_phy_los_lane (                  
    .rst_n                          (rst_n),                         // reset                             
    .rxp                            (rxp [lane]),                        // serial receive data (pos)         
    .rxn                            (rxn [lane]),                        // serial receive data (neg)         
    .rate                           (rate),                      // current data rate 
    .rx_clock_off                   (rx_clock_off[lane]),                
    .rxelecidle_disable             (lane_rxelecidle_disable[lane]),           // gate the LoS                      
    `ifdef GPHY_ESM_SUPPORT
     .esm_enable                   (esm_enable          [lane]        ), 
     .esm_data_rate0               (esm_data_rate0      [lane*7+:7]   ), 
     .esm_data_rate1               (esm_data_rate1      [lane*7+:7]   ), 
    `endif // GPHY_ESM_SUPPORT
   
   
    .rxelecidle_filtered            (rxelecidle_filtered   [lane]),         // electrical idle detected filtered 
    .rxelecidle_unfiltered          (rxelecidle_unfiltered [lane]),      // electrical idle detected          
    .rxelecidle_filtered_with_noise (rxelecidle_noise      [lane])
);

end
endgenerate 

endmodule 
