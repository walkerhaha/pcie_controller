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
// ---    $DateTime: 2020/09/25 01:42:07 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_tlp_check_slv.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles parsing of received Transaction Layer Packets (TLPs).
// --- Its main functions are:
// ---    (1) Snoop aligned tlp to check for Malformed TLPs that are required by spec. Optional
// checkers are not implemented
//         The checkers are:
//         1. payload length and hdr length mismatch
//         2. max payload exceed the MTU
//         3. TC MAPPING check for tc error
//         4. message routing error
//         5. Configuration retry request completion received for EP mode
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rtlh_tlp_check_slv (
    core_clk,
    core_rst_n,
    cfg_max_payload,
    cfg_upstream_port,
    cfg_root_compx,
    cfg_endpoint,
    cfg_tc_struc_vc_map,
    rtlh_extrct_data,
    rtlh_extrct_hdr,
    rtlh_extrct_dwen,
    rtlh_extrct_sot,
    rtlh_extrct_dv,
    rtlh_extrct_eot,
    rtlh_extrct_abort,
    rtlh_extrct_ecrc_err,
    rtlh_extrct_ecrc_len_mismatch,
    rtlh_fc_init1_status,
    cfg_tc_enable,

   rtlh_radm_ant_addr,
   rtlh_radm_ant_rid,

   prev_pyld_dwcnt,

    rtfcgen_overfl_err,
  
// outputs
    next_pyld_dwcnt,

    rtlh_radm_data,
    rtlh_radm_hdr,
    rtlh_radm_dwen,
    rtlh_radm_hv,
    rtlh_radm_dv,
    rtlh_radm_eot,
    rtlh_radm_malform_tlp_err,
    rtlh_radm_ecrc_err,
    rtlh_radm_dllp_err,
    rtfcgen_vc,
    rtfcgen_fctype,
    rtfcgen_incr_enable,
    rtfcgen_incr_amt
);
// ----------------------------------------------------------------------------
// --- Parameters
// ----------------------------------------------------------------------------

