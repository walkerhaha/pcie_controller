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
// ---    $DateTime: 2020/10/23 10:21:15 $
// ---    $Revision: #24 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_cpl_lut.sv#24 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//  1. provide cpl LUT to mananage received cpl, storing with tag.
//  2. provide cpl timeout mechansim.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Adm/radm_defs_pkg.svh"

 module radm_cpl_lut 
 import radm_defs_pkg::*;
(
// ---- inputs ---------------
    core_clk,
    radm_clk_ug,
    core_rst_n,
    rstctl_core_flush_req,
    cfg_filter_rule_mask,
    cfg_pbus_dev_num,
    cfg_pbus_num,
    cfg_p2p_track_cpl_to,
    cfg_p2p_err_rpt_ctrl,
    cfg_cpl_timeout_disable,
    cpl_tlp,
    dwlenEq0,
    flt_q_tlp_type,
    rtlh_radm_hv,
    rtlh_radm_hdr,
    rtlh_radm_eot,
    rtlh_radm_dllp_err,
    rtlh_radm_ecrc_err,
    rtlh_radm_malform_tlp_err,
    rtlh_radm_ant_rid,
    cpl_status,
    xtlh_xmt_tlp_attr,
    xtlh_xmt_tlp_done,
    xtlh_np_tlp_early,
    xtlh_xmt_tlp_len_inbytes,
    xtlh_xmt_tlp_first_be,
    xtlh_xmt_cfg_req,
    xtlh_xmt_memrd_req,
    xtlh_xmt_atomic_req,
    xtlh_xmt_ats_req,
    xtlh_xmt_tlp_req_id,
    xtlh_xmt_tlp_tag,
    xtlh_xmt_tlp_tc,
    current_data_rate,

    phy_type,
    device_type,


// ---- outputs ---------------
    vendor_msg_id_match,
    flt_q_cpl_abort,
    flt_q_cpl_last,
    cpl_mlf_err,
    cpl_ur_err,
    cpl_ca_err,
    radm_cpl_lut_valid,
    unexpected_cpl_err,
    radm_cpl_pending,
    radm_cpl_lut_busy,
    radm_cpl_timeout,
    radm_cpl_timeout_cdm,
    radm_timeout_cpl_tc,
    radm_timeout_cpl_attr,
    radm_timeout_cpl_tag,
    radm_timeout_func_num,
    radm_timeout_cpl_len
    ,
    radm_cpl_lut_pending

);

parameter TAG_SIZE               = `CX_TAG_SIZE;

parameter INST                    = 1'b0;

parameter NB                      = `CX_NB;                 // Number of symbols (bytes) per clock cycle
localparam CPL_LUT_DEPTH          = `CX_MAX_TAG + 1 
                                     ;                      // number of max tag that this core is configured to run
                                                            // Extra safe entry(769-1) to stay when 767<time_addr=timer[CPL_LUT_PTR_WD-1:0]<1024
                                                            // Max CPL_LUT_DEPTH=769
parameter CPL_LUT_DEPTH_EXTERNAL = `CX_MAX_TAG + 1;
 
parameter NF                      = `CX_NFUNC;              // Number of Physical Functions
parameter NVF                     = `CX_NVFUNC;             // Number of virtual functions
parameter INT_NVF                 = `CX_INTERNAL_NVFUNC;    // Number of Internal virtual functions
parameter NW                      = `CX_NW;                 // Number of Dwords in datapath
localparam FX_TLP                 = `CX_FX_TLP;             // Number of TLPs that can be processed in a single cycle after the formation block
localparam PF_WD                  = `CX_NFUNC_WD;           // Number of bits needed to address the physical functions
localparam VFI_WD                 = `CX_LOGBASE2(NVF);      // number of bits needed to represent the vf index [0 ... NVF-1]
localparam VF_WD                  = `CX_LOGBASE2(NVF) + 1;  // number of bits needed to represent the vf number plus one bit to indicate vf_active, i.e. if the pf,vf pair indicates a pf only or a vf within a pf
localparam NVF_EXT   = (1 << VFI_WD); // used to extend vectors to the full range of a vf number represented by VFI_WD bits, used to avoid ELAB-349 and E267: Range index out of bound when NVF is not a power of two
parameter FUNC_NUM_INDEX          =  PF_WD;                // 2:0 for function number in the lut
parameter BYTECNT_INDEX           = FUNC_NUM_INDEX;
// ## CPL_LUT2 ##
parameter LOW_ADDR_WD2            = 2;
parameter BYTECNT_WD2             = 12;
parameter LOW_ADDR_INDEX2         = 0;
parameter BYTECNT_INDEX2          = LOW_ADDR_WD2;
parameter CPL_ENTRY_WIDTH2        = LOW_ADDR_WD2 + BYTECNT_WD2;
parameter TC_INDEX                = 3 + BYTECNT_INDEX;

parameter ATTR_INDEX = 2 + TC_INDEX;

parameter NP_REQ_TYPE_INDEX = ATTR_INDEX + NP_REQ_TYPE_WD;
parameter CPL_ENTRY_WIDTH         = NP_REQ_TYPE_INDEX
                                    ; // This parameter is passing up from another module, Width of completion entry (length, attribute, Traffic Class, func number) 

parameter CPL_LUT_PTR_WD          = `CX_LUT_PTR_WIDTH;        // Number of bits needed to index completion table
parameter TIMEOUT_GRANULARITY     = `CX_TIMEOUT_GRANULARITY;  // Width of timeout value (granularity)

// Completion timer value scaled down by dividing the granularity. Min > CPL_LUT_PTR_WD
parameter CPL_TIMEOUT_VALUE_INT   = `CX_CPL_BASE_TIMER_VALUE;
parameter CPL_TIMER_TW            = `CX_CPL_BASE_TIMER_TW;    // timer width of the timeout value
parameter CPL_BASE_TIMER_VALUE_US = `CX_CPL_BASE_TIMER_VALUE_US; // the cpl base timer period expressed in microseconds
parameter TP                      = `TP;                      // Clock to Q delay (simulator insurance)
parameter BUSNUM_WD               = `CX_BUSNUM_WD;            // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD               = `CX_DEVNUM_WD;            // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter HW                      = 128;                      // Width of header in bits.
// Width of the header protection bus. 0 if RAS is not enabled
parameter HDR_PROT_WD             = `CX_RAS_PCIE_HDR_PROT_WD;

parameter P_TYPE                  = 0;
parameter NP_TYPE                 = 1;
parameter CPL_TYPE                = 2;
parameter N_FLT_MASK              = `CX_N_FLT_MASK;

