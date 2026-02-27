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
// ---    $DateTime: 2020/10/21 10:51:22 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_filter_rc.sv#9 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//  1. process and disassemble received p/np/cpl (includes msg tlps)
//  2. generate appropriate completion fields for p/np.
//  3. determine supported/unsupported requests.
//  4. provide data steering control for received tlp's (flt_q_destination)
//  5. detect tlp error conditions  and generate error signaling
//  6. provide error logging strobe/header.
//  7. Intercept decode message tlps, and signal CDM
//  9. multi-function supported
// 10. multi-VC supported.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module radm_filter_rc
   (
    // -- inputs --
    core_clk,
    core_rst_n,

    upstream_port,
    cfg_bar_is_io,
    cfg_io_match,  // timed with flt_q time domain.
    cfg_prefmem_match,  // timed with flt_q time domain.
    cfg_mem_match,  // timed with flt_q time domain.
    cfg_bar_match, // timed with flt_q time domain.
    cfg_rom_match, // timed with flt_q time domain.
    cfg_tc_struc_vc_map,
    cfg_filter_rule_mask,
    cfg_rcb_128,

    rtlh_radm_hv,
    rtlh_radm_dv,
    rtlh_radm_data,
    rtlh_radm_hdr,
    rtlh_radm_dwen,
    rtlh_radm_eot,
    rtlh_radm_dllp_err,
    rtlh_radm_malform_tlp_err,
    rtlh_radm_ecrc_err,
    rtlh_radm_parerr,
    default_target,
    cfg_p2p_err_rpt_ctrl,

    rtlh_radm_ant_addr,

    cpl_mlf_err,
    flt_q_cpl_abort,
    flt_q_cpl_last,
    cpl_ur_err,
    cpl_ca_err,
    unexpected_cpl_err,

    pm_radm_block_tlp,
    cfg_2ndbus_num,
    cfg_subbus_num,

    // outputs
    flt_cdm_addr,
    flt_q_tlp_type,
    flt_q_header,
    flt_q_data,
    flt_q_hv,
    flt_q_dv,
    flt_q_eot,
    flt_q_dwen,
    flt_q_tlp_abort,
    flt_q_dllp_abort,
    flt_q_ecrc_err,
    flt_q_parerr,
    flt_q_seg_num,
    flt_q_vc,
    radm_ecrc_err,
    radm_mlf_tlp_err,
    radm_rcvd_wreq_poisoned,
    radm_rcvd_cpl_poisoned,
    radm_rcvd_req_ur,
    radm_rcvd_req_ca,
    radm_hdr_log_valid,
    radm_hdr_log,


    radm_msg_payload,
    radm_inta_asserted,
    radm_intb_asserted,
    radm_intc_asserted,
    radm_intd_asserted,
    radm_inta_deasserted,
    radm_intb_deasserted,
    radm_intc_deasserted,
    radm_intd_deasserted,
    radm_pm_asnak,
    radm_pm_pme,
    radm_pm_turnoff,
    radm_pm_to_ack,
    radm_err_cor,
    radm_err_nf,
    radm_err_f,
    radm_unlock,
    radm_vendor_msg,
    radm_rcvd_tlp_req_id,
    radm_unexp_cpl_err,
    radm_rcvd_cpl_ca,
    radm_rcvd_cpl_ur,
    cpl_tlp,
    tlp_poisoned,
    flt_dwlenEq0,
    flt_q_rcvd_cpl_tlp_tag,


    cpl_status
);

localparam TAG_SIZE             = `CX_TAG_SIZE;

parameter INST                  = 0;                    // The uniquifying parameter for each port logic instance.
parameter FLT_NUM               = 0;                    // Filter Number. Used to identify filter when operating in parallel with another filter
parameter NB                    = `CX_NB;               // Number of symbols (bytes) per clock cycle
parameter NW                    = `CX_NW;               // Number of 32-bit dwords handled by the datapath each clock.
parameter NVC                   = `CX_NVC;              // Number of virtual channels
parameter NF                    = 1;                    // Number of functions
localparam PF_WD                = `CX_NFUNC_WD;         // Number of bits needed to address the physical functions
parameter DW                    = (32*NW);              // Width of datapath in bits.
parameter HW                    = `FLT_Q_HDR_WIDTH;     // Header width
parameter HEW                   = 32;                   // Header element width
parameter TP                    = `TP;                  // Clock to Q delay (simulator insurance)
parameter P_TYPE                = 0;
parameter NP_TYPE               = 1;
parameter CPL_TYPE              = 2;
parameter N_FLT_MASK            = `CX_N_FLT_MASK;

parameter NDQ                   = `CX_NDQ;  // Number of Data Queues
parameter RASDP_NDQ             = (NDQ==4)? 1: NDQ;

parameter PAR_CALC_WIDTH        = `DATA_BUS_PAR_CALC_WIDTH;
parameter DATA_PAR_WD           = `TRGT_DATA_PROT_WD;
parameter ADDR_PAR_WD           = `CX_RAS_PCIE_HDR_PROT_WD;

parameter ADDR_TRANSLATION_SUPPORT =  0 ;

// CPL parameters
parameter FLT_Q_ADDR_WIDTH      = `FLT_Q_ADDR_WIDTH;
parameter FLT_OUT_PROT_WD       = `CX_FLT_OUT_PROT_WD;

// Segbuf parameters
parameter SEG_WIDTH             = `CX_SEG_WIDTH;

parameter MASTER_BUS_ADDR_WIDTH = `MASTER_BUS_ADDR_WIDTH;

parameter CX_ELBI_NW = `CX_LBC_NW;   // number of DWs which can be accepted on ELBI; corresponds to max allowable Length field to which the ELBI is limited.

localparam ATTR_WD = `FLT_Q_ATTR_WIDTH;
localparam GATING_CTRL_PATH_WD = 3*NVC; // [NVC-1:0]  l_flt_q_hv, l_flt_q_dv, l_flt_q_eot


input                   core_clk;                       // Core clock
input                   core_rst_n;                     // Core system reset
input                   upstream_port;
input   [(NF*6)-1:0]    cfg_bar_is_io;                  // indication that tlp is within MEM BAR, which is IO space
input   [NF-1:0]        cfg_io_match;                   // TIED low for EP
input   [NF-1:0]        cfg_rom_match;                  // indication that tlp is within a ROM BAR
input   [(NF*6)-1:0]    cfg_bar_match;                  // indication that tlp is within a MEM BAR
input   [NF-1:0]        cfg_mem_match;
input   [NF-1:0]        cfg_prefmem_match;
input   [23:0]          cfg_tc_struc_vc_map;            // TC to VC Structure mapping
input   [N_FLT_MASK-1:0]cfg_filter_rule_mask;           // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
input                   cfg_rcb_128;
input   [NF-1:0]        pm_radm_block_tlp;

input                   rtlh_radm_hv;                   // Header from TLP alignment block is valid (Start of packet)
input   [127+ADDR_PAR_WD:0]  rtlh_radm_hdr;             // 127-bit packet header
input                   rtlh_radm_dv;                   // Data from TLP alignment block is valid
input   [DW+DATA_PAR_WD-1:0] rtlh_radm_data;            // 128-bit packet data
input   [NW-1:0]        rtlh_radm_dwen;                 // DWord Enable for Data Interface.
input                   rtlh_radm_eot;                  // Indicate end of packet
input                   rtlh_radm_dllp_err;             // Recall packet (Malformed TLP, etc.)
input                   rtlh_radm_ecrc_err;             // Recall packet (Malformed TLP, etc.)
input                   rtlh_radm_malform_tlp_err;      // Recall packet (Malformed TLP, etc.)
input                   rtlh_radm_parerr;


input   [63:0]          rtlh_radm_ant_addr;             // anticipated address (1 clock earlier)

input                   default_target;                 // determine where UR TLPs are directed.
input                   cfg_p2p_err_rpt_ctrl;           // P2P_ERR_RPT_CTRL
input                   cpl_mlf_err;
input                   flt_q_cpl_abort;
input                   flt_q_cpl_last;
input                   cpl_ur_err;
input                   cpl_ca_err;
input                   unexpected_cpl_err;


input  [(8*NF)-1:0]     cfg_2ndbus_num;                 // configured secondary bus number
input  [(8*NF)-1:0]     cfg_subbus_num;                 // configured subordinate bus number

//--------------------- outputs -----------------// Clock alignment



output  [63:0]          flt_cdm_addr;            // rtlh_flt                    //-- 64 bit tlp address sent to CDM for BAR matching
output  [DW+DATA_PAR_WD-1:0] flt_q_data;         // flt_q + CX_FLT_Q_REGOUT     //-- tlp data sent to queue
output                  flt_q_dllp_abort;        // flt_q + CX_FLT_Q_REGOUT     //-- Recall packet (Malformed TLP, etc.)
output  [NVC-1:0]       flt_q_dv;                // flt_q + CX_FLT_Q_REGOUT     //-- 1 when flt_q_data   is valid
output  [NW-1:0]        flt_q_dwen;              // flt_q + CX_FLT_Q_REGOUT     //-- DWord Enable for Data Interface.
output                  flt_q_ecrc_err;          // flt_q + CX_FLT_Q_REGOUT     //--  -> radm_q
output  [NVC-1:0]       flt_q_eot;               // flt_q + CX_FLT_Q_REGOUT     //-- Indicate end of packet
output  [HW+FLT_OUT_PROT_WD-1:0] flt_q_header;   // flt_q + CX_FLT_Q_REGOUT     //-- tlp compressed header sent to queue
output  [NVC-1:0]       flt_q_hv;                // flt_q + CX_FLT_Q_REGOUT     //-- 1 when flt_q_header is valid
output                  flt_q_tlp_abort;         // flt_q + CX_FLT_Q_REGOUT     //-- Recall packet (Malformed TLP, etc.)
output  [2:0]           flt_q_tlp_type;          // flt_q + CX_FLT_Q_REGOUT     //-- one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ flt_q_hv
output  [SEG_WIDTH-1:0] flt_q_seg_num;           // flt_q + CX_FLT_Q_REGOUT     //-- segment number
output  [2:0]           flt_q_vc;                // flt_q + CX_FLT_Q_REGOUT     //-- VC # of the current packet
output  [NF-1:0]        radm_rcvd_cpl_ca;        // flt_q + CX_ERROR_LOG_REGOUT //-- CPL -> cdm Received CPL completion abort
output  [NF-1:0]        radm_rcvd_cpl_ur;        // flt_q + CX_ERROR_LOG_REGOUT //-- CPL -> cdm Received CPL Unsupported request error
output  [NF-1:0]        radm_ecrc_err;           // flt_q + CX_ERROR_LOG_REGOUT //-- Received ECRC error (in absence of dllp error)
output                  flt_q_parerr;
output  [127:0]         radm_hdr_log;            // flt_q + CX_ERROR_LOG_REGOUT //-- tlp header for logging errors
output  [NF-1:0]        radm_hdr_log_valid;      // flt_q + CX_ERROR_LOG_REGOUT //-- strobe for radm_hdr_log
output  [NF-1:0]        radm_mlf_tlp_err;        // flt_q + CX_ERROR_LOG_REGOUT //-- Received malformed error
output  [63:0]          radm_msg_payload;        // flt_q                       //-- Received msg data associated with slot limit
output                  radm_pm_asnak;           // flt_q                       //-- Received PM_AS_NAK
output                  radm_pm_pme;             // flt_q                       //-- Received PM_PME MSG
output                  radm_pm_to_ack;          // flt_q                       //-- Received PM_TO_ACK
output                  radm_pm_turnoff;         // constant                    //-- Received PM_TURNOFF
output  [NF-1:0]        radm_rcvd_req_ca;        // flt_q + CX_ERROR_LOG_REGOUT //-- Received completion abort (EP's CA generated for dwlen>1 )
output  [NF-1:0]        radm_rcvd_cpl_poisoned;  // flt_q + CX_ERROR_LOG_REGOUT //-- Received posted poisoned cpl tlp request
output  [15:0]          radm_rcvd_tlp_req_id;    // flt_q                       //-- Received Requester ID
output  [NF-1:0]        radm_rcvd_req_ur;        // flt_q + CX_ERROR_LOG_REGOUT //-- Received unsupported Request
output  [NF-1:0]        radm_rcvd_wreq_poisoned; // flt_q + CX_ERROR_LOG_REGOUT //-- Received posted poisoned wr request
output  [NF-1:0]        radm_unexp_cpl_err;      // flt_q + CX_ERROR_LOG_REGOUT //-- CPL -> cdm    timeout CPL tc
output                  radm_vendor_msg;         // flt_q                       //-- N/A for EP
output                  radm_err_cor;            // flt_q                       //--
output                  radm_err_f;              // flt_q                       //--
output                  radm_err_nf;             // flt_q                       //--
output                  radm_inta_asserted;      // flt_q                       //--
output                  radm_inta_deasserted;    // flt_q                       //--
output                  radm_intb_asserted;      // flt_q                       //--
output                  radm_intb_deasserted;    // flt_q                       //--
output                  radm_intc_asserted;      // flt_q                       //--
output                  radm_intc_deasserted;    // flt_q                       //--
output                  radm_intd_asserted;      // flt_q                       //--
output                  radm_intd_deasserted;    // flt_q                       //--
output                  radm_unlock;             // constant                    //--
output                  cpl_tlp;                 // rtlh_flt                    //--
output                  tlp_poisoned;            // rtlh_flt                    //--
output                  flt_dwlenEq0;            // rtlh_flt                    //--
output  [TAG_SIZE-1:0]  flt_q_rcvd_cpl_tlp_tag;  // rtlh_flt                    //--
output  [2:0]           cpl_status;              // rtlh_flt                    //--


