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
// ---    $DateTime: 2018/08/30 02:24:02 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/hot_plug_ctrl.sv#2 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module generates hot plug interrupt/wake signal
// --- Only applicable for downstream port
// --- Hot-plug events (sec 6.7.3 of PCIe spec):
// --- 1. Slot Events:
// ---    - Attention Button Pressed
// ---    - Power Fault Detected
// ---    - MRL Sensor Changed
// ---    - Presence Detect Changed
// --- 2. Command Completed Events
// --- 3. Data Link Layer State Changed Events
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module hot_plug_ctrl(
// ---- inputs ----
    core_clk,
    core_rst_n,
    cfg_pme_en,
    cfg_msi_en,
    cfg_msix_en,

    cfg_atten_button_pressed,
    cfg_pwr_fault_det,
    cfg_mrl_sensor_chged,
    cfg_pre_det_chged,
    cfg_cmd_cpled_int,
    cfg_dll_state_chged,
    cfg_int_disable,

    cfg_hp_int_en,

// ----- Outputs -----
    hp_pme,
    hp_int,
    hp_msi
);

parameter INST  = 0;                    // The uniquifying parameter for each port logic instance.
parameter TP    = `TP;                  // Clock to Q delay (simulator insurance)

// -------- Inputs ----------
input   core_clk;
input   core_rst_n;
input   cfg_pme_en;
input   cfg_msi_en;
input   cfg_msix_en;

input   cfg_atten_button_pressed;
input   cfg_pwr_fault_det;
input   cfg_mrl_sensor_chged;
input   cfg_pre_det_chged;
input   cfg_cmd_cpled_int;
input   cfg_dll_state_chged;
input   cfg_int_disable;
input   cfg_hp_int_en;

// -------- Outputs ----------
output  hp_pme;                         // PME# to power management
output  hp_int;                         // Hot plug Interrupt
output  hp_msi;                         // Hot plug MSI/MSI-X

// ------ Internal Regs & Wires -----
wire    hp_pme;
wire    hp_int;
wire    hp_event;
wire    hp_int_src;
reg     hp_event_q;
reg     cfg_atten_button_pressed_d;
reg     cfg_pwr_fault_det_d;
reg     cfg_mrl_sensor_chged_d;
reg     cfg_pre_det_chged_d;
reg     cfg_cmd_cpled_int_d;
reg     cfg_dll_state_chged_d;

wire    re_cfg_atten_button_pressed;
wire    re_cfg_pwr_fault_det;
wire    re_cfg_mrl_sensor_chged;
wire    re_cfg_pre_det_chged;
wire    re_cfg_cmd_cpled_int;
wire    re_cfg_dll_state_chged;
wire    re_hp_event;

// For interrupt generation, interrupt (to application) should stay asserted
// whenever any of the enabled status bit is asserted
assign hp_event = (cfg_atten_button_pressed | cfg_pwr_fault_det |
                   cfg_mrl_sensor_chged     | cfg_pre_det_chged |
                   cfg_cmd_cpled_int        | cfg_dll_state_chged);

// For MSI generation, MSI should be generated upstream whenever the status
// changed from not set to set (rising edge)
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        cfg_atten_button_pressed_d  <= #TP 0;
        cfg_pwr_fault_det_d         <= #TP 0;
        cfg_mrl_sensor_chged_d      <= #TP 0;
        cfg_pre_det_chged_d         <= #TP 0;
        cfg_cmd_cpled_int_d         <= #TP 0;
        cfg_dll_state_chged_d       <= #TP 0;
    end
    else begin
        cfg_atten_button_pressed_d  <= #TP cfg_atten_button_pressed;
        cfg_pwr_fault_det_d         <= #TP cfg_pwr_fault_det;
        cfg_mrl_sensor_chged_d      <= #TP cfg_mrl_sensor_chged;
        cfg_pre_det_chged_d         <= #TP cfg_pre_det_chged;
        cfg_cmd_cpled_int_d         <= #TP cfg_cmd_cpled_int;
        cfg_dll_state_chged_d       <= #TP cfg_dll_state_chged;
    end
end

assign re_cfg_atten_button_pressed  = ~cfg_atten_button_pressed_d & cfg_atten_button_pressed;
assign re_cfg_pwr_fault_det         = ~cfg_pwr_fault_det_d        & cfg_pwr_fault_det;
assign re_cfg_mrl_sensor_chged      = ~cfg_mrl_sensor_chged_d     & cfg_mrl_sensor_chged;
assign re_cfg_pre_det_chged         = ~cfg_pre_det_chged_d        & cfg_pre_det_chged;
assign re_cfg_cmd_cpled_int         = ~cfg_cmd_cpled_int_d        & cfg_cmd_cpled_int;
assign re_cfg_dll_state_chged       = ~cfg_dll_state_chged_d      & cfg_dll_state_chged;

assign re_hp_event = (re_cfg_atten_button_pressed | re_cfg_pwr_fault_det |
                      re_cfg_mrl_sensor_chged     | re_cfg_pre_det_chged |
                      re_cfg_cmd_cpled_int        | re_cfg_dll_state_chged);

//
// Hot Plug Interrupt Source
//
assign hp_int_src = cfg_hp_int_en & hp_event;

//
// Activate Wake Mechanism
//
assign hp_pme = re_hp_event & cfg_pme_en;

//
// Activate INTx Mechanism
//
assign hp_int = hp_int_src & ~cfg_int_disable & ~(cfg_msi_en | cfg_msix_en);

//
// Activate MSI Interrupt Message
//

assign hp_msi = re_hp_event  & hp_int_src & (cfg_msi_en | cfg_msix_en);

endmodule
