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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer handler
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rmlh (

// ---- inputs ---------------
    core_clk,
    core_clk_ug,
    core_rst_n,
    cfg_deskew_disable,
    cfg_ts2_lid_deskew,
    cfg_elastic_buffer_mode,
    cfg_fast_link_mode,
    cfg_pipe_garbage_data_mode,
    phy_type,
    latched_smlh_link_up,
    latched_flip_ctrl,
    smlh_lane_flip_ctrl,
    smlh_in_rl0s,
    smlh_link_mode,
    smlh_no_turnoff_lanes,
    smlh_lanes_active,
    power_saving_lanes_active,
    deskew_lanes_active,
    smlh_do_deskew,
    smlh_lnknum_match_dis,
    smlh_link_up,
    smlh_link_in_training,
    smlh_scrambler_disable,
    smlh_ltssm_in_pollconfig,
    ltssm_rcvr_err_rpt_en,
    ltssm_clear,
    ltssm_cxl_ll_mod,
    drift_buffer_deskew_disable,
    ltssm_powerdown,
    ltssm_lpbk_master,
    smlh_ltssm_state,
    smseq_ts1_rcvd_pulse_bus,
    smseq_ts2_rcvd_pulse_bus,
    smseq_loc_ts2_rcvd_bus,
    smseq_in_skp_bus,
    smseq_fts_skp_do_deskew_bus,

    phy_mac_rxdata,
    phy_mac_rxdatak,
    phy_mac_rxvalid,
    phy_mac_rxstatus,
    phy_mac_rxelecidle,
    phy_mac_phystatus,
    active_nb,
    rplh_rdlh_pkt_err,
    mac_phy_rate,
    phy_mac_rxdatavalid,
    pm_current_data_rate,

// ---- outputs ---------------
    current_data_rate,
    pm_current_data_rate_others,
    pm_current_data_rate_xmlh_xmt,
    pm_current_data_rate_xmlh_scr,
    pm_current_data_rate_rplh_pkf,
    pm_current_data_rate_smlh_sqf,
    pm_current_data_rate_smlh_lnk,
    pm_current_data_rate_smlh_eq,
    pm_current_data_rate_ltssm,
    current_powerdown,
    rpipe_rxdata,
    rpipe_rxdatak,
    rpipe_rxerror_dup,
    rpipe_rxdata_dv,
    rpipe_rxelecidle,
    rpipe_rxdetected,
    rpipe_rxdetect_done,
    rpipe_all_phystatus_asserted,
    rpipe_all_phystatus_deasserted,

    rmlh_rcvd_eidle_set,
    rmlh_all_sym_locked,
    act_rmlh_rcvd_eidle_set,
    rmlh_rplh_rxdata,
    rmlh_rplh_rxdatak,
    rmlh_rplh_rxerror,
    rmlh_rplh_dv,
    rmlh_rplh_link_mode,
    rmlh_rplh_active_nb,
    rmlh_rplh_rcvd_idle_gen12,
    rmlh_deskew_alignment_err,
    rmlh_deskew_complete,
    rmlh_rpipe_rxskipremoved,
    rpipe_rxaligned,
    rmlh_rcvd_err
);
parameter INST              = 0;                        // The uniquifying parameter for each port logic instance.
parameter NL                = `CX_NL;                   // Max number of lanes supported
parameter NB                = `CX_NB;                   // Number of symbols (bytes) per clock cycle
parameter NBK               = `CX_NBK;                  // Number of symbols (bytes) per clock cycle for datak
parameter AW                = `CX_ANB_WD;               // Width of the active number of bytes
parameter NW                = `CX_PL_NW;                // Number of 32-bit dwords handled by the datapath each clock.
parameter DW                = (32*NW);                  // Width of datapath in bits.
parameter TP                = `TP;                      // Clock to Q delay (simulator insurance)
parameter L2NL              = NL==1 ? 1 : `CX_LOGBASE2(NL);   // log2 number of NL

// -----------------------------------------------------------------------------
// inputs
// -----------------------------------------------------------------------------

input                   core_clk;
input                   core_clk_ug;                    // An ungated version of core_clk used to track phystatus during powerdown states
input                   core_rst_n;
input                   cfg_deskew_disable;             // Disable the lane-to-lane deskew logic
input                   cfg_ts2_lid_deskew;             // do deskew at the transition from ts2 to Logic_Idle_data transition
input                   cfg_elastic_buffer_mode;        // 0 - nominal half full mode, 1 - empty mode
input                   cfg_fast_link_mode;             // for simulation
input                   cfg_pipe_garbage_data_mode;     // 0 - discard garbage data until Rxvalid is de-asserted 1: until next valid data 
input                   phy_type;                       // Mac type

// from XMLH
input                   smlh_in_rl0s;                   // ltssm is in Rx.L0s
input   [5:0]           smlh_link_mode;                 // 1000 --- x8 mode, 0100 ---- x4 mode, 0010 ---- x2 mode, 0001 ---- x1 mode
input   [NL-1:0]        smlh_no_turnoff_lanes;          // no turnoff lanes after linkup
input   [NL-1:0]        smlh_lanes_active;              // Which lanes are actively (begin) configured
input   [NL-1:0]        power_saving_lanes_active;      // lanes_active or LTSSM=config -- When LTSSM=config, all lanes are active
input   [NL-1:0]        deskew_lanes_active;            // Which lanes are actively (begin) configured, goes only to deskew logic
input                   smlh_do_deskew;                 // Indicate to the deskew block when it is valid to deskew
input                   smlh_lnknum_match_dis;          // This signal is designed to notify the rmlh block when to enable link number match checking
input                   smlh_link_up;                   // XMLH link is up when asserted.
input                   smlh_link_in_training;
input                   ltssm_rcvr_err_rpt_en;          // Enable rcvr errors, based on LTSSM state
input                   ltssm_clear;                    // clear signal from LTSSM
input   [5:0]           smlh_ltssm_state;               // Current state of Link Training and Status State Machine
input   [1:0]           ltssm_cxl_ll_mod;               // {drift_buffer, common_clk} enabled
input                   drift_buffer_deskew_disable;
input   [1:0]           ltssm_powerdown;                // From LTSSM indicating power down state (P0/P0s/P1). P2 State is controlled by
input                   ltssm_lpbk_master;              // Loopback master
input                   smlh_ltssm_in_pollconfig;       // this signal enables receiver to detect the polarity and invert if necessary.
input                   smlh_scrambler_disable;         // when asserted, scramble is disabled.
input                   latched_smlh_link_up;
input   [L2NL-1:0]      latched_flip_ctrl;
input   [L2NL-1:0]      smlh_lane_flip_ctrl;
input   [NL-1:0]        smseq_ts1_rcvd_pulse_bus;
input   [NL-1:0]        smseq_ts2_rcvd_pulse_bus;
input   [NL*4-1:0]      smseq_loc_ts2_rcvd_bus;
input   [NL*4-1:0]      smseq_in_skp_bus;
input   [NL-1:0]        smseq_fts_skp_do_deskew_bus;

// from PIPE Phy
input   [(NL*NB*8)-1:0] phy_mac_rxdata;                 // PHY_mac* interface is designed for PIPE spec. receive interface. data contains the pkt data
input   [(NL*NB)-1:0]   phy_mac_rxdatak;                // K char indication
input   [NL-1:0]        phy_mac_rxvalid;                // PIPE receive data valid signal
input   [(NL*3)-1:0]    phy_mac_rxstatus;               // PIPE receive status
input   [NL-1:0]        phy_mac_rxelecidle;             // PIPE receive RX electrical idle signal
input   [NL-1:0]        phy_mac_phystatus;              // PIPE PHY status signal
input   [AW-1:0]        active_nb;                      // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s
input   [NW-1:0]        rplh_rdlh_pkt_err;              // error indication
input   [2:0]           mac_phy_rate;                   // requested rate change from MAC to PHY
input   [NL-1:0]        phy_mac_rxdatavalid;            //Rx dataskip
input   [2:0]           pm_current_data_rate;           // current_data_rate shadowed in pm_ctrl

// -----------------------------------------------------------------------------
// outputs
// -----------------------------------------------------------------------------

// To the Phy
output  [(NL*NB*8)-1:0] rpipe_rxdata;
output  [(NL*NBK)-1:0]  rpipe_rxdatak;
output  [(NL*NB)-1:0]   rpipe_rxerror_dup;
output  [NL-1:0]        rpipe_rxdata_dv;                //
output  [NL-1:0]        rpipe_rxelecidle;               // RCVR rx electrical idle indication
output  [NL-1:0]        rpipe_rxdetected;               // RCVR rx detected
output                  rpipe_rxdetect_done;            // RCVR rx detection done signal designed for LTSSM to make the next transition from detect_active state
output                  rpipe_all_phystatus_asserted;   // RMLH pipe module monitors the phy_mac_phystatus for all lanes and generated this signal when all lanes are in agreement
output                  rpipe_all_phystatus_deasserted; // RMLH pipe module monitors the phy_mac_phystatus for all lanes and generated this signal when all lanes are in agreement

// to XMLH
output                  rmlh_all_sym_locked;            // symbol locked on all active lanes

output                  rmlh_rcvd_eidle_set;            // receiver rcvd eidle set.
output  [NL-1:0]        act_rmlh_rcvd_eidle_set;        // receiver rcvd eidle set per lane.
output  [2:0]           current_data_rate;              // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_others;    // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_xmlh_xmt;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_xmlh_scr;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_rplh_pkf;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_smlh_sqf;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_smlh_lnk;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_smlh_eq;   // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_ltssm;     // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4


output  [1:0]           current_powerdown;              // PHY changed powerdown

// to RPLH
output  [(NL*NB*8)-1:0] rmlh_rplh_rxdata;
output  [(NL*NB)-1:0]   rmlh_rplh_rxdatak;
output  [(NL*NB)-1:0]   rmlh_rplh_rxerror;
output                  rmlh_rplh_dv;
output  [5:0]           rmlh_rplh_link_mode;
output  [3:0]           rmlh_rplh_active_nb;
output  [1:0]           rmlh_rplh_rcvd_idle_gen12;

output                  rmlh_rcvd_err;                  // other receive errors detected (not necessary within a pkt)
output                  rmlh_deskew_alignment_err;      // Lanes fell out of alignement
output                  rmlh_deskew_complete;           // Lanes are deskewed
output  [NL-1:0]        rmlh_rpipe_rxskipremoved;       // Indicates skip removed in elastic buffer
output  [NL-1:0]        rpipe_rxaligned;                // Indicates rxvalid asserted

wire                    rmlh_deskew_bypass;
wire                    rmlh_deskew_rxdata_dv;
wire    [(NL*NB*8)-1:0] rmlh_deskew_rxdata;
wire    [(NL*NB)-1:0]   rmlh_deskew_rxdatak;
wire    [(NL*NB)-1:0]   rmlh_deskew_rxerror;
wire                    rmlh_deskew_alignment_err;
wire                    rmlh_deskew_complete;
wire                    rmlh_deskew_rxdata_flush_gen12;  // active high RX data flushing to pkt_finer for Gen1/2 rate
wire    [NL-1:0]        rmlh_deskew_ds_g12;              // in data stream

// Scramble logic
wire    [(NL*NB*8)-1:0] descrambled_rxdata;
wire    [NL -1:0]       descrambled_rxdata_dv;
wire    [NL -1:0]       descrambled_rxaligned;
wire    [(NL*NB)-1:0]   descrambled_rxdata_comma;
wire    [(NL*NB)-1:0]   descrambled_rxdata_skip;
wire    [(NL*NB)-1:0]   descrambled_rxdata_skprm;
wire    [(NL*NBK)-1:0]  descrambled_rxdatak;
wire    [(NL*NB)-1:0]   descrambled_rxerror;

wire    [NL-1:0]        rpipe_rxerror;
wire    [NL-1:0]        tmp_phy_err;
wire                    rmlh_rcvd_err;
wire  [NL-1:0]          rpipe_rxaligned;              // direct from phy_mac_rxvalid. gates: must revisit


// Decoded signals from PIPE
wire    [NL-1:0]        rpipe_rxelecidle;
wire    [(NL*NB*8)-1:0] rpipe_rxdata;
wire    [(NL*NBK)-1:0]  rpipe_rxdatak;
wire    [NL-1:0]        rpipe_rxdata_dv;
wire                    rpipe_eios_eieos_det;
wire    [NL-1:0]        rpipe_rxskipremoved;
wire    [NL-1:0]        rpipe_rxcodeerror;
wire    [NL-1:0]        rpipe_rxdisperror;
wire    [NL-1:0]        rpipe_rxunderflow;
wire    [NL-1:0]        rpipe_rxoverflow;
wire    [2:0]           current_data_rate;
wire    [2:0]           pm_current_data_rate_others;
wire    [2:0]           pm_current_data_rate_xmlh_xmt;
wire    [2:0]           pm_current_data_rate_xmlh_scr;
wire    [2:0]           pm_current_data_rate_rmlh_dsk;
wire    [2:0]           pm_current_data_rate_rmlh_scr;
wire    [2:0]           pm_current_data_rate_rplh_pkf;
wire    [2:0]           pm_current_data_rate_smlh_sqf;
wire    [2:0]           pm_current_data_rate_smlh_lnk;
wire    [2:0]           pm_current_data_rate_smlh_eq;
wire    [2:0]           pm_current_data_rate_ltssm;



// Turn off disparity error when using RocketIO PHY
    assign rpipe_rxerror   = (rpipe_rxcodeerror | rpipe_rxdisperror);
assign tmp_phy_err     = (deskew_lanes_active & rpipe_rxerror);

reg rmlh_rcvd_err_d;
always @(posedge core_clk or negedge core_rst_n)
begin : latch_rmlh_rcvd_err
  if (!core_rst_n)
    rmlh_rcvd_err_d <= #TP 0;
  else
    rmlh_rcvd_err_d <= #TP 
                           ((|tmp_phy_err) & ltssm_rcvr_err_rpt_en & (pm_current_data_rate_rmlh_dsk < `GEN3_RATE)); // only 8b10b error is required to be reported
