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
// ---    $DateTime: 2020/09/22 00:22:11 $
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pipe2phy.v#12 $
// -------------------------------------------------------------------------
// --- Module Description:  PIPE Interface to PHY Signal conversion.  Performs
// --- the reconcilliation function between the SDM/SerDes combined functions
// --  to the PIPE+ interface to the CX-PL Port Logic core.
// ---
// --- Currently control registers for the P2P are assumed in the port's config
// --  module and the signals are routed in through the PHY/SDM.
// -----------------------------------------------------------------------------

module DWC_pcie_gphy_pipe2phy #(
  parameter TP           = -1,
  parameter PIPE_DATA_WD = -1
) (
// =====================================
// General Inputs
   input              clk,                                                // Port Logic core clock (125MHz)
   input              rst_n,                                              // Port Logic core reset; active low
   input              serdes_arch,

// PIPE+ Side Inputs                                                      // Note:  PIPE+ interface synch to clk
   input [PIPE_DATA_WD-1:0]        mac_phy_txdata,                                     // Parallel transmit byte data
   input              mac_phy_txdatak,                                    // K-character indication
   input              mac_phy_txdetectrx_loopback,                        // Enable receive detection sequence generation (loopback)
   input              mac_phy_txelecidle,                                 // Place transmitter into electrical idle
   input              mac_phy_txcompliance,                               // Enable transmission of compliance sequence (disp control)
   input [3:0]        mac_phy_powerdown,                                  // Signal to go to specific power state
   input [2:0]        mac_phy_rate,                                       // 1 = change speed to 5 Gbit/s, 2 = change speed to 8 Gbit/s
   input [3:0]        mac_phy_pclk_rate,
   input [1:0]        mac_phy_pclkreq_n,                                  // Pclk request control
   input              asyncpowerchangeack,
   input              mac_phy_rxpolarity,
   input              powerdown_random_phystatus_en,
   input [2:0]        p1_random_range,
   input              p1_phystatus_time_load_en,
   input [12:0]       p1_phystatus_time, 
   
   input              p2_phystatus_rise_random_en,
   input              p2_random_phystatus_rise_load_en,
   input [12:0]       p2_random_phystatus_rise_value,
   input              p2_phystatus_fall_random_en,
   input              p2_random_phystatus_fall_load_en,
   input [12:0]       p2_random_phystatus_fall_value,
   input [2:0]        update_localfslf_mode,
    
   input              rate_random_phystatus_en,
   input              P1X_to_P1_exit_mode,                                // 0 = any type ; 1 = always as P2 exit
   input              mac_phy_txdatavalid,                                // ignore a byte or word on the data interface
   input              dec8b10b_rxdatavalid,                               // ignore a byte or word on the data interface
   input              mac_phy_txstartblock,                               // first byte of the data interface is the first
   input  [1:0]       mac_phy_txsynchdr,                                  // sync header to use in the next 130b block
   input              dec8b10b_rxstartblock,                              // first byte of the data interface is the first
   input  [1:0]       dec8b10b_rxsynchdr,                                 // sync header to use in the next 130b block
   input              skp_broken,                                         // report error if SKP is broken at gen3 speed
   output             pclk_stable,                                        // To tell the timing to start Local FS/LF PIPE message
   input              phy_reg_localfslf_done,                             // To delay phystatus until Local FS/LF PIPE message completion
   output reg         phy_mac_rxstartblock,                               // first byte of the data interface is the first
   output reg [1:0]   phy_mac_rxsynchdr,                                  // sync header to use in the next 130b block

// SerDes Side Inputs
   input [PIPE_DATA_WD-1:0]        dec8b10b_rxdata,                                    // Receive byte data from 8B10B decoder
   input              dec8b10b_rxdatak,                                   // K-character indication for RX data
   input              dec8b10b_rxdata_dv,                                 // Indication that RX data is valid
   input              dec8b10b_rxdisperror,                               // 8B10B disparity error
   input              dec8b10b_rxcodeerror,                               // 8B10B code violation
   input              elasbuf_rxunderflow,                                // Elastic buffer experienced underflow
   input              elasbuf_rxoverflow,                                 // Elastic buffer experienced overflow
   input              elasbuf_rxskipadded,                                // Elastic buffer added a skip
   input              elasbuf_rxskipremoved,                              // Elastic buffer removed a skip
   input              sds_sdm_rxdetected,                                 // Results from SerDes receiver detection process
   input              sds_sdm_comma_lock,                                 // Comma detect function in "comma lock"
   input              sds_sdm_ready,                                      // SerDes ready; map to PLL lock or pwr good indication
   input              pclk_off_ack,                                       // SerDes confirmed pclk removal
   input              lock,

  `ifdef GPHY_ESM_SUPPORT
   input              esm_enable,
   input [6:0]        esm_data_rate0,
   input [6:0]        esm_data_rate1,
  `endif // GPHY_ESM_SUPPORT 

   input              mac_phy_rxstandby,
   output reg         phy_mac_rxstandbystatus,
   
   // PCLK as PHY input
   // input/output
   input              mac_phy_pclkchangeack,
   output reg         phy_mac_pclkchangeok,
   input              pclk_mode_input,
   input              serdes_pipe_turnoff_lanes,

// PIPE+ Outputs
   output reg [PIPE_DATA_WD-1:0]   phy_mac_rxdata,                                     // Receive byte data
   output reg         phy_mac_rxdatak,                                    // Receive K character indication
   output             phy_mac_rxvalid,                                    // Receive data valid
   output reg [2:0]   phy_mac_rxstatus,                                   // Receive data valid
   output reg         phy_mac_phystatus,                                  // Indicates completion of operation (context specific)
   output             phy_mac_rxdatavalid,                                // ignore a byte or word on the data interface

// SerDes Outputs
   output reg [PIPE_DATA_WD-1:0]   sdm_sds_txdata,                                     // Many of the following signals are just re-registered from PIPE+
   output reg         sdm_sds_txdatak,
   output             sdm_sds_reset_n,
   output reg         sdm_sds_loopback,                                   // Decoded loopback control
   output reg         sdm_sds_txdetectrx,
   output reg         sdm_sds_txelecidle,
   output reg         sdm_sds_txcompliance,
   output reg         sdm_sds_beacongen,                                  // Decoded beacon generation control
   output reg [3:0]   sdm_sds_powerdown,
   output reg         sdm_sds_rxpolarity,
   output reg         sdm_sds_txerror,
   output reg [2:0]   sdm_sds_rate,                                       // signal for rate to Phy
   output reg [2:0]   sds_sdm_curr_rate,                                  // SerDes is in Gen2 speed  
   output reg         sdm_sds_rxstandby,
   output reg         sdm_sds_txdatavalid,                              
   output reg         sdm_sds_txstartblock,
   output reg [1:0]   sdm_sds_txsynchdr,

// Misc Control Outputs
   output            sdm_sds_set_disp,                                   // Set disparity (for compliance pattern)
   output reg        pclk_off_req,                                       // request to SerDes to remove pclk
   output            phy_mac_pclkack_n,                                  // Ack that pclk is off
   output            rx_clock_off,                                       // request to turn off rx clk
   output reg        randomize_P1X_to_P1,                                // internal P1X_to_P1_exit mode, 0 = normal P1 entry ; 1 = as P2 exit 
   output            rate_change_req,                                    // request to change the rate
   output reg        lane_disabled
);

// =============================================================================
// phystatus FSM state encoding
// =============================================================================
localparam S_IDLE                 = 4'b0000;
localparam S_READY                = 4'b0001;
localparam S_PSDET                = 4'b0010;
localparam S_P1DET                = 4'b0011;
localparam S_P2_PREP              = 4'b0100;
localparam S_P2                   = 4'b0101;
localparam S_P1CPM                = 4'b0110;
localparam S_P1X                  = 4'b0111;
localparam S_RXDET                = 4'b1000;
localparam S_RATE                 = 4'b1001;
localparam S_P1X_P1               = 4'b1010;
localparam S_RXSTANDBY_ASSERT     = 4'b1011;
localparam S_RXSTANDBY_DEASSERT   = 4'b1100;


// =============================================================================
// Internal Regs and wires
// =============================================================================
wire                    comma_detect_en;
wire                    comma_detect;
wire                    eie_detect;
wire                    p2p_pulse_txdetectrx;
wire                    ps_change;                          // Power state change detected
wire                    rate_change;                        // Rate change detected
wire                    pclk_rate_change;
wire                    in_p2;                              // Indicates we're in P2
reg                     P11_to_P1CPM;                       // indicates a change from P11 to P1CPM                             
reg                     sdm_sds_turn_off;
wire                    sdm_sds_pulse_reset_n;
reg                     mac_phy_txelecidle_d;               // Delay to match datapath
reg                     mac_phy_txelecidle_d2;              // Delay to match datapath
reg [3:0]               sdm_sds_powerdown_reg;
reg [3:0]               sdm_sds_current_powerdown;

reg                     int_phy_mac_rxvalid;
reg                     int_phy_mac_rxdatavalid;
reg                     p2p_reset_n_reg;
reg                     p2p_reset_n;
reg                     p2p_serdes_ready;
reg                     p2p_txdetectrx;
reg                     p2p_txcompliance;

reg  [3:0]              psfsm_state;                        // Phystatus FSM state
reg  [3:0]              psfsm_state_prev;                   // Phystatus FSM state - previous cycle - used to trigger counters
reg                     psfsm_phystatus;                    // Indicate state changes
reg                     psfsm_rxstandby_status;

