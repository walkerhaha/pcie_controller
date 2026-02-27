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
// ---    $DateTime: 2020/11/09 14:42:54 $
// ---    $Revision: #23 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_dm.sv#23 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Recieve Application Dependent Module (dual-mode
// --- version. It is intended for either end-point or RC application interface
// --- with the cxpl core.
// --- This module contains:
// ---      (1) Interface to RTLH module (filter)
// ---      (2) data path width conversion (formation)
// ---      (3) Filter msg/p/np/cpl TLPs (filter),
// ---      (4) Queue Managment for TLPs except for cpl tlps and  message tlps (Q)
// ---      (5) Completion tlp Interface to application (filter)
// ---      (6) provide Completion TAG LUT.
// ---      (7) Managing the credit buffer to assist FC generation (Q)
// ---      (8) demultiplex P/NP to trgt* with back pressure support.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Adm/radm_defs_pkg.svh"


 
 module radm_dm
import radm_defs_pkg::*;
   (
    // ------------- Inputs ---------------
    core_clk,
    core_rst_n,
    radm_clk_ug,
    cfg_radm_clk_control,
    rstctl_core_flush_req,
    upstream_port,
    app_req_retry_en,
    app_pf_req_retry_en,
    device_type,
    cfg_rcb_128,
    cfg_pbus_dev_num,
    cfg_pbus_num,
    cfg_ecrc_chk_en,
    cfg_max_func_num,
    cfg_radm_q_mode,
    cfg_radm_order_rule,
    cfg_order_rule_ctrl,
    cfg_radm_strict_vc_prior,
    cfg_hq_depths,
    cfg_dq_depths,
    rtlh_radm_dv,
    rtlh_radm_data,
    rtlh_radm_dwen,
    rtlh_radm_hdr,
    rtlh_radm_hv,
    rtlh_radm_eot,
    rtlh_radm_dllp_err,
    rtlh_radm_malform_tlp_err,
    rtlh_radm_ecrc_err,
    rtlh_radm_ant_addr,
    rtlh_radm_ant_rid,

       trgt1_radm_pkt_halt,
       bridge_trgt1_radm_pkt_halt,
       trgt_lut_trgt1_radm_pkt_halt,

    trgt0_radm_halt,
    trgt1_radm_halt,
    // from xtlh for keeping track of completions and handling of completions
    xtlh_xmt_tlp_done,
    xtlh_xmt_tlp_done_early,
    xtlh_xmt_cfg_req,
    xtlh_xmt_memrd_req,
    xtlh_xmt_ats_req,
    xtlh_xmt_atomic_req,
    xtlh_xmt_tlp_req_id,
    xtlh_xmt_tlp_tag,
    xtlh_xmt_tlp_attr,
    xtlh_xmt_tlp_tc,
    xtlh_xmt_tlp_len_inbytes,
    xtlh_xmt_tlp_first_be,

    cfg_bar_is_io,
    cfg_io_match,
    cfg_config_above_match,
    cfg_bar_match,
    cfg_rom_match,
    cfg_mem_match,
    cfg_prefmem_match,
    cfg_tc_struc_vc_map,
    cfg_filter_rule_mask,
    cfg_cpl_timeout_disable,
    pm_radm_block_tlp,
    pm_freeze_cpl_timer,

    target_mem_map,
    target_rom_map,

    current_data_rate,
    phy_type,



    default_target,
    ur_ca_mask_4_trgt1,
    cfg_target_above_config_limit,
    cfg_cfg_tlp_bypass_en, 
    cfg_p2p_track_cpl_to, 
    cfg_p2p_err_rpt_ctrl,
    cfg_2ndbus_num,
    cfg_subbus_num,
    rtlh_radm_pending,

    // ------------- Outputs ---------------

    radm_idle,
    radm_clk_en,

    flt_cdm_addr,
    flt_cdm_rtlh_radm_pending, // Enable for flt_cdm_addr
    radm_rtlh_ph_ca,
    radm_rtlh_pd_ca,
    radm_rtlh_nph_ca,
    radm_rtlh_npd_ca,
    radm_rtlh_cplh_ca,
    radm_rtlh_cpld_ca,
    radm_qoverflow,
    //  completion type tlp processed outputs
    radm_bypass_data,
    radm_bypass_dwen,
    radm_bypass_dv,
    radm_bypass_hv,
    radm_bypass_eot,
    radm_bypass_dllp_abort,
    radm_bypass_tlp_abort,
    radm_bypass_ecrc_err,
    radm_bypass_fmt,
    radm_bypass_type,
    radm_bypass_tc,
    radm_bypass_attr,
    radm_bypass_reqid,
    radm_bypass_tag,
    radm_bypass_func_num,

    radm_bypass_cpl_status,
    radm_bypass_td,
    radm_bypass_poisoned,
    radm_bypass_dw_len,
    radm_bypass_first_be,
    radm_bypass_bcm,
    radm_bypass_byte_cnt,
    radm_bypass_cmpltr_id,
    radm_bypass_cpl_last,
    radm_bypass_addr,
    radm_bypass_rom_in_range,
    radm_bypass_io_req_in_range,
    radm_bypass_in_membar_range,
    radm_bypass_last_be,
    radm_grant_tlp_type,
    radm_pend_cpl_so,
    radm_q_cpl_not_empty,
    //  non posted type tlp processed outputs
    radm_trgt0_dv,
    radm_trgt0_hv,
    radm_trgt0_hdr,
    radm_trgt0_data,
    radm_trgt0_dwen,
    radm_trgt0_eot,
    radm_trgt0_abort,
    radm_trgt0_ecrc_err,

    radm_trgt1_data,
    radm_trgt1_hdr,
    radm_trgt1_dwen,
    radm_trgt1_dv,
    radm_trgt1_hv,
    radm_trgt1_eot,
    radm_trgt1_dllp_abort,
    radm_trgt1_tlp_abort,
    radm_trgt1_ecrc_err,

    radm_trgt1_fmt,
    radm_trgt1_type,
    radm_trgt1_tc,
    radm_trgt1_attr,
    radm_trgt1_reqid,
    radm_trgt1_tag,
    radm_trgt1_func_num,
    radm_trgt1_cpl_status,
    radm_trgt1_td,
    radm_trgt1_poisoned,
    radm_trgt1_dw_len,
    radm_trgt1_first_be,
    radm_trgt1_bcm,
    radm_trgt1_byte_cnt,
    radm_trgt1_cmpltr_id,
    radm_trgt1_cpl_last,
    radm_trgt1_vc_num,

    radm_trgt1_addr,
    radm_trgt1_hdr_uppr_bytes,

    radm_trgt1_rom_in_range,
    radm_trgt1_io_req_in_range,
    radm_trgt1_in_membar_range,
    radm_trgt1_last_be,
    radm_trgt1_msgcode,
    // output to application to notify the time out of a completion
    // for application to return its buffer
    radm_cpl_lut_valid,
    radm_cpl_timeout,
    radm_cpl_timeout_cdm,
    radm_timeout_cpl_tc,
    radm_timeout_cpl_attr,
    radm_timeout_cpl_len,
    radm_timeout_cpl_tag,
    radm_timeout_func_num,

    radm_msg_payload,
    radm_pm_pme,
    radm_pm_to_ack,
    radm_vendor_msg,
    radm_pm_turnoff,
    radm_pm_asnak,
    radm_slot_pwr_limit,
    radm_slot_pwr_payload,
    radm_msg_unlock,
    radm_inta_asserted,
    radm_intb_asserted,
    radm_intc_asserted,
    radm_intd_asserted,
    radm_inta_deasserted,
    radm_intb_deasserted,
    radm_intc_deasserted,
    radm_intd_deasserted,
    radm_correctable_err,
    radm_nonfatal_err,
    radm_fatal_err,

    radm_msg_req_id,
    cdm_err_advisory,
    radm_unexp_cpl_err,
    radm_cpl_pending,
    radm_rcvd_cpl_ur,
    radm_rcvd_cpl_ca,
    radm_ecrc_err,
    radm_mlf_tlp_err,
    radm_rcvd_wreq_poisoned,
    radm_rcvd_cpl_poisoned,
    radm_rcvd_req_ur,
    radm_rcvd_req_ca,
    radm_hdr_log_valid,
    radm_hdr_log,
    radm_q_not_empty,

// ---- RAM external interface, Combine of inputs and outputs
    p_dataq_addra,
    p_dataq_addrb,
    p_dataq_datain,
    p_dataq_dataout,
    p_dataq_ena,
    p_dataq_enb,
    p_dataq_wea,
    p_dataq_parerr,
    p_dataq_par_chk_val,
    p_dataq_parerr_out,
    p_hdrq_addra,
    p_hdrq_addrb,
    p_hdrq_datain,
    p_hdrq_dataout,
    p_hdrq_ena,
    p_hdrq_enb,
    p_hdrq_wea,
    p_hdrq_parerr,
    p_hdrq_par_chk_val,
    p_hdrq_parerr_out,

    


    // ---- outputs to msg_gen -------------------------

    radm_parerr,
    radm_trgt0_pending,
    radm_snoop_upd,
    radm_snoop_bus_num,
    radm_snoop_dev_num

);

localparam TAG_SIZE             = `CX_TAG_SIZE;
localparam TAG_SIZE8            = 8; // radm_cpl_tag !RADM_SEG_BUF ARCH

localparam XTLH_PIPE_DELAY = 1
 ;

parameter INST                  = 0;                        // The uniquifying parameter for each port logic instance.
parameter NW                    = `CX_NW;                   // Number of 32-bit dwords handled by the datapath each clock.
parameter NF                    = `CX_NFUNC;                // Number of functions
parameter NL                    = `CX_NL;                   // Number of lanes
parameter NB                    = `CX_NB;                   // Number of bytes per cycles
parameter DW                    = (32*NW);                  // Width of datapath in bits.
parameter HW                    = 128;                      // Width of header in bits.
parameter NVC                   = `CX_NVC;                  // Number of Virtual Channels
parameter NHQ                   = (NW==8) ? 2 : 1;          // Number of Header Queues per VC
parameter NDQ                   = `CX_NDQ;                  // Number of Data Queues per VC
parameter L2N_INTFC             = 1;                        // the number of application interfaces with XADM block
parameter FLT_Q_HDR_WIDTH       = `FLT_Q_HDR_WIDTH;
parameter DATAQ_WD              = NW+NDQ*(1+1+1+1+1)+DW;

parameter P_HDRQ_NECC_BITS      = `P_HDRQ_NECC_BITS;
parameter P_DATAQ_NECC_BITS     = `P_DATAQ_NECC_BITS;

parameter DATAQ_WDEC            = DATAQ_WD;
parameter RADM_PQ_HWD           = `CX_RADM_PQ_HWD;
parameter RADM_NPQ_HWD          = `CX_RADM_NPQ_HWD;
parameter RADM_CPLQ_HWD         = `CX_RADM_CPLQ_HWD;

parameter RADM_PQ_HWDEC         = `CX_RADM_PQ_HWD;
parameter RADM_NPQ_HWDEC        = `CX_RADM_NPQ_HWD;
parameter RADM_CPLQ_HWDEC       = `CX_RADM_CPLQ_HWD;
parameter RADM_PQ_HPW           = `RADM_PQ_HPW;
parameter RADM_NPQ_HPW          = `RADM_NPQ_HPW;
parameter RADM_CPLQ_HPW         = `RADM_CPLQ_HPW;
parameter RADM_PQ_DPW           = `RADM_PQ_DPW;
parameter RADM_NPQ_DPW          = `RADM_NPQ_DPW;
parameter RADM_CPLQ_DPW         = `RADM_CPLQ_DPW;
parameter PAR_CALC_WIDTH        = `DATA_BUS_PAR_CALC_WIDTH;
parameter DATA_PAR_WD           = `TRGT_DATA_PROT_WD;       // data bus parity width
//parameter FLT_OUT_PROT_WD       = `CX_FLT_OUT_PROT_WD; 

