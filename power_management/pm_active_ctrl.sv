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
// ---    $DateTime: 2020/10/13 07:12:04 $
// ---    $Revision: #27 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_ctrl.sv#27 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module provides control logic for Active State PM as well as
// --- dllp pm control
// --- It has the following job to complete:
// --- 1. reponsible to control the entry of L0s as specified in active state
// --- power management spec.
// --- 2. reponsible to control the entry of L1 as specified in active state
// --- power management spec.
// --- 3. reponsible to control the entry of L2 or 3 as PCI_PM specification,
// --- before power can be removal, a l23 ready dllp has to be send and
// --- transition the same way as L1.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_active_ctrl (
// ---- inputs ---------------
    xdlh_retry_pending,
    pm_wake_req_exit_l0s,
    pm_wake_tlp_pending,
    xadm_block_tlp_ack,
    xdlh_match_pmdllp,
    msg_gen_asnak_grt,
    xdlh_last_pmdllp_ack,
    pm_l2_entry_flag,
    pm_det_l2,
    link_req_rst_not,
    app_clk_req_n,
    phy_clk_req_n,
    pwr_rst_n,
    aux_clk,
    perst_n,
    pm_phy_rst_done,
    pm_req_iso_vmain_to_vaux,
    pmu_l2_pd,
    switch_device,
    upstream_port,
    no_fc_cds,
    no_dllp_pending,
    no_acknak_dllp_pending,
    app_req_entr_l1,
    app_ready_entr_l23,
    app_req_exit_l1,
    pm_pme_exit_l1,
    apps_pm_xmt_turnoff,
    all_dwsp_in_l1,
    all_dwsp_in_rl0s,
    all_dwsp_rcvd_toack_msg,
    upsp_in_rl0s,
    one_dwsp_exit_l1,
    one_dwsp_exit_l23,
    pm_aslk_pmctrl,
    l0s_entr_latency_timer,
    l1_entr_latency_timer,
    pm_l1_entr_wo_rl0s,
    xdlh_not_expecting_ack,
    xtlh_had_enough_credit,
    rdlh_rcvd_pm_enter_l1,
    rdlh_rcvd_as_req_l1,
    rdlh_rcvd_pm_req_ack,
    rdlh_rcvd_pm_enter_l23,
    radm_pm_asnak,
    smlh_in_l0,
    smlh_in_l0s,
    smlh_in_rl0s,
    smlh_in_l1,
    smlh_in_l1_p1,
    smlh_in_l23,
    smlh_l123_eidle_timeout,
    latched_rcvd_eidle_set,
    pre_pm_phy_powerdown,
    pm_pmstate,
    pm_clk_pm_en,
    link_reactivate,
    int_pme_nego_done,
    phy_mac_rxelecidle,
    aux_pm_det,
    phy_link_up,
    smlh_link_in_training,
    ltssm_txelecidle,
    current_data_rate,
    aux_clk_active,
    aux_clk_inactive,
    phy_type,
    pm_pl_l1_nowait_p1,
    pm_pl_aux_clk_freq,
    radm_trgt0_pending,
    lbc_active,
    xfer_pending,
    pm_wake_l1_exit,
    pm_set_phy_p1,
    mac_phy_txcompliance,
    pl_l1_clk_sel,
    smlh_cal_req,
    current_powerdown_p2,
    pm_perst_powerdown,
    pm_req_non_sticky_rst,
