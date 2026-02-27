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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_vmain_top.v#9 $
// -------------------------------------------------------------------------
// --- Module Description: Switchable top-level of generic PHY this 
// --- level of hierarchy will be part of the switched power domain
// --- This module supports a 16 lane configuration of the PHY.
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_vmain_top #(
  parameter TP             = -1,                                     // Clock to Q delay (simulator insurance)
  parameter NB             = -1,                                     // Number of symbols (bytes) per clock cycle
  parameter NL             = -1,                                     // Number of lanes
  parameter RX_PSET_WD     = -1,                                     // Width of Receiver Equalization Presets
  parameter TX_PSET_WD     = -1,                                     // Width of Transmitter Equalization Presets
  parameter TX_COEF_WD     = -1,                                     // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
  parameter DIRFEEDBACK_WD = -1,                                     // Width of Direction Change
  parameter FOMFEEDBACK_WD = -1,                                     // Width of Figure of Merit
  parameter VPT_NUM        = -1,
  parameter VPT_DATA       = -1,                                     // Width of Full Swing or Low Frequency
  parameter TX_FS_WD       = -1,                                     // Width of LF or FS
  parameter RXSB_WD        = -1,
  parameter WIDTH_WD       = -1,
  parameter PIPE_DATA_WD   = -1,   
  parameter TXEI_WD        = -1                          
) (
// General Inputs
   input                            refclk,                          // reference clock input
   input                            phy_rst_n,                       // PIPE Reset input
   input   [NL-1:0]                 i_pclk,

// SerDes Inputs
   input   [NL-1:0]                 rxp,                             // Serial receive data (pos)
   input   [NL-1:0]                 rxn,                             // Serial receive data (neg)

// PIPE Inputs
   input   [(NL*NB*PIPE_DATA_WD)-1:0]  mac_phy_txdata,                  // Parallel transmit data
   input   [(NL*NB)-1:0]            mac_phy_txdatak,                 // K char indication per byte
   input   [NL-1:0]                 mac_phy_txdetectrx_loopback,     // Enable recevie detection sequence generation (or loopback)
   input   [NL*TXEI_WD-1:0]         mac_phy_txelecidle,              // Place transmitter into electrical idle
   input   [NL-1:0]                 mac_phy_txcompliance,            // Enable transmission of compliance sequence
   input   [NL-1:0]                 mac_phy_rxpolarity,              // Invert the receive data
   input   [WIDTH_WD-1:0]           mac_phy_width,
   input   [3:0]                    mac_phy_pclk_rate,
   input   [NL-1:0]                 mac_phy_rxstandby,
   input   [3:0]                    mac_phy_powerdown,               // Power up or down the tranceiver to 1 of 4 power states, PHY-specific states 5-7
   input                            powerdown_random_phystatus_en,   // Enable/disable random delay when generating phystatus at powerdown change
   input   [2:0]                    p1_random_range,                 // The range that it is used when generating phystatus at powerdown change to P1
   input                            p1_phystatus_time_load_en,       // Enable/disable to set a specific value as delay for phystatus at P1 entry
   input   [12:0]                   p1_phystatus_time,               // The value set if above is enabled
   input                            p2_phystatus_rise_random_en,     // enable/disable random delay generation for phystatus assertion in P2 entry
   input                            p2_random_phystatus_rise_load_en, // Enable/disable to set a specific value as delay for phystatus assertion at P2 entry
   input   [12:0]                   p2_random_phystatus_rise_value,         // The value set for P2 entry if above is enabled
   input                            p2_phystatus_fall_random_en,            // enable/disable random delay generation for phystatus deassertion in P2 entry
   input                            p2_random_phystatus_fall_load_en, // Enable/disable to set a specific value as delay for phystatus deassertion at P2 entry
   input   [12:0]                   p2_random_phystatus_fall_value,         // The value set for P2 entry if above is enabled 
      
   input                            pclkack_off_time_load_en,        // Enable/Disable random generation for pclkack_n
   input   [30:0]                   pclkack_off_time,                // Set specific value to pclkack_n
   input                            pclkack_on_time_load_en,         // Enable/Disable random generation for pclkack_n
   input   [30:0]                   pclkack_on_time,                 // Set specific value to pclkack_n
   input                            rate_random_phystatus_en,        // Enable/disable random delay when generating phystatus at rate change
   input                            rxdatavalid_shift_en,            // To set shift enable for rxdatavalid=0
   input   [3:0]                    fixed_rxdatavalid_shift_cycle,   // To fix shift range for rxdatavalid=0
   input                            random_margin_status_en,         // Enable/disable random delay when generationg margin_status
   input   [7:0]                    fixed_margin_status_thr,         // Fixed delay when generationg margin_status
   input                            random_calibrt_complete_en,      // Enable/disable random delay when generationg calibrt_complete
   input                            calibration_complete_en,         // Enable/disable calibration complete response
   input   [7:0]                    fixed_calibrt_complete_thr,      // Fixed delay when generationg calibrt_complete
   input                            syncheader_random_en,            // Enable/disable random generation of rxsyncheader when rxstartblock it is 0
   input                            disable_skp_addrm_en,            // Enable/disable skip add/remove
   input                            ebuf_location_upd_en,            // Enable/disable Elastic Buffer Location Update
   input                            rxsymclk_random_drift_en,
   input   [NL-1:0]                 mac_phy_txdatavalid,               
   input                            mac_phy_elasticbuffermode,       // 0 = empty mode ; 1 = half full mode  
   input                            P1X_to_P1_exit_mode,             // 0 = any type ; 1 = always as P2 exit     
   input                            cdr_fast_lock,                       
   input   [2:0]                    mac_phy_rate,                    // 1 = change speed to 5 Gbit/s, 2 = change speed to 8 Gbit/s   
   input   [NL*TX_COEF_WD-1:0]      mac_phy_txdeemph,                // selects transmitter de-emphasis in the PHY  
   input   [2:0]                    mac_phy_txmargin,                // selects transmitter voltage levels in the PHY            
   input                            mac_phy_txswing,                 // selects transmitter voltage swing level in the PHY      
   input   [NL-1:0]                 mac_phy_txstartblock,            // first byte of the data interface is the first byte of the block.
   input   [(NL*2)-1:0]             mac_phy_txsyncheader,            // sync header to use at start block time
    //output
   output  [NL*TX_FS_WD-1:0]        phy_mac_localfs,
   output  [NL*TX_FS_WD-1:0]        phy_mac_locallf,
   output  [NL*DIRFEEDBACK_WD-1:0]  phy_mac_dirfeedback,
   output  [NL*FOMFEEDBACK_WD-1:0]  phy_mac_fomfeedback,
   output  [NL*TX_COEF_WD-1:0]      phy_mac_local_tx_pset_coef,
   output  [NL-1:0]                 phy_mac_local_tx_coef_valid,
    //input
   input   [NL-1:0]                 mac_phy_invalid_req,
   input   [NL-1:0]                 mac_phy_rxeqeval,
   input   [NL*TX_PSET_WD-1:0]      mac_phy_local_pset_index,
   input   [NL-1:0]                 mac_phy_getlocal_pset_coef,
   input   [NL-1:0]                 mac_phy_rxeqinprogress,
   input   [NL*RX_PSET_WD-1:0]      mac_phy_rxpresethint,
   input   [NL*TX_FS_WD-1:0]        mac_phy_fs,
   input   [NL*TX_FS_WD-1:0]        mac_phy_lf,
   input                            mac_phy_blockaligncontrol,
   input                            mac_phy_encodedecodebypass,
   
   input   [NL*8-1:0]               mac_phy_messagebus,
   output  [NL*8-1:0]               phy_mac_messagebus,

   input                            mac_phy_rxelecidle_disable,
   input                            mac_phy_txcommonmode_disable,
   input   [1:0]                    mac_phy_pclkreq_n,                // Request to turn off pclk in L1sub
   output                           phy_mac_pclkack_n,                // Ack that pclk is off
   output                           phy_ref_clk_req_n,
   input                            mac_phy_asyncpowerchangeack,      // When this is 1 we bypass phystatus at rate change  when pclk is off

   input                            mac_phy_sris_mode,                // Enable SRIS mode
   input                            phy_reg_clk_g,                 
   input                            phy_reg_rst_n,                 
   output  [VPT_NUM-1:0]            phy_cr_para_ack,               
   output  [VPT_NUM*VPT_DATA-1:0]   phy_cr_para_rd_data,           
   input   [VPT_NUM-1:0]            phy_cr_para_rd_en,             
   input   [VPT_DATA-1:0]           phy_cr_para_wr_data,           
   input   [VPT_NUM-1:0]            phy_cr_para_wr_en,             
   input   [15:0]                   phy_cr_para_addr,              
   input   [VPT_NUM*2-1:0]          phy_cr_respond_time,              // 0 - quick ; 1- normal; 2- slow; 3 - timeout
   input                            phy_cr_rd_data_load_en,           // 1 - load specific value to be returned by the phy ; 0 - random
   input   [15:0]                   phy_cr_rd_data_return_value,      // value to be returned

   input                            serdes_arch,
   input   [WIDTH_WD-1:0]           rxwidth,
   input   [NL-1:0]                 serdes_pipe_turnoff_lanes,
   
   // PCLK as PHY input
   input  [NL-1:0]                  mac_phy_pclkchangeack,
   output [NL-1:0]                  phy_mac_pclkchangeok,
   
   input                            mac_phy_maxpclkreq_n,
   output                           phy_mac_maxpclkack_n,  
   output [NL-1:0]                  pcs_sdm_rx_clock_off,
   
   input                            pclk_mode_input,
   
   input [NL-1:0]                   los_rxelecidle_filtered,   
   input [NL-1:0]                   los_rxelecidle_unfiltered, 
   //input [NL-1:0]                   los_rxelecidle_noise,
   
   output    [NL*7-1:0]             phy_reg_esm_data_rate0,
   output    [NL*7-1:0]             phy_reg_esm_data_rate1,
   output    [NL-1:0]               phy_reg_esm_enable,
                        

// =====================================
// SerDes Outputs
   output  [NL-1:0]                 txp,                              // Serial transmit data (pos)
   output  [NL-1:0]                 txn,                              // Serial transmit data (neg)
   output  [NL-1:0]                 recvdclk,
// PIPE Outputs
   output                           pclk,                             // Pipe clock
   output                           pclkx2,                           // Pipe clock x2
   output                           max_pclk,                         // Pipe clk with fixed freq
   output  [(NL*NB*PIPE_DATA_WD)-1:0]  phy_mac_rxdata,                   // Parallel receive data
   output  [(NL*NB)-1:0]            phy_mac_rxdatak,                  // K char indication
   output  [NL-1:0]                 phy_mac_rxdatavalid, 
   output  [NL-1:0]                 phy_mac_rxvalid,                  // Receive data valid
   output  [(NL*3)-1:0]             phy_mac_rxstatus,                 // Receiver status (encoded)
   //output  [NL-1:0]                 phy_mac_rxelecidle,               // Receiver detected electrical idle
   output  [NL*RXSB_WD-1:0]         phy_mac_rxstartblock,             // first byte of the data interface is the first byte of the block.
   output  [(NL*RXSB_WD*2)-1:0]     phy_mac_rxsyncheader,             // sync header received from wire
   output  [NL-1:0]                 phy_mac_phystatus,                // Indicates completion of operation (context specific)
   output  [NL-1:0]                 phy_mac_rxstandbystatus
);
// ========================================================================
// Internal wires and regs
// ========================================================================

