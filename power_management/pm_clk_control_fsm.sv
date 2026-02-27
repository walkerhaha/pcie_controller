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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_clk_control_fsm.sv#11 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Clock control FSM 
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_clk_control_fsm
  #(
    parameter TP = `TP
  )
  (
    input         sel_aux_clk, // request to switch aux_clk to the slow clock
    input         perst_sel_aux_clk, // perst is asserted so switch to the slow clock
    input         en_core_clk, // request to gate off core_clk
    input         aux_clk_active, // aux_clk switch complete indication
    input         aux_clk, // clock
    input         pwr_rst_n, // reset
    output  logic pm_en_core_clk, // enable core clock
    output  logic pm_sel_aux_clk, // switch aux_clk to the slow clock
    output  logic pm_aux_clk_active // aux_clk_active indication
    ,output  logic pm_aux_clk_inactive // aux_clk_inactive indication
  );


typedef enum logic [2:0] {IDLE, SW_AUX_TO_CORE, EN_CORE_CLK, CORE_CLK_ACTIVE, SW_AUX_CLK, GATE_CORE_CLK, AUX_CLK_ACTIVE} pm_clk_state_e;

pm_clk_state_e rstate, snext_state;

logic s_aux_to_core;

// switch the aux clock to core clock when not selecting aux_clk and powerdown logic is not actively driving powerdown
assign s_aux_to_core = !sel_aux_clk;

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : rstate_PROC
  if (!pwr_rst_n) begin
    rstate <= #TP IDLE;
  end else begin
    rstate <= #TP snext_state;
  end
end : rstate_PROC

always_comb begin : snext_state_PROC
  unique case (rstate)
    SW_AUX_TO_CORE : begin
      // aux_clk switch completed enable core_clk
      if (!aux_clk_active) begin
        snext_state = EN_CORE_CLK;
      // If perst is asserted switch aux_clk back to the slow clock
      end else if (perst_sel_aux_clk) begin
        snext_state = SW_AUX_CLK;
      end else begin
        snext_state = SW_AUX_TO_CORE;
      end
    end
    EN_CORE_CLK : begin
      // If perst is asserted switch aux_clk back to the slow clock
      if (perst_sel_aux_clk) begin
        snext_state = SW_AUX_CLK;
      end
      // Wait for exit from low power state to complete before requesting clock-gating again
      else if (!sel_aux_clk) begin
        snext_state = CORE_CLK_ACTIVE;
      end else begin
        snext_state = EN_CORE_CLK;
      end
    end
    CORE_CLK_ACTIVE : begin
      // request to switch aux_clk to slow
      if (sel_aux_clk) begin
        snext_state = SW_AUX_CLK;
      // request to gate core_clk
      end else if (!en_core_clk) begin
        snext_state = GATE_CORE_CLK;
      end else begin
        snext_state = CORE_CLK_ACTIVE;
      end
    end
    SW_AUX_CLK : begin
      // aux_clk switch complete
      if (aux_clk_active) begin
        snext_state = AUX_CLK_ACTIVE;
      end else begin
        snext_state = SW_AUX_CLK;
      end
    end
    GATE_CORE_CLK : begin
      // request to switch aux_clk to slow
      if (sel_aux_clk) begin
        snext_state = SW_AUX_CLK;
      // enable core_clk
      end else if (en_core_clk) begin
        snext_state = CORE_CLK_ACTIVE;
      end else begin
        snext_state = GATE_CORE_CLK;
      end
    end
    AUX_CLK_ACTIVE : begin
      // switch aux_clk to core_clk
      if (s_aux_to_core) begin
        snext_state = SW_AUX_TO_CORE;
      end else begin
        snext_state = AUX_CLK_ACTIVE;
      end
    end
    default : begin
      // request to switch aux_clk to core_clk
      if (s_aux_to_core) begin
        snext_state = SW_AUX_TO_CORE;
      end else begin
        snext_state = IDLE;
      end
    end
  endcase
end : snext_state_PROC

assign pm_en_core_clk = (rstate == EN_CORE_CLK) || (rstate == CORE_CLK_ACTIVE);
assign pm_sel_aux_clk = (rstate == IDLE) || (rstate == SW_AUX_CLK) || (rstate == AUX_CLK_ACTIVE);
assign pm_aux_clk_active = aux_clk_active && pm_sel_aux_clk;
assign pm_aux_clk_inactive = !aux_clk_active && !pm_sel_aux_clk;

endmodule
