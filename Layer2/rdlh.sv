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
// ---    $DateTime: 2020/01/17 02:36:30 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Data Link Layer Handler
// --- 1. Remove the LCRC and sequence number
// --- 2. Generate requests for ACK/NACK/DupACK transmission
// --- 3. Data link layer control state machine
// --- 4. Extraction of DLLP (received ACK/NACK, FC and PM DLLP, etc
// --- 5. Extraction of TLP
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rdlh(
    core_clk,
    core_rst_n,
    smlh_link_mode,
    smlh_link_up,
    cfg_dll_lnk_en,
    rtlh_fci_done,
    rtlh_fci1_fci2,
    rmlh_rdlh_dllp_start,
    rmlh_rdlh_tlp_start,
    rmlh_rdlh_pkt_end,
    rmlh_rdlh_pkt_edb,
    rmlh_rdlh_pkt_data,
    rmlh_rdlh_pkt_dv,
    rmlh_rdlh_pkt_err,
    rmlh_rdlh_nak,
    xdlh_rdlh_last_xmt_seqnum,
    nak_scheduled,

    // ------------- outputs --------------------
    rdlh_xdlh_rcvd_nack,
    rdlh_xdlh_rcvd_ack,
    rdlh_xdlh_rcvd_acknack_seqnum,
    rdlh_rtlh_rcvd_dllp,
    rdlh_rtlh_dllp_content,
    rdlh_rtlh_tlp_sot,
    rdlh_rtlh_tlp_dv,
    rdlh_rtlh_tlp_eot,
    rdlh_rtlh_tlp_data,
    rdlh_rtlh_tlp_abort,
    rdlh_xdlh_req2send_ack,
    rdlh_xdlh_req2send_ack_due2dup,
    rdlh_xdlh_req2send_nack,
    rdlh_xdlh_req_acknack_seqnum,
`ifndef SYNTHESIS
`endif // SYNTHESIS
    rdlh_link_up,
    rdlh_link_down,
    rdlh_rtlh_link_state,
    rdlh_bad_dllp_err,
    rdlh_bad_tlp_err,
    rdlh_prot_err,
    rdlh_rcvd_as_req_l1,
    rdlh_rcvd_pm_enter_l1,
    rdlh_rcvd_pm_enter_l23,
    rdlh_rcvd_pm_req_ack

);
parameter INST          = 0;                                    // The uniquifying parameter for each port logic instance.
parameter NW            = `CX_NW;                               // Number of dwords handled by the datapath each clock.
parameter NB            = `CX_NB;                               // Number of bytes per cycle per lane
parameter DW            = (32*NW);                              // Width of datapath in bits.
parameter RX_NDLLP      = (NW>>1 == 0) ? 1 : NW>>1;             // Max number of DLLPs received per cycle
parameter TP            = `TP;                                  // Clock to Q delay (simulator insurance)
parameter DATA_PAR_WD   = `TRGT_DATA_PROT_WD;
localparam RX_TLP       = `CX_RX_TLP;                           // Number of TLPs that can be processed in this block in a single cycle


//------------------------------------------------------------------------------
// Inputs
//------------------------------------------------------------------------------

input                   core_clk;                               // core clock
input                   core_rst_n;                             // core reset
    // from XPLH
input   [5:0]           smlh_link_mode;                         // MAC layer indicated link mode (x1,x2,x4,x8,x16)
input                   smlh_link_up;                           // when asserted XPLH link up.
input                   cfg_dll_lnk_en;                         // DLL link enable to allow link up
    // from RTLH
input                   rtlh_fci_done;                          // RTLH flow control init done.
input                   rtlh_fci1_fci2;                         // RTLH flow control init 1 and init 2.
    // from RPLH
input   [NW-1:0]        rmlh_rdlh_dllp_start;                   // 1-4  for 4dword, indicates which DW is start of DLP
input   [NW-1:0]        rmlh_rdlh_tlp_start;                    // 1-4  for 4dword, indicates which DW is start of TLP
input   [NW-1:0]        rmlh_rdlh_pkt_end;                      // 1-4  for 4dword, indicates which DW is pkt good end
input   [NW-1:0]        rmlh_rdlh_pkt_edb;                      // 1-4  for 4dword, indicates which DW is pkt bad end
input   [DW-1:0]        rmlh_rdlh_pkt_data;                     // packet data bus.
input                   rmlh_rdlh_pkt_dv;                       // when asserted, packet data is valid.
input   [NW-1:0]        rmlh_rdlh_pkt_err;                       // when asserted, framing error or phy_error
input   [NW-1:0]        rmlh_rdlh_nak;                          // NAK indication
    // from XDLH
input   [11:0]          xdlh_rdlh_last_xmt_seqnum;              // the last transmitted highest sequence number of TLP's DLLP. Receiver needs this signal to identify out of order TLP
input                   nak_scheduled;                          // dllp generation block requests nak is scheduled to be transmitted

//------------------------------------------------------------------------------
// Outputs
//------------------------------------------------------------------------------


    // to XDLH
output                  rdlh_xdlh_rcvd_nack;                    // RDLH pulse signal to indicate that there was a NACK PKT received, and its nack sequence number drove to RDLH_RCVD_ACKNACK_SEQ_NUM
output                  rdlh_xdlh_rcvd_ack;                     // RDLH pulse signal to indicate that there was a ACK PKT received, and its ACK sequence number drove to RDLH_RCVD_ACKNACK_SEQ_NUM
output  [11:0]          rdlh_xdlh_rcvd_acknack_seqnum;          // 12 bits indicated the sequence number of received ACK/NACK DLLP Packet
    // to RTLH
output  [RX_NDLLP-1:0]     rdlh_rtlh_rcvd_dllp;                 // When asserted, it indicates it is DLLP1 packet (Each words could carry two DLLP packets)
output  [32*RX_NDLLP-1:0]  rdlh_rtlh_dllp_content;              // The received DLLP packet
output                  rdlh_rtlh_tlp_dv;                       // TLP packet data valid
output  [RX_TLP-1:0]    rdlh_rtlh_tlp_abort;                    // TLP packet abort due to DLLP layer error detected
output  [NW-1:0]        rdlh_rtlh_tlp_sot;                      // When asserted, it indicates the Start of a TLP pkt
output  [NW-1:0]        rdlh_rtlh_tlp_eot;                      // When asserted, it indicates the end of a good TLP pkt
output  [DW+DATA_PAR_WD-1:0] rdlh_rtlh_tlp_data;                // Current TLP header and data
    // to XDLH
output                  rdlh_xdlh_req2send_ack;                 // RDLH received a good packet and has been asked to send an ACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
output                  rdlh_xdlh_req2send_ack_due2dup;         // RDLH received a packet that is a duplicated PKT . RDLH_REQ2SEND_ACK signal will be asserted while RDLH_RCVD_DUP is asserted.
output                  rdlh_xdlh_req2send_nack;                // RDLH received a good packet and has been asked to send an NACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
output  [11:0]          rdlh_xdlh_req_acknack_seqnum;           // RDLH received a packet with this sequence number
`ifndef SYNTHESIS
`endif // SYNTHESIS
output                  rdlh_link_up;                           // RDLH link is up.
output                  rdlh_link_down;                         // RDLH link is down.
    // to RTLH
output  [1:0]           rdlh_rtlh_link_state;                   // RDLH link up FSM current state.
output                  rdlh_prot_err;                          // protocol err of DLLP layer
output                  rdlh_bad_dllp_err;                      // bad dllp error detected in DLLP layer
output                  rdlh_bad_tlp_err;                       // Bad TLP error detected in DLLP layer
output                  rdlh_rcvd_as_req_l1;                    // Received PM DLLP (as request L1)
output                  rdlh_rcvd_pm_enter_l1;                  // Received PM DLLP (PM enter L1)
output                  rdlh_rcvd_pm_enter_l23;                 // Received PM DLLP (PM enter L23)
output                  rdlh_rcvd_pm_req_ack;                   // Received PM DLLP (pm request ack)


// -----------------------------------------------------------------------------
// Internal Wires
// -----------------------------------------------------------------------------



wire                    rdlh_link_up;
wire                    rdlh_link_down;
wire                    tlp_crc_match;

wire    [31:0]          tlp_crc;
wire    [NW-1:0]        tlp_aligned_sot, tlp_aligned_eot, tlp_aligned_edb;
wire                    tlp_aligned_dv;
wire    [11:0]          tlp_seqnum;
wire    [11:0]          tlp_seqnum_early;
wire                    rcvd_reserved_dllp_type;
wire                    rcvd_dllp_outseq;

wire rdlh_prot_err;
assign rdlh_prot_err      = rcvd_dllp_outseq;

wire    [1:0]           rdlh_rtlh_link_state;                   // RDLH link up FSM current state.


// drive link up state of dllp to the upper layer

// link control block does a small taks of monitoring the phy layer and generated the link control state machine for DL layer.
rdlh_link_cntrl

#(INST) u_rdlh_link_cntrl(
    .core_clk               (core_clk),
    .core_rst_n             (core_rst_n),
    .smlh_link_up           (smlh_link_up),
    .cfg_dll_lnk_en         (cfg_dll_lnk_en),
    .rtlh_fci_done          (rtlh_fci_done),
    .rtlh_fci1_fci2         (rtlh_fci1_fci2),

// ---- outputs ---------------
    .rdlh_link_up           (rdlh_link_up),
    .rdlh_link_down         (rdlh_link_down),
    .rdlh_dlcntrl_state     (rdlh_rtlh_link_state)
);

// -----------------------------------------------------------------------------
// tlp extract block does the alignment of tlp data that comes from PHY layer
// at PHY layer, the pkt is sent to DL layer at its arrival order. It was simply
// pasted into a bus with start and end indication of a packet.
// therefore, we need to align the data from PHY layer and to extract the tlp out of
// mixed DLPs.
// this block does two thing:
// 1. identify TLPs and align it to a tlp bus. The possible two location of
//    TLP starts at 1st dword or the last dword since there is minimum of 8bytes cut from a pkt received from PHY to a TLP extract.
// 2. generated the start and end of TLP location indications. Due to the back2back TLP rcvd, we currently designed 4bits to indicate Start of TLP within bus.
//    The allowable location is 0001, or 1000 (1st or last dword start)
//    The allowable location for the end of a tlp could be 0001,0010, 0100, 1000, (1st, 2nd, 3rd and last dword).

rdlh_tlp_extract

#(INST) u_rdlh_tlp_extract(
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .rdlh_link_up               (rdlh_link_up),
    .rmlh_rdlh_tlp_start        (rmlh_rdlh_tlp_start),
    .rmlh_rdlh_pkt_end          (rmlh_rdlh_pkt_end),
    .rmlh_rdlh_pkt_edb          (rmlh_rdlh_pkt_edb),
    .rmlh_rdlh_pkt_data         (rmlh_rdlh_pkt_data),
    .rmlh_rdlh_pkt_dv           (rmlh_rdlh_pkt_dv),
    .rmlh_rdlh_pkt_err          (rmlh_rdlh_pkt_err),
    .rmlh_rdlh_nak              (rmlh_rdlh_nak),
    .nak_scheduled              (nak_scheduled),

// ---- outputs ---------------

    

    .rdlh_req2send_ack          (rdlh_xdlh_req2send_ack),
    .rdlh_req2send_ack_due2dup  (rdlh_xdlh_req2send_ack_due2dup),
    .rdlh_req2send_nack         (rdlh_xdlh_req2send_nack),
`ifndef SYNTHESIS
`endif // SYNTHESIS
    .rdlh_req_acknack_seqnum    (rdlh_xdlh_req_acknack_seqnum),
    .rdlh_rtlh_tlp_data         (rdlh_rtlh_tlp_data),
    .rdlh_rtlh_tlp_dv           (rdlh_rtlh_tlp_dv),
    .rdlh_rtlh_tlp_sot          (rdlh_rtlh_tlp_sot),
    .rdlh_rtlh_tlp_eot          (rdlh_rtlh_tlp_eot),
    .rdlh_rtlh_tlp_abort        (rdlh_rtlh_tlp_abort),
    .rdlh_bad_tlp_err           (rdlh_bad_tlp_err)
);

// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// The DLP extract block does all the DL layer DLP packet extraction from the data coming from the PHY layer.
// 1.The block identify the DLPs and does the checksum for every DLP
// 2.All violation of DLPs and DL protocol errors are checked in this block
// 3. ACK/NACK monitoring and signaling to XDLH to release the retry buffer resources in XDLH.

rdlh_dlp_extract

#(INST) u_rdlh_dlp_extract(
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .rdlh_dlcntrl_state         (rdlh_rtlh_link_state),
    .rmlh_rdlh_dllp_start       (rmlh_rdlh_dllp_start),
    .rmlh_rdlh_pkt_end          (rmlh_rdlh_pkt_end),
    .rmlh_rdlh_pkt_edb          (rmlh_rdlh_pkt_edb),
    .rmlh_rdlh_pkt_data         (rmlh_rdlh_pkt_data),
    .rmlh_rdlh_pkt_dv           (rmlh_rdlh_pkt_dv),
    .xdlh_rdlh_last_xmt_seqnum  (xdlh_rdlh_last_xmt_seqnum),
    .rmlh_rdlh_pkt_err          (rmlh_rdlh_pkt_err),

// ---- outputs ---------------
    .rdlh_rcvd_nack             (rdlh_xdlh_rcvd_nack),
    .rdlh_rcvd_ack              (rdlh_xdlh_rcvd_ack),
    .rdlh_rcvd_acknack_seqnum   (rdlh_xdlh_rcvd_acknack_seqnum),
    .rdlh_rcvd_dllp             (rdlh_rtlh_rcvd_dllp),
    .rdlh_rcvd_dllp_content     (rdlh_rtlh_dllp_content),
    .rcvd_dllp_outseq           (rcvd_dllp_outseq),
    .rdlh_bad_dllp_err          (rdlh_bad_dllp_err),
    .rdlh_rcvd_as_req_l1        (rdlh_rcvd_as_req_l1),
    .rdlh_rcvd_pm_enter_l1      (rdlh_rcvd_pm_enter_l1),
    .rdlh_rcvd_pm_enter_l23     (rdlh_rcvd_pm_enter_l23),
    .rdlh_rcvd_pm_req_ack       (rdlh_rcvd_pm_req_ack)
);



endmodule
