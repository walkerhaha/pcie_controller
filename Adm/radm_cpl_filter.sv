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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_cpl_filter.sv#13 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Filters received completions based on contents of RADM CPL LUT
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Adm/radm_defs_pkg.svh"

 
module radm_cpl_filter
import radm_defs_pkg::*;
(
// ---- inputs ---------------
    core_clk,
    radm_clk_ug,
    core_rst_n,
    device_type,
    cfg_filter_rule_mask,
    cfg_pbus_dev_num,
    cfg_pbus_num,
    cfg_p2p_track_cpl_to,
    cfg_p2p_err_rpt_ctrl,
    cpl_tlp,
    cpl_status,
    dwlenEq0,
    flt_q_tlp_type,
    rtlh_radm_hdr,
    rtlh_radm_eot,
    rtlh_radm_dllp_err,
    rtlh_radm_ecrc_err,
    rtlh_radm_malform_tlp_err,
    rtlh_radm_ant_rid,
    lut_np_req_type_decoded,
    lut_vec,
    lut_vec2,
    valid,
    same_tag,
    prev_byte_len,
    prev_cpl_last,
    prev_cpl_abort,
// ---- outputs ---------------
    update_lut_content,
    lut_addr,
    cpl_last,
    cpl_eot,
    update_lut_byte_cnt,
    vendor_msg_id_match,
    flt_q_cpl_abort,
    flt_q_cpl_last,
    cpl_mlf_err,
    cpl_ur_err,
    cpl_ca_err,
    unexpected_cpl_err,
    next_byte_len,
    next_cpl_abort

);


localparam TAG_SIZE               = `CX_TAG_SIZE;

parameter INST                    = 1'b0;

parameter NB                      = `CX_NB;                 // Number of symbols (bytes) per clock cycle
parameter CPL_LUT_DEPTH           = `CX_MAX_TAG + 1;        // number of max tag that this core is configured to run

parameter NF                      = `CX_NFUNC;              // Number of Physical Functions
parameter NVF                     = `CX_NVFUNC;             // Number of virtual functions
parameter NW                      = `CX_NW;                 // Number of Dwords in datapath
localparam FX_TLP                 = `CX_FX_TLP;             // Number of TLPs that can be processed in a single cycle after the formation block
localparam PF_WD                  = `CX_NFUNC_WD;           // Number of bits needed to address the physical functions
localparam VFI_WD                 = `CX_LOGBASE2(NVF);      // number of bits needed to represent the vf index [0 ... NVF-1]
localparam VF_WD                  = `CX_LOGBASE2(NVF) + 1;  // number of bits needed to represent the vf number plus one bit to indicate vf_active, i.e. if the pf,vf pair indicates a pf only or a vf within a pf
parameter FUNC_NUM_INDEX          =  PF_WD;
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

parameter TP                      = `TP;                      // Clock to Q delay (simulator insurance)
parameter BUSNUM_WD               = `CX_BUSNUM_WD;            // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD               = `CX_DEVNUM_WD;            // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter HW                      = 128;                      // Width of header in bits.
// Width of the header protection bus. 0 if RAS is not enabled!
parameter HDR_PROT_WD             = `CX_RAS_PCIE_HDR_PROT_WD;

parameter P_TYPE                  = 0;
parameter NP_TYPE                 = 1;
parameter CPL_TYPE                = 2;
parameter N_FLT_MASK              = `CX_N_FLT_MASK;
parameter FLT_NUM                 = 0;
parameter RADM_FILTER_TO_LUT_PIPE = 0;

// ---- inputs ---------------
input                           core_clk;
input                           radm_clk_ug;                // radm clock ungated for rid
input                           core_rst_n;
input   [3:0]                   device_type;                // "static"
input   [N_FLT_MASK-1:0]        cfg_filter_rule_mask;       // "static" // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
input   [DEVNUM_WD -1:0]        cfg_pbus_dev_num;           // "static" // Device number
input   [BUSNUM_WD -1:0]        cfg_pbus_num;               // "static" // Bus number
input                           cfg_p2p_track_cpl_to;       // 0: by default, do not track cpl in lut for P2P; 1: track cpl in lut for P2P
input                           cfg_p2p_err_rpt_ctrl;       // 1: by default, P2P error reporting enable; 0: P2P error reporting disable
input                           cpl_tlp;
input   [2:0]                   cpl_status;
input                           dwlenEq0;
input   [2:0]                   flt_q_tlp_type;             // one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ flt_q_hv
input   [HW+HDR_PROT_WD-1:0]    rtlh_radm_hdr;
input                           rtlh_radm_eot;
input                           rtlh_radm_dllp_err;         // Recall packet (Malformed TLP, etc.)
input                           rtlh_radm_ecrc_err;
input                           rtlh_radm_malform_tlp_err;  // Recall packet (Malformed TLP, etc.)
input   [15:0]                  rtlh_radm_ant_rid;          // anticipated RID (1 clock earlier)
input   [NP_REQ_TYPE_DECODED_WD-1:0]   lut_np_req_type_decoded;
input   [CPL_ENTRY_WIDTH-1:0]   lut_vec;
input   [CPL_ENTRY_WIDTH2-1:0]  lut_vec2;
input   [CPL_LUT_DEPTH-1:0]     valid;                      // Valid bits (per entry)
input                           same_tag;
input   [12:0]                  prev_byte_len;
input                           prev_cpl_last;
input                           prev_cpl_abort;


// ---- outputs ---------------
output                          update_lut_content;
output  [CPL_LUT_PTR_WD-1:0]    lut_addr;
output                          cpl_last;
output                          cpl_eot;
output  [CPL_ENTRY_WIDTH2-1:0]   update_lut_byte_cnt;
output                          vendor_msg_id_match;
output                          flt_q_cpl_abort;
output                          flt_q_cpl_last;
output                          cpl_mlf_err;
output                          cpl_ur_err;
output                          cpl_ca_err;
output                          unexpected_cpl_err;
output [12:0]                   next_byte_len;
output                          next_cpl_abort;

wire                            cpl_bcm;
wire    [15:0]                  cpl_reqid;
wire    [9:0]                   dw_len;
wire    [TAG_SIZE-1:0]          rcvd_cpl_tlp_tag;
wire    [12:0]                  rcvd_tlp_byte_cnt;
wire    [6:0]                   rcvd_tlp_low_addr;
wire    [2:0]                   tc;
wire    [1:0]                   attr;
reg                             flt_q_cpl_abort;
reg                             flt_q_cpl_last;
wire    [PF_WD-1:0]             lut_pfuncid;
wire    [CPL_LUT_PTR_WD-1:0]    lut_addr;
wire    [1:0]                   lut_attr;
wire    [2:0]                   lut_tc;
wire    [12:0]                  curnt_tlp_byte_len;
wire                            func_match;
wire                            reqid_match;
wire                            int_reqid_match;
wire                            reqid_match_lut;

// Extract fields from Completion Header
assign cpl_bcm                  =   rtlh_radm_hdr[52];
assign cpl_reqid                =  {rtlh_radm_hdr[71:64], rtlh_radm_hdr[79:72]};
assign dw_len                   =  {rtlh_radm_hdr[17:16], rtlh_radm_hdr[31:24]};
assign rcvd_cpl_tlp_tag         =  rtlh_radm_hdr[87:80];
assign rcvd_tlp_byte_cnt[11:0]  =  {rtlh_radm_hdr[51:48], rtlh_radm_hdr[63:56]};
assign rcvd_tlp_byte_cnt[12]    =  !(|rcvd_tlp_byte_cnt[11:0]);
assign rcvd_tlp_low_addr        =   rtlh_radm_hdr[94:88];
assign tc                       =   rtlh_radm_hdr[14:12];
assign attr                     =   rtlh_radm_hdr[21:20];

// Extract LUT Address
assign  lut_addr                    = rcvd_cpl_tlp_tag[CPL_LUT_PTR_WD -1:0];


wire np_req_is_a_memrd  = lut_np_req_type_decoded[NP_REQ_MEMRD_INDEX];
wire np_req_is_a_io     = lut_np_req_type_decoded[NP_REQ_IO_INDEX];
       wire np_req_is_a_cfg    = lut_np_req_type_decoded[NP_REQ_CFG_INDEX];



wire np_req_is_a_memrd_or_dmwr = np_req_is_a_memrd;
wire np_req_is_a_cfg_or_dmwr   = np_req_is_a_cfg ;

// ----------------------------------------------------------
// Decode Logic
// ----------------------------------------------------------
//
wire                            status_sc;
wire                            status_ur;
wire                            status_ca;
wire                            status_crs;
wire                            reserved_status;
wire    [1:0]                   byte_offset;

assign  status_sc               = (cpl_status == `SU_CPL_STATUS);  // Successful  Completion
assign  status_ur               = (cpl_status == `UR_CPL_STATUS);  // Unsupported Request
assign  status_ca               = (cpl_status == `CA_CPL_STATUS);  // Completion  Abort
assign  status_crs              = (cpl_status == `CRS_CPL_STATUS); // Request Retry Status
assign  reserved_status         = !(status_sc  || status_ur  || status_ca  || status_crs);

assign  byte_offset[0]          =  rcvd_tlp_low_addr[0] ;
assign  byte_offset[1]          =  (rcvd_tlp_low_addr[0] ^ rcvd_tlp_low_addr[1]) ; // (3'b100 - {1'b0, rcvd_tlp_low_addr[1:0]});

