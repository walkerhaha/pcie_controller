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
// ---    $DateTime: 2020/10/16 15:45:59 $
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_ecfg_reg.sv#16 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the decoding of PCIE extended capability registers
// --- and Virtual Channel extended capability structure
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
 
 module cdm_ecfg_reg(
// -- inputs ---
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    device_type,
    phy_type,
    lbc_cdm_addr,
    lbc_cdm_data,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    lbc_cdm_dbi2,
    err_reg_data,
    ecfg_reg_sel,

    rtlh_fc_init_status,
    cfg_pwr_budget_data_reg,
    cfg_pwr_budget_func_num,
    dbi_ro_wr_en,


    upstream_port,


// -- outputs --
    ecfg_write_pulse,
    ecfg_read_pulse,
    ecfg_reg_data,
    ecfg_reg_ack,
    err_reg_id,

    cfg_vc_enable,
    cfg_vc_struc_vc_id_map,
    cfg_vc_id_vc_struc_map,
    cfg_tc_enable,
    cfg_tc_vc_map,
    cfg_tc_vc_struc_map,
    cfg_lpvc,
    cfg_vc_arb_sel,
    cfg_pwr_budget_data_sel_reg,
    cfg_pwr_budget_sel,
    cfg_rbar_bar_resizable,
    cfg_rbar_bar0_mask,
    cfg_rbar_bar1_mask,
    cfg_rbar_bar2_mask,
    cfg_rbar_bar3_mask,
    cfg_rbar_bar4_mask,
    cfg_rbar_bar5_mask,
    cfg_vf_rbar_bar_resizable,
    cfg_vf_rbar_bar0_mask,
    cfg_vf_rbar_bar1_mask,
    cfg_vf_rbar_bar2_mask,
    cfg_vf_rbar_bar3_mask,
    cfg_vf_rbar_bar4_mask,
    cfg_vf_rbar_bar5_mask,

    rbar_ctrl_update,
    cfg_rbar_size,
    vf_rbar_ctrl_update,
    cfg_vf_rbar_size
);

parameter INST       = 0;                            // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM   = 0;                            // uniquifying parameter per function
parameter TP         = `TP;                          // Clock to Q delay (simulator insurance)
parameter NL         = `CX_NL;                       // Number of Lanes Supported
parameter NFUNC_WD   = `CX_NFUNC_WD;                 // Width of physical function number
parameter NVC        = `CX_NVC;                      // Number of VC channels supported
parameter VC_EN      = `VC_ENABLE;                   // VC Capability enabled or not
parameter AER_EN     = `AER_ENABLE;                  // AER Capability enabled or not
parameter SN_EN      = `SERIAL_CAP_ENABLE;           // Device Serial Number Capability enabled or not
parameter PB_EN      = `PWR_BUDGET_CAP_ENABLE;       // Power Budgeting Capability enabled or not
parameter SRIOV_EN   = `CX_SRIOV_ENABLE_VALUE;       // SR-IOV Capability enabled or not
parameter ARI_EN_VAL = `CX_ARI_ENABLE_VALUE;         // ARI Capability enabled or not
parameter SPCIE_EN   = `SPCIE_CAP_ENABLE;            // Secondary PCIe Extended Capability Enabled or not
parameter L1SUB_EN   = `CX_L1SUB_ENABLE_VALUE;       // L1 Substates Extended Capability Enabled or not
parameter PL16G_EN   = `CX_PL16G_ENABLE_VALUE;       // Physical Layer 16.0 GT/s Extended Capability Enabled or not
parameter MARGIN_EN  = `CX_MARGIN_ENABLE_VALUE;      // Margining Extended Capability Enabled or not
parameter CIO_EN         = `CX_PCIE_MODE == `PCIE_OVER_CIO;

parameter NPTMVSEC = CIO_EN ? 31 : 26;  // Number of PTM Requester or PTM Responder VSEC Registers, whichever is greater

localparam PTM_REQ_VALUE = `CX_PTM_REQUESTER_VALUE;




//`ifdef CX_RN_FRSQ_ENABLE
localparam NFRSQ = 4;
//`endif //CX_RN_FRSQ_ENABLE


localparam NF        = `CX_NFUNC;                  // Number of functions
localparam FX_TLP    = `CX_FX_TLP;                 // Number of TLPs received in a single cycle after formation block

// ----- Inputs ---------------
input                   core_clk;
input                   non_sticky_rst_n;
input                   sticky_rst_n;
input   [3:0]           device_type;                // Device type
input                   phy_type;
input   [15:0]          lbc_cdm_addr;               // Address of resource being accessed
input   [31:0]          lbc_cdm_data;               // Data for write
input   [3:0]           lbc_cdm_wr;                 // byte Write select
input                   lbc_cdm_dbi;                // DBI access to CDM
input                   lbc_cdm_dbi2;                // DBI access to CDM             
input                   ecfg_reg_sel;               // ecfg registers selected
input   [31:0]          err_reg_data;               // error register read
input   [NVC-1:0]       rtlh_fc_init_status;        // indicates the status of the process of FC initialization
input   [31:0]          cfg_pwr_budget_data_reg;    // Data Register from application
input   [NFUNC_WD-1:0]  cfg_pwr_budget_func_num;    // Function # of data register above
input                   dbi_ro_wr_en;


input                   upstream_port;




// ----- Outputs ---------------
output  [3:0]           ecfg_write_pulse;           // Extended Capability Write pulse
output                  ecfg_read_pulse;            // Extended Capability Read pulse
output  [17:0]          err_reg_id;                 // Adv. Error Register #
output  [31:0]          ecfg_reg_data;              // Read data back from core
output                  ecfg_reg_ack;               // Acknowledge back from core. Indicates completion, read data is valid



output  [NVC-1:0]       cfg_vc_enable;              // Which VCs are enabled - VC0 is always enabled
output  [(NVC*3)-1:0]   cfg_vc_struc_vc_id_map;     // VC Structure to VC ID mapping
output  [23:0]          cfg_vc_id_vc_struc_map;     // VC ID to VC Structure mapping
output  [7:0]           cfg_tc_enable;              // Which TCs are enabled
output  [23:0]          cfg_tc_vc_map;              // TC to VC ID mapping
output  [23:0]          cfg_tc_vc_struc_map;        // TC to VC Structure mapping
output  [2:0]           cfg_lpvc;                   // Low Priority Extended VC (LPVC) Count
output  [2:0]           cfg_vc_arb_sel;             // VC Arbitration Select
output  [7:0]           cfg_pwr_budget_data_sel_reg;// Power Budgeting: Data Select register
output                  cfg_pwr_budget_sel;         // Power Budgeting: Pulse signal indicates new data_sel_reg
output [5:0]            cfg_rbar_bar_resizable;     // Resize RBAR[n] where n = 0 to 5
output [63:0]           cfg_rbar_bar0_mask;         // RBAR0 mask value
output [31:0]           cfg_rbar_bar1_mask;         // RBAR1 mask value
output [63:0]           cfg_rbar_bar2_mask;         // RBAR2 mask value
output [31:0]           cfg_rbar_bar3_mask;         // RBAR3 mask value
output [63:0]           cfg_rbar_bar4_mask;         // RBAR4 mask value
output [31:0]           cfg_rbar_bar5_mask;         // RBAR5 mask value
output                  rbar_ctrl_update;           // indicates that RBAR control register has been updated
output [(6*6)-1:0]      cfg_rbar_size;              // wire the BAR size fields to top level
output [5:0]            cfg_vf_rbar_bar_resizable;     // Resize VF RBAR[n] where n = 0 to 5
output [63:0]           cfg_vf_rbar_bar0_mask;         // VF RBAR0 mask value
output [31:0]           cfg_vf_rbar_bar1_mask;         // VF RBAR1 mask value
output [63:0]           cfg_vf_rbar_bar2_mask;         // VF RBAR2 mask value
output [31:0]           cfg_vf_rbar_bar3_mask;         // VF RBAR3 mask value
output [63:0]           cfg_vf_rbar_bar4_mask;         // VF RBAR4 mask value
output [31:0]           cfg_vf_rbar_bar5_mask;         // VF RBAR5 mask value
output                  vf_rbar_ctrl_update;           // indicates that VF RBAR control register has been updated
output [(6*6)-1:0]      cfg_vf_rbar_size;              // wire the VF BAR size fields to top level



// Output registers
wire    [3:0]   ecfg_write_pulse;
wire            ecfg_read_pulse;
reg     [17:0]  err_reg_id;
wire    [31:0]  ecfg_reg_data;
reg             ecfg_reg_ack;

reg     [2:0]   cfg_lpvc;
reg     [2:0]   cfg_vc_arb_sel;                     // Used to support different types of arbitration
reg     [7:0]   cfg_pwr_budget_data_sel_reg;
reg             cfg_pwr_budget_sel;
wire    [5:0]   cfg_rbar_bar_resizable;
wire    [63:0]  cfg_rbar_bar0_mask;
wire    [31:0]  cfg_rbar_bar1_mask;
wire    [63:0]  cfg_rbar_bar2_mask;
wire    [31:0]  cfg_rbar_bar3_mask;
wire    [63:0]  cfg_rbar_bar4_mask;
wire    [31:0]  cfg_rbar_bar5_mask;
wire             rbar_ctrl_update;
wire [(6*6)-1:0] cfg_rbar_size;
wire    [5:0]   cfg_vf_rbar_bar_resizable;
wire    [63:0]  cfg_vf_rbar_bar0_mask;
wire    [31:0]  cfg_vf_rbar_bar1_mask;
wire    [63:0]  cfg_vf_rbar_bar2_mask;
wire    [31:0]  cfg_vf_rbar_bar3_mask;
wire    [63:0]  cfg_vf_rbar_bar4_mask;
wire    [31:0]  cfg_vf_rbar_bar5_mask;
wire             vf_rbar_ctrl_update;
wire [(6*6)-1:0] cfg_vf_rbar_size;

