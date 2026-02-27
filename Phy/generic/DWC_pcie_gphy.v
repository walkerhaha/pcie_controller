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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy.v#10 $
// -------------------------------------------------------------------------
// --- Module Description: Generic phy model. This will be replaced with a
// --- vendor-specific PHY implementation once the SerDes is selected.
// ----------------------------------------------------------------------------

module DWC_pcie_gphy #(
  //reuse-pragma attr Visible false
  parameter TP             = `GPHY_TP,            // Clock to Q delay (simulator insurance)
  //reuse-pragma attr Visible false
  parameter NB             = `GPHY_NB,            // Number of symbols (bytes) per clock cycle
  //reuse-pragma attr Visible false
  parameter NL             = `GPHY_NL,            // Number of lanes
  //reuse-pragma attr Visible false
  parameter VPT_NUM        = `GPHY_NUM_MACROS,    // Number of phy xNsub_blocks
  //reuse-pragma attr Visible false
  parameter VPT_DATA       = `GPHY_VIEWPORT_DATA, // Data width of PHY register interface

  //reuse-pragma attr Visible false
  parameter RX_PSET_WD     = 3,                   // Width of Receiver Equalization Presets
  //reuse-pragma attr Visible false
  //reuse-pragma attr ReplaceInHDL 0
  parameter TX_PSET_WD     = `GPHY_PSET_WD,       // Width of Transmitter Equalization Presets
  //reuse-pragma attr Visible false
  parameter TX_COEF_WD     = 18,                  // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
  //reuse-pragma attr Visible false
  parameter DIRFEEDBACK_WD = 6,                   // Width of Direction Change
  //reuse-pragma attr Visible false
  parameter FOMFEEDBACK_WD = 8,                   // Width of Figure of Merit
  //reuse-pragma attr Visible false
  //reuse-pragma attr ReplaceInHDL 0
  parameter TX_FS_WD       = 6,                   // Width of Full Swing or Low Frequency
  //reuse-pragma attr Visible false
  //reuse-pragma attr ReplaceInHDL 0
  parameter RXSB_WD        = `GPHY_RXSB_WD,
  //reuse-pragma attr Visible false
  //reuse-pragma attr ReplaceInHDL 0
  parameter WIDTH_WD       = `GPHY_WIDTH_WD,
  //reuse-pragma attr Visible false
  //reuse-pragma attr ReplaceInHDL 0
  parameter PIPE_DATA_WD   = `GPHY_PIPE_DATA_WD,
  //reuse-pragma attr Visible false
  //reuse-pragma attr ReplaceInHDL 0
  parameter TXEI_WD        = `GPHY_TXEI_WD
) (
// clock and reset
  input                           refclk_p,
  input                           refclk_n,
  input                           phy_rst_n,
  input                           power_up_rst_n,
  input                           perst_n,
  output                          pclk,
  output                          pclkx2,
  output                          max_pclk,

// SerDes tx/rx
  input   [NL-1:0]                rxp,
  input   [NL-1:0]                rxn,
  output  [NL-1:0]                txp,
  output  [NL-1:0]                txn,

// PIPE Data
  input   [NL*NB*PIPE_DATA_WD-1:0]      mac_phy_txdata,
  input   [(NL*NB)-1:0]           mac_phy_txdatak,
  input   [NL-1:0]                mac_phy_txdatavalid,
  input   [NL-1:0]                mac_phy_txstartblock,
  input   [(NL*2)-1:0]            mac_phy_txsyncheader,

  output  [NL*NB*PIPE_DATA_WD-1:0]      phy_mac_rxdata,
  output  [(NL*NB)-1:0]           phy_mac_rxdatak,
  output  [NL-1:0]                phy_mac_rxvalid,
  output  [NL-1:0]                phy_mac_rxdatavalid,
  output  [NL*RXSB_WD-1:0]        phy_mac_rxstartblock,
  output  [(NL*RXSB_WD*2)-1:0]    phy_mac_rxsyncheader,

// PIPE control
  input   [2:0]                   mac_phy_rate,
  input   [WIDTH_WD-1:0]          mac_phy_width,
  input   [3:0]                   mac_phy_pclk_rate,

  input   [NL-1:0]                mac_phy_txdetectrx_loopback,
  input   [NL-1:0]                mac_phy_rxpolarity,
  input                           mac_phy_blockaligncontrol,
  input   [NL*TXEI_WD-1:0]        mac_phy_txelecidle,
  input   [NL-1:0]                mac_phy_txcompliance,
  input   [NL*TX_COEF_WD-1:0]     mac_phy_txdeemph,
  input   [2:0]                   mac_phy_txmargin,
  input                           mac_phy_txswing,
  input                           mac_phy_sris_mode,
  input                           mac_phy_encodedecodebypass,
  input                           mac_phy_elasticbuffermode,

  input   [NL-1:0]                mac_phy_rxstandby,
  output  [NL-1:0]                phy_mac_rxstandbystatus,
  output  [(NL*3)-1:0]            phy_mac_rxstatus,
  output  [NL-1:0]                phy_mac_rxelecidle,


// EQ interface
  input   [NL-1:0]                mac_phy_invalid_req,
  input   [NL-1:0]                mac_phy_rxeqeval,
  input   [NL*TX_PSET_WD-1:0]     mac_phy_local_pset_index,
  input   [NL-1:0]                mac_phy_getlocal_pset_coef,
  input   [NL-1:0]                mac_phy_rxeqinprogress,
  input   [NL*RX_PSET_WD-1:0]     mac_phy_rxpresethint,
  input   [NL*TX_FS_WD-1:0]       mac_phy_fs,
  input   [NL*TX_FS_WD-1:0]       mac_phy_lf,
  output  [NL*TX_FS_WD-1:0]       phy_mac_localfs,
  output  [NL*TX_FS_WD-1:0]       phy_mac_locallf,
  output  [NL*DIRFEEDBACK_WD-1:0] phy_mac_dirfeedback,
  output  [NL*FOMFEEDBACK_WD-1:0] phy_mac_fomfeedback,
  output  [NL*TX_COEF_WD-1:0]     phy_mac_local_tx_pset_coef,
  output  [NL-1:0]                phy_mac_local_tx_coef_valid,

// powerdown interface
  input   [3:0]                   mac_phy_powerdown,
  input                           mac_phy_rxelecidle_disable,
  input                           mac_phy_txcommonmode_disable,
  input   [1:0]                   mac_phy_pclkreq_n,
  output                          phy_mac_pclkack_n,
  output                          phy_ref_clk_req_n,

`ifdef GPHY_PIPE43_SUPPORT
   `ifndef GPHY_PIPE43_ASYNC_HS_BYPASS
  input                           mac_phy_asyncpowerchangeack,
   `endif // GPHY_PIPE43_ASYNC_HS_BYPASS
`endif // GPHY_PIPE43_SUPPORT

`ifdef GPHY_PIPE51_SUPPORT
 input                            mac_phy_serdes_arch,
 input  [WIDTH_WD-1:0]            mac_phy_rxwidth,
 output [NL-1:0]                  rx_clk,
`endif //GPHY_PIPE51_SUPPORT

// SNPS PHY Viewport interface
  input                            phy_reg_clk_g,
  input                            phy_reg_rst_n,
  output  [VPT_NUM-1:0]            phy_cr_para_ack,
  output  [VPT_NUM*VPT_DATA-1:0]   phy_cr_para_rd_data,
  input   [VPT_NUM-1:0]            phy_cr_para_rd_en,
  input   [VPT_DATA-1:0]           phy_cr_para_wr_data,
  input   [VPT_NUM-1:0]            phy_cr_para_wr_en,
  input   [15:0]                   phy_cr_para_addr,

// message bus interface
  input   [NL*8-1:0]               mac_phy_messagebus,
  output  [NL*8-1:0]               phy_mac_messagebus,

// PCLK as PHY INPUT
   input  [NL-1:0]                 mac_phy_pclkchangeack,
   output [NL-1:0]                 phy_mac_pclkchangeok,
   input                           mac_phy_maxpclkreq_n,
   output                          phy_mac_maxpclkack_n,
   input  [NL-1:0]                 i_pclk,
   input  [NL-1:0]                 serdes_pipe_turnoff_lanes,

// main PIPE ack signal
  output  [NL-1:0]                 phy_mac_phystatus
);

