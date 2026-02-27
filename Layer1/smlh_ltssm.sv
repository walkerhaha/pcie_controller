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
// ---    $DateTime: 2020/10/14 02:47:19 $
// ---    $Revision: #50 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_ltssm.sv#50 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit MAC layer Handler Link State Machine
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"


 module smlh_ltssm
#(
    parameter   INST    = 0,                             // The uniquifying parameter for each port logic instance.
    parameter   NB      = `CX_NB,                        // Number of symbols (bytes) per clock cycle
    parameter   NL      = `CX_NL,                        // Number of lanes
    parameter   AW      = `CX_ANB_WD,                    // Width of the active number of bytes
    parameter   TP      = `TP,                           // Clock to Q delay (simulator insurance)
    parameter   L2NL    = NL==1 ? 1 : `CX_LOGBASE2(NL),  // log2 number of NL
    parameter   REGIN   = 1,                             // Optional input registration
    parameter   T_WD    = 25 // timer bit width
)
(
    // -----------------------------------------------------------------------------
    // Inputs/Outputs declaration
    // -----------------------------------------------------------------------------
    // ------------ Inputs -----------------
    input                core_clk,
    input                core_rst_n,
    // Beneath are the interface to CDM where software configures the intended
    // operation condition for link
    input                cfg_ts2_lid_deskew,
    input                cfg_support_part_lanes_rxei_exit,// Polling.Active -> Polling.Configuration based on part of predetermined lanes Rx EI exit
    input                cfg_upstream_port,               // port has been configured as an upstream port
    input                cfg_root_compx,                  // port has been configured as a root complex
    input   [7:0]        cfg_n_fts,                       // number of fast training sequence required by PHY
    input                cfg_scrmb_dis,                   // scrambler disable enable, for RC to turn off the downstream port's scramber
    input                cfg_link_dis,                    // link disable enable, for RC to disable the downstream port's link
    input   [1:0]        cfg_select_deemph_mux_bus,       // sel deempahsis {bit, var}
    input                cfg_lpbk_en,                     // loopback enable, for master device to start a loopback operation of a slave device
    input                cfg_reset_assert,                // Link reset enable, for RC to reset downstream link
    input   [7:0]        cfg_link_num,                    // 8bit link number of upstream device sent over TS seqeunce
    input   [5:0]        cfg_forced_ltssm,                // 6 bits to control manually transaction into each states.
    input   [3:0]        cfg_forced_ltssm_cmd,
    input                cfg_force_en,                    // A debug capability built in to allow software force LTSSM into a specific state
    input                cfg_fast_link_mode,              // simulation speed up mode
    input                cfg_l0s_supported,               // if core implemented L0s, set to 1
    input   [5:0]        cfg_link_capable,                // bit vector to indicate the intended link capabilities, bit0 -- x1, bit1 -- x2, bit2 -- x4, bit3 -- x8,
    input                cfg_ext_synch,                   // software enable extended synch
    input                cfg_gointo_cfg_state,            // a debug capability to allow forcing a LTSSM state to CFG link width start state from recovery idle state
    input                cfg_link_retrain,                // PCI express link control register to start a link retraining when a reset or loopback are intended.  This signal force link to go from L0 to recovery lock
    // some misc signals
    input                app_init_rst,                    // Application may want to reset LTSSM through this signal.
    input                app_ltssm_enable,                // application signal to block the LTSSM from link negotion due to application's readyness.
    // PMC interfaces for power management
    input                pm_smlh_entry_to_l0s,            // PM commands LTSSM enter L0s
    input                pm_smlh_l0s_exit,                // PM commands LTSSM exit L0s
    input                pm_smlh_entry_to_l1,             // PM commands LTSSM enter L1
    input                pm_smlh_l1_exit,                 // PM commands LTSSM exit L1
    input                pm_smlh_l23_exit,                // PM Commands LTSSM exit L23
    input                pm_smlh_entry_to_l2,             // PM Commands LTSSM enter L2
    input                pm_smlh_prepare4_l123,           // PM Commands LTSSM to get preparing for entering L123
    // RMLH interfaces
    input   [NL-1:0]     link_imp_lanes,
    input   [5:0]        link_next_link_mode,
    input   [NL-1:0]     link_lanes_rcving,
    input                link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd,
    input                link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd,
    input                link_latched_live_all_8_ts2_plinkn_planen_rcvd,
    input                link_latched_live_all_8_ts_plinkn_planen_rcvd,
    input                link_latched_live_any_8_ts_plinkn_planen_rcvd,
    input   [NL-1:0]     link_latched_live_any_8_ts_plinkn_planen_rcvd_bus,
    input                link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd,
    input                link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd,
    input                link_latched_live_any_8_ts2_plinkn_planen_rcvd,
    input                link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd,
    input                link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd,
    input                link_xmlh_16_ts2_sent_after_1_ts2_rcvd,
    input                link_xmlh_16_ts1_sent,
    input                link_latched_live_all_2_ts1_dis1_rcvd,
    input                link_latched_live_all_2_ts1_lpbk1_rcvd,
    input   [NL-1:0]     link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd,
    input   [NL-1:0]     link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd,
    input                link_latched_live_any_2_ts1_apn_rcvd, // Rx 2 ts1 with Alternate Protocols Negotiation in cfg.lanewait/.laneaccept/.complete
    input   [55:0]       link_latched_live_any_2_ts1_apn_sym14_8_rcvd, // sym14_8 rcvd for alternate protocols
    input   [NL*56-1:0]  link_latched_live_all_8_ts2_apn_sym14_8_rcvd, // sym14_8 rcvd for alternate protocols
    input   [NL*56-1:0]  link_latched_live_all_1_ts2_apn_sym14_8_rcvd, // sym14_8 rcvd for alternate protocols
    input                link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd,
    input                link_any_2_ts1_linknmtx_planen_rcvd,
    input                link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd,
    input                link_any_2_ts1_dis1_rcvd,
    input                link_latched_live_all_2_ts1_linkn_planen_rcvd,
    input                link_any_2_ts1_linkn_planen_rcvd,
    input                link_lane0_2_ts1_linkn_planen_rcvd,
    input                link_lane0_2_ts1_linknmtx_rcvd,
    input                link_lane0_2_ts1_linknmtx_lanen_rcvd,
    input                link_latched_live_all_2_ts1_linknmtx_rcvd,
    input                link_latched_live_all_2_ts1_linknmtx_lanen_rcvd,
    input                link_latched_live_all_2_ts1_plinkn_planen_rcvd,
    input                link_latched_live_lane0_2_ts1_lanen0_rcvd,
    input                link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd,
    input                link_latched_live_any_2_ts1_lanendiff_linkn_rcvd,
    input                link_any_2_ts2_rcvd,
    input                link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd,
    input                link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd,
    input                link_latched_live_all_ts1_spd_chg_0_rcvd,
    input                link_latched_live_any_ts2_rcvd,
    input                link_any_8_ts1_spd_chg_1_rcvd,
    input                link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd,
    input                link_any_8_ts_linknmtx_lanenmtx_rcvd,
    input                link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd,
    input                link_ln0_8_ts2_linknmtx_lanenmtx_rcvd,
    input                link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd,
    input                link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd,
    input                link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd,
    input                link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd,
    input                link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd,
    input                link_latched_live_any_8_std_ts2_spd_chg_1_rcvd,
    input                link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd,
    input                link_xmlh_32_ts2_spd_chg_1_sent,
    input                link_xmlh_128_ts2_spd_chg_1_sent,
    input                link_xmlh_16_ts2_sent_after_1_ts1_rcvd,
    input                link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd,
    input                link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd,
    input                link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd,
    input                link_any_2_ts1_hotreset1_rcvd,
    input                link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd,
    input                link_any_2_ts1_planen_rcvd,
    input                link_any_2_ts1_lpbk1_rcvd,
    input                link_imp_2_ts1_lpbk1_rcvd,
    input                link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd,
    input                link_any_2_ts_rcvd,
    input                link_any_exact_4_ts_rcvd,
    input                link_any_exact_5_ts_rcvd,
    input                link_1_ts_rcvd,
    input                link_any_1_ts_rcvd,
    input                link_any_1_ts2_rcvd,
    input                link_any_exact_1_ts_rcvd,
    input                link_any_exact_2_ts_rcvd,
    input   [4:0]        link_latched_ts_data_rate,
    input   [4:0]        link_latched_ts_data_rate_ever,
    input   [4:0]        link_any_8_ts_spd_chg_1_data_rate,
    input                link_latched_ts_spd_chg,
    input   [4:0]        link_ts_data_rate,
    input                link_ts_spd_chg,
    input   [4:0]        link_lpbk_ts_data_rate,
    input   [4:0]        link_latched_lpbk_ts_data_rate,
    input                link_lpbk_ts_deemphasis,
    input   [7:0]        link_ts_nfts,
    input                link_latched_live_all_ts_scrmb_dis,
    input                link_latched_modts_support,
    input                link_latched_skipeq_enable,
    input   [7:0]        link_any_2_ts1_link_num,
    input   [NL-1:0]     link_2_ts1_plinkn_planen_rcvd_upconf,
    input                link_latched_ts_retimer_pre,

    input   [10:0]       xmtbyte_ts_pcnt,                 // ts sent persistency count
    input                xmtbyte_1024_ts_sent,            // 1024 ts sent in a state
    input                xmtbyte_dis_link_sent,           // disable link bit set in Tx TS
    input                smlh_eidle_inferred,             // Electrical Idle has been inferred on at least one lane
    input   [NL-1:0]     smlh_inskip_rcv,
    input   [NL-1:0]     smlh_sds_rcvd,                   // RMLH indicates receiver receives SDS, 0 for gen1/2
    input   [NL-1:0]     smlh_lanes_rcving,               // NL bits indicates that the lanes have the proper training sequence found
    input   [1:0]        rmlh_rcvd_idle,                  // RMLH block keeps track of the number of idle received continously.  Bit 0 indicates receiver received 8 continous idle symbol, bit1 indicates 1 idle has been received
    input                rmlh_all_sym_locked,             // symbol locked on all active lanes
    input                rmlh_rcvd_eidle_set,             // RMLH indicates receiver received eidle ordered set
    input   [NL-1:0]     act_rmlh_rcvd_eidle_set,         // RMLH indicates receiver received eidle ordered set per lane
    input                rmlh_deskew_alignment_err,       // deskew alignement error from deskew block to have LTSSM go into recovery
    input                rmlh_deskew_complete,            // deskew completion indication
    input   [NL-1:0]     rpipe_rxaligned,                 // RMLH RxValid
    input                xdlh_smlh_start_link_retrain,    // Data link layer requests link retraining due to the number of replay exceed 3
    input                rtlh_req_link_retrain,           // RTLH layer requests link retrain due to the watch dog timeout
    // xmt byte block signals to LTSSM to report status of current
    // transimission
    input                xmtbyte_ts1_sent,                // indicates 1 TS1 ordered set has been sent based on LTSSM's command
    input                xmtbyte_ts2_sent,                // indicates 1 TS2 ordered set has been sent based on LTSSM's command
    input                xmtbyte_idle_sent,               // indicates 1 idle has been sent based on LTSSM's command
    input                xmtbyte_eidle_sent,              // indicates 1 eidle ordered set has been sent based on LTSSM's command
    input                xmtbyte_fts_sent,                // indicates all fast training sequences have been sent based on LTSSM's command
    input                xmtbyte_skip_sent,               // indicates 1 skip ordered set has been sent based on LTSSM's command
    input                xmtbyte_cmd_is_data,             // indicates xmtbyte is in datastream

    input   [2:0]        current_data_rate,               // 0=running at gen1 speeds, 1=running at gen2 speeds, 2 = 8GT/s
    input   [1:0]        current_powerdown,               // PHY changed powerdown
    input   [NL-1:0]     phy_mac_rxelecidle,              // RMLH reports electrical idle asserted
    input   [NL-1:0]     phy_mac_rxdetected,              // RMLH reports the received detected
    input                phy_mac_rxdetect_done,           // RMLH indicates the cycle to sample phy_mac_rxdetected
    input                xmtbyte_txdetectrx_loopback,     // Indicates detectrx or loopback mode
    input                all_phystatus_deasserted,        // RMLH pipe block reports the PHY status deasserted on all lanes
    input   [NL-1:0]     phy_mac_rxstandbystatus,         // RxStandbyStatus
    input   [NL-1:0]     phy_mac_rxelecidle_noflip,       // No Lane Flip-ed RxElecilde
    input   [NL-1:0]     laneflip_lanes_active,          // Lane Flip-ed smlh_lanes_active
    input   [NL-1:0]     laneflip_rcvd_eidle_rxstandby,  // Lane Flip-ed smlh_rcvd_eidle_rxstandby
    input   [8:0]        cfg_lane_en,                     // Indicates the number of lanes to check for exit from electrical idle in Polling.Active and Polling.Compliance. 1 = x1, 2=x2, 4=x4 etc.
    input                rmlh_pkt_start,                  // Indicates a STP or SDP was received
    input   [6:0]        cfg_rxstandby_control,           // Rxstandby Control
    input                cfg_rxstandby_handshake_policy,
    input                cfg_por_phystatus_mode,
    input   [3:0]        cfg_p1_entry_policy,

    input   [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl,             // lane under test + gen5 control, {cfg_force_lane_flip, cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts}
    input                cfg_alt_protocol_enable,         // enable alternate protocol
    input                cfg_hw_autowidth_dis,            // Hardware auto width disable for upconfigure
    input   [5:0]        cfg_target_link_width,           // Target Link Width
    input                cfg_directed_link_width_change,  // Directed Link Width Change
    input                cfg_upconfigure_support,         // Upconfigure support
    input   [NL-1:0]     xmtbyte_txelecidle,              // Enable Transmitter Electical Idle
    input   [NL-1:0]     laneflip_pipe_turnoff,           // Indicates PIPE Turnoff
    input   [1:0]        rdlh_dlcntrl_state,              // Data link layer state machine output
    // LTSSM timer outputs routed to the top-level for verification usage
    input  [T_WD-1:0]    fast_time_1ms,
    input  [T_WD-1:0]    fast_time_2ms,
    input  [T_WD-1:0]    fast_time_3ms,
    input  [T_WD-1:0]    fast_time_10ms,
    input  [T_WD-1:0]    fast_time_12ms,
    input  [T_WD-1:0]    fast_time_24ms,
    input  [T_WD-1:0]    fast_time_32ms,
    input  [T_WD-1:0]    fast_time_48ms,
    input  [T_WD-1:0]    fast_time_100ms,
    input                pm_current_powerdown_p1,         // Indicate mac phy powerdown is in P1
    input                pm_current_powerdown_p0,         // Indicate mac phy powerdown is in P0
    // ----------- outputs -----------------
    output               ltssm_lpbk_entry_send_ts1,       // loopback is in Loopback.Entry and in sending TS1s command

    output  reg [3:0]    ltssm_cmd,                       // 4bits encoded command to notify transmitter of the proper action based on LTSSM states
    output               smlh_link_up_falling_edge,
    output  reg          ltssm_in_pollconfig,
    output  reg          smlh_link_up,                    // LTSSM is in link up
    output  reg          smlh_req_rst_not,                // LTSSM link status is in surprised down so that it requests a reset
    output               smlh_scrambler_disable,          // 1 bit to disable the scrambler
    output  reg          smlh_training_rst_n,             // LTSSM negotiated a training reset
    output               smlh_link_disable,               // LTSSM negotiated a link disable
    output               clear_o,                         // ltssm clear
    output               clear_eqctl,                     // ltssm clear
    output               clear_seq,                       // ltssm clear
    output               clear_link,                      // ltssm clear
    output  reg          ltssm_rcvr_err_rpt_en,           // This signal is designed to notify the rmlh block when to enable receiver error report
    output  reg [7:0]    ltssm_xlinknum,                  // 8bits indicate link number to be inserted in training sequence
    output  reg [NL-1:0] ltssm_xk237_4lannum,             // 1 -- K237, 0 -- send lane number
    output  reg [NL-1:0] ltssm_xk237_4lnknum,             // 1 -- K237, 0 -- send link number
    output  [7:0]        ltssm_ts_cntrl,                  // training sequence control
    output  reg          ltssm_mod_ts,                    // TX modified TS OS
    output  reg          ltssm_mod_ts_rx,                 // RX modified TS OS
    output               ltssm_ts_alt_protocol,           // Alternate Protocol
    output               ltssm_no_idle_need_sent,         // No idle need sent
    output  reg [55:0]   ltssm_ts_alt_prot_info,          // sym14-8 for AP
    output  [5:0]        ltssm_cxl_enable,                // CXL enables
    output  [23:0]       ltssm_cxl_mod_ts_phase1_rcvd,    // Received Modified TS Data Phase1
    output               ltssm_cxl_retimers_pre_mismatched,   // Set CXL_Retimers_Present_Mismatched bit
    output               ltssm_cxl_flexbus_phase2_mismatched, // Set FlexBusEnableBits_Phase2_Mismatch bit
    output               cxl_mode_enable,                 // Indicates whether the link should operate in CXL or PCIe mode
    output  [1:0]        ltssm_cxl_ll_mod,                // CXL Low Latency Mode
    output  reg          ltssm_ap_success,                // Alternate Protocol negotiation successful
    output  reg [NL-1:0] ltssm_lanes_active,              // LTSSM latched lanes that are active based on the link negotiation
    output  reg [NL-1:0] lpbk_eq_lanes_active,            // LTSSM lanes active for Loopback Eq
    output               lpbk_eq_n_lut_pset,              // lpbk during gen5 rate for EQ
    output               lpbk_eq,                         // in Eq state for loopback
    output  reg [NL-1:0] smlh_no_turnoff_lanes,           // No turnoff lanes
    output  reg          lpbk_master,                     // indicates that the ltssm is the loopback master
    output  reg [NL-1:0] deskew_lanes_active,             // LTSSM latched lanes that are active based on the link negotiation, goes to rmlh_deskew logic
    output  reg          smlh_lnknum_match_dis,           // This signal is designed to notify the rmlh block when to enable link number match checking
    output  reg [5:0]    smlh_ltssm_state,                // 6 bits encoded link state
    output  reg [5:0]    smlh_ltssm_state_smlh_eq,        // replicated signal of smlh_ltssm_state for fanout reduction
    output  reg [5:0]    smlh_ltssm_state_smlh_sqf,       // replicated signal of smlh_ltssm_state for fanout reduction
    output  reg [5:0]    smlh_ltssm_state_smlh_lnk,       // replicated signal of smlh_ltssm_state for fanout reduction
    output  reg [5:0]    smlh_ltssm_state_xmlh,           // replicated signal of smlh_ltssm_state for fanout reduction
    output  reg [5:0]    smlh_ltssm_state_rmlh,           // replicated signal of smlh_ltssm_state for fanout reduction
    output  [5:0]        ltssm_next,
    output  [5:0]        ltssm_last,                      // last link state
    output  reg [1:0]    ltssm_powerdown,                 // Powerdown command to PIPE phy (P2 is set by PM controller)
    // LTSSM status
    output  reg          smlh_in_l0,                      // LTSSM in L0 state
    output  reg          smlh_in_l0s,                     // LTSSM in transmit L0s state
    output  reg          smlh_in_rl0s,                    // LTSSM in receive L0s state
    output  reg          smlh_in_l1,                      // LTSSM in L1 state
    output  wire         smlh_in_l1_p1,                   // LTSSM in L1 state with current_powerdown set to P1
    output  reg          smlh_in_l23,                     // LTSSM in L23 state, it will be L2 or L3 based on aux power detection
    output  reg          smlh_l123_eidle_timeout,         // 2ms Timer Timed out while waiting for EIDLE
    output  reg          smlh_pm_latched_eidle_set,
    output               ltssm_in_lpbk,                   // LTSSM in Loopback.Active state
    output  reg          ltssm_in_training,               // LTSSM in training (includes Recovery.Speed in Gen2/Gen3 and Recovery.Equalization in Gen3)
    output  reg [2:0]    ltssm_eidle_cnt,                 // 4 bits, indicates how many EIOS sets to send before returning xmtbyte_eidle_sent.  0=1 EIOS, 1=2 EIOS, etc.
    output  [4:0]        l0s_state,                       // L0s sub states of the LTSSM. This is a status information
    output               smlh_bw_mgt_status,              // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
    output               smlh_link_auto_bw_status,        // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
    output  [5:0]        smlh_link_mode,                  // 6 bits indicate the active lanes and final negotiated link width
    output  reg [5:0]    smlh_link_rxmode,                // 6 bits indicate the active lanes and final negotiated link width for RX SIDE
    output  reg [7:0]    latched_ts_nfts,                 // latched number of fast training sequence number from TS ordered set of receiver
    output  reg          smlh_do_deskew,                  // Indicate to the deskew block when it is valid to deskew
                                                          // without the port transitioning through DL_Down status
                                                          // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
    output  reg [2:0]    mac_phy_rate,                    // Indicate to the Phy what speed to run.  0 = 2.5Gb/s  1 = 5.0Gb/s, 2 = 8.0Gb/s
    output  reg [NL-1:0] mac_phy_rxstandby,               // Controls whether the PHY RX is active
    output  reg [NL-1:0] smlh_rcvd_eidle_rxstandby,       // Rx EIOS for RxStandby
    output  reg          ltssm_ts_auto_change,            // autonomous change/upconfig capable/select deemphasis bit.  bit 6 of the data rate identifier field.
    output               smlh_dir_linkw_chg_rising_edge,  // clear cfg_directed_link_width_change
    output  [7:0]        current_n_fts,                   // our current N_FTS based on the link speed (gen1/gen2)
    output  reg          smlh_in_l0_l0s,                  // LTSSM is in L0 or L0s state
    output  [AW-1:0]     active_nb,                       // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s, bit4=16s
    output  reg [NL-1:0] ltssm_lanes_active_d,            // lane under test for lpbk slave
    output  reg          ltssm_in_hotrst_dis_entry,
    output               ltssm_lane_flip_ctrl_chg_pulse,  // lane flip control update pulse
    output  [`CX_INFO_EI_WD-1:0] smlh_debug_info_ei,      // information about EIOS reception and LTSSM state transitions that are relevant for external logic that may be masking the analog rxelecidle
                                                          // Group 1 - single cycle pulse - received Ordered Sets decode:
                                                          // [0]: EIOS detected
                                                          // Group 2 - level - LTSSM is in one of the states that depends on rxelecidle==0:
                                                          // [1]: L1
                                                          // [2]: L2
                                                          // [3]: RxL0s
                                                          // [4]: Disabled
                                                          // [5]: Detect.Quiet
                                                          // [6]: Polling.Active
                                                          // [7]: Polling.Compliance
                                                          // Group 3 - level - LTSSM is in one of the states that depends on rxelecidle==1:
                                                          // [8]: LTSSM is in a transitory state prior to L1 or L2
                                                          // [9]: LTSSM is in a transitory state prior to Disabled
                                                          // [10]: LTSSM is in Loopback.Active as a Slave at Gen1
                                                          // [11]: LTSSM is in Polling.Active
                                                          // Group 4 - single cycle pulse - LTSSM state transitions with EI inferred:
                                                          // [12]: LTSSM enters Recovery from L0 with EI inferred, first row in base spec Table 4-11
                                                          // [13]: LTSSM enters Recovery.Speed from Recovery.RcvrCfg with EI inferred, second row in base spec Table 4-11
                                                          // [14]: EI inferred while LTSSM in Recovery.Speed, third/fourth rows in base spec Table 4-11
                                                          // [15]: EI inferred while LTSSM in Loopback.Active as a slave, fifth row in base spec Table 4-11
    output  [L2NL-1:0]   smlh_lane_flip_ctrl,             // control for flipping the lanes
    output  reg [L2NL-1:0] latched_flip_ctrl,             // control for flipping the lanes
    output  reg [4:0]    lpbk_lane_under_test,            // control for flipping the lanes for lpbk master in lpbk.active
    output  [L2NL-1:0]   ltssm_lane_flip_ctrl             // control for flipping the lanes without latched for enter Gen3/4 Polling.Compliance
);

// Include the assertion package
`ifndef SYNTHESIS
`endif // SYNTHESIS
// -----------------------------------------------------------------------------
// Parameter definition
// -----------------------------------------------------------------------------
parameter    S_DETECT_QUIET         = `S_DETECT_QUIET;
parameter    S_DETECT_ACT           = `S_DETECT_ACT;
parameter    S_POLL_ACTIVE          = `S_POLL_ACTIVE;
parameter    S_POLL_COMPLIANCE      = `S_POLL_COMPLIANCE;
parameter    S_POLL_CONFIG          = `S_POLL_CONFIG;
parameter    S_PRE_DETECT_QUIET     = `S_PRE_DETECT_QUIET;
parameter    S_DETECT_WAIT          = `S_DETECT_WAIT;
parameter    S_CFG_LINKWD_START     = `S_CFG_LINKWD_START;
parameter    S_CFG_LINKWD_ACEPT     = `S_CFG_LINKWD_ACEPT;
parameter    S_CFG_LANENUM_WAIT     = `S_CFG_LANENUM_WAIT;
parameter    S_CFG_LANENUM_ACEPT    = `S_CFG_LANENUM_ACEPT;
parameter    S_CFG_COMPLETE         = `S_CFG_COMPLETE;
parameter    S_CFG_IDLE             = `S_CFG_IDLE;
parameter    S_RCVRY_LOCK           = `S_RCVRY_LOCK;
parameter    S_RCVRY_SPEED          = `S_RCVRY_SPEED;
parameter    S_RCVRY_RCVRCFG        = `S_RCVRY_RCVRCFG;
parameter    S_RCVRY_IDLE           = `S_RCVRY_IDLE;
parameter    S_RCVRY_EQ0            = `S_RCVRY_EQ0;
parameter    S_RCVRY_EQ1            = `S_RCVRY_EQ1;
parameter    S_RCVRY_EQ2            = `S_RCVRY_EQ2;
parameter    S_RCVRY_EQ3            = `S_RCVRY_EQ3;
parameter    S_L0                   = `S_L0;
parameter    S_L0S                  = `S_L0S;
parameter    S_L123_SEND_EIDLE      = `S_L123_SEND_EIDLE;
parameter    S_L1_IDLE              = `S_L1_IDLE;
parameter    S_L2_IDLE              = `S_L2_IDLE;
parameter    S_L2_WAKE              = `S_L2_WAKE;
parameter    S_DISABLED_ENTRY       = `S_DISABLED_ENTRY;
parameter    S_DISABLED_IDLE        = `S_DISABLED_IDLE;
parameter    S_DISABLED             = `S_DISABLED;
parameter    S_LPBK_ENTRY           = `S_LPBK_ENTRY;
parameter    S_LPBK_ACTIVE          = `S_LPBK_ACTIVE;
parameter    S_LPBK_EXIT            = `S_LPBK_EXIT;
parameter    S_LPBK_EXIT_TIMEOUT    = `S_LPBK_EXIT_TIMEOUT;
parameter    S_HOT_RESET_ENTRY      = `S_HOT_RESET_ENTRY;
parameter    S_HOT_RESET            = `S_HOT_RESET;

parameter    S_L0S_RCV_ENTRY        = 2'b00;
//                                  = 2'b01; // reserved
parameter    S_L0S_RCV_IDLE         = 2'b10;
parameter    S_L0S_RCV_FTS          = 2'b11;

parameter    S_L0S_XMT_ENTRY        = 3'b000;
parameter    S_L0S_XMT_WAIT         = 3'b001;
parameter    S_L0S_XMT_IDLE         = 3'b010;
parameter    S_L0S_XMT_FTS          = 3'b011;
parameter    S_L0S_XMT_EIDLE        = 3'b100;
parameter    S_L0S_EXIT_WAIT        = 3'b101;

parameter    S_COMPL_IDLE               = 3'b000;       // Start here on entering Polling.Compliance
parameter    S_COMPL_ENT_TX_EIDLE       = 3'b001;       // send EIDLE ordered set in preparation for link speed change
parameter    S_COMPL_ENT_SPEED_CHANGE   = 3'b010;       // Change speed to Gen II
parameter    S_COMPL_TX_COMPLIANCE      = 3'b011;       // Transmit compliance pattern
parameter    S_COMPL_EXIT_TX_EIDLE      = 3'b100;       // send EIDLE ordered set in preparation for link speed change
parameter    S_COMPL_EXIT_SPEED_CHANGE  = 3'b101;       // Change speed to Gen I
parameter    S_COMPL_EXIT_IN_EIDLE      = 3'b110;       // Enter EIDLE for 1ms
parameter    S_COMPL_EXIT               = 3'b111;       // Exit compliance

parameter    S_LPBK_ENTRY_IDLE      = 2'h0;             // Idle
parameter    S_LPBK_ENTRY_ADV       = 2'h1;             // Advertise Loopback
parameter    S_LPBK_ENTRY_EIDLE     = 2'h2;             // Send Electrical Idle and change speed
parameter    S_LPBK_ENTRY_TS        = 2'h3;             // Send TS1s
parameter    TIME_6US        = `CX_TIME_6US;
parameter    TIME_800NS      = `CX_TIME_800NS; 

// ----------------------------------------------------------------------------
// signals
// ----------------------------------------------------------------------------
wire                clear;
reg                 timeout_1ms_d;
wire                int_timeout_1ms_rising_edge;
wire                xmtbyte_1024_consecutive_ts1_sent; // minimum 1024 CONSECUTIVE ts1 sent
wire                xmtbyte_16_ts_w_lpbk_sent;
wire                xmtbyte_16_ts_w_dis_link_sent;     // 16 ts with disable link bit set has been sent
reg     [5:0]       lts_state;
reg     [5:0]       lts_state_d;
reg     [2:0]       hold_current_data_rate;            // update to current_data_rate when clear = 1b and then hold
wire                poll_config_state;                 // Polling + Cfg.Linkwd.Start + Cfg.Linkwd.Accept
reg     [NL-1:0]    latchd_smlh_lanes_rcving;