wire    [HEW-1:0]       hdr_dw1;                 // sync with rtlh time domain
wire    [HEW-1:0]       hdr_dw2;
wire    [HEW-1:0]       hdr_dw3;
wire    [HEW-1:0]       hdr_dw4;
wire                    pcie_valid_tc;
wire                    pcie_format;
wire    [2:0]           tlp_type;
wire    [4:0]           hdr_type;
wire    [1:0]           fmt;
wire    [3:0]           tlpmsg;
wire                    tlp_is_msg;
wire                    int_mlf_msg;
wire                    flt_drop_msg;

wire                    p_tlp;
wire                    cpl_tlp;
wire                    np_tlp;
wire                    flt_q_invalid_tlp;
wire                    flt_q_pcie_valid_tc;
wire                    flt_q_pcie_format;
wire    [9:0]           dw_len;
wire                    tlp_poisoned;
wire    [ATTR_WD-1:0]   attr;
wire                    tlp_w_pyld;
wire    [2:0]           tc;
wire    [3:0]           first_be;
wire    [3:0]           last_be;

wire                    msg_is_vendor_msg0;
wire                    msg_is_vendor_msg1;
wire                    dwlenEq1;
wire    [7:0]           msg_code;
wire                    cpl_bcm;
wire    [2:0]           cpl_status;
wire    [11:0]          rcvd_tlp_byte_cnt;
wire    [TAG_SIZE-1:0]  rcvd_cpl_tlp_tag;
wire    [6:0]           rcvd_tlp_low_addr;
reg                     flt_q_rtlh_abort;
reg                     flt_q_malf_err;
reg                     flt_q_cpl_mlf_err;
reg                     flt_q_msg_mlf_err;
wire                    radm_vendor_msg;
reg     [HEW-1:0]       flt_q_hdr_dw1;                  // sync with q time domain
reg     [HEW-1:0]       flt_q_hdr_dw2;
reg     [HEW-1:0]       flt_q_hdr_dw3;
reg     [HEW-1:0]       flt_q_hdr_dw4;
reg                     flt_q_dwlenEq1;
reg                     flt_q_io_req_in_range;
reg                     flt_q_outside_mem_range;
reg                     flt_q_outside_prefmem_range;
// decouple the internal header wiring from the use of RAS. If RAS is used then chk_rtlh_radm_hdr is the output of
// bus_protect_chk module. Without RAS it's just a feedthrough of rtlh_radm_hdr
wire    [127+ADDR_PAR_WD:0]  chk_rtlh_radm_hdr;           // 128-bit packet header

reg     [DW+DATA_PAR_WD-1:0] l_flt_q_data;                // flt_q  //tlp data sent to queue
wire     [DW+DATA_PAR_WD-1:0] chk_l_flt_q_data;

reg                     l_flt_q_dllp_abort;               // flt_q  //Recall packet (Malformed TLP, etc.)
wire    [NVC-1:0]       l_flt_q_dv;                       // flt_q  //1 when flt_q_data   is valid
reg     [NW-1:0]        l_flt_q_dwen;                     // flt_q  //DWord Enable for Data Interface.
reg                     l_flt_q_ecrc_err;                 // flt_q  // -> radm_q
wire    [NVC-1:0]       l_flt_q_eot;                      // flt_q  //Indicate end of packet
wire    [HW+FLT_OUT_PROT_WD-1:0] l_flt_q_header;              // flt_q  //tlp compressed header sent to queue
wire    [HW+FLT_OUT_PROT_WD-1:0] l_flt_q_header_d;            // flt_q  //tlp compressed header sent to queue
wire    [HW+FLT_OUT_PROT_WD-1:0] chk_l_flt_q_header_d;    // flt_q  //tlp compressed header sent to queue, output of bus_protect_chk if RAS is enabled
wire    [NVC-1:0]       l_flt_q_hv;                       // flt_q  //1 when l_flt_q_header is valid
wire                    l_flt_q_tlp_abort;                // flt_q  //Recall packet (Malformed TLP, etc.)
wire                    int_flt_q_tlp_abort;              // flt_q - delayed version of l_flt_q_tlp_abort
reg     [2:0]           l_flt_q_tlp_type;                 // flt_q  //one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ l_flt_q_hv
reg                     l_flt_q_parerr;
wire                    int_flt_q_parerr;                 // error indication at the output of the delay module
reg     [SEG_WIDTH-1:0] l_flt_q_seg_num;                  // flt_q  //segment number
reg     [2:0]           l_flt_q_vc;                       // flt_q  //VC # of the current packet

reg                     l_set_radm_rcvd_cpl_ca;
reg                     l_set_radm_rcvd_cpl_ur;
reg                     l_set_radm_ecrc_err;
reg                     l_set_radm_hdr_log_valid;
reg                     l_set_radm_mlf_tlp_err;
reg                     l_set_radm_rcvd_req_ca;
reg                     l_set_radm_rcvd_cpl_poisoned;
reg                     l_set_radm_rcvd_req_ur;
reg                     l_set_radm_rcvd_wreq_poisoned;
reg                     l_set_radm_unexp_cpl_err;
wire    [127:0]         l_radm_hdr_log;
wire                    set_radm_rcvd_cpl_ca;
wire                    set_radm_rcvd_cpl_ur;
wire                    set_radm_ecrc_err;
wire                    set_radm_hdr_log_valid;
wire                    set_radm_mlf_tlp_err;
wire                    set_radm_rcvd_req_ca;
wire                    set_radm_rcvd_cpl_poisoned;
wire                    set_radm_rcvd_req_ur;
wire                    set_radm_rcvd_wreq_poisoned;
wire                    set_radm_unexp_cpl_err;
wire    [NF-1:0]        radm_rcvd_cpl_ca;
wire    [NF-1:0]        radm_rcvd_cpl_ur;
wire    [NF-1:0]        radm_ecrc_err;
wire    [NF-1:0]        radm_hdr_log_valid;
wire    [NF-1:0]        radm_mlf_tlp_err;
wire    [NF-1:0]        radm_rcvd_req_ca;
wire    [NF-1:0]        radm_rcvd_cpl_poisoned;
wire    [NF-1:0]        radm_rcvd_req_ur;
wire    [NF-1:0]        radm_rcvd_wreq_poisoned;
wire    [NF-1:0]        radm_unexp_cpl_err;

wire                    flt_q_mem_req_range;
wire                    flt_q_iowr_xep_req;
wire                    flt_q_memwr_xep_req;

reg     [1:0]           int_flt_q_destination;
reg     [1:0]           latchd_flt_q_destination;
wire    [1:0]           flt_q_destination;
wire    [ATTR_WD-1:0]   flt_q_attr;
wire    [2:0]           flt_q_tc;
wire    [TAG_SIZE-1:0]  flt_q_TAG;
wire    [15:0]          flt_q_REQID;
wire    [4:0]           flt_q_type;
wire    [1:0]           flt_q_fmt;
wire    [15:0]          flt_q_cplid;
wire                    flt_q_np_rd;
wire                    flt_q_iord_req;
wire                    flt_q_iowr_req;
wire                    flt_q_locked_rd;
wire                    flt_q_memrd_req;
wire                    flt_q_atomic_fetchadd;
wire                    flt_q_atomic_swap;
wire                    flt_q_atomic_cas;
wire                    flt_q_memwr_req;
wire                    flt_q_def_memwr_req;
wire                    flt_q_cfg0rd_req;
wire                    flt_q_cfg0wr_req;
wire                    flt_q_cfg1rd_req;
wire                    flt_q_cfg1wr_req;
wire                    flt_q_cfg_req;
wire                    flt_q_atomic_op;
wire                    flt_q_cpl_w_lock;
wire                    flt_q_cpl_wo_lock;
wire                    flt_q_func_mismatch;
wire                    flt_q_td;
wire                    flt_q_poisoned;
wire                    flt_q_poisoned_err;
wire                    flt_q_addr64;
wire    [3:0]           flt_q_first_be;
wire    [3:0]           flt_q_last_be;
wire    [7:0]           flt_q_msg_code;
wire    [7:0]           flt_q_bus_num;
wire    [4:0]           flt_q_dev_num;
wire    [PF_WD-1:0]     flt_q_cfg_func_num;
reg     [PF_WD-1:0]     flt_q_func_num;
wire    [PF_WD-1:0]     flt_q_func_num_d;
wire    [3:0]           flt_q_ext_reg_num;
wire    [5:0]           flt_q_reg_num;
wire    [63:0]          flt_q_addr;
wire    [7:0]           flt_q_addr_byte0;
wire    [7:0]           flt_q_addr_byte1;
wire    [7:0]           flt_q_addr_byte2;
wire    [7:0]           flt_q_addr_byte3;
wire    [7:0]           flt_q_addr_byte4;
wire    [7:0]           flt_q_addr_byte5;
wire    [7:0]           flt_q_addr_byte6;
wire    [7:0]           flt_q_addr_byte7;
wire    [63:0]          extract_addr;
wire    [6:0]           flt_q_lower_addr;
wire    [9:0]           flt_q_dw_len;
reg                     flt_q_handle_flush;
reg     [NVC-1:0]       flt_q_select;
reg     [1:0]           flt_q_byte_addr;
wire                    flt_q_valid_np;
wire                    flt_q_valid_p;
wire                    flt_q_valid_ur_np;
wire                    flt_q_valid_ur_p;
wire                    flt_q_valid_ur_np_wo_poisoned;
wire                    flt_q_valid_ur_p_wo_poisoned;
wire                    flt_q_valid_ca_np;
wire                    flt_q_valid_ca_p;
reg     [2:0]           flt_q_valid_type;
wire    [11:0]          flt_q_byte_cnt;
wire    [2:0]           flt_q_cpl_status;
wire                    flt_q_tlp_is_msg;
reg                     flt_q_invalid_msg;
wire                    flt_q_vendor_msg;
reg                     flt_q_vendor_msg0;
reg                     flt_q_vendor_msg1;
reg                     flt_q_invalidate_msg;
wire    [3:0]           flt_q_tlpmsg;
wire                    flt_q_cpl_bcm;
reg     [HW-1:0]        flt_q_compressed_hdr;
wire    [2:0]           flt_q_rcvd_cpl_status;
wire                    flt_q_reserved_status;
wire    [15:0]          flt_q_cpl_reqid;
wire    [11:0]          flt_q_rcvd_tlp_byte_cnt;
wire    [6:0]           flt_q_rcvd_tlp_low_addr;
wire                    flt_q_status_sc;
wire                    flt_q_status_ur;
wire                    flt_q_status_ca;
wire                    flt_q_status_crs;
wire                    flt_q_th;
reg                     radm_pm_asnak;
reg                     radm_pm_pme;
wire                    radm_pm_turnoff;
assign radm_pm_turnoff = 1'b0; // RC should not receive turnoff
reg                     radm_pm_to_ack;
reg                     radm_inta_asserted;
reg                     radm_intb_asserted;
reg                     radm_intc_asserted;
reg                     radm_intd_asserted;
reg                     radm_inta_deasserted;
reg                     radm_intb_deasserted;
reg                     radm_intc_deasserted;
reg                     radm_intd_deasserted;
reg                     radm_err_cor;
reg                     radm_err_nf;
reg                     radm_err_f;
wire                    radm_unlock;
assign radm_unlock = 1'b0;  // RC should not receive unlock

