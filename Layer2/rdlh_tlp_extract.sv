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
// ---    $DateTime: 2020/10/02 05:17:03 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh_tlp_extract.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Data Link Layer TLP Extraction
// --- 1. Extract a TLP from a DLLP
// --- 2. Remove the LCRC and sequence number
// --- 3. Generate ACK/NAK/DupACK transmit request
// --- 4. Detect DLLP layer TLP error (LCRC error and sequence error)
// --- 5. Report bad TLP error and drop nullified TLP
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rdlh_tlp_extract(
    core_clk,
    core_rst_n,
    rdlh_link_up,
    rmlh_rdlh_tlp_start,
    rmlh_rdlh_pkt_end,
    rmlh_rdlh_pkt_edb,
    rmlh_rdlh_pkt_data,
    rmlh_rdlh_pkt_dv,
    rmlh_rdlh_pkt_err,
    rmlh_rdlh_nak,
    nak_scheduled,

    // ------------- outputs --------------
    rdlh_req2send_ack,
    rdlh_req2send_ack_due2dup,
    rdlh_req2send_nack,
    rdlh_req_acknack_seqnum,
`ifndef SYNTHESIS
`endif // SYNTHESIS
    rdlh_rtlh_tlp_data,
    rdlh_rtlh_tlp_dv,
    rdlh_rtlh_tlp_sot,
    rdlh_rtlh_tlp_eot,
    rdlh_rtlh_tlp_abort,
    rdlh_bad_tlp_err
);

// =============================================================================
// Parameters
// =============================================================================
//
parameter   INST               = 0;        // The uniquifying parameter for each port logic instance.
parameter   NW                 = `CX_NW;   // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW                 = (32*NW);  // Width of datapath in bits.
parameter   TP                 = `TP;      // Clock to Q delay (simulator insurance)
parameter   CRC_LATENCY        = `CX_CRC_LATENCY_RDLH;  //adds a clk cycle delay if crc pipeline on. Min at least '1' delay

localparam SHIFT_SIZE          = (NW==1) ? 8 : 40; 
localparam RX_TLP              = `CX_RX_TLP; // Number of TLPs that can be processed in this block in a single cycle
localparam RX_TLP_LOG2         = (RX_TLP==4) ? 2 : 1;
localparam CRC_LATENCY_M1      = CRC_LATENCY-1;      //adds a clk cycle '-1' delay if crc pipeline on. Min at least '0' delay

