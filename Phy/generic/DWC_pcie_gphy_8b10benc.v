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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_8b10benc.v#6 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit PHY 8b10b encoder
// -----------------------------------------------------------------------------

module DWC_pcie_gphy_8b10benc #(
  parameter TP        = 0
) (
   input              rst_n,
   input              clk,
   input              set_disp,
   input              test_err_disp,
   input       [7:0]  txdata,
   input              txdatak,
   input              txdatavalid,
   input       [2:0]  rate,
   input              txstartblock,
   input       [1:0]  txsynchdr,
   input              txelecidle,
   output reg         txstartblock_10b,
   output reg  [1:0]  txsynchdr_10b,
   output reg         txdatavalid_10b,
   output      [9:0]  txdata_10b,
   output reg         txelecidle_10b
);

// Signals defined within this module
reg                     dispin;
wire                    dispout;

// Combinational logic. 
wire    [9:0]           txdata_10b_wire;
wire    [9:0]           txdata_10b_dec;
wire    [9:0]           txdata_10b_dec_inv;
wire                    rst_disp_n;
wire                    rst_disp_val;

assign rst_disp_n    = ~(set_disp | test_err_disp); 
assign rst_disp_val  = test_err_disp ? ~dispout : 1'b0;

DWC_pcie_gphy_bcm44 #(1,0,1,1) u_encode (
    // inputs
    .clk          ( clk             ) ,
    .rst_n        ( rst_n           ) ,
    .init_rd_n    ( rst_disp_n      ) ,
    .init_rd_val  ( rst_disp_val    ) ,
    .k_char       ( txdatak         ) ,
    .data_in      ( txdata[7:0]     ),
    .enable       ( 1'b1            ) ,

    // outputs
    .data_out     ( txdata_10b_dec  ),
    .rd           ( dispout         )
);

assign txdata_10b_dec_inv  = inv_txdata_10b(txdata_10b_dec);

always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        dispin           <= #TP 1'b1;
    end else begin
        // add an insertion mechanism for generating the disparity error
        dispin           <= #TP test_err_disp ? !dispout : dispout;
    end
    
always @(posedge clk or negedge rst_n)
    if (!rst_n)      txdatavalid_10b  <= #TP 0;
    else             txdatavalid_10b  <= #TP txdatavalid ;
        
    
reg     [7:0]    txdata_reg;
always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        txdata_reg       <= #TP 0;
        txstartblock_10b <= #TP 0;
        txsynchdr_10b    <= #TP 0;
        txelecidle_10b   <= #TP 1;
    end else begin
        txdata_reg       <= #TP txdata      ;
        txstartblock_10b <= #TP txstartblock;
        txsynchdr_10b    <= #TP txsynchdr   ;
        txelecidle_10b   <= #TP txelecidle ;
    end
    

assign txdata_10b         = (rate > 1) ? {2'h0,txdata_reg[7:0]}: txdata_10b_dec_inv;

function [9:0] inv_txdata_10b;
input    [9:0] txdata_10b;
integer        bit_loc;
begin
  for (bit_loc=0;bit_loc<10;bit_loc=bit_loc+1) begin
    inv_txdata_10b[10-1-bit_loc] = txdata_10b[bit_loc];
  end
end
endfunction

endmodule

