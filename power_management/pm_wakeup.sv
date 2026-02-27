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
// ---    $DateTime: 2020/09/18 02:33:28 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_wakeup.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains the logic to generate wakeup conditions from
// --- L1 link state and power gating state
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_wakeup
    // Parameters
    #( 
    parameter TP = `TP,
    parameter INST = 0,
    parameter NF = 1,
    parameter NVC = 1,
    parameter CPL_LUT_DEPTH = 1,
    parameter PM_SYNC_DEPTH  = 2,
    parameter NVC_XALI_EXP  = `CX_NVC_XALI_EXPANSION
    )
    (
    // Inputs
    input                 aux_clk, // clock
    input                 pwr_rst_n, // power on reset
    input                 dbi_cs, // DBI chip select
    input [NVC_XALI_EXP-1:0] client0_tlp_hv, // client header valid
    input [NVC_XALI_EXP-1:0] client1_tlp_hv, // client header valid
    input                 brdg_slv_xfer_pending, // AXI Slave transfer pending
    input                 edma_xfer_pending, // DMA pending indication
    input                 pm_radm_idle_n, // RADM not idle indication 
    input                 lbc_active, // LBC is processing a non-posted request
    input                 pm_trgt_cpl_lut_empty_n, // TX path CPL LUT is not empty
    input                 app_xfer_pending, // application transfer pending
    input                 upstream_port, // indicates device is USP
    input                 cfg_link_dis, // link disable
    input                 cfg_link_retrain, // link retrain
    input                 cfg_lpbk_en, // loopback enabled
    input                 cfg_2nd_reset, // hot reset request
    input                 cfg_plreg_reset, // hot reset request
    input                 cfg_directed_speed_change, // directed speed change
    input                 cfg_directed_width_change, // directed up/down configure
    input                 ven_msg_req, // vendor Message request
    input                 ven_msi_req, // vendor MSI request
    input                 app_init_rst, // application requests hot reset
    input                 app_ltr_msg_req, // application requests LTR message
    input                 app_unlock_msg, // application requests unlock message
    input                 msg_gen_unlock_grant, // Unlock message is granted
    input                 smlh_link_up, // Link is up
    input                 pm_req_iso_vmain_to_vaux, // Isolation enabled
    input                 pm_linkst_in_l1, // Link is in L1
    input                 pm_l1_in_progress, // L1 negotiation in progress
    input                 brdg_dbi_xfer_pending, // dbi transfer pending in bridge
    input                 smlh_link_in_training, // LTSSM in training
    input                 pm_en_aux_clk_g, // aux clock enable for CDM
    input                 msg_gen_hv,
    input                 lbc_cpl_hv,
    input                 xadm_tlp_pending,
    input                 xtlh_tlp_pending,
    input                 xdlh_tlp_pending,
    // Outputs
    output                pm_wake_init_rst, // latched version of app_init_rst
    output reg            pm_wake_unlock_msg_req, // latched version of app_unlock_msg
    output                pm_wake_l1_pg_exit, // request l1 power gating wakeup
    output                pm_wake_l1_pg_ack, // power gating can proceed
    output                pm_wake_xfer_pending, // xfer pendig wakeup from L1 resets ASPM timers
    output                pm_wake_l1_exit, // L1 exit request no effect on ASPM timers
    output                pm_wake_dbi_pending, // DBI transfer pending indication
    output reg            pm_wake_block_pg // Block power gating transition in L1 due to pending transfer or LTSSM sequence
    ,
    output reg            pm_smlh_link_retrain, // request to LTSSM to do link retrain
    output reg            pm_wake_req_exit_l0s, // tlp pending to be sent at the XADM interface so exit L0S
    output                pm_wake_tlp_pending // TLP pending in the transmit datapath
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
localparam          SYNC_WIDTH  = 1;
localparam          RST_VAL     = 0;

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire                    int_sync_slv_awvalid_s;
wire                    int_sync_slv_arvalid_s;
wire                    int_sync_slv_wvalid_s;
wire                    int_sync_dbi_arvalid_s;
wire                    int_sync_dbi_awvalid_s;
wire                    int_sync_dbi_wvalid_s;
wire                    int_dbi_exit_s;
wire                    int_slv_exit_s;
wire                    int_dbi_or_slv_exit_s;
wire                    int_brdg_pg_exit_s;
wire                    int_l1_pg_exit_native_s;
wire                    int_l1_exit_native_s;
wire                    int_client_req_exit_l1_s;
wire                    int_req_exit_l0s_s; // tlp pending to be sent so exit L0S
wire                    int_init_rst_s;
wire                    int_link_down_s;
wire                    int_unlock_msg_req_s;
wire                    int_msg_req_s;
wire                    int_cfg_exit_s;
wire                    int_cfg_or_msg_exit_s;
wire                    int_dsp_init_rst_s;
wire                    int_set_block_pg_s;
wire                    int_block_pg_s;
wire                    int_cfg_speed_chg_re_s;
wire                    int_cfg_speed_flag_s;
wire                    int_link_retrain_s;
wire                    int_smlh_link_retrain_s;

// ----------------------------------------------------------------------------
// Reg Declarations
// ----------------------------------------------------------------------------
reg                 int_client_req_exit_l1_r;
reg                 int_dbi_or_slv_exit_r;
reg                 int_cfg_or_msg_exit_r;
reg                 int_init_rst_r;
reg                 int_ltr_msg_req_r;
reg                 int_cfg_dir_speed_chg_r;
reg                 int_cfg_speed_flag_r;
reg                 int_link_retrain_r;

// ----------------------------------------------------------------------------
// BCM synchronizers
// ----------------------------------------------------------------------------
assign int_sync_slv_awvalid_s = 1'b0;
assign int_sync_slv_arvalid_s = 1'b0;
assign int_sync_slv_wvalid_s = 1'b0;

assign int_sync_dbi_awvalid_s = 1'b0;
assign int_sync_dbi_arvalid_s = 1'b0;
assign int_sync_dbi_wvalid_s = 1'b0;

assign int_dbi_exit_s = (int_sync_dbi_awvalid_s || int_sync_dbi_arvalid_s || int_sync_dbi_wvalid_s);
assign int_slv_exit_s = (int_sync_slv_awvalid_s || int_sync_slv_arvalid_s || int_sync_slv_wvalid_s);
assign int_dbi_or_slv_exit_s = int_dbi_exit_s || int_slv_exit_s;

// trigger exit from L0S if any of the interfaces header valids are active
// this is necessary for L0S since the core_clk is running in L0S and so any
// of the interfaces to the XADM could become pending
assign int_req_exit_l0s_s = |client0_tlp_hv
                            || |client1_tlp_hv
                            || msg_gen_hv
                            || lbc_cpl_hv;

always @(posedge aux_clk or negedge pwr_rst_n)
begin
  if(!pwr_rst_n) begin
    int_dbi_or_slv_exit_r <= #TP 1'b0;
    pm_wake_req_exit_l0s  <= #TP 1'b0;
  end else begin
    int_dbi_or_slv_exit_r <= #TP int_dbi_or_slv_exit_s;
    pm_wake_req_exit_l0s  <= #TP int_req_exit_l0s_s;
  end
end

assign int_brdg_pg_exit_s = int_dbi_or_slv_exit_r && int_dbi_or_slv_exit_s;

assign pm_wake_tlp_pending = xadm_tlp_pending || xtlh_tlp_pending || xdlh_tlp_pending;

// For triggering exit from L1 with native interface we look directly
// at the client interface ports of the controller.
assign int_client_req_exit_l1_s =                                  |client0_tlp_hv
                                  || |client1_tlp_hv
                                  ;

always @(posedge aux_clk or negedge pwr_rst_n)
begin
  if(!pwr_rst_n)
    int_client_req_exit_l1_r <= #TP 1'b0;
  else
    int_client_req_exit_l1_r <= #TP int_client_req_exit_l1_s;
end


assign int_l1_exit_native_s =  1'b0 
                             || int_client_req_exit_l1_r
                          ;

assign int_l1_pg_exit_native_s =   int_l1_exit_native_s
                                  || dbi_cs
; // !DBI_4SLAVE_POPULATED

assign pm_wake_dbi_pending = brdg_dbi_xfer_pending
                                  || dbi_cs
; // !DBI_4SLAVE_POPULATED


// If app_init_rst is toggled during L1 by the application we latch it and provide
// pm_wake_init_rst to the LTSSM until the link down
assign int_dsp_init_rst_s = app_init_rst && pm_l1_in_progress;
// link is down when isolation has been removed and LTSSM has transitioned to hot reset
assign int_link_down_s = !pm_req_iso_vmain_to_vaux && !smlh_link_up;
assign int_init_rst_s = (int_link_down_s ? 1'b0 : (int_dsp_init_rst_s ? 1'b1 : int_init_rst_r));
// pm_init_rst will either be the normal app_init_rst pulse or driven by
// the latched version during L1
assign pm_wake_init_rst = app_init_rst || int_init_rst_r;

