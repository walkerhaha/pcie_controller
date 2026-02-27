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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/include/port_cfg.svh#14 $
// -------------------------------------------------------------------------
// --- Module Description:
// ---
// --- This file re-configure CDM and the PHY
// -----------------------------------------------------------------------------

`ifndef __GUARD__PORT_CFG__SVH__
`define __GUARD__PORT_CFG__SVH__

`define PCIE_UNUSED_RESPONSE                `CX_UNUSED_RESPONSE             // (Renaming)  Value device responds with on reads to unused addresses
//com_def `define CX_DBI_RO_WR_EN                     1'b0                            // When set to 1, allows writes to Read-Only register through DBI

// #############################################################################
// Addressing
// #############################################################################
`define NULL                                8'h00                           // For the end of list
                                                                            // Exact address
`define CFG_REG_OFFSET                      4'h0                            // 0x00
`define ECFG_REG_OFFSET                     4'h1                            // 0x100
`define PL_REG_OFFSET                       4'h7                            // 0x700
`define CRGB_BASE_ADDR                      12'h970                         // 0x970 --CRGB Start Address 
`define CRGB_RANGE                          12'h13c                         // 0xAAC --CRGB End Address

// Unroll Registers
`define CFG_DMA_CAP_REG                      20'h80000
`define CFG_HDMA_CAP_REG                     20'h80000
`define CFG_ATU_CAP_REG                      20'h00000
//
// Port Logic Registers
`define CFG_PL_REG                          {`PL_REG_OFFSET, 8'h0}          // 0x700

// VF RAM and Flop indexing

`define VF_RAM_RTA_FO 0
`define VF_RAM_RMA_FO  `VF_RAM_RTA_FO  + `VF_RAM_RTA_WIDTH
`define VF_RAM_DPE_FO  `VF_RAM_RMA_FO  + `VF_RAM_RMA_WIDTH

`define VF_RAM_RTA_RANGE        `VF_RAM_RTA_WIDTH       + `VF_RAM_RTA_FO        -1 : `VF_RAM_RTA_FO
`define VF_RAM_RMA_RANGE        `VF_RAM_RMA_WIDTH       + `VF_RAM_RMA_FO        -1 : `VF_RAM_RMA_FO
`define VF_RAM_DPE_RANGE        `VF_RAM_DPE_WIDTH       + `VF_RAM_DPE_FO        -1 : `VF_RAM_DPE_FO

`define VF_FLOP_NF_ERR_DET_FO     0
`define VF_FLOP_F_ERR_DET_FO      `VF_FLOP_NF_ERR_DET_FO     + `VF_FLOP_NF_ERR_DET_WIDTH
`define VF_FLOP_COR_ERR_DET_FO    `VF_FLOP_F_ERR_DET_FO      + `VF_FLOP_F_ERR_DET_WIDTH
`define VF_FLOP_BME_FO            `VF_FLOP_COR_ERR_DET_FO    + `VF_FLOP_COR_ERR_DET_WIDTH
`define VF_FLOP_MSIX_EN_FO        `VF_FLOP_BME_FO            + `VF_FLOP_BME_WIDTH
`define VF_FLOP_MSIX_FUNC_MASK_FO `VF_FLOP_MSIX_EN_FO        + `VF_FLOP_MSIX_EN_WIDTH
`define VF_FLOP_UNSUPT_REQ_DET_FO `VF_FLOP_MSIX_FUNC_MASK_FO + `VF_FLOP_MSIX_FUNC_MASK_WIDTH
`define VF_FLOP_SIGNALED_TARGET_ABT_FO `VF_FLOP_UNSUPT_REQ_DET_FO + `VF_FLOP_UNSUPT_REQ_DET_WIDTH
`define VF_FLOP_MASTER_DATA_PERR_FO `VF_FLOP_SIGNALED_TARGET_ABT_FO + `VF_FLOP_SIGNALED_TARGET_ABT_WIDTH
`define VF_FLOP_SSERR_FO `VF_FLOP_MASTER_DATA_PERR_FO + `VF_FLOP_MASTER_DATA_PERR_WIDTH

// these are relative to the flop bus only 
`define VF_FLOP_NF_ERR_DET_RANGE     `VF_FLOP_NF_ERR_DET_WIDTH     + `VF_FLOP_NF_ERR_DET_FO     -1 : `VF_FLOP_NF_ERR_DET_FO
`define VF_FLOP_F_ERR_DET_RANGE      `VF_FLOP_F_ERR_DET_WIDTH      + `VF_FLOP_F_ERR_DET_FO      -1 : `VF_FLOP_F_ERR_DET_FO
`define VF_FLOP_COR_ERR_DET_RANGE    `VF_FLOP_COR_ERR_DET_WIDTH    + `VF_FLOP_COR_ERR_DET_FO    -1 : `VF_FLOP_COR_ERR_DET_FO
`define VF_FLOP_BME_RANGE            `VF_FLOP_BME_WIDTH            + `VF_FLOP_BME_FO            -1 : `VF_FLOP_BME_FO
`define VF_FLOP_MSIX_EN_RANGE        `VF_FLOP_MSIX_EN_WIDTH        + `VF_FLOP_MSIX_EN_FO        -1 : `VF_FLOP_MSIX_EN_FO
`define VF_FLOP_MSIX_FUNC_MASK_RANGE `VF_FLOP_MSIX_FUNC_MASK_WIDTH + `VF_FLOP_MSIX_FUNC_MASK_FO -1 : `VF_FLOP_MSIX_FUNC_MASK_FO
`define VF_FLOP_UNSUPT_REQ_DET_RANGE `VF_FLOP_UNSUPT_REQ_DET_WIDTH + `VF_FLOP_UNSUPT_REQ_DET_FO -1 : `VF_FLOP_UNSUPT_REQ_DET_FO
`define VF_FLOP_SIGNALED_TARGET_ABT_RANGE `VF_FLOP_SIGNALED_TARGET_ABT_WIDTH + `VF_FLOP_SIGNALED_TARGET_ABT_FO -1 : `VF_FLOP_SIGNALED_TARGET_ABT_FO
`define VF_FLOP_MASTER_DATA_PERR_RANGE `VF_FLOP_MASTER_DATA_PERR_WIDTH + `VF_FLOP_MASTER_DATA_PERR_FO -1 : `VF_FLOP_MASTER_DATA_PERR_FO
`define VF_FLOP_SSERR_RANGE `VF_FLOP_SSERR_WIDTH + `VF_FLOP_SSERR_FO -1 : `VF_FLOP_SSERR_FO

// these are relative to the full bus (the flop bits are above the vf_ram bits)
`define VF_FLOP_NF_ERR_DET_FULL_RANGE     `VF_RAM_DATABITS + `VF_FLOP_NF_ERR_DET_WIDTH     + `VF_FLOP_NF_ERR_DET_FO     -1 : `VF_RAM_DATABITS + `VF_FLOP_NF_ERR_DET_FO
`define VF_FLOP_F_ERR_DET_FULL_RANGE      `VF_RAM_DATABITS + `VF_FLOP_F_ERR_DET_WIDTH      + `VF_FLOP_F_ERR_DET_FO      -1 : `VF_RAM_DATABITS + `VF_FLOP_F_ERR_DET_FO
`define VF_FLOP_COR_ERR_DET_FULL_RANGE    `VF_RAM_DATABITS + `VF_FLOP_COR_ERR_DET_WIDTH    + `VF_FLOP_COR_ERR_DET_FO    -1 : `VF_RAM_DATABITS + `VF_FLOP_COR_ERR_DET_FO
`define VF_FLOP_BME_FULL_RANGE            `VF_RAM_DATABITS + `VF_FLOP_BME_WIDTH            + `VF_FLOP_BME_FO            -1 : `VF_RAM_DATABITS + `VF_FLOP_BME_FO
`define VF_FLOP_MSIX_EN_FULL_RANGE        `VF_RAM_DATABITS + `VF_FLOP_MSIX_EN_WIDTH        + `VF_FLOP_MSIX_EN_FO        -1 : `VF_RAM_DATABITS + `VF_FLOP_MSIX_EN_FO
`define VF_FLOP_MSIX_FUNC_MASK_FULL_RANGE `VF_RAM_DATABITS + `VF_FLOP_MSIX_FUNC_MASK_WIDTH + `VF_FLOP_MSIX_FUNC_MASK_FO -1 : `VF_RAM_DATABITS + `VF_FLOP_MSIX_FUNC_MASK_FO
`define VF_FLOP_UNSUPT_REQ_DET_FULL_RANGE `VF_RAM_DATABITS + `VF_FLOP_UNSUPT_REQ_DET_WIDTH + `VF_FLOP_UNSUPT_REQ_DET_FO -1 : `VF_RAM_DATABITS + `VF_FLOP_UNSUPT_REQ_DET_FO
`define VF_FLOP_SIGNALED_TARGET_ABT_FULL_RANGE `VF_RAM_DATABITS + `VF_FLOP_SIGNALED_TARGET_ABT_WIDTH + `VF_FLOP_SIGNALED_TARGET_ABT_FO -1 : `VF_RAM_DATABITS + `VF_FLOP_SIGNALED_TARGET_ABT_FO
`define VF_FLOP_MASTER_DATA_PERR_FULL_RANGE `VF_RAM_DATABITS + `VF_FLOP_MASTER_DATA_PERR_WIDTH + `VF_FLOP_MASTER_DATA_PERR_FO -1 : `VF_RAM_DATABITS + `VF_FLOP_MASTER_DATA_PERR_FO
`define VF_FLOP_SSERR_FULL_RANGE `VF_RAM_DATABITS + `VF_FLOP_SSERR_WIDTH + `VF_FLOP_SSERR_FO -1 : `VF_RAM_DATABITS + `VF_FLOP_SSERR_FO

// -----------------------------------------------------------------------------
// Extended Configuration Space Register
// Current configuration:
// Advanced Error Reporting Capability      0x100 - 0x140
// Virtual Channel Capability               0x140 - (0x140 + 0x10 + (CX_NVC * 0x0C))
// Device Serial Number Capability
// -----------------------------------------------------------------------------
// Extended Capabilities
// ---------------------
/* Extanded Capabilities are ordered as follows: 

       For Function 0:                                    AER VC DSN PB ARI SPCIE SRIOV TPH ATS ACS PRS LTR L1SUB PASID DPA MPCIE FRSQ RTR LN RAS_DES RASDP DLINK PTM PTM_VSEC CCIX_TP CXS VSECDMA RBAR  
       For all other Functions (in multifunction device): AER    DSN PB ARI       SRIOV TPH ATS     PRS           PASID DPA       FRSQ RTR LN RAS_DES RASDP       PTM PTM_VSEC CCIX_TP CXS VSECDMA RBAR   
       For the DM product, those capabilities which are EP only must be explicitly hidden in RP mode. Hence, a separate 
       linked list is used for DM products when configured in RP mode. See DM_RP_*_NEXT_PTR macros below.
       
   NOTE that new Capabilities, when implemented, must be placed in front of RBAR (so RBAR is always last in the linked list;
        this is because CX_NUM_RBARS will not be calculated until RBAR_NEXT_PTR macro is invoked.
*/
`define EXT_CAP_HDR                         12'h100                         // Extended Cfg starts at 0x100


// -----------------------------------------------------------------------------
// Port Logic Registers
// Starts at `CFG_PL_REG
// -----------------------------------------------------------------------------
`define PL_REG_DECODE_SIZE                  6
`define ACK_TIMER_OFFSETS                   {4'h0,2'b0}
`define OTHER_MSG_OFFSETS                   {4'h1,2'b0}
`define LINK_STS_OFFSETS                    {4'h2,2'b0}
`define ACK_FREQ_OFFSETS                    {4'h3,2'b0}
`define MODE_OFFSETS                        {4'h4,2'b0}
`define LANE_SKEW_OFFSETS                   {4'h5,2'b0}
`define TS_SYMBOL_NUM_OFFSETS               {4'h6,2'b0}
`define TS_SYMBOL_TIMER_OFFSETS             {4'h7,2'b0}
`define PHY_STATUS_OFFSETS                  {4'h8,2'b0}
`define PHY_CTRL_OFFSETS                    {4'h9,2'b0}
`define CXPL_DEBUG0_OFFSETS                 {4'hA,2'b0}
`define CXPL_DEBUG1_OFFSETS                 {4'hB,2'b0}

// #############################################################################
// Default Values
// NOTE: When instantiating multiple ports, use INST to differentiate between ports
// #############################################################################


// =============================================================================
// Configuration Space Registers
// =============================================================================
// Vendor/Device ID
`define DEFAULT_DEVICE_ID                   `CX_DEVICE_ID
`define DEFAULT_VENDOR_ID                   `CX_VENDOR_ID
// Revision ID
`define DEFAULT_REV_ID                      `CX_REVISION_ID

// -----------------------------------------------------------------------------
// Power Management Capability
// -----------------------------------------------------------------------------
`define PMC_VERSION                         3'b011          // compliance with 1.2 version of PCI Bus PM spec.

// -----------------------------------------------------------------------------
// PCI Express Capability
// -----------------------------------------------------------------------------
// -- Device Capability
`define DEFAULT_MAX_PAYLOAD_SIZE_SUPPORTED  ((`CX_MAX_MTU == 4096) ? 3'b101 : (`CX_MAX_MTU == 2048) ? 3'b100 : (`CX_MAX_MTU == 1024) ? 3'b011 : (`CX_MAX_MTU ==  512) ? 3'b010 : (`CX_MAX_MTU ==  256) ? 3'b001 : (`CX_MAX_MTU ==  128) ? 3'b000 : 3'b000)
// -- Link Capability               By default, support all widths between 1 and MAX (except x12)
    `define MAX_LINK_WIDTH                  ((NL==16) ? 6'b010000 : (NL==8) ? 6'b001000 : (NL==4) ? 6'b000100 : (NL==2) ? 6'b000010 : (NL==1) ? 6'b000001 : 6'b111111)


// =============================================================================
// Extended PCI Express Capabilities
// =============================================================================
// -----------------------------------------------------------------------------
// Advanced Error Reporting Capability
// -----------------------------------------------------------------------------
`define PCIE_AER_ECAP_ID                    16'h0001        // Indicates Advanced Error Ext Cap ID
`define PCIE_AER_ECAP_VER                   4'h2            // Indicates Advanced Error Ext Cap Version

// -----------------------------------------------------------------------------
// Virtual Channel Enhanced Capability
// -----------------------------------------------------------------------------
`define PCIE_VC_ECAP_ID                     16'h0002        // Indicates VC Ext Cap ID
`define PCIE_VC_ECAP_VER                    4'h1            // Indicates VC Ext Cap Version
`define DEFAULT_EXT_VC_CNT                  (`CX_NVC - 4'd1)   // # of extra VCs supported
`define DEFAULT_VC_REF_CLK                  2'b00           // 100 ns reference clock
`define DEFAULT_PORT_ARB_TABLE_SIZE         2'b00           // Port Arbitration Table Size = 1 (set to 0 for EP & RC)
    // VC0
`define DEFAULT_PORT_ARB_CAP_VC0            8'h01           // Port Arbiration Capability = HW defined (others not supported)
`define DEFAULT_AS_ONLY_VC0                 1'b0            // Support AS packets only (not supported)
`define DEFAULT_REJECT_NO_SNOOP_VC0         1'b0            // Reject packet without No-Snoop bit (not supported)
`define DEFAULT_MAX_TIME_SLOTS_VC0          7'h00           // Not supported since WRR not supported
`define DEFAULT_PORT_ARB_TABLE_OFFSET_VC0   8'h00           // No arbitration table present (table not supported)
    // VC1
`define DEFAULT_PORT_ARB_CAP_VC1            8'h01           // Port Arbiration Capability = HW defined (others not supported)
`define DEFAULT_AS_ONLY_VC1                 1'b0            // Support AS packets only (not supported)
`define DEFAULT_REJECT_NO_SNOOP_VC1         1'b0            // Reject packet without No-Snoop bit (not supported)
`define DEFAULT_MAX_TIME_SLOTS_VC1          7'h00           // Not supported since WRR not supported
`define DEFAULT_PORT_ARB_TABLE_OFFSET_VC1   8'h00           // No arbitration table present (table not supported)
    // VC2
`define DEFAULT_PORT_ARB_CAP_VC2            8'h01           // Port Arbiration Capability = HW defined (others not supported)
`define DEFAULT_AS_ONLY_VC2                 1'b0            // Support AS packets only (not supported)
`define DEFAULT_REJECT_NO_SNOOP_VC2         1'b0            // Reject packet without No-Snoop bit (not supported)
`define DEFAULT_MAX_TIME_SLOTS_VC2          7'h00           // Not supported since WRR not supported
`define DEFAULT_PORT_ARB_TABLE_OFFSET_VC2   8'h00           // No arbitration table present (table not supported)
    // VC3
`define DEFAULT_PORT_ARB_CAP_VC3            8'h01           // Port Arbiration Capability = HW defined (others not supported)
`define DEFAULT_AS_ONLY_VC3                 1'b0            // Support AS packets only (not supported)
`define DEFAULT_REJECT_NO_SNOOP_VC3         1'b0            // Reject packet without No-Snoop bit (not supported)
`define DEFAULT_MAX_TIME_SLOTS_VC3          7'h00           // Not supported since WRR not supported
`define DEFAULT_PORT_ARB_TABLE_OFFSET_VC3   8'h00           // No arbitration table present (table not supported)
    // VC4
`define DEFAULT_PORT_ARB_CAP_VC4            8'h01           // Port Arbiration Capability = HW defined (others not supported)
`define DEFAULT_AS_ONLY_VC4                 1'b0            // Support AS packets only (not supported)
`define DEFAULT_REJECT_NO_SNOOP_VC4         1'b0            // Reject packet without No-Snoop bit (not supported)
`define DEFAULT_MAX_TIME_SLOTS_VC4          7'h00           // Not supported since WRR not supported
`define DEFAULT_PORT_ARB_TABLE_OFFSET_VC4   8'h00           // No arbitration table present (table not supported)
    // VC5
`define DEFAULT_PORT_ARB_CAP_VC5            8'h01           // Port Arbiration Capability = HW defined (others not supported)
`define DEFAULT_AS_ONLY_VC5                 1'b0            // Support AS packets only (not supported)
`define DEFAULT_REJECT_NO_SNOOP_VC5         1'b0            // Reject packet without No-Snoop bit (not supported)
`define DEFAULT_MAX_TIME_SLOTS_VC5          7'h00           // Not supported since WRR not supported
`define DEFAULT_PORT_ARB_TABLE_OFFSET_VC5   8'h00           // No arbitration table present (table not supported)
    // VC6
`define DEFAULT_PORT_ARB_CAP_VC6            8'h01           // Port Arbiration Capability = HW defined (others not supported)
`define DEFAULT_AS_ONLY_VC6                 1'b0            // Support AS packets only (not supported)
`define DEFAULT_REJECT_NO_SNOOP_VC6         1'b0            // Reject packet without No-Snoop bit (not supported)
`define DEFAULT_MAX_TIME_SLOTS_VC6          7'h00           // Not supported since WRR not supported
`define DEFAULT_PORT_ARB_TABLE_OFFSET_VC6   8'h00           // No arbitration table present (table not supported)
    // VC7
`define DEFAULT_PORT_ARB_CAP_VC7            8'h01           // Port Arbiration Capability = HW defined (others not supported)
`define DEFAULT_AS_ONLY_VC7                 1'b0            // Support AS packets only (not supported)
`define DEFAULT_REJECT_NO_SNOOP_VC7         1'b0            // Reject packet without No-Snoop bit (not supported)
`define DEFAULT_MAX_TIME_SLOTS_VC7          7'h00           // Not supported since WRR not supported
`define DEFAULT_PORT_ARB_TABLE_OFFSET_VC7   8'h00           // No arbitration table present (table not supported)

// -----------------------------------------------------------------------------
// L1 Substates Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_L1SUB_ECAP_ID                  16'h001E        // Indicates L1 Substates Ext Cap ID
`define PCIE_L1SUB_ECAP_VER                 4'h1            // Indicates L1 Substates Ext Cap Version

// -----------------------------------------------------------------------------
// Secondary PCI Express Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_SPCIE_ECAP_ID                  16'h0019        // Indicates SPCIE Ext Cap ID
`define PCIE_SPCIE_ECAP_VER                 4'h1            // Indicates SPCIE Ext Cap Version

// -----------------------------------------------------------------------------
// Physical Layer 16.0 GT/s Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_PL16G_ECAP_ID                  16'h0026        // Indicates PL16G Ext Cap ID
`define PCIE_PL16G_ECAP_VER                 4'h1            // Indicates PL16G Ext Cap Version

// -----------------------------------------------------------------------------
// Margining Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_MARGIN_ECAP_ID                 16'h0027        // Indicates MARGIN Ext Cap ID
`define PCIE_MARGIN_ECAP_VER                4'h1            // Indicates MARGIN Ext Cap Version

// -----------------------------------------------------------------------------
// Physical Layer 32.0 GT/s Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_PL32G_ECAP_ID                  16'h002A        // Indicates PL32G Ext Cap ID
`define PCIE_PL32G_ECAP_VER                 4'h1            // Indicates PL32G Ext Cap Version

// -----------------------------------------------------------------------------
// SR-IOV Capability
// -----------------------------------------------------------------------------
`define PCIE_SRIOV_ECAP_ID                  16'h0010        // Indicates SR-IOV Ext Cap ID
`define PCIE_SRIOV_ECAP_VER                 4'h1            // Indicates SR-IOV Ext Cap Version

`define SRIOV_VF_MIGRATION_ENABLE           1'h0            // VF Migration not supported
`define SRIOV_VF_MIGRATION_INT_MSG_NUM      11'h0           // VF Migration Interrupt Message Number undefined if SRIOV_VF_MIGRATION_ENABLE is 0

// -----------------------------------------------------------------------------
// TPH Capability
// -----------------------------------------------------------------------------
`define PCIE_TPH_ECAP_ID                  16'h0017        // Indicates TPH Ext Cap ID
`define PCIE_TPH_ECAP_VER                 4'h1            // Indicates TPH Ext Cap Version

// -----------------------------------------------------------------------------
// ATS Capability
// -----------------------------------------------------------------------------
`define PCIE_ATS_ECAP_ID                  16'h000F        // Indicates ATS Ext Cap ID
`define PCIE_ATS_ECAP_VER                 4'h1            // Indicates ATS Ext Cap Version

// -----------------------------------------------------------------------------
// ACS Capability
// -----------------------------------------------------------------------------
`define PCIE_ACS_ECAP_ID                  16'h000D        // Indicates ACS Ext Cap ID
`define PCIE_ACS_ECAP_VER                 4'h1            // Indicates ACS Ext Cap Version

// -----------------------------------------------------------------------------
// PRS Capability
// -----------------------------------------------------------------------------
`define PCIE_PRS_ECAP_ID                  16'h0013        // Indicates PRS Ext Cap ID
`define PCIE_PRS_ECAP_VER                 4'h1            // Indicates PRS Ext Cap Version

// -----------------------------------------------------------------------------
// LTR Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_LTR_ECAP_ID                  16'h0018        // Indicates LTR Ext Cap ID
`define PCIE_LTR_ECAP_VER                 4'h1            // Indicates LTR Ext Cap Version

// -----------------------------------------------------------------------------
// Resizable BAR Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_RBAR_ECAP_ID                  16'h0015        // Indicates Resizable BAR Ext Cap ID
`define PCIE_RBAR_ECAP_VER                 4'h1            // Indicates Resizable BAR Ext Cap Version

// -----------------------------------------------------------------------------
// VF Resizable BAR Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_VF_RBAR_ECAP_ID               16'h0024        // Indicates VF Resizable BAR Ext Cap ID
`define PCIE_VF_RBAR_ECAP_VER              4'h1            // Indicates VF Resizable BAR Ext Cap Version

// -----------------------------------------------------------------------------
// PASID Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_PASID_ECAP_ID                  16'h001B        // Indicates PASID Ext Cap ID
`define PCIE_PASID_ECAP_VER                 4'h1            // Indicates PASID Ext Cap Version

// -----------------------------------------------------------------------------
// DPA Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_DPA_ECAP_ID                  16'h0016        // Indicates DPA Ext Cap ID
`define PCIE_DPA_ECAP_VER                 4'h1            // Indicates DPA Ext Cap Version

// -----------------------------------------------------------------------------
// DPC Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_DPC_ECAP_ID                  16'h001D        // Indicates DPC Ext Cap ID
`define PCIE_DPC_ECAP_VER                 4'h1            // Indicates DPC Ext Cap Version

// -----------------------------------------------------------------------------
// LN Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_LN_ECAP_ID                  16'h001C        // Indicates LN Ext Cap ID
`define PCIE_LN_ECAP_VER                 4'h1            // Indicates LN Ext Cap Version

// -----------------------------------------------------------------------------
// M-PCIe Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_MPCIE_ECAP_ID                  16'h0020       // Indicates M-PCIe Ext Cap ID 
`define PCIE_MPCIE_ECAP_VER                 4'h1           // Indicates M-PCIe Ext Cap Version


// -----------------------------------------------------------------------------
// RAS D.E.S. Vendor Specific Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_RAS_DES_ECAP_ID                16'h000B       // Indicates RAS D.E.S. Vendor-Specific Ext Cap ID 
`define PCIE_RAS_DES_ECAP_VER               4'h1           // Indicates RAS D.E.S. Vendor-Specific Ext Cap Version
`define PCIE_RAS_DES_VSEC_ID                16'h0002       // Indicates RAS D.E.S. Vendor-Specific Ext Cap VSEC ID
`define PCIE_RAS_DES_VSEC_REV               4'h4           // Indicates RAS D.E.S. Vendor-Specific Ext Cap VSEC Rev
`define PCIE_RAS_DES_VSEC_LEN               12'h100        // Indicates RAS D.E.S. Vendor-Specific Ext Cap VSEC Length

// RAS D.E.S. specific register
`define TIME_CPCIE_1MS                      (18'd250000 / `CX_FREQ_MULTIPLIER) - 1
`define TIME_MPCIE_RATEA_1MS                (18'd124798 / `CX_FREQ_MULTIPLIER) - 1
`define TIME_MPCIE_RATEB_1MS                (18'd145752 / `CX_FREQ_MULTIPLIER) - 1
// Malformed TLP pointer
`define MFPTR_NO_ERR                        8'h00          // No errors
`define MFPTR_ATOM_ADR                      8'h01          // AtomicOp address alignment
`define MFPTR_ATOM_OPR                      8'h02          // AtomicOp operand size
`define MFPTR_ATOM_BE                       8'h03          // AtomicOp  byte enable
`define MFPTR_TLP_DLEN                      8'h04          // TLP Data length miss match
`define MFPTR_TLP_HLEN                      8'h04          // TLP Header length miss match
`define MFPTR_TLP_MXPL                      8'h05          // TLP Max payload size
`define MFPTR_MSG_TC0                       8'h06          // Message TLP without TC0
`define MFPTR_TLP_TC                        8'h07          // Invalid TC
`define MFPTR_MSG_R                         8'h08          // Unexpected route bit in Message TLP
`define MFPTR_CPL_CRS                       8'h09          // Unexpected CRS status in Completion TLP
`define MFPTR_TLP_BE                        8'h0A          // Byte enable rules
`define MFPTR_TLP_4KBND                     8'h0B          // Memory Address 4KB boundary
`define MFPTR_PFX                           8'h0C          // TLP prefix rules
`define MFPTR_TLP_ELEN                      8'h04          // No ECRC with set TD
`define MFPTR_ATS                           8'h0D          // Translation request rules
`define MFPTR_TLP_TYP                       8'h0E          // Invalid TLP type
`define MFPTR_CPL                           8'h0F          // Completion rules
`define MFPTR_APL                           7'h7F          // Errors detected in application

// VSEC RAS Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_VSEC_ECAP_ID                    16'h000B       // Indicates RAS Ext Cap ID 
`define PCIE_VSEC_ECAP_VER                   4'h1           // Indicates RAS Ext Cap Version

`define DEFAULT_VSEC_RASDP_ID                16'h0001
`define DEFAULT_VSEC_RASDP_REV               4'h1
`define DEFAULT_VSEC_RASDP_LENGTH            12'h038       // 56bytes length

// VSEC DMA Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_VSECDMA_ECAP_ID                    16'h000B       // Indicates DMA VSEC Ext Cap ID 
`define PCIE_VSECDMA_ECAP_VER                   4'h1           // Indicates DMA VSEC Ext Cap Version
`define DEFAULT_VSECDMA_ID                     16'h0006
`define DEFAULT_VSECDMA_REV                    4'h0
`define DEFAULT_VSECDMA_LENGTH                 12'h018        // 

// -----------------------------------------------------------------------------
// FRS Queue Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_FRSQ_ECAP_ID                  16'h0021        // Indicates FRS Queue Ext Cap ID
`define PCIE_FRSQ_ECAP_VER                 4'h1            // Indicates FRS Queue Ext Cap Version


// -----------------------------------------------------------------------------
// RTR Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_RTR_ECAP_ID                  16'h0022        // Indicates RTR Ext Cap ID
`define PCIE_RTR_ECAP_VER                 4'h1            // Indicates RTR Ext Cap Version


// -----------------------------------------------------------------------------
// PTM Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_PTM_ECAP_ID                  16'h001F        // Indicates PTM Ext Cap ID
`define PCIE_PTM_ECAP_VER                 4'h1            // Indicates PTM Ext Cap Version


