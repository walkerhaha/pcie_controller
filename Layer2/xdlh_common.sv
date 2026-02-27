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
// ---    $DateTime: 2020/09/11 01:49:10 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_common.sv#1 $
// -------------------------------------------------------------------------
// --- Function Description:
// -----------------------------------------------------------------------------
// --- This module contains logic which is used in both Flit Mode and Non-Flit Mode.
// --- Replay Timer
// --- Replay Event Counter
// --- Retrain Event Counter
// --- This module also implements MUX/DEMUX logic to select between Flit Mode
// --- and non-Flit Mode interface signals.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module xdlh_common (
  // Inputs
  input                         core_clk,
  input                         core_rst_n,
  input                         flit_mode,              // Indicates Flit Mode is enabled
  input [16 : 0]                cfg_replay_timer_value, // Replay timer value
  input                         rdlh_link_up,           // DL_UP indication
  // Interfaces
  xdlh_replay_timer_if.slave_mp b_xdlh_replay,          // Replay Timer Interface from xdlh
  //xdlh_replay_timer_if.slave_mp b_xdlh_fm_replay      // Replay Timer Interface from xdlh_fm
  xdlh_replay_num_if.slave_mp   b_xdlh_replay_num,      // Replay Timeout Event Counter
  // Outputs
  output logic                  xdlh_replay_timeout,    // Indicates that the replay timer expired
  output logic [16 : 0]         xdlh_replay_timer       // Replay timer
);

// Replay Timer Interface
xdlh_replay_timer_if b_replay();
xdlh_replay_num_if b_replay_num();

// XDLH MUX
xdlh_mux_demux
 u_mux_demux(
  .flit_mode          (flit_mode),
  .b_xdlh_replay      (b_xdlh_replay),
  .b_mux_replay       (b_replay.master_mp),
  .b_xdlh_replay_num  (b_xdlh_replay_num),
  .b_mux_replay_num   (b_replay_num.master_mp)
);

// Instantiate the replay timer
xdlh_replay_timer
 u_replay_timer(
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .cfg_replay_timer_value     (cfg_replay_timer_value),
  .b_replay                   (b_replay.slave_mp),
  .replay_timeout_re          (xdlh_replay_timeout)
);

assign xdlh_replay_timer = b_xdlh_replay.replay_timer;

// Instantiate the replay timeout event counter
xdlh_replay_num
 u_replay_num(
  .core_clk     (core_clk),
  .core_rst_n   (core_rst_n),
  .rdlh_link_up (rdlh_link_up),
  .b_replay_num (b_replay_num.slave_mp)
);


endmodule
