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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_tlp_gen_64b.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer TLP Generation
//     DL Layer TLP is formed by adding sequence number and crc to each tlp
//     that is requested from xtlh
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xdlh_tlp_gen_64b(
    // -- inputs --
    core_clk,
    core_rst_n,
    cfg_corrupt_crc_pattern,
    rdlh_link_up,
    smlh_in_l0,
    xdctrl_tlp_halt,
    rbuf_reply_req,
    rbuf_xmt_dv,
    rbuf_xmt_done,
    rbuf_xmt_sot,
    rbuf_xmt_eot,
    rbuf_xmt_badeot,
    rbuf_xmt_dwen,
    rbuf_xmt_data,
    rbuf_xmt_seqnum,
    rbuf_entry_cnt,
    rbuf_pkt_cnt,
    rbuf_block_new_tlp,
    xtlh_xdlh_data,
    xtlh_xdlh_sot,
    xtlh_xdlh_dwen,
    xtlh_xdlh_eot,
    xtlh_xdlh_dv,
    xtlh_xdlh_badeot,


    // -- outputs --
    xdlh_xtlh_halt,
    rbuf_halt,
    tlpgen_rbuf_data,
    tlpgen_rbuf_dwen,
    tlpgen_rbuf_seqnum,
    tlpgen_rbuf_dv,
    tlpgen_rbuf_sot,
    tlpgen_rbuf_eot,
    tlpgen_rbuf_badeot,
    tlpgen_reply_grant,
    tlp_data,
    tlp_dwen,
    tlp_sot,
    tlp_eot,
    xdlh_curnt_seqnum
);
// ==============================================================
// ----- parameters ---------------
// ==============================================================
parameter INST      = 0;                                    // The uniquifying parameter for each port logic instance.
parameter NL        = `CX_NL;                               // Max number of lanes supported
parameter NB        = `CX_NB;                               // Number of symbols (bytes) per clock cycle
parameter NW        = 2;                                    // Number of 32-bit dwords handled by the datapath each clock.
parameter DW        = (32*NW);                              // Width of datapath in bits.
parameter TP        = `TP;                                  // Clock to Q delay (simulator insurance)

parameter DATA_PROT_WD         = `TRGT_DATA_PROT_WD;         // data bus parity width
parameter DW_W_PAR                      = (32*NW)+DATA_PROT_WD;  // Width of datapath in bits plus the parity bits.
parameter DW_WO_PAR                      = (32*NW);  // Width of datapath without the parity bits.

parameter RBUF_PW   = `RBUF_PW;


//
// State machine to Generate TLPs. The p1 pipe contains the outgoing packet except for CRC which is merged into the output stage.
parameter S_IDLE                  = 4'h0;
parameter S_REPLY_GRNT            = 4'h1;
parameter S_RBUF_IN_XMT           = 4'h2;
parameter S_RBUF_CRC_EXTRA_START  = 4'h3;
parameter S_RBUF_CRC_EXTRA_END    = 4'h4;
// encoded such that the bit 3 indicates XTLH has the bus
parameter S_XTLH_GRNT             = 4'h8;
parameter S_XTLH_IN_XMT           = 4'h9;
parameter S_XTLH_CRC_EXTRA_START  = 4'hA;                   // a state that identifies that CRC will be start asserted on LSB
parameter S_XTLH_CRC_EXTRA_END    = 4'hB;
parameter HAS_SEQNUM              = 1;

parameter CRC_LATENCY = `CX_CRC_LATENCY_XDLH; // default is 1, can be set to 2 for pipelining to ease timing
localparam CRC_LATENCY_M1 = CRC_LATENCY-1;  //adds a clk cycle delay if crc pipeline on; else 0

localparam TX_CRC_TLP = (NW>2) ? 2 : 1; // Number of TLPs that can be processed by the LCRC block in a single cycle


// ==============================================================
// ----- Inputs ---------------
// ==============================================================
input                           core_clk;
input                           core_rst_n;
input   [31:0]                  cfg_corrupt_crc_pattern;
input                           smlh_in_l0;                 // XMLH layer report back that LTSSM is in L0 state so that we allow transmission from RTLH. This is to prevent TLPs enter into pipe too early
input                           rdlh_link_up;
input                           xdctrl_tlp_halt;
input                           rbuf_reply_req;             // this signal is designed to block the tlp from transmitting while the retrybuffer is getting ready for reply. This is due to cycle delay of memory read
input                           rbuf_xmt_sot;
input                           rbuf_xmt_dv;
input                           rbuf_xmt_done;
input                           rbuf_xmt_eot;
input                           rbuf_xmt_badeot;            // asserted when parity error is detected during replay
input   [NW-1:0]                rbuf_xmt_dwen;
input   [11:0]                  rbuf_xmt_seqnum;
input   [DW_W_PAR-1:0]          rbuf_xmt_data;
input   [RBUF_PW :0]            rbuf_entry_cnt;

