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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh_dlp_extract.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Data Link Layer DLP Extracter
// --- 1. DLLP packet extract
// --- 2. DLLP packet error detection
// --
// -- Note: The 64b, 128b, 256b and 512b versions have been completely merged.
// -- In the case of 32b, delays due to inputs sizes result in differences 
// -- in the input and dllp extraction sections. 
// -- A single CRC and error checking section is used for all cases.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rdlh_dlp_extract(
    core_clk,
    core_rst_n,
    rdlh_dlcntrl_state,
    rmlh_rdlh_dllp_start,
    rmlh_rdlh_pkt_end,
    rmlh_rdlh_pkt_edb,
    rmlh_rdlh_pkt_data,
    rmlh_rdlh_pkt_dv,
    xdlh_rdlh_last_xmt_seqnum,
    rmlh_rdlh_pkt_err,

    //----------------- outputs ----------------------
    rdlh_rcvd_nack,
    rdlh_rcvd_ack,
    rdlh_rcvd_acknack_seqnum,
    rdlh_rcvd_dllp,
    rdlh_rcvd_dllp_content,
    rcvd_dllp_outseq,
    rdlh_bad_dllp_err,
    rdlh_rcvd_as_req_l1,
    rdlh_rcvd_pm_enter_l1,
    rdlh_rcvd_pm_enter_l23,
    rdlh_rcvd_pm_req_ack
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance.
parameter   NW      = `CX_NW;        // Number of 32-bit dwords handled by the datapath each clock.
parameter   NB      = `CX_NB;   // Number of bytes per cycle per lane

parameter   DW      = (32*NW);  // Width of datapath in bits.
parameter   RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1; // Max number of DLLPs received per cycle

parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)

// ============================================================
// Parameters
// ============================================================

parameter   MAX_SEQNUM      = 4095;
// ============================================================
// inputs
// ============================================================
input                   core_clk;
input                   core_rst_n;
input   [1:0]           rdlh_dlcntrl_state;
input   [NW-1:0]        rmlh_rdlh_dllp_start;       // packet start delimiter, 4bits to indicate the dword location of SDPor STP
input   [NW-1:0]        rmlh_rdlh_pkt_end;          // packet end delimiter 4bits to indicate the dword location of END
input   [NW-1:0]        rmlh_rdlh_pkt_edb;          // packet end delimiter for bad end , 4bit
input   [DW-1:0]        rmlh_rdlh_pkt_data;         // packet data bus 128bit
input                   rmlh_rdlh_pkt_dv;           // packet data valid
input   [11:0]          xdlh_rdlh_last_xmt_seqnum;  // 12bits sequence number to indicate the last transmitted sequence number
input   [NW-1:0]        rmlh_rdlh_pkt_err;          // MAC layer report pkt error

// ============================================================
// outputs
// ============================================================
output                  rdlh_rcvd_nack ;            // DLLP layer received a NACK
output                  rdlh_rcvd_ack ;             // DLLP layer received an ACK
output  [11:0]          rdlh_rcvd_acknack_seqnum;   // DLLP layer received ack/nack sequence number
output  [RX_NDLLP-1:0]  rdlh_rcvd_dllp;             // 1bit to indicate that we have received a dllp packet that could be FC; debug and power management
output  [32*RX_NDLLP-1:0] rdlh_rcvd_dllp_content;   // 32 bits indicates the rcvd special dllp content
output                  rcvd_dllp_outseq;           // out of sequence error detected
output                  rdlh_bad_dllp_err;          // bad dllp error detected
output                  rdlh_rcvd_as_req_l1;        // PM DLLP received, as request L1
output                  rdlh_rcvd_pm_enter_l1;      // PM DLLP received, pm enter L1
output                  rdlh_rcvd_pm_enter_l23;     // PM DLLP received, pm enter L23
output                  rdlh_rcvd_pm_req_ack;       // PM DLLP received, pm request ack

// ============================================================
// IO Declaration
// ============================================================
reg                     rdlh_rcvd_nack ;
reg                     rdlh_rcvd_ack ;
reg  [11:0]             rdlh_rcvd_acknack_seqnum ;
reg  [RX_NDLLP-1:0]     rdlh_rcvd_dllp;
reg  [32*RX_NDLLP-1:0]  rdlh_rcvd_dllp_content;
reg                     rcvd_dllp_outseq;
reg                     rdlh_rcvd_as_req_l1;
reg                     rdlh_rcvd_pm_enter_l1;
reg                     rdlh_rcvd_pm_enter_l23;
reg                     rdlh_rcvd_pm_req_ack;
wire                    rdlh_bad_dllp_err;

// ============================================================
// internal signal Declaration
// ============================================================

reg [23:0]              data_clkd;
reg                     pkterr_clkd;
reg                     rcvd_dllp_crc_err;


wire [NW-1:0] rmlh_rdlh_pkt_end_int;
// Ensure k-char END does not pass to rdlh_dlp_extract when EDB is also set.
// This removes the possibility of a DLLP passing with EDB set instead of END
assign rmlh_rdlh_pkt_end_int = rmlh_rdlh_pkt_end[NW-1:0] & ~rmlh_rdlh_pkt_edb[NW-1:0];


wire     link_rdy4dllp;
assign link_rdy4dllp  =  (rdlh_dlcntrl_state != `S_DL_INACTIVE) ;

wire     rdlh_link_up;
assign rdlh_link_up  =  (rdlh_dlcntrl_state == `S_DL_ACTIVE) ;


reg dllp_start_clkd;
reg pkt_end_clkd;
reg [RX_NDLLP-1:0]     dllp_rcvd; 
reg [RX_NDLLP-1:0]     dllp_rcvd_pkterr;
reg [RX_NDLLP*32-1:0]  dllp_rcvd_data;
reg [RX_NDLLP*16-1:0]  dllp_rcvd_cksum;


assign   rdlh_bad_dllp_err = rcvd_dllp_crc_err;

// Grab the top DW from the previous cycle in case a DLLP is split over two
// cycles.
always @(posedge core_clk or negedge core_rst_n) begin : clkd_PROC
    if (!core_rst_n) begin
        dllp_start_clkd <= #TP 0;
        data_clkd       <= #TP 0;
        pkterr_clkd     <= #TP 0;
        pkt_end_clkd    <= #TP 0;
    end else if(!link_rdy4dllp) begin
        dllp_start_clkd <= #TP 0;
        data_clkd       <= #TP 0;
        pkterr_clkd     <= #TP 0;
        pkt_end_clkd    <= #TP 0;
    end else if(rmlh_rdlh_pkt_dv) begin
        dllp_start_clkd <= #TP rmlh_rdlh_dllp_start[NW-1];
        data_clkd       <= #TP rmlh_rdlh_pkt_data[DW-1 -: 24];
        pkterr_clkd     <= #TP rmlh_rdlh_pkt_err[NW-1];
        pkt_end_clkd    <= #TP rmlh_rdlh_pkt_end_int[NW-1];
    end
end

