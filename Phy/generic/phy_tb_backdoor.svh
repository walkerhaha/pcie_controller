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
// ---    $DateTime: 2020/10/15 11:18:46 $
// ---    $Revision: #29 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/phy_tb_backdoor.svh#29 $
// -------------------------------------------------------------------------
// Description: Backdoor access for the PCIe IIP TB when simulating with the
// generic PHY.
// -----------------------------------------------------------------------------
`ifdef VIP_MODE_IS_SPIPE
// Generic Phy Control Interface instance is always required for the UTB
// testbench and must be in both the DUT and VDUT devices.
// Other TBs only require this instance in the DUT device
`ifdef UTB
  `define CREATE_PHY_TB_CTRL
`else
  `ifndef DEVICE_IS_VDUT
    `define CREATE_PHY_TB_CTRL
  `endif
`endif

`ifdef CREATE_PHY_TB_CTRL
  // Generic Phy Control Interface
  phy_tb_ctl
  #(.NL(NL),
    .VPT_NUM(`CX_PHY_NUM_MACROS)
   ) u_phy_tb_ctl (
    .pclk                           (`PHY0.u_phy_vmain_top.int_pclk[0]),
    .phy_rst_n                      (`PHY0.phy_rst_n)
    );
`endif

`else

// --------------------------------------------------------
// Force receiver detection result in the PHY
// --------------------------------------------------------
always @( rxpresent ) begin: force_rxdetect_proc
  $display("%m %t : Forcing receiver detection in Generic PHY with mask %0b", $time, rxpresent);
`ifdef CX_NL_GTR_8
  force `PHY0.u_phy_vmain_top.u_pma.genpma[15].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[15];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[14].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[14];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[13].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[13];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[12].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[12];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[11].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[11];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[10].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[10];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 9].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 9];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 8].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 8];
`endif // CX_NL_GTR_8

`ifdef CX_NL_GTR_4
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 7].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 7];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 6].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 6];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 5].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 5];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 4].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 4];
`endif // CX_NL_GTR_4

`ifdef CX_NL_GTR_2
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 3].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 3];
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 2].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 2];
`endif // CX_NL_GTR_2

`ifdef CX_NL_GTR_1
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 1].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 1];
`endif // CX_NL_GTR_1
  force `PHY0.u_phy_vmain_top.u_pma.genpma[ 0].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 0];

end


// Generic Phy Control Interface instance is always required for the UTB
// testbench and must be in both the DUT and VDUT devices.
// Other TBs only require this instance in the DUT device
`ifdef UTB
  `define CREATE_PHY_TB_CTRL
`else
  `ifndef DEVICE_IS_VDUT
    `define CREATE_PHY_TB_CTRL
  `endif
