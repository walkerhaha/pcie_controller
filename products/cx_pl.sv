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
// ---    $DateTime: 2020/10/14 06:27:23 $
// ---    $Revision: #17 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/cx_pl.sv#17 $
// -------------------------------------------------------------------------
// --- Module Description: PCI-Express Core (Layers 1,2, and 3)
// -----------------------------------------------------------------------------
// --- This module contains the complete CX-PL Port logic. Including Mac portion
// --- of the physical layer, the DataLink layer, and Transation layer.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/tx_lp_if.svh"
 
 module cx_pl (
    // System Information Interface
    cfg_p2p_track_cpl_to,

    pm_current_data_rate,
    core_clk,
    core_clk_ug,
    core_rst_n,
    app_init_rst,
    rstctl_core_flush_req,
    phy_type,
    app_ltssm_enable,
    smlh_training_rst_n,
    smlh_ltssm_state,
    smlh_lanes_active,
    smlh_no_turnoff_lanes,
    smlh_ltssm_in_config,
    cxpl_debug_info,
    cxpl_debug_info_ei,

    // XTLI Interface
    xadm_xtlh_soh,
    xadm_xtlh_hv,
    xadm_xtlh_hdr,
    xadm_xtlh_dv,
    xadm_xtlh_data,
    xadm_xtlh_dwen,
    xadm_xtlh_eot,
    xadm_xtlh_bad_eot,
    xadm_xtlh_add_ecrc,
    xadm_xtlh_vc,

    xtlh_xadm_halt,
    rtlh_parerr,
    rtlh_rfc_upd,
    rtlh_rfc_data,
    xtlh_xadm_restore_enable,
    xtlh_xadm_restore_capture,
    xtlh_xadm_restore_tc,
    xtlh_xadm_restore_type,
    xtlh_xadm_restore_word_len,

    // XTLH Completion Interface
    xtlh_xmt_tlp_done,
    xtlh_xmt_tlp_done_early,
    xtlh_xmt_tlp_req_id,
    xtlh_xmt_cfg_req,
    xtlh_xmt_memrd_req,
    xtlh_xmt_ats_req,
    xtlh_xmt_atomic_req,
    xtlh_xmt_tlp_attr,
    xtlh_xmt_tlp_tc,
    xtlh_xmt_tlp_tag,
    xtlh_xmt_tlp_len_inbytes,
    xtlh_xmt_tlp_first_be,

    // RTLI Interface
    radm_rtlh_ph_ca,
    radm_rtlh_pd_ca,
    radm_rtlh_nph_ca,
    radm_rtlh_npd_ca,
    radm_rtlh_cplh_ca,
    radm_rtlh_cpld_ca,
    rtlh_radm_dv,
    rtlh_radm_data,
    rtlh_radm_dwen,
    rtlh_radm_hv,
    rtlh_radm_hdr,
    rtlh_radm_eot,
    rtlh_radm_dllp_err,
    rtlh_radm_malform_tlp_err,
    rtlh_radm_ecrc_err,
    rtlh_radm_ant_addr,
    rtlh_radm_ant_rid,
    rtlh_radm_pending,

    // CDM and CXPL Interface (CCI)
    rmlh_rcvd_err,
    smlh_autoneg_link_width,
    smlh_autoneg_link_sp,
    smlh_link_training_in_prog,
    smlh_link_up,
    smlh_req_rst_not,
    rdlh_bad_tlp_err,
    rdlh_bad_dllp_err,
    rdlh_rtlh_link_state,
    rdlh_prot_err,
    xdlh_replay_num_rlover_err,
    xdlh_replay_timeout_err,
    xdlh_retrybuf_not_empty,
    rtlh_fc_init_status,
    rtlh_crd_not_rtn,
    xtlh_xmt_cpl_ca,
    xtlh_xmt_cpl_ur,
    xtlh_xmt_wreq_poisoned,
    xtlh_xmt_cpl_poisoned,
    cfg_endpoint,
    cfg_upstream_port,
    cfg_root_compx,
    cfg_dll_lnk_en,
    cfg_ack_freq,
    cfg_ack_latency_timer,
    cfg_replay_timer_value,
    cfg_fc_latency_value,
    cfg_other_msg_payload,
    cfg_other_msg_request,
    cfg_corrupt_crc_pattern,
    cfg_flow_control_disable,
    cfg_acknack_disable,
    cfg_scramble_dis,
    cfg_n_fts,
    cfg_link_dis,
    cfg_lpbk_en,
    cfg_link_num,
    cfg_ts2_lid_deskew,
    cfg_support_part_lanes_rxei_exit,
    cfg_forced_link_state,
    cfg_forced_ltssm_cmd,
    cfg_force_en,
    cfg_fast_link_mode,
    cfg_fast_link_scaling_factor,
    cfg_l0s_supported,
    cfg_link_capable,
    cfg_lane_skew,
    cfg_deskew_disable,
    cfg_imp_num_lanes,
    cfg_elastic_buffer_mode,
    cfg_skip_interval,
    cfg_ext_synch,
    cfg_hw_autowidth_dis,
    cfg_max_payload,
    cfg_tc_enable      ,
    cfg_vc_enable,
    cfg_vc_struc_vc_id_map,
    cfg_vc_id_vc_struc_map,
    cfg_tc_struc_vc_map,
    cfg_reset_assert,
    cfg_link_retrain,
    cfg_fc_wdog_disable,
    cfg_fc_credit_ph,
    cfg_fc_credit_nph,
    cfg_fc_credit_cplh,
    cfg_fc_credit_pd,
    cfg_fc_credit_npd,
    cfg_fc_credit_cpld,
    cfg_pipe_garbage_data_mode,
    device_type,           
    // PMC and CXPL Interface (CPI)
    xdlh_nodllp_pending,
    xdlh_no_acknak_dllp_pending,
    xdlh_xmt_pme_ack,
    xdlh_last_pmdllp_ack,
    xdlh_not_expecting_ack,
    rdlh_rcvd_pm_enter_l1,
    rdlh_rcvd_pm_enter_l23,
    rdlh_rcvd_pm_req_ack,
    rdlh_rcvd_as_req_l1,
    rdlh_link_up,
    rdlh_link_down,
    xtlh_tlp_pending,
    xdlh_tlp_pending,
    xdlh_retry_pending,
    xtlh_data_parerr,
    xadm_all_type_infinite,
    smlh_in_l0,
    smlh_in_l0s,
    smlh_in_rl0s,
    smlh_in_l1,
    smlh_in_l1_p1,
    smlh_in_l23,
    smlh_l123_eidle_timeout,
    latched_rcvd_eidle_set,
    rmlh_rcvd_eidle_set,
    xmlh_powerdown,
    pm_smlh_entry_to_l0s,
    pm_smlh_l0s_exit,
    pm_smlh_entry_to_l1,
    pm_smlh_l1_exit,
    pm_smlh_l23_exit,
    pm_smlh_entry_to_l2,
    pm_smlh_prepare4_l123,
    pm_xtlh_block_tlp,
    pm_freeze_fc_timer,
    pm_xdlh_enter_l1,
    pm_xdlh_req_ack,
    pm_xdlh_enter_l23,
    pm_xdlh_actst_req_l1,

    // PIPE Intertace
    mac_phy_txdata,
    mac_phy_txdatak,
    mac_phy_txdetectrx_loopback,
    mac_phy_txelecidle,
    mac_phy_txcompliance,
    mac_phy_rxpolarity,
    mac_phy_rxstandby,
    smlh_rcvd_eidle_rxstandby,
    phy_mac_rxdata,
    phy_mac_rxdatak,
    phy_mac_rxvalid,
    phy_mac_rxstatus,
    phy_mac_rxelecidle,
    phy_mac_phystatus,
    phy_mac_rxstandbystatus,
    phy_mac_rxelecidle_noflip,
    laneflip_lanes_active,
    laneflip_rcvd_eidle_rxstandby,
    laneflip_pipe_turnoff,
    cfg_lane_en,
    cfg_gen1_ei_inference_mode,
    cfg_select_deemph_mux_bus,
    cfg_lut_ctrl,
    cfg_rxstandby_control,

    smlh_bw_mgt_status,
    smlh_link_auto_bw_status,
    current_data_rate,
    pm_current_data_rate_others,
    mac_phy_rate,
    phy_mac_rxdatavalid,
    cfg_alt_protocol_enable,
    cfg_pl_multilane_control,

    smlh_dir_linkw_chg_rising_edge,
    smlh_ltssm_in_hotrst_dis_entry,
    smlh_mod_ts_rcvd,
    mod_ts_data_rcvd,
    mod_ts_data_sent,



    // Retry Buffer Interface (RBI)
    xdlh_retryram_addr,
    xdlh_retryram_data,
    xdlh_retryram_we,
    xdlh_retryram_en,
    xdlh_retryram_par_chk_val,
    xdlh_retryram_halt,
    retryram_xdlh_data,
    retryram_xdlh_depth,
    retryram_xdlh_parerr,


// Performance changes - 2p RAM I/F
 //   xdlh_retrysotram_addr,
    xdlh_retrysotram_waddr,
    xdlh_retrysotram_raddr,
    xdlh_retrysotram_data,
    xdlh_retrysotram_en,
    xdlh_retrysotram_we,
    xdlh_retrysotram_par_chk_val,
    retrysotram_xdlh_data,
    retrysotram_xdlh_depth,
    retrysotram_xdlh_parerr
   ,ltssm_cxl_enable
   ,ltssm_cxl_ll_mod
   ,drift_buffer_deskew_disable

    ,
    rtfcgen_ph_diff,
    rtlh_overfl_err,
    smlh_lane_flip_ctrl,
    lpbk_lane_under_test,
    ltssm_lane_flip_ctrl,
    xdlh_retry_req,
    pm_current_powerdown_p1,
    pm_current_powerdown_p0,
    xdlh_replay_timer,
    xdlh_rbuf_pkt_cnt,
    // Radm Formation Queue Overflow Prevention Mechanism 
    // LTSSM timer outputs routed to the top-level for verification usage
    smlh_fast_time_1ms,
    smlh_fast_time_2ms,
    smlh_fast_time_3ms,
    smlh_fast_time_4ms,
    smlh_fast_time_10ms,
    smlh_fast_time_12ms,
    smlh_fast_time_24ms,
    smlh_fast_time_32ms,
    smlh_fast_time_48ms,
    smlh_fast_time_100ms
  ,
  xdlh_match_pmdllp
  ,
  smlh_link_in_training
);


parameter   INST         = 0;                              // The uniquifying parameter for each port logic instance.
parameter   NL           = `CX_NL;                         // Wider Max number of lanes supported in Tx/Rx
parameter   L2NL         = NL==1 ? 1 : `CX_LOGBASE2(NL);   // log2 number of NL
parameter   TXNL         = `CM_TXNL;                       // Max Tx Lane Width in M-PCIe
parameter   RXNL         = `CM_RXNL;                       // Max Rx Lane Width in M-PCIe
parameter   NB           = `CX_NB;                         // Number of symbols (bytes) per clock cycle
parameter   NBK          = `CX_NBK;                        // Number of symbols (bytes) per clock cycle for datak
parameter   CM_NB        = `CM_NB;                         // Number of symbols (bytes) per clock cycle of M-PCIe
parameter   NW           = `CX_NW;                         // Number of 32-bit dwords handled by the datapath each clock.
parameter   PL_NW        = `CX_PL_NW;                      // Number of 32-bit dwords handled by the datapath each clock.
parameter   AW           = (`CX_NB == 16) ? 5 : 4;         // Width of active number symbols
parameter   DATA_PAR_WD  = `TRGT_DATA_PROT_WD;                // data bus parity width
parameter   DW_W_PAR     = (32*NW)+DATA_PAR_WD;            // Width of datapath in bits plus the parity bits.
parameter   DW_WO_PAR    = (32*NW);                        // Width of datapath in bits.
parameter   RAS_PCIE_HDR_PROT_WD = `CX_RAS_PCIE_HDR_PROT_WD;
parameter   TX_HW_W_PAR  = 128 + RAS_PCIE_HDR_PROT_WD;
parameter   DW           = (32*NW);                        // Width of datapath in bits.
parameter   PL_DW        = (32*PL_NW);                     // Width of datapath in bits.
parameter   NF           = `CX_NFUNC;                      // Number of functions
parameter   NVC          = `CX_NVC;                        // Number of virtual channels
parameter   L2N_INTFC    = 1;
parameter   RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1; // Max number of DLLPs received per cycle
parameter   TX_NDLLP     =  1;
// parameter   TX_NDLLP     = ((NB >= 2) & (NW>=4)) ? 2 : 1;  // Max number of DLLPs send per cycle
parameter   RX_TLP       = `CX_RX_TLP;                     // Number of TLPs that can be processed in a single cycle
parameter   DCAW         = `CX_LOGBASE2(NW/4+1);           // Number of bits needed to represent the maximum number 
                                                           // of Data CA returned from the radm (512:3, 256:2, 128 or below:1)
parameter   RBUF_WD      = `RBUF_WIDTH ;                   // 1 parity error bit per dword
parameter   RBUF_PW      = `RBUF_PW;
parameter   SOTBUF_WD    = `SOTBUF_WIDTH;
parameter   SOTBUF_DP    = `SOTBUF_DEPTH;                  // Indexed by sequence number (or some bits of it)
parameter   SOTBUF_PW    = `SOTBUF_L2DEPTH;                // Indexed by sequence number (or some bits of it)
parameter   TP           = `TP;                            // Clock to Q delay (simulator insurance)
parameter   DEVNUM_WD    = `CX_DEVNUM_WD;
localparam T_WD = 25; // timer bit width

// Interface Declarations
tx_lp_if b_xdlh_xplh();  // XDLH -> XPLH Transmit Interface
tx_lp_if b_xplh_xmlh();  // XPLH -> XMLH Transmit Interface






localparam HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
localparam DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;

localparam TAG_SIZE = `CX_TAG_SIZE;

localparam S_CFG_LINKWD_START     = `S_CFG_LINKWD_START;
localparam S_CFG_LINKWD_ACEPT     = `S_CFG_LINKWD_ACEPT;
localparam S_CFG_LANENUM_WAIT     = `S_CFG_LANENUM_WAIT;
localparam S_CFG_LANENUM_ACEPT    = `S_CFG_LANENUM_ACEPT;
localparam S_CFG_COMPLETE         = `S_CFG_COMPLETE;
localparam S_CFG_IDLE             = `S_CFG_IDLE;
localparam S_RCVRY_LOCK           = `S_RCVRY_LOCK;
localparam S_RCVRY_RCVRCFG        = `S_RCVRY_RCVRCFG;
localparam S_RCVRY_IDLE           = `S_RCVRY_IDLE;
localparam S_LPBK_ACTIVE          = `S_LPBK_ACTIVE;
localparam S_LPBK_EXIT            = `S_LPBK_EXIT;


localparam N_DELAY_GEN5_FPGA        = 0;

// -------------------------------------------------------------------------------------------
// Inputs
// -------------------------------------------------------------------------------------------

// START_IO:System Information Interface Signal Descriptions
input                       cfg_p2p_track_cpl_to;

input   [2:0]               pm_current_data_rate;           // current_data_rate shadowed in pm_ctrl
input                       core_clk;                       // Core clock
input                       core_clk_ug;                    // An ungated version of core_clk used to track phystatus during powerdown states
input                       core_rst_n;                     // When asserted, reset the core except for the PMC domain.
input                       app_init_rst;                   // N/A for end-point, used by downstream port of switch,
input                       rstctl_core_flush_req;
                                                            // which is initiated by upstream port
output                      smlh_training_rst_n;            // Hot reset from upstream component, routed to core_rst_n
                                                            // via reset tree
output  [5:0]               smlh_ltssm_state;               // Current LTSSM state. Intended to be used as debug information
output  [NL-1:0]            smlh_lanes_active;              // active lanes
output  [NL-1:0]            smlh_no_turnoff_lanes;          // upconfigure lanes
output                      smlh_ltssm_in_config;           // LTSSM is in configuration state
output  [63:0]              cxpl_debug_info;                // Debug bus provides internal status information
                                                            // cxpl_debug_info[63]    = smlh_scrambler_disable
                                                            // cxpl_debug_info[62]    = smlh_link_disable
                                                            // cxcp_debug_info[61]    = smlh_link_in_training
                                                            // cxpl_debug_info[60]    = smlh_ltssm_in_pollconfig
                                                            // cxpl_debug_info[59]    = smlh_training_rst_n
                                                            // cxpl_debug_info[58:55] = 4'b0
                                                            // cxpl_debug_info[54]    = mac_phy_txdetectrx_loopback[0]
                                                            // cxpl_debug_info[53]    = mac_phy_txelecidle[0]
                                                            // cxpl_debug_info[52]    = mac_phy_txcompliance[0]
                                                            // cxpl_debug_info[51]    = app_init_rst
                                                            // cxpl_debug_info[50:48] = 3'b0
                                                            // cxpl_debug_info[47:40] = smlh_ts_link_num
                                                            // cxpl_debug_info[39:38] = 2'b0
                                                            // cxpl_debug_info[37]    = xmtbyte_skip_sent
                                                            // cxpl_debug_info[36]    = smlh_link_up
                                                            // cxpl_debug_info[35]    = smlh_inskip_rcv
                                                            // cxpl_debug_info[34]    = smlh_ts1_rcvd
                                                            // cxpl_debug_info[33]    = smlh_ts2_rcvd,
                                                            // cxpl_debug_info[32]    = smlh_rcvd_lane_rev
                                                            // cxpl_debug_info[31:28] = smlh_ts_link_ctrl
                                                            // cxpl_debug_info[27]    = smlh_ts_lane_num_is_k237
                                                            // cxpl_debug_info[26]    = smlh_ts_link_num_is_k237
                                                            // cxpl_debug_info[25]    = rmlh_rcvd_idle[0]
                                                            // cxpl_debug_info[24]    = rmlh_rcvd_idle[1]
                                                            // cxpl_debug_info[23:8]  = mac_phy_txdata
                                                            // cxpl_debug_info[7:6]   = mac_phy_txdatak
                                                            // cxpl_debug_info[5:0]   = smlh_ltssm_state
output [`CX_INFO_EI_WD-1:0] cxpl_debug_info_ei;             // Debug bus, provides internal status information related to electrical idle
                                                            // See smlh_ltssm.v for bit field descriptions
