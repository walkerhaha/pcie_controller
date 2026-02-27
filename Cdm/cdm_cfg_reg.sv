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
// ---    $DateTime: 2020/09/18 13:59:22 $
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_cfg_reg.sv#13 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the PCIE core configure space registers.
// --- the PCIE configuration cycles and host access will be mapped to the
// --- local bus cycles.
//
// Note: this module can be configured to support
//      -- upstream port
//      -- downstream port
//      -- Bridge
//      -- End point
//      -- Root complex
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
 
 module cdm_cfg_reg
   (
// ---- inputs -----
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    device_type,
    phy_type,
    cfg_reg_sel,
    cfg_cap_reg_sel,
    ecfg_reg_sel,
    lbc_cdm_addr,
    lbc_cdm_data,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    lbc_cdm_dbi2,
    int_msg_pending,
    rdlh_link_up,
    smlh_link_up,
    smlh_autoneg_link_width,
    smlh_autoneg_link_sp,
    smlh_link_training_in_prog,
    smlh_bw_mgt_status,
    smlh_link_auto_bw_status,
    aux_pwr_det,
    radm_cpl_pending,
    cfg_cor_err_det,
    cfg_nf_err_det,
    cfg_f_err_det,
    cfg_rprt_err_cor,
    cfg_rprt_err_nf,
    cfg_rprt_err_f,
    cfg_unsupt_req_det,

    master_data_perr_det,
    signaled_target_abort_det,
    rcvd_target_abort_det,
    rcvd_master_abort_det,
    signaled_sys_err_det,
    perr_det,
    master_data_perr_det2,
    signaled_target_abort_det2,
    rcvd_target_abort_det2,
    rcvd_master_abort_det2,
    signaled_sys_err_det2,
    perr_det2,

    sys_pre_det_state,
    sys_mrl_sensor_state,
    sys_atten_button_pressed,
    sys_pwr_fault_det,
    sys_mrl_sensor_chged,
    sys_pre_det_chged,
    sys_cmd_cpled_int,
    sys_eml_interlock_engaged,
    radm_set_slot_pwr_limit,
    radm_slot_pwr_payload,
    pm_status,
    pm_pme_en,
    aux_pm_en,

    radm_correctable_err,
    radm_nonfatal_err,
    radm_fatal_err,

    radm_pm_pme,
    radm_msg_req_id,

    flt_cdm_addr,

    rbar_ctrl_update,
    cfg_rbar_bar0_mask,
    cfg_rbar_bar1_mask,
    cfg_rbar_bar2_mask,
    cfg_rbar_bar3_mask,
    cfg_rbar_bar4_mask,
    cfg_rbar_bar5_mask,
    cfg_rbar_bar_resizable,
    dbi_ro_wr_en,

    exp_rom_validation_status_strobe,
    exp_rom_validation_status,
    exp_rom_validation_details_strobe,
    exp_rom_validation_details,


    radm_snoop_upd,
    radm_snoop_bus_num,
    radm_snoop_dev_num,
    rdlh_dlcntrl_state,
    app_clk_pm_en,
    cfg_config_limit,
    app_dev_num,                 // DEV# driven by application
    app_bus_num,

// ------------ outputs --------------
    cfg_upd_pme_cap,
    cfg_io_match,
    cfg_config_above_match,
    cfg_rom_match,
    cfg_bar_match,
    cfg_bar_is_io,
    cfg_mem_match,
    cfg_prefmem_match,
    cfg_br_ctrl_serren,
    cfg_br_ctrl_perren,
    cfg_bus_master_en,
    cfg_reg_perren,
    cfg_reg_serren,
    cfg_sys_err_rc,
    cfg_2nd_reset,
    cfg_slot_pwr_limit_wr,
    cfg_pcie_slot_pwr_limit,
    cfg_multi_msi_en,
    cfg_msi_ext_data_en,
    cfg_msi_en,
    cfg_msi_addr,
    cfg_msi_data,
    cfg_msi_64,
    cfg_msix_en,
    cfg_msix_func_mask,
    cfg_msix_table_size,
    cfg_msix_table_size2,
    cfg_msix_table_bir,
    cfg_msix_table_bir2,
    cfg_msix_table_offset,
    cfg_msix_table_offset2,
    cfg_msix_pba_bir,
    cfg_msix_pba_bir2,
    cfg_msix_pba_offset,
    cfg_msix_pba_offset2,
    cfg_vpd_int,
    cfg_max_payload_size,
    cfg_relax_ord_en,
    cfg_ext_tag_en,
    cfg_phantom_fun_en,
    cfg_aux_pm_en,
    cfg_no_snoop_en,
    cfg_max_rd_req_size,
    cfg_bridge_crs_en,
    cfg_aslk_pmctrl,
    cfg_upd_aslk_pmctrl,
    cfg_clk_pm_en,
    cfg_rcb,
    cfg_link_dis,
    cfg_link_retrain,
    cfg_comm_clk_config,
    cfg_hw_autowidth_dis,
    cfg_link_rate,
    cfg_retimers_pre_detected,
    cfg_pwr_ind,
    cfg_atten_ind,
    cfg_pwr_ctrler_ctrl,
    cfg_hp_int_en,
    cfg_atten_button_pressed,
    cfg_eml_control,
    cfg_pwr_fault_det,
    cfg_mrl_sensor_chged,
    cfg_pre_det_chged,
    cfg_cmd_cpled_int,
    cfg_dll_state_chged,
    cfg_int_disable,
    cfg_cor_err_rpt_en,
    cfg_nf_err_rpt_en,
    cfg_f_err_rpt_en,
    cfg_unsupt_req_rpt_en,
    cfg_pbus_dev_num,
    cfg_pbus_num,
    cfg_2ndbus_num,
    cfg_subbus_num,
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
    cfg_cap_reg_data,
    cfg_cap_reg_ack,
    cfg_reg_data,
    cfg_reg_ack,
    cfg_upd_pmcsr,
    cfg_upd_aux_pm_en,
    cfg_upd_req_id,
    cfg_pmstatus_clr,
    cfg_pmstate,
    cfg_pme_en,
    cfg_pme_cap,
    cfg_isa_enable,
    cfg_vga_enable,
    cfg_vga16_decode,
    cfg_int_pin,
    cfg_pme_int,
    cfg_crs_sw_vis_en,
    cfg_pme_msi,
    cfg_pm_no_soft_rst,
    cfg_link_auto_bw_int,
    cfg_link_auto_bw_msi,
    cfg_bw_mgt_int,
    cfg_bw_mgt_msi,
    cfg_pcie_max_link_speed,
//    target_mem_map,
//    target_rom_map,
    cfg_pcie_aspm_cap,
    cfg_pcie_cap_int_msg_num,
    cfg_cpl_timeout_disable


    ,
    cfg_pcie_surp_dn_rpt_cap

    , 
    cfg_pcie_slot_clk_config,
    cfg_auto_slot_pwr_lmt_dis,
    cfg_dll_state_chged_en, 
    cfg_hp_slot_ctrl_access, 
    cfg_cmd_cpled_int_en_r, 
    cfg_pre_det_chged_en, 
    cfg_mrl_sensor_chged_en_r, 
    cfg_pwr_fault_det_en_r, 
    cfg_atten_button_pressed_en_r
);

parameter INST  = 0;                                              // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM  = 0;                                          // uniquifying parameter per function
parameter NL    = (`CM_TXNL < `CM_RXNL) ? `CM_TXNL : `CM_RXNL ;   // Number of nallower lanes
parameter NF    = `CX_NFUNC;                                      // Number of functions
parameter TP    = `TP;                          // Clock to Q delay (simulator insurance)

localparam FX_TLP = `CX_FX_TLP;                 // Number of TLPs received in a single cycle after formation block
localparam MULTI_DEVICE_AND_BUS_PER_FUNC = `MULTI_DEVICE_AND_BUS_PER_FUNC_EN_VALUE;
localparam SNOOP_REG = `MULTI_DEVICE_AND_BUS_PER_FUNC_EN_VALUE ? 1 : (FUNC_NUM==0) ? 1 :  0;
// ----- Inputs ---------------
input           core_clk;                       // Core clock
input           non_sticky_rst_n;               // Reset for non-sticky registers
input           sticky_rst_n;                   // Reset for sticky registers
input   [3:0]   device_type;                    // Device Type (EP/RC/etc)
input           phy_type;                       // Phy Type
// Local Bus
input           cfg_reg_sel;                    // cfg space register selected (0x0 - 0x3F)
input           cfg_cap_reg_sel;                // cfg capability space register selected (0x40 - 0xFF)
input           ecfg_reg_sel;                   // extended cfg capability space register selected (0x100-0x1FF)
input   [31:0]  lbc_cdm_addr;                   // Address of resource being accessed
input   [31:0]  lbc_cdm_data;                   // Data for write
input   [3:0]   lbc_cdm_wr;                     // Write byte enables: 4'b0000 = read
input           lbc_cdm_dbi;                    // DBI access to CDM
input           lbc_cdm_dbi2;                   // DBI2 access to CDM

// INT
input           int_msg_pending;                // internal INTx interrupt message is pending
// From Layer 2
input           rdlh_link_up;                   // Data Link Layer = DL_Active
// From Layer 1
input           smlh_link_up;                   // Layer 1 link is up
input   [5:0]   smlh_autoneg_link_width;        // negotiated link width
input   [3:0]   smlh_autoneg_link_sp;           // autonegotiation link speed
input           smlh_bw_mgt_status;             // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                // without the port transitioning through DL_Down status
input           smlh_link_auto_bw_status;       // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
                                                // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
input           smlh_link_training_in_prog;     // link trainging in progress

input           aux_pwr_det;                    // Aux Power is detected by the device
input           radm_cpl_pending;               // device has issued Non-posted requests which have not been completed

// ERRORS
input           cfg_cor_err_det;                // Correctable error detected
input           cfg_nf_err_det;                 // Non-fatal error detected
input           cfg_f_err_det;                  // Fatal error detected
input           cfg_rprt_err_cor;               // System Error factor by Correctable Error
input           cfg_rprt_err_nf;                // System Error factor by Non-Fatal Error
input           cfg_rprt_err_f;                 // System Error factor by Fatal Error
input           cfg_unsupt_req_det;             // Non-advisory unsupported request error detected
input           master_data_perr_det;
input           signaled_target_abort_det;
input           rcvd_target_abort_det;
input           rcvd_master_abort_det;
input           signaled_sys_err_det;
input           perr_det;
input           master_data_perr_det2;
input           signaled_target_abort_det2;
input           rcvd_target_abort_det2;
input           rcvd_master_abort_det2;
input           signaled_sys_err_det2;
input           perr_det2;

// Slot
input           sys_pre_det_state;              // Indicates the presence of a card in the slot
input           sys_mrl_sensor_state;           // Reports the status of the MRL sensor if it is implemented
input           sys_atten_button_pressed;       // Attention button is pressed or receive a message from end device
input           sys_pwr_fault_det;              // Indicates a fault in the power controller
input           sys_mrl_sensor_chged;           // Indicates the value of the MRL Sensor state had changed
input           sys_pre_det_chged;              // Indicates Presence Detect had changed
input           sys_cmd_cpled_int;              // this bit when set enables the generation of hot plug interrupt when a command is completed by hot plug control logic
input           sys_eml_interlock_engaged;      // Electromechanical Interlock engaged

input           radm_set_slot_pwr_limit;        // Capture Slot Power Value/Scale from payload below
input   [31:0]  radm_slot_pwr_payload;          // Extracted MSG payload

input           pm_status;                      // sticky bit, preserved in PMC during Aux power
input           pm_pme_en;                      // sticky bit, preserved in PMC during Aux power
input           aux_pm_en;                      // sticky bit, preserved in PMC during Aux power

// for Root Status register
// Received error messages
input           radm_correctable_err;           // Received Correctable Error MSG
input           radm_nonfatal_err;              // Received Non-Fatal Uncorrectable Error MSG
input           radm_fatal_err;                 // Received Fatal Uncorrectable Error MSG
input   [FX_TLP-1:0]            radm_pm_pme;                    // Received a PME
input   [(FX_TLP*16)-1:0]       radm_msg_req_id;                // Requester ID of the above PME

// for filter address decoding
input   [(FX_TLP*64)-1:0]       flt_cdm_addr;   // 64-bit address to be compared with BAR


input          rbar_ctrl_update;               // indicates that RBAR control register has been updated
input   [63:0] cfg_rbar_bar0_mask;             // Resizable BAR0 mask
input   [31:0] cfg_rbar_bar1_mask;             // Resizable BAR1 mask
input   [63:0] cfg_rbar_bar2_mask;             // Resizable BAR2 mask
input   [31:0] cfg_rbar_bar3_mask;             // Resizable BAR3 mask
input   [63:0] cfg_rbar_bar4_mask;             // Resizable BAR4 mask
input   [31:0] cfg_rbar_bar5_mask;             // Resizable BAR5 mask
input   [5:0]  cfg_rbar_bar_resizable;         // Resize BAR[N] mask where N = 0 to 5
input          dbi_ro_wr_en;
input          exp_rom_validation_status_strobe;
input [2:0]    exp_rom_validation_status;
input          exp_rom_validation_details_strobe;
input [3:0]    exp_rom_validation_details;

input [1:0]                 rdlh_dlcntrl_state;      // DLCM state machine signal
input                       app_clk_pm_en; // enable the clock power management capability
input [9:0]                 cfg_config_limit; // CONFIG_LIMIT_REG
input [4:0]                 app_dev_num; // DEV# from application
input [7:0]                 app_bus_num; // BUS# from application
// ---------- Outputs --------
output                          cfg_upd_pme_cap;                // Update cfg_pme_cap in pm_ctrl
output  [FX_TLP-1:0]            cfg_io_match;                   // Within IO address range
output  [FX_TLP-1:0]            cfg_config_above_match;         // Adress is above certain user configuration limit
output  [FX_TLP-1:0]            cfg_rom_match;                  // Within expansion ROM address range
output  [(FX_TLP*6)-1:0]        cfg_bar_match;                  // Within BAR range
output  [5:0]                   cfg_bar_is_io;                  // Indicates whether the BAR is set as IO or memory
output  [FX_TLP-1:0]            cfg_mem_match;                  // Within Memory range (Type 1 only)
output  [FX_TLP-1:0]            cfg_prefmem_match;              // Within Prefetchable Memorey range (Type 1 only)
output                          cfg_slot_pwr_limit_wr;          // configuration write to slot capability register trigging set_slot_pwr_limit message.
output  [9:0]                   cfg_pcie_slot_pwr_limit;        // Current setting of slot power limit value[7:0] & scale[9:8]
output  [31:0]                  cfg_reg_data;                   // Read data back from core
output  [31:0]                  cfg_cap_reg_data;               // Read data back from core
output                          cfg_reg_ack;                    // Acknowledge back from core. Indicates completion, read data is valid
output                          cfg_cap_reg_ack;                // Acknowledge back from core. Indicates completion, read data is valid
output                          cfg_relax_ord_en;               // Relax Ordering enable
output  [2:0]                   cfg_max_payload_size;           // Max payload size configured
output                          cfg_ext_tag_en;                 // Extended tag field enable (optional feature - always 0)
output                          cfg_phantom_fun_en;             // Phantom Function enable
output                          cfg_no_snoop_en;                // No snoop enable
output  [2:0]                   cfg_max_rd_req_size;            // Max read request size
output                          cfg_bridge_crs_en;              // Bridge Configuration Retry Enable (Bridge only)
output  [1:0]                   cfg_aslk_pmctrl;                // active state PM control
output                          cfg_upd_aslk_pmctrl;            // Register the aslk_pmctrl in pm_ctrl
output                          cfg_clk_pm_en;                  // Clock PM enable
output                          cfg_rcb;                        // RO for root complex
output                          cfg_link_dis;                   // link disable, not applied to endpoint device and Upstream port of a switch
output                          cfg_link_retrain;               // link retrain, not applied to endpoint device and Upstream port of a switch
output                          cfg_comm_clk_config;            // common clock configuration
output                          cfg_hw_autowidth_dis;           // HW autonomous width disable
output                          cfg_ext_synch;                  // Extended Synch
output                          cfg_io_space_en;                // IO Space enable
output                          cfg_mem_space_en;               // Memory space enable
// LINK
output  [3:0]   cfg_link_rate;                  // Maximum link speed
output  [1:0]   cfg_retimers_pre_detected;      // Retimers present detected {retimer2,retimer1}
// Slot
output  [1:0]   cfg_pwr_ind;                    // trigger power indicator message
output  [1:0]   cfg_atten_ind;                  // trigger attention indicator message
output          cfg_pwr_ctrler_ctrl;            // Power controller control - 0: Power on, 1: Power off.
output          cfg_hp_int_en;                  // Hot Plug interrupt enable
output          cfg_atten_button_pressed;       // Attention button pressed
output          cfg_eml_control;                // Electromechanical Interlock Control (pulse)
output          cfg_pwr_fault_det;              // Power fault detected
output          cfg_mrl_sensor_chged;           // MRL sensor changed
output          cfg_pre_det_chged;              // Presence detect changed
output          cfg_cmd_cpled_int;              // Command completed interrupt
output          cfg_dll_state_chged;            // Data Link Layer State Changed

// PME
output          cfg_aux_pm_en;                  // AUX power PM enable
output          cfg_upd_req_id;                 // Update requester ID field
output          cfg_upd_aux_pm_en;              // Update aux_pm_en signal in PMC
output          cfg_upd_pmcsr;                  // Update PMCSR in PMC
output          cfg_pmstatus_clr;               // Clear PM status in PMC
output  [2:0]   cfg_pmstate;                    // Power state
output          cfg_pme_en;                     // PME enable bit
output  [4:0]   cfg_pme_cap;                    // PME Capability

// MSI
output          cfg_int_disable;                // Interrupt disable
output  [2:0]   cfg_multi_msi_en;               // Multiple MSI enable
output          cfg_msi_ext_data_en;            // Extended message data for MSI enable        
output          cfg_msi_en;                     // MSI enable
output  [63:0]  cfg_msi_addr;                   // MSI address
output  [31:0]  cfg_msi_data;                   // MSI data field
output          cfg_msi_64;                     // 64 bits MSI addressing enable
// MSI-X
input   [NF-1:0] radm_snoop_upd;
input   [7:0]    radm_snoop_bus_num;
input   [4:0]    radm_snoop_dev_num;
output          cfg_msix_en;                    // MSI-X enable
output          cfg_msix_func_mask;             // MSI-X Function Mask
output  [10:0]  cfg_msix_table_size;            // MSI-X Table Size
output  [10:0]  cfg_msix_table_size2;           // MSI-X Table Size - second independent value exported to VFs
output  [2:0]   cfg_msix_table_bir;             // MSI-X Table BIR
output  [2:0]   cfg_msix_table_bir2;            // MSI-X Table BIR  - second independent value exported to VFs
output  [28:0]  cfg_msix_table_offset;          // MSI-X Table Offset
output  [28:0]  cfg_msix_table_offset2;         // MSI-X Table Offset - second independent value exported to VFs
output  [2:0]   cfg_msix_pba_bir;               // MSI-X PBA BIR
output  [2:0]   cfg_msix_pba_bir2;              // MSI-X PBA BIR - second independent value exported to VFs
output  [28:0]  cfg_msix_pba_offset;            // MSI-X PBA Offset
output  [28:0]  cfg_msix_pba_offset2;           // MSI-X PBA Offset - second independent value exported to VFs

// VPD
output          cfg_vpd_int;                    // VPD Interrupt to application

// to ERR GEN
output          cfg_cor_err_rpt_en;             // Correctable error reporting enable
output          cfg_nf_err_rpt_en;              // Non-fatal error reporting enable
output          cfg_f_err_rpt_en;               // Fatal error reporting enable
// to ERR REG
output          cfg_unsupt_req_rpt_en;          // Unsupported error reporting enable

// Only for Type 1
output  [4:0]   cfg_pbus_dev_num;                    // Device number
output  [7:0]   cfg_pbus_num;                   // Bus number
output  [7:0]   cfg_2ndbus_num;                 // Secondary bus number
output  [7:0]   cfg_subbus_num;                 // Subordinary bus number

output          cfg_2nd_reset;                  // Secondary reset

output  [63:0]  cfg_bar0_start;                 // BAR0 start address
output  [63:0]  cfg_bar0_limit;                 // BAR0 limit address
output  [63:0]  cfg_bar0_mask;                  // BAR0 mask register
output  [31:0]  cfg_bar1_start;                 // BAR1 start address
output  [31:0]  cfg_bar1_limit;                 // BAR1 limit address
output  [31:0]  cfg_bar1_mask;                  // BAR1 mask register
output  [63:0]  cfg_bar2_start;                 // BAR2 start address
output  [63:0]  cfg_bar2_limit;                 // BAR2 limit address
output  [63:0]  cfg_bar2_mask;                  // BAR2 mask register
output  [31:0]  cfg_bar3_start;                 // BAR3 start address
output  [31:0]  cfg_bar3_limit;                 // BAR3 limit address
output  [31:0]  cfg_bar3_mask;                  // BAR3 mask register
output  [63:0]  cfg_bar4_start;                 // BAR4 start address
output  [63:0]  cfg_bar4_limit;                 // BAR4 limit address
output  [63:0]  cfg_bar4_mask;                  // BAR4 mask register
output  [31:0]  cfg_bar5_start;                 // BAR5 start address
output  [31:0]  cfg_bar5_limit;                 // BAR5 limit address
output  [31:0]  cfg_bar5_mask;                  // BAR5 mask register
output  [31:0]  cfg_rom_mask;                   // ROM BAR mask register
output  [15:0]  cfg_mem_base;                   // Memory start address
output  [15:0]  cfg_mem_limit;                  // Memory limit address
output  [63:0]  cfg_pref_mem_base;              // Prefetchable memory start address
output  [63:0]  cfg_pref_mem_limit;             // Prefetchable memory limit address
output  [31:0]  cfg_exp_rom_start;              // Expansion ROM start address
output  [31:0]  cfg_exp_rom_limit;              // Expansion ROM limit address
output  [15:0]  cfg_io_base_upper16;            // Upper 16 bit IO base address
output  [15:0]  cfg_io_limit_upper16;           // Upper 16 bit IO limit address
output  [7:0]   cfg_io_base;                    // IO base address
output  [7:0]   cfg_io_limit;                   // IO limit address
output  [7:0]   cfg_hdr_type;                   // Header type
output          cfg_br_ctrl_serren;             // Bridge Control: SERR Enable
output          cfg_br_ctrl_perren;             // Bridge Control: Parity Error Response Enable
output          cfg_bus_master_en;              // Bus master enable
output          cfg_reg_perren;                 // Parity error response enable
output          cfg_reg_serren;                 // SERR# enable
output          cfg_sys_err_rc;                 // System Error (RC Only)
output          cfg_isa_enable;                 // For bridge: ISA enable
output          cfg_vga_enable;                 // For bridge: VGA enable (optional)
output          cfg_vga16_decode;               // For bridge: VGA 16-bit decode (optional)
output  [7:0]   cfg_int_pin;                    // Interrupt Pin mapping
output          cfg_crs_sw_vis_en;              // Root ctrl CRS Software Visibility feature enable
output          cfg_pme_int;                    // Interrupt caused by PME (RC Only)
output          cfg_pme_msi;                    // MSI caused by PME (RC Only)
output  [4:0]   cfg_pcie_cap_int_msg_num;       // MSI Message Data if multiple MSI is supported
output          cfg_cpl_timeout_disable;        // Completion Timeout disable
output          cfg_link_auto_bw_int;           // Interrupt indicating that Link Bandwidth Management Status bit has been set
output          cfg_link_auto_bw_msi;           // MSI indicating that Link Bandwidth Management Status bit has been set
output          cfg_bw_mgt_int;                 // Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
output          cfg_bw_mgt_msi;                 // MSI indicating that Link Autonomous Bandwidth Status bit has been set
output  [3:0]   cfg_pcie_max_link_speed;        // Max link speed
output          cfg_pm_no_soft_rst;             // no soft reset control
//output  [5:0]   target_mem_map;                 // Each bit of this vector indicates which target receives memory transactions for that bar #
//output          target_rom_map;                 // Each bit of this vector indicates which target receives rom    transactions for that bar #
output [1:0]    cfg_pcie_aspm_cap;




output cfg_pcie_surp_dn_rpt_cap;

output    cfg_pcie_slot_clk_config;
output    cfg_auto_slot_pwr_lmt_dis;    // Auto Slot Power Limit Disable field of Slot Control Register; hardwired to 0 if DPC is not configured.
output    cfg_dll_state_chged_en;
output    cfg_hp_slot_ctrl_access; 
output    cfg_cmd_cpled_int_en_r; 
output    cfg_pre_det_chged_en; 
output    cfg_mrl_sensor_chged_en_r; 
output    cfg_pwr_fault_det_en_r; 
output    cfg_atten_button_pressed_en_r; 
// Output registers
//
reg             cfg_cor_err_rpt_en;
reg             cfg_nf_err_rpt_en;
reg             cfg_f_err_rpt_en;
reg             cfg_unsupt_req_rpt_en;
reg     [7:0]   cfg_pbus_num_reg;
reg     [4:0]   r_dev_num_snooped;
reg     [7:0]   cfg_2ndbus_num;
reg             cfg_2nd_reset;

reg             cfg_slot_pwr_limit_wr;
reg     [31:0]  cfg_cap_reg_data;
reg             cfg_cap_reg_ack;
reg     [31:0]  cfg_reg_data;
reg             cfg_reg_ack;
reg             cfg_relax_ord_en;
reg     [2:0]   cfg_max_payload_size;
reg             cfg_ext_tag_en;
reg             cfg_phantom_fun_en;
reg             cfg_no_snoop_en;
reg     [2:0]   cfg_max_rd_req_size;
reg             cfg_bridge_crs_en;
reg             cfg_ext_synch_int;
wire            cfg_ext_synch;
reg             cfg_hw_autowidth_dis;
reg     [31:0]  cfg_pref_base_upper32;
reg     [31:0]  cfg_pref_limit_upper32;
reg     [15:0]  cfg_io_limit_upper16;
reg     [15:0]  cfg_io_base_upper16;
wire    [3:0]   cfg_link_rate;
wire    [15:0]  cfg_mem_base;
wire    [15:0]  cfg_mem_limit;
wire    [63:0]  cfg_pref_mem_base;
wire    [63:0]  cfg_pref_mem_limit;
reg     [31:0]  cfg_exp_rom_start;
reg     [31:0]  cfg_exp_rom_limit;
reg     [4:0]   cfg_pcie_cap_int_msg_num;
reg             cfg_cpl_timeout_disable;
reg     [3:0]   cfg_cpl_timeout_range;
reg             cfg_ari_fwd_en;
wire    [3:0]   cfg_pcie_max_link_speed;
reg     [3:0]   cfg_pcie_max_link_speed_int;
wire    [3:0]   cfg_pcie_max_link_speed_mpcie;
reg             cfg_link_auto_bw_int;
reg             cfg_bw_mgt_int;
//wire    [5:0]   target_mem_map;                 // Each bit of this vector indicates which target receives memory transactions for that bar #
//wire            target_rom_map;                 // Each bit of this vector indicates which target receives rom    transactions for that bar #
//`ifdef CX_SRIOV_ENABLE
//wire   [5:0]    vf_target_mem_map;             // Each bit of this vector indicates which target receives memory transactions for that bar #
//`endif // CX_SRIOV_ENABLE



