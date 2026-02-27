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
// ---    $DateTime: 2019/02/05 05:23:47 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pkg.svh#2 $
// -------------------------------------------------------------------------
// --- Description: parameters and support classes for the generic PHY
// -------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_GPHY_PKG__SVH__
`define __GUARD__DWC_PCIE_GPHY_PKG__SVH__

package DWC_pcie_gphy_pkg;

  // -------------------------------------------------------------------------
  // --- Description: a simple class to support random value generation with
  // --- seed initialization. This code snippet shows how to use the class to 
  // --- get per-instance unique randomization. This is proved to work across
  // --- all major simulators
  // ---
  // ---          DWC_pcie_gphy_pkg::DWC_pcie_gphy_randRange rnd_thr;
  // ---          initial begin
  // ---            string inst;
  // ---            int seed;
  // ---
  // ---            // generate a seed which is unique to this instance
  // ---            $sformat(inst, "%m");
  // ---            seed = $get_initial_random_seed();
  // ---            for (int i=0 ; i< inst.len(); i++) seed += inst.getc(i);
  // ---
  // ---            rnd_thr = new(inst, seed, rnd_lo, rnd_hi);
  // ---            forever @(posedge start) rnd_thr.newValue(rnd_lo, rnd_hi);
  // ---          end
  // ---
  // -------------------------------------------------------------------------
  class DWC_pcie_gphy_randRange;
    // these are only used for debugging purposes
    string name;
    int seed;

    // the value to randomize
    rand int value;

    // limits and constraint
         int lo;
         int hi;

    constraint c {
      hi - lo <= 1 -> value inside { [lo:hi] };
      hi - lo >  1 -> value dist { lo := 45, [lo+1:hi-1] := 10, hi := 45 };
    }

    // constructor
    function new (string name, int seed);
      this.name = name;
      this.seed = seed;
      this.srandom(seed);
      this.lo = 0;
      this.hi = 0;
    endfunction: new

    // generate a new random value
    function void newValue(int lo, int hi);
      this.lo = lo;
      this.hi = hi;
      void'(this.randomize());
    endfunction: newValue

    // return the current value
    function int getValue();
      return this.value;
    endfunction: getValue

    // for debugging purposes only
    function void post_randomize();
      `ifdef DWC_PCIE_GPHY_RAND_DEBUG
        $display("%0s : SEED: 0x%0h - Randomized value: %0d", name, seed, value);
      `endif // DWC_PCIE_GPHY_RAND_DEBUG
    endfunction: post_randomize
  endclass: DWC_pcie_gphy_randRange



  // -------------------------------------------------------------------------
  // extend DWC_pcie_gphy_randRange to implement constraints for rxclk drift
  // -------------------------------------------------------------------------
  class DWC_pcie_gphy_rxdrift extends DWC_pcie_gphy_randRange;
    // store the current level of the rx queue
    // required to constraint the drift as to 
    // avoid underruns
    int lvl;

    // additional constraint to avoid underrun
    constraint no_underrun {
      lvl < 10 -> this.value >= 0;
    }

    // constructor
    function new (string name, int seed);
      super.new(name, seed);
      this.lvl = 0;
    endfunction: new

    // generate a new random value
    function void newValue(int lo, int hi, int lvl);
      this.lo  = lo;
      this.hi  = hi;
      this.lvl = lvl;
      void'(this.randomize());
    endfunction: newValue
  endclass: DWC_pcie_gphy_rxdrift

endpackage: DWC_pcie_gphy_pkg

`endif // __GUARD__DWC_PCIE_GPHY_PKG__SVH__