parameter   INST                 = 0;          // The uniquifying parameter for each port logic instance.
parameter   NW                   = `CX_NW;     // Number of 32-bit dwords handled by the datapath each clock.
parameter   NVC                  = `CX_NVC;    // Number of VC
parameter   DW                   = (32*NW);    // Width of datapath in bits.
parameter   TP                   = `TP;        // Clock to Q delay (simulator insurance)
parameter   IDLE                 = 3'b000;
parameter   HDR1                 = 3'b001;
parameter   HDR2                 = 3'b010;
parameter   HDR3                 = 3'b011;
parameter   DATA                 = 3'b100;
parameter   DATA_PAR_WD          = `TRGT_DATA_PROT_WD; // data bus parity width
parameter   RAS_PCIE_HDR_PROT_WD = `CX_RAS_PCIE_HDR_PROT_WD;
parameter   DW_W_PAR             = DW+DATA_PAR_WD;
parameter   HW_W_PAR             = 128+RAS_PCIE_HDR_PROT_WD;
parameter   BYPASS_PYLD_DWCNT    = 0;


// -------------------------------- Inputs -------------------------------------
input                         core_clk;                       // Core clock
input                         core_rst_n;                     // Core system reset
input                         cfg_upstream_port;              // cdm configuration of upstream port device
input                         cfg_root_compx;                 // cdm configuration of root complex port
input                         cfg_endpoint;                   // cdm configuration of endpoint
input   [2:0]                 cfg_max_payload;                // cdm configuration of max MTU of TLP
input   [7:0]                 cfg_tc_enable;                  // cdm configuration of TC that are enabled
input   [23:0]                cfg_tc_struc_vc_map;            // Index by TC, returns VC

// From rtlh_tlp_align
input   [DW_W_PAR-1:0]        rtlh_extrct_data;               // Data (payload/hdr) of TLP packet from TLP extract module
input   [HW_W_PAR-1:0]        rtlh_extrct_hdr;                // hdr of TLP packet for 128bit arch only from TLP extract module
input   [NW-1:0]              rtlh_extrct_dwen;               // Dword enable of the TLP pkt data bus
input                         rtlh_extrct_dv;                 // Payload data valid
input                         rtlh_extrct_sot;                // hdr is valid this cycle
input                         rtlh_extrct_eot;                // end of a TLP
input                         rtlh_extrct_abort;              // DLLP layer abort due to DLLP layer error detected
input                         rtlh_extrct_ecrc_err;           // ECRC error detected when TD bit is set a TLP header
input                         rtlh_extrct_ecrc_len_mismatch;  // ECRC error detected when TD bit is set a TLP header and there is a length mismatch
input   [NVC-1:0]             rtlh_fc_init1_status;           // FC init status indicates that IFC1 state has been done

output  [63:0]                rtlh_radm_ant_addr;             // anticipated address (1 clock earlier)
output  [15:0]                rtlh_radm_ant_rid;              // anticipated RID (1 clock earlier)

input   [10:0]                prev_pyld_dwcnt;                // pyld count from the previous processing stage


input                         rtfcgen_overfl_err;               // Credit error from FC


// -------------------------------- Outputs ------------------------------------
output  [10:0]                next_pyld_dwcnt;                // pyld count to the next processing stage

output  [DW_W_PAR-1:0]        rtlh_radm_data;                 // Data (payload/hdr) of TLP packet, When it is 32b and 64b, hdr is merged onto this bus
output  [HW_W_PAR-1:0]        rtlh_radm_hdr;                  // hdr of TLP packet, only for 128b arch
output  [NW-1:0]              rtlh_radm_dwen;                 // Dword enable of the data bus
output                        rtlh_radm_dv;                   // Data (payload) is valid this cycle
output                        rtlh_radm_hv;                   // hdr is valid this cycle
output                        rtlh_radm_eot;                  // end of TLP
output                        rtlh_radm_dllp_err;             // Indicates current packet should be dropped because of DLLP layer err
output                        rtlh_radm_ecrc_err;             // Indicates current packet should be dropped because of ecrc error
output                        rtlh_radm_malform_tlp_err;      // Indicates current packet should be dropped because of checkers failed in this module
output  [2:0]                 rtfcgen_vc;                     // interface to flow contorl book keeping module, TC value
output  [1:0]                 rtfcgen_fctype;                 // FC type 00 = posted, 01== NP, 10 == CPL
output                        rtfcgen_incr_enable;            // FC increment enable. This is a strobe signal which indicates the FC type, FC amount and TC are valid.
output  [8:0]                 rtfcgen_incr_amt;               // FC credit amount. 9 bits used to allow max payload size of 4096 bytes

// ----------------------------------------------------------------------------
// Registered outputs
// ----------------------------------------------------------------------------
wire [DW_W_PAR-1:0] rtlh_radm_data;
wire [HW_W_PAR-1:0] rtlh_radm_hdr;
wire [NW-1:0]       rtlh_radm_dwen;
wire                rtlh_radm_dv;
wire                rtlh_radm_hv;
wire                rtlh_radm_eot;
wire                rtlh_radm_dllp_err;
wire                rtlh_radm_ecrc_err;     // Indicates current packet should be dropped because of tlp(aborted)
wire                rtlh_radm_malform_tlp_err;     // Indicates current packet should be dropped because of tlp(aborted)

// ----------------------------------------------------------------------------
// --- internal signals
// ----------------------------------------------------------------------------
wire     [NW-1:0]   extrct_dwen;
wire                extrct_dv;
wire                extrct_hv;
wire                extrct_eot;
wire [DW_W_PAR-1:0] extrct_data;
wire [HW_W_PAR-1:0] extrct_hdr;
wire                extrct_dllp_err;
wire                extrct_ecrc_err;          // Indicates current packet should be dropped because of tlp(aborted)
wire                extrct_malfm_tlp_err;     // Indicates current packet should be dropped because of tlp(aborted)

logic               max_pyld_err;
reg                 pcie_max_pyld_err;
wire                msg_route_err;
wire                tc_err;
wire                msg_type  ;
wire                p_wr  ;
wire                np_wr  ;
wire                np_rd  ;
wire                atomic_op;
wire                cpl  ;
wire                cpld  ;
wire                hdr_4dw;
wire                tlp_has_pyld;
wire    [1:0]       fc_type;
wire    [7:0]       hdr_err_ptr;
wire                extrct_malfm_tlp_errsts;
wire    [7:0]       extrct_malfm_tlp_err_ptr; // Indicates the detail of malformed for RASDES
integer j;

//=======================Internal Design ==========================

//  Depending upon different architecture, the extraction of the
//  information from header information will be different. Beneath is the
//  code design to accomodate this issue
//
wire    hdr_len_mismatch;
reg  [6:0]      tlp_fmt_type;
reg  [2:0]      tc;
reg             th;
reg             td;
reg  [7:0]      msg_code;
reg  [2:0]      cpl_status;
reg  [9:0]      tlp_dw_len;
reg  [3:0]      fbe; // First DW byte enable
reg  [3:0]      lbe; // Last DW byte enable
wire  [11:0]    int_addr_11_dt_0;
wire  [11:0]    addr_11_dt_0;
wire            int_extrct_hv;
wire            int_extrct_dv;
wire  [10:0]    pyld_dwcnt;
reg   [10:0]    next_pyld_dwcnt;
wire  [NW-1:0]  tmp_dwcnt;

reg             next_incr_enable;
reg   [1:0]     next_fctype;
reg   [2:0]     next_vc;
reg   [8:0]     next_incr_amt;

reg cfg_tph_enable;
assign cfg_tph_enable = 1'b0;


// =============== START 64 bit archtecture header information collection =====
    // latched the header information needed

  reg        pkt_in_progress;
  reg        pkt_in_progress_d;

   always @(posedge core_clk or negedge core_rst_n)
      if (!core_rst_n) begin
        pkt_in_progress         <= #TP 0;
      end else if (rtlh_extrct_eot) begin     // clear over set since it is possible to have a short TLP with 3 hdr dword where sot and eot are asserted at the same cycle
        pkt_in_progress         <= #TP 1'b0;
      end else if (rtlh_extrct_sot) begin
        pkt_in_progress         <= #TP 1'b1;
      end

   always @(posedge core_clk or negedge core_rst_n)
      if (!core_rst_n) begin
        tlp_fmt_type              <= #TP 0;
        tc                        <= #TP 0;
        td                        <= #TP 0;
        th                        <= #TP 0;
        tlp_dw_len                <= #TP 0;
        cpl_status                <= #TP 0;
        msg_code                  <= #TP 0;
      end else if (rtlh_extrct_sot & !pkt_in_progress) begin
        tlp_fmt_type              <= #TP rtlh_extrct_data[6:0];
        tc                        <= #TP rtlh_extrct_data[14:12];
        td                        <= #TP rtlh_extrct_data[23];
        th                        <= #TP cfg_tph_enable && rtlh_extrct_data[8];
        tlp_dw_len                <= #TP {rtlh_extrct_data[17:16], rtlh_extrct_data[31:24]} ;
        cpl_status                <= #TP rtlh_extrct_data[55:53] ;
        msg_code                  <= #TP rtlh_extrct_data[63:56] ;
      end

  always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
      fbe                       <= #TP 0;
      lbe                       <= #TP 0;
    end else if (rtlh_extrct_sot & !pkt_in_progress) begin
      fbe                       <= #TP rtlh_extrct_data[59:56];
      lbe                       <= #TP rtlh_extrct_data[63:60];
    end

   always @(*) begin
       next_pyld_dwcnt = prev_pyld_dwcnt;
        if (rtlh_extrct_sot) begin
            next_pyld_dwcnt = 0;
        end else if (rtlh_extrct_dv) begin
            next_pyld_dwcnt = pyld_dwcnt ;
        end
    end

  always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
      pkt_in_progress_d              <= #TP 0;
    end else if (rtlh_extrct_sot) begin
      pkt_in_progress_d              <= #TP pkt_in_progress ;
    end

  reg [11:0] latchd_addr_11_dt_0;
  always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
      latchd_addr_11_dt_0              <= #TP 0;
    end else if (pkt_in_progress && !pkt_in_progress_d) begin
      latchd_addr_11_dt_0              <= #TP hdr_4dw ? {rtlh_extrct_data[51:48], rtlh_extrct_data[63:56]}
                                              : {rtlh_extrct_data[19:16], rtlh_extrct_data[31:24]};
    end

assign int_addr_11_dt_0 = (rtlh_extrct_eot & pkt_in_progress && !pkt_in_progress_d) ?
                      (hdr_4dw ? {rtlh_extrct_data[51:48], rtlh_extrct_data[63:56]} :
                       {rtlh_extrct_data[19:16], rtlh_extrct_data[31:24]}) : latchd_addr_11_dt_0;

// For TPH requests we must strip the PH from the address field for
// checking purposes
assign addr_11_dt_0  = {int_addr_11_dt_0[11:2],2'b00};

   assign tmp_dwcnt           =    (rtlh_extrct_dwen == 2'b01) ? 2'h1
                                     : (rtlh_extrct_dwen == 2'b11) ? 2'h2
                                     : 2'h0;

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. pyld_dwcnt counters are intended to
// wrap without preseveration of carry/borrow
   assign     pyld_dwcnt          = (rtlh_extrct_dv) ? prev_pyld_dwcnt + tmp_dwcnt : prev_pyld_dwcnt;
// spyglass enable_block W164a

   // For 64bit architecture, hv indicates the header valid, dv indicates
   // the payload data valid. There are mutually exclusive
   // Header takes the first two cycles of a TLP, data is asserted there
   // after.
   assign int_extrct_hv       =  rtlh_extrct_sot;
   assign int_extrct_dv       =  rtlh_extrct_dv;

   assign  hdr_len_mismatch = 0;

// =============== END 64 bit archtecture header information collection =====


// ============ Common Code ==============================
assign              p_wr          =  (tlp_fmt_type[6:0] == `MWR32)
                                  |  (tlp_fmt_type[6:0] == `MWR64)
                                  |  (tlp_fmt_type[6:3] == `MSG_4)
                                  |  (tlp_fmt_type[6:3] == `MSGD_4)
                                  ;

assign              np_wr         =  (tlp_fmt_type[6:0] == `IOWR)

                                  |  (tlp_fmt_type[6:0] == `CFGWR1)
                                  |  (tlp_fmt_type[6:0] == `CFGWR0);