reg                 cfgcmpl_all_8_ts2_rcvd;
reg     [2:0]       current_data_rate_d;

reg  [2:0]   ts2_cxl_enable; // cxl.cache/mem/io
reg  [1:0]   ts2_cxl_r20_enable; // Multi-logical Dev, CXL 2.0
wire         cxl_cache_en, cxl_mem_en, cxl_io_en;
wire         cxl_r20_en, multi_logical_dev_en;
wire         cxl_r20_v09_en;
assign       ltssm_cxl_enable = 6'b000000;
assign       cxl_mode_enable  = 1'b0;
assign       ltssm_cxl_ll_mod = 2'b00; // {drift buffer, common clock}
assign       ltssm_cxl_mod_ts_phase1_rcvd = 0; // Mod TS1-OS symbol 14-12
assign       ltssm_cxl_retimers_pre_mismatched   = 0; // CXL_Retimers_Present_Mismatched
assign       ltssm_cxl_flexbus_phase2_mismatched = 0; // FlexBusEnableBits_Phase2_Mismatch

assign ltssm_ts_alt_prot_info = 56'h0;

    wire ltssm_ap_success_i = 1'b0;
    always @* ltssm_ap_success = ltssm_ap_success_i;

reg     [2:0]       latched_l0_speed;               // The speed on entering Recovery from L0 or L1
reg                 latched_lane_reversed;
reg     [5:0]       int_smlh_link_mode;             // 6 bits indicate the active lanes and final negotiated link width
reg                 link_mode_changed;
reg     [5:0]       linkup_link_mode;               // Latched link_mode of initial linkup
reg     [5:0]       latest_link_mode;               // Latched link_mode of latest config state
reg                 ltssm_lanes_activated_pulse;
wire                ltssm_mid_config_state;
reg                 ltssm_lane_flip_ctrl_chg_pulse_d;
reg                 deskew_lanes_active_change;
wire                update_deskew_lanes_active;
wire    [NL-1:0]    next_deskew_lanes_active;
reg                 r_ltssm_rcvr_err_rpt_en;
reg     [4:0]       ltssm_ts_data_rate_int;
reg [4:0]           ltssm_ts_data_rate;              // Gen2 Data rate to advertise support for in the ts.  bits 4:1 of the data rate identifier field.
reg [4:0]           latched_ts_data_rate;            // latched TS sequence data rate from partner
wire                link_num_match;
integer             j;
reg                 r_rcvd_at_least_1ts;
wire                cfg_force_lane_flip, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts;
wire                cfg_mod_ts_i;
wire [3:0]          cfg_lane_under_test;
wire                lut_en;
wire [4:0]          lut_ctrl;
assign {cfg_force_lane_flip, cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts} = cfg_lut_ctrl;
wire   ltssm_master_lpbk_active_after_g5_lpbk_eq = lpbk_lane_under_test[4];
// if cfg_force_lane_flip = 1, force the physical lane cfg_lane_under_test flip to logical lane 0.
// Else if loopback master in Loopback.Active at Gen5 rate following Loopback Eq, flip the physical lane cfg_lane_under_test to logical lane 0.
assign lut_en   = cfg_force_lane_flip ? 1'b1 : ltssm_master_lpbk_active_after_g5_lpbk_eq ? 1'b1 : 1'b0;
assign lut_ctrl = {lut_en, cfg_lane_under_test};

wire   cfg_selectable_deemph_bit_mux, cfg_select_deemph_var_mux; // {mux for selectable deemphasis bit for Tx TS2 in Rcvry.RcvrCfg, mux for select_deemphasis variable}
assign {cfg_selectable_deemph_bit_mux, cfg_select_deemph_var_mux} = cfg_select_deemph_mux_bus;

// ----------------------------------------------------------------------------
// internal Regs
// ----------------------------------------------------------------------------



reg                 retry_detect; // this is used to allow one time retry receiver detect
wire    [5:0]       ltssm;
reg     [5:0]       next_lts_state;                 // the previous ltssm state
reg     [5:0]       last_lts_state;                 // the previous ltssm state
reg     [2:0]       curnt_l0s_xmt_state;
reg     [2:0]       next_l0s_xmt_state;
reg     [2:0]       curnt_compliance_state;         // State machine for polling compliance
reg     [2:0]       curnt_compliance_state_d1;      // State machine for polling compliance
reg     [2:0]       next_compliance_state;          // State machine for polling compliance
reg     [1:0]       curnt_lpbk_entry_state;         // State machine for loopback entry
reg     [1:0]       next_lpbk_entry_state;          // State machine for loopback entry
reg                 lpbk_clear;
reg                 lpbk_clear_wire;
reg     [1:0]       curnt_l0s_rcv_state;            // Current Rx_L0s substate (Entry, Idle or FTS)
reg     [1:0]       r_curnt_l0s_rcv_state;          // registered curnt_l0s_rcv_state
wire    [NL-1:0]    int_rxdetected;                 // RMLH reports the received detected
wire                int_rxdetect_done;              // RMLH indicates the cycle to sample phy_mac_rxdetected
reg                 update_lanes_active;

reg     [10:0]      ts_sent_cnt;
reg     [4:0]       idle_sent_cnt;
reg                 ts_sent_in_poll_active;         // indicates that TSs were sent in Polling.Active
reg     [4:0]       rcvd_expect_tscnt;
reg     [4:0]       rcvd_expect_ts1cnt;
reg     [4:0]       r_rcvd_expect_ts1cnt;
reg     [4:0]       rcvd_expect_ts2cnt;
reg     [4:0]       r_rcvd_expect_ts2cnt;
reg     [4*NL-1:0]  rcvd_eidle_cnt;
reg                 rcvd_4eidle;
reg     [4:0]       all_rcvd_expect_tscnt;
reg     [4:0]       all_rcvd_expect_ts2cnt;
reg     [4:0]       rcvd_unexpect_ts1cnt;
reg     [4:0]       rcvd_unexpect_ts2cnt;
reg     [7:0]       idle_to_rlock;
reg                 use_modified_ts;
reg                 latched_tx_modified_ts;
wire                speed_change_pulse;

reg     [NL-1:0]    latched_rxeidle_exit_detected;
reg     [NL-1:0]    latched_rxeidle;
wire                any_predet_lane_latched_rxeidle;
reg                 l0s_state_clear;
wire                clr_timer_4rl0s;       // indicates when timer should be cleared when transitioning from L0 to Rx_L0s
wire                l0s_rcv_idle, l0s_rcv_entry, l0s_rcv_fts;        // Rx_L0s substates
reg                 r_l0s_rcv_idle, r_l0s_rcv_entry, r_l0s_rcv_fts;  // 1 cycle delayed Rx_L0s substates
wire                clr_l0s_rcv;                                     // clear pulse when changing Rx_L0s substates
reg                 rcvr_l0s_goto_rcvry;
reg     [NL-1:0]    latchd_rxeidle_exit;
reg                 latched_eidle_seen;
reg                 latched_eidle_inferred;
reg     [T_WD-1:0]  timer;
reg     [5:0]       timer_40ns_4rl0s;
wire    [T_WD-1:0]  polling_timeout_value;
reg     [18:0]      speed_timer;
reg                 timeout_1ms;
reg                 timeout_1us;
reg                 timeout_10us;
reg                 timeout_esm_10us;
reg                 timeout_esm_50us;
reg                 timeout_esm_100us;
reg                 timeout_esm_500us;
reg                 timeout_esm_1ms;
reg                 timeout_esm_5ms;
reg                 timeout_esm_10ms;
reg                 timeout_esm_50ms;
wire                timeout_cali;
wire                esm_quiet_calibration;
wire                esm_quiet_cal_no_clk_gate;
reg                 timeout_2ms;
reg                 timeout_3ms;
reg                 timeout_2ms_d;
wire                int_timeout_2ms_rising_edge;
reg                 ds_timeout_2ms;
reg                 timeout_10ms;
reg                 timeout_12ms;
reg                 timeout_12ms_d;
reg                 int_timeout_12ms_rising_edge;
reg                 timeout_24ms;
reg                 timeout_24ms_d;
reg                 int_timeout_24ms_rising_edge;
wire                ltssm_eq_slave_timeout;
wire                ltssm_eq_master_timeout;
reg                 timeout_32ms;
reg                 timeout_48ms;
reg                 timeout_nfts;
reg                 speed_timeout_800ns;
reg                 speed_timeout_6us;

reg                 rcvd_8idles;
reg                 rcvd_1idle;
reg                 rcvd_8expect_ts;
reg                 rcvd_8expect_ts2;
reg                 all_rcvd_8expect_ts;
reg                 all_rcvd_8expect_ts2;
reg                 rcvd_atleast1_expect_ts;
reg                 rcvd_8unexpect_ts1;
reg                 ts_2_sent;
reg                 ts_16_sent;
reg                 ts_1024_sent;
reg                 ts_rcvd_1024_sent;
reg                 ts_1024_sent_d;
wire                ts_1024_sent_rising_edge;
reg                 idle_16_sent;
reg                 latched_eidle_sent;
reg     [NL-1:0]    int_latched_smlh_inskip_rcv;
reg                 latched_smlh_inskip_rcv;
reg     [7:0]       xmt_ts_lnknum;
wire   [(NL*8)-1:0] xmt_ts_lnknum_bus;
wire                smlh_all_lanes_rcvd;
reg                 latched_any_lane_8expect_ts_rcvd;
wire                smlh_ts_rcvd;
reg     [NL-1:0]    latchd_lanes_rcving_lpbk;


wire                rcvry_idle_consecutive_ts;
wire                rcvd_2rst_i;
reg                 rcvd_2rst;
reg                 rcvd_2dis;
reg                 rcvd_2lpbk;
reg                 rcvd_2lpbk_cmplrcv;

reg                 rcvd_2lannum_pad;
reg                 rcvd_2lnknum_pad;
reg                 rcvd_2lnknum_nonpad;
reg                 rcvd_2lannum_nonpad;
reg                 rcvd_2_lane_num_match;
reg                 rcvd_2lannum_nonpad_ts2;
reg                 latched_ts1_rcv;
reg                 latched_ts1_rcvd;
reg                 latched_cl_ts1_rcv;
reg                 latched_ts2_rcv;
reg                 latched_ts2_rcvd;

//consecutive 8 or 2 TSs
reg     [NL-1:0]    rcvd_8ts_sym6_match;
reg     [NL-1:0]    rcvd_2ts1_sym6_match;
reg     [NL-1:0]    rcvd_8ts1_sym6_match;
reg     [NL-1:0]    rcvd_2ts2_sym6_match;
reg     [NL-1:0]    rcvd_8ts2_sym6_match;
reg     [NL-1:0]    rcvd_2ts1_s6s9_match;
reg     [NL-1:0]    rcvd_8ts1_s6s9_match;
reg     [NL-1:0]    rcvd_2ts2_s6s9_match;
reg     [NL-1:0]    rcvd_8ts2_s6s9_match;
wire                all_rcvd_8ts_sym6_match;
wire                any_rcvd_8ts_sym6_match;

wire                all_rcvd_cnsc_8ts_sym6;
wire                any_rcvd_cnsc_8ts_sym6;

wire                any_rcvd_2ts1_sym6_match;

wire                any_rcvd_8ts1_sym6_match;
wire                all_rcvd_8ts2_sym6_match;
wire                any_rcvd_8ts2_sym6_match;

wire                all_cfg_subset_rcvd_2ts1_sym6_match;
wire                all_cfg_rcvd_2ts1_sym6_match;
wire                any_cfg_rcvd_2ts1_sym6_match;
wire                all_cfg_rcvd_2ts2_sym6_match;
wire                any_cfg_rcvd_2ts2_sym6_match;

wire                all_cfg_rcvd_8ts2_sym6_match;

wire                any_rcvd_2ts1_s6s9_match;

wire                any_rcvd_8ts1_s6s9_match;
wire                all_rcvd_8ts2_s6s9_match;
wire                any_rcvd_8ts2_s6s9_match;

wire                all_cfg_subset_rcvd_2ts1_s6s9_match;
wire                all_cfg_rcvd_2ts1_s6s9_match;
wire                any_cfg_rcvd_2ts1_s6s9_match;
wire                all_cfg_rcvd_2ts2_s6s9_match;
wire                any_cfg_rcvd_2ts2_s6s9_match;

wire                all_cfg_rcvd_8ts2_s6s9_match;

wire                any_rcvd_cnsc_2ts1_s6s9;
wire                any_rcvd_cnsc_8ts1_s6s9;
wire                all_rcvd_cnsc_8ts2_s6s9;
wire                any_rcvd_cnsc_8ts2_s6s9;

wire                all_cfg_subset_rcvd_cnsc_2ts1_s6s9;

wire                all_cfg_rcvd_cnsc_2ts1_s6s9;
wire                any_cfg_rcvd_cnsc_2ts1_s6s9;
wire                all_cfg_rcvd_cnsc_2ts2_s6s9;
wire                any_cfg_rcvd_cnsc_2ts2_s6s9;
wire                all_cfg_rcvd_cnsc_8ts2_s6s9;
//end of consecutive 8 or 2 TSs

reg                 app_ltssm_enable_d;             // application signal to block the LTSSM from link negotion due to application's readyness.
reg                 app_ltssm_enable_dd;
wire                app_ltssm_enable_fall_edge;
reg                 timeout_polling_eidle;

wire                all_phy_mac_rxelecidle;
wire                any_phy_mac_rxeidle_exit;
wire                smlh_all_lanes_rcvd_c;
wire                smlh_any_lane_rcvd_c;

wire                turn_off_do_deskew;
wire                upstream_component;     // Upstream Component ; Downstream Port ; Downstream Lanes
wire                downstream_component;   // Downstream Component ; Upstream Port ; Upstream Lanes


// Loopback Flags
reg                 rcvry_to_lpbk;

reg                 latched_direct_rst;
reg                 direct_rst_d;
reg                 gointo_rcovr_state_d;

//reg     [1:0]       mac_phy_rate_d;
//reg     [1:0]       current_data_rate;
reg                 latched_rate_change;
wire                latched_rate_change_or;
reg                 int_rcvd_8_ts2_skip_eq;
reg                 int_rcvd_8_ts2_noeq_nd; // no eq needed
reg                 int_bypass_gen3_eq, int_bypass_gen4_eq;
reg                 bypass_g3_eq, bypass_g4_eq;
reg                 rcvd_ts_auto_change;

// Link Width Change
wire                go_recovery_link_width_change;
reg     [5:0]       int_target_link_width_legal;
reg     [5:0]       int_target_link_width_real;
reg                 directed_link_width_change;
reg                 directed_link_width_change_d;
reg     [5:0]       latched_target_link_width;
reg                 latched_auto_width_downsizing;
reg                 hw_autowidth_dis_d;
wire                hw_autowidth_dis_rising_edge;
reg                 hw_autowidth_dis_upconf;
wire    [NL-1:0]    target_link_lanes_active;
wire    [NL-1:0]    remote_lanes_activated;
wire                directed_link_width_change_updown;
wire                directed_link_width_change_up;
wire                directed_link_width_change_down;
wire                directed_link_width_change_nochg;
reg                 cfglwstart_upconf_dsp;
reg     [NL-1:0]    latchd_rxeidle_exit_upconf;
reg                 upconfigure_capable;
wire                link_mode_activated_pulse;

reg                 timeout_40ns;
reg                 timeout_40ns_4rl0s;
reg                 int_lpbk;
reg                 no_idle_need_sent;


reg                 rcvd_8expect_ts1_notlanematch;
wire                directed_recovery;
reg                 common_gen1_supported;
wire                gen2_supported;
wire                gen3_supported;
wire    [7:0]       pre_ltssm_ts_cntrl;                  // training sequence control

reg     [1:0]       next_ltssm_powerdown;

wire    [NL-1:0]    rxelecidle_fall;

reg                 latched_rcvd_eidle_set;
reg                 latched_rcvd_eidle_set_4rl0s;

wire                cfg_auto_flip_en;
wire    [3:0]       cfg_auto_flip_predet_lane;
wire                cfg_auto_flip_using_predet_lane;
wire                ltssm_entry_cfgcomplete_rcvrycfg_pulse;
reg    [AW-1:0]     active_nb_d;
wire                deskew_complete_n;
reg                 deskew_complete_n_d;
reg     [NL-1:0]    eiexit_hs_in_progress;
wire    [NL-1:0]    int_lanes_active_rxstandby;
wire                deskew_complete_i;
wire                smlh_link_up_rising_edge;
reg                 smlh_link_up_d;


//`ifdef CX_GEN5_SPEED
// extract control signals from PL Register
//wire       cfg_mod_ts, cfg_do_g5_lpbk_eq, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn;
//wire [3:0] cfg_lane_under_test;
//assign {cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts} = cfg_g5_ctrl;
//`endif // CX_GEN5_SPEED

// if ~rmlh_deskew_complete and cfg_ts2_lid_deskew, when ltssm is in L0, the core cannot get rmlh_deskew_complete again in L0 because
// the core does not use SKP OS to do deskew. The core have to transition to Recovery to gain rmlh_deskew_complete again.
assign              deskew_complete_n = ~rmlh_deskew_complete & cfg_ts2_lid_deskew & (current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE) & (lts_state_d == S_RCVRY_IDLE || lts_state_d == S_CFG_IDLE) & (lts_state == S_L0);

always @(posedge core_clk or negedge core_rst_n) begin : deskew_complete_n_d_PROC
    if (!core_rst_n) begin
        deskew_complete_n_d <= #TP 1'b0;
    end else begin
        if ( lts_state_d == S_L0 && lts_state != S_L0 )
            deskew_complete_n_d <= #TP 1'b0;
        else if ( deskew_complete_n )
            deskew_complete_n_d <= #TP 1'b1;
    end
end

// always true for Gen1/2 rate because of new deskew mechanisms for ts2/eieos/skp -> Idle. Need Idle for the deskew. The core must move to Cfg.Idle or Recovery.Idle to send Idle data
assign              deskew_complete_i = ~cfg_ts2_lid_deskew ? rmlh_deskew_complete : (current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE) ? 1'b1 : rmlh_deskew_complete;

// rlock -> rcfg when ext_synch bit set to 1 (consecutive ts1 sent)
localparam CNT_16 = 16 
;
localparam CNT_1024 = 1024 
;
assign              xmtbyte_1024_consecutive_ts1_sent = (cfg_fast_link_mode & (xmtbyte_ts_pcnt>=CNT_16)) | (~cfg_fast_link_mode & (xmtbyte_ts_pcnt>=CNT_1024));
assign              xmtbyte_16_ts_w_dis_link_sent     = (xmtbyte_ts_pcnt>=CNT_16) & xmtbyte_dis_link_sent;
assign              xmtbyte_16_ts_w_lpbk_sent         = (xmtbyte_ts_pcnt>=CNT_16) & int_lpbk;

wire [4:0] int_active_nb;
assign int_active_nb =
                     ((`CX_MAC_SMODE_GEN1==2 ) & (current_data_rate==`GEN1_RATE)) ? 5'b00010 : //gen1, active symbol number = 2
                                                                                    `CX_NB;
assign active_nb = int_active_nb[AW-1:0];



always @( posedge core_clk or negedge core_rst_n ) begin : smlh_link_up_d_PROC
    if ( ~core_rst_n )
        smlh_link_up_d <= #TP 1'b0;
    else
        smlh_link_up_d <= #TP smlh_link_up;
end // smlh_link_up_d_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : hold_current_data_rate_PROC
    if ( ~core_rst_n )
        hold_current_data_rate <= #TP 0;
    else if ( clear )
        hold_current_data_rate <= #TP current_data_rate;
end // hold_current_data_rate_PROC

assign  smlh_link_disable   = (lts_state == S_DISABLED);

wire lpbk_state     = (lts_state == S_LPBK_ENTRY || lts_state == S_LPBK_ACTIVE || lts_state == S_LPBK_EXIT || lts_state == S_LPBK_EXIT_TIMEOUT);

reg                 latched_link_retrain_bit;



assign smlh_link_up_falling_edge = smlh_link_up_d & ~smlh_link_up;

assign smlh_link_up_rising_edge = smlh_link_up & ~smlh_link_up_d;

always @( posedge core_clk or negedge core_rst_n ) begin : bypass_eq_PROC
    if ( ~core_rst_n ) begin
        bypass_g3_eq <= #TP 1'b1;
        bypass_g4_eq <= #TP 1'b1;
    end else begin
        bypass_g3_eq <= #TP int_bypass_gen3_eq;
        bypass_g4_eq <= #TP int_bypass_gen4_eq;
    end
end // bypass_eq_PROC

assign upstream_component   = !cfg_upstream_port;
assign downstream_component =  cfg_upstream_port;


// clock the input
always @(posedge core_clk or negedge core_rst_n)
begin : app_ltssm_enable_delay_PROC
    if (!core_rst_n) begin
        app_ltssm_enable_d  <= #TP 1'b0;
        app_ltssm_enable_dd <= #TP 1'b0;
    end else begin
        app_ltssm_enable_d  <= #TP app_ltssm_enable;
        app_ltssm_enable_dd <= #TP app_ltssm_enable_d;
    end
end

// a pulse from 1 -> 0 of app_ltssm_enable_d
assign app_ltssm_enable_fall_edge = (app_ltssm_enable_dd && !app_ltssm_enable_d);

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        smlh_training_rst_n <= #TP 1'b1;
    else
          smlh_training_rst_n <= #TP !((next_lts_state != S_HOT_RESET_ENTRY) & (lts_state == S_HOT_RESET_ENTRY) & !clear);
end

// latch the detected lanes for the detect retry
reg     [NL-1:0]    latchd_detected_lanes;
wire    [NL-1:0]    latchd_detected_lanes_for_compare;
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        latchd_detected_lanes <= #TP 0;
    else if (int_rxdetect_done)
        latchd_detected_lanes <= #TP int_rxdetected & ltssm_lanes_active;
end

assign  ltssm = lts_state;
assign  ltssm_last = last_lts_state;
assign  ltssm_next = next_lts_state;

reg                 all_phystatus_deasserted_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        all_phystatus_deasserted_d      <= #TP 0;
    end else begin
        all_phystatus_deasserted_d      <= #TP all_phystatus_deasserted;
    end

wire                all_phystatus_fall;

assign  all_phystatus_fall      = all_phystatus_deasserted & !all_phystatus_deasserted_d;

reg                 latchd_phystatus_fall;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latchd_phystatus_fall        <= #TP 0;
    end else if (clear) begin
        latchd_phystatus_fall        <= #TP 1'b0;
    end else if (all_phystatus_fall) begin
        latchd_phystatus_fall        <= #TP 1'b1;
    end

// This signal is used to filtered out invalid rxdetect_done signals
reg                 rxdetect_started;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        rxdetect_started            <= #TP 0;
    else if (clear)
        rxdetect_started            <= #TP 0;
    else if (xmtbyte_txdetectrx_loopback)
        rxdetect_started            <= #TP 1;

wire                all_phy_mac_rxdetected;
wire                any_phy_mac_rxdetected;
wire                same_detected_lanes;

//`ifdef CX_GEN5_SPEED
//  `ifdef CX_LANE_FLIP_CTRL_EN
// if CX_GEN5_SPEED & CX_NL>1, CX_LANE_FLIP_CTRL_EN is default defined
//lane_flip_mux #( 1, NL,1) u_lane_flip_mux_0 (.flipped_data(latchd_detected_lanes_for_compare), .lut(lpbk_lane_under_test), .flip_ctrl(smlh_lane_flip_ctrl), .data(latchd_detected_lanes)); // after auto-flip in Detect.Wait need to flip the lanes that were detected in Detect.Active
//  `endif // CX_LANE_FLIP_CTRL_EN
//`else // CX_GEN5_SPEED
// can force lane flipping from lut_ctrl. See description of signal lut_ctrl
lane_flip_mux
 #( 1, NL,1) u_lane_flip_mux_0 (.flipped_data(latchd_detected_lanes_for_compare), .lut(lut_ctrl), .flip_ctrl(smlh_lane_flip_ctrl), .data(latchd_detected_lanes)); // after auto-flip in Detect.Wait need to flip the lanes that were detected in Detect.Active
//`endif // CX_GEN5_SPEED

assign  all_phy_mac_rxdetected       = ((phy_mac_rxdetected & ltssm_lanes_active) == ltssm_lanes_active);
assign  any_phy_mac_rxdetected       = |(phy_mac_rxdetected & ltssm_lanes_active);
assign  same_detected_lanes          = ((phy_mac_rxdetected & ltssm_lanes_active) == latchd_detected_lanes_for_compare) & (lts_state == S_DETECT_ACT);

assign  int_rxdetected               = phy_mac_rxdetected;
assign  int_rxdetect_done            = phy_mac_rxdetect_done && rxdetect_started;

assign  all_phy_mac_rxelecidle       =  ((phy_mac_rxelecidle & ltssm_lanes_active) == ltssm_lanes_active);
assign  any_phy_mac_rxeidle_exit       = |(~phy_mac_rxelecidle);
assign  smlh_all_lanes_rcvd_c        = ((smlh_lanes_rcving & ltssm_lanes_active) == ltssm_lanes_active);
assign  smlh_any_lane_rcvd_c         = |(smlh_lanes_rcving);


reg                 smlh_all_lanes_rcvd_r;
assign  smlh_all_lanes_rcvd = REGIN ? smlh_all_lanes_rcvd_r : smlh_all_lanes_rcvd_c;


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        smlh_all_lanes_rcvd_r   <= #TP 0;
    end else begin
        smlh_all_lanes_rcvd_r   <= #TP smlh_all_lanes_rcvd_c;
    end

reg    link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d;
wire   link_all_2_ts1_linknmtx_lanen_rcvd_rising_edge;
wire   state_cfg_linkwd_start_wait, state_cfg_linkwd_acept_wait, state_cfg_lanenum_acept_wait, state_in_cfg_lanenum_wait;
wire   state_cfg_linkwd_acept_to_cfg_lanenum_wait, state_cfg_lanenum_acept_to_cfg_lanenum_wait;
assign state_cfg_linkwd_start_wait  = (lts_state == S_CFG_LINKWD_START) & (int_timeout_1ms_rising_edge | int_timeout_2ms_rising_edge | int_timeout_12ms_rising_edge | int_timeout_24ms_rising_edge) & ~clear;
// int_timeout_2ms_rising_edge is used to avoid TSs received on narrow link width with non-PAD lane# sent by the other end in the very late time (the other end moves into cfg_lanenum_wait state late).
assign state_cfg_linkwd_acept_wait  = (lts_state == S_CFG_LINKWD_ACEPT) & (int_timeout_1ms_rising_edge | int_timeout_2ms_rising_edge) & ~clear;
assign state_cfg_lanenum_acept_wait = (lts_state == S_CFG_LANENUM_ACEPT) & (int_timeout_1ms_rising_edge | int_timeout_2ms_rising_edge) & ~clear;
assign state_in_cfg_lanenum_wait    = (lts_state == S_CFG_LANENUM_WAIT) & ((cfg_upstream_port && last_lts_state == S_CFG_LINKWD_ACEPT) | (~cfg_upstream_port && last_lts_state == S_CFG_LANENUM_ACEPT));
assign state_cfg_linkwd_acept_to_cfg_lanenum_wait = (lts_state == S_CFG_LINKWD_ACEPT && next_lts_state == S_CFG_LANENUM_WAIT && ~clear);
assign state_cfg_lanenum_acept_to_cfg_lanenum_wait = (lts_state == S_CFG_LANENUM_ACEPT && next_lts_state == S_CFG_LANENUM_WAIT && ~clear);

always @(posedge core_clk or negedge core_rst_n) begin : link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d_PROC
    if ( ~core_rst_n )
        link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d <= #TP 0;
    else if ( clear )
        link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d <= #TP 0;
    else if ( link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd )
        link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d <= #TP 1;
end // link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d_PROC

assign link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge = link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd & ~link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d & ~clear;