reg [3:0]               sdm_sds_pclk_rate;

// start/expired signals for the different timers used by the Phystatus FSM
wire                    rxdet_timer_start;
wire                    rxdet_timer_exp;
wire                    psdet_timer_start;
wire                    psdet_timer_exp;
wire                    p1det_timer_start;
wire                    p1det_timer_exp;

reg                     pclk_off_p1;                      // shows when pclk is of due to L1sub or legacy P1.CPM
reg                     pclk_off_p2;                      // shows when pclk is off in P2
reg                     elasbuf_rxskipadded_d;
reg                     elasbuf_rxskipremoved_d;
reg                     elasbuf_rxskipadded_dd;
reg                     elasbuf_rxskipremoved_dd;
reg                     skp_broken_d;
reg                     skp_broken_dd;
reg                     rate_change_req_int;
reg                     rate_change_req_int_r;

reg                     mac_phy_pclkchangeack_r;
reg                     mac_phy_pclkchangeack_posedge;

wire pclkchangeok_assert_timer_exp;
wire pclkchangeok_assert_timer_start;
// =============================================================================
// support logic
// =============================================================================
assign comma_detect_en = 1;
assign comma_detect    = dec8b10b_rxdata_dv && dec8b10b_rxdata[7:0] == 8'hBC && dec8b10b_rxdatak;
assign eie_detect      = dec8b10b_rxdata_dv && dec8b10b_rxdata[7:0] == 8'hFC && dec8b10b_rxdatak;

assign phy_mac_rxvalid = int_phy_mac_rxvalid;
assign phy_mac_rxdatavalid = int_phy_mac_rxdatavalid;


reg   phy_rst_n_s1;
reg   phy_rst_n_s2;
wire  pipe_rst_n;

assign pipe_rst_n = phy_rst_n_s2;

always @(posedge clk or negedge rst_n)
begin
  if ( !rst_n )
  begin
    phy_rst_n_s1 <= #TP 1'b0;
    phy_rst_n_s2 <= #TP 1'b0;
  end else begin
    phy_rst_n_s1 <= #TP 1'b1;
    phy_rst_n_s2 <= #TP phy_rst_n_s1;
  end
end





reg lock_d;
wire lock_posedge;
wire lock_negedge;

always @(posedge clk or negedge rst_n)
begin
   if (!rst_n) lock_d <= #TP 1'b0;
   else        lock_d <= #TP lock;      
end

assign lock_posedge = ~lock_d && lock;
assign lock_negedge = ~lock && lock_d;

always @(posedge clk or negedge rst_n)
begin
   if (!rst_n) mac_phy_pclkchangeack_r <= #TP 1'b0;
   else        mac_phy_pclkchangeack_r <= #TP mac_phy_pclkchangeack;      
end

assign mac_phy_pclkchangeack_posedge = mac_phy_pclkchangeack && ~mac_phy_pclkchangeack_r;
// =============================================================================
// Re-generation of functional signals to/from the PIPE+ and SerDes
// interfaces based on functions provided either by the SerDes core
// or generated in this module based on gap analysis.
//
// The following notes are to assist in customization for a given SerDes
// core:
//
//  phy_mac_rxvalid:        Data from elastic buffer is valid.
//
//  phy_mac_rxelecidle:     serdes detected rx electrical idle... NOT ordered
//                              sets as these are detected at the upper layers
//
//  phy_mac_rxstatus:       encoded PIPE receiver status. For receiver detection process,
//                              LTSSM assumes valid only on the falling edge of
//                              phy_mac_status
//
//  phy_mac_phystatus:      this signal is context specific and is handled
//                              below in the PS state machine.
//
//  sdm_sds_reset_n:        direct map to reset passed from mac layer (merge
//                              w/ rst_n asynchronously)
//
//  sdm_sds_pulse_reset_n:  single cycle pulse of reset to serdes if needed (merge
//                              w/ rst_n asynchronously)
//
//  sdm_sds_powerdown:      serdes dependent; passed on as-is to generic serdes
//                              model which powers down the model if in P2 (or 2'b11)
//                              may need to bust out to separate rx & tx inputs or
//                              condition for specific serdes cores based on capa-
//                              bilities of the core
//
//  sdm_sds_txdetectrx:     forces serdes to transmit the detection sequence
//
//  sdm_sds_txelecidle:     forces serdes TX outputs to the electrical idle state;
//                              assumes upper layer handled transmission of the
//                              electrical idle ordered sets ahead of time
//
//  sdm_sds_beacongen:      enables serdes to send the beacon pattern; assumes
//                              beacon pattern is either generated in the serdes
//                              or is an input to the serdes core from the application
//                              i.e. beacon pattern generation is not handled in
//                              the phy/sdm function -- only in P2
//
//  sdm_sds_txcompliance:   forces the 8b10b transmit module to go to negative
//                              disparity (sdm_sds_set_disp) for transmission of the compliance
//                              symbol; this is supported in the 8b10b function
//
//  sdm_sds_loopback:       enables loopback per the standard; this currently is
//                              implemented in the phy module in conjunction w/
//                              the 8b10b modules; not the same as EWRAP function
//                              of most legacy serdes devices
//
//  sdm_sds_turn_off:       signal the PHY to turn off when both TxElecIdle and
//                              TxCompliance signals are both asserted.
//
// =============================================================================

// =============================================================================
// Pclk/Rx clock turn ON/OFF logic
// =============================================================================
//logic to gate the phy_mac_pclkack_n in P2 and when changing from P2 to P1
//TODO throw away part of this and use control from FSM instead
wire phy_mac_pclkack_n_posedge;
wire phy_mac_pclkack_n_negedge;
reg  pclk_off_p1_tmp;
reg [5:0] pclk_off_p1_d;

`ifndef GPHY_PIPE43_SUPPORT
// In Pipe4.2 there is a legacy mode for removing reference clock.
// The controller transitions powerdown to P2 and de-asserts mac_phy_pclkreq_n[0]
// The PHY can treat this as P2.CPM and behave in the same was as it does for P2.
// PCLK is disabled, PHY de-asserts its CLKREQ# output.
// The only additional requirement is that when the controller asserts mac_phy_pclkreq_n[0]
// the PHY should assert its CLKREQ# output.
reg       s_refclk_req_p2;
reg       r_pclk_off_ack;
wire      s_set_refclk_req_p2;
wire      s_clear_refclk_req_p2;
reg       r_refclk_req_p2;

// detect the falling edge of mac_phy_pclkreq_n while powerdown is P2
assign s_set_refclk_req_p2 = (pclk_off_p1_d[5] && !pclk_off_p1_d[4]) && pclk_off_p2;
// hold the reference clock request high until we know P1 transition occured and PCLK is restored
assign s_clear_refclk_req_p2 = r_pclk_off_ack && !pclk_off_ack;

always @(*) begin : refclk_p2_PROC
  if(s_set_refclk_req_p2)
    s_refclk_req_p2 = 1'b1;
  else if(s_clear_refclk_req_p2)
    s_refclk_req_p2 = 1'b0;
  else
    s_refclk_req_p2 = r_refclk_req_p2;
end : refclk_p2_PROC

always @(posedge clk or negedge rst_n) begin : refclk_r_PROC
  if (!rst_n) begin
    r_refclk_req_p2 <= #TP 1'b0;
    r_pclk_off_ack  <= #TP 1'b0;
  end else begin
    r_refclk_req_p2 <= #TP s_refclk_req_p2;
    r_pclk_off_ack  <= #TP pclk_off_ack;
  end
end : refclk_r_PROC

`endif // !GPHY_PIPE43_SUPPORT


reg phy_mac_pclkack_n_d;
always @(posedge clk or negedge rst_n)
begin
   if (!rst_n) begin
      phy_mac_pclkack_n_d <= #TP 1'b0;
   end else begin
      phy_mac_pclkack_n_d <= #TP phy_mac_pclkack_n;
   end
end

assign phy_mac_pclkack_n_posedge = phy_mac_pclkack_n && !phy_mac_pclkack_n_d;
assign phy_mac_pclkack_n_negedge = !phy_mac_pclkack_n && phy_mac_pclkack_n_d;

// =============================================================================
// set a flag when there is a request to turn off the pclk
// =============================================================================
reg pending_pclkreq_n;
always @(posedge clk or negedge rst_n)
begin
   if (!rst_n)                        pending_pclkreq_n <= #TP 0; else
   if (|mac_phy_pclkreq_n )           pending_pclkreq_n <= #TP 1; else
   if (phy_mac_pclkack_n_negedge 
        `ifndef GPHY_PIPE43_SUPPORT 
           || !r_refclk_req_p2
        `endif  )                     pending_pclkreq_n <= #TP 0; else
                                      pending_pclkreq_n <= #TP pending_pclkreq_n;
end