wire [NL-1:0] pcs_sdm_rx_clock_off;
wire    [NL*7-1:0]              phy_reg_esm_data_rate0;
wire    [NL*7-1:0]              phy_reg_esm_data_rate1;
wire    [NL-1:0]                phy_reg_esm_enable;

wire [NL-1:0] los_rxelecidle_filtered;   
wire [NL-1:0] los_rxelecidle_unfiltered; 
wire [NL-1:0] los_rxelecidle_noise;


assign phy_mac_rxelecidle     = los_rxelecidle_noise;


wire                serdes_arch;
wire [WIDTH_WD-1:0] rxwidth;
wire [NL-1:0]       recvdclk;

`ifdef GPHY_PIPE51_SUPPORT
   assign serdes_arch = mac_phy_serdes_arch;
   assign rxwidth = mac_phy_rxwidth;
   assign rx_clk = recvdclk;
`else
   assign serdes_arch = 1'b0;
   assign rxwidth = mac_phy_width;
`endif //GPHY_PIPE51_SUPPORT

wire pclk_mode_input;
`ifdef GPHY_PIPE_PCLK_AS_PHY_INPUT
  assign pclk_mode_input = 1'b1;
`else // !GPHY_PIPE_PCLK_AS_PHY_INPUT
  assign pclk_mode_input = 1'b0;
`endif // GPHY_PIPE_PCLK_AS_PHY_INPUT