// Internal signals
wire            pcie_sw_up;
wire            pcie_sw_down;
wire            switch_device;
wire            rc_device;
wire            end_device;
wire    [7:0]   ecfg_reg_00, ecfg_reg_01, ecfg_reg_02, ecfg_reg_03;
wire    [7:0]   ecfg_reg_04, ecfg_reg_05, ecfg_reg_06, ecfg_reg_07;
wire    [7:0]   ecfg_reg_08, ecfg_reg_09, ecfg_reg_10, ecfg_reg_11;
wire    [7:0]   ecfg_reg_12, ecfg_reg_13, ecfg_reg_14, ecfg_reg_15;
wire    [7:0]   ecfg_reg_16, ecfg_reg_17, ecfg_reg_18, ecfg_reg_19;
wire    [7:0]   ecfg_reg_20, ecfg_reg_21, ecfg_reg_22, ecfg_reg_23;
wire    [7:0]   ecfg_reg_24, ecfg_reg_25, ecfg_reg_26, ecfg_reg_27;
wire    [7:0]   ecfg_reg_28, ecfg_reg_29, ecfg_reg_30, ecfg_reg_31;
wire    [7:0]   ecfg_reg_32, ecfg_reg_33, ecfg_reg_34, ecfg_reg_35;
wire    [7:0]   ecfg_reg_36, ecfg_reg_37, ecfg_reg_38, ecfg_reg_39;
wire    [7:0]   ecfg_reg_43, ecfg_reg_42, ecfg_reg_41, ecfg_reg_40;
wire    [7:0]   ecfg_reg_47, ecfg_reg_46, ecfg_reg_45, ecfg_reg_44;
wire    [7:0]   ecfg_reg_51, ecfg_reg_50, ecfg_reg_49, ecfg_reg_48;
wire    [7:0]   ecfg_reg_55, ecfg_reg_54, ecfg_reg_53, ecfg_reg_52;
wire    [7:0]   ecfg_reg_59, ecfg_reg_58, ecfg_reg_57, ecfg_reg_56;
wire    [7:0]   ecfg_reg_63, ecfg_reg_62, ecfg_reg_61, ecfg_reg_60;
wire    [7:0]   ecfg_reg_67, ecfg_reg_66, ecfg_reg_65, ecfg_reg_64;
wire    [7:0]   ecfg_reg_71, ecfg_reg_70, ecfg_reg_69, ecfg_reg_68;
wire    [7:0]   ecfg_reg_75, ecfg_reg_74, ecfg_reg_73, ecfg_reg_72;
wire    [7:0]   ecfg_reg_79, ecfg_reg_78, ecfg_reg_77, ecfg_reg_76;
wire    [7:0]   ecfg_reg_83, ecfg_reg_82, ecfg_reg_81, ecfg_reg_80;
wire    [7:0]   ecfg_reg_87, ecfg_reg_86, ecfg_reg_85, ecfg_reg_84;
wire    [7:0]   ecfg_reg_91, ecfg_reg_90, ecfg_reg_89, ecfg_reg_88;
wire    [7:0]   ecfg_reg_95, ecfg_reg_94, ecfg_reg_93, ecfg_reg_92;
wire    [7:0]   ecfg_reg_99, ecfg_reg_98, ecfg_reg_97, ecfg_reg_96;
wire    [7:0]   ecfg_reg_103, ecfg_reg_102, ecfg_reg_101, ecfg_reg_100;
wire    [7:0]   ecfg_reg_107, ecfg_reg_106, ecfg_reg_105, ecfg_reg_104;
wire    [7:0]   ecfg_reg_111, ecfg_reg_110, ecfg_reg_109, ecfg_reg_108;


reg             ecfg_reg_sel_d;
reg     [3:0]   write_pulse;
reg             read_pulse;
reg     [27:0]  vc_reg_id;
wire    [7:0]   sn_reg_03, sn_reg_02, sn_reg_01, sn_reg_00;
wire    [7:0]   sn_reg_07, sn_reg_06, sn_reg_05, sn_reg_04;
wire    [7:0]   sn_reg_11, sn_reg_10, sn_reg_09, sn_reg_08;
reg     [2:0]   sn_reg_id;
reg     [31:0]  cfg_sn_dw1;
reg     [31:0]  cfg_sn_dw2;
reg     [31:0]  sn_reg_data;

reg     [3:0]   pb_reg_id;
reg     [31:0]  pb_reg_data;
wire    [31:0]  rbar_reg_data;
wire    [31:0]  vf_rbar_reg_data;
wire    [7:0]   pb_reg_03, pb_reg_02, pb_reg_01, pb_reg_00;
wire    [7:0]   pb_reg_07, pb_reg_06, pb_reg_05, pb_reg_04;
wire    [7:0]   pb_reg_11, pb_reg_10, pb_reg_09, pb_reg_08;
wire    [7:0]   pb_reg_15, pb_reg_14, pb_reg_13, pb_reg_12;
reg     [31:0]  clked_cfg_pwr_budget_data_reg;
reg             cfg_pwr_budget_sys_alloc;

wire            ARI_EN;



















assign ecfg_write_pulse = write_pulse;
assign ecfg_read_pulse  = read_pulse;

assign end_device       = (device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY);
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_up       = (device_type == `PCIE_SW_UP);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);
assign switch_device    = pcie_sw_up | pcie_sw_down;

assign ARI_EN           = ARI_EN_VAL; // STAR 9000470917

// ECFG register enable
wire ecfg_reg_id_en;
assign ecfg_reg_id_en = ecfg_reg_sel | ecfg_reg_sel_d;

// =============================================================================
// PCIE Extended Configuration select
// -- The Extended Configuration Registers are located in device configuration sel
// at offsets 256 or greater (up to 4096).
// =============================================================================
generate
if(FUNC_NUM == 0 & VC_EN) begin : gen_vc_reg_id
  always @(posedge core_clk or negedge non_sticky_rst_n)
  begin
    if(!non_sticky_rst_n) begin
        vc_reg_id       <= #TP 0;
    end else begin
        vc_reg_id[0]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : vc_reg_id[0];
        vc_reg_id[1]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : vc_reg_id[1];
        vc_reg_id[2]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : vc_reg_id[2];
        vc_reg_id[3]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : vc_reg_id[3];
            // VC0
            vc_reg_id[4]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : vc_reg_id[4];
            vc_reg_id[5]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : vc_reg_id[5];
            vc_reg_id[6]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : vc_reg_id[6];
            // VC1

            if (NVC > 1) begin
                vc_reg_id[7]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + 4'hC) >> 2)) & ecfg_reg_sel) : vc_reg_id[7];
                vc_reg_id[8]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + 4'hC) >> 2)) & ecfg_reg_sel) : vc_reg_id[8];
                vc_reg_id[9]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + 4'hC) >> 2)) & ecfg_reg_sel) : vc_reg_id[9];
            end
            else
                vc_reg_id[9:7]  <= #TP 0;
            // VC2
            if (NVC > 2) begin
                vc_reg_id[10]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (2 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[10];
                vc_reg_id[11]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (2 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[11];
                vc_reg_id[12]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (2 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[12];
            end
            else
                vc_reg_id[12:10]<= #TP 0;
            // VC3
            if (NVC > 3) begin
                vc_reg_id[13]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (3 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[13];
                vc_reg_id[14]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (3 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[14];
                vc_reg_id[15]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (3 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[15];
            end
            else
                vc_reg_id[15:13]<= #TP 0;
            // VC4
            if (NVC > 4) begin
                vc_reg_id[16]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (4 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[16];
                vc_reg_id[17]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (4 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[17];
                vc_reg_id[18]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (4 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[18];
            end
            else
                vc_reg_id[18:16]<= #TP 0;
            // VC3
            if (NVC > 5) begin
                vc_reg_id[19]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (5 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[19];
                vc_reg_id[20]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (5 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[20];
                vc_reg_id[21]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (5 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[21];
            end
            else
                vc_reg_id[21:19]<= #TP 0;
            // VC3
            if (NVC > 6) begin
                vc_reg_id[22]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (6 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[22];
                vc_reg_id[23]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (6 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[23];
                vc_reg_id[24]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (6 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[24];
            end
            else
                vc_reg_id[24:22]<= #TP 0;
            // VC3
            if (NVC > 7) begin
                vc_reg_id[25]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h010 + (7 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[25];
                vc_reg_id[26]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h014 + (7 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[26];
                vc_reg_id[27]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h018 + (7 * 4'hC)) >> 2)) & ecfg_reg_sel) : vc_reg_id[27];
            end
            else
                vc_reg_id[27:25]<= #TP 0;
 

      end
    end
  end // if (FUNC_NUM==0 && VC_EN)

  else if (VC_EN) begin : gen_vc_reg_id         // all other functions

    always @(posedge core_clk or negedge non_sticky_rst_n)
    begin
      if(!non_sticky_rst_n) begin
        vc_reg_id       <= #TP 0;
      end else begin
          vc_reg_id[0]       <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `VC_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : vc_reg_id[0];
        vc_reg_id[27:1] <= #TP 0;
      end
    end
  end // if(VC_EN)

  else begin : gen_vc_reg_id // not VC_EN, FUNC_NUM !=0
    always @(posedge core_clk or negedge non_sticky_rst_n)
    begin
      if(!non_sticky_rst_n) begin
        vc_reg_id       <= #TP 0;
      end else begin
        vc_reg_id   <= #TP 0;
      end
    end
  end // gen_vc_reg_id

endgenerate


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        err_reg_id      <= #TP 0;
        sn_reg_id       <= #TP 0;
        pb_reg_id       <= #TP 0;
    end
    else begin
        if (AER_EN) begin
            err_reg_id[0]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : err_reg_id[0];
            err_reg_id[1]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : err_reg_id[1];
            err_reg_id[2]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : err_reg_id[2];
            err_reg_id[3]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h00c) >> 2)) & ecfg_reg_sel) : err_reg_id[3];
            err_reg_id[4]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h010) >> 2)) & ecfg_reg_sel) : err_reg_id[4];
            err_reg_id[5]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h014) >> 2)) & ecfg_reg_sel) : err_reg_id[5];
            err_reg_id[6]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h018) >> 2)) & ecfg_reg_sel) : err_reg_id[6];
            err_reg_id[7]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h01C) >> 2)) & ecfg_reg_sel) : err_reg_id[7];
            err_reg_id[8]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h020) >> 2)) & ecfg_reg_sel) : err_reg_id[8];
            err_reg_id[9]   <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h024) >> 2)) & ecfg_reg_sel) : err_reg_id[9];
            err_reg_id[10]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h028) >> 2)) & ecfg_reg_sel) : err_reg_id[10];
            err_reg_id[14]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h038) >> 2)) & ecfg_reg_sel) : err_reg_id[14];
            err_reg_id[15]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h03C) >> 2)) & ecfg_reg_sel) : err_reg_id[15];
            err_reg_id[16]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h040) >> 2)) & ecfg_reg_sel) : err_reg_id[16];
            err_reg_id[17]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h044) >> 2)) & ecfg_reg_sel) : err_reg_id[17];

            // The next 3 is for RC only
            if (rc_device) begin
                err_reg_id[11]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h02C) >> 2)) & ecfg_reg_sel) : err_reg_id[11];
                err_reg_id[12]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h030) >> 2)) & ecfg_reg_sel) : err_reg_id[12];
                err_reg_id[13]  <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `AER_PTR + 12'h034) >> 2)) & ecfg_reg_sel) : err_reg_id[13];
            end
            else begin
                err_reg_id[11]  <= #TP 0;
                err_reg_id[12]  <= #TP 0;
                err_reg_id[13]  <= #TP 0;
            end

        end
        else begin
            err_reg_id[17:0]    <= #TP 0;
        end
        if (SN_EN) begin
            sn_reg_id[0]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SN_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : sn_reg_id[0];
            sn_reg_id[1]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SN_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : sn_reg_id[1];
            sn_reg_id[2]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `SN_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : sn_reg_id[2];
        end
        else
            sn_reg_id[2:0]  <= #TP 0;
        if (PB_EN) begin
            pb_reg_id[0]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PB_PTR + 12'h000) >> 2)) & ecfg_reg_sel) : pb_reg_id[0];
            pb_reg_id[1]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PB_PTR + 12'h004) >> 2)) & ecfg_reg_sel) : pb_reg_id[1];
            pb_reg_id[2]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PB_PTR + 12'h008) >> 2)) & ecfg_reg_sel) : pb_reg_id[2];
            pb_reg_id[3]    <= #TP ecfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (( `PB_PTR + 12'h00C) >> 2)) & ecfg_reg_sel) : pb_reg_id[3];
        end
        else
            pb_reg_id[3:0]  <= #TP 0;











    




       
    end
