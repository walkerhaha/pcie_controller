
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

//
// Filename    : DWC_pcie_ctl_bcm64_td.v
// Revision    : $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_ctl_bcm64_td.sv#1 $
// Author      : ALS/RJK/LMS 12/03/14
// Description : DWC_pcie_ctl_bcm64_td.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 2543425f
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm64_td(
    clk,
    rst_n,
    init_n,
    push_req_n,
    pop_req_n,
    diag_n,
    ae_level,
    af_thresh,
    data_in,
    empty,
    almost_empty,
    half_full,
    almost_full,
    full,
    error,
    data_out
);

  parameter WIDTH           = 8;    // RANGE 1 TO 256
  parameter DEPTH           = 4;    // RANGE 2 TO 256
  parameter ERR_MODE        = 0;    // RANGE 0 TO 2
  parameter RST_MODE        = 0;    // RANGE 0 TO 1
  parameter ADDR_WIDTH      = 2;    // RANGE 1 TO 8
  parameter REG_DELAY_TIME  = 1;    // RANGE >= 0
  parameter REG_DELAY_DENOM = 1;    // RANGE >  0

  input                     clk;            // clock input
  input                     rst_n;          // active low async. reset
  input                     init_n;         // active low sync. reset (FIFO flush)
  input                     push_req_n;     // active low push request
  input                     pop_req_n;      // active low pop request
  input                     diag_n;         // active low diagnostic input
  input  [ADDR_WIDTH-1:0]   ae_level;       // Almost Empty Flag level
  input  [ADDR_WIDTH-1:0]   af_thresh;      // Almost Full Flag threshold
  input  [WIDTH-1 : 0]      data_in;        // FIFO input data bus
  output                    empty;          // empty status flag
  output                    almost_empty;   // almost empty status flag
  output                    half_full;      // half full status flag
  output                    almost_full;    // almost full status flag
  output                    full;           // full status flag
  output                    error;          // error status flag
  output [WIDTH-1 : 0]      data_out;       // FIFO outptu data bus

  wire                      ram_async_rst_n;
  wire   [ADDR_WIDTH-1 : 0] ram_rd_addr, ram_wr_addr;
  wire                      ram_we_n;
    

generate
  if (RST_MODE == 0) begin : GEN_MEM_RST_RM0
    assign ram_async_rst_n = rst_n;
  end else begin : GEN_MEM_RST_RM_NE_0
    assign ram_async_rst_n = 1'b1;
  end
endgenerate
  

  DWC_pcie_ctl_bcm86
   #(DEPTH, ERR_MODE, ADDR_WIDTH, REG_DELAY_TIME, REG_DELAY_DENOM) U_FIFO_CTL(
    .clk(clk),
    .rst_n(rst_n),
    .init_n(init_n),
    .push_req_n(push_req_n),
    .pop_req_n(pop_req_n),
    .diag_n(diag_n),
    .ae_level(ae_level),
    .af_thresh(af_thresh),
    .we_n(ram_we_n),
    .empty(empty),
    .almost_empty(almost_empty),
    .half_full(half_full),
    .almost_full(almost_full),
    .full(full),
    .error(error),
    .wr_addr(ram_wr_addr),
    .rd_addr(ram_rd_addr),
// spyglass disable_block W287b
// SMD: An output port of module or gate instance is not connected
// SJ: The following port(s) of this instance are intentionally unconnected.
    .wrd_count(),
    .nxt_empty_n(),
    .nxt_full(),
    .nxt_error()
// spyglass enable_block W287b
  );
    
  DWC_pcie_ctl_bcm57
   #(WIDTH, DEPTH, 0, ADDR_WIDTH) U_FIFO_MEM( 
    .clk(clk),
    .rst_n(ram_async_rst_n),
    .wr_n(ram_we_n),
    .rd_addr(ram_rd_addr),
    .wr_addr(ram_wr_addr),
    .data_in(data_in),
    .data_out(data_out)
  );

endmodule
