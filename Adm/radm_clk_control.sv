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
// ---    $DateTime: 2019/10/03 14:27:33 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_clk_control.sv#2 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// RADM Clock Control : This module is clocked by the core clock which is
// not gated when the RADM is idle. The module monitors the requests at the inputs
// to the RADM and the internal status of the RADM receive queues and CPL LUT to
// generate an idle indication. The idle indication is registered to generate
// an enable output which may be used to gate off the RADM clock.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
 
module radm_clk_control
  #(
    parameter TP  = `TP,
    parameter NF  = 1,
    parameter XTLH_PIPE_DELAY = 1,
    parameter NVC = 1,
    parameter CPL_LUT_DEPTH = 32
  ) 
                         (
  input                           radm_clk_ug,            // Ungated version of the radm_clk
  input                           core_rst_n,             // Core reset
  input                           clock_gating_en,        // Enable clock gating in the RADM
  input                           sb_init_done,           // Segmented buffer initialization complete
  input                           rtlh_radm_pending,      // transfer pending in the transaction layer
  input                           radm_cpl_lut_pending,   // CPL LUT pending flag 
  input [(CPL_LUT_DEPTH - 1) : 0] radm_cpl_lut_valid,     // completion lookup table valid indication
  input                           radm_cpl_lut_busy,      // CPL LUT pending flag
  input [(NVC - 1) : 0]           radm_q_not_empty,       // Queues are not empty
  input                           radm_trgt0_hv,          // Valid header on trgt0 interface
  input                           radm_trgt0_dv,          // Valid data on trgt0 interface
  input                           radm_trgt1_hv,          // Valid header on trgt1 interface
  input                           radm_trgt1_dv,          // Valid data on trgt1 interface
  input                           radm_rtlh_crd_pending,  // Credit transfer pending to RTLH
  output logic                    radm_idle,              // Radm idle flag
  output logic                    radm_clk_en             // Enable the RADM clock
);

// -----------------------------------------------------------------------------
// Local Parameter Declaration
// -----------------------------------------------------------------------------
// Parameters used to calculate the latency for the receive path
localparam FIXED_LATENCY = 5; // 1 radm formation + 1 radm_filter + 1 radm_inq_mgr + 1 sbc + 1 trgt0/trgt1 i/f register

localparam LATENCY_MULTIPLIER =                                1 
;
localparam QUEUE_LATENCY = LATENCY_MULTIPLIER * (
                            `CX_FLT_Q_REGOUT

                            + `CX_RADM_INQ_MGR_REGOUT // radm_inq_mgr output register
                            + `CX_RADM_RAM_WR_REGOUT
                            + `CX_RADM_RAM_RD_CTL_REGOUT
                            + `CX_RADM_RAM_RD_LATENCY
                            );

// Receive path latency
localparam RX_LATENCY = FIXED_LATENCY + QUEUE_LATENCY;                   

// Parameters used to calculated latency for the CPL LUT write path
localparam CPL_LUT_LATENCY = 1 + `CX_RADM_CPL_LUT_PIPE_EN_VALUE + XTLH_PIPE_DELAY;

// -----------------------------------------------------------------------------
// Logic Declaration
// -----------------------------------------------------------------------------
logic int_radm_idle_s;
logic int_radm_clk_en_s;
logic int_radm_idle_r;
logic int_radm_clk_en_r;
logic rx_req_in_s;
logic rx_busy_s;

// -----------------------------------------------------------------------------
// Idleness detection for the receive path
// -----------------------------------------------------------------------------
// TLP pending from Transaction layer or segmented buffer is being initialised
assign rx_req_in_s = rtlh_radm_pending || !sb_init_done;
// Receiver busy indication if formation queue is not empty, or receive queues are not empty
// or if a transfer is pending on the TRGT0/TRGT1/CCIX/Bypass Interfaces
assign rx_busy_s = (|radm_q_not_empty)
                    || radm_trgt1_hv || radm_trgt1_dv
                    || radm_trgt0_hv || radm_trgt0_dv
                    || radm_rtlh_crd_pending;

// Shift register for idle detection
radm_idle_detect
 #(
  .DEPTH  (RX_LATENCY)
  ) u_rx_idle_detect (
  .clk        (radm_clk_ug),
  .rst_n      (core_rst_n),
  .req        (rx_req_in_s),
  .pending    (rx_busy_s),
  .radm_idle  (radm_rx_idle_s)
);

// -----------------------------------------------------------------------------
// Idleness detection for the CPL LUT the LUT is busy when the CPL LUT pending flags are asserted
// -----------------------------------------------------------------------------
logic cpl_lut_busy_s;
assign cpl_lut_busy_s = (|radm_cpl_lut_valid) || radm_cpl_lut_busy; 

// Shift register for idle detection
radm_idle_detect
 #(
  .DEPTH  (CPL_LUT_LATENCY)
  ) u_cpl_lut_idle_detect (
  .clk        (radm_clk_ug),
  .rst_n      (core_rst_n),
  .req        (radm_cpl_lut_pending),
  .pending    (cpl_lut_busy_s),
  .radm_idle  (radm_cpl_lut_idle_s)
);


// RADM idle indication depends on flr request, receive path idle indication and CPL LUT idle indication
assign int_radm_idle_s =                          radm_rx_idle_s && radm_cpl_lut_idle_s;

assign int_radm_clk_en_s = clock_gating_en ? !int_radm_idle_s : 1'b1;

always_ff @(posedge radm_clk_ug or negedge core_rst_n) begin : idle_PROC
  if(!core_rst_n) begin
    int_radm_clk_en_r <= #TP 1'b1;
    int_radm_idle_r   <= #TP 1'b0;
  end
  else begin
    int_radm_clk_en_r <= #TP int_radm_clk_en_s;
    int_radm_idle_r   <= #TP int_radm_idle_s;
  end
end : idle_PROC

// If the FLR snoop architecture is enabled maintain the old functionality so that the FLR request is not registered before the clock gate enable
assign radm_clk_en = int_radm_clk_en_r;
assign radm_idle = int_radm_idle_r;

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule
