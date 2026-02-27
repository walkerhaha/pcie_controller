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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_token_finder1.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Packet Layer Token Finder for Gen1/Gen2
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
module rplh_token_finder1
#(
parameter   INST    = 0,             // The uniquifying parameter for each port logic instance.
parameter   NL      = `CX_NL,        // Max number of lanes supported
parameter   NB      = `CX_NB,        // Number of symbols (bytes) per clock cycle
parameter   AW      = `CX_ANB_WD,    // Width of the active number of bytes
parameter   NW      = `CX_PL_NW,     // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW      = (32*NW),       // Width of datapath in bits.
parameter   TP      = `TP            // Clock to Q delay (simulator insurance)
)
(
// ---- inputs ---------------
input                   core_clk,
input                   core_rst_n,
input   [5:0]           smlh_link_mode,
input   [3:0]           active_nb,
input                   rxdata_dv,                 // data is valid this cycle
input   [(NL*NB*8)-1:0] rxdata,                    // Incoming data
input   [(NL*NB)-1:0]   rxdatak,                   // Incoming k indication
input   [(NL*NB)-1:0]   rxerror,                   // Errors reported by PHY
// ---- outputs ---------------
output  [NW-1:0]        rplh_rdlh_dllp_start,       // indication of the dword location of SDP or STP
output  [NW-1:0]        rplh_rdlh_tlp_start,        //
output  [NW-1:0]        rplh_rdlh_pkt_end,          // indication of the dword location of END or EBD
output  [NW-1:0]        rplh_rdlh_pkt_edb,          //
output  [DW-1:0]        rplh_rdlh_pkt_data,         // received data
output                  rplh_rdlh_pkt_dv,           // received data is valid this cycle
output  [NW-1:0]        rplh_rdlh_pkt_err,          // error indication
output  [NW-1:0]        rplh_rdlh_nak               // NAK indication
);

// ============================================================
// Local Parameters
// ============================================================
localparam   NW_MAX  = 16;            // Max umber of 32-bit dwords supported by this module.
localparam   DW_MAX  = (32*NW_MAX);   // Width of max datapath in bits.
localparam   GEN1_NB = `CX_MAC_SMODE_GEN1;
localparam   GEN2_NB = `CX_MAC_SMODE_GEN2;

// ============================================================
// internal Signals
// ============================================================
wire [4:0] link_mode;
assign link_mode = (NL==16) ?           smlh_link_mode[4:0]  :
                   (NL==8)  ? {1'b0   , smlh_link_mode[3:0]} :
                   (NL==4)  ? {2'b00  , smlh_link_mode[2:0]} :
                   (NL==2)  ? {3'b000 , smlh_link_mode[1:0]} :
                              {4'b0000, smlh_link_mode[0]  };

wire [3:0] active_sym_gen12;
// Suppress the most significant bits for lower speeds
     // for Dynamic Frequency config
assign active_sym_gen12      = NB; // Dynamic frequency


// Extend input data to the maximum size supported
wire [DW_MAX-1:0] rx_data;
wire [(NW_MAX*4)-1:0] rx_datak;
wire [(NW_MAX*4)-1:0] rx_error;
assign rx_data  = { {DW_MAX-    (NL*NB*8){1'b0}}, rxdata  };
assign rx_datak = { {(NW_MAX*4)-(NL*NB)  {1'b0}}, rxdatak };
assign rx_error = { {(NW_MAX*4)-(NL*NB)  {1'b0}}, rxerror };

wire    [(NW_MAX*4)-1:0]    stps;
assign stps = { {(NW_MAX*4)-(NL*NB){1'b0}}, compare_bytes(rx_data[(NL*NB*8)-1:0], rx_datak[(NL*NB)-1:0], `STP_8B) };
wire    [(NW_MAX*4)-1:0]    sdps;
assign sdps = { {(NW_MAX*4)-(NL*NB){1'b0}}, compare_bytes(rx_data[(NL*NB*8)-1:0], rx_datak[(NL*NB)-1:0], `SDP_8B) };
wire    [(NW_MAX*4)-1:0]    ends;
assign ends = { {(NW_MAX*4)-(NL*NB){1'b0}}, compare_bytes(rx_data[(NL*NB*8)-1:0], rx_datak[(NL*NB)-1:0], `END_8B) };
wire    [(NW_MAX*4)-1:0]    edbs;
assign edbs = { {(NW_MAX*4)-(NL*NB){1'b0}}, compare_bytes(rx_data[(NL*NB*8)-1:0], rx_datak[(NL*NB)-1:0], `EDB_8B) };

wire    [6:0]       valid_bytes;
// 2s is the default case in order to optimize the area for dynamic width configs
assign valid_bytes = 
                     link_mode[4] ? active_sym_gen12[0] ? 7'b0010000 : active_sym_gen12[2] ? 7'b1000000 : 7'b0100000 :             // 1sx16 : 4sx16 : 2sx16
                     link_mode[3] ? active_sym_gen12[0] ? 7'b0001000 : active_sym_gen12[2] ? 7'b0100000 : 7'b0010000 :             // 1sx8  : 4sx8  : 2sx8
                     link_mode[2] ? active_sym_gen12[0] ? 7'b0000100 : active_sym_gen12[2] ? 7'b0010000 : 7'b0001000 :             // 1sx4  : 4sx4  : 2sx4
                     link_mode[1] ? active_sym_gen12[0] ? 7'b0000010 : active_sym_gen12[2] ? 7'b0001000 : 7'b0000100 :             // 1sx2  : 4sx2  : 2sx2
                     link_mode[0] ? active_sym_gen12[0] ? 7'b0000001 : active_sym_gen12[2] ? 7'b0000100 : 7'b0000010 : 7'b0000010; // 1sx1  : 4sx1  : 2sx1

// since x1 and x2 link mode will require data alignment, then we will
// start our counter to left LSB aligned stp or sdp
reg     [5:0]       sym_cnt;

// this block finds the packet and collect data from all lanes into a data bus.
// handle odd-alignments caused by multi symbols-per-cycle
reg     [NW_MAX-1:0]    dllp_start;
reg     [NW_MAX-1:0]    tlp_start;
reg     [NW_MAX-1:0]    pkt_end;
reg     [NW_MAX-1:0]    pkt_edb;
reg     [DW_MAX-1:0]    pkt_data;
reg                     pkt_dv;
reg     [NW_MAX-1:0]    pkt_err;
reg     [NW_MAX-1:0]    nak;

reg     [2:0]           overflow_sdps;
reg     [2:0]           overflow_stps;
reg     [2:0]           overflow_datak;
reg     [2:0]           overflow_error;
reg     [23:0]          overflow_data;
reg                     alignment_flip;
reg     [NW_MAX:0]      packet_ip;
wire                    packet_ip_o;
wire                    packet_ip_a;
wire                    packet_ip_b;
wire                    packet_ip_c;
logic   [NW_MAX-1:0]    int_nak;
logic   [NW_MAX-1:0]    int_dllp_start;
logic   [NW_MAX-1:0]    int_tlp_start;
logic   [NW_MAX-1:0]    int_pkt_end;
logic   [NW_MAX-1:0]    int_pkt_edb;
logic   [NW_MAX-1:0]    int_pkt_err;


reg packet_in_progress;
always @(*) begin : decode_paket_ip
    integer nw;
    packet_ip[0] = packet_in_progress;
    for (nw=1; nw<=NW_MAX; nw = nw+1) begin
        packet_ip[nw] = packet_ip[nw-1] ? !(|{rx_datak[(nw-1)*4 +: 4], rx_error[(nw-1)*4 +: 4] }) : ((stps[(nw-1)*4] | sdps[(nw-1)*4]) & !(|{rx_datak[(nw-1)*4+1 +: 3], rx_error[(nw-1)*4 +: 4]}));
    end
end

assign              packet_ip_o = packet_ip[0] ? !((|{rx_datak[1:0], overflow_datak[1:0]}) | (|{rx_error[1:0], overflow_error[1:0]})) :
                                                 ((overflow_sdps[0] | overflow_stps[0]) & !(|{rx_datak[1:0], overflow_datak[1]} | (|{rx_error[1:0], overflow_error[1:0]})));
assign              packet_ip_a = packet_ip[0] ? !((|rx_datak[3:0])   | (|rx_error[3:0]))   : ((stps[0]  | sdps[0])  & !(|rx_datak[3:1]   | (|rx_error[3:0]  )));
assign              packet_ip_b = packet_ip_o  ? !((|rx_datak[5:2])   | (|rx_error[5:2]))   : ((stps[2]  | sdps[2])  & !(|rx_datak[5:3]   | (|rx_error[5:2]  )));
assign              packet_ip_c = packet_ip_a  ? !((|rx_datak[7:4])   | (|rx_error[7:4]))   : ((stps[4]  | sdps[4])  & !(|rx_datak[7:5]   | (|rx_error[7:4]  )));

always @(*) begin : decode_outputs
    integer nw;
    for (nw=0; nw<NW_MAX; nw = nw+1) begin
            int_nak[nw]                      = stps[nw*4]  & !packet_ip[nw] & ( (|rx_datak[nw*4+1 +: 3]) |  (|rx_error[nw*4 +: 4]  ));
            int_dllp_start[nw]               = sdps[nw*4]  & !packet_ip[nw] &  !(|rx_datak[nw*4+1 +: 3]) & !(|rx_error[nw*4 +: 4]  ) ;
            int_tlp_start[nw]                = stps[nw*4]  & !packet_ip[nw] &  !(|rx_datak[nw*4+1 +: 3]) & !(|rx_error[nw*4 +: 4]  ) ;
            int_pkt_end[nw]                  =                packet_ip[nw] & (  |rx_datak[nw*4   +: 4]  |  (|rx_error[nw*4 +: 4]  ));
            int_pkt_edb[nw]                  = edbs[(nw+1)*4-1];
            int_pkt_err[nw]                  = packet_ip[nw] & ((rx_datak[(nw+1)*4-1]  & !(ends[(nw+1)*4-1]  | edbs[(nw+1)*4-1] ) | (|rx_datak[nw*4 +: 3]  ) | (|rx_error[nw*4 +: 4]  )));
    end
end


// All errors regarding to pkt framing on multi-lanes should be detected here.
// do not know what to do yet when there is skew changed in the middle of pkt
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
            pkt_data                  <= #TP 0;
            pkt_dv                    <= #TP 0;
            dllp_start                <= #TP 0;
            tlp_start                 <= #TP 0;
            nak                       <= #TP 0;
            pkt_end                   <= #TP 0;
            pkt_edb                   <= #TP 0;
            pkt_err                   <= #TP 0;

            packet_in_progress        <= #TP 0;
            overflow_data             <= #TP 0;
            overflow_sdps             <= #TP 0;
            overflow_stps             <= #TP 0;
            overflow_datak            <= #TP 0;
            overflow_error            <= #TP 0;
            alignment_flip            <= #TP 0;
            sym_cnt                   <= #TP 0;
    end else if (!rxdata_dv) begin
            pkt_dv                    <= #TP 1'b0;
    end else if (valid_bytes[6]==1'b1) begin // 64-byte valid data
            // 4sx16
            pkt_dv                           <= #TP 1'b1;
            pkt_data[DW_MAX-1:DW_MAX-512]    <= #TP rx_data[511:0];
            dllp_start[NW_MAX-1:NW_MAX-16]   <= #TP int_dllp_start[15:0];
            tlp_start[NW_MAX-1:NW_MAX-16]    <= #TP int_tlp_start[15:0];
            nak[NW_MAX-1:NW_MAX-16]          <= #TP int_nak[15:0];
            pkt_end[NW_MAX-1:NW_MAX-16]      <= #TP int_pkt_end[15:0];
            pkt_edb[NW_MAX-1:NW_MAX-16]      <= #TP int_pkt_edb[15:0];
            pkt_err[NW_MAX-1:NW_MAX-16]      <= #TP int_pkt_err[15:0];

            packet_in_progress               <= #TP packet_ip[16];
    end else if (valid_bytes[5]==1'b1) begin // 32-byte valid data
            // 1sx32, 2sx16, 4sx8
            sym_cnt                          <= #TP sym_cnt + 32;
            pkt_dv                           <= #TP (NW==16) ? sym_cnt[5] : 1'b1;
            pkt_data[DW_MAX-1:DW_MAX-256]    <= #TP rx_data[255:0];
            dllp_start[NW_MAX-1:NW_MAX-8]    <= #TP int_dllp_start[7:0];
            tlp_start[NW_MAX-1:NW_MAX-8]     <= #TP int_tlp_start[7:0];
            nak[NW_MAX-1:NW_MAX-8]           <= #TP int_nak[7:0];
            pkt_end[NW_MAX-1:NW_MAX-8]       <= #TP int_pkt_end[7:0];
            pkt_edb[NW_MAX-1:NW_MAX-8]       <= #TP int_pkt_edb[7:0];
            pkt_err[NW_MAX-1:NW_MAX-8]       <= #TP int_pkt_err[7:0];

            packet_in_progress               <= #TP packet_ip[8];

            // Move lower 32 to upper 32
            pkt_data[DW_MAX-257:DW_MAX-512]  <= #TP pkt_data[DW_MAX-1:DW_MAX-256];
            dllp_start[NW_MAX-9:NW_MAX-16]   <= #TP dllp_start[NW_MAX-1:NW_MAX-8];
            tlp_start[NW_MAX-9:NW_MAX-16]    <= #TP tlp_start[NW_MAX-1:NW_MAX-8];
            pkt_end[NW_MAX-9:NW_MAX-16]      <= #TP pkt_end[NW_MAX-1:NW_MAX-8];
            pkt_edb[NW_MAX-9:NW_MAX-16]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-8];
            pkt_err[NW_MAX-9:NW_MAX-16]      <= #TP pkt_err[NW_MAX-1:NW_MAX-8];
    end else if (valid_bytes[4]==1'b1) begin // 16-byte valid data
            // 1sx16, 2sx8, 4sx4
            sym_cnt                          <= #TP sym_cnt + 16;
            pkt_dv                           <= #TP (NW==16) ? sym_cnt[5:4] == 2'b11 :
                                                    (NW==8)  ? sym_cnt[4] : 1'b1;
            pkt_data[DW_MAX-1:DW_MAX-128]    <= #TP rx_data[127:0];
            dllp_start[NW_MAX-1:NW_MAX-4]    <= #TP int_dllp_start[3:0];
            tlp_start[NW_MAX-1:NW_MAX-4]     <= #TP int_tlp_start[3:0];
            nak[NW_MAX-1:NW_MAX-4]           <= #TP int_nak[3:0];
            pkt_end[NW_MAX-1:NW_MAX-4]       <= #TP int_pkt_end[3:0];
            pkt_edb[NW_MAX-1:NW_MAX-4]       <= #TP int_pkt_edb[3:0];
            pkt_err[NW_MAX-1:NW_MAX-4]       <= #TP int_pkt_err[3:0];

            packet_in_progress               <= #TP packet_ip[4];

            // Move lower 16 to upper 16
            pkt_data[DW_MAX-129:DW_MAX-256] <= #TP pkt_data[DW_MAX-1:DW_MAX-128];
            dllp_start[NW_MAX-5:NW_MAX-8]   <= #TP dllp_start[NW_MAX-1:NW_MAX-4];
            tlp_start[NW_MAX-5:NW_MAX-8]    <= #TP tlp_start[NW_MAX-1:NW_MAX-4];
            pkt_end[NW_MAX-5:NW_MAX-8]      <= #TP pkt_end[NW_MAX-1:NW_MAX-4];
            pkt_edb[NW_MAX-5:NW_MAX-8]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-4];
            pkt_err[NW_MAX-5:NW_MAX-8]      <= #TP pkt_err[NW_MAX-1:NW_MAX-4];

            if (sym_cnt[5:4] == 2) begin
                // Move lower 32 to upper 32
                pkt_data[DW_MAX-257:DW_MAX-512]  <= #TP pkt_data[DW_MAX-1:DW_MAX-256];
                dllp_start[NW_MAX-9:NW_MAX-16]   <= #TP dllp_start[NW_MAX-1:NW_MAX-8];
                tlp_start[NW_MAX-9:NW_MAX-16]    <= #TP tlp_start[NW_MAX-1:NW_MAX-8];
                pkt_end[NW_MAX-9:NW_MAX-16]      <= #TP pkt_end[NW_MAX-1:NW_MAX-8];
                pkt_edb[NW_MAX-9:NW_MAX-16]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-8];
                pkt_err[NW_MAX-9:NW_MAX-16]      <= #TP pkt_err[NW_MAX-1:NW_MAX-8];
            end
    end else if (valid_bytes[3]==1'b1) begin // 8-byte valid data
            pkt_dv                           <= #TP (NW==16) ? (sym_cnt[5:3] == 3'b111) :
                                                    (NW==8)  ? (sym_cnt[4:3] == 2'b11)  :
                                                    (NW==4)  ? (sym_cnt[3]   == 1'b1)   : 1'b1;
        if (active_sym_gen12[2]==1'b1) begin // 4sx2 (link_mode = 5'b00010)
            overflow_data[15:0]       <= #TP rx_data[63:48];
            overflow_sdps[0]          <= #TP sdps[6];
            overflow_stps[0]          <= #TP stps[6];
            overflow_datak            <= #TP {1'b0, rx_datak[7:6]};
            overflow_error            <= #TP {1'b0, rx_error[7:6]};

            if (packet_in_progress) begin
                if (sym_cnt[1]) begin
                    pkt_data[DW_MAX-33:DW_MAX-64]       <= #TP {rx_data[15:0], overflow_data[15:0]};
                    dllp_start[NW_MAX-2]                <= #TP 0;
                    tlp_start[NW_MAX-2]                 <= #TP 0;
                    nak[NW_MAX-2]                       <= #TP 0;
                    pkt_end[NW_MAX-2]                   <= #TP |{rx_datak[1:0], overflow_datak[1:0]} | (|{rx_error[1:0], overflow_error[1:0]});
                    pkt_edb[NW_MAX-2]                   <= #TP edbs[1];
                    pkt_err[NW_MAX-2]                   <= #TP (rx_datak[1] & !(ends[1] | edbs[1])) | (|{rx_datak[0], overflow_datak[1:0]} | (|{rx_error[1:0], overflow_error[1:0]}));

                    pkt_data[DW_MAX-1:DW_MAX-32]        <= #TP packet_ip_o ? rx_data[47:16] :
                                                               packet_ip_b ? rx_data[47:16] : rx_data[63:32];
                    dllp_start[NW_MAX-1]                <= #TP packet_ip_o ? 0 :
                                                               packet_ip_b ? sdps[2] : sdps[4] & !(|{rx_datak[7:5], rx_error[7:4]});
                    tlp_start[NW_MAX-1]                 <= #TP packet_ip_o ? 0 :
                                                               packet_ip_b ? stps[2] : stps[4] & !(|{rx_datak[7:5], rx_error[7:4]});
                    nak[NW_MAX-1]                       <= #TP packet_ip_o ? 0 :
                                                                            (stps[2] & |{rx_datak[5:3], rx_error[5:2]}) | (stps[4] & (|{rx_datak[7:5], rx_error[7:4]}));
                    pkt_end[NW_MAX-1]                   <= #TP packet_ip_o ? |{rx_datak[5:2], rx_error[5:2]} : 0;
                    pkt_edb[NW_MAX-1]                   <= #TP packet_ip_o ? edbs[5] : 0;
                    pkt_err[NW_MAX-1]                   <= #TP packet_ip_o ? (rx_datak[5] & !(ends[5] | edbs[5])) | (|{rx_datak[4:2], rx_error[5:2]}) : 0;

                    packet_in_progress                  <= #TP packet_ip_b | (!packet_ip_o & ((stps[4] | sdps[4]) & !(|rx_datak[7:5] | (|rx_error[7:4]))));
                    sym_cnt                             <= #TP sym_cnt + (packet_ip_b ? 8 : 6);
                end else begin // packet_in_progres && !sym_cnt[1]
                    pkt_data[DW_MAX-33:DW_MAX-64]       <= #TP rx_data[31:0];
                    dllp_start[NW_MAX-2]                <= #TP 0;
                    tlp_start[NW_MAX-2]                 <= #TP 0;
                    nak[NW_MAX-2]                       <= #TP 0;
                    pkt_end[NW_MAX-2]                   <= #TP |{rx_datak[3:0], rx_error[3:0]};
                    pkt_edb[NW_MAX-2]                   <= #TP edbs[3];
                    pkt_err[NW_MAX-2]                   <= #TP (rx_datak[3] & !(ends[3] | edbs[3])) | (|{rx_datak[2:0], rx_error[3:0]});

                    pkt_data[DW_MAX-1:DW_MAX-32]        <= #TP rx_data[63:32];
                    dllp_start[NW_MAX-1]                <= #TP packet_ip_a ? 0 : sdps[4] & !(|{rx_datak[7:5], rx_error[7:4]});
                    tlp_start[NW_MAX-1]                 <= #TP packet_ip_a ? 0 : stps[4] & !(|{rx_datak[7:5], rx_error[7:4]});
                    nak[NW_MAX-1]                       <= #TP packet_ip_a ? 0 : stps[4] & (|{rx_datak[7:5], rx_error[7:4]});
                    pkt_end[NW_MAX-1]                   <= #TP packet_ip_a ? |{rx_datak[7:4], rx_error[7:4]} : 0;
                    pkt_edb[NW_MAX-1]                   <= #TP packet_ip_a ? edbs[7] : 0;
                    pkt_err[NW_MAX-1]                   <= #TP packet_ip_a ? (rx_datak[7] & !(ends[7] | edbs[7])) | (|{rx_datak[6:4], rx_error[7:4]}) : 0;

                    packet_in_progress                  <= #TP packet_ip_c;
                    sym_cnt                             <= #TP sym_cnt + 8;
                end

            end else begin // !packet_in_progress
                if (sym_cnt[1]) begin
                    if (sdps[4] | stps[4]) begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP rx_data[63:0];
                        dllp_start[NW_MAX-1]            <= #TP sdps[4] & !(|{rx_datak[7:5], rx_error[7:4]});
                        dllp_start[NW_MAX-2]            <= #TP 0;
                        tlp_start[NW_MAX-1]             <= #TP stps[4] & !(|{rx_datak[7:5], rx_error[7:4]});
                        tlp_start[NW_MAX-2]             <= #TP 0;
                        nak[NW_MAX-1]                   <= #TP stps[4] & (|{rx_datak[7:5], rx_error[7:4]});
                        nak[NW_MAX-2]                   <= #TP |{stps[2], stps[0], overflow_stps[0]};
                        pkt_end[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_edb[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_err[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        packet_in_progress              <= #TP !(|{rx_datak[7:5], rx_error[7:4]});
                        sym_cnt                         <= #TP sym_cnt + 6;
                    end else if (sdps[2] | stps[2]) begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP {rx_data[47:0], overflow_data[15:0]};
                        dllp_start[NW_MAX-1]            <= #TP sdps[2] & !(|{rx_datak[5:3], rx_error[5:2]});
                        dllp_start[NW_MAX-2]            <= #TP 0;
                        tlp_start[NW_MAX-1]             <= #TP stps[2] & !(|{rx_datak[5:3], rx_error[5:2]});
                        tlp_start[NW_MAX-2]             <= #TP 0;
                        nak[NW_MAX-1]                   <= #TP stps[2] & (|{rx_datak[5:3], rx_error[5:2]});
                        nak[NW_MAX-2]                   <= #TP |{stps[0], overflow_stps[0]};
                        pkt_end[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_edb[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_err[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        packet_in_progress              <= #TP !(|{rx_datak[5:3], rx_error[5:2]});
                        sym_cnt                         <= #TP sym_cnt + 8;
                    end else if (sdps[0] | stps[0]) begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP rx_data[63:0];
                        dllp_start[NW_MAX-1]            <= #TP 0;
                        dllp_start[NW_MAX-2]            <= #TP sdps[0] & !(|{rx_datak[3:1], rx_error[3:0]});
                        tlp_start[NW_MAX-1]             <= #TP 0;
                        tlp_start[NW_MAX-2]             <= #TP stps[0] & !(|{rx_datak[3:1], rx_error[3:0]});
                        nak[NW_MAX-1]                   <= #TP 0;
                        nak[NW_MAX-2]                   <= #TP (stps[0] & (|{rx_datak[3:1], rx_error[3:0]})) | overflow_stps[0];
                        pkt_end[NW_MAX-1]               <= #TP packet_ip_a & (|{rx_datak[7:4], rx_error[7:4]});
                        pkt_end[NW_MAX-2]               <= #TP 0;
                        pkt_edb[NW_MAX-1]               <= #TP edbs[7];
                        pkt_edb[NW_MAX-2]               <= #TP 0;
                        pkt_err[NW_MAX-1]               <= #TP packet_ip_a & ((rx_datak[7] & !(ends[7] | edbs[7])) | (|{rx_datak[6:4], rx_error[7:4]}));
                        pkt_err[NW_MAX-2]               <= #TP 0;
                        packet_in_progress              <= #TP packet_ip_c;
                        sym_cnt                         <= #TP sym_cnt + 6;
                    end else if (overflow_sdps[0] | overflow_stps[0]) begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP {rx_data[47:0], overflow_data[15:0]};
                        dllp_start[NW_MAX-1]            <= #TP 0;
                        dllp_start[NW_MAX-2]            <= #TP overflow_sdps[0] & !(|{rx_datak[1:0], overflow_datak[1], rx_error[1:0], overflow_error[1:0]});
                        tlp_start[NW_MAX-1]             <= #TP 0;
                        tlp_start[NW_MAX-2]             <= #TP overflow_stps[0] & !(|{rx_datak[1:0], overflow_datak[1], rx_error[1:0], overflow_error[1:0]});
                        nak[NW_MAX-1]                   <= #TP 0;
                        nak[NW_MAX-2]                   <= #TP overflow_stps[0] & (|{rx_datak[1:0], overflow_datak[1], rx_error[1:0], overflow_error[1:0]});
                        pkt_end[NW_MAX-1]               <= #TP packet_ip_o & (|{rx_datak[5:2], rx_error[5:2]});
                        pkt_end[NW_MAX-2]               <= #TP 0;
                        pkt_edb[NW_MAX-1]               <= #TP edbs[5];
                        pkt_edb[NW_MAX-2]               <= #TP 0;
                        pkt_err[NW_MAX-1]               <= #TP packet_ip_o & ((rx_datak[5] & !(ends[5] | edbs[5])) | (|{rx_datak[4:2], rx_error[5:2]}));
                        pkt_err[NW_MAX-2]               <= #TP 0;
                        packet_in_progress              <= #TP packet_ip_b;
                        sym_cnt                         <= #TP sym_cnt + 8;
                    end else begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP rx_data[63:0];
                        dllp_start[NW_MAX-1:NW_MAX-2]   <= #TP 0;
                        tlp_start[NW_MAX-1:NW_MAX-2]    <= #TP 0;
                        nak[NW_MAX-1:NW_MAX-2]          <= #TP 0;
                        pkt_end[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_edb[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_err[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        packet_in_progress              <= #TP 0;
                        sym_cnt                         <= #TP sym_cnt + 8;
                    end
                end else begin // !packet_in_progress && !sym_cnt[1]
                    if (sdps[4] | stps[4]) begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP rx_data[63:0];
                        dllp_start[NW_MAX-1]            <= #TP sdps[4] & !(|{rx_datak[7:5], rx_error[7:4]});
                        dllp_start[NW_MAX-2]            <= #TP 0;
                        tlp_start[NW_MAX-1]             <= #TP stps[4] & !(|{rx_datak[7:5], rx_error[7:4]});
                        tlp_start[NW_MAX-2]             <= #TP 0;
                        nak[NW_MAX-1]                   <= #TP stps[4] & (|{rx_datak[7:5], rx_error[7:4]});
                        nak[NW_MAX-2]                   <= #TP |{stps[2], stps[0]};
                        pkt_end[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_edb[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_err[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        packet_in_progress              <= #TP !(|{rx_datak[7:5], rx_error[7:4]});
                        sym_cnt                         <= #TP sym_cnt + 8;
                    end else if (sdps[2] | stps[2]) begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP {rx_data[47:0], overflow_data[15:0]};
                        dllp_start[NW_MAX-1]            <= #TP sdps[2] & !(|{rx_datak[5:3], rx_error[5:2]});
                        dllp_start[NW_MAX-2]            <= #TP 0;
                        tlp_start[NW_MAX-1]             <= #TP stps[2] & !(|{rx_datak[5:3], rx_error[5:2]});
                        tlp_start[NW_MAX-2]             <= #TP 0;
                        nak[NW_MAX-1]                   <= #TP stps[2] & (|{rx_datak[5:3], rx_error[5:2]});
                        nak[NW_MAX-2]                   <= #TP stps[0];
                        pkt_end[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_edb[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_err[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        packet_in_progress              <= #TP !(|{rx_datak[5:3], rx_error[5:2]});
                        sym_cnt                         <= #TP sym_cnt + 10;
                    end else if (sdps[0] | stps[0]) begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP rx_data[63:0];
                        dllp_start[NW_MAX-1]            <= #TP 0;
                        dllp_start[NW_MAX-2]            <= #TP sdps[0] & !(|{rx_datak[3:1], rx_error[3:0]});
                        tlp_start[NW_MAX-1]             <= #TP 0;
                        tlp_start[NW_MAX-2]             <= #TP stps[0] & !(|{rx_datak[3:1], rx_error[3:0]});
                        nak[NW_MAX-1]                   <= #TP 0;
                        nak[NW_MAX-2]                   <= #TP stps[0] & (|{rx_datak[3:1], rx_error[3:0]});
                        pkt_end[NW_MAX-1]               <= #TP packet_ip_a & (|{rx_datak[7:4], rx_error[7:4]});
                        pkt_end[NW_MAX-2]               <= #TP 0;
                        pkt_edb[NW_MAX-1]               <= #TP edbs[7];
                        pkt_edb[NW_MAX-2]               <= #TP 0;
                        pkt_err[NW_MAX-1]               <= #TP packet_ip_a & ((rx_datak[7] & !(ends[7] | edbs[7])) | (|{rx_datak[6:4], rx_error[7:4]}));
                        pkt_err[NW_MAX-2]               <= #TP 0;
                        packet_in_progress              <= #TP packet_ip_c;
                        sym_cnt                         <= #TP sym_cnt + 8;
                    end else if (overflow_sdps[0] | overflow_stps[0]) begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP {rx_data[47:0], overflow_data[15:0]};
                        dllp_start[NW_MAX-1]            <= #TP 0;
                        dllp_start[NW_MAX-2]            <= #TP overflow_sdps[0] & !(|{rx_datak[1:0], overflow_datak[1], rx_error[1:0], overflow_error[1:0]});
                        tlp_start[NW_MAX-1]             <= #TP 0;
                        tlp_start[NW_MAX-2]             <= #TP overflow_stps[0] & !(|{rx_datak[1:0], overflow_datak[1], rx_error[1:0], overflow_error[1:0]});
                        nak[NW_MAX-1]                   <= #TP 0;
                        nak[NW_MAX-2]                   <= #TP overflow_stps[0] & (|{rx_datak[1:0], overflow_datak[1], rx_error[1:0], overflow_error[1:0]});
                        pkt_end[NW_MAX-1]               <= #TP packet_ip_o & (|{rx_datak[5:2], rx_error[5:2]});
                        pkt_end[NW_MAX-2]               <= #TP 0;
                        pkt_edb[NW_MAX-1]               <= #TP edbs[5];
                        pkt_edb[NW_MAX-2]               <= #TP 0;
                        pkt_err[NW_MAX-1]               <= #TP packet_ip_o & ((rx_datak[5] & !(ends[5] | edbs[5])) | (|{rx_datak[4:2], rx_error[5:2]}));
                        pkt_err[NW_MAX-2]               <= #TP 0;
                        packet_in_progress              <= #TP packet_ip_b;
                        sym_cnt                         <= #TP sym_cnt + 10;
                    end else if (sdps[6] | stps[6]) begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP rx_data[63:0];
                        dllp_start[NW_MAX-1:NW_MAX-2]   <= #TP 0;
                        tlp_start[NW_MAX-1:NW_MAX-2]    <= #TP 0;
                        nak[NW_MAX-1]                   <= #TP 0;
                        nak[NW_MAX-2]                   <= #TP |{stps[4], stps[2], stps[0]};
                        pkt_end[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_edb[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_err[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        packet_in_progress              <= #TP 0;
                        sym_cnt                         <= #TP sym_cnt + 10;
                    end else begin
                        pkt_data[DW_MAX-1:DW_MAX-64]    <= #TP rx_data[63:0];
                        dllp_start[NW_MAX-1:NW_MAX-2]   <= #TP 0;
                        tlp_start[NW_MAX-1:NW_MAX-2]    <= #TP 0;
                        nak[NW_MAX-1:NW_MAX-2]          <= #TP 0;
                        pkt_end[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_edb[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        pkt_err[NW_MAX-1:NW_MAX-2]      <= #TP 0;
                        packet_in_progress              <= #TP 0;
                        sym_cnt                         <= #TP sym_cnt + 8;
                    end
                end
            end
        end
        else begin // 1sx8, 2sx4 (8-byte valid data)
            sym_cnt                          <= #TP sym_cnt + 8;

            pkt_data[DW_MAX-1:DW_MAX-64]     <= #TP rx_data[63:0];
            dllp_start[NW_MAX-2]             <= #TP sdps[0] & !(|rx_datak[3:1] | (|rx_error[3:0]));
            dllp_start[NW_MAX-1]             <= #TP sdps[4] & !(|rx_datak[7:5] | (|rx_error[7:4]));
            tlp_start[NW_MAX-2]              <= #TP stps[0] & !(|rx_datak[3:1] | (|rx_error[3:0]));
            tlp_start[NW_MAX-1]              <= #TP stps[4] & !(|rx_datak[7:5] | (|rx_error[7:4]));
            nak[NW_MAX-2]                    <= #TP stps[0] &  (|rx_datak[3:1] | (|rx_error[3:0]));
            nak[NW_MAX-1]                    <= #TP stps[4] &  (|rx_datak[7:5] | (|rx_error[7:4]));

            pkt_end[NW_MAX-2]                <= #TP packet_ip[0] & ((|rx_datak[3:0]) | (|rx_error[3:0]));
            pkt_end[NW_MAX-1]                <= #TP packet_ip[1] & ((|rx_datak[7:4]) | (|rx_error[7:4]));
            pkt_edb[NW_MAX-2]                <= #TP edbs[3];
            pkt_edb[NW_MAX-1]                <= #TP edbs[7];

            packet_in_progress               <= #TP packet_ip[2];
            pkt_err[NW_MAX-2]                <= #TP packet_ip[0] & ((rx_datak[3] & !(ends[3] | edbs[3])) | (|rx_datak[2:0]) | (|rx_error[3:0]));
            pkt_err[NW_MAX-1]                <= #TP packet_ip[1] & ((rx_datak[7] & !(ends[7] | edbs[7])) | (|rx_datak[6:4]) | (|rx_error[7:4]));
        end

        // Move lower 8 to upper 8
        pkt_data[DW_MAX-65:DW_MAX-128]  <= #TP pkt_data[DW_MAX-1:DW_MAX-64];
        dllp_start[NW_MAX-3:NW_MAX-4]   <= #TP dllp_start[NW_MAX-1:NW_MAX-2];
        tlp_start[NW_MAX-3:NW_MAX-4]    <= #TP tlp_start[NW_MAX-1:NW_MAX-2];
        pkt_end[NW_MAX-3:NW_MAX-4]      <= #TP pkt_end[NW_MAX-1:NW_MAX-2];
        pkt_edb[NW_MAX-3:NW_MAX-4]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-2];
        pkt_err[NW_MAX-3:NW_MAX-4]      <= #TP pkt_err[NW_MAX-1:NW_MAX-2];

        if (sym_cnt[4:3] == 2) begin
            // Move lower 16 to upper 16
            pkt_data[DW_MAX-129:DW_MAX-256] <= #TP pkt_data[DW_MAX-1:DW_MAX-128];
            dllp_start[NW_MAX-5:NW_MAX-8]   <= #TP dllp_start[NW_MAX-1:NW_MAX-4];
            tlp_start[NW_MAX-5:NW_MAX-8]    <= #TP tlp_start[NW_MAX-1:NW_MAX-4];
            pkt_end[NW_MAX-5:NW_MAX-8]      <= #TP pkt_end[NW_MAX-1:NW_MAX-4];
            pkt_edb[NW_MAX-5:NW_MAX-8]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-4];
            pkt_err[NW_MAX-5:NW_MAX-8]      <= #TP pkt_err[NW_MAX-1:NW_MAX-4];
        end

        if (sym_cnt[5:3] == 4) begin
            // Move lower 32 to upper 32
            pkt_data[DW_MAX-257:DW_MAX-512]  <= #TP pkt_data[DW_MAX-1:DW_MAX-256];
            dllp_start[NW_MAX-9:NW_MAX-16]   <= #TP dllp_start[NW_MAX-1:NW_MAX-8];
            tlp_start[NW_MAX-9:NW_MAX-16]    <= #TP tlp_start[NW_MAX-1:NW_MAX-8];
            pkt_end[NW_MAX-9:NW_MAX-16]      <= #TP pkt_end[NW_MAX-1:NW_MAX-8];
            pkt_edb[NW_MAX-9:NW_MAX-16]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-8];
            pkt_err[NW_MAX-9:NW_MAX-16]      <= #TP pkt_err[NW_MAX-1:NW_MAX-8];
        end
    end else if (valid_bytes[2]==1'b1) begin // 4-byte valid data
        if (active_sym_gen12[2]==1) begin // 4sx1 (link_mode = 5'b00001)
            overflow_data[23:0]       <= #TP rx_data[31:8];
            overflow_sdps[2:0]        <= #TP sdps[3:1];
            overflow_stps[2:0]        <= #TP stps[3:1];
            overflow_datak[2:0]       <= #TP rx_datak[3:1];
            overflow_error[2:0]       <= #TP rx_error[3:1];
            pkt_dv                    <= #TP (NW==16) ? (sym_cnt[5:2] == 4'b1111) :
                                             (NW==8)  ? (sym_cnt[4:2] == 3'b111)  :
                                             (NW==4)  ? (sym_cnt[3:2] == 2'b11)   :
                                             (NW==2)  ? (sym_cnt[2] == 1'b1)      : 1'b1;
            if (packet_in_progress) begin
                case (sym_cnt[1:0])
                    2'b00: begin
                        pkt_data[DW_MAX-1:DW_MAX-32]    <= #TP rx_data[31:0];
                        dllp_start[NW_MAX-1]            <= #TP 1'b0;
                        tlp_start[NW_MAX-1]             <= #TP 1'b0;
                        nak[NW_MAX-1]                   <= #TP 1'b0;
                        pkt_end[NW_MAX-1]               <= #TP |{rx_datak[3:0], rx_error[3:0]};
                        pkt_edb[NW_MAX-1]               <= #TP edbs[3];
                        pkt_err[NW_MAX-1]               <= #TP (rx_datak[3] & !(edbs[3] | ends[3])) | (|{rx_datak[2:0], rx_error[3:0]});
                        packet_in_progress              <= #TP !(|{rx_datak[3:0], rx_error[3:0]});
                    end
                    2'b01: begin
                        pkt_data[DW_MAX-1:DW_MAX-32]    <= #TP {rx_data[23:0], overflow_data[23:16]};
                        dllp_start[NW_MAX-1]            <= #TP 1'b0;
                        tlp_start[NW_MAX-1]             <= #TP 1'b0;
                        nak[NW_MAX-1]                   <= #TP 1'b0;
                        pkt_end[NW_MAX-1]               <= #TP |{rx_datak[2:0], overflow_datak[2], rx_error[2:0], overflow_error[2]};
                        pkt_edb[NW_MAX-1]               <= #TP edbs[2];
                        pkt_err[NW_MAX-1]               <= #TP (rx_datak[2] & !(edbs[2] | ends[2])) | (|{rx_datak[1:0], overflow_datak[2], rx_error[2:0], overflow_error[2]});
                        packet_in_progress              <= #TP !(|{rx_datak[2:0], overflow_datak[2], rx_error[2:0], overflow_error[2]});
                    end
                    2'b10: begin
                        pkt_data[DW_MAX-1:DW_MAX-32]    <= #TP {rx_data[15:0], overflow_data[23:8]};
                        dllp_start[NW_MAX-1]            <= #TP 1'b0;
                        tlp_start[NW_MAX-1]             <= #TP 1'b0;
                        nak[NW_MAX-1]                   <= #TP 1'b0;
                        pkt_end[NW_MAX-1]               <= #TP |{rx_datak[1:0], overflow_datak[2:1], rx_error[1:0], overflow_error[2:1]};
                        pkt_edb[NW_MAX-1]               <= #TP edbs[1];
                        pkt_err[NW_MAX-1]               <= #TP (rx_datak[1] & !(edbs[1] | ends[1])) | (|{rx_datak[0], overflow_datak[2:1], rx_error[1:0], overflow_error[2:1]});
                        packet_in_progress              <= #TP !(|{rx_datak[1:0], overflow_datak[2:1], rx_error[1:0], overflow_error[2:1]});
                    end
                    2'b11: begin
                        pkt_data[DW_MAX-1:DW_MAX-32]    <= #TP {rx_data[7:0], overflow_data[23:0]};
                        dllp_start[NW_MAX-1]            <= #TP 1'b0;
                        tlp_start[NW_MAX-1]             <= #TP 1'b0;
                        nak[NW_MAX-1]                   <= #TP 1'b0;
                        pkt_end[NW_MAX-1]               <= #TP |{rx_datak[0], overflow_datak[2:0], rx_error[0], overflow_error[2:0]};
                        pkt_edb[NW_MAX-1]               <= #TP edbs[0];
                        pkt_err[NW_MAX-1]               <= #TP (rx_datak[0] & !(edbs[0] | ends[0])) | (|{overflow_datak[2:0], rx_error[0], overflow_error[2:0]});
                        packet_in_progress              <= #TP !(|{rx_datak[0], overflow_datak[2:0], rx_error[0], overflow_error[2:0]});
                    end
                endcase
                        sym_cnt                         <= #TP sym_cnt + 4;
            end else begin // !packet_in_progress
                case (sym_cnt[1:0])
                    2'b00: begin
                        pkt_data[DW_MAX-1:DW_MAX-32]    <= #TP rx_data[31:0];
                        dllp_start[NW_MAX-1]            <= #TP sdps[0] & !(|{rx_datak[3:1], rx_error[3:0]});
                        tlp_start[NW_MAX-1]             <= #TP stps[0] & !(|{rx_datak[3:1], rx_error[3:0]});
                        nak[NW_MAX-1]                   <= #TP stps[0] & (|{rx_datak[3:1], rx_error[3:0]});
                        pkt_end[NW_MAX-1]               <= #TP 0;
                        pkt_edb[NW_MAX-1]               <= #TP 0;
                        pkt_err[NW_MAX-1]               <= #TP 0;
                        packet_in_progress              <= #TP (sdps[0] | stps[0]) & !(|{rx_datak[3:1], rx_error[3:0]});
                        sym_cnt                         <= #TP sym_cnt + ((sdps[0] | stps[0]) ? 4 :
                                                                          (sdps[1] | stps[1]) ? 7 :
                                                                          (sdps[2] | stps[2]) ? 6 :
                                                                          (sdps[3] | stps[3]) ? 5 : 4);
                    end
                    2'b01: begin
                        pkt_data[DW_MAX-1:DW_MAX-32]    <= #TP (overflow_sdps[2] | overflow_stps[2]) & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]}) ? {rx_data[23:0], overflow_data[23:16]} :
                                                                                                                                                                rx_data[31:0];
                        dllp_start[NW_MAX-1]            <= #TP (overflow_sdps[2] & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})) |
                                                               (sdps[0] & !(|{rx_datak[3:1], rx_error[3:0]}));
                        tlp_start[NW_MAX-1]             <= #TP (overflow_stps[2] & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})) |
                                                               (stps[0] & !(|{rx_datak[3:1], rx_error[3:0]}));
                        nak[NW_MAX-1]                   <= #TP (overflow_stps[2] & (|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})) |
                                                               (stps[0] & (|{rx_datak[3:1], rx_error[3:0]}));
                        pkt_end[NW_MAX-1]               <= #TP 0;
                        pkt_edb[NW_MAX-1]               <= #TP 0;
                        pkt_err[NW_MAX-1]               <= #TP 0;
                        packet_in_progress              <= #TP ((overflow_sdps[2] | overflow_stps[2]) & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})) |
                                                               ((sdps[0] | stps[0]) & !(|{rx_datak[3:1], rx_error[3:0]}));
                        sym_cnt                         <= #TP sym_cnt + ((overflow_sdps[2] | overflow_stps[2]) & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]}) ? 4 :
                                                                          (sdps[0] | stps[0])                                                                           ? 3 :
                                                                          (sdps[1] | stps[1])                                                                           ? 6 :
                                                                          (sdps[2] | stps[2])                                                                           ? 5 :
                                                                          (sdps[3] | stps[3])                                                                           ? 4 : 3);
                    end
                    2'b10: begin
                        pkt_data[DW_MAX-1:DW_MAX-32]    <= #TP (overflow_sdps[1] | overflow_stps[1]) & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]}) ? {rx_data[15:0], overflow_data[23:8]} :
                                                               (overflow_sdps[2] | overflow_stps[2]) & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})                      ? {rx_data[23:0], overflow_data[23:16]} :
                                                                                                                                                                                     rx_data[31:0];
                        dllp_start[NW_MAX-1]            <= #TP (overflow_sdps[1] & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]})) |
                                                               (overflow_sdps[2] & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})) |
                                                               (sdps[0] & !(|{rx_datak[3:1], rx_error[3:0]}));
                        tlp_start[NW_MAX-1]             <= #TP (overflow_stps[1] & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]})) |
                                                               (overflow_stps[2] & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2], overflow_stps[1]})) |
                                                               (stps[0] & !(|{rx_datak[3:1], rx_error[3:0], overflow_stps[2:1]}));
                        nak[NW_MAX-1]                   <= #TP (overflow_stps[1] & (|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]})) |
                                                               (overflow_stps[2] & (|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})) |
                                                               (stps[0] & (|{rx_datak[3:1], rx_error[3:0]}));
                        pkt_end[NW_MAX-1]               <= #TP 0;
                        pkt_edb[NW_MAX-1]               <= #TP 0;
                        pkt_err[NW_MAX-1]               <= #TP 0;
                        packet_in_progress              <= #TP ((overflow_sdps[1] | overflow_stps[1]) & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]})) |
                                                               ((overflow_sdps[2] | overflow_stps[2]) & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2], overflow_stps[1]})) |
                                                               ((sdps[0] | stps[0]) & !(|{rx_datak[3:1], rx_error[3:0], overflow_stps[2:1]}));
                        sym_cnt                         <= #TP sym_cnt + ((overflow_sdps[1] | overflow_stps[1]) & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]}) ? 4 :
                                                                          (overflow_sdps[2] | overflow_stps[2]) & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})                      ? 3 :
                                                                          (sdps[0] | stps[0])                                                                                                ? 2 :
                                                                          (sdps[1] | stps[1])                                                                                                ? 5 :
                                                                          (sdps[2] | stps[2])                                                                                                ? 4 :
                                                                          (sdps[3] | stps[3])                                                                                                ? 3 : 2);
                    end
                    2'b11: begin
                        pkt_data[DW_MAX-1:DW_MAX-32]    <= #TP (overflow_sdps[0] | overflow_stps[0]) & !(|{rx_datak[0], overflow_datak[2:1], rx_error[0], overflow_error[2:0]})   ? {rx_data[7:0], overflow_data[23:0]} :
                                                               (overflow_sdps[1] | overflow_stps[1]) & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]}) ? {rx_data[15:0], overflow_data[23:8]} :
                                                               (overflow_sdps[2] | overflow_stps[2]) & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})                      ? {rx_data[23:0], overflow_data[23:16]} :
                                                                                                                                                                                     rx_data[31:0];
                        dllp_start[NW_MAX-1]            <= #TP (overflow_sdps[0] & !(|{rx_datak[0], overflow_datak[2:1], rx_error[0], overflow_error[2:0]})) |
                                                               (overflow_sdps[1] & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]})) |
                                                               (overflow_sdps[2] & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})) |
                                                               (sdps[0] & !(|{rx_datak[3:1], rx_error[3:0]}));
                        tlp_start[NW_MAX-1]             <= #TP (overflow_stps[0] & !(|{rx_datak[0], overflow_datak[2:1], rx_error[0], overflow_error[2:0]})) |
                                                               (overflow_stps[1] & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1], overflow_stps[0]})) |
                                                               (overflow_stps[2] & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2], overflow_stps[1:0]})) |
                                                               (stps[0] & !(|{rx_datak[3:1], rx_error[3:0], overflow_stps[2:0]}));
                        nak[NW_MAX-1]                   <= #TP (overflow_stps[0] & (|{rx_datak[0], overflow_datak[2:1], rx_error[0], overflow_error[2:0]})) |
                                                               (overflow_stps[1] & (|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]})) |
                                                               (overflow_stps[2] & (|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})) |
                                                               (stps[0] & (|{rx_datak[3:1], rx_error[3:0]}));
                        pkt_end[NW_MAX-1]               <= #TP 0;
                        pkt_edb[NW_MAX-1]               <= #TP 0;
                        pkt_err[NW_MAX-1]               <= #TP 0;
                        packet_in_progress              <= #TP ((overflow_sdps[0] | overflow_stps[0]) & !(|{rx_datak[0], overflow_datak[2:1], rx_error[0], overflow_error[2:0]})) |
                                                               ((overflow_sdps[1] | overflow_stps[1]) & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1], overflow_stps[0]})) |
                                                               ((overflow_sdps[2] | overflow_stps[2]) & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2], overflow_stps[1:0]})) |
                                                               ((sdps[0] | stps[0]) & !(|{rx_datak[3:1], rx_error[3:0], overflow_stps[2:0]}));
                        sym_cnt                         <= #TP sym_cnt + ((overflow_sdps[0] | overflow_stps[0]) & !(|{rx_datak[0], overflow_datak[2:1], rx_error[0], overflow_error[2:0]})   ? 4 :
                                                                          (overflow_sdps[1] | overflow_stps[1]) & !(|{rx_datak[1:0], overflow_datak[2], rx_error[1:0], overflow_error[2:1]}) ? 3 :
                                                                          (overflow_sdps[2] | overflow_stps[2]) & !(|{rx_datak[2:0], rx_error[2:0], overflow_error[2]})                      ? 2 :
                                                                          (sdps[0] | stps[0])                                                                                                ? 1 :
                                                                          (sdps[1] | stps[1])                                                                                                ? 4 :
                                                                          (sdps[2] | stps[2])                                                                                                ? 3 :
                                                                          (sdps[3] | stps[3])                                                                                                ? 2 : 1);
                    end
                endcase
            end
        end
        else if (active_sym_gen12[1]==1) begin // 2sx2 (link_mode = 5'b00010)
            overflow_data[15:0]       <= #TP rx_data[31:16];
            overflow_sdps[0]          <= #TP sdps[2];
            overflow_stps[0]          <= #TP stps[2];
            overflow_datak            <= #TP {1'b0, rx_datak[3:2]};
            overflow_error            <= #TP {1'b0, rx_error[3:2]};

            if (packet_in_progress) begin
                if (sym_cnt[1]) begin       // Started on b
                    pkt_data[`WORD0]          <= #TP overflow_data[15:0];
                    pkt_data[`WORD1]          <= #TP rx_data[15:0];
                    dllp_start[NW_MAX-1]      <= #TP 1'b0;
                    tlp_start[NW_MAX-1]       <= #TP 1'b0;
                    nak[NW_MAX-1]             <= #TP 1'b0;
                    pkt_end[NW_MAX-1]         <= #TP (|rx_datak[1:0]) | (|overflow_datak[1:0]) | (|rx_error[1:0]) | (|overflow_error[1:0]);
                    pkt_edb[NW_MAX-1]         <= #TP edbs[1];
                    pkt_err[NW_MAX-1]         <= #TP ((|rx_error[1:0]) | (|overflow_error) | rx_datak[0] | (|overflow_datak[1:0]) | (rx_datak[1] & !(edbs[1] | ends[1])));
                    packet_in_progress        <= #TP |{rx_datak[1:0], overflow_datak, rx_error[1:0], overflow_error} ? 1'b0 : packet_in_progress;
                    sym_cnt                   <= #TP sym_cnt + 4;
                    pkt_dv                    <= #TP (NW==16) ? (sym_cnt[5:2] == 4'b1111) :
                                                     (NW==8)  ? (sym_cnt[4:2] == 3'b111)  :
                                                     (NW==4)  ? (sym_cnt[3:2] == 2'b11)   :
                                                     (NW==2)  ? (sym_cnt[2] == 1'b1)      : 1'b1;
                end else begin              // Started on a
                    pkt_data[`WORD0]          <= #TP rx_data[15:0];
                    pkt_data[`WORD1]          <= #TP rx_data[31:16];
                    dllp_start[NW_MAX-1]      <= #TP 1'b0;
                    tlp_start[NW_MAX-1]       <= #TP 1'b0;
                    nak[NW_MAX-1]             <= #TP 1'b0;
                    pkt_end[NW_MAX-1]         <= #TP (|rx_datak[1:0]) | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2]);
                    pkt_edb[NW_MAX-1]         <= #TP edbs[3];
                    pkt_err[NW_MAX-1]         <= #TP (((|rx_error[1:0]) | (|rx_error[3:2]) | rx_datak[2] | (|rx_datak[1:0])) | (rx_datak[3] & !(edbs[3] | ends[3])));
                    packet_in_progress        <= #TP ((|rx_datak[1:0]) | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2])) ? 1'b0 : packet_in_progress;
                    sym_cnt                   <= #TP sym_cnt + 4;
                    pkt_dv                    <= #TP (NW==16) ? (sym_cnt[5:2] == 4'b1111) :
                                                     (NW==8)  ? (sym_cnt[4:2] == 3'b111)  :
                                                     (NW==4)  ? (sym_cnt[3:2] == 2'b11)   :
                                                     (NW==2)  ? (sym_cnt[2] == 1'b1)      : 1'b1;
                end
            end else begin // !packet_in_progress
                if (sym_cnt[1]) begin       // Valid data in overflow
                    pkt_data[`WORD0]          <= #TP (sdps[0] | stps[0]) ? rx_data[15:0] : overflow_data[15:0];
                    pkt_data[`WORD1]          <= #TP (sdps[0] | stps[0]) ? rx_data[31:16] : rx_data[15:0];
                    dllp_start[NW_MAX-1]      <= #TP (overflow_sdps[0] & !(overflow_datak[1] | (|rx_datak[1:0]) | (|rx_error[1:0]) | (|overflow_error[1:0]))) |
                                                     (sdps[0] & !(rx_datak[1] | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2])));
                    tlp_start[NW_MAX-1]       <= #TP (overflow_stps[0] & !(overflow_datak[1] | (|rx_datak[1:0]) | (|rx_error[1:0]) | (|overflow_error[1:0]))) |
                                                     (stps[0] & !(rx_datak[1] | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2])));
                    nak[NW_MAX-1]             <= #TP (overflow_stps[0] &  (overflow_datak[1] | (|rx_datak[1:0]) | (|rx_error[1:0]) | (|overflow_error[1:0]))) |
                                                     (stps[0] &  (rx_datak[1] | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2])));
                    pkt_end[NW_MAX-1]         <= #TP 1'b0;
                    pkt_edb[NW_MAX-1]         <= #TP 1'b0;
                    pkt_err[NW_MAX-1]         <= #TP 1'b0;
                    packet_in_progress        <= #TP ((overflow_sdps[0] | overflow_stps[0]) & !(overflow_datak[1] | (|rx_datak[1:0]) | (|rx_error[1:0]) | (|overflow_error[1:0]))) |
                                                     ((sdps[0] | stps[0]) & !(rx_datak[1] | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2])));
                    // Here, we get realigned if we can
                    sym_cnt                   <= #TP sym_cnt + ((stps[2] | sdps[2])                   ? 3'b100 :
                                                                (stps[0] | sdps[0])                   ? 3'b010 :
                                                                (overflow_sdps[0] | overflow_stps[0]) ? 3'b100 : 3'b010);
                    alignment_flip            <= #TP 1'b0;
                    pkt_dv                    <= #TP (NW==16) ? (sym_cnt[5:2] == 4'b1111) :
                                                     (NW==8)  ? (sym_cnt[4:2] == 3'b111)  :
                                                     (NW==4)  ? (sym_cnt[3:2] == 2'b11)   :
                                                     (NW==2)  ? (sym_cnt[2] == 1'b1)      : 1'b1;

                end else begin // !sym_cnt[1] // Wait for start of packet
                    pkt_data[`WORD0]          <= #TP rx_data[15:0];
                    pkt_data[`WORD1]          <= #TP rx_data[31:16];
                    dllp_start[NW_MAX-1]      <= #TP (sdps[0] & !(rx_datak[1] | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2])));
                    tlp_start[NW_MAX-1]       <= #TP (stps[0] & !(rx_datak[1] | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2])));
                    nak[NW_MAX-1]             <= #TP (stps[0] &  (rx_datak[1] | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2])));
                    pkt_end[NW_MAX-1]         <= #TP 1'b0;
                    pkt_edb[NW_MAX-1]         <= #TP 1'b0;
                    pkt_err[NW_MAX-1]         <= #TP 1'b0;
                    packet_in_progress        <= #TP (sdps[0] | stps[0]) & !(rx_datak[1] | (|rx_datak[3:2]) | (|rx_error[1:0]) | (|rx_error[3:2]));
                    sym_cnt                   <= #TP (stps[2] | sdps[2]) ? {sym_cnt[5:2], 2'b10} : sym_cnt + 4;
                    alignment_flip            <= #TP (stps[2] | sdps[2]);
                    pkt_dv                    <= #TP (stps[2] | sdps[2]) ? 1'b0           :
                                                     (NW==16) ? (sym_cnt[5:2] == 4'b1111) :
                                                     (NW==8)  ? (sym_cnt[4:2] == 3'b111)  :
                                                     (NW==4)  ? (sym_cnt[3:2] == 2'b11)   :
                                                     (NW==2)  ? (sym_cnt[2] == 1'b1)      : 1'b1;

                end
            end
        end
        else if (active_sym_gen12[0]==1) begin // 1sx4 (link_mode = 5'b00100)
            pkt_dv                          <= #TP (NW==16) ? (sym_cnt[5:2] == 4'b1111) :
                                                   (NW==8)  ? (sym_cnt[4:2] == 3'b111)  :
                                                   (NW==4)  ? (sym_cnt[3:2] == 2'b11)   :
                                                   (NW==2)  ? (sym_cnt[2] == 1'b1)      : 1'b1;
            pkt_data[DW_MAX-1:DW_MAX-32]    <= #TP rx_data[31:0];
            dllp_start[NW_MAX-1]            <= #TP sdps[0] & !(|rx_datak[3:1] | (|rx_error[3:0]));
            tlp_start[NW_MAX-1]             <= #TP stps[0] & !(|rx_datak[3:1] | (|rx_error[3:0]));
            nak[NW_MAX-1]                   <= #TP stps[0] &  (|rx_datak[3:1] | (|rx_error[3:0]));

            pkt_end[NW_MAX-1]               <= #TP packet_ip[0] & (|rx_datak[3:0] | (|rx_error[3:0]));
            pkt_edb[NW_MAX-1]               <= #TP edbs[3];
            pkt_err[NW_MAX-1]               <= #TP packet_ip[0] & (|rx_datak[2:0] | (|rx_error[3:0]) | (rx_datak[3] & !(ends[3] | edbs[3])));

            // Now handle framing errors
            packet_in_progress              <= #TP packet_ip[1];
            sym_cnt                         <= #TP sym_cnt + 4;
        end
        if ((active_sym_gen12[2]==1) | ((active_sym_gen12[2:1]==2'b01) & (!alignment_flip)) | (active_sym_gen12[1:0]==2'b01) ) begin 
            // Move lower 4 to upper 4
            pkt_data[DW_MAX-33:DW_MAX-64]   <= #TP pkt_data[DW_MAX-1:DW_MAX-32];
            dllp_start[NW_MAX-2]            <= #TP dllp_start[NW_MAX-1];
            tlp_start[NW_MAX-2]             <= #TP tlp_start[NW_MAX-1];
            pkt_end[NW_MAX-2]               <= #TP pkt_end[NW_MAX-1];
            pkt_edb[NW_MAX-2]               <= #TP pkt_edb[NW_MAX-1];
            pkt_err[NW_MAX-2]               <= #TP pkt_err[NW_MAX-1];

            if (sym_cnt[3:2] == 2) begin
                // Move lower 8 to upper 8
                pkt_data[DW_MAX-65:DW_MAX-128]  <= #TP pkt_data[DW_MAX-1:DW_MAX-64];
                dllp_start[NW_MAX-3:NW_MAX-4]   <= #TP dllp_start[NW_MAX-1:NW_MAX-2];
                tlp_start[NW_MAX-3:NW_MAX-4]    <= #TP tlp_start[NW_MAX-1:NW_MAX-2];
                pkt_end[NW_MAX-3:NW_MAX-4]      <= #TP pkt_end[NW_MAX-1:NW_MAX-2];
                pkt_edb[NW_MAX-3:NW_MAX-4]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-2];
                pkt_err[NW_MAX-3:NW_MAX-4]      <= #TP pkt_err[NW_MAX-1:NW_MAX-2];
            end

            if (sym_cnt[4:2] == 4) begin
                // Move lower 16 to upper 16
                pkt_data[DW_MAX-129:DW_MAX-256] <= #TP pkt_data[DW_MAX-1:DW_MAX-128];
                dllp_start[NW_MAX-5:NW_MAX-8]   <= #TP dllp_start[NW_MAX-1:NW_MAX-4];
                tlp_start[NW_MAX-5:NW_MAX-8]    <= #TP tlp_start[NW_MAX-1:NW_MAX-4];
                pkt_end[NW_MAX-5:NW_MAX-8]      <= #TP pkt_end[NW_MAX-1:NW_MAX-4];
                pkt_edb[NW_MAX-5:NW_MAX-8]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-4];
                pkt_err[NW_MAX-5:NW_MAX-8]      <= #TP pkt_err[NW_MAX-1:NW_MAX-4];
            end

            if (sym_cnt[5:2] == 8) begin
                // Move lower 32 to upper 32
                pkt_data[DW_MAX-257:DW_MAX-512]  <= #TP pkt_data[DW_MAX-1:DW_MAX-256];
                dllp_start[NW_MAX-9:NW_MAX-16]   <= #TP dllp_start[NW_MAX-1:NW_MAX-8];
                tlp_start[NW_MAX-9:NW_MAX-16]    <= #TP tlp_start[NW_MAX-1:NW_MAX-8];
                pkt_end[NW_MAX-9:NW_MAX-16]      <= #TP pkt_end[NW_MAX-1:NW_MAX-8];
                pkt_edb[NW_MAX-9:NW_MAX-16]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-8];
                pkt_err[NW_MAX-9:NW_MAX-16]      <= #TP pkt_err[NW_MAX-1:NW_MAX-8];
            end
        end
    end else if (valid_bytes[1]==1'b1) begin // 2-byte valid data
        if (active_sym_gen12[1]==1) begin // 2sx1 (link_mode = 5'b00001)
            overflow_data[7:0]        <= #TP rx_data[15:8];
            overflow_sdps[0]          <= #TP sdps[1];
            overflow_stps[0]          <= #TP stps[1];
            overflow_datak[0]         <= #TP rx_datak[1];
            overflow_error[0]         <= #TP rx_error[1];


            if (packet_in_progress) begin
                case (sym_cnt[1:0])
                    2'b00 : begin   // Started on a
                        pkt_data[`BYTE0]          <= #TP rx_data[7:0];
                        pkt_data[`BYTE1]          <= #TP rx_data[15:8];
                        dllp_start[NW_MAX-1]      <= #TP 1'b0;
                        tlp_start[NW_MAX-1]       <= #TP 1'b0;
                        nak[NW_MAX-1]             <= #TP 1'b0;
                        pkt_end[NW_MAX-1]         <= #TP 1'b0;
                        pkt_edb[NW_MAX-1]         <= #TP 1'b0;
                        pkt_err[NW_MAX-1]         <= #TP rx_datak[0] | rx_datak[1] | rx_error[0] | rx_error[1];
                        sym_cnt                   <= #TP sym_cnt + 2;
                        pkt_dv                    <= #TP 1'b0;
                    end
                    2'b01 : begin   // Started on b
                        pkt_data[`BYTE0]          <= #TP overflow_data[7:0];
                        pkt_data[`BYTE1]          <= #TP rx_data[7:0];
                        dllp_start[NW_MAX-1]      <= #TP 1'b0;
                        tlp_start[NW_MAX-1]       <= #TP 1'b0;
                        nak[NW_MAX-1]             <= #TP 1'b0;
                        pkt_end[NW_MAX-1]         <= #TP 1'b0;
                        pkt_edb[NW_MAX-1]         <= #TP 1'b0;
                        pkt_err[NW_MAX-1]         <= #TP (rx_datak[0] | overflow_datak[0] | rx_error[0] | overflow_error[0]);
                        sym_cnt                   <= #TP sym_cnt + 2;
                        pkt_dv                    <= #TP 1'b0;
                    end
                    2'b10 : begin   // Started on a
                        pkt_data[`BYTE2]          <= #TP rx_data[7:0];
                        pkt_data[`BYTE3]          <= #TP rx_data[15:8];
                        nak[NW_MAX-1]             <= #TP 1'b0;
                        pkt_end[NW_MAX-1]         <= #TP |{rx_datak[0], rx_datak[1], rx_error[0], rx_error[1], pkt_err[NW_MAX-1]};
                        pkt_edb[NW_MAX-1]         <= #TP edbs[1];
                        pkt_err[NW_MAX-1]         <= #TP (pkt_err[NW_MAX-1] | rx_datak[0] | rx_error[0] | rx_error[1] | (rx_datak[1] & !(edbs[1] | ends[1])));
                        packet_in_progress        <= #TP |{rx_datak[0], rx_datak[1], rx_error[0], rx_error[1], pkt_err[NW_MAX-1]} ? 1'b0 : packet_in_progress;
                        sym_cnt                   <= #TP sym_cnt + 2;
                        pkt_dv                    <= #TP (NW==16) ? (sym_cnt[5:1] == 5'b11111) :
                                                         (NW==8)  ? (sym_cnt[4:1] == 4'b1111)  :
                                                         (NW==4)  ? (sym_cnt[3:1] == 3'b111)   :
                                                         (NW==2)  ? (sym_cnt[2:1] == 2'b11)    : (sym_cnt[1] == 1'b1);
                    end
                    2'b11 : begin   // Started on b
                        pkt_data[`BYTE2]          <= #TP overflow_data[7:0];
                        pkt_data[`BYTE3]          <= #TP rx_data[7:0];
                        nak[NW_MAX-1]             <= #TP 1'b0;
                        pkt_end[NW_MAX-1]         <= #TP |{rx_datak[0], overflow_datak[0], rx_error[0], overflow_error[0], pkt_err[NW_MAX-1]};
                        pkt_edb[NW_MAX-1]         <= #TP edbs[0];
                        pkt_err[NW_MAX-1]         <= #TP (pkt_err[NW_MAX-1] | overflow_datak[0] | rx_error[0] | overflow_error[0] | (rx_datak[0] & !(edbs[0] | ends[0])));
                        packet_in_progress        <= #TP |{rx_datak[0], overflow_datak[0], rx_error[0], overflow_error[0], pkt_err[NW_MAX-1]} ? 1'b0 : packet_in_progress;
                        sym_cnt                   <= #TP sym_cnt + 2;
                        alignment_flip            <= #TP 0;
                        pkt_dv                    <= #TP (NW==16) ? (sym_cnt[5:1] == 5'b11111) :
                                                         (NW==8)  ? (sym_cnt[4:1] == 4'b1111)  :
                                                         (NW==4)  ? (sym_cnt[3:1] == 3'b111)   :
                                                         (NW==2)  ? (sym_cnt[2:1] == 2'b11)    : (sym_cnt[1] == 1'b1);
                    end
                endcase
            end else begin // !packet_in_progress
                if (sym_cnt[0]) begin       // Valid data in overflow
                    pkt_data[`BYTE0]          <= #TP (sdps[0] | stps[0]) ? rx_data[7:0] : overflow_data[7:0];
                    pkt_data[`BYTE1]          <= #TP (sdps[0] | stps[0]) ? rx_data[15:8] : rx_data[7:0];
                    dllp_start[NW_MAX-1]      <= #TP (overflow_sdps[0] & !(rx_datak[0] | rx_datak[1] | rx_error[0] | rx_error[1] | overflow_error[0])) |
                                                     (sdps[0] & !(rx_datak[1] | rx_error[0] | rx_error[1]));
                    tlp_start[NW_MAX-1]       <= #TP (overflow_stps[0] & !(rx_datak[0] | rx_datak[1] | rx_error[0] | rx_error[1] | overflow_error[0])) |
                                                     (stps[0] & !(rx_datak[1] | rx_error[0] | rx_error[1]));
                    nak[NW_MAX-1]             <= #TP (overflow_stps[0] & (rx_datak[0] | rx_datak[1] | rx_error[0] | rx_error[1] | overflow_error[0])) |
                                                     (stps[0] & (rx_datak[1] | rx_error[0] | rx_error[1]));
                    pkt_end[NW_MAX-1]         <= #TP 1'b0;
                    pkt_edb[NW_MAX-1]         <= #TP 1'b0;
                    pkt_err[NW_MAX-1]         <= #TP 1'b0;
                    packet_in_progress        <= #TP (overflow_sdps[0] & !(rx_datak[0] | rx_datak[1] | rx_error[0] | rx_error[1] | overflow_error[0])) |
                                                     (sdps[0] & !(rx_datak[1] | rx_error[0] | rx_error[1])) |
                                                     (overflow_stps[0] & !(rx_datak[0] | rx_datak[1] | rx_error[0] | rx_error[1] | overflow_error[0])) |
                                                     (stps[0] & !(rx_datak[1] | rx_error[0] | rx_error[1]));

                    // Here, we get realigned if we can
                    if(stps[1] | sdps[1])                        begin sym_cnt   <= #TP {sym_cnt[5:2],2'b01}; end
                    else if(stps[0] | sdps[0])                   begin sym_cnt   <= #TP {sym_cnt[5:2],2'b10}; end
                    else if(overflow_sdps[0] | overflow_stps[0]) begin sym_cnt   <= #TP {sym_cnt[5:2],2'b11}; end
                    else                                         begin sym_cnt   <= #TP sym_cnt + 2; end

                    alignment_flip            <= #TP (stps[1] | sdps[1]);
                    pkt_dv                    <= #TP (stps[1] | sdps[1] | stps[0] | sdps[0]) ? 0 :
                                                     (NW==16) ? (sym_cnt[5:1] == 5'b11111) :
                                                     (NW==8)  ? (sym_cnt[4:1] == 4'b1111)  :
                                                     (NW==4)  ? (sym_cnt[3:1] == 3'b111)   :
                                                     (NW==2)  ? (sym_cnt[2:1] == 2'b11)    : (sym_cnt[1] == 1'b1);

                end else begin  // !sym_cnt[0] // Wait for start of packet
                    pkt_data[`BYTE0]          <= #TP rx_data[7:0];
                    pkt_data[`BYTE1]          <= #TP rx_data[15:8];
                    dllp_start[NW_MAX-1]      <= #TP (sdps[0] & !(rx_datak[1] | rx_error[0] | rx_error[1]));
                    tlp_start[NW_MAX-1]       <= #TP (stps[0] & !(rx_datak[1] | rx_error[0] | rx_error[1]));
                    nak[NW_MAX-1]             <= #TP (stps[0] & (rx_datak[1] | rx_error[0] | rx_error[1]));
                    pkt_end[NW_MAX-1]         <= #TP 1'b0;
                    pkt_edb[NW_MAX-1]         <= #TP 1'b0;
                    pkt_err[NW_MAX-1]         <= #TP 1'b0;
                    packet_in_progress        <= #TP (sdps[0] & !(rx_datak[1] | rx_error[0] | rx_error[1])) |
                                                     (stps[0] & !(rx_datak[1] | rx_error[0] | rx_error[1]));

                    if(stps[1] | sdps[1])      begin sym_cnt   <= #TP {sym_cnt[5:2],2'b01}; end
                    else if(stps[0] | sdps[0]) begin sym_cnt   <= #TP {sym_cnt[5:2],2'b10}; end
                    else                       begin sym_cnt   <= #TP sym_cnt + 2; end

                    alignment_flip            <= #TP stps[1] | sdps[1];
                    pkt_dv                    <= #TP (stps[1] | sdps[1] | stps[0] | sdps[0]) ? 0 :
                                                     (NW==16) ? (sym_cnt[5:1] == 5'b11111) :
                                                     (NW==8)  ? (sym_cnt[4:1] == 4'b1111)  :
                                                     (NW==4)  ? (sym_cnt[3:1] == 3'b111)   :
                                                     (NW==2)  ? (sym_cnt[2:1] == 2'b11)    : (sym_cnt[1] == 1'b1);
                end
            end
        end
        else if (active_sym_gen12[0]==1) begin // 1sx2 (link_mode = 5'b00010)
            pkt_dv                    <= #TP ((NW==16) ? (sym_cnt[5:1] == 5'b11111) :
                                              (NW==8)  ? (sym_cnt[4:1] == 4'b1111)  :
                                              (NW==4)  ? (sym_cnt[3:1] == 3'b111)   :
                                              (NW==2)  ? (sym_cnt[2:1] == 2'b11)    : sym_cnt[1]) & (packet_in_progress | !(stps[0] | sdps[0]));

            if (packet_in_progress) begin
                case(sym_cnt[1])
                    // Normal
                    1'b0 : begin
                        pkt_data[`WORD0]          <= #TP rx_data[15:0];
                        pkt_err[NW_MAX-1]         <= #TP |rx_datak[1:0] | (|rx_error[1:0]);
                        dllp_start[NW_MAX-1]      <= #TP 1'b0;
                        tlp_start[NW_MAX-1]       <= #TP 1'b0;
                    end
                    1'b1 : begin
                        pkt_data[`WORD1]          <= #TP rx_data[15:0];
                        pkt_end[NW_MAX-1]         <= #TP (|rx_datak[1:0]) | (|rx_error[1:0]) | pkt_err[NW_MAX-1];
                        pkt_edb[NW_MAX-1]         <= #TP edbs[1];
                        pkt_err[NW_MAX-1]         <= #TP (rx_datak[1] & !(edbs[1] | ends[1])) | rx_datak[0] | (|rx_error[1:0]) | pkt_err[NW_MAX-1];
                        packet_in_progress        <= #TP !((|rx_datak[1:0]) | (|rx_error[1:0]) | pkt_err[NW_MAX-1]);
                    end
                endcase
                sym_cnt                   <= #TP sym_cnt + 2;
            end else begin // !packet_in_progress
                pkt_data[`WORD0]          <= #TP rx_data[15:0];
                dllp_start[NW_MAX-1]      <= #TP sdps[0];
                tlp_start[NW_MAX-1]       <= #TP stps[0];
                pkt_end[NW_MAX-1]         <= #TP 1'b0;
                pkt_edb[NW_MAX-1]         <= #TP 1'b0;
                pkt_err[NW_MAX-1]         <= #TP rx_datak[1] | (|rx_error[1:0]);
                packet_in_progress        <= #TP sdps[0] | stps[0];
                sym_cnt                   <= #TP stps[0] | sdps[0] ? {sym_cnt[5:2], 2'b10} : sym_cnt + 2;
            end
        end
        if (((active_sym_gen12[1]==1) & (!alignment_flip)) | (active_sym_gen12[1:0]==2'b01)) begin

            if (sym_cnt[2:1] == 2) begin
                // Move lower 4 to upper 4
                pkt_data[DW_MAX-33:DW_MAX-64]   <= #TP pkt_data[DW_MAX-1:DW_MAX-32];
                dllp_start[NW_MAX-2]            <= #TP dllp_start[NW_MAX-1];
                tlp_start[NW_MAX-2]             <= #TP tlp_start[NW_MAX-1];
                pkt_end[NW_MAX-2]               <= #TP pkt_end[NW_MAX-1];
                pkt_edb[NW_MAX-2]               <= #TP pkt_edb[NW_MAX-1];
                pkt_err[NW_MAX-2]               <= #TP pkt_err[NW_MAX-1];
            end

            if (sym_cnt[3:1] == 4) begin
                // Move lower 8 to upper 8
                pkt_data[DW_MAX-65:DW_MAX-128]  <= #TP pkt_data[DW_MAX-1:DW_MAX-64];
                dllp_start[NW_MAX-3:NW_MAX-4]   <= #TP dllp_start[NW_MAX-1:NW_MAX-2];
                tlp_start[NW_MAX-3:NW_MAX-4]    <= #TP tlp_start[NW_MAX-1:NW_MAX-2];
                pkt_end[NW_MAX-3:NW_MAX-4]      <= #TP pkt_end[NW_MAX-1:NW_MAX-2];
                pkt_edb[NW_MAX-3:NW_MAX-4]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-2];
                pkt_err[NW_MAX-3:NW_MAX-4]      <= #TP pkt_err[NW_MAX-1:NW_MAX-2];
            end

            if (sym_cnt[4:1] == 8) begin
                // Move lower 16 to upper 16
                pkt_data[DW_MAX-129:DW_MAX-256] <= #TP pkt_data[DW_MAX-1:DW_MAX-128];
                dllp_start[NW_MAX-5:NW_MAX-8]   <= #TP dllp_start[NW_MAX-1:NW_MAX-4];
                tlp_start[NW_MAX-5:NW_MAX-8]    <= #TP tlp_start[NW_MAX-1:NW_MAX-4];
                pkt_end[NW_MAX-5:NW_MAX-8]      <= #TP pkt_end[NW_MAX-1:NW_MAX-4];
                pkt_edb[NW_MAX-5:NW_MAX-8]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-4];
                pkt_err[NW_MAX-5:NW_MAX-8]      <= #TP pkt_err[NW_MAX-1:NW_MAX-4];
            end

            if (sym_cnt[5:1] == 16) begin
                // Move lower 32 to upper 32
                pkt_data[DW_MAX-257:DW_MAX-512]  <= #TP pkt_data[DW_MAX-1:DW_MAX-256];
                dllp_start[NW_MAX-9:NW_MAX-16]   <= #TP dllp_start[NW_MAX-1:NW_MAX-8];
                tlp_start[NW_MAX-9:NW_MAX-16]    <= #TP tlp_start[NW_MAX-1:NW_MAX-8];
                pkt_end[NW_MAX-9:NW_MAX-16]      <= #TP pkt_end[NW_MAX-1:NW_MAX-8];
                pkt_edb[NW_MAX-9:NW_MAX-16]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-8];
                pkt_err[NW_MAX-9:NW_MAX-16]      <= #TP pkt_err[NW_MAX-1:NW_MAX-8];
            end

        end
    end else if (valid_bytes[0]==1'b1) begin // 1-byte valid data (1sx1)
        pkt_dv                    <= #TP ((NW==16) ? (sym_cnt[5:0] == 6'b111111) :
                                          (NW==8)  ? (sym_cnt[4:0] == 5'b11111)  :
                                          (NW==4)  ? (sym_cnt[3:0] == 4'b1111)   :
                                          (NW==2)  ? (sym_cnt[2:0] == 3'b111)    : sym_cnt[1:0] == 2'b11) & (packet_in_progress | !(stps[0] | sdps[0]));

        if (packet_in_progress) begin
            case(sym_cnt[1:0])
                2'b00 : begin
                    pkt_data[`BYTE0]          <= #TP rx_data[7:0];
                    dllp_start[NW_MAX-1]      <= #TP 1'b0;
                    tlp_start[NW_MAX-1]       <= #TP 1'b0;
                    pkt_err[NW_MAX-1]         <= #TP rx_datak[0] | rx_error[0];
                end
                2'b01 : begin
                    pkt_data[`BYTE1]          <= #TP rx_data[7:0];
                    pkt_err[NW_MAX-1]         <= #TP rx_datak[0] | rx_error[0] | pkt_err[NW_MAX-1];
                end
                2'b10 : begin
                    pkt_data[`BYTE2]          <= #TP rx_data[7:0];
                    pkt_err[NW_MAX-1]         <= #TP rx_datak[0] | rx_error[0] | pkt_err[NW_MAX-1];
                end
                2'b11 : begin
                    pkt_data[`BYTE3]          <= #TP rx_data[7:0];
                    pkt_end[NW_MAX-1]         <= #TP rx_datak[0] | rx_error[0] | pkt_err[NW_MAX-1];
                    pkt_edb[NW_MAX-1]         <= #TP edbs[0];
                    pkt_err[NW_MAX-1]         <= #TP (rx_datak[0] & !(edbs[0] | ends[0])) | rx_error[0] | pkt_err[NW_MAX-1];
                    packet_in_progress        <= #TP !(rx_datak[0] | rx_error[0] | pkt_err[NW_MAX-1]);
                end
            endcase
            sym_cnt                   <= #TP sym_cnt + 1;
        end else begin // !packet_in_progress
            pkt_data[`BYTE0]         <= #TP rx_data[7:0];
            dllp_start[NW_MAX-1]      <= #TP sdps[0];
            tlp_start[NW_MAX-1]       <= #TP stps[0];
            pkt_end[NW_MAX-1]         <= #TP 1'b0;
            pkt_edb[NW_MAX-1]         <= #TP 1'b0;
            pkt_err[NW_MAX-1]         <= #TP rx_error[0];
            packet_in_progress        <= #TP sdps[0] | stps[0];
            sym_cnt                   <= #TP (stps[0] | sdps[0]) ? {sym_cnt[5:2], 2'b01} : sym_cnt + 1;
        end

        if (sym_cnt[2:0] == 4) begin
            // Move lower 4 to upper 4
            pkt_data[DW_MAX-33:DW_MAX-64]   <= #TP pkt_data[DW_MAX-1:DW_MAX-32];
            dllp_start[NW_MAX-2]            <= #TP dllp_start[NW_MAX-1];
            tlp_start[NW_MAX-2]             <= #TP tlp_start[NW_MAX-1];
            pkt_end[NW_MAX-2]               <= #TP pkt_end[NW_MAX-1];
            pkt_edb[NW_MAX-2]               <= #TP pkt_edb[NW_MAX-1];
            pkt_err[NW_MAX-2]               <= #TP pkt_err[NW_MAX-1];
        end

        if (sym_cnt[3:0] == 8) begin
            // Move lower 8 to upper 8
            pkt_data[DW_MAX-65:DW_MAX-128]  <= #TP pkt_data[DW_MAX-1:DW_MAX-64];
            dllp_start[NW_MAX-3:NW_MAX-4]   <= #TP dllp_start[NW_MAX-1:NW_MAX-2];
            tlp_start[NW_MAX-3:NW_MAX-4]    <= #TP tlp_start[NW_MAX-1:NW_MAX-2];
            pkt_end[NW_MAX-3:NW_MAX-4]      <= #TP pkt_end[NW_MAX-1:NW_MAX-2];
            pkt_edb[NW_MAX-3:NW_MAX-4]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-2];
            pkt_err[NW_MAX-3:NW_MAX-4]      <= #TP pkt_err[NW_MAX-1:NW_MAX-2];
        end

        if (sym_cnt[4:0] == 16) begin
            // Move lower 16 to upper 16
            pkt_data[DW_MAX-129:DW_MAX-256] <= #TP pkt_data[DW_MAX-1:DW_MAX-128];
            dllp_start[NW_MAX-5:NW_MAX-8]   <= #TP dllp_start[NW_MAX-1:NW_MAX-4];
            tlp_start[NW_MAX-5:NW_MAX-8]    <= #TP tlp_start[NW_MAX-1:NW_MAX-4];
            pkt_end[NW_MAX-5:NW_MAX-8]      <= #TP pkt_end[NW_MAX-1:NW_MAX-4];
            pkt_edb[NW_MAX-5:NW_MAX-8]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-4];
            pkt_err[NW_MAX-5:NW_MAX-8]      <= #TP pkt_err[NW_MAX-1:NW_MAX-4];
        end

        if (sym_cnt[5:0] == 32) begin
            // Move lower 32 to upper 32
            pkt_data[DW_MAX-257:DW_MAX-512]  <= #TP pkt_data[DW_MAX-1:DW_MAX-256];
            dllp_start[NW_MAX-9:NW_MAX-16]   <= #TP dllp_start[NW_MAX-1:NW_MAX-8];
            tlp_start[NW_MAX-9:NW_MAX-16]    <= #TP tlp_start[NW_MAX-1:NW_MAX-8];
            pkt_end[NW_MAX-9:NW_MAX-16]      <= #TP pkt_end[NW_MAX-1:NW_MAX-8];
            pkt_edb[NW_MAX-9:NW_MAX-16]      <= #TP pkt_edb[NW_MAX-1:NW_MAX-8];
            pkt_err[NW_MAX-9:NW_MAX-16]      <= #TP pkt_err[NW_MAX-1:NW_MAX-8];
        end
    end

// ==================
//   Drive outputs
// ==================
assign rplh_rdlh_dllp_start = dllp_start[NW_MAX-1:NW_MAX-NW];
assign rplh_rdlh_tlp_start  = tlp_start [NW_MAX-1:NW_MAX-NW];
assign rplh_rdlh_pkt_end    = pkt_end   [NW_MAX-1:NW_MAX-NW];
assign rplh_rdlh_pkt_edb    = pkt_edb   [NW_MAX-1:NW_MAX-NW];
assign rplh_rdlh_pkt_data   = pkt_data  [DW_MAX-1:DW_MAX-DW];
assign rplh_rdlh_pkt_dv     = pkt_dv                        ;
assign rplh_rdlh_pkt_err    = pkt_err   [NW_MAX-1:NW_MAX-NW];
assign rplh_rdlh_nak        = nak       [NW_MAX-1:NW_MAX-NW];


//===================================================================================
//
//==============================================================================
function automatic [(NL*NB)-1:0] compare_bytes;
    input   [(NL*NB)*8-1:0] din;
    input   [(NL*NB)-1:0]   kchar;
    input   [7:0]           byteval;
begin
    for (int j=0; j<(NB*NL); j=j+1) begin
        compare_bytes[j] = (din[8*j+:8] == byteval) & kchar[j];
    end
end
endfunction

endmodule