// ---- outputs ---------------
    pm_xmt_asnak,
    pm_smlh_l0s_exit,
    pm_smlh_l1_exit,
    pm_smlh_l23_exit,
    pm_smlh_entry_to_l0s,
    pm_smlh_entry_to_l1,
    pm_smlh_entry_to_l2,
    pm_smlh_prepare4_l123,
    pm_xtlh_block_tlp,
    pm_block_all_tlp,
    pm_radm_block_tlp,
    pm_l1_aspm_entr,
    pm_xdlh_enter_l1,
    pm_xdlh_req_ack,
    pm_xdlh_enter_l23,
    pm_xdlh_actst_req_l1,
    pm_freeze_fc_timer,
    pm_freeze_cpl_timer,
    pm_dstate_d0,
    pm_dstate_d1,
    pm_dstate_d2,
    pm_dstate_d3,
    wake,
    local_ref_clk_req_n,
    pm_linkst_in_l0,
    pm_linkst_in_l1,
    pm_l1_entry_started,
    pm_linkst_in_l0s,
    pm_linkst_in_l2,
    pm_linkst_l2_exit,
    pm_linkst_in_l3,
    pm_curnt_state,
    pm_phy_powerdown,
    pm_int_phy_powerdown,
    pm_phy_txelecidle
    ,
    mac_phy_pclkreq_n
   ,pm_master_state,
    pm_slave_state,
    pm_l1_cpm_exit,
    pm_l1_in_progress
    ,
    pm_linkst_sel_aux_clk, // request to switch the source of aux_clk
    pm_linkst_en_core_clk // request to enable core_clk
    ,
    pm_linkst_in_l23rdy
);
parameter INST                      = 0;                    // The uniquifying parameter for each port logic instance.
parameter NL                        = `CX_NL;
parameter FREQ_MULTIPLIER           = `CX_FREQ_MULTIPLIER;
parameter NF                        = `CX_NFUNC;            // number of functions
parameter NVC                       = `CX_NVC;              // number of VCs
parameter TP                        = `TP;                  // Clock to Q delay (simulator insurance)
parameter ASPM_TIMEOUT_ENTR_L1_EN   = `CX_ASPM_TIMEOUT_ENTR_L1_EN;
parameter PD_WIDTH = 2;
parameter PHY_NB                    = `CX_PHY_NB;
parameter PHY_TXEI_WD               = `CX_PHY_TXEI_WD;
parameter P0S = {PD_WIDTH{1'b0}};
parameter P0 = {PD_WIDTH{1'b0}};
parameter P1 = {PD_WIDTH{1'b0}};
parameter P2 = {PD_WIDTH{1'b0}};
parameter PL_AUX_CLK_FREQ_WD = 1;
input                   xdlh_retry_pending;     // TLP pending for replay in Layer2 transmit path
input                   pm_wake_req_exit_l0s;   // TLP pending on XADM interface so exit L0S
input                   pm_wake_tlp_pending;    // TLP pending in transmit data path
input                   xadm_block_tlp_ack;     // XADM blocked all TLP's and has nothing pending to transmit
parameter PM_MST_WD = 5;
parameter PM_SLV_WD = 5;
input [3:0]             xdlh_match_pmdllp;      // Layer2 transmitted a PM DLLP
input                   link_req_rst_not;       // LTSSM sets this signal to 0 to request a reset due to surprise link down
input                   pm_det_l2;              // Indication from reset control that main power has been removed core is in L2
input                   msg_gen_asnak_grt;      // Indication from msg_gen that PM_Active_State_Nak has been granted
input                   xdlh_last_pmdllp_ack;  // Layer1 acknowledge that the last PM DLLP has been sent
input                   pm_l2_entry_flag;       // PM_Turnoff message has been received so L2 negotiation should start
input                   app_clk_req_n;          // Application requests removal of ref clock
input                   phy_clk_req_n;          // PHY is ready for ref clock removal
input                   pwr_rst_n;
input                   aux_clk;
input                   perst_n;                  // Main power removal indication
input                   pm_phy_rst_done;          // Rising edge of perst_n detected and PHY is out of reset
input                   pm_req_iso_vmain_to_vaux; // Enable for isolation cells at inputs to pm_ctrl
input                   pmu_l2_pd;                // power gating for l2 in progress
input   [(2*NF)-1:0]    pm_aslk_pmctrl;           // ASPM control bits
input                   aux_pm_det;             // aux support detected
input                   switch_device;          // 1 indicate that it is a switch device; 0 indicate that it is a EP/RC/bridge device
input                   upstream_port;          // 1 indicate that it is an upstream port (EP/upstream port of a SW)
// from Cfg reg
input   [2:0]           l0s_entr_latency_timer; // L0s transmitter L0s exit timer
input   [2:0]           l1_entr_latency_timer;  // L1 transmitter l1 exit timer
input                   pm_l1_entr_wo_rl0s;    // Start L1 timer without rL0s
input   [(3*NF)-1 :0]   pm_pmstate;            // PM state
input                   pm_clk_pm_en;           // Clock PM feature enabled by software

// from CXPL
input                   xdlh_not_expecting_ack; // XDLH is not expecting ACK
input   [NVC-1:0]       xtlh_had_enough_credit; // XTLH had enough credit
input                   rdlh_rcvd_as_req_l1;    // RDLH received PM_AS_REQ_L1
input                   rdlh_rcvd_pm_enter_l1;  // RDLH received PM_ENTER_L1
input                   rdlh_rcvd_pm_req_ack;   // RDLH received PM_REQ_ACK
input                   rdlh_rcvd_pm_enter_l23; // RDLH received PM_ENTER_L23
input   [NVC-1:0]       no_fc_cds;              // no FC credits are available to transmit anything
input                   no_dllp_pending;        // no DLLP pending to transmit
input                   no_acknak_dllp_pending; // no ACK/NAK DLLP pending to transmit

// from RADM
input                   radm_pm_asnak;          // received AS_NAK

// from pm_ctrl_up module
input                   int_pme_nego_done;      // PME_EVENT send request
input                   link_reactivate;        // PME send PME message request

// Handshake to Link state machine
input                   smlh_in_l0;             // TXMT MAC is in L0
input                   smlh_in_l0s;            // TXMT MAC is in L0s
input                   smlh_in_rl0s;           // TXMT MAC is in rL0s
input                   smlh_in_l1;             // TXMT MAC is in L1
input                   smlh_in_l1_p1;          // TXMT MAC is in L1 powerdown P1
input                   smlh_in_l23;            // TXMT MAC is in L23
input                   smlh_l123_eidle_timeout;// LTSSM 2ms Timer timeout waiting for EIDLE
input                   latched_rcvd_eidle_set;
input   [(PD_WIDTH - 1) : 0]   pre_pm_phy_powerdown;           // XMLH powerdown to PIPE phy. We intercept to drive P2

// for switch application only
input                   all_dwsp_in_l1;         // All downstream ports are in L1
input                   all_dwsp_in_rl0s;       // All downstream ports are in rl0s
input                   all_dwsp_rcvd_toack_msg;// All downstream ports have received Turnoff Ack MSG
input                   upsp_in_rl0s;           // upstream port is in rl0s
input                   app_req_entr_l1;        // Provide a capability for applications to request PM state to enter L1. This is only effective when ASPM of L1 is enabled.
input                   app_ready_entr_l23;    // Indicate that application is ready to enter L23 when device has being programmed to D3
input                   app_req_exit_l1;        // Provide a capability for applications to request PM state to exit L1. This is only effective when ASPM of L1 is enabled.
input                   pm_pme_exit_l1;         // Indication from pme_ctrl  that a wakeup event has occurred
input                   one_dwsp_exit_l23;      // One of the downstream port exits L23
input                   one_dwsp_exit_l1;       // One of the downstream ports exits L1
input                   apps_pm_xmt_turnoff;    // Application request to send a Turn Off Message

// from PHY
input   [NL-1:0]        phy_mac_rxelecidle;     // PHY is in rx EIDLE
input                   phy_link_up;            // PHY link up
input                   smlh_link_in_training;          // LTSSM is entering Recovery
input   [NL*PHY_TXEI_WD-1:0] ltssm_txelecidle;       // LTSSM tells PHY to go into electrical idle
input   [2:0]           current_data_rate;      // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4

input                   phy_type;               // Mac type
input                   aux_clk_active; // muxed aux clk has switched to low frequency clock, used when entering L1 to stall progression into L1 substates
input                   aux_clk_inactive; // muxed aux clk has switched to core clock
input                   pm_pl_l1_nowait_p1; // If set to 1 dont wait for powerdown P1 acknowledge before entering L1
input  [PL_AUX_CLK_FREQ_WD-1:0] pm_pl_aux_clk_freq; // Aux clock frequency
input                   radm_trgt0_pending;          // A TLP is enroute to TRGT0, delay L1 entry
input                   lbc_active;                  // The LBC may require a CPL to be sent, stop L1 timer
input                   xfer_pending;
input                   pm_wake_l1_exit; // pm_wakeup module requests L1 exit
input                   pm_set_phy_p1;  // When the PHY is reset in L2 the powerdown is set to P1
input [NL - 1 : 0]      mac_phy_txcompliance; // For disabled lanes this is set to 1
input                   pl_l1_clk_sel; // port logic bit which disables clock switching in L1
input                   smlh_cal_req; // CCIX calibrarion request signal
input                   current_powerdown_p2; // Phy has acknowledged P2 transition with Phystatus on all active lanes

input                   pm_perst_powerdown;     // Indicate specific powerdown will be driven during perst rst
input                   pm_req_non_sticky_rst;
// ------------ Outputs ------------------

// to CXPL
output                  pm_xmt_asnak;           // NAK respond to ASPM L1 enter protocol for enter L1 request
output                  pm_smlh_entry_to_l0s;   // entry to L0s
output                  pm_smlh_l0s_exit;       // exit xmtr L0s
output                  pm_smlh_entry_to_l1;    // entry to L1
output                  pm_smlh_l1_exit;        // exit xmtr L1
output                  pm_smlh_l23_exit;       // exit xmtr L23
output                  pm_smlh_entry_to_l2;    // entry to L2
output                  pm_smlh_prepare4_l123;  // prepare to entry to L1, L2 or L3
output                  pm_xtlh_block_tlp;      // XTLH blocks TLP for TXMT
output                  pm_block_all_tlp;       // to notify xmt modules to block all tlps
output                  pm_l1_aspm_entr;
output  [NF-1:0]        pm_radm_block_tlp;      // Block receiving certain TLPs in D1-D3 states
output                  pm_xdlh_enter_l1;       // XDLH enter L1
output                  pm_xdlh_enter_l23;      // XDLH enter L23
output                  pm_xdlh_req_ack;        // XDLH send REQ ACK
output                  pm_xdlh_actst_req_l1;   // XDLH send AS_REQ_L1
output                  pm_freeze_fc_timer;     // PM freeze FC timer
output                  pm_freeze_cpl_timer;    // PM freeze completion timeout timer

output                  wake;                 // to request system to restore main power and clock
output                  local_ref_clk_req_n;              // signal designed to indicate to the PHY we
// to switch application
output                  pm_linkst_in_l0;        // PM state in L0
output                  pm_linkst_in_l1;        // PM state in L1
output                  pm_l1_entry_started;    // L1 entry process has started
output                  pm_linkst_in_l0s;       // PM state in L0s
output                  pm_linkst_in_l2;        // PM state in L2
output                  pm_linkst_l2_exit;      // PM state exiting L2
output                  pm_linkst_in_l3;        // PM state in L3
output                  pm_linkst_in_l23rdy;

// To PHY
output  [(PD_WIDTH - 1) : 0]           pm_phy_powerdown;       // PM to PHY power down
output  [(PD_WIDTH - 1) : 0]           pm_int_phy_powerdown;       // PM to PHY power down
output  [2:0]           pm_curnt_state;         // PM current state
output  [NL*PHY_TXEI_WD-1:0] pm_phy_txelecidle;      // Direct PHY to TX-elecidle state
output  [NF-1:0]        pm_dstate_d0;
output  [NF-1:0]        pm_dstate_d1;
output  [NF-1:0]        pm_dstate_d2;
output  [NF-1:0]        pm_dstate_d3;

output [1:0]            mac_phy_pclkreq_n;     // Request PCLK removal:
                                               // 2'b00: do not request PCLK removal
                                               // 2'b01: request PCLK removal for executing L1 with Clock PM
                                               // 2'b10: request PCLK removal for executing L1 substates
                                               // 2'b11: request PCLK removal for executing L1 substates with Clock PM
output [(PM_MST_WD - 1):0] pm_master_state;
output [(PM_SLV_WD - 1):0] pm_slave_state;
output                  pm_l1_cpm_exit;
output                  pm_l1_in_progress; // L1 entry negotiation in progress
output                  pm_linkst_sel_aux_clk;
output                  pm_linkst_en_core_clk;

//------------------------------------------------------------------------------
// IO signals declaration
//------------------------------------------------------------------------------
wire int_pd_p1_override;
reg  [1:0]                      int_mac_phy_pclkreq_n_r;
reg                             int_override_pd_r;
wire                            int_p1_to_p2;
wire                            int_next_state_is_l1;
wire                            int_freq_step_smlh_in_l1;
wire                            int_next_state_is_l23;
wire                            int_start_l1_aspm;
wire                            int_start_l1_pcipm;
wire                            int_start_l1_nego;
wire                            int_block_tlp_ack;
wire                            int_l1_aspm_radm_race;
wire                            int_l1_aspm_ready;
wire                            int_en_sw_usp_aspm_l1;
wire                            int_en_usp_aspm_l1;
wire                            int_disable_aspm_l1;
wire                            int_clear_l1_timeout;
wire                            int_tx_pending;
wire                            int_trgt0_pending;
wire                            int_pending_clear_timeout;
wire                            int_l23_entry_abort;
wire                            int_pm_state_l23;
wire                            int_pm_state_l23rdy;
wire                            pm_active_next_l2;
wire                            pm_active_next_l1;
wire                            pm_linkst_sel_aux_clk;
wire                            pm_linkst_en_core_clk;
wire                            pm_active_next_l1_entry;
wire                            pm_active_next_l1_exit;
wire                            int_smlh_in_l1;
wire                            int_update_powerdown;
wire                            int_block_pd_update;
wire                            int_detect_pd_update;
wire                            int_smlh_pd_update;
wire                            int_txelecidle_and;
wire                            int_p0_pd_update;
reg                             int_l0s_idle_timeout_s;
wire                            int_link_up_not_rcvry;
wire                            int_idle_next;
wire                            int_clear_l0s_timeout;
wire                            int_l0s_l1_timeout_s;
wire                            int_l1_idle_timeout_s;
wire                            int_no_l0s_bef_l1;
wire                            int_l1_timeout_s;
wire                            int_l0s_before_l1_entry;
wire                            int_l1_entry_no_l0s;
wire                            int_pm_xmt_asnak;
wire                            int_next_resp_nak;
wire                            int_upd_clk_req_n;
wire                            int_hold_clk_req_n;
wire                            int_pm_clk_req_n;
//wire                            int_clear_clk_req_n;
reg                             int_l0s_idle_timeout_r;
reg     [2:0]                   pm_curnt_state;
wire    [(PD_WIDTH - 1) : 0]    pm_int_phy_powerdown;       // PM to PHY power down
wire                            int_pm_linkst_l2;
wire                            int_pm_l2_wakeup;
reg     [NL*PHY_TXEI_WD - 1 : 0]  int_phy_txelecidle;
reg                             int_phy_beacongen;
wire                            int_l2_wakeup_done;
reg     [NL*PHY_TXEI_WD - 1 : 0]  int_phy_txelecidle_r;
reg                             int_phy_beacongen_r;
wire                            int_sel_pm_txelecidle;
wire                            int_drive_txelecidle;
reg                             int_sel_pm_txelecidle_r;

wire                    sync_phy_clk_req_n;
reg                     int_phy_clk_req_n_r;
wire                    int_phy_clk_req_n;
wire                    int_lp_clk_sw_mode;
wire    [(3*NF)-1:0]    pm_dstate;
reg                     pm_linkst_in_l0;
reg                     pm_linkst_in_l1;
reg                     pm_l1_entry_started;
wire                    int_l1_entry_started;
reg                     pm_linkst_in_l0s;
reg                     pm_linkst_in_l2;
reg                     pm_linkst_l2_exit;
reg                     pm_linkst_in_l3;
reg                     pm_linkst_in_l23rdy;
reg                     int_l1_aspm_radm_race_r;
wire    [NL*PHY_TXEI_WD-1:0]           pm_phy_txelecidle;
reg     [(PD_WIDTH - 1) : 0]           pm_phy_powerdown;

// -----------------------------------------------------------------------------
// --- Parameters
// -----------------------------------------------------------------------------
parameter IDLE                  = 5'h0;
parameter L0                    = 5'h1;
parameter L0S                   = 5'h2;
parameter ENTER_L0S             = 5'h3;
parameter L0S_EXIT              = 5'h4;
parameter WAIT_PMCSR_CPL_SENT   = 5'h5;
parameter L1                    = 5'h8;
parameter L1_BLOCK_TLP          = 5'h9;
parameter L1_WAIT_LAST_TLP_ACK  = 5'hA;
parameter L1_WAIT_PMDLLP_ACK    = 5'hB;
parameter L1_LINK_ENTR_L1       = 5'hC;
parameter L1_EXIT               = 5'hD;
parameter PREP_4L1              = 5'hF;
parameter L23_BLOCK_TLP         = 5'h10;
parameter L23_WAIT_LAST_TLP_ACK = 5'h11;
parameter L23_WAIT_PMDLLP_ACK   = 5'h12;
parameter L23_ENTR_L23          = 5'h13;
parameter L23RDY                = 5'h14;
parameter PREP_4L23             = 5'h15;
parameter L23RDY_WAIT4ALIVE     = 5'h16;
parameter L0S_BLOCK_TLP         = 5'h17;
parameter WAIT_LAST_PMDLLP      = 5'h18;
parameter WAIT_DSTATE_UPDATE    = 5'h19;
parameter L1_CPM_ENTRY          = 5'h1B;
parameter L1_CPM_EXIT           = 5'h1C;
parameter L2_CPM_ENTRY          = 5'h1D;
parameter L2_CPM_EXIT           = 5'h1E;

// Slave state machine
parameter S_IDLE                = 5'h0;
parameter S_RESPOND_NAK         = 5'h1;
parameter S_BLOCK_TLP           = 5'h2;
parameter S_WAIT_LAST_TLP_ACK   = 5'h3;
parameter S_LINK_ENTR_L1        = 5'h5;
parameter S_L1                  = 5'h6;
parameter S_L1_EXIT             = 5'h7;
parameter S_L23RDY              = 5'h8;
parameter S_LINK_ENTR_L23       = 5'h9;
parameter S_L23RDY_WAIT4ALIVE   = 5'hA;
parameter S_ACK_WAIT4IDLE       = 5'hB;
parameter S_WAIT_LAST_PMDLLP    = 5'hC;
parameter S_NAK_BLOCK_TLP       = 5'hD;
parameter S_WAIT_NAK_TLP_ACK    = 5'hE;
parameter S_WAIT_NAK_TIMER      = 5'hF;

parameter PM_D0_UINI    = 3'b100;                 // 3'b001 indicates D1 state
parameter PM_D0_ACT     = 3'b000;
parameter PM_D1         = 3'b001;
parameter PM_D2         = 3'b010;
parameter PM_D3         = 3'b011;
parameter PM_SYNC_DEPTH = 2;
localparam US_TIMER_WD          = log2roundup(100000); // = 12 bits, use function for readability only, number of bits to count worst case which is t_power_on_value = 31 with a scale of 100us


//------------------------------------------------------------------------------
// Internal signals declaration
//------------------------------------------------------------------------------
//
parameter FREQ_VALUE  = `CX_FREQ_VALUE;

reg     [13:0]      l0s_idle_timer;
reg     [13:0]      l1_idle_timer;
reg     [11:0]      timer;
reg     [(PM_MST_WD - 1):0]  master_state;
reg     [(PM_SLV_WD - 1):0]  slave_state;
wire    [NL-1:0]    sync_phy_rxelecidle;        // internal synchronized version of phy_mac_rxelecidle due to the asynchronous nature of this signal
wire    [NL-1:0]    int_active_lane_rxelecidle;
reg     [NL-1:0]    int_active_lane_rxelecidle_r;
wire                int_rxelecidle_deassert; // Bitwise AND of phy_mac_rxelecidle indicates any lane has de-asserted rxelecidle

// switch_device and upstream_port signals should be set as following to
// form different devices:
// 1. switch device -- switch_device = 1'b1,
// 2. upstream port of a switch -- switch_device = 1'b1 and upstream_port = 1'b1
// 3. downstream port of a switch -- switch_device = 1'b1 and upstream_port = 1'b0
// 4. end device -- switch_device = 1'b0 and upstream_port = 1'b1;
// 5. root complex -- rc_device = 1'b1 and switch_device = 1'b0 and upstream_port = 1'b0;
// 6. bridge (similiar to end device) -- switch_device = 1'b0 and upstream_port = 1'b1;
//
wire    [10:0]      l0s_idle_timer_value;
reg     [10:0]      l0s_idle_timer_value_int;
wire    [10:0]      l0s_idle_timer_value_mpcie;
wire    [13:0]      l1_idle_timer_value;
reg     [13:0]      l1_idle_timer_value_int;
wire    [13:0]      l1_idle_timer_value_mpcie;
wire                timer_95us_expired;
reg                 timeout_95us_reg;
wire                timer_10us_expired;
wire                timer_95us_expired_int;
wire                timer_10us_expired_int;
wire                timer_95us_expired_mpcie;
wire                timer_10us_expired_mpcie;
wire    [11:0]      timer_9_728us_limit_mpcie;
wire    [11:0]      timer_10_24us_limit_mpcie;
reg                 timer_10us_expired_reg;

reg                 pm_xmt_asnak;
reg                 pm_smlh_entry_to_l0s;       // entry to L0s
reg                 pm_smlh_l0s_exit;           // exit xmtr L0s
reg                 pm_smlh_entry_to_l1;        // entry to L1
reg                 pm_smlh_l1_exit;            // exit xmtr L1
reg                 pm_smlh_l23_exit;           // exit xmtr L1
reg                 pm_xtlh_block_tlp;
reg                 pm_block_all_tlp;
reg                 pm_l1_aspm_entr;
reg     [NF-1:0]    pm_radm_block_tlp;
wire                pm_xdlh_enter_l1;
wire                pm_xdlh_enter_l23;
wire                pm_l1_aspm_flag;
wire                pm_l23_entry_flag;
reg                 pm_xdlh_req_ack;
wire                pm_xdlh_actst_req_l1;
wire                pm_timeout;
wire                pm_l23_entry_restart;
wire                pm_l23_hs_done;
wire                pm_l1_pcipm_hs_done;
wire                pm_l1_aspm_hs_done;
reg                 pm_freeze_fc_timer;
reg                 pm_freeze_cpl_timer;
reg                 pm_smlh_entry_to_l2;        // entry to L2
reg                 pm_smlh_prepare4_l123;
wire                wake;
reg                 local_ref_clk_req_n;
reg                 pm_phy_beacongen;

reg     [NF-1:0]    pm_dstate_d0_uninit;
reg     [NF-1:0]    pm_dstate_d0_act;
reg     [NF-1:0]    pm_dstate_d1;
reg     [NF-1:0]    pm_dstate_d2;
reg     [NF-1:0]    pm_dstate_d3;

wire  l0s_entr_cond4timeout_met;
wire  int_l0s_det_idle;
wire  l1_entr_cond4timeout_met;
wire  pm_req_exit_p2; // pm block request to transition powerdown from p2 to p1

wire                next_pm_state_is_l1;
wire                aux_clk_en_1us;
wire                int_block_l1_exit;
wire                int_hold_in_l1;

// There are two conditions that we may want to generated beacon on our transmitter
// 1. when PME state controls to reactivate the link
// 2. when any downstream port of switch device has exit from L23.
wire    wakeup_event;
assign wakeup_event = link_reactivate | (one_dwsp_exit_l23 & upstream_port & switch_device);

wire l0s_aspm_en;
wire l1_aspm_en;
// power D state determines the link permission of entering into L0s, L1,
// L2 and L3 state. Below signals are the enable signals used to enable the
// link state enter. The condition of entering l-state is determined as
// following:
// 1. According to spec. table 5-2 of section 5.3.2:
//      D0   -----    L0, L0s and L1
//      D1   -----    L1
//      D2   -----    L1
//      D3hot-----    L1, L2/3 ready
//      D3code ---    L2, L3
// 2. When ASPM control (i.e cfg_aslk_pmctrl) is programmed:
//      00   -----    Non ASPM enter L0s or L1
//      01   -----    L0s by ASPM
//      10   -----    L1 by ASPM
//      11   -----    L0s and L1 by ASPM
reg [NF-1:0]   l0s_aspm_en_vec;
reg [NF-1:0]   l1_aspm_en_vec;
always @(pm_aslk_pmctrl or pm_dstate_d0_act or pm_dstate_d1 or pm_dstate_d2 or pm_dstate_d3)
begin : L0S_ASPM
    integer i;
    reg [NF-1:0] l0s_pf_en_vec;
    for (i=0; i<NF; i=i+1)
      l0s_pf_en_vec[i] = pm_aslk_pmctrl[(i*2)];

    for (i =0; i < NF; i=i+1) begin
        // only the function has D0 state has effect on l0s enable
        // when all function's Dstate is programmed to active, and all functions ASPM l0s is enabled, then the l0s is enabled
        l0s_aspm_en_vec[i] = (pm_dstate_d0_act[i] & l0s_pf_en_vec[i]) | ((pm_dstate_d1[i] | pm_dstate_d2[i] | pm_dstate_d3[i]) & (|l0s_pf_en_vec));
    end
end

always @(pm_aslk_pmctrl or pm_dstate_d0_act or pm_dstate_d1 or pm_dstate_d2 or pm_dstate_d3)
begin : L1_ASPM
    integer i;
    reg [NF-1:0] l1_pf_en_vec;

    for (i=0; i<NF; i=i+1)
      l1_pf_en_vec[i] = pm_aslk_pmctrl[(i*2)+1];

    for (i =0; i < NF; i=i+1) begin
        l1_aspm_en_vec[i] = (pm_dstate_d0_act[i] & l1_pf_en_vec[i]) | ((pm_dstate_d1[i] | pm_dstate_d2[i] | pm_dstate_d3[i]) & (|l1_pf_en_vec));
    end
end

assign l0s_aspm_en = upstream_port ? (&l0s_aspm_en_vec) : l0s_aspm_en_vec[0];          // when all functions that has aspm l0s enable, then it can go into l0s state

assign l1_aspm_en  = upstream_port ? (&l1_aspm_en_vec) : l1_aspm_en_vec[0];           // when all L1 is enabled by all funcations, then it can go into L1 state

wire int_l1_en;
// when power management D1 or deeper state is programmed
assign int_l1_en   = &(pm_dstate_d1 | pm_dstate_d2 | pm_dstate_d3) & upstream_port;

wire software_entr_l23;
assign software_entr_l23 = pm_l23_entry_restart || (int_pme_nego_done && app_ready_entr_l23);

wire software_entr_l1;
assign software_entr_l1   = int_l1_en;


// -----------------------------------------------------------------------------
// ENTER L1 Condition
// -----------------------------------------------------------------------------
// There are many conditions that cause pm link enter l1
// 1. software program Dstate to request entering of L1
// 2. ASPM L1 is enabled and L1 enter conditions are met
// 3. Other external reason
// Note: As a swtich component, it is software's responsibility to
// program downstream ports entering L1 before upstream port is programmed.
// This PM design will not guard for this condition. If all ports of switch
// are enabled with ASPM L1, then upstream port L1 entering will only be
// possible when all downstream ports are in L1 and upstream ASPM L1
// entering conditions are met.
//

reg latch_as_entr_l1;
reg l1_timeout_req_enter_l1;
// L1 deadlock avoidance
always @* begin
   pm_l1_aspm_entr = latch_as_entr_l1 && (((master_state == L0) && int_l1_aspm_ready) ||
                                          (master_state == WAIT_PMCSR_CPL_SENT) ||  
                                          (master_state == L1_BLOCK_TLP) ||
                                          (master_state == L1_WAIT_LAST_TLP_ACK) ||
                                          (master_state == L1_WAIT_PMDLLP_ACK) ||
                                          (master_state == WAIT_LAST_PMDLLP));
end

always @(posedge aux_clk or negedge pwr_rst_n)
begin
  if (!pwr_rst_n)
    latch_as_entr_l1    <=  #TP 0;
  // we will latch the reason of state transition from L0 or L0s
  // to L1 so that we could generate proper pm dllp handshake
  else if ((master_state == L0) | (master_state == L0S))
    latch_as_entr_l1    <=  #TP !software_entr_l1;
end

reg latch_app_entr_l1;

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n)
        latch_app_entr_l1    <=  #TP 1'b0;
    else if (((master_state == L0) | (master_state == L0S) | (master_state == ENTER_L0S) | (master_state == L0S_EXIT)) & app_req_entr_l1)
        // we will latch the reason of state transition from L0 or L0s
        // to L1 so that we could generate proper pm dllp handshake
        latch_app_entr_l1    <=  #TP 1'b1;
    else if (master_state == L1)
        latch_app_entr_l1    <=  #TP 1'b0;
end
// -----------------------------------------------------------------------------
// EXIT L1 Condition triggered by downstream
// -----------------------------------------------------------------------------
// Exit L1 starts by
// 1. upstream components with pme request
// 2. down stream ports with traffic pending for transmit
// 3. Or endpoint device with a wake up call that can either be a WOL or
//    TLP pending to be sent

wire int_l1_exit;
assign int_l1_exit = software_entr_l23                                  // when in L1 and PM turnoff fencing is done.
                     | app_req_exit_l1                                    // allow application request to exit L1
                     | (apps_pm_xmt_turnoff && !upstream_port)            // if we need to transmit a turn off message we need to restore the clock if unavailable
                     | pm_pme_exit_l1                                    // Wakeup request exits L1
                     | (!xdlh_not_expecting_ack)                          // When there is stuff in retry buffer, we will start again because L1 is not intended to have stuff left in retry buffer
                     | int_rxelecidle_deassert                               // when phy detected electric idle exit. This is useful for identify PHY exit to command PM state change for application that intended to not supply clock
                     | (upstream_port & switch_device & one_dwsp_exit_l1 & latch_as_entr_l1)  // when ASPM enter L1 and down stream port is in exit of L1
                     | (upstream_port & switch_device & all_dwsp_rcvd_toack_msg)  // when UP SP and all downstream ports have acknowledged turnoff
                     | xfer_pending
                     | pm_wake_l1_exit
                     ;

wire int_master_in_l1_s;
assign int_master_in_l1_s = (master_state == L1) || (master_state == L1_CPM_ENTRY) || (master_state == L1_CPM_EXIT) ;
reg latch_int_l1_exit;
always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n)
        latch_int_l1_exit    <=  #TP 1'b0;
    else if ( ((int_master_in_l1_s) | (slave_state == S_L1)) & int_l1_exit )
        // make the condition persistent so that single cycle events won't be missed
        latch_int_l1_exit    <=  #TP 1'b1;
    else if ( !((int_master_in_l1_s) | (slave_state == S_L1)) )
        latch_int_l1_exit    <=  #TP 1'b0;
end



// -----------------------------------------------------------------------------
//  Master State Machine
// -----------------------------------------------------------------------------
// This state machine controls the activities between D state that software
// program and the active power management state of PCI express native.
// This state machine provides the control to PHY link state machine on
// behave of power management.
//
wire        l0s_idle_timeout;
assign l0s_idle_timeout = l0s_aspm_en & (l0s_idle_timer[10:0] >= (l0s_idle_timer_value - FREQ_MULTIPLIER));

wire l1_entr_cond4app_met;
wire l1_idle_timeout;
assign l1_idle_timeout  = l1_aspm_en & (l1_idle_timer >= (l1_idle_timer_value - FREQ_MULTIPLIER)) & (l1_entr_cond4timeout_met | l1_entr_cond4app_met);

// set flag to indicate L0S idle timeout
assign int_clear_l0s_timeout = (master_state == WAIT_PMCSR_CPL_SENT) || (master_state == L1_BLOCK_TLP) || (master_state == L23_BLOCK_TLP) || (master_state == L0S_BLOCK_TLP) || !phy_link_up;

always @ *
begin
  if(int_clear_l0s_timeout)
    int_l0s_idle_timeout_s = 1'b0;
  else if(l0s_idle_timeout)
    int_l0s_idle_timeout_s = 1'b1;
  else
    int_l0s_idle_timeout_s = int_l0s_idle_timeout_r;
end

always @(posedge aux_clk or negedge pwr_rst_n)
begin
  if(!pwr_rst_n)
  begin
    int_l0s_idle_timeout_r <= #TP 1'b0;
  end
  else
  begin
      int_l0s_idle_timeout_r <= #TP int_l0s_idle_timeout_s;
  end
end

wire slave_entering_block_tlp;
// In DSP, use dsp_ready_for_l0s to indicate that the slave FSM
// is not in L1/L23 negotiation, and is ready for l0s entry.
wire dsp_ready_for_l0s;
assign dsp_ready_for_l0s = upstream_port ? 1 : ( (slave_state==S_IDLE) & !slave_entering_block_tlp );

// This is introduced for entering L1 after L1 timeout or application
// request enter L1
// latched the status of this core wants to initiate an enter of l1 when it
// has been in L0s for certain amount of time.
// If L1 entry must be preceeded by L0S
assign int_l0s_l1_timeout_s = !pm_l1_entr_wo_rl0s && ((master_state == L0S) || (master_state == L0S_EXIT)) && l1_idle_timeout;
// L1 entry without L0S first
assign int_no_l0s_bef_l1 = !l0s_aspm_en || pm_l1_entr_wo_rl0s;
assign int_l1_idle_timeout_s = int_no_l0s_bef_l1 && l1_idle_timeout;
assign int_l1_timeout_s = int_l0s_l1_timeout_s || int_l1_idle_timeout_s;

// Switch upstream port is allowed to enter ASPM L1 if all switch DSP's are in L1 and there are no TLP's or DLLP's pending
// and the L1 ASPM timer has expired.
assign int_en_sw_usp_aspm_l1 = ((all_dwsp_in_l1 && switch_device && upstream_port && no_dllp_pending && !pm_wake_tlp_pending) && int_l1_timeout_s);
// Non switch upstream port is allowed to enter APSM L1 if the L1 ASPM timer has expired
assign int_en_usp_aspm_l1 = ((!switch_device && upstream_port) && int_l1_timeout_s);
// If the L1 ASPM entry conditions are no longer satisfied while we are waiting for the 10us timer to expire
// ASPM L1 entry will not be permitted
assign int_disable_aspm_l1 = !(l1_entr_cond4timeout_met || l1_entr_cond4app_met) && !timer_10us_expired_reg;
// Clear the L1 ASPM entry request when negotiation started or if during L0S_EXIT a transfer becomes pending
assign int_tx_pending = pm_wake_tlp_pending || !no_acknak_dllp_pending || xfer_pending;
assign int_trgt0_pending = (master_state == L0S_EXIT) && radm_trgt0_pending;
assign int_pending_clear_timeout = l1_aspm_en && ( int_tx_pending || int_trgt0_pending );
assign int_clear_l1_timeout = ((master_state == L1_WAIT_LAST_TLP_ACK) || !l1_aspm_en || int_pending_clear_timeout);

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if(!pwr_rst_n)
        l1_timeout_req_enter_l1 <= #TP 1'b0;
    else if (int_disable_aspm_l1)
        l1_timeout_req_enter_l1 <= #TP 1'b0;
    else if (int_clear_l1_timeout)
        l1_timeout_req_enter_l1 <= #TP 1'b0;
    else if (int_en_sw_usp_aspm_l1 || int_en_usp_aspm_l1)
        l1_timeout_req_enter_l1 <= #TP 1'b1;
end

// Create an internal signal to indicate PHY link up and LTSSM not in recovery
assign int_link_up_not_rcvry = !smlh_link_in_training && phy_link_up;

assign int_smlh_in_l1 = pm_pl_l1_nowait_p1 ? smlh_in_l1 : smlh_in_l1_p1;

// FSM returns to IDLE state if Recovery or link goes down
assign int_idle_next = smlh_link_in_training || !phy_link_up;

assign int_freq_step_smlh_in_l1 = int_smlh_in_l1;
assign int_next_state_is_l23 = smlh_in_l23;

assign int_next_state_is_l1 = pm_clk_pm_en ? smlh_in_l1 : int_freq_step_smlh_in_l1;
assign int_start_l1_aspm = (!pm_l2_entry_flag && ((l1_timeout_req_enter_l1 && timer_10us_expired_reg) || pm_l1_aspm_flag)
);

// PCI-PM L1 entry ready to start
assign int_start_l1_pcipm = (!pm_l2_entry_flag && software_entr_l1);

// L1 ASPM entry is about to be initiated by the USP
assign int_l1_aspm_ready = int_start_l1_aspm && (master_state == L0);
// Detect potential race condition between L1 ASPM entry initiation and RADM TRGT0 pending
// The L1 ASPM negotiation should not begin until the RADM TRGT0 non posted requests are halted
// and there are no transfers pending to TRGT0
assign int_l1_aspm_radm_race = (int_l1_aspm_ready && radm_trgt0_pending) ? 1'b1 : (!radm_trgt0_pending ? 1'b0 : int_l1_aspm_radm_race_r);

// L1 negotiation request either due to ASPM or PCI-PM the distinction will be in the type of DLLP sent but otherwise
// the state transitions in the master FSM are the same.
assign int_start_l1_nego = int_start_l1_pcipm || int_start_l1_aspm;
// Take into account pending TLP's in XADM/XTLH/XDLH and insure XADM itself is IDLE
assign int_block_tlp_ack = (!pm_wake_tlp_pending && xadm_block_tlp_ack);

wire int_l1_exit_req_s;
assign int_l1_exit_req_s =  !phy_link_up || latch_int_l1_exit;

logic int_l2_exit_req_s;
assign int_l2_exit_req_s = wakeup_event || (int_rxelecidle_deassert && !pmu_l2_pd);
logic int_l2_wakeup_flag_r;
logic int_l2_wakeup_flag_s;
logic int_set_wakeup_flag_s;
logic int_clear_wakeup_flag_s;

assign int_set_wakeup_flag_s = int_l2_exit_req_s;
assign int_clear_wakeup_flag_s = (master_state == IDLE) || (master_state == L23RDY_WAIT4ALIVE);

always_comb begin : l2_wakeup_PROC
  if(int_set_wakeup_flag_s)
    int_l2_wakeup_flag_s = 1'b1;
  else if(int_clear_wakeup_flag_s)
    int_l2_wakeup_flag_s = 1'b0;
  else
    int_l2_wakeup_flag_s = int_l2_wakeup_flag_r;
end : l2_wakeup_PROC

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : l2_wakeup_reg_PROC
  if(!pwr_rst_n)
    int_l2_wakeup_flag_r <= #TP 1'b0;
  else
    int_l2_wakeup_flag_r <= #TP int_l2_wakeup_flag_s;
end : l2_wakeup_reg_PROC

reg int_pd_p2_r;

always @(posedge aux_clk or negedge pwr_rst_n) begin : pd_p2_PROC
  if(!pwr_rst_n)
    int_pd_p2_r <= #TP 1'b0;
  // if perst is asserted abort the handshake since we will reset the PHY on perst de-assertion
  else if(!perst_n || current_powerdown_p2)
    int_pd_p2_r <= #TP 1'b1;
  // clear the flag
  else if(!pm_linkst_in_l23rdy)
    int_pd_p2_r <= #TP 1'b0;
  else
    int_pd_p2_r <= #TP int_pd_p2_r;
end : pd_p2_PROC

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n) begin
        master_state    <= #TP IDLE;
    end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Disable this check on legacy code. 
        case (master_state)
// spyglass enable_block STARC05-2.11.3.1
        IDLE:
            if (int_link_up_not_rcvry)
                master_state    <= #TP L0;
        L0:
            // If LTSSM enters Recovery the FSM transitions back to IDLE
            if (int_idle_next)
                master_state    <= #TP IDLE;
            // Start L2 entry negotiation
            else if (software_entr_l23)
                master_state    <= #TP L23_BLOCK_TLP;
            // Start L1 negotiation
            else if (int_start_l1_nego)
                master_state    <= #TP WAIT_PMCSR_CPL_SENT;
            // Start ASPM L0S entry
            else if (!pm_l2_entry_flag && dsp_ready_for_l0s && int_l0s_idle_timeout_r)
                master_state    <= #TP L0S_BLOCK_TLP;

        L0S_BLOCK_TLP:
            if (!int_l0s_det_idle)
                master_state    <= #TP L0;
            else if (int_block_tlp_ack)
                master_state    <= #TP ENTER_L0S;
            else
                master_state    <= #TP L0S_BLOCK_TLP;

        ENTER_L0S:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            else if (smlh_in_l0s)
                master_state    <= #TP L0S;

        L0S:
            // we will exit l0s when
            // 1. there are traffic to transmit
            // 2. when upstream port detect l0s_exit
            // 3. when down stream port detect l0s_exit
            // 5. or upstream port
            // detect all down steam port in L1 and it is enabled for l1
            // entry
            // PS. l1 idle timer will not increase unless the above
            // condition 4 are met
            //
            // Enter L1 conditions because of ASPM enabled :
            // 1. l1 timer expired in L0s state with upstream port of non
            // switch device
            // 2. l1 timer expired in L0s state with upstream port of
            // swtich device and its downstream ports are all in L0s
        //
        // Exit L0s for switch device:
        // 1. For upstream port of the switch, it exits when one of the
        // dwsp is not in rl0s
        // 2. For donwstream port of the switch, it exits when
        // the upstream port is not in rl0s

            if (pm_wake_req_exit_l0s | !no_dllp_pending | !smlh_in_l0s              // smlh_in_l0 is an error condition that gets ltssm exited the xmt l0s exit
                | slave_entering_block_tlp                                          // For DSP, if there is req to enter l1, exit l0s
                | (!upsp_in_rl0s & !upstream_port & switch_device) | (!all_dwsp_in_rl0s & upstream_port & switch_device)  // exit of l0s for switch device
            | (l1_idle_timeout & ((upstream_port & !switch_device) | (all_dwsp_in_l1 & switch_device & upstream_port))))
                master_state    <= #TP L0S_EXIT;

        L0S_EXIT:
            // In this case LTSSM exits L0S to L0 so we will return to L0 state
            // L1 idle timer will continue to increment (if L1 entry does not depend on L0S)
            if (!smlh_in_l0s)
                master_state    <= #TP L0;

        L1_BLOCK_TLP:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            else if (int_block_tlp_ack)
                master_state    <= #TP L1_WAIT_LAST_TLP_ACK;

        L1_WAIT_LAST_TLP_ACK:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            // no TLP being replayed and all TLP's acknowledged and sufficient credits to send maximum sized TLP
            else if (!xdlh_retry_pending && (&xtlh_had_enough_credit))
                master_state    <= #TP L1_WAIT_PMDLLP_ACK;

       L1_WAIT_PMDLLP_ACK:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            else if (latch_as_entr_l1 && radm_pm_asnak)
                master_state    <= #TP  L0;                 // designed for pipe line of xdlh to be cleared
            else if (rdlh_rcvd_pm_req_ack && (pm_l1_pcipm_hs_done || pm_l1_aspm_hs_done))
                master_state    <= #TP  WAIT_LAST_PMDLLP;

        PREP_4L1:
            master_state    <= #TP L1_LINK_ENTR_L1;

        L1_LINK_ENTR_L1:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            else if (int_next_state_is_l1)
                master_state    <= #TP L1;

        L1:
            // L1 CPM entry when powerdown phystatus handshake completed
            if (int_override_pd_r && int_freq_step_smlh_in_l1)
                master_state    <= #TP L1_CPM_ENTRY;
            else if (int_hold_in_l1)
                master_state    <= #TP L1; // keep the master_state into L1 until l1sub_state == L1_U
            // 1. the eidle order set receive is a sign of
            // remote side trying to get out of low power state
            // Downstream wakeup for end-point
            // 2. such as WOL
            else if (!phy_link_up)  // if the link goes down reset to IDLE state 
                master_state    <= #TP IDLE;
            else if (latch_int_l1_exit)   // When serveral event wants to command LTSSM exit L1
                master_state    <= #TP L1_EXIT;
        L1_EXIT:
            if (!latch_as_entr_l1 && smlh_in_l0)
                master_state    <= #TP WAIT_DSTATE_UPDATE;
            else if (smlh_in_l0)
                master_state    <= #TP L0;
            else if (!phy_link_up)  // added to prevent a dead lock just in case that core is programmed to D1.. state mistakenly
                master_state    <= #TP IDLE;

        L23_BLOCK_TLP:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            else if (int_block_tlp_ack)
                master_state    <= #TP L23_WAIT_LAST_TLP_ACK;

        L23_WAIT_LAST_TLP_ACK:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            // no TLP being replayed and all TLP's acknowledged and sufficient credits to send maximum sized TLP
            else if (!xdlh_retry_pending && (&xtlh_had_enough_credit))
                master_state    <= #TP L23_WAIT_PMDLLP_ACK;

        L23_WAIT_PMDLLP_ACK:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            else if (rdlh_rcvd_pm_req_ack && pm_l23_hs_done)
                master_state    <= #TP WAIT_LAST_PMDLLP;

        PREP_4L23:
            master_state    <= #TP L23_ENTR_L23;

        L23_ENTR_L23:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            else if (int_next_state_is_l23)
                master_state    <= #TP L23RDY;

        L23RDY:
            // Hold until P2 transition is acknowledged by the PHY
            if (!int_pd_p2_r)
                master_state    <= #TP L23RDY;
            // CLKREQ# de-assertion in L2.CPM
            else if (pm_clk_pm_en)
                master_state    <= #TP L2_CPM_ENTRY;
            else if (wakeup_event)
            // At this state, when aux power is enabled, then this state is
            // D3 hot. When there is no aux power detected, then this is
            // the D3 cold. At this point, this is the state required Aux
            // power for its operation
            // 1. when phy has detected beacon, then the phy_mac_rxelecidle
            // will be deasserted based on PIPE spec. This is a condition of
            // wakeing up the PM state while this pm module is in Aux power
                master_state    <= #TP L23RDY_WAIT4ALIVE;
            else if (int_rxelecidle_deassert && !pmu_l2_pd)
                master_state    <= #TP IDLE;
            else
                master_state    <= #TP L23RDY;

        L23RDY_WAIT4ALIVE:
            if (int_rxelecidle_deassert && !pmu_l2_pd)
                master_state    <= #TP IDLE;

        WAIT_LAST_PMDLLP:
            if (int_idle_next)
                master_state    <= #TP IDLE;
            else if (xdlh_last_pmdllp_ack && pm_l23_entry_flag)
                master_state    <= #TP PREP_4L23;
            else if (xdlh_last_pmdllp_ack)
                master_state    <= #TP PREP_4L1;
            else
                master_state    <= #TP WAIT_LAST_PMDLLP;

        WAIT_DSTATE_UPDATE:
            if (software_entr_l23 || (!software_entr_l1 && !lbc_active) || pm_timeout)
                master_state    <= #TP L0;
            else
                master_state    <= #TP WAIT_DSTATE_UPDATE;
       
        WAIT_PMCSR_CPL_SENT:
            if (!(lbc_active || int_l1_aspm_radm_race_r))
                master_state    <= #TP L1_BLOCK_TLP;
            else
                master_state    <= #TP WAIT_PMCSR_CPL_SENT;
        

        // negotiate the removal of the reference clock with the PHY
        L1_CPM_ENTRY:
            if(int_phy_clk_req_n_r && int_l1_exit_req_s)
                master_state    <= #TP L1_CPM_EXIT;
            else
                master_state    <= #TP L1_CPM_ENTRY;

        // negotiate the enabling of the reference clock with the PHY
        L1_CPM_EXIT:
            if(!int_phy_clk_req_n_r)
                master_state    <= #TP L1_EXIT;
            else
                master_state    <= #TP L1_CPM_EXIT;

        // negotiate the removal of the reference clock with the PHY for P2.CPM
        L2_CPM_ENTRY:
            if(int_phy_clk_req_n_r && int_l2_exit_req_s)
                master_state    <= #TP L2_CPM_EXIT;
            else
                master_state    <= #TP L2_CPM_ENTRY;
        L2_CPM_EXIT:
            if(!int_phy_clk_req_n_r && int_l2_wakeup_flag_r)
                master_state    <= #TP L23RDY_WAIT4ALIVE;
            else
                master_state    <= #TP L2_CPM_EXIT;

        default: begin
            master_state    <= #TP IDLE;
        end
        endcase
    end
end

// slave state machine is designed to handle L1 enter and it responds to
// a upstream port of downstream component's L1 enter negotiation
// Note: Slave state machine is only used in downstream port of RC or Switch

// master_engage_in_l0s
// Master FSM is already in progress to L0s. Prevent Slave FSM from entre
// L1/L2/L3 when Master FSM already in L0s.
wire master_engage_in_l0s;
assign master_engage_in_l0s = ((master_state == L0S_BLOCK_TLP) || (master_state == ENTER_L0S) 
                            || (master_state == L0S)           || (master_state == L0S_EXIT) );

// slave_entering_block_tlp: asserted whenever the condition to enter
// S_BLOCK_TLP is met. This signal is used to block the other FSM 
// from entering other states when SLV_FSM's next state is S_BLOCK_TLP.
assign slave_entering_block_tlp = int_link_up_not_rcvry & !upstream_port &
                    (rdlh_rcvd_as_req_l1 | rdlh_rcvd_pm_enter_l1 | rdlh_rcvd_pm_enter_l23);  // entring the L1 or L23

reg latched_entr_l23;

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n)
        slave_state <= #TP S_IDLE;
    else
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Disable this check on legacy code. 
        case (slave_state)
// spyglass enable_block STARC05-2.11.3.1
        S_IDLE:
            // Requirement:  When received DLLP of AS request enter L1,
            // a NAK or ACK has to be immediately scheduled. And the
            // decision made for ACK or NAK has to be maintain. It is not
            // allowed to answer both ACK and NAK for the same L1 request
            // protocol. This change is due to the errata of the PCIE spec.
            // when request enter L1 by ASPM protocol but the entering L1
            // conditions are not met
            if (int_next_resp_nak) 
                slave_state <= #TP S_RESPOND_NAK;
            else if ( slave_entering_block_tlp & !master_engage_in_l0s )  // accept the L1 or L23 enter request
                slave_state <= #TP S_BLOCK_TLP;
            else
                slave_state <= #TP S_IDLE;

        S_RESPOND_NAK:
            // Assumption: when the LTSSM is in L0s receiver state, it
            // means that the initiator of ASPM L1 has received the NAK and
            // properly terminated its L1 request protocol
            if (!phy_link_up)
                slave_state <= #TP S_IDLE;
            else if(msg_gen_asnak_grt)
                slave_state <= #TP S_NAK_BLOCK_TLP;
            else
                slave_state <= #TP S_RESPOND_NAK;

        S_NAK_BLOCK_TLP:
            // Block TLP transmission until the PM_Active_State_Nak has been transmitted
            if(!phy_link_up)
                slave_state <= #TP S_IDLE;
            else if(int_block_tlp_ack)
                slave_state <= #TP S_WAIT_NAK_TLP_ACK;
            else
                slave_state <= #TP S_NAK_BLOCK_TLP;
        
        S_WAIT_NAK_TLP_ACK:
            // Block TLP transmission until the PM_Active_State_Nak has been acknowledged by link partner
            if (!phy_link_up)
                slave_state <= #TP S_IDLE;
            // no TLP being replayed and all TLP's acknowledged
            else if (!xdlh_retry_pending)
                slave_state <= #TP S_WAIT_NAK_TIMER;
            else
                slave_state <= #TP S_WAIT_NAK_TLP_ACK;

        S_WAIT_NAK_TIMER:
            // Wait for 9.5us timer to expire
            if ((timeout_95us_reg)
               )
                slave_state <= #TP S_IDLE;

        S_BLOCK_TLP:
            if (int_idle_next)
                slave_state <= #TP S_IDLE;
            else if (int_block_tlp_ack)
                slave_state <= #TP S_WAIT_LAST_TLP_ACK;

        S_WAIT_LAST_TLP_ACK:
            if (int_idle_next)
                slave_state <= #TP S_IDLE;
            // no TLP being replayed and all TLP's acknowledged
            else if (!xdlh_retry_pending)
                slave_state <= #TP S_ACK_WAIT4IDLE;

        S_ACK_WAIT4IDLE:
            if (int_idle_next)
                slave_state <= #TP S_IDLE;
        // we need to consider the case that phy is not reporting
        // rxelectric idle, so that we need to enter L1 state.
        // Here smlh_in_l1 is asserted in the condition for this
        // purposes. Note there is no check that the PM_Request_Ack DLLP
        // has been sent since we will proceed to low power state anyway
        // once electrical idle is detected
            else if ((latched_rcvd_eidle_set || smlh_l123_eidle_timeout))
                slave_state <= #TP S_WAIT_LAST_PMDLLP;
            else
                slave_state <= #TP S_ACK_WAIT4IDLE;

        S_LINK_ENTR_L1:
            if (int_idle_next)
                slave_state <= #TP S_IDLE;
            else if (int_next_state_is_l1)
                slave_state <= #TP S_L1;

        S_LINK_ENTR_L23:
            if (int_idle_next)
                slave_state <= #TP S_IDLE;
            else if (int_next_state_is_l23)
                slave_state <= #TP S_L23RDY;

        S_L1:
            if (int_hold_in_l1)
                slave_state    <= #TP S_L1; // keep the slave_state into L1 until l1sub_state == L1_U
            // exit of L1 can be formed from two conditions:
            // 1. exit when this port has tlp to be transmit
            // 2. exit when link detected L1 exit from link state machine
            // in xmlh
            else if (!phy_link_up)                     // when remote site wants to exit the L1
                slave_state <= #TP S_IDLE;
            else if (latch_int_l1_exit)       // when there is a tlp pending for transimission or received detect the exit of elecidle
                slave_state <= #TP S_L1_EXIT;

        S_L1_EXIT:
            if (smlh_in_l0 || !phy_link_up)
                slave_state <= #TP S_IDLE;

        S_L23RDY:
            // Hold until P2 transition is acknowledged by the PHY
            if (!int_pd_p2_r)
                slave_state <= #TP S_L23RDY;
            else if(pm_phy_rst_done)
                slave_state <= #TP S_IDLE;
            else if (wakeup_event)
                slave_state <= #TP S_L23RDY_WAIT4ALIVE;
            else if (int_rxelecidle_deassert && !pmu_l2_pd)
                slave_state <= #TP S_IDLE;

        S_L23RDY_WAIT4ALIVE:
            if (int_rxelecidle_deassert && !pmu_l2_pd)
                slave_state <= #TP S_IDLE;

        S_WAIT_LAST_PMDLLP:
            if (int_idle_next)
                slave_state    <= #TP S_IDLE;
            else if (latched_entr_l23 && xdlh_last_pmdllp_ack)
                slave_state <= #TP S_LINK_ENTR_L23;
            else if (xdlh_last_pmdllp_ack)
                slave_state <= #TP S_LINK_ENTR_L1;
            else
                slave_state <= #TP S_WAIT_LAST_PMDLLP;


        default:
            slave_state <= #TP S_IDLE;
        endcase
end



// we need to latch the condition that make the slave state transition from
// idle to acknowledgment since it is different for slave state to go into
// L1 verse L23
always @(posedge aux_clk or negedge pwr_rst_n)
    if (!pwr_rst_n)
        latched_entr_l23    <= #TP 0;
    else
        latched_entr_l23    <= #TP ((slave_state == S_IDLE) & rdlh_rcvd_pm_enter_l23) ? 1'b1 : (slave_state == S_IDLE) ? 1'b0 : latched_entr_l23;

// Choosing of the idle timer value is application specific. We have
// a l0s_entr_latency_timer programmable from port logic register to allow
// application to choose an algorithm and program the value
always @(l0s_entr_latency_timer )
    case (l0s_entr_latency_timer)
        3'b000:  l0s_idle_timer_value_int = 11'b00100000000 ;  // 1 us
        3'b001:  l0s_idle_timer_value_int = 11'b01000000000 ;  // 2 us
        3'b010:  l0s_idle_timer_value_int = 11'b01100000000 ;  // 3 us
        3'b011:  l0s_idle_timer_value_int = 11'b10000000000 ;  // 4 us
        3'b100:  l0s_idle_timer_value_int = 11'b10100000000 ;  // 5 us
        3'b101:  l0s_idle_timer_value_int = 11'b11000000000 ;  // 6 us
        3'b110:  l0s_idle_timer_value_int = 11'b11100000000 ;  // 7 us
        default: l0s_idle_timer_value_int = 11'b11100000000 ;  // 7 us
    endcase

assign l0s_idle_timer_value_mpcie = 11'h000 ;   // Not Used in Conventional PCIe.

assign l0s_idle_timer_value = (phy_type == `PHY_TYPE_MPCIE) ? l0s_idle_timer_value_mpcie : l0s_idle_timer_value_int ;



//The mechanism for the ASPM enters L1 is application specific. Here we
//choose a time out mechanism where the timer value is the half of the l1
//exit latency timer. The L1 time out only apply to ASPM control is enabled
//with L1 and the quiet condition met in L0s for the duration of time out time.

always @(l1_entr_latency_timer )
    case (l1_entr_latency_timer)
        3'b000:  l1_idle_timer_value_int = 14'b00000100000000 ;  // 1us
        3'b001:  l1_idle_timer_value_int = 14'b00001000000000 ;  // 2us
        3'b010:  l1_idle_timer_value_int = 14'b00010000000000 ;  // 4us
        3'b011:  l1_idle_timer_value_int = 14'b00100000000000 ;  // 8us
        3'b100:  l1_idle_timer_value_int = 14'b01000000000000 ;  // 16us
        3'b101:  l1_idle_timer_value_int = 14'b10000000000000 ;  // 32us
        3'b110:  l1_idle_timer_value_int = 14'b11111111111110 ;  // 64us, note for 2s design, we need to set this value to 3FFE
        default: l1_idle_timer_value_int = 14'b11111111111110 ;  // 64us
    endcase

assign l1_idle_timer_value_mpcie = 14'd0 ;   // Not Used in Conventional PCIe.

assign l1_idle_timer_value = (phy_type == `PHY_TYPE_MPCIE) ? l1_idle_timer_value_mpcie : l1_idle_timer_value_int ;

// Both transmit and receive must be in L0S before L1 ASPM entry
assign int_l0s_before_l1_entry = smlh_in_rl0s && (master_state == L0S) && !pm_l1_entr_wo_rl0s;
// L1 entry need not be preceeded by L0S
assign int_l1_entry_no_l0s = int_no_l0s_bef_l1 && ((master_state == L0) || (master_state == L0S_BLOCK_TLP) || (master_state == ENTER_L0S) || (master_state == L0S) || (master_state == L0S_EXIT));

// The conditions for enabling the L1 idle timer
// FC credit DLLP's will not reset the timer but outstanding Ack/Nak TLP's will reset the timer
// this is necessary to insure that the retry buffer is empty.
assign l1_entr_cond4timeout_met =  l1_aspm_en & ASPM_TIMEOUT_ENTR_L1_EN & !latch_app_entr_l1 & upstream_port
                                   & !pm_wake_tlp_pending & no_acknak_dllp_pending & (&xtlh_had_enough_credit)
                                   & (int_l0s_before_l1_entry || int_l1_entry_no_l0s)
                                   && !radm_trgt0_pending
                                   && !xfer_pending
                                   ;

// requirements for idleness in L0S
assign int_l0s_det_idle = ((!pm_wake_tlp_pending | (&no_fc_cds)) & xdlh_not_expecting_ack & no_dllp_pending & l0s_aspm_en
                            & !smlh_in_l1 & !smlh_in_l23
                            & (!switch_device | (all_dwsp_in_rl0s & upstream_port & switch_device)
                            | (upsp_in_rl0s & !upstream_port & switch_device)));

// increment the L0S idle timer when we are IDLE and in L0
assign l0s_entr_cond4timeout_met = ((master_state == L0) && dsp_ready_for_l0s && int_l0s_det_idle);

assign l1_entr_cond4app_met     = (l1_aspm_en & latch_app_entr_l1 & upstream_port & !pm_wake_tlp_pending & no_dllp_pending
                                    & (&xtlh_had_enough_credit) & (((smlh_in_rl0s | pm_l1_entr_wo_rl0s) & (master_state == L0S)) | (master_state == L0)))
                                   && !radm_trgt0_pending
                                   && !xfer_pending
                                   ;
wire        timer2;

DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1 (0)
) u_gen_timer2
(
     .clk               (aux_clk)
    ,.rst_n             (pwr_rst_n)

    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)

    ,.cnt_up_en         (timer2)  // timer count-up
);

// L0s timer increments on:
// 1. no tlp pendings or dllp pending or no flow control
// credits
// 2. (when it is end device or root complex or bridge) or
// a switch device with upstream port in received lanes are all
// in l0s state, or a switch device with all downstream ports
// receive lanes in l0s state
// 3. software configured this port to enable l0s transition
// 4. idle timer expired
always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if(!pwr_rst_n)
    begin
        l0s_idle_timer  <= #TP 0;
    end  
    else
    begin
        // Enable L0S timer
        if (l0s_entr_cond4timeout_met)
        begin
            l0s_idle_timer  <= #TP l0s_idle_timer + (timer2 ? FREQ_MULTIPLIER : 1'b0);
        end
        else
        begin
            l0s_idle_timer  <= #TP {14{1'b0}};
        end
    end
end

// l1 timer increments on:
// 1. Both tx and rx in l0s state for a duration of half of the L1 exit
// latency timer of an upstream component
// 2. and current port of all function's ASMP L1 entry is enabled
// 3. The rule for entering L1 is applicaiton specific. It is
// controlable by set the parameter in app*.vh
always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if(!pwr_rst_n)
    begin
        l1_idle_timer  <= #TP 0;
    end
    else
    begin
        if (l1_entr_cond4timeout_met)
        begin
            l1_idle_timer  <= #TP l1_idle_timer + (timer2 ? FREQ_MULTIPLIER : 1'b0);
        end else if (l1_entr_cond4app_met)
        begin
            l1_idle_timer  <= #TP {14{1'b1}};
        end
        else
        begin
            l1_idle_timer  <= #TP {14{1'b0}};
        end
    end
end

// For an Upstream port this timer implements the 10us timer requirement between
// transmission of PM_Active_State_Request_L1 DLLP's after a PM_Active_State_Nak message
// is received. For a Downstream port this timer implements the 9.5us timer requirement
// after the transmission of a PM_Active_State_Nak message during which the Downstream port
// does not receive any PM_Active_State_Enter_L1 DLLP's.
always @(posedge aux_clk or negedge pwr_rst_n)
begin : timer_PROC
  if(!pwr_rst_n) begin
    timer <= #TP 0;
  // Reset the timer if the link goes down
  end else if(!phy_link_up) begin
    timer <= #TP 0;
  // The timer holds in RECOVERY
  end else if((upstream_port && (master_state == IDLE)) ||
              (!upstream_port && smlh_link_in_training)) begin
    timer <= #TP timer;
  // For USP the timer counts in L0, DSP the timer counts in the S_WAIT_NAK_TIMER state
  end else if((upstream_port && ((master_state == L0) || (master_state == L0S_BLOCK_TLP) || (master_state == ENTER_L0S) || (master_state == L0S) || (master_state == L0S_EXIT)) && !timer_10us_expired_reg) ||
              (!upstream_port && (slave_state == S_WAIT_NAK_TIMER) && !timeout_95us_reg)) begin
    timer  <= #TP timer + (timer2 ? 1'b1 : 1'b0);
  // Otherwise reset the timer
  end else begin
    timer <= #TP 0;
  end
end : timer_PROC

// 9.728 us timeout for errata C7 9.5 us
assign timer_95us_expired       = (phy_type == `PHY_TYPE_MPCIE) ? timer_95us_expired_mpcie : timer_95us_expired_int ;


assign timer_95us_expired_int   = (FREQ_VALUE==0) ?  (timer[11] & timer[8] & timer[7]) :
                                  (FREQ_VALUE==1) ?  (timer[10] & timer[7] & timer[6]) :
                                                     (timer[ 9] & timer[6] & timer[5]);

always @(posedge aux_clk or negedge pwr_rst_n)
begin : timer_95_PROC
    if(!pwr_rst_n) begin
      timeout_95us_reg <= #TP 1'b1;
    // Set when the timer expires, Receiver goes to L0S, or link goes down
    // If a PM_Enter_L1 or PM_Enter_L23 DLLP is received for the timer to expire.
    end else if (timer_95us_expired_int || smlh_in_rl0s || !phy_link_up || rdlh_rcvd_pm_enter_l1 || rdlh_rcvd_pm_enter_l23) begin
      timeout_95us_reg <= #TP 1'b1;
    // Reset to 0 before the timer is started
    end else if (slave_state == S_WAIT_NAK_TLP_ACK) begin
      timeout_95us_reg <= #TP 1'b0;
    // Hold the value
    end else begin
      timeout_95us_reg <= #TP timeout_95us_reg;
    end
end : timer_95_PROC

assign timer_9_728us_limit_mpcie = 12'h000 ;  // Not Used in Conventional PCIe.
assign timer_95us_expired_mpcie  = 1'b0 ;     // Not Used in Conventional PCIe.


// 10.24 us timeout for errata C7 10 us
assign timer_10us_expired       = (phy_type == `PHY_TYPE_MPCIE) ? timer_10us_expired_mpcie : timer_10us_expired_int ;

assign timer_10us_expired_int   = (FREQ_VALUE==0) ?  (timer[11] & timer[9]) :
                                  (FREQ_VALUE==1) ?  (timer[10] & timer[8]) :
                                                     (timer[ 9] & timer[7]);

assign timer_10_24us_limit_mpcie = 12'h000 ;  // Not Used in Conventional PCIe.
assign timer_10us_expired_mpcie  = 1'b0 ;     // Not Used in Conventional PCIe.


always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if(!pwr_rst_n)
        timer_10us_expired_reg  <= #TP 1'b1;
    // clear the flag if a Nak is received in response to L1 ASPM request
    else if (radm_pm_asnak)
        timer_10us_expired_reg  <= #TP 1'b0;
    // If the link goes down or the Trasmitter enters L0S the flag is set.
    // If the timer expires or PM_Enter_L1/PM_Enter_L23 DLLP's are being transmitted.
    else if ((!phy_link_up) || (master_state == L0S_EXIT) || timer_10us_expired || pm_xdlh_enter_l1 || pm_xdlh_enter_l23)
        timer_10us_expired_reg  <= #TP 1'b1;
end

// L23READY negotiation is aborted
assign int_l23_entry_abort = (master_state == L23_WAIT_PMDLLP_ACK) && int_idle_next;

// Generation of flags for pm_active_ctrl
pm_active_flags

    #( 
    .L1_BLOCK_TLP           (L1_BLOCK_TLP),
    .L23_BLOCK_TLP          (L23_BLOCK_TLP),
    .L1_WAIT_LAST_TLP_ACK   (L1_WAIT_LAST_TLP_ACK),
    .PREP_4L1               (PREP_4L1),
    .L1_LINK_ENTR_L1        (L1_LINK_ENTR_L1),
    .WAIT_LAST_PMDLLP       (WAIT_LAST_PMDLLP),
    .L1                     (L1),
    .IDLE                   (IDLE),
    .L0                     (L0),
    .PREP_4L23              (PREP_4L23),
    .L1_WAIT_PMDLLP_ACK     (L1_WAIT_PMDLLP_ACK),
    .L23_WAIT_PMDLLP_ACK    (L23_WAIT_PMDLLP_ACK),
    .WAIT_DSTATE_UPDATE     (WAIT_DSTATE_UPDATE),
    .L23RDY                 (L23RDY)
    ) u_active_flags (
    // Inputs
    .aux_clk                (aux_clk),
    .pwr_rst_n              (pwr_rst_n),
    .master_state           (master_state),
    .smlh_link_in_training  (smlh_link_in_training),
    .latch_as_entr_l1       (latch_as_entr_l1),
    .radm_pm_asnak          (radm_pm_asnak),
    .smlh_link_up           (phy_link_up),
    .smlh_in_l0             (smlh_in_l0),
    .pm_l23_entry_abort     (int_l23_entry_abort),
    .xdlh_match_pmdllp      (xdlh_match_pmdllp),
    // Outputs
    .pm_l1_aspm_flag        (pm_l1_aspm_flag),
    .pm_l23_entry_flag      (pm_l23_entry_flag),
    .pm_xdlh_enter_l23      (pm_xdlh_enter_l23),
    .pm_xdlh_enter_l1       (pm_xdlh_enter_l1),
    .pm_xdlh_actst_req_l1   (pm_xdlh_actst_req_l1),
    .pm_timeout             (pm_timeout),
    .pm_l23_entry_restart   (pm_l23_entry_restart),
    .pm_l23_hs_done         (pm_l23_hs_done),
    .pm_l1_pcipm_hs_done    (pm_l1_pcipm_hs_done),
    .pm_l1_aspm_hs_done     (pm_l1_aspm_hs_done)
);

// Conditions for transmitting Pm_Active_State_Nak when Pm_Active_State_Request_L1 received
// If recovery from L0 is enabled or ASPM is not enabled or there is a TLP pending or there
// is an ACK/NAK DLLP scheduled
assign int_next_resp_nak = (int_link_up_not_rcvry & !upstream_port & rdlh_rcvd_as_req_l1 & (~l1_aspm_en | pm_wake_tlp_pending | !no_acknak_dllp_pending));

assign int_pm_xmt_asnak = (slave_state == S_IDLE) & int_next_resp_nak;

assign pm_active_next_l1 = (int_master_in_l1_s) || (slave_state == S_L1);



wire int_l2cpm_s;
assign int_l2cpm_s = (master_state == L2_CPM_ENTRY) || (master_state == L2_CPM_EXIT);

// Gate off core_clk in L1 only if there is no exit request on entry
wire int_l1_disable_core_clk;
// l1 exit will not turn on core clock if it is already in P1.CPM, P1.1 or P1.2
assign int_l1_disable_core_clk = ((pm_active_next_l1 && (pre_pm_phy_powerdown == P1 || pm_req_iso_vmain_to_vaux)) && !smlh_cal_req) && !(latch_int_l1_exit);

// pm link state FSM requests aux_clk switch in L1 and powerdown is P1 and when L1 sub-fast exit mode is not enabled, or in L2 when powerdown is P2
assign pm_linkst_sel_aux_clk = (int_l1_disable_core_clk && 
                                ((!pl_l1_clk_sel || pm_clk_pm_en) 
)
)
                                || (pm_active_next_l2 && (pre_pm_phy_powerdown == P2)
) 
 || int_l2cpm_s;

assign pm_linkst_en_core_clk = !((int_pm_state_l23 && (pre_pm_phy_powerdown == P2)) || int_l1_disable_core_clk);

assign pm_active_next_l1_entry = (master_state == L1_LINK_ENTR_L1) || (slave_state == S_LINK_ENTR_L1);   // when slave state machine acknowledged the xdlh to enter L1, it needs to signal LTSSM that it is ready to enter L1 which prevent LTSSM goes into L0s when eidle order set received.
assign pm_active_next_l1_exit = (master_state == L1_EXIT) || (slave_state == S_L1_EXIT);

wire int_master_in_l23_s;
assign int_master_in_l23_s = (master_state == L23RDY) || (master_state == L2_CPM_ENTRY) || (master_state == L2_CPM_EXIT) ;
assign int_pm_state_l23 = ((int_master_in_l23_s) || (slave_state == S_L23RDY) ||
  (master_state == L23RDY_WAIT4ALIVE) || (slave_state == S_L23RDY_WAIT4ALIVE));
assign pm_active_next_l2 = int_pm_state_l23 && aux_pm_det;

assign int_pm_state_l23rdy = int_master_in_l23_s || (slave_state == S_L23RDY);

assign int_l1_entry_started = pm_l1_in_progress || pm_l1_aspm_entr || int_start_l1_aspm;

assign int_smlh_l23_exit = (((int_master_in_l23_s) || (slave_state == S_L23RDY)) && (int_rxelecidle_deassert || wakeup_event))
                           || ((master_state == L23RDY_WAIT4ALIVE) || (slave_state == S_L23RDY_WAIT4ALIVE));

// output driven process
always @(posedge aux_clk or negedge pwr_rst_n)
if (!pwr_rst_n) begin
    pm_smlh_l0s_exit        <= #TP 0;
    pm_smlh_l1_exit         <= #TP 0;
    pm_smlh_l23_exit        <= #TP 0;
    pm_smlh_entry_to_l0s    <= #TP 0;
    pm_smlh_entry_to_l1     <= #TP 0;
    pm_smlh_entry_to_l2     <= #TP 0;
    pm_smlh_prepare4_l123   <= #TP 0;
    pm_xdlh_req_ack         <= #TP 0;
    pm_xtlh_block_tlp       <= #TP 0;
    pm_block_all_tlp        <= #TP 0;
    pm_radm_block_tlp       <= #TP 0;
    pm_l1_entry_started     <= #TP 1'b0;
    pm_freeze_fc_timer      <= #TP 0;
    pm_freeze_cpl_timer     <= #TP 0;
    local_ref_clk_req_n     <= #TP 1'b0;
    pm_linkst_in_l0         <= #TP 0;
    pm_linkst_in_l1         <= #TP 0;
    pm_linkst_in_l0s        <= #TP 0;
    pm_linkst_in_l2         <= #TP 0;
    pm_linkst_l2_exit       <= #TP 0;
    pm_linkst_in_l3         <= #TP 0;
    pm_linkst_in_l23rdy     <= #TP 0;
    pm_xmt_asnak            <= #TP 0;
    int_mac_phy_pclkreq_n_r <= #TP 2'b00;
    int_l1_aspm_radm_race_r <= #TP 1'b0;
end
else begin
    // Beneath are the signal commands the LTSSM state machine to go into the proper low power state
    pm_smlh_l0s_exit        <= #TP master_state == L0S_EXIT;

    pm_smlh_l1_exit         <= #TP pm_active_next_l1_exit;

    pm_smlh_l23_exit        <= #TP int_smlh_l23_exit;

    pm_smlh_entry_to_l0s    <= #TP (master_state == ENTER_L0S);

    pm_smlh_entry_to_l1     <= #TP pm_active_next_l1_entry; 
    pm_smlh_entry_to_l2     <= #TP (master_state == L23_ENTR_L23) | (slave_state == S_LINK_ENTR_L23);  // when slave state machine acknowledged the xdlh to enter L2, it needs to signal LTSSM that it is ready to enter L2 which prevent LTSSM goes into L0s when eidle order set received.


    // Beneath are the signals designed to notify the xdlh for transmiting PM DLLP
    pm_smlh_prepare4_l123   <= #TP (slave_state == S_ACK_WAIT4IDLE) | (master_state == PREP_4L1) | (master_state == PREP_4L23) | (master_state == L1_LINK_ENTR_L1) | (slave_state == S_WAIT_LAST_PMDLLP) | (master_state == WAIT_LAST_PMDLLP);   // when slave state machine acknowledged the xdlh to enter L1, it needs to signal LTSSM that it is ready to enter L1 which prevent LTSSM goes into L0s when eidle order set received.
    pm_xdlh_req_ack         <= #TP ((slave_state == S_ACK_WAIT4IDLE) & (!latched_rcvd_eidle_set & !smlh_l123_eidle_timeout));
    pm_xmt_asnak            <= #TP int_pm_xmt_asnak;
    // This signal is designed to notify the xtlh or xadm to block any tlp transmit
    // request other than pm message
    // Only in certain states which we need to block off the TLP
    pm_block_all_tlp        <=  #TP  !phy_link_up   // block all new TLP from arbiter because of link down
                                       | ((master_state == L0S_BLOCK_TLP)
                                       | (master_state == ENTER_L0S)
                                       | (master_state == L1_BLOCK_TLP) | (master_state == L23_BLOCK_TLP)
                                       | (master_state == L1_WAIT_LAST_TLP_ACK) | (master_state == L23_WAIT_LAST_TLP_ACK)
                                       | (master_state == L1_WAIT_PMDLLP_ACK) | (master_state == L23_WAIT_PMDLLP_ACK)
                                       | (master_state == L1_LINK_ENTR_L1) |  (master_state == L23_ENTR_L23)
                                       | (master_state == PREP_4L1) | (master_state == PREP_4L23) | (master_state == WAIT_LAST_PMDLLP)
                                       | (int_master_in_l1_s) | (master_state == L1_EXIT))
                                       | ((slave_state == S_BLOCK_TLP) | (slave_state == S_WAIT_LAST_TLP_ACK)
                                       | (slave_state == S_ACK_WAIT4IDLE) | (slave_state == S_LINK_ENTR_L1)
                                       | (slave_state == S_L1) | (slave_state == S_L1_EXIT) | (slave_state == S_WAIT_LAST_PMDLLP)
                                       | (slave_state == S_NAK_BLOCK_TLP) | (slave_state == S_WAIT_NAK_TLP_ACK));


    pm_xtlh_block_tlp       <=  #TP ((&(pm_dstate_d1 | pm_dstate_d2 | pm_dstate_d3)) & upstream_port);
    pm_l1_entry_started     <=  #TP int_l1_entry_started;

    // This signal instruct the receive filter to reject TLPs other than CFG/MSG
    // Reject during D1, D2 or D3hot state. (D3cold doesn't matter since no power anyways)
    pm_radm_block_tlp       <= #TP (pm_dstate_d1 | pm_dstate_d2 | pm_dstate_d3) & {NF{upstream_port}};

    // this signal is designed to notify the xdlh that the fc timer
    // should be blocked since we will not send fc dllp based on timer expiration
    // during L1 or L23 state
    pm_freeze_fc_timer      <= #TP (int_master_in_l1_s) | (master_state == L1_LINK_ENTR_L1)
                                    | (slave_state == S_L1) | (slave_state == S_LINK_ENTR_L1) | (slave_state == S_ACK_WAIT4IDLE)
                                    | (master_state == L23_ENTR_L23) | (int_master_in_l23_s)
                                    | (slave_state == S_LINK_ENTR_L23) | (slave_state == S_L23RDY)
                                    | !(smlh_in_l0 | smlh_in_l0s | smlh_in_rl0s);

    // New PCIe 1.1 errata C6 turns off Completion Timer suspension.
    pm_freeze_cpl_timer     <= #TP 0;
    pm_linkst_in_l0     <= #TP (master_state == L0) & (slave_state == S_IDLE);
    pm_linkst_in_l1     <= #TP pm_active_next_l1;
    pm_linkst_in_l2     <= #TP pm_active_next_l2;
    pm_linkst_l2_exit   <= #TP ((master_state == L23RDY_WAIT4ALIVE) || (slave_state == S_L23RDY_WAIT4ALIVE)) && aux_pm_det;
    pm_linkst_in_l3     <= #TP int_pm_state_l23;
    pm_linkst_in_l23rdy <= #TP int_pm_state_l23rdy;
    pm_linkst_in_l0s    <= #TP (master_state == L0S);

    // When asserted to 1'b1, then it is ok to turn off the reference clock.
    local_ref_clk_req_n <= #TP int_pm_clk_req_n && perst_n;
    int_mac_phy_pclkreq_n_r <= #TP {1'b0, ((master_state == L1_CPM_ENTRY) || (master_state == L2_CPM_ENTRY))};
    int_l1_aspm_radm_race_r <= #TP int_l1_aspm_radm_race;
end

// Controller requests removal of reference clock in L1/L2 with CPM
assign int_upd_clk_req_n = int_mac_phy_pclkreq_n_r[0] && int_phy_clk_req_n_r;
  
// when isolated do not update value of clk_req_n
assign int_hold_clk_req_n = pm_req_iso_vmain_to_vaux ? local_ref_clk_req_n : int_upd_clk_req_n;

assign int_lp_clk_sw_mode = 1'b0;

// If the reference clock is always on controller does not wait for PHY clkreq handshake.
assign int_phy_clk_req_n = int_lp_clk_sw_mode ? 1'b1 : int_phy_clk_req_n_r;

assign int_pm_clk_req_n = app_clk_req_n && (int_hold_clk_req_n ) && int_phy_clk_req_n;


assign wake       = pm_phy_beacongen;

assign pm_dstate    = pm_pmstate;

assign pm_dstate_d0 = pm_dstate_d0_uninit | pm_dstate_d0_act;

reg [2:0]   tmp_vec1;
always @(pm_dstate)
begin : PM_DSTATE_2
integer i,j;
    for (i=0; i<NF; i=i+1) begin
        for (j=0; j<3; j=j+1)
            tmp_vec1[j]  = pm_dstate[(3*i)+j];

        if (tmp_vec1 == PM_D0_UINI)
            pm_dstate_d0_uninit[i] = 1'b1;
        else
            pm_dstate_d0_uninit[i] = 1'b0;

        if (tmp_vec1 == PM_D0_ACT)
            pm_dstate_d0_act[i] = 1'b1;
        else
            pm_dstate_d0_act[i] = 1'b0;

        if (tmp_vec1 == PM_D1)
            pm_dstate_d1[i] = 1'b1;
        else
            pm_dstate_d1[i] = 1'b0;

        if (tmp_vec1 == PM_D2)
            pm_dstate_d2[i] = 1'b1;
        else
            pm_dstate_d2[i] = 1'b0;

        if (tmp_vec1 == PM_D3)
            pm_dstate_d3[i] = 1'b1;
        else
            pm_dstate_d3[i] = 1'b0;
    end
end // PM_DSTATE_2


// based in PIPE spec., we consolidate these two signals since the PHY
// knows to use the PM state and the deassertion of pm_phy_txelecidle to
// detect beacongeneration situation.
assign int_pm_linkst_l2 = ((int_master_in_l23_s) | (master_state == L23RDY_WAIT4ALIVE) | (slave_state == S_L23RDY) | (slave_state == S_L23RDY_WAIT4ALIVE));
                            
// Link state is in L2 and wakeup event is detected
assign int_pm_l2_wakeup = (wakeup_event & int_pm_linkst_l2);

// The wakeup from L2 is completed when perst_n rising edge is detected or
// in the case where perst_n has not been asserted when rxelecidle is
// deasserted
assign int_l2_wakeup_done = int_pm_l2_wakeup && (pm_set_phy_p1 || int_rxelecidle_deassert);

// Select between LTSSM txelecidle and pm version LTSSM version is not
// registered to avoid adding delay
assign int_drive_txelecidle = aux_clk_active;
assign int_sel_pm_txelecidle = ((int_pm_linkst_l2 || pm_linkst_in_l1) && aux_clk_active);

// TXELECIDLE it will be set to 1 if in P0S or P1 or if in P2 with no
// wakeup event. When wakeup event is detected in P2 it will be set to 0 to
// allow for beacon transmission. Otherwise it will take the value provided
// by the LTSSM
// The beacongen signal is used to drive the wake signal which should be
// used by power management circuitry to restore main power in L2
always @ *
begin
    if(!int_drive_txelecidle)
    begin
        int_phy_txelecidle = ltssm_txelecidle;
        int_phy_beacongen = 1'b0;
    end
    else if(int_l2_wakeup_done)
    begin
        int_phy_txelecidle = {NL*PHY_TXEI_WD{1'b1}};
        int_phy_beacongen = 1'b0;
    end
    else if(int_pm_l2_wakeup)
    begin
        if (!pm_perst_powerdown) begin
          int_phy_txelecidle = {NL*PHY_TXEI_WD{1'b0}};
        end else begin
          int_phy_txelecidle = {NL*PHY_TXEI_WD{1'b1}};
        end
        int_phy_beacongen = 1'b1;
    end
    else
    begin
        int_phy_txelecidle = int_phy_txelecidle_r;
        int_phy_beacongen = 1'b0;
    end
end

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if(!pwr_rst_n)
    begin
        int_sel_pm_txelecidle_r <= #TP 1'b0;
        int_phy_txelecidle_r <= #TP {NL*PHY_TXEI_WD{1'b1}};
        pm_phy_beacongen <= #TP 1'b0;
    end
    else
    begin
        int_sel_pm_txelecidle_r <= #TP int_sel_pm_txelecidle;
        int_phy_txelecidle_r <= #TP int_phy_txelecidle;
        pm_phy_beacongen <= #TP int_phy_beacongen;
    end
end


assign pm_phy_txelecidle = int_sel_pm_txelecidle_r ? int_phy_txelecidle_r : ltssm_txelecidle;


// replicate phy powerdown to avoid any potential issues with fanout to
// 2 power domains
assign pm_int_phy_powerdown = pm_phy_powerdown;

// Dont detect powerdown updates from the LTSSM in the following cases 
// Isolation is enabled
// Dont take P2 from the LTSSM since the clock must switch to aux_clk first
// In L1 substates dont allow powerdown to update until the PHY has asserted phy_mac_pclkack_n
assign int_block_pd_update = pm_det_l2 || smlh_in_l23 || pm_req_iso_vmain_to_vaux || (pre_pm_phy_powerdown == P2);

logic int_set_l1cpm_exit;
assign int_set_l1cpm_exit = (master_state == L1_CPM_EXIT) && !int_phy_clk_req_n_r;

assign int_detect_pd_update = !(pre_pm_phy_powerdown == pm_phy_powerdown) && !int_override_pd_r;

// LTSSM updates powerdown based on state transition for example L1 to RECOVERY txelecidle is not asserted
assign int_smlh_pd_update = (int_detect_pd_update 
                            && !int_block_pd_update 
                            );
// When transitioning from P0 the txelecidle must be asserted
assign int_txelecidle_and = &ltssm_txelecidle;
assign int_p0_pd_update = (pm_phy_powerdown == P0) && int_smlh_pd_update && int_txelecidle_and;

// Update powerdown signal block updates if powerdown is overriden to P2 or perst_n is asserted
// Also do not take updates to powerdown before the PHY has asserted phy_clk_req_n
assign int_update_powerdown = perst_n && (!int_pd_p1_override && (int_p0_pd_update || (!(pm_phy_powerdown == P0) && int_smlh_pd_update)));
assign pm_req_exit_p2 = (pm_set_phy_p1 || (pm_linkst_in_l2 && int_rxelecidle_deassert && !pm_det_l2 && current_powerdown_p2));

// drive powerdown from the pm_ctrl in these states this prevents a deadlock situation where
// powerdown is driven to P2 by the LTSSM long before the pm controller has entered L2 and switched
// to aux_clk
always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n)
        pm_phy_powerdown    <= #TP P1;
    // Set powerdown to P1 during pma phy reset triggered by fundamental reset
    else if (pm_perst_powerdown)
        pm_phy_powerdown    <= #TP P1;
    // Set powerdown to P1 only after txelecidle has been asserted
    else if (pm_req_exit_p2)
        pm_phy_powerdown    <= #TP P1;
    // When the FSM is in L23RDY or L23RDY_WAIT4ALIVE drive P2 to the PHY
    else if (pm_linkst_in_l3 && int_pm_state_l23)
        pm_phy_powerdown    <= #TP P2;
    // Entering L1.CPM set powerdown to P2 instead of P1 
    else if (int_p1_to_p2)
        pm_phy_powerdown    <= #TP P2;
    else if ((!link_req_rst_not && ( &ltssm_txelecidle)))
        pm_phy_powerdown    <= #TP P1;
    // Exiting L1.CPM transition P2 to P1
    else if (int_set_l1cpm_exit)
        pm_phy_powerdown    <= #TP P1;
    else if (int_update_powerdown)
        pm_phy_powerdown    <= #TP pre_pm_phy_powerdown;
    else
        pm_phy_powerdown    <= #TP pm_phy_powerdown;
end

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n)
       pm_curnt_state  <= #TP 3'b000;
    else
        if ((int_master_in_l1_s) | (slave_state == S_L1))
            pm_curnt_state  <= #TP  3'b010;
        else if (((int_master_in_l23_s) | (slave_state == S_L23RDY)) & aux_pm_det)
            pm_curnt_state  <= #TP  3'b011;
        else if ((int_master_in_l23_s) | (slave_state == S_L23RDY))
            pm_curnt_state  <= #TP  3'b100;
        else if (master_state == L0S)
            pm_curnt_state  <= #TP  3'b001;
        else if ((master_state == L0) | (master_state == IDLE))
            pm_curnt_state  <= #TP  3'b000;
end



DWC_pcie_ctl_bcm41

#(
    .WIDTH (1),
    .RST_VAL (0),
    .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_phy_clk_req_n_sync (
    .clk_d      (aux_clk),
    .rst_d_n    (pwr_rst_n),
    .data_s     (phy_clk_req_n),
    .data_d     (sync_phy_clk_req_n)
);

always @(posedge aux_clk or negedge pwr_rst_n) begin : phy_clk_req_PROC
  if(!pwr_rst_n) begin
    int_phy_clk_req_n_r <= #TP 1'b0;
  end else begin
    int_phy_clk_req_n_r <= #TP sync_phy_clk_req_n;
  end
end : phy_clk_req_PROC

// Legacy interface for L1 or L2 CPM
wire                    int_mac_phy_p1;
wire                    int_override_p1_to_p2;
wire                    int_set_override;
wire                    int_clear_override;
wire                    int_linkst_set_override;
logic                   int_override_pd_s;

// If clock power management is enabled the powerdown state can be overriden to P2 
// during L1 state when the reference clock is not needed.
// Note the powerdown override to P2 does not apply when L1 Substates is supported.
assign int_mac_phy_p1 = (pre_pm_phy_powerdown == P1);
assign int_linkst_set_override = ((master_state == L1_LINK_ENTR_L1) || (master_state == L1)) && int_mac_phy_p1;
assign int_override_p1_to_p2 = upstream_port && pm_clk_pm_en && !pl_l1_clk_sel;

// Override P1 to P2 when no local clock request is asserted and the
// controller is driving P1 to the PHY in L1 state
assign int_set_override = int_override_p1_to_p2 && int_linkst_set_override;
assign int_clear_override = (master_state == L1_EXIT) || (master_state == IDLE);

always_comb begin : pd_override_PROC
  if(int_clear_override)
    int_override_pd_s = 1'b0;
  else if(int_set_override)
    int_override_pd_s = 1'b1;
  else
    int_override_pd_s = int_override_pd_r;
end : pd_override_PROC

always @(posedge aux_clk or negedge pwr_rst_n)
begin : pd_override_r_PROC
    if(!pwr_rst_n)
        int_override_pd_r   <= #TP 1'b0;
    else
        int_override_pd_r   <= #TP int_override_pd_s;
end : pd_override_r_PROC

assign int_pd_p1_override = int_override_pd_s;
assign int_p1_to_p2 = int_override_pd_r && pm_linkst_in_l1;
assign int_block_l1_exit = int_phy_clk_req_n_r && (phy_type == `PHY_TYPE_CPCIE);
// If L1 with Clock PM wait until PHY has asserted phy_clk_req_n before exiting L1.
assign int_hold_in_l1 = int_block_l1_exit;

// if the squelch module is defined, then it will synchronize phy_mac_rxelecidle.
assign  sync_phy_rxelecidle = phy_mac_rxelecidle;

assign pm_l1_cpm_exit = latch_int_l1_exit || !phy_link_up;
assign next_pm_state_is_l1 = pm_linkst_in_l1 && !latch_int_l1_exit;

// Only detect electrical idle de-assertion on active lanes for exiting low power
always @(posedge aux_clk or negedge pwr_rst_n) begin : rxelecidle_active_PROC
  if(!pwr_rst_n)
    int_active_lane_rxelecidle_r <= #TP {NL{1'b0}};
  else
    int_active_lane_rxelecidle_r <= #TP int_active_lane_rxelecidle;
end : rxelecidle_active_PROC

assign int_active_lane_rxelecidle = sync_phy_rxelecidle | mac_phy_txcompliance; 

assign int_rxelecidle_deassert = !(&int_active_lane_rxelecidle_r);


assign mac_phy_pclkreq_n = int_mac_phy_pclkreq_n_r;

pm_active_ctrl_aux_timer
 u_pm_active_ctrl_aux_timer (
// ---- inputs ---------------
    .aux_clk                     (aux_clk),
    .pwr_rst_n                   (pwr_rst_n),
    .aux_clk_freq                (pm_pl_aux_clk_freq),

// ---- outputs ---------------
    .aux_clk_en_1us              (aux_clk_en_1us)
);


assign pm_master_state = master_state;
assign pm_slave_state = slave_state;

// L1 entry negotiation is in progress at a point where the LTSSM has exited L0
assign pm_l1_in_progress = (((master_state == WAIT_LAST_PMDLLP) ||
                             (master_state == PREP_4L1) ||
                             (master_state == L1_LINK_ENTR_L1) ||
                             (int_master_in_l1_s)) ||
                            ((slave_state == S_ACK_WAIT4IDLE) ||
                             (slave_state == S_WAIT_LAST_PMDLLP) ||
                             (slave_state == S_LINK_ENTR_L1) ||
                             (slave_state == S_L1)));

function automatic integer log2roundup(input integer value);
    begin
        log2roundup = 1;
        while(1<<log2roundup <= value)
            log2roundup = log2roundup + 1;

    end
endfunction

`ifndef SYNTHESIS
wire  [21*8:0]  MST_STATE;

assign  MST_STATE = (master_state == IDLE                 ) ? "IDLE":
                    (master_state == L0                   ) ? "L0":
                    (master_state == L0S                  ) ? "L0S":
                    (master_state == ENTER_L0S            ) ? "ENTER_L0S":
                    (master_state == L0S_EXIT             ) ? "L0S_EXIT":
                    (master_state == L1                   ) ? "L1":
                    (master_state == L1_BLOCK_TLP         ) ? "L1_BLOCK_TLP":
                    (master_state == L1_WAIT_LAST_TLP_ACK ) ? "L1_WAIT_LAST_TLP_ACK":
                    (master_state == L1_WAIT_PMDLLP_ACK   ) ? "L1_WAIT_PMDLLP_ACK":
                    (master_state == L1_LINK_ENTR_L1      ) ? "L1_LINK_ENTR_L1":
                    (master_state == L1_EXIT              ) ? "L1_EXIT":
                    (master_state == PREP_4L1             ) ? "PREP_4L1":
                    (master_state == L23_BLOCK_TLP        ) ? "L23_BLOCK_TLP":
                    (master_state == L23_WAIT_LAST_TLP_ACK) ? "L23_WAIT_LAST_TLP_ACK":
                    (master_state == L23_WAIT_PMDLLP_ACK  ) ? "L23_WAIT_PMDLLP_ACK":
                    (master_state == L23_ENTR_L23         ) ? "L23_ENTR_L23":
                    (master_state == L23RDY               ) ? "L23RDY":
                    (master_state == PREP_4L23            ) ? "PREP_4L23":
                    (master_state == L23RDY_WAIT4ALIVE    ) ? "L23RDY_WAIT4ALIVE":
                    (master_state == L0S_BLOCK_TLP        ) ? "L0S_BLOCK_TLP":
                    (master_state == WAIT_LAST_PMDLLP     ) ? "WAIT_LAST_PMDLLP":
                    (master_state == WAIT_DSTATE_UPDATE   ) ? "WAIT_DSTATE_UPDATE" :
                    (master_state == WAIT_PMCSR_CPL_SENT  ) ? "WAIT_PMCSR_CPL_SENT":
                    (master_state == L1_CPM_ENTRY         ) ? "L1_CPM_ENTRY":
                    (master_state == L1_CPM_EXIT          ) ? "L1_CPM_EXIT":
                    (master_state == L2_CPM_ENTRY         ) ? "L2_CPM_ENTRY":
                    (master_state == L2_CPM_EXIT          ) ? "L2_CPM_EXIT":
                                                              "UNKNOWN";



wire  [19*8:0]  SLV_STATE;

assign  SLV_STATE = (slave_state == S_IDLE                ) ? "S_IDLE":
                    (slave_state == S_RESPOND_NAK         ) ? "S_RESPOND_NAK":
                    (slave_state == S_BLOCK_TLP           ) ? "S_BLOCK_TLP":
                    (slave_state == S_WAIT_LAST_TLP_ACK   ) ? "S_WAIT_LAST_TLP_ACK":
                    (slave_state == S_LINK_ENTR_L1        ) ? "S_LINK_ENTR_L1":
                    (slave_state == S_L1                  ) ? "S_L1":
                    (slave_state == S_L1_EXIT             ) ? "S_L1_EXIT":
                    (slave_state == S_L23RDY              ) ? "S_L23RDY":
                    (slave_state == S_LINK_ENTR_L23       ) ? "S_LINK_ENTR_L23":
                    (slave_state == S_L23RDY_WAIT4ALIVE   ) ? "S_L23RDY_WAIT4ALIVE":
                    (slave_state == S_ACK_WAIT4IDLE       ) ? "S_ACK_WAIT4IDLE":
                    (slave_state == S_WAIT_LAST_PMDLLP    ) ? "S_WAIT_LAST_PMDLLP":
                    (slave_state == S_NAK_BLOCK_TLP       ) ? "S_NAK_BLOCK_TLP":
                    (slave_state == S_WAIT_NAK_TLP_ACK    ) ? "S_WAIT_NAK_TLP_ACK":
                    (slave_state == S_WAIT_NAK_TIMER      ) ? "S_WAIT_NAK_TIMER":

                                                              "UNKNOWN";
`endif // SYNTHESIS

endmodule // pm_active_ctrl
