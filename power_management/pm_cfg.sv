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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_cfg.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module manages the interface between the power management circuitry
// --- and the configuration space CDM.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_cfg
  // Parameters
  #(
    parameter TP = `TP,
    parameter INST = 0,
    parameter NL = `CX_NL,
    parameter L0S_LATENCY_TIMER_WD = 3,
    parameter L1_LATENCY_TIMER_WD = 3,
    parameter NF = 1,
    parameter ASLK_CTRL_WD = (NF * 2),
    parameter NVF = 1,
    parameter BUS_NUM_WD = 1,
    parameter DEV_NUM_WD = 1,
    parameter UPD_REQ_ID_WD = 1,
    parameter PL_AUX_CLK_FREQ_WD = 1,
    parameter DEFAULT_PHY_PERST_ON_WARM_RESET = `DEFAULT_PHY_PERST_ON_WARM_RESET,
    parameter PHY_RST_TIMER_VAL = `CX_PHY_RST_TIMER,
    parameter PMA_PIPE_RST_DELAY_TIMER_VAL = `CX_PMA_PIPE_RST_DELAY_TIMER,
    parameter NFUNC_WD = 1
  )
  (
  // Inputs
  input                                   en_iso,
  input                                   aux_clk,                    // clock
  input                                   pwr_rst_n,                  // power on reset
  input                                   perst_n,                    // power good indication or fundamental reset request
  input                                   pm_hold,                    // Hold signal from power management circuit active in L1.2
  input                                   pm_hold_perst,                 // Hold signal from power management circuit active in L2
  input                                   pm_update,                  // Update signal from power management circuit active in L1.2
  input                                   pm_update_perst,               // Update signal from power management circuit active in L2
  input [(L0S_LATENCY_TIMER_WD - 1) : 0]  cfg_l0s_entr_latency_timer, // L0S entry latency timer
  input [(L1_LATENCY_TIMER_WD - 1) : 0]   cfg_l1_entr_latency_timer,  // L1 entry latency timer
  input                                   cfg_l1_entr_wo_rl0s,        // allow L1 entry without receiver in L0S
  input [(ASLK_CTRL_WD - 1) : 0]          cfg_aslk_pmctrl,            // active state link pm control
  input                                   cfg_upd_aspm_ctrl,          // Update ASPM register
  input [(NF - 1) : 0]                    cfg_upd_aslk_pmctrl,        // Update ASLK register
  input [(NF - 1) : 0]                    cfg_aux_pm_en,              // AUX pm enable
  input [(NF - 1) : 0]                    cfg_pme_en,                 // PME enable
  input [7 : 0]                           cfg_pbus_num,               // Bus number
  input [4 : 0]                           cfg_pbus_dev_num,           // Device number width
  input [(NF - 1) : 0]                    cfg_upd_aux_pm_en,          // Update cfg_aux_pm_en
  input [(NF - 1) : 0]                    cfg_upd_pmcsr,              // CDM pmcsr register updated
  input [(UPD_REQ_ID_WD - 1) : 0]         cfg_upd_req_id,             // Update bus and device numbers 
  input [((5*NF) - 1) : 0]                cfg_pme_cap,                // PME capability
  input [(NF - 1) : 0]                    cfg_upd_pme_cap,            // Update PME capability
  input                                   pm_core_rst_done,           // Rising edge detect of core_rst_n
  input                                   pm_active_state,            // Active state of PMU FSM
  input [((3*NF) - 1) : 0]                cfg_pmstate,                // PM state (D-state)
  input                                   cfg_clk_pm_en,              // CLK PM EN used to allow ref_clk to PHY to be disabled
  input                                   cfg_pl_l1_nowait_p1,        // L1 entry mode port logic bit
  input                                   cfg_pl_l1_clk_sel,          // L1 aux_clk source select (1 => core_clk, 0 => auxclk)
  input                                   cfg_phy_perst_on_warm_reset,
  input [17:0]                            cfg_phy_rst_timer, 
  input [5:0]                             cfg_pma_phy_rst_delay_timer, 
  input [(PL_AUX_CLK_FREQ_WD - 1) : 0]    cfg_pl_aux_clk_freq,        // Aux clock frequency
  input                                   upstream_port,
  input [5:0]                             cfg_link_capable,           // PL LINK_CAPABLE register, indicate used lanes at reset
  // Outputs
  output wire [(L0S_LATENCY_TIMER_WD - 1) : 0]  pm_cfg_l0s_entr_latency_timer,  // L0S entry latency timer registered in aux_clk domain
  output wire [(L1_LATENCY_TIMER_WD - 1) : 0]   pm_cfg_l1_entr_latency_timer,   // L1 entry latency timer registered in aux_clk domain
  output wire                                   pm_cfg_l1_entr_wo_rl0s,         // control bit to allow L1 entry without receiver L0S
  output wire [(ASLK_CTRL_WD - 1) : 0]          pm_cfg_aslk_pmctrl,             // Active state link pm control
  output wire [(NF - 1) : 0]                    pm_cfg_aux_pm_en,               // AUX pm enable
  output wire [(NF - 1) : 0]                    pm_cfg_pme_en,                  // PME enable
  output wire [(BUS_NUM_WD - 1) : 0]            pm_cfg_pbus_num,                // Bus number
  output wire [(DEV_NUM_WD - 1) : 0]            pm_cfg_pbus_dev_num,            // Bus number
  output wire [((5*NF) - 1) : 0]                pm_cfg_pme_cap,                 // PME capabilities
  output wire [((3*NF) - 1) : 0]                pm_cfg_pmstate,                 // PM state
  output wire                                   pm_cfg_clk_pm_en,               // CLK PM enable
  output wire                                   pm_cfg_pl_l1_nowait_p1,         // PL l1 entry mode
  output wire                                   pm_cfg_pl_l1_clk_sel,           // PL L1 clock gating mode
  output wire                                   pm_phy_perst_on_warm_reset,     // PMC drive pm_req_phy_perst when warm reset
  output wire [(PL_AUX_CLK_FREQ_WD - 1) : 0]    pm_cfg_pl_aux_clk_freq          // Aux clock frequency
  ,
  output wire                                   pm_upstream_port
  ,output wire [5:0]                            pm_link_capable
  ,output wire [17:0]                           pm_phy_rst_timer
  ,output wire [5:0]                            pm_pma_phy_rst_delay_timer
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
parameter   L0S_ENTRY_RST_VAL = `DEFAULT_L0S_ENTR_LATENCY;
parameter   L1_ENTRY_RST_VAL = `DEFAULT_L1_ENTR_LATENCY;
parameter   AUX_CLK_FREQ_RST_VAL = `DEFAULT_AUX_CLK_FREQ;
localparam  DOUNIT = 3'b100;
localparam  NINST = 1;

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire int_l1_or_l2_hold_s;
wire int_l1_or_l2_update_s;
wire int_hold_pmstate_s;