wire    [6:0]   cfg_pcie_supp_link_speed_vector_mpcie;  // Supported Link Speeds Vector for mpcie

// Internal Signal Declarations
reg     [15:0]  cfg_reg_id;
reg     [29:0]  cfg_cap_reg_id;
reg     [7:0]   int_line_reg;
reg             cfg_br_ctrl_perren;
reg             cfg_br_ctrl_serren;
reg             cfg_aux_pm_en;
reg             cfg_cor_err_det_reg;
reg             cfg_nf_err_det_reg;
reg             cfg_f_err_det_reg;
reg             cfg_unsupt_req_det_reg;
reg             cfg_link_retrain;               // retrain link
wire    [1:0]   pm_reg_id;                      // PM cap. structure addr. decode
wire    [31:0]  pm_reg_data;                    // PM cap. structure read-back data
wire    [5:0]   msi_reg_id;                     // MSI cap. structure addr. decode
wire    [31:0]  msi_reg_data;                   // MSI cap. structure read-back data
reg     [7:0]   rcvd_slot_pwr_limit_val;        // specifies that upper limit on power supplied by slot
reg     [1:0]   rcvd_slot_pwr_limit_scale;      // specifies the scale used for the slot power limit value

wire    [7:0]   cfg_reg_3,  cfg_reg_2,  cfg_reg_1,  cfg_reg_0;
wire    [7:0]   cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4;
wire    [7:0]   cfg_reg_11, cfg_reg_10, cfg_reg_9,  cfg_reg_8;
wire    [7:0]   cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12;
wire    [7:0]   cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16;
wire    [7:0]   cfg_reg_23, cfg_reg_22, cfg_reg_21, cfg_reg_20;
wire    [7:0]   cfg_reg_27, cfg_reg_26, cfg_reg_25, cfg_reg_24;
wire    [7:0]   cfg_reg_30, cfg_reg_31, cfg_reg_29, cfg_reg_28;
wire    [7:0]   cfg_reg_35, cfg_reg_34, cfg_reg_33, cfg_reg_32;
wire    [7:0]   cfg_reg_39, cfg_reg_38, cfg_reg_37, cfg_reg_36;
wire    [7:0]   cfg_reg_43, cfg_reg_42, cfg_reg_41, cfg_reg_40;
wire    [7:0]   cfg_reg_47, cfg_reg_46, cfg_reg_45, cfg_reg_44;
wire    [7:0]   cfg_reg_51, cfg_reg_50, cfg_reg_49, cfg_reg_48;
wire    [7:0]   cfg_reg_55, cfg_reg_54, cfg_reg_53, cfg_reg_52;
wire    [7:0]   cfg_reg_59, cfg_reg_58, cfg_reg_57, cfg_reg_56;
wire    [7:0]   cfg_reg_63, cfg_reg_61, cfg_reg_62, cfg_reg_60;
wire    [7:0]   cfg_reg_67, cfg_reg_66, cfg_reg_65, cfg_reg_64;
wire    [7:0]   cfg_reg_71, cfg_reg_70, cfg_reg_69, cfg_reg_68;
//wire    [7:0]   cfg_reg_75, cfg_reg_74, cfg_reg_73, cfg_reg_72;
//wire    [7:0]   cfg_reg_79, cfg_reg_78, cfg_reg_77, cfg_reg_76;
//reg     [7:0]   cfg_reg_83, cfg_reg_82, cfg_reg_81, cfg_reg_80;
//reg     [7:0]   cfg_reg_85, cfg_reg_84, cfg_reg_87, cfg_reg_86;
wire    [7:0]   cfg_reg_91, cfg_reg_90, cfg_reg_89, cfg_reg_88;
wire    [7:0]   cfg_reg_95, cfg_reg_94, cfg_reg_93, cfg_reg_92;
wire    [7:0]   cfg_reg_96, cfg_reg_97, cfg_reg_98, cfg_reg_99;
wire    [7:0]   cfg_reg_100, cfg_reg_101, cfg_reg_102, cfg_reg_103;
wire    [7:0]   cfg_reg_107, cfg_reg_106, cfg_reg_105, cfg_reg_104;
wire    [7:0]   cfg_reg_111, cfg_reg_110, cfg_reg_109, cfg_reg_108;
wire    [7:0]   cfg_reg_115, cfg_reg_114, cfg_reg_113, cfg_reg_112;
wire    [7:0]   cfg_reg_119, cfg_reg_118, cfg_reg_117, cfg_reg_116;
wire    [7:0]   cfg_reg_123, cfg_reg_122, cfg_reg_121, cfg_reg_120;
wire    [7:0]   cfg_reg_127, cfg_reg_126, cfg_reg_125, cfg_reg_124;
wire    [7:0]   cfg_reg_131, cfg_reg_130, cfg_reg_129, cfg_reg_128;
wire    [7:0]   cfg_reg_135, cfg_reg_134, cfg_reg_133, cfg_reg_132;
wire    [7:0]   cfg_reg_139, cfg_reg_138, cfg_reg_137, cfg_reg_136;
wire    [7:0]   cfg_reg_143, cfg_reg_142, cfg_reg_141, cfg_reg_140;   // Device Cap 2
wire    [7:0]   cfg_reg_147, cfg_reg_146, cfg_reg_145, cfg_reg_144;   // Device Control & Status 2
wire    [7:0]   cfg_reg_151, cfg_reg_150, cfg_reg_149, cfg_reg_148;   // Link Capabilities 2
wire    [7:0]   cfg_reg_155, cfg_reg_154, cfg_reg_153, cfg_reg_152;     // Link Control & Status 2
//wire    [7:0]   cfg_reg_159, cfg_reg_158, cfg_reg_157, cfg_reg_156;   // Slot Capabilities 2
//wire    [7:0]   cfg_reg_163, cfg_reg_162, cfg_reg_161, cfg_reg_160;   // Slot Control & Status 2
wire    [7:0]   cfg_reg_167, cfg_reg_166, cfg_reg_165, cfg_reg_164;
wire    [7:0]   cfg_reg_171, cfg_reg_170, cfg_reg_169, cfg_reg_168;
//reg     [7:0]   cfg_reg_175, cfg_reg_174, cfg_reg_173, cfg_reg_172;
//wire    [7:0]   cfg_reg_179, cfg_reg_178, cfg_reg_177, cfg_reg_176;
wire    [7:0]   cfg_reg_175, cfg_reg_174, cfg_reg_173, cfg_reg_172;
wire    [7:0]   cfg_reg_179, cfg_reg_178, cfg_reg_177, cfg_reg_176;
wire    [7:0]   cfg_reg_183, cfg_reg_182, cfg_reg_181, cfg_reg_180;

reg             reg_read_pulse;
reg             cap_reg_read_pulse;
reg     [7:0]   cfg_subbus_num;
reg     [1:0]   cfg_aslk_pmctrl_int;
wire            int_upd_aslk_pmctrl;
reg             cfg_upd_aslk_pmctrl;
reg             cfg_clk_pm_en;
reg             cfg_comm_clk_config;
reg             cfg_rcb;
reg             cfg_link_dis;
reg             cfg_pwr_ctrler_ctrl;
reg     [1:0]   cfg_pwr_ind;
reg     [1:0]   cfg_atten_ind;
reg             cfg_hp_int_en;
reg             cfg_eml_control;
reg             cfg_dll_state_chged_en;
reg             cfg_auto_slot_pwr_lmt_dis; // Auto Slot Power Limit Disable field of Slot Control Register
wire    [31:0]  cfg_msi_mask;

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
assign switch_device    = pcie_sw_up | pcie_sw_down;
assign pcie_br_up       = (device_type == `PCIE_PCIX);
assign pcie_br_down     = (device_type == `PCIX_PCIE);
assign bridge_device    = pcie_br_up | pcie_br_down;
assign upstream_port    = end_device | pcie_br_up | pcie_sw_up;

// Config space type
wire    type0;                      // Type 0 configuration space
assign  type0 = end_device;         // Only endpoint devices is a Type 0


wire msix_cap_enable;
assign msix_cap_enable      = `MSIX_CAP_ENABLE;
wire msi_cap_enable;
assign msi_cap_enable       = `MSI_CAP_ENABLE;
wire vpd_cap_enable;
assign vpd_cap_enable       = `VPD_CAP_ENABLE;
wire slot_cap_enable;
assign slot_cap_enable      = `SLOT_CAP_ENABLE;
wire sata_cap_enable;
assign sata_cap_enable      = `SATA_CAP_ENABLE;

wire dbi_ro_wr_en;
wire int_lbc_cdm_dbi_only   = lbc_cdm_dbi & ~lbc_cdm_dbi2;
wire int_lbc_cdm_dbi        = int_lbc_cdm_dbi_only & dbi_ro_wr_en;
wire int_lbc_cdm_dbi2       = lbc_cdm_dbi2 & dbi_ro_wr_en;

wire [5:0] cfg_bar_enabled;
wire has_mem_bar;
wire has_io_bar;

// =============================================================================
// Capture Set Slot Power messages
// =============================================================================

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        rcvd_slot_pwr_limit_val     <= #TP 0;
        rcvd_slot_pwr_limit_scale   <= #TP 0;
    end else begin
        rcvd_slot_pwr_limit_val     <= #TP radm_set_slot_pwr_limit ? radm_slot_pwr_payload[7:0] : rcvd_slot_pwr_limit_val;
        rcvd_slot_pwr_limit_scale   <= #TP radm_set_slot_pwr_limit ? radm_slot_pwr_payload[9:8] : rcvd_slot_pwr_limit_scale;
    end
end

// =============================================================================
// PCI-E Configuration Space Registers (TYPE 1/0)
// =============================================================================
reg cfg_reg_sel_d;
wire cfg_reg_id_en;
assign cfg_reg_id_en = cfg_reg_sel | cfg_reg_sel_d; 
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
  if(!non_sticky_rst_n)
        cfg_reg_id      <= #TP 0;
     else begin
        cfg_reg_id[0]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h000 >> 2)) & cfg_reg_sel) : cfg_reg_id[0];
        cfg_reg_id[1]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h004 >> 2)) & cfg_reg_sel) : cfg_reg_id[1];
        cfg_reg_id[2]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h008 >> 2)) & cfg_reg_sel) : cfg_reg_id[2];
        cfg_reg_id[3]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h00c >> 2)) & cfg_reg_sel) : cfg_reg_id[3];
        cfg_reg_id[4]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h010 >> 2)) & cfg_reg_sel) : cfg_reg_id[4];
        cfg_reg_id[5]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h014 >> 2)) & cfg_reg_sel) : cfg_reg_id[5];
        cfg_reg_id[6]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h018 >> 2)) & cfg_reg_sel) : cfg_reg_id[6];
        cfg_reg_id[7]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h01c >> 2)) & cfg_reg_sel) : cfg_reg_id[7];
        cfg_reg_id[8]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h020 >> 2)) & cfg_reg_sel) : cfg_reg_id[8];
        cfg_reg_id[9]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h024 >> 2)) & cfg_reg_sel) : cfg_reg_id[9];
        cfg_reg_id[10]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h028 >> 2)) & cfg_reg_sel) : cfg_reg_id[10];
        cfg_reg_id[11]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h02c >> 2)) & cfg_reg_sel) : cfg_reg_id[11];
        cfg_reg_id[12]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h030 >> 2)) & cfg_reg_sel) : cfg_reg_id[12];
        cfg_reg_id[13]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h034 >> 2)) & cfg_reg_sel) : cfg_reg_id[13];
        cfg_reg_id[14]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h038 >> 2)) & cfg_reg_sel) : cfg_reg_id[14];
        cfg_reg_id[15]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h03c >> 2)) & cfg_reg_sel) : cfg_reg_id[15];
     end
end

//L_UNCOVERED_330_3: allow toggling of all bits in cfg_cap_reg_id[], regardless of config
//L_UNCOVERED_330_3: Fix: rewrite address decoder process to do:
//L_UNCOVERED_330_3: Fix: 1. first part: full unconditional decode of all registers, regardless of config
//L_UNCOVERED_330_3: Fix: 2. second part: only if !max_coverage, override to 0 depending on config
//L_UNCOVERED_330_3: Fix: 3. instrument tests to force max_coverage=1 and exercise address regardless of configs
reg cfg_cap_reg_sel_d;
wire cfg_cap_reg_id_en;
assign cfg_cap_reg_id_en = cfg_cap_reg_sel | cfg_cap_reg_sel_d;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
  if(!non_sticky_rst_n)
        cfg_cap_reg_id      <= #TP 0;
     else begin
        cfg_cap_reg_id[0]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PM_CAP + 4'h0) >> 2))     & cfg_cap_reg_sel) : cfg_cap_reg_id[0];
        cfg_cap_reg_id[1]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PM_CAP + 4'h4) >> 2))     & cfg_cap_reg_sel) : cfg_cap_reg_id[1];
        if (msi_cap_enable) begin
            cfg_cap_reg_id[2]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSI_CAP + 4'h0) >> 2))    & cfg_cap_reg_sel) : cfg_cap_reg_id[2];
            cfg_cap_reg_id[3]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSI_CAP + 4'h4) >> 2))    & cfg_cap_reg_sel) : cfg_cap_reg_id[3];
            cfg_cap_reg_id[4]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSI_CAP + 4'h8) >> 2))    & cfg_cap_reg_sel) : cfg_cap_reg_id[4];
            cfg_cap_reg_id[5]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSI_CAP + 4'hC) >> 2))    & cfg_cap_reg_sel) : cfg_cap_reg_id[5];
            cfg_cap_reg_id[24]  <= #TP 0;
            cfg_cap_reg_id[25]  <= #TP 0;
        end
        else begin
            cfg_cap_reg_id[2]  <= #TP 0;
            cfg_cap_reg_id[3]  <= #TP 0;
            cfg_cap_reg_id[4]  <= #TP 0;
            cfg_cap_reg_id[5]  <= #TP 0;
            cfg_cap_reg_id[24]  <= #TP 0;
            cfg_cap_reg_id[25]  <= #TP 0;
        end
        cfg_cap_reg_id[6]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 4'h0)  >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[6];
        cfg_cap_reg_id[7]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h4)  >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[7];
        cfg_cap_reg_id[8]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h8)  >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[8];
        cfg_cap_reg_id[9]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'hc)  >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[9];
        cfg_cap_reg_id[10]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h10) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[10];
        // Slot Capability/Control/Status registers only apply to Downstream ports
        if (!upstream_port) begin
            cfg_cap_reg_id[11]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h14) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[11];
            cfg_cap_reg_id[12]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h18) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[12];
        end
        else begin
            cfg_cap_reg_id[11]  <= #TP 0;
            cfg_cap_reg_id[12]  <= #TP 0;
        end
        // Root Capability/Control/Status registers only apply to RC
        if (rc_device) begin
//L_UNCOVERED_330_4: sw => rc_device is dynamic for sw ( it is static for rc,ep, lines below are automatically excluded by the tool for ep,rc), solve by using max_coverage approach
            cfg_cap_reg_id[13]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h1C) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[13];
            cfg_cap_reg_id[14]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h20) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[14];
        end
        else begin
            cfg_cap_reg_id[13]  <= #TP 0;
            cfg_cap_reg_id[14]  <= #TP 0;
        end
        cfg_cap_reg_id[22]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h24) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[22];
        cfg_cap_reg_id[23]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h28) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[23];
        cfg_cap_reg_id[29]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h2C) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[29];

    cfg_cap_reg_id[19]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h30) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[19];

    //`ifdef CX_2ND_SPEED
    //`ifdef CX_GEN2_SPEED        //as of Readiness Notifications this register MUST be readable

     //   cfg_cap_reg_id[19]  <= #TP (lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h30) >> 2))  & cfg_cap_reg_sel;
    //`else
    //    cfg_cap_reg_id[19]  <= #TP 0;
    //`endif
    //`endif
        if (slot_cap_enable) begin
            cfg_cap_reg_id[15]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_SLOT_CAP + 4'h0) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[15];
        end 
        else begin
            cfg_cap_reg_id[15]  <= #TP 0;
        end    
        if (msix_cap_enable) begin
            cfg_cap_reg_id[16]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSIX_CAP + 4'h0) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[16];
            cfg_cap_reg_id[17]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSIX_CAP + 4'h4) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[17];
            cfg_cap_reg_id[18]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSIX_CAP + 4'h8) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[18];
        end
        else begin
            cfg_cap_reg_id[16]  <= #TP 0;
            cfg_cap_reg_id[17]  <= #TP 0;
            cfg_cap_reg_id[18]  <= #TP 0;
        end
        if (vpd_cap_enable) begin
            cfg_cap_reg_id[20]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_VPD_CAP + 4'h0) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[20];
            cfg_cap_reg_id[21]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_VPD_CAP + 4'h4) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[21];
        end
        else begin
            cfg_cap_reg_id[20]  <= #TP 0;
            cfg_cap_reg_id[21]  <= #TP 0;
        end
        if (sata_cap_enable) begin
            cfg_cap_reg_id[26]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] ==
                ((`CFG_SATA_CAP + 4'h0) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[26];
            cfg_cap_reg_id[27]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] ==
                ((`CFG_SATA_CAP + 4'h4) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[27];
            cfg_cap_reg_id[28]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] ==
                ((`CFG_SATA_CAP + 4'h8) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[28];
        end else begin
            cfg_cap_reg_id[26]  <= #TP 0;
            cfg_cap_reg_id[27]  <= #TP 0;
            cfg_cap_reg_id[28]  <= #TP 0;
        end
    end
end

assign pm_reg_id =  {cfg_cap_reg_id[1],     cfg_cap_reg_id[0]};   // map the cap_id into pm_id
assign msi_reg_id = {cfg_cap_reg_id[25:24], cfg_cap_reg_id[5:2]}; // map the cap_id into msi_id

// =============================================================================
// CFG Register Read Operation
// =============================================================================

// read PCI cfg space registers
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        cfg_reg_data    <= #TP 0;
    else
      if (reg_read_pulse) begin

            unique case (1'b1)

            cfg_reg_id[0] : cfg_reg_data  <= #TP {cfg_reg_3,  cfg_reg_2,  cfg_reg_1,  cfg_reg_0};
            cfg_reg_id[1] : cfg_reg_data  <= #TP {cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4};
            cfg_reg_id[2] : cfg_reg_data  <= #TP {cfg_reg_11, cfg_reg_10, cfg_reg_9,  cfg_reg_8};
            cfg_reg_id[3] : cfg_reg_data  <= #TP {cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12};
            cfg_reg_id[4] : cfg_reg_data  <= #TP {cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16};
            cfg_reg_id[5] : cfg_reg_data  <= #TP {cfg_reg_23, cfg_reg_22, cfg_reg_21, cfg_reg_20};
            cfg_reg_id[6] : cfg_reg_data  <= #TP {cfg_reg_27, cfg_reg_26, cfg_reg_25, cfg_reg_24};
            cfg_reg_id[7] : cfg_reg_data  <= #TP {cfg_reg_31, cfg_reg_30, cfg_reg_29, cfg_reg_28};
            cfg_reg_id[8] : cfg_reg_data  <= #TP {cfg_reg_35, cfg_reg_34, cfg_reg_33, cfg_reg_32};
            cfg_reg_id[9] : cfg_reg_data  <= #TP {cfg_reg_39, cfg_reg_38, cfg_reg_37, cfg_reg_36};
            cfg_reg_id[10]: cfg_reg_data  <= #TP {cfg_reg_43, cfg_reg_42, cfg_reg_41, cfg_reg_40};
            cfg_reg_id[11]: cfg_reg_data  <= #TP {cfg_reg_47, cfg_reg_46, cfg_reg_45, cfg_reg_44};
            cfg_reg_id[12]: cfg_reg_data  <= #TP {cfg_reg_51, cfg_reg_50, cfg_reg_49, cfg_reg_48};
            cfg_reg_id[13]: cfg_reg_data  <= #TP {cfg_reg_55, cfg_reg_54, cfg_reg_53, cfg_reg_52};
            cfg_reg_id[14]: cfg_reg_data  <= #TP {cfg_reg_59, cfg_reg_58, cfg_reg_57, cfg_reg_56};
            cfg_reg_id[15]: cfg_reg_data  <= #TP {cfg_reg_63, cfg_reg_62, cfg_reg_61, cfg_reg_60};
//L_UNCOVERED_330_1: reg_read_pulse==1 => |cfg_reg_id==1, remove line
            default:              cfg_reg_data  <= #TP `PCIE_UNUSED_RESPONSE;

            endcase
        end
        else
            cfg_reg_data    <= #TP cfg_reg_data;
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        cfg_cap_reg_data    <= #TP 0;
    else
        if (cap_reg_read_pulse) begin

          unique case (1'b1)

            |pm_reg_id[1:0]   : cfg_cap_reg_data  <= #TP pm_reg_data;
            |msi_reg_id[5:0]  : cfg_cap_reg_data  <= #TP msi_reg_data;
            cfg_cap_reg_id[6] : cfg_cap_reg_data  <= #TP {cfg_reg_91,  cfg_reg_90,  cfg_reg_89,  cfg_reg_88};
            cfg_cap_reg_id[7] : cfg_cap_reg_data  <= #TP {cfg_reg_95,  cfg_reg_94,  cfg_reg_93,  cfg_reg_92};
            cfg_cap_reg_id[8] : cfg_cap_reg_data  <= #TP {cfg_reg_99,  cfg_reg_98,  cfg_reg_97,  cfg_reg_96};
            cfg_cap_reg_id[9] : cfg_cap_reg_data  <= #TP {cfg_reg_103, cfg_reg_102, cfg_reg_101, cfg_reg_100};
            cfg_cap_reg_id[10]: cfg_cap_reg_data  <= #TP {cfg_reg_107, cfg_reg_106, cfg_reg_105, cfg_reg_104};
//L_UNCOVERED_330_2: ep => cfg_cap_reg_id[11:15]==0, rewrite address decoder process to allow toggle all bits of cfg_cap_reg_id, see next note
            cfg_cap_reg_id[11]: cfg_cap_reg_data  <= #TP {cfg_reg_111, cfg_reg_110, cfg_reg_109, cfg_reg_108};
            cfg_cap_reg_id[12]: cfg_cap_reg_data  <= #TP {cfg_reg_115, cfg_reg_114, cfg_reg_113, cfg_reg_112};
            cfg_cap_reg_id[13]: cfg_cap_reg_data  <= #TP {cfg_reg_119, cfg_reg_118, cfg_reg_117, cfg_reg_116};
            cfg_cap_reg_id[14]: cfg_cap_reg_data  <= #TP {cfg_reg_123, cfg_reg_122, cfg_reg_121, cfg_reg_120};
            cfg_cap_reg_id[15]: cfg_cap_reg_data  <= #TP {cfg_reg_127, cfg_reg_126, cfg_reg_125, cfg_reg_124};
            cfg_cap_reg_id[16]: cfg_cap_reg_data  <= #TP {cfg_reg_131, cfg_reg_130, cfg_reg_129, cfg_reg_128};
            cfg_cap_reg_id[17]: cfg_cap_reg_data  <= #TP {cfg_reg_135, cfg_reg_134, cfg_reg_133, cfg_reg_132};
            cfg_cap_reg_id[18]: cfg_cap_reg_data  <= #TP {cfg_reg_139, cfg_reg_138, cfg_reg_137, cfg_reg_136};
            cfg_cap_reg_id[22]: cfg_cap_reg_data  <= #TP {cfg_reg_143, cfg_reg_142, cfg_reg_141, cfg_reg_140};
            cfg_cap_reg_id[23]: cfg_cap_reg_data  <= #TP {cfg_reg_147, cfg_reg_146, cfg_reg_145, cfg_reg_144};
            cfg_cap_reg_id[29]: cfg_cap_reg_data  <= #TP {cfg_reg_151, cfg_reg_150, cfg_reg_149, cfg_reg_148};
            cfg_cap_reg_id[19]: cfg_cap_reg_data  <= #TP {cfg_reg_155, cfg_reg_154, cfg_reg_153, cfg_reg_152};
            cfg_cap_reg_id[20]: cfg_cap_reg_data  <= #TP {cfg_reg_167, cfg_reg_166, cfg_reg_165, cfg_reg_164};
            cfg_cap_reg_id[21]: cfg_cap_reg_data  <= #TP {cfg_reg_171, cfg_reg_170, cfg_reg_169, cfg_reg_168};
            cfg_cap_reg_id[26]: cfg_cap_reg_data  <= #TP 32'b0;
            cfg_cap_reg_id[27]: cfg_cap_reg_data  <= #TP 32'b0;
            cfg_cap_reg_id[28]: cfg_cap_reg_data  <= #TP 32'b0;
            default:            cfg_cap_reg_data  <= #TP `PCIE_UNUSED_RESPONSE;

            endcase
        end
        else
            cfg_cap_reg_data    <= #TP cfg_cap_reg_data;
end

// ack one cycle after lbc_cdm_cs is asserted
reg         ecfg_reg_sel_d;
reg [3:0]   write_pulse;

// =============================================================================
// MSI-X Table related logic
// =============================================================================

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_reg_ack         <= #TP 0;
        cfg_cap_reg_ack     <= #TP 0;
        cfg_reg_sel_d       <= #TP 0;
        cfg_cap_reg_sel_d   <= #TP 0;
        write_pulse         <= #TP 0;
        reg_read_pulse      <= #TP 0;
        cap_reg_read_pulse  <= #TP 0;
        ecfg_reg_sel_d      <= #TP 0;
    end else begin
        cfg_reg_sel_d       <= #TP (cfg_reg_sel);
        cfg_cap_reg_sel_d   <= #TP (cfg_cap_reg_sel);
        ecfg_reg_sel_d      <= #TP (ecfg_reg_sel);
        cfg_reg_ack         <= #TP cfg_reg_sel_d & cfg_reg_sel;
        cfg_cap_reg_ack     <= #TP cfg_cap_reg_sel_d & cfg_cap_reg_sel;
        write_pulse         <= #TP ((cfg_reg_sel & ~cfg_reg_sel_d) | (cfg_cap_reg_sel & !cfg_cap_reg_sel_d)) ? lbc_cdm_wr : 4'h0;
        reg_read_pulse      <= #TP cfg_reg_sel & ~cfg_reg_sel_d & (~|lbc_cdm_wr);
        cap_reg_read_pulse  <= #TP cfg_cap_reg_sel & ~cfg_cap_reg_sel_d & (~|lbc_cdm_wr);
    end
end

// =============================================================================
// PCIE Configuration Registers
// =============================================================================

//------------------------------------------------------------------------------
// Vendor ID / Device ID Register
// cfig_reg_id      - 0
// PCIE Offset      - 00h-03h
// Length           - 4 bytes
// Default value    - {`DEFAULT_DEVICE_ID, `DEFAULT_VENDOR_ID}
// Cfig register    - cfg_reg_0 - cfg_reg_3
//
// Read-Only register, but writable through DBI
//------------------------------------------------------------------------------
reg [15:0]      vendor_id;
reg [15:0]      device_id;
reg [15:0]      null_extended_cap_id;
reg  [3:0]      cxl_version;
reg [11:0]      next_cap_offset;

assign {cfg_reg_1, cfg_reg_0}   = vendor_id;
assign {cfg_reg_3, cfg_reg_2}   = device_id;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        vendor_id       <= #TP `DEFAULT_VENDOR_ID;
        device_id       <= #TP `DEFAULT_DEVICE_ID;
    end else begin
        vendor_id[7:0]  <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[0]) ? lbc_cdm_data[7:0]   : vendor_id[7:0];
        vendor_id[15:8] <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_reg_id[0]) ? lbc_cdm_data[15:8]  : vendor_id[15:8];
        device_id[7:0]  <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[0]) ? lbc_cdm_data[23:16] : device_id[7:0];
        device_id[15:8] <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_reg_id[0]) ? lbc_cdm_data[31:24] : device_id[15:8];

    end
