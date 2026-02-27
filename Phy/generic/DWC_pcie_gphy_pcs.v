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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pcs.v#5 $
// -------------------------------------------------------------------------
// --- Module Description: xN PCS module for the generic PHY
// ----------------------------------------------------------------------------


module DWC_pcie_gphy_pcs #(
  parameter TP        = -1,
  parameter PIPE_NB   = -1,
  parameter WIDTH_WD  = -1,
  parameter RXSB_WD   = -1,
  parameter NL        = -1,
  parameter TX_PSET_WD     = -1,                              // Width of Transmitter Equalization Presets
  parameter TX_COEF_WD     = -1,                              // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
  parameter DIRFEEDBACK_WD = -1,                              // Width of Direction Change
  parameter FOMFEEDBACK_WD = -1,                              // Width of Figure of Merit
  parameter TX_FS_WD       = -1,
  parameter PIPE_DATA_WD   = -1,   
  parameter TXEI_WD        = -1                                // Width of LF or FS

) (

// General Inputs
  input                              refclk,                         // reference clock input
  input                              phy_rst_n,                      // PIPE Reset input
  input  [NL-1:0]                    pclk,                           // Pipe clock  
  input                              txclk,                          // Txclk 
  input                              txclk_ug,                       // free running version of txclk    
  input                              txbitclk,                       // Txbitclk
  input   [NL-1:0]                   recvdclk,
  input   [NL-1:0]                   recvdclk_pipe,
  input                              pclk_mode_input,
  // PIPE Inputs
  input   [(NL*PIPE_NB*PIPE_DATA_WD)-1:0]    mac_phy_txdata,                 // Parallel transmit data
  input   [NL*PIPE_NB-1:0]           mac_phy_txdatak,                // K char indication per bytephy_1s.v
  input   [NL-1:0]                   mac_phy_txdetectrx_loopback,    // Enable recevie detection sequence generation (or loopback)
  input   [NL*TXEI_WD-1:0]           mac_phy_txelecidle,             // Place transmitter into electrical idle
  input   [NL-1:0]                   mac_phy_txcompliance,           // Enable transmission of compliance sequence
  input   [NL-1:0]                   mac_phy_rxpolarity,             // Invert the receive data
  input   [3:0]                      mac_phy_powerdown,              // Signal to go to specific power state
  input                              mac_phy_elasticbuffermode,      // 0 = empty mode ; 1 = half full mode
  input   [2:0]                      mac_phy_rate,                   // 1 = change speed to 5 Gbit/s, 2 = change speed to 8 Gbit/s
  input   [WIDTH_WD-1:0]             mac_phy_width,                  // pipe width: 0 = 1s; 1 = 2s; 2 = 4s; 3 = 8s
  input   [3:0]                      mac_phy_pclk_rate,              // pipe pclk rate: 0 = 62.5 ; 1 = 125 ; 2 = 250 ; 3 = 500 ; 4 = 100
  input   [NL-1:0]                   mac_phy_txdatavalid, 
  input   [NL-1:0]                   mac_phy_rxstandby,  
  input                              mac_phy_sris_mode,
  input   [NL-1:0]                   mac_phy_txdeemph,               // selects transmitter de-emphasis in the PHY
  input   [2:0]                      mac_phy_txmargin,               // selects transmitter voltage levels in the PHY
  input   [NL-1:0]                   mac_phy_txswing,                // selects transmitter voltage swing level in the PHY                                                             
  input   [NL-1:0]                   mac_phy_txstartblock,           // first byte of the data interface is the first byte of the block.
  input   [(NL*2)-1:0]               mac_phy_txsynchdr,              // sync header to use in the next 130b block
  input                              mac_phy_blockaligncontrol,      // block align control
  input                              mac_phy_encodedecodebypass,     // encode decode bypass
  input   [NL*2-1:0]                 mac_phy_pclkreq_n,              // request to turn off/on pclk
  input                              asyncpowerchangeack,            // pipe43 signal: handshake between phystatus and ack
  input   [NL-1:0]                   txcommonmode_disable,           //
  input   [NL-1:0]                   rxelecidle_disable,             //

  input   [NL-1:0]                   mac_phy_invalid_req,            //
  input   [NL-1:0]                   mac_phy_rxeqeval,               //
  input   [NL*TX_PSET_WD-1:0]        mac_phy_local_pset_index,       //
  input   [NL-1:0]                   mac_phy_getlocal_pset_coef,     //
  input   [NL-1:0]                   mac_phy_rxeqinprogress,         //
  input   [NL*TX_FS_WD-1:0]          mac_phy_fs,                     //
  input   [NL*TX_FS_WD-1:0]          mac_phy_lf,                     //
  
  input                              serdes_arch,
  input   [WIDTH_WD-1:0]             rxwidth,
  input   [NL-1:0]                   serdes_pipe_turnoff_lanes,

  // input Command interface inputs
  // phy_tb_ctrl for equalization
  input   [NL-1:0]                   set_eq_feedback_delay,               
  input   [NL*32-1:0]                eq_feedback_delay,                   
  input   [NL-1:0]                   set_eq_dirfeedback,                  
  input   [(NL*DIRFEEDBACK_WD)-1:0]  eq_dirfeedback_value,                
  input   [NL-1:0]                   set_eq_fomfeedback,                  
  input   [(NL*FOMFEEDBACK_WD)-1:0]  eq_fomfeedback_value,                
  input   [NL-1:0]                   set_localfs_g3,                      
  input   [(NL*TX_FS_WD)-1:0]        localfs_value_g3,                    
  input   [NL-1:0]                   set_localfs_g4,                      
  input   [(NL*TX_FS_WD)-1:0]        localfs_value_g4,                    
  input   [NL-1:0]                   set_localfs_g5,                      
  input   [(NL*TX_FS_WD)-1:0]        localfs_value_g5,                    
  input   [NL-1:0]                   set_locallf_g3,                      
  input   [(NL*TX_FS_WD)-1:0]        locallf_value_g3,                    
  input   [NL-1:0]                   set_locallf_g4,                      
  input   [(NL*TX_FS_WD)-1:0]        locallf_value_g4,                    
  input   [NL-1:0]                   set_locallf_g5,                      
  input   [(NL*TX_FS_WD)-1:0]        locallf_value_g5,                    
  input   [NL-1:0]                   set_local_tx_pset_coef_delay,        
  input   integer                    local_tx_pset_coef_delay,            
  input   [NL-1:0]                   set_local_tx_pset_coef,              
  input   [(NL*TX_COEF_WD)-1:0]      local_tx_pset_coef_value ,           
  input   [NL-1:0]                   set_rxadaption,                      
  input   [(NL*3)-1:0]               update_localfslf_mode,               
  
  // phy_tb_ctrl for powerdown/rate
  input                              powerdown_random_phystatus_en,    // enable/disable to generate phystatus with random delay at powerdown change
  input   [2:0]                      p1_random_range,                  // delay to change to P1
  input                              p1_phystatus_time_load_en,        // Enable/disable to set a specific value as delay for phystatus at P1 entry
  input   [12:0]                     p1_phystatus_time,                // The value set if above is enabled
  input                              rate_random_phystatus_en,         // enable/disable to generate phystatus with random delay at rate change
  input                              p2_phystatus_rise_random_en,      // enable/disable random delay generation for phystatus assertion in P2 entry
  input                              p2_random_phystatus_rise_load_en, // Enable/disable to set a specific value as delay for phystatus assertion at P2 entry
  input   [12:0]                     p2_random_phystatus_rise_value,   // The value set for P2 entry if above is enabled
  input                              p2_phystatus_fall_random_en,      // enable/disable random delay generation for phystatus deassertion in P2 entry
  input                              p2_random_phystatus_fall_load_en, // Enable/disable to set a specific value as delay for phystatus deassertion at P2 entry
  input   [12:0]                     p2_random_phystatus_fall_value,   // The value set for P2 entry if above is enabled
  input                              P1X_to_P1_exit_mode,              // 0 = any type ; 1 = always as P2 exit
  
  // PipeMessageBus Signals
  input   [(NL*8)-1:0]               mac_phy_messagebus,
  output  [(NL*8)-1:0]               phy_mac_messagebus,
  // phy_tb_ctrl for PipeMessageBus
  input   [NL-1:0]                   set_p2m_messagebus,
  input   [(NL*8)-1:0]               p2m_messagebus_command_value,
  input   [NL-1:0]                   set_m2p_messagebus,
  input   [(NL*8)-1:0]               m2p_messagebus_command_value,
  
  // phy_tb_ctrl for Margining at Receiver
  input                              VoltageSupported,
  input                              IndErrorSampler,
  input   [6:0]                      MaxVoltageOffset,
  input   [5:0]                      MaxTimingOffset,
  input   [6:0]                      UnsupportedVoltageOffset,
  input                              SampleReportingMethod,
  input   [(NL*2)-1:0]               margin_error_cnt_mode,
  input   [(NL*32)-1:0]              margin_cycle_for_an_error,
  input   [(NL*4)-1:0]               margin_bit_error_rate_factor,
  input   [(NL*2)-1:0]               set_margin_cnt,
  input   [(NL*7)-1:0]               margin_sampl_cnt_to_set,
  input   [(NL*6)-1:0]               margin_error_cnt_to_set,
  input                              random_margin_status_en,          // Enable/disable random delay when generationg margin_status
  input   [7:0]                      fixed_margin_status_thr,          // Fixed delay when generationg margin_status
  // phy_tb_ctrl for ElasticBufferLocation
  input                              ebuf_location_upd_en,
   
  // inputs from pll
  input                              pll_pcs_pclk_off_ack,             // Pclk turn off/on ack
  input [NL-1:0]                     pll_pcs_lock,                     // Pclk is back and locked 
  input                              pll_pcs_ready,                 

  // inputs from sdm
  input   [(NL*PIPE_DATA_WD)-1:0]    sdm_pcs_dec8b10b_rxdata,          // Receive byte data from 8B10B decoder
  input   [NL-1:0]                   sdm_pcs_dec8b10b_rxdatak,         // K-character indication for RX data
  input   [NL-1:0]                   sdm_pcs_dec8b10b_rxdata_dv,       // Indication that RX data is valid
  input   [NL-1:0]                   sdm_pcs_dec8b10b_rxdatavalid,
  input   [NL-1:0]                   sdm_pcs_dec8b10b_rxdisperror,     // 8B10B disparity error
  input   [NL-1:0]                   sdm_pcs_dec8b10b_rxcodeerror,     // 8B10B code violation
  input   [NL-1:0]                   sdm_pcs_elasbuf_rxunderflow,      // Elastic buffer experienced underflow
  input   [NL-1:0]                   sdm_pcs_elasbuf_rxoverflow,       // Elastic buffer experienced overflow
  input   [NL-1:0]                   sdm_pcs_elasbuf_rxskipadded,      // Elastic buffer added a skip
  input   [NL-1:0]                   sdm_pcs_elasbuf_rxskipremoved,    // Elastic buffer removed a skip
  input   [NL-1:0]                   sdm_pcs_rxdetected,               // Results from SerDes receiver detection process
  input   [NL-1:0]                   sdm_pcs_comma_lock,               // Comma detect function in "comma lock"

  input   [NL-1:0]                   sdm_pcs_dec8b10b_rxstartblock,    // first byte of the data interface is the first
  input   [(NL*2)-1:0]               sdm_pcs_dec8b10b_rxsynchdr,       // sync header to use in the next 130b block
  input   [NL-1:0]                   sdm_pcs_skp_broken,    
  input   [(NL*8)-1:0]               sdm_pcs_ebuf_location,
  
   // PCLK as PHY input
   // input/output
   input  [NL-1:0]                   mac_phy_pclkchangeack,
   output [NL-1:0]                   phy_mac_pclkchangeok,
  
// =========================================================================
// Outputs
                                     
// PIPE Outputs
  output  [(NL*PIPE_NB*PIPE_DATA_WD)-1:0]       phy_mac_rxdata,                   // Parallel receive data                                            
  output  [(NL*PIPE_NB)-1:0]         phy_mac_rxdatak,                  // K char indication                                                
  output  [NL-1:0]                   phy_mac_rxvalid,                  // Receive data valid                                               
  output  [(NL*3)-1:0]               phy_mac_rxstatus,                 // Receiver status (encoded)                                                             
  output  [NL-1:0]                   phy_mac_phystatus,                // Indicates completion of operation (context specific)             
  output  [NL-1:0]                   phy_mac_pclkack_n,                // acknoleadge that pclk if off                                     
  output  [NL-1:0]                   phy_mac_rxdatavalid,                                                                                  
  output  [(NL*RXSB_WD)-1:0]         phy_mac_rxstartblock,             // first byte of the data interface is the first byte of the block. 
  output  [(NL*RXSB_WD*2)-1:0]       phy_mac_rxsynchdr,                // sync header that was strippend out of the 130 bit block          
  output  [NL-1:0]                   phy_mac_rxstandbystatus,                                                                            
  output  [NL-1:0]                   phy_reg_txswing,                                                                                    
  output  [(NL*TX_COEF_WD)-1:0]      phy_reg_txdeemph,                                                                                   
  output  [NL-1:0]                   phy_reg_invalid_req,                                                                                
  output  [NL-1:0]                   phy_reg_rxeqeval,                                                                                   
  output  [(NL*6)-1:0]               phy_reg_local_pset_index,                                                                           
  output  [NL-1:0]                   phy_reg_getlocal_pset_coef,                                                                         
  output  [NL-1:0]                   phy_reg_rxeqinprogress,                                                                             
  output  [(NL*TX_FS_WD)-1:0]        phy_reg_fs,
  output  [(NL*TX_FS_WD)-1:0]        phy_reg_lf,
  output  [(NL*TX_COEF_WD)-1:0]      phy_mac_local_tx_pset_coef,       //in vmain connect phy_mac_local_tx_pset_coef
  output  [NL-1:0]                   phy_mac_local_tx_coef_valid,      //in vmain connect phy_mac_local_tx_coef_valid
  output  [(NL*TX_FS_WD)-1:0]        phy_mac_localfs,                  //in vmain connect phy_mac_localfs
  output  [(NL*TX_FS_WD)-1:0]        phy_mac_locallf,                  //in vmain connect phy_mac_locallf
  output  [(NL*DIRFEEDBACK_WD)-1:0]  phy_mac_dirfeedback,              //in vmain connect phy_mac_dirfeedback
  output  [(NL*FOMFEEDBACK_WD)-1:0]  phy_mac_fomfeedback,              //in vmain connect phy_mac_fomfeedback
  
  // CCIX Signals
  input  [NL-1:0]                    phy_mac_esm_calibrt_complete,
  output [(NL*7)-1:0]                phy_reg_esm_data_rate0,
  output [(NL*7)-1:0]                phy_reg_esm_data_rate1,
  output [NL-1:0]                    phy_reg_esm_calibrt_req,
  output [NL-1:0]                    phy_reg_esm_enable,
  output [NL-1:0]                    write_ack_for_esm_calibrt_req,
  output [NL-1:0]                    lane_disabled,

 
  // outputs to pll
  output [NL-1:0]                    pcs_pll_pclk_off_req,             // Request to turn off pclk
  output [NL-1:0]                    pcs_pll_rate_change_req,          // Request to change the rate
  // outputs to sdm
  output [(NL*PIPE_DATA_WD)-1:0]                pcs_sdm_txdata,           
  output [NL-1:0]                    pcs_sdm_txdatak,           
  output [NL-1:0]                    pcs_sdm_loopback,         
  output [NL-1:0]                    pcs_sdm_txdetectrx,       
  output [NL-1:0]                    pcs_sdm_txelecidle,       
  output [NL-1:0]                    pcs_sdm_txcompliance, 
  output [NL-1:0]                    pcs_sdm_blockaligncontrol,
  output [NL-1:0]                    pcs_sdm_elasticbuffermode,
  output [NL-1:0]                    pcs_sdm_encodedecodebypass,
  output [NL-1:0]                    pcs_sdm_rxstandby,    
  output [NL-1:0]                    pcs_sdm_beacongen,        
  output [3:0]                       pcs_sdm_powerdown,        
  output [NL-1:0]                    pcs_sdm_rxpolarity,       
  output [NL-1:0]                    pcs_sdm_txerror,                   
  output [NL*3-1:0]                  pcs_sdm_rate,             
  output [NL*3-1:0]                  pcs_sdm_curr_rate,        
  output [NL-1:0]                    pcs_sdm_txdatavalid,      
  output [NL-1:0]                    pcs_sdm_txstartblock,     
  output [(NL*2)-1:0]                pcs_sdm_txsynchdr, 
  output [NL-1:0]                    pcs_sdm_rx_clock_off,
  output [NL-1:0]                    pcs_sdm_reset_n,
  output [NL-1:0]                    pcs_sdm_set_disp
                                        
);


