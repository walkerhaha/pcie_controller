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
// ---    $DateTime: 2020/09/11 01:49:10 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_sdm_1s.v#6 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:  xN SDM module for the generic PHY
// -----------------------------------------------------------------------------



module DWC_pcie_gphy_sdm_1s #(
  parameter TP        = -1,
  parameter PIPE_NB   = -1,
  parameter WIDTH_WD  = -1,
  parameter RXSB_WD   = -1,
  parameter NL        = -1,
  parameter PIPE_DATA_WD   = -1,   
  parameter TXEI_WD        = -1  
) (

// =====================================
  // General Inputs
  input                    txclk,                                   // Port Logic tx clock
  input                    txclk_ug,
  input                    phy_rst_n,                               // Port Logic core reset; active low  
  input                    serdes_arch,
  
  // PCS to SDM Inputs
  input   [(NL*PIPE_DATA_WD)-1:0]     pcs_sdm_txdata,                          // Parallel transmit data (1 or 2 bytes wide)
  input   [NL-1:0]         pcs_sdm_txdatak,                         // K char indication per byte
  input   [NL-1:0]         pcs_sdm_txdatavalid,                     // ignore a byte or word on the data interface  
  input   [NL-1:0]         pcs_sdm_rxstandby,       
  input   [NL-1:0]         pcs_sdm_txstartblock,                    // first byte of the data interface is the first 
  input   [(NL*2)-1:0]     pcs_sdm_txsynchdr,                       // sync header to use in the next 130b block
  input   [NL-1:0]         pcs_sdm_txdetectrx_loopback,             // Enable recevie detection sequence generation  (loopback)
  input   [NL-1:0]         pcs_sdm_txelecidle,                      // Place transmitter into electrical idle
  input   [NL-1:0]         pcs_sdm_txcompliance,                    // Enable transmission of compliance sequence
  input   [NL-1:0]         pcs_sdm_rxpolarity,                      // Invert the receive data
  input   [3:0]            pcs_sdm_powerdown,                       // Signal to go to specific power state
  input   [NL-1:0]         pcs_sdm_elasticbuffermode,   
  input   [NL*3-1:0]       pcs_sdm_rate,                            // 1 = change speed to 5 Gbit/s, 2 = change speed to 8 Gbit/s
  input   [NL*3-1:0]       pcs_sdm_curr_rate,
  input   [WIDTH_WD-1:0]   pcs_sdm_width,  
  input   [NL-1:0]         pcs_sdm_reset_n,
  input   [NL-1:0]         pcs_sdm_set_disp,
  input   [NL-1:0]         pcs_sdm_txerror,
  input   [NL-1:0]         pcs_sdm_blockaligncontrol,               // block align control    
  input                    pcs_sdm_sris_mode,
  
  // control inputs
  input                    syncheader_random_en,
  input                    disable_skp_addrm_en,
  
    
`ifdef GPHY_ESM_SUPPORT
  input [NL-1:0]          phy_reg_esm_enable,
  input [NL*7-1:0]        phy_reg_esm_data_rate0,
  input [NL*7-1:0]        phy_reg_esm_data_rate1,
`endif // GPHY_ESM_SUPPORT


  // pma to sdm  Inputs
  input   [(NL*10)-1:0]    pma_sdm_rxdata_10b,                      // Parallel receive data from SerDes
  input   [NL-1:0]         pma_sdm_rxdetected,                      // Receive signal detected by SerDes
  input   [NL-1:0]         pma_sdm_rxelecidle,                      // Receive Idle detected
  input   [NL-1:0]         pma_sdm_recvdclk,                        // Recovered symbol clock
  input   [NL-1:0]         pma_sdm_rcvdrst_n,                       // Recovered reset_n
  input   [NL-1:0]         pma_sdm_recvdclk_stopped,
  input   [NL-1:0]         pma_serdes_rx_valid,
  
  // pll to sdm
  input                    pll_sdm_ready,

  // SDM to PCS Outputs
  output  [(NL*PIPE_DATA_WD)-1:0]     sdm_pcs_dec8b10b_rxdata,                 // Parallel receive data (1 or 2 bytes)
  output  [NL-1:0]         sdm_pcs_dec8b10b_rxdatak,                // K char indication
  output  [NL-1:0]         sdm_pcs_dec8b10b_rxvalid,                // Receive data valid  
  output  [NL-1:0]         sdm_pcs_dec8b10b_rxdatavalid,            
  output  [NL-1:0]         sdm_pcs_dec8b10b_rxstartblock,           // first byte of the data interface is the first byte of the block.
  output  [(NL*2)-1:0]     sdm_pcs_dec8b10b_rxsynchdr,              // sync header that was strippend out of the 130 bit block  
  output  [NL-1:0]         sdm_pcs_dec8b10b_rxdisperror,
  output  [NL-1:0]         sdm_pcs_dec8b10b_rxcodeerror,
  output  [NL-1:0]         sdm_pcs_dec8b10b_rxunderflow,
  
  output  [NL-1:0]         sdm_pcs_elasbuf_rxoverflow,   
  output  [NL-1:0]         sdm_pcs_elasbuf_rxskipadded,  
  output  [NL-1:0]         sdm_pcs_elasbuf_rxskipremoved,
  
  output  [NL-1:0]         sdm_pcs_skp_broken,
  output  [(NL*8)-1:0]     sdm_pcs_ebuf_location,                   // Elastic Buffer Location
  
  // SDM to PMA Outputs
  output  [(NL*10)-1:0]    sdm_pma_enc8b10b_txdata_10b,             // Transmit symbol data
  output  [NL-1:0]         sdm_pma_enc8b10b_txdatavalid_10b,        // ignore a byte or word on the data interface
  output  [NL-1:0]         sdm_pma_enc8b10b_txstartblock_10b,       // first byte of the data interface is the first byte of the block.
  output  [(NL*2)-1:0]     sdm_pma_enc8b10b_txsynchdr_10b,          // sync header to use in the next 130b block
  output  [NL-1:0]         sdm_pma_enc8b10b_txelecidle_10b,
  
  output  [NL-1:0]         sdm_pma_loopback                         // TODO :this needs to go to pma serializer where we look at loopback to clear queues 
                                                                    // decision is now take into elastic buffer and needs to propagate down       


);
// =============================================================================
genvar lane;
generate
for (lane = 0; lane<NL; lane = lane + 1) begin : gensdm_lane