parameter RADM_CPL_LUT_PIPE_EN    = `CX_RADM_CPL_LUT_PIPE_EN_VALUE; 
parameter RADM_FILTER_TO_LUT_PIPE    = 0; 
parameter RTLH_RADM_RID_WD  = (FX_TLP*16);
parameter RADM_ANT_PIPE_WD  = 16; 

input                           core_clk;
input                           radm_clk_ug; // ungated radm clock used to clock through anticipated RID in the radm cpl filter
input                           core_rst_n;
input                           rstctl_core_flush_req;
input   [N_FLT_MASK-1:0]        cfg_filter_rule_mask;       // "static" // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
input   [DEVNUM_WD -1:0]        cfg_pbus_dev_num;           // "static" // Device number
input   [BUSNUM_WD -1:0]        cfg_pbus_num;               // "static" // Bus number
input                           cfg_p2p_track_cpl_to;       // 0: bydefault, do not track cpl in lut for P2P; 1: track cpl in lut for P2P.
input                           cfg_p2p_err_rpt_ctrl;       // 1: bydefault, P2P error reporting enable; 0: P2P error reporting disable.
input   [NF-1:0]                cfg_cpl_timeout_disable;    // "static" // Completion timeout disable

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// completion packet interface
input   [FX_TLP-1:0]            cpl_tlp;
input   [(FX_TLP*3)-1:0]        cpl_status;
input   [FX_TLP-1:0]            dwlenEq0;
input   [(FX_TLP*3)-1:0]        flt_q_tlp_type;             // one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ flt_q_hv
input   [FX_TLP-1:0]            rtlh_radm_hv;               // When asserted; indicates the hdr valid
input   [(FX_TLP*(HW+HDR_PROT_WD))-1:0] rtlh_radm_hdr;      // hdr payload
input   [FX_TLP-1:0]            rtlh_radm_eot;              // When asserted; indicates the tlp end
input   [FX_TLP-1:0]            rtlh_radm_dllp_err;         // Indication that TLP has dllp err (valid @ EOT)
input   [FX_TLP-1:0]            rtlh_radm_malform_tlp_err;  // Indication that TLP is malformed (valid @ HV)
input   [FX_TLP-1:0]            rtlh_radm_ecrc_err;         // Indication that TLP has ECRC err (valid @ EOT)
input   [RTLH_RADM_RID_WD-1:0]  rtlh_radm_ant_rid;     // anticipated RID (1 clock earlier)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// initial packet interface
input   [1:0]                   xtlh_xmt_tlp_attr;          // transmitted TLP attibutes
input                           xtlh_xmt_tlp_done;          // transmitted TLP is done
input                           xtlh_np_tlp_early;          // an early indication from layer3 that a NP TLP has been sent
input   [11:0]                  xtlh_xmt_tlp_len_inbytes;   // transmitted TLP length in bytes
input   [3:0]                   xtlh_xmt_tlp_first_be;      // transmitted TLP first be

input                           xtlh_xmt_cfg_req;
input                           xtlh_xmt_memrd_req;
input                           xtlh_xmt_atomic_req;
input                           xtlh_xmt_ats_req;
input   [15:0]                  xtlh_xmt_tlp_req_id;        // interface id, it is designed to identify which Client interface the completion belongs to.
input   [TAG_SIZE-1:0]          xtlh_xmt_tlp_tag;           // transmitted TLP tag
input   [2:0]                   xtlh_xmt_tlp_tc;            // transmitted TLP tc
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

input   [2:0]                   current_data_rate;          // "static" // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4

input                           phy_type;                   // Mac type
input   [3:0]                   device_type;                // "static"


output  [FX_TLP-1:0]            vendor_msg_id_match;
output  [FX_TLP-1:0]            flt_q_cpl_abort;
output  [FX_TLP-1:0]            flt_q_cpl_last;
output  [FX_TLP-1:0]            cpl_mlf_err;
output  [FX_TLP-1:0]            cpl_ur_err;
output  [FX_TLP-1:0]            cpl_ca_err;
output  [FX_TLP-1:0]            unexpected_cpl_err;
output  [NF-1:0]                radm_cpl_pending;
output                          radm_cpl_lut_busy;          // CPL LUT busy indication
output                          radm_cpl_timeout;
output                          radm_cpl_timeout_cdm;       // Same information as radm_cpl_timeout but without the timeout tags flr'ed
output  [2:0]                   radm_timeout_cpl_tc;            // not used
output  [1:0]                   radm_timeout_cpl_attr;          // not used
output  [TAG_SIZE-1:0]          radm_timeout_cpl_tag;
output  [PF_WD-1:0]             radm_timeout_func_num;
output  [11:0]                  radm_timeout_cpl_len;

output  [CPL_LUT_DEPTH_EXTERNAL-1:0] radm_cpl_lut_valid;            // completion lookup table valid indication

output                          radm_cpl_lut_pending; // pending flag for the radm cpl lut
reg                             radm_cpl_lut_pending;



wire    [FX_TLP-1:0]            flt_q_cpl_last;
reg                             radm_cpl_timeout;
reg                             radm_cpl_timeout_cdm;
reg     [TAG_SIZE-1:0]          radm_timeout_cpl_tag;
reg     [2:0]                   radm_timeout_cpl_tc;
reg     [1:0]                   radm_timeout_cpl_attr;

reg     [PF_WD-1:0]             radm_timeout_func_num;
reg     [11:0]                  radm_timeout_cpl_len;
wire    [FUNC_NUM_INDEX-1:0]    timeout_func_num;
wire                            timeout_valid;
wire    [NF-1:0]                cpl_pending_pf;
reg     [NF-1:0]                cpl_pending_pf_reg;
reg     [NF-1:0]                cpl_pending_pf_latch;
wire    [NF-1:0]                radm_cpl_pending;

wire    [FX_TLP-1:0]            flt_q_cpl_abort;

//If the completion is not the last one, then it should be dw aligned.
//Otherwise, it contains the bytes that is left in byte cnt.
wire    [FX_TLP-1:0]              cpl_eot;
wire    [FX_TLP-1:0]              cpl_last;
wire    [FX_TLP-1:0]              cpl_last_pipe;

np_req_type_t np_req_type;
np_req_type_t int_np_req_type;

reg     [CPL_ENTRY_WIDTH-1:0]     cpl_lut [CPL_LUT_DEPTH-1:0];
reg     [CPL_ENTRY_WIDTH2-1:0]    cpl_lut2 [CPL_LUT_DEPTH-1:0];

wire    [CPL_LUT_DEPTH_EXTERNAL-1:0] radm_cpl_lut_valid;      // completion lookup table valid indication

reg     [CPL_LUT_DEPTH-1:0]       valid;                      // Valid bits (per entry)
reg     [TIMEOUT_GRANULARITY-1:0] pertag_timer[CPL_LUT_DEPTH-1:0];  // Timeout values
reg     [CPL_TIMER_TW-1:0]        timer;
reg     [CPL_LUT_PTR_WD-1:0]      timeout_addr;
wire                              timeout_error;
wire                              timeout_error_wo_flr;             // Containts tag timeout information because timer timeout and no because FLR.
wire    [FX_TLP-1:0]              update_lut_content;
wire    [FX_TLP-1:0]              update_lut_content_pipe;
wire    [CPL_LUT_PTR_WD-1:0]      req_addr;
wire    [FX_TLP-1:0]              vendor_msg_id_match;
wire    [CPL_ENTRY_WIDTH-1:0]     timeout_vec;
wire    [CPL_ENTRY_WIDTH2-1:0]    timeout_vec2;

wire    [FX_TLP*CPL_LUT_PTR_WD-1:0] lut_addr;
wire    [CPL_ENTRY_WIDTH-1:0]     lut_vec[FX_TLP-1:0];
wire    [CPL_ENTRY_WIDTH2-1:0]    lut_vec2[FX_TLP-1:0];
wire                              timer_expired;
wire    [PF_WD-1:0]               timeout_pf;
wire                              flr_pf_reset;
wire                              flr_reset;
wire                              timer_freq;

wire   [31:0]                     wCPL_TIMEOUT_VALUE;
wire   [31:0]                     wCPL_TIMEOUT_VALUE_INT;
wire   [31:0]                     wCPL_TIMEOUT_VALUE_MPCIE;
wire   [31:0]                     wCM_CPL_BASE_TIMER_VALUE_RATEA;
wire   [31:0]                     wCM_CPL_BASE_TIMER_VALUE_RATEB;

assign wCM_CPL_BASE_TIMER_VALUE_RATEA = `CM_CPL_BASE_TIMER_VALUE_RATEA;
assign wCM_CPL_BASE_TIMER_VALUE_RATEB = `CM_CPL_BASE_TIMER_VALUE_RATEB;

assign wCPL_TIMEOUT_VALUE_MPCIE = 32'h0000_0000 ; // Not Used in Conventional PCIe.

assign wCPL_TIMEOUT_VALUE_INT = CPL_TIMEOUT_VALUE_INT;
assign wCPL_TIMEOUT_VALUE     =  (phy_type == `PHY_TYPE_MPCIE) ? wCPL_TIMEOUT_VALUE_MPCIE : wCPL_TIMEOUT_VALUE_INT ;

