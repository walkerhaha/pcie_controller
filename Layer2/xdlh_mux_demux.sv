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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_mux_demux.sv#1 $
// -------------------------------------------------------------------------
// --- Function Description:
// -----------------------------------------------------------------------------
// --- Mux to select inputs from Flit mode or non-flit mode XDLH 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module xdlh_mux_demux (
  input flit_mode,                                    // Flit Mode Enabled
  xdlh_replay_timer_if.slave_mp   b_xdlh_replay,      // XDLH Replay Timer Interface
  xdlh_replay_timer_if.master_mp  b_mux_replay,       // Muxed Replay Timer Interface
  xdlh_replay_num_if.slave_mp     b_xdlh_replay_num,  // XDLH Replay Timer Interface
  xdlh_replay_num_if.master_mp    b_mux_replay_num    // Muxed Replay Timer Interface
);

// MUX between flit mode and non-flit mode signals
always_comb begin : xdlh_mux_proc
  // In flit mode connect to the interface from xdlh_fm
  if (flit_mode) begin
    // REPLAY TIMER INTERFACE
    b_mux_replay.replay_timer_start = 1'b0;
    b_mux_replay.replay_timer_hold = 1'b0;
    b_mux_replay.replay_timer_reset = 1'b0;
    b_mux_replay.replay_ack = 1'b0;
    // REPLAY NUM INTERFACE
    b_mux_replay_num.replay_num_incr = 1'b0;
    b_mux_replay_num.replay_num_reset = 1'b0;
    b_mux_replay_num.replay_num_retrain_ack = 1'b0;
  // In non-flit mode connect to the interface from xdlh
  end else begin
    // REPLAY TIMER INTERFACE
    b_mux_replay.replay_timer_start = b_xdlh_replay.replay_timer_start;
    b_mux_replay.replay_timer_hold = b_xdlh_replay.replay_timer_hold;
    b_mux_replay.replay_timer_reset = b_xdlh_replay.replay_timer_reset;
    b_mux_replay.replay_ack = b_xdlh_replay.replay_ack;
    // REPLAY NUM INTERFACE
    b_mux_replay_num.replay_num_incr = b_xdlh_replay_num.replay_num_incr;
    b_mux_replay_num.replay_num_reset = b_xdlh_replay_num.replay_num_reset;
    b_mux_replay_num.replay_num_retrain_ack = b_xdlh_replay_num.replay_num_retrain_ack;
  end
end : xdlh_mux_proc

// DEMUX between flit mode and non-flit mode signals
always_comb begin : xdlh_demux_proc
  // In Flit Mode drive xdlh_fm interface
  if (flit_mode) begin
    // REPLAY TIMER INTERFACE
    b_xdlh_replay.replay_req = 1'b0;
    b_xdlh_replay.replay_timer = 'h0;
    // REPLAY NUM INTERFACE
    b_xdlh_replay_num.replay_num_retrain_req = 1'b0;
    b_xdlh_replay_num.replay_num = 'h0;
  end
  // In Non-Flit Mode drive xdlh interface
  else begin
    // REPLAY TIMER INTERFACE
    b_xdlh_replay.replay_req = b_mux_replay.replay_req;
    b_xdlh_replay.replay_timer = b_mux_replay.replay_timer;
    // REPLAY NUM INTERFACE
    b_xdlh_replay_num.replay_num_retrain_req = b_mux_replay_num.replay_num_retrain_req;
    b_xdlh_replay_num.replay_num = b_mux_replay_num.replay_num;
  end
end : xdlh_demux_proc

endmodule