// END_IO:System Information Interface Signal Descriptions

// START_IO:XTLI Interface Signal Descriptions
input                       xadm_xtlh_hv;                   // header valid on bus when asserted
input   [TX_HW_W_PAR-1:0]   xadm_xtlh_hdr;                  // header
input                       xadm_xtlh_dv;                   // Indicates that the data is valid when it is asserted. If a TLP
                                                            // contains data, then it will be asserted at the HDR valid cycle.
input   [DW_W_PAR-1:0]      xadm_xtlh_data;                 // TLP payload for 64/128-bit cores, and both payload and
                                                            // header for 32-bit core
                                                            // DW=32, 32-bit core
                                                            // DW=64, 64-bit core
                                                            // DW=128, 128-bit core
                                                            // It is valid when XADM_XTLH_DATA is asserted
input   [NW-1:0]            xadm_xtlh_dwen;                 // N/A to 32-bit core.
                                                            // Data bus DW enable, it is used to identify the location of the last
                                                            // DW when XADM_XTLH_EOT is asserted.
                                                            // NW=1, 32-bit core: this signal is not used
                                                            // NW=2, 64-bit core: NW is 2 bits
                                                            //      2'b01: the last DW is at DW0
                                                            //      2'b10: the last DW is at DW1
                                                            // NW=4, 128-bit core: NW is 4 bits
                                                            //       4'b0001: the last DW is at DW0
                                                            //       4'b0010: the last DW is at DW1
                                                            //       4'b0100: the last DW is at DW2
                                                            //       4'b1000: the last DW is at DW3

input [1:0]            xadm_xtlh_soh;         // Indicates start of header loacation for 32/64-bit
input                       xadm_xtlh_eot;                  // When asserted, indicates the end of current transaction
input                       xadm_xtlh_bad_eot;              // Append Bad EOT at the end of packet. It is only valid during EOT cycle.
input                       xadm_xtlh_add_ecrc;
input   [2:0]               xadm_xtlh_vc;                   // Virtual Channel Number for current transaction
                                                            // Default to 0 for VC0.
output                      xtlh_xadm_halt;                 // XADM is permitted to advance to next DW
output  [RX_NDLLP-1:0]      rtlh_rfc_upd;                   // FC update packet is received when it is asserted. NDLLP is the maximum
                                                            // number of DLLPs that can be received in one clock. It is 2 for the 128
                                                            // bit architectures, 1 for all others.
output  [RX_NDLLP*32-1:0]   rtlh_rfc_data;                  // FC packet data from RTLH, the data is valid when rtlh_rfc_upd is asserted.
output                      rtlh_parerr;
output                      xtlh_xadm_restore_enable;
output                      xtlh_xadm_restore_capture;
output  [2:0]               xtlh_xadm_restore_tc;
output  [6:0]               xtlh_xadm_restore_type;
output  [9:0]               xtlh_xadm_restore_word_len;
// END_IO:XTLI Interface Signal Descriptions

// START_IO:XTLH Completion Signal Descriptions
output                      xtlh_xmt_tlp_done;              // Indicates that a request required completion has been transmitted.
output                      xtlh_xmt_tlp_done_early;        // Unregistered version of xtlh_xmt_tlp_done
output  [15:0]              xtlh_xmt_tlp_req_id;            // Requester ID of the TLP
output                      xtlh_xmt_cfg_req;               // Indicates that this TLP is a configuration request.
output                      xtlh_xmt_memrd_req;             // Indicates that this TLP is a memory read

output                      xtlh_xmt_ats_req;             // Indicates that this TLP is a memory read
output                      xtlh_xmt_atomic_req;             // Indicates that this TLP is a memory read
output  [1:0]               xtlh_xmt_tlp_attr;              // Attributes of the TLP
output  [2:0]               xtlh_xmt_tlp_tc;                // TC of the TLP
output  [TAG_SIZE-1:0]      xtlh_xmt_tlp_tag;               // TAG of the TLP
output  [11:0]              xtlh_xmt_tlp_len_inbytes;       // The number of bytes in the TLP
output  [3:0]               xtlh_xmt_tlp_first_be;          // The first be of the TLP
// END_IO:XTLH Completion Signal Descriptions

// START_IO:RTLI Interface Signal Descriptions
input   [DCAW*NVC-1:0]      radm_rtlh_ph_ca;                // Credit allocated (posted header)
input   [DCAW*NVC-1:0]      radm_rtlh_pd_ca;                // Credit allocated (posted data)
input   [DCAW*NVC-1:0]      radm_rtlh_nph_ca;               // Credit allocated (non-posted header)
input   [DCAW*NVC-1:0]      radm_rtlh_npd_ca;               // Credit allocated (non-posted data)
input   [DCAW*NVC-1:0]      radm_rtlh_cplh_ca;              // Credit allocated (completion header)
input   [DCAW*NVC-1:0]      radm_rtlh_cpld_ca;              // Credit allocated (completion data)

output  [RX_TLP-1:0]        rtlh_radm_dv;                   // Data is valid this cycle
output  [DW_W_PAR-1:0]      rtlh_radm_data;                 // Receive TLP data Payload for 128-bit/64-bit cores, it contains
                                                            // both header and payload for 32-bit core
                                                            // DW=32, 32-bit core
                                                            // DW=64, 64-bit core
                                                            // DW=128, 128-bit core
output  [NW-1:0]            rtlh_radm_dwen;                 // Indicates the 1st DW location of the transaction
                                                            // 32-bit core: this signal is N/A
                                                            // 64-bit core: NW is 2 bits
                                                            //      2'b01: the last DW is at DW0
                                                            //      2'b10: the last DW is at DW1
                                                            // 128-bit core: NW is 4 bits
                                                            //       4'b0001: the last DW is at DW0
                                                            //       4'b0010: the last DW is at DW1
                                                            //       4'b0100: the last DW is at DW2
                                                            //       4'b1000: the last DW is at DW3
output  [RX_TLP-1:0]        rtlh_radm_hv;                   // Indicates that the header is valid when asserted. It is only used
                                                            // for 128-bit/64-bit cores, N/A for 32-bit core. For 32bit core,
                                                            // header and data shared the same data bus.
output  [RX_TLP*(128+RAS_PCIE_HDR_PROT_WD)-1:0]      rtlh_radm_hdr;     // Header Is valid when rtlh_radm_hv is asserted, it is only used for
                                                            // 128-bit/64-bit cores, N/A for 32-bit core
output  [RX_TLP-1:0]           rtlh_radm_eot;               // Indicates end of TLP
output  [RX_TLP-1:0]           rtlh_radm_dllp_err;          // Indicates that DLLP error is detected, this packet should not been
                                                            // added into the queue. It shall be asserted at the same cycle as the rtlh_radm_eot
output  [RX_TLP-1:0]           rtlh_radm_malform_tlp_err;   // Indicates that a malformed TLP is detected, this TLP should not been
                                                            // added to the queue. It is asserted at the same cycle as the rtlh_radm_eot.
                                                            // Malformed is detected under rules: Payload length mismatch, Maximum payload
                                                            // length overflow, unsupported TC, unsupported route of a message, malformed
                                                            // completion retry request for endpoint, invalid type.
output  [RX_TLP-1:0]           rtlh_radm_ecrc_err;          // Indicates that ECRC error is detected. It is asserted at the same cycle
                                                            // as the rtlh_radm_eot
output  [RX_TLP*64-1:0]     rtlh_radm_ant_addr;             // anticipated address (1 clock earlier)
output  [RX_TLP*16-1:0]     rtlh_radm_ant_rid;              // anticipated RID (1 clock earlier)
output                      rtlh_radm_pending;              // Transaction Layer has a TLP pending

// END_IO:RTLI Interface Signal Descriptions

// START_IO:CDM and CXPL Interface (CCI)
output                      rmlh_rcvd_err;                  // PHY receiving error reported from pipe interface
output  [5:0]               smlh_autoneg_link_width;        // negotiated link width
output  [3:0]               smlh_autoneg_link_sp;           // negotiated link speed
output                      smlh_link_training_in_prog;     // link training in progress
output                      smlh_link_up;                   // LTSSM link up
output                      smlh_req_rst_not;                   // when asserted, LTSSM is in link down other than DISABLE,HOTRESET and LPBK state where a reset is required
output                      rdlh_bad_tlp_err;               // Data link layer receive bad TLP error
output                      rdlh_bad_dllp_err;              // Data link layer receive bad DLLP error
output  [1:0]               rdlh_rtlh_link_state;           // Data link layer state machine output
output                      rdlh_prot_err;                  // Data link layer protocol error
output                      xdlh_replay_num_rlover_err;     // Data link layer transmit replay number rollover
output                      xdlh_replay_timeout_err;        // Data link layer transmit replay timeout
output                      xdlh_retrybuf_not_empty;        // Data link layer retry buffer not empty
output  [NVC-1:0]           rtlh_fc_init_status;            // FC init status. This signal indicates that FC control state machine
                                                            // is in FC init.
output  [NVC-1:0]           rtlh_crd_not_rtn;               // Flow Control credit not returned
output  [NF-1:0]            xtlh_xmt_cpl_ca;                // Core Transmitted a CPL TLP with completion abort status
output  [NF-1:0]            xtlh_xmt_cpl_ur;                // Core Transmitted a CPL TLP with unsupported request status
output  [NF-1:0]            xtlh_xmt_wreq_poisoned;         // Core Transmitted a memory write TLP with poison bit set
output  [NF-1:0]            xtlh_xmt_cpl_poisoned;          // Core Transmitted a completion TLP with poison bit set
input                       cfg_endpoint;                   // Endpoint device when it is high
input                       cfg_upstream_port;              // Upstream port when it is high
input                       cfg_root_compx;                 // Root complex port
input                       cfg_dll_lnk_en;                 // Data link layer link enabled when it is asserted. This is a debug
                                                            // feature. Default is 1. It enables data link control and management
                                                            // state machine.
input   [7:0]               cfg_ack_freq;                   // ACK frequency. It is the number of ACK that is allowed to coalesce when
                                                            // timer is not expired. Default is 1 which will enable ACK on every TLP received.
input   [15:0]              cfg_ack_latency_timer;          // ACK latency timer. Default value is expected to be chosen from table 3-5
                                                            // of Specification1.0a based on different application.
input   [16:0]              cfg_replay_timer_value;         // Replay Timer value.  Default value is expected to be chosen from table 3-4
                                                            // of Specification1.0a based on different application.
input   [12:0]              cfg_fc_latency_value;           // FC update latency timer value
input   [31:0]              cfg_other_msg_payload;          // Other MSG payload, for test equipment purpose. It is a way to allow a DLLP
                                                            // message being sent by CORE.
input                       cfg_other_msg_request;          // Other MSG request, for test equipment purpose. Control signal for the request.
input   [31:0]              cfg_corrupt_crc_pattern;        // Corrupted CRC pattern, for test equipment purpose. It carries corruption pattern.
input                       cfg_flow_control_disable;       // Disable flow control. This disables the flow control DLLP generation. It is
                                                            // for test/debug purpose. Default should be 0.
input                       cfg_acknack_disable;            // ACK/NACK disable. For test/debug purpose. Default is 0.
input                       cfg_scramble_dis;               // SCRAMBLER disable. For test/debug purpose. Default is 0.
input   [7:0]               cfg_n_fts;                      // Number of Fast training sequences. It is based on PHY implementation. Application
                                                            // should carefully choose this value.
input                       cfg_link_dis;                   // Link disable bit. This is used for downstream port that wants to start link
                                                            // disable transition. Software should set a bit in config space and then start
                                                            // link retraining. Default should be set to 0.
input                       cfg_lpbk_en;                    // Loop-back is enabled. This is used for a component in either side of link that
                                                            //wants to transition into loopback. Software should set a bit in config space
                                                            // and then start link retraining. Default should be set to 0.
input   [7:0]               cfg_link_num;                   // Link number (0 to 255), advertised to link partner if core is a downstream
                                                            // port. Default should be set to 0.
input                       cfg_ts2_lid_deskew;             // do deskew at the ts2->Logic_Idle_Data transition
input                       cfg_support_part_lanes_rxei_exit; // Polling.Active -> Polling.Config based on part of pre lanes rxei exit
input   [5:0]               cfg_forced_link_state;          // Move the link state to this value indicated. This is for testing purpose.
                                                            // Default should be set to 0.
input   [3:0]               cfg_forced_ltssm_cmd;
input                       cfg_force_en;                   // Force enable has to be a pulse signal generated from cfg block, when software
                                                            // writes. This is for testing purpose. Default should be set to 0.
input                       cfg_fast_link_mode;             // Fast link mode for simulation. This default value is 0 when core is placed in product.
input   [1:0]               cfg_fast_link_scaling_factor;   // Fast link timer scaling factor
input                       cfg_l0s_supported;              // if core implemented L0s, it is 1
input                       cfg_elastic_buffer_mode;        // 0 - nominal half full elastic buffer mode, 1 - empty mode
input   [5:0]               cfg_link_capable;               // It is application specific. It needs to be decided by application at implementation
                                                            // time. It indicates the x1, x2, x4 capability of a port. This is an output of
                                                            // PCIE spec. required config register.
input   [23:0]              cfg_lane_skew;                  // Transmit lane skew control (optional) for test equipment. Default should be 0.
input                       cfg_deskew_disable;             // Disable the automatic deskew function.
input   [3:0]               cfg_imp_num_lanes;              // implementation-specific number of lanes
input   [10:0]              cfg_skip_interval;              // Skip interval. It is recommended to follow spec to be in between 1180 to 1538 symbol
                                                            // times. Application should choose a value depended upon the 2s or 1s application.
                                                            // The default value for 1s setup is set to 0x500, 2s setup is 0x280.
input                       cfg_ext_synch;                  // Extended synch. This is only asserted if PHY is desired to have it. Otherwise,
                                                            // default is 0.
input                       cfg_hw_autowidth_dis     ;      // Hardware auto width disable for upconfigure
input   [2:0]               cfg_max_payload;                // MTU size. It is chosen by application. Default is 001 for 256Bytes.
input   [7:0]               cfg_tc_enable      ;            // Supported highest TC. Report error if received tc number is higher than this.
                                                            // Default is at 7. All TC traffic is supported.
input   [NVC-1:0]           cfg_vc_enable;                  // Per VC enable
input   [3*NVC-1:0]         cfg_vc_struc_vc_id_map;         // Virtual channel structure to virtual channel ID map.
input   [23:0]              cfg_vc_id_vc_struc_map;         // vc id to structure id map
input   [23:0]              cfg_tc_struc_vc_map;                  // Index by TC, returns VC
input                       cfg_reset_assert;               // Initiates a hot reset.
input                       cfg_link_retrain;               // Initiates link retraining.
input                       cfg_fc_wdog_disable;            // disable watch dog timer in FC for some debug purpose
input   [(NVC*8)-1:0]       cfg_fc_credit_ph;               // Posted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]       cfg_fc_credit_nph;              // Nonposted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]       cfg_fc_credit_cplh;             // Completion header Wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]      cfg_fc_credit_pd;               // Posted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]      cfg_fc_credit_npd;              // Nonposted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]      cfg_fc_credit_cpld;             // Completion data wire to control the FC initial value for FC credit advertisement
input                       cfg_pipe_garbage_data_mode;
input [3:0]                 device_type;
// END_IO:CDM and CXPL Interface (CCI)
input                       phy_type;                       // Phy type
input                       app_ltssm_enable;               // application signal to enable the LTSSM , if it is not enable, then LTSSM will be in DETECT QUIET
// START_IO:PMC and CXPL Interface (CPI)
output                      xdlh_nodllp_pending;            // XDLH has no dllp pending. It is a signal for PMC (power management module).
output                      xdlh_no_acknak_dllp_pending;    // XDLH has no ACK/NAK dllp pending. It is a signal for PMC (power management module).
output                      xdlh_xmt_pme_ack;               // XDLH sends acknowledgement to the requester (PMC) block to indicate a completion
output                      xdlh_last_pmdllp_ack;           // XDLH sends the last PM DLLP in a low power entry negotiation
                                                            // of a PME DLLP sent.
