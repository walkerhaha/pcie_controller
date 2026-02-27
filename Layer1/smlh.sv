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
// ---    $DateTime: 2020/10/13 17:20:06 $
// ---    $Revision: #19 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh.sv#19 $
// -------------------------------------------------------------------------
// --- Module Description: State MAC Layer Handler
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module smlh
#(
    parameter INST              = 0,                                       // The uniquifying parameter for each port logic instance.
    parameter TSFD_WD           = `CX_TS_FIELD_CONTROL_WD,                 // Sym7,6,5,4,3,2,1
    parameter AW                = `CX_ANB_WD,                              // Width of the active number of bytes
    parameter NL                = `CX_NL,                                  // Max number of lanes supported
    parameter L2NL              = NL==1 ? 1 : `CX_LOGBASE2(NL),            // log2 number of NL
    parameter NB                = `CX_NB,                                  // Number of symbols (bytes) per clock cycle
    parameter NBK               = `CX_NBK,                                 // Number of symbols (bytes) per clock cycle for datak
    parameter NW                = `CX_PL_NW,                               // Number of 32-bit dwords handled by the datapath each clock.
    parameter T_WD              = 25 // timer bit width
)
(
    // -----------------------------------------------------------------------------
    // inputs
    // -----------------------------------------------------------------------------
    // LTSSM timer outputs routed to the top-level for verification usage
    input  [T_WD-1:0]                      smlh_fast_time_1ms,
    input  [T_WD-1:0]                      smlh_fast_time_2ms,
    input  [T_WD-1:0]                      smlh_fast_time_3ms,
    input  [T_WD-1:0]                      smlh_fast_time_4ms,
    input  [T_WD-1:0]                      smlh_fast_time_10ms,
    input  [T_WD-1:0]                      smlh_fast_time_12ms,
    input  [T_WD-1:0]                      smlh_fast_time_24ms,
    input  [T_WD-1:0]                      smlh_fast_time_32ms,
    input  [T_WD-1:0]                      smlh_fast_time_48ms,
    input  [T_WD-1:0]                      smlh_fast_time_100ms,
    input                                  core_clk,
    input                                  core_rst_n,
    input                                  cfg_ts2_lid_deskew,
    input                                  cfg_support_part_lanes_rxei_exit,
    input                                  cfg_elastic_buffer_mode,
    input                                  cfg_scramble_dis,               // cfg bit to disable scramble when asserted.
    input  [3:0]                           cfg_imp_num_lanes,
    input  [7:0]                           cfg_n_fts,                      // 8bits bus to specify the number of FTS we wish to receive for our receiver
    input                                  cfg_upstream_port,              // when asserted, indicates that this core function as a upstream port
    input                                  cfg_root_compx,                 // indicates that the current port is a root complext port
    input                                  cfg_link_dis,                   // cfg bit to disable link when asserted.
    input                                  cfg_link_retrain,               // cfg bit to force ltssm from l0 to recovery.
    input                                  cfg_lpbk_en,                    // cfg bit to enable loopback when asserted.
    input                                  cfg_reset_assert,               // cfg bit to reset link when asserted.
    input  [7:0]                           cfg_link_num,                   // 8 bit link number
    input  [5:0]                           cfg_forced_link_state,          // 5 bits to control manually transaction into each states.
    input  [3:0]                           cfg_forced_ltssm_cmd,
    input                                  cfg_force_en,
    input                                  cfg_fast_link_mode,
    input  [1:0]                           cfg_fast_link_scaling_factor,
    input                                  cfg_l0s_supported,              // if core implemented L0s, set to 1
    input  [5:0]                           cfg_link_capable,
    input                                  cfg_ext_synch,
    input                                  cfg_gen1_ei_inference_mode,
    input  [1:0]                           cfg_select_deemph_mux_bus,
    input  [`CX_LUT_PL_WD-1:0]             cfg_lut_ctrl,
    input  [6:0]                           cfg_rxstandby_control,
    input                                  cfg_polarity_mode,
    input                                  cfg_rx_8_ts1s,
    input                                  cfg_block_local_detect_eq_problem,
    input                                  cfg_rxstandby_handshake_policy,
    input                                  cfg_por_phystatus_mode,
    input  [3:0]                           cfg_p1_entry_policy,
    input                                  cfg_alt_protocol_enable,        // enable alternate protocol
    input                                  cfg_hw_autowidth_dis,           // Hardware auto width disable for upconfigure
    input  [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control,
    input                                  app_init_rst,                   // application wants to init a link hot reset to downstream port
    input                                  app_ltssm_enable,               // application signal to block the LTSSM link negotion due to application's readyness.
    input                                  pm_smlh_entry_to_l0s,
    input                                  pm_smlh_l0s_exit,
    input                                  pm_smlh_entry_to_l1,
    input                                  pm_smlh_l1_exit,
    input                                  pm_smlh_l23_exit,
    input                                  pm_smlh_entry_to_l2,
    input                                  pm_smlh_prepare4_l123,
    input                                  xdlh_smlh_start_link_retrain,
    input                                  rtlh_req_link_retrain,          // watch dog time out
    input   [1:0]                          rmlh_rcvd_idle,                 // RMLH block keeps track of the number of idle received continously.  Bit 0 indicates receiver received 8 continous idle symbol, bit1 indicates 1 idle receivd
    input                                  rmlh_all_sym_locked,            // symbol locked on all active lanes
    input                                  rmlh_rcvd_eidle_set,            // when asserted, it indicates that RPLH detected electric idle set received
    input   [NL-1:0]                       act_rmlh_rcvd_eidle_set,        // when asserted, it indicates that RPLH detected electric idle set received per lane
    input                                  rmlh_deskew_alignment_err,      // Lanes fell out of alignement
    input                                  rmlh_deskew_complete,           // Lanes are deskewed
    input   [NL-1:0]                       rpipe_rxaligned,
    input   [2:0]                          pm_current_data_rate_smlh_sqf,  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input   [2:0]                          pm_current_data_rate_smlh_lnk,  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input   [2:0]                          pm_current_data_rate_smlh_eq,   // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input   [2:0]                          pm_current_data_rate_ltssm,     // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input   [1:0]                          current_powerdown,              // PHY changed powerdown
    input   [(NL*NB*8)-1:0]                rpipe_rxdata,
    input   [(NL*NBK)-1:0]                 rpipe_rxdatak,
    input   [(NL*NB)-1:0]                  rpipe_rxerror_dup,
    input   [NL-1:0]                       rpipe_rxdata_dv,
    input   [NL-1:0]                       rpipe_rxelecidle,
    input   [NL-1:0]                       rpipe_rxdetected,               // From rmlh_pipe block. Indicates Receiver detected
    input                                  rpipe_rxdetect_done,            // Indicates Receiver detection complete
    input                                  rpipe_all_phystatus_deasserted, // All active receivers are de-asserting phystatus
    input   [NL-1:0]                       rpipe_rxskipremoved,
    input   [NL-1:0]                       phy_mac_phystatus,
    input   [NL-1:0]                       phy_mac_rxstandbystatus,
    input   [NL-1:0]                       phy_mac_rxelecidle_noflip,
    input   [NL-1:0]                       laneflip_lanes_active,          // Lane Flip-ed smlh_lanes_active
    input   [NL-1:0]                       laneflip_rcvd_eidle_rxstandby,  // Lane Flip-ed smlh_rcvd_eidle_rxstandby
    input    [NL-1:0]                      laneflip_pipe_turnoff,          // Indicates PIPE Turnoff
    input   [8:0]                          cfg_lane_en,                    // pre-determined number of lanes
    input                                  rmlh_pkt_start,                 // Indicates a STP or SDP was received
    input   [1:0]                          rdlh_dlcntrl_state,             // Data link layer state machine output
    //gates
    input                                  xmtbyte_skip_sent,
    input                                  xmtbyte_ts1_sent,
    input                                  xmtbyte_ts2_sent,
    input                                  xmtbyte_idle_sent,
    input                                  xmtbyte_eidle_sent,
    input                                  xmtbyte_fts_sent,
    input                                  xmtbyte_cmd_is_data,
    input                                  xmtbyte_txdata_dv,
    input    [(NL*NB*8)-1:0]               xmtbyte_txdata,
    input    [(NL*NBK)-1:0]                xmtbyte_txdatak,
    input    [NL-1:0]                      xmtbyte_txelecidle,             // Enable Transmitter Electical Idle
    input                                  xmtbyte_txdetectrx_loopback,    // Enable receiver detect (loopback)
    input    [10:0]                        xmtbyte_ts_pcnt,                // ts sent persistency count
    input                                  xmtbyte_ts_data_diff,           // current ts data different from previous
    input                                  xmtbyte_1024_ts_sent,           // 1024 ts sent in a state without persistency
    input                                  xmtbyte_spd_chg_sent,           // speed_change bit is set in a transmitted ts
    input                                  xmtbyte_dis_link_sent,          // disable link bit set in Tx TS

    input                                  pm_current_powerdown_p1,             // Indicate mac phy powerdown is in P1
    input                                  pm_current_powerdown_p0,             // Indicate mac phy powerdown is in P0
    // ---------------------------------------------------------------------------------------------------
    // outputs
    // ---------------------------------------------------------------------------------------------------
    output  [5:0]                          smlh_link_mode,
    output  [5:0]                          smlh_link_rxmode,
    output  [NL-1:0]                       smlh_lanes_active,
    output  [NL-1:0]                       lpbk_eq_lanes_active,
    output  [NL-1:0]                       smlh_no_turnoff_lanes,
    output                                 smlh_lnknum_match_dis,                // This signal is designed to notify the rmlh block when to enable link number match checking
    output                                 smlh_link_up,                         // when asserted, PLH link up.
    output                                 smlh_req_rst_not,                     // when asserted, LTSSM is in link down other than DISABLE,HOTRESET and LPBK state where a reset is required
    output                                 smlh_scrambler_disable,               // when asserted, scramble disabled.
    output                                 smlh_ltssm_in_pollconfig,
    output                                 smlh_training_rst_n,
    output                                 smlh_link_disable,
    output                                 smlh_link_in_training,
    output                                 smlh_bw_mgt_status,                   // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                                                 // without the port transitioning through DL_Down status
    output                                 smlh_link_auto_bw_status,             // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
                                                                                 // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
    output  [5:0]                          smlh_ltssm_next,
    output  [5:0]                          smlh_ltssm_last,                      // ltssm last state
    output  [NL-1:0]                       deskew_lanes_active,
    output  [2:0]                          mac_phy_rate,                         // 1=change speed to gen2, 2=change speed to gen3
    output  [NL-1:0]                       mac_phy_rxpolarity,                   // RCVR polarity indication to MAC
    output  [NL-1:0]                       mac_phy_rxstandby,                    // Controls whether the PHY RX is active
    output  [NL-1:0]                       smlh_rcvd_eidle_rxstandby,            // Rx EIOS for RxStandby
    output                                 smlh_dir_linkw_chg_rising_edge,       // clear cfg_directed_link_width_change
    output                                 smlh_ltssm_in_hotrst_dis_entry,
    output                                 smlh_mod_ts_rcvd,                     // modified ts received
    output                                 smlh_in_l0_l0s,                       // LTSSM is in L0 or L0s state
    output  [AW-1:0]                       active_nb,                            // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s
    output                                 smlh_do_deskew,                       // Indicate to the deskew block when it is valid to deskew
    output  [5:0]                          smlh_ltssm_state,                     // Current state of Link Training and Status State Machine
    output  [5:0]                          smlh_ltssm_state_xmlh,                // Current state of Link Training and Status State Machine
    output  [5:0]                          smlh_ltssm_state_rmlh,                // Current state of Link Training and Status State Machine
    output                                 smlh_in_l0s,
    output                                 smlh_in_rl0s,
    output                                 smlh_in_l0,
    output                                 smlh_in_l1,
    output                                 smlh_in_l1_p1,
    output                                 smlh_in_l23,
    output                                 smlh_l123_eidle_timeout,
    output  [4:0]                          smlh_ts_link_ctrl,                    // received TS1 or TS2 with this Link control in training sequence
    output                                 smlh_rcvd_lane_rev,                   // 1 bit. 1 means int_lane0 rcvd int_lane8; 0 means int_lane0 rcvd int_lane0
    output  [7:0]                          smlh_ts_link_num,                     // 8 bit link number
    output                                 smlh_ts_link_num_is_k237,             // Indicates whether or not received Kchar with k237
    output  [NL-1:0]                       smlh_lanes_rcving,                    // 8bits to indicates that the lane is receiving an ordered-set that is logicly correct
    output                                 smlh_ts_rcv_err,                      // When asserted, it indicates that the TS has violation in hear beat.
    output                                 smlh_ts1_rcvd,                        // when asserted, it indicates Received TS1 on all lanes that is part of multi-lane
    output                                 smlh_ts2_rcvd,                        // when asserted, it indicates Received TS2 on all lanes that is part of multi-lane
    output                                 smlh_inskip_rcv,                      // when asserted, it indicates the receiver is receiving skips on all lane
    output                                 smlh_ts_lane_num_is_k237,             // with k237; Bit7 to Bit0 is Lane number allowed value 0-31
    output                                 latched_rcvd_eidle_set,
    output                                 ltssm_rcvr_err_rpt_en,
    output                                 ltssm_clear,                          // ltssm clear
    output  [3:0]                          ltssm_cmd,
    output  [4:0]                          l0s_state,
    output                                 ltssm_ts_auto_change,
    output  [1:0]                          ltssm_powerdown,                      // powerdown from LTSSM to rmlh_pipe
    output  [7:0]                          ltssm_xlinknum,
    output  [NL-1:0]                       ltssm_xk237_4lannum,
    output  [NL-1:0]                       ltssm_xk237_4lnknum,
    output  [7:0]                          ltssm_ts_cntrl,                       // training sequence control
    output                                 ltssm_mod_ts,
    output                                 ltssm_ts_alt_protocol,
    output                                 ltssm_no_idle_need_sent,
    output  [55:0]                         ltssm_ts_alt_prot_info,
    output  [5:0]                          ltssm_cxl_enable, // {Multi-logical Dev, CXL 2.0, SyncHeader, Cache, Mem, IO}
    output  [23:0]                         ltssm_cxl_mod_ts_phase1_rcvd,          // Received Modified TS Data Phase1
    output                                 ltssm_cxl_retimers_pre_mismatched,   // Set CXL_Retimers_Present_Mismatched bit
    output                                 ltssm_cxl_flexbus_phase2_mismatched, // Set FlexBusEnableBits_Phase2_Mismatch bit
    output                                 cxl_mode_enable,  // Indicates whether the link should operate in CXL or PCIe mode
    output  [1:0]                          ltssm_cxl_ll_mod, // {driftbuffer, commonclock}
    output                                 ltssm_in_lpbk,
    output                                 ltssm_lpbk_master,
    output  [2:0]                          ltssm_eidle_cnt,                      // 4 bits, indicates how many EIOS sets to send before returning xmtbyte_eidle_sent.  0=1 EIOS, 1=2 EIOS, etc.
    output  [NL-1:0]                       ltssm_lpbk_slave_lut,                 // lane under test
    output  [7:0]                          muxed_n_fts,
    output  [7:0]                          latched_ts_nfts,
    output  [NL-1:0]                       smseq_ts1_rcvd_pulse_bus,             //
    output  [NL-1:0]                       smseq_ts2_rcvd_pulse_bus,
    output  [NL*4-1:0]                     smseq_loc_ts2_rcvd_bus,               // detect ts2
    output  [NL*4-1:0]                     smseq_in_skp_bus,                     // detect skp
    output  [NL-1:0]                       smseq_fts_skp_do_deskew_bus,          // detect fts->skp
    output  [`CX_INFO_EI_WD-1:0]           smlh_debug_info_ei,                   // Debug bus, provides internal status information related to electrical idle, see smlh_ltssm.v for bit field descriptions
    output  [L2NL-1:0]                     smlh_lane_flip_ctrl,
    output  [L2NL-1:0]                     latched_flip_ctrl,
    output  [4:0]                          lpbk_lane_under_test,
    output  [55:0]                         mod_ts_data_rcvd,
    output  [L2NL-1:0]                     ltssm_lane_flip_ctrl
);

// ---------------------------------------------------------------------------------------------------
// internal signals
// ---------------------------------------------------------------------------------------------------
localparam N_DELAY_GEN5_FPGA = 0;
wire                          ltssm_mod_ts_rx;
wire    [NL-1:0]              smseq_mod_ts1_rcvd_pulse_bus; // modified ts1
wire    [NL-1:0]              smseq_mod_ts2_rcvd_pulse_bus; // modified ts2
wire    [NL-1:0]              int_lpbk_slave_lut;
wire    [2:0]                 current_data_rate = pm_current_data_rate_smlh_lnk;
assign                        ltssm_lpbk_slave_lut = {NL{current_data_rate == `GEN5_RATE}} & int_lpbk_slave_lut;
wire    [5:0]                 smlh_ltssm_state_smlh_eq;
wire    [5:0]                 smlh_ltssm_state_smlh_sqf;
wire    [5:0]                 smlh_ltssm_state_smlh_lnk;
wire    [NL-1:0]              link_imp_lanes;
wire    [5:0]                 link_next_link_mode;            // intermediate active lane number
wire    [NL-1:0]              link_lanes_rcving;
wire                          link_latched_modts_support;
wire                          link_latched_mdfts_support;
wire                          link_latched_skipeq_enable;
wire                          link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd;
wire                          link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd;
wire                          link_latched_live_all_8_ts2_plinkn_planen_rcvd;
wire                          link_latched_live_all_8_ts_plinkn_planen_rcvd;
wire     [NL-1:0]             link_latched_live_any_8_ts_plinkn_planen_rcvd_bus;
wire                          link_latched_live_any_8_ts_plinkn_planen_rcvd;
wire                          link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd;
wire                          link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd;
wire                          link_latched_live_any_8_ts2_plinkn_planen_rcvd;
wire                          link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd;
wire                          link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd;
wire                          link_xmlh_16_ts2_sent_after_1_ts2_rcvd;
wire                          link_xmlh_16_ts1_sent;
wire                          link_latched_live_all_2_ts1_dis1_rcvd;
wire                          link_latched_live_all_2_ts1_lpbk1_rcvd;
wire     [NL-1:0]             link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd;
wire     [NL-1:0]             link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd;
wire                          link_latched_live_any_2_ts1_apn_rcvd;
wire     [55:0]               link_latched_live_any_2_ts1_apn_sym14_8_rcvd;
wire     [NL*56-1:0]          link_latched_live_all_8_ts2_apn_sym14_8_rcvd;
wire     [NL*56-1:0]          link_latched_live_all_1_ts2_apn_sym14_8_rcvd;
wire                          ltssm_ap_success;
assign                        mod_ts_data_rcvd = 0;
wire                          link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd;
wire                          link_any_2_ts1_linknmtx_planen_rcvd;
wire                          link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd;
wire                          link_any_2_ts1_dis1_rcvd;
wire                          link_latched_live_all_2_ts1_linkn_planen_rcvd;
wire                          link_any_2_ts1_linkn_planen_rcvd;
wire                          link_lane0_2_ts1_linkn_planen_rcvd;
wire                          link_lane0_2_ts1_linknmtx_rcvd;
wire                          link_lane0_2_ts1_linknmtx_lanen_rcvd;
wire                          link_latched_live_all_2_ts1_linknmtx_rcvd;
wire                          link_latched_live_all_2_ts1_linknmtx_lanen_rcvd;
wire                          link_latched_live_all_2_ts1_plinkn_planen_rcvd;
wire                          link_latched_live_lane0_2_ts1_lanen0_rcvd;
wire                          link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd;
wire                          link_latched_live_any_2_ts1_lanendiff_linkn_rcvd;
wire                          link_any_2_ts2_rcvd;
wire                          link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd;
wire                          link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd;
wire                          link_latched_live_all_ts1_spd_chg_0_rcvd;
wire                          link_latched_live_any_ts2_rcvd;
wire                          link_any_8_ts1_spd_chg_1_rcvd;
wire    [4:0]                 link_any_8_ts_spd_chg_1_data_rate;
wire                          int_directed_speed_change;
wire                          link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd;
wire                          link_any_8_ts_linknmtx_lanenmtx_rcvd;
wire                          link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          link_ln0_8_ts2_linknmtx_lanenmtx_rcvd;
wire                          link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd;
wire                          link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd;
wire                          link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd;
wire                          link_latched_live_any_8_std_ts2_spd_chg_1_rcvd;
wire                          link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                          smlh_link_up_falling_edge;
wire                          link_xmlh_32_ts2_spd_chg_1_sent;
wire                          link_xmlh_128_ts2_spd_chg_1_sent;
wire                          link_xmlh_16_ts2_sent_after_1_ts1_rcvd;
wire                          link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd;
wire                          link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd;
wire                          link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd;
wire                          link_any_2_ts1_hotreset1_rcvd;
wire                          link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd;
wire                          link_any_2_ts1_planen_rcvd;
wire                          link_any_2_ts1_lpbk1_rcvd;
wire                          link_imp_2_ts1_lpbk1_rcvd;
wire                          link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd;
wire                          link_any_2_ts_rcvd;
wire                          link_1_ts_rcvd;
wire                          link_any_1_ts_rcvd;
wire                          link_any_1_ts2_rcvd;
wire                          link_any_exact_1_ts_rcvd;
wire                          link_any_exact_2_ts_rcvd;
wire                          link_any_exact_4_ts_rcvd;
wire                          link_any_exact_5_ts_rcvd;
wire    [4:0]                 link_latched_ts_data_rate;
wire    [4:0]                 link_latched_ts_data_rate_ever;
wire                          link_latched_ts_spd_chg;
wire    [4:0]                 link_ts_data_rate;
wire                          link_ts_spd_chg;
wire    [4:0]                 link_lpbk_ts_data_rate;
wire    [4:0]                 link_latched_lpbk_ts_data_rate;
wire                          link_lpbk_ts_deemphasis;
wire    [7:0]                 link_ts_nfts;
wire                          link_latched_live_all_ts_scrmb_dis;
wire    [7:0]                 link_any_2_ts1_link_num;
wire    [NL-1:0]              link_mode_lanes_active;
wire    [NL-1:0]              link_2_ts1_plinkn_planen_rcvd_upconf;
wire                          link_any_ts2_rcvd;
wire                          link_latched_ts_retimer_pre;
wire                          ltssm_clear_eqctl;
wire                          ltssm_clear_seq;
wire                          ltssm_clear_link;
wire    [NL-1:0]              pre_link_imp_lanes;
wire    [5:0]                 pre_link_next_link_mode;            // intermediate active lane number
wire    [NL-1:0]              pre_link_lanes_rcving;
wire                          pre_link_latched_modts_support;
wire                          pre_link_latched_skipeq_enable;
wire                          pre_link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd;
wire                          pre_link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd;
wire                          pre_link_latched_live_all_8_ts2_plinkn_planen_rcvd;
wire                          pre_link_latched_live_all_8_ts_plinkn_planen_rcvd;
wire     [NL-1:0]             pre_link_latched_live_any_8_ts_plinkn_planen_rcvd_bus;
wire                          pre_link_latched_live_any_8_ts_plinkn_planen_rcvd;
wire                          pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd;
wire                          pre_link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd;
wire                          pre_link_latched_live_any_8_ts2_plinkn_planen_rcvd;
wire                          pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd;
wire                          pre_link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd;
wire                          pre_link_xmlh_16_ts2_sent_after_1_ts2_rcvd;
wire                          pre_link_xmlh_16_ts1_sent;
wire                          pre_link_latched_live_all_2_ts1_dis1_rcvd;
wire                          pre_link_latched_live_all_2_ts1_lpbk1_rcvd;
wire     [NL-1:0]             pre_link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd;
wire     [NL-1:0]             pre_link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd;
wire                          pre_link_latched_live_any_2_ts1_apn_rcvd;
wire     [55:0]               pre_link_latched_live_any_2_ts1_apn_sym14_8_rcvd;
wire     [NL*56-1:0]          pre_link_latched_live_all_8_ts2_apn_sym14_8_rcvd;
wire     [NL*56-1:0]          pre_link_latched_live_all_1_ts2_apn_sym14_8_rcvd;
wire                          pre_link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd;
wire                          pre_link_any_2_ts1_linknmtx_planen_rcvd;
wire                          pre_link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd;
wire                          pre_link_any_2_ts1_dis1_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linkn_planen_rcvd;
wire                          pre_link_any_2_ts1_linkn_planen_rcvd;
wire                          pre_link_lane0_2_ts1_linkn_planen_rcvd;
wire                          pre_link_lane0_2_ts1_linknmtx_rcvd;
wire                          pre_link_lane0_2_ts1_linknmtx_lanen_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linknmtx_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linknmtx_lanen_rcvd;
wire                          pre_link_latched_live_all_2_ts1_plinkn_planen_rcvd;
wire                          pre_link_latched_live_lane0_2_ts1_lanen0_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd;
wire                          pre_link_latched_live_any_2_ts1_lanendiff_linkn_rcvd;
wire                          pre_link_any_2_ts2_rcvd;
wire                          pre_link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd;
wire                          pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd;
wire                          pre_link_latched_live_all_ts1_spd_chg_0_rcvd;
wire                          pre_link_latched_live_any_ts2_rcvd;
wire                          pre_link_any_8_ts1_spd_chg_1_rcvd;
wire    [4:0]                 pre_link_any_8_ts_spd_chg_1_data_rate;
wire                          pre_int_directed_speed_change;
wire                          pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd;
wire                          pre_link_any_8_ts_linknmtx_lanenmtx_rcvd;
wire                          pre_link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          pre_link_ln0_8_ts2_linknmtx_lanenmtx_rcvd;
wire                          pre_link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          pre_link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd;
wire                          pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd;
wire                          pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd;
wire                          pre_link_latched_live_any_8_std_ts2_spd_chg_1_rcvd;
wire                          pre_link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                          pre_link_xmlh_32_ts2_spd_chg_1_sent;
wire                          pre_link_xmlh_128_ts2_spd_chg_1_sent;
wire                          pre_link_xmlh_16_ts2_sent_after_1_ts1_rcvd;
wire                          pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd;
wire                          pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd;
wire                          pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd;
wire                          pre_link_any_2_ts1_hotreset1_rcvd;
wire                          pre_link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd;
wire                          pre_link_any_2_ts1_planen_rcvd;
wire                          pre_link_any_2_ts1_lpbk1_rcvd;
wire                          pre_link_imp_2_ts1_lpbk1_rcvd;
wire                          pre_link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd;
wire                          pre_link_any_2_ts_rcvd;
wire                          pre_link_1_ts_rcvd;
wire                          pre_link_any_1_ts_rcvd;
wire                          pre_link_any_1_ts2_rcvd;
wire                          pre_link_any_exact_1_ts_rcvd;
wire                          pre_link_any_exact_2_ts_rcvd;
wire                          pre_link_any_exact_4_ts_rcvd;
wire                          pre_link_any_exact_5_ts_rcvd;
wire    [4:0]                 pre_link_latched_ts_data_rate;
wire    [4:0]                 pre_link_latched_ts_data_rate_ever;
wire                          pre_link_latched_ts_spd_chg;
wire    [4:0]                 pre_link_ts_data_rate;
wire                          pre_link_ts_spd_chg;
wire    [4:0]                 pre_link_lpbk_ts_data_rate;
wire    [4:0]                 pre_link_latched_lpbk_ts_data_rate;
wire                          pre_link_lpbk_ts_deemphasis;
wire    [7:0]                 pre_link_ts_nfts;
wire                          pre_link_latched_live_all_ts_scrmb_dis;
wire    [7:0]                 pre_link_any_2_ts1_link_num;
wire    [NL-1:0]              pre_link_mode_lanes_active;
wire    [NL-1:0]              pre_link_2_ts1_plinkn_planen_rcvd_upconf;
wire                          pre_link_any_ts2_rcvd;
wire                          pre_link_latched_ts_retimer_pre;
//--------
wire    [NL*4-1:0]            smseq_ts_rcvd_pcnt_bus;          // persistency count
wire    [NL*2-1:0]            smseq_ts_rcvd_cond_pcnt_bus;     // persistency count with conditions
wire    [NL*4-1:0]            smseq_ts_rcvd_mtx_pcnt_bus;      // persistency match Tx count
wire                          ltssm_directed_speed_change;
wire    [NL*TSFD_WD-1:0]      smseq_ts_info_bus;
wire    [NL*64-1:0]           smseq_mt_info_bus;
wire    [NL*2-1:0]            smseq_ts_lanen_linkn_pad_bus;
wire    [NL-1:0]              smlh_inskip_rcv_bus;
wire    [5:0]                 ltssm;
wire                          ltssm_lpbk_entry_send_ts1;
wire    [5:0]                 ltssm_last;
wire    [NL-1:0]              ltssm_lanes_active;
wire                          lpbk_eq;
wire                          lpbk_eq_n_lut_pset;
wire                          ltssm_in_pollconfig;
wire                          ltssm_state_is_rcvrylock;
wire                          lpbk_master;
wire    [7:0]                 current_n_fts;
wire    [NL-1:0]              smseq_ts1_rcvd_bus;
wire    [NL-1:0]              eqctl_rev_smlh_ts1_rcvd_bus;
wire    [NL-1:0]              eqctl_rev_rxdata_dv;
wire    [NL-1:0]              smseq_ts2_rcvd_bus;
wire    [NL-1:0]              eqctl_rev_smlh_ts2_rcvd_bus;
wire                          smlh_all_lannum_match;          // 1, all lane match
wire                          smlh_eidle_inferred;
wire    [7:0]                 smlh_ts_nfts;                   // 8 bits nfts number contained in training sequence
wire    [(NL*8)-1:0]          smlh_ts_link_num_bus;           // 8 bit link number per lane
wire    [NL-1:0]              smlh_sds_rcvd;                  // sds received by receiver
wire                          smlh_anylan_rcvd_atleast_1ts;   // any lane received at least 1 ts
wire                          smlh_2_lane_num_match;          // received 2 consecutive TSs with the same Lane #
wire    [NL-1:0]              smseq_sds_rcvd_bus;
wire    [NL-1:0]              smseq_ts_error_bus;
wire    [(NL*8)-1:0]          smseq_ts_link_num_bus;
wire    [(NL*8)-1:0]          smseq_ts_lane_num_bus;           // 8 bit lane nubmer (per lane)
wire    [NL-1:0]              smseq_ts_link_num_is_k237_bus;   // link number was K237
wire    [NL-1:0]              smseq_ts_lane_num_is_k237_bus;   // lane number was K237
wire    [(NL*8)-1:0]          smseq_ts_nfts_bus;               // 8 bits per lane
wire    [(NL*5)-1:0]          smseq_ts_link_ctrl_bus;          // 5 bits per lane
wire    [NL*4-1:0]            smseq_st_ts_rcvd_s6_pcnt;        // persistency count of Sym6
wire    [NL*4-1:0]            smseq_ts_rcvd_s6_pcnt;           // persistency count of Sym6
wire    [NL-1:0]              smseq_inskip_rcv_bus;
wire                          ltssm_in_hotrst_dis_entry;
wire                          ltssm_lane_flip_ctrl_chg_pulse;
wire [5:0]  cfg_target_link_width                    = cfg_pl_multilane_control[5:0];
wire        cfg_directed_link_width_change           = cfg_pl_multilane_control[6];
wire        cfg_upconfigure_support                  = cfg_pl_multilane_control[7];