// signals extended on number of lanes 
wire  [NL-1:0]                  lane_txcommonmode_disable;
wire  [NL-1:0]                  lane_rxelecidle_disable;
wire  [NL-1:0]                  lane_phy_mac_pclkack_n;


// additional layer of signals 
// we need this because utb test are forcing the output signals of phy
// muxed signals are used to prevent the propagation of the force into lover level modules of phy
wire  [(NL*NB*PIPE_DATA_WD)-1:0]           mux_phy_mac_rxdata;
wire  [(NL*NB)-1:0]             mux_phy_mac_rxdatak;
wire  [NL-1:0]                  mux_phy_mac_rxelecidle;
wire  [NL-1:0]                  mux_phy_mac_rxdatavalid;
wire  [NL*RXSB_WD-1:0]          mux_phy_mac_rxstartblock;
wire  [(NL*RXSB_WD*2)-1:0]      mux_phy_mac_rxsyncheader;
wire  [NL*3-1:0]                mux_phy_mac_rxstatus;

assign phy_mac_rxstatus        = mux_phy_mac_rxstatus;
//assign phy_mac_rxelecidle      = mux_phy_mac_rxelecidle;
assign phy_mac_rxdata          = mux_phy_mac_rxdata;
assign phy_mac_rxdatak         = mux_phy_mac_rxdatak;
assign phy_mac_rxdatavalid     = mux_phy_mac_rxdatavalid;
assign phy_mac_rxstartblock    = mux_phy_mac_rxstartblock;
assign phy_mac_rxsyncheader    = mux_phy_mac_rxsyncheader;

//assign mux_phy_mac_rxelecidle = los_rxelecidle_noise;


// clock generator pll outputs
wire                            txbitclk;
wire                            txclk;
wire                            txclk_ug;

wire [NL-1 : 0]                 pclk_off_req;
wire [NL-1 : 0]                 rate_change_req;     // rate change request comming from all lanes
wire [NL*2-1:0]                 lane_pclkreq_n;      // request to turn off pclk brodcasted to all lanes
wire [NL-1 : 0]                 lane_disabled;

// phy_tb_ctrl for PipeMessageBus
wire    [NL-1:0]                set_p2m_messagebus;
wire    [NL*8-1:0]              p2m_messagebus_command_value;
wire    [NL-1:0]                set_m2p_messagebus;
wire    [NL*8-1:0]              m2p_messagebus_command_value;
// phy_tb_ctrl for Margining at Receiver
wire                            VoltageSupported;
wire                            IndErrorSampler;
wire    [6:0]                   MaxVoltageOffset;
wire    [5:0]                   MaxTimingOffset;

wire    [6:0]                   UnsupportedVoltageOffset;

wire                            SampleReportingMethod;
wire    [NL*2-1:0]              margin_error_cnt_mode;
wire    [NL*32-1:0]             margin_cycle_for_an_error;
wire    [NL*4-1:0]              margin_bit_error_rate_factor;
wire    [NL*2-1:0]              set_margin_cnt;
wire    [NL*7-1:0]              margin_sampl_cnt_to_set;
wire    [NL*6-1:0]              margin_error_cnt_to_set;
wire    [NL*3-1:0]              update_localfslf_mode;