output                      xdlh_not_expecting_ack;         // Transmitter has received all its ACKs for all transmitted TLPs. It is a signal
                                                            // for PMC.
output                      rdlh_rcvd_pm_enter_l1;          // Rcvd DLLP PM_ENTER_L1
output                      rdlh_rcvd_pm_enter_l23;         // Rcvd DLLP PM_ENTER_L23
output                      rdlh_rcvd_pm_req_ack;           // Rcvd DLLP PM_REQ_ACK
output                      rdlh_rcvd_as_req_l1;            // Received AS REQ L1
output                      rdlh_link_up;                   // Data link layer is link up.
output                      rdlh_link_down;                 // Data link layer is link down.
output                      xtlh_tlp_pending;               // XTLH has TLP pending to be sent.
output                      xdlh_tlp_pending;               // XDLH has TLP pending to be sent.
output                      xdlh_retry_pending;             // XDLH has TLP pending to be sent or retry FSM is in the reply state
output                      xtlh_data_parerr;               // XTLH has detected data parrity error on the data bus
output                      smlh_in_l0;                     // LTSSM in l0
output                      smlh_in_l0s;                    // LTSSM Transmitter in l0s
output                      smlh_in_rl0s;                   // LTSSM Receiver in rL0s
output                      smlh_in_l1;                     // LTSSM  in L1
output                      smlh_in_l1_p1;                  // LTSSM  in L1 with powerdown P1
output                      smlh_in_l23;                    // LTSSM in L23
output                      smlh_l123_eidle_timeout;        // LTSSM 2ms Timer timed out while waiting for EIDLE
output                      latched_rcvd_eidle_set;         // That we have received an EIOS
output                      rmlh_rcvd_eidle_set;            // An EIDLE SET has been received.
output  [1:0]               xmlh_powerdown;                 // From LTSSM indicating power down state (P0/P0s/P1). P2 State is controlled by
                                                            // PMC module. This signal is routed to the PMC module and together with PMC's
                                                            // master state machine determines the output PIPE signal mac_phy_powerdown.
                                                            // When core is in AUX power state, PMC drives mac_phy_powerdown.  Otherwise,
                                                            // the LTSSM controls the power down state.
                                                            // When it is in L2 and L3 state, the LTSSM powerdown state is latched and
                                                            // maintained while core can be in reset/powerdown state.
input                       pm_smlh_entry_to_l0s;           // PMC directs LTSSM to entry to L0s
input                       pm_smlh_l0s_exit;               // PMC directs LTSSM to exit L0s
input                       pm_smlh_entry_to_l1;            // PMC directs LTSSM entry to L1
input                       pm_smlh_l1_exit;                // PMC directs LTSSM L1 EXIT
input                       pm_smlh_l23_exit;               // PMC directs LTSSM L23 EXIT
input                       pm_smlh_entry_to_l2;            // PMC directs LTSSM entry to L2
input                       pm_smlh_prepare4_l123;            // PMC directs LTSSM entry to L3
input                       pm_xtlh_block_tlp;              // PMC directs XTLH to block TLP
input                       pm_freeze_fc_timer;             // Freeze FC timer
input                       pm_xdlh_enter_l1;               // PMC signals XDLH to send ENTER_L1_DLLP. If power management is not supported,
                                                            // this signal should be set to 0.
input                       pm_xdlh_req_ack;                // PMC signals XDLH to send REQ_ACK_DLLP. If power management is not supported,
                                                            // this signal should be set to 0.
input                       pm_xdlh_enter_l23;              // PMC signals XDLH to send L23_DLLP. If power management is not supported, this
                                                            // signal should be set to 0.
input                       pm_xdlh_actst_req_l1;           // PMC signals XDLH to send AS_REQ_L1_DLLP. If power management is not supported,
                                                            // this signal should be set to 0.
input                       xadm_all_type_infinite;         // XADM FC book keeping block indicates that remote link advertised all FC credits to infinite.
// END_IO:PMC and CXPL Interface (CPI)


// START_IO:PIPE Signal Descriptions.
output  [(NL*NB*8)-1:0]     mac_phy_txdata;                 // Parallel transmit data. 1 or 2 bytes per lane.
output  [(NL*NB)-1:0]       mac_phy_txdatak;                // K character indication 1 or 2 bits per lane.
                                                            // Signals control character encoding to SDM.
output  [NL-1:0]            mac_phy_txdetectrx_loopback;    // Enable receiver detection sequence.  SerDes transmits
                                                            // receiver detection sequence or to begin loopback
output  [NL-1:0]            mac_phy_txelecidle;             // Place transmitter (SerDes) into electrical idle.
output  [NL-1:0]            mac_phy_txcompliance;           // Indicate to SDM to transmit a compliance sequence.
                                                            // (Sets negative disparity).
output  [NL-1:0]            mac_phy_rxpolarity;             // Invert the received data when asserted
output  [NL-1:0]            mac_phy_rxstandby;              // Controls whether the PHY RX is active
output  [NL-1:0]            smlh_rcvd_eidle_rxstandby;      // Rx EIOS for RxStandby
input   [(NL*NB*8)-1:0]     phy_mac_rxdata;                 // The received data. 8/16 bits per lane SDM performs 8B10B
                                                            // decode and error checking functions.
input   [(NL*NB)-1:0]       phy_mac_rxdatak;                // K character indication 1 or 2 bits per lane.  Signals SDM
                                                            // detected comma. SDM may perform comma detect alignment as well.
input   [NL-1:0]            phy_mac_rxvalid;                // Receive data is valid.
input   [(NL*3)-1:0]        phy_mac_rxstatus;               // Encoders receiver status and error codes for the received
                                                            // data stream and receiver detection
input   [NL-1:0]            phy_mac_rxelecidle;             // Indicates receiver detection of an electrical idle. This
                                                            // is an asynchronous signals
input   [NL-1:0]            phy_mac_phystatus;              // Used to communicate completion of several PHY functions
                                                            // including power management state transitions,
                                                            // and receiver detection
input   [NL-1:0]            phy_mac_rxstandbystatus;        // RxStandbyStatus PIPE signal
input   [NL-1:0]            phy_mac_rxelecidle_noflip;      // No Lane Flip-ed RxElecilde
input   [NL-1:0]            laneflip_lanes_active;          // Lane Flip-ed smlh_lanes_active
input   [NL-1:0]            laneflip_rcvd_eidle_rxstandby;  // Lane Flip-ed smlh_rcvd_eidle_rxstandby
input   [NL-1:0]            laneflip_pipe_turnoff;  
// END_IO:PIPE Signal Descriptions.