// @@@@@@@@@@@@@@@@@@@@
// @@@  PIPELINE    @@@
// @@@@@@@@@@@@@@@@@@@@

// ### Output signals from pipeline u_pipeline_lut_vec ###

reg    [FX_TLP*CPL_LUT_PTR_WD-1:0] lut_addr_reg;
reg    [FX_TLP*CPL_LUT_PTR_WD-1:0] update_lut_addr_pipe;
reg    [CPL_ENTRY_WIDTH-1:0]       lut_vec_reg[FX_TLP-1:0];
reg    [CPL_ENTRY_WIDTH2-1:0]      lut_vec2_reg[FX_TLP-1:0];

// ### Output signals from pipeline u_pipeline_rtlh_radm_bus ###
reg   [FX_TLP-1:0]         int_rtlh_radm_hv_reg;
reg   [(FX_TLP*(HW+HDR_PROT_WD))-1:0] int_rtlh_radm_hdr_reg;
reg   [FX_TLP-1:0]         int_rtlh_radm_eot_reg;
reg   [FX_TLP-1:0]         int_rtlh_radm_dllp_err_reg;  
reg   [FX_TLP-1:0]         int_rtlh_radm_ecrc_err_reg;  
reg   [FX_TLP-1:0]         int_rtlh_radm_malform_tlp_err_reg; 
wire  [FX_TLP-1:0]         radm_cpl_filter_malform_tlp_err;
wire  [RTLH_RADM_RID_WD-1:0]    int_rtlh_radm_ant_rid_reg;    
reg   [FX_TLP-1:0]         same_tag_reg;

// ----------------------------------------------------------
// Delay the xtlh interface, if doing rid_to_pfvf
// ----------------------------------------------------------
wire                           int_xtlh_xmt_tlp_done;          // transmitted TLP is done
wire   [11:0]                  int_xtlh_xmt_tlp_len_inbytes;   // transmitted TLP length in bytes
wire   [3:0]                   int_xtlh_xmt_tlp_first_be;      // transmitted TLP first be
wire                           int_xtlh_xmt_cfg_req;
wire                           int_xtlh_xmt_memrd_req;
wire   [TAG_SIZE-1:0]          int_xtlh_xmt_tlp_tag;           // transmitted TLP tag
wire   [1:0]                   int_xtlh_xmt_tlp_attr;          // transmitted TLP attibutes
wire   [2:0]                   int_xtlh_xmt_tlp_tc;            // transmitted TLP tc
wire  [PF_WD  - 1:0]           int_pf_from_rid;

wire  [PF_WD  - 1:0]           pf_from_rid;

wire [TAG_SIZE-1:0] xtlh_xmt_tlp_tag_mapped;
assign xtlh_xmt_tlp_tag_mapped[7:0] = xtlh_xmt_tlp_tag[7:0];

