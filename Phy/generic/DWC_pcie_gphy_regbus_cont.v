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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_regbus_cont.v#7 $
// -------------------------------------------------------------------------
// --- Description: PHY Register Bus Controller model
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_regbus_cont
#(
  parameter TP             = 0,  // Clock to Q delay (simulator insurance)
  parameter TX_COEF_WD     = 18, // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
  parameter DIRFEEDBACK_WD = 6,  // Width of Direction Change
  parameter FOMFEEDBACK_WD = 8,  // Width of Figure of Merit
  parameter TX_FS_WD       = 6   // Width of LF or FS
) (
input                         pclk,
input                         phy_rst_n,
input                         lane_disabled,
// For Lane Margining
input                         IndErrorSampler,
input                         SampleReportingMethod,
input                         phy_mac_margin_status,
input                         phy_mac_margin_nak,
input       [1:0]             phy_mac_margin_respinfo,
input                         phy_mac_margin_cnt_updated,
input       [6:0]             phy_mac_margin_sampl_cnt,
input       [5:0]             phy_mac_margin_error_cnt,
output                        phy_reg_margin_sampl_cnt_clr,
output                        phy_reg_margin_error_cnt_clr,
output                        phy_reg_margin_voltage_or_timing,
output                        phy_reg_margin_up_down,
output                        phy_reg_margin_left_right,
output                        phy_reg_margin_start,
output      [6:0]             phy_reg_margin_offset,
// For LowPinCount
input                         ebuf_location_upd_en,
input [7:0]                   phy_mac_ebuf_location,
input [TX_COEF_WD-1:0]        phy_mac_local_tx_pset_coef,
input                         eqpa_local_tx_coef_valid_g3,
input                         eqpa_local_tx_coef_valid_g4,
input                         eqpa_local_tx_coef_valid_g5,
input [2:0]                   update_localfslf_mode,
input [TX_FS_WD-1:0]          eqpa_localfs_g3,
input [TX_FS_WD-1:0]          eqpa_locallf_g3,
input [TX_FS_WD-1:0]          eqpa_localfs_g4,
input [TX_FS_WD-1:0]          eqpa_locallf_g4,
input [TX_FS_WD-1:0]          eqpa_localfs_g5,
input [TX_FS_WD-1:0]          eqpa_locallf_g5,
input                         eqpa_feedback_valid,
input                         g3_mac_phy_rate_pulse,
input                         g4_mac_phy_rate_pulse,
input                         g5_mac_phy_rate_pulse,
input [DIRFEEDBACK_WD-1:0]    phy_mac_dirfeedback,
input [FOMFEEDBACK_WD-1:0]    phy_mac_fomfeedback,
output [7:0]                  phy_reg_ebuf_depth_cntrl,
output                        phy_reg_rxpolarity,
output                        phy_reg_ebuf_mode,
output                        phy_reg_invalid_req,
output                        phy_reg_rxeqinprogress,
output                        phy_reg_rxeqeval,
output                        phy_reg_ebuf_rst_control,
output                        phy_reg_blockaligncontrol,
output [TX_COEF_WD-1:0]       phy_reg_txdeemph,
output                        phy_reg_getlocal_pset_coef,
output [5:0]                  phy_reg_local_pset_index,
output [TX_FS_WD-1:0]         phy_reg_fs,
output [TX_FS_WD-1:0]         phy_reg_lf,
output                        phy_reg_txswing,
output [2:0]                  phy_reg_txmargin,
output                        phy_reg_encodedecodebypass,
// For CCIX
input                         phy_mac_esm_calibrt_complete,
output      [6:0]             phy_reg_esm_data_rate0,
output      [6:0]             phy_reg_esm_data_rate1,
output                        phy_reg_esm_calibrt_req,
output                        phy_reg_esm_enable,
output                        write_ack_for_esm_calibrt_req,
//
input                         pclk_stable,
output                        phy_reg_localfslf_done,
// PipeMessageBus Signals
input       [7:0]             mac_phy_messagebus,
output      [7:0]             phy_mac_messagebus,
// Command interface
input                         set_p2m_messagebus,
input       [7:0]             p2m_messagebus_command_value,
input                         set_m2p_messagebus,
input       [7:0]             m2p_messagebus_command_value
);
wire        [7:0]             phy_mac_messagebus_native;
wire        [7:0]             mac_phy_messagebus_mod;