end

//------------------------------------------------------------------------------
// Command Register - Control register
// cfig_reg_id      - 1
// PCIE Offset      - 04h-05h
// Length           - 2 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_5, cfg_reg_4
//------------------------------------------------------------------------------

reg cfg_io_space_en;
reg cfg_mem_space_en;
reg cfg_bus_master_en;
reg cfg_reg_perren;
reg cfg_reg_serren;
reg cfg_int_disable;
assign cfg_reg_4 = {1'b0, cfg_reg_perren, 3'b0, cfg_bus_master_en, cfg_mem_space_en, cfg_io_space_en};
assign cfg_reg_5 = {5'b0, cfg_int_disable, 1'b0, cfg_reg_serren};

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_io_space_en  <= #TP 0;
        cfg_mem_space_en <= #TP 0;
        cfg_bus_master_en<= #TP 0;
        cfg_reg_perren   <= #TP 0;
        cfg_reg_serren   <= #TP 0;
        cfg_int_disable  <= #TP 0;
    end else begin
        cfg_io_space_en  <= #TP !has_io_bar ? 0 :  write_pulse[0] & cfg_reg_id[1] ? lbc_cdm_data[0] : cfg_io_space_en;
        cfg_mem_space_en <= #TP !has_mem_bar ? 0 :  write_pulse[0] & cfg_reg_id[1] ? lbc_cdm_data[1] : cfg_mem_space_en;
        cfg_bus_master_en<= #TP write_pulse[0] & cfg_reg_id[1] ? lbc_cdm_data[2] : cfg_bus_master_en;
        cfg_reg_perren   <= #TP write_pulse[0] & cfg_reg_id[1] ? lbc_cdm_data[6] : cfg_reg_perren;
        cfg_reg_serren   <= #TP write_pulse[1] & cfg_reg_id[1] ? lbc_cdm_data[8] : cfg_reg_serren;
        cfg_int_disable  <= #TP write_pulse[1] & cfg_reg_id[1] ? lbc_cdm_data[10]: cfg_int_disable;
    end
end

// Detect a write of 1 to any of cfg_bus_master_en, cfg_mem_space_en or cfg_io_space_en
wire d0_active_detect;
assign d0_active_detect = write_pulse[0] && cfg_reg_id[1] && |lbc_cdm_data[2:0];
//------------------------------------------------------------------------------
// Status Register  - Status register
// cfig_reg_id      - 1
// PCIE Offset      - 06h-07h
// Length           - 2 bytes
// Default value    - 0010h
// Cfig register    - cfg_reg_7, cfg_reg_6
//------------------------------------------------------------------------------
//RO
reg detected_perr;
reg rcvd_serr;
reg rcvd_master_abt;
reg rcvd_target_abt;
reg signaled_target_abt;
reg master_data_perr;

assign cfg_reg_6 = {3'b0, 1'b1, int_msg_pending, 3'b0};

assign cfg_reg_7 = {detected_perr, rcvd_serr, rcvd_master_abt, rcvd_target_abt,
                    signaled_target_abt, 2'b0, master_data_perr};

  
                 
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        detected_perr       <= #TP 0;
        rcvd_serr           <= #TP 0;
        rcvd_master_abt     <= #TP 0;
        rcvd_target_abt     <= #TP 0;
        signaled_target_abt <= #TP 0;
        master_data_perr    <= #TP 0;
    end else begin
        detected_perr       <= #TP perr_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[31]) ? 1'b0
                                 : detected_perr;
        rcvd_serr           <= #TP signaled_sys_err_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[30]) ? 1'b0
                                 : rcvd_serr;
        rcvd_master_abt     <= #TP rcvd_master_abort_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[29]) ? 1'b0
                                 : rcvd_master_abt;

        rcvd_target_abt     <= #TP rcvd_target_abort_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[28]) ? 1'b0
                                 : rcvd_target_abt;

        signaled_target_abt <= #TP signaled_target_abort_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[27]) ? 1'b0
                                 : signaled_target_abt;

        master_data_perr    <= #TP master_data_perr_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[24]) ? 1'b0
                                 : master_data_perr;
    end
end


//------------------------------------------------------------------------------
// Revision ID Register
// cfig_reg_id      - 2
// PCIE Offset      - 08h
// Length           - 1 bytes
// Default value    - `DEFAULT_REV_ID
// Cfig register    - cfg_reg_8
//
// Read-Only register, but writable through DBI
//------------------------------------------------------------------------------
reg [7:0]   revision_id;
assign cfg_reg_8    = revision_id;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        revision_id <= #TP `DEFAULT_REV_ID;
    end else begin
        revision_id <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[2]) ? lbc_cdm_data[7:0] : revision_id;
    end
end

//------------------------------------------------------------------------------
// Class Code Register  - PCI class_code
// cfig_reg_id      - 2
// PCIE Offset      - 09h - 0Bh
// Length           - 3 bytes
// Default value    - {`BASE_CLASS_CODE, `SUB_CLASS_CODE, `IF_CODE}
// Cfig register    - cfg_reg_9, cfg_reg_10, cfg_reg_11
//------------------------------------------------------------------------------
reg [7:0]   cfg_prog_interface;
reg [7:0]   cfg_sub_class;
reg [7:0]   cfg_base_class;
assign cfg_reg_9    = cfg_prog_interface;
assign cfg_reg_10   = cfg_sub_class;
assign cfg_reg_11   = cfg_base_class;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_prog_interface  <= #TP `IF_CODE;
        cfg_sub_class       <= #TP `SUB_CLASS_CODE;
        cfg_base_class      <= #TP `BASE_CLASS_CODE;

    end else begin
        cfg_prog_interface  <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_reg_id[2]) ? lbc_cdm_data[15:8]  : cfg_prog_interface;
        cfg_sub_class       <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[2]) ? lbc_cdm_data[23:16] : cfg_sub_class;
        cfg_base_class      <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_reg_id[2]) ? lbc_cdm_data[31:24] : cfg_base_class;
    end
end

//------------------------------------------------------------------------------
// Cache line size  - set by system firmware and OS to system cache line size, no impact to PCIE
// cfig_reg_id      - 3
// PCIE Offset      - 0Ch
// Length           - 1 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_12
//
// No impact to PCIE, but should be implemented as a R/W register
//------------------------------------------------------------------------------
reg [7:0]   cache_line_size;

assign cfg_reg_12   = cache_line_size;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n)
        cache_line_size <= #TP 0;
    else
        cache_line_size <= #TP write_pulse[0] & cfg_reg_id[3] ? lbc_cdm_data[7:0] : cache_line_size;
end

//------------------------------------------------------------------------------
// PCI Master Latency Timer Register
// cfig_reg_id      - 3
// PCIE Offset      - 0Dh
// Length           - 1 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_13
//
// Hardwire to 0
//------------------------------------------------------------------------------

assign cfg_reg_13   = 8'b0;     // N/A for PCI-E

//------------------------------------------------------------------------------
// Header Type register - Configuration space type
// cfig_reg_id      - 3
// PCIE Offset      - 0Eh
// Length           - 1 bytes
// Default value    - {(NF != 1), 6'b0, bridge_device}
// Cfig register    - cfg_reg_14
//------------------------------------------------------------------------------
reg         multi_function;
wire[7:0]   cfg_hdr_type;
assign cfg_hdr_type    = {multi_function, 6'b0, ~type0};
assign      cfg_reg_14      = cfg_hdr_type;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        multi_function  <= #TP (NF != 1);
    end else if(!end_device) begin
        multi_function  <= #TP 1'b0;        //set to zero in the case of a DM product set to RC mode with NFUNC>1
    end else begin
        multi_function  <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[3]) ? lbc_cdm_data[23] : multi_function;
    end
end

//------------------------------------------------------------------------------
// BIST register    - Configuration space type
// cfig_reg_id      - 3
// PCIE Offset      - 0Fh
// Length           - 1 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_15
//
// BIST is not supported.
// Customer need to modify by creating an input from BIST block to this register
// to support BIST.
//------------------------------------------------------------------------------
assign      cfg_reg_15 = 0;                        // BIST not supported.

//------------------------------------------------------------------------------
// There are a maximum of 6 32-bit BARs.
// Limitations:
// Only BAR0, BAR2 or BAR4 can be 64-bit.
// If BAR0 is 64-bit, BAR1 has to be disabled.
// If BAR2 is 64-bit, BAR3 has to be disabled.
// If BAR4 is 64-bit, BAR5 has to be disabled.
// BAR1, BAR3 and BAR5 can only be 32-bit BARs.
// -----------------------------------------------------------------------------
// Common signals for BAR Start and BAR Mask update indication, for BAR limit
// register clock gating inference.

reg         rbar_ctrl_update_d;              // Delayed RBAR resize update
reg         cfg_bar_start_mask_write_d;      // Delayed write BAR start or mask
wire        cfg_bar_start_mask_write;        // write to BAR start or mask registers

assign      cfg_bar_start_mask_write = |write_pulse & |cfg_reg_id[9:4]; // write to BAR start or mask registers

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        rbar_ctrl_update_d <= #TP 1'b0; 
        cfg_bar_start_mask_write_d <= #TP 1'b0; 
    end else begin
        rbar_ctrl_update_d <= #TP rbar_ctrl_update;
        cfg_bar_start_mask_write_d <= #TP cfg_bar_start_mask_write;
    end
end
// -----------------------------------------------------------------------------
// Memory Base Address Register 0
// If this is a 64-bit address decoder, it will take the first two BARs (10h and 14h) to implement.
// cfig_reg_id      - 4
// PCIE Offset      - 10h
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_16 - cfg_reg_19
//
//     A write of 0xFFFF_FFFFF_FFFF_FFFF and a read of this register shall return at least a value of
//     0xFFFF_FFFF_FFF0_0000 to indicate that there is 1M of memory behind this BAR. Actual size of this should
//     be no less than 2Kbytes and data is expected to repeat until the memory limit is met.
// -----------------------------------------------------------------------------
reg         bar0_enabled;
reg         bar0_enabled_d;
wire        bar0_enabled_chg; // BAR0 mask enable changed state, affecting BAR0 limit register next state
wire        bar0_mask_writable;
wire        bar0_is_64bit;
reg         bar0_is_64bit_d;
wire        bar0_is_64bit_chg; // BAR0 is 64bit status changed, affecting BAR0 limit register next state
reg [63:0]  bar0_mask_i;
reg [63:0]  bar0_mask;
reg [31:0]  bar0_low;
reg [31:0]  bar0_high;
wire[63:0]  cfg_bar0_start;
reg [63:0]  cfg_bar0_limit;
wire        cfg_bar0_limit_en; // Indicates BAR0 limit register must be enabled
reg         cfg_bar0_io;
reg [1:0]   cfg_bar0_type;
reg         cfg_bar0_pref;

//L_UNCOVERED_330_5: bar0_mask_writable==0 => bar0_enabled==`DEFAULT_BAR0_ENABLED (0|1 for EP,SW, depending on config, always 0 for RC)
//L_UNCOVERED_330_5: Explaination: when bar0_enabled is fixed to one value and cannot be toggled 0|1 the associated if/else branches in the BAR process below cannot be both covered in same config.
//L_UNCOVERED_330_5: Fix: expensive/risky: rewrite the BAR process, first assign as if bar0_mask_writable==1 and then override at the end if bar0_mask_writable==0 (or max_coverage)
//L_UNCOVERED_330_5: Fix: cheaper: keep the BAR process as it is and use bar0_mask_writable = (`BAR0_MASK_WRITABLE | max_coverage)
//L_UNCOVERED_330_5: Fix: in both cases use a test to force max_coverage=1 and exercise bar0_enabled=0|1, 4ar0_is_64bit=0|1
//L_UNCOVERED_330_5: Fix: repeat teh above for all BARs
assign bar0_mask_writable   = `BAR0_MASK_WRITABLE;
assign bar0_is_64bit        = (cfg_bar0_type == 2'b10);
assign cfg_bar0_start       = {bar0_high, bar0_low};                            // actual valid BAR
assign cfg_bar0_mask        = bar0_mask;

assign bar0_enabled_chg = bar0_enabled ^ bar0_enabled_d; // BAR0 enabled changed state, affecting BAR0 limit next state
assign bar0_is_64bit_chg = bar0_is_64bit ^ bar0_is_64bit_d; // BAR0 is_64bit changed state, affecting BAR0 limit next state
assign cfg_bar0_limit_en = bar0_enabled_chg | bar0_is_64bit_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR0 limit register enable


// BAR0 enable, R/W via DBI
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_enabled <= #TP `DEFAULT_BAR0_ENABLED;
    end else begin
        bar0_enabled <= #TP (write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[4]) ? lbc_cdm_data[0] : bar0_enabled;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_enabled_d <= #TP `DEFAULT_BAR0_ENABLED;
        bar0_is_64bit_d <= #TP `DEFAULT_BAR0_ENABLED;
    end else begin
        bar0_enabled_d <= #TP bar0_enabled;
        bar0_is_64bit_d <= #TP bar0_is_64bit;
    end
end

// Fixed/Programable BAR0 mask
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_mask_i       <= #TP `BAR0_MASK;
    end
    else begin
        // Lower 32-bit of BAR0 mask
        bar0_mask_i[7:0]  <= #TP 8'hFF;
        bar0_mask_i[15:8] <= #TP (bar0_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[4]) ? lbc_cdm_data[15:8] : bar0_mask_i[15:8];
        bar0_mask_i[23:16]<= #TP (bar0_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[4]) ? lbc_cdm_data[23:16]: bar0_mask_i[23:16];
        bar0_mask_i[31:24]<= #TP (bar0_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[4]) ? lbc_cdm_data[31:24]: bar0_mask_i[31:24];

        // Upper 32-bit of BAR0 mask
        if (bar0_is_64bit) begin
            bar0_mask_i[39:32]<= #TP (bar0_mask_writable & write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[7:0]  : bar0_mask_i[39:32];
            bar0_mask_i[47:40]<= #TP (bar0_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[15:8] : bar0_mask_i[47:40];
            bar0_mask_i[55:48]<= #TP (bar0_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[23:16]: bar0_mask_i[55:48];
            bar0_mask_i[63:56]<= #TP (bar0_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[31:24]: bar0_mask_i[63:56];
        end else begin
            bar0_mask_i[63:32]<= #TP 32'h0;
        end
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar0_enabled) begin
     bar0_mask = 64'h00000000FFFFFFFF;
   end else if (cfg_rbar_bar_resizable[0]) begin
     bar0_mask = cfg_rbar_bar0_mask;
   end else begin
     bar0_mask = bar0_mask_i;
   end
end

// Cfg header base address register located at offset 10h

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_low        <= #TP 32'h0;
        cfg_bar0_limit  <= #TP 64'h0;
        cfg_bar0_io     <= #TP `MEM0_SPACE_DECODER;
        cfg_bar0_type   <= #TP `BAR0_TYPE;
        cfg_bar0_pref   <= #TP `PREFETCHABLE0;
    end
    else begin
        bar0_low[7:0]       <= #TP ~bar0_enabled ? 8'h1 : (write_pulse[0] & cfg_reg_id[4] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar0_mask[7:0]  ): bar0_low[7:0];
        bar0_low[15:8]      <= #TP ~bar0_enabled ? 8'h0 : (write_pulse[1] & cfg_reg_id[4] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar0_mask[15:8] ): bar0_low[15:8];
        bar0_low[23:16]     <= #TP ~bar0_enabled ? 8'h0 : (write_pulse[2] & cfg_reg_id[4] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar0_mask[23:16]): bar0_low[23:16];
        bar0_low[31:24]     <= #TP ~bar0_enabled ? 8'h0 : (write_pulse[3] & cfg_reg_id[4] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar0_mask[31:24]): bar0_low[31:24];
        cfg_bar0_limit[31:0]  <= #TP cfg_bar0_limit_en ? (~bar0_enabled ? 32'h0 : (cfg_bar0_start[31:0] | bar0_mask[31:0])) : cfg_bar0_limit[31:0];
        cfg_bar0_limit[63:32] <= #TP cfg_bar0_limit_en ? ((~bar0_enabled | ~bar0_is_64bit) ? 32'h0 : (cfg_bar0_start[63:32] | bar0_mask[63:32])) : cfg_bar0_limit[63:32];

        if (bar0_enabled) begin
            cfg_bar0_io     <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[4]) ? lbc_cdm_data[0]  : cfg_bar0_io;
            cfg_bar0_type   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[4]) ? lbc_cdm_data[2:1]: cfg_bar0_type;
            cfg_bar0_pref   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[4]) ? lbc_cdm_data[3]  : cfg_bar0_pref;
        end
        else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar0_io     <= #TP 0;
            cfg_bar0_type   <= #TP 0;
            cfg_bar0_pref   <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// Memory Base Address Register 1
// cfig_reg_id      - 4
// PCIE Offset      - 14h
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_20 - cfg_reg_23
// -----------------------------------------------------------------------------
reg         bar1_enabled;
reg         bar1_enabled_d;
wire        bar1_enabled_chg;
wire        bar1_mask_writable;
reg [31:0]  bar1_mask;
reg [31:0]  bar1_mask_i;
reg [31:0]  bar1_low;
wire[31:0]  cfg_bar1_start;
reg [31:0]  cfg_bar1_limit;
wire        cfg_bar1_limit_en; // Indicates BAR1 limit register must be enabled
reg         cfg_bar1_io;
reg [1:0]   cfg_bar1_type;
reg         cfg_bar1_pref;

assign bar1_mask_writable   = `BAR1_MASK_WRITABLE;
assign cfg_bar1_start       = bar1_low;
assign cfg_bar1_mask        = bar1_mask;

assign bar1_enabled_chg = bar1_enabled ^ bar1_enabled_d; // BAR1 enabled changed state, affecting BAR1 limit next state
assign cfg_bar1_limit_en = bar1_enabled_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR1 limit register enable


// BAR1 enable, R/W via DBI
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar1_enabled <= #TP `DEFAULT_BAR1_ENABLED;
    end
    else begin
        bar1_enabled <= #TP (write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[5] & ~bar0_is_64bit) ? lbc_cdm_data[0] : bar1_enabled;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar1_enabled_d <= #TP `DEFAULT_BAR1_ENABLED;
    end else begin
        bar1_enabled_d <= #TP bar1_enabled;
    end
end

// Fixed/Programmable BAR1 mask
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar1_mask_i       <= #TP `BAR1_MASK;
    end
    else begin
        // BAR1 mask
        bar1_mask_i[7:0]  <= #TP 8'hFF;
        bar1_mask_i[15:8] <= #TP (bar1_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[15:8] : bar1_mask_i[15:8];
        bar1_mask_i[23:16]<= #TP (bar1_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[23:16]: bar1_mask_i[23:16];
        bar1_mask_i[31:24]<= #TP (bar1_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[31:24]: bar1_mask_i[31:24];
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar1_enabled) begin
     bar1_mask = 0;
   end else if (cfg_rbar_bar_resizable[1]) begin
     bar1_mask = cfg_rbar_bar1_mask;
   end else begin
     bar1_mask = bar1_mask_i;
   end
end

// Cfg header base address register located at offset 14h

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_high       <= #TP 32'h0;
        bar1_low        <= #TP 32'h0;
        cfg_bar1_limit  <= #TP 32'h0;
        cfg_bar1_io     <= #TP `MEM1_SPACE_DECODER;
        cfg_bar1_type   <= #TP `BAR1_TYPE;
        cfg_bar1_pref   <= #TP `PREFETCHABLE1;
    end
    else begin
        // Upper 32-bit of BAR0
        if (bar0_enabled & bar0_is_64bit) begin
            bar0_high[7:0]  <= #TP (write_pulse[0] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar0_mask[39:32]): bar0_high[7:0];
            bar0_high[15:8] <= #TP (write_pulse[1] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar0_mask[47:40]): bar0_high[15:8];
            bar0_high[23:16]<= #TP (write_pulse[2] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar0_mask[55:48]): bar0_high[23:16];
            bar0_high[31:24]<= #TP (write_pulse[3] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar0_mask[63:56]): bar0_high[31:24];
        end
        else begin
            bar0_high       <= #TP 0;
        end

        // 32-bit of BAR1
        if (bar1_enabled) begin
            bar1_low[7:0]   <= #TP (write_pulse[0] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar1_mask[7:0]  ): bar1_low[7:0];
            bar1_low[15:8]  <= #TP (write_pulse[1] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar1_mask[15:8] ): bar1_low[15:8];
            bar1_low[23:16] <= #TP (write_pulse[2] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar1_mask[23:16]): bar1_low[23:16];
            bar1_low[31:24] <= #TP (write_pulse[3] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar1_mask[31:24]): bar1_low[31:24];
        end
        else begin
            bar1_low        <= #TP 32'h1;
        end
        cfg_bar1_limit[31:0]<= #TP cfg_bar1_limit_en ? (~bar1_enabled ? 32'h0 : (cfg_bar1_start[31:0] | bar1_mask[31:0])) : cfg_bar1_limit[31:0];
        if (bar1_enabled) begin
            cfg_bar1_io     <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[5]) ? lbc_cdm_data[0]  : cfg_bar1_io;
            cfg_bar1_type   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[5]) ? lbc_cdm_data[2:1]: cfg_bar1_type;
            cfg_bar1_pref   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[5]) ? lbc_cdm_data[3]  : cfg_bar1_pref;
        end else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar1_io     <= #TP 0;
            cfg_bar1_type   <= #TP 0;
            cfg_bar1_pref   <= #TP 0;
        end
    end
end


assign {cfg_reg_23, cfg_reg_22, cfg_reg_21, cfg_reg_20} = bar1_enabled ? {cfg_bar1_start[31:4], cfg_bar1_pref, cfg_bar1_type, cfg_bar1_io}
                                                                       : cfg_bar0_start[63:32];
assign {cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16} = {cfg_bar0_start[31:4], cfg_bar0_pref, cfg_bar0_type, cfg_bar0_io};

// -----------------------------------------------------------------------------
// THE FOLLOWING REGISTERS ARE HEADER TYPE SPECIFIC
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Type 0: Memory Base Address Register 2
// If this is a 64-bit address decoder, it will take the next two BARs (18h and 1Ch) to implement.
// Type 1: 2nd Latency Timer, Subordinate Bus Number, 2nd Bus Number and Primary Bus Number
// cfig_reg_id      - 6
// PCIE Offset      - 18h
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_24 - cfg_reg_27
// -----------------------------------------------------------------------------
reg         bar2_enabled;
reg         bar2_enabled_d;
wire        bar2_enabled_chg; // BAR2 mask enable changed state, affecting BAR2 limit register next state
wire        bar2_mask_writable;
wire        bar2_is_64bit;
reg         bar2_is_64bit_d;
wire        bar2_is_64bit_chg; // BAR2 is 64bit status changed, affecting BAR2 limit register next state
reg [63:0]  bar2_mask;
reg [63:0]  bar2_mask_i;
reg [31:0]  bar2_low;
reg [31:0]  bar2_high;
wire[63:0]  cfg_bar2_start;
reg [63:0]  cfg_bar2_limit;
wire        cfg_bar2_limit_en; // Indicates BAR2 limit register must be enabled
reg         cfg_bar2_io;
reg [1:0]   cfg_bar2_type;
reg         cfg_bar2_pref;
wire [4:0]  int_dev_num;
wire [7:0]  int_bus_num;

// Get Bus or device input from application when not in EP mode
// Default value for device and bus number is set by the application*
assign int_dev_num = app_dev_num;
// for RC/SW_DW get the application bus num, and for bridge devices the cfg_pbus_num_reg Type 1 reg
assign int_bus_num = (bridge_device) ? cfg_pbus_num_reg : app_bus_num;


assign bar2_mask_writable   = `BAR2_MASK_WRITABLE;
assign bar2_is_64bit        = (cfg_bar2_type == 2'b10);
assign cfg_bar2_start       = {bar2_high, bar2_low};                            // actual valid BAR
assign cfg_bar2_mask        = bar2_mask;

assign bar2_enabled_chg = bar2_enabled ^ bar2_enabled_d; // BAR2 enabled changed state, affecting BAR2 limit next state
assign bar2_is_64bit_chg = bar2_is_64bit ^ bar2_is_64bit_d; // BAR2 is_64bit changed state, affecting BAR2 limit next state
assign cfg_bar2_limit_en = bar2_enabled_chg | bar2_is_64bit_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR2 limit register enable

   assign {cfg_reg_27, cfg_reg_26, cfg_reg_25, cfg_reg_24} = type0 ? {cfg_bar2_start[31:4], cfg_bar2_pref, cfg_bar2_type, cfg_bar2_io} : {8'b0, cfg_subbus_num, cfg_2ndbus_num, cfg_pbus_num_reg};

// Type 1
reg [4:0]   cfg_pbus_dev_num;
reg         cfg_upd_req_id;     // update the shadow register in PMC
reg [7:0]   cfg_pbus_num;

// bus number and dev number need to be updated constantly
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_pbus_num_reg            <= #TP 0;
        cfg_2ndbus_num              <= #TP 0;
        cfg_subbus_num              <= #TP 0;
        cfg_pbus_dev_num            <= #TP 0;
        cfg_pbus_num                <= #TP 0;
        cfg_upd_req_id              <= #TP 0;
    end else begin
        // If it's an in-band write or a write to pribus # and it's a RC/SW_dn, update it
        if (SNOOP_REG) begin
          cfg_upd_req_id      <= #TP (radm_snoop_upd[FUNC_NUM] & !bridge_device) | ((rc_device | pcie_sw_down | bridge_device) & write_pulse[0] & cfg_reg_id[6]);
        end else begin
          cfg_upd_req_id      <= #TP ((rc_device | pcie_sw_down | bridge_device) & write_pulse[0] & cfg_reg_id[6]);
        end

        // RW register, only used to be compatible with PCI.
        cfg_pbus_num_reg    <= #TP write_pulse[0] & cfg_reg_id[6] ? lbc_cdm_data[7:0]      // direct write
                                    : cfg_pbus_num_reg;
        // Snooped bus number when non RC/SW_DW.
        if (SNOOP_REG) begin
            // If upstream device and not a bridge device, get the snooped bus number, else get the internally generated bus number 
           cfg_pbus_num                <= #TP (upstream_port & (!bridge_device) ) ? (radm_snoop_upd[FUNC_NUM] ? radm_snoop_bus_num : cfg_pbus_num) : int_bus_num;
        end else begin
          cfg_pbus_num                 <= #TP 0;
        end
        if (SNOOP_REG) begin
            // If RC/switch downstream port, or PCIE_PCIX , get the int_dev_num , else get snooped device number
           cfg_pbus_dev_num    <= #TP (rc_device | pcie_sw_down | pcie_br_up) ? int_dev_num : (radm_snoop_upd[FUNC_NUM] ) ? radm_snoop_dev_num : cfg_pbus_dev_num;   // snooping
        end else begin
          cfg_pbus_dev_num    <= #TP 0;
        end
        cfg_2ndbus_num      <= #TP ~type0 & write_pulse[1] & cfg_reg_id[6] ? lbc_cdm_data[15:8] : cfg_2ndbus_num;
        cfg_subbus_num      <= #TP ~type0 & write_pulse[2] & cfg_reg_id[6] ? lbc_cdm_data[23:16] : cfg_subbus_num;
    end
end



// BAR2 enable, R/W via DBI
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_enabled    <= #TP `DEFAULT_BAR2_ENABLED;
    end else begin
        bar2_enabled    <= #TP !type0 ? 0 : (type0 & lbc_cdm_dbi2 & write_pulse[0] & cfg_reg_id[6]) ? lbc_cdm_data[0] : bar2_enabled;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_enabled_d <= #TP `DEFAULT_BAR2_ENABLED;
        bar2_is_64bit_d <= #TP `DEFAULT_BAR2_ENABLED;
    end else begin
        bar2_enabled_d <= #TP bar2_enabled;
        bar2_is_64bit_d <= #TP bar2_is_64bit;
    end
end

// Fixed/Programmable BAR2 mask, type 0 only.
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_mask_i       <= #TP `BAR2_MASK;
    end else begin
        // Lower 32-bit of BAR2 mask
        bar2_mask_i[7:0]  <= #TP 8'hFF;
        bar2_mask_i[15:8] <= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[1] & cfg_reg_id[6]) ? lbc_cdm_data[15:8] : bar2_mask_i[15:8];
        bar2_mask_i[23:16]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[2] & cfg_reg_id[6]) ? lbc_cdm_data[23:16]: bar2_mask_i[23:16];
        bar2_mask_i[31:24]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[3] & cfg_reg_id[6]) ? lbc_cdm_data[31:24]: bar2_mask_i[31:24];

        // Upper 32-bit of BAR2 mask
        if (bar2_is_64bit) begin
            bar2_mask_i[39:32]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[0] & cfg_reg_id[7]) ? lbc_cdm_data[7:0]  : bar2_mask_i[39:32];
            bar2_mask_i[47:40]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[1] & cfg_reg_id[7]) ? lbc_cdm_data[15:8] : bar2_mask_i[47:40];
            bar2_mask_i[55:48]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[2] & cfg_reg_id[7]) ? lbc_cdm_data[23:16]: bar2_mask_i[55:48];
            bar2_mask_i[63:56]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[3] & cfg_reg_id[7]) ? lbc_cdm_data[31:24]: bar2_mask_i[63:56];
        end else begin
            bar2_mask_i[63:32]<= #TP 32'h0;
        end
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar2_enabled) begin
     bar2_mask = 64'h00000000FFFFFFFF;
   end else if (cfg_rbar_bar_resizable[2]) begin
     bar2_mask = cfg_rbar_bar2_mask;
   end else begin
    bar2_mask = bar2_mask_i;
   end
end

// Cfg header base address register 2, located at offset 18h, type 0 only.

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_low        <= #TP 32'b0;
        cfg_bar2_limit  <= #TP 64'h0;
        cfg_bar2_io     <= #TP `MEM2_SPACE_DECODER;
        cfg_bar2_type   <= #TP `BAR2_TYPE;
        cfg_bar2_pref   <= #TP `PREFETCHABLE2;
    end else begin
        bar2_low[7:0]       <= #TP ~bar2_enabled ? 8'h1 : (type0 & write_pulse[0] & cfg_reg_id[6] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar2_mask[7:0]  ): bar2_low[7:0];
        bar2_low[15:8]      <= #TP ~bar2_enabled ? 8'h0 : (type0 & write_pulse[1] & cfg_reg_id[6] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar2_mask[15:8] ): bar2_low[15:8];
        bar2_low[23:16]     <= #TP ~bar2_enabled ? 8'h0 : (type0 & write_pulse[2] & cfg_reg_id[6] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar2_mask[23:16]): bar2_low[23:16];
        bar2_low[31:24]     <= #TP ~bar2_enabled ? 8'h0 : (type0 & write_pulse[3] & cfg_reg_id[6] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar2_mask[31:24]): bar2_low[31:24];

        cfg_bar2_limit[31:0]<= #TP cfg_bar2_limit_en ? (~bar2_enabled ? 32'h0 : (cfg_bar2_start[31:0] | bar2_mask[31:0])) : cfg_bar2_limit[31:0];
        cfg_bar2_limit[63:32]<= #TP cfg_bar2_limit_en ? ((~bar2_enabled | ~bar2_is_64bit) ? 32'h0 : (cfg_bar2_start[63:32] | bar2_mask[63:32])) : cfg_bar2_limit[63:32];

        if (bar2_enabled) begin
            cfg_bar2_io     <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[6]) ? lbc_cdm_data[0]  : cfg_bar2_io;
            cfg_bar2_type   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[6]) ? lbc_cdm_data[2:1]: cfg_bar2_type;
            cfg_bar2_pref   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[6]) ? lbc_cdm_data[3]  : cfg_bar2_pref;
        end
        else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar2_io     <= #TP 0;
            cfg_bar2_type   <= #TP 0;
            cfg_bar2_pref   <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// Type 1: 2nd Status register, I/O limit, I/O Base
// Type 0: Memory Reg Base Address register 3
// cfig_reg_id      - 7
// PCIE Offset      - 1Ch
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_28 - cfg_reg_31
// -----------------------------------------------------------------------------
// Type 0
reg         bar3_enabled;
reg         bar3_enabled_d;
wire        bar3_enabled_chg;
wire        bar3_mask_writable;
reg [31:0]  bar3_mask;
reg [31:0]  bar3_mask_i;
reg [31:0]  bar3_low;
wire[31:0]  cfg_bar3_start;
reg [31:0]  cfg_bar3_limit;
wire        cfg_bar3_limit_en; // Indicates BAR3 limit register must be enabled
reg         cfg_bar3_io;
reg [1:0]   cfg_bar3_type;
reg         cfg_bar3_pref;
assign bar3_mask_writable   = `BAR3_MASK_WRITABLE;
assign cfg_bar3_start       = bar3_low;
assign cfg_bar3_mask        = bar3_mask;

assign bar3_enabled_chg = bar3_enabled ^ bar3_enabled_d; // BAR3 enabled changed state, affecting BAR3 limit next state
assign cfg_bar3_limit_en = bar3_enabled_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR3 limit register enable

// Type 1
reg         detected_perr2;
reg         rcvd_serr2;
reg         rcvd_master_abt2;
reg         rcvd_target_abt2;
reg         signaled_target_abt2;
reg         master_data_perr2;
reg         io_is_32bit;
reg [3:0]   io_base;
reg [3:0]   io_limit;
wire[7:0]   cfg_io_base;
wire[7:0]   cfg_io_limit;

assign cfg_io_base  = {io_base,  3'b0, io_is_32bit};
assign cfg_io_limit = {io_limit, 3'b0, io_is_32bit};

assign cfg_reg_31 =  type0 ? (bar3_enabled ? cfg_bar3_start[31:24] : cfg_bar2_start[63:56])
                            : {detected_perr2, rcvd_serr2, rcvd_master_abt2, rcvd_target_abt2,
                               signaled_target_abt2, 2'b00, master_data_perr2}; 

assign cfg_reg_30 = type0 ? (bar3_enabled ? cfg_bar3_start[23:16] : cfg_bar2_start[55:48]) : 8'b0;

assign cfg_reg_29 =type0 ? (bar3_enabled ? cfg_bar3_start[15:8]  : cfg_bar2_start[47:40]) : cfg_io_limit; 

assign cfg_reg_28 = type0 ? (bar3_enabled ? {cfg_bar3_start[7:4], cfg_bar3_pref, cfg_bar3_type, cfg_bar3_io}: cfg_bar2_start[39:32]) : cfg_io_base; 


//// for master data parity error of secondary bus
//wire rcvd_cpl_poisoned_secondary    = !upstream_port & radm_rcvd_cpl_poisoned;
//wire xmt_wreq_poisoned_secondary    = !upstream_port & xtlh_xmt_wreq_poisoned;
//
//// for signaled target abort of secondary bus
//wire xmt_cpl_ca_secondary           = !upstream_port & xal_xmt_cpl_ca;
//
//// for received target abort of secondary bus
//wire rcvd_cpl_ca_secondary          = !upstream_port & radm_rcvd_cpl_ca;
//
//// for received master abort of second bus
//wire rcvd_cpl_ur_secondary          = !upstream_port & radm_rcvd_cpl_ur;
//

//// for signaled system error of second bus
//wire rcvd_serr_secondary            = (send_nf_err | send_f_err);

//
//// for detected parity error
//wire rcvd_wreq_poisoned_secondary   = !upstream_port & radm_rcvd_wreq_poisoned;


// Type 1
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        io_is_32bit             <= #TP `IO_DECODE_32;
        io_base                 <= #TP 0;
        io_limit                <= #TP 0;
        detected_perr2          <= #TP 0;
        rcvd_serr2              <= #TP 0;
        rcvd_master_abt2        <= #TP 0;
        rcvd_target_abt2        <= #TP 0;
        signaled_target_abt2    <= #TP 0;
        master_data_perr2       <= #TP 0;
    end else begin
        if (~type0) begin
            io_is_32bit             <= #TP write_pulse[0] & cfg_reg_id[7] & int_lbc_cdm_dbi ? lbc_cdm_data[0] : io_is_32bit;
            io_base                 <= #TP write_pulse[0] & cfg_reg_id[7] ? lbc_cdm_data[7:4]   : io_base;
            io_limit                <= #TP write_pulse[1] & cfg_reg_id[7] ? lbc_cdm_data[15:12] : io_limit;

            detected_perr2          <= #TP perr_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[31]) ? 1'b0 :  detected_perr2;

            rcvd_serr2              <= #TP signaled_sys_err_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[30]) ? 1'b0 : rcvd_serr2;

            rcvd_master_abt2        <= #TP rcvd_master_abort_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[29]) ? 1'b0 : rcvd_master_abt2;

            rcvd_target_abt2        <= #TP rcvd_target_abort_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[28]) ? 1'b0 : rcvd_target_abt2;

            signaled_target_abt2    <= #TP signaled_target_abort_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[27]) ? 1'b0 : signaled_target_abt2;

            master_data_perr2       <= #TP master_data_perr_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[24]) ? 1'b0 : master_data_perr2;
        end else begin
            io_is_32bit             <= #TP `IO_DECODE_32;
            io_base                 <= #TP 0;
            io_limit                <= #TP 0;
            detected_perr2          <= #TP 0;
            rcvd_serr2              <= #TP 0;
            rcvd_master_abt2        <= #TP 0;
            rcvd_target_abt2        <= #TP 0;
            signaled_target_abt2    <= #TP 0;
            master_data_perr2       <= #TP 0;
        end
    end // else: !if(!non_sticky_rst_n)
end // always @ (posedge core_clk or negedge non_sticky_rst_n)


// BAR3 enable
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar3_enabled <= #TP `DEFAULT_BAR3_ENABLED;
    end else begin
        bar3_enabled <= #TP !type0 ? 0 : (type0 & write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[7] & ~bar2_is_64bit) ? lbc_cdm_data[0] : bar3_enabled;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar3_enabled_d <= #TP `DEFAULT_BAR3_ENABLED;
    end else begin
        bar3_enabled_d <= #TP bar3_enabled;
    end
end

// Fixed/Programmable BAR3 mask, type 0 only.
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar3_mask_i       <= #TP `BAR3_MASK;
    end else begin
        // BAR3 mask
        bar3_mask_i[7:0]  <= #TP 8'hFF;
        bar3_mask_i[15:8] <= #TP (bar3_mask_writable & type0 & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[7]) ? lbc_cdm_data[15:8] : bar3_mask_i[15:8];
        bar3_mask_i[23:16]<= #TP (bar3_mask_writable & type0 & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[7]) ? lbc_cdm_data[23:16]: bar3_mask_i[23:16];
        bar3_mask_i[31:24]<= #TP (bar3_mask_writable & type0 & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[7]) ? lbc_cdm_data[31:24]: bar3_mask_i[31:24];
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar3_enabled) begin
     bar3_mask = 0;
   end else if (cfg_rbar_bar_resizable[3]) begin
     bar3_mask = cfg_rbar_bar3_mask;
   end else begin
     bar3_mask = bar3_mask_i;
   end
end

// Cfg header base address register 3, located at offset 1Ch, type 0 only.

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_high       <= #TP 32'h0;
        bar3_low        <= #TP 32'h0;
        cfg_bar3_limit  <= #TP 32'h0;
        cfg_bar3_io     <= #TP `MEM3_SPACE_DECODER;
        cfg_bar3_type   <= #TP `BAR3_TYPE;
        cfg_bar3_pref   <= #TP `PREFETCHABLE3;
    end else begin
        // Upper 32-bit of BAR2
        if (bar2_enabled & bar2_is_64bit) begin
            bar2_high[7:0]  <= #TP (type0 & write_pulse[0] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar2_mask[39:32]) : bar2_high[7:0];
            bar2_high[15:8] <= #TP (type0 & write_pulse[1] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar2_mask[47:40]) : bar2_high[15:8];
            bar2_high[23:16]<= #TP (type0 & write_pulse[2] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar2_mask[55:48]) : bar2_high[23:16];
            bar2_high[31:24]<= #TP (type0 & write_pulse[3] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar2_mask[63:56]) : bar2_high[31:24];
        end
        else begin
            bar2_high       <= #TP 0;
        end

        // 32-bit of BAR3
        if (bar3_enabled) begin
            bar3_low[7:0]   <= #TP (write_pulse[0] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar3_mask[7:0]  ): bar3_low[7:0];
            bar3_low[15:8]  <= #TP (write_pulse[1] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar3_mask[15:8] ): bar3_low[15:8];
            bar3_low[23:16] <= #TP (write_pulse[2] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar3_mask[23:16]): bar3_low[23:16];
            bar3_low[31:24] <= #TP (write_pulse[3] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar3_mask[31:24]): bar3_low[31:24];
        end
        else begin
            bar3_low        <= #TP 32'h1;
        end

        cfg_bar3_limit[31:0]<= #TP cfg_bar3_limit_en ? (~bar3_enabled ? 32'h0 : (cfg_bar3_start[31:0] | bar3_mask[31:0])) : cfg_bar3_limit[31:0];

        if (bar3_enabled) begin
            cfg_bar3_io     <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[7]) ? lbc_cdm_data[0]  : cfg_bar3_io;
            cfg_bar3_type   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[7]) ? lbc_cdm_data[2:1]: cfg_bar3_type;
            cfg_bar3_pref   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[7]) ? lbc_cdm_data[3]  : cfg_bar3_pref;
        end else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar3_io     <= #TP 0;
            cfg_bar3_type   <= #TP 0;
            cfg_bar3_pref   <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// Note: 24h is not implemented for Type 0 header as PCI Base Address Registers at default
// Implemented at vendors discretion
// -----------------------------------------------------------------------------
// Type 1: Memory Limit, Memory Base, Prefetchable Memory Limit, Prefetchable memory Base
// Type 0: Memory Reg Base Address register 4, Memory Reg Base Address register 5
// cfig_reg_id      - 8,9
// PCIE Offset      - 20h - 27h
// Length           - 8 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_32 - cfg_reg_39
// -----------------------------------------------------------------------------
// Type 0
reg         bar4_enabled;
reg         bar4_enabled_d;
wire        bar4_enabled_chg; // BAR4 mask enable changed state, affecting BAR4 limit register next state
wire        bar4_mask_writable;
wire        bar4_is_64bit;
reg         bar4_is_64bit_d;
wire        bar4_is_64bit_chg; // BAR4 is 64bit status changed, affecting BAR4 limit register next state
reg [63:0]  bar4_mask;
reg [63:0]  bar4_mask_i;
reg [31:0]  bar4_low;
reg [31:0]  bar4_high;
wire[63:0]  cfg_bar4_start;
reg [63:0]  cfg_bar4_limit;
wire        cfg_bar4_limit_en; // Indicates BAR4 limit register must be enabled
reg         cfg_bar4_io;
reg [1:0]   cfg_bar4_type;
reg         cfg_bar4_pref;

assign bar4_mask_writable   = `BAR4_MASK_WRITABLE;
assign bar4_is_64bit        = (cfg_bar4_type == 2'b10);
assign cfg_bar4_start       = {bar4_high, bar4_low};                            // actual valid BAR
assign cfg_bar4_mask        = bar4_mask;

assign bar4_enabled_chg = bar4_enabled ^ bar4_enabled_d; // BAR4 enabled changed state, affecting BAR4 limit next state
assign bar4_is_64bit_chg = bar4_is_64bit ^ bar4_is_64bit_d; // BAR4 is_64bit changed state, affecting BAR4 limit next state
assign cfg_bar4_limit_en = bar4_enabled_chg | bar4_is_64bit_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR4 limit register enable

// BAR4 enable
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_enabled <= #TP `DEFAULT_BAR4_ENABLED;
    end
    else begin
        bar4_enabled <= #TP !type0 ? 0 : (type0 & lbc_cdm_dbi2 & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[0] : bar4_enabled;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_enabled_d <= #TP `DEFAULT_BAR4_ENABLED;
        bar4_is_64bit_d <= #TP `DEFAULT_BAR4_ENABLED;
    end else begin
        bar4_enabled_d <= #TP bar4_enabled;
        bar4_is_64bit_d <= #TP bar4_is_64bit;
    end
end

// BAR4 mask
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_mask_i       <= #TP `BAR4_MASK;
    end
    else begin
        // Lower 32-bit of BAR4 mask
        bar4_mask_i[7:0]  <= #TP 8'hFF;
        bar4_mask_i[15:8] <= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[1] & cfg_reg_id[8]) ? lbc_cdm_data[15:8] : bar4_mask_i[15:8];
        bar4_mask_i[23:16]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[2] & cfg_reg_id[8]) ? lbc_cdm_data[23:16]: bar4_mask_i[23:16];
        bar4_mask_i[31:24]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[3] & cfg_reg_id[8]) ? lbc_cdm_data[31:24]: bar4_mask_i[31:24];

        // Upper 32-bit of BAR4 mask
        if (bar4_is_64bit) begin
            bar4_mask_i[39:32]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[7:0]  : bar4_mask_i[39:32];
            bar4_mask_i[47:40]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[1] & cfg_reg_id[9]) ? lbc_cdm_data[15:8] : bar4_mask_i[47:40];
            bar4_mask_i[55:48]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[2] & cfg_reg_id[9]) ? lbc_cdm_data[23:16]: bar4_mask_i[55:48];
            bar4_mask_i[63:56]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[3] & cfg_reg_id[9]) ? lbc_cdm_data[31:24]: bar4_mask_i[63:56];
        end else begin
            bar4_mask_i[63:32]<= #TP 32'h0;
        end
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar4_enabled) begin
     bar4_mask = 64'h00000000FFFFFFFF;
   end else if (cfg_rbar_bar_resizable[4]) begin
     bar4_mask = cfg_rbar_bar4_mask;
   end else begin
     bar4_mask = bar4_mask_i;
   end
end

// Cfg header base address register 4, located at offset 20h, type 0 only.

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_low        <= #TP 32'h0;
        cfg_bar4_limit  <= #TP 64'h0;
        cfg_bar4_io     <= #TP `MEM4_SPACE_DECODER;
        cfg_bar4_type   <= #TP `BAR4_TYPE;
        cfg_bar4_pref   <= #TP `PREFETCHABLE4;
    end
    else begin
        bar4_low[7:0]       <= #TP ~bar4_enabled ? 8'h1 : (type0 & write_pulse[0] & cfg_reg_id[8] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]  & ~bar4_mask[7:0]  ): bar4_low[7:0];
        bar4_low[15:8]      <= #TP ~bar4_enabled ? 8'h0 : (type0 & write_pulse[1] & cfg_reg_id[8] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8] & ~bar4_mask[15:8] ): bar4_low[15:8];
        bar4_low[23:16]     <= #TP ~bar4_enabled ? 8'h0 : (type0 & write_pulse[2] & cfg_reg_id[8] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16]& ~bar4_mask[23:16]): bar4_low[23:16];
        bar4_low[31:24]     <= #TP ~bar4_enabled ? 8'h0 : (type0 & write_pulse[3] & cfg_reg_id[8] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24]& ~bar4_mask[31:24]): bar4_low[31:24];

        cfg_bar4_limit[31:0]<= #TP cfg_bar4_limit_en ? (~bar4_enabled ? 32'h0 : (cfg_bar4_start[31:0] | bar4_mask[31:0])) : cfg_bar4_limit[31:0];
        cfg_bar4_limit[63:32]<= #TP cfg_bar4_limit_en ? ((~bar4_enabled | (bar4_enabled & ~bar4_is_64bit)) ? 32'h0 : (cfg_bar4_start[63:32] | bar4_mask[63:32])) : cfg_bar4_limit[63:32];

        if (bar4_enabled) begin
            cfg_bar4_io     <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[0]  : cfg_bar4_io;
            cfg_bar4_type   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[2:1]: cfg_bar4_type;
            cfg_bar4_pref   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[3]  : cfg_bar4_pref;
        end
        else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar4_io     <= #TP 0;
            cfg_bar4_type   <= #TP 0;
            cfg_bar4_pref   <= #TP 0;
        end
    end
end

reg         bar5_enabled;
reg         bar5_enabled_d;
wire        bar5_enabled_chg;
wire        bar5_mask_writable;
reg [31:0]  bar5_mask;
reg [31:0]  bar5_mask_i;
reg [31:0]  bar5_low;
wire[31:0]  cfg_bar5_start;
reg [31:0]  cfg_bar5_limit;
wire        cfg_bar5_limit_en; // Indicates BAR5 limit register must be enabled
reg         cfg_bar5_io;
reg [1:0]   cfg_bar5_type;
reg         cfg_bar5_pref;

assign bar5_mask_writable   = `BAR5_MASK_WRITABLE;
assign cfg_bar5_start       = bar5_low;
assign cfg_bar5_mask        = bar5_mask;

assign bar5_enabled_chg = bar5_enabled ^ bar5_enabled_d; // BAR5 enabled changed state, affecting BAR5 limit next state
assign cfg_bar5_limit_en = bar5_enabled_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR5 limit register enable


// BAR5 enable
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar5_enabled <= #TP `DEFAULT_BAR5_ENABLED;
    end
    else begin
        bar5_enabled <= #TP !type0 ? 0 : (write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[9] & ~bar4_is_64bit) ? lbc_cdm_data[0] : bar5_enabled;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar5_enabled_d <= #TP `DEFAULT_BAR5_ENABLED;
    end else begin
        bar5_enabled_d <= #TP bar5_enabled;
    end
end

// BAR5 mask
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar5_mask_i       <= #TP `BAR5_MASK;
    end
    else begin
        // BAR5 mask
        bar5_mask_i[7:0]  <= #TP 8'hFF;
        bar5_mask_i[15:8] <= #TP (bar5_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[9]) ? lbc_cdm_data[15:8] : bar5_mask_i[15:8];
        bar5_mask_i[23:16]<= #TP (bar5_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[9]) ? lbc_cdm_data[23:16]: bar5_mask_i[23:16];
        bar5_mask_i[31:24]<= #TP (bar5_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[9]) ? lbc_cdm_data[31:24]: bar5_mask_i[31:24];
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar5_enabled) begin
     bar5_mask = 0;
   end else if (cfg_rbar_bar_resizable[5]) begin
     bar5_mask = cfg_rbar_bar5_mask;
   end else begin
     bar5_mask = bar5_mask_i;
   end
end

