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
// ---    $DateTime: 
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_viewport_bfm.v#2 $
// -------------------------------------------------------------------------
// --- Description: PHY CR viewport interface model
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_viewport_bfm
#(
   parameter TP       = 0,
   parameter VPT_NUM  = 1,
   parameter VPT_DATA = 16
) (
  input                                 clk,
  input                                 rst_n,
  input       [15:0]                    phy_cr_para_addr,
  input       [VPT_NUM-1:0]             phy_cr_para_rd_en,
  input       [VPT_NUM-1:0]             phy_cr_para_wr_en,
  input       [VPT_DATA-1:0]            phy_cr_para_wr_data,
  input       [VPT_NUM*2-1:0]           phy_cr_respond_time,           // 0 - quick ; 1- normal; 2- slow; 3 - timeout
  input                                 phy_cr_rd_data_load_en,        // 1 - load specific value to be returned ; 0 - random
  input       [15:0]                    phy_cr_rd_data_return_value,   // value to be returned

  output      [VPT_NUM-1:0]             phy_cr_para_ack,
  output      [VPT_NUM*VPT_DATA-1:0]    phy_cr_para_rd_data
);


genvar macro;

generate
for (macro=0; macro<VPT_NUM; macro = macro+1) begin : gen_cr_if_slv
phy_viewport_slv #(
   .TP       (TP),
   .VPT_NUM  (VPT_NUM),
   .VPT_DATA (VPT_DATA)
) u_phy_viewport_slv (
   .clk                                (clk),
   .rst_n                              (rst_n),
   .phy_cr_para_addr                   (phy_cr_para_addr),
   .phy_cr_para_rd_en                  (phy_cr_para_rd_en[macro]),
   .phy_cr_para_wr_en                  (phy_cr_para_wr_en[macro]),
   .phy_cr_para_wr_data                (phy_cr_para_wr_data),
   .phy_cr_para_ack                    (phy_cr_para_ack[macro]),
   .phy_cr_respond_time                (phy_cr_respond_time[macro*2+:2]),         
   .phy_cr_rd_data_load_en             (phy_cr_rd_data_load_en),
   .phy_cr_rd_data_return_value        (phy_cr_rd_data_return_value),
   .phy_cr_para_rd_data                (phy_cr_para_rd_data[macro*VPT_DATA+:VPT_DATA]) 
); // phy_viewport_slv
end // for
endgenerate 

endmodule: DWC_pcie_gphy_viewport_bfm


// single phy version of cr_if_bfm
module phy_viewport_slv #( 
   parameter TP       = 0,
   parameter VPT_NUM  = 1,
   parameter VPT_DATA = 1
) (
  input                                 clk,
  input                                 rst_n,
  input       [15:0]                    phy_cr_para_addr,
  input                                 phy_cr_para_rd_en,
  input                                 phy_cr_para_wr_en,
  input       [VPT_DATA-1:0]            phy_cr_para_wr_data,
  input       [1:0]                     phy_cr_respond_time,           // 0 - quick ; 1- normal; 2- slow; 3 - timeout
  input                                 phy_cr_rd_data_load_en,        // 1 - load specific value to be returned ; 0 - random
  input       [15:0]                    phy_cr_rd_data_return_value,   // value to be returned

  output  reg                           phy_cr_para_ack,
  output  reg [VPT_DATA-1:0]            phy_cr_para_rd_data
);


parameter MIN_WR_RESPOND_DELAY = 1;
parameter MAX_WR_RESPOND_DELAY = 6 + 2*VPT_NUM;
parameter MIN_RD_RESPOND_DELAY = 1;
parameter MAX_RD_RESPOND_DELAY = 6 + 2*VPT_NUM + 5;

wire       wr_timer_start;
wire [7:0] wr_timer_thr;
wire [7:0] wr_timer_lo_rnd;
wire [7:0] wr_timer_hi_rnd;
wire       wr_start_timer_exp;
wire       wr_random_delay_en;
reg        wr_start_timer_en;

wire       rd_timer_start;
wire [7:0] rd_timer_thr;
wire [7:0] rd_timer_lo_rnd;
wire [7:0] rd_timer_hi_rnd;
wire       rd_start_timer_exp;
wire       rd_random_delay_en;
reg        rd_start_timer_en;