// header protection code covers the complete header
parameter HDR_PROT_WD           = `CX_RAS_PCIE_HDR_PROT_WD;
// width of the protection code used for the "compressed header, from filter_ep onwards
parameter FLT_OUT_PROT_WD       = `CX_FLT_OUT_PROT_WD;
parameter TRGT_HDR_WD           = `TRGT_HDR_WD;


parameter RAS_PCIE_HDR_PROT_WD  = `CX_RAS_PCIE_HDR_PROT_WD;
parameter RADM_P_HWD_WO_PAR     = `RADM_P_HWD;
parameter RADM_NP_HWD_WO_PAR    = `RADM_NP_HWD;
parameter RADM_CPL_HWD_WO_PAR   = `RADM_CPL_HWD;
parameter RADM_P_HWD            = `RADM_P_HWD + FLT_OUT_PROT_WD;
parameter RADM_NP_HWD           = `RADM_NP_HWD + HDR_PROT_WD;
parameter RADM_CPL_HWD          = `RADM_CPL_HWD + HDR_PROT_WD;
parameter DW_PAR                = DW + DATA_PAR_WD;
parameter BUSNUM_WD             = `CX_BUSNUM_WD;            // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD             = `CX_DEVNUM_WD;            // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter N_FLT_MASK            = `CX_N_FLT_MASK;
parameter NUM_SEGMENTS          = `CX_NUM_SEGMENTS;
parameter RADM_SBUF_HDRQ_WD     = `CX_RADM_SBUF_HDRQ_WD;
parameter RADM_SBUF_HDRQ_PW     = `CX_RADM_SBUF_HDRQ_PW;
parameter RADM_SBUF_DATAQ_RAM_WD    = `CX_RADM_SBUF_DATAQ_RAM_WD;
parameter RADM_SBUF_DATAQ_PW    = `CX_RADM_SBUF_DATAQ_PW;

parameter SEG_WIDTH             = `CX_SEG_WIDTH;
parameter CPL_LUT_DEPTH         = `CX_MAX_TAG +1;           // number of max tag that this core is configured to run
parameter NVF                   = `CX_NVFUNC;               // Number of virtual functions
parameter INT_NVF               = `CX_INTERNAL_NVFUNC;    // Number of Internal virtual functions
parameter PF_WD                 = `CX_NFUNC_WD;             // Width of physical function number signal
// derived params
localparam VFI_WD               = `CX_LOGBASE2(NVF);      // number of bits needed to represent the vf index [0 ... NVF-1]
localparam VF_WD                = `CX_LOGBASE2(NVF) + 1;  // number of bits needed to represent the vf number plus one bit to indicate vf_active, i.e. if the pf,vf pair indicates a pf only or a vf within a pf
localparam RX_TLP               = `CX_RX_TLP;             // Number of TLPs that can be received in a single cycle
localparam FX_TLP               = `CX_FX_TLP;             // Number of TLPs that can be processed in a single cycle after the formation block
localparam DIAG_WD              = (FX_TLP == 2) ? ((`CX_RADM_DIAG_STATUS_BUS_WD - 1) >> 1) : `CX_RADM_DIAG_STATUS_BUS_WD; // Per TLP width of Diagnostic Information

parameter CPL_ENTRY_WIDTH      = 2 + 3 + PF_WD + NP_REQ_TYPE_WD
                                 ;

parameter  DCA_WD               = `CX_LOGBASE2(NW/4+1);

parameter TP = `TP;      // Clock to Q delay (simulator insurance)
parameter TRGT_DATA_WD          = `TRGT_DATA_WD;

localparam DW_OUT_W_PAR         = DW+DATA_PAR_WD;
localparam TRGT1_ADDR_WD        = `FLT_Q_ADDR_WIDTH; 
localparam ATTR_WD              = `FLT_Q_ATTR_WIDTH;
parameter NHQ_LOG2              = `CX_LOGBASE2(NHQ);





// -------------------------------- Inputs -------------------------------------
input                           core_clk;                   // Core clock
input                           core_rst_n;                 // Core system reset
input                           radm_clk_ug;                // ungated radm clock (connect to core_clk)
input                           cfg_radm_clk_control;       // enable clock gating in the radm
input                           rstctl_core_flush_req;
input                           upstream_port;
input                           app_req_retry_en;           // Allow application to enable LBC to return request retry status
                                                            // to all configuration accesses
input   [NF-1:0]                app_pf_req_retry_en;        // Allow application to enable LBC to return request retry status, per PF Function
                                                            // to all configuration accesses
input   [3:0]                   device_type;
input                           cfg_rcb_128;
input   [BUSNUM_WD -1:0]        cfg_pbus_num;               // Bus number
input   [DEVNUM_WD -1:0]        cfg_pbus_dev_num;           // Device number
input   [NF-1:0]                cfg_ecrc_chk_en;            // ECRC Check enables
input   [PF_WD-1:0]             cfg_max_func_num;           // (PL) Highest accepted function number
input   [(NVC*3*3)-1:0]         cfg_radm_q_mode;            // Indicates that queue is in bypass, cut-through, and store-forward mode for posted TLP.
                                                            // 3bits per VC, bit0 for bypass, bit1 for cut-through and bit2 for store and forward
                                                            // 3bits for type posted, non posted and completion
input                           cfg_radm_strict_vc_prior;   // 1 indicates strict priority, 0 indicates round roubin
input   [NVC-1:0]               cfg_radm_order_rule;        // Indicates what scheme the order queue selection mechanism should be used
                                                            // Currently there are two  scheme used, 1'b1 for order reserved scheme,
                                                            // 1'b0 used for strict priority scheme
input   [15:0]                  cfg_order_rule_ctrl;        // cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC 

input   [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0] cfg_hq_depths;  // Indicates the depth of the header queues per type per vc
input   [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]cfg_dq_depths;  // Indicates the depth of the data queues per type per vc
input   [RX_TLP-1:0]            rtlh_radm_dv;               // When asserted; indicates the payload id valid
input   [RX_TLP-1:0]            rtlh_radm_hv;               // When asserted; indicates the hdr valid
input   [RX_TLP-1:0]            rtlh_radm_eot;              // When asserted; indicates the tlp end
input   [(DW+DATA_PAR_WD)-1:0]  rtlh_radm_data;             // Data payload
input   [(RX_TLP*(128+HDR_PROT_WD))-1:0] rtlh_radm_hdr;     // hdr payload
input   [NW-1:0]                rtlh_radm_dwen;             // Indicates ending DWORD of TLP packet
input   [RX_TLP-1:0]            rtlh_radm_dllp_err;         // Indication that TLP has dllp err (valid @ EOT)
input   [RX_TLP-1:0]            rtlh_radm_malform_tlp_err;  // Indication that TLP is malformed (valid @ HV)
input   [RX_TLP-1:0]            rtlh_radm_ecrc_err;         // Indication that TLP has ECRC err (valid @ EOT)
input   [(RX_TLP*64)-1:0]       rtlh_radm_ant_addr;         // anticipated address (1 clock earlier)
input   [(RX_TLP*16)-1:0]       rtlh_radm_ant_rid;          // anticipated RID (1 clock earlier)

input                           trgt1_radm_halt;            // trgt1 back pressure signal
input [(NVC*3)-1:0]             trgt1_radm_pkt_halt;          // Halt for order queue to select in packet unit
input [(NVC*3)-1:0]             bridge_trgt1_radm_pkt_halt;   // Halt for order queue to select in packet unit from the bridge tracker
input [(NVC*3)-1:0]             trgt_lut_trgt1_radm_pkt_halt; // Halt for order queue to select in packet unit from the xadm.trgt_lut tracker 
input [3*NVC-1:0]               trgt0_radm_halt;            // trgt0 back pressure signal

input                           xtlh_xmt_tlp_done;          // transmitted TLP is done
input                           xtlh_xmt_tlp_done_early;    // unregistered version of xtlh_xmt_tlp_done 
input                           xtlh_xmt_cfg_req;           // current transmitted TLP is a configuration type
input                           xtlh_xmt_memrd_req;         // current transmitted TLP is a MemRd
input                           xtlh_xmt_ats_req ;          // current transmitted TLP is a MemRd for ATS Request
input                           xtlh_xmt_atomic_req ;       // current transmitted TLP is an Atomic Request
input   [15:0]                  xtlh_xmt_tlp_req_id;        // Transmitted tlp request id
input   [TAG_SIZE-1:0]          xtlh_xmt_tlp_tag;           // transmitted TLP tag
input   [1:0]                   xtlh_xmt_tlp_attr;          // transmitted TLP attibutes
input   [2:0]                   xtlh_xmt_tlp_tc;            // transmitted TLP tc
input   [11:0]                  xtlh_xmt_tlp_len_inbytes;   // transmitted TLP length in bytes
input   [3:0]                   xtlh_xmt_tlp_first_be;      // transmitted TLP first be

input   [(NF*6)-1:0]            target_mem_map;             // Each bit of this vector indicates which target receives memory transactions for that bar #

input   [ NF-1:0]               target_rom_map;             // Each bit of this vector indicates which target receives rom    transactions for that bar #


input   [(NF*6)-1:0]            cfg_bar_is_io;              // indication that tlp is within MEM BAR, which is IO space
input   [(FX_TLP*NF)-1:0]       cfg_io_match;               // TIED low for EP
input   [(FX_TLP*NF)-1:0]       cfg_config_above_match;     // configuaration access belongs to the above our customer set address limit so that target1 interface will be the detination of the configuration rd/wr.
input   [(FX_TLP*NF)-1:0]       cfg_rom_match;              // indication that tlp is within a ROM BAR
input   [(FX_TLP*NF*6)-1:0]     cfg_bar_match;              // indication that tlp is within a MEM BAR
input   [(FX_TLP*NF)-1:0]       cfg_mem_match;              // memory match indication for RC device
input   [(FX_TLP*NF)-1:0]       cfg_prefmem_match;          // prefetch memory match indication for RC device
input   [23:0]                  cfg_tc_struc_vc_map;        // TC to VC Structure mapping
input   [NF-1:0]                pm_radm_block_tlp;          // when this signal is active, only CFG/MSG are valid TLP's

input                           pm_freeze_cpl_timer;        // when this signal is active, freeze the completion timeout timer

input   [N_FLT_MASK-1:0]        cfg_filter_rule_mask;       // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
input   [NF-1:0]                cfg_cpl_timeout_disable;    // Completion timeout disable

input   [2:0]                   current_data_rate;          // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4
input                           phy_type;                   // Mac type





input                           default_target;
input                           ur_ca_mask_4_trgt1;
input [1:0]                     cfg_target_above_config_limit;
input                           cfg_cfg_tlp_bypass_en;
input                           cfg_p2p_track_cpl_to;
input                           cfg_p2p_err_rpt_ctrl;

input  [(8*NF)-1:0]              cfg_2ndbus_num;           // configured primary bus number, it will be reserved during power down if PMC module is populated
input  [(8*NF)-1:0]              cfg_subbus_num;           // configured primary bus number, it will be reserved during power down if PMC module is populated
input                           rtlh_radm_pending;          // Transaction layer TLP pending

//--------------------- outputs -------------------------

output                          radm_idle;
output                          radm_clk_en;

output  [(FX_TLP*64)-1:0]       flt_cdm_addr;
output                          flt_cdm_rtlh_radm_pending;
// single pulse to advertise the credit allocated each time a credit has been freed
output  [NVC-1:0]               radm_rtlh_ph_ca;            // Credit allocated (posted header)
output  [NVC-1:0]               radm_rtlh_pd_ca;            // Credit allocated (posted data)
output  [NVC-1:0]               radm_rtlh_nph_ca;           // Credit allocated (non-posted header)
output  [NVC-1:0]               radm_rtlh_npd_ca;           // Credit allocated (non-posted data)
output  [NVC-1:0]               radm_rtlh_cplh_ca;          // Credit allocated (completion header)
output  [NVC-1:0]               radm_rtlh_cpld_ca;          // Credit allocated (completion data)
output  [NVC-1:0]               radm_qoverflow;             // Received Queue overflow

// ---------- TLP interfaces Client Requesters
output  [DW_OUT_W_PAR-1:0]      radm_bypass_data;           // bypass request TLP data
output  [NW-1:0]                radm_bypass_dwen;           // bypass request TLP data with dword enable of the data bus
output  [NHQ-1:0]               radm_bypass_dv;             // bypass TLP data valid
output  [NHQ-1:0]               radm_bypass_hv;             // bypass TLP hdr valid
output  [NHQ-1:0]               radm_bypass_eot;            // bypass TLP end of TLP
output  [NHQ-1:0]               radm_bypass_dllp_abort;     // bypass DLLP abort (valid at EOT)
output  [NHQ-1:0]               radm_bypass_tlp_abort;      // bypass TLP  abort (valid at HV)
output  [NHQ-1:0]               radm_bypass_ecrc_err;       // bypass TLP with ECRC error
output  [NHQ*2-1:0]             radm_bypass_fmt;            // bypass pcie hdr field fmt
output  [NHQ*5-1:0]             radm_bypass_type;           // bypass pcie hdr field type
output  [NHQ*3-1:0]             radm_bypass_tc;             // bypass pcie hdr field tc
output  [NHQ*ATTR_WD-1:0]       radm_bypass_attr;           // bypass pcie hdr field attr
output  [NHQ*16-1:0]            radm_bypass_reqid;          // bypass pcie hdr field REQID
output  [NHQ*TAG_SIZE-1:0]      radm_bypass_tag;            // bypass pcie hdr field TAG
output  [NHQ*PF_WD-1:0]         radm_bypass_func_num;       // bypass pcie hdr field func_num
output  [NHQ-1:0]               radm_bypass_td;             // bypass pcie hdr field td
output  [NHQ-1:0]               radm_bypass_poisoned;       // bypass pcie hdr field poisoned
output  [NHQ*10-1:0]            radm_bypass_dw_len;         // bypass pcie hdr field dw_len
output  [NHQ*4-1:0]             radm_bypass_first_be;       // bypass pcie hdr field first_be
output  [NHQ*TRGT1_ADDR_WD-1:0] radm_bypass_addr;           // bypass pcie hdr field addr
output  [NHQ-1:0]               radm_bypass_rom_in_range;   // bypass pcie hdr field rom_in_range
output  [NHQ-1:0]               radm_bypass_io_req_in_range;// bypass pcie hdr field io_req_in_range
output  [NHQ*3-1:0]             radm_bypass_in_membar_range;// bypass pcie hdr field in_membar_range
output  [NHQ*4-1:0]             radm_bypass_last_be;        // bypass pcie hdr field last_be
output  [NHQ-1:0]               radm_bypass_bcm;            // Completion header BCM field
output  [NHQ-1:0]               radm_bypass_cpl_last;       // Indicates last completion for TLP
output  [NHQ*3-1:0]             radm_bypass_cpl_status;     // Header info: Received completion status. It is valid when
output  [NHQ*12-1:0]            radm_bypass_byte_cnt;       // Header info: Received CPL byte count. It is valid when radm_cpl_hv is asserted
output  [NHQ*16-1:0]            radm_bypass_cmpltr_id;      // Header info: Received CPL Completer ID, which is the ID sent
output  [(NVC*3)-1:0]           radm_grant_tlp_type;        // A vector to indicate which type&VC has been granted for the next read out of receive queue
output  [NVC-1:0]               radm_pend_cpl_so;           // A vector to indicate which VCs have strongly ordered completions pending
output [NVC-1:0]                radm_q_cpl_not_empty;       // A vector to indicate which VCs have the CPL queue not empty



output  [CPL_LUT_DEPTH-1:0]     radm_cpl_lut_valid;         // completion lookup table valid indication
output                          radm_cpl_timeout;           // CPL is timeout
output                          radm_cpl_timeout_cdm;       // CPL is timeout without flr timeout information
output  [2:0]                   radm_timeout_cpl_tc;        // timeout CPL tc
output  [1:0]                   radm_timeout_cpl_attr;      // timeout CPL attributes
output  [11:0]                  radm_timeout_cpl_len;       // timeout CPL Length
output  [TAG_SIZE-1:0]          radm_timeout_cpl_tag;       // timeout CPL tag
output  [PF_WD-1:0]             radm_timeout_func_num;      // timeout cpl function id

output  [TRGT_DATA_WD-1:0]      radm_trgt0_data;            // trgt0 request TLP data
output  [TRGT_HDR_WD-1:0]       radm_trgt0_hdr;             // trgt0 request TLP hdr
output  [NW-1:0]                radm_trgt0_dwen;            // trgt0 request TLP data with dword enable of the data bus
output                          radm_trgt0_dv;              // trgt0 TLP data valid
output                          radm_trgt0_hv;              // trgt0 TLP hdr valid
output                          radm_trgt0_eot;             // trgt0 TLP end of TLP

output                          radm_trgt0_abort;           // trgt0 TLP or DLLP abort
output                          radm_trgt0_ecrc_err;        // trgt0 TLP with ECRC error










wire   [TRGT_HDR_WD-1:0]       radm_trgt0_hdr;
wire   [TRGT_HDR_WD-1:0]       int_radm_trgt0_hdr;
wire   [TRGT_HDR_WD-1:0]       int_radm_trgt0_hdr_tmp;

wire                           radm_trgt0_parerr;
wire                           radm_trgt0_err;
wire                           radm_trgt0_dv;
wire                           radm_trgt0_hv;
wire                           radm_trgt0_eot;

wire       segbuf_radm_trgt0_hv;  // signal from outq_manager
wire       segbuf_radm_trgt0_dv;
wire       segbuf_radm_trgt0_eot;

// CHECK RAS PROTECTION
  assign int_radm_trgt0_hdr = int_radm_trgt0_hdr_tmp;
  assign radm_trgt0_parerr = 1'b0;
  assign radm_trgt0_err    = 1'b0;

assign radm_trgt0_hv     = segbuf_radm_trgt0_hv;
assign radm_trgt0_dv     = segbuf_radm_trgt0_dv;
assign radm_trgt0_eot    = segbuf_radm_trgt0_eot;

reg    [TRGT_HDR_WD-1:0]        radm_trgt0_hdr_tmp;

always@(*)
begin
  radm_trgt0_hdr_tmp                            = int_radm_trgt0_hdr;
end

assign radm_trgt0_hdr = radm_trgt0_hdr_tmp;


output  [(FX_TLP*64)-1:0]       radm_msg_payload;           // Received msg data associated with slot limit
output  [FX_TLP-1:0]            radm_pm_pme;                // Received PM_PME MSG
output                          radm_pm_turnoff;            // Received PM_TURNOFF
output                          radm_pm_to_ack;             // Received PM_TO_ACK
output                          radm_pm_asnak;              // Received PM_AS_NAK
output                          radm_slot_pwr_limit;        // Received Slot power limit MSG
output  [31:0]                  radm_slot_pwr_payload;      // Received msg data associated with slot limit
output                          radm_msg_unlock;            // Received unlock message
output  [(FX_TLP*16)-1:0]       radm_msg_req_id;            // Received Requester ID
output  [FX_TLP-1:0]            cdm_err_advisory;

output  [NF-1:0]                radm_cpl_pending;           // Indicates that at least one CPL is pending.
output  [(FX_TLP*NF)-1:0]       radm_rcvd_cpl_ur;           // Received CPL Unsupported request error
output  [(FX_TLP*NF)-1:0]       radm_rcvd_cpl_ca;           // Received CPL completion abort
output  [(FX_TLP*NF)-1:0]       radm_unexp_cpl_err;         // Received unexpected CPL error
output  [(FX_TLP*NF)-1:0]       radm_ecrc_err;              // Received ECRC error (in absence of dllp error)
output  [(FX_TLP*NF)-1:0]       radm_mlf_tlp_err;           // Received malformed error
output  [(FX_TLP*NF)-1:0]       radm_rcvd_wreq_poisoned;    // Received posted poisoned wr request
output  [(FX_TLP*NF)-1:0]       radm_rcvd_cpl_poisoned;     // Received posted poisoned cpl tlp request
output  [(FX_TLP*NF)-1:0]       radm_rcvd_req_ur;           // Received unsupported REquest
output  [(FX_TLP*NF)-1:0]       radm_rcvd_req_ca;           // Received completion abort (EP's CA generated for dwlen>1)
output  [(FX_TLP*NF)-1:0]       radm_hdr_log_valid;         // strobe for radm_hdr_log
output  [(FX_TLP*HW)-1:0]       radm_hdr_log;               // tlp header for logging

output  [NVC-1:0]               radm_q_not_empty;           // Receiving Queue is not empty for debug purpose

output  [FX_TLP-1:0]            radm_vendor_msg;            // Received vendor message with message paylod in msg data

output                          radm_inta_asserted;
output                          radm_intb_asserted;
output                          radm_intc_asserted;
output                          radm_intd_asserted;
output                          radm_inta_deasserted;
output                          radm_intb_deasserted;
output                          radm_intc_deasserted;
output                          radm_intd_deasserted;
output   [FX_TLP-1:0]           radm_correctable_err;
output   [FX_TLP-1:0]           radm_nonfatal_err;
output   [FX_TLP-1:0]           radm_fatal_err;

output  [TRGT_DATA_WD-1:0]      radm_trgt1_data;            // trgt1 request TLP data
output  [TRGT_HDR_WD-1:0]       radm_trgt1_hdr;             // trgt1 request TLP hdr
output  [NW-1:0]                radm_trgt1_dwen;            // trgt1 request TLP data with dword enable of the data bus
output                          radm_trgt1_dv;              // trgt1 TLP data valid
output                          radm_trgt1_hv;              // trgt1 TLP hdr valid
output                          radm_trgt1_eot;             // trgt1 TLP end of TLP
output                          radm_trgt1_dllp_abort;      // trgt1 DLLP abort (valid at EOT)
output                          radm_trgt1_tlp_abort;       // trgt1 TLP  abort (valid at HV)
output                          radm_trgt1_ecrc_err;        // trgt1 TLP with ECRC error
output  [1:0]                   radm_trgt1_fmt;             // trgt1 pcie hdr field fmt
output  [4:0]                   radm_trgt1_type;            // trgt1 pcie hdr field type
output  [2:0]                   radm_trgt1_tc;              // trgt1 pcie hdr field tc
output  [ATTR_WD-1:0]           radm_trgt1_attr;            // trgt1 pcie hdr field attr
output  [15:0]                  radm_trgt1_reqid;           // trgt1 pcie hdr field reqid
output  [TAG_SIZE-1:0]          radm_trgt1_tag;             // trgt1 pcie hdr field TAG
output  [PF_WD-1:0]             radm_trgt1_func_num;        // trgt1 pcie hdr field func_num
output  [2:0]                   radm_trgt1_cpl_status;      // trgt1 pcie hdr field cpl_status
output                          radm_trgt1_td;              // trgt1 pcie hdr field td
output                          radm_trgt1_poisoned;        // trgt1 pcie hdr field poisoned
output  [9:0]                   radm_trgt1_dw_len;          // trgt1 pcie hdr field dw_len
output  [3:0]                   radm_trgt1_first_be;        // trgt1 pcie hdr field first_be
output  [TRGT1_ADDR_WD-1:0]     radm_trgt1_addr;            // trgt1 pcie hdr field addr
output  [TRGT1_ADDR_WD-1:0]     radm_trgt1_hdr_uppr_bytes;  // trgt1 pcie hdr - bytes 8 to 11 (for 3DW header), bytes 8 to 15 (for 4DW header)
output                          radm_trgt1_rom_in_range;    // trgt1 pcie hdr field rom_in_range
output                          radm_trgt1_io_req_in_range; // trgt1 pcie hdr field io_req_in_range
output  [2:0]                   radm_trgt1_in_membar_range; // trgt1 pcie hdr field in_membar_range
output  [3:0]                   radm_trgt1_last_be;         // trgt1 pcie hdr field last_be
output  [7:0]                   radm_trgt1_msgcode;         // trgt1 pcie hdr field message code
output                          radm_trgt1_bcm;             // Completion header BCM field
output                          radm_trgt1_cpl_last;        // Indicates last completion for TLP
output  [11:0]                  radm_trgt1_byte_cnt;        // Header info: Received CPL byte count. It is valid when radm_cpl_hv is asserted
output  [15:0]                  radm_trgt1_cmpltr_id;       // Header info: Received CPL Completer ID, which is the ID sent
output  [2:0]                   radm_trgt1_vc_num;          // trgt1 VC num

wire    [TRGT1_ADDR_WD-1:0]     int_radm_trgt1_addr;
wire    [TRGT1_ADDR_WD-1:0]     radm_trgt1_addr;                // trgt1 pcie hdr field addr
wire    [TRGT1_ADDR_WD-1:0]     radm_trgt1_addr_tmp;            // trgt1 pcie hdr field addr
wire    [3:0]                   int_radm_trgt1_first_be;       // trgt1 pcie hdr field first_be
wire    [3:0]                   int_radm_trgt1_last_be;        // trgt1 pcie hdr field last_be

wire   [TRGT_HDR_WD-1:0]        radm_trgt1_hdr;

wire [3:0]               radm_trgt1_last_be_i;
wire                     radm_trgt1_cpl_last_i;
wire                     radm_trgt1_poisoned_i;
wire                     radm_trgt1_td_i;
wire [TRGT1_ADDR_WD-1:0] radm_trgt1_addr_i;
wire [3:0]               radm_trgt1_first_be_i;
wire                     radm_trgt1_io_req_in_range_i;
wire                     radm_trgt1_rom_in_range_i;
wire [2:0]               radm_trgt1_in_membar_range_i;
wire [9:0]               radm_trgt1_dw_len_i;
wire [2:0]               radm_trgt1_cpl_status_i;
wire [PF_WD-1:0]         radm_trgt1_func_num_i;
wire [TAG_SIZE-1:0]      radm_trgt1_tag_i;
wire [15:0]              radm_trgt1_reqid_i;
wire [ATTR_WD-1:0]       radm_trgt1_attr_i;
wire [2:0]               radm_trgt1_tc_i;
wire [4:0]               radm_trgt1_type_i;
wire [1:0]               radm_trgt1_fmt_i;

wire                      radm_trgt1_parerr;
wire                      radm_trgt1_err;
assign radm_trgt1_parerr  = 1'b0;
assign radm_trgt1_err     = 1'b0;

assign radm_trgt1_fmt_i[1:0]        = radm_trgt1_hdr[`RADM_Q_FMT_RANGE       ]; // completion hdr element
assign radm_trgt1_type_i[4:0]       = radm_trgt1_hdr[`RADM_Q_TYPE_RANGE      ]; // completion hdr element
assign radm_trgt1_tc_i[2:0]         = radm_trgt1_hdr[`RADM_Q_TC_RANGE        ]; // completion hdr element
assign radm_trgt1_attr_i            = radm_trgt1_hdr[`RADM_Q_ATTR_RANGE      ]; // completion hdr element
assign radm_trgt1_reqid_i[15:0]     = radm_trgt1_hdr[`RADM_Q_REQID_RANGE     ]; // completion hdr element
assign radm_trgt1_tag_i[TAG_SIZE-1:0]= radm_trgt1_hdr[`RADM_Q_TAG_RANGE       ]; // completion hdr element
assign radm_trgt1_func_num_i        = radm_trgt1_hdr[`RADM_Q_FUNC_NMBR_RANGE ]; // for cfg transaction only
assign radm_trgt1_cpl_status_i[2:0] = radm_trgt1_hdr[`RADM_Q_CPL_STATUS_RANGE]; // completion hdr element
assign radm_trgt1_dw_len_i[9:0]     = radm_trgt1_hdr[`RADM_PQ_DW_LENGTH_RANGE]; // completion hdr element
assign int_radm_trgt1_first_be[3:0] = radm_trgt1_hdr[`RADM_PQ_FRSTDW_BE_RANGE]; // completion hdr & TRGT0 control
// MUTUALLY EXCLUSIVE macros

// For any Msg, the Message Code field is byte 7 of the TLP Header. This is
// the same byte that is used for the Last and First DW Byte Enable fields
// in a memory request header.
assign radm_trgt1_msgcode = {int_radm_trgt1_last_be,int_radm_trgt1_first_be};
wire trgt1_cpl_type;
assign trgt1_cpl_type   = (({radm_trgt1_fmt_i,radm_trgt1_type_i} == `CPLLK) | ({radm_trgt1_fmt_i,radm_trgt1_type_i} == `CPLDLK)  ||
                           ({radm_trgt1_fmt_i,radm_trgt1_type_i} == `CPL) | ({radm_trgt1_fmt_i,radm_trgt1_type_i} == `CPLD));
parameter FLT_Q_CPL_LOWER_ADDR_WIDTH  = `FLT_Q_CPL_LOWER_ADDR_WIDTH;
reg     [TRGT1_ADDR_WD-1:0]     int_radm_trgt1_addr_tmp;
  always @(*) begin : INT_RADM_TRGT1_ADDR
    int_radm_trgt1_addr_tmp = 0;
    if(trgt1_cpl_type) begin
      int_radm_trgt1_addr_tmp[0 +:FLT_Q_CPL_LOWER_ADDR_WIDTH] =  radm_trgt1_hdr[`RADM_PQ_CPL_LOWER_ADDR_RANGE];
    end else begin
      int_radm_trgt1_addr_tmp[0 +: `FLT_Q_ADDR_WIDTH] = radm_trgt1_hdr[ `RADM_PQ_ADDR_RANGE   ];
    end
  end
assign int_radm_trgt1_addr = int_radm_trgt1_addr_tmp;
                                 assign radm_trgt1_poisoned_i = trgt1_cpl_type ? radm_trgt1_hdr[`RADM_CPLQ_EP_RANGE] : radm_trgt1_hdr[ `RADM_PQ_EP_RANGE              ];
                                 assign radm_trgt1_td_i       = trgt1_cpl_type ? radm_trgt1_hdr[`RADM_CPLQ_TD_RANGE] : radm_trgt1_hdr[ `RADM_PQ_TD_RANGE              ];

assign radm_trgt1_addr_tmp[`FLT_Q_ADDR_WIDTH-1:0] = int_radm_trgt1_addr[`FLT_Q_ADDR_WIDTH-1:0];
assign radm_trgt1_addr_i[`FLT_Q_ADDR_WIDTH-1:0]   = radm_trgt1_addr_tmp[`FLT_Q_ADDR_WIDTH-1:0];


assign radm_trgt1_rom_in_range_i    = radm_trgt1_hdr[ `RADM_PQ_ROM_IN_RANGE_RANGE    ];          // control
assign radm_trgt1_io_req_in_range_i = radm_trgt1_hdr[ `RADM_PQ_IO_REQ_IN_RANGE_RANGE ];          // control
assign radm_trgt1_in_membar_range_i = radm_trgt1_hdr[ `RADM_PQ_IN_MEMBAR_RANGE_RANGE ];          // control
assign int_radm_trgt1_last_be[3:0]  = radm_trgt1_hdr[ `RADM_PQ_LSTDW_BE_RANGE        ];
assign radm_trgt1_first_be_i = int_radm_trgt1_first_be;
assign radm_trgt1_last_be_i  = int_radm_trgt1_last_be;
assign radm_trgt1_cpl_last_i        = radm_trgt1_hdr[ `RADM_CPLQ_CPL_LAST_RANGE      ];
assign radm_trgt1_bcm               = radm_trgt1_hdr[ `RADM_CPLQ_BCM_RANGE           ];
assign radm_trgt1_byte_cnt          = radm_trgt1_hdr[ `RADM_CPLQ_BYTE_CNT_RANGE      ];
assign radm_trgt1_cmpltr_id         = radm_trgt1_hdr[ `RADM_CPLQ_CMPLTR_ID_RANGE     ];

//--------------------------------- Extract raw bytes 8 to 15 of TLP header ---------------------------------------------
// Bring raw header data out from PCIe core: bytes 8 to 11 for 3 DW header
// or bytes 8 to 15 for 4 DW header. int_radm_trgt1_addr consists of these
// bytes, but the byte endianness must be reversed.
// For a 4 DW header, radm_trgt1_fmt_i[0] = 1.

// TLP Header bytes
wire [7:0]                   int_radm_trgt1_hdr_byte15, int_radm_trgt1_hdr_byte14, int_radm_trgt1_hdr_byte13, int_radm_trgt1_hdr_byte12;
wire [7:0]                   int_radm_trgt1_hdr_byte11, int_radm_trgt1_hdr_byte10, int_radm_trgt1_hdr_byte9, int_radm_trgt1_hdr_byte8;

// Upper TLP Header bytes (8 to 11 or 15)
reg  [TRGT1_ADDR_WD-1:0]     radm_trgt1_hdr_uppr_bytes_i, int_radm_trgt1_hdr_uppr_bytes; 

assign  int_radm_trgt1_hdr_byte15  = int_radm_trgt1_addr[7:0];
assign  int_radm_trgt1_hdr_byte14  = int_radm_trgt1_addr[15:8];
assign  int_radm_trgt1_hdr_byte13  = int_radm_trgt1_addr[23:16];
assign  int_radm_trgt1_hdr_byte12  = int_radm_trgt1_addr[31:24];
assign  int_radm_trgt1_hdr_byte11  = radm_trgt1_fmt_i[0] ? int_radm_trgt1_addr[39:32] : int_radm_trgt1_addr[7:0];
assign  int_radm_trgt1_hdr_byte10  = radm_trgt1_fmt_i[0] ? int_radm_trgt1_addr[47:40] : int_radm_trgt1_addr[15:8];
assign  int_radm_trgt1_hdr_byte9   = radm_trgt1_fmt_i[0] ? int_radm_trgt1_addr[55:48] : int_radm_trgt1_addr[23:16];
assign  int_radm_trgt1_hdr_byte8   = radm_trgt1_fmt_i[0] ? int_radm_trgt1_addr[63:56] : int_radm_trgt1_addr[31:24];
always @(*) begin : INT_UPR_BYTES
  int_radm_trgt1_hdr_uppr_bytes = 0;
  if(radm_trgt1_fmt_i[0]) begin
    int_radm_trgt1_hdr_uppr_bytes       = {int_radm_trgt1_hdr_byte15,int_radm_trgt1_hdr_byte14,int_radm_trgt1_hdr_byte13,int_radm_trgt1_hdr_byte12,
                                           int_radm_trgt1_hdr_byte11,int_radm_trgt1_hdr_byte10,int_radm_trgt1_hdr_byte9,int_radm_trgt1_hdr_byte8};
  end else begin
    int_radm_trgt1_hdr_uppr_bytes[31:0] = {int_radm_trgt1_hdr_byte11,int_radm_trgt1_hdr_byte10,int_radm_trgt1_hdr_byte9,int_radm_trgt1_hdr_byte8};
  end
end

// If TLP is a Cpl, then upper bytes is 4 bytes and is Lower Address, Tag and Requester ID fields (bytes 11 down to 8).
// Use radm_trgt1_tag_i[7:0] because tag is 10 bits for Gen4.
always @(*) begin : UPR_BYTES 
  radm_trgt1_hdr_uppr_bytes_i = 0;
  if(trgt1_cpl_type) begin
    radm_trgt1_hdr_uppr_bytes_i[31:0] = {int_radm_trgt1_hdr_byte11, radm_trgt1_tag_i[7:0], radm_trgt1_reqid_i[7:0], radm_trgt1_reqid_i[15:8]};
  end else begin
    radm_trgt1_hdr_uppr_bytes_i       = int_radm_trgt1_hdr_uppr_bytes; 
  end
end

//--------------------------------- End of extraction of raw bytes 8 to 11 of TLP header -----------------------------------


  assign {        
                   radm_trgt1_hdr_uppr_bytes,
                   radm_trgt1_last_be,
                   radm_trgt1_cpl_last,
                   radm_trgt1_poisoned,
                   radm_trgt1_td,
                   radm_trgt1_addr,
                   radm_trgt1_first_be,
                   radm_trgt1_io_req_in_range,
                   radm_trgt1_rom_in_range,
                   radm_trgt1_in_membar_range,
                   radm_trgt1_dw_len,
                   radm_trgt1_cpl_status,
                   radm_trgt1_func_num,
                   radm_trgt1_tag,
                   radm_trgt1_reqid,
                   radm_trgt1_attr,
                   radm_trgt1_tc,
                   radm_trgt1_type,
                   radm_trgt1_fmt
         } =
                  {
                   radm_trgt1_hdr_uppr_bytes_i,
                   radm_trgt1_last_be_i,
                   radm_trgt1_cpl_last_i,
                   radm_trgt1_poisoned_i,
                   radm_trgt1_td_i,
                   radm_trgt1_addr_i,
                   radm_trgt1_first_be_i,
                   radm_trgt1_io_req_in_range_i,
                   radm_trgt1_rom_in_range_i,
                   radm_trgt1_in_membar_range_i,
                   radm_trgt1_dw_len_i,
                   radm_trgt1_cpl_status_i,
                   radm_trgt1_func_num_i,
                   radm_trgt1_tag_i,
                   radm_trgt1_reqid_i,
                   radm_trgt1_attr_i,
                   radm_trgt1_tc_i,
                   radm_trgt1_type_i,
                   radm_trgt1_fmt_i 
                  };



// For the effort of bring RAM outside of the hiarch.
// Beneath are grouped inputs and outputs just for RAM

input   [NHQ*RADM_SBUF_HDRQ_WD-1:0]     p_hdrq_dataout;
input   [NHQ-1:0]                       p_hdrq_parerr;
output  [NHQ-1:0]                       p_hdrq_par_chk_val;
output  [NHQ-1:0]                       p_hdrq_parerr_out;
output  [NHQ*(RADM_SBUF_HDRQ_PW)-1:0]   p_hdrq_addra;
output  [NHQ*(RADM_SBUF_HDRQ_PW)-1:0]   p_hdrq_addrb;
output  [NHQ*(RADM_SBUF_HDRQ_WD)-1:0]   p_hdrq_datain;
output  [NHQ-1:0]                       p_hdrq_ena;
output  [NHQ-1:0]                       p_hdrq_enb;
output  [NHQ-1:0]                       p_hdrq_wea;
input   [NDQ*RADM_SBUF_DATAQ_RAM_WD-1:0] p_dataq_dataout;
input   [NDQ-1:0]                       p_dataq_parerr;
output  [NDQ-1:0]                       p_dataq_par_chk_val;
output  [NDQ-1:0]                       p_dataq_parerr_out;
output  [NDQ*(RADM_SBUF_DATAQ_PW)-1:0]  p_dataq_addra;
output  [NDQ*(RADM_SBUF_DATAQ_PW)-1:0]  p_dataq_addrb;
output  [NDQ*(RADM_SBUF_DATAQ_RAM_WD)-1:0]  p_dataq_datain;
output  [NDQ-1:0]                       p_dataq_ena;
output  [NDQ-1:0]                       p_dataq_enb;
output  [NDQ-1:0]                       p_dataq_wea;



output                              radm_parerr;
output                              radm_trgt0_pending;         // TLP enroute from RADM prevent DBI access
output                              radm_snoop_upd;
output  [7:0]                       radm_snoop_bus_num;
output  [4:0]                       radm_snoop_dev_num;


//---------------- internal wires-----------------
wire                                radm_idle;
wire                                radm_clk_en;
wire                                sb_init_done;


wire    [FX_TLP-1:0]                form_filt_hv;
wire    [(FX_TLP*(128+HDR_PROT_WD))-1:0]  form_filt_hdr;
wire    [FX_TLP-1:0]                form_filt_dv;
wire    [FX_TLP-1:0]                form_filt_parerr;
wire    [(FX_TLP*(DW+DATA_PAR_WD))-1:0] form_filt_data;
wire    [FX_TLP-1:0]                form_filt_eot;
wire    [(FX_TLP*NW)-1:0]           form_filt_dwen;
wire    [FX_TLP-1:0]                form_filt_dllp_err;
wire    [FX_TLP-1:0]                form_filt_malform_tlp_err;
wire    [FX_TLP-1:0]                form_filt_ecrc_err;
wire    [(FX_TLP*64)-1:0]           form_filt_ant_addr;
wire    [(FX_TLP*16)-1:0]           form_filt_ant_rid;
wire    [(FX_TLP*NF)-1:0]           form_filt_io_match;
wire    [(FX_TLP*NF)-1:0]           form_filt_config_above_match;
wire    [(FX_TLP*NF)-1:0]           form_filt_rom_match;
wire    [(FX_TLP*NF*6)-1:0]         form_filt_bar_match;
wire    [(FX_TLP*NF)-1:0]           form_filt_prefmem_match;
wire    [(FX_TLP*NF)-1:0]           form_filt_mem_match;

wire    [NVC-1:0]                   cplq_ral_dv;
wire    [NVC-1:0]                   cplq_ral_hv;
wire    [NVC*RADM_CPL_HWD-1:0]      cplq_ral_header;
wire    [NVC*DW_PAR-1:0]            cplq_ral_data;
wire    [NVC*NW-1:0]                cplq_ral_dwen;
wire    [NVC-1:0]                   cplq_ral_eot;

wire    [NVC-1:0]                   pq_ral_dv;
wire    [NVC-1:0]                   pq_ral_hv;
wire    [NVC*RADM_P_HWD-1:0]        pq_ral_header;
wire    [NVC*DW_PAR-1:0]            pq_ral_data;
wire    [NVC*NW-1:0]                pq_ral_dwen;
wire    [NVC-1:0]                   pq_ral_eot;

wire    [NVC-1:0]                   npq_ral_dv;
wire    [NVC-1:0]                   npq_ral_hv;
wire    [NVC*RADM_NP_HWD-1:0]       npq_ral_header;
wire    [NVC*DW_PAR-1:0]            npq_ral_data;
wire    [NVC*NW-1:0]                npq_ral_dwen;
wire    [NVC-1:0]                   npq_ral_eot;

wire    [(FX_TLP*(FLT_Q_HDR_WIDTH+FLT_OUT_PROT_WD))-1:0] ep_flt_q_header;
wire    [(FX_TLP*NVC)-1:0]          ep_flt_q_hv;
wire    [(FX_TLP*NVC)-1:0]          ep_flt_q_dv;
wire    [(FX_TLP*(DW+DATA_PAR_WD))-1:0] ep_flt_q_data;
wire    [(FX_TLP*NW)-1:0]           ep_flt_q_dwen;
wire    [(FX_TLP*NVC)-1:0]          ep_flt_q_eot;
wire    [(FX_TLP*3)-1:0]            ep_flt_q_tlp_type;
wire    [FX_TLP-1:0]                ep_flt_q_parerr;
wire    [(FX_TLP*SEG_WIDTH)-1:0]    ep_flt_q_seg_num;
wire    [(FX_TLP*3)-1:0]            ep_flt_q_vc;
wire    [(FX_TLP*(FLT_Q_HDR_WIDTH+FLT_OUT_PROT_WD))-1:0] rc_flt_q_header;
wire    [(FX_TLP*NVC)-1:0]         rc_flt_q_hv;
wire    [(FX_TLP*NVC)-1:0]         rc_flt_q_dv;
wire    [(FX_TLP*(DW+DATA_PAR_WD))-1:0] rc_flt_q_data;
wire    [(FX_TLP*NW)-1:0]          rc_flt_q_dwen;
wire    [(FX_TLP*NVC)-1:0]         rc_flt_q_eot;
wire    [(FX_TLP*3)-1:0]           rc_flt_q_tlp_type;
wire    [FX_TLP-1:0]               rc_flt_q_parerr;
wire    [(FX_TLP*SEG_WIDTH)-1:0]   rc_flt_q_seg_num;
wire    [(FX_TLP*3)-1:0]           rc_flt_q_vc;
wire    [(FX_TLP*(FLT_Q_HDR_WIDTH+FLT_OUT_PROT_WD))-1:0] flt_q_header;
wire    [(FX_TLP*NVC)-1:0]         flt_q_hv;
wire    [(FX_TLP*NVC)-1:0]         flt_q_dv;
wire    [(FX_TLP*(DW+DATA_PAR_WD))-1:0] flt_q_data;
wire    [(FX_TLP*NW)-1:0]          flt_q_dwen;
wire    [(FX_TLP*NVC)-1:0]         flt_q_eot;
wire    [(FX_TLP*3)-1:0]           flt_q_tlp_type;
wire    [FX_TLP-1:0]               flt_q_parerr;
wire    [(FX_TLP*SEG_WIDTH)-1:0]   flt_q_seg_num;
wire    [(FX_TLP*3)-1:0]           flt_q_vc;
wire    [(FX_TLP*NVC)-1:0]          flt_qform_dv;
wire    [(FX_TLP*NVC)-1:0]          flt_qform_hv;
wire    [(FX_TLP*NVC)-1:0]          flt_qform_eot;
wire    [DW+DATA_PAR_WD-1:0]        flt_qform_data;
wire    [(FX_TLP*(FLT_Q_HDR_WIDTH+FLT_OUT_PROT_WD))-1:0] flt_qform_header;
wire    [NW-1:0]                    flt_qform_dwen;
wire    [FX_TLP-1:0]                flt_qform_dllp_abort;
wire    [FX_TLP-1:0]                flt_qform_tlp_abort;
wire    [FX_TLP-1:0]                flt_qform_ecrc_err;
wire    [FX_TLP-1:0]                flt_qform_parerr;
wire    [(FX_TLP*SEG_WIDTH)-1:0]    flt_qform_seg_num;
wire    [(FX_TLP*3)-1:0]            flt_qform_vc;
wire    [(FX_TLP*3)-1:0]            flt_qform_tlp_type;


//---------------- outputs-----------------
wire    [NVC-1:0]                   pq_overflow;
wire    [NVC-1:0]                   npq_overflow;
wire    [NVC-1:0]                   cplq_overflow;
wire    [NVC-1:0]                   pq_not_empty;
wire    [NVC-1:0]                   npq_not_empty;
wire    [NVC-1:0]                   cplq_not_empty;

wire    [NVC-1:0]                   radm_qoverflow;
wire    [NVC-1:0]                   radm_q_not_empty;

wire                                outq_parerr;
wire    [NVC-1:0]                   radm_pq_parerr;
wire    [NVC-1:0]                   radm_npq_parerr;
wire    [NVC-1:0]                   radm_cplq_parerr;
wire                                radm_cpl_tlp_abort;
wire                                radm_cpl_dllp_abort;
wire                                radm_trgt1_tlp_abort;
wire                                radm_trgt1_dllp_abort;

wire                                radm_inta_asserted;
wire                                radm_intb_asserted;
wire                                radm_intc_asserted;
wire                                radm_intd_asserted;
wire                                radm_inta_deasserted;
wire                                radm_intb_deasserted;
wire                                radm_intc_deasserted;
wire                                radm_intd_deasserted;

// --- added wires ---
wire    [FX_TLP-1:0]                ep_flt_q_dllp_abort;
wire    [FX_TLP-1:0]                ep_flt_q_tlp_abort;
wire    [FX_TLP-1:0]                ep_flt_q_ecrc_err;

wire    [FX_TLP-1:0]                rc_flt_q_dllp_abort;
wire    [FX_TLP-1:0]                rc_flt_q_tlp_abort;
wire    [FX_TLP-1:0]                rc_flt_q_ecrc_err;

wire    [FX_TLP-1:0]                flt_q_dllp_abort;
wire    [FX_TLP-1:0]                flt_q_tlp_abort;
wire    [FX_TLP-1:0]                flt_q_ecrc_err;
wire    [NVC-1:0]                   dmx_q_p_halt;
wire    [NVC-1:0]                   dmx_q_np_halt;
wire    [NVC-1:0]                   dmx_q_cpl_halt;
wire    [NVC-1:0]                   pq_ral_dllp_abort;
wire    [NVC-1:0]                   pq_ral_tlp_abort;
wire    [NVC-1:0]                   pq_ral_ecrc_err;
wire    [NVC-1:0]                   pq_ral_discard;
wire    [NVC-1:0]                   npq_ral_dllp_abort;
wire    [NVC-1:0]                   npq_ral_tlp_abort;
wire    [NVC-1:0]                   npq_ral_ecrc_err;
wire    [NVC-1:0]                   npq_ral_discard;
wire    [NVC-1:0]                   cplq_ral_dllp_abort;
wire    [NVC-1:0]                   cplq_ral_tlp_abort;
wire    [NVC-1:0]                   cplq_ral_ecrc_err;
wire    [NVC-1:0]                   cplq_ral_discard;

wire    [FX_TLP-1:0]                ep_cpl_tlp;
wire    [FX_TLP-1:0]                ep_tlp_poisoned;
wire    [FX_TLP-1:0]                ep_flt_dwlenEq0;
wire    [(FX_TLP*TAG_SIZE)-1:0]     ep_flt_q_rcvd_cpl_tlp_tag;
wire    [(FX_TLP*3)-1:0]            ep_cpl_status;
wire    [FX_TLP-1:0]                ep_radm_snoop_upd;

wire    [FX_TLP*RADM_P_HWD_WO_PAR-1:0] radm_bypass_hdr;         // bypass request TLP hdr
wire    [FX_TLP-1:0]                rc_cpl_tlp;
wire    [FX_TLP-1:0]                rc_tlp_poisoned;
wire    [FX_TLP-1:0]                rc_flt_dwlenEq0;
wire    [(FX_TLP*TAG_SIZE)-1:0]     rc_flt_q_rcvd_cpl_tlp_tag;
wire    [(FX_TLP*3)-1:0]            rc_cpl_status;
wire    [(FX_TLP*NF)-1:0]           rc_radm_snoop_upd;
wire    [FX_TLP-1:0]                cpl_tlp;
wire    [FX_TLP-1:0]                tlp_poisoned;
wire    [FX_TLP-1:0]                flt_dwlenEq0;
wire    [(FX_TLP*TAG_SIZE)-1:0]     flt_q_rcvd_cpl_tlp_tag;
wire    [(FX_TLP*3)-1:0]            cpl_status;
wire    [FX_TLP-1:0]                cpl_mlf_err;
wire    [FX_TLP-1:0]                flt_q_cpl_abort;
wire    [FX_TLP-1:0]                flt_q_cpl_last;
wire    [FX_TLP-1:0]                cpl_ur_err;
wire    [FX_TLP-1:0]                cpl_ca_err;
wire    [FX_TLP-1:0]                unexpected_cpl_err;
wire    [FX_TLP-1:0]                vendor_msg_id_match;
wire    [TAG_SIZE8-1:0]             radm_cpl_tag;               // Received CPL tag field
wire    [31:0]                      radm_slot_pwr_payload;      // Received msg data associated with slot limit

wire                                radm_snoop_upd;
wire    [7:0]                       radm_snoop_bus_num;
wire    [4:0]                       radm_snoop_dev_num;
wire                                radm_slot_pwr_limit;        // Received Slot power limit MSG
wire    [(FX_TLP*64)-1:0]           radm_msg_payload;           // Received msg data associated with slot limit
wire    [(FX_TLP*16)-1:0]           radm_msg_req_id;            // Received Requester ID
wire    [FX_TLP-1:0]                radm_vendor_msg;            // Received vendor message with message paylod in msg data
wire    [FX_TLP-1:0]                radm_pm_pme;                // Received PM_PME MSG
wire                                radm_pm_turnoff;            // Received PM_TURNOFF
wire                                radm_pm_to_ack;             // Received PM_TO_ACK
wire                                radm_pm_asnak;              // Received PM_AS_NAK
wire    [(FX_TLP*64)-1:0]           ep_radm_msg_payload;        // Received msg data associated with slot limit
wire    [(FX_TLP*16)-1:0]           ep_radm_msg_req_id;         // Received Requester ID
wire    [FX_TLP-1:0]                ep_radm_vendor_msg;         // Received vendor message
wire    [FX_TLP-1:0]                ep_radm_pm_pme;             // Received PM_PME MSG
wire    [FX_TLP-1:0]                ep_radm_pm_turnoff;         // Received PM_TURNOFF
wire    [FX_TLP-1:0]                ep_radm_pm_to_ack;          // Received PM_TO_ACK
wire    [FX_TLP-1:0]                ep_radm_pm_asnak;           // Received PM_AS_NAK

wire    [(FX_TLP*64)-1:0]           rc_radm_msg_payload;        // Received msg data associated with slot limit
wire    [(FX_TLP*16)-1:0]           rc_radm_msg_req_id;         // Received Requester ID
wire    [FX_TLP-1:0]                rc_radm_vendor_msg;         // Received vendor message
wire    [FX_TLP-1:0]                rc_radm_pm_pme;             // Received PM_PME MSG
wire    [FX_TLP-1:0]                rc_radm_pm_turnoff;         // Received PM_TURNOFF
wire    [FX_TLP-1:0]                rc_radm_pm_to_ack;          // Received PM_TO_ACK
wire    [FX_TLP-1:0]                rc_radm_pm_asnak;           // Received PM_AS_NAK

wire    [(FX_TLP*NF)-1:0]           radm_rcvd_cpl_ur;           // Received CPL Unsupported request error
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_cpl_ca;           // Received CPL completion abort
wire    [(FX_TLP*NF)-1:0]           radm_unexp_cpl_err;         // Received unexpected CPL error
wire    [(FX_TLP*NF)-1:0]           radm_ecrc_err;              // Received ECRC error (in absence of dllp error)
wire    [(FX_TLP*NF)-1:0]           radm_mlf_tlp_err;           // Received malformed error
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_wreq_poisoned;    // Received posted poisoned wr request
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_cpl_poisoned;     // Received posted poisoned cpl tlp request
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_req_ur;           // Received unsupported REquest
wire    [(FX_TLP*NF)-1:0]           radm_rcvd_req_ca;           // Received completion abort (EP's CA generated for dwlen>1 )
wire    [(FX_TLP*NF)-1:0]           radm_hdr_log_valid;         // strobe for radm_hdr_log
wire    [(FX_TLP*HW)-1:0]           radm_hdr_log;               // tlp header for logging

wire    [(FX_TLP*NF)-1:0]           ep_radm_rcvd_cpl_ur;        // Received CPL Unsupported request error
wire    [(FX_TLP*NF)-1:0]           ep_radm_rcvd_cpl_ca;        // Received CPL completion abort
wire    [(FX_TLP*NF)-1:0]           ep_radm_unexp_cpl_err;      // Received unexpected CPL error
wire    [(FX_TLP*NF)-1:0]           ep_radm_ecrc_err;           // Received ECRC error (in absence of dllp error)
wire    [(FX_TLP*NF)-1:0]           ep_radm_mlf_tlp_err;        // Received malformed error
wire    [(FX_TLP*NF)-1:0]           ep_radm_rcvd_wreq_poisoned; // Received posted poisoned wr request
wire    [(FX_TLP*NF)-1:0]           ep_radm_rcvd_cpl_poisoned;  // Received posted poisoned cpl tlp request
wire    [(FX_TLP*NF)-1:0]           ep_radm_rcvd_req_ur;        // Received unsupported REquest
wire    [(FX_TLP*NF)-1:0]           ep_radm_rcvd_req_ca;        // Received completion abort (EP's CA generated for dwlen>1 )
wire    [(FX_TLP*NF)-1:0]           ep_radm_hdr_log_valid;      // strobe for radm_hdr_log
wire    [(FX_TLP*HW)-1:0]           ep_radm_hdr_log;            // tlp header for logging

reg     [(FX_TLP*NF)-1:0]           rc_radm_rcvd_cpl_ur;        // Received CPL Unsupported request error
reg     [(FX_TLP*NF)-1:0]           rc_radm_rcvd_cpl_ca;        // Received CPL completion abort
reg     [(FX_TLP*NF)-1:0]           rc_radm_unexp_cpl_err;      // Received unexpected CPL error
reg     [(FX_TLP*NF)-1:0]           rc_radm_ecrc_err;           // Received ECRC error (in absence of dllp error)
reg     [(FX_TLP*NF)-1:0]           rc_radm_mlf_tlp_err;        // Received malformed error
reg     [(FX_TLP*NF)-1:0]           rc_radm_rcvd_wreq_poisoned; // Received posted poisoned wr request
reg     [(FX_TLP*NF)-1:0]           rc_radm_rcvd_cpl_poisoned;  // Received posted poisoned cpl tlp request
reg     [(FX_TLP*NF)-1:0]           rc_radm_rcvd_req_ur;        // Received unsupported REquest
reg     [(FX_TLP*NF)-1:0]           rc_radm_rcvd_req_ca;        // Received completion abort (EP's CA generated for dwlen>1 )
reg     [(FX_TLP*NF)-1:0]           rc_radm_hdr_log_valid;      // strobe for radm_hdr_log
wire    [(FX_TLP*HW)-1:0]           rc_radm_hdr_log;            // tlp header for logging

wire    [FX_TLP-1:0]                int_rc_radm_rcvd_cpl_ur;        // Received CPL Unsupported request error
wire    [FX_TLP-1:0]                int_rc_radm_rcvd_cpl_ca;        // Received CPL completion abort
wire    [FX_TLP-1:0]                int_rc_radm_unexp_cpl_err;      // Received unexpected CPL error
wire    [FX_TLP-1:0]                int_rc_radm_ecrc_err;           // Received ECRC error (in absence of dllp error)
wire    [FX_TLP-1:0]                int_rc_radm_mlf_tlp_err;        // Received malformed error
wire    [FX_TLP-1:0]                int_rc_radm_rcvd_wreq_poisoned; // Received posted poisoned wr request
wire    [FX_TLP-1:0]                int_rc_radm_rcvd_cpl_poisoned;  // Received posted poisoned cpl tlp request
wire    [FX_TLP-1:0]                int_rc_radm_rcvd_req_ur;        // Received unsupported REquest
wire    [FX_TLP-1:0]                int_rc_radm_rcvd_req_ca;        // Received completion abort (EP's CA generated for dwlen>1 )
wire    [FX_TLP-1:0]                int_rc_radm_hdr_log_valid;      // strobe for radm_hdr_log
wire    [FX_TLP-1:0]                cdm_err_advisory;
wire    [FX_TLP-1:0]                rc_cdm_err_advisory;

wire    [(FX_TLP*64)-1:0]           flt_cdm_addr;
wire    [(FX_TLP*64)-1:0]           ep_flt_cdm_addr;
wire    [(FX_TLP*64)-1:0]           rc_flt_cdm_addr;

wire    [(FX_TLP*64)-1:0]           int_radm_msg_payload;       // Received msg data associated with slot limit
wire    [FX_TLP-1:0]                int_radm_pm_pme;            // Received PM_PME MSG
wire    [FX_TLP-1:0]                int_radm_pm_turnoff;        // Received PM_TURNOFF
wire    [FX_TLP-1:0]                int_radm_pm_to_ack;         // Received PM_TO_ACK
wire    [FX_TLP-1:0]                int_radm_pm_asnak;          // Received PM_AS_NAK
wire    [FX_TLP-1:0]                int_radm_slot_pwr_limit;    // Received Slot power limit MSG
wire    [FX_TLP-1:0]                int_radm_msg_unlock;        // Received unlock message
wire    [(FX_TLP*16)-1:0]           int_radm_msg_req_id;        // Received Requester ID
wire    [FX_TLP-1:0]                int_radm_vendor_msg;        // Received vendor message with message paylod in msg data
wire    [(FX_TLP*NF)-1:0]           int_radm_rcvd_cpl_ur;       // Received CPL Unsupported request error
wire    [(FX_TLP*NF)-1:0]           int_radm_rcvd_cpl_ca;       // Received CPL completion abort
wire    [(FX_TLP*NF)-1:0]           int_radm_unexp_cpl_err;     // Received unexpected CPL error
wire    [(FX_TLP*NF)-1:0]           int_radm_ecrc_err;          // Received ECRC error (in absence of dllp error)
wire    [(FX_TLP*NF)-1:0]           int_radm_mlf_tlp_err;       // Received malformed error
wire    [(FX_TLP*NF)-1:0]           int_radm_rcvd_wreq_poisoned;// Received posted poisoned wr request
wire    [(FX_TLP*NF)-1:0]           int_radm_rcvd_cpl_poisoned; // Received posted poisoned cpl tlp request
wire    [(FX_TLP*NF)-1:0]           int_radm_rcvd_req_ur;       // Received unsupported REquest
wire    [(FX_TLP*NF)-1:0]           int_radm_rcvd_req_ca;       // Received completion abort (EP's CA generated for dwlen>1)
wire    [(FX_TLP*NF)-1:0]           int_radm_hdr_log_valid;     // strobe for radm_hdr_log
wire    [(FX_TLP*HW)-1:0]           int_radm_hdr_log;           // tlp header for logging

wire    [FX_TLP-1:0]                int_radm_snoop_upd;
wire    [(FX_TLP*8)-1:0]            int_radm_snoop_bus_num;
wire    [(FX_TLP*5)-1:0]            int_radm_snoop_dev_num;

wire    [FX_TLP-1:0]                int_radm_inta_asserted;
wire    [FX_TLP-1:0]                int_radm_intb_asserted;
wire    [FX_TLP-1:0]                int_radm_intc_asserted;
wire    [FX_TLP-1:0]                int_radm_intd_asserted;
wire    [FX_TLP-1:0]                int_radm_inta_deasserted;
wire    [FX_TLP-1:0]                int_radm_intb_deasserted;
wire    [FX_TLP-1:0]                int_radm_intc_deasserted;
wire    [FX_TLP-1:0]                int_radm_intd_deasserted;
wire    [FX_TLP-1:0]                int_radm_correctable_err;
wire    [FX_TLP-1:0]                int_radm_nonfatal_err;
wire    [FX_TLP-1:0]                int_radm_fatal_err;

wire                             s_radm_msg_unlock;            // Received unlock message
wire                             s_radm_slot_pwr_limit;        // Received Slot power limit MSG
wire    [31:0]                   s_radm_slot_pwr_payload;      // Received msg data associated with slot limit

wire    [FX_TLP-1:0]             s_radm_vendor_msg;            // Received vendor message with message paylod in msg data
wire    [(FX_TLP*64)-1:0]        s_radm_msg_payload;           // Received msg data associated with slot limit
wire    [(FX_TLP*16)-1:0]        s_radm_msg_req_id;            // Received Requester ID
wire  [FX_TLP-1:0]               s_radm_pm_pme;                // Received PM_PME MSG
wire                             s_radm_pm_turnoff;            // Received PM_TURNOFF
wire                             s_radm_pm_to_ack;             // Received PM_TO_ACK
wire                             s_radm_pm_asnak;              // Received PM_AS_NAK
wire   [FX_TLP-1:0]              s_radm_correctable_err;
wire   [FX_TLP-1:0]              s_radm_nonfatal_err;
wire   [FX_TLP-1:0]              s_radm_fatal_err;




assign 
                    {
                   radm_msg_unlock,
                   radm_slot_pwr_limit,
                   radm_slot_pwr_payload,
                   radm_vendor_msg,
                   radm_msg_payload,
                   radm_msg_req_id,
                   radm_pm_pme,
                   radm_pm_turnoff,
                   radm_pm_to_ack,
                   radm_pm_asnak,
                   radm_correctable_err,
                   radm_nonfatal_err,
                   radm_fatal_err
                    } = 
                    {
                    s_radm_msg_unlock,
                    s_radm_slot_pwr_limit,
                    s_radm_slot_pwr_payload,
                    s_radm_vendor_msg,
                    s_radm_msg_payload,
                    s_radm_msg_req_id,
                    s_radm_pm_pme,
                    s_radm_pm_turnoff,
                    s_radm_pm_to_ack,
                    s_radm_pm_asnak,
                    s_radm_correctable_err,
                    s_radm_nonfatal_err,
                    s_radm_fatal_err
                    } ;







// Message Handling
assign s_radm_msg_unlock            = int_radm_msg_unlock[0];           // Unlock Message Received
assign s_radm_slot_pwr_limit        = int_radm_slot_pwr_limit[0];
assign s_radm_slot_pwr_payload      = int_radm_msg_payload[31:0];
assign s_radm_vendor_msg            = int_radm_vendor_msg[0];
assign s_radm_msg_payload           = int_radm_msg_payload[63:0];
assign s_radm_msg_req_id            = int_radm_msg_req_id[15:0];




// Power Management TLP Handling
assign s_radm_pm_pme                = int_radm_pm_pme[0];
assign s_radm_pm_to_ack             = |int_radm_pm_to_ack;  // PME_TO_ACK received by either filter
assign s_radm_pm_asnak              = |int_radm_pm_asnak;
assign s_radm_pm_turnoff            = |int_radm_pm_turnoff;

// Error Reporting TLP Handling
assign radm_unexp_cpl_err         = int_radm_unexp_cpl_err[NF-1:0];
assign radm_rcvd_cpl_ca           = int_radm_rcvd_cpl_ca[NF-1:0];
assign radm_rcvd_cpl_ur           = int_radm_rcvd_cpl_ur[NF-1:0];
assign radm_mlf_tlp_err           = int_radm_mlf_tlp_err[NF-1:0];
assign radm_ecrc_err              = int_radm_ecrc_err[NF-1:0];
assign radm_rcvd_wreq_poisoned    = int_radm_rcvd_wreq_poisoned[NF-1:0];
assign radm_rcvd_cpl_poisoned     = int_radm_rcvd_cpl_poisoned[NF-1:0];
assign radm_rcvd_req_ur           = int_radm_rcvd_req_ur[NF-1:0];
assign radm_rcvd_req_ca           = int_radm_rcvd_req_ca[NF-1:0];
assign radm_hdr_log_valid         = int_radm_hdr_log_valid[NF-1:0];
assign radm_hdr_log               = int_radm_hdr_log[HW-1:0];
assign s_radm_correctable_err       = int_radm_correctable_err[0];
assign s_radm_nonfatal_err          = int_radm_nonfatal_err[0];
assign s_radm_fatal_err             = int_radm_fatal_err[0];

assign radm_inta_asserted         = |int_radm_inta_asserted && ~|int_radm_inta_deasserted;
assign radm_intb_asserted         = |int_radm_intb_asserted && ~|int_radm_intb_deasserted;
assign radm_intc_asserted         = |int_radm_intc_asserted && ~|int_radm_intc_deasserted;
assign radm_intd_asserted         = |int_radm_intd_asserted && ~|int_radm_intd_deasserted;
assign radm_inta_deasserted       = |int_radm_inta_deasserted && ~|int_radm_inta_asserted;
assign radm_intb_deasserted       = |int_radm_intb_deasserted && ~|int_radm_intb_asserted;
assign radm_intc_deasserted       = |int_radm_intc_deasserted && ~|int_radm_intc_asserted;
assign radm_intd_deasserted       = |int_radm_intd_deasserted && ~|int_radm_intd_asserted;

// Configuration Request Snooping Logic
assign radm_snoop_upd             = int_radm_snoop_upd[0];
assign radm_snoop_bus_num         = int_radm_snoop_bus_num[7:0];
assign radm_snoop_dev_num         = int_radm_snoop_dev_num[4:0];




wire [NHQ*`FLT_Q_ADDR_WIDTH-1:0]    int_radm_bypass_addr;          // bypass pcie hdr field addr
wire [NHQ*TRGT1_ADDR_WD-1:0]        radm_bypass_addr_tmp;           // for RAS implementation
wire [NHQ*4-1:0]                    int_radm_bypass_first_be;       // trgt1 pcie hdr field first_be
wire [NHQ*4-1:0]                    int_radm_bypass_last_be;        // trgt1 pcie hdr field last_be
wire [NHQ-1:0]                      cpl_type;

//`ifdef CX_RAS_EN
wire [DW_OUT_W_PAR-1:0]      radm_bypass_data_i; 
wire [NW-1:0]                radm_bypass_dwen_i;
wire [NHQ-1:0]               radm_bypass_dllp_abort_i;
wire [NHQ-1:0]               radm_bypass_tlp_abort_i;
wire [NHQ-1:0]               radm_bypass_ecrc_err_i;
wire [NHQ-1:0]               radm_bypass_dv_i;
wire [NHQ-1:0]               radm_bypass_hv_i;
wire [NHQ-1:0]               radm_bypass_eot_i;
wire [NHQ-1:0]               radm_bypass_bcm_i;
wire [NHQ*12-1:0]            radm_bypass_byte_cnt_i;
wire [NHQ*16-1:0]            radm_bypass_cmpltr_id_i;
wire [NHQ-1:0]               radm_bypass_cpl_last_i;
wire [NHQ*4-1:0]             radm_bypass_last_be_i;
wire [NHQ-1:0]               radm_bypass_poisoned_i;
wire [NHQ-1:0]               radm_bypass_td_i;
wire [NHQ*TRGT1_ADDR_WD-1:0] radm_bypass_addr_i;
wire [NHQ*4-1:0]             radm_bypass_first_be_i;
wire [NHQ-1:0]               radm_bypass_io_req_in_range_i;
wire [NHQ-1:0]               radm_bypass_rom_in_range_i;
wire [NHQ*3-1:0]             radm_bypass_in_membar_range_i;
wire [NHQ*10-1:0]            radm_bypass_dw_len_i;
wire [NHQ*3-1:0]             radm_bypass_cpl_status_i;
wire [NHQ*PF_WD-1:0]         radm_bypass_func_num_i;

wire [NHQ*TAG_SIZE-1:0]      radm_bypass_tag_i;
wire [NHQ*16-1:0]            radm_bypass_reqid_i;
wire [NHQ*ATTR_WD-1:0]       radm_bypass_attr_i;
wire [NHQ*3-1:0]             radm_bypass_tc_i;
wire [NHQ*5-1:0]             radm_bypass_type_i;
wire [NHQ*2-1:0]             radm_bypass_fmt_i;
// `endif // CX_RAS_EN
wire [NHQ-1:0]               radm_bypass_cpl_last_ii;
wire [NHQ*4-1:0]             radm_bypass_last_be_ii;
wire [NHQ-1:0]               radm_bypass_poisoned_ii;
wire [NHQ-1:0]               radm_bypass_td_ii;
wire [NHQ*TRGT1_ADDR_WD-1:0] radm_bypass_addr_ii;
wire [NHQ*4-1:0]             radm_bypass_first_be_ii;
wire [NHQ-1:0]               radm_bypass_io_req_in_range_ii;
wire [NHQ-1:0]               radm_bypass_rom_in_range_ii;
wire [NHQ*3-1:0]             radm_bypass_in_membar_range_ii;
wire [NHQ*10-1:0]            radm_bypass_dw_len_ii;
wire [NHQ*3-1:0]             radm_bypass_cpl_status_ii;
wire [NHQ*PF_WD-1:0]         radm_bypass_func_num_ii;

wire [NHQ*TAG_SIZE-1:0]      radm_bypass_tag_ii;
wire [NHQ*16-1:0]            radm_bypass_reqid_ii;
wire [NHQ*ATTR_WD-1:0]       radm_bypass_attr_ii;
wire [NHQ*3-1:0]             radm_bypass_tc_ii;
wire [NHQ*5-1:0]             radm_bypass_type_ii;
wire [NHQ*2-1:0]             radm_bypass_fmt_ii;


genvar g_byp;
generate for(g_byp = 0; g_byp < NHQ; g_byp = g_byp + 1) begin : BYPASS_EXTRACT
  
assign cpl_type[g_byp]  = (
    ({radm_bypass_fmt_i[g_byp*2 +: 2],radm_bypass_type_i[g_byp*5 +: 5]} == `CPLLK) ||
    ({radm_bypass_fmt_i[g_byp*2 +: 2],radm_bypass_type_i[g_byp*5 +: 5]} == `CPLDLK)  ||
    ({radm_bypass_fmt_i[g_byp*2 +: 2],radm_bypass_type_i[g_byp*5 +: 5]} == `CPL) ||
    ({radm_bypass_fmt_i[g_byp*2 +: 2],radm_bypass_type_i[g_byp*5 +: 5]} == `CPLD));

assign radm_bypass_fmt_i[g_byp*2 +: 2]                = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR +`FLT_Q_FMT_FO +: 2];        // completion hdr element
assign radm_bypass_type_i[g_byp*5 +: 5]               = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR +`FLT_Q_TYPE_FO +: 5];        // completion hdr element
assign radm_bypass_tc_i[g_byp*3 +: 3]                 = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR +`FLT_Q_TC_FO +: 3];        // completion hdr element
assign radm_bypass_attr_i[g_byp*ATTR_WD +: ATTR_WD]   = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR +`FLT_Q_ATTR_FO +: ATTR_WD];        // completion hdr element
assign radm_bypass_reqid_i[g_byp*16 +: 16]            = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR +`FLT_Q_REQID_FO +: 16];        // completion hdr element
assign radm_bypass_tag_i[g_byp*TAG_SIZE +: TAG_SIZE]  = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR +`FLT_Q_TAG_FO +: TAG_SIZE];    // completion hdr element
assign radm_bypass_func_num_i[g_byp*PF_WD +: PF_WD]   = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR +`FLT_Q_FUNC_NMBR_FO +: PF_WD];        // for cfg transaction only
assign radm_bypass_cpl_status_i[g_byp*3 +: 3]         = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `FLT_Q_CPL_STATUS_FO +: 3];        // completion hdr element
assign radm_bypass_td_i[g_byp]                        = cpl_type[g_byp] ?
    radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_CPLQ_TD_FO +: 1] :
    radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_TD_FO +: 1];
