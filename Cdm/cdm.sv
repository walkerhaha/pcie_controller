
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
// ---    $DateTime: 2020/10/23 10:21:15 $
// ---    $Revision: #41 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm.sv#41 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the following functions (for both type 0 and type 1 device)
// ---   - PCI-Compatible configuration registers
// ---   - PM capability registers
// ---   - PCIE capability registers
// ---   - MSI capability registers
// ---   - Advanced Error capability registers
// ---   - Virtual Channel capability registers
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Cdm/cdm_pkg.svh"

 
 module cdm (
// ---- inputs ----------------
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    device_type,
    phy_type,
    app_dbi_ro_wr_disable,
    lbc_cdm_addr,
    lbc_cdm_data,
    lbc_cdm_cs,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    lbc_cdm_dbi2,

    lbc_xmt_cpl_ca,

    sys_int,
    sys_aux_pwr_det,
    sys_pre_det_state,
    sys_mrl_sensor_state,
    sys_atten_button_pressed,
    sys_pwr_fault_det,
    sys_mrl_sensor_chged,
    sys_pre_det_chged,
    sys_cmd_cpled_int,
    sys_eml_interlock_engaged,
    phy_cfg_status,
    cxpl_debug_info,
    smlh_autoneg_link_width,
    smlh_autoneg_link_sp,
    smlh_link_training_in_prog,
    smlh_bw_mgt_status,
    smlh_link_auto_bw_status,
    smlh_dir_linkw_chg_rising_edge,
    current_data_rate,
    tmp_int_mac_phy_rate,
    rmlh_rcvd_err,

    xtlh_xmt_cpl_ca,
    xtlh_xmt_cpl_ur,
    xtlh_xmt_wreq_poisoned,
    xtlh_xmt_cpl_poisoned,
    radm_rcvd_wreq_poisoned,
    radm_rcvd_cpl_poisoned,
    radm_mlf_tlp_err,
    radm_rcvd_req_ur,
    radm_rcvd_req_ca,
    radm_ecrc_err,
    cdm_err_advisory,
    radm_hdr_log_valid,
    radm_hdr_log,




    rtlh_overfl_err,
    rtlh_fc_init_status,

    xal_rcvd_cpl_ca,
    xal_rcvd_cpl_ur,
    xal_xmt_cpl_ca,
    xal_perr,
    xal_serr,
    xal_set_trgt_abort_primary,
    xal_set_mstr_abort_primary,
    xal_pci_addr_perr,

    rdlh_prot_err,
    rdlh_bad_tlp_err,
    rdlh_bad_dllp_err,
    rdlh_link_up,
    xdlh_replay_num_rlover_err,
    xdlh_replay_timeout_err,
    smlh_link_up,

    radm_cpl_pending,
    radm_rcvd_cpl_ca,
    radm_rcvd_cpl_ur,
    radm_cpl_timeout,
    radm_timeout_func_num,

    radm_unexp_cpl_err,
    radm_set_slot_pwr_limit,
    radm_slot_pwr_payload,

    radm_pm_pme,
    radm_msg_req_id,

    radm_correctable_err,
    radm_nonfatal_err,
    radm_fatal_err,

    xtlh_xadm_ph_cdts,
    xtlh_xadm_pd_cdts,
    xtlh_xadm_nph_cdts,
    xtlh_xadm_npd_cdts,
    xtlh_xadm_cplh_cdts,
    xtlh_xadm_cpld_cdts,
    radm_qoverflow,
    radm_q_not_empty,
    xdlh_retrybuf_not_empty,
    rtlh_crd_not_rtn,


    pm_status,
    pm_pme_en,
    aux_pm_en,
    flt_cdm_addr,
    pm_radm_block_tlp,
    flt_cdm_rtlh_radm_pending,
// allow application to return the error bits and hdr log
    smlh_mod_ts_rcvd,
    mod_ts_data_rcvd,
    mod_ts_data_sent,
    xdlh_retry_req,
    rdlh_dlcntrl_state,


    smlh_in_l0,
    smlh_in_l1,

    pm_sel_aux_clk,


    radm_snoop_upd,
    radm_snoop_bus_num,
    radm_snoop_dev_num,

    app_clk_pm_en,

    app_dev_num,              // DEV# provided by the application
    app_bus_num,              // Bus# provided by the application



// ---- outputs ---------------

    cfg_upd_pme_cap,
    cfg_io_match,
    cfg_config_above_match,
    cfg_rom_match,
    cfg_bar_match,
    cfg_bar_is_io,
    cfg_mem_match,
    cfg_prefmem_match,
    cfg_pl_l1_nowait_p1,
    cfg_pl_l1_clk_sel,
    cfg_phy_perst_on_warm_reset,
    cfg_phy_rst_timer,
    cfg_pma_phy_rst_delay_timer,
    cfg_pl_aux_clk_freq,
    cfg_filter_rule_mask,
    cfg_fc_wdog_disable,
    cdm_lbc_data,
    cdm_lbc_ack,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    cfg_2ndbus_num,
    cfg_subbus_num,
    cfg_aslk_pmctrl,
    cfg_clk_pm_en,
    cfg_relax_ord_en,
    cfg_ext_tag_en,
    cfg_phantom_fun_en,
    cfg_aux_pm_en,
    cfg_no_snoop_en,
    cfg_max_rd_req_size,
    cfg_bridge_crs_en,
    cfg_rcb,
    cfg_comm_clk_config,
    cfg_hw_autowidth_dis,
    cfg_max_payload_size,
    cfg_highest_max_payload,
    cfg_ack_freq,
    cfg_ack_latency_timer,
    cfg_replay_timer_value,
    cfg_fc_latency_value,
    cfg_other_msg_payload,
    cfg_other_msg_request,
    cfg_corrupt_crc_pattern,
    cfg_scramble_dis,
    cfg_n_fts,
    cfg_link_dis,
    cfg_link_retrain,
    cfg_lpbk_en,
    cfg_elastic_buffer_mode,
    cfg_pipe_loopback,
    cfg_rxstatus_lane,
    cfg_rxstatus_value,
    cfg_lpbk_rxvalid,
    cfg_plreg_reset,
    cfg_link_num,
    cfg_ts2_lid_deskew,
    cfg_support_part_lanes_rxei_exit,
    cfg_forced_link_state,
    cfg_forced_ltssm_cmd,
    cfg_force_en,
    cfg_lane_skew,
    cfg_deskew_disable,
    cfg_imp_num_lanes,
    cfg_flow_control_disable,
    cfg_acknack_disable,
    cfg_link_capable,
    cfg_eidle_timer,
    cfg_skip_interval,
    cfg_link_rate,
    cfg_retimers_pre_detected,
    cfg_l0s_supported,
    cfg_fast_link_mode,
    cfg_fast_link_scaling_factor,
    cfg_dll_lnk_en,
    cfg_soft_rst_n,
    cfg_2nd_reset,
    cfg_ecrc_gen_en,
    cfg_ecrc_chk_en,
    cfg_bar0_start,
    cfg_bar0_limit,
    cfg_bar0_mask,
    cfg_bar1_start,
    cfg_bar1_limit,
    cfg_bar1_mask,
    cfg_bar2_start,
    cfg_bar2_limit,
    cfg_bar2_mask,
    cfg_bar3_start,
    cfg_bar3_limit,
    cfg_bar3_mask,
    cfg_bar4_start,
    cfg_bar4_limit,
    cfg_bar4_mask,
    cfg_bar5_start,
    cfg_bar5_limit,
    cfg_bar5_mask,
    cfg_rom_mask,
    cfg_mem_base,
    cfg_mem_limit,
    cfg_pref_mem_base,
    cfg_pref_mem_limit,
    cfg_exp_rom_start,
    cfg_exp_rom_limit,
    cfg_io_limit_upper16,
    cfg_io_base_upper16,
    cfg_io_base,
    cfg_io_limit,
    cfg_hdr_type,
    cfg_ext_synch,
    cfg_io_space_en,
    cfg_mem_space_en,
    cfg_phy_control,
    upstream_port,
    switch_device,
    end_device,
    rc_device,
    bridge_device,
    cfg_upd_pmcsr,
    cfg_upd_req_id,
    cfg_upd_aux_pm_en,
    cfg_pmstatus_clr,
    cfg_pmstate,
    cfg_pme_en,
    cfg_bus_master_en,
    cfg_reg_serren,
    cfg_cor_err_rpt_en,
    cfg_nf_err_rpt_en,
    cfg_f_err_rpt_en,
    cfg_pme_cap,
    cfg_pm_no_soft_rst ,
    cfg_l0s_entr_latency_timer,
    cfg_l1_entr_latency_timer,
    cfg_l1_entr_wo_rl0s,
    cfg_isa_enable,
    cfg_vga_enable,
    cfg_vga16_decode,
    cfg_send_cor_err,
    cfg_send_nf_err,
    cfg_send_f_err,
    cfg_func_spec_err,
    cfg_sys_err_rc,
    cfg_aer_rc_err_int,
    cfg_aer_rc_err_msi,
    cfg_aer_int_msg_num,
    cfg_pme_int,
    cfg_crs_sw_vis_en,
    cfg_pme_msi,
    cfg_pcie_cap_int_msg_num,
    cfg_cpl_timeout_disable,
    cfg_lane_en,
    cfg_gen1_ei_inference_mode,
    cfg_select_deemph_mux_bus,
    cfg_lut_ctrl,
    cfg_rxstandby_control,
    cfg_link_auto_bw_int,
    cfg_link_auto_bw_msi,
    cfg_bw_mgt_int,
    cfg_bw_mgt_msi,
    cfg_pwr_ind,
    cfg_atten_ind,
    cfg_pwr_ctrler_ctrl,
    cfg_eml_control,
    cfg_slot_pwr_limit_wr,
    cfg_int_disable,
    cfg_multi_msi_en,
    cfg_msi_ext_data_en,
    cfg_msi_en,
    cfg_msi_addr,
    cfg_msi_data,
    cfg_msi_64,
    cfg_msix_en,
    cfg_msix_func_mask,
    set_slot_pwr_limit_val,
    set_slot_pwr_limit_scale,
    cfg_vc_enable,
    cfg_vc_struc_vc_id_map,
    cfg_vc_id_vc_struc_map,
    cfg_tc_enable,
    cfg_tc_vc_map,
    cfg_tc_struc_vc_map,
    cfg_lpvc,
    cfg_vc_arb_sel,
    cfg_lpvc_wrr_weight,
    cfg_max_func_num,
    cfg_upd_aspm_ctrl,
    cfg_upd_aslk_pmctrl,
    cfg_trgt_cpl_lut_delete_entry,
    cfg_clock_gating_ctrl,
    cfg_fc_credit_ph,
    cfg_fc_credit_nph,
    cfg_fc_credit_cplh,
    cfg_fc_credit_pd,
    cfg_fc_credit_npd,
    cfg_fc_credit_cpld,
    cfg_radm_q_mode,
    cfg_radm_order_rule,
    cfg_order_rule_ctrl,
    cfg_radm_strict_vc_prior,
    cfg_hq_depths,
    cfg_dq_depths,
    target_mem_map,
    target_rom_map,
    inta_wire,
    intb_wire,
    intc_wire,
    intd_wire,
    cfg_pl_multilane_control
    ,cfg_alt_protocol_enable

    ,
    cfg_int_pin                             // Interrupt Pin mapping


    ,default_target,
    cfg_cfg_tlp_bypass_en,
    cfg_config_limit,
    cfg_target_above_config_limit,
    cfg_p2p_track_cpl_to,
    cfg_p2p_err_rpt_ctrl,
    ur_ca_mask_4_trgt1
    ,
    cfg_pipe_garbage_data_mode 









    ,
    cdm_hp_pme,
    cdm_hp_int,
    cdm_hp_msi

    ,   
    cfg_auto_slot_pwr_lmt_dis,
    cfg_hp_slot_ctrl_access, 
    cfg_dll_state_chged_en, 
    cfg_cmd_cpled_int_en, 
    cfg_pre_det_chged_en, 
    cfg_hp_int_en,
    cfg_mrl_sensor_chged_en, 
    cfg_pwr_fault_det_en, 
    cfg_atten_button_pressed_en

    ,
    cfg_br_ctrl_serren
    ,
    cfg_nond0_vdm_block,
    cfg_client0_block_new_tlp,
    cfg_client1_block_new_tlp,
    cfg_client2_block_new_tlp
    ,exp_rom_validation_status_strobe
    ,exp_rom_validation_status
    ,exp_rom_validation_details_strobe
    ,exp_rom_validation_details

    ,
    pm_powerdown_status,
    cfg_force_powerdown,
    cfg_pcie_slot_clk_config,
    cfg_uncor_internal_err_sts,
    cfg_rcvr_overflow_err_sts,
    cfg_fc_protocol_err_sts,
    cfg_mlf_tlp_err_sts,
    cfg_surprise_down_er_sts,
    cfg_dl_protocol_err_sts,
    cfg_ecrc_err_sts,
    cfg_corrected_internal_err_sts,
    cfg_replay_number_rollover_err_sts,
    cfg_replay_timer_timeout_err_sts,
    cfg_bad_dllp_err_sts,
    cfg_bad_tlp_err_sts,
    cfg_rcvr_err_sts   

);

import cdm_pkg::*;

parameter PWDN_WIDTH    = `CX_PHY_PDOWN_WD;
parameter INST          = 0;                        // The uniquifying parameter for each port logic instance.
parameter TP            = `TP;
parameter PM_MST_WD     = 5;
parameter PM_SLV_WD     = 5;
parameter NF            = `CX_NFUNC;                // Number of functions
parameter PF_WD         = `CX_NFUNC_WD;             // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise
parameter NL            = `CX_NL;                   // Number of Lanes Supported
parameter TXNL          = `CM_TXNL;                 // Tx Lane Width for M-PCIe
parameter RXNL          = `CM_RXNL;                 // Rx Lane Width for M-PCie
parameter NVC           = `CX_NVC;                  // Number of virtual channels
parameter BUSNUM_WD     = `CX_BUSNUM_WD;            // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD     = `CX_DEVNUM_WD;            // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter N_FLT_MASK    = `CX_N_FLT_MASK;
parameter NHQ           = `CX_NHQ;                  // Number of Header Queues per VC, corresponds to the Number of TLPs that can be processed in a single cycle
parameter NPRFX      = `CX_NPRFX;
parameter NVF        = `CX_NVFUNC;               // Number of virtual functions
localparam TLP_WIDTH = 128;
localparam HDR_PRFX_WD                = (NPRFX > 0) ? (TLP_WIDTH*2) : TLP_WIDTH;
localparam TX_PSET_WD     = 4;                        // Width of Transmitter Equalization Presets
localparam RX_PSET_WD     = 3;                        // Width of Receiver Equalization Presets
localparam ERR_BUS_WD = `CX_ERR_BUS_WD;
localparam ATTR_WD = `FLT_Q_ATTR_WIDTH;
localparam NW       = `CX_NW;                            // Number of 32-bit dwords handled by the datapath each clock.
localparam FX_TLP   = `CX_FX_TLP;                        // Number of TLPs that can be processed in a single cycle after the formation block
localparam RX_TLP   = `CX_RX_TLP;                        // Number of TLPs received in a single cycle
localparam RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1;          // Max number of DLLPs received per cycle
localparam TX_NDLLP    =  1;


localparam PTM_REQ_VALUE  = `CX_PTM_REQUESTER_VALUE;
localparam CIO_EN         = `CX_PCIE_MODE == `PCIE_OVER_CIO;
localparam NPTMREQVSEC    =  CIO_EN ? 29 : 26;// Number of PTM Requester VSEC Registers
localparam NPTMRESVSEC    =  CIO_EN ? 31 : 19;// Number of PTM Responder VSEC Registers
localparam NPTMVSEC       = (NPTMREQVSEC>=NPTMRESVSEC) ? NPTMREQVSEC : NPTMRESVSEC;
localparam NPTM           = 3;
localparam MULTI_DEVICE_AND_BUS_PER_FUNC = `MULTI_DEVICE_AND_BUS_PER_FUNC_EN_VALUE;
localparam UPD_WD         = MULTI_DEVICE_AND_BUS_PER_FUNC ? (FX_TLP==2 ? NF*FX_TLP : NF) : 1;
localparam SNOOP_BUS_WD   = MULTI_DEVICE_AND_BUS_PER_FUNC ? (FX_TLP==2 ? 8*FX_TLP : 8) : 8;
localparam SNOOP_DEV_WD   = MULTI_DEVICE_AND_BUS_PER_FUNC ? (FX_TLP==2 ? 5*FX_TLP : 5) : 5;

