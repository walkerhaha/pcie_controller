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
// ---  RCS information: ARCT generated file. Do not manually edit. (generator -> process_rtl.sh)
// ---    $DateTime: 2020/10/23 07:44:27 $
// ---    $Revision: #120 $
// ---    $Id: //dwh/pcie_iip/main/DWC_pcie/DWC_pcie_ctl/src/DWC_pcie_ctl.sv#120 $
// -------------------------------------------------------------------------

//==============================================================================
// Start License Usage
//==============================================================================
// Key Used   : DWC-PCIE                   (IP access)
// Key Used   : DWC-PCIE-G1-STND-A-SRC     (Add-on feature access: DWC PCIe G1.0 with AXI Bridge Standard License)
// Key Used   : DWC-PCIE-G1-PLUS-A-SRC     (Add-on feature access: DWC PCIe G1.0 with AXI Bridge Plus License)
// Key Used   : DWC-PCIE-G1-STND-N-SRC     (Add-on feature access: DWC PCIe G1.0 Standard License)
// Key Used   : DWC-PCIE-G1-PLUS-N-SRC     (Add-on feature access: DWC PCIe G1.0 Plus License)
// Key Used   : DWC-PCIE-G1-PREM-N-SRC     (Add-on feature access: DWC PCIe G1.0 Premium License)
// Key Used   : DWC-CCIX-G25-PREM-N-SRC    (Add-on feature access: DWC PCIe Support CCIX G25 License)
// Key Used   : DWC-AP-PCIE-G1-PREM-N-SRC  (Add-on feature access: DWC PCIe G1.0 Support AUTOMOTIVE Safety Package License)
// Key Used   : DWC-AP-CCIX-G25-PREM-N-SRC (Add-on feature access: DWC PCIe Support CCIX G25 with AUTOMOTIVE Safety Package License)
// Key Used   : DWC-AC-CCIX-G25-PREM-N-SRC (Add-on feature access: DWC PCIe Support CCIX G25 with AC Controller License)
// Key NotUsed: DWC-USB4-PCIE-PREM-N-SRC   (Add-on feature access: DWC USB4 PCIe Premium License)
//==============================================================================
// End License Usage
//==============================================================================
// -----------------------------------------------------------------------------
// --- Module description:  This is for top-level dual mode/end device/root complex/switch application.
// --- Top level modules:
// --- * radm_dm        : Rcvd ADM for dual-mode application
// --- * radm_ep        : Rcvd ADM for end-point application
// --- * radm_rc        : Rcvd ADM for root application
// --- * radm_sw        : Rcvd ADM for switch application
// --- * xadm           : Txmt ADM
// --- * cx_pl          : Basic PCI Express Functionality: Layer1, Layer2 and Layer3
// --- * cdm            : Type 0 CDM
// --- * lbc            : Local bus controller
// --- * pm_ctrl        : Power management running at Aux clock
// --- * msg_gen        : Message TLP Generation
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "include/DWC_pcie_ctl_all_pkgs.svh"
`include "include/DWC_pcie_ctl_all_itfs.svh"
`include "Cdm/cdm_pkg.svh"

module DWC_pcie_ctl
import cdm_pkg::*;
  #(