// app_unlock_msg_req is toggled by the application we latch it and provide
// pm_wake_unlock_msg_req to the LTSSM until msg_gen grants the LTR message
assign int_unlock_msg_req_s = (msg_gen_unlock_grant ? 1'b0 : (app_unlock_msg ? 1'b1 : pm_wake_unlock_msg_req));
// vendor message or msi message request
assign int_msg_req_s = ven_msg_req || ven_msi_req;

// For directed speed change a rising edge detect is performed since the
// default value of this bit can be 1. If the rising edge is detected
// during L1 entry a flag is set and only cleared when L1 entry is no
// longer in progress.
assign int_cfg_speed_chg_re_s = !int_cfg_dir_speed_chg_r && cfg_directed_speed_change && pm_l1_in_progress;
assign int_cfg_speed_flag_s = (int_cfg_speed_chg_re_s ? 1'b1 : (!pm_l1_in_progress ? 1'b0 : int_cfg_speed_flag_r));

// create the link retrain flag to trigger L1 exit
assign int_link_retrain_s = ((pm_l1_in_progress && cfg_link_retrain) ? 1'b1 : (smlh_link_in_training ? 1'b0 : int_link_retrain_r));
assign int_smlh_link_retrain_s = int_link_retrain_r ? 1'b1 : cfg_link_retrain;

