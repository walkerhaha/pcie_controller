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
// ---    $DateTime: 2020/01/17 06:46:25 $
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pma.v#16 $
// -------------------------------------------------------------------------
// --- Module Description: xN SerDes module for the generic PHY
// -----------------------------------------------------------------------------

module DWC_pcie_gphy_pma #(
  parameter   TP = -1,                               // Clock to Q delay (simulator insurance)
  parameter   PIPE_NB  = -1,
  parameter   WIDTH_WD = -1, 
  parameter   NL = -1                                // Nr of lanes
) (
// general inputs
  input                   refclk,                   // Reference Clock
  input                   txbitclk,                 // Transmit bit clock
  input                   txclk,                    // Transmit symbol clock
  input                   serdes_arch,
  input  [WIDTH_WD-1:0]   rxwidth,
  
  input  [NL-1:0]         sdm_pma_reset_n,          // Reset
  input  [3:0]            sdm_pma_powerdown,        // power state  
  input                   mac_phy_sris_mode,    
  input                   cdr_fast_lock,
  input  [NL*3-1:0]       sdm_pma_rate,
  input  [NL*3-1:0]       sdm_pma_curr_rate,        // Current operating rate
  input  [NL-1:0]         mac_phy_rxstandby,   
  // transmit inputs
  input [NL-1:0]          sdm_pma_rx_clock_off,             // clock is turned off in P1
  input [NL-1:0]          sdm_pma_loopback,         // PCI-E loopback
  
  input [NL-1:0]          sdm_pma_txdetectrx,       // Send receiver detection sequence; placeholder
  input [NL-1:0]          sdm_pma_txelecidle,       // Enable Transmitter Electical Idle
  input [NL-1:0]          sdm_pma_beacongen,        // Instruct the SerDes to generate a beacon signal

  // receive inputs
  input [NL-1:0]          sdm_pma_rxpolarity,       // Invert receive data
  input [NL-1:0]          rxp,                      // Serial receive data (pos)
  input [NL-1:0]          rxn,                      // Serial receive data (neg)
  input [NL-1:0]          rxelecidle_disable,       // L1sub power saving measure
  input [NL-1:0]          txcommonmode_disable,     // L1sub power saving measure
  input                   rxsymclk_random_drift_en,
  
  input [(NL*10)-1:0]     sdm_pma_txdata_10b,       // 1 symbol parallel transmit data
  input [NL-1:0]          sdm_pma_txdatavalid_10b,  // ignore a byte or word on the data interface
  input [NL-1:0]          sdm_pma_txstartblock_10b, // first byte of the data interface is the first byte of the block.
  input [NL*2-1:0]        sdm_pma_txsynchdr_10b,    // sync header to use in the next 130b block
`ifdef GPHY_ESM_SUPPORT
  input [NL-1:0]          phy_reg_esm_enable,
  input [NL*7-1:0]        phy_reg_esm_data_rate0,
  input [NL*7-1:0]        phy_reg_esm_data_rate1,
`endif // GPHY_ESM_SUPPORT  

  input [NL-1:0]           los_rxelecidle_filtered,   
  input [NL-1:0]           los_rxelecidle_unfiltered, 

  // transmit outputs
  output [NL-1:0]         txp,                      // Serial transmit data (pos)
  output [NL-1:0]         txn,                      // Serial transmit data (neg)

  // receive outputs
  output [(NL*10)-1:0]    pma_sdm_rxdata_10b,       // 1 symbol parallel receive data
  output [NL-1:0]         pma_pm_beacondetected,    // beacon detected by receiver
  output [NL-1:0]         pma_sdm_rxdetected,       // receiver detected signaling,
  output [NL-1:0]         pma_sdm_recvdclk,         // recovered receive byte clock
  output [NL-1:0]         pma_sdm_recvdclk_pipe,
  output [NL-1:0]         pma_sdm_rcvdrst_n,        // recovered reset_n
  output [NL-1:0]         pma_serdes_rx_valid,
  output [NL-1:0]         pma_sdm_recvdclk_stopped

);