// Cfg header base address register 5, located at offset 24h, type 0 only.

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_high       <= #TP 32'h0;
        bar5_low        <= #TP 32'h0;
        cfg_bar5_limit  <= #TP 32'h0;
        cfg_bar5_io     <= #TP `MEM5_SPACE_DECODER;
        cfg_bar5_type   <= #TP `BAR5_TYPE;
        cfg_bar5_pref   <= #TP `PREFETCHABLE5;
    end
    else begin
        // Upper 32-bit of BAR4
        if (bar4_enabled & bar4_is_64bit) begin
            bar4_high[7:0]  <= #TP (write_pulse[0] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar4_mask[39:32]): bar4_high[7:0];
            bar4_high[15:8] <= #TP (write_pulse[1] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar4_mask[47:40]): bar4_high[15:8];
            bar4_high[23:16]<= #TP (write_pulse[2] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar4_mask[55:48]): bar4_high[23:16];
            bar4_high[31:24]<= #TP (write_pulse[3] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar4_mask[63:56]): bar4_high[31:24];
        end
        else begin
            bar4_high       <= #TP 0;
        end

        // 32-bit of BAR5
        if (bar5_enabled) begin
            bar5_low[7:0]   <= #TP (write_pulse[0] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar5_mask[7:0]  ): bar5_low[7:0];
            bar5_low[15:8]  <= #TP (write_pulse[1] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar5_mask[15:8] ): bar5_low[15:8];
            bar5_low[23:16] <= #TP (write_pulse[2] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar5_mask[23:16]): bar5_low[23:16];
            bar5_low[31:24] <= #TP (write_pulse[3] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar5_mask[31:24]): bar5_low[31:24];
        end
        else begin
            bar5_low        <= #TP 32'h1;
        end

        cfg_bar5_limit[31:0]<= #TP cfg_bar5_limit_en ? (~bar5_enabled ? 32'h0 : (cfg_bar5_start[31:0] | bar5_mask[31:0])) : cfg_bar5_limit[31:0];

        if (bar5_enabled) begin
            cfg_bar5_io     <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[0]  : cfg_bar5_io;
            cfg_bar5_type   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[2:1]: cfg_bar5_type;
            cfg_bar5_pref   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[3]  : cfg_bar5_pref;
        end else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar5_io     <= #TP 0;
            cfg_bar5_type   <= #TP 0;
            cfg_bar5_pref   <= #TP 0;
        end
    end
end


// Type 1
reg [11:0]  mem_base;
reg [11:0]  mem_limit;
reg         mem_is_64bit;
reg [11:0]  pref_mem_base;
reg [11:0]  pref_mem_limit;
assign  cfg_mem_base            = {mem_base,  4'b0};
assign  cfg_mem_limit           = {mem_limit, 4'hf};
assign  cfg_pref_mem_base       = {cfg_pref_base_upper32,  pref_mem_base,  20'h0};
assign  cfg_pref_mem_limit      = {cfg_pref_limit_upper32, pref_mem_limit, 20'hFFFFF};

assign {cfg_reg_35, cfg_reg_34, cfg_reg_33, cfg_reg_32} = type0 ? {cfg_bar4_start[31:4], cfg_bar4_pref, cfg_bar4_type, cfg_bar4_io}
                                                                : {mem_limit, 4'h0, mem_base,  4'b0}; 

assign {cfg_reg_37, cfg_reg_36} = type0 ? (bar5_enabled ? {cfg_bar5_start[15:4], cfg_bar5_pref, cfg_bar5_type, cfg_bar5_io} : cfg_bar4_start[47:32])
                                        : {pref_mem_base,  3'h0, mem_is_64bit}; 

assign {cfg_reg_39, cfg_reg_38} =  type0 ? (bar5_enabled ? cfg_bar5_start[31:16] : cfg_bar4_start[63:48])
                                        : {pref_mem_limit, 3'h0, mem_is_64bit}; 


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        mem_base                <= #TP 0;
        mem_limit               <= #TP 0;
        pref_mem_base           <= #TP 0;
        pref_mem_limit          <= #TP 0;
    end else begin
        mem_base[3:0]           <= #TP (~type0 & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[7:4]   : mem_base[3:0];
        mem_base[11:4]          <= #TP (~type0 & write_pulse[1] & cfg_reg_id[8]) ? lbc_cdm_data[15:8]  : mem_base[11:4];
        mem_limit[3:0]          <= #TP (~type0 & write_pulse[2] & cfg_reg_id[8]) ? lbc_cdm_data[23:20] : mem_limit[3:0];
        mem_limit[11:4]         <= #TP (~type0 & write_pulse[3] & cfg_reg_id[8]) ? lbc_cdm_data[31:24] : mem_limit[11:4];

//L_UNCOVERED_330_6: type0==1 => mem_is_64bit==0
        pref_mem_base[3:0]      <= #TP (~type0 & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[7:4]   : pref_mem_base[3:0];
        pref_mem_base[11:4]     <= #TP (~type0 & write_pulse[1] & cfg_reg_id[9]) ? lbc_cdm_data[15:8]  : pref_mem_base[11:4];
        pref_mem_limit[3:0]     <= #TP (~type0 & write_pulse[2] & cfg_reg_id[9]) ? lbc_cdm_data[23:20] : pref_mem_limit[3:0];
        pref_mem_limit[11:4]    <= #TP (~type0 & write_pulse[3] & cfg_reg_id[9]) ? lbc_cdm_data[31:24] : pref_mem_limit[11:4];
    end
end
 
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        mem_is_64bit            <= #TP `MEM_DECODE_64;
    end else begin
        mem_is_64bit            <= #TP (int_lbc_cdm_dbi & ~type0 & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[0]     : mem_is_64bit;
    end
end

// -----------------------------------------------------------------------------
// Type 1: Prefetchable Base Upper 32 Bits, Prefetchable limit Upper 32 Bits
// Type 0: 28h is cardbus cis pointer(hardwired to 0)
//         2Ch is subsystem_device_id, subsystem_vendor_id (hardwired to 0 for now)
// cfig_reg_id      - 10, 11
// PCIE Offset      - 28h - 2Ch
// Length           - 8 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_40 - cfg_reg_47
// -----------------------------------------------------------------------------
reg [15:0]  subsystem_device_id;
reg [15:0]  subsystem_vendor_id;
reg [31:0]  cfg_cardbus_cis_ptr;
assign {cfg_reg_43, cfg_reg_42, cfg_reg_41, cfg_reg_40} = type0 ? cfg_cardbus_cis_ptr : cfg_pref_base_upper32; 

assign {cfg_reg_47, cfg_reg_46, cfg_reg_45, cfg_reg_44} = type0 ? {subsystem_device_id, subsystem_vendor_id} : cfg_pref_limit_upper32;

// Type 0
// Read-Only registers, but writable through DBI access
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_cardbus_cis_ptr         <= #TP `CARDBUS_CIS_PTR;
        subsystem_vendor_id         <= #TP `SUBSYS_VENDOR_ID;
        subsystem_device_id         <= #TP `SUBSYS_DEV_ID;
    end else begin
        cfg_cardbus_cis_ptr[7:0]    <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[10]) ? lbc_cdm_data[7:0]   : cfg_cardbus_cis_ptr[7:0];
        cfg_cardbus_cis_ptr[15:8]   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[1] & cfg_reg_id[10]) ? lbc_cdm_data[15:8]  : cfg_cardbus_cis_ptr[15:8];
        cfg_cardbus_cis_ptr[23:16]  <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[10]) ? lbc_cdm_data[23:16] : cfg_cardbus_cis_ptr[23:16];
        cfg_cardbus_cis_ptr[31:24]  <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[3] & cfg_reg_id[10]) ? lbc_cdm_data[31:24] : cfg_cardbus_cis_ptr[31:24];
        subsystem_vendor_id[7:0]    <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[11]) ? lbc_cdm_data[7:0]   : subsystem_vendor_id[7:0];
        subsystem_vendor_id[15:8]   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[1] & cfg_reg_id[11]) ? lbc_cdm_data[15:8]  : subsystem_vendor_id[15:8];
        subsystem_device_id[7:0]    <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[11]) ? lbc_cdm_data[23:16] : subsystem_device_id[7:0];
        subsystem_device_id[15:8]   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[3] & cfg_reg_id[11]) ? lbc_cdm_data[31:24] : subsystem_device_id[15:8];
    end
end

// Type 1
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_pref_base_upper32               <= #TP 0;
        cfg_pref_limit_upper32              <= #TP 0;
    end
    else begin

        if (mem_is_64bit) begin
            cfg_pref_base_upper32[7:0]      <= #TP write_pulse[0] & cfg_reg_id[10]? lbc_cdm_data[7:0]   :cfg_pref_base_upper32[7:0];
            cfg_pref_base_upper32[15:8]     <= #TP write_pulse[1] & cfg_reg_id[10]? lbc_cdm_data[15:8]  :cfg_pref_base_upper32[15:8];
            cfg_pref_base_upper32[23:16]    <= #TP write_pulse[2] & cfg_reg_id[10]? lbc_cdm_data[23:16] :cfg_pref_base_upper32[23:16];
            cfg_pref_base_upper32[31:24]    <= #TP write_pulse[3] & cfg_reg_id[10]? lbc_cdm_data[31:24] :cfg_pref_base_upper32[31:24];

            cfg_pref_limit_upper32[7:0]     <= #TP write_pulse[0] & cfg_reg_id[11]? lbc_cdm_data[7:0]   :cfg_pref_limit_upper32[7:0];
            cfg_pref_limit_upper32[15:8]    <= #TP write_pulse[1] & cfg_reg_id[11]? lbc_cdm_data[15:8]  :cfg_pref_limit_upper32[15:8];
            cfg_pref_limit_upper32[23:16]   <= #TP write_pulse[2] & cfg_reg_id[11]? lbc_cdm_data[23:16] :cfg_pref_limit_upper32[23:16];
            cfg_pref_limit_upper32[31:24]   <= #TP write_pulse[3] & cfg_reg_id[11]? lbc_cdm_data[31:24] :cfg_pref_limit_upper32[31:24];

        end
        else begin
            cfg_pref_base_upper32           <= #TP 0;
            cfg_pref_limit_upper32          <= #TP 0;
        end

    end
end
// -----------------------------------------------------------------------------
// Type 1: I/O Limit Upper 16 bits, I/O Base Upper 16 Bits
// Type 0: Expansion ROM address
// cfig_reg_id      - 12
// PCIE Offset      - 30h
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_48 - cfg_reg_51
// -----------------------------------------------------------------------------

reg [31:0]  exp_rom_mask;
reg         rom_bar_enabled;

assign cfg_rom_mask = exp_rom_mask;
// Type 0
reg [31:0]  exp_rom_addr_type0;
reg [20:0]  exp_rom_addr_0;
reg [3:0]   exp_rom_validation_details_0;
reg [2:0]   exp_rom_validation_status_0;
reg         exp_rom_en_0;
reg [20:0]  exp_rom_addr_1;
reg [3:0]   exp_rom_validation_details_1;
reg [2:0]   exp_rom_validation_status_1;
reg         exp_rom_en_1;
wire[31:0]  cfg_exp_rom_type0;
wire[31:0]  exp_rom_start_type0;
wire[31:0]  exp_rom_limit_type0;
wire        rom_enable_type0;
assign cfg_exp_rom_type0    = (exp_rom_addr_type0 & ~exp_rom_mask);

// Need to disable if cfg_mem_space_en or rom_enable is 0 - by setting the limit to 0
assign rom_enable_type0     = exp_rom_addr_type0[0] & cfg_mem_space_en & rom_bar_enabled;
assign exp_rom_start_type0  = ~rom_enable_type0 ? 32'h1
                             : cfg_exp_rom_type0;
assign exp_rom_limit_type0  = ~rom_enable_type0 ? 0
                             : (cfg_exp_rom_type0 | exp_rom_mask);

wire rom_mask_writable;
//L_UNCOVERED_330_7: rom_mask_writable==0 => rom_bar_enabled==0
assign rom_mask_writable = `ROM_MASK_WRITABLE;



always @(posedge core_clk or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    rom_bar_enabled       <= #TP `DEFAULT_ROM_BAR_ENABLED;
  end else begin
    rom_bar_enabled       <= #TP (rom_mask_writable & write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[0]     : rom_bar_enabled;
  end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        exp_rom_addr_0              <= #TP 0;
        exp_rom_en_0                <= #TP 0;
    end else begin

        if (~rom_bar_enabled) begin
            exp_rom_addr_0          <= #TP 0;
            exp_rom_en_0            <= #TP 0;
        end
        else begin
            exp_rom_en_0            <= #TP (type0 & write_pulse[0] & ~lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[0]     : exp_rom_en_0;
            exp_rom_addr_0[4:0]     <= #TP (type0 & write_pulse[1] & ~lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[15:11] : exp_rom_addr_0[4:0];
            exp_rom_addr_0[12:5]    <= #TP (type0 & write_pulse[2] & ~lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[23:16] : exp_rom_addr_0[12:5];
            exp_rom_addr_0[20:13]   <= #TP (type0 & write_pulse[3] & ~lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[31:24] : exp_rom_addr_0[20:13];
        end
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        exp_rom_validation_status_0    <= #TP 3'b000;
        exp_rom_validation_details_0   <= #TP 4'b0000;
    end else begin
      if (!rom_bar_enabled) begin
        exp_rom_validation_status_0    <= #TP 3'b000;
        exp_rom_validation_details_0   <= #TP 4'b0000;
      end else if (exp_rom_validation_status_strobe | exp_rom_validation_details_strobe) begin   
        if (exp_rom_validation_status_strobe) begin                               
          exp_rom_validation_status_0  <= #TP exp_rom_validation_status;     //Set the Expansion ROM Validation Status bits
      end
        if (exp_rom_validation_details_strobe) begin                               
          exp_rom_validation_details_0 <= #TP exp_rom_validation_details;    //Set the Expansion ROM Validation Details bits
        end
      end else begin
       exp_rom_validation_status_0  <= #TP(type0 & write_pulse[0] & ~lbc_cdm_dbi2 & cfg_reg_id[12] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:1] : exp_rom_validation_status_0;
       exp_rom_validation_details_0 <= #TP(type0 & write_pulse[0] & ~lbc_cdm_dbi2 & cfg_reg_id[12] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:4] : exp_rom_validation_details_0;
      end
    end
end

assign exp_rom_addr_type0 = {exp_rom_addr_0, 3'b0, exp_rom_validation_details_0, exp_rom_validation_status_0, exp_rom_en_0};

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        exp_rom_mask                    <= #TP `ROM_MASK;
    end else begin
        if (rom_bar_enabled) begin
            exp_rom_mask[10:0]          <= #TP 11'h7FF;
            exp_rom_mask[15:11]         <= #TP (rom_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & ((type0 && cfg_reg_id[12]) || (~type0 && cfg_reg_id[14]))) ? lbc_cdm_data[15:11] : exp_rom_mask[15:11];
            exp_rom_mask[23:16]         <= #TP (rom_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & ((type0 && cfg_reg_id[12]) || (~type0 && cfg_reg_id[14]))) ? lbc_cdm_data[23:16] : exp_rom_mask[23:16];
            exp_rom_mask[31:24]         <= #TP (rom_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & ((type0 && cfg_reg_id[12]) || (~type0 && cfg_reg_id[14]))) ? lbc_cdm_data[31:24] : exp_rom_mask[31:24];
        end
        else begin
            exp_rom_mask                <= #TP 32'hFFFFFFFF;
        end
    end
end

//assertions for exp_rom_addr_type0 added near end of file


// Type 1
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_io_limit_upper16        <= #TP 0;
        cfg_io_base_upper16         <= #TP 0;
    end else begin

        cfg_io_base_upper16[7:0]    <= #TP ~type0 & write_pulse[0] & cfg_reg_id[12] ? lbc_cdm_data[7:0]   : cfg_io_base_upper16[7:0];
        cfg_io_base_upper16[15:8]   <= #TP ~type0 & write_pulse[1] & cfg_reg_id[12] ? lbc_cdm_data[15:8]  : cfg_io_base_upper16[15:8];
        cfg_io_limit_upper16[7:0]   <= #TP ~type0 & write_pulse[2] & cfg_reg_id[12] ? lbc_cdm_data[23:16] : cfg_io_limit_upper16[7:0];
        cfg_io_limit_upper16[15:8]  <= #TP ~type0 & write_pulse[3] & cfg_reg_id[12] ? lbc_cdm_data[31:24] : cfg_io_limit_upper16[15:8];

    end
end
assign {cfg_reg_51, cfg_reg_50, cfg_reg_49, cfg_reg_48} = type0 ? {cfg_exp_rom_type0[31:8], exp_rom_validation_details_0, exp_rom_validation_status_0, exp_rom_addr_type0[0]}
                                                                : (io_is_32bit ? {cfg_io_limit_upper16, cfg_io_base_upper16} : 0); 


// -----------------------------------------------------------------------------
// Capabilities Pointer
// -----------------------------------------------------------------------------
// Capabilities Pointer - Point to the first location of capability structure
// cfig_reg_id      - 13
// PCIE Offset      - 34h
// Length           - 4 bytes
// Default value    - `CFG_NEXT_PTR
// Cfig register    - cfg_reg_52 - cfg_reg_55
//
// Same for Type0 or Type1
// -----------------------------------------------------------------------------
reg [7:0]   cfg_cap_ptr;
assign cfg_reg_52 = cfg_cap_ptr;    // Points to first capability structure
assign cfg_reg_53 = 8'h00;          // RESV
assign cfg_reg_54 = 8'h00;          // RESV
assign cfg_reg_55 = 8'h00;          // RESV


always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_cap_ptr <= #TP `CFG_NEXT_PTR;
    end else begin
        cfg_cap_ptr <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[13]) ? lbc_cdm_data[7:0] : cfg_cap_ptr;
    end
end

// -----------------------------------------------------------------------------
// Type 1: Expansion ROM Base Address
// Type 0: Reserved
// cfig_reg_id      - 14
// PCIE Offset      - 38h
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_56 - cfg_reg_59
// -----------------------------------------------------------------------------
reg [31:0]  exp_rom_addr_type1;
wire[31:0]  cfg_exp_rom_type1;
wire[31:0]  exp_rom_start_type1;
wire[31:0]  exp_rom_limit_type1;
wire        rom_enable_type1;
wire        exp_rom_enable;
assign {cfg_reg_59, cfg_reg_58, cfg_reg_57, cfg_reg_56} = type0 ? 32'b0 : {cfg_exp_rom_type1[31:8], exp_rom_validation_details_1, exp_rom_validation_status_1, exp_rom_addr_type1[0]};

assign cfg_exp_rom_type1    = (exp_rom_addr_type1 & ~exp_rom_mask);
// Need to disable if cfg_mem_space_en or rom_enable is 0 - by setting the limit to 0
assign rom_enable_type1     = exp_rom_addr_type1[0] & (cfg_mem_space_en | ~upstream_port) & rom_bar_enabled;
assign exp_rom_start_type1  = ~rom_enable_type1 ? 32'h1
                             : cfg_exp_rom_type1;
assign exp_rom_limit_type1  = ~rom_enable_type1 ? 0
                             : cfg_exp_rom_type1 | exp_rom_mask;

assign exp_rom_enable       =  type0 ? rom_enable_type0 : rom_enable_type1;

// cfg_exp_rom_limit and cfg_exp_rom_start register enables
reg cfg_exp_rom_limit_updt_d;
wire cfg_exp_rom_limit_en;
assign cfg_exp_rom_limit_updt = |write_pulse; 
assign cfg_exp_rom_limit_en = cfg_exp_rom_limit_updt | cfg_exp_rom_limit_updt_d;
reg cfg_exp_rom_start_updt_d;
wire cfg_exp_rom_start_en;
assign cfg_exp_rom_start_updt = |write_pulse;
assign cfg_exp_rom_start_en = cfg_exp_rom_start_updt | cfg_exp_rom_start_updt_d;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_exp_rom_limit_updt_d        <= #TP 0;
        cfg_exp_rom_start_updt_d        <= #TP 0;
      end else begin
        cfg_exp_rom_limit_updt_d        <= #TP cfg_exp_rom_limit_updt;
        cfg_exp_rom_start_updt_d        <= #TP cfg_exp_rom_start_updt;
    end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_exp_rom_start               <= #TP 0;
        cfg_exp_rom_limit               <= #TP 0;
    end else begin
        cfg_exp_rom_start               <= #TP cfg_exp_rom_start_en ? (type0 ? exp_rom_start_type0 : exp_rom_start_type1) : cfg_exp_rom_start;
        cfg_exp_rom_limit               <= #TP cfg_exp_rom_limit_en ? (type0 ? exp_rom_limit_type0 : exp_rom_limit_type1) : cfg_exp_rom_limit;
    end
end


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        exp_rom_addr_1              <= #TP 0;
        exp_rom_en_1                <= #TP 0;
    end else begin

        if (~rom_bar_enabled) begin
            exp_rom_addr_1          <= #TP 0;
            exp_rom_en_1            <= #TP 0;
        end
        else begin
            exp_rom_en_1            <= #TP (write_pulse[0] & cfg_reg_id[14]) ? lbc_cdm_data[0]     : exp_rom_en_1;
            exp_rom_addr_1[4:0  ]   <= #TP (write_pulse[1] & cfg_reg_id[14]) ? lbc_cdm_data[15:11] : exp_rom_addr_1[4:0];
            exp_rom_addr_1[12:5]    <= #TP (write_pulse[2] & cfg_reg_id[14]) ? lbc_cdm_data[23:16] : exp_rom_addr_1[12:5];
            exp_rom_addr_1[20:13]   <= #TP (write_pulse[3] & cfg_reg_id[14]) ? lbc_cdm_data[31:24] : exp_rom_addr_1[20:13];
        end
    end
end
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        exp_rom_validation_status_1    <= #TP 3'b000;
        exp_rom_validation_details_1   <= #TP 4'b0000;
    end else begin
      if (!rom_bar_enabled) begin
        exp_rom_validation_status_1    <= #TP 3'b000;
        exp_rom_validation_details_1   <= #TP 4'b0000;
      end else if (exp_rom_validation_status_strobe | exp_rom_validation_details_strobe) begin   
        if (exp_rom_validation_status_strobe) begin                               
          exp_rom_validation_status_1  <= #TP exp_rom_validation_status;     //Set the Expansion ROM Validation Status bits
        end
        if (exp_rom_validation_details_strobe) begin                               
          exp_rom_validation_details_1 <= #TP exp_rom_validation_details;    //Set the Expansion ROM Validation Details bits
        end
      end else begin
       exp_rom_validation_status_1  <= #TP(write_pulse[0] & cfg_reg_id[14] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:1] : exp_rom_validation_status_1;
       exp_rom_validation_details_1 <= #TP(write_pulse[0] & cfg_reg_id[14] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:4] : exp_rom_validation_details_1;
      end
    end
end

assign exp_rom_addr_type1 = {exp_rom_addr_1, 3'b0, exp_rom_validation_details_1, exp_rom_validation_status_1, exp_rom_en_1};

// -----------------------------------------------------------------------------
// Type 1: Bridge Control, INT Pin, INT Line
// Type 0: Max_Lat, Min_Gnt, INT Pin, INT Line
// cfig_reg_id      - 15
// PCIE Offset      - 3Ch
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_60 - cfg_reg_63
// -----------------------------------------------------------------------------

reg         cfg_vga_enable;
reg         cfg_vga16_decode;
reg         cfg_isa_enable;
reg [7:0]   cfg_int_pin;
reg         cfg_mstr_abort_mode;
assign cfg_reg_60 = int_line_reg;
assign cfg_reg_61 = cfg_int_pin;
assign cfg_reg_62 = type0 ? 8'h0 : {1'b0, cfg_2nd_reset, cfg_mstr_abort_mode, cfg_vga16_decode, cfg_vga_enable, cfg_isa_enable, cfg_br_ctrl_serren, cfg_br_ctrl_perren};
assign cfg_reg_63 = 8'b0;


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_br_ctrl_perren  <= #TP 0;
        cfg_br_ctrl_serren  <= #TP 0;
        cfg_isa_enable      <= #TP 0;
        cfg_vga_enable      <= #TP 0;
        cfg_vga16_decode    <= #TP 0;
        cfg_mstr_abort_mode <= #TP 0;
        cfg_2nd_reset       <= #TP 0;
        int_line_reg        <= #TP 8'hFF;
    end else begin

        cfg_br_ctrl_perren  <= #TP (~type0 & write_pulse[2] & cfg_reg_id[15]) ? lbc_cdm_data[16] : cfg_br_ctrl_perren;
        cfg_br_ctrl_serren  <= #TP (~type0 & write_pulse[2] & cfg_reg_id[15]) ? lbc_cdm_data[17] : cfg_br_ctrl_serren;
        cfg_isa_enable      <= #TP (~type0 & write_pulse[2] & cfg_reg_id[15]) ? lbc_cdm_data[18] : cfg_isa_enable;
        cfg_vga_enable      <= #TP 0;
        cfg_vga16_decode    <= #TP 0;
        cfg_mstr_abort_mode <= #TP (~type0 & write_pulse[2] & cfg_reg_id[15] & bridge_device) ? lbc_cdm_data[21] : cfg_mstr_abort_mode;
        cfg_2nd_reset       <= #TP (~type0 & write_pulse[2] & cfg_reg_id[15]) ? lbc_cdm_data[22] : cfg_2nd_reset;

        int_line_reg        <= #TP (write_pulse[0] & cfg_reg_id[15]) ? lbc_cdm_data[7:0] : int_line_reg;

    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_int_pin         <= #TP `INT_PIN_MAPPING;
    end else begin
        // DBI writable register
        cfg_int_pin         <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_reg_id[15]) ? lbc_cdm_data[15:8] : cfg_int_pin;
    end
end

// Group BAR enables
assign cfg_bar_enabled = { bar5_enabled, bar4_enabled, bar3_enabled, bar2_enabled, bar1_enabled, bar0_enabled};
// The following is used to determine if the function has any active Memory or
// IO BARs. Determines if Memory and IO space enables are Read Only or
// Read/Write as per section 6.2.2 of PCI Local bus specification.
// Only applies to endpoint devices. Switches and root ports always
// support IO and Memory ranges
assign has_mem_bar =
    ~type0 || |(cfg_bar_enabled & ~cfg_bar_is_io) || rom_bar_enabled;
assign has_io_bar = ~type0 || |(cfg_bar_enabled & cfg_bar_is_io);

//==============================================================================
//
// PCI Capability List Structure -- pointed to by capabilities pointer register
//
//==============================================================================