input                           rbuf_block_new_tlp;
input   [11:0]                  rbuf_pkt_cnt;
input   [DW_W_PAR-1:0]          xtlh_xdlh_data;
input   [NW-1:0]                xtlh_xdlh_dwen;
input                           xtlh_xdlh_sot;
input                           xtlh_xdlh_eot;
input                           xtlh_xdlh_dv;
input                           xtlh_xdlh_badeot;


// ==============================================================
// ----- Outputs ---------------
// ==============================================================
output                          xdlh_xtlh_halt;
output                          rbuf_halt;
output  [DW-1:0]                tlp_data;
output  [NW-1:0]                tlp_dwen;
output                          tlp_sot;
output                          tlp_eot;
// Below are interface to retrybuf block for the current tlp that is
// transmitting. This interface is introduced for the purpose of saving
// retrybuf size the tlpgen data does not include crc and sequece number
// and the framing information
output  [DW_W_PAR-1:0]          tlpgen_rbuf_data;
output  [NW-1:0]                tlpgen_rbuf_dwen;
output                          tlpgen_rbuf_dv;
output                          tlpgen_rbuf_sot;
output                          tlpgen_rbuf_eot;
output                          tlpgen_rbuf_badeot;
output                          tlpgen_reply_grant;
output  [11:0]                  tlpgen_rbuf_seqnum;
output  [11:0]                  xdlh_curnt_seqnum;
// ==============================================================
// ----- IO declaration ---------------
// ==============================================================
wire                            xdlh_xtlh_halt;
wire                            rbuf_halt;
wire    [DW-1:0]                tlp_data;
wire                            tlp_sot;
wire    [NW-1:0]                tlp_dwen;
wire                            tlp_eot;
wire    [DW_W_PAR-1:0]          tlpgen_rbuf_data;
wire                            tlpgen_rbuf_sot;
wire                            tlpgen_rbuf_eot;
wire                            tlpgen_rbuf_badeot;
wire                            tlpgen_rbuf_dv;
wire    [11:0]                  tlpgen_rbuf_seqnum;
wire    [11:0]                  xdlh_curnt_seqnum;
wire                            tlpgen_reply_grant;

// ==============================================================
// ----- internal signal declaration ---------------
// ==============================================================

wire    [DW_W_PAR-1:0]          int_xtlh_xdlh_data;
wire                            int_tlp_dv;
wire                            xtlh_has_bus;
wire                            valid_xtlh_sot;
reg     [DW_W_PAR-1:0]          clkd_rbuf_data;
reg     [DW_W_PAR-1:0]          clkd_xtlh_data;
wire    [DW_W_PAR-1:0]          int_clkd_rbuf_data;
wire    [DW_W_PAR-1:0]          int_clkd_xtlh_data;

assign int_xtlh_xdlh_data = xtlh_xdlh_data;
assign int_clkd_rbuf_data = clkd_rbuf_data;
assign int_clkd_xtlh_data = clkd_xtlh_data;

reg     [3:0]                   state;
reg     [11:0]                  xtlh_tlp_seqnum_org;
wire                            pipe_in_halt;
wire                            pipe_out_halt;

wire    [NW-1:0]                int_xtlh_dwen;
wire    [NW-1:0]                int_rbuf_dwen;
reg     [NW-1:0]                clkd_xtlh_dwen;
reg     [NW-1:0]                clkd_rbuf_dwen;
wire    [DW-1:0]                int_tlp_data;
wire    [NW-1:0]                int_tlp_dwen;
wire                            int_tlp_sot;
wire                            int_tlp_eot;
wire                            int_eot;
wire    [NW-1:0]                int_dwen;
wire                            int_crc_cross;
wire    [DW-1:0]                int_rbuf_data;
wire    [DW-1:0]                int_xtlh_data;
wire    [DW-1:0]                int_rbuf_data_10b;
wire    [DW-1:0]                int_xtlh_data_10b;
reg                             rbuf_block_tlp;
reg                             latchd_int_badeot;
wire                            int_badeot;
wire                            int_badeot_org;
wire                            xtlh_crc_extrastrt;
wire                            rbuf_crc_extrastrt;
wire                            xtlh_crc_cross;
wire                            rbuf_crc_cross;

