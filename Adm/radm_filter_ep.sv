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
// ---    $DateTime: 2020/09/11 01:49:10 $
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_filter_ep.sv#14 $
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

 
 module radm_filter_ep (
// ---- inputs ---------------
    core_clk,
    radm_clk_ug,
    core_rst_n,

    app_req_retry_en,
    app_pf_req_retry_en,
    cfg_bar_is_io,
    cfg_io_match,                                       // timed with flt_q time domain.
    cfg_config_above_match,
    cfg_bar_match,                                      // timed with flt_q time domain.
    cfg_rom_match,                                      // timed with flt_q time domain.
    cfg_tc_struc_vc_map,
    cfg_filter_rule_mask,
    cfg_rcb_128,
    cfg_max_func_num,
    pm_radm_block_tlp,

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
    ur_ca_mask_4_trgt1,
    cfg_target_above_config_limit,
    cfg_cfg_tlp_bypass_en,
    upstream_port,
    rtlh_radm_ant_addr,
    rtlh_radm_ant_rid,
    cpl_mlf_err,
    flt_q_cpl_abort,
    flt_q_cpl_last,
    cpl_ur_err,
    cpl_ca_err,
    unexpected_cpl_err,
    vendor_msg_id_match,
    target_mem_map,
    target_rom_map,



    cfg_pbus_num,
    cfg_pbus_dev_num,

// ---- outputs ---------------
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
    radm_slot_pwr_limit,
    radm_pm_asnak,
    radm_pm_pme,
    radm_pm_turnoff,
    radm_pm_to_ack,
    radm_msg_unlock,
    radm_vendor_msg,
    radm_rcvd_tlp_req_id,
    radm_unexp_cpl_err,
    radm_rcvd_cpl_ca,
    radm_rcvd_cpl_ur,
    cpl_tlp,
    flt_dwlenEq0,
    tlp_poisoned,
    flt_q_rcvd_cpl_tlp_tag,
    cpl_status,
    radm_snoop_upd,
    radm_snoop_bus_num,
    radm_snoop_dev_num
);

localparam TAG_SIZE             = `CX_TAG_SIZE;

parameter INST                  = 0;                    // The uniquifying parameter for each port logic instance.
parameter FLT_NUM               = 0;                    // Filter Number. Used to identify filter when operating in parallel with another filter
parameter NB                    = `CX_NB;               // Number of symbols (bytes) per clock cycle
parameter NW                    = `CX_NW;               // Number of 32-bit dwords handled by the datapath each clock.
parameter NVC                   = `CX_NVC;              // Number of virtual channels
parameter NF                    = `CX_NFUNC;            // Number of functions
localparam PF_WD                = `CX_NFUNC_WD;        // Number of bits needed to address the physical functions
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

parameter ADDR_TRANSLATION_SUPPORT =  0 ;

// change parameter name  ADDR_PAR_WD to a more meaningfull one since now it
// covers the complete header
parameter ADDR_PAR_WD           = `CX_RAS_PCIE_HDR_PROT_WD;

// protection width for compressed header 
parameter FLT_OUT_PROT_WD = `CX_FLT_OUT_PROT_WD;

// CPL parameters
parameter L2N_INTFC             = 1;                    // Number of bits for application interface ID
parameter FLT_Q_ADDR_WIDTH      = `FLT_Q_ADDR_WIDTH;

// Segbuf parameters
parameter SEG_WIDTH             = `CX_SEG_WIDTH;
parameter SNOOP_VPD_WD          = `CX_SNOOP_VPD_WD;

parameter BUSNUM_WD = `CX_BUSNUM_WD;
parameter DEVNUM_WD = `CX_DEVNUM_WD;
parameter PIPE_VF_INDEX = 0 ;
parameter PIPE_VF_INDEX_WIDTH = PF_WD +3 +3 + 8 // func_num + in_membar_range + in_io_range + bar_is_io
 // in_vf_membar_range + mem_vf_num
                                 ;
parameter PIPE_CFG_WIDTH = (6*NF) + (6*NF) + NF + 1 //cfg_bar_match + cfg_bar_is_io + cfg_rom_match + coerce_cfg_tlp_to_trgt1
                           ;
parameter CX_ELBI_NW = `CX_LBC_NW;   // number of DWs which can be accepted on ELBI; corresponds to max allowable Length field to which the ELBI is limited.