wire   mux_mac_phy_asyncpowerchangeack;

`ifdef GPHY_PIPE43_SUPPORT
  `ifndef GPHY_PIPE43_ASYNC_HS_BYPASS
    assign mux_mac_phy_asyncpowerchangeack = mac_phy_asyncpowerchangeack;
  `else
    assign mux_mac_phy_asyncpowerchangeack = 1'b1;
  `endif
`else //  GPHY_PIPE43_SUPPORT
  assign mux_mac_phy_asyncpowerchangeack = 1'b1;
`endif //GPHY_PIPE43_SUPPORT

wire phy_pmu_en_iso_n;

// =============================================================================
// Generic PHY TB control access
// This logic is placed here as this module is in the AlwaysON domain and as
// such is not affected when power gating is performed
//
// All these signals are controller from the phy_tb_ctl interface and
// propagate down into the relevant logic (phystatus FSM, elastic buffer, PLL,
// etc)
// =============================================================================


// Control the random generation of phystatus after a rate changes
// 1 - enable random phystatus generation
// 0 - disable random phystatus generation
wire rate_random_phystatus_en;

// Control the random generation of phystatus at powerdown changes
// 1 - enable
// 0 - disable
wire   powerdown_random_phystatus_en;

`ifndef CORETOOLS
// This signal is used to set a range for the generation of the
// p1_powerdown_phystatus delay. All lanes share the same range,
// each lane will generate a different time within the range
// Five ranges are currently supported, from 0 to 4. Ranges are
// defined in the pipe2phy module
reg  [2:0]  p1_random_range;
initial begin
  process p;
  string inst;
  int seed;

  // generate a seed which is unique to this instance
  p = process::self();
  $sformat(inst, "%m");
  seed = 0;
  for (int i=0 ; i< inst.len(); i++) seed += inst.getc(i);
  p.srandom(seed);

  void'(std::randomize(p1_random_range) with {p1_random_range > 0; p1_random_range < 4;});
end
`endif // CORETOOLS


