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
// ---    $DateTime: 2020/10/29 10:45:06 $
// ---    $Revision: #54 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/DWC_pcie_core.sv#54 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module description:  This is for core only wrapper for dual mode/end device/root complex/switch application.
// --- core only modules:
// --- * radm_dm        : Rcvd ADM for dual-mode application
// --- * radm_ep        : Rcvd ADM for end-point application
// --- * radm_rc        : Rcvd ADM for root application
// --- * radm_sw        : Rcvd ADM for switch application
// --- * xadm           : Txmt ADM
// --- * cxs_top        : CXS Interface
// --- * cx_pl          : Basic PCI Express Functionality: Layer1, Layer2 and Layer3
// --- * cdm            : Type 0 CDM
// --- * lbc            : Local bus controller
// --- * pm_ctrl        : Power management running at Aux clock
// --- * msg_gen        : Message TLP Generation
// -----------------------------------------------------------------------------
//
//
`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Cdm/cdm_pkg.svh"
 
 module DWC_pcie_core 
import cdm_pkg::*;
   #(
// module parameter port list
    parameter INST              = 0,                                    // The uniquifying parameter for each port logic instance.
    parameter NL                = `CX_NL,                               // Max number of lanes supported
    parameter TXNL              = `CM_TXNL,                             // Max Tx Lane Width
    parameter RXNL              = `CM_RXNL,                             // Max Rx Lane Width
    parameter NB                = `CX_NB,                               // Number of symbols (bytes) per clock cycle
    parameter PHY_NB            = `CX_PHY_NB,                           // Number of symbols (bytes) per clock cycle of PHY's PIPE interface
    parameter CM_PHY_NB         = `CM_PHY_NB,                           // Number of symbols (bytes) per clock cycle of M-PHY's PIPE interface
    parameter NW                = `CX_NW,                               // Number of 32-bit dwords handled by the datapath each clock.
    parameter NF                = `CX_NFUNC,                            // Number of functions
    parameter PF_WD             = `CX_NFUNC_WD,                         // Width of virtual function number signal
    parameter NVC               = `CX_NVC,                              // Max number of Virtual Channels
    parameter NVC_XALI_EXP      = `CX_NVC_XALI_EXPANSION,               // Max number of Virtual Channels used on Xali Expansion
    parameter NHQ               = `CX_NHQ,                              // number of header queues per VC
    parameter NDQ               = `CX_NDQ,                              // number of data queues per VC
    parameter DATA_PAR_WD       = `TRGT_DATA_PROT_WD,                   // data bus parity width
    parameter TRGT_DATA_WD          = `TRGT_DATA_WD,

    parameter ADDR_PAR_WD       = `CX_ADDR_PAR_WD,                      // addr bus parity width
    parameter DW_W_PAR          = (32*NW)+ DATA_PAR_WD,                 // Width of datapath in bits plus the parity bits.
    parameter DW_WO_PAR         = (32*NW),                              // Width of datapath in bits.
    parameter RAS_PCIE_HDR_PROT_WD = `CX_RAS_PCIE_HDR_PROT_WD,
    parameter TX_HW_W_PAR       = 128 + RAS_PCIE_HDR_PROT_WD,
    parameter   RADM_P_HWD      = `RADM_P_HWD,
    parameter DW                = (`CC_DEVICE_TYPE==`CC_EP) ? (`RADM_PARBITS_OUT_VALUE ? (32*NW) + DATA_PAR_WD : (32*NW) ) : (32*NW), // Width of datapath in bits - For ECC we export the check bits.
    parameter DATA_WIDTH        = (`CC_DEVICE_TYPE==`CC_EP) ? DW : DW_WO_PAR,
    parameter ADDR_WIDTH        = `FLT_Q_ADDR_WIDTH,
    // parameter ADDR_WIDTH        = (`CC_DEVICE_TYPE==`CC_EP) ? ( `RADM_PARBITS_OUT_VALUE ? `FLT_Q_ADDR_WIDTH + ADDR_PAR_WD : `FLT_Q_ADDR_WIDTH ) : `FLT_Q_ADDR_WIDTH,
    parameter RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1, // Max number of DLLPs received
    parameter L2N_INTFC         = 1,                                    // 2**L2N_INTFC = number of interface
    parameter ALL_FUNC_NUM      = {3'h7, 3'h6, 3'h5, 3'h4, 3'h3, 3'h2, 3'h1, 3'h0},
    parameter TRGT_HDR_WD       = `TRGT_HDR_WD,
    parameter TRGT_HDR_PROT_WD  = `TRGT_HDR_PROT_WD,
    parameter CLIENT_HDR_PROT_WD = `CLIENT_HDR_PROT_WD,
    parameter ST_HDR            = `ST_HDR,
    parameter HDR_PROT_WD       = `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD,    // XADM Common Header ecc/parity protection width
    parameter LBC_MSG_HDR_WD    = `ST_HDR
                                  ,
    parameter RBUF_DEPTH        = `CX_RBUF_DEPTH,
    parameter RBUF_PW           = `RBUF_PW,                             // True pointer width is calculated from the depth of the memory
    parameter SOTBUF_DP         = `SOTBUF_DEPTH,                        // Indexed by sequence number (or some bits of it)
    parameter SOTBUF_PW         = `SOTBUF_L2DEPTH,                      // Indexed by sequence number (or some bits of it)
    parameter SOTBUF_WD         = `SOTBUF_WIDTH,
    parameter DATAQ_WD          = NW+1+1+1+1+1+DW_WO_PAR,
    parameter RADM_Q_DATABITS   = `CX_RADM_Q_DATABITS,
    parameter RADM_Q_DATABITS_O = `CX_RADM_Q_DATABITS_OUT,
    parameter LBC_EXT_AW        = `CX_LBC_EXT_AW,

    parameter RADM_PQ_HWD       = `CX_RADM_PQ_HWD,
    parameter RADM_NPQ_HWD      = `CX_RADM_NPQ_HWD,
    parameter RADM_CPLQ_HWD     = `CX_RADM_CPLQ_HWD,
    parameter RADM_PQ_HPW       = `RADM_PQ_HPW,
    parameter RADM_NPQ_HPW      = `RADM_NPQ_HPW,
    parameter RADM_CPLQ_HPW     = `RADM_CPLQ_HPW,
    parameter RADM_PQ_DPW       = `RADM_PQ_DPW,
    parameter RADM_NPQ_DPW      = `RADM_NPQ_DPW,
    parameter RADM_CPLQ_DPW     = `RADM_CPLQ_DPW,

    parameter RADM_Q_H_CTRLBITS     = `CX_RADM_Q_H_CTRLBITS,
    parameter RADM_Q_D_CTRLBITS     = `CX_RADM_Q_D_CTRLBITS,
    parameter RADM_PQ_H_DATABITS    = `CX_RADM_PQ_H_DATABITS,
    parameter RADM_PQ_H_DATABITS_O  = `CX_RADM_PQ_H_DATABITS_OUT,
    parameter RADM_NPQ_H_DATABITS   = `CX_RADM_NPQ_H_DATABITS,
    parameter RADM_NPQ_H_DATABITS_O = `CX_RADM_NPQ_H_DATABITS_OUT,
    parameter RADM_CPLQ_H_DATABITS  = `CX_RADM_CPLQ_H_DATABITS,
    parameter RADM_CPLQ_H_DATABITS_O= `CX_RADM_CPLQ_H_DATABITS_OUT,

    parameter RADM_PQ_H_ADDRBITS    = `CX_RADM_PQ_H_ADDRBITS,
    parameter RADM_NPQ_H_ADDRBITS   = `CX_RADM_NPQ_H_ADDRBITS,
    parameter RADM_CPLQ_H_ADDRBITS  = `CX_RADM_CPLQ_H_ADDRBITS,
    parameter RADM_PQ_D_ADDRBITS    = `CX_RADM_PQ_D_ADDRBITS,
    parameter RADM_NPQ_D_ADDRBITS   = `CX_RADM_NPQ_D_ADDRBITS,
    parameter RADM_CPLQ_D_ADDRBITS  = `CX_RADM_CPLQ_D_ADDRBITS,

    parameter RADM_PQ_HDP       = `RADM_PQ_HDP,
    parameter RADM_NPQ_HDP      = `RADM_NPQ_HDP,
    parameter RADM_CPLQ_HDP     = `RADM_CPLQ_HDP,
    parameter RADM_PQ_DDP       = `RADM_PQ_DDP,
    parameter RADM_NPQ_DDP      = `RADM_NPQ_DDP,
    parameter RADM_CPLQ_DDP     = `RADM_CPLQ_DDP,
    parameter  DCA_WD           = `CX_LOGBASE2(NW/4+1),
    parameter  APP_CRD_WD       = `CX_NW_GTR_4_VALUE ? `CX_LOGBASE2(NW/4+1)*`CX_NVC : `CX_NVC,
    parameter BUSNUM_WD         = `CX_BUSNUM_WD,                        // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
    parameter DEVNUM_WD         = `CX_DEVNUM_WD,                        // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.
    parameter N_FLT_MASK        = `CX_N_FLT_MASK,                       // vector width for filter mask

    parameter CPL_LUT_DEPTH         = `CX_MAX_TAG +1,           // number of max tag that this core is configured to run





    parameter TX_COEF_WD = 18, // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}

    parameter ORIG_DATA_WD = PHY_NB * 8,
    parameter SERDES_DATA_WD = PHY_NB * 10,
    parameter PIPE_DATA_WD = (`CX_PIPE_SERDES_ARCH_VALUE) ? (NL * SERDES_DATA_WD) : (NL * ORIG_DATA_WD),
    parameter PDWN_WIDTH = `CX_PHY_PDOWN_WD,
    parameter RATE_WIDTH = `CX_PHY_RATE_WD,
    parameter WIDTH_WIDTH = `CX_PHY_WIDTH_WD,
    parameter TX_DEEMPH_WD = `CX_PHY_TXDEEMPH_WD,
    parameter PHY_TXEI_WD = `CX_PHY_TXEI_WD,

    parameter ERR_BUS_WD  = `CX_ERR_BUS_WD,
    parameter RX_TLP      = `CX_RX_TLP, // Number of TLPs that can be received in a single cycle
    parameter FX_TLP      = `CX_FX_TLP, // Number of TLPs that can be processed in a single cycle after the formation block

    parameter TAG_SIZE    = `CX_TAG_SIZE,
    parameter LOOKUPID_WD = `CX_REMOTE_LOOKUPID_WD,


    parameter ATTR_WD = `FLT_Q_ATTR_WIDTH,
    parameter DW_LEN_WD = `FLT_Q_DW_LENGTH_WIDTH,


    parameter   LBC_INT_WD        = `CX_LBC_INT_WD,    // LBC - XADM data bus width can be 32, 64 or 128


    parameter GEN2_DYNAMIC_FREQ_VALUE        = `CX_GEN2_DYNAMIC_FREQ_VALUE,

    parameter RADM_RAM_RD_LATENCY      = `CX_RADM_RAM_RD_LATENCY,
    parameter RADM_FORMQ_RAM_RD_LATENCY = `CX_RADM_FORMQ_RAM_RD_LATENCY,
    parameter RETRY_RAM_RD_LATENCY     = `CX_RETRY_RAM_RD_LATENCY,
    parameter RETRY_SOT_RAM_RD_LATENCY = `CX_RETRY_SOT_RAM_RD_LATENCY,


    parameter HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8,
    parameter DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12


    ,
    parameter AUX_CLK_FREQ_WD = `CX_PL_AUX_CLK_FREQ_WD,
    parameter L2NL = (NL==1) ? 1 : `CX_LOGBASE2(NL)
    ,
    parameter P_R_WD = `PCLK_RATE_WD // pclk_rate width


    ,
    parameter PM_MST_WD = 5,
    parameter PM_SLV_WD = 5
)

                     (
  // list of port declarations



// start xadm ports will present no matter AMBA_POPULATED is defined or not
    input   [NVC_XALI_EXP-1:0]          client0_tlp_hv,
    input   [NVC_XALI_EXP-1:0]          client1_tlp_hv,
    output  [(NVC*3)-1:0]               radm_grant_tlp_type,
    input   [NVC_XALI_EXP-1:0]          client0_tlp_dv,
    input   [NVC_XALI_EXP-1:0]          client0_tlp_eot,
    input   [NVC_XALI_EXP-1:0]          client0_addr_align_en,
    input   [(NVC_XALI_EXP*8)-1:0]      client0_tlp_byte_en,
    input   [(NVC_XALI_EXP*16)-1:0]     client0_remote_req_id,
    input   [(NVC_XALI_EXP*12)-1:0]     client0_cpl_byte_cnt,
    input   [(NVC_XALI_EXP*3)-1:0]      client0_tlp_tc,
    input   [(NVC_XALI_EXP*ATTR_WD)-1:0]client0_tlp_attr,
    input   [(NVC_XALI_EXP*3)-1:0]      client0_cpl_status,
    input   [NVC_XALI_EXP-1:0]          client0_cpl_bcm,
    input   [NVC_XALI_EXP-1:0]          client0_tlp_bad_eot,
    input   [(NVC_XALI_EXP*2)-1:0]      client0_tlp_fmt,
    input   [(NVC_XALI_EXP*5)-1:0]      client0_tlp_type,
    input   [NVC_XALI_EXP-1:0]          client0_tlp_td,
    input   [NVC_XALI_EXP-1:0]          client0_tlp_ep,
    input   [(NVC_XALI_EXP*13)-1:0]     client0_tlp_byte_len,
    input   [(NVC_XALI_EXP*64)-1:0]     client0_tlp_addr,
    input   [(NVC_XALI_EXP*TAG_SIZE)-1:0]client0_tlp_tid,
    input   [(NVC_XALI_EXP*DW_W_PAR)-1:0]client0_tlp_data,
    input   [(NVC_XALI_EXP*PF_WD)-1:0]  client0_tlp_func_num,
    output  [NVC_XALI_EXP-1:0]          xadm_client0_halt,




    input   [NVC_XALI_EXP-1:0]          client1_addr_align_en,
    input   [(NVC_XALI_EXP*8)-1:0]      client1_tlp_byte_en,
    input   [(NVC_XALI_EXP*16)-1:0]     client1_remote_req_id,
    input   [(NVC_XALI_EXP*3)-1:0]      client1_cpl_status,
    input   [NVC_XALI_EXP-1:0]          client1_cpl_bcm,
    input   [(NVC_XALI_EXP*12)-1:0]     client1_cpl_byte_cnt,
    input   [NVC_XALI_EXP-1:0]          client1_tlp_dv,
    input   [NVC_XALI_EXP-1:0]          client1_tlp_eot,
    input   [NVC_XALI_EXP-1:0]          client1_tlp_bad_eot,
    input   [(NVC_XALI_EXP*2)-1:0]      client1_tlp_fmt,
    input   [(NVC_XALI_EXP*5)-1:0]      client1_tlp_type,
    input   [(NVC_XALI_EXP*3)-1:0]      client1_tlp_tc,
    input   [NVC_XALI_EXP-1:0]          client1_tlp_td,
    input   [NVC_XALI_EXP-1:0]          client1_tlp_ep,
    input   [(NVC_XALI_EXP*ATTR_WD)-1:0]client1_tlp_attr,
    input   [(NVC_XALI_EXP*13)-1:0]     client1_tlp_byte_len,
    input   [(NVC_XALI_EXP*TAG_SIZE)-1:0]client1_tlp_tid,
    input   [(NVC_XALI_EXP*64)-1:0]     client1_tlp_addr,
    input   [(NVC_XALI_EXP*DW_W_PAR)-1:0]client1_tlp_data,
    input   [(NVC_XALI_EXP*PF_WD)-1:0]   client1_tlp_func_num,
    output  [NVC_XALI_EXP-1:0]          xadm_client1_halt,



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




 // end xadm ports will present no matter AMBA_POPULATED is defined or not

    output                              radm_cpl_timeout,
    output  [PF_WD-1:0]                 radm_timeout_func_num,
    output  [2:0]                       radm_timeout_cpl_tc,
    output  [1:0]                       radm_timeout_cpl_attr,
    output  [11:0]                      radm_timeout_cpl_len,
    output  [TAG_SIZE-1:0]              radm_timeout_cpl_tag,

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





    input  [(NVC*3)-1:0]           trgt1_radm_pkt_halt,
    input  [(NVC*3)-1:0]           bridge_trgt1_radm_pkt_halt,

    input                     app_dbi_ro_wr_disable,      // Set dbi_ro_wr_en to 0, disable write to DBI_RO_WR_EN bit

    input   [31:0]                      dbi_addr,
    input   [31:0]                      dbi_din,
    input                               dbi_cs2,
    input   [3:0]                       dbi_wr,
    output                              lbc_dbi_ack,
    output  [31:0]                      lbc_dbi_dout,

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
    input                               ven_msi_req,
    input   [PF_WD-1:0]                 ven_msi_func_num,
    input   [2:0]                       ven_msi_tc,
    input   [4:0]                       ven_msi_vector,
    output                              ven_msi_grant,
    output  [NF-1:0]                    cfg_msi_en,









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


    input                               tx_lane_flip_en,

    input   [NF-1:0]                    sys_int,
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
    input                               app_unlock_msg,
    input                               pm_xtlh_block_tlp,
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
    output  [5:0]                       smlh_ltssm_state,
    output  [5:0]                       ltssm_cxl_enable,
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
    output  [NF-1:0]                    cfg_eml_control,
    output  [NF-1:0]                    hp_pme,
    output  [NF-1:0]                    hp_int,
    output  [NF-1:0]                    hp_msi,
    input                               app_ltssm_enable,
    output  [BUSNUM_WD-1:0]             cfg_pbus_num,
    output  [DEVNUM_WD-1:0]             cfg_pbus_dev_num,
    input  [(3*NF)-1:0]                 pm_dstate,
    input  [NF-1:0]                     pm_status,
    output                              cfg_link_dis,
    output                              cfg_link_auto_bw_int,
    output                              cfg_link_auto_bw_msi,
    output                              cfg_bw_mgt_int,
    output                              cfg_bw_mgt_msi,
    output  [NVC-1:0]                   radm_q_not_empty,
    output  [NVC-1:0]                   radm_qoverflow,



    input  [(PDWN_WIDTH - 1) : 0]       mac_phy_powerdown,
    input  [NL*PHY_TXEI_WD-1:0]         mac_phy_txelecidle,
    input   [NL-1:0]                    phy_mac_phystatus,
    input   [(PIPE_DATA_WD - 1):0]      phy_mac_rxdata,
    input   [(NL*PHY_NB)-1:0]           phy_mac_rxdatak,
    input   [NL-1:0]                    phy_mac_rxvalid,
    input   [(NL*3)-1:0]                phy_mac_rxstatus,
    input   [NL-1:0]                    phy_mac_rxstandbystatus,
    input   [31:0]                      phy_cfg_status,

    input  [NL-1:0]                     mac_phy_txdetectrx_loopback,
    input  [NL-1:0]                     mac_phy_txcompliance,
    input  [NL-1:0]                     mac_phy_rxpolarity,

    input   [NL-1:0]                    phy_mac_rxdatavalid,

    output  [31:0]                      cfg_phy_control,
    input                               core_clk,
    input                               core_clk_ug,
    input                               aux_clk_g,
    input                               radm_clk_g,
    output                              en_radm_clk_g,
    output                              radm_idle,
    input                               pwr_rst_n,
    input                               sticky_rst_n,
    input                               non_sticky_rst_n,
    input                               core_rst_n,
    input                               pm_sel_aux_clk,
    input   [3:0]                       device_type,
    input                               app_req_retry_en,
    input   [NF-1:0]                    app_pf_req_retry_en,


    output                              training_rst_n,

    output  [RBUF_PW -1:0]              xdlh_retryram_addr,
    output  [`RBUF_WIDTH-1:0]           xdlh_retryram_data,
    output                              xdlh_retryram_we,
    output                              xdlh_retryram_en,
    output                              xdlh_retryram_par_chk_val,
    input   [`RBUF_WIDTH-1:0]           retryram_xdlh_data,

    output  [SOTBUF_PW -1:0]            xdlh_retrysotram_waddr,
    output  [SOTBUF_PW -1:0]            xdlh_retrysotram_raddr,
    output  [SOTBUF_WD -1:0]            xdlh_retrysotram_data,
    output                              xdlh_retrysotram_we,
    output                              xdlh_retrysotram_en,
    output                              xdlh_retrysotram_par_chk_val,
    input   [SOTBUF_WD -1:0]            retrysotram_xdlh_data,
    input   [RADM_PQ_H_DATABITS_O-1:0]  p_hdrq_dataout,
    output  [RADM_Q_H_CTRLBITS-1:0]     p_hdrq_par_chk_val,
    output  [RADM_PQ_H_ADDRBITS-1:0]    p_hdrq_addra,
    output  [RADM_PQ_H_ADDRBITS-1:0]    p_hdrq_addrb,
    output  [RADM_PQ_H_DATABITS-1:0]    p_hdrq_datain,
    output  [RADM_Q_H_CTRLBITS-1:0]     p_hdrq_ena,
    output  [RADM_Q_H_CTRLBITS-1:0]     p_hdrq_enb,
    output  [RADM_Q_H_CTRLBITS-1:0]     p_hdrq_wea,
    input   [RADM_Q_DATABITS_O-1:0]     p_dataq_dataout,
    output  [RADM_Q_D_CTRLBITS-1:0]     p_dataq_par_chk_val,
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

    input [NF-1:0]                      exp_rom_validation_status_strobe,
    input [NF*3-1:0]                    exp_rom_validation_status,
    input [NF-1:0]                      exp_rom_validation_details_strobe,
    input [NF*4-1:0]                    exp_rom_validation_details,
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
    output  [(8*NF)-1:0]                cfg_subbus_num
   ,output                              cfg_2nd_reset
    ,
    input                   app_clk_pm_en
    ,input                  aux_clk_active


    ,output  [NF-1:0]                 cfg_send_cor_err
    ,output  [NF-1:0]                 cfg_send_nf_err
    ,output  [NF-1:0]                 cfg_send_f_err
    ,output  [NF-1:0]                 cfg_int_disable
    ,output  [NF-1:0]                 cfg_no_snoop_en
    ,output  [NF-1:0]                 cfg_relax_order_en





    ,output   [NF-1:0]                cfg_br_ctrl_serren
    ,input    [RADM_Q_H_CTRLBITS-1:0]        p_hdrq_parerr
    ,input    [RADM_Q_D_CTRLBITS-1:0]        p_dataq_parerr
    ,input                                   retryram_xdlh_parerr
    ,input                                   retrysotram_xdlh_parerr
    ,output   [RADM_Q_H_CTRLBITS-1:0]        p_hdrq_parerr_out_int
    ,output   [RADM_Q_D_CTRLBITS-1:0]        p_dataq_parerr_out_int
    ,input                                   pm_aux_clk
    ,input                                   pm_aux_clk_active
    ,output [ADDR_WIDTH -1:0]           radm_trgt1_addr_i
    ,output [TRGT_DATA_WD-1:0]          radm_trgt1_data_i
    ,output [2:0]                       radm_trgt1_vc_num_i
    ,output [DW_W_PAR-1:0]              radm_bypass_data_i
    ,output [NHQ*12-1:0]                radm_bypass_byte_cnt_i
    ,output [NHQ*`FLT_Q_ADDR_WIDTH-1:0] radm_bypass_addr_i
    ,output [NVC-1:0]                   radm_pend_cpl_so
    ,output [NVC-1:0]                   radm_q_cpl_not_empty
    ,output [(NVC*3)-1:0]               radm_grant_tlp_type_i
    ,output                             rstctl_slv_flush_req
    ,output                             rstctl_mstr_flush_req
    ,output                             rstctl_flush_done
    ,input                              pm_phy_type
    ,output [2:0]                       current_data_rate              // 0=running at gen1 speeds, 1=running at gen2 speeds
    ,output [2:0]                       pm_current_data_rate_others    // reg pm_current_data_rate using core_clk to resolve massive fan-out issues
                                                                    // only used in blocks other than layer1

    ,output [NF-1:0]                   cfg_hp_slot_ctrl_access
    ,output [NF-1:0]                   cfg_dll_state_chged_en
    ,output [NF-1:0]                   cfg_cmd_cpled_int_en
    ,output [NF-1:0]                   cfg_pre_det_chged_en
    ,output [NF-1:0]                   cfg_mrl_sensor_chged_en
    ,output [NF-1:0]                   cfg_pwr_fault_det_en
    ,output [NF-1:0]                   cfg_atten_button_pressed_en
    ,output [NF-1:0]                   cfg_hp_int_en

    ,output                             cfg_upd_aspm_ctrl
    ,output [(NF - 1) : 0]              cfg_upd_aslk_pmctrl
    ,output [NF-1:0]                    cfg_upd_pme_cap
    ,output                             cfg_elastic_buffer_mode
    ,output                             rstctl_ltssm_enable
    ,output                             rstctl_core_flush_req
    ,output                             upstream_port
    ,output                             xdlh_nodllp_pending
    ,output                             xdlh_no_acknak_dllp_pending
    ,output                             xdlh_xmt_pme_ack
    ,output                             xdlh_last_pmdllp_ack
    ,output                             rdlh_rcvd_as_req_l1
    ,output                             rdlh_rcvd_pm_enter_l1
    ,output                             rdlh_rcvd_pm_enter_l23
    ,output                             rdlh_rcvd_pm_req_ack
    ,output                             smlh_link_in_training
    ,output                             xdlh_not_expecting_ack
    ,output [NVC-1:0]                   xadm_had_enough_credit
    ,output                             smlh_in_l0
    ,output                             smlh_in_l0s
    ,output                             smlh_in_rl0s
    ,output                             smlh_in_l1
    ,output                             smlh_in_l1_p1
    ,output                             smlh_in_l23
    ,output                             smlh_l123_eidle_timeout
    ,output                             latched_rcvd_eidle_set
    ,output                             xadm_tlp_pending
    ,output                             xadm_block_tlp_ack
    ,output                             xtlh_tlp_pending
    ,output                             xdlh_tlp_pending
    ,output                             xdlh_retry_pending
    ,output [NVC-1:0]                   xadm_no_fc_credit
    ,output [(2*NF)-1:0]                cfg_aslk_pmctrl
    ,output [2:0]                       cfg_l0s_entr_latency_timer
    ,output [2:0]                       cfg_l1_entr_latency_timer
    ,output                             cfg_l1_entr_wo_rl0s
    ,output [NF-1:0]                    cfg_upd_pmcsr
    ,output [NF-1:0]                    cfg_upd_aux_pm_en
    ,output [NF-1:0]                    cfg_pmstatus_clr
    ,output [(3*NF)-1:0]                cfg_pmstate
    ,output [NF-1:0]                    cfg_pme_en
    ,output [NF-1:0]                    cfg_aux_pm_en
    ,output [NF-1:0]                    cfg_upd_req_id
    ,output                             cfg_clk_pm_en
    ,output                             radm_pm_asnak
    ,output                             int_radm_pm_to_ack
    ,output [(5*NF)-1:0]                cfg_pme_cap
    ,output                             cfg_pl_l1_nowait_p1
    ,output                             cfg_pl_l1_clk_sel
    ,output                             cfg_phy_perst_on_warm_reset
    ,output [17:0]                      cfg_phy_rst_timer
    ,output [5:0]                       cfg_pma_phy_rst_delay_timer
    ,output [AUX_CLK_FREQ_WD-1:0]       cfg_pl_aux_clk_freq
    ,output                             pme_to_ack_grt
    ,output                             radm_trgt0_pending
    ,output                             lbc_active
    ,output [NF-1:0]                    pm_pme_grant
    ,output                             pme_turn_off_grt
    ,output [(PDWN_WIDTH - 1) :0]       pre_mac_phy_powerdown
    ,output [NL*PHY_TXEI_WD-1:0]        int_mac_phy_txelecidle
    ,output [(PIPE_DATA_WD - 1):0]      pre_mac_phy_txdata
    ,output [(NL*PHY_NB)-1:0]           pre_mac_phy_txdatak
    ,output [NL-1:0]                    pre_mac_phy_txdetectrx_loopback
    ,output reg [NL-1:0]                glue_mac_phy_txcompliance
    ,output [NL-1:0]                    pre_mac_phy_rxpolarity
    ,output [NL-1:0]                    tmp_mac_phy_rxpolarity
    ,output [(WIDTH_WIDTH -1):0]        pre_mac_phy_width
    ,output [P_R_WD-1:0]                pre_mac_phy_pclk_rate
    ,output [NL-1:0]                    pre_mac_phy_rxstandby
    ,output [RATE_WIDTH-1:0]            pre_mac_phy_rate
    ,output [NL-1:0]                    pre_mac_phy_txdatavalid
    ,output [7:0]                       int_cfg_pbus_num
    ,output [4:0]                       int_cfg_pbus_dev_num
    ,output                             msg_gen_asnak_grt
    ,output [L2NL-1:0]                  smlh_lane_flip_ctrl  //flip lanes with latched for gen3/4 enter polling.Compliance
    ,output                             cfg_link_retrain
    ,output                             cfg_lpbk_en
    ,output                             cfg_plreg_reset
    ,output [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control
    ,output                             msg_gen_unlock_grant
    ,output [3:0]                       xdlh_match_pmdllp
    ,input                              pm_ltssm_enable
    ,input [2:0]                        pm_current_data_rate       // current_data_rate shadowed in pm_ctrl
    ,input                              pm_smlh_entry_to_l0s
    ,input                              pm_smlh_entry_to_l1
    ,input                              pm_smlh_entry_to_l2
    ,input                              pm_smlh_prepare4_l123
    ,input                              pm_smlh_l0s_exit
    ,input                              pm_smlh_l1_exit
    ,input                              pm_smlh_l23_exit
    ,input                              pm_xdlh_enter_l1
    ,input                              pm_xdlh_req_ack
    ,input                              pm_xdlh_enter_l23
    ,input                              pm_xdlh_actst_req_l1
    ,input                              pm_freeze_fc_timer
    // Adding in a freeze completion timer control per PM module's request
    ,input                              pm_freeze_cpl_timer
    ,input                              pm_xmt_asnak
    ,input                              pm_xmt_turnoff
    ,input [NF-1:0]                     pm_xmt_to_ack
    ,input [NF-1:0]                     pm_xmt_pme
    ,input                              pm_turnoff_timeout
    ,input [BUSNUM_WD -1:0]             pm_bus_num
    ,input [DEVNUM_WD -1:0]             pm_dev_num
    ,input [(PDWN_WIDTH - 1) : 0]       pm_int_phy_powerdown
    ,input [(PM_MST_WD - 1):0]          pm_master_state
    ,input [(PM_SLV_WD - 1):0]          pm_slave_state
    ,input [NL-1:0]                     int_phy_txelecidle
    ,input [NL-1:0]                     sqlchd_rxelecidle
    ,input                              pm_sys_aux_pwr_det
    ,input                              pm_dbi_cs
    ,input [NF-1:0]                     pm_pme_en_split
    ,input [NF-1:0]                     pm_aux_pm_en_split
    ,input                              pm_init_rst
    ,input                              pm_unlock_msg_req
    ,input [L2NL - 1 : 0]               pm_rx_lane_flip_en
    ,input [L2NL - 1 : 0]               pm_tx_lane_flip_en
    ,input [L2NL - 1 : 0]               pm_rx_pol_lane_flip_ctrl
    ,input                              pm_smlh_link_retrain
    ,input                              pm_l1_aspm_entr
    ,input                              pm_block_all_tlp
    ,input [NF-1:0]                     pm_radm_block_tlp

    ,input     [4:0]                  app_dev_num                   // Device number set by application
    ,input     [7:0]                  app_bus_num                   // Bus number    set by application
    ,output                           msg_gen_hv // header valid for message generation
    ,output                           lbc_cpl_hv // header valid for CPL
    ,input  [(2 * PDWN_WIDTH) - 1 : 0]            pm_powerdown_status
    ,output                                       cfg_force_powerdown
    ,output                                       cfg_uncor_internal_err_sts
    ,output                                       cfg_rcvr_overflow_err_sts
    ,output                                       cfg_fc_protocol_err_sts
    ,output                                       cfg_mlf_tlp_err_sts
    ,output                                       cfg_surprise_down_er_sts
    ,output                                       cfg_dl_protocol_err_sts
    ,output                                       cfg_ecrc_err_sts
    ,output                                       cfg_corrected_internal_err_sts
    ,output                                       cfg_replay_number_rollover_err_sts
    ,output                                       cfg_replay_timer_timeout_err_sts
    ,output                                       cfg_bad_dllp_err_sts
    ,output                                       cfg_bad_tlp_err_sts
    ,output                                       cfg_rcvr_err_sts   
    ,output [5:0]                                 cfg_link_capable

   ,input pm_current_powerdown_p1                  // Indicate mac phy powerdown is in P1
   ,input pm_current_powerdown_p0                  // Indicate mac phy powerdown is in P0
);
`ifndef SNPS_PCIE_SATB
 //Remove PCE Core code for Bridge Standalone simulation
// ------------------------------------------------------------------------------------------
// macros
// ------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------
// local parameters
// ------------------------------------------------------------------------------------------

localparam TX_DATAK_WD = NL * PHY_NB;
localparam TX_NDLLP    =  1;


// ------------------------------------------------------------------------------------------
// genvar declarations
// ------------------------------------------------------------------------------------------
genvar lane;  // used to instantiate per-lane logic
genvar func;  // used to instantiate per-function logic
genvar rx_tlp; // used to instantiate per-TLP logic

genvar j; //used for xali expansion
// ------------------------------------------------------------------------------------------
// Interface Signal Descriptions
// ------------------------------------------------------------------------------------------




    // ELBI interface

// completion timeout interface












wire      [(64*NF)-1:0]             cfg_bar0_mask;
wire      [(32*NF)-1:0]             cfg_bar1_mask;
wire      [(64*NF)-1:0]             cfg_bar2_mask;
wire      [(32*NF)-1:0]             cfg_bar3_mask;
wire      [(64*NF)-1:0]             cfg_bar4_mask;
wire      [(32*NF)-1:0]             cfg_bar5_mask;
wire      [(32*NF)-1:0]             cfg_rom_mask;

wire [4:0]                lpbk_lane_under_test;
// PIPE Loopback connections
logic [8*PHY_NB*NL-1:0]    lpbk_rxdata;
logic [PHY_NB*NL-1:0]      lpbk_rxdatak;
logic [NL-1:0]             lpbk_rxvalid;
logic [NL-1:0]             lpbk_rxelecidle;
logic [NL-1:0]             lpbk_rxdatavalid;
logic [NL*3-1:0]           lpbk_rxstatus;
logic [NL-1:0]             lpbk_phystatus;

// PIPE51 obsolete signals
logic [NL-1:0]  regif_phystatus, tmp_regif_phystatus;
always_comb begin
  regif_phystatus = lpbk_phystatus;
end


    

// ------------------------------------------------------------------------------------------
// Internal Signal declaration
// ------------------------------------------------------------------------------------------

wire                 cfg_pcie_slot_clk_config;    // connect to the same ref clock source
wire [1:0]           ltssm_cxl_ll_mod;            // low latency mode {driftbuffer, commonclock}




wire  [7:0]                      radm_trgt1_msgcode;

 wire   [(NVC_XALI_EXP*16)-1:0]         client0_req_id;                 // bus and dev number are set based on per function
 wire   [(NVC_XALI_EXP*16)-1:0]         client1_req_id;                 // bus and dev number are set based on per function

wire  [CPL_LUT_DEPTH-1:0]           radm_cpl_lut_valid;         // completion lookup table valid indication
wire                              xdlh_retry_req;                           // Puls : Retry Event



wire   [(NVC_XALI_EXP*DW_W_PAR)-1:0]client0_tlp_data_i                 ;
wire   [(NVC_XALI_EXP*PF_WD)-1:0]   client0_tlp_func_num_i             ;
wire   [NVC_XALI_EXP-1:0]           client0_addr_align_en_i            ;
wire   [(NVC_XALI_EXP*8)-1:0]       client0_tlp_byte_en_i              ;
wire   [(NVC_XALI_EXP*3)-1:0]       client0_cpl_status_i               ;
wire   [NVC_XALI_EXP-1:0]           client0_cpl_bcm_i                  ;
wire   [(NVC_XALI_EXP*16)-1:0]      client0_remote_req_id_i            ;
wire   [(NVC_XALI_EXP*12)-1:0]      client0_cpl_byte_cnt_i             ;
wire   [(NVC_XALI_EXP*3)-1:0]       client0_tlp_tc_i                   ;
wire   [(NVC_XALI_EXP*ATTR_WD)-1:0] client0_tlp_attr_i                 ;
wire   [NVC_XALI_EXP-1:0]           client0_tlp_dv_i                   ;
wire   [NVC_XALI_EXP-1:0]           client0_tlp_eot_i                  ;
wire   [NVC_XALI_EXP-1:0]           client0_tlp_bad_eot_i              ;
wire   [(NVC_XALI_EXP*16)-1:0]      client0_req_id_i                   ;
wire   [(NVC_XALI_EXP*2)-1:0]       client0_tlp_fmt_i                  ;
wire   [(NVC_XALI_EXP*5)-1:0]       client0_tlp_type_i                 ;
wire   [NVC_XALI_EXP-1:0]           client0_tlp_td_i                   ;
wire   [NVC_XALI_EXP-1:0]           client0_tlp_ep_i                   ;
wire   [(NVC_XALI_EXP*13)-1:0]      client0_tlp_byte_len_i             ;
wire   [(NVC_XALI_EXP*TAG_SIZE)-1:0]client0_tlp_tid_i                  ;
wire   [(NVC_XALI_EXP*64)-1:0]      client0_tlp_addr_i                 ;

wire   [NVC_XALI_EXP-1:0]           client1_addr_align_en_i            ;
wire   [(NVC_XALI_EXP*8)-1:0]       client1_tlp_byte_en_i              ;
wire   [(NVC_XALI_EXP*3)-1:0]       client1_cpl_status_i               ;
wire   [NVC_XALI_EXP-1:0]           client1_cpl_bcm_i                  ;
wire   [(NVC_XALI_EXP*16)-1:0]      client1_remote_req_id_i            ;
wire   [(NVC_XALI_EXP*12)-1:0]      client1_cpl_byte_cnt_i             ;
wire   [(NVC_XALI_EXP*3)-1:0]       client1_tlp_tc_i                   ;
wire   [(NVC_XALI_EXP*ATTR_WD)-1:0] client1_tlp_attr_i                 ;
wire   [NVC_XALI_EXP-1:0]           client1_tlp_dv_i                   ;
wire   [NVC_XALI_EXP-1:0]           client1_tlp_eot_i                  ;
wire   [NVC_XALI_EXP-1:0]           client1_tlp_bad_eot_i              ;
wire   [(NVC_XALI_EXP*16)-1:0]      client1_req_id_i                   ;
wire   [(NVC_XALI_EXP*2)-1:0]       client1_tlp_fmt_i                  ;
wire   [(NVC_XALI_EXP*5)-1:0]       client1_tlp_type_i                 ;
wire   [NVC_XALI_EXP-1:0]           client1_tlp_td_i                   ;
wire   [NVC_XALI_EXP-1:0]           client1_tlp_ep_i                   ;
wire   [(NVC_XALI_EXP*13)-1:0]      client1_tlp_byte_len_i             ;
wire   [(NVC_XALI_EXP*TAG_SIZE)-1:0]client1_tlp_tid_i                  ;
wire   [(NVC_XALI_EXP*64)-1:0]      client1_tlp_addr_i                 ;
wire   [(NVC_XALI_EXP*DW_W_PAR)-1:0]client1_tlp_data_i                 ;
wire   [(NVC_XALI_EXP*PF_WD)-1:0]   client1_tlp_func_num_i             ;


// START_IO:XALI0 Descriptions

wire   [NVC_XALI_EXP-1:0]         xadm_client0_halt_i                ;
wire [LOOKUPID_WD-1:0]             trgt_lookup_id_i                   ;

// END_IO:XALI0 Descriptions

// START_IO:XALI1 Descriptions



wire  [NVC_XALI_EXP-1:0]           xadm_client1_halt_i                ;


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
wire  [CPL_LUT_DEPTH-1:0]         radm_cpl_lut_valid_i                  ;


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
wire    [NHQ-1:0]                   radm_bypass_rom_in_range_i       ;
wire    [NHQ-1:0]                   radm_bypass_io_req_in_range_i    ;
wire    [NHQ*3-1:0]                 radm_bypass_in_membar_range_i    ;

wire  [NF-1:0]  cfg_auto_slot_pwr_lmt_dis; // Auto Slot Power Limit Disable field of Slot Control Register; hardwired to 0 if DPC is not configured.


// -------------------------------------------------------------------------------------
// XADM/RADM interconnect signals.

// The following signals are not used in DMA.


// Assignments valid for Core only, Core+AMBA, Core+AMBA+DMA configurations

assign client0_tlp_dv_i           =   client0_tlp_dv                  ;
assign client0_tlp_eot_i          =   client0_tlp_eot                 ;
assign client0_tlp_bad_eot_i      =   client0_tlp_bad_eot             ;
assign client0_tlp_data_i         =   client0_tlp_data                ;
// assign client0_tlp_func_num_i     =   client0_tlp_func_num            ;

// `ifdef CX_SRIOV_ENABLE
//assign client0_tlp_vfunc_num_i    =   client0_tlp_vfunc_num           ;
//assign client0_tlp_vfunc_active_i =   client0_tlp_vfunc_active        ;
// `endif // CX_SRIOV_ENABLE
// `ifdef CX_TPH_ENABLE
//  `ifdef AMBA_POPULATED
//    `ifdef CC_DMA_ENABLE
// assign client0_tlp_th_i             = client0_tlp_th                  ;
// assign client0_tlp_ph_i             = client0_tlp_ph                  ;
// assign client0_tlp_st_i             = client0_tlp_st                  ;
//    `endif // CC_DMA_ENABLE
//  `else // !AMBA_POPULATED
// assign client0_tlp_th_i             = client0_tlp_th                  ;
// assign client0_tlp_ph_i             = client0_tlp_ph                  ;
// assign client0_tlp_st_i             = client0_tlp_st                  ;
//  `endif // AMBA_POPULATED
// `endif // CX_TPH_ENABLE
assign xadm_client0_halt          =   xadm_client0_halt_i             ;