// =============================================================================
// Power Management Capability Structure
// =============================================================================

  cdm_pm_reg
   #(.INST(INST), .FUNC_NUM(FUNC_NUM),  .VF_IMPL(0)
  ) u_cdm_pm_reg
  (
// ---------- Inputs --------
    .core_clk            (core_clk),
    .non_sticky_rst_n    (non_sticky_rst_n),
    .sticky_rst_n    (sticky_rst_n),
    .flr_rst_n           (1'b1),
    .lbc_cdm_data        (lbc_cdm_data),
    .lbc_cdm_dbi         (int_lbc_cdm_dbi),
    .pm_write_pulse      (write_pulse),
    .pm_reg_id           (pm_reg_id),
    .aux_pwr_det         (aux_pwr_det),
    .pm_status           (pm_status),
    .pm_pme_en           (pm_pme_en),
    .d0_active_detect    (d0_active_detect),
    .pme_support         (5'b00000), // Not Required for PFs
    .pm_d2_support       (1'b0),     // Not Required for PFs
    .pm_d1_support       (1'b0),     // Not Required for PFs
    .pm_no_soft_rst      (1'b0),     // Not Required for PFs

// ---------- Outputs --------
    .cfg_upd_pmcsr       (cfg_upd_pmcsr),
    .cfg_pmstatus_clr    (cfg_pmstatus_clr),
    .cfg_pmstate         (cfg_pmstate),
    .cfg_pme_en          (cfg_pme_en),
    .cfg_pme_cap         (cfg_pme_cap),
    .cfg_pm_no_soft_rst  (cfg_pm_no_soft_rst),
    .pm_reg_data         (pm_reg_data),
    .cfg_upd_pme_cap     (cfg_upd_pme_cap)

  );  //cdm_pm_reg
// =============================================================================
// MSI Capability Structure
// =============================================================================

  cdm_msi_reg
   #(.INST(INST), .VF_IMPL(0), .FUNC_NUM(FUNC_NUM)
  ) u_cdm_msi_reg
  (
// ---------- Inputs --------
    .core_clk            (core_clk),
    .non_sticky_rst_n    (non_sticky_rst_n),
    .sticky_rst_n    (sticky_rst_n),
    .flr_rst_n           (1'b1),
    .lbc_cdm_data        (lbc_cdm_data),
    .lbc_cdm_dbi         (int_lbc_cdm_dbi),
    .msi_write_pulse     (write_pulse),
    .msi_read_pulse      (cap_reg_read_pulse),
    .msi_reg_id          (msi_reg_id[5:0]),
    .cfg_msi_pending     (32'b0),
// ---------- Outputs --------
    .cfg_multi_msi_en    (cfg_multi_msi_en),
    .cfg_msi_ext_data_en (cfg_msi_ext_data_en),
    .cfg_msi_en          (cfg_msi_en),
    .cfg_msi_addr        (cfg_msi_addr),
    .cfg_msi_data        (cfg_msi_data),
    .cfg_msi_64          (cfg_msi_64),
    .cfg_msi_mask        (cfg_msi_mask),
    .msi_reg_data        (msi_reg_data)
  );

// =============================================================================
// PCI-Express Capability Structure
// =============================================================================

// -----------------------------------------------------------------------------
// PCI-E cap list register
// -----------------------------------------------------------------------------
// Capability ID    - PCI-E capability and ID
// cfg_cap_reg_id   - 6
// PCIE Offset      - `CFG_PCIE_CAP
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_88, cfg_reg_89, cfg_reg_90, cfg_reg_91
// -----------------------------------------------------------------------------
reg [7:0]   cfg_pcie_cap_next_ptr;
reg         cfg_pcie_cap_slot_impl;
assign cfg_reg_88 = 8'h10;                  // PCI-E capability ID
assign cfg_reg_89 = cfg_pcie_cap_next_ptr;
assign cfg_reg_90 = ({device_type, 4'h2}); // device/port type and Cap version
assign cfg_reg_91 = {2'b0, cfg_pcie_cap_int_msg_num, cfg_pcie_cap_slot_impl};


always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_pcie_cap_next_ptr   <= #TP `PCIE_NEXT_PTR;
        cfg_pcie_cap_slot_impl  <= #TP `SLOT_IMPLEMENTED;
        cfg_pcie_cap_int_msg_num<= #TP `PCIE_CAP_INT_MSG_NUM;
    end
    else begin
        cfg_pcie_cap_next_ptr   <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[6]) ? lbc_cdm_data[15:8] : cfg_pcie_cap_next_ptr;
        cfg_pcie_cap_slot_impl  <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[6]) ? lbc_cdm_data[24]   : cfg_pcie_cap_slot_impl;
        cfg_pcie_cap_int_msg_num<= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[6]) ? lbc_cdm_data[29:25]: cfg_pcie_cap_int_msg_num;
    end
end

// -----------------------------------------------------------------------------
// Device Capabilities Register
// cfg_cap_reg_id   - 7
// PCIE Offset      - `CFG_PCIE_CAP + 04h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_92, cfg_reg_93, cfg_reg_94, cfg_reg_95
// -----------------------------------------------------------------------------
reg [2:0]   cfg_pcie_max_pyld_size_cap;
reg [1:0]   cfg_pcie_phantom_func_cap;
reg         cfg_pcie_ext_tag_field_cap;
reg [2:0]   cfg_pcie_ep_l0s_latency_cap;
reg [2:0]   cfg_pcie_ep_l1_latency_cap;
reg         cfg_pcie_rolebased_err_rpt;
reg         cfg_pcie_flr_cap;
assign {cfg_reg_93, cfg_reg_92} = { cfg_pcie_rolebased_err_rpt,
                                    3'b0,
                                    cfg_pcie_ep_l1_latency_cap,
                                    cfg_pcie_ep_l0s_latency_cap,
                                    cfg_pcie_ext_tag_field_cap,
                                    cfg_pcie_phantom_func_cap,
                                    cfg_pcie_max_pyld_size_cap};

// cap_slot_pwr_limit_val and capt_slot_pwr_limit_scale are only applied to upstrm port, otherwise is wired to 0
assign {cfg_reg_95, cfg_reg_94} = upstream_port ? {3'b0, cfg_pcie_flr_cap, rcvd_slot_pwr_limit_scale, rcvd_slot_pwr_limit_val, 2'b0} : 16'b0;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_pcie_max_pyld_size_cap      <= #TP `DEFAULT_MAX_PAYLOAD_SIZE_SUPPORTED;
        cfg_pcie_phantom_func_cap       <= #TP `DEFAULT_PHANTOM_FUNC_SUPPORTED;
        cfg_pcie_ext_tag_field_cap      <= #TP `DEFAULT_EXT_TAG_FIELD_SUPPORTED;
        cfg_pcie_ep_l0s_latency_cap     <= #TP `DEFAULT_EP_L0S_ACCPT_LATENCY;
        cfg_pcie_ep_l1_latency_cap      <= #TP `DEFAULT_EP_L1_ACCPT_LATENCY;
        cfg_pcie_rolebased_err_rpt      <= #TP 1'b1;                                    // 1.1 support
        cfg_pcie_flr_cap                <= #TP  `CX_FLR_ENABLE_VALUE;
    end

    else begin
        cfg_pcie_max_pyld_size_cap      <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[7]) ? lbc_cdm_data[2:0] : cfg_pcie_max_pyld_size_cap;
        cfg_pcie_phantom_func_cap       <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[7]) ? lbc_cdm_data[4:3] : cfg_pcie_phantom_func_cap;
        cfg_pcie_ext_tag_field_cap      <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[7]) ? lbc_cdm_data[5]   : cfg_pcie_ext_tag_field_cap;
        cfg_pcie_ep_l0s_latency_cap[1:0]<= #TP (!end_device || (phy_type == `PHY_TYPE_MPCIE)) ? 2'b0 : ((int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[7]) ? lbc_cdm_data[7:6] : cfg_pcie_ep_l0s_latency_cap[1:0]);
        cfg_pcie_ep_l0s_latency_cap[2]  <= #TP (!end_device || (phy_type == `PHY_TYPE_MPCIE)) ? 1'b0 : ((int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[7]) ? lbc_cdm_data[8]   : cfg_pcie_ep_l0s_latency_cap[2]);
        cfg_pcie_ep_l1_latency_cap      <= #TP !end_device                                             ? 3'b0
                                              : (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[7]) ? lbc_cdm_data[11:9]
                                              : cfg_pcie_ep_l1_latency_cap;
        cfg_pcie_rolebased_err_rpt      <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[7]) ? lbc_cdm_data[15]  : cfg_pcie_rolebased_err_rpt;
        cfg_pcie_flr_cap                <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[7]) ? lbc_cdm_data[28]  : cfg_pcie_flr_cap;
    end
end

// -----------------------------------------------------------------------------
// Device Control & Status Register
// cfg_cap_reg_id   - 8
// PCIE Offset      - `CFG_PCIE_CAP + 08h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_96, cfg_reg_97, cfg_reg_98, cfg_reg_99
// -----------------------------------------------------------------------------

//
// Device Control register (08h)
//

assign {cfg_reg_97, cfg_reg_96} = {1'b0, cfg_max_rd_req_size, cfg_no_snoop_en, aux_pm_en, cfg_phantom_fun_en,
                                   cfg_ext_tag_en,
                                   cfg_max_payload_size, cfg_relax_ord_en, cfg_unsupt_req_rpt_en,
                                   cfg_f_err_rpt_en, cfg_nf_err_rpt_en, cfg_cor_err_rpt_en};

reg cfg_upd_aux_pm_en;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_aux_pm_en          <= #TP 0;
        cfg_upd_aux_pm_en      <= #TP 0;
    end else begin
        // cfg_aux_pm_en is hardwired to 0 when aux_pwr_det = 0
        cfg_aux_pm_en          <= #TP write_pulse[1] & cfg_cap_reg_id[8] & aux_pwr_det ? lbc_cdm_data[10]: cfg_aux_pm_en;
        cfg_upd_aux_pm_en      <= #TP write_pulse[1] & cfg_cap_reg_id[8];
    end
end


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_cor_err_rpt_en      <= #TP 0;
        cfg_nf_err_rpt_en       <= #TP 0;
        cfg_f_err_rpt_en        <= #TP 0;
        cfg_unsupt_req_rpt_en   <= #TP 0;
        cfg_relax_ord_en        <= #TP 1'b1;
        cfg_max_payload_size    <= #TP 0;
        cfg_ext_tag_en          <= #TP `DEFAULT_EXT_TAG_FIELD_SUPPORTED;
        cfg_phantom_fun_en      <= #TP 0;
        cfg_no_snoop_en         <= #TP `DEFAULT_NO_SNOOP_SUPPORTED;
        cfg_max_rd_req_size     <= #TP 3'b010;
        cfg_bridge_crs_en       <= #TP 0;
    end else begin
        cfg_cor_err_rpt_en      <= #TP write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[0] : cfg_cor_err_rpt_en;
        cfg_nf_err_rpt_en       <= #TP write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[1] : cfg_nf_err_rpt_en;
        cfg_f_err_rpt_en        <= #TP write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[2] : cfg_f_err_rpt_en;
        cfg_unsupt_req_rpt_en   <= #TP write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[3] : cfg_unsupt_req_rpt_en;
        cfg_relax_ord_en        <= #TP bridge_device ? 1'b0 : write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[4] : cfg_relax_ord_en;
        cfg_max_payload_size    <= #TP (write_pulse[0] & cfg_cap_reg_id[8]) ? lbc_cdm_data[7:5] : cfg_max_payload_size;
        cfg_ext_tag_en          <= #TP cfg_pcie_ext_tag_field_cap ? (write_pulse[1] & cfg_cap_reg_id[8] ? lbc_cdm_data[8] : cfg_ext_tag_en) : 0;
        cfg_phantom_fun_en      <= #TP (cfg_pcie_phantom_func_cap != 2'h0) ? (write_pulse[1] & cfg_cap_reg_id[8] ? lbc_cdm_data[9] : cfg_phantom_fun_en) : 0;
        cfg_no_snoop_en         <= #TP `DEFAULT_NO_SNOOP_SUPPORTED ? (write_pulse[1] & cfg_cap_reg_id[8] ? lbc_cdm_data[11] : cfg_no_snoop_en) : 0;
        cfg_max_rd_req_size     <= #TP (write_pulse[1] & cfg_cap_reg_id[8]) ? lbc_cdm_data[14:12] : cfg_max_rd_req_size;
        cfg_bridge_crs_en       <= #TP bridge_device ? (write_pulse[1] & cfg_cap_reg_id[8] ? lbc_cdm_data[15] : cfg_bridge_crs_en) : 0;
    end
end

//
// Status register (0Ah)
//

// For RC and Switch devices that don't issue Non-posted transaction, hardwire to 0
wire transaction_pending;
assign transaction_pending = (rc_device | switch_device) ? 0 : radm_cpl_pending;


// RW1C registers.  Write 1 to clear.
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_cor_err_det_reg     <= #TP 0;
        cfg_nf_err_det_reg      <= #TP 0;
        cfg_f_err_det_reg       <= #TP 0;
        cfg_unsupt_req_det_reg  <= #TP 0;
    end else begin
        cfg_cor_err_det_reg     <= #TP cfg_cor_err_det    ? 1'b1 : 
                                       (write_pulse[2] & cfg_cap_reg_id[8] & lbc_cdm_data[16]) ? 1'b0 : 
                                       cfg_cor_err_det_reg;

        cfg_nf_err_det_reg      <= #TP cfg_nf_err_det     ? 1'b1 :
                                       (write_pulse[2] & cfg_cap_reg_id[8] & lbc_cdm_data[17]) ? 1'b0 :  
                                       cfg_nf_err_det_reg;

        cfg_f_err_det_reg       <= #TP cfg_f_err_det      ? 1'b1 :
                                       (write_pulse[2] & cfg_cap_reg_id[8] & lbc_cdm_data[18]) ? 1'b0 :  
                                       cfg_f_err_det_reg;

        cfg_unsupt_req_det_reg  <= #TP cfg_unsupt_req_det ? 1'b1 :
                                       (write_pulse[2] & cfg_cap_reg_id[8] & lbc_cdm_data[19]) ? 1'b0 :  
                                       cfg_unsupt_req_det_reg;
    end
end



assign cfg_reg_98 = {1'b0,                              1'b0,
 transaction_pending, aux_pwr_det, cfg_unsupt_req_det_reg, cfg_f_err_det_reg, cfg_nf_err_det_reg, cfg_cor_err_det_reg};
assign cfg_reg_99 = 8'b0;


// -----------------------------------------------------------------------------
// Link Capabilities Register
// cfg_cap_reg_id   - 9
// PCIE Offset      - `CFG_PCIE_CAP + 0Ch
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_100, cfg_reg_101, cfg_reg_102, cfg_reg_103
// -----------------------------------------------------------------------------
wire[5:0]   cfg_pcie_max_link_width;
reg [5:0]   cfg_pcie_max_link_width_int;
wire[5:0]   cfg_pcie_max_link_width_mpcie;
reg [1:0]   cfg_pcie_aspm_cap;
reg [2:0]   int_pcie_l0s_exit_latency;
reg [2:0]   int_pcie_l1_exit_latency;
wire[2:0]   cfg_pcie_l0s_exit_latency;
wire[2:0]   cfg_pcie_l1_exit_latency;
assign cfg_pcie_l0s_exit_latency= int_pcie_l0s_exit_latency;
assign cfg_pcie_l1_exit_latency = int_pcie_l1_exit_latency;
reg         cfg_clk_pm_cap;
reg         cfg_pcie_slot_hp_cap;
reg         cfg_pcie_surp_dn_rpt_cap;
reg         cfg_bw_notification_cap;
reg [7:0]   cfg_pcie_port_num;
reg         cfg_aspm_optionality_compliance;
wire        cfg_dll_link_rpt_en;

assign      cfg_pcie_max_link_speed_mpcie  = 4'b0001 ;             // Not Used in Conventional PCIe.
assign      cfg_pcie_max_link_width_mpcie  = 6'b00_0001;           // Not Used in Conventional PCIe.

assign      cfg_pcie_max_link_speed     = (phy_type ==  `PHY_TYPE_MPCIE) ? cfg_pcie_max_link_speed_mpcie : cfg_pcie_max_link_speed_int ;
assign      cfg_pcie_max_link_width     = (phy_type ==  `PHY_TYPE_MPCIE) ? cfg_pcie_max_link_width_mpcie : cfg_pcie_max_link_width_int ;

assign cfg_link_rate      = cfg_reg_100[3:0];

assign {cfg_reg_102, cfg_reg_101, cfg_reg_100} = {1'b0,
                                                  cfg_aspm_optionality_compliance,
                                                  cfg_bw_notification_cap,
                                                  cfg_dll_link_rpt_en,
                                                  cfg_pcie_surp_dn_rpt_cap,
                                                  cfg_clk_pm_cap,
                                                  cfg_pcie_l1_exit_latency,
                                                  cfg_pcie_l0s_exit_latency,
                                                  cfg_pcie_aspm_cap,
                                                  cfg_pcie_max_link_width,
                                                  cfg_pcie_max_link_speed};
assign cfg_reg_103 = cfg_pcie_port_num;

// DLL link active reporting capable - always enabled when downstream port
assign cfg_dll_link_rpt_en = ~upstream_port;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_pcie_max_link_speed_int     <= #TP `MAX_LINK_SP;
        cfg_pcie_max_link_width_int     <= #TP `MAX_LINK_WIDTH;
        cfg_pcie_aspm_cap               <= #TP `AS_LINK_PM_SUPT;
        int_pcie_l0s_exit_latency       <= #TP `DEFAULT_L0S_EXIT_LATENCY;
        int_pcie_l1_exit_latency        <= #TP `DEFAULT_L1_EXIT_LATENCY;
        cfg_pcie_surp_dn_rpt_cap        <= #TP `DEFAULT_SURPRISE_DOWN_RPT_CAP;
        cfg_bw_notification_cap         <= #TP 1'b1;
        cfg_aspm_optionality_compliance <= #TP `ASPM_OPTIONALITY_COMPLIANCE;
        cfg_pcie_port_num               <= #TP `PORT_NUM;
    end else begin
        cfg_pcie_max_link_speed_int         <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[9]) ? lbc_cdm_data[3:0]   : cfg_pcie_max_link_speed_int;
        cfg_pcie_max_link_width_int[3:0]    <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[9]) ? lbc_cdm_data[7:4]   : cfg_pcie_max_link_width_int[3:0];
        cfg_pcie_max_link_width_int[5:4]    <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[9:8]   : cfg_pcie_max_link_width_int[5:4];
        cfg_pcie_aspm_cap[0]            <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 1'b0    : (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[10]    : cfg_pcie_aspm_cap[0];
        cfg_pcie_aspm_cap[1]            <= #TP                                           (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[11]    : cfg_pcie_aspm_cap[1];
        int_pcie_l0s_exit_latency       <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 3'b000  : (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[14:12] : cfg_pcie_l0s_exit_latency;
        int_pcie_l1_exit_latency[0]     <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[15]
                                              : int_pcie_l1_exit_latency[0];
        int_pcie_l1_exit_latency[2:1]   <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[17:16]
                                                  : int_pcie_l1_exit_latency[2:1];
        cfg_pcie_surp_dn_rpt_cap            <= #TP upstream_port ? 1'b0 : (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[19] : cfg_pcie_surp_dn_rpt_cap;  
        cfg_bw_notification_cap             <= #TP upstream_port ? 1'b0 : (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[21] : cfg_bw_notification_cap;
        cfg_aspm_optionality_compliance     <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[22] : cfg_aspm_optionality_compliance;
        cfg_pcie_port_num                   <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[9]) ? lbc_cdm_data[31:24] : cfg_pcie_port_num;
    end
end


always @(posedge core_clk or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    cfg_clk_pm_cap                  <= #TP `DEFAULT_CLK_PM_CAP;
  end else begin
    cfg_clk_pm_cap                  <= #TP !(app_clk_pm_en && upstream_port) ? 0 : ((int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[18]    : cfg_clk_pm_cap); 
  end
end



//

// -----------------------------------------------------------------------------
// Link Control & Status Register
// cfg_cap_reg_id   - 10
// PCIE Offset      - `CFG_PCIE_CAP + 10h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_104, cfg_reg_105, cfg_reg_106, cfg_reg_107
// -----------------------------------------------------------------------------

// Link Control (10h)
reg     cfg_pcie_root_rcb;
reg     cfg_link_auto_bw_int_en;
reg     cfg_bw_mgt_int_en;
// RCB: if Switch, hardwire to 0.  If root port, RO.  If endpoints, RW.
reg  other_rcb;

assign cfg_reg_104 = {cfg_ext_synch_int, cfg_comm_clk_config, 1'b0, cfg_link_dis, cfg_rcb, 1'b0, cfg_aslk_pmctrl_int};
assign cfg_reg_105 = {
                      2'b0,
                      2'b0,
                      cfg_link_auto_bw_int_en,  // Link Autonomous BW Interrupt Enable
                      cfg_bw_mgt_int_en,        // Link BW Management Interrupt Enable
                      cfg_hw_autowidth_dis,
                      cfg_clk_pm_en};


assign int_upd_aslk_pmctrl = (write_pulse[0] & cfg_cap_reg_id[10]);

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_aslk_pmctrl_int     <= #TP 0;
        other_rcb               <= #TP 0;  // default to 64 bytes (for non-RC)
        cfg_link_dis            <= #TP 0;
        cfg_link_retrain        <= #TP 0;
        cfg_comm_clk_config     <= #TP 0;
        cfg_ext_synch_int       <= #TP 0;
        cfg_clk_pm_en           <= #TP 0;
        cfg_upd_aslk_pmctrl     <= #TP 0;
        cfg_hw_autowidth_dis    <= #TP 0;


        cfg_bw_mgt_int_en       <= #TP 1'b0;
        cfg_link_auto_bw_int_en <= #TP 1'b0;
        cfg_rcb                 <= #TP 0;
        cfg_pcie_root_rcb       <= #TP `ROOT_RCB;
    end else begin
        cfg_aslk_pmctrl_int     <= #TP int_upd_aslk_pmctrl ? lbc_cdm_data[1:0] : cfg_aslk_pmctrl_int;
        cfg_upd_aslk_pmctrl     <= #TP int_upd_aslk_pmctrl;
        other_rcb               <= #TP (`CX_RCB_SUPPORT & !switch_device & !rc_device & write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[3] : other_rcb;
        cfg_link_dis            <= #TP (write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[4] & !(end_device | pcie_sw_up | bridge_device) : cfg_link_dis;
        cfg_link_retrain        <= #TP (write_pulse[0] & cfg_cap_reg_id[10]) & lbc_cdm_data[5] & !(end_device | pcie_sw_up | bridge_device);
        cfg_comm_clk_config     <= #TP (write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[6] : cfg_comm_clk_config;
        cfg_ext_synch_int       <= #TP (write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[7] : cfg_ext_synch_int;
        cfg_clk_pm_en           <= #TP cfg_clk_pm_cap ? ((write_pulse[1] & cfg_cap_reg_id[10]) ? lbc_cdm_data[8] : cfg_clk_pm_en) : 0;
        cfg_hw_autowidth_dis    <= #TP (write_pulse[1] & cfg_cap_reg_id[10] & (FUNC_NUM == 0)) ? lbc_cdm_data[9] : cfg_hw_autowidth_dis;
        cfg_bw_mgt_int_en       <= #TP cfg_bw_notification_cap ? ((write_pulse[1] & cfg_cap_reg_id[10]) ? lbc_cdm_data[10] : cfg_bw_mgt_int_en) : 1'b0;
        cfg_link_auto_bw_int_en <= #TP cfg_bw_notification_cap ? ((write_pulse[1] & cfg_cap_reg_id[10]) ? lbc_cdm_data[11] : cfg_link_auto_bw_int_en) : 1'b0;
        cfg_rcb                 <= #TP switch_device ? 1'b0 : rc_device ? cfg_pcie_root_rcb : other_rcb;
        // Read-only if root port, but writable through DBI
        cfg_pcie_root_rcb       <= #TP (rc_device & int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[3] : cfg_pcie_root_rcb;
    end
end

assign cfg_aslk_pmctrl = cfg_aslk_pmctrl_int;
assign cfg_ext_synch = (phy_type ==  `PHY_TYPE_MPCIE) ? 1'b0 : cfg_ext_synch_int ;

// Link Status (12h)
reg     cfg_pcie_slot_clk_config;
reg     cfg_bw_mgt_status;
reg     cfg_link_auto_bw_status;

wire[5:0]   int_link_width;
wire[5:0]   smlh_autoneg_link_width_mpcie;
wire[5:0]   smlh_autoneg_link_width_cpcie;
wire[5:0]   smlh_autoneg_link_width_set;

assign smlh_autoneg_link_width_mpcie = 6'h00 ;
assign smlh_autoneg_link_width_cpcie = smlh_autoneg_link_width ;
assign smlh_autoneg_link_width_set   = (phy_type == `PHY_TYPE_MPCIE) ? smlh_autoneg_link_width_mpcie : smlh_autoneg_link_width_cpcie ;

assign int_link_width                = smlh_link_up ? smlh_autoneg_link_width_set : 6'b000001;

reg  cfg_dll_active_d;
wire cfg_dll_active;
assign cfg_dll_active = (rdlh_dlcntrl_state ==  `S_DL_ACTIVE);
wire dll_active_chnged;
assign dll_active_chnged = (cfg_dll_active != cfg_dll_active_d);


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_dll_active_d    <= #TP 1'b0;
    end
    else begin
        cfg_dll_active_d    <= #TP cfg_dll_active;
    end
end

assign {cfg_reg_107, cfg_reg_106} = upstream_port ? 
                                                         {3'b0, cfg_pcie_slot_clk_config, 2'b0, int_link_width, smlh_autoneg_link_sp} :
                                                         {cfg_link_auto_bw_status, cfg_bw_mgt_status, cfg_dll_active, cfg_pcie_slot_clk_config, smlh_link_training_in_prog, 1'b0, int_link_width, smlh_autoneg_link_sp};


reg cfg_link_auto_bw_msi;
reg link_auto_bw_msi_src_d;
wire link_auto_bw_msi_src;
reg cfg_bw_mgt_msi;
reg bw_mgt_msi_src_d;
wire bw_mgt_msi_src;

assign link_auto_bw_msi_src = cfg_link_auto_bw_int_en & cfg_link_auto_bw_status & (cfg_msi_en | cfg_msix_en);
assign bw_mgt_msi_src = cfg_bw_mgt_int_en & cfg_bw_mgt_status & (cfg_msi_en | cfg_msix_en);

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_pcie_slot_clk_config    <= #TP `SLOT_CLK_CONFIG;
        cfg_bw_mgt_status           <= #TP 1'b0;
        cfg_link_auto_bw_status     <= #TP 1'b0;
        cfg_bw_mgt_int              <= #TP 1'b0;
        cfg_link_auto_bw_int        <= #TP 1'b0;
        cfg_link_auto_bw_msi        <= #TP 1'b0;
        link_auto_bw_msi_src_d      <= #TP 1'b0;
        bw_mgt_msi_src_d            <= #TP 1'b0;
        cfg_bw_mgt_msi              <= #TP 1'b0;
    end else begin
        cfg_pcie_slot_clk_config    <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[10]) ? lbc_cdm_data[28] : cfg_pcie_slot_clk_config;
        cfg_bw_mgt_status           <= #TP cfg_bw_notification_cap ? (smlh_bw_mgt_status ? 1'b1 : (write_pulse[3] & cfg_cap_reg_id[10] & lbc_cdm_data[30]) ? 1'b0 : cfg_bw_mgt_status) : 1'b0;
        cfg_link_auto_bw_status     <= #TP cfg_bw_notification_cap ? (smlh_link_auto_bw_status ? 1'b1 : (write_pulse[3] & cfg_cap_reg_id[10] & lbc_cdm_data[31]) ? 1'b0 : cfg_link_auto_bw_status) : 1'b0;
        link_auto_bw_msi_src_d      <= #TP link_auto_bw_msi_src;
        cfg_link_auto_bw_msi        <= #TP link_auto_bw_msi_src & ~link_auto_bw_msi_src_d;
        bw_mgt_msi_src_d            <= #TP bw_mgt_msi_src;
        cfg_bw_mgt_msi              <= #TP bw_mgt_msi_src & ~bw_mgt_msi_src_d;
    // Interrupt generation for Link BW Notification & link autonomous BW
        cfg_bw_mgt_int              <= #TP cfg_bw_mgt_int_en       &  cfg_bw_mgt_status & !cfg_int_disable  & ~(cfg_msi_en | cfg_msix_en) ;
        cfg_link_auto_bw_int        <= #TP cfg_link_auto_bw_int_en &  cfg_link_auto_bw_status & !cfg_int_disable  & ~(cfg_msi_en | cfg_msix_en);
    end
end

// Slot cap is only applied to Downstream port

// -----------------------------------------------------------------------------
// Slot Capabilities Register
// cfg_cap_reg_id   - 11
// PCIE Offset      - `CFG_PCIE_CAP + 14h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_108, cfg_reg_109, cfg_reg_110, cfg_reg_111
// -----------------------------------------------------------------------------
reg [12:0]  cfg_pcie_phy_slot_num;
reg         cfg_pcie_slot_no_cc_support;
reg         cfg_pcie_slot_eml_present;
wire[9:0]   cfg_pcie_slot_pwr_limit;
reg [1:0]   cfg_pcie_slot_pwr_limit_scale;
reg [7:0]   cfg_pcie_slot_pwr_limit_value;
reg         cfg_pcie_slot_hp_surprise;
reg         cfg_pcie_slot_pwr_indc_present;
reg         cfg_pcie_slot_attn_indc_present;
reg         cfg_pcie_slot_mrl_sensor_present;
reg         cfg_pcie_slot_pwr_ctrl_present;
reg         cfg_pcie_slot_attn_butt_present;
assign      cfg_pcie_slot_pwr_limit = {cfg_pcie_slot_pwr_limit_scale, cfg_pcie_slot_pwr_limit_value};

assign  {cfg_reg_111, cfg_reg_110, cfg_reg_109, cfg_reg_108} = !upstream_port ? {cfg_pcie_phy_slot_num, cfg_pcie_slot_no_cc_support,
                                                                cfg_pcie_slot_eml_present, cfg_pcie_slot_pwr_limit_scale,
                                                                cfg_pcie_slot_pwr_limit_value, cfg_pcie_slot_hp_cap,
                                                                cfg_pcie_slot_hp_surprise, cfg_pcie_slot_pwr_indc_present,
                                                                cfg_pcie_slot_attn_indc_present, cfg_pcie_slot_mrl_sensor_present,
                                                                cfg_pcie_slot_pwr_ctrl_present, cfg_pcie_slot_attn_butt_present}
                                                                              : 32'h0;



// Detect a write to this register because it'll cause set_slot_pwr_limit message to be sent.
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_slot_pwr_limit_wr   <= #TP 0;
    end else begin
        cfg_slot_pwr_limit_wr   <= #TP |write_pulse[2:0] & cfg_cap_reg_id[11];
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        cfg_pcie_phy_slot_num           <= #TP `SLOT_PHY_SLOT_NUM;
        cfg_pcie_slot_no_cc_support     <= #TP `SLOT_NO_CC_SUPPORT;
        cfg_pcie_slot_eml_present       <= #TP `SLOT_EML_PRESENT;
        cfg_pcie_slot_pwr_limit_scale   <= #TP `SET_SLOT_PWR_LIMIT_SCALE;
        cfg_pcie_slot_pwr_limit_value   <= #TP `SET_SLOT_PWR_LIMIT_VAL;
        cfg_pcie_slot_hp_cap            <= #TP `SLOT_HP_CAPABLE;
        cfg_pcie_slot_hp_surprise       <= #TP `SLOT_HP_SURPRISE;
        cfg_pcie_slot_pwr_indc_present  <= #TP `SLOT_PWR_IND_PRESENT;
        cfg_pcie_slot_attn_indc_present <= #TP `SLOT_ATTEN_IND_PRESENT;
        cfg_pcie_slot_mrl_sensor_present<= #TP `SLOT_MRL_SENSOR_PRESENT;
        cfg_pcie_slot_pwr_ctrl_present  <= #TP `SLOT_PWR_CTRL_PRESENT;
        cfg_pcie_slot_attn_butt_present <= #TP `SLOT_ATTEN_BUTTON_PRESENT;
    end else begin
        if (!upstream_port) begin
            cfg_pcie_phy_slot_num[12:5]     <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[11]) ? lbc_cdm_data[31:24] : cfg_pcie_phy_slot_num[12:5];
            cfg_pcie_phy_slot_num[4:0]      <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[11]) ? lbc_cdm_data[23:19] : cfg_pcie_phy_slot_num[4:0];
            cfg_pcie_slot_no_cc_support     <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[11]) ? lbc_cdm_data[18] : cfg_pcie_slot_no_cc_support;
            cfg_pcie_slot_eml_present       <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[11]) ? lbc_cdm_data[17] : cfg_pcie_slot_eml_present;
            cfg_pcie_slot_pwr_limit_scale[1]<= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[11]) ? lbc_cdm_data[16] : cfg_pcie_slot_pwr_limit_scale[1];
            cfg_pcie_slot_pwr_limit_scale[0]<= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[11]) ? lbc_cdm_data[15] : cfg_pcie_slot_pwr_limit_scale[0];
            cfg_pcie_slot_pwr_limit_value[7:1]<= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[11]) ? lbc_cdm_data[14:8] : cfg_pcie_slot_pwr_limit_value[7:1];
            cfg_pcie_slot_pwr_limit_value[0]<= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[7] : cfg_pcie_slot_pwr_limit_value[0];
            cfg_pcie_slot_hp_cap            <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[6] : cfg_pcie_slot_hp_cap;
            cfg_pcie_slot_hp_surprise       <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[5] : cfg_pcie_slot_hp_surprise;
            cfg_pcie_slot_pwr_indc_present  <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[4] : cfg_pcie_slot_pwr_indc_present;
            cfg_pcie_slot_attn_indc_present <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[3] : cfg_pcie_slot_attn_indc_present;
            cfg_pcie_slot_mrl_sensor_present<= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[2] : cfg_pcie_slot_mrl_sensor_present;
            cfg_pcie_slot_pwr_ctrl_present  <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[1] : cfg_pcie_slot_pwr_ctrl_present;
            cfg_pcie_slot_attn_butt_present <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[0] : cfg_pcie_slot_attn_butt_present;
        end
        else begin
            cfg_pcie_phy_slot_num           <= #TP `SLOT_PHY_SLOT_NUM;
            cfg_pcie_slot_no_cc_support     <= #TP `SLOT_NO_CC_SUPPORT;
            cfg_pcie_slot_eml_present       <= #TP `SLOT_EML_PRESENT;
            cfg_pcie_slot_pwr_limit_scale   <= #TP `SET_SLOT_PWR_LIMIT_SCALE;
            cfg_pcie_slot_pwr_limit_value   <= #TP `SET_SLOT_PWR_LIMIT_VAL;
            cfg_pcie_slot_hp_cap            <= #TP `SLOT_HP_CAPABLE;
            cfg_pcie_slot_hp_surprise       <= #TP `SLOT_HP_SURPRISE;
            cfg_pcie_slot_pwr_indc_present  <= #TP `SLOT_PWR_IND_PRESENT;
            cfg_pcie_slot_attn_indc_present <= #TP `SLOT_ATTEN_IND_PRESENT;
            cfg_pcie_slot_mrl_sensor_present<= #TP `SLOT_MRL_SENSOR_PRESENT;
            cfg_pcie_slot_pwr_ctrl_present  <= #TP `SLOT_PWR_CTRL_PRESENT;
            cfg_pcie_slot_attn_butt_present <= #TP `SLOT_ATTEN_BUTTON_PRESENT;
        end
    end