localparam TAG_SIZE       = `CX_TAG_SIZE;

localparam HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
localparam DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;


// ----- Inputs ---------------
input                   core_clk;                   // Core clock
input                   non_sticky_rst_n;           // Reset non-sticky registers only
input                   sticky_rst_n;               // Reset sticky registers only
input   [3:0]           device_type;                // Device type
input                   phy_type;                   // Mac type
// Local Bus interface
input                   app_dbi_ro_wr_disable;      // Set dbi_ro_wr_en to 0, disable write to DBI_RO_WR_EN bit
input   [31:0]          lbc_cdm_addr;               // Address of resource being accessed
input   [31:0]          lbc_cdm_data;               // Data for write
input   [NF-1:0]        lbc_cdm_cs;                 // Chip select (indicates an active bus cycle)
input   [3:0]           lbc_cdm_wr;                 // Write byte enables (active high)
input                   lbc_cdm_dbi;                // Indicates that the CDM is acccessed from dbi
input                   lbc_cdm_dbi2;               // Indicates that the CDM is acccessed from dbi2

input   [NF-1:0]        lbc_xmt_cpl_ca;             // Incidates that the LBC sent CPL w/ CA
// INTx - legacy interrupts
input   [NF-1:0]        sys_int;                    // interrupt signal per function from system side
// Power management
input                   sys_aux_pwr_det;            // Aux power is detected
// Slot
input   [NF-1:0]        sys_pre_det_state;          // Indicates the presence of a card in the slot
input   [NF-1:0]        sys_mrl_sensor_state;       // Reports the status of the MRL sensor if it is implemented
input   [NF-1:0]        sys_atten_button_pressed;   // Attention button is pressed or receive a message from end device
input   [NF-1:0]        sys_pwr_fault_det;          // Indicates a fault in the power controller
input   [NF-1:0]        sys_mrl_sensor_chged;       // Indicates the value of the MRL Sensor state had changed
input   [NF-1:0]        sys_pre_det_chged;          // Indicates Presence Detect had changed
input   [NF-1:0]        sys_cmd_cpled_int;          // this bit when set enables the generation of hot plug interrupt when a command is completed by hot plug control logic
input   [NF-1:0]        sys_eml_interlock_engaged;  // Electromechanical Interlock engaged
// Port Logic register specific
input   [31:0]          phy_cfg_status;             // PHY status register
input   [63:0]          cxpl_debug_info;            // debug bus
// Link
input   [5:0]           smlh_autoneg_link_width;    // negotiated link width
input   [3:0]           smlh_autoneg_link_sp;       // negotiated link speed
input                   smlh_link_training_in_prog; // link training in progress
input                   smlh_bw_mgt_status;         // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                    // without the port transitioning through DL_Down status
input                   smlh_link_auto_bw_status;   // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
                                                    // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
input                   smlh_dir_linkw_chg_rising_edge; // clear cfg_directed_link_width_change
input   [2:0]           current_data_rate;          // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4, 4-gen5
input   [2:0]           tmp_int_mac_phy_rate;       // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4, 4-gen5
input                   rmlh_rcvd_err;              // PHY Receiver error

input   [(FX_TLP*NF)-1:0]   radm_rcvd_wreq_poisoned; // Received a poisoned write request
input   [(FX_TLP*NF)-1:0]   radm_rcvd_cpl_poisoned;  // Received a completion marked poisoned
input   [(FX_TLP*NF)-1:0]   radm_rcvd_req_ur;        // Received request that was unsupported
input   [(FX_TLP*NF)-1:0]   radm_rcvd_req_ca;        // Received request that would cause Completer Abort
input   [(FX_TLP*NF)-1:0]   radm_mlf_tlp_err;        // Received malformed TLP
input   [(FX_TLP*NF)-1:0]   radm_ecrc_err;           // Received ECRC errors
input   [FX_TLP-1:0]        cdm_err_advisory;        // Error notified is an advisory error
input   [(FX_TLP*NF)-1:0]   radm_hdr_log_valid;      // TLP Header is ready for error logged
input   [(FX_TLP*128)-1:0]  radm_hdr_log;            // 128-bit TLP Header error register

input   [(FX_TLP*NF)-1:0]  radm_pm_pme;             // Received a PME
input   [(FX_TLP*16)-1:0]  radm_msg_req_id;         // Requester ID of the above PME
input   [NF-1:0]        radm_set_slot_pwr_limit;    // 1 cycle enable pulse
input   [31:0]          radm_slot_pwr_payload;      // specifies the scale/value used for the slot power limit when radm_set_slot_pwr_limit is asserted
input   [NF-1:0]        radm_cpl_pending;           // Completion is pending
input   [(FX_TLP*NF)-1:0]   radm_rcvd_cpl_ur;           // Received completion with UR status
input   [(FX_TLP*NF)-1:0]   radm_rcvd_cpl_ca;           // Received completion with CA status
input                       radm_cpl_timeout;           // Completion timeout
input   [PF_WD-1:0]         radm_timeout_func_num;       // Function # associated with the above timeout
input   [(FX_TLP*NF)-1:0]   radm_unexp_cpl_err;         // Received unexpected Completion
input                   rdlh_prot_err;              // data layer protocol error
input                   rdlh_bad_tlp_err;           // data layer receive bad TLP error
input                   rdlh_bad_dllp_err;          // data layer receive bad DLLP error
input                   rdlh_link_up;               // data layer link up
input                   xdlh_replay_num_rlover_err; // data layer transmit replay timeout number rollover
input                   xdlh_replay_timeout_err;    // data layer transmit replay timer timeout
input                   smlh_link_up;               // Link is active

input   [(FX_TLP*NF)-1:0]  radm_correctable_err;       // Received Correctable Error MSG
input   [(FX_TLP*NF)-1:0]  radm_nonfatal_err;          // Received Non-Fatal Uncorrectable Error MSG
input   [(FX_TLP*NF)-1:0]  radm_fatal_err;             // Received Fatal Uncorrectable Error MSG
input   [NF-1:0]        rtlh_overfl_err;            // Receiver overflow error
input   [NVC-1:0]       rtlh_fc_init_status;        // FC init status
//
// the following signal wiring depends on the location of the PCI-E port logic
//
input   [NF-1:0]        xtlh_xmt_cpl_ca;            // Core completes a request using Completer Abort completion Status
input   [NF-1:0]        xtlh_xmt_cpl_ur;            // Core side completes a request using Completer unsupported request
input   [NF-1:0]        xtlh_xmt_wreq_poisoned;     // Core poisons a write request
input   [NF-1:0]        xtlh_xmt_cpl_poisoned;      // Core Poisons a CPL request

input   [NF-1:0]        xal_rcvd_cpl_ca;            // internal logic side received completion with ca
input   [NF-1:0]        xal_rcvd_cpl_ur;            // internal logic side received completion with ur
input   [NF-1:0]        xal_xmt_cpl_ca;             // internal logic side transmit completion with ca
input   [NF-1:0]        xal_perr;                   // detect PERR# (PCIe -> PCI/PCI-X bridge)
input   [NF-1:0]        xal_serr;                   // detect SERR# (PCIe -> PCI/PCI-X bridge)
input   [NF-1:0]        xal_set_trgt_abort_primary;     // Set trgt abort of primary(PCIe -> PCI/PCI-X bridge)
input   [NF-1:0]        xal_set_mstr_abort_primary;     // Set mstr abort of primary(PCIe -> PCI/PCI-X bridge)
input   [NF-1:0]        xal_pci_addr_perr;              // Set secondary parity err detected(PCIe -> PCI/PCI-X bridge address/attribute error)


// Flow control credits
input   [HCRD_WD-1:0]   xtlh_xadm_ph_cdts;          // header for P credits
input   [DCRD_WD-1:0]   xtlh_xadm_pd_cdts;          // data for P credits
input   [HCRD_WD-1:0]   xtlh_xadm_nph_cdts;         // header for NP credits
input   [DCRD_WD-1:0]   xtlh_xadm_npd_cdts;         // data for NP credits
input   [HCRD_WD-1:0]   xtlh_xadm_cplh_cdts;        // header for CPL credits
input   [DCRD_WD-1:0]   xtlh_xadm_cpld_cdts;        // data for CPL credits
input                   radm_qoverflow;             // RADM queue has overflowed, for debug purpose
input                   radm_q_not_empty;           // RADM queue is not empty after test is complete, for debug purpose
input                   xdlh_retrybuf_not_empty;    // XDLH retry buffer is not empty after test is complete, for debug purpose
input                   rtlh_crd_not_rtn;           // RTLH credits are not returned after test is complete, for debug purpose


//--------------------- outputs -------------------------

// for PM handshake
input   [NF-1:0]        pm_status;                  // PM status, indicates if a previously enabled PME event occurred or not - Sticky
input   [NF-1:0]        pm_pme_en;                  // PME enable, device is enabled to generate PME - Sticky
input   [NF-1:0]        aux_pm_en;                  // AUX Power PM enable: enable device to draw AUX power independent of PME AUX Power - Sticky

// for filter address decoding
input [(FX_TLP*64)-1:0] flt_cdm_addr;               // 64-bit address to be compared with BAR
input   [NF-1:0]        pm_radm_block_tlp;          // In D1, D2 or D3 state - block certain error messages
input                   flt_cdm_rtlh_radm_pending;






input                     smlh_mod_ts_rcvd;         // g5 Modified TS Received
input   [55:0]            mod_ts_data_rcvd;         // mod ts data rcvd
input   [55:0]            mod_ts_data_sent;         // mod ts data txed

input                   xdlh_retry_req;              // Pulse : Retry Event 
input  [1:0]            rdlh_dlcntrl_state;          // Layer 2 control state


input                   smlh_in_l0;                     // Level: L0(idl) for Ras D.E.S
input                   smlh_in_l1;                     // Level: L1 Entry for Ras D.E.S event counter

input                   pm_sel_aux_clk;
input [UPD_WD-1:0]        radm_snoop_upd;
input [SNOOP_BUS_WD-1:0]  radm_snoop_bus_num;
input [SNOOP_DEV_WD-1:0]  radm_snoop_dev_num;

input                   app_clk_pm_en;


input  [4:0]             app_dev_num;                 // Device number driven by the application
input  [7:0]             app_bus_num;                 // Bus Number drive by the application


// ---------- Outputs --------
output  [NF-1:0]        cfg_upd_pme_cap;
output  [(NF*FX_TLP)-1:0] cfg_io_match;               // Within IO address range
output  [(NF*FX_TLP)-1:0] cfg_config_above_match;     // configuaration access belongs to the above our customer set address limit so that target1 interface will be the detination of the configuration rd/wr.
output  [(NF*FX_TLP)-1:0] cfg_rom_match;              // Within expansion ROM address range
output  [(6*NF*FX_TLP)-1:0]    cfg_bar_match;              // Within BAR range
output  [(6*NF)-1:0]    cfg_bar_is_io;              // Indicates whether the BAR is set as IO or memory
output  [(NF*FX_TLP)-1:0]        cfg_mem_match;              // Within Memory range (Type 1 only)
output  [(NF*FX_TLP)-1:0]        cfg_prefmem_match;          // Within Prefetchable Memorey range (Type 1 only)

output                  cfg_pl_l1_nowait_p1;
output                  cfg_pl_l1_clk_sel;
output                  cfg_phy_perst_on_warm_reset;
output [17:0]           cfg_phy_rst_timer;                                 // PHY rst timer
output [5:0]            cfg_pma_phy_rst_delay_timer;                       // PMA reset to PIPE reset delay timer
output [`CX_PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;                  // Aux clock frequency
output  [N_FLT_MASK-1:0]cfg_filter_rule_mask;       // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
output                  cfg_fc_wdog_disable;        // disable watch dog timer in FC for some debug purpose

//  To local bus controller
output  [(32*NF)-1:0]   cdm_lbc_data;               // Read data back from core
output  [NF-1:0]        cdm_lbc_ack;                // Acknowledge back from core. Indicates completion, read data is valid


output  [7:0]           cfg_hdr_type;               // CFG space header type
// for type 1 device only
output  [(16*NF)-1:0]   cfg_mem_base;               // device memory base address
output  [(16*NF)-1:0]   cfg_mem_limit;              // memory limit
output  [(64*NF)-1:0]   cfg_pref_mem_base;          // prefetchable memory base address
output  [(64*NF)-1:0]   cfg_pref_mem_limit;         // prefetchable memory limit address
output  [(16*NF)-1:0]   cfg_io_limit_upper16;       // IO Limit Upper 16 Bits
output  [(16*NF)-1:0]   cfg_io_base_upper16;        // IO Base Upper 16 Bits
output  [(8*NF)-1:0]    cfg_io_base;                // IO Base
output  [(8*NF)-1:0]    cfg_io_limit;               // IO Limit

// Power management
output  [(2*NF)-1:0]    cfg_aslk_pmctrl;            // active state PM control
output                  cfg_clk_pm_en;              // Clock PM enable, used to enable the feature that PHY can use to turn off the clock.
// to CX-PL
output  [NF-1:0]        cfg_relax_ord_en;           // relaxed ordering enable
output  [NF-1:0]        cfg_ext_tag_en;             // extended tag field enable
output  [NF-1:0]        cfg_phantom_fun_en;         // Phantom function enable
output  [NF-1:0]        cfg_no_snoop_en;            // No Snoop enable
output  [(3*NF)-1:0]    cfg_max_rd_req_size;        // MAX Read Request Size
output  [NF-1:0]        cfg_bridge_crs_en;          // Bridge Configuration Retry Enable (Bridge only)
output  [NF-1:0]        cfg_rcb;                    // RCB (read completion boundary)
output                  cfg_comm_clk_config;        // common clock configuration
output                  cfg_hw_autowidth_dis;       // HW autonomous width disable
output  [(3*NF)-1:0]    cfg_max_payload_size;       // MTU size
output  [2:0]           cfg_highest_max_payload;    // highest payload size among all functions
output  [7:0]           cfg_ack_freq;               // (PL) ACK frequency
output  [15:0]          cfg_ack_latency_timer;      // (PL) ACK latency timer
output  [12:0]          cfg_fc_latency_value;       // (PL) FC latency timer
output  [16:0]          cfg_replay_timer_value;     // (PL) Replay timer value
output  [31:0]          cfg_other_msg_payload;      // (PL) Other MSG payload, for test equipment purpose
output                  cfg_other_msg_request;      // (PL) Other MSG request, for test equipment purpose
output  [31:0]          cfg_corrupt_crc_pattern;    // (PL) Corrupted CRC pattern for test purpose
output  [5:0]           cfg_link_capable;           // (PL) Link Capable (x1, x2 ... x32)
output                  cfg_scramble_dis;           // (PL) scrambler disable
output  [7:0]           cfg_n_fts;                  // (PL) Number of Fast training sequence
output                  cfg_link_dis;               // Link disable
output                  cfg_link_retrain;           // Link retrain
output                  cfg_lpbk_en;                // (PL) Loopback enable
output                  cfg_elastic_buffer_mode;    // (PL) elastic buffer mode
output                  cfg_pipe_loopback;          // Local Loopback Enable
output  [5:0]           cfg_rxstatus_lane;          // Lane to inject rxstatus value(bit6 = all lanes)
output  [2:0]           cfg_rxstatus_value;         // rxstatus value to inject
output  [NL-1:0]        cfg_lpbk_rxvalid;           // rxvalid value to use during loopback
output  [7:0]           cfg_link_num;               // (PL) Link number (0 to 255), advertised to link partner
output                  cfg_ts2_lid_deskew;         // do deskew using ts2->Logic_Idle_Data transition
output                  cfg_support_part_lanes_rxei_exit; //Polling.Active -> Polling.Config based on part of pre lanes rxei exit
output                  cfg_plreg_reset;            // (PL) Reset link state machine for test purpose
output  [5:0]           cfg_forced_link_state;      // (PL) a 5-bit register to move the link state to this value indicated
output  [3:0]           cfg_forced_ltssm_cmd;
output                  cfg_force_en;               // (PL) force enable has to be a pulse signal generated from cfg block. When software writes
output  [23:0]          cfg_lane_skew;              // (PL) Transmit lane skew control (optional) for test equipment
output                  cfg_deskew_disable;         // (PL) Deskew disable
output                  cfg_flow_control_disable;   // (PL) disable the automatic flowcontrol
output                  cfg_acknack_disable;        // (PL) disable the automatic ACK/NACK
output  [3:0]           cfg_imp_num_lanes;          // (PL) implementation-specific number of lanes
output                  cfg_dll_lnk_en;             // (PL) DLL Link enable
output                  cfg_soft_rst_n;             // Soft reset (not used)
output  [3:0]           cfg_eidle_timer;            // (PL) eidle timer
output  [10:0]          cfg_skip_interval;          // (PL) skip interval
output  [3:0]           cfg_link_rate;              // link data rate
output  [1:0]           cfg_retimers_pre_detected;  // Retimers present detected {retimer2,retimer1}
output                  cfg_l0s_supported;          // from Link Cap Reg
output                  cfg_fast_link_mode;         // (PL) fast link mode
output  [1:0]           cfg_fast_link_scaling_factor; // (PL) fast link timer scaling factor
output                  cfg_2nd_reset;              // reset the internal side of bus for a bridge device
output  [NF-1:0]        cfg_ecrc_gen_en;            // ECRC Gen enable
output  [NF-1:0]        cfg_ecrc_chk_en;            // ECRC Check enable
output                  cfg_ext_synch;              // Extended synch
output  [31:0]          cfg_phy_control;            // (PL) PHY control register
output  [NF-1:0]        cfg_io_space_en;            // IO address space enable
output  [NF-1:0]        cfg_mem_space_en;           // memory address space enable
output  [(64*NF)-1:0]   cfg_bar0_start;             // BAR0 base address
output  [(64*NF)-1:0]   cfg_bar0_limit;             // BAR0 limit
output  [(64*NF)-1:0]   cfg_bar0_mask;              // BAR0 mask register
output  [(32*NF)-1:0]   cfg_bar1_start;             // BAR1 base address
output  [(32*NF)-1:0]   cfg_bar1_limit;             // BAR1 limit
output  [(32*NF)-1:0]   cfg_bar1_mask;              // BAR1 mask register
output  [(64*NF)-1:0]   cfg_bar2_start;             // BAR2 base address
output  [(64*NF)-1:0]   cfg_bar2_limit;             // BAR2 limit
output  [(64*NF)-1:0]   cfg_bar2_mask;              // BAR2 mask register
output  [(32*NF)-1:0]   cfg_bar3_start;             // BAR3 base address
output  [(32*NF)-1:0]   cfg_bar3_limit;             // BAR3 limit
output  [(32*NF)-1:0]   cfg_bar3_mask;              // BAR3 mask register
output  [(64*NF)-1:0]   cfg_bar4_start;             // BAR4 base address
output  [(64*NF)-1:0]   cfg_bar4_limit;             // BAR4 limit
output  [(64*NF)-1:0]   cfg_bar4_mask;              // BAR4 mask register
output  [(32*NF)-1:0]   cfg_bar5_start;             // BAR5 base address
output  [(32*NF)-1:0]   cfg_bar5_limit;             // BAR5 limit
output  [(32*NF)-1:0]   cfg_bar5_mask;              // BAR5 mask register
output  [(32*NF)-1:0]   cfg_rom_mask;               // ROM BAR mask register
output  [(32*NF)-1:0]   cfg_exp_rom_start;          // Expansion ROM base Address
output  [(32*NF)-1:0]   cfg_exp_rom_limit;          // Expansion ROM limit Address

