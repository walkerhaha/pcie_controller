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
// ---    $DateTime: 2017/03/13 07:29:23 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_timer.v#4 $
// -------------------------------------------------------------------------
// --- Description: a timer implementation with the following features:
// --- * configurable bit width
// --- * asynchronous reset
// --- * synchronous start
// --- * configuration port to set threshold
// --- * configuration ports for random threshold generation
// --- * random threshold generation support - per-instance randomization
// -------------------------------------------------------------------------

module DWC_pcie_gphy_timer #(
  parameter WD = 10,
  parameter TP = 1
) (
  input          clk,
  input          rst_n,

  input          start,
  input [WD-1:0] thr,
  input          rnd_en,
  input [WD-1:0] rnd_lo,
  input [WD-1:0] rnd_hi,

  output reg     expired
);

// -------------------------------------------------------------------------
// this is required to support the randomization of the timer threshold
// -------------------------------------------------------------------------
DWC_pcie_gphy_pkg::DWC_pcie_gphy_randRange rnd_thr;
initial begin
  string inst;
  int seed;

  // generate a seed which is unique to this instance
  $sformat(inst, "%m");
  seed = $get_initial_random_seed();
  for (int i=0 ; i< inst.len(); i++) seed += inst.getc(i);

  rnd_thr = new(inst, seed);
  forever @(posedge start) rnd_thr.newValue(rnd_lo, rnd_hi);
end



// -------------------------------------------------------------------------
// whenever a synchronous start is received either register the 'thr'
// when randomization is off (rnd_en == 0), or generate a random threshold
// when randomization is on (rnd_en == 1)
// -------------------------------------------------------------------------
reg [WD-1:0] counter;

always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
  begin
    // at reset the counter is expired
    counter       <= #TP {WD{1'b0}};
    expired       <= #TP 1'b1;
  end else begin
    // synchronous command to start the countdown
    if (start)
    begin
      counter     <= #TP (rnd_en) ? rnd_thr.getValue() : thr;
      expired     <= #TP 1'b0;
    end else begin
      // counting down
      // once zero is reached stay there
      counter     <= #TP (counter > 0) ? counter - 1 : {WD{1'b0}};
      expired     <= #TP (counter == {WD{1'b0}});
    end
  end
end
 
endmodule: DWC_pcie_gphy_timer