//////////////////////////////////////////////////
// u_reg -> u_regbus_arb(txcont)
wire        [7:0]             phy_reg_ebuf_upd_freq;
// u_regbus_arb -> u_regbus_master
wire        [3:0]             phy_mac_command;
wire        [11:0]            phy_mac_address;
wire        [7:0]             phy_mac_data;
// u_regbus_slave -> u_reg/u_regbus_arb
wire        [3:0]             mac_phy_command;
wire        [11:0]            mac_phy_address;
wire        [7:0]             mac_phy_data;
wire        [7:0]             phy_reg_data;
wire                          phy_mac_command_ack;

DWC_pcie_gphy_regbus_arb #(
    .TP   (TP)
) u_regbus_arb (
// inputs
  .pclk                              (pclk),
  .phy_rst_n                         (phy_rst_n),
  .lane_disabled                     (lane_disabled),
  .IndErrorSampler                   (IndErrorSampler),
  .SampleReportingMethod             (SampleReportingMethod),
  .phy_mac_margin_status             (phy_mac_margin_status),
  .phy_mac_margin_nak                (phy_mac_margin_nak),
  .phy_mac_margin_respinfo           (phy_mac_margin_respinfo),
  .phy_mac_margin_cnt_updated        (phy_mac_margin_cnt_updated),
  .phy_mac_margin_sampl_cnt          (phy_mac_margin_sampl_cnt),
  .phy_mac_margin_error_cnt          (phy_mac_margin_error_cnt),
  .ebuf_location_upd_en              (ebuf_location_upd_en),
  .phy_mac_ebuf_location             (phy_mac_ebuf_location),
  .phy_mac_local_tx_pset_coef        (phy_mac_local_tx_pset_coef),
  .eqpa_local_tx_coef_valid_g3       (eqpa_local_tx_coef_valid_g3),
  .eqpa_local_tx_coef_valid_g4       (eqpa_local_tx_coef_valid_g4),
  .eqpa_local_tx_coef_valid_g5       (eqpa_local_tx_coef_valid_g5),
  .update_localfslf_mode             (update_localfslf_mode),
  .eqpa_localfs_g3                   (eqpa_localfs_g3),
  .eqpa_locallf_g3                   (eqpa_locallf_g3),
  .eqpa_localfs_g4                   (eqpa_localfs_g4),
  .eqpa_locallf_g4                   (eqpa_locallf_g4),
  .eqpa_localfs_g5                   (eqpa_localfs_g5),
  .eqpa_locallf_g5                   (eqpa_locallf_g5),
  .eqpa_feedback_valid               (eqpa_feedback_valid),
  .g3_mac_phy_rate_pulse             (g3_mac_phy_rate_pulse),
  .g4_mac_phy_rate_pulse             (g4_mac_phy_rate_pulse),
  .g5_mac_phy_rate_pulse             (g5_mac_phy_rate_pulse),
  .phy_mac_dirfeedback               (phy_mac_dirfeedback),
  .phy_mac_fomfeedback               (phy_mac_fomfeedback),
  .phy_mac_esm_calibrt_complete      (phy_mac_esm_calibrt_complete),
  .mac_phy_command                   (mac_phy_command),
  .mac_phy_address                   (mac_phy_address),
  .phy_mac_command_ack               (phy_mac_command_ack),
  .phy_reg_esm_calibrt_req           (phy_reg_esm_calibrt_req),
  .phy_reg_ebuf_upd_freq             (phy_reg_ebuf_upd_freq),
  .pclk_stable                       (pclk_stable),
// outputs
  .phy_mac_command                   (phy_mac_command),
  .phy_mac_address                   (phy_mac_address),
  .phy_mac_data                      (phy_mac_data),
  .write_ack_for_esm_calibrt_req     (write_ack_for_esm_calibrt_req),
  .phy_reg_localfslf_done            (phy_reg_localfslf_done)
);