wire                            valid_xtlh_eot;
wire                            valid_rbuf_sot;
wire                            valid_rbuf_eot;
wire    [11:0]                  xtlh_tlp_seqnum;


// for the coverage purpose, we generated the valid sot and eot so that it
// is indenpend from interface of xtlh and rbuf whether sot and dv are
// asserted at the same cycle always.
// Our current core XTLH module will assert dv when sot and eot are
// asserted. In future, other xtlh block may control sot and eot as a valid
// control signals so that dv is irrelavent.

// since dv are eot are asserted at the same cycle for our current module,
// these lines are pragma off for expression

assign   valid_xtlh_sot = xtlh_xdlh_sot & xtlh_xdlh_dv;
assign   valid_xtlh_eot = xtlh_xdlh_eot & xtlh_xdlh_dv;
assign   valid_rbuf_sot = rbuf_xmt_sot & rbuf_xmt_dv;
assign   valid_rbuf_eot = rbuf_xmt_eot & rbuf_xmt_dv;


// -----------------------------------------------------------------
// xmt tlp sequence number creation process
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        xtlh_tlp_seqnum_org <= #TP 0;
    else if (!rdlh_link_up)
        xtlh_tlp_seqnum_org <= #TP 0;
    else if ((valid_xtlh_eot & !xtlh_xdlh_badeot & !xdlh_xtlh_halt) 
                                        )
    // seqnum can only increase when the TLH layer has not asking for
    // nullify a TLP, in other words, to append BAD EOT and non invert
    // CRC to the end.
        xtlh_tlp_seqnum_org <= #TP xtlh_tlp_seqnum_org + 12'h001 ; 

assign xtlh_tlp_seqnum = xtlh_tlp_seqnum_org;

assign xdlh_einj0_fcrc_evt = 1'b0 ;

// Interface control with xdlh control block and xtlh block
// Note: In general,  When next block did not assert halt
// (xdctrl_tlp_halt), then the output registers will not latch a net value
// except when state is in idle. When it is idle, interface protocol
// requires that this block insert request regardless of the halt.

// When rbuf request tlp transmission, the state will grant for it as
// always. This means that we have implemented that replay will stop the
// xtlh tlp transmission on every tlp boundary
// XTLH halt is asserted during the idle condition so that we have a cycle
// to make a decision whether or not to block this tlp
reg tmp_xtlh_halt;
reg tmp_rbuf_halt;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        tmp_xtlh_halt   <= #TP 1'b1;
        tmp_rbuf_halt   <= #TP 1'b0;
    end else begin
        // Condition to cause halt:
        // 1. when not in idle or XTLP_WAIT state and xdctrl_tlp_halt
        // asserted
        // 2. When it is the other interface transmission (either retry
        // buffer or xtlh tlp request)
        // 3. when it is idle
        // 4. when inserts crc
        tmp_xtlh_halt   <= #TP (((state == S_XTLH_CRC_EXTRA_START) 
                                | (state == S_XTLH_CRC_EXTRA_END)) & pipe_out_halt)
                                | (((state == S_XTLH_IN_XMT) | (state == S_XTLH_GRNT)) &  valid_xtlh_eot & (xtlh_crc_cross | xtlh_crc_extrastrt) & !pipe_out_halt);

        tmp_rbuf_halt   <= #TP (((state == S_RBUF_CRC_EXTRA_START) 
                                | (state == S_RBUF_CRC_EXTRA_END)) & pipe_out_halt)
                                | (((state == S_RBUF_IN_XMT) | (state == S_REPLY_GRNT)) &  valid_rbuf_eot & (rbuf_crc_cross | rbuf_crc_extrastrt) & !pipe_out_halt ); // insert extra cycle
    end

// When link goes down, we need to deassert halt to ensure that all TLPs
// fromm upper module being taken and upper pipes are empty
assign xdlh_xtlh_halt = (pipe_out_halt | tmp_xtlh_halt | ~xtlh_has_bus | (valid_xtlh_sot & (rbuf_block_tlp | !smlh_in_l0 | rbuf_block_new_tlp))) & rdlh_link_up;
assign rbuf_halt      = pipe_out_halt | tmp_rbuf_halt | xtlh_has_bus | (valid_rbuf_sot & !smlh_in_l0);

assign xdlh_curnt_seqnum = xtlh_tlp_seqnum;