// From phy_reg
wire    [NL-1:0]                phy_reg_txswing;
wire    [NL*TX_COEF_WD-1:0]     phy_reg_txdeemph;
wire    [NL-1:0]                phy_reg_invalid_req;
wire    [NL-1:0]                phy_reg_rxeqeval;
wire    [NL*6-1:0]              phy_reg_local_pset_index;
wire    [NL-1:0]                phy_reg_getlocal_pset_coef;
wire    [NL-1:0]                phy_reg_rxeqinprogress;
wire    [NL*TX_FS_WD-1:0]       phy_reg_fs;
wire    [NL*TX_FS_WD-1:0]       phy_reg_lf;

wire    [NL-1:0]                lane_esm_calibrt_complete;
wire                            phy_mac_esm_calibrt_complete;
wire    [NL-1:0]                phy_reg_esm_calibrt_req;
wire    [NL-1:0]                write_ack_for_esm_calibrt_req;
wire    [6:0]                   pipe_esm_data_rate0;
wire    [6:0]                   pipe_esm_data_rate1;
wire                            pipe_esm_calibrt_req;
wire                            pipe_esm_enable;
wire                            pipe_command_ack;

// Equalization Testbench Command interface 
wire    [NL-1:0]                 set_eq_feedback_delay;
wire    [(NL*32)-1:0]            eq_feedback_delay;
wire    [NL-1:0]                 set_eq_dirfeedback;
wire    [NL*DIRFEEDBACK_WD-1:0]  eq_dirfeedback_value;
wire    [NL-1:0]                 set_eq_fomfeedback;
wire    [NL*FOMFEEDBACK_WD-1:0]  eq_fomfeedback_value;
wire    [NL-1:0]                 set_localfs_g3;
wire    [NL*TX_FS_WD-1:0]        localfs_value_g3;
wire    [NL-1:0]                 set_localfs_g4;
wire    [NL*TX_FS_WD-1:0]        localfs_value_g4;
wire    [NL-1:0]                 set_localfs_g5;
wire    [NL*TX_FS_WD-1:0]        localfs_value_g5;
wire    [NL-1:0]                 set_locallf_g3;
wire    [NL*TX_FS_WD-1:0]        locallf_value_g3;
wire    [NL-1:0]                 set_locallf_g4;
wire    [NL*TX_FS_WD-1:0]        locallf_value_g4;
wire    [NL-1:0]                 set_locallf_g5;
wire    [NL*TX_FS_WD-1:0]        locallf_value_g5;
wire    [NL-1:0]                 set_local_tx_pset_coef_delay;
wire    [NL-1:0]                 set_rxadaption;
integer                          local_tx_pset_coef_delay;
wire    [NL-1:0]                 set_local_tx_pset_coef;
wire    [NL*TX_COEF_WD-1:0]      local_tx_pset_coef_value;



// wires from pll to pcs 
wire                              pll_pcs_pclk_off_ack;
wire                              pll_pcs_ready;
wire   [NL-1:0]                   pll_pcs_lock;

// wires from pcs to pll
wire   [NL-1:0]                   pcs_pll_pclk_off_req;             // Request to turn off pclk
wire   [NL-1:0]                   pcs_pll_rate_change_req;          // Request to change the rate

// wires from cps to sdm
wire  [(NL*PIPE_DATA_WD)-1:0]     pcs_sdm_txdata;           
wire  [NL-1:0]                    pcs_sdm_txdatak;           
wire  [NL-1:0]                    pcs_sdm_loopback;         
wire  [NL-1:0]                    pcs_sdm_txdetectrx;       
wire  [NL-1:0]                    pcs_sdm_txelecidle;       
wire  [NL-1:0]                    pcs_sdm_txcompliance; 
wire  [NL-1:0]                    pcs_sdm_rxstandby;    
wire  [NL-1:0]                    pcs_sdm_beacongen;        
wire  [3:0]                       pcs_sdm_powerdown;        
wire  [NL-1:0]                    pcs_sdm_rxpolarity;       
wire  [NL-1:0]                    pcs_sdm_txerror;          
wire  [NL-1:0]                    pcs_sdm_turn_off;         
wire  [NL*3-1:0]                  pcs_sdm_rate;             
wire  [NL*3-1:0]                  pcs_sdm_curr_rate;   
wire  [3:0]                       pcs_sdm_pclk_rate;     
wire  [NL-1:0]                    pcs_sdm_txdatavalid;      
wire  [NL-1:0]                    pcs_sdm_txstartblock;     
wire  [(NL*2)-1:0]                pcs_sdm_txsynchdr; 
wire  [NL-1:0]                    pcs_sdm_reset_n;
wire  [NL-1:0]                    pcs_sdm_set_disp;
wire  [NL-1:0]                    pcs_sdm_blockaligncontrol;  
wire  [NL-1:0]                    pcs_sdm_elasticbuffermode;  
wire  [NL-1:0]                    pcs_sdm_encodedecodebypass; 

// wires from sdm to pcs
wire  [(NL*PIPE_DATA_WD)-1:0]    sdm_pcs_dec8b10b_rxdata;       
wire  [NL-1:0]                   sdm_pcs_dec8b10b_rxdatak;      
wire  [NL-1:0]                   sdm_pcs_dec8b10b_rxvalid;  
wire  [NL-1:0]                   sdm_pcs_dec8b10b_rxdatavalid;  
wire  [NL-1:0]                   sdm_pcs_dec8b10b_rxdisperror;  
wire  [NL-1:0]                   sdm_pcs_dec8b10b_rxcodeerror;  
wire  [NL-1:0]                   sdm_pcs_dec8b10b_rxunderflow;   
wire  [NL-1:0]                   sdm_pcs_elasbuf_rxoverflow;    
wire  [NL-1:0]                   sdm_pcs_elasbuf_rxskipadded;   
wire  [NL-1:0]                   sdm_pcs_elasbuf_rxskipremoved; 
            
wire  [NL-1:0]                   sdm_pcs_rxelecidle;                   
wire  [NL-1:0]                   sdm_pcs_comma_lock;            
wire  [NL-1:0]                   sdm_pcs_dec8b10b_rxstartblock; 
wire  [(NL*2)-1:0]               sdm_pcs_dec8b10b_rxsynchdr;    
wire  [NL-1:0]                   sdm_pcs_skp_broken;    
wire  [(NL*8)-1:0]               sdm_pcs_ebuf_location;
 
// wires from pma to sdm
wire  [(NL*10)-1:0]              pma_sdm_rxdata_10b;       // 1 symbol parallel receive data
wire  [NL-1:0]                   pma_pm_beacondetected;    // beacon detected by receiver
wire  [NL-1:0]                   pma_sdm_rxelecidle_filtered;
wire  [NL-1:0]                   pma_sdm_rxelecidle_noise;
wire  [NL-1:0]                   pma_sdm_recvdclk;         // recovered receive byte clock
wire  [NL-1:0]                   pma_sdm_recvdclk_pipe;
wire  [NL-1:0]                   pma_sdm_rcvdrst_n;        // recovered reset_n
wire  [NL-1:0]                   pma_sdm_recvdclk_stopped;
wire  [NL-1:0]                   pma_pcs_rxdetected;  
wire  [NL-1:0]                   pma_serdes_rx_valid; 
   
