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
// ---    $DateTime: 2020/10/22 02:44:15 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/DWC_pcie_phystatus_if.sv#11 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module provides an interface between controller and PHY for performing
// handshakes using the Phystatus signal.
// It contains an FSM to handle Phystatus detection in response to commands from the MAC.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

module DWC_pcie_phystatus_if

import DWC_pcie_pm_pkg::*;
  // Parameters
  #(
    parameter TP = `TP
  ) (
    // Inputs
    input                                     aux_clk,                      // aux_clk
    input                                     pipe_clk,                     // PHY clock for sampling phy_mac_phystatus
    input                                     pwr_rst_n,                    // power on reset
    input [(PWDN_WIDTH - 1) : 0]              mac_phy_powerdown,            // powerdown request from the MAC
    input [(NL - 1) : 0]                      mac_phy_txcompliance,         // Txcompliance used to disable lanes
    input [(NL - 1) : 0]                      mac_phy_txdetectrx_loopback,  // Receiver Detect request from the MAC
    input [(NL - 1) : 0]                      phy_mac_phystatus,            // Phystatus handshake from the PHY
    input [((RXSTATUS_WD * NL) - 1) : 0]      phy_mac_rxstatus,             // Rxstatus signal from the PHY
    input                                     cfg_force_powerdown,          // Force the powerdown handshake to complete regardless of Phystatus
    input [5:0]                               pm_link_capable,              // PL LINK_CAPABLE register, indicate used lanes at reset
    input [5:0]                               smlh_ltssm_state,             // LTSSM state
    input                                     pm_perst_powerdown,           // Indicate there is PMA or PIPE reset
    // Outputs
    output logic [(PWDN_WIDTH - 1) : 0]       pm_current_powerdown,         // Current powerdown value as acknowledged by the PHY
    output logic [(NL - 1) : 0]               pm_rxdetected,                // Receiver detected indication
    output logic                              pm_current_powerdown_p2,      // Current powerdown is P2
    output logic                              pm_current_powerdown_p1,      // Current powerdown is P1
    output logic                              pm_current_powerdown_p0,      // Current powerdown is P0
    output logic [((2 * PWDN_WIDTH) -1) : 0]  pm_powerdown_status,          // Powerdown status register
    output logic                              phystatus_if_sel_aux_clk      // Phystatus interface select aux_clk
    ,output logic                             phystatus_pclk_ready          // When all active lane's phystatus are 0
);

// ----------------------------------------------------------------------------
// Logic Declaration
// ----------------------------------------------------------------------------
logic int_rate_change;


// ----------------------------------------------------------------------------
// Phystatus tracker FSM
// ----------------------------------------------------------------------------
DWC_pcie_phystatus_fsm
 u_phystatus_fsm(
  // Inputs
  .aux_clk              (aux_clk),
  .pwr_rst_n            (pwr_rst_n),
  .req_phystatus_hs     (pd_if_req_phystatus_hs),
  .phystatus_low        (phystatus_low),
  .phystatus_high       (phystatus_high),
  .phystatus_pclk_ready (phystatus_pclk_ready),
  .force_transition     (pd_if_force_transition),
  .pm_perst_powerdown   (pm_perst_powerdown),
  // Outputs
  .phystatus_hs_done_r  (phystatus_hs_done),
  .sel_aux_clk_r        (phystatus_if_sel_aux_clk)
);

// ----------------------------------------------------------------------------
// Powerdown interface for Phystatus handshake
// ----------------------------------------------------------------------------

DWC_pcie_pd_if
 u_pd_if(
  // Inputs
  .aux_clk                      (aux_clk),
  .pipe_clk                     (pipe_clk),
  .pwr_rst_n                    (pwr_rst_n),
  .phystatus_hs_done            (phystatus_hs_done),
  .mac_phy_powerdown            (mac_phy_powerdown),
  .mac_phy_txdetectrx_loopback  (mac_phy_txdetectrx_loopback),
  .phy_mac_rxstatus             (phy_mac_rxstatus),
  .pipe_phystatus_done          (phystatus_sync_done_pipe),
  .force_transition             (cfg_force_powerdown),
  .pm_perst_powerdown           (pm_perst_powerdown),
  // Outputs
  .pd_if_req_phystatus_hs_r     (pd_if_req_phystatus_hs),
  .pd_if_curr_powerdown_r       (pm_current_powerdown),
  .pd_if_curr_powerdown_p2      (pm_current_powerdown_p2),
  .pd_if_curr_powerdown_p1      (pm_current_powerdown_p1),
  .pd_if_curr_powerdown_p0      (pm_current_powerdown_p0),
  .pd_if_rxdetected_r           (pm_rxdetected),
  .pd_if_rxdetect_active_r      (),
  .pd_if_rxdetect_done          (),
  .pd_if_status                 (pm_powerdown_status),
  .pd_if_force_transition_r     (pd_if_force_transition)
);


// ----------------------------------------------------------------------------
// Phystatus synchronization logic
// ----------------------------------------------------------------------------
DWC_pcie_phystatus_sync
 u_phystatus_sync(
  // Inputs
  .aux_clk                  (aux_clk),
  .pipe_clk                 (pipe_clk),
  .pwr_rst_n                (pwr_rst_n),
  .phy_mac_phystatus        (phy_mac_phystatus),
  .mac_phy_txcompliance     (mac_phy_txcompliance),
  .mac_phy_powerdown        (mac_phy_powerdown),
  .pm_link_capable          (pm_link_capable),
  .smlh_ltssm_state         (smlh_ltssm_state),
  .pm_perst_powerdown       (pm_perst_powerdown),
  // Outputs
  .phystatus_high           (phystatus_high),
  .phystatus_low            (phystatus_low),
  .phystatus_sync_done_pipe (phystatus_sync_done_pipe),
  .phystatus_pclk_ready     (phystatus_pclk_ready)
);

endmodule