assign              np_rd         =  (tlp_fmt_type[6:0] == `IORD)
                                  |  (tlp_fmt_type[6:0] == `MRD32)
                                  |  (tlp_fmt_type[6:0] == `MRD64)
                                  |  (tlp_fmt_type[6:0] == `MRDLK32)
                                  |  (tlp_fmt_type[6:0] == `MRDLK64)
                                  |  (tlp_fmt_type[6:0] == `CFGRD1)
                                  |  (tlp_fmt_type[6:0] == `CFGRD0);

assign              atomic_op     = (tlp_fmt_type[6:0] == `FETCHADD32)
                                  | (tlp_fmt_type[6:0] == `FETCHADD64)
                                  | (tlp_fmt_type[6:0] == `SWAP32)
                                  | (tlp_fmt_type[6:0] == `SWAP64)
                                  | (tlp_fmt_type[6:0] == `CAS32)
                                  | (tlp_fmt_type[6:0] == `CAS64);

assign              cpl           = ((tlp_fmt_type[6:0] == `CPL )
                                  |  (tlp_fmt_type[6:0] == `CPLD)
                                  |  (tlp_fmt_type[6:0] == `CPLLK)
                                  |  (tlp_fmt_type[6:0] == `CPLDLK));

assign              cpld          =  (tlp_fmt_type[6:0] == `CPLD) | (tlp_fmt_type[6:0] == `CPLDLK);

wire                msg;
wire                msg_route_rc;
wire                msg_route_bc;
assign msg           = (tlp_fmt_type[6:3] == `MSG_4) | (tlp_fmt_type[6:3] == `MSGD_4);
assign msg_route_rc  = (tlp_fmt_type[2:0]    == 3'b000) | (tlp_fmt_type[2:0] == 3'b101);
assign msg_route_bc  = (tlp_fmt_type[2:0]    == 3'b011);


reg                 intrup_msg;
reg                 pm_msg;
reg                 err_msg;
reg                 lock_msg;
reg                 sspl_msg;
wire                valid_type;
wire                cpl_crs_err;
wire                dw_len_is0;

always@(*)
begin
  intrup_msg = 1'b0;
  pm_msg     = 1'b0;
  err_msg    = 1'b0;
  lock_msg   = 1'b0;
  sspl_msg   = 1'b0;

  casez (msg_code)
    8'b0010_???? : intrup_msg = 1'b1;
    8'b0001_0100,
    8'b0001_1000,
    8'b0001_1001,
    8'b0001_1011 : pm_msg     = 1'b1;
    8'b0011_???? : err_msg    = 1'b1;
    8'b0000_0000 : lock_msg   = 1'b1;
    8'b0101_0000 : sspl_msg   = 1'b1;
    default : begin
      intrup_msg = 1'b0;
      pm_msg     = 1'b0;
      err_msg    = 1'b0;
      lock_msg   = 1'b0;
      sspl_msg   = 1'b0;
    end
  endcase
end

assign valid_type    = (atomic_op | np_rd | np_wr | p_wr | cpl);

// based on spec.1.0a paget 82, a completion with configuration request
// retry will result a malformd tlp. For endpoint device, since there is no
// configuration request issued from the device, any cpl wiht CRS is
// a malformed. This donot apply to switch
assign cpl_crs_err   = cpl & (cpl_status == `CRS_CPL_STATUS) & cfg_endpoint;

