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
// ---    $DateTime: 2020/10/21 14:24:01 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_seq_finder_slv.sv#11 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer Sequence Finder
// --- This module performs the receive special sequence detect as well as
// receive link in training status. This module monitors the PHY rx data to
// extract the all special ordered set defined in PCIExpress spec.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module smlh_seq_finder_slv
#(
    parameter   INST              = 0,                          // The uniquifying parameter for each port logic instance.
    parameter   NB                = `CX_MAC_SMODE_GEN1,         // Number of symbols (bytes) per clock cycle
    parameter   TSFD_WD           = `CX_TS_FIELD_CONTROL_WD,    // bit width of concantenation of TS Symbols {7,6,5,4,3,2,1}
    parameter   TP                = `TP                         // Clock to Q delay (simulator insurance)
)
(
    // Inputs
    input                   core_clk,
    input                   core_rst_n,
    input                   ltssm_lane_flip_ctrl_chg_pulse,    // lane flip control update pulse
    input                   smlh_link_up,
    input                   smlh_link_in_training,
    input   [3:0]           active_nb,
    input                   smlh_in_rl0s,
    input                   cfg_ts2_lid_deskew,
    input                   rxdata_dv_in,
    input                   rxaligned,
    input                   rxskipremoved_in,
    input   [(NB*8)-1:0]    rxdata_in,
    input   [NB-1:0]        rxdatak_in,
    input   [NB-1:0]        rxerror_in,
    input   [5:0]           smlh_ltssm_state,           // Current state of Link Training and Status State Machine
    input                   cfg_upstream_port,
    input                   cfg_elastic_buffer_mode,
    input                   cfg_polarity_mode,              // 0: Default behavior 1: Disable Recovery mechanism
    input   [2:0]           current_data_rate,
    input   [10:0]          xmtbyte_ts_pcnt,
    input                   ltssm_clear,                // used to clear TS persistency count on a ltssm state transition
    input                   ltssm_mod_ts,               // both sides support Modified TS

    // Outputs
    output                  smseq_inskip_rcv,

    output  [TSFD_WD-1:0]   smseq_ts_info,              // {sym7,6,5,4,3,2,1}
    output  [64-1:0]        smseq_mt_info,              // {sym15,14,13,12,11,10,9,8}
    output  [1:0]           smseq_ts_lanen_linkn_pad,   // {PAD lane number, PAD link number}
    output reg [3:0]        smseq_ts_rcvd_mtx_pcnt,     //persistency count for rcvd TS matching some fields in Tx TS
    output reg [3:0]        smseq_ts_rcvd_pcnt,         //persistency count for rcvd TS
    output reg [1:0]        smseq_ts_rcvd_cond_pcnt,    //persistency count for rcvd TS with conditions
    output                  smseq_ts_error,
    output                  smseq_ts1_rcvd,
    output                  smseq_ts2_rcvd,
    output reg              smseq_ts1_rcvd_pulse,
    output reg              smseq_ts2_rcvd_pulse,
    output reg              smseq_mod_ts1_rcvd_pulse,
    output reg              smseq_mod_ts2_rcvd_pulse,
    output reg [3:0]        smseq_loc_ts2_rcvd,
    output reg [3:0]        smseq_in_skp,
    output reg              smseq_fts_skp_do_deskew,
    output                  smseq_rcvr_pol_reverse
);

// Internal Signal declaration
reg                     smseq_fts_skp_do_deskew_i;
reg                     smseq_fts_skp_do_deskew_d;
wire  [3:0]             smseq_loc_ts2_rcvd_i;
reg   [3:0]             smseq_loc_ts2_rcvd_d;
wire  [3:0]             smseq_in_skp_i;
reg   [3:0]             smseq_in_skp_d;
wire  [3:0]             smseq_loc_eies_rcvd_i;
reg   [3:0]             smseq_loc_eies_rcvd_d;
reg                     rcvr_pol_reverse_r;
reg                     latched_link_any_8_ts1_spd_chg_1_rcvd;
wire                    speed_change_is_1;
wire                    ltssm_in_detect;
wire                    ltssm_in_polling;
wire                    ltssm_in_pollact;
wire                    ltssm_in_pollcfg;
wire                    ltssm_in_rcvrylock;
wire                    ltssm_in_rcvry;
wire                    ltssm_in_cfglinkwdstart;
wire                    ltssm_in_l0;
wire                    ltssm_in_l0s;
wire                    ltssm_in_l123sendeidle;
reg                     rx_dv;
reg                     rx_skp_rmd;
wire  [3:0]             pre_rx_bv; //byte valid from active_nb
wire  [3:0]             rx_bv; //byte valid from active_nb
reg   [31:0]            rx_data;
reg   [7:0]             rx_byte_data;
reg   [3:0]             rx_kchar;
reg                     rx_err;
reg   [3:0]             rx_com;
reg   [3:0]             rx_skp;
reg   [3:0]             rx_idl;
reg   [3:0]             rx_k237;
reg   [3:0]             rx_num_v;
reg   [3:0]             rx_rate_v;
reg   [3:0]             rx_eq_ts; //bit[7]==1b
reg   [3:0]             rx_md_ts; //modified ts, bit[7:6]==11b
reg                     rx_lnk_v_d; //link# valid
reg                     rx_lnk_k_d; //link# k-char
reg                     rx_lnk_k;
wire                    rx_lnk_v;
wire                    int_rx_lnk_v;
reg   [3:0]             int_rx_g3_spt; //received data rate supports Gen3
reg                     rx_g3_spt_d; //received data rate supports Gen3
wire                    rx_g3_spt; //received data rate supports Gen3
reg   [3:0]             rx_k287;
reg   [3:0]             rx_d215;
reg   [3:0]             rx_d102;
reg   [3:0]             rx_fts;
reg   [3:0]             rx_ts1;
reg   [3:0]             rx_zero;
reg   [3:0]             rx_s15;
reg   [3:0]             rx_ts2;
reg   [3:0]             rx_invts1;
reg   [3:0]             rx_s_ts1;  //scrambled TS1 for Sym15
reg   [3:0]             rx_invts2;
reg   [3:0]             valid_ep;
reg                     comma_flag;
reg                     in_ts;
reg                     in_ts1;
reg                     in_mod_ts1;
reg   [7:0]             mod_ep[0:3];   // even parity from previous clock for mod ts
reg   [7:0]             in_mod_ep;     // even parity from previous clock for mod ts
reg                     iv_ts1;
reg                     in_ts2;
reg                     in_mod_ts2;
reg                     iv_ts2;
reg                     in_skp;
reg                     in_fts;
reg   [7:0]             int_ts_sym[0:15];
reg   [7:0]             dec_ts_sym[0:15];
localparam SN = 6;
reg   [7:0]             int_ts_sym_rcvd[1:SN];
reg   [7:0]             int_mt_sym_rcvd[8:15]; // sym15-8 for Modified TS Format
reg                     ts_link_num_is_k237_i;
reg                     ts_lane_num_is_k237_i;
reg                     ts_link_num_is_k237;
reg                     ts_lane_num_is_k237;
reg   [3:0]             sym_count;
reg                     ts_error;
reg                     skp_rcvd;
reg                     ts1_rcvd;
reg                     ts2_rcvd;
reg                     pol_reverse;
reg   [3:0]             int_sym_count[0:3];
wire  [3:0]             int_in_ts;
wire  [3:0]             int_in_ts1;
wire  [3:0]             int_in_mod_ts1;
wire  [3:0]             int_in_ts2;
wire  [3:0]             int_in_mod_ts2;
wire  [3:0]             inv_in_ts1;
wire  [3:0]             inv_in_ts2;
wire  [3:0]             int_in_skp;
wire  [3:0]             int_in_fts;
wire  [3:0]             i_fts_rcvd;
reg                     fts_rcvd;
wire                    ts_error_i;
wire                    ts_error_not_ts_rcvd;
reg                     int_ts_error_d;
wire                    int_ts_error;
wire  [3:0]             int_ts1_rcvd;
wire  [3:0]             int_ts2_rcvd;
wire  [3:0]             int_mod_ts1_rcvd;
wire  [3:0]             int_mod_ts2_rcvd;
wire  [3:0]             inv_ts1_rcvd;
wire  [3:0]             inv_ts2_rcvd;
wire                    int_ts_rcvd_pulse;
wire                    inv_ts_rcvd_pulse;
wire                    int_ts1_rcvd_pulse;
wire                    int_ts2_rcvd_pulse;
wire                    int_mod_ts1_rcvd_pulse;
wire                    int_mod_ts2_rcvd_pulse;
wire                    int_mod_ts_rcvd_pulse;
wire                    inv_ts1_rcvd_pulse;
wire                    inv_ts2_rcvd_pulse;
reg                     latched_sym_updated;
wire                    int_xmtbyte_eies_sent;
wire  [3:0]             active_nb_gen12;
reg [7:1]               sym_diff_bus;
wire                    any_sym_diff;
wire                    xmtbyte_32_ts1_sent;
wire                    rxaligned_i;

  assign active_nb_gen12 =
                     ((`CX_MAC_SMODE_GEN1==2 ) & (current_data_rate==`GEN1_RATE)) ? 4'b0010 : //gen1, active symbol number = 2
                                                                                    `CX_NB;

assign  pre_rx_bv = (active_nb_gen12 == 4'b0001) ? 4'b0001 :
                    (active_nb_gen12 == 4'b0010) ? 4'b0011 :
                    (active_nb_gen12 == 4'b0100) ? 4'b1111 : 4'b0000; //byte valid
//assign  rx_bv = (active_nb == 4'b0001) ? 4'b0001 :
//                (active_nb == 4'b0010) ? 4'b0011 :
//                (active_nb == 4'b0100) ? 4'b1111 : 4'b0000; //byte valid
assign rx_bv = pre_rx_bv & (cfg_elastic_buffer_mode ? {4{rx_dv}} : 4'b1111);

always @( * ) begin : rx_4s_data_PROC
    integer i;

    rx_dv      = 0;
    rx_skp_rmd = 0;
    rx_data    = 0;
    rx_kchar   = 0;
    rx_err     = 0;

    rx_dv      = rxdata_dv_in;
    rx_skp_rmd = rxskipremoved_in;
    rx_err     = rxerror_in[0]; //rxerror_in[NB-1:1] duplicates rxerror_in[0], see rmlh.v

    for ( i=0; i<NB; i=i+1 ) begin
        rx_data[i*8 +: 8] = rxdata_in[i*8 +: 8];
        rx_kchar[i]       = rxdatak_in[i];
    end
end // rx_4s_data_PROC

assign ltssm_in_detect         = (smlh_ltssm_state == `S_DETECT_QUIET || smlh_ltssm_state == `S_DETECT_ACT );
assign ltssm_in_polling        = (smlh_ltssm_state == `S_POLL_ACTIVE || smlh_ltssm_state == `S_POLL_CONFIG || smlh_ltssm_state == `S_POLL_COMPLIANCE);
assign ltssm_in_pollact        = (smlh_ltssm_state == `S_POLL_ACTIVE);
assign ltssm_in_pollcfg        = (smlh_ltssm_state == `S_POLL_CONFIG);
assign ltssm_in_rcvrylock      = (smlh_ltssm_state == `S_RCVRY_LOCK);
assign ltssm_in_rcvry          = (smlh_ltssm_state == `S_RCVRY_LOCK || smlh_ltssm_state == `S_RCVRY_RCVRCFG);
assign ltssm_in_cfglinkwdstart = (smlh_ltssm_state == `S_CFG_LINKWD_START);
assign ltssm_in_l0             = (smlh_ltssm_state == `S_L0);
assign ltssm_in_l0s            = (smlh_ltssm_state == `S_L0S);
assign ltssm_in_l123sendeidle  = (smlh_ltssm_state == `S_L123_SEND_EIDLE);

wire [7:0] lane_1s_ep = int_ts_sym[9]^int_ts_sym[10]^int_ts_sym[11]^int_ts_sym[12]^int_ts_sym[13]^int_ts_sym[14];
always @( * ) begin : os_field_extract_PROC
    integer i;

    rx_com        = 4'b0;
    rx_skp        = 4'b0;
    rx_idl        = 4'b0;
    rx_k237       = 4'b0;
    rx_num_v      = 4'b0;
    rx_d215       = 4'b0;
    rx_d102       = 4'b0;
    rx_fts        = 4'b0;
    rx_ts1        = 4'b0;
    rx_s15        = 4'b0;
    rx_ts2        = 4'b0;
    rx_invts1     = 4'b0;
    rx_invts2     = 4'b0;
    int_rx_g3_spt = 4'b0;
    rx_rate_v     = 4'b0;
    rx_eq_ts      = 4'b0;
    rx_md_ts      = 4'b0;
    valid_ep      = 4'b0;

    for (i=0; i<NB; i=i+1) begin
        rx_com   [i]     =  (rx_data[i*8 +: 8] == `COMMA_8B  ) & rx_kchar[i]  & rx_bv[i] & rx_dv;
        rx_skp   [i]     =  (rx_data[i*8 +: 8] == `SKIP_8B   ) & rx_kchar[i]  & rx_bv[i] & rx_dv;
        rx_idl   [i]     =  (rx_data[i*8 +: 8] == `EIDLE_8B  ) & rx_kchar[i]  & rx_bv[i] & rx_dv;
        rx_k237  [i]     =  (rx_data[i*8 +: 8] == `K237_8B   ) & rx_kchar[i]  & rx_bv[i] & rx_dv;
        rx_num_v [i]     =  (rx_data[i*8 +: 8] <=  8'h1f     ) & !rx_kchar[i] & rx_bv[i] & rx_dv; //lane number <= 31
        rx_d215  [i]     =  (rx_data[i*8 +: 8] == `D215_8B   ) & !rx_kchar[i] & rx_bv[i] & rx_dv;
        rx_d102  [i]     =  (rx_data[i*8 +: 8] == `D102_8B   ) & !rx_kchar[i] & rx_bv[i] & rx_dv;
        rx_fts   [i]     =  (rx_data[i*8 +: 8] == `FTS_8B    ) & rx_kchar[i]  & rx_bv[i] & rx_dv;
        rx_ts1   [i]     =  (rx_data[i*8 +: 8] == `TS1_8B    ) & !rx_kchar[i] & rx_bv[i] & rx_dv;
        rx_ts2   [i]     =  (rx_data[i*8 +: 8] == `TS2_8B    ) & !rx_kchar[i] & rx_bv[i] & rx_dv;
        rx_invts1[i]     =  (rx_data[i*8 +: 8] == `INV_TS1_8B) & !rx_kchar[i] & rx_bv[i] & rx_dv;
        rx_invts2[i]     =  (rx_data[i*8 +: 8] == `INV_TS2_8B) & !rx_kchar[i] & rx_bv[i] & rx_dv;
        valid_ep [i]     =  (rx_data[i*8 +: 8] == mod_ep[i]  ) & !rx_kchar[i] & rx_bv[i] & rx_dv;
        int_rx_g3_spt[i] =  0;
        rx_eq_ts [i]     =  0;
        rx_rate_v[i]     =  !rx_kchar[i] & rx_bv[i] & rx_dv;
        //rx_s15 is the bit-wise even parity for sym14-9
        rx_s15   [i]     =  !rx_kchar[i] & rx_bv[i] & rx_dv & (active_nb[0] );
        rx_md_ts [i]     =  0;
    end // for
end // os_field_extract_PROC

//
//get valid link# <= 31 if gen3 supported, link# is sym1
//
always @(posedge core_clk or negedge core_rst_n) begin : link_num_v_PROC
    if ( ~core_rst_n ) begin
        rx_lnk_v_d <= #TP 0;
        rx_lnk_k_d <= #TP 0;
    end else if ( int_sym_count[3] == 1 && rx_bv[3] && int_in_ts[3] ) begin
        rx_lnk_v_d <= #TP rx_num_v[3] | rx_k237[3];
        rx_lnk_k_d <= #TP rx_k237[3];
    end else if ( int_sym_count[2] == 1 && rx_bv[2] && int_in_ts[2] ) begin
        rx_lnk_v_d <= #TP rx_num_v[2] | rx_k237[2];
        rx_lnk_k_d <= #TP rx_k237[2];
    end else if ( int_sym_count[1] == 1 && rx_bv[1] && int_in_ts[1] ) begin
        rx_lnk_v_d <= #TP rx_num_v[1] | rx_k237[1];
        rx_lnk_k_d <= #TP rx_k237[1];
    end else if ( int_sym_count[0] == 1 && rx_bv[0] && int_in_ts[0] ) begin
        rx_lnk_v_d <= #TP rx_num_v[0] | rx_k237[0];
        rx_lnk_k_d <= #TP rx_k237[0];
    end
end // link_num_v_PROC

always @( * ) begin : rx_lnk_k_PROC
    rx_lnk_k = rx_lnk_k_d;

    if ( int_sym_count[3] == 1 && rx_bv[3] && int_in_ts[3] )
        rx_lnk_k = rx_k237[3];
    else if ( int_sym_count[2] == 1 && rx_bv[2] && int_in_ts[2] )
        rx_lnk_k = rx_k237[2];
    else if ( int_sym_count[1] == 1 && rx_bv[1] && int_in_ts[1] )
        rx_lnk_k = rx_k237[1];
    else if ( int_sym_count[0] == 1 && rx_bv[0] && int_in_ts[0] )
        rx_lnk_k = rx_k237[0];
end // rx_lnk_k_PROC

assign rx_lnk_v = rx_lnk_v_d;

//latch int_rx_g3_spt to check Link# at Sym 8 for breaking timing path, data rate in sym4
always @(posedge core_clk or negedge core_rst_n) begin : rx_g3_spt_delay_PROC
    if ( !core_rst_n )
        rx_g3_spt_d <= #TP 0;
    else if ( int_sym_count[3] == 4 && rx_bv[3] && int_in_ts[3] )
        rx_g3_spt_d <= #TP int_rx_g3_spt[3];
    else if ( int_sym_count[2] == 4 && rx_bv[2] && int_in_ts[2] )
        rx_g3_spt_d <= #TP int_rx_g3_spt[2];
    else if ( int_sym_count[1] == 4 && rx_bv[1] && int_in_ts[1] )
        rx_g3_spt_d <= #TP int_rx_g3_spt[1];
    else if ( int_sym_count[0] == 4 && rx_bv[0] && int_in_ts[0] )
        rx_g3_spt_d <= #TP int_rx_g3_spt[0];
end // rx_g3_spt_delay_PROC

assign rx_g3_spt = 0;

//
// detecting TS
//
// combinational logic of sym_count for each symbol.
// sym_count is a free running counter reset by rx_com.
// int_sym_count[NB-1] is latched in sym_count.
always @( * ) begin : int_sym_count_PROC
    int_sym_count[0] = 0;
    int_sym_count[1] = 0;
    int_sym_count[2] = 0;
    int_sym_count[3] = 0;

    int_sym_count[0] = rx_bv[0] ? rx_com[0] ? 4'b0000 : sym_count + 1 : sym_count; //byte0 always valid except ~rx_dv
    int_sym_count[1] = rx_bv[1] ? rx_com[1] ? 4'b0000 : rx_com[0] ? 4'b0001 : sym_count + 2 : int_sym_count[0];
    int_sym_count[2] = rx_bv[2] ? rx_com[2] ? 4'b0000 : rx_com[1] ? 4'b0001 : rx_com[0] ? 4'b0010 : sym_count + 3 : int_sym_count[1];
    int_sym_count[3] = rx_bv[3] ? rx_com[3] ? 4'b0000 : rx_com[2] ? 4'b0001 : rx_com[1] ? 4'b0010 : rx_com[0] ? 4'b0011 : sym_count + 4 : int_sym_count[2];
end // int_sym_count_PROC

//standard TS1
// eqts1 may be in any states, so ltssm_in_rcvry set to 1 to detect eqts1 always
assign int_in_ts1[0] = !rx_err & rx_dv & call_in_ts(1'b1    , in_ts1       , int_sym_count[0], comma_flag, rx_com[0], rx_kchar[0], rx_num_v[0], rx_k237[0], rx_ts1[0], rx_g3_spt, rx_lnk_v, rx_rate_v[0], rx_eq_ts[0], 1'b1);
assign int_in_ts1[1] = !rx_err & rx_dv & call_in_ts(rx_bv[1], int_in_ts1[0], int_sym_count[1], rx_com[0] , rx_com[1], rx_kchar[1], rx_num_v[1], rx_k237[1], rx_ts1[1], rx_g3_spt, rx_lnk_v, rx_rate_v[1], rx_eq_ts[1], 1'b1);
assign int_in_ts1[2] = !rx_err & rx_dv & call_in_ts(rx_bv[2], int_in_ts1[1], int_sym_count[2], rx_com[1] , rx_com[2], rx_kchar[2], rx_num_v[2], rx_k237[2], rx_ts1[2], rx_g3_spt, rx_lnk_v, rx_rate_v[2], rx_eq_ts[2], 1'b1);
assign int_in_ts1[3] = !rx_err & rx_dv & call_in_ts(rx_bv[3], int_in_ts1[2], int_sym_count[3], rx_com[2] , rx_com[3], rx_kchar[3], rx_num_v[3], rx_k237[3], rx_ts1[3], rx_g3_spt, rx_lnk_v, rx_rate_v[3], rx_eq_ts[3], 1'b1);

// modified ts1
assign int_in_mod_ts1[0] = 1'b0;
assign int_in_mod_ts1[1] = 1'b0;
assign int_in_mod_ts1[2] = 1'b0;
assign int_in_mod_ts1[3] = 1'b0;

// modified ts for Call Even Parity on sym15
assign mod_ep[0] = {8{(!rx_err & rx_dv)}} & call_in_mod_ep(1'b1    , in_mod_ep, int_sym_count[0], rx_data[7:0]  );
assign mod_ep[1] = {8{(!rx_err & rx_dv)}} & call_in_mod_ep(rx_bv[1], mod_ep[0], int_sym_count[1], rx_data[15:8] );
assign mod_ep[2] = {8{(!rx_err & rx_dv)}} & call_in_mod_ep(rx_bv[2], mod_ep[1], int_sym_count[2], rx_data[23:16]);
assign mod_ep[3] = {8{(!rx_err & rx_dv)}} & call_in_mod_ep(rx_bv[3], mod_ep[2], int_sym_count[3], rx_data[31:24]);

//complement TS1
// complement ts1 is only in Polling.Active and Polling.Compliance
/*
assign inv_in_ts1[0] = !rx_err & rx_dv & call_in_ts(1'b1    , iv_ts1       , int_sym_count[0], comma_flag, rx_com[0], rx_kchar[0], rx_num_v[0], rx_k237[0], rx_invts1[0], rx_g3_spt, rx_lnk_v, rx_rate_v[0], rx_eq_ts[0], 1'b1);
assign inv_in_ts1[1] = !rx_err & rx_dv & call_in_ts(rx_bv[1], inv_in_ts1[0], int_sym_count[1], rx_com[0] , rx_com[1], rx_kchar[1], rx_num_v[1], rx_k237[1], rx_invts1[1], rx_g3_spt, rx_lnk_v, rx_rate_v[1], rx_eq_ts[1], 1'b1);
assign inv_in_ts1[2] = !rx_err & rx_dv & call_in_ts(rx_bv[2], inv_in_ts1[1], int_sym_count[2], rx_com[1] , rx_com[2], rx_kchar[2], rx_num_v[2], rx_k237[2], rx_invts1[2], rx_g3_spt, rx_lnk_v, rx_rate_v[2], rx_eq_ts[2], 1'b1);
assign inv_in_ts1[3] = !rx_err & rx_dv & call_in_ts(rx_bv[3], inv_in_ts1[2], int_sym_count[3], rx_com[2] , rx_com[3], rx_kchar[3], rx_num_v[3], rx_k237[3], rx_invts1[3], rx_g3_spt, rx_lnk_v, rx_rate_v[3], rx_eq_ts[3], 1'b1);
*/
assign inv_in_ts1[0] = !rx_err & rx_dv & call_in_inv_ts(1'b1    , iv_ts1       , int_sym_count[0], comma_flag, rx_com[0], rx_invts1[0]);
assign inv_in_ts1[1] = !rx_err & rx_dv & call_in_inv_ts(rx_bv[1], inv_in_ts1[0], int_sym_count[1], rx_com[0] , rx_com[1], rx_invts1[1]);
assign inv_in_ts1[2] = !rx_err & rx_dv & call_in_inv_ts(rx_bv[2], inv_in_ts1[1], int_sym_count[2], rx_com[1] , rx_com[2], rx_invts1[2]);
assign inv_in_ts1[3] = !rx_err & rx_dv & call_in_inv_ts(rx_bv[3], inv_in_ts1[2], int_sym_count[3], rx_com[2] , rx_com[3], rx_invts1[3]);

//standard TS2 
// eqts2 in any states
assign int_in_ts2[0] = !rx_err & rx_dv & call_in_ts(1'b1    , in_ts2       , int_sym_count[0], comma_flag, rx_com[0], rx_kchar[0], rx_num_v[0], rx_k237[0], rx_ts2[0], rx_g3_spt, rx_lnk_v, rx_rate_v[0], rx_eq_ts[0], 1'b1);
assign int_in_ts2[1] = !rx_err & rx_dv & call_in_ts(rx_bv[1], int_in_ts2[0], int_sym_count[1], rx_com[0] , rx_com[1], rx_kchar[1], rx_num_v[1], rx_k237[1], rx_ts2[1], rx_g3_spt, rx_lnk_v, rx_rate_v[1], rx_eq_ts[1], 1'b1);
assign int_in_ts2[2] = !rx_err & rx_dv & call_in_ts(rx_bv[2], int_in_ts2[1], int_sym_count[2], rx_com[1] , rx_com[2], rx_kchar[2], rx_num_v[2], rx_k237[2], rx_ts2[2], rx_g3_spt, rx_lnk_v, rx_rate_v[2], rx_eq_ts[2], 1'b1);
assign int_in_ts2[3] = !rx_err & rx_dv & call_in_ts(rx_bv[3], int_in_ts2[2], int_sym_count[3], rx_com[2] , rx_com[3], rx_kchar[3], rx_num_v[3], rx_k237[3], rx_ts2[3], rx_g3_spt, rx_lnk_v, rx_rate_v[3], rx_eq_ts[3], 1'b1);

// modified ts2
assign int_in_mod_ts2[0] = 1'b0;
assign int_in_mod_ts2[1] = 1'b0;
assign int_in_mod_ts2[2] = 1'b0;
assign int_in_mod_ts2[3] = 1'b0;

//complement TS2
// complement eq ts2 in Polling state
/*
assign inv_in_ts2[0] = !rx_err & rx_dv & call_in_ts(1'b1    , iv_ts2       , int_sym_count[0], comma_flag, rx_com[0], rx_kchar[0], rx_num_v[0], rx_k237[0], rx_invts2[0], rx_g3_spt, rx_lnk_v, rx_rate_v[0], rx_eq_ts[0], 1'b1); //1'b0);
assign inv_in_ts2[1] = !rx_err & rx_dv & call_in_ts(rx_bv[1], inv_in_ts2[0], int_sym_count[1], rx_com[0] , rx_com[1], rx_kchar[1], rx_num_v[1], rx_k237[1], rx_invts2[1], rx_g3_spt, rx_lnk_v, rx_rate_v[1], rx_eq_ts[1], 1'b1); //1'b0);
assign inv_in_ts2[2] = !rx_err & rx_dv & call_in_ts(rx_bv[2], inv_in_ts2[1], int_sym_count[2], rx_com[1] , rx_com[2], rx_kchar[2], rx_num_v[2], rx_k237[2], rx_invts2[2], rx_g3_spt, rx_lnk_v, rx_rate_v[2], rx_eq_ts[2], 1'b1); //1'b0);
assign inv_in_ts2[3] = !rx_err & rx_dv & call_in_ts(rx_bv[3], inv_in_ts2[2], int_sym_count[3], rx_com[2] , rx_com[3], rx_kchar[3], rx_num_v[3], rx_k237[3], rx_invts2[3], rx_g3_spt, rx_lnk_v, rx_rate_v[3], rx_eq_ts[3], 1'b1); //1'b0);
*/
assign inv_in_ts2[0] = !rx_err & rx_dv & call_in_inv_ts(1'b1    , iv_ts2       , int_sym_count[0], comma_flag, rx_com[0], rx_invts2[0]);
assign inv_in_ts2[1] = !rx_err & rx_dv & call_in_inv_ts(rx_bv[1], inv_in_ts2[0], int_sym_count[1], rx_com[0] , rx_com[1], rx_invts2[1]);
assign inv_in_ts2[2] = !rx_err & rx_dv & call_in_inv_ts(rx_bv[2], inv_in_ts2[1], int_sym_count[2], rx_com[1] , rx_com[2], rx_invts2[2]);
assign inv_in_ts2[3] = !rx_err & rx_dv & call_in_inv_ts(rx_bv[3], inv_in_ts2[2], int_sym_count[3], rx_com[2] , rx_com[3], rx_invts2[3]);

//complement ts is only in Polling state
//sym7-sym15 must be identical
//only one of (int_in_ts1 or inv_in_ts1 or int_in_ts2 or inv_in_ts2) is true if a ts is received, or ts_error
//assign int_in_ts[0] = ltssm_in_polling ? (int_in_ts1[0] | inv_in_ts1[0] | int_in_ts2[0] | inv_in_ts2[0]) : (int_in_ts1[0] | int_in_ts2[0]);
//assign int_in_ts[1] = ltssm_in_polling ? (int_in_ts1[1] | inv_in_ts1[1] | int_in_ts2[1] | inv_in_ts2[1]) : (int_in_ts1[1] | int_in_ts2[1]);
//assign int_in_ts[2] = ltssm_in_polling ? (int_in_ts1[2] | inv_in_ts1[2] | int_in_ts2[2] | inv_in_ts2[2]) : (int_in_ts1[2] | int_in_ts2[2]);
//assign int_in_ts[3] = ltssm_in_polling ? (int_in_ts1[3] | inv_in_ts1[3] | int_in_ts2[3] | inv_in_ts2[3]) : (int_in_ts1[3] | int_in_ts2[3]);
assign int_in_ts[0] = (ltssm_mod_ts ? 1'b0 : (int_in_ts1[0] | int_in_ts2[0])) | int_in_mod_ts1[0] | int_in_mod_ts2[0];
assign int_in_ts[1] = (ltssm_mod_ts ? 1'b0 : (int_in_ts1[1] | int_in_ts2[1])) | int_in_mod_ts1[1] | int_in_mod_ts2[1];
assign int_in_ts[2] = (ltssm_mod_ts ? 1'b0 : (int_in_ts1[2] | int_in_ts2[2])) | int_in_mod_ts1[2] | int_in_mod_ts2[2];
assign int_in_ts[3] = (ltssm_mod_ts ? 1'b0 : (int_in_ts1[3] | int_in_ts2[3])) | int_in_mod_ts1[3] | int_in_mod_ts2[3];

// standard TS
function automatic call_in_ts;
    input       rx_bv;
    input       pre_in_ts;
    input [3:0] count;
    input       pre_com;
    input       rx_com;
    input       rx_kchar;
    input       rx_num_v;
    input       rx_k237;
    input       rx_ts;
    input       rx_g3_spt;
    input       rx_lnk_v;
    input       rx_rate_v;
    input       rx_eq_ts;
    input       ltssm_in_rcvry;
begin
    if ( ~rx_bv )
        call_in_ts = pre_in_ts;

    else case (count)
        4'b0000:
            call_in_ts = rx_com; //COMMA
        4'b0001:
            call_in_ts = (!rx_kchar | rx_k237) & pre_com; //link#
        4'b0010:
            call_in_ts = (rx_num_v | rx_k237) & pre_in_ts; //Lane# = 0-31 or PAD
        4'b0100:
            call_in_ts = rx_rate_v & pre_in_ts; //data rate: not k-char
        4'b0011, 4'b0101:
            call_in_ts = (!rx_kchar) & pre_in_ts; //sym3 - N_FTS (any value), sym5 - training control (any value)
        //if support 8.0 GT/s or above, Link# 0-31 or PAD. Link# is in Sym 1 and DataRate is in Sym 4.
        //check Link# at Sym 8 is to break critical timing path
//        4'b1000: //no check since 30-1-2015
//            call_in_ts = (rx_g3_spt ? rx_lnk_v : 1) & rx_ts & pre_in_ts;
        default:
            call_in_ts = rx_ts & pre_in_ts;
    endcase
end
endfunction // call_in_ts

// Modified TS
function automatic call_in_mod_ts;
    input       rx_bv;
    input       pre_in_ts;
    input [3:0] count;
    input       pre_com;
    input       rx_com;
    input       rx_kchar;
    input       rx_num_v;
    input       rx_k237;
    input       rx_ts;
    input       rx_g3_spt;
    input       rx_lnk_v;
    input       rx_rate_v;
    input       rx_md_ts;
    input       ltssm_in_rcvry;
    input       valid_ep;
begin
    if ( ~rx_bv )
        call_in_mod_ts = pre_in_ts;

    else case (count)
        4'b0000:
            call_in_mod_ts = rx_com; //COMMA
        4'b0001:
            call_in_mod_ts = (!rx_kchar | rx_k237) & pre_com; //link#
        4'b0010:
            call_in_mod_ts = (rx_num_v | rx_k237) & pre_in_ts; //Lane# = 0-31 or PAD
        4'b0011:
            call_in_mod_ts = (!rx_kchar) & pre_in_ts; //sym3 - N_FTS (any value)
        4'b0100:
            call_in_mod_ts = rx_rate_v & pre_in_ts; //data rate: not k-char
        4'b0101:
            call_in_mod_ts = rx_md_ts & pre_in_ts; //sym5[7] = 1
        //sym15-8 may be Modified TS Format, TBD, any values for spec 5.0 r0.7
        4'b1000, 4'b1001, 4'b1010, 4'b1011, 4'b1100, 4'b1101, 4'b1110:
            call_in_mod_ts = (!rx_kchar) & pre_in_ts;
        4'b1111:
            call_in_mod_ts = (!rx_kchar) & pre_in_ts & valid_ep; // valid Even Parity
        default: // sym7-6 is TS Idetifier
            call_in_mod_ts = rx_ts & pre_in_ts;
    endcase
end
endfunction // call_in_mod_ts

// Modified TS for Even Parity
function automatic [7:0] call_in_mod_ep;
    input       rx_bv;   // byte valid on the symbol
    input [7:0] pre_e_p; // previous even parity
    input [3:0] count;   // sym count on the byte
    input [7:0] rx_data; // current clock rx_data
begin
    if ( ~rx_bv )
        call_in_mod_ep = pre_e_p;

    else case (count)
        4'b0000, 4'b0001, 4'b0010, 4'b0011:
            call_in_mod_ep = 8'b00000000; //sym3-0, reset the even parity
        4'b1111:
            call_in_mod_ep = pre_e_p;     //sym15, keep sym14 value
        default:                          //sym14-4, bit-wise even parity
            call_in_mod_ep = pre_e_p^rx_data;
    endcase
end
endfunction // call_in_mod_ep

// Polarity TS can only be in Polling state, no Modified TS
function automatic call_in_inv_ts;
    input       rx_bv;
    input       pre_in_ts;
    input [3:0] count;
    input       pre_com;
    input       rx_com;
    input       rx_ts;
begin
    if ( ~rx_bv )
        call_in_inv_ts = pre_in_ts;

    else case (count)
        4'b0000:
            call_in_inv_ts = rx_com; //COMMA
        4'b0001:
            call_in_inv_ts = pre_com; //polarity
        4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110:
            call_in_inv_ts = pre_in_ts; //polarity
        default:
            call_in_inv_ts = rx_ts & pre_in_ts;
    endcase
end
endfunction // call_in_inv_ts



//  
// byte 3 : xxx
// byte 2 : COM (rxskipremoved not on this COM)
// byte 1 : xxx
// byte 0 : COM (rxskipremoved on this COM)
//
// detecting SKIP OS
//  
assign int_in_skp[0] = !rx_err & rx_dv & ( (comma_flag ? rx_skp[0] : in_skp & rx_skp[0]) | (rx_com[0] & rx_skp_rmd) );
assign int_in_skp[1] = !rx_err & rx_dv & (~rx_bv[1] ? int_in_skp[0] : (rx_com[0] ? rx_skp[1] : ( (int_in_skp[0] & rx_skp[1]) | (rx_com[1] & rx_skp_rmd) )));
assign int_in_skp[2] = !rx_err & rx_dv & (~rx_bv[2] ? int_in_skp[1] : (rx_com[1] ? rx_skp[2] : ( (int_in_skp[1] & rx_skp[2]) | (rx_com[2] & ~rx_com[0] & rx_skp_rmd) )));
assign int_in_skp[3] = !rx_err & rx_dv & (~rx_bv[3] ? int_in_skp[2] : (rx_com[2] ? rx_skp[3] : ( (int_in_skp[2] & rx_skp[3]) | (rx_com[3] & ~(|rx_com[1:0]) & rx_skp_rmd) )));

//
// generating ts_error
//
// all NB bytes must be in ts or skp or eieos, otherwise ts_error
// if current valid byte with COMMA but previous byte sym_count != 15, ts_error
// if rxaligned=0, so no ts/skp/eieos, ts_error. if rxdatavalid=0, so no ts/skp/eieos, not ts_error
assign ts_error_i  = (cfg_elastic_buffer_mode & ~rxaligned) ? 1 : (cfg_elastic_buffer_mode & ~rx_dv) ? 0 :
                     (!(&(int_in_ts[NB-1:0] | int_in_skp[NB-1:0]))
                       | (rx_bv[0] & rx_com[0] & ~in_skp        & in_ts        & (sym_count != 4'b1111))
                       | (rx_bv[1] & rx_com[1] & ~int_in_skp[0] & int_in_ts[0] & (int_sym_count[0] != 4'b1111))
                       | (rx_bv[2] & rx_com[2] & ~int_in_skp[1] & int_in_ts[1] & (int_sym_count[1] != 4'b1111))
                       | (rx_bv[3] & rx_com[3] & ~int_in_skp[2] & int_in_ts[2] & (int_sym_count[2] != 4'b1111)));

assign int_ts1_rcvd_pulse = |int_ts1_rcvd[NB-1:0];
assign int_ts2_rcvd_pulse = |int_ts2_rcvd[NB-1:0];
assign int_mod_ts1_rcvd_pulse = |int_mod_ts1_rcvd[NB-1:0];
assign int_mod_ts2_rcvd_pulse = |int_mod_ts2_rcvd[NB-1:0];
assign int_mod_ts_rcvd_pulse  = int_mod_ts1_rcvd_pulse | int_mod_ts2_rcvd_pulse;
assign inv_ts1_rcvd_pulse = |inv_ts1_rcvd[NB-1:0];
assign inv_ts2_rcvd_pulse = |inv_ts2_rcvd[NB-1:0];
assign int_ts_rcvd_pulse  = int_ts1_rcvd_pulse | int_ts2_rcvd_pulse;
assign inv_ts_rcvd_pulse  = inv_ts1_rcvd_pulse | inv_ts2_rcvd_pulse;
assign ts_error_not_ts_rcvd = ts_error_i & (~int_ts_rcvd_pulse);

always @(posedge core_clk or negedge core_rst_n) begin : int_ts_error_d_PROC
    if ( ~core_rst_n )
        int_ts_error_d <= #TP 0;
    else
        int_ts_error_d <= #TP ts_error_i & int_ts_rcvd_pulse;
end // int_ts_error_d_PROC

//if ts_error and ts_rcvd occur at the same cycle, the ts is received but ts_error moves to the next cycle (next OS)
//we don't need to discard the currently received correct TS
assign int_ts_error = ts_error_not_ts_rcvd | int_ts_error_d;

//
// generating ts_rcvd
//
assign int_ts1_rcvd[0] = int_sym_count[0]==4'b1111 & (( int_in_ts1[0]));
assign int_ts1_rcvd[1] = int_sym_count[1]==4'b1111 & (( int_in_ts1[1]));
assign int_ts1_rcvd[2] = int_sym_count[2]==4'b1111 & (( int_in_ts1[2]));
assign int_ts1_rcvd[3] = int_sym_count[3]==4'b1111 & (( int_in_ts1[3]));
assign int_mod_ts1_rcvd[0] = int_sym_count[0]==4'b1111 & (~int_in_ts1[0] & int_in_mod_ts1[0]);
assign int_mod_ts1_rcvd[1] = int_sym_count[1]==4'b1111 & (~int_in_ts1[1] & int_in_mod_ts1[1]);
assign int_mod_ts1_rcvd[2] = int_sym_count[2]==4'b1111 & (~int_in_ts1[2] & int_in_mod_ts1[2]);
assign int_mod_ts1_rcvd[3] = int_sym_count[3]==4'b1111 & (~int_in_ts1[3] & int_in_mod_ts1[3]);
assign int_ts2_rcvd[0] = int_sym_count[0]==4'b1111 & (( int_in_ts2[0]));
assign int_ts2_rcvd[1] = int_sym_count[1]==4'b1111 & (( int_in_ts2[1]));
assign int_ts2_rcvd[2] = int_sym_count[2]==4'b1111 & (( int_in_ts2[2]));
assign int_ts2_rcvd[3] = int_sym_count[3]==4'b1111 & (( int_in_ts2[3]));
assign int_mod_ts2_rcvd[0] = int_sym_count[0]==4'b1111 & (~int_in_ts2[0] & int_in_mod_ts2[0]);
assign int_mod_ts2_rcvd[1] = int_sym_count[1]==4'b1111 & (~int_in_ts2[1] & int_in_mod_ts2[1]);
assign int_mod_ts2_rcvd[2] = int_sym_count[2]==4'b1111 & (~int_in_ts2[2] & int_in_mod_ts2[2]);
assign int_mod_ts2_rcvd[3] = int_sym_count[3]==4'b1111 & (~int_in_ts2[3] & int_in_mod_ts2[3]);

assign inv_ts1_rcvd[0] = int_sym_count[0]==4'b1111 & inv_in_ts1[0];
assign inv_ts1_rcvd[1] = int_sym_count[1]==4'b1111 & inv_in_ts1[1];
assign inv_ts1_rcvd[2] = int_sym_count[2]==4'b1111 & inv_in_ts1[2];
assign inv_ts1_rcvd[3] = int_sym_count[3]==4'b1111 & inv_in_ts1[3];
assign inv_ts2_rcvd[0] = int_sym_count[0]==4'b1111 & inv_in_ts2[0];
assign inv_ts2_rcvd[1] = int_sym_count[1]==4'b1111 & inv_in_ts2[1];
assign inv_ts2_rcvd[2] = int_sym_count[2]==4'b1111 & inv_in_ts2[2];
assign inv_ts2_rcvd[3] = int_sym_count[3]==4'b1111 & inv_in_ts2[3];

assign  smseq_loc_ts2_rcvd_i  = /* ~cfg_ts2_lid_deskew ? 0 : */ (int_ts2_rcvd & rx_bv);  // no need ts2 -> idle for ts1_ts2_do_deskew. comment out ~cfg_ts2_lid_deskew as it is used in deskew block again and only there
assign  smseq_in_skp_i        = int_in_skp & rx_bv;

always @(posedge core_clk or negedge core_rst_n) begin : smseq_ts_rcvd_pulse_PROC
    if (!core_rst_n) begin
        smseq_ts1_rcvd_pulse  <= #TP 1'b0;
        smseq_ts2_rcvd_pulse  <= #TP 1'b0;
        smseq_mod_ts1_rcvd_pulse  <= #TP 1'b0;
        smseq_mod_ts2_rcvd_pulse  <= #TP 1'b0;
        smseq_loc_ts2_rcvd_d  <= #TP 0;
        smseq_in_skp_d        <= #TP 0;
    end else begin
        smseq_ts1_rcvd_pulse  <= #TP int_ts1_rcvd_pulse;
        smseq_ts2_rcvd_pulse  <= #TP int_ts2_rcvd_pulse;
        smseq_mod_ts1_rcvd_pulse  <= #TP 1'b0;
        smseq_mod_ts2_rcvd_pulse  <= #TP 1'b0;
        smseq_loc_ts2_rcvd_d  <= #TP smseq_loc_ts2_rcvd_i;  // no need ts2 -> idle for ts1_ts2_do_deskew
        smseq_in_skp_d        <= #TP smseq_in_skp_i;
    end
end // smseq_ts_rcvd_pulse_PROC

always @* begin : ts2_lid_deskew_PROC
    smseq_loc_ts2_rcvd  = 0;
    smseq_in_skp        = 0;

    smseq_loc_ts2_rcvd  = `CX_RMLH_SCRAMBLE_REGOUT ? smseq_loc_ts2_rcvd_d  : smseq_loc_ts2_rcvd_i;
    smseq_in_skp        = `CX_RMLH_SCRAMBLE_REGOUT ? smseq_in_skp_d        : smseq_in_skp_i;
end // ts2_lid_deskew_PROC

//
// update TS Symbol value when int_sym_count reaches the symbol number
//
always @( * ) begin : update_ts_sym_PROC
    integer i;

    for ( i=0; i<16; i=i+1 ) begin
        dec_ts_sym[i] = (int_sym_count[3]==i & rx_bv[3] & int_in_ts[3]) ? rx_data[31:24] :
                        (int_sym_count[2]==i & rx_bv[2] & int_in_ts[2]) ? rx_data[23:16] :
                        (int_sym_count[1]==i & rx_bv[1] & int_in_ts[1]) ? rx_data[15: 8] :
                        (int_sym_count[0]==i & rx_bv[0] & int_in_ts[0]) ? rx_data[ 7: 0] : int_ts_sym[i];
    end
end // update_ts_sym_PROC


//
//persistency count for received TS
//
//smseq_ts_rcvd_pcnt - special received TS match Tx, smseq_ts_rcvd_mtx_pcnt - match Tx TS. smseq_ts_rcvd_cond_pcnt with conditions
assign int_xmtbyte_eies_sent = 0;

always @( * ) begin : sym_diff_bus_PROC
    integer i;
    sym_diff_bus = 0;

    for ( i=1; i<8; i=i+1 ) begin
        sym_diff_bus[i] = (int_ts_sym[i] != dec_ts_sym[i]); //link num = F7h but not PAD (F7h with with k-char)
    end
end // sym_diff_bus_PROC

assign any_sym_diff = |sym_diff_bus || (rx_lnk_k != rx_lnk_k_d);

// for gen1/2, sym7-15 are ts identifier. if not, ts_error. So only need to check sym1-7.
// for gen1/2, max is 4 syms / clock, so any_sym_diff and int_ts_rcvd_pulse are not in the same clock cycle.
assign xmtbyte_32_ts1_sent = xmtbyte_ts_pcnt >= 32;

assign speed_change_is_1 = 0;

always @(posedge core_clk or negedge core_rst_n) begin : smseq_ts_rcvd_pcnt_PROC
    integer i;

    if ( ~core_rst_n ) begin
        smseq_ts_rcvd_pcnt     <= #TP 0;
        smseq_ts_rcvd_mtx_pcnt <= #TP 0;
        smseq_ts_rcvd_cond_pcnt<= #TP 0;
        latched_sym_updated    <= #TP 0;
    end else if ( int_ts_error ) begin //clear when a ts_error
        smseq_ts_rcvd_pcnt     <= #TP 0;
        smseq_ts_rcvd_mtx_pcnt <= #TP 0;
        smseq_ts_rcvd_cond_pcnt<= #TP 0;
        latched_sym_updated    <= #TP 0;
    end else if ( ltssm_clear ) begin //clear when a state transition
        if ( int_ts_rcvd_pulse ) begin
            smseq_ts_rcvd_pcnt     <= #TP 1;
            smseq_ts_rcvd_mtx_pcnt <= #TP 1;
            smseq_ts_rcvd_cond_pcnt<= #TP 1;
            latched_sym_updated    <= #TP 0;
        end else begin
            smseq_ts_rcvd_pcnt     <= #TP 0;
            smseq_ts_rcvd_mtx_pcnt <= #TP 0;
            smseq_ts_rcvd_cond_pcnt<= #TP 0;
        end

        if ( any_sym_diff && ~int_mod_ts_rcvd_pulse ) //if any symbol difference
            latched_sym_updated    <= #TP 1; //latched until ts_rcvd at the end of the TS

        if ( ltssm_lane_flip_ctrl_chg_pulse )
            smseq_ts_rcvd_mtx_pcnt <= #TP 0; // if lane flip changes, clear the count to re-start count after the flip
    end else begin
        if ( int_ts_rcvd_pulse ) begin //at the end of a TS
            if ( latched_sym_updated || (any_sym_diff && int_mod_ts_rcvd_pulse) ) begin //if any symbol updated (difference)
                if ( speed_change_is_1 )
                    smseq_ts_rcvd_pcnt     <= #TP 1;
                else
                    smseq_ts_rcvd_pcnt     <= #TP 0;

                if ( ~(ltssm_in_l0 || ltssm_in_l123sendeidle || ltssm_in_rcvrylock || ltssm_in_l0s) )
                    smseq_ts_rcvd_cond_pcnt<= #TP 1;

                smseq_ts_rcvd_mtx_pcnt <= #TP 1; //int_xmtbyte_eies_sent ? 0 : 1; 
                latched_sym_updated    <= #TP 0;
            end else begin //no difference, increment until saturation 8
                if ( speed_change_is_1 )
                    smseq_ts_rcvd_pcnt     <= #TP (smseq_ts_rcvd_pcnt < 8) ? smseq_ts_rcvd_pcnt + 1 : smseq_ts_rcvd_pcnt;
                else
                    smseq_ts_rcvd_pcnt     <= #TP 0;

                if ( ~(ltssm_in_l0 || ltssm_in_l123sendeidle || ltssm_in_rcvrylock || ltssm_in_l0s) )
                    smseq_ts_rcvd_cond_pcnt<= #TP (smseq_ts_rcvd_cond_pcnt < 2) ? smseq_ts_rcvd_cond_pcnt + 1 : smseq_ts_rcvd_cond_pcnt;

                smseq_ts_rcvd_mtx_pcnt <= #TP (smseq_ts_rcvd_mtx_pcnt < 8) ? smseq_ts_rcvd_mtx_pcnt + 1 : smseq_ts_rcvd_mtx_pcnt; //(smseq_ts_rcvd_mtx_pcnt < 8) && ~int_xmtbyte_eies_sent ? smseq_ts_rcvd_mtx_pcnt + 1 : smseq_ts_rcvd_mtx_pcnt;
                latched_sym_updated    <= #TP 0;
            end
        end //else begin
//            if ( smseq_ts_rcvd_mtx_pcnt > 0 && int_xmtbyte_eies_sent )
//                smseq_ts_rcvd_mtx_pcnt <= #TP smseq_ts_rcvd_mtx_pcnt - 1;
//        end

        if ( any_sym_diff && ~int_mod_ts_rcvd_pulse ) begin //if any symbol difference
            latched_sym_updated    <= #TP 1; //latched until ts_rcvd at the end of the TS
        end

        // for crosslink in Configuration.Linkwidth.Start state, after 16-32 (pick up 32 here) ts1 sent,
        // then receive 2 ts1s with non-pad link# and pad lane# for DSP or with pad link# and pad lane# for USP
        if ( ~xmtbyte_32_ts1_sent && ltssm_in_cfglinkwdstart )
            smseq_ts_rcvd_cond_pcnt <= #TP 0;
        else if ( (ltssm_in_l0 || ltssm_in_l123sendeidle || ltssm_in_rcvrylock || ltssm_in_l0s) && int_ts_rcvd_pulse ) //for L0, if receive 2 TSs (not need persistency), ltssm move to Recovery
            smseq_ts_rcvd_cond_pcnt <= #TP (smseq_ts_rcvd_cond_pcnt < 3) ? smseq_ts_rcvd_cond_pcnt + 1 : smseq_ts_rcvd_cond_pcnt;

        if ( ltssm_lane_flip_ctrl_chg_pulse )
            smseq_ts_rcvd_mtx_pcnt <= #TP 0; // if lane flip changes, clear the count to re-start count after the flip
    end // end else begin
end // smseq_ts_rcvd_pcnt_PROC


//
// latch ts symbol value
//
assign rxaligned_i = cfg_elastic_buffer_mode ? rxaligned & ~rx_dv : 1'b0; //rxvalid=1 but rxdatavalid=0
always @(posedge core_clk or negedge core_rst_n) begin : latch_ts_sym_PROC
    integer i,j, k;

    if (!core_rst_n) begin
        comma_flag           <= #TP 0;
        in_ts                <= #TP 0;
        in_ts1               <= #TP 0;
        in_mod_ts1           <= #TP 0;
        in_mod_ep            <= #TP 0;
        iv_ts1               <= #TP 0;
        in_ts2               <= #TP 0;
        in_mod_ts2           <= #TP 0;
        iv_ts2               <= #TP 0;
        in_skp               <= #TP 0;
        in_fts               <= #TP 0;
        sym_count            <= #TP 0;
        ts_error             <= #TP 0;
        skp_rcvd             <= #TP 0;
        ts1_rcvd             <= #TP 0;
        ts2_rcvd             <= #TP 0;

        for ( j=1; j<SN+1; j=j+1 ) begin
            int_ts_sym_rcvd[j] <= #TP 0;
        end //for

        for ( k=8; k<16; k=k+1 ) begin
            int_mt_sym_rcvd[k] <= #TP 0;
        end //for

        for ( i=0; i<16; i=i+1 ) begin
            int_ts_sym[i]  <= #TP 0;
        end //for
        int_ts_sym[4]      <= #TP 8'b11111111;

    end else begin

        comma_flag           <= #TP ~rx_err & ((active_nb[2]==1 ? rx_com[3] :
                                               active_nb[1]==1 ? rx_com[1] : rx_com[0]) ? 1 : rxaligned_i ? comma_flag : 0);

        in_ts                <= #TP int_in_ts[NB-1] ? 1 : rxaligned_i ? in_ts : 0;
        in_ts1               <= #TP int_in_ts1[NB-1] ? 1 : rxaligned_i ? in_ts1 : 0;
        in_mod_ts1           <= #TP int_in_mod_ts1[NB-1] ? 1 : rxaligned_i ? in_mod_ts1 : 0;
        in_mod_ep            <= #TP (int_in_mod_ts1[NB-1] | int_in_mod_ts2[NB-1]) ? mod_ep[NB-1] : rxaligned_i ? in_mod_ep : 0;
        iv_ts1               <= #TP inv_in_ts1[NB-1] ? 1 : rxaligned_i ? iv_ts1 : 0;
        in_ts2               <= #TP int_in_ts2[NB-1] ? 1 : rxaligned_i ? in_ts2 : 0;
        in_mod_ts2           <= #TP int_in_mod_ts2[NB-1] ? 1 : rxaligned_i ? in_mod_ts2 : 0;
        iv_ts2               <= #TP inv_in_ts2[NB-1] ? 1 : rxaligned_i ? iv_ts2 : 0;
        in_skp               <= #TP int_in_skp[NB-1] & ~rx_err ? 1 : rxaligned_i ? in_skp : 0;
        in_fts               <= #TP int_in_fts[NB-1] & ~rx_err ? 1 : rxaligned_i ? in_fts : 0;
        sym_count            <= #TP int_sym_count[NB-1];
        ts_error             <= #TP int_ts_error;
        skp_rcvd             <= #TP |int_in_skp[NB-1:0]; //skp length varies, so detect any skp symbol as received
        ts1_rcvd             <= #TP !(int_ts_error | int_ts2_rcvd_pulse) & (int_ts1_rcvd_pulse | ts1_rcvd);
        ts2_rcvd             <= #TP !(int_ts_error | int_ts1_rcvd_pulse) & (int_ts2_rcvd_pulse | ts2_rcvd);

        if ( int_ts_error ) begin
            for ( j=1; j<SN+1; j=j+1 ) begin
                int_ts_sym_rcvd[j] <= #TP 0;
            end //for

            for ( k=8; k<16; k=k+1 ) begin
                int_mt_sym_rcvd[k] <= #TP 0;
            end //for
        end else if ( int_ts_rcvd_pulse ) begin //have to align to ts_rcvd_pulse
            for ( j=1; j<SN+1; j=j+1 ) begin
                int_ts_sym_rcvd[j] <= #TP int_ts_sym[j];
            end //for

            for ( k=8; k<16; k=k+1 ) begin
                int_mt_sym_rcvd[k] <= #TP int_ts_sym[k];
            end //for
        end

        //latch TS symbol once the symbol is received
//        if ( int_ts_error ) begin
//            for ( i=0; i<16; i=i+1 ) begin
//                int_ts_sym[i]      <= #TP 0;
//            end // for
//        end else begin
            for ( i=0; i<16; i=i+1 ) begin
                int_ts_sym[i]      <= #TP dec_ts_sym[i];
            end // for
//        end



        if ( smlh_link_up ) begin // if linkup, clear int_mt_sym_rcvd
            for ( k=8; k<16; k=k+1 ) begin
                int_mt_sym_rcvd[k] <= #TP 0;
            end //for
        end // if ( smlh_link_up
    end
end // latch_ts_sym_PROC

//
// detect PAD link#/lane#
//
always @(posedge core_clk or negedge core_rst_n) begin : plinkn_planen_i_PROC
    if ( ~core_rst_n ) begin
        ts_link_num_is_k237_i <= #TP 0;
        ts_lane_num_is_k237_i <= #TP 0;
//    end else if ( (!smlh_link_in_training && smlh_link_up) || int_ts_error ) begin
//        ts_link_num_is_k237_i <= #TP 0;
//        ts_lane_num_is_k237_i <= #TP 0;
    end else begin
        ts_link_num_is_k237_i <= #TP (int_sym_count[3]==1 & rx_bv[3] & int_in_ts[3]) ? rx_kchar[3] :
                                     (int_sym_count[2]==1 & rx_bv[2] & int_in_ts[2]) ? rx_kchar[2] :
                                     (int_sym_count[1]==1 & rx_bv[1] & int_in_ts[1]) ? rx_kchar[1] :
                                     (int_sym_count[0]==1 & rx_bv[0] & int_in_ts[0]) ? rx_kchar[0] : ts_link_num_is_k237_i;
        ts_lane_num_is_k237_i <= #TP (int_sym_count[3]==2 & rx_bv[3] & int_in_ts[3]) ? rx_kchar[3] :
                                     (int_sym_count[2]==2 & rx_bv[2] & int_in_ts[2]) ? rx_kchar[2] :
                                     (int_sym_count[1]==2 & rx_bv[1] & int_in_ts[1]) ? rx_kchar[1] :
                                     (int_sym_count[0]==2 & rx_bv[0] & int_in_ts[0]) ? rx_kchar[0] : ts_lane_num_is_k237_i;
    end
end // plinkn_planen_i_PROC

always @(posedge core_clk or negedge core_rst_n) begin : plinkn_planen_PROC
    if ( ~core_rst_n ) begin
        ts_link_num_is_k237 <= #TP 0;
        ts_lane_num_is_k237 <= #TP 0;
    end else if ( int_ts_rcvd_pulse ) begin
        ts_link_num_is_k237 <= #TP ts_link_num_is_k237_i;
        ts_lane_num_is_k237 <= #TP ts_lane_num_is_k237_i;
    end
end // plinkn_planen_PROC

//
// Output assignments
//
assign smseq_mt_info             = 0;
assign smseq_ts_info             = {8'h0,int_ts_sym_rcvd[6],int_ts_sym_rcvd[5],int_ts_sym_rcvd[4],int_ts_sym_rcvd[3],int_ts_sym_rcvd[2],int_ts_sym_rcvd[1]};
assign smseq_ts_lanen_linkn_pad  = {ts_lane_num_is_k237,ts_link_num_is_k237};
assign smseq_ts1_rcvd            = ts1_rcvd;
assign smseq_ts2_rcvd            = ts2_rcvd;
assign smseq_ts_error            = ts_error;
assign smseq_inskip_rcv          = skp_rcvd;

//
// determine polarity inversion
// - Reset to 0 when LTSSM enters Detect State
// - Two consecutive Inverted TSs is the condition to detect polarity (rcvd_inv_ts_flag is to remember 1st inverted TS)
// - Polarity Evaluation is done in Polling.Active and Polling.Configuration State
// - In case that MAC wrongly detect polarity inversion, the core can recover if the core is in Polling.Active or Pollin.Configuration
//     - pol_reverse <= #TP ~pol_reverse;
// - When the core changes pol_reverse signal, there will be delay in the PHY from Rxpolarity signal change to Inverted data showing up on RxData signal
//     - During this period, the core must not do polarity evaluation (pol_inv_det_mask_cnt)
//     - The max delay specified in PIPE Spec is 20 PCLK cycles. 
//
reg       rcvd_inv_ts_flag;
reg [4:0] pol_inv_det_mask_cnt;
wire      pol_inv_det_x1;
wire      pol_inv_det_x2;

assign pol_inv_det_x1 = ( pol_inv_det_mask_cnt == 5'h00 ) & ( ltssm_in_pollact | ltssm_in_pollcfg ) & inv_ts_rcvd_pulse & ( rx_invts1[0] | rx_invts2[0]) & ( !cfg_polarity_mode | !pol_reverse );
assign pol_inv_det_x2 = pol_inv_det_x1 & rcvd_inv_ts_flag ;

always @(posedge core_clk or negedge core_rst_n) begin : pol_reverse_PROC
    if ( ~core_rst_n ) begin
        pol_reverse <= #TP 0;
    end else if ( ltssm_in_detect ) begin
        pol_reverse <= #TP 0;
    end else if ( pol_inv_det_x2 ) begin
        pol_reverse <= #TP ~pol_reverse;
    end
end // pol_reverse_PROC

always @(posedge core_clk or negedge core_rst_n) begin : rcvd_inv_ts_flag_PROC
    if ( ~core_rst_n ) begin
        rcvd_inv_ts_flag <= #TP 0;
    end else if ( int_ts_rcvd_pulse || rx_err || pol_inv_det_x2 ) begin
        rcvd_inv_ts_flag <= #TP 0;
    end else if ( pol_inv_det_x1 ) begin
        rcvd_inv_ts_flag <= #TP 1;
    end
end // rcvd_inv_ts_flag_PROC

always @(posedge core_clk or negedge core_rst_n) begin : pol_inv_det_mask_cnt_PROC
    if ( ~core_rst_n ) begin
        pol_inv_det_mask_cnt <= #TP 0;
    end else if ( pol_inv_det_x2 ) begin
        pol_inv_det_mask_cnt <= #TP 1;
    end else if ( pol_inv_det_mask_cnt == 5'h1F || ( !ltssm_in_pollact && !ltssm_in_pollcfg ) ) begin
        pol_inv_det_mask_cnt <= #TP 0;
    end else if ( pol_inv_det_mask_cnt > 5'h00 && (inv_ts_rcvd_pulse || int_ts_rcvd_pulse) ) begin
        pol_inv_det_mask_cnt <= #TP pol_inv_det_mask_cnt + 1;
    end
end // pol_inv_det_mask_cnt_PROC


always @(posedge core_clk or negedge core_rst_n) begin : latch_smseq_rcvr_pol_reverse_PROC
  if (!core_rst_n)
    rcvr_pol_reverse_r <= 0;
  else
    rcvr_pol_reverse_r <=
    pol_reverse;
end // latch_smseq_rcvr_pol_reverse_PROC

assign smseq_rcvr_pol_reverse    = rcvr_pol_reverse_r;

assign int_in_fts[0] = !rx_err & rx_dv & ( (comma_flag ? rx_fts[0] : in_fts & rx_fts[0]) );
assign int_in_fts[1] = !rx_err & rx_dv & (~rx_bv[1] ? int_in_fts[0] : (rx_com[0] ? rx_fts[1] : ( (int_in_fts[0] & rx_fts[1]) )));
assign int_in_fts[2] = !rx_err & rx_dv & (~rx_bv[2] ? int_in_fts[1] : (rx_com[1] ? rx_fts[2] : ( (int_in_fts[1] & rx_fts[2]) )));
assign int_in_fts[3] = !rx_err & rx_dv & (~rx_bv[3] ? int_in_fts[2] : (rx_com[2] ? rx_fts[3] : ( (int_in_fts[2] & rx_fts[3]) )));

assign i_fts_rcvd[0] = int_sym_count[0]==3 & int_in_fts[0];
assign i_fts_rcvd[1] = int_sym_count[1]==3 & int_in_fts[1];
assign i_fts_rcvd[2] = int_sym_count[2]==3 & int_in_fts[2];
assign i_fts_rcvd[3] = int_sym_count[3]==3 & int_in_fts[3];

// latch fts detected
always @( posedge core_clk or negedge core_rst_n ) begin : fts_rcvd_PROC
    if ( ~core_rst_n ) begin
        fts_rcvd <= #TP 0;
    end else if ( ~smlh_in_rl0s ) begin // if LTSSM is not in Rx.L0s, reset
        fts_rcvd <= #TP 0;
    end else if ( |i_fts_rcvd[NB-1:0] ) begin
        fts_rcvd <= #TP 1;
    end
end // fts_rcvd_PROC

// FTS -> SKP transition. once detecting the 1st skp symbol, enable the deskew
// in worst case, FTS and skp rcvd at the same cycle
always @* begin : fts_skp_do_deskew_i_PROC
    smseq_fts_skp_do_deskew_i = 0;

    if ( (fts_rcvd || (|i_fts_rcvd[NB-1:0])) && |int_in_skp[NB-1:0] && ~rx_err ) begin
        smseq_fts_skp_do_deskew_i = 1;
    end
end // fts_skp_do_deskew_i_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : fts_skp_do_deskew_d_PROC
    if ( ~core_rst_n ) begin
        smseq_fts_skp_do_deskew_d <= #TP 0;
    end else if ( ~smlh_in_rl0s ) begin // if LTSSM is not in Rx.L0s, reset
        smseq_fts_skp_do_deskew_d <= #TP 0;
    end else if ( (fts_rcvd || (|i_fts_rcvd[NB-1:0])) && |int_in_skp[NB-1:0] && ~rx_err ) begin
        smseq_fts_skp_do_deskew_d <= #TP 1;
    end
end // fts_skp_do_deskew_d_PROC

always @* begin : fts_skp_do_deskew_PROC
    smseq_fts_skp_do_deskew = 0;

    smseq_fts_skp_do_deskew = `CX_RMLH_SCRAMBLE_REGOUT ? smseq_fts_skp_do_deskew_d : smseq_fts_skp_do_deskew_i;
end // fts_skp_do_deskew_PROC



endmodule
