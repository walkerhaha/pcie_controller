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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/svif/xdlh_replay_timer_if.svh#1 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__XDLH_REPLAY_TIMER_IF__SVH__
`define __GUARD__XDLH_REPLAY_TIMER_IF__SVH__

interface xdlh_replay_timer_if ();

  logic           replay_timer_start;
  logic           replay_timer_hold;
  logic           replay_timer_reset;
  logic           replay_req;
  logic           replay_ack;
  logic [16 : 0]  replay_timer;

  modport master_mp (
    output  replay_timer_start,
    output  replay_timer_hold,
    output  replay_timer_reset,
    output  replay_ack,
    input   replay_req,
    input   replay_timer
  );

  modport slave_mp (
    input   replay_timer_start,
    input   replay_timer_hold,
    input   replay_timer_reset,
    input   replay_ack,
    output  replay_req,
    output  replay_timer
  );


endinterface

`endif // __GUARD__XDLH_REPLAY_TIMER_IF__SVH__