`define PCIE_PTM_REQ_REV                  4'h1                 
`define PCIE_PTM_REQ_ID                   16'h0003

`define PCIE_PTM_RES_REV                  4'h1  
`define PCIE_PTM_RES_ID                   16'h0004
// Capability length is different between requester and responder

// -----------------------------------------------------------------------------
// CCIX Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_CCIX_ECAP_ID                 16'h0023        // Indicates CCIX Ext Cap ID
`define PCIE_CCIX_ECAP_VER                4'h1            // Indicates CCIX Ext Cap Version
`define PCIE_CCIX_ID                      16'h0001
`define PCIE_CCIX_DVSEC_ID0               16'h0
`define PCIE_CCIX_TP_VER                  4'h1            // Indicates CCIX Ext Cap Version

// -----------------------------------------------------------------------------
// CXS Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_CXS_ECAP_ID                  16'h000B        // Indicates CXS Ext Cap ID
`define PCIE_CXS_ECAP_VER                 4'h1            // Indicates CXS Ext Cap Version
`define PCIE_CXS_VSEC_ID                  16'h0005        // Indicates CXS VSEC ID
`define PCIE_CXS_VSEC_REV                 4'h1            // Indicates CXS VSEC Revision

// -----------------------------------------------------------------------------
// DLINK Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_DLINK_ECAP_ID                  16'h0025        // Indicates DLINK Ext Cap ID
`define PCIE_DLINK_ECAP_VER                 4'h1            // Indicates DLINK Ext Cap Version