assign rx_clock_off    = (phy_mac_pclkack_n && |mac_phy_pclkreq_n) ||(mac_phy_powerdown inside { `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON});
assign pclk_off_req    = pclk_off_p1_tmp || pclk_off_p2 || lane_disabled;
assign rate_change_req = rate_change_req_int || lane_disabled;



// if there was a request to turn off pclk (not implicit turn off via P2) then
// propagate the PMA acknowledgment pclk_off_ack to the upper layers as
// phy_mac_pclkack_n (NOTE: we do change polarity here)
assign phy_mac_pclkack_n = (pending_pclkreq_n) ? pclk_off_ack : 1'b0;

wire int_lane_disabled;
assign int_lane_disabled = serdes_arch ? serdes_pipe_turnoff_lanes : mac_phy_txelecidle & mac_phy_txcompliance;

// compute lane disable only in P1
always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
     lane_disabled <= #TP 1'b0;
  else if (int_lane_disabled & sdm_sds_powerdown inside {`GPHY_PDOWN_P1, `GPHY_PDOWN_P0} ) 
      lane_disabled <= #TP 1'b1;
  else if (!int_lane_disabled & sdm_sds_powerdown inside {`GPHY_PDOWN_P1})
      lane_disabled <= #TP 1'b0;
  else
      lane_disabled <= #TP lane_disabled;     
end



// =============================================================================
// PHY to MAC Outputs
// =============================================================================
//assign phy_mac_rxelecidle   = sds_sdm_rxelecidle; // asynchronous pass-through, in case we don't have any clock

always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        phy_mac_phystatus       <= #TP 1'b1;    // Power on is high
        phy_mac_rxdata          <= #TP 0;
        phy_mac_rxdatak         <= #TP 1'b0;
        int_phy_mac_rxdatavalid <= #TP 0;
        int_phy_mac_rxvalid     <= #TP 1'b0;
        phy_mac_rxstatus        <= #TP 3'b0;
        sdm_sds_rate            <= #TP 0;
        elasbuf_rxskipadded_d   <= #TP 1'b0;
        elasbuf_rxskipremoved_d <= #TP 1'b0;
        elasbuf_rxskipadded_dd  <= #TP 1'b0;
        elasbuf_rxskipremoved_dd<= #TP 1'b0;
        phy_mac_rxstandbystatus <= #TP 1'b1;
        phy_mac_pclkchangeok    <= #TP 1'b0;
        skp_broken_d            <= #TP 1'b0;
        skp_broken_dd           <= #TP 1'b0;
    end else begin
        sdm_sds_rate             <= #TP mac_phy_rate;
        phy_mac_rxstandbystatus <= #TP psfsm_rxstandby_status;
    if (!lane_disabled) begin
        phy_mac_phystatus       <= #TP psfsm_phystatus;
        phy_mac_rxdata          <= #TP dec8b10b_rxdata;                                // Simple registration
        phy_mac_rxdatak         <= #TP dec8b10b_rxdatak;                               // Simple registration
        int_phy_mac_rxvalid     <= #TP dec8b10b_rxdata_dv;                             // Simple registration
        int_phy_mac_rxdatavalid <= #TP sdm_sds_rate > 1 ? dec8b10b_rxdatavalid & dec8b10b_rxdata_dv : 
                                                          dec8b10b_rxdatavalid; 

        phy_mac_rxstatus        <= #TP pipe_encode_rxstatus(
                                            sdm_sds_txdetectrx,
                                            psfsm_phystatus,
                                            skp_broken_dd,
                                            sds_sdm_rxdetected,
                                            dec8b10b_rxdisperror,
                                            dec8b10b_rxcodeerror,
                                            elasbuf_rxunderflow,
                                            elasbuf_rxoverflow,
                                            elasbuf_rxskipadded_dd,
                                            elasbuf_rxskipremoved_dd);

        elasbuf_rxskipadded_d    <= #TP elasbuf_rxskipadded;
        elasbuf_rxskipremoved_d  <= #TP elasbuf_rxskipremoved;
        elasbuf_rxskipadded_dd   <= #TP elasbuf_rxskipadded_d;
        elasbuf_rxskipremoved_dd <= #TP elasbuf_rxskipremoved_d;
        skp_broken_d             <= #TP skp_broken;
        skp_broken_dd            <= #TP skp_broken_d;
        // This is for pclk as input handshake

       `ifdef GPHY_PIPE_PCLK_MODE_1
        if (!phy_mac_pclkchangeok)
            phy_mac_pclkchangeok <= #TP ((mac_phy_pclk_rate != sdm_sds_pclk_rate) 
                                         || ((sdm_sds_rate != sds_sdm_curr_rate) && (`GPHY_PIPE_OPTIONAL_PCLKCHANGE_HS == 1))
                                        ) && pclkchangeok_assert_timer_exp && !pclkchangeok_assert_timer_start;
        else
           if (phy_mac_phystatus)
            phy_mac_pclkchangeok <= #TP 1'b0;   
       `else
        phy_mac_pclkchangeok <= #TP 0;
       `endif // GPHY_PIPE_PCLK_MODE_1
     end else begin // if lane is disabled gate the outputs
        phy_mac_phystatus       <= #TP 1'b0;
        phy_mac_rxdata          <= #TP 8'b0;                                // Simple registration
        phy_mac_rxdatak         <= #TP 1'b0;                                // Simple registration
        int_phy_mac_rxvalid     <= #TP 1'b0;                                // Simple registration
        phy_mac_rxstatus        <= #TP 3'b0;
        elasbuf_rxskipadded_d   <= #TP 1'b0;
        elasbuf_rxskipremoved_d <= #TP 1'b0;
        elasbuf_rxskipadded_dd   <= #TP 1'b0;
        elasbuf_rxskipremoved_dd <= #TP 1'b0;
        phy_mac_pclkchangeok     <= #TP 1'b0;
     end      
    end

always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        phy_mac_rxstartblock   <= #TP 0;
        phy_mac_rxsynchdr      <= #TP 0;
    end else begin
        phy_mac_rxstartblock   <= #TP    dec8b10b_rxdata_dv   & dec8b10b_rxstartblock;
        phy_mac_rxsynchdr      <= #TP {2{dec8b10b_rxdata_dv}} & dec8b10b_rxsynchdr;
    end

// =============================================================================
// SDM to SerDes Outputs
// =============================================================================