localparam L2NLD2 = `CX_LOGBASE2(NL/2);
reg [L2NL-1:0] next_smlh_lane_flip_ctrl, int_smlh_lane_flip_ctrl;
reg            ecb_g345_compliance_lane_flip; // if Enter Compliance Bit set and over gen3 rate and in Polling.Compliance state, use latched lane flip at linkup
always @(posedge core_clk or negedge core_rst_n) begin : smlh_lane_flip_ctrl_PROC
    if (!core_rst_n)
        int_smlh_lane_flip_ctrl <= #TP 0;
    else
        int_smlh_lane_flip_ctrl <= #TP next_smlh_lane_flip_ctrl;
end

assign ltssm_lane_flip_ctrl = int_smlh_lane_flip_ctrl;

// only in the below three states the 2 Rx TS with pad/pad link/lane on all lanes causes the ltssm transition to Detect state because of lane reversal with skew between lanes and latched signals
assign ltssm_mid_config_state = (lts_state == S_CFG_LINKWD_ACEPT | lts_state == S_CFG_LANENUM_WAIT | lts_state == S_CFG_LANENUM_ACEPT); // do not clear Rx TS count in the other states
// if pad/pad link#/lane# were latched on some lanes and then a lane reversal occurs, ltssm may detect pad/pad link#/lane# on all active lanes. This would cause ltssm transition to Detect.
// So need to clear all the latched flip/reversal related signals when the lane flip/reversal changes
// after the flip, re-start to count 2 consecutive Rx TSs in the narrow link width formed at the time when (int_smlh_lane_flip_ctrl != next_smlh_lane_flip_ctrl)
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_lane_flip_ctrl_chg_pulse_d_PROC
    if (!core_rst_n)
        ltssm_lane_flip_ctrl_chg_pulse_d <= #TP 0; //reg to break Combinatorial Loop
    else
        ltssm_lane_flip_ctrl_chg_pulse_d <= #TP ltssm_mid_config_state & (int_smlh_lane_flip_ctrl != next_smlh_lane_flip_ctrl);
end // ltssm_lane_flip_ctrl_chg_pulse_d_PROC

assign ltssm_lane_flip_ctrl_chg_pulse = ltssm_lane_flip_ctrl_chg_pulse_d;


// if in Loopback.Active from Loopback EQ, the master flips cfg_lane_under_test to logical Lane 0 always. The other lanes keep latched_linkup_lane_flip_ctrl_lpbk
// use mac_phy_rate because phy_mac_fs/lf reversal occurs at phy_mac_phystatus = 1 for speed change, not current_data_rate
assign smlh_lane_flip_ctrl =
                              int_smlh_lane_flip_ctrl;

wire [4:0] lpbk_lane_under_test_i = 0;
always @* begin
    lpbk_lane_under_test = 0;
    lpbk_lane_under_test = lpbk_lane_under_test_i;
end


assign cfg_auto_flip_en = cfg_lane_en[8];
assign cfg_auto_flip_predet_lane = (4'b0001 << cfg_lane_en[7:5]) - 1; // 0->0, 1->1, 2->3, 3->7, 4->15
assign cfg_auto_flip_using_predet_lane = cfg_lane_en[7:5] != 0;

// derive link_mode from max number of lane which is detected and received (15, 7, 3, 1, 0) to form a x1 link when cfg_support_part_lanes_rxei_exit = 1 and link_next_link_mode = 1
reg [5:0] link_mode_part;
always @* begin
    link_mode_part = smlh_link_mode;
    if ( link_next_link_mode == 6'd1 ) begin
        if ( link_lanes_rcving[0] )
            link_mode_part = 1;
        else if ( link_lanes_rcving[3] )
            link_mode_part = 4;
        else if ( link_lanes_rcving[1] )
            link_mode_part = 2;
    end
end
wire [5:0] smlh_link_mode_part = cfg_support_part_lanes_rxei_exit ? link_mode_part : smlh_link_mode;

// next_smlh_lane_flip_ctrl[3,2,1,0]: 0 - lane 2; 1 - lane 4; 2 - lane 8; 3 - lane 16
// change for spyglass check pass
always @(*) begin : next_smlh_lane_flip_ctrl_PROC
    next_smlh_lane_flip_ctrl = 0;
    if( cfg_auto_flip_en ) begin
        if( !cfg_auto_flip_using_predet_lane ) begin
            // autoflip based on detected lanes - executed in S_DETECT_WAIT
            case (lts_state)
                S_DETECT_QUIET: begin
                    if ( ltssm_powerdown == `P1 )
                        next_smlh_lane_flip_ctrl = 0;
                end
                S_DETECT_WAIT: begin
                    // priority logic to determine the widest flip possible
                    if( latchd_detected_lanes[0] ) next_smlh_lane_flip_ctrl = 0; // no flip needed
                    else if( latchd_detected_lanes[NL-1] ) next_smlh_lane_flip_ctrl[L2NL-1] = 1'b1; // flip xNL
                    else if( latchd_detected_lanes[NL/2-1] ) next_smlh_lane_flip_ctrl[L2NLD2-1] = 1'b1; // flip xNL/2
                    // else next_smlh_lane_flip_ctrl = 0; // cannot form a link
                end // S_DETECT_WAIT
                S_CFG_LINKWD_START, S_CFG_LINKWD_ACEPT, S_CFG_LANENUM_ACEPT: begin
                    next_smlh_lane_flip_ctrl = int_smlh_lane_flip_ctrl;

                    if ( (state_cfg_linkwd_start_wait && cfg_upstream_port && ~link_lane0_2_ts1_linkn_planen_rcvd && (link_next_link_mode > 0)) || //usp lane0 doesn't receive non-pad link# in S_CFG_LINKWD_START
                         (state_cfg_linkwd_acept_wait && cfg_upstream_port && ~link_lane0_2_ts1_linknmtx_lanen_rcvd && (link_next_link_mode > 0)) || //usp lane0 doesn't receive link# match TX and non-PAD lane# in S_CFG_LINKWD_ACEPT
                         (state_cfg_linkwd_acept_wait && ~cfg_upstream_port && ~link_lane0_2_ts1_linknmtx_rcvd && (link_next_link_mode > 0)) || //dsp lane0 doesn't receive link# match TX in S_CFG_LINKWD_ACEPT
                         //usp S_CFG_LINKWD_ACEPT -> S_CFG_LANENUM_WAIT or dsp S_CFG_LANENUM_ACEPT -> S_CFG_LANENUM_WAIT, lane0 receives lane# != 0
                         (state_cfg_linkwd_acept_to_cfg_lanenum_wait && cfg_upstream_port && ~link_latched_live_lane0_2_ts1_lanen0_rcvd && (link_next_link_mode > 0)) ||
                         // link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge is link number matching TX and reversed lane number matching TX on all smlh_lanes_active (~link_mode_changed) monitored continuously regardless of 1ms or 2ms timeout
                         ((state_cfg_lanenum_acept_wait || (link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge && lts_state == S_CFG_LANENUM_ACEPT)) && ~cfg_upstream_port && ~link_latched_live_lane0_2_ts1_lanen0_rcvd && link_latched_live_all_2_ts1_linknmtx_lanen_rcvd && ~link_mode_changed) ||
                         (state_cfg_lanenum_acept_to_cfg_lanenum_wait && ~link_latched_live_lane0_2_ts1_lanen0_rcvd && (link_next_link_mode > 0)) ) begin
//                         (state_in_cfg_lanenum_wait && link_all_2_ts1_linknmtx_lanen_rcvd_rising_edge && ~link_latched_live_lane0_2_ts1_lanen0_rcvd && ~clear) ) begin
                        if ( smlh_link_mode_part == 1 ) next_smlh_lane_flip_ctrl = 0; // no reverse needed, only lane 0 works
                        else if ( smlh_link_mode_part == 2 ) next_smlh_lane_flip_ctrl[0] = ~int_smlh_lane_flip_ctrl[0]; // reverse x2
                        else if ( smlh_link_mode_part == 4 ) next_smlh_lane_flip_ctrl[1] = ~int_smlh_lane_flip_ctrl[1]; // reverse x4
                    end
                end // S_CFG_LINKWD_START
                default: next_smlh_lane_flip_ctrl = int_smlh_lane_flip_ctrl;
            endcase
        end else begin
            // autoflip based on predetermined lane - executed regardless of LTSSM state
            next_smlh_lane_flip_ctrl = 0; // no flip on illegal programming values or when NL=1
            if( cfg_auto_flip_predet_lane==NL-1 ) next_smlh_lane_flip_ctrl[L2NL-1] = 1'b1; // flip xNL
            else if( cfg_auto_flip_predet_lane==NL/2-1 ) next_smlh_lane_flip_ctrl[L2NLD2-1] = 1'b1; // flip xNL/2
        end
    end
end
// end smlh_lane_flip_ctrl logic

//Errata B3
reg [NL-1:0] ltssm_lanes_active_r;
always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n)
    ltssm_lanes_active_r <= #TP 0;
  else begin
    if ( lts_state == S_CFG_COMPLETE && next_lts_state != S_CFG_COMPLETE && !clear )
      ltssm_lanes_active_r <= #TP latchd_smlh_lanes_rcving;
  end
end

always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n)
    ltssm_lanes_active_d <= #TP 0;
  else begin
      ltssm_lanes_active_d <= #TP 0;
  end
end

wire [NL-1:0] int_active = 0;
always @* begin : int_active_PROC
    lpbk_eq_lanes_active = 0;
    lpbk_eq_lanes_active = int_active;
end // int_active_PROC

assign lpbk_eq_n_lut_pset = 0;
assign lpbk_eq = 0;

wire load_link_capable ;
assign load_link_capable = cfg_por_phystatus_mode ? 1'b1 : all_phystatus_deasserted ;

// LMD: Truncation of bits in constant. Most significant bits are lost
// LJ: If NL < 16, the most significant bits of ltssm_lanes_active are DO NOT CARE
// leda W163 off
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_lanes_active_PROC
    if (!core_rst_n) begin
        ltssm_lanes_active      <= #TP {NL{1'b1}};  // All lanes start out as active
        ltssm_lanes_activated_pulse   <= #TP 0;
    end else if ( cfg_support_part_lanes_rxei_exit && smlh_link_mode == 6'd1 && lts_state != S_DETECT_QUIET ) begin
        ltssm_lanes_active <= #TP {{(NL-1){1'b0}},1'b1};
    end else if ( lts_state == S_LPBK_ACTIVE && lpbk_master ) // to narrow active lanes in S_LPBK_ACTIVE for lpbk_master so that TX data can be received over the lanes
        ltssm_lanes_active <= #TP ltssm_lanes_active & link_imp_lanes;
    else if ((lts_state == S_DETECT_QUIET) && cfg_auto_flip_en && cfg_auto_flip_using_predet_lane && load_link_capable) ltssm_lanes_active  <= #TP 16'h0001; // same as having cfg_link_capable=4'b00001
    // in DETECT ACTIVE state, we need to detect the active lanes. If
    // we do not receive all of the lanes that we think it is active, then
    // we will give a chance of retry the detect to make sure that the same
    // active lanes are detected.
    // Note: Here we will  update the ltssm_lanes_active when the
    // detected active lanes are not matching what we think from
    // configuration capablity. all_phy_mac_rxdetected determines the
    // matching of active lanes with detected lanes
    else if ((lts_state == S_DETECT_ACT) & int_rxdetect_done & !clear & (next_lts_state == S_POLL_ACTIVE)) ltssm_lanes_active  <= #TP (ltssm_lanes_active & int_rxdetected);
    else if (cfg_link_capable[2] & (lts_state == S_DETECT_QUIET) & load_link_capable) ltssm_lanes_active  <= #TP 16'h000f;
    else if (cfg_link_capable[1] & (lts_state == S_DETECT_QUIET) & load_link_capable) ltssm_lanes_active  <= #TP 16'h0003;
    else if (cfg_link_capable[0] & (lts_state == S_DETECT_QUIET) & load_link_capable) ltssm_lanes_active  <= #TP 16'h0001;
    // ltssm_lanes_active gets updated again upon entering CFG_COMPLETE
    else if ( (lts_state == S_CFG_COMPLETE) & !clear & (next_lts_state == S_CFG_IDLE) )  ltssm_lanes_active  <= #TP latchd_smlh_lanes_rcving;
    else if ( lts_state == S_CFG_LINKWD_START ) begin
        if(clear && directed_link_width_change_up)
            ltssm_lanes_active <= #TP target_link_lanes_active;
        else if( !clear & upconfigure_capable ) begin
            ltssm_lanes_active <= #TP ltssm_lanes_active | remote_lanes_activated ;
            ltssm_lanes_activated_pulse <= #TP (ltssm_lanes_active != (ltssm_lanes_active | remote_lanes_activated));
        end
    end
    // Errata B3, ltssm_lanes_active gets updated again upon entering cfg.linkwd.start from Recovery
    else if ( (lts_state == S_RCVRY_IDLE || lts_state == S_RCVRY_LOCK || lts_state == S_RCVRY_RCVRCFG) & !clear & (next_lts_state == S_CFG_LINKWD_START) )
      ltssm_lanes_active  <= #TP ltssm_lanes_active_r;
    else                                                      ltssm_lanes_active  <= #TP ltssm_lanes_active;
end
// leda W163 on

// deskew_lanes_active is identical to ltssm_lanes_active,
// except that it is continuously updated in S_CFG_LANENUM_ACEPT
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        deskew_lanes_active      <= #TP {NL{1'b1}};  // All lanes start out as active
    else if ( lts_state == S_LPBK_ACTIVE && lpbk_master ) // to narrow active lanes in S_LPBK_ACTIVE for lpbk_master so that TX data can be received over the lanes after deskew
        deskew_lanes_active      <= #TP next_deskew_lanes_active;
    else if (update_deskew_lanes_active)
        deskew_lanes_active      <= #TP next_deskew_lanes_active;

assign next_deskew_lanes_active =
       (lts_state == S_LPBK_ACTIVE & lpbk_master) ? ( (deskew_lanes_active & link_imp_lanes)) :
       (lts_state == S_DETECT_ACT) & int_rxdetect_done & !clear & (next_lts_state == S_POLL_ACTIVE)  ? (deskew_lanes_active & int_rxdetected & ltssm_lanes_active) :

       cfg_link_capable[2] & (lts_state == S_DETECT_QUIET) ? 16'h000f :
       cfg_link_capable[1] & (lts_state == S_DETECT_QUIET) ? 16'h0003 :
       cfg_link_capable[0] & (lts_state == S_DETECT_QUIET) ? 16'h0001 :
      (  (lts_state == S_CFG_LINKWD_ACEPT )
       | (lts_state == S_CFG_LANENUM_WAIT )
       | (lts_state == S_CFG_LANENUM_ACEPT) ) ? latchd_smlh_lanes_rcving : deskew_lanes_active;

assign update_deskew_lanes_active =
       (lts_state == S_DETECT_ACT) & int_rxdetect_done & !clear & (next_lts_state == S_POLL_ACTIVE) |
       cfg_link_capable[4] & (lts_state == S_DETECT_QUIET) |
       cfg_link_capable[3] & (lts_state == S_DETECT_QUIET) |
       cfg_link_capable[2] & (lts_state == S_DETECT_QUIET) |
       cfg_link_capable[1] & (lts_state == S_DETECT_QUIET) |
       cfg_link_capable[0] & (lts_state == S_DETECT_QUIET) |
      (  (lts_state == S_CFG_LINKWD_ACEPT )
             | (lts_state == S_CFG_LANENUM_WAIT )
       | (lts_state == S_CFG_LANENUM_ACEPT) );

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        deskew_lanes_active_change  <= #TP 1'b0;
    else if (update_deskew_lanes_active)
        deskew_lanes_active_change  <= #TP (deskew_lanes_active != next_deskew_lanes_active);
    else
        deskew_lanes_active_change  <= #TP 1'b0;

assign ltssm_entry_cfgcomplete_rcvrycfg_pulse = clear & (lts_state == S_CFG_COMPLETE || lts_state == S_RCVRY_RCVRCFG);

always @( posedge core_clk or negedge core_rst_n ) begin : active_nb_d_PROC
    if ( ~core_rst_n ) begin
        active_nb_d <= #TP `CX_NB;
    end else begin
        active_nb_d <= #TP active_nb;
    end
end // active_nb_d_PROC

// smlh_do_deskew is really acting as an active low reset to the deskew logic
// the conditions in OR below determine when to drive this to 0
// for CX_16S_EN, the core needs more RX TSs to delay resetting the deskew block because deskew block may still be processing Rx Data Stream if using link_any_exact_2_ts_rcvd to reset deskew block
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_do_deskew      <= #TP 1;
    else
        smlh_do_deskew      <= #TP ~( ((lts_state == S_RCVRY_LOCK) && (((timeout_24ms && link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd) || link_any_exact_2_ts_rcvd) && ~clear)
                                      )
                                    || (lts_state == S_DETECT_ACT)
                                    || (lts_state == S_POLL_COMPLIANCE)
                                    || ((lts_state == S_CFG_LINKWD_ACEPT) && link_any_exact_1_ts_rcvd && ~clear) //reset. this state is only from Cfg.Linkwidth.Start, late lane Rx data already gone through and ts2 has not arrived
                                    || (lts_state == S_LPBK_ENTRY) //reset because speed change or the remote loopback will cause deskew loss
                                    || (lts_state == S_RCVRY_SPEED)
                                    || ((r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE) && (curnt_l0s_rcv_state == S_L0S_RCV_FTS)) //reset. deskew block has time to detect SKP after the reset. late lane Rx data is ok.
                                    || deskew_lanes_active_change
                                    || (next_smlh_lane_flip_ctrl != int_smlh_lane_flip_ctrl) // reset the deskew block to redo deskew if lane reversed
                                    );

assign  smlh_link_mode  = int_smlh_link_mode;