input   [8:0]               cfg_lane_en;                    // pre-determined number of lanes
input                       cfg_gen1_ei_inference_mode;     // EI inference mode for Gen1. default 0 - using rxelecidle==1; 1 - using rxvalid==0
input   [1:0]               cfg_select_deemph_mux_bus;      // sel deemphasis {bit, var}
input   [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl;                   // lane under test + gen5 control
input   [6:0]               cfg_rxstandby_control;          // Rxstandby Control
output                      smlh_bw_mgt_status;             // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                            // without the port transitioning through DL_Down status
output                      smlh_link_auto_bw_status;       // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through

                                                            // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
output  [2:0]               current_data_rate;              // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=running at gen3 data rate, 3=running at gen4 data rate
output  [2:0]               pm_current_data_rate_others;    // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=running at gen3 data rate, 3=running at gen4 data rate
output  [2:0]               mac_phy_rate;                   // 1= change speed to gen2, 2=change speed to gen3
input   [NL-1:0]            phy_mac_rxdatavalid;            //Rx datavalid
input                       cfg_alt_protocol_enable;        // enable alternate protocol
input   [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control;

output                      smlh_dir_linkw_chg_rising_edge; // clear cfg_directed_link_width_change
output                      smlh_ltssm_in_hotrst_dis_entry;
output                      smlh_mod_ts_rcvd;               // modified ts received
output  [55:0]              mod_ts_data_rcvd;               // mod ts data rcvd
output  [55:0]              mod_ts_data_sent;               // mod ts data transmitted

// Retry buffer external RAM interface inputs/outpus declaration
//
input   [SOTBUF_WD -1:0]    retrysotram_xdlh_data;          // Data coming back from Retry buffer RAM
input   [SOTBUF_PW -1:0]    retrysotram_xdlh_depth;
input                       retrysotram_xdlh_parerr;
input   [RBUF_WD -1:0]      retryram_xdlh_data;             // Data coming back from Retry buffer RAM
input   [RBUF_PW -1:0]      retryram_xdlh_depth;            // How big is the external retry buffer
input                       retryram_xdlh_parerr;           // retry buffer ram parity error detected
output                      xdlh_retryram_par_chk_val;      // parity check is valid
output                      xdlh_retryram_halt;
output  [RBUF_PW -1:0]      xdlh_retryram_addr;             // Adrress to retry buffer RAM
output  [RBUF_WD -1:0]      xdlh_retryram_data;             // Write data to retry buffer RAM
output                      xdlh_retryram_we;               // Write enable to retry buffer RAM
output                      xdlh_retryram_en;               // Read enable to retry buffer RAM
output                      xdlh_retrysotram_par_chk_val;   // parity check is valid
  
output  [3:0]               xdlh_match_pmdllp;
wire    [3:0]               xdlh_match_pmdllp;

// Performance changes - 2p RAM I/F
// output  [SOTBUF_PW -1:0]    xdlh_retrysotram_addr;          // Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]    xdlh_retrysotram_waddr;          // Write Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]    xdlh_retrysotram_raddr;          // Read Adrress to retry buffer RAM

output  [SOTBUF_WD -1:0]    xdlh_retrysotram_data;          // Write data to retry buffer RAM
output                      xdlh_retrysotram_we;            // Write enable to retry buffer RAM
output                      xdlh_retrysotram_en;            // Read enable to retry buffer RAM

output                  xdlh_retry_req;                 // Puls : Retry Event
output                  smlh_link_in_training;                 // Level: Ltssm is in Config or Recovery



input                   pm_current_powerdown_p1;               // Indicate mac phy powerdown is in P1
input                   pm_current_powerdown_p0;               // Indicate mac phy powerdown is in P0

output  [16:0]          xdlh_replay_timer;              // XDLH retry buffer replay timer
output  [11:0]          xdlh_rbuf_pkt_cnt;              // XDLH packet counter
// LTSSM timers routed to the top-level for verification usage
input   [T_WD-1:0]      smlh_fast_time_1ms;
input   [T_WD-1:0]      smlh_fast_time_2ms;
input   [T_WD-1:0]      smlh_fast_time_3ms;
input   [T_WD-1:0]      smlh_fast_time_4ms;
input   [T_WD-1:0]      smlh_fast_time_10ms;
input   [T_WD-1:0]      smlh_fast_time_12ms;
input   [T_WD-1:0]      smlh_fast_time_24ms;
input   [T_WD-1:0]      smlh_fast_time_32ms;
input   [T_WD-1:0]      smlh_fast_time_48ms;
input   [T_WD-1:0]      smlh_fast_time_100ms;
// -------------------------------------------------------------------------------------------
// Internal wires
// -------------------------------------------------------------------------------------------
// From RDLH
wire                        rdlh_xdlh_rcvd_nack;            // RDLH pulse signal to indicate that there was a NACK PKT received, and its nack sequence number drove to RDLH_RCVD_ACKNACK_SEQ_NUM
wire                        rdlh_xdlh_rcvd_ack;             // RDLH pulse signal to indicate that there was a ACK PKT received, and its ACK sequence number drove to RDLH_RCVD_ACKNACK_SEQ_NUM
wire    [11:0]              rdlh_xdlh_rcvd_acknack_seqnum;  // 12 bits indicated the sequence number of received ACK/NACK DLLP Packet
wire                        rdlh_xdlh_req2send_ack;         // RDLH received a good packet and has been asked to send an ACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
wire                        rdlh_xdlh_req2send_ack_due2dup; // RDLH received a packet that is a duplicated PKT . RDLH_REQ2SEND_ACK signal will be asserted while RDLH_RCVD_DUP is asserted.
wire                        rdlh_xdlh_req2send_nack;        // RDLH received a good packet and has been asked to send an NACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
wire    [11:0]              rdlh_xdlh_req_acknack_seqnum;   // RDLH received a packet with this sequence number
  `ifndef SYNTHESIS
  `endif // SYNTHESIS
wire                        nak_scheduled;                  // dllp generation block requests nak is scheduled to be transmitted

// From RMLH
wire                        smlh_inskip_rcv;                // when asserted, RPLH is in skip receiving
wire                        smlh_ts_rcv_err;                // When asserted, it indicates that the TS has violation in hear beat.
wire                        smlh_ts1_rcvd;                  // when asserted, RPLH rcvd TS1
wire                        smlh_ts2_rcvd;                  // when asserted, RPLH rcvd TS2
wire    [4:0]               smlh_ts_link_ctrl;              // 5 bits
wire                        smlh_ts_lane_num_is_k237;
wire    [7:0]               smlh_ts_link_num;               // 8 bit link number
wire                        smlh_ts_link_num_is_k237;       // Indicates whether or not received Kchar with k237
wire                        smlh_rcvd_lane_rev;
wire    [NL-1:0]            smlh_lanes_rcving;
wire    [1:0]               rmlh_rcvd_idle;                 // RMLH block keeps track of the number of idle received continously.  Bit 0 indicates receiver received 8 continous idle symbol, bit1 indicates 1 idle receivd
wire                        rmlh_rcvd_eidle_set;            // receiver rcvd eidle set.
wire    [NL-1:0]            act_rmlh_rcvd_eidle_set;        // receiver rcvd eidle set per lane.
wire                        rmlh_all_sym_locked;            // symbol locked on all active lanes

wire  [NL-1:0]              rpipe_rxaligned;                // indicates rxvalid with squelch
wire    [NW-1:0]            rmlh_rdlh_dllp_start;           // indicate the dword location of SDPor STP
wire    [NW-1:0]            rmlh_rdlh_tlp_start;
wire                        rmlh_rdlh_pkt_dv;
wire    [NW-1:0]            rmlh_rdlh_pkt_end;              // indicate the dword location of END or EBD
wire    [NW-1:0]            rmlh_rdlh_pkt_edb;
wire    [DW_WO_PAR-1:0]     rmlh_rdlh_pkt_data;
wire    [NW-1:0]            rmlh_rdlh_pkt_err;               // EOP/SOP error in frame
wire    [NW-1:0]            rmlh_rdlh_nak;                  // NAK indication
wire    [NL-1:0]            rpipe_rxdetected;               // RMLH pipe module output to SMLH
wire                        rpipe_rxdetect_done;            // RMLH pipe module output to SMLH
wire                        rpipe_all_phystatus_asserted;
wire                        rpipe_all_phystatus_deasserted;
wire    [NL-1:0]            rpipe_rxelecidle;               // RMLH pipe module output to SMLH
wire    [(NL*NB*8)-1:0]     rpipe_rxdata;
wire    [(NL*NBK)-1:0]      rpipe_rxdatak;
wire    [(NL*NB)-1:0]       rpipe_rxerror_dup;
wire    [NL-1:0]            rpipe_rxdata_dv;                // RMLH pipe module output to SMLH


// From XDLH
wire    [11:0]              xdlh_rdlh_last_xmt_seqnum;      // the last transmitted highest sequence number of TLP's DLLP. Receiver needs this signal to identify out of order TLP
wire                        xdlh_smlh_start_link_retrain;

wire    [NL-1:0]            lpbk_eq_lanes_active;
wire    [NL-1:0]            smlh_lanes_active;              // Which lanes are actively configured
wire    [NL-1:0]            smlh_no_turnoff_lanes;          // No turnoff lanes
wire    [NL-1:0]            smlh_txlanes_active;            // Which lanes are actively configured (TX SIDE)
wire    [NL-1:0]            smlh_rxlanes_active;            // Which lanes are actively configured (RX SIDE)
wire    [NL-1:0]            deskew_lanes_active;              // Which lanes are actively configured (or being configured)
wire                        smlh_lnknum_match_dis;          // This signal is designed to notify the rmlh block when to enable link number match checking
wire                        smlh_ltssm_in_pollconfig;       // this signal enables receiver to detect the polarity and invert if necessary.
wire                        smlh_scrambler_disable;         // when asserted, scramble disabled.
wire                        xmlh_cmd_is_data;               // xmtbyte state machine is waiting for packet start or packet end
wire                        smlh_training_rst_n;
wire                        smlh_link_disable;

wire    [5:0]               smlh_link_mode;                 // 6 bit link width; 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
wire    [5:0]               smlh_link_txmode;               // 6 bit link width; 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
wire    [5:0]               smlh_link_rxmode;               // 6 bit link width; 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
wire                        smlh_link_up;                   // Link state machine is in link up when asserted.
wire                        smlh_req_rst_not;                   // LTSSM request reset
wire                        smlh_in_l0_l0s;                 // LTSSM is in L0 or L0s state

wire                        rdlh_link_up;                   // RDLH link is up.
wire                        rdlh_link_down;                 // RDLH link is down.
wire    [11:0]              xdlh_curnt_seqnum;

wire                        xdlh_xtlh_halt;                 // stop xtlh xmt immediatelly
wire    [RX_NDLLP-1:0]      rtlh_rfc_upd;                   // FC pkt rcvd from RTLH
wire    [(RX_NDLLP*32)-1:0] rtlh_rfc_data;                  // 32bits FC data from RTLH


localparam CTL_WD = `CX_XTLH_XDLH_CTL_WD; // (NW == 2)? 1 : @CX_NW
wire                  xtlh_xdlh_dv;      // XTLH pushes down packet down qualified by this data
wire   [CTL_WD-1:0]   xtlh_xdlh_sot;     // XTLH Start Of TLP control bus
wire   [CTL_WD-1:0]   xtlh_xdlh_eot;     // XTLH End Of TLP control bus
wire   [CTL_WD-1:0]   xtlh_xdlh_badeot;  // XTLH Bad Eot control bus
wire   [DW_W_PAR-1:0] xtlh_xdlh_data;    // XTLH outputs header/data bus to XDLH
wire   [NW-1:0]       xtlh_xdlh_dwen;    // XTLH outputs dword enable for header/data bus to XDLH

// From RDLH
wire    [RX_NDLLP-1:0]      rdlh_rtlh_rcvd_dllp;            // When asserted, it indicates it is DLLP1 packet (Each 128-bit words could carry two DLLP packets)
wire    [(RX_NDLLP*32)-1:0] rdlh_rtlh_dllp_content;         // The received DLLP packet
wire    [DW_W_PAR-1:0]      rdlh_rtlh_tlp_data;             // Current TLP header and data

wire                        rdlh_rtlh_tlp_dv;               // Data bus is valid this cycle
wire    [NW-1:0]            rdlh_rtlh_tlp_sot;              // When asserted, it indicates the Start of a TLP pkt

wire    [NW-1:0]            rdlh_rtlh_tlp_eot;              // When asserted, it indicates the end of a good TLP pkt
wire    [RX_TLP-1:0]        rdlh_rtlh_tlp_abort;            // Packet was malformed -- abort it.
wire    [1:0]               rdlh_rtlh_link_state;           // RDLH link up FSM current state.

wire                        xdlh_rtlh_fc_ack;               // When asserted, it indicates XDLH has accepted the request to XMIT a FC packet

// RTLH/RDLH interface
wire                        rtlh_rdlh_fci1_fci2;            // RTLH flow control init 1 and init 2.
wire    [TX_NDLLP-1:0]      rtlh_xdlh_fc_req;               // Request to send a FCP
wire                        rtlh_xdlh_fc_req_hi;            // Request to send a high-priority FCP that is higher than ACK/NACK
wire                        rtlh_xdlh_fc_req_low;           // Request to send a low-priority FCP that is lower than TLP
wire    [(TX_NDLLP*32)-1:0] rtlh_xdlh_fc_data;              // Data associated with request
output         [7:0]                 rtfcgen_ph_diff;
output                               rtlh_overfl_err;                // Indicates receiver overflow (credit based)
output         [L2NL-1:0]            smlh_lane_flip_ctrl;
output         [4:0]                 lpbk_lane_under_test;
output         [L2NL-1:0]            ltssm_lane_flip_ctrl;

output         [5:0]                 ltssm_cxl_enable;
output         [1:0]                 ltssm_cxl_ll_mod;
input                                drift_buffer_deskew_disable;




wire                        rtlh_req_link_retrain;


wire    [5:0]               smlh_autoneg_link_width;
wire    [3:0]               smlh_autoneg_link_sp;
wire    [3:0]               smlh_autoneg_link_sp_mpcie;
wire    [3:0]               smlh_autoneg_link_sp_int;
wire                        smlh_link_training_in_prog;
wire    [2:0]               current_data_rate;
wire    [2:0]               pm_current_data_rate_others;
wire    [2:0]               pm_current_data_rate_xmlh_xmt;
wire    [2:0]               pm_current_data_rate_xmlh_scr;
wire    [2:0]               pm_current_data_rate_rplh_pkf;
wire    [2:0]               pm_current_data_rate_smlh_sqf;
wire    [2:0]               pm_current_data_rate_smlh_lnk;
wire    [2:0]               pm_current_data_rate_smlh_eq;
wire    [2:0]               pm_current_data_rate_ltssm;
wire    [1:0]               current_powerdown;
wire    [5:0]               smlh_ltssm_state_xmlh;
wire    [5:0]               smlh_ltssm_state_rmlh;

assign smlh_autoneg_link_width           = smlh_link_mode;
assign smlh_autoneg_link_sp_mpcie        = 4'h0 ;   // Not Used in Conventional PCIe.
assign smlh_autoneg_link_sp_int          = (pm_current_data_rate == `GEN5_RATE) ? `GEN5_LINK_SP : (pm_current_data_rate == `GEN4_RATE) ? `GEN4_LINK_SP : (pm_current_data_rate == `GEN3_RATE ) ? `GEN3_LINK_SP  : ((pm_current_data_rate == `GEN2_RATE) ? `GEN2_LINK_SP : `GEN1_LINK_SP);
assign smlh_autoneg_link_sp              = (phy_type == `PHY_TYPE_MPCIE) ? smlh_autoneg_link_sp_mpcie : smlh_autoneg_link_sp_int ;

assign smlh_link_training_in_prog        = smlh_link_in_training;

// active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
wire [AW-1:0] active_nb;
wire       smlh_do_deskew;

wire                        smlh_in_l1;
wire                        smlh_in_l1_p1;
//wire                        pm_freeze_ack_timer             = smlh_in_l1 & pm_xtlh_block_tlp;
// link training state machine detects a violation of the rules which is an option checker
// Rules to detect the violation of the SDP, STP and END location of multi-lane port, and etc, is another optional checker
// Therefore two of the errors below are wired to zero. Not support at the moment
wire                        rmlh_rcvd_err;
wire                        rmlh_deskew_alignment_err;
wire                        rmlh_deskew_complete;

wire                        rdlh_prot_err;
wire                        rdlh_bad_tlp_err;
wire                        rdlh_bad_dllp_err;


// Power Management signals
wire                        rdlh_rcvd_as_req_l1;
wire                        rdlh_rcvd_pm_enter_l1;
wire                        rdlh_rcvd_pm_enter_l23;
wire                        rdlh_rcvd_pm_req_ack;

wire                        xdlh_replay_num_rlover_err;
assign xdlh_replay_num_rlover_err      = xdlh_smlh_start_link_retrain;
wire                        xdlh_replay_timeout_err;
wire                        xmtbyte_skip_sent;
wire                        smlh_successful_spd_negotiation;
wire    [NL-1:0]            smseq_ts1_rcvd_pulse_bus;
wire    [NL-1:0]            smseq_ts2_rcvd_pulse_bus;
wire    [NL*4-1:0]          smseq_loc_ts2_rcvd_bus;
wire    [NL*4-1:0]          smseq_loc_eies_rcvd_bus;
wire    [NL*4-1:0]          smseq_in_skp_bus;
wire    [NL-1:0]            smseq_fts_skp_do_deskew_bus;

wire    [63:0]              cxpl_debug_info;

wire                        ltssm_rcvr_err_rpt_en;
wire    [1:0]               xmlh_powerdown;                 // From LTSSM indicating power down state (P0/P0s/P1). P2 State is controlled by
wire    [1:0]               ltssm_powerdown;                // From LTSSM to rmlh_pipe
wire    [3:0]               ltssm_eidle_cnt;                // 3 bits, indicates how many EIOS sets to send before returning xmtbyte_eidle_sent.  0=1 EIOS, 1=2 EIOS, etc.
wire                        ltssm_lpbk_master;

wire    [2:0]               mac_phy_rate;
wire                        xmtbyte_ts1_sent;
wire                        xmtbyte_ts2_sent;
wire                        xmtbyte_idle_sent;
wire                        xmtbyte_eidle_sent;

wire    [10:0]              xmtbyte_ts_pcnt;
wire                        xmtbyte_ts_data_diff;
wire                        xmtbyte_1024_ts_sent;
wire                        xmtbyte_spd_chg_sent;
wire                        xmtbyte_dis_link_sent;

wire                        ltssm_ts_auto_change;
wire   [7:0]                ltssm_xlinknum;
wire   [NL-1:0]             ltssm_xk237_4lannum;
wire   [NL-1:0]             ltssm_xk237_4lnknum;
wire   [7:0]                ltssm_ts_cntrl;
wire                        ltssm_mod_ts;
wire   [7:0]                latched_ts_nfts;
wire                        ltssm_in_lpbk;
wire                        xmtbyte_fts_sent;
wire                        xmtbyte_txdata_dv;
wire   [(NL*NB*8)-1:0]      xmtbyte_txdata;
wire   [(NL*NBK)-1:0]       xmtbyte_txdatak;
wire   [NL-1:0]             xmtbyte_txelecidle;
wire                        xmtbyte_txdetectrx_loopback;
wire   [5:0]                smlh_ltssm_next;
wire   [5:0]                smlh_ltssm_last;
wire   [7:0]                muxed_n_fts;
wire   [3:0]                ltssm_cmd;

// From rmlh to rplh
wire  [(NL*NB*8)-1:0]       rmlh_rplh_rxdata;
wire  [(NL*NB)-1:0]         rmlh_rplh_rxdatak;
wire  [(NL*NB)-1:0]         rmlh_rplh_rxerror;
wire                        rmlh_rplh_dv;
wire  [5:0]                 rmlh_rplh_link_mode;
wire  [3:0]                 rmlh_rplh_active_nb;
wire  [1:0]                 rmlh_rplh_rcvd_idle_gen12;

// The following signals are used of freq_step b/w layer1 and layer2
wire    [PL_NW-1:0]         pl_rmlh_rdlh_dllp_start;       // indicate the dword location of SDPor STP
wire    [PL_NW-1:0]         pl_rmlh_rdlh_tlp_start;
wire                        pl_rmlh_rdlh_pkt_dv;
wire    [PL_NW-1:0]         pl_rmlh_rdlh_pkt_end;          // indicate the dword location of END or EBD
wire    [PL_NW-1:0]         pl_rmlh_rdlh_pkt_edb;
wire    [PL_DW-1:0]         pl_rmlh_rdlh_pkt_data;
wire    [PL_NW-1:0]         pl_rmlh_rdlh_pkt_err;          // EOP/SOP error in frame
wire    [PL_NW-1:0]         pl_rmlh_rdlh_nak;              // NAK indication
wire                        pl_rmlh_rcvd_err;
wire                        pl_rmlh_deskew_alignment_err;



wire xtlh_sot_is_first;
wire xtlh_eot_sot_eot;
wire xtlh_badeot;
wire xtlh_first_badeot;
wire xtlh_eot_sot;
wire [L2NL-1:0] latched_flip_ctrl;

wire                       debug_mac_phy_tx_burst;
wire   [15:0]              debug_mac_phy_tx_symbol;
wire   [1:0]               debug_mac_phy_tx_datanctrl;
assign debug_mac_phy_tx_burst      = 1'b0 ;
assign debug_mac_phy_tx_symbol     = 16'h0000 ;
assign debug_mac_phy_tx_datanctrl  = 2'b00 ;

wire                       info_txelec_txburst ;
wire                       info_txcomp_rxburst ;
wire   [7:0]               info_link_number ;
wire                       info_inskip_rcv ;
wire                       info_ts1_rcvd ;
wire                       info_ts2_rcvd ;
wire                       info_rcvd_lane_rev ;
wire   [3:0]               info_ts_link_ctrl ;
wire                       info_ts_lane_num_is_k237 ;
wire                       info_ts_link_num_is_k237 ;
wire   [15:0]              info_tx_data_symbol ;
wire   [1:0]               info_tx_datak_ctrl ;


assign info_txelec_txburst       = (phy_type == `PHY_TYPE_CPCIE) ? mac_phy_txelecidle[0]     : debug_mac_phy_tx_burst ;
assign info_txcomp_rxburst       = (phy_type == `PHY_TYPE_CPCIE) ? mac_phy_txcompliance[0]   : phy_mac_rxelecidle[0] ;
assign info_link_number          = (phy_type == `PHY_TYPE_CPCIE) ? smlh_ts_link_num          : 8'h00 ;
assign info_inskip_rcv           = (phy_type == `PHY_TYPE_CPCIE) ? smlh_inskip_rcv           : 1'b0 ;
assign info_ts1_rcvd             = (phy_type == `PHY_TYPE_CPCIE) ? smlh_ts1_rcvd             : 1'b0 ;
assign info_ts2_rcvd             = (phy_type == `PHY_TYPE_CPCIE) ? smlh_ts2_rcvd             : 1'b0 ;
assign info_rcvd_lane_rev        = (phy_type == `PHY_TYPE_CPCIE) ? smlh_rcvd_lane_rev        : 1'b0 ;
assign info_ts_link_ctrl         = (phy_type == `PHY_TYPE_CPCIE) ? smlh_ts_link_ctrl[3:0]    : 4'b0000 ;
assign info_ts_lane_num_is_k237  = (phy_type == `PHY_TYPE_CPCIE) ? smlh_ts_lane_num_is_k237  : 1'b0 ;
assign info_ts_link_num_is_k237  = (phy_type == `PHY_TYPE_CPCIE) ? smlh_ts_link_num_is_k237  : 1'b0 ;
assign info_tx_data_symbol       = (phy_type == `PHY_TYPE_CPCIE) ? mac_phy_txdata[15:0]        : debug_mac_phy_tx_symbol[15:0] ;
assign info_tx_datak_ctrl        = (phy_type == `PHY_TYPE_CPCIE) ? mac_phy_txdatak[1:0]        : debug_mac_phy_tx_datanctrl[1:0] ;

// added to identify whether or not LTSSM is enabled to transmit TLP
wire tmp_smlh_in_l0;
assign tmp_smlh_in_l0 = (smlh_in_l0) | (smlh_in_rl0s & !smlh_in_l0s);
// status that used to help link negotiation
wire    [63:0]              pre_cxpl_debug_info;
assign pre_cxpl_debug_info = {
    smlh_scrambler_disable,     // 31
    smlh_link_disable,          // 30
    smlh_link_in_training,      // 29
    smlh_ltssm_in_pollconfig,   // 28
    smlh_training_rst_n,        // 27
    1'b0,                       // 26
    2'b0,                       // 25:24
    1'b0,                       // 23
    mac_phy_txdetectrx_loopback[0],// 22
    info_txelec_txburst,        // 21
    info_txcomp_rxburst,        // 20
    app_init_rst,               // 19
    1'b0,                       // 18
    2'b0,                       // 17:16
    info_link_number,           // 15:8
    2'b0,                       // 7:6
    xmtbyte_skip_sent,          // 5
    smlh_link_up,               // 4
    info_inskip_rcv,            // 3
    info_ts1_rcvd,              // 2
    info_ts2_rcvd,              // 1
    info_rcvd_lane_rev,         // 0
    info_ts_link_ctrl[3:0],     // 31:28
    info_ts_lane_num_is_k237,   // 27
    info_ts_link_num_is_k237,   // 26
    rmlh_rcvd_idle[0],          // 25
    rmlh_rcvd_idle[1],          // 24
    info_tx_data_symbol,        // 23:8
    info_tx_datak_ctrl,         // 7:6
    smlh_ltssm_state            // 5:0
};

assign cxpl_debug_info = pre_cxpl_debug_info;

// This signal is used to by the ltssm to reset idle_to_rlock flag
wire                        rmlh_pkt_start;
assign  rmlh_pkt_start      = |rmlh_rdlh_dllp_start || |rmlh_rdlh_tlp_start;


wire    [5:0]               cpcie_smlh_link_mode;
wire    [5:0]               cpcie_smlh_link_rxmode;
wire    [NL-1:0]            cpcie_smlh_lanes_active;
wire    [NL-1:0]            cpcie_smlh_no_turnoff_lanes;
wire                        cpcie_smlh_lnknum_match_dis;
wire                        cpcie_smlh_link_up;
wire                        cpcie_smlh_req_rst_not;
wire                        cpcie_smlh_scrambler_disable;
wire                        cpcie_smlh_ltssm_in_pollconfig;
wire                        cpcie_smlh_training_rst_n;
wire                        cpcie_smlh_link_disable;
wire                        cpcie_smlh_link_in_training;
wire                        cpcie_smlh_bw_mgt_status;
wire                        cpcie_smlh_link_auto_bw_status;
wire    [5:0]               cpcie_smlh_ltssm_next;
wire    [NL-1:0]            cpcie_deskew_lanes_active;
wire    [NL-1:0]            cpcie_mac_phy_txdetectrx_loopback;
wire    [NL-1:0]            cpcie_mac_phy_txcompliance;
wire    [2:0]               cpcie_mac_phy_rate;
wire    [NL-1:0]            cpcie_mac_phy_rxpolarity;
wire    [NL-1:0]            cpcie_mac_phy_rxstandby;
wire    [NL-1:0]            cpcie_smlh_rcvd_eidle_rxstandby;
wire                        cpcie_smlh_dir_linkw_chg_rising_edge;
wire                        cpcie_smlh_ltssm_in_hotrst_dis_entry;
wire    [NL-1:0]            cpcie_smseq_ts1_rcvd_pulse_bus;
wire    [NL-1:0]            cpcie_smseq_ts2_rcvd_pulse_bus;
wire    [NL*4-1:0]          cpcie_smseq_loc_ts2_rcvd_bus;
wire    [NL*4-1:0]          cpcie_smseq_loc_eies_rcvd_bus;
wire    [NL*4-1:0]          cpcie_smseq_in_skp_bus;
wire    [NL-1:0]            cpcie_smseq_fts_skp_do_deskew_bus;
wire                        cpcie_smlh_in_l0_l0s;
wire    [AW-1:0]            cpcie_active_nb;
wire                        cpcie_smlh_do_deskew;
wire    [5:0]               cpcie_smlh_ltssm_state;
wire    [5:0]               cpcie_smlh_ltssm_state_xmlh;
wire    [5:0]               cpcie_smlh_ltssm_state_rmlh;
wire                        cpcie_smlh_in_l0s;
wire                        cpcie_smlh_in_rl0s;
wire                        cpcie_smlh_in_l0;
wire                        cpcie_smlh_in_l1;
wire                        cpcie_smlh_in_l1_p1;
wire                        cpcie_smlh_in_l23;
wire                        cpcie_smlh_l123_eidle_timeout;
wire    [4:0]               cpcie_smlh_ts_link_ctrl;
wire                        cpcie_smlh_rcvd_lane_rev;
wire    [7:0]               cpcie_smlh_ts_link_num;
wire                        cpcie_smlh_ts_link_num_is_k237;
wire    [NL-1:0]            cpcie_smlh_lanes_rcving;
wire                        cpcie_smlh_ts_rcv_err;
wire                        cpcie_smlh_ts1_rcvd;
wire                        cpcie_smlh_ts2_rcvd;
wire                        cpcie_smlh_inskip_rcv;
wire                        cpcie_smlh_ts_lane_num_is_k237;
wire                        cpcie_latched_rcvd_eidle_set;
wire                        cpcie_ltssm_rcvr_err_rpt_en;
wire                        cpcie_ltssm_clear;
wire    [3:0]               cpcie_ltssm_cmd;
wire    [1:0]               cpcie_ltssm_powerdown;
wire                        cpcie_ltssm_lpbk_master;
wire                        cpcie_ltssm_ts_auto_change;
wire    [7:0]               cpcie_ltssm_xlinknum;
wire    [NL-1:0]            cpcie_ltssm_xk237_4lannum;
wire    [NL-1:0]            cpcie_ltssm_xk237_4lnknum;
wire    [7:0]               cpcie_ltssm_ts_cntrl;
wire                        cpcie_ltssm_ts_alt_protocol;
wire                        cpcie_ltssm_no_idle_need_sent;
wire    [55:0]              cpcie_ltssm_ts_alt_prot_info;
assign                      mod_ts_data_sent = cpcie_ltssm_ts_alt_prot_info;
wire    [5:0]               cpcie_ltssm_cxl_enable;
wire    [5:0]               ltssm_cxl_enable = cpcie_ltssm_cxl_enable; // {Multi-Logical Dev, CXL 2.0, SyncHeader_Bypass, CXL.Cache, CXL.Mem, CXL.IO}
wire    [23:0]              cpcie_ltssm_cxl_mod_ts_phase1_rcvd;
wire    [23:0]              ltssm_cxl_mod_ts_phase1_rcvd = cpcie_ltssm_cxl_mod_ts_phase1_rcvd;
wire                        cpcie_ltssm_cxl_retimers_pre_mismatched;
wire                        ltssm_cxl_retimers_pre_mismatched = cpcie_ltssm_cxl_retimers_pre_mismatched;
wire                        cpcie_ltssm_cxl_flexbus_phase2_mismatched;
wire                        ltssm_cxl_flexbus_phase2_mismatched = cpcie_ltssm_cxl_flexbus_phase2_mismatched;
wire                        cpcie_ltssm_in_lpbk;
wire    [2:0]               cpcie_ltssm_eidle_cnt;
wire    [1:0]               ltssm_cxl_ll_mod;
wire    [NL-1:0]            ltssm_lpbk_slave_lut;
wire    [7:0]               cpcie_muxed_n_fts;
wire    [7:0]               cpcie_latched_ts_nfts;
wire    [`CX_INFO_EI_WD-1:0]cpcie_cxpl_debug_info_ei;
wire    [L2NL-1:0]          cpcie_smlh_lane_flip_ctrl;
wire    [L2NL-1:0]          cpcie_ltssm_lane_flip_ctrl;


