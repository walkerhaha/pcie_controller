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
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/phy_tb_ctl.sv#20 $
// -------------------------------------------------------------------------
// --- Description: VTB will use this SV interface to control some aspects 
// --- of the PHY being tested like link adaptive equalization.
// ----------------------------------------------------------------------------

interface phy_tb_ctl
#(
     parameter NL             = 8,
     parameter VPT_NUM        = 1,
     // constants
     parameter TX_COEF_WD     = 18,
     parameter DIRFEEDBACK_WD = 6,
     parameter FOMFEEDBACK_WD = 8,
     parameter TX_FS_WD       = 6
)
( //pin inout
input     pclk,
input     phy_rst_n,
input     phy_reg_clk_g,

output reg [NL-1:0]                set_eq_feedback_delay,
output reg [(NL*32)-1:0]           eq_feedback_delay,
output reg [NL-1:0]                set_eq_dirfeedback,
output reg [NL*DIRFEEDBACK_WD-1:0] eq_dirfeedback_value,
output reg [NL-1:0]                set_eq_fomfeedback,
output reg [NL*FOMFEEDBACK_WD-1:0] eq_fomfeedback_value,
output reg [NL-1:0]                set_localfs_g3,
output reg [NL*TX_FS_WD-1:0]       localfs_value_g3,
output reg [NL-1:0]                set_localfs_g4,
output reg [NL*TX_FS_WD-1:0]       localfs_value_g4,
output reg [NL-1:0]                set_localfs_g5,
output reg [NL*TX_FS_WD-1:0]       localfs_value_g5,
output reg [NL-1:0]                set_locallf_g3,
output reg [NL*TX_FS_WD-1:0]       locallf_value_g3,
output reg [NL-1:0]                set_locallf_g4,
output reg [NL*TX_FS_WD-1:0]       locallf_value_g4,
output reg [NL-1:0]                set_locallf_g5,
output reg [NL*TX_FS_WD-1:0]       locallf_value_g5,
output reg [NL-1:0]                set_local_tx_pset_coef_delay,
output integer                     local_tx_pset_coef_delay,
output reg [NL-1:0]                set_local_tx_pset_coef,
output reg [NL*TX_COEF_WD-1:0]     local_tx_pset_coef_value,
output reg [NL-1:0]                set_rxadaption,
output reg                         rate_random_phystatus_en,
output reg                         powerdown_random_phystatus_en,
output reg                         p1_phystatus_time_load_en,
output reg [12:0]                  p1_phystatus_time,
output reg                         p2_phystatus_rise_random_en,    
output reg                         p2_random_phystatus_rise_load_en,
output reg [12:0]                  p2_random_phystatus_rise_value, 
output reg                         p2_phystatus_fall_random_en,   
output reg                         p2_random_phystatus_fall_load_en,
output reg [12:0]                  p2_random_phystatus_fall_value, 
output reg                         pclkack_off_time_load_en,
output reg [30:0]                  pclkack_off_time,  
output reg                         pclkack_on_time_load_en,
output reg [30:0]                  pclkack_on_time,
output reg                         syncheader_random_en,
output reg                         disable_skp_addrm_en,
output reg                         rxsymclk_random_drift_en,
output reg  [VPT_NUM*2-1:0]        phy_cr_respond_time,
output reg                         phy_cr_rd_data_load_en,
output reg  [15:0]                 phy_cr_rd_data_return_value,
// For RxDataValid with Elastic Buffer Mode=1
output reg                         rxdatavalid_shift_en,
output reg [3:0]                   fixed_rxdatavalid_shift_cycle,
output reg                         P1X_to_P1_exit_mode, 

output reg                         cdr_fast_lock, 

// For Margining at Receiver
output reg                         random_margin_status_en,
output reg [7:0]                   fixed_margin_status_thr,
output reg [NL-1:0]                set_p2m_messagebus,
output reg [NL*8-1:0]              p2m_messagebus_command_value,
output reg [NL-1:0]                set_m2p_messagebus,
output reg [NL*8-1:0]              m2p_messagebus_command_value,
output reg                         VoltageSupported,
output reg                         IndErrorSampler,
output reg [6:0]                   MaxVoltageOffset,
output reg [5:0]                   MaxTimingOffset,
output reg [6:0]                   UnsupportedVoltageOffset,
output reg                         SampleReportingMethod,
output reg [NL*2-1:0]              margin_error_cnt_mode,
output reg [NL*32-1:0]             margin_cycle_for_an_error,
output reg [NL*4-1:0]              margin_bit_error_rate_factor,
output reg [NL*2-1:0]              set_margin_cnt,
output reg [NL*7-1:0]              margin_sampl_cnt_to_set,
output reg [NL*6-1:0]              margin_error_cnt_to_set,
// For CCIX ESM Calibration
output reg                         random_calibrt_complete_en,
output reg [7:0]                   fixed_calibrt_complete_thr,
output reg                         calibration_complete_en,
// For LowPinCount
output reg [NL*3-1:0]              update_localfslf_mode,
output reg [31:0]                  pclk_per_ps
); //pin inout