// This signals are used to set a fixed value for phystatus delay when changing to P1
wire        p1_phystatus_time_load_en;
wire [12:0] p1_phystatus_time;

// This signals are used to set a fixed value as delay for pclkack genereation when pclk is going off
wire        pclkack_off_time_load_en;        // this signal will turn of the randomzation of pclkack delay
wire [30:0] pclkack_off_time;                // set specific value

// This signals are used to set a fixed value as delay for pclkack genereation when pclk is going on
wire        pclkack_on_time_load_en;        // this signal will turn of the randomzation of pclkack delay
wire [30:0] pclkack_on_time;                // set specific value




// This signal it is used to control the random generation of syncheader when
// StarBlock it is 0
// 1 - enable (default)
// 0 - disable
wire  syncheader_random_en;

// When true disable manipulation of SKP ordered sets in the elastic buffer
// 1 - enable SKP ADD/RM
// 0 - disable SKP ADD/RM
wire disable_skp_addrm_en;

// =============================================================================
// This signal it is used to control the random drift or rxsymclk enable
// StarBlock it is 0
// 1 - enable (default)
// 0 - disable
wire rxsymclk_random_drift_en;


// This signal it is used to shift the RxDataValid=0 Timing during Elastic Buffer Mode=1
// 1 - enable (default)
// 0 - disable
wire         rxdatavalid_shift_en;
// This signal it is used to control the fixed RxDataValid=0 Timing during Elastic Buffer Mode=0
// 0    - random
// else - fixed
wire   [3:0] fixed_rxdatavalid_shift_cycle;

// Control the random generation of margin_status
// 1 - enable
// 0 - disable
// Threshold when random_margin_status_en is 0b;
wire         random_margin_status_en;
wire   [7:0] fixed_margin_status_thr;

// Control the random generation of calibrt_complete
// 1 - enable
// 0 - disable
// Threshold when random_calibrt_complete_en is 0b;
wire         random_calibrt_complete_en;
wire   [7:0] fixed_calibrt_complete_thr;

// Control of ESM calibration complete
// 1 - enable calibration complete respons
// 0 - disable calibration complete response
wire  calibration_complete_en;

// Control of Elastic Buffer Location Update
// 1 - enable
// 0 - disable
wire  ebuf_location_upd_en=1'b0;


// control phystatus assertion delay at p2 entry
// 1 - enable
// 0 - disable
wire         p2_phystatus_rise_random_en;
wire         p2_random_phystatus_rise_load_en;
wire [12:0]  p2_random_phystatus_rise_value;

// control phystatus deassertion delay at p2 entry
// 1 - enable
// 0 - disable
wire         p2_phystatus_fall_random_en;
wire         p2_random_phystatus_fall_load_en;
wire [12:0]  p2_random_phystatus_fall_value;

// =============================================================================
// This signals are used to control the phy viewport interface
wire [VPT_NUM*2-1:0] phy_cr_respond_time;            // 0 - quick ; 1- normal; 2- slow; 3 - timeout
wire                 phy_cr_rd_data_load_en;         // 1 - load specific value to be returned ; 0 - random
wire [15:0]          phy_cr_rd_data_return_value;    // value to be returned

// =============================================================================
// This signal is used to control the phy P1X_to_P1 exit mode interface
// 0 = normal mode
// 1 = as P2 exit mode
wire P1X_to_P1_exit_mode;

// =============================================================================
// This signal is used for controling the CDR for fast lock
// 0 = no fast lock
// 1 = fast lock
wire cdr_fast_lock;


