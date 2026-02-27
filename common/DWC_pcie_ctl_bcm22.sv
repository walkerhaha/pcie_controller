
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
// Filename    : DWC_pcie_ctl_bcm22.v
// Revision    : $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_ctl_bcm22.sv#1 $
// Author      : Bruce Dean      June 24, 2004
// Description : DWC_pcie_ctl_bcm22.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 4eeb8eba
//
////////////////////////////////////////////////////////////////////////////////
module DWC_pcie_ctl_bcm22 (
             clk_s, 
             rst_s_n, 
             event_s, 

             clk_d, 
             rst_d_n, 
             event_d
             );

 parameter REG_EVENT    = 1;    // RANGE 0 to 1
 parameter F_SYNC_TYPE  = 2;    // RANGE 0 to 4
 parameter VERIF_EN     = 1;    // RANGE 0 to 4
 parameter PULSE_MODE   = 0;    // RANGE 0 to 3
 parameter SVA_TYPE     = 0;
 localparam F_SYNC_TYPE_P8 = F_SYNC_TYPE + 8;
 
input  clk_s;                   // clock input for source domain
input  rst_s_n;                 // active low async. reset in clk_s domain
input  event_s;                 // event pulse input (active high event)

input  clk_d;                   // clock input for destination domain
input  rst_d_n;                 // active low async. reset in clk_d domain
output event_d;                 // event pulse output (active high event)

wire   next_tgl_event_s;
wire   tgl_event_cc;
reg    tgl_event_s;
reg    tgl_s_nfb_cdc;
reg    event_s_d;
wire   dw_sync_data_d;
reg    sync_event_out;    // history for edge detect
wire   next_event_d_q;    // event seen via edge detect (before registered)
reg    event_d_q;         // registered version of event seen
wire   event_s_pet;
wire   event_s_net;
wire   event_s_tgl;



`ifndef SYNTHESIS
`ifndef DWC_DISABLE_CDC_METHOD_REPORTING
  initial begin
    if ((F_SYNC_TYPE > 0)&&(F_SYNC_TYPE < 8))
       $display("Information: *** Instance %m module is using the <Toggle Type Event Sychronizer (2)> Clock Domain Crossing Method ***");
  end

`endif
`endif

generate
    
    if (PULSE_MODE <= 0) begin : GEN_PLSMD0
      assign next_tgl_event_s = tgl_event_s ^ event_s;
    end
    
    if (PULSE_MODE == 1) begin : GEN_PLSMD1
      assign next_tgl_event_s = tgl_event_s ^ event_s_pet;
    end
    
    if (PULSE_MODE == 2) begin : GEN_PLSMD2
      assign next_tgl_event_s = tgl_event_s ^ event_s_net;
    end
    
    if (PULSE_MODE >= 3) begin : GEN_PLSMD3
      assign next_tgl_event_s = tgl_event_s ^ (event_s_net | event_s_pet);
    end

endgenerate


 assign event_s_pet =  event_s & (! event_s_d);
// spyglass disable_block W528
// SMD: A signal or variable is set but never read
// SJ: Based on component configuration, this(these) signal(s) or parts of it will not be used to compute the final result.
 assign event_s_net = !event_s &   event_s_d;
 assign event_s_tgl = tgl_event_s ^ event_s_pet;
// spyglass enable_block W528
 
  always @ (posedge clk_s or negedge rst_s_n) begin : event_lauch_reg_PROC
    if (rst_s_n == 1'b0) begin
      tgl_event_s <= 1'b0;
      tgl_s_nfb_cdc<=1'b0;
      event_s_d   <= 1'b0;
    end else begin
      tgl_event_s <= next_tgl_event_s;
      tgl_s_nfb_cdc<=next_tgl_event_s;
      event_s_d   <= event_s;
    end
  end // always : event_lauch_reg_PROC
  

  
  assign tgl_event_cc = tgl_s_nfb_cdc;

  DWC_pcie_ctl_bcm21
   #(1, F_SYNC_TYPE_P8, VERIF_EN, 1) U_SYNC(
        .clk_d(clk_d),
        .rst_d_n(rst_d_n),
        .data_s(tgl_event_cc),
        .data_d(dw_sync_data_d) );

  always @ (posedge clk_d or negedge rst_d_n) begin : second_sync_PROC
    if (rst_d_n == 1'b0) begin
      sync_event_out <= 1'b0;
// spyglass disable_block W528
// SMD: A signal or variable is set but never read
// SJ: Based on component configuration, this(these) signal(s) or parts of it will not be used to compute the final result.
      event_d_q      <= 1'b0;
// spyglass enable_block W528
    end else begin
      sync_event_out <= dw_sync_data_d;
      event_d_q      <= next_event_d_q;
    end
  end // always


  assign next_event_d_q = sync_event_out ^ dw_sync_data_d;

generate

  if (REG_EVENT == 0) begin : GEN_RGEVT0
    assign event_d = next_event_d_q;
  end

  else begin : GEN_RGEVT1
    assign event_d = event_d_q;
  end

endgenerate

`ifdef DWC_BCM_SNPS_ASSERT_ON
`ifndef SYNTHESIS
  generate
    if (SVA_TYPE == 1) begin : GEN_SVATP_EQ_1
      DWC_pcie_ctl_sva02 #(
        .F_SYNC_TYPE    (F_SYNC_TYPE&7),
        .PULSE_MODE     (PULSE_MODE   )
      ) P_PULSE_SYNC_HS (
          .clk_s        (clk_s        )
        , .rst_s_n      (rst_s_n      )
        , .rst_d_n      (rst_d_n      )
        , .event_s      (event_s      )
        , .event_d      (event_d      )
      );
    end
  endgenerate

  generate
    if (F_SYNC_TYPE==0) begin : GEN_SINGLE_CLOCK_CANDIDATE
      DWC_pcie_ctl_sva07 #(F_SYNC_TYPE, F_SYNC_TYPE) P_CDC_CLKCOH (.*);
    end
  endgenerate
`endif // SYNTHESIS
`endif // DWC_BCM_SNPS_ASSERT_ON
 
endmodule