assign client1_tlp_dv_i           =   client1_tlp_dv                  ;
assign client1_tlp_eot_i          =   client1_tlp_eot                 ;
assign client1_tlp_bad_eot_i      =   client1_tlp_bad_eot             ;
assign client1_tlp_data_i         =   client1_tlp_data                ;

assign  xadm_client1_halt         =   xadm_client1_halt_i             ;
assign radm_trgt1_hv                =  radm_trgt1_hv_i                       ;
assign radm_trgt1_dv                =  radm_trgt1_dv_i                       ;
assign radm_trgt1_eot               =  radm_trgt1_eot_i                      ;
assign radm_trgt1_tlp_abort         =  radm_trgt1_tlp_abort_i                ;
assign radm_trgt1_dllp_abort        =  radm_trgt1_dllp_abort_i               ;
assign radm_trgt1_ecrc_err          =  radm_trgt1_ecrc_err_i                 ;
assign radm_trgt1_data              =  radm_trgt1_data_i                     ;
assign radm_trgt1_dwen              =  radm_trgt1_dwen_i                     ;
assign radm_trgt1_fmt               =  radm_trgt1_fmt_i                      ;
assign radm_trgt1_type              =  radm_trgt1_type_i                     ;
assign radm_trgt1_tc                =  radm_trgt1_tc_i                       ;
assign radm_trgt1_attr              =  radm_trgt1_attr_i                     ;
assign radm_trgt1_reqid             =  radm_trgt1_reqid_i                    ;
assign radm_trgt1_tag               =  radm_trgt1_tag_i                      ;
assign radm_trgt1_func_num          =  radm_trgt1_func_num_i                 ;
assign radm_trgt1_td                =  radm_trgt1_td_i                       ;
assign radm_trgt1_poisoned          =  radm_trgt1_poisoned_i                 ;
assign radm_trgt1_dw_len            =  radm_trgt1_dw_len_i                   ;
assign radm_trgt1_first_be          =  radm_trgt1_first_be_i                 ;
assign radm_trgt1_last_be           =  radm_trgt1_last_be_i                  ;
assign radm_trgt1_addr              =  radm_trgt1_addr_i                     ;
assign radm_trgt1_io_req_in_range   =  radm_trgt1_io_req_in_range_i          ;
assign radm_trgt1_rom_in_range      =  radm_trgt1_rom_in_range_i             ;
assign radm_trgt1_in_membar_range   =  radm_trgt1_in_membar_range_i          ;
assign radm_trgt1_cpl_status        =  radm_trgt1_cpl_status_i               ;
assign radm_trgt1_hdr_uppr_bytes    =  radm_trgt1_hdr_uppr_bytes_i           ;
assign radm_trgt1_bcm               =  radm_trgt1_bcm_i                      ;
assign radm_trgt1_cpl_last          =  radm_trgt1_cpl_last_i                 ;
assign radm_trgt1_byte_cnt          =  radm_trgt1_byte_cnt_i                 ;
assign radm_trgt1_cmpltr_id         =  radm_trgt1_cmpltr_id_i                ;

assign radm_cpl_timeout          =  radm_cpl_timeout_i                      ;
assign radm_timeout_cpl_tc       =  radm_timeout_cpl_tc_i                   ;
assign radm_timeout_cpl_attr     =  radm_timeout_cpl_attr_i                 ;
assign radm_timeout_cpl_len      =  radm_timeout_cpl_len_i                  ;
assign radm_timeout_cpl_tag      =  radm_timeout_cpl_tag_i                  ;
assign radm_timeout_func_num     =  radm_timeout_func_num_i                 ;