logic [NP_REQ_TYPE_DECODED_WD-1:0] np_req_vector;
always_comb begin
                              np_req_vector                      = '0;
                              np_req_vector[NP_REQ_MEMRD_INDEX]  = cfg_filter_rule_mask[`CX_FLT_UNMASK_ATS_SPECIFIC_RULES] ? xtlh_xmt_memrd_req && !xtlh_xmt_ats_req : xtlh_xmt_memrd_req;
         np_req_vector[NP_REQ_CFG_INDEX]    = xtlh_xmt_cfg_req; 
 
 

    np_req_type = radm_np_req_type_encode(np_req_vector);
end


assign  int_xtlh_xmt_tlp_done         = xtlh_xmt_tlp_done       ;
assign  int_xtlh_xmt_tlp_len_inbytes  = xtlh_xmt_tlp_len_inbytes;
assign  int_xtlh_xmt_tlp_first_be     = xtlh_xmt_tlp_first_be   ;
assign int_np_req_type = np_req_type;
assign  int_xtlh_xmt_tlp_attr         = xtlh_xmt_tlp_attr       ;
assign  int_xtlh_xmt_tlp_tc           = xtlh_xmt_tlp_tc         ;
assign  int_xtlh_xmt_tlp_tag          = xtlh_xmt_tlp_tag_mapped ; // ifndef CX_10BITS_TAG => xtlh_xmt_tlp_tag_mapped = xtlh_xmt_tlp_tag
assign  int_pf_from_rid               = pf_from_rid             ;

// ---------- external tlp interfaces targetted to application
assign radm_cpl_lut_valid       = valid;
wire    [CPL_ENTRY_WIDTH2-1:0]   update_lut_byte_cnt[FX_TLP-1:0];
wire    [CPL_ENTRY_WIDTH2-1:0]   update_lut_byte_cnt_pipe[FX_TLP-1:0];
// Lower address checking
// According to the spec, the Lower Address field is set to 0's for all
// types of Completions other than Memory Read Completions
wire [1:0]   lutin_low_addr;
// The lower address bits for the first byte of data to be returned
// Derived from the first_be see
// Table 2.32. Section 2.3.1.1 of PCIe base spec 2.1
assign lutin_low_addr[1:0] = (int_np_req_type==NP_REQ_MEMRD) ? 
    ((int_xtlh_xmt_tlp_first_be[1:0] == 2'b10   ? 2'b01 : 2'b00) |
    (int_xtlh_xmt_tlp_first_be[2:0] == 3'b100  ? 2'b10 : 2'b00) |
    (int_xtlh_xmt_tlp_first_be[3:0] == 4'b1000 ? 2'b11 : 2'b00)) :
    2'b00;



// ----------------------------------------------------------
// Completion Lookup Table Update Logic
// ----------------------------------------------------------
assign  req_addr                = int_xtlh_xmt_tlp_tag[CPL_LUT_PTR_WD-1:0];

wire  [FUNC_NUM_INDEX-1:0]  lutin_func;


assign  pf_from_rid = xtlh_xmt_tlp_req_id[FUNC_NUM_INDEX-1:0];
// there is a potential pipeline delay here
assign  lutin_func  = int_pf_from_rid;

reg [CPL_ENTRY_WIDTH-1:0]   lutin;
reg [CPL_ENTRY_WIDTH2-1:0]  lutin2;

always_comb begin
    lutin = {
             int_np_req_type,
             int_xtlh_xmt_tlp_attr, 
             int_xtlh_xmt_tlp_tc, 
             lutin_func};
    lutin2 = {int_xtlh_xmt_tlp_len_inbytes[11:0], lutin_low_addr};
end // always_comb

wire int_update_lut;
wire int_dont_update_lut;

// NP TLP transmitted update the LUT
assign int_update_lut = ( int_xtlh_xmt_tlp_done
           );

// NP TLP transmitted during FLR so dont update the LUT
assign int_dont_update_lut = int_xtlh_xmt_tlp_done
           ;

logic int_xtlh_xmt_tlp_done_d;
logic int_update_lut_d;
logic int_dont_update_lut_d;
logic [CPL_LUT_PTR_WD-1:0] req_addr_d;
logic [CPL_ENTRY_WIDTH-1:0] lutin_d;
logic [CPL_ENTRY_WIDTH2-1:0]  lutin2_d;
localparam XTLH_WRITE_TO_LUT_DELAY = 0;
delay_n

#(XTLH_WRITE_TO_LUT_DELAY, 1+1+1+CPL_LUT_PTR_WD+CPL_ENTRY_WIDTH + CPL_ENTRY_WIDTH2) u_xtlh_write_to_lut_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({int_xtlh_xmt_tlp_done, int_update_lut, int_dont_update_lut, req_addr, lutin ,lutin2}),
    .dout        ({int_xtlh_xmt_tlp_done_d, int_update_lut_d, int_dont_update_lut_d, req_addr_d, lutin_d ,lutin2_d})
);


// spyglass disable_block W468
// SMD: Variable/Signal 'cpl_lut' is indexed by 'req_addr' which cannot index the full range of this vector.
// SJ: The completion_lut (cpl_lut) is oversized by one location to facilitate a park location which should never be addressed. This is necessary//     due to the implementation chosen for the timeout feature. 'cpl_lut2', 'valid', 'valid_new' and 'pertag_timer' effected by the same error.
always @(posedge core_clk or negedge core_rst_n)
begin: LUT_PROCESS
integer i;
    if (!core_rst_n) begin
        // can't do this if the LUT is a RAM
        for (i=0; i<CPL_LUT_DEPTH; i=i+1) begin
           cpl_lut[i]   <= #TP 0;
           cpl_lut2[i]  <= #TP 0;
        end
    end else begin

        cpl_lut  <= #TP cpl_lut;
        cpl_lut2 <= #TP cpl_lut2;

        // update lut at address=req_addr=int_xtlh_xmt_tlp_tag
        if (int_update_lut_d) begin
            cpl_lut[req_addr_d] <= #TP lutin_d;
            cpl_lut2[req_addr_d] <= #TP lutin2_d;
           end
        // update lut at address=lut_addr
        // if storing byte count, update the table for each completion that is returned
        for(i=0;i<FX_TLP;i=i+1) begin
            if (update_lut_content_pipe[i]) begin
               cpl_lut2[update_lut_addr_pipe[i*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD]] <= #TP update_lut_byte_cnt_pipe[i];
            end
        end

    end
end

wire    [CPL_LUT_PTR_WD-1:0]     timeout_addr_reg;
wire                             timeout_valid_reg;
logic                            timeout_mask_valid;
logic                            timeout_going_to_clear_valid;



always_comb begin
    timeout_going_to_clear_valid = 0;
    for(int i=0;i<FX_TLP;i=i+1) begin
        if(update_lut_addr_pipe[i*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD] == timeout_addr_reg && update_lut_content_pipe[i] && cpl_last_pipe[i])begin
            timeout_going_to_clear_valid = 1;
        end
    end
    if (timeout_error
        ) begin
        timeout_going_to_clear_valid = 1;
    end
end // always_comb

always @(posedge core_clk or negedge core_rst_n)begin
    if(!core_rst_n)begin
        timeout_mask_valid <= #TP 0;
    end else begin
        timeout_mask_valid <= #TP (timeout_addr == timeout_addr_reg && timeout_going_to_clear_valid ) ? 1 : 0;
    end
end

always @(posedge core_clk or negedge core_rst_n)
begin: LUT_VALID_PROCESS
integer i;
    if (!core_rst_n) begin
        valid      <= #TP 0;
    end else begin
        // cpl received
        for(i=0;i<FX_TLP;i=i+1) begin
            if (update_lut_content_pipe[i] && cpl_last_pipe[i])  begin
                valid[update_lut_addr_pipe[i*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD]]  <= #TP 1'b0;
            end
        end

        // the timeout_addr_regess to the lut is based on the timer.
        // as long as there is a valid in the lut then the timer
        // will increment.

        // pertag timeout
        if (timeout_error
        ) begin
            valid[timeout_addr_reg]  <= #TP 1'b0;
        end

        // tlp transmitted towards wire
        if (int_update_lut_d) begin
            valid[req_addr_d] <= #TP 1'b1;
        end

    end
end

// ----------------------------------------------------------
// Completion Timeout Control Logic
// ----------------------------------------------------------
// use the lower bits of the base timer to loop through the cpl lut table
assign timeout_addr     = timer[CPL_LUT_PTR_WD-1:0];

// Fetch
assign timeout_vec      = cpl_lut[timeout_addr];  
assign timeout_vec2     = cpl_lut2[timeout_addr]; 
assign timeout_valid    = valid[timeout_addr]; // used as pre-condition for flr_reset

// Pipeline
wire    [CPL_ENTRY_WIDTH-1:0]     timeout_vec_reg;
wire    [CPL_ENTRY_WIDTH2-1:0]    timeout_vec2_reg;

localparam TIMEOUT_FETCH_PIPELINE = `CX_RADM_LUT_TO_FETCH_PIPE;
localparam TIMEOUT_FETCH_WIDTH = CPL_LUT_PTR_WD + CPL_ENTRY_WIDTH + 1
  + CPL_ENTRY_WIDTH2
;

delay_n

#(TIMEOUT_FETCH_PIPELINE, TIMEOUT_FETCH_WIDTH) u_timeout_fetch_pipe(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({timeout_addr, timeout_valid, timeout_vec2, timeout_vec}),
    .dout       ({timeout_addr_reg, timeout_valid_reg,  timeout_vec2_reg, timeout_vec_reg })
);


// Decode

assign timeout_func_num = timeout_vec_reg[FUNC_NUM_INDEX -1 : 0];

assign  timeout_pf = timeout_func_num;

// ### For timeout_err information is reading the actual version of valid[] to avoid that timeout_error lasts ###
// ### more than 1 cycle if the the timeout_addr increment 1 per 8 cycles...                                  ###
assign  timeout_error           =  (timeout_valid_reg
                                && !timeout_mask_valid
                                && (&pertag_timer[timeout_addr_reg])                       // timeout tag information because timer timeout(No FLR ENABLE)
                                && (~cfg_cpl_timeout_disable[timeout_pf]                   // not disabled
                                   ) )
                                ;

assign  timeout_error_wo_flr    =  (timeout_valid_reg
                                && !timeout_mask_valid
                                && (&pertag_timer[timeout_addr_reg])                       // tag timeout
                                && (~cfg_cpl_timeout_disable[timeout_pf] ) )               // not disabled
                                ;

// for 1s product at 250Mhz, base timer times out at 4ms based on current defines in adm_defs.vh
wire    [CPL_TIMER_TW-1:0]      cpl_timeout_value_wire;

assign  cpl_timeout_value_wire  = wCPL_TIMEOUT_VALUE -1;

assign  timer_expired           =
                                  (timer >= cpl_timeout_value_wire) & timer_freq;

DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1(0)
) u_gen_timer_freq
(
     .clk               (core_clk)
    ,.rst_n             (core_rst_n)

    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)
    
    ,.cnt_up_en         (timer_freq)  // timer count-up
);

// free running timer counts ticks of timer freq
// when a np tlp is sent by the XTLH clear the counter
// when the counter rolls over the signal to clear the cpl
// lut busy is toggled
reg [1:0] free_timer_r;
reg       int_cpl_lut_pending_r;

// needs to be clocked on ungated radm clock to ungate the clock when np request is received
always @(posedge radm_clk_ug or negedge core_rst_n) begin : free_timer_PROC
  if (!core_rst_n) begin
    free_timer_r <= #TP 2'b00;
    int_cpl_lut_pending_r <= #TP 1'b0;
  end else begin
    int_cpl_lut_pending_r <= #TP radm_cpl_lut_pending;
    if(xtlh_np_tlp_early)
      free_timer_r <= #TP 2'b00;
    else if(timer_freq)
      free_timer_r <= #TP (free_timer_r + 1'b1);
    else
      free_timer_r <= #TP free_timer_r;
  end
end : free_timer_PROC