assign radm_bypass_poisoned_i[g_byp]                  = cpl_type[g_byp] ?
    radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_CPLQ_EP_FO +: 1] :
    radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_EP_FO +: 1];
assign radm_bypass_dw_len_i[g_byp*10 +: 10]           = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_DW_LENGTH_FO +: 10];// completion hdr element
assign int_radm_bypass_first_be[g_byp*4 +: 4]         = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_FRSTDW_BE_FO +: 4];// completion hdr & TRGT0 contro // no need for completion type
// MUTUALLY EXCLUSIVE macros

assign int_radm_bypass_addr[g_byp*`FLT_Q_ADDR_WIDTH +: `FLT_Q_ADDR_WIDTH] =
    cpl_type[g_byp] ?
    {{`FLT_Q_ADDR_WIDTH-`FLT_Q_CPL_LOWER_ADDR_WIDTH{1'b0}},radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_CPL_LOWER_ADDR_FO +: `FLT_Q_CPL_LOWER_ADDR_WIDTH]} :
    radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_ADDR_FO +: `FLT_Q_ADDR_WIDTH];       // completion hdr & TRGT0 control

assign radm_bypass_addr_tmp[g_byp*`FLT_Q_ADDR_WIDTH +: `FLT_Q_ADDR_WIDTH] = int_radm_bypass_addr[g_byp*`FLT_Q_ADDR_WIDTH +: `FLT_Q_ADDR_WIDTH];

assign radm_bypass_addr_i[g_byp*`FLT_Q_ADDR_WIDTH +: `FLT_Q_ADDR_WIDTH] = radm_bypass_addr_tmp [g_byp*`FLT_Q_ADDR_WIDTH +: `FLT_Q_ADDR_WIDTH];


assign radm_bypass_rom_in_range_i[g_byp]           = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_ROM_IN_RANGE_FO];  // only PQ or NPQ has this info
assign radm_bypass_io_req_in_range_i[g_byp]        = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_IO_REQ_IN_RANGE_FO];  // only PQ or NPQ has this info
assign radm_bypass_in_membar_range_i[g_byp*3 +: 3] = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_IN_MEMBAR_RANGE_FO +: 3];  // only PQ or NPQ has this info
assign int_radm_bypass_last_be[g_byp*4 +: 4]       = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_PQ_LSTDW_BE_FO +: 4];  // only PQ or NPQ has this info
assign radm_bypass_cpl_last_i[g_byp]               = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_CPLQ_CPL_LAST_FO     ];
assign radm_bypass_bcm_i[g_byp]                    = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_CPLQ_BCM_FO          ];
assign radm_bypass_byte_cnt_i[g_byp*12 +: 12]      = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_CPLQ_BYTE_CNT_FO +: 12];
assign radm_bypass_cmpltr_id_i[g_byp*16 +: 16]     = radm_bypass_hdr[g_byp*RADM_P_HWD_WO_PAR + `RADM_CPLQ_CMPLTR_ID_FO +: 16];
assign radm_bypass_first_be_i[g_byp*4 +: 4] = int_radm_bypass_first_be[g_byp*4 +: 4];
assign radm_bypass_last_be_i[g_byp*4 +: 4]  = int_radm_bypass_last_be[g_byp*4 +: 4];
end
endgenerate

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

// ------------ muxes for dual mode ------------------------
always @(*) begin : RX_NF_EXPANSION
    integer i;
    rc_radm_rcvd_cpl_ur         = 0;
    rc_radm_rcvd_cpl_ca         = 0;
    rc_radm_unexp_cpl_err       = 0;
    rc_radm_ecrc_err            = 0;
    rc_radm_mlf_tlp_err         = 0;
    rc_radm_rcvd_wreq_poisoned  = 0;
    rc_radm_rcvd_cpl_poisoned   = 0;
    rc_radm_rcvd_req_ur         = 0;
    rc_radm_rcvd_req_ca         = 0;
    rc_radm_hdr_log_valid       = 0;
    for(i = 0; i < FX_TLP; i = i + 1) begin
        rc_radm_rcvd_cpl_ur[NF*i]           = int_rc_radm_rcvd_cpl_ur[i];
        rc_radm_rcvd_cpl_ca[NF*i]           = int_rc_radm_rcvd_cpl_ca[i];
        rc_radm_unexp_cpl_err[NF*i]         = int_rc_radm_unexp_cpl_err[i];
        rc_radm_ecrc_err[NF*i]              = int_rc_radm_ecrc_err[i];
        rc_radm_mlf_tlp_err[NF*i]           = int_rc_radm_mlf_tlp_err[i];
        rc_radm_rcvd_wreq_poisoned[NF*i]    = int_rc_radm_rcvd_wreq_poisoned[i];
        rc_radm_rcvd_cpl_poisoned[NF*i]     = int_rc_radm_rcvd_cpl_poisoned[i];
        rc_radm_rcvd_req_ur[NF*i]           = int_rc_radm_rcvd_req_ur[i];
        rc_radm_rcvd_req_ca[NF*i]           = int_rc_radm_rcvd_req_ca[i];
        rc_radm_hdr_log_valid[NF*i]         = int_rc_radm_hdr_log_valid[i];
    end
end
assign flt_q_header             = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_header            : rc_flt_q_header;
assign flt_q_hv                 = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_hv                : rc_flt_q_hv ;
assign flt_q_dv                 = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_dv                : rc_flt_q_dv;
assign flt_q_data               = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_data              : rc_flt_q_data;
assign flt_q_dwen               = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_dwen              : rc_flt_q_dwen;
assign flt_q_eot                = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_eot               : rc_flt_q_eot;
assign flt_q_tlp_type           = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_tlp_type          : rc_flt_q_tlp_type;
assign flt_q_parerr             = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_parerr            : rc_flt_q_parerr;
assign flt_q_seg_num            = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_seg_num           : rc_flt_q_seg_num;
assign flt_q_vc                 = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_vc                : rc_flt_q_vc;
assign flt_q_dllp_abort         = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_dllp_abort        : rc_flt_q_dllp_abort;
assign flt_q_tlp_abort          = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_tlp_abort         : rc_flt_q_tlp_abort;
assign flt_q_ecrc_err           = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_ecrc_err          : rc_flt_q_ecrc_err;

assign int_radm_msg_payload         = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_msg_payload        : rc_radm_msg_payload;
assign int_radm_pm_pme              = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_pm_pme             : rc_radm_pm_pme;
assign int_radm_pm_turnoff          = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_pm_turnoff         : rc_radm_pm_turnoff;
assign int_radm_pm_to_ack           = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_pm_to_ack          : rc_radm_pm_to_ack;
assign int_radm_pm_asnak            = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_pm_asnak           : rc_radm_pm_asnak;
assign int_radm_msg_req_id          = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_msg_req_id         : rc_radm_msg_req_id;
assign int_radm_vendor_msg          = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_vendor_msg         : rc_radm_vendor_msg;

assign int_radm_rcvd_cpl_ur         = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_rcvd_cpl_ur        : rc_radm_rcvd_cpl_ur;
assign int_radm_rcvd_cpl_ca         = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_rcvd_cpl_ca        : rc_radm_rcvd_cpl_ca;
assign int_radm_unexp_cpl_err       = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_unexp_cpl_err      : rc_radm_unexp_cpl_err;
assign int_radm_ecrc_err            = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_ecrc_err           : rc_radm_ecrc_err;
assign int_radm_mlf_tlp_err         = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_mlf_tlp_err        : rc_radm_mlf_tlp_err;
assign int_radm_rcvd_wreq_poisoned  = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_rcvd_wreq_poisoned : rc_radm_rcvd_wreq_poisoned;
assign int_radm_rcvd_cpl_poisoned   = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_rcvd_cpl_poisoned  : rc_radm_rcvd_cpl_poisoned;
assign int_radm_rcvd_req_ur         = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_rcvd_req_ur        : rc_radm_rcvd_req_ur;
assign int_radm_rcvd_req_ca         = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_rcvd_req_ca        : rc_radm_rcvd_req_ca;
assign int_radm_hdr_log_valid       = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_hdr_log_valid      : rc_radm_hdr_log_valid;
assign int_radm_hdr_log             = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_hdr_log            : rc_radm_hdr_log;

assign flt_cdm_addr             = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_cdm_addr            : rc_flt_cdm_addr;
assign cpl_tlp                  = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_cpl_tlp                 : rc_cpl_tlp;
assign tlp_poisoned             = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_tlp_poisoned            : rc_tlp_poisoned;
assign flt_dwlenEq0             = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_dwlenEq0            : rc_flt_dwlenEq0;
assign flt_q_rcvd_cpl_tlp_tag   = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_flt_q_rcvd_cpl_tlp_tag  : rc_flt_q_rcvd_cpl_tlp_tag;
assign cpl_status               = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_cpl_status              : rc_cpl_status;
assign int_radm_snoop_upd       = ((device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY)) ? ep_radm_snoop_upd          : 0;


// register the inputs from Cdm
reg cfg_ecrc_chk_en_or;
always @(posedge radm_clk_ug or negedge core_rst_n)
    if (!core_rst_n) begin
        cfg_ecrc_chk_en_or <= #TP 0;
    end else begin
        cfg_ecrc_chk_en_or <= #TP |cfg_ecrc_chk_en;
    end

// ECRC error will be masked if none of the function enables ECRC checking.
wire   [RX_TLP-1:0] int_rtlh_radm_ecrc_err;
assign int_rtlh_radm_ecrc_err = rtlh_radm_ecrc_err & {RX_TLP{cfg_ecrc_chk_en_or}};

    wire radm_parerr_tmp;

    assign  radm_parerr = |{radm_parerr_tmp,radm_trgt0_parerr,radm_trgt1_parerr};


radm_formation

#(INST) u_radm_formation (
    // ----------- Inputs -----------------
    .clk                        (core_clk),
    .rst_n                      (core_rst_n),
    .rtlh_radm_hv               (rtlh_radm_hv),
    .rtlh_radm_hdr              (rtlh_radm_hdr),
    .rtlh_radm_dv               (rtlh_radm_dv),
    .rtlh_radm_data             (rtlh_radm_data),
    .rtlh_radm_eot              (rtlh_radm_eot),
    .rtlh_radm_dwen             (rtlh_radm_dwen),
    .rtlh_radm_dllp_err         (rtlh_radm_dllp_err),
    .rtlh_radm_malform_tlp_err  (rtlh_radm_malform_tlp_err),
    .rtlh_radm_ecrc_err         (int_rtlh_radm_ecrc_err),
    .rtlh_radm_ant_addr         (rtlh_radm_ant_addr),
    .rtlh_radm_ant_rid          (rtlh_radm_ant_rid),
    .cfg_io_match               (cfg_io_match),
    .cfg_config_above_match     (cfg_config_above_match),
    .cfg_bar_match              (cfg_bar_match),
    .cfg_rom_match              (cfg_rom_match),
    .cfg_prefmem_match          (cfg_prefmem_match),
    .cfg_mem_match              (cfg_mem_match),

    // ----------- Outputs -----------------
    .form_filt_hv               (form_filt_hv),
    .form_filt_hdr              (form_filt_hdr),
    .form_filt_dv               (form_filt_dv),
    .form_filt_data             (form_filt_data),
    .form_filt_eot              (form_filt_eot),
    .form_filt_dwen             (form_filt_dwen),
    .form_filt_dllp_err         (form_filt_dllp_err),
    .form_filt_malform_tlp_err  (form_filt_malform_tlp_err),
    .form_filt_ecrc_err         (form_filt_ecrc_err),
    .form_filt_ant_addr         (form_filt_ant_addr),
    .form_filt_ant_rid          (form_filt_ant_rid),
    .form_filt_io_match         (form_filt_io_match),
    .form_filt_config_above_match   (form_filt_config_above_match),
    .form_filt_bar_match        (form_filt_bar_match),
    .form_filt_rom_match        (form_filt_rom_match),
    .form_filt_prefmem_match    (form_filt_prefmem_match),
    .form_filt_mem_match        (form_filt_mem_match),
    .form_par_err               (form_filt_parerr)
);

// @@@@@@@@@@@@@@@@
// @@@ PIPELINE @@@
// @@@@@@@@@@@@@@@@

 reg    [FX_TLP-1:0]                form_filt_hv_reg;
 reg    [(FX_TLP*(128+HDR_PROT_WD))-1:0]  form_filt_hdr_reg;
 reg    [FX_TLP-1:0]                form_filt_dv_reg;
 reg    [FX_TLP-1:0]                form_filt_parerr_reg;
 reg    [(FX_TLP*(DW+DATA_PAR_WD))-1:0] form_filt_data_reg;
 reg    [FX_TLP-1:0]                form_filt_eot_reg;
 reg    [(FX_TLP*NW)-1:0]           form_filt_dwen_reg;
 reg    [FX_TLP-1:0]                form_filt_dllp_err_reg;
 reg    [FX_TLP-1:0]                form_filt_malform_tlp_err_reg;
 reg    [FX_TLP-1:0]                form_filt_ecrc_err_reg;
 reg    [(FX_TLP*64)-1:0]           form_filt_ant_addr_reg;
 reg    [(FX_TLP*16)-1:0]           form_filt_ant_rid_reg;

    parameter RADM_CPL_LUT_PIPE_EN = `CX_RADM_CPL_LUT_PIPE_EN_VALUE;
    parameter FORM_FLT_WD = FX_TLP + (FX_TLP*(128+HDR_PROT_WD))

                          + 2*FX_TLP + (FX_TLP*(DW+DATA_PAR_WD)) 
                          + FX_TLP + (FX_TLP*NW) + 3*FX_TLP

 
 
 
                          ;
    parameter ANT_PIPE_WD = (FX_TLP * 64) + (FX_TLP * 16);
                                 
    wire [FORM_FLT_WD-1:0] form_flt_pipe_in;
    wire [FORM_FLT_WD-1:0] form_flt_pipe_out;
    wire [(ANT_PIPE_WD - 1) : 0] rtlh_ant_pipe_in;
    wire [(ANT_PIPE_WD - 1) : 0] rtlh_ant_pipe_out;

    assign rtlh_ant_pipe_in = {form_filt_ant_addr, form_filt_ant_rid};

    // ant_rid and ant_addr pipeline clocked by ungated radm_clk to insure that the updates
    // can be clocked through while waiting for the clock to be enabled
    delay_n_w_enable
    
    #(RADM_CPL_LUT_PIPE_EN, ANT_PIPE_WD) u_pipeline_ant_bus(
        .clk        (radm_clk_ug),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .en         (1'b1),
        .din        (rtlh_ant_pipe_in),
        .dout       (rtlh_ant_pipe_out)
    );


    assign {form_filt_ant_addr_reg, form_filt_ant_rid_reg} = rtlh_ant_pipe_out;

    assign form_flt_pipe_in = {
                              form_filt_hv,
                              form_filt_hdr,
                              form_filt_dv,
                              form_filt_parerr,
                              form_filt_data,
                              form_filt_eot,
                              form_filt_dwen,
                              form_filt_dllp_err,
                              form_filt_malform_tlp_err,
                              form_filt_ecrc_err
                            };

        delay_n_w_enable
        
        #(RADM_CPL_LUT_PIPE_EN, FORM_FLT_WD) u_pipeline_form_filt_bus(
            .clk        (core_clk),
            .rst_n      (core_rst_n),
            .clear      (1'b0),
            .en         (1'b1),
            .din        (form_flt_pipe_in),
            .dout       (form_flt_pipe_out)
        );
    
    assign {
                              form_filt_hv_reg,
                              form_filt_hdr_reg,
                              form_filt_dv_reg,
                              form_filt_parerr_reg,
                              form_filt_data_reg,
                              form_filt_eot_reg,
                              form_filt_dwen_reg,
                              form_filt_dllp_err_reg,
                              form_filt_malform_tlp_err_reg,
                              form_filt_ecrc_err_reg
            } = form_flt_pipe_out;

        wire                         rtlh_radm_pending_pipe_in;
        wire                         rtlh_radm_pending_pipe_out;
    
        assign rtlh_radm_pending_pipe_in  = rtlh_radm_pending;

        delay_n_w_enable
        
        #(RADM_CPL_LUT_PIPE_EN, 1) u_pipeline_rtlh_pending_bit(
            .clk        (radm_clk_ug),
            .rst_n      (core_rst_n),
            .clear      (1'b0),
            .en         (1'b1),
            .din        (rtlh_radm_pending_pipe_in),
            .dout       (rtlh_radm_pending_pipe_out)
        );


    // Keep pipeline for flt_cdm_rtlh_radm_pending aligned with the pipeline of flt_cdm_addr which is the rtlh_ant_addr
    assign flt_cdm_rtlh_radm_pending = rtlh_radm_pending_pipe_out;


// @@@@@@@@@@@@@@@@@@@@
// @@@ END PIPELINE @@@
// @@@@@@@@@@@@@@@@@@@@


assign cdm_err_advisory         = {FX_TLP{1'b0}};



radm_clk_control

  #(
    .NF               (NF),
    .XTLH_PIPE_DELAY  (XTLH_PIPE_DELAY),
    .NVC              (NVC),
    .CPL_LUT_DEPTH    (CPL_LUT_DEPTH)
  ) u_radm_clk_control (
  .radm_clk_ug            (radm_clk_ug),
  .core_rst_n             (core_rst_n),
  .clock_gating_en        (cfg_radm_clk_control),
  .sb_init_done           (sb_init_done),
  .rtlh_radm_pending      (rtlh_radm_pending),
  // FLR
  .radm_cpl_lut_valid     (radm_cpl_lut_valid),
  .radm_cpl_lut_pending   (radm_cpl_lut_pending),
  .radm_cpl_lut_busy      (radm_cpl_lut_busy),
  .radm_q_not_empty       (radm_q_not_empty),
  .radm_trgt0_hv          (radm_trgt0_hv),
  .radm_trgt0_dv          (radm_trgt0_dv),
  .radm_trgt1_hv          (radm_trgt1_hv),
  .radm_trgt1_dv          (radm_trgt1_dv),
  .radm_rtlh_crd_pending  (radm_rtlh_crd_pending),
  .radm_idle              (radm_idle),
  .radm_clk_en            (radm_clk_en)
);


genvar num_tlp;
generate
for (num_tlp=0; num_tlp<FX_TLP; num_tlp = num_tlp+1) begin : u_radm_gen

radm_filter_ep

#(.INST(INST), .FLT_NUM(num_tlp)) u_radm_filter_ep (
    // ----------- Inputs -----------------
    .core_clk                   (core_clk),
    .radm_clk_ug                (radm_clk_ug),
    .core_rst_n                 (core_rst_n),
    .app_req_retry_en           (app_req_retry_en),
    .app_pf_req_retry_en        (app_pf_req_retry_en),
    .rtlh_radm_hv               (form_filt_hv_reg[num_tlp]),
    .rtlh_radm_hdr              (form_filt_hdr_reg[(128+HDR_PROT_WD)*(num_tlp+1)-1:(128+HDR_PROT_WD)*num_tlp]),
    .rtlh_radm_dv               (form_filt_dv_reg[num_tlp]),
    .rtlh_radm_parerr           (form_filt_parerr_reg[num_tlp]),
    .rtlh_radm_data             (form_filt_data_reg[(DW+DATA_PAR_WD)*(num_tlp+1)-1:(DW+DATA_PAR_WD)*num_tlp]),
    .rtlh_radm_dwen             (form_filt_dwen_reg[NW*(num_tlp+1)-1:NW*num_tlp]),
    .rtlh_radm_eot              (form_filt_eot_reg[num_tlp]),
    .rtlh_radm_dllp_err         (form_filt_dllp_err_reg[num_tlp]),
    .rtlh_radm_malform_tlp_err  (form_filt_malform_tlp_err_reg[num_tlp]),
    .rtlh_radm_ecrc_err         (form_filt_ecrc_err_reg[num_tlp]),
    .cfg_bar_is_io              (cfg_bar_is_io),
    .cfg_io_match               (form_filt_io_match[NF*(num_tlp+1)-1:NF*num_tlp]),
    .cfg_bar_match              (form_filt_bar_match[6*NF*(num_tlp+1)-1:6*NF*num_tlp]), 
    .cfg_rom_match              (form_filt_rom_match[NF*(num_tlp+1)-1:NF*num_tlp]),
    .cfg_tc_struc_vc_map        (cfg_tc_struc_vc_map),
    .cfg_rcb_128                (cfg_rcb_128),
    .default_target             (default_target),
    .ur_ca_mask_4_trgt1         (ur_ca_mask_4_trgt1),
    .cfg_target_above_config_limit (cfg_target_above_config_limit),
    .cfg_cfg_tlp_bypass_en      (cfg_cfg_tlp_bypass_en),
    .target_mem_map             (target_mem_map),
    .target_rom_map             (target_rom_map),
    .upstream_port              (upstream_port),
    .cpl_mlf_err                (cpl_mlf_err[num_tlp]),
    .flt_q_cpl_abort            (flt_q_cpl_abort[num_tlp]),
    .flt_q_cpl_last             (flt_q_cpl_last[num_tlp]),
    .cpl_ur_err                 (cpl_ur_err[num_tlp]),
    .cpl_ca_err                 (cpl_ca_err[num_tlp]),
    .unexpected_cpl_err         (unexpected_cpl_err[num_tlp]),
    .vendor_msg_id_match        (vendor_msg_id_match[num_tlp]),

    .pm_radm_block_tlp          (pm_radm_block_tlp),
    .cfg_filter_rule_mask       (cfg_filter_rule_mask),
    .cfg_config_above_match     (form_filt_config_above_match[NF*(num_tlp+1)-1:NF*num_tlp]),
    .cfg_max_func_num           (cfg_max_func_num),

 
    .cfg_pbus_num               (cfg_pbus_num),
    .cfg_pbus_dev_num           (cfg_pbus_dev_num),

    .rtlh_radm_ant_addr         (form_filt_ant_addr_reg[64*(num_tlp+1)-1:64*num_tlp]),
    .rtlh_radm_ant_rid          (form_filt_ant_rid_reg[16*(num_tlp+1)-1:16*num_tlp]),

    // ----------- Outputs -----------------
    .cpl_tlp                    (ep_cpl_tlp[num_tlp]),
    .tlp_poisoned               (ep_tlp_poisoned[num_tlp]),
    .flt_dwlenEq0               (ep_flt_dwlenEq0[num_tlp]),
    .flt_q_rcvd_cpl_tlp_tag     (ep_flt_q_rcvd_cpl_tlp_tag[TAG_SIZE*(num_tlp+1)-1:TAG_SIZE*num_tlp]),
    .cpl_status                 (ep_cpl_status[3*(num_tlp+1)-1:3*num_tlp]),
    .flt_cdm_addr               (ep_flt_cdm_addr[64*(num_tlp+1)-1:64*num_tlp]),
    .flt_q_tlp_type             (ep_flt_q_tlp_type[3*(num_tlp+1)-1:3*num_tlp]),
    .flt_q_seg_num              (ep_flt_q_seg_num[SEG_WIDTH*(num_tlp+1)-1:SEG_WIDTH*num_tlp]),
    .flt_q_vc                   (ep_flt_q_vc[3*(num_tlp+1)-1:3*num_tlp]),
    .flt_q_header               (ep_flt_q_header[(FLT_Q_HDR_WIDTH+FLT_OUT_PROT_WD)*(num_tlp+1)-1:(FLT_Q_HDR_WIDTH+FLT_OUT_PROT_WD)*num_tlp]),
    .flt_q_hv                   (ep_flt_q_hv[NVC*(num_tlp+1)-1:NVC*num_tlp]),
    .flt_q_dv                   (ep_flt_q_dv[NVC*(num_tlp+1)-1:NVC*num_tlp]),
    .flt_q_data                 (ep_flt_q_data[(DW+DATA_PAR_WD)*(num_tlp+1)-1:(DW+DATA_PAR_WD)*num_tlp]),
    .flt_q_dwen                 (ep_flt_q_dwen[NW*(num_tlp+1)-1:NW*num_tlp]),
    .flt_q_eot                  (ep_flt_q_eot[NVC*(num_tlp+1)-1:NVC*num_tlp]),
    .flt_q_dllp_abort           (ep_flt_q_dllp_abort[num_tlp]),
    .flt_q_tlp_abort            (ep_flt_q_tlp_abort[num_tlp]),
    .flt_q_ecrc_err             (ep_flt_q_ecrc_err[num_tlp]),
    .flt_q_parerr               (ep_flt_q_parerr[num_tlp]),
    .radm_msg_payload           (ep_radm_msg_payload[64*(num_tlp+1)-1:64*num_tlp]),
    .radm_pm_pme                (ep_radm_pm_pme[num_tlp]),
    .radm_pm_to_ack             (ep_radm_pm_to_ack[num_tlp]),
    .radm_pm_asnak              (ep_radm_pm_asnak[num_tlp]),
    .radm_pm_turnoff            (ep_radm_pm_turnoff[num_tlp]),
    .radm_slot_pwr_limit        (int_radm_slot_pwr_limit[num_tlp]),
    .radm_msg_unlock            (int_radm_msg_unlock[num_tlp]),
    .radm_rcvd_tlp_req_id       (ep_radm_msg_req_id[16*(num_tlp+1)-1:16*num_tlp]),
    .radm_vendor_msg            (ep_radm_vendor_msg[num_tlp]),
    .radm_unexp_cpl_err         (ep_radm_unexp_cpl_err[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_rcvd_cpl_ca           (ep_radm_rcvd_cpl_ca[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_rcvd_cpl_ur           (ep_radm_rcvd_cpl_ur[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_mlf_tlp_err           (ep_radm_mlf_tlp_err[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_ecrc_err              (ep_radm_ecrc_err[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_rcvd_wreq_poisoned    (ep_radm_rcvd_wreq_poisoned[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_rcvd_cpl_poisoned     (ep_radm_rcvd_cpl_poisoned[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_rcvd_req_ur           (ep_radm_rcvd_req_ur[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_rcvd_req_ca           (ep_radm_rcvd_req_ca[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_hdr_log_valid         (ep_radm_hdr_log_valid[NF*(num_tlp+1)-1:NF*num_tlp]),
    .radm_hdr_log               (ep_radm_hdr_log[HW*(num_tlp+1)-1:HW*num_tlp]),
    .radm_snoop_upd             (ep_radm_snoop_upd[num_tlp]),
    .radm_snoop_bus_num         (int_radm_snoop_bus_num[8*(num_tlp+1)-1:8*num_tlp]),
    .radm_snoop_dev_num         (int_radm_snoop_dev_num[5*(num_tlp+1)-1:5*num_tlp])
);
radm_filter_rc

#(.INST(INST), .FLT_NUM(num_tlp)) u_radm_filter_rc (
    // ----------- Inputs -----------------
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .upstream_port              (upstream_port),
    .cfg_prefmem_match          (form_filt_prefmem_match[NF*num_tlp]),
    .cfg_mem_match              (form_filt_mem_match[NF*num_tlp]),
    .rtlh_radm_hv               (form_filt_hv_reg[num_tlp]),
    .rtlh_radm_hdr              (form_filt_hdr_reg[(128+HDR_PROT_WD)*(num_tlp+1)-1:(128+HDR_PROT_WD)*num_tlp]),
    .rtlh_radm_dv               (form_filt_dv_reg[num_tlp]),
    .rtlh_radm_parerr           (form_filt_parerr_reg[num_tlp]),
    .rtlh_radm_data             (form_filt_data_reg[(DW+DATA_PAR_WD)*(num_tlp+1)-1:(DW+DATA_PAR_WD)*num_tlp]),
    .rtlh_radm_dwen             (form_filt_dwen_reg[NW*(num_tlp+1)-1:NW*num_tlp]),
    .rtlh_radm_eot              (form_filt_eot_reg[num_tlp]),
    .rtlh_radm_dllp_err         (form_filt_dllp_err_reg[num_tlp]),
    .rtlh_radm_malform_tlp_err  (form_filt_malform_tlp_err_reg[num_tlp]),
    .rtlh_radm_ecrc_err         (form_filt_ecrc_err_reg[num_tlp]),
    .cfg_bar_is_io              (cfg_bar_is_io[5:0]),
    .cfg_io_match               (form_filt_io_match[NF*num_tlp]),
    .cfg_bar_match              (form_filt_bar_match[6*NF*num_tlp +: 6]),
    .cfg_rom_match              (form_filt_rom_match[NF*num_tlp]),
    .cfg_tc_struc_vc_map        (cfg_tc_struc_vc_map),
    .cfg_rcb_128                (cfg_rcb_128),
    .default_target             (default_target),
    .cfg_p2p_err_rpt_ctrl       (cfg_p2p_err_rpt_ctrl),
    .cpl_mlf_err                (cpl_mlf_err[num_tlp]),
    .flt_q_cpl_abort            (flt_q_cpl_abort[num_tlp]),
    .flt_q_cpl_last             (flt_q_cpl_last[num_tlp]),
    .cpl_ur_err                 (cpl_ur_err[num_tlp]),
    .cpl_ca_err                 (cpl_ca_err[num_tlp]),
    .unexpected_cpl_err         (unexpected_cpl_err[num_tlp]),

    .pm_radm_block_tlp          (pm_radm_block_tlp[0]),
    .cfg_filter_rule_mask       (cfg_filter_rule_mask),
    .rtlh_radm_ant_addr         (form_filt_ant_addr_reg[64*(num_tlp+1)-1:64*num_tlp]),
    .cfg_2ndbus_num             (cfg_2ndbus_num[7:0]),
    .cfg_subbus_num             (cfg_subbus_num[7:0]),

    // ----------- Outputs -----------------

    .cpl_tlp                    (rc_cpl_tlp[num_tlp]),
    .tlp_poisoned               (rc_tlp_poisoned[num_tlp]),
    .flt_dwlenEq0               (rc_flt_dwlenEq0[num_tlp]),
    .flt_q_rcvd_cpl_tlp_tag     (rc_flt_q_rcvd_cpl_tlp_tag[TAG_SIZE*(num_tlp+1)-1:TAG_SIZE*num_tlp]),
    .cpl_status                 (rc_cpl_status[3*(num_tlp+1)-1:3*num_tlp]),
    .flt_cdm_addr               (rc_flt_cdm_addr[64*(num_tlp+1)-1:64*num_tlp]),
    .flt_q_tlp_type             (rc_flt_q_tlp_type[3*(num_tlp+1)-1:3*num_tlp]),
    .flt_q_seg_num              (rc_flt_q_seg_num[SEG_WIDTH*(num_tlp+1)-1:SEG_WIDTH*num_tlp]),
    .flt_q_vc                   (rc_flt_q_vc[3*(num_tlp+1)-1:3*num_tlp]),
    .flt_q_header               (rc_flt_q_header[(FLT_Q_HDR_WIDTH+FLT_OUT_PROT_WD)*(num_tlp+1)-1:(FLT_Q_HDR_WIDTH+FLT_OUT_PROT_WD)*num_tlp]),
    .flt_q_hv                   (rc_flt_q_hv[NVC*(num_tlp+1)-1:NVC*num_tlp]),
    .flt_q_dv                   (rc_flt_q_dv[NVC*(num_tlp+1)-1:NVC*num_tlp]),
    .flt_q_data                 (rc_flt_q_data[(DW+DATA_PAR_WD)*(num_tlp+1)-1:(DW+DATA_PAR_WD)*num_tlp]),
    .flt_q_dwen                 (rc_flt_q_dwen[NW*(num_tlp+1)-1:NW*num_tlp]),
    .flt_q_eot                  (rc_flt_q_eot[NVC*(num_tlp+1)-1:NVC*num_tlp]),
    .flt_q_ecrc_err             (rc_flt_q_ecrc_err[num_tlp]),
    .flt_q_dllp_abort           (rc_flt_q_dllp_abort[num_tlp]),
    .flt_q_tlp_abort            (rc_flt_q_tlp_abort[num_tlp]),
    .flt_q_parerr               (rc_flt_q_parerr[num_tlp]),
    .radm_msg_payload           (rc_radm_msg_payload[64*(num_tlp+1)-1:64*num_tlp]),
    .radm_pm_asnak              (rc_radm_pm_asnak[num_tlp]),
    .radm_pm_pme                (rc_radm_pm_pme[num_tlp]),
    .radm_pm_turnoff            (rc_radm_pm_turnoff[num_tlp]),
    .radm_pm_to_ack             (rc_radm_pm_to_ack[num_tlp]),
    .radm_unlock                (),
    .radm_vendor_msg            (rc_radm_vendor_msg[num_tlp]),
    .radm_rcvd_tlp_req_id       (rc_radm_msg_req_id[16*(num_tlp+1)-1:16*num_tlp]),
    .radm_unexp_cpl_err         (int_rc_radm_unexp_cpl_err[num_tlp]),
    .radm_rcvd_cpl_ca           (int_rc_radm_rcvd_cpl_ca[num_tlp]),
    .radm_rcvd_cpl_ur           (int_rc_radm_rcvd_cpl_ur[num_tlp]),
    .radm_mlf_tlp_err           (int_rc_radm_mlf_tlp_err[num_tlp]),
    .radm_rcvd_wreq_poisoned    (int_rc_radm_rcvd_wreq_poisoned[num_tlp]),
    .radm_rcvd_cpl_poisoned     (int_rc_radm_rcvd_cpl_poisoned[num_tlp]),
    .radm_rcvd_req_ur           (int_rc_radm_rcvd_req_ur[num_tlp]),
    .radm_rcvd_req_ca           (int_rc_radm_rcvd_req_ca[num_tlp]),
    .radm_hdr_log_valid         (int_rc_radm_hdr_log_valid[num_tlp]),
    .radm_hdr_log               (rc_radm_hdr_log[HW*(num_tlp+1)-1:HW*num_tlp]),
    .radm_ecrc_err              (int_rc_radm_ecrc_err[num_tlp]),
    .radm_inta_asserted         (int_radm_inta_asserted[num_tlp]),
    .radm_intb_asserted         (int_radm_intb_asserted[num_tlp]),
    .radm_intc_asserted         (int_radm_intc_asserted[num_tlp]),
    .radm_intd_asserted         (int_radm_intd_asserted[num_tlp]),
    .radm_inta_deasserted       (int_radm_inta_deasserted[num_tlp]),
    .radm_intb_deasserted       (int_radm_intb_deasserted[num_tlp]),
    .radm_intc_deasserted       (int_radm_intc_deasserted[num_tlp]),
    .radm_intd_deasserted       (int_radm_intd_deasserted[num_tlp]),
    .radm_err_cor               (int_radm_correctable_err[num_tlp]),
    .radm_err_nf                (int_radm_nonfatal_err[num_tlp]),


    .radm_err_f                 (int_radm_fatal_err[num_tlp])
);
end
endgenerate




radm_cpl_lut

#(
      .INST (INST),            /* a param used to differentiate instances */
      .CPL_ENTRY_WIDTH(CPL_ENTRY_WIDTH)  /* width of CPL LUT */
) u_radm_cpl_lut
(
     // Inputs
    .core_clk                  (core_clk),
    .radm_clk_ug               (radm_clk_ug),
    .core_rst_n                (core_rst_n),
    .rstctl_core_flush_req     (rstctl_core_flush_req),
    .cfg_pbus_dev_num          (cfg_pbus_dev_num),
    .cfg_pbus_num              (cfg_pbus_num),
    .cfg_p2p_track_cpl_to      (cfg_p2p_track_cpl_to),
    .cfg_p2p_err_rpt_ctrl      (cfg_p2p_err_rpt_ctrl),
    .cfg_cpl_timeout_disable    (cfg_cpl_timeout_disable),
    .cpl_tlp                   (cpl_tlp),
    .dwlenEq0                  (flt_dwlenEq0),
    .flt_q_tlp_type            (flt_q_tlp_type),
    .rtlh_radm_hv              (form_filt_hv), 
    .rtlh_radm_hdr             (form_filt_hdr),
    .rtlh_radm_eot             (form_filt_eot),
    .rtlh_radm_dllp_err        (form_filt_dllp_err),
    .rtlh_radm_ecrc_err        (form_filt_ecrc_err),
    .rtlh_radm_malform_tlp_err (form_filt_malform_tlp_err),
    .rtlh_radm_ant_rid         (form_filt_ant_rid),
    .cpl_status                (cpl_status),
    .xtlh_xmt_tlp_attr         (xtlh_xmt_tlp_attr[1:0]),
    .xtlh_xmt_tlp_done         (xtlh_xmt_tlp_done),
    .xtlh_np_tlp_early         (xtlh_xmt_tlp_done_early),
    .xtlh_xmt_tlp_len_inbytes  (xtlh_xmt_tlp_len_inbytes[11:0]),
    .xtlh_xmt_tlp_first_be     (xtlh_xmt_tlp_first_be),
    .xtlh_xmt_cfg_req          (xtlh_xmt_cfg_req),
    .xtlh_xmt_memrd_req        (xtlh_xmt_memrd_req),
    .xtlh_xmt_ats_req          (xtlh_xmt_ats_req),
    .xtlh_xmt_atomic_req       (xtlh_xmt_atomic_req),
    .xtlh_xmt_tlp_req_id       (xtlh_xmt_tlp_req_id[15:0]),
    .xtlh_xmt_tlp_tag          (xtlh_xmt_tlp_tag),
    .xtlh_xmt_tlp_tc           (xtlh_xmt_tlp_tc[2:0]),
    .cfg_filter_rule_mask      (cfg_filter_rule_mask),
    .current_data_rate         (current_data_rate),
    .phy_type                  (phy_type),
    .device_type               (device_type),

    // Outputs
    .vendor_msg_id_match       (vendor_msg_id_match),
    .cpl_mlf_err               (cpl_mlf_err),
    .flt_q_cpl_abort           (flt_q_cpl_abort),
    .flt_q_cpl_last            (flt_q_cpl_last),
    .cpl_ur_err                (cpl_ur_err),
    .cpl_ca_err                (cpl_ca_err),
    .unexpected_cpl_err        (unexpected_cpl_err),
    .radm_cpl_pending          (radm_cpl_pending),
    .radm_cpl_lut_valid        (radm_cpl_lut_valid),
    .radm_cpl_timeout          (radm_cpl_timeout),
    .radm_cpl_timeout_cdm      (radm_cpl_timeout_cdm),
    .radm_timeout_cpl_tc       (radm_timeout_cpl_tc[2:0]),
    .radm_timeout_cpl_attr     (radm_timeout_cpl_attr[1:0]),
    .radm_timeout_cpl_tag      (radm_timeout_cpl_tag),
    .radm_timeout_func_num     (radm_timeout_func_num),
    .radm_timeout_cpl_len      (radm_timeout_cpl_len[11:0])
    ,
    .radm_cpl_lut_pending      (radm_cpl_lut_pending),
    .radm_cpl_lut_busy         (radm_cpl_lut_busy)

);

radm_qformation

#(INST) u_radm_qformation   (
// -- inputs --
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .flt_q_dv                   (flt_q_dv),
    .flt_q_hv                   (flt_q_hv),
    .flt_q_eot                  (flt_q_eot),
    .flt_q_data                 (flt_q_data),
    .flt_q_header               (flt_q_header),
    .flt_q_dwen                 (flt_q_dwen),
    .flt_q_dllp_abort           (flt_q_dllp_abort),
    .flt_q_tlp_abort            (flt_q_tlp_abort),
    .flt_q_ecrc_err             (flt_q_ecrc_err),
    .flt_q_parerr               (flt_q_parerr),
    .flt_q_tlp_type             (flt_q_tlp_type),
    .flt_q_seg_num              (flt_q_seg_num),
    .flt_q_vc                   (flt_q_vc),
// --- outputs --
    .flt_qform_dv               (flt_qform_dv),
    .flt_qform_hv               (flt_qform_hv),
    .flt_qform_eot              (flt_qform_eot),
    .flt_qform_data             (flt_qform_data),
    .flt_qform_header           (flt_qform_header),
    .flt_qform_dwen             (flt_qform_dwen),
    .flt_qform_dllp_abort       (flt_qform_dllp_abort),
    .flt_qform_tlp_abort        (flt_qform_tlp_abort),
    .flt_qform_ecrc_err         (flt_qform_ecrc_err),
    .flt_qform_parerr           (flt_qform_parerr),
    .flt_qform_seg_num          (flt_qform_seg_num),
    .flt_qform_vc               (flt_qform_vc),
    .flt_qform_tlp_type         (flt_qform_tlp_type)
);


// radm_q Virtual Channel 0 instantiation.
radm_q_seg_buf

#(INST) u_radm_q_seg_buf (
    // ----------- Inputs -----------------
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .cfg_radm_q_mode            (cfg_radm_q_mode),
    .cfg_radm_order_rule        (cfg_radm_order_rule),
    .cfg_order_rule_ctrl        (cfg_order_rule_ctrl),
    .cfg_filter_rule_mask       (cfg_filter_rule_mask),
    .cfg_radm_strict_vc_prior   (cfg_radm_strict_vc_prior),
    .cfg_hq_depths              (cfg_hq_depths),
    .cfg_dq_depths              (cfg_dq_depths),

    //   Inputs from the Wire side.
    .flt_q_hv                   (flt_qform_hv[0]),
    .flt_q_dv                   (flt_qform_dv[0]),
    .flt_q_eot                  (flt_qform_eot[0]),
    .flt_q_header               (flt_qform_header),
    .flt_q_data                 (flt_qform_data),
    .flt_q_dwen                 (flt_qform_dwen),
    .flt_q_dllp_abort           (flt_qform_dllp_abort),
    .flt_q_tlp_abort            (flt_qform_tlp_abort),
    .flt_q_ecrc_err             (flt_qform_ecrc_err),
    .flt_q_tlp_type             (flt_qform_tlp_type),
    .flt_q_seg_num              (flt_qform_seg_num),
    .flt_q_vc                   (flt_qform_vc),
    .flt_q_parerr               (flt_qform_parerr),
    //   Inputs from the Application side.
    .trgt0_radm_halt            (trgt0_radm_halt),
    .trgt1_radm_halt            (trgt1_radm_halt),
    .trgt1_radm_pkt_halt          (trgt1_radm_pkt_halt),
    .bridge_trgt1_radm_pkt_halt   (bridge_trgt1_radm_pkt_halt),
    .trgt_lut_trgt1_radm_pkt_halt (trgt_lut_trgt1_radm_pkt_halt),

    // ---------- Outputs -----------------
    .sb_init_done               (sb_init_done),
    // Outputs to the Application side.
    //   Interface for Posted Types
    .radm_trgt0_data             (radm_trgt0_data),
    .radm_trgt0_hdr              (int_radm_trgt0_hdr_tmp),
    .radm_trgt0_dwen             (radm_trgt0_dwen),
    .radm_trgt0_dv               (segbuf_radm_trgt0_dv),
    .radm_trgt0_hv               (segbuf_radm_trgt0_hv),
    .radm_trgt0_eot              (segbuf_radm_trgt0_eot),
    .radm_trgt0_abort            (radm_trgt0_abort),
    .radm_trgt0_ecrc_err         (radm_trgt0_ecrc_err),

    .radm_trgt1_data             (radm_trgt1_data),
    .radm_trgt1_hdr              (radm_trgt1_hdr),
    .radm_trgt1_dwen             (radm_trgt1_dwen),
    .radm_trgt1_dv               (radm_trgt1_dv),
    .radm_trgt1_hv               (radm_trgt1_hv),
    .radm_trgt1_eot              (radm_trgt1_eot),
    .radm_trgt1_tlp_abort        (radm_trgt1_tlp_abort),
    .radm_trgt1_dllp_abort       (radm_trgt1_dllp_abort),
    .radm_trgt1_ecrc_err         (radm_trgt1_ecrc_err),
    .radm_trgt1_vc_num           (radm_trgt1_vc_num),

    .radm_bypass_ecrc_err        (radm_bypass_ecrc_err_i),
    .radm_bypass_tlp_abort       (radm_bypass_tlp_abort_i),
    .radm_bypass_dllp_abort      (radm_bypass_dllp_abort_i),
    .radm_bypass_hdr             (radm_bypass_hdr),
    .radm_bypass_data            (radm_bypass_data_i),
    .radm_bypass_dv              (radm_bypass_dv_i),
    .radm_bypass_hv              (radm_bypass_hv_i),
    .radm_bypass_dwen            (radm_bypass_dwen_i),
    .radm_bypass_eot             (radm_bypass_eot_i),


    .radm_rtlh_ph_ca             (radm_rtlh_ph_ca),
    .radm_rtlh_pd_ca             (radm_rtlh_pd_ca),
    .radm_rtlh_nph_ca            (radm_rtlh_nph_ca),
    .radm_rtlh_npd_ca            (radm_rtlh_npd_ca),
    .radm_rtlh_cplh_ca           (radm_rtlh_cplh_ca),
    .radm_rtlh_cpld_ca           (radm_rtlh_cpld_ca),

    .radm_q_not_empty            (radm_q_not_empty),
    .radm_qoverflow              (radm_qoverflow),
    .radm_grant_tlp_type         (radm_grant_tlp_type),
    .radm_pend_cpl_so            (radm_pend_cpl_so),
    .radm_q_cpl_not_empty        (radm_q_cpl_not_empty),
    .radm_parerr                 (radm_parerr_tmp),
    .radm_trgt0_pending          (radm_trgt0_pending),

    .hdrq_addra                  (p_hdrq_addra),
    .hdrq_addrb                  (p_hdrq_addrb),
    .hdrq_datain                 (p_hdrq_datain),
    .hdrq_dataout                (p_hdrq_dataout),
    .hdrq_ena                    (p_hdrq_ena),
    .hdrq_enb                    (p_hdrq_enb),
    .hdrq_wea                    (p_hdrq_wea),
    .hdrq_parerr                 (p_hdrq_parerr),
    .hdrq_par_chk_val            (p_hdrq_par_chk_val),
    .hdrq_parerr_out             (p_hdrq_parerr_out),
    .dataq_addra                 (p_dataq_addra),
    .dataq_addrb                 (p_dataq_addrb),
    .dataq_datain                (p_dataq_datain),
    .dataq_dataout               (p_dataq_dataout),
    .dataq_ena                   (p_dataq_ena),
    .dataq_enb                   (p_dataq_enb),
    .dataq_wea                   (p_dataq_wea),
    .dataq_parerr                (p_dataq_parerr),
    .dataq_par_chk_val           (p_dataq_par_chk_val),
    .dataq_parerr_out            (p_dataq_parerr_out),
    .radm_rtlh_crd_pending       (radm_rtlh_crd_pending)
);


`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule
