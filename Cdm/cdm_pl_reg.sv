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
// ---    $DateTime: 2020/09/28 06:58:33 $
// ---    $Revision: #26 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_pl_reg.sv#26 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the PCIE core local registers.
// --- the PCIE configuration cycles and CPU access will be mapped to the
// --- local bus cycles. The total register space is 64K, first 32K is reserved for
// --- configuration registers and second 32K is reserved for core local registers
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module cdm_pl_reg(
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    phy_type,
    app_dbi_ro_wr_disable,
    lbc_cdm_addr,
    lbc_cdm_data,
    pl_reg_sel,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    upstream_port,
    phy_cfg_status,
    cxpl_debug_info,
    smlh_autoneg_link_width,
    cfg_max_payload_size,
    cfg_min_payload_size,
    cfg_comm_clk_config,
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
    smlh_dir_linkw_chg_rising_edge,
    current_data_rate,
    cfg_ext_synch,

    app_dev_num,                     // Application driven device number
    app_bus_num,                    // Application driven bus number
// -- outputs --
    cfg_lane_en,
    cfg_gen1_ei_inference_mode,
    cfg_select_deemph_mux_bus,
    cfg_lut_ctrl,
    cfg_rxstandby_control,
    cfg_pl_multilane_control,
    cfg_pl_l1_nowait_p1,
    cfg_pl_l1_clk_sel,
    cfg_phy_perst_on_warm_reset,
    cfg_phy_rst_timer,
    cfg_pma_phy_rst_delay_timer,
    cfg_pl_aux_clk_freq,
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
    cfg_flow_control_disable,
    cfg_acknack_disable,
    cfg_imp_num_lanes,
    cfg_link_capable,
    cfg_xmt_beacon,
    cfg_tx_reverse_lanes,
    cfg_eidle_timer,
    cfg_skip_interval,
    cfg_link_rate,
    cfg_fast_link_mode,
    cfg_fast_link_scaling_factor,
    cfg_dll_lnk_en,
    pl_reg_data,
    pl_reg_ack,

    target_mem_map,
    target_rom_map,
    cfg_phy_control,
    cfg_l0s_entr_latency_timer,
    cfg_upd_aspm_ctrl,
    cfg_l1_entr_latency_timer,
    cfg_l1_entr_wo_rl0s,
    cfg_filter_rule_mask,
    cfg_fc_wdog_disable,
    cfg_lpvc_wrr_weight,
    cfg_max_func_num,
    cfg_fc_credit_ph,
    cfg_fc_credit_nph,
    cfg_fc_credit_cplh,
    cfg_fc_credit_pd,
    cfg_fc_credit_npd,
    cfg_fc_credit_cpld,
    cfg_radm_q_mode,
    cfg_radm_order_rule,
    cfg_order_rule_ctrl,
    cfg_clock_gating_ctrl,
    cfg_trgt_cpl_lut_delete_entry,
    cfg_radm_strict_vc_prior,
    cfg_hq_depths,
    cfg_dq_depths,
    cfg_pipe_garbage_data_mode,
    dbi_ro_wr_en,
    default_target,
    cfg_cfg_tlp_bypass_en,
    cfg_config_limit,
    cfg_target_above_config_limit,
    cfg_p2p_track_cpl_to,
    cfg_p2p_err_rpt_ctrl,
    ur_ca_mask_4_trgt1

    ,
    cfg_nond0_vdm_block,
    cfg_client0_block_new_tlp,
    cfg_client1_block_new_tlp,
    cfg_client2_block_new_tlp
    ,
    pm_powerdown_status,
    cfg_force_powerdown
);
parameter INST               = 0;                        // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM           = 0;                        // uniquifying parameter per function
parameter NL                 = `CX_NL;
parameter NLM1               = `CX_NL_M_1;               // `CX_NL - 1
parameter TXNL               = `CM_TXNL;                 // Tx Lane Width for M-PCIe
parameter RXNL               = `CM_RXNL;                 // Rx Lane Width for M-PCIe
parameter NB                 = `CX_NB;
parameter NW                 = `CX_NW;
parameter NVC                = `CX_NVC;
parameter NF                 = `CX_NFUNC;                // Number of functions
parameter PF_WD              = `CX_NFUNC_WD;             // Width of physical function number
parameter TP                 = `TP;                      // Clock to Q delay (simulator insurance)
parameter N_FLT_MASK         = `CX_N_FLT_MASK;
parameter RADM_SBUF_HDRQ_PW  = `CX_RADM_SBUF_HDRQ_PW;
parameter RADM_SBUF_DATAQ_PW = `CX_RADM_SBUF_DATAQ_PW;
parameter FREQ               = `CX_FREQ;