// =============================================================================
genvar lane;
generate
for (lane = 0; lane<NL; lane = lane + 1) begin : genpma

DWC_pcie_gphy_pma_lane #(
    .TP (TP),
    .WIDTH_WD  (WIDTH_WD)
) u_serdes_lane (
// inputs
    .refclk                     (refclk                                       ),
    .txbitclk                   (txbitclk                                     ),
    .txclk                      (txclk                                        ),
    
    .serdes_arch                (serdes_arch                                  ),
    .rxwidth                    (rxwidth                                      ),
    
    .pma_reset_n                (sdm_pma_reset_n           [lane]             ),  
    .pma_powerdown              (sdm_pma_powerdown                            ),  
    .rxsymclk_random_drift_en   (rxsymclk_random_drift_en                     ),
    .sris_mode                  (mac_phy_sris_mode                            ),
    .pma_rate                   (sdm_pma_rate              [lane*3+:3]        ),
    .pma_curr_rate              (sdm_pma_curr_rate         [lane*3+:3]        ),       
    .mac_phy_rxstandby          (mac_phy_rxstandby         [lane]             ),

    .pma_rx_clock_off           (sdm_pma_rx_clock_off      [lane]             ),  
    .pma_loopback               (sdm_pma_loopback          [lane]             ),
    .pma_txelecidle             (sdm_pma_txelecidle        [lane]             ),
    .pma_beacongen              (sdm_pma_beacongen         [lane]             ),

    .pma_txdetectrx             (sdm_pma_txdetectrx        [lane]             ),
    .pma_rxpolarity             (sdm_pma_rxpolarity        [lane]             ),
    .rxp                        (rxp                       [lane]             ),
    .rxn                        (rxn                       [lane]             ),
    
    .rxelecidle_disable         (rxelecidle_disable        [lane]             ), 
    .txcommonmode_disable       (txcommonmode_disable      [lane]             ),
     
    .pma_txdata_10b             (sdm_pma_txdata_10b        [lane*10+:10]      ),
    .pma_txdatavalid_10b        (sdm_pma_txdatavalid_10b   [lane]             ),   
    .pma_txstartblock_10b       (sdm_pma_txstartblock_10b  [lane]             ),
    .pma_txsynchdr_10b          (sdm_pma_txsynchdr_10b     [lane*2 +:2]       ),
    .cdr_fast_lock              (cdr_fast_lock                                ),
`ifdef GPHY_ESM_SUPPORT
    .phy_reg_esm_enable         (phy_reg_esm_enable        [lane]             ),
    .phy_reg_esm_data_rate0     (phy_reg_esm_data_rate0    [lane*7+:7]        ),
    .phy_reg_esm_data_rate1     (phy_reg_esm_data_rate1    [lane*7+:7]        ),
`endif // GPHY_ESM_SUPPORT  

   .los_rxelecidle_filtered     (los_rxelecidle_filtered    [lane]            ),   
   .los_rxelecidle_unfiltered   (los_rxelecidle_unfiltered  [lane]            ),  
// outputs    
    .txp                        (txp                       [lane]             ),
    .txn                        (txn                       [lane]             ),
    .pma_rxdata_10b             (pma_sdm_rxdata_10b        [lane*10+:10]      ),
    .pma_pm_beacondetected      (),
    .pma_rxdetected             (pma_sdm_rxdetected        [lane]             ),
   // .pma_rxelecidle_filtered    (pma_sdm_rxelecidle_filtered     [lane]       ),
   // .pma_rxelecidle_noise       (pma_sdm_rxelecidle_noise        [lane]       ),
    .pma_recvdclk               (pma_sdm_recvdclk          [lane]             ),
    .pma_recvdclk_pipe          (pma_sdm_recvdclk_pipe     [lane]             ),
    .pma_rcvdrst_n              (pma_sdm_rcvdrst_n         [lane]             ),
    .pma_serdes_rx_valid        (pma_serdes_rx_valid       [lane]             ),
    .pma_recvdclk_stopped       (pma_sdm_recvdclk_stopped  [lane]             )
);
end
endgenerate

endmodule: DWC_pcie_gphy_pma

