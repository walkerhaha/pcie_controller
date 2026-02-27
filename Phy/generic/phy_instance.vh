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
// ---    $DateTime: 2020/10/23 04:57:34 $
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/phy_instance.vh#20 $
// -------------------------------------------------------------------------
// Description: generic PHY instantiation
// -------------------------------------------------------------------------


// these are the signals going from the PHY into the MAC through the PIPE test
// mux (instantiated at the bottom of this file)
wire    [(NL*PHY_NB*PIPE_DATA_WD)-1:0]   muxin_phy_mac_rxdata;
wire    [(NL*PHY_NB)-1:0]                muxin_phy_mac_rxdatak;
wire    [NL-1:0]                         muxin_phy_mac_rxvalid;
wire    [(NL*3)-1:0]                     muxin_phy_mac_rxstatus;
wire    [NL-1:0]                         muxin_phy_mac_rxelecidle;
wire    [NL-1:0]                         muxin_phy_mac_phystatus;
`ifdef CX_PIPE_PCLK_AS_PHY_INPUT
wire                                     muxin_phy_mac_maxpclkack_n;
`endif
`ifdef CX_PIPE_PCLK_MODE_1
wire    [NL-1:0]                         muxin_phy_mac_pclkchangeok;
`endif
wire    [NL-1:0]                         muxin_phy_mac_rxstandbystatus;
wire    [NL-1:0]                         muxin_phy_mac_rxdatavalid;
wire    [NL*RXSB_WD-1:0]                 muxin_phy_mac_rxstartblock;
wire    [NL*RXSB_WD*2-1:0]               muxin_phy_mac_rxsyncheader;
wire    [NL*FS_LF_WD-1:0]                muxin_phy_mac_localfs;
wire    [NL*FS_LF_WD-1:0]                muxin_phy_mac_locallf;
wire    [NL*DIRFEEDBACK_WD-1:0]          muxin_phy_mac_dirfeedback;
wire    [NL*FOMFEEDBACK_WD-1:0]          muxin_phy_mac_fomfeedback;
wire    [NL*TX_COEF_WD-1:0]              muxin_phy_mac_local_tx_pset_coef;
wire    [NL-1:0]                         muxin_phy_mac_local_tx_coef_valid;



`ifdef VIP_MODE_IS_SPIPE
// -----------------------------------------------------------------------------
// PIPE 2 PIPE test mode instantiation
// -----------------------------------------------------------------------------
`include "pipe2pipe_instance.vh"
`else // !VIP_MODE_IS_SPIPE
wire    [NL-1:0]                         int_mac_phy_rxpolarity;
wire                                     int_mac_phy_elasticbuffermode;
wire    [2:0]                            int_mac_phy_rate;
wire    [NL*TX_COEF_WD-1:0]              int_mac_phy_txdeemph;
wire    [2:0]                            int_mac_phy_txmargin;
wire                                     int_mac_phy_txswing;
wire    [NL*RX_PSET_WD-1:0]              int_mac_phy_rxpresethint;
wire    [NL-1:0]                         int_mac_phy_invalid_req;
wire    [NL-1:0]                         int_mac_phy_rxeqinprogress;
wire    [NL-1:0]                         int_mac_phy_rxeqeval;
wire    [NL*TX_PSET_WD-1:0]              int_mac_phy_local_pset_index;
wire    [NL-1:0]                         int_mac_phy_getlocal_pset_coef;
wire    [NL*FS_LF_WD-1:0]                int_mac_phy_fs;
wire    [NL*FS_LF_WD-1:0]                int_mac_phy_lf;
wire                                     int_mac_phy_blockaligncontrol;
wire                                     int_mac_phy_encodedecodebypass;
wire    [NL*8-1:0]                       int_mac_phy_messagebus;
`ifdef CX_PCIE_OVER_CIO_ENABLE
assign                          phy_mac_txcready = 1'b1;
assign                          phy_mac_rxcvalid = phy_mac_rxdatavalid[0];
`endif


wire    [NL-1:0]                         int_mac_phy_txstartblock;
wire    [NL*SYNCHDR_WD-1:0]              int_mac_phy_txsyncheader;
wire    [NL*8-1:0]                       int_phy_mac_messagebus;
wire    [(NL*PHY_NB)-1:0]                int_mac_phy_txdatak;
wire    [NL-1:0]                         int_mac_phy_txcompliance;

assign int_mac_phy_txdatak      = `ifndef CX_PIPE_SERDES_ARCH mac_phy_txdatak      `else '0 `endif;
assign int_mac_phy_txcompliance = `ifndef CX_PIPE_SERDES_ARCH mac_phy_txcompliance `else '0 `endif;

