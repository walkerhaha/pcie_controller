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
// ---    $DateTime: 2020/10/09 03:24:51 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pcs_lane.v#9 $
// -------------------------------------------------------------------------
// --- Module Description: PCS per-lane logic
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_pcs_lane #(
  parameter TP        = -1,
  parameter PIPE_NB   = -1,
  parameter WIDTH_WD  = -1,
  parameter RXSB_WD   = -1,
  parameter TX_PSET_WD     = -1,                              // Width of Transmitter Equalization Presets
  parameter TX_COEF_WD     = -1,                              // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
  parameter DIRFEEDBACK_WD = -1,                              // Width of Direction Change
  parameter FOMFEEDBACK_WD = -1,                              // Width of Figure of Merit
  parameter TX_FS_WD       = -1,                              // Width of LF or FS
  parameter SEED           = -1,
  parameter PIPE_DATA_WD   = -1,   
  parameter TXEI_WD        = -1    
) (

// General Inputs
  input                       refclk,                         // reference clock input
  input                       phy_rst_n,                      // PIPE Reset input
  input                       pclk,                           // Pipe clock  
  input                       txclk,                          // Txclk 
  input                       txclk_ug,                       // free running version of txclk    
  input                       txbitclk,                       // Txbitclk
  input                       recvdclk,
  input                       recvdclk_pipe,
  input                       pclk_mode_input,  
  // PIPE Inputs
  input   [(PIPE_NB*PIPE_DATA_WD)-1:0]   mac_phy_txdata,                 // Parallel transmit data
  input   [PIPE_NB-1:0]       mac_phy_txdatak,                // K char indication per bytephy_1s.v
  input                       mac_phy_txdetectrx_loopback,    // Enable recevie detection sequence generation (or loopback)
  input   [TXEI_WD-1:0]                    mac_phy_txelecidle,             // Place transmitter into electrical idle
  input                       mac_phy_txcompliance,           // Enable transmission of compliance sequence
  input                       mac_phy_rxpolarity,             // Invert the receive data
  input   [3:0]               mac_phy_powerdown,              // Signal to go to specific power state
  input                       mac_phy_elasticbuffermode,      // 0 = empty mode ; 1 = half full mode
  input   [2:0]               mac_phy_rate,                   // 1 = change speed to 5 Gbit/s, 2 = change speed to 8 Gbit/s
  input   [WIDTH_WD-1:0]      mac_phy_width,                  // pipe width: 0 = 1s; 1 = 2s; 2 = 4s; 3 = 8s
  input   [3:0]               mac_phy_pclk_rate,              // pipe pclk rate: 0 = 62.5 ; 1 = 125 ; 2 = 250 ; 3 = 500 ; 4 = 100
  input                       mac_phy_txdatavalid, 
  input                       mac_phy_rxstandby,  
  input                       mac_phy_sris_mode,
  input                       mac_phy_txdeemph,               // selects transmitter de-emphasis in the PHY
  input   [2:0]               mac_phy_txmargin,               // selects transmitter voltage levels in the PHY
  input                       mac_phy_txswing,                // selects transmitter voltage swing level in the PHY                                                             
  input                       mac_phy_txstartblock,           // first byte of the data interface is the first byte of the block.
  input   [1:0]               mac_phy_txsynchdr,              // sync header to use in the next 130b block
  input                       mac_phy_blockaligncontrol,      // block align control
  input                       mac_phy_encodedecodebypass,     // encode decode bypass
  input   [1:0]               mac_phy_pclkreq_n,              // request to turn off/on pclk
  input                       asyncpowerchangeack,            // pipe43 signal: handshake between phystatus and ack
  input                       txcommonmode_disable,           //
  input                       rxelecidle_disable,             //

  input                       mac_phy_invalid_req,            //
  input                       mac_phy_rxeqeval,               //
  input [TX_PSET_WD-1:0]      mac_phy_local_pset_index,       //
  input                       mac_phy_getlocal_pset_coef,     //
  input                       mac_phy_rxeqinprogress,         //
  input [TX_FS_WD-1:0]        mac_phy_fs,                     //
  input [TX_FS_WD-1:0]        mac_phy_lf,                     //
 
  input                       serdes_arch,
  input [WIDTH_WD-1:0]        rxwidth,
  input                       serdes_pipe_turnoff_lanes,

  // input Command interface inputs
  // phy_tb_ctrl for equalization
  input                       set_eq_feedback_delay, 
  input integer               eq_feedback_delay,
  input                       set_eq_dirfeedback,
  input [DIRFEEDBACK_WD-1:0]  eq_dirfeedback_value,           
  input                       set_eq_fomfeedback,
  input [FOMFEEDBACK_WD-1:0]  eq_fomfeedback_value,
  input                       set_localfs_g3,
  input [TX_FS_WD-1:0]        localfs_value_g3,
  input                       set_localfs_g4,
  input [TX_FS_WD-1:0]        localfs_value_g4,
  input                       set_localfs_g5,
  input [TX_FS_WD-1:0]        localfs_value_g5,
  input                       set_locallf_g3,
  input [TX_FS_WD-1:0]        locallf_value_g3,
  input                       set_locallf_g4,
  input [TX_FS_WD-1:0]        locallf_value_g4,
  input                       set_locallf_g5,
  input [TX_FS_WD-1:0]        locallf_value_g5,
  input                       set_local_tx_pset_coef_delay,
  input integer               local_tx_pset_coef_delay,  
  input                       set_local_tx_pset_coef,
  input [TX_COEF_WD-1:0]      local_tx_pset_coef_value ,
  input                       set_rxadaption,  
  input [2:0]                 update_localfslf_mode,
  
  // phy_tb_ctrl for powerdown/rate
  input                       powerdown_random_phystatus_en,        // enable/disable to generate phystatus with random delay at powerdown change
  input   [2:0]               p1_random_range,                      // delay to change to P1
  input                       p1_phystatus_time_load_en,            // Enable/disable to set a specific value as delay for phystatus at P1 entry
  input   [12:0]              p1_phystatus_time,                    // The value set if above is enabled
  input                       rate_random_phystatus_en,             // enable/disable to generate phystatus with random delay at rate change
  input                       p2_phystatus_rise_random_en,          // enable/disable random delay generation for phystatus assertion in P2 entry
  input                       p2_random_phystatus_rise_load_en,     // Enable/disable to set a specific value as delay for phystatus assertion at P2 entry    
  input [12:0]                p2_random_phystatus_rise_value,       // The value set for P2 entry if above is enabled                                         
  input                       p2_phystatus_fall_random_en,          // enable/disable random delay generation for phystatus deassertion in P2 entry           
  input                       p2_random_phystatus_fall_load_en,     // Enable/disable to set a specific value as delay for phystatus deassertion at P2 entry  
  input [12:0]                p2_random_phystatus_fall_value,       // The value set for P2 entry if above is enabled                                         
  input                       P1X_to_P1_exit_mode,                  // 0 = any type ; 1 = always as P2 exit
  
  // PipeMessageBus Signals
  input   [7:0]               mac_phy_messagebus,
  output  [7:0]               phy_mac_messagebus,
  // phy_tb_ctrl for PipeMessageBus
  input                       set_p2m_messagebus,
  input [7:0]                 p2m_messagebus_command_value,
  input                       set_m2p_messagebus,
  input [7:0]                 m2p_messagebus_command_value,
  
  // phy_tb_ctrl for Margining at Receiver
  input                       VoltageSupported,
  input                       IndErrorSampler,
  input [6:0]                 MaxVoltageOffset,
  input [5:0]                 MaxTimingOffset,
  input [6:0]                 UnsupportedVoltageOffset,
  input                       SampleReportingMethod,
  input [1:0]                 margin_error_cnt_mode,
  input [31:0]                margin_cycle_for_an_error,
  input [3:0]                 margin_bit_error_rate_factor,
  input [1:0]                 set_margin_cnt,
  input [6:0]                 margin_sampl_cnt_to_set,
  input [5:0]                 margin_error_cnt_to_set,
  input                       random_margin_status_en,               // Enable/disable random delay when generationg margin_status
  input   [7:0]               fixed_margin_status_thr,               // Fixed delay when generationg margin_status
  // phy_tb_ctrl for ElasticBufferLocation
  input                       ebuf_location_upd_en,
  
  // PCLK as PHY input
  // input/output
  input                       mac_phy_pclkchangeack,
  output                      phy_mac_pclkchangeok,
   
  // inputs from pll
  input                       pll_pcs_pclk_off_ack,                  // Pclk turn off/on ack
  input                       pll_pcs_lock,                          // Pclk is back and locked 
  input                       pll_pcs_ready,                 

  // inputs from sdm
  input [PIPE_DATA_WD-1:0]    sdm_pcs_dec8b10b_rxdata,               // Receive byte data from 8B10B decoder            
  input                       sdm_pcs_dec8b10b_rxdatak,              // K-character indication for RX data              
  input                       sdm_pcs_dec8b10b_rxdata_dv,            // Indication that RX data is valid                
  input                       sdm_pcs_dec8b10b_rxdatavalid,
  input                       sdm_pcs_dec8b10b_rxdisperror,          // 8B10B disparity error                           
  input                       sdm_pcs_dec8b10b_rxcodeerror,          // 8B10B code violation                            
  input                       sdm_pcs_elasbuf_rxunderflow,           // Elastic buffer experienced underflow            
  input                       sdm_pcs_elasbuf_rxoverflow,            // Elastic buffer experienced overflow             
  input                       sdm_pcs_elasbuf_rxskipadded,           // Elastic buffer added a skip                     
  input                       sdm_pcs_elasbuf_rxskipremoved,         // Elastic buffer removed a skip                   
  input                       sdm_pcs_rxdetected,                    // Results from SerDes receiver detection process
  input                       sdm_pcs_comma_lock,                    // Comma detect function in "comma lock"
  input                       sdm_pcs_dec8b10b_rxstartblock,         // first byte of the data interface is the first
  input  [1:0]                sdm_pcs_dec8b10b_rxsynchdr,            // sync header to use in the next 130b block
  input                       sdm_pcs_skp_broken,    
  input  [7:0]                sdm_pcs_ebuf_location,

// =========================================================================
// Outputs
// PIPE Outputs
  output  [(PIPE_NB*PIPE_DATA_WD)-1:0]    phy_mac_rxdata,                       // Parallel receive data
  output  [PIPE_NB-1:0]        phy_mac_rxdatak,                      // K char indication
  output                       phy_mac_rxvalid,                      // Receive data valid
  output  [2:0]                phy_mac_rxstatus,                     // Receiver status (encoded)
  output                       phy_mac_phystatus,                    // Indicates completion of operation (context specific)
  output                       phy_mac_pclkack_n,                    // acknoleadge that pclk if off
  output                       phy_mac_rxdatavalid,
  output  [RXSB_WD-1:0]        phy_mac_rxstartblock,                 // first byte of the data interface is the first byte of the block.
  output  [RXSB_WD*2-1:0]      phy_mac_rxsynchdr,                    // sync header that was strippend out of the 130 bit block
  output                       phy_mac_rxstandbystatus,                
  output                       phy_reg_txswing,
  output [TX_COEF_WD-1:0]      phy_reg_txdeemph,
  output                       phy_reg_invalid_req,
  output                       phy_reg_rxeqeval,
  output [5:0]                 phy_reg_local_pset_index,
  output                       phy_reg_getlocal_pset_coef,
  output                       phy_reg_rxeqinprogress,
  output [TX_FS_WD-1:0]        phy_reg_fs,
  output [TX_FS_WD-1:0]        phy_reg_lf,
  output [TX_COEF_WD-1:0]      phy_mac_local_tx_pset_coef,          //in vmain connect phy_mac_local_tx_pset_coef
  output                       phy_mac_local_tx_coef_valid,         //in vmain connect phy_mac_local_tx_coef_valid
  output [TX_FS_WD-1:0]        phy_mac_localfs,                     //in vmain connect phy_mac_localfs
  output [TX_FS_WD-1:0]        phy_mac_locallf,                     //in vmain connect phy_mac_locallf
  output [DIRFEEDBACK_WD-1:0]  phy_mac_dirfeedback,                 //in vmain connect phy_mac_dirfeedback
  output [FOMFEEDBACK_WD-1:0]  phy_mac_fomfeedback,                 //in vmain connect phy_mac_fomfeedback
                    
  // CCIX Signals
  input                        phy_mac_esm_calibrt_complete,
  output [6:0]                 phy_reg_esm_data_rate0,
  output [6:0]                 phy_reg_esm_data_rate1,
  output                       phy_reg_esm_calibrt_req,
  output                       phy_reg_esm_enable,
  output                       write_ack_for_esm_calibrt_req, 
  output                       lane_disabled,
 
  // outputs to pll
  output                        pcs_pll_pclk_off_req,               // Request to turn off pclk
  output                        pcs_pll_rate_change_req,            // Request to change the rate
  // outputs to sdm
  // PCS to SDM Outputs
  output  [PIPE_DATA_WD-1:0]                 pcs_sdm_txdata,           
  output                        pcs_sdm_txdatak,           
  output                        pcs_sdm_loopback,         
  output                        pcs_sdm_txdetectrx,       
  output                        pcs_sdm_txelecidle,       
  output                        pcs_sdm_txcompliance,     
  output                        pcs_sdm_beacongen,        
  output  [3:0]                 pcs_sdm_powerdown,        
  output                        pcs_sdm_rxpolarity,
  output                        pcs_sdm_blockaligncontrol,
  output                        pcs_sdm_elasticbuffermode,
  output                        pcs_sdm_encodedecodebypass, 
  output                        pcs_sdm_rxstandby,                         
  output  [2:0]                 pcs_sdm_rate,             
  output  [2:0]                 pcs_sdm_curr_rate,        
  output                        pcs_sdm_txdatavalid,      
  output                        pcs_sdm_txstartblock,     
  output  [1:0]                 pcs_sdm_txsynchdr,        
  
  output                        pcs_sdm_rx_clock_off,
  output                        pcs_sdm_reset_n,
  output                        pcs_sdm_set_disp,
  output                        pcs_sdm_txerror
   
                                     
);
// rx signals from pipe2phy to gasket
wire [PIPE_DATA_WD-1:0]  int_pcs_phy_mac_rxdata;            
wire        int_pcs_phy_mac_rxdatak;           
wire        int_pcs_phy_mac_rxvalid;           
wire [2:0]  int_pcs_phy_mac_rxstatus;          
//wire        int_pcs_phy_mac_rxelecidle;        
wire        int_pcs_phy_mac_phystatus;         
wire        int_pcs_phy_mac_rxstartblock;      
wire [1:0]  int_pcs_phy_mac_rxsynchdr;         
wire        int_pcs_phy_mac_rxdatavalid;   

