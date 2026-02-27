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
// ---    $DateTime: 2019/10/03 14:27:33 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_seq_finder.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC Layer Handler Sequence Finder
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module smlh_seq_finder
#(
    parameter   INST              = 0,                    // The uniquifying parameter for each port logic instance.
    parameter   NL                = `CX_NL,               // Max number of lanes supported
    parameter   NB                = `CX_NB,               // Number of symbols (bytes) per clock cycle
    parameter   AW                = `CX_ANB_WD,           // Width of the active number of bytes
    parameter  TSFD_WD            = `CX_TS_FIELD_CONTROL_WD, // sym7,6,5,4,3,2,1
    parameter  G12_NB             = `CX_MAC_SMODE_GEN1    // Max Number of symbols (bytes) per clock cycle for Gen1/Gen2 specific modules
)
(
    input                    core_clk,
    input                    core_rst_n,
    input                    ltssm_lane_flip_ctrl_chg_pulse,
    input                    smlh_link_up,
    input                    smlh_link_in_training,
    input   [AW-1:0]         active_nb,
    input                    smlh_in_rl0s,                 // LTSSM is in Rx.L0s
    input                    cfg_ts2_lid_deskew,           // ts2/skp/eieos -> idle do deskew
    input   [NL-1:0]         rxdata_dv,
    input   [NL-1:0]         rxaligned,
    input   [(NL*NB*8)-1:0]  rxdata,
    input   [(NL*NB)-1:0]    rxdatak,
    input   [(NL*NB)-1:0]    rxerror,
    input   [NL-1:0]         rxskipremoved,                // PHY removed SKP symbol aligning to COM or RxStartBlock
    input   [5:0]            smlh_ltssm_state,             // Current state of Link Training and Status State Machine
    input                    cfg_upstream_port,
    input                    cfg_elastic_buffer_mode,
    input                    cfg_polarity_mode,              // 0: polarity detection in Polling.Active 1: polarity detection in Polling.Compliance
    input   [2:0]            current_data_rate,
    input                    ltssm_clear,                  // used to clear TS persistency count on a ltssm state transition
    input                    ltssm_mod_ts,                 // both sides support Modified TS
    input   [10:0]           xmtbyte_ts_pcnt,
    input                    xmtbyte_ts1_sent,
    input                    xmtbyte_skip_sent,

    //----------------- outputs--------------------------------------------
    output  [NL*TSFD_WD-1:0] smseq_ts_info,               // sym7-1
    output  [NL*64-1:0]      smseq_mt_info,               // sym15-8
    output  [NL*2-1:0]       smseq_ts_lanen_linkn_pad,    // pad-lane, pad-link
    output  [NL*4-1:0]       smseq_ts_rcvd_mtx_pcnt,      // persistency count of matching Tx
    output  [NL*4-1:0]       smseq_ts_rcvd_pcnt,          // persistency count of purely rcvd TS
    output  [NL*2-1:0]       smseq_ts_rcvd_cond_pcnt,     // persistency count with conditions
    output  [NL-1:0]         smseq_inskip_rcv,
    output  [NL-1:0]         smseq_sds_rcvd,
    output  [NL-1:0]         smseq_ts1_rcvd,
    output  [NL-1:0]         smseq_ts2_rcvd,
    output  [NL-1:0]         smseq_ts1_rcvd_pulse,
    output  [NL-1:0]         smseq_ts2_rcvd_pulse,
    output  [NL-1:0]         smseq_mod_ts1_rcvd_pulse,
    output  [NL-1:0]         smseq_mod_ts2_rcvd_pulse,
    output  [NL*4-1:0]       smseq_loc_ts2_rcvd,
    output  [NL*4-1:0]       smseq_in_skp,
    output  [NL-1:0]         smseq_fts_skp_do_deskew,
    output  [NL-1:0]         smseq_ts_error,
    output  [NL-1:0]         smseq_rcvr_pol_reverse
);

//declared signals
wire  [(NL*G12_NB*8)-1:0] smseq_g12_rxdata;
wire  [(NL*G12_NB)-1:0]   smseq_g12_rxdatak;
wire  [(NL*G12_NB)-1:0]   smseq_g12_rxerror;
wire  [NL-1:0]            smseq_g12_inskip_rcv;
wire  [NL-1:0]            smseq_g12_sds_rcvd;
wire  [NL-1:0]            smseq_g12_ts1_rcvd;
wire  [NL-1:0]            smseq_g12_ts2_rcvd;
wire  [NL-1:0]            smseq_g12_ts1_rcvd_pulse;
wire  [NL-1:0]            smseq_g12_ts2_rcvd_pulse;
wire  [NL-1:0]            smseq_g12_ts_error;
wire  [(NL*8)-1:0]        smseq_g12_ts_link_num;          // 8 bit link number;
wire  [NL-1:0]            smseq_g12_ts_link_num_is_k237;  // indicates whether or not received Kchar with k237
wire  [(NL*8)-1:0]        smseq_g12_ts_lane_num;          // 8 bit lane number;
wire  [NL-1:0]            smseq_g12_ts_lane_num_is_k237;  // Indicates whether or not received Kchar with k237
wire  [(NL*8)-1:0]        smseq_g12_ts_nfts;              // 8 bits nfts number contained in training sequence
wire  [(NL*5)-1:0]        smseq_g12_ts_link_ctrl;         // 5 bits
wire  [NL-1:0]            smseq_g12_ts_speed_change;      // Requesting to change the speed of operation.
wire  [NL-1:0]            smseq_g12_ts_auto_change;       // Indicate autonomous speed change
wire  [(NL*5)-1:0]        smseq_g12_ts_data_rate;         // Bit 0 = 1, generation 1 (2.5 Gb/s) data rate supported
wire  [NL-1:0]            smseq_g12_ineies_rcv;           // Electrical Idle Exit Level signal
wire  [NL-1:0]            smseq_g12_mcs_rcvd;             // Modified Compliance Sequence detected

wire  [NL*TSFD_WD-1:0]    smseq_g12_ts_info;
wire  [NL*64-1:0]         smseq_g12_mt_info;
wire  [NL*2-1:0]          smseq_g12_ts_lanen_linkn_pad;
wire  [NL*4-1:0]          smseq_g12_ts_rcvd_mtx_pcnt;
wire  [NL*4-1:0]          smseq_g12_ts_rcvd_pcnt;
wire  [NL*2-1:0]          smseq_g12_ts_rcvd_cond_pcnt;
wire  [NL*TSFD_WD-1:0]    smseq_g3_ts_info;
wire  [NL*2-1:0]          smseq_g3_ts_lanen_linkn_pad;
wire  [NL*4-1:0]          smseq_g3_ts_rcvd_mtx_pcnt;
wire  [NL*4-1:0]          smseq_g3_ts_rcvd_pcnt;
wire  [NL*2-1:0]          smseq_g3_ts_rcvd_cond_pcnt;

assign smseq_ts_rcvd_pcnt       = smseq_g12_ts_rcvd_pcnt;
assign smseq_ts_rcvd_cond_pcnt  = smseq_g12_ts_rcvd_cond_pcnt;
assign smseq_ts_rcvd_mtx_pcnt   = smseq_g12_ts_rcvd_mtx_pcnt;
assign smseq_ts_info            = smseq_g12_ts_info;
assign smseq_mt_info            = smseq_g12_mt_info;
assign smseq_ts_lanen_linkn_pad = smseq_g12_ts_lanen_linkn_pad;


assign {smseq_inskip_rcv, smseq_sds_rcvd, smseq_ts1_rcvd, smseq_ts2_rcvd, smseq_ts1_rcvd_pulse, smseq_ts2_rcvd_pulse, smseq_ts_error
        } =


       {smseq_g12_inskip_rcv, {NL{1'b0}}, smseq_g12_ts1_rcvd, smseq_g12_ts2_rcvd, smseq_g12_ts1_rcvd_pulse, smseq_g12_ts2_rcvd_pulse, smseq_g12_ts_error
        };


assign smseq_g12_rxdata  = rxdata[(NL*G12_NB*8)-1:0];
assign smseq_g12_rxdatak = rxdatak[(NL*G12_NB)-1:0];
assign smseq_g12_rxerror = rxerror[(NL*G12_NB)-1:0];

smlh_seq_finder_slv
 #(.INST(INST),.NB(G12_NB)) u_smlh_seq_finder_slv[NL-1:0] (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .smlh_link_up                   (smlh_link_up),
    .smlh_link_in_training          (smlh_link_in_training),
    .active_nb                      (active_nb[3:0]),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .rxdata_dv_in                   (rxdata_dv[NL-1:0]),
    .rxaligned                      (rxaligned[NL-1:0]),
    .rxskipremoved_in               (rxskipremoved[NL-1:0]),
    .rxdata_in                      (smseq_g12_rxdata[(NL*G12_NB*8)-1:0]),
    .rxdatak_in                     (smseq_g12_rxdatak[(NL*G12_NB)-1:0]),
    .rxerror_in                     (smseq_g12_rxerror[(NL*G12_NB)-1:0]),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_polarity_mode              (cfg_polarity_mode),
    .current_data_rate              (current_data_rate),
    .ltssm_clear                    (ltssm_clear),
    .ltssm_mod_ts                   (ltssm_mod_ts),
    .xmtbyte_ts_pcnt                (xmtbyte_ts_pcnt),
    .smseq_ts_info                  (smseq_g12_ts_info[NL*TSFD_WD-1:0]),
    .smseq_mt_info                  (smseq_g12_mt_info[NL*64-1:0]),
    .smseq_ts_lanen_linkn_pad       (smseq_g12_ts_lanen_linkn_pad[NL*2-1:0]),
    .smseq_ts_rcvd_mtx_pcnt         (smseq_g12_ts_rcvd_mtx_pcnt[NL*4-1:0]),
    .smseq_ts_rcvd_pcnt             (smseq_g12_ts_rcvd_pcnt[NL*4-1:0]),
    .smseq_ts_rcvd_cond_pcnt        (smseq_g12_ts_rcvd_cond_pcnt[NL*2-1:0]),
    .smseq_inskip_rcv               (smseq_g12_inskip_rcv[NL-1:0]),
    .smseq_ts_error                 (smseq_g12_ts_error[NL-1:0]),
    .smseq_ts1_rcvd                 (smseq_g12_ts1_rcvd[NL-1:0]),
    .smseq_ts2_rcvd                 (smseq_g12_ts2_rcvd[NL-1:0]),
    .smseq_ts1_rcvd_pulse           (smseq_g12_ts1_rcvd_pulse[NL-1:0]),
    .smseq_ts2_rcvd_pulse           (smseq_g12_ts2_rcvd_pulse[NL-1:0]),
    .smseq_mod_ts1_rcvd_pulse       (smseq_mod_ts1_rcvd_pulse[NL-1:0]),
    .smseq_mod_ts2_rcvd_pulse       (smseq_mod_ts2_rcvd_pulse[NL-1:0]),
    .smseq_loc_ts2_rcvd             (smseq_loc_ts2_rcvd[NL*4-1:0]),
    .smseq_in_skp                   (smseq_in_skp[NL*4-1:0]),
    .smseq_fts_skp_do_deskew        (smseq_fts_skp_do_deskew[NL-1:0]),
    .smseq_rcvr_pol_reverse         (smseq_rcvr_pol_reverse[NL-1:0])
); //smlh_seq_finder_slv


endmodule