parameter DATA_PROT_WD        = `TRGT_DATA_PROT_WD;


// =============================================================================
// inputs
// =============================================================================
input                   core_clk;             // core running clock
input                   core_rst_n;           // Core reset
input                   rdlh_link_up;         // Data link layer link up indication from RDLH link control state
input   [NW-1:0]        rmlh_rdlh_tlp_start;  // MAC packet start
input   [NW-1:0]        rmlh_rdlh_pkt_end;    // 4bits to indicate the dword location of END or EBD,  MAC packet END
input   [NW-1:0]        rmlh_rdlh_pkt_edb;    // MAC packet end with EDB
input   [DW-1:0]        rmlh_rdlh_pkt_data;   // MAC packet data
input                   rmlh_rdlh_pkt_dv;     // MAC packet data valid
input   [NW-1:0]        rmlh_rdlh_pkt_err;    // MAC packet error
input   [NW-1:0]        rmlh_rdlh_nak;        // MAC packet error
input                   nak_scheduled;        // dllp generation block requests nak is scheduled to be transmitted

// =============================================================================
// Outputs
// =============================================================================


output                  rdlh_req2send_ack;          // Control signal to request the transmission of an ACK
output                  rdlh_req2send_ack_due2dup;  // Control signal to request the transmission of an ACK due to duplicate. 
                                                    // When rdlh_req2send_ack_due2dup is asserted the rdlh_req2send_ack is asserted
output                  rdlh_req2send_nack;         // Control signal to request the transmission of a NACK
output  [11:0]          rdlh_req_acknack_seqnum;    // ACK/NACK sequence number
`ifndef SYNTHESIS
`endif // SYNTHESIS
output  [DW+DATA_PROT_WD-1:0] rdlh_rtlh_tlp_data;   // TLP packet data
output                  rdlh_rtlh_tlp_dv;           // TLP packet data valid indication signal
output  [NW-1:0]        rdlh_rtlh_tlp_sot;          // TLP packet start indication signal
output  [NW-1:0]        rdlh_rtlh_tlp_eot;          // TLP packet end indication signal
output  [RX_TLP-1:0]    rdlh_rtlh_tlp_abort;        // TLP packet abort due to DLLP layer error detected
output                  rdlh_bad_tlp_err;           // Report to CDM that there is an error detected at DLLP layer



// =============================================================================
// IO declaration
// =============================================================================
reg                     rdlh_req2send_ack;
reg                     rdlh_req2send_ack_due2dup;
reg                     rdlh_req2send_nack;
reg      [11:0]         rdlh_req_acknack_seqnum;
wire[DW+DATA_PROT_WD-1:0]rdlh_rtlh_tlp_data;
wire                    rdlh_rtlh_tlp_dv;
wire     [NW-1:0]       rdlh_rtlh_tlp_sot;
wire     [NW-1:0]       rdlh_rtlh_tlp_eot;
wire     [RX_TLP-1:0]   rdlh_rtlh_tlp_abort;
reg                     rdlh_bad_tlp_err;
`ifndef SYNTHESIS
`endif // SYNTHESIS

// =============================================================================
// internal signals declaration
// =============================================================================
wire     [NW-1:0]        tlp_aligned_sot;
wire     [NW-1:0]        tlp_aligned_eot;
wire                     tlp_aligned_short_sc; // single cycle 1 or 2 DW TLP
wire                     tlp_aligned_short_mc; // multi cycle 2 DW TLP
wire                     tlp_aligned_abort_vec;
wire     [NW-1:0]        lcrc_aligned_eot;
wire                     tlp_aligned_badeot;
wire                     tlp_aligned_pkterr;
wire                     tlp_aligned_dv;
wire    [DW+DATA_PROT_WD-1:0] tlp_aligned_data;

//secondary delay signals to allow for pipelined crc on/off
reg     [NW-1:0]        tlp_aligned_sot_d;
reg     [NW-1:0]        tlp_aligned_eot_d;
reg     [NW-1:0]        lcrc_aligned_eot_d;
reg                     tlp_aligned_badeot_pre;
reg                     tlp_aligned_pkterr_d;
reg                     tlp_aligned_dv_d;
reg     [DW+DATA_PROT_WD-1:0]  tlp_aligned_data_d;

reg     [11:0]          tlp_extracted_seqnum_pre;

// Delayed version of inputs to line up with CRC
wire    [NW-1:0]        pipe_rdlh_tlp_start;
wire    [NW-1:0]        pipe_rdlh_pkt_end;
wire    [NW-1:0]        pipe_rdlh_pkt_edb;
wire    [DW-1:0]        tmp_pipe_rdlh_pkt_data;
wire    [DW+DATA_PROT_WD-1:0] pipe_rdlh_pkt_data;
wire                    pipe_rdlh_pkt_dv;
wire    [NW-1:0]        pipe_rdlh_pkterr;
wire    [NW-1:0]        pipe_rdlh_nak;

wire     [11:0]         tlp_extracted_seqnum;

reg                     packet_in_progress;
reg                     ant_packet_in_progress;
reg     [11:0]          tlp_expected_seqnum;
reg     [11:0]          tlp_seqnum;
wire    [NW-1:0]        pipe_eot;
reg     [DW+DATA_PROT_WD-1:0] pipe_pkt_data_d;
wire    [DW+DATA_PROT_WD-1:0] chk_pipe_pkt_data_d;
reg     [NW-1:0]        pipe_pkt_start_d;
reg                     pipe_nack;

wire                    or_aligned_eot;
logic   [NW-1:0]        tmp_aligned_sot;
logic   [NW-1:0]        tmp_aligned_eot;
logic   [NW-1:0]        tmp_aligned_badeot;
wire    [DW-1:0]        tmp_aligned_data;
wire                    tmp_aligned_dv;
wire                    tmp_aligned_short_sc;
wire                    tmp_aligned_short_mc;

reg     [12*RX_TLP-1:0] seqnum_vec;

//--------------------------------
// if RAS is used then prot_tmp_aligned_data is tmp_aligned_data with the associated protection code
// if RAS is not used then is just a buffer for tmp_aligned_data 
wire [DW+DATA_PROT_WD-1:0] prot_tmp_aligned_data;

parameter N_CYCLE_DELAY     = `CX_RDLH_REGIN;