wire                        ltssm_clear;
wire    [16:0]              xdlh_replay_timer;
wire    [11:0]              xdlh_rbuf_pkt_cnt;
wire    [NL-1:0]            rmlh_rpipe_rxskipremoved;

wire                        cfg_polarity_mode;
wire                        cfg_rx_8_ts1s;
wire                        cfg_rate_chg_mode;
wire                        cfg_block_local_detect_eq_problem;
wire                        cfg_rxstandby_handshake_policy;
wire    [3:0]               cfg_p1_entry_policy;
wire                        cfg_por_phystatus_mode;
assign cfg_polarity_mode                 = cfg_lane_skew[1];
assign cfg_rx_8_ts1s                     = cfg_lane_skew[2];
assign cfg_rate_chg_mode                 = cfg_lane_skew[7];
assign cfg_block_local_detect_eq_problem = cfg_lane_skew[8];

// Temporary wire
wire    [NL-1:0]            pl_rmlh_rpipe_rxskipremoved;
wire                        pl_smlh_dir_linkw_chg_rising_edge;
wire                        pl_smlh_bw_mgt_status;
wire                        pl_smlh_link_auto_bw_status;
wire    [NL-1:0]            pl_smseq_ts1_rcvd_pulse_bus;
wire    [NL-1:0]            pl_smseq_ts2_rcvd_pulse_bus;


// GEN1_LINK_SP must be supported at least

assign cfg_rxstandby_handshake_policy    = cfg_lane_skew[3];
assign cfg_por_phystatus_mode            = cfg_lane_skew[6];
assign cfg_p1_entry_policy               = cfg_lane_skew[12:9];
wire       cfg_link_retrain_i = cfg_link_retrain;