always @(posedge core_clk or negedge core_rst_n) begin : int_smlh_link_mode_PROC
    if ( ~core_rst_n )
        int_smlh_link_mode <= #TP 0;
    else if ( lts_state == S_DETECT_QUIET || lts_state == S_POLL_ACTIVE || link_mode_activated_pulse || (lts_state == S_LPBK_ACTIVE && lpbk_master) ) begin
        int_smlh_link_mode <= #TP
            (ltssm_lanes_active[3:0]  == 4'hF ) ? 4 :
            (ltssm_lanes_active[1:0]  == 2'b11 ) ? 2 :
            1'b1;
    end else if ( clear &&
                  ( ( lts_state == S_CFG_LINKWD_START && ( !cfg_upstream_port && directed_link_width_change_up ||
                                                           cfg_upstream_port && directed_link_width_change_updown ) ) ||
                    ( lts_state == S_CFG_LINKWD_ACEPT && !cfg_upstream_port && directed_link_width_change_down ) ) ) begin
        int_smlh_link_mode <= #TP latched_target_link_width;
    end else if ( cfg_upstream_port && state_cfg_linkwd_start_wait ) begin
        int_smlh_link_mode <= #TP link_next_link_mode == 0 ? int_smlh_link_mode : link_next_link_mode; //0 - not ready to form a link at this time, wait for next timeout
    end else if ( state_cfg_linkwd_acept_wait || state_cfg_lanenum_acept_wait ) begin
        int_smlh_link_mode <= #TP link_next_link_mode == 0 ? int_smlh_link_mode : link_next_link_mode; //0 - not ready to form a link at this time, wait for next timeout
    end
end // int_smlh_link_mode_PROC

always @(posedge core_clk or negedge core_rst_n) begin : link_mode_changed_PROC
  if ( ~core_rst_n )
    link_mode_changed <= 1'b0;
  else if ( lts_state == S_CFG_LANENUM_ACEPT ) begin 
    if( state_cfg_lanenum_acept_wait && link_next_link_mode!=0 && link_next_link_mode!=int_smlh_link_mode )
      link_mode_changed <= 1'b1;
  end
  else
    link_mode_changed <= 1'b0;
end

always @(posedge core_clk or negedge core_rst_n) begin : smlh_link_rxmode_PROC
    if ( ~core_rst_n )
        smlh_link_rxmode <= #TP 0;
    else if ( ltssm != S_CFG_LINKWD_START )
        smlh_link_rxmode <= #TP smlh_link_mode;
end

always @(posedge core_clk or negedge core_rst_n) begin : linkup_link_mode_PROC
    if ( ~core_rst_n )
        linkup_link_mode <= #TP 0;
    else if ( !smlh_link_up )
        linkup_link_mode <= #TP smlh_link_mode;
end

always @(posedge core_clk or negedge core_rst_n) begin : smlh_no_turnoff_lanes_PROC
    if ( ~core_rst_n )
        smlh_no_turnoff_lanes <= #TP 0;
    else if ( smlh_link_up )
        smlh_no_turnoff_lanes <= #TP 
                                     linkup_link_mode[2] ? 'h000f :
                                     linkup_link_mode[1] ? 'h0003 :
                                                           'h0001;
end

always @(posedge core_clk or negedge core_rst_n) begin : latest_link_mode_PROC
    if ( ~core_rst_n )
        latest_link_mode <= #TP 0;
    else if ( lts_state != S_L0 && next_lts_state == S_L0 && !clear )
        latest_link_mode <= #TP smlh_link_mode;
end

  // this is used to allow one time retry receiver detect
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        retry_detect      <= #TP 0;
    else
        retry_detect      <= #TP (ltssm == S_DETECT_QUIET) ? 1'b0 : (ltssm == S_DETECT_WAIT) ? 1'b1 : retry_detect;

reg                 cfg_force_en_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        cfg_force_en_d      <= #TP 0;
    else
        cfg_force_en_d      <= #TP cfg_force_en;

wire                cfg_force_state;
assign  cfg_force_state = !cfg_force_en_d & cfg_force_en;

assign  current_n_fts = cfg_n_fts;

wire   [8:0]  floor_p_nfts;
wire   [8:0]  floor_x2_p_nfts;
wire   [23:0] floor_x2_p_nfts_x_8;
wire   [23:0] floor_p_nfts_x_16;
wire   [23:0] floor_p_nfts_x_32;
wire   [23:0] nfts_x_16;
wire   [23:0] nfts_x_32;
wire   [T_WD-1:0] timeout_nfts_value;
assign floor_p_nfts = {6'b0,current_n_fts[7:5]}+{1'b0,current_n_fts}; //N_FTS + Floor(N_FTS/32)
assign floor_x2_p_nfts = {5'b0,current_n_fts[7:5]<<1}+{1'b0,current_n_fts}; //N_FTS + 2*Floor(N_FTS/32)
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The left shift of floor_x2_p_nfts_x_8,floor_p_nfts_x_16,floor_p_nfts_x_32,nfts_x_16,nfts_x_32 insures that the MSB will be 0 in which case the addition cannot overflow and there is space for the carry bit.
assign floor_x2_p_nfts_x_8 = ({15'b0,floor_x2_p_nfts}<<3);
assign floor_p_nfts_x_16 = ({15'b0,floor_p_nfts}<<4);
assign floor_p_nfts_x_32 = ({15'b0,floor_p_nfts}<<5);
assign nfts_x_16 = ({16'b0,current_n_fts}<<4);
assign nfts_x_32 = ({16'b0,current_n_fts}<<5);
// spyglass enable_block W164a

//UI = 400ps for Gen1, 200ps for Gen2, 125ps for Gen3, 62.5ps for Gen4, 31.25ps for Gen5
//each clock takes 4ns for CX_PL_FREQ_VALUE=0, 8ns for CX_PL_FREQ_VALUE=1, 16ns for CX_PL_FREQ_VALUE=2
//calculated timeout value needs to be divided by 4 for CX_PL_FREQ_VALUE=0, by 8 for CX_PL_FREQ_VALUE=1, by 16 for CX_PL_FREQ_VALUE=2, and then match timer number

//Gen1
//When ext_synch=0, Spec required time is 40*(N_FTS+3)*UI*2 (ps) = 96+(32*N_FTS) (ns)
//     timeout_nfts_value = ((96+(32*N_FTS)) >> 2) >> CX_PL_FREQ_VALUE
//When ext_synch=1, Spec required time is 40*2048*UI*2 (ps) = 65536 (ns)
//     timeout_nfts_value = 16384 >> CX_PL_FREQ_VALUE

//Gen2
//When ext_synch=0, Spec required time is 40*(N_FTS+3)*UI*2 (ps) = 48+(16*N_FTS) (ns)
//     timeout_nfts_value = ((48+(16*N_FTS)) >> 2) >> CX_PL_FREQ_VALUE
//When ext_synch=1, Spec required time is 40*2048*UI*2 (ps) = 32768 (ns)
//     timeout_nfts_value = 8192 >> CX_PL_FREQ_VALUE

//Gen3
//When ext_synch=0, Spec required time is 130*(N_FTS+5+Floor(N_FTS/32))*UI*2 (ps) = 162+(32*(N_FTS+Floor(N_FTS/32))) (ns)
//     timeout_nfts_value = ((162+(32*(N_FTS+Floor(N_FTS/32)))) >> 2) >> CX_PL_FREQ_VALUE
//When ext_synch=1, Spec required time is 130*(4096+5+12+(4096/32))*UI*2 (ps) = 137832 (ns)
//     timeout_nfts_value = 34458 >> CX_PL_FREQ_VALUE

//Gen4
//When ext_synch=0, Spec required time is 130*(N_FTS+5+Floor(N_FTS/32))*UI*2 (ps) = 81+(16*(N_FTS+Floor(N_FTS/32))) (ns)
//     timeout_nfts_value = ((81+(16*(N_FTS+Floor(N_FTS/32)))) >> 2) >> CX_PL_FREQ_VALUE
//When ext_synch=1, Spec required time is 130*(4096+5+12+(4096/32))*UI*2 (ps) = 68916 (ns)
//     timeout_nfts_value = 17229 >> CX_PL_FREQ_VALUE

//Gen5
//When ext_synch=0, Spec required time is 130*(N_FTS+10+2*Floor(N_FTS/32))*UI*2 (ps) = 81+(8*(N_FTS+2*Floor(N_FTS/32))) (ns)
//     timeout_nfts_value = ((81+(8*(N_FTS+2*Floor(N_FTS/32)))) >> 2) >> CX_FREQ_VALUE
//When ext_synch=1, Spec required time is 130*(4096+10+12+2*(4096/32))*UI*2 (ps) = 35538 (ns)
//     timeout_nfts_value = 8886 >> CX_FREQ_VALUE

assign timeout_nfts_value = cfg_ext_synch ? (
                                                                                (16384>>`CX_PL_FREQ_VALUE) ) :
                                            (
                                                                                (((96+nfts_x_32)>>2)>>`CX_PL_FREQ_VALUE)
                                            );

// cannot freeze the timer when mac_phy_rate != current_data_rate because it will cause issue when phystatus never be back.
// when (mac_phy_rate > current_data_rate), use mac_phy_rate to assign timer2; else use current_data_rate.
// this will keep timer running to prevent LTSSM stuck because of no timeout occuring if phystatus never be back.
// the calculated timing might be bigger than expected.
logic   [2:0]  int_data_rate;
assign int_data_rate = current_data_rate;

wire       timer2;
wire   timer_freq_multiplier;
assign timer_freq_multiplier = 1'b1;

DWC_pcie_tim_gen
 u_gen_timer2
(
     .clk               (core_clk)
    ,.rst_n             (core_rst_n)

    ,.current_data_rate (int_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)

    ,.cnt_up_en         (timer2)  // timer count-up 
);



always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        timer    <= #TP 0;
    // clear the timer when in HOT_RESET_ENTRY state and still receiving TS1 with reset
    end else if (clear || clr_timer_4rl0s
                 || (lts_state==S_HOT_RESET_ENTRY & link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd)
                 || (curnt_lpbk_entry_state==S_LPBK_ENTRY_EIDLE & xmtbyte_eidle_sent)
                 || !app_ltssm_enable_dd) begin
        timer     <= #TP 0;
    end else if (   !timeout_48ms
                ) begin
        timer     <= #TP timer + (timer2 ? timer_freq_multiplier : 1'b0);

    end

always @(posedge core_clk or negedge core_rst_n) begin : timer_40ns_4rl0s_PROC
    if ( !core_rst_n ) begin
        timer_40ns_4rl0s     <= #TP 0;
    // clear the timer when clr_timer_4rl0s
    end else if ( clr_timer_4rl0s || (rmlh_rcvd_eidle_set && (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE || lts_state == S_L123_SEND_EIDLE || lts_state == S_DISABLED_IDLE || lts_state == S_DISABLED_ENTRY )) ) begin
        timer_40ns_4rl0s     <= #TP 0;
    end else if ( !timeout_40ns_4rl0s ) begin
        timer_40ns_4rl0s     <= #TP timer_40ns_4rl0s + (timer2 ? timer_freq_multiplier : 1'b0);
    end
end //timer_40ns_4rl0s_PROC

//logic below is to calculate a scaling factor for the 40ns timer used for L0s, L1 and L2 entry. Intent is to scale this timer with n_fts
//to provide more time to the phy to stabilize rxelecidle to 1 and prevent premature exit.
//The min time is 48ns and max time is (4 * 48ns). The multiplier calculation is based on the formula: ((current_n_fts - 2) * (GEN2 ? 8ns : 16ns))/48ns.
//48ns is because `CX_TIME_40NS = 12/`CX_PL_FREQ_MULTIPLIER, (12 * 4ns == 48ns). 8ns for GEN2 is because FTS OS is 4 FTS-Symbols x 2ns.
//16ns for Gen1 and Gen3 is because 4 FTS-Symbols x 4ns for Gen1 and 16 FTS-Symbols x 1ns for Gen3.
wire [1:0] nfts_factor; // scaling factor for low power entry time
assign     nfts_factor = (current_data_rate == `GEN2_RATE) ? (current_n_fts<14 ? 0 : current_n_fts<26 ? 1 : 2) :
                                                             (current_n_fts<50 ? 0 : current_n_fts<86 ? 1 : 2) ;


// Timer and logic for inferred electrical idle

reg             speed_clear;        // clear signal for comma timer and timeouts
wire            inf_count_ui;       // indicates that the timer is counting UI's instead of time
reg             latched_eqctl_any_8eqts2_rcvd;
wire int_eqctl_any_8eqts2_rcvd = 1'b0;

always @(posedge core_clk or negedge core_rst_n) begin : eqctl_any_8eqts2_rcvd_r_PROC
    if ( !core_rst_n ) begin
        latched_eqctl_any_8eqts2_rcvd <= #TP 0;
    end else if ( lts_state != S_RCVRY_RCVRCFG ) begin
        latched_eqctl_any_8eqts2_rcvd <= #TP 0;
    end else if (int_eqctl_any_8eqts2_rcvd && !clear) begin
        latched_eqctl_any_8eqts2_rcvd <= #TP 1;
    end
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        speed_clear         <= #TP 1'b0;
    else
        speed_clear         <= #TP ((next_lts_state != lts_state) & !clear) || app_ltssm_enable_fall_edge;     // clean flags when the state changes


  
// This counter counts the cycles since a comma was seen
// we also use it for the timeouts in Recovery.Speed after the receiver detects electrical idle.
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        speed_timer         <= #TP 0;
    else if ( speed_clear ||
              // also clean the timer when a comma is received and we haven't already inferred electrical idle.
              ((!latched_eidle_seen || ~(&xmtbyte_txelecidle)) && (lts_state == S_RCVRY_SPEED))
              || (!latched_eqctl_any_8eqts2_rcvd && (lts_state == S_RCVRY_RCVRCFG)) //clear the timer when 8 consecutive EQ TS2 rcvd on any lane
            )
        speed_timer         <= #TP 0;
    else if ( ~compare_19(speed_timer, {19{1'b1}}) )  // hold value so we don't wrap
        speed_timer         <= #TP speed_timer + (timer2 ? timer_freq_multiplier : 1'b0);

// used for recovery speed
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        speed_timeout_800ns     <= #TP 1'b0;
    else if (speed_clear || !latched_eidle_seen || ~(&xmtbyte_txelecidle))
        speed_timeout_800ns     <= #TP 1'b0;
    else if ( compare_25({6'h0,speed_timer}, `CX_TIME_800NS) && latched_eidle_seen )
        speed_timeout_800ns     <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        speed_timeout_6us       <= #TP 1'b0;
    else if (speed_clear || !latched_eidle_seen || ~(&xmtbyte_txelecidle))
        speed_timeout_6us       <= #TP 1'b0;
    else if ( compare_25({6'h0,speed_timer}, `CX_TIME_6US) && latched_eidle_seen)
        speed_timeout_6us       <= #TP 1'b1;



assign  inf_count_ui    = (lts_state == S_RCVRY_RCVRCFG) || (lts_state == S_RCVRY_SPEED);

wire   eidle_inferred_recovery;
assign eidle_inferred_recovery = smlh_eidle_inferred & (lts_state == S_L0);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_eidle_seen       <= #TP 1'b0;
    else if ((smlh_eidle_inferred & !clear) || rmlh_rcvd_eidle_set)
        latched_eidle_seen       <= #TP 1'b1;
    else if ((next_lts_state != lts_state) && ((next_lts_state != S_RCVRY_SPEED) || latched_eidle_inferred) && !clear) // use anticipated clear, needed to avoid races if new state also is sensitive to the flag
        latched_eidle_seen       <= #TP 1'b0;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_eidle_inferred   <= #TP 1'b0;
    else if (smlh_eidle_inferred & !clear) // same condition as for the latched_eidle_seen flag, without the EIOS received
        latched_eidle_inferred   <= #TP 1'b1;
    else if (clear) // do not use anticipated clear because this flag is only used after the transition to check that the transition was made with the flag
        latched_eidle_inferred   <= #TP 1'b0;


// timeout value based on link mode
assign  polling_timeout_value   = ( cfg_fast_link_mode ) ?  fast_time_1ms  : `CX_TIME_1MS;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_polling_eidle   <= #TP 0;
    else if ((lts_state == S_POLL_COMPLIANCE) // we are in Polling.Compliance
              && (   ((next_compliance_state == S_COMPL_ENT_TX_EIDLE)  && (curnt_compliance_state != S_COMPL_ENT_TX_EIDLE))            // clear the timeout the state before we'll be checking it
                   || ((next_compliance_state == S_COMPL_EXIT_TX_EIDLE) && (curnt_compliance_state != S_COMPL_EXIT_TX_EIDLE))))
        timeout_polling_eidle   <= #TP 0;
    else if ((lts_state == S_POLL_COMPLIANCE) && (compare_t_wd(timer, polling_timeout_value)))
        timeout_polling_eidle   <= #TP 1'b1;

// End of Eidle Inferred Logic
// -------------------------------------------------------------------------

wire            enter_cfg_linkwidth_start;
assign  enter_cfg_linkwidth_start = (next_lts_state == S_CFG_LINKWD_START) && (lts_state != S_CFG_LINKWD_START) && !clear;



// RxL0s/L1/L2/Disable Entry condition
wire ei_interval_expire;
wire all_rxstandbystatus;
assign all_rxstandbystatus = &( ~int_lanes_active_rxstandby | phy_mac_rxstandbystatus ) ;
assign ei_interval_expire  = (cfg_p1_entry_policy[1:0]==2'b00) ? timeout_40ns_4rl0s : 
                             (cfg_p1_entry_policy[1:0]==2'b01) ? all_phy_mac_rxelecidle :
                             (cfg_p1_entry_policy[1:0]==2'b10) ? all_rxstandbystatus | timeout_40ns_4rl0s : 1'b1 ;
// L1/L2/Disable Entry Interval Time
// Minimum = 160 ns
// Can be extended to 320ns (640ns if RASDES=1)
reg  [3:0] p1_entry_factor_case;
reg  [2:0] p1_entry_factor;
wire       p1_entry_state;
assign p1_entry_factor_case = { 2'b00, cfg_p1_entry_policy[3:2]};
always @(*) begin
    casez({p1_entry_factor_case})
        4'b00_11: p1_entry_factor = 1 ;  // 80ns
        4'b00_10: p1_entry_factor = 0 ;  // 40ns
        4'b00_01: p1_entry_factor = 3 ;  // 320ns
        default : p1_entry_factor = 2 ;  // Default 160ns
    endcase
end
assign p1_entry_state = (lts_state == S_L123_SEND_EIDLE) | (lts_state == S_DISABLED_IDLE) | (lts_state == S_DISABLED_ENTRY) ;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_40ns  <= #TP 0;
    else if (clear || clr_timer_4rl0s)
        timeout_40ns  <= #TP 0;
    else if (timer >= (`CX_TIME_40NS << nfts_factor))
        timeout_40ns  <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_40ns_4rl0s_PROC
    if ( !core_rst_n )
        timeout_40ns_4rl0s  <= #TP 0;
    else if ( clr_timer_4rl0s || (rmlh_rcvd_eidle_set && (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE || lts_state == S_L123_SEND_EIDLE || lts_state == S_DISABLED_IDLE || lts_state == S_DISABLED_ENTRY )) )
        timeout_40ns_4rl0s  <= #TP 0;
    else if (  p1_entry_state && timer_40ns_4rl0s >= (`CX_TIME_40NS << p1_entry_factor) )
        timeout_40ns_4rl0s  <= #TP 1'b1;
    else if ( !p1_entry_state && timer_40ns_4rl0s >= ((`CX_TIME_40NS << nfts_factor )) )
        timeout_40ns_4rl0s  <= #TP 1'b1;
end //timeout_40ns_4rl0s_PROC

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_1ms  <= #TP 0;
    else if (clear)
        timeout_1ms  <= #TP 0;
    else if ((cfg_fast_link_mode && (compare_t_wd(timer, fast_time_1ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_1MS)))  
        timeout_1ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_1ms_d_PROC
    if ( ~core_rst_n ) begin
        timeout_1ms_d <= #TP 0;
    end else begin
        timeout_1ms_d <= #TP timeout_1ms;
    end
end // timeout_1ms_d_PROC

assign int_timeout_1ms_rising_edge = timeout_1ms & ~timeout_1ms_d;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_1us  <= #TP 0;
    else if (clear)
        timeout_1us  <= #TP 0;
    else if (compare_t_wd(timer, `CX_TIME_1US))
        timeout_1us <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_10us  <= #TP 0;
    else if (clear)
        timeout_10us  <= #TP 0;
    else if (compare_t_wd(timer, `CX_TIME_10US))
        timeout_10us <= #TP 1'b1;



always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_2ms  <= #TP 0;
    else if (clear)
        timeout_2ms  <= #TP 0;
    else if ((cfg_fast_link_mode && (compare_t_wd(timer, fast_time_2ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_2MS)))  
        timeout_2ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_2ms_d_PROC
    if (!core_rst_n)
        timeout_2ms_d <= #TP 0;
    else
        timeout_2ms_d <= #TP timeout_2ms;
end // timeout_2ms_d_PROC

assign int_timeout_2ms_rising_edge = timeout_2ms & ~timeout_2ms_d;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_12ms_d_PROC
    if (!core_rst_n)
        timeout_12ms_d <= #TP 0;
    else
        timeout_12ms_d <= #TP timeout_12ms;
end // timeout_2ms_d_PROC

assign int_timeout_12ms_rising_edge = timeout_12ms & ~timeout_12ms_d;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_24ms_d_PROC
    if (!core_rst_n)
        timeout_24ms_d <= #TP 0;
    else
        timeout_24ms_d <= #TP timeout_24ms;
end // timeout_2ms_d_PROC

assign int_timeout_24ms_rising_edge = timeout_24ms & ~timeout_24ms_d;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_3ms_PROC
    if (!core_rst_n)
        timeout_3ms  <= #TP 0;
    else if (clear)
        timeout_3ms  <= #TP 0;
    else if ( (cfg_fast_link_mode && (compare_t_wd(timer, fast_time_3ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_3MS)) )  
        timeout_3ms <= #TP 1'b1;
end // timeout_3ms_PROC

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_12ms <= #TP 1'b0;
    else if (clear)
        timeout_12ms <= #TP 1'b0;
    else if ((cfg_fast_link_mode && (compare_t_wd(timer, fast_time_12ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_12MS)))  
        timeout_12ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_10ms <= #TP 1'b0;
    else if (clear)
        timeout_10ms <= #TP 1'b0;
    else if ((cfg_fast_link_mode && (compare_t_wd(timer, fast_time_10ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_10MS)))  
        timeout_10ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_24ms <= #TP 1'b0;
    else if (clear)
        timeout_24ms <= #TP 1'b0;
    else if ((cfg_fast_link_mode && compare_t_wd(timer, fast_time_24ms)) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_24MS))) 
        timeout_24ms <= #TP 1'b1;


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_32ms <= #TP 1'b0;
    else if (clear)
        timeout_32ms <= #TP 1'b0;
    else if ((cfg_fast_link_mode && compare_t_wd(timer, fast_time_32ms)) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_32MS))) 
        timeout_32ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_48ms <= #TP 1'b0;
    else if (clear || clr_timer_4rl0s) // clear timeout_48ms to keep the timer running to count 40ns when transitioning L0 -> Rx.L0s
        timeout_48ms <= #TP 1'b0;
    else if ((cfg_fast_link_mode && compare_t_wd(timer, fast_time_48ms)) || (~cfg_fast_link_mode && compare_t_wd(timer,`CX_TIME_48MS)))
        timeout_48ms <= #TP 1'b1;

// For "8 GT/s Receiver Impedance" ECN, implement a 100 ms timer.

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_nfts <= #TP 0;
    else if (clear | clr_timer_4rl0s)
        timeout_nfts <= #TP 1'b0;
    else if (timer >= timeout_nfts_value)
        timeout_nfts <= #TP 1'b1;


wire                detect_state;
assign  detect_state = (lts_state == S_DETECT_ACT) | (lts_state == S_DETECT_QUIET);

wire    [NL-1:0]    predet_lanes;  // predetermined lanes from cfg_lane_en
assign  predet_lanes = Get_predet_lane_mask({4'b0000, cfg_lane_en[4:0]}); // don't use upper bits because these bits are repurposed to control autoflip

// This function converts a number of lanes (from cfg_lane_en) into a mask with one bit per lane.
// Example: if NL=8 and cfg_lane_en = 9'd4, Get_predet_lane_mask = 8'b00001111
function automatic [NL-1:0]   Get_predet_lane_mask;
input   [8:0]       cfg_lane_en;
// LMD: Use fully assigned variables in function
// LJ: The range of values of the variable i are define by the parameter NL
// leda FM_2_35 off
reg     [NL-1:0]    int_predet_lanes;
integer             i;
    begin
        int_predet_lanes = {NL{1'b0}};
        for (i = 0; i < NL; i= i+1)
            if (i < cfg_lane_en)
                int_predet_lanes[i] = 1'b1;

        Get_predet_lane_mask = int_predet_lanes;
    end
// leda FM_2_35 on
endfunction

// This function picks up a lane which equals to cfg_lane_under_test into a mask with one bit per lane.
// Example: if NL=8 and cfg_lane_under_test = 4'd2, get_lut = 8'b00000100
function automatic [NL-1:0]   get_lut;
input   [3:0]       cfg_lane_under_test;
// LMD: Use fully assigned variables in function
// LJ: The range of values of the variable i are define by the parameter NL
// leda FM_2_35 off
reg     [NL-1:0]    int_lut;
integer             i;
    begin
        int_lut = {NL{1'b0}};
        for (i = 0; i < NL; i= i+1)
            if (i == cfg_lane_under_test)
                int_lut[i] = 1'b1;

        get_lut = int_lut;
    end
// leda FM_2_35 on
endfunction

always @(posedge core_clk or negedge core_rst_n) begin : latchd_rxeidle_exit_PROC
    integer i;
    if (!core_rst_n)
        latchd_rxeidle_exit  <= #TP 0;
    else if (clear)
        latchd_rxeidle_exit  <= #TP 0;
    else
        for (i = 0; i < NL; i= i+1)
           if (!(ltssm_lanes_active[i] & predet_lanes[i]) | (!phy_mac_rxelecidle[i] & ltssm_lanes_active[i] & predet_lanes[i]))
             latchd_rxeidle_exit[i]  <= #TP 1'b1;
end

//cfg_support_part_lanes_rxei_exit = 1: any lanes receives 8 consecutive TS OS, Polling.Active -> Polling.Config (Rx 8 TS means Rx EI exit on that lane from base spec).
//                                      no any lanes receive 8 consecutive TS OS and any predetermined lanes are still on Rx ElecIdle, Polling.Active -> Polling.Compliance.
//cfg_support_part_lanes_rxei_exit = 0: any lanes receives 8 consecutive TS OS and all predetermined lanes have Rx ElecIdle exit, Polling.Active -> Polling.Config (legacy from Base Spec)
//                                      Else, any predetermined lanes are still on Rx ElecIdle, Polling.Active -> Polling.Compliance (legacy from Base Spec).
wire all_predet_lane_latchd_rxeidle_exit;
assign all_predet_lane_latchd_rxeidle_exit = cfg_support_part_lanes_rxei_exit ? 1'b1 : (&latchd_rxeidle_exit);

wire                any_predet_lane_rxeidle_exit;
assign  any_predet_lane_rxeidle_exit    = |(~phy_mac_rxelecidle & predet_lanes);        // for each lane (bit) not in eidle and its a predetermined lane

reg     [NL-1:0]    phy_mac_rxelecidle_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        phy_mac_rxelecidle_d  <= #TP 0;
    else
        phy_mac_rxelecidle_d  <= #TP phy_mac_rxelecidle;

assign  rxelecidle_fall = phy_mac_rxelecidle_d & ~phy_mac_rxelecidle;

always @(posedge core_clk or negedge core_rst_n) begin : latched_rxeidle_exit_PROC
    integer i;
    if (!core_rst_n)
        latched_rxeidle_exit_detected <= #TP 0;
    else if ( lts_state != S_POLL_ACTIVE )
        latched_rxeidle_exit_detected <= #TP 0;
    else begin
        for (i = 0; i < NL; i= i+1) begin
           if ( rxelecidle_fall[i] )
               latched_rxeidle_exit_detected[i] <= #TP 1;
        end
    end
end // latched_rxeidle_exit_PROC

always @(posedge core_clk or negedge core_rst_n) begin : latched_rxeidle_PROC
    integer i;
    if (!core_rst_n)
        latched_rxeidle <= #TP 0;
    else if ( lts_state != S_POLL_ACTIVE )
        latched_rxeidle <= #TP 0;
    else begin
        for (i = 0; i < NL; i= i+1) begin
           if ( latched_rxeidle_exit_detected[i] )
               latched_rxeidle[i] <= #TP 0;
           else if ( phy_mac_rxelecidle[i] )
               latched_rxeidle[i] <= #TP 1;
        end
    end
end // latched_rxeidle_PROC

assign any_predet_lane_latched_rxeidle = |(latched_rxeidle & ltssm_lanes_active & predet_lanes);


reg                 latched_ts_disable;
reg                 latched_ts_lpbk;
reg                 latched_ts_slv_cmpl_rcv;
reg                 latched_ts_rst;
reg                 latched_ts_scrmb_dis;
reg                 latched_ts_lannum_rev;
reg     [7:0]       latched_ts_lnknum;
reg                 latched_ts_speed_change;
reg                 latched_ts_deemphasis;
reg                 latched_ts_deemphasis_var;
reg                 latched_link_any_8_ts_linknmtx_lanenmtx_rcvd;
wire                any_8_ts_linknmtx_lanenmtx_rcvd;
reg     [1:0]       latched_cmp_data_rate; // [0]gen2 [1]gen3(not used)
reg                 persist_2scrmb_dis_rcvd;
reg                 latched_rcvd_lnkpad;
reg                 latched_rcvd_lanpad;
reg     [3*NL-1:0]  eidle_continuity_cnt;
reg     [NL-1:0]    rcvd_valid_eidle_set;
reg     [NL-1:0]    eidle_cnt_clear;
wire    [2:0]       eidle_cnt_max;

// ------------------------------------------------------------------------------
// counters designed for ltssm
always@(posedge core_clk or negedge core_rst_n) begin : latchd_smlh_lanes_rcving_PROC
    if (!core_rst_n)
        latchd_smlh_lanes_rcving <= #TP 0;
    else if ( int_rxdetect_done )     // all lanes that detected a receiver during detect are considered active
        latchd_smlh_lanes_rcving <= #TP int_rxdetected & ltssm_lanes_active;
    else
        latchd_smlh_lanes_rcving <= #TP smlh_lanes_rcving;
end // latchd_smlh_lanes_rcving_PROC

// we need to detect 8 consecutive TSs on any lanes that are active. Therefore we will have to count the symbols to identify
// the next smlh_ts1_rcvd or smlh_Rcvd_ts2 pulse arrived at the correct cycle. If we missed one pusle, we have
// to clear the count and start over again.
//
always@(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        rcvd_ts_auto_change   <= #TP 1'b0;
    else if (clear && (lts_state != S_RCVRY_SPEED))
        rcvd_ts_auto_change   <= #TP 1'b0;
    else if ((lts_state == S_CFG_LANENUM_ACEPT) && link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd)
        rcvd_ts_auto_change   <= #TP 1'b1;
end


// used to determine if TSs were sent during Polling.Active
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ts_sent_in_poll_active  <= #TP 1'b0;
    else if ((next_lts_state == S_POLL_ACTIVE) && (lts_state != S_POLL_ACTIVE) && !clear) // clear on entry to Polling.Active
        ts_sent_in_poll_active  <= #TP 1'b0;
    //else if ((lts_state != S_POLL_ACTIVE) && (lts_state_d == S_POLL_ACTIVE)) // set on leaving Polling.Active
    else if (lts_state == S_POLL_ACTIVE)
        ts_sent_in_poll_active  <= #TP xmtbyte_ts1_sent | xmtbyte_ts2_sent | ts_sent_in_poll_active;



always@(posedge core_clk or negedge core_rst_n)
begin : LATCH_8IDLE_RCVD
    if (!core_rst_n)
        rcvd_8idles           <= #TP 1'b0;
    else if (clear)
        rcvd_8idles           <= #TP 1'b0;
    else if (rmlh_rcvd_idle[0]) // bit 0: 8 (or more) consecutive idle symbol times received
        rcvd_8idles           <= #TP 1'b1;
end

always@(posedge core_clk or negedge core_rst_n)
begin : LATCH_1IDLE_RCVD
    if (!core_rst_n)
        rcvd_1idle            <= #TP 1'b0;
    else if (clear)
        rcvd_1idle            <= #TP 1'b0;
    else if (rmlh_rcvd_idle[1])   // bit 1: 1 idle symbol time received, spec requires to start the idle sent count after 1 idle has been received
        rcvd_1idle            <= #TP 1'b1;
end

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        idle_sent_cnt           <= #TP 5'b0;
    end else if (!rcvd_1idle | clear)   // spec required to start the count after 1 idle has been received
        idle_sent_cnt           <= #TP 0;
    else if ( ltssm_cxl_enable[0] )
        idle_sent_cnt           <= #TP idle_sent_cnt + (xmtbyte_idle_sent ? 1'b1 : 1'b0);
    else if (xmtbyte_idle_sent)
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        idle_sent_cnt           <= #TP idle_sent_cnt + active_nb ;
// spyglass enable_block W164a

assign  ts_to_poll_cmp_pulse = 1'b0;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_ts_nfts         <= #TP 8'b0;
    else if ( link_any_1_ts_rcvd & ((lts_state == S_CFG_COMPLETE) | (lts_state == S_RCVRY_RCVRCFG)))
        // latched the nfts during the cfg completion state for L0s state
        //
        latched_ts_nfts     <= #TP link_ts_nfts ;

wire [4:0] int_ts_data_rate;
assign int_ts_data_rate = 0;
always @( * ) begin
    latched_ts_data_rate = 0;
    latched_ts_data_rate = int_ts_data_rate;
end



always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        rcvry_to_lpbk       <= #TP 1'b0;
    else if (lts_state == S_DETECT_QUIET)
        rcvry_to_lpbk       <= #TP 1'b0;
    else if ( (last_lts_state == S_RCVRY_IDLE) && (lts_state == S_LPBK_ENTRY) )
        rcvry_to_lpbk       <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        lts_state_d         <= #TP S_DETECT_QUIET;
    else
        lts_state_d         <= #TP lts_state;



always @( posedge core_clk or negedge core_rst_n ) begin : latched_flip_ctrl_PROC
    if ( ~core_rst_n )
        latched_flip_ctrl <= #TP 0;
    else if ( lts_state == S_DETECT_QUIET )
        latched_flip_ctrl <= #TP 0;
    else if ( smlh_link_up_rising_edge && ~lpbk_state ) // except the implementation-specific linkup = 1 in Loopback.Active state for loopback master
        latched_flip_ctrl <= #TP int_smlh_lane_flip_ctrl;
end // latched_flip_ctrl_PROC

always@(posedge core_clk or negedge core_rst_n)
begin : IDLE_TO_RLOCK
    if (!core_rst_n)
        idle_to_rlock           <= #TP 0;
    else if ( (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE) && (next_lts_state == S_RCVRY_LOCK) && timeout_2ms && !clear ) begin
        if ( (current_data_rate ==  `GEN1_RATE && lts_state == S_CFG_IDLE)
 )
            idle_to_rlock           <= #TP 8'hff; //set to ffh if not gen3
    end else if ( //reset to 0 if gen3
                  (lts_state == S_DETECT_QUIET) || (rmlh_pkt_start && (lts_state == S_L0)) )
        idle_to_rlock         <= #TP 0;
end

// Determine when to change link speed
reg [2:0] next_data_rate; //extend to 3 bits, 0-gen1, 1-gen2, 2-gen3, 3-gen4, 4-gen5

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        next_data_rate          <= #TP 0;
    else
        next_data_rate          <= #TP 0; //!CX_GEN3_SPEED & !CX_GEN2_SPEED, the 3 bits would be blown away if gen1

reg [2:0] mac_phy_rate1, mac_phy_rate2, mac_phy_rate3, mac_phy_rate4;

wire [NL-1:0]     int_xmtbyte_txelecidle;
assign int_xmtbyte_txelecidle = xmtbyte_txelecidle;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        mac_phy_rate            <= #TP 0;
        mac_phy_rate1           <= #TP 0;
        mac_phy_rate2           <= #TP 0;
        mac_phy_rate3           <= #TP 0;
        mac_phy_rate4           <= #TP 0;
//        mac_phy_rate_d          <= #TP 0;
    end
    else begin
      if (  (ltssm_cmd == `XMT_IN_EIDLE) && &int_xmtbyte_txelecidle   // must be in electrical idle to change rate

                && (   (lts_state == S_PRE_DETECT_QUIET)
                    || (lts_state == S_LPBK_ENTRY)
                    || (latched_eidle_seen &&   (lts_state == S_RCVRY_SPEED))
                    || (curnt_compliance_state == S_COMPL_ENT_SPEED_CHANGE)
                    || (curnt_compliance_state == S_COMPL_EXIT_SPEED_CHANGE) )) begin
        if ( lts_state == S_PRE_DETECT_QUIET ) // prevent mac_phy_rate1 changes without phystatus back when timeout_48ms in S_RCVRY_SPEED to S_PRE_DETECT_QUIET
          mac_phy_rate1          <= #TP 0; // always change to Gen1 rate when in S_PRE_DETECT_QUIET
        else
          mac_phy_rate1          <= #TP next_data_rate;
      end
      mac_phy_rate2          <= #TP mac_phy_rate1;
      mac_phy_rate3          <= #TP mac_phy_rate2;
      mac_phy_rate4          <= #TP (|eiexit_hs_in_progress) ? mac_phy_rate4 : mac_phy_rate3; //must not be in process of rxstandby handshake for ei exit
      mac_phy_rate           <= #TP mac_phy_rate4;
//      mac_phy_rate_d         <= #TP mac_phy_rate;
    end

// latch the link speed on entering detect
reg [2:0] latched_detect_speed;   // The speed on entering Detect
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latched_detect_speed    <= #TP 0;
    end else if ( app_ltssm_enable_fall_edge || ((next_lts_state == S_PRE_DETECT_QUIET) & (lts_state != S_PRE_DETECT_QUIET) & !clear)
             || (!clear & (next_lts_state == S_DETECT_QUIET) & ((lts_state != S_PRE_DETECT_QUIET) && (lts_state != S_DETECT_QUIET))) ) begin
        latched_detect_speed    <= #TP current_data_rate;
    end


reg rate_change_flag;
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        rate_change_flag <= #TP 0;
    else if ( mac_phy_rate2 != mac_phy_rate3 )
        rate_change_flag <= #TP 1;
    else if ( mac_phy_rate2 == current_data_rate )
        rate_change_flag <= #TP 0;

wire [NL-1:0] int_rcvd_eidle_rxstandby;

always @(*) begin : smlh_rcvd_eidle_rxstandby_PROC
    integer n;

    smlh_rcvd_eidle_rxstandby = act_rmlh_rcvd_eidle_set;


end // smlh_rcvd_eidle_rxstandby_PROC

assign int_rcvd_eidle_rxstandby = laneflip_rcvd_eidle_rxstandby;
assign int_lanes_active_rxstandby = laneflip_lanes_active;

reg     [NL-1:0]    eios_subsequent_flag;
reg     [NL-1:0]    eios_l1_l2_flag;
reg     [5:0]       eios_subsequent_timer[0:NL-1];

parameter SUBSEQ_TIMEOUT = 12 / `CX_PL_FREQ_MULTIPLIER;

always @(posedge core_clk or negedge core_rst_n) begin : eios_subsequent_flag_PROC
    integer n;

    if ( !core_rst_n ) begin
        eios_subsequent_flag <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if( int_rcvd_eidle_rxstandby[n] ) begin
                eios_subsequent_flag[n] <= #TP 1;
            end else if(eios_subsequent_timer[n] >= SUBSEQ_TIMEOUT) begin
                eios_subsequent_flag[n] <= #TP 0;
            end
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : eios_subsequent_timer_PROC
    integer n;

    if ( !core_rst_n ) begin
        for ( n=0; n<NL; n=n+1 ) begin
            eios_subsequent_timer[n] <= #TP 0;
        end
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( int_rcvd_eidle_rxstandby[n] ) begin
                eios_subsequent_timer[n] <= #TP 0;
            end else if ( eios_subsequent_flag[n] ) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
                eios_subsequent_timer[n] <= #TP eios_subsequent_timer[n] + (timer2? timer_freq_multiplier : 1'b0);
// spyglass enable_block W164a
            end else begin
                eios_subsequent_timer[n] <= #TP 0;
            end
        end
    end
end

// Once EIOS is received during L1/L2/Disable entry negotiation, the core keeps asserting rxstandby until Recovery State entry or Detect State when cfg_rxstandby_control[3] and [0]=1
always @(posedge core_clk or negedge core_rst_n) begin : eios_l1_l2_flag_PROC
    integer n;

    if ( !core_rst_n ) begin
        eios_l1_l2_flag <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if( (lts_state != S_L123_SEND_EIDLE) && (lts_state != S_L1_IDLE) && (lts_state != S_L2_IDLE) && 
                (lts_state != S_DISABLED_ENTRY) && (lts_state != S_DISABLED_IDLE) && (lts_state != S_DISABLED) ) begin
                eios_l1_l2_flag[n] <= #TP 0;
            end else if( int_rcvd_eidle_rxstandby[n] ) begin
                eios_l1_l2_flag[n] <= #TP 1;
            end
        end
    end
end

wire [5:0] rxstandby_assertion_enable = cfg_rxstandby_control[5:0];
wire rxstandby_handshake_enable = cfg_rxstandby_control[6];

reg     [NL-1:0]    set_rxstandby;

always @(*) begin : set_rxstandby_PROC
    integer n;

    for ( n=0; n<NL; n=n+1 ) begin
        if ( rxstandby_assertion_enable[0] && (int_rcvd_eidle_rxstandby[n] || eios_subsequent_flag[n]) ||
             rxstandby_assertion_enable[1] && rate_change_flag ||
             rxstandby_assertion_enable[2] && ( !clear && lts_state == S_CFG_IDLE && next_lts_state != S_CFG_IDLE && !int_lanes_active_rxstandby[n] ) ||
             rxstandby_assertion_enable[2] && laneflip_pipe_turnoff[n] ||
             rxstandby_assertion_enable[3] && ( next_ltssm_powerdown == `P1 || next_ltssm_powerdown == `P2 || current_powerdown == `P1 || current_powerdown == `P2 ) ||
             rxstandby_assertion_enable[0] && rxstandby_assertion_enable[3] && eios_l1_l2_flag[n] ||
             rxstandby_assertion_enable[4] && ( r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE ) ||
             rxstandby_assertion_enable[5] && ( !clear && lts_state == S_L0 && next_lts_state == S_RCVRY_LOCK && latched_eidle_inferred )
        ) begin
            set_rxstandby[n] = 1'b1;
        end else begin
            set_rxstandby[n] = 1'b0;
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : eiexit_hs_in_progress_PROC
    integer n;

    if ( !core_rst_n ) begin
        eiexit_hs_in_progress <= #TP {NL{1'b0}};
    end else begin
      for ( n=0; n<NL; n=n+1 ) begin
        if ( !cfg_rxstandby_handshake_policy && cfg_rxstandby_control[6] && phy_mac_rxstandbystatus[n] && (!mac_phy_rxstandby[n] || !set_rxstandby[n] && !phy_mac_rxelecidle_noflip[n] ) ) begin
            eiexit_hs_in_progress[n] <= #TP 1'b1;
        end else begin
            eiexit_hs_in_progress[n] <= #TP 1'b0;
        end
      end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_rxstandby_PROC
    integer n;

    if ( !core_rst_n ) begin
        mac_phy_rxstandby <= #TP {NL{`CX_RXSTANDBY_DEFAULT}};
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( set_rxstandby[n] ) begin
                mac_phy_rxstandby[n] <= #TP (rxstandby_handshake_enable && phy_mac_rxstandbystatus[n]) ? mac_phy_rxstandby[n] : 1'b1;
            end else if ( ~phy_mac_rxelecidle_noflip[n] ) begin
                mac_phy_rxstandby[n] <= #TP (rxstandby_handshake_enable && !phy_mac_rxstandbystatus[n]) ? mac_phy_rxstandby[n] : 0;
            end else begin
                mac_phy_rxstandby[n] <= #TP mac_phy_rxstandby[n];
            end
        end
    end
end


// Gen3 Compliance signal generation

wire                retrain_pulse;
wire                retrain_complete;               // Indicates that the link finished retraining
reg                 latched_link_retrain;
reg                 latched_rec_cfg_to_l0;

wire                perform_link_retrain;

always @(posedge core_clk or negedge core_rst_n) begin : latched_link_retrain_bit_PROC
    if ( ~core_rst_n ) begin
        latched_link_retrain_bit <= #TP 0;
    end else if (perform_link_retrain) begin // a pulse to clear latched_link_retrain_bit and latched_perform_eq at the transition from (L0 || L1_IDLE) -> S_RCVRY_LOCK after cfg_link_retrain setting
        latched_link_retrain_bit  <= #TP 1'b0;
    end else if (!latched_link_retrain_bit && retrain_pulse) begin     // capture Retrain Link / Target Link Speed / Perform Equalization at the rising edge of cfg_link_retrain
        latched_link_retrain_bit  <= #TP 1'b1;
    end else begin                        // hold current value
        latched_link_retrain_bit  <= #TP latched_link_retrain_bit;
    end
end //latched_link_retrain_bit_PROC

// after link_retrain bit has been set and LTSSM moves from (L0 || L1_IDLE) -> S_RCVRY_LOCK, generate a pulse
assign perform_link_retrain = latched_link_retrain_bit && (next_lts_state == S_RCVRY_LOCK) && ((lts_state == S_L0) || (lts_state == S_L1_IDLE) || (lts_state == S_L0S)) && !clear && ~cfg_upstream_port; // adding "&& ~cfg_upstream_port" for CC




//Do not clear the ltssm_ts_auto_change in lts_state_d == S_CFG_COMPLETE. delay one cycle to S_CFG_COMPLETE so that the controller sends upconfigure in its last TX TS2 in S_CFG_IDLE.
//it is safe to do so because no TS send command in S_CFG_IDLE which follows S_CFG_COMPLETE.
//Do not clear the ltssm_ts_auto_change in S_RCVRY_IDLE with no_idle_need_sent. it is safe to do so because no_idle_need_sent is inside S_RCVRY_IDLE if ltssm_ts_auto_change needs to be sent.
//do not clear ltssm_ts_auto_change during (lts_state_d == S_RCVRY_RCVRCFG && lts_state == S_RCVRY_IDLE) because TxDataValid may be one cycle 0 at the entry to S_RCVRY_IDLE causing TS2 sent delay 1 cycle
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ltssm_ts_auto_change    <= #TP 1'b0;
    else if ( lts_state == S_POLL_ACTIVE ) // initial deemphasis setting
        ltssm_ts_auto_change    <= #TP 1'b0 ;
    else if ( lts_state == S_CFG_COMPLETE && clear ) // Link upconfig support
        ltssm_ts_auto_change    <= #TP cfg_upconfigure_support;
    else if ( lts_state == S_CFG_LINKWD_START && clear ) // used for auto change
        ltssm_ts_auto_change    <= #TP (cfg_upstream_port && (last_lts_state == S_RCVRY_IDLE)) ? directed_link_width_change_updown : 1'b0;
//    else if ( !cfg_upstream_port && (next_lts_state == S_RCVRY_LOCK) && !clear )      // used for deemphasis
//        ltssm_ts_auto_change    <= #TP cfg_sel_de_emphasis;
    else if ( (cfg_upstream_port && (lts_state == S_RCVRY_LOCK)) ||       // used for deemphasis
              (!cfg_upstream_port && clear && (lts_state == S_RCVRY_RCVRCFG)) ) // used for deemphasis. if cfg_selectable_deemph_bit_mux = 1, the value requested by USP. Else, the Selectable De-emphasis field in the Link Control 2 register
        ltssm_ts_auto_change    <= #TP cfg_upstream_port ? ( 1'b0) : ( 1'b0) ;
//    else if ( !cfg_upstream_port && (lts_state != S_RCVRY_RCVRCFG) && !clear && (next_lts_state == S_RCVRY_RCVRCFG) )  // used for deemphasis
//        ltssm_ts_auto_change    <= #TP `ifdef CX_GEN2_SPEED (ltssm_ts_data_rate[1] == 1'b1) ? cfg_sel_de_emphasis : `endif 1'b0;
    else if ( cfg_upstream_port && clear && (lts_state == S_RCVRY_RCVRCFG) ) // used for auto change
        ltssm_ts_auto_change    <= #TP directed_link_width_change_updown | 1'b0;
    else if ( cfg_upstream_port && (lts_state == S_LPBK_ENTRY) && cfg_lpbk_en && last_lts_state == S_RCVRY_IDLE )  // used for deemphasis with lpbk master
        ltssm_ts_auto_change    <= #TP 1'b0 ;
    else if ( /*cfg_upstream_port &&*/ clear && (lts_state == S_LPBK_ENTRY) && cfg_lpbk_en )  // used for deemphasis with lpbk master
        ltssm_ts_auto_change    <= #TP 1'b0 ;
    else if ( ~(lts_state == S_POLL_ACTIVE || lts_state == S_CFG_LINKWD_START || lts_state == S_LPBK_ENTRY || lts_state == S_POLL_CONFIG || lts_state == S_CFG_COMPLETE || lts_state_d == S_CFG_COMPLETE || (lts_state == S_RCVRY_IDLE && no_idle_need_sent) ||
                lts_state == S_RCVRY_RCVRCFG || (lts_state_d == S_RCVRY_RCVRCFG && lts_state == S_RCVRY_IDLE) || (cfg_upstream_port && (lts_state == S_CFG_LINKWD_ACEPT || lts_state == S_CFG_LANENUM_WAIT || lts_state == S_CFG_LANENUM_ACEPT || lts_state == S_RCVRY_LOCK))) )
        ltssm_ts_auto_change    <= #TP 0;

// generate ltssm_ts_data_rate from next_lts_state = S_RCVRY_RCVRCFG for ltssm_cmd_8geqts os that ltssm_cmd_8geqts is read when entry to S_RCVRY_RCVRCFG state
always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_ts_data_rate_int_PROC
    if ( ~core_rst_n )
        ltssm_ts_data_rate_int <= #TP 5'b00001;
    else
        ltssm_ts_data_rate_int <= #TP ltssm_ts_data_rate;
end // ltssm_ts_data_rate_int_PROC

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ltssm_ts_data_rate      <= #TP 5'b00001;
    else
        ltssm_ts_data_rate      <= #TP ltssm_ts_data_rate;


// -------------------------------------------------------------------------
// Link Width Change Logic
assign go_recovery_link_width_change = (cfg_directed_link_width_change || hw_autowidth_dis_upconf ) && (rdlh_dlcntrl_state ==  `S_DL_ACTIVE);

assign int_target_link_width_legal = (cfg_hw_autowidth_dis || !upconfigure_capable) ? 6'b00_0000 : // if latched_target_link_width is 0, just go through config state without initiating width change
                                     ( cfg_target_link_width==6'b10_0000 ||
                                       cfg_target_link_width==6'b01_0000 ||
                                       cfg_target_link_width==6'b00_1000 ||
                                       cfg_target_link_width==6'b00_0100 ||
                                       cfg_target_link_width==6'b00_0010 ||
                                       cfg_target_link_width==6'b00_0001 )          ? cfg_target_link_width :
                                                                                      6'b00_0000;

assign int_target_link_width_real = ((int_target_link_width_legal > linkup_link_mode) || hw_autowidth_dis_upconf) ? linkup_link_mode : int_target_link_width_legal;

always@(posedge core_clk or negedge core_rst_n)
begin : directed_link_width_change_PROC
    if (!core_rst_n) begin
        directed_link_width_change <= #TP 1'b0;
        latched_target_link_width  <= #TP 6'h0;
    end else if ( ((lts_state == S_L0)||(lts_state == S_L1_IDLE)) && (next_lts_state == S_RCVRY_LOCK) && !clear && go_recovery_link_width_change ) begin
        directed_link_width_change <= #TP 1'b1;
        latched_target_link_width  <= #TP int_target_link_width_real;
    end else if ( (lts_state == S_CFG_IDLE) && (next_lts_state != S_CFG_IDLE) && !clear ) begin
        directed_link_width_change <= #TP 1'b0;
        latched_target_link_width  <= #TP latched_target_link_width;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : latched_auto_width_downsizing_PROC
    if ( ~core_rst_n )
        latched_auto_width_downsizing <= #TP 0;
    else if ( !smlh_link_up )
        latched_auto_width_downsizing <= #TP 0;
    else
        latched_auto_width_downsizing <= #TP latched_auto_width_downsizing | directed_link_width_change_down;
end

always @(posedge core_clk or negedge core_rst_n) begin : hw_autowidth_dis_d_PROC
    if ( ~core_rst_n )
        hw_autowidth_dis_d <= #TP 0;
    else
        hw_autowidth_dis_d <= #TP cfg_hw_autowidth_dis;
end

assign hw_autowidth_dis_rising_edge = cfg_hw_autowidth_dis & ~hw_autowidth_dis_d;

always @(posedge core_clk or negedge core_rst_n) begin : hw_autowidth_dis_upconf_PROC
    if ( ~core_rst_n )
        hw_autowidth_dis_upconf <= #TP 0;
    else if ( (lts_state != S_L0) && (next_lts_state == S_L0) && !clear && directed_link_width_change_up && (linkup_link_mode==latched_target_link_width) )
        hw_autowidth_dis_upconf <= #TP 0;
    else if ( latched_auto_width_downsizing && hw_autowidth_dis_rising_edge && (linkup_link_mode > smlh_link_mode) )
        hw_autowidth_dis_upconf <= #TP 1;
end

assign target_link_lanes_active = 
                                  latched_target_link_width[2] ? 'h000f :
                                  latched_target_link_width[1] ? 'h0003 :
                                                                 'h0001;

assign remote_lanes_activated = 
                                linkup_link_mode[2] ? (16'h000f & latchd_rxeidle_exit_upconf & link_2_ts1_plinkn_planen_rcvd_upconf) :
                                linkup_link_mode[1] ? (16'h0003 & latchd_rxeidle_exit_upconf & link_2_ts1_plinkn_planen_rcvd_upconf) :
                                                      16'h0000;


always @(posedge core_clk or negedge core_rst_n) begin : directed_link_width_change_d_PROC
    if ( ~core_rst_n ) begin
        directed_link_width_change_d <= #TP 0;
    end else begin
        directed_link_width_change_d <= #TP directed_link_width_change;
    end
end

assign smlh_dir_linkw_chg_rising_edge = directed_link_width_change & ~directed_link_width_change_d ;

assign directed_link_width_change_updown = directed_link_width_change_up | directed_link_width_change_down;
assign directed_link_width_change_up     = directed_link_width_change & (latched_target_link_width != 0) & (latched_target_link_width > latest_link_mode);
assign directed_link_width_change_down   = directed_link_width_change & (latched_target_link_width != 0) & (latched_target_link_width < latest_link_mode);
assign directed_link_width_change_nochg  = directed_link_width_change & !directed_link_width_change_updown;

always@(posedge core_clk or negedge core_rst_n)
begin : cfglwstart_upconf_dsp_PROC
    if (!core_rst_n) begin
        cfglwstart_upconf_dsp <= #TP 1'b0;
    end else if ( (lts_state != S_CFG_LINKWD_START) && (next_lts_state == S_CFG_LINKWD_START) && !clear ) begin
        if(directed_link_width_change_up && !cfg_upstream_port)
            cfglwstart_upconf_dsp <= #TP 1'b1;
        else
            cfglwstart_upconf_dsp <= #TP 1'b0;
    end else if ( (lts_state == S_CFG_LINKWD_START) && (timeout_1ms || link_latched_live_all_2_ts1_plinkn_planen_rcvd && !clear) ) begin
        cfglwstart_upconf_dsp <= #TP 1'b0;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : latchd_rxeidle_exit_upconf_PROC
    integer i;
    if (!core_rst_n)
        latchd_rxeidle_exit_upconf <= #TP 0;
    else if ( (next_lts_state == S_RCVRY_LOCK) && ((lts_state == S_L0)||(lts_state == S_L1_IDLE)) && !clear )
        latchd_rxeidle_exit_upconf <= #TP 0;
    else
        for (i = 0; i < NL; i= i+1)
           if (!phy_mac_rxelecidle[i])
             latchd_rxeidle_exit_upconf[i] <= #TP 1'b1;
end

always @(posedge core_clk or negedge core_rst_n) begin : upconfigure_capable_PROC
    if (!core_rst_n)
        upconfigure_capable <= #TP 0;
    else if(lts_state == S_DETECT_QUIET)
        upconfigure_capable <= #TP 0;
    else if((lts_state == S_CFG_COMPLETE) && ~clear && link_ln0_8_ts2_linknmtx_lanenmtx_rcvd)
        upconfigure_capable <= #TP link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd & ltssm_ts_auto_change; // rx and tx
end

assign link_mode_activated_pulse = !clear &&
                                   ( lts_state == S_CFG_LINKWD_START && !directed_link_width_change_updown && ltssm_lanes_activated_pulse ) &&
                                   ( 
                                     smlh_link_mode[1] && (&ltssm_lanes_active[3:2]) ||
                                     smlh_link_mode[0] && (ltssm_lanes_active[1]) ||
                                     1'b0);

// End of Link Width Change Logic
// -------------------------------------------------------------------------



always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        persist_2scrmb_dis_rcvd <= #TP 1'b0;
    else if ( lts_state == S_DETECT_ACT ) //scrambler enabled for gen3 rate
        persist_2scrmb_dis_rcvd <= #TP 1'b0;
    else if ( ((lts_state == S_CFG_COMPLETE) & ((link_latched_live_all_ts_scrmb_dis) | cfg_scrmb_dis))
        & ( (current_data_rate == `GEN1_RATE) || (current_data_rate == `GEN2_RATE) ))
        // latched the scrambler disable during the cfg completion state
        // to disable the scrambler of this lane
        persist_2scrmb_dis_rcvd       <= #TP 1'b1;

// This counts the cycles between rmlh_rcvd_eidle_set pulses and clears the count if the eidles weren't contiguous as required by the spec
// Its also used to protect from counting too many Eidles because of lane skew
/*
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        eidle_continuity_cnt    <= #TP 3'b0;
    else if (clear || rcvd_valid_eidle_set || (eidle_continuity_cnt == 3'b0))  // Clear the count when we change states or an EIDLE OS is received
        eidle_continuity_cnt    <= #TP active_nb[0] ? 3'd3 : 3'd1;
    else if (rcvd_eidle_cnt > 3'b0)
        eidle_continuity_cnt    <= #TP eidle_continuity_cnt - 3'b1;
*/
always@(posedge core_clk or negedge core_rst_n) begin : EIDLE_CONTINUITY_CNT
  if (!core_rst_n) begin
    eidle_continuity_cnt <= #TP 0;
  end else begin
      if (clear || rcvd_valid_eidle_set[0] || (eidle_continuity_cnt[2:0] == 3'b0))
        eidle_continuity_cnt[2:0] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[3:0] > 4'b0)
        eidle_continuity_cnt[2:0] <= #TP eidle_continuity_cnt[2:0] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[1] || (eidle_continuity_cnt[5:3] == 3'b0))
        eidle_continuity_cnt[5:3] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[7:4] > 4'b0)
        eidle_continuity_cnt[5:3] <= #TP eidle_continuity_cnt[5:3] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[2] || (eidle_continuity_cnt[8:6] == 3'b0))
        eidle_continuity_cnt[8:6] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[11:8] > 4'b0)
        eidle_continuity_cnt[8:6] <= #TP eidle_continuity_cnt[8:6] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[3] || (eidle_continuity_cnt[11:9] == 3'b0))
        eidle_continuity_cnt[11:9] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[15:12] > 4'b0)
        eidle_continuity_cnt[11:9] <= #TP eidle_continuity_cnt[11:9] - 3'b1;


  end
end

//get rcvd_valid_eidle_set based on per lane
always @( act_rmlh_rcvd_eidle_set or rcvd_eidle_cnt or eidle_continuity_cnt or active_nb ) begin : EIDLE_VALID
  rcvd_valid_eidle_set = 0;
    rcvd_valid_eidle_set[0] = act_rmlh_rcvd_eidle_set[0] && ( (rcvd_eidle_cnt[3:0] == 0)
                                 || (eidle_continuity_cnt[2:0] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[1] = act_rmlh_rcvd_eidle_set[1] && ( (rcvd_eidle_cnt[7:4] == 0)
                                 || (eidle_continuity_cnt[5:3] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[2] = act_rmlh_rcvd_eidle_set[2] && ( (rcvd_eidle_cnt[11:8] == 0)
                                 || (eidle_continuity_cnt[8:6] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[3] = act_rmlh_rcvd_eidle_set[3] && ( (rcvd_eidle_cnt[15:12] == 0)
                                 || (eidle_continuity_cnt[11:9] == 0) || active_nb[2] );


end

//assign  rcvd_valid_eidle_set = rmlh_rcvd_eidle_set && ( (rcvd_eidle_cnt == 0)
//                                                        || (eidle_continuity_cnt == 0) || active_nb[2]);

// how many cycles it should take between eidle pulses
assign  eidle_cnt_max = active_nb[0] ? 3'd3 : 3'd1;

//assign  eidle_cnt_clear = active_nb[2] ? (|rcvd_eidle_cnt && !rmlh_rcvd_eidle_set) : // if in 4S mode, clear on any interruption of rmlh_rcvd_eidle_set
//                            (eidle_continuity_cnt == 3'd0) && !rmlh_rcvd_eidle_set;

//lane-base eidle_cnt_clear
always @(active_nb or rcvd_eidle_cnt or act_rmlh_rcvd_eidle_set or eidle_continuity_cnt) begin : EIDLE_CNT_CLEAR
  eidle_cnt_clear = 0;

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[0] = active_nb[2] ? (|rcvd_eidle_cnt[3:0] && !act_rmlh_rcvd_eidle_set[0]) :
                            (eidle_continuity_cnt[2:0] == 3'd0) && !act_rmlh_rcvd_eidle_set[0];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[1] = active_nb[2] ? (|rcvd_eidle_cnt[7:4] && !act_rmlh_rcvd_eidle_set[1]) :
                            (eidle_continuity_cnt[5:3] == 3'd0) && !act_rmlh_rcvd_eidle_set[1];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[2] = active_nb[2] ? (|rcvd_eidle_cnt[11:8] && !act_rmlh_rcvd_eidle_set[2]) :
                            (eidle_continuity_cnt[8:6] == 3'd0) && !act_rmlh_rcvd_eidle_set[2];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[3] = active_nb[2] ? (|rcvd_eidle_cnt[15:12] && !act_rmlh_rcvd_eidle_set[3]) :
                            (eidle_continuity_cnt[11:9] == 3'd0) && !act_rmlh_rcvd_eidle_set[3];


end


// Count the number of electrical idle ordered sets.
// Stop the counter at 8
// changed to 4 (code coverage) because we only need max 4 EIOSs in Rx and move to next state
always@(posedge core_clk or negedge core_rst_n) begin : EIDLE_CNT
  if (!core_rst_n) begin
    rcvd_eidle_cnt <= #TP 0;
  end else begin
      if (clear || eidle_cnt_clear[0])
        rcvd_eidle_cnt[3:0] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[3:0]>=4)
        rcvd_eidle_cnt[3:0] <= #TP rcvd_eidle_cnt[3:0];
      else if (rcvd_valid_eidle_set[0])
        rcvd_eidle_cnt[3:0] <= #TP rcvd_eidle_cnt[3:0] + 1'b1;

      if (clear || eidle_cnt_clear[1])
        rcvd_eidle_cnt[7:4] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[7:4]>=4)
        rcvd_eidle_cnt[7:4] <= #TP rcvd_eidle_cnt[7:4];
      else if (rcvd_valid_eidle_set[1])
        rcvd_eidle_cnt[7:4] <= #TP rcvd_eidle_cnt[7:4] + 1'b1;

      if (clear || eidle_cnt_clear[2])
        rcvd_eidle_cnt[11:8] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[11:8]>=4)
        rcvd_eidle_cnt[11:8] <= #TP rcvd_eidle_cnt[11:8];
      else if (rcvd_valid_eidle_set[2])
        rcvd_eidle_cnt[11:8] <= #TP rcvd_eidle_cnt[11:8] + 1'b1;

      if (clear || eidle_cnt_clear[3])
        rcvd_eidle_cnt[15:12] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[15:12]>=4)
        rcvd_eidle_cnt[15:12] <= #TP rcvd_eidle_cnt[15:12];
      else if (rcvd_valid_eidle_set[3])
        rcvd_eidle_cnt[15:12] <= #TP rcvd_eidle_cnt[15:12] + 1'b1;


  end
end

always@(posedge core_clk or negedge core_rst_n) begin : RCVD_4EIDLE
    if (!core_rst_n)
        rcvd_4eidle <= #TP 1'b0;
    else if (clear)
        rcvd_4eidle <= #TP 1'b0;
    else begin
        begin //for gen1/2 rate
            for (j=0; j<NL; j=j+1) begin
                //Gen3 Spec: EIOS has 4 symbols for 5GT/s as well
                if ( (current_data_rate == `GEN2_RATE || current_data_rate == `GEN1_RATE) && rcvd_eidle_cnt[4*j+2] ) begin
                    rcvd_4eidle <= #TP 1'b1;
                end
            end //for
        end //else begin //for gen1/2 rate
    end
end

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_rcvd_eidle_set  <= #TP 1'b0;
    else if (rmlh_rcvd_eidle_set)
        latched_rcvd_eidle_set  <= #TP 1'b1;
    else if (clear & (lts_state != S_DISABLED_IDLE) & (lts_state != S_L123_SEND_EIDLE))
        latched_rcvd_eidle_set  <= #TP 1'b0;

assign  smlh_scrambler_disable = persist_2scrmb_dis_rcvd;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_eidle_sent  <= #TP 1'b0;
    else if (clear | (curnt_compliance_state == S_COMPL_TX_COMPLIANCE))
        latched_eidle_sent  <= #TP 1'b0;
    else if (xmtbyte_eidle_sent)
        latched_eidle_sent  <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n) begin : int_latched_smlh_inskip_rcv_PROC
    integer ii;

    if (!core_rst_n)
        int_latched_smlh_inskip_rcv <= #TP 0;
    else if ( clear || ((current_data_rate == `GEN3_RATE) || (current_data_rate == `GEN4_RATE) || (current_data_rate == `GEN5_RATE)) || (r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY) || (r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE) )
        int_latched_smlh_inskip_rcv <= #TP 0;
    else begin
        for ( ii=0; ii<NL; ii=ii+1 ) begin
            if (smlh_inskip_rcv[ii])
                int_latched_smlh_inskip_rcv[ii]  <= #TP 1'b1;
        end //for
    end
end //int_latched_smlh_inskip_rcv_PROC

always @( * ) begin : latched_smlh_inskip_rcv_PROC
    latched_smlh_inskip_rcv = &(~ltssm_lanes_active | int_latched_smlh_inskip_rcv); //all lanes receive skip os.
end // latched_smlh_inskip_rcv_PROC



always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        idle_16_sent        <= #TP 1'b0;
    else if (clear)
        idle_16_sent        <= #TP 1'b0;
    else if ( ltssm_cxl_enable[0] && idle_sent_cnt[3] ) // 8 flits sent after receiving 1
        idle_16_sent        <= #TP 1'b1;
    else if (idle_sent_cnt[4])
        idle_16_sent        <= #TP 1'b1;

// -------------------------------------------------------------------------
// For reset, disable and loopback, PCI Express spec. required to receive
// two continous ts1 or ts2 with control bits set in order for both device
// on the link to decide the actions
reg                 clked_cfg_reset_assert;
reg                 clked_cfg_link_dis;
reg                 clked_cfg_lpbk_en;
reg                 clked_app_init_rst;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        clked_cfg_reset_assert <= #TP 0;
        lpbk_master            <= #TP 0;
        clked_cfg_link_dis     <= #TP 0;
        clked_cfg_lpbk_en      <= #TP 0;
        clked_app_init_rst     <= #TP 0;
    end else begin
        lpbk_master            <= #TP (cfg_lpbk_en & (lts_state != S_LPBK_ENTRY) & (next_lts_state == S_LPBK_ENTRY) & !clear) ? 1'b1
                                       : (lts_state == S_LPBK_EXIT_TIMEOUT) ? 1'b0 : lpbk_master;
        clked_cfg_reset_assert <= #TP cfg_reset_assert | clked_app_init_rst;
        clked_cfg_link_dis     <= #TP cfg_link_dis;
        clked_cfg_lpbk_en      <= #TP cfg_lpbk_en;
        clked_app_init_rst     <= #TP app_init_rst;
    end

reg latched_cfg_link_dis;
always @* begin : latched_cfg_link_dis_PROC
    latched_cfg_link_dis = 1'b0;

    latched_cfg_link_dis = cfg_link_dis;
end // latched_cfg_link_dis_PROC

wire                direct_rst;
    assign  direct_rst = (clked_app_init_rst | cfg_reset_assert) & !cfg_upstream_port;

wire up_rst_deassert;
assign up_rst_deassert       = !(cfg_reset_assert | clked_app_init_rst) & clked_cfg_reset_assert;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latched_direct_rst          <= #TP 0;
        direct_rst_d                <= #TP 0;
        gointo_rcovr_state_d        <= #TP 0;
    end else begin
        direct_rst_d                <= #TP direct_rst;
        if (direct_rst & !direct_rst_d & smlh_link_up)
            latched_direct_rst      <= #TP 1'b1;
        else if (!direct_rst && (lts_state == S_HOT_RESET_ENTRY || lts_state == S_HOT_RESET))
            latched_direct_rst      <= #TP 1'b0;

        gointo_rcovr_state_d        <= #TP cfg_link_retrain;
    end

assign  retrain_pulse               = !gointo_rcovr_state_d & cfg_link_retrain;

assign  retrain_complete            = latched_link_retrain & (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE) & (next_lts_state == S_L0) & !clear;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_link_retrain        <= #TP 1'b0;
    else
        if (retrain_complete || ~latched_rec_cfg_to_l0) // clear on retrain complete
            latched_link_retrain    <= #TP 1'b0;
        else if (retrain_pulse)                         // capture the retrain pulse
            latched_link_retrain    <= #TP 1'b1;
        else                                            // hold current value
            latched_link_retrain    <= #TP latched_link_retrain;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_rec_cfg_to_l0 <= #TP 1'b0;
    else
        if ((lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE) & (next_lts_state == S_L0) & !clear) // capture the transition to L0 from Recovery or Configuration
            latched_rec_cfg_to_l0 <= #TP 1'b1;
        else if (lts_state==S_DETECT_QUIET) // clear by linkdown
            latched_rec_cfg_to_l0 <= #TP 1'b0;
        else                                // hold current value
            latched_rec_cfg_to_l0 <= #TP latched_rec_cfg_to_l0;


reg                 latched_rec_to_cfg;  // Indicates that this Configuration State is from Recovery State
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_rec_to_cfg <= #TP 0;
    else if( (lts_state_d == S_RCVRY_IDLE || lts_state_d == S_RCVRY_LOCK || lts_state_d == S_RCVRY_RCVRCFG) & (lts_state == S_CFG_LINKWD_START) )
        latched_rec_to_cfg <= #TP 1'b1;
    else if( lts_state == S_CFG_LINKWD_START || lts_state == S_CFG_LINKWD_ACEPT || lts_state == S_CFG_LANENUM_WAIT || lts_state == S_CFG_LANENUM_ACEPT || lts_state == S_CFG_COMPLETE )
        latched_rec_to_cfg <= #TP latched_rec_to_cfg;
    else
        latched_rec_to_cfg <= #TP 0;

always @(posedge core_clk or negedge core_rst_n) begin : current_data_rate_d_PROC
    if ( ~core_rst_n )
        current_data_rate_d <= #TP 0;
    else
        current_data_rate_d <= #TP current_data_rate;
end //always

always @(posedge core_clk or negedge core_rst_n) begin : latched_rate_change_PROC
    if ( ~core_rst_n )
        latched_rate_change <= #TP 0;
    else if(clear)
        latched_rate_change <= #TP 0;
    else if(current_data_rate_d != current_data_rate)
        latched_rate_change <= #TP 1'b1;
end //always



// This is to take care of the different change timing of ltssm and data rate.
assign latched_rate_change_or = latched_rate_change || (current_data_rate_d != current_data_rate);

// pulse
assign  smlh_bw_mgt_status          = (  (retrain_complete && !cfg_upstream_port)
                                      || ( latched_rec_to_cfg && (lts_state_d != S_CFG_COMPLETE) && (lts_state == S_CFG_COMPLETE) && (smlh_link_mode != latest_link_mode) &&
                                           !rcvd_ts_auto_change && !directed_link_width_change_updown )
                                    );

assign  smlh_link_auto_bw_status    = ( 1'b0
                                      || ( latched_rec_to_cfg && (lts_state_d != S_CFG_COMPLETE) && (lts_state == S_CFG_COMPLETE) && (smlh_link_mode != latest_link_mode) &&
                                           ( rcvd_ts_auto_change || // autonomous link width change by remote port
                                             directed_link_width_change_updown ) ) // autonomous link width change by my port
                                    );



   assign  directed_recovery = latched_direct_rst | latched_link_retrain_bit | (!clked_cfg_link_dis & cfg_link_dis) | (!clked_cfg_lpbk_en & cfg_lpbk_en);

    // latches to control lts_state transition
    // this process decides the link number for port to transmit
    always@(posedge core_clk or negedge core_rst_n)
        if (!core_rst_n)
        xmt_ts_lnknum       <= #TP 8'b0;
        // when ltssm is in link width start state, it supposed to latch the remote site link num
        // only when two consective non pad link number has been received
        else if ((lts_state == S_CFG_LINKWD_START) & cfg_upstream_port & link_any_2_ts1_linkn_planen_rcvd & ~clear)
        xmt_ts_lnknum       <= #TP link_any_2_ts1_link_num;
        else if (!cfg_upstream_port)  // when ltssm supposed to latch its own transmitted link num
        // link number will be latched during the cfg start state
        xmt_ts_lnknum       <= #TP cfg_link_num;




// -------------------------------------------------------------------------
// Beneath is the ltssm main state machine process
// -------------------------------------------------------------------------
//
//Direct the L0 state to recovery state is based on the following
//conditions:
//1. Receiver received TS ordered set while LTSSM is in l0 state
//2. Software wants to start a reset (directed_recovery)
//3. Test and debug function for force lts_state state
//4. when enter electric idle during L0 state, it means that link has problem, we will start link recovery
//5. When received detected skew alignment error while LTSSM's rcvr is in L0 state
//6. When data link layer inigiated a link retraining due to over role of replay timer
//7. When RTLH request link retain because of watch dog timer expired
//
wire                rcvd_2_unexpect_ts;
reg                 latched_rcvd_2_unexpect_ts;
assign rcvd_2_unexpect_ts = link_any_2_ts_rcvd & ~clear;
reg                 l0s_link_rcvry_en;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        l0s_link_rcvry_en     <= #TP 1'b0;
    else
        l0s_link_rcvry_en     <= #TP (rcvd_2_unexpect_ts | xdlh_smlh_start_link_retrain | directed_recovery
                                      | (rmlh_deskew_alignment_err & (r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY)) | rtlh_req_link_retrain);


// Indicate the ltssm is in training
always @( * ) begin : ltssm_in_training_PROC
        ltssm_in_training      = 0;

        ltssm_in_training      = (lts_state == S_CFG_LINKWD_START ) |
                                 (lts_state == S_CFG_LINKWD_ACEPT ) |
                                 (lts_state == S_CFG_LANENUM_WAIT ) |
                                 (lts_state == S_CFG_LANENUM_ACEPT) |
                                 (lts_state == S_CFG_COMPLETE     ) |
                                 (lts_state == S_CFG_IDLE         ) |
                                 (lts_state == S_RCVRY_LOCK       ) |
                                 (lts_state == S_RCVRY_SPEED      ) |
                                 (lts_state == S_RCVRY_EQ0        ) |
                                 (lts_state == S_RCVRY_EQ1        ) |
                                 (lts_state == S_RCVRY_EQ2        ) |
                                 (lts_state == S_RCVRY_EQ3        ) |
                                 (lts_state == S_RCVRY_RCVRCFG    ) |
                                 (lts_state == S_RCVRY_IDLE       );
end // ltssm_in_training_PROC



always @( posedge core_clk or negedge core_rst_n ) begin : latched_rcvd_2_unexpect_ts_PROC
    if ( ~core_rst_n ) begin
        latched_rcvd_2_unexpect_ts <= #TP 0;
    end else if ( ~(lts_state == S_L0 ) ) begin
        latched_rcvd_2_unexpect_ts <= #TP 0;
    end else if ( link_any_exact_2_ts_rcvd && ~clear ) begin
        latched_rcvd_2_unexpect_ts <= #TP 1;
    end
end // latched_rcvd_2_unexpect_ts_PROC

reg l0_link_rcvry_en;
//
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        l0_link_rcvry_en      <= #TP 1'b0;
    else
        l0_link_rcvry_en      <= #TP ( latched_rcvd_2_unexpect_ts | xdlh_smlh_start_link_retrain | directed_recovery | rmlh_deskew_alignment_err
                                     | go_recovery_link_width_change
                                     | rtlh_req_link_retrain | eidle_inferred_recovery);

// no need to send Idle data in Rcvry.Idle if directed to HotReset, Lpbk, Cfg, Disabled state
always @(posedge core_clk or negedge core_rst_n) begin : no_idle_need_sent_PROC
    if (!core_rst_n) begin
        no_idle_need_sent <= #TP 0;
    end else begin
        if ( (lts_state != S_RCVRY_IDLE) && (next_lts_state == S_RCVRY_IDLE) && !clear &&
             (latched_direct_rst || cfg_lpbk_en || cfg_gointo_cfg_state
                                                || directed_link_width_change
                                                || ((!cfg_upstream_port
                                                    ) && cfg_link_dis)) )
            no_idle_need_sent <= #TP 1;
        else if (lts_state == S_RCVRY_IDLE && next_lts_state != S_RCVRY_IDLE && !clear)
            no_idle_need_sent <= #TP 0;
    end
end

assign ltssm_no_idle_need_sent = no_idle_need_sent;

// outputs from state machine
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        ltssm_cmd                   <= #TP `XMT_IN_EIDLE;
        ltssm_xlinknum              <= #TP 0;
        ltssm_xk237_4lnknum         <= #TP {NL{1'b1}};
        ltssm_xk237_4lannum         <= #TP {NL{1'b1}};
        ltssm_eidle_cnt             <= #TP 3'd0;
    end
    else if (cfg_force_en && cfg_forced_ltssm_cmd!=4'h0)
        ltssm_cmd <= #TP cfg_forced_ltssm_cmd;
    else

             case (lts_state)
        S_DETECT_QUIET:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_PRE_DETECT_QUIET:
            if (xmtbyte_eidle_sent | latched_eidle_sent | (ltssm_cmd == `XMT_IN_EIDLE))
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            else
            begin
            ltssm_cmd               <= #TP `SEND_EIDLE;
            ltssm_eidle_cnt         <= #TP (current_data_rate == `GEN2_RATE) ? 3'h1: 3'h0; //1 for gen1/3, 2 for gen2
            end
        S_DETECT_ACT: begin
            if ((current_powerdown == `P1) && !int_rxdetect_done )
                ltssm_cmd           <= #TP `SEND_RCVR_DETECT_SEQ;
            else
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            ltssm_eidle_cnt         <= #TP (current_data_rate == `GEN2_RATE) ? 3'h1: 3'h0;
        end
        S_DETECT_WAIT:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_POLL_ACTIVE: begin
            ltssm_cmd               <= #TP (current_powerdown == `P0) ? `SEND_TS1 : ltssm_cmd;
            ltssm_xk237_4lnknum     <= #TP {NL{1'b1}};
            ltssm_xk237_4lannum     <= #TP {NL{1'b1}};
        end
        S_POLL_COMPLIANCE:
            if (curnt_compliance_state == S_COMPL_IDLE)
                ltssm_cmd           <= #TP ltssm_cmd;
            else if (curnt_compliance_state == S_COMPL_ENT_TX_EIDLE) begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP 3'h1;
            end
            else if (curnt_compliance_state == S_COMPL_ENT_SPEED_CHANGE)
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            else if (curnt_compliance_state == S_COMPL_TX_COMPLIANCE) begin
                ltssm_cmd           <= #TP `COMPLIANCE_PATTERN;
            end else if (curnt_compliance_state == S_COMPL_EXIT_TX_EIDLE) begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP ((|current_data_rate)
                                           ) ? 3'd7 : 3'd0; //8 for not 2.5GT/s
            end
            else if ((curnt_compliance_state == S_COMPL_EXIT_SPEED_CHANGE) || (curnt_compliance_state == S_COMPL_EXIT_IN_EIDLE))
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
        S_POLL_CONFIG: begin
            ltssm_cmd               <= #TP `SEND_TS2;
            ltssm_xk237_4lnknum     <= #TP {NL{1'b1}};
            ltssm_xk237_4lannum     <= #TP {NL{1'b1}};
        end
        S_CFG_LINKWD_START: begin
            ltssm_cmd               <= #TP `SEND_TS1;

            ltssm_xlinknum          <= #TP !smlh_link_up ? xmt_ts_lnknum : ltssm_xlinknum;     //Errata A36

            ltssm_xk237_4lannum     <= #TP {NL{1'b1}};
            if (!cfg_upstream_port && ~(cfg_lpbk_en || latched_cfg_link_dis) && !cfglwstart_upconf_dsp )
                ltssm_xk237_4lnknum <= #TP {NL{1'b0}};
            else
                ltssm_xk237_4lnknum <= #TP {NL{1'b1}};
        end
        S_CFG_LINKWD_ACEPT: begin
            ltssm_cmd               <= #TP `SEND_TS1;
            ltssm_xk237_4lannum     <= #TP {NL{1'b1}};
            ltssm_xk237_4lnknum     <= #TP !cfg_upstream_port ? {NL{1'b0}} : ~latchd_smlh_lanes_rcving; // for the lanes do not receive TS with same link num, we need to put PAD out
            ltssm_xlinknum          <= #TP xmt_ts_lnknum;
        end
        S_CFG_LANENUM_WAIT: begin
            ltssm_cmd               <= #TP `SEND_TS1;
            ltssm_xk237_4lannum     <= #TP ~latchd_smlh_lanes_rcving;  // for the lanes do not receive TS with same link num, we need to put PAD out
            ltssm_xk237_4lnknum     <= #TP ~latchd_smlh_lanes_rcving;
            ltssm_xlinknum          <= #TP xmt_ts_lnknum;
        end
        S_CFG_LANENUM_ACEPT: begin
            ltssm_cmd               <= #TP `SEND_TS1;
            ltssm_xk237_4lannum     <= #TP ~latchd_smlh_lanes_rcving;  // for the lanes do not receive TS with same link num, we need to put PAD out
            ltssm_xk237_4lnknum     <= #TP ~latchd_smlh_lanes_rcving;
            ltssm_xlinknum          <= #TP xmt_ts_lnknum;
        end
        S_CFG_COMPLETE: begin
            ltssm_cmd               <= #TP `SEND_TS2;
            ltssm_xk237_4lannum     <= #TP ~latchd_smlh_lanes_rcving;  // for the lanes do not receive TS with same link num, we need to put PAD out
            ltssm_xk237_4lnknum     <= #TP ~latchd_smlh_lanes_rcving;
            ltssm_xlinknum          <= #TP xmt_ts_lnknum;
        end
        S_CFG_IDLE:
            ltssm_cmd               <= #TP `SEND_IDLE;
        S_L0 :
            ltssm_cmd               <= #TP `NORM;
        S_L0S:
            if (curnt_l0s_xmt_state == S_L0S_XMT_EIDLE) begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP (current_data_rate == `GEN2_RATE) ? 3'd1 : 3'd0;
            end
            else if ((curnt_l0s_xmt_state == S_L0S_XMT_FTS) & !xmtbyte_fts_sent)
                ltssm_cmd           <= #TP `SEND_N_FTS;
            else if ((curnt_l0s_xmt_state == S_L0S_EXIT_WAIT)
                    |(curnt_l0s_xmt_state == S_L0S_XMT_IDLE)
                    |(curnt_l0s_xmt_state == S_L0S_XMT_WAIT))
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            else
                ltssm_cmd           <= #TP `NORM;
        S_RCVRY_LOCK:
            if (current_powerdown == `P0) begin
              if ((ltssm_cmd != `NORM) || xmtbyte_cmd_is_data)
                ltssm_cmd           <= #TP `SEND_TS1;
              else
                ltssm_cmd           <= #TP ltssm_cmd;
            end else
                ltssm_cmd           <= #TP ltssm_cmd;
        S_RCVRY_RCVRCFG:
                ltssm_cmd           <= #TP `SEND_TS2;
        S_RCVRY_IDLE: begin
            if (no_idle_need_sent)
                ltssm_cmd           <= #TP ltssm_cmd; // Keep sending TS2 in this state when directed into config/loopback/disabled/hotreset
            else
                ltssm_cmd           <= #TP `SEND_IDLE;
        end

        S_L1_IDLE:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_L123_SEND_EIDLE:
            if (xmtbyte_eidle_sent | latched_eidle_sent)
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            // for upstream port, we will send one EIDLE order set at this set
            // for downstream port, we will send one EIDLE order set after
            // we received eidle order set which indicates remote port is
            // in L1 or L23
            else if ((latched_rcvd_eidle_set | smlh_l123_eidle_timeout | cfg_upstream_port) & (pm_smlh_entry_to_l1 | pm_smlh_entry_to_l2)) begin

                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP (current_data_rate == `GEN2_RATE) ? 3'd1 : 3'd0;
            end
        S_L2_IDLE:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_L2_WAKE:
// ccx_line_begin: ; unreachable because PM block doesn't make the condition for LTSSM from S_L2_IDLE to S_L2_WAKE for USP. No S_L2_WAKE state for DSP.
            ltssm_cmd               <= #TP `SEND_BEACON;
// ccx_line_end
        S_HOT_RESET_ENTRY:
            ltssm_cmd               <= #TP `SEND_TS1;
        S_HOT_RESET:
            ltssm_cmd               <= #TP `SEND_TS1;
        S_DISABLED_ENTRY: begin
            ltssm_cmd               <= #TP `SEND_TS1;
        end
        S_DISABLED_IDLE: begin
            begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP (current_data_rate == `GEN2_RATE) ? 3'd1 : 3'd0;
            end
        end
        S_DISABLED:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_LPBK_ENTRY:
            if (curnt_lpbk_entry_state == S_LPBK_ENTRY_IDLE) begin
                ltssm_cmd           <= #TP ltssm_cmd;
            end else if (curnt_lpbk_entry_state == S_LPBK_ENTRY_ADV)
                ltssm_cmd           <= #TP `SEND_TS1;
            else if (curnt_lpbk_entry_state == S_LPBK_ENTRY_EIDLE)
                if (xmtbyte_eidle_sent | latched_eidle_sent)
                    ltssm_cmd       <= #TP `XMT_IN_EIDLE;
                else begin
                    ltssm_cmd       <= #TP `SEND_EIDLE;
                    ltssm_eidle_cnt <= #TP (current_data_rate == `GEN2_RATE) ? 3'd1 : 3'd0;
                end
            else if (curnt_lpbk_entry_state == S_LPBK_ENTRY_TS) begin
                //Slave sends TS1s with Link#/Lane# set to PAD
                //if last state is EQ, it is >= gen5 rate, need keep the previous EQ link#/lane# for scrambling seed
                ltssm_cmd              <= #TP `SEND_TS1;
                ltssm_xk237_4lnknum    <= #TP lpbk_master ? ltssm_xk237_4lnknum : {NL{1'b1}};
                ltssm_xk237_4lannum    <= #TP lpbk_master ? ltssm_xk237_4lannum : {NL{1'b1}};
            end
        S_LPBK_ACTIVE: begin
            ltssm_cmd               <= #TP  `NORM;
        end
        S_LPBK_EXIT:
            if (lpbk_master) begin
                if ((ltssm_cmd != `NORM) || xmtbyte_cmd_is_data) begin
                    ltssm_cmd       <= #TP `SEND_EIDLE;
                    ltssm_eidle_cnt <= #TP 3'd7;
                end else begin
                    ltssm_cmd       <= #TP ltssm_cmd;
                end
            end
            else
                ltssm_cmd           <= #TP ltssm_cmd;
        S_LPBK_EXIT_TIMEOUT:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        default: // S_DETECT_QUIET
// ccx_line_begin: ; Redundant code for case default item.
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
// ccx_line_end
    endcase

wire   current_powerdown_p0;
reg    current_powerdown_p0_d;
wire   current_powerdown_p0_rising_edge;
assign current_powerdown_p0 = (current_powerdown == `P0);
always @(posedge core_clk or negedge core_rst_n) begin : current_powerdown_p0_d_PROC
    if (~core_rst_n)
        current_powerdown_p0_d <= #TP 0;
    else if (~((next_lts_state == S_POLL_ACTIVE) | (next_lts_state == S_RCVRY_LOCK)) && ~clear)
        current_powerdown_p0_d <= #TP 0;
    else
        current_powerdown_p0_d <= #TP current_powerdown_p0;
end //always
assign current_powerdown_p0_rising_edge = (current_powerdown_p0 & ~current_powerdown_p0_d);

localparam CLEAR_WD = 1;
reg   [CLEAR_WD-1:0] r_clear;
assign clear       = r_clear[0];
assign clear_o     = r_clear[0];
assign clear_eqctl = r_clear[0];
assign clear_seq   = r_clear[0];
assign clear_link  = r_clear[0];

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        r_clear                 <= #TP 0;
        l0s_state_clear         <= #TP 0;
     end else if (cfg_force_state) begin
        r_clear                 <= #TP {CLEAR_WD{1'b1}};
        l0s_state_clear         <= #TP 0;
     end else begin
        // Register the outputs
        r_clear                 <= #TP {CLEAR_WD{( !clear & ((next_lts_state != lts_state) || app_ltssm_enable_fall_edge)) // Clear counters on a state change
                                       | ((curnt_compliance_state == S_COMPL_ENT_TX_EIDLE)  && (curnt_compliance_state_d1 != S_COMPL_ENT_TX_EIDLE))
                                       | ((curnt_compliance_state == S_COMPL_EXIT_TX_EIDLE) && (curnt_compliance_state_d1 != S_COMPL_EXIT_TX_EIDLE))
                                       | ((lts_state == S_LPBK_ENTRY) & lpbk_clear)
                                       | (((lts_state == S_POLL_ACTIVE) | (lts_state == S_RCVRY_LOCK)) & (current_powerdown_p0_rising_edge))}};    // clear counter on current_powerdown = P0 rising edge during few states that is involved in power state change according PIPE spec.
        l0s_state_clear         <= #TP !l0s_state_clear & (next_l0s_xmt_state != curnt_l0s_xmt_state);
    end


reg [5:0] lts_state_wire;

always @(*)
    if (app_ltssm_enable_fall_edge) // 1->0 transition
        lts_state_wire    = S_PRE_DETECT_QUIET; // send EIOS and change speed back to Gen1 if needed
    else if (!app_ltssm_enable_dd && (lts_state != S_PRE_DETECT_QUIET)) // protect pre-detect-quiet state from forced transitions
        lts_state_wire    = S_DETECT_QUIET;
    else if (cfg_force_state)
        lts_state_wire    = cfg_forced_ltssm;
    else if (!clear)
        lts_state_wire    = next_lts_state;
    else
        lts_state_wire    = lts_state;

// replicates ltssm state register to resolve synthesis timing closure issue because of massive fan-outs
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        lts_state                    <= #TP S_DETECT_QUIET;
        smlh_ltssm_state             <= #TP S_DETECT_QUIET;
        smlh_ltssm_state_smlh_eq     <= #TP S_DETECT_QUIET;
        smlh_ltssm_state_smlh_sqf    <= #TP S_DETECT_QUIET;
        smlh_ltssm_state_smlh_lnk    <= #TP S_DETECT_QUIET;
        smlh_ltssm_state_xmlh        <= #TP S_DETECT_QUIET;
        smlh_ltssm_state_rmlh        <= #TP S_DETECT_QUIET;
    end else begin
        lts_state                    <= #TP lts_state_wire;
        smlh_ltssm_state             <= #TP lts_state_wire;
        smlh_ltssm_state_smlh_eq     <= #TP lts_state_wire;
        smlh_ltssm_state_smlh_sqf    <= #TP lts_state_wire;
        smlh_ltssm_state_smlh_lnk    <= #TP lts_state_wire;
        smlh_ltssm_state_xmlh        <= #TP lts_state_wire;
        smlh_ltssm_state_rmlh        <= #TP lts_state_wire;
    end
end

// Save the last state
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        last_lts_state         <= #TP S_DETECT_QUIET;
    else if (app_ltssm_enable_fall_edge) // 1->0 transition
        last_lts_state         <= #TP S_PRE_DETECT_QUIET; // send EIOS and change speed back to Gen1 if needed
    else if (!app_ltssm_enable_dd && (lts_state != S_PRE_DETECT_QUIET)) // protect pre-detect-quiet state from forced transitions
        last_lts_state         <= #TP S_DETECT_QUIET;
    else if (clear)
        last_lts_state         <= #TP last_lts_state;
    else if ((lts_state != next_lts_state) && !clear)
        last_lts_state         <= #TP lts_state;

reg error_entr_l1;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        error_entr_l1         <= #TP 0;
    else if ((next_lts_state == S_L1_IDLE) && (lts_state == S_L123_SEND_EIDLE) && timeout_2ms && !clear)
        error_entr_l1         <= #TP 1'b1;
    else if (lts_state != S_L1_IDLE)
        error_entr_l1         <= #TP 0;

always @(posedge core_clk or negedge core_rst_n) begin
  if ( !core_rst_n )
    ds_timeout_2ms <= #TP 1'b0;
  else if ( (lts_state == S_HOT_RESET_ENTRY) & timeout_2ms & !cfg_upstream_port && ~clear)
    ds_timeout_2ms <= #TP 1'b1;
  else if ( lts_state == S_PRE_DETECT_QUIET )
    ds_timeout_2ms <= #TP 1'b0;
end





always @( * ) begin : next_lts_state_PROC
        ltssm_in_hotrst_dis_entry = 1'b0;
        int_rcvd_8_ts2_skip_eq = 0;
        cfgcmpl_all_8_ts2_rcvd = 0;
        int_rcvd_8_ts2_noeq_nd = 0;
        int_bypass_gen3_eq = bypass_g3_eq;
        int_bypass_gen4_eq = bypass_g4_eq;
             case (lts_state)
        S_DETECT_QUIET: begin
            if ( app_ltssm_enable_dd
                && (current_powerdown == `P1) // If there was a power state change, wait until phystatus is received
                && ((timeout_12ms && all_phystatus_deasserted) || (latchd_phystatus_fall && any_phy_mac_rxeidle_exit)) )
                next_lts_state   = S_DETECT_ACT;
            else
                next_lts_state   = S_DETECT_QUIET;

            cfgcmpl_all_8_ts2_rcvd = 0;
            int_rcvd_8_ts2_noeq_nd = 0;
            int_bypass_gen3_eq = 1'b1;
            int_bypass_gen4_eq = 1'b1;
        end
        S_PRE_DETECT_QUIET: begin
            if (&xmtbyte_txelecidle
               && !(|latched_detect_speed)
               && !app_ltssm_enable_fall_edge && timeout_1us && !clear
               )
                next_lts_state   = S_DETECT_QUIET;
            else if (|latched_detect_speed && (current_data_rate == `GEN1_RATE) && timeout_1ms
) //change speed to gen1
                next_lts_state   = S_DETECT_QUIET;
            else if ( timeout_48ms ) // This transition is not possible under normal conditions.
                next_lts_state   = S_DETECT_QUIET;
            else
                next_lts_state   = S_PRE_DETECT_QUIET;
        end
        S_DETECT_ACT: begin
        // when all lanes detected receiver
        // or when the number of lanes detected receiver matched the
        // last time in this state
            if (int_rxdetect_done & ((all_phy_mac_rxdetected & ~retry_detect) | (any_phy_mac_rxdetected & retry_detect & same_detected_lanes)
                 | (cfg_auto_flip_en & cfg_auto_flip_using_predet_lane & int_rxdetected[0])
                ))
                next_lts_state   = S_POLL_ACTIVE;
             else if ((int_rxdetect_done & !any_phy_mac_rxdetected)
                      | (int_rxdetect_done & any_phy_mac_rxdetected & !same_detected_lanes & retry_detect)
                      | (int_rxdetect_done & cfg_auto_flip_en & cfg_auto_flip_using_predet_lane & !int_rxdetected[0])
                     )
                next_lts_state   = S_DETECT_QUIET;
             else if (int_rxdetect_done & any_phy_mac_rxdetected & !retry_detect)
                next_lts_state   = S_DETECT_WAIT;
             else
                next_lts_state   = S_DETECT_ACT;
        end
        S_DETECT_WAIT:
            if (timeout_12ms)
                next_lts_state   = S_DETECT_ACT;
            else
                next_lts_state   = S_DETECT_WAIT;

        S_POLL_ACTIVE: begin
            if (current_powerdown == `P0)
                if ( link_latched_live_all_8_ts_plinkn_planen_rcvd
                     && (link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd || link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd || link_latched_live_all_8_ts2_plinkn_planen_rcvd)
                     && xmtbyte_1024_ts_sent )
                    // 8 ts are rcvd with pad link/lane# on all lanes
                    next_lts_state = S_POLL_CONFIG;
                else if (timeout_24ms) begin
                    if ( link_latched_live_any_8_ts_plinkn_planen_rcvd && link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd && all_predet_lane_latchd_rxeidle_exit //ts_rcvd_1024_sent: 1024 TSs sent after receiving one TS
                          && (link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd || link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd || link_latched_live_any_8_ts2_plinkn_planen_rcvd) //don't check compl_rcv and lpbk if receiving TS2
                       )
                        next_lts_state = S_POLL_CONFIG;
                    else if ( any_predet_lane_latched_rxeidle )
                        // not all predet lanes exit rxelecidle
                        next_lts_state = S_POLL_COMPLIANCE;
                    else
                        next_lts_state = S_PRE_DETECT_QUIET;
                end else // !timeout_24ms
                    next_lts_state = S_POLL_ACTIVE;
            else // !current_powerdown == `P0
                next_lts_state = S_POLL_ACTIVE;
        end
        S_POLL_COMPLIANCE: begin
            if (curnt_compliance_state == S_COMPL_EXIT)
                next_lts_state = S_POLL_ACTIVE;
            else
                next_lts_state = S_POLL_COMPLIANCE;
        end
        S_POLL_CONFIG: begin
            //use latched signal because the other end may move to Configuration and start to send ts1s
            //while the near end is still sending 16 ts2s.
            if (link_latched_live_any_8_ts2_plinkn_planen_rcvd && link_xmlh_16_ts2_sent_after_1_ts2_rcvd)
                next_lts_state = S_CFG_LINKWD_START;
            else if (timeout_48ms)
                next_lts_state = S_PRE_DETECT_QUIET;
            else
                next_lts_state = S_POLL_CONFIG;
        end
        S_CFG_LINKWD_START: begin
            if ( ~cfg_upstream_port ) begin // DSP
                if ( latched_cfg_link_dis ) begin
                    next_lts_state = S_DISABLED_ENTRY;
                end else if ( cfg_lpbk_en ) begin
                    next_lts_state   = S_LPBK_ENTRY;
                end else if ( link_latched_live_all_2_ts1_lpbk1_rcvd ) begin // any_2_ts1_lpbk1_ebth1_rcvd_g5: Eq Bypass To Highest common gen5 rate
                    next_lts_state = S_LPBK_ENTRY;
                end else if ( link_any_2_ts1_linknmtx_planen_rcvd ) begin
                    next_lts_state = S_CFG_LINKWD_ACEPT;
                end else if ( timeout_32ms ) begin //32ms < 24ms + 50% margin
                    next_lts_state = S_PRE_DETECT_QUIET;
                end else begin
                    next_lts_state = S_CFG_LINKWD_START;
                end
            end else begin // USP
                if ( cfg_lpbk_en ) begin
                    next_lts_state   = S_LPBK_ENTRY;
                end else if ( link_any_2_ts1_dis1_rcvd ) begin
                    next_lts_state = S_DISABLED_ENTRY;
                end else if ( link_latched_live_all_2_ts1_lpbk1_rcvd ) begin
                    next_lts_state = S_LPBK_ENTRY;
                end else if ( 
                              (link_latched_live_all_2_ts1_linkn_planen_rcvd ) ) begin // ensure at least 1 ts1 sent
                    next_lts_state = S_CFG_LINKWD_ACEPT;
                end else if ( timeout_32ms ) begin //32ms < 24ms + 50% margin
                    next_lts_state = S_PRE_DETECT_QUIET;
                end else begin
                    next_lts_state = S_CFG_LINKWD_START;
                end
            end
        end
        S_CFG_LINKWD_ACEPT: begin
            if ( ~cfg_upstream_port && link_latched_live_all_2_ts1_linknmtx_rcvd ) begin
                next_lts_state = S_CFG_LANENUM_WAIT;
            end else if ( cfg_upstream_port && link_latched_live_all_2_ts1_linknmtx_lanen_rcvd ) begin
                next_lts_state = S_CFG_LANENUM_WAIT;
            end else if ( link_latched_live_all_2_ts1_plinkn_planen_rcvd || timeout_3ms ) begin //3ms = 2ms + 50% margin
                next_lts_state = S_PRE_DETECT_QUIET;
            end else begin
                next_lts_state = S_CFG_LINKWD_ACEPT;
            end
        end
        S_CFG_LANENUM_WAIT: begin
            if ( (~cfg_upstream_port && link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd) || (cfg_upstream_port && link_any_2_ts2_rcvd) ) begin
                next_lts_state = S_CFG_LANENUM_ACEPT;
            end else if ( (~cfg_upstream_port || timeout_1ms) && link_latched_live_any_2_ts1_lanendiff_linkn_rcvd ) begin
                // base spec: The Upstream Lanes are permitted delay up to 1 ms before transitioning to Configuration.Lanenum.Accept.
                // comment  : The "delay up to 1 ms" does not apply to DSP
                next_lts_state = S_CFG_LANENUM_ACEPT;
            end else if ( link_latched_live_all_2_ts1_plinkn_planen_rcvd || timeout_3ms ) begin //3ms = 2ms + 50% margin
                next_lts_state = S_PRE_DETECT_QUIET;
            end else begin
                next_lts_state = S_CFG_LANENUM_WAIT;
            end
        end
        S_CFG_LANENUM_ACEPT: begin
            // PCIe Gen5 errata for CXL:  If the use_modified_TS1_TS2_Ordered_Set variable is set to 1b and an Alternate Protocol Negotiation is being performed (cxl_enable == 1'b1), the transition to
            // Configuration.Complete must be delayed for 10us or until the Upstream Port responds to the protocol request (whichever happens first). This delay allows for a consensus to be reached.
            if ( ((~cfg_upstream_port && link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd) ||
                  (cfg_upstream_port && link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd)) && ~link_mode_changed ) begin
                next_lts_state = S_CFG_COMPLETE;
            end else if ( ~cfg_upstream_port && link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge  && ~link_mode_changed ) begin
                // base spec: If two consecutive TS1 Ordered Sets are received with non-PAD Link and non-PAD Lane numbers that match all the non-PAD Link and non-PAD Lane numbers (ORRRRR reversed Lane numbers if Lane reversal
                // is optionally supported) that are being transmitted in Downstream Lane TS1 Ordered Sets, the next state is Configuration.Complete. This must be on all smlh_lanes_active. If not, move to S_CFG_LANENUM_WAIT.
                // The core performs Lane Reversal (see link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge for signal next_smlh_lane_flip_ctrl) and transition to S_CFG_COMPLETE immediately & at the same time as lane reversal
                // This is not for USP according to base spec.
                next_lts_state = S_CFG_COMPLETE;
            end else if ( link_latched_live_all_2_ts1_linknmtx_lanen_rcvd && link_mode_changed ) begin
                next_lts_state = S_CFG_LANENUM_WAIT;
            end else if ( link_latched_live_all_2_ts1_plinkn_planen_rcvd || timeout_3ms ) begin //3ms = 2ms + 50% margin
                next_lts_state = S_PRE_DETECT_QUIET;
            end else begin
                next_lts_state = S_CFG_LANENUM_ACEPT;
            end
        end
        S_CFG_COMPLETE: begin
            if ( link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd && link_xmlh_16_ts2_sent_after_1_ts2_rcvd && deskew_complete_i ) begin
              begin
                next_lts_state = S_CFG_IDLE;
                int_rcvd_8_ts2_skip_eq = link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd & ~smlh_link_up; // skip eq on RX
                int_rcvd_8_ts2_noeq_nd = link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd & ~smlh_link_up; // no eq needed on RX including normal or mod TS2s
                cfgcmpl_all_8_ts2_rcvd = 1'b1 & ~smlh_link_up;
              end
            end else if ( timeout_2ms ) begin
                if ( !(&idle_to_rlock) & ((current_data_rate == `GEN3_RATE) || (current_data_rate == `GEN4_RATE) || (current_data_rate == `GEN5_RATE)) ) //idle_to_rlock < ffh & gen3 data rate
                  next_lts_state = S_CFG_IDLE;
                else
                  next_lts_state = S_PRE_DETECT_QUIET;
            end else begin
                next_lts_state = S_CFG_COMPLETE;
            end
        end
        S_CFG_IDLE: begin
            //not timeout from S_CFG_COMPLETE to S_CFG_IDLE for Gen3 rate
            if (
                 (((current_data_rate == `GEN1_RATE) || (current_data_rate == `GEN2_RATE)) && rcvd_8idles && idle_16_sent) )
                next_lts_state = S_L0;
            else if (timeout_2ms) begin
                if ( !(&idle_to_rlock) ) //idle_to_rlock < ffh
                    next_lts_state = S_RCVRY_LOCK;
                else
                    next_lts_state = S_PRE_DETECT_QUIET;
            end else
                next_lts_state = S_CFG_IDLE;

            int_rcvd_8_ts2_skip_eq = 0;
            int_rcvd_8_ts2_noeq_nd = 0;
            cfgcmpl_all_8_ts2_rcvd = 0;
        end
        S_L0: begin
        // when pm module direct this state machine to go into
        // L0s,l1,l2,l3, it will start the transition
        //
        // According to spec. electric idle set received will trig a entry
        //to power down state. It really means that we have detected
        //remote side with entering into low power state. It is upto PM
        //module to decide whether or not to enter into the low  poweri state
            if (l0_link_rcvry_en || deskew_complete_n_d) begin // see deskew_complete_n signal explanation, immediately move to Recovery if deskew_complete_n
                next_lts_state = S_RCVRY_LOCK;
            end
            else if (pm_smlh_prepare4_l123)
                next_lts_state = S_L123_SEND_EIDLE;
            // in case of EIOS delay by 40ns entrance into Rx L0s to avoid start looking too soon for rxelecidle=0 before rxelecidle has become stable high
            else if (pm_smlh_entry_to_l0s | (latched_rcvd_eidle_set_4rl0s & timeout_40ns_4rl0s & cfg_l0s_supported) | (r_curnt_l0s_rcv_state != S_L0S_RCV_ENTRY) | (curnt_l0s_xmt_state != S_L0S_XMT_ENTRY))
                next_lts_state = S_L0S;
            else if (latched_rcvd_eidle_set_4rl0s && !cfg_l0s_supported)
                next_lts_state = S_RCVRY_LOCK;
            else
                next_lts_state = S_L0;
        end
        S_L0S: begin
            if ((r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY) & (curnt_l0s_xmt_state == S_L0S_XMT_ENTRY) & !(rcvr_l0s_goto_rcvry) & !(pm_smlh_entry_to_l0s | rmlh_rcvd_eidle_set))
                next_lts_state   = S_L0;
            else if ((curnt_l0s_xmt_state == S_L0S_XMT_ENTRY) & (rcvr_l0s_goto_rcvry) & (r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY))
                next_lts_state   = S_RCVRY_LOCK;
            else
                next_lts_state   = S_L0S;
        end
        S_RCVRY_LOCK: begin
            if ( link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd &&

                 (cfg_ext_synch ? xmtbyte_1024_consecutive_ts1_sent : 1'b1) && (current_powerdown == `P0) ) begin
                 // receive 8 ts with link/lane# match and spd_chg==directed_speed_change and ec==00b on all lanes, and 1024 CONSECUTIVE TS1s sent if ext_synch==1b.
                 // link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd: the remote partner is in Rcvry.RcvrCfg state already, so we have to move to Rcvry.RcvrCfg.
                 // dsp_timeout_common_mode: for DSP if enter this state from L1.2 exit, have to wait until Tcommonmode has elapsed, then move to S_RCVRY_RCVRCFG to send TS2.
                 next_lts_state = S_RCVRY_RCVRCFG;
            end else if ( timeout_24ms ) begin
                if ( current_powerdown == `P0 ) begin
                    if ( link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd ) begin
                        // rcvd speed_change bit and data_rate value latched from the last rcvd TS in the state Rcvry.RcvrLock.
                        // ltssm_ts_data_rate[1] == 1b: over Gen1 rate is transmitted; ltssm_ts_data_rate[1] == 0b: only Gen1 rate is transmitted. This is in signal common_gen1_supported.
                        next_lts_state   = S_CFG_LINKWD_START;
                    end else begin
                        next_lts_state = S_PRE_DETECT_QUIET;
                    end
                end else begin// current_powerdown == `P0
                    next_lts_state = S_PRE_DETECT_QUIET;
                end
            end else begin
                next_lts_state = S_RCVRY_LOCK;
            end
        end // S_RCVRY_LOCK
        S_RCVRY_RCVRCFG: begin
            if ( (link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd
                 ) && link_xmlh_16_ts2_sent_after_1_ts2_rcvd && deskew_complete_i //16 ts2 sent after rcving 1 ts2
               ) begin
                next_lts_state = S_RCVRY_IDLE;
            end else if ( (link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd // this covers cfg_ts2_lid_deskew==1 because lane# mismatching
                          ) && link_xmlh_16_ts2_sent_after_1_ts1_rcvd //16 ts2 sent after rcving 1 ts1
                        ) begin
                next_lts_state = S_CFG_LINKWD_START;
            end else if ( (cfg_upstream_port ) && link_any_2_ts1_dis1_rcvd ) begin // L1 -> Recovery and hard to get sym/bit/blockalign lock or no deskew_complete for cfg_ts2_lid_deskew
                next_lts_state = S_DISABLED_ENTRY; //L1 -> Recovery -> Disabled, no need rmlh_deskew_complete -> S_RCVRY_IDLE and the remote is in DISABLED state already. It is SAFE. for cfg_ts2_lid_deskew due to no idle data sent from remote
            end else if ( (cfg_upstream_port ) && link_any_2_ts1_hotreset1_rcvd && cfg_ts2_lid_deskew && (current_data_rate ==  `GEN1_RATE || current_data_rate ==  `GEN2_RATE) ) begin
                next_lts_state = S_HOT_RESET_ENTRY; // no deskew_complete for cfg_ts2_lid_deskew because the remote partner doesn't send Idle Data, only affect Gen1/2 rate
            end else if ( link_any_2_ts1_lpbk1_rcvd && cfg_ts2_lid_deskew && (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE) ) begin
                next_lts_state = S_LPBK_ENTRY; // no deskew_complete for cfg_ts2_lid_deskew because the remote partner doesn't send Idle Data, only affect Gen1/2 rate
            end else if ( timeout_48ms ) begin
                if ( current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE ) //The next state is Detect if the current Data Rate is 2.5 GT/s or 5GT/s
                    next_lts_state = S_PRE_DETECT_QUIET;
                //The next state is Recovery.Idle if idle_to_rlock_transitioned variable is less than ffh and current Data Rate is 8 GT/s.
                else if ( ((current_data_rate == `GEN3_RATE) || (current_data_rate == `GEN4_RATE) || (current_data_rate == `GEN5_RATE)) && (idle_to_rlock < 8'hff) )
                    next_lts_state = S_RCVRY_IDLE;
                else //Else the next state is Detect
                    next_lts_state = S_PRE_DETECT_QUIET;
            end else begin
                next_lts_state = S_RCVRY_RCVRCFG;
            end
        end // S_RCVRY_RCVRCFG
        S_RCVRY_IDLE: begin
            if ( (~cfg_upstream_port ) && cfg_link_dis && no_idle_need_sent ) begin
                next_lts_state = S_DISABLED_ENTRY;
            end else if ( (~cfg_upstream_port ) && latched_direct_rst && no_idle_need_sent ) begin
                next_lts_state = S_HOT_RESET_ENTRY;
            end else if ( cfg_lpbk_en && no_idle_need_sent ) begin
                next_lts_state = S_LPBK_ENTRY;
            end else if ( (cfg_upstream_port ) && link_any_2_ts1_dis1_rcvd ) begin
                next_lts_state = S_DISABLED_ENTRY;
            end else if ( (cfg_upstream_port ) && link_any_2_ts1_hotreset1_rcvd ) begin
                next_lts_state = S_HOT_RESET_ENTRY;
            end else if ( link_any_2_ts1_planen_rcvd || (cfg_gointo_cfg_state & no_idle_need_sent) || directed_link_width_change ) begin //cfg_gointo_cfg_state not supported yet
                next_lts_state = S_CFG_LINKWD_START;
            end else if ( link_any_2_ts1_lpbk1_rcvd ) begin
                next_lts_state = S_LPBK_ENTRY;
            end else if (
                          ((current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE) && rcvd_8idles && idle_16_sent)
                        ) begin
                next_lts_state = S_L0;
            end else if ( timeout_2ms ) begin
                if ( !(&idle_to_rlock) ) //idle_to_rlock < ffh
                    next_lts_state = S_RCVRY_LOCK;
                else
                    next_lts_state = S_PRE_DETECT_QUIET;
            end else begin
                next_lts_state = S_RCVRY_IDLE;
            end
        end // S_RCVRY_IDLE
        S_L123_SEND_EIDLE: begin
             // To finally enter L1 or L23 state, ltssm needs to wait for remote device to enter electric idle. Or under error conditions of electric idle detection, the TS ordered set received will allow core to enter L1 or L23, and then gracefully exit L1 or L23 to recovery lock.
            // Note: another condition is that if an electric ordered set has been received followed with skip or TS, it means that electric idle signal is not properly detected, then core enter L1 or L23 under this error condition to gracefully exit the L1 and L23.

         if (pm_smlh_entry_to_l1 & latched_eidle_sent
             & ((latched_rcvd_eidle_set & ei_interval_expire )
               | (rcvd_2_unexpect_ts)
                | timeout_2ms)
        )
                next_lts_state   = S_L1_IDLE;
       // the reason for the !current_data_rate is that the PHY has to be in gen1 rate before
       // transitioning to P2 according to the PIPE spec

            // if rcvd TSs for DSP, move to S_L2_IDLE and have a fundamental reset perst in S_L2_IDLE
            // if rcvd TSs for USP, move to Recovery as RC is in Recovery.
       else if (pm_smlh_entry_to_l2 & latched_eidle_sent
                & ((latched_rcvd_eidle_set &
                  ei_interval_expire
)
              | (!cfg_upstream_port && rcvd_2_unexpect_ts)
                | timeout_2ms)
          )
                next_lts_state   = S_L2_IDLE;
       else if (pm_smlh_entry_to_l2 && latched_eidle_sent
                     && rcvd_2_unexpect_ts && cfg_upstream_port)
                next_lts_state   = S_RCVRY_LOCK;
            else
                next_lts_state   = S_L123_SEND_EIDLE;
        end // S_L123_SEND_EIDLE
        S_L1_IDLE: begin
            // When next_lts_state tries to get into L1 state, It must have
            // a mininume of TX_IDLE_MIN timeout (1us) before it can look
            // for exit of l1. This will guarantees that the transmitter
            // has established the electrical idle condition
            if ( ( pm_smlh_l1_exit
                    & (timeout_40ns ) )
                    & (current_powerdown == `P1 ))
                next_lts_state   = S_RCVRY_LOCK;
            else
                next_lts_state   = S_L1_IDLE;
        end
        S_L2_IDLE: begin
            // current_powerdown == `P2 from LTSSM. LTSSM does not drive powerdown from P2 to P1 but PM does. PIPE spec requires rate change only in P0 or P1
            if ( any_predet_lane_rxeidle_exit && timeout_40ns && (current_powerdown == `P2) && (pm_current_powerdown_p1 || pm_current_powerdown_p0) )
                next_lts_state   = S_PRE_DETECT_QUIET;
// ccx_line_begin: ; unreachable because PM block doesn't make the condition for LTSSM from S_L2_IDLE to S_L2_WAKE for USP. No S_L2_WAKE state for DSP.
            else if (pm_smlh_l23_exit & timeout_40ns & cfg_upstream_port & (current_powerdown == `P2))
                next_lts_state   = S_L2_WAKE;
// ccx_line_end
            else
                next_lts_state   = S_L2_IDLE;
        end
// ccx_line_begin: ; unreachable because PM block doesn't make the condition for LTSSM from S_L2_IDLE to S_L2_WAKE for USP. No S_L2_WAKE state for DSP.
        S_L2_WAKE: begin
           // PIPE spec requires rate change only in P0 or P1. PM block drives powerdown from P2 to P1
           if ( !all_phy_mac_rxelecidle && (pm_current_powerdown_p1 || pm_current_powerdown_p0) )
                next_lts_state   = S_PRE_DETECT_QUIET;
            else
                next_lts_state   = S_L2_WAKE;
        end
// ccx_line_end
        S_HOT_RESET_ENTRY: begin
            ltssm_in_hotrst_dis_entry = 1'b1;
            // For downstream ports, stay here until the link partner reaches Hot Reset.
            if ((!cfg_upstream_port
                 ) & link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd)
                next_lts_state   = S_HOT_RESET;
            //as long as the EP is contineously receiving TS1 with reset, stay in HOT_RESET_ENTRY state and keep linkup
            //When timeout_2ms happened after rcvd_2rst is deasserted, then
            //we will go into predetect quiet
            // The timeout timer is reset everytime rcvd_2rst signal is assert
            else if (timeout_2ms)
                next_lts_state   = S_HOT_RESET;
            else
                next_lts_state   = S_HOT_RESET_ENTRY;
        end
        S_HOT_RESET: begin
            // Once Reset goes away
            if (!latched_direct_rst | ds_timeout_2ms
                | cfg_upstream_port
               )
                next_lts_state   = S_PRE_DETECT_QUIET;
            else
                next_lts_state   = S_HOT_RESET;
        end
        S_DISABLED_ENTRY: begin
            ltssm_in_hotrst_dis_entry = 1'b1;
            // after 16 ts1 s with disable bit set, then we need to gointo idle state for s electric idle
            if (xmtbyte_16_ts_w_dis_link_sent)
                next_lts_state   = S_DISABLED_IDLE;
            else
                next_lts_state   = S_DISABLED_ENTRY;
        end
        S_DISABLED_IDLE: begin
            if ( !cfg_link_dis & !cfg_upstream_port )
                next_lts_state   = S_PRE_DETECT_QUIET;
            else if (latched_rcvd_eidle_set & ei_interval_expire & latched_eidle_sent) begin
                    next_lts_state   = S_DISABLED;
            end else if (timeout_2ms & cfg_upstream_port)
                next_lts_state   = S_PRE_DETECT_QUIET;
            else
                next_lts_state   = S_DISABLED_IDLE;
        end
        S_DISABLED: begin
            if ( !cfg_link_dis & !cfg_upstream_port && current_powerdown == `P1)
                next_lts_state   = S_PRE_DETECT_QUIET;
            else if (!all_phy_mac_rxelecidle & cfg_upstream_port && current_powerdown == `P1)
                next_lts_state   = S_PRE_DETECT_QUIET;
            else
                next_lts_state   = S_DISABLED;
        end
        S_LPBK_ENTRY: begin
            if ( ( timeout_24ms) & lpbk_master )   // timer less than 100ms for master device
                next_lts_state   = S_LPBK_EXIT;
            else
        // loopback conditions for going into active state:
        // 1. received ts1 with loopback enable bit set after master
        // has s tst1 with loopback bit set
        // 2. slave has to  enter loopback active when it detected two
        // or more consecutive ts1 with lpbk enabled
        // received
            if (  (curnt_lpbk_entry_state == S_LPBK_ENTRY_TS)
               && ( (!lpbk_master && ((link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd || link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd) // slave : Rx Compliance receive bit of TS1s directing to Lpbk.Entry
                    || (rmlh_all_sym_locked && (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE)) // slave : Symbol locked for Gen1/2 rate on all active lanes
                    ))
                  || (lpbk_master && link_imp_2_ts1_lpbk1_rcvd //implementation-specific set of lanes receiving TS1 with loopback bit = 1. it was link_any_2_ts1_lpbk1_rcvd
                     )) ) // master: Tx compliance receive = 0 & Rx LPBK = 1
                next_lts_state   = S_LPBK_ACTIVE;
            else
                next_lts_state   = S_LPBK_ENTRY;
        end
        S_LPBK_ACTIVE: begin
        // exit loopback based on two seperate conditions, one for
        // master of the loopback device and one for slave of the
        // loopback device.
            if (  (lpbk_master & !cfg_lpbk_en)    // directed for loopback master
                  || (~lpbk_master & rcvd_4eidle) // 4 EIOSs received or Eidle inferred for loopback slave
                  || (~lpbk_master                // loopback slave
                      & (current_data_rate == `GEN1_RATE)        // with current link speed 2.5 GT/s
                      & (latched_rcvd_eidle_set   // and an EIOS received
                        | smlh_eidle_inferred                                // or Eidle is inferred from page 183 of 2.0 spec (section 4.2.4.3)
                        )) )
                next_lts_state   = S_LPBK_EXIT;
            else
                next_lts_state   = S_LPBK_ACTIVE;
        end
        S_LPBK_EXIT: begin
            if (lpbk_master & xmtbyte_eidle_sent)
                next_lts_state   = S_LPBK_EXIT_TIMEOUT;
            else if (!lpbk_master && timeout_1us && ~clear)
                next_lts_state   = S_LPBK_EXIT_TIMEOUT;
            else
                next_lts_state   = S_LPBK_EXIT;
        end
        S_LPBK_EXIT_TIMEOUT: begin
            if (timeout_2ms) begin
                next_lts_state   = (|current_data_rate) ? S_PRE_DETECT_QUIET : S_DETECT_QUIET; //if gen2/3, go to S_PRE_DETECT_QUIET for speed change to gen1
            end else
                next_lts_state   = S_LPBK_EXIT_TIMEOUT;
        end
        default: begin
            next_lts_state   = S_DETECT_QUIET;
        end
        endcase
end // next_lts_state_PROC



// output drive process
// Xmlh_link_up is a signal to indicate the LTSSM's linkup status based on specification.
//
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        smlh_link_up            <= #TP 1'b0;
    else if ((lts_state == S_L0S) | (lts_state == S_L0)
             | (lts_state == S_RCVRY_RCVRCFG) | (lts_state == S_RCVRY_LOCK)
             | (lts_state == S_RCVRY_IDLE) | (lts_state == S_CFG_IDLE)
             | (lts_state == S_LPBK_ACTIVE && lpbk_master))
        smlh_link_up            <= #TP 1'b1;
    else if ((lts_state == S_DISABLED)   // according to spec intended usage of the disable function
             | (lts_state == S_DETECT_QUIET)
             | (lts_state == S_DETECT_ACT)
             | (lts_state == S_POLL_COMPLIANCE)
             | (lts_state == S_LPBK_ENTRY)
             | ((~cfg_upstream_port) ? (lts_state == S_HOT_RESET) : (lts_state == S_HOT_RESET_ENTRY))
             | (lts_state == S_POLL_CONFIG)
             | (lts_state == S_DETECT_WAIT)
             | (lts_state == S_LPBK_EXIT_TIMEOUT))
        smlh_link_up            <= #TP 1'b0;
end


// LTSSM in L1 with powerdown P1
assign smlh_in_l1_p1 = smlh_in_l1 && (current_powerdown == `P1);

always @(posedge core_clk or negedge core_rst_n)
begin : LINK_DOWN_REQ_RESET
    if (!core_rst_n)
        smlh_req_rst_not       <= #TP 1'b0;
    else if ((lts_state == S_L0S) | (lts_state == S_L0)
             | (lts_state == S_RCVRY_RCVRCFG) | (lts_state == S_RCVRY_LOCK)
             | (lts_state == S_RCVRY_IDLE) | (lts_state == S_CFG_IDLE)
             | (lts_state == S_LPBK_ACTIVE && lpbk_master))
        smlh_req_rst_not       <= #TP 1'b1;
    else if ((lts_state == S_DETECT_QUIET)
             | (lts_state == S_DETECT_ACT)
             | (lts_state == S_POLL_COMPLIANCE)
             | (lts_state == S_POLL_CONFIG)
             | (lts_state == S_DETECT_WAIT))
        smlh_req_rst_not       <= #TP 1'b0;
end


wire gen12 = current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE;
wire config_lanenum_state = (lts_state == S_CFG_LANENUM_WAIT || lts_state == S_CFG_LANENUM_ACEPT || lts_state == S_CFG_COMPLETE) & gen12;
assign poll_config_state = (lts_state == S_POLL_ACTIVE || lts_state == S_POLL_CONFIG || lts_state == S_CFG_LINKWD_START || lts_state == S_CFG_LINKWD_ACEPT) & gen12;
reg  int_disable, int_hot_reset, int_skip_eq, int_alt_protocol, int_mod_ts, int_no_eq_needed, int_lpbk_eq, int_tx_mod_cmpl;
wire lpbk_master_in_entry = (lpbk_master & (lts_state == S_LPBK_ENTRY));


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        ltssm_in_pollconfig     <= #TP 1'b0;
        int_lpbk                <= #TP 0;
        int_disable             <= #TP 0;
        int_hot_reset           <= #TP 0;
        int_mod_ts              <= #TP 0;
        int_skip_eq             <= #TP 0;
        int_alt_protocol        <= #TP 0;
        int_no_eq_needed        <= #TP 0;
        int_lpbk_eq             <= #TP 0;
        int_tx_mod_cmpl         <= #TP 0;
    end else begin
        ltssm_in_pollconfig     <= #TP (lts_state == S_POLL_CONFIG);
        int_lpbk                <= #TP lpbk_master_in_entry ? 1'b1 //Not send lpbk=1 in Loopback EQ for Loopback master to prevent master in EQ and slave in Loopback.Entry. slave to Lpbk.Active while master is still in Lpbk EQ and cannot exit the EQ
                                       : ( (lts_state == S_LPBK_ACTIVE) | (lts_state == S_LPBK_EXIT) | (lts_state == S_DETECT_QUIET)) ? 1'b0 : int_lpbk;
        int_disable             <= #TP (lts_state == S_DISABLED_ENTRY) ? 1'b1 : (lts_state == S_DETECT_QUIET) ? 1'b0: int_disable;
        int_hot_reset           <= #TP ((lts_state == S_HOT_RESET_ENTRY) | (lts_state == S_HOT_RESET)) ? 1'b1
                                       : (lts_state == S_DETECT_QUIET) ? 1'b0 : int_hot_reset;
        int_mod_ts              <= #TP 0; // support Mod TS. In Mod TS Format, Sym5[7:6] = 2'b11 always in TS1/2 for gen1/2 rate
        int_skip_eq             <= #TP 0; // negotiated in config_lanenum_state to initial L0. "negotiated" means TX and RX
        int_alt_protocol        <= #TP 0; // negotiated in config_lanenum_state to initial L0. "negotiated" means TX and RX
                                       // A component must not advertise this capability (no eq needed) if the 'Equalization bypass to highest rate support Disable' bit is set to 1b
        int_no_eq_needed        <= #TP 0; // negotiated in config_lanenum_state to initial L0. "negotiated" means TX and RX
        int_lpbk_eq             <= #TP 1'b0;
        int_tx_mod_cmpl         <= #TP 1'b0;
    end

wire mod_ts_i = 0;
always @( * ) begin : mod_ts_i_PROC
    ltssm_mod_ts = 0;
    ltssm_mod_ts_rx = 0;

    ltssm_mod_ts = mod_ts_i;
    ltssm_mod_ts_rx = mod_ts_i;
end // mod_ts_i_PROC

assign  pre_ltssm_ts_cntrl[4]       =  1'b0;

assign  pre_ltssm_ts_cntrl[3:0]     =                                   { ((current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE) ? ((lts_state_d == S_CFG_COMPLETE) & cfg_scrmb_dis) : 1'b0), int_lpbk, int_disable, int_hot_reset};
assign  pre_ltssm_ts_cntrl[5]       =  1'b0;
assign  pre_ltssm_ts_cntrl[7:6]     =  2'b00;
assign  ltssm_ts_alt_protocol   =  1'b0;

assign ltssm_ts_cntrl = pre_ltssm_ts_cntrl;

// State machine for handling speed changes and electrical idle in Polling.Compliance
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        curnt_compliance_state  <= #TP S_COMPL_IDLE;
    else if (lts_state != S_POLL_COMPLIANCE)                                    // hold in idle unless we are in Polling.Compliance
        curnt_compliance_state  <= #TP S_COMPL_IDLE;
    else
        curnt_compliance_state  <= #TP next_compliance_state;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        curnt_compliance_state_d1  <= #TP S_COMPL_IDLE;
    else
        curnt_compliance_state_d1  <= #TP curnt_compliance_state;

always @(curnt_compliance_state or ts_sent_in_poll_active or latched_eidle_sent
         or current_data_rate
         or rxelecidle_fall or next_data_rate or timeout_polling_eidle
    )
    begin : COMPLIANCE_STATE

             case (curnt_compliance_state)
            S_COMPL_IDLE:
                if (|next_data_rate) //have to send EIOS for gen2/3, then change speed
                    if (ts_sent_in_poll_active)                                 // if TSs were sent in Polling.Active EIOS must be sent
                        next_compliance_state   = S_COMPL_ENT_TX_EIDLE;
                    else
                        next_compliance_state   = S_COMPL_ENT_SPEED_CHANGE;
                else
                    next_compliance_state   = S_COMPL_TX_COMPLIANCE;
            S_COMPL_ENT_TX_EIDLE:                                               // Send an EIDLE ordered set and go to next state
                if (latched_eidle_sent)
                    next_compliance_state   = S_COMPL_ENT_SPEED_CHANGE;
                else
                    next_compliance_state   = S_COMPL_ENT_TX_EIDLE;
            S_COMPL_ENT_SPEED_CHANGE:                                           // Change speed to Gen II and wait for 1ms timeout
                if (timeout_polling_eidle & (current_data_rate != `GEN1_RATE))
                    next_compliance_state   = S_COMPL_TX_COMPLIANCE;
                else
                    next_compliance_state   = S_COMPL_ENT_SPEED_CHANGE;
            S_COMPL_TX_COMPLIANCE: begin
                if ( |rxelecidle_fall )
                    next_compliance_state   = S_COMPL_EXIT;
                else
                    next_compliance_state   = S_COMPL_TX_COMPLIANCE;
            end
            S_COMPL_EXIT:
                    next_compliance_state   = S_COMPL_EXIT;        // When lts_state != S_POLL_COMPLIANCE, next state will be idle
            default:
// ccx_line_begin: ; Redundant code for case default item.
                next_compliance_state   = S_COMPL_IDLE;
// ccx_line_end
        endcase
    end


// State machine for handling speed changes and electrical idle in Loopback.Entry
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        curnt_lpbk_entry_state  <= #TP S_LPBK_ENTRY_IDLE;
    else if (lts_state != S_LPBK_ENTRY)                                     // hold in idle unless we are in Loopback.Entry
        curnt_lpbk_entry_state  <= #TP S_LPBK_ENTRY_IDLE;
    else if (!clear)
        curnt_lpbk_entry_state  <= #TP next_lpbk_entry_state;

always @(
         curnt_lpbk_entry_state)
    begin : LOOPBACK_ENTRY_STATE
        lpbk_clear_wire = 1'b0;

        case (curnt_lpbk_entry_state)
            S_LPBK_ENTRY_IDLE:
                    next_lpbk_entry_state   = S_LPBK_ENTRY_TS;
            S_LPBK_ENTRY_TS:                                                // Change speed to Gen II and wait for 1ms timeout
                    next_lpbk_entry_state   = S_LPBK_ENTRY_TS;
            default:
                next_lpbk_entry_state   = S_LPBK_ENTRY_IDLE;
        endcase
    end

assign ltssm_lpbk_entry_send_ts1 = (curnt_lpbk_entry_state == S_LPBK_ENTRY_TS);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        lpbk_clear  <= #TP 1'b0;
    else if (lts_state != S_LPBK_ENTRY)
        lpbk_clear  <= #TP 1'b0;
    else if (!clear)
        lpbk_clear  <= #TP lpbk_clear_wire;

reg [3:0] xmt_timer_20ns;
wire      xmt_timeout_20ns;

always @(posedge core_clk or negedge core_rst_n) begin : xmt_timer_20ns_PROC
    if (!core_rst_n) begin
        xmt_timer_20ns <= #TP 0;
    end else if (curnt_l0s_xmt_state == S_L0S_XMT_EIDLE) begin
        xmt_timer_20ns <= #TP 0;
    end else if (!xmt_timeout_20ns) begin
        xmt_timer_20ns <= #TP xmt_timer_20ns + (timer2 ? timer_freq_multiplier : 1'b0);
    end
end // xmt_timer_20ns_PROC

assign xmt_timeout_20ns = (xmt_timer_20ns >= `CX_TIME_20NS);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        curnt_l0s_xmt_state <= #TP S_L0S_XMT_ENTRY;
    else
        curnt_l0s_xmt_state <= #TP next_l0s_xmt_state;

// if ~rmlh_deskew_complete, transmitter should not enter L0s but Recovery because the RX is not deskew complete when RX is still in L0
always @(pm_smlh_entry_to_l0s or l0_link_rcvry_en or xmtbyte_eidle_sent or pm_smlh_prepare4_l123 or current_powerdown
        or xmt_timeout_20ns or curnt_l0s_xmt_state or lts_state or rcvr_l0s_goto_rcvry or pm_smlh_l0s_exit or xmtbyte_fts_sent)
begin

             case (curnt_l0s_xmt_state)
            S_L0S_XMT_ENTRY:
                if (((lts_state == S_L0) & pm_smlh_entry_to_l0s & !(l0_link_rcvry_en) & !pm_smlh_prepare4_l123) // when xmtr enter L0s first
                     | ((lts_state == S_L0S) & pm_smlh_entry_to_l0s & !rcvr_l0s_goto_rcvry)) // when rcvr in l0s
                    next_l0s_xmt_state =  S_L0S_XMT_EIDLE;
                else
                    next_l0s_xmt_state =  S_L0S_XMT_ENTRY;

            S_L0S_XMT_EIDLE:    // Wait here until eidle sent
                if (xmtbyte_eidle_sent)
                    next_l0s_xmt_state =  S_L0S_XMT_WAIT;
                else
                    next_l0s_xmt_state =  S_L0S_XMT_EIDLE;

            S_L0S_XMT_WAIT:
                if (xmt_timeout_20ns & (current_powerdown == `P0S))  // either time out for 50 ui or phy has acknowledged the power state change before we can get into the l0s state. This is to prevent MAC to exit L0s without acknowledgement of the PHY to the previous power state change command
                    next_l0s_xmt_state = S_L0S_XMT_IDLE ;
                else
                    next_l0s_xmt_state = S_L0S_XMT_WAIT;

            S_L0S_XMT_IDLE:
                // waking remote site up when recovery condition has been
                // detected
                if (rcvr_l0s_goto_rcvry | pm_smlh_l0s_exit)
                    next_l0s_xmt_state = S_L0S_EXIT_WAIT;
                else
                    next_l0s_xmt_state = S_L0S_XMT_IDLE;

            S_L0S_EXIT_WAIT: begin
                if ( current_powerdown == `P0 )
                    next_l0s_xmt_state = S_L0S_XMT_FTS;
                else
                    next_l0s_xmt_state = S_L0S_EXIT_WAIT;
            end

            default: // S_L0S_XMT_FTS, Wait here until all FTSs are sent
                if (xmtbyte_fts_sent)
                    next_l0s_xmt_state = S_L0S_XMT_ENTRY;
                else
                    next_l0s_xmt_state = S_L0S_XMT_FTS;
        endcase
end

// L0s substate is designed as following

// Assign each substate in Rx L0s
assign l0s_rcv_entry = (curnt_l0s_rcv_state == S_L0S_RCV_ENTRY);         // Rx_L0s.Entry
assign l0s_rcv_idle  = (curnt_l0s_rcv_state == S_L0S_RCV_IDLE);         // Rx_L0s.Idle
assign l0s_rcv_fts   = (curnt_l0s_rcv_state == S_L0S_RCV_FTS);         // Rx_L0s.FTS

// 1 cycle delay versions of above substates:
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        r_l0s_rcv_entry          <= #TP 0;
        r_l0s_rcv_idle           <= #TP 0;
        r_l0s_rcv_fts            <= #TP 0;
    end else if (!clear) begin
        r_l0s_rcv_entry          <= #TP l0s_rcv_entry;
        r_l0s_rcv_idle           <= #TP l0s_rcv_idle;
        r_l0s_rcv_fts            <= #TP l0s_rcv_fts;
    end

// Generate clear pulse every time there is an entry to or exit from each Rx_L0s substate.
assign clr_l0s_rcv = (((l0s_rcv_entry ^ r_l0s_rcv_entry) | (l0s_rcv_idle ^ r_l0s_rcv_idle) | (l0s_rcv_fts ^ r_l0s_rcv_fts)));

// Timers are cleared every time Rx_L0s substates are changed OR when
// receive electrical idle is set while in S_L0 or S_L0s:
assign  clr_timer_4rl0s     = clr_l0s_rcv                                     // start nfts timer
                              || (rmlh_rcvd_eidle_set & (lts_state == S_L0)) // start 40ns timer in L0 state
                              || (rmlh_rcvd_eidle_set & (lts_state == S_L0S)); // start 40ns timer When xmtr in L0s state

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_pm_latched_eidle_set  <= #TP 1'b0;
    else if (rmlh_rcvd_eidle_set)
        smlh_pm_latched_eidle_set  <= #TP 1'b1;
    // don't clear on L0->L0s transition otherwise we could miss an eios that happened around the same time L0s is entered because of pm_smlh_entry_to_l0s
    else if ((clear & (lts_state != S_DISABLED_IDLE) & (lts_state != S_L123_SEND_EIDLE) & (lts_state != S_L0S)) || (r_curnt_l0s_rcv_state == S_L0S_RCV_FTS))
    //old:else if ((clear & (lts_state != S_DISABLED_IDLE) & (lts_state != S_L123_SEND_EIDLE)))
        smlh_pm_latched_eidle_set  <= #TP 1'b0;

//latch rcvd eios for Rx L0s when ltssm is in S_L0 or S_L0S (Tx is in L0s)
//clear it when ltssm is in S_RCVRY_LOCK (L0->Rcvry or L0->L1->Rcvry or L0->L0s->Rcvry), in S_DETECT_QUIET (L0->L2->Detect), clr_l0s_rcv (Rx.L0s state transition)
//So Tx.L0s transition doesn't affect the clear
always @( posedge core_clk or negedge core_rst_n ) begin : smlh_pm_latched_eidle_set_PROC
    if ( !core_rst_n )
        latched_rcvd_eidle_set_4rl0s  <= #TP 1'b0;
    else if ( rmlh_rcvd_eidle_set && (lts_state==S_L0S || lts_state==S_L0 || lts_state==S_RCVRY_IDLE || lts_state==S_CFG_IDLE) )
        latched_rcvd_eidle_set_4rl0s  <= #TP 1'b1;
        // S_RCVRY_IDLE to next HotReset/Disable/Loopback/PreDetectQuiet -> S_DETECT_QUIET, RecoveryLock/CfgLinkwdithStart, can be cleared
        // S_CFG_IDLE to next S_RCVRY_LOCK, PreDetectQuiet->S_DETECT_QUIET, can be cleared
        // S_L0S to next PreDetectQuiet->S_DETECT_QUIET, S_RCVRY_LOCK, can be cleared
        // S_L0S is Tx.L0s, after receiving rmlh_rcvd_eidle_set, move to Rx.L0s -> (l0s_rcv_idle ^ r_l0s_rcv_idle), can be cleared
        // S_L0S is Rx.L0s, any time receiving rmlh_rcvd_eidle_set, and parallel skp -> L0 -> latched_rcvd_eidle_set_4rl0s -> Rx.L0s -> (l0s_rcv_idle ^ r_l0s_rcv_idle), can be cleared
        // S_L0 to next S_L123_SEND_EIDLE -> S_RCVRY_LOCK or S_DETECT_QUIET, S_RCVRY_LOCK, PreDetectQuiet->S_DETECT_QUIET, can be cleared
        // S_L0 to next latched_rcvd_eidle_set_4rl0s -> Rx.L0s -> (l0s_rcv_idle ^ r_l0s_rcv_idle), can be cleared
    else if ( lts_state==S_RCVRY_LOCK || lts_state==S_DETECT_QUIET || lts_state==S_CFG_LINKWD_START || (l0s_rcv_idle ^ r_l0s_rcv_idle) )
        latched_rcvd_eidle_set_4rl0s  <= #TP 1'b0;
end //smlh_pm_latched_eidle_set_PROC

always @(*) begin : current_l0s_receive_state_assignments
             case (r_curnt_l0s_rcv_state)
            S_L0S_RCV_IDLE: begin
                if (  !all_phy_mac_rxelecidle
                   )
                    curnt_l0s_rcv_state = S_L0S_RCV_FTS;
                else if (rcvr_l0s_goto_rcvry)
                    curnt_l0s_rcv_state = S_L0S_RCV_ENTRY;
                else
                    curnt_l0s_rcv_state = S_L0S_RCV_IDLE;
            end
            S_L0S_RCV_FTS: begin
                // According to spec, when phy is not in alignment, then we can not gurantee
                // the correctness of fts receiving.
                // timer here is caled as max skip interval + one NFTS,
                // using our core period = 1528/2 + 2,here we use 50us timer roughly for this.
                //for gen3, need detect sds received on all active lanes
                if (((latched_smlh_inskip_rcv ) & rmlh_deskew_complete) | timeout_nfts | rcvr_l0s_goto_rcvry)
                    curnt_l0s_rcv_state = S_L0S_RCV_ENTRY;
                // rcvd skip on all active lanes and the controller receives EIOS immediately (stored latched_rcvd_eidle_set_4rl0s), the rmlh_deskew_complete gets cleared.
                // the controller moves to L0 (S_L0S_RCV_ENTRY in Rx.L0s) regardless of rmlh_deskew_complete. Then LTSSM moves from L0 to L0s again after timeout_40ns_4rl0s
                // because latched_rcvd_eidle_set_4rl0s does not get cleared. 
                else if ( latched_smlh_inskip_rcv && latched_rcvd_eidle_set_4rl0s && (current_data_rate <= `GEN2_RATE) )
                    curnt_l0s_rcv_state = S_L0S_RCV_ENTRY;
                else
                    curnt_l0s_rcv_state = S_L0S_RCV_FTS;
            end

            default /*S_L0S_RCV_ENTRY*/: begin
                if (((lts_state == S_L0) & (latched_rcvd_eidle_set_4rl0s & timeout_40ns_4rl0s) & !l0_link_rcvry_en & !pm_smlh_prepare4_l123 & cfg_l0s_supported) // in l0 state
                     | ((lts_state == S_L0S) & (latched_rcvd_eidle_set_4rl0s & timeout_40ns_4rl0s) & !rcvr_l0s_goto_rcvry & cfg_l0s_supported)) // When xmtr in L0s state
                    curnt_l0s_rcv_state =  S_L0S_RCV_IDLE;
                else
                    curnt_l0s_rcv_state =  S_L0S_RCV_ENTRY;

            end
        endcase
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        r_curnt_l0s_rcv_state <= #TP S_L0S_RCV_ENTRY;
    else
        r_curnt_l0s_rcv_state <= #TP curnt_l0s_rcv_state;


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rcvr_l0s_goto_rcvry <= #TP 0;
    end else begin
        rcvr_l0s_goto_rcvry <= #TP (lts_state == S_RCVRY_LOCK) ? 1'b0
                                   : (((r_curnt_l0s_rcv_state == S_L0S_RCV_FTS) & timeout_nfts)               // when nfts timeout at rcv L0s state
                                     | (l0s_link_rcvry_en & ((lts_state == S_L0) | (lts_state == S_L0S)))   // when training sequence received before rcvr at L0s state
                                     | ((r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY) & (curnt_l0s_xmt_state != S_L0S_XMT_ENTRY)
                                         & smlh_eidle_inferred))
                                     ? 1'b1
                                    : rcvr_l0s_goto_rcvry;
    end


// ------------------------------------------
// PowerDown outputs for PIPE phy
always @(next_lts_state or curnt_l0s_xmt_state or ltssm_powerdown or eiexit_hs_in_progress)
begin

         case(next_lts_state)
        S_L0S:  next_ltssm_powerdown = ((curnt_l0s_xmt_state == S_L0S_XMT_WAIT) | (curnt_l0s_xmt_state == S_L0S_XMT_IDLE)) ? `P0S : `P0;

        S_DISABLED,
        S_DETECT_QUIET,
        S_DETECT_WAIT,
        S_DETECT_ACT,
        S_L1_IDLE:      begin
                          if(!(|eiexit_hs_in_progress)) next_ltssm_powerdown = `P1;
                          else                          next_ltssm_powerdown = ltssm_powerdown;
                        end

        S_L2_IDLE,
        S_L2_WAKE :     next_ltssm_powerdown = `P2;

        S_PRE_DETECT_QUIET : next_ltssm_powerdown = ltssm_powerdown;

        default :       next_ltssm_powerdown = `P0;
    endcase
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        ltssm_powerdown          <= #TP `P1;
    end else if (!clear) begin
        ltssm_powerdown          <= #TP next_ltssm_powerdown;
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        smlh_in_l0s     <= #TP 1'b0;
        smlh_in_rl0s    <= #TP 1'b0;
        smlh_in_l0      <= #TP 1'b0;
        smlh_in_l1      <= #TP 1'b0;
        smlh_in_l23     <= #TP 1'b0;
        smlh_in_l0_l0s  <= #TP 1'b0;
    end else begin
        smlh_in_l0s     <= #TP (curnt_l0s_xmt_state != S_L0S_XMT_ENTRY && curnt_l0s_xmt_state != S_L0S_XMT_EIDLE);
        smlh_in_rl0s    <= #TP (r_curnt_l0s_rcv_state != S_L0S_RCV_ENTRY);
        smlh_in_l1      <= #TP (lts_state == S_L1_IDLE);
        smlh_in_l0      <= #TP (lts_state == S_L0) || (lts_state == S_LPBK_ACTIVE && lpbk_master);
        smlh_in_l23     <= #TP (lts_state == S_L2_WAKE) | (lts_state == S_L2_IDLE);
        smlh_in_l0_l0s  <= #TP ((curnt_l0s_xmt_state != S_L0S_XMT_ENTRY) || (r_curnt_l0s_rcv_state != S_L0S_RCV_ENTRY) ||
                                (lts_state == S_L0) || (lts_state == S_LPBK_ACTIVE && lpbk_master));
    end


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        smlh_l123_eidle_timeout <= #TP 1'b0;
    end else begin
        if((lts_state == S_L123_SEND_EIDLE) && (!clear))
          smlh_l123_eidle_timeout <= #TP timeout_2ms;  // Set EIDLE timeout
        else if((lts_state == S_L1_IDLE) || (lts_state == S_L2_IDLE))
          smlh_l123_eidle_timeout <= #TP 1'b0;  // Clear timeout when L1/L2 is entered
        else
          smlh_l123_eidle_timeout <= #TP smlh_l123_eidle_timeout;
    end

//debug signals
assign  l0s_state = {curnt_l0s_xmt_state, r_curnt_l0s_rcv_state};
assign  ltssm_in_lpbk    = (lts_state == S_LPBK_ACTIVE || (~lpbk_master && lts_state == S_LPBK_EXIT));

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        r_ltssm_rcvr_err_rpt_en  <= #TP 0;
    else
        r_ltssm_rcvr_err_rpt_en  <= #TP
                (((ltssm == S_CFG_LINKWD_START) | (ltssm == S_CFG_LINKWD_ACEPT) | (ltssm == S_CFG_LANENUM_WAIT)
                | (ltssm == S_CFG_LANENUM_ACEPT) | (ltssm == S_CFG_COMPLETE) | (ltssm == S_CFG_IDLE & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set)) & smlh_link_up) ? 1'b1:
                ((ltssm == S_L0)              & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                (((ltssm == S_L0) | (ltssm == S_L0S)) & (r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY) & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set_4rl0s) ? 1'b1:
                ((ltssm == S_L123_SEND_EIDLE)   & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                ((ltssm == S_DISABLED_ENTRY)  & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                ((ltssm == S_DISABLED_IDLE)     & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                ((ltssm == S_HOT_RESET_ENTRY) & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                ((ltssm == S_HOT_RESET)       & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1
                : 1'b0;

//make sure ltssm_rcvr_err_rpt_en is low during Recovery state
always @( r_ltssm_rcvr_err_rpt_en or ltssm ) begin
  if ( ltssm == S_RCVRY_LOCK )
    ltssm_rcvr_err_rpt_en = 1'b0;
  else
    ltssm_rcvr_err_rpt_en = r_ltssm_rcvr_err_rpt_en;
end

// Link number is expected to be matched when LTSSM is not in LINKWD_START
// state of a upstream port. If upstream port received multiple link number
// on different lanes, it is expected to select one link number. This is
// the reason that we do not need to check whether or not link number
// matched
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_lnknum_match_dis  <= #TP 0;
    else
        smlh_lnknum_match_dis  <= #TP (ltssm == S_CFG_LINKWD_START) && cfg_upstream_port;

//
// START logic for generating the additional outputs for the EI interface
//

// Group1: EIOS received
assign smlh_debug_info_ei[0] = rmlh_rcvd_eidle_set;

// Group2: LTSSM is in a state that depends on rxelecidle==0 to exit
assign smlh_debug_info_ei[1]  = (lts_state == S_L1_IDLE); // LTSSM is in L1, with or without EIOS
assign smlh_debug_info_ei[2]  = (lts_state == S_L2_IDLE) || (lts_state == S_L2_WAKE); // LTSSM is in L2, with or without EIOS
assign smlh_debug_info_ei[3]  = (r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE); // LTSSM is in RxL0s, only possible with EIOS
assign smlh_debug_info_ei[4]  = (lts_state == S_DISABLED); // LTSSM is in Disabled, with or without EIOS
assign smlh_debug_info_ei[5]  = (lts_state == S_DETECT_QUIET); // LTSSM is in Detect.Quiet
assign smlh_debug_info_ei[6]  = (lts_state == S_POLL_ACTIVE); // LTSSM is in Polling.Active
assign smlh_debug_info_ei[7]  = (curnt_compliance_state == S_COMPL_TX_COMPLIANCE); // LTSSM is in Polling.Compliance transmitting compliance pattern

// Group3: LTSSM is in a state that depends on rxelecidle==1 to exit
assign smlh_debug_info_ei[8]  = (lts_state == S_L123_SEND_EIDLE); // LTSSM is transitioning into L1 or L2
assign smlh_debug_info_ei[9]  = (lts_state == S_DISABLED_IDLE); // LTSSM is transitioning into Disabled
assign smlh_debug_info_ei[10] = (lts_state == S_LPBK_ACTIVE) && !lpbk_master && (current_data_rate == `GEN1_RATE); // LTSSM is in Loopback.Active as a slave and Gen1
assign smlh_debug_info_ei[11] = (lts_state == S_POLL_ACTIVE); // LTSSM is in Polling.Active, note this is identical to bit [6], it is repeated for completeness

// Group4: LTSSM transitions with EI inferred from Table 4-11 in Base Spec.
assign smlh_debug_info_ei[12] = (lts_state_d == S_L0)            && (lts_state == S_RCVRY_LOCK)  && latched_eidle_inferred; // L0 -> Recovery with EI inferred, first row in base spec Table 4-11
assign smlh_debug_info_ei[13] = (lts_state_d == S_RCVRY_RCVRCFG) && (lts_state == S_RCVRY_SPEED) && latched_eidle_inferred; // Recovery.RcvrCfg -> Recovery.Speed with EI inferred, second row in base spec Table 4-11
assign smlh_debug_info_ei[14] = (lts_state == S_RCVRY_SPEED)                                     && smlh_eidle_inferred; // Recovery.Speed with EI inferred, third/fourth rows in base spec Table 4-11
assign smlh_debug_info_ei[15] = (lts_state == S_LPBK_ACTIVE) && !lpbk_master                     && smlh_eidle_inferred; // Loopback.Active as a slave with EI inferred, fifth row in base spec Table 4-11

//
// END logic for generating the additional outputs for the EI interface
//


function automatic compare_t_wd; //bit width = T_WD
    input [T_WD-1:0] timer;
    input [T_WD-1:0] value;

    begin
            compare_t_wd = timer == value;
    end
endfunction // compare_t_wd

function automatic compare_t_wd_p2; //bit width = T_WD plus 2
    input [T_WD+1:0] timer;
    input [T_WD+1:0] value;

    begin
            compare_t_wd_p2 = timer == value;
    end
endfunction // compare_t_wd_p2


function automatic compare_19; //bit width = 19
    input   [18:0] timer;
    input   [18:0] value;

    begin
            compare_19 = timer == value;
    end
endfunction // compare_19

function automatic compare_25; //bit width = 25
    input   [24:0] timer;
    input   [24:0] value;

    begin
            compare_25 = timer == value;
    end
endfunction // compare_25

`ifndef SYNTHESIS
wire    [(34*8)-1:0]    LTSSM;
wire    [(19*8)-1:0]    CURNT_L0S_RCV_STATE;
wire    [(15*8)-1:0]    CURNT_L0S_XMT_STATE;
wire    [(26*8)-1:0]    CURNT_COMPLIANCE_STATE;
wire    [(19*8)-1:0]    CURNT_LPBK_ENTRY_STATE;
wire    [(3*8)-1:0]     DIVIDER;

assign  DIVIDER = " / ";

assign  LTSSM= ( ltssm == S_DETECT_QUIET               ) ? "DETECT_QUIET"      :
               ( ltssm == S_DETECT_ACT                 ) ? "DETECT_ACT"        :
               ( ltssm == S_POLL_ACTIVE                ) ? "POLL_ACTIVE"       :
               ( ltssm == S_POLL_COMPLIANCE            ) ? "POLL_COMPLIANCE"   :
               ( ltssm == S_POLL_CONFIG                ) ? "POLL_CONFIG"       :
               ( ltssm == S_PRE_DETECT_QUIET           ) ? "PRE_DETECT_QUIET"  :
               ( ltssm == S_CFG_LINKWD_START           ) ? "CFG_LINKWD_START"  :
               ( ltssm == S_CFG_LINKWD_ACEPT           ) ? "CFG_LINKWD_ACEPT"  :
               ( ltssm == S_CFG_LANENUM_WAIT           ) ? "CFG_LANENUM_WAIT"  :
               ( ltssm == S_CFG_LANENUM_ACEPT          ) ? "CFG_LANENUM_ACEPT" :
               ( ltssm == S_CFG_COMPLETE               ) ? "CFG_COMPLETE"      :
               ( ltssm == S_CFG_IDLE                   ) ? "CFG_IDLE"          :
               ( ltssm == S_RCVRY_LOCK                 ) ? "RCVRY_LOCK"        :
               ( ltssm == S_RCVRY_SPEED                ) ? "RCVRY_SPEED"       :
               ( ltssm == S_RCVRY_RCVRCFG              ) ? "RCVRY_RCVRCFG"     :
               ( ltssm == S_RCVRY_IDLE                 ) ? "RCVRY_IDLE"        :
               ( ltssm == S_RCVRY_EQ0                  ) ? "RCVRY_EQ0"         :
               ( ltssm == S_RCVRY_EQ1                  ) ? "RCVRY_EQ1"         :
               ( ltssm == S_RCVRY_EQ2                  ) ? "RCVRY_EQ2"         :
               ( ltssm == S_RCVRY_EQ3                  ) ? "RCVRY_EQ3"         :
               ( ltssm == S_L0                         ) ? "L0"                :
               ( ltssm == S_L0S                        ) ? { CURNT_L0S_RCV_STATE, DIVIDER, CURNT_L0S_XMT_STATE }:
               ( ltssm == S_L123_SEND_EIDLE            ) ? "L123_SEND_EIDLE"   :
               ( ltssm == S_L1_IDLE                    ) ? "L1_IDLE"           :
               ( ltssm == S_L2_IDLE                    ) ? "L2_IDLE"           :
               ( ltssm == S_L2_WAKE                    ) ? "L2_WAKE"           :
               ( ltssm == S_DISABLED_ENTRY             ) ? "DISABLED_ENTRY"    :
               ( ltssm == S_DISABLED_IDLE              ) ? "DISABLED_IDLE"     :
               ( ltssm == S_DISABLED                   ) ? "DISABLED"          :
               ( ltssm == S_LPBK_ENTRY                 ) ? "LPBK_ENTRY"        :
               ( ltssm == S_LPBK_ACTIVE                ) ? "LPBK_ACTIVE"       :
               ( ltssm == S_LPBK_EXIT                  ) ? "LPBK_EXIT"         :
               ( ltssm == S_LPBK_EXIT_TIMEOUT          ) ? "LPBK_EXIT_TIMEOUT" :
               ( ltssm == S_HOT_RESET_ENTRY            ) ? "HOT_RESET_ENTRY"   :
               ( ltssm == S_HOT_RESET                  ) ? "HOT_RESET"         :
               ( ltssm == S_DETECT_WAIT                ) ? "DETECT_WAIT"       : "BOGUS";

assign  CURNT_COMPLIANCE_STATE =
               ( curnt_compliance_state == S_COMPL_IDLE             ) ? "S_COMPL_IDLE" :
               ( curnt_compliance_state == S_COMPL_ENT_TX_EIDLE     ) ? "S_COMPL_ENT_TX_EIDLE" :
               ( curnt_compliance_state == S_COMPL_ENT_SPEED_CHANGE ) ? "S_COMPL_ENT_SPEED_CHANGE" :
               ( curnt_compliance_state == S_COMPL_TX_COMPLIANCE    ) ? "S_COMPL_TX_COMPLIANCE" :
               ( curnt_compliance_state == S_COMPL_EXIT_TX_EIDLE    ) ? "S_COMPL_EXIT_TX_EIDLE" :
               ( curnt_compliance_state == S_COMPL_EXIT_SPEED_CHANGE) ? "S_COMPL_EXIT_SPEED_CHANGE" :
               ( curnt_compliance_state == S_COMPL_EXIT_IN_EIDLE    ) ? "S_COMPL_EXIT_IN_EIDLE" :
               ( curnt_compliance_state == S_COMPL_EXIT             ) ? "S_COMPL_EXIT" : "BOGUS";


assign  CURNT_LPBK_ENTRY_STATE =
               ( curnt_lpbk_entry_state == S_LPBK_ENTRY_IDLE    ) ? "S_LPBK_ENTRY_IDLE" :
               ( curnt_lpbk_entry_state == S_LPBK_ENTRY_ADV     ) ? "S_LPBK_ENTRY_ADV" :
               ( curnt_lpbk_entry_state == S_LPBK_ENTRY_EIDLE   ) ? "S_LPBK_ENTRY_EIDLE" :
               ( curnt_lpbk_entry_state == S_LPBK_ENTRY_TS      ) ? "S_LPBK_ENTRY_TS" : "BOGUS";

assign  CURNT_L0S_RCV_STATE =
               ( r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY    ) ? "L0S_RCV_ENTRY" :
               ( r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE     ) ? "L0S_RCV_IDLE" :
               ( r_curnt_l0s_rcv_state == S_L0S_RCV_FTS      ) ? "L0S_RCV_FTS" : "BOGUS";

assign  CURNT_L0S_XMT_STATE =
               ( curnt_l0s_xmt_state == S_L0S_XMT_ENTRY    ) ? "L0S_XMT_ENTRY" :
               ( curnt_l0s_xmt_state == S_L0S_XMT_WAIT     ) ? "L0S_XMT_WAIT" :
               ( curnt_l0s_xmt_state == S_L0S_XMT_IDLE     ) ? "L0S_XMT_IDLE" :
               ( curnt_l0s_xmt_state == S_L0S_XMT_FTS      ) ? "L0S_XMT_FTS" :
               ( curnt_l0s_xmt_state == S_L0S_EXIT_WAIT    ) ? "L0S_EXIT_WAIT" :
               ( curnt_l0s_xmt_state == S_L0S_XMT_EIDLE    ) ? "L0S_XMT_EIDLE" :  "Bogus";
`endif // SYNTHESIS




endmodule