// Instantiate the PHY top-level
DWC_pcie_gphy_vmain_top #(
    .NB             (NB),
    .VPT_NUM        (VPT_NUM),
    .VPT_DATA       (VPT_DATA),
    .NL             (NL),
    .RXSB_WD        (RXSB_WD),
    .WIDTH_WD       (WIDTH_WD),
    .RX_PSET_WD     (RX_PSET_WD),
    .TX_PSET_WD     (TX_PSET_WD),
    .TX_COEF_WD     (TX_COEF_WD),
    .DIRFEEDBACK_WD (DIRFEEDBACK_WD),
    .FOMFEEDBACK_WD (FOMFEEDBACK_WD),
    .TX_FS_WD       (TX_FS_WD),
    .TP             (TP),
    .PIPE_DATA_WD   (PIPE_DATA_WD),
    .TXEI_WD        (TXEI_WD)
) u_phy_vmain_top(
// General Inputs
    .refclk     (refclk_p),
    .phy_rst_n  (phy_rst_n),
    .i_pclk     (i_pclk),

// SerDes Inputs
    .rxp        (rxp),
    .rxn        (rxn),

// PIPE Inputs
    .mac_phy_txdata                 (mac_phy_txdata),
    .mac_phy_txdatak                (mac_phy_txdatak),
    .mac_phy_txdetectrx_loopback    (mac_phy_txdetectrx_loopback),
    .mac_phy_txelecidle             (mac_phy_txelecidle),
    .mac_phy_txcompliance           (mac_phy_txcompliance),
    .mac_phy_rxpolarity             (mac_phy_rxpolarity),
    .mac_phy_width                  (mac_phy_width),
    .mac_phy_pclk_rate              (mac_phy_pclk_rate),
    .mac_phy_rxstandby              (mac_phy_rxstandby),
    .mac_phy_powerdown              (mac_phy_powerdown),
    .mac_phy_elasticbuffermode      (mac_phy_elasticbuffermode),
    .powerdown_random_phystatus_en  (powerdown_random_phystatus_en),
    .p1_random_range                (p1_random_range),
    .rate_random_phystatus_en       (rate_random_phystatus_en),
    .rxdatavalid_shift_en           (rxdatavalid_shift_en),
    .fixed_rxdatavalid_shift_cycle  (fixed_rxdatavalid_shift_cycle),
    .random_margin_status_en        (random_margin_status_en),
    .fixed_margin_status_thr        (fixed_margin_status_thr),
    .random_calibrt_complete_en     (random_calibrt_complete_en),
    .calibration_complete_en        (calibration_complete_en),
    .fixed_calibrt_complete_thr     (fixed_calibrt_complete_thr),
    .syncheader_random_en           (syncheader_random_en),
    .disable_skp_addrm_en           (disable_skp_addrm_en),
    .ebuf_location_upd_en           (ebuf_location_upd_en),
    .p1_phystatus_time_load_en      (p1_phystatus_time_load_en),
    .p1_phystatus_time              (p1_phystatus_time),
    .p2_phystatus_rise_random_en       (p2_phystatus_rise_random_en),
    .p2_random_phystatus_rise_load_en  (p2_random_phystatus_rise_load_en),
    .p2_random_phystatus_rise_value    (p2_random_phystatus_rise_value),
    .p2_phystatus_fall_random_en       (p2_phystatus_fall_random_en),
    .p2_random_phystatus_fall_load_en  (p2_random_phystatus_fall_load_en),
    .p2_random_phystatus_fall_value    (p2_random_phystatus_fall_value),
    .pclkack_off_time_load_en       (pclkack_off_time_load_en),
    .pclkack_off_time               (pclkack_off_time),
    .pclkack_on_time_load_en        (pclkack_on_time_load_en),
    .pclkack_on_time                (pclkack_on_time),
    .rxsymclk_random_drift_en       (rxsymclk_random_drift_en),
    .phy_mac_rxdatavalid            (phy_mac_rxdatavalid),
    .mac_phy_txdatavalid            (mac_phy_txdatavalid),
    .P1X_to_P1_exit_mode            (P1X_to_P1_exit_mode),
    .cdr_fast_lock                  (cdr_fast_lock),

    .mac_phy_rate                   (mac_phy_rate),
    .mac_phy_txdeemph               (mac_phy_txdeemph),
    .mac_phy_txmargin               (mac_phy_txmargin),
    .mac_phy_txswing                (mac_phy_txswing),

    .mac_phy_txstartblock           (mac_phy_txstartblock),
    .mac_phy_txsyncheader           (mac_phy_txsyncheader),

    //output
    .phy_mac_localfs                (phy_mac_localfs),
    .phy_mac_locallf                (phy_mac_locallf),
    .phy_mac_dirfeedback            (phy_mac_dirfeedback),
    .phy_mac_fomfeedback            (phy_mac_fomfeedback),
    .phy_mac_local_tx_pset_coef     (phy_mac_local_tx_pset_coef),
    .phy_mac_local_tx_coef_valid    (phy_mac_local_tx_coef_valid),
    //input
    .mac_phy_invalid_req            (mac_phy_invalid_req),
    .mac_phy_rxeqeval               (mac_phy_rxeqeval),
    .mac_phy_local_pset_index       (mac_phy_local_pset_index),
    .mac_phy_getlocal_pset_coef     (mac_phy_getlocal_pset_coef),
    .mac_phy_rxeqinprogress         (mac_phy_rxeqinprogress),
    .mac_phy_rxpresethint           (mac_phy_rxpresethint),
    .mac_phy_fs                     (mac_phy_fs),
    .mac_phy_lf                     (mac_phy_lf),
    .mac_phy_blockaligncontrol      (mac_phy_blockaligncontrol),
    .mac_phy_encodedecodebypass     (mac_phy_encodedecodebypass),
    .mac_phy_messagebus             (mac_phy_messagebus),
    .phy_mac_messagebus             (phy_mac_messagebus),

    .mac_phy_rxelecidle_disable     (mac_phy_rxelecidle_disable),
    .mac_phy_txcommonmode_disable   (mac_phy_txcommonmode_disable),
    .mac_phy_pclkreq_n              (mac_phy_pclkreq_n),
    .phy_mac_pclkack_n              (phy_mac_pclkack_n),
    .pcs_sdm_rx_clock_off           (pcs_sdm_rx_clock_off),
    .phy_ref_clk_req_n              (phy_ref_clk_req_n),
    .mac_phy_asyncpowerchangeack    (mux_mac_phy_asyncpowerchangeack),

    .mac_phy_sris_mode              (mac_phy_sris_mode),
    .phy_reg_clk_g                  (phy_reg_clk_g),
    .phy_reg_rst_n                  (phy_reg_rst_n),
    .phy_cr_para_ack                (phy_cr_para_ack),
    .phy_cr_para_rd_data            (phy_cr_para_rd_data),
    .phy_cr_para_rd_en              (phy_cr_para_rd_en),
    .phy_cr_para_wr_data            (phy_cr_para_wr_data),
    .phy_cr_para_wr_en              (phy_cr_para_wr_en),
    .phy_cr_para_addr               (phy_cr_para_addr),
    .phy_cr_respond_time            (phy_cr_respond_time),
    .phy_cr_rd_data_load_en         (phy_cr_rd_data_load_en),
    .phy_cr_rd_data_return_value    (phy_cr_rd_data_return_value),
    
    .phy_reg_esm_data_rate1                      (phy_reg_esm_data_rate1            ), 
    .phy_reg_esm_data_rate0                      (phy_reg_esm_data_rate0           ), 
    .phy_reg_esm_enable                          (phy_reg_esm_enable                ), 

    .serdes_arch                    (serdes_arch),
    .rxwidth                        (rxwidth),
    .recvdclk                       (recvdclk),
    .serdes_pipe_turnoff_lanes      (serdes_pipe_turnoff_lanes),

    .mac_phy_pclkchangeack          (mac_phy_pclkchangeack),
    .phy_mac_pclkchangeok           (phy_mac_pclkchangeok),

    .mac_phy_maxpclkreq_n           (mac_phy_maxpclkreq_n),
    .phy_mac_maxpclkack_n           (phy_mac_maxpclkack_n),

    .pclk_mode_input                (pclk_mode_input),
    
    .los_rxelecidle_filtered        (los_rxelecidle_filtered),  
    .los_rxelecidle_unfiltered      (los_rxelecidle_unfiltered), 
    //.los_rxelecidle_noise           (los_rxelecidle_noise), 

// =====================================
// SerDes Outputs
    .txp                            (txp),
    .txn                            (txn),

// PIPE Outputs
    .pclk                           (pclk),
    .pclkx2                         (pclkx2),
    .max_pclk                       (max_pclk),
    .phy_mac_rxdata                 (phy_mac_rxdata),
    .phy_mac_rxdatak                (phy_mac_rxdatak),
    .phy_mac_rxvalid                (phy_mac_rxvalid),
    .phy_mac_rxstatus               (phy_mac_rxstatus),
    //.phy_mac_rxelecidle             (phy_mac_rxelecidle),
    .phy_mac_rxstartblock           (phy_mac_rxstartblock),
    .phy_mac_rxsyncheader           (phy_mac_rxsyncheader),
    .phy_mac_phystatus              (phy_mac_phystatus),
    .phy_mac_rxstandbystatus        (phy_mac_rxstandbystatus)
);