always @(posedge clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       sdm_sds_pclk_rate       <= #TP mac_phy_pclk_rate;
    end else begin
       sdm_sds_pclk_rate       <= #TP !pclk_mode_input  ?  mac_phy_pclk_rate : 
                                      (psfsm_state == S_RATE && lock_posedge) ? mac_phy_pclk_rate : sdm_sds_pclk_rate;   
    end
end


always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        sdm_sds_txdata          <= #TP 8'b0;
        sdm_sds_txdatak         <= #TP 1'b0;
        sdm_sds_loopback        <= #TP 1'b0;
        sdm_sds_txcompliance    <= #TP 1'b0;
        p2p_txcompliance        <= #TP 1'b0;
        sdm_sds_rxpolarity      <= #TP 1'b0;
        sdm_sds_txerror         <= #TP 1'b0;
        mac_phy_txelecidle_d    <= #TP 1'b1;
        mac_phy_txelecidle_d2   <= #TP 1'b1;
        sdm_sds_rxstandby       <= #TP 1'b1;
        sds_sdm_curr_rate       <= #TP 3'b0;
    end
    else begin
        sdm_sds_txdata          <= #TP mac_phy_txdata;
        sdm_sds_txdatak         <= #TP mac_phy_txdatak;
        sdm_sds_txdatavalid     <= #TP mac_phy_txdatavalid;
         
        sds_sdm_curr_rate       <= #TP (psfsm_state == S_RATE && lock_posedge) ? mac_phy_rate : sds_sdm_curr_rate;        
        sdm_sds_txstartblock    <= #TP mac_phy_txstartblock;
        sdm_sds_txsynchdr       <= #TP mac_phy_txsynchdr;
        sdm_sds_loopback        <= #TP (mac_phy_powerdown == `GPHY_PDOWN_P0 && mac_phy_txdetectrx_loopback & !mac_phy_txelecidle_d); // Decoded per PIPE
        sdm_sds_txcompliance    <= #TP mac_phy_txcompliance;
        p2p_txcompliance        <= #TP sdm_sds_txcompliance;
        sdm_sds_rxpolarity      <= #TP mac_phy_rxpolarity;
        sdm_sds_txerror         <= #TP 1'b0;                                           // Not supported by PIPE
        sdm_sds_rxstandby       <= #TP mac_phy_rxstandby;
        mac_phy_txelecidle_d    <= #TP mac_phy_txelecidle;
        mac_phy_txelecidle_d2   <= #TP mac_phy_txelecidle_d;        
    end


wire state_aliasing;
assign state_aliasing = ((`GPHY_PDOWN_P1_CPM == `GPHY_PDOWN_P1_1) || (`GPHY_PDOWN_P1_CPM == `GPHY_PDOWN_P1_2)) ? 1'b1 : 1'b0;

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)                    P11_to_P1CPM   <= #TP 1'b0;
    else if (sdm_sds_powerdown_reg == `GPHY_PDOWN_P1_CPM && sdm_sds_powerdown inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2} && !state_aliasing) 
                                   P11_to_P1CPM   <= #TP 1'b1;   
   `ifdef GPHY_PIPE43_ASYNC_HS_BYPASS
    else if (sdm_sds_powerdown_reg != `GPHY_PDOWN_P1_CPM)  P11_to_P1CPM   <= #TP 1'b0; 
   `else
    else if (asyncpowerchangeack)  P11_to_P1CPM   <= #TP 1'b0; 
   `endif //GPHY_PIPE43_ASYNC_HS_BYPASS
    else                           P11_to_P1CPM   <= #TP P11_to_P1CPM;
end  

// generate random P1X_to_P1 exit mode internaly 
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)                    randomize_P1X_to_P1   <= #TP 1'b0;
    else if (sdm_sds_powerdown != sdm_sds_powerdown_reg && sdm_sds_powerdown_reg inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2}) 
                                   randomize_P1X_to_P1   <= #TP $urandom_range(0,1);   
end    
   
// =============================================================================
// SDM to SerDes Outputs on AUX Clock.  Select inputs from PMC if in P2
// state and the PhyStatus signal has "acked" the transition... i.e. clock
// could go away for the MAC signals.
// =============================================================================
always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        sdm_sds_txdetectrx      <= #TP 1'b0;
        p2p_txdetectrx          <= #TP 1'b0;
        sdm_sds_txelecidle      <= #TP 1'b1;
        sdm_sds_beacongen       <= #TP 1'b0;
        sdm_sds_turn_off        <= #TP 1'b0;
    end
    else begin
        sdm_sds_txdetectrx      <= #TP (mac_phy_txdetectrx_loopback & mac_phy_powerdown == `GPHY_PDOWN_P1 );
        p2p_txdetectrx          <= #TP sdm_sds_txdetectrx;
        sdm_sds_txelecidle      <= #TP mac_phy_txelecidle;
        sdm_sds_beacongen       <= #TP (sdm_sds_current_powerdown inside {`GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON}  & !mac_phy_txelecidle_d);             // Decoded per PIPE
        sdm_sds_turn_off        <= #TP (mac_phy_txcompliance & mac_phy_txelecidle);
    end

// =============================================================================
// Registration of misc inputs on the PIPE+ interface which are not direct pass-
// throughs (i.e. registered below).  Needed for PS FSM so on AUX clock.
// =============================================================================
always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        sdm_sds_powerdown_reg   <= #TP `GPHY_PDOWN_P1;
        sdm_sds_powerdown       <= #TP `GPHY_PDOWN_P1;
        p2p_reset_n_reg         <= #TP 1'b0;
        p2p_reset_n             <= #TP 1'b0;
        p2p_serdes_ready        <= #TP 1'b0;
    end else
    begin
        sdm_sds_powerdown_reg   <= #TP mac_phy_powerdown;
        sdm_sds_powerdown       <= #TP sdm_sds_powerdown_reg;
        p2p_reset_n_reg         <= #TP rst_n;
        p2p_reset_n             <= #TP p2p_reset_n_reg;
        p2p_serdes_ready        <= #TP sds_sdm_ready;
    end

assign sdm_sds_reset_n       = (p2p_reset_n & rst_n);                          // merge in the core reset
assign sdm_sds_pulse_reset_n = ((p2p_reset_n_reg | (~p2p_reset_n)) & rst_n);   // generate single cycle reset pulse for SerDes; merged w/ core reset
assign p2p_pulse_txdetectrx  = (~p2p_txdetectrx & sdm_sds_txdetectrx);         // generate edge for psfsm

// Set negative disparity for compliance pattern
assign sdm_sds_set_disp = ((~p2p_txcompliance & sdm_sds_txcompliance) & sdm_sds_reset_n) | mac_phy_txelecidle_d2; // merge in primary reset


// =============================================================================
// instantiate the different timers used to implement phystatus latency (i.e.
// how long will it take for the PHY to answer a given request)
//
// Timers are triggered when entering relevant states of the PSFSM
// =============================================================================

// Emulate receiver detection processing time
// start the receiver detect timer when entering S_RXDET
assign rxdet_timer_start = (psfsm_state != psfsm_state_prev && psfsm_state == S_RXDET);

DWC_pcie_gphy_timer #(
  .WD        (5),
  .TP        (TP)
) rxdet_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (rxdet_timer_start),
  .thr       (5'h10),
  .rnd_en    (1'b0),
  .rnd_lo    (5'b0),
  .rnd_hi    (5'b0),

  .expired   (rxdet_timer_exp)
);


// Emulate processing time to ack transitions in and out of P0/P0s
// TODO make random
localparam PSDET_TC = 7'h04;
wire [6:0] psdet_timer_thr;

// start the power state detect timer when entering S_PSDET
assign psdet_timer_start = (psfsm_state != psfsm_state_prev && psfsm_state == S_PSDET);

// set the fixed threshold
assign psdet_timer_thr = sdm_sds_rate==0 ? PSDET_TC   :
                         sdm_sds_rate==1 ? PSDET_TC*2 :
                         sdm_sds_rate==2 ? PSDET_TC*4 : 
                         sdm_sds_rate==3 ? PSDET_TC*8 :
                         sdm_sds_rate==4 ? PSDET_TC*16 :
                                           PSDET_TC*32;

DWC_pcie_gphy_timer #(
  .WD        (7),
  .TP        (TP)
) psdet_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (psdet_timer_start),
  .thr       (psdet_timer_thr),
  .rnd_en    (1'b0),
  .rnd_lo    (7'b0),
  .rnd_hi    (7'b0),

  .expired   (psdet_timer_exp)
);


// Emulate processing time to ack transitions in and out of P1
wire [12:0] p1det_timer_thr;    // fixed threshold
wire [12:0] p1det_timer_lo_rnd_prescale; // low limit for randomization - before scaling
wire [12:0] p1det_timer_hi_rnd_prescale; // high limit for randomization - before scaling
wire [12:0] p1det_timer_lo_rnd; // low limit for randomization
wire [12:0] p1det_timer_hi_rnd; // high limit for randomization
wire [12:0] p1det_timer_thr_sel;

// start the power state detect timer when entering S_P1DET
assign p1det_timer_start = (psfsm_state != psfsm_state_prev && psfsm_state inside {S_P1DET, S_P1X_P1});

// fixed threshold (used when randomization is off) is same as P0s
localparam P1DET_TC = 13'h4;
assign p1det_timer_thr_sel = (p1_phystatus_time_load_en) ? p1_phystatus_time : P1DET_TC;

assign p1det_timer_thr = sdm_sds_rate==0 ? p1det_timer_thr_sel :
                         sdm_sds_rate==1 ? p1det_timer_thr_sel*2 :
                         sdm_sds_rate==2 ? p1det_timer_thr_sel*4 : 
                         sdm_sds_rate==3 ? p1det_timer_thr_sel*8 :
                         sdm_sds_rate==4 ? p1det_timer_thr_sel*16 :
                                           p1det_timer_thr_sel*32;

// ranges for randomization
assign p1det_timer_lo_rnd_prescale = (p1_random_range == 0) ? 1  :
                                     (p1_random_range == 1) ? 8  :
                                     (p1_random_range == 2) ? 13 :
                                     (p1_random_range == 3) ? 50 : 450;

assign p1det_timer_hi_rnd_prescale = (p1_random_range == 0) ? 5  :
                                     (p1_random_range == 1) ? 12  :
                                     (p1_random_range == 2) ? 37 :
                                     (p1_random_range == 3) ? 200 : 550;

// apply rate dependent scaling to get absolute times
// ranges are expressed in Gen1 clock cycles (4ns), so need to scale
// for higher rates
assign p1det_timer_lo_rnd = sdm_sds_rate==0 ? p1det_timer_lo_rnd_prescale   :
                            sdm_sds_rate==1 ? p1det_timer_lo_rnd_prescale*2 :
                            sdm_sds_rate==2 ? p1det_timer_lo_rnd_prescale*4 :
                            sdm_sds_rate==3 ? p1det_timer_lo_rnd_prescale*8 :
                            sdm_sds_rate==4 ? p1det_timer_lo_rnd_prescale*16 : 
                                              p1det_timer_lo_rnd_prescale*32;

assign p1det_timer_hi_rnd = sdm_sds_rate==0 ? p1det_timer_hi_rnd_prescale   :
                            sdm_sds_rate==1 ? p1det_timer_hi_rnd_prescale*2 :
                            sdm_sds_rate==2 ? p1det_timer_hi_rnd_prescale*4 :
                            sdm_sds_rate==3 ? p1det_timer_hi_rnd_prescale*8 :
                            sdm_sds_rate==4 ? p1det_timer_hi_rnd_prescale*16 :
                                              p1det_timer_hi_rnd_prescale*32;


DWC_pcie_gphy_timer #(
  .WD        (13),
  .TP        (TP)
) p1det_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (p1det_timer_start),
  .thr       (p1det_timer_thr),
  .rnd_en    (powerdown_random_phystatus_en),
  .rnd_lo    (p1det_timer_lo_rnd),
  .rnd_hi    (p1det_timer_hi_rnd),

  .expired   (p1det_timer_exp)
);



// Emulate processing time to ack transitions in and out of P1.CPM
// TODO make random
// NOTE this timer needs to be always smaller than the pclk turnoff
// timeout generated in DWC_pcie_gphy_pll, because phystus should
// be returned prior to pclk removal
localparam P1CPM_TC = 5'h03;
wire [4:0] p1cpm_timer_thr;
wire p1cpm_timer_start;
wire p1cpm_timer_exp;

// start the power state detect timer when entering S_P1CPM
assign p1cpm_timer_start = (psfsm_state != psfsm_state_prev && psfsm_state == S_P1CPM);

// set the fixed threshold
assign p1cpm_timer_thr = sdm_sds_rate==0 ? P1CPM_TC   :
                         sdm_sds_rate==1 ? P1CPM_TC*2 :
                         sdm_sds_rate==2 ? P1CPM_TC*4 : 
                         sdm_sds_rate==3 ? P1CPM_TC*8 :
                         sdm_sds_rate==4 ? P1CPM_TC*16 :
                                           P1CPM_TC*32;

                         
DWC_pcie_gphy_timer #(
  .WD        (5),
  .TP        (TP)
) p1cpm_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (p1cpm_timer_start),
  .thr       (p1cpm_timer_thr),
  .rnd_en    (1'b0),
  .rnd_lo    (5'b0),
  .rnd_hi    (5'b0),

  .expired   (p1cpm_timer_exp)
);

// Emulate processing time to ack a rate change
// set the fixed threshold in ns
// we need to exid the 800ns timer
localparam MIN_RATE_PHYSTATUS_RET_DLY = 16;
localparam MAX_RATE_PHYSTATUS_RET_DLY = 800;

wire [12:0] rate_timer_thr;
wire [12:0] rate_timer_lo_rnd; // low limit for randomization - before scaling
wire [12:0] rate_timer_hi_rnd; // high limit for randomization - before scaling
wire rate_timer_start;
wire rate_timer_exp;

//we decode tx_rate clk period in ns
realtime tx_rate_speed_dec;
assign tx_rate_speed_dec = `ifdef GPHY_ESM_SUPPORT
                            (esm_enable && esm_data_rate0 == `GPHY_ESM_RATE0_8GT   && mac_phy_rate === 2) ? 0.5  :
                            (esm_enable && esm_data_rate0 == `GPHY_ESM_RATE0_16GT  && mac_phy_rate === 2) ? 1    :
                            (esm_enable && esm_data_rate1 == `GPHY_ESM_RATE1_20GT  && mac_phy_rate === 3) ? 0.64 :
                            (esm_enable && esm_data_rate1 == `GPHY_ESM_RATE1_25GT  && mac_phy_rate === 3) ? 0.32 :
                            `endif //GPHY_ESM_SUPPORT
                            (mac_phy_rate === 5)                                                     ? 0.125 :
                            (mac_phy_rate === 4)                                                     ? 0.25  :
                            (mac_phy_rate === 3)                                                     ? 0.5   :
                            (mac_phy_rate === 2)                                                     ? 1     :
                            (mac_phy_rate === 1)                                                     ? 2     :  4; 


// start the power state detect timer when changing the rate
// when we are in mode pclk as input, phystatus should be returned only after signal mac_phy_pclkchangeack is received
// we start timer to count for phystatus after mac_phy_pclkchangeack is received
assign rate_timer_start = (psfsm_state == S_RATE  && lock_posedge);
                          
assign rate_timer_lo_rnd = MIN_RATE_PHYSTATUS_RET_DLY/tx_rate_speed_dec;
assign rate_timer_hi_rnd = MAX_RATE_PHYSTATUS_RET_DLY/tx_rate_speed_dec;
assign rate_timer_thr    = MIN_RATE_PHYSTATUS_RET_DLY;

DWC_pcie_gphy_timer #(
  .WD        (13),
  .TP        (TP)
) rate_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (rate_timer_start),
  .thr       (rate_timer_thr),
  .rnd_en    (rate_random_phystatus_en),
  .rnd_lo    (rate_timer_lo_rnd),
  .rnd_hi    (rate_timer_hi_rnd),

  .expired   (rate_timer_exp)
);


// =============================================================================
// Rxstandby changes
// Emulate processing time to ack a rxstandby change
localparam MIN_STANDBY_STATUS_DLY = 2;
localparam MAX_STANDBY_STATUS_DLY = 15;

wire       rxstandby_timer_start;
wire       rxstandby_timer_exp;
wire [8:0] rxstandby_timer_thr;
wire [8:0] rxstandby_timer_lo_rnd; // low limit for randomization - before scaling
wire [8:0] rxstandby_timer_hi_rnd; // high limit for randomization - before scaling
wire       rxstandby_timer_running;
reg        rxstandby_timer_running_r;
wire       rxstandby_timer_end;

reg   mac_phy_rxstandby_r;
wire  rxstandby_rise;
wire  rxstandby_fall;

always @(posedge clk or negedge rst_n)
begin
   if (!rst_n) mac_phy_rxstandby_r <= #TP mac_phy_rxstandby; else
               mac_phy_rxstandby_r <= #TP mac_phy_rxstandby;
end

always @(posedge clk or negedge rst_n)
begin
   if (!rst_n) rxstandby_timer_running_r <= #TP 1'b0; else
               rxstandby_timer_running_r <= #TP rxstandby_timer_running;
end

assign rxstandby_rise = mac_phy_rxstandby && !mac_phy_rxstandby_r;
assign rxstandby_fall = !mac_phy_rxstandby && mac_phy_rxstandby_r;
assign rxstandby_timer_running = rxstandby_timer_start || !rxstandby_timer_exp;
assign rxstandby_timer_end = !rxstandby_timer_running & rxstandby_timer_running_r;

// start the rxstandby timer when a change on rx_standby it is seen
assign rxstandby_timer_start = (rxstandby_rise || rxstandby_fall);
assign rxstandby_timer_lo_rnd = MIN_STANDBY_STATUS_DLY;
assign rxstandby_timer_hi_rnd = MAX_STANDBY_STATUS_DLY;
assign rxstandby_timer_thr    = MIN_STANDBY_STATUS_DLY;


DWC_pcie_gphy_timer #(
  .WD        (9),
  .TP        (TP)
) rxstandby_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (rxstandby_timer_start),
  .thr       (rxstandby_timer_thr),
  .rnd_en    (1'b1),
  .rnd_lo    (rxstandby_timer_lo_rnd),
  .rnd_hi    (rxstandby_timer_hi_rnd),

  .expired   (rxstandby_timer_exp)
);