DWC_pcie_gphy_regbus_master #(
    .TP   (TP)
) u_regbus_master (
// inputs
  .pclk                (pclk),
  .phy_rst_n           (phy_rst_n),
  .phy_mac_command     (phy_mac_command),
  .phy_mac_address     (phy_mac_address),
  .phy_mac_data        (phy_mac_data),
// outputs
  .phy_mac_command_ack (phy_mac_command_ack),
  .phy_mac_messagebus  (phy_mac_messagebus_native)
);

assign phy_mac_messagebus = (set_p2m_messagebus) ? p2m_messagebus_command_value : phy_mac_messagebus_native;

DWC_pcie_gphy_regbus_slave #(
    .TP   (TP)
) u_regbus_slave (
// inputs
  .pclk               (pclk),
  .phy_rst_n          (phy_rst_n),
  .mac_phy_messagebus (mac_phy_messagebus_mod),
// outputs
  .mac_phy_command    (mac_phy_command),
  .mac_phy_address    (mac_phy_address),
  .mac_phy_data       (mac_phy_data)
);

assign mac_phy_messagebus_mod = (set_m2p_messagebus) ? m2p_messagebus_command_value : mac_phy_messagebus;

DWC_pcie_gphy_reg #(
    .TP             (TP),
    .TX_COEF_WD     (TX_COEF_WD),
    .DIRFEEDBACK_WD (DIRFEEDBACK_WD),
    .FOMFEEDBACK_WD (FOMFEEDBACK_WD),
    .TX_FS_WD       (TX_FS_WD)
) u_reg (
// inputs
  .pclk                             (pclk),
  .phy_rst_n                        (phy_rst_n),
  .lane_disabled                    (lane_disabled),
  .mac_phy_command                  (mac_phy_command),
  .mac_phy_address                  (mac_phy_address),
  .mac_phy_data                     (mac_phy_data),
// outputs
  .phy_reg_data                     (phy_reg_data),
  .phy_reg_margin_sampl_cnt_clr     (phy_reg_margin_sampl_cnt_clr),
  .phy_reg_margin_error_cnt_clr     (phy_reg_margin_error_cnt_clr),
  .phy_reg_margin_voltage_or_timing (phy_reg_margin_voltage_or_timing),
  .phy_reg_margin_up_down           (phy_reg_margin_up_down),
  .phy_reg_margin_left_right        (phy_reg_margin_left_right),
  .phy_reg_margin_start             (phy_reg_margin_start),
  .phy_reg_margin_offset            (phy_reg_margin_offset),
  .phy_reg_ebuf_depth_cntrl         (phy_reg_ebuf_depth_cntrl),
  .phy_reg_rxpolarity               (phy_reg_rxpolarity),
  .phy_reg_ebuf_mode                (phy_reg_ebuf_mode),
  .phy_reg_invalid_req              (phy_reg_invalid_req),
  .phy_reg_rxeqinprogress           (phy_reg_rxeqinprogress),
  .phy_reg_rxeqeval                 (phy_reg_rxeqeval),
  .phy_reg_ebuf_upd_freq            (phy_reg_ebuf_upd_freq),
  .phy_reg_ebuf_rst_control         (phy_reg_ebuf_rst_control),
  .phy_reg_blockaligncontrol        (phy_reg_blockaligncontrol),
  .phy_reg_txdeemph                 (phy_reg_txdeemph),
  .phy_reg_getlocal_pset_coef       (phy_reg_getlocal_pset_coef),
  .phy_reg_local_pset_index         (phy_reg_local_pset_index),
  .phy_reg_fs                       (phy_reg_fs),
  .phy_reg_lf                       (phy_reg_lf),
  .phy_reg_txswing                  (phy_reg_txswing),
  .phy_reg_txmargin                 (phy_reg_txmargin),
  .phy_reg_encodedecodebypass       (phy_reg_encodedecodebypass),
  .phy_reg_esm_data_rate0           (phy_reg_esm_data_rate0),
  .phy_reg_esm_data_rate1           (phy_reg_esm_data_rate1),
  .phy_reg_esm_calibrt_req          (phy_reg_esm_calibrt_req),
  .phy_reg_esm_enable               (phy_reg_esm_enable)
);


endmodule // DWC_pcie_ghpy_regbus_cont