reg [2:0] localfslf_mode;
// initialize outputs
initial begin
  set_eq_feedback_delay         = 0;
  eq_feedback_delay             = 0;
  set_eq_dirfeedback            = 0;
  eq_dirfeedback_value          = 0;
  set_eq_fomfeedback            = 0;
  eq_fomfeedback_value          = 0;
  set_localfs_g3                = 0;
  localfs_value_g3              = 0;
  set_localfs_g4                = 0;
  localfs_value_g4              = 0;
  set_localfs_g5                = 0;
  localfs_value_g5              = 0;
  set_locallf_g3                = 0;
  locallf_value_g3              = 0;
  set_locallf_g4                = 0;
  locallf_value_g4              = 0;
  set_locallf_g5                = 0;
  locallf_value_g5              = 0;
  set_local_tx_pset_coef_delay  = 0;
  local_tx_pset_coef_delay      = 0;
  set_local_tx_pset_coef        = 0;
  local_tx_pset_coef_value      = 0;
  set_rxadaption                = 0;
  rate_random_phystatus_en      = 1;
  powerdown_random_phystatus_en = 1;
  p1_phystatus_time_load_en     = 0;
  p1_phystatus_time             = 13'b0;  
  p2_phystatus_rise_random_en      = 1;   
  p2_random_phystatus_rise_load_en = 0; 
  p2_random_phystatus_rise_value   = 13'b0;
  p2_phystatus_fall_random_en      = 1;  
  p2_random_phystatus_fall_load_en = 0;
  p2_random_phystatus_fall_value   = 13'b0;  
  pclkack_off_time_load_en      = 0;
  pclkack_off_time              = 13'b0;
  pclkack_on_time_load_en       = 0;
  pclkack_on_time               = 13'b0;
  syncheader_random_en          = 1;  
  disable_skp_addrm_en          = 1'b0;
  rxsymclk_random_drift_en      = 1;
  phy_cr_respond_time           = 16'h5555;
  phy_cr_rd_data_load_en        = 0;
  phy_cr_rd_data_return_value   = 16'b0;
  // For RxDataValid with Elastic Buffer Mode=1
  rxdatavalid_shift_en          = 1'b0;
  fixed_rxdatavalid_shift_cycle = 4'h0;
  // For Margining at Receiver
  random_margin_status_en       = 1;
  fixed_margin_status_thr       = 8;
  set_p2m_messagebus            = 0;
  p2m_messagebus_command_value  = 0;
  set_m2p_messagebus            = 0;
  m2p_messagebus_command_value  = 0;
  VoltageSupported              = 1;
  IndErrorSampler               = 1;
  MaxVoltageOffset              = {7{1'b1}};
  MaxTimingOffset               = {6{1'b1}};
  UnsupportedVoltageOffset      = {7{1'b1}};
  SampleReportingMethod         = 0;
  margin_error_cnt_mode         = {NL{`GPHY_BER_MODE}};
  margin_cycle_for_an_error     = 0;
  margin_bit_error_rate_factor  = {NL{4'd15}};
  set_margin_cnt                = 0;
  margin_sampl_cnt_to_set       = 0;
  margin_error_cnt_to_set       = 0;
  P1X_to_P1_exit_mode           = 0;
  // For CCIX ESM Calibration
  random_calibrt_complete_en    = 1;
  fixed_calibrt_complete_thr    = 8;
  calibration_complete_en       = 1;
  // For LowPinCount 
  `ifdef GPHY_GEN3_EQ_PSET_COEF_MAP_MODE_PHY  
     localfslf_mode = $urandom_range(1,7);  
  `else  
     localfslf_mode[2]   = 1'b0;
     localfslf_mode[1:0] = $urandom_range(1,3);  
  `endif    
    
   for (int i=0; i<NL; i++)
     update_localfslf_mode[i*3+:3] = localfslf_mode; 
     
  cdr_fast_lock                 = 0;
  // DUt-VIP in Pipe-pipe mode
  pclk_per_ps                   = 32'd4000;
end

// fields that specify what control tasks are supported by current PHY
// variables to use from tests
reg support_set_eq_feedback_delay_cmd        = 1;
reg support_set_eq_dirfeedback_cmd           = 1;
reg support_set_eq_fomfeedback_cmd           = 1;
reg support_set_localfs_cmd                  = 1;
reg support_set_locallf_cmd                  = 1;
reg support_set_local_tx_pset_coef_delay_cmd = 1;
reg support_set_local_tx_pset_coef_cmd       = 1;
reg support_set_rxadaption_required          = 1;
reg support_set_p1_phystatus_time            = 1;
reg support_set_pclkack_off_time             = 1;
reg support_set_pclkack_on_time              = 1;
reg support_set_rate_random_phystatus        = 1;
reg support_set_powerdown_random_phystatus   = 1;
reg support_set_p2_phystatus_rise_random_en       = 1;   
reg support_set_p2_random_phystatus_rise_load_en  = 1; 
reg support_set_p2_random_phystatus_rise_value    = 1;
reg support_set_p2_phystatus_fall_random_en       = 1;   
reg support_set_p2_random_phystatus_fall_load_en  = 1; 
reg support_set_p2_random_phystatus_fall_value    = 1;
reg support_set_syncheader_random            = 1;
reg support_set_disable_skp_addrm_en         = 1;
reg support_set_rxsymclk_random_drift_en     = 1;
reg support_set_phy_cr_respond_time          = 1;
reg support_set_phy_cr_rd_data_load_en       = 1;
reg support_set_rxdatavalid_shift_mode       = 1;
reg support_set_random_margin_status         = 1;
reg support_set_VoltageSupported             = 1;
reg support_set_IndErrorSampler              = 1;
reg support_set_MaxVoltageOffset             = 1;
reg support_set_MaxTimingOffset              = 1;
reg support_set_UnsupportedVoltageOffset     = 1;
reg support_set_SampleReportingMethod        = 1;
reg support_set_margin_sampl_cnt             = 1;
reg support_set_margin_error_cnt             = 1;
reg support_set_margin_error_cnt_mode        = 1;
reg support_set_margin_error_period          = 1;
reg support_set_margin_bit_error_rate        = 1;
reg support_set_p2m_messagebus_command       = 1;
reg support_set_m2p_messagebus_command       = 1;
reg support_set_P1X_to_P1_exit_mode          = 1;
reg support_set_random_calibrt_complete      = 1;
reg support_set_calibration_complete_en      = 1;
reg support_set_update_localfslf_mode        = 1;
reg support_set_cdr_fast_lock                = 1;
reg support_set_ideal_mode                   = 1;

// task to enable/disable calibration complete respons
// 1 - enable calibration compelte response
// 0 - disable calibration compelte response
task automatic set_calibration_complete_en(bit value);
  @ (posedge pclk);
  calibration_complete_en  <= value; 
endtask: set_calibration_complete_en


// task to set P1X_to_P1 exit mode
// 0 - normal mode
// 1 - as P2 exit mode
task automatic set_P1X_to_P1_exit_mode(bit value);
  @ (posedge pclk);
  P1X_to_P1_exit_mode  <= value; 
endtask: set_P1X_to_P1_exit_mode

// task to set phy viewport respond time
// 0 - quick
// 1 - normal
// 2 - slow
// 3 - timeout
task automatic set_phy_cr_respond_time(int phy_num, bit [1:0] value);
  @ (posedge phy_reg_clk_g);
  phy_cr_respond_time[phy_num*2 +: 2 ]  <= value; 
endtask: set_phy_cr_respond_time

// task to set read value to be returned  by the phy
// 1 - set value
// 0 - random
task automatic set_phy_cr_rd_data_load_en(bit en, bit[15:0] value);
  @ (posedge phy_reg_clk_g);
  phy_cr_rd_data_load_en         <= en; 
  phy_cr_rd_data_return_value    <= value; 
endtask: set_phy_cr_rd_data_load_en

// task to enable/disable rxsymclk random drift
// 1 - enable
// 0 - disable
task automatic set_rxsymclk_random_drift(bit en);
  @ (posedge pclk);
  rxsymclk_random_drift_en  <= en; 
endtask: set_rxsymclk_random_drift



// task to enable/disable random generation of syncheader when StartBlock it is 0
// 1 - enable
// 0 - disable
task automatic set_syncheader_random(bit en);
  @ (posedge pclk);
  syncheader_random_en  <= en; 
endtask: set_syncheader_random


// task to enable/disable skip add/remove
// 1 - enable
// 0 - disable
task automatic set_disable_skp_addrm_en(bit en);
  @ (posedge pclk);
  disable_skp_addrm_en  <= en; 
endtask: set_disable_skp_addrm_en


// task to enable/disable fixed value for  generation of phystatus in p1
// 1 - enable
// 0 - disable
task automatic set_p1_phystatus_time(bit en, bit[12:0] value);
  @ (posedge pclk);
  p1_phystatus_time_load_en <= en; 
  p1_phystatus_time         <= value; 
endtask: set_p1_phystatus_time

// task to set a fixed value for generation of pclkack_n 
// 1 - load
// 0 - disable
task automatic set_pclkack_off_time(bit en, bit[30:0] value);
  @ (posedge pclk);
  pclkack_off_time_load_en       <= en; 
  pclkack_off_time               <= value; 
endtask: set_pclkack_off_time

// task to set a fixed value to restore pclkack_n
// 1 - load
// 0 - disable
task automatic set_pclkack_on_time(bit en, bit[30:0] value);
  @ (posedge pclk);
  pclkack_on_time_load_en       <= en; 
  pclkack_on_time               <= value; 
endtask: set_pclkack_on_time


// task to enable/disable random delay for phystatus assertion at p2 entry
// 1 - enable
// 0 - disable
task automatic set_random_phystatus_rise_p2_entry(bit en);
  @ (posedge pclk);
  p2_phystatus_rise_random_en  <= en; 
endtask: set_random_phystatus_rise_p2_entry

// task to enable/disable random delay for phystatus assertion at p2 entry
// 1 - enable
// 0 - disable
task automatic set_random_phystatus_fall_p2_entry(bit en);
  @ (posedge pclk);
  p2_phystatus_fall_random_en  <= en; 
endtask: set_random_phystatus_fall_p2_entry


// task to enable/disable fixed value for phystatus assertion in p2
// 1 - enable
// 0 - disable
task automatic set_p2_phystatus_rise_time(bit en, bit[12:0] value);
  @ (posedge pclk);
  p2_random_phystatus_rise_load_en <= en; 
  p2_random_phystatus_rise_value   <= value; 
endtask: set_p2_phystatus_rise_time

// task to enable/disable fixed value for phystatus deassertion in p2
// 1 - enable
// 0 - disable
task automatic set_p2_phystatus_fall_time(bit en, bit[12:0] value);
  @ (posedge pclk);
 p2_random_phystatus_fall_load_en <= en; 
 p2_random_phystatus_fall_value   <= value; 
endtask: set_p2_phystatus_fall_time

// task to enable/disable random delay for phystatus at powerdown change
// 1 - enable
// 0 - disable
task automatic set_powerdown_random_phystatus(bit en);
  @ (posedge pclk);
  powerdown_random_phystatus_en  <= en; 
endtask: set_powerdown_random_phystatus


// task to enable/disable random delay for phystatus at rate change
// 1 - enable
// 0 - disable
task automatic set_rate_random_phystatus(bit en);
  @ (posedge pclk);
  rate_random_phystatus_en  <= en; 
endtask: set_rate_random_phystatus


// Set specific feedback response delay in nanoseconds.
task automatic set_eq_feedback_delay_cmd(int lane_no, integer eq_feedback_delay_param);
//  $display("%0t %m: set_eq_feedback_delay_cmd lane_no=%0d, localfs_value_param=%0x",$time, lane_no, eq_feedback_delay_param  );
  @ (posedge pclk);
  set_eq_feedback_delay[lane_no] <= 1;
  eq_feedback_delay[ lane_no*32 +: 32 ]     <= eq_feedback_delay_param;
  @ (posedge pclk); 
  set_eq_feedback_delay[lane_no] <= 0;
endtask : set_eq_feedback_delay_cmd

// Set specific dir feedback response 
task automatic set_eq_dirfeedback_cmd(int lane_no, bit[DIRFEEDBACK_WD-1:0] eq_dirfeedback_value_param);
  @ (posedge pclk);
  set_eq_dirfeedback[lane_no]   <= 1;
  eq_dirfeedback_value[lane_no*DIRFEEDBACK_WD +: DIRFEEDBACK_WD] <= eq_dirfeedback_value_param;
  @ (posedge pclk); 
  set_eq_dirfeedback[lane_no]   <= 0;
endtask : set_eq_dirfeedback_cmd

// Set specific fom feedback response 
task automatic set_eq_fomfeedback_cmd(int lane_no, bit[FOMFEEDBACK_WD-1:0] eq_fomfeedback_value_param);
  @ (posedge pclk);
  set_eq_fomfeedback[lane_no]   <= 1;
  eq_fomfeedback_value[ lane_no*FOMFEEDBACK_WD +: FOMFEEDBACK_WD] <= eq_fomfeedback_value_param;
  @ (posedge pclk); 
  set_eq_fomfeedback[lane_no]   <= 0;
endtask : set_eq_fomfeedback_cmd

// Set specific local FS response 
// rate encoding: 3=GEN3, 4=GEN4, 5=GEN5
task automatic set_localfs_cmd(int lane_no, bit[TX_FS_WD-1:0] localfs_value_param, bit[3:0] localfs_rate_param);
  @ (posedge pclk);
  if (localfs_rate_param == 3) begin
    set_localfs_g3[lane_no]   <= 1;
    localfs_value_g3[lane_no*TX_FS_WD +: TX_FS_WD] <= localfs_value_param;
  end else if (localfs_rate_param == 4) begin
    set_localfs_g4[lane_no]   <= 1;
    localfs_value_g4[lane_no*TX_FS_WD +: TX_FS_WD] <= localfs_value_param;
  end else if (localfs_rate_param == 5) begin
    set_localfs_g5[lane_no]   <= 1;
    localfs_value_g5[lane_no*TX_FS_WD +: TX_FS_WD] <= localfs_value_param;
  end 
  @ (posedge pclk); 
  if      (localfs_rate_param == 3) set_localfs_g3[lane_no]   <= 0;
  else if (localfs_rate_param == 4) set_localfs_g4[lane_no]   <= 0;
  else if (localfs_rate_param == 5) set_localfs_g5[lane_no]   <= 0;
endtask : set_localfs_cmd

// Set specific local LF response 
// rate encoding: 3=GEN3, 4=GEN4, 5=GEN5
task automatic set_locallf_cmd(int lane_no, bit[TX_FS_WD-1:0] locallf_value_param, bit[3:0] locallf_rate_param);
  @ (posedge pclk);
  if (locallf_rate_param == 3) begin
    set_locallf_g3[lane_no]   <= 1;
    locallf_value_g3[lane_no*TX_FS_WD +:TX_FS_WD ] <= locallf_value_param;
  end else if (locallf_rate_param == 4) begin
    set_locallf_g4[lane_no]   <= 1;
    locallf_value_g4[lane_no*TX_FS_WD +:TX_FS_WD ] <= locallf_value_param;
  end else if (locallf_rate_param == 5) begin
    set_locallf_g5[lane_no]   <= 1;
    locallf_value_g5[lane_no*TX_FS_WD +:TX_FS_WD ] <= locallf_value_param;
  end
  @ (posedge pclk); 
  if      (locallf_rate_param == 3) set_locallf_g3[lane_no]   <= 0;
  else if (locallf_rate_param == 4) set_locallf_g4[lane_no]   <= 0;
  else if (locallf_rate_param == 5) set_locallf_g5[lane_no]   <= 0;
endtask : set_locallf_cmd

// Set specific local_tx_pset_coef response delay 
task automatic set_local_tx_pset_coef_delay_cmd(int lane_no, integer local_tx_pset_coef_delay_param);
  @ (posedge pclk);
  set_local_tx_pset_coef_delay <= 1<<lane_no;
  local_tx_pset_coef_delay     <= local_tx_pset_coef_delay_param;
  @ (posedge pclk); 
  set_local_tx_pset_coef_delay <= 0;
endtask : set_local_tx_pset_coef_delay_cmd

// Set specific local_tx_pset_coef response 
task automatic set_local_tx_pset_coef_cmd(int lane_no, bit[TX_COEF_WD-1:0] local_tx_pset_coef_value_param);
  @ (posedge pclk);
  set_local_tx_pset_coef[lane_no]   <= 1;
  local_tx_pset_coef_value[lane_no*TX_COEF_WD +:TX_COEF_WD ] <= local_tx_pset_coef_value_param;
  @ (posedge pclk); 
  set_local_tx_pset_coef[lane_no]   <= 0;
endtask : set_local_tx_pset_coef_cmd

task automatic set_rxadaption_required(int lane_no,bit rxadaption);
  @ (posedge pclk);
  set_rxadaption[lane_no]   <= rxadaption;
  @ (posedge pclk); 
  set_rxadaption[lane_no]   <= 0;
endtask: set_rxadaption_required


//////////////////////////////////////////////////
// For RxDataValid with Elastic Buffer Mode=1
//////////////////////////////////////////////////
// task to shift the RxDataValid=0 Timing during Elastic Buffer Mode=1
// 1 - enable (default)
// 0 - disable
// This signal it is used to control the fixed RxDataValid=0 Timing during Elastic Buffer Mode=0
// 0    - random
// else - fixed
task automatic set_rxdatavalid_shift_mode(bit shift_en, bit [3:0] fixed_cycle=4'h0);
  @ (posedge pclk);
  rxdatavalid_shift_en           <= shift_en; 
  fixed_rxdatavalid_shift_cycle  <= fixed_cycle;
endtask: set_rxdatavalid_shift_mode

//////////////////////////////////////////////////
// For Margining at Receiver
//////////////////////////////////////////////////
// task to enable/disable random delay for margin_status
// 1 - enable
// 0 - disable
task automatic set_random_margin_status(bit en, bit [7:0] thr=8'h08);
  @ (posedge pclk);
  random_margin_status_en  <= en; 
  fixed_margin_status_thr  <= thr;
endtask: set_random_margin_status

// task to set M(VoltageSupported)
// 1 - indicates that voltage margining is supported
// 0 - indicates that voltage margining is not supported
task automatic set_VoltageSupported(bit value);
  @ (posedge pclk);
  VoltageSupported <= value;
endtask : set_VoltageSupported

// task to set M(IndErrorSampler)
// 1 - Margining will not produce errors (change in the error rate) in data stream (ie. . error sampler is independent)
// 0 - Margining may produce errors in the data stream
task automatic set_IndErrorSampler(bit value);
  @ (posedge pclk);
  IndErrorSampler <= value;
endtask : set_IndErrorSampler

// task to set M(MaxVoltageOffset)
// Offset from default at maximum step value as percentage of a nominal UI at 16.0 GT/s
// A 0 value may be reported if the vendor chooses not to report the offset
task automatic set_MaxVoltageOffset(bit[6:0] value);
  @ (posedge pclk);
  MaxVoltageOffset <= value;
endtask : set_MaxVoltageOffset

// task to set M(MaxTimingOffset)
// Offset from default at maximum step value as percentage of one volt
// A 0 value may be reported if the vendor chooses not to report the offset when M(VoltageSupported) is 1b
// This value will not be used if M(VoltageSupported) is 0b
task automatic set_MaxTimingOffset(bit[5:0] value);
  @ (posedge pclk);
  MaxTimingOffset <= value;
endtask : set_MaxTimingOffset



// task to set M(UnsupportedVoltageOffset)
// Unsupported value of VoltageOffset from the advertised range
task automatic set_UnsupportedVoltageOffset(bit[6:0] value);
  @ (posedge pclk);
  UnsupportedVoltageOffset <= value;
endtask : set_UnsupportedVoltageOffset



// task to set M(SampleReportingMethod)
// 1 - sampling rates ( M(SamplingRateVoltage) and M(SamplingRateTiming) ) are supported
// 0 - a sample count is supported
task automatic set_SampleReportingMethod(bit value);
  @ (posedge pclk);
  SampleReportingMethod <= value;
endtask : set_SampleReportingMethod

// task to set Sample Count
task automatic set_margin_sampl_cnt(int lane_no, bit[6:0] value);
begin
  @ (posedge pclk);
  set_margin_cnt[lane_no*2+1]           <= 1'b1;
  margin_sampl_cnt_to_set[lane_no*7+:7] <= value;
  @ (posedge pclk);
  set_margin_cnt[lane_no*2+1]           <= 1'b0;
end
endtask : set_margin_sampl_cnt

// task to set Error Count
task automatic set_margin_error_cnt(int lane_no, bit[5:0] value);
begin
  @ (posedge pclk);
  set_margin_cnt[lane_no*2]             <= 1'b1;
  margin_error_cnt_to_set[lane_no*6+:6] <= value;
  @ (posedge pclk);
  set_margin_cnt[lane_no*2]             <= 1'b0;
end
endtask : set_margin_error_cnt

// task to set Error Count Mode
// 00b - Fixed Value Mode
// 01b - Periodical Increment Mode
// 10b - Bit Error Rate Modeling Mode
// 11b - Reserved
task automatic set_margin_error_cnt_mode(int lane_no, bit[1:0] value);
  @ (posedge pclk);
  margin_error_cnt_mode[lane_no*2+:2] <= value;
endtask : set_margin_error_cnt_mode

// task to set Error Period
task automatic set_margin_error_period(int lane_no, bit[31:0] value);
  @ (posedge pclk);
  margin_error_cnt_mode[lane_no*2+:2]       <= `GPHY_PERIOD_MODE;
  margin_cycle_for_an_error[lane_no*32+:32] <= value;
endtask : set_margin_error_period

// task to set Bit Error Rate
task automatic set_margin_bit_error_rate(int lane_no, bit[3:0] value);
  @ (posedge pclk);
  margin_error_cnt_mode[lane_no*2+:2]        <= `GPHY_BER_MODE;
  margin_bit_error_rate_factor[lane_no*4+:4] <= value;
endtask : set_margin_bit_error_rate

// task to insert command into p2m_messagebus
task automatic set_p2m_messagebus_command(int lane_no, bit[3:0] command, bit[11:0] address, bit[7:0] data);
  set_p2m_messagebus[lane_no] <= 1;
  if(command==`GPHY_CMD_WR_UC || command==`GPHY_CMD_WR_C) begin
      p2m_messagebus_command_value[lane_no*8+:8] <= {command, address[11:8]};
      @ (posedge pclk);
      p2m_messagebus_command_value[lane_no*8+:8] <= {address[7:0]};
      @ (posedge pclk);
      p2m_messagebus_command_value[lane_no*8+:8] <= {data[7:0]};
  end
  if(command==`GPHY_CMD_RD) begin
      p2m_messagebus_command_value[lane_no*8+:8] <= {command, address[11:8]};
      @ (posedge pclk);
      p2m_messagebus_command_value[lane_no*8+:8] <= {address[7:0]};
  end
  if(command==`GPHY_CMD_RD_CPL ) begin
      p2m_messagebus_command_value[lane_no*8+:8] <= {command, 4'b0000};
      @ (posedge pclk);
      p2m_messagebus_command_value[lane_no*8+:8] <= {data[7:0]};
  end
  if(command==`GPHY_CMD_NOP || command==`GPHY_CMD_WR_ACK) begin
      p2m_messagebus_command_value[lane_no*8+:8] <= {command, 4'b0000};
  end
  @ (posedge pclk);
  p2m_messagebus_command_value[lane_no*8+:8] <= {`GPHY_CMD_NOP, 4'b0000};
  set_p2m_messagebus[lane_no] <= 0;
endtask: set_p2m_messagebus_command

// task to insert command into m2p_messagebus
task automatic set_m2p_messagebus_command(int lane_no, bit[3:0] command, bit[11:0] address, bit[7:0] data);
  set_m2p_messagebus[lane_no] <= 1;
  if(command==`GPHY_CMD_WR_UC || command==`GPHY_CMD_WR_C) begin
      m2p_messagebus_command_value[lane_no*8+:8] <= {command, address[11:8]};
      @ (posedge pclk);
      m2p_messagebus_command_value[lane_no*8+:8] <= {address[7:0]};
      @ (posedge pclk);
      m2p_messagebus_command_value[lane_no*8+:8] <= {data[7:0]};
  end
  if(command==`GPHY_CMD_RD) begin
      m2p_messagebus_command_value[lane_no*8+:8] <= {command, address[11:8]};
      @ (posedge pclk);
      m2p_messagebus_command_value[lane_no*8+:8] <= {address[7:0]};
  end
  if(command==`GPHY_CMD_RD_CPL ) begin
      m2p_messagebus_command_value[lane_no*8+:8] <= {command, 4'b0000};
      @ (posedge pclk);
      m2p_messagebus_command_value[lane_no*8+:8] <= {data[7:0]};
  end
  if(command==`GPHY_CMD_NOP || command==`GPHY_CMD_WR_ACK) begin
      m2p_messagebus_command_value[lane_no*8+:8] <= {command, 4'b0000};
  end
  @ (posedge pclk);
  m2p_messagebus_command_value[lane_no*8+:8] <= {`GPHY_CMD_NOP, 4'b0000};
  set_m2p_messagebus[lane_no] <= 0;
endtask: set_m2p_messagebus_command

// For backward compatibility
task automatic set_pbus_command(int lane_no, bit[3:0] command, bit[11:0] address, bit[7:0] data);
  set_p2m_messagebus_command(lane_no, command, address, data);
endtask: set_pbus_command
task automatic set_mbus_command(int lane_no, bit[3:0] command, bit[11:0] address, bit[7:0] data);
  set_m2p_messagebus_command(lane_no, command, address, data);
endtask: set_mbus_command

//////////////////////////////////////////////////
// For CCIX ESM Calibration
//////////////////////////////////////////////////
// task to enable/disable random delay for calibrt_complete
// 1 - enable
// 0 - disable
task automatic set_random_calibrt_complete(bit en, bit [7:0] thr=8'h08);
  @ (posedge pclk);
  random_calibrt_complete_en <= en; 
  fixed_calibrt_complete_thr <= thr;
endtask: set_random_calibrt_complete

//////////////////////////////////////////////////
// For LowPinCount
//////////////////////////////////////////////////
// task to set FS/LF update mode
// Bit[0] : behavior for reset sequence
//   1b - All Rate
//   0b - G3 only
// Bit[1] : behavior for rate change sequence
//   1b - On
//   0b - Off
// Bit[2] : behavior for getlocal
//   1b - On
//   0b - Off
task automatic set_update_localfslf_mode(int lane_no, bit[2:0] value);
  @ (posedge pclk);
  update_localfslf_mode[lane_no*3+:3] <= value;
endtask : set_update_localfslf_mode

// task to enable/disable Ideal mode in the PHY
// 1 - enable Ideal
// 0 - disable Ideal
task automatic set_ideal_mode(bit value);
  support_set_rate_random_phystatus        = ~value;
  support_set_powerdown_random_phystatus   = ~value;
  support_set_syncheader_random            = ~value;
  support_set_disable_skp_addrm_en         = ~value;
  support_set_rxsymclk_random_drift_en     = ~value;
  support_set_rxdatavalid_shift_mode       = ~value;
  support_set_P1X_to_P1_exit_mode          = ~value;
  support_set_random_calibrt_complete      = ~value;
  //-
  set_rate_random_phystatus(~value);
  set_powerdown_random_phystatus(~value);
  set_syncheader_random(~value);
  set_disable_skp_addrm_en(value);
  set_rxsymclk_random_drift(~value);
  set_rxdatavalid_shift_mode(~value);
  set_P1X_to_P1_exit_mode(~value);
  set_random_calibrt_complete(value);
endtask: set_ideal_mode

// task to enable/disable CDR fast lock
// 1 - enable CDR fast lock
// 0 - disable CDR fast lock
task automatic set_cdr_fast_lock(bit value);
  @ (posedge pclk);
  cdr_fast_lock  <= value; 
endtask: set_cdr_fast_lock

task automatic set_pclk_per_ps(bit[31:0] clk_per_ps);
  @ (posedge pclk)
  pclk_per_ps <= clk_per_ps;
endtask : set_pclk_per_ps

endinterface //phy_tb_ctl