// start the power state detect timer when asserting phystatus at P2 entry
localparam MIN_P2_PHYSTATUS_RISE_DLY = 10;
localparam MAX_P2_PHYSTATUS_RISE_DLY = 30;

wire [12:0] p2_phystatus_rise_timer_thr;
wire [12:0] p2_phystatus_rise_timer_lo_rnd;
wire [12:0] p2_phystatus_rise_timer_hi_rnd;
wire        p2_phystatus_rise_timer_start;
wire        p2_phystatus_rise_timer_exp;

assign p2_phystatus_rise_timer_start  = (ps_change && in_p2);
assign p2_phystatus_rise_timer_lo_rnd = MIN_P2_PHYSTATUS_RISE_DLY;
assign p2_phystatus_rise_timer_hi_rnd = MAX_P2_PHYSTATUS_RISE_DLY;
assign p2_phystatus_rise_timer_thr    = p2_random_phystatus_rise_load_en ? p2_random_phystatus_rise_value : MAX_P2_PHYSTATUS_RISE_DLY;

DWC_pcie_gphy_timer #(
  .WD        (13),
  .TP        (TP)
) p2_entry_phystatus_rise_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (p2_phystatus_rise_timer_start),
  .thr       (p2_phystatus_rise_timer_thr),
  .rnd_en    (p2_phystatus_rise_random_en),
  .rnd_lo    (p2_phystatus_rise_timer_lo_rnd),
  .rnd_hi    (p2_phystatus_rise_timer_hi_rnd),

  .expired   (p2_phystatus_rise_timer_exp)
);

// start the power state detect timer when asserting phystatus at P2 entry
localparam MIN_P2_PHYSTATUS_FALL_DLY = 10;
localparam MAX_P2_PHYSTATUS_FALL_DLY = 50;

wire [12:0] p2_phystatus_fall_timer_thr;
wire [12:0] p2_phystatus_fall_timer_lo_rnd;
wire [12:0] p2_phystatus_fall_timer_hi_rnd;
wire        p2_phystatus_fall_timer_start;
wire        p2_phystatus_fall_timer_exp;

assign p2_phystatus_fall_timer_start  = (in_p2 && lock_negedge);
assign p2_phystatus_fall_timer_lo_rnd = MIN_P2_PHYSTATUS_FALL_DLY;
assign p2_phystatus_fall_timer_hi_rnd = MAX_P2_PHYSTATUS_FALL_DLY;
assign p2_phystatus_fall_timer_thr    = p2_random_phystatus_fall_load_en ? p2_random_phystatus_fall_value : MAX_P2_PHYSTATUS_FALL_DLY;

DWC_pcie_gphy_timer #(
  .WD        (13),
  .TP        (TP)
) p2_entry_phystatus_fall_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (p2_phystatus_fall_timer_start),
  .thr       (p2_phystatus_fall_timer_thr),
  .rnd_en    (p2_phystatus_fall_random_en),
  .rnd_lo    (p2_phystatus_fall_timer_lo_rnd),
  .rnd_hi    (p2_phystatus_fall_timer_hi_rnd),
  .expired   (p2_phystatus_fall_timer_exp)
);

//----------------------------------------------------------
// Emulate processing time to ack a p1x change by phystatus assertion
// set the fixed threshold in ns
localparam MIN_P1X_PHYSTATUS_RET_DLY = 16;
localparam MAX_P1X_PHYSTATUS_RET_DLY = 500;

wire [12:0] p1x_timer_thr;
wire [12:0] p1x_timer_lo_rnd; // low limit for randomization - before scaling
wire [12:0] p1x_timer_hi_rnd; // high limit for randomization - before scaling

wire p1x_timer_exp;
wire p1x_timer_start;