// wires from sdm to pma 
wire  [(NL*10)-1:0]              sdm_pma_enc8b10b_txdata_10b;       
wire  [NL-1:0]                   sdm_pma_enc8b10b_txdatavalid_10b;  
wire  [NL-1:0]                   sdm_pma_enc8b10b_txstartblock_10b; 
wire  [(NL*2)-1:0]               sdm_pma_enc8b10b_txsynchdr_10b;  
wire  [NL-1:0]                   sdm_pma_enc8b10b_txelecidle_10b;

wire  [NL-1:0]                   sdm_pma_loopback;  
     
// needed for serdes arch
assign recvdclk                = pma_sdm_recvdclk_pipe; 

// mux clk when we have pclk as input mode
wire [NL-1:0] int_pclk;
assign int_pclk = pclk_mode_input ? i_pclk : {NL{pclk}}; 

                                       
//==============================================================================
// Clock generator 
//==============================================================================
DWC_pcie_gphy_pll #(
    .TP (TP),
    .NL (NL)
) u_xphy_pll (
    // Inputs
    // when pclk as input mode 
    .i_pclk                       (i_pclk                             ),
    .pclk_mode_input              (pclk_mode_input                    ),
      
    .refclk                       (refclk                             ),
    .rst_n                        (phy_rst_n                          ),
    .rate                         (mac_phy_rate                       ),
    .pclk_rate                    (mac_phy_pclk_rate                  ),
    .pclk_off_req                 (pcs_pll_pclk_off_req               ),
    .rate_change_req              (pcs_pll_rate_change_req            ),
    .pclkack_off_time_load_en     (pclkack_off_time_load_en           ),
    .pclkack_off_time             (pclkack_off_time                   ),
    .pclkack_on_time_load_en      (pclkack_on_time_load_en            ),
    .pclkack_on_time              (pclkack_on_time                    ),
    .mac_phy_pclkchangeack        (mac_phy_pclkchangeack              ),
    .phy_mac_pclkchangeok         (phy_mac_pclkchangeok               ),
    `ifdef GPHY_ESM_SUPPORT
    .calibration_complete_en      (calibration_complete_en            ),
    .random_calibrt_complete_en   (random_calibrt_complete_en         ),
    .fixed_calibrt_complete_thr   (fixed_calibrt_complete_thr         ),
    .esm_reg_data_rate0           (pipe_esm_data_rate0                ),
    .esm_reg_data_rate1           (pipe_esm_data_rate1                ),
    .esm_calibrt_req              (pipe_esm_calibrt_req               ),
    .esm_enable                   (pipe_esm_enable                    ),
    .pipe_command_ack             (pipe_command_ack                   ),
    `endif // GPHY_ESM_SUPPORT
    
    .maxpclkreq_n                 (mac_phy_maxpclkreq_n           ),
    .maxpclkack_n                 (phy_mac_maxpclkack_n           ), 
    
    // Outputs
    .txbitclk                     (txbitclk                           ),
    `ifdef GPHY_ESM_SUPPORT
    .esm_calibrt_complete_pulse   (phy_mac_esm_calibrt_complete       ),
    `endif // GPHY_ESM_SUPPORT
    .pclk_off_ack                 (pll_pcs_pclk_off_ack               ),
    .ready                        (pll_pcs_ready                      ),
    .txclk                        (txclk                              ),
    .txclk_ug                     (txclk_ug                           ),
    .pclk                         (pclk                               ),
    .pclkx2                       (pclkx2                             ),
    .max_pclk                     (max_pclk                           ),
    .lock_out                     (pll_pcs_lock                       )
);

// =============================================================================
// Module that aggregates between per phy and per pipe signals
// =============================================================================
DWC_pcie_gphy_pipe_aggr #(
   .TP (TP),
   .NL (NL)
) u_phy_pipe_aggr (
   // per-lane input --> per-pipe outputs
   // from lower layers         
   .lane_pclkack_n                    (lane_phy_mac_pclkack_n              ),
   .lane_disabled                     (lane_disabled                      ),
   `ifdef GPHY_ESM_SUPPORT
   .lane_esm_data_rate0               (phy_reg_esm_data_rate0             ),
   .lane_esm_data_rate1               (phy_reg_esm_data_rate1             ),
   .lane_esm_calibrt_req              (phy_reg_esm_calibrt_req            ),
   .lane_esm_enable                   (phy_reg_esm_enable                 ),
   .lane_command_ack                  (write_ack_for_esm_calibrt_req      ),
   
   `endif // GPHY_ESM_SUPPORT
   // to PIPE
    `ifdef GPHY_ESM_SUPPORT   
   .pipe_esm_data_rate0               (pipe_esm_data_rate0                ),
   .pipe_esm_data_rate1               (pipe_esm_data_rate1                ),
   .pipe_esm_calibrt_req              (pipe_esm_calibrt_req               ),
   .pipe_esm_enable                   (pipe_esm_enable                    ),
   .pipe_command_ack                  (pipe_command_ack                   ),
   `endif // GPHY_ESM_SUPPORT
   `ifndef GPHY_PIPE43_SUPPORT
   .pipe_pclkack_n                    (phy_mac_pclkack_n                  ),
   `else  // GPHY_PIPE43_SUPPORT
   .pipe_pclkack_n                    (                                   ),
   `endif // GPHY_PIPE43_SUPPORT
   .pipe_ref_clk_req_n                (phy_ref_clk_req_n                  ),
   // per-pipe inputs --> per-lane inputs
   // from PIPE
   `ifdef GPHY_ESM_SUPPORT
    .pipe_esm_calibrt_complete        (phy_mac_esm_calibrt_complete       ),
   `endif // GPHY_ESM_SUPPORT
   .pipe_txcommonmode_disable         (mac_phy_txcommonmode_disable       ),
   .pipe_rxelecidle_disable           (mac_phy_rxelecidle_disable         ),
   `ifndef GPHY_PIPE43_SUPPORT
   .pipe_clkreq_n                     (mac_phy_pclkreq_n                  ),
   `else // GPHY_PIPE43_SUPPORT
   .pipe_clkreq_n                     (2'b0                               ),
   `endif // GPHY_PIPE43_SUPPORT
   .powerdown                         (mac_phy_powerdown                  ),
   // to lower layers
   `ifdef GPHY_ESM_SUPPORT
   .lane_esm_calibrt_complete         (lane_esm_calibrt_complete          ),
   `endif // GPHY_ESM_SUPPORT
   .lane_txcommonmode_disable         (lane_txcommonmode_disable          ),
   .lane_rxelecidle_disable           (lane_rxelecidle_disable            ),
   .lane_clkreq_n                     (lane_pclkreq_n                     )
);



// =============================================================================
// PCS Module
// =============================================================================