localparam ATTR_WD = `FLT_Q_ATTR_WIDTH;
localparam GATING_CTRL_PATH_WD = 3*NVC; // [NVC-1:0]  l_flt_q_hv, l_flt_q_dv, l_flt_q_eot   


input                   core_clk;                       // Core clock
input                   radm_clk_ug;                    // ungated clock used for anticipated rid and addr from rtlh
input                   core_rst_n;                     // Core system reset
input                   app_req_retry_en;               // Allow application to enable LBC to return request retry status
                                                        // to all configuration accesses
input   [NF-1:0]        app_pf_req_retry_en;            // Allow application to enable LBC to return request retry status, per PF Function
                                                        // to all configuration accesses
input   [(NF*6)-1:0]    cfg_bar_is_io;                  // indication that tlp is within MEM BAR, which is IO space
input   [NF-1:0]        cfg_io_match;                   // TIED low for EP
input   [NF-1:0]        cfg_config_above_match;         // configuaration access belongs to the above our customer set address limit so that target1 interface will be the detination of the configuration rd/wr.
input   [NF-1:0]        cfg_rom_match;                  // indication that tlp is within a ROM BAR
input   [(NF*6)-1:0]    cfg_bar_match;                  // indication that tlp is within a MEM BAR
input   [23:0]          cfg_tc_struc_vc_map;            // TC to VC Structure mapping
input   [N_FLT_MASK-1:0]cfg_filter_rule_mask;           // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
input                   cfg_rcb_128;
input   [PF_WD-1:0]     cfg_max_func_num;               // (PL) Highest accepted function number
input   [NF-1:0]        pm_radm_block_tlp;              // when this signal is active, only CFG/MSG are valid TLP's


input                   rtlh_radm_hv;                   // Header from TLP alignment block is valid (Start of packet)
input   [127+ADDR_PAR_WD:0]  rtlh_radm_hdr;             // 128-bit packet header
input                   rtlh_radm_dv;                   // Data from TLP alignment block is valid
input   [DW+DATA_PAR_WD-1:0] rtlh_radm_data;            // 128-bit packet data
input   [NW-1:0]        rtlh_radm_dwen;                 // DWord Enable for Data Interface.
input                   rtlh_radm_eot;                  // Indicate end of packet
input                   rtlh_radm_dllp_err;             // Recall packet (Malformed TLP, etc.)
input                   rtlh_radm_ecrc_err;             // Recall packet (Malformed TLP, etc.)
input                   rtlh_radm_malform_tlp_err;      // Recall packet (Malformed TLP, etc.)
input                   rtlh_radm_parerr;

input   [63:0]                  rtlh_radm_ant_addr;    // anticipated address (1 clock earlier)
input   [15:0]                  rtlh_radm_ant_rid;     // anticipated RID (1 clock earlier)
input                   default_target;                 // when asserted, it enables the lbc access to application registers
input                   ur_ca_mask_4_trgt1;             // when asserted, mask the UR/CA errors and allow the TLP to be passed
input   [1:0]           cfg_target_above_config_limit;  // TARGET_ABOVE_CONFIG_LIMIT_REG
input                   cfg_cfg_tlp_bypass_en;// CFG_TLP_BYPASS_EN_REG
input                   upstream_port;
input                   cpl_mlf_err;
input                   flt_q_cpl_abort;
input                   flt_q_cpl_last;
input                   cpl_ur_err;
input                   cpl_ca_err;
input                   unexpected_cpl_err;
input                   vendor_msg_id_match;
input   [(NF*6)-1:0]    target_mem_map;             // Each bit of this vector indicates which target receives memory transactions for that bar #

input   [NF-1:0]        target_rom_map;             // Each bit of this vector indicates which target receives rom    transactions for that bar #


input   [BUSNUM_WD-1:0] cfg_pbus_num;
input [DEVNUM_WD-1:0] cfg_pbus_dev_num;




//--------------------- outputs --------------------// Clock alignment


output  [63:0]          flt_cdm_addr;               // rtlh_flt                     //-- 64 bit tlp address sent to CDM for BAR matching
output  [DW+DATA_PAR_WD-1:0] flt_q_data;            // flt_q + CX_FLT_Q_REGOUT      //-- tlp data sent to queue
output                  flt_q_dllp_abort;           // flt_q + CX_FLT_Q_REGOUT      //-- Recall packet (Malformed TLP, etc.)
output  [NVC-1:0]       flt_q_dv;                   // flt_q + CX_FLT_Q_REGOUT      //-- 1 when flt_q_data   is valid
output  [NW-1:0]        flt_q_dwen;                 // flt_q + CX_FLT_Q_REGOUT      //-- DWord Enable for Data Interface.
output                  flt_q_ecrc_err;             // flt_q + CX_FLT_Q_REGOUT      //--  -> radm_q
output                  flt_q_parerr;
output  [NVC-1:0]       flt_q_eot;                  // flt_q + CX_FLT_Q_REGOUT      //-- Indicate end of packet
output  [HW+FLT_OUT_PROT_WD-1:0] flt_q_header;          // flt_q + CX_FLT_Q_REGOUT      //-- tlp compressed header sent to queue

output  [NVC-1:0]       flt_q_hv;                   // flt_q + CX_FLT_Q_REGOUT      //-- 1 when flt_q_header is valid
output                  flt_q_tlp_abort;            // flt_q + CX_FLT_Q_REGOUT      //-- Recall packet (Malformed TLP, etc.)
output  [2:0]           flt_q_tlp_type;             // flt_q + CX_FLT_Q_REGOUT      //-- one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ flt_q_hv
output  [SEG_WIDTH-1:0] flt_q_seg_num;              // flt_q + CX_FLT_Q_REGOUT      //-- segment number
output  [2:0]           flt_q_vc;                   // flt_q + CX_FLT_Q_REGOUT      //-- VC # of the current packet
output  [NF-1:0]        radm_rcvd_cpl_ca;           // flt_q + CX_ERROR_LOG_REGOUT  //-- CPL -> cdm Received CPL completion abort
output  [NF-1:0]        radm_rcvd_cpl_ur;           // flt_q + CX_ERROR_LOG_REGOUT  //-- CPL -> cdm Received CPL Unsupported request error
output  [NF-1:0]        radm_ecrc_err;              // flt_q + CX_ERROR_LOG_REGOUT  //-- Received ECRC error (in absence of dllp error)
output  [127:0]         radm_hdr_log;               // flt_q + CX_ERROR_LOG_REGOUT  //-- tlp header for logging errors
output  [NF-1:0]        radm_hdr_log_valid;         // flt_q + CX_ERROR_LOG_REGOUT  //-- strobe for radm_hdr_log
output  [NF-1:0]        radm_mlf_tlp_err;           // flt_q + CX_ERROR_LOG_REGOUT  //-- Received malformed error
output  [63:0]          radm_msg_payload;           // flt_q                        //-- Received msg data associated with slot limit
output                  radm_pm_asnak;              // flt_q                        //-- Received PM_AS_NAK
output                  radm_pm_pme;                // constant                     //-- Received PM_PME MSG
output                  radm_pm_to_ack;             // constant                     //-- Received PM_TO_ACK
output                  radm_pm_turnoff;            // flt_q                        //-- Received PM_TURNOFF
output  [NF-1:0]        radm_rcvd_req_ca;           // flt_q + CX_ERROR_LOG_REGOUT  //-- Received completion abort (EP's CA generated for dwlen>1 )
output  [NF-1:0]        radm_rcvd_cpl_poisoned;     // flt_q + CX_ERROR_LOG_REGOUT  //-- Received posted poisoned cpl tlp request
output  [15:0]          radm_rcvd_tlp_req_id;       // flt_q                        //-- Received Requester ID
output  [NF-1:0]        radm_rcvd_req_ur;           // flt_q + CX_ERROR_LOG_REGOUT  //-- Received unsupported Request
output  [NF-1:0]        radm_rcvd_wreq_poisoned;    // flt_q + CX_ERROR_LOG_REGOUT  //-- Received posted poisoned wr request
output  [NF-1:0]        radm_unexp_cpl_err;         // flt_q + CX_ERROR_LOG_REGOUT  //-- CPL -> cdm    timeout CPL tc
output                  radm_vendor_msg;            // flt_q                        //-- N/A for EP
output                  radm_msg_unlock;            // flt_q                        //-- Received unlock message
output                  radm_slot_pwr_limit;        // flt_q                        //-- Received Slot power limit MSG
output                  cpl_tlp;                    // rtlh_flt                     //--
output                  tlp_poisoned;               // rtlh_flt                     //--
output                  flt_dwlenEq0;               // rtlh_flt                     //--
output  [TAG_SIZE-1:0]  flt_q_rcvd_cpl_tlp_tag;     // rtlh_flt                     //--
output  [2:0]           cpl_status;                 // rtlh_flt                     //--


// to support the max allowed func number. output to notify the CMD or PM module that a configuration
// received with the bus and device number asserted on radm_snoop_bus_num and radm_snoop_devnum
output  [SNOOP_VPD_WD -1:0] radm_snoop_upd;         // flt_q                        //--
output  [7:0]           radm_snoop_bus_num;         // flt_q                        //--
output  [4:0]           radm_snoop_dev_num;         // flt_q                        //--

wire    [HEW-1:0]       hdr_dw1;                    // sync with rtlh time domain
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
wire                    flt_q_ecrc_discard;

wire                    p_tlp;
wire                    cpl_tlp;
wire                    flt_q_invalid_tlp;
wire                    flt_q_pcie_format;
wire                    flt_q_pcie_valid_tc;
wire                    flt_q_np_req4trgt1;
wire    [9:0]           dw_len;
wire                    tlp_poisoned;
wire    [ATTR_WD-1:0]   attr;
wire                    tlp_w_pyld;
wire                    td;
wire    [2:0]           tc;
wire    [3:0]           first_be;
wire    [3:0]           last_be;
wire                    msg_is_slotpwr;
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
reg                     flt_q_cpl_mlf_err;
reg                     flt_q_msg_mlf_err;
wire                    radm_vendor_msg;
reg     [HEW-1:0]       flt_q_hdr_dw1;                  // sync with q time domain
reg     [HEW-1:0]       flt_q_hdr_dw2;
reg     [HEW-1:0]       flt_q_hdr_dw3;
reg     [HEW-1:0]       flt_q_hdr_dw4;
wire                    flt_q_io_req_in_range;
wire     [2:0]           raw_flt_q_in_membar_range;
wire    [2:0]           flt_q_in_membar_range;
wire                    flt_q_mem_req_in_range;
wire                    flt_q_rom_req_in_range;

reg     [DW+DATA_PAR_WD-1:0] l_flt_q_data;                // flt_q  //tlp data sent to queue
// aux bus to decouple the internal wiring from the use of RAS. If RAS is used chk_l_flt_q_data holds the 
// value of l_flt_q_data at the output of bus_protect_chk. If RAS is not used chk_l_flt_q_data is just a 
// feedthrough
wire     [DW+DATA_PAR_WD-1:0] chk_l_flt_q_data;          

reg                     l_flt_q_dllp_abort;               // flt_q  //Recall packet (Malformed TLP, etc.)
wire    [NVC-1:0]       l_flt_q_dv;                       // flt_q  //1 when flt_q_data   is valid
reg     [NW-1:0]        l_flt_q_dwen;                     // flt_q  //DWord Enable for Data Interface.
reg                     l_flt_q_ecrc_err;                 // flt_q  // -> radm_q
wire    [NVC-1:0]       l_flt_q_eot;                      // flt_q  //Indicate end of packet
wire    [HW+FLT_OUT_PROT_WD-1:0] l_flt_q_header;          // flt_q  //tlp compressed header sent to queue
wire    [HW+FLT_OUT_PROT_WD-1:0] l_flt_q_header_d;        // flt_q  //tlp compressed header sent to queue
wire    [HW+FLT_OUT_PROT_WD-1:0] chk_l_flt_q_header_d;    // flt_q  //tlp compressed header sent to queue, output of bus_protect_chk if RAS is enabled

// decouple the internal header wiring from the use of RAS. If RAS is used then chk_rtlh_radm_hdr is the output of
// bus_protect_chk module. Without RAS it's just a feedthrough of rtlh_radm_hdr
wire    [127+ADDR_PAR_WD:0]  chk_rtlh_radm_hdr;           // 128-bit packet header

wire    [NVC-1:0]       l_flt_q_hv;                       // flt_q  //1 when l_flt_q_header is valid
wire                    l_flt_q_tlp_abort;                // flt_q  //Recall packet (Malformed TLP, etc.)
reg     [2:0]           l_flt_q_tlp_type;                 // flt_q  //one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ l_flt_q_hv
reg                     l_flt_q_parerr;
wire                    int_flt_q_parerr;                 // error indication at the output of the delay module
reg     [SEG_WIDTH-1:0] l_flt_q_seg_num;                  // flt_q  //segment number
reg     [2:0]           l_flt_q_vc;                       // flt_q  //VC # of the current packet
wire    [63:0]          radm_msg_payload;               // flt_q //Received msg data associated with slot limit
reg                     radm_pm_asnak;                  // flt_q //Received PM_AS_NAK
reg                     radm_pm_turnoff;                // flt_q //Received PM_TURNOFF
wire    [15:0]          radm_rcvd_tlp_req_id;           // flt_q //Received Requester ID
reg                     radm_msg_unlock;                // flt_q //Received unlock message
reg                     radm_slot_pwr_limit;            // flt_q //Received Slot power limit MSG


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
reg                     l_set_outrange_req_ur;
wire    [127:0]         l_radm_hdr_log;
wire                    set_radm_rcvd_cpl_ca;
wire                    set_radm_rcvd_cpl_ur;
wire                    set_radm_ecrc_err;
wire                    set_radm_hdr_log_valid;
wire                    set_radm_mlf_tlp_err;
wire                    set_radm_rcvd_req_ca;
wire                    set_radm_rcvd_cpl_poisoned;
wire                    set_radm_rcvd_req_ur;
wire                    set_outrange_req_ur;
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
wire                    flt_q_memwr_req;
wire                    flt_q_def_memwr_req;
wire                    flt_q_atomic_fetchadd;
wire                    flt_q_atomic_swap;
wire                    flt_q_atomic_cas;
wire                    flt_q_cfg0rd_req;
wire                    flt_q_cfg0wr_req;
wire                    flt_q_cfg1rd_req;
wire                    flt_q_cfg1wr_req;
wire                    flt_q_cfg_req;
wire                    flt_q_cfg1_req;
wire                    flt_q_atomic_op;
wire                    flt_q_mem_req;
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
wire    [PF_WD-1:0]  flt_q_cfg_func_num;
wire    [PF_WD-1:0]  flt_q_func_num;
wire    [PF_WD-1:0]  raw_flt_q_func_num;
wire    [PF_WD-1:0]  raw_func_num_unreg;
reg     [PF_WD-1:0]  raw_mem_func_num;
wire    [PF_WD-1:0]  flt_q_func_num_d;
wire    [PF_WD-1:0]  pf;
wire    [PF_WD-1:0]     pfvf_func_num;
wire    [3:0]           flt_q_ext_reg_num;
wire    [5:0]           flt_q_reg_num;
wire    [63:0]          flt_q_addr;
wire    [63:0]          flt_q_addr_int;
wire    [7:0]           flt_q_addr_byte0;
wire    [7:0]           flt_q_addr_byte1;
wire    [7:0]           flt_q_addr_byte2;
wire    [7:0]           flt_q_addr_byte3;
wire    [7:0]           flt_q_addr_byte4;
wire    [7:0]           flt_q_addr_byte5;
wire    [7:0]           flt_q_addr_byte6;
wire    [7:0]           flt_q_addr_byte7;
wire    [6:0]           flt_q_lower_addr;
wire    [9:0]           flt_q_dw_len;
reg                     flt_q_handle_flush;
reg     [NVC-1:0]       flt_q_vc_select;
reg     [1:0]           flt_q_byte_addr;
wire                    flt_q_valid_np;
wire                    flt_q_valid_p;
wire                    flt_q_valid_ur_np;
wire                    flt_q_valid_ur_p;
wire                    flt_q_ur_np_wo_poisn;
wire                    flt_q_ur_p_wo_poisn;
wire                    flt_q_valid_ca_np;
wire                    flt_q_valid_ca_p;
wire    [2:0]           flt_q_actual_cpl_status;
wire    [2:0]           flt_q_cpl_status;
wire                    flt_q_tlp_is_msg;
reg                     int_flt_q_invalid_msg;
reg                     int_flt_q_vendor_msg_id_match;
wire                    flt_q_invalid_msg;
wire                    flt_q_vendor_msg_id_match;  
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
wire                    radm_pm_pme;
assign  radm_pm_pme     = 1'b0;                         // PME should not be received by endpoint device

wire                    radm_pm_to_ack;
assign  radm_pm_to_ack  = 1'b0;                         // to ack should not be received by EP

reg                     rtlh_dllp_err_d  ;
reg                     flt_q_unqual_dv;
reg                     flt_q_unqual_hv;
reg                     flt_q_unqual_eot;


// CPL declarations


wire                    flt_q_outrange_ur;
reg                     flt_q_cpl_rcvd_ur;
reg                     flt_q_cpl_rcvd_ca;
reg                     l_flt_q_unexp_cpl_err;
wire                    flt_q_unexp_cpl_err;
reg     [1:0]           target_acquisition;             // dynamic tlp steering, depending on bar mapping, 1-trgt1; 0-trgt0;
wire                    rom_trgt_map;
wire                    mem_trgt_map;
wire                    io_trgt_map;
wire                    pm_block_tlp;
wire                    flt_q_io_req_range;
wire                    flt_q_pm_radm_block_tlp;
wire                    flt_q_poisoned_discard;
wire                    flt_q_func_mismatch_tlp;
wire                    flt_q_locked_rd_tlp;
wire                    flr_in_progress;
wire                    flr_pf_in_progress;
wire                    flr_vf_in_progress;

wire                    coerce_cfg_tlp_to_trgt1;
reg                     coerce_cfg_tlp_to_trgt1_int;

wire [DEVNUM_WD-1:0] cfg_pbus_dev_num;

wire rtlh_mem_req;
wire rtlh_io_req;
wire rtlh_cfg_req;
wire rtlh_is_msg;
wire [PF_WD-1:0] rtlh_cfg_func_num;
wire [2:0] rtlh_req_id;

wire  [(NF*6)-1:0]    cfg_bar_is_io_reg;                  // indication that tlp is within MEM BAR, which is IO space
wire  [NF-1:0]        cfg_io_match_reg;                   // TIED low for EP
wire  [NF-1:0]        cfg_rom_match_reg;                  // indication that tlp is within a ROM BAR
wire  [(NF*6)-1:0]    cfg_bar_match_reg;                  // indication that tlp is within a MEM BAR

//ERROR INJECTION Done Signals



wire                  target_ca;              // target completion abort; asserted if target 0 - ELBI limitations not met.

wire                    tmp_mlf_err;
wire [7:0]              tmp_mlf_err_ptr;
reg  [7:0]              flt_q_rtlh_abort_ptr;
wire [7:0]              rtlh_radm_malform_tlp_err_ptr = 8'h00;

wire coerce_cfg_tlp_to_trgt1_en;  // Target destination control signal; allows Cfg requests to reach Target1.




wire   app_req_retry_en_tmp;
reg                   int_app_req_retry_en;
reg   [NF-1:0]        int_app_pf_req_retry_en;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        int_app_req_retry_en    <= #TP 0;
    else
        int_app_req_retry_en    <= #TP app_req_retry_en;

always @(posedge core_clk or negedge core_rst_n)
begin: APP_PF_REQ_RETRY
integer j;
    if (!core_rst_n) begin
          int_app_pf_req_retry_en         <= #TP 0;
    end else begin
        for (j=0; j<NF; j=j+1) begin
          int_app_pf_req_retry_en[j]      <= #TP app_pf_req_retry_en[j];
        end // for j
    end
end


assign app_req_retry_en_tmp    = int_app_req_retry_en || ((raw_flt_q_func_num < NF) && int_app_pf_req_retry_en[raw_flt_q_func_num])
 ;

//
// [ ----------------  sync with rtlh time domain  -----------------------]
//
// aux wire to indicate a protection error has been detected at the output of the delay module
// if the delay is 0 then there is no check and hence no error
wire l_flt_q_header_d_prot_err; 

assign flt_q_parerr = int_flt_q_parerr | l_flt_q_header_d_prot_err;


  assign chk_rtlh_radm_hdr = rtlh_radm_hdr;

assign  hdr_dw1                 = chk_rtlh_radm_hdr[31:0];
assign  hdr_dw2                 = chk_rtlh_radm_hdr[63:32];
assign  hdr_dw3                 = chk_rtlh_radm_hdr[95:64];
assign  hdr_dw4                 = chk_rtlh_radm_hdr[127:96];

assign  hdr_type                = hdr_dw1[4:0];
assign  fmt                     = hdr_dw1[6:5];
assign  tlpmsg                  = hdr_dw1[6:3];
assign  attr                    = hdr_dw1[21:20];
assign  tlp_w_pyld              = hdr_dw1[6]; // Supported PCIe format only

assign  tlp_is_msg              = ((tlpmsg          == `MSG_4) || (tlpmsg         == `MSGD_4)) && pcie_format;
assign  p_tlp                   = (((({fmt,hdr_type} == `MWR32) || ({fmt,hdr_type} == `MWR64)) && pcie_format) || tlp_is_msg)
                                ;
assign  cpl_tlp                 = (({fmt,hdr_type} == `CPLLK) || ({fmt,hdr_type} == `CPLDLK) ||
                                   ({fmt,hdr_type} == `CPL)   || ({fmt,hdr_type} == `CPLD)) && pcie_format;

assign  tlp_type [P_TYPE]       = p_tlp;               //sync with rtlh time domain
assign  tlp_type [NP_TYPE]      = !p_tlp & !cpl_tlp;
assign  tlp_type [CPL_TYPE]     = cpl_tlp;             //sync with rtlh time domain

assign rtlh_mem_req = pcie_format &&
                     ({fmt,hdr_type} == `MWR32        || {fmt,hdr_type}  == `MWR64        ||
                      {fmt,hdr_type} == `MRD32        || {fmt,hdr_type}  == `MRD64        ||
                      {fmt,hdr_type} == `MRDLK32      || {fmt,hdr_type}  == `MRDLK64      ||
                      {fmt,hdr_type} == `FETCHADD32   || {fmt, hdr_type} == `FETCHADD64   ||
                      {fmt,hdr_type} == `SWAP32       || {fmt, hdr_type} == `SWAP64       ||
                      {fmt,hdr_type} == `CAS32        || {fmt, hdr_type} == `CAS64 );


assign rtlh_io_req  = pcie_format && 
                     ({fmt,hdr_type} == `IOWR         || {fmt,hdr_type}  == `IORD);
assign rtlh_cfg_req = pcie_format &&
                     ({fmt,hdr_type}  == `CFGRD0      || {fmt,hdr_type}  == `CFGRD1        ||
                      {fmt,hdr_type}  == `CFGWR0      || {fmt,hdr_type}  == `CFGWR1);
assign rtlh_is_msg  = pcie_format &&
                     (hdr_dw1[6:3]   == `MSG_4        || hdr_dw1[6:3]    == `MSGD_4);

assign rtlh_cfg_func_num = hdr_dw3[(PF_WD-1)+8:8];

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
assign  td                      = hdr_dw1[23];
assign  tc                      = hdr_dw1[14:12];

assign  msg_is_slotpwr          = ((hdr_dw2[31:24] == `SET_SLOT_PWR_LIMIT) && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSGD_4) && !int_mlf_msg && pcie_format);
assign  msg_is_vendor_msg0      = ((hdr_dw2[31:24] == `VENDOR_TYPE0)       && ((hdr_type[2:0] == 3'b000) || (hdr_type[2:0] == 3'b010) || (hdr_type[2:0] == 3'b011) || (hdr_type[2:0] == 3'b100)) && ((tlpmsg == `MSG_4) || (tlpmsg == `MSGD_4)) && !int_mlf_msg && pcie_format);
assign  msg_is_vendor_msg1      = ((hdr_dw2[31:24] == `VENDOR_TYPE1)       && ((hdr_type[2:0] == 3'b000) || (hdr_type[2:0] == 3'b010) || (hdr_type[2:0] == 3'b011) || (hdr_type[2:0] == 3'b100)) && ((tlpmsg == `MSG_4) || (tlpmsg == `MSGD_4)) && !int_mlf_msg && pcie_format);