assign int_clear_lut_pending = (free_timer_r == 2'b11);

// Generate a cpl lut pending indication
// this will be set when a np tlp is sent from layer3
// it remains set until the free running timer saturates
// this insures that a flag is asserted to indication cpl lut
// busy until the cpl lut pending flags would be updated
always @(*) begin : cpl_lut_pending_PROC
  if(xtlh_np_tlp_early)
    radm_cpl_lut_pending = 1'b1;
  else if(int_clear_lut_pending)
    radm_cpl_lut_pending = 1'b0;
  else
    radm_cpl_lut_pending = int_cpl_lut_pending_r;
end : cpl_lut_pending_PROC

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        timer     <= #TP 0;
    end else if (((~(|valid))
                 ) || timer_expired) begin
        timer     <= #TP 0;
    end else begin
        timer     <= #TP timer + (timer_freq ? 1'b1 : 1'b0);
    end
end

wire   timer_expired_incr;
reg    timer_expired_window;
// make sure that each cycle of the timer is a full two clocks
assign timer_expired_incr = timer_expired_window & timer_freq;

// use the timer to create a window as wide as the number of entries in the table
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        timer_expired_window     <= #TP 0;
    end else if (timer_expired) begin
        timer_expired_window     <= #TP 1;
    end else if ((&timer[CPL_LUT_PTR_WD-1:0]) & timer_expired_incr) begin
        timer_expired_window     <= #TP 0;
    end
end


always @(posedge core_clk or negedge core_rst_n)
begin: TRANSACTION_TIMEOUT_PROCESS
integer i;
    if (!core_rst_n) begin
        // can't do this if the TIMER is a RAM
        for (i=0; i<CPL_LUT_DEPTH; i=i+1)
            pertag_timer[i]     <= #TP 0;
    end else begin

      pertag_timer <= #TP pertag_timer;

      if (rstctl_core_flush_req) begin
        // Time out all pending NP requests
        if (valid[timeout_addr_reg]) begin
          pertag_timer[timeout_addr_reg] <= # TP {TIMEOUT_GRANULARITY{1'b1}};
        end
      end else begin

        // timer timeout occurred
        if (valid[timeout_addr_reg] && timer_expired_incr
        )
            pertag_timer[timeout_addr_reg] <= #TP  pertag_timer[timeout_addr_reg] + 1'b1;


        // completion timeout occured
        if (timeout_error)
            pertag_timer[timeout_addr_reg] <= #TP 0;

        // new entry
        if (int_xtlh_xmt_tlp_done_d)
            pertag_timer[req_addr_d] <= #TP 0;

      end
    end
end

assign  cpl_pending_pf = check_radm_cpl_pending_pf(cpl_pending_pf_reg,timeout_addr_reg,timer_freq,(timeout_valid_reg && !timeout_mask_valid),timeout_vec_reg);
assign radm_cpl_lut_busy = (|cpl_pending_pf_reg) || (|cpl_pending_pf_latch);
// spyglass enable_block W468 

// register the combinatorial cpl_pending flags and periodically latch the result to the CDM
always @(posedge core_clk or negedge core_rst_n)
begin : CPL_PENDING_PF_PROCESS
integer i;
    if (!core_rst_n) begin
        cpl_pending_pf_reg <= #TP 0;
        cpl_pending_pf_latch <= #TP 0;
    end else begin
        for (i=0; i<NF; i=i+1) begin
            begin
                cpl_pending_pf_reg[i] <= #TP cpl_pending_pf[i];
                if ((timeout_addr==0) && timer_freq) begin
                    cpl_pending_pf_latch[i]  <= #TP cpl_pending_pf_reg[i];
                end
            end
        end // for ...
    end
end

assign radm_cpl_pending = cpl_pending_pf_latch;

always @(posedge core_clk or negedge core_rst_n)
begin: OUTPUT_CONTROL_DRIVE_PROCESS
    if (!core_rst_n) begin
        radm_cpl_timeout        <= #TP 0;
        radm_cpl_timeout_cdm    <= #TP 0;
        radm_timeout_func_num   <= #TP 0;
        radm_timeout_cpl_tag    <= #TP 0;
        radm_timeout_cpl_attr   <= #TP 0;
        radm_timeout_cpl_tc     <= #TP 0;
        radm_timeout_cpl_len    <= #TP 0;

    end else begin
        radm_cpl_timeout        <= #TP timeout_error ; 
        radm_cpl_timeout_cdm    <= #TP timeout_error_wo_flr ; // timeout errors wo flr(timeouts) is 
                                                              // now connected to the CDM.input instead radm_cpl_timeout to avoid indicate 
                                                              // timeout error in the cdm because the flr information of the tag released
        radm_timeout_cpl_tag    <= #TP {TAG_SIZE{1'b0}};
        radm_timeout_cpl_tag[CPL_LUT_PTR_WD-1:0]    <= #TP timeout_addr_reg;
        radm_timeout_cpl_attr   <= #TP timeout_vec_reg[ATTR_INDEX-1: TC_INDEX];
        radm_timeout_cpl_tc     <= #TP timeout_vec_reg[TC_INDEX-1 : BYTECNT_INDEX];
        radm_timeout_func_num   <= #TP timeout_pf;
        radm_timeout_cpl_len    <= #TP timeout_vec2_reg[BYTECNT_INDEX2+BYTECNT_WD2-1 : BYTECNT_INDEX2];
    end
end

// Figure out when the LUT Filters are looking at the same tag. Each filter
// tag is compared to the tag of the filter below it. filter 0 is compared
// with filter FX_TLP-1.
// For the case of two filters
// lut_addr[0] is compared with lut_addr[1] to give same_tag[0]
// lut_addr[1] is compared with lut_addr[0] to give same_tag[1]
// Each filter gets it's own same_tag bit as an input
reg     [FX_TLP-1:0] same_tag;
// The received Byte length from the first filter needs to be passed into the other filter
// when two filters are looking at the same tag. Any filter can be the
// first filter depending on the formation bit(form_filt_formation).
// The next_byte_len output from one filter is passed to the prev_byte_len input
// of the next.
reg     [13*FX_TLP-1:0] prev_byte_len;
wire    [13*FX_TLP-1:0] next_byte_len;

// mask same tag when the first filter has a cpl_abort.
reg   [FX_TLP-1:0]   prev_cpl_abort;
wire  [FX_TLP-1:0]   next_cpl_abort;

// When one filter detects that a completion is the last it needs to tell its
// neighbour that the completion it has isn't valid if it has the same tag.
// Also when both filters are looking at the same tag only the later of
// the two should do update_lut_content. use prev_cpl_last input to filter for
// this.
// Completions can be checked for byte count on hv, if the byte count is
// incorrect the completion can be ruled out and aborted immediately. When
// looking at two completions with the same tag this applies to the eot of
// one TLP overlapping with the hv of the second.
// This also covers the case when the second TLP is single cycle and the eot
// of this TLP also occurs in that cycle.
reg     [FX_TLP-1:0] prev_cpl_last;

wire   [FX_TLP-1:0]         int_rtlh_radm_hv;               // When asserted; indicates the hdr valid
wire   [FX_TLP-1:0]         int_rtlh_radm_eot;              // When asserted; indicates the tlp end
always @(*) begin : FILTER_INTERCONNECT
    integer i;
    prev_cpl_abort[0] = 0;
    same_tag[0] = 0;
    prev_byte_len[0 +: 13] = 0;
    prev_cpl_last[0] = 0;
    if(FX_TLP > 1) begin
        for(i = 1; i < FX_TLP; i = i + 1) begin
            same_tag[i] = 
                // cpl_tlp[i] && cpl_tlp[i-1] && // ### Done after REG[same_tag] since cpl_tlp is output of radm_filter* already delayed
                lut_addr[i*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD] == lut_addr[CPL_LUT_PTR_WD*(i-1) +: CPL_LUT_PTR_WD] &&
                int_rtlh_radm_hv[i] && int_rtlh_radm_eot[i-1] &&
                !rtlh_radm_dllp_err[i] && !rtlh_radm_dllp_err[i-1] &&
                !rtlh_radm_malform_tlp_err[i] && !rtlh_radm_malform_tlp_err[i-1] &&
                !rtlh_radm_ecrc_err[i] && !rtlh_radm_ecrc_err[i-1];
            prev_byte_len[13*i +: 13] = next_byte_len[13*(i-1) +: 13];
            prev_cpl_last[i] = cpl_last[i-1];
            prev_cpl_abort[i] = next_cpl_abort[i-1];
        end
    end
end

// cross connect the filter io based on the formation bit.
wire   [FX_TLP-1:0]         int_cpl_tlp;
wire   [(FX_TLP*3)-1:0]     int_cpl_status;
wire   [FX_TLP-1:0]         int_dwlenEq0;
wire   [(FX_TLP*3)-1:0]     int_flt_q_tlp_type;             // one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ flt_q_hv
wire   [(FX_TLP*(HW+HDR_PROT_WD))-1:0] int_rtlh_radm_hdr;      // hdr payload
wire   [FX_TLP-1:0]         int_rtlh_radm_dllp_err;         // Indication that TLP has dllp err (valid @ EOT)
wire   [FX_TLP-1:0]         int_rtlh_radm_malform_tlp_err;  // Indication that TLP is malformed (valid @ HV)
wire   [FX_TLP-1:0]         int_rtlh_radm_ecrc_err;         // Indication that TLP has ECRC err (valid @ EOT)
wire   [RTLH_RADM_RID_WD-1:0]    int_rtlh_radm_ant_rid;     // anticipated RID (1 clock earlier)

wire  [FX_TLP-1:0]          int_vendor_msg_id_match;
wire  [FX_TLP-1:0]          int_flt_q_cpl_abort;
wire  [FX_TLP-1:0]          int_flt_q_cpl_last;
wire  [FX_TLP-1:0]          int_cpl_mlf_err;
wire  [FX_TLP-1:0]          int_cpl_ur_err;
wire  [FX_TLP-1:0]          int_cpl_ca_err;
wire  [FX_TLP-1:0]          int_unexpected_cpl_err;
assign int_cpl_tlp = cpl_tlp;
assign int_cpl_status = cpl_status;
assign int_dwlenEq0 = dwlenEq0;
assign int_flt_q_tlp_type = flt_q_tlp_type;             // one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ flt_q_hv
assign int_rtlh_radm_hv = rtlh_radm_hv;               // When asserted; indicates the hdr valid
assign int_rtlh_radm_hdr = rtlh_radm_hdr;      // hdr payload
assign int_rtlh_radm_eot = rtlh_radm_eot;              // When asserted; indicates the tlp end
assign int_rtlh_radm_dllp_err = rtlh_radm_dllp_err;         // Indication that TLP has dllp err (valid @ EOT)
assign int_rtlh_radm_malform_tlp_err = rtlh_radm_malform_tlp_err;  // Indication that TLP is malformed (valid @ HV)
assign int_rtlh_radm_ecrc_err = rtlh_radm_ecrc_err;         // Indication that TLP has ECRC err (valid @ EOT)
assign int_rtlh_radm_ant_rid = rtlh_radm_ant_rid;     // anticipated RID (1 clock earlier)

assign vendor_msg_id_match = int_vendor_msg_id_match;
assign flt_q_cpl_abort = int_flt_q_cpl_abort;
assign flt_q_cpl_last = int_flt_q_cpl_last;
assign cpl_mlf_err = int_cpl_mlf_err;
assign cpl_ur_err = int_cpl_ur_err;
assign cpl_ca_err = int_cpl_ca_err;
assign unexpected_cpl_err = int_unexpected_cpl_err;

parameter RTLH_RADM_IN_WD   = (1 + (HW+HDR_PROT_WD) + 4 + 1);
parameter LUT_VEC_WD        = ( FX_TLP*CPL_LUT_PTR_WD + FX_TLP*CPL_ENTRY_WIDTH + FX_TLP*CPL_ENTRY_WIDTH2 + FX_TLP*NP_REQ_TYPE_DECODED_WD)/FX_TLP;

wire [CPL_LUT_DEPTH-1:0]   valid_at_hv[FX_TLP-1:0];
reg  [CPL_LUT_DEPTH-1:0]   valid_reg[FX_TLP-1:0];


wire [RTLH_RADM_IN_WD-1:0] rtlh_radm_pipe_in[FX_TLP-1:0];
reg  [RTLH_RADM_IN_WD-1:0] rtlh_radm_pipe_out[FX_TLP-1:0];

reg  [FX_TLP-1:0]          int_same_tag_reg;

wire [LUT_VEC_WD-1:0]      lut_vec_pipe_in[FX_TLP-1:0];
reg  [LUT_VEC_WD-1:0]      lut_vec_pipe_out[FX_TLP-1:0];

parameter UPDATE_VEC_WD = CPL_LUT_PTR_WD + 1 + 1 + CPL_ENTRY_WIDTH2 ;
wire [UPDATE_VEC_WD-1:0]      update_pipe_in[FX_TLP-1:0];
reg  [UPDATE_VEC_WD-1:0]      update_pipe_out[FX_TLP-1:0];

logic[FX_TLP-1:0][NP_REQ_TYPE_DECODED_WD-1:0] lut_np_req_type_decoded;
logic[FX_TLP-1:0][NP_REQ_TYPE_DECODED_WD-1:0] lut_np_req_type_decoded_reg;

genvar num_tlp; 
generate
for (num_tlp=0; num_tlp<FX_TLP; num_tlp = num_tlp+1) begin : u_radm_cpl_filter_gen

    
    
always @(posedge core_clk or negedge core_rst_n)
begin : VALID_REG
integer i;
    if (!core_rst_n) begin
        valid_reg[num_tlp] <= #TP 0;
    end else if(int_rtlh_radm_hv_reg[num_tlp]) begin
        valid_reg[num_tlp] <= #TP valid;
    end
end

assign valid_at_hv[num_tlp] = (int_rtlh_radm_hv_reg[num_tlp]) ? valid : valid_reg[num_tlp];
    
radm_cpl_lut_vec_extractor

#(    .INST (INST),
      .CPL_ENTRY_WIDTH(CPL_ENTRY_WIDTH),
      .RADM_CPL_LUT_PIPE_EN(RADM_CPL_LUT_PIPE_EN),
      .RADM_FILTER_TO_LUT_PIPE(RADM_FILTER_TO_LUT_PIPE),
      .NP_REQ_TYPE_INDEX(NP_REQ_TYPE_INDEX)
      )
