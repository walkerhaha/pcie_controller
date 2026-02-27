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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_64b.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer Hander
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/xdlh_replay_timer_if.svh"
`include "Layer2/svif/xdlh_replay_num_if.svh"

 
 module xdlh_64b(
//  Interface Ports
    b_xdlh_xplh_mp,
// ---- inputs ---------------
    core_clk,
    core_rst_n,
    cfg_replay_timer_value,
    cfg_ack_freq,
    cfg_ack_latency_timer,
    cfg_flow_control_disable,
    cfg_acknack_disable,
    cfg_other_msg_payload,
    cfg_other_msg_request,
    cfg_corrupt_crc_pattern,
    smlh_in_l0,
    current_data_rate,
    phy_type,
    xtlh_xdlh_data,
    xtlh_xdlh_dwen,
    xtlh_xdlh_dv,
    xtlh_xdlh_sot,
    xtlh_xdlh_eot,
    xtlh_xdlh_badeot,
    rdlh_link_up,
    rdlh_link_state,
    rdlh_xdlh_rcvd_nack,
    rdlh_xdlh_rcvd_ack,
    rdlh_xdlh_rcvd_acknack_seqnum,
    rdlh_xdlh_req2send_ack,
    rdlh_xdlh_req2send_ack_due2dup,
    rdlh_xdlh_req2send_nack,
    rdlh_xdlh_req_acknack_seqnum,
    rtlh_xdlh_fc_req,
    rtlh_xdlh_fc_req_hi,
    rtlh_xdlh_fc_req_low,
    rtlh_xdlh_fc_data,
    xmlh_xdlh_halt,
    xdlh_xmlh_eot,
    smlh_link_mode,
    pm_xdlh_enter_l1,
    pm_xdlh_req_ack,
    pm_xdlh_enter_l23,
    pm_xdlh_actst_req_l1,
    pm_freeze_ack_timer,
    smlh_link_in_training,
    smlh_in_rcvry,

// ---- outputs ---------------

    xdlh_xtlh_halt,
    xdlh_rdlh_last_xmt_seqnum,
    xdlh_rtlh_fc_ack,
    xdlh_smlh_start_link_retrain,
    xdlh_curnt_seqnum,
    xdlh_retrybuf_not_empty,
    xdlh_not_expecting_ack,
    xdlh_xmt_pme_ack,
    xdlh_last_pmdllp_ack,
    xdlh_nodllp_pending,
    xdlh_no_acknak_dllp_pending,
    xdlh_tlp_pending,
    xdlh_retry_pending,


// Retry buffer external RAM interface
    xdlh_retryram_addr,
    xdlh_retryram_data,
    xdlh_retryram_we,
    xdlh_retryram_en,
    xdlh_retryram_par_chk_val,
    xdlh_retryram_halt,
    retryram_xdlh_data,
    retryram_xdlh_depth,
    retryram_xdlh_parerr,

// Performance changes - 2p RAM I/F
 //   xdlh_retrysotram_addr,
    xdlh_retrysotram_waddr,
    xdlh_retrysotram_raddr,
    xdlh_retrysotram_data,
    xdlh_retrysotram_en,
    xdlh_retrysotram_we,
    xdlh_retrysotram_par_chk_val,
    retrysotram_xdlh_data,
    retrysotram_xdlh_parerr,
    retrysotram_xdlh_depth,
    nak_scheduled,
    xdlh_retry_req
    ,
    rbuf_pkt_cnt,
    xdlh_match_pmdllp,
    xdlh_replay_timeout,
    xdlh_replay_timer
);

parameter   INST    = 0;        // The uniquifying parameter for each port logic instance.
parameter   NW      = 2;        // Number of 32-bit dwords handled by the datapath each clock.
parameter   NL      = `CX_NL;   // Number of lanes
parameter   DW      = (32*NW);  // Width of datapath in bits.
parameter   NB      = `CX_NB;   // Number of 32-bit dwords handled by the datapath each clock.
parameter   TX_NDLLP= 1;        // Max number of DLLPs send per cycle
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)

parameter   RBUF_WD     = `RBUF_WIDTH ;  // 1 parity error bit per dword
parameter   RBUF_PW     = `RBUF_PW;         // True pointer width is calculated from the depth of the memory
parameter   SOTBUF_WD   = `SOTBUF_WIDTH;
parameter   SOTBUF_DP   = `SOTBUF_DEPTH;                    // Indexed by sequence number (or some bits of it)
parameter   SOTBUF_PW   = `SOTBUF_L2DEPTH;               // Indexed by sequence number (or some bits of it)

