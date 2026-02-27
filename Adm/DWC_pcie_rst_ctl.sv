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
// ---    $DateTime: 2020/09/18 02:33:28 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/DWC_pcie_rst_ctl.sv#5 $
// -------------------------------------------------------------------------
// --- Module description: Reset control 
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_rst_ctl
 #(
   parameter GEN2_DYNAMIC_FREQ_VALUE             = 1,
   parameter TP                                  = `TP
  )
  
                         (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  input                                              core_clk,    
  input                                              core_rst_n,
  // -------------------------------------------------------------------------------------
  // Link Reset Request
  input                                              smlh_req_rst_not,
  // -------------------------------------------------------------------------------------
  // Reset Request Interface
  output wire                                        rstctl_req_rst_not
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Regs/Wires
  // -------------------------------------------------------------------------------------
  wire                                     s_smlh_req_rst_hl;
  reg                                      r_smlh_req_rst_not;
  reg                                      rr_smlh_req_rst_not;
  wire                                     s_link_req_rst_not;

  
  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------

  // -------------------------------------------------------------------------------------
  // Detect reset request.
  // Applicaton reset request sequence triggered on the negative edge of smlh_req_rst_not.
  // The negative edge is detected and maintained until the core is reset.
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_smlh_req_rst
    if (!core_rst_n) begin
      r_smlh_req_rst_not <= # TP 1'b0; 
    end else begin
      r_smlh_req_rst_not <= # TP smlh_req_rst_not;
    end  
  end

  // Falling edge detect
  assign s_smlh_req_rst_hl = !smlh_req_rst_not && r_smlh_req_rst_not;

  // Register reset request
  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      rr_smlh_req_rst_not <= # TP 1'b1;
    end else if (s_smlh_req_rst_hl) begin
      rr_smlh_req_rst_not <= # TP 1'b0;
    end
  end

  // Request warm reset
  assign s_link_req_rst_not = rr_smlh_req_rst_not;



  assign rstctl_req_rst_not = s_link_req_rst_not;





`ifndef SYNTHESIS



`endif // SYNTHESIS
   
endmodule