assign  first_be                = hdr_dw2[27:24];
assign  last_be                 = hdr_dw2[31:28];
assign  dwlenEq1                = (dw_len[0] & (!(|dw_len[9:1])));    // dw_len == 10'b01
assign  flt_dwlenEq0            = !(|dw_len);                         // dw_len == 10'b0

assign  msg_code                = ( hdr_dw2[31:24]);

assign  cpl_status              = hdr_dw2[23:21];
assign  rcvd_tlp_byte_cnt       = {hdr_dw2[19:16], hdr_dw2[31:24]};
assign  rcvd_cpl_tlp_tag        = hdr_dw3[23:16];
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
assign  flt_q_attr              = flt_q_hdr_dw1[21:20];
assign  flt_q_tc                = flt_q_hdr_dw1[14:12];
assign  flt_q_TAG               = flt_q_hdr_dw2[23:16];
assign  flt_q_REQID             = (flt_q_cpl_w_lock | flt_q_cpl_wo_lock) ? {flt_q_hdr_dw3[7:0],flt_q_hdr_dw3[15:8]} : {flt_q_hdr_dw2[7:0],flt_q_hdr_dw2[15:8]};
assign  flt_q_dw_len            = {flt_q_hdr_dw1[17:16], flt_q_hdr_dw1[31:24]};
assign  flt_q_type              = flt_q_hdr_dw1[4:0];
assign  flt_q_fmt               = flt_q_hdr_dw1[6:5];
assign  flt_q_cplid             = {flt_q_hdr_dw2[7:0],flt_q_hdr_dw2[15:8]};

assign  flt_q_tlpmsg            = flt_q_hdr_dw1[6:3];
assign  flt_q_tlp_is_msg        = (((flt_q_tlpmsg == `MSG_4) || (flt_q_tlpmsg == `MSGD_4)) && flt_q_pcie_format);

assign  flt_q_iord_req          = ( {flt_q_fmt, flt_q_type} == `IORD) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;  // check also that length field = 1
assign  flt_q_iowr_req          = ( {flt_q_fmt, flt_q_type} == `IOWR) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_locked_rd         = (({flt_q_fmt, flt_q_type} == `MRDLK32)      || ({flt_q_fmt, flt_q_type} == `MRDLK64)) && flt_q_pcie_format;
assign  flt_q_memrd_req         = (({flt_q_fmt, flt_q_type} == `MRD32)        || ({flt_q_fmt, flt_q_type} == `MRD64  )) && flt_q_pcie_format;
assign  flt_q_memwr_req         = (({flt_q_fmt, flt_q_type} == `MWR32)        || ({flt_q_fmt, flt_q_type} == `MWR64  )) && flt_q_pcie_format;
assign  flt_q_def_memwr_req     = 0;
assign  flt_q_atomic_fetchadd   = (({flt_q_fmt, flt_q_type} == `FETCHADD32)   || ({flt_q_fmt, flt_q_type} == `FETCHADD64  )) && flt_q_pcie_format;
assign  flt_q_atomic_swap       = (({flt_q_fmt, flt_q_type} == `SWAP32)       || ({flt_q_fmt, flt_q_type} == `SWAP64  )) && flt_q_pcie_format;
assign  flt_q_atomic_cas        = (({flt_q_fmt, flt_q_type} == `CAS32)        || ({flt_q_fmt, flt_q_type} == `CAS64  )) && flt_q_pcie_format;
assign  flt_q_cfg0rd_req        = ( {flt_q_fmt, flt_q_type} == `CFGRD0) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_cfg0wr_req        = ( {flt_q_fmt, flt_q_type} == `CFGWR0) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_cfg1rd_req        = ( {flt_q_fmt, flt_q_type} == `CFGRD1) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_cfg1wr_req        = ( {flt_q_fmt, flt_q_type} == `CFGWR1) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
assign  flt_q_cfg_req           = (flt_q_cfg0rd_req || flt_q_cfg0wr_req  || flt_q_cfg1rd_req || flt_q_cfg1wr_req);
assign  flt_q_cfg1_req          = (flt_q_cfg1rd_req || flt_q_cfg1wr_req);
assign  flt_q_atomic_op         = (flt_q_atomic_fetchadd || flt_q_atomic_swap || flt_q_atomic_cas);
assign  flt_q_mem_req           = (flt_q_locked_rd || flt_q_memrd_req || flt_q_memwr_req || flt_q_def_memwr_req || flt_q_atomic_op);


assign  flt_q_cpl_w_lock        = (({flt_q_fmt,flt_q_type}  == `CPLLK)   ||  ({flt_q_fmt,flt_q_type} == `CPLDLK)) && flt_q_pcie_format;
assign  flt_q_cpl_wo_lock       = (({flt_q_fmt,flt_q_type}  == `CPL)     ||  ({flt_q_fmt,flt_q_type} == `CPLD))   && flt_q_pcie_format;

assign  flt_q_invalid_tlp       = !flt_q_iord_req & !flt_q_iowr_req & !flt_q_locked_rd & !flt_q_memrd_req
                                     & !flt_q_memwr_req & !flt_q_def_memwr_req & !flt_q_cfg0rd_req & !flt_q_cfg0wr_req & !flt_q_tlp_is_msg
                                     & !flt_q_cfg1rd_req & !flt_q_cfg1wr_req & !flt_q_cpl_w_lock & !flt_q_cpl_wo_lock
                                     & !flt_q_atomic_op;
  


assign  flt_q_np_rd             = ( flt_q_iord_req || flt_q_cfg0rd_req || flt_q_cfg1rd_req || flt_q_memrd_req || flt_q_locked_rd || flt_q_atomic_op);

assign  flt_q_func_mismatch     = (flt_q_cfg_func_num   > cfg_max_func_num);

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
//
//assign flt_q_np_req4trgt1        = (target_acquisition == `FLT_DESTINATION_TRGT1) && (( {flt_q_fmt,flt_q_type} != `CFGRD0) &&
//                                                                                   ( {flt_q_fmt,flt_q_type} != `CFGRD1) &&
//                                                                                   ( {flt_q_fmt,flt_q_type} != `CFGWR0) &&
//                                                                                   ( {flt_q_fmt,flt_q_type} != `CFGWR1));
//

assign  flt_q_addr_byte7        = (flt_q_addr64) ? flt_q_hdr_dw3[7:0]   : 8'h00;
assign  flt_q_addr_byte6        = (flt_q_addr64) ? flt_q_hdr_dw3[15:8]  : 8'h00;
assign  flt_q_addr_byte5        = (flt_q_addr64) ? flt_q_hdr_dw3[23:16] : 8'h00;
assign  flt_q_addr_byte4        = (flt_q_addr64) ? flt_q_hdr_dw3[31:24] : 8'h00;
assign  flt_q_addr_byte3        = (flt_q_addr64) ? flt_q_hdr_dw4[7:0]   : flt_q_hdr_dw3[7:0];
assign  flt_q_addr_byte2        = (flt_q_addr64) ? flt_q_hdr_dw4[15:8]  : flt_q_hdr_dw3[15:8];
assign  flt_q_addr_byte1        = (flt_q_addr64) ? flt_q_hdr_dw4[23:16] : flt_q_hdr_dw3[23:16];
assign  flt_q_addr_byte0        = (flt_q_addr64) ? flt_q_hdr_dw4[31:24] : flt_q_hdr_dw3[31:24];

assign  flt_q_addr = flt_q_addr_int;

assign  flt_q_lower_addr        = flt_q_memrd_req ? {flt_q_hdr_dw3[30:26], flt_q_byte_addr} : 7'b0;

assign  flt_q_actual_cpl_status =   (flt_q_valid_ur_np | flt_q_valid_ur_p | flr_in_progress)  ? `UR_CPL_STATUS :     // when it is invalid ur, it is
                                      (flt_q_valid_ca_np | flt_q_valid_ca_p) ? `CA_CPL_STATUS                                                                        // the CA status: 1. TRGT0 is the destination and more than 1 dword is
                                                              // being requested. This is a limitation of current LBC module.
                                                              // 2. when ecrc detected and it is non posted TLP
                                      : `SU_CPL_STATUS;


assign  flt_q_cpl_status        = (((int_flt_q_destination[1:0] == `FLT_DESTINATION_TRGT0) && app_req_retry_en_tmp && flt_q_cfg_req) ? `CRS_CPL_STATUS:
                                      ((int_flt_q_destination[1:0] == `FLT_DESTINATION_TRGT0) && app_req_retry_en_tmp) ? `UR_CPL_STATUS   :
                                      flt_q_actual_cpl_status);

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
// --------------------- snoop configuration access to obtain the bus and device number ------------------
reg     [SNOOP_VPD_WD -1:0]  radm_snoop_upd;   // output to notify the CMD or PM module that a configuration received with the bus and device number asserted on radm_snoop_bus_num and radm_snoop_devnum


always @(/*AUTOSENSE*/flt_q_cfg0wr_req or flt_q_poisoned_discard
         or flt_q_rtlh_abort or l_flt_q_ecrc_err or l_flt_q_eot
         or rtlh_dllp_err_d or flt_q_valid_np)
    radm_snoop_upd          = (|l_flt_q_eot) & !rtlh_dllp_err_d   & !flt_q_rtlh_abort & !l_flt_q_ecrc_err &  flt_q_cfg0wr_req & !flt_q_poisoned_discard & flt_q_valid_np;

wire    [7:0]           radm_snoop_bus_num;
wire    [4:0]           radm_snoop_dev_num;

assign  radm_snoop_bus_num      = flt_q_cpl_reqid[15:8];
assign  radm_snoop_dev_num      = flt_q_cpl_reqid[7:3];
// ---------------------------------------------------------------------------------------------------------


wire enable_mask_pois_if_trgt0_destination;
wire flt_q_mask_wreq_poisoned_reporting;
wire flt_q_mask_cpl_poisoned_reporting;
assign enable_mask_pois_if_trgt0_destination = !(cfg_filter_rule_mask[`CX_FLT_UNMASK_UR_POIS_TRGT0] && (target_acquisition == `FLT_DESTINATION_TRGT0));
assign flt_q_mask_wreq_poisoned_reporting = (cfg_filter_rule_mask[`CX_FLT_MASK_POIS_ERROR_REPORTING] & cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & (int_flt_q_destination == `FLT_DESTINATION_TRGT1));
assign flt_q_mask_cpl_poisoned_reporting  = cfg_filter_rule_mask[`CX_FLT_MASK_POIS_ERROR_REPORTING];

assign pf = flt_q_cfg_func_num;


// -----------------------------------------------------------------------------
// TLP destination calculation
// -----------------------------------------------------------------------------
always @(flt_q_first_be)
begin: DECODE_BYTE_ADDR
    casez(flt_q_first_be)
        4'b0000:     flt_q_byte_addr = 2'b00;
        4'b???1:     flt_q_byte_addr = 2'b00;
        4'b??10:     flt_q_byte_addr = 2'b01;
        4'b?100:     flt_q_byte_addr = 2'b10;
        4'b1000:     flt_q_byte_addr = 2'b11;
    endcase // casez(flt_q_first_be)
end

assign  io_trgt_map             = |(target_mem_map & cfg_bar_match_reg & (cfg_bar_is_io_reg));  //
assign  mem_trgt_map            = |(target_mem_map & cfg_bar_match_reg & (~cfg_bar_is_io_reg));  //
assign  rom_trgt_map            = |(target_rom_map & cfg_rom_match_reg);  //

// TLP Bypass feature. cfg_cfg_tlp_bypass_en is the value of register CFG_TLP_BYPASS_EN_REG.
// When cfg_cfg_tlp_bypass_en is set, the destination control signal coerce_cfg_tlp_to_trgt1 (from CONFIG_LIMIT_REG) is disabled. 
// If the top level application pin app_req_retry_en is asserted, the value of cfg_cfg_tlp_bypass_en is ignored.
assign coerce_cfg_tlp_to_trgt1_en = (!int_app_req_retry_en & cfg_cfg_tlp_bypass_en) | coerce_cfg_tlp_to_trgt1;


always@(/*AUTO SENSE*/default_target or flt_q_cfg_req
        or flt_q_io_req_in_range or flt_q_iord_req or flt_q_iowr_req
        or flt_q_mem_req_in_range
        or flt_q_mem_req or io_trgt_map
        or flt_q_rom_req_in_range or mem_trgt_map or rom_trgt_map
        or coerce_cfg_tlp_to_trgt1_en
        or cfg_target_above_config_limit

        )
begin
    //          if (!(flt_q_io_req_in_range || flt_q_mem_req_in_range || flt_q_rom_req_in_range))
    target_acquisition = `FLT_DESTINATION_TRASH;
    //          else
    if (flt_q_cfg_req)    begin
        if (coerce_cfg_tlp_to_trgt1_en)
            target_acquisition = cfg_target_above_config_limit;
        else
            target_acquisition = `FLT_DESTINATION_TRGT0;
    end
    else if (flt_q_iord_req || flt_q_iowr_req)    begin
        if (flt_q_io_req_in_range)
            if (io_trgt_map)
                target_acquisition  =  `FLT_DESTINATION_TRGT1;
            else
                target_acquisition  =  `FLT_DESTINATION_TRGT0;
        else  if (default_target)
            target_acquisition      =  `FLT_DESTINATION_TRGT1;
        else
            target_acquisition      =  `FLT_DESTINATION_TRGT0;
    end
    else if (flt_q_mem_req) begin // MEMORY (or ROM)
        if (flt_q_mem_req_in_range)
            if (mem_trgt_map)
                target_acquisition  =  `FLT_DESTINATION_TRGT1;
            else
                target_acquisition  =  `FLT_DESTINATION_TRGT0;
        else if (flt_q_rom_req_in_range)
            if (rom_trgt_map)
                target_acquisition  =  `FLT_DESTINATION_TRGT1;
            else
                target_acquisition  =  `FLT_DESTINATION_TRGT0;
        else if (default_target)
            target_acquisition      =  `FLT_DESTINATION_TRGT1;
        else
            target_acquisition      =  `FLT_DESTINATION_TRGT0;
    end    // Mem transactions
end




assign  flt_q_io_req_in_range   = |(cfg_bar_match_reg & cfg_bar_is_io_reg) ;
assign  flt_q_mem_req_in_range  = (|(cfg_bar_match_reg & (~cfg_bar_is_io_reg))) & flt_q_mem_req;
assign  flt_q_rom_req_in_range  = (|cfg_rom_match_reg) & flt_q_mem_req;

reg  [PF_WD-1:0]  raw_io_func_num;
wire [2:0]        in_membar_range;
reg  [2:0]        in_membar_range_unreg;
reg  [2:0]        in_iobar_range_unreg;
wire [2:0]        in_iobar_range;
reg  [PF_WD-1:0]  raw_cfg_func_num;
wire [PF_WD-1:0]  pf_to_match;
reg  [7:0]        shft_bar_is_io_unreg;
wire [7:0]        shft_bar_is_io;

// Used for cfg/msg/cpl only
assign pf_to_match = (flt_q_tlp_is_msg && (flt_q_type[2:0] == 3'b010))
                     | flt_q_cfg_req ? flt_q_cfg_func_num : flt_q_REQID[PF_WD-1:0];

// Extract info from cfg_bar_match and derive the bar number
// (in_membar_range), the function number (raw_mem_func_num)
// and the corresponding *bar_is_io vector.

always @(*)
begin : GET_MEM_BAR_PF_PROC
  integer idx;

  in_membar_range_unreg = `RADM_OUTSIDE_MEMBAR;
  raw_mem_func_num      = 0;

  for (idx=0; idx<NF; idx=idx+1)
  begin

    if (cfg_rom_match[idx])
      raw_mem_func_num = idx;
    else
      if ((|cfg_bar_match[(idx*6) +: 6]))
      begin
        raw_mem_func_num = idx;
        in_membar_range_unreg = get_bar_num(cfg_bar_match[(idx*6) +: 6]);
      end
  end
end

always @(*)
begin : GET_IO_BAR_PF_PROC
  integer idx;

  in_iobar_range_unreg = `RADM_OUTSIDE_MEMBAR;
  raw_io_func_num      = 0;
  shft_bar_is_io_unreg  = 0;

  for (idx=0; idx<NF; idx=idx+1)
  begin
    if (|(cfg_bar_match[(idx*6) +: 6] & cfg_bar_is_io[idx*6 +: 6]))
      begin
        raw_io_func_num = idx;
        in_iobar_range_unreg = get_bar_num((cfg_bar_match[(idx*6) +: 6] & cfg_bar_is_io[idx*6 +: 6]));
        shft_bar_is_io_unreg[5:0] = cfg_bar_is_io[idx*6 +: 6];
      end
  end
end


always @(*)
begin : GEN_RAW_CFG_FUNC_NUM
  integer idx;

  raw_cfg_func_num = 0;
  coerce_cfg_tlp_to_trgt1_int = 1'b0;

  for (idx=0; idx<NF; idx=idx+1)
  begin
    if (idx==pf_to_match)
    begin
      coerce_cfg_tlp_to_trgt1_int = cfg_config_above_match[idx];
      raw_cfg_func_num = pf_to_match;
    end
  end //for idx
end


wire mem_req = PIPE_VF_INDEX == 1 ? rtlh_mem_req : flt_q_mem_req ;
wire io_req  = PIPE_VF_INDEX == 1 ? rtlh_io_req  : (flt_q_iord_req | flt_q_iowr_req);
wire cfg_req = PIPE_VF_INDEX == 1 ? rtlh_cfg_req : flt_q_cfg_req ;
wire msg_req = PIPE_VF_INDEX == 1 ? tlp_is_msg && (hdr_type[2:0]==3'b010) :
               flt_q_tlp_is_msg && (flt_q_type[2:0] == 3'b010) ;


assign pfvf_func_num =  io_req  ? raw_io_func_num  :
                        mem_req ? raw_mem_func_num : 0;                            


assign raw_func_num_unreg = (mem_req | io_req)    ?  pfvf_func_num  :
                            (cfg_req | msg_req)   ?  pf             :
                            flt_q_REQID[PF_WD-1:0]; //completions


// If PIPE_VF_INDEX==1, cfg_*match are anticipated by one cycle
// and so are function and bar numbers.
// We need to delay them in order to align to flt_q* domain
delay_n

#(PIPE_VF_INDEX, PIPE_VF_INDEX_WIDTH) u_vf_index_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({raw_func_num_unreg, in_membar_range_unreg, in_iobar_range_unreg, shft_bar_is_io_unreg
                  }),
    .dout       ({raw_flt_q_func_num, in_membar_range, in_iobar_range, shft_bar_is_io
                 })
  );

delay_n

#(PIPE_VF_INDEX, PIPE_CFG_WIDTH) u_cfg_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({cfg_bar_match, cfg_bar_is_io, cfg_rom_match, coerce_cfg_tlp_to_trgt1_int
                 }),
    .dout       ({cfg_bar_match_reg, cfg_bar_is_io_reg, cfg_rom_match_reg, coerce_cfg_tlp_to_trgt1
                 })
  );

assign raw_flt_q_in_membar_range =                                   (flt_q_mem_req && !shft_bar_is_io[in_membar_range]) ? in_membar_range :
                                   ((flt_q_iord_req | flt_q_iowr_req)
                                   && shft_bar_is_io[in_iobar_range]) ? in_iobar_range :
                                   `RADM_OUTSIDE_MEMBAR;



/*
assign  flt_q_func_num = (flt_q_valid_ur_np | flt_q_valid_ur_p | flr_pf_in_progress) ? 0 : raw_flt_q_func_num;
assign  flt_q_func_num = (flt_q_valid_ur_np | flt_q_valid_ur_p) ? 0 : raw_flt_q_func_num;
*/

/*
assign  flt_q_valid_ur_xtrash   = ((flt_q_cfg0wr_req ? flt_q_valid_ur_np : flt_q_ur_np_wo_poisn) || flt_q_ur_p_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRASH) ;
assign  flt_q_valid_ur_xtrgt0   = ((flt_q_cfg0wr_req ? flt_q_valid_ur_np : flt_q_ur_np_wo_poisn) || flt_q_ur_p_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRGT0);
assign  flt_q_valid_ur_xtrgt1   = ((flt_q_cfg0wr_req ? flt_q_valid_ur_np : flt_q_ur_np_wo_poisn) || flt_q_ur_p_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRGT1) && !(ur_ca_mask_4_trgt1); // this `define will mask out the report of UR or CA
*/

// If a UR is due to a function specific error then the function number of the
// targeted function is used in the Completer ID of the Completion TLP.
// If a UR is due to a non-function specific error then the Completion is not
// associated with a specific function within the device and the function
// number is Reserved (i.e. the function number field of the Completer ID is
// set to all 0s).
assign  flt_q_func_num = flt_q_outrange_ur ? 0 : raw_flt_q_func_num;
// set membar to outside range if this is a UR
assign  flt_q_in_membar_range = (flt_q_valid_ur_np | flt_q_valid_ur_p | flr_in_progress) ? `RADM_OUTSIDE_MEMBAR : raw_flt_q_in_membar_range;

//
// derive the signals used for error log
//
wire  flt_q_valid_ur_xtrash_wo_poisn   = (flt_q_ur_np_wo_poisn | flt_q_ur_p_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRASH);
wire  flt_q_valid_ur_xtrgt0_wo_poisn   = (flt_q_ur_np_wo_poisn | flt_q_ur_p_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRGT0);
wire  flt_q_valid_ur_xtrgt1_wo_poisn   = (flt_q_ur_np_wo_poisn | flt_q_ur_p_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRGT1) && !(ur_ca_mask_4_trgt1); // this `define will mask out the report of UR or CA
wire  flt_q_valid_ur_wo_poisn_err      = flt_q_valid_ur_xtrgt0_wo_poisn || flt_q_valid_ur_xtrgt1_wo_poisn || flt_q_valid_ur_xtrash_wo_poisn || 
                                         (flr_in_progress & !(flt_q_cpl_w_lock | flt_q_cpl_wo_lock) );// UR, assuming no poisoned tlp