// -----------------------------------------------------------------------------
// NPEM Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_NPEM_ECAP_ID                  16'h0029        // Indicates NPEM Ext Cap ID
`define PCIE_NPEM_ECAP_VER                 4'h1            // Indicates NPEM Ext Cap Version

// -----------------------------------------------------------------------------
// DEV3 Extended Capability
// -----------------------------------------------------------------------------
`define PCIE_DEV3_ECAP_ID                  16'h002F        // Indicates DEV3 Ext Cap ID
`define PCIE_DEV3_ECAP_VER                 4'h1            // Indicates DEV3 Ext Cap Version

// =============================================================================
// Port Logic Register
// =============================================================================
// Other Message
`define DEFAULT_REQ_OTHER_MSG               32'hFFFF_FFFF
// Port Link Control
    `define DEFAULT_SCRAMBLE_DISABLE            1'b0
`define DEFAULT_LOOPBACK_ENABLE             1'b0
`define DEFAULT_PIPE_LOOPBACK               1'b0
`define DEFAULT_RESET_ASSERT                1'b0
`define DEFAULT_DLL_LINK_ENABLE             1'b1
`define DEFAULT_LINK_DISABLE                1'b0
`define DEFAULT_LINK_RATE                   4'b0001         // 2.5G
`define DEFAULT_BEACON_ENABLE               1'b0
`define DEFAULT_LINK_CAPABLE                ((NL==16) ? 6'b011111 : (NL==8) ? 6'b001111 : (NL==4) ? 6'b000111 : (NL==2) ? 6'b000011 : (NL==1) ? 6'b000001 : 6'b111111)
`define DEFAULT_FAST_LINK_ENABLE            1'b0
// Symbol Number
`define DEFAULT_N_TS1_SYMBOLS               4'hA            // A means 10 TS1 or TS2 symbols
`define DEFAULT_N_TS2_SYMBOLS               4'hA
`define DEFAULT_N_SKIP_SYMBOLS              3'b011          // This parameter is defined as the number of skip cycles after comma
`define DEFAULT_N_EIDLE_SYMBOLS             3'b1            // Same of above for skip applied to eidle
// Symbol Timer
`define DEFAULT_SKIP_INTERVAL               (11'd1280/`CX_PL_FREQ_MULTIPLIER)   // Use 1280 symbol times for skip interval
`define DEFAULT_GEN3_SKIP_INTERVAL          9'd370          // Number of blocks in between skips
`define DEFAULT_GEN3_CXL_SNHB_INTERVAL      9'd340          // Number of blocks in between skips, Sync Header Bypass, + 1 is because SDS or SKP itself counted
`define DEFAULT_GEN3_CXL_SYNC_INTERVAL      9'd374          // Number of blocks in between skips, Not Sync Header Bypass, + 1 is because SDS or SKP itself counted
`define DEFAULT_EIDLE_TIMER                 4'b0
// Use 152 symbol times for SHORT skip interval for SRIS mode because RTL counts from 0-DEFAULT_SHORT_SKIP_INTERVAL
// Use 150/multiplier because of rounding down and because RLT couts from 0-DEFAULT_SHORT_SKIP_INTERVAL
// Use 36 because RLT couts from 0-DEFAULT_GEN3_SHORT_SKIP_INTERVAL
`define DEFAULT_SHORT_SKIP_INTERVAL         (11'd150/`CX_PL_FREQ_MULTIPLIER)
`define DEFAULT_GEN3_SHORT_SKIP_INTERVAL    9'd36          // Number of blocks in between skips for short skip intrvals for SRIS mode, GEN3
`define DEFAULT_GEN3_SHORT_SKIP_INTERVAL_CXL 9'd34         // using 34 Blocks which is 34 x 16 = 544, then divided by 68 syms/flit = 8 flits (integer), + 1 is because SDS or SKP itself counted
// M-PCIe
`define DEFAULT_TGT_GEAR                    4'h1
`define DEFAULT_TGT_TXWIDTH                 ((`CM_TXNL== 16) ? 6'b01_0000 : (`CM_TXNL== 8) ? 6'b00_1000 : (`CM_TXNL== 4) ? 6'b00_0100 : (`CM_TXNL== 2) ? 6'b00_0010 : 6'b00_0001) 
`define DEFAULT_TGT_RXWIDTH                 ((`CM_RXNL== 16) ? 6'b01_0000 : (`CM_RXNL== 8) ? 6'b00_1000 : (`CM_RXNL== 4) ? 6'b00_0100 : (`CM_RXNL== 2) ? 6'b00_0010 : 6'b00_0001) 
`define SKIP_INTERVAL_2KPPM                 (11'd228/`CX_PL_FREQ_MULTIPLIER)

// =============================================================================
// M-PCIe Attribute Register
// =============================================================================
`define SUPPORT_HSGEAR                      8'h02
`define SUPPORT_TX_LANE                     ((`CM_TXNL== 16) ? 8'b0010_1111 : (`CM_TXNL== 8) ? 8'b0000_1111 : (`CM_TXNL== 4) ? 8'b0000_0111 : (`CM_TXNL== 2) ? 8'b0000_0011 : 8'b0000_0001) 
`define SUPPORT_RX_LANE                     ((`CM_RXNL== 16) ? 8'b0010_1111 : (`CM_RXNL== 8) ? 8'b0000_1111 : (`CM_RXNL== 4) ? 8'b0000_0111 : (`CM_RXNL== 2) ? 8'b0000_0011 : 8'b0000_0001) 
`define DEFAULT_TXLANE_WIDTH                ((`CM_TXNL== 16) ? 8'b0010_0000 : (`CM_TXNL== 8) ? 8'b0000_1000 : (`CM_TXNL== 4) ? 8'b0000_0100 : (`CM_TXNL== 2) ? 8'b0000_0010 : 8'b0000_0001) 
`define DEFAULT_RXLANE_WIDTH                ((`CM_RXNL== 16) ? 8'b0010_0000 : (`CM_RXNL== 8) ? 8'b0000_1000 : (`CM_RXNL== 4) ? 8'b0000_0100 : (`CM_RXNL== 2) ? 8'b0000_0010 : 8'b0000_0001) 

// coefs width for the coef req for FOM evaluation
`define FCOEF_WIDTH                         8'd12 + 8'd12 + 8'd24






// =============================================================================
// VCS UNR Macros
// =============================================================================
`define SNPS_UNR_CONSTANT(desc, cond, signal, value) \
/*DO NOT REMOVE THIS COMMENT*/
`define SNPS_UNR_CONSTRAINT(desc, cond, clk, const) \
/*DO NOT REMOVE THIS COMMENT*/
`define SNPS_UNR_CONSTRAINT_PROP(desc, cond, const) \
/*DO NOT REMOVE THIS COMMENT*/

`endif // __GUARD__PORT_CFG__SVH__