reg                     rtlh_dllp_err_d  ;
reg                     flt_q_unqual_dv;
reg                     flt_q_unqual_hv;
reg                     flt_q_unqual_eot;

wire    [(8*NF)-1:0]    cfg_2ndbus_num;                 // configured secondary bus number
wire    [(8*NF)-1:0]    cfg_subbus_num;                 // configured subordinate bus number

// CPL declarations


wire                    flt_q_valid_ur_wo_poisn_err;
wire                    flt_q_valid_ur_err;
wire                    flt_q_valid_ca_err;
reg                     flt_q_cpl_rcvd_ur;
reg                     flt_q_cpl_rcvd_ca;
reg                     flt_q_unexp_cpl_err;
wire [PF_WD-1:0]        NF_wire;
assign NF_wire = NF-1; // this intermediate assignment, to allow slicing of NF_wire

wire                    flt_q_poisoned_discard;
wire                    flt_q_locked_rd_tlp;
wire                    flt_q_ecrc_discard;
wire                    flt_q_mem_req_in_range;
wire                    flt_q_rom_req_in_range;
wire    [2:0]           flt_q_in_membar_range;



wire [7:0]              tmp_mlf_err_ptr;
reg  [7:0]              flt_q_rtlh_abort_ptr;
wire [7:0]              rtlh_radm_malform_tlp_err_ptr = 8'h00;
//
// [ ----------------  sync with rtlh time domain  -----------------------]
//
// aux wire to indicate a protection error has been detected at the output of the delay module
// if the delay is 0 then there is no check and hence no error
wire l_flt_q_header_d_prot_err; 

  assign chk_rtlh_radm_hdr = rtlh_radm_hdr;
  assign flt_q_parerr = int_flt_q_parerr;

assign  hdr_dw1                 = chk_rtlh_radm_hdr[31:0];
assign  hdr_dw2                 = chk_rtlh_radm_hdr[63:32];
assign  hdr_dw3                 = chk_rtlh_radm_hdr[95:64];
assign  hdr_dw4                 = chk_rtlh_radm_hdr[127:96];

assign  hdr_type                = hdr_dw1[4:0];
assign  fmt                     = hdr_dw1[6:5];
assign  tlpmsg                  = hdr_dw1[6:3];
assign  attr                    = hdr_dw1[21:20];
assign  tlp_w_pyld              = hdr_dw1[6]; // Supported PCIe format only

assign  tlp_is_msg              = (((tlpmsg          == `MSG_4) || (tlpmsg         == `MSGD_4)) && pcie_format);
assign  p_tlp                   = ( ( (({fmt,hdr_type} == `MWR32) || ({fmt,hdr_type} == `MWR64)) && pcie_format) || tlp_is_msg)
                                ;
assign  cpl_tlp                 = (({fmt,hdr_type} == `CPLLK) || ({fmt,hdr_type} == `CPLDLK) ||
                                   ({fmt,hdr_type} == `CPL)   || ({fmt,hdr_type} == `CPLD)) && pcie_format;
assign  np_tlp                  = (({fmt,hdr_type} == `IORD) | ({fmt,hdr_type} == `IOWR) | ({fmt,hdr_type} == `CFGRD0) | ({fmt,hdr_type} == `CFGWR0)
                                  |({fmt,hdr_type} == `CFGRD1) | ({fmt,hdr_type} == `CFGWR1) | ({fmt,hdr_type} == `MRD32) | ({fmt,hdr_type} == `MRD64)
                                  |({fmt,hdr_type} == `MRDLK32) | ({fmt,hdr_type} == `MRDLK64)) && pcie_format;

assign  tlp_type [P_TYPE]       = p_tlp;               //sync with rtlh time domain
assign  tlp_type [NP_TYPE]      = !p_tlp & !cpl_tlp;
assign  tlp_type [CPL_TYPE]     = cpl_tlp;             //sync with rtlh time domain

// segbuf calcs
wire    [1:0]           seg_type;                       // 2 bit type for segment calculations
wire    [2:0]           seg_vc;                         // 3 bit vc number for segment calculations
wire    [SEG_WIDTH-1:0] seg_num;                        // segment number

// for segment buffer segment calculation
assign  seg_type                = p_tlp ? P_TYPE
                                            : cpl_tlp ? CPL_TYPE
                                                      : NP_TYPE;
assign  seg_vc                  = vc_from_tc(cfg_tc_struc_vc_map, tc);
assign  seg_num                 = Get_seg_num ( seg_vc, seg_type );

assign  pcie_valid_tc           = 1'b1;
assign  pcie_format             = 1'b1;

assign  flt_cdm_addr            = rtlh_radm_ant_addr;

assign  dw_len                  = {hdr_dw1[17:16], hdr_dw1[31:24]}; // Supported PCIe format only
assign  tlp_poisoned            = hdr_dw1[22] & pcie_format;
assign  tc                      = hdr_dw1[14:12];


assign  msg_is_vendor_msg0      = ((hdr_dw2[31:24] == `VENDOR_TYPE0) && ((hdr_type[2:0] == 3'b000) || (hdr_type[2:0] == 3'b010) || (hdr_type[2:0] == 3'b011) || (hdr_type[2:0] == 3'b100)) && ((tlpmsg == `MSG_4) || (tlpmsg == `MSGD_4)) && !int_mlf_msg && pcie_format);
assign  msg_is_vendor_msg1      = ((hdr_dw2[31:24] == `VENDOR_TYPE1) && ((hdr_type[2:0] == 3'b000) || (hdr_type[2:0] == 3'b010) || (hdr_type[2:0] == 3'b011) || (hdr_type[2:0] == 3'b100)) && ((tlpmsg == `MSG_4) || (tlpmsg == `MSGD_4)) && !int_mlf_msg && pcie_format);



assign  first_be                = hdr_dw2[27:24];
assign  last_be                 = hdr_dw2[31:28];
assign  dwlenEq1                = (dw_len[0] & (!(|dw_len[9:1])));    // dw_len == 10'b01
assign  flt_dwlenEq0            = !(|dw_len);                         // dw_len == 10'b0

assign  msg_code                = ( hdr_dw2[31:24]);
//assign q_REQID             = {hdr_dw2[7:0],hdr_dw2[15:8]};

assign  cpl_status              = hdr_dw2[23:21];
assign  rcvd_tlp_byte_cnt       = {hdr_dw2[19:16], hdr_dw2[31:24]};
assign  rcvd_cpl_tlp_tag        =  hdr_dw3[23:16];
assign  rcvd_tlp_low_addr       = hdr_dw3[30:24];

assign  cpl_bcm                 = hdr_dw2[20];





always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        l_flt_q_seg_num           <= #TP 0;
    else
        l_flt_q_seg_num           <= #TP seg_num;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        l_flt_q_vc                <= #TP 0;
    else
        l_flt_q_vc                <= #TP seg_vc;

always @(posedge core_clk or negedge core_rst_n)
begin:  LATCH_TLP_TYPE_PROCESS
    if(!core_rst_n)
    begin
        l_flt_q_tlp_type          <= #TP 3'b000;          // delayed to be sync with q time domain
    end
    else
    begin
        l_flt_q_tlp_type[P_TYPE]  <= #TP tlp_type [P_TYPE];
        l_flt_q_tlp_type[NP_TYPE] <= #TP tlp_type [NP_TYPE];
        l_flt_q_tlp_type[CPL_TYPE]<= #TP tlp_type [CPL_TYPE];
    end
end

//
// [ ----------------  sync with q time domain  -----------------------]
//
assign  l_radm_hdr_log          = {flt_q_hdr_dw4,flt_q_hdr_dw3,flt_q_hdr_dw2,flt_q_hdr_dw1};

assign  flt_q_attr              = flt_q_hdr_dw1[21:20];
assign  flt_q_tc                = flt_q_hdr_dw1[14:12];
assign  flt_q_TAG               =  flt_q_hdr_dw2[23:16];
assign  flt_q_REQID             = (flt_q_cpl_w_lock | flt_q_cpl_wo_lock) ? {flt_q_hdr_dw3[7:0],flt_q_hdr_dw3[15:8]} : {flt_q_hdr_dw2[7:0],flt_q_hdr_dw2[15:8]};
assign  flt_q_dw_len            = {flt_q_hdr_dw1[17:16], flt_q_hdr_dw1[31:24]};
assign  flt_q_type              = flt_q_hdr_dw1[4:0];
assign  flt_q_fmt               = flt_q_hdr_dw1[6:5];
assign  flt_q_cplid             = {flt_q_hdr_dw2[7:0],flt_q_hdr_dw2[15:8]};

assign  flt_q_tlpmsg            = flt_q_hdr_dw1[6:3];
assign  flt_q_tlp_is_msg        = (((flt_q_tlpmsg == `MSG_4) || (flt_q_tlpmsg == `MSGD_4)) && flt_q_pcie_format);

assign  flt_q_iord_req          = ( {flt_q_fmt, flt_q_type} == `IORD) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_iowr_req          = ( {flt_q_fmt, flt_q_type} == `IOWR) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_locked_rd         = (({flt_q_fmt, flt_q_type} == `MRDLK32) || ({flt_q_fmt, flt_q_type} == `MRDLK64)) && flt_q_pcie_format;
assign  flt_q_memrd_req         = (({flt_q_fmt, flt_q_type} == `MRD32)   || ({flt_q_fmt, flt_q_type} == `MRD64  )) && flt_q_pcie_format;
assign  flt_q_memwr_req         = (({flt_q_fmt, flt_q_type} == `MWR32)   || ({flt_q_fmt, flt_q_type} == `MWR64  )) && flt_q_pcie_format;
assign  flt_q_def_memwr_req     = 0;
assign  flt_q_atomic_fetchadd   = (({flt_q_fmt, flt_q_type} == `FETCHADD32)   || ({flt_q_fmt, flt_q_type} == `FETCHADD64  )) && flt_q_pcie_format;
assign  flt_q_atomic_swap       = (({flt_q_fmt, flt_q_type} == `SWAP32)       || ({flt_q_fmt, flt_q_type} == `SWAP64  )) && flt_q_pcie_format;
assign  flt_q_atomic_cas        = (({flt_q_fmt, flt_q_type} == `CAS32)        || ({flt_q_fmt, flt_q_type} == `CAS64  )) && flt_q_pcie_format;
assign  flt_q_cfg0rd_req        = ( {flt_q_fmt, flt_q_type} == `CFGRD0) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_cfg0wr_req        = ( {flt_q_fmt, flt_q_type} == `CFGWR0) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_cfg1rd_req        = ( {flt_q_fmt, flt_q_type} == `CFGRD1) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_cfg1wr_req        = ( {flt_q_fmt, flt_q_type} == `CFGWR1) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_cfg_req           = (flt_q_cfg0rd_req || flt_q_cfg0wr_req  || flt_q_cfg1rd_req || flt_q_cfg1wr_req);
assign  flt_q_atomic_op         = (flt_q_atomic_fetchadd || flt_q_atomic_swap || flt_q_atomic_cas);

assign  flt_q_cpl_w_lock        = (({flt_q_fmt,flt_q_type}  == `CPLLK)   ||  ({flt_q_fmt,flt_q_type} == `CPLDLK)) && flt_q_pcie_format;
assign  flt_q_cpl_wo_lock       = (({flt_q_fmt,flt_q_type}  == `CPL)     ||  ({flt_q_fmt,flt_q_type} == `CPLD)) && flt_q_pcie_format;

assign  flt_q_invalid_tlp       = !flt_q_iord_req & !flt_q_iowr_req & !flt_q_locked_rd & !flt_q_memrd_req
                                     & !flt_q_memwr_req & !flt_q_def_memwr_req & !flt_q_cfg0rd_req & !flt_q_cfg0wr_req & !flt_q_tlp_is_msg
                                     & !flt_q_cfg1rd_req & !flt_q_cfg1wr_req & !flt_q_cpl_w_lock & !flt_q_cpl_wo_lock
                                     & !flt_q_atomic_op;