assign radm_bypass_data              =   radm_bypass_data_i               ;
assign radm_bypass_dwen              =   radm_bypass_dwen_i               ;
assign radm_bypass_dv                =   radm_bypass_dv_i                 ;
assign radm_bypass_hv                =   radm_bypass_hv_i                 ;
assign radm_bypass_eot               =   radm_bypass_eot_i                ;
assign radm_bypass_dllp_abort        =   radm_bypass_dllp_abort_i         ;
assign radm_bypass_tlp_abort         =   radm_bypass_tlp_abort_i          ;
assign radm_bypass_ecrc_err          =   radm_bypass_ecrc_err_i           ;
assign radm_bypass_bcm               =   radm_bypass_bcm_i                ;
assign radm_bypass_cpl_last          =   radm_bypass_cpl_last_i           ;
assign radm_bypass_cpl_status        =   radm_bypass_cpl_status_i         ;
assign radm_bypass_byte_cnt          =   radm_bypass_byte_cnt_i           ;
assign radm_bypass_cmpltr_id         =   radm_bypass_cmpltr_id_i          ;
assign radm_bypass_fmt               =   radm_bypass_fmt_i                ;
assign radm_bypass_type              =   radm_bypass_type_i               ;
assign radm_bypass_tc                =   radm_bypass_tc_i                 ;
assign radm_bypass_attr              =   radm_bypass_attr_i               ;
assign radm_bypass_reqid             =   radm_bypass_reqid_i              ;
assign radm_bypass_tag               =   radm_bypass_tag_i                ;
assign radm_bypass_func_num          =   radm_bypass_func_num_i           ;
assign radm_bypass_td                =   radm_bypass_td_i                 ;
assign radm_bypass_poisoned          =   radm_bypass_poisoned_i           ;
assign radm_bypass_dw_len            =   radm_bypass_dw_len_i             ;
assign radm_bypass_first_be          =   radm_bypass_first_be_i           ;
assign radm_bypass_last_be           =   radm_bypass_last_be_i            ;
assign radm_bypass_addr              =   radm_bypass_addr_i               ;
assign radm_bypass_rom_in_range      =   radm_bypass_rom_in_range_i       ;
assign radm_bypass_io_req_in_range   =   radm_bypass_io_req_in_range_i    ;
assign radm_bypass_in_membar_range   =   radm_bypass_in_membar_range_i    ;



assign radm_cpl_lut_valid         =   radm_cpl_lut_valid_i            ;



wire [1:0] tmp_ltssm_powerdown, tmp_xmlh_powerdown;
wire [1:0] int_ltssm_powerdown, int_xmlh_powerdown;
wire [2:0] tmp_int_mac_phy_rate;

wire    [NL-1:0]                  laneflip_no_turnoff_lanes          ;
wire                              cfg_nond0_vdm_block;
wire                              cfg_client0_block_new_tlp;
wire                              cfg_client1_block_new_tlp;
wire                              cfg_client2_block_new_tlp;


wire    [(NVC*3)-1:0]             trgt_lut_trgt1_radm_pkt_halt;   // Xadm ->Multiplexor
wire    [(NVC*3)-1:0]             trgt_lut_trgt1_radm_pkt_halt_i; // Masked trgt_lut_trgt1_radm_pkt_halt
wire    [(NVC*3)-1:0]             bridge_trgt1_radm_pkt_halt_i;   // Masked bridge_trgt1_radm_pkt_halt
wire    [(NVC*3)-1:0]             trgt1_radm_pkt_halt_i; // If CXS is enabled packet halt for CCIX VC is driven internally by CXS top

genvar  g_i;
generate
  for (g_i=0 ; g_i<NVC ; g_i=g_i+1 ) begin : gen_radm_grant_tlp_type
     assign radm_grant_tlp_type_i[3*g_i +: 3] =
                                                radm_grant_tlp_type[3*g_i +: 3];
     assign bridge_trgt1_radm_pkt_halt_i[3*g_i +: 3] =
                                                       bridge_trgt1_radm_pkt_halt[3*g_i +: 3];
     assign trgt_lut_trgt1_radm_pkt_halt_i[3*g_i +: 3] =
                                                         trgt_lut_trgt1_radm_pkt_halt[3*g_i +: 3];
     assign trgt1_radm_pkt_halt_i[3*g_i +: 3] =
                                                       trgt1_radm_pkt_halt[3*g_i +: 3];
  end
endgenerate

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


assign client0_tlp_func_num_i     =   client0_tlp_func_num            ;
assign client0_addr_align_en_i    =   client0_addr_align_en           ;
assign client0_tlp_byte_en_i      =   client0_tlp_byte_en             ;
assign client0_cpl_status_i       =   client0_cpl_status              ;
assign client0_cpl_bcm_i          =   client0_cpl_bcm                 ;
assign client0_remote_req_id_i    =   client0_remote_req_id           ;
assign client0_cpl_byte_cnt_i     =   client0_cpl_byte_cnt            ;
assign client0_tlp_tc_i           =   client0_tlp_tc                  ;
assign client0_tlp_attr_i         =   client0_tlp_attr                ;
assign client0_tlp_fmt_i          =   client0_tlp_fmt                 ;
assign client0_tlp_type_i         =   client0_tlp_type                ;
assign client0_tlp_td_i           =   client0_tlp_td                  ;
assign client0_tlp_ep_i           =   client0_tlp_ep                  ;
assign client0_tlp_byte_len_i     =   client0_tlp_byte_len            ;
assign client0_tlp_tid_i          =   client0_tlp_tid                 ;
assign client0_tlp_addr_i         =   client0_tlp_addr                ;
assign client0_req_id_i           =   client0_req_id                  ;

assign client1_addr_align_en_i    =   client1_addr_align_en           ;
assign client1_tlp_byte_en_i      =   client1_tlp_byte_en             ;
assign client1_cpl_status_i       =   client1_cpl_status              ;
assign client1_cpl_bcm_i          =   client1_cpl_bcm                 ;
assign client1_remote_req_id_i    =   client1_remote_req_id           ;
assign client1_cpl_byte_cnt_i     =   client1_cpl_byte_cnt            ;
assign client1_tlp_tc_i           =   client1_tlp_tc                  ;
assign client1_tlp_attr_i         =   client1_tlp_attr                ;
assign client1_tlp_fmt_i          =   client1_tlp_fmt                 ;
assign client1_tlp_type_i         =   client1_tlp_type                ;
assign client1_tlp_td_i           =   client1_tlp_td                  ;
assign client1_tlp_ep_i           =   client1_tlp_ep                  ;
assign client1_tlp_byte_len_i     =   client1_tlp_byte_len            ;
assign client1_tlp_tid_i          =   client1_tlp_tid                 ;
assign client1_tlp_addr_i         =   client1_tlp_addr                ;
assign client1_req_id_i           =   client1_req_id                  ;
assign client1_tlp_func_num_i     =   client1_tlp_func_num            ;



//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


wire                                phy_type;
assign phy_type = `CX_PHY_TYPE;

wire    [1:0]                       rdlh_dlcntrl_state;
wire                                xadm_msg_halt;
wire                                cfg_elastic_buffer_mode_i;
// if Gen1/2 rate, always half full mode. if Gen3/4 rate, use regsiter bit cfg_elastic_buffer_mode_i
//assign                              cfg_elastic_buffer_mode = `ifdef CX_GEN3_SPEED (mac_phy_rate == `GEN3_RATE || mac_phy_rate == `GEN4_RATE) ? cfg_elastic_buffer_mode_i : `endif 1'b0;
assign                              cfg_elastic_buffer_mode = cfg_elastic_buffer_mode_i;

wire    [NL*3-1:0]                  tmp_mac_phy_rate_bus;           // 1=change speed to gen2, 2-gen3, 0-gen1, internal use
wire    [2:0]                       tmp_mac_phy_rate;               // 1=change speed to gen2, 2-gen3, 0-gen1, internal use

//wire    [NL-1:0]                    mac_phy_txelecidle;

wire    [NL-1:0]                    pre_mac_phy_txcompliance;
wire                                ltssm_all_detect_quiet;
reg     [5:0]                       ltssm_d;
wire                                dis_to_pre_detect_pulse;
reg                                 latched_dis_to_pre_detect;
wire                                pre_detect_from_disabled;
reg     [NL-1:0]                    latched_mac_phy_txcompliance;
wire    [WIDTH_WIDTH-1:0]           adapted_pipe_mac_phy_width;
wire    [P_R_WD-1:0]                adapted_pipe_mac_phy_pclk_rate;
wire    [(NL*NB*8)-1:0]             int_phy_mac_rxdata;
wire    [NL*NB-1 :0]                int_phy_mac_rxdatak;
wire    [NL-1:0]                    int_phy_mac_rxvalid;
wire    [NL-1:0]                    int_phy_mac_rxelecidle;
wire    [(NL*3)-1:0]                int_phy_mac_rxstatus;           // Encoders receiver status and error codes for the received
wire    [NL-1:0]                    int_phy_mac_phystatus;          // Used to communicate completion of several PHY functions
wire    [NL-1:0]                    int_phy_mac_rxstandbystatus;
wire    [(NL*NB*8)-1:0]             tmp_phy_mac_rxdata;
wire    [NL*NB-1 :0]                tmp_phy_mac_rxdatak;
wire    [NL-1:0]                    tmp_phy_mac_rxvalid;
wire    [NL-1:0]                    tmp_phy_mac_rxelecidle;
wire    [(NL*3)-1:0]                tmp_phy_mac_rxstatus;
wire    [NL-1:0]                    tmp_phy_mac_phystatus;
wire    [NL-1:0]                    tmp_phy_mac_rxstandbystatus;
wire    [(NL*NB*8)-1:0]             in_cxpl_phy_mac_rxdata;
wire    [NL*NB-1 :0]                in_cxpl_phy_mac_rxdatak;
wire    [NL-1:0]                    in_cxpl_phy_mac_rxvalid;
wire    [NL-1:0]                    in_cxpl_phy_mac_rxelecidle;
wire    [(NL*3)-1:0]                in_cxpl_phy_mac_rxstatus;
wire    [NL-1:0]                    in_cxpl_phy_mac_phystatus;
wire    [(NL*ORIG_DATA_WD)-1:0]     orig_pipe_rxdata;
wire    [(NL*PHY_NB)-1:0]           orig_pipe_rxdatak;
wire    [NL-1:0]                    orig_pipe_rxvalid;
wire    [NL-1:0]                    orig_pipe_rxdatavalid;
wire    [(NL*3)-1:0]                orig_pipe_rxstatus;
wire                                xadm_xtlh_hv;                   // hdr valid on bus when asserted
wire    [1:0]                       xadm_xtlh_soh;                  // Indicates start of header loacation for 32/64-bit
wire    [TX_HW_W_PAR-1:0]           xadm_xtlh_hdr;                  // hdr bus from XadM
wire                                xadm_xtlh_dv;                   // data valid on bus when asserted
wire    [DW_W_PAR-1:0]              xadm_xtlh_data;                 // data bus from XadM
wire    [NW-1:0]                    xadm_xtlh_dwen;                 // data bus dword enable
wire    [8:0]                       cfg_lane_en;                    // pre-determined number of lanes
wire                                cfg_gen1_ei_inference_mode;     // EI inference mode for Gen1. default 0 - using rxelecidle==1; 1 - using rxvalid==0
wire    [1:0]                       cfg_select_deemph_mux_bus;      // sel deemphasis {bit, var}
wire    [`CX_LUT_PL_WD-1:0]         cfg_lut_ctrl;                   // lane under test + gen5 control
wire                                lut_en;                         // lut enable
wire    [5:0]                       lut_ctrl;                       // {cfg_force_lane_flip, lut_en, lut}
wire                                cfg_force_lane_flip, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts;
wire    [3:0]                       cfg_lane_under_test;
wire    [6:0]                       cfg_rxstandby_control;          // Rxstandby Control
wire                                smlh_bw_mgt_status;             // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                                    // without the port transitioning through DL_Down status
wire                                smlh_link_auto_bw_status;       // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
                                                                    // DL_Down status, for reasons other than to attempt to correct unreliable link operation.

wire                                smlh_dir_linkw_chg_rising_edge;    // clear cfg_directed_link_width_change
wire                                smlh_ltssm_in_hotrst_dis_entry;

wire                                xadm_xtlh_eot;                  // end of transaction
wire                                xadm_xtlh_bad_eot;              // poison the data
wire                                xadm_xtlh_add_ecrc;
wire    [2:0]                       xadm_xtlh_vc;
wire    [NL-1:0]                    tmp_ltssm_txelecidle;
reg     [NL-1:0]                    int_ltssm_txelecidle;
wire    [NL-1:0]                    int_ltssm_txelecidle_i;
wire    [NL-1:0]                    fstep_mac_phy_txelecidle;
wire    [NL-1:0]                    int_mac_phy_txcompliance_i;
reg     [NL-1:0]                    int_mac_phy_txcompliance_r;
wire    [1:0]                       xmlh_powerdown;

wire    [(NL*NB*8)-1:0]             int_mac_phy_txdata;
wire    [(NL*NB)-1:0]               int_mac_phy_txdatak;
reg     [NL-1:0]                    int_mac_phy_txcompliance;
wire    [NL-1:0]                    int_mac_phy_rxpolarity;
wire    [NL-1:0]                    int_mac_phy_rxstandby;
wire    [2:0]                       int_mac_phy_rate;               // 1=change speed to gen2, 2-gen3
wire    [NL-1:0]                    int_mac_phy_txdetectrx_loopback;// Enable receiver detection sequence.  SerDes transmits
wire    [(NL*NB*8)-1:0]             tmp_mac_phy_txdata;
wire    [(NL*NB)-1:0]               tmp_mac_phy_txdatak;
wire    [NL-1:0]                    int_phy_mac_rxdatavalid;
wire    [NL-1:0]                    tmp_phy_mac_rxdatavalid;
wire    [(NL*PHY_NB*8)-1:0]         fstep_mac_phy_txdata;
wire    [NL-1:0]                    fstep_mac_phy_txdetectrx_loopback;
wire    [NL-1:0]                    int_pipe_turnoff = int_ltssm_txelecidle & int_mac_phy_txcompliance;

wire [1:0]             core_int_mac_phy_txdeemph;
wire [NL-1:0]          lpbk_rxdatavalid_i;

wire [(PDWN_WIDTH - 1) : 0] adapted_pipe_mac_phy_powerdown;

wire    [NL-1:0]                    tmp_mac_phy_txcompliance;
wire    [NL-1:0]                    tmp_mac_phy_rxstandby;
wire    [NL-1:0]                    smlh_rcvd_eidle_rxstandby;
wire    [NL-1:0]                    laneflip_lanes_active;
wire    [NL-1:0]                    laneflip_rcvd_eidle_rxstandby;
wire    [NL-1:0]                    power_saving_laneflip_lanes_active;
wire    [NL-1:0]                    tmp_mac_phy_txdetectrx_loopback;// Enable receiver detection sequence.  SerDes transmits

wire                                rdlh_link_down;
wire    [DW_W_PAR-1:0]              rtlh_radm_data;                 // Packet data
wire    [RX_TLP*(128+RAS_PCIE_HDR_PROT_WD)-1:0] rtlh_radm_hdr;        // hdr data
wire    [NW-1:0]                    rtlh_radm_dwen;                 // Packet data dword enable
wire    [RX_TLP-1:0]                rtlh_radm_dv;                   // data is valid this cycle
wire    [RX_TLP-1:0]                rtlh_radm_hv;                   // hdr is valid this cycle
wire    [RX_TLP-1:0]                rtlh_radm_eot;                  // EOT indication
wire    [RX_TLP-1:0]                rtlh_radm_dllp_err;
wire    [RX_TLP-1:0]                rtlh_radm_ecrc_err;
wire    [RX_TLP-1:0]                rtlh_radm_malform_tlp_err;
wire    [(RX_TLP*64)-1:0]           rtlh_radm_ant_addr;
wire    [(RX_TLP*16)-1:0]           rtlh_radm_ant_rid;
wire                                rtlh_radm_pending;
wire                                xtlh_xadm_restore_enable;
wire                                xtlh_xadm_restore_capture;
wire    [2:0]                       xtlh_xadm_restore_tc;
wire    [6:0]                       xtlh_xadm_restore_type;
wire    [9:0]                       xtlh_xadm_restore_word_len;


// cfg newly added signals

wire    [7:0]                       rtfcgen_ph_diff;

wire                                lbc_cpl_dv;
wire                                lbc_cpl_eot;
wire    [DW_W_PAR-1:0]              lbc_cpl_data;
wire    [LBC_MSG_HDR_WD-1:0]        lbc_cpl_hdr;
//DE:Deadlock Fix
wire                                lbc_deadlock_det;

wire                                msg_gen_dv;
wire                                msg_gen_eot;
wire    [DW_W_PAR-1:0]              msg_gen_data;
wire    [LBC_MSG_HDR_WD-1:0]        msg_gen_hdr;
wire    [TRGT_DATA_WD-1:0]          radm_trgt0_data;
wire    [NW-1:0]                    radm_trgt0_dwen;
wire    [TRGT_HDR_WD-1:0]           radm_trgt0_hdr;
wire                                radm_trgt0_eot;
wire                                radm_trgt0_dv;
wire                                radm_trgt0_hv;
wire                                radm_trgt0_abort;
wire                                xtlh_xmt_tlp_done;
wire                                xtlh_xmt_tlp_done_early;
wire    [15 :0]                     xtlh_xmt_tlp_req_id;
wire    [TAG_SIZE-1:0]              xtlh_xmt_tlp_tag;
wire    [1:0]                       xtlh_xmt_tlp_attr;
wire    [2:0]                       xtlh_xmt_tlp_tc;
wire    [11:0]                      xtlh_xmt_tlp_len_inbytes;
wire    [3:0]                       xtlh_xmt_tlp_first_be;

wire                                xtlh_xmt_cfg_req;
wire                                xtlh_xmt_memrd_req;
wire                                xtlh_xmt_ats_req;
wire                                xtlh_xmt_atomic_req;

// Local bus controller interface
wire    [31:0]                      lbc_cdm_addr;
wire    [31:0]                      lbc_cdm_data;
wire    [3:0]                       lbc_cdm_wr;

wire    [NVC-1:0]                   int_rtlh_ph_ca;                 // Credit allocated (posted header)
wire    [NVC-1:0]                   int_rtlh_pd_ca;                 // Credit allocated (posted data)
wire    [NVC-1:0]                   int_rtlh_nph_ca;                // Credit allocated (non-posted header)
wire    [NVC-1:0]                   int_rtlh_npd_ca;                // Credit allocated (non-posted data)
wire    [NVC-1:0]                   int_rtlh_cplh_ca;               // Credit allocated (completion header)
wire    [NVC-1:0]                   int_rtlh_cpld_ca;               // Credit allocated (completion data)



// From  RADM queue
wire    [NVC-1:0]                   radm_rtlh_ph_ca;                // Credit allocated (posted header)
wire    [NVC-1:0]                   radm_rtlh_pd_ca;                // Credit allocated (posted data)
wire    [NVC-1:0]                   radm_rtlh_nph_ca;               // Credit allocated (non-posted header)
wire    [NVC-1:0]                   radm_rtlh_npd_ca;               // Credit allocated (non-posted data)
wire    [NVC-1:0]                   radm_rtlh_cplh_ca;              // Credit allocated (completion header)
wire    [NVC-1:0]                   radm_rtlh_cpld_ca;              // Credit allocated (completion data)

wire    [5:0]                       smlh_autoneg_link_width;
wire    [3:0]                       smlh_autoneg_link_sp;
wire                                smlh_link_training_in_prog;
wire    [NF-1:0]                    radm_cpl_pending;
wire    [31:0]                      radm_slot_pwr_payload;

wire    [NVC*HCRD_WD-1:0]           xadm_ph_cdts;                   // header for P credits
wire    [NVC*DCRD_WD-1:0]           xadm_pd_cdts;                   // data for P credits
wire    [NVC*HCRD_WD-1:0]           xadm_nph_cdts;                  // header for NPR credits
wire    [NVC*DCRD_WD-1:0]           xadm_npd_cdts;                  // data for NPR credits
wire    [NVC*HCRD_WD-1:0]           xadm_cplh_cdts;                 // header for cPL credits
wire    [NVC*DCRD_WD-1:0]           xadm_cpld_cdts;                 // data for cPL credits
wire    [NL-1:0]                    smlh_lanes_active;              // active lanes
wire    [NL-1:0]                    smlh_no_turnoff_lanes;          // upconfigure lanes
wire                                smlh_ltssm_in_config;           // LTSSM is in configuration state


// declaration for multi-func purpose
//  input signals of cdm
// -----------------------------------------------------------------------------
wire    [NF-1:0]                    xtlh_xmt_cpl_ca;
wire    [NF-1:0]                    xtlh_xmt_cpl_ur;
wire    [NF-1:0]                    xtlh_xmt_wreq_poisoned;
wire    [NF-1:0]                    xtlh_xmt_cpl_poisoned;
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_wreq_poisoned;

wire    [(FX_TLP*NF)-1:0]           radm_mlf_tlp_err;
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_cpl_poisoned;
wire    [(FX_TLP*NF)-1:0]           radm_ecrc_err;
wire    [(FX_TLP*NF)-1:0]           radm_hdr_log_valid;
wire    [(FX_TLP*128)-1:0]          radm_hdr_log;
wire    [NF-1:0]                    rtlh_overfl_err_nf;
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_cpl_ur;

wire    [(FX_TLP*NF)-1:0]           radm_rcvd_cpl_ca;
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_req_ur;
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_req_ca;
wire    [(FX_TLP*NF)-1:0]           radm_unexp_cpl_err;
wire    [FX_TLP-1:0]                cdm_err_advisory;

wire                                cfg_clk_pm_en_tmp;
assign cfg_clk_pm_en = cfg_clk_pm_en_tmp;

// declaration for multi-func purpose
//  output signals of cdm
// ----------------------------------------------------------------------------

wire    [(32*NF)-1:0]               cdm_lbc_data;
wire    [NF-1:0]                    cdm_lbc_ack;
wire    [NF-1:0]                    lbc_cdm_cs;



wire    [NF-1:0]                    cfg_ext_tag_en;
wire                                cfg_comm_clk_config;
wire                                cfg_hw_autowidth_dis;
wire    [2:0]                       cfg_highest_max_payload;
wire    [7:0]                       cfg_ack_freq;
wire    [15:0]                      cfg_ack_latency_timer;
wire    [16:0]                      cfg_replay_timer_value;
wire    [12:0]                      cfg_fc_latency_value;
wire    [31:0]                      cfg_other_msg_payload;
wire                                cfg_other_msg_request;
wire    [31:0]                      cfg_corrupt_crc_pattern;
wire                                cfg_scramble_dis;
wire    [7:0]                       cfg_n_fts;
wire    [7:0]                       cfg_link_num;
wire                                cfg_ts2_lid_deskew;
wire                                cfg_support_part_lanes_rxei_exit;
wire                                cfg_pipe_loopback;
wire    [5:0]                       cfg_rxstatus_lane;          // Lane to inject rxstatus value(bit6 = all lanes)
wire    [2:0]                       cfg_rxstatus_value;         // rxstatus value to inject
wire    [NL-1:0]                    cfg_lpbk_rxvalid;           // rxvalid value to use during loopback
wire                                cfg_reset_assert;
wire                                cfg_force_en;
wire    [5:0]                       cfg_forced_link_state;
wire    [3:0]                       cfg_forced_ltssm_cmd;

wire    [23:0]                      cfg_lane_skew;
wire                                cfg_flow_control_disable;       // disable the automatic flowcontrol built in this core
wire                                cfg_acknack_disable;
wire                                cfg_deskew_disable;
wire    [3:0]                       cfg_imp_num_lanes;
wire                                cfg_fast_link_mode;
wire    [1:0]                       cfg_fast_link_scaling_factor;
wire                                cfg_l0s_supported;
wire                                diag_fast_link_mode;
wire                                int_cfg_fast_link_mode;
assign                              cfg_fast_link_mode = int_cfg_fast_link_mode;
wire    [NF-1:0]                    cfg_ecrc_chk_en;
wire    [10:0]                      cfg_skip_interval;              // skip interval
wire    [1:0]                       cfg_retimers_pre_detected;

wire                                cfg_dll_lnk_en;
wire    [NF-1:0]                    cfg_ecrc_gen_en;
wire    [(16*NF)-1:0]               cfg_io_limit_upper16;
wire    [(16*NF)-1:0]               cfg_io_base_upper16;
wire    [(8*NF)-1:0]                cfg_io_limit;
wire    [(8*NF)-1:0]                cfg_io_base;
wire    [NF-1:0]                    cfg_io_space_en;
wire                                cfg_ext_synch;
wire                                end_device;
wire                                rc_device;
wire                                bridge_device;
wire    [NF-1:0]                    cfg_cpl_timeout_disable;
wire    [NF-1:0]                    cfg_adv_cor_err_int;
wire    [NF-1:0]                    cfg_adv_nf_err_int;
wire    [NF-1:0]                    cfg_adv_f_err_int;





wire    [NF-1:0]                    cfg_slot_pwr_limit_wr;
wire    [(64*NF)-1:0]               cfg_msi_addr;
wire    [(32*NF)-1:0]               cfg_msi_data;
wire    [NF-1:0]                    cfg_msi_64;
wire    [63:0]                      msix_addr;
wire    [31:0]                      msix_data;
wire    [NF-1:0]                    cfg_msix_en;
wire                                cfg_pipe_garbage_data_mode;
wire    [(3*NF)-1:0]                cfg_multi_msi_en;
wire    [NF-1:0]                    cfg_msi_ext_data_en;
wire    [NF-1:0]                    cfg_msix_func_mask;

wire    [7:0]                       cfg_slot_pwr_limit_val;
wire    [1:0]                       cfg_slot_pwr_limit_scale;
wire    [(3*NF)-1:0]                cfg_func_spec_err;
wire    [PF_WD-1:0]                 cfg_max_func_num;

// -----------------------------------------------------------------------------

wire    [NVC-1:0]                   rtlh_crd_not_rtn;
wire    [(FX_TLP*64)-1:0]           flt_cdm_addr;
wire                                flt_cdm_rtlh_radm_pending;

wire    [(FX_TLP*NF)-1:0]           cfg_io_match;
wire    [(FX_TLP*NF)-1:0]           cfg_config_above_match;
wire    [(FX_TLP*NF)-1:0]           cfg_rom_match;
wire    [(FX_TLP*NF*6)-1:0]         cfg_bar_match;
wire    [(FX_TLP*NF)-1:0]           cfg_prefmem_match;
wire    [(FX_TLP*NF)-1:0]           cfg_mem_match;
wire    [(NF*6)-1:0]                cfg_bar_is_io;
wire                                cfg_alt_protocol_enable;
wire                                smlh_mod_ts_rcvd;
wire  [55:0]                        mod_ts_data_rcvd;   // {info2[23:0], vendor_id[15:0], info1[15:5], ap_negotiation[1:0], mod_ts_usage_mode[2:0]}
wire  [55:0]                        mod_ts_data_sent_i; // {info2[23:0], vendor_id[15:0], info1[15:5], ap_negotiation[1:0], mod_ts_usage_mode[2:0]}
wire  [55:0]                        mod_ts_data_sent = (smlh_ltssm_state == `S_CFG_COMPLETE) ? mod_ts_data_sent_i : 56'h0;

wire    [N_FLT_MASK-1:0]            cfg_filter_rule_mask;

wire                                cfg_fc_wdog_disable;

wire                                xtlh_xadm_halt;
wire                                xadm_cpl_halt;
wire                                xadm_all_type_infinite;
wire    [3*NVC-1:0]                 trgt0_radm_halt;
wire                                radm_slot_pwr_limit;
wire                                lbc_cdm_dbi;
wire                                lbc_cdm_dbi2;
assign lbc_ext_dbi_access       = lbc_cdm_dbi & (|lbc_ext_cs);

wire    [NF-1:0]                    lbc_xmt_cpl_ca;
wire                                rmlh_rcvd_err;
wire    [NVC-1:0]                   rtlh_fc_init_status;
wire                                rdlh_prot_err;
wire                                rdlh_bad_tlp_err;
wire                                rdlh_bad_dllp_err;
wire                                xdlh_replay_num_rlover_err;
wire                                xdlh_replay_timeout_err;
wire                                xdlh_retrybuf_not_empty;
wire                                xdlh_retryram_halt;
wire    [L2NL-1:0]                  ltssm_lane_flip_ctrl; //flip lanes without latched for gen3/4 enter polling.Compliance
wire                                rmlh_rcvd_eidle_set;
wire                                xtlh_data_parerr;
wire    [(NVC)-1:0]                 cfg_vc_enable;                  // Which VCs are enabled - VC0 is always enabled
wire    [(NVC*3)-1:0]               cfg_vc_struc_vc_id_map;         // VC Structure to VC ID mapping
wire    [23:0]                      cfg_vc_id_vc_struc_map;         // VC ID to VC Structure mapping
wire    [7:0]                       cfg_tc_enable;                  // Which TCs are enabled
wire    [23:0]                      cfg_tc_struc_vc_map;            // TC to VC Structure mapping
wire    [23:0]                      cfg_tc_vc_map;                  // TC to VC Structure mapping


// Retry buffer external RAM interface
// Depth of retry buffer
wire    [RBUF_PW -1:0]              retryram_xdlh_depth;
assign  retryram_xdlh_depth         = RBUF_DEPTH -1;                // this signal is defined to be the value of the top pointer of a RAM designed in our core

// Depth of retry buffer
wire    [SOTBUF_PW -1:0]            retrysotram_xdlh_depth;
assign  retrysotram_xdlh_depth      = SOTBUF_DP -1;                 // this signal is defined to be the value of the top pointer of a RAM designed in our core

wire                                radm_parerr;
wire                                rtlh_parerr;
wire                                xadm_parerr_detected;
wire    [(NF*6)-1:0]                target_mem_map;                 // Each bit of this vector indicates which target receives memory transactions for that bar #
wire    [ NF-1:0]                   target_rom_map;                 // Each bit of this vector indicates which target receives rom    transactions for that bar #
wire                                inta_wire;
wire                                intb_wire;
wire                                intc_wire;
wire                                intd_wire;
 


wire                                radm_snoop_upd;
wire    [7:0]                       radm_snoop_bus_num;
wire    [4:0]                       radm_snoop_dev_num;
wire                                rtlh_fc_prot_err;
assign rtlh_fc_prot_err = 1'b0;



wire    [16:0]                  xdlh_replay_timer;            // XDLH retry buffer replay timer it is routed to top-level to resolve multisim issues with hdl backdoor usage in VTB
wire    [11:0]                  xdlh_rbuf_pkt_cnt;            // XDLH packet counter it is routed to top-level to resolve multisim issues with hdl backdoor usage in VTB
// LTSSM timers routed to the top-level for verification usage
localparam T_WD = 25; // timer bit width
wire    [T_WD-1:0]              smlh_freq_multiplier;
wire    [T_WD-1:0]              smlh_fast_time_1ms;
wire    [T_WD-1:0]              smlh_fast_time_2ms;
wire    [T_WD-1:0]              smlh_fast_time_3ms;
wire    [T_WD-1:0]              smlh_fast_time_4ms;
wire    [T_WD-1:0]              smlh_fast_time_10ms;
wire    [T_WD-1:0]              smlh_fast_time_12ms;
wire    [T_WD-1:0]              smlh_fast_time_24ms;
wire    [T_WD-1:0]              smlh_fast_time_32ms;
wire    [T_WD-1:0]              smlh_fast_time_48ms;
wire    [T_WD-1:0]              smlh_fast_time_100ms;
wire                            ltssm_in_config = (smlh_ltssm_state == `S_CFG_LINKWD_START) |
                                                  (smlh_ltssm_state == `S_CFG_LINKWD_ACEPT) |
                                                  (smlh_ltssm_state == `S_CFG_LANENUM_WAIT) |
                                                  (smlh_ltssm_state == `S_CFG_LANENUM_ACEPT) |
                                                  (smlh_ltssm_state == `S_CFG_COMPLETE) |
                                                  (smlh_ltssm_state == `S_CFG_IDLE) ;
wire                            ltssm_in_lpbk   = (smlh_ltssm_state == `S_LPBK_ENTRY) ;

// spyglass disable_block W486
// SMD: Reports shift overflow operations
// SJ: Maximum value of CX_FAST_TIME_xxx is 21'h800. Overflow does not occur even if the value is shifted by 6 bits.
// de-reference LTSSM timeouts in fast link mode from cxpl_defs.vh
assign smlh_freq_multiplier = `CX_PL_FREQ_MULTIPLIER;
// Note: In ltssm_in_config state on USP for MAC=16s PHY=4s configs, 1ms is not enough to correctly decide Link width in simulation.
assign smlh_fast_time_1ms   = (cfg_fast_link_scaling_factor==2'b00) ? (ltssm_in_config || ltssm_in_lpbk) ? ((`CX_FAST_TIME_1MS << 1)) :  `CX_FAST_TIME_1MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_1MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_1MS << 4) :
                                                                      (`CX_FAST_TIME_1MS << 6) ;
// Note: In config state, 1us is not enough to correctly decide Link width in simulation.
assign smlh_fast_time_2ms   = (cfg_fast_link_scaling_factor==2'b00) ? (ltssm_in_config || ltssm_in_lpbk || smlh_ltssm_state == `S_L123_SEND_EIDLE) ? (`CX_FAST_TIME_2MS << 1) : `CX_FAST_TIME_2MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_2MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_2MS << 4) :
                                                                      (`CX_FAST_TIME_2MS << 6) ;
// Note: Generic PHY could take more than 2us for PHYSTATUS response for P1/P2 entry. Internal LTSSM timeout (2ms) in S_L123_SEND_EIDLE should be more than that.
// Note: In config state, 1us is not enough to correctly decide Link width in simulation. Need to extend 2ms timer as well.
assign smlh_fast_time_3ms   = (cfg_fast_link_scaling_factor==2'b00) ? (ltssm_in_config) ? (`CX_FAST_TIME_3MS << 1) : `CX_FAST_TIME_3MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_3MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_3MS << 4) :
                                                                      (`CX_FAST_TIME_3MS << 6) ;
// Note: In config state, 1us is not enough to correctly decide Link width in simulation. Need to extend 3ms timer as well.
assign smlh_fast_time_4ms   = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_4MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_4MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_4MS << 4) :
                                                                      (`CX_FAST_TIME_4MS << 6) ;
assign smlh_fast_time_10ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_10MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_10MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_10MS << 4) :
                                                                      (`CX_FAST_TIME_10MS << 6) ;
assign smlh_fast_time_12ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_12MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_12MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_12MS << 4) :
                                                                      (`CX_FAST_TIME_12MS << 6) ;
assign smlh_fast_time_24ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_24MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_24MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_24MS << 4) :
                                                                      (`CX_FAST_TIME_24MS << 6) ;
assign smlh_fast_time_32ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_32MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_32MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_32MS << 4) :
                                                                      (`CX_FAST_TIME_32MS << 6) ;
assign smlh_fast_time_48ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_48MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_48MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_48MS << 4) :
                                                                      (`CX_FAST_TIME_48MS << 6) ;
assign smlh_fast_time_100ms = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_100MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_100MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_100MS << 4) :
                                                                      (`CX_FAST_TIME_100MS << 6) ;
// spyglass enable_block W486


wire                                    default_target;
wire                                    cfg_cfg_tlp_bypass_en;
wire [9:0]                              cfg_config_limit;               
wire [1:0]                              cfg_target_above_config_limit;  
wire                                    cfg_p2p_track_cpl_to; 
wire                                    ur_ca_mask_4_trgt1;


//  MUX for CPCIE outputs
// ----------------------------------------------------------------------------


//  MUX for MPCIE outputs
// ----------------------------------------------------------------------------




// =============================================================================
// APP FLR pipeline signaling  

// =============================================================================
reg    [3:0]    int_device_type;                    // internal device type. (can be change when crosslink is enabled)

 always @(*)
         int_device_type            = device_type;

 // Insert register in path to avoid feedback path between RADM input
 // (device_type) and output (radm_byp_addr)

 reg  [3:0]      device_type_reg; // registered device_type
 always @(posedge core_clk or negedge core_rst_n)
     if(!core_rst_n)
         device_type_reg            <= #(`TP) `CX_DEVICE_TYPE;
     else
         device_type_reg            <= #(`TP) device_type;    // device_type_reg gets valid type one cycle after reset, but this is ok for RADM block.

assign  msix_addr = 64'd0;
assign  msix_data = 32'd0;

assign  cfg_reset_assert            = (cfg_2nd_reset & !upstream_port) | cfg_plreg_reset;  // two resets from CDM. One is for RC mode only, it is the secondary bridge reset, the other one is for debug PL register.


assign  int_cfg_pbus_num            = Bget(cfg_pbus_num, cfg_upd_req_id);
assign  int_cfg_pbus_dev_num        = Qget(cfg_pbus_dev_num, cfg_upd_req_id);

wire rtlh_overfl_err;
assign rtlh_overfl_err_nf = {NF{rtlh_overfl_err}};

 assign int_rtlh_ph_ca              = credit_mapping(radm_rtlh_ph_ca);
 assign int_rtlh_pd_ca              = radm_rtlh_pd_ca;
 assign int_rtlh_nph_ca             = credit_mapping(radm_rtlh_nph_ca);
 assign int_rtlh_npd_ca             = radm_rtlh_npd_ca;
 assign int_rtlh_cplh_ca            = credit_mapping(radm_rtlh_cplh_ca);
 assign int_rtlh_cpld_ca            = radm_rtlh_cpld_ca;

wire    [(NVC*8)-1:0]               cfg_fc_credit_ph;
wire    [(NVC*8)-1:0]               cfg_fc_credit_nph;
wire    [(NVC*8)-1:0]               cfg_fc_credit_cplh;
wire    [(NVC*12)-1:0]              cfg_fc_credit_pd;
wire    [(NVC*12)-1:0]              cfg_fc_credit_npd;
wire    [(NVC*12)-1:0]              cfg_fc_credit_cpld;             // (PL) Flow Control credits - Completion Data
wire    [(NVC*9)-1:0]               cfg_radm_q_mode;                // (PL) Queue Mode: CPL(BP/CT/SF), NP(BP/CT/SF), P(BP/CT/SF)
wire    [NVC-1:0]                   cfg_radm_order_rule;            // (PL) Order Selection: 0 - Strict Priority, 1 - Complies with Ordering Rule
wire    [15:0]                      cfg_order_rule_ctrl;            // cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC
wire                                cfg_radm_strict_vc_prior;       // (PL) VC Priority: 0 - Round Robin, 1 - Strict Priority
wire    [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0] cfg_hq_depths;          // (PL) Indicates the depth of the header queues per type per vc
wire    [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]cfg_dq_depths;          // (PL) Indicates the depth of the data queues per type per vc




wire    [31:0]                      cfg_trgt_cpl_lut_delete_entry;  // trgt_cpl_lut delete one entry
wire    [1:0]                       cfg_clock_gating_ctrl; // {axi_clk_gating_en, radm_clk_gating_en}

// for multifunction device, bus and dev number are based on per func.
// Here the request ID is the request ID of a transaction request and a completer's ID if it is a completion

 generate
 for (j=0; j < NVC_XALI_EXP; j = j+1) begin : client_req_id_dm_no_hdr_pass_gen
    assign client0_req_id[(j*16)+:16]= get_req_id(cfg_pbus_num, cfg_pbus_dev_num, client0_tlp_func_num_i[j*PF_WD+:PF_WD], int_device_type);
    assign client1_req_id[(j*16)+:16]= get_req_id(cfg_pbus_num, cfg_pbus_dev_num, client1_tlp_func_num_i[j*PF_WD+:PF_WD], int_device_type);
 end
 endgenerate





wire [L2NL - 1 : 0] pm_rx_pol_lane_flip_ctrl_i;
assign pm_rx_pol_lane_flip_ctrl_i = pm_rx_pol_lane_flip_ctrl;

assign {cfg_force_lane_flip, cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts} = cfg_lut_ctrl;
wire   ltssm_master_lpbk_active_after_g5_lpbk_eq = lpbk_lane_under_test[4]; // loopback master in Gen5 Loopback.Active following Loopback EQ
assign lut_en   = cfg_force_lane_flip ? 1'b1 : ltssm_master_lpbk_active_after_g5_lpbk_eq ? 1'b1 : 1'b0;
assign lut_ctrl = {cfg_force_lane_flip, lut_en, cfg_lane_under_test};



//
// muxes added for enabling lane flip functions
//
lane_flip
 #(
  .L2NL (L2NL)
) u_lane_flip (
    // ------------------ Inputs - Controls ------------------
    .core_clk                                       (core_clk),
    .core_clk_ug                                    (core_clk_ug),
    .core_rst_n                                     (core_rst_n),
    .lane_under_test_i                              (lut_ctrl),
    .pm_rx_lane_flip_en                             (pm_rx_lane_flip_en),
    .pm_tx_lane_flip_en                             (pm_tx_lane_flip_en),
    .pm_rx_pol_lane_flip_ctrl                       (pm_rx_pol_lane_flip_ctrl_i),

    // ------------------ Inputs - Rx Muxes ------------------
    .int_phy_mac_rxstandbystatus_i                  (int_phy_mac_rxstandbystatus),
    .int_phy_mac_rxdata_i                           (int_phy_mac_rxdata),
    .int_phy_mac_rxdatak_i                          (int_phy_mac_rxdatak),
    .int_phy_mac_rxdatavalid_i                      (int_phy_mac_rxdatavalid),
    .int_phy_mac_rxvalid_i                      (int_phy_mac_rxvalid),
    .int_phy_mac_rxelecidle_i                   (int_phy_mac_rxelecidle),
    .int_phy_mac_rxstatus_i                     (int_phy_mac_rxstatus),
    .int_phy_mac_phystatus_i                    (int_phy_mac_phystatus),
    .smlh_no_turnoff_lanes                          (smlh_no_turnoff_lanes),

    // ------------------ Outputs - Rx Muxes ------------------
    .tmp_phy_mac_rxstandbystatus                    (tmp_phy_mac_rxstandbystatus),
    .tmp_phy_mac_rxdata                             (tmp_phy_mac_rxdata),
    .tmp_phy_mac_rxdatak                            (tmp_phy_mac_rxdatak),
    .tmp_phy_mac_rxdatavalid                        (tmp_phy_mac_rxdatavalid),
    .tmp_phy_mac_rxvalid                        (tmp_phy_mac_rxvalid),
    .tmp_phy_mac_rxelecidle                     (tmp_phy_mac_rxelecidle),
    .tmp_phy_mac_rxstatus                       (tmp_phy_mac_rxstatus),
    .tmp_phy_mac_phystatus                      (tmp_phy_mac_phystatus),
    .laneflip_no_turnoff_lanes_o                    (laneflip_no_turnoff_lanes),

    // ------------------ Inputs - Tx Muxes ------------------
    .tmp_mac_phy_rxstandby                          (tmp_mac_phy_rxstandby),
    .tmp_xmlh_powerdown                             (tmp_xmlh_powerdown),
    .tmp_int_mac_phy_rate                           (tmp_int_mac_phy_rate),
    .tmp_mac_phy_txdata                             (tmp_mac_phy_txdata),
    .tmp_mac_phy_txdatak                            (tmp_mac_phy_txdatak),
    .tmp_mac_phy_txdetectrx_loopback                (tmp_mac_phy_txdetectrx_loopback),
    .tmp_ltssm_txelecidle                           (tmp_ltssm_txelecidle),
    .tmp_mac_phy_txcompliance                       (tmp_mac_phy_txcompliance),
    .tmp_mac_phy_rxpolarity                         (tmp_mac_phy_rxpolarity),
    .smlh_lanes_active                              (smlh_lanes_active),
    .smlh_rcvd_eidle_rxstandby                      (smlh_rcvd_eidle_rxstandby),


    // ------------------ Outputs - Tx Muxes ------------------
    .int_mac_phy_rxstandby_o                        (int_mac_phy_rxstandby),
    .int_xmlh_powerdown_o                           (int_xmlh_powerdown),
    .int_mac_phy_rate_o                             (int_mac_phy_rate),
    .int_mac_phy_txdata_o                           (int_mac_phy_txdata),
    .int_mac_phy_txdatak_o                          (int_mac_phy_txdatak),
    .int_mac_phy_txdetectrx_loopback_o              (int_mac_phy_txdetectrx_loopback),
    .int_ltssm_txelecidle_o                         (int_ltssm_txelecidle_i),
    .int_mac_phy_txcompliance_o                     (int_mac_phy_txcompliance_i),
    .int_mac_phy_rxpolarity_o                       (int_mac_phy_rxpolarity)
    ,
    .laneflip_lanes_active_o                        (laneflip_lanes_active),
    .laneflip_rcvd_eidle_rxstandby_o                (laneflip_rcvd_eidle_rxstandby)
); // u_lane_flip

reg  ltssm_master_lpbk_active_after_g5_lpbk_eq_r;
wire ltssm_master_lpbk_active_after_g5_lpbk_eq_i;
always @( posedge core_clk or negedge core_rst_n ) begin : int_mac_phy_txcompliance_r_PROC
    if ( ~core_rst_n )
        int_mac_phy_txcompliance_r <= #`TP 0;
    else if ( ~ltssm_master_lpbk_active_after_g5_lpbk_eq_i )
        int_mac_phy_txcompliance_r <= #`TP int_mac_phy_txcompliance_i;
end // int_mac_phy_txcompliance_r_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_master_lpbk_active_after_g5_lpbk_eq_r_PROC
    if ( ~core_rst_n )
        ltssm_master_lpbk_active_after_g5_lpbk_eq_r <= #`TP 0;
    else
        ltssm_master_lpbk_active_after_g5_lpbk_eq_r <= #`TP ltssm_master_lpbk_active_after_g5_lpbk_eq;
end // ltssm_master_lpbk_active_after_g5_lpbk_eq_r_PROC

assign ltssm_master_lpbk_active_after_g5_lpbk_eq_i = ltssm_master_lpbk_active_after_g5_lpbk_eq_r | ltssm_master_lpbk_active_after_g5_lpbk_eq;