`endif

`ifdef CREATE_PHY_TB_CTRL
  // Generic Phy Control Interface
  phy_tb_ctl
  #(.NL(NL),
    .VPT_NUM(`CX_PHY_NUM_MACROS),
    .TX_COEF_WD(TX_COEF_WD),
    .DIRFEEDBACK_WD(DIRFEEDBACK_WD),
    .FOMFEEDBACK_WD(FOMFEEDBACK_WD),
    .TX_FS_WD(FS_LF_WD)
   ) u_phy_tb_ctl (
    .pclk                           (`PHY0.u_phy_vmain_top.int_pclk[0]),
    .phy_rst_n                      (`PHY0.phy_rst_n),
    .phy_reg_clk_g                  (`PHY0.phy_reg_clk_g),
    .set_eq_feedback_delay          (`PHY0.u_phy_vmain_top.set_eq_feedback_delay), 
    .eq_feedback_delay              (`PHY0.u_phy_vmain_top.eq_feedback_delay), 
    .set_eq_dirfeedback             (`PHY0.u_phy_vmain_top.set_eq_dirfeedback),
    .eq_dirfeedback_value           (`PHY0.u_phy_vmain_top.eq_dirfeedback_value),   
    .set_eq_fomfeedback             (`PHY0.u_phy_vmain_top.set_eq_fomfeedback),
    .eq_fomfeedback_value           (`PHY0.u_phy_vmain_top.eq_fomfeedback_value),
    .set_localfs_g3                 (`PHY0.u_phy_vmain_top.set_localfs_g3),
    .localfs_value_g3               (`PHY0.u_phy_vmain_top.localfs_value_g3),
    .set_localfs_g4                 (`PHY0.u_phy_vmain_top.set_localfs_g4),
    .localfs_value_g4               (`PHY0.u_phy_vmain_top.localfs_value_g4),
    .set_localfs_g5                 (`PHY0.u_phy_vmain_top.set_localfs_g5),
    .localfs_value_g5               (`PHY0.u_phy_vmain_top.localfs_value_g5),
    .set_locallf_g3                 (`PHY0.u_phy_vmain_top.set_locallf_g3),
    .locallf_value_g3               (`PHY0.u_phy_vmain_top.locallf_value_g3),
    .set_locallf_g4                 (`PHY0.u_phy_vmain_top.set_locallf_g4),
    .locallf_value_g4               (`PHY0.u_phy_vmain_top.locallf_value_g4),
    .set_locallf_g5                 (`PHY0.u_phy_vmain_top.set_locallf_g5),
    .locallf_value_g5               (`PHY0.u_phy_vmain_top.locallf_value_g5),
    .set_local_tx_pset_coef_delay   (`PHY0.u_phy_vmain_top.set_local_tx_pset_coef_delay),
    .local_tx_pset_coef_delay       (`PHY0.u_phy_vmain_top.local_tx_pset_coef_delay),
    .set_local_tx_pset_coef         (`PHY0.u_phy_vmain_top.set_local_tx_pset_coef),
    .local_tx_pset_coef_value       (`PHY0.u_phy_vmain_top.local_tx_pset_coef_value),
    .set_rxadaption                 (`PHY0.u_phy_vmain_top.set_rxadaption ),
    .rate_random_phystatus_en       (`PHY0.rate_random_phystatus_en),
    .powerdown_random_phystatus_en  (`PHY0.powerdown_random_phystatus_en),
    .syncheader_random_en           (`PHY0.syncheader_random_en),
    .disable_skp_addrm_en           (`PHY0.disable_skp_addrm_en),
    .p1_phystatus_time_load_en      (`PHY0.p1_phystatus_time_load_en),
    .p1_phystatus_time              (`PHY0.p1_phystatus_time),    
    .p2_phystatus_rise_random_en      (`PHY0.p2_phystatus_rise_random_en),
    .p2_random_phystatus_rise_load_en (`PHY0.p2_random_phystatus_rise_load_en),
    .p2_random_phystatus_rise_value   (`PHY0.p2_random_phystatus_rise_value),
    .p2_phystatus_fall_random_en      (`PHY0.p2_phystatus_fall_random_en),
    .p2_random_phystatus_fall_load_en (`PHY0.p2_random_phystatus_fall_load_en),
    .p2_random_phystatus_fall_value   (`PHY0.p2_random_phystatus_fall_value),  
    .pclkack_off_time_load_en       (`PHY0.pclkack_off_time_load_en),
    .pclkack_off_time               (`PHY0.pclkack_off_time),
    .pclkack_on_time_load_en        (`PHY0.pclkack_on_time_load_en),
    .pclkack_on_time                (`PHY0.pclkack_on_time),
    .rxsymclk_random_drift_en       (`PHY0.rxsymclk_random_drift_en),
    .phy_cr_respond_time            (`PHY0.phy_cr_respond_time),        
    .phy_cr_rd_data_load_en         (`PHY0.phy_cr_rd_data_load_en), 
    .phy_cr_rd_data_return_value    (`PHY0.phy_cr_rd_data_return_value),
    // For RxDataValid with Elastic Buffer Mode=1
    .rxdatavalid_shift_en           (`PHY0.rxdatavalid_shift_en),
    .fixed_rxdatavalid_shift_cycle  (`PHY0.fixed_rxdatavalid_shift_cycle),
    .P1X_to_P1_exit_mode            (`PHY0.P1X_to_P1_exit_mode),
    .cdr_fast_lock                  (`PHY0.cdr_fast_lock),
    // For Margining at Receiver
    .random_margin_status_en        (`PHY0.random_margin_status_en),
    .fixed_margin_status_thr        (`PHY0.fixed_margin_status_thr),
    .set_p2m_messagebus             (`PHY0.u_phy_vmain_top.set_p2m_messagebus),
    .p2m_messagebus_command_value   (`PHY0.u_phy_vmain_top.p2m_messagebus_command_value),
    .set_m2p_messagebus             (`PHY0.u_phy_vmain_top.set_m2p_messagebus),
    .m2p_messagebus_command_value   (`PHY0.u_phy_vmain_top.m2p_messagebus_command_value),
    .VoltageSupported               (`PHY0.u_phy_vmain_top.VoltageSupported),
    .IndErrorSampler                (`PHY0.u_phy_vmain_top.IndErrorSampler),
    .MaxVoltageOffset               (`PHY0.u_phy_vmain_top.MaxVoltageOffset),
    .MaxTimingOffset                (`PHY0.u_phy_vmain_top.MaxTimingOffset),    
    .UnsupportedVoltageOffset       (`PHY0.u_phy_vmain_top.UnsupportedVoltageOffset ),        
    .SampleReportingMethod          (`PHY0.u_phy_vmain_top.SampleReportingMethod),
    .margin_error_cnt_mode          (`PHY0.u_phy_vmain_top.margin_error_cnt_mode),
    .margin_cycle_for_an_error      (`PHY0.u_phy_vmain_top.margin_cycle_for_an_error),
    .margin_bit_error_rate_factor   (`PHY0.u_phy_vmain_top.margin_bit_error_rate_factor),
    .set_margin_cnt                 (`PHY0.u_phy_vmain_top.set_margin_cnt),
    .margin_sampl_cnt_to_set        (`PHY0.u_phy_vmain_top.margin_sampl_cnt_to_set),
    .margin_error_cnt_to_set        (`PHY0.u_phy_vmain_top.margin_error_cnt_to_set),
    // For CCIX ESM Calibration
    .random_calibrt_complete_en     (`PHY0.u_phy_vmain_top.random_calibrt_complete_en),
    .fixed_calibrt_complete_thr     (`PHY0.u_phy_vmain_top.fixed_calibrt_complete_thr),
    .calibration_complete_en        (`PHY0.u_phy_vmain_top.calibration_complete_en),
    // For LowPinCount
    .update_localfslf_mode          (`PHY0.u_phy_vmain_top.update_localfslf_mode),
    .pclk_per_ps                    ( )
  );
  `ifdef DWC_GPHY_IDEAL
    initial  u_phy_tb_ctl.set_ideal_mode(1'b1);
  `endif
`else
  // provide default drivers for these control signals
  initial begin
    force `PHY0.u_phy_vmain_top.set_eq_feedback_delay = 1'b0; 
    force `PHY0.u_phy_vmain_top.set_eq_dirfeedback    = 1'b0;
    force `PHY0.u_phy_vmain_top.set_eq_fomfeedback    = 1'b0;
    force `PHY0.u_phy_vmain_top.set_localfs_g3        = 1'b0;
    force `PHY0.u_phy_vmain_top.set_localfs_g4        = 1'b0;
    force `PHY0.u_phy_vmain_top.set_localfs_g5        = 1'b0;
    force `PHY0.u_phy_vmain_top.set_locallf_g3        = 1'b0;
    force `PHY0.u_phy_vmain_top.set_locallf_g4        = 1'b0;
    force `PHY0.u_phy_vmain_top.set_locallf_g5        = 1'b0;
    force `PHY0.u_phy_vmain_top.set_local_tx_pset_coef_delay = 1'b0;
    force `PHY0.u_phy_vmain_top.set_local_tx_pset_coef       = 1'b0;  
    force `PHY0.rate_random_phystatus_en      = 1'b1;
    force `PHY0.powerdown_random_phystatus_en = 1'b1;
    force `PHY0.syncheader_random_en          = 1'b1;
    force `PHY0.disable_skp_addrm_en          = 1'b0;
    force `PHY0.p1_phystatus_time_load_en     = 1'b0;
    force `PHY0.p1_phystatus_time             = 13'b0;    
    force `PHY0.p2_phystatus_rise_random_en         = 1'b1;  
    force `PHY0.p2_random_phystatus_rise_load_en    = 1'b0;
    force `PHY0.p2_random_phystatus_rise_value      = 13'b0;
    force `PHY0.p2_phystatus_fall_random_en         = 1'b1; 
    force `PHY0.p2_random_phystatus_fall_load_en    = 1'b0;
    force `PHY0.p2_random_phystatus_fall_value      = 13'b0;   
    force `PHY0.rxsymclk_random_drift_en      = 1'b0;
    force `PHY0.pclkack_off_time_load_en      = 1'b0;
    force `PHY0.pclkack_off_time              = 31'b0;
    force `PHY0.pclkack_on_time_load_en       = 1'b0;
    force `PHY0.pclkack_on_time               = 31'b0;
    force `PHY0.rxdatavalid_shift_en          = 1'b0;
    force `PHY0.fixed_rxdatavalid_shift_cycle = 4'h0;
    force `PHY0.random_margin_status_en       = 1'b1;
    force `PHY0.fixed_margin_status_thr       = 8'h08;
    force `PHY0.random_calibrt_complete_en    = 1'b1;
    force `PHY0.fixed_calibrt_complete_thr    = 8'h08;
    force `PHY0.phy_cr_respond_time           = 16'h5555;       
    force `PHY0.phy_cr_rd_data_load_en        = 1'b0; 
    force `PHY0.phy_cr_rd_data_return_value   = 16'b0;
    force `PHY0.P1X_to_P1_exit_mode           = 1'b0; 
    force `PHY0.cdr_fast_lock                 = 1'b0; 
    force `PHY0.calibration_complete_en           = 1'b1;
    force `PHY0.u_phy_vmain_top.set_p2m_messagebus = 1'b0;
    force `PHY0.u_phy_vmain_top.set_m2p_messagebus = 1'b0;
    force `PHY0.u_phy_vmain_top.update_localfslf_mode = '1;
  end
`endif // CREATE_PHY_TB_CTRL

`endif // VIP_MODE_IS_SPIPE