u_radm_cpl_lut_vec_extractor (
// ---- inputs ---------------
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .rtlh_radm_hdr              (int_rtlh_radm_hdr[((HW+HDR_PROT_WD)*(num_tlp+1))-1:(HW+HDR_PROT_WD)*num_tlp]),
    .cpl_lut                    (cpl_lut), 
    .cpl_lut2                   (cpl_lut2), 

// ---- outputs ---------------
    .lut_addr                   (lut_addr[num_tlp*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD]),
    .lut_vec                    (lut_vec[num_tlp])
   ,.lut_vec2                   (lut_vec2[num_tlp])

);

// @@@@@@@@@@@@@@@@@@@@
// @@@   PIPELINE   @@@
// @@@@@@@@@@@@@@@@@@@@

assign rtlh_radm_pipe_in[num_tlp] = {
    int_rtlh_radm_hv[num_tlp],
    int_rtlh_radm_hdr[((HW+HDR_PROT_WD)*(num_tlp+1))-1:(HW+HDR_PROT_WD)*num_tlp],
    int_rtlh_radm_eot[num_tlp],
    int_rtlh_radm_dllp_err[num_tlp],
    int_rtlh_radm_ecrc_err[num_tlp],
    int_rtlh_radm_malform_tlp_err[num_tlp],
    same_tag[num_tlp]
    };

    delay_n_w_enable
    
    #(RADM_CPL_LUT_PIPE_EN, RTLH_RADM_IN_WD) u_pipeline_rtlh_radm_bus(
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .en         (1'b1), 
        .din        (rtlh_radm_pipe_in[num_tlp]),
        .dout       (rtlh_radm_pipe_out[num_tlp])
    );

    delay_n_w_enable
    
    #(RADM_CPL_LUT_PIPE_EN, RADM_ANT_PIPE_WD) u_pipeline_rtlh_radm_ant_rid(
        .clk        (radm_clk_ug),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .en         (1'b1), 
        .din        (int_rtlh_radm_ant_rid[16*(num_tlp+1)-1:16*num_tlp]),
        .dout       (int_rtlh_radm_ant_rid_reg[16*(num_tlp+1)-1:16*num_tlp])
    );

assign {
    int_rtlh_radm_hv_reg[num_tlp],
    int_rtlh_radm_hdr_reg[((HW+HDR_PROT_WD)*(num_tlp+1))-1:(HW+HDR_PROT_WD)*num_tlp],
    int_rtlh_radm_eot_reg[num_tlp],
    int_rtlh_radm_dllp_err_reg[num_tlp],
    int_rtlh_radm_ecrc_err_reg[num_tlp],
    int_rtlh_radm_malform_tlp_err_reg[num_tlp],
    same_tag_reg[num_tlp]
    } = rtlh_radm_pipe_out[num_tlp];

assign radm_cpl_filter_malform_tlp_err[num_tlp] = int_rtlh_radm_malform_tlp_err_reg[num_tlp];

assign int_same_tag_reg[num_tlp] = 1'b0;