output  [BUSNUM_WD-1:0] cfg_pbus_num;               // primary Bus number
output  [DEVNUM_WD-1:0] cfg_pbus_dev_num;           // primary device number
output  [(8*NF)-1:0]    cfg_2ndbus_num;             // 2nd bus number
output  [(8*NF)-1:0]    cfg_subbus_num;             // sub bus number
output                  upstream_port;              // upstream port when set
output                  switch_device;              // switch device when set
output                  end_device;                 // end-point device when set
output                  rc_device;                  // RC device when set
output                  bridge_device;              // bridge device
output  [NF-1:0]        cfg_upd_pmcsr;              // Update PM state (bit 1:0 of PMCSR)
output  [NF-1:0]        cfg_upd_req_id;
output  [NF-1:0]        cfg_aux_pm_en;              // AUX Power PM Enable (Bit 10 of Device control register)
output  [NF-1:0]        cfg_upd_aux_pm_en;          // Update AUX Power PM Enable (Bit 10 of Device control register)
output  [NF-1:0]        cfg_pmstatus_clr;           // Clear PM status (bit 15 of PMCSR)
output  [(3*NF)-1:0]    cfg_pmstate;                // PM state
output  [NF-1:0]        cfg_pme_en;                 // PME enable
output  [(5*NF)-1:0]    cfg_pme_cap;                // PME_support in PM capabilities register
output  [NF-1:0]        cfg_pm_no_soft_rst;         // Indicates no soft reset needed
output  [2:0]           cfg_l0s_entr_latency_timer; // (PL) L0s Entrance Latency
output  [2:0]           cfg_l1_entr_latency_timer;  // (PL) L1 Entrance Latency
output                  cfg_l1_entr_wo_rl0s;        // (PL) Start L1 timer without rL0s
output  [NF-1:0]        cfg_bus_master_en;          // register bus master enable

output  [NF-1:0]        cfg_reg_serren;             // SERR enable bit
output  [NF-1:0]        cfg_cor_err_rpt_en;         // Correctable Error Reporting enable bit
output  [NF-1:0]        cfg_nf_err_rpt_en;          // Non-Fatal Error Reporting enable bit
output  [NF-1:0]        cfg_f_err_rpt_en;           // Fatal Error Reporting enable bit

output  [NF-1:0]        cfg_isa_enable;             // For bridge: ISA enable
output  [NF-1:0]        cfg_vga_enable;             // For bridge: VGA enable (optional)
output  [NF-1:0]        cfg_vga16_decode;           // For bridge: VGA 16-bit decode (optional)
output  [NF-1:0]        cfg_send_cor_err;           // Send a correctable error MSG
output  [NF-1:0]        cfg_send_nf_err;            // Send a non-fatal uncorrectable error MSG
output  [NF-1:0]        cfg_send_f_err;             // Send a fatal uncorrectable error MSG
output  [(3*NF)-1:0]    cfg_func_spec_err;          // Indicate function specific error.  Bit 0 for cor, bit 1 for NF, bit 2 for F
output  [NF-1:0]        cfg_aer_rc_err_int;         // RC Only: Error interrupt
output  [NF-1:0]        cfg_aer_rc_err_msi;         // RC Only: Error MSI/MSI-X
output  [(NF*5)-1:0]    cfg_aer_int_msg_num;        // RC Only: Advanced Error Interrupt Message Number
output  [NF-1:0]        cfg_sys_err_rc;             // RC Only: System error
output  [NF-1:0]        cfg_crs_sw_vis_en;
output  [NF-1:0]        cfg_pme_int;                // RC Only: Interrupt caused by PME
output  [NF-1:0]        cfg_pme_msi;                // RC Only: MSI caused by PME
output  [(NF*5)-1:0]    cfg_pcie_cap_int_msg_num;   // Interrupt Message Number
output  [NF-1:0]        cfg_cpl_timeout_disable;    // Completion timeout disable
output  [8:0]           cfg_lane_en;                // Number of lanes (1-256)
output                  cfg_gen1_ei_inference_mode; // EI inference mode for Gen1. default 0 - using rxelecidle==1; 1 - using rxvalid==0
output  [1:0]           cfg_select_deemph_mux_bus;  // sel deemphasis {bit, var}
output  [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl;           // lane under test + gen5 control
output  [6:0]           cfg_rxstandby_control;      // Rxstandby Control
output                  cfg_link_auto_bw_int;       // Interrupt indicating that Link Bandwidth Management Status bit has been set
output                  cfg_link_auto_bw_msi;       // MSI Interrupt indicating that Link Bandwidth Management Status bit has been set
output                  cfg_bw_mgt_int;             // Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
output                  cfg_bw_mgt_msi;             // MSI Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
output  [(2*NF)-1:0]    cfg_pwr_ind;                // Power indicator command
output  [(2*NF)-1:0]    cfg_atten_ind;              // Attention indicator command
output  [NF-1:0]        cfg_pwr_ctrler_ctrl;        // Power controller control
output  [NF-1:0]        cfg_eml_control;            // Electromechanical Interlock Control
output  [NF-1:0]        cfg_slot_pwr_limit_wr;
output  [NF-1:0]        cfg_int_disable;
output  [(3*NF)-1:0]    cfg_multi_msi_en;
output  [NF-1:0]        cfg_msi_ext_data_en;
output  [NF-1:0]        cfg_msi_en;
output  [(64*NF)-1:0]   cfg_msi_addr;
output  [(32*NF)-1:0]   cfg_msi_data;
output  [NF-1:0]        cfg_msi_64;
output  [NF-1:0]        cfg_msix_en;
output  [NF-1:0]        cfg_msix_func_mask;


output  [7:0]           set_slot_pwr_limit_val;
output  [1:0]           set_slot_pwr_limit_scale;
// VC
output  [(NVC*1)-1:0]   cfg_vc_enable;              // Which VCs are enabled - VC0 is always enabled
output  [(NVC*3)-1:0]   cfg_vc_struc_vc_id_map;     // VC Structure to VC ID mapping
output  [23:0]          cfg_vc_id_vc_struc_map;     // VC ID to VC Structure mapping
output  [7:0]           cfg_tc_enable;              // Which TCs are enabled
output  [23:0]          cfg_tc_vc_map;              // TC to VC ID mapping
output  [23:0]          cfg_tc_struc_vc_map;        // TC to VC Structure mapping
output  [2:0]           cfg_lpvc;                   // Low Priority Extended VC (LPVC) Count
output  [2:0]           cfg_vc_arb_sel;             // VC Arbitration Select
output  [63:0]          cfg_lpvc_wrr_weight;        // (PL) WRR weighing per VC ID (8 bits per VC)
output  [PF_WD-1:0]     cfg_max_func_num;           // (PL) Highest accepted function number
output                  cfg_upd_aspm_ctrl;          // ASPM control update
output  [(NF - 1) : 0]  cfg_upd_aslk_pmctrl;        // ASLK pm control
output  [31:0]          cfg_trgt_cpl_lut_delete_entry;  // (PL) trgt_cpl_lut delete one entry
output  [1:0]           cfg_clock_gating_ctrl;      // (PL) Enable/Disable Radm clock gating  
output  [(NVC*8)-1:0]   cfg_fc_credit_ph;           // (PL) Flow Control credits - Posted Header
output  [(NVC*8)-1:0]   cfg_fc_credit_nph;          // (PL) Flow Control credits - Non-Posted Header
output  [(NVC*8)-1:0]   cfg_fc_credit_cplh;         // (PL) Flow Control credits - Completion Header
output  [(NVC*12)-1:0]  cfg_fc_credit_pd;           // (PL) Flow Control credits - Posted Data
output  [(NVC*12)-1:0]  cfg_fc_credit_npd;          // (PL) Flow Control credits - Non-Posted Data
output  [(NVC*12)-1:0]  cfg_fc_credit_cpld;         // (PL) Flow Control credits - Completion Data
output  [(NVC*9)-1:0]   cfg_radm_q_mode;            // (PL) Queue Mode: CPL(BP/CT/SF), NP(BP/CT/SF), P(BP/CT/SF)
output  [NVC-1:0]       cfg_radm_order_rule;        // (PL) Order Selection: 0 - Strict Priority, 1 - Complies with Ordering Rule
output  [15:0]          cfg_order_rule_ctrl;        // (PL) cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC
output                  cfg_radm_strict_vc_prior;   // (PL) VC Priority: 0 - Round Robin, 1 - Strict Priority
output  [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0]     cfg_hq_depths;  // (PL) Indicates the depth of the header queues per type per vc
output  [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]    cfg_dq_depths;  // (PL) Indicates the depth of the data queues per type per vc
output  [(6*NF)-1:0]    target_mem_map;             // Each bit of this vector indicates which target receives memory transactions for that bar #
output  [NF-1:0]        target_rom_map;             // Each bit of this vector indicates which target receives rom    transactions for that bar #

output                  inta_wire;                  // virtual legacy wire of interrupt A for message generation purpose
output                  intb_wire;                  // virtual legacy wire of interrupt B for message generation purpose
output                  intc_wire;                  // virtual legacy wire of interrupt C for message generation purpose
output                  intd_wire;                  // virtual legacy wire of interrupt D for message generation purpose

output [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control; // Multi Lane Control Register

output                     cfg_alt_protocol_enable;// Alternate protocol support
output  [(8*NF)-1:0]    cfg_int_pin;                    // Interrupt Pin mapping



output                  default_target;               // Default target if there is any error
output                  ur_ca_mask_4_trgt1;           // Mask the UR CA error is the default target is 1
output                  cfg_cfg_tlp_bypass_en;           //CFG_TLP_BYPASS_EN_REG
output [9:0]            cfg_config_limit;                //CONFIG_LIMIT_REG
output [1:0]            cfg_target_above_config_limit;   //TARGET_ABOVE_CONFIG_LIMIT_REG
output                  cfg_p2p_track_cpl_to;            //P2P_TRACK_CPL_TO_REG
output                  cfg_p2p_err_rpt_ctrl;            //P2P_ERR_RPT_CTRL


output                  cfg_pipe_garbage_data_mode;         // PIPE Garbage Data mode















output                  cfg_nond0_vdm_block;
output                  cfg_client0_block_new_tlp;
output                  cfg_client1_block_new_tlp;
output                  cfg_client2_block_new_tlp;

output [NF-1:0]        cfg_br_ctrl_serren;

output   [NF-1:0]       cdm_hp_pme;
output   [NF-1:0]       cdm_hp_int;
output   [NF-1:0]       cdm_hp_msi;
wire     [NF-1:0]       cdm_hp_pme;
wire     [NF-1:0]       cdm_hp_int;
wire     [NF-1:0]       cdm_hp_msi;

output   [NF-1:0] cfg_auto_slot_pwr_lmt_dis;    // Auto Slot Power Limit Disable field of Slot Control Register; hardwired to 0 if DPC is not configured.
output   [NF-1:0] cfg_hp_slot_ctrl_access;
output   [NF-1:0] cfg_dll_state_chged_en;
output   [NF-1:0] cfg_cmd_cpled_int_en; 
output   [NF-1:0] cfg_pre_det_chged_en; 
output   [NF-1:0] cfg_mrl_sensor_chged_en; 
output   [NF-1:0] cfg_pwr_fault_det_en; 
output   [NF-1:0] cfg_atten_button_pressed_en;
output   [NF-1:0] cfg_hp_int_en;




wire     [NF-1:0]       cfg_atten_button_pressed;
wire     [NF-1:0]       cfg_pwr_fault_det;
wire     [NF-1:0]       cfg_mrl_sensor_chged;
wire     [NF-1:0]       cfg_pre_det_chged;
wire     [NF-1:0]       cfg_cmd_cpled_int;
wire     [NF-1:0]       cfg_dll_state_chged;


input [(2 * PWDN_WIDTH) - 1 : 0]             pm_powerdown_status; // powerdown status
output                                       cfg_force_powerdown; // debug bit to force completion of powerdown transition

input [NF-1:0]              exp_rom_validation_status_strobe;
input [NF*3-1:0]            exp_rom_validation_status;
input [NF-1:0]              exp_rom_validation_details_strobe;
input [NF*4-1:0]            exp_rom_validation_details;

output                      cfg_pcie_slot_clk_config;
output                      cfg_uncor_internal_err_sts;
output                      cfg_rcvr_overflow_err_sts;
output                      cfg_fc_protocol_err_sts;
output                      cfg_mlf_tlp_err_sts;
output                      cfg_surprise_down_er_sts;
output                      cfg_dl_protocol_err_sts;
output                      cfg_ecrc_err_sts;
output                      cfg_corrected_internal_err_sts;
output                      cfg_replay_number_rollover_err_sts;
output                      cfg_replay_timer_timeout_err_sts;
output                      cfg_bad_dllp_err_sts;
output                      cfg_bad_tlp_err_sts;
output                      cfg_rcvr_err_sts;

// -----------------------------------------------------------------------------
// Signal declaration
// -----------------------------------------------------------------------------
wire                    cfg_pcie_slot_clk_config_i[NF-1:0];
wire                    cfg_pcie_slot_clk_config = cfg_pcie_slot_clk_config_i[0];

// LBC
//
wire                    dbi_ro_wr_en;
wire                    default_target;
wire                    ur_ca_mask_4_trgt1;
wire                    cfg_cfg_tlp_bypass_en;
wire [9:0]              cfg_config_limit;               
wire [1:0]              cfg_target_above_config_limit;  
wire                    cfg_p2p_track_cpl_to;           
wire                    cfg_p2p_err_rpt_ctrl;   
wire                    pl_reg_ack;
wire    [NF-1:0]        cfg_reg_ack;
wire    [NF-1:0]        cfg_cap_reg_ack;
wire    [NF-1:0]        ecfg_reg_ack;
wire                    pl_reg_sel;
wire    [NF-1:0]        cfg_reg_sel;
wire    [NF-1:0]        cfg_cap_reg_sel;
wire    [NF-1:0]        ecfg_reg_sel;
wire    [31:0]          cdm_pf_ecfg_addr;
wire    [((32*NF)-1):0] err_reg_data;
wire    [((18*NF)-1):0] err_reg_id;
wire    [((4*NF)-1):0]  ecfg_write_pulse;
wire    [31:0]          pl_reg_data;
wire    [((32*NF)-1):0] cfg_reg_data;
wire    [((32*NF)-1):0] cfg_cap_reg_data;
wire    [((32*NF)-1):0] ecfg_reg_data;
// Misc
wire    [NF-1:0]        int_cfg_2nd_reset;
wire    [(8*NF)-1:0]    int_cfg_hdr_type;
wire    [(4*NF)-1:0]    int_cfg_link_rate;
wire    [(2*NF)-1:0]    int_cfg_retimers_pre_detected;
wire    [(2*NF)-1:0]    cfg_pwr_ind;
wire    [(2*NF)-1:0]    cfg_atten_ind;
wire    [(10*NF)-1:0]   cfg_pcie_slot_pwr_limit;
wire    [7:0]           set_slot_pwr_limit_val;
assign set_slot_pwr_limit_val      = cfg_pcie_slot_pwr_limit[7:0];
wire    [1:0]           set_slot_pwr_limit_scale;
assign set_slot_pwr_limit_scale    = cfg_pcie_slot_pwr_limit[9:8];
wire    [NF-1:0]        cfg_slot_pwr_limit_wr;
wire                    cfg_link_retrain;
wire                    cfg_tx_reverse_lanes;
wire    [(8*NF)-1:0]    cfg_int_pin;                    // Interrupt Pin mapping
wire                    cfg_clk_pm_en;
wire    [NF-1:0]        int_cfg_clk_pm_en;
wire    [NF-1:0]        cfg_eml_control;
wire    [NF-1:0]        sys_eml_interlock_engaged;
// Function 0 Only Signals
wire    [NF-1:0]        int_cfg_sys_err_rc;             // RC Only: System error
wire    [NF-1:0]        int_cfg_pme_int;                // RC Only: Interrupt caused by PME
wire    [NF-1:0]        int_cfg_pme_msi;                // RC Only: MSI caused by PME
wire    [NF-1:0]        int_cfg_crs_sw_vis_en; 
wire    [NF-1:0]        int_cfg_link_auto_bw_int;       // Interrupt indicating that Link Bandwidth Management Status bit has been set
wire    [NF-1:0]        int_cfg_link_auto_bw_msi;       // MSI Interrupt indicating that Link Bandwidth Management Status bit has been set
wire    [NF-1:0]        int_cfg_bw_mgt_int;             // Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
wire    [NF-1:0]        int_cfg_bw_mgt_msi;             // MSI Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
wire    [(NF*NVC*1)-1:0] int_cfg_vc_enable;             // Which VCs are enabled - VC0 is always enabled
wire    [(NF*NVC*3)-1:0] int_cfg_vc_struc_vc_id_map;    // VC Structure to VC ID mapping
wire    [(NF*24)-1:0]   int_cfg_vc_id_vc_struc_map;     // VC ID to VC Structure mapping
wire    [(NF*8)-1:0]    int_cfg_tc_enable;              // Which TCs are enabled
wire    [(NF*24)-1:0]   int_cfg_tc_vc_map;              // TC to VC ID mapping
wire    [(NF*3)-1:0]    int_cfg_lpvc;                   // Low Priority Extended VC (LPVC) Count
wire    [(NF*24)-1:0]   int_cfg_tc_struc_vc_map;        // TC to VC Structure mapping
wire    [(NF*3)-1:0]    int_cfg_vc_arb_sel;             // VC Arbitration Select
wire    [(NF*3)-1:0]    int_cfg_func_spec_err;          // Indicate function specific error.  Bit 0 for cor, bit 1 for NF, bit 2 for F
wire    [NF-1:0]        int_cfg_aer_rc_err_int;         // RC Only: Error interrupt
wire    [NF-1:0]        int_cfg_aer_rc_err_msi;         // RC Only: Error MSI/MSI-X
// VC
wire    [(NVC*1)-1:0]   cfg_vc_enable;                  // Which VCs are enabled - VC0 is always enabled
wire    [(NVC*3)-1:0]   cfg_vc_struc_vc_id_map;         // VC Structure to VC ID mapping
wire    [23:0]          cfg_vc_id_vc_struc_map;         // VC ID to VC Structure mapping
wire    [7:0]           cfg_tc_enable;                  // Which TCs are enabled
wire    [23:0]          cfg_tc_vc_map;                  // TC to VC ID mapping
wire    [2:0]           cfg_lpvc;                       // Low Priority Extended VC (LPVC) Count
wire    [23:0]          cfg_tc_struc_vc_map;            // TC to VC Structure mapping
wire    [2:0]           cfg_vc_arb_sel;                 // VC Arbitration Select
wire    [63:0]          cfg_lpvc_wrr_weight;            // WRR weighing per VC (8 bits per VC)
// MSI: generate Memory write for hotplug INT MSI inside ADM
wire    [(3*NF)-1:0]    cfg_multi_msi_en;
wire    [NF-1:0]        cfg_msi_en;                     // system software enabled MSI
wire    [(64*NF)-1:0]   cfg_msi_addr;
wire    [(32*NF)-1:0]   cfg_msi_data;
// MSI-X
wire    [NF-1:0]        cfg_msix_en;
wire    [NF-1:0]        cfg_msix_func_mask;
wire    [(11*NF)-1:0]   cfg_msix_table_size;
wire    [(11*NF)-1:0]   cfg_msix_table_size2;
wire    [(3*NF)-1:0]    cfg_msix_table_bir;
wire    [(3*NF)-1:0]    cfg_msix_table_bir2;
wire    [(29*NF)-1:0]   cfg_msix_table_offset;
wire    [(29*NF)-1:0]   cfg_msix_table_offset2;
wire    [(3*NF)-1:0]    cfg_msix_pba_bir;
wire    [(3*NF)-1:0]    cfg_msix_pba_bir2;
wire    [(29*NF)-1:0]   cfg_msix_pba_offset;
wire    [(29*NF)-1:0]   cfg_msix_pba_offset2;
// VPD
wire    [NF-1:0]        cfg_vpd_int;


// Power Budgeting
wire    [31:0]          cfg_pwr_budget_data_reg;
wire    [PF_WD-1:0]     cfg_pwr_budget_func_num;
reg     [7:0]           cfg_pwr_budget_data_sel_reg;
wire    [(8*NF)-1:0]    int_cfg_pwr_budget_data_sel_reg;
wire    [NF-1:0]        cfg_pwr_budget_sel;

wire    [1:0]           cfg_select_deemph_mux_bus;
wire                               cfg_pl_l1_nowait_p1;
wire                               cfg_pl_l1_clk_sel;
wire                               cfg_phy_perst_on_warm_reset;
wire [17:0]                        cfg_phy_rst_timer;
wire [5:0]                         cfg_pma_phy_rst_delay_timer;
wire    [`CX_PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;   // programmable auxiliary clock frequency
wire [(32*NF)-1:0] pf_cfg_aer_uncorr_mask_bus;
wire [(32*NF)-1:0] pf_cfg_aer_uncorr_svrity_bus;
wire [(32*NF)-1:0] pf_cfg_aer_corr_mask_bus;
wire [NF-1:0]      pf_multi_hdr_rec_en_bus;





wire [2*NF-1:0]  pf_cfg_pcie_aspm_cap_bus;
wire             cfg_l0s_supported;
wire    [(6*NF)-1:0]             int_cfg_rbar_bar_resizable;      // Resize RBAR[n] when n = 0 to 5
wire    [(64*NF)-1:0]            int_cfg_rbar_bar0_mask;          // RBAR0 mask value
wire    [(32*NF)-1:0]            int_cfg_rbar_bar1_mask;          // RBAR1 mask value
wire    [(64*NF)-1:0]            int_cfg_rbar_bar2_mask;          // RBAR2 mask value
wire    [(32*NF)-1:0]            int_cfg_rbar_bar3_mask;          // RBAR3 mask value
wire    [(64*NF)-1:0]            int_cfg_rbar_bar4_mask;          // RBAR4 mask value
wire    [(32*NF)-1:0]            int_cfg_rbar_bar5_mask;          // RBAR5 mask value
wire    [NF-1:0]                 rbar_ctrl_update;                // RBAR size update - output only if RBARS exist
wire    [NF*(6*6)-1:0]           cfg_rbar_size;                   // RBAR sizes  - output only if RBARS exist
wire    [(6*NF)-1:0]             int_cfg_vf_rbar_bar_resizable;      // Resize VF RBAR[n] when n = 0 to 5
wire    [(64*NF)-1:0]            int_cfg_vf_rbar_bar0_mask;          // VF RBAR0 mask value
wire    [(32*NF)-1:0]            int_cfg_vf_rbar_bar1_mask;          // VF RBAR1 mask value
wire    [(64*NF)-1:0]            int_cfg_vf_rbar_bar2_mask;          // VF RBAR2 mask value
wire    [(32*NF)-1:0]            int_cfg_vf_rbar_bar3_mask;          // VF RBAR3 mask value
wire    [(64*NF)-1:0]            int_cfg_vf_rbar_bar4_mask;          // VF RBAR4 mask value
wire    [(32*NF)-1:0]            int_cfg_vf_rbar_bar5_mask;          // VF RBAR5 mask value
wire    [NF-1:0]                 vf_rbar_ctrl_update;                // VF RBAR size update - output only if VFRBARS exist
wire    [NF*(6*6)-1:0]           cfg_vf_rbar_size;                   // VF RBAR sizes  - output only if VFRBARS exist


// -------------------------------------------------------------------------------------------------


wire   [`CX_LUT_PL_WD-1:0]      cfg_lut_ctrl;                  //lane under test + gen5 control




wire [(8*NF)-1:0]    int_cfg_pbus_num;               // intermediate primary Bus number used to transform between different width
wire [(5*NF)-1:0]    int_cfg_pbus_dev_num;           // intermediate device number used to transform between different width

wire [NF-1:0]                      cfg_uncor_internal_err_sts_int        ;
wire [NF-1:0]                      cfg_rcvr_overflow_err_sts_int         ;
wire [NF-1:0]                      cfg_fc_protocol_err_sts_int           ;
wire [NF-1:0]                      cfg_mlf_tlp_err_sts_int               ;
wire [NF-1:0]                      cfg_surprise_down_er_sts_int          ;
wire [NF-1:0]                      cfg_dl_protocol_err_sts_int           ;
wire [NF-1:0]                      cfg_ecrc_err_sts_int                  ;
wire [NF-1:0]                      cfg_corrected_internal_err_sts_int    ;
wire [NF-1:0]                      cfg_replay_number_rollover_err_sts_int;
wire [NF-1:0]                      cfg_replay_timer_timeout_err_sts_int  ;
wire [NF-1:0]                      cfg_bad_dllp_err_sts_int              ;
wire [NF-1:0]                      cfg_bad_tlp_err_sts_int               ;
wire [NF-1:0]                      cfg_rcvr_err_sts_int                  ;

assign cfg_uncor_internal_err_sts         = cfg_uncor_internal_err_sts_int[0]        ;
assign cfg_rcvr_overflow_err_sts          = cfg_rcvr_overflow_err_sts_int[0]         ;
assign cfg_fc_protocol_err_sts            = cfg_fc_protocol_err_sts_int[0]           ;
assign cfg_mlf_tlp_err_sts                = cfg_mlf_tlp_err_sts_int[0]               ;
assign cfg_surprise_down_er_sts           = cfg_surprise_down_er_sts_int[0]          ;
assign cfg_dl_protocol_err_sts            = cfg_dl_protocol_err_sts_int[0]           ;
assign cfg_ecrc_err_sts                   = cfg_ecrc_err_sts_int[0]                  ;
assign cfg_corrected_internal_err_sts     = cfg_corrected_internal_err_sts_int[0]    ;
assign cfg_replay_number_rollover_err_sts = cfg_replay_number_rollover_err_sts_int[0];
assign cfg_replay_timer_timeout_err_sts   = cfg_replay_timer_timeout_err_sts_int[0]  ;
assign cfg_bad_dllp_err_sts               = cfg_bad_dllp_err_sts_int[0]              ;
assign cfg_bad_tlp_err_sts                = cfg_bad_tlp_err_sts_int[0]               ;
assign cfg_rcvr_err_sts                   = cfg_rcvr_err_sts_int[0]                  ;




// Errors
wire    [NF-1:0]        cfg_f_err_det;
wire    [NF-1:0]        cfg_nf_err_det;
wire    [NF-1:0]        cfg_cor_err_det;
wire    [NF-1:0]        cfg_unsupt_req_det;
wire    [NF-1:0]        cfg_cor_err_rpt_en;
wire    [NF-1:0]        cfg_nf_err_rpt_en;
wire    [NF-1:0]        cfg_f_err_rpt_en;
wire    [NF-1:0]        cfg_unsupt_req_rpt_en;
wire    [NF-1:0]        ecfg_read_pulse;
wire    [NF-1:0]        cfg_br_ctrl_serren;
wire    [NF-1:0]        cfg_br_ctrl_perren;
wire    [NF-1:0]        cfg_reg_perren;

wire    [NF-1:0]        int_ext_synch;
wire    [NF-1:0]        int_link_dis;
wire    [NF-1:0]        int_link_retrain;
wire    [NF-1:0]        int_cfg_comm_clk_config;
wire    [NF-1:0]        int_cfg_hw_autowidth_dis;
wire    [(2*NF)-1:0]    int_cfg_aslk_pmctrl;
wire    [(2*NF)-1:0]    cfg_aslk_pmctrl_cpcie;
wire    [(2*NF)-1:0]    cfg_aslk_pmctrl_mpcie;
wire    [NF-1:0]        int_cfg_upd_aslk_pmctrl;
wire    [NF-1:0]        cfg_upd_aslk_pmctrl;
wire    [NF-1:0]        cfg_upd_aslk_pmctrl_mpcie;
wire    [NF-1:0]        cfg_pcie_surp_dn_rpt_cap;

wire    [(NVC*8)-1:0]   cfg_fc_credit_ph;
wire    [(NVC*8)-1:0]   cfg_fc_credit_nph;
wire    [(NVC*8)-1:0]   cfg_fc_credit_cplh;
wire    [(NVC*12)-1:0]  cfg_fc_credit_pd;
wire    [(NVC*12)-1:0]  cfg_fc_credit_npd;
wire    [(NVC*12)-1:0]  cfg_fc_credit_cpld;
wire    [(NVC*9)-1:0]   cfg_radm_q_mode;
wire    [NVC-1:0]       cfg_radm_order_rule;
wire    [15:0]          cfg_order_rule_ctrl;        // cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC
wire    [1:0]           cfg_clock_gating_ctrl;          // Enable/Disable clock gating
wire    [31:0]          cfg_trgt_cpl_lut_delete_entry;  // trgt_cpl_lut delete one entry
wire                    cfg_radm_strict_vc_prior;
wire    [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0]     cfg_hq_depths;
wire    [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]    cfg_dq_depths;

wire    [NF-1:0]        master_data_perr_det;
wire    [NF-1:0]        signaled_target_abort_det;
wire    [NF-1:0]        rcvd_target_abort_det;
wire    [NF-1:0]        rcvd_master_abort_det;
wire    [NF-1:0]        signaled_sys_err_det;
wire    [NF-1:0]        perr_det;
wire    [NF-1:0]        master_data_perr_det2;
wire    [NF-1:0]        signaled_target_abort_det2;
wire    [NF-1:0]        rcvd_target_abort_det2;
wire    [NF-1:0]        rcvd_master_abort_det2;
wire    [NF-1:0]        signaled_sys_err_det2;
wire    [NF-1:0]        perr_det2;


wire    [(NF*5)-1:0]    cfg_pcie_cap_int_msg_num;   // Interrupt Message Number
wire    [(NF*5)-1:0]    cfg_aer_int_msg_num;        // Advanced Error Interrupt Message Number
wire    [NF-1:0]        cfg_rprt_err_cor;           // System Error factor by Correctable Error
wire    [NF-1:0]        cfg_rprt_err_nf;            // System Error factor by Non-Fatal Error
wire    [NF-1:0]        cfg_rprt_err_f;             // System Error factor by Fatal Error

wire    [4*NF-1:0]      pf_cfg_pcie_max_link_speed_bus;


reg     [NF-1:0]             rtlh_overfl_err_d;
always @(posedge core_clk or negedge sticky_rst_n)
begin : rtlh_overfl_d_PROC
    if (!sticky_rst_n)
        rtlh_overfl_err_d <= #TP 0;
    else
        rtlh_overfl_err_d <= #TP rtlh_overfl_err;
end

// Device Types
wire    end_device;
wire    rc_device;
wire    pcie_sw_up;
wire    pcie_sw_down;
wire    switch_device;
wire    pcie_br_up;
wire    pcie_br_down;
wire    bridge_device;
wire    upstream_port;
assign end_device       = (device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY);
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_up       = (device_type == `PCIE_SW_UP);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);
assign switch_device    = pcie_sw_up | pcie_sw_down | bridge_device;
assign pcie_br_up       = (device_type == `PCIE_PCIX);
assign pcie_br_down     = (device_type == `PCIX_PCIE);
assign bridge_device    = pcie_br_up | pcie_br_down;
assign upstream_port    = end_device | pcie_br_up | pcie_sw_up;







reg [2:0] cfg_highest_max_payload;
// For a single function, highest max payload is function 0's max payload.
always @(cfg_max_payload_size)
begin: gen_max_payload_1f
    cfg_highest_max_payload = cfg_max_payload_size[2:0];
end

reg [2:0] cfg_smallest_max_payload;
// For a single function, smallest max payload is function 0's max payload.
always @(cfg_max_payload_size)
begin: gen_min_payload_1f
    cfg_smallest_max_payload = cfg_max_payload_size[2:0];
end

// =============================================================================
// Extract Function 0 Specific Signals
// =============================================================================
assign cfg_sys_err_rc[0]            = int_cfg_sys_err_rc[0];                  // RC Only: System error
assign cfg_crs_sw_vis_en[0]         = int_cfg_crs_sw_vis_en[0];               // Root ctrl CRS Software Visibility feature enable
assign cfg_pme_int[0]               = int_cfg_pme_int[0];                     // RC Only: Interrupt caused by PME
assign cfg_pme_msi[0]               = int_cfg_pme_msi[0];                     // RC Only: MSI caused by PME
assign cfg_link_auto_bw_int         = int_cfg_link_auto_bw_int[0];            // Interrupt indicating that Link Bandwidth Management Status bit has been set
assign cfg_link_auto_bw_msi         = int_cfg_link_auto_bw_msi[0];            // MSI Interrupt indicating that Link Bandwidth Management Status bit has been set
assign cfg_bw_mgt_int               = int_cfg_bw_mgt_int[0];                  // Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
assign cfg_bw_mgt_msi               = int_cfg_bw_mgt_msi[0];                  // MSI Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
assign cfg_vc_enable                = 
                                       int_cfg_vc_enable[NVC-1:0] ;             // Which VCs are enabled - VC0 is always enabled
assign cfg_vc_struc_vc_id_map       =
                                       int_cfg_vc_struc_vc_id_map[(NVC*3)-1:0] ;// VC Structure to VC ID mapping
assign cfg_vc_id_vc_struc_map       = 
                                       int_cfg_vc_id_vc_struc_map[23:0] ;       // VC ID to VC Structure mapping
assign cfg_tc_enable                =
                                       int_cfg_tc_enable[7:0] ;                 // Which TCs are enabled
assign cfg_tc_vc_map                =
                                       int_cfg_tc_vc_map[23:0] ;                // TC to VC ID mapping
assign cfg_lpvc                     =
                                       int_cfg_lpvc[2:0] ;                      // Low Priority Extended VC (LPVC) Count
assign cfg_tc_struc_vc_map          =
                                       int_cfg_tc_struc_vc_map[23:0] ;          // TC to VC Structure mapping
assign cfg_vc_arb_sel               =
                                       int_cfg_vc_arb_sel[2:0] ;                // VC Arbitration Select
assign cfg_aer_rc_err_int[0]        = int_cfg_aer_rc_err_int[0];              // RC Only: Error interrupt
assign cfg_aer_rc_err_msi[0]        = int_cfg_aer_rc_err_msi[0];              // RC Only: Error MSI/MSI-X
// =============================================================================
// Assert completion timeout error for the appropriate function
reg     [NF-1:0]    int_radm_cpl_timeout_pf;
wire    [NF-1:0]    radm_cpl_timeout_pf;
always @(*)
begin: get_radm_cpl_timeout_pf
integer j;
    int_radm_cpl_timeout_pf = 0;
    for (j = 0; j<NF; j=j+1) begin
        if ((j == radm_timeout_func_num)
            && radm_cpl_timeout
           ) begin
            int_radm_cpl_timeout_pf[j] = 1'b1;
        end
    end
end
assign radm_cpl_timeout_pf = int_radm_cpl_timeout_pf;

// =============================================================================
// Mux error signals between the radm and app
wire    [(FX_TLP*NF)-1:0]    cdm_hdr_log_valid;
wire    [(FX_TLP*128)-1:0]   cdm_hdr_log;
wire    [(FX_TLP*NF)-1:0]    cdm_mlf_tlp_err;
wire    [NF-1:0]             cdm_rcvr_overflow;
wire    [(FX_TLP*NF)-1:0]    cdm_rcvd_req_ur;
wire    [(FX_TLP*NF)-1:0]    cdm_rcvd_req_ca;
wire    [(FX_TLP*NF)-1:0]    cdm_unexp_cpl_err;
wire    [(FX_TLP*NF)-1:0]    cdm_rcvd_wreq_poisoned;
wire    [(FX_TLP*NF)-1:0]    cdm_ecrc_err;
wire    [NF-1:0]             cdm_cpl_timeout;
wire    [NF-1:0]             cdm_internal_err;
wire    [NF-1:0]             cdm_corr_internal_err;
wire    [FX_TLP-1:0]         int_err_advisory;


assign cdm_hdr_log              = radm_hdr_log;
assign cdm_hdr_log_valid        = radm_hdr_log_valid;
assign cdm_mlf_tlp_err          = radm_mlf_tlp_err;
assign cdm_acs_violation        = 'b0;
assign cdm_rcvr_overflow        = rtlh_overfl_err_d;
assign cdm_rcvd_req_ur          = radm_rcvd_req_ur;
assign cdm_rcvd_req_ca          = radm_rcvd_req_ca;
assign cdm_unexp_cpl_err        = radm_unexp_cpl_err;
assign cdm_rcvd_wreq_poisoned   = radm_rcvd_wreq_poisoned;
assign cdm_ecrc_err             = radm_ecrc_err;
assign cdm_cpl_timeout          = radm_cpl_timeout_pf;
assign cdm_internal_err         = {NF{1'b0}}
                                 | {NF{radm_qoverflow}}
;
assign cdm_corr_internal_err    = {NF{1'b0}}
;
assign int_err_advisory         = cdm_err_advisory;








// =============================================================================
// Error reporting in D1-D3 states
// signal radm_pm_block_tlp indicate that we're in D1-D3 states
wire    [NF-1:0]        blocked_error_in_d13;
reg     [NF-1:0]        cfg_send_cor_err;
reg     [NF-1:0]        cfg_send_nf_err;
reg     [NF-1:0]        cfg_send_f_err;
reg     [(3*NF)-1:0]    cfg_func_spec_err;
reg     [NF-1:0]        send_aft_blk_cor_err;
reg     [NF-1:0]        send_aft_blk_nf_err;
reg     [NF-1:0]        send_aft_blk_f_err;
wire    [NF-1:0]        int_cfg_send_cor_err;
wire    [NF-1:0]        int_cfg_send_nf_err;
wire    [NF-1:0]        int_cfg_send_f_err;

wire                    int_rtlh_fc_prot_err;
wire                    rtlh_fc_prot_err;
assign rtlh_fc_prot_err = 1'b0;
assign int_rtlh_fc_prot_err = rtlh_fc_prot_err;

wire    [NF-1:0]        int_radm_set_slot_pwr_limit;
assign int_radm_set_slot_pwr_limit = radm_set_slot_pwr_limit;

// Errors that aren't caused by a received TLP:
// 1. Replay Timeout
// 2. REPLAY NUM Rollover
// 3. Completion Timeout
// 4. Flow Control Protocol Error
// 5. Receiver Overflow
// All the other errors are caused by a received TLP
// In D1-D3 states
assign blocked_error_in_d13 = {NF{xdlh_replay_timeout_err}} | {NF{xdlh_replay_num_rlover_err}} |
                               cdm_cpl_timeout | {NF{int_rtlh_fc_prot_err}} | cdm_rcvr_overflow
                                   | cdm_internal_err | cdm_corr_internal_err
                               ;

// Latch the error if in D1-D3 states
always @(posedge core_clk or negedge non_sticky_rst_n)
begin: latch_error_proc
integer m;
    if (!non_sticky_rst_n) begin
        cfg_send_cor_err        <= #TP 0;
        cfg_send_nf_err         <= #TP 0;
        cfg_send_f_err          <= #TP 0;
        cfg_func_spec_err       <= #TP 0;
        send_aft_blk_cor_err    <= #TP 0;
        send_aft_blk_nf_err     <= #TP 0;
        send_aft_blk_f_err      <= #TP 0;
    end
    else begin
        // delay to align with error signals
        cfg_func_spec_err       <= #TP int_cfg_func_spec_err;
        for (m=0; m<NF; m=m+1) begin
            if (pm_radm_block_tlp[m])
                // Block the errors if it's not caused by received TLP and save it
                if (blocked_error_in_d13[m]) begin
                    cfg_send_cor_err[m]     <= #TP 0;
                    cfg_send_nf_err[m]      <= #TP 0;
                    cfg_send_f_err[m]       <= #TP 0;
                      send_aft_blk_cor_err[m] <= #TP int_cfg_send_cor_err[m] ? 1'b1 : send_aft_blk_cor_err[m];
                      send_aft_blk_nf_err[m]  <= #TP int_cfg_send_nf_err[m] ? 1'b1 : send_aft_blk_nf_err[m];
                      send_aft_blk_f_err[m]   <= #TP int_cfg_send_f_err[m] ? 1'b1 : send_aft_blk_f_err[m];
                end
                // if it's caused by a received TLP, then send it
                else begin
                    cfg_send_cor_err[m]     <= #TP int_cfg_send_cor_err[m];
                    cfg_send_nf_err[m]      <= #TP int_cfg_send_nf_err[m];
                    cfg_send_f_err[m]       <= #TP int_cfg_send_f_err[m];
                end
            // Not in D1-D3 states, send normally
            else begin
                // Send the error message latched while in D1-D3 states
                if (send_aft_blk_cor_err[m]) begin
                    cfg_send_cor_err[m]     <= #TP send_aft_blk_cor_err[m];
                    send_aft_blk_cor_err[m] <= #TP 0;
                end
                else begin
                    cfg_send_cor_err[m]     <= #TP int_cfg_send_cor_err[m];
                    send_aft_blk_cor_err[m] <= #TP 0;
                end

                if (send_aft_blk_nf_err[m]) begin
                    cfg_send_nf_err[m]      <= #TP send_aft_blk_nf_err[m];
                    send_aft_blk_nf_err[m]  <= #TP 0;
                end
                else begin
                    cfg_send_nf_err[m]      <= #TP int_cfg_send_nf_err[m];
                    send_aft_blk_nf_err[m]  <= #TP 0;
                end

                if (send_aft_blk_f_err[m]) begin
                    cfg_send_f_err[m]       <= #TP send_aft_blk_f_err[m];
                    send_aft_blk_f_err[m]   <= #TP 0;
                end
                else begin
                    cfg_send_f_err[m]       <= #TP int_cfg_send_f_err[m];
                    send_aft_blk_f_err[m]   <= #TP 0;
                end
            end
        end // for loop


    end
end



// =============================================================================
// Legacy interrupt handling
reg [NF-1:0]    inta_wirei;
reg [NF-1:0]    intb_wirei;
reg [NF-1:0]    intc_wirei;
reg [NF-1:0]    intd_wirei;
wire            inta_wire;
wire            intb_wire;
wire            intc_wire;
wire            intd_wire;

assign inta_wire = |inta_wirei;
assign intb_wire = |intb_wirei;
assign intc_wire = |intc_wirei;
assign intd_wire = |intd_wirei;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin: latch_int_proc
integer k;
    if (!non_sticky_rst_n) begin
        inta_wirei  <= #TP 0;
        intb_wirei  <= #TP 0;
        intc_wirei  <= #TP 0;
        intd_wirei  <= #TP 0;
    end
    else begin
        // If there's only one function, only INTA is available
        if (NF == 1) begin
            intb_wirei[0]   <= #TP 0;
            intc_wirei[0]   <= #TP 0;
            intd_wirei[0]   <= #TP 0;
            if (sys_int[0])
                inta_wirei[0]   <= #TP !cfg_int_disable[0];
            else
                inta_wirei[0]   <= #TP 1'b0;
        end
        // Otherwise, it depends on the interrupt pin mapping register
        else begin
            for (k=0; k<NF; k=k+1) begin
                case (Bget(cfg_int_pin,k))
                    8'h01: inta_wirei[k]<= #TP sys_int[k] & !cfg_int_disable[k];
                    8'h02: intb_wirei[k]<= #TP sys_int[k] & !cfg_int_disable[k];
                    8'h03: intc_wirei[k]<= #TP sys_int[k] & !cfg_int_disable[k];
                    8'h04: intd_wirei[k]<= #TP sys_int[k] & !cfg_int_disable[k];
                    default: begin
                        inta_wirei[k]   <= #TP inta_wirei[k];
                        intb_wirei[k]   <= #TP intb_wirei[k];
                        intc_wirei[k]   <= #TP intc_wirei[k];
                        intd_wirei[k]   <= #TP intd_wirei[k];
                    end
                endcase
            end
        end
    end
end

// Function to grab a byte from a bus
function automatic [7:0] Bget;
input [(NF*8)-1:0]      vector;
input integer           index;
reg [PF_WD-1:0]        reg_index;
// LMD: Variable hides a variable in outer scope i
// LJ: This variable is intern to this block
// leda W121 off
integer i;
// leda W121 on
begin
    reg_index = index; 
    Bget = 0;
    for (i=0; i<8; i=i+1)
        Bget[i] = vector[(reg_index<<3)+i];
end
endfunction

assign cfg_pwr_budget_func_num = 0;
assign cfg_pwr_budget_data_reg = 0;


// -----------------------------------------------------------------------------
// Assignments
// -----------------------------------------------------------------------------
assign cfg_2nd_reset            = |int_cfg_2nd_reset;
assign cfg_soft_rst_n           = 1'b1;
assign cfg_hdr_type             = int_cfg_hdr_type[7:0];
assign cfg_link_rate            = int_cfg_link_rate[3:0];
assign cfg_retimers_pre_detected = int_cfg_retimers_pre_detected[1:0];
assign cfg_link_dis             = |int_link_dis; // When any function is disabled, core will go into disable
assign cfg_link_retrain         = |int_link_retrain;                                    // When any function is retrain, core will retrain
assign cfg_ext_synch            = |int_ext_synch;                                       // When any function is in extended sync, core in extended sync
assign cfg_l0s_supported        = (phy_type == `PHY_TYPE_MPCIE) ? 1'b0 : pf_cfg_pcie_aspm_cap_bus[0] ;      // Only bit 0 because same value for all funcs in multi-funcs
assign cfg_aslk_pmctrl          = (phy_type == `PHY_TYPE_MPCIE) ? cfg_aslk_pmctrl_mpcie : cfg_aslk_pmctrl_cpcie ;
assign cfg_aslk_pmctrl_cpcie    = int_cfg_aslk_pmctrl ;
assign cfg_aslk_pmctrl_mpcie    = {NF{2'b00}} ;   // Not Used in Conventional PCIe.

assign cfg_clk_pm_en            = &int_cfg_clk_pm_en;
assign cfg_comm_clk_config      = &int_cfg_comm_clk_config;         // When all functions use common clock, then we signal this (PCIe 1.1 C15 errata).
assign cfg_hw_autowidth_dis     =  int_cfg_hw_autowidth_dis[0];

assign cfg_upd_aslk_pmctrl       = (phy_type == `PHY_TYPE_MPCIE) ? cfg_upd_aslk_pmctrl_mpcie : int_cfg_upd_aslk_pmctrl ;
assign cfg_upd_aslk_pmctrl_mpcie = {NF{1'b0}} ;   // Not Used in Conventional PCIe.





// -----------------------------------------------------------------------------
// Local bus address decoding
// -----------------------------------------------------------------------------

wire [(64*FX_TLP)-1:0] flt_cdm_addr_int;
// when flt_cdm_addr is anticipated create a delayed version to be used
// in cdm_cfg_reg (for PFs). The anticipated version is only
// needed/supported by cdm_sriov_reg.
delay_n

#(1, (64*FX_TLP)) u_delay_n (.dout(flt_cdm_addr_int), .din(flt_cdm_addr), .clk(core_clk), .rst_n(non_sticky_rst_n), .clear(1'b0) );

cdm_reg_decode

#(
   .INST (INST)
) u_cdm_reg_decode (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .lbc_cdm_addr                   (lbc_cdm_addr),
    .lbc_cdm_cs                     (lbc_cdm_cs),
    .pl_reg_ack                     (pl_reg_ack),
    .pl_reg_data                    (pl_reg_data),
    .cfg_reg_ack                    (cfg_reg_ack),
    .cfg_reg_data                   (cfg_reg_data),
    .cfg_cap_reg_ack                (cfg_cap_reg_ack),
    .cfg_cap_reg_data               (cfg_cap_reg_data),
    .ecfg_reg_ack                   (ecfg_reg_ack),
    .ecfg_reg_data                  (ecfg_reg_data),



// ---------- Outputs --------
    .pl_reg_sel                     (pl_reg_sel),
    .cfg_reg_sel                    (cfg_reg_sel),
    .cfg_cap_reg_sel                (cfg_cap_reg_sel),
    .ecfg_reg_sel                   (ecfg_reg_sel),
    .cdm_pf_ecfg_addr               (cdm_pf_ecfg_addr),
    .lbc_cdm_dbi2                   ( lbc_cdm_dbi2    ),

    .cdm_lbc_data                   (cdm_lbc_data),
    .cdm_lbc_ack                    (cdm_lbc_ack)
); // cdm_reg_decode

wire [NF-1:0]               int_radm_snoop_upd;
wire [SNOOP_BUS_WD-1:0]     int_radm_snoop_bus_num;
wire [SNOOP_DEV_WD-1:0]     int_radm_snoop_dev_num;

assign cfg_pbus_num     = int_cfg_pbus_num[7:0];
assign cfg_pbus_dev_num = int_cfg_pbus_dev_num[4:0];

generate
  if(MULTI_DEVICE_AND_BUS_PER_FUNC) begin : gen_int_radm_snoop_upd
    assign int_radm_snoop_upd = radm_snoop_upd;
  end
  else begin : gen_int_radm_snoop_upd
    assign int_radm_snoop_upd = {{(NF-1){1'h0}}, radm_snoop_upd};
  end
endgenerate
assign int_radm_snoop_bus_num = radm_snoop_bus_num;
assign int_radm_snoop_dev_num = radm_snoop_dev_num;


genvar func;
generate
for (func=0; func<NF; func = func+1) begin : gen_cdm_reg
// -----------------------------------------------------------------------------
// Base Configuration Register Space
// -----------------------------------------------------------------------------

cdm_cfg_reg

#(.INST(INST), .FUNC_NUM(func)
)
u_cdm_cfg_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .device_type                    (device_type),
    .phy_type                       (phy_type),
    // Local Bus access
    .cfg_reg_sel                    (cfg_reg_sel[func]),
    .cfg_cap_reg_sel                (cfg_cap_reg_sel[func]),
    .ecfg_reg_sel                   (ecfg_reg_sel[func]),
    .lbc_cdm_addr                   (lbc_cdm_addr),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),


    .int_msg_pending                (sys_int[func]),

    .rdlh_link_up                   (rdlh_link_up),
    .smlh_link_up                   (smlh_link_up),
    .smlh_autoneg_link_width        (smlh_autoneg_link_width),
    .smlh_autoneg_link_sp           (smlh_autoneg_link_sp),
    .smlh_link_training_in_prog     (smlh_link_training_in_prog),
    .smlh_bw_mgt_status             (smlh_bw_mgt_status),
    .smlh_link_auto_bw_status       (smlh_link_auto_bw_status),
    .aux_pwr_det                    (sys_aux_pwr_det),
    .radm_cpl_pending               (radm_cpl_pending[func]),

    // Errors
    .cfg_f_err_det                  (cfg_f_err_det[func]),
    .cfg_nf_err_det                 (cfg_nf_err_det[func]),
    .cfg_cor_err_det                (cfg_cor_err_det[func]),
    .cfg_unsupt_req_det             (cfg_unsupt_req_det[func]),
    .cfg_rprt_err_cor               (cfg_rprt_err_cor[func]),                 // Function 0 Only
    .cfg_rprt_err_nf                (cfg_rprt_err_nf[func]),                 // Function 0 Only
    .cfg_rprt_err_f                 (cfg_rprt_err_f[func]),                   // Function 0 Only
    .master_data_perr_det           (master_data_perr_det[func]),
    .signaled_target_abort_det      (signaled_target_abort_det[func]),
    .rcvd_target_abort_det          (rcvd_target_abort_det[func]),
    .rcvd_master_abort_det          (rcvd_master_abort_det[func]),
    .signaled_sys_err_det           (signaled_sys_err_det[func]),
    .perr_det                       (perr_det[func]),
    .master_data_perr_det2          (master_data_perr_det2[func]),
    .signaled_target_abort_det2     (signaled_target_abort_det2[func]),
    .rcvd_target_abort_det2         (rcvd_target_abort_det2[func]),
    .rcvd_master_abort_det2         (rcvd_master_abort_det2[func]),
    .signaled_sys_err_det2          (signaled_sys_err_det2[func]),
    .perr_det2                      (perr_det2[func]),

    // MSG received
    .radm_correctable_err           (|radm_correctable_err[FX_TLP*(1+func)-1:FX_TLP*func]),
    .radm_nonfatal_err              (|radm_nonfatal_err[FX_TLP*(1+func)-1:FX_TLP*func]),
    .radm_fatal_err                 (|radm_fatal_err[FX_TLP*(1+func)-1:FX_TLP*func]),

    .sys_pre_det_state              (sys_pre_det_state[func]),
    .sys_mrl_sensor_state           (sys_mrl_sensor_state[func]),
    .sys_atten_button_pressed       (sys_atten_button_pressed[func]),
    .sys_pwr_fault_det              (sys_pwr_fault_det[func]),
    .sys_mrl_sensor_chged           (sys_mrl_sensor_chged[func]),
    .sys_pre_det_chged              (sys_pre_det_chged[func]),
    .sys_cmd_cpled_int              (sys_cmd_cpled_int[func]),
    .sys_eml_interlock_engaged      (sys_eml_interlock_engaged[func]),
    .radm_set_slot_pwr_limit        (int_radm_set_slot_pwr_limit[func]),
    .radm_slot_pwr_payload          (radm_slot_pwr_payload),
    .pm_status                      (pm_status[func]),
    .pm_pme_en                      (pm_pme_en[func]),
    .aux_pm_en                      (aux_pm_en[func]),
    .radm_pm_pme                    (radm_pm_pme[FX_TLP*(1+func)-1:FX_TLP*func]),
    .radm_msg_req_id                (radm_msg_req_id),


    .flt_cdm_addr                   (flt_cdm_addr_int),


    .rbar_ctrl_update               (rbar_ctrl_update[func]),
    .cfg_rbar_bar_resizable         (int_cfg_rbar_bar_resizable[6*(1+func)-1:6*func]),
    .cfg_rbar_bar0_mask             (int_cfg_rbar_bar0_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar1_mask             (int_cfg_rbar_bar1_mask[32*(1+func)-1:32*func]),
    .cfg_rbar_bar2_mask             (int_cfg_rbar_bar2_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar3_mask             (int_cfg_rbar_bar3_mask[32*(1+func)-1:32*func]),
    .cfg_rbar_bar4_mask             (int_cfg_rbar_bar4_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar5_mask             (int_cfg_rbar_bar5_mask[32*(1+func)-1:32*func]),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),

    .exp_rom_validation_status_strobe (exp_rom_validation_status_strobe[func] ),
    .exp_rom_validation_status        (exp_rom_validation_status[3*(1+func)-1:3*func]),
    .exp_rom_validation_details_strobe(exp_rom_validation_details_strobe[func]),
    .exp_rom_validation_details       (exp_rom_validation_details[4*(1+func)-1:4*func]),

    .radm_snoop_upd                 (int_radm_snoop_upd),
    .radm_snoop_bus_num             (int_radm_snoop_bus_num),
    .radm_snoop_dev_num             (int_radm_snoop_dev_num),
    .rdlh_dlcntrl_state             (rdlh_dlcntrl_state),     // input [1:0]
    .app_clk_pm_en                  (app_clk_pm_en),
    .cfg_config_limit               (cfg_config_limit),
    .app_dev_num                    (app_dev_num),
    .app_bus_num                    (app_bus_num),

// ---------- Outputs --------
    .cfg_upd_pme_cap                (cfg_upd_pme_cap[func]),
    .cfg_mem_match                  (cfg_mem_match[FX_TLP*(1+func)-1:FX_TLP*func]),
    .cfg_prefmem_match              (cfg_prefmem_match[FX_TLP*(1+func)-1:FX_TLP*func]),
    .cfg_io_match                   (cfg_io_match[FX_TLP*(1+func)-1:FX_TLP*func]),
    .cfg_config_above_match         (cfg_config_above_match[FX_TLP*(1+func)-1:FX_TLP*func]),
    .cfg_bar_match                  (cfg_bar_match[6*FX_TLP*(1+func)-1:6*FX_TLP*func]),
    .cfg_bar_is_io                  (cfg_bar_is_io[6*(1+func)-1:6*func]),
    .cfg_rom_match                  (cfg_rom_match[FX_TLP*(1+func)-1:FX_TLP*func]),
    .cfg_br_ctrl_serren             (cfg_br_ctrl_serren[func]),
    .cfg_br_ctrl_perren             (cfg_br_ctrl_perren[func]),
    .cfg_bus_master_en              (cfg_bus_master_en[func]),
    .cfg_reg_perren                 (cfg_reg_perren[func]),
    .cfg_reg_serren                 (cfg_reg_serren[func]),
    .cfg_sys_err_rc                 (int_cfg_sys_err_rc[func]),  // Function 0 Only
    .cfg_crs_sw_vis_en              (int_cfg_crs_sw_vis_en[func]),  // Function 0 Only
    .cfg_pme_int                    (int_cfg_pme_int[func]),     // Function 0 Only
    .cfg_pme_msi                    (int_cfg_pme_msi[func]),     // Function 0 Only
    .cfg_2nd_reset                  (int_cfg_2nd_reset[func]),
    .cfg_slot_pwr_limit_wr          (cfg_slot_pwr_limit_wr[func]),
    .cfg_pcie_slot_pwr_limit        (cfg_pcie_slot_pwr_limit[10*(1+func)-1:10*func]),
    .cfg_multi_msi_en               (cfg_multi_msi_en[3*(1+func)-1:3*func]),
    .cfg_msi_ext_data_en            (cfg_msi_ext_data_en[func]),
    .cfg_msi_en                     (cfg_msi_en[func]),
    .cfg_msi_addr                   (cfg_msi_addr[64*(1+func)-1:64*func]),
    .cfg_msi_data                   (cfg_msi_data[32*(1+func)-1:32*func]),
    .cfg_msi_64                     (cfg_msi_64[func]),
    .cfg_msix_en                    (cfg_msix_en[func]),
    .cfg_msix_func_mask             (cfg_msix_func_mask[func]),
    .cfg_msix_table_size            (cfg_msix_table_size[11*(1+func)-1:11*func]),
    .cfg_msix_table_size2           (cfg_msix_table_size2[11*(1+func)-1:11*func]),
    .cfg_msix_table_bir             (cfg_msix_table_bir[3*(1+func)-1:3*func]),
    .cfg_msix_table_bir2            (cfg_msix_table_bir2[3*(1+func)-1:3*func]),
    .cfg_msix_table_offset          (cfg_msix_table_offset[29*(1+func)-1:29*func]),
    .cfg_msix_table_offset2         (cfg_msix_table_offset2[29*(1+func)-1:29*func]),
    .cfg_msix_pba_bir               (cfg_msix_pba_bir[3*(1+func)-1:3*func]),
    .cfg_msix_pba_bir2              (cfg_msix_pba_bir2[3*(1+func)-1:3*func]),
    .cfg_msix_pba_offset            (cfg_msix_pba_offset[29*(1+func)-1:29*func]),
    .cfg_msix_pba_offset2           (cfg_msix_pba_offset2[29*(1+func)-1:29*func]),
    .cfg_vpd_int                    (cfg_vpd_int[func]),
    .cfg_max_payload_size           (cfg_max_payload_size[3*(1+func)-1:3*func]),
    .cfg_relax_ord_en               (cfg_relax_ord_en[func]),
    .cfg_ext_tag_en                 (cfg_ext_tag_en[func]),
    .cfg_phantom_fun_en             (cfg_phantom_fun_en[func]),
    .cfg_no_snoop_en                (cfg_no_snoop_en[func]),
    .cfg_max_rd_req_size            (cfg_max_rd_req_size[3*(1+func)-1:3*func]),
    .cfg_bridge_crs_en              (cfg_bridge_crs_en[func]),
    .cfg_aslk_pmctrl                (int_cfg_aslk_pmctrl[2*(1+func)-1:2*func]),
    .cfg_upd_aslk_pmctrl            (int_cfg_upd_aslk_pmctrl[func]),
    .cfg_clk_pm_en                  (int_cfg_clk_pm_en[func]),
    .cfg_rcb                        (cfg_rcb[func]),
    .cfg_link_dis                   (int_link_dis[func]),
    .cfg_link_retrain               (int_link_retrain[func]),
    .cfg_comm_clk_config            (int_cfg_comm_clk_config[func]),
    .cfg_hw_autowidth_dis           (int_cfg_hw_autowidth_dis[func]),
    .cfg_link_rate                  (int_cfg_link_rate[4*(1+func)-1:4*func]),
    .cfg_retimers_pre_detected      (int_cfg_retimers_pre_detected[2*(1+func)-1:2*func]),
    .cfg_pwr_ind                    (cfg_pwr_ind[2*(1+func)-1:2*func]),
    .cfg_atten_ind                  (cfg_atten_ind[2*(1+func)-1:2*func]),
    .cfg_pwr_ctrler_ctrl            (cfg_pwr_ctrler_ctrl[func]),
    .cfg_hp_int_en                  (cfg_hp_int_en[func]),
    .cfg_atten_button_pressed       (cfg_atten_button_pressed[func]),
    .cfg_eml_control                (cfg_eml_control[func]),
    .cfg_pwr_fault_det              (cfg_pwr_fault_det[func]),
    .cfg_mrl_sensor_chged           (cfg_mrl_sensor_chged[func]),
    .cfg_pre_det_chged              (cfg_pre_det_chged[func]),
    .cfg_cmd_cpled_int              (cfg_cmd_cpled_int[func]),
    .cfg_dll_state_chged            (cfg_dll_state_chged[func]),
    .cfg_int_disable                (cfg_int_disable[func]),
    .cfg_cor_err_rpt_en             (cfg_cor_err_rpt_en[func]),
    .cfg_nf_err_rpt_en              (cfg_nf_err_rpt_en[func]),
    .cfg_f_err_rpt_en               (cfg_f_err_rpt_en[func]),
    .cfg_unsupt_req_rpt_en          (cfg_unsupt_req_rpt_en[func]),
    .cfg_pbus_num                   (int_cfg_pbus_num[8*(1+func)-1:8*func]),
    .cfg_2ndbus_num                 (cfg_2ndbus_num[8*(1+func)-1:8*func]),
    .cfg_subbus_num                 (cfg_subbus_num[8*(1+func)-1:8*func]),
    .cfg_pbus_dev_num               (int_cfg_pbus_dev_num[5*(1+func)-1:5*func]),
    .cfg_bar0_start                 (cfg_bar0_start[64*(1+func)-1:64*func]),
    .cfg_bar0_limit                 (cfg_bar0_limit[64*(1+func)-1:64*func]),
    .cfg_bar1_start                 (cfg_bar1_start[32*(1+func)-1:32*func]),
    .cfg_bar1_limit                 (cfg_bar1_limit[32*(1+func)-1:32*func]),
    .cfg_bar2_start                 (cfg_bar2_start[64*(1+func)-1:64*func]),
    .cfg_bar2_limit                 (cfg_bar2_limit[64*(1+func)-1:64*func]),
    .cfg_bar3_start                 (cfg_bar3_start[32*(1+func)-1:32*func]),
    .cfg_bar3_limit                 (cfg_bar3_limit[32*(1+func)-1:32*func]),
    .cfg_bar4_start                 (cfg_bar4_start[64*(1+func)-1:64*func]),
    .cfg_bar4_limit                 (cfg_bar4_limit[64*(1+func)-1:64*func]),
    .cfg_bar5_start                 (cfg_bar5_start[32*(1+func)-1:32*func]),
    .cfg_bar5_limit                 (cfg_bar5_limit[32*(1+func)-1:32*func]),
    .cfg_bar0_mask                  (cfg_bar0_mask[64*(1+func)-1:64*func]),
    .cfg_bar1_mask                  (cfg_bar1_mask[32*(1+func)-1:32*func]),
    .cfg_bar2_mask                  (cfg_bar2_mask[64*(1+func)-1:64*func]),
    .cfg_bar3_mask                  (cfg_bar3_mask[32*(1+func)-1:32*func]),
    .cfg_bar4_mask                  (cfg_bar4_mask[64*(1+func)-1:64*func]),
    .cfg_bar5_mask                  (cfg_bar5_mask[32*(1+func)-1:32*func]),
    .cfg_rom_mask                   (cfg_rom_mask[32*(1+func)-1:32*func]),
    .cfg_mem_base                   (cfg_mem_base[16*(1+func)-1:16*func]),
    .cfg_mem_limit                  (cfg_mem_limit[16*(1+func)-1:16*func]),
    .cfg_pref_mem_base              (cfg_pref_mem_base[64*(1+func)-1:64*func]),
    .cfg_pref_mem_limit             (cfg_pref_mem_limit[64*(1+func)-1:64*func]),
    .cfg_exp_rom_start              (cfg_exp_rom_start[32*(1+func)-1:32*func]),
    .cfg_exp_rom_limit              (cfg_exp_rom_limit[32*(1+func)-1:32*func]),
    .cfg_io_limit_upper16           (cfg_io_limit_upper16[16*(1+func)-1:16*func]),
    .cfg_io_base_upper16            (cfg_io_base_upper16[16*(1+func)-1:16*func]),
    .cfg_io_base                    (cfg_io_base[8*(1+func)-1:8*func]),
    .cfg_io_limit                   (cfg_io_limit[8*(1+func)-1:8*func]),
    .cfg_hdr_type                   (int_cfg_hdr_type[8*(1+func)-1:8*func]),
    .cfg_ext_synch                  (int_ext_synch[func]),
    .cfg_io_space_en                (cfg_io_space_en[func]),
    .cfg_mem_space_en               (cfg_mem_space_en[func]),

    .cfg_cap_reg_ack                (cfg_cap_reg_ack[func]),
    .cfg_cap_reg_data               (cfg_cap_reg_data[32*(1+func)-1:32*func]),
    .cfg_reg_data                   (cfg_reg_data[32*(1+func)-1:32*func]),
    .cfg_reg_ack                    (cfg_reg_ack[func]),
    .cfg_upd_pmcsr                  (cfg_upd_pmcsr[func]),
    .cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en[func]),
    .cfg_upd_req_id                 (cfg_upd_req_id[func]),
    .cfg_aux_pm_en                  (cfg_aux_pm_en[func]),
    .cfg_pmstatus_clr               (cfg_pmstatus_clr[func]),
    .cfg_pmstate                    (cfg_pmstate[3*(1+func)-1:3*func]),
    .cfg_pme_en                     (cfg_pme_en[func]),
    .cfg_pme_cap                    (cfg_pme_cap[5*(1+func)-1:5*func]),
    .cfg_pm_no_soft_rst             (cfg_pm_no_soft_rst[func]),
    .cfg_isa_enable                 (cfg_isa_enable[func]),
    .cfg_vga_enable                 (cfg_vga_enable[func]),
    .cfg_vga16_decode               (cfg_vga16_decode[func]),
    .cfg_int_pin                    (cfg_int_pin[8*(1+func)-1:8*func]),
    .cfg_link_auto_bw_int           (int_cfg_link_auto_bw_int[func]),                       // Function 0 Only
    .cfg_link_auto_bw_msi           (int_cfg_link_auto_bw_msi[func]),                       // Function 0 Only
    .cfg_bw_mgt_int                 (int_cfg_bw_mgt_int[func]),                             // Function 0 Only
    .cfg_bw_mgt_msi                 (int_cfg_bw_mgt_msi[func]),                             // Function 0 Only
    .cfg_pcie_max_link_speed        (pf_cfg_pcie_max_link_speed_bus[4*(1+func)-1:4*func]),
//    .target_mem_map                 (target_mem_map[6*(1+func)-1:6*func]),
//    .target_rom_map                 (target_rom_map[func]),

    .cfg_pcie_aspm_cap              (pf_cfg_pcie_aspm_cap_bus[2*(1+func)-1:2*func]),



    .cfg_pcie_cap_int_msg_num       (cfg_pcie_cap_int_msg_num[5*(1+func)-1:5*func]),
    .cfg_cpl_timeout_disable        (cfg_cpl_timeout_disable[func])

    ,
    .cfg_pcie_surp_dn_rpt_cap        (cfg_pcie_surp_dn_rpt_cap[func])

    ,
    .cfg_pcie_slot_clk_config        (cfg_pcie_slot_clk_config_i[func]),
    .cfg_auto_slot_pwr_lmt_dis       (cfg_auto_slot_pwr_lmt_dis[func]), 
    .cfg_hp_slot_ctrl_access         (cfg_hp_slot_ctrl_access[func]),
    .cfg_dll_state_chged_en          (cfg_dll_state_chged_en[func]), 
    .cfg_cmd_cpled_int_en_r          (cfg_cmd_cpled_int_en[func]), 
    .cfg_pre_det_chged_en            (cfg_pre_det_chged_en[func]), 
    .cfg_mrl_sensor_chged_en_r       (cfg_mrl_sensor_chged_en[func]), 
    .cfg_pwr_fault_det_en_r          (cfg_pwr_fault_det_en[func]), 
    .cfg_atten_button_pressed_en_r   (cfg_atten_button_pressed_en[func])

); // cdm_cfg_reg

// -----------------------------------------------------------------------------
// Extended PCIE config registers
// -----------------------------------------------------------------------------

cdm_ecfg_reg

#(.INST(INST), .FUNC_NUM(func), .NPTMVSEC(NPTMVSEC)
)
u_cdm_ecfg_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .device_type                    (device_type),
    .phy_type                       (phy_type),
    .lbc_cdm_addr                   (cdm_pf_ecfg_addr[15:0]),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),
    .ecfg_reg_sel                   (ecfg_reg_sel[func]),
    .err_reg_data                   (err_reg_data[32*(1+func)-1:32*func]),
    .rtlh_fc_init_status            (rtlh_fc_init_status),
    .cfg_pwr_budget_data_reg        (cfg_pwr_budget_data_reg),
    .cfg_pwr_budget_func_num        (cfg_pwr_budget_func_num),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),





    .upstream_port                  (upstream_port),


// ---------- Outputs --------
    .ecfg_reg_data                  (ecfg_reg_data[32*(1+func)-1:32*func]),
    .ecfg_reg_ack                   (ecfg_reg_ack[func]),
    .ecfg_write_pulse               (ecfg_write_pulse[4*(1+func)-1:4*func]),
    .ecfg_read_pulse                (ecfg_read_pulse[func]),
    .err_reg_id                     (err_reg_id[18*(1+func)-1:18*func]),


    .cfg_vc_enable                  (int_cfg_vc_enable[NVC*(1+func)-1:NVC*func]),               // Function 0 Only
    .cfg_vc_struc_vc_id_map         (int_cfg_vc_struc_vc_id_map[NVC*3*(1+func)-1:NVC*3*func]),  // Function 0 Only
    .cfg_vc_id_vc_struc_map         (int_cfg_vc_id_vc_struc_map[24*(1+func)-1:24*func]),        // Function 0 Only
    .cfg_tc_enable                  (int_cfg_tc_enable[8*(1+func)-1:8*func]),                   // Function 0 Only
    .cfg_tc_vc_map                  (int_cfg_tc_vc_map[24*(1+func)-1:24*func]),                 // Function 0 Only
    .cfg_tc_vc_struc_map            (int_cfg_tc_struc_vc_map[24*(1+func)-1:24*func]),           // Function 0 Only
    .cfg_lpvc                       (int_cfg_lpvc[3*(1+func)-1:3*func]),                        // Function 0 Only
    .cfg_vc_arb_sel                 (int_cfg_vc_arb_sel[3*(1+func)-1:3*func]),                  // Function 0 Only
    .cfg_pwr_budget_data_sel_reg    (int_cfg_pwr_budget_data_sel_reg[8*(1+func)-1:8*func]),
    .cfg_pwr_budget_sel             (cfg_pwr_budget_sel[func]),
    .cfg_rbar_bar_resizable         (int_cfg_rbar_bar_resizable[6*(1+func)-1:6*func]),
    .cfg_rbar_bar0_mask             (int_cfg_rbar_bar0_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar1_mask             (int_cfg_rbar_bar1_mask[32*(1+func)-1:32*func]),
    .cfg_rbar_bar2_mask             (int_cfg_rbar_bar2_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar3_mask             (int_cfg_rbar_bar3_mask[32*(1+func)-1:32*func]),
    .cfg_rbar_bar4_mask             (int_cfg_rbar_bar4_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar5_mask             (int_cfg_rbar_bar5_mask[32*(1+func)-1:32*func]),
    .cfg_vf_rbar_bar_resizable      (int_cfg_vf_rbar_bar_resizable[6*(1+func)-1:6*func]),
    .cfg_vf_rbar_bar0_mask          (int_cfg_vf_rbar_bar0_mask[64*(1+func)-1:64*func]),
    .cfg_vf_rbar_bar1_mask          (int_cfg_vf_rbar_bar1_mask[32*(1+func)-1:32*func]),
    .cfg_vf_rbar_bar2_mask          (int_cfg_vf_rbar_bar2_mask[64*(1+func)-1:64*func]),
    .cfg_vf_rbar_bar3_mask          (int_cfg_vf_rbar_bar3_mask[32*(1+func)-1:32*func]),
    .cfg_vf_rbar_bar4_mask          (int_cfg_vf_rbar_bar4_mask[64*(1+func)-1:64*func]),
    .cfg_vf_rbar_bar5_mask          (int_cfg_vf_rbar_bar5_mask[32*(1+func)-1:32*func])



    ,
    .rbar_ctrl_update               (rbar_ctrl_update[func]),
    .cfg_rbar_size                  (cfg_rbar_size[func*6*6 +: 6*6]),
    .vf_rbar_ctrl_update            (vf_rbar_ctrl_update[func]),
    .cfg_vf_rbar_size               (cfg_vf_rbar_size[func*6*6 +: 6*6])


); // cdm_ecfg_reg


// -----------------------------------------------------------------------------
// cdm_error_reg instantiation
// -----------------------------------------------------------------------------

cdm_error_reg

#(.INST(INST), .FUNC_NUM(func))
u_cdm_error_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .device_type                    (device_type),
    .phy_type                       (phy_type),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .err_write_pulse                (ecfg_write_pulse[4*(1+func)-1:4*func]),
    .err_read_pulse                 (ecfg_read_pulse[func]),
    .err_reg_id                     (err_reg_id[18*(1+func)-1:18*func]),
    .pm_bus_num                     (int_cfg_pbus_num[7:0]),
    .pm_dev_num                     (int_cfg_pbus_dev_num[4:0]),
    .cfg_int_disable                (cfg_int_disable[func]),
    .cfg_msi_en                     (cfg_msi_en[func]),
    .cfg_msix_en                    (cfg_msix_en[func]),
    .cfg_br_ctrl_serren             (cfg_br_ctrl_serren[func]),
    .cfg_br_ctrl_perren             (cfg_br_ctrl_perren[func]),
    .cfg_reg_perren                 (cfg_reg_perren[func]),
    .cfg_reg_serren                 (cfg_reg_serren[func]),
    .cfg_cor_err_rpt_en             (cfg_cor_err_rpt_en[func]),
    .cfg_nf_err_rpt_en              (cfg_nf_err_rpt_en[func]),
    .cfg_f_err_rpt_en               (cfg_f_err_rpt_en[func]),
    .cfg_unsupt_req_rpt_en          (cfg_unsupt_req_rpt_en[func]),
    .cdm_err_advisory               (int_err_advisory),
    .rtlh_fc_prot_err               (int_rtlh_fc_prot_err),
    .rtlh_overfl_err                (cdm_rcvr_overflow[func]),
    .internal_err                   (cdm_internal_err[func]),
    .corr_internal_err              (cdm_corr_internal_err[func]),
    .radm_rcvd_cpl_poisoned         (radm_rcvd_cpl_poisoned[func]),
    .radm_rcvd_wreq_poisoned        (cdm_rcvd_wreq_poisoned[func]),
    .radm_cpl_timeout_err           (cdm_cpl_timeout[func]),
    .radm_mlf_tlp_err               (cdm_mlf_tlp_err[func]),
    .radm_ecrc_err                  (cdm_ecrc_err),
    .radm_rcvd_req_ur               (cdm_rcvd_req_ur[func]),
    .radm_rcvd_req_ca               (cdm_rcvd_req_ca[func]),
    .radm_unexp_cpl_err             (cdm_unexp_cpl_err[func]),
    .radm_rcvd_cpl_ur               (radm_rcvd_cpl_ur[func]),
    .radm_rcvd_cpl_ca               (radm_rcvd_cpl_ca[func]),
    .radm_hdr_log_valid             (cdm_hdr_log_valid[func]),
    .radm_correctable_err           (radm_correctable_err[func]),
    .radm_nonfatal_err              (radm_nonfatal_err[func]),
    .radm_fatal_err                 (radm_fatal_err[func]),
    .rmlh_rcvd_err                  (rmlh_rcvd_err),
    .rdlh_prot_err                  (rdlh_prot_err),
    .rdlh_bad_tlp_err               (rdlh_bad_tlp_err),
    .rdlh_bad_dllp_err              (rdlh_bad_dllp_err),
    .xdlh_replay_num_rlover_err     (xdlh_replay_num_rlover_err),
    .xdlh_replay_timeout_err        (xdlh_replay_timeout_err),
    .lbc_xmt_cpl_ca                 (lbc_xmt_cpl_ca[func]),
    .xal_rcvd_cpl_ca                (xal_rcvd_cpl_ca[func]),
    .xal_rcvd_cpl_ur                (xal_rcvd_cpl_ur[func]),
    .xal_xmt_cpl_ca                 (xal_xmt_cpl_ca[func]),
    .xal_perr                       (xal_perr[func]),
    .xal_serr                       (xal_serr[func]),
    .xal_set_trgt_abort_primary     (xal_set_trgt_abort_primary[func]),
    .xal_set_mstr_abort_primary     (xal_set_mstr_abort_primary[func]),
    .xal_pci_addr_perr              (xal_pci_addr_perr[func]),
    .xtlh_xmt_wreq_poisoned         (xtlh_xmt_wreq_poisoned[func]),
    .xtlh_xmt_cpl_poisoned          (xtlh_xmt_cpl_poisoned[func]),
    .xtlh_xmt_cpl_ca                (xtlh_xmt_cpl_ca[func]),
    .xtlh_xmt_cpl_ur                (xtlh_xmt_cpl_ur[func]),

    .radm_hdr_log                   (cdm_hdr_log),
    .radm_msg_req_id                (radm_msg_req_id),

    // PF settings used by VFs, unused by PFs so tie to zero
    .pf_cfg_aer_uncorr_mask         (32'b0), // aer && vf
    .pf_cfg_aer_uncorr_svrity       (32'b0), // aer && vf
    .pf_cfg_aer_corr_mask           (32'b0), // aer && vf
    .pf_multi_hdr_rec_en            (1'b0), // aer && vf
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .cfg_pcie_surp_dn_rpt_cap       (cfg_pcie_surp_dn_rpt_cap[func]),
    .cfg_ecrc_chk_en                (cfg_ecrc_chk_en),
    .cfg_p2p_err_rpt_ctrl           (cfg_p2p_err_rpt_ctrl),

// ---------- Outputs --------
    .ecrc_gen_en                    (cfg_ecrc_gen_en[func]),
    .ecrc_chk_en                    (cfg_ecrc_chk_en[func]),
    .err_reg_data                   (err_reg_data[32*(1+func)-1:32*func]),
    .cfg_send_cor_err               (int_cfg_send_cor_err[func]),
    .cfg_send_nf_err                (int_cfg_send_nf_err[func]),
    .cfg_send_f_err                 (int_cfg_send_f_err[func]),
    .cfg_func_spec_err              (int_cfg_func_spec_err[3*(1+func)-1:3*func]),   // Function 0 Only
    .cfg_aer_rc_err_int             (int_cfg_aer_rc_err_int[func]),                 // Function 0 Only
    .cfg_aer_rc_err_msi             (int_cfg_aer_rc_err_msi[func]),                 // Function 0 Only
    .cfg_aer_int_msg_num            (cfg_aer_int_msg_num[5*(1+func)-1:5*func]),
    .cfg_rprt_err_cor               (cfg_rprt_err_cor[func]),                 // Function 0 Only
    .cfg_rprt_err_nf                (cfg_rprt_err_nf[func]),                  // Function 0 Only
    .cfg_rprt_err_f                 (cfg_rprt_err_f[func]),                   // Function 0 Only
    .cfg_f_err_det                  (cfg_f_err_det[func]),
    .cfg_nf_err_det                 (cfg_nf_err_det[func]),
    .cfg_cor_err_det                (cfg_cor_err_det[func]),
    .cfg_unsupt_req_det             (cfg_unsupt_req_det[func]),
    .master_data_perr_det           (master_data_perr_det[func]),
    .signaled_target_abort_det      (signaled_target_abort_det[func]),
    .rcvd_target_abort_det          (rcvd_target_abort_det[func]),
    .rcvd_master_abort_det          (rcvd_master_abort_det[func]),
    .signaled_sys_err_det           (signaled_sys_err_det[func]),
    .perr_det                       (perr_det[func]),
    .master_data_perr_det2          (master_data_perr_det2[func]),
    .signaled_target_abort_det2     (signaled_target_abort_det2[func]),
    .rcvd_target_abort_det2         (rcvd_target_abort_det2[func]),
    .rcvd_master_abort_det2         (rcvd_master_abort_det2[func]),
    .signaled_sys_err_det2          (signaled_sys_err_det2[func]),
    .perr_det2                      (perr_det2[func]),

    // PF settings exported to VFs
    .cfg_aer_uncorr_mask            (pf_cfg_aer_uncorr_mask_bus  [32*(1+func)-1:32*func]), // aer && pf
    .cfg_aer_uncorr_svrity          (pf_cfg_aer_uncorr_svrity_bus[32*(1+func)-1:32*func]), // aer && pf
    .cfg_aer_corr_mask              (pf_cfg_aer_corr_mask_bus    [32*(1+func)-1:32*func]), // aer && pf
    .multi_hdr_rec_en               (pf_multi_hdr_rec_en_bus [func]) // aer && pf
    ,
    .cfg_uncor_internal_err_sts         (cfg_uncor_internal_err_sts_int[func]        ),
    .cfg_rcvr_overflow_err_sts          (cfg_rcvr_overflow_err_sts_int[func]         ),
    .cfg_fc_protocol_err_sts            (cfg_fc_protocol_err_sts_int[func]           ),
    .cfg_mlf_tlp_err_sts                (cfg_mlf_tlp_err_sts_int[func]               ),
    .cfg_surprise_down_er_sts           (cfg_surprise_down_er_sts_int[func]          ),
    .cfg_dl_protocol_err_sts            (cfg_dl_protocol_err_sts_int[func]           ),
    .cfg_ecrc_err_sts                   (cfg_ecrc_err_sts_int[func]                  ),
    .cfg_corrected_internal_err_sts     (cfg_corrected_internal_err_sts_int[func]    ),
    .cfg_replay_number_rollover_err_sts (cfg_replay_number_rollover_err_sts_int[func]),
    .cfg_replay_timer_timeout_err_sts   (cfg_replay_timer_timeout_err_sts_int[func]  ),
    .cfg_bad_dllp_err_sts               (cfg_bad_dllp_err_sts_int[func]              ),
    .cfg_bad_tlp_err_sts                (cfg_bad_tlp_err_sts_int[func]               ),
    .cfg_rcvr_err_sts                   (cfg_rcvr_err_sts_int[func]                  )
); // cdm_error_reg









end // for (func=0; func<NF; func = func+1) begin : gen_cdm_reg
endgenerate


















wire   [NL*5-1:0]        rmlh_deskew_ctlskp_err = 0;


// the following signals are only for gen5 configs
wire                     smlh_ls2_g5_eq_req = 0;       // g5 Equalization request, no cap reg defined for V5.0 R0.3
wire  [3:1]              smlh_ls2_g5_eq_success = 0;   // g5 Equalization Successful {Phase 3, Phase 2, Phase 1}, no cap reg defined for V5.0 R0.3
wire                     smlh_ls2_g5_eq_cmpl = 0;      // g5 Equalization Complete, no cap reg defined for V5.0 R0.3
wire                     smlh_ls2_g5_eq_enter = 0;     // g5 Equalization Entered
wire [NL*TX_PSET_WD-1:0] smlh_lec_g5_pset_ltx = 0;     // g5 Latest Transmitter Preset requested from Upstream Component (Not applicable to RC/SW_DW), no cap reg defined for V5.0 R0.3
wire [NL*RX_PSET_WD-1:0] smlh_lec_g5_pset_lrx = 0;     // g5 Latest Receiver Preset requested from Upstream Component (Not applicable to RC/SW_DW), no cap reg defined for V5.0 R0.3
wire [1:0]               smlh_elbc_rcvd = 0;           // g5 Received Enhanced Link Behavior Control
wire                     smlh_tx_precoding_on = 0;     // g5 Transmitter Precoding On
wire                     smlh_noeq_needed_rcvd = 0;    // g5 no eq needed received
wire                     cfg_pl_gen5_det_eq_problem = 0;

assign cfg_alt_protocol_enable = 1'b0;






// -----------------------------------------------------------------------------
// PL registers
// Note: some register are only used for L2+L1 package without cfgm_cfg_reg module
// they are duplicated at PCI-E config space
// -----------------------------------------------------------------------------
cdm_pl_reg

#(
  .INST (INST),
  .FUNC_NUM(0)
  ) u_cdm_pl_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .sticky_rst_n                   (sticky_rst_n),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .phy_type                       (phy_type),
    .app_dbi_ro_wr_disable          (app_dbi_ro_wr_disable),
    .lbc_cdm_addr                   (lbc_cdm_addr[11:0]),
    .pl_reg_sel                     (pl_reg_sel),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .upstream_port                  (upstream_port),
    .phy_cfg_status                 (phy_cfg_status),
    .cxpl_debug_info                (cxpl_debug_info),
    .smlh_autoneg_link_width        (smlh_autoneg_link_width),
    .cfg_max_payload_size           (cfg_highest_max_payload),
    .cfg_min_payload_size           (cfg_smallest_max_payload),
    .cfg_comm_clk_config            (cfg_comm_clk_config),
    .xtlh_xadm_ph_cdts              (xtlh_xadm_ph_cdts),
    .xtlh_xadm_pd_cdts              (xtlh_xadm_pd_cdts),
    .xtlh_xadm_nph_cdts             (xtlh_xadm_nph_cdts),
    .xtlh_xadm_npd_cdts             (xtlh_xadm_npd_cdts),
    .xtlh_xadm_cplh_cdts            (xtlh_xadm_cplh_cdts),
    .xtlh_xadm_cpld_cdts            (xtlh_xadm_cpld_cdts),
    .radm_qoverflow                 (radm_qoverflow),
    .radm_q_not_empty               (radm_q_not_empty),
    .xdlh_retrybuf_not_empty        (xdlh_retrybuf_not_empty),
    .rtlh_crd_not_rtn               (rtlh_crd_not_rtn),



    .smlh_dir_linkw_chg_rising_edge (smlh_dir_linkw_chg_rising_edge),

//`ifdef CX_GEN2_SPEED
    .current_data_rate              (current_data_rate),
//`endif

    .cfg_ext_synch                  (cfg_ext_synch),

    .app_dev_num                    (app_dev_num),
    .app_bus_num                    (app_bus_num),

// ---------- Outputs --------

    .cfg_pl_multilane_control       (cfg_pl_multilane_control),
    .cfg_pl_l1_nowait_p1            (cfg_pl_l1_nowait_p1),
    .cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel),
    .cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset),
    .cfg_phy_rst_timer              (cfg_phy_rst_timer),
    .cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer),
    .cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq),
    .cfg_lane_en                    (cfg_lane_en),
    .cfg_gen1_ei_inference_mode     (cfg_gen1_ei_inference_mode),
    .cfg_select_deemph_mux_bus      (cfg_select_deemph_mux_bus),
    .cfg_lut_ctrl                   (cfg_lut_ctrl),
    .cfg_rxstandby_control          (cfg_rxstandby_control),
    .cfg_link_dis                   (),
    .cfg_link_rate                  (),
    .cfg_ack_freq                   (cfg_ack_freq),
    .cfg_ack_latency_timer          (cfg_ack_latency_timer),
    .cfg_replay_timer_value         (cfg_replay_timer_value),
    .cfg_fc_latency_value           (cfg_fc_latency_value ),
    .cfg_other_msg_payload          (cfg_other_msg_payload),
    .cfg_other_msg_request          (cfg_other_msg_request),
    .cfg_corrupt_crc_pattern        (cfg_corrupt_crc_pattern),
    .cfg_scramble_dis               (cfg_scramble_dis),
    .cfg_n_fts                      (cfg_n_fts),
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_pipe_loopback              (cfg_pipe_loopback),
    .cfg_rxstatus_lane              (cfg_rxstatus_lane),
    .cfg_rxstatus_value             (cfg_rxstatus_value),
    .cfg_lpbk_rxvalid               (cfg_lpbk_rxvalid),
    .cfg_plreg_reset                (cfg_plreg_reset),
    .cfg_link_num                   (cfg_link_num),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_forced_link_state          (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd           (cfg_forced_ltssm_cmd),

    .cfg_force_en                   (cfg_force_en),
    .cfg_lane_skew                  (cfg_lane_skew),
    .cfg_deskew_disable             (cfg_deskew_disable),
    .cfg_imp_num_lanes              (cfg_imp_num_lanes),
    .cfg_flow_control_disable       (cfg_flow_control_disable),
    .cfg_acknack_disable            (cfg_acknack_disable),
    .cfg_link_capable               (cfg_link_capable),
    .cfg_xmt_beacon                 (),
    .cfg_tx_reverse_lanes           (cfg_tx_reverse_lanes),
    .cfg_eidle_timer                (cfg_eidle_timer),
    .cfg_skip_interval              (cfg_skip_interval),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_fast_link_scaling_factor   (cfg_fast_link_scaling_factor),
    .cfg_dll_lnk_en                 (cfg_dll_lnk_en),
    .pl_reg_data                    (pl_reg_data),
    .pl_reg_ack                     (pl_reg_ack),
    .cfg_phy_control                (cfg_phy_control),
    .cfg_l0s_entr_latency_timer     (cfg_l0s_entr_latency_timer),
    .cfg_upd_aspm_ctrl              (cfg_upd_aspm_ctrl),
    .cfg_l1_entr_latency_timer      (cfg_l1_entr_latency_timer),
    .cfg_l1_entr_wo_rl0s            (cfg_l1_entr_wo_rl0s),
    .cfg_filter_rule_mask           (cfg_filter_rule_mask),
    .cfg_fc_wdog_disable            (cfg_fc_wdog_disable),
    .cfg_lpvc_wrr_weight            (cfg_lpvc_wrr_weight),
    .cfg_max_func_num               (cfg_max_func_num),
    .cfg_fc_credit_ph               (cfg_fc_credit_ph),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld),
    .cfg_radm_q_mode                (cfg_radm_q_mode),
    .cfg_radm_order_rule            (cfg_radm_order_rule),
    .cfg_order_rule_ctrl            (cfg_order_rule_ctrl),
    .cfg_clock_gating_ctrl          (cfg_clock_gating_ctrl),
    .cfg_trgt_cpl_lut_delete_entry  (cfg_trgt_cpl_lut_delete_entry),
    .cfg_radm_strict_vc_prior       (cfg_radm_strict_vc_prior),
    .cfg_hq_depths                  (cfg_hq_depths),
    .cfg_dq_depths                  (cfg_dq_depths),
    .target_mem_map                 (target_mem_map),
    .target_rom_map                 (target_rom_map),
    .cfg_pipe_garbage_data_mode     (cfg_pipe_garbage_data_mode),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .default_target                 (default_target),
    .cfg_cfg_tlp_bypass_en          (cfg_cfg_tlp_bypass_en),
    .cfg_config_limit               (cfg_config_limit),
    .cfg_target_above_config_limit  (cfg_target_above_config_limit),
    .cfg_p2p_track_cpl_to           (cfg_p2p_track_cpl_to),
    .cfg_p2p_err_rpt_ctrl           (cfg_p2p_err_rpt_ctrl),
    .ur_ca_mask_4_trgt1             (ur_ca_mask_4_trgt1)


    ,
    .cfg_nond0_vdm_block            (cfg_nond0_vdm_block),
    .cfg_client0_block_new_tlp      (cfg_client0_block_new_tlp),
    .cfg_client1_block_new_tlp      (cfg_client1_block_new_tlp),
    .cfg_client2_block_new_tlp      (cfg_client2_block_new_tlp)
    ,
    .pm_powerdown_status          (pm_powerdown_status),
    .cfg_force_powerdown          (cfg_force_powerdown)
);  // u_cdm_pl_reg