assign fc_type       = p_wr ? 2'b00 : cpl ? 2'b10 : (atomic_op | np_rd | np_wr) ? 2'b01 : 2'b11;

assign tlp_has_pyld  = tlp_fmt_type[6];
assign hdr_4dw       = tlp_fmt_type[5];
assign dw_len_is0    = (tlp_dw_len == 10'b0);

// all errors below are latched to form the malformaed error at the final
// cycle of the current tlp due to the abort issue of the currnt tlp
// This error can only be generated based on long payload tlps

always @(dw_len_is0 or tlp_dw_len or cfg_max_payload or tlp_has_pyld)  begin
        // dd err according to page 51 of rev1.0
        // 1.0 spec.
        case (cfg_max_payload)
            3'b000: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h020) & tlp_has_pyld; // 128 bytes
            3'b001: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h040) & tlp_has_pyld ; // 256Bytes
            3'b010: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h080) & tlp_has_pyld ; // 512Bytes
            3'b011: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h100) & tlp_has_pyld ; // 1KBytes
            3'b100: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h200) & tlp_has_pyld ; // 2KBytes
            3'b101: pcie_max_pyld_err      = 1'b0 ; // 4KBytes
        // not spec supported payload size
        //VCS coverage off
            3'b110: pcie_max_pyld_err      = 1'b0;
            3'b111: pcie_max_pyld_err      = 1'b0;
        //VCS coverage on
        endcase
end

assign max_pyld_err = pcie_max_pyld_err;

wire [2:0]  curnt_struc_vc;
wire [10:0] tmp_dw_len;

// detect the interrupt message with TC non zero err according to page 67 of rev1.0
assign  msg_type                  = msg & (intrup_msg |
                                           pm_msg     |
                                           err_msg    |
                                           lock_msg   |
                                           sspl_msg
                                          );

// detect the message route errors : upstream port can not receive
// the route code as routed to root complex
// Downstream port can not receive the route code as broadcast from
// root complex
// This error detection is only there for switch
assign  msg_route_err             = msg & !cfg_endpoint & !cfg_root_compx &  ((msg_route_rc & cfg_upstream_port) | (msg_route_bc & !cfg_upstream_port));

// detect the VC/TC errors with TC non zero err according to page 84,85 of rev1.0
assign curnt_struc_vc        = get_VC(cfg_tc_struc_vc_map,tc);
assign  tc_err                    = ~( get_tc_enable(cfg_tc_enable,tc)
                                     )
                                  | ~get_fc_init_status(rtlh_fc_init1_status,curnt_struc_vc);

assign tmp_dw_len                  = {dw_len_is0, tlp_dw_len};

wire    len_mismatch;
  assign len_mismatch              = (td & tlp_has_pyld) ? (tmp_dw_len != pyld_dwcnt) :
                                     (td)                ? (pyld_dwcnt != 11'h0)      :
                                     (tlp_has_pyld)      ? (tmp_dw_len != pyld_dwcnt) : (pyld_dwcnt != 11'h0);

// Atomic Op length check.
// If the length field of an Atomic Op does not match an architected
// operand size, the request must be handled as a MLF TLP.
// Architected operand sizes are detailed in table 2-13 of the PCIe
// base spec rev 2.1
wire atomic_operand_err;
wire atomic_operand32;
wire atomic_operand64;
wire atomic_operand128;
wire atomic_be_err;

assign atomic_operand32  = (((tlp_fmt_type[6:0] == `FETCHADD32)
                           | (tlp_fmt_type[6:0] == `FETCHADD64)
                           | (tlp_fmt_type[6:0] == `SWAP32)
                           | (tlp_fmt_type[6:0] == `SWAP64))
                           && (tmp_dw_len == 11'h1)) ||
                           (((tlp_fmt_type[6:0] == `CAS32)
                           | (tlp_fmt_type[6:0] == `CAS64))
                           && (tmp_dw_len == 11'h2)) ;

assign atomic_operand64  = (((tlp_fmt_type[6:0] == `FETCHADD32)
                           | (tlp_fmt_type[6:0] == `FETCHADD64)
                           | (tlp_fmt_type[6:0] == `SWAP32)
                           | (tlp_fmt_type[6:0] == `SWAP64))
                           && (tmp_dw_len == 11'h2)) ||
                           (((tlp_fmt_type[6:0] == `CAS32)
                           | (tlp_fmt_type[6:0] == `CAS64))
                           && (tmp_dw_len == 11'h4)) ;

assign atomic_operand128 = ((tlp_fmt_type[6:0] == `CAS32)
                           | (tlp_fmt_type[6:0] == `CAS64))
                           && (tmp_dw_len == 11'h8) ;

// Byte enable fields are reserved for Atomic Ops, so setting field to zero.
// See "Memory, I/O and Configuration Request Rules" in Base Spec.
assign atomic_be_err = 1'b0;

assign atomic_operand_err = atomic_op && !(atomic_operand32 | atomic_operand64 | atomic_operand128);

// For AtomicOp Requests, the Address must be naturally aligned with the operand size. The
// Completer must check for violations of this rule. If a TLP violates this rule, the TLP is a
// Malformed TLP
wire atomic_addr_align_err;

assign atomic_addr_align_err = (atomic_operand32  && (addr_11_dt_0[1:0] != 2'h0)) ||
                               (atomic_operand64  && (addr_11_dt_0[2:0] != 3'h0)) ||
                               (atomic_operand128 && (addr_11_dt_0[3:0] != 4'h0));



wire  hdr_err;
assign {hdr_err_ptr, hdr_err} = max_pyld_err             ? {`MFPTR_TLP_MXPL, 1'b1} :
                               (msg_type & (tc != 3'b0)) ? {`MFPTR_MSG_TC0,  1'b1} :
                                tc_err                   ? {`MFPTR_TLP_TC,   1'b1} :
                                msg_route_err            ? {`MFPTR_MSG_R,    1'b1} :
                                cpl_crs_err              ? {`MFPTR_CPL_CRS,  1'b1} :
                                                           {`MFPTR_NO_ERR,   1'b0} ;
// --------------- Output assignment ----------------
assign       extrct_dwen          = rtlh_extrct_dwen ;
assign       extrct_dv            = int_extrct_dv ;
assign       extrct_hv            = int_extrct_hv ;
assign       extrct_eot           = rtlh_extrct_eot ;
assign       extrct_data          = rtlh_extrct_data ;
assign       extrct_hdr           = rtlh_extrct_hdr ;
assign       extrct_dllp_err      = rtlh_extrct_abort ;
assign       extrct_ecrc_err      = rtlh_extrct_ecrc_err ;

assign       extrct_malfm_tlp_err = extrct_malfm_tlp_errsts & rtlh_extrct_eot;

assign      {extrct_malfm_tlp_err_ptr, extrct_malfm_tlp_errsts} = rtlh_extrct_abort             ? {`MFPTR_NO_ERR,    1'b0} :
                                                                  atomic_addr_align_err         ? {`MFPTR_ATOM_ADR,  1'b1} :
                                                                  atomic_operand_err            ? {`MFPTR_ATOM_OPR,  1'b1} :
                                                                  atomic_be_err                 ? {`MFPTR_ATOM_BE ,  1'b1} :
                                                                  len_mismatch                  ? {`MFPTR_TLP_DLEN,  1'b1} :
                                                                  hdr_len_mismatch              ? {`MFPTR_TLP_HLEN,  1'b1} :
                                                                  hdr_err                       ? {hdr_err_ptr,      1'b1} :
                                                                  rtlh_extrct_ecrc_len_mismatch ? {`MFPTR_TLP_ELEN,  1'b1} :
                                                                                                  {`MFPTR_NO_ERR,    1'b0} ;

wire       fc_align_dllp_err;
wire       fc_align_malfm_tlp_err;
wire [7:0] fc_align_malfm_tlp_err_ptr;

// Qualify the FC overflow error with incr_enable to be nice
// Note eot is not available here but incr_enable can be used with the same meaning
wire rtlh_fc_credit_abort;
assign rtlh_fc_credit_abort = rtfcgen_incr_enable && rtfcgen_overfl_err;

wire       extrct_fc_dllp_err;
wire       extrct_fc_malfm_tlp_err;
wire [7:0] extrct_fc_malfm_tlp_err_ptr;
assign extrct_fc_dllp_err = fc_align_dllp_err || rtlh_fc_credit_abort;
assign {extrct_fc_malfm_tlp_err_ptr, extrct_fc_malfm_tlp_err} = rtlh_fc_credit_abort ? {`MFPTR_NO_ERR,1'b0} : {fc_align_malfm_tlp_err_ptr, fc_align_malfm_tlp_err};
 

// ================== Output Drives ==================
// Outputs are always registered except for 'anticipated' signals and FC gen outputs.
// An additional pipeline stage can be added for one or both of the following reasons:
//  - Ease cdm timing closure (RADM_VFINDEX_REGOUT): anticipated outputs provided 2 clock cycles in advance.
//    Note in 512b, the Seriliazation Queue is in charge of providing the anticipated signals
//    and this feature is not required.
//  - Ease FC calculation (CX_RTLH_FC_CHECK_REGOUT): FC gen outputs registered
localparam FC_OPT  = 0 ;
localparam CDM_OPT = (NW==16)? 0 : 0 ;
localparam N_CYCLE_DELAY_GLOBAL   = ((FC_OPT == 1) || (CDM_OPT == 1))? 2 : 1;
localparam N_CYCLE_DELAY_FC_OUT   = (FC_OPT)? 1 : 0;
localparam N_CYCLE_DELAY_ERR_OUT  = N_CYCLE_DELAY_GLOBAL - N_CYCLE_DELAY_FC_OUT;
localparam N_CYCLE_DELAY_ANT_OUT  = ((FC_OPT == 1) && (CDM_OPT == 0))? 1 : 0;

// CTRL_register_path
localparam CTRL_WIDTH         = 3   // hv,dv,eot
                                ;
delay_n

#(.N(N_CYCLE_DELAY_GLOBAL), .WD(CTRL_WIDTH)) u_delay_ctrl (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({extrct_hv, extrct_dv, extrct_eot
                }),
    .dout       ({rtlh_radm_hv, rtlh_radm_dv, rtlh_radm_eot
                })
);

localparam DATAPATH_CTRL_WIDTH = NW + 1 
                                ;
delay_n_w_enable

#(N_CYCLE_DELAY_GLOBAL, DATAPATH_CTRL_WIDTH) u_delay_datapath_ctrl (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (extrct_hv | extrct_dv),
    .din        ({extrct_dwen, extrct_ecrc_err
                 }),
    .dout       ({rtlh_radm_dwen, rtlh_radm_ecrc_err
                 })
);

localparam HDR_WIDTH = 128 
                      ; 
delay_n_w_enable

#(N_CYCLE_DELAY_GLOBAL, HDR_WIDTH) u_delay_hdr (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (extrct_hv),
    .din        (extrct_hdr),
    .dout       (rtlh_radm_hdr)
);

localparam DATA_WIDTH = DW
                      ; 
delay_n_w_enable

#(N_CYCLE_DELAY_GLOBAL, DATA_WIDTH) u_delay_data (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (extrct_dv | 
                 extrct_hv),
    .din        (extrct_data),
    .dout       (rtlh_radm_data)
);

// FC gen outputs
localparam FC_OUT_WIDTH = 1   // rtfcgen_incr_enable
                          +3  // rtfcgen_vc
                          +2  // rtfcgen_fctype
                          +9  // rtfcgen_incr_amt;
                          +1  // extrct_dllp_err
                          +1; // extrct_malfm_tlp_err
delay_n

#(.N(N_CYCLE_DELAY_FC_OUT), .WD(FC_OUT_WIDTH)) u_delay_fc_out (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({   next_incr_enable,    next_vc,    next_fctype,    next_incr_amt, extrct_dllp_err,   extrct_malfm_tlp_err
                }),
    .dout       ({rtfcgen_incr_enable, rtfcgen_vc, rtfcgen_fctype, rtfcgen_incr_amt, fc_align_dllp_err, fc_align_malfm_tlp_err
                })
);
assign fc_align_malfm_tlp_err_ptr = 0;

// Error outputs
localparam ERR_OUT_WIDTH =  1  // extrct_fc_dllp_err
                           +1; // extrct_fc_malfm_tlp_err

delay_n

#(.N(N_CYCLE_DELAY_ERR_OUT), .WD(ERR_OUT_WIDTH)) u_delay_err_out (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({extrct_fc_dllp_err, extrct_fc_malfm_tlp_err
                }),
    .dout       ({rtlh_radm_dllp_err, rtlh_radm_malform_tlp_err
                })
);

// --------- Anticipated outputs  ----------
// Present the address to the cdm one or two clocks earlier to provide ease of timing closure

wire    [31:0]      hdr_dw1;                    // sync with rtlh time domain
wire    [31:0]      hdr_dw2;
wire    [31:0]      hdr_dw3;
wire    [31:0]      hdr_dw4;
wire    [63:0]      rtlh_radm_ant_addr;
wire    [15:0]      rtlh_radm_ant_rid;
wire    [31:0]      addr_low;
wire    [31:0]      addr_high;
wire                addr64;

reg  [127:0] latched_hdr;
reg  [127:0] latched_hdr_wire;
reg   [2:0]  latched_cnt;
// if core is 64 bit, radm_formation takes the 64 header to form a 128bit header. must be done here 1 clock earlier to send earlier to cdm
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
      latched_cnt <= #TP 0;
    end else if (extrct_eot) begin
      latched_cnt <= #TP 0;
    end else if (extrct_hv) begin
      latched_cnt <= #TP latched_cnt + 1'b1;
    end
end

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
      latched_hdr <= #TP 0;
    end else begin
      latched_hdr <= #TP latched_hdr_wire;
    end
end

always @ (latched_cnt or extrct_hv or extrct_data or latched_hdr)
begin
    if ((latched_cnt==3'h0) & extrct_hv) begin
      latched_hdr_wire = {64'h0,extrct_data[63:0]};
    end else if ((latched_cnt==3'h1) & extrct_hv) begin
      latched_hdr_wire = {extrct_data[63:0],latched_hdr[63:0]};
    end else begin
      latched_hdr_wire = latched_hdr;
    end
end
assign  hdr_dw1  = latched_hdr_wire[31:0];
assign  hdr_dw2  = latched_hdr_wire[63:32];
assign  hdr_dw3  = latched_hdr_wire[95:64];
assign  hdr_dw4  = latched_hdr_wire[127:96];


assign  addr64              = hdr_dw1[5];
assign  addr_low            = addr64 ? {hdr_dw4[7:0], hdr_dw4[15:8], hdr_dw4[23:16], hdr_dw4[31:24]} :
                                       {hdr_dw3[7:0], hdr_dw3[15:8], hdr_dw3[23:16], hdr_dw3[31:24]};
assign  addr_high           = addr64 ? {hdr_dw3[7:0], hdr_dw3[15:8], hdr_dw3[23:16], hdr_dw3[31:24]} : 32'b0;
assign  rtlh_radm_ant_addr  = {addr_high, addr_low};
assign  rtlh_radm_ant_rid   = {hdr_dw3[7:0], hdr_dw3[15:8]};

always @(*) begin : NEXT_CRD_UPDATE
    next_incr_enable = rtlh_extrct_eot && !rtlh_extrct_abort && fc_type != 2'b11;
    next_fctype = fc_type;
    next_vc = curnt_struc_vc;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. next_incr_amt counters are intended to
// wrap without preseveration of carry/borrow
    if(tlp_has_pyld) begin
        next_incr_amt = tmp_dw_len[10:2] + |tmp_dw_len[1:0];
    end else begin
        next_incr_amt = 0;
    end
end
// spyglass enable_block W164a



function automatic [2:0]  get_VC;
    input [23:0] tc_vc_map;
    input [2:0] tc;
    begin
        case (tc)
            3'b000: get_VC = tc_vc_map[2:0];
            3'b001: get_VC = tc_vc_map[5:3];
            3'b010: get_VC = tc_vc_map[8:6];
            3'b011: get_VC = tc_vc_map[11:9];
            3'b100: get_VC = tc_vc_map[14:12];
            3'b101: get_VC = tc_vc_map[17:15];
            3'b110: get_VC = tc_vc_map[20:18];
            3'b111: get_VC = tc_vc_map[23:21];
        endcase
    end
    //    for (bit=0; bit<3; bit=bit+1) get_VC[bit]    = tc_vc_map[(tc*3)+bit];
endfunction

function automatic get_tc_enable;
input [7:0] cfg_tc_enable;
input [2:0] tc;
begin
    case (tc)
      3'b000: get_tc_enable = cfg_tc_enable[0];
      3'b001: get_tc_enable = cfg_tc_enable[1];
      3'b010: get_tc_enable = cfg_tc_enable[2];
      3'b011: get_tc_enable = cfg_tc_enable[3];
      3'b100: get_tc_enable = cfg_tc_enable[4];
      3'b101: get_tc_enable = cfg_tc_enable[5];
      3'b110: get_tc_enable = cfg_tc_enable[6];
      3'b111: get_tc_enable = cfg_tc_enable[7];
    endcase
end
endfunction

function automatic get_fc_init_status;
input [NVC-1:0] rtlh_fc_init1_status;
input     [2:0] curnt_struc_vc;
begin
    case (curnt_struc_vc)
            3'b000:  get_fc_init_status = rtlh_fc_init1_status[0];
            default: get_fc_init_status = rtlh_fc_init1_status[0];
    endcase
end
endfunction

endmodule