end

assign rmlh_rcvd_err   = rmlh_rcvd_err_d;

// Reversed data buses
wire    [(NL*NB*8)-1:0] rmlh_reversed_rxdata;
wire                    rmlh_reversed_rxdata_dv;
wire    [(NL*NB)-1:0]   rmlh_reversed_rxdatak;
wire    [(NL*NB)-1:0]   rmlh_reversed_rxerror;

// PIPE only provides one error per symbol time, rest of core supports 1 per symbol. Duplicate here.
reg     [(NL*NB)-1:0]   rpipe_rxerror_dup;
always @(rpipe_rxerror)
begin : duplicate_rxerror
    integer ln, sym;
    for (ln=0; ln<NL; ln=ln+1)
        for (sym=0; sym<NB; sym=sym+1)
            rpipe_rxerror_dup[ln*NB+sym] = rpipe_rxerror[ln];
end


wire rpipe_all_sym_locked;
wire rmlh_all_sym_locked;
assign rmlh_all_sym_locked = rpipe_all_sym_locked;

// convert pipe inputs to our internal signals
rmlh_pipe
 #(INST) u_rmlh_pipe(
// ---- inputs ---------------
    .core_rst_n                     (core_rst_n),
    .core_clk                       (core_clk),
    .core_clk_ug                    (core_clk_ug),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_pipe_garbage_data_mode     (cfg_pipe_garbage_data_mode),
    .phy_type                       (phy_type),
    .ltssm_clear                    (ltssm_clear),
    .ltssm_powerdown                (ltssm_powerdown),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .mac_phy_rate                   (mac_phy_rate),
    .phy_mac_rxdata                 (phy_mac_rxdata),
    .phy_mac_rxdatak                (phy_mac_rxdatak),
    .phy_mac_rxvalid                (phy_mac_rxvalid),
    .phy_mac_rxdatavalid            (phy_mac_rxdatavalid),
    .phy_mac_rxstatus               (phy_mac_rxstatus),
    .phy_mac_rxelecidle             (phy_mac_rxelecidle),
    .phy_mac_phystatus              (phy_mac_phystatus),
    .smlh_lanes_active              (smlh_lanes_active),
    .smlh_link_up                   (smlh_link_up),
    .smlh_no_turnoff_lanes          (smlh_no_turnoff_lanes),
    .active_nb                      (active_nb),
    .pm_current_data_rate           (pm_current_data_rate),