// start the power state detect timer when changing the rate
assign p1x_timer_start = (sdm_sds_powerdown_reg inside {4'b0101, 4'b0110} && sdm_sds_powerdown == 4'b100);
assign p1x_timer_lo_rnd = MIN_P1X_PHYSTATUS_RET_DLY/tx_rate_speed_dec;
assign p1x_timer_hi_rnd = MAX_P1X_PHYSTATUS_RET_DLY/tx_rate_speed_dec;
assign p1x_timer_thr    = MIN_P1X_PHYSTATUS_RET_DLY;

DWC_pcie_gphy_timer #(
  .WD        (13),
  .TP        (TP)
) p1x_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (p1x_timer_start),
  .thr       (p1x_timer_thr),
  .rnd_en    (1'b1),
  .rnd_lo    (p1x_timer_lo_rnd),
  .rnd_hi    (p1x_timer_hi_rnd),

  .expired   (p1x_timer_exp)
);


//----------------------------------------------------------
// Emulate processing time to ack a p1x change by phystatus assertion
// set the fixed threshold in ns
reg asyncpowerchangeack_r;
wire asyncpowerchangeack_rise_edge;
always @(posedge clk or negedge rst_n)
begin
   if (!rst_n)
   begin
     asyncpowerchangeack_r    <= #TP 1'b0;
   end else begin
     asyncpowerchangeack_r    <= #TP asyncpowerchangeack;
   end
end

assign asyncpowerchangeack_rise_edge = asyncpowerchangeack && !asyncpowerchangeack_r;


localparam MIN_P1X_PHYSTATUS_DEASSERT_DLY = 16;
localparam MAX_P1X_PHYSTATUS_DEASSERT_DLY = 500;

wire [12:0] p1x_phystatus_deassert_timer_thr;
wire [12:0] p1x_phystatus_deassert_timer_lo_rnd; // low limit for randomization - before scaling
wire [12:0] p1x_phystatus_deassert_timer_hi_rnd; // high limit for randomization - before scaling

wire p1x_phystatus_deassert_timer_exp;
wire p1x_phystatus_deassert_timer_start;



// start the power state detect timer when changing the rate
assign p1x_phystatus_deassert_timer_start = (sdm_sds_powerdown inside {4'b0101, 4'b0110} && asyncpowerchangeack_rise_edge);
assign p1x_phystatus_deassert_timer_lo_rnd = MIN_P1X_PHYSTATUS_DEASSERT_DLY/tx_rate_speed_dec;
assign p1x_phystatus_deassert_timer_hi_rnd = MAX_P1X_PHYSTATUS_DEASSERT_DLY/tx_rate_speed_dec;
assign p1x_phystatus_deassert_timer_thr    = MIN_P1X_PHYSTATUS_DEASSERT_DLY;

DWC_pcie_gphy_timer #(
  .WD        (13),
  .TP        (TP)
) p1x_phystatus_deassert_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (p1x_phystatus_deassert_timer_start),
  .thr       (p1x_phystatus_deassert_timer_thr),
  .rnd_en    (1'b1),
  .rnd_lo    (p1x_phystatus_deassert_timer_lo_rnd),
  .rnd_hi    (p1x_phystatus_deassert_timer_hi_rnd),

  .expired   (p1x_phystatus_deassert_timer_exp)
);

// -----------------------------------------------------------------------

localparam MIN_PCLKCHANGEOK_ASSERT_DLY = 16;
localparam MAX_PCLKCHANGEOK_ASSERT_DLY = 100;

wire [12:0] pclkchangeok_assert_timer_thr;
wire [12:0] pclkchangeok_assert_timer_lo_rnd; // low limit for randomization - before scaling
wire [12:0] pclkchangeok_assert_timer_hi_rnd; // high limit for randomization - before scaling

reg pclk_rate_change_r;

always @(posedge clk or negedge rst_n)
begin
   if (!rst_n)   pclk_rate_change_r <= #TP 1'b0;
   else          pclk_rate_change_r <= #TP pclk_rate_change;
end

wire pclk_rate_change_rise;
assign pclk_rate_change_rise = pclk_rate_change && !pclk_rate_change_r; 


wire rate_change_rise;
assign rate_change_rise =  mac_phy_rate !== sdm_sds_rate;
                             
                                

// start the power state detect timer when changing the rate
assign pclkchangeok_assert_timer_start  = pclk_rate_change_rise
                                       || (rate_change_rise && `GPHY_PIPE_OPTIONAL_PCLKCHANGE_HS == 1);


assign pclkchangeok_assert_timer_lo_rnd = MIN_PCLKCHANGEOK_ASSERT_DLY/tx_rate_speed_dec;
assign pclkchangeok_assert_timer_hi_rnd = MAX_PCLKCHANGEOK_ASSERT_DLY/tx_rate_speed_dec;
assign pclkchangeok_assert_timer_thr    = MIN_PCLKCHANGEOK_ASSERT_DLY;



DWC_pcie_gphy_timer #(
  .WD        (13),
  .TP        (TP)
) pclkchangeok_assert_timer (
  .clk       (clk),
  .rst_n     (rst_n),

  .start     (pclkchangeok_assert_timer_start),
  .thr       (pclkchangeok_assert_timer_thr),
  .rnd_en    (1'b1),
  .rnd_lo    (pclkchangeok_assert_timer_lo_rnd),
  .rnd_hi    (pclkchangeok_assert_timer_hi_rnd),

  .expired   (pclkchangeok_assert_timer_exp)
);



// =============================================================================
// PHY Status Finite State Machine (PSFSM)
//
// This FSM implements all the PIPE handshakes (receiver detection, powerdown
// and rate transitions) in the txclk domain
//
// =============================================================================
assign ps_change   = (sdm_sds_powerdown != sdm_sds_powerdown_reg);    // detect power state change
assign in_p2       = (sdm_sds_powerdown_reg  inside {`GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON});       // indication we're in P2
assign rate_change = (sdm_sds_rate != sds_sdm_curr_rate);
assign pclk_rate_change = (mac_phy_pclk_rate != sdm_sds_pclk_rate);


// when we have the overide we need to keep the req to turn off pclk in p1
// in 1 for a longer time to connect with P2 pclk off

always @(posedge clk or negedge rst_n)
begin
   if (!rst_n)
   begin
     pclk_off_p1_d    <= #TP 5'b0;
   end else begin
     pclk_off_p1_d[0] <= #TP |mac_phy_pclkreq_n;
     pclk_off_p1_d[1] <= #TP pclk_off_p1_d[0];
     pclk_off_p1_d[2] <= #TP pclk_off_p1_d[1];
     pclk_off_p1_d[3] <= #TP pclk_off_p1_d[2];
     pclk_off_p1_d[4] <= #TP pclk_off_p1_d[3];
     pclk_off_p1_d[5] <= #TP pclk_off_p1_d[4];
   end
end

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin
      psfsm_state_prev <= #TP S_IDLE;
    end else begin
      psfsm_state_prev <= #TP psfsm_state;
    end
end

