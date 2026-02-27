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
// ---    $DateTime: 2018/10/12 09:47:22 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_lpbk.v#8 $
// -------------------------------------------------------------------------
// --- Module Description:  Loopback module for supporting loopback slave operation
// -----------------------------------------------------------------------------


module DWC_pcie_gphy_lpbk #(
  parameter TP      = 0                             // Clock to Q delay (simulator insurance)
) (
   input         clk,
   input         rst_n,
   // Loopback enable control   
   input         loopback,           
   // incoming data before decoding
   input  [9:0]  rxdata_10b, 
   input         rxdatavalid_10b,
   input         rxvalid,
   input  [2:0]  rate,                    
   input         rxstartblock_10b,
   input  [1:0]  rxsynchdr_10b,      
     
   // transmit data path - before the encoding
   input  [9:0]  txdata_10b,   
   input         txdatavalid_10b,                   
   input         txstartblock_10b,
   input  [1:0]  txsynchdr_10b,  

   // muxed path             
   output        ser_txstartblock_10b,
   output [1:0]  ser_txsynchdr_10b,
   output        ser_txdatavalid_10b,   
   output [9:0]  ser_txdata_10b
);

//reg int_loopback;
reg [9:0] rxdata_10b_r;
reg       rxdatavalid_10b_r;
//wire      negedge_rxdatavalid_10b; 
reg       rxstartblock_10b_r;
reg [1:0] rxsynchdr_10b_r;


always @(posedge clk or negedge rst_n)
begin
   if (!rst_n) begin
     rxdata_10b_r        <= #TP 10'b0;
     rxdatavalid_10b_r   <= #TP 1'b0;
     rxstartblock_10b_r  <= #TP 1'b0;
     rxsynchdr_10b_r     <= #TP 2'b0;  
   end else begin
      rxdata_10b_r        <= #TP rxdata_10b;
      rxdatavalid_10b_r   <= #TP rxdatavalid_10b;
      rxstartblock_10b_r  <= #TP rxstartblock_10b;
      rxsynchdr_10b_r     <= #TP rxsynchdr_10b;
   end   
end

//assign negedge_rxdatavalid_10b = !rxdatavalid_10b && rxdatavalid_10b_r;

// always @(posedge clk or negedge rst_n)
// begin  
//    if (!rst_n)   int_loopback <= #TP 0;
//    else begin
//       if (rate > 1) begin
//          if (negedge_rxdatavalid_10b && rxvalid)
//             int_loopback <= #TP loopback;
//       end else begin
//          int_loopback    <= #TP loopback;
//       end  
//    end   
// end

assign ser_txdata_10b        = loopback ? rxdata_10b_r  : txdata_10b;
assign ser_txdatavalid_10b   = loopback ? rxdatavalid_10b_r  : txdatavalid_10b ;
assign ser_txstartblock_10b  = loopback ? rxstartblock_10b_r : txstartblock_10b;
assign ser_txsynchdr_10b     = loopback ? rxsynchdr_10b_r    : txsynchdr_10b   ;

endmodule