// tx signals from gasket to pipe2phy
wire [PIPE_DATA_WD-1:0]  int_pcs_mac_phy_txdata;
wire        int_pcs_mac_phy_txdatak;
wire        int_pcs_mac_phy_txdetectrx_loopback;
wire        int_pcs_mac_phy_txcompliance;
wire        int_pcs_mac_phy_rxpolarity;
wire [2:0]  int_pcs_mac_phy_rate;
wire [WIDTH_WD-1:0]  int_pcs_mac_phy_width;
wire [3:0]  int_pcs_mac_phy_pclk_rate;
wire        int_pcs_mac_phy_txdatavalid;
wire        int_pcs_mac_phy_txdeemph;
wire [2:0]  int_pcs_mac_phy_txmargin;
wire        int_pcs_mac_phy_txswing;
wire        int_pcs_mac_phy_txstartblock;
wire [1:0]  int_pcs_mac_phy_txsynchdr;
wire        int_pcs_mac_phy_blockaligncontrol;
wire        int_pcs_mac_phy_txelecidle;    
wire [7:0]  int_pcs_ebuf_location;
wire        int_pcs_phy_mac_pclkchangeok;

wire        pipe_rst_n;


wire gasket_eqbfm_phy_mac_rxvalid;
wire eqpa_bfm_phystatus;
wire eqpa_feedback_valid;
wire gasket_phystatus;
assign phy_mac_phystatus = (`GPHY_IS_PIPE_51) ?   gasket_phystatus:
                                                  eqpa_bfm_phystatus | gasket_phystatus;
assign eqpa_feedback_valid =  eqpa_bfm_phystatus;                                                 
     
// output from reg bus                                                
wire    [7:0]           phy_reg_ebuf_depth_cntrl; // Only register is implemented. This function to use is not implemented
wire                    phy_reg_rxpolarity;
wire                    phy_reg_ebuf_mode;
wire    [2:0]           phy_reg_txmargin;
wire                    phy_reg_ebuf_rst_control; // Only register is implemented. This function to use is not implemented
wire                    phy_reg_localfslf_done;      
wire                    phy_reg_blockaligncontrol; 
wire                    phy_reg_encodedecodebypass;                                  
                                                  

assign pcs_sdm_elasticbuffermode  = (`GPHY_IS_PIPE_51) ? phy_reg_ebuf_mode          : mac_phy_elasticbuffermode;
assign pcs_sdm_blockaligncontrol  = (`GPHY_IS_PIPE_51) ? phy_reg_blockaligncontrol  : int_pcs_mac_phy_blockaligncontrol;
assign pcs_sdm_encodedecodebypass = (`GPHY_IS_PIPE_51) ? phy_reg_encodedecodebypass : mac_phy_encodedecodebypass;