assign      ltssm_lpbk_master                        = lpbk_master;

assign      muxed_n_fts                              = cfg_n_fts;
assign      smlh_ltssm_in_pollconfig                 = ltssm_in_pollconfig;
assign      smlh_lanes_active                        = ltssm_lanes_active;
assign      ltssm_state_is_rcvrylock                 = (smlh_ltssm_state_smlh_lnk == `S_RCVRY_LOCK);
assign      smlh_inskip_rcv                          = smlh_inskip_rcv_bus[0];


assign smlh_ltssm_in_hotrst_dis_entry = ltssm_in_hotrst_dis_entry;


assign smlh_ltssm_last = ltssm_last;

wire [55:0] ltssm_ts_alt_prot_info_i;
assign ltssm_ts_alt_prot_info = 0;

//LTSSM
smlh_ltssm

#(INST) u_smlh_ltssm (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_root_compx                 (cfg_root_compx),
    .cfg_n_fts                      (cfg_n_fts),
    .cfg_scrmb_dis                  (cfg_scramble_dis),
    .cfg_link_dis                   (cfg_link_dis),
    .cfg_select_deemph_mux_bus      (cfg_select_deemph_mux_bus),
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_reset_assert               (cfg_reset_assert),
    .cfg_link_num                   (cfg_link_num),
    .cfg_forced_ltssm               (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd           (cfg_forced_ltssm_cmd),

    .cfg_force_en                   (cfg_force_en),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_l0s_supported              (cfg_l0s_supported),
    .cfg_link_capable               (cfg_link_capable),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_rxstandby_handshake_policy (cfg_rxstandby_handshake_policy),
    .cfg_por_phystatus_mode         (cfg_por_phystatus_mode),
    .cfg_p1_entry_policy            (cfg_p1_entry_policy),
    .cfg_gointo_cfg_state           (1'b0),
    .cfg_link_retrain               (cfg_link_retrain),
    .app_init_rst                   (app_init_rst),
    .app_ltssm_enable               (app_ltssm_enable),

    // inputs from pm module
    .pm_smlh_entry_to_l0s           (pm_smlh_entry_to_l0s),
    .pm_smlh_entry_to_l1            (pm_smlh_entry_to_l1),
    .pm_smlh_entry_to_l2            (pm_smlh_entry_to_l2),
    .pm_smlh_prepare4_l123          (pm_smlh_prepare4_l123),
    .pm_smlh_l0s_exit               (pm_smlh_l0s_exit),
    .pm_smlh_l1_exit                (pm_smlh_l1_exit),
    .pm_smlh_l23_exit               (pm_smlh_l23_exit),

    .link_imp_lanes                                                               (link_imp_lanes),
    .link_next_link_mode                                                          (link_next_link_mode),
    .link_lanes_rcving                                                            (link_lanes_rcving),
    .link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd                   (link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd),
    .link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd                         (link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd),
    .link_latched_live_all_8_ts2_plinkn_planen_rcvd                               (link_latched_live_all_8_ts2_plinkn_planen_rcvd),
    .link_latched_live_all_8_ts_plinkn_planen_rcvd                                (link_latched_live_all_8_ts_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts_plinkn_planen_rcvd                              (link_latched_live_any_8_ts_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts_plinkn_planen_rcvd_bus                          (link_latched_live_any_8_ts_plinkn_planen_rcvd_bus),
    .link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd                 (link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd),
    .link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd                       (link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd),
    .link_latched_live_any_8_ts2_plinkn_planen_rcvd                             (link_latched_live_any_8_ts2_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd           (link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd),
    .link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd                                (link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd),
    .link_xmlh_16_ts2_sent_after_1_ts2_rcvd                                       (link_xmlh_16_ts2_sent_after_1_ts2_rcvd),
    .link_xmlh_16_ts1_sent                                                        (link_xmlh_16_ts1_sent),
    .link_latched_live_all_2_ts1_dis1_rcvd                                        (link_latched_live_all_2_ts1_dis1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_rcvd                                       (link_latched_live_all_2_ts1_lpbk1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd                                 (link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd                                 (link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd),
    .link_latched_live_any_2_ts1_apn_rcvd                                         (link_latched_live_any_2_ts1_apn_rcvd),
    .link_latched_live_any_2_ts1_apn_sym14_8_rcvd                                 (link_latched_live_any_2_ts1_apn_sym14_8_rcvd),
    .link_latched_live_all_8_ts2_apn_sym14_8_rcvd                                 (link_latched_live_all_8_ts2_apn_sym14_8_rcvd),
    .link_latched_live_all_1_ts2_apn_sym14_8_rcvd                                 (link_latched_live_all_1_ts2_apn_sym14_8_rcvd),
    .link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd                                (link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd),
    .link_any_2_ts1_linknmtx_planen_rcvd                                          (link_any_2_ts1_linknmtx_planen_rcvd),
    .link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd (link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd),
    .link_any_2_ts1_dis1_rcvd                                                     (link_any_2_ts1_dis1_rcvd),
    .link_latched_live_all_2_ts1_linkn_planen_rcvd                                (link_latched_live_all_2_ts1_linkn_planen_rcvd),
    .link_any_2_ts1_linkn_planen_rcvd                                             (link_any_2_ts1_linkn_planen_rcvd),
    .link_lane0_2_ts1_linkn_planen_rcvd                                           (link_lane0_2_ts1_linkn_planen_rcvd),
    .link_lane0_2_ts1_linknmtx_rcvd                                               (link_lane0_2_ts1_linknmtx_rcvd),
    .link_lane0_2_ts1_linknmtx_lanen_rcvd                                         (link_lane0_2_ts1_linknmtx_lanen_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_rcvd                                    (link_latched_live_all_2_ts1_linknmtx_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanen_rcvd                              (link_latched_live_all_2_ts1_linknmtx_lanen_rcvd),
    .link_latched_live_all_2_ts1_plinkn_planen_rcvd                               (link_latched_live_all_2_ts1_plinkn_planen_rcvd),
    .link_latched_live_lane0_2_ts1_lanen0_rcvd                                    (link_latched_live_lane0_2_ts1_lanen0_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd                           (link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd                  (link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd),
    .link_latched_live_any_2_ts1_lanendiff_linkn_rcvd                             (link_latched_live_any_2_ts1_lanendiff_linkn_rcvd),
    .link_any_2_ts2_rcvd                                                          (link_any_2_ts2_rcvd),
    .link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd                           (link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd                           (link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd                           (link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd               (link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd               (link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd                            (link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd                 (link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd                   (link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd),
    .link_latched_live_all_ts1_spd_chg_0_rcvd                                     (link_latched_live_all_ts1_spd_chg_0_rcvd),
    .link_latched_live_any_ts2_rcvd                                               (link_latched_live_any_ts2_rcvd),
    .link_any_8_ts1_spd_chg_1_rcvd                                                (link_any_8_ts1_spd_chg_1_rcvd),
    .link_any_8_ts_spd_chg_1_data_rate                                            (link_any_8_ts_spd_chg_1_data_rate),
    .link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd                  (link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd),
    .link_any_8_ts_linknmtx_lanenmtx_rcvd                                         (link_any_8_ts_linknmtx_lanenmtx_rcvd),
    .link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd                                (link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_ln0_8_ts2_linknmtx_lanenmtx_rcvd                                        (link_ln0_8_ts2_linknmtx_lanenmtx_rcvd),
    .link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd                               (link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd                               (link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd      (link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd                  (link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd                            (link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd                    (link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd),
    .link_latched_live_any_8_std_ts2_spd_chg_1_rcvd                               (link_latched_live_any_8_std_ts2_spd_chg_1_rcvd),
    .link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd                   (link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd),
    .link_xmlh_32_ts2_spd_chg_1_sent                                              (link_xmlh_32_ts2_spd_chg_1_sent),
    .link_xmlh_128_ts2_spd_chg_1_sent                                             (link_xmlh_128_ts2_spd_chg_1_sent),
    .link_xmlh_16_ts2_sent_after_1_ts1_rcvd                                       (link_xmlh_16_ts2_sent_after_1_ts1_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd                    (link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd          (link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd            (link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd),
    .link_any_2_ts1_hotreset1_rcvd                                                (link_any_2_ts1_hotreset1_rcvd),
    .link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd                              (link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd),
    .link_any_2_ts1_planen_rcvd                                                   (link_any_2_ts1_planen_rcvd),
    .link_any_2_ts1_lpbk1_rcvd                                                    (link_any_2_ts1_lpbk1_rcvd),
    .link_imp_2_ts1_lpbk1_rcvd                                                    (link_imp_2_ts1_lpbk1_rcvd),
    .link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd                                (link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd),
    .link_any_2_ts_rcvd                                                           (link_any_2_ts_rcvd),
    .link_1_ts_rcvd                                                               (link_1_ts_rcvd),
    .link_any_1_ts_rcvd                                                           (link_any_1_ts_rcvd),
    .link_any_1_ts2_rcvd                                                          (link_any_1_ts2_rcvd),
    .link_any_exact_1_ts_rcvd                                                     (link_any_exact_1_ts_rcvd),
    .link_any_exact_2_ts_rcvd                                                     (link_any_exact_2_ts_rcvd),
    .link_any_exact_4_ts_rcvd                                                     (link_any_exact_4_ts_rcvd),
    .link_any_exact_5_ts_rcvd                                                     (link_any_exact_5_ts_rcvd),
    .link_latched_ts_data_rate                                                    (link_latched_ts_data_rate),
    .link_latched_ts_data_rate_ever                                               (link_latched_ts_data_rate_ever),
    .link_latched_ts_spd_chg                                                      (link_latched_ts_spd_chg),
    .link_ts_data_rate                                                            (link_ts_data_rate),
    .link_ts_spd_chg                                                              (link_ts_spd_chg),
    .link_lpbk_ts_data_rate                                                       (link_lpbk_ts_data_rate),
    .link_latched_lpbk_ts_data_rate                                               (link_latched_lpbk_ts_data_rate),
    .link_lpbk_ts_deemphasis                                                      (link_lpbk_ts_deemphasis),
    .link_ts_nfts                                                                 (link_ts_nfts),
    .link_latched_live_all_ts_scrmb_dis                                           (link_latched_live_all_ts_scrmb_dis),
    .link_latched_modts_support                                                   (link_latched_modts_support),
    .link_latched_skipeq_enable                                                   (link_latched_skipeq_enable),
    .link_any_2_ts1_link_num                                                      (link_any_2_ts1_link_num),
    .link_2_ts1_plinkn_planen_rcvd_upconf                                         (link_2_ts1_plinkn_planen_rcvd_upconf),
    .link_latched_ts_retimer_pre                                                  (link_latched_ts_retimer_pre),

    .xmtbyte_ts_pcnt                                                              (xmtbyte_ts_pcnt),
    .xmtbyte_1024_ts_sent                                                         (xmtbyte_1024_ts_sent),
    .xmtbyte_dis_link_sent                                                        (xmtbyte_dis_link_sent),

    .smlh_lanes_rcving              (smlh_lanes_rcving),
    .smlh_eidle_inferred            (smlh_eidle_inferred),
    .smlh_inskip_rcv                (smlh_inskip_rcv_bus),
    .smlh_sds_rcvd                  (smlh_sds_rcvd),
    .rmlh_rcvd_idle                 (rmlh_rcvd_idle),
    .rmlh_all_sym_locked            (rmlh_all_sym_locked),
    .rmlh_rcvd_eidle_set            (rmlh_rcvd_eidle_set),
    .act_rmlh_rcvd_eidle_set        (act_rmlh_rcvd_eidle_set),
    .rmlh_deskew_alignment_err      (rmlh_deskew_alignment_err),
    .rmlh_deskew_complete           (rmlh_deskew_complete),
    .rpipe_rxaligned                (rpipe_rxaligned),
    .xdlh_smlh_start_link_retrain   (xdlh_smlh_start_link_retrain),
    .rtlh_req_link_retrain          (rtlh_req_link_retrain),
    .xmtbyte_ts1_sent               (xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent               (xmtbyte_ts2_sent),
    .xmtbyte_idle_sent              (xmtbyte_idle_sent),
    .xmtbyte_eidle_sent             (xmtbyte_eidle_sent),
    .xmtbyte_fts_sent               (xmtbyte_fts_sent),
    .xmtbyte_skip_sent              (xmtbyte_skip_sent),
    .xmtbyte_cmd_is_data            (xmtbyte_cmd_is_data),

    .current_data_rate              (pm_current_data_rate_ltssm),
    .current_powerdown              (current_powerdown),
    .phy_mac_rxelecidle             (rpipe_rxelecidle),
    .phy_mac_rxdetected             (rpipe_rxdetected),
    .phy_mac_rxdetect_done          (rpipe_rxdetect_done),
    .xmtbyte_txdetectrx_loopback    (xmtbyte_txdetectrx_loopback),
    .all_phystatus_deasserted       (rpipe_all_phystatus_deasserted),
    .phy_mac_rxstandbystatus        (phy_mac_rxstandbystatus),
    .phy_mac_rxelecidle_noflip      (phy_mac_rxelecidle_noflip),
    .laneflip_lanes_active          (laneflip_lanes_active),
    .laneflip_rcvd_eidle_rxstandby  (laneflip_rcvd_eidle_rxstandby),
    .laneflip_pipe_turnoff          (laneflip_pipe_turnoff),
    .cfg_lane_en                    (cfg_lane_en),
    .rmlh_pkt_start                 (rmlh_pkt_start),
    .cfg_rxstandby_control          (cfg_rxstandby_control),
    .cfg_lut_ctrl                   (cfg_lut_ctrl),

    .cfg_alt_protocol_enable        (cfg_alt_protocol_enable),
    .cfg_hw_autowidth_dis           (cfg_hw_autowidth_dis),
    .cfg_target_link_width          (cfg_target_link_width),
    .cfg_directed_link_width_change (cfg_directed_link_width_change),
    .cfg_upconfigure_support        (cfg_upconfigure_support),
    .xmtbyte_txelecidle             (xmtbyte_txelecidle),
    .rdlh_dlcntrl_state             (rdlh_dlcntrl_state),
    .pm_current_powerdown_p1        (pm_current_powerdown_p1),
    .pm_current_powerdown_p0        (pm_current_powerdown_p0),
// ---------------------------------outputs ------------------------
    .ltssm_lpbk_entry_send_ts1      (ltssm_lpbk_entry_send_ts1),
    .ltssm_cmd                      (ltssm_cmd),
    .smlh_link_up_falling_edge      (smlh_link_up_falling_edge),
    .ltssm_in_pollconfig            (ltssm_in_pollconfig),
    .smlh_link_up                   (smlh_link_up),
    .smlh_req_rst_not               (smlh_req_rst_not),
    .smlh_scrambler_disable         (smlh_scrambler_disable),
    .smlh_training_rst_n            (smlh_training_rst_n),
    .smlh_link_disable              (smlh_link_disable),
    .clear_o                        (ltssm_clear),
    .clear_eqctl                    (ltssm_clear_eqctl),
    .clear_seq                      (ltssm_clear_seq),
    .clear_link                     (ltssm_clear_link),
    .ltssm_rcvr_err_rpt_en          (ltssm_rcvr_err_rpt_en),
    .ltssm_xlinknum                 (ltssm_xlinknum),
    .ltssm_xk237_4lannum            (ltssm_xk237_4lannum),
    .ltssm_xk237_4lnknum            (ltssm_xk237_4lnknum),
    .ltssm_ts_cntrl                 (ltssm_ts_cntrl),
    .ltssm_mod_ts                   (ltssm_mod_ts),
    .ltssm_mod_ts_rx                (ltssm_mod_ts_rx),
    .ltssm_ts_alt_protocol          (ltssm_ts_alt_protocol),
    .ltssm_no_idle_need_sent        (ltssm_no_idle_need_sent),
    .ltssm_ts_alt_prot_info         (ltssm_ts_alt_prot_info_i),
    .ltssm_cxl_enable               (ltssm_cxl_enable),
    .ltssm_cxl_mod_ts_phase1_rcvd   (ltssm_cxl_mod_ts_phase1_rcvd),
    .ltssm_cxl_retimers_pre_mismatched (ltssm_cxl_retimers_pre_mismatched),
    .ltssm_cxl_flexbus_phase2_mismatched (ltssm_cxl_flexbus_phase2_mismatched),
    .cxl_mode_enable                (cxl_mode_enable),
    .ltssm_cxl_ll_mod               (ltssm_cxl_ll_mod),
    .ltssm_ap_success               (ltssm_ap_success),
    .ltssm_lanes_active             (ltssm_lanes_active),
    .lpbk_eq_lanes_active           (lpbk_eq_lanes_active),
    .lpbk_eq                        (lpbk_eq),
    .lpbk_eq_n_lut_pset             (lpbk_eq_n_lut_pset),
    .smlh_no_turnoff_lanes          (smlh_no_turnoff_lanes),
    .lpbk_master                    (lpbk_master),
    .deskew_lanes_active            (deskew_lanes_active),
    .smlh_lnknum_match_dis          (smlh_lnknum_match_dis),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .smlh_ltssm_state_smlh_eq       (smlh_ltssm_state_smlh_eq),
    .smlh_ltssm_state_smlh_sqf      (smlh_ltssm_state_smlh_sqf),
    .smlh_ltssm_state_smlh_lnk      (smlh_ltssm_state_smlh_lnk),
    .smlh_ltssm_state_rmlh          (smlh_ltssm_state_rmlh),
    .smlh_ltssm_state_xmlh          (smlh_ltssm_state_xmlh),
    .ltssm_next                     (smlh_ltssm_next),
    .ltssm_last                     (ltssm_last),
    .ltssm_powerdown                (ltssm_powerdown),
    .smlh_in_l0                     (smlh_in_l0),
    .smlh_in_l0s                    (smlh_in_l0s),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .smlh_in_l1                     (smlh_in_l1),
    .smlh_in_l1_p1                  (smlh_in_l1_p1),
    .smlh_in_l23                    (smlh_in_l23),
    .smlh_l123_eidle_timeout        (smlh_l123_eidle_timeout),
    .smlh_pm_latched_eidle_set      (latched_rcvd_eidle_set),
    .ltssm_in_lpbk                  (ltssm_in_lpbk),
    .ltssm_in_training              (smlh_link_in_training),
    .ltssm_eidle_cnt                (ltssm_eidle_cnt),
    .l0s_state                      (l0s_state),
    .smlh_bw_mgt_status             (smlh_bw_mgt_status),
    .smlh_link_auto_bw_status       (smlh_link_auto_bw_status),
    .smlh_link_mode                 (smlh_link_mode),
    .smlh_link_rxmode               (smlh_link_rxmode),
    .latched_ts_nfts                (latched_ts_nfts),
    .smlh_do_deskew                 (smlh_do_deskew),
    .mac_phy_rate                   (mac_phy_rate),
    .mac_phy_rxstandby              (mac_phy_rxstandby),
    .smlh_rcvd_eidle_rxstandby      (smlh_rcvd_eidle_rxstandby),
    .ltssm_ts_auto_change           (ltssm_ts_auto_change),
    .smlh_dir_linkw_chg_rising_edge (smlh_dir_linkw_chg_rising_edge),
    .current_n_fts                  (current_n_fts),
    .smlh_in_l0_l0s                 (smlh_in_l0_l0s),
    .active_nb                      (active_nb),
    .ltssm_lanes_active_d           (int_lpbk_slave_lut),        //lane under test for lpbk slave
    .ltssm_in_hotrst_dis_entry      (ltssm_in_hotrst_dis_entry),
    .smlh_debug_info_ei             (smlh_debug_info_ei),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),
    .latched_flip_ctrl              (latched_flip_ctrl),
    .lpbk_lane_under_test           (lpbk_lane_under_test),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .ltssm_lane_flip_ctrl           (ltssm_lane_flip_ctrl)
    ,
    .fast_time_1ms                  (smlh_fast_time_1ms),
    .fast_time_2ms                  (smlh_fast_time_2ms),
    .fast_time_3ms                  (smlh_fast_time_3ms),
    .fast_time_10ms                 (smlh_fast_time_10ms),
    .fast_time_12ms                 (smlh_fast_time_12ms),
    .fast_time_24ms                 (smlh_fast_time_24ms),
    .fast_time_32ms                 (smlh_fast_time_32ms),
    .fast_time_48ms                 (smlh_fast_time_48ms),
    .fast_time_100ms                (smlh_fast_time_100ms)
); //smlh_ltssm


// Layer1 Sequence Finder


wire    [(NL*NB)-1:0]  tmp_rpipe_rxdatak;
assign tmp_rpipe_rxdatak = rpipe_rxdatak;

// DSP moves to Cfg.Lanenum.wait and starts sending MOD TS while USP remains in Cfg.Linkwidth.Accept and may receive MOD TS. Gen5 Spec Errata
wire ltssm_mod_ts_rx_i = cfg_upstream_port ? ltssm_mod_ts_rx : ltssm_mod_ts;

smlh_seq_finder

#(INST) u_smlh_seq_finder (
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .smlh_link_up                   (smlh_link_up),
    .smlh_link_in_training          (smlh_link_in_training),
    .active_nb                      (active_nb),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .rxdata_dv                      (rpipe_rxdata_dv),
    .rxdata                         (rpipe_rxdata),
    .rxdatak                        (tmp_rpipe_rxdatak),
    .rxerror                        (rpipe_rxerror_dup),
    .rxskipremoved                  (rpipe_rxskipremoved),
    .rxaligned                      (rpipe_rxaligned),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_polarity_mode              (cfg_polarity_mode),
    .smlh_ltssm_state               (smlh_ltssm_state_smlh_sqf),
    .current_data_rate              (pm_current_data_rate_smlh_sqf),
    .ltssm_clear                    (ltssm_clear_seq),
    .ltssm_mod_ts                   (ltssm_mod_ts_rx_i),
    .xmtbyte_ts_pcnt                (xmtbyte_ts_pcnt),
    .xmtbyte_ts1_sent               (xmtbyte_ts1_sent),
    .xmtbyte_skip_sent              (xmtbyte_skip_sent),

// ---- outputs ---------------
    .smseq_ts_info                  (smseq_ts_info_bus),
    .smseq_mt_info                  (smseq_mt_info_bus),
    .smseq_ts_lanen_linkn_pad       (smseq_ts_lanen_linkn_pad_bus),
    .smseq_ts_rcvd_pcnt             (smseq_ts_rcvd_pcnt_bus),
    .smseq_ts_rcvd_cond_pcnt        (smseq_ts_rcvd_cond_pcnt_bus),
    .smseq_ts_rcvd_mtx_pcnt         (smseq_ts_rcvd_mtx_pcnt_bus),
    .smseq_ts_error                 (smseq_ts_error_bus),
    .smseq_inskip_rcv               (smseq_inskip_rcv_bus),
    .smseq_sds_rcvd                 (smseq_sds_rcvd_bus),
    .smseq_ts1_rcvd                 (smseq_ts1_rcvd_bus),
    .smseq_ts2_rcvd                 (smseq_ts2_rcvd_bus),
    .smseq_ts1_rcvd_pulse           (smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse           (smseq_ts2_rcvd_pulse_bus),
    .smseq_mod_ts1_rcvd_pulse       (smseq_mod_ts1_rcvd_pulse_bus),
    .smseq_mod_ts2_rcvd_pulse       (smseq_mod_ts2_rcvd_pulse_bus),
    .smseq_loc_ts2_rcvd             (smseq_loc_ts2_rcvd_bus),
    .smseq_in_skp                   (smseq_in_skp_bus),
    .smseq_fts_skp_do_deskew        (smseq_fts_skp_do_deskew_bus),
    .smseq_rcvr_pol_reverse         (mac_phy_rxpolarity)
); //smlh_seq_finder

//Layer1 Link
smlh_link
 #(INST) u_smlh_link(
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .lpbk_eq_lanes_active           (lpbk_eq_lanes_active),
    .smlh_lanes_active_i            (smlh_lanes_active),
    .smlh_link_mode_i               (smlh_link_mode),
    .ltssm_clear                    (ltssm_clear_link),
    .ltssm_mod_ts                   (ltssm_mod_ts_rx),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .ltssm_ts_data_rate             (5'b00000),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_imp_num_lanes              (cfg_imp_num_lanes),
    .cfg_rx_8_ts1s                  (cfg_rx_8_ts1s),
    .current_data_rate              (pm_current_data_rate_smlh_lnk),
    .smlh_ltssm_state               (smlh_ltssm_state_smlh_lnk),
    .smlh_link_up_falling_edge      (smlh_link_up_falling_edge),
    .smlh_link_up                   (smlh_link_up),
    .ltssm_xlinknum                 (ltssm_xlinknum),
    .ltssm_xk237_4lnknum            (ltssm_xk237_4lnknum),
    .ltssm_xk237_4lannum            (ltssm_xk237_4lannum),
    .ltssm_lpbk_entry_send_ts1      (ltssm_lpbk_entry_send_ts1),
    .smseq_ts_info_bus              (smseq_ts_info_bus),
    .smseq_mt_info_bus              (smseq_mt_info_bus),
    .smseq_ts_lanen_linkn_pad_bus   (smseq_ts_lanen_linkn_pad_bus),
    .smseq_ts_rcvd_pcnt_bus         (smseq_ts_rcvd_pcnt_bus),
    .smseq_ts_rcvd_cond_pcnt_bus    (smseq_ts_rcvd_cond_pcnt_bus),
    .smseq_ts_rcvd_mtx_pcnt_bus     (smseq_ts_rcvd_mtx_pcnt_bus),
    .xmtbyte_ts_pcnt                (xmtbyte_ts_pcnt),
    .xmtbyte_ts_data_diff           (xmtbyte_ts_data_diff),
    .xmtbyte_spd_chg_sent           (xmtbyte_spd_chg_sent),
    .xmtbyte_ts1_sent               (xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent               (xmtbyte_ts2_sent),
    .smseq_ts_error_bus             (smseq_ts_error_bus),
    .smseq_inskip_rcv_bus           (smseq_inskip_rcv_bus),
    .smseq_sds_rcvd_bus             (smseq_sds_rcvd_bus),
    .smseq_ts1_rcvd_bus             (smseq_ts1_rcvd_bus),
    .smseq_ts2_rcvd_bus             (smseq_ts2_rcvd_bus),
    .smseq_ts1_rcvd_pulse_bus       (smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse_bus       (smseq_ts2_rcvd_pulse_bus),
    .smseq_mod_ts1_rcvd_pulse_bus   (smseq_mod_ts1_rcvd_pulse_bus),
    .smseq_mod_ts2_rcvd_pulse_bus   (smseq_mod_ts2_rcvd_pulse_bus),
    .active_nb                      (active_nb),

// ---- outputs ---------------
    .link_imp_lanes                                                               (pre_link_imp_lanes),
    .link_next_link_mode                                                          (pre_link_next_link_mode),
    .link_lanes_rcving                                                            (pre_link_lanes_rcving),
    .link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd                   (pre_link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd),
    .link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd                         (pre_link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd),
    .link_latched_live_all_8_ts2_plinkn_planen_rcvd                               (pre_link_latched_live_all_8_ts2_plinkn_planen_rcvd),
    .link_latched_live_all_8_ts_plinkn_planen_rcvd                                (pre_link_latched_live_all_8_ts_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts_plinkn_planen_rcvd                              (pre_link_latched_live_any_8_ts_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts_plinkn_planen_rcvd_bus                          (pre_link_latched_live_any_8_ts_plinkn_planen_rcvd_bus),
    .link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd                 (pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd),
    .link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd                       (pre_link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd),
    .link_latched_live_any_8_ts2_plinkn_planen_rcvd                             (pre_link_latched_live_any_8_ts2_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd           (pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd),
    .link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd                                (pre_link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd),
    .link_xmlh_16_ts2_sent_after_1_ts2_rcvd                                       (pre_link_xmlh_16_ts2_sent_after_1_ts2_rcvd),
    .link_xmlh_16_ts1_sent                                                        (pre_link_xmlh_16_ts1_sent),
    .link_latched_live_all_2_ts1_dis1_rcvd                                        (pre_link_latched_live_all_2_ts1_dis1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_rcvd                                       (pre_link_latched_live_all_2_ts1_lpbk1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd                                 (pre_link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd                                 (pre_link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd),
    .link_latched_live_any_2_ts1_apn_rcvd                                         (pre_link_latched_live_any_2_ts1_apn_rcvd),
    .link_latched_live_any_2_ts1_apn_sym14_8_rcvd                                 (pre_link_latched_live_any_2_ts1_apn_sym14_8_rcvd),
    .link_latched_live_all_8_ts2_apn_sym14_8_rcvd                                 (pre_link_latched_live_all_8_ts2_apn_sym14_8_rcvd),
    .link_latched_live_all_1_ts2_apn_sym14_8_rcvd                                 (pre_link_latched_live_all_1_ts2_apn_sym14_8_rcvd),
    .link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd                                (pre_link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd),
    .link_any_2_ts1_linknmtx_planen_rcvd                                          (pre_link_any_2_ts1_linknmtx_planen_rcvd),
    .link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd (pre_link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd),
    .link_any_2_ts1_dis1_rcvd                                                     (pre_link_any_2_ts1_dis1_rcvd),
    .link_latched_live_all_2_ts1_linkn_planen_rcvd                                (pre_link_latched_live_all_2_ts1_linkn_planen_rcvd),
    .link_any_2_ts1_linkn_planen_rcvd                                             (pre_link_any_2_ts1_linkn_planen_rcvd),
    .link_lane0_2_ts1_linkn_planen_rcvd                                           (pre_link_lane0_2_ts1_linkn_planen_rcvd),
    .link_lane0_2_ts1_linknmtx_rcvd                                               (pre_link_lane0_2_ts1_linknmtx_rcvd),
    .link_lane0_2_ts1_linknmtx_lanen_rcvd                                         (pre_link_lane0_2_ts1_linknmtx_lanen_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_rcvd                                    (pre_link_latched_live_all_2_ts1_linknmtx_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanen_rcvd                              (pre_link_latched_live_all_2_ts1_linknmtx_lanen_rcvd),
    .link_latched_live_all_2_ts1_plinkn_planen_rcvd                               (pre_link_latched_live_all_2_ts1_plinkn_planen_rcvd),
    .link_latched_live_lane0_2_ts1_lanen0_rcvd                                    (pre_link_latched_live_lane0_2_ts1_lanen0_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd                           (pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd                  (pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd),
    .link_latched_live_any_2_ts1_lanendiff_linkn_rcvd                             (pre_link_latched_live_any_2_ts1_lanendiff_linkn_rcvd),
    .link_any_2_ts2_rcvd                                                          (pre_link_any_2_ts2_rcvd),
    .link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd                           (pre_link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd                           (pre_link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd                           (pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd               (pre_link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd               (pre_link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd                            (pre_link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd                 (pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd                   (pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd),
    .link_latched_live_all_ts1_spd_chg_0_rcvd                                     (pre_link_latched_live_all_ts1_spd_chg_0_rcvd),
    .link_latched_live_any_ts2_rcvd                                               (pre_link_latched_live_any_ts2_rcvd),
    .link_any_8_ts1_spd_chg_1_rcvd                                                (pre_link_any_8_ts1_spd_chg_1_rcvd),
    .link_any_8_ts_spd_chg_1_data_rate                                            (pre_link_any_8_ts_spd_chg_1_data_rate),
    .link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd                  (pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd),
    .link_any_8_ts_linknmtx_lanenmtx_rcvd                                         (pre_link_any_8_ts_linknmtx_lanenmtx_rcvd),
    .link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd                                (pre_link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_ln0_8_ts2_linknmtx_lanenmtx_rcvd                                        (pre_link_ln0_8_ts2_linknmtx_lanenmtx_rcvd),
    .link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd                               (pre_link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd                               (pre_link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd      (pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd                  (pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd                            (pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd                    (pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd),
    .link_latched_live_any_8_std_ts2_spd_chg_1_rcvd                               (pre_link_latched_live_any_8_std_ts2_spd_chg_1_rcvd),
    .link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd                   (pre_link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd),
    .link_xmlh_32_ts2_spd_chg_1_sent                                              (pre_link_xmlh_32_ts2_spd_chg_1_sent),
    .link_xmlh_128_ts2_spd_chg_1_sent                                             (pre_link_xmlh_128_ts2_spd_chg_1_sent),
    .link_xmlh_16_ts2_sent_after_1_ts1_rcvd                                       (pre_link_xmlh_16_ts2_sent_after_1_ts1_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd                    (pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd          (pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd            (pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd),
    .link_any_2_ts1_hotreset1_rcvd                                                (pre_link_any_2_ts1_hotreset1_rcvd),
    .link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd                              (pre_link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd),
    .link_any_2_ts1_planen_rcvd                                                   (pre_link_any_2_ts1_planen_rcvd),
    .link_any_2_ts1_lpbk1_rcvd                                                    (pre_link_any_2_ts1_lpbk1_rcvd),
    .link_imp_2_ts1_lpbk1_rcvd                                                    (pre_link_imp_2_ts1_lpbk1_rcvd),
    .link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd                                (pre_link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd),
    .link_any_2_ts_rcvd                                                           (pre_link_any_2_ts_rcvd),
    .link_1_ts_rcvd                                                               (pre_link_1_ts_rcvd),
    .link_any_1_ts_rcvd                                                           (pre_link_any_1_ts_rcvd),
    .link_any_1_ts2_rcvd                                                          (pre_link_any_1_ts2_rcvd),
    .link_any_exact_1_ts_rcvd                                                     (pre_link_any_exact_1_ts_rcvd),
    .link_any_exact_2_ts_rcvd                                                     (pre_link_any_exact_2_ts_rcvd),
    .link_any_exact_4_ts_rcvd                                                     (pre_link_any_exact_4_ts_rcvd),
    .link_any_exact_5_ts_rcvd                                                     (pre_link_any_exact_5_ts_rcvd),
    .link_latched_ts_data_rate                                                    (pre_link_latched_ts_data_rate),
    .link_latched_ts_data_rate_ever                                               (pre_link_latched_ts_data_rate_ever),
    .link_latched_ts_spd_chg                                                      (pre_link_latched_ts_spd_chg),
    .link_ts_data_rate                                                            (pre_link_ts_data_rate),
    .link_ts_spd_chg                                                              (pre_link_ts_spd_chg),
    .link_lpbk_ts_data_rate                                                       (pre_link_lpbk_ts_data_rate),
    .link_latched_lpbk_ts_data_rate                                               (pre_link_latched_lpbk_ts_data_rate),
    .link_lpbk_ts_deemphasis                                                      (pre_link_lpbk_ts_deemphasis),
    .link_ts_nfts                                                                 (pre_link_ts_nfts),
    .link_latched_live_all_ts_scrmb_dis                                           (pre_link_latched_live_all_ts_scrmb_dis),
    .link_latched_mdfts_support                                                   (smlh_mod_ts_rcvd),
    .link_latched_modts_support                                                   (pre_link_latched_modts_support),
    .link_latched_skipeq_enable                                                   (pre_link_latched_skipeq_enable),
    .link_any_2_ts1_link_num                                                      (pre_link_any_2_ts1_link_num),
    .link_mode_lanes_active                                                       (pre_link_mode_lanes_active),
    .link_2_ts1_plinkn_planen_rcvd_upconf                                         (pre_link_2_ts1_plinkn_planen_rcvd_upconf),
    .link_any_ts2_rcvd                                                            (pre_link_any_ts2_rcvd),
    .link_latched_ts_retimer_pre                                                  (pre_link_latched_ts_retimer_pre),
//--------
    .smlh_ts_link_ctrl              (smlh_ts_link_ctrl),        //for debug
    .smlh_rcvd_lane_rev             (smlh_rcvd_lane_rev),       //for debug
    .smlh_ts_link_num               (smlh_ts_link_num),         //for debug
    .smlh_ts_link_num_is_k237       (smlh_ts_link_num_is_k237), //for debug
    .smlh_ts_rcv_err                (smlh_ts_rcv_err),          //for debug
    .smlh_ts1_rcvd                  (smlh_ts1_rcvd),            //for debug
    .smlh_ts2_rcvd                  (smlh_ts2_rcvd),            //for debug
    .smlh_ts_lane_num_is_k237       (smlh_ts_lane_num_is_k237), //for debug
//--------

    .smlh_lanes_rcving              (smlh_lanes_rcving),
    .smlh_inskip_rcv                (smlh_inskip_rcv_bus),
    .smlh_sds_rcvd                  (smlh_sds_rcvd)
); //smlh_link

    assign  link_imp_lanes                                                      =   pre_link_imp_lanes ;
    assign  link_next_link_mode                                                 =   pre_link_next_link_mode ;
    assign  link_lanes_rcving                                                   =   pre_link_lanes_rcving;
    assign  link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd          =   pre_link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd ;
    assign  link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd                =   pre_link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd ;
    assign  link_latched_live_all_8_ts2_plinkn_planen_rcvd                      =   pre_link_latched_live_all_8_ts2_plinkn_planen_rcvd ;
    assign  link_latched_live_all_8_ts_plinkn_planen_rcvd                       =   pre_link_latched_live_all_8_ts_plinkn_planen_rcvd ;
    assign  link_latched_live_any_8_ts_plinkn_planen_rcvd                       =   pre_link_latched_live_any_8_ts_plinkn_planen_rcvd ;
    assign  link_latched_live_any_8_ts_plinkn_planen_rcvd_bus                   =   pre_link_latched_live_any_8_ts_plinkn_planen_rcvd_bus ;
    assign  link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd          =   pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd ;
    assign  link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd                =   pre_link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd ;
    assign  link_latched_live_any_8_ts2_plinkn_planen_rcvd                      =   pre_link_latched_live_any_8_ts2_plinkn_planen_rcvd ;
    assign  link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd    =   pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd ;
    assign  link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd                         =   pre_link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd ;
    assign  link_xmlh_16_ts2_sent_after_1_ts2_rcvd                              =   pre_link_xmlh_16_ts2_sent_after_1_ts2_rcvd ;
    assign  link_xmlh_16_ts1_sent                                               =   pre_link_xmlh_16_ts1_sent ;
    assign  link_latched_live_all_2_ts1_dis1_rcvd                               =   pre_link_latched_live_all_2_ts1_dis1_rcvd ;
    assign  link_latched_live_all_2_ts1_lpbk1_rcvd                              =   pre_link_latched_live_all_2_ts1_lpbk1_rcvd ;
    assign  link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd                        =   pre_link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd ;
    assign  link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd                        =   pre_link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd ;
    assign  link_latched_live_any_2_ts1_apn_rcvd                                =   pre_link_latched_live_any_2_ts1_apn_rcvd;
    assign  link_latched_live_any_2_ts1_apn_sym14_8_rcvd                        =   pre_link_latched_live_any_2_ts1_apn_sym14_8_rcvd;
    assign  link_latched_live_all_8_ts2_apn_sym14_8_rcvd                        =   pre_link_latched_live_all_8_ts2_apn_sym14_8_rcvd;
    assign  link_latched_live_all_1_ts2_apn_sym14_8_rcvd                        =   pre_link_latched_live_all_1_ts2_apn_sym14_8_rcvd;
    assign  link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd                       =   pre_link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd ;
    assign  link_any_2_ts1_linknmtx_planen_rcvd                                 =   pre_link_any_2_ts1_linknmtx_planen_rcvd ;
    assign  link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd    =   pre_link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd ;
    assign  link_any_2_ts1_dis1_rcvd                                            =   pre_link_any_2_ts1_dis1_rcvd ;
    assign  link_latched_live_all_2_ts1_linkn_planen_rcvd                       =   pre_link_latched_live_all_2_ts1_linkn_planen_rcvd ;
    assign  link_any_2_ts1_linkn_planen_rcvd                                    =   pre_link_any_2_ts1_linkn_planen_rcvd ;
    assign  link_lane0_2_ts1_linkn_planen_rcvd                                  =   pre_link_lane0_2_ts1_linkn_planen_rcvd ;
    assign  link_lane0_2_ts1_linknmtx_rcvd                                      =   pre_link_lane0_2_ts1_linknmtx_rcvd ;
    assign  link_lane0_2_ts1_linknmtx_lanen_rcvd                                =   pre_link_lane0_2_ts1_linknmtx_lanen_rcvd ;
    assign  link_latched_live_all_2_ts1_linknmtx_rcvd                           =   pre_link_latched_live_all_2_ts1_linknmtx_rcvd ;
    assign  link_latched_live_all_2_ts1_linknmtx_lanen_rcvd                     =   pre_link_latched_live_all_2_ts1_linknmtx_lanen_rcvd ;
    assign  link_latched_live_all_2_ts1_plinkn_planen_rcvd                      =   pre_link_latched_live_all_2_ts1_plinkn_planen_rcvd ;
    assign  link_latched_live_lane0_2_ts1_lanen0_rcvd                           =   pre_link_latched_live_lane0_2_ts1_lanen0_rcvd ;
    assign  link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd                  =   pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd         =   pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd ;
    assign  link_latched_live_any_2_ts1_lanendiff_linkn_rcvd                    =   pre_link_latched_live_any_2_ts1_lanendiff_linkn_rcvd ;
    assign  link_any_2_ts2_rcvd                                                 =   pre_link_any_2_ts2_rcvd ;
    assign  link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd                  =   pre_link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd                  =   pre_link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd                  =   pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd      =   pre_link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd      =   pre_link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd                   =   pre_link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd        =   pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd ;
    assign  link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd          =   pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd ;
    assign  link_latched_live_all_ts1_spd_chg_0_rcvd                            =   pre_link_latched_live_all_ts1_spd_chg_0_rcvd ;
    assign  link_latched_live_any_ts2_rcvd                                      =   pre_link_latched_live_any_ts2_rcvd ;
    assign  link_any_8_ts1_spd_chg_1_rcvd                                       =   pre_link_any_8_ts1_spd_chg_1_rcvd ;
    assign  link_any_8_ts_spd_chg_1_data_rate                                   =   pre_link_any_8_ts_spd_chg_1_data_rate ;
    assign  link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd         =   pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd ;
    assign  link_any_8_ts_linknmtx_lanenmtx_rcvd                                =   pre_link_any_8_ts_linknmtx_lanenmtx_rcvd ;
    assign  link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd                       =   pre_link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd ;
    assign  link_ln0_8_ts2_linknmtx_lanenmtx_rcvd                               =   pre_link_ln0_8_ts2_linknmtx_lanenmtx_rcvd ;
    assign  link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd                      =   pre_link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd ;
    assign  link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd                      =   pre_link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd ;
    assign  link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd =   pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd ;
    assign  link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd         =   pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd ;
    assign  link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd                   =   pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd           =   pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd ;
    assign  link_latched_live_any_8_std_ts2_spd_chg_1_rcvd                      =   pre_link_latched_live_any_8_std_ts2_spd_chg_1_rcvd ;
    assign  link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd          =   pre_link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd ;
    assign  link_xmlh_32_ts2_spd_chg_1_sent                                     =   pre_link_xmlh_32_ts2_spd_chg_1_sent ;
    assign  link_xmlh_128_ts2_spd_chg_1_sent                                    =   pre_link_xmlh_128_ts2_spd_chg_1_sent ;
    assign  link_xmlh_16_ts2_sent_after_1_ts1_rcvd                              =   pre_link_xmlh_16_ts2_sent_after_1_ts1_rcvd ;
    assign  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd           =   pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd ;
    assign  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd  =  pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd ;
    assign  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd   =   pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd ;
    assign  link_any_2_ts1_hotreset1_rcvd                                       =   pre_link_any_2_ts1_hotreset1_rcvd ;
    assign  link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd                     =   pre_link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd ;
    assign  link_any_2_ts1_planen_rcvd                                          =   pre_link_any_2_ts1_planen_rcvd ;
    assign  link_any_2_ts1_lpbk1_rcvd                                           =   pre_link_any_2_ts1_lpbk1_rcvd ;
    assign  link_imp_2_ts1_lpbk1_rcvd                                           =   pre_link_imp_2_ts1_lpbk1_rcvd ;
    assign  link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd                       =   pre_link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd ;
    assign  link_any_2_ts_rcvd                                                  =   pre_link_any_2_ts_rcvd ;
    assign  link_1_ts_rcvd                                                      =   pre_link_1_ts_rcvd ;
    assign  link_any_1_ts_rcvd                                                  =   pre_link_any_1_ts_rcvd ;
    assign  link_any_1_ts2_rcvd                                                 =   pre_link_any_1_ts2_rcvd ;
    assign  link_any_exact_1_ts_rcvd                                            =   pre_link_any_exact_1_ts_rcvd ;
    assign  link_any_exact_2_ts_rcvd                                            =   pre_link_any_exact_2_ts_rcvd ;
    assign  link_any_exact_4_ts_rcvd                                            =   pre_link_any_exact_4_ts_rcvd ;
    assign  link_any_exact_5_ts_rcvd                                            =   pre_link_any_exact_5_ts_rcvd ;
    assign  link_latched_ts_data_rate                                           =   pre_link_latched_ts_data_rate ;
    assign  link_latched_ts_data_rate_ever                                      =   pre_link_latched_ts_data_rate_ever ;
    assign  link_latched_ts_spd_chg                                             =   pre_link_latched_ts_spd_chg ;
    assign  link_ts_data_rate                                                   =   pre_link_ts_data_rate ;
    assign  link_ts_spd_chg                                                     =   pre_link_ts_spd_chg ;
    assign  link_lpbk_ts_data_rate                                              =   pre_link_lpbk_ts_data_rate ;
    assign  link_latched_lpbk_ts_data_rate                                      =   pre_link_latched_lpbk_ts_data_rate ;
    assign  link_lpbk_ts_deemphasis                                             =   pre_link_lpbk_ts_deemphasis ;
    assign  link_ts_nfts                                                        =   pre_link_ts_nfts ;
    assign  link_latched_live_all_ts_scrmb_dis                                  =   pre_link_latched_live_all_ts_scrmb_dis ;
    assign  link_latched_modts_support                                          =   pre_link_latched_modts_support ;
    assign  link_latched_skipeq_enable                                          =   pre_link_latched_skipeq_enable ;
    assign  link_any_2_ts1_link_num                                             =   pre_link_any_2_ts1_link_num ;
    assign  link_mode_lanes_active                                              =   pre_link_mode_lanes_active ;
    assign  link_2_ts1_plinkn_planen_rcvd_upconf                                =   pre_link_2_ts1_plinkn_planen_rcvd_upconf ;
    assign  link_any_ts2_rcvd                                                   =   pre_link_any_ts2_rcvd ;
    assign  link_latched_ts_retimer_pre                                         =   pre_link_latched_ts_retimer_pre ;

//Layer1 electrical Idle Inference
smlh_eidle_infer
 #(INST) u_smlh_eidle_infer(
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),


    .smlh_lanes_active              (smlh_lanes_active),
    .smlh_ltssm_state               (smlh_ltssm_state_smlh_lnk),
    .smseq_inskip_rcv               (smseq_inskip_rcv_bus),
    .smseq_ts1_rcvd_pulse           (smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse           (smseq_ts2_rcvd_pulse_bus),

    .rpipe_rxdata_dv                (rpipe_rxdata_dv),
    .rpipe_rxelecidle               (rpipe_rxelecidle),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_gen1_ei_inference_mode     (cfg_gen1_ei_inference_mode),
    .fast_time_4ms                  (smlh_fast_time_4ms[24:0]),

// ---- outputs ---------------
    .smlh_eidle_inferred            (smlh_eidle_inferred)
); //smlh_eidle_infer




endmodule