end















// -----------------------------------------------------------------------------
// Generate resizable BAR extended register address decodes
// -----------------------------------------------------------------------------

   localparam NUM_RBARS = `CX_NUM_RBARS;

   // LMD: Undriven net Range
   // LJ: All nets are driven by the statement for (i=0; i<=(NUM_RBARS*2); i=i+1
   // leda NTL_CON12 off
   wire [(NUM_RBARS*2):0] rbar_reg_id; // Resizable BAR register ID
   // leda NTL_CON12 on

   generate
     if (NUM_RBARS > 0) begin : gen_rbar_reg_id

       reg [(NUM_RBARS*2):0] rbar_reg_id_r;

       always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_rbar_reg_id
         integer i;

         if (!non_sticky_rst_n) begin
           for (i=0; i<=(NUM_RBARS*2); i=i+1) begin
              rbar_reg_id_r[i] <= #TP 0;
           end
         end else begin
           for (i=0; i<=(NUM_RBARS*2); i=i+1) begin
              rbar_reg_id_r[i] <= #TP (lbc_cdm_addr[11:2] == (( `RBAR_PTR + (12'h004*i)) >> 2)) &
                                       ecfg_reg_sel;
           end
         end
       end
       assign rbar_reg_id = rbar_reg_id_r;
     end else begin : gen_no_rbar_reg_id
       assign rbar_reg_id = 0;
     end
   endgenerate

// -----------------------------------------------------------------------------
// Generate resizable VF BAR extended register address decodes
// -----------------------------------------------------------------------------

   localparam NUM_VF_RBARS = `CX_NUM_VF_RBARS;

   // LMD: Undriven net Range
   // LJ: All nets are driven by the statement for (i=0; i<=(NUM_VF_RBARS*2); i=i+1
   // leda NTL_CON12 off
   wire [(NUM_VF_RBARS*2):0] vf_rbar_reg_id; // Resizable BAR register ID
   // leda NTL_CON12 on

   generate
     if (NUM_VF_RBARS > 0) begin : gen_vf_rbar_reg_id

       reg [(NUM_VF_RBARS*2):0] vf_rbar_reg_id_r;

       always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_vf_rbar_reg_id
         integer i;

         if (!non_sticky_rst_n) begin
           for (i=0; i<=(NUM_VF_RBARS*2); i=i+1) begin
              vf_rbar_reg_id_r[i] <= #TP 0;
           end
         end else begin
           for (i=0; i<=(NUM_VF_RBARS*2); i=i+1) begin
              vf_rbar_reg_id_r[i] <= #TP (lbc_cdm_addr[11:2] == (( `VF_RBAR_PTR + (12'h004*i)) >> 2)) &

                                       ecfg_reg_sel;
           end
         end
       end
       assign vf_rbar_reg_id = vf_rbar_reg_id_r;
     end else begin : gen_no_vf_rbar_reg_id
       assign vf_rbar_reg_id = 0;
     end
   endgenerate


// =============================================================================
// Configuration Register Read Operation
// =============================================================================
reg     [31:0]  vc_reg_data;

wire dbi_ro_wr_en;
wire int_lbc_cdm_dbi;
assign int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;


// Extension Configuration registers
// read PCI cfg space registers
assign ecfg_reg_data   =                   (|err_reg_id) ? err_reg_data :
                                           (|vc_reg_id)  ? vc_reg_data  :
                                           (|sn_reg_id)  ? sn_reg_data  :
                                           (|pb_reg_id)  ? pb_reg_data  :
                                           (|rbar_reg_id) ? rbar_reg_data :
                                           (|vf_rbar_reg_id) ? vf_rbar_reg_data :






                                           `PCIE_UNUSED_RESPONSE;
generate
if(FUNC_NUM==0 && VC_EN) begin : gen_vc_reg_data
  always @(posedge core_clk or negedge non_sticky_rst_n)
  begin
    if (!non_sticky_rst_n)
        vc_reg_data <= #TP 32'b0;
    else
        if (read_pulse) begin


            unique case (1'b1)

            vc_reg_id[ 0] : vc_reg_data <= #TP {ecfg_reg_03, ecfg_reg_02, ecfg_reg_01, ecfg_reg_00};  // VC Header for Function 0 only

            vc_reg_id[ 1] : vc_reg_data <= #TP {ecfg_reg_07, ecfg_reg_06, ecfg_reg_05, ecfg_reg_04};
            vc_reg_id[ 2] : vc_reg_data <= #TP {ecfg_reg_11, ecfg_reg_10, ecfg_reg_09, ecfg_reg_08};
            vc_reg_id[ 3] : vc_reg_data <= #TP {ecfg_reg_15, ecfg_reg_14, ecfg_reg_13, ecfg_reg_12};
            // VC0
            vc_reg_id[ 4] : vc_reg_data <= #TP {ecfg_reg_19, ecfg_reg_18, ecfg_reg_17, ecfg_reg_16};
            vc_reg_id[ 5] : vc_reg_data <= #TP {ecfg_reg_23, ecfg_reg_22, ecfg_reg_21, ecfg_reg_20};
            vc_reg_id[ 6] : vc_reg_data <= #TP {ecfg_reg_27, ecfg_reg_26, ecfg_reg_25, ecfg_reg_24};

            // VC1
            vc_reg_id[ 7] : vc_reg_data <= #TP {ecfg_reg_31, ecfg_reg_30, ecfg_reg_29, ecfg_reg_28};
            vc_reg_id[ 8] : vc_reg_data <= #TP {ecfg_reg_35, ecfg_reg_34, ecfg_reg_33, ecfg_reg_32};
            vc_reg_id[ 9] : vc_reg_data <= #TP {ecfg_reg_39, ecfg_reg_38, ecfg_reg_37, ecfg_reg_36};
            // VC2
            vc_reg_id[10] : vc_reg_data <= #TP {ecfg_reg_43, ecfg_reg_42, ecfg_reg_41, ecfg_reg_40};
            vc_reg_id[11] : vc_reg_data <= #TP {ecfg_reg_47, ecfg_reg_46, ecfg_reg_45, ecfg_reg_44};
            vc_reg_id[12] : vc_reg_data <= #TP {ecfg_reg_51, ecfg_reg_50, ecfg_reg_49, ecfg_reg_48};
            // VC3
            vc_reg_id[13] : vc_reg_data <= #TP {ecfg_reg_55, ecfg_reg_54, ecfg_reg_53, ecfg_reg_52};
            vc_reg_id[14] : vc_reg_data <= #TP {ecfg_reg_59, ecfg_reg_58, ecfg_reg_57, ecfg_reg_56};
            vc_reg_id[15] : vc_reg_data <= #TP {ecfg_reg_63, ecfg_reg_62, ecfg_reg_61, ecfg_reg_60};
            // VC4
            vc_reg_id[16] : vc_reg_data <= #TP {ecfg_reg_67, ecfg_reg_66, ecfg_reg_65, ecfg_reg_64};
            vc_reg_id[17] : vc_reg_data <= #TP {ecfg_reg_71, ecfg_reg_70, ecfg_reg_69, ecfg_reg_68};
            vc_reg_id[18] : vc_reg_data <= #TP {ecfg_reg_75, ecfg_reg_74, ecfg_reg_73, ecfg_reg_72};
            // VC5
            vc_reg_id[19] : vc_reg_data <= #TP {ecfg_reg_79, ecfg_reg_78, ecfg_reg_77, ecfg_reg_76};
            vc_reg_id[20] : vc_reg_data <= #TP {ecfg_reg_83, ecfg_reg_82, ecfg_reg_81, ecfg_reg_80};
            vc_reg_id[21] : vc_reg_data <= #TP {ecfg_reg_87, ecfg_reg_86, ecfg_reg_85, ecfg_reg_84};
            // VC6
            vc_reg_id[22] : vc_reg_data <= #TP {ecfg_reg_91, ecfg_reg_90, ecfg_reg_89, ecfg_reg_88};
            vc_reg_id[23] : vc_reg_data <= #TP {ecfg_reg_95, ecfg_reg_94, ecfg_reg_93, ecfg_reg_92};
            vc_reg_id[24] : vc_reg_data <= #TP {ecfg_reg_99, ecfg_reg_98, ecfg_reg_97, ecfg_reg_96};
            // VC7
            vc_reg_id[25] : vc_reg_data <= #TP {ecfg_reg_103, ecfg_reg_102, ecfg_reg_101, ecfg_reg_100};
            vc_reg_id[26] : vc_reg_data <= #TP {ecfg_reg_107, ecfg_reg_106, ecfg_reg_105, ecfg_reg_104};
            vc_reg_id[27] : vc_reg_data <= #TP {ecfg_reg_111, ecfg_reg_110, ecfg_reg_109, ecfg_reg_108};

            default:        vc_reg_data <= #TP `PCIE_UNUSED_RESPONSE;
            endcase
        end
        else
            vc_reg_data <= #TP vc_reg_data;
  end // always @ (posedge core_clk or negedge non_sticky_rst_n)

end

else begin : gen_vc_reg_data //generate
always @(posedge core_clk or negedge non_sticky_rst_n)
  begin
    if (!non_sticky_rst_n)
        vc_reg_data <= #TP 32'b0;
    else
        vc_reg_data <= #TP {ecfg_reg_03, ecfg_reg_02, 16'h0};     // Null Capability for all other functions

  end

end // block: gen_vc_reg_data
    
endgenerate


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        sn_reg_data <= #TP 32'b0;
    else
        if (read_pulse & SN_EN) begin

            unique case (1'b1)
            // Device Serial Number
            sn_reg_id[0] : sn_reg_data  <= #TP {sn_reg_03, sn_reg_02, sn_reg_01, sn_reg_00};
            sn_reg_id[1] : sn_reg_data  <= #TP {sn_reg_07, sn_reg_06, sn_reg_05, sn_reg_04};
            sn_reg_id[2] : sn_reg_data  <= #TP {sn_reg_11, sn_reg_10, sn_reg_09, sn_reg_08};
            default      : sn_reg_data  <= #TP `PCIE_UNUSED_RESPONSE;
            endcase
        end
        else
            sn_reg_data <= #TP sn_reg_data;
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        pb_reg_data <= #TP 32'b0;
    else
        if (read_pulse & PB_EN) begin

            unique case (1'b1)
            // Power Budgeting
            pb_reg_id[0] : pb_reg_data  <= #TP {pb_reg_03, pb_reg_02, pb_reg_01, pb_reg_00};
            pb_reg_id[1] : pb_reg_data  <= #TP {pb_reg_07, pb_reg_06, pb_reg_05, pb_reg_04};
            pb_reg_id[2] : pb_reg_data  <= #TP {pb_reg_11, pb_reg_10, pb_reg_09, pb_reg_08};
            pb_reg_id[3] : pb_reg_data  <= #TP {pb_reg_15, pb_reg_14, pb_reg_13, pb_reg_12};
            default      : pb_reg_data  <= #TP `PCIE_UNUSED_RESPONSE;
            endcase
        end
        else
            pb_reg_data <= #TP pb_reg_data;
end




// ack one cycle after lbc_cdm_cs is asserted
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        ecfg_reg_ack            <= #TP 0;
        ecfg_reg_sel_d          <= #TP 0;
        write_pulse             <= #TP 0;
        read_pulse              <= #TP 0;
    end else begin
        ecfg_reg_ack            <= #TP  (
                                                   ecfg_reg_sel_d & ecfg_reg_sel )
                              ;
        ecfg_reg_sel_d  <= #TP ecfg_reg_sel;
        write_pulse     <= #TP (ecfg_reg_sel & ~ecfg_reg_sel_d) ? lbc_cdm_wr : 4'b0;
        read_pulse      <= #TP ecfg_reg_sel & ~ecfg_reg_sel_d & (~|lbc_cdm_wr);
    end
end

// =============================================================================
// VC Capability
// =============================================================================
reg     [7:0]   vc_enable;                      // VC enable - bit 0 is always 1
reg     [6:0]   r_vc_enable;                    // VC enable - excluding bit 0
wire    [8:0]   vc_neg_pending;

assign vc_neg_pending = {{(9-NVC){1'b0}}, (~rtlh_fc_init_status & vc_enable[NVC-1:0])};

// -----------------------------------------------------------------------------
// Virtual Channel Enhanced Capability Header
// vc_reg_id        - 0
// PCIE Offset      - `VC_PTR
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_00, ecfg_reg_01, ecfg_reg_02, ecfg_reg_03
// -----------------------------------------------------------------------------

reg [15:0]  cfg_vc_id;          // VC Capability ID
reg [3:0]   cfg_vc_ver;         // VC Capability Version
reg [11:0]  cfg_vc_next_ptr;    // VC Next Capability Offset
reg         vc_next_ptr_wr_updated;    // Asserted when VC Capability header has been changed by a DBI write

// Capabilities such as RBAR should not
// be visible to a DM product in Root Port mode; hence, when rc_device
// is true then the next pointer is in a smaller linked list.

assign {ecfg_reg_01, ecfg_reg_00}       = cfg_vc_id;
assign ecfg_reg_02[3:0]                 = cfg_vc_ver;
assign {ecfg_reg_03, ecfg_reg_02[7:4]}  = cfg_vc_next_ptr;

always @( posedge core_clk or negedge sticky_rst_n ) begin : vc_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_vc_id[15:0]       <= #TP `PCIE_VC_ECAP_ID;
        cfg_vc_ver[3:0]       <= #TP `PCIE_VC_ECAP_VER;
    end else if (vc_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_vc_id[7:0]        <= #TP write_pulse[0] ? lbc_cdm_data[7:0] : cfg_vc_id[7:0];
        cfg_vc_id[15:8]       <= #TP write_pulse[1] ? lbc_cdm_data[15:8] : cfg_vc_id[15:8];
        cfg_vc_ver[3:0]       <= #TP write_pulse[2] ? lbc_cdm_data[19:16] : cfg_vc_ver[3:0];
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : vc_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_vc_next_ptr[11:0]  <= #TP `VC_NEXT_PTR;                // Assume EP linked list at reset.
    end else if (vc_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_vc_next_ptr[3:0]   <= #TP write_pulse[2] ? lbc_cdm_data[23:20] : cfg_vc_next_ptr[3:0];
        cfg_vc_next_ptr[11:4]  <= #TP write_pulse[3] ? lbc_cdm_data[31:24] : cfg_vc_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !vc_next_ptr_wr_updated) begin
        cfg_vc_next_ptr[11:0]  <= #TP (phy_type == `PHY_TYPE_MPCIE) ? `MP_RP_VC_NEXT_PTR : `DM_RP_VC_NEXT_PTR ;       // If RP or downstream port of SW, then use smaller linked list.
    end else if (!vc_next_ptr_wr_updated) begin
        cfg_vc_next_ptr[11:0]  <= #TP (phy_type == `PHY_TYPE_MPCIE) ? `MP_VC_NEXT_PTR :  `VC_NEXT_PTR ;                // Device type could change if crosslink enable is true.
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : vc_cap_hdr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        vc_next_ptr_wr_updated <= #TP 1'b0;
    end else if (vc_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |write_pulse[3:2]) begin
        vc_next_ptr_wr_updated <= #TP 1'b1;
    end
end


// -----------------------------------------------------------------------------
// Port VC Capability Register 1
// vc_reg_id        - 1
// PCIE Offset      - `VC_PTR + 04h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_04, ecfg_reg_05, ecfg_reg_06, ecfg_reg_07
// -----------------------------------------------------------------------------
// set to 0 for Root Port and Endpoint
wire    [1:0]   vc_ref_clk;
assign vc_ref_clk                = switch_device ? `DEFAULT_VC_REF_CLK          : 2'b0;
wire    [1:0]   port_arb_table_entry_size;
assign port_arb_table_entry_size = switch_device ? `DEFAULT_PORT_ARB_TABLE_SIZE : 2'b0;

assign ecfg_reg_04[7:3] = {1'b0, cfg_lpvc, 1'b0};           // Low Priority Extended VC (LPVC) Count
assign ecfg_reg_04[2:0] = `DEFAULT_EXT_VC_CNT;
//VCS coverage off
assign ecfg_reg_05 = {4'b0,                                 // RsvdP
                      port_arb_table_entry_size,            // Port Arbitration Table Size
                      vc_ref_clk};                          // ref clk for VC that support time-based WRR
//VCS coverage on
assign ecfg_reg_06 = 8'b0;                                  // RsvdP
assign ecfg_reg_07 = 8'b0;                                  // RsvdP

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (~sticky_rst_n) begin
        cfg_lpvc    <= #TP `DEFAULT_LOW_PRI_EXT_VC_CNT;
    end
    else begin
        cfg_lpvc    <= #TP (vc_reg_id[1] & write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[6:4] : cfg_lpvc;
    end
end

// -----------------------------------------------------------------------------
// Port VC Capability Register 2
// vc_reg_id        - 2
// PCIE Offset      - `VC_PTR + 08h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_08, ecfg_reg_09, ecfg_reg_10, ecfg_reg_11
// -----------------------------------------------------------------------------
reg[7:0] cfg_vc_arb_cap;
assign ecfg_reg_08 = cfg_vc_arb_cap;                             // VC Arbitration Capability
assign ecfg_reg_09 = 8'b0;                                  // RsvdP
assign ecfg_reg_10 = 8'b0;                                  // RsvdP
assign ecfg_reg_11 = `DEFAULT_VC_ARB_TABLE_OFFSET;          // VC Arbitration Table Offset
  
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        cfg_vc_arb_cap       <= #TP `DEFAULT_VC_ARB_32;
    end
    else begin
        cfg_vc_arb_cap[3:0]  <= #TP (vc_reg_id[2] & write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:0] : cfg_vc_arb_cap[3:0];
        cfg_vc_arb_cap[7:4]  <= #TP 0;                           // Reserved
    end
end

// -----------------------------------------------------------------------------
// Port VC Control Register
// vc_reg_id        - 3
// PCIE Offset      - `VC_PTR + 0Ch
// length           - 2 byte
// default value    -
// Cfig register    - ecfg_reg_12, ecfg_reg_13
// -----------------------------------------------------------------------------

assign          ecfg_reg_12 = {4'h0, cfg_vc_arb_sel, 1'b0}; // bit 0 always return 0 when read
assign          ecfg_reg_13 = 8'h0;                         // RsvdP

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_vc_arb_sel  <= #TP 0;
    end
    else begin
        cfg_vc_arb_sel  <= #TP (vc_reg_id[3] & write_pulse[0]) ? lbc_cdm_data[3:1] : cfg_vc_arb_sel;

    end
end

// -----------------------------------------------------------------------------
// Port VC status Register
// vc_reg_id        - 3
// PCIE Offset      - `VC_PTR + 0Eh
// length           - 2 byte
// default value    -
// Cfig register    - ecfg_reg_14, ecfg_reg_15
// -----------------------------------------------------------------------------
wire        vc_table_status;
assign vc_table_status = 0;                            // 0 since no arbitration table present

//VCS coverage off
assign      ecfg_reg_14     = {7'b0,                        // RsvdP
                               vc_table_status};            // VC Arbitration Table Status
//VCS coverage on
assign      ecfg_reg_15     = 8'b0;                         // RsvdP

// =============================================================================
// VC0 Resource Capability Register
// vc_reg_id        - 4
// PCIE Offset      - `VC_PTR + 10h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_16, ecfg_reg_17, ecfg_reg_18, ecfg_reg_19
// -----------------------------------------------------------------------------
assign ecfg_reg_16 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC0 : 8'b0;
assign ecfg_reg_17 = {`DEFAULT_REJECT_NO_SNOOP_VC0,         // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC0,                 // When set, only support AS packet traffic
                      6'b0};                                // RsvdP
assign ecfg_reg_18 = {1'b0,                                 // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC0};         // Maximum Time Slot
assign ecfg_reg_19 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC0 : 8'b0;

// -----------------------------------------------------------------------------
// VC0 Resource Control Register
// vc_reg_id        - 5
// PCIE Offset      - `VC_PTR + 14h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_20, ecfg_reg_21, ecfg_reg_22, ecfg_reg_23
// -----------------------------------------------------------------------------
reg     [2:0]   vc0_port_arb_sel;
reg     [7:0]   tc_vc0_map;
assign          ecfg_reg_20         = {tc_vc0_map[7:1], 1'b1};
assign          ecfg_reg_21         = 8'h0;                 // RsvdP
assign          ecfg_reg_22         = {4'h0, 3'h0, 1'b0};
reg             load_port0_arb_table;                       // No table supported, not used
assign          ecfg_reg_23         = 8'h80;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        tc_vc0_map          <= #TP 8'hFF;
        load_port0_arb_table<= #TP 0;
        vc0_port_arb_sel    <= #TP 0;
    end else begin
        // Bit 0 is read only - must be set to 1 only for VC0.
        tc_vc0_map[7:1]     <= #TP (vc_reg_id[5] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc0_map[7:1];
        tc_vc0_map[0]       <= #TP 1'b1;
        load_port0_arb_table<= #TP (vc_reg_id[5] & write_pulse[2]) ? lbc_cdm_data[16] : load_port0_arb_table;
        vc0_port_arb_sel    <= #TP (vc_reg_id[5] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc0_port_arb_sel;
    end
end

// -----------------------------------------------------------------------------
// VC0 Resource Status Register
// vc_reg_id        - 6
// PCIE Offset      - `VC_PTR + 18h
// length           - 4 byte
// default value    -
// Cfig register    - ecfg_reg_24, ecfg_reg_25, ecfg_reg_26, ecfg_reg_27
// -----------------------------------------------------------------------------
assign   ecfg_reg_24 = 8'b0;                                // RsvdP
assign   ecfg_reg_25 = 8'b0;                                // RsvdP
assign   ecfg_reg_26 = {6'b0, vc_neg_pending[0], 1'b0};
assign   ecfg_reg_27 = 8'b0;                                // RsvdP




// =============================================================================
// VC0 was special, but VC1-7 is the same structure/characteristics
// =============================================================================
reg [7:1]   tc_vc_map[7:0];                                 // bit 0 is always 0
reg [7:1]   load_port_arb_table;                            // Not supported
reg [2:0]   vc_port_arb_sel[7:1];                           // Arbitration select, only 000 is supported
reg [2:0]   vc_id[7:1];                                     // VC ID - structure 0 is always 0

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
            tc_vc_map[1]            <= #TP 0;
            load_port_arb_table[1]  <= #TP 0;
            vc_port_arb_sel[1]      <= #TP 0;
            vc_id[1]                <= #TP 0;
            tc_vc_map[2]            <= #TP 0;
            load_port_arb_table[2]  <= #TP 0;
            vc_port_arb_sel[2]      <= #TP 0;
            vc_id[2]                <= #TP 0;
            tc_vc_map[3]            <= #TP 0;
            load_port_arb_table[3]  <= #TP 0;
            vc_port_arb_sel[3]      <= #TP 0;
            vc_id[3]                <= #TP 0;
            tc_vc_map[4]            <= #TP 0;
            load_port_arb_table[4]  <= #TP 0;
            vc_port_arb_sel[4]      <= #TP 0;
            vc_id[4]                <= #TP 0;
            tc_vc_map[5]            <= #TP 0;
            load_port_arb_table[5]  <= #TP 0;
            vc_port_arb_sel[5]      <= #TP 0;
            vc_id[5]                <= #TP 0;
            tc_vc_map[6]            <= #TP 0;
            load_port_arb_table[6]  <= #TP 0;
            vc_port_arb_sel[6]      <= #TP 0;
            vc_id[6]                <= #TP 0;
            tc_vc_map[7]            <= #TP 0;
            load_port_arb_table[7]  <= #TP 0;
            vc_port_arb_sel[7]      <= #TP 0;
            vc_id[7]                <= #TP 0;
            tc_vc_map[0]            <= #TP 0;
    end else begin
        tc_vc_map[0]                <= #TP tc_vc0_map[7:1];
        if (VC_EN) begin
            tc_vc_map[1]            <= #TP (vc_reg_id[8] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[1];
            load_port_arb_table[1]  <= #TP (vc_reg_id[8] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[1];
            vc_port_arb_sel[1]      <= #TP (vc_reg_id[8] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[1];
            vc_id[1]                <= #TP (vc_reg_id[8] & write_pulse[3] & ~vc_enable[1]) ? lbc_cdm_data[26:24] : vc_id[1];

            tc_vc_map[2]            <= #TP (vc_reg_id[11] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[2];
            load_port_arb_table[2]  <= #TP (vc_reg_id[11] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[2];
            vc_port_arb_sel[2]      <= #TP (vc_reg_id[11] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[2];
            vc_id[2]                <= #TP (vc_reg_id[11] & write_pulse[3] & ~vc_enable[2]) ? lbc_cdm_data[26:24] : vc_id[2];

            tc_vc_map[3]            <= #TP (vc_reg_id[14] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[3];
            load_port_arb_table[3]  <= #TP (vc_reg_id[14] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[3];
            vc_port_arb_sel[3]      <= #TP (vc_reg_id[14] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[3];
            vc_id[3]                <= #TP (vc_reg_id[14] & write_pulse[3] & ~vc_enable[3]) ? lbc_cdm_data[26:24] : vc_id[3];

            tc_vc_map[4]            <= #TP (vc_reg_id[17] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[4];
            load_port_arb_table[4]  <= #TP (vc_reg_id[17] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[4];
            vc_port_arb_sel[4]      <= #TP (vc_reg_id[17] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[4];
            vc_id[4]                <= #TP (vc_reg_id[17] & write_pulse[3] & ~vc_enable[4]) ? lbc_cdm_data[26:24] : vc_id[4];

            tc_vc_map[5]            <= #TP (vc_reg_id[20] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[5];
            load_port_arb_table[5]  <= #TP (vc_reg_id[20] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[5];
            vc_port_arb_sel[5]      <= #TP (vc_reg_id[20] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[5];
            vc_id[5]                <= #TP (vc_reg_id[20] & write_pulse[3] & ~vc_enable[5]) ? lbc_cdm_data[26:24] : vc_id[5];

            tc_vc_map[6]            <= #TP (vc_reg_id[23] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[6];
            load_port_arb_table[6]  <= #TP (vc_reg_id[23] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[6];
            vc_port_arb_sel[6]      <= #TP (vc_reg_id[23] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[6];
            vc_id[6]                <= #TP (vc_reg_id[23] & write_pulse[3] & ~vc_enable[6]) ? lbc_cdm_data[26:24] : vc_id[6];

            tc_vc_map[7]            <= #TP (vc_reg_id[26] & write_pulse[0]) ? lbc_cdm_data[7:1] : tc_vc_map[7];
            load_port_arb_table[7]  <= #TP (vc_reg_id[26] & write_pulse[2]) ? lbc_cdm_data[16] : load_port_arb_table[7];
            vc_port_arb_sel[7]      <= #TP (vc_reg_id[26] & write_pulse[2] & switch_device) ? lbc_cdm_data[19:17] : vc_port_arb_sel[7];
            vc_id[7]                <= #TP (vc_reg_id[26] & write_pulse[3] & ~vc_enable[7]) ? lbc_cdm_data[26:24] : vc_id[7];
        end
        else begin
            tc_vc_map[1]            <= #TP 0;
            load_port_arb_table[1]  <= #TP 0;
            vc_port_arb_sel[1]      <= #TP 0;
            vc_id[1]                <= #TP 0;
            tc_vc_map[2]            <= #TP 0;
            load_port_arb_table[2]  <= #TP 0;
            vc_port_arb_sel[2]      <= #TP 0;
            vc_id[2]                <= #TP 0;
            tc_vc_map[3]            <= #TP 0;
            load_port_arb_table[3]  <= #TP 0;
            vc_port_arb_sel[3]      <= #TP 0;
            vc_id[3]                <= #TP 0;
            tc_vc_map[4]            <= #TP 0;
            load_port_arb_table[4]  <= #TP 0;
            vc_port_arb_sel[4]      <= #TP 0;
            vc_id[4]                <= #TP 0;
            tc_vc_map[5]            <= #TP 0;
            load_port_arb_table[5]  <= #TP 0;
            vc_port_arb_sel[5]      <= #TP 0;
            vc_id[5]                <= #TP 0;
            tc_vc_map[6]            <= #TP 0;
            load_port_arb_table[6]  <= #TP 0;
            vc_port_arb_sel[6]      <= #TP 0;
            vc_id[6]                <= #TP 0;
            tc_vc_map[7]            <= #TP 0;
            load_port_arb_table[7]  <= #TP 0;
            vc_port_arb_sel[7]      <= #TP 0;
            vc_id[7]                <= #TP 0;
        end
    end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
  if (!non_sticky_rst_n) begin
    r_vc_enable               <= #TP 0;
  end else begin
    if (VC_EN) begin
      r_vc_enable[0]            <= #TP (vc_reg_id[8] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[0];
      r_vc_enable[1]            <= #TP (vc_reg_id[11] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[1];
      r_vc_enable[2]            <= #TP (vc_reg_id[14] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[2];
      r_vc_enable[3]            <= #TP (vc_reg_id[17] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[3];
      r_vc_enable[4]            <= #TP (vc_reg_id[20] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[4];
      r_vc_enable[5]            <= #TP (vc_reg_id[23] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[5];
      r_vc_enable[6]            <= #TP (vc_reg_id[26] & write_pulse[3]) ? lbc_cdm_data[31] : r_vc_enable[6];
    end
    else begin
      r_vc_enable               <= #TP 0;
    end
  end
end

assign vc_enable = {r_vc_enable, 1'b1};

// VC1
assign ecfg_reg_28 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC1 : 8'b0;
assign ecfg_reg_29 = {`DEFAULT_REJECT_NO_SNOOP_VC1,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC1,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_30 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC1};                     // Maximum Time Slot
assign ecfg_reg_31 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC1 : 8'b0;
assign ecfg_reg_32 = {tc_vc_map[1], 1'b0};
assign ecfg_reg_33 = 8'h0;
assign ecfg_reg_34 = {4'h0, vc_port_arb_sel[1], 1'b0};
assign ecfg_reg_35 = {vc_enable[1], 4'h0, vc_id[1]};
assign ecfg_reg_36 = 8'b0;                                              // RsvdP
assign ecfg_reg_37 = 8'b0;                                              // RsvdP
assign ecfg_reg_38 = {6'b0, vc_neg_pending[1], 1'b0};
assign ecfg_reg_39 = 8'b0;
// VC2
assign ecfg_reg_40 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC2 : 8'b0;
assign ecfg_reg_41 = {`DEFAULT_REJECT_NO_SNOOP_VC2,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC2,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_42 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC2};                     // Maximum Time Slot
assign ecfg_reg_43 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC2 : 8'b0;
assign ecfg_reg_44 = {tc_vc_map[2], 1'b0};
assign ecfg_reg_45 = 8'h0;
assign ecfg_reg_46 = {4'h0, vc_port_arb_sel[2], 1'b0};
assign ecfg_reg_47 = {vc_enable[2], 4'h0, vc_id[2]};
assign ecfg_reg_48 = 8'b0;                                              // RsvdP
assign ecfg_reg_49 = 8'b0;                                              // RsvdP
assign ecfg_reg_50 = {6'b0, vc_neg_pending[2], 1'b0};
assign ecfg_reg_51 = 8'b0;
// VC3
assign ecfg_reg_52 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC3 : 8'b0;
assign ecfg_reg_53 = {`DEFAULT_REJECT_NO_SNOOP_VC3,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC3,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_54 = {1'b0,                                             // RsvdP
                    `DEFAULT_MAX_TIME_SLOTS_VC3};                       // Maximum Time Slot
assign ecfg_reg_55 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC3 : 8'b0;
assign ecfg_reg_56 = {tc_vc_map[3], 1'b0};
assign ecfg_reg_57 = 8'h0;
assign ecfg_reg_58 = {4'h0, vc_port_arb_sel[3], 1'b0};
assign ecfg_reg_59 = {vc_enable[3], 4'h0, vc_id[3]};
assign ecfg_reg_60 = 8'b0;                                              // RsvdP
assign ecfg_reg_61 = 8'b0;                                              // RsvdP
assign ecfg_reg_62 = {6'b0, vc_neg_pending[3], 1'b0};
assign ecfg_reg_63 = 8'b0;
// VC4
assign ecfg_reg_64 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC4 : 8'b0;
assign ecfg_reg_65 = {`DEFAULT_REJECT_NO_SNOOP_VC4,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC4,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_66 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC4};                     // Maximum Time Slot
assign ecfg_reg_67 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC4 : 8'b0;
assign ecfg_reg_68 = {tc_vc_map[4], 1'b0};
assign ecfg_reg_69 = 8'h0;
assign ecfg_reg_70 = {4'h0, vc_port_arb_sel[4], 1'b0};
assign ecfg_reg_71 = {vc_enable[4], 4'h0, vc_id[4]};
assign ecfg_reg_72 = 8'b0;                                              // RsvdP
assign ecfg_reg_73 = 8'b0;                                              // RsvdP
assign ecfg_reg_74 = {6'b0, vc_neg_pending[4], 1'b0};
assign ecfg_reg_75 = 8'b0;
// VC5
assign ecfg_reg_76 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC5 : 8'b0;
assign ecfg_reg_77 = {`DEFAULT_REJECT_NO_SNOOP_VC5,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC5,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_78 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC5};                     // Maximum Time Slot
assign ecfg_reg_79 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC5 : 8'b0;
assign ecfg_reg_80 = {tc_vc_map[5], 1'b0};
assign ecfg_reg_81 = 8'h0;
assign ecfg_reg_82 = {4'h0, vc_port_arb_sel[5], 1'b0};
assign ecfg_reg_83 = {vc_enable[5], 4'h0, vc_id[5]};
assign ecfg_reg_84 = 8'b0;                                              // RsvdP
assign ecfg_reg_85 = 8'b0;                                              // RsvdP
assign ecfg_reg_86 = {6'b0, vc_neg_pending[5], 1'b0};
assign ecfg_reg_87 = 8'b0;
// VC6
assign ecfg_reg_88 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC6 : 8'b0;
assign ecfg_reg_89 = {`DEFAULT_REJECT_NO_SNOOP_VC6,                     // When set, transaction without no-snoop is UR
                      `DEFAULT_AS_ONLY_VC6,                             // When set, only support AS packet traffic
                      6'b0};                                            // RsvdP
assign ecfg_reg_90 = {1'b0,                                             // RsvdP
                      `DEFAULT_MAX_TIME_SLOTS_VC6};                     // Maximum Time Slot
assign ecfg_reg_91 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC6 : 8'b0;
assign ecfg_reg_92 = {tc_vc_map[6], 1'b0};
assign ecfg_reg_93 = 8'h0;
assign ecfg_reg_94 = {4'h0, vc_port_arb_sel[6], 1'b0};
assign ecfg_reg_95 = {vc_enable[6], 4'h0, vc_id[6]};
assign ecfg_reg_96 = 8'b0;                                              // RsvdP
assign ecfg_reg_97 = 8'b0;                                              // RsvdP
assign ecfg_reg_98 = {6'b0, vc_neg_pending[6], 1'b0};
assign ecfg_reg_99 = 8'b0;
// VC7
assign ecfg_reg_100 = switch_device ? `DEFAULT_PORT_ARB_CAP_VC7 : 8'b0;
assign ecfg_reg_101 = {`DEFAULT_REJECT_NO_SNOOP_VC7,                    // When set, transaction without no-snoop is UR
                       `DEFAULT_AS_ONLY_VC7,                            // When set, only support AS packet traffic
                       6'b0};                                           // RsvdP
assign ecfg_reg_102 = {1'b0,                                            // RsvdP
                       `DEFAULT_MAX_TIME_SLOTS_VC7};                    // Maximum Time Slot
assign ecfg_reg_103 = switch_device ? `DEFAULT_PORT_ARB_TABLE_OFFSET_VC7 : 8'b0;
assign ecfg_reg_104 = {tc_vc_map[7], 1'b0};
assign ecfg_reg_105 = 8'h0;
assign ecfg_reg_106 = {4'h0, vc_port_arb_sel[7], 1'b0};
assign ecfg_reg_107 = {vc_enable[7], 4'h0, vc_id[7]};
assign ecfg_reg_108 = 8'b0;                                             // RsvdP
assign ecfg_reg_109 = 8'b0;                                             // RsvdP
assign ecfg_reg_110 = {6'b0, vc_neg_pending[7], 1'b0};
assign ecfg_reg_111 = 8'b0;




// General VC Assignments

// VC Structure enables
assign cfg_vc_enable = vc_enable[NVC-1:0];

// VC Structure to VC ID mapping
wire [23:0] tmp_vc_struc_vc_id_map;
assign tmp_vc_struc_vc_id_map   = VC_EN ?
                                       {vc_id[7], vc_id[6], vc_id[5], vc_id[4], vc_id[3], vc_id[2], vc_id[1], 3'h0}
                                       : 24'b0;

assign cfg_vc_struc_vc_id_map = tmp_vc_struc_vc_id_map[(NVC*3)-1:0];

// VC ID to VC Structure mapping
reg  [2:0]  tmp_vc_id_vc_struc_map[7:1];



// LMD: Variable in the sensitivity list but not used in the block
// LJ: vc_id and tc_vc_map arrays are always defined but only the first NVC are used, hence the warning. Using always@(*) wouldn't work on Xilinx tools
// leda W456 off
// LMD: Missing or redundant signals in the sensitivity list of a combinational block. Signal <item> is missing or redundant.
// LJ: vc_id and tc_vc_map arrays are always defined but only the first NVC are used, hence the warning. Using always@(*) wouldn't work on Xilinx tools
// leda C_2C_R off
always @(vc_id[1] or vc_id[2] or vc_id[3] or vc_id[4] or vc_id[5] or vc_id[6] or vc_id[7])
begin : vc_id_struc_map_update
    integer i, j;

    for (j=1; j<8; j=j+1) begin
        tmp_vc_id_vc_struc_map[j] = 3'h0;
        for (i=1; i<NVC; i=i+1) begin
            if (vc_id[i] == j)
                tmp_vc_id_vc_struc_map[j] = i;
        end
    end
end
// leda C_2C_R on
// leda W456 on



assign cfg_vc_id_vc_struc_map = VC_EN ?
                                {tmp_vc_id_vc_struc_map[7], tmp_vc_id_vc_struc_map[6], tmp_vc_id_vc_struc_map[5], tmp_vc_id_vc_struc_map[4],
                                 tmp_vc_id_vc_struc_map[3], tmp_vc_id_vc_struc_map[2], tmp_vc_id_vc_struc_map[1], 3'h0}
                                : 24'h0;

// Traffic Class to VC Structure mapping
wire    [7:0]   tc_vc1_map;
assign tc_vc1_map = {tc_vc_map[1], 1'b0};
wire    [7:0]   tc_vc2_map;
assign tc_vc2_map = {tc_vc_map[2], 1'b0};
wire    [7:0]   tc_vc3_map;
assign tc_vc3_map = {tc_vc_map[3], 1'b0};
wire    [7:0]   tc_vc4_map;
assign tc_vc4_map = {tc_vc_map[4], 1'b0};
wire    [7:0]   tc_vc5_map;
assign tc_vc5_map = {tc_vc_map[5], 1'b0};
wire    [7:0]   tc_vc6_map;
assign tc_vc6_map = {tc_vc_map[6], 1'b0};
wire    [7:0]   tc_vc7_map;
assign tc_vc7_map = {tc_vc_map[7], 1'b0};

reg     [2:0]   tmp_tc_vc_map[7:0];

always @(tc_vc0_map or tc_vc1_map or tc_vc2_map or tc_vc3_map or tc_vc4_map or tc_vc5_map or tc_vc6_map or tc_vc7_map)
begin : tc_vc_map_update
    integer i;

    for (i=0; i<8; i=i+1) begin
        if (tc_vc0_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h0;

        else if (tc_vc1_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h1;
        else if (tc_vc2_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h2;
        else if (tc_vc3_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h3;
        else if (tc_vc4_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h4;
        else if (tc_vc5_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h5;
        else if (tc_vc6_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h6;
        else if (tc_vc7_map[i] == 1'b1)
            tmp_tc_vc_map[i] = 3'h7;

        else
            tmp_tc_vc_map[i] = 3'h0;
    end
end

assign cfg_tc_vc_struc_map = VC_EN ?
                             {tmp_tc_vc_map[7], tmp_tc_vc_map[6], tmp_tc_vc_map[5], tmp_tc_vc_map[4],
                              tmp_tc_vc_map[3], tmp_tc_vc_map[2], tmp_tc_vc_map[1], 3'h0}
                             : 24'h0;

// Traffic Class to VC ID mapping
integer m,n;
reg [7:0]   local_tc_vc_map;
reg [2:0]   tmp2_tc_vc_map[7:0];

// LMD: Variable in the sensitivity list but not used in the block
// LJ: vc_id and tc_vc_map arrays are always defined but only the first NVC are used, hence the warning
// leda W456 off
// LMD: Missing or redundant signals in the sensitivity list of a combinational block. Signal <item> is missing or redundant.
// LJ: vc_id and tc_vc_map arrays are always defined but only the first NVC are used, hence the warning
// leda C_2C_R off
always @(tc_vc_map[0] or tc_vc_map[1] or tc_vc_map[2] or tc_vc_map[3] or tc_vc_map[4] or
         tc_vc_map[5] or tc_vc_map[6] or tc_vc_map[7] or vc_id[1] or
         vc_id[2] or vc_id[3] or vc_id[4] or vc_id[5] or vc_id[6] or vc_id[7])
begin : tc_vc_map_update2
    tmp2_tc_vc_map[0] = 0;
    for (m=1; m<8; m=m+1) begin
        tmp2_tc_vc_map[m] = 0;
        for (n=0; n<NVC; n=n+1) begin
            local_tc_vc_map = {tc_vc_map[n],1'b0};
            if (local_tc_vc_map[m]) begin
                if (n==0)
                    tmp2_tc_vc_map[m] = 3'b0;
                else
                    tmp2_tc_vc_map[m] = vc_id[n];
            end
        end
    end
end
// leda W456 on
// leda C_2C_R on

assign cfg_tc_vc_map = VC_EN ?
                       {tmp2_tc_vc_map[7], tmp2_tc_vc_map[6], tmp2_tc_vc_map[5], tmp2_tc_vc_map[4],
                        tmp2_tc_vc_map[3], tmp2_tc_vc_map[2], tmp2_tc_vc_map[1], 3'h0}
                       : 24'h0;

// Traffic Class enable
assign cfg_tc_enable = VC_EN ?
                       tc_vc0_map | tc_vc1_map | tc_vc2_map | tc_vc3_map  | tc_vc4_map  | tc_vc5_map  | tc_vc6_map | tc_vc7_map
                       : 8'hFF;


// =============================================================================
// Device Serial Number Capability Structure
// =============================================================================
// Serial CAP register
// sn_reg_id        - 0
// PCIE Offset      - `SN_PTR
// Length           - 4 bytes
// Default value    - {`SN_NEXT_PTR, 4'h1, 16'h3}
// Cfig register    - sn_reg_03, sn_reg_02, sn_reg_01, sn_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_sn_id;          // DSN Capability ID
reg [3:0]   cfg_sn_ver;         // DSN Capability Version
reg [11:0]  cfg_sn_next_ptr;    // DSN Next Capability Offset
reg         sn_next_ptr_wr_updated;    // Asserted when DSN Capability header has been changed by a DBI write

// Capabilities such as RBAR should not
// be visible to a DM product in Root Port mode; hence, when rc_device
// is true then the next pointer is in a smaller linked list.

assign {sn_reg_01, sn_reg_00}       = cfg_sn_id;
assign sn_reg_02[3:0]               = cfg_sn_ver;
assign {sn_reg_03, sn_reg_02[7:4]}  = cfg_sn_next_ptr;

always @( posedge core_clk or negedge sticky_rst_n ) begin : sn_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_sn_id[15:0]       <= #TP 16'h3;                // Device Serial Num Cap ID
        cfg_sn_ver[3:0]       <= #TP 4'h1;                 // Capability version
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_sn_id[7:0]        <= #TP (sn_reg_id[0] & write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_sn_id[7:0];
        cfg_sn_id[15:8]       <= #TP (sn_reg_id[0] & write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_sn_id[15:8];
        cfg_sn_ver[3:0]       <= #TP (sn_reg_id[0] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_sn_ver[3:0];
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : sn_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_sn_next_ptr[11:0] <= #TP ((FUNC_NUM==0) ? `SN_NEXT_PTR_0 : `SN_NEXT_PTR_N);                       // Assume EP linked list at reset.
    end else if (sn_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_sn_next_ptr[3:0]  <= #TP write_pulse[2] ? lbc_cdm_data[23:20] : cfg_sn_next_ptr[3:0];
        cfg_sn_next_ptr[11:4] <= #TP write_pulse[3] ? lbc_cdm_data[31:24] : cfg_sn_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !sn_next_ptr_wr_updated) begin
        cfg_sn_next_ptr[11:0]  <= #TP (phy_type == `PHY_TYPE_MPCIE) ? `MP_RP_SN_NEXT_PTR : `DM_RP_SN_NEXT_PTR ;       // If RP or downstream port of SW, then use smaller linked list.
    end else if (!sn_next_ptr_wr_updated) begin
        cfg_sn_next_ptr[11:0]  <= #TP (phy_type == `PHY_TYPE_MPCIE) ? `MP_SN_NEXT_PTR : ((FUNC_NUM==0) ?  `SN_NEXT_PTR_0 :  `SN_NEXT_PTR_N) ;             // Device type could change if crosslink enable is true.
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : sn_cap_hdr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        sn_next_ptr_wr_updated <= #TP 1'b0;
    end else if (sn_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |write_pulse[3:2]) begin
        sn_next_ptr_wr_updated <= #TP 1'b1;
    end
end


// -----------------------------------------------------------------------------
// Serial Number register (DW1)
// sn_reg_id        - 1
// PCIE Offset      - `SN_PTR + 04h
// Length           - 4 bytes
// Default value    - `DEFAULT_SN_DW1
// Cfig register    - sn_reg_07, sn_reg_06, sn_reg_05, sn_reg_04
// -----------------------------------------------------------------------------
 
assign {sn_reg_07, sn_reg_06, sn_reg_05, sn_reg_04} = cfg_sn_dw1;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_sn_dw1        <= #TP `DEFAULT_SN_DW1;
    end else begin
        if (SN_EN) begin
            cfg_sn_dw1[7:0]     <= #TP (write_pulse[0] & sn_reg_id[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0]   : cfg_sn_dw1[7:0];
            cfg_sn_dw1[15:8]    <= #TP (write_pulse[1] & sn_reg_id[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8]  : cfg_sn_dw1[15:8];
            cfg_sn_dw1[23:16]   <= #TP (write_pulse[2] & sn_reg_id[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_sn_dw1[23:16];
            cfg_sn_dw1[31:24]   <= #TP (write_pulse[3] & sn_reg_id[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_sn_dw1[31:24];
        end
        else begin
            cfg_sn_dw1          <= #TP `DEFAULT_SN_DW1;
        end
    end
end

// -----------------------------------------------------------------------------
// Serial Number register (DW2)
// sn_reg_id        - 2
// PCIE Offset      - `SN_PTR + 08h
// Length           - 4 bytes
// Default value    - `DEFAULT_SN_DW2
// Cfig register    - sn_reg_11, sn_reg_10, sn_reg_09, sn_reg_08
// -----------------------------------------------------------------------------
assign {sn_reg_11, sn_reg_10, sn_reg_09, sn_reg_08} = cfg_sn_dw2;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_sn_dw2        <= #TP `DEFAULT_SN_DW2;
    end else begin
        if (SN_EN) begin
            cfg_sn_dw2[7:0]     <= #TP (write_pulse[0] & sn_reg_id[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0]   : cfg_sn_dw2[7:0];
            cfg_sn_dw2[15:8]    <= #TP (write_pulse[1] & sn_reg_id[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8]  : cfg_sn_dw2[15:8];
            cfg_sn_dw2[23:16]   <= #TP (write_pulse[2] & sn_reg_id[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_sn_dw2[23:16];
            cfg_sn_dw2[31:24]   <= #TP (write_pulse[3] & sn_reg_id[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_sn_dw2[31:24];
        end
        else begin
            cfg_sn_dw2          <= #TP `DEFAULT_SN_DW2;
        end
    end
end

// =============================================================================
// Power Budgeting Capability Structure
// =============================================================================
// Power Budget CAP register
// pb_reg_id        - 0
// PCIE Offset      - `PB_PTR
// Length           - 4 bytes
// Default value    - {`PB_NEXT_PTR, 4'h1, 16'h4}
// Cfig register    - pb_reg_03, pb_reg_02, pb_reg_01, pb_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_pb_id;          // PB Capability ID
reg [3:0]   cfg_pb_ver;         // PB Capability Version
reg [11:0]  cfg_pb_next_ptr;    // PB Next Capability Offset
reg         pb_next_ptr_wr_updated;    // Asserted when PB Capability header has been changed by a DBI write

// Capabilities such as RBAR should not
// be visible to a DM product in Root Port mode; hence, when rc_device
// is true then the next pointer is in a smaller linked list.

assign {pb_reg_01, pb_reg_00}       = cfg_pb_id;
assign pb_reg_02[3:0]               = cfg_pb_ver;
assign {pb_reg_03, pb_reg_02[7:4]}  = cfg_pb_next_ptr;

always @( posedge core_clk or negedge sticky_rst_n ) begin : pb_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pb_id[15:0]       <= #TP 16'h4;                // PB Cap ID
        cfg_pb_ver[3:0]       <= #TP 4'h1;                 // Capability version
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_pb_id[7:0]        <= #TP (pb_reg_id[0] & write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_pb_id[7:0];
        cfg_pb_id[15:8]       <= #TP (pb_reg_id[0] & write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_pb_id[15:8];
        cfg_pb_ver[3:0]       <= #TP (pb_reg_id[0] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_pb_ver[3:0];
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : pb_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pb_next_ptr[11:0] <= #TP ((FUNC_NUM==0) ? `PB_NEXT_PTR_0  : `PB_NEXT_PTR_N);       // Assume EP linked list at reset.
    end else if (pb_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_pb_next_ptr[3:0]  <= #TP write_pulse[2] ? lbc_cdm_data[23:20] : cfg_pb_next_ptr[3:0];
        cfg_pb_next_ptr[11:4] <= #TP write_pulse[3] ? lbc_cdm_data[31:24] : cfg_pb_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !pb_next_ptr_wr_updated) begin
        cfg_pb_next_ptr[11:0] <= #TP (phy_type == `PHY_TYPE_MPCIE) ? `MP_RP_PB_NEXT_PTR : `DM_RP_PB_NEXT_PTR ; // If RP or downstream port of SW, then use smaller linked list.
    end else if (!pb_next_ptr_wr_updated) begin
        cfg_pb_next_ptr[11:0] <= #TP (phy_type == `PHY_TYPE_MPCIE) ? `MP_PB_NEXT_PTR : ((FUNC_NUM==0) ?  `PB_NEXT_PTR_0  :  `PB_NEXT_PTR_N) ;       // If RP or upstream port of SW, then use full linked list. Device type could change if crosslink enable is true.
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : pb_cap_hdr_wr_updated_PROC
    if ( !sticky_rst_n ) begin
        pb_next_ptr_wr_updated <= #TP 1'b0;
    end else if (pb_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |write_pulse[3:2]) begin
        pb_next_ptr_wr_updated <= #TP 1'b1;
    end
end


// -----------------------------------------------------------------------------
// Data Select Register
// pb_reg_id        - 1
// PCIE Offset      - `PB_PTR + 04h
// Length           - 4 bytes
// Default value    - 0
// Cfig register    - pb_reg_07, pb_reg_06, pb_reg_05, pb_reg_04
// -----------------------------------------------------------------------------
assign {pb_reg_07, pb_reg_06, pb_reg_05}    = 24'h0;        // RsvdP
assign pb_reg_04                            = cfg_pwr_budget_data_sel_reg;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_pwr_budget_data_sel_reg <= #TP 0;
        cfg_pwr_budget_sel          <= #TP 0;
    end else begin
        if (PB_EN) begin
            cfg_pwr_budget_data_sel_reg <= #TP (write_pulse[0] & pb_reg_id[1]) ? lbc_cdm_data[7:0]   : cfg_pwr_budget_data_sel_reg;
            cfg_pwr_budget_sel          <= #TP (write_pulse[0] & pb_reg_id[1]);
        end
        else begin
            cfg_pwr_budget_data_sel_reg <= #TP 0;
            cfg_pwr_budget_sel          <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// Data Register
// pb_reg_id        - 2
// PCIE Offset      - `PB_PTR + 08h
// Length           - 4 bytes
// Default value    - 0
// Cfig register    - pb_reg_11, pb_reg_10, pb_reg_09, pb_reg_08
// -----------------------------------------------------------------------------
assign {pb_reg_11, pb_reg_10, pb_reg_09, pb_reg_08} = clked_cfg_pwr_budget_data_reg;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        clked_cfg_pwr_budget_data_reg   <= #TP 0;
    end
    else begin
        if (PB_EN)
            clked_cfg_pwr_budget_data_reg   <= #TP (cfg_pwr_budget_func_num == FUNC_NUM) ? cfg_pwr_budget_data_reg : clked_cfg_pwr_budget_data_reg;
        else
            clked_cfg_pwr_budget_data_reg   <= #TP 0;
    end
end


// -----------------------------------------------------------------------------
// Data Select Register
// pb_reg_id        - 3
// PCIE Offset      - `PB_PTR + 0Ch
// Length           - 4 bytes
// Default value    - {31'h0, `DEFAULT_PWR_BUDGET_SYS_ALLOC}
// Cfig register    - pb_reg_15, pb_reg_14, pb_reg_13, pb_reg_12
// -----------------------------------------------------------------------------
assign {pb_reg_15, pb_reg_14, pb_reg_13}    = 24'h0;                            // RsvdP
assign pb_reg_12                            = {7'h0, cfg_pwr_budget_sys_alloc};
 
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_pwr_budget_sys_alloc    <= #TP `DEFAULT_PWR_BUDGET_SYS_ALLOC;
    end else begin
        if (PB_EN) begin
            cfg_pwr_budget_sys_alloc    <= #TP (write_pulse[0] & pb_reg_id[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[0] : cfg_pwr_budget_sys_alloc;
        end
        else begin
            cfg_pwr_budget_sys_alloc <= #TP 0;
        end
    end
end
 







   generate
     if (NUM_RBARS > 0) begin : gen_cdm_rbar_reg
       cdm_rbar_reg
         #(.INST(INST),
                       .FUNC_NUM(FUNC_NUM),
                       .VF_BAR(0)
                      )
       u_cdm_rbar_reg (
                      // INPUTS
                      .core_clk             (core_clk),
                      .sticky_rst_n         (sticky_rst_n),
                      .non_sticky_rst_n     (non_sticky_rst_n),
                      .lbc_cdm_data         (lbc_cdm_data),
                      .lbc_cdm_dbi          (lbc_cdm_dbi),
                      .lbc_cdm_dbi2         (lbc_cdm_dbi2),
                      .write_pulse          (write_pulse),
                      .rbar_reg_id          (rbar_reg_id),
                      .cx_dbi_ro_wr_en          (dbi_ro_wr_en),
                      // OUTPUTS
                      .rbar_reg_data        (rbar_reg_data),
                      .rbar_bar_resizable   (cfg_rbar_bar_resizable),
                      .rbar_bar0_mask       (cfg_rbar_bar0_mask),
                      .rbar_bar1_mask       (cfg_rbar_bar1_mask),
                      .rbar_bar2_mask       (cfg_rbar_bar2_mask),
                      .rbar_bar3_mask       (cfg_rbar_bar3_mask),
                      .rbar_bar4_mask       (cfg_rbar_bar4_mask),
                      .rbar_bar5_mask       (cfg_rbar_bar5_mask),
                       .rbar_ctrl_update     (rbar_ctrl_update),
                      .cfg_rbar_size        (cfg_rbar_size)
                    );
      end else begin : gen_cdm_no_rbar_reg
         assign rbar_reg_data = 0;
         assign cfg_rbar_bar_resizable = 0;
         assign cfg_rbar_bar0_mask = 0;
         assign cfg_rbar_bar1_mask = 0;
         assign cfg_rbar_bar2_mask = 0;
         assign cfg_rbar_bar3_mask = 0;
         assign cfg_rbar_bar4_mask = 0;
         assign cfg_rbar_bar5_mask = 0;
         assign rbar_ctrl_update   = 0;
         assign cfg_rbar_size      = 0;
      end
   endgenerate

generate
     if (NUM_VF_RBARS > 0) begin : gen_cdm_vf_rbar_reg
       cdm_rbar_reg
         #(.INST(INST),
                       .FUNC_NUM(FUNC_NUM),
                       .VF_BAR(NUM_VF_RBARS)
                      )
       u_cdm_vf_rbar_reg (
                      // INPUTS
                      .core_clk             (core_clk),
                      .sticky_rst_n         (sticky_rst_n),
                      .non_sticky_rst_n     (non_sticky_rst_n),
                      .lbc_cdm_data         (lbc_cdm_data),
                      .lbc_cdm_dbi          (lbc_cdm_dbi),
                      .lbc_cdm_dbi2         (lbc_cdm_dbi2),
                      .write_pulse          (write_pulse),
                      .rbar_reg_id          (vf_rbar_reg_id),
                      .cx_dbi_ro_wr_en      (dbi_ro_wr_en),
                      // OUTPUTS
                      .rbar_reg_data        (vf_rbar_reg_data),
                      .rbar_bar_resizable   (cfg_vf_rbar_bar_resizable),
                      .rbar_bar0_mask       (cfg_vf_rbar_bar0_mask),
                      .rbar_bar1_mask       (cfg_vf_rbar_bar1_mask),
                      .rbar_bar2_mask       (cfg_vf_rbar_bar2_mask),
                      .rbar_bar3_mask       (cfg_vf_rbar_bar3_mask),
                      .rbar_bar4_mask       (cfg_vf_rbar_bar4_mask),
                      .rbar_bar5_mask       (cfg_vf_rbar_bar5_mask),
                       .rbar_ctrl_update     (vf_rbar_ctrl_update),
                      .cfg_rbar_size        (cfg_vf_rbar_size)
                    );
      end else begin : gen_cdm_no_vf_rbar_reg
         assign vf_rbar_reg_data = 0;
         assign cfg_vf_rbar_bar_resizable = 0;
         assign cfg_vf_rbar_bar0_mask = 0;
         assign cfg_vf_rbar_bar1_mask = 0;
         assign cfg_vf_rbar_bar2_mask = 0;
         assign cfg_vf_rbar_bar3_mask = 0;
         assign cfg_vf_rbar_bar4_mask = 0;
         assign cfg_vf_rbar_bar5_mask = 0;
         assign vf_rbar_ctrl_update   = 0;
         assign cfg_vf_rbar_size      = 0;
      end
   endgenerate













//
// XALI Expansion coverage
//



endmodule