reg latched_smlh_link_up;
always @( posedge core_clk or negedge core_rst_n ) begin : latched_smlh_link_up_PROC
    if ( ~core_rst_n )
        latched_smlh_link_up <= #TP 1'b0;
    else if ( smlh_ltssm_state == `S_DETECT_QUIET )
        latched_smlh_link_up <= #TP 1'b0;
    else if ( ~(smlh_ltssm_state == `S_LPBK_ENTRY || smlh_ltssm_state == `S_LPBK_ACTIVE || smlh_ltssm_state == `S_LPBK_EXIT || smlh_ltssm_state == `S_LPBK_EXIT_TIMEOUT) && smlh_link_up )
        latched_smlh_link_up <= #TP 1'b1;
end // latched_smlh_link_up_PROC

//--------------------------------------
// smlh Selector
//--------------------------------------

assign smlh_link_mode              = cpcie_smlh_link_mode;
assign smlh_link_txmode            = cpcie_smlh_link_mode;
assign smlh_link_rxmode            = cpcie_smlh_link_rxmode;
assign smlh_lanes_active           = cpcie_smlh_lanes_active;
assign smlh_txlanes_active         = cpcie_smlh_lanes_active;
assign smlh_rxlanes_active         = cpcie_smlh_lanes_active;
assign smlh_no_turnoff_lanes       = cpcie_smlh_no_turnoff_lanes;
assign smlh_lnknum_match_dis       = cpcie_smlh_lnknum_match_dis;
assign smlh_link_up                = cpcie_smlh_link_up;
assign smlh_req_rst_not            = cpcie_smlh_req_rst_not;
assign smlh_scrambler_disable      = cpcie_smlh_scrambler_disable;
assign smlh_ltssm_in_pollconfig    = cpcie_smlh_ltssm_in_pollconfig;
assign smlh_training_rst_n         = cpcie_smlh_training_rst_n;
assign smlh_link_disable           = cpcie_smlh_link_disable;
assign smlh_link_in_training       = cpcie_smlh_link_in_training;
assign pl_smlh_bw_mgt_status       = cpcie_smlh_bw_mgt_status;
assign pl_smlh_link_auto_bw_status = cpcie_smlh_link_auto_bw_status;
assign smlh_ltssm_next             = cpcie_smlh_ltssm_next;
assign deskew_lanes_active         = cpcie_deskew_lanes_active;
assign mac_phy_txdetectrx_loopback = cpcie_mac_phy_txdetectrx_loopback;
assign mac_phy_txcompliance        = cpcie_mac_phy_txcompliance;
assign mac_phy_rate                = cpcie_mac_phy_rate;
assign mac_phy_rxpolarity          = cpcie_mac_phy_rxpolarity;
assign mac_phy_rxstandby           = cpcie_mac_phy_rxstandby;
assign smlh_rcvd_eidle_rxstandby   = cpcie_smlh_rcvd_eidle_rxstandby;
assign pl_smlh_dir_linkw_chg_rising_edge = cpcie_smlh_dir_linkw_chg_rising_edge;
assign smlh_ltssm_in_hotrst_dis_entry = cpcie_smlh_ltssm_in_hotrst_dis_entry;
assign pl_smseq_ts1_rcvd_pulse_bus = cpcie_smseq_ts1_rcvd_pulse_bus;
assign pl_smseq_ts2_rcvd_pulse_bus = cpcie_smseq_ts2_rcvd_pulse_bus;
assign smseq_loc_ts2_rcvd_bus      = cpcie_smseq_loc_ts2_rcvd_bus;
assign smseq_in_skp_bus            = cpcie_smseq_in_skp_bus;
assign smseq_fts_skp_do_deskew_bus = cpcie_smseq_fts_skp_do_deskew_bus;
assign smlh_in_l0_l0s              = cpcie_smlh_in_l0_l0s;
assign active_nb                   = cpcie_active_nb;
assign smlh_do_deskew              = cpcie_smlh_do_deskew;
assign smlh_ltssm_state            = cpcie_smlh_ltssm_state;
assign smlh_ltssm_state_xmlh       = cpcie_smlh_ltssm_state_xmlh;
assign smlh_ltssm_state_rmlh       = cpcie_smlh_ltssm_state_rmlh;
assign smlh_in_l0s                 = cpcie_smlh_in_l0s;
assign smlh_in_rl0s                = cpcie_smlh_in_rl0s;
assign smlh_in_l0                  = cpcie_smlh_in_l0;
assign smlh_in_l1                  = cpcie_smlh_in_l1;
assign smlh_in_l1_p1               = cpcie_smlh_in_l1_p1;
assign smlh_in_l23                 = cpcie_smlh_in_l23;
assign smlh_l123_eidle_timeout     = cpcie_smlh_l123_eidle_timeout;
assign smlh_ts_link_ctrl           = cpcie_smlh_ts_link_ctrl;
assign smlh_rcvd_lane_rev          = cpcie_smlh_rcvd_lane_rev;
assign smlh_ts_link_num            = cpcie_smlh_ts_link_num;
assign smlh_ts_link_num_is_k237    = cpcie_smlh_ts_link_num_is_k237;
assign smlh_lanes_rcving           = cpcie_smlh_lanes_rcving;
assign smlh_ts_rcv_err             = cpcie_smlh_ts_rcv_err;
assign smlh_ts1_rcvd               = cpcie_smlh_ts1_rcvd;
assign smlh_ts2_rcvd               = cpcie_smlh_ts2_rcvd;
assign smlh_inskip_rcv             = cpcie_smlh_inskip_rcv;
assign smlh_ts_lane_num_is_k237    = cpcie_smlh_ts_lane_num_is_k237;
assign latched_rcvd_eidle_set      = cpcie_latched_rcvd_eidle_set;
assign ltssm_rcvr_err_rpt_en       = cpcie_ltssm_rcvr_err_rpt_en;
assign ltssm_clear                 = cpcie_ltssm_clear;
assign ltssm_cmd                   = cpcie_ltssm_cmd;
assign ltssm_powerdown             = cpcie_ltssm_powerdown;
assign ltssm_lpbk_master           = cpcie_ltssm_lpbk_master;
assign ltssm_ts_auto_change        = cpcie_ltssm_ts_auto_change;
assign ltssm_xlinknum              = cpcie_ltssm_xlinknum;
assign ltssm_xk237_4lannum         = cpcie_ltssm_xk237_4lannum;
assign ltssm_xk237_4lnknum         = cpcie_ltssm_xk237_4lnknum;
assign ltssm_ts_cntrl              = cpcie_ltssm_ts_cntrl;
assign ltssm_in_lpbk               = cpcie_ltssm_in_lpbk;
assign ltssm_eidle_cnt             = {1'b0, cpcie_ltssm_eidle_cnt};
assign muxed_n_fts                 = cpcie_muxed_n_fts;
assign latched_ts_nfts             = cpcie_latched_ts_nfts;
assign cxpl_debug_info_ei          = cpcie_cxpl_debug_info_ei;
assign smlh_lane_flip_ctrl         = cpcie_smlh_lane_flip_ctrl;
assign ltssm_lane_flip_ctrl        = cpcie_ltssm_lane_flip_ctrl;



// For Layer1 power saving and clock gating(STAR#9000936068)
wire                   ltssm_in_config;
wire                   ltssm_in_recovery;
wire                   ltssm_in_lpbk_active;
wire   [NL-1:0]        power_saving_txlanes_active;
wire   [NL-1:0]        power_saving_rxlanes_active;
assign ltssm_in_config = (smlh_ltssm_state==S_CFG_LINKWD_START) || 
                         (smlh_ltssm_state==S_CFG_LINKWD_ACEPT) ||
                         (smlh_ltssm_state==S_CFG_LANENUM_WAIT) ||
                         (smlh_ltssm_state==S_CFG_LANENUM_ACEPT) ||
                         (smlh_ltssm_state==S_CFG_COMPLETE) ||
                         (smlh_ltssm_state==S_CFG_IDLE);

  // When LTSSM in config state, all lanes have to be active  for upconfigure.
assign power_saving_txlanes_active = smlh_txlanes_active | {NL{ltssm_in_config}};
assign power_saving_rxlanes_active = smlh_rxlanes_active | {NL{ltssm_in_config}};
  // When LTSSM in recovery state that previous state of S_CFG_LINKWD_START, all lanes in freq_step have to be active for upconfigure.
assign ltssm_in_recovery = (smlh_ltssm_state==S_RCVRY_LOCK) ||
                           (smlh_ltssm_state==S_RCVRY_RCVRCFG) ||
                           (smlh_ltssm_state==S_RCVRY_IDLE);
  // When LTSSM in lpbk_active or lpbk_exit state, all lanes in freq_step have to be active for latency b/w ltssm and freq_step.
assign ltssm_in_lpbk_active = (smlh_ltssm_state==S_LPBK_ACTIVE) || (smlh_ltssm_state==S_LPBK_EXIT);
assign smlh_ltssm_in_config = (ltssm_in_config || ltssm_in_recovery || ltssm_in_lpbk_active);
// END(STAR#9000936068)

// ================================================================================================================//
// Layer 1 Receive
rmlh

#(INST) u_rmlh(
    .core_clk                           (core_clk),
    .core_clk_ug                        (core_clk_ug),
    .core_rst_n                         (core_rst_n),
    .cfg_deskew_disable                 (cfg_deskew_disable),
    .cfg_ts2_lid_deskew                 (cfg_ts2_lid_deskew),
    .cfg_fast_link_mode                 (cfg_fast_link_mode),
    .cfg_elastic_buffer_mode            (cfg_elastic_buffer_mode),
    .cfg_pipe_garbage_data_mode         (cfg_pipe_garbage_data_mode),
    .latched_smlh_link_up               (latched_smlh_link_up),
    .phy_type                           (phy_type),
    .smlh_in_rl0s                       (smlh_in_rl0s),
    .latched_flip_ctrl                  (latched_flip_ctrl),
    .smlh_lane_flip_ctrl                (cpcie_ltssm_lane_flip_ctrl),
    .smlh_link_mode                     (smlh_link_rxmode),
    .smlh_no_turnoff_lanes              (smlh_no_turnoff_lanes),
    .smlh_lanes_active                  (smlh_lanes_active),
    .power_saving_lanes_active          (power_saving_rxlanes_active),
    .deskew_lanes_active                (deskew_lanes_active),
    .smlh_do_deskew                     (smlh_do_deskew),
    .smlh_lnknum_match_dis              (smlh_lnknum_match_dis),
    .smlh_link_up                       (smlh_link_up),
    .smlh_link_in_training              (smlh_link_in_training),
    .smlh_scrambler_disable             (smlh_scrambler_disable),
    .smlh_ltssm_in_pollconfig           (smlh_ltssm_in_pollconfig),
    .smlh_ltssm_state                   (smlh_ltssm_state_rmlh),
    .smseq_ts1_rcvd_pulse_bus           (pl_smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse_bus           (pl_smseq_ts2_rcvd_pulse_bus),
    .smseq_loc_ts2_rcvd_bus             (smseq_loc_ts2_rcvd_bus),
    .smseq_in_skp_bus                   (smseq_in_skp_bus),
    .smseq_fts_skp_do_deskew_bus        (smseq_fts_skp_do_deskew_bus),
    .ltssm_rcvr_err_rpt_en              (ltssm_rcvr_err_rpt_en),
    .ltssm_powerdown                    (ltssm_powerdown),
    .ltssm_cxl_ll_mod                   (ltssm_cxl_ll_mod),
    .drift_buffer_deskew_disable        (drift_buffer_deskew_disable),
    .ltssm_lpbk_master                  (ltssm_lpbk_master),

    .phy_mac_rxdata                     (phy_mac_rxdata),
    .phy_mac_rxdatak                    (phy_mac_rxdatak),
    .phy_mac_rxvalid                    (phy_mac_rxvalid),
    .phy_mac_rxstatus                   (phy_mac_rxstatus),
    .phy_mac_rxelecidle                 (phy_mac_rxelecidle),
    .phy_mac_phystatus                  (phy_mac_phystatus),
    .ltssm_clear                        (ltssm_clear),
    .active_nb                          (active_nb),
    .rplh_rdlh_pkt_err                  (pl_rmlh_rdlh_pkt_err),
    .mac_phy_rate                       (mac_phy_rate),
    .phy_mac_rxdatavalid                (phy_mac_rxdatavalid),
    .pm_current_data_rate               (pm_current_data_rate),

// ---- outputs ---------------
    .current_data_rate                  (current_data_rate),
    .pm_current_data_rate_others        (pm_current_data_rate_others),
    .pm_current_data_rate_xmlh_xmt      (pm_current_data_rate_xmlh_xmt),
    .pm_current_data_rate_xmlh_scr      (pm_current_data_rate_xmlh_scr),
    .pm_current_data_rate_rplh_pkf      (pm_current_data_rate_rplh_pkf),
    .pm_current_data_rate_smlh_sqf      (pm_current_data_rate_smlh_sqf),
    .pm_current_data_rate_smlh_lnk      (pm_current_data_rate_smlh_lnk),
    .pm_current_data_rate_smlh_eq       (pm_current_data_rate_smlh_eq),
    .pm_current_data_rate_ltssm         (pm_current_data_rate_ltssm),
    .current_powerdown                  (current_powerdown),
    .rpipe_rxdata                       (rpipe_rxdata),
    .rpipe_rxdatak                      (rpipe_rxdatak),
    .rpipe_rxerror_dup                  (rpipe_rxerror_dup),
    .rpipe_rxdata_dv                    (rpipe_rxdata_dv),
    .rpipe_rxelecidle                   (rpipe_rxelecidle),
    .rpipe_rxdetected                   (rpipe_rxdetected),
    .rpipe_rxdetect_done                (rpipe_rxdetect_done),
    .rpipe_all_phystatus_asserted       (rpipe_all_phystatus_asserted),
    .rpipe_all_phystatus_deasserted     (rpipe_all_phystatus_deasserted),

    .rmlh_rcvd_eidle_set                (rmlh_rcvd_eidle_set),
    .rmlh_all_sym_locked                (rmlh_all_sym_locked),
    .act_rmlh_rcvd_eidle_set            (act_rmlh_rcvd_eidle_set),
    .rmlh_rplh_rxdata                   (rmlh_rplh_rxdata),
    .rmlh_rplh_rxdatak                  (rmlh_rplh_rxdatak),
    .rmlh_rplh_rxerror                  (rmlh_rplh_rxerror),
    .rmlh_rplh_dv                       (rmlh_rplh_dv),
    .rmlh_rplh_link_mode                (rmlh_rplh_link_mode),
    .rmlh_rplh_active_nb                (rmlh_rplh_active_nb),
    .rmlh_rplh_rcvd_idle_gen12          (rmlh_rplh_rcvd_idle_gen12),

    .rmlh_deskew_alignment_err          (pl_rmlh_deskew_alignment_err),
    .rmlh_deskew_complete               (rmlh_deskew_complete),
    .rmlh_rpipe_rxskipremoved            (pl_rmlh_rpipe_rxskipremoved),
    .rpipe_rxaligned                    (rpipe_rxaligned),
    .rmlh_rcvd_err                      (pl_rmlh_rcvd_err)
); //rmlh

// Plh Receive
rplh
 #(INST) u_rplh(
// ---- inputs ---------------
    .core_clk                         (core_clk),
    .core_rst_n                       (core_rst_n),
    .smlh_link_mode                   (rmlh_rplh_link_mode),
    .active_nb                        (rmlh_rplh_active_nb),
    .rmlh_rplh_rcvd_idle_gen12        (rmlh_rplh_rcvd_idle_gen12),
    .rxdata_dv                        (rmlh_rplh_dv),
    .rxdata                           (rmlh_rplh_rxdata),
    .rxdatak                          (rmlh_rplh_rxdatak),
    .rxerror                          (rmlh_rplh_rxerror),

// ---- outputs ---------------
    .rplh_rdlh_dllp_start             (pl_rmlh_rdlh_dllp_start),
    .rplh_rdlh_tlp_start              (pl_rmlh_rdlh_tlp_start),
    .rplh_rdlh_pkt_end                (pl_rmlh_rdlh_pkt_end),
    .rplh_rdlh_pkt_edb                (pl_rmlh_rdlh_pkt_edb),
    .rplh_rdlh_pkt_data               (pl_rmlh_rdlh_pkt_data),
    .rplh_rdlh_pkt_dv                 (pl_rmlh_rdlh_pkt_dv),
    .rplh_rdlh_pkt_err                (pl_rmlh_rdlh_pkt_err),
    .rplh_rdlh_nak                    (pl_rmlh_rdlh_nak),
    .rplh_rcvd_idle                   (rmlh_rcvd_idle)
); //rplh


// Layer 2 Receive
rdlh

#(INST) u_rdlh(
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .smlh_link_mode                     (smlh_link_rxmode),
    .smlh_link_up                       (smlh_link_up),
    .cfg_dll_lnk_en                     (cfg_dll_lnk_en),
    .rtlh_fci_done                      (rtlh_fc_init_status[0]),
    .rtlh_fci1_fci2                     (rtlh_rdlh_fci1_fci2),
    .rmlh_rdlh_dllp_start               (rmlh_rdlh_dllp_start),
    .rmlh_rdlh_tlp_start                (rmlh_rdlh_tlp_start),
    .rmlh_rdlh_pkt_end                  (rmlh_rdlh_pkt_end),
    .rmlh_rdlh_pkt_edb                  (rmlh_rdlh_pkt_edb),
    .rmlh_rdlh_pkt_data                 (rmlh_rdlh_pkt_data),
    .rmlh_rdlh_pkt_dv                   (rmlh_rdlh_pkt_dv),
    .rmlh_rdlh_pkt_err                  (rmlh_rdlh_pkt_err),
    .rmlh_rdlh_nak                      (rmlh_rdlh_nak),
    .xdlh_rdlh_last_xmt_seqnum          (xdlh_rdlh_last_xmt_seqnum),
    .nak_scheduled                      (nak_scheduled),
// ---- outputs ---------------
    .rdlh_xdlh_rcvd_nack                (rdlh_xdlh_rcvd_nack),
    .rdlh_xdlh_rcvd_ack                 (rdlh_xdlh_rcvd_ack),
    .rdlh_xdlh_rcvd_acknack_seqnum      (rdlh_xdlh_rcvd_acknack_seqnum),
    .rdlh_rtlh_rcvd_dllp                (rdlh_rtlh_rcvd_dllp),
    .rdlh_rtlh_dllp_content             (rdlh_rtlh_dllp_content),
    .rdlh_rtlh_tlp_sot                  (rdlh_rtlh_tlp_sot),
    .rdlh_rtlh_tlp_dv                   (rdlh_rtlh_tlp_dv),
    .rdlh_rtlh_tlp_eot                  (rdlh_rtlh_tlp_eot),
    .rdlh_rtlh_tlp_data                 (rdlh_rtlh_tlp_data),
    .rdlh_rtlh_tlp_abort                (rdlh_rtlh_tlp_abort),
    .rdlh_xdlh_req2send_ack             (rdlh_xdlh_req2send_ack),
    .rdlh_xdlh_req2send_nack            (rdlh_xdlh_req2send_nack),
    .rdlh_xdlh_req_acknack_seqnum       (rdlh_xdlh_req_acknack_seqnum),
    .rdlh_xdlh_req2send_ack_due2dup     (rdlh_xdlh_req2send_ack_due2dup),
`ifndef SYNTHESIS
`endif // SYNTHESIS
    .rdlh_link_up                       (rdlh_link_up),
    .rdlh_link_down                     (rdlh_link_down),
    .rdlh_rtlh_link_state               (rdlh_rtlh_link_state),
    .rdlh_bad_dllp_err                  (rdlh_bad_dllp_err),
    .rdlh_bad_tlp_err                   (rdlh_bad_tlp_err),
    .rdlh_prot_err                      (rdlh_prot_err),
    .rdlh_rcvd_as_req_l1                (rdlh_rcvd_as_req_l1),
    .rdlh_rcvd_pm_enter_l1              (rdlh_rcvd_pm_enter_l1),
    .rdlh_rcvd_pm_enter_l23             (rdlh_rcvd_pm_enter_l23),
    .rdlh_rcvd_pm_req_ack               (rdlh_rcvd_pm_req_ack)
); //rdlh

// Layer 3 Receive
rtlh

#(INST) u_rtlh (
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .cfg_max_payload                    (cfg_max_payload),
    .cfg_endpoint                       (cfg_endpoint),
    .cfg_root_compx                     (cfg_root_compx),
    .cfg_upstream_port                  (cfg_upstream_port),
    .cfg_tc_enable                      (cfg_tc_enable),
    .cfg_ext_synch                      (cfg_ext_synch),
    .cfg_vc_enable                      (cfg_vc_enable),
    .cfg_vc_struc_vc_id_map             (cfg_vc_struc_vc_id_map),
    .cfg_vc_id_vc_struc_map             (cfg_vc_id_vc_struc_map),
    .cfg_tc_struc_vc_map                (cfg_tc_struc_vc_map),
    .cfg_fc_wdog_disable                (cfg_fc_wdog_disable),
    .cfg_fc_latency_value               (cfg_fc_latency_value),
    .cfg_fc_credit_ph                   (cfg_fc_credit_ph),
    .cfg_fc_credit_nph                  (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh                 (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd                   (cfg_fc_credit_pd),
    .cfg_fc_credit_npd                  (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld                 (cfg_fc_credit_cpld),
    .smlh_in_l1                         (smlh_in_l1),
    .rdlh_rtlh_rcvd_dllp                (rdlh_rtlh_rcvd_dllp),
    .rdlh_rtlh_dllp_content             (rdlh_rtlh_dllp_content),
    .rdlh_rtlh_data                     (rdlh_rtlh_tlp_data),
    .rdlh_rtlh_sot                      (rdlh_rtlh_tlp_sot),
    .rdlh_rtlh_eot                      (rdlh_rtlh_tlp_eot),
    .rdlh_rtlh_dv                       (rdlh_rtlh_tlp_dv),
    .rdlh_rtlh_abort                    (rdlh_rtlh_tlp_abort),
    .rdlh_rtlh_link_state               (rdlh_rtlh_link_state),
    .pm_freeze_fc_timer                 (pm_freeze_fc_timer),
    .current_data_rate                  (pm_current_data_rate_others),
    .phy_type                           (phy_type),
    .smlh_in_l0_l0s                     (smlh_in_l0_l0s),

    .radm_rtlh_ph_ca                    (radm_rtlh_ph_ca),
    .radm_rtlh_pd_ca                    (radm_rtlh_pd_ca),
    .radm_rtlh_nph_ca                   (radm_rtlh_nph_ca),
    .radm_rtlh_npd_ca                   (radm_rtlh_npd_ca),
    .radm_rtlh_cplh_ca                  (radm_rtlh_cplh_ca),
    .radm_rtlh_cpld_ca                  (radm_rtlh_cpld_ca),
    .xdlh_rtlh_fc_ack                   (xdlh_rtlh_fc_ack),
    .xadm_all_type_infinite             (xadm_all_type_infinite),


// ---- outputs ---------------
    .rtlh_rdlh_fci1_fci2                (rtlh_rdlh_fci1_fci2),
    .rtlh_xdlh_fc_req                   (rtlh_xdlh_fc_req),
    .rtlh_xdlh_fc_req_hi                (rtlh_xdlh_fc_req_hi),
    .rtlh_xdlh_fc_req_low               (rtlh_xdlh_fc_req_low),
    .rtlh_xdlh_fc_data                  (rtlh_xdlh_fc_data),
    .rtlh_parerr                        (rtlh_parerr),
    .rtlh_rfc_upd                       (rtlh_rfc_upd),
    .rtlh_rfc_data                      (rtlh_rfc_data),
    .rtlh_radm_data                     (rtlh_radm_data),
    .rtlh_radm_hdr                      (rtlh_radm_hdr),
    .rtlh_radm_dv                       (rtlh_radm_dv),
    .rtlh_radm_hv                       (rtlh_radm_hv),
    .rtlh_radm_eot                      (rtlh_radm_eot),
    .rtlh_radm_dwen                     (rtlh_radm_dwen),
    .rtlh_radm_malform_tlp_err          (rtlh_radm_malform_tlp_err),
    .rtlh_radm_ecrc_err                 (rtlh_radm_ecrc_err),
    .rtlh_radm_dllp_err                 (rtlh_radm_dllp_err),
    .rtlh_radm_ant_addr                 (rtlh_radm_ant_addr),
    .rtlh_radm_ant_rid                  (rtlh_radm_ant_rid),
    .rtlh_fc_init_status                (rtlh_fc_init_status),
    .rtlh_crd_not_rtn                   (rtlh_crd_not_rtn),
    .rtlh_req_link_retrain              (rtlh_req_link_retrain),
    .rtfcgen_ph_diff_vc0                (rtfcgen_ph_diff),
    .rtlh_overfl_err                    (rtlh_overfl_err)
    ,
    .rtlh_radm_pending                  (rtlh_radm_pending)
); //rtlh

// Layer 1 State


  // rmlh -> cdm
assign rmlh_rcvd_err               = pl_rmlh_rcvd_err;
assign rmlh_deskew_alignment_err   = pl_rmlh_deskew_alignment_err;
assign rmlh_rpipe_rxskipremoved    = pl_rmlh_rpipe_rxskipremoved;

  // smlh -> cdm
assign smlh_dir_linkw_chg_rising_edge = pl_smlh_dir_linkw_chg_rising_edge;
assign smlh_bw_mgt_status             = pl_smlh_bw_mgt_status;
assign smlh_link_auto_bw_status       = pl_smlh_link_auto_bw_status;
assign smseq_ts1_rcvd_pulse_bus = pl_smseq_ts1_rcvd_pulse_bus;
assign smseq_ts2_rcvd_pulse_bus = pl_smseq_ts2_rcvd_pulse_bus;


  // PM -> rmlh
  // rmlh -> rdlh
assign rmlh_rdlh_pkt_dv      = pl_rmlh_rdlh_pkt_dv    ;
assign rmlh_rdlh_tlp_start   = pl_rmlh_rdlh_tlp_start ;
assign rmlh_rdlh_dllp_start  = pl_rmlh_rdlh_dllp_start;
assign rmlh_rdlh_pkt_end     = pl_rmlh_rdlh_pkt_end   ;
assign rmlh_rdlh_pkt_edb     = pl_rmlh_rdlh_pkt_edb   ;
assign rmlh_rdlh_pkt_data    = pl_rmlh_rdlh_pkt_data  ;
assign rmlh_rdlh_pkt_err     = pl_rmlh_rdlh_pkt_err   ;
assign rmlh_rdlh_nak         = pl_rmlh_rdlh_nak       ;


//--------------------------------------
// Instance of smlh for PCIe
//--------------------------------------
// Improving synthesis timing closure to add register pipeline between u_pm_ctrl and u_smlh
wire pm_smlh_entry_to_l0s_i;            // PM commands LTSSM enter L0s
wire pm_smlh_l0s_exit_i;                // PM commands LTSSM exit L0s
wire pm_smlh_entry_to_l1_i;             // PM commands LTSSM enter L1
wire pm_smlh_l1_exit_i;                 // PM commands LTSSM exit L1
wire pm_smlh_l23_exit_i;                // PM Commands LTSSM exit L23
wire pm_smlh_entry_to_l2_i;             // PM Commands LTSSM enter L2
wire pm_smlh_prepare4_l123_i;           // PM Commands LTSSM to get preparing for entering L123

localparam DATAPATH_WIDTH_GEN5_PM_SMLH = 7;
delay_n

 #(N_DELAY_GEN5_FPGA, DATAPATH_WIDTH_GEN5_PM_SMLH) u_delay_gen5_pm_smlh
(
    .clk                           (core_clk),
    .rst_n                         (core_rst_n),
    .clear      (1'b0),
    .din        ({
                  pm_smlh_entry_to_l0s,
                  pm_smlh_l0s_exit    ,
                  pm_smlh_entry_to_l1 ,
                  pm_smlh_l1_exit     ,
                  pm_smlh_l23_exit    ,
                  pm_smlh_entry_to_l2 ,
                  pm_smlh_prepare4_l123
                 }),
    .dout       ({
                  pm_smlh_entry_to_l0s_i,
                  pm_smlh_l0s_exit_i    ,
                  pm_smlh_entry_to_l1_i ,
                  pm_smlh_l1_exit_i     ,
                  pm_smlh_l23_exit_i    ,
                  pm_smlh_entry_to_l2_i ,
                  pm_smlh_prepare4_l123_i
                 })
);

smlh

#(INST) u_smlh(
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .cfg_ts2_lid_deskew                 (cfg_ts2_lid_deskew),
    .cfg_support_part_lanes_rxei_exit   (cfg_support_part_lanes_rxei_exit),
    .cfg_scramble_dis                   (cfg_scramble_dis),
    .cfg_imp_num_lanes                  (cfg_imp_num_lanes),
    .cfg_n_fts                          (cfg_n_fts),
    .cfg_upstream_port                  (cfg_upstream_port),
    .cfg_root_compx                     (cfg_root_compx),
    .cfg_link_dis                       (cfg_link_dis),
    .cfg_link_retrain                   (cfg_link_retrain_i),
    .cfg_lpbk_en                        (cfg_lpbk_en),
    .cfg_reset_assert                   (cfg_reset_assert),
    .cfg_link_num                       (cfg_link_num),
    .cfg_forced_link_state              (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd               (cfg_forced_ltssm_cmd),
    .cfg_force_en                       (cfg_force_en),
    .cfg_elastic_buffer_mode            (cfg_elastic_buffer_mode),
    .cfg_fast_link_mode                 (cfg_fast_link_mode),
    .cfg_fast_link_scaling_factor       (cfg_fast_link_scaling_factor),
    .cfg_l0s_supported                  (cfg_l0s_supported),
    .cfg_link_capable                   (cfg_link_capable),
    .cfg_ext_synch                      (cfg_ext_synch),
    .cfg_gen1_ei_inference_mode         (cfg_gen1_ei_inference_mode),
    .cfg_select_deemph_mux_bus          (cfg_select_deemph_mux_bus),
    .cfg_lut_ctrl                       (cfg_lut_ctrl),
    .cfg_rxstandby_control              (cfg_rxstandby_control),
    .cfg_polarity_mode                  (cfg_polarity_mode),
    .cfg_rx_8_ts1s                      (cfg_rx_8_ts1s),
    .cfg_block_local_detect_eq_problem  (cfg_block_local_detect_eq_problem),
    .cfg_rxstandby_handshake_policy     (cfg_rxstandby_handshake_policy),
    .cfg_por_phystatus_mode             (cfg_por_phystatus_mode),
    .cfg_p1_entry_policy                (cfg_p1_entry_policy),
    .cfg_alt_protocol_enable            (cfg_alt_protocol_enable),
    .cfg_hw_autowidth_dis               (cfg_hw_autowidth_dis),
    .cfg_pl_multilane_control           (cfg_pl_multilane_control),
    .app_init_rst                       (app_init_rst),
    .app_ltssm_enable                   (app_ltssm_enable),
    .pm_smlh_entry_to_l0s               (pm_smlh_entry_to_l0s_i),
    .pm_smlh_l0s_exit                   (pm_smlh_l0s_exit_i),
    .pm_smlh_entry_to_l1                (pm_smlh_entry_to_l1_i),
    .pm_smlh_l1_exit                    (pm_smlh_l1_exit_i),
    .pm_smlh_l23_exit                   (pm_smlh_l23_exit_i),
    .pm_smlh_entry_to_l2                (pm_smlh_entry_to_l2_i),
    .pm_smlh_prepare4_l123              (pm_smlh_prepare4_l123_i),
    .xdlh_smlh_start_link_retrain       (xdlh_smlh_start_link_retrain),
    .rtlh_req_link_retrain              (rtlh_req_link_retrain),
    .rmlh_rcvd_idle                     (rmlh_rcvd_idle),
    .rmlh_all_sym_locked                (rmlh_all_sym_locked),
    .rmlh_rcvd_eidle_set                (rmlh_rcvd_eidle_set),
    .act_rmlh_rcvd_eidle_set            (act_rmlh_rcvd_eidle_set),
    .rmlh_deskew_alignment_err          (pl_rmlh_deskew_alignment_err),
    .rmlh_deskew_complete               (rmlh_deskew_complete),
    .rpipe_rxaligned                    (rpipe_rxaligned),
    .pm_current_data_rate_smlh_sqf      (pm_current_data_rate_smlh_sqf),
    .pm_current_data_rate_smlh_lnk      (pm_current_data_rate_smlh_lnk),
    .pm_current_data_rate_smlh_eq       (pm_current_data_rate_smlh_eq),
    .pm_current_data_rate_ltssm         (pm_current_data_rate_ltssm),
    .current_powerdown                  (current_powerdown),
    .rpipe_rxdata                       (rpipe_rxdata),
    .rpipe_rxdatak                      (rpipe_rxdatak),
    .rpipe_rxerror_dup                  (rpipe_rxerror_dup),
    .rpipe_rxdata_dv                    (rpipe_rxdata_dv),
    .rpipe_rxelecidle                   (rpipe_rxelecidle),
    .rpipe_rxdetected                   (rpipe_rxdetected),
    .rpipe_rxdetect_done                (rpipe_rxdetect_done),
    .rpipe_all_phystatus_deasserted     (rpipe_all_phystatus_deasserted),
    .rpipe_rxskipremoved                (pl_rmlh_rpipe_rxskipremoved),
    .phy_mac_phystatus                  (phy_mac_phystatus),
    .phy_mac_rxstandbystatus            (phy_mac_rxstandbystatus),
    .phy_mac_rxelecidle_noflip          (phy_mac_rxelecidle_noflip),
    .laneflip_lanes_active              (laneflip_lanes_active),
    .laneflip_rcvd_eidle_rxstandby      (laneflip_rcvd_eidle_rxstandby),
    .laneflip_pipe_turnoff              (laneflip_pipe_turnoff),
    .cfg_lane_en                        (cfg_lane_en),
    .rmlh_pkt_start                     (rmlh_pkt_start),
    .rdlh_dlcntrl_state                 (rdlh_rtlh_link_state),
    //gates
    .pm_current_powerdown_p1            ( pm_current_powerdown_p1 ),
    .pm_current_powerdown_p0            ( pm_current_powerdown_p0 ),
// ---------- Outputs --------
    .xmtbyte_ts_pcnt                    (xmtbyte_ts_pcnt),
    .xmtbyte_ts_data_diff               (xmtbyte_ts_data_diff),
    .xmtbyte_1024_ts_sent               (xmtbyte_1024_ts_sent),
    .xmtbyte_spd_chg_sent               (xmtbyte_spd_chg_sent),
    .xmtbyte_dis_link_sent              (xmtbyte_dis_link_sent),
    .xmtbyte_skip_sent                  (xmtbyte_skip_sent),
    .xmtbyte_ts1_sent                   (xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent                   (xmtbyte_ts2_sent),
    .xmtbyte_idle_sent                  (xmtbyte_idle_sent),
    .xmtbyte_eidle_sent                 (xmtbyte_eidle_sent),
    .xmtbyte_fts_sent                   (xmtbyte_fts_sent),
    .xmtbyte_cmd_is_data                (xmlh_cmd_is_data),
    .xmtbyte_txdata_dv                  (xmtbyte_txdata_dv),
    .xmtbyte_txdata                     (xmtbyte_txdata),
    .xmtbyte_txdatak                    (xmtbyte_txdatak),
    .xmtbyte_txelecidle                 (xmtbyte_txelecidle),
    .xmtbyte_txdetectrx_loopback        (xmtbyte_txdetectrx_loopback),

    // outputs
    .smlh_link_mode                     (cpcie_smlh_link_mode),
    .smlh_link_rxmode                   (cpcie_smlh_link_rxmode),
    .smlh_lanes_active                  (cpcie_smlh_lanes_active),
    .lpbk_eq_lanes_active               (lpbk_eq_lanes_active),
    .smlh_no_turnoff_lanes              (cpcie_smlh_no_turnoff_lanes),
    .smlh_lnknum_match_dis              (cpcie_smlh_lnknum_match_dis),
    .smlh_link_up                       (cpcie_smlh_link_up),
    .smlh_req_rst_not                   (cpcie_smlh_req_rst_not),
    .smlh_scrambler_disable             (cpcie_smlh_scrambler_disable),
    .smlh_ltssm_in_pollconfig           (cpcie_smlh_ltssm_in_pollconfig),
    .smlh_training_rst_n                (cpcie_smlh_training_rst_n),
    .smlh_link_disable                  (cpcie_smlh_link_disable),
    .smlh_link_in_training              (cpcie_smlh_link_in_training),
    .smlh_bw_mgt_status                 (cpcie_smlh_bw_mgt_status),
    .smlh_link_auto_bw_status           (cpcie_smlh_link_auto_bw_status),
    .smlh_ltssm_next                    (cpcie_smlh_ltssm_next),
    .smlh_ltssm_last                    (smlh_ltssm_last),
    .deskew_lanes_active                (cpcie_deskew_lanes_active),
    .mac_phy_rate                       (cpcie_mac_phy_rate),
    .mac_phy_rxpolarity                 (cpcie_mac_phy_rxpolarity),
    .mac_phy_rxstandby                  (cpcie_mac_phy_rxstandby),
    .smlh_rcvd_eidle_rxstandby          (cpcie_smlh_rcvd_eidle_rxstandby),
    .smlh_dir_linkw_chg_rising_edge     (cpcie_smlh_dir_linkw_chg_rising_edge),
    .smlh_ltssm_in_hotrst_dis_entry     (cpcie_smlh_ltssm_in_hotrst_dis_entry),
    .smseq_ts1_rcvd_pulse_bus           (cpcie_smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse_bus           (cpcie_smseq_ts2_rcvd_pulse_bus),
    .smseq_loc_ts2_rcvd_bus             (cpcie_smseq_loc_ts2_rcvd_bus),
    .smseq_in_skp_bus                   (cpcie_smseq_in_skp_bus),
    .smseq_fts_skp_do_deskew_bus        (cpcie_smseq_fts_skp_do_deskew_bus),
    .smlh_mod_ts_rcvd                   (smlh_mod_ts_rcvd),
    .mod_ts_data_rcvd                   (mod_ts_data_rcvd),
    .smlh_in_l0_l0s                     (cpcie_smlh_in_l0_l0s),
    .active_nb                          (cpcie_active_nb),
    .smlh_do_deskew                     (cpcie_smlh_do_deskew),
    .smlh_ltssm_state                   (cpcie_smlh_ltssm_state),
    .smlh_ltssm_state_xmlh              (cpcie_smlh_ltssm_state_xmlh),
    .smlh_ltssm_state_rmlh              (cpcie_smlh_ltssm_state_rmlh),
    .smlh_in_l0s                        (cpcie_smlh_in_l0s),
    .smlh_in_rl0s                       (cpcie_smlh_in_rl0s),
    .smlh_in_l0                         (cpcie_smlh_in_l0),
    .smlh_in_l1                         (cpcie_smlh_in_l1),
    .smlh_in_l1_p1                      (cpcie_smlh_in_l1_p1),
    .smlh_in_l23                        (cpcie_smlh_in_l23),
    .smlh_l123_eidle_timeout            (cpcie_smlh_l123_eidle_timeout),
    .smlh_ts_link_ctrl                  (cpcie_smlh_ts_link_ctrl),
    .smlh_rcvd_lane_rev                 (cpcie_smlh_rcvd_lane_rev),
    .smlh_ts_link_num                   (cpcie_smlh_ts_link_num),
    .smlh_ts_link_num_is_k237           (cpcie_smlh_ts_link_num_is_k237),
    .smlh_lanes_rcving                  (cpcie_smlh_lanes_rcving),
    .smlh_ts_rcv_err                    (cpcie_smlh_ts_rcv_err),
    .smlh_ts1_rcvd                      (cpcie_smlh_ts1_rcvd),
    .smlh_ts2_rcvd                      (cpcie_smlh_ts2_rcvd),
    .smlh_inskip_rcv                    (cpcie_smlh_inskip_rcv),
    .smlh_ts_lane_num_is_k237           (cpcie_smlh_ts_lane_num_is_k237),
    .latched_rcvd_eidle_set             (cpcie_latched_rcvd_eidle_set),
    .ltssm_rcvr_err_rpt_en              (cpcie_ltssm_rcvr_err_rpt_en),
    .ltssm_clear                        (cpcie_ltssm_clear),
    .ltssm_cmd                          (cpcie_ltssm_cmd),
    .l0s_state                          (),
    .ltssm_powerdown                    (cpcie_ltssm_powerdown),
    .ltssm_lpbk_master                  (cpcie_ltssm_lpbk_master),
    .ltssm_ts_auto_change               (cpcie_ltssm_ts_auto_change),
    .ltssm_xlinknum                     (cpcie_ltssm_xlinknum),
    .ltssm_xk237_4lannum                (cpcie_ltssm_xk237_4lannum),
    .ltssm_xk237_4lnknum                (cpcie_ltssm_xk237_4lnknum),
    .ltssm_ts_cntrl                     (cpcie_ltssm_ts_cntrl),
    .ltssm_mod_ts                       (ltssm_mod_ts),
    .ltssm_ts_alt_protocol              (cpcie_ltssm_ts_alt_protocol),
    .ltssm_no_idle_need_sent            (cpcie_ltssm_no_idle_need_sent),
    .ltssm_ts_alt_prot_info             (cpcie_ltssm_ts_alt_prot_info),
    .cxl_mode_enable                    (cxl_mode_enable),
    .ltssm_cxl_enable                   (cpcie_ltssm_cxl_enable), 
    .ltssm_cxl_mod_ts_phase1_rcvd       (cpcie_ltssm_cxl_mod_ts_phase1_rcvd),
    .ltssm_cxl_retimers_pre_mismatched  (cpcie_ltssm_cxl_retimers_pre_mismatched),
    .ltssm_cxl_flexbus_phase2_mismatched (cpcie_ltssm_cxl_flexbus_phase2_mismatched),
    .ltssm_cxl_ll_mod                   (ltssm_cxl_ll_mod),
    .ltssm_in_lpbk                      (cpcie_ltssm_in_lpbk),
    .ltssm_eidle_cnt                    (cpcie_ltssm_eidle_cnt),
    .ltssm_lpbk_slave_lut               (ltssm_lpbk_slave_lut),
    .muxed_n_fts                        (cpcie_muxed_n_fts),
    .latched_ts_nfts                    (cpcie_latched_ts_nfts),
    .smlh_debug_info_ei                 (cpcie_cxpl_debug_info_ei),
    .smlh_lane_flip_ctrl                (cpcie_smlh_lane_flip_ctrl),
    .latched_flip_ctrl                  (latched_flip_ctrl),
    .lpbk_lane_under_test               (lpbk_lane_under_test),
    .ltssm_lane_flip_ctrl               (cpcie_ltssm_lane_flip_ctrl)
    ,
    .smlh_fast_time_1ms                 (smlh_fast_time_1ms),
    .smlh_fast_time_2ms                 (smlh_fast_time_2ms),
    .smlh_fast_time_3ms                 (smlh_fast_time_3ms),
    .smlh_fast_time_4ms                 (smlh_fast_time_4ms),
    .smlh_fast_time_10ms                (smlh_fast_time_10ms),
    .smlh_fast_time_12ms                (smlh_fast_time_12ms),
    .smlh_fast_time_24ms                (smlh_fast_time_24ms),
    .smlh_fast_time_32ms                (smlh_fast_time_32ms),
    .smlh_fast_time_48ms                (smlh_fast_time_48ms),
    .smlh_fast_time_100ms               (smlh_fast_time_100ms)
); //smlh



// Layer 1 Transmit
wire unlinkup_mod_ts = cfg_lut_ctrl[0] & ~smlh_link_up & (pm_current_data_rate_others < `GEN3_RATE) & (smlh_ltssm_state == S_CFG_LANENUM_WAIT || smlh_ltssm_state == S_CFG_LANENUM_ACEPT || smlh_ltssm_state == S_CFG_COMPLETE); // TX mod_ts only in ~linkup & Gen1/2 rate
xmlh