assign wr_timer_start   = phy_cr_para_wr_en && (phy_cr_respond_time != 0);
assign wr_timer_thr     = MIN_WR_RESPOND_DELAY;
assign wr_timer_lo_rnd  = phy_cr_respond_time == 0 ? 1                     :
                          phy_cr_respond_time == 1 ? MIN_WR_RESPOND_DELAY  : 61;
assign wr_timer_hi_rnd  = phy_cr_respond_time == 0 ? 1                     :
                          phy_cr_respond_time == 1 ? MAX_WR_RESPOND_DELAY  : 61;

assign rd_timer_start   = phy_cr_para_rd_en && (phy_cr_respond_time != 0);
assign rd_timer_thr     = MIN_RD_RESPOND_DELAY;
assign rd_timer_lo_rnd  = phy_cr_respond_time == 0 ? 1                     :
                          phy_cr_respond_time == 1 ? MIN_RD_RESPOND_DELAY  : 61;
                          
assign rd_timer_hi_rnd  = phy_cr_respond_time == 0 ? 1                     :
                          phy_cr_respond_time == 1 ? MAX_RD_RESPOND_DELAY  : 61;

initial begin
   phy_cr_para_rd_data = '0;
   phy_cr_para_ack     = '0;
end

//WR timer
DWC_pcie_gphy_timer #(
  .WD        (8),
  .TP        (TP)
) wr_start_timer (
  .clk       (clk),
  .rst_n     (rst_n),
  .start     (wr_timer_start),
  .thr       (wr_timer_thr),
  .rnd_en    (1'b1),
  .rnd_lo    (wr_timer_lo_rnd),
  .rnd_hi    (wr_timer_hi_rnd),
  
  .expired   (wr_start_timer_exp)
);

//RD timer
DWC_pcie_gphy_timer #(
  .WD        (8),
  .TP        (TP)
) rd_start_timer (
  .clk       (clk),
  .rst_n     (rst_n),
  .start     (rd_timer_start),
  .thr       (rd_timer_thr),
  .rnd_en    (1'b1),
  .rnd_lo    (rd_timer_lo_rnd),
  .rnd_hi    (rd_timer_hi_rnd),
  .expired   (rd_start_timer_exp)
);


// wr_start_timer_en = 1 -> write in pending
always @(posedge clk or negedge rst_n)
begin
   if (!rst_n)             wr_start_timer_en <= #TP  1'b0; else
   if (wr_timer_start)     wr_start_timer_en <= #TP  1'b1; else
   if (wr_start_timer_exp) wr_start_timer_en <= #TP  1'b0; else
                           wr_start_timer_en <= #TP wr_start_timer_en;
end

// rd_start_timer_en = 1 -> read in pending
always @(posedge clk or negedge rst_n)
begin
   if (!rst_n)             rd_start_timer_en <= #TP 1'b0; else
   if (rd_timer_start)     rd_start_timer_en <= #TP 1'b1; else
   if (rd_start_timer_exp) rd_start_timer_en <= #TP 1'b0; else
                           rd_start_timer_en <= #TP rd_start_timer_en;
end

// generate ack when WR or RD
always @(posedge clk or negedge rst_n)
begin
   if (!rst_n)                                        phy_cr_para_ack <= #TP 1'b0; else 
   if ((phy_cr_para_wr_en || phy_cr_para_rd_en) 
         && phy_cr_respond_time == 0)                 phy_cr_para_ack <= #TP 1'b1; else 
   if (wr_start_timer_en && wr_start_timer_exp)       phy_cr_para_ack <= #TP 1'b1; else       
   if (rd_start_timer_en && rd_start_timer_exp)       phy_cr_para_ack <= #TP 1'b1; else       
   if (!wr_start_timer_en && !rd_start_timer_en)      phy_cr_para_ack <= #TP 1'b0; else       
                                                      phy_cr_para_ack <= #TP phy_cr_para_ack; 
end

// generate read data 
always @(posedge clk)
begin
   if (!rst_n)                                   phy_cr_para_rd_data <= #TP 16'b0;     else
   if ((phy_cr_para_wr_en || phy_cr_para_rd_en) 
         && phy_cr_respond_time == 0)            phy_cr_para_rd_data <= #TP phy_cr_rd_data_load_en ? phy_cr_rd_data_return_value : $random(); else
   if (rd_start_timer_en && rd_start_timer_exp)  phy_cr_para_rd_data <= #TP phy_cr_rd_data_load_en ? phy_cr_rd_data_return_value : $random(); else
                                                 phy_cr_para_rd_data <= #TP phy_cr_para_rd_data;
end


endmodule: phy_viewport_slv
