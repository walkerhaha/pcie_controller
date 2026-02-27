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
// ---    $DateTime: 2019/06/06 16:32:01 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/pipe_loopback.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module loops back the PIPE interface
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pipe_loopback
#(
    parameter INST = 0, // uniquifying parameter for each port logic instance
    parameter NL = `CX_NL,
    parameter PHY_NB = `CX_PHY_NB,
    parameter CTRL_WIDTH = NL, // Control mux width varies with gen3 pipe i/f
    parameter PDWN_WIDTH = 1,
    parameter RATE_WIDTH = 1,
    parameter TP = `TP // Clock to Q delay (simulator insurance)
)
(
    input                       clk,
    input                       rst_n,

    // Control Inputs
    input                       cfg_pipe_loopback,
    input  [5:0]                cfg_rxstatus_lane,          // Lane to inject rxstatus value(bit6 = all lanes)
    input  [2:0]                cfg_rxstatus_value,         // rxstatus value to inject
    input  [NL-1:0]             cfg_lpbk_rxvalid,           // rxvalid value to use during loopback
    input                       ext_pipe_loopback,

    // PIPE RX Inputs
    input  [8*PHY_NB*NL-1:0]    rxdata,
    input  [PHY_NB*NL-1:0]      rxdatak,
    input  [NL-1:0]             rxvalid,
    input  [CTRL_WIDTH-1:0]     rxctrl,
    input  [NL*3-1:0]           rxstatus,
    input  [NL-1:0]             phystatus,

    // PIPE TX Inputs
    input  [8*PHY_NB*NL-1:0]    txdata,
    input  [PHY_NB*NL-1:0]      txdatak,
    input  [CTRL_WIDTH-1:0]     txctrl,
    input  [NL-1:0]             txdetectrx_loopback,
    input  [PDWN_WIDTH-1:0]     powerdown,
    input  [RATE_WIDTH-1:0]     rate,

    // PIPE Outputs
    output [8*PHY_NB*NL-1:0]    lpbk_rxdata,
    output [PHY_NB*NL-1:0]      lpbk_rxdatak,
    output [NL-1:0]             lpbk_rxvalid,
    output [CTRL_WIDTH-1:0]     lpbk_ctrl,
    output [NL*3-1:0]           lpbk_rxstatus,
    output [NL-1:0]             lpbk_phystatus
);


// RX Status values
localparam  RX_DETECTED = 3'b011;

// Powerdown Values
localparam  P1 = 4'b0010;
localparam  P2 = 4'b0011;

// Tx Input Pipeline (Defalut: 0)
// txctrl = {elecidle,datavalid `ifdef CX_GEN3_SPEED , startblock, syncheader `endif}
//                          txdata         txdatak  txdet_lpbk  ctrl
parameter DATAPATH_WIDTH = (8*PHY_NB*NL) + (PHY_NB*NL) + NL + CTRL_WIDTH;
parameter RESET_VALUE    = {{ (8*PHY_NB*NL+PHY_NB*NL+NL){1'b0}}, {NL*2{1'b1}}} ; // Reset value of Txelecidle=1 and txdatavalid=1, The others = 0
parameter REGIN = `CX_LOOPBACK_TX_REGIN;

wire   [8*PHY_NB*NL-1:0]    txdata_i;
wire   [PHY_NB*NL-1:0]      txdatak_i;
wire   [CTRL_WIDTH-1:0]     txctrl_i;
wire   [NL-1:0]             txdetectrx_loopback_i;
wire                        tx_regin_en;
assign tx_regin_en = (powerdown != P2);

delay_n_w_enable

#(REGIN , DATAPATH_WIDTH, RESET_VALUE) u_delay_tx_regin(
    .clk        (clk),
    .rst_n      (rst_n),
    .clear      (1'b0),
    .en         (tx_regin_en),
    .din        ({ txdata, txdatak, txdetectrx_loopback, txctrl}),
    .dout       ({ txdata_i, txdatak_i, txdetectrx_loopback_i, txctrl_i})
);

// Loopback can be enabled either from port logic register or external pin
wire    lpbk_active;
assign lpbk_active = cfg_pipe_loopback || ext_pipe_loopback;

// detect when the MAC does RX detection, per lane
wire   [NL-1:0] detectrx;
assign detectrx = {NL{powerdown == P1}} & txdetectrx_loopback_i;

//  detect edges on powerdown, rate or detectrx
reg    [PDWN_WIDTH-1:0]     powerdown_d;
reg    [RATE_WIDTH-1:0]     rate_d;
reg    [NL-1:0]             detectrx_d;
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        powerdown_d <= #TP 0;
        rate_d      <= #TP 0;
        detectrx_d  <= #TP 0;
    end else if(lpbk_active) begin
        powerdown_d <= #TP powerdown;
        rate_d      <= #TP rate;
        detectrx_d  <= #TP detectrx;
    end
wire            powerdown_edge;
wire            rate_edge;
wire   [NL-1:0] detectrx_edge;
assign powerdown_edge = powerdown != powerdown_d;
assign rate_edge = rate != rate_d;
assign detectrx_edge = detectrx & ~detectrx_d;

// Rxdetection is per lane, other assertions of phystatus are common across
// all lanes
reg     [NL*3-1:0]  int_lpbk_rxstatus;
reg     [NL-1:0]    int_lpbk_phystatus;
always @(*) begin : RXSTATUS
    integer i;
    int_lpbk_rxstatus = 0;
    int_lpbk_phystatus = 0;
    for(i = 0; i < NL; i = i + 1) begin
        if(cfg_rxstatus_lane == i || cfg_rxstatus_lane[5] == 1) begin
            int_lpbk_rxstatus[i*3 +: 3] = cfg_rxstatus_value;
        end
        // detectrx takes priority over injected rxstatus
        if(detectrx_edge[i]) begin
            int_lpbk_rxstatus[i*3 +: 3] = RX_DETECTED;
        end
        if(detectrx_edge[i] || powerdown_edge || rate_edge) begin
            int_lpbk_phystatus[i] = 1'b1;
        end
    end
end

// Delay phystatus and rxstatus by two cycles after detecting the condition
reg     [NL-1:0]    r_phystatus;
reg     [NL*3-1:0]  r_rxstatus;
reg     [NL-1:0]    r_phystatus_d;
reg     [NL*3-1:0]  r_rxstatus_d;
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        r_phystatus     <= #TP 0;
        r_rxstatus      <= #TP 0;
        r_phystatus_d   <= #TP 0;
        r_rxstatus_d    <= #TP 0;
    end else if(lpbk_active) begin
        r_phystatus     <= #TP int_lpbk_phystatus;
        r_rxstatus      <= #TP int_lpbk_rxstatus;
        r_phystatus_d   <= #TP r_phystatus;
        r_rxstatus_d    <= #TP r_rxstatus;
    end


// Output MUX
assign lpbk_rxdata          = lpbk_active ? txdata_i : rxdata;
assign lpbk_rxdatak         = lpbk_active ? txdatak_i : rxdatak;
assign lpbk_rxvalid         = lpbk_active ? cfg_lpbk_rxvalid : rxvalid;
assign lpbk_ctrl            = lpbk_active ? txctrl_i : rxctrl;
assign lpbk_rxstatus        = lpbk_active ? r_rxstatus_d : rxstatus;
assign lpbk_phystatus       = lpbk_active ? r_phystatus_d : phystatus;

endmodule