end

// -----------------------------------------------------------------------------
// Slot Control/Status Register
// cfg_cap_reg_id   - 12
// PCIE Offset      - `CFG_PCIE_CAP + 18h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_112, cfg_reg_113, cfg_reg_114, cfg_reg_115
// -----------------------------------------------------------------------------
reg cfg_dll_state_chged_reg;
reg cfg_atten_button_pressed_reg;
reg cfg_pwr_fault_det_reg;
reg cfg_mrl_sensor_chged_reg;
reg cfg_pre_det_chged_reg;
reg cfg_cmd_cpled_int_reg;
reg cfg_pre_det_chged_en;
reg cfg_mrl_sensor_chged_en_r;
reg cfg_pwr_fault_det_en_r;
reg cfg_atten_button_pressed_en_r;
reg cfg_cmd_cpled_int_en_r;
reg cfg_hp_slot_ctrl_access;


// Output to Hot-plug controller
assign cfg_atten_button_pressed = cfg_atten_button_pressed_reg & cfg_atten_button_pressed_en_r;
assign cfg_pwr_fault_det        = cfg_pwr_fault_det_reg        & cfg_pwr_fault_det_en_r;
assign cfg_mrl_sensor_chged     = cfg_mrl_sensor_chged_reg     & cfg_mrl_sensor_chged_en_r;
assign cfg_pre_det_chged        = cfg_pre_det_chged_reg        & cfg_pre_det_chged_en;
assign cfg_cmd_cpled_int        = cfg_cmd_cpled_int_reg        & cfg_cmd_cpled_int_en_r;
assign cfg_dll_state_chged      = cfg_dll_state_chged_reg      & cfg_dll_state_chged_en;

// Slot Control
assign cfg_reg_112  = !upstream_port ? {cfg_atten_ind, cfg_hp_int_en, cfg_cmd_cpled_int_en_r, cfg_pre_det_chged_en,
                       cfg_mrl_sensor_chged_en_r, cfg_pwr_fault_det_en_r, cfg_atten_button_pressed_en_r}
                                     : 8'h0;
assign cfg_reg_113  = !upstream_port ? {2'b0, cfg_auto_slot_pwr_lmt_dis, cfg_dll_state_chged_en , 1'b0, cfg_pwr_ctrler_ctrl, cfg_pwr_ind}
                                     : 8'h0;
// Slot Status
assign cfg_reg_115  = !upstream_port ? {7'b0, cfg_dll_state_chged_reg} : 8'h0;
assign cfg_reg_114  = !upstream_port ? {sys_eml_interlock_engaged,
                                       (upstream_port ? 1'b0 : (cfg_pcie_cap_slot_impl ? sys_pre_det_state : 1'b1)),
                                       sys_mrl_sensor_state,
                                       cfg_cmd_cpled_int_reg,
                                       cfg_pre_det_chged_reg,
                                       cfg_mrl_sensor_chged_reg,
                                       cfg_pwr_fault_det_reg,
                                       cfg_atten_button_pressed_reg}
                                     : 8'h0;

  always @(posedge core_clk or negedge non_sticky_rst_n)
  begin
    if (!non_sticky_rst_n) begin
      cfg_hp_slot_ctrl_access <= #TP 0;
    end else begin
      cfg_hp_slot_ctrl_access <= #TP (write_pulse[0] || write_pulse[1]) && cfg_cap_reg_id[12];
    end
  end

