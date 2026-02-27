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
// ---    $DateTime: 2019/10/03 14:27:33 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_flags.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Contains logic to generate various flags which are either used internally
// --- in pm_active_ctrl or are outputs from pm_active_ctrl
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_active_flags
    // Parameters
    #( 
    parameter TP = `TP,
    parameter L1_BLOCK_TLP = 0,
    parameter L23_BLOCK_TLP = 0,
    parameter L1_WAIT_LAST_TLP_ACK = 0,
    parameter PREP_4L1 = 0,
    parameter L1_LINK_ENTR_L1 = 0,
    parameter WAIT_LAST_PMDLLP = 0,
    parameter L1 = 0,
    parameter IDLE = 0,
    parameter L0 = 0,
    parameter PREP_4L23 = 0,
    parameter L1_WAIT_PMDLLP_ACK = 0,
    parameter L23_WAIT_PMDLLP_ACK = 0,
    parameter WAIT_DSTATE_UPDATE = 0,
    parameter L23RDY = 0
    )
    (
    // Inputs
    input       aux_clk,                // aux_clk
    input       pwr_rst_n,              // power on reset
    input [4:0] master_state,           // master FSM state
    input       smlh_link_in_training,  // Indication that SMLH LTSSM is in Recovery
    input       latch_as_entr_l1,       // ASPM L1 entry
    input       radm_pm_asnak,          // PM_Active_State_Nak received
    input       smlh_link_up,           // Link down request from SMLH LTSSM
    input       smlh_in_l0,             // LTSSM is in L0
    input       pm_l23_entry_abort,     // Aborted L23 entry during transmission of PM_Enter_L23 DLLP's
    input [3:0] xdlh_match_pmdllp,      // Layer2 transmitted PM DLLP
                                        // 3: PM_Enter_L23 
                                        // 2: PM_ENter_L1
                                        // 1: PM_Active_State_Request_L1
                                        // 0: PM_Request_Ack
    // Outputs
    output wire pm_l1_aspm_flag,        // L1 ASPM entry flag
    output wire pm_l23_entry_flag,      // L23 Ready entry flag
    output wire pm_xdlh_enter_l23,      // Request to transmit PM_Enter_L23 DLLP's
    output wire pm_xdlh_enter_l1,       // Request to transmit PM_Enter_L1 DLLP's
    output wire pm_xdlh_actst_req_l1,   // Request to transmit PM_Active_State_Request_L1 DLLP's
    output wire pm_timeout,             // Timeout
    output wire pm_l23_entry_restart,   // Restart aborted L23 entry negotiation
    output wire pm_l1_pcipm_hs_done,    // PM_Enter_L1 requested by PM block and sent by XDLH 
    output wire pm_l1_aspm_hs_done,     // PM_Active_State_Request_L1 requested by PM block and sent by XDLH 
    output wire pm_l23_hs_done          // PM_Enter_L23 requested by PM block and sent by XDLH
);

// -----------------------------------------------------------------------------
// Net Declarations
// -----------------------------------------------------------------------------
wire  int_set_l1_aspm_flag;
wire  int_clear_l1_aspm_flag;
wire  int_set_l23_entry_flag;
wire  int_clear_l23_entry_flag;
wire  int_req_l1_dllp;
wire  int_set_actst_req_l1;
wire  int_clear_req_l1;
wire  int_set_pm_req_l1;
wire  int_set_pm_req_l23;
wire  int_clear_pm_req_l23;
wire  int_clear_l23_restart;
wire int_set_l1_pcipm_hs;
wire int_set_l1_aspm_hs;
wire int_set_l23_hs;
wire int_clear_l1_pcipm_hs;
wire int_clear_l1_aspm_hs;
wire int_clear_l23_hs;

// ASPM L1 flag this flag is set when L1 ASPM entry negotiation has been initiated
// but is interrupted by LTSSM going through Recovery
// The flag is necessary to direct the USP to restart the L1 ASPM negotiation when Recovery
// has completed.
assign int_set_l1_aspm_flag = smlh_link_in_training && latch_as_entr_l1 && ((master_state == L1_BLOCK_TLP) ||
(master_state == L1_WAIT_LAST_TLP_ACK) || int_req_l1_dllp || (master_state == PREP_4L1)
|| (master_state == L1_LINK_ENTR_L1) || (master_state == WAIT_LAST_PMDLLP));
// The flag is cleared if the ASPM L1 request is Naked by DSP or if PCI-PM L1/L23 is initiated or upon completion
// of L1 entry process or if the link reset request is asserted
assign int_clear_l1_aspm_flag = ((int_req_l1_dllp && radm_pm_asnak && latch_as_entr_l1) || !latch_as_entr_l1
|| (master_state == L1) || (master_state == L23_BLOCK_TLP)) || !smlh_link_up;

// L2 entry flag
// Set the flag when entry DLLP's are being sent
// Clear the flag if we go back to the IDLE state for any reason or if we complete L2 entry
assign int_set_l23_entry_flag = (master_state == L23_WAIT_PMDLLP_ACK);
assign int_clear_l23_entry_flag = (master_state == PREP_4L23) || (master_state == IDLE);

// L23 Negotiation restart flag
// Set the flag if a transition from L23_WAIT_PMDLLP_ACK to IDLE occurs
// Clear the flag upon completion of L23 entry or if the link is reset
assign int_clear_l23_restart = (master_state == L23RDY) || !smlh_link_up;

// Create flags for various purposes
pm_flag
 u_flag_inst [2:0] (
  // Inputs
  .clk    (aux_clk),
  .rst_n  (pwr_rst_n),
  .clear  ({int_clear_l1_aspm_flag, int_clear_l23_entry_flag, int_clear_l23_restart}),
  .set    ({int_set_l1_aspm_flag, int_set_l23_entry_flag, pm_l23_entry_abort}),
  // Outputs
  .flag_r ({pm_l1_aspm_flag, pm_l23_entry_flag, pm_l23_entry_restart})
);

// Detect a transition to the L1_WAIT_PMDLLP_ACK state to initiate relevant L1 entry protocol
assign int_req_l1_dllp = (master_state == L1_WAIT_PMDLLP_ACK);

// Logic for setting the request to the XDLH to transmit PM_Active_State_Request_L1 DLLP
assign int_set_actst_req_l1 = (int_req_l1_dllp && latch_as_entr_l1) && !smlh_link_in_training;
assign int_clear_req_l1 = !int_req_l1_dllp;

// Logic for setting the request to the XDLH to transmit PM_Enter_L1 DLLP
assign int_set_pm_req_l1 = (int_req_l1_dllp && !latch_as_entr_l1) && !smlh_link_in_training;

// Logic for setting the request to the XDLH to transmit PM_Enter_L2 DLLP
assign int_set_pm_req_l23 = (master_state == L23_WAIT_PMDLLP_ACK) && !smlh_link_in_training;
assign int_clear_pm_req_l23 = (!(master_state == L23_WAIT_PMDLLP_ACK));

pm_flag
 u_pm_dllp_req_inst [2:0] (
  // Inputs
  .clk    (aux_clk),
  .rst_n  (pwr_rst_n),
  .clear  ({int_clear_pm_req_l23, int_clear_req_l1, int_clear_req_l1}),
  .set    ({int_set_pm_req_l23, int_set_pm_req_l1, int_set_actst_req_l1}),
  // Outputs
  .flag_r ({pm_xdlh_enter_l23, pm_xdlh_enter_l1, pm_xdlh_actst_req_l1})
);

// Watchdog timer for WAIT_DSTATE_UPDATE state of the master FSM
pm_active_timer

  // Parameters
  #(
  .WAIT_DSTATE_UPDATE (WAIT_DSTATE_UPDATE)
  ) u_pm_active_timer (
  // Inputs
  .aux_clk      (aux_clk),
  .pwr_rst_n    (pwr_rst_n),
  .master_state (master_state),
  .smlh_in_l0   (smlh_in_l0),
  // Outputs
  .pm_timeout   (pm_timeout)
);

// Create flags to indicate PM DLLP's requested by PM block have been sent by the Layer2
assign int_set_l23_hs = xdlh_match_pmdllp[3] && pm_xdlh_enter_l23;
assign int_set_l1_pcipm_hs = xdlh_match_pmdllp[2] && pm_xdlh_enter_l1;
assign int_set_l1_aspm_hs = xdlh_match_pmdllp[1] && pm_xdlh_actst_req_l1;

assign int_clear_l23_hs = !pm_xdlh_enter_l23;
assign int_clear_l1_pcipm_hs = !pm_xdlh_enter_l1;
assign int_clear_l1_aspm_hs = !pm_xdlh_actst_req_l1;

pm_flag
 u_pm_dllp_hs_inst [2:0] (
  // Inputs
  .clk    (aux_clk),
  .rst_n  (pwr_rst_n),
  .clear  ({int_clear_l23_hs, int_clear_l1_pcipm_hs, int_clear_l1_aspm_hs}),
  .set    ({int_set_l23_hs, int_set_l1_pcipm_hs, int_set_l1_aspm_hs}),
  // Outputs
  .flag_r ({pm_l23_hs_done, pm_l1_pcipm_hs_done, pm_l1_aspm_hs_done})
);
    

endmodule