//==============================================================================
// Los logic 
//==============================================================================
DWC_pcie_gphy_los #(
    .TP (TP),
    .NL (NL)
) u_phy_los (                   
    .rst_n                          (phy_rst_n                 ), // reset                             
    .rxp                            (rxp                       ), // serial receive data (pos)         
    .rxn                            (rxn                       ), // serial receive data (neg)         
    .rate                           (mac_phy_rate              ), // current data rate 
    .rx_clock_off                   (pcs_sdm_rx_clock_off      ),                
    .rxelecidle_disable             (mac_phy_rxelecidle_disable), // gate the LoS 
    .mac_phy_powerdown              (mac_phy_powerdown         ),                     
    `ifdef GPHY_ESM_SUPPORT
    .esm_enable                     (phy_reg_esm_enable        ), 
    .esm_data_rate0                 (phy_reg_esm_data_rate0    ), 
    .esm_data_rate1                 (phy_reg_esm_data_rate1    ), 
    `endif // GPHY_ESM_SUPPORT
      
    .rxelecidle_filtered            (los_rxelecidle_filtered   ),      // electrical idle detected filtered 
    .rxelecidle_unfiltered          (los_rxelecidle_unfiltered ),      // electrical idle detected          
    .rxelecidle_noise                (los_rxelecidle_noise      )
);


DWC_pcie_gphy_pmu #(
    .TP                        (TP),
    .NL                        (NL),
    .TXEI_WD                   (TXEI_WD)
) u_phy_pmu (
    // Inputs
    .power_on_rst_n            (power_up_rst_n),
    .phy_dig_rst_n             (phy_rst_n),
    .perst_n                   (perst_n),
    .refclk                    (refclk_p),
    .powerdown                 (mac_phy_powerdown[3:0]),
    .phy_mac_phystatus         (phy_mac_phystatus),
    .mac_phy_txelecidle        (mac_phy_txelecidle),
    .mac_phy_txcompliance      (mac_phy_txcompliance),
    .serdes_pipe_turnoff_lanes (serdes_pipe_turnoff_lanes),
    .serdes_arch               (serdes_arch),
    // Outputs
    .phy_pmu_en_iso_n_r        (phy_pmu_en_iso_n)
);

endmodule