DWC_pcie_gphy_pcs #(
 .TP        (TP),
 .PIPE_NB   (NB),  
 .WIDTH_WD  (WIDTH_WD),
 .RXSB_WD   (RXSB_WD),
 .NL        (NL),
 .TX_PSET_WD     (TX_PSET_WD),       // Width of Transmitter Equalization Presets                                                           
 .TX_COEF_WD     (TX_COEF_WD),       // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}                       
 .DIRFEEDBACK_WD (DIRFEEDBACK_WD),   // Width of Direction Change                                                                           
 .FOMFEEDBACK_WD (FOMFEEDBACK_WD),   // Width of Figure of Merit                                                                            
 .TX_FS_WD       (TX_FS_WD),          // Width of LF or FS  
 .PIPE_DATA_WD   (PIPE_DATA_WD), 
 .TXEI_WD        (TXEI_WD)                                                                                 
) u_pcs (
   
  .refclk                                      (refclk                            ),                                 
  .phy_rst_n                                   (phy_rst_n                         ),   
  .pclk                                        (int_pclk                          ), 
  .txclk                                       (txclk                             ), 
  .txclk_ug                                    (txclk_ug                          ), 
  .txbitclk                                    (txbitclk                          ),
  .recvdclk                                    (pma_sdm_recvdclk                  ),
  .recvdclk_pipe                               (pma_sdm_recvdclk_pipe             ),  
  .pclk_mode_input                             (pclk_mode_input                   ),   
  // PIPE Inputs 
  .mac_phy_txdata                              (mac_phy_txdata                    ), 
  .mac_phy_txdatak                             (mac_phy_txdatak                   ), 
  .mac_phy_txdetectrx_loopback                 (mac_phy_txdetectrx_loopback       ), 
  .mac_phy_txelecidle                          (mac_phy_txelecidle                ), 
  .mac_phy_txcompliance                        (mac_phy_txcompliance              ), 
  .mac_phy_rxpolarity                          (mac_phy_rxpolarity                ), 
  .mac_phy_powerdown                           (mac_phy_powerdown                 ), 
  .mac_phy_elasticbuffermode                   (mac_phy_elasticbuffermode         ), 
  .mac_phy_rate                                (mac_phy_rate                      ), 
  .mac_phy_width                               (mac_phy_width                     ), 
  .mac_phy_pclk_rate                           (mac_phy_pclk_rate                 ), 
  .mac_phy_txdatavalid                         (mac_phy_txdatavalid               ), 
  .mac_phy_rxstandby                           (mac_phy_rxstandby                 ), 
  .mac_phy_sris_mode                           (mac_phy_sris_mode                 ), 
  .mac_phy_txdeemph                            ({NL{mac_phy_txdeemph[0]}}         ), 
  .mac_phy_txmargin                            (mac_phy_txmargin                  ), 
  .mac_phy_txswing                             ({NL{mac_phy_txswing}}             ), 
  .mac_phy_txstartblock                        (mac_phy_txstartblock              ), 
  .mac_phy_txsynchdr                           (mac_phy_txsyncheader              ), 
  .mac_phy_blockaligncontrol                   (mac_phy_blockaligncontrol         ), 
  .mac_phy_encodedecodebypass                  (mac_phy_encodedecodebypass        ), 
  .mac_phy_pclkreq_n                           (lane_pclkreq_n                    ), 
  .asyncpowerchangeack                         (mac_phy_asyncpowerchangeack       ), 
  .txcommonmode_disable                        (lane_txcommonmode_disable         ), 
  .rxelecidle_disable                          (lane_rxelecidle_disable           ),       
  .mac_phy_invalid_req                         (mac_phy_invalid_req               ), 
  .mac_phy_rxeqeval                            (mac_phy_rxeqeval                  ), 
  .mac_phy_local_pset_index                    (mac_phy_local_pset_index          ), 
  .mac_phy_getlocal_pset_coef                  (mac_phy_getlocal_pset_coef        ), 
  .mac_phy_rxeqinprogress                      (mac_phy_rxeqinprogress            ), 
  .mac_phy_fs                                  (mac_phy_fs                        ), 
  .mac_phy_lf                                  (mac_phy_lf                        ), 
  // serdes arch
  .serdes_arch                                 (serdes_arch                       ),
  .rxwidth                                     (rxwidth                           ),
  .serdes_pipe_turnoff_lanes                   (serdes_pipe_turnoff_lanes         ),
  // input Command interface inputs
  // phy_tb_ctrl for equalization
  .set_eq_feedback_delay                       (set_eq_feedback_delay             ), 
  .eq_feedback_delay                           (eq_feedback_delay                 ), 
  .set_eq_dirfeedback                          (set_eq_dirfeedback                ),  
  .eq_dirfeedback_value                        (eq_dirfeedback_value              ), 
  .set_eq_fomfeedback                          (set_eq_fomfeedback                ), 
  .eq_fomfeedback_value                        (eq_fomfeedback_value              ), 
  .set_localfs_g3                              (set_localfs_g3                    ), 
  .localfs_value_g3                            (localfs_value_g3                  ), 
  .set_localfs_g4                              (set_localfs_g4                    ), 
  .localfs_value_g4                            (localfs_value_g4                  ), 
  .set_localfs_g5                              (set_localfs_g5                    ), 
  .localfs_value_g5                            (localfs_value_g5                  ), 
  .set_locallf_g3                              (set_locallf_g3                    ), 
  .locallf_value_g3                            (locallf_value_g3                  ), 
  .set_locallf_g4                              (set_locallf_g4                    ), 
  .locallf_value_g4                            (locallf_value_g4                  ), 
  .set_locallf_g5                              (set_locallf_g5                    ), 
  .locallf_value_g5                            (locallf_value_g5                  ), 
  .set_local_tx_pset_coef_delay                (set_local_tx_pset_coef_delay      ), 
  .local_tx_pset_coef_delay                    (local_tx_pset_coef_delay          ), 
  .set_local_tx_pset_coef                      (set_local_tx_pset_coef            ), 
  .local_tx_pset_coef_value                    (local_tx_pset_coef_value          ), 
  .set_rxadaption                              (set_rxadaption                    ), 
  .update_localfslf_mode                       (update_localfslf_mode             ), 
  
  
  // phy_tb_ctrl for powerdown/rate
  .powerdown_random_phystatus_en               (powerdown_random_phystatus_en     ), 
  .p1_random_range                             (p1_random_range                   ), 
  .p1_phystatus_time_load_en                   (p1_phystatus_time_load_en         ), 
  .p1_phystatus_time                           (p1_phystatus_time                 ), 
  .rate_random_phystatus_en                    (rate_random_phystatus_en          ), 
  .p2_phystatus_rise_random_en                 (p2_phystatus_rise_random_en       ), 
  .p2_random_phystatus_rise_load_en            (p2_random_phystatus_rise_load_en  ), 
  .p2_random_phystatus_rise_value              (p2_random_phystatus_rise_value    ), 
  .p2_phystatus_fall_random_en                 (p2_phystatus_fall_random_en       ), 
  .p2_random_phystatus_fall_load_en            (p2_random_phystatus_fall_load_en  ), 
  .p2_random_phystatus_fall_value              (p2_random_phystatus_fall_value    ),                 
  .P1X_to_P1_exit_mode                         (P1X_to_P1_exit_mode               ),              
  
  // PipeMessageBus Signals (), 
  .mac_phy_messagebus                          (mac_phy_messagebus                ), 
  .phy_mac_messagebus                          (phy_mac_messagebus                ), 
  // phy_tb_ctrl for PipeMessageBus
  .set_p2m_messagebus                          (set_p2m_messagebus                ), 
  .p2m_messagebus_command_value                (p2m_messagebus_command_value      ), 
  .set_m2p_messagebus                          (set_m2p_messagebus                ), 
  .m2p_messagebus_command_value                (m2p_messagebus_command_value      ), 
  
  // phy_tb_ctrl for Margining at Receiver
  .VoltageSupported                            (VoltageSupported                  ), 
  .IndErrorSampler                             (IndErrorSampler                   ), 
  .MaxVoltageOffset                            (MaxVoltageOffset                  ), 
  .MaxTimingOffset                             (MaxTimingOffset                   ),
  .UnsupportedVoltageOffset                    (UnsupportedVoltageOffset          ), 
  .SampleReportingMethod                       (SampleReportingMethod             ), 
  .margin_error_cnt_mode                       (margin_error_cnt_mode             ), 
  .margin_cycle_for_an_error                   (margin_cycle_for_an_error         ), 
  .margin_bit_error_rate_factor                (margin_bit_error_rate_factor      ), 
  .set_margin_cnt                              (set_margin_cnt                    ), 
  .margin_sampl_cnt_to_set                     (margin_sampl_cnt_to_set           ), 
  .margin_error_cnt_to_set                     (margin_error_cnt_to_set           ), 
  .random_margin_status_en                     (random_margin_status_en           ), 
  .fixed_margin_status_thr                     (fixed_margin_status_thr           ), 

  // phy_tb_ctrl for ElasticBufferLocation
  .ebuf_location_upd_en                        (ebuf_location_upd_en              ),       
   
  // inputs from pll
  .pll_pcs_pclk_off_ack                        (pll_pcs_pclk_off_ack              ), 
  .pll_pcs_lock                                (pll_pcs_lock                      ), 
  .pll_pcs_ready                               (pll_pcs_ready                     ), 

  // inputs from sdm
  .sdm_pcs_dec8b10b_rxdata                     (sdm_pcs_dec8b10b_rxdata           ), 
  .sdm_pcs_dec8b10b_rxdatak                    (sdm_pcs_dec8b10b_rxdatak          ), 
  .sdm_pcs_dec8b10b_rxdata_dv                  (sdm_pcs_dec8b10b_rxvalid          ),
  .sdm_pcs_dec8b10b_rxdatavalid                (sdm_pcs_dec8b10b_rxdatavalid      ), 
  .sdm_pcs_dec8b10b_rxdisperror                (sdm_pcs_dec8b10b_rxdisperror      ), 
  .sdm_pcs_dec8b10b_rxcodeerror                (sdm_pcs_dec8b10b_rxcodeerror      ), 
  .sdm_pcs_elasbuf_rxunderflow                 (sdm_pcs_dec8b10b_rxunderflow      ), 
  .sdm_pcs_elasbuf_rxoverflow                  (sdm_pcs_elasbuf_rxoverflow        ), 
  .sdm_pcs_elasbuf_rxskipadded                 (sdm_pcs_elasbuf_rxskipadded       ), 
  .sdm_pcs_elasbuf_rxskipremoved               (sdm_pcs_elasbuf_rxskipremoved     ), 
  .sdm_pcs_rxdetected                          (pma_pcs_rxdetected                ),                    
  .sdm_pcs_comma_lock                          (sdm_pcs_comma_lock                ),   
  .sdm_pcs_dec8b10b_rxstartblock               (sdm_pcs_dec8b10b_rxstartblock     ), 
  .sdm_pcs_dec8b10b_rxsynchdr                  (sdm_pcs_dec8b10b_rxsynchdr        ), 
  .sdm_pcs_skp_broken                          (sdm_pcs_skp_broken                ), 
  .sdm_pcs_ebuf_location                       (sdm_pcs_ebuf_location             ), 
  
// PIPE Outputs 
  .phy_mac_rxdata                              (mux_phy_mac_rxdata                ), 
  .phy_mac_rxdatak                             (mux_phy_mac_rxdatak               ), 
  .phy_mac_rxvalid                             (phy_mac_rxvalid                   ), 
  .phy_mac_rxstatus                            (mux_phy_mac_rxstatus              ),  
  .phy_mac_phystatus                           (phy_mac_phystatus                 ), 
  .phy_mac_pclkack_n                           (lane_phy_mac_pclkack_n            ), 
  .phy_mac_rxdatavalid                         (mux_phy_mac_rxdatavalid           ), 
  .phy_mac_rxstartblock                        (mux_phy_mac_rxstartblock          ), 
  .phy_mac_rxsynchdr                           (mux_phy_mac_rxsyncheader          ), 
  .phy_mac_rxstandbystatus                     (phy_mac_rxstandbystatus           ), 
  .phy_reg_txswing                             (phy_reg_txswing                   ), 
  .phy_reg_txdeemph                            (phy_reg_txdeemph                  ), 
  .phy_reg_invalid_req                         (phy_reg_invalid_req               ), 
  .phy_reg_rxeqeval                            (phy_reg_rxeqeval                  ), 
  .phy_reg_local_pset_index                    (phy_reg_local_pset_index          ), 
  .phy_reg_getlocal_pset_coef                  (phy_reg_getlocal_pset_coef        ), 
  .phy_reg_rxeqinprogress                      (phy_reg_rxeqinprogress            ), 
  .phy_reg_fs                                  (phy_reg_fs                        ), 
  .phy_reg_lf                                  (phy_reg_lf                        ), 
  .phy_mac_local_tx_pset_coef                  (phy_mac_local_tx_pset_coef        ), 
  .phy_mac_local_tx_coef_valid                 (phy_mac_local_tx_coef_valid       ), 
  .phy_mac_localfs                             (phy_mac_localfs                   ), 
  .phy_mac_locallf                             (phy_mac_locallf                   ), 
  .phy_mac_dirfeedback                         (phy_mac_dirfeedback               ), 
  .phy_mac_fomfeedback                         (phy_mac_fomfeedback               ), 
                    
  // CCIX Signals
  .phy_mac_esm_calibrt_complete                (lane_esm_calibrt_complete         ), 
  .phy_reg_esm_data_rate0                      (phy_reg_esm_data_rate0            ), 
  .phy_reg_esm_data_rate1                      (phy_reg_esm_data_rate1            ), 
  .phy_reg_esm_calibrt_req                     (phy_reg_esm_calibrt_req           ), 
  .phy_reg_esm_enable                          (phy_reg_esm_enable                ), 
  .write_ack_for_esm_calibrt_req               (write_ack_for_esm_calibrt_req     ), 
  .lane_disabled                               (lane_disabled                     ), 
  
  // outputs to pll
  .pcs_pll_pclk_off_req                        (pcs_pll_pclk_off_req              ), 
  .pcs_pll_rate_change_req                     (pcs_pll_rate_change_req           ), 
  // outputs to sdm
  
  .pcs_sdm_txdata                              (pcs_sdm_txdata                    ),
  .pcs_sdm_txdatak                             (pcs_sdm_txdatak                   ),  
  .pcs_sdm_loopback                            (pcs_sdm_loopback                  ), 
  .pcs_sdm_txdetectrx                          (pcs_sdm_txdetectrx                ), 
  .pcs_sdm_txelecidle                          (pcs_sdm_txelecidle                ), 
  .pcs_sdm_rxstandby                           (pcs_sdm_rxstandby                 ),
  .pcs_sdm_blockaligncontrol                   (pcs_sdm_blockaligncontrol         ),
  .pcs_sdm_elasticbuffermode                   (pcs_sdm_elasticbuffermode         ),
  .pcs_sdm_encodedecodebypass                  (pcs_sdm_encodedecodebypass        ),
  .pcs_sdm_txcompliance                        (pcs_sdm_txcompliance              ), 
  .pcs_sdm_beacongen                           (pcs_sdm_beacongen                 ), 
  .pcs_sdm_powerdown                           (pcs_sdm_powerdown                 ),       
  .pcs_sdm_rxpolarity                          (pcs_sdm_rxpolarity                ), 
  .pcs_sdm_txerror                             (pcs_sdm_txerror                   ), 
  .pcs_sdm_rate                                (pcs_sdm_rate                      ),
  .pcs_sdm_curr_rate                           (pcs_sdm_curr_rate                 ),    
  .pcs_sdm_txdatavalid                         (pcs_sdm_txdatavalid               ), 
  .pcs_sdm_txstartblock                        (pcs_sdm_txstartblock              ), 
  .pcs_sdm_txsynchdr                           (pcs_sdm_txsynchdr                 ),   
  .pcs_sdm_rx_clock_off                        (pcs_sdm_rx_clock_off              ), 
  .pcs_sdm_reset_n                             (pcs_sdm_reset_n                   ), 
  .pcs_sdm_set_disp                            (pcs_sdm_set_disp                  ),
  
  //pclk as PHY input
  .mac_phy_pclkchangeack                       (mac_phy_pclkchangeack             ),
  .phy_mac_pclkchangeok                        (phy_mac_pclkchangeok              )


);


