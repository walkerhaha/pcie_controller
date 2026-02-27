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
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/svif/xdlh_replay_num_if.svh#1 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__XDLH_REPLAY_NUM_IF__SVH__
`define __GUARD__XDLH_REPLAY_NUM_IF__SVH__

interface xdlh_replay_num_if ();

  logic         replay_num_incr;        // Increment the replay event counter
  logic         replay_num_reset;       // Reset the replay event counter
  logic         replay_num_retrain_ack; // Retrain acknowledge
  logic         replay_num_retrain_req; // Retrain request
  logic [2 : 0] replay_num;             // Replay event counter

  modport master_mp (
    output  replay_num_incr,
    output  replay_num_reset,
    output  replay_num_retrain_ack,
    input   replay_num_retrain_req,
    input   replay_num
  );

  modport slave_mp (
    input   replay_num_incr,
    input   replay_num_reset,
    input   replay_num_retrain_ack,
    output  replay_num_retrain_req,
    output  replay_num
  );


endinterface

`endif // __GUARD__XDLH_REPLAY_NUM_IF__SVH__
