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
// ---    $DateTime: 2020/10/14 06:27:23 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Packet Layer handler
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module rplh
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
input   [1:0]           rmlh_rplh_rcvd_idle_gen12,
input                   rxdata_dv,                  // data is valid this cycle
input   [(NL*NB*8)-1:0] rxdata,                     // Incoming data
input   [(NL*NB)-1:0]   rxdatak,                    // Incoming k indication
input   [(NL*NB)-1:0]   rxerror,                    // Errors reported by PHY
// ---- outputs ---------------
output  [NW-1:0]        rplh_rdlh_dllp_start,       // indication of the dword location of SDP or STP
output  [NW-1:0]        rplh_rdlh_tlp_start,        //
output  [NW-1:0]        rplh_rdlh_pkt_end,          // indication of the dword location of END or EBD
output  [NW-1:0]        rplh_rdlh_pkt_edb,          //
output  [DW-1:0]        rplh_rdlh_pkt_data,         // received data
output                  rplh_rdlh_pkt_dv,           // received data is valid this cycle
output  [NW-1:0]        rplh_rdlh_pkt_err,          // error indication
output  [NW-1:0]        rplh_rdlh_nak,              // NAK indication
output  [1:0]           rplh_rcvd_idle              // RMLH block keeps track of the number of idle received continously.
                                                    // Bit 0 indicates 8 continous idle symbol received, bit 1 indicates 1 idle receivd
);

// ============================================================
// Local Parameters
// ============================================================

// ============================================================
// internal Signals
// ============================================================
wire [4:0] link_mode;
assign link_mode = (NL==16) ?           smlh_link_mode[4:0]  :
                   (NL==8)  ? {1'b0   , smlh_link_mode[3:0]} :
                   (NL==4)  ? {2'b00  , smlh_link_mode[2:0]} :
                   (NL==2)  ? {3'b000 , smlh_link_mode[1:0]} :
                              {4'b0000, smlh_link_mode[0]  };


wire    [AW-1:0]        active_sym_gen34;
wire    [AW-1:0]        int_active_nb;
assign int_active_nb = NB;

assign active_sym_gen34 = 
                          (int_active_nb==8 ) ? `CX_8S  :
                          (int_active_nb==4 ) ? `CX_4S  :
                          (int_active_nb==2 ) ? `CX_2S  : `CX_1S;

wire    [4:0]           active_nw_gen34;
assign active_nw_gen34  = link_mode[4] ? active_sym_gen34[2] ? 5'h10: active_sym_gen34[1] ? 5'h8 : 5'h4 :                              // 4sx16,2sx16, 1sx16
                          link_mode[3] ? active_sym_gen34[3] ? 5'h10: active_sym_gen34[2] ? 5'h8 : active_sym_gen34[1] ? 5'h4 : 5'h2 : // 8sx8, 4sx8, 2sx8, 1sx8
                          link_mode[2] ? active_sym_gen34[3] ? 5'h8 : active_sym_gen34[2] ? 5'h4 : active_sym_gen34[1] ? 5'h2 : 5'h1 : // 8sx4, 4sx4, 2sx4, 1sx4
                          link_mode[1] ? active_sym_gen34[3] ? 5'h4 : active_sym_gen34[2] ? 5'h2 : 5'h1 :    // 8sx2, 4sx2, 2sx2, 1sx2
                          link_mode[0] ? active_sym_gen34[3] ? 5'h2 : 5'h1 : 5'h1 ;                          // 8sx1, 4sx1, 2sx1, 1sx1

// ============================================================
// Demux
// ============================================================

// ============================================================
// Active Decoder
// ============================================================

enum logic [1:0] {
    Gen12_pkt_finder,    // Gen1 & Gen2 decoder
    Gen34_token_finder3, // Gen3 & Gen4 decoder for small data widths
    Gen34_token_finder4  // Gen3 & Gen4 decoder for wide data widths
} active_decoder;

always_comb begin : active_decoder_PROC
        active_decoder = Gen12_pkt_finder;
end

// ============================================================
// Gen1 / Gen2 Section
// ============================================================
wire rxdata_dv_gen12;
assign rxdata_dv_gen12 = (active_decoder == Gen12_pkt_finder) ? rxdata_dv : 1'b0;

wire [NW-1:0] dllp_start;
wire [NW-1:0] tlp_start;
wire [NW-1:0] pkt_end;
wire [NW-1:0] pkt_edb;
wire [DW-1:0] pkt_data;
wire          pkt_dv;
wire [NW-1:0] pkt_err;
wire [NW-1:0] nak;

rplh_token_finder1
 u_rplh_token_finder1
(
// ---- inputs ---------------
    .core_clk                 (core_clk),
    .core_rst_n               (core_rst_n),
    .smlh_link_mode           (smlh_link_mode),
    .active_nb                (active_nb),
    .rxdata_dv                (rxdata_dv_gen12),
    .rxdata                   (rxdata),
    .rxdatak                  (rxdatak),
    .rxerror                  (rxerror),
// ---- outputs ---------------
    .rplh_rdlh_dllp_start     (dllp_start),
    .rplh_rdlh_tlp_start      (tlp_start),
    .rplh_rdlh_pkt_end        (pkt_end),
    .rplh_rdlh_pkt_edb        (pkt_edb),
    .rplh_rdlh_pkt_data       (pkt_data),
    .rplh_rdlh_pkt_dv         (pkt_dv),
    .rplh_rdlh_pkt_err        (pkt_err),
    .rplh_rdlh_nak            (nak)
);

// ============================================================
// Gen3 Section
// ============================================================

// ==================
//   Drive outputs
// ==================
assign  rplh_rdlh_dllp_start = dllp_start;
assign  rplh_rdlh_tlp_start  = tlp_start ;
assign  rplh_rdlh_pkt_end    = pkt_end   ;
assign  rplh_rdlh_nak        = nak       ;
assign  rplh_rdlh_pkt_edb    = pkt_edb   ;
assign  rplh_rdlh_pkt_data   = pkt_data  ;
assign  rplh_rdlh_pkt_dv     = pkt_dv    ;
assign  rplh_rdlh_pkt_err    = pkt_err   ;
assign  rplh_rcvd_idle       = rmlh_rplh_rcvd_idle_gen12;


endmodule