// ---- outputs ---------------
    .current_data_rate              (current_data_rate),
    .current_data_rate_others       (pm_current_data_rate_others),
    .current_data_rate_xmlh_xmt     (pm_current_data_rate_xmlh_xmt),
    .current_data_rate_xmlh_scr     (pm_current_data_rate_xmlh_scr),
    .current_data_rate_rmlh_dsk     (pm_current_data_rate_rmlh_dsk),
    .current_data_rate_rmlh_scr     (pm_current_data_rate_rmlh_scr),
    .current_data_rate_rmlh_pkf     (pm_current_data_rate_rplh_pkf),
    .current_data_rate_smlh_sqf     (pm_current_data_rate_smlh_sqf),
    .current_data_rate_smlh_lnk     (pm_current_data_rate_smlh_lnk),
    .current_data_rate_smlh_eq      (pm_current_data_rate_smlh_eq),
    .current_data_rate_ltssm        (pm_current_data_rate_ltssm),
    .current_powerdown              (current_powerdown),
    .rpipe_rxdata                   (rpipe_rxdata),
    .rpipe_rxdatak                  (rpipe_rxdatak),
    .rpipe_rxdata_dv                (rpipe_rxdata_dv),
    .rpipe_rxaligned                (rpipe_rxaligned),    //gates: must revisit
    .rpipe_rxskipadded              (),
    .rpipe_rxskipremoved            (rpipe_rxskipremoved),
    .rpipe_all_sym_locked           (rpipe_all_sym_locked),
    .rpipe_rxcodeerror              (rpipe_rxcodeerror),
    .rpipe_rxdisperror              (rpipe_rxdisperror),
    .rpipe_rxunderflow              (rpipe_rxunderflow),
    .rpipe_rxoverflow               (rpipe_rxoverflow),
    .rpipe_rxelecidle               (rpipe_rxelecidle),
    .rpipe_rcvd_eidle_set           (rmlh_rcvd_eidle_set),
    .rpipe_eios_eieos_det           (rpipe_eios_eieos_det),
    .act_rpipe_rcvd_eidle_set       (act_rmlh_rcvd_eidle_set)
    ,
    .rpipe_rxdetected               (rpipe_rxdetected),
    .rpipe_rxdetect_done            (rpipe_rxdetect_done),
    .rpipe_all_phystatus_asserted   (rpipe_all_phystatus_asserted),
    .rpipe_all_phystatus_deasserted (rpipe_all_phystatus_deasserted)
); //rmlh_pipe