`ifndef CX_PIPE_SERDES_ARCH
   `ifdef CX_GEN3_SPEED
   assign int_mac_phy_txstartblock       = mac_phy_txstartblock;
   assign int_mac_phy_txsyncheader       = mac_phy_txsyncheader;
   `else
   assign int_mac_phy_txstartblock       = '0;
   assign int_mac_phy_txsyncheader       = '0;
   `endif // CX_GEN3_SPEED
`else //CX_PIPE_SERDES_ARCH
   assign int_mac_phy_txstartblock       = '0;
   assign int_mac_phy_txsyncheader       = '0;
`endif   

`ifndef CX_PIPE_LOW_PIN_COUNT
assign int_mac_phy_rxpolarity         = mac_phy_rxpolarity;
assign int_mac_phy_elasticbuffermode  = mac_phy_elasticbuffermode;

assign int_mac_phy_txdeemph           =
  `ifdef CX_GEN3_SPEED
    mac_phy_txdeemph 
  `else
    `ifdef CX_GEN2_SPEED
      {NL{'0,mac_phy_txdeemph}}
    `else 
      '0 
    `endif // CX_GEN2_SPEED
  `endif ; // CX_GEN3_SPEED

assign int_mac_phy_txmargin           = `ifdef CX_GEN2_SPEED mac_phy_txmargin           `else '0 `endif;
assign int_mac_phy_txswing            = `ifdef CX_GEN2_SPEED mac_phy_txswing            `else '0 `endif;
assign int_mac_phy_rxpresethint       = `ifdef CX_GEN3_SPEED mac_phy_rxpresethint       `else '0 `endif;
assign int_mac_phy_invalid_req        = `ifdef CX_GEN3_SPEED mac_phy_invalid_req        `else '0 `endif;
assign int_mac_phy_rxeqinprogress     = `ifdef CX_GEN3_SPEED mac_phy_rxeqinprogress     `else '0 `endif;
assign int_mac_phy_rxeqeval           = `ifdef CX_GEN3_SPEED mac_phy_rxeqeval           `else '0 `endif;
assign int_mac_phy_local_pset_index   = `ifdef CX_GEN3_SPEED mac_phy_local_pset_index   `else '0 `endif;
assign int_mac_phy_getlocal_pset_coef = `ifdef CX_GEN3_SPEED mac_phy_getlocal_pset_coef `else '0 `endif;
assign int_mac_phy_fs                 = `ifdef CX_GEN3_SPEED mac_phy_fs                 `else '0 `endif;
assign int_mac_phy_lf                 = `ifdef CX_GEN3_SPEED mac_phy_lf                 `else '0 `endif;
assign int_mac_phy_blockaligncontrol  = `ifdef CX_GEN3_SPEED mac_phy_blockaligncontrol  `else '0 `endif;
assign int_mac_phy_encodedecodebypass = `ifdef CX_GEN3_SPEED mac_phy_encodedecodebypass `else '0 `endif;
`else // CX_PIPE_LOW_PIN_COUNT
assign int_mac_phy_rxpolarity         = '0;
assign int_mac_phy_elasticbuffermode  = '0;
assign int_mac_phy_txdeemph           = '0;
assign int_mac_phy_txmargin           = '0;
assign int_mac_phy_rxpresethint       = '0;
assign int_mac_phy_txswing            = '0;
assign int_mac_phy_invalid_req        = '0;
assign int_mac_phy_rxeqinprogress     = '0;
assign int_mac_phy_rxeqeval           = '0;
assign int_mac_phy_local_pset_index   = '0;
assign int_mac_phy_getlocal_pset_coef = '0;
assign int_mac_phy_fs                 = '0;
assign int_mac_phy_lf                 = '0;
assign int_mac_phy_blockaligncontrol  = '0;
assign int_mac_phy_encodedecodebypass = '0;
`endif // CX_PIPE_LOW_PIN_COUNT
assign int_mac_phy_messagebus         = `ifdef CX_PIPE_REGIF_SUPPORT mac_phy_messagebus `else '0 `endif;


`ifdef CX_PIPE_REGIF_SUPPORT
assign phy_mac_messagebus             = int_phy_mac_messagebus;
`endif // CX_PIPE_REGIF_SUPPORT

`ifdef CX_GEN5_SPEED
assign int_mac_phy_rate = mac_phy_rate;
`else // !CX_GEN5_SPEED
`ifdef CX_GEN2_SPEED
  `ifdef CX_GEN3_SPEED
assign int_mac_phy_rate = {1'b0,mac_phy_rate};
  `else //!CX_GEN3_SPEED
assign int_mac_phy_rate = {2'b0,mac_phy_rate};
  `endif //CX_GEN3_SPEED
`else //!CX_GEN2_SPEED
assign int_mac_phy_rate = 3'b00;
`endif // CX_GEN2_SPEED
`endif // CX_GEN5_SPEED

// drive this optional signal to zero
assign phy_cfg_status = 32'b0;


// ========================================================================
// data path connectivity
// ========================================================================
// When in PIPE51 mode, GPHY data-related signals will be maxed out to meet
// SerDes arch requirement (10bit per symbol), however the controller will 
// still sport the standard 8bit per symbol interface if SerDes mode is not
// enable. This logic is needed to conceal this difference
//                         GPHY    MAC
// PIPE < 5.1                8      8
// PIPE 5.1 w/o  SerDes     10      8
// PIPE 5.1 with SerDes     10     10
localparam PCS_DATA_WD   = `ifdef CX_PIPE5_SUPPORT 10 `else 8 `endif ;
// this is the difference between the GPHY and controller data width (per symbol)
localparam PCS_DATA_PAD  = PCS_DATA_WD - PIPE_DATA_WD;

wire [(NL*PHY_NB*PCS_DATA_WD)-1:0]                int_mac_phy_txdata;
wire [(NL*PHY_NB*PCS_DATA_WD)-1:0]                int_phy_mac_rxdata;
genvar sym_idx;
generate
  for (sym_idx=0; sym_idx<PHY_NB*NL; sym_idx=sym_idx+1)
  begin: gen_gphy_sym_w
    if ( PCS_DATA_PAD > 0)
    begin: gen_gphy_w_pad
      // Tx datapath padding
      assign int_mac_phy_txdata [PCS_DATA_WD*sym_idx+PIPE_DATA_WD +: PCS_DATA_PAD] = '0;
    end // gen_gphy_w_pad

    // Tx datapath
    assign int_mac_phy_txdata   [ PCS_DATA_WD*sym_idx +: PIPE_DATA_WD] = mac_phy_txdata     [PIPE_DATA_WD*sym_idx +: PIPE_DATA_WD];
    // Rx datapath
    assign muxin_phy_mac_rxdata [PIPE_DATA_WD*sym_idx +: PIPE_DATA_WD] = int_phy_mac_rxdata [ PCS_DATA_WD*sym_idx +: PIPE_DATA_WD];
  end // gen_gphy_sym_w
endgenerate

wire [3:0] int_mac_phy_pclk_rate;
generate
   if (P_R_WD == 4)
      assign int_mac_phy_pclk_rate = mac_phy_pclk_rate;
   else
      assign int_mac_phy_pclk_rate = {1'b0, mac_phy_pclk_rate};   
      
endgenerate

DWC_pcie_gphy u_phy (
    .refclk_p                           (refclk_p),
    .refclk_n                           (refclk_n),
`ifndef CX_PIPE_PCLK_AS_PHY_INPUT
    .pclk                               (pclk),
`else // !CX_PIPE_PCLK_AS_PHY_INPUT
    .pclk                               (),
`endif // CX_PIPE_PCLK_AS_PHY_INPUT
    .pclkx2                             (pclkx2),
    .max_pclk                           (max_pclk),
    .phy_rst_n                          (phy_rst_n),
    .power_up_rst_n                     (power_up_rst_n),
    .perst_n                            (phy_perst_n),

    .phy_ref_clk_req_n                  (phy_ref_clk_req_n),
`ifndef CX_PIPE43_SUPPORT
    .mac_phy_pclkreq_n                  (mac_phy_pclkreq_n),
`else
    .mac_phy_pclkreq_n                  ('0),
`endif // CX_PIPE43_SUPPORT

    
`ifdef CX_L1_SUBSTATES_ENABLE
    .mac_phy_rxelecidle_disable         (mac_phy_rxelecidle_disable),
    .mac_phy_txcommonmode_disable       (mac_phy_txcommonmode_disable),
`ifndef CX_PIPE43_SUPPORT
    .phy_mac_pclkack_n                  (phy_mac_pclkack_n),
`else 
    .phy_mac_pclkack_n                  (),
`endif // CX_PIPE43_SUPPORT
`else
    .mac_phy_rxelecidle_disable         (1'b0),
    .mac_phy_txcommonmode_disable       (1'b0),
    .phy_mac_pclkack_n                  (),
`endif // CX_L1_SUBSTATES_ENABLE       
    
`ifdef CX_PIPE43_SUPPORT
`ifndef CX_PIPE43_ASYNC_HS_BYPASS
    .mac_phy_asyncpowerchangeack        (mac_phy_asyncpowerchangeack),
`endif // CX_PIPE43_ASYNC_HS_BYPASS
`endif // CX_PIPE43_SUPPORT


`ifdef GPHY_PIPE51_SUPPORT
    .mac_phy_serdes_arch               (mac_phy_serdes_arch),
`ifdef CX_PIPE_SERDES_ARCH
    .rx_clk                            (rx_clk),  
    .mac_phy_rxwidth                   (mac_phy_rxwidth),
`else
    .rx_clk                            (),
    .mac_phy_rxwidth                   (mac_phy_width),
`endif // CX_PIPE_SERDES_ARCH
`endif //GPHY_PIPE51_SUPPORT

`ifdef CX_PIPE_PCLK_MODE_1
   .mac_phy_pclkchangeack   (mac_phy_pclkchangeack),
   .phy_mac_pclkchangeok    (muxin_phy_mac_pclkchangeok),
   .mac_phy_maxpclkreq_n    (mac_phy_maxpclkreq_n),
   .phy_mac_maxpclkack_n    (muxin_phy_mac_maxpclkack_n),  
   .i_pclk                  (pclk),
`elsif CX_PIPE_PCLK_AS_PHY_INPUT
   // mode 2 and 3
   .mac_phy_pclkchangeack   ('0),   
   .phy_mac_pclkchangeok    (),
   .mac_phy_maxpclkreq_n    (mac_phy_maxpclkreq_n),
   .phy_mac_maxpclkack_n    (muxin_phy_mac_maxpclkack_n),  
   .i_pclk                  (pclk),
`else // !CX_PIPE_PCLK_AS_PHY_INPUT
   .mac_phy_pclkchangeack   ('0),   
   .phy_mac_pclkchangeok    (),     
   .mac_phy_maxpclkreq_n    ('0),   
   .phy_mac_maxpclkack_n    (),     
   .i_pclk                  ('0),   
`endif //CX_PIPE_PCLK_MODE_1

    // Phy PIPE interface
    .phy_mac_rxdata                     (int_phy_mac_rxdata),
    .phy_mac_rxdatak                    (muxin_phy_mac_rxdatak),
    .phy_mac_rxvalid                    (muxin_phy_mac_rxvalid),
    .phy_mac_rxdatavalid                (muxin_phy_mac_rxdatavalid),
    .phy_mac_rxstatus                   (muxin_phy_mac_rxstatus),
    .phy_mac_rxelecidle                 (muxin_phy_mac_rxelecidle),
    .phy_mac_phystatus                  (muxin_phy_mac_phystatus),
    .phy_mac_rxstandbystatus            (muxin_phy_mac_rxstandbystatus),
    .phy_mac_rxstartblock               (muxin_phy_mac_rxstartblock),
    .phy_mac_rxsyncheader               (muxin_phy_mac_rxsyncheader),
    .phy_mac_localfs                    (muxin_phy_mac_localfs),
    .phy_mac_locallf                    (muxin_phy_mac_locallf),
    .phy_mac_dirfeedback                (muxin_phy_mac_dirfeedback),
    .phy_mac_fomfeedback                (muxin_phy_mac_fomfeedback),
    .phy_mac_local_tx_pset_coef         (muxin_phy_mac_local_tx_pset_coef),
    .phy_mac_local_tx_coef_valid        (muxin_phy_mac_local_tx_coef_valid),
    .mac_phy_rxpresethint               (int_mac_phy_rxpresethint),
    .mac_phy_invalid_req                (int_mac_phy_invalid_req),
    .mac_phy_rxeqinprogress             (int_mac_phy_rxeqinprogress),
    .mac_phy_rxeqeval                   (int_mac_phy_rxeqeval),
    .mac_phy_local_pset_index           (int_mac_phy_local_pset_index),
    .mac_phy_getlocal_pset_coef         (int_mac_phy_getlocal_pset_coef),
    .mac_phy_fs                         (int_mac_phy_fs),
    .mac_phy_lf                         (int_mac_phy_lf),
    .mac_phy_blockaligncontrol          (int_mac_phy_blockaligncontrol),
    .mac_phy_encodedecodebypass         (int_mac_phy_encodedecodebypass),

    .mac_phy_txdata                     (int_mac_phy_txdata),
    .mac_phy_txdatak                    (int_mac_phy_txdatak),
    .mac_phy_txdatavalid                (mac_phy_txdatavalid),
    .mac_phy_txdetectrx_loopback        (mac_phy_txdetectrx_loopback),
    .mac_phy_elasticbuffermode          (int_mac_phy_elasticbuffermode),
    .mac_phy_txelecidle                 (mac_phy_txelecidle),
    .mac_phy_txcompliance               (int_mac_phy_txcompliance),
    .mac_phy_rxpolarity                 (int_mac_phy_rxpolarity),
    .mac_phy_width                      (mac_phy_width),
    
  `ifdef CX_GEN5_SPEED  
     .mac_phy_pclk_rate                 (int_mac_phy_pclk_rate),
  `else
  `ifdef CX_CCIX_ESM_SUPPORT
     .mac_phy_pclk_rate                 (mac_phy_pclk_rate),
  `else
     .mac_phy_pclk_rate                 ({1'b0,mac_phy_pclk_rate}),
  `endif //CX_CCIX_ESM_SUPPORT           
  `endif //CX_GEN5_SPEED   
    
    
    .mac_phy_rxstandby                  (mac_phy_rxstandby),
    .mac_phy_powerdown                  (mac_phy_powerdown),
    .mac_phy_rate                       (int_mac_phy_rate),      
    .mac_phy_txdeemph                   (int_mac_phy_txdeemph),
    .mac_phy_txmargin                   (int_mac_phy_txmargin),
    .mac_phy_txswing                    (int_mac_phy_txswing),
    .mac_phy_txstartblock               (int_mac_phy_txstartblock),
    .mac_phy_txsyncheader               (int_mac_phy_txsyncheader),
    .mac_phy_messagebus                 (int_mac_phy_messagebus),
    .phy_mac_messagebus                 (int_phy_mac_messagebus),
    `ifdef CX_SRIS_SUPPORT
    .mac_phy_sris_mode                  (app_sris_mode),
    `else
    .mac_phy_sris_mode                  ('0),
    `endif //CX_SRIS_SUPPORT
    
    `ifdef CX_SERDES_ARCH_LANES_TURNOFF
    .serdes_pipe_turnoff_lanes          (serdes_pipe_turnoff_lanes),
    `else
    .serdes_pipe_turnoff_lanes          ('0),
    `endif //CX_SERDES_ARCH_LANES_TURNOFF
    
    
   `ifdef CX_PHY_VIEWPORT_ENABLE
    .phy_reg_clk_g                      (phy_reg_clk_g),
    .phy_reg_rst_n                      (phy_reg_rst_n),  
    .phy_cr_para_ack                    (phy_cr_para_ack),
    .phy_cr_para_rd_data                (phy_cr_para_rdata),
    .phy_cr_para_rd_en                  (phy_cr_para_rd_en),
    .phy_cr_para_wr_data                (phy_cr_para_wr_data),
    .phy_cr_para_wr_en                  (phy_cr_para_wr_en),
    .phy_cr_para_addr                   (phy_cr_para_addr),
   `else
    .phy_reg_clk_g                      ('0),
    .phy_reg_rst_n                      ('1),  
    .phy_cr_para_ack                    (),
    .phy_cr_para_rd_data                (),
    .phy_cr_para_rd_en                  ('0),
    .phy_cr_para_wr_data                ('0),
    .phy_cr_para_wr_en                  ('0),
    .phy_cr_para_addr                   ('0),
   `endif //CX_PHY_VIEWPORT_ENABLE

    .txp                                (txp),
    .txn                                (txn),
    .rxp                                (rxp),
    .rxn                                (rxn)
 );
`endif // !VIP_MODE_IS_SPIPE

`ifndef CX_PIPE_SERDES_ARCH
// -----------------------------------------------------------------------------
// Rx path test mux used in some testbenches
// -----------------------------------------------------------------------------
pipe_test_mux #(
  .NL              (NL),
  .NB              (PHY_NB),
  .PIPE_DATA_WD    (PIPE_DATA_WD),
  .RATE_WD         (RATE_WD),
  `ifdef CX_GEN3_SPEED
  .RXSB_WD         (RXSB_WD),
  `endif // CX_GEN3_SPEED
  .TX_COEF_WD      (TX_COEF_WD),
  .DIRFEEDBACK_WD  (DIRFEEDBACK_WD),
  .FOMFEEDBACK_WD  (FOMFEEDBACK_WD),
  .FS_LF_WD        (FS_LF_WD)
) u_pipe_test_mux (
  .pclk                                  (pclk),
  .pipe_rst_n                            (phy_rst_n),
  .mac_phy_powerdown                     (mac_phy_powerdown),
  `ifdef CX_GEN2_SPEED
  .mac_phy_rate                          (mac_phy_rate),
  `endif

  .mac_phy_elasticbuffermode             (mac_phy_elasticbuffermode),
  .in_phy_mac_rxdata                     (muxin_phy_mac_rxdata),
`ifndef CX_PIPE_SERDES_ARCH
  .in_phy_mac_rxdatak                    (muxin_phy_mac_rxdatak),
  .in_phy_mac_rxdatavalid                (muxin_phy_mac_rxdatavalid),
`endif // !CX_PIPE_SERDES_ARCH
  .in_phy_mac_rxvalid                    (muxin_phy_mac_rxvalid),
  .in_phy_mac_rxstatus                   (muxin_phy_mac_rxstatus),
  .in_phy_mac_rxelecidle                 (muxin_phy_mac_rxelecidle),
  .in_phy_mac_phystatus                  (muxin_phy_mac_phystatus),
`ifdef CX_PIPE_PCLK_AS_PHY_INPUT
  .in_phy_mac_maxpclkack_n               (muxin_phy_mac_maxpclkack_n),
`endif
`ifdef CX_PIPE_PCLK_MODE_1
  .in_phy_mac_pclkchangeok                  (muxin_phy_mac_pclkchangeok),
`endif
  .in_phy_mac_rxstandbystatus            (muxin_phy_mac_rxstandbystatus),
  `ifdef CX_GEN3_SPEED
    `ifndef CX_PIPE_SERDES_ARCH
  .in_phy_mac_rxstartblock               (muxin_phy_mac_rxstartblock),
  .in_phy_mac_rxsyncheader               (muxin_phy_mac_rxsyncheader),
    `endif // !CX_PIPE_SERDES_ARCH
  `ifndef CX_PIPE_LOW_PIN_COUNT
  .in_phy_mac_localfs                    (muxin_phy_mac_localfs),
  .in_phy_mac_locallf                    (muxin_phy_mac_locallf),
  .in_phy_mac_dirfeedback                (muxin_phy_mac_dirfeedback),
  .in_phy_mac_fomfeedback                (muxin_phy_mac_fomfeedback),
  .in_phy_mac_local_tx_pset_coef         (muxin_phy_mac_local_tx_pset_coef),
  .in_phy_mac_local_tx_coef_valid        (muxin_phy_mac_local_tx_coef_valid),
  `endif // !CX_PIPE_LOW_PIN_COUNT
  `endif // CX_GEN3_SPEED

   // Indicates if the RxPipeAgent is present. 
  .rxAgentPresent                        (),

  .out_phy_mac_rxdata                    (phy_mac_rxdata),
`ifndef CX_PIPE_SERDES_ARCH
  .out_phy_mac_rxdatak                   (phy_mac_rxdatak),
  .out_phy_mac_rxdatavalid               (phy_mac_rxdatavalid),
`endif // !CX_PIPE_SERDES_ARCH
  .out_phy_mac_rxvalid                   (phy_mac_rxvalid),
  .out_phy_mac_rxstatus                  (phy_mac_rxstatus),
  .out_phy_mac_rxelecidle                (phy_mac_rxelecidle),
  .out_phy_mac_phystatus                 (phy_mac_phystatus),
`ifdef CX_PIPE_PCLK_AS_PHY_INPUT
  .out_phy_mac_maxpclkack_n               (phy_mac_maxpclkack_n),
`endif
`ifdef CX_PIPE_PCLK_MODE_1
  .out_phy_mac_pclkchangeok                  (phy_mac_pclkchangeok),
`endif
  .out_phy_mac_rxstandbystatus           (phy_mac_rxstandbystatus)
  `ifdef CX_GEN3_SPEED
    `ifndef CX_PIPE_SERDES_ARCH
  ,
  .out_phy_mac_rxstartblock              (phy_mac_rxstartblock),
  .out_phy_mac_rxsyncheader              (phy_mac_rxsyncheader)
    `endif // !CX_PIPE_SERDES_ARCH
  `ifndef CX_PIPE_LOW_PIN_COUNT
  ,
  .out_phy_mac_localfs                   (phy_mac_localfs),
  .out_phy_mac_locallf                   (phy_mac_locallf),
  .out_phy_mac_dirfeedback               (phy_mac_dirfeedback),
  .out_phy_mac_fomfeedback               (phy_mac_fomfeedback),
  .out_phy_mac_local_tx_pset_coef        (phy_mac_local_tx_pset_coef),
  .out_phy_mac_local_tx_coef_valid       (phy_mac_local_tx_coef_valid)
  `endif // !CX_PIPE_LOW_PIN_COUNT
  `endif // CX_GEN3_SPEED
); // pipe_test_mux
`else
 assign phy_mac_rxdata                      =muxin_phy_mac_rxdata              ;
 assign phy_mac_rxdatak                     =muxin_phy_mac_rxdatak             ;
 assign phy_mac_rxdatavalid                 =muxin_phy_mac_rxdatavalid         ;
 assign phy_mac_rxvalid                     =muxin_phy_mac_rxvalid             ;
 assign phy_mac_rxstatus                    =muxin_phy_mac_rxstatus            ;
 assign phy_mac_rxelecidle                  =muxin_phy_mac_rxelecidle          ;
 assign phy_mac_phystatus                   =muxin_phy_mac_phystatus           ;
`ifdef CX_PIPE_PCLK_AS_PHY_INPUT
 assign phy_mac_maxpclkack_n                =muxin_phy_mac_maxpclkack_n        ;
`endif
`ifdef CX_PIPE_PCLK_MODE_1
 assign phy_mac_pclkchangeok                =muxin_phy_mac_pclkchangeok        ;
`endif
 assign phy_mac_rxstandbystatus             =muxin_phy_mac_rxstandbystatus      ;
 assign phy_mac_rxstartblock                =muxin_phy_mac_rxstartblock        ;
 assign phy_mac_rxsyncheader                =muxin_phy_mac_rxsyncheader        ;
 assign phy_mac_localfs                     =muxin_phy_mac_localfs             ;
 assign phy_mac_locallf                     =muxin_phy_mac_locallf             ;
 assign phy_mac_dirfeedback                 =muxin_phy_mac_dirfeedback         ;
 assign phy_mac_fomfeedback                 =muxin_phy_mac_fomfeedback         ;
 assign phy_mac_local_tx_pset_coef          =muxin_phy_mac_local_tx_pset_coef  ;
 assign phy_mac_local_tx_coef_valid         =muxin_phy_mac_local_tx_coef_valid;  
`endif //CX_PIPE_SERDES_ARCH

