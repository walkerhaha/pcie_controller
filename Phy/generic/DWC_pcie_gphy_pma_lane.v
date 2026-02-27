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
// ---    $DateTime: 2020/06/26 01:14:06 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pma_lane.v#5 $
// -------------------------------------------------------------------------
// --- Module Description:  Generic single lane SerDes module for use in the
// ---                      generic PHY model.
// -----------------------------------------------------------------------------

module DWC_pcie_gphy_pma_lane #(
  parameter  TP = -1,
  parameter  WIDTH_WD = -1                             // Clock to Q delay (simulator insurance)
) (
  // general inputs
  input                   refclk,                   // Reference Clock
  input                   txbitclk,                 // Transmit bit clock
  input                   txclk,                    // Transmit symbol clock
  input                   serdes_arch,
  input  [WIDTH_WD-1:0]   rxwidth,
  
  input                   pma_reset_n,          // Reset
  input   [3:0]           pma_powerdown,        // power state 
  input                   sris_mode,
  input   [2:0]           pma_rate,
  input   [2:0]           pma_curr_rate,        // Current operating rate
  input                   mac_phy_rxstandby,

  // transmit inputs

  input                   pma_rx_clock_off,             // clock is turned off in P1
  input                   pma_loopback,         // PCI-E loopback
  input   [9:0]           pma_txdata_10b,       // 1 symbol parallel transmit data  
  input                   pma_txdetectrx,       // Send receiver detection sequence; placeholder
  input                   pma_txelecidle,       // Enable Transmitter Electical Idle
  input                   pma_beacongen,        // Instruct the SerDes to generate a beacon signal


  // receive inputs
  input                   pma_rxpolarity,       // Invert receive data
  input                   rxp,                      // Serial receive data (pos)
  input                   rxn,                      // Serial receive data (neg)
  input                   rxelecidle_disable,       // L1sub power saving measure
  input                   txcommonmode_disable,     // L1sub power saving measure
  input                   rxsymclk_random_drift_en,

  input                   pma_txdatavalid_10b,  // ignore a byte or word on the data interface

  input                   pma_txstartblock_10b, // first byte of the data interface is the first byte of the block.
  input  [1:0]            pma_txsynchdr_10b,    // sync header to use in the next 130b block
  input                   cdr_fast_lock,
`ifdef GPHY_ESM_SUPPORT
  input                   phy_reg_esm_enable,
  input [6:0]             phy_reg_esm_data_rate0,
  input [6:0]             phy_reg_esm_data_rate1,
`endif // GPHY_ESM_SUPPORT   


  input                   los_rxelecidle_filtered,   
  input                   los_rxelecidle_unfiltered, 
  
  // transmit outputs
  output                  txp,                    // Serial transmit data (pos)
  output                  txn,                    // Serial transmit data (neg)

  // receive outputs
  output  [9:0]           pma_rxdata_10b,     // 1 symbol parallel receive data
  output                  pma_pm_beacondetected,  // beacon detected by receiver
  output                  pma_rxdetected,     // receiver detected signaling,
  output                  pma_recvdclk,       // recovered receive byte clock
  output                  pma_recvdclk_pipe,
  output                  pma_rcvdrst_n,       // recovered reset_n
  output                  pma_serdes_rx_valid,
  output                  pma_recvdclk_stopped
);

wire rxbitclk;
//==============================================================================
// Serializer 
//==============================================================================
DWC_pcie_gphy_ser #(
    .TP (TP)
) u_xphy_ser (
    .refclk                    (refclk                  ),
    .txbitclk                  (txbitclk                ),
    .txclk                     (txclk                   ),
    .rst_n                     (pma_reset_n             ),
    .serdes_arch               (serdes_arch             ),
    .elecidle                  (pma_txelecidle          ),
    .loopback                  (pma_loopback            ),
    .common_mode_disable       (txcommonmode_disable    ),  
    .powerdown                 (pma_powerdown           ),
    .beacongen                 (pma_beacongen           ),
    .txdetectrx                (pma_txdetectrx          ), 
    .txdata_10b                (pma_txdata_10b          ),
    .rate                      (pma_curr_rate           ),
    .txdatavalid_10b           (pma_txdatavalid_10b     ),
    .txstartblock_10b          (pma_txstartblock_10b    ),
    .txsynchdr_10b             (pma_txsynchdr_10b       ),

    .rxdetected                (pma_rxdetected          ),
    .txp                       (txp                     ),
    .txn                       (txn                     )
);


//==============================================================================
// Deserializer
//==============================================================================
DWC_pcie_gphy_deser #(
    .TP (TP),
    .WIDTH_WD  (WIDTH_WD)
) u_rphy_deser (
    .refclk                   (refclk                  ),
    .rst_n                    (pma_reset_n             ),
    .rx_clock_off             (pma_rx_clock_off        ),
    .rxpolarity               (pma_rxpolarity          ),
    .serdes_arch              (serdes_arch             ),
    .rxwidth                  (rxwidth                 ),
    .rxp                      (rxp                     ),
    .rxn                      (rxn                     ),
    .rate                     (pma_rate                ),
    .current_rate             (pma_curr_rate           ),
    .powerdown                (pma_powerdown           ),
    .rxstandby                (mac_phy_rxstandby       ),  
    .rxsymclk_random_drift_en (rxsymclk_random_drift_en),
    .rxelecidle_filtered      (los_rxelecidle_filtered  ),    // electrical idle detected filtered
    .rxelecidle_unfiltered    (los_rxelecidle_unfiltered ),     // electrical idle detected
    .sris_mode                (sris_mode               ),
    .cdr_fast_lock            (cdr_fast_lock           ),
`ifdef GPHY_ESM_SUPPORT
    .esm_enable               (phy_reg_esm_enable      ),
    .esm_data_rate0           (phy_reg_esm_data_rate0  ),
    .esm_data_rate1           (phy_reg_esm_data_rate1  ),
`endif // GPHY_ESM_SUPPORT 
    .rxdata_10b               (pma_rxdata_10b          ),  // non-aligned symbol data
    .beacondetected           (pma_pm_beacondetected   ),
    .recvdclk                 (pma_recvdclk            ),
    .recvdclk_pipe            (pma_recvdclk_pipe       ),
    .rcvdrst_n                (pma_rcvdrst_n           ),
    .recvdclk_stopped         (pma_recvdclk_stopped    ),
    .serdes_rx_valid          (pma_serdes_rx_valid     ),
    .rxbitclk                 (rxbitclk                )                   // serial bit clock   
);

endmodule