assign  flt_q_np_rd             = ( flt_q_iord_req || flt_q_cfg0rd_req || flt_q_cfg1rd_req || flt_q_memrd_req || flt_q_locked_rd || flt_q_atomic_op);
assign  flt_q_func_mismatch     = (flt_q_cfg_func_num  > NF_wire);
assign  flt_q_td                = 
                                  cfg_filter_rule_mask[`CX_FLT_UNMASK_TD] ? flt_q_hdr_dw1[23] : 1'b0;
assign  flt_q_poisoned          = flt_q_hdr_dw1[22];
assign  flt_q_poisoned_err      = flt_q_poisoned && flt_q_pcie_format;
assign  flt_q_addr64            = flt_q_hdr_dw1[5] && flt_q_pcie_format;
assign  flt_q_first_be          = flt_q_hdr_dw2[27:24];
assign  flt_q_last_be           = flt_q_hdr_dw2[31:28];
assign  flt_q_msg_code          = flt_q_hdr_dw2[31:24];                         // for message transactions only
assign  flt_q_bus_num           = flt_q_hdr_dw3[7:0];                           // for cfg transaction only
assign  flt_q_dev_num           = flt_q_hdr_dw3[15:11];                         // for cfg transaction only
assign  flt_q_cfg_func_num      = flt_q_hdr_dw3[(PF_WD-1)+8:8];                 // for cfg transaction only
assign  flt_q_ext_reg_num       = flt_q_hdr_dw3[19:16];                         // for cfg transaction only
assign  flt_q_reg_num           = flt_q_hdr_dw3[31:26];                         // for cfg transaction only
assign  flt_q_rcvd_cpl_status   = flt_q_hdr_dw2[23:21];                         // for cpl receptions only

assign  flt_q_status_sc         = (flt_q_rcvd_cpl_status == `SU_CPL_STATUS);    // Successful  Completion
assign  flt_q_status_ca         = (flt_q_rcvd_cpl_status == `CA_CPL_STATUS);    // Completion  Abort
assign  flt_q_status_crs        = (flt_q_rcvd_cpl_status == `CRS_CPL_STATUS);   // Request Retry Status
assign  flt_q_status_ur         = !(flt_q_status_sc || flt_q_status_ca || 
    flt_q_status_crs);      // 2.3.2 Completions with a Reserved Completion
                            // Status value are treated as if the Completion
                            // Status was Unsupported Request (UR)
