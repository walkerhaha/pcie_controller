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

// ---  RCS information:
// ---    $DateTime: 2020/09/11 01:49:10 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/include/cap_port_cfg.svh#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// ---
// --- This file re-configure CDM capability pointers
// -----------------------------------------------------------------------------

`ifndef __GUARD__CAP_PORT_CFG__SVH__
`define __GUARD__CAP_PORT_CFG__SVH__

// =============================================================================

// =============================================================================
// PCIe Version and Type 
// =============================================================================
`define DWC_PCIE_IIP_RELEASE_VER_NUMBER 32'h3539302A // (Version is 5.90a)

`define DWC_PCIE_IIP_RELEASE_VER_TYPE 32'h67612A2A // (Type is ga)


// Start PCI capability 
// =============================================================================

// Start PCIe capability linked list definitions






// Special case; resizable bar must always be the last capability, it is also treated differently by PortCfg plugin

// =============================================================================
// Start PCI capability for external virtual functions.
// =============================================================================

// =============================================================================
// SRIOV virtual capabilities for External VF
// =============================================================================

// ARI is required for all SRIOV functions.

// =============================================================================
// call TCL process to build link list and write-out defines. 
`define CFG_PTR 8'h00
`define PM_PTR 8'h40
`define MSI_PTR 8'h50
`define PCIE_PTR 8'h70
`define MSIX_PTR 8'hB0
`define SLOT_PTR 8'hC0
`define VPD_PTR 8'hD0
`define SATA_PTR 8'hE0
`define CXL_CFG_PTR 8'h00
`define CXL_PM_PTR 8'h40
`define CXL_MSI_PTR 8'h50
`define CXL_PCIE_PTR 8'h70
`define CXL_MSIX_PTR 8'hB0
`define CXL_SLOT_PTR 8'hC0
`define CXL_VPD_PTR 8'hD0
`define CXL_SATA_PTR 8'hE0
`define CFG_NEXT_PTR 8'h40
`define PM_NEXT_PTR 8'h50
`define MSI_NEXT_PTR 8'h70
`define PCIE_NEXT_PTR 8'h00
`define MSIX_NEXT_PTR 8'h00
`define SLOT_NEXT_PTR 8'h00
`define VPD_NEXT_PTR 8'h00
`define SATA_NEXT_PTR 8'h00
`define CXL_CFG_NEXT_PTR 8'h40
`define CXL_PM_NEXT_PTR 8'h50
`define CXL_MSI_NEXT_PTR 8'h70
`define CXL_PCIE_NEXT_PTR 8'h00
`define CXL_MSIX_NEXT_PTR 8'h00
`define CXL_SLOT_NEXT_PTR 8'h00
`define CXL_VPD_NEXT_PTR 8'h00
`define CXL_SATA_NEXT_PTR 8'h00
`define BASE_PTR 12'h100
`define AER_PTR 12'h100
`define VC_PTR 12'h148
`define SN_PTR 12'h148
`define PB_PTR 12'h148
`define ARI_PTR 12'h148
`define SPCIE_PTR 12'h148
`define PL16G_PTR 12'h148
`define MARGIN_PTR 12'h148
`define PL32G_PTR 12'h148
`define SRIOV_PTR 12'h148
`define TPH_PTR 12'h148
`define ATS_PTR 12'h148
`define ACS_PTR 12'h148
`define PRS_PTR 12'h148
`define LTR_PTR 12'h148
`define L1SUB_PTR 12'h148
`define PASID_PTR 12'h148
`define DPA_PTR 12'h148
`define DPC_PTR 12'h148
`define MPCIE_PTR 12'h148
`define FRSQ_PTR 12'h148
`define RTR_PTR 12'h148
`define LN_PTR 12'h148
`define RAS_DES_PTR 12'h148
`define VSECRAS_PTR 12'h148
`define DLINK_PTR 12'h148
`define PTM_PTR 12'h148
`define PTM_VSEC_PTR 12'h148
`define CCIX_TP_PTR 12'h148
`define CXS_PTR 12'h148
`define VSECDMA_PTR 12'h148
`define NPEM_PTR 12'h148
`define DEV3_PTR 12'h148
`define RBAR_PTR 12'h148
`define VF_RBAR_PTR 12'h148
`define CXL_BASE_PTR 12'h100
`define CXL_AER_PTR 12'h100
`define CXL_VC_PTR 12'h148
`define CXL_SN_PTR 12'h148
`define CXL_PB_PTR 12'h148
`define CXL_ARI_PTR 12'h148
`define CXL_SPCIE_PTR 12'h148
`define CXL_PL16G_PTR 12'h148
`define CXL_MARGIN_PTR 12'h148
`define CXL_PL32G_PTR 12'h148
`define CXL_SRIOV_PTR 12'h148
`define CXL_TPH_PTR 12'h148
`define CXL_ATS_PTR 12'h148
`define CXL_ACS_PTR 12'h148
`define CXL_PRS_PTR 12'h148
`define CXL_LTR_PTR 12'h148
`define CXL_L1SUB_PTR 12'h148
`define CXL_PASID_PTR 12'h148
`define CXL_DPA_PTR 12'h148
`define CXL_DPC_PTR 12'h148
`define CXL_MPCIE_PTR 12'h148
`define CXL_FRSQ_PTR 12'h148
`define CXL_RTR_PTR 12'h148
`define CXL_LN_PTR 12'h148
`define CXL_RAS_DES_PTR 12'h148
`define CXL_VSECRAS_PTR 12'h148
`define CXL_DLINK_PTR 12'h148
`define CXL_PTM_PTR 12'h148
`define CXL_PTM_VSEC_PTR 12'h148
`define CXL_CCIX_TP_PTR 12'h148
`define CXL_CXS_PTR 12'h148
`define CXL_VSECDMA_PTR 12'h148
`define CXL_NPEM_PTR 12'h148
`define CXL_DEV3_PTR 12'h148
`define CXL_RBAR_PTR 12'h148
`define CXL_VF_RBAR_PTR 12'h148
`define BASE_NEXT_PTR_0 12'h100
`define BASE_NEXT_PTR ((FUNC_NUM==0) ? `BASE_NEXT_PTR_0 : `BASE_NEXT_PTR_N ) 
`define AER_NEXT_PTR_0 12'h000
`define AER_NEXT_PTR ((FUNC_NUM==0) ? `AER_NEXT_PTR_0 : `AER_NEXT_PTR_N ) 
`define VC_NEXT_PTR_0 12'h000
`define VC_NEXT_PTR 12'h000
`define SN_NEXT_PTR_0 12'h000
`define SN_NEXT_PTR ((FUNC_NUM==0) ? `SN_NEXT_PTR_0 : `SN_NEXT_PTR_N ) 
`define PB_NEXT_PTR_0 12'h000
`define PB_NEXT_PTR ((FUNC_NUM==0) ? `PB_NEXT_PTR_0 : `PB_NEXT_PTR_N ) 
`define ARI_NEXT_PTR_0 12'h000
`define ARI_NEXT_PTR ((FUNC_NUM==0) ? `ARI_NEXT_PTR_0 : `ARI_NEXT_PTR_N ) 
`define SPCIE_NEXT_PTR_0 12'h000
`define SPCIE_NEXT_PTR 12'h000
`define PL16G_NEXT_PTR_0 12'h000
`define PL16G_NEXT_PTR 12'h000
`define MARGIN_NEXT_PTR_0 12'h000
`define MARGIN_NEXT_PTR 12'h000
`define PL32G_NEXT_PTR_0 12'h000
`define PL32G_NEXT_PTR 12'h000
`define SRIOV_NEXT_PTR_0 12'h000
`define SRIOV_NEXT_PTR ((FUNC_NUM==0) ? `SRIOV_NEXT_PTR_0 : `SRIOV_NEXT_PTR_N ) 
`define TPH_NEXT_PTR_0 12'h000
`define TPH_NEXT_PTR ((FUNC_NUM==0) ? `TPH_NEXT_PTR_0 : `TPH_NEXT_PTR_N ) 
`define ATS_NEXT_PTR_0 12'h000
`define ATS_NEXT_PTR ((FUNC_NUM==0) ? `ATS_NEXT_PTR_0 : `ATS_NEXT_PTR_N ) 
`define ACS_NEXT_PTR_0 12'h000
`define ACS_NEXT_PTR ((FUNC_NUM==0) ? `ACS_NEXT_PTR_0 : `ACS_NEXT_PTR_N ) 
`define PRS_NEXT_PTR_0 12'h000
`define PRS_NEXT_PTR ((FUNC_NUM==0) ? `PRS_NEXT_PTR_0 : `PRS_NEXT_PTR_N ) 
`define LTR_NEXT_PTR_0 12'h000
`define LTR_NEXT_PTR 12'h000
`define L1SUB_NEXT_PTR_0 12'h000
`define L1SUB_NEXT_PTR 12'h000
`define PASID_NEXT_PTR_0 12'h000
`define PASID_NEXT_PTR ((FUNC_NUM==0) ? `PASID_NEXT_PTR_0 : `PASID_NEXT_PTR_N ) 
`define DPA_NEXT_PTR_0 12'h000
`define DPA_NEXT_PTR ((FUNC_NUM==0) ? `DPA_NEXT_PTR_0 : `DPA_NEXT_PTR_N ) 
`define DPC_NEXT_PTR_0 12'h000
`define DPC_NEXT_PTR ((FUNC_NUM==0) ? `DPC_NEXT_PTR_0 : `DPC_NEXT_PTR_N ) 
`define MPCIE_NEXT_PTR_0 12'h000
`define MPCIE_NEXT_PTR 12'h000
`define FRSQ_NEXT_PTR_0 12'h000
`define FRSQ_NEXT_PTR 12'h000
`define RTR_NEXT_PTR_0 12'h000
`define RTR_NEXT_PTR ((FUNC_NUM==0) ? `RTR_NEXT_PTR_0 : `RTR_NEXT_PTR_N ) 
`define LN_NEXT_PTR_0 12'h000
`define LN_NEXT_PTR ((FUNC_NUM==0) ? `LN_NEXT_PTR_0 : `LN_NEXT_PTR_N ) 
`define RAS_DES_NEXT_PTR_0 12'h000
`define RAS_DES_NEXT_PTR ((FUNC_NUM==0) ? `RAS_DES_NEXT_PTR_0 : `RAS_DES_NEXT_PTR_N ) 
`define VSECRAS_NEXT_PTR_0 12'h000
`define VSECRAS_NEXT_PTR ((FUNC_NUM==0) ? `VSECRAS_NEXT_PTR_0 : `VSECRAS_NEXT_PTR_N ) 
`define DLINK_NEXT_PTR_0 12'h000
`define DLINK_NEXT_PTR 12'h000
`define PTM_NEXT_PTR_0 12'h000
`define PTM_NEXT_PTR 12'h000
`define PTM_VSEC_NEXT_PTR_0 12'h000
`define PTM_VSEC_NEXT_PTR ((FUNC_NUM==0) ? `PTM_VSEC_NEXT_PTR_0 : `PTM_VSEC_NEXT_PTR_N ) 
`define CCIX_TP_NEXT_PTR_0 12'h000
`define CCIX_TP_NEXT_PTR 12'h000
`define CXS_NEXT_PTR_0 12'h000
`define CXS_NEXT_PTR 12'h000
`define VSECDMA_NEXT_PTR_0 12'h000
`define VSECDMA_NEXT_PTR ((FUNC_NUM==0) ? `VSECDMA_NEXT_PTR_0 : `VSECDMA_NEXT_PTR_N ) 
`define NPEM_NEXT_PTR_0 12'h000
`define NPEM_NEXT_PTR 12'h000
`define DEV3_NEXT_PTR_0 12'h000
`define DEV3_NEXT_PTR ((FUNC_NUM==0) ? `DEV3_NEXT_PTR_0 : `DEV3_NEXT_PTR_N ) 
`define RBAR_NEXT_PTR_0 12'h000
`define RBAR_NEXT_PTR ((FUNC_NUM==0) ? `RBAR_NEXT_PTR_0 : `RBAR_NEXT_PTR_N ) 
`define VF_RBAR_NEXT_PTR_0 12'h000
`define VF_RBAR_NEXT_PTR ((FUNC_NUM==0) ? `VF_RBAR_NEXT_PTR_0 : `VF_RBAR_NEXT_PTR_N ) 
`define BASE_NEXT_PTR_N 12'h100
`define AER_NEXT_PTR_N 12'h000
`define VC_NEXT_PTR_N 12'h000
`define SN_NEXT_PTR_N 12'h000
`define PB_NEXT_PTR_N 12'h000
`define ARI_NEXT_PTR_N 12'h000
`define SPCIE_NEXT_PTR_N 12'h000
`define PL16G_NEXT_PTR_N 12'h000
`define MARGIN_NEXT_PTR_N 12'h000
`define PL32G_NEXT_PTR_N 12'h000
`define SRIOV_NEXT_PTR_N 12'h000
`define TPH_NEXT_PTR_N 12'h000
`define ATS_NEXT_PTR_N 12'h000
`define ACS_NEXT_PTR_N 12'h000
`define PRS_NEXT_PTR_N 12'h000
`define LTR_NEXT_PTR_N 12'h000
`define L1SUB_NEXT_PTR_N 12'h000
`define PASID_NEXT_PTR_N 12'h000
`define DPA_NEXT_PTR_N 12'h000
`define DPC_NEXT_PTR_N 12'h000
`define MPCIE_NEXT_PTR_N 12'h000
`define FRSQ_NEXT_PTR_N 12'h000
`define RTR_NEXT_PTR_N 12'h000
`define LN_NEXT_PTR_N 12'h000
`define RAS_DES_NEXT_PTR_N 12'h000
`define VSECRAS_NEXT_PTR_N 12'h000
`define DLINK_NEXT_PTR_N 12'h000
`define PTM_NEXT_PTR_N 12'h000
`define PTM_VSEC_NEXT_PTR_N 12'h000
`define CCIX_TP_NEXT_PTR_N 12'h000
`define CXS_NEXT_PTR_N 12'h000
`define VSECDMA_NEXT_PTR_N 12'h000
`define NPEM_NEXT_PTR_N 12'h000
`define DEV3_NEXT_PTR_N 12'h000
`define RBAR_NEXT_PTR_N 12'h000
`define VF_RBAR_NEXT_PTR_N 12'h000
`define DM_RP_BASE_NEXT_PTR 12'h100
`define DM_RP_AER_NEXT_PTR 12'h000
`define DM_RP_VC_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_SN_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_PB_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_ARI_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_SPCIE_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_PL16G_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_MARGIN_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_PL32G_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_SRIOV_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_TPH_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_ATS_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_ACS_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_PRS_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_LTR_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_L1SUB_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_PASID_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_DPA_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_DPC_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_MPCIE_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_FRSQ_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_RTR_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_LN_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_RAS_DES_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_VSECRAS_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_DLINK_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_PTM_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_PTM_VSEC_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_CCIX_TP_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_CXS_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_VSECDMA_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_NPEM_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_DEV3_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_RBAR_NEXT_PTR 12'h0 // not cap enabled
`define DM_RP_VF_RBAR_NEXT_PTR 12'h0 // not cap enabled
`define CXL_BASE_NEXT_PTR 12'h0 // not cap enabled
`define CXL_AER_NEXT_PTR_0 12'h000
`define CXL_AER_NEXT_PTR ((FUNC_NUM==0) ? `CXL_AER_NEXT_PTR_0 : `CXL_AER_NEXT_PTR_N ) 
`define CXL_VC_NEXT_PTR 12'h0 // not cap enabled
`define CXL_SN_NEXT_PTR 12'h0 // not cap enabled
`define CXL_PB_NEXT_PTR 12'h0 // not cap enabled
`define CXL_ARI_NEXT_PTR 12'h0 // not cap enabled
`define CXL_SPCIE_NEXT_PTR 12'h0 // not cap enabled
`define CXL_PL16G_NEXT_PTR 12'h0 // not cap enabled
`define CXL_MARGIN_NEXT_PTR 12'h0 // not cap enabled
`define CXL_PL32G_NEXT_PTR 12'h0 // not cap enabled
`define CXL_SRIOV_NEXT_PTR 12'h0 // not cap enabled
`define CXL_TPH_NEXT_PTR 12'h0 // not cap enabled
`define CXL_ATS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_ACS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_PRS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_LTR_NEXT_PTR 12'h0 // not cap enabled
`define CXL_L1SUB_NEXT_PTR 12'h0 // not cap enabled
`define CXL_PASID_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DPA_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DPC_NEXT_PTR 12'h0 // not cap enabled
`define CXL_MPCIE_NEXT_PTR 12'h0 // not cap enabled
`define CXL_FRSQ_NEXT_PTR 12'h0 // not cap enabled
`define CXL_RTR_NEXT_PTR 12'h0 // not cap enabled
`define CXL_LN_NEXT_PTR 12'h0 // not cap enabled
`define CXL_RAS_DES_NEXT_PTR 12'h0 // not cap enabled
`define CXL_VSECRAS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DLINK_NEXT_PTR 12'h0 // not cap enabled
`define CXL_PTM_NEXT_PTR 12'h0 // not cap enabled
`define CXL_PTM_VSEC_NEXT_PTR 12'h0 // not cap enabled
`define CXL_CCIX_TP_NEXT_PTR 12'h0 // not cap enabled
`define CXL_CXS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_VSECDMA_NEXT_PTR 12'h0 // not cap enabled
`define CXL_NPEM_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DEV3_NEXT_PTR 12'h0 // not cap enabled
`define CXL_RBAR_NEXT_PTR 12'h0 // not cap enabled
`define CXL_VF_RBAR_NEXT_PTR 12'h0 // not cap enabled
`define CXL_BASE_NEXT_PTR_N 12'h000
`define CXL_AER_NEXT_PTR_N 12'h000
`define CXL_VC_NEXT_PTR_N 12'h000
`define CXL_SN_NEXT_PTR_N 12'h000
`define CXL_PB_NEXT_PTR_N 12'h000
`define CXL_ARI_NEXT_PTR_N 12'h000
`define CXL_SPCIE_NEXT_PTR_N 12'h000
`define CXL_PL16G_NEXT_PTR_N 12'h000
`define CXL_MARGIN_NEXT_PTR_N 12'h000
`define CXL_PL32G_NEXT_PTR_N 12'h000
`define CXL_SRIOV_NEXT_PTR_N 12'h000
`define CXL_TPH_NEXT_PTR_N 12'h000
`define CXL_ATS_NEXT_PTR_N 12'h000
`define CXL_ACS_NEXT_PTR_N 12'h000
`define CXL_PRS_NEXT_PTR_N 12'h000
`define CXL_LTR_NEXT_PTR_N 12'h000
`define CXL_L1SUB_NEXT_PTR_N 12'h000
`define CXL_PASID_NEXT_PTR_N 12'h000
`define CXL_DPA_NEXT_PTR_N 12'h000
`define CXL_DPC_NEXT_PTR_N 12'h000
`define CXL_MPCIE_NEXT_PTR_N 12'h000
`define CXL_FRSQ_NEXT_PTR_N 12'h000
`define CXL_RTR_NEXT_PTR_N 12'h000
`define CXL_LN_NEXT_PTR_N 12'h000
`define CXL_RAS_DES_NEXT_PTR_N 12'h000
`define CXL_VSECRAS_NEXT_PTR_N 12'h000
`define CXL_DLINK_NEXT_PTR_N 12'h000
`define CXL_PTM_NEXT_PTR_N 12'h000
`define CXL_PTM_VSEC_NEXT_PTR_N 12'h000
`define CXL_CCIX_TP_NEXT_PTR_N 12'h000
`define CXL_CXS_NEXT_PTR_N 12'h000
`define CXL_VSECDMA_NEXT_PTR_N 12'h000
`define CXL_NPEM_NEXT_PTR_N 12'h000
`define CXL_DEV3_NEXT_PTR_N 12'h000
`define CXL_RBAR_NEXT_PTR_N 12'h000
`define CXL_VF_RBAR_NEXT_PTR_N 12'h000
`define CXL_DM_RP_BASE_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_AER_NEXT_PTR 12'h000
`define CXL_DM_RP_VC_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_SN_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_PB_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_ARI_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_SPCIE_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_PL16G_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_MARGIN_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_PL32G_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_SRIOV_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_TPH_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_ATS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_ACS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_PRS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_LTR_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_L1SUB_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_PASID_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_DPA_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_DPC_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_MPCIE_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_FRSQ_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_RTR_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_LN_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_RAS_DES_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_VSECRAS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_DLINK_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_PTM_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_PTM_VSEC_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_CCIX_TP_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_CXS_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_VSECDMA_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_NPEM_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_DEV3_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_RBAR_NEXT_PTR 12'h0 // not cap enabled
`define CXL_DM_RP_VF_RBAR_NEXT_PTR 12'h0 // not cap enabled
`define MP_BASE_NEXT_PTR_0 12'h100
`define MP_BASE_NEXT_PTR ((FUNC_NUM==0) ? `MP_BASE_NEXT_PTR_0 : `MP_BASE_NEXT_PTR_N ) 
`define MP_AER_NEXT_PTR_0 12'h000
`define MP_AER_NEXT_PTR ((FUNC_NUM==0) ? `MP_AER_NEXT_PTR_0 : `MP_AER_NEXT_PTR_N ) 
`define MP_VC_NEXT_PTR_0 12'h000
`define MP_VC_NEXT_PTR 12'h000
`define MP_SN_NEXT_PTR_0 12'h000
`define MP_SN_NEXT_PTR ((FUNC_NUM==0) ? `MP_SN_NEXT_PTR_0 : `MP_SN_NEXT_PTR_N ) 
`define MP_PB_NEXT_PTR_0 12'h000
`define MP_PB_NEXT_PTR ((FUNC_NUM==0) ? `MP_PB_NEXT_PTR_0 : `MP_PB_NEXT_PTR_N ) 
`define MP_ARI_NEXT_PTR_0 12'h000
`define MP_ARI_NEXT_PTR ((FUNC_NUM==0) ? `MP_ARI_NEXT_PTR_0 : `MP_ARI_NEXT_PTR_N ) 
`define MP_SPCIE_NEXT_PTR_0 12'h000
`define MP_SPCIE_NEXT_PTR 12'h000
`define MP_PL16G_NEXT_PTR_0 12'h000
`define MP_PL16G_NEXT_PTR 12'h000
`define MP_MARGIN_NEXT_PTR_0 12'h000
`define MP_MARGIN_NEXT_PTR 12'h000
`define MP_PL32G_NEXT_PTR_0 12'h000
`define MP_PL32G_NEXT_PTR 12'h000
`define MP_SRIOV_NEXT_PTR_0 12'h000
`define MP_SRIOV_NEXT_PTR ((FUNC_NUM==0) ? `MP_SRIOV_NEXT_PTR_0 : `MP_SRIOV_NEXT_PTR_N ) 
`define MP_TPH_NEXT_PTR_0 12'h000
`define MP_TPH_NEXT_PTR ((FUNC_NUM==0) ? `MP_TPH_NEXT_PTR_0 : `MP_TPH_NEXT_PTR_N ) 
`define MP_ATS_NEXT_PTR_0 12'h000
`define MP_ATS_NEXT_PTR ((FUNC_NUM==0) ? `MP_ATS_NEXT_PTR_0 : `MP_ATS_NEXT_PTR_N ) 
`define MP_ACS_NEXT_PTR_0 12'h000
`define MP_ACS_NEXT_PTR ((FUNC_NUM==0) ? `MP_ACS_NEXT_PTR_0 : `MP_ACS_NEXT_PTR_N ) 
`define MP_PRS_NEXT_PTR_0 12'h000
`define MP_PRS_NEXT_PTR ((FUNC_NUM==0) ? `MP_PRS_NEXT_PTR_0 : `MP_PRS_NEXT_PTR_N ) 
`define MP_LTR_NEXT_PTR_0 12'h000
`define MP_LTR_NEXT_PTR 12'h000
`define MP_L1SUB_NEXT_PTR_0 12'h000
`define MP_L1SUB_NEXT_PTR 12'h000
`define MP_PASID_NEXT_PTR_0 12'h000
`define MP_PASID_NEXT_PTR ((FUNC_NUM==0) ? `MP_PASID_NEXT_PTR_0 : `MP_PASID_NEXT_PTR_N ) 
`define MP_DPA_NEXT_PTR_0 12'h000
`define MP_DPA_NEXT_PTR ((FUNC_NUM==0) ? `MP_DPA_NEXT_PTR_0 : `MP_DPA_NEXT_PTR_N ) 
`define MP_DPC_NEXT_PTR_0 12'h000
`define MP_DPC_NEXT_PTR ((FUNC_NUM==0) ? `MP_DPC_NEXT_PTR_0 : `MP_DPC_NEXT_PTR_N ) 
`define MP_MPCIE_NEXT_PTR_0 12'h000
`define MP_MPCIE_NEXT_PTR 12'h000
`define MP_FRSQ_NEXT_PTR_0 12'h000
`define MP_FRSQ_NEXT_PTR 12'h000
`define MP_RTR_NEXT_PTR_0 12'h000
`define MP_RTR_NEXT_PTR ((FUNC_NUM==0) ? `MP_RTR_NEXT_PTR_0 : `MP_RTR_NEXT_PTR_N ) 
`define MP_LN_NEXT_PTR_0 12'h000
`define MP_LN_NEXT_PTR ((FUNC_NUM==0) ? `MP_LN_NEXT_PTR_0 : `MP_LN_NEXT_PTR_N ) 
`define MP_RAS_DES_NEXT_PTR_0 12'h000
`define MP_RAS_DES_NEXT_PTR ((FUNC_NUM==0) ? `MP_RAS_DES_NEXT_PTR_0 : `MP_RAS_DES_NEXT_PTR_N ) 
`define MP_VSECRAS_NEXT_PTR_0 12'h000
`define MP_VSECRAS_NEXT_PTR ((FUNC_NUM==0) ? `MP_VSECRAS_NEXT_PTR_0 : `MP_VSECRAS_NEXT_PTR_N ) 
`define MP_DLINK_NEXT_PTR_0 12'h000
`define MP_DLINK_NEXT_PTR 12'h000
`define MP_PTM_NEXT_PTR_0 12'h000
`define MP_PTM_NEXT_PTR 12'h000
`define MP_PTM_VSEC_NEXT_PTR_0 12'h000
`define MP_PTM_VSEC_NEXT_PTR ((FUNC_NUM==0) ? `MP_PTM_VSEC_NEXT_PTR_0 : `MP_PTM_VSEC_NEXT_PTR_N ) 
`define MP_CCIX_TP_NEXT_PTR_0 12'h000
`define MP_CCIX_TP_NEXT_PTR 12'h000
`define MP_CXS_NEXT_PTR_0 12'h000
`define MP_CXS_NEXT_PTR 12'h000
`define MP_VSECDMA_NEXT_PTR_0 12'h000
`define MP_VSECDMA_NEXT_PTR ((FUNC_NUM==0) ? `MP_VSECDMA_NEXT_PTR_0 : `MP_VSECDMA_NEXT_PTR_N ) 
`define MP_NPEM_NEXT_PTR_0 12'h000
`define MP_NPEM_NEXT_PTR 12'h000
`define MP_DEV3_NEXT_PTR_0 12'h000
`define MP_DEV3_NEXT_PTR ((FUNC_NUM==0) ? `MP_DEV3_NEXT_PTR_0 : `MP_DEV3_NEXT_PTR_N ) 
`define MP_RBAR_NEXT_PTR_0 12'h000
`define MP_RBAR_NEXT_PTR ((FUNC_NUM==0) ? `MP_RBAR_NEXT_PTR_0 : `MP_RBAR_NEXT_PTR_N ) 
`define MP_VF_RBAR_NEXT_PTR_0 12'h000
`define MP_VF_RBAR_NEXT_PTR ((FUNC_NUM==0) ? `MP_VF_RBAR_NEXT_PTR_0 : `MP_VF_RBAR_NEXT_PTR_N ) 
`define MP_BASE_NEXT_PTR_N 12'h100
`define MP_AER_NEXT_PTR_N 12'h000
`define MP_VC_NEXT_PTR_N 12'h000
`define MP_SN_NEXT_PTR_N 12'h000
`define MP_PB_NEXT_PTR_N 12'h000
`define MP_ARI_NEXT_PTR_N 12'h000
`define MP_SPCIE_NEXT_PTR_N 12'h000
`define MP_PL16G_NEXT_PTR_N 12'h000
`define MP_MARGIN_NEXT_PTR_N 12'h000
`define MP_PL32G_NEXT_PTR_N 12'h000
`define MP_SRIOV_NEXT_PTR_N 12'h000
`define MP_TPH_NEXT_PTR_N 12'h000
`define MP_ATS_NEXT_PTR_N 12'h000
`define MP_ACS_NEXT_PTR_N 12'h000
`define MP_PRS_NEXT_PTR_N 12'h000
`define MP_LTR_NEXT_PTR_N 12'h000
`define MP_L1SUB_NEXT_PTR_N 12'h000
`define MP_PASID_NEXT_PTR_N 12'h000
`define MP_DPA_NEXT_PTR_N 12'h000
`define MP_DPC_NEXT_PTR_N 12'h000
`define MP_MPCIE_NEXT_PTR_N 12'h000
`define MP_FRSQ_NEXT_PTR_N 12'h000
`define MP_RTR_NEXT_PTR_N 12'h000
`define MP_LN_NEXT_PTR_N 12'h000
`define MP_RAS_DES_NEXT_PTR_N 12'h000
`define MP_VSECRAS_NEXT_PTR_N 12'h000
`define MP_DLINK_NEXT_PTR_N 12'h000
`define MP_PTM_NEXT_PTR_N 12'h000
`define MP_PTM_VSEC_NEXT_PTR_N 12'h000
`define MP_CCIX_TP_NEXT_PTR_N 12'h000
`define MP_CXS_NEXT_PTR_N 12'h000
`define MP_VSECDMA_NEXT_PTR_N 12'h000
`define MP_NPEM_NEXT_PTR_N 12'h000
`define MP_DEV3_NEXT_PTR_N 12'h000
`define MP_RBAR_NEXT_PTR_N 12'h000
`define MP_VF_RBAR_NEXT_PTR_N 12'h000
`define MP_RP_BASE_NEXT_PTR 12'h100
`define MP_RP_AER_NEXT_PTR 12'h000
`define MP_RP_VC_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_SN_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_PB_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_ARI_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_SPCIE_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_PL16G_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_MARGIN_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_PL32G_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_SRIOV_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_TPH_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_ATS_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_ACS_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_PRS_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_LTR_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_L1SUB_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_PASID_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_DPA_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_DPC_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_MPCIE_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_FRSQ_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_RTR_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_LN_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_RAS_DES_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_VSECRAS_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_DLINK_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_PTM_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_PTM_VSEC_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_CCIX_TP_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_CXS_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_VSECDMA_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_NPEM_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_DEV3_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_RBAR_NEXT_PTR 12'h0 // not cap enabled
`define MP_RP_VF_RBAR_NEXT_PTR 12'h0 // not cap enabled
`define VF_BASE_PTR 12'h100
`define EXT_VF_BASE_PTR 12'h100
`define VF_AER_PTR 12'h0 // cap not enabled
`define EXT_VF_AER_PTR 12'h0 // cap not enabled
`define VF_ARI_PTR 12'h100
`define EXT_VF_ARI_PTR 12'h100
`define VF_TPH_PTR 12'h0 // cap not enabled
`define EXT_VF_TPH_PTR 12'h0 // cap not enabled
`define VF_ATS_PTR 12'h0 // cap not enabled
`define EXT_VF_ATS_PTR 12'h0 // cap not enabled
`define VF_ACS_PTR 12'h0 // cap not enabled
`define EXT_VF_ACS_PTR 12'h0 // cap not enabled
`define VF_PASID_PTR 12'h0 // cap not enabled
`define EXT_VF_PASID_PTR 12'h0 // cap not enabled
`define VF_RTR_PTR 12'h0 // cap not enabled
`define EXT_VF_RTR_PTR 12'h0 // cap not enabled
`define VF_LN_PTR 12'h0 // cap not enabled
`define EXT_VF_LN_PTR 12'h0 // cap not enabled
`define VF_BASE_NEXT_PTR 12'h100
`define EXT_VF_BASE_NEXT_PTR 12'h100
`define VF_AER_NEXT_PTR 12'h000
`define EXT_VF_AER_NEXT_PTR 12'h000
`define VF_ARI_NEXT_PTR 12'h000
`define EXT_VF_ARI_NEXT_PTR 12'h000
`define VF_TPH_NEXT_PTR 12'h000
`define EXT_VF_TPH_NEXT_PTR 12'h000
`define VF_ATS_NEXT_PTR 12'h000
`define EXT_VF_ATS_NEXT_PTR 12'h000
`define VF_ACS_NEXT_PTR 12'h000
`define EXT_VF_ACS_NEXT_PTR 12'h000
`define VF_PASID_NEXT_PTR 12'h000
`define EXT_VF_PASID_NEXT_PTR 12'h000
`define VF_RTR_NEXT_PTR 12'h000
`define EXT_VF_RTR_NEXT_PTR 12'h000
`define VF_LN_NEXT_PTR 12'h000
`define EXT_VF_LN_NEXT_PTR 12'h000
`define VF_CFG_PTR 8'h00
`define EXT_VF_CFG_PTR 8'h00
`define VF_PM_PTR 8'h0 // cap not enabled
`define EXT_VF_PM_PTR 8'h0 // cap not enabled
`define VF_MSI_PTR 8'h0 // cap not enabled
`define EXT_VF_MSI_PTR 8'h0 // cap not enabled
`define VF_PCIE_PTR 8'h70
`define EXT_VF_PCIE_PTR 8'h70
`define VF_MSIX_PTR 8'h0 // cap not enabled
`define EXT_VF_MSIX_PTR 8'h0 // cap not enabled
`define VF_SLOT_PTR 8'h0 // cap not enabled
`define EXT_VF_SLOT_PTR 8'h0 // cap not enabled
`define VF_VPD_PTR 8'h0 // cap not enabled
`define EXT_VF_VPD_PTR 8'h0 // cap not enabled
`define VF_CFG_NEXT_PTR 8'h70
`define EXT_VF_CFG_NEXT_PTR 8'h70
`define VF_PM_NEXT_PTR 8'h00
`define EXT_VF_PM_NEXT_PTR 8'h00
`define VF_MSI_NEXT_PTR 8'h00
`define EXT_VF_MSI_NEXT_PTR 8'h00
`define VF_PCIE_NEXT_PTR 8'h00
`define EXT_VF_PCIE_NEXT_PTR 8'h00
`define VF_MSIX_NEXT_PTR 8'h00
`define EXT_VF_MSIX_NEXT_PTR 8'h00
`define VF_SLOT_NEXT_PTR 8'h00
`define EXT_VF_SLOT_NEXT_PTR 8'h00
`define VF_VPD_NEXT_PTR 8'h00
`define EXT_VF_VPD_NEXT_PTR 8'h00



// =============================================================================



`endif // __GUARD__CAP_PORT_CFG__SVH__