assign rmlh_rpipe_rxskipremoved  =  rpipe_rxskipremoved ;

// Lane-to-Lane Deskew Logic Bypass.
assign rmlh_deskew_bypass =                            (`CX_DESKEW_DISABLE)                                                                                 ? 1'b1 : // PHY performs Lane-to-Lane Deskew (Gen1/Gen2 Rate)
                                                                                                                     cfg_deskew_disable ; // Deskew Disable bit in Lane Skew Port Logic Register


rmlh_deskew
 #(INST) u_rmlh_deskew (
// ---- inputs ---------------
    .core_rst_n                       (core_rst_n),
    .core_clk                         (core_clk),
    .cfg_elastic_buffer_mode          (cfg_elastic_buffer_mode),
    .cfg_ts2_lid_deskew               (cfg_ts2_lid_deskew),
    .rmlh_deskew_bypass               (rmlh_deskew_bypass),
    .ltssm_cxl_ll_mod                 (ltssm_cxl_ll_mod),
    .drift_buffer_deskew_disable      (drift_buffer_deskew_disable),
    .deskew_lanes_active              (deskew_lanes_active),
    .smlh_in_rl0s_i                   (smlh_in_rl0s),
    .smlh_do_deskew_i                 (smlh_do_deskew),
    .smseq_ts1_rcvd_pulse_bus_i       (smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse_bus_i       (smseq_ts2_rcvd_pulse_bus),
    .smseq_loc_ts2_rcvd_bus_i         (smseq_loc_ts2_rcvd_bus),
    .smseq_in_skp_bus_i               (smseq_in_skp_bus),
    .smseq_fts_skp_do_deskew_bus_i    (smseq_fts_skp_do_deskew_bus),
    .active_nb                        (active_nb),
    .rxdata_dv_i                      (descrambled_rxdata_dv),
    .rxaligned_i                      (descrambled_rxaligned),
    .rxdata_i                         (descrambled_rxdata),
    .rxdata_comma_i                   (descrambled_rxdata_comma),
    .rxdata_skip_i                    (descrambled_rxdata_skip),
    .rxdata_skprm_i                   (descrambled_rxdata_skprm),
    .rxdatak_i                        (descrambled_rxdatak),
    .rxerror_i                        (descrambled_rxerror),
    .current_data_rate                (pm_current_data_rate_rmlh_dsk),
    .smlh_ltssm_state_i               (smlh_ltssm_state),
    .ltssm_lpbk_master_i              (ltssm_lpbk_master),
    .cxl_mode_enable                  (1'b0),
    .phy_type                         (phy_type),
    .rxunderflow_i                    (rpipe_rxunderflow),
    .rxoverflow_i                     (rpipe_rxoverflow),
    .rpipe_eios_eieos_det_i           (rpipe_eios_eieos_det),
// ---- outputs ---------------
    .deskew_rxdata_dv                 (rmlh_deskew_rxdata_dv),
    .deskew_rxdata                    (rmlh_deskew_rxdata),
    .deskew_rxdatak                   (rmlh_deskew_rxdatak),
    .deskew_rxerror                   (rmlh_deskew_rxerror),
    .deskew_rxdata_flush_gen12        (rmlh_deskew_rxdata_flush_gen12),
    .deskew_ds_g12                    (rmlh_deskew_ds_g12),
    .deskew_alignment_err             (rmlh_deskew_alignment_err),
    .deskew_complete                  (rmlh_deskew_complete)
); //rmlh_deskew

// Lane Reversal Logic Bypass.
assign rmlh_reversed_rxdata_dv = rmlh_deskew_rxdata_dv;
assign rmlh_reversed_rxdata    = rmlh_deskew_rxdata;
assign rmlh_reversed_rxdatak   = rmlh_deskew_rxdatak;
assign rmlh_reversed_rxerror   = rmlh_deskew_rxerror;

//CALC_PARITY_BEFORE_SCRAMBLE=1 denotes SKP parity calculation done before de-scrambling in Rx side
scramble
 #(.INST(INST), .REGOUT(`CX_RMLH_SCRAMBLE_REGOUT), .GEN3_REGIN(`CX_RMLH_GEN3_SCRAMBLE_REGIN), .GEN3_REGOUT(`CX_RMLH_GEN3_SCRAMBLE_REGOUT), .CALC_PARITY_BEFORE_SCRAMBLE(1)) u_scramble (
// ---- inputs ---------------
    .core_rst_n                     (core_rst_n),
    .core_clk                       (core_clk),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .scrambler_disable              (smlh_scrambler_disable),
    .data_dv                        (rpipe_rxdata_dv),
    .data                           (rpipe_rxdata),
    .datak                          (rpipe_rxdatak),
    .error                          (rpipe_rxerror_dup),
    .rxskipremoved                  (rpipe_rxskipremoved),
    .active_nb                      (active_nb),
    .aligned                        (rpipe_rxaligned),  //gates: mustt revisit
    .latched_smlh_link_up           (latched_smlh_link_up),
    .latched_flip_ctrl              (latched_flip_ctrl),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),
    .deskew_ds_g12                  (rmlh_deskew_ds_g12),
    .lanes_active                   (power_saving_lanes_active),

