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
// ---    $DateTime: 2020/10/16 04:47:41 $
// ---    $Revision: #24 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_rst_control.sv#24 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module is responsible for controlling the reset generation for
// --- the IP.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module pm_rst_control
    // Parameters
    #(
        parameter TP = `TP,
        parameter NL = 1,
        parameter INST = 0,
        parameter PM_SYNC_DEPTH = 2
    )
    (
    // Inputs
    input                       core_rst_n,                 // Core reset
    input                       pm_req_iso_vmain_to_vaux,   // Isolation enable
    input                       aux_clk,                    // auxilliary clock
    input                       pwr_rst_n,                  // power on reset
    input                       perst_n,                    // perst signal synchronized to aux_clk
    input                       phy_type,                   // PHY Type
    input                       pm_linkst_in_l2,            // PM control is in L2
    input                       aux_clk_active,             // Aux clock switched to slow clock
    input                       aux_clk_inactive,           // Aux clock switched to core clock
    input                       link_req_rst_not,
    input                       app_hold_phy_rst,           // Hold the PHY in reset during initialization
    input [17:0]                pm_phy_rst_timer,           // PHY rst timer
    input [5:0]                 pm_pma_phy_rst_delay_timer, // PMA reset to PIPE reset delay timer
    input                       pm_phy_perst_on_warm_reset,    // PMC drive pm_req_phy_perst when warm reset
    input                       phystatus_pclk_ready,       // Indicate all the active lanes' phystatus are 0
    // Outputs
    output wire                 pm_rst_req_phy_rst,         // Request the PHY reset assertion
    output wire                 pm_rst_req_phy_perst,       // Request the PHY perst reset assertion
    output wire                 pm_rst_req_core_rst,        // Request the assertion of sticky, core, non_sticky resets
    output wire                 pm_rst_req_sticky_rst,      // Request the assertion of sticky, core, non_sticky resets
    output wire                 pm_rst_req_non_sticky_rst,  // Request the assertion of sticky, core, non_sticky resets
    output wire                 pm_rst_perst_powerdown,     // Drive specific powerdown during phy_perst rst
    output reg                  pm_rst_set_phy_p1,          // Put the PHY in P1 when resetting the PHY after L23 wakeup
    output wire                 pm_rst_sel_aux_clk,         // Select slow clock for aux_clk
    output wire                 pm_rst_sync_perst_n,        // perst_n synchronized to aux_clk
    output wire                 pm_rst_phy_rst_done,        // reset of PHY after L2 exit is complete 
    output wire                 pm_rst_core_rst_done,       // Core reset done indication
    output reg                  pm_rst_det_l2               // The core is in L2 with perst asserted
);

// ----------------------------------------------------------------------------
// Local parameters
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Register declarations
// ----------------------------------------------------------------------------
reg         int_req_phy_rst_r;
reg         int_req_phy_l2_rst_r;
reg         int_req_cntl_rst_r;
reg [17 : 0] int_phy_rst_cnt_r;
reg [5 : 0] int_pma_pipe_rst_delay_cnt_r;
reg         int_sync_perst_n_r;
reg         int_sync_perst_n_r2;
reg         int_sel_aux_clk_r;
reg         int_core_rst_det_r;
reg         int_core_rst_det_rr;
reg         int_rst_in_l2_r;
reg         int_phy_rst_flag_s;
reg         int_pma_pipe_rst_r;
reg         int_pma_pipe_rst_s;

// ----------------------------------------------------------------------------
// Net declarations
// ----------------------------------------------------------------------------
reg                 int_set_phy_p1_s;
reg                 int_req_phy_l2_rst_s;
wire                int_set_phy_rst_s;
reg                 int_en_phy_rst_cnt_s;
wire [17 : 0]       int_phy_rst_cnt_s;
wire [5 : 0]        int_pma_pipe_rst_delay_cnt_s;
wire                int_phy_rst_timeout;
wire                int_pma_pipe_rst_delay_timeout;
reg                 int_sel_aux_clk_s;
wire                int_sync_perst_n;
wire                int_rst_perst_n_re_s;
reg                 int_det_l2_s;
wire                int_set_l2_s;
wire                int_det_exit_l2_s;
wire                int_rel_phy_p1_s;
wire                int_rst_perst_n_fe_s;
wire                int_req_phy_rst_s;
wire                int_req_phy_perst;
reg                 int_rst_in_l2_s;
reg                 int_phy_rst_flag_r;
wire                int_start_pma_pipe_rst;
wire                int_release_pma_pipe_rst;

// ----------------------------------------------------------------------------
// Synchronize Perst to aux_clk
// ----------------------------------------------------------------------------
DWC_pcie_ctl_bcm41

#(
    .WIDTH (1),
    .RST_VAL (0),
    .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_perst_n_sync (
    .clk_d      (aux_clk),
    .rst_d_n    (pwr_rst_n),
    .data_s     (perst_n),
    .data_d     (int_sync_perst_n)
);

// De-glitch logic for perst_n
assign pm_rst_sync_perst_n = int_sync_perst_n && int_sync_perst_n_r;

// ----------------------------------------------------------------------------
// Controller resets during perst assertion
// ----------------------------------------------------------------------------
reg   int_req_cntl_rst_s;
wire  int_release_rst;
reg   int_release_rst_r;
reg   int_release_rst_r2;
wire  int_start_rst;
wire  int_release_phy_rst;

// Only trigger the pipe/pma rst after aux_clk is active
// for more than 2 cycles in a roll.
reg  aux_clk_active_r;
reg  aux_clk_active_r2;
wire aux_clk_active_ready;

always @(posedge aux_clk or negedge pwr_rst_n)
begin
  if(!pwr_rst_n) begin
    aux_clk_active_r  <= #TP 1'b1;
    aux_clk_active_r2 <= #TP 1'b1;
  end else begin
    aux_clk_active_r  <= #TP aux_clk_active;
    aux_clk_active_r2 <= #TP aux_clk_active_r;
  end
end

assign aux_clk_active_ready = aux_clk_active && aux_clk_active_r && aux_clk_active_r2;

// Indicate the PMA/PIPE reset due to perst is on
// Need to drive specific powerdown during this period
assign pm_rst_perst_powerdown = pm_rst_req_phy_rst                                                      || int_req_cntl_rst_s
                                                      || pm_rst_req_phy_perst
                                                      ;

// indicate when to clear the pclkchange hs                                                         
assign pclk_hs_rst = ((pm_rst_req_phy_rst || pm_rst_req_phy_perst) && aux_clk_active_ready) || !link_req_rst_not;

// Start reset:
// In L2: start the reset after perst_n is finished
// In other condition: start the reset immediately after perst.
// apply to phy_rst/perst_rst/core_rst/sticky or non_sticky rst

// perst_in_l2 used to indicate the whole duration when perst_n happen in L2.
wire perst_in_l2;
assign perst_in_l2 = pm_linkst_in_l2 || pm_rst_det_l2;
assign int_start_rst = perst_in_l2 ? int_det_exit_l2_s : ((!pm_rst_sync_perst_n || !int_sync_perst_n_r2) && aux_clk_active_ready);

// Release reset:
// In L2: release after the timer is timeout
// In other condition: release the reset immediately after perst.
// apply to phy_rst/perst_rst/core_rst/sticky or non_sticky rst
// If wakeup from L2 during perst_n, pm_linkst_in_l2 is terminated earlier
// int_rst_in_l2_r is used to indicate that phy/pipe reset happens in L2.
assign int_release_rst = (pm_linkst_in_l2 || int_rst_in_l2_r) ? int_phy_rst_timeout : (pm_rst_sync_perst_n && int_sync_perst_n_r2);

// Timer:
// The rst timer is used in L2.
assign int_phy_rst_timeout = (int_phy_rst_cnt_r == (pm_phy_rst_timer - 1'b1));
assign int_phy_rst_cnt_s = int_req_phy_l2_rst_r ? int_phy_rst_cnt_r + 1'b1 : 18'h0;

always @ *
begin
    if(perst_in_l2 && int_det_exit_l2_s)
        int_rst_in_l2_s = 1'b1;
    else if(int_rst_in_l2_r && int_phy_rst_timeout)
        int_rst_in_l2_s = 1'b0;
    else
        int_rst_in_l2_s = int_rst_in_l2_r;
end

// Reset generation for controller resets
always @ *
begin
    // reset asserted when perst_n is low
    if(int_start_rst)
        int_req_cntl_rst_s = 1'b1;
    // reset released when perst_n is high and aux_clk has switched
    else if(int_release_rst)
        int_req_cntl_rst_s = 1'b0;
    else
        int_req_cntl_rst_s = int_req_cntl_rst_r;
end

// ----------------------------------------------------------------------------
// Reset request logic
// ----------------------------------------------------------------------------
// Detect de-assertion of core_rst_n note when the inputs to pm_ctrl are being
// isolated the reset input will be isolated to 1 so the asynchronous reset
// will not be detected. For this reason the register is set to 0 when isolation
// enable is detected.
always @(posedge aux_clk or negedge core_rst_n)
begin
  if(!core_rst_n)
    int_core_rst_det_r <= #TP 1'b0;
  else
  begin
    if(pm_req_iso_vmain_to_vaux)
      int_core_rst_det_r <= #TP 1'b0;
    else
      int_core_rst_det_r <= #TP 1'b1;
  end
end

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if(!pwr_rst_n)
    begin
        int_core_rst_det_rr <= #TP 1'b0;
        int_req_phy_rst_r <= #TP 1'b1;
        int_sync_perst_n_r <= #TP 1'b0;
        int_sync_perst_n_r2 <= #TP 1'b0;
        int_phy_rst_cnt_r <= #TP 18'b0;
        int_pma_pipe_rst_delay_cnt_r <= #TP 6'b0;
        int_req_phy_l2_rst_r <= #TP 1'b0;
        int_req_cntl_rst_r <= #TP 1'b1;
        pm_rst_set_phy_p1 <= #TP 1'b0;
        int_sel_aux_clk_r <= #TP 1'b1;
        pm_rst_det_l2 <= #TP 1'b0;
        int_rst_in_l2_r <= #TP 1'b0;
        int_phy_rst_flag_r <= #TP 1'b1;
        int_release_rst_r <= #TP 1'b0;
        int_release_rst_r2 <= #TP 1'b0;
        int_pma_pipe_rst_r <= #TP 1'b0;
    end
    else
    begin
        int_core_rst_det_rr <= #TP int_core_rst_det_r;
        int_sync_perst_n_r <= #TP int_sync_perst_n;
        int_sync_perst_n_r2 <= #TP pm_rst_sync_perst_n;
        int_phy_rst_cnt_r <= #TP int_phy_rst_cnt_s;
        int_pma_pipe_rst_delay_cnt_r <= #TP int_pma_pipe_rst_delay_cnt_s;
        int_req_phy_rst_r <= #TP ((app_hold_phy_rst && aux_clk_active_ready) || int_req_phy_l2_rst_s || int_pma_pipe_rst_s);
        int_req_cntl_rst_r <= #TP int_req_cntl_rst_s;
        int_req_phy_l2_rst_r <= #TP int_req_phy_l2_rst_s;
        pm_rst_set_phy_p1 <= #TP int_set_phy_p1_s;
        int_sel_aux_clk_r <= #TP int_sel_aux_clk_s;
        pm_rst_det_l2 <= #TP int_det_l2_s;
        int_rst_in_l2_r <= #TP int_rst_in_l2_s;
        int_phy_rst_flag_r <= #TP int_phy_rst_flag_s;
        int_release_rst_r <= #TP int_release_rst;
        int_release_rst_r2 <= #TP int_release_rst_r;
        int_pma_pipe_rst_r <= #TP int_pma_pipe_rst_s;
    end
end

// ----------------------------------------------------------------------------
// Detect entry into L2 pm_linkst_in_l2 asserted and main power removed
// signalled by the assertion of perst_n
// ----------------------------------------------------------------------------
assign int_set_l2_s = !pm_rst_sync_perst_n && pm_linkst_in_l2;

// detection of entry into L2 only de-assert this signal when main power is restored
// signalled by the de-assertion of perst_n
always @ *
begin
  if(int_set_l2_s)
    int_det_l2_s = 1'b1;
  else if(int_rst_perst_n_re_s)
    int_det_l2_s = 1'b0;
  else
    int_det_l2_s = pm_rst_det_l2;
end

// ----------------------------------------------------------------------------
// When perst_n is asserted the PHY reset will be requested
// right after perst_n started and aux clk is active
// ----------------------------------------------------------------------------
assign int_rst_perst_n_fe_s = !pm_rst_sync_perst_n && int_sync_perst_n_r2;

// ----------------------------------------------------------------------------
// The PIPE reset is aligned with PMA reset and core reset.
// In L2: the PIPE reset start when perst_n is finished.
// In other condition: PIPE reset is asserted when perst_n is asserted.
// If this is as a result of L2 entry the powerdown signal of the PHY
// will be forced to P1 otherwise the core reset being applied should already
// result in P1 being driven on powerdown
// ----------------------------------------------------------------------------
assign int_req_phy_rst_s = int_start_rst;
// pm_rst_phy_rst_done is a legacy signal used to indicate
// when the pipe reset is finished. Since pipe rst is align with 
// perst_n, the perst_n rising edge can indicate pipe rst finish.
assign pm_rst_phy_rst_done = int_release_rst_r && !int_release_rst_r2;
assign int_rst_perst_n_re_s = pm_rst_sync_perst_n && !int_sync_perst_n_r2;
assign int_det_exit_l2_s = (int_rst_perst_n_re_s && pm_rst_det_l2);

always @ *
begin
    if(int_req_phy_rst_s)
        int_req_phy_l2_rst_s = 1'b1;
    else if(int_release_rst)
        int_req_phy_l2_rst_s = 1'b0;
    else
        int_req_phy_l2_rst_s = int_req_phy_l2_rst_r;
end

// ----------------------------------------------------------------------------
// The PHY is put in P1 when the reset is being asserted
// The PHY will be held in P1 until the exit from L2 has completed
// ----------------------------------------------------------------------------
assign int_rel_phy_p1_s = (!int_req_phy_l2_rst_r && !pm_linkst_in_l2);

always @ *
begin
    if(int_det_exit_l2_s)
       int_set_phy_p1_s = 1'b1;
    else if(int_rel_phy_p1_s)
       int_set_phy_p1_s = 1'b0;
    else
       int_set_phy_p1_s = pm_rst_set_phy_p1;
end

// ----------------------------------------------------------------------------
// Select for clock switch between fast and slow clock for aux_clk
// ----------------------------------------------------------------------------
reg                 int_vp_sel_aux_clk_s;
reg                 int_vp_sel_aux_clk_r;
wire                phystatus_pclk_ready_rst;

always @(posedge aux_clk or negedge pwr_rst_n) begin : phystatus_PROC
  if(!pwr_rst_n) begin
    int_vp_sel_aux_clk_r <= #TP 1'b1;
  end else begin
    int_vp_sel_aux_clk_r <= #TP int_vp_sel_aux_clk_s;
  end
end : phystatus_PROC

// Indicate that all the active lanes in phystatus are 0.
// pclk could be from any lane, only all active lane 0 indicate pclk is ready
// Only consider pclk ready when there is no pipe/pma reset
assign phystatus_pclk_ready_rst = !pm_rst_req_phy_rst && !pm_rst_req_phy_perst && phystatus_pclk_ready;

always @ *
begin
  if(app_hold_phy_rst)
    int_vp_sel_aux_clk_s = 1'b1;
  else if(phystatus_pclk_ready_rst)
    int_vp_sel_aux_clk_s = 1'b0;
  else
    int_vp_sel_aux_clk_s = int_vp_sel_aux_clk_r;
end

always @ *
begin
    if(!pm_rst_sync_perst_n)
        int_sel_aux_clk_s = 1'b1;
    else if(phystatus_pclk_ready_rst && int_sel_aux_clk_r&&int_phy_rst_flag_r)
        int_sel_aux_clk_s = 1'b0;
    else
        int_sel_aux_clk_s = int_sel_aux_clk_r;
end

// int_phy_rst_flag_s is used to remember the phy_rst_n has happened
always @ *
begin
    if(pm_rst_phy_rst_done)
      int_phy_rst_flag_s = 1'b1;
    else if (aux_clk_inactive)
      int_phy_rst_flag_s = 1'b0;
    else
      int_phy_rst_flag_s = int_phy_rst_flag_r;
end

// ----------------------------------------------------------------------------
// Reset requests generation 
// ----------------------------------------------------------------------------
assign int_req_phy_perst = int_req_cntl_rst_r && pm_phy_perst_on_warm_reset;
assign pm_rst_req_phy_rst = int_req_phy_rst_r;
assign pm_rst_req_phy_perst = int_req_phy_perst;
assign pm_rst_req_core_rst = int_req_cntl_rst_r;
assign pm_rst_req_sticky_rst = int_req_cntl_rst_r;
assign pm_rst_req_non_sticky_rst = int_req_cntl_rst_r;
assign pm_rst_sel_aux_clk = int_sel_aux_clk_s || int_vp_sel_aux_clk_r ;


// Rising edge detect of core_rst_n
assign pm_rst_core_rst_done = !int_core_rst_det_rr && int_core_rst_det_r;

// Timer for PMA reset to PIPE reset delay
// Based on the PHY requirement, 
// PIPE reset should not be finished immediately when PMA reset finish
// This following timer is used to hold PIPE reset for duration that is
// configured by cfg_pma_phy_rst_delay_timer after PMA reset.
// Note: if cfg_phy_perst_on_warm_reset==0, this timer will not be triggered.
                                
assign int_start_pma_pipe_rst = (int_req_cntl_rst_r && int_release_rst
                                                   )
                                                  ;                                
assign int_release_pma_pipe_rst = int_pma_pipe_rst_r && int_pma_pipe_rst_delay_timeout;

assign int_pma_pipe_rst_delay_timeout = (int_pma_pipe_rst_delay_cnt_r == (pm_pma_phy_rst_delay_timer - 1'b1));
assign int_pma_pipe_rst_delay_cnt_s = int_pma_pipe_rst_r ? int_pma_pipe_rst_delay_cnt_r + 1'b1 : 6'h0;

always @ *
begin
    if(int_start_pma_pipe_rst)
        int_pma_pipe_rst_s = 1'b1;
    else if(int_release_pma_pipe_rst)
        int_pma_pipe_rst_s = 1'b0;
    else
        int_pma_pipe_rst_s = int_pma_pipe_rst_r;
end



endmodule
