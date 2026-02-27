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
// ---    $DateTime: 2020/09/18 02:33:28 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles transmit transaction Layer. Its main functions are:
// --- (1) TX FC accounting
// --- (2) XTLH control state machine
// --- Note:
// --- (1) Application specific Layer 3 functions are implemented in ADM
// --- (2) TLP is pre-formed before coming in
// ---
// --- XTLH and XDLH interface protocol
// ---
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xtlh (
// ----- inputs------
    core_clk,
    core_rst_n,
    rstctl_core_flush_req,
    xdlh_xtlh_halt,
    xadm_xtlh_hv,
    xadm_xtlh_soh,
    xadm_xtlh_hdr,
    xadm_xtlh_dv,
    xadm_xtlh_data,
    xadm_xtlh_dwen,
    xadm_xtlh_eot,
    xadm_xtlh_bad_eot,
    xadm_xtlh_add_ecrc,
    xadm_xtlh_vc,



    pm_xtlh_block_tlp,
    cfg_p2p_track_cpl_to,
    device_type,

// ----- Outputs-----
    xtlh_xadm_halt,
    xtlh_xdlh_sot,
    xtlh_xdlh_data,

   xtlh_xdlh_dwen,

    xtlh_xdlh_eot,
    xtlh_xdlh_dv,
    xtlh_xdlh_badeot,
    xtlh_sot_is_first,
    xtlh_badeot,
    xtlh_first_badeot,
    xtlh_eot_sot,
    xtlh_eot_sot_eot,

    xtlh_xmt_cpl_ca,
    xtlh_xmt_cpl_ur,
    xtlh_xmt_cpl_poisoned,
    xtlh_xmt_wreq_poisoned,
    xtlh_tlp_pending,
    xtlh_data_parerr,
    // from xtlh for keeping track of completions and handling of completions
    xtlh_xmt_tlp_done,
    xtlh_xmt_tlp_done_early,
    xtlh_xmt_tlp_req_id,
    xtlh_xmt_tlp_tag,
    xtlh_xmt_tlp_attr,
    xtlh_xmt_cfg_req,
    xtlh_xmt_memrd_req,
    xtlh_xmt_ats_req,
    xtlh_xmt_atomic_req,
    xtlh_xmt_tlp_tc,
    xtlh_xmt_tlp_len_inbytes,
    xtlh_xmt_tlp_first_be,
    xtlh_xadm_restore_enable,    
    xtlh_xadm_restore_capture,
    xtlh_xadm_restore_tc,
    xtlh_xadm_restore_type,
    xtlh_xadm_restore_word_len
);
parameter INST              = 0;                    // The uniquifying parameter for each port logic instance.
parameter NVC               = `CX_NVC;              // Number of VC channels
parameter NF                = `CX_NFUNC;            // Number of functions
parameter NW                = `CX_NW;               // Number of 32-bit dwords handled by the datapath each clock.
parameter DATA_PAR_WD       = `TRGT_DATA_PROT_WD;      // data bus parity width
parameter DW_W_PAR          = (32*NW)+DATA_PAR_WD;  // Width of datapath in bits plus the parity bits.
parameter DW_WO_PAR         = (32*NW);              // Width of datapath in bits.
parameter RAS_PCIE_HDR_PROT_WD  = `CX_RAS_PCIE_HDR_PROT_WD;
parameter RAS_PCIE_HDR_WD   = 128 + RAS_PCIE_HDR_PROT_WD;
parameter TP                = `TP;                  // Clock to Q delay (simulator insurance)
parameter L2N_INTFC         = 1;

parameter CTL_WD = `CX_XTLH_XDLH_CTL_WD; // (NW == 2)? 1 : @CX_NW

parameter DEVNUM_WD         = `CX_DEVNUM_WD;