parameter DATA_PAR_WD              = `TRGT_DATA_PROT_WD;      // data bus parity width
parameter DW_W_PAR                 = (32*NW)+DATA_PAR_WD;  // Width of datapath in bits plus the parity bits.


// =============================================================================
// ---- inputs ---------------
// =============================================================================
tx_lp_if     b_xdlh_xplh_mp; // Link Layer to Physical Layer master modport
xdlh_replay_timer_if  b_xdlh_replay();
xdlh_replay_num_if    b_xdlh_replay_num();
input                   core_clk;
input                   core_rst_n;
input   [16:0]          cfg_replay_timer_value;         // Replay Timer value.  Default value is expected to be chosen from table 3-4
input   [7:0]           cfg_ack_freq;                   // 8bits programmable value to allow up to 256 ack accumulated before send
input   [15:0]          cfg_ack_latency_timer;          // 16bits Spec called for array. We recommend to set array in cfg register block so that it is easier to control. We may want programmable value set by software.
input   [31:0]          cfg_other_msg_payload;          // special DLLP message register to allow user insert special DLLP message with this 32 bits data content.
input                   cfg_other_msg_request;          // special DLLP message register to allow user insert special DLLP message with this 32 bits data content.
input   [31:0]          cfg_corrupt_crc_pattern;        // How to corrupt CRC data -- normally just invert CRC. This value allows per-bit inversion.
input                   cfg_flow_control_disable;
input                   cfg_acknack_disable;
input                   smlh_in_l0;                     // XMLH layer report bakc that LTSSM is in L0 state so that we allow transmission from RTLH. This is to prevent TLPs enter into pipe too early
input   [2:0]           current_data_rate;              // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
input                   phy_type;                       // Phy Type
input   [DW_W_PAR-1:0]  xtlh_xdlh_data;                 // XTLH outputs header/data bus to XDLH
input   [NW-1:0]        xtlh_xdlh_dwen;                 // XTLH outputs header/data bus dword enable
input                   xtlh_xdlh_dv;                   // XTLH data is valid this cycle
input                   xtlh_xdlh_sot;                  // XTLH pushes down packet start with this signal pulsed,
input                   xtlh_xdlh_eot;                  // XTLH pushes down packet end with this signal pulsed
input                   xtlh_xdlh_badeot;              // XTLH wish to xmt a TLP packet with bad end. This signal is qualified by eot


input                   rdlh_link_up;                   // when asserted, it indicates that link control FSM is in link active state.
input   [1:0]           rdlh_link_state;

input                   rdlh_xdlh_rcvd_nack;            // when asserted, this pulse signal indicates that there was a NACK PKT received, and its nack sequence number driven to RDLH_RCVD_ACKNACK_SEQ_NUM
input                   rdlh_xdlh_rcvd_ack;             // when asserted, this pulse signal indicates that there was a ACK PKT received, and its ACK sequence number driven to RDLH_RCVD_ACKNACK_SEQ_NUM
input   [11:0]          rdlh_xdlh_rcvd_acknack_seqnum;  // 12 bits indicated the sequence number of received ACK/NACK DLLP Packet
input                   rdlh_xdlh_req2send_ack;         // RDLH received a good packet and has been asked to send an ACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
input                   rdlh_xdlh_req2send_ack_due2dup; // RDLH received a packet that is a duplicated PKT . RDLH_REQ2SEND_ACK signal will be asserted while RDLH_RCVD_DUP is asserted.
input                   rdlh_xdlh_req2send_nack;        // RDLH received a good packet and has been asked to send an NACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
input   [11:0]          rdlh_xdlh_req_acknack_seqnum;   // RDLH received a packet with this sequence number
input   [TX_NDLLP-1:0]     rtlh_xdlh_fc_req;               // When asserted, RTLH has requested to send a FC packet, it is de-asserted when xdlh_rtlh_fc_ack is asserted to RTLH
input   [(32*TX_NDLLP)-1:0] rtlh_xdlh_fc_data;              // Content data for FC update, which has be to be valid when RTLH_FC_REQ is asserted
input                   rtlh_xdlh_fc_req_hi;            // When asserted, RTLH has requested to send a high-priority FC packet that has higher priority than ACK/NACK
input                   rtlh_xdlh_fc_req_low;           // When asserted, RTLH has requested to send a low-priority FC packet that has lower priority than TLP


input                   xmlh_xdlh_halt;
input   [NW-1:0]        xdlh_xmlh_eot;

input   [5:0]           smlh_link_mode;

// pm module signals
input                   pm_xdlh_enter_l1;
input                   pm_xdlh_req_ack;
input                   pm_xdlh_enter_l23;
input                   pm_xdlh_actst_req_l1;

input                   smlh_link_in_training;
input                   pm_freeze_ack_timer;            // PM module request to freeze acknack latency timer.

input                   smlh_in_rcvry;                   // LTSSM enters recovery

// =============================================================================
// ---- outputs ---------------
// =============================================================================
output                  xdlh_xtlh_halt;             // when asserted, it indicates to RTLH arbitor to stop scheduling the next transaction.

output  [11:0]          xdlh_rdlh_last_xmt_seqnum;      // the last transmitted highest sequence number of TLP's DLLP. Receiver needs this signal to identify out of order TLP
output                  xdlh_rtlh_fc_ack;               // when asserted, it indicates that the FC packet data has been used and RTLH_FC_REQ signal will be de-asserted in next clock cycle.
output  [11:0]          xdlh_curnt_seqnum;              // inserted here for external monitor
output                  xdlh_smlh_start_link_retrain;

output                  xdlh_retrybuf_not_empty;
output                  xdlh_not_expecting_ack;
output                  xdlh_xmt_pme_ack;
output                  xdlh_last_pmdllp_ack;
output                  xdlh_nodllp_pending;            // No DLLP pending
output                  xdlh_no_acknak_dllp_pending;    // No Ack or Nak DLLP pending
output                  xdlh_tlp_pending;               // TLP pending in the datapath
output                  xdlh_retry_pending;             // TLP pending or retry FSM is in reply state

// Retry buffer external RAM interface inputs/outpus declaration
input [SOTBUF_WD -1:0]   retrysotram_xdlh_data;        // Data coming back from Retry buffer RAM
input [SOTBUF_PW -1:0]   retrysotram_xdlh_depth;
input                    retrysotram_xdlh_parerr;
input [RBUF_WD -1:0]     retryram_xdlh_data;           // Data coming back from Retry buffer RAM
input [RBUF_PW -1:0]     retryram_xdlh_depth;          // How big is the external retry buffer
input                    retryram_xdlh_parerr;         // retry buffer ram parity error detected
output                   xdlh_retryram_par_chk_val;    // parity check valid
output                   xdlh_retryram_halt;
output  [RBUF_PW -1:0]   xdlh_retryram_addr;           // Adrress to retry buffer RAM
output  [RBUF_WD -1:0]   xdlh_retryram_data;           // Write data to retry buffer RAM
output                   xdlh_retryram_we;             // Write enable to retry buffer RAM
output                   xdlh_retryram_en;             // Read enable to retry buffer RAM
output                   xdlh_retrysotram_par_chk_val; // parity check valid

// Performance changes - 2p RAM I/F
// output  [SOTBUF_PW -1:0]    xdlh_retrysotram_addr;          // Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]    xdlh_retrysotram_waddr;          // Write Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]    xdlh_retrysotram_raddr;          // Read Adrress to retry buffer RAM
output  [SOTBUF_WD -1:0] xdlh_retrysotram_data;        // Write data to retry buffer RAM
output                   xdlh_retrysotram_we;          // Write enable to retry buffer RAM
output                   xdlh_retrysotram_en;          // Read enable to retry buffer RAM
output                   nak_scheduled;                // dllp generation block requests nak is scheduled to be transmitted

output                   xdlh_retry_req;               // Pulse: Retry Event 
output  [11:0]              rbuf_pkt_cnt;               // packet in flight timer
output  [3:0]               xdlh_match_pmdllp;
output                  xdlh_replay_timeout;
output  [16:0]          xdlh_replay_timer;


// =============================================================================
// ---- internal signals ------
// =============================================================================
wire                         xdlh_last_pmdllp_req;
wire                         xdlh_in_reply;
wire    [DW-1:0]             tlp_data;                       // tlp_data
wire    [NW-1:0]             tlp_dwen;                       // tlp_data
wire                         tlp_sot;
wire                         tlp_eot;                        // end of tlp, when asserted, indicates the end of tlp.
wire                         rbuf_halt;
wire                         rbuf_reply_req;                 // a tlp will be replied
wire                         rbuf_xmt_sot;                   // sot
wire                         rbuf_xmt_dv;
wire                         rbuf_xmt_done;
wire                         rbuf_xmt_eot;                   // eot
wire                         rbuf_xmt_badeot;                // bad eot is asserted when parity error detected during replay
wire    [DW_W_PAR-1:0]       rbuf_xmt_data;                  // data
wire    [NW-1:0]             rbuf_xmt_dwen;                  // dwen
wire    [11:0]               rbuf_xmt_seqnum;                // seqnum from retry buffer.

wire                         tlpgen_rbuf_sot;                   // sot
wire                         tlpgen_rbuf_dv;
wire                         tlpgen_rbuf_eot;                   // eot
wire                         tlpgen_rbuf_badeot;                   // eot
wire                         tlpgen_reply_grant;
wire    [DW_W_PAR-1:0]       tlpgen_rbuf_data;                  // data
wire    [NW-1:0]             tlpgen_rbuf_dwen;                  // dword enable
wire    [11:0]               tlpgen_rbuf_seqnum;                // seqnum from retry buffer.
wire    [TX_NDLLP-1:0]       dllp_xmt_req;
wire    [(64*TX_NDLLP)-1:0] dllp_xmt_pkt_10b;
 
 
wire                         dllp_req_low_prior;
wire                         xdctrl_dllp_halt;
wire                         xdctrl_tlp_halt;
wire    [NW-1:0]             xdlh_dllp_sent;

wire    [11:0]               rbuf_pkt_cnt;
wire    [RBUF_PW :0]         rbuf_entry_cnt;
wire                         rbuf_block_new_tlp;
wire    [3:0]                xdlh_match_pmdllp;


// DLLP pending signal is generated in xdlh for power management purpose.
// According to spec, when there is no tlp and dllp to be transmitted, then
// nodllp_pending signal can be asserted.
// There are two conditions that we need to watch: 1. when tlp and dllp is
// not requesting at xdlh control block
// 2. when the ack is scheduled in dllp generation block, but it is not
// timeout to be transmitted yet. This is considered as a dllp pending
// condition
wire                         xdctrl_nodllp_pending;
wire                         xdlh_no_acknak_dllp_pending;
wire                         xdlh_nodllp_pending;
assign xdlh_nodllp_pending = xdctrl_nodllp_pending & xdlh_no_acknak_dllp_pending;


// XDLH Common Instantiates Logic which is shared between Flit Mode and Non Flit Mode
xdlh_common
 u_xdlh_common(
  // Inputs
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .flit_mode              (1'b0),
  .cfg_replay_timer_value (cfg_replay_timer_value),
  .rdlh_link_up           (rdlh_link_up),
  // Interfaces
  .b_xdlh_replay          (b_xdlh_replay.slave_mp),
  .b_xdlh_replay_num      (b_xdlh_replay_num.slave_mp),
  // Outputs
  .xdlh_replay_timeout    (xdlh_replay_timeout),
  .xdlh_replay_timer      (xdlh_replay_timer)
);

xdlh_retrybuf

#(INST) u_xdlh_retrybuf(
    // -- inputs --
    .b_xdlh_replay              (b_xdlh_replay.master_mp),
    .b_xdlh_replay_num          (b_xdlh_replay_num.master_mp),
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .smlh_link_in_training      (smlh_link_in_training     ),
    .rdlh_link_up               (rdlh_link_up),
    .tlpgen_rbuf_data           (tlpgen_rbuf_data),
    .tlpgen_rbuf_dwen           (tlpgen_rbuf_dwen),
    .tlpgen_rbuf_seqnum         (tlpgen_rbuf_seqnum),
    .tlpgen_rbuf_dv             (tlpgen_rbuf_dv),
    .tlpgen_rbuf_sot            (tlpgen_rbuf_sot),
    .tlpgen_rbuf_eot            (tlpgen_rbuf_eot),
    .tlpgen_rbuf_badeot         (tlpgen_rbuf_badeot),
    .tlpgen_reply_grant         (tlpgen_reply_grant),

    .rbuf_halt                  (rbuf_halt     ),
    .rdlh_xdlh_rcvd_nack        (rdlh_xdlh_rcvd_nack),
    .rdlh_xdlh_rcvd_ack         (rdlh_xdlh_rcvd_ack),
    .rdlh_xdlh_rcvd_acknack_seqnum (rdlh_xdlh_rcvd_acknack_seqnum),

    // -- outputs --
    .rbuf_reply_req             (rbuf_reply_req),
    .rbuf_xmt_data              (rbuf_xmt_data),
    .rbuf_xmt_dwen              (rbuf_xmt_dwen),
    .rbuf_xmt_sot               (rbuf_xmt_sot),
    .rbuf_xmt_dv                (rbuf_xmt_dv),
    .rbuf_xmt_done              (rbuf_xmt_done),
    .rbuf_xmt_eot               (rbuf_xmt_eot),
    .rbuf_xmt_badeot            (rbuf_xmt_badeot),
    .rbuf_xmt_seqnum            (rbuf_xmt_seqnum),
    .rbuf_entry_cnt             (rbuf_entry_cnt),
    .rbuf_pkt_cnt               (rbuf_pkt_cnt),
    .rbuf_block_new_tlp         (rbuf_block_new_tlp),
    .xdlh_smlh_start_link_retrain (xdlh_smlh_start_link_retrain),
    .xdlh_rbuf_not_empty        (xdlh_retrybuf_not_empty),
    .xdlh_not_expecting_ack     (xdlh_not_expecting_ack),
    .xdlh_rdlh_last_xmt_seqnum  (xdlh_rdlh_last_xmt_seqnum),

    // Retry buffer external RAM interface
      .xdlh_retryram_addr          (xdlh_retryram_addr ),
    .xdlh_retryram_data            (xdlh_retryram_data   ),
    .xdlh_retryram_we              (xdlh_retryram_we     ),
    .xdlh_retryram_en              (xdlh_retryram_en     ),
    .xdlh_retryram_par_chk_val     (xdlh_retryram_par_chk_val),
    .xdlh_retryram_halt            (xdlh_retryram_halt),
    .retryram_xdlh_data            (retryram_xdlh_data   ),
    .retryram_xdlh_depth           (retryram_xdlh_depth  ),
    .retryram_xdlh_parerr          (retryram_xdlh_parerr),

//   Performance change - 2p RAM I/F
//    .xdlh_retrysotram_addr              (xdlh_retrysotram_addr),
    .xdlh_retrysotram_waddr              (xdlh_retrysotram_waddr),
    .xdlh_retrysotram_raddr              (xdlh_retrysotram_raddr),    
    .xdlh_retrysotram_data         (xdlh_retrysotram_data),
    .xdlh_retrysotram_we           (xdlh_retrysotram_we),
    .xdlh_retrysotram_en           (xdlh_retrysotram_en),
    .xdlh_retrysotram_par_chk_val  (xdlh_retrysotram_par_chk_val),
    .retrysotram_xdlh_data         (retrysotram_xdlh_data),
    .retrysotram_xdlh_parerr       (retrysotram_xdlh_parerr),
    .retrysotram_xdlh_depth        (retrysotram_xdlh_depth),
    .xdlh_retry_req                (xdlh_retry_req)
    ,
    .xdlh_in_reply                 (xdlh_in_reply)
);


xdlh_control_64b

#(INST) u_xdlh_control(
    // -- inputs --
    .core_clk                          (core_clk),
    .core_rst_n                        (core_rst_n),
    .rdlh_link_up                      (rdlh_link_up),
    .current_data_rate                 (current_data_rate),
    .phy_type                          (phy_type),
    .smlh_link_mode                    (smlh_link_mode),
    .dllp_xmt_req                      (dllp_xmt_req),
    .dllp_req_low_prior                (dllp_req_low_prior),
    .last_pmdllp_ack                   (xdlh_last_pmdllp_req),

    .dllp_xmt_pkt_10b                  (dllp_xmt_pkt_10b), 

    .xmlh_xdlh_halt                    (b_xdlh_xplh_mp.halt_in),
    .tlp_data                          (tlp_data),
    .tlp_dwen                          (tlp_dwen),
    .tlp_sot                           (tlp_sot),
    .tlp_eot                           (tlp_eot),

    // -- outputs --
    .xdlh_xmlh_data                    (b_xdlh_xplh_mp.data_out),
    .xdlh_xmlh_stp                     (b_xdlh_xplh_mp.stp),
    .xdlh_xmlh_sdp                     (b_xdlh_xplh_mp.sdp),
    .xdlh_xmlh_eot                     (b_xdlh_xplh_mp.eot),
    .next_xdlh_xmlh_eot                (b_xdlh_xplh_mp.next_eot),
    .next_xdlh_xmlh_stp                (b_xdlh_xplh_mp.next_stp),
    .next_xdlh_xmlh_sdp                (b_xdlh_xplh_mp.next_sdp), 
    .xdlh_xmlh_pad                     (b_xdlh_xplh_mp.pad),
    .xdctrl_dllp_halt                  (xdctrl_dllp_halt),
    .xdctrl_tlp_halt                   (xdctrl_tlp_halt),
    .xdlh_xmt_pme_ack                  (xdlh_xmt_pme_ack),
    .xdctrl_nodllp_pending             (xdctrl_nodllp_pending),
    .xdlh_last_pmdllp_ack              (xdlh_last_pmdllp_ack),
    .xdlh_match_pmdllp                 (xdlh_match_pmdllp),
    .xdlh_dllp_sent                    (xdlh_dllp_sent)
);

// Data Valid not used in this architecture
assign b_xdlh_xplh_mp.data_valid = 1'b0;


xdlh_dllp_gen

#(INST) u_xdlh_dllp_gen(
    // -- inputs --
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .cfg_ack_freq                       (cfg_ack_freq),
    .cfg_ack_latency_timer              (cfg_ack_latency_timer),
    .cfg_acknack_disable                (cfg_acknack_disable),
    .cfg_flow_control_disable           (cfg_flow_control_disable),

    .rdlh_link_up                       (rdlh_link_up),
    .rdlh_link_state                    (rdlh_link_state),

    .cfg_other_msg_request              (cfg_other_msg_request),
    .cfg_other_msg_payload              (cfg_other_msg_payload),
    .phy_type                           (phy_type),

    .rtlh_xdlh_fc_req                   (rtlh_xdlh_fc_req),
    .rtlh_xdlh_fc_req_hi                (rtlh_xdlh_fc_req_hi),
    .rtlh_xdlh_fc_req_low               (rtlh_xdlh_fc_req_low),
    .rtlh_xdlh_fc_data                  (rtlh_xdlh_fc_data),

    .rdlh_xdlh_req2send_ack             (rdlh_xdlh_req2send_ack),
    .rdlh_xdlh_req2send_ack_due2dup     (rdlh_xdlh_req2send_ack_due2dup),
    .rdlh_xdlh_req2send_nack            (rdlh_xdlh_req2send_nack),
    .rdlh_xdlh_req_acknack_seqnum       (rdlh_xdlh_req_acknack_seqnum),

    .pm_xdlh_enter_l1                   (pm_xdlh_enter_l1),
    .pm_xdlh_req_ack                    (pm_xdlh_req_ack),
    .pm_xdlh_enter_l23                  (pm_xdlh_enter_l23),
    .pm_xdlh_actst_req_l1               (pm_xdlh_actst_req_l1),
    .pm_freeze_ack_timer                (pm_freeze_ack_timer ),

    .xdctrl_dllp_halt                   (xdctrl_dllp_halt),
    .xmlh_xdlh_halt                     (b_xdlh_xplh_mp.halt_in),
    .xdlh_last_pmdllp_ack               (xdlh_last_pmdllp_ack),
    .smlh_in_rcvry                      (smlh_in_rcvry),

    // -- outputs --
    .nak_scheduled                      (nak_scheduled),
    .dllp_xmt_req                       (dllp_xmt_req),
    .dllp_req_low_prior                 (dllp_req_low_prior),
    .dllp_xmt_pkt_10b                   (dllp_xmt_pkt_10b), 
    .xdlh_rtlh_fc_ack                   (xdlh_rtlh_fc_ack),
    .nodllp_pending                     (xdlh_no_acknak_dllp_pending)
    ,
    .dllp_last_pmdllp_req               (xdlh_last_pmdllp_req)
);

xdlh_tlp_gen_64b

#(INST) u_xdlh_tlp_gen(
    // -- inputs --
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .cfg_corrupt_crc_pattern    (cfg_corrupt_crc_pattern),
    .smlh_in_l0                 (smlh_in_l0),
    .rdlh_link_up               (rdlh_link_up),
    .xtlh_xdlh_dwen             (xtlh_xdlh_dwen),
    .xtlh_xdlh_data             (xtlh_xdlh_data),
    .xtlh_xdlh_sot              (xtlh_xdlh_sot),
    .xtlh_xdlh_eot              (xtlh_xdlh_eot),
    .xtlh_xdlh_dv               (xtlh_xdlh_dv ),
    .xtlh_xdlh_badeot           (xtlh_xdlh_badeot),

    .xdctrl_tlp_halt            (xdctrl_tlp_halt),
    .rbuf_xmt_data              (rbuf_xmt_data),
    .rbuf_xmt_dwen              (rbuf_xmt_dwen),
    .rbuf_xmt_sot               (rbuf_xmt_sot),
    .rbuf_xmt_dv                (rbuf_xmt_dv),
    .rbuf_xmt_done              (rbuf_xmt_done),
    .rbuf_xmt_eot               (rbuf_xmt_eot),
    .rbuf_xmt_badeot            (rbuf_xmt_badeot),
    .rbuf_reply_req             (rbuf_reply_req),
    .rbuf_xmt_seqnum            (rbuf_xmt_seqnum),
    .rbuf_entry_cnt             (rbuf_entry_cnt),
    .rbuf_pkt_cnt               (rbuf_pkt_cnt),
    .rbuf_block_new_tlp         (rbuf_block_new_tlp),

    // -- outputs --
    .xdlh_xtlh_halt             (xdlh_xtlh_halt),
    .rbuf_halt                  (rbuf_halt     ),
    .tlpgen_rbuf_data           (tlpgen_rbuf_data),
    .tlpgen_rbuf_dwen           (tlpgen_rbuf_dwen),
    .tlpgen_rbuf_seqnum         (tlpgen_rbuf_seqnum),
    .tlpgen_rbuf_dv             (tlpgen_rbuf_dv),
    .tlpgen_rbuf_sot            (tlpgen_rbuf_sot),
    .tlpgen_rbuf_eot            (tlpgen_rbuf_eot),
    .tlpgen_rbuf_badeot         (tlpgen_rbuf_badeot),
    .tlpgen_reply_grant         (tlpgen_reply_grant),

    .tlp_data                   (tlp_data),
    .tlp_dwen                   (tlp_dwen),
    .tlp_sot                    (tlp_sot),
    .tlp_eot                    (tlp_eot),

    .xdlh_curnt_seqnum          (xdlh_curnt_seqnum)
);



// -----------------------------------------------------------------
// Track TLP's through the XDLH
// -----------------------------------------------------------------
wire int_clear_pending;
// pipelines are cleared when link goes down so reset the tracker
// If RASDP error mode is enabled clear the tracker
assign int_clear_pending = !rdlh_link_up;

xdlh_tracker

  // Parameters
  #(
    .NW     (NW),
    .SOT_WD (1)
  ) u_xdlh_tracker (
    // Inputs
    .core_clk                 (core_clk),
    .core_rst_n               (core_rst_n),
    .xtlh_xdlh_sot            (xtlh_xdlh_sot),
    .xdlh_xtlh_halt           (xdlh_xtlh_halt),
    .xdlh_xmlh_eot            (xdlh_xmlh_eot),
    .xmlh_xdlh_halt           (xmlh_xdlh_halt),
    .xdlh_xmlh_dllp           (xdlh_dllp_sent),
    .rbuf_xmt_sot             (rbuf_xmt_sot),
    .rbuf_halt                (rbuf_halt),
    .clear_pending            (int_clear_pending), 
    .xdlh_in_reply            (xdlh_in_reply),
    .xdlh_not_expecting_ack   (xdlh_not_expecting_ack),
    // Outputs
    .xdlh_tlp_pending         (xdlh_tlp_pending),
    .xdlh_retry_pending       (xdlh_retry_pending)
);


endmodule