parameter CTRL_DATAPATH_WIDTH    = (3*NW) + (2*NW) + 1;



// Signals after input masking
wire   [NW-1:0]       int_rmlh_rdlh_tlp_start;
wire   [NW-1:0]       int_rmlh_rdlh_pkt_end;
wire   [NW-1:0]       int_rmlh_rdlh_pkt_edb;

// Signals before output masking
wire   [NW-1:0]       int_tlp_aligned_sot;
wire   [NW-1:0]       int_tlp_aligned_eot;
wire   [RX_TLP-1:0]   int_tlp_aligned_abort_vec;

assign int_rmlh_rdlh_tlp_start   = rmlh_rdlh_tlp_start;
assign int_rmlh_rdlh_pkt_end     = rmlh_rdlh_pkt_end  ;
assign int_rmlh_rdlh_pkt_edb     = rmlh_rdlh_pkt_edb  ;

assign int_tlp_aligned_sot       = tlp_aligned_sot      ;
assign int_tlp_aligned_eot       = tlp_aligned_eot      ;
assign int_tlp_aligned_abort_vec = tlp_aligned_abort_vec;


// CTRL Path
delay_n
 #(.N(N_CYCLE_DELAY), .WD(CTRL_DATAPATH_WIDTH)) u_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({rmlh_rdlh_pkt_dv, int_rmlh_rdlh_tlp_start, int_rmlh_rdlh_pkt_end, int_rmlh_rdlh_pkt_edb, rmlh_rdlh_pkt_err, rmlh_rdlh_nak}),

    .dout       ({pipe_rdlh_pkt_dv, pipe_rdlh_tlp_start, pipe_rdlh_pkt_end, pipe_rdlh_pkt_edb, pipe_rdlh_pkterr, pipe_rdlh_nak})
);

delay_n_w_enable
 #(.N(N_CYCLE_DELAY), .WD(DW)) u_delay_w_enable (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (rmlh_rdlh_pkt_dv),
    .din        (rmlh_rdlh_pkt_data),

    .dout       (tmp_pipe_rdlh_pkt_data)
);

assign pipe_eot = (pipe_rdlh_pkt_end | pipe_rdlh_pkt_edb);


// =============================================================================
// Beneath are the design for crc calculation
//
// Delay and shift the incoming data to pass to CRC block with sequence
// number not STP symbol
wire [DW-1:0]         data_to_crc_org;
wire [DW-1:0]         data_to_crc;
wire [NW-1:0]         sot_to_crc;
wire [NW-1:0]         eot_to_crc;
wire                  dv_to_crc;
wire [NW-1:0]         valid_start;
wire [RX_TLP-1:0]     crc_match_vec, crc_match_inv_vec;
wire [RX_TLP-1:0]     org_crc_match_vec, org_crc_match_inv_vec;

assign data_to_crc_org = pipe_rdlh_pkt_data[DW-1:0];
assign dv_to_crc   = pipe_rdlh_pkt_dv;

assign sot_to_crc = valid_start;
//--------------------------------
assign data_to_crc = data_to_crc_org;


// Generate the protection code for the data that is going to be passed to the LCRC module
  assign pipe_rdlh_pkt_data = tmp_pipe_rdlh_pkt_data;