localparam TAG_SIZE = `CX_TAG_SIZE;


// =============================================================================
// -------------------------------- Inputs -------------------------------------
// =============================================================================
input                       core_clk;
input                       core_rst_n;
input                       rstctl_core_flush_req;
// XADM/XTLH interface
input [1:0]                 xadm_xtlh_soh;          // Start of Header for 32/64 bit ARC.
input                       xadm_xtlh_hv;           // Header valid on bus when asserted
input [RAS_PCIE_HDR_WD-1:0] xadm_xtlh_hdr;          // 128 bits header bus from XADM
input                       xadm_xtlh_dv;           // data valid on bus when asserted, it may not occur for non-posted pkt
input [DW_W_PAR-1:0]        xadm_xtlh_data;         // 128 bits data bus from XADM
input [NW-1:0]              xadm_xtlh_dwen;
input                       xadm_xtlh_eot;          // end of transaction
input                       xadm_xtlh_add_ecrc;
input [2:0]                 xadm_xtlh_vc;           // vc number
input                       xdlh_xtlh_halt;         // stop xtlh xmt immediatelly
input                       xadm_xtlh_bad_eot;      // append bad EOT
input                       pm_xtlh_block_tlp;



input                       cfg_p2p_track_cpl_to; // P2P_TRACK_CPL_TO_REG
input [3:0]                 device_type;

// =============================================================================
// ------------------------------- Outputs -------------------------------------
// =============================================================================

output                      xtlh_xadm_halt;         // when asserted, XADM data bus advances to next data

// XTLH/XDLH interface
output  [CTL_WD-1:0]        xtlh_xdlh_sot;          // XTLH pushes down packet start with this signal pulsed;
output  [DW_W_PAR-1:0]      xtlh_xdlh_data;         // XTLH outputs header/data bus to XDLH
output  [NW-1:0]            xtlh_xdlh_dwen;         // XTLH outputs dword enable for header/data bus to XDLH
output  [CTL_WD-1:0]        xtlh_xdlh_eot;          // XTLH pushes down packet end with this signal pulsed
output                      xtlh_xdlh_dv;           // XTLH pushes down packet down qualified by this data
output  [CTL_WD-1:0]        xtlh_xdlh_badeot;       // XTLH wish to xmt a TLP packet with bad end. This signal is qualified by eot

output  [NF-1:0]            xtlh_xmt_cpl_ca;
output  [NF-1:0]            xtlh_xmt_cpl_ur;
output  [NF-1:0]            xtlh_xmt_cpl_poisoned;
output  [NF-1:0]            xtlh_xmt_wreq_poisoned;
output                      xtlh_tlp_pending;
output                      xtlh_data_parerr;       // indicates that XTLH has detected the parity error on data bus
output                      xtlh_xmt_tlp_done;
output                      xtlh_xmt_tlp_done_early; // unregistered version of xtlh_xmt_tlp_done used to ungate RADM clock
output  [15:0]              xtlh_xmt_tlp_req_id;    // interface id, it is designed to identify which interface the completion belongs to.
output  [TAG_SIZE-1:0]      xtlh_xmt_tlp_tag;
output  [1:0]               xtlh_xmt_tlp_attr;
output                      xtlh_xmt_cfg_req;
output                      xtlh_xmt_memrd_req;
output                      xtlh_xmt_ats_req;
output                      xtlh_xmt_atomic_req;
output  [2:0]               xtlh_xmt_tlp_tc;
output  [11:0]              xtlh_xmt_tlp_len_inbytes;
output  [3:0]               xtlh_xmt_tlp_first_be;
output                      xtlh_xadm_restore_enable;
output                      xtlh_xadm_restore_capture;
output  [2:0]               xtlh_xadm_restore_tc;
output  [6:0]               xtlh_xadm_restore_type;
output  [9:0]               xtlh_xadm_restore_word_len;


output xtlh_sot_is_first;
output xtlh_eot_sot_eot;
output xtlh_badeot;
output xtlh_first_badeot;
output xtlh_eot_sot;


// =============================================================================
// I/O Signal declaration
// =============================================================================
wire xtlh_sot_is_first;
wire xtlh_eot_sot_eot;
wire xtlh_badeot;
wire xtlh_first_badeot;
wire xtlh_eot_sot;
wire xtlh_sot_is_first_int;
wire xtlh_eot_sot_eot_int;
wire xtlh_badeot_int;
wire xtlh_first_badeot_int;
wire xtlh_eot_sot_int;

wire    [CTL_WD-1:0]        xtlh_xdlh_sot;          // XTLH pushes down packet start with this signal pulsed
wire    [DW_W_PAR-1:0]      xtlh_xdlh_data;         // XTLH outputs header/data bus to XDLH
wire    [NW-1:0]            xtlh_xdlh_dwen;         // XTLH outputs dword enable for header/data bus to XDLH
wire    [CTL_WD-1:0]        xtlh_xdlh_eot;          // XTLH pushes down packet end with this signal pulsed
wire                        xtlh_xdlh_dv;           // XTLH pushes down packet down qualified by this data
wire    [CTL_WD-1:0]        xtlh_xdlh_badeot;       // XTLH wish to xmt a TLP packet with bad end. This signal is qualified by eot
wire    [CTL_WD-1:0]        xtlh_xdlh_badeot_int;

wire                        xtlh_xadm_halt;         // when asserted, XADM advances next data


// =============================================================================
// Internal signals declaration
// =============================================================================
wire                        xtlh_xdlh_dv_int;
wire    [CTL_WD-1:0]        xtlh_xdlh_sot_int;
wire    [CTL_WD-1:0]        xtlh_xdlh_eot_int;
wire                        xdlh_xtlh_halt_int;



//
// Merge header and data onto common bus
// This functionality could/should be merged with the control block
//
wire                        merged_tlp_dv;          // data valid
//wire                        merged_tlp_eot;         // end of transaction
//wire                        merged_tlp_badeot;      // end of transaction
//wire    [DW_W_PAR-1:0]      merged_tlp_data;
wire    [NW-1:0]            merged_tlp_dwen;
wire     [1:0]              merged_tlp_add_ecrc;
wire                        merged_par_err;

wire                        xtlh_ctrl_halt;         // Control block halts when it needs to insert CRC (or downstream halts)







// Cont. from here 25/12/2011


wire                merged_tlp_eot;         // end of transaction
wire                merged_tlp_badeot;      // end of transaction
wire [DW_W_PAR-1:0] merged_tlp_data;

wire [1:0]          merged_tlp_soh;
wire [NW-1:0]       merged_tlp_sot;



    assign merged_tlp_dv        = xadm_xtlh_dv;
    assign merged_tlp_data      = (xadm_xtlh_dv)? xadm_xtlh_data: {DW_W_PAR{1'b0}};
    assign merged_tlp_dwen      = xadm_xtlh_dwen;
    assign merged_tlp_eot       = xadm_xtlh_eot ;
    assign merged_tlp_badeot    = xadm_xtlh_bad_eot;
    assign merged_tlp_add_ecrc  = {1'b0, xadm_xtlh_add_ecrc};
    assign xtlh_xadm_halt       = xtlh_ctrl_halt;
    assign merged_par_err       = 0;

    assign merged_tlp_soh       = xadm_xtlh_soh;
    assign merged_tlp_sot       = {NW{1'b0}}; // Not used here












//------------------------------------------------------------------------------
// Control FSM
//------------------------------------------------------------------------------
xtlh_ctrl

#(INST) u_xtlh_ctrl (
    // inputs
    .core_rst_n                 (core_rst_n),
    .core_clk                   (core_clk),
    .merged_tlp_soh             (merged_tlp_soh),
    .merged_tlp_sot             (merged_tlp_sot),
    .merged_tlp_dv              (merged_tlp_dv),

    .merged_tlp_eot             (merged_tlp_eot),
    .merged_tlp_data            (merged_tlp_data),
    .merged_tlp_dwen            (merged_tlp_dwen),
    .merged_tlp_badeot          (merged_tlp_badeot),
    .merged_tlp_add_ecrc        (merged_tlp_add_ecrc),
    .merged_par_err             (merged_par_err),


    .xdlh_xtlh_halt             (xdlh_xtlh_halt_int),
    .pm_xtlh_block_tlp          (pm_xtlh_block_tlp),
    .device_type                (device_type),
// ---- outputs ---------------

    // outputs
    .xtlh_ctrl_halt             (xtlh_ctrl_halt),
    .xtlh_xdlh_sot              (xtlh_xdlh_sot_int),
    .xtlh_xdlh_eot              (xtlh_xdlh_eot_int),
    .xtlh_xdlh_dv               (xtlh_xdlh_dv_int),
    .xtlh_xdlh_dwen             (xtlh_xdlh_dwen),

//    .xtlh_xdlh_badeot           (xtlh_xdlh_badeot),
    .xtlh_xdlh_badeot           (xtlh_xdlh_badeot_int),

    .xtlh_xdlh_data             (xtlh_xdlh_data),

    .xtlh_sot_is_first          (xtlh_sot_is_first_int),
    .xtlh_eot_sot_eot           (xtlh_eot_sot_eot_int),
    .xtlh_badeot                (xtlh_badeot_int),
    .xtlh_first_badeot          (xtlh_first_badeot_int),
    .xtlh_eot_sot               (xtlh_eot_sot_int),

    .xtlh_xmt_cpl_ca            (xtlh_xmt_cpl_ca),
    .xtlh_xmt_cpl_ur            (xtlh_xmt_cpl_ur),
    .xtlh_xmt_cpl_poisoned      (xtlh_xmt_cpl_poisoned),
    .xtlh_xmt_wreq_poisoned     (xtlh_xmt_wreq_poisoned),
    .xtlh_data_parerr           (xtlh_data_parerr  ),
    // from xtlh for keeping track of completions and handling of completions
    .xtlh_xmt_tlp_done          (xtlh_xmt_tlp_done),
    .xtlh_xmt_tlp_done_early    (xtlh_xmt_tlp_done_early),
    .xtlh_xmt_tlp_req_id        (xtlh_xmt_tlp_req_id),
    .xtlh_xmt_tlp_tag           (xtlh_xmt_tlp_tag),
    .xtlh_xmt_tlp_attr          (xtlh_xmt_tlp_attr),
    .xtlh_xmt_cfg_req           (xtlh_xmt_cfg_req),
    .xtlh_xmt_memrd_req         (xtlh_xmt_memrd_req),
    .xtlh_xmt_ats_req           (xtlh_xmt_ats_req),
    .xtlh_xmt_atomic_req        (xtlh_xmt_atomic_req),
    .xtlh_xmt_tlp_tc            (xtlh_xmt_tlp_tc),
    .xtlh_xmt_tlp_len_inbytes   (xtlh_xmt_tlp_len_inbytes),
    .xtlh_xmt_tlp_first_be      (xtlh_xmt_tlp_first_be),
    .xtlh_xadm_restore_enable   (xtlh_xadm_restore_enable),
    .xtlh_xadm_restore_capture  (xtlh_xadm_restore_capture),
    .xtlh_xadm_restore_tc       (xtlh_xadm_restore_tc),
    .xtlh_xadm_restore_type     (xtlh_xadm_restore_type),
    .xtlh_xadm_restore_word_len (xtlh_xadm_restore_word_len)
);

// -----------------------------------------------------------------
// Assign outputs
// -----------------------------------------------------------------
// If flush request asserted sink transmit TLPs.

  wire rasdp_badeot; 
  assign rasdp_badeot = xtlh_xdlh_badeot_int;

assign xtlh_xdlh_dv       = rstctl_core_flush_req ? 0 : xtlh_xdlh_dv_int;
assign xtlh_xdlh_sot      = rstctl_core_flush_req ? 0 : xtlh_xdlh_sot_int;
assign xtlh_xdlh_eot      = rstctl_core_flush_req ? 0 : xtlh_xdlh_eot_int;
assign xtlh_xdlh_badeot   = rasdp_badeot;
assign xtlh_sot_is_first  = xtlh_sot_is_first_int;
assign xtlh_eot_sot_eot   = xtlh_eot_sot_eot_int;
assign xtlh_badeot        = xtlh_badeot_int;
assign xtlh_first_badeot  = xtlh_first_badeot_int;
assign xtlh_eot_sot       = xtlh_eot_sot_int;
assign xdlh_xtlh_halt_int = rstctl_core_flush_req ? 0 : xdlh_xtlh_halt;

xtlh_tracker

  // Parameters
  #(
    .NW     (NW),
    .EOT_WD (CTL_WD)
  ) u_xtlh_tracker (
    // Inputs
    .core_clk               (core_clk),
    .core_rst_n             (core_rst_n),
    .rasdp_flush_req        (1'b0),
    .xadm_xtlh_hv           (|xadm_xtlh_soh),
    .xtlh_xadm_halt         (xtlh_xadm_halt),
    .xtlh_xdlh_eot          (xtlh_xdlh_eot),
    .xdlh_xtlh_halt         (xdlh_xtlh_halt),
    .flush_req              (rstctl_core_flush_req),
    // Outputs
    .xtlh_tlp_pending       (xtlh_tlp_pending)
);


endmodule