localparam GM_NW             = (`CC_MSTR_BUS_DATA_WIDTH > `CC_CORE_DATA_BUS_WD) ? `CC_MSTR_NW : `CX_NW;
localparam ATTR_WD = `FLT_Q_ATTR_WIDTH;


parameter GEN4MODE = `CX_GEN4_MODE;
localparam SIMPLIFIED_REPLAY_TIMER_GEN4 = (GEN4MODE == 2) ? 1'b0 : 1'b1;
localparam P2P_ENABLE = (`CX_P2P_ENABLE_VALUE == 1) ? 1'b1 : 1'b0;

localparam TAG_SIZE = `CX_TAG_SIZE;




parameter HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
parameter DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;

localparam DEFAULT_PHY_PERST_ON_WARM_RESET = `DEFAULT_PHY_PERST_ON_WARM_RESET;
parameter PWDN_WIDTH = `CX_PHY_PDOWN_WD;
localparam PHY_RST_TIMER = `CX_PHY_RST_TIMER;
localparam PMA_PIPE_RST_DELAY_TIMER = `CX_PMA_PIPE_RST_DELAY_TIMER;

// ----- Inputs ---------------
input [(2*PWDN_WIDTH) - 1 : 0]      pm_powerdown_status;
wire                                int_force_powerdown;
wire                                int_vmain_ack_ctrl_en;
output reg                          cfg_force_powerdown;
wire  [(2*PWDN_WIDTH + 4) - 1 : 0]  int_powerdown_status;
reg                                 cfg_vmain_ack_ctrl;

input                   core_clk;
input                   non_sticky_rst_n;
input                   sticky_rst_n;
input                   phy_type;                   // Phy Type

input                   app_dbi_ro_wr_disable;      // Set dbi_ro_wr_en to 0, disable write to DBI_RO_WR_EN bit
input   [11:0]          lbc_cdm_addr;               // Address of resource being accessed
input   [31:0]          lbc_cdm_data;               // Data for write
input                   pl_reg_sel;                 // bus strobe (indicates an active bus cycle)
input   [3:0]           lbc_cdm_wr;                 // Write select: 1 = write, 0 = read
input                   lbc_cdm_dbi;                // Indicates that the CDM is acccessed from dbi
input                   upstream_port;              // Upstream Port
input   [31:0]          phy_cfg_status;             // status from PHY, mapping differently for different PHY
input   [63:0]          cxpl_debug_info;            // status that should be useful for debug/brinqup activities

input   [5:0]           smlh_autoneg_link_width;    // Operating link width
input   [2:0]           cfg_max_payload_size;       // Largest of Max Payload Size from Device Control register
input   [2:0]           cfg_min_payload_size;       // Smallest of Max Payload Size from Device Control register
input                   cfg_comm_clk_config;        // common clock configuration
input   [HCRD_WD-1:0]   xtlh_xadm_ph_cdts;          // header for P credits
input   [DCRD_WD-1:0]   xtlh_xadm_pd_cdts;          // data for P credits
input   [HCRD_WD-1:0]   xtlh_xadm_nph_cdts;         // header for NPR credits
input   [DCRD_WD-1:0]   xtlh_xadm_npd_cdts;         // data for NPR credits
input   [HCRD_WD-1:0]   xtlh_xadm_cplh_cdts;        // header for cPL credits
input   [DCRD_WD-1:0]   xtlh_xadm_cpld_cdts;        // data for cPL credits
input                   radm_qoverflow;             // RADM Queue overflow flag
input                   radm_q_not_empty;           // RADM Queue not empty
input                   xdlh_retrybuf_not_empty;    // Retry buffer not empty
input                   rtlh_crd_not_rtn;           // Credit not returned

input                   smlh_dir_linkw_chg_rising_edge;   // clear cfg_directed_link_width_change
input   [2:0]           current_data_rate;          // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4
input                  cfg_ext_synch;                     // Extended Synch

input   [4:0]           app_dev_num; // DEV# from application                
input   [7:0]           app_bus_num; // BUS# from application                

// ----- Outputs ---------------
output [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control; // Multi Lane Control Register
output                               cfg_pl_l1_nowait_p1;
output                               cfg_pl_l1_clk_sel; // Port Logic bit to allow to disable core_clk gating in L1
output                               cfg_phy_perst_on_warm_reset; // PMC will drive pm_req_phy_perst during warm reset
output [17:0]                        cfg_phy_rst_timer;        // PHY rst timer.
output [5:0]                         cfg_pma_phy_rst_delay_timer;  // Delay between PMA reset and PIPE rst timer.
output [`CX_PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;
output  [8:0]           cfg_lane_en;                // Number of lanes (1-256)
output                  cfg_gen1_ei_inference_mode; // EI inference mode for Gen1. default 0 - using rxelecidle==1; 1 - using rxvalid==0
output  [1:0]           cfg_select_deemph_mux_bus;  // sel deemphasis {bit, var}
output  [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl;           // lane under test + gen5
output  [6:0]           cfg_rxstandby_control;      // Rxstandby Control
output  [7:0]           cfg_ack_freq;               // ACK frequency
output  [15:0]          cfg_ack_latency_timer;      // ACK Latency timer
output  [16:0]          cfg_replay_timer_value;     // Replay Timer value
output  [12:0]          cfg_fc_latency_value;       // fc latency Timer value
output  [31:0]          cfg_other_msg_payload;      // Other MSG payload
output                  cfg_other_msg_request;      // Other MSG request
output  [31:0]          cfg_corrupt_crc_pattern;    // CRC Corruption pattern
output  [5:0]           cfg_link_capable;           // Link capable
output                  cfg_scramble_dis;           // Scramble disable
output  [7:0]           cfg_n_fts;                  // NFTS #
output                  cfg_xmt_beacon;             // Transmit beacon
output                  cfg_tx_reverse_lanes;       // Reverse lanes
output                  cfg_link_dis;               // Link disable
output                  cfg_lpbk_en;                // Loopback enable
output                  cfg_elastic_buffer_mode;    // 0 - nominal half full mode, 1 - nominal empty mode
output                  cfg_pipe_loopback;          // Local Loopback Enable
output  [5:0]           cfg_rxstatus_lane;          // Lane to inject rxstatus value(bit6 = all lanes)
output  [2:0]           cfg_rxstatus_value;         // rxstatus value to inject
output  [NL-1:0]        cfg_lpbk_rxvalid;           // rxvalid value to use during loopback
output  [7:0]           cfg_link_num;               // Link number
output                  cfg_ts2_lid_deskew;         // do deskew using ts2->Logic_Idle_Data transition
output                  cfg_support_part_lanes_rxei_exit; // Polling.Active -> Polling.Config based on part of pre lanes rxei exit
output                  cfg_plreg_reset;
output  [5:0]           cfg_forced_link_state;      // a 4 bits register to move the link state to this value indicated
output  [3:0]           cfg_forced_ltssm_cmd;      // a 4 bits register to issue LTSSM cmd

output                  cfg_force_en;               // force enable has to be a pulse signal generated from cfg block. When software writes
                                                    // to this register, a pulse will be generated to force the link
                                                    // synchronization state machine move from its current state to the
                                                    // cfg_forced_link_state
output  [23:0]          cfg_lane_skew;              // (PL) Transmit lane skew control (optional) for test equipment
output                  cfg_deskew_disable;         // Disable lane deskew logic on receive
output                  cfg_flow_control_disable;   // this bit disable the automatic flowcontrol built in this core
output                  cfg_acknack_disable;        // this bit disable the automatic acknack built in this core
output  [3:0]           cfg_imp_num_lanes;          // implementation-specific set of lanes
output  [31:0]          pl_reg_data;                // Read data back from core
output                  pl_reg_ack;                 // Acknowledge back from core. Indicates completion, read data is valid
output                  cfg_dll_lnk_en;             // When = 0, keep DLL layer in inactive state
output  [3:0]           cfg_eidle_timer;            // eidle timer
output  [10:0]          cfg_skip_interval;          // skip interval
output  [3:0]           cfg_link_rate;              // link data rate
output                  cfg_fast_link_mode;         // fast link mode
output  [1:0]           cfg_fast_link_scaling_factor; // fast link timer scaling factor
output    [(6*NF)-1:0]  target_mem_map;             // Each bit of this vector indicates which target receives memory transactions for that bar #
output    [NF-1:0]      target_rom_map;             // Each bit of this vector indicates which target receives rom    transactions for that bar #
output  [31:0]          cfg_phy_control;            // control signals to PHY, mapping differently for different PHY
output  [2:0]           cfg_l0s_entr_latency_timer; // L0s entrance latency timer
output                  cfg_upd_aspm_ctrl;          // Used to update the shadowed ASPM control register in pm_ctrl
output  [2:0]           cfg_l1_entr_latency_timer;  // L1 entrance latency timer
output                  cfg_l1_entr_wo_rl0s;        // Start L1 timer without rL0s
output  [N_FLT_MASK-1:0]cfg_filter_rule_mask;       // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
output                  cfg_fc_wdog_disable;        // Disable watch dog timer in flow control for some debug purpose
output  [63:0]          cfg_lpvc_wrr_weight;        // WRR weighing per VC ID (8 bits per VC)
output  [PF_WD   -1:0]  cfg_max_func_num;           // Highest accepted function number
output  [(NVC*8)-1:0]   cfg_fc_credit_ph;           // Flow Control credits - Posted Header
output  [(NVC*8)-1:0]   cfg_fc_credit_nph;          // Flow Control credits - Non-Posted Header
output  [(NVC*8)-1:0]   cfg_fc_credit_cplh;         // Flow Control credits - Completion Header
output  [(NVC*12)-1:0]  cfg_fc_credit_pd;           // Flow Control credits - Posted Data
output  [(NVC*12)-1:0]  cfg_fc_credit_npd;          // Flow Control credits - Non-Posted Data
output  [(NVC*12)-1:0]  cfg_fc_credit_cpld;         // Flow Control credits - Completion Data
output  [(NVC*9)-1:0]   cfg_radm_q_mode;            // Queue Mode: CPL(BP/CT/SF), NP(BP/CT/SF), P(BP/CT/SF)
output  [NVC-1:0]       cfg_radm_order_rule;        // Order Selection: 0 - Strict Priority, 1 - Complies with Ordering Rule
output  [15:0]          cfg_order_rule_ctrl;        // cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC
output  [1:0]           cfg_clock_gating_ctrl;      // Enable/Disable clock gating feature

output  [31:0]          cfg_trgt_cpl_lut_delete_entry;  // trgt_cpl_lut delete one entry 
output                  cfg_radm_strict_vc_prior;   // VC Priority: 0 - Round Robin, 1 - Strict Priority
output  [(NVC*3*RADM_SBUF_HDRQ_PW)-1:0]     cfg_hq_depths;  // Indicates the depth of the header queues per type per vc
output  [(NVC*3*RADM_SBUF_DATAQ_PW)-1:0]    cfg_dq_depths;  // Indicates the depth of the data queues per type per vc


output                                          cfg_pipe_garbage_data_mode;
output                                          dbi_ro_wr_en;
output                                          default_target;
output                                          ur_ca_mask_4_trgt1;
output                                          cfg_cfg_tlp_bypass_en;
output [9:0]                                    cfg_config_limit;
output [1:0]                                    cfg_target_above_config_limit;
output                                          cfg_p2p_track_cpl_to;
output                                          cfg_p2p_err_rpt_ctrl;



localparam            ARI_DEVICE_NUM = 1'b0;




output                                            cfg_nond0_vdm_block;
output                                            cfg_client0_block_new_tlp;
output                                            cfg_client1_block_new_tlp;
output                                            cfg_client2_block_new_tlp;


// =============================================================================
// Output registers
// =============================================================================

wire                    cfg_pl_l1_nowait_p1;
wire                    cfg_pl_l1_clk_sel;
wire                    cfg_phy_perst_on_warm_reset;
reg                     cfg_upd_aspm_ctrl;
reg     [31:0]          pl_reg_data;
reg                     pl_reg_ack;
wire                    int_upd_aspm_ctrl;
wire    [7:0]           pl_reg_3,  pl_reg_2,  pl_reg_1,  pl_reg_0;
reg     [7:0]           pl_reg_7,  pl_reg_6,  pl_reg_5,  pl_reg_4;
reg     [7:0]           pl_reg_11, pl_reg_10, pl_reg_9,  pl_reg_8;
reg     [7:0]           pl_reg_15, pl_reg_14, pl_reg_13, pl_reg_12;
reg     [7:0]           pl_reg_19, pl_reg_18, pl_reg_17, pl_reg_16;
reg     [7:0]           pl_reg_23, pl_reg_22, pl_reg_21, pl_reg_20;
reg     [7:0]           pl_reg_27, pl_reg_26, pl_reg_25, pl_reg_24;
reg     [7:0]           pl_reg_31, pl_reg_30, pl_reg_29, pl_reg_28;
reg     [7:0]           pl_reg_35, pl_reg_34, pl_reg_33, pl_reg_32;
wire    [7:0]           pl_reg_39, pl_reg_38, pl_reg_37;
reg     [7:0]           pl_reg_36;
reg     [7:0]           pl_reg_43, pl_reg_42, pl_reg_41, pl_reg_40;
reg     [7:0]           pl_reg_47, pl_reg_46, pl_reg_45, pl_reg_44;
wire    [7:0]           pl_reg_51, pl_reg_50, pl_reg_49, pl_reg_48;
wire    [7:0]           pl_reg_55, pl_reg_54, pl_reg_53, pl_reg_52;
wire    [7:0]           pl_reg_59, pl_reg_58, pl_reg_57, pl_reg_56;
wire    [7:0]           pl_reg_61, pl_reg_60;
reg     [7:0]           pl_reg_63, pl_reg_62;
reg     [7:0]           pl_reg_67, pl_reg_66, pl_reg_65, pl_reg_64;
reg     [7:0]           pl_reg_71, pl_reg_70, pl_reg_69, pl_reg_68;
reg     [7:0]           pl_reg_75, pl_reg_74, pl_reg_73, pl_reg_72;
reg     [7:0]           pl_reg_79, pl_reg_78, pl_reg_77, pl_reg_76;
reg     [7:0]           pl_reg_83, pl_reg_82, pl_reg_81, pl_reg_80;
reg     [7:0]           pl_reg_84, pl_reg_85, pl_reg_86, pl_reg_87;
reg     [7:0]           pl_reg_88, pl_reg_89, pl_reg_90, pl_reg_91;
reg     [7:0]           pl_reg_92, pl_reg_93, pl_reg_94, pl_reg_95;
reg     [7:0]           pl_reg_99, pl_reg_98, pl_reg_97, pl_reg_96;
reg     [7:0]           pl_reg_103, pl_reg_102, pl_reg_101, pl_reg_100;
reg     [7:0]           pl_reg_107, pl_reg_106, pl_reg_105, pl_reg_104;
reg     [7:0]           pl_reg_111, pl_reg_110, pl_reg_109, pl_reg_108;
reg     [7:0]           pl_reg_115, pl_reg_114, pl_reg_113, pl_reg_112;
reg     [7:0]           pl_reg_119, pl_reg_118, pl_reg_117, pl_reg_116;
reg     [7:0]           pl_reg_123, pl_reg_122, pl_reg_121, pl_reg_120;
reg     [7:0]           pl_reg_127, pl_reg_126, pl_reg_125, pl_reg_124;
reg     [7:0]           pl_reg_131, pl_reg_130, pl_reg_129, pl_reg_128;
reg     [7:0]           pl_reg_135, pl_reg_134, pl_reg_133, pl_reg_132;
reg     [7:0]           pl_reg_139, pl_reg_138, pl_reg_137, pl_reg_136;
reg     [7:0]           pl_reg_143, pl_reg_142, pl_reg_141, pl_reg_140;
reg     [7:0]           pl_reg_147, pl_reg_146, pl_reg_145, pl_reg_144;
reg     [7:0]           pl_reg_151, pl_reg_150, pl_reg_149, pl_reg_148;
reg     [7:0]           pl_reg_155, pl_reg_154, pl_reg_153, pl_reg_152;
reg     [7:0]           pl_reg_159, pl_reg_158, pl_reg_157, pl_reg_156;
reg     [7:0]           pl_reg_163, pl_reg_162, pl_reg_161, pl_reg_160;
reg     [7:0]           pl_reg_167, pl_reg_166, pl_reg_165, pl_reg_164;
reg     [7:0]           pl_reg_175, pl_reg_174, pl_reg_173, pl_reg_172;
wire    [7:0]           pl_reg_179, pl_reg_178, pl_reg_177, pl_reg_176;
reg     [7:0]           pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180;
reg     [7:0]           pl_reg_203, pl_reg_202, pl_reg_201, pl_reg_200;
reg     [7:0]           pl_reg_246, pl_reg_245, pl_reg_205, pl_reg_204;
reg     [7:0]           pl_reg_mult_0;
reg     [7:0]           pl_reg_phyiop_3, pl_reg_phyiop_2, pl_reg_phyiop_1, pl_reg_phyiop_0;
reg     [7:0]           pl_reg_phyiop_ctrl2_3, pl_reg_phyiop_ctrl2_2, pl_reg_phyiop_ctrl2_1, pl_reg_phyiop_ctrl2_0;



wire      [0:0]         trgt_map_reg_id;        // Target Map address decode
wire      [31:0]        trgt_map_reg_data;      // Target Map read data
wire      [(6*NF)-1:0]  target_mem_map;
wire      [NF-1:0]      target_rom_map;



reg     [15:0]          int_ack_latency_timer;
reg     [15:0]          int2_ack_latency_timer;
reg     [16:0]          int_replay_timer_value;
reg     [16:0]          int2_replay_timer_value;
wire    [5:0]           cfg_forced_link_state;
wire                    cfg_ts2_lid_deskew;
wire                    cfg_support_part_lanes_rxei_exit;
wire    [3:0]           cfg_forced_ltssm_cmd;

reg                     cfg_force_en;
wire                    cfg_other_msg_request;
wire    [23:0]          cfg_lane_skew;              // (PL) Transmit lane skew control (optional) for test equipment
wire                    cfg_acknack_disable;
wire    [3:0]           cfg_imp_num_lanes;
wire                    cfg_dll_lnk_en;
wire    [3:0]           cfg_eidle_timer;
wire    [10:0]          cfg_skip_interval;
wire    [3:0]           cfg_link_rate;
wire   [12:0]           fc_timer_override_val;
wire                    fc_timer_override;
wire    [6:0]           int_replay_timer_add;
wire    [4:0]           replay_timer_add;
wire    [4:0]           replay_timer_add_int;
wire    [4:0]           replay_timer_add_mpcie;
wire    [4:0]           acknak_timer_add;
wire                    cfg_fast_link_mode;
wire    [1:0]           cfg_fast_link_scaling_factor;
wire                    cfg_xmt_corrupt_crc;
reg                     read_pulse;
wire                    aux_clk_reg_id;   //L1SUB register space decode
wire    [31:0]          aux_clk_reg_data; //L1SUB read data



reg  [(NVC*2)-1:0]   hdr_scale_p;              // The HdrScale field contains the scaling factor for headers of the indicated type
reg  [(NVC*2)-1:0]   data_scale_p;             // The DataScale field contains the scaling factor for payload data of the indicated type
reg  [(NVC*2)-1:0]   hdr_scale_np;             // The HdrScale field contains the scaling factor for headers of the indicated type
reg  [(NVC*2)-1:0]   data_scale_np;            // The DataScale field contains the scaling factor for payload data of the indicated type
reg  [(NVC*2)-1:0]   hdr_scale_cpl;            // The HdrScale field contains the scaling factor for headers of the indicated type
reg  [(NVC*2)-1:0]   data_scale_cpl;           // The DataScale field contains the scaling factor for payload data of the indicated type

wire    [31:0]          pl_reg_0x490;      // PIPE Related Register read data 0x490
wire    [7:0]           pl_reg_0x41C;      // VDM Traffic during non-D0 states


reg     [7:0]           pl_reg_240, pl_reg_239;
reg     [7:0]           pl_reg_244, pl_reg_243, pl_reg_242, pl_reg_241;
//  cfg_clock_gating_ctrl
reg                     r_radm_clk_gating_en; 

reg [15:0]              app_bus_dev_num_status; // Application Bus and Device Number Status
wire                    cfg_pl_wr_disable;


// =============================================================================
// Internal IP Core Registers
// =============================================================================
localparam ID_0x480 = 158;
localparam ID_0x484 = 159;
localparam ID_0x500 = 160;
localparam ID_0x470 = 164;
localparam ID_0x474 = 165;
localparam ID_0x490 = 166;
localparam ID_0x260 = 167;
localparam ID_0x264 = 168;
// Number of register locations consumed by the DTIM
localparam DTIM_REG_RANGE = 20;
// DTIM register address offsets
localparam ID_0x3B0 = 169; // DTIM CTRL0
localparam ID_0x3B4 = 170; // DTIM CTRL1
localparam ID_0x3B8 = 171; // DTIM CTRL2
localparam ID_0x3BC = 172; // DTIM CTRL3
localparam ID_0x3C0 = 173; // DTIM CTRL4
localparam ID_0x3C4 = 174; // DTIM CTRL5
localparam ID_0x3C8 = 175; // Reserved
localparam ID_0x3CC = 176; // DTIM INT_STATUS
localparam ID_0x3D0 = 177; // DTIM INT_EN
localparam ID_0x3D4 = 178; // DTIM INT_CLR
localparam ID_0x3D8 = 179; // DTIM INT_MSK
localparam ID_0x3DC = 180; // DTIM MSI_ADDR_UPR
localparam ID_0x3E0 = 181; // DTIM MSI_ADDR_LWR
localparam ID_0x3E4 = 182; // DTIM MSI_DATA
localparam ID_0x3E8 = 183; // DTIM ERR_LOG0
localparam ID_0x3EC = 184; // DTIM ERR_LOG1
localparam ID_0x3F0 = 185; // DTIM ERR_LOG2
localparam ID_0x3F4 = 186; // DTIM RSVD
localparam ID_0x3F8 = 187; // DTIM RSVD
localparam ID_0x3FC = 188; // DTIM DIAG
localparam ID_0x520 = 189; // CCIX VDM VID
localparam ID_0x448 = 190; // POWERDOWN_CTRL_STATUS
localparam ID_0x44C = 114; // PHY_INTEROP_CTRL_2
localparam ID_0x410 = 191; // APP_BUS_DEV_NUM_STATUS
localparam ID_0x41C = 192; // non-D0 VDM
localparam ID_0x524 = 193; // FOM_COEF_LENGTH
localparam ID_0x528 = 194; // FOM_COEF_LANE0_1
localparam ID_0x52C = 195; // FOM_COEF_LANE2_3
localparam ID_0x530 = 196; // FOM_COEF_LANE4_5
localparam ID_0x534 = 197; // FOM_COEF_LANE6_7
localparam ID_0x538 = 198; // FOM_COEF_LANE8_9
localparam ID_0x53C = 199; // FOM_COEF_LANE10_11
localparam ID_0x540 = 200; // FOM_COEF_LANE12_13
localparam ID_0x544 = 201; // FOM_COEF_LANE14_15
localparam ID_0x548 = 202; // CXL : CXL_LL_CREDIT_CR
localparam ID_0x54C = 203; // CXL : CXL_LRSM_CSR
localparam ID_0x550 = 204; // CXL : CXL_LL_TIMER_CR
localparam ID_0x554 = 205; // CXL : CXL_FATAL_ERROR_CR
localparam ID_0x558 = 206; // CXL : CXL_CACHE_MEM_LL_EI
localparam ID_0x55C = 207; // CXL : CXL_IO_LL_EI
localparam ID_0x560 = 208; // CXL : CXL_FB_LOGPHY_EI
localparam ID_0x564 = 209; // CXL : CXL_VIRAL_LDID
// SBSA ECAM Adress registers - offsets
localparam ID_0x570 = 210; // ECAM lower base address
localparam ID_0x574 = 211; // ECAM upper base address
localparam ID_0x578 = 212; // ECAM control
localparam MAX_ID   = 213;
localparam POWERDOWN_CTRL_STATUS_OFF    = 12'h448;
localparam [11:0] PHY_INTEROP_CTRL_2_OFF= 12'h44C;
localparam PL_APP_BUS_DEV_NUM_STATUS_OFF= 12'h410;



reg     [MAX_ID-1:0]    int_pl_reg_id;
wire    [MAX_ID-1:0]    pl_reg_id;
reg pl_reg_sel_d;

assign pl_reg_id    = int_pl_reg_id;


assign trgt_map_reg_id = {int_pl_reg_id[71]};
assign aux_clk_reg_id = int_pl_reg_id[141]; // L1SUB register decode

// int_pl_reg_id register enable logic
wire  int_pl_reg_id_en;
assign int_pl_reg_id_en = pl_reg_sel | pl_reg_sel_d;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n)
        int_pl_reg_id    <= #TP 0;
    else begin
        int_pl_reg_id[0] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h000) >> 2))) : int_pl_reg_id[0];
        int_pl_reg_id[1] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h004) >> 2))) : int_pl_reg_id[1];
        int_pl_reg_id[2] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h008) >> 2))) : int_pl_reg_id[2];
        int_pl_reg_id[3] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h00C) >> 2))) : int_pl_reg_id[3];
        int_pl_reg_id[4] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h010) >> 2))) : int_pl_reg_id[4];
        int_pl_reg_id[5] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h014) >> 2))) : int_pl_reg_id[5];
        int_pl_reg_id[6] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h018) >> 2))) : int_pl_reg_id[6];
        int_pl_reg_id[7] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h01C) >> 2))) : int_pl_reg_id[7];
        int_pl_reg_id[8] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h020) >> 2))) : int_pl_reg_id[8];
        int_pl_reg_id[9] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h024) >> 2))) : int_pl_reg_id[9];
        int_pl_reg_id[10]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h028) >> 2))) : int_pl_reg_id[10];
        int_pl_reg_id[11]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h02C) >> 2))) : int_pl_reg_id[11];
        int_pl_reg_id[12]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h030) >> 2))) : int_pl_reg_id[12];
        int_pl_reg_id[13]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h034) >> 2))) : int_pl_reg_id[13];
        int_pl_reg_id[14]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h038) >> 2))) : int_pl_reg_id[14];
        int_pl_reg_id[15]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h03C) >> 2))) : int_pl_reg_id[15];
        int_pl_reg_id[16]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h040) >> 2))) : int_pl_reg_id[16];
        int_pl_reg_id[17]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h044) >> 2))) : int_pl_reg_id[17];
        int_pl_reg_id[18]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h048) >> 2))) : int_pl_reg_id[18];
        int_pl_reg_id[19]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h04C) >> 2))) : int_pl_reg_id[19];
        int_pl_reg_id[20]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h050) >> 2))) : int_pl_reg_id[20];
        int_pl_reg_id[23:21]<= #TP 3'd0;
        int_pl_reg_id[26:24]<= #TP 3'd0;
        int_pl_reg_id[29:27]<= #TP 3'd0;
        int_pl_reg_id[32:30]<= #TP 3'd0;
        int_pl_reg_id[35:33]<= #TP 3'd0;
        int_pl_reg_id[38:36]<= #TP 3'd0;
        int_pl_reg_id[41:39]<= #TP 3'd0;
        int_pl_reg_id[42]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h0A8) >> 2))) : int_pl_reg_id[42];
        int_pl_reg_id[43]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h0AC) >> 2))) : int_pl_reg_id[43];
        int_pl_reg_id[44]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h0B0) >> 2))) : int_pl_reg_id[44];
        int_pl_reg_id[47:45]<= #TP 3'd0;
        int_pl_reg_id[50:48]<= #TP 3'd0;
        int_pl_reg_id[53:51]<= #TP 3'd0;
        int_pl_reg_id[56:54]<= #TP 3'd0;
        int_pl_reg_id[59:57]<= #TP 3'd0;
        int_pl_reg_id[62:60]<= #TP 3'd0;
        int_pl_reg_id[65:63]<= #TP 3'd0;
        int_pl_reg_id[66]<= #TP 1'b0;
        int_pl_reg_id[67]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h10C) >> 2))) : int_pl_reg_id[67];
        int_pl_reg_id[68]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h110) >> 2))) : int_pl_reg_id[68];
        int_pl_reg_id[69]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h114) >> 2))) : int_pl_reg_id[69];
        int_pl_reg_id[70]<= #TP 1'd0;
        int_pl_reg_id[71]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h11C) >> 2)) ) : int_pl_reg_id[71];
        int_pl_reg_id[98:72]<= #TP 27'd0;
        int_pl_reg_id[99]<= #TP 0; // unused addresses
        int_pl_reg_id[100]<= #TP 1'b0;
        int_pl_reg_id[103:101]<= #TP 4'd0;
        int_pl_reg_id[105]<= #TP 4'd0;
        int_pl_reg_id[104]<= #TP 1'b0;
        // int_pl_reg_id[105] is assigned above for ifdef CX_GEN3_EQ_PSET_COEF_MAP_MODE_PROG
        int_pl_reg_id[106]<= #TP 1'b0;
        int_pl_reg_id[107]<= #TP 1'b0;
        int_pl_reg_id[108] <= #TP 0; // unused addresses

    int_pl_reg_id[109] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1b4) >> 2))) : int_pl_reg_id[109];

    int_pl_reg_id[110]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1b8) >> 2))) : int_pl_reg_id[110];
    int_pl_reg_id[111]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1bc) >> 2))) : int_pl_reg_id[111];
    int_pl_reg_id[112]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1c0) >> 2))) : int_pl_reg_id[112];
    int_pl_reg_id[113]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1c4) >> 2))) : int_pl_reg_id[113];
    int_pl_reg_id[ID_0x44C]<= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + PHY_INTEROP_CTRL_2_OFF) >> 2))) : int_pl_reg_id[ID_0x44C];
        int_pl_reg_id[115]     <= #TP 0; // unused address
        int_pl_reg_id[117]     <= #TP 0; // unused address
        // AMBA Error Response
        int_pl_reg_id[116] <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1d0) >> 2))) : int_pl_reg_id[116];
        int_pl_reg_id[118] <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1d8) >> 2))) : int_pl_reg_id[118];
        int_pl_reg_id[119] <= #TP 0;  // unused address
        int_pl_reg_id[121:120] <= #TP 0; // unused addresses
        int_pl_reg_id[122]     <= #TP 0; // unused addresses
        int_pl_reg_id[124]     <= #TP 0; // unused addresses
        int_pl_reg_id[125]     <= #TP 0; // unused addresses
        int_pl_reg_id[123]     <= #TP 0; // unused addresses
        int_pl_reg_id[126] <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1f8) >> 2)) ) : int_pl_reg_id[126];
        int_pl_reg_id[127] <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1fc) >> 2)) ) : int_pl_reg_id[127];
        int_pl_reg_id[136:128]<= #TP 9'd0;

        int_pl_reg_id[140:137]<= #TP 4'd0;
        int_pl_reg_id[141]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h440) >> 2))) : int_pl_reg_id[141];
        int_pl_reg_id[142]<= #TP 1'b0;
        int_pl_reg_id[147:143]<= #TP 5'd0;
        int_pl_reg_id[150:148]<= #TP 3'd0;
        int_pl_reg_id[151] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1c8) >> 2))) : int_pl_reg_id[151];
        int_pl_reg_id[152] <= #TP 1'd0;

        int_pl_reg_id[153] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h18c) >> 2))) : int_pl_reg_id[153];
        int_pl_reg_id[157:154] <= #TP 4'b0; 
        int_pl_reg_id[ID_0x484:ID_0x480]<= #TP 2'b00;
        int_pl_reg_id[ID_0x490]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h490) >> 2))) : int_pl_reg_id[ID_0x490];
        int_pl_reg_id[ID_0x500] <= #TP 1'b0; 
        int_pl_reg_id[163:161] <= #TP 3'b000;
        int_pl_reg_id[ID_0x474:ID_0x470]<= #TP 2'b00;
        int_pl_reg_id[ID_0x264:ID_0x260] <= #TP 2'b00;
        int_pl_reg_id[ID_0x520]<= #TP 1'b0;
        int_pl_reg_id[ID_0x544:ID_0x524]<= #TP {9{1'b0}};
        int_pl_reg_id[ID_0x41C]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h41C) >> 2))) : int_pl_reg_id[ID_0x41C];
        int_pl_reg_id[ID_0x3FC:ID_0x3B0] <= #TP {DTIM_REG_RANGE{1'b0}};
        int_pl_reg_id[ID_0x448] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + POWERDOWN_CTRL_STATUS_OFF) >> 2)))
                                                        : int_pl_reg_id[ID_0x448];
        int_pl_reg_id[ID_0x410] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + PL_APP_BUS_DEV_NUM_STATUS_OFF) >> 2)))
                                                        : int_pl_reg_id[ID_0x410];                                                         
     int_pl_reg_id[201:193] <= #TP '0;
        int_pl_reg_id[ID_0x548]<= #TP 1'b0;
        int_pl_reg_id[ID_0x54C]<= #TP 1'b0;
        int_pl_reg_id[ID_0x550]<= #TP 1'b0;
        int_pl_reg_id[ID_0x554]<= #TP 1'b0;
        int_pl_reg_id[ID_0x558]<= #TP 1'b0;
        int_pl_reg_id[ID_0x55C]<= #TP 1'b0;
        int_pl_reg_id[ID_0x560]<= #TP 1'b0;
        int_pl_reg_id[ID_0x564]<= #TP 1'b0;
        int_pl_reg_id[ID_0x570]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x574]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x578]  <= #TP 1'b0;
    end
end

// =============================================================================
// Core Register Read Operation
// =============================================================================

// Register muxed data back to host
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        pl_reg_data <= #TP 32'b0;
    else
        if (read_pulse) begin


            unique case (1'b1)

                pl_reg_id[0]: pl_reg_data   <= #TP {pl_reg_3,  pl_reg_2,  pl_reg_1,  pl_reg_0};
                pl_reg_id[1]: pl_reg_data   <= #TP {pl_reg_7,  pl_reg_6,  pl_reg_5,  pl_reg_4};
                pl_reg_id[2]: pl_reg_data   <= #TP {pl_reg_11, pl_reg_10, pl_reg_9,  pl_reg_8};
                pl_reg_id[3]: pl_reg_data   <= #TP {pl_reg_15, pl_reg_14, pl_reg_13, pl_reg_12};
                pl_reg_id[4]: pl_reg_data   <= #TP {pl_reg_19, pl_reg_18, pl_reg_17, pl_reg_16};
                pl_reg_id[5]: pl_reg_data   <= #TP {pl_reg_23, pl_reg_22, pl_reg_21, pl_reg_20};
                pl_reg_id[6]: pl_reg_data   <= #TP {pl_reg_27, pl_reg_26, pl_reg_25, pl_reg_24};
                pl_reg_id[7]: pl_reg_data   <= #TP {pl_reg_31, pl_reg_30, pl_reg_29, pl_reg_28};
                pl_reg_id[8]: pl_reg_data   <= #TP {pl_reg_35, pl_reg_34, pl_reg_33, pl_reg_32};
                pl_reg_id[9]: pl_reg_data   <= #TP {pl_reg_39, pl_reg_38, pl_reg_37, pl_reg_36};
//Do not cover the debug registers

                pl_reg_id[10]: pl_reg_data  <= #TP {pl_reg_43, pl_reg_42, pl_reg_41, pl_reg_40};
                pl_reg_id[11]: pl_reg_data  <= #TP {pl_reg_47, pl_reg_46, pl_reg_45, pl_reg_44};
                pl_reg_id[12]: pl_reg_data  <= #TP {pl_reg_51, pl_reg_50, pl_reg_49, pl_reg_48};
                pl_reg_id[13]: pl_reg_data  <= #TP {pl_reg_55, pl_reg_54, pl_reg_53, pl_reg_52};
                pl_reg_id[14]: pl_reg_data  <= #TP {pl_reg_59, pl_reg_58, pl_reg_57, pl_reg_56};
                pl_reg_id[15]: pl_reg_data  <= #TP {pl_reg_63, pl_reg_62, pl_reg_61, pl_reg_60};
                pl_reg_id[16]: pl_reg_data  <= #TP {pl_reg_67, pl_reg_66, pl_reg_65, pl_reg_64};
                pl_reg_id[17]: pl_reg_data  <= #TP {pl_reg_71, pl_reg_70, pl_reg_69, pl_reg_68};
            // VC_0
                pl_reg_id[18]: pl_reg_data  <= #TP {pl_reg_75, pl_reg_74, pl_reg_73, pl_reg_72};
                pl_reg_id[19]: pl_reg_data  <= #TP {pl_reg_79, pl_reg_78, pl_reg_77, pl_reg_76};
                pl_reg_id[20]: pl_reg_data  <= #TP {pl_reg_83, pl_reg_82, pl_reg_81, pl_reg_80};
            // VC_0
                pl_reg_id[67]: pl_reg_data  <= #TP {pl_reg_175, pl_reg_174, pl_reg_173, pl_reg_172};
                pl_reg_id[68]: pl_reg_data  <= #TP {pl_reg_179, pl_reg_178, pl_reg_177, pl_reg_176};
                pl_reg_id[69]: pl_reg_data  <= #TP {pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180};
                pl_reg_id[109]: pl_reg_data <= #TP {16'h0, pl_reg_240, pl_reg_239};
                pl_reg_id[110]: pl_reg_data <= #TP {pl_reg_203, pl_reg_202, pl_reg_201, pl_reg_200};
                pl_reg_id[111]: pl_reg_data <= #TP {pl_reg_246, pl_reg_245, pl_reg_205, pl_reg_204};
                pl_reg_id[112]: pl_reg_data <= #TP {24'h0, pl_reg_mult_0};
                pl_reg_id[113]: pl_reg_data <= #TP {pl_reg_phyiop_3, pl_reg_phyiop_2, pl_reg_phyiop_1, pl_reg_phyiop_0};
                pl_reg_id[ID_0x44C]: pl_reg_data <= #TP {pl_reg_phyiop_ctrl2_3, pl_reg_phyiop_ctrl2_2, pl_reg_phyiop_ctrl2_1, pl_reg_phyiop_ctrl2_0};
               pl_reg_id[126]: pl_reg_data <= #TP `DWC_PCIE_IIP_RELEASE_VER_NUMBER;
               pl_reg_id[127]: pl_reg_data <= #TP `DWC_PCIE_IIP_RELEASE_VER_TYPE;
             |trgt_map_reg_id: pl_reg_data  <= #TP trgt_map_reg_data;

             aux_clk_reg_id: pl_reg_data     <= #TP aux_clk_reg_data;
             pl_reg_id[151]: pl_reg_data <= #TP {pl_reg_244, pl_reg_243, pl_reg_242, pl_reg_241};
             pl_reg_id[153]: pl_reg_data <= #TP {16'h0, 8'h0, 7'h0, r_radm_clk_gating_en};
             pl_reg_id[ID_0x490]: pl_reg_data <= #TP pl_reg_0x490;
             pl_reg_id[ID_0x41C]: pl_reg_data <= #TP {24'b0, pl_reg_0x41C};
             pl_reg_id[ID_0x448] : pl_reg_data <= #TP {20'b0, int_powerdown_status};
             pl_reg_id[ID_0x410] : pl_reg_data <= #TP {16'b0, app_bus_dev_num_status};



                default:  pl_reg_data   <= #TP `PCIE_UNUSED_RESPONSE;
            endcase
        end
end


// ack one cycle after lbus_strobe is asserted
// it could be delayed more in reality
reg     [3:0]   write_pulse;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        pl_reg_ack      <= #TP 0;
        pl_reg_sel_d    <= #TP 0;
        write_pulse     <= #TP 0;
        read_pulse      <= #TP 0;
    end else begin
        pl_reg_ack      <= #TP pl_reg_sel & pl_reg_sel_d;
        pl_reg_sel_d    <= #TP  pl_reg_sel;
        // generation of write pulse is gated by the cfg_pl_wr_disable signal which defaults to CX_PL_WIRE_WR_DISABLE parameter
        write_pulse     <= #TP (pl_reg_sel & ~pl_reg_sel_d) ? lbc_cdm_wr & {4{~cfg_pl_wr_disable|lbc_cdm_dbi}}: 4'b0;
        read_pulse      <= #TP  pl_reg_sel & ~pl_reg_sel_d & (~|lbc_cdm_wr);
    end
end

// =============================================================================
// Core Register Write Operation
// =============================================================================



//------------------------------------------------------------------------------
// Bus ack latency timer and replay timer register
// pl_reg_id        - 0
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_0 to pl_reg_3;
//
// These value are taken from table 3-4 and 3-5 of the PCIE 1.0a spec
// Simplified replay timer values added for Gen4-0.7
// -----------------------------------------------------------------------------
reg   [5:0]   smlh_autoneg_link_width_d, smlh_autoneg_link_width_d2;
reg   [2:0]   cfg_max_payload_size_d, cfg_max_payload_size_d2;
reg           ack_timer_update_en;
reg           replay_timer_update_en;
reg           simplified_replay_timer_en, simplified_replay_timer_en_d;
reg           cfg_ext_synch_d;

assign simplified_replay_timer_en = pl_reg_204[3];


// No replay adjust if Simplified Replay Timer
assign cfg_replay_timer_value = simplified_replay_timer_en ? {(int2_replay_timer_value[16:6]), int2_replay_timer_value[5:0]} 
                                                             : {(int2_replay_timer_value[16:6] + int_replay_timer_add), int2_replay_timer_value[5:0]};
assign cfg_ack_latency_timer  = {(int2_ack_latency_timer[15:6]  + acknak_timer_add), int2_ack_latency_timer[5:0]};

assign {pl_reg_1, pl_reg_0} = int_ack_latency_timer;
assign {pl_reg_3, pl_reg_2} = int_replay_timer_value[15:0];

assign int2_replay_timer_value = int_replay_timer_value;
assign int2_ack_latency_timer  = int_ack_latency_timer;

// max_payload size: 000=128, 001=256, 010=512, 011=1024, 100=2048, 101=4096
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        int_ack_latency_timer         <= #TP 16'd4143  / NB;
        int_replay_timer_value        <= #TP 17'd12429 / NB;
        smlh_autoneg_link_width_d     <= #TP 0;
        smlh_autoneg_link_width_d2    <= #TP 0;
        cfg_max_payload_size_d        <= #TP 0;
        cfg_max_payload_size_d2       <= #TP 0;
        simplified_replay_timer_en_d  <= #TP 0;
        cfg_ext_synch_d               <= #TP 0;
        ack_timer_update_en           <= #TP 0;
        replay_timer_update_en        <= #TP 0;
    end
    else begin

        smlh_autoneg_link_width_d     <= #TP smlh_autoneg_link_width;
        smlh_autoneg_link_width_d2    <= #TP smlh_autoneg_link_width_d;
        cfg_max_payload_size_d        <= #TP cfg_max_payload_size;
        cfg_max_payload_size_d2       <= #TP cfg_max_payload_size_d;
        simplified_replay_timer_en_d  <= #TP simplified_replay_timer_en;
        cfg_ext_synch_d               <= #TP cfg_ext_synch;
        

        // Automatically update the ACK Latency/Replay Timer if the link width/max MTU size values changed
        // Additionally update the Replay Timer if Simplified Replay Timer/Extended Synch values changed
        replay_timer_update_en      <= #TP  (smlh_autoneg_link_width_d != smlh_autoneg_link_width_d2    )
                                        | (cfg_max_payload_size_d      != cfg_max_payload_size_d2       )
                                        | (simplified_replay_timer_en  != simplified_replay_timer_en_d  )
                                        | (cfg_ext_synch               != cfg_ext_synch_d               ); 
                                            
        ack_timer_update_en         <= #TP  (smlh_autoneg_link_width_d != smlh_autoneg_link_width_d2    )
                                        | (cfg_max_payload_size_d      != cfg_max_payload_size_d2       );
                                            

        if (ack_timer_update_en) begin              // Ack/Nak Latency Timer
            unique case (1'b1)

                smlh_autoneg_link_width[0]:            // x1, (128, 256, 1024, 2048, 4096)
                    case (cfg_max_payload_size)
                        3'b000 : int_ack_latency_timer   <= #TP 16'd237   / NB;
                        3'b001 : int_ack_latency_timer   <= #TP 16'd416   / NB;
                        3'b010 : int_ack_latency_timer   <= #TP 16'd559   / NB;
                        3'b011 : int_ack_latency_timer   <= #TP 16'd1071  / NB;
                        3'b100 : int_ack_latency_timer   <= #TP 16'd2095  / NB;
                        default: int_ack_latency_timer   <= #TP 16'd4143  / NB;     //3'b101
                    endcase
                smlh_autoneg_link_width[1]:                    // x2, (128, 256, 1024, 2048, 4096)
                    case (cfg_max_payload_size)
                        3'b000 : int_ack_latency_timer   <= #TP 16'd128  / NB;
                        3'b001 : int_ack_latency_timer   <= #TP 16'd217  / NB;
                        3'b010 : int_ack_latency_timer   <= #TP 16'd289  / NB;
                        3'b011 : int_ack_latency_timer   <= #TP 16'd545  / NB;
                        3'b100 : int_ack_latency_timer   <= #TP 16'd1057 / NB;
                        default: int_ack_latency_timer   <= #TP 16'd2081 / NB;        //3'b101
                    endcase // case(cfg_max_payload_size)
                smlh_autoneg_link_width[2]: // x4, (128, 256, 1024, 2048, 4096)
                    case (cfg_max_payload_size)
                        3'b000 : int_ack_latency_timer   <= #TP 16'd73   / NB;
                        3'b001 : int_ack_latency_timer   <= #TP 16'd118  / NB;
                        3'b010 : int_ack_latency_timer   <= #TP 16'd154  / NB;
                        3'b011 : int_ack_latency_timer   <= #TP 16'd282  / NB;
                        3'b100 : int_ack_latency_timer   <= #TP 16'd538  / NB;
                        default: int_ack_latency_timer   <= #TP 16'd1050 / NB;      //3'b101
                    endcase // case(cfg_max_payload_size)
                default        : int_ack_latency_timer   <= #TP 16'd4143  / NB;
            endcase // case(1'b1)
        end
        else begin
            int_ack_latency_timer[7:0]  <= #TP (write_pulse[0] & pl_reg_id[0]) ? lbc_cdm_data[7:0]   : int_ack_latency_timer[7:0];
            int_ack_latency_timer[15:8] <= #TP (write_pulse[1] & pl_reg_id[0]) ? lbc_cdm_data[15:8]  : int_ack_latency_timer[15:8];
        end

        if (replay_timer_update_en) begin                            // Replay Timer
            unique case (1'b1)

                smlh_autoneg_link_width[0]:             // x1, (128, 256, 1024, 2048, 4096)
                  casez ({simplified_replay_timer_en, cfg_ext_synch, cfg_max_payload_size})
                        5'b00000 : int_replay_timer_value  <= #TP 17'd711   / NB;
                        5'b00001 : int_replay_timer_value  <= #TP 17'd1248  / NB;
                        5'b00010 : int_replay_timer_value  <= #TP 17'd1677  / NB;
                        5'b00011 : int_replay_timer_value  <= #TP 17'd3213  / NB;
                        5'b00100 : int_replay_timer_value  <= #TP 17'd6285  / NB;
                        5'b00101 : int_replay_timer_value  <= #TP 17'd12429 / NB;
                        5'b10??? : int_replay_timer_value  <= #TP 17'd27500 / NB; // A value from 24,000 to 31,000 Symbol Times when Extended Synch is 0b.
                        5'b11??? : int_replay_timer_value  <= #TP 17'd90000 / NB; // A value from 80,000 to 100,000 Symbol Times when Extended Synch is 1b.
                        default  : int_replay_timer_value  <= #TP 17'd12429 / NB;
                  endcase
                smlh_autoneg_link_width[1]:                     // x2, (128, 256, 1024, 2048, 4096)
                  casez ({simplified_replay_timer_en, cfg_ext_synch, cfg_max_payload_size}) 
                        5'b00000 : int_replay_timer_value  <= #TP 17'd384  / NB;
                        5'b00001 : int_replay_timer_value  <= #TP 17'd651  / NB;
                        5'b00010 : int_replay_timer_value  <= #TP 17'd867  / NB;
                        5'b00011 : int_replay_timer_value  <= #TP 17'd1635 / NB;
                        5'b00100 : int_replay_timer_value  <= #TP 17'd3171 / NB;
                        5'b00101 : int_replay_timer_value  <= #TP 17'd6243 / NB;
                        5'b10??? : int_replay_timer_value  <= #TP 17'd27500 / NB; // A value from 24,000 to 31,000 Symbol Times when Extended Synch is 0b.
                        5'b11??? : int_replay_timer_value  <= #TP 17'd90000 / NB; // A value from 80,000 to 100,000 Symbol Times when Extended Synch is 1b.
                        default  : int_replay_timer_value  <= #TP 17'd12429 / NB;
                  endcase // case(cfg_max_payload_size)
                smlh_autoneg_link_width[2]:   // x4, (128, 256, 1024, 2048, 4096)
                  casez ({simplified_replay_timer_en, cfg_ext_synch, cfg_max_payload_size})
                        5'b00000 : int_replay_timer_value  <= #TP 17'd219  / NB;
                        5'b00001 : int_replay_timer_value  <= #TP 17'd354  / NB;
                        5'b00010 : int_replay_timer_value  <= #TP 17'd462  / NB;
                        5'b00011 : int_replay_timer_value  <= #TP 17'd846  / NB;
                        5'b00100 : int_replay_timer_value  <= #TP 17'd1614 / NB;
                        5'b00101 : int_replay_timer_value  <= #TP 17'd3150 / NB;
                        5'b10??? : int_replay_timer_value  <= #TP 17'd27500 / NB; // A value from 24,000 to 31,000 Symbol Times when Extended Synch is 0b.
                        5'b11??? : int_replay_timer_value  <= #TP 17'd90000 / NB; // A value from 80,000 to 100,000 Symbol Times when Extended Synch is 1b.
                        default  : int_replay_timer_value  <= #TP 17'd12429 / NB;
                  endcase // case(cfg_max_payload_size)
                default  :         int_replay_timer_value  <= #TP 17'd12429 / NB;
            endcase // case(1'b1)
        end
        else begin
            int_replay_timer_value[7:0] <= #TP (write_pulse[2] & pl_reg_id[0]) ? lbc_cdm_data[23:16] : int_replay_timer_value[7:0];
            int_replay_timer_value[15:8]<= #TP (write_pulse[3] & pl_reg_id[0]) ? lbc_cdm_data[31:24] : int_replay_timer_value[15:8];
// Simplified Replay Timer enhancement puts the upper bit of the register outside of programmable range in port logic. 
// This potentially leads to a future problem for e.g. a 1S gen4 core with extended sync set. 
// 2GHz speeds are not yet support by Synopsys so this is unlikely to surface as an issue for some time.
// Current Max value is 100000 = 0x186A0
// For NB > 1 e.g. /2 = 50000 = 0xC350 which fits within 16 bit range.
            if (simplified_replay_timer_en && cfg_ext_synch && NB==1)
                int_replay_timer_value[16] <= #TP 1'b1; // MSB must be '1' for 80,000 to 100,000 range when Extended Synch is 1b and NB is 1
            else
                int_replay_timer_value[16] <= #TP 1'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Other MSG register / Corruption Pattern
// Other MSG: used to send a specific PCI-E Message. The user writes the payload
//            of the message it wishes to send into this registers, then sets bit
//            0 of the Port Link Control Register
// Corruption Pattern: used to store a corruption pattern for corrupting the LCRC
//                     on all TLP packets. The user places a 32-bit corruption
//                     pattern into this register and enables this function by
//                     setting bit 24 of the Port Link Control Register. When
//                     enabled, the transmit CRC result is XOR'd with this
//                     pattern before inserting it into the packet.
// pl_reg_id        - 1
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_4 to to pl_reg_7
// -----------------------------------------------------------------------------

assign cfg_other_msg_payload    = {pl_reg_7, pl_reg_6, pl_reg_5, pl_reg_4};
assign cfg_corrupt_crc_pattern  = cfg_xmt_corrupt_crc ? {pl_reg_7, pl_reg_6, pl_reg_5, pl_reg_4} : 32'h0;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        {pl_reg_7, pl_reg_6, pl_reg_5, pl_reg_4}    <= #TP `DEFAULT_REQ_OTHER_MSG;
    end
    else begin
        pl_reg_4    <= #TP (write_pulse[0] & pl_reg_id[1]) ? lbc_cdm_data[7:0]   : pl_reg_4;
        pl_reg_5    <= #TP (write_pulse[1] & pl_reg_id[1]) ? lbc_cdm_data[15:8]  : pl_reg_5;
        pl_reg_6    <= #TP (write_pulse[2] & pl_reg_id[1]) ? lbc_cdm_data[23:16] : pl_reg_6;
        pl_reg_7    <= #TP (write_pulse[3] & pl_reg_id[1]) ? lbc_cdm_data[31:24] : pl_reg_7;
    end
end

//------------------------------------------------------------------------------
// Port Force Link Register
// cpl_reg_id       - 2
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_8 to to pl_reg_11
// -----------------------------------------------------------------------------
assign cfg_link_num          = pl_reg_8;
assign cfg_forced_link_state = {pl_reg_10[5:0]};
assign cfg_support_part_lanes_rxei_exit = pl_reg_10[6];
assign cfg_ts2_lid_deskew    = pl_reg_10[7];
assign cfg_forced_ltssm_cmd  = {pl_reg_9[3:0]};


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n)
        cfg_force_en    <= #TP 0;
    else
        cfg_force_en    <= #TP write_pulse[1] & pl_reg_id[2] & lbc_cdm_data[15] & !cfg_force_en;
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_8        <= #TP `DEFAULT_LINK_NUM;       // Link number
        pl_reg_9        <= #TP 0;                       // Forced LTSSM cmd
        pl_reg_10[5:0]  <= #TP 0;                       // Forced link state
        pl_reg_10[6]    <= #TP `DEFAULT_SUPPORT_PART_LANES_RXEI_EXIT_IN_POLL_ACTIVE; // Polling.Active -> Polling.Configuration based on part of predetermined lanes RxEi exit
        pl_reg_10[7]    <= #TP `DEFAULT_DO_DESKEW_FOR_SRIS; // do deskew for sris using ts2 -> logic_idle_data transition
        pl_reg_11       <= #TP 0;                       // Reserved
    end
    else begin
        pl_reg_8        <= #TP (write_pulse[0] & pl_reg_id[2]) ? lbc_cdm_data[7:0]   : pl_reg_8;
        pl_reg_9[7:4]   <= #TP 4'b0;
        pl_reg_9[3:0]   <= #TP (write_pulse[1] & pl_reg_id[2]) ? lbc_cdm_data[11:8]  : pl_reg_9[3:0];
        pl_reg_10[5:0]  <= #TP (write_pulse[2] & pl_reg_id[2]) ? lbc_cdm_data[21:16] : pl_reg_10[5:0];
        pl_reg_10[6]    <= #TP (write_pulse[2] & pl_reg_id[2]) ? lbc_cdm_data[22]    : pl_reg_10[6];
        pl_reg_10[7]    <= #TP (write_pulse[2] & pl_reg_id[2]) ? lbc_cdm_data[23]    : pl_reg_10[7];
        pl_reg_11       <= #TP 0; 
    end
end

//------------------------------------------------------------------------------
// ACK freq register
// cpl_reg_id       - 3
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_12 to to pl_reg_15
// -----------------------------------------------------------------------------
assign cfg_ack_freq                 = pl_reg_12;
  assign cfg_n_fts                  = pl_reg_13;
assign cfg_l0s_entr_latency_timer   = pl_reg_15[2:0];
assign cfg_l1_entr_latency_timer    = pl_reg_15[5:3];
assign cfg_l1_entr_wo_rl0s          = pl_reg_15[6];
assign int_upd_aspm_ctrl            = (write_pulse[3] & pl_reg_id[3]);

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_12       <= #TP `DEFAULT_ACK_FREQUENCY;      // ACK frequency
        pl_reg_13       <= #TP `CX_NFTS;                    // N_FTS
        pl_reg_14       <= #TP `CX_COMM_NFTS;               // Common N_FTS
        pl_reg_15[2:0]  <= #TP `DEFAULT_L0S_ENTR_LATENCY;   // L0s entrance latency
        pl_reg_15[5:3]  <= #TP `DEFAULT_L1_ENTR_LATENCY;    // L1 entrance latency
        pl_reg_15[6]    <= #TP 0;                           // Enter L1 without rL0s
        pl_reg_15[7]    <= #TP 0;                           // Reserved
        cfg_upd_aspm_ctrl <= #TP 0;
    end
    else begin
        pl_reg_12       <= #TP (write_pulse[0] & pl_reg_id[3]) ? lbc_cdm_data[7:0]   : pl_reg_12;
        pl_reg_13       <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 8'h00 : (write_pulse[1] & pl_reg_id[3]) ? lbc_cdm_data[15:8]  : pl_reg_13;
        pl_reg_14       <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 8'h00 : `CX_COMM_NFTS;
        cfg_upd_aspm_ctrl <= #TP int_upd_aspm_ctrl;
        pl_reg_15[2:0]  <= #TP (write_pulse[3] & pl_reg_id[3]) ? lbc_cdm_data[26:24] : pl_reg_15[2:0];
        pl_reg_15[5:3]  <= #TP (write_pulse[3] & pl_reg_id[3]) ? lbc_cdm_data[29:27] : pl_reg_15[5:3];
        pl_reg_15[6]    <= #TP (write_pulse[3] & pl_reg_id[3]) ? lbc_cdm_data[30]    : pl_reg_15[6];
        pl_reg_15[7]    <= #TP 0;
    end
end

//------------------------------------------------------------------------------
// Port Link Control register
// pl_reg_id        - 4
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_16
// -----------------------------------------------------------------------------
assign cfg_other_msg_request    = pl_reg_16[0];
assign cfg_scramble_dis         = pl_reg_16[1];
assign cfg_lpbk_en              = pl_reg_16[2];
assign cfg_plreg_reset          = pl_reg_16[3];
assign cfg_dll_lnk_en           = pl_reg_16[5];

assign cfg_link_dis             = pl_reg_16[6];
assign cfg_link_rate            = pl_reg_17[3:0];
//assign cfg_ext_synch            = pl_reg_19[2]; //extended sync is spec defined so this port logic register is incorrect.
assign cfg_xmt_beacon           = pl_reg_19[0];

assign cfg_fast_link_mode       = pl_reg_16[7];
assign cfg_link_capable         = pl_reg_18[5:0];
assign cfg_xmt_corrupt_crc      = pl_reg_19[1];
assign cfg_tx_reverse_lanes     = pl_reg_19[3];



always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin

        pl_reg_16[0]    <= #TP 1'b0;                            // Send special message

        pl_reg_16[1]    <= #TP `DEFAULT_SCRAMBLE_DISABLE;       // Scrambler disabled
        pl_reg_16[2]    <= #TP `DEFAULT_LOOPBACK_ENABLE;        // Loopback enabled
        pl_reg_16[3]    <= #TP `DEFAULT_RESET_ASSERT;           // LTSSM goes to Hot Reset state
        pl_reg_16[4]    <= #TP 1'b0;                            // Reserved
        pl_reg_16[5]    <= #TP `DEFAULT_DLL_LINK_ENABLE;        // DLL Link enable - allows L2 link up

        pl_reg_16[6]    <= #TP `DEFAULT_LINK_DISABLE;           // Link disable (only L1/L2 package) - otherwise, use Link control register
        pl_reg_17[3:0]  <= #TP `DEFAULT_LINK_RATE;              // Link data rate (only L1/L2 package) - otherwise, use Link status register
        pl_reg_17[7:4]  <= #TP 4'b0;                            // Reserved
        pl_reg_19[0]    <= #TP `DEFAULT_BEACON_ENABLE;          // Transmit beacon enable
        pl_reg_19[2]    <= #TP 1'b0;                            // Extended Synch (only L1/L2 package) - otherwise, use Link control register

        pl_reg_18[5:0]  <= #TP `DEFAULT_LINK_CAPABLE;           // Supported number of lanes - direct control over ltssm_lanes_active
        pl_reg_18[7:6]  <= #TP 2'b0;                            // Reserved
        pl_reg_19[1]    <= #TP 1'b0;                            // Corrupt LCRC enable
        pl_reg_19[3]    <= #TP 1'b0;                            // Transmit lane reversale enable
        pl_reg_19[7:4]  <= #TP 4'b0;                            // Reserved
    end
    else begin

        pl_reg_16[0]    <= #TP (write_pulse[0] & pl_reg_id[4] & lbc_cdm_data[0] & !pl_reg_16[0]);     // 1-cycle pulse

        pl_reg_16[1]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[1]   : pl_reg_16[1];
        pl_reg_16[2]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[2]   : pl_reg_16[2];
        pl_reg_16[3]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[3]   : pl_reg_16[3];
        pl_reg_16[4]    <= #TP 1'b0;
        pl_reg_16[5]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[5]   : pl_reg_16[5];
        pl_reg_16[6]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[6]   : pl_reg_16[6];

        pl_reg_17[3:0]  <= #TP (write_pulse[1] & pl_reg_id[4]) ? lbc_cdm_data[11:8]  : pl_reg_17[3:0];
        pl_reg_17[7:4]  <= #TP 4'b0;
        pl_reg_18[5:0]    <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 6'h00 : (write_pulse[2] & pl_reg_id[4]) ? lbc_cdm_data[21:16] : pl_reg_18[5:0];

        pl_reg_18[7:6]  <= #TP 2'b0;                            // Reserved
        pl_reg_19[3:0]  <= #TP (write_pulse[3] & pl_reg_id[4]) ? lbc_cdm_data[27:24] : pl_reg_19[3:0];
        pl_reg_19[7:4]  <= #TP 0;
    end
end

// spyglass disable_block W552
// SMD: Bus 'pl_reg_16' is driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n)
        pl_reg_16[7]    <= #TP `DEFAULT_FAST_LINK_ENABLE;       // Fast Link mode
    else begin
        pl_reg_16[7]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[7] : pl_reg_16[7];
    end
end
// spyglass enable_block W552



//------------------------------------------------------------------------------
// Lane Skew Register
// cpl_reg_id       - 5
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_20 , 21, 22, 23
// -----------------------------------------------------------------------------
assign cfg_lane_skew            = {pl_reg_22, pl_reg_21, pl_reg_20};
assign cfg_deskew_disable       = pl_reg_23[7];
assign cfg_imp_num_lanes        = pl_reg_23[6:3];
assign cfg_elastic_buffer_mode  = 1'b0; 
assign cfg_acknack_disable      = pl_reg_23[1];
assign cfg_flow_control_disable = pl_reg_23[0];

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_20       <= #TP 0;               // Lane deskew
        pl_reg_21       <= #TP 0;               // Lane deskew
        pl_reg_22       <= #TP 0;               // Lane deskew
        pl_reg_23[0]    <= #TP 0;               // Flow control disable
        pl_reg_23[1]    <= #TP 0;               // ACK/NAK disable
        pl_reg_23[2]    <= #TP `DEFAULT_LANE_SKEW_OFF_26; 
        pl_reg_23[6:3]  <= #TP NLM1;            // implementation-specific number of lanes, 0->1, 1->2, 3->4, 7->8, 15->16
        pl_reg_23[7]    <= #TP 0;
    end
    else begin
        pl_reg_20       <= #TP (write_pulse[0] & pl_reg_id[5]) ? lbc_cdm_data[7:0]   : pl_reg_20;
        pl_reg_21       <= #TP (write_pulse[1] & pl_reg_id[5]) ? lbc_cdm_data[15:8]  : pl_reg_21;
        pl_reg_22       <= #TP (write_pulse[2] & pl_reg_id[5]) ? lbc_cdm_data[23:16] : pl_reg_22;
        pl_reg_23[0]    <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[24]    : pl_reg_23[0];
        pl_reg_23[1]    <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[25]    : pl_reg_23[1];
        pl_reg_23[2]    <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[26]    : pl_reg_23[2];
        pl_reg_23[6:3]  <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[30:27] : pl_reg_23[6:3];
        pl_reg_23[7]    <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[31]    : pl_reg_23[7];
    end
end

//------------------------------------------------------------------------------
// SYMBOL number register
// cpl_reg_id       - 6
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_24,25,26,27
// -----------------------------------------------------------------------------
assign cfg_max_func_num         = pl_reg_24[PF_WD   -1:0];
assign replay_timer_add         = {pl_reg_26[2:0], pl_reg_25[7:6]};
assign acknak_timer_add         = pl_reg_26[7:3];
assign cfg_fast_link_scaling_factor = pl_reg_27[6:5];




assign int_replay_timer_add     =
                                  {2'b00, replay_timer_add}; //Each increment of the replay timer by 64

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_24[7:0]  <= #TP `CX_MAX_FUNC_NUM;                // Max number of functions supported
        pl_reg_25[2:0]  <= #TP 0;                               // Reserved
        pl_reg_25[5:3]  <= #TP 0;                               // Reserved
        {pl_reg_26[2:0],
        pl_reg_25[7:6]} <= #TP `DEFAULT_REPLAY_ADJ;             // Replay timer modifier
        pl_reg_26[7:3]  <= #TP 0;                               // ACK/NAK latency timer modifier
        pl_reg_27[4:0]  <= #TP 0;                               // FC update freq timer modifier
        pl_reg_27[6:5]  <= #TP `DEFAULT_FAST_LINK_SCALING_FACTOR; // Fast Link timer Scaling Factor
        pl_reg_27[7]    <= #TP 0;                               // Reserved
    end
    else begin
        pl_reg_24       <= #TP (write_pulse[0] & pl_reg_id[6]) ? lbc_cdm_data[7:0]   : pl_reg_24;
        pl_reg_25[2:0]  <= #TP 0;                               // Reserved
        pl_reg_25[5:3]  <= #TP 0;                               // Reserved
        pl_reg_25[7:6]  <= #TP
                               (write_pulse[1] & pl_reg_id[6]) ? lbc_cdm_data[15:14] :
                               pl_reg_25[7:6];
        pl_reg_26[2:0]  <= #TP
                               (write_pulse[2] & pl_reg_id[6]) ? lbc_cdm_data[18:16] :
                               pl_reg_26[2:0];
        pl_reg_26[7:3]  <= #TP (write_pulse[2] & pl_reg_id[6]) ? lbc_cdm_data[23:19] : pl_reg_26[7:3];
        pl_reg_27[4:0]  <= #TP (write_pulse[3] & pl_reg_id[6]) ? lbc_cdm_data[28:24] : pl_reg_27[4:0];
        pl_reg_27[6:5]  <= #TP (write_pulse[3] & pl_reg_id[6]) ? lbc_cdm_data[30:29] : pl_reg_27[6:5];
        pl_reg_27[7]    <= #TP 0;                               // Reserved
    end
end

//------------------------------------------------------------------------------
// SYMBOL timer & Filer Mask register
// cpl_reg_id       - 7
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_28,29, 30, 21
// -----------------------------------------------------------------------------
localparam logic [47:0] DEF_CFG_FILTER_RULE_MASK = {32'(`DEFAULT_FILTER_MASK_2), 16'(`DEFAULT_FILTER_MASK_1)};
wire    [47:0]  pl_filter_rule_reg;
assign pl_filter_rule_reg       = {pl_reg_35, pl_reg_34, pl_reg_33, pl_reg_32, pl_reg_31, pl_reg_30};
assign cfg_skip_interval        = {pl_reg_29[2:0], pl_reg_28[7:0]};
assign cfg_eidle_timer          = pl_reg_29[6:3];
assign cfg_fc_wdog_disable      = pl_reg_29[7];
assign cfg_filter_rule_mask     = pl_filter_rule_reg[N_FLT_MASK-1:0];

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        {pl_reg_29[2:0], pl_reg_28} <= #TP `DEFAULT_SKIP_INTERVAL;          // Skip interval
    end
    else begin
        pl_reg_28        <= #TP (write_pulse[0] & pl_reg_id[7]) ? lbc_cdm_data[7:0]   : pl_reg_28;
        pl_reg_29[2:0]   <= #TP (write_pulse[1] & pl_reg_id[7]) ? lbc_cdm_data[10:8]  : pl_reg_29[2:0];
    end
end

// spyglass disable_block W552
// SMD: Bus 'pl_reg_29' is driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.
 
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_29[6:3]              <= #TP `DEFAULT_EIDLE_TIMER;            // Eidle timer
        pl_reg_29[7]                <= #TP `DEFAULT_FC_WATCH_DOG_DISABLE;   // Flow control watchdog timer disable
        pl_reg_31                   <= #TP DEF_CFG_FILTER_RULE_MASK[15:8];  // Filter rule mask
        pl_reg_30                   <= #TP DEF_CFG_FILTER_RULE_MASK[7:0];   // Filter rule mask
    end
    else begin
        pl_reg_29[7:3]   <= #TP (write_pulse[1] & pl_reg_id[7]) ? lbc_cdm_data[15:11] : pl_reg_29[7:3];
        pl_reg_30        <= #TP (write_pulse[2] & pl_reg_id[7]) ? lbc_cdm_data[23:16] : pl_reg_30;
        pl_reg_31        <= #TP (write_pulse[3] & pl_reg_id[7]) ? lbc_cdm_data[31:24] : pl_reg_31;
    end
end
// spyglass enable_block W552

//------------------------------------------------------------------------------
// Filer Mask register 2
// cpl_reg_id       - 8
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_32, 33, 34, 35
// -----------------------------------------------------------------------------
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_32   <= #TP DEF_CFG_FILTER_RULE_MASK[23:16];                 // Filter rule mask
        pl_reg_33   <= #TP DEF_CFG_FILTER_RULE_MASK[31:24];                 // Filter rule mask
        pl_reg_34   <= #TP DEF_CFG_FILTER_RULE_MASK[39:32];                 // Filter rule mask
        pl_reg_35   <= #TP DEF_CFG_FILTER_RULE_MASK[47:40];                 // Filter rule mask
    end
    else begin
        pl_reg_32   <= #TP (write_pulse[0] & pl_reg_id[8]) ? lbc_cdm_data[7:0]   : pl_reg_32;
        pl_reg_33   <= #TP (write_pulse[1] & pl_reg_id[8]) ? lbc_cdm_data[15:8]  : pl_reg_33;
        pl_reg_34   <= #TP (write_pulse[2] & pl_reg_id[8]) ? lbc_cdm_data[23:16] : pl_reg_34;
        pl_reg_35   <= #TP (write_pulse[3] & pl_reg_id[8]) ? lbc_cdm_data[31:24] : pl_reg_35;
    end
end

//------------------------------------------------------------------------------
// Misc control register
// cpl_reg_id       - 9
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_36, 37, 38, 39
// -----------------------------------------------------------------------------
assign {pl_reg_39, pl_reg_38, pl_reg_37} = 0;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_36       <= #TP 0;
    end else begin
        pl_reg_36[0]  <= #TP 0;
        pl_reg_36[7:1]  <= #TP 0;
    end
end

// Dont need to cover the debug registers

//------------------------------------------------------------------------------
// Debug registers
// pl_reg_id    - 10, 11
// Length       - 8 bytes
// Default value
// Core register- pl_reg_40 to 47
//------------------------------------------------------------------------------

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        {pl_reg_43, pl_reg_42, pl_reg_41, pl_reg_40}    <= #TP 0;
        {pl_reg_47, pl_reg_46, pl_reg_45, pl_reg_44}    <= #TP 0;
    end
    else begin
        {pl_reg_43, pl_reg_42, pl_reg_41, pl_reg_40}    <= #TP cxpl_debug_info[31:0];
        {pl_reg_47, pl_reg_46, pl_reg_45, pl_reg_44}    <= #TP cxpl_debug_info[63:32];
    end
end

//------------------------------------------------------------------------------
// Debug registers
// pl_reg_id    - 12 - 14
// Length       - 12 bytes
// Default value
// Core register- pl_reg_48 to 59
//------------------------------------------------------------------------------

wire [11:0] all_zeros;
assign all_zeros = 12'b0;

assign {pl_reg_51, pl_reg_50, pl_reg_49, pl_reg_48} = {all_zeros, xtlh_xadm_ph_cdts, xtlh_xadm_pd_cdts};
assign {pl_reg_55, pl_reg_54, pl_reg_53, pl_reg_52} = {all_zeros, xtlh_xadm_nph_cdts, xtlh_xadm_npd_cdts};
assign {pl_reg_59, pl_reg_58, pl_reg_57, pl_reg_56} = {all_zeros, xtlh_xadm_cplh_cdts, xtlh_xadm_cpld_cdts};

//------------------------------------------------------------------------------
// Debug registers
// pl_reg_id    - 15
// Length       - 4 bytes
// Default value
// Core register- pl_reg_60 to 63
//------------------------------------------------------------------------------

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_62       <= #TP 0;
        pl_reg_63       <= #TP 0;
    end
    else begin
        pl_reg_62       <= #TP (write_pulse[2] & pl_reg_id[15]) ? lbc_cdm_data[23:16] : pl_reg_62;
        pl_reg_63[4:0]  <= #TP (write_pulse[3] & pl_reg_id[15]) ? lbc_cdm_data[28:24] : pl_reg_63[4:0];
        pl_reg_63[6:5]  <= #TP 2'b0;
        pl_reg_63[7]    <= #TP (write_pulse[3] & pl_reg_id[15]) ? lbc_cdm_data[31]    : pl_reg_63[7];
    end
end

assign fc_timer_override_val = {pl_reg_63[4:0],pl_reg_62};
assign fc_timer_override     = pl_reg_63[7];

// -- Rx Queue Status
//      - Credit Queue, VC0, P/NP/CPL
wire clr_radm_qoverflow;
wire set_radm_qoverflow;
assign clr_radm_qoverflow = (write_pulse[0] & pl_reg_id[15]) ? lbc_cdm_data[3] : 1'b0;
assign set_radm_qoverflow = radm_qoverflow;

reg  r_radm_qoverflow;
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      r_radm_qoverflow <= #TP 0;
    end else begin
      r_radm_qoverflow <= #TP set_radm_qoverflow ? 1'b1 : clr_radm_qoverflow ? 1'b0 : r_radm_qoverflow;
    end
end

assign {pl_reg_61, pl_reg_60} = { 12'b0,
                                 r_radm_qoverflow,
                                 radm_q_not_empty, xdlh_retrybuf_not_empty, rtlh_crd_not_rtn
                                };

//------------------------------------------------------------------------------
// XADM Transmit Arbitration
// pl_reg_id    - 16, 17
// Length       - 8 bytes
// Default value
// Core register- pl_reg_64 to 71
//------------------------------------------------------------------------------
//
assign cfg_lpvc_wrr_weight[7:0]     = pl_reg_64;
assign cfg_lpvc_wrr_weight[15:8]    = pl_reg_65;
assign cfg_lpvc_wrr_weight[23:16]   = pl_reg_66;
assign cfg_lpvc_wrr_weight[31:24]   = pl_reg_67;
assign cfg_lpvc_wrr_weight[39:32]   = pl_reg_68;
assign cfg_lpvc_wrr_weight[47:40]   = pl_reg_69;
assign cfg_lpvc_wrr_weight[55:48]   = pl_reg_70;
assign cfg_lpvc_wrr_weight[63:56]   = pl_reg_71;

always @(posedge core_clk or negedge sticky_rst_n)
begin : lpvc_wrr_weight_PROC
    if (!sticky_rst_n) begin
        pl_reg_64   <= #TP `LPVC_WRR_WEIGHT_VC0;
        pl_reg_65   <= #TP `LPVC_WRR_WEIGHT_VC1;
        pl_reg_66   <= #TP `LPVC_WRR_WEIGHT_VC2;
        pl_reg_67   <= #TP `LPVC_WRR_WEIGHT_VC3;
        pl_reg_68   <= #TP `LPVC_WRR_WEIGHT_VC4;
        pl_reg_69   <= #TP `LPVC_WRR_WEIGHT_VC5;
        pl_reg_70   <= #TP `LPVC_WRR_WEIGHT_VC6;
        pl_reg_71   <= #TP `LPVC_WRR_WEIGHT_VC7;
    end
    else begin
        pl_reg_64   <= #TP `LPVC_WRR_WEIGHT_VC0;
        pl_reg_65   <= #TP `LPVC_WRR_WEIGHT_VC1;
        pl_reg_66   <= #TP `LPVC_WRR_WEIGHT_VC2;
        pl_reg_67   <= #TP `LPVC_WRR_WEIGHT_VC3;
        pl_reg_68   <= #TP `LPVC_WRR_WEIGHT_VC4;
        pl_reg_69   <= #TP `LPVC_WRR_WEIGHT_VC5;
        pl_reg_70   <= #TP `LPVC_WRR_WEIGHT_VC6;
        pl_reg_71   <= #TP `LPVC_WRR_WEIGHT_VC7;
    end
end

//------------------------------------------------------------------------------
// Flow Control Credits & Single RAM (Segmented Buffer) Control Register
// pl_reg_id    - 18 - 41
// Length       -
// Default value
// Core register- pl_reg_72 to pl_reg_167
//------------------------------------------------------------------------------

assign  cfg_fc_credit_pd[11:0]      = {pl_reg_73[3:0], pl_reg_72};
assign  cfg_fc_credit_ph[7:0]       = {pl_reg_74[3:0], pl_reg_73[7:4]};
assign  cfg_fc_credit_npd[11:0]     = {pl_reg_77[3:0], pl_reg_76};
assign  cfg_fc_credit_nph[7:0]      = {pl_reg_78[3:0], pl_reg_77[7:4]};
assign  cfg_fc_credit_cpld[11:0]    = {pl_reg_81[3:0], pl_reg_80};
assign  cfg_fc_credit_cplh[7:0]     = {pl_reg_82[3:0], pl_reg_81[7:4]};

assign  hdr_scale_p[1:0]           = pl_reg_75[1:0];
assign  data_scale_p[1:0]          = pl_reg_75[3:2];
assign  hdr_scale_np[1:0]          = pl_reg_79[1:0];
assign  data_scale_np[1:0]         = pl_reg_79[3:2];
assign  hdr_scale_cpl[1:0]         = pl_reg_83[1:0];
assign  data_scale_cpl[1:0]        = pl_reg_83[3:2];

assign cfg_radm_order_rule[0]       = pl_reg_75[6];
assign cfg_radm_strict_vc_prior     = pl_reg_75[7];
assign cfg_radm_q_mode[8:0]         = {pl_reg_82[7:5], pl_reg_78[7:5], pl_reg_74[7:5]};

always @(posedge core_clk or negedge sticky_rst_n)
begin : vc0_rcv_q_ctrl_PROC
    if (!sticky_rst_n) begin
        {pl_reg_74[3:0], pl_reg_73, pl_reg_72}  <= #TP {`RADM_PQ_HCRD_VC0, `RADM_PQ_DCRD_VC0};
        pl_reg_74[4]                            <= #TP 0;                                           // Reserved
        pl_reg_74[7:5]                          <= #TP `RADM_P_QMODE_VC0;
        pl_reg_75[1:0]                          <= #TP `RADM_PQ_HSCALE_VC0;
        pl_reg_75[3:2]                          <= #TP `RADM_PQ_DSCALE_VC0;
        pl_reg_75[5:4]                          <= #TP 0;                                           // Reserved

        pl_reg_75[6]                            <= #TP `CX_RADM_ORDERING_RULES_VC0;
        pl_reg_75[7]                            <= #TP `CX_RADM_STRICT_VC_PRIORITY;
        {pl_reg_78[3:0], pl_reg_77, pl_reg_76}  <= #TP {`RADM_NPQ_HCRD_VC0, `RADM_NPQ_DCRD_VC0};
        pl_reg_78[4]                            <= #TP 0;                                           // Reserved
        pl_reg_78[7:5]                          <= #TP `RADM_NP_QMODE_VC0;
        pl_reg_79[1:0]                          <= #TP `RADM_NPQ_HSCALE_VC0;
        pl_reg_79[3:2]                          <= #TP `RADM_NPQ_DSCALE_VC0;
        pl_reg_79[7:4]                          <= #TP 0;                                           // Reserved

        {pl_reg_82[3:0], pl_reg_81, pl_reg_80}  <= #TP {`RADM_CPLQ_HCRD_VC0, `RADM_CPLQ_DCRD_VC0};
        pl_reg_82[4]                            <= #TP 0;                                           // Reserved
        pl_reg_82[7:5]                          <= #TP `RADM_CPL_QMODE_VC0;
        pl_reg_83[1:0]                          <= #TP `RADM_CPLQ_HSCALE_VC0;
        pl_reg_83[3:2]                          <= #TP `RADM_CPLQ_DSCALE_VC0;
        pl_reg_83[7:4]                          <= #TP 0;                                           // Reserved

    end
    else begin
        {pl_reg_74[3:0], pl_reg_73, pl_reg_72}  <= #TP {`RADM_PQ_HCRD_VC0, `RADM_PQ_DCRD_VC0};
        pl_reg_74[7:4]                          <= #TP (write_pulse[2] & pl_reg_id[18]) ? lbc_cdm_data[23:20] : pl_reg_74[7:4];
        pl_reg_75                               <= #TP (write_pulse[3] & pl_reg_id[18]) ? lbc_cdm_data[31:24] : pl_reg_75;
        {pl_reg_78[3:0], pl_reg_77, pl_reg_76}  <= #TP {`RADM_NPQ_HCRD_VC0, `RADM_NPQ_DCRD_VC0};
        pl_reg_78[7:4]                          <= #TP (write_pulse[2] & pl_reg_id[19]) ? lbc_cdm_data[23:20] : pl_reg_78[7:4];
        pl_reg_79                               <= #TP (write_pulse[3] & pl_reg_id[19]) ? lbc_cdm_data[31:24] : pl_reg_79;
        {pl_reg_82[3:0], pl_reg_81, pl_reg_80}  <= #TP {`RADM_CPLQ_HCRD_VC0, `RADM_CPLQ_DCRD_VC0};
        pl_reg_82[7:4]                          <= #TP (write_pulse[2] & pl_reg_id[20]) ? lbc_cdm_data[23:20] : pl_reg_82[7:4];
        pl_reg_83                               <= #TP (write_pulse[3] & pl_reg_id[20]) ? lbc_cdm_data[31:24] : pl_reg_83;
    end
end









//------------------------------------------------------------------------------
// Segment Sizes Register
// pl_reg_id    -
// Length       -
// Default value
// Core register-
//------------------------------------------------------------------------------

assign cfg_hq_depths[(RADM_SBUF_HDRQ_PW *(0+(3*0)+1))-1:RADM_SBUF_HDRQ_PW *(0+(3*0))] = `RADM_PQ_HDP_VC0;
assign cfg_hq_depths[(RADM_SBUF_HDRQ_PW *(1+(3*0)+1))-1:RADM_SBUF_HDRQ_PW *(1+(3*0))] = `RADM_NPQ_HDP_VC0;
assign cfg_hq_depths[(RADM_SBUF_HDRQ_PW *(2+(3*0)+1))-1:RADM_SBUF_HDRQ_PW *(2+(3*0))] = `RADM_CPLQ_HDP_VC0;

assign cfg_dq_depths[(RADM_SBUF_DATAQ_PW*(0+(3*0)+1))-1:RADM_SBUF_DATAQ_PW*(0+(3*0))] = `RADM_PQ_DDP_VC0;
assign cfg_dq_depths[(RADM_SBUF_DATAQ_PW*(1+(3*0)+1))-1:RADM_SBUF_DATAQ_PW*(1+(3*0))] = `RADM_NPQ_DDP_VC0;
assign cfg_dq_depths[(RADM_SBUF_DATAQ_PW*(2+(3*0)+1))-1:RADM_SBUF_DATAQ_PW*(2+(3*0))] = `RADM_CPLQ_DDP_VC0;









//------------------------------------------------------------------------------
// 8b/10b Error Count Register
// cpl_reg_id       - 66
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - {pl_reg_171, pl_reg_170, pl_reg_169, pl_reg_168}
// -----------------------------------------------------------------------------

//------------------------------------------------------------------------------
// PCIe Gen 2 Register
// cpl_reg_id       - 67
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - {pl_reg_175, pl_reg_174, pl_reg_173, pl_reg_172}
// -----------------------------------------------------------------------------
//assign {pl_reg_175, pl_reg_174, pl_reg_173, pl_reg_172} = {12'b0, cfg_tx_compliance_rcv, cfg_phy_txswing, cfg_directed_speed_change, cfg_lane_en, cfg_gen2_n_fts};
wire cfg_gen1_ei_inference_mode;
wire cfg_do_g5_lpbk_eq, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_mod_ts;
wire cfg_force_lane_flip;
wire [3:0] cfg_lane_under_test;
wire cfg_select_deemph_var_mux, cfg_selectable_deemph_bit_mux; //cfg_select_deemph_var_mux: select_deemphasis variable mux, cfg_selectable_deemph_bit_mux: mux for selectable deemphasis bit in Tx TS2s
wire [1:0] cfg_select_deemph_mux_bus = {cfg_selectable_deemph_bit_mux, cfg_select_deemph_var_mux};
// {force lane flip enable, the lane number of under test, Tx modified compliance pattern, gen5 loopback eq enable, mod ts support}
wire [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl = {cfg_force_lane_flip, cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts}; //lut = Lane Under _test

assign cfg_lane_en              = {pl_reg_174[0], pl_reg_173};
assign cfg_gen1_ei_inference_mode = pl_reg_174[5];
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_172      <= #TP 0;                           // Reserved
        pl_reg_174[0]   <= #TP 1'b1;
        pl_reg_173      <= #TP NL;                         // Number of lanes (1-256)
        pl_reg_174[4:1] <= #TP 0;                           // Reserved
        pl_reg_174[5]   <= #TP 1'b0;                        // EI inference mode for Gen1. default = 0 - using rxelecidle == 1; 1 - using rxvalid == 0
        pl_reg_174[7:6] <= #TP 0;                           // Reserved
        pl_reg_175      <= #TP 0;                           // Reserved
    end
    else begin
        pl_reg_172      <= #TP 0;                           // Reserved
        pl_reg_173      <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 8'h00  : (write_pulse[1] & pl_reg_id[67]) ? lbc_cdm_data[15:8] : pl_reg_173;
        pl_reg_174[0]   <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 1'b0   : (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[16]   : pl_reg_174[0];
        pl_reg_174[4:1] <= #TP 0;                           // Reserved
        pl_reg_174[5]   <= #TP (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[21]   : pl_reg_174[5];
        pl_reg_174[7:6] <= #TP 0;                           // Reserved
        pl_reg_175      <= #TP 0;                           // Reserved
    end
end


assign cfg_do_g5_lpbk_eq        = 0;
assign cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn = 0;
assign cfg_lane_under_test      = 0;
assign cfg_force_lane_flip      = 0;
assign cfg_select_deemph_var_mux = 1'b0;
assign cfg_selectable_deemph_bit_mux = 1'b0;
assign cfg_mod_ts = 0;


//------------------------------------------------------------------------------
// PHY status register
// cpl_reg_id       - 68
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_179, pl_reg_178, pl_reg_177, pl_reg_176
// -----------------------------------------------------------------------------

assign {pl_reg_179, pl_reg_178, pl_reg_177, pl_reg_176} = (phy_type == `PHY_TYPE_MPCIE) ? 32'h0000_0000 : phy_cfg_status;

//------------------------------------------------------------------------------
// PHY control register
// cpl_reg_id       - 69
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180
// -----------------------------------------------------------------------------

assign cfg_phy_control = {pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180};

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        {pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180}  <= #TP `DEFAULT_PHY_CONTROL;
    end
    else begin
        pl_reg_180 <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 8'h00 : (write_pulse[0] & pl_reg_id[69]) ? lbc_cdm_data[7:0]   : pl_reg_180;
        pl_reg_181 <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 8'h00 : (write_pulse[1] & pl_reg_id[69]) ? lbc_cdm_data[15:8]  : pl_reg_181;
        pl_reg_182 <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 8'h00 : (write_pulse[2] & pl_reg_id[69]) ? lbc_cdm_data[23:16] : pl_reg_182;
        pl_reg_183 <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 8'h00 : (write_pulse[3] & pl_reg_id[69]) ? lbc_cdm_data[31:24] : pl_reg_183;
    end
end




//-------------------------------------------------------------------------------------------------------------
//
// Istantiate Gen3 Transmit Equalization Programmable Presets to Coefficients Mapping Table.
//
//-------------------------------------------------------------------------------------------------------------



//-------------------------------------------------------------------------------------------------------------
//
// END of Gen3 Transmit Equalization Programmable Presets to Coefficients Mapping Table instantiation
//
//-------------------------------------------------------------------------------------------------------------





//------------------------------------------------------------------------------
// Order Rule Ctrl
// cpl_reg_id       - 109 (offset 0x1b4)
// Length           - 2 byte
// Default value    - 0
// Core register    - {16'h0, pl_reg_240, pl_reg_239}
// -----------------------------------------------------------------------------

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
      pl_reg_239             <= #TP 8'b0;
      pl_reg_240             <= #TP 8'b0;
    end
    else begin
      // ORDER_RULE_CTRL
      pl_reg_239     <= #TP (write_pulse[0] & pl_reg_id[109]) ? lbc_cdm_data[7:0]  : pl_reg_239;
      pl_reg_240     <= #TP (write_pulse[1] & pl_reg_id[109]) ? lbc_cdm_data[15:8] : pl_reg_240;
    end
end

assign cfg_order_rule_ctrl  = {pl_reg_240, pl_reg_239};

//------------------------------------------------------------------------------
// TRGT_CPL_LUT Delete Entry Ctrl
// cpl_reg_id       - 151 (offset 0x1c8)
// Length           - 4 byte
// Default value    - 0
// Core register    - {pl_reg_244, pl_reg_243, pl_reg_242, pl_reg_241}
// -----------------------------------------------------------------------------

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
      pl_reg_241             <= #TP 8'b0;
      pl_reg_242             <= #TP 8'b0;
      pl_reg_243             <= #TP 8'b0;
      pl_reg_244             <= #TP 8'b0;
    end
    else begin
      // TRGT_CPL_LUT Delete Entry Ctrl
      pl_reg_241     <= #TP (write_pulse[0] & pl_reg_id[151]) ? lbc_cdm_data[7:0]   : pl_reg_241;
      pl_reg_242     <= #TP (write_pulse[1] & pl_reg_id[151]) ? lbc_cdm_data[15:8]  : pl_reg_242;
      pl_reg_243     <= #TP (write_pulse[2] & pl_reg_id[151]) ? lbc_cdm_data[23:16] : pl_reg_243;
      pl_reg_244     <= #TP (write_pulse[3] & pl_reg_id[151]) ? lbc_cdm_data[31:24] : {1'b0, pl_reg_244[6:0]};
    end
end

// cfg_trgt_cpl_lut_delete_entry[31]: This is a one shot bit. A '1' write to this bit triggers the deletion of the entry specified in the lookup_id field.
// This is a self-clearing register field. Reading from this register field always returns a "0".
assign cfg_trgt_cpl_lut_delete_entry  = { pl_reg_244, pl_reg_243, pl_reg_242, pl_reg_241};


//------------------------------------------------------------------------------
// Application Bus and  Device number Status for Root port or Downstream switch port
// pl_reg_id        - `CX_PL_REG + ID_0x410
// Length           - 4 bytes
// Default value    - 0x0000
// Core register    - {16'b0,app_bus_num, app_dev_num, 3'b0}
// -----------------------------------------------------------------------------
  assign app_bus_dev_num_status   = {app_bus_num, app_dev_num, 3'b0};

//------------------------------------------------------------------------------
// Order Rule Ctrl
// cpl_reg_id       - 153 (offset 0x18c)
// Length           - 1 bit (4 byte max)
// Default value    - 1
// Core register    - {16'h0, 8'h0, 6'h0, r_axi_clk_gating_en, r_radm_clk_gating_en}
// -----------------------------------------------------------------------------

always @(posedge core_clk or negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    r_radm_clk_gating_en <= #TP 1'b1;
  end else begin
    // Clock_gating_ctrl
    r_radm_clk_gating_en <= #TP (write_pulse[0] & pl_reg_id[153]) ? lbc_cdm_data[0]  : r_radm_clk_gating_en;
  end
end
assign cfg_clock_gating_ctrl  = { 1'b0, r_radm_clk_gating_en}; 

//------------------------------------------------------------------------------
// Enable PIPE Loopback
// cpl_reg_id       - 110 (offset 0x1b8)
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - {pl_reg_203, pl_reg_202, pl_reg_201, pl_reg_200}
// -----------------------------------------------------------------------------

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_203[7]             <= #TP `DEFAULT_PIPE_LOOPBACK;
      pl_reg_203[6:0]           <= #TP 7'b0;
      pl_reg_202                <= #TP 8'b0;
      {pl_reg_201,pl_reg_200}   <= #TP {NL{1'b1}};
    end
    else begin
      // PIPE Looback enable
      pl_reg_203[7]     <= #TP (write_pulse[3] & pl_reg_id[110]) ? lbc_cdm_data[31] : pl_reg_203[7];
      pl_reg_203[6:3]   <= #TP 4'b0;
      // RX status value to inject, this is self clearing
      pl_reg_203[2:0]   <= #TP (write_pulse[3] & pl_reg_id[110]) ? lbc_cdm_data[26:24] : 3'b0;
      // which lane to inject rxstatus value, bit6 => all lanes, bit[5:0]
      // allow lanes 0-31 to be selected
      pl_reg_202[7:6]   <= #TP 2'b0;
      pl_reg_202[5:0]   <= #TP (write_pulse[2] & pl_reg_id[110]) ? lbc_cdm_data[21:16] : pl_reg_202[5:0];
      // {pl_reg_201 , pl_reg_200} specify rxvalid value, default all active
      pl_reg_201        <= #TP (write_pulse[1] & pl_reg_id[110]) ? lbc_cdm_data[15:8]  : pl_reg_201;
      pl_reg_200        <= #TP (write_pulse[0] & pl_reg_id[110]) ? lbc_cdm_data[7:0]   : pl_reg_200;
    end
end


wire [15:0] int_cfg_lpbk_rxvalid = {pl_reg_201,pl_reg_200};
assign cfg_pipe_loopback        = pl_reg_203[7];
assign cfg_rxstatus_lane        = pl_reg_202[5:0];
assign cfg_rxstatus_value       = pl_reg_203[2:0];
assign cfg_lpbk_rxvalid         = int_cfg_lpbk_rxvalid[NL-1:0];

//------------------------------------------------------------------------------
// DBI Read Only Write Enable
// Default Target
// UR CA Error Mask for Target 1
// Also simplified replay timer enable
// cpl_reg_id       - 111 (offset 0x1bc)
// Length           - 1 byte
// Default value    - `CX_DBI_RO_WR_EN
// Core register    - {pl_reg_246, pl_reg_245, pl_reg_205, pl_reg_204}
// -----------------------------------------------------------------------------

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_204             <= #TP {1'b0, 1'b1, ARI_DEVICE_NUM, 1'b0,  SIMPLIFIED_REPLAY_TIMER_GEN4, `CX_MASK_UR_CA_4_TRGT1, `DEFAULT_TARGET, `CX_DBI_RO_WR_EN};
      {pl_reg_245[1:0], pl_reg_205} <= #TP `CONFIG_LIMIT;
      {pl_reg_245[3:2]}      <= #TP `TARGET_ABOVE_CONFIG_LIMIT;
      {pl_reg_245[7:4]}      <= #TP {1'b0, `CX_PL_WIRE_WR_DISABLE, P2P_ENABLE, 1'b0}; // bit [6] is PORT_LOGIC_WR_DISABLE
      pl_reg_246             <= #TP 8'b0;
    end
    else begin
      // dbi_ro_wr_en
      pl_reg_204[0]     <= #TP (app_dbi_ro_wr_disable) ? 1'b0 : (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[0] : pl_reg_204[0];
      pl_reg_204[1]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[1] : pl_reg_204[1];
      pl_reg_204[2]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[2] : pl_reg_204[2];
      pl_reg_204[3]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[3] : pl_reg_204[3]; //simplified replay timer enable
      pl_reg_204[4]     <= #TP 0;
      pl_reg_204[5]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[5] : pl_reg_204[5]; //ARI Device Number Enable
      pl_reg_204[6]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[6] : pl_reg_204[6]; //cfg_cplq_mng_en
      pl_reg_204[7]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[7] : pl_reg_204[7]; //CFG_TLP_BYPASS_EN_REG
      pl_reg_205        <= #TP (write_pulse[1] & pl_reg_id[111]) ? lbc_cdm_data[15:8] : pl_reg_205; //CONFIG_LIMIT_REG[7:0]
      pl_reg_245[1:0]   <= #TP (write_pulse[2] & pl_reg_id[111]) ? lbc_cdm_data[17:16] : pl_reg_245[1:0];//CONFIG_LIMIT_REG[9:8]
      pl_reg_245[3:2]   <= #TP (write_pulse[2] & pl_reg_id[111]) ? lbc_cdm_data[19:18] : pl_reg_245[3:2];//TARGET_ABOVE_CONFIG_LIMIT_REG
      pl_reg_245[4]     <= #TP (write_pulse[2] & pl_reg_id[111]) ? lbc_cdm_data[20]    : pl_reg_245[4];  //P2P_TRACK_CPL_TO_REG
      pl_reg_245[5]     <= #TP (write_pulse[2] & pl_reg_id[111]) ? lbc_cdm_data[21]    : pl_reg_245[5];  //P2P_ERR_RPT_CTRL
      pl_reg_245[6]     <= #TP (write_pulse[2] & pl_reg_id[111] & lbc_cdm_dbi) ? lbc_cdm_data[22] : pl_reg_245[6];  //PORT_LOGIC_WR_DISABLE
      pl_reg_245[7]     <= #TP 1'b0;
      pl_reg_246[0]     <= #TP 1'b0;
      pl_reg_246[7:1]   <= #TP 7'b0;
    end
end



assign dbi_ro_wr_en = pl_reg_204[0];
assign default_target =
                        pl_reg_204[1];
assign ur_ca_mask_4_trgt1 =
                            pl_reg_204[2];
  assign cfg_cfg_tlp_bypass_en = pl_reg_204[7];
  assign cfg_config_limit                = {pl_reg_245[1:0], pl_reg_205};
  assign cfg_target_above_config_limit   = pl_reg_245[3:2];
  assign cfg_p2p_track_cpl_to            = pl_reg_245[4];
  assign cfg_p2p_err_rpt_ctrl            = pl_reg_245[5];
  assign cfg_pl_wr_disable               = pl_reg_245[6];



//------------------------------------------------------------------------------
// Multi Lane Control
// cpl_reg_id       - 112 (offset 0x1c0)
// Length           - 4 byte
// Default value    - 0x0000_0080
// Core register    - {24'h0, pl_reg_mult_0}
// -----------------------------------------------------------------------------

`define DEFAULT_TARGET_LINK_WIDTH         6'h0
`define DEFAULT_DIRECT_LINK_WIDTH_CHANGE  1'b0

assign cfg_pl_multilane_control = pl_reg_mult_0[7:0];

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
      pl_reg_mult_0[5:0]            <= #TP `DEFAULT_TARGET_LINK_WIDTH;
      pl_reg_mult_0[6]              <= #TP `DEFAULT_DIRECT_LINK_WIDTH_CHANGE;
    end
    else begin
      pl_reg_mult_0[5:0]            <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 6'h0 : (write_pulse[0] & pl_reg_id[112]) ? lbc_cdm_data[5:0] : pl_reg_mult_0[5:0] ;
      pl_reg_mult_0[6]              <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 1'b0 : smlh_dir_linkw_chg_rising_edge ? 1'b0 : (write_pulse[0] & pl_reg_id[112]) ? lbc_cdm_data[6] : pl_reg_mult_0[6] ;
    end
end

// spyglass disable_block W552
// SMD: Bus 'pl_reg_mult_0' is driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_mult_0[7]              <= #TP `DEFAULT_UPCONFIGURE_SUPPORT;
    end
    else begin
      pl_reg_mult_0[7]              <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 1'b0 : (write_pulse[0] & pl_reg_id[112]) ? lbc_cdm_data[7] : pl_reg_mult_0[7] ;
    end
end
// spyglass enable_block W552


//------------------------------------------------------------------------------
// PHY InterOp Control
// cpl_reg_id       - 113 (offset 0x1c4)
// Length           - 4 byte
// Default value    - 
// Core register    - {pl_reg_phyiop_3, pl_reg_phyiop_2, pl_reg_phyiop_1, pl_reg_phyiop_0}
// -----------------------------------------------------------------------------

assign cfg_rxstandby_control = pl_reg_phyiop_0[6:0];

assign cfg_pl_l1_nowait_p1 = pl_reg_phyiop_1[1];
assign cfg_pl_l1_clk_sel = pl_reg_phyiop_1[2];
assign cfg_phy_rst_timer = {pl_reg_phyiop_3[5:0], pl_reg_phyiop_2[7:0], pl_reg_phyiop_1[7:4]};
assign cfg_phy_perst_on_warm_reset = pl_reg_phyiop_3[6];

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_phyiop_0[6:0] <= #TP `CX_RXSTANDBY_CONTROL;  // Rxstandby Control
      pl_reg_phyiop_0[7]   <= #TP 0;                      // Reserved
      pl_reg_phyiop_1[3:0] <= #TP 0;                      // 
     {pl_reg_phyiop_3[5:0], pl_reg_phyiop_2[7:0], pl_reg_phyiop_1[7:4]} <= #TP PHY_RST_TIMER; // Timer for PHY rst
      pl_reg_phyiop_3[6]   <= #TP DEFAULT_PHY_PERST_ON_WARM_RESET;
      pl_reg_phyiop_3[7]   <= #TP 0;
    end
    else begin
      pl_reg_phyiop_0[6:0] <= #TP (phy_type == `PHY_TYPE_MPCIE) ? 7'h0 : (write_pulse[0] & pl_reg_id[113]) ? lbc_cdm_data[6:0] : pl_reg_phyiop_0[6:0];
      pl_reg_phyiop_0[7]   <= #TP 0;
      pl_reg_phyiop_1[1]   <= #TP pl_reg_id[113] & write_pulse[1] ? lbc_cdm_data[9] : pl_reg_phyiop_1[1];

      pl_reg_phyiop_1[0]   <= #TP 0; 
      pl_reg_phyiop_1[2]   <= #TP pl_reg_id[113] & write_pulse[1] ? lbc_cdm_data[10] : pl_reg_phyiop_1[2];
      pl_reg_phyiop_1[3] <= #TP 0;
      // writes to cfg_phy_rst_timer registers
      pl_reg_phyiop_1[7:4] <= #TP pl_reg_id[113] & write_pulse[1] ? lbc_cdm_data[15:12] : pl_reg_phyiop_1[7:4];
      pl_reg_phyiop_2[7:0] <= #TP pl_reg_id[113] & write_pulse[2] ? lbc_cdm_data[23:16] : pl_reg_phyiop_2[7:0];
      pl_reg_phyiop_3[5:0] <= #TP pl_reg_id[113] & write_pulse[3] ? lbc_cdm_data[29:24] : pl_reg_phyiop_3[5:0];
      pl_reg_phyiop_3[6]   <= #TP pl_reg_id[113] & write_pulse[3] ? lbc_cdm_data[30] : pl_reg_phyiop_3[6];
      pl_reg_phyiop_3[7]   <= #TP 0;
    end
end

//------------------------------------------------------------------------------
// PHY InterOp Control 2
// cpl_reg_id       - 114 (offset 0x44c)
// Length           - 4 byte
// Default value    - 
// Core register    - {pl_reg_phyiop_ctrl2_3, pl_reg_phyiop_ctrl2_2, pl_reg_phyiop_ctrl2_1, pl_reg_phyiop_ctrl2_0}
// -----------------------------------------------------------------------------

assign cfg_pma_phy_rst_delay_timer = pl_reg_phyiop_ctrl2_0[5:0];

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_phyiop_ctrl2_0[5:0] <= #TP PMA_PIPE_RST_DELAY_TIMER;  // PMA reset and PIPE reset delay timer
      pl_reg_phyiop_ctrl2_0[7:6] <= #TP 0;                         // Reserved
      pl_reg_phyiop_ctrl2_1[7:0] <= #TP 0;                         // Reserved
      pl_reg_phyiop_ctrl2_2[7:0] <= #TP 0;                         // Reserved
      pl_reg_phyiop_ctrl2_3[7:0] <= #TP 0;                         // Reserved
    end
    else begin
      pl_reg_phyiop_ctrl2_0[7:0] <= #TP pl_reg_id[ID_0x44C] & write_pulse[0] ? lbc_cdm_data[7:0] : pl_reg_phyiop_ctrl2_0[7:0];
      pl_reg_phyiop_ctrl2_0[7:6] <= #TP 0;
      pl_reg_phyiop_ctrl2_1[7:0] <= #TP 0;
      pl_reg_phyiop_ctrl2_2[7:0] <= #TP 0;
      pl_reg_phyiop_ctrl2_3[7:0] <= #TP 0;
    end
end


//------------------------------------------------------------------------------
// POWERDOWN_CTRL_STATUS
// cpl_reg_id       - 190 (offset 0x448)
// Length           - 4 byte
// Default value    - 
// Core register    - {16'h0000, pm_powerdown_status, 3'b000, cfg_force_powerdown} 
// -----------------------------------------------------------------------------
// toggle the force powerdown bit
assign int_force_powerdown = write_pulse[0] && pl_reg_id[ID_0x448] ? lbc_cdm_data[0] : 1'b0;
assign int_vmain_ack_ctrl_en = write_pulse[0] && pl_reg_id[ID_0x448];

always @(posedge core_clk or negedge sticky_rst_n) begin : powerdown_reg_PROC
  if (!sticky_rst_n) begin
    cfg_force_powerdown <= #TP 1'b0;
    cfg_vmain_ack_ctrl  <= #TP `CX_VMAIN_ACK_CTRL_RST_VALUE;
  end
  else begin
    cfg_force_powerdown <= #TP int_force_powerdown;
    cfg_vmain_ack_ctrl  <= #TP int_vmain_ack_ctrl_en ? lbc_cdm_data[1] : cfg_vmain_ack_ctrl;
  end
end : powerdown_reg_PROC

assign int_powerdown_status = {pm_powerdown_status, 2'b00, cfg_vmain_ack_ctrl, cfg_force_powerdown};











// Target Map registers
    cdm_trgt_map
    
        #(
          .INST(INST))
          u_cdm_trgt_map(
// ------------ Inputs ---------------
        .core_clk               (core_clk),
        .sticky_rst_n           (sticky_rst_n),
        .lbc_cdm_data           (lbc_cdm_data),
        .trgt_map_write_pulse   (write_pulse),
        .trgt_map_reg_id        (trgt_map_reg_id),
// ------------ Outputs --------------
        .trgt_map_reg_data      (trgt_map_reg_data),
        .target_mem_map         (target_mem_map),
        .target_rom_map         (target_rom_map)
    );

//      - ATU UNROLL removes this





// =============================================================================
// Auxiliary Clock register
// =============================================================================
//------------------------------------------------------------------------------
// Auxiliary Clock Frequency Control Register
// Port Logic Offset - `CFG_PL_REG + 0x440 (0xB40)
// pl_reg_id         - 141
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg    [`CX_PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;

always @(posedge core_clk or negedge sticky_rst_n) begin : cfg_pl_aux_clk_freq_PROC
    if (!sticky_rst_n) begin
        cfg_pl_aux_clk_freq <= #TP `DEFAULT_AUX_CLK_FREQ;
    end else begin
        cfg_pl_aux_clk_freq[7:0] <= #TP aux_clk_reg_id & write_pulse[0] ? lbc_cdm_data[7:0] : cfg_pl_aux_clk_freq[7:0];
        cfg_pl_aux_clk_freq[9:8] <= #TP aux_clk_reg_id & write_pulse[1] ? lbc_cdm_data[9:8] : cfg_pl_aux_clk_freq[9:8];
   end
end

assign aux_clk_reg_data = {22'h0, cfg_pl_aux_clk_freq};






//------------------------------------------------------------------------------
// PIPE_RELATED_REG
// Port Logic Offset - `CFG_PL_REG + 0x490 (0xB90)
// pl_reg_id         - 166
// Length            - 4 bytes
// Default value     - 
//------------------------------------------------------------------------------
reg                   reg_pipe_garbage_data_mode;             // [ 8]    PIPE Garbage data mode
wire    [3:0]         cfg_tx_message_bus_write_buffer_depth;  // [ 7: 4] Tx Message Bus Write Buffer Depth
logic   [3:0]         cfg_rx_message_bus_write_buffer_depth;  // [ 3: 0] Rx Message Bus Write Buffer Depth

assign pl_reg_0x490 = {{23{1'b0}},reg_pipe_garbage_data_mode, cfg_tx_message_bus_write_buffer_depth, cfg_rx_message_bus_write_buffer_depth};

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        reg_pipe_garbage_data_mode <= #TP `DEFAULT_PIPE_GARBAGE_DATA_MODE;
    end
    else begin
        reg_pipe_garbage_data_mode <= #TP pl_reg_id[ID_0x490] & write_pulse[1] ? lbc_cdm_data[ 8] : reg_pipe_garbage_data_mode;
   end
end

assign cfg_pipe_garbage_data_mode = reg_pipe_garbage_data_mode
                                 || cfg_pipe_loopback
                                   ;

assign cfg_rx_message_bus_write_buffer_depth = {4{1'b0}};
assign cfg_tx_message_bus_write_buffer_depth = {4{1'b0}};



// =============================================================================
// Flow Control Latency Timer
// =============================================================================
reg     [12:0]  cfg_fc_latency_value;
wire    [12:0]  spec_fc_latency_value;
wire    [12:0]  int_fc_latency_value;
wire    [12:0]  total_fc_delay,queue_pop_time,fcgen_dly,l2_dly;

// subtract 19 out of latency value because this is the PCI Express spec fixed internal delay used
// in "Flow Control Update Frequency" calculation.  This latency(internal delay) is accounted for
// by credits advertised
// subtract 1 because fc latency timer expires at 0 not 1
assign total_fc_delay        = 20;
assign spec_fc_latency_value = get_fc_latency_value(
                                   cfg_min_payload_size
                                 , smlh_autoneg_link_width
                                 );
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: Largest value of spec_fc_latency_value is 4143, min is 48, total_fc_delay is
// a constant, 20. No carry/borrow needed
assign int_fc_latency_value  = (spec_fc_latency_value - total_fc_delay);
// spyglass enable_block W164a

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        cfg_fc_latency_value    <= #TP 0;
    end else if (fc_timer_override) begin
        cfg_fc_latency_value    <= #TP fc_timer_override_val;
    end else begin
        cfg_fc_latency_value    <= #TP int_fc_latency_value;
    end
end

function automatic [12:0] get_fc_latency_value;
    input   [2:0]   cfg_max_payload_size;
    input   [5:0]   smlh_link_mode;

    reg     [5:0]   link_width;
    reg     [2:0]   max_payload;

begin
    // Make sure we optimize things away based on the actual number of lanes
    link_width[0]   =            & smlh_link_mode[0];
    link_width[1]   = (RXNL > 1) & smlh_link_mode[1];
    link_width[2]   = (RXNL > 2) & smlh_link_mode[2];
    link_width[3]   = (RXNL > 4) & smlh_link_mode[3];
    link_width[4]   = (RXNL > 8) & smlh_link_mode[4];
    link_width[5]   = (RXNL >16) & smlh_link_mode[5];

    max_payload     = cfg_max_payload_size;

    case (link_width)

             6'b000001 : case(max_payload)
                        // x1
                        3'b001  :   get_fc_latency_value  = 416 ;  // 256 bytes
                        3'b010  :   get_fc_latency_value  = 559 ;  // 512 bytes
                        3'b011  :   get_fc_latency_value  = 1071;  // 1024 bytes
                        3'b100  :   get_fc_latency_value  = 2095;  // 2048 bytes
                        3'b101  :   get_fc_latency_value  = 4143;  // 4096 bytes
                        default :   get_fc_latency_value  = 237 ;  // 128 bytes   3'b000
                    endcase

             6'b000010 : case(max_payload)
                        //  x2
                        3'b001  :   get_fc_latency_value  = 217 ;  // 256 bytes
                        3'b010  :   get_fc_latency_value  = 289 ;  // 512 bytes
                        3'b011  :   get_fc_latency_value  = 545 ;  // 1024 bytes
                        3'b100  :   get_fc_latency_value  = 1057;  // 2048 bytes
                        3'b101  :   get_fc_latency_value  = 2081;  // 4096 bytes
                        default :   get_fc_latency_value  = 128 ;  // 128 bytes   3'b000
                    endcase

             6'b000100 : case(max_payload)
                        //  x4
                        3'b001  :   get_fc_latency_value  = 118 ;  // 256 bytes
                        3'b010  :   get_fc_latency_value  = 154 ;  // 512 bytes
                        3'b011  :   get_fc_latency_value  = 282 ;  // 1024 bytes
                        3'b100  :   get_fc_latency_value  = 538 ;  // 2048 bytes
                        3'b101  :   get_fc_latency_value  = 1050;  // 4096 bytes
                        default :   get_fc_latency_value  = 73  ;  // 128 bytes   3'b000
                    endcase

             default :   case(max_payload)
                        //  Error on the side of more frequent updates
                        3'b000  :   get_fc_latency_value  = 48  ;  // 128 bytes
                        3'b001  :   get_fc_latency_value  = 72  ;  // 256 bytes
                        3'b010  :   get_fc_latency_value  = 86  ;  // 512 bytes
                        3'b011  :   get_fc_latency_value  = 150 ;  // 1024 bytes
                        3'b100  :   get_fc_latency_value  = 278 ;  // 2048 bytes
                        3'b101  :   get_fc_latency_value  = 534 ;  // 4096 bytes
                        default :   get_fc_latency_value  = 48  ;  // 128 bytes
                    endcase
    endcase
end
endfunction





//------------------------------------------------------------------------------
// VDM Traffic during non-D0 states: PCIMPM_TRAFFIC_CTRL
// Port Logic Offset - `CFG_PL_REG + 0x41C 
// pl_reg_id         - ID_0x41C
// Length            - 1 byte
// Default value     -
//------------------------------------------------------------------------------
reg    cfg_nond0_vdm_block;
reg    cfg_client0_block_new_tlp;
reg    cfg_client1_block_new_tlp;
reg    cfg_client2_block_new_tlp;

assign pl_reg_0x41C = {4'b0000,            
                       cfg_client2_block_new_tlp,cfg_client1_block_new_tlp,cfg_client0_block_new_tlp,cfg_nond0_vdm_block};   // 0x41C

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_nond0_vdm_block        <= #TP `CX_BLOCK_VDM_TLP;
        cfg_client0_block_new_tlp  <= #TP `CX_CLIENT0_BLOCK_NEW_TLP;
        cfg_client1_block_new_tlp  <= #TP `CX_CLIENT1_BLOCK_NEW_TLP;
        cfg_client2_block_new_tlp  <= #TP `CX_CLIENT2_BLOCK_NEW_TLP;
    end else begin
        cfg_nond0_vdm_block        <= #TP (write_pulse[0] & pl_reg_id[ID_0x41C]) ? lbc_cdm_data[0]   : cfg_nond0_vdm_block;
        cfg_client0_block_new_tlp  <= #TP (write_pulse[0] & pl_reg_id[ID_0x41C]) ? lbc_cdm_data[1]   : cfg_client0_block_new_tlp;
        cfg_client1_block_new_tlp  <= #TP (write_pulse[0] & pl_reg_id[ID_0x41C]) ? lbc_cdm_data[2]   : cfg_client1_block_new_tlp;
        cfg_client2_block_new_tlp  <= #TP (write_pulse[0] & pl_reg_id[ID_0x41C]) ? lbc_cdm_data[3]   : cfg_client2_block_new_tlp;
    end
end







endmodule
