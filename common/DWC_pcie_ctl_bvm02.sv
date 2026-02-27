
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
// Filename    : DWC_pcie_ctl_bvm02.v
// Revision    : $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_ctl_bvm02.sv#1 $
// Author      : Liming SU       01/10/17
// Description : DWC_pcie_ctl_bvm02.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 23f30511
//
////////////////////////////////////////////////////////////////////////////////


`ifndef SYNTHESIS
module DWC_pcie_ctl_bvm02
(
  input      clk,
  input      rst_n,
  output reg clk_stopped,
  output     [63:0] clk_period
);

  real          clk_period_int;
  real          time_start;
  reg   [7:0]   cnt;
  reg   [7:0]   cnt_previous;
  reg           clk_stable;
  reg           clk_stopped_nxt;

  assign clk_period = $realtobits(clk_period_int);

  initial begin : signal_initialization_PROC
    cnt             = 2'b00;
    cnt_previous    = 2'b00;
    clk_period_int  = 0.0;
    time_start      = 0.0;
    clk_stopped_nxt = 1'b1;
    clk_stopped     = 1'b1;
  end

  ///////////////////////
  // get period of clk //
  ///////////////////////

  always @(posedge clk) begin : clk_period_sched_counter_PROC
    if (clk_stable) begin
      clk_period_int <= $realtime - time_start;
    end
    time_start <= $realtime;
  end

  ////////////////////////////
  // detect stoppage of clk //
  ////////////////////////////

  always @(clk_stopped_nxt) begin : clk_stopped_PROC
    if ($time > 0) begin
      if($sampled(clk_stopped_nxt)) begin
        @(posedge clk);
        clk_stopped = clk_stopped_nxt;
      end else begin
        clk_stopped = clk_stopped_nxt;
      end
    end
  end

  always @(*) begin : clk_stopped_nxt_PROC

    fork

    begin
      @(negedge clk_stable);
    end


    begin
      wait (clk_stable==1);
      clk_stopped_nxt = 0;

      repeat(2)
        @(posedge clk);

      while (!clk_stopped_nxt) begin
        cnt_previous = cnt;

        #(clk_period_int*1.5);
        if (cnt==cnt_previous) begin
          clk_stopped_nxt = 1;
          #(clk_period_int/2);
        end
      end
    end

    join_any
    disable fork;

  end

  always @(posedge clk or posedge clk_stopped_nxt or negedge rst_n) begin : posedg_count_PROC
    if (!rst_n || (clk_stopped_nxt && clk_stable)) begin
      cnt <= 0;
      clk_stable <= 0;
      clk_stopped_nxt <= 1;
    end
    else if ($time > 0) begin
      if (cnt == 3'd1) begin
        clk_stable <= 1;
      end
      cnt <= cnt+3'd1;
    end
  end

endmodule
`endif // SYNTHESIS
