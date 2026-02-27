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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_replay_num.sv#1 $
// -------------------------------------------------------------------------
// --- Function Description:
// -----------------------------------------------------------------------------
// This module implements the replay event counter which is used to trigger a link retrain.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/xdlh_replay_num_if.svh"

module xdlh_replay_num #(
  parameter TP = `TP
) (
  input                         core_clk,
  input                         core_rst_n,
  input                         rdlh_link_up,           // DL_UP indication
  xdlh_replay_num_if.slave_mp   b_replay_num            // Replay number slave modport
);

// Logic Declarations
logic [2 : 0] replay_num;

// Replay Event Couter
always @ (posedge core_clk or negedge core_rst_n) begin : replay_num_proc
  if (!core_rst_n)
    replay_num  <= #TP 3'b0;
  // Hold in reset when the link is down
  else if ( !rdlh_link_up )
    replay_num  <= #TP 3'b0;
  // Clear on link training or received updated sequence number
  else if (b_replay_num.replay_num_retrain_ack | b_replay_num.replay_num_reset) begin // when link retraining ends or ack/nak received with advanced sequence number
    if( b_replay_num.replay_num_retrain_ack ) // when link retraining ends clear only the bit that is used to hold link_retrain_pending
      replay_num[2] <= #TP 1'b0;
    if ( b_replay_num.replay_num_reset ) // clear the replay count on ack/nak received
      replay_num[1:0] <= #TP 2'b0;
  // Increment when a replay is requested
  end else if (b_replay_num.replay_num_incr)
    replay_num[2:0] <= #TP (replay_num + 1'b1);
end : replay_num_proc

assign b_replay_num.replay_num_retrain_req = replay_num[2]; // use bit 2 to hold the condition that a link retrain must be performed before proceeding with a 4th replay
assign b_replay_num.replay_num = replay_num;

endmodule