// =============================================================================
// SDM Module
// =============================================================================

DWC_pcie_gphy_sdm_1s #(
  .TP        (TP),
  .PIPE_NB   (NB),
  .NL        (NL),
  .WIDTH_WD  (WIDTH_WD),
  .RXSB_WD   (RXSB_WD),
  .PIPE_DATA_WD   (PIPE_DATA_WD), 
  .TXEI_WD        (TXEI_WD)

) u_sdm (
// =====================================
// General Inputs
  .txclk                             (txclk                              ),      
  .txclk_ug                          (txclk_ug                           ),
  .phy_rst_n                         (phy_rst_n                          ),
        
  .serdes_arch                       (serdes_arch                        ),
// PCS to SDM Inputs
  .pcs_sdm_txdata                    (pcs_sdm_txdata                     ),      
  .pcs_sdm_txdatak                   (pcs_sdm_txdatak                    ),      
  .pcs_sdm_txdatavalid               (pcs_sdm_txdatavalid                ),      
  .pcs_sdm_rxstandby                 (pcs_sdm_rxstandby                  ),           
  .pcs_sdm_txstartblock              (pcs_sdm_txstartblock               ),      
  .pcs_sdm_txsynchdr                 (pcs_sdm_txsynchdr                  ),      
  .pcs_sdm_txdetectrx_loopback       (pcs_sdm_loopback                   ),           
  .pcs_sdm_txelecidle                (pcs_sdm_txelecidle                 ),      
  .pcs_sdm_txcompliance              (pcs_sdm_txcompliance               ),      
  .pcs_sdm_rxpolarity                (pcs_sdm_rxpolarity                 ),      
  .pcs_sdm_powerdown                 (pcs_sdm_powerdown                  ),      
  .pcs_sdm_elasticbuffermode         (pcs_sdm_elasticbuffermode          ),           
  .pcs_sdm_rate                      (pcs_sdm_rate                       ),      
  .pcs_sdm_curr_rate                 (pcs_sdm_curr_rate                  ),      
  .pcs_sdm_width                     (mac_phy_width                      ),                    
  .pcs_sdm_reset_n                   (pcs_sdm_reset_n                    ),           
  .pcs_sdm_set_disp                  (pcs_sdm_set_disp                   ),           
  .pcs_sdm_txerror                   (pcs_sdm_txerror                    ),           
  .pcs_sdm_blockaligncontrol         (pcs_sdm_blockaligncontrol          ),         
  .pcs_sdm_sris_mode                 (mac_phy_sris_mode                  ),           
       
  // control inputs
  .syncheader_random_en              (syncheader_random_en               ),                                                                                         
  .disable_skp_addrm_en              (disable_skp_addrm_en               ),                                                                                         
  
    
`ifdef GPHY_ESM_SUPPORT
  .phy_reg_esm_enable                (phy_reg_esm_enable                 ),                                                                                                                            
  .phy_reg_esm_data_rate0            (phy_reg_esm_data_rate0             ),                                                                                                                        
  .phy_reg_esm_data_rate1            (phy_reg_esm_data_rate1             ),                                                                                                                        
`endif // GPHY_ESM_SUPPORT


  // pma to sdm  Inputs
  .pma_sdm_rxdata_10b                (pma_sdm_rxdata_10b                 ),              // Parallel receive data from SerDes
  .pma_sdm_rxdetected                (pma_pcs_rxdetected                 ),              // Receive signal detected by SerDes
  .pma_sdm_rxelecidle                (los_rxelecidle_filtered            ),              // Receive Idle detected
  .pma_sdm_recvdclk                  (pma_sdm_recvdclk                   ),              // Recovered symbol clock
  .pma_sdm_rcvdrst_n                 (pma_sdm_rcvdrst_n                  ),              // Recovered reset_n
  .pma_sdm_recvdclk_stopped          (pma_sdm_recvdclk_stopped           ),
  .pma_serdes_rx_valid               (pma_serdes_rx_valid                ),
  
  .pll_sdm_ready                     (pll_pcs_ready                      ),

  // SDM to PCS Outputs
  .sdm_pcs_dec8b10b_rxdata           (sdm_pcs_dec8b10b_rxdata            ),               // Parallel receive data (1 or 2 bytes)
  .sdm_pcs_dec8b10b_rxdatak          (sdm_pcs_dec8b10b_rxdatak           ),               // K char indication
  .sdm_pcs_dec8b10b_rxvalid          (sdm_pcs_dec8b10b_rxvalid           ),               // Receive data valid  
  .sdm_pcs_dec8b10b_rxdatavalid      (sdm_pcs_dec8b10b_rxdatavalid       ),            
  .sdm_pcs_dec8b10b_rxstartblock     (sdm_pcs_dec8b10b_rxstartblock      ),               // first byte of the data interface is the first byte of the block.
  .sdm_pcs_dec8b10b_rxsynchdr        (sdm_pcs_dec8b10b_rxsynchdr         ),               // sync header that was strippend out of the 130 bit block  
  .sdm_pcs_dec8b10b_rxdisperror      (sdm_pcs_dec8b10b_rxdisperror       ),
  .sdm_pcs_dec8b10b_rxcodeerror      (sdm_pcs_dec8b10b_rxcodeerror       ),
  .sdm_pcs_dec8b10b_rxunderflow      (sdm_pcs_dec8b10b_rxunderflow       ),  
  .sdm_pcs_elasbuf_rxoverflow        (sdm_pcs_elasbuf_rxoverflow         ),
  .sdm_pcs_elasbuf_rxskipadded       (sdm_pcs_elasbuf_rxskipadded        ),
  .sdm_pcs_elasbuf_rxskipremoved     (sdm_pcs_elasbuf_rxskipremoved      ),
  
  .sdm_pcs_skp_broken                (sdm_pcs_skp_broken                 ),
  .sdm_pcs_ebuf_location             (sdm_pcs_ebuf_location              ),               // Elastic Buffer Location
  
  // SDM to PMA Outputs
  .sdm_pma_enc8b10b_txdata_10b       (sdm_pma_enc8b10b_txdata_10b        ),               // Transmit symbol data
  .sdm_pma_enc8b10b_txdatavalid_10b  (sdm_pma_enc8b10b_txdatavalid_10b   ),               // ignore a byte or word on the data interface
  .sdm_pma_enc8b10b_txstartblock_10b (sdm_pma_enc8b10b_txstartblock_10b  ),               // first byte of the data interface is the first byte of the block.
  .sdm_pma_enc8b10b_txsynchdr_10b    (sdm_pma_enc8b10b_txsynchdr_10b     ),               // sync header to use in the next 130b block
  .sdm_pma_enc8b10b_txelecidle_10b   (sdm_pma_enc8b10b_txelecidle_10b    ),
  
  .sdm_pma_loopback                  (                   )  // TODO :this needs to go to pma serializer where we look at loopback to clear queues 
                                                                                           // decision is now take into elastic buffer and needs to propagate down       
);