always @* begin : force_lane_flip_PROC
    integer ij;

    int_ltssm_txelecidle = {NL{1'b1}};
    int_mac_phy_txcompliance = {NL{1'b0}};

    if ( cfg_force_lane_flip || ltssm_master_lpbk_active_after_g5_lpbk_eq_i ) begin // force not cfg_lane_under_test lanes turned off if cfg_force_lane_flip = 1'b1
        for (ij=0; ij<NL; ij=ij+1) begin
            if ( ij == cfg_lane_under_test ) begin
                int_ltssm_txelecidle[ij] = int_ltssm_txelecidle_i[ij];
                int_mac_phy_txcompliance[ij] = int_mac_phy_txcompliance_i[ij];
            end else begin
                int_ltssm_txelecidle[ij] = 1'b1;

                if ( cfg_force_lane_flip ) begin
                    int_mac_phy_txcompliance[ij] = 1'b1;
                end else begin // ltssm_master_lpbk_active_after_g5_lpbk_eq_i = 1
                    int_mac_phy_txcompliance[ij] = int_mac_phy_txcompliance_r[ij];
                end
            end
        end
    end else begin
        int_ltssm_txelecidle = int_ltssm_txelecidle_i;
        int_mac_phy_txcompliance = int_mac_phy_txcompliance_i;
    end
end // force_lane_flip_PROC

  // When LTSSM in config state, all lanes have to be active  for upconfigure.
 assign power_saving_laneflip_lanes_active = laneflip_lanes_active | {NL{smlh_ltssm_in_config}};

// assign tmp_phy_mac_rxstandbystatus = int_phy_mac_rxstandbystatus; // no lane flip
// assign int_mac_phy_rxstandby = tmp_mac_phy_rxstandby; // no lane flip


 assign in_cxpl_phy_mac_rxdata              = tmp_phy_mac_rxdata;
 assign in_cxpl_phy_mac_rxdatak             = tmp_phy_mac_rxdatak;
 assign in_cxpl_phy_mac_rxvalid             = tmp_phy_mac_rxvalid;
 assign in_cxpl_phy_mac_rxelecidle          = tmp_phy_mac_rxelecidle;
 assign in_cxpl_phy_mac_rxstatus            = tmp_phy_mac_rxstatus;
 assign in_cxpl_phy_mac_phystatus           = tmp_phy_mac_phystatus;


assign  radm_pm_to_ack              = int_radm_pm_to_ack | pm_turnoff_timeout; // Turnoff timeout is treated as if TO ACK message is received.

//
// XADM Module
//

localparam WRR_ARB_WD = `CX_XADM_ARB_WRR_WEIGHT_BIT_WIDTH;

wire    [(8*WRR_ARB_WD)-1:0]        cfg_lpvc_wrr_weight;
wire    [63:0]                      int_cfg_lpvc_wrr_weight;
wire    [1:0]                       cfg_lpvc_wrr_phase;
wire    [2:0]                       cfg_lpvc;
wire    [2:0]                       cfg_vc_arb_sel;
            

wire                    int_radm_inta_asserted;
wire                    int_radm_intb_asserted;
wire                    int_radm_intc_asserted;
wire                    int_radm_intd_asserted;
assign                  radm_inta_asserted = int_radm_inta_asserted;
assign                  radm_intb_asserted = int_radm_intb_asserted;
assign                  radm_intc_asserted = int_radm_intc_asserted;
assign                  radm_intd_asserted = int_radm_intd_asserted;
assign cfg_lpvc_wrr_weight  = {int_cfg_lpvc_wrr_weight[(8*7+WRR_ARB_WD)-1:8*7],
                               int_cfg_lpvc_wrr_weight[(8*6+WRR_ARB_WD)-1:8*6],
                               int_cfg_lpvc_wrr_weight[(8*5+WRR_ARB_WD)-1:8*5],
                               int_cfg_lpvc_wrr_weight[(8*4+WRR_ARB_WD)-1:8*4],
                               int_cfg_lpvc_wrr_weight[(8*3+WRR_ARB_WD)-1:8*3],
                               int_cfg_lpvc_wrr_weight[(8*2+WRR_ARB_WD)-1:8*2],
                               int_cfg_lpvc_wrr_weight[(8*1+WRR_ARB_WD)-1:8*1],
                               int_cfg_lpvc_wrr_weight[(8*0+WRR_ARB_WD)-1:8*0]};
assign cfg_lpvc_wrr_phase   = cfg_vc_arb_sel[1:0];

assign trgt1_radm_halt_i = trgt1_radm_halt;


// Since AXI_BRIDGE does the parity location different from the core's parity location, we will need to swap the parity location



wire    [FX_TLP-1:0]                int_radm_pm_pme;
assign radm_pm_pme          = |int_radm_pm_pme;
wire    [FX_TLP-1:0]                int_radm_correctable_err;           // RC Mode Only:
wire    [FX_TLP-1:0]                int_radm_nonfatal_err;              // RC Mode Only:
wire    [FX_TLP-1:0]                int_radm_fatal_err;                 // RC Mode Only:
assign radm_correctable_err = |int_radm_correctable_err;
assign radm_nonfatal_err    = |int_radm_nonfatal_err;
assign radm_fatal_err       = |int_radm_fatal_err;

wire    [FX_TLP*NF-1:0] cdm_radm_correctable_err;           // RC Mode Only:
wire    [FX_TLP*NF-1:0] cdm_radm_nonfatal_err;              // RC Mode Only:
wire    [FX_TLP*NF-1:0] cdm_radm_fatal_err;                 // RC Mode Only:
wire    [FX_TLP*NF-1:0] cdm_radm_pm_pme;                    // RC Mode Only:

assign cdm_radm_correctable_err = {NF{int_radm_correctable_err}};
assign cdm_radm_nonfatal_err    = {NF{int_radm_nonfatal_err}};
assign cdm_radm_fatal_err       = {NF{int_radm_fatal_err}};
assign cdm_radm_pm_pme          = {NF{int_radm_pm_pme}};



            
xadm

#(
    .INST (INST)
) u_xadm (
    // ------ Inputs ------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .rstctl_core_flush_req          (rstctl_core_flush_req),
    .cfg_max_payload_size           (cfg_highest_max_payload),
    .cfg_vc_enable                  (cfg_vc_enable),
    .cfg_vc_struc_vc_id_map         (cfg_vc_struc_vc_id_map),
    .cfg_tc_vc_map                  (cfg_tc_vc_map),
    .cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map),
    .cfg_lpvc_wrr_weight            (cfg_lpvc_wrr_weight),
    .cfg_lpvc_wrr_phase             (cfg_lpvc_wrr_phase),
    .cfg_lpvc                       (cfg_lpvc),
    .cfg_ecrc_gen_en                (cfg_ecrc_gen_en),
    .cfg_trgt_cpl_lut_delete_entry  (cfg_trgt_cpl_lut_delete_entry),
    .cfg_max_rd_req_size            (cfg_max_rd_req_size),
    .cfg_hq_depths                  (cfg_hq_depths),
    .cfg_dq_depths                  (cfg_dq_depths),
    .xtlh_xadm_halt                 (xtlh_xadm_halt),

    .client0_addr_align_en          (client0_addr_align_en_i),
    .client0_tlp_byte_en            (client0_tlp_byte_en_i),
    .client0_cpl_req_id             (client0_remote_req_id_i),
    .client0_cpl_status             (client0_cpl_status_i),
    .client0_cpl_bcm                (client0_cpl_bcm_i),
    .client0_cpl_byte_cnt           (client0_cpl_byte_cnt_i),
    .client0_req_id                 (client0_req_id_i),
    .client0_tlp_dv                 (client0_tlp_dv_i),
    .client0_tlp_hv                 (client0_tlp_hv),
    .client0_tlp_eot                (client0_tlp_eot_i),
    .client0_tlp_data               (client0_tlp_data_i),
    .client0_tlp_bad_eot            (client0_tlp_bad_eot_i),
    .client0_tlp_fmt                (client0_tlp_fmt_i),
    .client0_tlp_type               (client0_tlp_type_i),
    .client0_tlp_tc                 (client0_tlp_tc_i),
    .client0_tlp_td                 (client0_tlp_td_i),
    .client0_tlp_ep                 (client0_tlp_ep_i),
    .client0_tlp_attr               (client0_tlp_attr_i),
    .client0_tlp_byte_len           (client0_tlp_byte_len_i),
    .client0_tlp_tid                (client0_tlp_tid_i),
    .client0_tlp_addr               (client0_tlp_addr_i),

// `ifdef CX_RASDP_EN
//     .client0_hdr_prot               (client0_hdr_prot_i),
// `endif // CX_RASDP_EN

    .client1_addr_align_en          (client1_addr_align_en_i),
    .client1_tlp_byte_en            (client1_tlp_byte_en_i),
    .client1_cpl_req_id             (client1_remote_req_id_i),
    .client1_cpl_status             (client1_cpl_status_i),
    .client1_cpl_bcm                (client1_cpl_bcm_i),
    .client1_cpl_byte_cnt           (client1_cpl_byte_cnt_i),
    .client1_req_id                 (client1_req_id_i),
    .client1_tlp_dv                 (client1_tlp_dv_i),
    .client1_tlp_hv                 (client1_tlp_hv),
    .client1_tlp_eot                (client1_tlp_eot_i),
    .client1_tlp_bad_eot            (client1_tlp_bad_eot_i),
    .client1_tlp_data               (client1_tlp_data_i),
    .client1_tlp_fmt                (client1_tlp_fmt_i),
    .client1_tlp_type               (client1_tlp_type_i),
    .client1_tlp_tc                 (client1_tlp_tc_i),
    .client1_tlp_td                 (client1_tlp_td_i),
    .client1_tlp_ep                 (client1_tlp_ep_i),
    .client1_tlp_attr               (client1_tlp_attr_i),
    .client1_tlp_byte_len           (client1_tlp_byte_len_i),
    .client1_tlp_tid                (client1_tlp_tid_i),
    .client1_tlp_addr               (client1_tlp_addr_i),
// `ifdef CX_RASDP_EN
//     .client1_hdr_prot               (client1_hdr_prot_i),
// `endif // CX_RASDP_EN


    .lbc_cpl_hv                     (lbc_cpl_hv),
    .lbc_cpl_dv                     (lbc_cpl_dv),
    .lbc_cpl_data                   (lbc_cpl_data),
    .lbc_cpl_hdr                    (lbc_cpl_hdr),
    .lbc_cpl_eot                    (lbc_cpl_eot),
    //DE: Deadlock fix
    .lbc_deadlock_det               (lbc_deadlock_det),


    .msg_gen_hv                     (msg_gen_hv),
    .msg_gen_dv                     (msg_gen_dv),
    .msg_gen_eot                    (msg_gen_eot),
    .msg_gen_data                   (msg_gen_data),
    .msg_gen_hdr                    (msg_gen_hdr),
    .rdlh_link_down                 (rdlh_link_down),
    .rtlh_rfc_upd                   (rtlh_rfc_upd),
    .rtlh_rfc_data                  (rtlh_rfc_data),
    .rtlh_fc_init_status            (rtlh_fc_init_status),
    .pm_xtlh_block_tlp              (pm_xtlh_block_tlp),
    .cfg_client0_block_new_tlp      (cfg_client0_block_new_tlp),
    .cfg_client1_block_new_tlp      (cfg_client1_block_new_tlp),
    .cfg_client2_block_new_tlp      (cfg_client2_block_new_tlp),
    .pm_block_all_tlp               (pm_block_all_tlp),
    //.pm_l1_aspm_entr               (pm_l1_aspm_entr),
    .xtlh_xadm_restore_enable       (xtlh_xadm_restore_enable),
    .xtlh_xadm_restore_capture      (xtlh_xadm_restore_capture),
    .xtlh_xadm_restore_tc           (xtlh_xadm_restore_tc),
    .xtlh_xadm_restore_type         (xtlh_xadm_restore_type),
    .xtlh_xadm_restore_word_len     (xtlh_xadm_restore_word_len),

// SW || !TRGT1 => NO TRGT_LUT, NO CPLQ_MNG => !(SW || !TRGT1)=!SW && TRGT1
    .radm_trgt1_hv                  (radm_trgt1_hv_i),
    .radm_trgt1_eot                 (radm_trgt1_eot_i),
    .radm_trgt1_tlp_abort           (radm_trgt1_tlp_abort_i),
    .radm_trgt1_dllp_abort          (radm_trgt1_dllp_abort_i),
    .radm_trgt1_fmt                 (radm_trgt1_fmt_i),
    .radm_trgt1_type                (radm_trgt1_type_i),
    .radm_trgt1_dw_len              (radm_trgt1_dw_len_i),
    .radm_trgt1_addr                (radm_trgt1_addr_out_i[6:0]),

    .radm_trgt1_cpl_last            (radm_trgt1_cpl_last_i),
    .radm_trgt1_cpl_status          (radm_trgt1_cpl_status_i),
    .radm_trgt1_byte_cnt            (radm_trgt1_byte_cnt_i),
    .radm_trgt1_tc                  (radm_trgt1_tc_i),
    .radm_trgt1_tag                 (radm_trgt1_tag_i),
    .trgt1_radm_halt                (trgt1_radm_halt_i),

    .radm_cpl_timeout               (radm_cpl_timeout_i),
    .radm_timeout_cpl_byte_len      (radm_timeout_cpl_len_i),
    .radm_timeout_cpl_tc            (radm_timeout_cpl_tc_i),
    .radm_timeout_cpl_tag           (radm_timeout_cpl_tag_i),

    .radm_grant_tlp_type            (radm_grant_tlp_type_i),
    .trgt_lut_trgt1_radm_pkt_halt   (trgt_lut_trgt1_radm_pkt_halt),
    .cfg_2ndbus_num                 (cfg_2ndbus_num),
    .device_type                    (int_device_type),

//==== THEIRS //dwh/pcie_iip/dev_pcie/fairbanks/design/products/DWC_pcie_core.sv#98
  //`endif // CX_IS_DM_OR_RC
  //`ifdef CX_IS_EP_OR_RC
//==== THEIRS //dwh/pcie_iip/dev_pcie/fairbanks/design/products/DWC_pcie_core.sv#98
  //`endif //  CX_IS_EP_OR_RC
    // ------ Outputs ------
    .xadm_client0_halt              (xadm_client0_halt_i),
    .xadm_client1_halt              (xadm_client1_halt_i),

    .xadm_msg_halt                  (xadm_msg_halt),
    .xadm_cpl_halt                  (xadm_cpl_halt),
    .xadm_xtlh_bad_eot              (xadm_xtlh_bad_eot),
    .xadm_xtlh_add_ecrc             (xadm_xtlh_add_ecrc),
    .xadm_xtlh_hv                   (xadm_xtlh_hv),
    .xadm_xtlh_soh          (xadm_xtlh_soh),
    .xadm_xtlh_hdr                  (xadm_xtlh_hdr),
    .xadm_xtlh_dwen                 (xadm_xtlh_dwen),
    .xadm_xtlh_dv                   (xadm_xtlh_dv),
    .xadm_xtlh_data                 (xadm_xtlh_data),
    .xadm_xtlh_vc                   (xadm_xtlh_vc),
    .xadm_xtlh_eot                  (xadm_xtlh_eot),
    .xadm_tlp_pending               (xadm_tlp_pending),
    .xadm_block_tlp_ack             (xadm_block_tlp_ack),
    .xadm_no_fc_credit              (xadm_no_fc_credit),
    .xadm_had_enough_credit         (xadm_had_enough_credit),
    .xadm_parerr_detected           (xadm_parerr_detected),

    .xadm_all_type_infinite         (xadm_all_type_infinite),
    .xadm_ph_cdts                   (xadm_ph_cdts),
    .xadm_pd_cdts                   (xadm_pd_cdts),
    .xadm_nph_cdts                  (xadm_nph_cdts),
    .xadm_npd_cdts                  (xadm_npd_cdts),
    .xadm_cplh_cdts                 (xadm_cplh_cdts),
    .xadm_cpld_cdts                 (xadm_cpld_cdts)
);   // u_xadm





//
// RADM module for DM application
//
radm_dm

#(INST) u_radm_dm (
    // ------- Inputs --------
    .core_clk                       (radm_clk_g),
    .core_rst_n                     (core_rst_n),
    .radm_clk_ug                    (core_clk),
    .cfg_radm_clk_control           (cfg_clock_gating_ctrl[0]),
    .rstctl_core_flush_req          (rstctl_core_flush_req),
    .upstream_port                  (upstream_port),
    .app_req_retry_en               (app_req_retry_en),
    .app_pf_req_retry_en            (app_pf_req_retry_en),
    .cfg_rcb_128                    (cfg_rcb[0]),
    .cfg_pbus_dev_num               (cfg_pbus_dev_num),
    .cfg_pbus_num                   (cfg_pbus_num),
    .cfg_ecrc_chk_en                (cfg_ecrc_chk_en),
    .cfg_max_func_num               (cfg_max_func_num),
    .cfg_radm_q_mode                (cfg_radm_q_mode),
    .cfg_radm_order_rule            (cfg_radm_order_rule),
    .cfg_order_rule_ctrl            (cfg_order_rule_ctrl),
    .cfg_radm_strict_vc_prior       (cfg_radm_strict_vc_prior),
    .cfg_hq_depths                  (cfg_hq_depths),
    .cfg_dq_depths                  (cfg_dq_depths),
    .device_type                    (device_type_reg),
    .pm_radm_block_tlp              (pm_radm_block_tlp),
    .pm_freeze_cpl_timer            (pm_freeze_cpl_timer),
    .rtlh_radm_dv                   (rtlh_radm_dv),
    .rtlh_radm_hv                   (rtlh_radm_hv),
    .rtlh_radm_data                 (rtlh_radm_data),
    .rtlh_radm_hdr                  (rtlh_radm_hdr),
    .rtlh_radm_dwen                 (rtlh_radm_dwen),
    .rtlh_radm_eot                  (rtlh_radm_eot),
    .rtlh_radm_dllp_err             (rtlh_radm_dllp_err),
    .rtlh_radm_ecrc_err             (rtlh_radm_ecrc_err),
    .rtlh_radm_malform_tlp_err      (rtlh_radm_malform_tlp_err),
    .rtlh_radm_ant_addr             (rtlh_radm_ant_addr),
    .rtlh_radm_ant_rid              (rtlh_radm_ant_rid),

    .trgt0_radm_halt                (trgt0_radm_halt),
      .trgt1_radm_pkt_halt          (trgt1_radm_pkt_halt_i),
      .bridge_trgt1_radm_pkt_halt   (bridge_trgt1_radm_pkt_halt_i),
      .trgt_lut_trgt1_radm_pkt_halt (trgt_lut_trgt1_radm_pkt_halt_i),
      .trgt1_radm_halt              (trgt1_radm_halt_i),

    // from xtlh for keeping track of completions and handling of
    // completions
    .xtlh_xmt_tlp_done              (xtlh_xmt_tlp_done),
    .xtlh_xmt_tlp_done_early        (xtlh_xmt_tlp_done_early),
    .xtlh_xmt_tlp_req_id            (xtlh_xmt_tlp_req_id),
    .xtlh_xmt_tlp_tag               (xtlh_xmt_tlp_tag),
    .xtlh_xmt_tlp_attr              (xtlh_xmt_tlp_attr),
    .xtlh_xmt_tlp_tc                (xtlh_xmt_tlp_tc),
    .xtlh_xmt_tlp_len_inbytes       (xtlh_xmt_tlp_len_inbytes),
    .xtlh_xmt_tlp_first_be          (xtlh_xmt_tlp_first_be),
    .xtlh_xmt_cfg_req               (xtlh_xmt_cfg_req),
    .xtlh_xmt_memrd_req             (xtlh_xmt_memrd_req),

    .xtlh_xmt_ats_req               (xtlh_xmt_ats_req),
    .xtlh_xmt_atomic_req            (xtlh_xmt_atomic_req),

    .cfg_bar_is_io                  (cfg_bar_is_io),
    .cfg_io_match                   (cfg_io_match),
    .cfg_bar_match                  (cfg_bar_match),
    .cfg_rom_match                  (cfg_rom_match),
    .cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map),
    .cfg_config_above_match         (cfg_config_above_match),
    .cfg_prefmem_match              (cfg_prefmem_match),
    .cfg_mem_match                  (cfg_mem_match),
    .cfg_filter_rule_mask           (cfg_filter_rule_mask),
    .cfg_cpl_timeout_disable        (cfg_cpl_timeout_disable),

    .current_data_rate              (pm_current_data_rate_others),
    .phy_type                       (pm_phy_type),

    .target_mem_map                 (target_mem_map),
    .target_rom_map                 (target_rom_map),

    .default_target                 (default_target),
    .ur_ca_mask_4_trgt1             (ur_ca_mask_4_trgt1),
    .cfg_target_above_config_limit  (cfg_target_above_config_limit),
    .cfg_cfg_tlp_bypass_en          (cfg_cfg_tlp_bypass_en),
    .cfg_p2p_track_cpl_to           (cfg_p2p_track_cpl_to),
    .cfg_p2p_err_rpt_ctrl           (cfg_p2p_err_rpt_ctrl),
    .cfg_2ndbus_num                 (cfg_2ndbus_num),
    .cfg_subbus_num                 (cfg_subbus_num),

    .rtlh_radm_pending              (rtlh_radm_pending),

    // ---------------------- Outputs -----------------------------------
    .radm_idle                      (radm_idle),
    .flt_cdm_addr                   (flt_cdm_addr),
    .flt_cdm_rtlh_radm_pending      (flt_cdm_rtlh_radm_pending),
    .radm_rtlh_ph_ca                (radm_rtlh_ph_ca),
    .radm_rtlh_pd_ca                (radm_rtlh_pd_ca),
    .radm_rtlh_nph_ca               (radm_rtlh_nph_ca),
    .radm_rtlh_npd_ca               (radm_rtlh_npd_ca),
    .radm_rtlh_cplh_ca              (radm_rtlh_cplh_ca),
    .radm_rtlh_cpld_ca              (radm_rtlh_cpld_ca),
    .radm_qoverflow                 (radm_qoverflow),


    .radm_bypass_ecrc_err           (radm_bypass_ecrc_err_i),
    .radm_bypass_tlp_abort          (radm_bypass_tlp_abort_i),
    .radm_bypass_dllp_abort         (radm_bypass_dllp_abort_i),
    .radm_bypass_data               (radm_bypass_data_i),
    .radm_bypass_dv                 (radm_bypass_dv_i),
    .radm_bypass_hv                 (radm_bypass_hv_i),
    .radm_bypass_dwen               (radm_bypass_dwen_i),
    .radm_bypass_eot                (radm_bypass_eot_i),
    .radm_bypass_fmt                (radm_bypass_fmt_i),
    .radm_bypass_type               (radm_bypass_type_i),
    .radm_bypass_tc                 (radm_bypass_tc_i),
    .radm_bypass_attr               (radm_bypass_attr_i),
    .radm_bypass_reqid              (radm_bypass_reqid_i),
    .radm_bypass_tag                (radm_bypass_tag_i),
    .radm_bypass_func_num           (radm_bypass_func_num_i),
    .radm_bypass_cpl_status         (radm_bypass_cpl_status_i),
    .radm_bypass_td                 (radm_bypass_td_i),
    .radm_bypass_poisoned           (radm_bypass_poisoned_i),
    .radm_bypass_dw_len             (radm_bypass_dw_len_i),
    .radm_bypass_first_be           (radm_bypass_first_be_i),
    .radm_bypass_addr               (radm_bypass_addr_i),
    .radm_bypass_in_membar_range    (radm_bypass_in_membar_range_i),
    .radm_bypass_io_req_in_range    (radm_bypass_io_req_in_range_i),
    .radm_bypass_rom_in_range       (radm_bypass_rom_in_range_i),
    .radm_bypass_last_be            (radm_bypass_last_be_i),
    .radm_bypass_cpl_last           (radm_bypass_cpl_last_i),
    .radm_bypass_bcm                (radm_bypass_bcm_i),
    .radm_bypass_byte_cnt           (radm_bypass_byte_cnt_i),
    .radm_bypass_cmpltr_id          (radm_bypass_cmpltr_id_i),
    .radm_grant_tlp_type            (radm_grant_tlp_type),
    .radm_pend_cpl_so               (radm_pend_cpl_so),
    .radm_q_cpl_not_empty           (radm_q_cpl_not_empty),
    .radm_cpl_lut_valid             (radm_cpl_lut_valid_i),
    .radm_cpl_timeout               (radm_cpl_timeout_i),
    .radm_cpl_timeout_cdm           (radm_cpl_timeout_cdm_i),
    .radm_timeout_cpl_tc            (radm_timeout_cpl_tc_i),
    .radm_timeout_cpl_attr          (radm_timeout_cpl_attr_i),
    .radm_timeout_cpl_len           (radm_timeout_cpl_len_i),
    .radm_timeout_cpl_tag           (radm_timeout_cpl_tag_i),
    .radm_timeout_func_num          (radm_timeout_func_num_i),


    .radm_trgt0_dv                  (radm_trgt0_dv),
    .radm_trgt0_hv                  (radm_trgt0_hv),
    .radm_trgt0_hdr                 (radm_trgt0_hdr),
    .radm_trgt0_data                (radm_trgt0_data),
    .radm_trgt0_dwen                (radm_trgt0_dwen),
    .radm_trgt0_eot                 (radm_trgt0_eot),
    .radm_trgt0_abort               (radm_trgt0_abort),
    .radm_trgt0_ecrc_err            (),


    .radm_slot_pwr_limit            (radm_slot_pwr_limit),
    .radm_slot_pwr_payload          (radm_slot_pwr_payload),
    .radm_msg_payload               (radm_msg_payload),
    .radm_vendor_msg                (radm_vendor_msg),
    .radm_msg_unlock                (radm_msg_unlock),

    // all messages that core recived related to RC application
    .radm_inta_asserted             (int_radm_inta_asserted),
    .radm_intb_asserted             (int_radm_intb_asserted),
    .radm_intc_asserted             (int_radm_intc_asserted),
    .radm_intd_asserted             (int_radm_intd_asserted),
    .radm_inta_deasserted           (radm_inta_deasserted),
    .radm_intb_deasserted           (radm_intb_deasserted),
    .radm_intc_deasserted           (radm_intc_deasserted),
    .radm_intd_deasserted           (radm_intd_deasserted),
    .radm_correctable_err           (int_radm_correctable_err),
    .radm_nonfatal_err              (int_radm_nonfatal_err),
    .radm_fatal_err                 (int_radm_fatal_err),

    .radm_pm_pme                    (int_radm_pm_pme),
    .radm_pm_to_ack                 (int_radm_pm_to_ack),
    .radm_pm_turnoff                (radm_pm_turnoff),
    .radm_pm_asnak                  (radm_pm_asnak),
    .radm_msg_req_id                (radm_msg_req_id),
    .radm_unexp_cpl_err             (radm_unexp_cpl_err),
    .radm_rcvd_cpl_ur               (radm_rcvd_cpl_ur),
    .radm_rcvd_cpl_ca               (radm_rcvd_cpl_ca),
    .radm_q_not_empty               (radm_q_not_empty),
    .radm_cpl_pending               (radm_cpl_pending),

    .radm_trgt1_dv                  (radm_trgt1_dv_i),
    .radm_trgt1_hv                  (radm_trgt1_hv_i),
    .radm_trgt1_eot                 (radm_trgt1_eot_i),
    .radm_trgt1_hdr                 (radm_trgt1_hdr_i),
    .radm_trgt1_data                (radm_trgt1_data_i),
    .radm_trgt1_dwen                (radm_trgt1_dwen_i),
    .radm_trgt1_ecrc_err            (radm_trgt1_ecrc_err_i),
    .radm_trgt1_tlp_abort           (radm_trgt1_tlp_abort_i),
    .radm_trgt1_dllp_abort          (radm_trgt1_dllp_abort_i),
    .radm_trgt1_fmt                 (radm_trgt1_fmt_i),
    .radm_trgt1_type                (radm_trgt1_type_i),
    .radm_trgt1_tc                  (radm_trgt1_tc_i),
    .radm_trgt1_attr                (radm_trgt1_attr_i),
    .radm_trgt1_reqid               (radm_trgt1_reqid_i),
    .radm_trgt1_tag                 (radm_trgt1_tag_i),
    .radm_trgt1_func_num            (radm_trgt1_func_num_i),
    .radm_trgt1_cpl_status          (radm_trgt1_cpl_status_i),
    .radm_trgt1_td                  (radm_trgt1_td_i),
    .radm_trgt1_poisoned            (radm_trgt1_poisoned_i),
    .radm_trgt1_dw_len              (radm_trgt1_dw_len_i),
    .radm_trgt1_first_be            (radm_trgt1_first_be_i),
    .radm_trgt1_addr                (radm_trgt1_addr_out_i),
    .radm_trgt1_hdr_uppr_bytes      (radm_trgt1_hdr_uppr_bytes_i),
    .radm_trgt1_io_req_in_range     (radm_trgt1_io_req_in_range_i),
    .radm_trgt1_in_membar_range     (radm_trgt1_in_membar_range_i),
    .radm_trgt1_rom_in_range        (radm_trgt1_rom_in_range_i),
    .radm_trgt1_last_be             (radm_trgt1_last_be_i),
    .radm_trgt1_msgcode             (radm_trgt1_msgcode),
    .radm_trgt1_cpl_last            (radm_trgt1_cpl_last_i),
    .radm_trgt1_bcm                 (radm_trgt1_bcm_i),
    .radm_trgt1_byte_cnt            (radm_trgt1_byte_cnt_i),
    .radm_trgt1_cmpltr_id           (radm_trgt1_cmpltr_id_i),
    .radm_trgt1_vc_num              (radm_trgt1_vc_num_i),
    .radm_hdr_log_valid             (radm_hdr_log_valid),
    .radm_hdr_log                   (radm_hdr_log),
    .radm_ecrc_err                  (radm_ecrc_err),
    .radm_mlf_tlp_err               (radm_mlf_tlp_err),
    .radm_rcvd_wreq_poisoned        (radm_rcvd_wreq_poisoned),
    .radm_rcvd_cpl_poisoned         (radm_rcvd_cpl_poisoned),
    .radm_rcvd_req_ur               (radm_rcvd_req_ur),
    .radm_rcvd_req_ca               (radm_rcvd_req_ca),
    .cdm_err_advisory               (cdm_err_advisory),

    .p_hdrq_addra                   (p_hdrq_addra),
    .p_hdrq_addrb                   (p_hdrq_addrb),
    .p_hdrq_datain                  (p_hdrq_datain),
    .p_hdrq_dataout                 (p_hdrq_dataout),
    .p_hdrq_ena                     (p_hdrq_ena),
    .p_hdrq_enb                     (p_hdrq_enb),
    .p_hdrq_wea                     (p_hdrq_wea),
    .p_hdrq_parerr                  (p_hdrq_parerr),
    .p_hdrq_par_chk_val             (p_hdrq_par_chk_val),
    .p_hdrq_parerr_out              (p_hdrq_parerr_out_int),
    .p_dataq_addra                  (p_dataq_addra),
    .p_dataq_addrb                  (p_dataq_addrb),
    .p_dataq_datain                 (p_dataq_datain),
    .p_dataq_dataout                (p_dataq_dataout),
    .p_dataq_ena                    (p_dataq_ena),
    .p_dataq_enb                    (p_dataq_enb),
    .p_dataq_wea                    (p_dataq_wea),
    .p_dataq_parerr                 (p_dataq_parerr),
    .p_dataq_par_chk_val            (p_dataq_par_chk_val),
    .p_dataq_parerr_out             (p_dataq_parerr_out_int),




    .radm_snoop_upd                 (radm_snoop_upd),
    .radm_snoop_bus_num             (radm_snoop_bus_num),
    .radm_snoop_dev_num             (radm_snoop_dev_num),



    .radm_parerr                    (radm_parerr),
    .radm_trgt0_pending             (radm_trgt0_pending)


    ,
    .radm_clk_en                    (en_radm_clk_g)
);






// START_IO:DBI Signal Descriptions.
wire    [31:0]                      int_dbi_addr;
wire    [31:0]                      int_dbi_din;
wire                                int_dbi_cs;
wire                                int_dbi_cs2;
wire    [3:0]                       int_dbi_wr;
wire                                int_lbc_dbi_ack;
wire    [31:0]                      int_lbc_dbi_dout;



    assign int_dbi_addr        = dbi_addr;
    assign int_dbi_din         = dbi_din;
    assign int_dbi_cs          = pm_dbi_cs;
    assign int_dbi_cs2         = dbi_cs2;
    assign int_dbi_wr          = dbi_wr;
    assign lbc_dbi_ack         = int_lbc_dbi_ack;
    assign lbc_dbi_dout        = int_lbc_dbi_dout;
    assign slv_lbc_dbi_ack     = 0;
    assign slv_lbc_dbi_dout    = 0;

//
// CDM Module (default configuration is TYPE 0 header type)
//



//
// Any changes made to u_cdm MUST also be made to u_cdm_b
//

cdm

#(
  .INST(INST)

  ,
  .PM_MST_WD                (PM_MST_WD),
  .PM_SLV_WD                (PM_SLV_WD)
  ) u_cdm (
    // ------------- inputs --------------
    .core_clk                       (aux_clk_g),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .device_type                    (int_device_type),
    .phy_type                       (pm_phy_type),
    .app_dbi_ro_wr_disable          (app_dbi_ro_wr_disable),

    .lbc_cdm_addr                   (lbc_cdm_addr),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_cs                     (lbc_cdm_cs),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_xmt_cpl_ca                 (lbc_xmt_cpl_ca),
    .sys_int                        (sys_int),                      // not applicable to RC
    .sys_aux_pwr_det                (pm_sys_aux_pwr_det),
    .sys_pre_det_chged              (sys_pre_det_chged),
    .sys_atten_button_pressed       (sys_atten_button_pressed),
    .sys_pwr_fault_det              (sys_pwr_fault_det),
    .sys_mrl_sensor_chged           (sys_mrl_sensor_chged),
    .sys_cmd_cpled_int              (sys_cmd_cpled_int),
    .sys_pre_det_state              (sys_pre_det_state),
    .sys_mrl_sensor_state           (sys_mrl_sensor_state),
    .sys_eml_interlock_engaged      (sys_eml_interlock_engaged),

    .phy_cfg_status                 (phy_cfg_status),
    .cxpl_debug_info                (cxpl_debug_info),
    .smlh_autoneg_link_width        (smlh_autoneg_link_width),
    .smlh_autoneg_link_sp           (smlh_autoneg_link_sp),
    .smlh_link_training_in_prog     (smlh_link_training_in_prog),
    .rmlh_rcvd_err                  (rmlh_rcvd_err),
    .xtlh_xmt_cpl_ca                (xtlh_xmt_cpl_ca),
    .xtlh_xmt_cpl_ur                (xtlh_xmt_cpl_ur),
    .xtlh_xmt_wreq_poisoned         (xtlh_xmt_wreq_poisoned),
    .xtlh_xmt_cpl_poisoned          (xtlh_xmt_cpl_poisoned),

    .radm_rcvd_wreq_poisoned        (radm_rcvd_wreq_poisoned),
    .radm_rcvd_cpl_poisoned         (radm_rcvd_cpl_poisoned),
    .radm_mlf_tlp_err               (radm_mlf_tlp_err),
    .radm_ecrc_err                  (radm_ecrc_err),
    .cdm_err_advisory               (cdm_err_advisory),
    .radm_hdr_log_valid             (radm_hdr_log_valid),
    .radm_hdr_log                   (radm_hdr_log),
    .radm_rcvd_req_ur               (radm_rcvd_req_ur),
    .radm_rcvd_req_ca               (radm_rcvd_req_ca),


    .rtlh_overfl_err                (rtlh_overfl_err_nf),
    .rtlh_fc_init_status            (rtlh_fc_init_status),

    .xal_xmt_cpl_ca                 ({NF{1'b0}}),
    .xal_rcvd_cpl_ca                ({NF{1'b0}}),
    .xal_rcvd_cpl_ur                ({NF{1'b0}}),
    .xal_perr                       ({NF{1'b0}}),
    .xal_serr                       ({NF{1'b0}}),
    .xal_set_trgt_abort_primary     ({NF{1'b0}}),
    .xal_set_mstr_abort_primary     ({NF{1'b0}}),
    .xal_pci_addr_perr              ({NF{1'b0}}),
    .rdlh_dlcntrl_state             (rdlh_dlcntrl_state),
    .rdlh_prot_err                  (rdlh_prot_err),
    .rdlh_bad_tlp_err               (rdlh_bad_tlp_err),
    .rdlh_bad_dllp_err              (rdlh_bad_dllp_err),
    .rdlh_link_up                   (rdlh_link_up),
    .xdlh_replay_num_rlover_err     (xdlh_replay_num_rlover_err),
    .xdlh_replay_timeout_err        (xdlh_replay_timeout_err),
    .smlh_link_up                   (smlh_link_up),
    .smlh_bw_mgt_status             (smlh_bw_mgt_status),
    .smlh_link_auto_bw_status       (smlh_link_auto_bw_status),
    .current_data_rate              (pm_current_data_rate),
    .tmp_int_mac_phy_rate           (tmp_int_mac_phy_rate),
    .smlh_dir_linkw_chg_rising_edge (smlh_dir_linkw_chg_rising_edge),
    .radm_cpl_pending               (radm_cpl_pending),
    .radm_rcvd_cpl_ca               (radm_rcvd_cpl_ca),
    .radm_rcvd_cpl_ur               (radm_rcvd_cpl_ur),
    .radm_cpl_timeout               (radm_cpl_timeout_cdm_i),
    .radm_timeout_func_num           (radm_timeout_func_num_i),
    .radm_unexp_cpl_err             (radm_unexp_cpl_err),
    .radm_set_slot_pwr_limit        ({NF{radm_slot_pwr_limit}}),
    .radm_slot_pwr_payload          (radm_slot_pwr_payload),

    .radm_msg_req_id                (radm_msg_req_id),
    .radm_pm_pme                    (cdm_radm_pm_pme),            // Only for RC

    .radm_correctable_err           (cdm_radm_correctable_err),   // Only for RC or SW
    .radm_nonfatal_err              (cdm_radm_nonfatal_err),      // Only for RC or SW
    .radm_fatal_err                 (cdm_radm_fatal_err),         // Only for RC or SW
    .xtlh_xadm_ph_cdts              (xadm_ph_cdts[HCRD_WD-1:0]),
    .xtlh_xadm_nph_cdts             (xadm_nph_cdts[HCRD_WD-1:0]),
    .xtlh_xadm_cplh_cdts            (xadm_cplh_cdts[HCRD_WD-1:0]),
    .xtlh_xadm_pd_cdts              (xadm_pd_cdts[DCRD_WD-1:0]),
    .xtlh_xadm_npd_cdts             (xadm_npd_cdts[DCRD_WD-1:0]),
    .xtlh_xadm_cpld_cdts            (xadm_cpld_cdts[DCRD_WD-1:0]),

    .radm_qoverflow                 (|radm_qoverflow),
    .radm_q_not_empty               (radm_q_not_empty[0]),
    .xdlh_retrybuf_not_empty        (xdlh_retrybuf_not_empty),
    .rtlh_crd_not_rtn               (rtlh_crd_not_rtn[0]),

    // aux power reserved signals
    .pm_status                      (pm_status),
    .pm_pme_en                      (pm_pme_en_split),
    .aux_pm_en                      (pm_aux_pm_en_split),
    .flt_cdm_addr                   (flt_cdm_addr),
    .pm_radm_block_tlp              (pm_radm_block_tlp),
    .flt_cdm_rtlh_radm_pending      (flt_cdm_rtlh_radm_pending),



    .smlh_mod_ts_rcvd               (smlh_mod_ts_rcvd),
    .mod_ts_data_rcvd               (mod_ts_data_rcvd),
    .mod_ts_data_sent               (mod_ts_data_sent),
    .xdlh_retry_req                 (xdlh_retry_req),
    .exp_rom_validation_status_strobe            (exp_rom_validation_status_strobe ),
    .exp_rom_validation_status                   (exp_rom_validation_status        ),
    .exp_rom_validation_details_strobe           (exp_rom_validation_details_strobe),
    .exp_rom_validation_details                  (exp_rom_validation_details       ),

    .smlh_in_l0                     (smlh_in_l0),
    .smlh_in_l1                     (smlh_in_l1),

    .pm_sel_aux_clk                 (pm_sel_aux_clk),
    .radm_snoop_upd                 (radm_snoop_upd),
    .radm_snoop_bus_num             (radm_snoop_bus_num),
    .radm_snoop_dev_num             (radm_snoop_dev_num),


    .app_clk_pm_en                  (app_clk_pm_en),

    .app_dev_num                    (app_dev_num),
    .app_bus_num                    (app_bus_num),

    // -------------------------------- outputs -------------------------------------------------
    //


    .cfg_upd_aspm_ctrl              (cfg_upd_aspm_ctrl),
    .cfg_upd_aslk_pmctrl            (cfg_upd_aslk_pmctrl),
    .cfg_upd_pme_cap                (cfg_upd_pme_cap),
    .cfg_mem_match                  (cfg_mem_match),
    .cfg_prefmem_match              (cfg_prefmem_match),
    .cfg_config_above_match         (cfg_config_above_match),
    .cfg_io_match                   (cfg_io_match),
    .cfg_bar_match                  (cfg_bar_match),
    .cfg_bar_is_io                  (cfg_bar_is_io),
    .cfg_rom_match                  (cfg_rom_match),
    .cfg_pl_l1_nowait_p1            (cfg_pl_l1_nowait_p1),
    .cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel),
    .cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset),
    .cfg_phy_rst_timer              (cfg_phy_rst_timer),
    .cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer),
    .cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq),
    .cfg_filter_rule_mask           (cfg_filter_rule_mask),

    .cdm_lbc_data                   (cdm_lbc_data),
    .cdm_lbc_ack                    (cdm_lbc_ack),

    .cfg_pbus_num                   (cfg_pbus_num),
    .cfg_pbus_dev_num               (cfg_pbus_dev_num),
    .cfg_2ndbus_num                 (cfg_2ndbus_num),
    .cfg_subbus_num                 (cfg_subbus_num),
    .cfg_aslk_pmctrl                (cfg_aslk_pmctrl),
    .cfg_clk_pm_en                  (cfg_clk_pm_en_tmp),

    .cfg_relax_ord_en               (cfg_relax_order_en),
    .cfg_no_snoop_en                (cfg_no_snoop_en),

    .cfg_ext_tag_en                 (cfg_ext_tag_en),
    .cfg_phantom_fun_en             (),
    .cfg_aux_pm_en                  (cfg_aux_pm_en),
    .cfg_max_rd_req_size            (cfg_max_rd_req_size),
    .cfg_bridge_crs_en              (),
    .cfg_rcb                        (cfg_rcb),
    .cfg_comm_clk_config            (cfg_comm_clk_config),
    .cfg_hw_autowidth_dis           (cfg_hw_autowidth_dis),
    .cfg_max_payload_size           (cfg_max_payload_size),
    .cfg_highest_max_payload        (cfg_highest_max_payload),
    .cfg_ack_freq                   (cfg_ack_freq),
    .cfg_ack_latency_timer          (cfg_ack_latency_timer),
    .cfg_replay_timer_value         (cfg_replay_timer_value),
    .cfg_fc_latency_value           (cfg_fc_latency_value),
    .cfg_other_msg_payload          (cfg_other_msg_payload),
    .cfg_other_msg_request          (cfg_other_msg_request),
    .cfg_corrupt_crc_pattern        (cfg_corrupt_crc_pattern),
    .cfg_scramble_dis               (cfg_scramble_dis),
    .cfg_n_fts                      (cfg_n_fts),
    .cfg_link_dis                   (cfg_link_dis),
    .cfg_link_retrain               (cfg_link_retrain),
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_pipe_loopback              (cfg_pipe_loopback),
    .cfg_rxstatus_lane              (cfg_rxstatus_lane),
    .cfg_rxstatus_value             (cfg_rxstatus_value),
    .cfg_lpbk_rxvalid               (cfg_lpbk_rxvalid),
    .cfg_plreg_reset                (cfg_plreg_reset),
    .cfg_link_num                   (cfg_link_num),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .cfg_forced_link_state          (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd           (cfg_forced_ltssm_cmd),

    .cfg_force_en                   (cfg_force_en),
    .cfg_lane_skew                  (cfg_lane_skew),
    .cfg_deskew_disable             (cfg_deskew_disable),
    .cfg_imp_num_lanes              (cfg_imp_num_lanes),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode_i),
    .cfg_flow_control_disable       (cfg_flow_control_disable),
    .cfg_acknack_disable            (cfg_acknack_disable),
    .cfg_link_capable               (cfg_link_capable),
    .cfg_eidle_timer                (),
    .cfg_skip_interval              (cfg_skip_interval),
    .cfg_link_rate                  (),
    .cfg_retimers_pre_detected      (cfg_retimers_pre_detected),
    .cfg_fast_link_mode             (int_cfg_fast_link_mode),
    .cfg_fast_link_scaling_factor   (cfg_fast_link_scaling_factor),
    .cfg_l0s_supported              (cfg_l0s_supported),
    .cfg_dll_lnk_en                 (cfg_dll_lnk_en),
    .cfg_soft_rst_n                 (),
    .cfg_2nd_reset                  (cfg_2nd_reset),
    .cfg_ecrc_gen_en                (cfg_ecrc_gen_en),
    .cfg_ecrc_chk_en                (cfg_ecrc_chk_en),
    .cfg_bar0_start                 (cfg_bar0_start),
    .cfg_bar0_limit                 (cfg_bar0_limit),
    .cfg_bar0_mask                  (cfg_bar0_mask),
    .cfg_bar1_start                 (cfg_bar1_start),
    .cfg_bar1_limit                 (cfg_bar1_limit),
    .cfg_bar1_mask                  (cfg_bar1_mask),
    .cfg_bar2_start                 (cfg_bar2_start),
    .cfg_bar2_limit                 (cfg_bar2_limit),
    .cfg_bar2_mask                  (cfg_bar2_mask),
    .cfg_bar3_start                 (cfg_bar3_start),
    .cfg_bar3_limit                 (cfg_bar3_limit),
    .cfg_bar3_mask                  (cfg_bar3_mask),
    .cfg_bar4_start                 (cfg_bar4_start),
    .cfg_bar4_limit                 (cfg_bar4_limit),
    .cfg_bar4_mask                  (cfg_bar4_mask),
    .cfg_bar5_start                 (cfg_bar5_start),
    .cfg_bar5_limit                 (cfg_bar5_limit),
    .cfg_bar5_mask                  (cfg_bar5_mask),
    .cfg_rom_mask                   (cfg_rom_mask),
    .cfg_mem_base                   (),
    .cfg_mem_limit                  (),
    .cfg_pref_mem_base              (),
    .cfg_pref_mem_limit             (),
    .cfg_exp_rom_start              (cfg_exp_rom_start),
    .cfg_exp_rom_limit              (cfg_exp_rom_limit),
    .cfg_io_limit_upper16           (cfg_io_limit_upper16),
    .cfg_io_base_upper16            (cfg_io_base_upper16),
    .cfg_io_base                    (cfg_io_base),
    .cfg_io_limit                   (cfg_io_limit),
    .cfg_hdr_type                   (),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_io_space_en                (cfg_io_space_en),
    .cfg_mem_space_en               (cfg_mem_space_en),
    .cfg_phy_control                (cfg_phy_control),
    .upstream_port                  (upstream_port),
    .switch_device                  (),
    .end_device                     (end_device),
    .rc_device                      (rc_device),
    .bridge_device                  (bridge_device),
    .cfg_upd_req_id                 (cfg_upd_req_id),
    .cfg_upd_pmcsr                  (cfg_upd_pmcsr),
    .cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en),
    .cfg_pmstatus_clr               (cfg_pmstatus_clr),
    .cfg_pmstate                    (cfg_pmstate),
    .cfg_pme_en                     (cfg_pme_en),
    .cfg_pm_no_soft_rst             (cfg_pm_no_soft_rst),
    .cfg_bus_master_en              (cfg_bus_master_en),
    .cfg_reg_serren                 (cfg_reg_serren),
    .cfg_cor_err_rpt_en             (cfg_cor_err_rpt_en),
    .cfg_nf_err_rpt_en              (cfg_nf_err_rpt_en),
    .cfg_f_err_rpt_en               (cfg_f_err_rpt_en),
    .cfg_pme_cap                    (cfg_pme_cap),
    .cfg_l0s_entr_latency_timer     (cfg_l0s_entr_latency_timer),
    .cfg_l1_entr_latency_timer      (cfg_l1_entr_latency_timer),
    .cfg_l1_entr_wo_rl0s            (cfg_l1_entr_wo_rl0s),
    .cfg_isa_enable                 (),
    .cfg_vga_enable                 (),
    .cfg_vga16_decode               (),
    .cfg_send_cor_err               (cfg_send_cor_err),
    .cfg_send_nf_err                (cfg_send_nf_err),
    .cfg_send_f_err                 (cfg_send_f_err),
    .cfg_func_spec_err              (cfg_func_spec_err),
    .cfg_sys_err_rc                 (cfg_sys_err_rc),
    .cfg_aer_rc_err_int             (cfg_aer_rc_err_int),
    .cfg_aer_rc_err_msi             (cfg_aer_rc_err_msi),
    .cfg_aer_int_msg_num            (cfg_aer_int_msg_num),
    .cfg_pme_int                    (cfg_pme_int),
    .cfg_pme_msi                    (cfg_pme_msi),
    .cfg_crs_sw_vis_en              (cfg_crs_sw_vis_en),
    .cfg_pcie_cap_int_msg_num       (cfg_pcie_cap_int_msg_num),
    .cfg_cpl_timeout_disable        (cfg_cpl_timeout_disable),
    .cfg_lane_en                    (cfg_lane_en),
    .cfg_gen1_ei_inference_mode     (cfg_gen1_ei_inference_mode),
    .cfg_select_deemph_mux_bus      (cfg_select_deemph_mux_bus),
    .cfg_lut_ctrl                   (cfg_lut_ctrl),
    .cfg_rxstandby_control          (cfg_rxstandby_control),
    .cfg_link_auto_bw_int           (cfg_link_auto_bw_int),
    .cfg_bw_mgt_int                 (cfg_bw_mgt_int),
    .cfg_link_auto_bw_msi           (cfg_link_auto_bw_msi),
    .cfg_bw_mgt_msi                 (cfg_bw_mgt_msi),
    .cfg_pwr_ind                    (cfg_pwr_ind),
    .cfg_atten_ind                  (cfg_atten_ind),
    .cfg_pwr_ctrler_ctrl            (cfg_pwr_ctrler_ctrl),
    .cfg_eml_control                (cfg_eml_control),
    .cfg_slot_pwr_limit_wr          (cfg_slot_pwr_limit_wr),
    .cfg_int_disable                (cfg_int_disable),
    .cfg_msi_addr                   (cfg_msi_addr),
    .cfg_msi_data                   (cfg_msi_data),
    .cfg_msi_64                     (cfg_msi_64),
    .cfg_msi_en                     (cfg_msi_en),
    .cfg_multi_msi_en               (cfg_multi_msi_en),
    .cfg_msi_ext_data_en            (cfg_msi_ext_data_en),
    .cfg_msix_en                    (cfg_msix_en),
    .cfg_msix_func_mask             (cfg_msix_func_mask),
    .set_slot_pwr_limit_val         (cfg_slot_pwr_limit_val),
    .set_slot_pwr_limit_scale       (cfg_slot_pwr_limit_scale),
    .cfg_vc_enable                  (cfg_vc_enable),
    .cfg_vc_struc_vc_id_map         (cfg_vc_struc_vc_id_map),
    .cfg_vc_id_vc_struc_map         (cfg_vc_id_vc_struc_map),
    .cfg_tc_enable                  (cfg_tc_enable),
    .cfg_tc_vc_map                  (cfg_tc_vc_map),
    .cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map),
    .cfg_lpvc                       (cfg_lpvc),
    .cfg_vc_arb_sel                 (cfg_vc_arb_sel),
    .cfg_lpvc_wrr_weight            (int_cfg_lpvc_wrr_weight),
    .cfg_max_func_num               (cfg_max_func_num),
    .cfg_trgt_cpl_lut_delete_entry  (cfg_trgt_cpl_lut_delete_entry),
    .cfg_clock_gating_ctrl          (cfg_clock_gating_ctrl),
    .cfg_fc_credit_ph               (cfg_fc_credit_ph),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld),
    .cfg_radm_q_mode                (cfg_radm_q_mode),
    .cfg_radm_order_rule            (cfg_radm_order_rule),
    .cfg_order_rule_ctrl            (cfg_order_rule_ctrl),
    .cfg_radm_strict_vc_prior       (cfg_radm_strict_vc_prior),
    .cfg_hq_depths                  (cfg_hq_depths),
    .cfg_dq_depths                  (cfg_dq_depths),
    .target_mem_map                 (target_mem_map),
    .target_rom_map                 (target_rom_map),
    .inta_wire                      (inta_wire),
    .intb_wire                      (intb_wire),
    .intc_wire                      (intc_wire),
    .intd_wire                      (intd_wire),
    .cfg_fc_wdog_disable            (cfg_fc_wdog_disable),
    .cfg_pl_multilane_control       (cfg_pl_multilane_control)
    ,
    .cfg_alt_protocol_enable        (cfg_alt_protocol_enable) // Alternate protocol support
    ,
    .cfg_int_pin                    (cfg_int_pin)




    ,
    .default_target                 (default_target),
    .cfg_cfg_tlp_bypass_en          (cfg_cfg_tlp_bypass_en),
    .cfg_config_limit               (cfg_config_limit),
    .cfg_target_above_config_limit  (cfg_target_above_config_limit),
    .cfg_p2p_track_cpl_to           (cfg_p2p_track_cpl_to),
    .cfg_p2p_err_rpt_ctrl           (cfg_p2p_err_rpt_ctrl),
    .ur_ca_mask_4_trgt1             (ur_ca_mask_4_trgt1)

    ,
    .cfg_pipe_garbage_data_mode     (cfg_pipe_garbage_data_mode)







  ,
  .cfg_nond0_vdm_block              (cfg_nond0_vdm_block),
  .cfg_client0_block_new_tlp        (cfg_client0_block_new_tlp),
  .cfg_client1_block_new_tlp        (cfg_client1_block_new_tlp),
  .cfg_client2_block_new_tlp        (cfg_client2_block_new_tlp)

    ,
    .cdm_hp_pme                     (hp_pme),
    .cdm_hp_int                     (hp_int),
    .cdm_hp_msi                     (hp_msi)
    ,
    .cfg_auto_slot_pwr_lmt_dis      (cfg_auto_slot_pwr_lmt_dis), 
    .cfg_hp_slot_ctrl_access        (cfg_hp_slot_ctrl_access),
    .cfg_dll_state_chged_en         (cfg_dll_state_chged_en),
    .cfg_cmd_cpled_int_en           (cfg_cmd_cpled_int_en),
    .cfg_pre_det_chged_en           (cfg_pre_det_chged_en),
    .cfg_mrl_sensor_chged_en        (cfg_mrl_sensor_chged_en),
    .cfg_pwr_fault_det_en           (cfg_pwr_fault_det_en),
    .cfg_atten_button_pressed_en    (cfg_atten_button_pressed_en),
    .cfg_hp_int_en                  (cfg_hp_int_en)
    ,
    .cfg_br_ctrl_serren             (cfg_br_ctrl_serren)


    ,.pm_powerdown_status          (pm_powerdown_status)
    ,.cfg_force_powerdown          (cfg_force_powerdown)
    ,
    .cfg_pcie_slot_clk_config           (cfg_pcie_slot_clk_config          ),
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
    .cfg_rcvr_err_sts                   (cfg_rcvr_err_sts                  )    


);  // u_cdm


assign radm_trgt1_addr_i = radm_trgt1_addr_out_i;





//instance of pipe_adapter
pipe_adapter

#(
   .INST(INST),
   .NL(NL)
) u_pipe_adapter (
    //inputs
    .clk                       (core_clk_ug),
    .rst_n                     (core_rst_n),
    .cfg_elastic_buffer_mode   (cfg_elastic_buffer_mode),
    .rate                      (tmp_mac_phy_rate),
    .powerdown                 (xmlh_powerdown),

    //outputs
    .pipe_powerdown            (adapted_pipe_mac_phy_powerdown),
    .pipe_width                (adapted_pipe_mac_phy_width),
    .pipe_pclk_rate            (adapted_pipe_mac_phy_pclk_rate)
); //pipe_adapter

assign pre_mac_phy_txdatavalid  = {NL{1'b1}}; // All pacing configs are in gen3/4, so set to 1 for Gen1/2 configs
assign lpbk_rxdatavalid_i = lpbk_rxdatavalid;

//
// CX-PL core for xN
//

cx_pl

#(INST) u_cx_pl (
    // ------------------------------- Inputs ------------------------------------
    .cfg_p2p_track_cpl_to           (cfg_p2p_track_cpl_to),

    .pm_current_data_rate           (pm_current_data_rate),
    .core_clk                       (core_clk),
    .core_clk_ug                    (core_clk_ug),
    .core_rst_n                     (core_rst_n),
    .app_init_rst                   (pm_init_rst),                 // only applied to Downstream port
    .app_ltssm_enable               (pm_ltssm_enable),
    .rstctl_core_flush_req          (rstctl_core_flush_req),
    .phy_type                       (pm_phy_type),
    .cfg_endpoint                   (end_device),
    .cfg_root_compx                 (rc_device),
    .cfg_upstream_port              (upstream_port),
    .cfg_dll_lnk_en                 (cfg_dll_lnk_en),
    .cfg_ack_freq                   (cfg_ack_freq),
    .cfg_ack_latency_timer          (cfg_ack_latency_timer),
    .cfg_replay_timer_value         (cfg_replay_timer_value),
    .cfg_fc_latency_value           (cfg_fc_latency_value),
    .cfg_other_msg_payload          (cfg_other_msg_payload),
    .cfg_other_msg_request          (cfg_other_msg_request),
    .cfg_corrupt_crc_pattern        (cfg_corrupt_crc_pattern),
    .cfg_flow_control_disable       (cfg_flow_control_disable),
    .cfg_acknack_disable            (cfg_acknack_disable),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_scramble_dis               (cfg_scramble_dis),
    .cfg_n_fts                      (cfg_n_fts),
    .cfg_link_dis                   (cfg_link_dis),
    .cfg_link_retrain               (pm_smlh_link_retrain),             // Control LTSSM to link recovery
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_reset_assert               (cfg_reset_assert),
    .cfg_link_num                   (cfg_link_num),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_forced_link_state          (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd           (cfg_forced_ltssm_cmd),
    .cfg_force_en                   (cfg_force_en),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_fast_link_scaling_factor   (cfg_fast_link_scaling_factor),
    .cfg_l0s_supported              (cfg_l0s_supported),
    .cfg_link_capable               (cfg_link_capable),
    .cfg_lane_skew                  (cfg_lane_skew),
    .cfg_deskew_disable             (cfg_deskew_disable),
    .cfg_imp_num_lanes              (cfg_imp_num_lanes),
    .cfg_skip_interval              (cfg_skip_interval),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_hw_autowidth_dis           (cfg_hw_autowidth_dis),
    .cfg_max_payload                (cfg_highest_max_payload),
    .cfg_vc_enable                  (cfg_vc_enable),
    .cfg_vc_struc_vc_id_map         (cfg_vc_struc_vc_id_map),
    .cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map),
    .cfg_vc_id_vc_struc_map         (cfg_vc_id_vc_struc_map),
    .cfg_tc_enable                  (cfg_tc_enable),
    .cfg_fc_wdog_disable            (cfg_fc_wdog_disable),

    .cfg_fc_credit_ph               (cfg_fc_credit_ph),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld),
    .cfg_pipe_garbage_data_mode     (cfg_pipe_garbage_data_mode),
    .device_type                    (int_device_type),

    .phy_mac_rxdata                 (in_cxpl_phy_mac_rxdata),
    .phy_mac_rxdatak                (in_cxpl_phy_mac_rxdatak),
    .phy_mac_rxvalid                (in_cxpl_phy_mac_rxvalid),
    .phy_mac_rxstatus               (in_cxpl_phy_mac_rxstatus),
    .phy_mac_rxelecidle             (in_cxpl_phy_mac_rxelecidle),
    .phy_mac_phystatus              (in_cxpl_phy_mac_phystatus),
    .phy_mac_rxstandbystatus        (tmp_phy_mac_rxstandbystatus),
    .phy_mac_rxelecidle_noflip      (sqlchd_rxelecidle),
    .laneflip_lanes_active          (laneflip_lanes_active),
    .laneflip_rcvd_eidle_rxstandby  (laneflip_rcvd_eidle_rxstandby),
    .laneflip_pipe_turnoff          (int_pipe_turnoff),


    .cfg_lane_en                    (cfg_lane_en),
    .cfg_gen1_ei_inference_mode     (cfg_gen1_ei_inference_mode),
    .cfg_select_deemph_mux_bus      (cfg_select_deemph_mux_bus),
    .cfg_lut_ctrl                   (cfg_lut_ctrl),
    .cfg_rxstandby_control          (cfg_rxstandby_control),
    .phy_mac_rxdatavalid            (tmp_phy_mac_rxdatavalid),
    .cfg_alt_protocol_enable        (cfg_alt_protocol_enable), // Alternate protocol support
    .cfg_pl_multilane_control       (cfg_pl_multilane_control),

    .radm_rtlh_ph_ca                (int_rtlh_ph_ca),
    .radm_rtlh_pd_ca                (int_rtlh_pd_ca),
    .radm_rtlh_nph_ca               (int_rtlh_nph_ca),
    .radm_rtlh_npd_ca               (int_rtlh_npd_ca),
    .radm_rtlh_cplh_ca              (int_rtlh_cplh_ca),
    .radm_rtlh_cpld_ca              (int_rtlh_cpld_ca),

    .xadm_xtlh_hv                   (xadm_xtlh_hv),
    .xadm_xtlh_soh                  (xadm_xtlh_soh),
    .xadm_xtlh_hdr                  (xadm_xtlh_hdr),
    .xadm_xtlh_dwen                 (xadm_xtlh_dwen),
    .xadm_xtlh_dv                   (xadm_xtlh_dv),
    .xadm_xtlh_data                 (xadm_xtlh_data),
    .xadm_xtlh_eot                  (xadm_xtlh_eot),
    .xadm_xtlh_bad_eot              (xadm_xtlh_bad_eot),
    .xadm_xtlh_add_ecrc             (xadm_xtlh_add_ecrc),
    .xadm_xtlh_vc                   (xadm_xtlh_vc),

    .pm_smlh_entry_to_l0s           (pm_smlh_entry_to_l0s),
    .pm_smlh_l0s_exit               (pm_smlh_l0s_exit),
    .pm_smlh_entry_to_l1            (pm_smlh_entry_to_l1),
    .pm_smlh_l1_exit                (pm_smlh_l1_exit),
    .pm_smlh_l23_exit               (pm_smlh_l23_exit),
    .pm_smlh_entry_to_l2            (pm_smlh_entry_to_l2),
    .pm_smlh_prepare4_l123          (pm_smlh_prepare4_l123),
    .pm_freeze_fc_timer             (pm_freeze_fc_timer),
    .pm_xtlh_block_tlp              (pm_xtlh_block_tlp),
    .pm_xdlh_req_ack                (pm_xdlh_req_ack),
    .pm_xdlh_enter_l1               (pm_xdlh_enter_l1),
    .pm_xdlh_enter_l23              (pm_xdlh_enter_l23),
    .pm_xdlh_actst_req_l1           (pm_xdlh_actst_req_l1),
    .xadm_all_type_infinite         (xadm_all_type_infinite),

    .ltssm_cxl_enable               (ltssm_cxl_enable), // {Multi-logical Dev, CXL 2.0, SyncHeader, Cache, Mem, IO}
    .ltssm_cxl_ll_mod               (ltssm_cxl_ll_mod), // {driftbuffer, commonclock}
    .drift_buffer_deskew_disable    (cfg_lane_skew[13]),

    .pm_current_powerdown_p1            (pm_current_powerdown_p1),
    .pm_current_powerdown_p0            (pm_current_powerdown_p0),
    //  ------------------------------  Outputs --------------------------------
    .mac_phy_txdata                 (tmp_mac_phy_txdata),
    .mac_phy_txdatak                (tmp_mac_phy_txdatak),
    .mac_phy_txdetectrx_loopback    (tmp_mac_phy_txdetectrx_loopback),
    .mac_phy_txelecidle             (tmp_ltssm_txelecidle),
    .mac_phy_txcompliance           (tmp_mac_phy_txcompliance),
    .mac_phy_rxpolarity             (tmp_mac_phy_rxpolarity),
    .mac_phy_rxstandby              (tmp_mac_phy_rxstandby),
    .smlh_rcvd_eidle_rxstandby      (smlh_rcvd_eidle_rxstandby),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .smlh_lanes_active              (smlh_lanes_active),
    .smlh_no_turnoff_lanes          (smlh_no_turnoff_lanes),
    .smlh_ltssm_in_config           (smlh_ltssm_in_config),
    .xmlh_powerdown                 (tmp_xmlh_powerdown),
    .smlh_autoneg_link_width        (smlh_autoneg_link_width),
    .smlh_training_rst_n            (training_rst_n),
    .smlh_autoneg_link_sp           (smlh_autoneg_link_sp),
    .smlh_link_training_in_prog     (smlh_link_training_in_prog),
    .smlh_link_up                   (smlh_link_up),
    .smlh_req_rst_not               (smlh_req_rst_not),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .smlh_in_l0s                    (smlh_in_l0s),
    .smlh_in_l0                     (smlh_in_l0),
    .smlh_in_l1                     (smlh_in_l1),
    .smlh_in_l1_p1                  (smlh_in_l1_p1),
    .smlh_in_l23                    (smlh_in_l23),
    .smlh_l123_eidle_timeout        (smlh_l123_eidle_timeout),
    .latched_rcvd_eidle_set         (latched_rcvd_eidle_set),
    .smlh_bw_mgt_status             (smlh_bw_mgt_status),
    .smlh_link_auto_bw_status       (smlh_link_auto_bw_status),
    .smlh_dir_linkw_chg_rising_edge (smlh_dir_linkw_chg_rising_edge),
    .smlh_ltssm_in_hotrst_dis_entry (smlh_ltssm_in_hotrst_dis_entry),
    .smlh_mod_ts_rcvd               (smlh_mod_ts_rcvd),
    .mod_ts_data_rcvd               (mod_ts_data_rcvd),
    .mod_ts_data_sent               (mod_ts_data_sent_i),
    .rmlh_rcvd_err                  (rmlh_rcvd_err),
    .rmlh_rcvd_eidle_set            (rmlh_rcvd_eidle_set),

    .rdlh_prot_err                  (rdlh_prot_err),
    .rdlh_bad_tlp_err               (rdlh_bad_tlp_err),
    .rdlh_bad_dllp_err              (rdlh_bad_dllp_err),
    .rdlh_rtlh_link_state           (rdlh_dlcntrl_state),
    .rdlh_rcvd_as_req_l1            (rdlh_rcvd_as_req_l1),
    .rdlh_rcvd_pm_enter_l1          (rdlh_rcvd_pm_enter_l1),
    .rdlh_rcvd_pm_enter_l23         (rdlh_rcvd_pm_enter_l23),
    .rdlh_rcvd_pm_req_ack           (rdlh_rcvd_pm_req_ack),
    .rdlh_link_up                   (rdlh_link_up),
    .rdlh_link_down                 (rdlh_link_down),


    .xdlh_replay_num_rlover_err     (xdlh_replay_num_rlover_err),
    .xdlh_replay_timeout_err        (xdlh_replay_timeout_err),
    .xdlh_retrybuf_not_empty        (xdlh_retrybuf_not_empty),
    .xdlh_nodllp_pending            (xdlh_nodllp_pending),
    .xdlh_no_acknak_dllp_pending    (xdlh_no_acknak_dllp_pending),
    .xdlh_not_expecting_ack         (xdlh_not_expecting_ack),
    .xdlh_xmt_pme_ack               (xdlh_xmt_pme_ack),
    .xdlh_last_pmdllp_ack           (xdlh_last_pmdllp_ack),
    .xdlh_tlp_pending               (xdlh_tlp_pending),
    .xdlh_retry_pending             (xdlh_retry_pending),

    .rtlh_radm_hv                   (rtlh_radm_hv),
    .rtlh_radm_hdr                  (rtlh_radm_hdr),
    .rtlh_radm_dwen                 (rtlh_radm_dwen),
    .rtlh_radm_dv                   (rtlh_radm_dv),
    .rtlh_radm_data                 (rtlh_radm_data),
    .rtlh_radm_eot                  (rtlh_radm_eot),
    .rtlh_radm_ecrc_err             (rtlh_radm_ecrc_err),
    .rtlh_radm_malform_tlp_err      (rtlh_radm_malform_tlp_err),
    .rtlh_radm_dllp_err             (rtlh_radm_dllp_err),
    .rtlh_radm_ant_addr             (rtlh_radm_ant_addr),
    .rtlh_radm_ant_rid              (rtlh_radm_ant_rid),
    .rtlh_parerr                    (rtlh_parerr),

    .rtlh_fc_init_status            (rtlh_fc_init_status),
    .rtlh_crd_not_rtn               (rtlh_crd_not_rtn),
    .rtlh_rfc_upd                   (rtlh_rfc_upd),
    .rtlh_rfc_data                  (rtlh_rfc_data),
    .xtlh_xadm_restore_enable       (xtlh_xadm_restore_enable),
    .xtlh_xadm_restore_capture      (xtlh_xadm_restore_capture),
    .xtlh_xadm_restore_tc           (xtlh_xadm_restore_tc),
    .xtlh_xadm_restore_type         (xtlh_xadm_restore_type),
    .xtlh_xadm_restore_word_len     (xtlh_xadm_restore_word_len),

    .xtlh_tlp_pending               (xtlh_tlp_pending),
    .xtlh_data_parerr               (xtlh_data_parerr),
    .xtlh_xmt_cpl_ca                (xtlh_xmt_cpl_ca),
    .xtlh_xmt_cpl_ur                (xtlh_xmt_cpl_ur),
    .xtlh_xmt_cpl_poisoned          (xtlh_xmt_cpl_poisoned),
    .xtlh_xmt_wreq_poisoned         (xtlh_xmt_wreq_poisoned),
    .xtlh_xadm_halt                 (xtlh_xadm_halt),
    // from xtlh for keeping track of completions and handling of
    // completions -- Only applied to End-point
    .xtlh_xmt_tlp_done              (xtlh_xmt_tlp_done),
    .xtlh_xmt_tlp_done_early        (xtlh_xmt_tlp_done_early),
    .xtlh_xmt_cfg_req               (xtlh_xmt_cfg_req),             // N/A for endpoint
    .xtlh_xmt_memrd_req             (xtlh_xmt_memrd_req),
    .xtlh_xmt_ats_req               (xtlh_xmt_ats_req),
    .xtlh_xmt_atomic_req            (xtlh_xmt_atomic_req),
    .xtlh_xmt_tlp_req_id            (xtlh_xmt_tlp_req_id),
    .xtlh_xmt_tlp_tag               (xtlh_xmt_tlp_tag),
    .xtlh_xmt_tlp_attr              (xtlh_xmt_tlp_attr),
    .xtlh_xmt_tlp_tc                (xtlh_xmt_tlp_tc),
    .xtlh_xmt_tlp_len_inbytes       (xtlh_xmt_tlp_len_inbytes),
    .xtlh_xmt_tlp_first_be          (xtlh_xmt_tlp_first_be),

    .mac_phy_rate                   (tmp_int_mac_phy_rate),
    .current_data_rate              (current_data_rate),
    .pm_current_data_rate_others    (pm_current_data_rate_others),

    // Retry buffer external RAM interface


    .xdlh_retryram_addr             (xdlh_retryram_addr),
    .xdlh_retryram_data             (xdlh_retryram_data),
    .xdlh_retryram_we               (xdlh_retryram_we),
    .xdlh_retryram_en               (xdlh_retryram_en),
    .xdlh_retryram_par_chk_val      (xdlh_retryram_par_chk_val),
    .xdlh_retryram_halt             (xdlh_retryram_halt),

    .retryram_xdlh_data             (retryram_xdlh_data),
    .retryram_xdlh_depth            (retryram_xdlh_depth),
    .retryram_xdlh_parerr           (retryram_xdlh_parerr),
    .xdlh_retrysotram_waddr         (xdlh_retrysotram_waddr),
    .xdlh_retrysotram_raddr         (xdlh_retrysotram_raddr),
    .xdlh_retrysotram_data          (xdlh_retrysotram_data),
    .xdlh_retrysotram_en            (xdlh_retrysotram_en),
    .xdlh_retrysotram_we            (xdlh_retrysotram_we),
    .xdlh_retrysotram_par_chk_val   (xdlh_retrysotram_par_chk_val),

    .retrysotram_xdlh_depth         (retrysotram_xdlh_depth),
    .retrysotram_xdlh_parerr        (retrysotram_xdlh_parerr),
    .retrysotram_xdlh_data          (retrysotram_xdlh_data),
    // signals for debug purpose
    .cxpl_debug_info                (cxpl_debug_info),
    .cxpl_debug_info_ei             (cxpl_debug_info_ei),
    .rtfcgen_ph_diff                (rtfcgen_ph_diff),
    .rtlh_overfl_err                (rtlh_overfl_err),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),
    .lpbk_lane_under_test           (lpbk_lane_under_test),
    .ltssm_lane_flip_ctrl           (ltssm_lane_flip_ctrl),
    .xdlh_retry_req                 (xdlh_retry_req)
    ,
    .smlh_link_in_training          (smlh_link_in_training),
    .xdlh_replay_timer              (xdlh_replay_timer),
    .xdlh_rbuf_pkt_cnt              (xdlh_rbuf_pkt_cnt),
    .smlh_fast_time_1ms             (smlh_fast_time_1ms),
    .smlh_fast_time_2ms             (smlh_fast_time_2ms),
    .smlh_fast_time_3ms             (smlh_fast_time_3ms),
    .smlh_fast_time_4ms             (smlh_fast_time_4ms),
    .smlh_fast_time_10ms            (smlh_fast_time_10ms),
    .smlh_fast_time_12ms            (smlh_fast_time_12ms),
    .smlh_fast_time_24ms            (smlh_fast_time_24ms),
    .smlh_fast_time_32ms            (smlh_fast_time_32ms),
    .smlh_fast_time_48ms            (smlh_fast_time_48ms),
    .smlh_fast_time_100ms           (smlh_fast_time_100ms)
    ,
    .xdlh_match_pmdllp              (xdlh_match_pmdllp),
    .rtlh_radm_pending              (rtlh_radm_pending)
);    // u_cx_pl

assign xmlh_powerdown = int_xmlh_powerdown;




assign orig_pipe_rxdata = phy_mac_rxdata;
assign orig_pipe_rxdatak = phy_mac_rxdatak;
assign orig_pipe_rxvalid = phy_mac_rxvalid;
assign orig_pipe_rxstatus = phy_mac_rxstatus;
assign orig_pipe_rxdatavalid = phy_mac_rxdatavalid;
assign pre_mac_phy_txdata = fstep_mac_phy_txdata;
assign pre_mac_phy_txdetectrx_loopback = fstep_mac_phy_txdetectrx_loopback;

assign int_mac_phy_txelecidle = fstep_mac_phy_txelecidle;

// Assemble the PIPE control signals into a single bus to pass in/out of
// pipe_loopback module
struct packed {
  logic [NL-1:0]              elecidle;
  logic [NL-1:0]              datavalid;
}  rxctrl, txctrl, lpbk_ctrl;

localparam int  CTRL_WIDTH = $bits(rxctrl);
// 1: rxelecidle
// 4: startblock, datavalid, syncheader(2 bits)


// Pack Normal mode receive control signals
always_comb begin: rxctrl_PROC
  rxctrl.elecidle = sqlchd_rxelecidle;
  rxctrl.datavalid = orig_pipe_rxdatavalid;
end: rxctrl_PROC

// Pack loopback mode transmit control signals
always_comb begin: txctrl_PROC
  txctrl.elecidle = int_phy_txelecidle;

  txctrl.datavalid = pre_mac_phy_txdatavalid;

end: txctrl_PROC

// Unpack the loopback rx control signals
always_comb begin: lpbk_ctrl_PROC
  lpbk_rxelecidle = lpbk_ctrl.elecidle;
  lpbk_rxdatavalid = lpbk_ctrl.datavalid;
end: lpbk_ctrl_PROC

pipe_loopback

#(
    .INST (0), // uniquifying parameter for each port logic instance
    .NL (`CX_NL),
    .PHY_NB (`CX_PHY_NB),
    .CTRL_WIDTH (CTRL_WIDTH),// Control mux width varies with gen3 pipe i/f
    .PDWN_WIDTH (PDWN_WIDTH),// Width of powerdown input
    .RATE_WIDTH (RATE_WIDTH) // Width of powerdown input
) u_pipe_loopback
(
    .clk                            (core_clk_ug),
    .rst_n                          (core_rst_n),

    // Control Inputs
    .cfg_pipe_loopback              (cfg_pipe_loopback),
    .cfg_rxstatus_lane              (cfg_rxstatus_lane),
    .cfg_rxstatus_value             (cfg_rxstatus_value),
    .cfg_lpbk_rxvalid               (cfg_lpbk_rxvalid),
    .ext_pipe_loopback              (1'b0),     // May be connected to test pin

    // PIPE RX Inputs
    .rxdata                         (orig_pipe_rxdata),
    .rxdatak                        (orig_pipe_rxdatak),
    .rxvalid                        (orig_pipe_rxvalid),
    .rxctrl                         (rxctrl),
    .rxstatus                       (orig_pipe_rxstatus),
    .phystatus                      (phy_mac_phystatus),

    // PIPE TX Inputs
    .txdata                         (fstep_mac_phy_txdata),
    .txdatak                        (pre_mac_phy_txdatak),
    .txctrl                         (txctrl),
    .txdetectrx_loopback            (fstep_mac_phy_txdetectrx_loopback),
    .powerdown                      (pm_int_phy_powerdown),
    .rate                           (pre_mac_phy_rate),

    // PIPE Outputs
    .lpbk_rxdata                    (lpbk_rxdata),
    .lpbk_rxdatak                   (lpbk_rxdatak),
    .lpbk_rxvalid                   (lpbk_rxvalid),
    .lpbk_ctrl                      (lpbk_ctrl),
    .lpbk_rxstatus                  (lpbk_rxstatus),
    .lpbk_phystatus                 (lpbk_phystatus)
);

//
// Note: Not all features applied to end-point application
//
 assign int_phy_mac_rxdata = {{((NL*NB*8)-(8*PHY_NB*NL)){1'b0}},lpbk_rxdata};
 assign int_phy_mac_rxdatak = {{((NL*NB)-(PHY_NB*NL)){1'b0}},lpbk_rxdatak};
 assign int_phy_mac_rxvalid = lpbk_rxvalid;
 assign int_phy_mac_rxstatus = lpbk_rxstatus;
 assign int_phy_mac_rxelecidle = lpbk_rxelecidle;
 assign int_phy_mac_phystatus = regif_phystatus;
 assign int_phy_mac_rxstandbystatus = phy_mac_rxstandbystatus;
 assign int_phy_mac_rxdatavalid = lpbk_rxdatavalid_i;
 assign fstep_mac_phy_txdetectrx_loopback = int_mac_phy_txdetectrx_loopback;

 assign fstep_mac_phy_txdata = int_mac_phy_txdata;
 assign pre_mac_phy_txdatak = int_mac_phy_txdatak;
 assign pre_mac_phy_txcompliance = int_mac_phy_txcompliance;
 assign pre_mac_phy_rxpolarity = int_mac_phy_rxpolarity;
 assign pre_mac_phy_rxstandby = int_mac_phy_rxstandby;
 assign fstep_mac_phy_txelecidle = int_ltssm_txelecidle;
 assign tmp_mac_phy_rate_bus = {NL{int_mac_phy_rate}};

 assign tmp_mac_phy_rate = tmp_mac_phy_rate_bus[2:0];
 assign pre_mac_phy_width = adapted_pipe_mac_phy_width;
 assign pre_mac_phy_pclk_rate = adapted_pipe_mac_phy_pclk_rate;
 assign pre_mac_phy_powerdown = adapted_pipe_mac_phy_powerdown;


 assign pre_mac_phy_rate = tmp_mac_phy_rate[0];


always @( posedge core_clk or negedge core_rst_n ) begin : latched_mac_phy_txcompliance2_PROC
    if ( ~core_rst_n )
        latched_mac_phy_txcompliance <= #`TP 0;
    else if ( ~ltssm_all_detect_quiet )
        latched_mac_phy_txcompliance <= #`TP pre_mac_phy_txcompliance & fstep_mac_phy_txelecidle; //latch/keep pre_mac_phy_txcompliance when entry to S_DETECT_QUIET or S_PRE_DETECT_QUIET
end // latched_mac_phy_txcompliance2_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_d_PROC
    if ( ~core_rst_n )
        ltssm_d <= #`TP `S_DETECT_QUIET;
    else
        ltssm_d <= #`TP smlh_ltssm_state;
end // ltssm_d_PROC

assign dis_to_pre_detect_pulse = (smlh_ltssm_state == `S_PRE_DETECT_QUIET && ltssm_d == `S_DISABLED);

always @( posedge core_clk or negedge core_rst_n ) begin : latched_dis_to_pre_detect_PROC
    if ( ~core_rst_n )
        latched_dis_to_pre_detect <= #`TP 0;
    else if ( smlh_ltssm_state == `S_DETECT_QUIET )
        latched_dis_to_pre_detect <= #`TP 0;
    else if ( dis_to_pre_detect_pulse )
        latched_dis_to_pre_detect <= #`TP 1;
end // latched_dis_to_pre_detect_PROC

assign pre_detect_from_disabled = (smlh_ltssm_state == `S_PRE_DETECT_QUIET && (latched_dis_to_pre_detect | dis_to_pre_detect_pulse));

assign ltssm_all_detect_quiet = (smlh_ltssm_state == `S_DETECT_QUIET || smlh_ltssm_state == `S_PRE_DETECT_QUIET) && ~pre_detect_from_disabled;
wire   ltssm_in_L2            = (smlh_ltssm_state == `S_L2_IDLE || smlh_ltssm_state == `S_L2_WAKE);

// from a glue logic based on pre_mac_phy_txcompliance to avoid pipe spec violation
always @( * ) begin : glue_mac_phy_txcompliance_PROC
    glue_mac_phy_txcompliance = 0;

    if ( (ltssm_all_detect_quiet || ltssm_in_L2) && mac_phy_powerdown == 4'b0010 ) // powerdown = P1 & in Detect.Quiet state or S_PRE_DETECT_QUIET or L2
        glue_mac_phy_txcompliance = 0;
    else if ( ltssm_all_detect_quiet )
        glue_mac_phy_txcompliance = latched_mac_phy_txcompliance; // else, keep unchanged on entry to S_DETECT_QUIET during S_DETECT_QUIET or S_PRE_DETECT_QUIET
    else
        glue_mac_phy_txcompliance = pre_mac_phy_txcompliance; // else, keep pre_mac_phy_txcompliance
end // glue_mac_phy_txcompliance_PROC

// The Local Bus Controller
lbc

#(INST) u_lbc (
    // -- inputs --
    .core_clk                       (aux_clk_g),
    .core_rst_n                     (core_rst_n),
    .cfg_pbus_num                   (cfg_pbus_num),
    .cfg_pbus_dev_num               (cfg_pbus_dev_num),
    .device_type                    (int_device_type),
    .cfg_bar0_mask                  (cfg_bar0_mask),
    .cfg_bar1_mask                  (cfg_bar1_mask),
    .cfg_bar2_mask                  (cfg_bar2_mask),
    .cfg_bar3_mask                  (cfg_bar3_mask),
    .cfg_bar4_mask                  (cfg_bar4_mask),
    .cfg_bar5_mask                  (cfg_bar5_mask),
    .radm_dv                        (radm_trgt0_dv),
    .radm_hv                        (radm_trgt0_hv),
    .radm_hdr                       (radm_trgt0_hdr[RADM_P_HWD-1:0]),
    .radm_data                      (radm_trgt0_data[DW_WO_PAR-1:0]),
    .radm_eot                       (radm_trgt0_eot),
    .radm_abort                     (radm_trgt0_abort),
    .radm_trgt0_pending             (radm_trgt0_pending),

    // local bus interface with external registers
    .ext_lbc_ack                    (ext_lbc_ack),
    .ext_lbc_din                    (ext_lbc_din),
    // from cdm
    .cdm_lbc_din                    (cdm_lbc_data),
    .cdm_lbc_ack                    (cdm_lbc_ack),
   // from  XADM
    .xadm_cpl_halt                  (xadm_cpl_halt),

    //memory mapped device
    // external dbi interface designed for outband access
    .dbi_addr                       (int_dbi_addr),
    .dbi_din                        (int_dbi_din),
    .dbi_cs                         (int_dbi_cs),
    .dbi_cs2                        (int_dbi_cs2),
    .dbi_wr                         (int_dbi_wr),




    .cfg_config_limit               (cfg_config_limit),
     
//----------- outputs -------------------------
    // external dbi interface designed for outband access
    .lbc_dbi_dout                   (int_lbc_dbi_dout),
    .lbc_dbi_ack                    (int_lbc_dbi_ack),

    // to XADM as completion request of device local bus read or write
    .lbc_cpl_hv                     (lbc_cpl_hv),
    .lbc_cpl_dv                     (lbc_cpl_dv),
    .lbc_cpl_hdr                    (lbc_cpl_hdr),
    .lbc_cpl_data                   (lbc_cpl_data),
    .lbc_cpl_eot                    (lbc_cpl_eot),

    .lbc_xmt_cpl_ca                 (lbc_xmt_cpl_ca),

    // local bus interface with cdm to read registers locally
    .lbc_cdm_addr                   (lbc_cdm_addr),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_cs                     (lbc_cdm_cs),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),
    // local bus interface with external registers
    .lbc_ext_addr                   (lbc_ext_addr),
    .lbc_ext_dout                   (lbc_ext_dout),
    .lbc_ext_cs                     (lbc_ext_cs),
    .lbc_ext_wr                     (lbc_ext_wr),
    .lbc_ext_rom_access             (lbc_ext_rom_access),
    .lbc_ext_io_access              (lbc_ext_io_access),
    .lbc_ext_bar_num                (lbc_ext_bar_num),





    //DE: Deadlock fix
    .pm_l1_aspm_entr                (pm_l1_aspm_entr),
    .lbc_deadlock_det               (lbc_deadlock_det),
    .rtfcgen_ph_diff                (rtfcgen_ph_diff),         //input

    // radm block interface control signal to allowback pressure applied to radm queues.
    .trgt0_radm_halt                (trgt0_radm_halt),
    .lbc_active                     (lbc_active)


); // lbc


// -----------------------------------------------------------------------------
// Message TLP Generation
// -----------------------------------------------------------------------------

msg_gen

#(INST) u_msg_gen(
// ---------- Inputs --------
    .core_rst_n                     (core_rst_n),
    .core_clk                       (core_clk),
    .device_type                    (int_device_type),
    .pm_xtlh_block_tlp              (pm_xtlh_block_tlp),
    .cfg_nond0_vdm_block            (cfg_nond0_vdm_block),
    .pm_pme                         (pm_xmt_pme),
    .pm_asnak                       (pm_xmt_asnak),                 // N/A for endpoint
    .pme_turn_off                   (pm_xmt_turnoff),               // N/A for endpoint
    .pme_to_ack                     (pm_xmt_to_ack),
    .send_cor_err                   (cfg_send_cor_err),
    .send_nf_err                    (cfg_send_nf_err),
    .send_f_err                     (cfg_send_f_err),
    .cfg_func_spec_err              (cfg_func_spec_err),
    .unlock                         (pm_unlock_msg_req),            // N/A for endpoint
    .inta_wire                      (inta_wire),
    .intb_wire                      (intb_wire),
    .intc_wire                      (intc_wire),
    .intd_wire                      (intd_wire),
//    .nhp_int                        ({NF{1'b0}}),                   // not used
    .cfg_bus_master_en              (cfg_bus_master_en),
    .cfg_slot_pwr_limit_wr          (cfg_slot_pwr_limit_wr[0]),     // N/A for endpoint
    .rdlh_link_up                   (rdlh_link_up),
    .pm_bus_num                     (pm_bus_num),
    .pm_dev_num                     (pm_dev_num),
    .cfg_pbus_num                   (cfg_pbus_num),
    .cfg_pbus_dev_num               (cfg_pbus_dev_num),
    .cfg_msi_addr                   (cfg_msi_addr),
    .cfg_msi_data                   (cfg_msi_data),
    .cfg_msi_64                     (cfg_msi_64),
    .cfg_multi_msi_en               (cfg_multi_msi_en),
//    .hp_msi_request                 ({NF{1'b0}}),                   // Only for SW Upstream
    .cfg_msix_en                    (cfg_msix_en),                  // N/A for RC
    .msix_addr                      (msix_addr),                    // N/A for RC
    .msix_data                      (msix_data),                    // N/A for RC
    .ven_msi_req                    (ven_msi_req),                  // N/A for RC
    .ven_msi_func_num               (ven_msi_func_num),              // N/A for RC

    .ven_msi_tc                     (ven_msi_tc),                   // N/A for RC
    .ven_msi_vector                 (ven_msi_vector),               // N/A for RC

    .xadm_msg_halt                  (xadm_msg_halt),
    .set_slot_pwr_limit_val         (cfg_slot_pwr_limit_val),
    .set_slot_pwr_limit_scale       (cfg_slot_pwr_limit_scale),

    .ven_msg_fmt                    (ven_msg_fmt),
    .ven_msg_type                   (ven_msg_type),
    .ven_msg_tc                     (ven_msg_tc),
    .ven_msg_td                     (ven_msg_td),
    .ven_msg_ep                     (ven_msg_ep),
    .ven_msg_attr                   (ven_msg_attr),
    .ven_msg_len                    (ven_msg_len),
    .ven_msg_func_num               (ven_msg_func_num),
    .ven_msg_tag                    (ven_msg_tag),
    .ven_msg_code                   (ven_msg_code),
    .ven_msg_data                   (ven_msg_data),
    .ven_msg_req                    (ven_msg_req),

    .pm_dstate                      (pm_dstate),

    .cfg_auto_slot_pwr_lmt_dis      (cfg_auto_slot_pwr_lmt_dis), 


// ---------- Outputs --------
    .msg_gen_hv                     (msg_gen_hv),
    .msg_gen_dv                     (msg_gen_dv),
    .msg_gen_eot                    (msg_gen_eot),
    .msg_gen_data                   (msg_gen_data),
    .msg_gen_hdr                    (msg_gen_hdr),

    .assert_inta_grt            (assert_inta_grt),
    .assert_intb_grt            (assert_intb_grt),
    .assert_intc_grt            (assert_intc_grt),
    .assert_intd_grt            (assert_intd_grt),
    .deassert_inta_grt          (deassert_inta_grt),
    .deassert_intb_grt          (deassert_intb_grt),
    .deassert_intc_grt          (deassert_intc_grt),
    .deassert_intd_grt          (deassert_intd_grt),
    .ven_msg_grant                  (ven_msg_grant),
    .ven_msi_grant                  (ven_msi_grant),                // N/A for RC
    .pme_to_ack_grt                 (pme_to_ack_grt),
    .pm_pme_grant                   (pm_pme_grant),
    .pme_turn_off_grt               (pme_turn_off_grt)
    ,
    .msg_gen_asnak_grt              (msg_gen_asnak_grt),
    .msg_gen_unlock_grant           (msg_gen_unlock_grant)
); // msg_gen

// ----------------------------------------------------------------------
// Instantiate reset request control logic
// ----------------------------------------------------------------------



  DWC_pcie_rst_ctl
  
  u_rstctl
  (
  // Clocks and resets
  .core_clk                           (core_clk)
  ,.core_rst_n                        (core_rst_n)
  // Link Info interface
  ,.smlh_req_rst_not                  (smlh_req_rst_not)
  // Reset Request Interface
  ,.rstctl_req_rst_not                (link_req_rst_not)
  );

  assign rstctl_ltssm_enable   = app_ltssm_enable;
  assign rstctl_core_flush_req = 1'b0;
  assign rstctl_slv_flush_req  = 1'b0;
  assign rstctl_mstr_flush_req = 1'b0;
  assign rstctl_flush_done     = 1'b0;


//---------------------------------------------------------------------------------------
// Assign Outputs
//---------------------------------------------------------------------------------------

// ================================= Diagnostic Bus Assignment =================================================
// Diagnostic mechanism is designed in core by routing the important internal signals to application dynamically.
// Diagnostic mechanism is designed in core by taking control signals from application to insert a defined behavor of the core.
// Diagnotic status signals are groupped together from different layers of the core


//---------------------------------------------------------------------------------------
// Functions
//---------------------------------------------------------------------------------------
 // Function to grab a byte from a bus
function automatic [15:0] get_req_id;
input   [BUSNUM_WD -1:0]            bus_num;
input   [DEVNUM_WD -1:0]            dev_num;
input   [PF_WD-1:0]                 func_num;
input    [3:0]                      device_type;
integer                             i;
reg     [7:0]                       int_bus_num;
reg     [4:0]                       int_dev_num;
reg     [7:0]                       int_func_num;

begin
    int_bus_num = 0;
    int_dev_num = 0;
    int_func_num = 0;
    int_func_num[PF_WD-1:0]    = func_num[PF_WD-1:0]   ;
    int_bus_num = bus_num;
    int_dev_num = dev_num;
    get_req_id     = {int_bus_num, int_dev_num, int_func_num[2:0]};
end
endfunction

// Function to grab a byte from a bus
function automatic [7:0] Bget;
input   [BUSNUM_WD-1:0]                vector;
input   [NF-1:0]                    onehot_index;
integer                             i;

begin
    Bget = vector[7:0];
end
endfunction

// Function to grab a 5-bit slice from a bus
function automatic [4:0] Qget;
input   [DEVNUM_WD-1:0]                vector;
input   [NF-1:0]                    onehot_index;
integer                             i;

begin
    Qget = vector[4:0];
end
endfunction


// Function to assign 1 bit radm_rtlh_*h_ca to multi-bits int_rtlh_*h_ca
function automatic [DCA_WD*NVC-1:0] credit_mapping;
input   [NVC-1:0]                radm_h_ca;
integer                             i;

begin
    credit_mapping = 0;
    for(i=0;i<NVC;i=i+1) begin
            credit_mapping[i*DCA_WD] = radm_h_ca[i];
    end
end
endfunction

`ifndef SYNTHESIS
`endif // SYNTHESIS

`endif // `ifndef SNPS_PCIE_SATB

endmodule