// Assemble the data that is valid in this cycle. This includes the control
// and data from the upper DW of the last cycle to detect a DLLP that is split
// across two cycles
wire [DW+32-1:0] dllp_in_data;
wire [NW-1:0] dllp_in_start;
wire [NW+1:0] dllp_in_pkterr;
wire [NW:0] dllp_in_end;
assign dllp_in_data   = {rmlh_rdlh_pkt_data[DW-1:0], data_clkd, 8'b0};
assign dllp_in_pkterr = {1'b0, rmlh_rdlh_pkt_err, pkterr_clkd}; 
assign dllp_in_end    = {rmlh_rdlh_pkt_end_int, pkt_end_clkd}; 
assign dllp_in_start  = {rmlh_rdlh_dllp_start[NW-2:0], dllp_start_clkd}; 

// March along each DW and look for dllp start. Extract the cksum and data and
// detect some errors.
reg [NW*32-1: 0]    dllp_scan_data;
reg [NW*16-1: 0]    dllp_scan_cksum;
reg [NW-1:0]        dllp_scan_rcvd; 
reg [NW-1:0]        dllp_scan_pkterr;
integer i;

always @(*) begin : scan_PROC
    for(i = 0; i < NW; i = i + 1) begin
        dllp_scan_data[i*32 +: 32]  = dllp_in_data[i*32+8 +: 32];
        dllp_scan_cksum[i*16 +: 16] = dllp_in_data[i*32+40 +: 16];
        dllp_scan_rcvd[i]   = dllp_in_start[i];
        dllp_scan_pkterr[i] = dllp_in_start[i] && 
            (|dllp_in_pkterr[i +:2] || !dllp_in_end[i+1]); // change the dllp_rcvd logic to decode a DLLP only when a DLLP start is followed by pkt END
    end
end

// dllp_scan gives us NW possible DLLPs. A maximum of NW/2 possible DLLPs can
// be received per cycle. If a DW has a DLLP then it's neighbour cannot as
// a DLLP spans two DW.
// Arbitrarily choosing the most significant DW to have priority.
reg [RX_NDLLP*32-1: 0] dllp_xtrct_data;
reg [RX_NDLLP*16-1: 0] dllp_xtrct_cksum;
reg [RX_NDLLP-1:0]     dllp_xtrct_rcvd; 
reg [RX_NDLLP-1:0]     dllp_xtrct_pkterr;


always @(*) begin : xtrct_PROC
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        dllp_xtrct_data[i*32 +: 32]  = dllp_scan_rcvd[i*2+1] ?
            dllp_scan_data[i*2*32+32 +: 32] : dllp_scan_data[i*2*32 +: 32];
        dllp_xtrct_cksum[i*16 +: 16] = dllp_scan_rcvd[i*2+1] ?
            dllp_scan_cksum[i*2*16+16 +: 16] : dllp_scan_cksum[i*2*16 +: 16];
        dllp_xtrct_rcvd[i]   = dllp_scan_rcvd[i*2] || dllp_scan_rcvd[i*2+1];
        dllp_xtrct_pkterr[i] = dllp_scan_rcvd[i*2+1] ?
            dllp_scan_pkterr[i*2+1] : dllp_scan_pkterr[i*2];
    end
end

// Register the extracted DLLP
always @(posedge core_clk or negedge core_rst_n) begin : dllp_rcvd_seq_PROC
    if (!core_rst_n) begin
        dllp_rcvd           <= #TP 0;
        dllp_rcvd_pkterr    <= #TP 0;
        dllp_rcvd_data      <= #TP 0;
        dllp_rcvd_cksum     <= #TP 0;
    end else if(rmlh_rdlh_pkt_dv) begin
        dllp_rcvd           <= #TP dllp_xtrct_rcvd;
        dllp_rcvd_pkterr    <= #TP dllp_xtrct_pkterr;
        dllp_rcvd_data      <= #TP dllp_xtrct_data;
        dllp_rcvd_cksum     <= #TP dllp_xtrct_cksum;
    end else begin
        dllp_rcvd           <= #TP 0;
        dllp_rcvd_pkterr    <= #TP 0;
    end
end



// Check the CRC and the sequence number for Ack/Nak DLLPs
// Extract PM type
reg [RX_NDLLP-1:0] dllp_cksum_match;
reg [RX_NDLLP-1:0] ack_dllp;
reg [RX_NDLLP-1:0] nack_dllp;
reg [RX_NDLLP-1:0] valid_dllp_rcvd;
reg [RX_NDLLP-1:0] dllp_seq_less;
reg [RX_NDLLP-1:0] good_dllp_ack;
reg [RX_NDLLP-1:0] good_dllp_nack;
reg [RX_NDLLP-1:0] dllp_seq_greater;
reg [RX_NDLLP*12-1:0]  dllp_seqnum;
reg [RX_NDLLP*12-1:0]  dllp_seq_diff;
reg [RX_NDLLP*12-1:0]  dllp_expected_seq_diff;
reg [RX_NDLLP-1:0] dllp_outseq;
reg [RX_NDLLP-1:0] dllp_crc_err;
reg [RX_NDLLP-1:0] dllp_pm_enter_l1;
reg [RX_NDLLP-1:0] dllp_pm_enter_l23;
reg [RX_NDLLP-1:0] dllp_as_req_l1;
reg [RX_NDLLP-1:0] dllp_pm_req_ack;
reg [15:0] tmp_int_caled_dllp_cksum;
reg [15:0] int_caled_dllp_cksum ;
reg [11:0] good_dllp_seqnum;

always @(*) begin : check_PROC
    good_dllp_seqnum = 0;
    tmp_int_caled_dllp_cksum = 0;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        // Calculate checksums
        tmp_int_caled_dllp_cksum = crc16x32(dllp_rcvd_data[i*32 +: 32], 16'hFFFF);
        int_caled_dllp_cksum = ~flip16(tmp_int_caled_dllp_cksum);

        dllp_cksum_match[i] = dllp_rcvd_cksum[i*16 +: 16] == int_caled_dllp_cksum;
    
        // DLLP is valid if checksum matches and there is no error
        valid_dllp_rcvd[i]  = !dllp_rcvd_pkterr[i] && dllp_cksum_match[i] && dllp_rcvd[i];
        ack_dllp[i]         = dllp_rcvd_data[i*32 +: 8] == 8'h00;
        nack_dllp[i]        = dllp_rcvd_data[i*32 +: 8] == 8'h10;
        // we need to detect whether or not the current ACK/NACK dllp is
        // within sequence range.  otherwise, we should discard the current
        // dllp and reported illegal sequence err
        dllp_seqnum[i*12 +: 12] = {dllp_rcvd_data[i*32+16+:4], dllp_rcvd_data[i*32+24 +: 8]};

        // If more than one ACK/NACK DLLP is received in a clock cycle
        if(i>0) begin
            if (valid_dllp_rcvd[i-1] && dllp_seq_less[i-1] && (ack_dllp[i-1] || nack_dllp[i-1])) begin
                //select the highest ACK/NACK sequence number by checking the difference between them
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Sequence counters are intended to
// wrap without preseveration of carry/borrow
                dllp_seq_diff[i*12 +: 12] = dllp_seqnum[i*12 +: 12] - dllp_seqnum[(i-1)*12 +:12];
            end else begin
                // Otherwise just check difference with current seqnum value
                dllp_seq_diff[i*12 +: 12] = dllp_seqnum[i*12 +: 12] - rdlh_rcvd_acknack_seqnum;
            end
        end else begin
            dllp_seq_diff[i*12 +: 12] = dllp_seqnum[i*12 +: 12] - rdlh_rcvd_acknack_seqnum;
        end
        // comparing to the most recent transmission
        dllp_expected_seq_diff[i*12 +: 12] = xdlh_rdlh_last_xmt_seqnum - dllp_seqnum[i*12 +: 12];
// spyglass enable_block W164a

        // Check sequence number is valid
        dllp_seq_less[i] = dllp_seq_diff[i*12 +: 12] < 2048 && dllp_expected_seq_diff[i*12 +: 12] <= 2048;
        dllp_seq_greater[i] = dllp_seq_diff[i*12 +: 12] >= 2048 || dllp_expected_seq_diff[i*12 +: 12] > 2048;

        // Only use the highest received good ack/nak
        good_dllp_ack[i] = 0;
        good_dllp_nack[i] = 0;
        if(valid_dllp_rcvd[i] && dllp_seq_less[i] &&
            (ack_dllp[i] || nack_dllp[i])) begin
            good_dllp_ack = 0;
            good_dllp_nack = 0;
            good_dllp_ack[i] = ack_dllp[i];
            good_dllp_nack[i] = nack_dllp[i];
            good_dllp_seqnum = dllp_seqnum[i*12 +: 12];
        end


        // Detect Errors
        dllp_outseq[i] = valid_dllp_rcvd[i] && dllp_seq_greater[i] &&
            (ack_dllp[i] || nack_dllp[i]);
        dllp_crc_err[i] = !dllp_rcvd_pkterr[i] && !dllp_cksum_match[i] && dllp_rcvd[i];
        // Detect PM DLLPs
        dllp_pm_enter_l1[i] =
            valid_dllp_rcvd[i] && dllp_rcvd_data[i*32 +:8] == `PM_ENTER_L1;
        dllp_pm_enter_l23[i] =
            valid_dllp_rcvd[i] && dllp_rcvd_data[i*32 +:8] == `PM_ENTER_L23;
        dllp_as_req_l1[i] =
            valid_dllp_rcvd[i] && dllp_rcvd_data[i*32 +:8] == `PM_AS_REQ_L1;
        dllp_pm_req_ack[i] =
            valid_dllp_rcvd[i] && dllp_rcvd_data[i*32 +:8] == `PM_REQ_ACK;
    end
end

// output process
// following process implements a lot of data link layer function as per spec.
// received DLLP error check flowchart and Ack/Nack DLLP processing flowchart
// are all included here.

always @(posedge core_clk or negedge core_rst_n) begin : rcvd_acknack_seqnum_seq_PROC
    if (!core_rst_n) begin
        rdlh_rcvd_acknack_seqnum                <= #TP 12'hfff;
    end else if (!rdlh_link_up) begin
            rdlh_rcvd_acknack_seqnum            <= #TP 12'hfff;
    end else if (|good_dllp_ack || |good_dllp_nack) begin
            rdlh_rcvd_acknack_seqnum            <= #TP good_dllp_seqnum;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : rcvd_dllp_seq_PROC
    integer dllp_num;

    if (!core_rst_n) begin
        rdlh_rcvd_dllp                          <= #TP 0;
        rdlh_rcvd_dllp_content                  <= #TP 0;
        rdlh_rcvd_ack                           <= #TP 1'b0;
        rdlh_rcvd_nack                          <= #TP 1'b0;
        rdlh_rcvd_pm_enter_l1                   <= #TP 1'b0;
        rdlh_rcvd_pm_enter_l23                  <= #TP 1'b0;
        rdlh_rcvd_as_req_l1                     <= #TP 1'b0;
        rdlh_rcvd_pm_req_ack                    <= #TP 1'b0;
        rcvd_dllp_crc_err                       <= #TP 1'b0;
        rcvd_dllp_outseq                        <= #TP 1'b0;
    end else if (!link_rdy4dllp) begin
        rdlh_rcvd_dllp                          <= #TP 0;
        rdlh_rcvd_dllp_content                  <= #TP 0;
        rdlh_rcvd_ack                           <= #TP 1'b0;
        rdlh_rcvd_nack                          <= #TP 1'b0;
        rdlh_rcvd_pm_enter_l1                   <= #TP 1'b0;
        rdlh_rcvd_pm_enter_l23                  <= #TP 1'b0;
        rdlh_rcvd_as_req_l1                     <= #TP 1'b0;
        rdlh_rcvd_pm_req_ack                    <= #TP 1'b0;
        rcvd_dllp_crc_err                       <= #TP 1'b0;
        rcvd_dllp_outseq                        <= #TP 1'b0;
    end else begin
        rdlh_rcvd_as_req_l1                     <= #TP |dllp_as_req_l1;
        rdlh_rcvd_pm_enter_l1                   <= #TP |dllp_pm_enter_l1;
        rdlh_rcvd_pm_enter_l23                  <= #TP |dllp_pm_enter_l23;
        rdlh_rcvd_pm_req_ack                    <= #TP |dllp_pm_req_ack;
        rdlh_rcvd_dllp                          <= #TP valid_dllp_rcvd;

        for(dllp_num=0; dllp_num<RX_NDLLP; dllp_num=dllp_num+1) begin
           if (valid_dllp_rcvd[dllp_num])
              rdlh_rcvd_dllp_content[dllp_num*32 +: 32] <= #TP dllp_rcvd_data[dllp_num*32 +: 32];
        end // for
        
        rdlh_rcvd_ack                           <= #TP |good_dllp_ack;
        rdlh_rcvd_nack                          <= #TP |good_dllp_nack;
        rcvd_dllp_outseq                        <= #TP |dllp_outseq;
        rcvd_dllp_crc_err                       <= #TP |dllp_crc_err;
    end
end



function automatic[15:0] crc16x32;
    input   [31:0] Data;
    input   [15:0]  CRC;

    reg     [31:0]  Data_flip;
begin
    Data_flip   = flip32(Data);                  
    crc16x32    = nextCRC16_D32(Data_flip, CRC); 
end
endfunction

  function automatic [15:0] nextCRC16_D32;

    input [31:0] Data;
    input [15:0] CRC;

    reg [31:0] D;
    reg [15:0] C;
    reg [15:0] NewCRC;

  begin

    D = Data;
    C = CRC;
    NewCRC    = 16'h0000;
    NewCRC[0] = D[31] ^ D[29] ^ D[28] ^ D[26] ^ D[23] ^ D[21] ^ D[20] ^
                D[15] ^ D[13] ^ D[12] ^ D[8] ^ D[4] ^ D[0] ^ C[4] ^
                C[5] ^ C[7] ^ C[10] ^ C[12] ^ C[13] ^ C[15];
    NewCRC[1] = D[31] ^ D[30] ^ D[28] ^ D[27] ^ D[26] ^ D[24] ^ D[23] ^
                D[22] ^ D[20] ^ D[16] ^ D[15] ^ D[14] ^ D[12] ^ D[9] ^
                D[8] ^ D[5] ^ D[4] ^ D[1] ^ D[0] ^ C[0] ^ C[4] ^ C[6] ^
                C[7] ^ C[8] ^ C[10] ^ C[11] ^ C[12] ^ C[14] ^ C[15];
    NewCRC[2] = D[31] ^ D[29] ^ D[28] ^ D[27] ^ D[25] ^ D[24] ^ D[23] ^
                D[21] ^ D[17] ^ D[16] ^ D[15] ^ D[13] ^ D[10] ^ D[9] ^
                D[6] ^ D[5] ^ D[2] ^ D[1] ^ C[0] ^ C[1] ^ C[5] ^ C[7] ^
                C[8] ^ C[9] ^ C[11] ^ C[12] ^ C[13] ^ C[15];
    NewCRC[3] = D[31] ^ D[30] ^ D[25] ^ D[24] ^ D[23] ^ D[22] ^ D[21] ^
                D[20] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^ D[14] ^ D[13] ^
                D[12] ^ D[11] ^ D[10] ^ D[8] ^ D[7] ^ D[6] ^ D[4] ^
                D[3] ^ D[2] ^ D[0] ^ C[0] ^ C[1] ^ C[2] ^ C[4] ^ C[5] ^
                C[6] ^ C[7] ^ C[8] ^ C[9] ^ C[14] ^ C[15];
    NewCRC[4] = D[31] ^ D[26] ^ D[25] ^ D[24] ^ D[23] ^ D[22] ^ D[21] ^
                D[19] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^ D[14] ^ D[13] ^
                D[12] ^ D[11] ^ D[9] ^ D[8] ^ D[7] ^ D[5] ^ D[4] ^
                D[3] ^ D[1] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[5] ^ C[6] ^
                C[7] ^ C[8] ^ C[9] ^ C[10] ^ C[15];
    NewCRC[5] = D[27] ^ D[26] ^ D[25] ^ D[24] ^ D[23] ^ D[22] ^ D[20] ^
                D[19] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^ D[14] ^ D[13] ^
                D[12] ^ D[10] ^ D[9] ^ D[8] ^ D[6] ^ D[5] ^ D[4] ^
                D[2] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[6] ^ C[7] ^
                C[8] ^ C[9] ^ C[10] ^ C[11];
    NewCRC[6] = D[28] ^ D[27] ^ D[26] ^ D[25] ^ D[24] ^ D[23] ^ D[21] ^
                D[20] ^ D[19] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^ D[14] ^
                D[13] ^ D[11] ^ D[10] ^ D[9] ^ D[7] ^ D[6] ^ D[5] ^
                D[3] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[7] ^
                C[8] ^ C[9] ^ C[10] ^ C[11] ^ C[12];
    NewCRC[7] = D[29] ^ D[28] ^ D[27] ^ D[26] ^ D[25] ^ D[24] ^ D[22] ^
                D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^
                D[14] ^ D[12] ^ D[11] ^ D[10] ^ D[8] ^ D[7] ^ D[6] ^
                D[4] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^
                C[8] ^ C[9] ^ C[10] ^ C[11] ^ C[12] ^ C[13];
    NewCRC[8] = D[30] ^ D[29] ^ D[28] ^ D[27] ^ D[26] ^ D[25] ^ D[23] ^
                D[22] ^ D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[17] ^ D[16] ^
                D[15] ^ D[13] ^ D[12] ^ D[11] ^ D[9] ^ D[8] ^ D[7] ^
                D[5] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^
                C[7] ^ C[9] ^ C[10] ^ C[11] ^ C[12] ^ C[13] ^ C[14];
    NewCRC[9] = D[31] ^ D[30] ^ D[29] ^ D[28] ^ D[27] ^ D[26] ^ D[24] ^
                D[23] ^ D[22] ^ D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[17] ^
                D[16] ^ D[14] ^ D[13] ^ D[12] ^ D[10] ^ D[9] ^ D[8] ^
                D[6] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^
                C[7] ^ C[8] ^ C[10] ^ C[11] ^ C[12] ^ C[13] ^ C[14] ^
                C[15];
    NewCRC[10] = D[31] ^ D[30] ^ D[29] ^ D[28] ^ D[27] ^ D[25] ^ D[24] ^
                 D[23] ^ D[22] ^ D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[17] ^
                 D[15] ^ D[14] ^ D[13] ^ D[11] ^ D[10] ^ D[9] ^ D[7] ^
                 C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^ C[7] ^ C[8] ^
                 C[9] ^ C[11] ^ C[12] ^ C[13] ^ C[14] ^ C[15];
    NewCRC[11] = D[31] ^ D[30] ^ D[29] ^ D[28] ^ D[26] ^ D[25] ^ D[24] ^
                 D[23] ^ D[22] ^ D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[16] ^
                 D[15] ^ D[14] ^ D[12] ^ D[11] ^ D[10] ^ D[8] ^ C[0] ^
                 C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^ C[7] ^ C[8] ^ C[9] ^
                 C[10] ^ C[12] ^ C[13] ^ C[14] ^ C[15];
    NewCRC[12] = D[30] ^ D[28] ^ D[27] ^ D[25] ^ D[24] ^ D[22] ^ D[19] ^
                 D[17] ^ D[16] ^ D[11] ^ D[9] ^ D[8] ^ D[4] ^ D[0] ^
                 C[0] ^ C[1] ^ C[3] ^ C[6] ^ C[8] ^ C[9] ^ C[11] ^ C[12] ^
                 C[14];
    NewCRC[13] = D[31] ^ D[29] ^ D[28] ^ D[26] ^ D[25] ^ D[23] ^ D[20] ^
                 D[18] ^ D[17] ^ D[12] ^ D[10] ^ D[9] ^ D[5] ^ D[1] ^
                 C[1] ^ C[2] ^ C[4] ^ C[7] ^ C[9] ^ C[10] ^ C[12] ^
                 C[13] ^ C[15];
    NewCRC[14] = D[30] ^ D[29] ^ D[27] ^ D[26] ^ D[24] ^ D[21] ^ D[19] ^
                 D[18] ^ D[13] ^ D[11] ^ D[10] ^ D[6] ^ D[2] ^ C[2] ^
                 C[3] ^ C[5] ^ C[8] ^ C[10] ^ C[11] ^ C[13] ^ C[14];
    NewCRC[15] = D[31] ^ D[30] ^ D[28] ^ D[27] ^ D[25] ^ D[22] ^ D[20] ^
                 D[19] ^ D[14] ^ D[12] ^ D[11] ^ D[7] ^ D[3] ^ C[3] ^
                 C[4] ^ C[6] ^ C[9] ^ C[11] ^ C[12] ^ C[14] ^ C[15];

    nextCRC16_D32 = NewCRC;

  end

  endfunction

function automatic [31:0] flip32;
    input [31:0] d;

    integer bit_loc;
begin
    flip32 = 32'b0;
    for (bit_loc=0; bit_loc<32; bit_loc=bit_loc+1) flip32[bit_loc] = d[31-bit_loc];
end
endfunction

function automatic [15:0] flip16;
    input [15:0] d;

    integer bit_loc;
begin
    flip16 = 16'b0;
    for (bit_loc=0; bit_loc<16; bit_loc=bit_loc+1) flip16[bit_loc] = d[15-bit_loc];
end
endfunction


endmodule
