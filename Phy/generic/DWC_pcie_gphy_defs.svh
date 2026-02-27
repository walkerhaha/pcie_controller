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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_defs.svh#5 $
// -------------------------------------------------------------------------
// --- Description: defines used throughout the generic PHY codebase
// --- This files is for numeric defines only
// -------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_GPHY_DEFS__SVH__
`define __GUARD__DWC_PCIE_GPHY_DEFS__SVH__

// clock to q propagation delay
`define GPHY_TP 0.1

// enable ESM support
`define GPHY_ESM_SUPPORT

`define GPHY_IS_PIPE_44 (`GPHY_PIPE_VER >= 2)
`define GPHY_IS_PIPE_51 (`GPHY_PIPE_VER >= 3)

// powerdown encoding for the basic P-states
`define GPHY_PDOWN_P0              4'b0000
`define GPHY_PDOWN_P0S             4'b0001
`define GPHY_PDOWN_P1              4'b0010
`define GPHY_PDOWN_P2              4'b0011

// symbol encodings
`define GPHY_COM_10B_NEG           10'b0101_111100     // K28.5(-)
`define GPHY_COM_10B_POS           10'b1010_000011     // K28.5(+)
`define GPHY_SKP_10B_NEG           10'b0010_111100     // K28.0(-)
`define GPHY_SKP_10B_POS           10'b1101_000011     // K28.0(+)
`define GPHY_IDL_10B_NEG           10'b1100_111100     // K28.3(-)
`define GPHY_IDL_10B_POS           10'b0011_000011     // K28.3(+)
`define GPHY_STP_10B_POS           10'b0001_011011     // K27.7(-)
`define GPHY_STP_10B_NEG           10'b1110_100100     // K27.7(+)

`define GPHY_EDB_8B                8'hfe
`define GPHY_SKP_SYM_0             8'haa
`define GPHY_SKP_END_SYM           8'he1
`define GPHY_SKP_END_CTL_SYM       8'h78
`define GPHY_EIOS_SYM_0            8'h66
`define GPHY_EIEOS_SYM_0           8'h00
`define GPHY_EIEOS_SYM_1           8'hff
`define GPHY_SDS_SYM_0             8'he1
`define GPHY_SDS_SYM_1             8'h55


`define GPHY_SDS_SYM_1_GEN5_R07_ENC   8'h87
`define GPHY_SKP_SYM_0_GEN5_R07_ENC   8'h99

`define GPHY_SYNC_INV0_BLOCK       2'b00
`define GPHY_SYNC_OS_BLOCK         2'b01
`define GPHY_SYNC_DATA_BLOCK       2'b10
`define GPHY_SYNC_INV3_BLOCK       2'b11
`define GPHY_BASYNC_OS_BLOCK       2'b01
`define GPHY_BASYNC_DATA_BLOCK     2'b10

// ESM freq encodings
`define GPHY_ESM_RATE0_8GT         6'b000011
`define GPHY_ESM_RATE0_16GT        6'b000110
`define GPHY_ESM_RATE1_16GT        6'b000110
`define GPHY_ESM_RATE1_20GT        6'b001010
`define GPHY_ESM_RATE1_25GT        6'b001111

// PIPE size
`ifdef GPHY_PIPE51_SUPPORT
  `define GPHY_PSET_WD  6
`else
  `ifdef GPHY_PIPE44_SUPPORT
    `define GPHY_PSET_WD 5
  `else
    `define GPHY_PSET_WD 4
  `endif // GPHY_PIPE44_SUPPORT
`endif // GPHY_PIPE51_SUPPORT
`define GPHY_MAX_NB      16
`define GPHY_MAX_RXSB_WD 4


// bus widths for PIPE 5.1
`ifdef GPHY_PIPE51_SUPPORT
  `define GPHY_PIPE_DATA_WD 10
`else
  `define GPHY_PIPE_DATA_WD  8
`endif

// delay of recvdclk until is stopped in serdes mode
`define GPHY_RECVDCLK_OFF_DELAY 4
`define GPHY_LATENCY_SERDES 13
`define GPHY_RXVALID_DEASSERT_DELAY 20

// minimun and maximum time required for the PHY receiver to provide a valid feedback
`define PHY_EQ_EVAL_MIN_TIMEOUT 50
`define PHY_EQ_EVAL_MAX_TIMEOUT 500

// Local FS/LF at gen3 and gen4
`define PHY_EQ_DEFAULT_GEN3_LOCAL_FS 48
`define PHY_EQ_DEFAULT_GEN3_LOCAL_LF 18
`define PHY_EQ_DEFAULT_GEN4_LOCAL_FS 47
`define PHY_EQ_DEFAULT_GEN4_LOCAL_LF 15
`define PHY_EQ_DEFAULT_GEN5_LOCAL_FS 47
`define PHY_EQ_DEFAULT_GEN5_LOCAL_LF 15

// maximum number of fine tune attempts the VIP can make
`define MAX_FTUNE_ATTEMPTS 50

//message buss commands
`define GPHY_CMD_NOP       4'b0000
`define GPHY_CMD_WR_UC     4'b0001
`define GPHY_CMD_WR_C      4'b0010
`define GPHY_CMD_RD        4'b0011
`define GPHY_CMD_RD_CPL    4'b0100
`define GPHY_CMD_WR_ACK    4'b0101

// message bus register address(PHY Registers)
`define GPHY_PHY_REG_RX_MARGIN_CONTROL0 12'h000 // RX1: RX Margin Control0
`define GPHY_PHY_REG_RX_MARGIN_CONTROL1 12'h001 // RX1: RX Margin Control1
`define GPHY_PHY_REG_EBUF_CONTROL       12'h002 // RX1: Elastic Buffer Control
`define GPHY_PHY_REG_PHY_RX_CONTROL0    12'h003 // RX1: PHY RX Control0
`define GPHY_PHY_REG_PHY_RX_CONTROL3    12'h006 // RX1: PHY RX Control3
`define GPHY_PHY_REG_EBUF_LOC_UPD_FREQ  12'h007 // RX1: Elastic Buffer Location Update Frequency
`define GPHY_PHY_REG_PHY_RX_CONTROL4    12'h008 // RX1: PHY RX Control4
`define GPHY_PHY_REG_PHY_TX_CONTROL2    12'h402 // TX1: PHY TX Control2
`define GPHY_PHY_REG_PHY_TX_CONTROL3    12'h403 // TX1: PHY TX Control3
`define GPHY_PHY_REG_PHY_TX_CONTROL4    12'h404 // TX1: PHY TX Control4
`define GPHY_PHY_REG_PHY_TX_CONTROL5    12'h405 // TX1: PHY TX Control5
`define GPHY_PHY_REG_PHY_TX_CONTROL6    12'h406 // TX1: PHY TX Control6
`define GPHY_PHY_REG_PHY_TX_CONTROL7    12'h407 // TX1: PHY TX Control7
`define GPHY_PHY_REG_PHY_TX_CONTROL8    12'h408 // TX1: PHY TX Control8
`define GPHY_PHY_REG_PHY_CMN_CONTROL0   12'h800 // CMN1: PHY Common Control0
`define GPHY_PHY_REG_VDR_ESM_RATE0      12'hF00 // VDR: ESM Rate0
`define GPHY_PHY_REG_VDR_ESM_RATE1      12'hF01 // VDR: ESM Rate1
`define GPHY_PHY_REG_VDR_ESM_CONTROL    12'hF02 // VDR: ESM Control

// message bus register address(MAC Registers)
`define GPHY_MAC_REG_RX_MARIN_STATUS0           12'h000 // RX1: RX Margin Status0
`define GPHY_MAC_REG_RX_MARIN_STATUS1           12'h001 // RX1: RX Margin Status1
`define GPHY_MAC_REG_RX_MARIN_STATUS2           12'h002 // RX1: RX Margin Status2
`define GPHY_MAC_REG_EBUF_STATUS                12'h003 // RX1: Elastic Buffer Status
`define GPHY_MAC_REG_EBUF_LOCATION              12'h004 // RX1: Elastic Buffer Location
`define GPHY_MAC_REG_RX_LINK_EVAL_STATUS0       12'h00A // RX1: RX Link Evaluation Status0
`define GPHY_MAC_REG_RX_LINK_EVAL_STATUS1       12'h00B // RX1: RX Link Evaluation Status1
`define GPHY_MAC_REG_TX_STATUS0                 12'h400 // TX1: TX Status0
`define GPHY_MAC_REG_TX_STATUS1                 12'h401 // TX1: TX Status1
`define GPHY_MAC_REG_TX_STATUS2                 12'h402 // TX1: TX Status2
`define GPHY_MAC_REG_TX_STATUS3                 12'h403 // TX1: TX Status3
`define GPHY_MAC_REG_TX_STATUS4                 12'h404 // TX1: TX Status4
`define GPHY_MAC_REG_TX_STATUS5                 12'h405 // TX1: TX Status5
`define GPHY_MAC_REG_TX_STATUS6                 12'h406 // TX1: TX Status6
`ifdef GPHY_PIPE51_X_REG_MAP
`define GPHY_MAC_REG_TX_STATUS7                 12'h407 // TX1: TX Status7
`define GPHY_MAC_REG_TX_STATUS8                 12'h408 // TX1: TX Status8
`else // GPHY_PIPE51_X_REG_MAP
`define GPHY_MAC_REG_TX_STATUS7                 12'h00c
`define GPHY_MAC_REG_TX_STATUS8                 12'h00d
`endif // GPHY_PIPE51_X_REG_MAP
`define GPHY_MAC_REG_VDR_ESM_CALIBRATE_COMPLETE 12'hF00 // VDR : ESM Calibration Complete

// Number of cycle for message type
`define GPHY_NCYCLE_WR      3
`define GPHY_NCYCLE_RD      2
`define GPHY_NCYCLE_RD_CPL  2
`define GPHY_NCYCLE_WR_ACK  1

//Margining Modes
`define GPHY_FIXED_MODE    2'b00
`define GPHY_PERIOD_MODE   2'b01
`define GPHY_BER_MODE      2'b10



`define GPHY_CCIX_OFFSET  12'hF00

`endif // __GUARD__DWC_PCIE_GPHY_DEFS__SVH__
