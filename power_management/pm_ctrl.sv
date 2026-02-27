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
// ---    $DateTime: 2020/10/30 12:30:08 $
// ---    $Revision: #42 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_ctrl.sv#42 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description: top level PM control logic
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module pm_ctrl (
// ---- inputs ---------------
    xdlh_last_pmdllp_ack,
    xdlh_match_pmdllp,
    cfg_upd_aspm_ctrl,
    cfg_upd_aslk_pmctrl,
    rstctl_ltssm_enable,
    link_req_rst_not,
    app_clk_req_n,
    phy_clk_req_n,
    app_hold_phy_rst,
    aux_clk,
    pipe_clk,
    pwr_rst_n,
    rstctl_core_flush_req,
    radm_idle,
    upstream_port,
    switch_device,
    xdlh_nodllp_pending,
    xdlh_no_acknak_dllp_pending,
    xdlh_xmt_pme_ack,
    rdlh_rcvd_as_req_l1,
    rdlh_rcvd_pm_enter_l1,
    rdlh_rcvd_pm_enter_l23,
    rdlh_rcvd_pm_req_ack,
    smlh_link_up,
    smlh_link_in_training,
    all_dwsp_in_l1,
    all_dwsp_in_rl0s,
    upsp_in_rl0s,
    one_dwsp_exit_l1,
    one_dwsp_exit_l23,
    app_req_entr_l1,
    app_ready_entr_l23,
    app_req_exit_l1,
    xdlh_not_expecting_ack,
    xtlh_had_enough_credit,
    smlh_in_l0,
    smlh_in_l0s,
    smlh_in_rl0s,
    smlh_in_l1,
    smlh_in_l1_p1,
    smlh_in_l23,
    smlh_l123_eidle_timeout,
    latched_rcvd_eidle_set,
    sys_aux_pwr_det,
    xadm_tlp_pending,
    xadm_block_tlp_ack,
    xtlh_tlp_pending,
    xdlh_tlp_pending,
    xdlh_retry_pending,
    xtlh_no_fc_credit,
    cfg_aslk_pmctrl,
    cfg_l0s_entr_latency_timer,
    cfg_l1_entr_latency_timer,
    cfg_l1_entr_wo_rl0s,
    cfg_clk_pm_en,
    all_dwsp_rcvd_toack_msg,
    outband_pwrup_cmd,
    cfg_upd_pmcsr,
    cfg_upd_aux_pm_en,
    cfg_upd_req_id,
    cfg_pmstatus_clr,
    cfg_pmstate,
    cfg_pme_en,
    cfg_aux_pm_en,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    radm_pm_turnoff,
    radm_pm_asnak,
    radm_pm_to_ack,
    apps_pm_xmt_turnoff,
    apps_pm_xmt_pme,
    nhp_pme_det,
    cfg_upd_pme_cap,
    cfg_pme_cap,
    phy_mac_rxelecidle,
    current_data_rate,
    aux_clk_active,
    phy_if_cpcie_pclkreq_n,
    cfg_pl_l1_nowait_p1,
    cfg_pl_l1_clk_sel,
    cfg_phy_perst_on_warm_reset,
    cfg_phy_rst_timer,
    cfg_pma_phy_rst_delay_timer,
    cfg_pl_aux_clk_freq,
    pme_to_ack_grt,
    radm_trgt0_pending,
    lbc_active,
    pm_pme_grant,
    pme_turn_off_grt,
    perst_n,
    app_xfer_pending,
    dbi_cs,


    client0_tlp_hv,
    client1_tlp_hv,



    cfg_phy_control,
    mac_phy_powerdown,
    mac_phy_txelecidle,
    mac_phy_txdata,
    mac_phy_txdatak,
    mac_phy_txdetectrx_loopback,
    mac_phy_txcompliance,
    mac_phy_rxpolarity,
    ltssm_rxpolarity,
    mac_phy_width,
    mac_phy_pclk_rate,
    mac_phy_rxstandby,
    phy_mac_phystatus,
    phy_mac_rxstatus,
    core_rst_n,
    msg_gen_asnak_grt,


    rx_lane_flip_en,
    tx_lane_flip_en,
    smlh_lane_flip_ctrl,

    cfg_link_dis,
    cfg_link_retrain,
    cfg_lpbk_en,
    cfg_2nd_reset,
    cfg_plreg_reset,
    app_init_rst,
    cfg_directed_speed_change,
    cfg_directed_width_change,
    ven_msg_req,
    ven_msi_req,
    app_ltr_msg_req,
    app_unlock_msg,
    msg_gen_unlock_grant,
    cfg_link_capable,
    smlh_ltssm_state,
    cfg_elastic_buffer_mode,


// ---- outputs ---------------
    wake,
    local_ref_clk_req_n,
    pm_smlh_entry_to_l0s,
    pm_smlh_entry_to_l1,
    pm_smlh_entry_to_l2,
    pm_smlh_prepare4_l123,
    pm_smlh_l0s_exit,
    pm_smlh_l1_exit,
    pm_smlh_l23_exit,
    pm_xtlh_block_tlp,
    pm_block_all_tlp,
    pm_l1_aspm_entr,
    pm_radm_block_tlp,
    pm_xdlh_enter_l1,
    pm_xdlh_req_ack,
    pm_xdlh_enter_l23,
    pm_xdlh_actst_req_l1,
    pm_freeze_fc_timer,
    pm_freeze_cpl_timer,
    pm_req_dwsp_turnoff,
    pm_xmt_asnak,
    pm_xmt_turnoff,
    pm_xmt_to_ack,
    pm_xmt_pme,
    pm_turnoff_timeout,
    pm_linkst_in_l0,
    pm_linkst_in_l1,
    pm_linkst_in_l2,
    pm_linkst_l2_exit,
    pm_linkst_in_l3,
    pm_linkst_in_l0s,
    pm_pme_en,
    pm_pme_en_split,
    pm_status,
    pm_aux_pm_en,
    pm_aux_pm_en_split,
    pm_bus_num,
    pm_dev_num,
    pm_int_phy_powerdown,
    pm_curnt_state,
    pm_ltssm_enable,
    pm_current_data_rate,
    pm_req_sticky_rst,
    pm_req_core_rst,
    pm_req_non_sticky_rst,
    pm_sel_aux_clk,
    pm_en_core_clk,
    pm_en_aux_clk_g,
    pm_req_phy_rst,
    pm_req_phy_perst,
    pm_master_state,
    pm_slave_state,
    phy_if_cfg_phy_control,
    phy_if_cpcie_powerdown,
    phy_if_cpcie_txelecidle,
    pm_int_txelecidle,
    phy_if_cpcie_txdata,
    phy_if_cpcie_txdatak,
    phy_if_cpcie_txdetectrx_loopback,
    phy_if_cpcie_txcompliance,
    phy_if_cpcie_rxpolarity,   
    phy_if_cpcie_width,
    phy_if_cpcie_pclk_rate,
    phy_if_cpcie_rxstandby,
    phy_if_cpcie_txdatavalid,
    phy_if_cpcie_phy_type,
    pm_pmstate,
    sqlchd_rxelecidle,
    pm_aux_clk_ft,
    pm_sys_aux_pwr_det_ft,
    pm_aux_clk_active_ft,

    pm_xadm_client0_tlp_hv
    ,
    pm_xadm_client1_tlp_hv

    ,
    pm_dbi_cs_ft
    ,
    pm_rx_lane_flip_ctrl,
    pm_tx_lane_flip_ctrl,
    pm_rx_pol_lane_flip_ctrl
    ,
    pm_init_rst,
    pm_unlock_msg_req
    ,
    pm_smlh_link_retrain
    ,
    phy_if_elasticbuffermode
    ,
    pm_l1_entry_started
    ,
    msg_gen_hv,
    lbc_cpl_hv
    ,
    pm_powerdown_status,
    cfg_force_powerdown
    ,pm_current_powerdown_p1
    ,pm_current_powerdown_p0
);

parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter PM_SYNC_DEPTH = 2;
parameter PM_MST_WD     = 5;
parameter PM_SLV_WD     = 5;
parameter NL            = `CX_NL;
parameter L2NL          = 1;
parameter RXNL          = `CM_RXNL ;            // Max number of lanes supported (Rx)
parameter NF            = `CX_NFUNC;
parameter NFUNC_WD      = `CX_NFUNC_WD;
parameter NVC           = `CX_NVC;
parameter NVC_XALI_EXP  = `CX_NVC_XALI_EXPANSION;      // Max number of Virtual Channels used on Xali Expansion
parameter BUSNUM_WD     = 1;        // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD     = 1;        // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter CPL_LUT_DEPTH = `CX_MAX_TAG + 1;
parameter PHY_NB = 1;
parameter TX_COEF_WD = 18;
parameter PHY_RATE_WD = (`CX_GEN5_SPEED_VALUE == 1) ? 3 : (`CX_GEN3_SPEED_VALUE == 1) ? 2 : 1;
parameter PHY_WIDTH_WD = `CX_PHY_WIDTH_WD;
parameter PDWN_WIDTH = 2;
localparam [PDWN_WIDTH - 1 : 0] P0S  = {2'b00, `P0S};
localparam [PDWN_WIDTH - 1 : 0] P0   = {2'b00, `P0};
localparam [PDWN_WIDTH - 1 : 0] P1   = {2'b00, `P1};
localparam [PDWN_WIDTH - 1 : 0] P2   = {2'b00, `P2};
localparam DEFAULT_PHY_PERST_ON_WARM_RESET = `DEFAULT_PHY_PERST_ON_WARM_RESET;
parameter ORIG_DATA_WD = PHY_NB * 8;
parameter SERDES_DATA_WD = PHY_NB * 10;
parameter PIPE_DATA_WD = (`CX_PIPE_SERDES_ARCH_VALUE) ? (NL * SERDES_DATA_WD) : (NL * ORIG_DATA_WD);
parameter TX_DATAK_WD = NL * PHY_NB;
parameter TX_DEEMPH_WD = 1;
parameter PHY_TXEI_WD = `CX_PHY_TXEI_WD;

localparam NL_X2 = NL * 2;
localparam L0S_LATENCY_TIMER_WD = 3;
localparam L1_LATENCY_TIMER_WD = 3;
localparam ASLK_CTRL_WD = (NF * 2);
parameter PL_AUX_CLK_FREQ_WD = `CX_PL_AUX_CLK_FREQ_WD;
localparam P_R_WD = `PCLK_RATE_WD;

input                   xdlh_last_pmdllp_ack;          // Layer1 acknowledge that the last PM DLLP has been sent
input [3:0]             xdlh_match_pmdllp;              // Layer2 has transmitted a PM DLLP
                                                        // 3: PM_Enter_L23 
                                                        // 2: PM_ENter_L1
                                                        // 1: PM_Active_State_Request_L1
                                                        // 0: PM_Request_Ack
input [(NF - 1) : 0]    cfg_upd_aslk_pmctrl;            // CDM update of Active state link pmctrl
input                   cfg_upd_aspm_ctrl;              // CDM update of ASPM control registers
input                   rstctl_ltssm_enable;            // Application enables LTSSM
input                   link_req_rst_not;               // When set to 0 LTSSM requests reset due to surprise link down
input                   app_clk_req_n;                  // Application request ref clock removal
input                   phy_clk_req_n;                  // PHY acknowledge that it is ready for ref clock removal
input                   app_hold_phy_rst;               // Application requests to hold PHY reset
input                   rstctl_core_flush_req;
input                   radm_idle;                      // Idle indication from the RADM
input                   aux_clk;                        // auxiliary clock
input                   pwr_rst_n;                      // power on reset
input                   pipe_clk;                       // PCLK for sampling Phystatus

input                   upstream_port;                  // upstream port
input                   switch_device;                  // Switch device
input                   xdlh_nodllp_pending;            // XDLH has no dllp pending
input                   xdlh_no_acknak_dllp_pending;    // XDLH has no ACK/NAK DLLP pending
input                   xdlh_xmt_pme_ack;               // Txmt ACK PME
input                   rdlh_rcvd_pm_enter_l1;          // Rcvd DLLP PM_ENTER_L1
input                   rdlh_rcvd_pm_enter_l23;         // Rcvd DLLP PM_ENTER_123
input                   rdlh_rcvd_pm_req_ack;           // Rcvd DLLP PM_EQ_ACK

// for switch only
input                   all_dwsp_rcvd_toack_msg;        // All downstream ports received PM_TO_ACK message
input                   all_dwsp_in_l1;                 // All downstream ports are in L1
input                   all_dwsp_in_rl0s;               // All downstream ports are in RL0s
input                   upsp_in_rl0s;                   // All upstream ports are in RL0s
input                   one_dwsp_exit_l1;               // One of the downstream ports exits L1
input                   one_dwsp_exit_l23;              // One of the downstream ports exits L23

// Config
input   [(L0S_LATENCY_TIMER_WD - 1) : 0]  cfg_l0s_entr_latency_timer;     // L0s enter latency
input   [(L1_LATENCY_TIMER_WD - 1) : 0]   cfg_l1_entr_latency_timer;      // L1 enter latency
input                                     cfg_l1_entr_wo_rl0s;            // Start L1 timer without rL0s
input   [(ASLK_CTRL_WD - 1) :0]           cfg_aslk_pmctrl;                // Active Link PM enable
input   [NF-1:0]                          cfg_upd_pmcsr;                  // PMCSR is written
input   [NF-1:0]                          cfg_upd_aux_pm_en;              // AUX Power PM enable
input                                     cfg_upd_req_id;                 // update bus/dev/fun number, here 7:0 is set to support the max func number allowed in spec.
input   [NF-1:0]        cfg_pmstatus_clr;               // PM status bits are cleared
input   [(3*NF)-1:0]    cfg_pmstate;                    // PM state
input   [NF-1:0]        cfg_pme_en;                     // PME_Enable
input   [(5*NF)-1:0]    cfg_pme_cap;                    // PME Capability
input   [NF-1:0]        cfg_upd_pme_cap;                // Update PME Capability field
input   [NF-1:0]        nhp_pme_det;                    // Native Plug PM event detected
input   [7:0]           cfg_pbus_num;                   // Configured Primary bus number used to store for AUX power
input   [4:0]           cfg_pbus_dev_num;               // Configured Device number used to store for AUX power
input   [NF-1:0]        cfg_aux_pm_en;                  // aux power pm enable
input                   cfg_clk_pm_en;                  // enables the clock request# signal to be deasserted at L1 and L23 state
input                   app_req_entr_l1;                // Provide a capability for applications to request PM state to enter L1. This is only effective when ASPM of L1 is enabled.
input                   app_ready_entr_l23;             // inidcates that application is ready for L23 transition based on D3 programmed
input                   app_req_exit_l1;                // Provide a capability for applications to request PM state to exit L1. This is only effective when ASPM of L1 is enabled.

// from CXPL
input                   xadm_tlp_pending;               // XADM has no TLP pending in its datapath 
input                   xadm_block_tlp_ack;             // XADM block TLP request acknowledged
input                   xtlh_tlp_pending;               // XTLH has no TLP pending in its datapath
input                   xdlh_tlp_pending;               // XDLH has no TLP pending in its datapath
input                   xdlh_retry_pending;             // XDLH has TLP pending for replay in its datapath
input   [NVC-1:0]       xtlh_no_fc_credit;              // XTLH has no FC credits available
input                   xdlh_not_expecting_ack;         // Transmiter has received all its ACKs for all transmitted TLPs
input   [NVC-1:0]       xtlh_had_enough_credit;         // XTLH had enough credit
input                   rdlh_rcvd_as_req_l1;            // Received AS REQ L1

// handshake with Link state
input                   smlh_in_l0;                     // XMLH in l0
input                   smlh_in_l0s;                    // XMLH in l0s
input                   smlh_in_rl0s;                   // XMLH in rL0s
input                   smlh_in_l1;                     // XMLH in L1
input                   smlh_in_l1_p1;                  // XMLH in L1 with powerdown P1
input                   smlh_in_l23;                    // XMLH in L23
input                   smlh_l123_eidle_timeout;        // XMLH timeout waiting for EIDLE
input                   latched_rcvd_eidle_set;         // 
input                   smlh_link_up;                   // link is up
input                   smlh_link_in_training;          // LTSSM is entering Recovery or Cfg


// from RADM
input                   radm_pm_turnoff;                // Received PM TURN OFF(only downstream port)
input                   radm_pm_to_ack;                 // Received PM TO ACK message (received by RC or downstream port)
input                   radm_pm_asnak;                  // Received PM AS NAK  (only upstream port)

// from Application side
input                   sys_aux_pwr_det;                 // AUX Power is detected
input                   apps_pm_xmt_turnoff;            // for switch application
input   [NF-1:0]        apps_pm_xmt_pme;                // for switch application
input   [NF-1:0]        outband_pwrup_cmd;              // out band power is up command such as WOL

// phy mac rxelecidle
input   [NL-1:0]        phy_mac_rxelecidle;             // PHY is in EIDLE

input   [2:0]           current_data_rate;              // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4
input                   aux_clk_active; // muxed aux clk has switched to low frequency clock, used when entering L1 to stall progression into L1 substates 
output  [1 : 0]         phy_if_cpcie_pclkreq_n;
input                   cfg_pl_l1_nowait_p1; // Port logic bit to control L1 entry mode
input                   cfg_pl_l1_clk_sel; // Port logic bit to select aux_clk source in L1
input                   cfg_phy_perst_on_warm_reset; // PMC drive pm_req_phy_perst when warm reset
input [17:0]            cfg_phy_rst_timer;               // PHY RST timer
input [5:0]             cfg_pma_phy_rst_delay_timer;     // PMA reset to PIPE reset delay timer
input   [PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;   // programmable auxiliary clock frequency
input                   pme_to_ack_grt;              // PME Turnoff Ack request has been granted
input                   radm_trgt0_pending;          // A TLP is enroute to TRGT0, delay L1 entry
input                   lbc_active;                  // The LBC may require a CPL to be sent, stop L1 timer
input   [NF-1:0]        pm_pme_grant;                // PM PME grant
input                   pme_turn_off_grt;            // PM Turn Off grant
input                   perst_n;
input                   app_xfer_pending;
// Power Gating exit conditions
input                 dbi_cs;

input [NVC_XALI_EXP-1:0] client0_tlp_hv;
input [NVC_XALI_EXP-1:0] client1_tlp_hv;


input                 msg_gen_hv;
input                 lbc_cpl_hv;

output wire [(2 * PDWN_WIDTH) - 1 : 0]  pm_powerdown_status;
input                                   cfg_force_powerdown;



input [31:0]                     cfg_phy_control;
input [(PDWN_WIDTH - 1) : 0]     mac_phy_powerdown;
input [(NL*PHY_TXEI_WD - 1) : 0] mac_phy_txelecidle;
input [(PIPE_DATA_WD - 1) : 0]  mac_phy_txdata;
input [(TX_DATAK_WD - 1) : 0]   mac_phy_txdatak;
input [(NL - 1) : 0]            mac_phy_txdetectrx_loopback;
input [(NL - 1) : 0]            mac_phy_txcompliance;
input [(NL - 1) : 0]            mac_phy_rxpolarity;
input [(NL - 1) : 0]            ltssm_rxpolarity;
input [(PHY_WIDTH_WD -1) : 0]   mac_phy_width;
input [P_R_WD-1 : 0]            mac_phy_pclk_rate;
input [(NL - 1) : 0]            mac_phy_rxstandby;
input [(NL - 1) : 0]            phy_mac_phystatus;
input [((NL*3) - 1) : 0]        phy_mac_rxstatus;
input                           core_rst_n;             // Core reset
input                           msg_gen_asnak_grt;  // PM_Active_State_Nak granted
input                           rx_lane_flip_en; // Lane flip control
input                           tx_lane_flip_en; // Lane flip control
input [L2NL-1:0]                smlh_lane_flip_ctrl; // Lane flip control

input                           cfg_link_dis; // disable the link
input                           cfg_link_retrain; // link retrain request
input                           cfg_lpbk_en; // loopback enable request
input                           cfg_2nd_reset; // secondary reset
input                           cfg_plreg_reset; // port logic secondary reset
input                           app_init_rst; // application request hot reset
input                           cfg_directed_speed_change; // directed speed change
input                           cfg_directed_width_change; // directed width change
input                           ven_msg_req; // vendor message request
input                           ven_msi_req; // vendor msi message request
input                           app_ltr_msg_req; // LTR message request
input                           app_unlock_msg; // Unlock message request
input                           msg_gen_unlock_grant; // msg_gen grants unlock message
input                           cfg_elastic_buffer_mode; // Elastic Buffer mode
input [5:0]                     cfg_link_capable; // PL LINK_CAPABLE register, indicate used lanes at reset
input [5:0]                     smlh_ltssm_state; // LTSSM state
// ------------- Outputs ---------------
output                    wake;                         // indicate application to wakeup from l2
output                    local_ref_clk_req_n;                      // indicates to PHY the states that required clock. When it inidcates not required clock, it is imporatant to make sure that PHY is specially designed for this.

// to CXPL
output                    pm_smlh_entry_to_l0s;           // PMC directs XMLH to entry to L0s
output                    pm_smlh_l0s_exit;               // PMC directs XMLH to exit L0s
output                    pm_smlh_entry_to_l1;            // PMC directs XMLH entry to L1
output                    pm_smlh_l1_exit;                // PMC directs XMLH L1 EXIT
output                    pm_smlh_l23_exit;               // PMC directs XMLH L23 EXIT
output                    pm_smlh_entry_to_l2;            // PMC directs XMLH entry to L2
output                    pm_smlh_prepare4_l123;            // PMC directs XMLH entry to L3
output                    pm_xtlh_block_tlp;              // PMC directs XTLH to block TLP
output                    pm_block_all_tlp;               // PMC directs transmit modules to block all tlps
output                    pm_l1_aspm_entr;                // 
output  [NF-1:0]          pm_radm_block_tlp;              // PMC directs RTLH to block TLP
output                    pm_freeze_fc_timer;             // Freeze FC timer
output                    pm_freeze_cpl_timer;            // Freeze completion timout timer
output                    pm_xdlh_enter_l1;               // XDLH to send ENTER_L1_DLLP
output                    pm_xdlh_req_ack;                // XDLH to send REQ_ACK_DLLP
output                    pm_xdlh_enter_l23;              // XDLH to send L23_DLLP
output                    pm_xdlh_actst_req_l1;           // XDLH to send AS_REQ_L1_DLLP

// to CDM
output                    pm_xmt_asnak;                   // to send AS_NAK MSG TLP  (only for upstream port)
output                    pm_xmt_turnoff;                 // to send TURNOFF MSG TLP (only for downstream)
output                    pm_turnoff_timeout;             // Indicates to application of RC or downstream port of a swtich that PM turnoff timeout has occurred
output  [NF-1:0]          pm_xmt_to_ack;                  // to send PM_TO_ACK TLP (only for upstream port)
output  [NF-1:0]          pm_xmt_pme;                     // to send PM_PME TLP
output  [NF-1:0]          pm_status;                      // PM status register
output  [NF-1:0]          pm_pme_en;                      // PM PME_EN register
output  [NF-1:0]          pm_pme_en_split;                // PM PME_EN register to be fed back internally in the core
output  [NF-1:0]          pm_aux_pm_en;                   // AUX PM EN register
output  [NF-1:0]          pm_aux_pm_en_split;             // AUX PM EN split port
output  [BUSNUM_WD -1:0]  pm_bus_num;
output  [DEVNUM_WD -1:0]  pm_dev_num;

// for switch only
output                    pm_req_dwsp_turnoff;
output                    pm_linkst_in_l0;
output                    pm_linkst_in_l1;
output                    pm_linkst_in_l2;
output                    pm_linkst_l2_exit;
output                    pm_linkst_in_l3;
output                    pm_linkst_in_l0s;

output  [(PDWN_WIDTH - 1) : 0]         pm_int_phy_powerdown;   // PM PHY powerdown 2 LSB's for freq_step and pipe_loopback 
output  [2:0]           pm_curnt_state;                 // PM current state
output [(PM_MST_WD - 1):0]  pm_master_state;
output [(PM_SLV_WD - 1):0]  pm_slave_state;
output                  pm_req_sticky_rst;
output                  pm_req_core_rst;
output                  pm_req_non_sticky_rst;
output                  pm_req_phy_rst;
output                  pm_req_phy_perst;
output                  pm_ltssm_enable; // The application enable for the LTSSM shadowed in the always on domain
output  [2:0]           pm_current_data_rate;   // Current data rate shadowed in the always on domain
output                  pm_sel_aux_clk; // Select the slow clock for aux_clk
output                  pm_en_core_clk; // enable the core_clk
output                  pm_en_aux_clk_g; // Enable the gate aux clock that is used for CDM

output  [31:0]                      phy_if_cfg_phy_control;
output  [(PDWN_WIDTH - 1) : 0]      phy_if_cpcie_powerdown;
output  [(NL*PHY_TXEI_WD - 1) : 0]  phy_if_cpcie_txelecidle;
output  [(NL - 1) : 0]  pm_int_txelecidle;
output  [(PIPE_DATA_WD - 1) : 0]    phy_if_cpcie_txdata;
output  [(TX_DATAK_WD - 1) : 0]     phy_if_cpcie_txdatak;
output  [(NL - 1) : 0]              phy_if_cpcie_txdetectrx_loopback;
output  [(NL - 1) : 0]              phy_if_cpcie_txcompliance;
output  [(NL - 1) : 0]              phy_if_cpcie_rxpolarity;
output  [(PHY_WIDTH_WD -1) : 0]     phy_if_cpcie_width;
output  [P_R_WD-1 : 0]              phy_if_cpcie_pclk_rate;
output  [(NL - 1) : 0]              phy_if_cpcie_rxstandby;
output  [(NL - 1) : 0]              phy_if_cpcie_txdatavalid;
output                              phy_if_cpcie_phy_type;
output  [((3*NF) - 1) : 0]          pm_pmstate;
output  [(NL - 1) : 0]              sqlchd_rxelecidle;
output                              pm_aux_clk_ft; // Aux clock fed through pm_ctrl
output                              pm_sys_aux_pwr_det_ft; // sys_aux_pwr_det fed through pm_ctrl
output                              pm_aux_clk_active_ft; // aux_clk_active fed through pm_ctrl
output [NVC_XALI_EXP-1:0]           pm_xadm_client0_tlp_hv; // client0_tlp_hv fed through pm_ctrl
output [NVC_XALI_EXP-1:0]           pm_xadm_client1_tlp_hv; // client1_tlp_hv fed through pm_ctrl
output                              pm_dbi_cs_ft; // dbi_cs fed through pm_ctrl
output                              pm_init_rst; // pm hot reset request
output                              pm_unlock_msg_req; // pm unlock message request
output              pm_smlh_link_retrain;
output              phy_if_elasticbuffermode;
output              pm_l1_entry_started; // L1 entry process started


output [L2NL - 1 : 0]              pm_rx_lane_flip_ctrl;
output [L2NL - 1 : 0]              pm_tx_lane_flip_ctrl;
output [L2NL - 1 : 0]              pm_rx_pol_lane_flip_ctrl;


output                             pm_current_powerdown_p1;
output                             pm_current_powerdown_p0;


`ifndef SNPS_PCIE_SATB
//
// -----------------------------------------------------------------------
wire              pm_l1_entry_started; 
wire              pm_linkst_sel_aux_clk;
wire              pm_linkst_en_core_clk;
wire              pm_l1_cpm_exit;
wire              pm_smlh_link_retrain;
wire              phy_if_elasticbuffermode;
wire              pm_active_next_l1;


wire            pm_l1_in_progress;

wire [1 : 0]    phy_if_cpcie_pclkreq_n;
wire [31:0]                      phy_if_cfg_phy_control;
wire [(PDWN_WIDTH - 1) : 0]      int_cpcie_powerdown;
wire [(NL*PHY_TXEI_WD - 1) : 0]  int_cpcie_txelecidle;
wire [(PDWN_WIDTH - 1) : 0]      phy_if_cpcie_powerdown;
wire [(PDWN_WIDTH - 1) : 0]      phy_if_cpcie_pm_powerdown; //from pm_active
wire [(NL*PHY_TXEI_WD - 1) : 0]  phy_if_cpcie_txelecidle;
wire [(NL - 1) : 0]              pm_int_txelecidle;
wire [(PIPE_DATA_WD - 1) : 0]    phy_if_cpcie_txdata;
wire [(TX_DATAK_WD - 1) : 0]     phy_if_cpcie_txdatak;
wire [(NL - 1) : 0]              phy_if_cpcie_txdetectrx_loopback;
wire [(NL - 1) : 0]              phy_if_cpcie_txcompliance;
wire [(NL - 1) : 0]              phy_if_cpcie_rxpolarity;
wire [(PHY_WIDTH_WD -1) : 0]     phy_if_cpcie_width;
wire [P_R_WD-1 : 0]              phy_if_cpcie_pclk_rate;
wire [(NL - 1) : 0]              phy_if_cpcie_rxstandby;
wire [(NL - 1) : 0]              phy_if_cpcie_txdatavalid;
assign phy_if_cpcie_txdatavalid = {NL{1'b1}};
wire                             phy_if_cpcie_phy_type;



wire                    pm_en_aux_clk_g;
wire                    pm_sync_perst_n; // perst_n synchronized to aux_clk
wire                    pm_phy_rst_done; // PHY out of reset after exit from L2
wire                    pm_core_rst_done;
wire                    pm_det_l2; // core is in L2 state with main power removed
wire    [1:0]           pm_phy_pclkreq_n;

wire                    pm_linkst_in_l0;
wire                    pm_linkst_in_l1;
wire                    pm_linkst_in_l2;
wire                    pm_linkst_l2_exit;
wire                    pm_linkst_in_l3;
wire                    pm_linkst_in_l23rdy;
wire                    pm_linkst_in_l0s;

wire                    link_reactivate;
wire                    int_pme_nego_done;
wire                    pm_smlh_l0s_exit;
wire                    pm_smlh_entry_to_l0s;
wire    [NF-1:0]        pm_dstate_d0;
wire    [NF-1:0]        pm_dstate_d1;
wire    [NF-1:0]        pm_dstate_d2;
wire    [NF-1:0]        pm_dstate_d3;
wire    [2:0]           pm_curnt_state;
wire                    pm_xdlh_enter_l23;              // XDLH to send L23_DLLP
wire                    pm_pme_exit_l1;
wire                    pm_l2_entry_flag;

wire                    pm_block_all_tlp_int;
wire                    local_ref_clk_req_n;
wire                    pm_set_phy_p1;
wire                    pm_req_sticky_rst;
wire                    pm_req_core_rst;
wire                    pm_req_phy_rst;
wire                    pm_req_phy_perst;
wire                    pm_req_non_sticky_rst;
wire                    pm_perst_powerdown;

wire                    shadow_smlh_link_up;
wire                    pm_ltssm_enable;
wire    [2:0]           pm_current_data_rate;   // Current data rate shadowed in the always on domain
wire                    pm_sel_aux_clk;
wire                    pm_en_core_clk;

wire                    pmu_sel_aux_clk;
wire                    pm_wake_xfer_pending;
wire                    pm_wake_l1_exit;
wire                    pm_wake_dbi_pending;
wire                    pm_wake_block_pg;
wire                    pm_wake_l1_pg_ack;
wire                    pm_wake_l1_pg_exit;
wire  [(L0S_LATENCY_TIMER_WD - 1) : 0]  pm_l0s_entr_latency_timer;
wire  [(L1_LATENCY_TIMER_WD - 1) : 0]   pm_l1_entr_latency_timer;
wire                                    pm_l1_entr_wo_rl0s;
wire  [(ASLK_CTRL_WD - 1) : 0]          pm_aslk_pmctrl;
wire  [(NF - 1) : 0]                    pm_aux_pm_en;
wire  [(NF - 1) : 0]                    pm_aux_pm_en_split;
wire  [(NF - 1) : 0]                    pm_pme_en;
wire  [(NF - 1) : 0]                    pm_pme_en_split;
wire  [(BUSNUM_WD - 1) : 0]             pm_bus_num;
wire  [(DEVNUM_WD - 1) : 0]             pm_dev_num;
wire  [((5*NF) - 1) : 0]                pm_pme_cap;
wire  [((3*NF) - 1) : 0]                pm_pmstate;
wire                                    pm_clk_pm_en;
wire                                    pm_pl_l1_nowait_p1;
wire                                    pm_pl_l1_clk_sel;
wire  [(PL_AUX_CLK_FREQ_WD - 1) : 0]    pm_pl_aux_clk_freq;
wire                                    pm_wake_req_exit_l0s;
wire                                    pm_wake_tlp_pending;
wire  [(NL - 1) : 0]                    sqlchd_rxelecidle;
wire                                    pm_aux_clk_ft;
wire                                    pm_sys_aux_pwr_det_ft;
wire                                    pm_aux_clk_active_ft;
wire [NVC_XALI_EXP-1:0]                 pm_xadm_client0_tlp_hv; // client0_tlp_hv fed through pm_ctrl
wire [NVC_XALI_EXP-1:0]                 pm_xadm_client1_tlp_hv; // client1_tlp_hv fed through pm_ctrl
wire                                    pm_dbi_cs_ft;

wire [L2NL - 1 : 0]                     pm_rx_lane_flip_ctrl;
wire [L2NL - 1 : 0]                     pm_tx_lane_flip_ctrl;
wire [L2NL - 1 : 0]                     pm_rx_pol_lane_flip_ctrl;
wire pm_rst_sel_aux_clk;

wire                                    pm_init_rst; // pm hot reset request
wire                                    pm_unlock_msg_req; // pm unlock message request
wire  [(NL - 1) : 0]                    int_pm_rxelecidle;

wire [5:0]                              pm_link_capable; 
wire [17:0]                             pm_phy_rst_timer;
wire [5:0]                              pm_pma_phy_rst_delay_timer;
wire                                    phystatus_pclk_ready;
// ----------------------------------------------------------------------------
// PM clock control
// ----------------------------------------------------------------------------
pm_clk_control
 u_pm_clk_control(
  // Inputs
  .aux_clk                    (aux_clk),
  .pwr_rst_n                  (pwr_rst_n),
  .aux_clk_active             (aux_clk_active),
  .pm_rst_sel_aux_clk         (pm_rst_sel_aux_clk),
  .pm_linkst_sel_aux_clk      (pm_linkst_sel_aux_clk),
  .pm_linkst_en_core_clk      (pm_linkst_en_core_clk),
  .pm_l1sub_sel_aux_clk       (1'b0),
  .phystatus_if_sel_aux_clk   (phystatus_if_sel_aux_clk),
  // Outputs
  .pm_clk_sel_aux_clk         (pm_sel_aux_clk),
  .pm_clk_en_core_clk         (pm_en_core_clk),
  .pm_clk_aux_clk_active      (pm_aux_clk_active)
  ,.pm_clk_aux_clk_inactive   (pm_aux_clk_inactive)
);

assign phy_if_cpcie_powerdown           = phy_if_cpcie_pm_powerdown;



//
// PCI link PM state control
//

pme_ctrl
 
#(INST) u_pme_ctrl(
//--------------------- Inputs -----------------------
    .aux_clk                        (aux_clk),
    .pwr_rst_n                      (pwr_rst_n),
    .pm_core_rst_done               (pm_core_rst_done),
    .perst_n                        (pm_sync_perst_n),
    .switch_device                  (switch_device),
    .upstream_port                  (pm_upstream_port),
    .all_dwsp_rcvd_toack_msg        (all_dwsp_rcvd_toack_msg),
    .pm_pme_cap                     (pm_pme_cap),
    .apps_pm_xmt_turnoff            (apps_pm_xmt_turnoff),
    .apps_pm_xmt_pme                (apps_pm_xmt_pme),
    .nhp_pme_det                    (nhp_pme_det),
    .radm_pm_turnoff                (radm_pm_turnoff),
    .radm_pm_to_ack                 (radm_pm_to_ack ),
    .outband_pwrup_cmd              (outband_pwrup_cmd),
    .xdlh_xmt_pme_ack               (xdlh_xmt_pme_ack),
    .cfg_pmstatus_clr               (cfg_pmstatus_clr),
    .pm_pme_en                      (pm_pme_en),
    .smlh_link_up                   (shadow_smlh_link_up),
    .smlh_in_l0                     (smlh_in_l0),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .pm_curnt_state                 (pm_curnt_state),
    .pm_smlh_l23_exit               (pm_smlh_l23_exit),
    .pm_dstate_d0                   (pm_dstate_d0),
    .pm_dstate_d1                   (pm_dstate_d1),
    .pm_dstate_d2                   (pm_dstate_d2),
    .pm_dstate_d3                   (pm_dstate_d3),
    .pm_xdlh_enter_l23              (pm_xdlh_enter_l23),
    .current_data_rate              (pm_current_data_rate),

    .phy_type                       (phy_if_cpcie_phy_type),
    .pme_to_ack_grt                 (pme_to_ack_grt),
    .pm_pme_grant                   (pm_pme_grant),
    .pme_turn_off_grt               (pme_turn_off_grt),
// ------------- Outputs ----------------------------------
    .pm_xmt_turnoff                 (pm_xmt_turnoff),
    .pm_turnoff_timeout             (pm_turnoff_timeout),
    .pm_xmt_to_ack                  (pm_xmt_to_ack),
    .pm_xmt_pme                     (pm_xmt_pme),
    .link_reactivate                (link_reactivate),
    .pm_req_dwsp_turnoff            (pm_req_dwsp_turnoff),
    .int_pme_nego_done              (int_pme_nego_done),
    .pm_status                      (pm_status),
    .pm_pme_exit_l1                 (pm_pme_exit_l1)
    ,
    .pm_l2_entry_flag               (pm_l2_entry_flag)
);

pm_active_ctrl

#(  .INST               (INST),
    .PD_WIDTH           (PDWN_WIDTH),
    .P0S                (P0S),
    .P0                 (P0),
    .P1                 (P1),
    .P2                 (P2),
    .PL_AUX_CLK_FREQ_WD (PL_AUX_CLK_FREQ_WD),
    .PM_MST_WD          (PM_MST_WD),
    .PM_SLV_WD          (PM_SLV_WD)
) u_pm_active_ctrl(
    .xdlh_retry_pending             (xdlh_retry_pending),
    .pm_wake_req_exit_l0s           (pm_wake_req_exit_l0s),
    .pm_wake_tlp_pending            (pm_wake_tlp_pending),
    .xadm_block_tlp_ack             (xadm_block_tlp_ack),
    .pl_l1_clk_sel                  (pm_pl_l1_clk_sel),
    .smlh_cal_req                   (1'b0),
    .xdlh_match_pmdllp              (xdlh_match_pmdllp),
    .msg_gen_asnak_grt              (msg_gen_asnak_grt),
    .xdlh_last_pmdllp_ack           (xdlh_last_pmdllp_ack),
    .pm_l2_entry_flag               (pm_l2_entry_flag),
    .pm_det_l2                      (pm_det_l2),
    .link_req_rst_not               (link_req_rst_not),               
    .aux_clk_active                 (pm_aux_clk_active),
    .aux_clk_inactive               (pm_aux_clk_inactive),
    .app_clk_req_n                  (app_clk_req_n),
    .phy_clk_req_n                  (phy_clk_req_n),
    .pm_set_phy_p1                  (pm_set_phy_p1),
    .pwr_rst_n                      (pwr_rst_n),
    .aux_clk                        (aux_clk),
    .perst_n                        (pm_sync_perst_n),
    .pm_phy_rst_done                (pm_phy_rst_done),
    .pm_req_iso_vmain_to_vaux       (1'b0),
    .pmu_l2_pd                      (1'b0),
    .switch_device                  (switch_device),
    .upstream_port                  (pm_upstream_port),
    .no_fc_cds                      (xtlh_no_fc_credit),
    .no_dllp_pending                (xdlh_nodllp_pending),
    .no_acknak_dllp_pending         (xdlh_no_acknak_dllp_pending),
    .all_dwsp_in_l1                 (all_dwsp_in_l1),
    .all_dwsp_in_rl0s               (all_dwsp_in_rl0s),
    .all_dwsp_rcvd_toack_msg        (all_dwsp_rcvd_toack_msg),
    .upsp_in_rl0s                   (upsp_in_rl0s),
    .one_dwsp_exit_l1               (one_dwsp_exit_l1),
    .one_dwsp_exit_l23              (one_dwsp_exit_l23),
    .app_req_entr_l1                (app_req_entr_l1),
    .app_req_exit_l1                (app_req_exit_l1),
    .app_ready_entr_l23             (app_ready_entr_l23),
    .pm_pme_exit_l1                 (pm_pme_exit_l1),
    .apps_pm_xmt_turnoff            (apps_pm_xmt_turnoff),
    .pm_aslk_pmctrl                 (pm_aslk_pmctrl),
    .l0s_entr_latency_timer         (pm_l0s_entr_latency_timer),
    .l1_entr_latency_timer          (pm_l1_entr_latency_timer),
    .pm_l1_entr_wo_rl0s             (pm_l1_entr_wo_rl0s),
    .xdlh_not_expecting_ack         (xdlh_not_expecting_ack),
    .xtlh_had_enough_credit         (xtlh_had_enough_credit),
    .rdlh_rcvd_pm_enter_l1          (rdlh_rcvd_pm_enter_l1),
    .rdlh_rcvd_as_req_l1            (rdlh_rcvd_as_req_l1),
    .rdlh_rcvd_pm_req_ack           (rdlh_rcvd_pm_req_ack),
    .rdlh_rcvd_pm_enter_l23         (rdlh_rcvd_pm_enter_l23),
    .radm_pm_asnak                  (radm_pm_asnak),
    .smlh_in_l0                     (smlh_in_l0),
    .smlh_in_l0s                    (smlh_in_l0s),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .smlh_in_l1                     (smlh_in_l1),
    .smlh_in_l1_p1                  (smlh_in_l1_p1),
    .smlh_in_l23                    (smlh_in_l23),
    .smlh_l123_eidle_timeout        (smlh_l123_eidle_timeout),
    .latched_rcvd_eidle_set         (latched_rcvd_eidle_set),
    .pre_pm_phy_powerdown           (int_cpcie_powerdown),
    .pm_pmstate                     (pm_pmstate),
    .pm_clk_pm_en                   (pm_clk_pm_en),
    .link_reactivate                (link_reactivate),
    .int_pme_nego_done              (int_pme_nego_done),
    .phy_mac_rxelecidle             (int_pm_rxelecidle),
    .aux_pm_det                     (sys_aux_pwr_det),
    .phy_link_up                    (shadow_smlh_link_up),
    .smlh_link_in_training          (smlh_link_in_training),
    .ltssm_txelecidle               (int_cpcie_txelecidle),
    .current_data_rate              (pm_current_data_rate),
    .phy_type                       (phy_if_cpcie_phy_type),
    .pm_pl_l1_nowait_p1             (pm_pl_l1_nowait_p1),
    .pm_pl_aux_clk_freq             (pm_pl_aux_clk_freq),
    .radm_trgt0_pending             (radm_trgt0_pending),
    .lbc_active                     (lbc_active),
    .xfer_pending                   (pm_wake_xfer_pending),
    .pm_wake_l1_exit                (pm_wake_l1_exit),
    .mac_phy_txcompliance           (phy_if_cpcie_txcompliance),
    .current_powerdown_p2           (pm_current_powerdown_p2),
    .pm_perst_powerdown             (pm_perst_powerdown),
    .pm_req_non_sticky_rst          (pm_req_non_sticky_rst),
// Outputs
    .pm_xmt_asnak                   (pm_xmt_asnak),
    .pm_smlh_l0s_exit               (pm_smlh_l0s_exit),
    .pm_smlh_l1_exit                (pm_smlh_l1_exit),
    .pm_smlh_l23_exit               (pm_smlh_l23_exit),
    .pm_smlh_entry_to_l0s           (pm_smlh_entry_to_l0s),
    .pm_smlh_entry_to_l1            (pm_smlh_entry_to_l1),
    .pm_smlh_entry_to_l2            (pm_smlh_entry_to_l2),
    .pm_smlh_prepare4_l123          (pm_smlh_prepare4_l123),
    .pm_xtlh_block_tlp              (pm_xtlh_block_tlp),
    .pm_block_all_tlp               (pm_block_all_tlp_int),
    .pm_l1_aspm_entr                (pm_l1_aspm_entr),
    .pm_radm_block_tlp              (pm_radm_block_tlp),
    .pm_xdlh_enter_l1               (pm_xdlh_enter_l1),
    .pm_xdlh_req_ack                (pm_xdlh_req_ack),
    .pm_xdlh_enter_l23              (pm_xdlh_enter_l23),
    .pm_xdlh_actst_req_l1           (pm_xdlh_actst_req_l1),
    .pm_freeze_fc_timer             (pm_freeze_fc_timer),
    .pm_freeze_cpl_timer            (pm_freeze_cpl_timer),
    .pm_dstate_d0                   (pm_dstate_d0),
    .pm_dstate_d1                   (pm_dstate_d1),
    .pm_dstate_d2                   (pm_dstate_d2),
    .pm_dstate_d3                   (pm_dstate_d3),
    .wake                           (wake),
    .local_ref_clk_req_n            (local_ref_clk_req_n),
    .pm_linkst_in_l0                (pm_linkst_in_l0),
    .pm_linkst_in_l1                (pm_linkst_in_l1),
    .pm_linkst_in_l0s               (pm_linkst_in_l0s),
    .pm_linkst_in_l2                (pm_linkst_in_l2),
    .pm_linkst_l2_exit              (pm_linkst_l2_exit),
    .pm_linkst_in_l3                (pm_linkst_in_l3),
    .pm_linkst_in_l23rdy            (pm_linkst_in_l23rdy),
    .pm_curnt_state                 (pm_curnt_state),
    .pm_phy_powerdown               (phy_if_cpcie_pm_powerdown),
    .pm_int_phy_powerdown           (pm_int_phy_powerdown),   
    .pm_phy_txelecidle              (phy_if_cpcie_txelecidle)
    ,
    .mac_phy_pclkreq_n              (pm_phy_pclkreq_n)
   ,.pm_master_state                (pm_master_state),
    .pm_slave_state                 (pm_slave_state),
    .pm_l1_cpm_exit                 (pm_l1_cpm_exit),
    .pm_l1_in_progress              (pm_l1_in_progress)
    ,
    .pm_l1_entry_started            (pm_l1_entry_started),
    .pm_linkst_sel_aux_clk          (pm_linkst_sel_aux_clk),
    .pm_linkst_en_core_clk          (pm_linkst_en_core_clk)
);

assign pm_en_aux_clk_g = 1'b1;


// -------------------------------------------------------------------------------------
// Assign outputs
// -------------------------------------------------------------------------------------
// If flush enabled on link down then overide the block on the XADM transmit interfaces.
assign pm_block_all_tlp = rstctl_core_flush_req ? 1'b0 : pm_block_all_tlp_int;

pm_shadow

#(
  .INST (INST),
  .NL   (NL)
) u_pm_shadow (
    // Inputs
    .aux_clk                          (aux_clk),
    .pwr_rst_n                        (pwr_rst_n),
    .smlh_link_up                     (smlh_link_up),
    .current_data_rate                (current_data_rate),
    .pm_update                        (1'b0),
    .pm_hold                          (1'b0),
    .rstctl_ltssm_enable              (rstctl_ltssm_enable),
    .radm_idle                        (radm_idle),
    // Outputs
    .pm_smlh_link_up                  (shadow_smlh_link_up),
    .pm_ltssm_enable                  (pm_ltssm_enable),
    .pm_current_data_rate             (pm_current_data_rate)
    ,
    .pm_radm_idle_n                   (pm_radm_idle_n)
);

// -------------------------------------------------------------------------------------
// PM wakeup logic
// -------------------------------------------------------------------------------------
pm_wakeup

// Parameters
#( 
  .INST (INST),
  .NF   (NF),
  .NVC  (NVC),
  .CPL_LUT_DEPTH  (CPL_LUT_DEPTH),
  .PM_SYNC_DEPTH  (PM_SYNC_DEPTH)
) u_pm_wakeup (
    // Inputs
    .aux_clk                      (aux_clk),
    .pwr_rst_n                    (pwr_rst_n),
    .pm_radm_idle_n               (pm_radm_idle_n),
    .edma_xfer_pending            (1'b0),
    .dbi_cs                       (dbi_cs),
    .brdg_dbi_xfer_pending        (1'b0),
    .brdg_slv_xfer_pending        (1'b0),
    .pm_trgt_cpl_lut_empty_n      (1'b0),
    .client0_tlp_hv               (client0_tlp_hv),
    .client1_tlp_hv               (client1_tlp_hv),
    .app_xfer_pending             (app_xfer_pending),
    .upstream_port                (pm_upstream_port),
    .cfg_link_dis                 (cfg_link_dis),
    .cfg_link_retrain             (cfg_link_retrain),
    .cfg_lpbk_en                  (cfg_lpbk_en),
    .cfg_2nd_reset                (cfg_2nd_reset),
    .cfg_plreg_reset              (cfg_plreg_reset),
    .app_init_rst                 (app_init_rst),
    .cfg_directed_speed_change    (cfg_directed_speed_change),
    .cfg_directed_width_change    (cfg_directed_width_change),
    .ven_msg_req                  (ven_msg_req),
    .ven_msi_req                  (ven_msi_req),
    .app_ltr_msg_req              (app_ltr_msg_req),
    .app_unlock_msg               (app_unlock_msg),
    .msg_gen_unlock_grant         (msg_gen_unlock_grant),
    .smlh_link_up                 (shadow_smlh_link_up),
    .pm_req_iso_vmain_to_vaux     (1'b0),
    .pm_linkst_in_l1              (pm_linkst_in_l1),
    .pm_l1_in_progress            (pm_l1_in_progress),
    .pm_en_aux_clk_g              (pm_en_aux_clk_g),
    .smlh_link_in_training        (smlh_link_in_training),
    .lbc_active                   (lbc_active),
    .msg_gen_hv                   (msg_gen_hv),
    .lbc_cpl_hv                   (lbc_cpl_hv),
    .xadm_tlp_pending             (xadm_tlp_pending),
    .xtlh_tlp_pending             (xtlh_tlp_pending),
    .xdlh_tlp_pending             (xdlh_tlp_pending),
    // Outputs
    .pm_wake_init_rst             (pm_init_rst),
    .pm_wake_unlock_msg_req       (pm_unlock_msg_req),
    .pm_wake_l1_pg_exit           (pm_wake_l1_pg_exit),
    .pm_wake_l1_pg_ack            (pm_wake_l1_pg_ack),
    .pm_wake_xfer_pending         (pm_wake_xfer_pending),
    .pm_wake_l1_exit              (pm_wake_l1_exit),
    .pm_wake_dbi_pending          (pm_wake_dbi_pending),
    .pm_wake_block_pg             (pm_wake_block_pg)
    ,
    .pm_smlh_link_retrain         (pm_smlh_link_retrain)
    ,
    .pm_wake_req_exit_l0s         (pm_wake_req_exit_l0s),
    .pm_wake_tlp_pending          (pm_wake_tlp_pending)
);

// ----------------------------------------------------------------------------
// PM reset control
// ----------------------------------------------------------------------------
pm_rst_control

    // Parameters
    #(
        .NL             (NL),
        .INST           (INST),
        .PM_SYNC_DEPTH  (PM_SYNC_DEPTH)
    ) u_pm_rst_control (
    // Inputs
    .pm_req_iso_vmain_to_vaux   (1'b0),
    .aux_clk                    (aux_clk),
    .pwr_rst_n                  (pwr_rst_n),
    .core_rst_n                 (core_rst_n),
    .perst_n                    (perst_n),
    .phy_type                   (phy_if_cpcie_phy_type),
    .pm_linkst_in_l2            (pm_linkst_in_l2),
    .aux_clk_active             (pm_aux_clk_active),
    .aux_clk_inactive           (pm_aux_clk_inactive),
    .link_req_rst_not           (link_req_rst_not),
    .app_hold_phy_rst            (app_hold_phy_rst),
    .pm_phy_rst_timer            (pm_phy_rst_timer),
    .pm_pma_phy_rst_delay_timer  (pm_pma_phy_rst_delay_timer),
    .pm_phy_perst_on_warm_reset  (pm_phy_perst_on_warm_reset),
    .phystatus_pclk_ready        (phystatus_pclk_ready),
    // Outputs
    .pm_rst_req_phy_rst         (pm_req_phy_rst),
    .pm_rst_req_phy_perst       (pm_req_phy_perst),
    .pm_rst_req_core_rst        (pm_req_core_rst),
    .pm_rst_req_sticky_rst      (pm_req_sticky_rst),
    .pm_rst_req_non_sticky_rst  (pm_req_non_sticky_rst),
    .pm_rst_perst_powerdown     (pm_perst_powerdown),
    .pm_rst_set_phy_p1          (pm_set_phy_p1),
    .pm_rst_sel_aux_clk         (pm_rst_sel_aux_clk),
    .pm_rst_sync_perst_n        (pm_sync_perst_n),
    .pm_rst_phy_rst_done        (pm_phy_rst_done),
    .pm_rst_core_rst_done       (pm_core_rst_done),
    .pm_rst_det_l2              (pm_det_l2)
);

// ----------------------------------------------------------------------------
// Receiver electrical idle detection
// ----------------------------------------------------------------------------
rxeidle_squelch
 u_rxeidle_squelch [NL-1:0] (
    //    ----------------- Inputs ----------------------
    .iphy_mac_rxelecidle (phy_mac_rxelecidle[NL-1:0]),
    .aux_clk             (aux_clk),
    .rst_n               (pwr_rst_n),
    //    ----------------- Outputs ----------------------
    .ophy_mac_rxelecidle (sqlchd_rxelecidle[NL-1:0])
);

 assign int_pm_rxelecidle          = sqlchd_rxelecidle;

// ----------------------------------------------------------------------------
// PHY Interface
// ----------------------------------------------------------------------------
phy_if_cpcie
 #(
    // Parameters
    .INST           (INST),
    .PDWN_WIDTH     (PDWN_WIDTH),
    .NL             (NL),
    .PHY_NB         (PHY_NB),
    .TX_DEEMPH_WD   (TX_DEEMPH_WD),
    .PHY_RATE_WD    (PHY_RATE_WD),
    .PHY_WIDTH_WD   (PHY_WIDTH_WD),
    .P1             (P1),
    .NL_X2          (NL_X2),
    .L2NL           (L2NL)
) u_phy_if_cpcie (
    // Inputs
    .clk                            (aux_clk),
    .rst_n                          (pwr_rst_n),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode), 
    .update_perst                   (1'b0),
    .hold_perst                     (1'b0),
    .hold_data                      (1'b0),
    .update                         (1'b0),
    .phy_type                       (1'b0)
    ,
    .mac_phy_pclkreq_n              (pm_phy_pclkreq_n)
    ,
    .cfg_phy_control                (cfg_phy_control),
    .mac_phy_powerdown              (mac_phy_powerdown),
    .mac_phy_txelecidle             (mac_phy_txelecidle)
    ,
    .mac_phy_txdata                 (mac_phy_txdata),
    .mac_phy_txdatak                (mac_phy_txdatak),
    .mac_phy_txdetectrx_loopback    (mac_phy_txdetectrx_loopback),
    .mac_phy_txcompliance           (mac_phy_txcompliance),
    .mac_phy_rxpolarity             (mac_phy_rxpolarity),
    .ltssm_rxpolarity               (ltssm_rxpolarity),
    .mac_phy_width                  (mac_phy_width),
    .mac_phy_pclk_rate              (mac_phy_pclk_rate),
    .mac_phy_rxstandby              (mac_phy_rxstandby)
    ,
    .rx_lane_flip_en                (rx_lane_flip_en),
    .tx_lane_flip_en                (tx_lane_flip_en),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl)
    // Outputs
    ,
    .phy_if_cpcie_pclkreq_n             (phy_if_cpcie_pclkreq_n)
    ,
    .phy_if_cfg_phy_control             (phy_if_cfg_phy_control),
    .phy_if_cpcie_powerdown             (int_cpcie_powerdown),
    .phy_if_cpcie_txelecidle            (int_cpcie_txelecidle)
    ,
    .phy_if_cpcie_txdata                (phy_if_cpcie_txdata),
    .phy_if_cpcie_txdatak               (phy_if_cpcie_txdatak),
    .phy_if_cpcie_txdetectrx_loopback   (phy_if_cpcie_txdetectrx_loopback),
    .phy_if_cpcie_txcompliance          (phy_if_cpcie_txcompliance),
    .phy_if_cpcie_rxpolarity            (phy_if_cpcie_rxpolarity),
    .phy_if_cpcie_width                 (phy_if_cpcie_width),
    .phy_if_cpcie_pclk_rate             (phy_if_cpcie_pclk_rate),
    .phy_if_cpcie_rxstandby             (phy_if_cpcie_rxstandby)
    ,
    .phy_if_cpcie_phy_type              (phy_if_cpcie_phy_type)
    ,
    .pm_rx_lane_flip_ctrl               (pm_rx_lane_flip_ctrl),
    .pm_tx_lane_flip_ctrl               (pm_tx_lane_flip_ctrl),
    .pm_rx_pol_lane_flip_ctrl           (pm_rx_pol_lane_flip_ctrl)
    ,
    .phy_if_elasticbuffermode           (phy_if_elasticbuffermode)
);

pm_cfg

  // Parameters
  #(
    .INST                 (1'b0),
    .NF                   (NF),
    .NL                   (NL),
    .L0S_LATENCY_TIMER_WD (L0S_LATENCY_TIMER_WD),
    .L1_LATENCY_TIMER_WD  (L1_LATENCY_TIMER_WD),
    .ASLK_CTRL_WD         (ASLK_CTRL_WD),
    .PL_AUX_CLK_FREQ_WD   (PL_AUX_CLK_FREQ_WD),
    .DEFAULT_PHY_PERST_ON_WARM_RESET (DEFAULT_PHY_PERST_ON_WARM_RESET),
    .NFUNC_WD             (NFUNC_WD),
    .NVF                  (1),
    .BUS_NUM_WD           (BUSNUM_WD),
    .DEV_NUM_WD           (DEVNUM_WD)
  ) u_pm_cfg (
  // Inputs
  .aux_clk                        (aux_clk),
  .pwr_rst_n                      (pwr_rst_n),
  .perst_n                        (pm_sync_perst_n),
  .upstream_port                  (upstream_port),
  .en_iso                         (1'b0),
  .pm_hold                        (1'b0),
  .pm_hold_perst                  (1'b0),
  .pm_update                      (1'b0),
  .pm_update_perst                (1'b0),
  .pm_active_state                (1'b0),
  .cfg_l0s_entr_latency_timer     (cfg_l0s_entr_latency_timer),
  .cfg_l1_entr_latency_timer      (cfg_l1_entr_latency_timer),
  .cfg_l1_entr_wo_rl0s            (cfg_l1_entr_wo_rl0s),
  .cfg_aslk_pmctrl                (cfg_aslk_pmctrl),
  .cfg_upd_aspm_ctrl              (cfg_upd_aspm_ctrl),
  .cfg_upd_aslk_pmctrl            (cfg_upd_aslk_pmctrl),
  .cfg_aux_pm_en                  (cfg_aux_pm_en),
  .cfg_pme_en                     (cfg_pme_en),
  .cfg_pbus_num                   (cfg_pbus_num),
  .cfg_pbus_dev_num               (cfg_pbus_dev_num),
  .cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en),
  .cfg_upd_pmcsr                  (cfg_upd_pmcsr),
  .cfg_upd_req_id                 (cfg_upd_req_id),
  .cfg_pme_cap                    (cfg_pme_cap),
  .cfg_upd_pme_cap                (cfg_upd_pme_cap),
  .pm_core_rst_done               (pm_core_rst_done),
  .cfg_pmstate                    (cfg_pmstate),
  .cfg_clk_pm_en                  (cfg_clk_pm_en),
  .cfg_pl_l1_nowait_p1            (cfg_pl_l1_nowait_p1),
  .cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel),
  .cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset),
  .cfg_phy_rst_timer              (cfg_phy_rst_timer),
  .cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer),
  .cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq),
  .cfg_link_capable               (cfg_link_capable),
  // Outputs
  .pm_cfg_l0s_entr_latency_timer  (pm_l0s_entr_latency_timer),
  .pm_cfg_l1_entr_latency_timer   (pm_l1_entr_latency_timer),
  .pm_cfg_l1_entr_wo_rl0s         (pm_l1_entr_wo_rl0s),
  .pm_cfg_aslk_pmctrl             (pm_aslk_pmctrl),
  .pm_cfg_aux_pm_en               (pm_aux_pm_en),
  .pm_cfg_pme_en                  (pm_pme_en),
  .pm_cfg_pbus_num                (pm_bus_num),
  .pm_cfg_pbus_dev_num            (pm_dev_num),
  .pm_cfg_pme_cap                 (pm_pme_cap),
  .pm_cfg_pmstate                 (pm_pmstate),
  .pm_cfg_clk_pm_en               (pm_clk_pm_en),
  .pm_cfg_pl_l1_nowait_p1         (pm_pl_l1_nowait_p1),
  .pm_cfg_pl_l1_clk_sel           (pm_pl_l1_clk_sel),
  .pm_phy_perst_on_warm_reset     (pm_phy_perst_on_warm_reset),
  .pm_cfg_pl_aux_clk_freq         (pm_pl_aux_clk_freq)
  ,
  .pm_upstream_port               (pm_upstream_port)
  ,
  .pm_link_capable                (pm_link_capable),
  .pm_phy_rst_timer               (pm_phy_rst_timer),
  .pm_pma_phy_rst_delay_timer     (pm_pma_phy_rst_delay_timer)
);

// -----------------------------------------------------------------------
// To avoid heterogeneous fanout issues some ports are split
// -----------------------------------------------------------------------
assign pm_int_txelecidle = phy_if_cpcie_txelecidle;
// -----------------------------------------------------------------------
// To facilate level shifter insertion where required some nets are 
// passed through the pm_ctrl module first and the routed into the core logic
// -----------------------------------------------------------------------
assign pm_aux_clk_ft = aux_clk;
assign pm_sys_aux_pwr_det_ft = sys_aux_pwr_det;
assign pm_aux_clk_active_ft = aux_clk_active;
assign pm_xadm_client0_tlp_hv = client0_tlp_hv;
assign pm_xadm_client1_tlp_hv = client1_tlp_hv;
assign pm_dbi_cs_ft = dbi_cs;

// -----------------------------------------------------------------------
// To facilate level shifter insertion where required some outputs of
// the pm_ctrl module are split with one version output directly to the IO.
// The other versions named *_split are fed back internally in the core.
// -----------------------------------------------------------------------
assign pm_pme_en_split = pm_pme_en;
assign pm_aux_pm_en_split = pm_aux_pm_en;

// -----------------------------------------------------------------------
// Phystatus tracker for powerdown P2 transition
// -----------------------------------------------------------------------
DWC_pcie_phystatus_if
 u_phystatus_if(
    // Inputs
    .aux_clk                      (aux_clk),
    .pipe_clk                     (pipe_clk),
    .pwr_rst_n                    (pwr_rst_n),
    .mac_phy_powerdown            (phy_if_cpcie_powerdown),
    .mac_phy_txcompliance         (phy_if_cpcie_txcompliance),
    .mac_phy_txdetectrx_loopback  (phy_if_cpcie_txdetectrx_loopback),
    .phy_mac_phystatus            (phy_mac_phystatus),
    .phy_mac_rxstatus             (phy_mac_rxstatus),
    .cfg_force_powerdown          (cfg_force_powerdown),
    .pm_link_capable              (pm_link_capable),
    .smlh_ltssm_state             (smlh_ltssm_state),
    .pm_perst_powerdown           (pm_perst_powerdown),
    // Outputs
    .pm_current_powerdown         (),
    .pm_current_powerdown_p2      (pm_current_powerdown_p2),
    .pm_current_powerdown_p1      (pm_current_powerdown_p1),
    .pm_current_powerdown_p0      (pm_current_powerdown_p0),
    .pm_rxdetected                (),
    .pm_powerdown_status          (pm_powerdown_status),
    .phystatus_if_sel_aux_clk     (phystatus_if_sel_aux_clk)
    ,.phystatus_pclk_ready        (phystatus_pclk_ready)
);


`endif // `ifndef SNPS_PCIE_SATB

endmodule