// module parameter port list
    parameter INST = 0,

    parameter NL = 4,

    parameter TXNL = 4,

    parameter RXNL = 4,

    parameter NB = 2,

    parameter PHY_NB = 2,

    parameter CM_PHY_NB = 1,

    parameter NW = 2,

    parameter NF = 6'h1,

    parameter PF_WD = 5'h3,

    parameter NVC = 4'h1,

    parameter NVC_XALI_EXP = 4'h1,

    parameter NHQ = 1,

    parameter NDQ = 1,

    parameter DATA_PAR_WD = 0,

    parameter TRGT_DATA_WD = 64,


    parameter ADDR_PAR_WD = 0,

    parameter DW_W_PAR = 64,

    parameter DW_WO_PAR = 64,

    parameter RAS_PCIE_HDR_PROT_WD = 0,

    parameter TX_HW_W_PAR = 128,

    parameter RADM_P_HWD = 134,

    parameter DW = 64,

    parameter DATA_WIDTH = 64,

    parameter ADDR_WIDTH = 64,
    
    parameter RX_NDLLP = 1,

    parameter L2N_INTFC = 1,

    parameter ALL_FUNC_NUM = 24'hfac688,

    parameter TRGT_HDR_WD = 134,

    parameter TRGT_HDR_PROT_WD = 0,

    parameter CLIENT_HDR_PROT_WD = 0,

    parameter ST_HDR = 156,

    parameter HDR_PROT_WD = 0,

    parameter RBUF_DEPTH = 196,

    parameter RBUF_PW = 8,

    parameter SOTBUF_DP = 128,

    parameter SOTBUF_PW = 7,

    parameter SOTBUF_WD = 8,

    parameter DATAQ_WD = 71,

    parameter RADM_Q_DATABITS = 65,

    parameter RADM_Q_DATABITS_O = 65,

    parameter LBC_EXT_AW = 6'h20,


    parameter RADM_PQ_HWD = 140,

    parameter RADM_NPQ_HWD = 140,

    parameter RADM_CPLQ_HWD = 104,

    parameter RADM_PQ_HPW = 6,

    parameter RADM_NPQ_HPW = 6,

    parameter RADM_CPLQ_HPW = 2,

    parameter RADM_PQ_DPW = 8,

    parameter RADM_NPQ_DPW = 5,

    parameter RADM_CPLQ_DPW = 2,


    parameter RADM_Q_H_CTRLBITS = 1,

    parameter RADM_Q_D_CTRLBITS = 1,

    parameter RADM_PQ_H_DATABITS = 135,

    parameter RADM_PQ_H_DATABITS_O = 135,

    parameter RADM_NPQ_H_DATABITS = 140,

    parameter RADM_NPQ_H_DATABITS_O = 140,

    parameter RADM_CPLQ_H_DATABITS = 104,

    parameter RADM_CPLQ_H_DATABITS_O = 104,


    parameter RADM_PQ_H_ADDRBITS = 7,

    parameter RADM_NPQ_H_ADDRBITS = 7,

    parameter RADM_CPLQ_H_ADDRBITS = 7,

    parameter RADM_PQ_D_ADDRBITS = 8,

    parameter RADM_NPQ_D_ADDRBITS = 8,

    parameter RADM_CPLQ_D_ADDRBITS = 8,


    parameter RADM_PQ_HDP = 34,

    parameter RADM_NPQ_HDP = 34,

    parameter RADM_CPLQ_HDP = 3,

    parameter RADM_PQ_DDP = 161,

    parameter RADM_NPQ_DDP = 17,

    parameter RADM_CPLQ_DDP = 3,

    parameter DCA_WD = 1,

    parameter APP_CRD_WD = 1,

    parameter BUSNUM_WD = 8,

    parameter DEVNUM_WD = 5,

    parameter N_FLT_MASK = 5'h1c,


    parameter CPL_LUT_DEPTH = 8,
    
    parameter SLV_DATA_WD = 64,

    parameter SLV_DATAP_WD = 1,

    parameter SLV_AW_USER_WIDTH = 0,

    parameter SLV_W_USER_WIDTH = 0,

    parameter SLV_AR_USER_WIDTH = 0,

    parameter SLV_R_USER_WIDTH = 0,

    parameter SLV_B_USER_WIDTH = 0,

    parameter SLV_ADDR_WD = 32,

    parameter SLV_ADDRP_WD = 1,

    parameter SLV_LOCK_WD = 2,

    parameter SLV_WSTRB_WD = 8,

    parameter SLV_ID_WD = 3,

    parameter DBI_SLV_DATA_WD = 32,

    parameter DBI_SLV_AW_USER_WIDTH = 0,

    parameter DBI_SLV_W_USER_WIDTH = 0,

    parameter DBI_SLV_AR_USER_WIDTH = 0,

    parameter DBI_SLV_R_USER_WIDTH = 0,

    parameter DBI_SLV_B_USER_WIDTH = 0,

    parameter DBI_SLV_WSTRB_WD = 4,

    parameter DBI_SLV_ADDR_WD = 32,

    parameter DBI_SLV_LOCK_WD = 2,

    parameter DBI_SLV_ID_WD = 4,

    parameter DATA_PAR_CALC_WIDTH = 0,

    parameter ADDR_PAR_CALC_WIDTH = 0,
    
    parameter DBI_NUM_MASTERS = 16,

    parameter DBI_NUM_MSTRS_WD = 4,
    

    parameter MSTR_DATA_WD = 64,

    parameter MSTR_DATAP_WD = 1,

    parameter MSTR_AW_USER_WIDTH = 0,

    parameter MSTR_W_USER_WIDTH = 0,

    parameter MSTR_AR_USER_WIDTH = 0,

    parameter MSTR_R_USER_WIDTH = 0,

    parameter MSTR_B_USER_WIDTH = 0,

    parameter MSTR_ADDR_WD = 32,

    parameter MSTR_ADDRP_WD = 1,

    parameter MSTR_LOCK_WD = 2,

    parameter MSTR_WSTRB_WD = 8,

    parameter MSTR_ID_WD_CORE = 1,

    parameter MSTR_ID_WD = 1,
    
     parameter SLV_NPW_SAB_RAM_DATA_WD = 93,

     parameter SLV_NPW_SAB_RAM_ADDR_WD = 5,

     parameter SLV_NPW_SAB_RAM_ADDRP_WD = 1,
     
     parameter SLV_WRP_RSP_ROB_FIFO_ADDR_WD = 4,
     
     parameter OB_NPDCMP_RAM_DATA_WD = 115,

     parameter OB_NPDCMP_RAM_ADDR_WD = 3,

     parameter OB_NPDCMP_RAM_ADDRP_WD = 1,
     
     parameter OB_PDCMP_HDR_RAM_DATA_WD = 76,

     parameter OB_PDCMP_HDR_RAM_ADDR_WD = 4,

     parameter OB_PDCMP_HDR_RAM_ADDRP_WD = 1,
     
     parameter OB_PDCMP_DATA_RAM_DATA_WD = 64,

     parameter OB_PDCMP_DATA_RAM_ADDR_WD = 6,

     parameter OB_PDCMP_DATA_RAM_ADDRP_WD = 1,
     
     parameter OB_CCMP_DATA_RAM_DATA_WD = 67,

     parameter OB_CCMP_DATA_RAM_ADDR_WD = 8,

     parameter OB_CCMP_DATA_RAM_ADDRP_WD = 1,
     
      parameter CC_IB_RD_REQ_ORDR_RAM_ADDR_WD = 3,

      parameter CC_IB_RD_REQ_ORDR_RAM_ADDRP_WD = 1,

      parameter CC_IB_RD_REQ_ORDR_RAM_DATA_WD = 131,
      
      parameter CC_IB_RD_REQ_CDC_RAM_ADDR_WD = 4,

      parameter CC_IB_RD_REQ_CDC_RAM_ADDRP_WD = 1,

      parameter CC_IB_WR_REQ_CDC_RAM_ADDR_WD = 4,

      parameter CC_IB_WR_REQ_CDC_RAM_ADDRP_WD = 1,
      
      parameter CC_IB_WR_REQ_CDC_RAM_DATA_WD = 228,

      parameter CC_IB_RD_REQ_CDC_RAM_DATA_WD = 140,
      
      parameter CC_IB_MCPL_CDC_RAM_ADDR_WD = 4,

      parameter CC_IB_MCPL_CDC_RAM_ADDRP_WD = 1,

      parameter CC_IB_MCPL_CDC_RAM_DATA_WD = 82,
      
      parameter CC_IB_MCPL_SEG_BUF_RAM_DATA_WD = 67,

      parameter CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD = 13,

      parameter CC_IBH_MCPL_SEG_BUF_RAM_ADDR_WD = 14,

      parameter CC_IB_MCPL_SEG_BUF_RAM_ADDRP_WD = 1,

      parameter CC_IBH_MCPL_SEG_BUF_RAM_ADDRP_WD = 1,
      
      parameter CC_IB_WR_REQ_PTRK_HDR_RAM_ADDR_WD = 5,

      parameter CC_IB_WR_REQ_PTRK_HDR_RAM_ADDRP_WD = 1,

      parameter CC_IB_WR_REQ_PTRK_HDR_RAM_DATA_WD = 147,

      parameter CC_IB_WR_REQ_PTRK_DATA_RAM_ADDR_WD = 6,

      parameter CC_IB_WR_REQ_PTRK_DATA_RAM_ADDRP_WD = 1,

      parameter CC_IB_WR_REQ_PTRK_DATA_RAM_DATA_WD = 64,
      
      parameter DTIM_AXI4SS_REQ_Q_RAM_DATA_WD = 105,

      parameter DTIM_AXI4SS_REQ_Q_RAM_ADDR_WD = 4,

      parameter DTIM_AXI4SS_REQ_Q_RAM_ADDRP_WD = 0,

      parameter DTIM_NUM_BYTES_PER_BEAT = 20,

      parameter DTIM_DATA_WD = 160,

      parameter DTIM_INTF_PROT_WD = 0,

      parameter PCIE_ATS_INV_REQ_ITAG_WD = 5,

      parameter DTIM_ATS_SID_LWR_WD = 16,
      
      parameter AXI_RAS_ERR_INJ_EN_INTF_WD = 0,

      parameter AXI_RAS_ERR_INJ_MASK_INTF_WD = 2,
      
      parameter DTIM_RAS_ERR_UC_INTF_WD = 13,

      parameter DTIM_RAS_ERR_C_INTF_WD = 1,
      
      parameter DTIM_RAS_RAM_ERR_C_INTF_WD = 1,

      parameter DTIM_RAS_RAM_ERR_UC_INTF_WD = 1,

      parameter DTIM_RAS_RAM_ERR_ADDR_INTF_WD = 4,

      parameter DTIM_RAS_RAM_ERR_SYND_INTF_WD = 0,
      
      parameter XADMX_CLIENT1_QUEUE_DWD = 65,

      parameter XADMX_CLIENT1_QUEUE_DPW = 6,
      
      parameter XADMX_CLIENT1_QUEUE_HWD = 114,

      parameter XADMX_CLIENT1_QUEUE_HPW = 3,
      
      parameter SLV_DECOMP_TAG_LOW = 0,

      parameter SLV_DECOMP_TAG_HIGH = 7,

      parameter SLV_DECOMP_TAG_DP_PW = 3,
      
      parameter CLIENT1_TS_DATAQ_ADDR_PW = 3,

      parameter CLIENT1_TS_DATAQ_WIDTH = 32,
      
      parameter RADMX_COMPOSER_DATAQ_PW = 8,

      parameter RADMX_COMPOSER_DATAQ_WD = 67,
      
      parameter FIFO_PW = 4,

      parameter FIFO_WD = 97,
      
      parameter RADMX_DECOMPOSER_DATAQ_PW = 2,

      parameter RADMX_DECOMPOSER_DATAQ_WD = 65,
      
      parameter RADMX_DECOMPOSER_HDRQ_PW = 2,

      parameter RADMX_DECOMPOSER_HDRQ_WD = 128,
      
      parameter CC_MCB_A2C_FIFO_ADDR_WD = 4,

      parameter CC_MSTR_RSP_INTF_WD = 82,
      
      parameter CC_MSTR_CPL_SEG_BUF_DATA_WD = 67,

      parameter CC_MSTR_CPL_SEG_BUF_ADDR_WD = 13,
      

    parameter MSTR_MISC_INFO_PW = 48,

    parameter SLV_MISC_INFO_PW = 22,

    parameter MSTR_RESP_MISC_INFO_PW = 13,

    parameter SLV_RESP_MISC_INFO_PW = 11,

    parameter MSTR_BURST_LEN_PW = 4,

    parameter SLV_BURST_LEN_PW = 4,

    parameter DBISLV_BURST_LEN_PW = 4,
    
    parameter SLV_NUM_MASTERS = 16,

    parameter SLAVE_NUM_MSTRS_WD = 4,
    

    parameter MAX_MSTR_TAGS = 1,

    parameter MAX_MSTR_TAG_PW = 1,


    parameter MAX_WIRE_TAG = 8,


    parameter MAX_WIRE_TAG_PW = 3,


    parameter CORE_ADDR_BUS_WD = 64,

    parameter ADDR_PAR_CALC_WIDTH_NO_ZERO = 1,

    parameter CORE_ADDR_PAR_WD = 0,
    
    parameter DMA_CTX_RAM_ADDR_WIDTH = 3,
    
    parameter DMA_CTX_RAM_ADDRP_WIDTH = 1,
    

    parameter DMA_CTX_RAM_DATA_WIDTH = 256,


    parameter DMA_SEG_BUF_NW_ADDR_WIDTH = 8,
    
    parameter DMA_SEG_BUF_NW_ADDRP_WIDTH = 1,
    

    parameter DMA_SEG_BUF_DATA_WIDTH = 64,
    
    parameter NVF = 2,

    parameter INT_NVF = 2,
    
    parameter VFI_WD = 1,

    parameter VF_WD = 2,
    
    parameter VF_RAM_DATABITS = 3,

    parameter VF_RAM_ADDRBITS = 1,

    parameter VF_RAM_CTRLBITS = 1,
    
    parameter RASDES_EC_RAM_DATA_WIDTH = 64,

    parameter RASDES_EC_RAM_ADDR_WIDTH = 1,

    parameter RASDES_EC_RAM_DEPTH = 0,

    parameter RASDES_EC_INFO_CM = 177,

    parameter RASDES_EC_INFO_PL = 13,
    
    parameter RASDES_TBA_RAM_DATA_WIDTH = 64,

    parameter RASDES_TBA_RAM_ADDR_WIDTH = 1,

    parameter RASDES_TBA_RAM_DEPTH = 1,
    
    parameter RASDES_SD_INFO_CM = 79,

    parameter RASDES_SD_INFO_PL = 205,

    parameter RASDES_SD_INFO_PV = 240,
    
    parameter RASDES_TBA_INFO_CM = 7,
    

    parameter TX_COEF_WD = 18,
    
    parameter RX_PSET_WD = 3,

    parameter TX_PSET_WD = 4,

    parameter TX_FSLF_WD = 12,

    parameter TX_FS_WD = 6,

    parameter TX_CRSR_WD = 6,

    parameter PHY_RXSB_WD = 1,

    parameter PHY_RXSH_WD = 2,
    
    parameter DIRFEEDBACK_WD = 6,

    parameter FOMFEEDBACK_WD = 8,
    

    parameter ORIG_DATA_WD = 16,

    parameter SERDES_DATA_WD = 20,

    parameter PIPE_DATA_WD = 64,

    parameter PDWN_WIDTH = 4,

    parameter RATE_WIDTH = 1,

    parameter P_R_WD = 3,

    parameter WIDTH_WIDTH = 2,

    parameter TX_DEEMPH_WD = 2,

    parameter PHY_TXEI_WD = 1,
    
    parameter ATU_OUT_REGIONS = 2,

    parameter ATU_IN_REGIONS = 2,
    
    parameter ATU_BASE_WD = 32,
    
    parameter ATU_REG_WD = 16,

    parameter ATU_UPR_LMT_WD = 0,

    parameter ATU_IN_MIN1 = 2,
    
    parameter ERR_BUS_WD = 15,

    parameter RX_TLP = 1,

    parameter FX_TLP = 1,


    parameter TAG_SIZE = 8,

    parameter LOOKUPID_WD = 8,
    
    parameter SATA_IDX_WD = 64,
    

    parameter ATTR_WD = 2,


    parameter AXI_IF_PAR_ECC_ENABLED = 0,
    
    parameter CX_TLP_PREFIX_ENABLE_VALUE = 0,

    parameter PRFX_W_PAR = 32,

    parameter NW_PRFX = 0,

    parameter PRFX_PAR_WD = 0,

    parameter PRFX_DW = 32,

    parameter PRFX_WIDTH = 0,
    

    parameter LBC_INT_WD = 32,
    

    parameter MSIX_TABLE_SIZE = 11'h0,

    parameter MSIX_PBA_SIZE = 0,

    parameter MSIX_TABLE_RAM_DEPTH = 0,

    parameter MSIX_PBA_RAM_DEPTH = 0,

    parameter MSIX_PBA_PW = 1,

    parameter MSIX_TABLE_PW = 1,

    parameter MSIX_TABLE_DW = 131,

    parameter MSIX_TABLE_WEW = 17,

    parameter MSIX_TABLE_RAM_RD_LATENCY = 1,

    parameter MSIX_PBA_RAM_RD_LATENCY = 1,
    

    parameter GEN2_DYNAMIC_FREQ_VALUE = 0,
    
    parameter RAS_PROT_RANGE = 64,

    parameter RAS_PROT_TYPE = 0,

    parameter RAS_CORR_EN = 1,

    parameter RAS_PARITY_MODE = 0,

    parameter ERROR_INJ_EN_WD = 256,

    parameter ERROR_INJ_MASK_WD = 2400,

    parameter APP_ERROR_WD = 52,

    parameter RASDP_TRGT1_HDR_PROT_WD = 0,

    parameter RASDP_BYPASS_HDR_PROT_WD = 0,

    parameter RASDP_HDRQ_ERR_SYND_WD = 0,

    parameter RASDP_DATAQ_ERR_SYND_WD = 0,

    parameter RASDP_RBUF_ERR_SYND_WD = 0,

    parameter RASDP_SOTBUF_ERR_SYND_WD = 0,

    parameter RADM_SBUF_HDRQ_ERR_ADDR_WD = 8,
    
    parameter APP_ERROR_ADDR_WD = 54,

    parameter APP_CORR_DISABLE_WD = 1,
    
    parameter RADM_RAM_RD_LATENCY = 1,

    parameter RADM_FORMQ_RAM_RD_LATENCY = 1,

    parameter RETRY_RAM_RD_LATENCY = 1,

    parameter RETRY_SOT_RAM_RD_LATENCY = 1,
    
    parameter NQW = 2,

    parameter RAM_WD = 135,

    parameter RAM_DP = 44,

    parameter RAM_PW = 6,

    parameter RASDP_FORMQ_ERR_SYND_WD = 0,
    
    parameter ACS_CTRL_VEC_WD = 9'h4,
    
    parameter PHY_VPT_NUM = 1,

    parameter PHY_VPT_DATA = 16,
    
    parameter CCIX_HDR_WD = 128,

    parameter CCIX_HDR_PROT_WD = 0,

    parameter CX_CCIX_HDR_WD = 128,

    parameter CX_CCIX_DATA_WD = 64,
    
    parameter CXSDATAFLITWIDTH = 256,

    parameter CXSCNTLWIDTH = 14,

    parameter CXS_RX_BUFF_DEPTH = 32,

    parameter CXS_RX_BUFF_DATAW = 270,

    parameter CXS_RX_BUFF_ADDRW = 5,

    parameter CXS_TX_BUFF_DEPTH = 16,

    parameter CXS_TX_BUFF_DATAW = 270,

    parameter CXS_TX_BUFF_ADDRW = 4,
    
    parameter CXSDATACHKWIDTH = 32,

    parameter CXSCNTLCHKWIDTH = 1,
    
    parameter CXSRXREPWIDTH = 0,
    
    parameter CXSTXREPWIDTH = 0,
    

    parameter HCRD_WD = 8,

    parameter DCRD_WD = 12,
    
    parameter PSET_ID_WD = 4,
    
    parameter AUX_CLK_FREQ_WD = 10,
    

    parameter XADM_RFC_IN_WD = 34,

    parameter RADM_RFC_OUT_WD = 34,

    parameter XADM_XTLH_OUT_WD = 204,

    parameter RTLH_RAMD_IN_WD = 204,

    parameter LTSSM_EMU_IN_WD = 11,

    parameter LTSSM_EMU_OUT_WD = 11,

    parameter FREQ = 2,

    parameter GEN3_MODE = 2,
    
    parameter CORE_SYNC_DEPTH = 2,

    parameter PM_MST_WD = 5,

    parameter PM_SLV_WD = 5,
    
    parameter CPL_LUT_PTR_WD = 3,

    parameter DPC_PRFX_LOG_SIZE = 0,

    parameter DPC_PRFX_LOG_WD = 0
    )

                   (
  // list of port declarations
    // XALI0 interface
    input [NVC_XALI_EXP-1:0]            client0_addr_align_en,
    input   [(NVC_XALI_EXP*8)-1:0]      client0_tlp_byte_en,
    input   [(NVC_XALI_EXP*16)-1:0]     client0_remote_req_id,
    input   [(NVC_XALI_EXP*12)-1:0]     client0_cpl_byte_cnt,
    input   [(NVC_XALI_EXP*3)-1:0]      client0_tlp_tc,
    input   [(NVC_XALI_EXP*ATTR_WD)-1:0]client0_tlp_attr,
    input   [(NVC_XALI_EXP*3)-1:0]    client0_cpl_status,
    input  [NVC_XALI_EXP-1:0]         client0_cpl_bcm,
    input  [NVC_XALI_EXP-1:0]           client0_tlp_dv,
    input  [NVC_XALI_EXP-1:0]           client0_tlp_eot,
    input [NVC_XALI_EXP-1:0]            client0_tlp_bad_eot,
    input [NVC_XALI_EXP-1:0]            client0_tlp_hv,
    input   [(NVC_XALI_EXP*2)-1:0]      client0_tlp_fmt,
    input   [(NVC_XALI_EXP*5)-1:0]      client0_tlp_type,
    input   [NVC_XALI_EXP-1:0]          client0_tlp_td,
    input   [NVC_XALI_EXP-1:0]          client0_tlp_ep,
    input   [(NVC_XALI_EXP*13)-1:0]     client0_tlp_byte_len,
    input   [(NVC_XALI_EXP*64)-1:0]      client0_tlp_addr,
    input   [(NVC_XALI_EXP*TAG_SIZE)-1:0] client0_tlp_tid,
    input   [(NVC_XALI_EXP*DW_W_PAR)-1:0]client0_tlp_data,
    input   [(NVC_XALI_EXP*PF_WD)-1:0]  client0_tlp_func_num,
    output  [NVC_XALI_EXP-1:0]         xadm_client0_halt,




    // XALI1 interface
    input  [NVC_XALI_EXP-1:0]            client1_addr_align_en,
    input   [(NVC_XALI_EXP*8)-1:0]        client1_tlp_byte_en,
    input   [(NVC_XALI_EXP*16)-1:0]       client1_remote_req_id,
    input   [(NVC_XALI_EXP*3)-1:0]         client1_cpl_status,
    input   [NVC_XALI_EXP-1:0]          client1_cpl_bcm,
    input   [(NVC_XALI_EXP*12)-1:0]     client1_cpl_byte_cnt,
    input  [NVC_XALI_EXP-1:0]           client1_tlp_dv,
    input  [NVC_XALI_EXP-1:0]            client1_tlp_eot,
    input  [NVC_XALI_EXP-1:0]          client1_tlp_bad_eot,
    input  [NVC_XALI_EXP-1:0]          client1_tlp_hv,
    input   [(NVC_XALI_EXP*2)-1:0]      client1_tlp_fmt,
    input   [(NVC_XALI_EXP*5)-1:0]      client1_tlp_type,
    input   [(NVC_XALI_EXP*3)-1:0]      client1_tlp_tc,
    input   [NVC_XALI_EXP-1:0]           client1_tlp_td,
    input   [NVC_XALI_EXP-1:0]            client1_tlp_ep,
    input   [(NVC_XALI_EXP*ATTR_WD)-1:0]   client1_tlp_attr,
    input   [(NVC_XALI_EXP*13)-1:0]        client1_tlp_byte_len,
    input   [(NVC_XALI_EXP*TAG_SIZE)-1:0]  client1_tlp_tid,
    input   [(NVC_XALI_EXP*64)-1:0]        client1_tlp_addr,
    input   [(NVC_XALI_EXP*DW_W_PAR)-1:0]      client1_tlp_data,
    input   [(NVC_XALI_EXP*PF_WD)-1:0]         client1_tlp_func_num,
    output  [NVC_XALI_EXP-1:0]           xadm_client1_halt,





    // RCPL interface
    output  [DW_W_PAR-1:0]              radm_bypass_data,
    output  [NW-1:0]                    radm_bypass_dwen,
    output  [NHQ-1:0]                   radm_bypass_dv,
    output  [NHQ-1:0]                   radm_bypass_hv,
    output  [NHQ-1:0]                   radm_bypass_eot,
    output  [NHQ-1:0]                   radm_bypass_dllp_abort,
    output  [NHQ-1:0]                   radm_bypass_tlp_abort,
    output  [NHQ-1:0]                   radm_bypass_ecrc_err,
    output  [NHQ*2-1:0]                 radm_bypass_fmt,
    output  [NHQ*5-1:0]                 radm_bypass_type,
    output  [NHQ*3-1:0]                 radm_bypass_tc,
    output  [NHQ*ATTR_WD-1:0]           radm_bypass_attr,
    output  [NHQ*16-1:0]                radm_bypass_reqid,
    output  [NHQ*TAG_SIZE-1:0]          radm_bypass_tag,
    output  [NHQ*PF_WD-1:0]             radm_bypass_func_num,
    output  [NHQ-1:0]                   radm_bypass_td,
    output  [NHQ-1:0]                   radm_bypass_poisoned,
    output  [NHQ*10-1:0]                radm_bypass_dw_len,
    output  [NHQ*4-1:0]                 radm_bypass_first_be,
    output  [NHQ*4-1:0]                 radm_bypass_last_be,
    output  [NHQ*`FLT_Q_ADDR_WIDTH -1:0]radm_bypass_addr,
    output  [NHQ-1:0]                   radm_bypass_rom_in_range,
    output  [NHQ-1:0]                   radm_bypass_io_req_in_range,
    output  [NHQ*3-1:0]                 radm_bypass_in_membar_range,
    output  [NHQ-1:0]                   radm_bypass_bcm,
    output  [NHQ-1:0]                   radm_bypass_cpl_last,
    output  [NHQ*16-1:0]                radm_bypass_cmpltr_id,
    output  [NHQ*12-1:0]                radm_bypass_byte_cnt,
    output  [NHQ*3-1:0]                 radm_bypass_cpl_status,
    output                              radm_cpl_timeout,
    output  [PF_WD-1:0]                 radm_timeout_func_num,
    output  [2:0]                       radm_timeout_cpl_tc,
    output  [1:0]                       radm_timeout_cpl_attr,
    output  [11:0]                      radm_timeout_cpl_len,
    output  [TAG_SIZE-1:0]              radm_timeout_cpl_tag,

    // RTRGT1 interface
    input                               trgt1_radm_halt,
    output                              radm_trgt1_dv,
    output                              radm_trgt1_hv,
    output                              radm_trgt1_eot,
    output                              radm_trgt1_tlp_abort,
    output                              radm_trgt1_dllp_abort,
    output                              radm_trgt1_ecrc_err,
    output  [TRGT_DATA_WD-1:0]          radm_trgt1_data,
    output  [NW-1:0]                    radm_trgt1_dwen,
    output  [1:0]                       radm_trgt1_fmt,
    output  [4:0]                       radm_trgt1_type,
    output  [2:0]                       radm_trgt1_tc,
    output  [ATTR_WD-1:0]               radm_trgt1_attr,
    output  [15:0]                      radm_trgt1_reqid,
    output  [TAG_SIZE-1:0]              radm_trgt1_tag,
    output  [PF_WD-1:0]                 radm_trgt1_func_num,
    output                              radm_trgt1_td,
    output                              radm_trgt1_poisoned,
    output  [9:0]                       radm_trgt1_dw_len,
    output  [3:0]                       radm_trgt1_first_be,
    output  [3:0]                       radm_trgt1_last_be,
    output  [ADDR_WIDTH-1:0]            radm_trgt1_addr,
    output  [ADDR_WIDTH-1:0]            radm_trgt1_hdr_uppr_bytes,
    output                              radm_trgt1_rom_in_range,
    output  [2:0]                       radm_trgt1_in_membar_range,
    output                              radm_trgt1_io_req_in_range,
    output [2:0]                        radm_trgt1_cpl_status,

    output                         radm_trgt1_bcm,
    output [11:0]                  radm_trgt1_byte_cnt,
    output                         radm_trgt1_cpl_last,
    output [15:0]                  radm_trgt1_cmpltr_id,

    output [2:0]                   radm_trgt1_vc,

    output  [(NVC*3)-1:0]               radm_grant_tlp_type,
    input  [(NVC*3)-1:0]           trgt1_radm_pkt_halt,

       // DBI interface
    input   [31:0]                      dbi_addr,
    input   [31:0]                      dbi_din,
    input                               dbi_cs,
    input                               dbi_cs2,
    input   [3:0]                       dbi_wr,
    output                              lbc_dbi_ack,
    output  [31:0]                      lbc_dbi_dout,
    // ELBI interface
    input   [NF-1:0]                    ext_lbc_ack,
    input   [(`CX_LBC_NW*32*NF)-1:0]    ext_lbc_din,
    output  [LBC_EXT_AW-1:0]            lbc_ext_addr,
    output  [`CX_LBC_NW*32-1:0]         lbc_ext_dout,
    output  [NF-1:0]                    lbc_ext_cs,
    output  [(4*`CX_LBC_NW)-1:0]        lbc_ext_wr,
    output                              lbc_ext_dbi_access,    
    output                              lbc_ext_rom_access,
    output                              lbc_ext_io_access,
    output  [2:0]                       lbc_ext_bar_num,
    // MSI interface
    input                               ven_msi_req,
    input   [PF_WD-1:0]                 ven_msi_func_num,
    input   [2:0]                       ven_msi_tc,
    input   [4:0]                       ven_msi_vector,
    output                              ven_msi_grant,
    output  [NF-1:0]                    cfg_msi_en,

    // MSI-X interface

    // VPD interface


    // FLR interface



    // VMI interface
    input   [1:0]                       ven_msg_fmt,
    input   [4:0]                       ven_msg_type,
    input   [2:0]                       ven_msg_tc,
    input                               ven_msg_td,
    input                               ven_msg_ep,
    input   [ATTR_WD-1:0]               ven_msg_attr,
    input   [9:0]                       ven_msg_len,
    input   [PF_WD-1:0]                 ven_msg_func_num,
    input   [TAG_SIZE-1:0]              ven_msg_tag,
    input   [7:0]                       ven_msg_code,
    input   [63:0]                      ven_msg_data,
    input                               ven_msg_req,
    output                              ven_msg_grant,

    // SII interface
    input                               rx_lane_flip_en,
    input                               tx_lane_flip_en,


    input   [NF-1:0]                    sys_int,
    input   [NF-1:0]                    outband_pwrup_cmd,
    input   [NF-1:0]                    apps_pm_xmt_pme,
    input                               sys_aux_pwr_det,
    input   [NF-1:0]                    sys_atten_button_pressed,
    input   [NF-1:0]                    sys_pre_det_state,
    input   [NF-1:0]                    sys_mrl_sensor_state,
    input   [NF-1:0]                    sys_pwr_fault_det,
    input   [NF-1:0]                    sys_mrl_sensor_chged,
    input   [NF-1:0]                    sys_pre_det_chged,
    input   [NF-1:0]                    sys_cmd_cpled_int,
    input   [NF-1:0]                    sys_eml_interlock_engaged,
    output  [(2*NF)-1:0]                cfg_pwr_ind,
    output  [(2*NF)-1:0]                cfg_atten_ind,
    output  [NF-1:0]                    cfg_pwr_ctrler_ctrl,
    input                               apps_pm_xmt_turnoff,
    input                               app_unlock_msg,
    output                              pm_xtlh_block_tlp,
    output  [(64*NF)-1:0]               cfg_bar0_start,
    output  [(32*NF)-1:0]               cfg_bar1_start,
    output  [(64*NF)-1:0]               cfg_bar0_limit,
    output  [(32*NF)-1:0]               cfg_bar1_limit,
    output  [(64*NF)-1:0]               cfg_bar2_start,
    output  [(64*NF)-1:0]               cfg_bar2_limit,
    output  [(32*NF)-1:0]               cfg_bar3_start,
    output  [(32*NF)-1:0]               cfg_bar3_limit,
    output  [(64*NF)-1:0]               cfg_bar4_start,
    output  [(64*NF)-1:0]               cfg_bar4_limit,
    output  [(32*NF)-1:0]               cfg_bar5_start,
    output  [(32*NF)-1:0]               cfg_bar5_limit,
    output  [(32*NF)-1:0]               cfg_exp_rom_start,
    output  [(32*NF)-1:0]               cfg_exp_rom_limit,
    output  [NF-1:0]                    cfg_bus_master_en,
    output  [NF-1:0]                    cfg_mem_space_en,
    output  [(3*NF)-1:0]                cfg_max_rd_req_size,
    output  [(3*NF)-1:0]                cfg_max_payload_size,
    output  [NF-1:0]                    cfg_rcb,
    output  [NF -1 :0]                  cfg_pm_no_soft_rst,
    output  [NF-1:0]                    cfg_aer_rc_err_int,
    output  [NF-1:0]                    cfg_aer_rc_err_msi,
    output  [(NF*5)-1:0]                cfg_aer_int_msg_num,
    output  [NF-1:0]                    cfg_sys_err_rc,
    output  [NF-1:0]                    cfg_pme_int,
    output  [NF-1:0]                    cfg_pme_msi,
    output  [NF-1:0]                    cfg_crs_sw_vis_en,
    output  [(NF*5)-1:0]                cfg_pcie_cap_int_msg_num,
    output                              rdlh_link_up,
    output  [2:0]                       pm_curnt_state,
    output  [5:0]                       smlh_ltssm_state,
    output                              smlh_link_up,
    output                              smlh_req_rst_not,
    output                              link_req_rst_not,
    output  [FX_TLP-1:0]                radm_vendor_msg,
    output  [(FX_TLP*64)-1:0]           radm_msg_payload,
    output                              radm_msg_unlock,
    output  [(FX_TLP*16)-1:0]           radm_msg_req_id,
    output                              radm_inta_asserted,
    output                              radm_intb_asserted,
    output                              radm_intc_asserted,
    output                              radm_intd_asserted,
    output                              radm_inta_deasserted,
    output                              radm_intb_deasserted,
    output                              radm_intc_deasserted,
    output                              radm_intd_deasserted,
    output                              radm_correctable_err,
    output                              radm_nonfatal_err,
    output                              radm_fatal_err,
    output                              radm_pm_pme,
    output                              radm_pm_to_ack,
    output                              radm_pm_turnoff,
    output  [RX_NDLLP-1:0]              rtlh_rfc_upd,
    output  [(32*RX_NDLLP)-1:0]         rtlh_rfc_data,
    output                              wake,
    output                              local_ref_clk_req_n,
    output  [NF-1:0]                    cfg_eml_control,
    output  [NF-1:0]                    hp_pme,
    output  [NF-1:0]                    hp_int,
    output  [NF-1:0]                    hp_msi,
    input                               app_ltssm_enable,
    output  [BUSNUM_WD-1:0]             cfg_pbus_num,
    output  [DEVNUM_WD-1:0]             cfg_pbus_dev_num,
    output  [(3*NF)-1:0]                pm_dstate,
    output  [NF-1:0]                    pm_pme_en,
    output                              pm_linkst_in_l0s,
    output                              pm_linkst_in_l1,
    output                              pm_linkst_in_l2,
    output                              pm_linkst_l2_exit,
    output  [(PM_MST_WD - 1):0]         pm_master_state,
    output  [(PM_SLV_WD - 1):0]         pm_slave_state,
    output  [NF-1:0]                    pm_status,
    output  [NF-1:0]                    aux_pm_en,
    output                              cfg_link_auto_bw_int,
    output                              cfg_link_auto_bw_msi,
    output                              cfg_bw_mgt_int,
    output                              cfg_bw_mgt_msi,
    output  [NVC-1:0]                   radm_q_not_empty,
    output  [NVC-1:0]                   radm_qoverflow,




    // PIPE interface
    output  [(PDWN_WIDTH - 1) : 0]                       mac_phy_powerdown,
    input   [NL-1:0]                    phy_mac_rxelecidle,
    input   [NL-1:0]                    phy_mac_phystatus,
    input   [(PIPE_DATA_WD - 1):0]         phy_mac_rxdata,
    input   [(NL*PHY_NB)-1:0]           phy_mac_rxdatak,
    input   [NL-1:0]                    phy_mac_rxvalid,
    input   [(NL*3)-1:0]                phy_mac_rxstatus,
    input   [NL-1:0]                    phy_mac_rxstandbystatus,
    input   [31:0]                      phy_cfg_status,
    output  [(PIPE_DATA_WD - 1):0]         mac_phy_txdata,
    output  [(NL*PHY_NB)-1:0]           mac_phy_txdatak,
    output                              mac_phy_elasticbuffermode,
    output  [NL-1:0]                    mac_phy_txdatavalid,

    output  [NL-1:0]                    mac_phy_txdetectrx_loopback,
    output  [NL*PHY_TXEI_WD-1:0]       mac_phy_txelecidle,
    output  [NL-1:0]                    mac_phy_txcompliance,
    output  [NL-1:0]                    mac_phy_rxpolarity,
    output  [WIDTH_WIDTH-1:0]           mac_phy_width,
    output  [P_R_WD-1:0]                       mac_phy_pclk_rate,
    output  [NL-1:0]                    mac_phy_rxstandby,


    output  [2:0]                       pm_current_data_rate,



    input   [NL-1:0]                    phy_mac_rxdatavalid,
    output  [31:0]                      cfg_phy_control,
    // clk_and_reset interface
    input                               core_clk,
    input                               core_clk_ug,
    input                               aux_clk,
    input                               aux_clk_g,
    output                              en_aux_clk_g,
    input                               radm_clk_g,
    output                              en_radm_clk_g,
    output                              radm_idle,
    input                               pwr_rst_n,
    input                               sticky_rst_n,
    input                               non_sticky_rst_n,
    input                               core_rst_n,
    input               perst_n,
    input               app_clk_req_n,
    input               phy_clk_req_n,
    output              pm_req_sticky_rst,
    output              pm_req_core_rst,
    output              pm_req_non_sticky_rst,
    output              pm_sel_aux_clk,
    output              pm_en_core_clk,
    output              pm_req_phy_rst,
    output              pm_req_phy_perst,
    input                               app_req_entr_l1,
    input                               app_ready_entr_l23,
    //<ct:CX_IS_SW><br><i>Note:</i> The controller ignores this input in a downstream port.</ct>
    input                               app_req_exit_l1,
    input                               app_xfer_pending,
    input                               app_init_rst,

    input   [3:0]                       device_type,
    input                               app_req_retry_en,
    input  [NF-1:0]                       app_pf_req_retry_en,


    // DBI Read-only Write Disable
    input                              app_dbi_ro_wr_disable,


    output                              training_rst_n,

   // RAM moved out of the TOP
    // Retry buffer external RAM interface
    output  [RBUF_PW -1:0]              xdlh_retryram_addr,
    output  [`RBUF_WIDTH-1:0]           xdlh_retryram_data,
    output                              xdlh_retryram_we,
    output                              xdlh_retryram_en,
    input   [`RBUF_WIDTH-1:0]           retryram_xdlh_data,

    // Retry SOT buffer
    output  [SOTBUF_PW -1:0]            xdlh_retrysotram_waddr,
    output  [SOTBUF_PW -1:0]            xdlh_retrysotram_raddr,
    output  [SOTBUF_WD -1:0]            xdlh_retrysotram_data,
    output                              xdlh_retrysotram_we,
    output                              xdlh_retrysotram_en,
    input   [SOTBUF_WD -1:0]            retrysotram_xdlh_data,

    // For the effort of bring RAM outside of the hiarch.
    // Beneath are grouped outputs and input  s just for RAM
    input   [RADM_PQ_H_DATABITS_O-1:0]  p_hdrq_dataout,
    output  [RADM_PQ_H_ADDRBITS-1:0]    p_hdrq_addra,
    output  [RADM_PQ_H_ADDRBITS-1:0]    p_hdrq_addrb,
    output  [RADM_PQ_H_DATABITS-1:0]    p_hdrq_datain,
    output  [RADM_Q_H_CTRLBITS-1:0]     p_hdrq_ena,
    output  [RADM_Q_H_CTRLBITS-1:0]     p_hdrq_enb,
    output  [RADM_Q_H_CTRLBITS-1:0]     p_hdrq_wea,
    input   [RADM_Q_DATABITS_O-1:0]     p_dataq_dataout,
    output  [RADM_PQ_D_ADDRBITS-1:0]    p_dataq_addra,
    output  [RADM_PQ_D_ADDRBITS-1:0]    p_dataq_addrb,
    output  [RADM_Q_DATABITS-1:0]       p_dataq_datain,
    output  [RADM_Q_D_CTRLBITS-1:0]     p_dataq_ena,
    output  [RADM_Q_D_CTRLBITS-1:0]     p_dataq_enb,
    output  [RADM_Q_D_CTRLBITS-1:0]     p_dataq_wea,







    output  [NF-1:0]                    cfg_reg_serren,
    output  [NF-1:0]                    cfg_cor_err_rpt_en,
    output  [NF-1:0]                    cfg_nf_err_rpt_en,
    output  [NF-1:0]                    cfg_f_err_rpt_en,


    input [NF-1:0]               exp_rom_validation_status_strobe,
    input [NF*3-1:0]               exp_rom_validation_status,
    input [NF-1:0]               exp_rom_validation_details_strobe,
    input [NF*4-1:0]               exp_rom_validation_details,
    output  [63:0]                      cxpl_debug_info,
    output  [`CX_INFO_EI_WD-1:0]        cxpl_debug_info_ei
    ,
    output                              assert_inta_grt,
    output                              assert_intb_grt,
    output                              assert_intc_grt,
    output                              assert_intd_grt,
    output                              deassert_inta_grt,
    output                              deassert_intb_grt,
    output                              deassert_intc_grt,
    output                              deassert_intd_grt,
    output  [(8*NF)-1:0]                cfg_int_pin
   ,
    output  [(8*NF)-1:0]                cfg_2ndbus_num,
    output  [(8*NF)-1:0]                cfg_subbus_num,
    output                              cfg_2nd_reset
    ,
    output [1:0]            mac_phy_pclkreq_n
    ,
    input                   app_clk_pm_en
    ,input                   aux_clk_active


    ,output  [NF-1:0]                    cfg_send_cor_err
    ,output  [NF-1:0]                    cfg_send_nf_err
    ,output  [NF-1:0]                    cfg_send_f_err


    ,output  [NF-1:0]                    cfg_int_disable
    ,output  [NF-1:0]        cfg_no_snoop_en
    ,output  [NF-1:0]        cfg_relax_order_en









    ,output   [NF-1:0]                cfg_br_ctrl_serren

,output [NF-1:0] cfg_hp_slot_ctrl_access
,output [NF-1:0] cfg_dll_state_chged_en
,output [NF-1:0] cfg_cmd_cpled_int_en
,output [NF-1:0] cfg_hp_int_en
,output [NF-1:0] cfg_pre_det_chged_en
,output [NF-1:0] cfg_mrl_sensor_chged_en
,output [NF-1:0] cfg_pwr_fault_det_en
,output [NF-1:0] cfg_atten_button_pressed_en




    ,input                                  app_hold_phy_rst
    ,output                     pm_l1_entry_started
    ,

    input      [4:0]                 app_dev_num,

    input      [7:0]                 app_bus_num
    ,

    output                           cfg_uncor_internal_err_sts,
    output                           cfg_rcvr_overflow_err_sts,
    output                           cfg_fc_protocol_err_sts,
    output                           cfg_mlf_tlp_err_sts,
    output                           cfg_surprise_down_er_sts,
    output                           cfg_dl_protocol_err_sts,
    output                           cfg_ecrc_err_sts,
    output                           cfg_corrected_internal_err_sts,
    output                           cfg_replay_number_rollover_err_sts,
    output                           cfg_replay_timer_timeout_err_sts,
    output                           cfg_bad_dllp_err_sts,
    output                           cfg_bad_tlp_err_sts,
    output                           cfg_rcvr_err_sts



);
// ------------------------------------------------------------------------------------------
// macros
// ------------------------------------------------------------------------------------------


// ------------------------------------------------------------------------------------------
// local parameters
// ------------------------------------------------------------------------------------------

localparam L2NL    = NL==1 ? 1 : `CX_LOGBASE2(NL);  // log2 number of NL
localparam TX_DATAK_WD = NL * PHY_NB;
localparam TX_NDLLP    =  1;
localparam PL_AUX_CLK_FREQ_WD = `CX_PL_AUX_CLK_FREQ_WD;

// ------------------------------------------------------------------------------------------
// genvar declarations
// ------------------------------------------------------------------------------------------
genvar lane;  // used to instantiate per-lane logic
genvar func;  // used to instantiate per-function logic
genvar rx_tlp; // used to instantiate per-TLP logic

// ------------------------------------------------------------------------------------------
// Interface Signal Descriptions
// ------------------------------------------------------------------------------------------
wire [5:0]                         ltssm_cxl_enable; // {cxl.multi-logical_device, cxl2p0_enabled, cxl.r2.0syncheader_bypass, cxl.cache, cxl.mem, cxl.io}







// wire [(NVC*3)-1:0]               trgt1_radm_pkt_halt;        // No needed because there is an input if !AMBA_POPULATED && RADM_SEG_BUF && TRGT1_POPULATE
wire [(NVC*3)-1:0]                  bridge_trgt1_radm_pkt_halt;
assign bridge_trgt1_radm_pkt_halt = {(NVC*3){1'b0}};








//Wire declaration for when RAS D.E.S. debug signals are not included in the top level port.



wire                                pm_aux_clk;
wire [NVC_XALI_EXP-1:0]             pm_xadm_client0_tlp_hv;
wire [NVC_XALI_EXP-1:0]             pm_xadm_client1_tlp_hv;

wire                                pm_aux_clk_active;



// ------------------------------------------------------------------------------------------
// Internal Signal declaration
// ------------------------------------------------------------------------------------------

wire   [DW_W_PAR -1:0]             client0_tlp_data_i                 ;
wire   [PF_WD-1:0]                 client0_tlp_func_num_i             ;
wire                               client0_addr_align_en_i            ;
wire   [7:0]                       client0_tlp_byte_en_i              ;
wire   [2:0]                       client0_cpl_status_i               ;
wire                               client0_cpl_bcm_i                  ;
wire   [15:0]                      client0_remote_req_id_i            ;
wire   [11:0]                      client0_cpl_byte_cnt_i             ;
wire   [2:0]                       client0_tlp_tc_i                   ;
wire   [ATTR_WD-1:0]               client0_tlp_attr_i                 ;
wire                               client0_tlp_dv_i                   ;
wire                               client0_tlp_eot_i                  ;
wire                               client0_tlp_bad_eot_i              ;
wire                               client0_tlp_hv_i                   ;
wire   [1:0]                       client0_tlp_fmt_i                  ;
wire   [4:0]                       client0_tlp_type_i                 ;
wire                               client0_tlp_td_i                   ;
wire                               client0_tlp_ep_i                   ;
wire   [12:0]                      client0_tlp_byte_len_i             ;
wire   [TAG_SIZE-1:0]              client0_tlp_tid_i                  ;
wire   [63:0]                      client0_tlp_addr_i                 ;
wire   [15:0]                      client0_req_id_i                   ;

wire                               client1_addr_align_en_i            ;
wire   [7:0]                       client1_tlp_byte_en_i              ;
wire   [2:0]                       client1_cpl_status_i               ;
wire                               client1_cpl_bcm_i                  ;
wire   [15:0]                      client1_remote_req_id_i            ;
wire   [11:0]                      client1_cpl_byte_cnt_i             ;
wire   [2:0]                       client1_tlp_tc_i                   ;
wire   [ATTR_WD-1:0]               client1_tlp_attr_i                 ;
wire                               client1_tlp_dv_i                   ;
wire                               client1_tlp_eot_i                  ;
wire                               client1_tlp_bad_eot_i              ;
wire                               client1_tlp_hv_i                   ;
wire   [1:0]                       client1_tlp_fmt_i                  ;
wire   [4:0]                       client1_tlp_type_i                 ;
wire                               client1_tlp_td_i                   ;
wire                               client1_tlp_ep_i                   ;
wire   [12:0]                      client1_tlp_byte_len_i             ;
wire   [TAG_SIZE-1:0]              client1_tlp_tid_i                  ;
wire   [63:0]                      client1_tlp_addr_i                 ;
wire   [15:0]                      client1_req_id_i                   ;
wire   [DW_W_PAR -1:0]             client1_tlp_data_i                 ;
wire   [PF_WD-1:0]                 client1_tlp_func_num_i             ;

// START_IO:XALI0 Descriptions


wire                               xadm_client0_halt_i                ;

// END_IO:XALI0 Descriptions

// START_IO:XALI1 Descriptions



wire                               xadm_client1_halt_i                ;

// END_IO:XALI1 Descriptions


//--------------------------------
//     TRGT1 Interface
//--------------------------------
wire [TRGT_HDR_WD-1:0]            radm_trgt1_hdr_i                      ;
wire                              trgt1_radm_halt_i                     ;
wire                              radm_trgt1_hv_i                       ;
wire                              radm_trgt1_dv_i                       ;
wire                              radm_trgt1_eot_i                      ;
wire                              radm_trgt1_tlp_abort_i                ;
wire                              radm_trgt1_dllp_abort_i               ;
wire                              radm_trgt1_ecrc_err_i                 ;
wire  [TRGT_DATA_WD-1:0]          radm_trgt1_data_i                     ;
wire  [NW-1:0]                    radm_trgt1_dwen_i                     ;
wire  [1:0]                       radm_trgt1_fmt_i                      ;
wire  [4:0]                       radm_trgt1_type_i                     ;
wire  [2:0]                       radm_trgt1_tc_i                       ;
wire  [ATTR_WD-1:0]               radm_trgt1_attr_i                     ;
wire  [15:0]                      radm_trgt1_reqid_i                    ;
wire  [TAG_SIZE-1:0]              radm_trgt1_tag_i                      ;
wire  [PF_WD-1:0]                 radm_trgt1_func_num_i                 ;
wire                              radm_trgt1_td_i                       ;
wire                              radm_trgt1_poisoned_i                 ;
wire  [9:0]                       radm_trgt1_dw_len_i                   ;
wire  [3:0]                       radm_trgt1_first_be_i                 ;
wire  [3:0]                       radm_trgt1_last_be_i                  ;
wire  [ADDR_WIDTH -1:0]           radm_trgt1_addr_i                     ;
wire [ADDR_WIDTH -1:0]           radm_trgt1_hdr_uppr_bytes_i;
wire [63:0]                      radm_trgt1_hdr_uppr_bytes_tmp;
wire  [ADDR_WIDTH -1:0]           radm_trgt1_addr_out_i                 ;
wire                              radm_trgt1_io_req_in_range_i          ;
wire                              radm_trgt1_rom_in_range_i             ;
wire  [2:0]                       radm_trgt1_in_membar_range_i          ;
wire  [2:0]                       radm_trgt1_cpl_status_i               ;
wire                              radm_trgt1_bcm_i                      ;
wire                              radm_trgt1_cpl_last_i                 ;
wire [11:0]                       radm_trgt1_byte_cnt_i                 ;
wire [15:0]                       radm_trgt1_cmpltr_id_i                ;


wire                                radm_cpl_timeout_i                  ;
wire                                radm_cpl_timeout_cdm_i              ;
wire    [PF_WD-1:0]                 radm_timeout_func_num_i             ;
wire    [2:0]                       radm_timeout_cpl_tc_i               ;
wire    [1:0]                       radm_timeout_cpl_attr_i             ;
wire    [11:0]                      radm_timeout_cpl_len_i              ;
wire    [TAG_SIZE-1:0]              radm_timeout_cpl_tag_i              ;

//--------------------------------
//     RADM Bypass interface
//--------------------------------
wire    [DW_W_PAR-1:0]              radm_bypass_data_i               ;
wire    [NW-1:0]                    radm_bypass_dwen_i               ;
wire    [NHQ-1:0]                   radm_bypass_dv_i                 ;
wire    [NHQ-1:0]                   radm_bypass_hv_i                 ;
wire    [NHQ-1:0]                   radm_bypass_eot_i                ;
wire    [NHQ-1:0]                   radm_bypass_dllp_abort_i         ;
wire    [NHQ-1:0]                   radm_bypass_tlp_abort_i          ;
wire    [NHQ-1:0]                   radm_bypass_ecrc_err_i           ;
wire    [NHQ-1:0]                   radm_bypass_bcm_i                ;
wire    [NHQ-1:0]                   radm_bypass_cpl_last_i           ;
wire    [NHQ*3-1:0]                 radm_bypass_cpl_status_i         ;

wire    [NHQ*12-1:0]                radm_bypass_byte_cnt_i           ;
wire    [NHQ*16-1:0]                radm_bypass_cmpltr_id_i          ;
wire    [NHQ*2-1:0]                 radm_bypass_fmt_i                ;
wire    [NHQ*5-1:0]                 radm_bypass_type_i               ;
wire    [NHQ*3-1:0]                 radm_bypass_tc_i                 ;
wire    [NHQ*ATTR_WD-1:0]           radm_bypass_attr_i               ;
wire    [NHQ*16-1:0]                radm_bypass_reqid_i              ;
wire    [NHQ*TAG_SIZE-1:0]          radm_bypass_tag_i                ;
wire    [NHQ*PF_WD-1:0]             radm_bypass_func_num_i           ;
wire    [NHQ-1:0]                   radm_bypass_td_i                 ;
wire    [NHQ-1:0]                   radm_bypass_poisoned_i           ;
wire    [NHQ*10-1:0]                radm_bypass_dw_len_i             ;
wire    [NHQ*4-1:0]                 radm_bypass_first_be_i           ;
wire    [NHQ*4-1:0]                 radm_bypass_last_be_i            ;
wire    [NHQ*`FLT_Q_ADDR_WIDTH-1:0] radm_bypass_addr_i               ;
wire    [NHQ-1:0]                   radm_bypass_rom_in_range_i       ;
wire    [NHQ-1:0]                   radm_bypass_io_req_in_range_i    ;
wire    [NHQ*3-1:0]                 radm_bypass_in_membar_range_i    ;
wire    [(NVC*3)-1:0]               radm_grant_tlp_type_i            ;
wire                              rstctl_slv_flush_req               ;
wire                              rstctl_mstr_flush_req              ;
wire                              rstctl_flush_done                  ;


wire [2:0]                        radm_trgt1_vc_num_i                   ;
assign radm_trgt1_vc            = radm_trgt1_vc_num_i                   ;


wire    [NVC-1:0]                   radm_pend_cpl_so                 ;
wire    [NVC-1:0]                   radm_q_cpl_not_empty             ;

wire    [2:0]                       current_data_rate;          // 0=running at gen1 speeds, 1=running at gen2 speeds

wire    [2:0]                       pm_current_data_rate_others;    // reg pm_current_data_rate using core_clk to resolve massive fan-out issues
wire    [2:0]                       int_pm_current_data_rate;
assign                              pm_current_data_rate = pm_current_data_rate_others;

wire                                pm_phy_type;
wire                                pm_block_all_tlp;
wire [5:0]                          cfg_link_capable;
// declaration for multi-func purpose
//  output signals of cdm





wire    [31:0]                      cfg_trgt_cpl_lut_delete_entry;  // trgt_cpl_lut delete one entry





wire [AUX_CLK_FREQ_WD-1:0]          cfg_pl_aux_clk_freq;
wire [NL-1:0]   phy_mac_phystatus_int;
wire [NL*3-1:0] phy_mac_rxstatus_int;
wire [NL-1:0]   phy_mac_rxdatavalid_int;
wire [NL-1:0]   phy_mac_rxvalid_int;
wire [NL-1:0]   phy_mac_rxelecidle_int;

assign phy_mac_phystatus_int   = phy_mac_phystatus;
assign phy_mac_rxstatus_int    = phy_mac_rxstatus;
assign phy_mac_rxdatavalid_int = phy_mac_rxdatavalid;
assign phy_mac_rxvalid_int     = phy_mac_rxvalid;
assign phy_mac_rxelecidle_int  = phy_mac_rxelecidle;










wire                                cfg_upd_aspm_ctrl;
wire    [(NF - 1) : 0]              cfg_upd_aslk_pmctrl;
wire    [NF-1:0]                    cfg_upd_pme_cap;
wire                                cfg_elastic_buffer_mode;
wire                                rstctl_ltssm_enable;
wire                                rstctl_core_flush_req;
wire                                int_rstctl_core_flush_req;
assign int_rstctl_core_flush_req = 1'b0;

wire                                upstream_port;
wire                                xdlh_nodllp_pending;
wire                                xdlh_no_acknak_dllp_pending;
wire                                xdlh_xmt_pme_ack;
wire                                xdlh_last_pmdllp_ack;
wire                                rdlh_rcvd_as_req_l1;
wire                                rdlh_rcvd_pm_enter_l1;
wire                                rdlh_rcvd_pm_enter_l23;
wire                                rdlh_rcvd_pm_req_ack;
wire                                smlh_link_in_training;
wire                                xdlh_not_expecting_ack;
wire [NVC-1:0]                      xadm_had_enough_credit;
wire                                smlh_in_l0;
wire                                smlh_in_l0s;
wire                                smlh_in_rl0s;
wire                                smlh_in_l1;
wire                                smlh_in_l1_p1;
wire                                smlh_in_l23;
wire                                smlh_l123_eidle_timeout;
wire                                latched_rcvd_eidle_set;
wire                                xadm_tlp_pending;
wire                                xadm_block_tlp_ack;
wire                                xtlh_tlp_pending;
wire                                xdlh_tlp_pending;
wire                                xdlh_retry_pending;
wire [NVC-1:0]                      xadm_no_fc_credit;
wire [(2*NF)-1:0]                   cfg_aslk_pmctrl;
wire [2:0]                          cfg_l0s_entr_latency_timer;
wire [2:0]                          cfg_l1_entr_latency_timer;
wire                                cfg_l1_entr_wo_rl0s;
wire [NF-1:0]                       cfg_upd_pmcsr;
wire [NF-1:0]                       cfg_upd_aux_pm_en;
wire [NF-1:0]                       cfg_pmstatus_clr;
wire [(3*NF)-1:0]                   cfg_pmstate;
wire [NF-1:0]                       cfg_pme_en;
wire [NF-1:0]                       cfg_aux_pm_en;
wire [NF-1:0]                       cfg_upd_req_id;
wire                                int_cfg_upd_req_id;
wire    [7:0]                       int_cfg_pbus_num;
wire    [4:0]                       int_cfg_pbus_dev_num;
wire                                cfg_clk_pm_en;
wire                                radm_pm_asnak;
wire                                int_radm_pm_to_ack;
wire [(5*NF)-1:0]                   cfg_pme_cap;
wire    [NL-1:0]                    int_phy_mac_phystatus;
assign                              int_phy_mac_phystatus = phy_mac_phystatus;

