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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_10b8bdec.v#12 $
// -------------------------------------------------------------------------
// --- Module Description: Receive PHY 10b8b decoder
// -----------------------------------------------------------------------------
//
module DWC_pcie_gphy_10b8bdec #(
  parameter TP        = 0
) (
   input              clk,
   input              rst_n,
   input              set_disp,
   input              invert_polarity,
   input              elasbuf_underflow,
   input  [9:0]       rxdata_10b,
   input              rxdata_10b_dv,
   input              rxdata_10b_datavalid,
   input  [2:0]       rxdata_rate,
   input              rxdata_10b_startblock,
   input  [1:0]       rxdata_10b_synchdr,
   output reg         rxdata_startblock,
   output reg [1:0]   rxdata_synchdr,

   output reg [7:0]   rxdata,
   output reg         rxdatak,
   output reg         rxdata_dv,
   output reg         rxdata_datavalid,
   output reg         rxcodeerror,
   output reg         rxdisperror,
   output reg         underflow_p
);

//==============================================================================
// Internal regs and wires
//==============================================================================
wire    [7:0]    rxdata_dec;
wire             rxdatak_dec;
wire             code_err_dec;
wire             disp_err_dec;

//==============================================================================
// Support polarity inversion
//==============================================================================
wire    [9:0]  rxdata_10b_wire;
wire    [9:0]  rxdata_10b_wire_inv;
assign rxdata_10b_wire     = invert_polarity ? ~rxdata_10b : rxdata_10b;
assign rxdata_10b_wire_inv = inv_rxdata_10b(rxdata_10b_wire);

//==============================================================================
// Decode the first symbol
//==============================================================================
wire   rst_disp_n;
assign rst_disp_n = ~set_disp & rst_n;

DWC_pcie_gphy_bcm43 #(1,0,1,0) u_decode_a (
    // inputs
    .clk          ( clk             ) ,
    .rst_n        ( rst_n           ) ,
    .init_rd_n    ( 1'b1            ) ,
    .init_rd_val  ( 1'b0            ) ,
    .data_in      ( rxdata_10b_wire_inv[9:0] ) ,
    .enable       ( rxdata_10b_datavalid  & rxdata_10b_dv  ) , // at gen1/2 the data that has rx_datavalid = 0 should not be decoded
                                                 // this is an extra symbol added by the elastibuffer in nominal empty mode
                                                 // if decoded will give disparity error

    // outputs
    .k_char       ( rxdatak_dec     ) ,
    .data_out     ( rxdata_dec      ) ,
    .rd_err_bus   ( disp_err_dec    ) ,
    .code_err_bus ( code_err_dec    ) ,
    .error        (                 ) ,
    .rd           (                 ) ,
    .rd_err       (                 ) ,
    .code_err     (                 ) ,
    .ib_rd_bus    (                 )
);

//==============================================================================
// Drive the outputs
//==============================================================================

//==============================================================================
// For Gen3 pass through data if running at gen3 rate
//==============================================================================
wire    [7:0]    mux_rxdata;
wire             mux_rxdatak;
wire             rxcodeerror_wire;
wire             rxdisperror_wire;
reg              rxdata_10b_valid_r;
reg              rxdata_10b_datavalid_r;
reg              rxdata_10b_valid_rr;
reg              rxdata_10b_datavalid_rr;
reg     [7:0]    rxdata_10b_r;
reg              rxdata_10b_startblock_r;
reg     [1:0]    rxdata_10b_synchdr_r; 
reg              elasbuf_underflow_r;

assign mux_rxdata       = (rxdata_rate > 1) ? rxdata_10b_r[7:0] : rxdata_dec;
assign mux_rxdatak      = rxdatak_dec;
assign rxcodeerror_wire = (rxdata_rate > 1) ? 0                    : code_err_dec & rxdata_10b_valid_r;
assign rxdisperror_wire = (rxdata_rate > 1) ? 0                    : disp_err_dec & rxdata_10b_valid_r & rxdata_10b_datavalid_rr & rxdata_10b_valid_rr;

//==============================================================================
// Mux in EDB symbol on the appropriate byte lane.  This is done here for the
// specific 1s case.
//
// Also includes injection of EDB on lower order byte when have elastic buffer
// underflow.
//==============================================================================
wire [7:0] rxdata_p;
wire       rxdatak_p;

assign rxdata_p  = (rxcodeerror_wire | elasbuf_underflow_r) ? `GPHY_EDB_8B : mux_rxdata[7:0];
assign rxdatak_p = (rxcodeerror_wire | elasbuf_underflow_r) ?         1'b1 : mux_rxdatak;

//==============================================================================
// Delay signals to line up with datapath
always @(posedge clk or negedge rst_n)
    if (!rst_n ) begin
        rxdata_10b_valid_r            <= #TP '0;
        rxdata_10b_datavalid_r        <= #TP '0;
        rxdata_10b_valid_rr           <= #TP '0;
        rxdata_10b_datavalid_rr       <= #TP '0;
        rxdata_10b_r                  <= #TP '0;
        rxdata_10b_startblock_r       <= #TP '0;
        rxdata_10b_synchdr_r          <= #TP '0;
    end else begin
        rxdata_10b_r                  <= #TP rxdata_10b_wire[7:0];
        rxdata_10b_valid_r            <= #TP rxdata_10b_dv;
        rxdata_10b_datavalid_r        <= #TP rxdata_10b_datavalid;
        rxdata_10b_startblock_r       <= #TP rxdata_10b_startblock;
        rxdata_10b_synchdr_r          <= #TP rxdata_10b_synchdr;
        rxdata_10b_valid_rr           <= #TP rxdata_10b_valid_r;
        rxdata_10b_datavalid_rr       <= #TP rxdata_10b_datavalid_r;
    end

always @(posedge clk or negedge rst_n)
    if (!rst_n ) begin
        rxdata             <= #TP 0;
        rxdatak            <= #TP 0;
        rxdata_dv          <= #TP 0;
        rxcodeerror        <= #TP 0;
        rxdisperror        <= #TP 0;
        underflow_p        <= #TP 0;
        rxdata_datavalid   <= #TP 0;
        elasbuf_underflow_r  <= #TP 0;
    end else begin
        rxdata             <= #TP rxdata_p;
        rxdatak            <= #TP (rxdata_rate > 1) ? $urandom_range(0,1) : rxdatak_p;
        rxdata_datavalid   <= #TP rxdata_10b_datavalid_r;
        rxdata_dv          <= #TP rxdata_10b_valid_r;
        rxcodeerror        <= #TP rxcodeerror_wire;
        rxdisperror        <= #TP rxdisperror_wire;
        elasbuf_underflow_r <= #TP elasbuf_underflow;
        underflow_p        <= #TP elasbuf_underflow_r;
    end

always @(posedge clk or negedge rst_n)
    if (!rst_n ) begin
        rxdata_startblock  <= #TP 0;
        rxdata_synchdr     <= #TP 0;
    end else begin
        rxdata_startblock  <= #TP  rxdata_10b_startblock_r;
        rxdata_synchdr     <= #TP  rxdata_10b_synchdr_r;
    end


function [9:0] inv_rxdata_10b;
input    [9:0] rxdata_10b;
integer        bit_loc;
begin
  for (bit_loc=0;bit_loc<10;bit_loc=bit_loc+1) begin
    inv_rxdata_10b[10-1-bit_loc] = rxdata_10b[bit_loc];
  end
end
endfunction

endmodule
