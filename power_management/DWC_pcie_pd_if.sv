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
// ---    $DateTime: 2020/10/28 15:50:21 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/DWC_pcie_pd_if.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Powerdown interface to Phystatus tracker FSM
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

module DWC_pcie_pd_if

import DWC_pcie_pm_pkg::*;
  // Parameters
  #(
    parameter TP = `TP
  ) (
  // Inputs
  input                                     aux_clk,
  input                                     pipe_clk,
  input                                     pwr_rst_n,
  input                                     phystatus_hs_done,            // Phystatus handshake is complete 
  input [(PWDN_WIDTH - 1) : 0]              mac_phy_powerdown,            // Powerdown value requested by the MAC
  input [(NL - 1) : 0]                      mac_phy_txdetectrx_loopback,  // Receiver detect
  input [((RXSTATUS_WD * NL) - 1) : 0]      phy_mac_rxstatus,             // Rxstatus to be used in receiver detection
  input                                     pipe_phystatus_done,          // Phystatus handshake done indication in pipe_clk domain
  input                                     force_transition,             // force the phystatus handshake to complete
  input                                     pm_perst_powerdown,           // Indicate there is PMA or PIPE reset
  // Outputs
  output logic                              pd_if_req_phystatus_hs_r,     // Request Phystatus handshake 
  output logic [(PWDN_WIDTH - 1) : 0]       pd_if_curr_powerdown_r,       // Current powerdown acknowledged by the Phy 
  output logic                              pd_if_curr_powerdown_p2,      // Current powerdown P2
  output logic                              pd_if_curr_powerdown_p1,      // Current powerdown P1
  output logic                              pd_if_curr_powerdown_p0,      // Current powerdown P0
  output logic [(NL - 1) : 0]               pd_if_rxdetected_r,           // Receiver detect indication
  output logic                              pd_if_rxdetect_active_r,      // Receiver detection in progress
  output logic                              pd_if_rxdetect_done,          // Receiver detection done
  output logic [((PWDN_WIDTH * 2) - 1) : 0] pd_if_status,                 // Powerdown interface status register
  output logic                              pd_if_force_transition_r      // Powerdown interface request to force phystatus handshake
);

// ----------------------------------------------------------------------------
// Logic Declarations
// ----------------------------------------------------------------------------
logic [(PWDN_WIDTH - 1) : 0]  int_curr_powerdown_b;
logic                         req_phystatus_hs_b;
logic                         detect_pd_change;
logic [(NL - 1) : 0]          int_rxdetected_b;
logic                         int_rxdetect_active_b;
logic                         int_rxdetect_req_b;
logic                         int_rxdetect_req_r;
logic                         int_rxdetect_req_re;
logic                         int_force_transition_b;
logic                         int_phystatus_hs_done_r;
logic                         int_phystatus_hs_done_fe;

// ----------------------------------------------------------------------------
// Current powerdown tracking
// ----------------------------------------------------------------------------
// Current Powerdown Process update the value when Phystatus has been returned
// (Only update powerdown at the falling edge of phystatus_hs_done
// The current powerdown should not be updated during receiver detection
assign int_phystatus_hs_done_fe = !phystatus_hs_done && int_phystatus_hs_done_r;
always_comb begin : curr_powerdown_PROC
  if (int_phystatus_hs_done_fe && !pd_if_rxdetect_active_r)
    int_curr_powerdown_b = mac_phy_powerdown;
  else
    int_curr_powerdown_b = pd_if_curr_powerdown_r;
end : curr_powerdown_PROC

// Current powerdown P2 the decode can be either P2 Or P2NOBEACON
assign pd_if_curr_powerdown_p2 = (pd_if_curr_powerdown_r == P2);
assign pd_if_curr_powerdown_p1 = (pd_if_curr_powerdown_r == P1);
assign pd_if_curr_powerdown_p0 = (pd_if_curr_powerdown_r == P0);

// Generate the request to the Phystatus FSM to begin tracking Phystatus
// This is initiated when a change is detect on mac_phy_powerdown or in the case
// of Receiver detection in the P1 state.
assign detect_pd_change = !((mac_phy_powerdown) == (pd_if_curr_powerdown_r));
assign int_rxdetect_req_b = ((pd_if_curr_powerdown_r == P1) && |mac_phy_txdetectrx_loopback);

always_comb begin : req_phystatus_hs_PROC
  if (phystatus_hs_done)
    req_phystatus_hs_b = 1'b0;
  else if (detect_pd_change || int_rxdetect_req_b)
    req_phystatus_hs_b = 1'b1;
  else
    req_phystatus_hs_b = pd_if_req_phystatus_hs_r;
end : req_phystatus_hs_PROC

// ----------------------------------------------------------------------------
// Debug forcing of powerdown handshake 
// ----------------------------------------------------------------------------
always_comb begin : force_hs_PROC
  // set to 1 when toggle on debug input
  if (force_transition)
    int_force_transition_b = 1'b1;
  // Cleared when Phystatus handshake completes
  else if (phystatus_hs_done)
    int_force_transition_b = 1'b0;
  // hold
  else
    int_force_transition_b = pd_if_force_transition_r;
end : force_hs_PROC

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin
  if (!pwr_rst_n) begin
    pd_if_curr_powerdown_r <= #TP P1;
    pd_if_req_phystatus_hs_r <= #TP 1'b0;
    int_rxdetect_req_r <= #TP 1'b0;
    pd_if_rxdetect_active_r <= #TP 1'b0;
    pd_if_force_transition_r <= #TP 1'b0;
    int_phystatus_hs_done_r <= #TP 1'b0;
  end
  else begin
    // When PMA rst or PIPE rst happen, the current powerdown go to P1
    pd_if_curr_powerdown_r <= #TP pm_perst_powerdown ? P1 : int_curr_powerdown_b;
    pd_if_req_phystatus_hs_r <= #TP req_phystatus_hs_b;
    int_rxdetect_req_r <= #TP int_rxdetect_req_b;
    pd_if_rxdetect_active_r <= #TP int_rxdetect_active_b;
    pd_if_force_transition_r <= #TP int_force_transition_b;
    int_phystatus_hs_done_r <= #TP phystatus_hs_done;
  end
end

assign pd_if_status = {pd_if_curr_powerdown_r, mac_phy_powerdown};

// ----------------------------------------------------------------------------
// Receiver detection logic
// ----------------------------------------------------------------------------
always_comb begin : rxdetect_PROC
  integer ln;
  int_rxdetected_b = {NL{1'b0}};
  // When Phystatus handshake is done clear rxdetected
  if (pipe_phystatus_done) begin
    int_rxdetected_b = {NL{1'b0}};
  end else begin
    for (ln = 0; ln < NL; ln = ln + 1) begin
      // Updated based on decode of phy_mac_rxstatus
      if (phy_mac_rxstatus[((3*ln) + 2) -: RXSTATUS_WD] == RX_PRESENT) begin
        int_rxdetected_b[ln] = 1'b1;
      end
      else
        int_rxdetected_b[ln] = pd_if_rxdetected_r[ln];
    end
  end
end : rxdetect_PROC

// Receiver dection done indication
assign pd_if_rxdetect_done = pd_if_rxdetect_active_r && phystatus_hs_done;

// Generate Receiver detection active indication
assign int_rxdetect_req_re = int_rxdetect_req_b && !int_rxdetect_req_r;
always_comb begin : rxdetect_active_PROC
  int_rxdetect_active_b = 1'b0;
  if(int_rxdetect_req_re) begin
    int_rxdetect_active_b = 1'b1;
  end
  else if(phystatus_hs_done) begin
    int_rxdetect_active_b = 1'b0;
  end
  else begin
    int_rxdetect_active_b = pd_if_rxdetect_active_r;
  end
end : rxdetect_active_PROC

always_ff @(posedge pipe_clk or negedge pwr_rst_n) begin
  if (!pwr_rst_n)
  begin
    pd_if_rxdetected_r <= #TP {NL{1'b0}};
  end
  else
  begin
    pd_if_rxdetected_r <= #TP int_rxdetected_b;
  end
end

endmodule