assign  flt_q_reserved_status   = !(flt_q_status_sc  || flt_q_rcvd_cpl_status == `UR_CPL_STATUS  || flt_q_status_ca  || flt_q_status_crs);

assign  flt_q_cpl_reqid         = {flt_q_hdr_dw3[7:0], flt_q_hdr_dw3[15:8]};
assign  flt_q_cpl_bcm           = flt_q_hdr_dw2[20];                            // for cpl receptions only
assign  flt_q_rcvd_tlp_byte_cnt = {flt_q_hdr_dw2[19:16], flt_q_hdr_dw2[31:24]};
assign  flt_q_rcvd_cpl_tlp_tag  =  flt_q_hdr_dw3[23:16];
assign  flt_q_rcvd_tlp_low_addr = flt_q_hdr_dw3[30:24];

assign  flt_q_addr_byte7        = (flt_q_addr64) ? flt_q_hdr_dw3[7:0]   : 8'h00;
assign  flt_q_addr_byte6        = (flt_q_addr64) ? flt_q_hdr_dw3[15:8]  : 8'h00;
assign  flt_q_addr_byte5        = (flt_q_addr64) ? flt_q_hdr_dw3[23:16] : 8'h00;
assign  flt_q_addr_byte4        = (flt_q_addr64) ? flt_q_hdr_dw3[31:24] : 8'h00;
assign  flt_q_addr_byte3        = (flt_q_addr64) ? flt_q_hdr_dw4[7:0]   : flt_q_hdr_dw3[7:0];
assign  flt_q_addr_byte2        = (flt_q_addr64) ? flt_q_hdr_dw4[15:8]  : flt_q_hdr_dw3[15:8];
assign  flt_q_addr_byte1        = (flt_q_addr64) ? flt_q_hdr_dw4[23:16] : flt_q_hdr_dw3[23:16];
assign  flt_q_addr_byte0        = (flt_q_addr64) ? flt_q_hdr_dw4[31:24] : flt_q_hdr_dw3[31:24];
assign  extract_addr            = {flt_q_addr_byte7, flt_q_addr_byte6, flt_q_addr_byte5, flt_q_addr_byte4,
                                   flt_q_addr_byte3, flt_q_addr_byte2, flt_q_addr_byte1, flt_q_addr_byte0};

assign  flt_q_lower_addr        = flt_q_memrd_req ? {flt_q_hdr_dw3[30:26], flt_q_byte_addr} : 7'b0;
assign  flt_q_byte_cnt          = (flt_q_memrd_req | flt_q_atomic_fetchadd | flt_q_atomic_swap) ? {flt_q_dw_len, 2'b0}      :
                                  flt_q_atomic_cas                                              ? {flt_q_dw_len, 2'b0} >> 1 :
                                  12'h004;

assign  flt_q_cpl_status        = (flt_q_valid_ur_np | flt_q_valid_ur_p) ? `UR_CPL_STATUS
                                 : (flt_q_valid_ca_np | flt_q_valid_ca_p) ? `CA_CPL_STATUS: `SU_CPL_STATUS;


assign flt_q_th                 = flt_q_hdr_dw1[8];
wire    [1:0]           flt_q_ph;
wire    [7:0]           flt_q_st;
assign flt_q_ph                 = (flt_q_memwr_req || flt_q_memrd_req || flt_q_atomic_op) ? flt_q_addr[1:0] :
                                  2'b0;
assign flt_q_st                 = flt_q_memwr_req ? flt_q_TAG[7:0] :
                                  (flt_q_memrd_req || flt_q_atomic_op) ? {flt_q_last_be, flt_q_first_be} :
                                  8'b0;

assign flt_q_pcie_valid_tc   = 1'b1;
assign flt_q_pcie_format     = 1'b1;

always @(flt_q_first_be)
begin: DECODE_BYTE_ADDR
    casez(flt_q_first_be)
        4'b0000:     flt_q_byte_addr = 2'b00;
        4'b???1:     flt_q_byte_addr = 2'b00;
        4'b??10:     flt_q_byte_addr = 2'b01;
        4'b?100:     flt_q_byte_addr = 2'b10;
        4'b1000:     flt_q_byte_addr = 2'b11;
        default:     flt_q_byte_addr = 2'b00;
    endcase // casez(flt_q_first_be)
end


function automatic [PF_WD:0] one_hot_decode_2_zero;
    input [NF-1:0]      one_hot_target;
    reg   [PF_WD-1:0]   encoded;
    reg                 target_eq_0;
    integer             i;

    begin
      // only function 0 is supported in RC mode
      encoded = 0;
      target_eq_0 = 1'b1;
      for (i=NF-1; i>=0 ; i=i-1) begin
        if(one_hot_target[i] == 1'b1) begin
          encoded     = i;
          target_eq_0 = 1'b0;
        end
      end

      one_hot_decode_2_zero = {encoded,target_eq_0};
    end
endfunction

parameter PIPE_VF_INDEX = 0 ;
parameter PIPE_CFG_WIDTH = (6*NF) + (6*NF) + NF + NF + NF; //cfg_bar_match + cfg_bar_is_io + cfg_rom_match + cfg_mem_match + cfg_prefmem_match
                           
wire  [(NF*6)-1:0]    cfg_bar_is_io_reg;                  // indication that tlp is within MEM BAR, which is IO space
wire  [NF-1:0]        cfg_rom_match_reg;                  // indication that tlp is within a ROM BAR
wire  [(NF*6)-1:0]    cfg_bar_match_reg;                  // indication that tlp is within a MEM BAR
wire  [NF-1:0]        cfg_mem_match_reg;
wire  [NF-1:0]        cfg_prefmem_match_reg;



wire   flt_q_mask_wreq_poisoned_reporting;
wire   flt_q_mask_cpl_poisoned_reporting;
assign flt_q_mask_wreq_poisoned_reporting = (cfg_filter_rule_mask[`CX_FLT_MASK_POIS_ERROR_REPORTING] & cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & (int_flt_q_destination == `FLT_DESTINATION_TRGT1));
assign flt_q_mask_cpl_poisoned_reporting  = cfg_filter_rule_mask[`CX_FLT_MASK_POIS_ERROR_REPORTING];

delay_n

#(PIPE_VF_INDEX, PIPE_CFG_WIDTH) u_cfg_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({cfg_bar_match, cfg_bar_is_io, cfg_rom_match, cfg_mem_match, cfg_prefmem_match 
                }),
    .dout       ({cfg_bar_match_reg, cfg_bar_is_io_reg, cfg_rom_match_reg, cfg_mem_match_reg, cfg_prefmem_match_reg
                 })
  );

always @(/*AUTOSENSE*/cfg_io_match or cfg_mem_match_reg
     or cfg_prefmem_match_reg or flt_q_cfg_func_num or flt_q_cfg_req
     or flt_q_iord_req or flt_q_iowr_req or flt_q_locked_rd
     or flt_q_memrd_req or flt_q_memwr_req or flt_q_def_memwr_req or flt_q_func_mismatch
     or flt_q_atomic_op)
begin: FUNC_NUMBER_LOOKUP
reg [5:0] local_bar;
reg [PF_WD-1:0] tmp_func_num;
    flt_q_io_req_in_range   = 0;
    flt_q_outside_mem_range  = 0;
    flt_q_outside_prefmem_range  = 0;
    flt_q_func_num         = `CX_RC_FUNC_NUM;
    tmp_func_num           = 0;

    if ( flt_q_iord_req || flt_q_iowr_req)    begin                                                  // IO transaction
        {flt_q_func_num,flt_q_io_req_in_range} = one_hot_decode_2_zero(cfg_io_match);
    end
    else
    if (flt_q_locked_rd || flt_q_memrd_req || flt_q_memwr_req || flt_q_def_memwr_req || flt_q_atomic_op) begin             // memory access
        {tmp_func_num, flt_q_outside_mem_range}     = one_hot_decode_2_zero(cfg_mem_match_reg);
        {tmp_func_num, flt_q_outside_prefmem_range} = one_hot_decode_2_zero(cfg_prefmem_match_reg);
    end
    else
        if (flt_q_cfg_req & !flt_q_func_mismatch)
            flt_q_func_num = flt_q_cfg_func_num;
end

assign  flt_q_valid_ur_wo_poisn_err = flt_q_valid_ur_np_wo_poisoned || flt_q_valid_ur_p_wo_poisoned;  // vendor msg is supported, msg with poison is a ur
assign  flt_q_valid_ur_err          = flt_q_valid_ur_np || flt_q_valid_ur_p;  // UR, including poisoned tlp

assign  flt_q_valid_ca_err          = flt_q_valid_ca_np || flt_q_valid_ca_p;




wire                    tmp_mlf_err;
assign  {tmp_mlf_err_ptr, tmp_mlf_err } = flt_q_rtlh_abort  ? {flt_q_rtlh_abort_ptr, 1'b1} :
                                          flt_q_invalid_tlp ? {`MFPTR_TLP_TYP,       1'b1} :
                                          flt_q_cpl_mlf_err ? {`MFPTR_CPL,           1'b1} :
                                          flt_q_msg_mlf_err ? {`MFPTR_MSG_TC0,       1'b1} :
                                                              {`MFPTR_NO_ERR,        1'b0} ;

always @(/*AUTOSENSE*/flt_q_cpl_rcvd_ca or tmp_mlf_err
         or flt_q_cpl_rcvd_ur or rtlh_dllp_err_d   or l_flt_q_ecrc_err
         or flt_q_valid_ca_err
         or l_flt_q_tlp_type
         or flt_q_unexp_cpl_err or flt_q_unqual_eot or flt_q_valid_ur_wo_poisn_err or flt_q_valid_ur_err
         or flt_q_poisoned_err or cfg_filter_rule_mask or flt_q_mask_wreq_poisoned_reporting or flt_q_mask_cpl_poisoned_reporting
         or cfg_p2p_err_rpt_ctrl)
begin: ERROR_PROCESSING
    l_set_radm_rcvd_req_ca              = 1'b0;
    l_set_radm_rcvd_cpl_poisoned        = 1'b0;
    l_set_radm_rcvd_req_ur              = 1'b0;
    l_set_radm_rcvd_wreq_poisoned       = 1'b0;
    l_set_radm_unexp_cpl_err            = 1'b0;
    l_set_radm_rcvd_cpl_ur              = 1'b0;
    l_set_radm_rcvd_cpl_ca              = 1'b0;
    l_set_radm_hdr_log_valid            = 1'b0;
    l_set_radm_ecrc_err                 = 1'b0;
    l_set_radm_mlf_tlp_err              = 1'b0;

    // RTLH layer reported errors
    if (flt_q_unqual_eot && !rtlh_dllp_err_d  ) begin
        l_set_radm_ecrc_err             =  l_flt_q_ecrc_err & (!tmp_mlf_err);
        l_set_radm_mlf_tlp_err          =  tmp_mlf_err;
        l_set_radm_rcvd_cpl_poisoned    =  flt_q_poisoned_err & l_flt_q_tlp_type[CPL_TYPE]  & (!l_flt_q_ecrc_err) & (!tmp_mlf_err) & (!flt_q_unexp_cpl_err) 
                                           & !flt_q_mask_cpl_poisoned_reporting;// design from spec. that poisoned is the lowest priority when only one error is allowed to reported
        l_set_radm_rcvd_wreq_poisoned   =  flt_q_poisoned_err & !l_flt_q_tlp_type[CPL_TYPE] & (!l_flt_q_ecrc_err) & (!tmp_mlf_err) & (!flt_q_valid_ur_wo_poisn_err) & (!flt_q_valid_ca_err) 
                                           & !flt_q_mask_wreq_poisoned_reporting;

        // filter detected errors for a received request
        // RC CA when ECRC is for target0 to complete with CA
        l_set_radm_rcvd_req_ca          =  flt_q_valid_ca_err & !tmp_mlf_err & !l_flt_q_ecrc_err
                                          ;
        l_set_radm_rcvd_req_ur          =  flt_q_valid_ur_err & !tmp_mlf_err & !l_flt_q_ecrc_err;
        // filter detected errors for a received completion
        l_set_radm_unexp_cpl_err        =  flt_q_unexp_cpl_err & !tmp_mlf_err;
        l_set_radm_rcvd_cpl_ur          =  flt_q_cpl_rcvd_ur ;
        l_set_radm_rcvd_cpl_ca          =  flt_q_cpl_rcvd_ca ;

        // filter detected errors for a received message
        l_set_radm_hdr_log_valid        =  (l_flt_q_ecrc_err      ||
                                            tmp_mlf_err         ||
                                            flt_q_poisoned_err  ||
                                            flt_q_valid_ur_wo_poisn_err ||
                                            flt_q_valid_ur_err  ||
                                            flt_q_valid_ca_err  ||
                                            flt_q_unexp_cpl_err ||
                                            flt_q_cpl_rcvd_ur   ||
                                            flt_q_cpl_rcvd_ca
                                            );
    end
end // block: ERROR_PROCESSING

// Output registering (optional)
parameter ERROR_LOG_PIPE_DELAY = `CX_ERROR_LOG_REGOUT;
parameter ERROR_LOG_PIPEWIDTH = 125 + PF_WD
                                + 13;

// CTRL_registers_path
reg pipe_error_log_en;
assign pipe_error_log_en = (flt_q_unqual_dv | flt_q_unqual_hv); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe

reg pipe_error_log_en_reg;
generate 
    if (ERROR_LOG_PIPE_DELAY > 0) begin : gen_error_log_pipe 
       always @(posedge core_clk or negedge core_rst_n)
       begin  
          if (!core_rst_n) begin
             pipe_error_log_en_reg    <= #TP 0;
          end else begin
             pipe_error_log_en_reg    <= #TP pipe_error_log_en;
          end
       end// always
   end else begin : gen_error_log_pipe_eq0
      assign  pipe_error_log_en_reg  = 0;
   end
endgenerate

reg error_log_pipe_en;
assign error_log_pipe_en = !upstream_port && (pipe_error_log_en | pipe_error_log_en_reg); //  to flush the ERROR pipe and set error only for a cycle.

delay_n_w_enable

#(ERROR_LOG_PIPE_DELAY,ERROR_LOG_PIPEWIDTH) u_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (error_log_pipe_en),
    .din        ({  l_radm_hdr_log,
                    l_set_radm_rcvd_req_ca, l_set_radm_rcvd_cpl_poisoned,
                    l_set_radm_rcvd_req_ur, l_set_radm_rcvd_wreq_poisoned,
                    l_set_radm_unexp_cpl_err, l_set_radm_rcvd_cpl_ur,
                    l_set_radm_rcvd_cpl_ca, l_set_radm_ecrc_err,
                    l_set_radm_mlf_tlp_err, l_set_radm_hdr_log_valid,
                    flt_q_func_num}),
    .dout       ({  radm_hdr_log,
                    set_radm_rcvd_req_ca, set_radm_rcvd_cpl_poisoned,
                    set_radm_rcvd_req_ur, set_radm_rcvd_wreq_poisoned,
                    set_radm_unexp_cpl_err, set_radm_rcvd_cpl_ur,
                    set_radm_rcvd_cpl_ca, set_radm_ecrc_err,
                    set_radm_mlf_tlp_err, set_radm_hdr_log_valid,
                    flt_q_func_num_d})
);



assign flt_q_header = chk_l_flt_q_header_d;
assign flt_q_addr = extract_addr;

parameter FLT_Q_PIPE_DELAY = `CX_FLT_Q_REGOUT;
parameter FLT_Q_PIPEWIDTH = `CX_FLT_Q_PIPELINE_WD + HW + DATA_PAR_WD + FLT_OUT_PROT_WD + 1 - GATING_CTRL_PATH_WD
                            ;

// when asserted indicates an uncorrectable error has been detected in the data
// if RAS is not used this signal is set to 0
wire l_flt_data_parerr;

  assign chk_l_flt_q_data  = l_flt_q_data;
  assign l_flt_data_parerr = 1'b0;

// CTRL_registers_path
generate 
    if (FLT_Q_PIPE_DELAY > 0) begin : gen_flt_q_pipe_delay 
       reg [NVC-1:0] l_flt_q_hv_reg[FLT_Q_PIPE_DELAY-1:0]; // [NVC-1:0]  l_flt_q_hv, l_flt_q_dv, l_flt_q_eot
       reg [NVC-1:0] l_flt_q_dv_reg[FLT_Q_PIPE_DELAY-1:0];
       reg [NVC-1:0] l_flt_q_eot_reg[FLT_Q_PIPE_DELAY-1:0];

       always @(posedge core_clk or negedge core_rst_n)
       begin  
          integer i;

          if (!core_rst_n) begin
             for(i = 0; i < FLT_Q_PIPE_DELAY; i = i + 1) begin 
                l_flt_q_hv_reg[i]    <= #TP 0;
                l_flt_q_dv_reg[i]    <= #TP 0;
                l_flt_q_eot_reg[i]   <= #TP 0;
             end
          end else begin
             for(i = 0; i < FLT_Q_PIPE_DELAY; i = i + 1) begin
                if(i==0) begin
                   l_flt_q_hv_reg[i]    <= #TP l_flt_q_hv;
                   l_flt_q_dv_reg[i]    <= #TP l_flt_q_dv;
                   l_flt_q_eot_reg[i]   <= #TP l_flt_q_eot;
                end else begin
                   l_flt_q_hv_reg[i]    <= #TP l_flt_q_hv_reg[i-1];
                   l_flt_q_dv_reg[i]    <= #TP l_flt_q_dv_reg[i-1];
                   l_flt_q_eot_reg[i]   <= #TP l_flt_q_eot_reg[i-1];
                end
             end // for
          end
       end
       assign  flt_q_hv  = l_flt_q_hv_reg[FLT_Q_PIPE_DELAY-1];
       assign  flt_q_dv  = l_flt_q_dv_reg[FLT_Q_PIPE_DELAY-1];
       assign  flt_q_eot = l_flt_q_eot_reg[FLT_Q_PIPE_DELAY-1];
       assign  flt_q_tlp_abort = int_flt_q_tlp_abort;

   end else begin : gen_flt_q_pipe_delay_eq0 
       assign  flt_q_hv  = l_flt_q_hv;
       assign  flt_q_dv  = l_flt_q_dv;
       assign  flt_q_eot = l_flt_q_eot;
       assign  flt_q_tlp_abort = int_flt_q_tlp_abort;

   end
endgenerate

wire flt_q_pipe_en;
assign flt_q_pipe_en = !upstream_port && ((|l_flt_q_hv) || (|l_flt_q_dv)); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe

delay_n_w_enable

#(FLT_Q_PIPE_DELAY, FLT_Q_PIPEWIDTH) u_flt_q_pipeline(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (flt_q_pipe_en),
    .din        ({
                    l_flt_q_seg_num,
                    l_flt_q_vc,
                    chk_l_flt_q_data,
                    l_flt_q_dllp_abort,
                    l_flt_q_dwen,
                    l_flt_q_ecrc_err,
                    l_flt_q_parerr,
                    l_flt_q_header,
                    l_flt_q_tlp_abort,
                    l_flt_q_tlp_type
                    }),
    .dout       ({
                    flt_q_seg_num,
                    flt_q_vc,
                    flt_q_data,
                    flt_q_dllp_abort,
                    flt_q_dwen,
                    flt_q_ecrc_err,
                    int_flt_q_parerr,
                    l_flt_q_header_d,
                    int_flt_q_tlp_abort,
                    flt_q_tlp_type
                    })

);

  assign chk_l_flt_q_header_d = l_flt_q_header_d;


assign  radm_ecrc_err           = {NF{set_radm_ecrc_err}};
assign  radm_mlf_tlp_err        = {NF{set_radm_mlf_tlp_err}};
assign  radm_rcvd_req_ca        = route_error_to_func( set_radm_rcvd_req_ca        , flt_q_func_num_d);
assign  radm_rcvd_req_ur        = route_error_to_func( set_radm_rcvd_req_ur        , flt_q_func_num_d);

assign  radm_rcvd_cpl_poisoned  = route_error_to_func( set_radm_rcvd_cpl_poisoned  , flt_q_func_num_d);
assign  radm_rcvd_wreq_poisoned = route_error_to_func( set_radm_rcvd_wreq_poisoned , flt_q_func_num_d);
assign  radm_unexp_cpl_err      = {NF{set_radm_unexp_cpl_err}};                         // Non function specific error (PCIe 1.1 C16 errata)
assign  radm_rcvd_cpl_ur        = route_error_to_func( set_radm_rcvd_cpl_ur        , flt_q_func_num_d);
assign  radm_rcvd_cpl_ca        = route_error_to_func( set_radm_rcvd_cpl_ca        , flt_q_func_num_d);
assign  radm_hdr_log_valid      = route_error_to_func( set_radm_hdr_log_valid      , flt_q_func_num_d);

assign  flt_drop_msg            = (!cfg_filter_rule_mask[`CX_FLT_MASK_MSG_DROP] & !(flt_q_vendor_msg | flt_q_invalidate_msg 
                                  )) ||
                                     (!cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG0_DROP] & flt_q_vendor_msg0) ||
                                     ((!cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG1_DROP] & flt_q_vendor_msg1)
                                     )
                                  ;

wire   enable_mask_pois_if_trgt0_destination;
assign enable_mask_pois_if_trgt0_destination = 1;

assign  flt_q_ecrc_discard      = l_flt_q_ecrc_err & !cfg_filter_rule_mask[`CX_FLT_MASK_ECRC_DISCARD]; // when discard an ECRC TLP is desired
assign  flt_q_poisoned_discard  = flt_q_poisoned_err & !(cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & enable_mask_pois_if_trgt0_destination) ;

assign  flt_q_in_membar_range   = (cfg_bar_match_reg[0]) ? 0 : (cfg_bar_match_reg[1]) ? 1:3'b111;
assign  flt_q_mem_req_in_range  = (|(cfg_bar_match_reg & (~cfg_bar_is_io_reg))) & (flt_q_locked_rd   || flt_q_memrd_req || flt_q_memwr_req || flt_q_def_memwr_req || flt_q_atomic_op);
assign  flt_q_rom_req_in_range  = (|cfg_rom_match_reg) & (flt_q_locked_rd   || flt_q_memrd_req || flt_q_memwr_req || flt_q_def_memwr_req || flt_q_atomic_op);
//`ifdef CX_CXL_ENABLE
//assign  flt_q_rcrb_req_in_range  = (cfg_rcrb_match_reg || cfg_rcrb_mbar0_match_reg) & flt_q_mem_req_rcrb;
//`endif  //CX_CXL_ENABLE



always @(/*AUTO SENSE*/default_target
         or flt_q_tlp_is_msg or l_flt_q_tlp_type or flt_q_valid_ur_np or flt_q_valid_ca_np
         or flt_q_valid_ur_p or flt_q_valid_ca_p or flt_drop_msg or flt_q_handle_flush
         or flt_q_cpl_abort
         )
begin:  FILTER_PROCESS
    if (l_flt_q_tlp_type[P_TYPE])                                         // [------------- POSTED -------------]
    begin                                                               //
        if (flt_q_tlp_is_msg & flt_drop_msg)      //  MESSAGE will not pass to application
            int_flt_q_destination = `FLT_DESTINATION_TRASH;                 //
        else if (!flt_q_valid_ur_p & !flt_q_valid_ca_p & flt_q_handle_flush)                 // VADID EXCEPT for MESSAGE
            int_flt_q_destination     = `FLT_DESTINATION_TRGT0;             //  ALL (EXCEPT message), valid or not
        else if (!flt_q_valid_ur_p & !flt_q_valid_ca_p) begin           // VADID EXCEPT for MESSAGE
            int_flt_q_destination     = `FLT_DESTINATION_TRGT1;             //  ALL (EXCEPT message), valid or not
        end
        else if (default_target)                                        // target determined by default_target
            int_flt_q_destination = `FLT_DESTINATION_TRGT1;                     //  ALL others, valid or not
        else                                                            //
            int_flt_q_destination = `FLT_DESTINATION_TRASH;                 //

    end                                                                 //
    else                                                                //
    if (l_flt_q_tlp_type[NP_TYPE]) begin                                  // [----------- NON-POSTED -----------]
        if (!flt_q_valid_ur_np & !flt_q_valid_ca_np & flt_q_handle_flush)                                      // TRGT0
            int_flt_q_destination     = `FLT_DESTINATION_TRGT0;             //  VALID, or VALID UR
        else if (!flt_q_valid_ur_np & !flt_q_valid_ca_np) begin                               // TRGT0
            int_flt_q_destination     = `FLT_DESTINATION_TRGT1;             //  VALID, or VALID UR
        end
        else if (default_target)                                        // target determined by default_target
            int_flt_q_destination     = `FLT_DESTINATION_TRGT1;             //  ALL others, valid or not
        else                                                            //
            int_flt_q_destination = `FLT_DESTINATION_TRGT0;                 //
     end                                                                //
     else                                                               //
     if (l_flt_q_tlp_type[CPL_TYPE]) begin                                // [-------------- CPL ---------------]
            if (flt_q_cpl_abort)                                        //
                   int_flt_q_destination   = `FLT_DESTINATION_TRASH;        //  ABORTED CPLs (determinded @ hv)
            else                                                        //
                   int_flt_q_destination   = `FLT_DESTINATION_CPL;          //  ALL CPLs expected aborted
     end
     else
            int_flt_q_destination = `FLT_DESTINATION_TRASH;

end


//  ENCODED valid type
always @(flt_q_valid_np or flt_q_valid_p or flt_q_valid_ur_np or flt_q_valid_ur_p)
begin:  ENCODE_VALID_TYPE
    case({flt_q_valid_ur_p,flt_q_valid_ur_np,flt_q_valid_p,flt_q_valid_np})
        4'b0001:     flt_q_valid_type  = `FLT_VALID_NP_TYPE;

        4'b0010:     flt_q_valid_type  = `FLT_VALID_P_TYPE;

        4'b0100:     flt_q_valid_type  = `FLT_VALID_UR_NP_TYPE;

        4'b1000:     flt_q_valid_type  = `FLT_VALID_UR_P_TYPE;

        default:     flt_q_valid_type  = 3'b100; //
    endcase //
end


wire cpl_req_id_match;
assign cpl_req_id_match = 1'b1;

// CTRL_registers_path
always @(posedge core_clk or negedge core_rst_n)
begin  
   if (!core_rst_n) begin
      flt_q_unqual_dv  <= #TP 0;
      flt_q_unqual_hv  <= #TP 0;
      flt_q_unqual_eot <= #TP 0;
   end else if(!upstream_port) begin
      flt_q_unqual_dv  <= #TP rtlh_radm_dv;
      flt_q_unqual_hv  <= #TP rtlh_radm_hv;
      flt_q_unqual_eot <= #TP rtlh_radm_eot;
   end
end

wire latch_hdr_pipe_en;
assign latch_hdr_pipe_en = !upstream_port && (rtlh_radm_dv | rtlh_radm_hv); 

always @(posedge core_clk or negedge core_rst_n)
begin: LATCH_HDR_PROCESS
    if(!core_rst_n)
    begin
        l_flt_q_data            <= #TP 0;
        l_flt_q_dwen            <= #TP 0;
        l_flt_q_ecrc_err        <= #TP 0;
        flt_q_malf_err          <= #TP 0;
        flt_q_cpl_mlf_err       <= #TP 0;
        flt_q_msg_mlf_err       <= #TP 0;
        flt_q_unexp_cpl_err     <= #TP 0;
        flt_q_cpl_rcvd_ur       <= #TP 0;
        flt_q_cpl_rcvd_ca       <= #TP 0;
        flt_q_rtlh_abort        <= #TP 0;
        flt_q_rtlh_abort_ptr    <= #TP 0;
        l_flt_q_dllp_abort      <= #TP 0;
        rtlh_dllp_err_d         <= #TP 0;
        flt_q_hdr_dw1           <= #TP 0;
        flt_q_hdr_dw2           <= #TP 0;
        flt_q_hdr_dw3           <= #TP 0;
        flt_q_hdr_dw4           <= #TP 0;
        flt_q_dwlenEq1          <= #TP 0;
        flt_q_select            <= #TP 0;
        flt_q_handle_flush      <= #TP 0;
        l_flt_q_parerr          <= #TP 0;
    end
    else if (latch_hdr_pipe_en)
    begin
        l_flt_q_data            <= #TP rtlh_radm_data;
        l_flt_q_dwen            <= #TP rtlh_radm_dwen;

        l_flt_q_dllp_abort      <= #TP
          // do not alter the meaning of dllp_abort unless the completion buffering mode is store and forward
                                       rtlh_radm_dllp_err;

        rtlh_dllp_err_d         <= #TP rtlh_radm_dllp_err;
        {flt_q_rtlh_abort_ptr, flt_q_rtlh_abort} <= #TP rtlh_radm_dllp_err        ? {`MFPTR_NO_ERR,                 1'b0} :
                                                        rtlh_radm_malform_tlp_err ? {rtlh_radm_malform_tlp_err_ptr, 1'b1} :
                                                                                    {`MFPTR_NO_ERR,                 1'b0} ;
        l_flt_q_ecrc_err          <= #TP rtlh_radm_ecrc_err & !rtlh_radm_dllp_err;

        flt_q_cpl_mlf_err       <= #TP cpl_tlp & cpl_mlf_err;
        flt_q_msg_mlf_err       <= #TP tlp_is_msg && int_mlf_msg;

        flt_q_malf_err          <= #TP rtlh_radm_malform_tlp_err & !rtlh_radm_dllp_err;
        flt_q_unexp_cpl_err     <= #TP cpl_tlp & unexpected_cpl_err;

        flt_q_cpl_rcvd_ur       <= #TP cpl_tlp & cpl_ur_err;
        flt_q_cpl_rcvd_ca       <= #TP cpl_tlp & cpl_ca_err;
        flt_q_hdr_dw1           <= #TP chk_rtlh_radm_hdr[31:0];
        flt_q_hdr_dw2           <= #TP chk_rtlh_radm_hdr[63:32];
        flt_q_hdr_dw3           <= #TP chk_rtlh_radm_hdr[95:64];
        flt_q_hdr_dw4           <= #TP chk_rtlh_radm_hdr[127:96];
        flt_q_dwlenEq1          <= #TP dwlenEq1;
        flt_q_select            <= #TP q_select_from_tc(cfg_tc_struc_vc_map, tc);
        flt_q_handle_flush      <= #TP cfg_filter_rule_mask[`CX_FLT_MASK_HANDLE_FLUSH] & dwlenEq1 & (first_be == 4'b0) & (last_be == 4'b0) & pcie_format
         ;
        l_flt_q_parerr          <= #TP rtlh_radm_parerr | l_flt_data_parerr;
end
end

assign  l_flt_q_hv[0]             = (flt_q_unqual_hv  & !flt_q_invalid_tlp);
assign  l_flt_q_dv[0]             = (flt_q_unqual_dv  & !flt_q_invalid_tlp);
assign  l_flt_q_eot[0]            = (flt_q_unqual_eot & !flt_q_invalid_tlp);

// Detect if an access greater than the address bus width occurs
// Check both the AMBA address bus and Core. Don't do this check here if
// address translation support is enabled. Need to do it after we get the
// address back
wire flt_q_addr_gt_bus_width;
wire flt_q_addr_gt_mstr_addr_width;
assign flt_q_addr_gt_bus_width = 1'b0;
assign flt_q_addr_gt_mstr_addr_width = 1'b0;
// Always out of range if access is attempted above the either the core or
// AMBA address bus widths, unless address translation support is enabled
assign  flt_q_mem_req_range     =  (cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR    ] ||  flt_q_mem_req_in_range || (flt_q_outside_mem_range && flt_q_outside_prefmem_range)) && !(flt_q_addr_gt_mstr_addr_width || flt_q_addr_gt_bus_width);
assign  flt_q_locked_rd_tlp     =  (!cfg_filter_rule_mask[`CX_FLT_MASK_LOCKED_RD_AS_UR  ] &&  flt_q_locked_rd       );

// Check for a valid Atomic Op.
// An Atomic Op request must have a supported operand size otherwise
// the request should be treated as a UR.
wire valid_atomic_request;
wire atomic_operand32;
wire atomic_operand64;
wire atomic_operand128;

assign atomic_operand32     = (flt_q_atomic_fetchadd || flt_q_atomic_swap) && (flt_q_dw_len == 10'h1) ||
                              flt_q_atomic_cas && (flt_q_dw_len == 10'h2);

assign atomic_operand64     = (flt_q_atomic_fetchadd || flt_q_atomic_swap) && (flt_q_dw_len == 10'h2) ||
                              flt_q_atomic_cas && (flt_q_dw_len == 10'h4);

assign atomic_operand128    = flt_q_atomic_cas && (flt_q_dw_len == 10'h8);

assign valid_atomic_request = atomic_operand32  && `CX_ATOMIC_32_CPL_EN ||
                              atomic_operand64  && `CX_ATOMIC_64_CPL_EN ||
                              atomic_operand128 && `CX_ATOMIC_128_CAS_EN;

// We don't support Atomic Ops targeting TRGT0 (ELBI)
wire flt_q_atomic_discard;
assign flt_q_atomic_discard = 1'b0;

// Check for valid DMWr Requests
// A DMWr request must have a supported operand size otherwise the request should be treated as a UR.
localparam MAX_DMWR_SIZE = (`CX_DEF_MEM_WR_LEN_SUPP == 0)? 10'd16 : 10'd32;
wire valid_def_memwr_request;
assign valid_def_memwr_request = flt_q_def_memwr_req  && (flt_q_dw_len > 10'h0) && (flt_q_dw_len <= MAX_DMWR_SIZE) && (`CX_DEF_MEM_WR_CPL_EN || `CX_DEF_MEM_WR_ROUTING_EN);

// We don't support DMWrs Ops targeting TRGT0 (ELBI)
wire flt_q_def_memwr_discard;
assign flt_q_def_memwr_discard = 1'b0;

wire valid_ats;
assign valid_ats = 1;


assign  flt_q_valid_np          = (flt_q_mem_req_range && (valid_atomic_request | flt_q_memrd_req | valid_def_memwr_request | flt_q_locked_rd_tlp) && valid_ats && flt_q_pcie_valid_tc)
                                  || ((flt_q_cfg1rd_req || flt_q_cfg1wr_req || flt_q_cfg0rd_req || flt_q_cfg0wr_req) & flt_q_pcie_valid_tc & cfg_filter_rule_mask[`CX_FLT_MASK_RC_CFG_DISCARD])
                                  || ((flt_q_iord_req || flt_q_iowr_req) && flt_q_pcie_valid_tc && cfg_filter_rule_mask[`CX_FLT_MASK_RC_IO_DISCARD]);

assign  flt_q_valid_p           = (flt_q_mem_req_range && flt_q_memwr_req && valid_ats && flt_q_pcie_valid_tc) || (flt_q_tlp_is_msg && !flt_q_invalid_msg)           // !(poisoned or outrange)
                                ;

assign  flt_q_valid_ur_np_wo_poisoned = (flt_q_cfg1rd_req    ||
                                   flt_q_cfg1wr_req    ||
                                   flt_q_cfg0rd_req    ||
                                   flt_q_cfg0wr_req    ||
                                   flt_q_memrd_req     ||
                                   (flt_q_def_memwr_req && !flt_q_def_memwr_discard) ||
                                   flt_q_locked_rd     ||
                                   flt_q_iord_req      ||
                                   flt_q_iowr_req      ||
                                   (flt_q_atomic_op && !flt_q_atomic_discard)
                                   ) && (!flt_q_valid_np);

assign  flt_q_valid_ur_np       = (flt_q_cfg1rd_req    ||
                                   flt_q_cfg1wr_req    ||
                                   flt_q_cfg0rd_req    ||
                                   flt_q_cfg0wr_req    ||
                                   flt_q_memrd_req     ||
                                   (flt_q_def_memwr_req && !flt_q_def_memwr_discard) ||
                                   flt_q_locked_rd     ||
                                   flt_q_iord_req      ||
                                   flt_q_iowr_req      ||
                                   (flt_q_atomic_op && !flt_q_atomic_discard)
                                   ) && (!flt_q_valid_np | flt_q_poisoned_discard);

assign  flt_q_valid_ur_p_wo_poisoned     = (flt_q_memwr_req || flt_q_tlp_is_msg) && (!flt_q_valid_p);

assign  flt_q_valid_ur_p        = (flt_q_memwr_req || flt_q_tlp_is_msg) && (!flt_q_valid_p | flt_q_poisoned_discard);

assign  flt_q_valid_ca_p        = (flt_q_memwr_req || flt_q_tlp_is_msg) && (flt_q_ecrc_discard
                                );
assign  flt_q_valid_ca_np       = flt_q_valid_np && (flt_q_ecrc_discard || flt_q_atomic_discard || flt_q_def_memwr_discard
                                );



//
// [ ----------------  MESSAGE interception  -----------------------]
//

wire                    int_pm_asnak;
wire                    int_pm_pme;
wire                    int_pm_to_ack;
wire                    int_inta_asserted;
wire                    int_intb_asserted;
wire                    int_intc_asserted;
wire                    int_intd_asserted;
wire                    int_inta_deasserted;
wire                    int_intb_deasserted;
wire                    int_intc_deasserted;
wire                    int_intd_deasserted;
wire                    int_err_cor;
wire                    int_err_nf;
wire                    int_err_f;
wire                    int_att_button_pressed;
wire                    int_att_ind_on;
wire                    int_att_ind_blink;
wire                    int_att_ind_off;
wire                    int_pwr_ind_on;
wire                    int_pwr_ind_blink;
wire                    int_pwr_ind_off;
wire                    int_invalidate_request;
wire                    int_invalidate_cmplt;

assign  int_pm_asnak            = ((msg_code == `PM_ACTIVE_STATE_NAK)         && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format); 
assign  int_pm_pme              = ((msg_code == `PM_PME)                      && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_pm_to_ack           = ((msg_code == `PME_TO_ACK)                  && (hdr_type[2:0] == 3'b101) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_inta_asserted       = ((msg_code == `ASSERT_INTA)                 && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_intb_asserted       = ((msg_code == `ASSERT_INTB)                 && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_intc_asserted       = ((msg_code == `ASSERT_INTC)                 && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_intd_asserted       = ((msg_code == `ASSERT_INTD)                 && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_inta_deasserted     = ((msg_code == `DEASSERT_INTA)               && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_intb_deasserted     = ((msg_code == `DEASSERT_INTB)               && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_intc_deasserted     = ((msg_code == `DEASSERT_INTC)               && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_intd_deasserted     = ((msg_code == `DEASSERT_INTD)               && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_err_cor             = ((msg_code == `ERR_COR)                     && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_err_nf              = ((msg_code == `ERR_NF)                      && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_err_f               = ((msg_code == `ERR_F)                       && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_att_button_pressed  = ((msg_code == `ATTENTION_BUTTON_PRESSED)    && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_att_ind_on          = ((msg_code == `ATTENTION_INDICATOR_ON)      && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_att_ind_blink       = ((msg_code == `ATTENTION_INDICATOR_BLINK)   && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_att_ind_off         = ((msg_code == `ATTENTION_INDICATOR_OFF)     && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_pwr_ind_on          = ((msg_code == `POWER_INDICATOR_ON)          && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_pwr_ind_blink       = ((msg_code == `POWER_INDICATOR_BLINK)       && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_pwr_ind_off         = ((msg_code == `POWER_INDICATOR_OFF)         && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
assign  int_invalidate_request  = ((msg_code == `INVALIDATE_REQUEST)          && (hdr_type[2:0] == 3'b010) && (tlpmsg == `MSGD_4) && !int_mlf_msg  && pcie_format);
assign  int_invalidate_cmplt    = ((msg_code == `INVALIDATE_COMPLETION)       && (hdr_type[2:0] == 3'b010) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);

// Several Messages are required to be sent with TC0  and checking is required.
// Section 2.2.8.x:
// "x Messages must use the default Traffic Class designator (TC0). Receivers
// must check for violations of this rule. If a Receiver determines that
// a TLP violates this rule, it must handle the TLP as a Malformed TLP"
assign int_mlf_msg = pcie_format && tc != 0 && (
    ((msg_code == `PM_ACTIVE_STATE_NAK)) ||
    ((msg_code == `PM_PME)             ) ||
    ((msg_code == `PME_TO_ACK)         ) ||
    ((msg_code == `ASSERT_INTA)        ) ||
    ((msg_code == `ASSERT_INTB)        ) ||
    ((msg_code == `ASSERT_INTC)        ) ||
    ((msg_code == `ASSERT_INTD)        ) ||
    ((msg_code == `DEASSERT_INTA)      ) ||
    ((msg_code == `DEASSERT_INTB)      ) ||
    ((msg_code == `DEASSERT_INTC)      ) ||
    ((msg_code == `DEASSERT_INTD)      ) ||
    ((msg_code == `ERR_COR)            ) ||
    ((msg_code == `ERR_NF)             ) ||
    ((msg_code == `ERR_F)              )
);

reg flt_q_pcie_good_eot;

assign  flt_q_vendor_msg        = flt_q_vendor_msg0 || flt_q_vendor_msg1;


always @(posedge core_clk or negedge core_rst_n)
begin:  MESSAGE_INTERCEPTION_PROCESS
    if (!core_rst_n)
    begin
        radm_pm_asnak           <= #TP 1'b0;
        radm_pm_pme             <= #TP 1'b0;
        radm_pm_to_ack          <= #TP 1'b0;
        radm_inta_asserted      <= #TP 1'b0;
        radm_intb_asserted      <= #TP 1'b0;
        radm_intc_asserted      <= #TP 1'b0;
        radm_intd_asserted      <= #TP 1'b0;
        radm_inta_deasserted    <= #TP 1'b0;
        radm_intb_deasserted    <= #TP 1'b0;
        radm_intc_deasserted    <= #TP 1'b0;
        radm_intd_deasserted    <= #TP 1'b0;
        radm_err_cor            <= #TP 1'b0;
        radm_err_nf             <= #TP 1'b0;
        radm_err_f              <= #TP 1'b0;
        flt_q_invalid_msg       <= #TP 1'b0;
        flt_q_vendor_msg0       <= #TP 1'b0;
        flt_q_vendor_msg1       <= #TP 1'b0;
        flt_q_invalidate_msg    <= #TP 1'b0;
        flt_q_pcie_good_eot     <= #TP 1'b0;
    end
    else
    begin
        flt_q_vendor_msg0               <= #TP msg_is_vendor_msg0 && tlp_is_msg && !tlp_poisoned;
        flt_q_vendor_msg1               <= #TP msg_is_vendor_msg1 && tlp_is_msg && !tlp_poisoned;
        flt_q_invalidate_msg            <= #TP (( int_invalidate_request | int_invalidate_cmplt) && `CX_ATS_ENABLE_VALUE==1)
                                               && tlp_is_msg && !tlp_poisoned;


        flt_q_pcie_good_eot             <= #TP rtlh_radm_eot && pcie_valid_tc && !(rtlh_radm_dllp_err | rtlh_radm_ecrc_err | rtlh_radm_malform_tlp_err);

        // DV and HV may not asserted at the same cycle, so we must
        // latch the slot message to assert when payload data is ready


        if (rtlh_radm_hv & rtlh_radm_eot & !tlp_poisoned & flt_dwlenEq0 & tlp_is_msg & pcie_valid_tc & !(rtlh_radm_dllp_err | rtlh_radm_ecrc_err | rtlh_radm_malform_tlp_err)) begin
            radm_pm_asnak            <= #TP  int_pm_asnak            ;
            radm_pm_pme              <= #TP  int_pm_pme              ;
            radm_pm_to_ack           <= #TP  int_pm_to_ack           ;
            radm_inta_asserted       <= #TP  int_inta_asserted       ;
            radm_intb_asserted       <= #TP  int_intb_asserted       ;
            radm_intc_asserted       <= #TP  int_intc_asserted       ;
            radm_intd_asserted       <= #TP  int_intd_asserted       ;
            radm_inta_deasserted     <= #TP  int_inta_deasserted     ;
            radm_intb_deasserted     <= #TP  int_intb_deasserted     ;
            radm_intc_deasserted     <= #TP  int_intc_deasserted     ;
            radm_intd_deasserted     <= #TP  int_intd_deasserted     ;
            radm_err_cor             <= #TP  int_err_cor             ;
            radm_err_nf              <= #TP  int_err_nf              ;
            radm_err_f               <= #TP  int_err_f               ;
        end
        else
        begin
            radm_pm_asnak            <= #TP 1'b0;
            radm_pm_pme              <= #TP 1'b0;
            radm_pm_to_ack           <= #TP 1'b0;
            radm_inta_asserted       <= #TP 1'b0;
            radm_intb_asserted       <= #TP 1'b0;
            radm_intc_asserted       <= #TP 1'b0;
            radm_intd_asserted       <= #TP 1'b0;
            radm_inta_deasserted     <= #TP 1'b0;
            radm_intb_deasserted     <= #TP 1'b0;
            radm_intc_deasserted     <= #TP 1'b0;
            radm_intd_deasserted     <= #TP 1'b0;
            radm_err_cor             <= #TP 1'b0;
            radm_err_nf              <= #TP 1'b0;
            radm_err_f               <= #TP 1'b0;
        end

        flt_q_invalid_msg            <= #TP ~( (pcie_valid_tc &
                                                ((msg_is_vendor_msg0 & cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG0_DROP]) | // When vendor 0 is dropped, it'll create a UR
                                                  msg_is_vendor_msg1      |         // VENDOR_MSG1 valid if routing 000b, 010b, 011b or 100b
                                                  int_pm_asnak            |
                                                  int_pm_pme              |
                                                  int_pm_to_ack           |
                                                  int_inta_asserted       |
                                                  int_intb_asserted       |
                                                  int_intc_asserted       |
                                                  int_intd_asserted       |
                                                  int_inta_deasserted     |
                                                  int_intb_deasserted     |
                                                  int_intc_deasserted     |
                                                  int_intd_deasserted     |
                                                  int_err_cor             |
                                                  int_err_nf              |
                                                  int_err_f               |
                                                  int_att_ind_on          |
                                                  int_att_ind_blink       |
                                                  int_att_ind_off         |
                                                  int_pwr_ind_on          |
                                                  int_pwr_ind_blink       |
                                                  int_pwr_ind_off         |
                                                  int_att_button_pressed
                                               ))
                                             )
                                                & tlp_is_msg & (rtlh_radm_hv | rtlh_radm_dv) & rtlh_radm_eot
                        & !(rtlh_radm_dllp_err | rtlh_radm_ecrc_err | rtlh_radm_malform_tlp_err | int_mlf_msg);
    end
end




// for short Vendor message, we can send to SII interface
//--------------------------------
// Extract SII message header info
//--------------------------------
assign  radm_vendor_msg = (flt_q_vendor_msg & flt_q_pcie_good_eot)
                        ;


// The VDM message payload is defined from bytes 12 to byte 15.
// To be consistent with the format on the RTRGT1 address bus the byte  order is reversed.
// DW3 output on bits [63:32], DW4 output on [31:0].
assign  radm_msg_payload = flt_q_vendor_msg ?
                             {flt_q_hdr_dw3[7:0],flt_q_hdr_dw3[15:8],flt_q_hdr_dw3[23:16],flt_q_hdr_dw3[31:24],
                              flt_q_hdr_dw4[7:0],flt_q_hdr_dw4[15:8],flt_q_hdr_dw4[23:16],flt_q_hdr_dw4[31:24]} :
                             {32'b0, chk_l_flt_q_data[31:0]};


assign  radm_rcvd_tlp_req_id    = flt_q_REQID;

assign  l_flt_q_header          = flt_q_compressed_hdr;

assign  l_flt_q_tlp_abort       = (flt_q_cpl_abort | flt_q_rtlh_abort | flt_q_msg_mlf_err
                                ) & flt_q_unqual_eot;

// ECRC error can cause store and forward queue to drop the TLP. The drop
// was decidied by destination. Therefore, the destination needs to be
// reevaluated at the end of ecrc errored packet
wire    update_destination_en;
assign  update_destination_en = (latchd_flt_q_destination != `FLT_DESTINATION_TRASH);
assign  flt_q_destination       = (flt_q_unqual_hv | (flt_q_unqual_eot & update_destination_en)) ? int_flt_q_destination[1:0] : latchd_flt_q_destination[1:0];          // Q DEMUX control


// We need to latch the decision made for destination because the context
// may be varied during a non hv cycle
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        latchd_flt_q_destination    <= #TP 0;
    else if (flt_q_unqual_hv)
        latchd_flt_q_destination    <= #TP int_flt_q_destination;
end

always @(/*AUTOSENSE*/flt_q_REQID or flt_q_TAG or flt_q_addr or flt_q_attr
     or flt_q_cpl_bcm or flt_q_cpl_last or flt_q_cpl_reqid
     or flt_q_cpl_status or flt_q_cplid or flt_q_destination
     or flt_q_rom_req_in_range
     or flt_q_in_membar_range
     or flt_q_dw_len or flt_q_first_be or flt_q_fmt
     or flt_q_func_num or flt_q_io_req_in_range or flt_q_last_be
     or flt_q_poisoned or flt_q_rcvd_cpl_status
     or flt_q_reserved_status or flt_q_rcvd_cpl_tlp_tag
     or flt_q_rcvd_tlp_byte_cnt or flt_q_rcvd_tlp_low_addr
     or flt_q_tc or flt_q_td or l_flt_q_tlp_type or flt_q_type)
begin:  ASSEMBLE_COMPRESSED_HDR_PROCESS
    flt_q_compressed_hdr = 0;
    flt_q_compressed_hdr[ `FLT_Q_FMT_RANGE             ] = flt_q_fmt[1:0];                  // completion hdr element
    flt_q_compressed_hdr[ `FLT_Q_TYPE_RANGE            ] = flt_q_type[4:0];                 // completion hdr element
    flt_q_compressed_hdr[ `FLT_Q_TC_RANGE              ] = flt_q_tc[2:0];                   // completion hdr element
    flt_q_compressed_hdr[ `FLT_Q_TD_RANGE              ] = flt_q_td;
    flt_q_compressed_hdr[ `FLT_Q_EP_RANGE              ] = flt_q_poisoned;
    flt_q_compressed_hdr[ `FLT_Q_ATTR_RANGE            ] = flt_q_attr;                      // completion hdr element
    flt_q_compressed_hdr[ `FLT_Q_DW_LENGTH_RANGE       ] = flt_q_dw_len[9:0];               // completion hdr element
    flt_q_compressed_hdr[ `FLT_Q_REQID_RANGE           ] = flt_q_REQID[15:0];               // completion hdr element
    flt_q_compressed_hdr[ `FLT_Q_TAG_RANGE             ] = flt_q_TAG[TAG_SIZE-1:0];         // completion hdr element
    flt_q_compressed_hdr[ `FLT_Q_FRSTDW_BE_RANGE       ] = flt_q_first_be[3:0];             // completion hdr &  TRGT0 control
    flt_q_compressed_hdr[ `FLT_Q_LSTDW_BE_RANGE        ] = flt_q_last_be[3:0];              // TRGT1 and cpl_gen control
    flt_q_compressed_hdr[ `FLT_Q_ADDR_RANGE            ] = flt_q_addr[FLT_Q_ADDR_WIDTH-1:0];// completion hdr &  TRGT0 control
    flt_q_compressed_hdr[ `FLT_Q_FUNC_NMBR_RANGE       ] = flt_q_func_num[PF_WD-1:0];       // for cfg transaction only
    flt_q_compressed_hdr[ `FLT_Q_CPL_STATUS_RANGE      ] = flt_q_cpl_status[2:0];           // completion hdr element
    flt_q_compressed_hdr[ `FLT_Q_ROM_IN_RANGE_RANGE    ] = flt_q_rom_req_in_range;          // TRGT0 control
    flt_q_compressed_hdr[ `FLT_Q_IO_REQ_IN_RANGE_RANGE ] = flt_q_io_req_in_range;           // TRGT0 control
    flt_q_compressed_hdr[ `FLT_Q_IN_MEMBAR_RANGE_RANGE ] = flt_q_in_membar_range;           // TRGT0 control

    flt_q_compressed_hdr[ `FLT_Q_DESTINATION_RANGE     ] = flt_q_destination[1:0];          // Q DEMUX control
    flt_q_compressed_hdr[ `FLT_Q_CPL_LAST_RANGE        ] = flt_q_cpl_last;                  // CPL Control

    flt_q_compressed_hdr[ `FLT_Q_BYTE_CNT_RANGE        ] = flt_q_rcvd_tlp_byte_cnt;         // CPL HDR
    flt_q_compressed_hdr[ `FLT_Q_CMPLTR_ID_RANGE       ] = flt_q_cplid;                     // CPL HDR
    flt_q_compressed_hdr[ `FLT_Q_BCM_RANGE             ] = flt_q_cpl_bcm;                   // CPL HDR
    flt_q_compressed_hdr[ `FLT_Q_CPL_LOWER_ADDR_RANGE  ] = flt_q_rcvd_tlp_low_addr;         // CPL LOWER ADDR

    if (l_flt_q_tlp_type[CPL_TYPE])
    begin
        // NOTE THE FOLLOWING ASSIGNMENTS  OVERRIDING storage for  CPL TLPs
        flt_q_compressed_hdr[ `FLT_Q_REQID_RANGE       ] = flt_q_cpl_reqid;                 // CPL HDR REQID
        flt_q_compressed_hdr[ `FLT_Q_TAG_RANGE         ] = flt_q_rcvd_cpl_tlp_tag;          // CPL_HDR TAG
        if (!flt_q_reserved_status)
            flt_q_compressed_hdr[ `FLT_Q_CPL_STATUS_RANGE      ] = flt_q_rcvd_cpl_status;
        else
            flt_q_compressed_hdr[ `FLT_Q_CPL_STATUS_RANGE      ] = `UR_CPL_STATUS;  // pcie spec1.0a, 2.3.2:  treat reserved rcvd cpl_status as UR
    end
end


// ----------------------------------------------------------------
// functions
// ----------------------------------------------------------------

// Function to convert from a traffic class to vc number
function automatic [2:0] vc_from_tc;
    input   [23:0]  cfg_tc_struc_vc_map;  // TC to VC Structure mapping
    input   [2:0]   tc;             // Traffic class
    begin

        case  (tc)
            3'b000:     vc_from_tc = cfg_tc_struc_vc_map[ 2: 0];
            3'b001:     vc_from_tc = cfg_tc_struc_vc_map[ 5: 3];
            3'b010:     vc_from_tc = cfg_tc_struc_vc_map[ 8: 6];
            3'b011:     vc_from_tc = cfg_tc_struc_vc_map[11: 9];
            3'b100:     vc_from_tc = cfg_tc_struc_vc_map[14:12];
            3'b101:     vc_from_tc = cfg_tc_struc_vc_map[17:15];
            3'b110:     vc_from_tc = cfg_tc_struc_vc_map[20:18];
            3'b111:     vc_from_tc = cfg_tc_struc_vc_map[23:21];
        endcase // case
    end
endfunction // vc_from_tc


// Returns the segment number for a given vc and type.
function automatic [SEG_WIDTH-1:0] Get_seg_num;
input [2:0] vc;
input [1:0] pkt_type;

begin
    Get_seg_num = 0;


    case ({vc, pkt_type})
        5'b00000:   Get_seg_num =  0;
        5'b00001:   Get_seg_num =  1;
        5'b00010:   Get_seg_num =  2;
        default :   Get_seg_num = 0;
    endcase
end
endfunction




// Function to convert from a traffic class to a one-hot Q select
function automatic [NVC-1:0] q_select_from_tc;
    input   [23:0]  cfg_tc_struc_vc_map;  // TC to VC Structure mapping
    input   [2:0]   tc;             // Traffic class
    reg     [2:0]   vc;
    reg     [7:0]   full_NVC_q_select;
    begin

        case  (tc)
            3'b000:     vc = cfg_tc_struc_vc_map[ 2: 0];
            3'b001:     vc = cfg_tc_struc_vc_map[ 5: 3];
            3'b010:     vc = cfg_tc_struc_vc_map[ 8: 6];
            3'b011:     vc = cfg_tc_struc_vc_map[11: 9];
            3'b100:     vc = cfg_tc_struc_vc_map[14:12];
            3'b101:     vc = cfg_tc_struc_vc_map[17:15];
            3'b110:     vc = cfg_tc_struc_vc_map[20:18];
            3'b111:     vc = cfg_tc_struc_vc_map[23:21];
        endcase // case

        case  (vc)
            3'b000:     full_NVC_q_select  = 8'b00000001;
            3'b001:     full_NVC_q_select  = 8'b00000010;
            3'b010:     full_NVC_q_select  = 8'b00000100;
            3'b011:     full_NVC_q_select  = 8'b00001000;
            3'b100:     full_NVC_q_select  = 8'b00010000;
            3'b101:     full_NVC_q_select  = 8'b00100000;
            3'b110:     full_NVC_q_select  = 8'b01000000;
            3'b111:     full_NVC_q_select  = 8'b10000000;
        endcase // case
        q_select_from_tc = full_NVC_q_select[NVC-1:0];
    end
endfunction // q_select_from_tc

function automatic [NF-1:0] route_error_to_func;
    input set_error_signal;
    input [PF_WD-1:0] function_dest;
    integer i;
    begin
        route_error_to_func = 0;
        if (function_dest  < NF)
            for (i=0; i<NF; i=i+1) begin
                if(i==function_dest)
                    route_error_to_func[i] = set_error_signal;
            end
        else // function_dest >= NF
            route_error_to_func = {NF{set_error_signal}};
    end
endfunction


`ifndef SYNTHESIS
wire    [8*5:0]     RADM_Q_DEST;
wire    [8*9:0]     RADM_Q_VALID_TYPE;
wire    [8*3:0]     RADM_Q_TLP_TYPE;
assign  RADM_Q_DEST             =  ( flt_q_destination == `FLT_DESTINATION_TRASH ) ? "trash"     :
                                   ( flt_q_destination == `FLT_DESTINATION_TRGT0 ) ? "TRGT0"     :
                                   ( flt_q_destination == `FLT_DESTINATION_TRGT1 ) ? "TRGT1"     :
                                   ( flt_q_destination == `FLT_DESTINATION_CPL   ) ? "CPL"       : "bogus";

assign  RADM_Q_VALID_TYPE       =  ( flt_q_valid_type  == `FLT_VALID_NP_TYPE     ) ? "val_NP"    :
                                   ( flt_q_valid_type  == `FLT_VALID_P_TYPE      ) ? "val_P"     :
                                   ( flt_q_valid_type  == `FLT_VALID_UR_NP_TYPE  ) ? "val_UR_NP" :
                                   ( flt_q_valid_type  == `FLT_VALID_UR_P_TYPE   ) ? "val_UR_P"  : "----";


assign  RADM_Q_TLP_TYPE         =  ( l_flt_q_tlp_type == 3'b001 ) ? "P"  :
                                   ( l_flt_q_tlp_type == 3'b010 ) ? "NP" :
                                   ( l_flt_q_tlp_type == 3'b100 ) ? "CPL":
                                   ( l_flt_q_tlp_type == 3'b000 ) ? "---": "BGS";
`endif // SYNTHESIS

endmodule