// Slot Control (18h)
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_atten_button_pressed_en_r <= #TP 0;
        cfg_pwr_fault_det_en_r        <= #TP 0;
        cfg_mrl_sensor_chged_en_r     <= #TP 0;
        cfg_pre_det_chged_en          <= #TP 0;
        cfg_cmd_cpled_int_en_r        <= #TP 0;
        cfg_hp_int_en                 <= #TP 0;
        cfg_atten_ind                 <= #TP 2'b11;       // Off
        cfg_pwr_ind                   <= #TP 2'b11;       // Off
        cfg_pwr_ctrler_ctrl           <= #TP 0;
        cfg_eml_control               <= #TP 0;
        cfg_dll_state_chged_en        <= #TP 0;
    end else begin
        cfg_atten_button_pressed_en_r <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[0]  : cfg_atten_button_pressed_en_r;
        cfg_pwr_fault_det_en_r      <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[1]  : cfg_pwr_fault_det_en_r;
        cfg_mrl_sensor_chged_en_r   <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[2]  : cfg_mrl_sensor_chged_en_r;
        cfg_pre_det_chged_en        <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[3]  : cfg_pre_det_chged_en;
        cfg_cmd_cpled_int_en_r      <= #TP cfg_pcie_slot_no_cc_support ? 1'b0
                                           : (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[4]: cfg_cmd_cpled_int_en_r;
        cfg_hp_int_en               <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[5]  : cfg_hp_int_en;
        cfg_atten_ind               <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[7:6]: cfg_atten_ind;
        cfg_pwr_ind                 <= #TP (write_pulse[1] & cfg_cap_reg_id[12]) ? lbc_cdm_data[9:8]: cfg_pwr_ind;
        cfg_pwr_ctrler_ctrl         <= #TP (write_pulse[1] & cfg_cap_reg_id[12]) ? lbc_cdm_data[10] : cfg_pwr_ctrler_ctrl;
        // EML control is a pulse, directing EML to toggle
        cfg_eml_control             <= #TP (write_pulse[1] & cfg_cap_reg_id[12]) ? lbc_cdm_data[11] : 1'b0;
        cfg_dll_state_chged_en      <= #TP (write_pulse[1] & cfg_cap_reg_id[12] & cfg_dll_link_rpt_en) ? lbc_cdm_data[12] : cfg_dll_state_chged_en;
    end
end

assign cfg_auto_slot_pwr_lmt_dis = 1'b0;

// Slot Status (1Ah)
// RW1C registers:
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_atten_button_pressed_reg<= #TP 0;
        cfg_pwr_fault_det_reg       <= #TP 0;
        cfg_mrl_sensor_chged_reg    <= #TP 0;
        cfg_pre_det_chged_reg       <= #TP 0;
        cfg_cmd_cpled_int_reg       <= #TP 0;
        cfg_dll_state_chged_reg     <= #TP 0;
    end else begin
        cfg_atten_button_pressed_reg<= #TP ~cfg_pcie_slot_attn_butt_present ? 1'b0
                                          : (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[16]) ? 1'b0
                                          : sys_atten_button_pressed ? 1'b1 : cfg_atten_button_pressed_reg;
        cfg_pwr_fault_det_reg       <= #TP ~cfg_pcie_slot_pwr_ctrl_present ? 1'b0
                                          : (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[17]) ? 1'b0
                                          : sys_pwr_fault_det ? 1'b1 : cfg_pwr_fault_det_reg;
        cfg_mrl_sensor_chged_reg    <= #TP ~cfg_pcie_slot_mrl_sensor_present ? 1'b0
                                          : (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[18]) ? 1'b0
                                          : sys_mrl_sensor_chged ? 1'b1 : cfg_mrl_sensor_chged_reg;
        cfg_pre_det_chged_reg       <= #TP (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[19]) ? 1'b0
                                          : sys_pre_det_chged ? 1'b1 : cfg_pre_det_chged_reg;
        cfg_cmd_cpled_int_reg       <= #TP cfg_pcie_slot_no_cc_support ? 1'b0
                                          : (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[20]) ? 1'b0
                                          : sys_cmd_cpled_int ? 1'b1 : cfg_cmd_cpled_int_reg;
        cfg_dll_state_chged_reg     <= #TP (~cfg_dll_state_chged_en | (write_pulse[3] & cfg_cap_reg_id[12] & lbc_cdm_data[24])) ? 1'b0
                                          : dll_active_chnged ? 1'b1 : cfg_dll_state_chged_reg;
    end
end

// -----------------------------------------------------------------------------
// Root Control Register (Only for Root Complex)
// cfg_cap_reg_id   - 13
// PCIE Offset      - `CFG_PCIE_CAP + 1Ch
// length           - 2 byte
// default value    -
// Cfig register    - cfg_reg_117, cfg_reg_116
// -----------------------------------------------------------------------------
reg root_cap_crs_visibility;
reg root_ctrl_crs_visibility_en;
reg pme_int_en;
reg sys_err_f_err_en;
reg sys_err_nf_err_en;
reg sys_err_cor_err_en;
reg cfg_sys_err_rc;
wire int_sys_err_rc_cor ;
wire int_sys_err_rc_nf ;
wire int_sys_err_rc_f ;
reg  cfg_sys_err_rc_cor ;
reg  cfg_sys_err_rc_nf ;
reg  cfg_sys_err_rc_f ;

assign cfg_reg_116  = rc_device ? {3'b0, root_ctrl_crs_visibility_en, pme_int_en, sys_err_f_err_en, sys_err_nf_err_en, sys_err_cor_err_en} : 0;
assign cfg_reg_117  = 8'b0;

assign int_sys_err_rc_cor = sys_err_cor_err_en & cfg_rprt_err_cor ;
assign int_sys_err_rc_nf  = sys_err_nf_err_en  & cfg_rprt_err_nf ;
assign int_sys_err_rc_f   = sys_err_f_err_en   & cfg_rprt_err_f ;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        sys_err_cor_err_en  <= #TP 0;
        sys_err_nf_err_en   <= #TP 0;
        sys_err_f_err_en    <= #TP 0;
        pme_int_en          <= #TP 0;
        root_ctrl_crs_visibility_en   <= #TP 0;
        cfg_sys_err_rc      <= #TP 0;
        cfg_sys_err_rc_cor  <= #TP 0;
        cfg_sys_err_rc_nf   <= #TP 0;
        cfg_sys_err_rc_f    <= #TP 0;
    end
    else begin
        sys_err_cor_err_en  <= #TP write_pulse[0] & cfg_cap_reg_id[13] ? lbc_cdm_data[0] : sys_err_cor_err_en;
        sys_err_nf_err_en   <= #TP write_pulse[0] & cfg_cap_reg_id[13] ? lbc_cdm_data[1] : sys_err_nf_err_en;
        sys_err_f_err_en    <= #TP write_pulse[0] & cfg_cap_reg_id[13] ? lbc_cdm_data[2] : sys_err_f_err_en;
        pme_int_en          <= #TP write_pulse[0] & cfg_cap_reg_id[13] ? lbc_cdm_data[3] : pme_int_en;
        root_ctrl_crs_visibility_en   <= #TP root_cap_crs_visibility ? ((write_pulse[0] & cfg_cap_reg_id[13]) ? lbc_cdm_data[4] : root_ctrl_crs_visibility_en) : 0; 
 
        // System Error signal to the system
        cfg_sys_err_rc      <= #TP int_sys_err_rc_cor | int_sys_err_rc_nf | int_sys_err_rc_f ;
        // System Error signal per kind of errors to the diag_status_bus
        cfg_sys_err_rc_cor  <= #TP int_sys_err_rc_cor ;
        cfg_sys_err_rc_nf   <= #TP int_sys_err_rc_nf ;
        cfg_sys_err_rc_f    <= #TP int_sys_err_rc_f ;
    end
end

assign cfg_crs_sw_vis_en = root_ctrl_crs_visibility_en;

// -----------------------------------------------------------------------------
// Root Capabilities Register (Only for Root Complex)
// cfg_cap_reg_id   - 13
// PCIE Offset      - `CFG_PCIE_CAP + 1Eh
// length           - 2 byte
// default value    - 0
// Cfig register    - cfg_reg_119, cfg_reg_118
// -----------------------------------------------------------------------------

assign cfg_reg_118  = {7'b0, root_cap_crs_visibility};
assign cfg_reg_119  = 8'b0;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (~sticky_rst_n) begin
        root_cap_crs_visibility   <= #TP `DEFAULT_CRS_SW_VISIBILITY_CAP; 
     end
    else begin
        root_cap_crs_visibility   <= #TP rc_device ? (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[13] ? lbc_cdm_data[16] : root_cap_crs_visibility) : 0;  
    end
end

// -----------------------------------------------------------------------------
// Root Status Register (Only for Root Complex)
// cfg_cap_reg_id   - 14
// PCIE Offset      - `CFG_PCIE_CAP + 20h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_123, cfg_reg_122, cfg_reg_121, cfg_reg_120
//
// This register stores the req ID of a received PME.
// If there's another PME before software clears the current one, we have to
// latch it and assert pme_pending.
// -----------------------------------------------------------------------------

wire[FX_TLP*16-1:0]  pme_req_id;
wire[FX_TLP-1:0] pme_status;

assign  pme_status = radm_pm_pme;
assign  pme_req_id = radm_msg_req_id;

reg [15:0]  latched_pme_req_id;
reg [15:0]  pending_pme_req_id;
reg         latched_pme_status;
reg         pme_pending;

assign {cfg_reg_121, cfg_reg_120} = rc_device ? latched_pme_req_id : 0;
assign cfg_reg_122 = rc_device ? {6'h0, pme_pending, latched_pme_status} : 0;
assign cfg_reg_123 = 0;

reg latched_pme_pending;
wire clear_pme;
assign clear_pme = (write_pulse[2] & cfg_cap_reg_id[14] & lbc_cdm_data[16]);

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        latched_pme_req_id  <= #TP 0;
        latched_pme_status  <= #TP 0;
        latched_pme_pending <= #TP 0;
        pme_pending         <= #TP 0;
        pending_pme_req_id  <= #TP 0;
    end
    else begin
        latched_pme_req_id  <= #TP (pme_status[0] & !latched_pme_status) ? pme_req_id[15:0] :
            (clear_pme & pme_pending) ? pending_pme_req_id : latched_pme_req_id;
         latched_pme_status  <= #TP (clear_pme) ? 1'b0 : ((latched_pme_pending || (|pme_status)) ? 1'b1 : latched_pme_status);
         latched_pme_pending <= #TP (clear_pme) ? pme_pending : latched_pme_pending ;
         pme_pending         <= #TP (clear_pme) ? 1'b0 : ((latched_pme_status & pme_status[0]) ? 1'b1 :
            pme_pending);
        pending_pme_req_id  <= #TP (pme_status[0] & latched_pme_status) ? pme_req_id[15:0] :
            pending_pme_req_id;
    end
end

// PME Interrupt & MSI generation
reg cfg_pme_int;
reg cfg_pme_msi;
reg pme_msi_src_d;
wire pme_msi_src;

assign pme_msi_src = pme_int_en & latched_pme_status & (cfg_msi_en | cfg_msix_en);

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        cfg_pme_int         <= #TP 0;
        cfg_pme_msi         <= #TP 0;
        pme_msi_src_d       <= #TP 0;
    end
    else begin
        // PME Interrupt - level signal
        cfg_pme_int     <= #TP pme_int_en & !cfg_int_disable & latched_pme_status & ~(cfg_msi_en | cfg_msix_en);

        // PME MSI/MSI-X - pulse signal
        cfg_pme_msi     <= #TP pme_msi_src & ~pme_msi_src_d;
        pme_msi_src_d   <= #TP pme_msi_src;
    end
end

// -----------------------------------------------------------------------------
// Device Capabilities 2 Register
// cfg_cap_reg_id   - 22
// PCIE Offset      - `CFG_PCIE_CAP + 24h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_143, cfg_reg_142, cfg_reg_141, cfg_reg_140
// -----------------------------------------------------------------------------
wire    [3:0]   cfg_cpl_timeout_supt_range;
wire            cfg_cpl_timeout_supt_disable;
wire            cfg_ari_fwd_supt;
wire    [1:0]   cfg_tph_cpl_en;
wire            cfg_ro_en_no_pr_pr_passing;
wire            cfg_atomic_routing_sup;
wire            cfg_atomic_32_cpl_sup;
wire            cfg_atomic_64_cpl_sup;
wire            cfg_atomic_128_cas_sup;
wire            cfg_10bits_tag_req_support;
wire            cfg_10bits_tag_comp_support;
wire            cfg_dmwr_cpl_sup;
wire    [1:0]   cfg_dmwr_len_sup;

assign cfg_10bits_tag_comp_support = (`CX_10BITS_TAG_VALUE == 1)? 1'b1: 1'b0;
assign cfg_10bits_tag_req_support  = (`CX_10BITS_TAG_VALUE == 1 && `CX_10BITS_TAG_REQ_VALUE == 1)? 1'b1: 1'b0;

assign cfg_cpl_timeout_supt_range   = 4'b0000;  // optional ranges not supported.
assign cfg_ari_fwd_supt           = (pcie_sw_down | rc_device) ?
                                    `CX_ARI_FWD_ENABLE : 1'b0;
assign cfg_tph_cpl_en             = (end_device || rc_device) ?
                                    {1'b0,`CX_TPH_ENABLE_VALUE} : 2'b00;
assign cfg_ro_en_no_pr_pr_passing = (rc_device || switch_device) ? 1'b1 : 1'b0;

assign cfg_atomic_routing_sup     = (rc_device || switch_device) ? `CX_ATOMIC_ROUTING_EN : 1'b0;

assign cfg_atomic_32_cpl_sup      = `CX_ATOMIC_32_CPL_EN;
assign cfg_atomic_64_cpl_sup      = `CX_ATOMIC_64_CPL_EN;
assign cfg_atomic_128_cas_sup     = `CX_ATOMIC_128_CAS_EN;

assign cfg_cpl_timeout_supt_disable = (end_device | rc_device) ? 1'b1 : 1'b0;



// OBFF Supported is writable via DBI iff CX_OBFF_SUPPORT is set
wire    [1:0]   cfg_obff_support;       // OBFF Supported
assign    cfg_obff_support    = 2'b00;


// LTR Mechanism Supported is writable via DBI iff CX_LTR_M_ENABLE is set
wire      cfg_ltr_m_suprtd;       // LTR Mechanism Supported
assign    cfg_ltr_m_suprtd    = 1'b0;


// Max End-End TLP Prefixes and End-End TLP Prefixes Supported are writeable via DBI iff TLP Prefixes are
// enabled
wire    [1:0]   cfg_max_end2end_tlp_prfxs;       // the maximum number of End-End TLP Prefixes supported; DBI writeable.
wire            cfg_extnd_fmt_support;           // TLP Prefix - FMT(2) support
wire            cfg_end2end_tlp_prfx_support;    // TLP Prefix of type End-End support; DBI writeable.
assign    cfg_max_end2end_tlp_prfxs    = 2'b00;
assign    cfg_end2end_tlp_prfx_support = 1'b0;
assign    cfg_extnd_fmt_support        = 1'b0;


  wire [1:0]  cfg_ln_system_cls;
  assign      cfg_ln_system_cls = 2'b00;


assign cfg_reg_140 = {cfg_atomic_32_cpl_sup,cfg_atomic_routing_sup, cfg_ari_fwd_supt,
                      cfg_cpl_timeout_supt_disable, cfg_cpl_timeout_supt_range};
assign cfg_reg_141 = {cfg_ln_system_cls, cfg_tph_cpl_en,cfg_ltr_m_suprtd,cfg_ro_en_no_pr_pr_passing,
                      cfg_atomic_128_cas_sup,cfg_atomic_64_cpl_sup};
assign cfg_reg_142 = {cfg_max_end2end_tlp_prfxs, cfg_end2end_tlp_prfx_support, cfg_extnd_fmt_support, cfg_obff_support, cfg_10bits_tag_req_support, cfg_10bits_tag_comp_support};



assign cfg_dmwr_cpl_sup     = `CX_DEF_MEM_WR_CPL_EN;
assign cfg_dmwr_len_sup     = ((`CX_DEF_MEM_WR_ROUTING_EN == 1) || (`CX_DEF_MEM_WR_CPL_EN == 1))? `CX_DEF_MEM_WR_LEN_SUPP : 0;


assign cfg_reg_143 = {                        1'b0,
                        cfg_dmwr_len_sup,
                        cfg_dmwr_cpl_sup,
                        1'b0,
                        3'b0
                     };

// -----------------------------------------------------------------------------
// Device Control 2 Register
// cfg_cap_reg_id   - 23
// PCIE Offset      - `CFG_PCIE_CAP + 28h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_147, cfg_reg_146, cfg_reg_145, cfg_reg_144
// -----------------------------------------------------------------------------



assign cfg_reg_144 = {2'h0, cfg_ari_fwd_en,
                      cfg_cpl_timeout_disable,
                      cfg_cpl_timeout_range};
assign cfg_reg_145 = {                      1'b0,
                      2'b00,
                      1'b0,
                      1'b0,
                      1'b0,
                      2'b00
                      };

assign cfg_reg_146 = 0;
assign cfg_reg_147 = 0;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        cfg_cpl_timeout_range   <= #TP 4'b0000; // Default range: 50us to 50ms
        cfg_cpl_timeout_disable <= #TP 0;
        cfg_ari_fwd_en          <= #TP 0;
    end
    else begin
        cfg_cpl_timeout_range   <= #TP 4'b0000;
        cfg_cpl_timeout_disable <= #TP write_pulse[0] & cfg_cap_reg_id[23] & cfg_cpl_timeout_supt_disable ? lbc_cdm_data[4] : cfg_cpl_timeout_disable;

        cfg_ari_fwd_en          <= #TP write_pulse[0] & cfg_cap_reg_id[23] & cfg_ari_fwd_supt ? lbc_cdm_data[5] : cfg_ari_fwd_en;
    end
end





// -----------------------------------------------------------------------------
// Link Capabilities 2 Register
// cfg_cap_reg_id   - 29
// PCIE Offset      - `CFG_PCIE_CAP + 2Ch
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_151, cfg_reg_150, cfg_reg_149, cfg_reg_148
// -----------------------------------------------------------------------------
wire    [6:0]   cfg_pcie_supp_link_speed_vector;        // Supported Link Speeds Vector
wire    [6:0]   cfg_pcie_supp_link_speed_vector_int;    // Supported Link Speeds Vector for Conventional PCIe
wire            cfg_pcie_crosslink_supported;

assign cfg_pcie_supp_link_speed_vector_int   =



                                                                                                                  7'h1  ;
assign cfg_pcie_supp_link_speed_vector_mpcie = 7'h00 ;      // Not Used in Conventional PCIe.

assign cfg_pcie_supp_link_speed_vector       = (phy_type ==  `PHY_TYPE_MPCIE) ? cfg_pcie_supp_link_speed_vector_mpcie : cfg_pcie_supp_link_speed_vector_int ;

assign cfg_pcie_crosslink_supported = 1'b0;

assign cfg_reg_148 = {cfg_pcie_supp_link_speed_vector, 1'b0};
assign cfg_reg_149 = {7'h0, cfg_pcie_crosslink_supported};
assign cfg_reg_150 = 0;


assign cfg_reg_151[7:1] = 7'b0;
assign cfg_reg_151[0] = 1'b0;



assign cfg_reg_152 = 0;
assign cfg_reg_153 = 0;
assign cfg_reg_154 = 0;
assign cfg_reg_155[3:0] = 4'b0;
assign cfg_retimers_pre_detected = 2'b00;


  localparam DCP_LD_PRES_NOT_DET  = 3'b000;         //downstream component presence, link down - presence not determined
  localparam DCP_LD_COMP_NOT_PRES = 3'b001;         //downstream component presence, link down - component not present
  localparam DCP_LD_COMP_PRES     = 3'b010;         //downstream component presence, link down - component present
  localparam DCP_LU_COMP_PRES     = 3'b100;         //downstream component presence, link up - component present
  localparam DCP_LU_COMP_PRES_DRS = 3'b101;         //downstream component presence, link up - component present and DRS message received


assign cfg_reg_155[7:4] = { 4'b0};                      // [7:4] Reserved




// =============================================================================
// MSI-X Capability Structure
// =============================================================================
// MSI-X CAP register
// cfg_cap_reg_id   - 16
// PCIE Offset      - `CFG_MSIX_CAP
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_131, cfg_reg_130, cfg_reg_129, cfg_reg_128
// -----------------------------------------------------------------------------
reg          cfg_msix_en;
reg  [7:0]   cfg_msix_next_ptr;
reg          cfg_msix_func_mask;
reg  [10:0]  cfg_msix_table_size;
reg  [10:0]  cfg_msix_table_size2;
wire [10:0]  rdata_msix_table_size;
   
assign cfg_reg_128 = 8'h11;                                         // MSI-X Cap ID
assign cfg_reg_129 = cfg_msix_next_ptr;
assign {cfg_reg_131, cfg_reg_130} = {cfg_msix_en, cfg_msix_func_mask, 3'b0,
                                     rdata_msix_table_size};

assign rdata_msix_table_size = cfg_msix_table_size ;
                        
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_msix_func_mask          <= #TP 0;
        cfg_msix_en                 <= #TP 0;
    end else begin
        if (msix_cap_enable) begin
            // RW - protected on dbi2 access
            cfg_msix_func_mask          <= #TP (write_pulse[3] & cfg_cap_reg_id[16]) ? lbc_cdm_data[30] : cfg_msix_func_mask;
            cfg_msix_en                 <= #TP (write_pulse[3] & cfg_cap_reg_id[16]) ? lbc_cdm_data[31] : cfg_msix_en;
        end
        else begin
            cfg_msix_func_mask          <= #TP 0;
            cfg_msix_en                 <= #TP 0;
        end
    end
end


always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_msix_table_size         <= #TP `MSIX_TABLE_SIZE;
        cfg_msix_table_size2        <= #TP `MSIX_TABLE_SIZE;
        cfg_msix_next_ptr           <= #TP `MSIX_NEXT_PTR;
    end else begin
        if (msix_cap_enable) begin
            // Read-Only register, but writable through DBI
            cfg_msix_table_size[10:8]   <= #TP (int_lbc_cdm_dbi   & write_pulse[3] & cfg_cap_reg_id[16]) ? lbc_cdm_data[26:24] : cfg_msix_table_size[10:8];
            cfg_msix_table_size[7:0]    <= #TP (int_lbc_cdm_dbi   & write_pulse[2] & cfg_cap_reg_id[16]) ? lbc_cdm_data[23:16] : cfg_msix_table_size[7:0];
            cfg_msix_table_size2[10:8]  <= #TP (int_lbc_cdm_dbi2  & write_pulse[3] & cfg_cap_reg_id[16]) ? lbc_cdm_data[26:24] : cfg_msix_table_size2[10:8];
            cfg_msix_table_size2[7:0]   <= #TP (int_lbc_cdm_dbi2  & write_pulse[2] & cfg_cap_reg_id[16]) ? lbc_cdm_data[23:16] : cfg_msix_table_size2[7:0];
            cfg_msix_next_ptr           <= #TP (int_lbc_cdm_dbi   & write_pulse[1] & cfg_cap_reg_id[16]) ? lbc_cdm_data[15:8]  : cfg_msix_next_ptr;
        end
        else begin
            cfg_msix_table_size         <= #TP `MSIX_TABLE_SIZE;
            cfg_msix_table_size2        <= #TP `MSIX_TABLE_SIZE;
            cfg_msix_next_ptr           <= #TP `MSIX_NEXT_PTR;
        end
    end
end

// -----------------------------------------------------------------------------
// MSI-X Table Offset/Table BIR
// cfg_cap_reg_id   - 17
// PCIE Offset      - `CFG_MSIX_CAP + 04h
// Length           - 4 bytes
// Default value    - {`MSIX_TABLE_OFFSET, `MSIX_TABLE_BIR}
// Cfig register    - cfg_reg_135, cfg_reg_134, cfg_reg_133, cfg_reg_132
// -----------------------------------------------------------------------------
reg [2:0]   cfg_msix_table_bir, cfg_msix_table_bir2;
reg [28:0]  cfg_msix_table_offset, cfg_msix_table_offset2;
wire [2:0]  rdata_msix_table_bir;
wire [28:0] rdata_msix_table_offset;

assign cfg_reg_132 = {rdata_msix_table_offset[4:0], rdata_msix_table_bir};
assign {cfg_reg_135, cfg_reg_134, cfg_reg_133} = rdata_msix_table_offset[28:5]; 

assign rdata_msix_table_bir    = cfg_msix_table_bir ;
assign rdata_msix_table_offset = cfg_msix_table_offset ;
 
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_msix_table_bir          <= #TP `MSIX_TABLE_BIR;
        cfg_msix_table_offset       <= #TP `MSIX_TABLE_OFFSET;
        cfg_msix_table_bir2         <= #TP `VF_MSIX_TABLE_BIR;
        cfg_msix_table_offset2      <= #TP `VF_MSIX_TABLE_OFFSET;

    end else begin
        if (msix_cap_enable) begin
            // Read-Only register, but writable through DBI
            cfg_msix_table_bir          <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[17]) ? lbc_cdm_data[2:0]   : cfg_msix_table_bir;
            cfg_msix_table_offset[4:0]  <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[17]) ? lbc_cdm_data[7:3]   : cfg_msix_table_offset[4:0];
            cfg_msix_table_offset[12:5] <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[17]) ? lbc_cdm_data[15:8]  : cfg_msix_table_offset[12:5];
            cfg_msix_table_offset[20:13]<= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[17]) ? lbc_cdm_data[23:16] : cfg_msix_table_offset[20:13];
            cfg_msix_table_offset[28:21]<= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[17]) ? lbc_cdm_data[31:24] : cfg_msix_table_offset[28:21];
            // Read-Only register, but writable through DBI2
            cfg_msix_table_bir2          <= #TP (int_lbc_cdm_dbi2 & write_pulse[0] & cfg_cap_reg_id[17]) ? lbc_cdm_data[2:0]   : cfg_msix_table_bir2;
            cfg_msix_table_offset2[4:0]  <= #TP (int_lbc_cdm_dbi2 & write_pulse[0] & cfg_cap_reg_id[17]) ? lbc_cdm_data[7:3]   : cfg_msix_table_offset2[4:0];
            cfg_msix_table_offset2[12:5] <= #TP (int_lbc_cdm_dbi2 & write_pulse[1] & cfg_cap_reg_id[17]) ? lbc_cdm_data[15:8]  : cfg_msix_table_offset2[12:5];
            cfg_msix_table_offset2[20:13]<= #TP (int_lbc_cdm_dbi2 & write_pulse[2] & cfg_cap_reg_id[17]) ? lbc_cdm_data[23:16] : cfg_msix_table_offset2[20:13];
            cfg_msix_table_offset2[28:21]<= #TP (int_lbc_cdm_dbi2 & write_pulse[3] & cfg_cap_reg_id[17]) ? lbc_cdm_data[31:24] : cfg_msix_table_offset2[28:21];
        end
        else begin
            cfg_msix_table_bir          <= #TP `MSIX_TABLE_BIR;
            cfg_msix_table_offset       <= #TP `MSIX_TABLE_OFFSET;
            cfg_msix_table_bir2         <= #TP `VF_MSIX_TABLE_BIR;
            cfg_msix_table_offset2      <= #TP `VF_MSIX_TABLE_OFFSET;
        end
    end
end

// -----------------------------------------------------------------------------
// MSI-X PBA Offset/PBA BIR
// cfg_cap_reg_id   - 18
// PCIE Offset      - `CFG_MSIX_CAP + 08h
// Length           - 4 bytes
// Default value    - {`MSIX_PBA_OFFSET, `MSIX_PBA_BIR}
// Cfig register    - cfg_reg_139, cfg_reg_138, cfg_reg_137, cfg_reg_136
// -----------------------------------------------------------------------------
reg [2:0]   cfg_msix_pba_bir, cfg_msix_pba_bir2;
reg [28:0]  cfg_msix_pba_offset, cfg_msix_pba_offset2;
wire [2:0]  rdata_msix_pba_bir;
wire [28:0] rdata_msix_pba_offset;

assign cfg_reg_136 = {rdata_msix_pba_offset[4:0], rdata_msix_pba_bir};
assign {cfg_reg_139, cfg_reg_138, cfg_reg_137} = rdata_msix_pba_offset[28:5];

assign rdata_msix_pba_bir    = cfg_msix_pba_bir ;
assign rdata_msix_pba_offset = cfg_msix_pba_offset ;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_msix_pba_bir            <= #TP `MSIX_PBA_BIR;
        cfg_msix_pba_offset         <= #TP `MSIX_PBA_OFFSET;
        cfg_msix_pba_bir2           <= #TP `VF_MSIX_PBA_BIR;
        cfg_msix_pba_offset2        <= #TP `VF_MSIX_PBA_OFFSET;
    end else begin
        if (msix_cap_enable) begin
            // Read-Only register, but writable through DBI
            cfg_msix_pba_bir            <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[18]) ? lbc_cdm_data[2:0]   : cfg_msix_pba_bir;
            cfg_msix_pba_offset[4:0]    <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[18]) ? lbc_cdm_data[7:3]   : cfg_msix_pba_offset[4:0];
            cfg_msix_pba_offset[12:5]   <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[18]) ? lbc_cdm_data[15:8]  : cfg_msix_pba_offset[12:5];
            cfg_msix_pba_offset[20:13]  <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[18]) ? lbc_cdm_data[23:16] : cfg_msix_pba_offset[20:13];
            cfg_msix_pba_offset[28:21]  <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[18]) ? lbc_cdm_data[31:24] : cfg_msix_pba_offset[28:21];
            // Read-Only register, but writable through DBI
            cfg_msix_pba_bir2            <= #TP (int_lbc_cdm_dbi2 & write_pulse[0] & cfg_cap_reg_id[18]) ? lbc_cdm_data[2:0]   : cfg_msix_pba_bir2;
            cfg_msix_pba_offset2[4:0]    <= #TP (int_lbc_cdm_dbi2 & write_pulse[0] & cfg_cap_reg_id[18]) ? lbc_cdm_data[7:3]   : cfg_msix_pba_offset2[4:0];
            cfg_msix_pba_offset2[12:5]   <= #TP (int_lbc_cdm_dbi2 & write_pulse[1] & cfg_cap_reg_id[18]) ? lbc_cdm_data[15:8]  : cfg_msix_pba_offset2[12:5];
            cfg_msix_pba_offset2[20:13]  <= #TP (int_lbc_cdm_dbi2 & write_pulse[2] & cfg_cap_reg_id[18]) ? lbc_cdm_data[23:16] : cfg_msix_pba_offset2[20:13];
            cfg_msix_pba_offset2[28:21]  <= #TP (int_lbc_cdm_dbi2 & write_pulse[3] & cfg_cap_reg_id[18]) ? lbc_cdm_data[31:24] : cfg_msix_pba_offset2[28:21];
        end
        else begin
            cfg_msix_pba_bir            <= #TP `MSIX_PBA_BIR;
            cfg_msix_pba_offset         <= #TP `MSIX_PBA_OFFSET;
            cfg_msix_pba_bir2           <= #TP `VF_MSIX_PBA_BIR;
            cfg_msix_pba_offset2        <= #TP `VF_MSIX_PBA_OFFSET;
        end
    end
end

// =============================================================================
// PCI SLOT Indentification capability structure
// does not apply to EP
// cfg_cap_reg_id   - 15
// PCIE Offset      - `CFG_SLOT_CAP
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_127, cfg_reg_126, cfg_reg_125, cfg_reg_124
// =============================================================================

reg [7:0] chassis_num;

assign cfg_reg_124 = slot_cap_enable ? 8'h04 : 8'h0;                                     // Slot capability ID
assign cfg_reg_125 = slot_cap_enable ?  `SLOT_NEXT_PTR : 8'h0;
assign cfg_reg_126 = slot_cap_enable ? {2'b0, `FIRST_IN_CHASSIS, `SLOT_NUM} : 8'h0;
assign cfg_reg_127 = slot_cap_enable ? chassis_num : 8'h0;

always @(posedge core_clk or negedge non_sticky_rst_n)
    if (!non_sticky_rst_n) begin
        chassis_num <= #TP 0;
    end else begin
        chassis_num <= #TP slot_cap_enable & write_pulse[3] & cfg_cap_reg_id[15] ? lbc_cdm_data[31:24] : chassis_num;
    end


// =============================================================================
// Vital Product Data (VPD) Capability Structure
// =============================================================================
// VPD CAP register
// cfg_cap_reg_id   - 20
// PCIE Offset      - `CFG_VPD_CAP
// Length           - 4 bytes
// Default value    - {0, 0, `VPD_NEXT_PTR, 0x03}
// Cfig register    - cfg_reg_167, cfg_reg_166, cfg_reg_165, cfg_reg_164
// -----------------------------------------------------------------------------
reg         cfg_vpd_int;
reg         cfg_vpd_flag;
reg [7:0]   cfg_vpd_next_ptr;
reg [14:0]  cfg_vpd_addr;
assign cfg_reg_164 = 8'h03;                                         // VPD Cap ID
assign cfg_reg_165 = cfg_vpd_next_ptr;
assign {cfg_reg_167, cfg_reg_166} = {cfg_vpd_flag, cfg_vpd_addr};

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_vpd_int             <= #TP 0;
        cfg_vpd_addr            <= #TP 0;
        cfg_vpd_flag            <= #TP 0;
    end else begin
        if (vpd_cap_enable) begin
            // If there's a write to this register over the wire, notify the application (pulse).
            cfg_vpd_int         <= #TP (!lbc_cdm_dbi & (write_pulse[2] | write_pulse[3]) & cfg_cap_reg_id[20]);
            // RW
            cfg_vpd_addr[7:0]   <= #TP (write_pulse[2] & cfg_cap_reg_id[20]) ? lbc_cdm_data[23:16] : cfg_vpd_addr[7:0];
            cfg_vpd_addr[14:8]  <= #TP (write_pulse[3] & cfg_cap_reg_id[20]) ? lbc_cdm_data[30:24] : cfg_vpd_addr[14:8];
            cfg_vpd_flag        <= #TP (write_pulse[3] & cfg_cap_reg_id[20]) ? lbc_cdm_data[31] : cfg_vpd_flag;
        end
        else begin
            cfg_vpd_int         <= #TP 0;
            cfg_vpd_addr        <= #TP 0;
            cfg_vpd_flag        <= #TP 0;
        end
    end
end


always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_vpd_next_ptr        <= #TP `VPD_NEXT_PTR;
    end else begin
        if (vpd_cap_enable) begin
            // Read-Only register, but writable through DBI
            cfg_vpd_next_ptr    <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[20]) ? lbc_cdm_data[15:8]  : cfg_vpd_next_ptr;
        end
        else begin
            cfg_vpd_next_ptr    <= #TP `VPD_NEXT_PTR;
        end
    end
end

// -----------------------------------------------------------------------------
// VPD Data
// cfg_cap_reg_id   - 21
// PCIE Offset      - `CFG_VPD_CAP + 04h
// Length           - 4 bytes
// Default value    - 0
// Cfig register    - cfg_reg_171, cfg_reg_170, cfg_reg_169, cfg_reg_168
// -----------------------------------------------------------------------------
reg [31:0]  cfg_vpd_data;

assign {cfg_reg_171, cfg_reg_170, cfg_reg_169, cfg_reg_168} = cfg_vpd_data;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_vpd_data        <= #TP 0;
    end else begin
        if (vpd_cap_enable) begin
            cfg_vpd_data[7:0]   <= #TP (write_pulse[0] & cfg_cap_reg_id[21]) ? lbc_cdm_data[7:0]   : cfg_vpd_data[7:0];
            cfg_vpd_data[15:8]  <= #TP (write_pulse[1] & cfg_cap_reg_id[21]) ? lbc_cdm_data[15:8]  : cfg_vpd_data[15:8];
            cfg_vpd_data[23:16] <= #TP (write_pulse[2] & cfg_cap_reg_id[21]) ? lbc_cdm_data[23:16] : cfg_vpd_data[23:16];
            cfg_vpd_data[31:24] <= #TP (write_pulse[3] & cfg_cap_reg_id[21]) ? lbc_cdm_data[31:24] : cfg_vpd_data[31:24];
        end
        else begin
            cfg_vpd_data        <= #TP 0;
        end
    end
end

assign cfg_reg_172 = 8'b0;
assign cfg_reg_173 = 8'b0;
assign cfg_reg_174 = 8'b0;
assign cfg_reg_175 = 8'b0;
assign cfg_reg_176 = 8'b0;
assign cfg_reg_177 = 8'b0;
assign cfg_reg_178 = 8'b0;
assign cfg_reg_179 = 8'b0;
assign cfg_reg_180 = 8'b0;
assign cfg_reg_181 = 8'b0;
assign cfg_reg_182 = 8'b0;
assign cfg_reg_183 = 8'b0;

genvar num_tlp;
generate
for (num_tlp=0; num_tlp<FX_TLP; num_tlp = num_tlp+1) begin : u_cdm_bar_match_gen

    cdm_bar_match
     #(.INST(INST), .FUNC_NUM(FUNC_NUM)) u_cdm_bar_match
  (
    // -- inputs --
    .core_clk                   (core_clk),
    .non_sticky_rst_n           (non_sticky_rst_n),
    .flt_cdm_addr               (flt_cdm_addr[64*(num_tlp+1)-1:64*num_tlp]),
    .upstream_port              (upstream_port),
    .type0                      (type0),
    .cfg_io_limit_upper16       (cfg_io_limit_upper16),
    .cfg_io_base_upper16        (cfg_io_base_upper16),
    .cfg_io_base                (cfg_io_base),
    .cfg_io_limit               (cfg_io_limit),
    .io_is_32bit                (io_is_32bit),
    .cfg_io_space_en            (cfg_io_space_en),
    .cfg_mem_space_en           (cfg_mem_space_en),
    .cfg_bus_master_en          (cfg_bus_master_en),
    .cfg_isa_enable             (cfg_isa_enable),
    .cfg_vga_enable             (cfg_vga_enable),
    .cfg_vga16_decode           (cfg_vga16_decode),
    .cfg_bar_is_io              (cfg_bar_is_io),
    .cfg_bar_enabled            (cfg_bar_enabled),
    .cfg_bar0_start             (cfg_bar0_start),
    .cfg_bar0_limit             (cfg_bar0_limit),
    .cfg_bar0_mask              (cfg_bar0_mask),
    .cfg_bar1_start             (cfg_bar1_start),
    .cfg_bar1_limit             (cfg_bar1_limit),
    .cfg_bar1_mask              (cfg_bar1_mask),
    .cfg_bar2_start             (cfg_bar2_start),
    .cfg_bar2_limit             (cfg_bar2_limit),
    .cfg_bar2_mask              (cfg_bar2_mask),
    .cfg_bar3_start             (cfg_bar3_start),
    .cfg_bar3_limit             (cfg_bar3_limit),
    .cfg_bar3_mask              (cfg_bar3_mask),
    .cfg_bar4_start             (cfg_bar4_start),
    .cfg_bar4_limit             (cfg_bar4_limit),
    .cfg_bar4_mask              (cfg_bar4_mask),
    .cfg_bar5_start             (cfg_bar5_start),
    .cfg_bar5_limit             (cfg_bar5_limit),
    .cfg_bar5_mask              (cfg_bar5_mask),
    .cfg_exp_rom_enable         (exp_rom_enable),
    .cfg_exp_rom_start          (cfg_exp_rom_start),
    .cfg_exp_rom_mask           (cfg_rom_mask),
    .cfg_mem_base               (cfg_mem_base),
    .cfg_mem_limit              (cfg_mem_limit),
    .cfg_pref_mem_base          (cfg_pref_mem_base),
    .cfg_pref_mem_limit         (cfg_pref_mem_limit),
    .cfg_config_limit           (cfg_config_limit),

    // -- outputs --
    .cfg_io_match               (cfg_io_match[num_tlp]),
    .cfg_config_above_match     (cfg_config_above_match[num_tlp]),
    .cfg_rom_match              (cfg_rom_match[num_tlp]),
    .cfg_bar_match              (cfg_bar_match[6*(num_tlp+1)-1:6*num_tlp]),
    .cfg_mem_match              (cfg_mem_match[num_tlp]),
    .cfg_prefmem_match          (cfg_prefmem_match[num_tlp])
   );
end
endgenerate

assign cfg_bar_is_io = {cfg_bar5_io, cfg_bar4_io, cfg_bar3_io, cfg_bar2_io, cfg_bar1_io, cfg_bar0_io};

// Map Function's BARs to Target0/Target1
//assign   target_mem_map    = {`MEM_FUNC_BAR5_TARGET_MAP, `MEM_FUNC_BAR4_TARGET_MAP, `MEM_FUNC_BAR3_TARGET_MAP,
//                              `MEM_FUNC_BAR2_TARGET_MAP, `MEM_FUNC_BAR1_TARGET_MAP, `MEM_FUNC_BAR0_TARGET_MAP};
//assign   target_rom_map    = `ROM_FUNC_TARGET_MAP;
//`ifdef CX_SRIOV_ENABLE
//assign   vf_target_mem_map = {`VF_MEM_FUNC_BAR5_TARGET_MAP, `VF_MEM_FUNC_BAR4_TARGET_MAP, `VF_MEM_FUNC_BAR3_TARGET_MAP,
//                              `VF_MEM_FUNC_BAR2_TARGET_MAP, `VF_MEM_FUNC_BAR1_TARGET_MAP, `VF_MEM_FUNC_BAR0_TARGET_MAP};
//`endif // CX_SRIOV_ENABLE



// ----------------------------------------------------------------------------
// Assign outputs
// ----------------------------------------------------------------------------


//##############################################################################

`ifndef SYNTHESIS
`endif // SYNTHESIS
//##############################################################################



endmodule