assign lut_np_req_type_decoded[num_tlp] = radm_np_req_type_decode(np_req_type_t'(lut_vec[num_tlp][NP_REQ_TYPE_INDEX-1:ATTR_INDEX]));    
    
assign lut_vec_pipe_in[num_tlp] = {
        lut_addr[num_tlp*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD],
        lut_vec[num_tlp],
        lut_np_req_type_decoded[num_tlp]                           
       ,lut_vec2[num_tlp]
    };

    delay_n_w_enable
    
    #(RADM_CPL_LUT_PIPE_EN, LUT_VEC_WD) u_pipeline_lut_vec(
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .en         (1'b1),
        .din        (lut_vec_pipe_in[num_tlp]),
        .dout       (lut_vec_pipe_out[num_tlp])
    );
    
assign {
        lut_addr_reg[num_tlp*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD],
        lut_vec_reg[num_tlp],
        lut_np_req_type_decoded_reg[num_tlp]
       ,lut_vec2_reg[num_tlp]
        } = lut_vec_pipe_out[num_tlp];


    assign update_pipe_in[num_tlp] = {
        lut_addr_reg[num_tlp*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD],
        cpl_last[num_tlp],
        update_lut_content[num_tlp]                             
        ,update_lut_byte_cnt[num_tlp]
    };

    delay_n
    
    #(RADM_FILTER_TO_LUT_PIPE, UPDATE_VEC_WD) u_pipeline_update_vec(
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .din        (update_pipe_in[num_tlp]),
        .dout       (update_pipe_out[num_tlp])
    );
    
    assign  {
        update_lut_addr_pipe[num_tlp*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD],
        cpl_last_pipe[num_tlp],
        update_lut_content_pipe[num_tlp]                             
        ,update_lut_byte_cnt_pipe[num_tlp]
    } = update_pipe_out[num_tlp];


// @@@@@@@@@@@@@@@@@@@@
// @@@ END PIPELINE @@@
// @@@@@@@@@@@@@@@@@@@@

radm_cpl_filter

#(    .INST (INST),
      .CPL_ENTRY_WIDTH(CPL_ENTRY_WIDTH),
      .FLT_NUM(num_tlp),
      .RADM_FILTER_TO_LUT_PIPE(RADM_FILTER_TO_LUT_PIPE),
      .NP_REQ_TYPE_INDEX(NP_REQ_TYPE_INDEX)
      )
u_radm_cpl_filter (
// ---- inputs ---------------
    .core_clk                   (core_clk),
    .radm_clk_ug                (radm_clk_ug),
    .core_rst_n                 (core_rst_n),
    .device_type                (device_type),

    .cfg_filter_rule_mask       (cfg_filter_rule_mask),
    .cfg_pbus_dev_num           (cfg_pbus_dev_num),
    .cfg_pbus_num               (cfg_pbus_num),
    .cfg_p2p_track_cpl_to       (cfg_p2p_track_cpl_to),
    .cfg_p2p_err_rpt_ctrl       (cfg_p2p_err_rpt_ctrl),
    .cpl_tlp                    (int_cpl_tlp[num_tlp]), // ###  already delayed via form_filt pipe
    .cpl_status                 (int_cpl_status[3*(num_tlp+1)-1:3*num_tlp]),
    .dwlenEq0                   (int_dwlenEq0[num_tlp]),
    .flt_q_tlp_type             (3'b0),                 // ### Not used
    .rtlh_radm_hdr              (int_rtlh_radm_hdr_reg[((HW+HDR_PROT_WD)*(num_tlp+1))-1:(HW+HDR_PROT_WD)*num_tlp]),
    .rtlh_radm_eot              (int_rtlh_radm_eot_reg[num_tlp]),
    .rtlh_radm_dllp_err         (int_rtlh_radm_dllp_err_reg[num_tlp]),
    .rtlh_radm_ecrc_err         (int_rtlh_radm_ecrc_err_reg[num_tlp]),
    .rtlh_radm_malform_tlp_err  (radm_cpl_filter_malform_tlp_err[num_tlp]),
    .rtlh_radm_ant_rid          (int_rtlh_radm_ant_rid_reg[16*(num_tlp+1)-1:16*num_tlp]),
    .lut_np_req_type_decoded    (lut_np_req_type_decoded_reg[num_tlp]),
    .lut_vec                    (lut_vec_reg[num_tlp]), 
    .lut_vec2                   (lut_vec2_reg[num_tlp]),
    .valid                      (valid_at_hv[num_tlp]),                  
    .same_tag                   (int_same_tag_reg[num_tlp]),
    .prev_byte_len              (prev_byte_len[13*num_tlp +: 13]),
    .prev_cpl_last              (prev_cpl_last[num_tlp]),
    .prev_cpl_abort             (prev_cpl_abort[num_tlp]),
// ---- outputs ---------------
    .update_lut_content         (update_lut_content[num_tlp]),
    .lut_addr                   (), 
    .cpl_last                   (cpl_last[num_tlp]),
    .cpl_eot                    (cpl_eot[num_tlp]),
    .update_lut_byte_cnt        (update_lut_byte_cnt[num_tlp]),
    .vendor_msg_id_match        (int_vendor_msg_id_match[num_tlp]),
    .flt_q_cpl_abort            (int_flt_q_cpl_abort[num_tlp]),
    .flt_q_cpl_last             (int_flt_q_cpl_last[num_tlp]),
    .cpl_mlf_err                (int_cpl_mlf_err[num_tlp]),
    .cpl_ur_err                 (int_cpl_ur_err[num_tlp]),
    .cpl_ca_err                 (int_cpl_ca_err[num_tlp]),
    .unexpected_cpl_err         (int_unexpected_cpl_err[num_tlp]),
    .next_byte_len              (next_byte_len[13*num_tlp +: 13]),
    .next_cpl_abort             (next_cpl_abort[num_tlp])

);
end
endgenerate


function automatic [NF-1 : 0 ] check_radm_cpl_pending_pf;
input [NF-1:0]             cpl_pending_pf;
input [CPL_LUT_PTR_WD-1:0]  timeout_addr;
input                       timer_freq;
input                       valid;                      // Valid bits (per entry)
input [CPL_ENTRY_WIDTH-1:0] lut_entry;

integer                    i;
reg [NF-1:0]              local_cpl_pending_pf;
reg [PF_WD-1:0]           local_func_num_pf;

begin
    if ((timeout_addr==0) && timer_freq) begin
      local_cpl_pending_pf = {NF{1'b0}};
    end else begin
      local_cpl_pending_pf = cpl_pending_pf;
    end

    local_func_num_pf = lut_entry[FUNC_NUM_INDEX-1:0];

    for (i=0; i<NF; i=i+1) begin
      if (i==local_func_num_pf) local_cpl_pending_pf[i] = local_cpl_pending_pf[i] | valid;
    end

    check_radm_cpl_pending_pf = local_cpl_pending_pf;
end
endfunction





//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// System Verilog Assertions.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

endmodule