genvar lane;
generate
for (lane = 0; lane<NL; lane = lane + 1) begin : genpcs_lane


DWC_pcie_gphy_pcs_lane #(
  .TP             (TP),
  .PIPE_NB        (PIPE_NB),
  .WIDTH_WD       (WIDTH_WD),
  .RXSB_WD        (RXSB_WD),
  .TX_PSET_WD     (TX_PSET_WD),                           
  .TX_COEF_WD     (TX_COEF_WD),                           
  .DIRFEEDBACK_WD (DIRFEEDBACK_WD),                       
  .FOMFEEDBACK_WD (FOMFEEDBACK_WD),                       
  .TX_FS_WD       (TX_FS_WD),                             
  .SEED           (lane),
  .PIPE_DATA_WD   (PIPE_DATA_WD), 
  .TXEI_WD        (TXEI_WD)
) u_pcs_lane (
// General Inputs        
  .refclk                                       (refclk                                                                 ),     // reference clock input
  .phy_rst_n                                    (phy_rst_n                                                              ),     // PIPE Reset input
  .pclk                                         (pclk                          [lane]                                   ),     // Pipe clock  
  .txclk                                        (txclk                                                                  ),     // Txclk 
  .txclk_ug                                     (txclk_ug                                                               ),     // free running version of txclk    
  .txbitclk                                     (txbitclk                                                               ),     // Txbitclk
  .recvdclk                                     (recvdclk                      [lane]                                   ),
  .recvdclk_pipe                                (recvdclk_pipe                 [lane]                                   ),
  .pclk_mode_input                              (pclk_mode_input                                                        ),
  
  // PIPE Inputs
  .mac_phy_txdata                               (mac_phy_txdata                [lane*PIPE_NB*PIPE_DATA_WD+:PIPE_NB*PIPE_DATA_WD]              ),     // Parallel transmit data
  .mac_phy_txdatak                              (mac_phy_txdatak               [lane*PIPE_NB+:PIPE_NB]                  ),     // K char indication per bytephy_1s.v
  .mac_phy_txdetectrx_loopback                  (mac_phy_txdetectrx_loopback   [lane]                                   ),     // Enable recevie detection sequence generation (or loopback)
  .mac_phy_txelecidle                           (mac_phy_txelecidle            [lane*TXEI_WD+:TXEI_WD]                                   ),     // Place transmitter into electrical idle
  .mac_phy_txcompliance                         (mac_phy_txcompliance          [lane]                                   ),     // Enable transmission of compliance sequence
  .mac_phy_rxpolarity                           (mac_phy_rxpolarity            [lane]                                   ),     // Invert the receive data
  .mac_phy_powerdown                            (mac_phy_powerdown                                                      ),     // Signal to go to specific power state
  .mac_phy_elasticbuffermode                    (mac_phy_elasticbuffermode                                              ),     // 0 = empty mode ; 1 = half full mode
  .mac_phy_rate                                 (mac_phy_rate                                                           ),     // 1 = change speed to 5 Gbit/s, 2 = change speed to 8 Gbit/s
  .mac_phy_width                                (mac_phy_width                                                          ),     // pipe width: 0 = 1s; 1 = 2s; 2 = 4s; 3 = 8s
  .mac_phy_pclk_rate                            (mac_phy_pclk_rate                                                      ),     // pipe pclk rate: 0 = 62.5 ; 1 = 125 ; 2 = 250 ; 3 = 500 ; 4 = 100
  .mac_phy_txdatavalid                          (mac_phy_txdatavalid           [lane]                                   ), 
  .mac_phy_rxstandby                            (mac_phy_rxstandby             [lane]                                   ),  
  .mac_phy_sris_mode                            (mac_phy_sris_mode                                                      ),
  .mac_phy_txdeemph                             (mac_phy_txdeemph              [lane]                                   ),     // selects transmitter de-emphasis in the PHY
  .mac_phy_txmargin                             (mac_phy_txmargin                                                       ),     // selects transmitter voltage levels in the PHY
  .mac_phy_txswing                              (mac_phy_txswing               [lane]                                   ),     // selects transmitter voltage swing level in the PHY                                                             
  .mac_phy_txstartblock                         (mac_phy_txstartblock          [lane]                                   ),     // first byte of the data interface is the first byte of the block.
  .mac_phy_txsynchdr                            (mac_phy_txsynchdr             [lane*2+:2]                              ),     // sync header to use in the next 130b block
  .mac_phy_blockaligncontrol                    (mac_phy_blockaligncontrol                                              ),     // block align control
  .mac_phy_encodedecodebypass                   (mac_phy_encodedecodebypass                                             ),     // encode decode bypass
  .mac_phy_pclkreq_n                            (mac_phy_pclkreq_n             [lane*2+:2]                              ),     // request to turn off/on pclk
  .asyncpowerchangeack                          (asyncpowerchangeack                                                    ),     // pipe43 signal: handshake between phystatus and ack
  .txcommonmode_disable                         (txcommonmode_disable          [lane]                                   ),          
  .rxelecidle_disable                           (rxelecidle_disable            [lane]                                   ),          
  
  .mac_phy_invalid_req                          (mac_phy_invalid_req           [lane]                                   ),     
  .mac_phy_rxeqeval                             (mac_phy_rxeqeval              [lane]                                   ),     
  .mac_phy_local_pset_index                     (mac_phy_local_pset_index      [lane *TX_PSET_WD +: TX_PSET_WD]         ),     
  .mac_phy_getlocal_pset_coef                   (mac_phy_getlocal_pset_coef    [lane]                                   ),     
  .mac_phy_rxeqinprogress                       (mac_phy_rxeqinprogress        [lane]                                   ),     
  .mac_phy_fs                                   (mac_phy_fs                    [lane *TX_FS_WD +: TX_FS_WD]             ),     
  .mac_phy_lf                                   (mac_phy_lf                    [lane *TX_FS_WD +: TX_FS_WD]             ),     
  
  // serdes arch
  .serdes_arch                                  (serdes_arch                                                            ),
  .rxwidth                                      (rxwidth                                                                ),
  .serdes_pipe_turnoff_lanes                    (serdes_pipe_turnoff_lanes     [lane]                                   ),
  
  // input Command interface inputs
  // phy_tb_ctrl for equalization
  .set_eq_feedback_delay                        (set_eq_feedback_delay         [lane]                                   ), 
  .eq_feedback_delay                            (eq_feedback_delay             [lane*32+:32]                            ),
  .set_eq_dirfeedback                           (set_eq_dirfeedback            [lane]                                   ),
  .eq_dirfeedback_value                         (eq_dirfeedback_value          [lane*DIRFEEDBACK_WD+:DIRFEEDBACK_WD]    ),           
  .set_eq_fomfeedback                           (set_eq_fomfeedback            [lane]                                   ),
  .eq_fomfeedback_value                         (eq_fomfeedback_value          [lane*FOMFEEDBACK_WD+:FOMFEEDBACK_WD]    ),
  .set_localfs_g3                               (set_localfs_g3                [lane]                                   ),
  .localfs_value_g3                             (localfs_value_g3              [lane*TX_FS_WD+:TX_FS_WD]                ),
  .set_localfs_g4                               (set_localfs_g4                [lane]                                   ),
  .localfs_value_g4                             (localfs_value_g4              [lane*TX_FS_WD+:TX_FS_WD]                ),
  .set_localfs_g5                               (set_localfs_g5                [lane]                                   ),
  .localfs_value_g5                             (localfs_value_g5              [lane*TX_FS_WD+:TX_FS_WD]                ),
  .set_locallf_g3                               (set_locallf_g3                [lane]                                   ),
  .locallf_value_g3                             (locallf_value_g3              [lane*TX_FS_WD+:TX_FS_WD]                ),
  .set_locallf_g4                               (set_locallf_g4                [lane]                                   ),
  .locallf_value_g4                             (locallf_value_g4              [lane*TX_FS_WD+:TX_FS_WD]                ),
  .set_locallf_g5                               (set_locallf_g5                [lane]                                   ),
  .locallf_value_g5                             (locallf_value_g5              [lane*TX_FS_WD+:TX_FS_WD]                ),
  .set_local_tx_pset_coef_delay                 (set_local_tx_pset_coef_delay  [lane]                                   ),
  .local_tx_pset_coef_delay                     (local_tx_pset_coef_delay                                               ),  
  .set_local_tx_pset_coef                       (set_local_tx_pset_coef        [lane]                                   ),
  .local_tx_pset_coef_value                     (local_tx_pset_coef_value      [lane*TX_COEF_WD+:TX_COEF_WD]),
  .set_rxadaption                               (set_rxadaption                [lane]                                   ),  
  .update_localfslf_mode                        (update_localfslf_mode         [lane*3+:3]                              ),
  
  
  // phy_tb_ctrl for powerdown/rate
  .powerdown_random_phystatus_en                (powerdown_random_phystatus_en                                          ),       // enable/disable to generate phystatus with random delay at powerdown change
  .p1_random_range                              (p1_random_range                                                        ),       // delay to change to P1
  .p1_phystatus_time_load_en                    (p1_phystatus_time_load_en                                              ),       // Enable/disable to set a specific value as delay for phystatus at P1 entry
  .p1_phystatus_time                            (p1_phystatus_time                                                      ),       // The value set if above is enabled
  .rate_random_phystatus_en                     (rate_random_phystatus_en                                               ),       // enable/disable to generate phystatus with random delay at rate change
  .p2_phystatus_rise_random_en                  (p2_phystatus_rise_random_en                                            ),       // enable/disable random delay generation for phystatus assertion in P2 entry
  .p2_random_phystatus_rise_load_en             (p2_random_phystatus_rise_load_en                                       ),       // Enable/disable to set a specific value as delay for phystatus assertion at P2 entry
  .p2_random_phystatus_rise_value               (p2_random_phystatus_rise_value                                         ),       // The value set for P2 entry if above is enabled
  .p2_phystatus_fall_random_en                  (p2_phystatus_fall_random_en                                            ),       // enable/disable random delay generation for phystatus deassertion in P2 entry
  .p2_random_phystatus_fall_load_en             (p2_random_phystatus_fall_load_en                                       ),       // Enable/disable to set a specific value as delay for phystatus deassertion at P2 entry
  .p2_random_phystatus_fall_value               (p2_random_phystatus_fall_value                                         ),       // The value set for P2 entry if above is enabled
  .P1X_to_P1_exit_mode                          (P1X_to_P1_exit_mode                                                    ),       // 0 = any type ; 1 = always as P2 exit
  
  // PipeMessageBus Signals
  .mac_phy_messagebus                          (mac_phy_messagebus             [lane*8+:8]                              ),
  .phy_mac_messagebus                          (phy_mac_messagebus             [lane*8+:8]                              ),
  // phy_tb_ctrl for PipeMessageBus
  .set_p2m_messagebus                          (set_p2m_messagebus             [lane]                                   ),
  .p2m_messagebus_command_value                (p2m_messagebus_command_value   [lane*8+:8]                              ),
  .set_m2p_messagebus                          (set_m2p_messagebus             [lane]                                   ),
  .m2p_messagebus_command_value                (m2p_messagebus_command_value   [lane*8+:8]                              ),
  
  // phy_tb_ctrl for Margining at Receiver
  .VoltageSupported                            (VoltageSupported                                                        ),
  .IndErrorSampler                             (IndErrorSampler                                                         ),
  .MaxVoltageOffset                            (MaxVoltageOffset                                                        ),
  .MaxTimingOffset                             (MaxTimingOffset                                                         ),
  .UnsupportedVoltageOffset                    (UnsupportedVoltageOffset                                                ),
  .SampleReportingMethod                       (SampleReportingMethod                                                   ),
  .margin_error_cnt_mode                       (margin_error_cnt_mode          [lane*2+:2]                              ),
  .margin_cycle_for_an_error                   (margin_cycle_for_an_error      [lane*32+:32]                            ),
  .margin_bit_error_rate_factor                (margin_bit_error_rate_factor   [lane*4+:4]                              ),
  .set_margin_cnt                              (set_margin_cnt                 [lane*2+:2]                              ),
  .margin_sampl_cnt_to_set                     (margin_sampl_cnt_to_set        [lane*7+:7]                              ),
  .margin_error_cnt_to_set                     (margin_sampl_cnt_to_set        [lane*6+:6]                              ),
  .random_margin_status_en                     (random_margin_status_en                                                 ),        // Enable/disable random delay when generationg margin_status
  .fixed_margin_status_thr                     (fixed_margin_status_thr                                                 ),        // Fixed delay when generationg margin_status

  // phy_tb_ctrl for ElasticBufferLocation
  .ebuf_location_upd_en                        (ebuf_location_upd_en                                                    ),
  
   //pclk as PHY input
  .mac_phy_pclkchangeack                       (mac_phy_pclkchangeack       [lane]                                  ),
  .phy_mac_pclkchangeok                        (phy_mac_pclkchangeok        [lane]                                  ),
   
  // inputs from pll
  .pll_pcs_pclk_off_ack                        (pll_pcs_pclk_off_ack                                                    ),            // Pclk turn off/on ack
  .pll_pcs_lock                                (pll_pcs_lock                [lane]                                      ),            // Pclk is back and locked 
  .pll_pcs_ready                               (pll_pcs_ready                                                           ),                 

  // inputs from sdm
  .sdm_pcs_dec8b10b_rxdata                     (sdm_pcs_dec8b10b_rxdata        [lane*PIPE_DATA_WD+:PIPE_DATA_WD]                              ),            // Receive byte data from 8B10B decoder                  
  .sdm_pcs_dec8b10b_rxdatak                    (sdm_pcs_dec8b10b_rxdatak       [lane]                                   ),            // K-character indication for RX data                    
  .sdm_pcs_dec8b10b_rxdata_dv                  (sdm_pcs_dec8b10b_rxdata_dv     [lane]                                   ),            // Indication that RX data is valid                      
  .sdm_pcs_dec8b10b_rxdatavalid                (sdm_pcs_dec8b10b_rxdatavalid   [lane]                                   ),
  .sdm_pcs_dec8b10b_rxdisperror                (sdm_pcs_dec8b10b_rxdisperror   [lane]                                   ),            // 8B10B disparity error                                   
  .sdm_pcs_dec8b10b_rxcodeerror                (sdm_pcs_dec8b10b_rxcodeerror   [lane]                                   ),            // 8B10B code violation                                  
  .sdm_pcs_elasbuf_rxunderflow                 (sdm_pcs_elasbuf_rxunderflow    [lane]                                   ),            // Elastic buffer experienced underflow                  
  .sdm_pcs_elasbuf_rxoverflow                  (sdm_pcs_elasbuf_rxoverflow     [lane]                                   ),            // Elastic buffer experienced overflow                   
  .sdm_pcs_elasbuf_rxskipadded                 (sdm_pcs_elasbuf_rxskipadded    [lane]                                   ),            // Elastic buffer added a skip                           
  .sdm_pcs_elasbuf_rxskipremoved               (sdm_pcs_elasbuf_rxskipremoved  [lane]                                   ),            // Elastic buffer removed a skip                         
  .sdm_pcs_rxdetected                          (sdm_pcs_rxdetected             [lane]                                   ),            // Results from SerDes receiver detection process                 
  .sdm_pcs_comma_lock                          (sdm_pcs_comma_lock             [lane]                                   ),            // Comma detect function in "comma lock"                   
  .sdm_pcs_dec8b10b_rxstartblock               (sdm_pcs_dec8b10b_rxstartblock  [lane]                                   ),            // first byte of the data interface is the first         
  .sdm_pcs_dec8b10b_rxsynchdr                  (sdm_pcs_dec8b10b_rxsynchdr     [lane*2+:2]                              ),            // sync header to use in the next 130b block             
  .sdm_pcs_skp_broken                          (sdm_pcs_skp_broken             [lane]                                   ),    
  .sdm_pcs_ebuf_location                       (sdm_pcs_ebuf_location          [lane*8+:8]                              ),
  
// PIPE Outputs 
  .phy_mac_rxdata                              (phy_mac_rxdata                 [lane*PIPE_NB*PIPE_DATA_WD+:PIPE_NB*PIPE_DATA_WD]               ),           // Parallel receive data
  .phy_mac_rxdatak                             (phy_mac_rxdatak                [lane*PIPE_NB+:PIPE_NB]                   ),           // K char indication
  .phy_mac_rxvalid                             (phy_mac_rxvalid                [lane]                                    ),           // Receive data valid
  .phy_mac_rxstatus                            (phy_mac_rxstatus               [lane*3+:3]                               ),           // Receiver status (encoded)
  .phy_mac_phystatus                           (phy_mac_phystatus              [lane]                                    ),           // Indicates completion of operation (context specific)
  .phy_mac_pclkack_n                           (phy_mac_pclkack_n              [lane]                                    ),           // acknoleadge that pclk if off
  .phy_mac_rxdatavalid                         (phy_mac_rxdatavalid            [lane]                                    ),
  .phy_mac_rxstartblock                        (phy_mac_rxstartblock           [lane*RXSB_WD+:RXSB_WD]                   ),           // first byte of the data interface is the first byte of the block.
  .phy_mac_rxsynchdr                           (phy_mac_rxsynchdr              [lane*RXSB_WD*2+:RXSB_WD*2]               ),           // sync header that was strippend out of the 130 bit block
  .phy_mac_rxstandbystatus                     (phy_mac_rxstandbystatus        [lane]                                    ),          
  .phy_reg_txswing                             (phy_reg_txswing                [lane]                                    ),
  .phy_reg_txdeemph                            (phy_reg_txdeemph               [lane*TX_COEF_WD+:TX_COEF_WD]             ),
  .phy_reg_invalid_req                         (phy_reg_invalid_req            [lane]                                    ),
  .phy_reg_rxeqeval                            (phy_reg_rxeqeval               [lane]                                    ),
  .phy_reg_local_pset_index                    (phy_reg_local_pset_index       [lane*6+:6]                               ),
  .phy_reg_getlocal_pset_coef                  (phy_reg_getlocal_pset_coef     [lane]                                    ),
  .phy_reg_rxeqinprogress                      (phy_reg_rxeqinprogress         [lane]                                    ),
  .phy_reg_fs                                  (phy_reg_fs                     [lane*TX_FS_WD+:TX_FS_WD]                 ),
  .phy_reg_lf                                  (phy_reg_lf                     [lane*TX_FS_WD+:TX_FS_WD]                 ), 
  .phy_mac_local_tx_pset_coef                  (phy_mac_local_tx_pset_coef     [lane*TX_COEF_WD+:TX_COEF_WD]             ),           //in vmain connect phy_mac_local_tx_pset_coef
  .phy_mac_local_tx_coef_valid                 (phy_mac_local_tx_coef_valid    [lane]                                    ),           //in vmain connect phy_mac_local_tx_coef_valid
  .phy_mac_localfs                             (phy_mac_localfs                [lane*TX_FS_WD+:TX_FS_WD]                 ),           //in vmain connect phy_mac_localfs
  .phy_mac_locallf                             (phy_mac_locallf                [lane*TX_FS_WD+:TX_FS_WD]                 ),           //in vmain connect phy_mac_locallf
  .phy_mac_dirfeedback                         (phy_mac_dirfeedback            [lane*DIRFEEDBACK_WD+:DIRFEEDBACK_WD]     ),           //in vmain connect phy_mac_dirfeedback
  .phy_mac_fomfeedback                         (phy_mac_fomfeedback            [lane*FOMFEEDBACK_WD+:FOMFEEDBACK_WD]     ),           //in vmain connect phy_mac_fomfeedback
                         
  // CCIX Signals
  .phy_mac_esm_calibrt_complete                (phy_mac_esm_calibrt_complete   [lane]                                    ),                                                    
  .phy_reg_esm_data_rate0                      (phy_reg_esm_data_rate0         [lane*7+:7]                               ),                                                    
  .phy_reg_esm_data_rate1                      (phy_reg_esm_data_rate1         [lane*7+:7]                               ),                                                    
  .phy_reg_esm_calibrt_req                     (phy_reg_esm_calibrt_req        [lane]                                    ),                                                    
  .phy_reg_esm_enable                          (phy_reg_esm_enable             [lane]                                    ),                                                    
  .write_ack_for_esm_calibrt_req               (write_ack_for_esm_calibrt_req  [lane]                                    ),                                                     
  .lane_disabled                               (lane_disabled                  [lane]                                    ),                                                    
 
  // outputs to pll
  .pcs_pll_pclk_off_req                        (pcs_pll_pclk_off_req           [lane]                                    ),            // Request to turn off pclk      
  .pcs_pll_rate_change_req                     (pcs_pll_rate_change_req        [lane]                                    ),            // Request to change the rate       
  // outputs to sdm
  
   
  .pcs_sdm_txdata                              (pcs_sdm_txdata                 [lane*PIPE_DATA_WD+:PIPE_DATA_WD]                               ),
  .pcs_sdm_txdatak                             (pcs_sdm_txdatak                [lane]                                    ),  
  .pcs_sdm_loopback                            (pcs_sdm_loopback               [lane]                                    ), 
  .pcs_sdm_txdetectrx                          (pcs_sdm_txdetectrx             [lane]                                    ), 
  .pcs_sdm_txelecidle                          (pcs_sdm_txelecidle             [lane]                                    ), 
  .pcs_sdm_blockaligncontrol                   (pcs_sdm_blockaligncontrol      [lane]                                    ),
  .pcs_sdm_elasticbuffermode                   (pcs_sdm_elasticbuffermode      [lane]                                    ),
  .pcs_sdm_encodedecodebypass                  (pcs_sdm_encodedecodebypass     [lane]                                    ), 
  .pcs_sdm_rxstandby                           (pcs_sdm_rxstandby              [lane]                                    ),
  .pcs_sdm_txcompliance                        (pcs_sdm_txcompliance           [lane]                                    ), 
  .pcs_sdm_beacongen                           (pcs_sdm_beacongen              [lane]                                    ), 
  .pcs_sdm_powerdown                           (pcs_sdm_powerdown                                                        ),       
  .pcs_sdm_rxpolarity                          (pcs_sdm_rxpolarity             [lane]                                    ), 
  .pcs_sdm_txerror                             (pcs_sdm_txerror                [lane]                                    ), 
  .pcs_sdm_rate                                (pcs_sdm_rate                   [lane*3+:3]                               ),
  .pcs_sdm_curr_rate                           (pcs_sdm_curr_rate              [lane*3+:3]                               ),  
  .pcs_sdm_txdatavalid                         (pcs_sdm_txdatavalid            [lane]                                    ), 
  .pcs_sdm_txstartblock                        (pcs_sdm_txstartblock           [lane]                                    ), 
  .pcs_sdm_txsynchdr                           (pcs_sdm_txsynchdr              [lane*2+:2]                               ),  
  .pcs_sdm_rx_clock_off                        (pcs_sdm_rx_clock_off           [lane]                                    ),                                                    
  .pcs_sdm_reset_n                             (pcs_sdm_reset_n                [lane]                                    ),                                                    
  .pcs_sdm_set_disp                            (pcs_sdm_set_disp               [lane]                                    )                                                    

);
end
endgenerate

endmodule