wire  flt_q_valid_ur_xtrash            = (flt_q_valid_ur_np | flt_q_valid_ur_p) && (flt_q_destination == `FLT_DESTINATION_TRASH);
wire  flt_q_valid_ur_xtrgt0            = (flt_q_valid_ur_np | flt_q_valid_ur_p) && (flt_q_destination == `FLT_DESTINATION_TRGT0);
wire  flt_q_valid_ur_xtrgt1            = (flt_q_valid_ur_np | flt_q_valid_ur_p) && (flt_q_destination == `FLT_DESTINATION_TRGT1) && !(ur_ca_mask_4_trgt1); // this `define will mask out the report of UR or CA
wire  flt_q_valid_ur_err               = flt_q_valid_ur_xtrgt0 || flt_q_valid_ur_xtrgt1 || flt_q_valid_ur_xtrash || 
                                         (flr_in_progress & !(flt_q_cpl_w_lock | flt_q_cpl_wo_lock) );// UR, including poisoned tlp

wire  flt_q_valid_ca_err               = flt_q_valid_ca_np | flt_q_valid_ca_p;

assign  l_radm_hdr_log          = {flt_q_hdr_dw4,flt_q_hdr_dw3,flt_q_hdr_dw2,flt_q_hdr_dw1};



assign {tmp_mlf_err_ptr, tmp_mlf_err} = flt_q_rtlh_abort  ? {flt_q_rtlh_abort_ptr, 1'b1} :
                                        flt_q_invalid_tlp ? {`MFPTR_TLP_TYP      , 1'b1} :
                                        flt_q_cpl_mlf_err ? {`MFPTR_CPL          , 1'b1} :
                                        flt_q_msg_mlf_err ? {`MFPTR_MSG_TC0      , 1'b1} :
                                                                 {`MFPTR_NO_ERR       , 1'b0} ;

always @(*)
begin: set_err_PROC
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
    l_set_outrange_req_ur               = 1'b0;
    // RTLH layer reported errors
    if (flt_q_unqual_eot && !rtlh_dllp_err_d  ) begin
        l_set_radm_ecrc_err             =  l_flt_q_ecrc_err & (!tmp_mlf_err);
        l_set_radm_mlf_tlp_err          =  tmp_mlf_err;
        l_set_radm_rcvd_cpl_poisoned    =  flt_q_poisoned_err & l_flt_q_tlp_type[CPL_TYPE]  & (!l_flt_q_ecrc_err) & (!tmp_mlf_err) & (!flt_q_unexp_cpl_err) & 
                                           !flt_q_mask_cpl_poisoned_reporting;// design from spec. that poisoned is the lowest priority when only one error is allowed to reported, or not reported if the filter rule CX_FLT_MASK_POIS_ERROR_REPORTING is set
        l_set_radm_rcvd_wreq_poisoned   =  flt_q_poisoned_err & !l_flt_q_tlp_type[CPL_TYPE] & (!l_flt_q_ecrc_err) & (!tmp_mlf_err) & (!flt_q_valid_ur_wo_poisn_err) & (!flt_q_valid_ca_err) &                             
                                           !flt_q_mask_wreq_poisoned_reporting;

        // filter detected errors for a received request
        // EP's CA generated for dwlen>1
        l_set_radm_rcvd_req_ca          =  flt_q_valid_ca_err & !tmp_mlf_err & !l_flt_q_ecrc_err;
        l_set_radm_rcvd_req_ur          =  flt_q_valid_ur_err & !tmp_mlf_err & !l_flt_q_ecrc_err;
        l_set_outrange_req_ur           =  flt_q_outrange_ur;
        // filter detected errors for a received completion
        // remain_byte_err is inaccurate,  FIX is TBD
        l_set_radm_unexp_cpl_err        =  flt_q_unexp_cpl_err & !tmp_mlf_err; // in lut module, unexpected error and mlf error are mutual exclusive, but low level MLF is not
        l_set_radm_rcvd_cpl_ur          =  flt_q_cpl_rcvd_ur ;  // priority assignment to keep core from reporting duplicated errors for completion is done in completion lookup module
        l_set_radm_rcvd_cpl_ca          =  flt_q_cpl_rcvd_ca ;

        // filter detected errors for a received message
        l_set_radm_hdr_log_valid        =  (l_flt_q_ecrc_err    ||
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
end

// Output registering (optional)
parameter ERROR_LOG_PIPE_DELAY = `CX_ERROR_LOG_REGOUT;
parameter ERROR_LOG_PIPEWIDTH = 125
                                + PF_WD                  // flt_q_func_num
                                + 14;

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
assign error_log_pipe_en = upstream_port && (pipe_error_log_en | pipe_error_log_en_reg); //  to flush the ERROR pipe and set error only for a cycle.

delay_n_w_enable

#(ERROR_LOG_PIPE_DELAY, ERROR_LOG_PIPEWIDTH) u_error_log_pipeline(
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
                    flt_q_func_num,
                    l_set_outrange_req_ur}),
    .dout       ({  radm_hdr_log,
                    set_radm_rcvd_req_ca, set_radm_rcvd_cpl_poisoned,
                    set_radm_rcvd_req_ur, set_radm_rcvd_wreq_poisoned,
                    set_radm_unexp_cpl_err, set_radm_rcvd_cpl_ur,
                    set_radm_rcvd_cpl_ca, set_radm_ecrc_err,
                    set_radm_mlf_tlp_err, set_radm_hdr_log_valid,
                    flt_q_func_num_d,
                    set_outrange_req_ur})
);


wire [63:0] extract_addr;
assign extract_addr = {flt_q_addr_byte7, flt_q_addr_byte6, flt_q_addr_byte5, flt_q_addr_byte4,
                       flt_q_addr_byte3, flt_q_addr_byte2, flt_q_addr_byte1, flt_q_addr_byte0};


assign flt_q_addr_int = extract_addr;
assign flt_q_header = chk_l_flt_q_header_d;




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
       reg [NVC-1:0] l_flt_q_hv_reg[FLT_Q_PIPE_DELAY-1:0];
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

   end else begin : gen_flt_q_pipe_delay_eq0
       assign  flt_q_hv  = l_flt_q_hv;
       assign  flt_q_dv  = l_flt_q_dv;
       assign  flt_q_eot = l_flt_q_eot;
   end
endgenerate

wire flt_q_pipe_en;
assign flt_q_pipe_en = upstream_port && ((|l_flt_q_hv) || (|l_flt_q_dv)); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe

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
                    flt_q_tlp_abort,
                    flt_q_tlp_type
                    })

);



  assign l_flt_q_header_d_prot_err = 1'b0;
  assign chk_l_flt_q_header_d = l_flt_q_header_d;



/////////////////////////////////////////////////////////////////////////
// Error indications for Cdm
/////////////////////////////////////////////////////////////////////////
wire [NF-1:0] radm_rcvd_req_ca_int        = route_error_to_func( set_radm_rcvd_req_ca        , flt_q_func_num_d);
wire [NF-1:0] radm_rcvd_req_ur_int        = set_outrange_req_ur ? {NF{set_radm_rcvd_req_ur}}      // when an UR wo function number, go all functions
                                                          : route_error_to_func( set_radm_rcvd_req_ur, flt_q_func_num_d);
wire [NF-1:0] radm_rcvd_cpl_poisoned_int  = route_error_to_func( set_radm_rcvd_cpl_poisoned  , flt_q_func_num_d);
wire [NF-1:0] radm_rcvd_wreq_poisoned_int = route_error_to_func( set_radm_rcvd_wreq_poisoned , flt_q_func_num_d);
wire [NF-1:0] radm_rcvd_cpl_ur_int        = route_error_to_func( set_radm_rcvd_cpl_ur        , flt_q_func_num_d);
wire [NF-1:0] radm_rcvd_cpl_ca_int        = route_error_to_func( set_radm_rcvd_cpl_ca        , flt_q_func_num_d);
wire [NF-1:0] radm_hdr_log_valid_int      = (set_radm_ecrc_err | set_radm_mlf_tlp_err | set_outrange_req_ur | set_radm_unexp_cpl_err) ? {NF{set_radm_hdr_log_valid}}
                                                                                                                                      : route_error_to_func( set_radm_hdr_log_valid      , flt_q_func_num_d);
assign radm_ecrc_err              = {NF{set_radm_ecrc_err}};
assign radm_mlf_tlp_err           = {NF{set_radm_mlf_tlp_err}};
assign radm_unexp_cpl_err         = {NF{set_radm_unexp_cpl_err}};  // Non function specific error (PCIe 1.1 C16 errata)
assign radm_rcvd_req_ca           = radm_rcvd_req_ca_int;
assign radm_rcvd_req_ur           = radm_rcvd_req_ur_int;
assign radm_rcvd_cpl_poisoned     = radm_rcvd_cpl_poisoned_int;
assign radm_rcvd_wreq_poisoned    = radm_rcvd_wreq_poisoned_int;
assign radm_rcvd_cpl_ur           = radm_rcvd_cpl_ur_int;
assign radm_rcvd_cpl_ca           = radm_rcvd_cpl_ca_int;
assign radm_hdr_log_valid         = radm_hdr_log_valid_int;

wire pf_hidden_for_vendor_msg0;
wire pf_hidden_for_vendor_msg1;
assign  flt_drop_msg            = (!cfg_filter_rule_mask[`CX_FLT_MASK_MSG_DROP] & !(flt_q_vendor_msg || flt_q_invalidate_msg 
                                  )) ||
                                     (!cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG0_DROP] & flt_q_vendor_msg0) ||
                                     pf_hidden_for_vendor_msg0 ||
                                     ((!cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG1_DROP] & flt_q_vendor_msg1) 
                                     )
                                     || pf_hidden_for_vendor_msg1 
                                  ;
assign  flt_q_ecrc_discard      = l_flt_q_ecrc_err & !cfg_filter_rule_mask[`CX_FLT_MASK_ECRC_DISCARD]; // when discard an ECRC TLP is desired
assign  flt_q_poisoned_discard  = flt_q_poisoned_err & !(cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & enable_mask_pois_if_trgt0_destination);

always @(/*AUTO SENSE*/default_target
         or flt_q_tlp_is_msg or l_flt_q_tlp_type or flt_q_valid_ur_np or flt_q_valid_ca_np
         or flt_q_valid_ur_p or flt_q_valid_ca_p or target_acquisition or flt_drop_msg
         or flt_q_handle_flush or flr_in_progress
         or flt_q_cpl_abort
         )
begin:  FILTER_PROCESS
    int_flt_q_destination               = `FLT_DESTINATION_TRASH;           // DEFAULT to trash
    if  (l_flt_q_tlp_type[CPL_TYPE]) begin                                // [-------------- CPL ---------------]
        if (flt_q_cpl_abort)
            int_flt_q_destination   = `FLT_DESTINATION_TRASH;           //  ABORTED CPLs due to unexpected completion
        else
            int_flt_q_destination   = `FLT_DESTINATION_CPL;             //  ALL CPLs expected aborted
    end
    if (l_flt_q_tlp_type[P_TYPE])  begin                                  // [------------- POSTED -------------]
        if (flt_q_tlp_is_msg & (flt_drop_msg | flt_q_valid_ur_p | flt_q_valid_ca_p | flr_in_progress))// (message)
            int_flt_q_destination       = `FLT_DESTINATION_TRASH;
        else if (flt_q_tlp_is_msg )                                         // (message)
            int_flt_q_destination       = `FLT_DESTINATION_TRGT1;
        else if (!flt_q_valid_ur_p & !flr_in_progress & !flt_q_valid_ca_p & flt_q_handle_flush)// VALID
            int_flt_q_destination       = `FLT_DESTINATION_TRGT0;
        else if (!flt_q_valid_ur_p & !flr_in_progress & !flt_q_valid_ca_p)                     // VALID
            int_flt_q_destination       = target_acquisition;               // target determined by bar-mapping
        else if (default_target)                                            // target determined by default_target
            int_flt_q_destination       = `FLT_DESTINATION_TRGT1;
        else
            int_flt_q_destination       = `FLT_DESTINATION_TRASH;
    end
    if (l_flt_q_tlp_type[NP_TYPE]) begin                                    // [----------- NON-POSTED -----------]
        if (!flt_q_valid_ur_np  & !flr_in_progress & !flt_q_valid_ca_np & flt_q_handle_flush)   // VALID
            int_flt_q_destination       = `FLT_DESTINATION_TRGT0;
        else if (!flt_q_valid_ur_np & !flr_in_progress & !flt_q_valid_ca_np)                   // VALID
            int_flt_q_destination       = target_acquisition;               // target determined by bar-mapping
        else                                                                // VALID UR
            if (default_target)                                             // target determined by default_target
                int_flt_q_destination   = `FLT_DESTINATION_TRGT1;           //  ALL others, valid or not
            else
                int_flt_q_destination   = `FLT_DESTINATION_TRGT0;
    end
end

// -----------------------------------------------------------------------------
// output drives
// -----------------------------------------------------------------------------

// CTRL_registers_path
always @(posedge core_clk or negedge core_rst_n)
begin  
   if (!core_rst_n) begin
      flt_q_unqual_dv  <= #TP 0;
      flt_q_unqual_hv  <= #TP 0;
      flt_q_unqual_eot <= #TP 0;
   end else if(upstream_port) begin
      flt_q_unqual_dv  <= #TP rtlh_radm_dv;
      flt_q_unqual_hv  <= #TP rtlh_radm_hv;
      flt_q_unqual_eot <= #TP rtlh_radm_eot;
   end
end

wire latch_hdr_pipe_en;
assign latch_hdr_pipe_en = upstream_port && (rtlh_radm_dv | rtlh_radm_hv); 

always @(posedge core_clk or negedge core_rst_n)
begin: LATCH_HDR_PROCESS
integer j;
    if(!core_rst_n)
    begin
        l_flt_q_data            <= #TP 0;
        l_flt_q_dwen            <= #TP 0;
        l_flt_q_ecrc_err        <= #TP 0;
        flt_q_cpl_mlf_err       <= #TP 0;
        flt_q_msg_mlf_err       <= #TP 0;
        l_flt_q_unexp_cpl_err   <= #TP 0;
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
        flt_q_vc_select         <= #TP 0;
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
       {flt_q_rtlh_abort_ptr, flt_q_rtlh_abort} <= #TP {rtlh_radm_malform_tlp_err_ptr, rtlh_radm_malform_tlp_err};
        l_flt_q_ecrc_err        <= #TP rtlh_radm_ecrc_err;

        flt_q_cpl_mlf_err       <= #TP cpl_tlp & cpl_mlf_err;
        flt_q_msg_mlf_err       <= #TP tlp_is_msg && int_mlf_msg;

        l_flt_q_unexp_cpl_err   <= #TP (cpl_tlp & unexpected_cpl_err); // not from completion lookup table
        flt_q_cpl_rcvd_ur       <= #TP cpl_tlp & cpl_ur_err;
        flt_q_cpl_rcvd_ca       <= #TP cpl_tlp & cpl_ca_err;
        flt_q_hdr_dw1           <= #TP chk_rtlh_radm_hdr[31:0];
        flt_q_hdr_dw2           <= #TP chk_rtlh_radm_hdr[63:32];
        flt_q_hdr_dw3           <= #TP chk_rtlh_radm_hdr[95:64];
        flt_q_hdr_dw4           <= #TP chk_rtlh_radm_hdr[127:96];
        flt_q_vc_select         <= #TP q_select_from_tc(cfg_tc_struc_vc_map, tc);
        flt_q_handle_flush      <= #TP cfg_filter_rule_mask[`CX_FLT_MASK_HANDLE_FLUSH] & dwlenEq1 & (first_be == 4'b0) & (last_be == 4'b0) & pcie_format;

        l_flt_q_parerr          <= #TP rtlh_radm_parerr | l_flt_data_parerr;
    end
end

assign  l_flt_q_tlp_abort       = (flt_q_cpl_abort | flt_q_rtlh_abort | flt_q_msg_mlf_err
                                ) & flt_q_unqual_eot;

assign  l_flt_q_hv[0]             = (flt_q_unqual_hv  & !flt_q_invalid_tlp);
assign  l_flt_q_dv[0]             = (flt_q_unqual_dv  & !flt_q_invalid_tlp);
assign  l_flt_q_eot[0]            = (flt_q_unqual_eot & !flt_q_invalid_tlp);

assign pm_block_tlp              =  get_pm_block(pm_radm_block_tlp,raw_flt_q_func_num);

assign  flt_q_mem_req_range     =  (cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR    ] || (flt_q_mem_req_in_range
                                                                                              || flt_q_rom_req_in_range));
assign  flt_q_io_req_range      =  (cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR    ] ||  flt_q_io_req_in_range );
assign  flt_q_pm_radm_block_tlp = !(cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR    ] || !pm_block_tlp);
assign  flt_q_func_mismatch_tlp = !(cfg_filter_rule_mask[`CX_FLT_MASK_UR_FUNC_MISMATCH  ] || !flt_q_func_mismatch   );
assign  flt_q_locked_rd_tlp     =  (cfg_filter_rule_mask[`CX_FLT_MASK_LOCKED_RD_AS_UR   ] &&  flt_q_locked_rd       );
// Unexpected CPL error when a completion received during pm block or CPL is not from CPL lookup table
assign  flt_q_unexp_cpl_err     = l_flt_q_unexp_cpl_err || (l_flt_q_tlp_type[CPL_TYPE] & pm_block_tlp);