// ---- outputs ---------------
    .scramble_data_dv               (descrambled_rxdata_dv),
    .scramble_aligned               (descrambled_rxaligned),
    .scramble_data                  (descrambled_rxdata),
    .scramble_data_comma            (descrambled_rxdata_comma),
    .scramble_data_skip             (descrambled_rxdata_skip),
    .scramble_data_skprm            (descrambled_rxdata_skprm),
    .scramble_datak                 (descrambled_rxdatak),
    .scramble_error                 (descrambled_rxerror)
); //scramble



rmlh_byte_order
 #(INST) u_rmlh_byte_order (
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .smlh_link_mode                 (smlh_link_mode),
    .deskew_lanes_active            (deskew_lanes_active),
    .active_nb                      (active_nb[3:0]),
    .rxdata_flush_gen12_in          (rmlh_deskew_rxdata_flush_gen12),
    .rxdata_dv_in                   (rmlh_reversed_rxdata_dv),
    .rxdata_in                      (rmlh_reversed_rxdata),
    .rxdatak_in                     (rmlh_reversed_rxdatak),
    .rxerror_in                     (rmlh_reversed_rxerror),
// ---- outputs ---------------
    .rmlh_rplh_rxdata               (rmlh_rplh_rxdata),
    .rmlh_rplh_rxdatak              (rmlh_rplh_rxdatak),
    .rmlh_rplh_rxerror              (rmlh_rplh_rxerror),
    .rmlh_rplh_dv                   (rmlh_rplh_dv),
    .rmlh_rplh_link_mode            (rmlh_rplh_link_mode),
    .rmlh_rplh_active_nb            (rmlh_rplh_active_nb),
    .rmlh_rplh_rcvd_idle_gen12      (rmlh_rplh_rcvd_idle_gen12)
); //rmlh_byte_order



endmodule