// Configuration access that cause L1 exit
assign int_cfg_exit_s = ((!upstream_port && (cfg_link_dis || int_link_retrain_r || cfg_2nd_reset || cfg_plreg_reset))
                        || (cfg_lpbk_en || int_cfg_speed_flag_s || cfg_directed_width_change));
assign int_cfg_or_msg_exit_s = int_msg_req_s || int_cfg_exit_s || msg_gen_hv || lbc_cpl_hv;


always @(posedge aux_clk or negedge pwr_rst_n)
begin : l1_exit_PROC
  if(!pwr_rst_n)
  begin
    int_init_rst_r                  <= #TP 1'b0;
    int_ltr_msg_req_r               <= #TP 1'b0;
    pm_wake_unlock_msg_req          <= #TP 1'b0;
    int_cfg_or_msg_exit_r           <= #TP 1'b0;
    pm_wake_block_pg                <= #TP 1'b0;
    int_cfg_dir_speed_chg_r         <= #TP 1'b0;
    int_cfg_speed_flag_r            <= #TP 1'b0;
    int_link_retrain_r              <= #TP 1'b0;
    pm_smlh_link_retrain            <= #TP 1'b0;
  end
  else
  begin
    int_init_rst_r                  <= #TP int_init_rst_s;
    int_ltr_msg_req_r               <= #TP app_ltr_msg_req;
    pm_wake_unlock_msg_req          <= #TP int_unlock_msg_req_s;
    int_cfg_or_msg_exit_r           <= #TP int_cfg_or_msg_exit_s;
    pm_wake_block_pg                <= #TP int_block_pg_s;
    int_cfg_dir_speed_chg_r         <= #TP cfg_directed_speed_change;
    int_cfg_speed_flag_r            <= #TP int_cfg_speed_flag_s;
    int_link_retrain_r              <= #TP int_link_retrain_s;
    pm_smlh_link_retrain            <= #TP int_smlh_link_retrain_s;
  end
end : l1_exit_PROC



wire int_core_edma_bridge_pending;
assign int_core_edma_bridge_pending = (app_xfer_pending || pm_trgt_cpl_lut_empty_n || edma_xfer_pending || brdg_slv_xfer_pending || pm_radm_idle_n || lbc_active);

assign pm_wake_l1_pg_exit = int_l1_pg_exit_native_s || int_brdg_pg_exit_s || app_xfer_pending;
assign pm_wake_l1_pg_ack = !(int_l1_pg_exit_native_s || int_core_edma_bridge_pending);
assign pm_wake_xfer_pending = int_core_edma_bridge_pending || int_l1_exit_native_s;
assign pm_wake_l1_exit = int_init_rst_r || int_ltr_msg_req_r || pm_wake_unlock_msg_req || int_cfg_or_msg_exit_r 
                         ;

// Prevent power-gating until L1 exit is complete
assign int_set_block_pg_s = int_init_rst_s || app_ltr_msg_req || int_unlock_msg_req_s || int_cfg_or_msg_exit_s;
assign int_block_pg_s = (int_set_block_pg_s ? 1'b1 : (!pm_linkst_in_l1 ? 1'b0 : pm_wake_block_pg));



endmodule