#(INST) u_xmlh(
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .b_xplh_xmlh_sp                     (b_xplh_xmlh.slave_mp),
    .latched_smlh_link_up               (latched_smlh_link_up),
    .latched_flip_ctrl                  (latched_flip_ctrl),
    .smlh_lane_flip_ctrl                (cpcie_ltssm_lane_flip_ctrl),
    .ltssm_lpbk_slave_lut               (ltssm_lpbk_slave_lut),
    .muxed_n_fts                        (muxed_n_fts),
    .cfg_link_capable                   (cfg_link_capable),
    .cfg_fast_link_mode                 (cfg_fast_link_mode),
    .cfg_skip_interval                  (cfg_skip_interval),
    .cfg_ext_synch                      (cfg_ext_synch),
    .cfg_mod_ts                         (unlinkup_mod_ts),
    .phy_type                           (phy_type),
    .current_data_rate_xmt              (pm_current_data_rate_xmlh_xmt),
    .current_data_rate_scr              (pm_current_data_rate_xmlh_scr),
    .active_nb                          (active_nb),
    .phy_mac_phystatus                  (phy_mac_phystatus),
    .ltssm_ts_auto_change               (ltssm_ts_auto_change),
    .ltssm_xlinknum                     (ltssm_xlinknum),
    .ltssm_xk237_4lannum                (ltssm_xk237_4lannum),
    .ltssm_xk237_4lnknum                (ltssm_xk237_4lnknum),
    .ltssm_ts_cntrl                     (ltssm_ts_cntrl),
    .ltssm_mod_ts                       (ltssm_mod_ts),
    .ltssm_ts_alt_protocol              (cpcie_ltssm_ts_alt_protocol),
    .ltssm_no_idle_need_sent            (cpcie_ltssm_no_idle_need_sent),
    .ltssm_ts_alt_prot_info             (cpcie_ltssm_ts_alt_prot_info),
    .ltssm_eidle_cnt                    (ltssm_eidle_cnt),
    .ltssm_clear                        (ltssm_clear),
    .ltssm_cmd                          (ltssm_cmd),
    .ltssm_powerdown                    (ltssm_powerdown),
    .ltssm_lpbk_master                  (ltssm_lpbk_master),
    .ltssm_in_lpbk                      (ltssm_in_lpbk),
    .latched_ts_nfts                    (latched_ts_nfts),
    .smlh_link_mode                     (smlh_link_mode),
    .smlh_lanes_active                  (smlh_lanes_active),
    .lpbk_eq_lanes_active               (lpbk_eq_lanes_active),
    .power_saving_lanes_active          (power_saving_txlanes_active),
    .smlh_no_turnoff_lanes              (smlh_no_turnoff_lanes),
    .smlh_ltssm_state                   (smlh_ltssm_state_xmlh),
    .smlh_ltssm_next                    (smlh_ltssm_next),
    .smlh_ltssm_last                    (smlh_ltssm_last),
    .smlh_scrambler_disable             (smlh_scrambler_disable),