// ----------------------------------------------------------------------------
// Shadow registers that update on CDM write hold value during power gating
// Note these shadow registers are also update when the core is reset
// ----------------------------------------------------------------------------
shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0),
        .RESET_VALUE        (L0S_ENTRY_RST_VAL),
        .WIDTH              (L0S_LATENCY_TIMER_WD)
    ) u_l0s_entr_latency_timer_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (pm_core_rst_done | cfg_upd_aspm_ctrl),
    .data        (cfg_l0s_entr_latency_timer),
    // Outputs
    .shadow_data (pm_cfg_l0s_entr_latency_timer)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0),
        .RESET_VALUE        (L1_ENTRY_RST_VAL),
        .WIDTH              (L1_LATENCY_TIMER_WD)
    ) u_l1_entr_latency_timer_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (pm_core_rst_done | cfg_upd_aspm_ctrl),
    .data        (cfg_l1_entr_latency_timer),
    // Outputs
    .shadow_data (pm_cfg_l1_entr_latency_timer)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0)
    ) u_l1_entr_wo_rl0s_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (pm_core_rst_done | cfg_upd_aspm_ctrl),
    .data        (cfg_l1_entr_wo_rl0s),
    // Outputs
    .shadow_data (pm_cfg_l1_entr_wo_rl0s)
);

genvar nf;
generate
for (nf=0; nf<NF; nf=nf+1)
begin: gen_pm_aslk_shadow
shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0),
        .WIDTH              (ASLK_CTRL_WD/NF)
    ) u_aslk_pmctrl_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (pm_core_rst_done | cfg_upd_aslk_pmctrl[nf]),
    .data        (cfg_aslk_pmctrl[(nf*(ASLK_CTRL_WD/NF) + (ASLK_CTRL_WD/NF) - 1) : (nf*(ASLK_CTRL_WD/NF))]),
    // Outputs
    .shadow_data (pm_cfg_aslk_pmctrl[(nf*(ASLK_CTRL_WD/NF) + (ASLK_CTRL_WD/NF) - 1) : (nf*(ASLK_CTRL_WD/NF))])
);
end
endgenerate // gen_pm_aslk_shadow

// ----------------------------------------------------------------------------
// Registers that update on CDM access otherwise hold their value
// ----------------------------------------------------------------------------
shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0)
    ) u_aux_pm_en_shadow [(NF - 1) : 0] (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (1'b0),
    .update      (cfg_upd_aux_pm_en),
    .data        (cfg_aux_pm_en),
    // Outputs
    .shadow_data (pm_cfg_aux_pm_en)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0)
    ) u_pme_en_shadow [(NF - 1) : 0] (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (cfg_upd_pmcsr),
    .data        (cfg_pme_en),
    // Outputs
    .shadow_data (pm_cfg_pme_en)
);


shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0),
        .DIS_SHADOW_MUX     (1'b1),
        .WIDTH              (8)
    ) u_bus_num_shadow [(NINST - 1) : 0] (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (cfg_upd_req_id),
    .data        (cfg_pbus_num),
    // Outputs
    .shadow_data (pm_cfg_pbus_num)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0),
        .DIS_SHADOW_MUX     (1'b1),
        .WIDTH              (5)
    ) u_pbus_dev_num_shadow [(NINST - 1) : 0] (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (cfg_upd_req_id),
    .data        (cfg_pbus_dev_num),
    // Outputs
    .shadow_data (pm_cfg_pbus_dev_num)
);

// ----------------------------------------------------------------------------
// PME Capabilities
// ----------------------------------------------------------------------------
pm_cfg_pme

  // Parameters
  #(
    .INST     (1'b0),
    .NF       (NF),
    .NVFUNC   (NVF),
    .NFUNC_WD (NFUNC_WD)
  ) u_pm_cfg_pme (
  // Inputs
  .aux_clk            (aux_clk),
  .pwr_rst_n          (pwr_rst_n),
  .cfg_upd_pme_cap    (cfg_upd_pme_cap),
  .cfg_pme_cap        (cfg_pme_cap),
  .pm_core_rst_done   (pm_core_rst_done),
  .pm_active_state    (pm_active_state),
  // Outputs
  .pm_cfg_pme_cap     (pm_cfg_pme_cap)
);

// ----------------------------------------------------------------------------
// Registers updated before power-gating and held during power-gating
// ----------------------------------------------------------------------------
assign int_l1_or_l2_update_s = pm_update || pm_update_perst;
assign int_l1_or_l2_hold_s   = pm_hold   || pm_hold_perst;
assign int_hold_pmstate_s = !perst_n || int_l1_or_l2_hold_s 
                            ;


shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .WIDTH              (3*NF),
        .RESET_VALUE        ({NF{DOUNIT}})
    ) u_pmstate_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_pmstate_s),
    .update      (perst_n),
    .data        (cfg_pmstate),
    // Outputs
    .shadow_data (pm_cfg_pmstate)
);


shadow_reg

    // Parameters
    #(
        .INST (1'b0)
    ) u_clk_pm_en_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (perst_n),
    .data        (cfg_clk_pm_en),
    // Outputs
    .shadow_data (pm_cfg_clk_pm_en)
);


shadow_reg

    // Parameters
    #(
        .INST   (1'b0)
    ) u_pl_l1_nowait_p1_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (int_l1_or_l2_update_s),
    .data        (cfg_pl_l1_nowait_p1),
    // Outputs
    .shadow_data (pm_cfg_pl_l1_nowait_p1)
);

shadow_reg

    // Parameters
    #(
        .INST   (1'b0)
    ) u_pl_l1_clk_sel_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (int_l1_or_l2_update_s),
    .data        (cfg_pl_l1_clk_sel),
    // Outputs
    .shadow_data (pm_cfg_pl_l1_clk_sel)
);



shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .RESET_VALUE        (PHY_RST_TIMER_VAL),
        .WIDTH              (18)
    ) u_phy_rst_timer_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_pmstate_s),
    .update      (perst_n),
    .data        (cfg_phy_rst_timer),
    // Outputs
    .shadow_data (pm_phy_rst_timer)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .RESET_VALUE        (PMA_PIPE_RST_DELAY_TIMER_VAL),
        .WIDTH              (6)
    ) u_pma_phy_rst_delay_timer_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_pmstate_s),
    .update      (perst_n),
    .data        (cfg_pma_phy_rst_delay_timer),
    // Outputs
    .shadow_data (pm_pma_phy_rst_delay_timer)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .RESET_VALUE        (DEFAULT_PHY_PERST_ON_WARM_RESET)
    ) u_phy_perst_on_warm_reset_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_pmstate_s),
    .update      (perst_n),
    .data        (cfg_phy_perst_on_warm_reset),
    // Outputs
    .shadow_data (pm_phy_perst_on_warm_reset)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .WIDTH              (PL_AUX_CLK_FREQ_WD),
        .RESET_VALUE        (AUX_CLK_FREQ_RST_VAL)
    ) u_pl_aux_clk_freq_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (int_l1_or_l2_update_s),
    .data        (cfg_pl_aux_clk_freq),
    // Outputs
    .shadow_data (pm_cfg_pl_aux_clk_freq)
);



shadow_reg

#(.INST (INST)) u_usp_shadow_reg (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (1'b1),
    .hold_data      (int_hold_pmstate_s),
    .update         (perst_n),
    .data           (upstream_port),
    // Outputs
    .shadow_data    (pm_upstream_port)
);

shadow_reg

#(.INST (INST),
  .WIDTH (6),
  .EN_HOLD_BYPASS_MUX (1'b0),
  .RESET_VALUE        (`DEFAULT_LINK_CAPABLE)
) u_link_capable_shadow_reg (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (1'b1),
    .hold_data      (int_hold_pmstate_s),
    .update         (perst_n),
    .data           (cfg_link_capable),
    // Outputs
    .shadow_data    (pm_link_capable)
);

endmodule
