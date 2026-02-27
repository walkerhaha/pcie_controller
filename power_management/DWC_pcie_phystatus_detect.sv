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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/DWC_pcie_phystatus_detect.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module registers Phystatus in PCLK domain and generates an aux_clk domain
// signal that indicates Phystatus has been detected high on all active lanes.
// It also generates an indication that Phystatus has been detect low in all lanes.
// Phystatus low detection is handled different for transitions from PCLK running states 
// to PCLK running states as indicated by the parameter PCLK_RUNNING.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

module DWC_pcie_phystatus_detect

import DWC_pcie_pm_pkg::*;
  #(
    // Parameter Declaration
    parameter TP = `TP,
    parameter PCLK_RUNNING = 1 // Set to 1 if PCLK is running in both to and from states otherwise 0
  ) (
  // Inputs
  input                         pipe_clk,
  input                         aux_clk,
  input                         pwr_rst_n,
  input [(NL - 1) : 0]          lane_active,          // mask Phystatus for disabled lanes
  input [(NL - 1) : 0]          phy_mac_phystatus,    // Phystatus handshake
  input                         en_detector,          // Enable the phystatus detection
  input                         aux_phystatus,        // aux_clk domain synchronized level version of Phystatus
  input                         pm_perst_powerdown,   // Indicate PIPE or PMA reset request
  // Outputs
  output logic                  phystatus_high,       // Phystatus detected high in aux_clk domain
  output logic                  phystatus_low,        // Phystatus detected low in aux_clk domain
  output logic                  phystatus_sync_done   // Phystatus high synchronization done indication in pipe_clk domain
);

// ----------------------------------------------------------------------------
// Logic Declaration
// ----------------------------------------------------------------------------
logic [(NL - 1) : 0]  int_phystatus_b;
logic [(NL - 1) : 0]  int_phystatus_r;
logic                 int_phystatus_high_b;
logic                 int_phystatus_high_r;
logic                 int_phystatus_re_b;
logic                 sync_phystatus_high;
logic                 int_pclk_phystatus_high_b;
logic                 int_pclk_phystatus_high_r;
logic                 int_phystatus_low_r;
logic                 int_flush_phystatus_b;
logic                 int_aux_sync_done_b;
logic                 int_aux_sync_done_r;

assign phystatus_sync_done = int_pclk_phystatus_high_r;

// Latch the PHY status for active lanes and hold until the signal has been transferred to aux_clk
always_comb begin : phystatus_PROC
  integer ln;
  int_phystatus_b = {NL{1'b0}};
  // When Phystatus has been transferred to aux_clk clear the register
  if (int_flush_phystatus_b || pm_perst_powerdown) begin
    int_phystatus_b = {NL{1'b0}};
  end else begin
    for (ln=0; ln<NL; ln=ln+1) begin
      // Set to 1 for disabled lanes 
      if (~lane_active[ln] && en_detector)
        int_phystatus_b[ln] = 1'b1;
      // For enabled lanes set to 1 when Phystatus is asserted
      else if (phy_mac_phystatus[ln] && en_detector)
        int_phystatus_b[ln] = 1'b1;
      else
        int_phystatus_b[ln] = int_phystatus_r[ln];
    end
  end
end : phystatus_PROC

// Phystatus high on all active lanes
assign int_phystatus_high_b = &int_phystatus_b;
// Phystatus rising edge detect
assign int_phystatus_re_b = int_phystatus_high_b && !int_phystatus_high_r;

always_ff @(posedge pipe_clk or negedge pwr_rst_n) begin
  if (!pwr_rst_n)
  begin
    int_phystatus_r           <= #TP {NL{1'b1}};
    int_phystatus_high_r      <= #TP 1'b1;
    int_pclk_phystatus_high_r <= #TP 1'b1;
  end
  else
  begin
    int_phystatus_r           <= #TP int_phystatus_b;
    int_phystatus_high_r      <= #TP int_phystatus_high_b;
    int_pclk_phystatus_high_r <= #TP int_pclk_phystatus_high_b;
  end
end

// extend the input to the BCM41 to 2 cycles of aux_clk
assign int_aux_sync_done_b = sync_phystatus_high || phystatus_high
                             ;

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin
  if (!pwr_rst_n)
  begin
    phystatus_high      <= #TP 1'b1;
    int_aux_sync_done_r <= #TP 1'b0;
    int_phystatus_low_r <= #TP 1'b0;
  end
  else
  begin
    phystatus_high      <= #TP sync_phystatus_high;
    int_phystatus_low_r <= #TP !sync_phystatus_high;
    int_aux_sync_done_r <= #TP int_aux_sync_done_b;
  end
end

// Synchronize the Phstatus high indication back to pipe_clk domain to clear the registered Phystatus
DWC_pcie_ctl_bcm41

#(
    .WIDTH (1),
    .RST_VAL (1),
    .F_SYNC_TYPE (CORE_SYNC_DEPTH)
) u_aux_to_pipe_sync (
    .clk_d      (pipe_clk),
    .rst_d_n    (pwr_rst_n),
    .data_s     (int_aux_sync_done_r),
    .data_d     (int_pclk_phystatus_high_b)
);

DWC_pcie_ctl_bcm22
 u_phystatus_pulse_sync (
    .clk_s    (pipe_clk),
    .rst_s_n  (pwr_rst_n),
    .event_s  (int_phystatus_re_b),
    .clk_d    (aux_clk),
    .rst_d_n  (pwr_rst_n),
    .event_d  (sync_phystatus_high)
);


// If Phystatus is a single PCLK Pulse (PCLK running in TO/FROM) then just use the low level of the int_phystatus_low_r
// If PCLK is not running in the TO state use the low level of the synchronized version of phy_mac_phystatus
// If transitioning from PCLK OFF to PCLK ON state the Phystatus detection logic is cleared when the detection logic is disabled.
// This happens when for example the powerdown value transitions from P1.CPM to P1 or P2 to P1.
generate
  if(PCLK_RUNNING) begin : phystatus_gen_PROC
    assign phystatus_low = int_phystatus_low_r;
    assign int_flush_phystatus_b = int_pclk_phystatus_high_r;
  end
  else begin : phystatus_gen_PROC
    assign phystatus_low = !aux_phystatus;
    assign int_flush_phystatus_b = !en_detector;
  end
endgenerate

endmodule