wire                eqpa_local_tx_coef_valid_g3;
wire                eqpa_local_tx_coef_valid_g4;
wire                eqpa_local_tx_coef_valid_g5;
wire                g3_mac_phy_rate_pulse;
wire                g4_mac_phy_rate_pulse;
wire                g5_mac_phy_rate_pulse;
wire [TX_FS_WD-1:0] eqpa_localfs_g3;
wire [TX_FS_WD-1:0] eqpa_locallf_g3;
wire [TX_FS_WD-1:0] eqpa_localfs_g4;
wire [TX_FS_WD-1:0] eqpa_locallf_g4;
wire [TX_FS_WD-1:0] eqpa_localfs_g5;
wire [TX_FS_WD-1:0] eqpa_locallf_g5;
wire                pclk_stable;


// From phy_reg or MAC to eq_bfm
wire                      selected_rxpolarity;
wire                      selected_txswing;
wire                      selected_invalid_req;
wire                      selected_rxeqeval;
wire    [TX_PSET_WD-1:0]  selected_local_pset_index;
wire                      selected_getlocal_pset_coef;
wire                      selected_rxeqinprogress;
wire    [TX_FS_WD-1:0]    selected_fs;
wire    [TX_FS_WD-1:0]    selected_lf;

assign selected_rxpolarity         = (`GPHY_IS_PIPE_51) ? phy_reg_rxpolarity         : int_pcs_mac_phy_rxpolarity;
assign selected_txswing            = (`GPHY_IS_PIPE_51) ? phy_reg_txswing            : mac_phy_txswing;
assign selected_invalid_req        = (`GPHY_IS_PIPE_51) ? phy_reg_invalid_req        : mac_phy_invalid_req;
assign selected_rxeqeval           = (`GPHY_IS_PIPE_51) ? phy_reg_rxeqeval           : mac_phy_rxeqeval;
assign selected_local_pset_index   = (`GPHY_IS_PIPE_51) ? phy_reg_local_pset_index   : mac_phy_local_pset_index;
assign selected_getlocal_pset_coef = (`GPHY_IS_PIPE_51) ? phy_reg_getlocal_pset_coef : mac_phy_getlocal_pset_coef;
assign selected_rxeqinprogress     = (`GPHY_IS_PIPE_51) ? phy_reg_rxeqinprogress     : mac_phy_rxeqinprogress;
assign selected_fs                 = (`GPHY_IS_PIPE_51) ? phy_reg_fs                 : mac_phy_fs;
assign selected_lf                 = (`GPHY_IS_PIPE_51) ? phy_reg_lf                 : mac_phy_lf;



wire [PIPE_DATA_WD-1:0]   gasket_in_phy_mac_rxdata;
wire                      gasket_in_phy_mac_rxdatak;
wire                      gasket_in_phy_mac_rxvalid;
wire                      gasket_in_phy_mac_rxdatavalid;
wire                      gasket_in_phy_mac_rxstartblock;
wire [1:0]                gasket_in_phy_mac_rxsynchdr;
wire                      gasket_int_clk;
wire                      randomize_P1X_to_P1;


assign gasket_int_clk = serdes_arch  ? recvdclk : txclk ;
assign gasket_in_phy_mac_rxdata       = serdes_arch  ? sdm_pcs_dec8b10b_rxdata        :    int_pcs_phy_mac_rxdata ;
assign gasket_in_phy_mac_rxdatak      = serdes_arch  ? sdm_pcs_dec8b10b_rxdatak       :    int_pcs_phy_mac_rxdatak;
assign gasket_in_phy_mac_rxvalid      = serdes_arch  ? sdm_pcs_dec8b10b_rxdata_dv     :    int_pcs_phy_mac_rxvalid;
assign gasket_in_phy_mac_rxdatavalid  = serdes_arch  ? sdm_pcs_dec8b10b_rxdatavalid   :    int_pcs_phy_mac_rxdatavalid;
assign gasket_in_phy_mac_rxstartblock = serdes_arch  ? sdm_pcs_dec8b10b_rxstartblock  :    int_pcs_phy_mac_rxstartblock;
assign gasket_in_phy_mac_rxsynchdr    = serdes_arch  ? sdm_pcs_dec8b10b_rxsynchdr     :    int_pcs_phy_mac_rxsynchdr;
// ----------------------------------------------------------
// Gasket
// ----------------------------------------------------------
DWC_pcie_gphy_pipe_gasket #(
    .PIPE_NB                        (PIPE_NB),
    .TP                             (TP),
    .WIDTH_WD                       (WIDTH_WD),
    .RXSB_WD                        (RXSB_WD),
    .PIPE_DATA_WD                   (PIPE_DATA_WD), 
    .TXEI_WD                        (TXEI_WD)     
) u_freq_step(
    .int_clk                        (gasket_int_clk               ),    
    .recvdclk_pipe                  (recvdclk_pipe                ),
    .txclk                          (txclk                        ),   
    .phy_rst_n                      (phy_rst_n                    ),
    .pclk                           (pclk                         ),
    .lock                           (pll_pcs_lock                 ),
    .pclk_mode_input                (pclk_mode_input              ),
    .lane_disabled                  (lane_disabled                ),
    // rx input
    .phy_mac_rxdata                 (gasket_in_phy_mac_rxdata     ),
    .phy_mac_rxdatak                (gasket_in_phy_mac_rxdatak    ),
    .phy_mac_rxvalid                (gasket_in_phy_mac_rxvalid    ),
    .phy_mac_rxdatavalid            (gasket_in_phy_mac_rxdatavalid),
    .phy_mac_rxstatus               (int_pcs_phy_mac_rxstatus     ),
    .phy_mac_phystatus              (int_pcs_phy_mac_phystatus    ),
    .phy_mac_rxstartblock           (gasket_in_phy_mac_rxstartblock),
    .phy_mac_rxsynchdr              (gasket_in_phy_mac_rxsynchdr  ),
    .phy_mac_pipe_rxdatavalid       (1'b1                         ),
    .phy_mac_pclkchangeok           (int_pcs_phy_mac_pclkchangeok ),
    
    .serdes_arch                    (serdes_arch                  ),
    .rxwidth                        (rxwidth                      ),
    
    .phy_mac_ebuf_location          (sdm_pcs_ebuf_location        ),
    
    .mac_phy_pclkreq_n              (mac_phy_pclkreq_n            ),
    .rxelecidle_disable             (rxelecidle_disable           ),
    .txcommonmode_disable           (txcommonmode_disable         ),    
    .P1X_to_P1_exit_mode            (P1X_to_P1_exit_mode          ),
    .randomize_P1X_to_P1            (randomize_P1X_to_P1          ), 
          
    // rx output
    .sdown_phy_mac_rxdata           (phy_mac_rxdata               ),
    .sdown_phy_mac_rxdatak          (phy_mac_rxdatak              ),
    .sdown_phy_mac_rxvalid          (gasket_eqbfm_phy_mac_rxvalid ),
    .sdown_phy_mac_rxdatavalid      (phy_mac_rxdatavalid          ),
    .sdown_phy_mac_rxstatus         (phy_mac_rxstatus             ),
    .sdown_phy_mac_phystatus        (gasket_phystatus             ),
    .sdown_phy_mac_ebuf_location    (int_pcs_ebuf_location        ),
    .sdown_phy_mac_rxstartblock     (phy_mac_rxstartblock         ),
    .sdown_phy_mac_rxsynchdr        (phy_mac_rxsynchdr            ),
    .sdown_phy_mac_pclkchangeok     (phy_mac_pclkchangeok         ),   

    // tx input
    .mac_phy_txdata                 (mac_phy_txdata               ),
    .mac_phy_txdatak                (mac_phy_txdatak              ),
    .mac_phy_txelecidle             (mac_phy_txelecidle           ),
    .mac_phy_txdetectrx_loopback    (mac_phy_txdetectrx_loopback  ),
    .mac_phy_txcompliance           (mac_phy_txcompliance         ),
    .mac_phy_rxpolarity             (mac_phy_rxpolarity           ),
    .mac_phy_powerdown              (mac_phy_powerdown            ),
    .mac_phy_rate                   (mac_phy_rate                 ),
    .mac_phy_width                  (mac_phy_width                ),
    .mac_phy_pclk_rate              (mac_phy_pclk_rate            ),
    .mac_phy_txdatavalid            (mac_phy_txdatavalid          ),
    .mac_phy_txdeemph               (mac_phy_txdeemph             ),
    .mac_phy_txmargin               (mac_phy_txmargin             ),
    .mac_phy_txswing                (mac_phy_txswing              ),
    .mac_phy_txstartblock           (mac_phy_txstartblock         ),
    .mac_phy_txsynchdr              (mac_phy_txsynchdr            ),
    .mac_phy_pipe_txdatavalid       (1'b1                         ),
    .smlh_blockaligncontrol         (mac_phy_blockaligncontrol    ),
`ifdef GPHY_ESM_SUPPORT
    .esm_enable                     (phy_reg_esm_enable           ),
    .esm_data_rate0                 (phy_reg_esm_data_rate0       ),
    .esm_data_rate1                 (phy_reg_esm_data_rate1       ),
`endif // GPHY_ESM_SUPPORT 
    
    
    // tx output
    .sup_mac_phy_txdata             (int_pcs_mac_phy_txdata       ),
    .sup_mac_phy_txdatak            (int_pcs_mac_phy_txdatak      ),
    .sup_mac_phy_txdetectrx_loopback(int_pcs_mac_phy_txdetectrx_loopback ),
    .sup_mac_phy_txcompliance       (int_pcs_mac_phy_txcompliance        ),
    .sup_mac_phy_rxpolarity         (int_pcs_mac_phy_rxpolarity          ),
    .sup_mac_phy_rate               (int_pcs_mac_phy_rate                ),
    .sup_mac_phy_width              (int_pcs_mac_phy_width               ),
    .sup_mac_phy_pclk_rate          (int_pcs_mac_phy_pclk_rate           ),
    .sup_mac_phy_txdatavalid        (int_pcs_mac_phy_txdatavalid         ),
    .sup_mac_phy_txdeemph           (int_pcs_mac_phy_txdeemph            ),
    .sup_mac_phy_txmargin           (int_pcs_mac_phy_txmargin            ),
    .sup_mac_phy_txswing            (int_pcs_mac_phy_txswing             ),
    .sup_mac_phy_txstartblock       (int_pcs_mac_phy_txstartblock        ),
    .sup_mac_phy_txsynchdr          (int_pcs_mac_phy_txsynchdr           ),
    .sup_smlh_blockaligncontrol     (int_pcs_mac_phy_blockaligncontrol   ),
    .sup_mac_phy_txelecidle         (int_pcs_mac_phy_txelecidle          )
);

// ========================================================================
// Pipe to PHY reconcilliation module:
//
// This module does all translation of SerDes specific signals to/from the
// PIPE interface.
// ========================================================================

DWC_pcie_gphy_pipe2phy #(
   .TP             (TP),
   .PIPE_DATA_WD   (PIPE_DATA_WD) 
  ) 
   u0_pipe2phy (
// MAC Inputs
    .clk                            (txclk_ug                           ), // we connect the free running version of txclk
    .rst_n                          (phy_rst_n                          ),
    .serdes_arch                    (serdes_arch                        ),
    
    // inputs from gasket
    .mac_phy_txdata                 (int_pcs_mac_phy_txdata             ),
    .mac_phy_txdatak                (int_pcs_mac_phy_txdatak            ),
    .mac_phy_txdetectrx_loopback    (int_pcs_mac_phy_txdetectrx_loopback),
    .mac_phy_txdatavalid            (int_pcs_mac_phy_txdatavalid        ),
    .mac_phy_txstartblock           (int_pcs_mac_phy_txstartblock       ),
    .mac_phy_txsynchdr              (int_pcs_mac_phy_txsynchdr          ),
    .mac_phy_txelecidle             (int_pcs_mac_phy_txelecidle         ),
    .mac_phy_txcompliance           (int_pcs_mac_phy_txcompliance       ),
    .mac_phy_rxpolarity             (selected_rxpolarity                ),
    .mac_phy_rate                   (int_pcs_mac_phy_rate               ),
    .mac_phy_pclk_rate              (int_pcs_mac_phy_pclk_rate          ),
    
    .mac_phy_powerdown              (mac_phy_powerdown                  ),
    .mac_phy_pclkreq_n              (mac_phy_pclkreq_n                  ),         
    .mac_phy_rxstandby              (mac_phy_rxstandby                  ), 
    .asyncpowerchangeack            (asyncpowerchangeack                ), 
  
    // outputs
    .phy_mac_rxstandbystatus        (phy_mac_rxstandbystatus            ), 
    .phy_mac_pclkack_n              (phy_mac_pclkack_n                  ), 
    
    // PCLK as PHY input
  // input/output
    .mac_phy_pclkchangeack          (mac_phy_pclkchangeack          ),
    .phy_mac_pclkchangeok           (int_pcs_phy_mac_pclkchangeok   ),
    .pclk_mode_input                (pclk_mode_input                ),
    .serdes_pipe_turnoff_lanes      (serdes_pipe_turnoff_lanes      ),
    
    // control inputs
    .powerdown_random_phystatus_en    (powerdown_random_phystatus_en    ),  
    .p1_random_range                  (p1_random_range                  ),
    .p1_phystatus_time_load_en        (p1_phystatus_time_load_en        ),
    .p1_phystatus_time                (p1_phystatus_time                ),
    .p2_phystatus_rise_random_en      (p2_phystatus_rise_random_en      ),
    .p2_random_phystatus_rise_load_en (p2_random_phystatus_rise_load_en ),
    .p2_random_phystatus_rise_value   (p2_random_phystatus_rise_value   ),
    .p2_phystatus_fall_random_en      (p2_phystatus_fall_random_en      ),
    .p2_random_phystatus_fall_load_en (p2_random_phystatus_fall_load_en ),
    .p2_random_phystatus_fall_value   (p2_random_phystatus_fall_value   ),    
    .rate_random_phystatus_en         (rate_random_phystatus_en         ),
    .P1X_to_P1_exit_mode              (P1X_to_P1_exit_mode              ),
    .randomize_P1X_to_P1              (randomize_P1X_to_P1              ),
    .update_localfslf_mode            (update_localfslf_mode),
              

    // SDM Inputs
    .dec8b10b_rxdata                (sdm_pcs_dec8b10b_rxdata            ),
    .dec8b10b_rxdatak               (sdm_pcs_dec8b10b_rxdatak           ),
    .dec8b10b_rxdata_dv             (sdm_pcs_dec8b10b_rxdata_dv         ),
    .dec8b10b_rxdatavalid           (sdm_pcs_dec8b10b_rxdatavalid       ),
    .dec8b10b_rxstartblock          (sdm_pcs_dec8b10b_rxstartblock      ),
    .dec8b10b_rxsynchdr             (sdm_pcs_dec8b10b_rxsynchdr         ),
    .dec8b10b_rxdisperror           (sdm_pcs_dec8b10b_rxdisperror       ),
    .dec8b10b_rxcodeerror           (sdm_pcs_dec8b10b_rxcodeerror       ),
    .elasbuf_rxunderflow            (sdm_pcs_elasbuf_rxunderflow        ),
    .elasbuf_rxoverflow             (sdm_pcs_elasbuf_rxoverflow         ),
    .elasbuf_rxskipadded            (sdm_pcs_elasbuf_rxskipadded        ),
    .elasbuf_rxskipremoved          (sdm_pcs_elasbuf_rxskipremoved      ),
    .sds_sdm_rxdetected             (sdm_pcs_rxdetected                 ),
    .sds_sdm_comma_lock             (sdm_pcs_comma_lock                 ),
    .sds_sdm_ready                  (pll_pcs_ready                      ),
    .skp_broken                     (sdm_pcs_skp_broken                 ),
    
    // pll inputs
    .lock                           (pll_pcs_lock                       ),
    .pclk_off_ack                   (pll_pcs_pclk_off_ack               ),
    //reg bus cont input
    .phy_reg_localfslf_done         (phy_reg_localfslf_done             ),
    
    `ifdef GPHY_ESM_SUPPORT
    .esm_enable                     (phy_reg_esm_enable                 ),
    .esm_data_rate0                 (phy_reg_esm_data_rate0             ),
    .esm_data_rate1                 (phy_reg_esm_data_rate1             ),
    `endif // GPHY_ESM_SUPPORT 

// Outputs
    .phy_mac_rxdata                 (int_pcs_phy_mac_rxdata             ),
    .phy_mac_rxdatak                (int_pcs_phy_mac_rxdatak            ),
    .phy_mac_rxvalid                (int_pcs_phy_mac_rxvalid            ),
    .phy_mac_rxstatus               (int_pcs_phy_mac_rxstatus           ),
    .phy_mac_phystatus              (int_pcs_phy_mac_phystatus          ),    
    .phy_mac_rxstartblock           (int_pcs_phy_mac_rxstartblock       ),
    .phy_mac_rxsynchdr              (int_pcs_phy_mac_rxsynchdr          ),
    .phy_mac_rxdatavalid            (int_pcs_phy_mac_rxdatavalid        ),
    
// PCS to SDM Outputs
    .sdm_sds_txdata                 (pcs_sdm_txdata                     ),
    .sdm_sds_txdatak                (pcs_sdm_txdatak                    ),
    .sdm_sds_reset_n                (pcs_sdm_reset_n                    ),
    .sdm_sds_loopback               (pcs_sdm_loopback                   ),
    .sdm_sds_rxstandby              (pcs_sdm_rxstandby                  ),
    .sdm_sds_txdetectrx             (pcs_sdm_txdetectrx                 ),
    .sdm_sds_txelecidle             (pcs_sdm_txelecidle                 ),
    .sdm_sds_txcompliance           (pcs_sdm_txcompliance               ),
    .sdm_sds_beacongen              (pcs_sdm_beacongen                  ),
    .sdm_sds_powerdown              (pcs_sdm_powerdown                  ),   
    .sdm_sds_rxpolarity             (pcs_sdm_rxpolarity                 ),
    .sdm_sds_txerror                (pcs_sdm_txerror                    ),
    .sdm_sds_rate                   (pcs_sdm_rate                       ),
    .sds_sdm_curr_rate              (pcs_sdm_curr_rate                  ),
    .sdm_sds_txdatavalid            (pcs_sdm_txdatavalid                ),
    .sdm_sds_txstartblock           (pcs_sdm_txstartblock               ),
    .sdm_sds_txsynchdr              (pcs_sdm_txsynchdr                  ),

// misc control outputs
    .sdm_sds_set_disp               (pcs_sdm_set_disp                   ),
    .rx_clock_off                   (pcs_sdm_rx_clock_off               ),
    
    .pclk_stable                    (pclk_stable                        ),  
    
    .pclk_off_req                   (pcs_pll_pclk_off_req               ),
    .rate_change_req                (pcs_pll_rate_change_req            ),
    .lane_disabled                  (lane_disabled                      )

);


//==============================================================================
// Margining at Receiver
//==============================================================================
// u_pipe_margin_bfm -> u_regbus_cont
wire                       phy_mac_margin_status;
wire                       phy_mac_margin_nak;
wire    [1:0]              phy_mac_margin_respinfo;
wire                       phy_mac_margin_cnt_updated;
wire    [6:0]              phy_mac_margin_sampl_cnt;
wire    [5:0]              phy_mac_margin_error_cnt;
// u_regbus_cont -> u_pipe_margin_bfm
wire                       phy_reg_margin_sampl_cnt_clr;
wire                       phy_reg_margin_error_cnt_clr;
wire                       phy_reg_margin_voltage_or_timing;
wire                       phy_reg_margin_up_down;
wire                       phy_reg_margin_left_right;
wire                       phy_reg_margin_start;
wire    [6:0]              phy_reg_margin_offset;

DWC_pcie_gphy_margin_bfm #(
    .TP       (TP),
    .WIDTH_WD (WIDTH_WD),
    .RXSB_WD  (RXSB_WD)
) u_pipe_margin_bfm (
// inputs
  .pclk                             (pclk),
  .phy_rst_n                        (phy_rst_n),
  .random_margin_status_en          (random_margin_status_en),
  .fixed_margin_status_thr          (fixed_margin_status_thr),
  .VoltageSupported                 (VoltageSupported),
  .IndErrorSampler                  (IndErrorSampler),
  .MaxVoltageOffset                 (MaxVoltageOffset),
  .MaxTimingOffset                  (MaxTimingOffset),
  .UnsupportedVoltageOffset         (UnsupportedVoltageOffset ),
  .SampleReportingMethod            (SampleReportingMethod),
  .mac_phy_rate                     (mac_phy_rate),
  .mac_phy_width                    (mac_phy_width),
  .phy_mac_rxstartblock             (phy_mac_rxstartblock),
  .phy_reg_margin_sampl_cnt_clr     (phy_reg_margin_sampl_cnt_clr),
  .phy_reg_margin_error_cnt_clr     (phy_reg_margin_error_cnt_clr),
  .phy_reg_margin_voltage_or_timing (phy_reg_margin_voltage_or_timing),
  .phy_reg_margin_start             (phy_reg_margin_start),
  .phy_reg_margin_left_right        (phy_reg_margin_left_right),
  .phy_reg_margin_up_down           (phy_reg_margin_up_down),
  .phy_reg_margin_offset            (phy_reg_margin_offset),
// outputs
  .phy_mac_margin_status            (phy_mac_margin_status),
  .phy_mac_margin_nak               (phy_mac_margin_nak),
  .phy_mac_margin_respinfo          (phy_mac_margin_respinfo),
  .phy_mac_margin_cnt_updated       (phy_mac_margin_cnt_updated),
  .phy_mac_margin_sampl_cnt         (phy_mac_margin_sampl_cnt),
  .phy_mac_margin_error_cnt         (phy_mac_margin_error_cnt),
// For Task
  .margin_error_cnt_mode            (margin_error_cnt_mode),
  .margin_cycle_for_an_error        (margin_cycle_for_an_error),
  .margin_bit_error_rate_factor     (margin_bit_error_rate_factor),
  .set_margin_cnt                   (set_margin_cnt),
  .margin_sampl_cnt_to_set          (margin_sampl_cnt_to_set),
  .margin_error_cnt_to_set          (margin_error_cnt_to_set)
);



//==============================================================================
// PHY Register I/F
//==============================================================================
DWC_pcie_gphy_regbus_cont #(
    .TP             (TP),
    .TX_COEF_WD     (TX_COEF_WD),
    .DIRFEEDBACK_WD (DIRFEEDBACK_WD),
    .FOMFEEDBACK_WD (FOMFEEDBACK_WD),
    .TX_FS_WD       (TX_FS_WD)
) u_regbus_cont (
// inputs
  .pclk                             (pclk),
  .phy_rst_n                        (phy_rst_n),
  .lane_disabled                    (lane_disabled),
// For Lane Margining
  .IndErrorSampler                  (IndErrorSampler),
  .SampleReportingMethod            (SampleReportingMethod),
  .phy_mac_margin_status            (phy_mac_margin_status),
  .phy_mac_margin_nak               (phy_mac_margin_nak),
  .phy_mac_margin_respinfo          (phy_mac_margin_respinfo),
  .phy_mac_margin_cnt_updated       (phy_mac_margin_cnt_updated),
  .phy_mac_margin_sampl_cnt         (phy_mac_margin_sampl_cnt),
  .phy_mac_margin_error_cnt         (phy_mac_margin_error_cnt),
  .phy_reg_margin_sampl_cnt_clr     (phy_reg_margin_sampl_cnt_clr),
  .phy_reg_margin_error_cnt_clr     (phy_reg_margin_error_cnt_clr),
  .phy_reg_margin_voltage_or_timing (phy_reg_margin_voltage_or_timing),
  .phy_reg_margin_start             (phy_reg_margin_start),
  .phy_reg_margin_left_right        (phy_reg_margin_left_right),
  .phy_reg_margin_up_down           (phy_reg_margin_up_down),
  .phy_reg_margin_offset            (phy_reg_margin_offset),
// For LowPinCount
  .ebuf_location_upd_en             (ebuf_location_upd_en),
  .phy_mac_ebuf_location            (int_pcs_ebuf_location),
  .phy_mac_local_tx_pset_coef       (phy_mac_local_tx_pset_coef),
  .eqpa_local_tx_coef_valid_g3      (eqpa_local_tx_coef_valid_g3),
  .eqpa_local_tx_coef_valid_g4      (eqpa_local_tx_coef_valid_g4),
  .eqpa_local_tx_coef_valid_g5      (eqpa_local_tx_coef_valid_g5),
  .update_localfslf_mode            (update_localfslf_mode),
  .eqpa_localfs_g3                  (eqpa_localfs_g3),
  .eqpa_locallf_g3                  (eqpa_locallf_g3),
  .eqpa_localfs_g4                  (eqpa_localfs_g4),
  .eqpa_locallf_g4                  (eqpa_locallf_g4),
  .eqpa_localfs_g5                  (eqpa_localfs_g5),
  .eqpa_locallf_g5                  (eqpa_locallf_g5),
  .eqpa_feedback_valid              (eqpa_feedback_valid),
  .g3_mac_phy_rate_pulse            (g3_mac_phy_rate_pulse),
  .g4_mac_phy_rate_pulse            (g4_mac_phy_rate_pulse),
  .g5_mac_phy_rate_pulse            (g5_mac_phy_rate_pulse),
  .phy_mac_dirfeedback              (phy_mac_dirfeedback),
  .phy_mac_fomfeedback              (phy_mac_fomfeedback),
  .phy_reg_ebuf_depth_cntrl         (phy_reg_ebuf_depth_cntrl),
  .phy_reg_rxpolarity               (phy_reg_rxpolarity),
  .phy_reg_ebuf_mode                (phy_reg_ebuf_mode),
  .phy_reg_invalid_req              (phy_reg_invalid_req),
  .phy_reg_rxeqinprogress           (phy_reg_rxeqinprogress),
  .phy_reg_rxeqeval                 (phy_reg_rxeqeval),
  .phy_reg_txdeemph                 (phy_reg_txdeemph),
  .phy_reg_getlocal_pset_coef       (phy_reg_getlocal_pset_coef),
  .phy_reg_local_pset_index         (phy_reg_local_pset_index),
  .phy_reg_fs                       (phy_reg_fs),
  .phy_reg_lf                       (phy_reg_lf),
  .phy_reg_txswing                  (phy_reg_txswing),
  .phy_reg_txmargin                 (phy_reg_txmargin),
  .phy_reg_ebuf_rst_control         (phy_reg_ebuf_rst_control),
  .phy_reg_blockaligncontrol        (phy_reg_blockaligncontrol),
  .phy_reg_encodedecodebypass       (phy_reg_encodedecodebypass),
// For CCIX
  .phy_mac_esm_calibrt_complete     (phy_mac_esm_calibrt_complete),
  .phy_reg_esm_data_rate0           (phy_reg_esm_data_rate0),
  .phy_reg_esm_data_rate1           (phy_reg_esm_data_rate1),
  .phy_reg_esm_calibrt_req          (phy_reg_esm_calibrt_req),
  .phy_reg_esm_enable               (phy_reg_esm_enable),
  .write_ack_for_esm_calibrt_req    (write_ack_for_esm_calibrt_req),
//
  .pclk_stable                      (pclk_stable),
  .phy_reg_localfslf_done           (phy_reg_localfslf_done),
// PipeMessageBus Signals
  .mac_phy_messagebus               (mac_phy_messagebus),
  .phy_mac_messagebus               (phy_mac_messagebus),
// Command interface
  .set_p2m_messagebus               (set_p2m_messagebus),
  .p2m_messagebus_command_value     (p2m_messagebus_command_value),
  .set_m2p_messagebus               (set_m2p_messagebus),
  .m2p_messagebus_command_value     (m2p_messagebus_command_value)
);



//==============================================================================
// PHY EQ EVAL SLV
//==============================================================================

DWC_pcie_gphy_eq_bfm
#(
   .TP   (TP),
   .TX_PSET_WD (TX_PSET_WD),
   .TX_COEF_WD (TX_COEF_WD),
   .DIRFEEDBACK_WD (DIRFEEDBACK_WD),
   .FOMFEEDBACK_WD (FOMFEEDBACK_WD),
   .TX_FS_WD (TX_FS_WD),
   .SEED (SEED)            
) u_pipe_eqpa_bfm
(
  .pclk                         ( pclk                         ),
  .phy_rst_n                    ( phy_rst_n                    ),
  .mac_phy_rate                 ( mac_phy_rate                 ),
  .mac_phy_txswing              ( selected_txswing             ),
  .mac_phy_invalid_req          ( selected_invalid_req         ),
  .mac_phy_rxeqeval             ( selected_rxeqeval            ),
  .mac_phy_local_pset_index     ( selected_local_pset_index    ),
  .mac_phy_getlocal_pset_coef   ( selected_getlocal_pset_coef  ),
  .mac_phy_rxeqinprogress       ( selected_rxeqinprogress      ),
  .mux_phy_mac_rxvalid          ( gasket_eqbfm_phy_mac_rxvalid ),
  .mux_phy_mac_rxdatavalid      ( phy_mac_rxdatavalid          ),
  .mac_phy_fs                   ( selected_fs                  ),
  .mac_phy_lf                   ( selected_lf                  ),
  .phy_mac_local_tx_pset_coef   ( phy_mac_local_tx_pset_coef   ),
  .phy_mac_local_tx_coef_valid  ( phy_mac_local_tx_coef_valid  ),
  .eqpa_local_tx_coef_valid_g3  ( eqpa_local_tx_coef_valid_g3  ),
  .eqpa_local_tx_coef_valid_g4  ( eqpa_local_tx_coef_valid_g4  ),
  .eqpa_local_tx_coef_valid_g5  ( eqpa_local_tx_coef_valid_g5  ),
  .g3_mac_phy_rate_pulse        ( g3_mac_phy_rate_pulse        ),
  .g4_mac_phy_rate_pulse        ( g4_mac_phy_rate_pulse        ),
  .g5_mac_phy_rate_pulse        ( g5_mac_phy_rate_pulse        ),
  .phy_mac_localfs              ( phy_mac_localfs              ),
  .phy_mac_locallf              ( phy_mac_locallf              ),
  .eqpa_localfs_g3              ( eqpa_localfs_g3              ),
  .eqpa_locallf_g3              ( eqpa_locallf_g3              ),
  .eqpa_localfs_g4              ( eqpa_localfs_g4              ),
  .eqpa_locallf_g4              ( eqpa_locallf_g4              ),
  .eqpa_localfs_g5              ( eqpa_localfs_g5              ),
  .eqpa_locallf_g5              ( eqpa_locallf_g5              ),
  .phy_mac_dirfeedback          ( phy_mac_dirfeedback          ),
  .phy_mac_fomfeedback          ( phy_mac_fomfeedback          ),
  .phy_mac_phystatus            ( eqpa_bfm_phystatus           ),
  .phy_mac_rxvalid              ( phy_mac_rxvalid              ),
  // Command If.                
  .set_eq_feedback_delay        ( set_eq_feedback_delay        ),
  .eq_feedback_delay            ( eq_feedback_delay            ),
  .set_eq_dirfeedback           ( set_eq_dirfeedback           ),
  .eq_dirfeedback_value         ( eq_dirfeedback_value         ),   
  .set_eq_fomfeedback           ( set_eq_fomfeedback           ),
  .eq_fomfeedback_value         ( eq_fomfeedback_value         ),
  .set_localfs_g3               ( set_localfs_g3               ),
  .localfs_value_g3             ( localfs_value_g3             ),
  .set_localfs_g4               ( set_localfs_g4               ),
  .localfs_value_g4             ( localfs_value_g4             ),
  .set_localfs_g5               ( set_localfs_g5               ),
  .localfs_value_g5             ( localfs_value_g5             ),
  .set_locallf_g3               ( set_locallf_g3               ),
  .locallf_value_g3             ( locallf_value_g3             ),
  .set_locallf_g4               ( set_locallf_g4               ),
  .locallf_value_g4             ( locallf_value_g4             ),
  .set_locallf_g5               ( set_locallf_g5               ),
  .locallf_value_g5             ( locallf_value_g5             ),
  .set_local_tx_pset_coef_delay ( set_local_tx_pset_coef_delay ),
  .local_tx_pset_coef_delay     ( local_tx_pset_coef_delay     ),
  .set_local_tx_pset_coef       ( set_local_tx_pset_coef       ),
  .local_tx_pset_coef_value     ( local_tx_pset_coef_value     ),
  .set_rxadaption               ( set_rxadaption               )
); // u_pipe_eqpa_bfm


endmodule