wire phystatus_negedge;
assign phystatus_negedge = !psfsm_phystatus && phy_mac_phystatus;

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin
     sdm_sds_current_powerdown <= #TP `GPHY_PDOWN_P1;
    end else begin
      if (sdm_sds_current_powerdown != sdm_sds_powerdown_reg)  begin
         if (lane_disabled) 
             sdm_sds_current_powerdown <= #TP sdm_sds_powerdown_reg; 
         else if (sdm_sds_powerdown_reg inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2, `GPHY_PDOWN_P1_CPM} && asyncpowerchangeack)
             sdm_sds_current_powerdown <= #TP sdm_sds_powerdown_reg;
         else if (phystatus_negedge)
             sdm_sds_current_powerdown <= #TP sdm_sds_powerdown_reg;
         else 
             sdm_sds_current_powerdown <= #TP sdm_sds_current_powerdown;    
      end
    end     
end


assign pclk_stable = p2p_serdes_ready & lock & !(mac_phy_pclk_rate != sdm_sds_pclk_rate) & !(sdm_sds_rate != sds_sdm_curr_rate) & !(phy_mac_pclkchangeok && !mac_phy_pclkchangeack);


always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin
        psfsm_phystatus                     <= #TP 1'b1;             // asserted on power on reset
        psfsm_state                         <= #TP S_IDLE;
        rate_change_req_int                 <= #TP 1'b0;
        psfsm_rxstandby_status              <= #TP 1'b1;
    end else if (!sdm_sds_pulse_reset_n) begin
        psfsm_phystatus                     <= #TP 1'b1;             // asserted on power on reset
        psfsm_state                         <= #TP S_IDLE;
        rate_change_req_int                 <= #TP 1'b0;
        psfsm_rxstandby_status              <= #TP 1'b1;
      end else
    case (psfsm_state)
        S_IDLE:     begin
                        pclk_off_p2             <= #TP 1'b0;
                        pclk_off_p1_tmp         <= #TP 1'b0;
                        if ((p2p_serdes_ready & lock & (phy_reg_localfslf_done)) | in_p2) begin
                            psfsm_phystatus     <= #TP in_p2;       // assert PhyStatus if P2 after reset
                            psfsm_state         <= #TP S_READY;
                        end else begin
                            psfsm_phystatus     <= #TP 1'b1;
                            psfsm_state         <= #TP S_IDLE;
                        end
                    end

        S_READY:    begin
                        psfsm_phystatus         <= #TP 1'b0;
                        pclk_off_p2             <= #TP pclk_off_p2;
                        pclk_off_p1_tmp         <= #TP |mac_phy_pclkreq_n || pclk_off_p1_d[5];
                        if (ps_change) begin
                            psfsm_state         <= #TP (sdm_sds_powerdown_reg inside { `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON})        ? S_P2_PREP : // into P2, prepare to turn off
                                                       (sdm_sds_powerdown_reg == `GPHY_PDOWN_P1 && sdm_sds_powerdown inside 
                                                                                           { `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON} ) ? S_P2_PREP : // out of P2, prepare to turn on
                                                       (sdm_sds_powerdown_reg == `GPHY_PDOWN_P1 && 
                                                        sdm_sds_powerdown inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2} &&
                                                        (P1X_to_P1_exit_mode || randomize_P1X_to_P1 ))                                  ? S_P1X_P1  :
                                                       (sdm_sds_powerdown_reg == `GPHY_PDOWN_P1)                                        ? S_P1DET   : // into P1
                                                       (sdm_sds_powerdown_reg == `GPHY_PDOWN_P1_CPM)                                    ? S_P1CPM   : // into P1.CPM
                                                       (sdm_sds_powerdown_reg inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2})              ? S_P1X     : // into P1.x
                                                                                                                                          S_PSDET;    // P0/P0s
                        end else if (p2p_pulse_txdetectrx) begin
                            psfsm_state         <= #TP S_RXDET;
                        end else if ((rate_change || ( pclk_mode_input && pclk_rate_change)) && !(mac_phy_powerdown inside {`GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON })) begin
                            psfsm_state         <= #TP S_RATE;   
                        end else if (rxstandby_rise) begin 
                            psfsm_state         <= #TP S_RXSTANDBY_ASSERT; 
                        end else if (rxstandby_fall) begin 
                            psfsm_state         <= #TP S_RXSTANDBY_DEASSERT;                                                          
                        end else begin
                            psfsm_state         <= #TP S_READY;
                        end
                    end


        S_PSDET:    begin
                        pclk_off_p2             <= #TP 1'b0;
                        pclk_off_p1_tmp         <= #TP 1'b0;
                        if (~psdet_timer_start & psdet_timer_exp) begin
                            psfsm_phystatus     <= #TP 1'b1;
                            if (rxstandby_timer_running & mac_phy_rxstandby) begin
                               // if we rxstandby timer is still runnign and rxstandby it was asserted it 
                               // means we came from S_RXSTANDBY_ASSSERT so we go back to finish handshake
                               psfsm_state         <= #TP S_RXSTANDBY_ASSERT;
                            end else if (rxstandby_timer_running & !mac_phy_rxstandby) begin
                               // if we rxstandby timer is still runnign and rxstandby it was de-asserted it 
                               // means we came from S_RXSTANDBY_DEASSSERT so we go back to finish handshake
                               psfsm_state         <= #TP S_RXSTANDBY_DEASSERT; 
                            end else begin
                               psfsm_state         <= #TP S_READY;
                               if (rxstandby_timer_end && !mac_phy_rxstandby)
                                 psfsm_rxstandby_status    <= #TP 1'b0;
                               if (rxstandby_timer_end && mac_phy_rxstandby)
                                 psfsm_rxstandby_status    <= #TP 1'b1;   
                              
                            end   
                                                       
                        end else begin
                            psfsm_phystatus     <= #TP 1'b0;
                            psfsm_state         <= #TP S_PSDET;
                            if (rxstandby_timer_end && !mac_phy_rxstandby)
                               psfsm_rxstandby_status    <= #TP 1'b0;
                            if (rxstandby_timer_end && mac_phy_rxstandby)
                               psfsm_rxstandby_status    <= #TP 1'b1;   
                              
                        end
                    end
                    

        S_P1DET:    begin
                        pclk_off_p2             <= #TP 1'b0;
                        if (~p1det_timer_start & p1det_timer_exp & ~pclk_off_ack & lock) begin
                            // return phystatus once the timer to emulate
                            // phystatus delay for this state has expired 
                            // and pclk has been restored (if coming from P1.X)
                            psfsm_phystatus     <= #TP 1'b1;
                            pclk_off_p1_tmp     <= #TP |mac_phy_pclkreq_n;
                            if (rxstandby_timer_running) begin
                               // if we rxstandby timer is still runnign it means we came from S_RXSTANDBY_ASSSERT
                               // so we go back to finish handshake
                               psfsm_state         <= #TP S_RXSTANDBY_ASSERT;
                            end else begin
                               psfsm_state         <= #TP S_READY;
                               if (rxstandby_timer_end && !mac_phy_rxstandby)
                                  psfsm_rxstandby_status    <= #TP 1'b0;
                               if (rxstandby_timer_end && mac_phy_rxstandby)
                                  psfsm_rxstandby_status    <= #TP 1'b1;  
                               
                            end   
                        end else begin
                            psfsm_phystatus     <= #TP 1'b0;
                            pclk_off_p1_tmp     <= #TP 1'b0;
                            psfsm_state         <= #TP S_P1DET;
                            if (rxstandby_timer_end)
                               psfsm_rxstandby_status    <= #TP 1'b1;
                        end
                    end
                    
        S_P1X_P1:   begin
                       pclk_off_p2         <= #TP 1'b0;
                       pclk_off_p1_tmp     <= #TP |mac_phy_pclkreq_n;
                       if (~p1det_timer_start & p1det_timer_exp & ~pclk_off_ack & lock & !pclk_mode_input) begin
                          psfsm_state         <= #TP S_READY;
                          psfsm_phystatus     <= #TP 1'b0;
                       
                       end else if (pclk_mode_input && psfsm_phystatus) begin 
                       // in pclk as input mode phystatus is just a pulse 
                          psfsm_state         <= #TP S_READY;
                          psfsm_phystatus     <= #TP 1'b0;
                       end else begin
                          // keep phystatus in 1 while timer is running
                          // and pclk has been restored (if coming from P1.X)
                          psfsm_phystatus     <= #TP 1'b1;
                          psfsm_state         <= #TP S_P1X_P1;
                       end
                    end            
                    

        S_P1CPM:    begin
                        pclk_off_p2             <= #TP 1'b0;
                        pclk_off_p1_tmp         <= #TP 1'b1;
                        if (P11_to_P1CPM) begin
                           // if there is no pclk in P1.CPM phystatus is async 
                            psfsm_phystatus     <= #TP (asyncpowerchangeack) ? 1'b0 : 1'b1;
                           // but we stay here if pclk is not yet off
                            psfsm_state         <= #TP (asyncpowerchangeack) ? S_READY : S_P1CPM;
                        end else begin
                           // if handshale ends set rx_standby_status
                           if (rxstandby_timer_end)
                               psfsm_rxstandby_status    <= #TP 1'b1;
                        
                           if ((~p1cpm_timer_start & p1cpm_timer_exp & lock && !pclk_mode_input) ||
                               (~p1cpm_timer_start & p1cpm_timer_exp & lock && pclk_mode_input && !psfsm_phystatus)) begin
                               // in P1.CPM phystatus returns when pclk is still on
                               psfsm_phystatus     <= #TP 1'b1;
                               // but we stay here if pclk is not yet off
                               psfsm_state         <= #TP (pclk_off_ack && !rxstandby_timer_running) ? S_READY :
                                                          (pclk_off_ack && rxstandby_timer_running)  ? S_RXSTANDBY_ASSERT :
                                                                                                       S_P1CPM;
                           end else begin
                              if (!pclk_mode_input)
                              begin
                                  if (pclk_off_ack) begin 
                                      // either the request was removed (what is
                                      // going on?) or pclk is finally off
                                      psfsm_phystatus     <= #TP 1'b0;
                                      psfsm_state         <= #TP rxstandby_timer_running ? S_RXSTANDBY_ASSERT : S_READY;
                                  end else begin
                                      psfsm_phystatus     <= #TP 1'b0;
                                      psfsm_state         <= #TP S_P1CPM;
                                  end
                              end else begin
                              // pclk as input mode
                                 if (psfsm_phystatus) begin
                                      psfsm_phystatus     <= #TP 1'b0;
                                      psfsm_state         <= #TP S_READY;
                                 end else begin
                                      psfsm_phystatus     <= #TP 1'b0;
                                      psfsm_state         <= #TP S_P1CPM;
                                 end     
                                      
                              end  
                           end
                        end 
                    end

        S_P1X:      begin
                        pclk_off_p2             <= #TP 1'b0;
                        pclk_off_p1_tmp         <= #TP 1'b1;
                        `ifndef GPHY_PIPE43_ASYNC_HS_BYPASS
                          // keep phystatus high until MAC asserts asyncpowerchangeack
                          if (asyncpowerchangeack && psfsm_phystatus && !p1x_phystatus_deassert_timer_start && p1x_phystatus_deassert_timer_exp) begin
                            psfsm_phystatus     <= #TP 1'b0;
                            psfsm_state         <= #TP S_READY;
                          end else begin
                            if (~p1x_timer_start && p1x_timer_exp)
                            begin
                              psfsm_phystatus     <= #TP 1'b1;
                              psfsm_state         <= #TP S_P1X;
                            end else begin
                              psfsm_phystatus     <= #TP 1'b0;
                              psfsm_state         <= #TP S_P1X;   
                            end  
                          end
                        `else
                          // when disabling the asynchronous handshake
                          // there is not much to do here
                          psfsm_phystatus     <= #TP 1'b0;
                          psfsm_state         <= #TP S_READY;
                        `endif
                    end

        S_P2_PREP:  begin
                        
                        if (P11_to_P1CPM) begin
                           psfsm_phystatus     <= #TP 1'b0;
                           psfsm_state            <= #TP S_P2;
                        end else begin    
                           if (~p2_phystatus_rise_timer_start && p2_phystatus_rise_timer_exp && mac_phy_powerdown inside { `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON}) begin
                              psfsm_phystatus     <= #TP 1'b1;
                              pclk_off_p1_tmp     <= #TP 1'b0;
                              pclk_off_p2         <= #TP !pclk_off_p2;
                              psfsm_state         <= #TP S_P2;
                           end else if (mac_phy_powerdown == `GPHY_PDOWN_P1) begin
                              psfsm_phystatus     <= #TP 1'b0;
                              pclk_off_p1_tmp     <= #TP 1'b0;
                              pclk_off_p2         <= #TP !pclk_off_p2;
                              psfsm_state         <= #TP S_P2;
                           end   
                        end
                        
                        // if handshake ends set rx_standby_status
                        if (rxstandby_timer_end)
                            psfsm_rxstandby_status    <= #TP 1'b1;
                            
                        
                    end


        S_P2:       begin
                        // when in P2 keep phystatus high while pclk
                        // removal/restore is in progress
                        // if pclk is on turn it off
                        // if pclk is off turn it on
                        
                        pclk_off_p1_tmp        <= #TP 1'b0;
                        // if handshake ends set rx_standby_status
                        if (rxstandby_timer_end)
                            psfsm_rxstandby_status    <= #TP 1'b1;
                        
                        if (P11_to_P1CPM) begin
                            psfsm_phystatus     <= #TP 1'b0;
                            psfsm_state         <= #TP rxstandby_timer_running ? S_RXSTANDBY_ASSERT : S_READY;
                            
                        end else if ((!pclk_mode_input && ((pclk_off_req  & !pclk_off_ack) ||     // this a pclk removal in progress
                                                          (!pclk_off_req & pclk_off_ack)) ) ||
                                    (pclk_mode_input && !psfsm_phystatus && lock)) begin  // this is a pclk restore in progress
                            psfsm_phystatus     <= #TP 1'b1;
                            psfsm_state         <= #TP S_P2;
                        end else begin
                           if ((~p2_phystatus_fall_timer_start && p2_phystatus_fall_timer_exp && !lock && !pclk_mode_input) ||
                               (pclk_mode_input && psfsm_phystatus) )  
                           begin
                              psfsm_phystatus     <= #TP 1'b0;
                              psfsm_state         <= #TP rxstandby_timer_running ? S_RXSTANDBY_ASSERT : S_READY;
                           end
                        end
                    end

        S_RXDET:    begin
                        pclk_off_p2             <= #TP 1'b0;
                        pclk_off_p1_tmp         <= #TP 1'b0;
                        if (~rxdet_timer_start & rxdet_timer_exp & lock) begin
                            psfsm_phystatus     <= #TP 1'b1;
                            if (rxstandby_timer_running) begin
                               // if we rxstandby timer is still running it means we came from S_RXSTANDBY_DEASSSERT
                               // so we go back to finish handshake
                               psfsm_state         <= #TP S_RXSTANDBY_DEASSERT;
                            end else begin
                               psfsm_state         <= #TP S_READY;
                            end   
                        end else begin
                            psfsm_phystatus     <= #TP 1'b0;
                            psfsm_state         <= #TP S_RXDET;
                            if (rxstandby_timer_end)
                               psfsm_rxstandby_status <= #TP 1'b0; 
                        end
                    end
                      
        S_RATE:     begin
                        pclk_off_p2             <= #TP 1'b0;
                        pclk_off_p1_tmp         <= #TP 1'b0;
                        if ((~rate_timer_start & rate_timer_exp & lock & (~rate_change) & (phy_reg_localfslf_done || !update_localfslf_mode[1]))
                        `ifdef GPHY_PIPE_PCLK_MODE_1
                         && ((mac_phy_pclkchangeack && `GPHY_PIPE_OPTIONAL_PCLKCHANGE_HS == 1) || (`GPHY_PIPE_OPTIONAL_PCLKCHANGE_HS == 0 && !pclk_rate_change) ||
                            (`GPHY_PIPE_OPTIONAL_PCLKCHANGE_HS == 0 && mac_phy_pclkchangeack && pclk_rate_change))
                        `endif
                        )  begin
                            psfsm_phystatus     <= #TP 1'b1;
                            rate_change_req_int <= #TP 1'b0;
                            if (!rxstandby_timer_exp) begin
                               // if  rxstandby timer is still running it means we came from S_RXSTANDBY_ASSSERT
                               // so we go back to finish handshake
                               psfsm_state         <= #TP S_RXSTANDBY_ASSERT; 
                            end else begin
                           
                               psfsm_state         <= #TP S_READY; 
                            end                                
                        end else begin
                            psfsm_phystatus     <= #TP 1'b0;
                            psfsm_state         <= #TP S_RATE;
                            `ifdef GPHY_PIPE_PCLK_MODE_1
                             if ((phy_mac_pclkchangeok && `GPHY_PIPE_OPTIONAL_PCLKCHANGE_HS == 1)  || 
                                 (`GPHY_PIPE_OPTIONAL_PCLKCHANGE_HS == 0 && !pclk_rate_change) ||
                                 (`GPHY_PIPE_OPTIONAL_PCLKCHANGE_HS == 0 && phy_mac_pclkchangeok && pclk_rate_change))
                               rate_change_req_int <= #TP 1'b1;
                            `else
                               rate_change_req_int <= #TP 1'b1;
                            `endif    
                            if (rxstandby_timer_end)
                               psfsm_rxstandby_status <= #TP 1'b1; 
                               
                        end
                    end
                    
                           // During the handshake procees when rxstandby is asserted we can have a rate change or a powerdown change
                           // that they need to be served -> so we can move to S_RATE or one of the PWDW change states                    
        S_RXSTANDBY_ASSERT : begin
                               if (~rxstandby_timer_start & rxstandby_timer_exp) begin
                                  psfsm_rxstandby_status <= #TP 1'b1;
                                  psfsm_state         <= #TP S_READY;
                               end  
                               if (rate_change)
                                  psfsm_state         <= #TP S_RATE; 
                               if (ps_change && sdm_sds_powerdown_reg == `GPHY_PDOWN_P1) begin
                                  psfsm_state         <= #TP S_P1DET;                               
                               end
                               if (ps_change && sdm_sds_powerdown_reg == `GPHY_PDOWN_P0S) begin
                                  psfsm_state         <= #TP S_PSDET;                               
                               end
                               if (ps_change && sdm_sds_powerdown_reg == `GPHY_PDOWN_P1_CPM) begin
                                  psfsm_state         <= #TP S_P1CPM;                               
                               end
                               if (ps_change && sdm_sds_powerdown_reg inside { `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON}) begin
                                  psfsm_state         <= #TP S_P2_PREP;                               
                               end
                               
                               if (ps_change && sdm_sds_powerdown_reg == `GPHY_PDOWN_P0 && sdm_sds_powerdown == `GPHY_PDOWN_P0S) begin
                                  psfsm_state         <= #TP S_PSDET;                               
                               end
                               
                               // TODO : add more powerdown transitions if needded to P1CPM/P2
                                  
                             end   
                             
                              // During the handshake procees when rxstandby is de-asserted we can have only
                              // a powerdown change to P0s
         S_RXSTANDBY_DEASSERT : begin
                                  if (~rxstandby_timer_start & rxstandby_timer_exp) begin
                                    psfsm_rxstandby_status <= #TP 1'b0;
                                    psfsm_state         <= #TP S_READY;
                                  end  
                                
                                  if (ps_change && sdm_sds_powerdown_reg == `GPHY_PDOWN_P0S) begin
                                     psfsm_state         <= #TP S_PSDET;                               
                                  end
                                  
                                  if (ps_change && sdm_sds_powerdown_reg == `GPHY_PDOWN_P0) begin
                                     psfsm_state         <= #TP S_PSDET;                               
                                  end
                                  
                                  if (p2p_pulse_txdetectrx)
                                    psfsm_state         <= #TP S_RXDET;
                                    
                                    
                                end                       
                             
                    
    endcase