// =============================================================================
// PMA Module
// =============================================================================

DWC_pcie_gphy_pma #(
    .TP        (TP),
    .PIPE_NB   (NB),
    .WIDTH_WD  (WIDTH_WD),
    .NL        (NL)
) u_pma (
// inputs
// general inputs
  .refclk                       (refclk                              ),       // Reference Clock
  .txbitclk                     (txbitclk                            ),       // Transmit bit clock
  .txclk                        (txclk                               ),       // Transmit symbol clock
  
  .serdes_arch                  (serdes_arch                         ),
  .sdm_pma_reset_n              (pcs_sdm_reset_n                     ),       // Reset
  .sdm_pma_powerdown            (pcs_sdm_powerdown                   ),       // power state  
  .mac_phy_sris_mode            (mac_phy_sris_mode                   ),    
  .sdm_pma_rate                 (pcs_sdm_rate                        ),
  .sdm_pma_curr_rate            (pcs_sdm_curr_rate                   ),       // Current operating rate
  .mac_phy_rxstandby            (mac_phy_rxstandby                   ), 
  .rxwidth                      (rxwidth                             ),
  .cdr_fast_lock                (cdr_fast_lock                       ),       // control of CDR from task
  
  // pcs to sdm inputs
  .sdm_pma_rx_clock_off         (pcs_sdm_rx_clock_off                ),       // clock is turned off in P1
  .sdm_pma_loopback             (pcs_sdm_loopback                    ),       // PCI-E loopback
  .sdm_pma_txdetectrx           (pcs_sdm_txdetectrx                  ),       // Send receiver detection sequence; placeholder 
  .sdm_pma_beacongen            (pcs_sdm_beacongen                   ),       // Instruct the SerDes to generate a beacon signal 
  .sdm_pma_rxpolarity           (pcs_sdm_rxpolarity                  ),       // Invert receive data
  
  //serial lines
  .rxp                          (rxp                                 ),       // Serial receive data (pos)
  .rxn                          (rxn                                 ),       // Serial receive data (neg)
  
  .rxelecidle_disable           (lane_rxelecidle_disable             ),       // L1sub power saving measure
  .txcommonmode_disable         (lane_txcommonmode_disable           ),       // L1sub power saving measure
  //control input
  .rxsymclk_random_drift_en     (rxsymclk_random_drift_en            ),
  
  // tx inputs from sdm to pma
  .sdm_pma_txdata_10b           (sdm_pma_enc8b10b_txdata_10b         ),       // 1 symbol parallel transmit data
  .sdm_pma_txdatavalid_10b      (sdm_pma_enc8b10b_txdatavalid_10b    ),       // ignore a byte or word on the data interface
  .sdm_pma_txstartblock_10b     (sdm_pma_enc8b10b_txstartblock_10b   ),       // first byte of the data interface is the first byte of the block.
  .sdm_pma_txsynchdr_10b        (sdm_pma_enc8b10b_txsynchdr_10b      ),       // sync header to use in the next 130b block
  .sdm_pma_txelecidle           (sdm_pma_enc8b10b_txelecidle_10b     ),       // Enable Transmitter Electical Idle

`ifdef GPHY_ESM_SUPPORT
  .phy_reg_esm_enable           (phy_reg_esm_enable                  ),
  .phy_reg_esm_data_rate0       (phy_reg_esm_data_rate0              ),
  .phy_reg_esm_data_rate1       (phy_reg_esm_data_rate1              ),
`endif // GPHY_ESM_SUPPORT 
   
  .los_rxelecidle_filtered      (los_rxelecidle_filtered             ),
  .los_rxelecidle_unfiltered     (los_rxelecidle_unfiltered           ),
  
  // transmit outputs
  .txp                          (txp                                 ),       // Serial transmit data (pos)
  .txn                          (txn                                 ),       // Serial transmit data (neg)

  // outputs from pma to sdm
  .pma_sdm_rxdata_10b           (pma_sdm_rxdata_10b                  ),       // 1 symbol parallel receive data
  .pma_pm_beacondetected        (pma_pm_beacondetected               ),       // beacon detected by receiver
  .pma_sdm_rxdetected           (pma_pcs_rxdetected                  ),       // receiver detected signaling,  
  .pma_sdm_recvdclk             (pma_sdm_recvdclk                    ),       // recovered receive byte clock
  .pma_sdm_recvdclk_pipe        (pma_sdm_recvdclk_pipe               ),
  .pma_sdm_rcvdrst_n            (pma_sdm_rcvdrst_n                   ),       // recovered reset_n
  .pma_serdes_rx_valid          (pma_serdes_rx_valid                 ), 
  .pma_sdm_recvdclk_stopped     (pma_sdm_recvdclk_stopped            )


);


//==============================================================================
// PHY CR VIEWPORT I/F
//==============================================================================
DWC_pcie_gphy_viewport_bfm #(
  .TP        (TP),
  .VPT_NUM   (VPT_NUM),
  .VPT_DATA  (VPT_DATA)
) u_phy_viewport_bfm (
  .clk                                (phy_reg_clk_g                 ),
  .rst_n                              (phy_reg_rst_n                 ),
  .phy_cr_para_addr                   (phy_cr_para_addr              ),
  .phy_cr_para_rd_en                  (phy_cr_para_rd_en             ),
  .phy_cr_para_wr_en                  (phy_cr_para_wr_en             ),
  .phy_cr_para_wr_data                (phy_cr_para_wr_data           ),
  .phy_cr_respond_time                (phy_cr_respond_time           ),
  .phy_cr_rd_data_load_en             (phy_cr_rd_data_load_en        ),
  .phy_cr_rd_data_return_value        (phy_cr_rd_data_return_value   ),
  .phy_cr_para_ack                    (phy_cr_para_ack               ),
  .phy_cr_para_rd_data                (phy_cr_para_rd_data           )
);


endmodule: DWC_pcie_gphy_vmain_top