assign  curnt_tlp_byte_len      = (|byte_offset) ? {({dwlenEq0,dw_len} - 1'b1), byte_offset} :  {dwlenEq0,dw_len, byte_offset}; // (0 value means 4K)


assign  cpl_eot                 = cpl_tlp && rtlh_radm_eot;


assign  cpl_last                = ((curnt_tlp_byte_len >= rcvd_tlp_byte_cnt) & !cpl_bcm) | !status_sc
                                  ;
wire                            byte_cnt_match;
wire                            low_addr_match;
wire                            last_filter;
// When two CMPLT_D TLPs with the same tag are received together and this is
// the second TLP add the byte_length of the first TLP to the Byte Count we
// received in this TLP. It seems we are adding two different quantities since
// a byte count is normally total outstanding byte count for this
// request(unless BCM is set) and the byte length is the actual number of
// completion bytes in the TLP.
// However when checking that the byte count of a completion matches we need
// to check that byte count stored in the LUT is the same as the byte count
// received in the TLP. In the case where two TLPs are received the last
// filter must adjust it's received byte count by the amount of data received
// in the first completion before checking against the value stored in the
// LUT.
wire [12:0] total_rcvd_byte_cnt;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is has already been expanded to 13 bits to account for
// overflow. The maximum byte count is 4096.
assign total_rcvd_byte_cnt = (same_tag && !prev_cpl_abort && last_filter) ?
    prev_byte_len + rcvd_tlp_byte_cnt :
    rcvd_tlp_byte_cnt;
// spyglass enable_block W164a

assign  last_filter = FLT_NUM == FX_TLP - 1;
wire    [1:0]                   lut_low_addr;
wire    [12:0]                  remain_byte_cnt;
wire    [11:0]                  stored_byte_cnt;
wire    [CPL_ENTRY_WIDTH2-1:0]  update_lut_byte_cnt;
wire    [1:0]                   next_low_addr;

assign next_low_addr            = 2'b0;

assign stored_byte_cnt          = lut_vec2[BYTECNT_INDEX2+BYTECNT_WD2-1 : BYTECNT_INDEX2];

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: 'remain_byte_cnt' logic should perhaps be expanded to 14-bit to account for overflow 
assign remain_byte_cnt          = cpl_bcm ?
    ({1'b0, stored_byte_cnt} - {1'b0, total_rcvd_byte_cnt[11:0]}) :
    rcvd_tlp_byte_cnt - curnt_tlp_byte_len;  // curnt_tlp_byte_len = 00 -> means 4K,
// spyglass enable_block W164a

// The next bytecnt is the number of bytes received in this TLP
assign next_byte_len = curnt_tlp_byte_len;

assign update_lut_byte_cnt      = {remain_byte_cnt[11:0], next_low_addr};

assign  byte_cnt_match          =                                  (cpl_bcm | (stored_byte_cnt == total_rcvd_byte_cnt[11:0]) | cfg_filter_rule_mask[`CX_FLT_MASK_CPL_LEN_MATCH]);
assign  low_addr_match          =                                  ((np_req_is_a_memrd_or_dmwr ? rcvd_tlp_low_addr[1:0] ==
                                   lut_low_addr : rcvd_tlp_low_addr == 0)
                                   | cfg_filter_rule_mask[`CX_FLT_MASK_CPL_LEN_MATCH]);

// Lower address checking
assign lut_low_addr     = (same_tag && !prev_cpl_abort && last_filter) ?
    next_low_addr : lut_vec2[LOW_ADDR_INDEX2+LOW_ADDR_WD2-1:LOW_ADDR_INDEX2];

  assign  lut_pfuncid             = lut_vec[FUNC_NUM_INDEX -1: 0];
  assign  func_match              = (lut_pfuncid  == cpl_reqid[PF_WD-1:0])  || cfg_filter_rule_mask[`CX_FLT_MASK_CPL_FUNC_MATCH];
  assign  int_reqid_match             = (cpl_reqid[15:3] == {cfg_pbus_num, cfg_pbus_dev_num});

assign reqid_match = int_reqid_match || cfg_filter_rule_mask[`CX_FLT_MASK_CPL_REQID_MATCH ];
// cfg_p2p_track_cpl_to=0: P2P NP is not in LUT, check if reqid match core reqid for LUT update;
// cfg_p2p_track_cpl_to=1: P2P NP is in LUT, do not check if reqid match core reqid for LUT update;
assign reqid_match_lut = int_reqid_match || cfg_p2p_track_cpl_to;

assign  vendor_msg_id_match     = reqid_match;



wire attr_match;
wire tc_match;

assign lut_attr                 = lut_vec[ATTR_INDEX-1: TC_INDEX];
assign lut_tc                   = lut_vec[TC_INDEX-1:BYTECNT_INDEX];

assign attr_match               = (lut_attr    == attr)                                          ||  cfg_filter_rule_mask[`CX_FLT_MASK_CPL_ATTR_MATCH  ];

assign tc_match                 = (lut_tc      == tc)                                            ||  cfg_filter_rule_mask[`CX_FLT_MASK_CPL_TC_MATCH    ];


reg    [TAG_SIZE-1:0]            paded_rcv_tag;
always @(*) begin
  paded_rcv_tag = 0;
  paded_rcv_tag[CPL_LUT_PTR_WD-1:0] = rcvd_cpl_tlp_tag[CPL_LUT_PTR_WD-1:0];
end

assign  tag_err                 = (paded_rcv_tag != rcvd_cpl_tlp_tag) && !cfg_filter_rule_mask[`CX_FLT_MASK_CPL_TAGERR_MATCH] ;

// ----------------------------------------------------------
// Completion Filtering Logic
// ----------------------------------------------------------
// Error should be reported only one type when multiple errors happened
// within the same TLP.
// ECRC error has the highest priority
// Unexpected completion has the second highest priroity since it is unexpected,
// we will dropped it silently.
// when malformed or unsuccessful completion received, it will terminate
// current completion and send up the completions to application with status of non sucessful.
// When discard ECRC packet is desired, it will be treated as an unexpected
// completion such that the completion will be dropped silently and lookup table will not be updated.
wire  ecrc_err;
wire  valid_at_lut_addr;
wire  int_valid_at_lut_addr;




assign  int_valid_at_lut_addr       = get_valid_lut_addr(valid,lut_addr) &&
    !(same_tag && !prev_cpl_abort && last_filter && prev_cpl_last);

// int_valid_at_lut_addr is used when update LUT. Always check if tag is entered in LUT
// valid_at_lut_addr is used to check if cpl is unexpected cpl
assign valid_at_lut_addr = cfg_filter_rule_mask[`CX_FLT_MASK_CPL_IN_LUT_CHECK] || int_valid_at_lut_addr;

assign  ecrc_err                = rtlh_radm_ecrc_err && !cfg_filter_rule_mask[`CX_FLT_MASK_CPL_ECRC_DISCARD ];

assign  cpl_ecrc_err = ecrc_err && !cpl_mlf_err;  // Malformed TLP Error has higher precedence.

assign  unexpected_cpl_err      = ((!valid_at_lut_addr || !func_match ||
    !reqid_match || tag_err || (!byte_cnt_match || !low_addr_match) &&
    np_req_is_a_memrd_or_dmwr)
    ) && !ecrc_err;    // ECRC error has high priority than unexpected completion

assign  cpl_mlf_err             = 
    (((!byte_cnt_match || !low_addr_match) && !np_req_is_a_memrd_or_dmwr || !attr_match ||
      !tc_match
      || !np_req_is_a_cfg_or_dmwr && status_crs // when request is not a config_or_dmwr request but with CRS completion status
      ) && !unexpected_cpl_err );

wire    cpl_abort;
assign  cpl_abort               = unexpected_cpl_err | ecrc_err | cpl_mlf_err;

wire    next_cpl_abort;
assign  next_cpl_abort = cpl_abort;

assign  cpl_ur_err              = (status_ur || reserved_status) && !cpl_abort;
assign  cpl_ca_err              = status_ca && !cpl_abort;



// ----------------------------------------------------------
// Completion Lookup Table Update Logic
// ----------------------------------------------------------
// Don't allow this filter to generate an update when
// 1) it has the same tag as another filter and
// 2) it is not the last filter unless it has the last completion or
// 3) it is the last filter but the other filter had the last completion
wire mask_lut_update;
assign mask_lut_update = same_tag && !prev_cpl_abort && (!last_filter && !cpl_last || last_filter && prev_cpl_last);

assign  update_lut_content =
    !mask_lut_update && !cpl_abort && cpl_eot &&
    !( rtlh_radm_malform_tlp_err || rtlh_radm_dllp_err);

always @(posedge core_clk or negedge core_rst_n)
begin: OUTPUT_CONTROL_DRIVE_PROCESS
    if (!core_rst_n) begin
        flt_q_cpl_last          <= #TP 0;
        flt_q_cpl_abort         <= #TP 0;

    end else begin
        flt_q_cpl_last          <= #TP cpl_last;
        flt_q_cpl_abort         <= #TP cpl_abort & cpl_tlp;
    end
end

function  automatic get_valid_lut_addr;
input   [CPL_LUT_DEPTH-1:0]     valid;
input   [CPL_LUT_PTR_WD-1:0]    lut_addr;

integer ii;
begin
  get_valid_lut_addr = 0;
  for (ii=0; ii<CPL_LUT_DEPTH; ii=ii+1) begin
    if (ii==lut_addr) begin
      get_valid_lut_addr = valid[ii];
    end

  end
end
endfunction






endmodule
