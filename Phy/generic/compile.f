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
// ---    $DateTime: 2020/06/26 01:14:06 $
// ---    $Revision: #39 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/compile.f#39 $
// -------------------------------------------------------------------------

/root/i_DWC_pcie_ctl/src/DWC_pcie_ctl_cc_constants.svh
+define+PHY_TB_CTL_PATH=u_phy_tb_ctl

+define+PHY_REFCLK_PERIOD_PS=10000

// workaround as GPHY does not meet 128ns timing for returning the pset coef msg bus
+define+SVA_POSTED_WR_TO_TX_CONTROL5_TOL_NS=500



-y /root/i_DWC_pcie_ctl/src/Phy/generic
+incdir+/root/i_DWC_pcie_ctl/src/Phy/generic
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_cc_constants.svh
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_defs.svh
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pkg.svh
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_bcm43.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_bcm44.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_timer.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pipe_gasket.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pll.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_ser.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_deser.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_los_lane.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_los.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pma_lane.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pma.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_10b8bdec.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_8b10benc.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_elasbuf.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_cdet.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pipe2phy.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_lpbk.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_sdm_1s_lane.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_sdm_1s.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pcs_lane.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pcs.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_blockalign.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pmu.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_eq_bfm.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_viewport_bfm.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_margin_bfm.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_reg.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_reg_sub.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_regbus_master.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_regbus_slave.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_regbus_cont.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_regbus_arb.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_pipe_aggr.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy_vmain_top.v
/root/i_DWC_pcie_ctl/src/Phy/generic/DWC_pcie_gphy.v
/root/i_DWC_pcie_ctl/src/DWC_pcie_ctl-undef.v