wire                                cfg_pl_l1_nowait_p1;
wire                                cfg_pl_l1_clk_sel;
wire [17:0]                         cfg_phy_rst_timer;
wire [5:0]                          cfg_pma_phy_rst_delay_timer;
wire                                cfg_phy_perst_on_warm_reset;
wire                                pme_to_ack_grt;
wire                                radm_trgt0_pending;
wire                                lbc_active;
wire [NF-1:0]                       pm_pme_grant;
wire                                pme_turn_off_grt;
wire [(PDWN_WIDTH - 1) :0]         pre_mac_phy_powerdown;
wire [NL*PHY_TXEI_WD-1:0]          int_mac_phy_txelecidle;
wire [(PIPE_DATA_WD - 1):0]        pre_mac_phy_txdata;
wire [(NL*PHY_NB)-1:0]             pre_mac_phy_txdatak;
wire [NL-1:0]                      pre_mac_phy_txdetectrx_loopback;
wire [NL-1:0]                      core_pre_mac_phy_txdetectrx_loopback;
assign pre_mac_phy_txdetectrx_loopback = core_pre_mac_phy_txdetectrx_loopback;
wire [NL-1:0]                      glue_mac_phy_txcompliance;
wire [NL-1:0]                      pre_mac_phy_rxpolarity;
wire [NL-1:0]                      tmp_mac_phy_rxpolarity;
wire [(WIDTH_WIDTH -1):0]          pre_mac_phy_width;
wire [P_R_WD-1:0]                  pre_mac_phy_pclk_rate;
wire [NL-1:0]                      pre_mac_phy_rxstandby;
wire [RATE_WIDTH-1:0]              pre_mac_phy_rate;
wire [NL-1:0]                      pre_mac_phy_txdatavalid;
wire [31:0]                        pre_cfg_phy_control;
wire                               msg_gen_asnak_grt;
wire [L2NL-1:0]                    smlh_lane_flip_ctrl;
wire                               cfg_link_retrain;
wire                               cfg_lpbk_en;
wire                               cfg_plreg_reset;
wire [(2*PDWN_WIDTH) - 1 : 0]      pm_powerdown_status;
wire                               cfg_force_powerdown;
wire [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control;
wire                               msg_gen_unlock_grant;
wire [3:0]                         xdlh_match_pmdllp;
wire                               pm_ltssm_enable;
wire                               pm_smlh_entry_to_l0s;
wire                               pm_smlh_entry_to_l1;
wire                               pm_smlh_entry_to_l2;
wire                               pm_smlh_prepare4_l123;
wire                               pm_smlh_l0s_exit;
wire                               pm_smlh_l1_exit;
wire                               pm_smlh_l23_exit;
wire                               pm_xdlh_enter_l1;
wire                               pm_xdlh_req_ack;
wire                               pm_xdlh_enter_l23;
wire                               pm_xdlh_actst_req_l1;
wire                               pm_freeze_fc_timer;
    // Adding in a freeze completion timer control per PM module's request
wire                               pm_freeze_cpl_timer;
wire                               pm_xmt_asnak;
wire                               pm_xmt_turnoff;
wire [NF-1:0]                      pm_xmt_to_ack;
wire [NF-1:0]                      pm_xmt_pme;
wire                               pm_turnoff_timeout;
wire [BUSNUM_WD -1:0]              pm_bus_num;
wire [DEVNUM_WD -1:0]              pm_dev_num;
wire [(PDWN_WIDTH - 1) : 0]        pm_int_phy_powerdown;
wire                               pm_current_powerdown_p1;
wire                               pm_current_powerdown_p0;
wire [NL-1:0]                      int_phy_txelecidle;
wire [NL-1:0]                      sqlchd_rxelecidle;
wire                               pm_sys_aux_pwr_det;
wire                               pm_dbi_cs;
wire [NF-1:0]                      pm_pme_en_split;
wire [NF-1:0]                      pm_aux_pm_en_split;
wire                               pm_init_rst;
wire                               pm_unlock_msg_req;
wire [L2NL - 1 : 0]                pm_rx_lane_flip_en;
wire [L2NL - 1 : 0]                pm_tx_lane_flip_en;
wire [L2NL - 1 : 0]                pm_rx_pol_lane_flip_ctrl;
wire                               pm_smlh_link_retrain;
wire                               msg_gen_hv;
wire                               lbc_cpl_hv;

wire                               pm_l1_aspm_entr;
wire    [NF-1:0]                   pm_radm_block_tlp;


 assign int_cfg_upd_req_id      = cfg_upd_req_id[0];


wire   pm_smlh_req_l1;
wire   pm_smlh_req_l2;
assign pm_smlh_req_l1 = pm_smlh_entry_to_l1;
assign pm_smlh_req_l2 = pm_smlh_entry_to_l2;



DWC_pcie_core

#(
    .INST         (INST         ),
    .NL           (NL           ),
    .TXNL         (TXNL         ),
    .RXNL         (RXNL         ),
    .NB           (NB           ),
    .PHY_NB       (PHY_NB       ),
    .CM_PHY_NB    (CM_PHY_NB    ),
    .NW           (NW           ),
    .NF           (NF           ),
    .PF_WD        (PF_WD        ),
    .NVC          (NVC          ),
    .NHQ          (NHQ          ),
    .NDQ          (NDQ          ),
    .DATA_PAR_WD  (DATA_PAR_WD  ),
    .TRGT_DATA_WD (TRGT_DATA_WD ),

    .ADDR_PAR_WD           (ADDR_PAR_WD          ),
    .DW_W_PAR              (DW_W_PAR             ),
    .DW_WO_PAR             (DW_WO_PAR            ),
    .RAS_PCIE_HDR_PROT_WD  (RAS_PCIE_HDR_PROT_WD ),
    .TX_HW_W_PAR           (TX_HW_W_PAR          ),
    .RADM_P_HWD            (RADM_P_HWD           ),
    .DW                    (DW                   ),
    .DATA_WIDTH            (DATA_WIDTH           ),
    .ADDR_WIDTH            (ADDR_WIDTH           ),
    .RX_NDLLP              (RX_NDLLP             ),
    .L2N_INTFC             (L2N_INTFC            ),
    .ALL_FUNC_NUM          (ALL_FUNC_NUM         ),
    .TRGT_HDR_WD           (TRGT_HDR_WD          ),
    .TRGT_HDR_PROT_WD      (TRGT_HDR_PROT_WD     ),
    .CLIENT_HDR_PROT_WD    (CLIENT_HDR_PROT_WD   ),
    .ST_HDR                (ST_HDR               ),
    .HDR_PROT_WD           (HDR_PROT_WD          ),
    .RBUF_DEPTH            (RBUF_DEPTH           ),
    .RBUF_PW               (RBUF_PW              ),
    .SOTBUF_DP             (SOTBUF_DP            ),
    .SOTBUF_PW             (SOTBUF_PW            ),
    .SOTBUF_WD             (SOTBUF_WD            ),
    .DATAQ_WD              (DATAQ_WD             ),
    .RADM_Q_DATABITS       (RADM_Q_DATABITS      ),
    .RADM_Q_DATABITS_O     (RADM_Q_DATABITS_O    ),
    .LBC_EXT_AW            (LBC_EXT_AW           ),

    .RADM_PQ_HWD             (RADM_PQ_HWD           ),
    .RADM_NPQ_HWD            (RADM_NPQ_HWD          ),
    .RADM_CPLQ_HWD           (RADM_CPLQ_HWD         ),
    .RADM_PQ_HPW             (RADM_PQ_HPW           ),
    .RADM_NPQ_HPW            (RADM_NPQ_HPW          ),
    .RADM_CPLQ_HPW           (RADM_CPLQ_HPW         ),
    .RADM_PQ_DPW             (RADM_PQ_DPW           ),
    .RADM_NPQ_DPW            (RADM_NPQ_DPW          ),
    .RADM_CPLQ_DPW           (RADM_CPLQ_DPW         ),
    .RADM_Q_H_CTRLBITS       (RADM_Q_H_CTRLBITS     ),
    .RADM_Q_D_CTRLBITS       (RADM_Q_D_CTRLBITS     ),
    .RADM_PQ_H_DATABITS      (RADM_PQ_H_DATABITS    ),
    .RADM_PQ_H_DATABITS_O    (RADM_PQ_H_DATABITS_O  ),
    .RADM_NPQ_H_DATABITS     (RADM_NPQ_H_DATABITS   ),
    .RADM_NPQ_H_DATABITS_O   (RADM_NPQ_H_DATABITS_O ),
    .RADM_CPLQ_H_DATABITS    (RADM_CPLQ_H_DATABITS  ),
    .RADM_CPLQ_H_DATABITS_O  (RADM_CPLQ_H_DATABITS_O),
    .RADM_PQ_H_ADDRBITS      (RADM_PQ_H_ADDRBITS    ),
    .RADM_NPQ_H_ADDRBITS     (RADM_NPQ_H_ADDRBITS   ),
    .RADM_CPLQ_H_ADDRBITS    (RADM_CPLQ_H_ADDRBITS  ),
    .RADM_PQ_D_ADDRBITS      (RADM_PQ_D_ADDRBITS    ),
    .RADM_NPQ_D_ADDRBITS     (RADM_NPQ_D_ADDRBITS   ),
    .RADM_CPLQ_D_ADDRBITS    (RADM_CPLQ_D_ADDRBITS  ),
    .RADM_PQ_HDP             (RADM_PQ_HDP           ),
    .RADM_NPQ_HDP            (RADM_NPQ_HDP          ),
    .RADM_CPLQ_HDP           (RADM_CPLQ_HDP         ),
    .RADM_PQ_DDP             (RADM_PQ_DDP           ),
    .RADM_NPQ_DDP            (RADM_NPQ_DDP          ),
    .RADM_CPLQ_DDP           (RADM_CPLQ_DDP         ),
    .DCA_WD                  (DCA_WD                ),
    .APP_CRD_WD              (APP_CRD_WD            ),
    .BUSNUM_WD               (BUSNUM_WD             ),
    .DEVNUM_WD               (DEVNUM_WD             ),
    .N_FLT_MASK              (N_FLT_MASK            ),
    .CPL_LUT_DEPTH           (CPL_LUT_DEPTH         ),




     .TX_COEF_WD (TX_COEF_WD),

     .ORIG_DATA_WD   (ORIG_DATA_WD    ),
     .SERDES_DATA_WD (SERDES_DATA_WD),
     .PIPE_DATA_WD   (PIPE_DATA_WD  ),
     .PDWN_WIDTH     (PDWN_WIDTH    ),
     .RATE_WIDTH     (RATE_WIDTH    ),
     .TX_DEEMPH_WD   (TX_DEEMPH_WD  ),
     .PHY_TXEI_WD    (PHY_TXEI_WD   ),

     .ERR_BUS_WD  (ERR_BUS_WD ),
     .RX_TLP      (RX_TLP     ),
     .FX_TLP      (FX_TLP     ),
     .TAG_SIZE    (TAG_SIZE   ),
     .LOOKUPID_WD (LOOKUPID_WD),


     .ATTR_WD (ATTR_WD),


     .LBC_INT_WD   (LBC_INT_WD),


     .GEN2_DYNAMIC_FREQ_VALUE  (GEN2_DYNAMIC_FREQ_VALUE),

     .RADM_RAM_RD_LATENCY       (RADM_RAM_RD_LATENCY      ),
     .RADM_FORMQ_RAM_RD_LATENCY (RADM_FORMQ_RAM_RD_LATENCY),
     .RETRY_RAM_RD_LATENCY      (RETRY_RAM_RD_LATENCY     ),
     .RETRY_SOT_RAM_RD_LATENCY  (RETRY_SOT_RAM_RD_LATENCY ),

     .HCRD_WD (HCRD_WD),
     .DCRD_WD (DCRD_WD)
    ,
    .AUX_CLK_FREQ_WD (AUX_CLK_FREQ_WD),
    .PM_MST_WD       (PM_MST_WD),
    .PM_SLV_WD       (PM_SLV_WD),
    .L2NL (L2NL)
 )
 u_DWC_pcie_core (



// start xadm ports will present no matter AMBA_POPULATED is defined or not
    .client0_tlp_hv         (pm_xadm_client0_tlp_hv),
    .client1_tlp_hv         (pm_xadm_client1_tlp_hv),
    .radm_grant_tlp_type   (radm_grant_tlp_type     ),
    .client0_tlp_dv         (client0_tlp_dv       ),
    .client0_tlp_eot        (client0_tlp_eot      ),
    .client0_addr_align_en  (client0_addr_align_en),
    .client0_tlp_byte_en    (client0_tlp_byte_en  ),
    .client0_remote_req_id  (client0_remote_req_id),
    .client0_cpl_byte_cnt   (client0_cpl_byte_cnt ),
    .client0_tlp_tc         (client0_tlp_tc       ),
    .client0_tlp_attr       (client0_tlp_attr     ),
    .client0_cpl_status    (client0_cpl_status  ),
    .client0_cpl_bcm       (client0_cpl_bcm     ),
    .client0_tlp_bad_eot   (client0_tlp_bad_eot ),
    .client0_tlp_fmt       (client0_tlp_fmt     ),
    .client0_tlp_type      (client0_tlp_type    ),
    .client0_tlp_td        (client0_tlp_td      ),
    .client0_tlp_ep        (client0_tlp_ep      ),
    .client0_tlp_byte_len  (client0_tlp_byte_len),
    .client0_tlp_addr      (client0_tlp_addr    ),
    .client0_tlp_tid       (client0_tlp_tid     ),
    .client0_tlp_data      (client0_tlp_data    ),
    .client0_tlp_func_num  (client0_tlp_func_num),
    .xadm_client0_halt (xadm_client0_halt),




    .client1_addr_align_en  (client1_addr_align_en),
    .client1_tlp_byte_en    (client1_tlp_byte_en  ),
    .client1_remote_req_id  (client1_remote_req_id),
    .client1_cpl_status     (client1_cpl_status   ),
    .client1_cpl_bcm        (client1_cpl_bcm      ),
    .client1_cpl_byte_cnt   (client1_cpl_byte_cnt ),
    .client1_tlp_dv         (client1_tlp_dv       ),
    .client1_tlp_eot        (client1_tlp_eot      ),
    .client1_tlp_bad_eot    (client1_tlp_bad_eot  ),
    .client1_tlp_fmt        (client1_tlp_fmt      ),
    .client1_tlp_type       (client1_tlp_type     ),
    .client1_tlp_tc         (client1_tlp_tc       ),
    .client1_tlp_td         (client1_tlp_td       ),
    .client1_tlp_ep         (client1_tlp_ep       ),
    .client1_tlp_attr       (client1_tlp_attr     ),
    .client1_tlp_byte_len  (client1_tlp_byte_len),
    .client1_tlp_tid       (client1_tlp_tid     ),
    .client1_tlp_addr      (client1_tlp_addr    ),
    .client1_tlp_data      (client1_tlp_data    ),
    .client1_tlp_func_num  (client1_tlp_func_num),
    .xadm_client1_halt (xadm_client1_halt),



    .radm_bypass_data        (radm_bypass_data      ),
    .radm_bypass_dwen        (radm_bypass_dwen      ),
    .radm_bypass_dv          (radm_bypass_dv        ),
    .radm_bypass_hv          (radm_bypass_hv        ),
    .radm_bypass_eot         (radm_bypass_eot       ),
    .radm_bypass_dllp_abort  (radm_bypass_dllp_abort),
    .radm_bypass_tlp_abort   (radm_bypass_tlp_abort ),
    .radm_bypass_ecrc_err    (radm_bypass_ecrc_err  ),
    .radm_bypass_fmt   (radm_bypass_fmt ),
    .radm_bypass_type  (radm_bypass_type),
    .radm_bypass_tc    (radm_bypass_tc  ),
    .radm_bypass_attr  (radm_bypass_attr),
    .radm_bypass_reqid     (radm_bypass_reqid   ),
    .radm_bypass_tag       (radm_bypass_tag     ),
    .radm_bypass_func_num  (radm_bypass_func_num),
    .radm_bypass_td        (radm_bypass_td      ),
    .radm_bypass_poisoned  (radm_bypass_poisoned),
    .radm_bypass_dw_len    (radm_bypass_dw_len  ),
    .radm_bypass_first_be  (radm_bypass_first_be),
    .radm_bypass_last_be   (radm_bypass_last_be ),
    .radm_bypass_addr      (radm_bypass_addr    ),
    .radm_bypass_rom_in_range     (radm_bypass_rom_in_range   ),
    .radm_bypass_io_req_in_range  (radm_bypass_io_req_in_range),
    .radm_bypass_in_membar_range  (radm_bypass_in_membar_range),
    .radm_bypass_bcm         (radm_bypass_bcm       ),
    .radm_bypass_cpl_last    (radm_bypass_cpl_last  ),
    .radm_bypass_cmpltr_id   (radm_bypass_cmpltr_id ),
    .radm_bypass_byte_cnt    (radm_bypass_byte_cnt  ),
    .radm_bypass_cpl_status  (radm_bypass_cpl_status),



    .radm_cpl_timeout       (radm_cpl_timeout     ),
    .radm_timeout_func_num  (radm_timeout_func_num),
    .radm_timeout_cpl_tc    (radm_timeout_cpl_tc  ),
    .radm_timeout_cpl_attr  (radm_timeout_cpl_attr),
    .radm_timeout_cpl_len   (radm_timeout_cpl_len),
    .radm_timeout_cpl_tag   (radm_timeout_cpl_tag),

    .trgt1_radm_halt        (trgt1_radm_halt      ),
    .radm_trgt1_dv          (radm_trgt1_dv        ),
    .radm_trgt1_hv          (radm_trgt1_hv        ),
    .radm_trgt1_eot         (radm_trgt1_eot       ),
    .radm_trgt1_tlp_abort   (radm_trgt1_tlp_abort ),
    .radm_trgt1_dllp_abort  (radm_trgt1_dllp_abort),
    .radm_trgt1_ecrc_err    (radm_trgt1_ecrc_err  ),
    .radm_trgt1_data        (radm_trgt1_data      ),
    .radm_trgt1_dwen        (radm_trgt1_dwen      ),
    .radm_trgt1_fmt   (radm_trgt1_fmt ),
    .radm_trgt1_type  (radm_trgt1_type),
    .radm_trgt1_tc    (radm_trgt1_tc  ),
    .radm_trgt1_attr  (radm_trgt1_attr),
    .radm_trgt1_reqid     (radm_trgt1_reqid   ),
    .radm_trgt1_tag       (radm_trgt1_tag     ),
    .radm_trgt1_func_num  (radm_trgt1_func_num),
    .radm_trgt1_td              (radm_trgt1_td            ),
    .radm_trgt1_poisoned        (radm_trgt1_poisoned      ),
    .radm_trgt1_dw_len          (radm_trgt1_dw_len        ),
    .radm_trgt1_first_be        (radm_trgt1_first_be      ),
    .radm_trgt1_last_be         (radm_trgt1_last_be       ),
    .radm_trgt1_addr            (radm_trgt1_addr          ),
    .radm_trgt1_hdr_uppr_bytes  (radm_trgt1_hdr_uppr_bytes),
    .radm_trgt1_rom_in_range     (radm_trgt1_rom_in_range   ),
    .radm_trgt1_in_membar_range  (radm_trgt1_in_membar_range),
    .radm_trgt1_io_req_in_range  (radm_trgt1_io_req_in_range),
    .radm_trgt1_cpl_status       (radm_trgt1_cpl_status     ),

    .radm_trgt1_bcm        (radm_trgt1_bcm      ),
    .radm_trgt1_byte_cnt   (radm_trgt1_byte_cnt ),
    .radm_trgt1_cpl_last   (radm_trgt1_cpl_last ),
    .radm_trgt1_cmpltr_id  (radm_trgt1_cmpltr_id),





    .trgt1_radm_pkt_halt         (trgt1_radm_pkt_halt),          // Input from external input if NO AMBA_POPULATED
    .bridge_trgt1_radm_pkt_halt  (bridge_trgt1_radm_pkt_halt),   // Input from DWC_pcie_edma_amba_bridge/axi_bridge/ahb_bridge


    .app_dbi_ro_wr_disable          (app_dbi_ro_wr_disable),

    .dbi_addr      (dbi_addr    ),
    .dbi_din       (dbi_din     ),
    .dbi_cs2       (dbi_cs2     ),
    .dbi_wr        (dbi_wr      ),
    .lbc_dbi_ack   (lbc_dbi_ack ),
    .lbc_dbi_dout  (lbc_dbi_dout),

    .ext_lbc_ack              (ext_lbc_ack             ),
    .ext_lbc_din              (ext_lbc_din             ),
    .lbc_ext_addr             (lbc_ext_addr            ),
    .lbc_ext_dout             (lbc_ext_dout            ),
    .lbc_ext_cs               (lbc_ext_cs              ),
    .lbc_ext_wr               (lbc_ext_wr              ),
    .lbc_ext_dbi_access       (lbc_ext_dbi_access      ),    
    .lbc_ext_rom_access       (lbc_ext_rom_access      ),
    .lbc_ext_io_access        (lbc_ext_io_access       ),
    .lbc_ext_bar_num          (lbc_ext_bar_num         ),
    .ven_msi_req       (ven_msi_req     ),
    .ven_msi_func_num  (ven_msi_func_num),
    .ven_msi_tc      (ven_msi_tc    ),
    .ven_msi_vector  (ven_msi_vector),
    .ven_msi_grant   (ven_msi_grant ),
    .cfg_msi_en      (cfg_msi_en    ),








    .ven_msg_fmt       (ven_msg_fmt     ),
    .ven_msg_type      (ven_msg_type    ),
    .ven_msg_tc        (ven_msg_tc      ),
    .ven_msg_td        (ven_msg_td      ),
    .ven_msg_ep        (ven_msg_ep      ),
    .ven_msg_attr      (ven_msg_attr    ),
    .ven_msg_len       (ven_msg_len     ),
    .ven_msg_func_num  (ven_msg_func_num),
    .ven_msg_tag    (ven_msg_tag  ),
    .ven_msg_code   (ven_msg_code ),
    .ven_msg_data   (ven_msg_data ),
    .ven_msg_req    (ven_msg_req  ),
    .ven_msg_grant  (ven_msg_grant),


    .tx_lane_flip_en (tx_lane_flip_en),

    .sys_int            (sys_int          ),
    .sys_aux_pwr_det  (sys_aux_pwr_det ),
    .sys_atten_button_pressed   (sys_atten_button_pressed ),
    .sys_pre_det_state          (sys_pre_det_state        ),
    .sys_mrl_sensor_state       (sys_mrl_sensor_state     ),
    .sys_pwr_fault_det          (sys_pwr_fault_det        ),
    .sys_mrl_sensor_chged       (sys_mrl_sensor_chged     ),
    .sys_pre_det_chged          (sys_pre_det_chged        ),
    .sys_cmd_cpled_int          (sys_cmd_cpled_int        ),
    .sys_eml_interlock_engaged  (sys_eml_interlock_engaged),
    .cfg_pwr_ind                (cfg_pwr_ind              ),
    .cfg_atten_ind              (cfg_atten_ind            ),
    .cfg_pwr_ctrler_ctrl        (cfg_pwr_ctrler_ctrl      ),
    .app_unlock_msg             (app_unlock_msg           ),
    .pm_xtlh_block_tlp  (pm_xtlh_block_tlp),
    .pm_block_all_tlp   (pm_block_all_tlp),
    .cfg_bar0_start  (cfg_bar0_start),
    .cfg_bar1_start  (cfg_bar1_start),
    .cfg_bar0_limit  (cfg_bar0_limit),
    .cfg_bar1_limit  (cfg_bar1_limit),
    .cfg_bar2_start  (cfg_bar2_start),
    .cfg_bar2_limit  (cfg_bar2_limit),
    .cfg_bar3_start  (cfg_bar3_start),
    .cfg_bar3_limit  (cfg_bar3_limit),
    .cfg_bar4_start  (cfg_bar4_start),
    .cfg_bar4_limit  (cfg_bar4_limit),
    .cfg_bar5_start  (cfg_bar5_start),
    .cfg_bar5_limit  (cfg_bar5_limit),
    .cfg_exp_rom_start    (cfg_exp_rom_start  ),
    .cfg_exp_rom_limit    (cfg_exp_rom_limit  ),
    .cfg_bus_master_en    (cfg_bus_master_en  ),
    .cfg_mem_space_en     (cfg_mem_space_en   ),
    .cfg_max_rd_req_size  (cfg_max_rd_req_size),
    .cfg_max_payload_size (cfg_max_payload_size),
    .cfg_rcb              (cfg_rcb             ),
    .cfg_pm_no_soft_rst   (cfg_pm_no_soft_rst  ),
    .cfg_aer_rc_err_int   (cfg_aer_rc_err_int ),
    .cfg_aer_rc_err_msi   (cfg_aer_rc_err_msi ),
    .cfg_aer_int_msg_num  (cfg_aer_int_msg_num),
    .cfg_sys_err_rc       (cfg_sys_err_rc     ),
    .cfg_pme_int          (cfg_pme_int        ),
    .cfg_pme_msi          (cfg_pme_msi        ),
    .cfg_crs_sw_vis_en    (cfg_crs_sw_vis_en        ),
    .cfg_pcie_cap_int_msg_num  (cfg_pcie_cap_int_msg_num),
    .rdlh_link_up      (rdlh_link_up    ),
    .smlh_ltssm_state  (smlh_ltssm_state),
    .ltssm_cxl_enable  (ltssm_cxl_enable),
    .smlh_link_up      (smlh_link_up    ),
    .smlh_req_rst_not  (smlh_req_rst_not),
    .link_req_rst_not  (link_req_rst_not),
    .radm_vendor_msg (radm_vendor_msg),
    .radm_msg_payload  (radm_msg_payload),
    .radm_msg_unlock   (radm_msg_unlock),
    .radm_msg_req_id      (radm_msg_req_id    ),
    .radm_inta_asserted    (radm_inta_asserted  ),
    .radm_intb_asserted    (radm_intb_asserted  ),
    .radm_intc_asserted    (radm_intc_asserted  ),
    .radm_intd_asserted    (radm_intd_asserted  ),
    .radm_inta_deasserted  (radm_inta_deasserted),
    .radm_intb_deasserted  (radm_intb_deasserted),
    .radm_intc_deasserted  (radm_intc_deasserted),
    .radm_intd_deasserted  (radm_intd_deasserted),
    .radm_correctable_err  (radm_correctable_err),
    .radm_nonfatal_err     (radm_nonfatal_err   ),
    .radm_fatal_err        (radm_fatal_err      ),
    .radm_pm_pme           (radm_pm_pme         ),
    .radm_pm_to_ack        (radm_pm_to_ack      ),
    .radm_pm_turnoff  (radm_pm_turnoff  ),
    .rtlh_rfc_upd   (rtlh_rfc_upd ),
    .rtlh_rfc_data  (rtlh_rfc_data),
    .cfg_eml_control  (cfg_eml_control),
    .hp_pme           (hp_pme         ),
    .hp_int           (hp_int         ),
    .hp_msi           (hp_msi         ),
    .app_ltssm_enable  (app_ltssm_enable),
    .cfg_pbus_num      (cfg_pbus_num    ),
    .cfg_pbus_dev_num  (cfg_pbus_dev_num),
    
    .pm_dstate         (pm_dstate       ),
    .pm_status     (pm_status     ),
    .cfg_link_dis          (cfg_link_dis),
    .cfg_link_auto_bw_int  (cfg_link_auto_bw_int),
    .cfg_link_auto_bw_msi  (cfg_link_auto_bw_msi),
    .cfg_bw_mgt_int        (cfg_bw_mgt_int      ),
    .cfg_bw_mgt_msi        (cfg_bw_mgt_msi      ),
    .radm_q_not_empty  (radm_q_not_empty),
    .radm_qoverflow    (radm_qoverflow  ),



    .mac_phy_powerdown   (mac_phy_powerdown ),
    .mac_phy_txelecidle  (mac_phy_txelecidle),
    .phy_mac_phystatus   (phy_mac_phystatus_int ),
    .phy_mac_rxdata            (phy_mac_rxdata           ),
    .phy_mac_rxdatak           (phy_mac_rxdatak          ),
    .phy_mac_rxvalid           (phy_mac_rxvalid_int      ),
    .phy_mac_rxstatus          (phy_mac_rxstatus_int       ),
    .phy_mac_rxstandbystatus   (phy_mac_rxstandbystatus  ),
    .phy_cfg_status            (phy_cfg_status           ),

    .mac_phy_txdetectrx_loopback  (mac_phy_txdetectrx_loopback),
    .mac_phy_txcompliance         (mac_phy_txcompliance       ),
    .mac_phy_rxpolarity           (mac_phy_rxpolarity         ),

    .phy_mac_rxdatavalid (phy_mac_rxdatavalid_int),

    .cfg_phy_control  (pre_cfg_phy_control),
    .core_clk (core_clk),
    .core_clk_ug (core_clk_ug),
    .aux_clk_g             (aux_clk_g            ),
    .radm_clk_g            (radm_clk_g           ),
    .en_radm_clk_g         (en_radm_clk_g        ),
    .radm_idle             (radm_idle            ),
    .pwr_rst_n             (pwr_rst_n            ),
    .sticky_rst_n          (sticky_rst_n         ),
    .non_sticky_rst_n      (non_sticky_rst_n     ),
    .core_rst_n            (core_rst_n           ),
    .pm_sel_aux_clk        (pm_sel_aux_clk       ),
    .device_type           (device_type         ),
    .app_req_retry_en      (app_req_retry_en    ),
    .app_pf_req_retry_en   (app_pf_req_retry_en ),


    .training_rst_n  (training_rst_n ),

    .xdlh_retryram_addr            (xdlh_retryram_addr          ),
    .xdlh_retryram_data            (xdlh_retryram_data          ),
    .xdlh_retryram_we              (xdlh_retryram_we            ),
    .xdlh_retryram_en              (xdlh_retryram_en            ),
    .xdlh_retryram_par_chk_val     (                            ),
    .retryram_xdlh_data            (retryram_xdlh_data          ),
    .xdlh_retrysotram_waddr        (xdlh_retrysotram_waddr      ),
    .xdlh_retrysotram_raddr        (xdlh_retrysotram_raddr      ),
    .xdlh_retrysotram_data         (xdlh_retrysotram_data       ),
    .xdlh_retrysotram_we           (xdlh_retrysotram_we         ),
    .xdlh_retrysotram_en           (xdlh_retrysotram_en         ),
    .xdlh_retrysotram_par_chk_val  (                            ),
    .retrysotram_xdlh_data         (retrysotram_xdlh_data       ),
    .p_hdrq_dataout      (p_hdrq_dataout     ),
    .p_hdrq_par_chk_val  (                   ),
    .p_hdrq_addra        (p_hdrq_addra       ),
    .p_hdrq_addrb        (p_hdrq_addrb       ),
    .p_hdrq_datain       (p_hdrq_datain      ),
    .p_hdrq_ena          (p_hdrq_ena         ),
    .p_hdrq_enb          (p_hdrq_enb         ),
    .p_hdrq_wea          (p_hdrq_wea         ),
    .p_dataq_dataout     (p_dataq_dataout    ),
    .p_dataq_par_chk_val (                   ),
    .p_dataq_addra       (p_dataq_addra      ),
    .p_dataq_addrb       (p_dataq_addrb      ),
    .p_dataq_datain      (p_dataq_datain     ),
    .p_dataq_ena         (p_dataq_ena        ),
    .p_dataq_enb         (p_dataq_enb        ),
    .p_dataq_wea         (p_dataq_wea        ),















    .cfg_reg_serren              (cfg_reg_serren       ),
    .cfg_cor_err_rpt_en          (cfg_cor_err_rpt_en   ),
    .cfg_nf_err_rpt_en           (cfg_nf_err_rpt_en    ),
    .cfg_f_err_rpt_en            (cfg_f_err_rpt_en     ),


    .exp_rom_validation_status_strobe  (exp_rom_validation_status_strobe ),
    .exp_rom_validation_status         (exp_rom_validation_status        ),
    .exp_rom_validation_details_strobe (exp_rom_validation_details_strobe),
    .exp_rom_validation_details        (exp_rom_validation_details       ),
    .cxpl_debug_info        (cxpl_debug_info      ),
    .cxpl_debug_info_ei     (cxpl_debug_info_ei   )
    ,
    .assert_inta_grt    (assert_inta_grt  ),
    .assert_intb_grt    (assert_intb_grt  ),
    .assert_intc_grt    (assert_intc_grt  ),
    .assert_intd_grt    (assert_intd_grt  ),
    .deassert_inta_grt  (deassert_inta_grt),
    .deassert_intb_grt  (deassert_intb_grt),
    .deassert_intc_grt  (deassert_intc_grt),
    .deassert_intd_grt  (deassert_intd_grt),
    .cfg_int_pin        (cfg_int_pin      )
   ,
    .cfg_2ndbus_num  (cfg_2ndbus_num),
    .cfg_subbus_num  (cfg_subbus_num)
   ,.cfg_2nd_reset   (cfg_2nd_reset )
    ,
    .app_clk_pm_en (app_clk_pm_en)
    ,.aux_clk_active  (aux_clk_active)


    ,.cfg_send_cor_err   (cfg_send_cor_err  )
    ,.cfg_send_nf_err    (cfg_send_nf_err   )
    ,.cfg_send_f_err     (cfg_send_f_err    )
    ,.cfg_int_disable    (cfg_int_disable   )
    ,.cfg_no_snoop_en    (cfg_no_snoop_en   )
    ,.cfg_relax_order_en (cfg_relax_order_en)





    ,.cfg_br_ctrl_serren    (cfg_br_ctrl_serren)
    ,.p_hdrq_parerr            ({RADM_Q_H_CTRLBITS{1'b0}})
    ,.p_dataq_parerr           ({RADM_Q_D_CTRLBITS{1'b0}})
    ,.retryram_xdlh_parerr     ({1{1'b0}}               )
    ,.retrysotram_xdlh_parerr  ({1{1'b0}}               )
    ,.p_hdrq_parerr_out_int    (                        )
    ,.p_dataq_parerr_out_int   (                        )
    ,.pm_aux_clk          (pm_aux_clk         )
    ,.pm_aux_clk_active (pm_aux_clk_active)
    ,.radm_trgt1_addr_i     (radm_trgt1_addr_i    )
    ,.radm_trgt1_data_i     (radm_trgt1_data_i    )
    ,.radm_trgt1_vc_num_i   (radm_trgt1_vc_num_i   )
    ,.radm_bypass_data_i        (radm_bypass_data_i      )
    ,.radm_bypass_byte_cnt_i    (radm_bypass_byte_cnt_i  )
    ,.radm_bypass_addr_i        (radm_bypass_addr_i      )
    ,.radm_pend_cpl_so          (radm_pend_cpl_so        )
    ,.radm_q_cpl_not_empty      (radm_q_cpl_not_empty    )
    ,.radm_grant_tlp_type_i (radm_grant_tlp_type_i)
    ,.rstctl_slv_flush_req         (rstctl_slv_flush_req )
    ,.rstctl_mstr_flush_req        (rstctl_mstr_flush_req)
    ,.rstctl_flush_done            (rstctl_flush_done)
    ,.pm_phy_type                  (pm_phy_type                )
    ,.current_data_rate            (current_data_rate          )
    ,.pm_current_data_rate_others  (pm_current_data_rate_others)

    ,.cfg_hp_slot_ctrl_access        (cfg_hp_slot_ctrl_access)
    ,.cfg_dll_state_chged_en         (cfg_dll_state_chged_en)
    ,.cfg_cmd_cpled_int_en           (cfg_cmd_cpled_int_en)
    ,.cfg_pre_det_chged_en           (cfg_pre_det_chged_en)
    ,.cfg_mrl_sensor_chged_en        (cfg_mrl_sensor_chged_en)
    ,.cfg_pwr_fault_det_en           (cfg_pwr_fault_det_en)
    ,.cfg_atten_button_pressed_en    (cfg_atten_button_pressed_en)
    ,.cfg_hp_int_en                  (cfg_hp_int_en)

    ,.cfg_upd_aspm_ctrl              (cfg_upd_aspm_ctrl)
    ,.cfg_upd_aslk_pmctrl            (cfg_upd_aslk_pmctrl)
    ,.cfg_upd_pme_cap                (cfg_upd_pme_cap)
    ,.cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode)
    ,.rstctl_ltssm_enable            (rstctl_ltssm_enable)
    ,.rstctl_core_flush_req          (rstctl_core_flush_req)
    ,.upstream_port                  (upstream_port)
    ,.xdlh_nodllp_pending            (xdlh_nodllp_pending)
    ,.xdlh_no_acknak_dllp_pending    (xdlh_no_acknak_dllp_pending)
    ,.xdlh_xmt_pme_ack               (xdlh_xmt_pme_ack)
    ,.xdlh_last_pmdllp_ack           (xdlh_last_pmdllp_ack)
    ,.rdlh_rcvd_as_req_l1            (rdlh_rcvd_as_req_l1)
    ,.rdlh_rcvd_pm_enter_l1          (rdlh_rcvd_pm_enter_l1)
    ,.rdlh_rcvd_pm_enter_l23         (rdlh_rcvd_pm_enter_l23)
    ,.rdlh_rcvd_pm_req_ack           (rdlh_rcvd_pm_req_ack)
    ,.smlh_link_in_training          (smlh_link_in_training)
    ,.xdlh_not_expecting_ack         (xdlh_not_expecting_ack)
    ,.xadm_had_enough_credit         (xadm_had_enough_credit)
    ,.smlh_in_l0                     (smlh_in_l0)
    ,.smlh_in_l0s                    (smlh_in_l0s)
    ,.smlh_in_rl0s                   (smlh_in_rl0s)
    ,.smlh_in_l1                     (smlh_in_l1)
    ,.smlh_in_l1_p1                  (smlh_in_l1_p1)
    ,.smlh_in_l23                    (smlh_in_l23)
    ,.smlh_l123_eidle_timeout        (smlh_l123_eidle_timeout)
    ,.latched_rcvd_eidle_set         (latched_rcvd_eidle_set)
    ,.xadm_tlp_pending               (xadm_tlp_pending)
    ,.xadm_block_tlp_ack             (xadm_block_tlp_ack)
    ,.xtlh_tlp_pending               (xtlh_tlp_pending)
    ,.xdlh_tlp_pending               (xdlh_tlp_pending)
    ,.xdlh_retry_pending             (xdlh_retry_pending)
    ,.xadm_no_fc_credit              (xadm_no_fc_credit)
    ,.cfg_aslk_pmctrl                (cfg_aslk_pmctrl)
    ,.cfg_l0s_entr_latency_timer     (cfg_l0s_entr_latency_timer)
    ,.cfg_l1_entr_latency_timer      (cfg_l1_entr_latency_timer)
    ,.cfg_l1_entr_wo_rl0s            (cfg_l1_entr_wo_rl0s)
    ,.cfg_upd_pmcsr                  (cfg_upd_pmcsr)
    ,.cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en)
    ,.cfg_pmstatus_clr               (cfg_pmstatus_clr)
    ,.cfg_pmstate                    (cfg_pmstate)
    ,.cfg_pme_en                     (cfg_pme_en)
    ,.cfg_aux_pm_en                  (cfg_aux_pm_en)
    ,.cfg_upd_req_id                 (cfg_upd_req_id)
    ,.cfg_clk_pm_en                  (cfg_clk_pm_en)
    ,.radm_pm_asnak                  (radm_pm_asnak)
    ,.int_radm_pm_to_ack             (int_radm_pm_to_ack)
    ,.cfg_pme_cap                    (cfg_pme_cap)
    ,.cfg_pl_l1_nowait_p1            (cfg_pl_l1_nowait_p1)
    ,.cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel)
    ,.cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset)
    ,.cfg_phy_rst_timer              (cfg_phy_rst_timer)
    ,.cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer)
    ,.cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq)
    ,.pme_to_ack_grt                 (pme_to_ack_grt)
    ,.radm_trgt0_pending             (radm_trgt0_pending)
    ,.lbc_active                     (lbc_active)
    ,.pm_pme_grant                   (pm_pme_grant)
    ,.pme_turn_off_grt               (pme_turn_off_grt)
    ,.pre_mac_phy_powerdown          (pre_mac_phy_powerdown)
    ,.int_mac_phy_txelecidle         (int_mac_phy_txelecidle)
    ,.pre_mac_phy_txdata             (pre_mac_phy_txdata)
    ,.pre_mac_phy_txdatak            (pre_mac_phy_txdatak)
    ,.pre_mac_phy_txdetectrx_loopback (core_pre_mac_phy_txdetectrx_loopback)
    ,.glue_mac_phy_txcompliance      (glue_mac_phy_txcompliance)
    ,.pre_mac_phy_rxpolarity         (pre_mac_phy_rxpolarity)
    ,.tmp_mac_phy_rxpolarity         (tmp_mac_phy_rxpolarity)
    ,.pre_mac_phy_width              (pre_mac_phy_width)
    ,.pre_mac_phy_pclk_rate          (pre_mac_phy_pclk_rate)
    ,.pre_mac_phy_rxstandby          (pre_mac_phy_rxstandby)
    ,.pre_mac_phy_rate               (pre_mac_phy_rate)
    ,.pre_mac_phy_txdatavalid        (pre_mac_phy_txdatavalid)
    ,.int_cfg_pbus_num               (int_cfg_pbus_num)
    ,.int_cfg_pbus_dev_num           (int_cfg_pbus_dev_num)
    ,.msg_gen_asnak_grt              (msg_gen_asnak_grt)
    ,.smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl)
    ,.cfg_link_retrain               (cfg_link_retrain)
    ,.cfg_lpbk_en                    (cfg_lpbk_en)
    ,.cfg_plreg_reset                (cfg_plreg_reset)
    ,.cfg_pl_multilane_control       (cfg_pl_multilane_control)
    ,.msg_gen_unlock_grant           (msg_gen_unlock_grant)
    ,.xdlh_match_pmdllp              (xdlh_match_pmdllp)
    ,.pm_ltssm_enable                (pm_ltssm_enable)
    ,.pm_current_data_rate           (int_pm_current_data_rate)
    ,.pm_smlh_entry_to_l0s           (pm_smlh_entry_to_l0s)
    ,.pm_smlh_entry_to_l1            (pm_smlh_req_l1)
    ,.pm_smlh_entry_to_l2            (pm_smlh_req_l2)
    ,.pm_smlh_prepare4_l123          (pm_smlh_prepare4_l123)
    ,.pm_smlh_l0s_exit               (pm_smlh_l0s_exit)
    ,.pm_smlh_l1_exit                (pm_smlh_l1_exit)
    ,.pm_smlh_l23_exit               (pm_smlh_l23_exit)
    ,.pm_xdlh_enter_l1               (pm_xdlh_enter_l1)
    ,.pm_xdlh_req_ack                (pm_xdlh_req_ack)
    ,.pm_xdlh_enter_l23              (pm_xdlh_enter_l23)
    ,.pm_xdlh_actst_req_l1           (pm_xdlh_actst_req_l1)
    ,.pm_freeze_fc_timer             (pm_freeze_fc_timer)
    ,.pm_freeze_cpl_timer            (pm_freeze_cpl_timer)
    ,.pm_xmt_asnak                   (pm_xmt_asnak)
    ,.pm_xmt_turnoff                 (pm_xmt_turnoff)
    ,.pm_xmt_to_ack                  (pm_xmt_to_ack)
    ,.pm_xmt_pme                     (pm_xmt_pme)
    ,.pm_turnoff_timeout             (pm_turnoff_timeout)
    ,.pm_bus_num                     (pm_bus_num)
    ,.pm_dev_num                     (pm_dev_num)
    ,.pm_int_phy_powerdown           (pm_int_phy_powerdown)
    ,.pm_master_state                (pm_master_state)
    ,.pm_slave_state                 (pm_slave_state)
    ,.int_phy_txelecidle             (int_phy_txelecidle)
    ,.sqlchd_rxelecidle              (sqlchd_rxelecidle)
    ,.pm_sys_aux_pwr_det             (pm_sys_aux_pwr_det)
    ,.pm_dbi_cs                      (pm_dbi_cs)
    ,.pm_pme_en_split                (pm_pme_en_split)
    ,.pm_aux_pm_en_split             (pm_aux_pm_en_split)
    ,.pm_init_rst                    (pm_init_rst)
    ,.pm_unlock_msg_req              (pm_unlock_msg_req)
    ,.pm_rx_lane_flip_en             (pm_rx_lane_flip_en)
    ,.pm_tx_lane_flip_en             (pm_tx_lane_flip_en)
    ,.pm_rx_pol_lane_flip_ctrl       (pm_rx_pol_lane_flip_ctrl)
    ,.pm_smlh_link_retrain           (pm_smlh_link_retrain)
    ,.pm_l1_aspm_entr                (pm_l1_aspm_entr)
    ,.pm_radm_block_tlp              (pm_radm_block_tlp)
    ,.app_dev_num                    (app_dev_num)
    ,.app_bus_num                    (app_bus_num)
    ,.msg_gen_hv                     (msg_gen_hv)
    ,.lbc_cpl_hv                     (lbc_cpl_hv)
    ,.pm_powerdown_status          (pm_powerdown_status)
    ,.cfg_force_powerdown          (cfg_force_powerdown)
    ,
    .cfg_uncor_internal_err_sts         (cfg_uncor_internal_err_sts        ),
    .cfg_rcvr_overflow_err_sts          (cfg_rcvr_overflow_err_sts         ),
    .cfg_fc_protocol_err_sts            (cfg_fc_protocol_err_sts           ),
    .cfg_mlf_tlp_err_sts                (cfg_mlf_tlp_err_sts               ),
    .cfg_surprise_down_er_sts           (cfg_surprise_down_er_sts          ),
    .cfg_dl_protocol_err_sts            (cfg_dl_protocol_err_sts           ),
    .cfg_ecrc_err_sts                   (cfg_ecrc_err_sts                  ),
    .cfg_corrected_internal_err_sts     (cfg_corrected_internal_err_sts    ),
    .cfg_replay_number_rollover_err_sts (cfg_replay_number_rollover_err_sts),
    .cfg_replay_timer_timeout_err_sts   (cfg_replay_timer_timeout_err_sts  ),
    .cfg_bad_dllp_err_sts               (cfg_bad_dllp_err_sts              ),
    .cfg_bad_tlp_err_sts                (cfg_bad_tlp_err_sts               ),
    .cfg_rcvr_err_sts                   (cfg_rcvr_err_sts                  ),
    .cfg_link_capable                   (cfg_link_capable                  )



    ,.pm_current_powerdown_p1        (pm_current_powerdown_p1)
    ,.pm_current_powerdown_p0        (pm_current_powerdown_p0)
); // u_DWC_pcie_core


// -------------------------------------------------------------------------------------
// DWC CXS Interface Controller Instantiation
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// DWC CXL Controller Instantiation
// -------------------------------------------------------------------------------------


pm_ctrl

#(  .INST           (INST),
    .NL             (NL),
    .L2NL           (L2NL),
    .RXNL           (RXNL),
    .NF             (NF),
    .NFUNC_WD       (PF_WD),
    .NVC            (NVC),
    .BUSNUM_WD      (BUSNUM_WD),
    .DEVNUM_WD      (DEVNUM_WD),
    .PHY_NB         (PHY_NB),
    .TX_COEF_WD     (TX_COEF_WD),
    .PHY_RATE_WD    (RATE_WIDTH),
    .PDWN_WIDTH     (PDWN_WIDTH),
    .ORIG_DATA_WD   (ORIG_DATA_WD),
    .SERDES_DATA_WD (SERDES_DATA_WD),
    .PIPE_DATA_WD   (PIPE_DATA_WD  ),
    .TX_DATAK_WD    (TX_DATAK_WD),
    .TX_DEEMPH_WD   (TX_DEEMPH_WD),
    .PHY_TXEI_WD    (PHY_TXEI_WD   ),
    .PL_AUX_CLK_FREQ_WD (PL_AUX_CLK_FREQ_WD),
    .PM_SYNC_DEPTH  (CORE_SYNC_DEPTH),
    .PM_MST_WD       (PM_MST_WD),
    .PM_SLV_WD       (PM_SLV_WD)
) u_pm_ctrl(
    //    ----------------- Inputs ----------------------
    .core_rst_n                     (core_rst_n),
    .cfg_upd_aspm_ctrl              (cfg_upd_aspm_ctrl),
    .cfg_upd_aslk_pmctrl            (cfg_upd_aslk_pmctrl),
    .link_req_rst_not               (link_req_rst_not),
    .app_clk_req_n                  (app_clk_req_n),
    .phy_clk_req_n                  (phy_clk_req_n),
    .app_hold_phy_rst               (app_hold_phy_rst),
    .cfg_upd_pme_cap                (cfg_upd_pme_cap),
    .aux_clk                        (aux_clk),
    .pwr_rst_n                      (pwr_rst_n),

// Connect the pipe_clk to the clock which is launching Phystatus
    .pipe_clk                       (core_clk_ug),

    .radm_idle                      (radm_idle),
    .cfg_elastic_buffer_mode        (1'b0),
    .rstctl_ltssm_enable            (rstctl_ltssm_enable),
    .rstctl_core_flush_req          (rstctl_core_flush_req),
    .upstream_port                  (upstream_port),
    .switch_device                  (1'b0),
    .xdlh_nodllp_pending            (xdlh_nodllp_pending),
    .xdlh_no_acknak_dllp_pending    (xdlh_no_acknak_dllp_pending),
    .xdlh_xmt_pme_ack               (xdlh_xmt_pme_ack),
    .xdlh_last_pmdllp_ack           (xdlh_last_pmdllp_ack),
    .rdlh_rcvd_as_req_l1            (rdlh_rcvd_as_req_l1),
    .rdlh_rcvd_pm_enter_l1          (rdlh_rcvd_pm_enter_l1),
    .rdlh_rcvd_pm_enter_l23         (rdlh_rcvd_pm_enter_l23),
    .rdlh_rcvd_pm_req_ack           (rdlh_rcvd_pm_req_ack),
    .smlh_link_up                   (smlh_link_up),
    .smlh_link_in_training          (smlh_link_in_training),
    .all_dwsp_in_l1                 (1'b0),
    .all_dwsp_in_rl0s               (1'b0),                         // Only for SW
    .upsp_in_rl0s                   (1'b0),                         // Only for SW
    .one_dwsp_exit_l1               (1'b0),
    .one_dwsp_exit_l23              (1'b0),
    .app_req_entr_l1                (app_req_entr_l1),
    .app_ready_entr_l23             (app_ready_entr_l23),
    .app_req_exit_l1                (app_req_exit_l1),
    .xdlh_not_expecting_ack         (xdlh_not_expecting_ack),
    .xtlh_had_enough_credit         (xadm_had_enough_credit),
    .smlh_in_l0                     (smlh_in_l0),
    .smlh_in_l0s                    (smlh_in_l0s),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .smlh_in_l1                     (smlh_in_l1),
    .smlh_in_l1_p1                  (smlh_in_l1_p1),
    .smlh_in_l23                    (smlh_in_l23),
    .smlh_l123_eidle_timeout        (smlh_l123_eidle_timeout),
    .latched_rcvd_eidle_set         (latched_rcvd_eidle_set),
    .sys_aux_pwr_det                (sys_aux_pwr_det),
    .xadm_tlp_pending               (xadm_tlp_pending),
    .xadm_block_tlp_ack             (xadm_block_tlp_ack),
    .xtlh_tlp_pending               (xtlh_tlp_pending),
    .xdlh_tlp_pending               (xdlh_tlp_pending),
    .xdlh_retry_pending             (xdlh_retry_pending),
    .xtlh_no_fc_credit              (xadm_no_fc_credit),
    .cfg_aslk_pmctrl                (cfg_aslk_pmctrl),
    .cfg_l0s_entr_latency_timer     (cfg_l0s_entr_latency_timer),
    .cfg_l1_entr_latency_timer      (cfg_l1_entr_latency_timer),
    .cfg_l1_entr_wo_rl0s            (cfg_l1_entr_wo_rl0s),
    .all_dwsp_rcvd_toack_msg        (1'b0),
    .outband_pwrup_cmd              (outband_pwrup_cmd),
    .cfg_upd_pmcsr                  (cfg_upd_pmcsr),
    .cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en),
    .cfg_pmstatus_clr               (cfg_pmstatus_clr),
    .cfg_pmstate                    (cfg_pmstate),
    .cfg_pme_en                     (cfg_pme_en),
    .cfg_aux_pm_en                  (cfg_aux_pm_en),
    .cfg_upd_req_id                 (int_cfg_upd_req_id),
    .cfg_pbus_dev_num               (int_cfg_pbus_dev_num),
    .cfg_pbus_num                   (int_cfg_pbus_num),
    .cfg_clk_pm_en                  (cfg_clk_pm_en),
    .radm_pm_turnoff                (radm_pm_turnoff),
    .radm_pm_asnak                  (radm_pm_asnak),
    .radm_pm_to_ack                 (int_radm_pm_to_ack),
    .apps_pm_xmt_turnoff            (apps_pm_xmt_turnoff),
    .apps_pm_xmt_pme                (apps_pm_xmt_pme),              // Only for upstream port
    .nhp_pme_det                    ({NF{1'b0}}),                   // Only for SW upstream
    .cfg_pme_cap                    (cfg_pme_cap),
    .phy_mac_rxelecidle             (phy_mac_rxelecidle_int),
    .current_data_rate              (current_data_rate),
    .aux_clk_active                 (aux_clk_active),
    .phy_mac_phystatus              (phy_mac_phystatus_int),
    .phy_mac_rxstatus               (phy_mac_rxstatus_int),
    .phy_if_cpcie_pclkreq_n         (mac_phy_pclkreq_n),
    .cfg_pl_l1_nowait_p1            (cfg_pl_l1_nowait_p1),
    .cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel),
    .cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset),
    .cfg_phy_rst_timer              (cfg_phy_rst_timer),
    .cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer),
    .cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq),
    .pme_to_ack_grt                 (pme_to_ack_grt),
    .radm_trgt0_pending             (radm_trgt0_pending),
    .lbc_active                     (lbc_active),
    .pm_pme_grant                   (pm_pme_grant),
    .pme_turn_off_grt               (pme_turn_off_grt),
    .perst_n                        (perst_n),
    .app_xfer_pending                  (app_xfer_pending),
    .dbi_cs                         (dbi_cs),


    .client0_tlp_hv                 (client0_tlp_hv),
    .client1_tlp_hv                 (client1_tlp_hv),
    .msg_gen_hv                     (msg_gen_hv),
    .lbc_cpl_hv                     (lbc_cpl_hv),


    .cfg_link_capable               (cfg_link_capable),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .mac_phy_powerdown              (pre_mac_phy_powerdown),
    .mac_phy_txelecidle             (int_mac_phy_txelecidle),
    // PHY interface signals
    .mac_phy_txdata                 (pre_mac_phy_txdata),
    .mac_phy_txdatak                (pre_mac_phy_txdatak),
    .mac_phy_txdetectrx_loopback    (pre_mac_phy_txdetectrx_loopback),
    .mac_phy_txcompliance           (glue_mac_phy_txcompliance),
    .mac_phy_rxpolarity             (pre_mac_phy_rxpolarity),
    .ltssm_rxpolarity               (tmp_mac_phy_rxpolarity),
    .mac_phy_width                  (pre_mac_phy_width),
    .mac_phy_pclk_rate              (pre_mac_phy_pclk_rate),
    .mac_phy_rxstandby              (pre_mac_phy_rxstandby),
    .cfg_phy_control                (pre_cfg_phy_control),
    .msg_gen_asnak_grt              (msg_gen_asnak_grt),

    .rx_lane_flip_en                (rx_lane_flip_en),
    .tx_lane_flip_en                (tx_lane_flip_en),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),

    .cfg_link_dis                   (cfg_link_dis),
    .cfg_link_retrain               (cfg_link_retrain),
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_2nd_reset                  (cfg_2nd_reset),
    .cfg_plreg_reset                (cfg_plreg_reset),
    .app_init_rst                   (app_init_rst),
    .cfg_directed_speed_change      (1'b0),
    .cfg_directed_width_change      (cfg_pl_multilane_control[6]),
    .ven_msg_req                    (ven_msg_req),
    .ven_msi_req                    (ven_msi_req),
    .app_ltr_msg_req                (1'b0),
    .app_unlock_msg                 (app_unlock_msg),
    .msg_gen_unlock_grant           (msg_gen_unlock_grant),
    .xdlh_match_pmdllp              (xdlh_match_pmdllp),
    // ----------------- Outputs -----------------------
    .pm_en_aux_clk_g                (en_aux_clk_g),
    .pm_ltssm_enable                (pm_ltssm_enable),
    .pm_current_data_rate           (int_pm_current_data_rate),
    .wake                           (wake),
    .local_ref_clk_req_n            (local_ref_clk_req_n),
    .pm_smlh_entry_to_l0s           (pm_smlh_entry_to_l0s),
    .pm_smlh_entry_to_l1            (pm_smlh_entry_to_l1),
    .pm_smlh_entry_to_l2            (pm_smlh_entry_to_l2),
    .pm_smlh_prepare4_l123          (pm_smlh_prepare4_l123),
    .pm_smlh_l0s_exit               (pm_smlh_l0s_exit),
    .pm_smlh_l1_exit                (pm_smlh_l1_exit),
    .pm_smlh_l23_exit               (pm_smlh_l23_exit),
    .pm_xtlh_block_tlp              (pm_xtlh_block_tlp),
    .pm_block_all_tlp               (pm_block_all_tlp),
    .pm_l1_aspm_entr                (pm_l1_aspm_entr),
    .pm_radm_block_tlp              (pm_radm_block_tlp),
    .pm_xdlh_enter_l1               (pm_xdlh_enter_l1),
    .pm_xdlh_req_ack                (pm_xdlh_req_ack),
    .pm_xdlh_enter_l23              (pm_xdlh_enter_l23),
    .pm_xdlh_actst_req_l1           (pm_xdlh_actst_req_l1),
    .pm_freeze_fc_timer             (pm_freeze_fc_timer),
    .pm_freeze_cpl_timer            (pm_freeze_cpl_timer),
    .pm_req_dwsp_turnoff            (),
    .pm_xmt_asnak                   (pm_xmt_asnak),                 // N/A for endpoint
    .pm_xmt_turnoff                 (pm_xmt_turnoff),               // N/A for endpoint
    .pm_xmt_to_ack                  (pm_xmt_to_ack),
    .pm_xmt_pme                     (pm_xmt_pme),
    .pm_turnoff_timeout             (pm_turnoff_timeout),
    .pm_linkst_in_l0                (pm_linkst_in_l0),
    .pm_linkst_in_l1                (pm_linkst_in_l1),
    .pm_linkst_in_l2                (pm_linkst_in_l2),
    .pm_linkst_l2_exit              (pm_linkst_l2_exit),
    .pm_linkst_in_l3                (),
    .pm_linkst_in_l0s               (pm_linkst_in_l0s),
    .pm_pme_en                      (pm_pme_en),
    .pm_status                      (pm_status),
    .pm_aux_pm_en                   (aux_pm_en),
    .pm_bus_num                     (pm_bus_num),
    .pm_dev_num                     (pm_dev_num),
    .pm_int_phy_powerdown           (pm_int_phy_powerdown),
    .pm_curnt_state                 (pm_curnt_state),
    .pm_req_sticky_rst              (pm_req_sticky_rst),
    .pm_req_core_rst                  (pm_req_core_rst),
    .pm_req_non_sticky_rst          (pm_req_non_sticky_rst),
    .pm_sel_aux_clk                 (pm_sel_aux_clk),
    .pm_en_core_clk                 (pm_en_core_clk),
    .pm_req_phy_rst                 (pm_req_phy_rst),
    .pm_req_phy_perst               (pm_req_phy_perst),
    .pm_master_state                (pm_master_state),
    .pm_slave_state                 (pm_slave_state),
    .phy_if_cpcie_powerdown         (mac_phy_powerdown),
    .phy_if_cpcie_txelecidle        (mac_phy_txelecidle),
    .pm_int_txelecidle              (int_phy_txelecidle),
    .phy_if_cpcie_txdata                (mac_phy_txdata),
    .phy_if_cpcie_txdatak               (mac_phy_txdatak),
    .phy_if_cpcie_txdetectrx_loopback   (mac_phy_txdetectrx_loopback),
    .phy_if_cpcie_txcompliance          (mac_phy_txcompliance),
    .phy_if_cpcie_rxpolarity            (mac_phy_rxpolarity),
    .phy_if_cpcie_width                 (mac_phy_width),
    .phy_if_cpcie_pclk_rate             (mac_phy_pclk_rate),
    .phy_if_cpcie_rxstandby             (mac_phy_rxstandby),
    .phy_if_cpcie_txdatavalid           (mac_phy_txdatavalid),
    .phy_if_cfg_phy_control             (cfg_phy_control),
    .phy_if_cpcie_phy_type              (pm_phy_type),
    .pm_pmstate                         (pm_dstate),
    .sqlchd_rxelecidle                  (sqlchd_rxelecidle),
    .pm_aux_clk_ft                      (pm_aux_clk),
    .pm_sys_aux_pwr_det_ft              (pm_sys_aux_pwr_det),
    .pm_aux_clk_active_ft               (pm_aux_clk_active),

    .pm_xadm_client0_tlp_hv             (pm_xadm_client0_tlp_hv)
    ,
    .pm_xadm_client1_tlp_hv             (pm_xadm_client1_tlp_hv)

    ,
    .pm_dbi_cs_ft                       (pm_dbi_cs)
    ,
    .pm_pme_en_split                    (pm_pme_en_split),
    .pm_aux_pm_en_split                 (pm_aux_pm_en_split),
    .pm_init_rst                        (pm_init_rst),
    .pm_unlock_msg_req                  (pm_unlock_msg_req)
    ,
    .pm_rx_lane_flip_ctrl               (pm_rx_lane_flip_en),
    .pm_tx_lane_flip_ctrl               (pm_tx_lane_flip_en),
    .pm_rx_pol_lane_flip_ctrl           (pm_rx_pol_lane_flip_ctrl)
    ,
    .pm_smlh_link_retrain               (pm_smlh_link_retrain)
    ,
    .phy_if_elasticbuffermode           (mac_phy_elasticbuffermode)
    ,
    .pm_l1_entry_started                (pm_l1_entry_started)
    ,
    .pm_powerdown_status                (pm_powerdown_status),
    .cfg_force_powerdown                (cfg_force_powerdown)
    ,.pm_current_powerdown_p1           (pm_current_powerdown_p1)
    ,.pm_current_powerdown_p0           (pm_current_powerdown_p0)
);

// ----------------------------------------------------------------------
// Instantiate reset request control logic
// ----------------------------------------------------------------------

// Pending Status


endmodule