lcrc
 #(.NW(NW), .NOUT(RX_TLP), .CRC_MODE(`CX_RDLH), .OPTIMIZE_FOR_1SOT_1EOT(0), .CRC_LATENCY(`CX_CRC_LATENCY_RDLH)) u_lcrc (
    // inputs
    .clk                (core_clk), 
    .rst_n              (core_rst_n),
    .enable_in          (dv_to_crc),
    .data_in            (data_to_crc),
    .sot_in             (sot_to_crc),
    .eot_in             (eot_to_crc),
    .seqnum_in_0        (16'h0),
    .seqnum_in_1        (16'h0),
    // outputs
    .crc_out            (),
    .crc_out_valid      (),
    .crc_out_match      (org_crc_match_vec),
    .crc_out_match_inv  (org_crc_match_inv_vec)
);

assign crc_match_vec     = (tlp_aligned_short_mc)? org_crc_match_vec & {{RX_TLP-1{1'b1}}, 1'b0} :                     // the short TLP cannot be masked so make sure it is aborted
                           (tlp_aligned_short_sc)? {1'b0 } : // shift out the first bit corresponding to the masked short TLP
                                                   org_crc_match_vec;

assign crc_match_inv_vec = (tlp_aligned_short_mc)? org_crc_match_inv_vec & {{RX_TLP-1{1'b1}}, 1'b0} :                     // the short TLP cannot be masked so make sure it is aborted
                           (tlp_aligned_short_sc)? {1'b0 } : // shift out the first bit corresponding to the masked short TLP
                                                   org_crc_match_inv_vec;

//--------------------------------

assign eot_to_crc      =   tmp_aligned_eot;


// ================= START of LCRC strip logic for 64bit ARCH =================================
// CRC block does the tlp LCRC calculation and matching to expected CRC value.
// tlp data input into this block has been aligned to elminate the STP.
wire   valid_start_0;
assign valid_start_0          = (pipe_rdlh_tlp_start[0] & !packet_in_progress & !(|pipe_eot) & !(|pipe_rdlh_pkterr));
wire   inval_start_0;
assign inval_start_0          = pipe_rdlh_tlp_start[0] & !packet_in_progress & ((|pipe_eot) | (|pipe_rdlh_pkterr));

wire   valid_start_1;
assign valid_start_1          = (pipe_rdlh_tlp_start[1] & !pipe_eot[1] & !pipe_rdlh_pkterr[1] 
                                      & (!packet_in_progress | (packet_in_progress & pipe_eot[0])));
wire   inval_start_1;
assign inval_start_1          = pipe_rdlh_tlp_start[1] & (!packet_in_progress | (packet_in_progress & pipe_eot[0]))
                                      & (pipe_eot[1] | pipe_rdlh_pkterr[1]);

wire   tlp_valid_start;
assign tlp_valid_start        = valid_start_0 | valid_start_1;
assign valid_start = {valid_start_1, valid_start_0};
wire   tlp_inval_start;
assign tlp_inval_start        = inval_start_0 | inval_start_1;
wire [NW-1:0] invalid_end;


reg [NW-1:0] pipe_pkt_start_d2;
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)  begin
//        pipe_pkt_data_d            <= #TP {SHIFT_SIZE{1'b0}};
        pipe_pkt_data_d            <= #TP {DW+DATA_PROT_WD{1'b0}};
        pipe_pkt_start_d           <= #TP 0;
        pipe_pkt_start_d2          <= #TP 0;
        pipe_nack                  <= #TP 0;
end else begin
    if (pipe_rdlh_pkt_dv) begin
//        pipe_pkt_data_d            <= #TP pipe_rdlh_pkt_data[(DW-1):(DW-SHIFT_SIZE)];
        pipe_pkt_data_d            <= #TP pipe_rdlh_pkt_data;
        pipe_pkt_start_d[0]        <= #TP valid_start_0;
        pipe_pkt_start_d[1]        <= #TP valid_start_1;
        pipe_pkt_start_d2          <= #TP pipe_pkt_start_d;
        pipe_nack                  <= #TP tlp_inval_start | (|pipe_rdlh_nak) | (|invalid_end);
    end else
        pipe_nack                  <= #TP |pipe_rdlh_nak;
end

// one bit state to indicate that we are in a packet receiving
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)  begin
        packet_in_progress         <= #TP 0;
end else if (!rdlh_link_up)  begin
        packet_in_progress         <= #TP 0;
end else if ((pipe_rdlh_pkt_dv & pipe_eot[1])
            |(pipe_rdlh_pkt_dv & pipe_eot[0] & !valid_start_1)) begin
        packet_in_progress         <= #TP 1'b0 ; 
end else if (pipe_rdlh_pkt_dv & tlp_valid_start) begin
        packet_in_progress         <= #TP 1'b1 ; 
end

// check the data from the pipe_pkt_data_d before using it
  assign  chk_pipe_pkt_data_d = pipe_pkt_data_d;

// When a start is detected in the last cycle an end detected in this cycle is invalid and should be masked.
assign invalid_end = pipe_eot & {2{|pipe_pkt_start_d}};

// Short single cycle TLPs are completely masked (i.e.tmp_aligned_eot and tmp_aligned_sot). 
// The lcrc is still calculating their CRC, but for 128b and below there is no need to fix 
// lcrc outputs because cannot be 2 eots in the same clock cycle
assign tmp_aligned_short_sc = 0;

// Short multi cycle TLPs cannot be masked because the sot is already out. Make sure they are aborted.
assign tmp_aligned_short_mc = pipe_eot[0] & pipe_pkt_start_d2[1];

assign tmp_aligned_eot      = (packet_in_progress & pipe_eot[0]) ? 2'b01 & ~invalid_end :
                              (packet_in_progress & pipe_eot[1]) ? 2'b10 & ~invalid_end :  2'b00;

assign tmp_aligned_sot      = (pipe_pkt_start_d[1] & !(|pipe_eot[1:0])) ? 2'b10 :
                              (pipe_pkt_start_d[0] & !(|pipe_eot[1:0])) ? 2'b01 :
                                                                          2'b00 ;

assign tmp_aligned_dv       = packet_in_progress & pipe_rdlh_pkt_dv;

wire [11:0]    seqnum;
assign seqnum               = valid_start_0   ? {pipe_rdlh_pkt_data[11:8], pipe_rdlh_pkt_data[23:16]} :
                              valid_start_1   ? {pipe_rdlh_pkt_data[43:40], pipe_rdlh_pkt_data[55:48]} : tlp_seqnum ; 

assign tmp_aligned_data     = {pipe_rdlh_pkt_data[DW-1 -SHIFT_SIZE:0], chk_pipe_pkt_data_d[(DW-1):(DW-SHIFT_SIZE)]};

//----------
reg tlp_aligned_pkterr_pre;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        tlp_aligned_pkterr_pre        <= #TP 0;
    end else if (!rdlh_link_up)  begin
        tlp_aligned_pkterr_pre        <= #TP 0;
    end else begin
        tlp_aligned_pkterr_pre        <= #TP ((pipe_rdlh_pkterr[0] & pipe_eot[0] & !pipe_rdlh_tlp_start[0]) |
                                          (pipe_rdlh_pkterr[1] & pipe_eot[1] & !(|pipe_rdlh_tlp_start[1:0])))
                                         & packet_in_progress & tmp_aligned_dv; // when the pkterr is happening after, then it doesn't matter
    end

delay_n
 //delay: 0 clk delays standard mode,1 clk delays crc pipeline mode
#(.N(CRC_LATENCY_M1), .WD(1)) u_crc_rdlh_delay64 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({tlp_aligned_pkterr_pre}),
    .dout       ({tlp_aligned_pkterr})
);

// ================= END of LCRC strip logic for 64bit ARCH =================================


/////////////////////////////////////////
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        tlp_aligned_badeot_pre      <= #TP 0;
        tlp_seqnum                <= #TP 0;
    end else if(!rdlh_link_up) begin
        tlp_aligned_badeot_pre      <= #TP 0;
        tlp_seqnum                <= #TP 0;
    end else begin
        tlp_aligned_badeot_pre      <= #TP (|pipe_rdlh_pkt_edb) & packet_in_progress & tmp_aligned_dv ;
        // Logic to grab the correct sequence number
        tlp_seqnum                <= #TP (tlp_valid_start & pipe_rdlh_pkt_dv) ? seqnum : tlp_seqnum;
    end
//--------------------------------    

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)  
        tlp_extracted_seqnum_pre       <= #TP 0;
    else if (!rdlh_link_up) 
        tlp_extracted_seqnum_pre       <= #TP 0;
    else if (  (|tmp_aligned_eot) & tmp_aligned_dv) 
        // Latch sequence number at start of packet. Move to output/compare at end of packet.
        tlp_extracted_seqnum_pre       <= #TP tlp_seqnum[11:0];
    else
        tlp_extracted_seqnum_pre       <= #TP tlp_extracted_seqnum_pre;
end
//--------------------------------

delay_n
 //delay: 0 clk delays standard mode,1 clk delays crc pipeline mode
#(.N(CRC_LATENCY_M1), .WD(1+12)) u_crc_rdlh_delay4 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({tlp_aligned_badeot_pre, tlp_extracted_seqnum_pre}),
    .dout       ({tlp_aligned_badeot, tlp_extracted_seqnum})
);
//--------------------------------


// --------------- Error extraction -----------------------
// when PHY not reporting error and it is eot cycle:
// There are 4 sources of errors considered as bad tlp error
// 1. when CRC is not match and is not a nullified tlp
// 2. When CRC is inverted and it is not a nullified TLP
// 3. When crc is not inverted and badeot is asserted
// 4. When tlp sequence error
assign or_aligned_eot            = |tlp_aligned_eot;

wire    sequence_not_eq;
assign sequence_not_eq           = (tlp_extracted_seqnum != tlp_expected_seqnum);

wire    duplicate_seq;
assign duplicate_seq             = ((tlp_expected_seqnum - tlp_extracted_seqnum) <= 12'h800) & sequence_not_eq;


wire    int_crc_err;
assign int_crc_err                =   (!crc_match_vec & !crc_match_inv_vec)           // bad crc
                                      | (crc_match_inv_vec & !tlp_aligned_badeot)   // inverted CRC but not a nullifed
                                      | (tlp_aligned_badeot & !crc_match_inv_vec);  // bad eot but not inverted CRC

wire    sequence_err;
assign sequence_err               = sequence_not_eq & !duplicate_seq ;            // true sequence error

wire    nullified_tlp;
assign nullified_tlp              = crc_match_inv_vec & tlp_aligned_badeot;

wire    duplicate_tlp;
assign duplicate_tlp              = duplicate_seq & !int_crc_err & !tlp_aligned_pkterr & !nullified_tlp;

wire    tlp_abort;
assign tlp_abort                  = int_crc_err | sequence_err | tlp_aligned_pkterr | duplicate_seq | nullified_tlp ;


// this process is used to store the expected sequence number based on last good tlp received.
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        tlp_expected_seqnum         <= #TP 12'b0;
    else if (!rdlh_link_up)
        tlp_expected_seqnum         <= #TP 12'b0;
    else if (or_aligned_eot & !tlp_abort)    // when duplicate or tlp error or phy error or nullified, we can not update the sequence number
        tlp_expected_seqnum         <= #TP (tlp_expected_seqnum + 1) ;
    else
        tlp_expected_seqnum         <= #TP tlp_expected_seqnum ;

// For ack or nack notification to xdlh
// based on the current tlp received, we need to decide whether to ack or
// nack this tlp. A flag is set to issue notification
//
wire    ack_flag, nak_flag, dup_flag;

assign  ack_flag                    = !tlp_abort; // no ack if nullified tlp received
assign  dup_flag                    = duplicate_tlp; 
assign  nak_flag                    = (tlp_aligned_pkterr | int_crc_err | (sequence_err & !tlp_aligned_badeot)); // no nak if nullified or duplicate


// ------------------- Output Drives ------------------------------
// outputs drive process for passing good tlp to tlp layer
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        rdlh_bad_tlp_err            <= #TP 0;
    end else begin
        // PHY errors are not reported here
        rdlh_bad_tlp_err            <= #TP or_aligned_eot & (int_crc_err | (sequence_err & !nullified_tlp & !nak_scheduled)) & !tlp_aligned_pkterr;
    end

// According to spec, we will need to ack on duplicates then drop them
// NOTE: Since we don't abort these duplicates until the end, the consumer
// must have overflow protection, as flow control has been compromised
assign tlp_aligned_abort_vec       = tlp_abort & or_aligned_eot ;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        rdlh_req2send_ack           <= #TP 0;
        rdlh_req2send_ack_due2dup   <= #TP 0;
        rdlh_req2send_nack          <= #TP 0;
        rdlh_req_acknack_seqnum     <= #TP {12{1'b1}};
    end else begin
        rdlh_req2send_ack           <= #TP (ack_flag | dup_flag) & or_aligned_eot & !pipe_nack;
        rdlh_req2send_ack_due2dup   <= #TP dup_flag & or_aligned_eot;
        rdlh_req2send_nack          <= #TP (nak_flag & or_aligned_eot) | pipe_nack;
        
        if (or_aligned_eot & !tlp_abort)
           rdlh_req_acknack_seqnum  <= #TP tlp_expected_seqnum ; 
    end




// ================= Common Code ===============================================
// =============================================================================
// Output functions
// =============================================================================
//second delay to allow for pipelined crc
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        tlp_aligned_dv_d            <= #TP 0;
        tlp_aligned_data_d          <= #TP {                                             {DW{1'b0}}
                                           };
        tlp_aligned_sot_d           <= #TP 0;
        tlp_aligned_eot_d           <= #TP 0;
        lcrc_aligned_eot_d          <= #TP 0;
    end else if (!rdlh_link_up)  begin
        tlp_aligned_dv_d            <= #TP 0;
        tlp_aligned_data_d          <= #TP {                                             {DW{1'b0}}
                                           };
        tlp_aligned_sot_d           <= #TP 0;
        tlp_aligned_eot_d           <= #TP 0;
        lcrc_aligned_eot_d          <= #TP 0;
    end else begin
        // when tlp start on the 3DW, after stripping off the seqnum and
        // STP, we will align tlp data with start pkt in next clock cycle.
        // This is the reason that we do not have dv assert at the
        // pipe_rdlh_tlp_start[3] cycle
        tlp_aligned_dv_d            <= #TP tmp_aligned_dv;
        tlp_aligned_sot_d           <= #TP (tmp_aligned_sot & {NW{tmp_aligned_dv}}) ;

        tlp_aligned_eot_d           <= #TP (tmp_aligned_eot & {NW{tmp_aligned_dv}});
        lcrc_aligned_eot_d          <= #TP (eot_to_crc & {NW{tmp_aligned_dv}});
        if (tmp_aligned_dv)
           tlp_aligned_data_d       <= #TP prot_tmp_aligned_data;
    end