DWC_pcie_gphy_sdm_1s_lane #(
  .TP             (TP),
  .PIPE_NB        (PIPE_NB),
  .WIDTH_WD       (WIDTH_WD),
  .RXSB_WD        (RXSB_WD),
  .PIPE_DATA_WD   (PIPE_DATA_WD), 
  .TXEI_WD        (TXEI_WD)

) u_sdm_lane (
// =====================================
// General Inputs
  .txclk                             (txclk                                             ),                                   // Port Logic tx clock
  .txclk_ug                          (txclk_ug                                          ),
  .phy_rst_n                         (phy_rst_n                                         ),                               // Port Logic core reset; active low

  .serdes_arch                       (serdes_arch                                       ),
// PCS to SDM Inputs
  .pcs_sdm_txdata                    (pcs_sdm_txdata                   [lane*PIPE_DATA_WD+:PIPE_DATA_WD]      ),             // Parallel transmit data (1 or 2 bytes wide)                  
  .pcs_sdm_txdatak                   (pcs_sdm_txdatak                  [lane]           ),             // K char indication per byte                                   
  .pcs_sdm_txdatavalid               (pcs_sdm_txdatavalid              [lane]           ),             // ignore a byte or word on the data interface                      
  .pcs_sdm_rxstandby                 (pcs_sdm_rxstandby                [lane]           ),                                                                                         
  .pcs_sdm_txstartblock              (pcs_sdm_txstartblock             [lane]           ),             // first byte of the data interface is the first                     
  .pcs_sdm_txsynchdr                 (pcs_sdm_txsynchdr                [lane*2+:2]      ),             // sync header to use in the next 130b block                      
  .pcs_sdm_txdetectrx_loopback       (pcs_sdm_txdetectrx_loopback      [lane]           ),             // Enable recevie detection sequence generation  (loopback)                 
  .pcs_sdm_txelecidle                (pcs_sdm_txelecidle               [lane]           ),             // Place transmitter into electrical idle                          
  .pcs_sdm_txcompliance              (pcs_sdm_txcompliance             [lane]           ),             // Enable transmission of compliance sequence                        
  .pcs_sdm_rxpolarity                (pcs_sdm_rxpolarity               [lane]           ),             // Invert the receive data                                         
  .pcs_sdm_powerdown                 (pcs_sdm_powerdown                                 ),             // Signal to go to specific power state                           
  .pcs_sdm_elasticbuffermode         (pcs_sdm_elasticbuffermode        [lane]           ),                                                                                         
  .pcs_sdm_rate                      (pcs_sdm_rate                     [lane*3+:3]      ),             // 1 = change speed to 5 Gbit/s, 2 = change speed to 8 Gbit/s
  .pcs_sdm_curr_rate                 (pcs_sdm_curr_rate                [lane*3+:3]      ),                                                     
  .pcs_sdm_width                     (pcs_sdm_width                                     ),                                                                                                                           
  .pcs_sdm_reset_n                   (pcs_sdm_reset_n                  [lane]           ),                                                                                         
  .pcs_sdm_set_disp                  (pcs_sdm_set_disp                 [lane]           ),                                                                                         
  .pcs_sdm_txerror                   (pcs_sdm_txerror                  [lane]           ),                                                                                         
  .pcs_sdm_blockaligncontrol         (pcs_sdm_blockaligncontrol        [lane]           ),             // block align control                                                    
  .pcs_sdm_sris_mode                 (pcs_sdm_sris_mode                                 ),                                                                                         
     
  
  // control inputs
  .syncheader_random_en              (syncheader_random_en                              ),                                                                                         
  .disable_skp_addrm_en              (disable_skp_addrm_en                              ),                                                                                         
  
    
`ifdef GPHY_ESM_SUPPORT
  .phy_reg_esm_enable                (phy_reg_esm_enable               [lane]           ),                                                                                                                            
  .phy_reg_esm_data_rate0            (phy_reg_esm_data_rate0           [lane*7+:7]      ),                                                                                                                        
  .phy_reg_esm_data_rate1            (phy_reg_esm_data_rate1           [lane*7+:7]      ),                                                                                                                        
`endif // GPHY_ESM_SUPPORT


  // pma to sdm  Inputs
  .pma_sdm_rxdata_10b                (pma_sdm_rxdata_10b                [lane*10 +: 10] ),              // Parallel receive data from SerDes
  .pma_sdm_rxdetected                (pma_sdm_rxdetected                [lane]          ),              // Receive signal detected by SerDes
  .pma_sdm_rxelecidle                (pma_sdm_rxelecidle                [lane]          ),              // Receive Idle detected
  .pma_sdm_recvdclk                  (pma_sdm_recvdclk                  [lane]          ),              // Recovered symbol clock
  .pma_sdm_rcvdrst_n                 (pma_sdm_rcvdrst_n                 [lane]          ),              // Recovered reset_n
  .pma_sdm_recvdclk_stopped          (pma_sdm_recvdclk_stopped          [lane]          ),
  .pma_serdes_rx_valid               (pma_serdes_rx_valid               [lane]          ),
  
  .pll_sdm_ready                     (pll_sdm_ready                                     ),

  // SDM to PCS Outputs
  .sdm_pcs_dec8b10b_rxdata           (sdm_pcs_dec8b10b_rxdata           [lane*PIPE_DATA_WD +:PIPE_DATA_WD]    ),               // Parallel receive data (1 or 2 bytes)
  .sdm_pcs_dec8b10b_rxdatak          (sdm_pcs_dec8b10b_rxdatak          [lane]          ),               // K char indication
  .sdm_pcs_dec8b10b_rxvalid          (sdm_pcs_dec8b10b_rxvalid          [lane]          ),               // Receive data valid  
  .sdm_pcs_dec8b10b_rxdatavalid      (sdm_pcs_dec8b10b_rxdatavalid      [lane]          ),            
  .sdm_pcs_dec8b10b_rxstartblock     (sdm_pcs_dec8b10b_rxstartblock     [lane]          ),               // first byte of the data interface is the first byte of the block.
  .sdm_pcs_dec8b10b_rxsynchdr        (sdm_pcs_dec8b10b_rxsynchdr        [lane*2 +:2]    ),               // sync header that was strippend out of the 130 bit block  
  .sdm_pcs_dec8b10b_rxdisperror      (sdm_pcs_dec8b10b_rxdisperror      [lane]          ),
  .sdm_pcs_dec8b10b_rxcodeerror      (sdm_pcs_dec8b10b_rxcodeerror      [lane]          ),
  .sdm_pcs_dec8b10b_rxunderflow      (sdm_pcs_dec8b10b_rxunderflow      [lane]          ),
  
  .sdm_pcs_elasbuf_rxoverflow        (sdm_pcs_elasbuf_rxoverflow        [lane]          ),
  .sdm_pcs_elasbuf_rxskipadded       (sdm_pcs_elasbuf_rxskipadded       [lane]          ),
  .sdm_pcs_elasbuf_rxskipremoved     (sdm_pcs_elasbuf_rxskipremoved     [lane]          ),
  .sdm_pcs_skp_broken                (sdm_pcs_skp_broken                [lane]          ),
  .sdm_pcs_ebuf_location             (sdm_pcs_ebuf_location             [lane*8 +:8]    ),               // Elastic Buffer Location
  
  // SDM to PMA Outputs
  .sdm_pma_enc8b10b_txdata_10b       (sdm_pma_enc8b10b_txdata_10b       [lane*10 +:10]  ),               // Transmit symbol data
  .sdm_pma_enc8b10b_txdatavalid_10b  (sdm_pma_enc8b10b_txdatavalid_10b  [lane]          ),               // ignore a byte or word on the data interface
  .sdm_pma_enc8b10b_txstartblock_10b (sdm_pma_enc8b10b_txstartblock_10b [lane]          ),               // first byte of the data interface is the first byte of the block.
  .sdm_pma_enc8b10b_txsynchdr_10b    (sdm_pma_enc8b10b_txsynchdr_10b    [lane*2 +:2]    ),               // sync header to use in the next 130b block
  .sdm_pma_enc8b10b_txelecidle_10b   (sdm_pma_enc8b10b_txelecidle_10b   [lane]          ),
  
  .sdm_pma_loopback                  (                                                  )  // TODO :this needs to go to pma serializer where we look at loopback to clear queues 
                                                                                           // decision is now take into elastic buffer and needs to propagate down       


);

end
endgenerate

endmodule