// -----------------------------------------------------------------------
//
// There are few conditions that we need to block xtlh transmission
// 1. when there is no enough entry available in retry buf
// 2. When there are too many pkt in flight (>2048)
//
//wire [6:0]  tlp_type      = xtlh_xdlh_data[6:0];
//wire    tlp_with_payload  = tlp_type[6];
//
//wire [9:0]  int_dw_cnt    = {xtlh_xdlh_data[17:16], xtlh_xdlh_data[31:24]};
//assign  tlp_dw_cnt        = (int_dw_cnt == 10'b0 & tlp_with_payload) ? ({1'b1, int_dw_cnt} + 11'h005)
//                            : (tlp_with_payload) ? ({1'b0, int_dw_cnt} + 11'h005) : 11'h005;
//
//
// PCIE down not allow more than 2K packets in flight. We may be further limited by the size of the SOT buffer
wire    [11:0]        max_pkts_in_flight;
wire    [RBUF_PW :0]  max_packet_entries;

assign max_pkts_in_flight = (`SOTBUF_DEPTH <= 12'h800) ? `SOTBUF_DEPTH -1 : 12'h800;  
assign max_packet_entries = `CX_RBUF_DATASIZE + 1;  // Check to make sure we have room for a MAX packet

// Also make sure there is room for a MAX TLP
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        rbuf_block_tlp  <= #TP 1'b0;
    else
        rbuf_block_tlp  <= #TP (rbuf_entry_cnt <= max_packet_entries) | (rbuf_pkt_cnt >= max_pkts_in_flight);

assign xtlh_has_bus = state[3]; // FSM States encoded to indicate if XTLH or Retry Buffer buffer has bus
                                // state[3] == 1'b1 : XTLH
                                // state[3] == 1'b0 : RBUF

assign xtlh_crc_cross       = (xtlh_xdlh_dwen == 2'b01);
assign rbuf_crc_cross       = (rbuf_xmt_dwen  == 2'b01);
assign xtlh_crc_extrastrt   = (xtlh_xdlh_dwen == 2'b11);
assign rbuf_crc_extrastrt   = (rbuf_xmt_dwen  == 2'b11);


assign tlpgen_reply_grant   = (state == S_REPLY_GRNT);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        state       <= #TP S_IDLE;
    else if (!pipe_out_halt)
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Legacy code
        case (state)
        S_IDLE:
            if (rbuf_reply_req)
              state       <= #TP S_REPLY_GRNT ;
            else
              state       <= #TP S_XTLH_GRNT;

        S_XTLH_GRNT:
            if (valid_xtlh_sot & !rbuf_block_tlp & !rbuf_block_new_tlp & smlh_in_l0)
              state       <= #TP S_XTLH_IN_XMT;
            else if (rbuf_reply_req)
              state       <= #TP S_REPLY_GRNT;
            else
              state       <= #TP S_XTLH_GRNT;

        S_XTLH_IN_XMT:
            if (valid_xtlh_eot & xtlh_crc_extrastrt)
              state       <= #TP S_XTLH_CRC_EXTRA_START;
            else if (valid_xtlh_eot & xtlh_crc_cross)
              state       <= #TP S_XTLH_CRC_EXTRA_END;
            else if (valid_xtlh_eot & !rbuf_reply_req)
              state       <= #TP S_XTLH_GRNT;
            else if (valid_xtlh_eot & rbuf_reply_req)
              state       <= #TP S_REPLY_GRNT;
            else
              state       <= #TP S_XTLH_IN_XMT;
        S_XTLH_CRC_EXTRA_START:
            if (rbuf_reply_req)
              state       <= #TP S_REPLY_GRNT ;
            else
              state       <= #TP S_XTLH_GRNT;

        S_XTLH_CRC_EXTRA_END:
            if (rbuf_reply_req)
              state       <= #TP S_REPLY_GRNT;
            else
              state       <= #TP S_XTLH_GRNT;


        S_REPLY_GRNT:
            if (rbuf_xmt_done)
              state       <= #TP  S_IDLE;
            else if (valid_rbuf_sot & smlh_in_l0)
              state       <= #TP  S_RBUF_IN_XMT;
            else
              state       <= #TP  S_REPLY_GRNT;

        S_RBUF_IN_XMT:
            if (valid_rbuf_eot & rbuf_crc_extrastrt)
              state       <= #TP S_RBUF_CRC_EXTRA_START;
            else if (valid_rbuf_eot & rbuf_crc_cross )
              state       <= #TP S_RBUF_CRC_EXTRA_END;
            else if (valid_rbuf_eot )
              state       <= #TP S_REPLY_GRNT;
            else
              state       <= #TP S_RBUF_IN_XMT;

        S_RBUF_CRC_EXTRA_START:
              state       <= #TP  S_REPLY_GRNT;

        S_RBUF_CRC_EXTRA_END:
                state       <= #TP  S_REPLY_GRNT;
// mapping S_IDLE to default state to facilitate code coverage
            default:
                if (!rbuf_reply_req)
                    state       <= #TP S_XTLH_GRNT;
                else
                    state       <= #TP S_IDLE;
        endcase
// spyglass enable_block STARC05-2.11.3.1

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        clkd_rbuf_data  <= #TP 0;
        clkd_xtlh_data  <= #TP 0;
    end else if (!pipe_out_halt) begin
        // start of packet delimiter
        clkd_rbuf_data  <= #TP rbuf_xmt_data;
        clkd_xtlh_data  <= #TP int_xtlh_xdlh_data;
    end


assign int_xtlh_data_10b[31:0]   = (state == S_XTLH_GRNT)
                                 ? {int_xtlh_xdlh_data[7:0], xtlh_tlp_seqnum[7:0], 4'b0000, xtlh_tlp_seqnum[11:8], `STP_8B}
                                 : ((state == S_XTLH_CRC_EXTRA_START) & latchd_int_badeot)
                                 ? {8'hFF, int_clkd_xtlh_data[63:40]}
                                 : ((state == S_XTLH_CRC_EXTRA_START) & !latchd_int_badeot)
                                 ? {8'h00, int_clkd_xtlh_data[63:40]}
                                 : ((state == S_XTLH_CRC_EXTRA_END) & latchd_int_badeot)
                                 ? {`EDB_8B, 24'hFFFFFF}
                                 : ((state == S_XTLH_CRC_EXTRA_END) & !latchd_int_badeot)
                                 ? {`END_8B, 24'h0}
                                 : { int_xtlh_xdlh_data[7:0], int_clkd_xtlh_data[63:40]};

assign int_xtlh_data_10b[63:32]  = ((state == S_XTLH_CRC_EXTRA_START) & latchd_int_badeot)
                                 ? {`EDB_8B, 24'hFFFFFF}
                                 : ((state == S_XTLH_CRC_EXTRA_START) & !latchd_int_badeot)
                                 ? {`END_8B, 24'b0}
                                 : ((state == S_XTLH_IN_XMT) & (xtlh_xdlh_dwen == 2'b01) & valid_xtlh_eot &  (xtlh_xdlh_badeot

                                                                                                             ))
                                 ? {8'hFF, int_xtlh_xdlh_data[31:8]}
                                 : ((state == S_XTLH_IN_XMT) & (xtlh_xdlh_dwen == 2'b01) & valid_xtlh_eot & !(xtlh_xdlh_badeot

                                                                                                             ))
                                 ? {8'h0, int_xtlh_xdlh_data[31:8]}
                                 : int_xtlh_xdlh_data[39:8];


assign int_rbuf_data_10b[31:0]   = (state == S_REPLY_GRNT)
                                 ? {rbuf_xmt_data[7:0], rbuf_xmt_seqnum[7:0], 4'b0000, rbuf_xmt_seqnum[11:8], `STP_8B}
                                 : ((state == S_RBUF_CRC_EXTRA_START) & latchd_int_badeot)
                                 ? {8'hFF, int_clkd_rbuf_data[63:40]}
                                 : ((state == S_RBUF_CRC_EXTRA_START) & !latchd_int_badeot)
                                 ? {8'h0, int_clkd_rbuf_data[63:40]}
                                 : ((state == S_RBUF_CRC_EXTRA_END) & latchd_int_badeot)
                                 ? {`EDB_8B, 24'hFFFFFF}
                                 : ((state == S_RBUF_CRC_EXTRA_END ) & !latchd_int_badeot)
                                 ? {`END_8B, 24'b0}
                                 : { rbuf_xmt_data[7:0], int_clkd_rbuf_data[63:40]};

assign int_rbuf_data_10b[63:32]  = ((state == S_RBUF_CRC_EXTRA_START ) & latchd_int_badeot)
                                 ? {`EDB_8B, 24'hFFFFFF}
                                 : ((state == S_RBUF_CRC_EXTRA_START) & !latchd_int_badeot)
                                 ? {`END_8B, 24'b0}
                                 : ((state == S_RBUF_IN_XMT) & (rbuf_xmt_dwen == 2'b01) & valid_rbuf_eot &  (rbuf_xmt_badeot ))
                                 ? {8'hFF, rbuf_xmt_data[31:8]}
                                 : ((state == S_RBUF_IN_XMT) & (rbuf_xmt_dwen == 2'b01) & valid_rbuf_eot & !(rbuf_xmt_badeot ))
                                 ? {8'h0, rbuf_xmt_data[31:8]}
                                 : rbuf_xmt_data[39:8];


assign int_xtlh_data = int_xtlh_data_10b;
assign int_rbuf_data = int_rbuf_data_10b;

assign int_tlp_data = ~xtlh_has_bus ? int_rbuf_data : int_xtlh_data;

assign int_tlp_sot  = (xtlh_has_bus & !rbuf_block_tlp & !rbuf_block_new_tlp & valid_xtlh_sot & smlh_in_l0 & (state != S_XTLH_CRC_EXTRA_START) 
                                                                                                          & (state != S_XTLH_CRC_EXTRA_END))
                      | (~xtlh_has_bus & valid_rbuf_sot & smlh_in_l0 & (state != S_RBUF_CRC_EXTRA_START) 
                                                                     & (state != S_RBUF_CRC_EXTRA_END));

assign int_tlp_eot  = (((state == S_XTLH_IN_XMT) | (state == S_XTLH_GRNT)) & ~(xtlh_crc_extrastrt | xtlh_crc_cross) & valid_xtlh_eot )
                        | (((state == S_RBUF_IN_XMT) | (state == S_REPLY_GRNT)) & ~(rbuf_crc_extrastrt | rbuf_crc_cross) & valid_rbuf_eot)
                        | (state == S_XTLH_CRC_EXTRA_START) | (state == S_XTLH_CRC_EXTRA_END)
                        | (state == S_RBUF_CRC_EXTRA_START) | (state == S_RBUF_CRC_EXTRA_END);

assign int_crc_cross_10b = ((state == S_XTLH_IN_XMT | state == S_XTLH_GRNT) & xtlh_crc_cross & valid_xtlh_eot)
                         | ((state == S_REPLY_GRNT | state == S_RBUF_IN_XMT) & rbuf_crc_cross & valid_rbuf_eot);

assign int_crc_cross = int_crc_cross_10b;

assign int_badeot = int_badeot_org ;

assign   int_xtlh_dwen   = xtlh_xdlh_dwen;

assign   int_rbuf_dwen   = rbuf_xmt_dwen;

wire     [NW-1:0]   tmp_tlp_dwen;
assign tmp_tlp_dwen =    ((state == S_XTLH_CRC_EXTRA_START) | (state == S_XTLH_CRC_EXTRA_END))     ? clkd_xtlh_dwen
                       : ((state == S_RBUF_CRC_EXTRA_START) | (state == S_RBUF_CRC_EXTRA_END))     ? clkd_rbuf_dwen
                       : (~xtlh_has_bus & valid_rbuf_eot & ~(rbuf_crc_cross | rbuf_crc_extrastrt)) ? int_rbuf_dwen
                       : (xtlh_has_bus  & valid_xtlh_eot & ~(xtlh_crc_cross | xtlh_crc_extrastrt)) ? int_xtlh_dwen
                       : 2'b11;

assign int_tlp_dwen = tmp_tlp_dwen ;

assign int_badeot_org = (valid_xtlh_eot & xtlh_xdlh_badeot & xtlh_has_bus) | (valid_rbuf_eot & rbuf_xmt_badeot & ~xtlh_has_bus)
                                                                                                                            ;
assign int_tlp_dv   =  (state == S_XTLH_IN_XMT) | (state == S_XTLH_CRC_EXTRA_START) | (state == S_XTLH_CRC_EXTRA_END)
                       | (state == S_RBUF_IN_XMT) | (state == S_RBUF_CRC_EXTRA_START) | (state == S_RBUF_CRC_EXTRA_END)
                       | ((state == S_REPLY_GRNT) & valid_rbuf_sot & smlh_in_l0)
                       | ((state == S_XTLH_GRNT) & valid_xtlh_sot & smlh_in_l0 & !rbuf_block_tlp & !rbuf_block_new_tlp );

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        clkd_xtlh_dwen  <= #TP 0;
        clkd_rbuf_dwen  <= #TP 0;
    end else if (!pipe_out_halt) begin
        clkd_xtlh_dwen  <= #TP int_xtlh_dwen ;
        clkd_rbuf_dwen  <= #TP int_rbuf_dwen ;
    end
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latchd_int_badeot   <= #TP 0;
    else
        latchd_int_badeot   <= #TP (!pipe_out_halt) ? int_badeot : latchd_int_badeot;


// ============= CRC section =======================================

wire                crc_en;
wire    [31:0]      crc_result;
wire    [31:0]      crc_result_lcrc;
assign int_dwen    = ~xtlh_has_bus ? rbuf_xmt_dwen : xtlh_xdlh_dwen;
wire    [DW-1:0]    int_data;
assign int_data    = ~xtlh_has_bus ? rbuf_xmt_data[DW-1:0] : int_xtlh_xdlh_data[DW-1:0];
assign int_eot     = ~xtlh_has_bus ? (valid_rbuf_eot ) : valid_xtlh_eot;
wire                int_sot;
assign int_sot     = ~xtlh_has_bus ? (valid_rbuf_sot) : valid_xtlh_sot;
wire    [15:0]      int_seqnum;
assign int_seqnum  = (valid_rbuf_sot) ? {rbuf_xmt_seqnum[7:0], 4'b0, rbuf_xmt_seqnum[11:8]}
                                    : {xtlh_tlp_seqnum[7:0], 4'b0, xtlh_tlp_seqnum[11:8]};

//wire                crc_en      = (state != S_IDLE) & (state != S_XTLH_CRC_EXTRA_START) & (state != S_XTLH_CRC_EXTRA_END)
//                                  & (state != S_RBUF_CRC_EXTRA_START) & (state != S_RBUF_CRC_EXTRA_END) & !pipe_out_halt;


assign crc_en      = !pipe_out_halt;

wire    [NW-1:0]    sot_to_crc;
assign sot_to_crc  = int_sot ? 2'b01 : 2'b00;   // Always start on first word
wire    [NW-1:0]    eot_to_crc;

assign              eot_to_crc[1] = (int_eot & int_dwen[1]);
assign              eot_to_crc[0] = (int_eot & int_dwen[0] & !int_dwen[1]);

wire    [DW-1:0]                pipe_data;
wire    [NW-1:0]                pipe_dwen;
wire                            pipe_sot;
wire                            pipe_eot;
wire                            pipe_dv;
wire                            pipe_crc_cross;
wire                            tlp_dv;

wire crc_valid;

lcrc
 #(.NW(NW), .NOUT(TX_CRC_TLP), .CRC_MODE(`CX_XDLH), .OPTIMIZE_FOR_1SOT_1EOT(1), .CRC_LATENCY(`CX_CRC_LATENCY_XDLH)) u_lcrc (
    // inputs
    .clk                (core_clk), 
    .rst_n              (core_rst_n),
    .enable_in          (crc_en),
    .data_in            (int_data),
    .sot_in             (sot_to_crc),
    .eot_in             (eot_to_crc),
    .seqnum_in_0        (int_seqnum), 
    .seqnum_in_1        (16'h0),
    // outputs
    .crc_out          (crc_result_lcrc),
    .crc_out_valid      (crc_valid),
    .crc_out_match      (),  // unused when generating
    .crc_out_match_inv  ()  // unused when generating
);

// Delay the input data of the CRC module to match the delay of CRC module
assign pipe_in_halt         = xdctrl_tlp_halt;

parameter DATAPATH_WIDTH    = (4 + DW + NW)
                            ;
parameter CAN_STALL         = (CRC_LATENCY != 0);
delay_n_w_stalling
 //defined as 2 clk = crc pipeline on; 1 clk = crc pipeline off
#(CRC_LATENCY, DATAPATH_WIDTH, 0) u0_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .stall      (pipe_out_halt),
    .clear      (!rdlh_link_up),

    .din        ({
                  int_tlp_sot,  int_tlp_dv,  int_crc_cross,  int_tlp_eot,  int_tlp_data,  int_tlp_dwen}),
    .stallout   (),
    .dout       ({
                  pipe_sot,     pipe_dv,     pipe_crc_cross, pipe_eot,     pipe_data,     pipe_dwen })
);



reg [31:0] crc_result_d ;
reg [31:0] latched_crc_result;   // latch the crc value when it is a halt start
reg        pipe_out_halt_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        pipe_out_halt_d  <= #TP 0;
    else
        pipe_out_halt_d  <= #TP pipe_out_halt;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_crc_result  <= #TP 0;
    else if (pipe_out_halt & !pipe_out_halt_d & crc_valid)
        latched_crc_result  <= #TP crc_result_lcrc;

wire [31:0] int_crc_result;
// assign int_crc_result  = (!pipe_out_halt & pipe_out_halt_d & CAN_STALL) ? latched_crc_result : crc_result;
assign int_crc_result  = crc_result;

// We need to delay the CRC one more cycle in cases where the CRC is split across cycles
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        crc_result_d        <= #TP 0;
    else if ( crc_valid)
        crc_result_d        <= #TP crc_result_lcrc;


assign crc_result = crc_valid ? crc_result_lcrc : crc_result_d;

// Debug control capability added in
wire [31:0] crc_result_i;
assign crc_result_i  =  (pipe_crc_cross) ?  int_crc_result : crc_result_d;
//assign crc_result_i  =  (pipe_crc_cross) ?  int_crc_result : crc_result;


// replace the place holder CRC to the real calculated value
wire    [DW-1:0]                tmp_tlp_data;
reg     [DW-1:0]                tmp_tlp_data_10b;
wire    [NW-1:0]                tmp_dwen;
wire                            tmp_eot;

always @(*)
begin : tmp_tlp_data_10b_proc
    if (pipe_eot & pipe_dv & (pipe_dwen == 2'b01))
        tmp_tlp_data_10b   = {pipe_data[63:24], (pipe_data[23:0]   ^ crc_result_i[31:8])};
    else if (pipe_eot & pipe_dv & (pipe_dwen == 2'b11))
        tmp_tlp_data_10b   = {pipe_data[63:56], (pipe_data[55:24]  ^ crc_result_i),  pipe_data[23:0]};
    else if (pipe_crc_cross & pipe_dv)
        tmp_tlp_data_10b   = {(pipe_data[63:56] ^ crc_result_i[7:0]), pipe_data[55:0]};
    else
        tmp_tlp_data_10b   = pipe_data;
end

assign tmp_tlp_data = tmp_tlp_data_10b;
assign tmp_eot      = pipe_eot;
assign tmp_dwen     = pipe_dwen;

// -----------------Output Drive ---------------------------------------
parameter DATAPATH_WIDTH2    = (3 + DW + NW);
parameter N_CYCLE_DELAY2     = `CX_XDLH_TLP_REGOUT + `XDLH_PKT_PENDING_REG;
parameter CAN_STALL2         = (N_CYCLE_DELAY2 != 0);
wire      tmp_out_halt;
delay_n_w_stalling

#(N_CYCLE_DELAY2, DATAPATH_WIDTH2, CAN_STALL2) u1_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .stall      (pipe_in_halt),
    .clear      (!rdlh_link_up),

    .din        ({pipe_sot,    pipe_dv,    tmp_eot,    tmp_tlp_data, tmp_dwen}),
    .stallout   (tmp_out_halt),
    .dout       ({tlp_sot,     tlp_dv,     tlp_eot,     tlp_data,   tlp_dwen})
);

assign  pipe_out_halt = (CAN_STALL2) ? tmp_out_halt : pipe_in_halt;


// output to retry buf when a tlp has been transmit from xtlh interface
assign tlpgen_rbuf_sot      = valid_xtlh_sot;
assign tlpgen_rbuf_eot      = valid_xtlh_eot;
assign tlpgen_rbuf_seqnum   = xtlh_tlp_seqnum_org; // need to use the seq# without errors
assign tlpgen_rbuf_dwen     = xtlh_xdlh_dwen;
assign tlpgen_rbuf_dv       = !xdlh_xtlh_halt & ((state == S_XTLH_GRNT & valid_xtlh_sot) | state == S_XTLH_IN_XMT);
assign tlpgen_rbuf_badeot   = (
                              xtlh_xdlh_badeot) & xtlh_has_bus;

assign tlpgen_rbuf_data     = int_xtlh_xdlh_data;


`ifndef SYNTHESIS
wire    [(20*8)-1:0]    TLP_GEN_STATE;

assign  TLP_GEN_STATE = (state == S_IDLE)                 ? "IDLE"                 :
                        (state == S_REPLY_GRNT)           ? "REPLY_GRNT"           :
                        (state == S_RBUF_IN_XMT)          ? "RBUF_IN_XMT"          :
                        (state == S_RBUF_CRC_EXTRA_START) ? "RBUF_CRC_EXTRA_START" :
                        (state == S_RBUF_CRC_EXTRA_END)   ? "RBUF_CRC_EXTRA_END"   :
                        (state == S_XTLH_GRNT)            ? "XTLH_GRNT"            :
                        (state == S_XTLH_IN_XMT)          ? "XTLH_IN_XMT"          :
                        (state == S_XTLH_CRC_EXTRA_START) ? "XTLH_CRC_EXTRA_START" :
                        (state == S_XTLH_CRC_EXTRA_END)   ? "XTLH_CRC_EXTRA_END"   :
                                                            "ERROR" ;

`endif // SYNTHESIS

endmodule