delay_n
 //delay: 0 clk delays standard mode,1 clk delays crc pipeline mode
#(.N(CRC_LATENCY_M1), .WD(1+NW+NW+NW)) u_crc_rdlh_delay5 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({tlp_aligned_dv_d, tlp_aligned_sot_d, tlp_aligned_eot_d, lcrc_aligned_eot_d}),
    .dout       ({tlp_aligned_dv, tlp_aligned_sot, tlp_aligned_eot, lcrc_aligned_eot})
);

delay_n_w_enable
 //delay: 0 clk delays standard mode,1 clk delays crc pipeline mode
#(.N(CRC_LATENCY_M1), .WD(DW+DATA_PROT_WD)) u_crc_rdlh_delay5_w_enable (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (tlp_aligned_dv_d),
    .din        (tlp_aligned_data_d),
    .dout       (tlp_aligned_data)
);

delay_n
 //delay: 1 clk delays standard mode,2 clk delays crc pipeline mode
#(.N(CRC_LATENCY), .WD(2)) u_crc_rdlh_delay_short_tlp (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (!rdlh_link_up),
    .din        ({tmp_aligned_short_sc, tmp_aligned_short_mc}),
    .dout       ({tlp_aligned_short_sc, tlp_aligned_short_mc})
);


  assign prot_tmp_aligned_data = tmp_aligned_data;

// optional delay to get complete output clocked
parameter OUTPUT_CTRL_DATAPATH_WIDTH    = (2*NW) + 1 + RX_TLP;
delay_n

#(.N(`CX_RDLH_TLP_EXTRACT_REGOUT), .WD(OUTPUT_CTRL_DATAPATH_WIDTH)) u1_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({int_tlp_aligned_sot, int_tlp_aligned_eot, tlp_aligned_dv, int_tlp_aligned_abort_vec}),
    .dout       ({rdlh_rtlh_tlp_sot, rdlh_rtlh_tlp_eot, rdlh_rtlh_tlp_dv, rdlh_rtlh_tlp_abort})
);

delay_n_w_enable

#(.N(`CX_RDLH_TLP_EXTRACT_REGOUT), .WD(DW + DATA_PROT_WD)) u1_delay_w_enable (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (tlp_aligned_dv),
    .din        (tlp_aligned_data),
    .dout       (rdlh_rtlh_tlp_data)
);

//--------------------------------

//--------------------------------
endmodule
//--------------------------------