end


// =============================================================================
// Implement priority mechanism as specified in section 6.8 of PIPE spec
// =============================================================================
function [2:0] pipe_encode_rxstatus;
    input               sdm_sds_txdetectrx;
    input               phystatus;
    input               skp_broken;
    input               sds_sdm_rxdetected;
    input               dec8b10b_rxdisperror;
    input               dec8b10b_rxcodeerror;
    input               elasbuf_rxunderflow;
    input               elasbuf_rxoverflow;
    input               elasbuf_rxskipadded;
    input               elasbuf_rxskipremoved;
begin
    if (phystatus && sdm_sds_txdetectrx)
        pipe_encode_rxstatus = sds_sdm_rxdetected ? 3'b011 : 3'b000;
    else if (|dec8b10b_rxcodeerror || skp_broken)
        pipe_encode_rxstatus = 3'b100;
    else if (elasbuf_rxoverflow)
        pipe_encode_rxstatus = 3'b101;
    else if (elasbuf_rxunderflow)
        pipe_encode_rxstatus = 3'b110;
    else if (|dec8b10b_rxdisperror)
        pipe_encode_rxstatus = 3'b111;
    else if (elasbuf_rxskipadded)
        pipe_encode_rxstatus = 3'b001;
    else if (elasbuf_rxskipremoved)
        pipe_encode_rxstatus = 3'b010;
    else
        pipe_encode_rxstatus = 3'b000;
end

endfunction

endmodule: DWC_pcie_gphy_pipe2phy

