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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_byte_order.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description: Re-order data per symbol and per lane.
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
module rmlh_byte_order
#(
parameter   INST    = 0,                         // The uniquifying parameter for each port logic instance.
parameter   REGIN   = `CX_RMLH_PKT_FINDER_REGIN,
parameter   NL      = `CX_NL,                    // Max number of lanes supported
parameter   NB      = `CX_NB,                    // Number of symbols (bytes) per clock cycle
parameter   AW      = `CX_ANB_WD,                // Width of the active number of bytes
parameter   TP      = `TP                        // Clock to Q delay (simulator insurance)
)
(
// ---- inputs ---------------
input                   core_clk,
input                   core_rst_n,
input   [5:0]           smlh_link_mode,
input   [NL-1:0]        deskew_lanes_active,           // Which lanes are actively (begin) configured
input   [3:0]           active_nb,
input                   rxdata_flush_gen12_in,         // Request from deskew to flush the internal buffer. Active high. Gen1/Gen2 only
input                   rxdata_dv_in,                  // data is valid this cycle
input   [(NL*NB*8)-1:0] rxdata_in,                     // Incoming data
input   [(NL*NB)-1:0]   rxdatak_in,                    // Incoming k indication
input   [(NL*NB)-1:0]   rxerror_in,                    // Errors reported by PHY
// ---- outputs ---------------
output  [(NL*NB*8)-1:0] rmlh_rplh_rxdata,              // Incoming data
output  [(NL*NB)-1:0]   rmlh_rplh_rxdatak,             // Incoming k indication
output  [(NL*NB)-1:0]   rmlh_rplh_rxerror,             // Errors reported by PHY
output                  rmlh_rplh_dv,                  // data is valid this cycle
output  [5:0]           rmlh_rplh_link_mode,
output  [3:0]           rmlh_rplh_active_nb,
output  [1:0]           rmlh_rplh_rcvd_idle_gen12      // Keep track of the number of idle received continously in Gen1/Gen2.
                                                       // Bit 0 indicates 8 continous idle symbol received, bit 1 indicates 1 idle receivd
);

// ============================================================
// Local Parameters
// ============================================================
localparam   GEN1_NB = `CX_MAC_SMODE_GEN1;
localparam   GEN2_NB = `CX_MAC_SMODE_GEN2;


// ============================================================
// (Optional) Registered inputs
// ============================================================
wire    [5:0]                  smlh_link_mode_int;
wire    [3:0]                  active_nb_int;

wire                    rxdata_dv_int;
wire    [(NL*NB*8)-1:0] rxdata_int;
wire    [(NL*NB)-1:0]   rxdatak_int;
wire    [(NL*NB)-1:0]   rxerror_int;
wire                    rxdata_flush_gen12_int;

parameter N_DELAY_CYLES     = REGIN ? 1 : 0;
parameter DATAPATH_WIDTH    = 10 * NB * NL;
delay_n

#(N_DELAY_CYLES, 2) u_delay_ctrl (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({rxdata_dv_in,  rxdata_flush_gen12_in}),
    .dout  ({rxdata_dv_int, rxdata_flush_gen12_int})
);

delay_n_w_enable

#(N_DELAY_CYLES, DATAPATH_WIDTH) u_delay_w_enable_data (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .en    (rxdata_dv_in),
    .din   ({rxdata_in,  rxdatak_in,  rxerror_in}),
    .dout  ({rxdata_int, rxdatak_int, rxerror_int})
);

parameter SIGNALS_WIDTH = 6 + // smlh_link_mode
                          4; // active_nb

delay_n

#(N_DELAY_CYLES, SIGNALS_WIDTH) u_delay_signals (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({ smlh_link_mode, 
              active_nb}),
    .dout  ({ smlh_link_mode_int,
              active_nb_int})
);



// ============================================================
// Gen1/Gen2 Flush internal buffers.
// ============================================================
// Deskew module can request to flush the internal buffer in several scenarios.
// The intent is to forward to Layer 2 whatever was already received and is 
// stored in the internal buffer just waiting for fill the datapath.
// The flush is done by emulating a special k-symbol "00". 
// If there is not packet in progress the special k-symbol will be ignored.
// Instead, if a packet is in progress it will be terminated and flagged
// with pkt_err. Idle counters will be reset as well during the flush.

wire gen12_rate;
assign gen12_rate = 1'b1;

wire data_flush;
wire                    rxdata_dv;
wire    [(NL*NB*8)-1:0] rxdata;
wire    [(NL*NB)-1:0]   rxdatak;
wire    [(NL*NB)-1:0]   rxerror;

assign data_flush = gen12_rate & rxdata_flush_gen12_int & ~rxdata_dv_int;
assign rxdata_dv = (data_flush)?          1'b1   : rxdata_dv_int;
assign rxdata    = (data_flush)? {NL*NB*8{1'b0}} : rxdata_int;
assign rxdatak   = (data_flush)? {NL*NB  {1'b1}} : rxdatak_int;
assign rxerror   = (data_flush)? {NL*NB  {1'b0}} : rxerror_int;


// ============================================================
// Re-order data received
// ============================================================

wire    [4:0]           link_mode;
assign link_mode       = (NL==16) ?           smlh_link_mode_int[4:0]  :
                         (NL==8)  ? {1'b0   , smlh_link_mode_int[3:0]} :
                         (NL==4)  ? {2'b00  , smlh_link_mode_int[2:0]} :
                         (NL==2)  ? {3'b000 , smlh_link_mode_int[1:0]} :
                                    {4'b0000, smlh_link_mode_int[0]  };

// Re-order input per symbol
wire    [(NL*NB*8)-1:0] rx_data_tmp;
wire    [(NL*NB)-1:0]   rx_datak_tmp;
wire    [(NL*NB)-1:0]   rx_error_tmp;

assign rx_data_tmp = sym_order_byte(rxdata);
assign rx_datak_tmp = sym_order_bit(rxdatak);
assign rx_error_tmp = sym_order_bit(rxerror);

function automatic [(NL*NB)-1:0] sym_order_bit;
    input [(NL*NB)-1:0] data_in;
begin
    for (int sym=0; sym<NB; sym=sym+1) begin
        for (int lane=0; lane<NL; lane=lane+1) begin
            sym_order_bit[sym*NL+lane] = data_in[lane*NB+sym];
        end
    end
end
endfunction

function automatic [(NL*NB*8)-1:0] sym_order_byte;
    input [(NL*NB*8)-1:0] data_in;
begin
    for (int sym=0; sym<NB; sym=sym+1) begin
        for (int lane=0; lane<NL; lane=lane+1) begin
            sym_order_byte[(sym*NL+lane)*8+:8] = data_in[(lane*NB+sym)*8+:8];
        end
    end
end
endfunction

// Re-order input per lane
reg [(NL*NB*8)-1:0] rx_data;
reg [(NL*NB)-1:0]   rx_datak;
reg [(NL*NB)-1:0]   rx_error;

assign rx_data  = lane_order_byte(rx_data_tmp, link_mode);
assign rx_datak = lane_order_bit(rx_datak_tmp, link_mode);
assign rx_error = lane_order_bit(rx_error_tmp, link_mode);

parameter LINK_LOOP = (NL==16) ? 4 :
                      (NL==8)  ? 3 :
                      (NL==4)  ? 2 :
                      (NL==2)  ? 1 : 0;

function automatic [(NL*NB)-1:0] lane_order_bit;
    input [(NL*NB)-1:0] data_in;
    input [4:0]         link_mode;
    integer byte_loc, link_loc;
begin
    lane_order_bit = {(NL*NB){1'b0}};
    for (link_loc=LINK_LOOP; link_loc>=0; link_loc=link_loc-1) begin
        if (link_mode[link_loc]==1'b1) begin
            for (byte_loc=0; byte_loc<(NB<<LINK_LOOP); byte_loc=byte_loc+1) begin
                if (byte_loc<(NB<<link_loc)) begin
                    lane_order_bit[byte_loc] = data_in[(byte_loc/(1<<link_loc))*NL+(byte_loc%(1<<link_loc))];
                end
            end
        end
    end
end
endfunction

function automatic [(NL*NB*8)-1:0] lane_order_byte;
    input [(NL*NB*8)-1:0] data_in;
    input [4:0]           link_mode;
begin
    lane_order_byte = {(NL*NB*8-1){1'b0}};
    for (int link_loc=LINK_LOOP; link_loc>=0; link_loc=link_loc-1) begin
        if (link_mode[link_loc]==1'b1) begin
            for (int byte_loc=0; byte_loc<(NB<<LINK_LOOP); byte_loc=byte_loc+1) begin
                if (byte_loc<(NB<<link_loc)) begin
                    lane_order_byte[byte_loc*8+:8] = data_in[((byte_loc/(1<<link_loc))*NL+(byte_loc%(1<<link_loc)))*8+:8];
                end
            end
        end
    end
end
endfunction


//===================================================================================
// Gen1/Gen2 Logic idle detection circuitry to assist LTSSM transition
//===================================================================================
localparam TMP_NB = (`CX_NB==16) ? 8 : NB;
wire    [(NL*NB)-1:0]   idles;
assign idles = compare_bytes(rx_data_tmp, ~rx_datak_tmp, 8'b0);
reg     [7:0]     skips_lane0;

always @(*) begin : skips_lane0_PROC
    skips_lane0 = 8'h0;
    for (int i=0; i<TMP_NB; i=i+1) begin
        skips_lane0[i]    = ( rxdata[i*8+:8] == `SKIP_8B || rxdata[i*8+:8] == `COMMA_8B ) & rxdatak[i];
    end
end

reg [8:0] all_lane_rcvd_idle;
always @(*) begin : all_lane_rcvd_idle_PROC
    all_lane_rcvd_idle = 8'h0;
    for (int i=0; i<TMP_NB; i=i+1) begin
        all_lane_rcvd_idle[i] = &((~deskew_lanes_active) | (idles[i*NL+:NL] & (~rx_error_tmp[NL-1:0])));
    end
end

wire [3:0] active_sym_gen12;
// Suppress the most significant bits for lower speeds
     // for Dynamic Frequency config
assign active_sym_gen12      = NB; // Dynamic frequency

wire  [3:0]          rx_sym_valid;
assign  rx_sym_valid = (active_sym_gen12 == 4'b0001) ? 4'b0001 :
                       (active_sym_gen12 == 4'b0010) ? 4'b0011 :
                       (active_sym_gen12 == 4'b0100) ? 4'b1111 : 4'b0000;

wire [3:0] rcvd_idle_cnt_a;
wire [3:0] rcvd_idle_cnt_b;
wire [3:0] rcvd_idle_cnt_c;
wire [3:0] rcvd_idle_cnt_d;
reg  [3:0] rcvd_idle_cnt;
assign rcvd_idle_cnt_a = (rxdata_dv & rx_sym_valid[0]) ? (all_lane_rcvd_idle[0] ? rcvd_idle_cnt + 1 :
                                                          skips_lane0[0]        ? rcvd_idle_cnt : 0) :
                                                                                  rcvd_idle_cnt;
assign rcvd_idle_cnt_b = (rxdata_dv & rx_sym_valid[1]) ? (all_lane_rcvd_idle[1] ? rcvd_idle_cnt_a + 1 :
                                                          skips_lane0[1]        ? rcvd_idle_cnt_a : 0) :
                                                                                  rcvd_idle_cnt_a;
assign rcvd_idle_cnt_c = (rxdata_dv & rx_sym_valid[2]) ? (all_lane_rcvd_idle[2] ? rcvd_idle_cnt_b + 1 :
                                                          skips_lane0[2]        ? rcvd_idle_cnt_b : 0) :
                                                                                  rcvd_idle_cnt_b;
assign rcvd_idle_cnt_d = (rxdata_dv & rx_sym_valid[3]) ? (all_lane_rcvd_idle[3] ? rcvd_idle_cnt_c + 1 :
                                                          skips_lane0[3]        ? rcvd_idle_cnt_c : 0) :
                                                                                  rcvd_idle_cnt_c;

reg [1:0] rcvd_idle12;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rcvd_idle_cnt     <= #TP 0;
        rcvd_idle12       <= #TP 0;
    end else begin
        rcvd_idle_cnt     <= #TP (NB>=4) ? rcvd_idle_cnt_d[3] ? 4'b1000 : rcvd_idle_cnt_d :
                                 (NB==2) ? rcvd_idle_cnt_b[3] ? 4'b1000 : rcvd_idle_cnt_b :
                                           rcvd_idle_cnt_a[3] ? 4'b1000 : rcvd_idle_cnt_a;
        rcvd_idle12[0]    <= #TP (NB>=4) ? rcvd_idle_cnt_a[3] | rcvd_idle_cnt_b[3] | rcvd_idle_cnt_c[3] | rcvd_idle_cnt_d[3] :
                                 (NB==2) ? rcvd_idle_cnt_a[3] | rcvd_idle_cnt_b[3] :
                                           rcvd_idle_cnt_a[3];
        rcvd_idle12[1]    <= #TP (NB>=4) ? |{rcvd_idle_cnt_a, rcvd_idle_cnt_b, rcvd_idle_cnt_c, rcvd_idle_cnt_d} :
                                 (NB==2) ? |{rcvd_idle_cnt_a, rcvd_idle_cnt_b} :
                                           |{rcvd_idle_cnt_a};
    end


// ==================
//   Drive outputs
// ==================
assign rmlh_rplh_rxdata  = rx_data;
assign rmlh_rplh_rxdatak = rx_datak;
assign rmlh_rplh_rxerror = rx_error;
assign rmlh_rplh_dv      = rxdata_dv;

assign rmlh_rplh_link_mode         = smlh_link_mode_int;
assign rmlh_rplh_active_nb         = active_nb_int;

assign rmlh_rplh_rcvd_idle_gen12   = rcvd_idle12;

//==============================================================================
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