// -----------------------------------------------------------------------------
// Hot-plug Logic
// -----------------------------------------------------------------------------
//  Per Function Hot Plug Controller Instantiation.
generate
for (func=0; func<NF; func = func+1) begin : gen_hot_plug_ctrl
hot_plug_ctrl
 #(INST) u_hot_plug_ctrl (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .core_rst_n                     (non_sticky_rst_n),
    .cfg_atten_button_pressed       (cfg_atten_button_pressed[func]),
    .cfg_pwr_fault_det              (cfg_pwr_fault_det[func]),
    .cfg_mrl_sensor_chged           (cfg_mrl_sensor_chged[func]),
    .cfg_pre_det_chged              (cfg_pre_det_chged[func]),
    .cfg_cmd_cpled_int              (cfg_cmd_cpled_int[func]),
    .cfg_dll_state_chged            (cfg_dll_state_chged[func]),
    .cfg_int_disable                (cfg_int_disable[func]),
    .cfg_hp_int_en                  (cfg_hp_int_en[func]),
    .cfg_pme_en                     (cfg_pme_en[func]),
    .cfg_msi_en                     (cfg_msi_en[func]),
    .cfg_msix_en                    (cfg_msix_en[func]),

// ---------- Outputs --------
    .hp_pme                         (cdm_hp_pme[func]),
    .hp_int                         (cdm_hp_int[func]),
    .hp_msi                         (cdm_hp_msi[func])
);
end // for (func=0; func<NF; func = func+1) begin : gen_hot_plug_ctrl
endgenerate
// -----------------------------------------------------------------------------
// ATU Unroll
// -----------------------------------------------------------------------------



// --------------------------------------------------------------------------------------
// Assign outputs
// --------------------------------------------------------------------------------------


endmodule



