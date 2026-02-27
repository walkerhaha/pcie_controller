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
// --- RCS information:
// ---   $DateTime: 2020/09/25 12:53:35 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Transmit Link Layer Packet Generation.
// This module manages the interface between the Link Layers and the Physical Layer.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/tx_lp_if.svh"

module xplh
#(
  parameter NW = `CX_NW,
  parameter DW = (32*NW),
  parameter INST = 0
) (
  // Interfaces
  tx_lp_if.slave_mp                 b_xdlh_xplh_sp,             // Link Layer Transmit Slave Port XDLH->XPLH
  tx_lp_if.master_mp                b_xplh_xmlh_mp,             // Link Layer Transmit Slave Port XPLH->XMLH
  // Inputs
  input                             core_clk,
  input                             core_rst_n
);

// XDLH XPLH Interface connected directly to the XMLH if CXL is not enabled
assign b_xdlh_xplh_sp.halt_in     = b_xplh_xmlh_mp.halt_in;
assign b_xplh_xmlh_mp.data_out    = b_xdlh_xplh_sp.data_out;
assign b_xplh_xmlh_mp.stp         = b_xdlh_xplh_sp.stp;
assign b_xplh_xmlh_mp.sdp         = b_xdlh_xplh_sp.sdp;
assign b_xplh_xmlh_mp.eot         = b_xdlh_xplh_sp.eot;
assign b_xplh_xmlh_mp.pad         = b_xdlh_xplh_sp.pad;
assign b_xplh_xmlh_mp.next_eot    = b_xdlh_xplh_sp.next_eot;
assign b_xplh_xmlh_mp.next_stp    = b_xdlh_xplh_sp.next_stp;
assign b_xplh_xmlh_mp.next_sdp    = b_xdlh_xplh_sp.next_sdp;

// Data Valid Indication not used in XMLH
assign b_xplh_xmlh_mp.data_valid  = 1'b0;

// Signals connected directly from XMLH to XDLH
assign b_xdlh_xplh_sp.skip_pending  = b_xplh_xmlh_mp.skip_pending;
assign b_xdlh_xplh_sp.cmd_is_data   = b_xplh_xmlh_mp.cmd_is_data;


endmodule