// ---- outputs ---------------

    .xmtbyte_ts_pcnt                    (xmtbyte_ts_pcnt),
    .xmtbyte_ts_data_diff               (xmtbyte_ts_data_diff),
    .xmtbyte_1024_ts_sent               (xmtbyte_1024_ts_sent),
    .xmtbyte_spd_chg_sent               (xmtbyte_spd_chg_sent),
    .xmtbyte_dis_link_sent              (xmtbyte_dis_link_sent),
    .xmlh_cmd_is_data                   (xmlh_cmd_is_data),
    .mac_phy_txdata                     (mac_phy_txdata),
    .mac_phy_txdatak                    (mac_phy_txdatak),
    .mac_phy_txdetectrx_loopback        (cpcie_mac_phy_txdetectrx_loopback),
    .mac_phy_txelecidle                 (mac_phy_txelecidle),
    .mac_phy_txcompliance               (cpcie_mac_phy_txcompliance),
    .xmtbyte_skip_sent                  (xmtbyte_skip_sent),
    .xmtbyte_ts1_sent                   (xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent                   (xmtbyte_ts2_sent),
    .xmtbyte_idle_sent                  (xmtbyte_idle_sent),
    .xmtbyte_eidle_sent                 (xmtbyte_eidle_sent),
    .xmtbyte_fts_sent                   (xmtbyte_fts_sent),
    .xmtbyte_txdata_dv                  (xmtbyte_txdata_dv),
    .xmtbyte_txdata                     (xmtbyte_txdata),
    .xmtbyte_txdatak                    (xmtbyte_txdatak),
    .xmtbyte_txelecidle                 (xmtbyte_txelecidle),
    .xmtbyte_txdetectrx_loopback        (xmtbyte_txdetectrx_loopback),
    .xpipe_powerdown                    (xmlh_powerdown)
); //xmlh

// Layer 2 Transmit
//



xdlh_64b

#(INST) u_xdlh(
    .b_xdlh_xplh_mp                     (b_xdlh_xplh.master_mp),
    .xmlh_xdlh_halt                     (b_xplh_xmlh.halt_in),
    .xdlh_xmlh_eot                      (b_xplh_xmlh.eot),
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .cfg_replay_timer_value             (cfg_replay_timer_value),
    .cfg_ack_freq                       (cfg_ack_freq),
    .cfg_ack_latency_timer              (cfg_ack_latency_timer),
    .cfg_other_msg_payload              (cfg_other_msg_payload),
    .cfg_other_msg_request              (cfg_other_msg_request),
    .cfg_corrupt_crc_pattern            (cfg_corrupt_crc_pattern),
    .cfg_flow_control_disable           (cfg_flow_control_disable),
    .cfg_acknack_disable                (cfg_acknack_disable),
    .pm_xdlh_enter_l1                   (pm_xdlh_enter_l1),
    .pm_xdlh_req_ack                    (pm_xdlh_req_ack),
    .pm_xdlh_enter_l23                  (pm_xdlh_enter_l23),
    .pm_xdlh_actst_req_l1               (pm_xdlh_actst_req_l1),
    .smlh_link_in_training              (smlh_link_in_training),
    .smlh_in_l0                         (tmp_smlh_in_l0),
    .pm_freeze_ack_timer                (1'b0),
    .current_data_rate                  (pm_current_data_rate_others),
    .phy_type                           (phy_type),
    .xtlh_xdlh_data                     (xtlh_xdlh_data),
    .xtlh_xdlh_dwen                     (xtlh_xdlh_dwen),
    .xtlh_xdlh_dv                       (xtlh_xdlh_dv),
    .xtlh_xdlh_sot                      (xtlh_xdlh_sot),
    .xtlh_xdlh_eot                      (xtlh_xdlh_eot),
    .xtlh_xdlh_badeot                   (xtlh_xdlh_badeot),
    .rdlh_link_up                       (rdlh_link_up),
    .rdlh_link_state                    (rdlh_rtlh_link_state),
    .rdlh_xdlh_rcvd_nack                (rdlh_xdlh_rcvd_nack),
    .rdlh_xdlh_rcvd_ack                 (rdlh_xdlh_rcvd_ack),
    .rdlh_xdlh_rcvd_acknack_seqnum      (rdlh_xdlh_rcvd_acknack_seqnum),
    .rdlh_xdlh_req2send_ack             (rdlh_xdlh_req2send_ack),
    .rdlh_xdlh_req2send_ack_due2dup     (rdlh_xdlh_req2send_ack_due2dup),
    .rdlh_xdlh_req2send_nack            (rdlh_xdlh_req2send_nack),
    .rdlh_xdlh_req_acknack_seqnum       (rdlh_xdlh_req_acknack_seqnum),
    .rtlh_xdlh_fc_req                   (rtlh_xdlh_fc_req),
    .rtlh_xdlh_fc_req_hi                (rtlh_xdlh_fc_req_hi),
    .rtlh_xdlh_fc_req_low               (rtlh_xdlh_fc_req_low),
    .rtlh_xdlh_fc_data                  (rtlh_xdlh_fc_data),
    .smlh_link_mode                     (smlh_link_mode),
    .smlh_in_rcvry                      (smlh_link_in_training),
// ---- outputs ---------------
    .xdlh_xtlh_halt                     (xdlh_xtlh_halt),
    .xdlh_rdlh_last_xmt_seqnum          (xdlh_rdlh_last_xmt_seqnum),
    .xdlh_rtlh_fc_ack                   (xdlh_rtlh_fc_ack),
    .xdlh_smlh_start_link_retrain       (xdlh_smlh_start_link_retrain),
    .xdlh_curnt_seqnum                  (xdlh_curnt_seqnum),
    .xdlh_retrybuf_not_empty            (xdlh_retrybuf_not_empty),
    .xdlh_not_expecting_ack             (xdlh_not_expecting_ack),
    .xdlh_xmt_pme_ack                   (xdlh_xmt_pme_ack),
    .xdlh_last_pmdllp_ack               (xdlh_last_pmdllp_ack),
    .xdlh_nodllp_pending                (xdlh_nodllp_pending),
    .xdlh_no_acknak_dllp_pending        (xdlh_no_acknak_dllp_pending),
    .xdlh_tlp_pending                   (xdlh_tlp_pending),
    .xdlh_retry_pending                 (xdlh_retry_pending),


    // Retry buffer external RAM interface
    .xdlh_retryram_addr                 (xdlh_retryram_addr),
    .xdlh_retryram_data                 (xdlh_retryram_data),
    .xdlh_retryram_we                   (xdlh_retryram_we),
    .xdlh_retryram_en                   (xdlh_retryram_en),
    .xdlh_retryram_par_chk_val          (xdlh_retryram_par_chk_val),
    .xdlh_retryram_halt                 (xdlh_retryram_halt),
    .retryram_xdlh_data                 (retryram_xdlh_data),
    .retryram_xdlh_depth                (retryram_xdlh_depth),
    .retryram_xdlh_parerr               (retryram_xdlh_parerr),


//   Performance change - 2p RAM I/F
//    .xdlh_retrysotram_addr              (xdlh_retrysotram_addr),
    .xdlh_retrysotram_waddr              (xdlh_retrysotram_waddr),
    .xdlh_retrysotram_raddr              (xdlh_retrysotram_raddr),
    .xdlh_retrysotram_data              (xdlh_retrysotram_data),
    .xdlh_retrysotram_en                (xdlh_retrysotram_en),
    .xdlh_retrysotram_we                (xdlh_retrysotram_we),
    .xdlh_retrysotram_par_chk_val       (xdlh_retrysotram_par_chk_val),
    .retrysotram_xdlh_data              (retrysotram_xdlh_data),
    .retrysotram_xdlh_parerr            (retrysotram_xdlh_parerr),
    .retrysotram_xdlh_depth             (retrysotram_xdlh_depth),
    .nak_scheduled                      (nak_scheduled),
    .xdlh_retry_req                     (xdlh_retry_req)
    ,
    .rbuf_pkt_cnt                       (xdlh_rbuf_pkt_cnt),
    .xdlh_match_pmdllp                  (xdlh_match_pmdllp),
    .xdlh_replay_timeout                (xdlh_replay_timeout_err),
    .xdlh_replay_timer                  (xdlh_replay_timer)
); //xdlh_64b


// Layer2 Physical Layer Packet Interface
xplh
 #(
  .INST (INST)
) u_xplh (
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .b_xdlh_xplh_sp             (b_xdlh_xplh.slave_mp),
  .b_xplh_xmlh_mp             (b_xplh_xmlh.master_mp)
);

// Layer 3 Transmit
xtlh

#(INST) u_xtlh (
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .rstctl_core_flush_req              (rstctl_core_flush_req),
    .xdlh_xtlh_halt                     (xdlh_xtlh_halt),
    .xadm_xtlh_hv                       (xadm_xtlh_hv),
    .xadm_xtlh_soh            (xadm_xtlh_soh),
    .xadm_xtlh_hdr                      (xadm_xtlh_hdr),
    .xadm_xtlh_dv                       (xadm_xtlh_dv),
    .xadm_xtlh_data                     (xadm_xtlh_data),
    .xadm_xtlh_dwen                     (xadm_xtlh_dwen),
    .xadm_xtlh_eot                      (xadm_xtlh_eot),
    .xadm_xtlh_bad_eot                  (xadm_xtlh_bad_eot),
    .xadm_xtlh_add_ecrc                 (xadm_xtlh_add_ecrc),
    .xadm_xtlh_vc                       (xadm_xtlh_vc),

    .pm_xtlh_block_tlp                  (pm_xtlh_block_tlp),
    .cfg_p2p_track_cpl_to               (cfg_p2p_track_cpl_to),
    .device_type                        (device_type),
// ---- outputs ---------------
    .xtlh_xadm_halt                     (xtlh_xadm_halt),

    .xtlh_xdlh_sot                      (xtlh_xdlh_sot),
    .xtlh_xdlh_data                     (xtlh_xdlh_data),
    .xtlh_xdlh_eot                      (xtlh_xdlh_eot),
    .xtlh_xdlh_dv                       (xtlh_xdlh_dv),
    .xtlh_xdlh_badeot                   (xtlh_xdlh_badeot),
    .xtlh_xdlh_dwen                     (xtlh_xdlh_dwen),

    .xtlh_sot_is_first          (xtlh_sot_is_first),
    .xtlh_eot_sot_eot           (xtlh_eot_sot_eot),
    .xtlh_badeot                (xtlh_badeot),
    .xtlh_first_badeot          (xtlh_first_badeot),
    .xtlh_eot_sot               (xtlh_eot_sot),

    .xtlh_xmt_cpl_ca                    (xtlh_xmt_cpl_ca),
    .xtlh_xmt_cpl_ur                    (xtlh_xmt_cpl_ur),
    .xtlh_xmt_cpl_poisoned              (xtlh_xmt_cpl_poisoned),
    .xtlh_xmt_wreq_poisoned             (xtlh_xmt_wreq_poisoned),
    .xtlh_tlp_pending                   (xtlh_tlp_pending),
    .xtlh_data_parerr                   (xtlh_data_parerr  ),
    // from xtlh for keeping track of completions and handling of completions
    .xtlh_xmt_tlp_done                  (xtlh_xmt_tlp_done),
    .xtlh_xmt_tlp_done_early            (xtlh_xmt_tlp_done_early),
    .xtlh_xmt_tlp_req_id                (xtlh_xmt_tlp_req_id),
    .xtlh_xmt_tlp_tag                   (xtlh_xmt_tlp_tag),
    .xtlh_xmt_tlp_attr                  (xtlh_xmt_tlp_attr),
    .xtlh_xmt_cfg_req                   (xtlh_xmt_cfg_req),
    .xtlh_xmt_memrd_req                 (xtlh_xmt_memrd_req),
    .xtlh_xmt_ats_req                   (xtlh_xmt_ats_req),
    .xtlh_xmt_atomic_req                (xtlh_xmt_atomic_req),
    .xtlh_xmt_tlp_tc                    (xtlh_xmt_tlp_tc),
    .xtlh_xmt_tlp_len_inbytes           (xtlh_xmt_tlp_len_inbytes),
    .xtlh_xmt_tlp_first_be              (xtlh_xmt_tlp_first_be),
    .xtlh_xadm_restore_enable           (xtlh_xadm_restore_enable),
    .xtlh_xadm_restore_capture          (xtlh_xadm_restore_capture),
    .xtlh_xadm_restore_tc               (xtlh_xadm_restore_tc),
    .xtlh_xadm_restore_type             (xtlh_xadm_restore_type),
    .xtlh_xadm_restore_word_len         (xtlh_xadm_restore_word_len)
); //xtlh




`ifndef SYNTHESIS
`endif // SYNTHESIS
endmodule