assign flr_pf_in_progress = 0;
assign flr_vf_in_progress = 0;
// In order to avoid dropping Messages which have the Routing Type set to, for example Broadcast,
// we need to include only Messages with Routing ID = Route by ID;
// so, if the TLP is a MSG TLP, only Routed by ID are affected by FLR in Progress:
assign flr_in_progress = (flr_pf_in_progress | flr_vf_in_progress) && ((flt_q_type[4:3] != 2'b10) || (flt_q_type[2:0] == 3'b010)); 


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

assign flt_q_atomic_discard = valid_atomic_request && (target_acquisition == `FLT_DESTINATION_TRGT0) && flt_q_valid_np;

// Check for valid DMWr Requests
// A DMWr request must have a supported operand size otherwise the request should be treated as a UR.
localparam MAX_DMWR_SIZE = (`CX_DEF_MEM_WR_LEN_SUPP == 0)? 10'd16 : 10'd32;
wire valid_def_memwr_request;
assign valid_def_memwr_request = flt_q_def_memwr_req  && (flt_q_dw_len > 10'h0) && (flt_q_dw_len <= MAX_DMWR_SIZE) && (`CX_DEF_MEM_WR_CPL_EN);

// We don't support DMWrs Ops targeting TRGT0 (ELBI)
wire flt_q_def_memwr_discard;
assign flt_q_def_memwr_discard = valid_def_memwr_request && (target_acquisition == `FLT_DESTINATION_TRGT0) && flt_q_valid_np;

wire valid_ats;
assign valid_ats = 1;

wire pf_hidden_for_cfg_req;
assign pf_hidden_for_cfg_req = 1'b0;
assign pf_hidden_for_vendor_msg0 = 1'b0;
assign pf_hidden_for_vendor_msg1 = 1'b0;

assign  flt_q_valid_np          =  ((((flt_q_mem_req_range) && (valid_atomic_request || flt_q_memrd_req || valid_def_memwr_request || flt_q_locked_rd_tlp)
                                    && valid_ats
                                    && flt_q_pcie_valid_tc
                                    )  ||
                                  //`ifdef CX_CXL_ENABLE
                                  //  (flt_q_rcrb_req_in_range) ||
                                  //`endif //CX_CXL_ENABLE
                                     ((flt_q_iord_req      || flt_q_iowr_req)       &&  flt_q_io_req_range))     && !flt_q_pm_radm_block_tlp && flt_q_pcie_valid_tc) ||
                                   ((((flt_q_cfg0rd_req    || flt_q_cfg0wr_req)     && !flt_q_func_mismatch_tlp  && flt_q_pcie_valid_tc) ||
                                     ((flt_q_cfg1rd_req    || flt_q_cfg1wr_req)     && !flt_q_func_mismatch_tlp  && flt_q_pcie_valid_tc &&
                                      cfg_filter_rule_mask[`CX_FLT_MASK_CFG_TYPE1_REQ_AS_UR ]))                  &&
                                    !pf_hidden_for_cfg_req);

assign  flt_q_outrange_ur       = (!flt_q_mem_req_range && (valid_atomic_request || flt_q_memrd_req          || flt_q_locked_rd_tlp || flt_q_memwr_req || valid_def_memwr_request))  ||
                                  ((flt_q_iord_req      || flt_q_iowr_req)       && !flt_q_io_req_range)     ||
                                  (((flt_q_cfg0rd_req   || flt_q_cfg0wr_req)     && flt_q_func_mismatch_tlp) ||
                                   ((flt_q_cfg1rd_req   || flt_q_cfg1wr_req)     && (flt_q_func_mismatch_tlp ||
                                    !cfg_filter_rule_mask[`CX_FLT_MASK_CFG_TYPE1_REQ_AS_UR ]))               ||
                                   pf_hidden_for_cfg_req)                                                    ||
                                  pf_hidden_for_vendor_msg0                                                  ||
                                  (flt_q_tlp_is_msg    && flt_q_invalid_msg      && !(flt_q_vendor_msg_id_match && (flt_q_type[2:0]==3'b010)));


assign  flt_q_valid_p           = ((flt_q_mem_req_range) && flt_q_memwr_req &&
                                    flt_q_pcie_valid_tc &&
                                    !flt_q_pm_radm_block_tlp && valid_ats)
                                  | (flt_q_tlp_is_msg && 
                                  !flt_q_invalid_msg && !pf_hidden_for_vendor_msg0)
                                  ;


assign  flt_q_ur_np_wo_poisn    = (flt_q_cfg1rd_req    || flt_q_cfg1wr_req ||
                                   flt_q_cfg0rd_req    || flt_q_cfg0wr_req ||
                                   flt_q_locked_rd     ||
                                   flt_q_memrd_req     || flt_q_atomic_op  ||
                                   flt_q_def_memwr_req ||
                                   flt_q_iord_req      || flt_q_iowr_req
                                  ) && (!flt_q_valid_np);

assign  flt_q_valid_ur_np       = (flt_q_cfg1rd_req    || flt_q_cfg1wr_req ||
                                   flt_q_cfg0rd_req    || flt_q_cfg0wr_req ||
                                   flt_q_locked_rd     ||
                                   flt_q_memrd_req     || flt_q_atomic_op  ||
                                   flt_q_def_memwr_req ||
                                   flt_q_iord_req      || flt_q_iowr_req
                                  ) && (!flt_q_valid_np | flt_q_poisoned_discard);

assign  flt_q_ur_p_wo_poisn     = (flt_q_memwr_req | flt_q_tlp_is_msg) && (!flt_q_valid_p);

assign  flt_q_valid_ur_p        = (flt_q_memwr_req | flt_q_tlp_is_msg) && (!flt_q_valid_p | flt_q_poisoned_discard);

assign  target_ca               = ((flt_q_dw_len == 0) || (flt_q_dw_len > CX_ELBI_NW)) && (target_acquisition == `FLT_DESTINATION_TRGT0);

assign  flt_q_valid_ca_p        = (flt_q_memwr_req | flt_q_tlp_is_msg) && flt_q_valid_p && (target_ca || flt_q_ecrc_discard);
assign  flt_q_valid_ca_np       = flt_q_valid_np && (target_ca || flt_q_ecrc_discard || flt_q_atomic_discard || flt_q_def_memwr_discard);

//
// [ ----------------  MESSAGE interception  -----------------------]
//

wire                    int_pm_asnak;
wire                    int_pm_turnoff;
wire                    int_inta_asserted;
wire                    int_intb_asserted;
wire                    int_intc_asserted;
wire                    int_intd_asserted;
wire                    int_inta_deasserted;
wire                    int_intb_deasserted;
wire                    int_intc_deasserted;
wire                    int_intd_deasserted;
wire                    int_att_ind_on;
wire                    int_att_ind_blink;
wire                    int_att_ind_off;
wire                    int_pwr_ind_on;
wire                    int_pwr_ind_blink;
wire                    int_pwr_ind_off;
wire                    int_msg_unlock;
wire                    int_att_button_pressed;
wire                    int_vendor_msg_id_match;
wire                    int_ltr;
wire                    int_invalidate_request;
wire                    int_invalidate_cmplt;
reg                     flt_q_pcie_good_eot;

// Several Messages are required to be sent with TC0  and checking is required.
// Section 2.2.8.x:
// "x Messages must use the default Traffic Class designator (TC0). Receivers
// must check for violations of this rule. If a Receiver determines that
// a TLP violates this rule, it must handle the TLP as a Malformed TLP"
// Also Section 2.2.8.1:
// "Assert_INTx/Deassert_INTx Messages are only issued by Upstream Ports
// Receivers may optionally check for violations of this rule. If a Receiver
// implementing this 15 check determines that an Assert_INTx/Deassert_INTx
// violates this rule, it must handle the TLP as a Malformed TLP"

assign int_mlf_msg = pcie_format && tc != 0 && (
    ((msg_code == `PM_ACTIVE_STATE_NAK)) ||
    ((msg_code == `PME_TURN_OFF)       ) ||
    ((msg_code == `UNLOCK)             ) ||
    ((msg_code == `SET_SLOT_PWR_LIMIT) )
    ) ||
   ((msg_code == `ASSERT_INTA)        ) ||
    ((msg_code == `ASSERT_INTB)        ) ||
    ((msg_code == `ASSERT_INTC)        ) ||
    ((msg_code == `ASSERT_INTD)        ) ||
    ((msg_code == `DEASSERT_INTA)      ) ||
    ((msg_code == `DEASSERT_INTB)      ) ||
    ((msg_code == `DEASSERT_INTC)      ) ||
    ((msg_code == `DEASSERT_INTD)      );


assign  int_pm_asnak            = ((msg_code == `PM_ACTIVE_STATE_NAK)                 && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_pm_turnoff          = ((msg_code == `PME_TURN_OFF)                        && (hdr_type[2:0] == 3'b011) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_inta_asserted       = ((msg_code == `ASSERT_INTA)                         && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_intb_asserted       = ((msg_code == `ASSERT_INTB)                         && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_intc_asserted       = ((msg_code == `ASSERT_INTC)                         && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_intd_asserted       = ((msg_code == `ASSERT_INTD)                         && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_inta_deasserted     = ((msg_code == `DEASSERT_INTA)                       && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_intb_deasserted     = ((msg_code == `DEASSERT_INTB)                       && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_intc_deasserted     = ((msg_code == `DEASSERT_INTC)                       && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_intd_deasserted     = ((msg_code == `DEASSERT_INTD)                       && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_att_ind_on          = ((msg_code == `ATTENTION_INDICATOR_ON)              && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_att_ind_blink       = ((msg_code == `ATTENTION_INDICATOR_BLINK)           && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_att_ind_off         = ((msg_code == `ATTENTION_INDICATOR_OFF)             && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_pwr_ind_on          = ((msg_code == `POWER_INDICATOR_ON)                  && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_pwr_ind_blink       = ((msg_code == `POWER_INDICATOR_BLINK)               && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_pwr_ind_off         = ((msg_code == `POWER_INDICATOR_OFF)                 && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_msg_unlock          = ((msg_code == `UNLOCK)                              && (hdr_type[2:0] == 3'b011) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_att_button_pressed  = ((msg_code == `ATTENTION_BUTTON_PRESSED)            && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_ltr                 = ((msg_code == `LATENCY_TOLERANCE_REPORTING)         && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
assign  int_invalidate_request  = ((msg_code == `INVALIDATE_REQUEST)                  && (hdr_type[2:0] == 3'b010) && (tlpmsg == `MSGD_4) && !int_mlf_msg && pcie_format);
assign  int_invalidate_cmplt    = ((msg_code == `INVALIDATE_COMPLETION)               && (hdr_type[2:0] == 3'b010) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);


assign  flt_q_vendor_msg        = flt_q_vendor_msg0 || flt_q_vendor_msg1;
assign  int_vendor_msg_id_match = vendor_msg_id_match;
assign  flt_q_vendor_msg_id_match  =  int_flt_q_vendor_msg_id_match;
assign  flt_q_invalid_msg       = int_flt_q_invalid_msg;


always @(posedge core_clk or negedge core_rst_n)
begin:  MESSAGE_INTERCEPTION_PROCESS
    if (!core_rst_n)
    begin
        radm_pm_asnak                   <= #TP 1'b0;
        radm_pm_turnoff                 <= #TP 1'b0;
        radm_slot_pwr_limit             <= #TP 1'b0;
        radm_msg_unlock                 <= #TP 1'b0;
        int_flt_q_invalid_msg           <= #TP 1'b0;
        int_flt_q_vendor_msg_id_match   <= #TP 1'b0;
        flt_q_vendor_msg0               <= #TP 1'b0;
        flt_q_vendor_msg1               <= #TP 1'b0;
        flt_q_invalidate_msg            <= #TP 1'b0;
        flt_q_pcie_good_eot             <= #TP 1'b0;
    end
    else
    begin

        flt_q_vendor_msg0               <= #TP msg_is_vendor_msg0 && tlp_is_msg && !tlp_poisoned;
        flt_q_vendor_msg1               <= #TP msg_is_vendor_msg1 && tlp_is_msg && !tlp_poisoned;
        flt_q_invalidate_msg            <= #TP ((int_invalidate_request | int_invalidate_cmplt) && `CX_ATS_ENABLE_VALUE==1)
                                               && tlp_is_msg && !tlp_poisoned;
        flt_q_pcie_good_eot             <= #TP rtlh_radm_eot && pcie_valid_tc && !(rtlh_radm_dllp_err | rtlh_radm_ecrc_err | rtlh_radm_malform_tlp_err);



        if (rtlh_radm_hv && !(rtlh_radm_dllp_err | rtlh_radm_ecrc_err | rtlh_radm_malform_tlp_err)
             && rtlh_radm_eot && !tlp_poisoned && tlp_is_msg && pcie_valid_tc) begin
            radm_pm_asnak           <= #TP  int_pm_asnak;
            radm_pm_turnoff         <= #TP  int_pm_turnoff;
            radm_msg_unlock         <= #TP  int_msg_unlock;
            radm_slot_pwr_limit     <= #TP upstream_port  && msg_is_slotpwr && dwlenEq1;
        end else begin
            radm_slot_pwr_limit         <= #TP 1'b0;
            radm_pm_asnak               <= #TP 1'b0;
            radm_pm_turnoff             <= #TP 1'b0;
            radm_msg_unlock             <= #TP 1'b0;
        end

        int_flt_q_invalid_msg           <= #TP ~( (pcie_valid_tc &
                                                     (((msg_is_vendor_msg0 & cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG0_DROP])// When vendor 0 is dropped, it'll create a UR
                                                        & (
                                                           (hdr_type[2:0] == 3'b010 & int_vendor_msg_id_match) |
                                                           (hdr_type[2:0] == 3'b011) | (hdr_type[2:0] == 3'b100)))  |
                                                      msg_is_vendor_msg1           |         // VENDOR_MSG1 valid if routing 000b, 010b, 011b or 100b
                                                      (msg_is_slotpwr & dwlenEq1)  |
                                                      (int_msg_unlock)             |
                                                      (int_pm_asnak  )             |
                                                      (int_pm_turnoff)             |
                                                      int_att_ind_on               |
                                                      int_att_ind_blink            |
                                                      int_att_ind_off              |
                                                      int_pwr_ind_on               |
                                                      int_pwr_ind_blink            |
                                                      int_att_button_pressed       |
                                                      int_pwr_ind_off
                                                    )
                                                  )
                                                )
                                                && (rtlh_radm_hv | rtlh_radm_dv) && rtlh_radm_eot && tlp_is_msg
                                                && !(rtlh_radm_dllp_err | rtlh_radm_ecrc_err | rtlh_radm_malform_tlp_err | int_mlf_msg);

        int_flt_q_vendor_msg_id_match   <= #TP int_vendor_msg_id_match;
    end
end


// for short Vendor message, we can send to SII interface
//--------------------------------
// Extract SII message header info
//--------------------------------
assign  radm_vendor_msg = (flt_q_vendor_msg && flt_q_pcie_good_eot)
                        ;
// The VDM message payload is defined from bytes 12 to byte 15.
// To be consistent with the format on the RTRGT1 address bus the byte  order is reversed.
// DW3 output on bits [63:32], DW4 output on [31:0].
assign  radm_msg_payload = (flt_q_vendor_msg) ?
                              {flt_q_hdr_dw3[7:0],flt_q_hdr_dw3[15:8],flt_q_hdr_dw3[23:16],flt_q_hdr_dw3[31:24],
                               flt_q_hdr_dw4[7:0],flt_q_hdr_dw4[15:8],flt_q_hdr_dw4[23:16],flt_q_hdr_dw4[31:24]} :
                              {32'b0, chk_l_flt_q_data[31:0]};
assign  radm_rcvd_tlp_req_id = flt_q_REQID;

assign l_flt_q_header = flt_q_compressed_hdr;

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

always @(/*AUTO SENSE*/flt_q_REQID or flt_q_TAG or flt_q_addr
         or flt_q_attr
         or flt_q_cpl_bcm
         or flt_q_cpl_last or flt_q_cpl_reqid
         or flt_q_cpl_status or flt_q_cplid or flt_q_destination or int_flt_q_destination
         or flt_q_dw_len or flt_q_first_be or flt_q_fmt
         or flt_q_in_membar_range
         or flt_q_io_req_in_range or flt_q_last_be or flt_q_poisoned
         or flt_q_rcvd_cpl_status or flt_q_reserved_status
         or flt_q_rcvd_cpl_tlp_tag or flt_q_rcvd_tlp_byte_cnt
         or flt_q_rcvd_tlp_low_addr or flt_q_rom_req_in_range
         or flt_q_valid_ur_np or flt_q_valid_ur_p or flr_in_progress
         or flt_q_func_num
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
    flt_q_compressed_hdr[ `FLT_Q_FUNC_NMBR_RANGE       ] = flt_q_func_num;                  // for cfg transaction only
    flt_q_compressed_hdr[ `FLT_Q_CPL_STATUS_RANGE      ] = flt_q_cpl_status[2:0];           // completion hdr element
    flt_q_compressed_hdr[ `FLT_Q_ROM_IN_RANGE_RANGE    ] = flt_q_rom_req_in_range & ~(flt_q_valid_ur_np | flt_q_valid_ur_p | flr_in_progress);  // TRGT0 control
    flt_q_compressed_hdr[ `FLT_Q_IO_REQ_IN_RANGE_RANGE ] = flt_q_io_req_in_range  & ~(flt_q_valid_ur_np | flt_q_valid_ur_p | flr_in_progress);  // TRGT0 control
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
    if (int_flt_q_destination[1:0] == `FLT_DESTINATION_TRGT0)
    begin
        // FOR trgt0 configurations we can squeeze out the reserved bits which don't need to be stored
        // FOR trgt0 UR, we overload some of the address with lastdw/length
        if (flt_q_cpl_status !=`SU_CPL_STATUS)
        begin
            flt_q_compressed_hdr[`FLT_T0Q_LSTDW_BE_RANGE  ] = flt_q_last_be[3:0];
            flt_q_compressed_hdr[`FLT_T0Q_DW_LENGTH_RANGE ] = flt_q_dw_len[9:0];
        end
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
    begin
        route_error_to_func = 0;
        if (function_dest  < NF)
            route_error_to_func[function_dest] = set_error_signal;
        else // function_dest >= NF
            route_error_to_func = {NF{set_error_signal}};
end
endfunction

function automatic get_pm_block;
    input [NF-1:0]    pm_radm_block_tlp;
    input [PF_WD-1:0] tlp_func_num;
    integer        func;
    begin
      get_pm_block = 1'b1;
      for (func=0; func<NF; func=func+1) begin
        if (tlp_func_num==func)
          get_pm_block = pm_radm_block_tlp[func];
      end
    end
endfunction


// Get a bar number from the one hot bar match
function automatic [2:0] get_bar_num;
input [5:0] bar;
begin
    casez  (bar)
        6'b000000 : get_bar_num = `RADM_OUTSIDE_MEMBAR;
        6'b?????1 : get_bar_num = 3'd0;
        6'b????10 : get_bar_num = 3'd1;
        6'b???100 : get_bar_num = 3'd2;
        6'b??1000 : get_bar_num = 3'd3;
        6'b?10000 : get_bar_num = 3'd4;
        6'b100000 : get_bar_num = 3'd5;
    endcase
end
endfunction




`ifndef SYNTHESIS
//VCS coverage off
always @(posedge core_clk)
begin
    if (|l_flt_q_hv && upstream_port)
    begin
        if (l_flt_q_tlp_type[P_TYPE] && (flt_q_destination == `FLT_DESTINATION_TRASH))
            $display ("%t %m WARNING:  Posted transaction intended was TRASHED by RADM Filter", $time);
        if (l_flt_q_tlp_type[CPL_TYPE] && (flt_q_destination == `FLT_DESTINATION_TRASH))
            $display ("%t %m WARNING:  Completion transaction TRASHED by RADM Filter", $time);
    end
end
wire    [8*5:0]         RADM_Q_DEST;
wire    [8*5:0]         TARGET_MAP;
wire    [8*9:0]         RADM_Q_VALID_TYPE;
wire    [8*3:0]         RADM_Q_TLP_TYPE;

//  ENCODED valid type
reg     [2:0]           flt_q_valid_type;
always @(flt_q_valid_np or flt_q_valid_p or flt_q_valid_ur_np or flt_q_valid_ur_p)
begin:  ENCODE_VALID_TYPE
    case({flt_q_valid_ur_p,flt_q_valid_ur_np,flt_q_valid_p,flt_q_valid_np} )
        4'b0001:    flt_q_valid_type = `FLT_VALID_NP_TYPE;
        4'b0010:    flt_q_valid_type = `FLT_VALID_P_TYPE;
        4'b0100:    flt_q_valid_type = `FLT_VALID_UR_NP_TYPE;
        4'b1000:    flt_q_valid_type = `FLT_VALID_UR_P_TYPE;
        default:    flt_q_valid_type = 3'b100; //
    endcase //
end


assign  TARGET_MAP              =  ( target_acquisition == `FLT_DESTINATION_TRASH ) ? "trash"     :
                                   ( target_acquisition == `FLT_DESTINATION_TRGT0 ) ? "TRGT0"     :
                                   ( target_acquisition == `FLT_DESTINATION_TRGT1 ) ? "TRGT1"     : "bogus";

assign  RADM_Q_DEST             =  ( flt_q_compressed_hdr[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_TRASH ) ? "trash"     :
                                   ( flt_q_compressed_hdr[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_TRGT0 ) ? "TRGT0"     :
                                   ( flt_q_compressed_hdr[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_TRGT1 ) ? "TRGT1"     :
                                   ( flt_q_compressed_hdr[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_CPL   ) ? "CPL"       : "bogus";

assign  RADM_Q_VALID_TYPE       =  ( flt_q_valid_type  == `FLT_VALID_NP_TYPE     ) ? "val_NP"    :
                                   ( flt_q_valid_type  == `FLT_VALID_P_TYPE      ) ? "val_P"     :
                                   ( flt_q_valid_type  == `FLT_VALID_UR_NP_TYPE  ) ? "val_UR_NP" :
                                   ( flt_q_valid_type  == `FLT_VALID_UR_P_TYPE   ) ? "val_UR_P"  : "----";


assign  RADM_Q_TLP_TYPE         =  ( l_flt_q_tlp_type == 3'b001 ) ? "P"  :
                                   ( l_flt_q_tlp_type == 3'b010 ) ? "NP" :
                                   ( l_flt_q_tlp_type == 3'b100 ) ? "CPL":
                                   ( l_flt_q_tlp_type == 3'b000 ) ? "---": "BGS";
//VCS coverage on

                               

`endif // SYNTHESIS


endmodule
