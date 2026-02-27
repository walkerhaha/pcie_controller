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
// ---    $DateTime: 2020/10/08 11:09:15 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/xadm_hdr_form.sv#8 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  The major funcions:
//  (1) Based on inputs to form tlp pkt as PCI-Express required.  Calculation of DW_LEN, DW_LAST, DW_FIRST
//      and 128-bit data aligment for memory address because of address offset and DW align offset
//  (2) 128-bit data alignment based on addr[1:0] offset
//  interfaces

//  Notes for interface requirement:
//  (1) for header only transaction, client_xadm_hv and client_xadm_eot are
//      asserted at the same time, but client_xadm_dv is always deasserted
//  (2) for 1 DW payload transaction, client_xadm_hv, client_xadm_eot and client_xadm_dv are
//      asserted at the same time
//  (3) output dv and hv will be always asserted together if there is
//      payload in the current tlp
// ----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xadm_hdr_form
    (
// ------ inputs ------
    core_clk,
    core_rst_n,
    cfg_ecrc_gen_en,
    device_type,
    intf_tlp_hdr_int,
    intf_hdr_rsvd,
    intf_hdr_ats,
    intf_hdr_nw,
    intf_hdr_th,
    intf_hdr_ph,
    intf_hdr_st,
    intf_tlp_hv,
    intf_tlp_eot,
    intf_in_halt,



    cfg_2ndbus_num,

// ------ outputs ------
    tlp_formed_hdr,           // SEE adm_defs.vh for hdr slicing.
    tlp_formed_hdr_parerr,
    tlp_data_align_en,
    tlp_formed_last_dwen,
     tlp_is_mem,
     addr64,


    prfx_formed_parerr,

    tlp_formed_add_ecrc
    
);
parameter   INST        = 0;        // The uniquifying parameter for each port logic instance.
parameter   NW          = `CX_NW;   // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW          = (32*NW);  // Width of datapath in bits.
parameter   TP          = `TP;      // Clock to Q delay (simulator insurance)
parameter   ST_HDR      = `ST_HDR;
parameter   NF          = `CX_NFUNC;// Number of functions
parameter   HDR_PROT_WD = `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD;  // XADM Common Header ecc/parity protection width
parameter   NF_WD       = `CX_NFUNC_WD;// Number of bits in the Function Number



parameter LEN_OFFSET_WIDTH = NW==16 ? 4 : NW==8 ? 3 : NW==4 ? 2 : 1;  // bus width of tlp_raw_bytelen_offset in xadm_data_align module

parameter RAS_PCIE_HDR_PROT_WD = 0 
                                     ; 
    
localparam TAG_SIZE = `CX_TAG_SIZE;

// input signals
input                   core_clk;
input                   core_rst_n;
input   [ST_HDR-1:0]    intf_tlp_hdr_int;         // address and header infor
input   [14:0]          intf_hdr_rsvd;        // header reserved fields
input   [1:0]           intf_hdr_ats;
input                   intf_hdr_nw;
input   [7:0]           intf_hdr_st;
input   [1:0]           intf_hdr_ph;
input                   intf_hdr_th;
input   [NF-1:0]        cfg_ecrc_gen_en;      // enables ECRC assertion per function
input [3:0]             device_type;          // Device type - RC, EP, SW or DM.
wire                    intf_tlp_hdr_pt;
assign intf_tlp_hdr_pt = 0;
input                   intf_tlp_hv;          // Header Valid
input                   intf_tlp_eot;         // TLP eot
input                   intf_in_halt;         // formation out halt
input  [(8*NF)-1:0]     cfg_2ndbus_num;       // configured secondary bus number

// output signals
output  [128-1+RAS_PCIE_HDR_PROT_WD:0]tlp_formed_hdr;         // header bus: RAS Logic in PCIe. + Extra-bits to header (in case of CX_RASDP_EN) 
output  [NW -1:0]                     tlp_formed_last_dwen;   // data bus dword enable
output                                tlp_formed_add_ecrc;
output                                tlp_formed_hdr_parerr; // output address detected parity error from client address
output                                tlp_data_align_en;      // For posted write and address align is enabled by application
output                                tlp_is_mem;
output                                addr64;


output      prfx_formed_parerr;




reg                     tlp_is_mem;

// header formation related signals
wire    [10:0]          hdr_dw_len_w_ecrc;

wire    [9:0]           hdr_dw_len;

wire    [3:0]           last_be;
reg     [3:0]           first_be;
reg     [127:0]         tmp_hdr;
wire    [NF_WD-1:0]     tlp_func_num;
wire                    tlp_data_align_en;
wire [`SF_HDR_CPL_BCM           -1:0]   cpl_bcm;
wire [`SF_HDR_CPL_BYTE_CNT      -1:0]   cpl_byte_cnt;
wire [`SF_HDR_CPL_REQ_ID        -1:0]   cpl_req_id;
wire [`SF_HDR_CPL_STATUS        -1:0]   cpl_status;
wire [`SF_HDR_REQ_ID            -1:0]   req_id;
wire [2:0]                              tlp_attr;
wire [`SF_HDR_TLP_BYTE_LEN      -1:0]   tlp_byte_len;
wire [`SF_HDR_TLP_EP            -1:0]   tlp_ep;
wire [`SF_HDR_TLP_TAG           -1:0]   tlp_tag;
wire [`SF_HDR_ADDR_ALIGN_EN     -1:0]   int_tlp_addr_align_en;
wire [`SF_HDR_BYTE_EN           -1:0]   tlp_byte_en;
wire [`SF_HDR_TLP_ADDR          -1:0]   tlp_addr;
wire [`SF_HDR_TLP_FMT           -1:0]   tlp_fmt;
wire [`SF_HDR_TLP_MSG_CODE      -1:0]   tlp_msg_code;
wire [`SF_HDR_TLP_TC            -1:0]   tlp_tc;
wire [`SF_HDR_TLP_TYPE          -1:0]   int_tlp_type, tlp_type;
wire [`SF_HDR_TLP_TD            -1:0]   tlp_td;
wire [`SF_HDR_TLP_BYTE_LEN+1    -1:0]   tlp_byte_len_w_ecrc;
wire                                    addr64;
wire [6:0]                              fmt_type;
wire [6:0]                              int_fmt_type;
wire                                    int_curnt_iscfgtype1;
wire                                    int_bus_num_match;
wire                                    curnt_ismsg;
wire                                    curnt_iscpl;
wire                                    curnt_iscfgwr;
wire                                    curnt_iscfgrd;
wire                                    curnt_isiord;
wire                                    curnt_isiowr;
wire                                    curnt_ismemrd;
wire                                    curnt_istransreq;
wire                                    curnt_ismemwr;
wire                                    curnt_isdefmemwr;
wire                                    curnt_isatomic;
wire                                    curnt_is_tphmemrd;
wire                                    curnt_is_tphmemwr;
wire                                    curnt_is_tphatomic;
wire                                    curnt_is_tph;
wire [1:0]                              tlp_addr_1_0;
wire [3:0]                              tlp_addr_15_12;
wire [7:0]                              tlp_addr_31_24, trgt_bus_num;
wire [4:0]                              tlp_addr_23_19;
wire                                    tlp_has_pyld;
wire [9:0]                              tmp_dw_len;
wire [9:0]                              com_dw_len;
wire [31:0]                             int_common_hdr;
wire [31:0]                             common_hdr_pt;
wire [7:0]                              int_byte_en;
wire                                    tlp_dwlen_nonzero;

// temp wire to adjust the width of intf_hdr_st when TAG field is 10 bits wide
// this signal will be used to drive tlp_tag when curnt_is_tphmemwr is asserted
wire [TAG_SIZE-1:0] tlp_tag_st;

wire    rc_device;
wire    pcie_sw_down;
wire    downstream_port;
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);
assign downstream_port  = rc_device | pcie_sw_down;

assign tlp_tag_st[0+:8]         = intf_hdr_st;

// ============================================================================
//
// TLP Header formation  -- start
//
// Note: For zero mem_rd, length field has to be 1DW, but 1st BE is 0
//
// Note: IO READ/WRITE, CFG READ/WRITE only applied to RC application
// ============================================================================
//
// Header information

// Break the HDR structure into its fields
assign cpl_bcm          = intf_tlp_hdr_int[`F_HDR_CPL_BCM         ];
assign cpl_byte_cnt     = intf_tlp_hdr_int[`F_HDR_CPL_BYTE_CNT    ];
assign cpl_req_id       = intf_tlp_hdr_int[`F_HDR_CPL_REQ_ID      ];     // completion requester's ID
assign cpl_status       = intf_tlp_hdr_int[`F_HDR_CPL_STATUS      ];
assign req_id           = intf_tlp_hdr_int[`F_HDR_REQ_ID          ];     // requester's ID or Completer ID
assign tlp_attr[2]      = intf_hdr_rsvd[3];
assign tlp_attr[1:0]    = intf_tlp_hdr_int[`F_HDR_TLP_ATTR        ];
assign tlp_ln           = intf_hdr_rsvd[2];

assign tlp_byte_len     = intf_tlp_hdr_int[`F_HDR_TLP_BYTE_LEN    ];
assign tlp_ep           = intf_tlp_hdr_int[`F_HDR_TLP_EP          ];
// The tag field is re-purposed to be a Steering tag value when the TH bit
// is set in a MemWr request.
assign tlp_tag          = curnt_is_tphmemwr ? tlp_tag_st: intf_tlp_hdr_int[`F_HDR_TLP_TAG];
assign int_tlp_addr_align_en= intf_tlp_hdr_int[`F_HDR_ADDR_ALIGN_EN   ];
assign tlp_addr         = intf_tlp_hdr_int[`F_HDR_TLP_ADDR        ];
assign tlp_byte_en      = intf_tlp_hdr_int[`F_HDR_BYTE_EN         ];
assign tlp_fmt          = intf_tlp_hdr_int[`F_HDR_TLP_FMT         ];
assign tlp_msg_code     = intf_tlp_hdr_int[`F_HDR_TLP_MSG_CODE    ]; // OVERLOADED with ADDR
assign tlp_tc           = intf_tlp_hdr_int[`F_HDR_TLP_TC          ];

//Determine if target bus of Cfg Type 1 request matches secondary bus:
assign int_tlp_type     = intf_tlp_hdr_int[`F_HDR_TLP_TYPE        ];
assign tlp_type         = int_bus_num_match && int_curnt_iscfgtype1 ? 5'b00100 : int_tlp_type;  // Convert to Type 0 or leave as current Type (from application)
assign int_fmt_type = {tlp_fmt, int_tlp_type};
assign int_curnt_iscfgtype1  =  (int_fmt_type == `CFGWR1) || (int_fmt_type == `CFGRD1) ;
assign int_bus_num_match = 1'b0;

// form basic headers
assign addr64            = (tlp_fmt == 2'b01)         || (tlp_fmt == 2'b11);
assign fmt_type     = {tlp_fmt, tlp_type};
assign curnt_ismsg  = ((fmt_type[6:3] == `MSG_4) || (fmt_type[6:3] == `MSGD_4));
assign curnt_iscpl  = ((fmt_type  == `CPL)    || (fmt_type == `CPLD)  ||
                           (fmt_type  == `CPLLK)  || (fmt_type == `CPLDLK));
assign curnt_iscfgwr  =  (fmt_type == `CFGWR1) || (fmt_type == `CFGWR0) ;
assign curnt_iscfgrd  =  (fmt_type == `CFGRD1) || (fmt_type == `CFGRD0);
assign curnt_isiord   =   (fmt_type == `IORD);
assign curnt_isiowr   =   (fmt_type == `IOWR);
assign curnt_ismemrd =  ((fmt_type == `MRD32)  || (fmt_type == `MRD64) ||
                            (fmt_type == `MRDLK32) || (fmt_type == `MRDLK64));
assign curnt_ismemwr =  ((fmt_type == `MWR32)  || (fmt_type == `MWR64));
assign curnt_isdefmemwr =  0;

// ccx_cond_begin: ;;; Atomic Ops not supported when CX_ATOMIC_ENABLE is not defined
assign curnt_isatomic = (fmt_type == `FETCHADD32) || (fmt_type == `FETCHADD64) ||
                        (fmt_type == `SWAP32)     || (fmt_type == `SWAP64)     ||
                        (fmt_type == `CAS32)      || (fmt_type == `CAS64);
// ccx_cond_end
assign curnt_is_tphmemrd     = curnt_ismemrd     && intf_hdr_th && `CX_TPH_ENABLE_VALUE;
assign curnt_is_tphmemwr     = curnt_ismemwr     && intf_hdr_th && `CX_TPH_ENABLE_VALUE;
assign curnt_is_tphatomic    = curnt_isatomic    && intf_hdr_th && `CX_TPH_ENABLE_VALUE;
assign curnt_is_tph          = curnt_is_tphatomic || curnt_is_tphmemrd || curnt_is_tphmemwr;
assign curnt_istransreq      = curnt_ismemrd && (intf_hdr_ats == 2'b01) && `CX_ATS_ENABLE_VALUE==1;
assign tlp_has_pyld = fmt_type[6];
assign tlp_addr_1_0 = curnt_istransreq ? {1'b0,intf_hdr_nw} :
                      (curnt_is_tph) ? intf_hdr_ph :
                      intf_hdr_rsvd[13:12];
assign tlp_addr_15_12 = intf_tlp_hdr_pt ?
                       intf_hdr_rsvd[11:8] :
                       tlp_addr[15:12];
assign tlp_addr_31_24 = tlp_addr[31:24];
assign trgt_bus_num = tlp_addr_31_24;     // if transaction is a configuration request, then target Bus Number is bits 31 down to 24 of address field.
assign tlp_addr_23_19 = tlp_addr[23:19];  // Device number for non ARI.
//////////////
//////////////
assign tlp_td              = intf_tlp_hdr_int[`F_HDR_TLP_TD          ] || get_ecrc_en(cfg_ecrc_gen_en,tlp_func_num);
assign tlp_byte_len_w_ecrc = {1'b0,tlp_byte_len};
//////////////
//////////////

assign tmp_dw_len = ((!tlp_has_pyld | tlp_byte_len[12]) & (curnt_iscpl | curnt_ismsg))                             ? 10'b0              : // for tlp without data cpl or message or 4K payload
                        (curnt_iscfgrd | curnt_iscfgwr | curnt_isiord | curnt_isiowr | (tlp_byte_len == 13'b0))    ? 10'h001            : // for io or cfg, dw len is 1, and if the byte len
                        (curnt_iscpl | curnt_ismsg | !int_tlp_addr_align_en)                                       ? tlp_byte_len[11:2] : // for cpl and msg that inovles data less than 4k,
                                                                                                                                          // the byte len [1:0] has to be 0 provided by application interface.
                                                                                                                                          // The dw len of header field is driven by application interface
                                                                                                                                          // on the tlp_byte_len_w_ecrc vec.
                         hdr_dw_len[9:0];                                                                                       // calculated dword length for memory read and write.

assign com_dw_len = ((!tlp_has_pyld | tlp_byte_len[12]) & (curnt_iscpl | curnt_ismsg))        ? 10'b0              : // for tlp without data cpl or message or 4K payload
                        (curnt_iscfgrd | curnt_iscfgwr | curnt_isiord | curnt_isiowr | (tlp_byte_len == 13'b0))                      ? 10'h001            : // for io or cfg, dw len is 1, and if the byte len
                        (curnt_iscpl | curnt_ismsg | !int_tlp_addr_align_en)                          ? tlp_byte_len[11:2] : // for cpl and msg that inovles data less than 4k,
                                                                                                                         // the byte len [1:0] has to be 0 provided by application interface.
                                                                                                                         // The dw len of header field is driven by application interface
                                                                                                                         // on the tlp_byte_len_w_ecrc vec.
                         hdr_dw_len[9:0];                                                                                // calculated dword length for memory read and write.

assign int_common_hdr = {com_dw_len[7:0],
                             tlp_td,tlp_ep,tlp_attr[1:0], intf_hdr_ats, com_dw_len[9:8],
 intf_hdr_rsvd[5], tlp_tc, intf_hdr_rsvd[4], tlp_attr[2], intf_hdr_rsvd[2], intf_hdr_th,
                             intf_hdr_rsvd[0], tlp_fmt, tlp_type};

assign common_hdr_pt  = {tlp_byte_len[9:2],
                             tlp_td,tlp_ep,tlp_attr[1:0], intf_hdr_rsvd[7:6], tlp_byte_len[11:10],
 intf_hdr_rsvd[5], tlp_tc, intf_hdr_rsvd[4], tlp_attr[2], intf_hdr_rsvd[2], intf_hdr_rsvd[1],
                             intf_hdr_rsvd[0], tlp_fmt, tlp_type};
// ccx_cond_begin: ;1;1; Excluding condition ( curnt_isatomic == 1) if CX_ATOMIC_ENABLE is not defined
assign int_byte_en     = (curnt_is_tphmemrd | curnt_is_tphatomic) ? intf_hdr_st         : // byte enables carry steering tags for Atomic and MemRd
                          curnt_isatomic                          ? 8'h00               : // byte enables are reserved for atomic request
                          int_tlp_addr_align_en                   ? {last_be, first_be} : // Use calculated BE when addr alignment is enabled
                          tlp_byte_en;
// ccx_cond_end

wire[NF_WD-1:0]   int_func_num;
wire[7:0] func_num_8b;
assign     int_func_num   = (NF > 1) ? ((((`CX_DEVICE_TYPE == `PCIE_SW_UP) | (`CX_DEVICE_TYPE == `PCIE_SW_DOWN) | (`CX_DEVICE_TYPE == `PCIE_PCIX) | (`CX_DEVICE_TYPE == `PCIX_PCIE) )
                              & ((fmt_type == `CPL) | (fmt_type == `CPLLK) | (fmt_type == `CPLD) | (fmt_type == `CPLDLK)))
                           ? cpl_req_id[NF_WD-1:0]
                   : req_id[NF_WD-1:0]) : 0; // locally for function ID so that we can determine whether or not to insert ecrc based on per function ecrc_gen_enable.
assign func_num_8b = {{(8-NF_WD){1'b0}},int_func_num}; // drive at 0 most significant bits

wire [7:0] func_num_8b_rc;
assign func_num_8b_rc = {5'b00000, func_num_8b[2:0]};
assign tlp_func_num = (device_type == `PCIE_RC) ? func_num_8b_rc[NF_WD-1:0] 
                                                : func_num_8b[NF_WD-1:0];


always @(cpl_bcm or cpl_byte_cnt or cpl_req_id
         or cpl_status or fmt_type or int_common_hdr or req_id
         or tlp_addr or int_byte_en or tlp_msg_code
         or tlp_tag or intf_hdr_rsvd or tlp_addr_1_0
         or tlp_addr_23_19
         or addr64 or com_dw_len or common_hdr_pt
         or intf_hdr_ats or intf_tlp_hdr_pt or tlp_attr
         or tlp_byte_len or tlp_ep or tlp_fmt or tlp_tc
         or tlp_td or tlp_type or intf_hdr_th
)

      casez (fmt_type)
        // Memory Read and Write Request
        `MRD32, `MRD64, `MRDLK32, `MRDLK64, `MWR32, `MWR64:
            begin
              if (intf_tlp_hdr_pt) begin
                tmp_hdr       = addr64 ? { tlp_addr[7:2], tlp_addr_1_0, tlp_addr[15:8], tlp_addr[23:16], tlp_addr[31:24],
                                                tlp_addr[39:32], tlp_addr[47:40], tlp_addr[55:48], tlp_addr[63:56],
                                                int_byte_en[7:4], int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                                tlp_byte_len[9:2], tlp_td,tlp_ep,tlp_attr[1:0], intf_hdr_ats, tlp_byte_len[11:10],
 intf_hdr_rsvd[5], tlp_tc, intf_hdr_rsvd[4], tlp_attr[2], intf_hdr_rsvd[2], 
                                                intf_hdr_th, intf_hdr_rsvd[0], tlp_fmt, tlp_type}
                                            : { 32'b0, tlp_addr[7:2], tlp_addr_1_0, tlp_addr[15:8], tlp_addr[23:16], 
                                                tlp_addr[31:24],
                                                int_byte_en[7:4], int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                                tlp_byte_len[9:2], tlp_td,tlp_ep,tlp_attr[1:0], intf_hdr_ats, tlp_byte_len[11:10],
 intf_hdr_rsvd[5], tlp_tc, intf_hdr_rsvd[4], tlp_attr[2], intf_hdr_rsvd[2],
                                                intf_hdr_th, intf_hdr_rsvd[0], tlp_fmt, tlp_type};
              end else begin
                tmp_hdr       = addr64 ? { tlp_addr[7:2], tlp_addr_1_0, tlp_addr[15:8], tlp_addr[23:16], tlp_addr[31:24],
                                                tlp_addr[39:32], tlp_addr[47:40], tlp_addr[55:48], tlp_addr[63:56],
                                                int_byte_en[7:4], int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                                com_dw_len[7:0], tlp_td,tlp_ep,tlp_attr[1:0], intf_hdr_ats, com_dw_len[9:8],
 intf_hdr_rsvd[5], tlp_tc, intf_hdr_rsvd[4], tlp_attr[2], intf_hdr_rsvd[2], 
                                                intf_hdr_th, intf_hdr_rsvd[0], tlp_fmt, tlp_type}
                                            : { 32'b0, tlp_addr[7:2], tlp_addr_1_0, tlp_addr[15:8], tlp_addr[23:16], 
                                                tlp_addr[31:24],
                                                int_byte_en[7:4], int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                                com_dw_len[7:0], tlp_td,tlp_ep,tlp_attr[1:0], intf_hdr_ats, com_dw_len[9:8],
 intf_hdr_rsvd[5], tlp_tc, intf_hdr_rsvd[4], tlp_attr[2], intf_hdr_rsvd[2], 
                                                intf_hdr_th, intf_hdr_rsvd[0], tlp_fmt, tlp_type};
              end
                tlp_is_mem = 1'b1;
            end
        // IO Read and Write Request
        `IORD, `IOWR :
            begin
              if (intf_tlp_hdr_pt) begin
                tmp_hdr       =  { 32'b0, tlp_addr[7:2], intf_hdr_rsvd[13:12], tlp_addr[15:8], tlp_addr[23:16], tlp_addr[31:24],
                                        int_byte_en[7:4],  int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                        common_hdr_pt};
              end else begin
                tmp_hdr       =  { 32'b0, tlp_addr[7:2], intf_hdr_rsvd[13:12], tlp_addr[15:8], tlp_addr[23:16], tlp_addr[31:24],
                                        4'b0,  int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                        8'h01, tlp_td,tlp_ep,2'b0, intf_hdr_rsvd[7:6], 2'b0, intf_hdr_rsvd[5], 3'b0, intf_hdr_rsvd[4:1], intf_hdr_rsvd[0], tlp_fmt, tlp_type};
              end
                tlp_is_mem = 1'b0;
            end
        // CFG Read and Write Requests
        //
        `CFGWR1, `CFGRD1:
            begin
              if (intf_tlp_hdr_pt) begin
                tmp_hdr       =  { 32'b0, tlp_addr[7:2], intf_hdr_rsvd[13:8], tlp_addr[11:8], tlp_addr_23_19, tlp_addr[18:16], tlp_addr[31:24],
                                        int_byte_en[7:4], int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                        common_hdr_pt};
              end else begin
                tmp_hdr       =  { 32'b0, tlp_addr[7:2], intf_hdr_rsvd[13:8], tlp_addr[11:8], tlp_addr_23_19, tlp_addr[18:16], tlp_addr[31:24],
                                        4'b0, int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                        8'h01, tlp_td,tlp_ep,2'b0, intf_hdr_rsvd[7:6], 2'b0, intf_hdr_rsvd[5], 3'b0, intf_hdr_rsvd[4:1], intf_hdr_rsvd[0], tlp_fmt, tlp_type};
              end
                tlp_is_mem = 1'b0;
            end
        `CFGWR0 , `CFGRD0:
            begin
              if (intf_tlp_hdr_pt) begin
                tmp_hdr       =  { 32'b0, tlp_addr[7:2], intf_hdr_rsvd[13:8], tlp_addr[11:8], tlp_addr_23_19, tlp_addr[18:16], tlp_addr[31:24],
                                        int_byte_en[7:4], int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                        common_hdr_pt};
              end else begin
                tmp_hdr       =  { 32'b0, tlp_addr[7:2], intf_hdr_rsvd[13:8], tlp_addr[11:8], tlp_addr_23_19, tlp_addr[18:16], tlp_addr[31:24],
                                        4'b0, int_byte_en[3:0], tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                        8'h01, tlp_td,tlp_ep,2'b0, intf_hdr_rsvd[7:6], 2'b0, intf_hdr_rsvd[5], 3'b0, intf_hdr_rsvd[4:1], intf_hdr_rsvd[0], tlp_fmt, tlp_type};
              end
                tlp_is_mem = 1'b0;
            end

        // CPL
        `CPL, `CPLLK, `CPLD, `CPLDLK:
            begin
              if (intf_tlp_hdr_pt) begin
                  tmp_hdr        =  { 32'h0,
                                    intf_hdr_rsvd[14], tlp_addr[6:0], tlp_tag[0+:8], cpl_req_id[7:0], cpl_req_id[15:8],
                                    cpl_byte_cnt[7:0], cpl_status, cpl_bcm, cpl_byte_cnt[11:8], req_id[7:0], req_id[15:8],
                                    common_hdr_pt};
              end else begin
                  tmp_hdr        =  { 32'h0,
                                    intf_hdr_rsvd[14], tlp_addr[6:0], tlp_tag[0+:8], cpl_req_id[7:0], cpl_req_id[15:8],
                                    cpl_byte_cnt[7:0], cpl_status, cpl_bcm, cpl_byte_cnt[11:8], req_id[7:0], req_id[15:8],
                                    int_common_hdr};
              end
                  tlp_is_mem = 1'b0;
            end
        `MSG , `MSGD:  // msg with out data
            begin
              if (intf_tlp_hdr_pt) begin
                tmp_hdr       = { tlp_addr[7:0],tlp_addr[15:8], tlp_addr[23:16], tlp_addr[31:24],
                                  tlp_addr[39:32], tlp_addr[47:40], tlp_addr[55:48], tlp_addr[63:56],
                                    tlp_msg_code,tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                    common_hdr_pt};
              end else begin
                tmp_hdr       = { tlp_addr[7:0],tlp_addr[15:8], tlp_addr[23:16], tlp_addr[31:24],
                                  tlp_addr[39:32], tlp_addr[47:40], tlp_addr[55:48], tlp_addr[63:56],
                                    tlp_msg_code,tlp_tag[0+:8], req_id[7:0], req_id[15:8],
                                    int_common_hdr};
              end
                tlp_is_mem = 1'b0;
            end
        default:
        begin
                tmp_hdr      = 0;
                tlp_is_mem   = 1'b0;
        end
        endcase

// ------------------------------------------------------------------------------------------------
// First DW and Last DW offsets
// ------------------------------------------------------------------------------------------------

//
// 1st BE to fill the header field
//

assign tlp_dwlen_nonzero = |tlp_byte_len[12:2];

always @(tlp_byte_len or tlp_addr or tlp_dwlen_nonzero)
     casez ({tlp_addr[1:0], tlp_byte_len[1:0]})
        4'b0000: first_be = tlp_dwlen_nonzero ? 4'b1111 : 4'b0000;
// ccx_line_cond_begin: ; Redundant code for configs where GLOB_ADDR_ALIGN_EN = 0 because the core does not support address alignment and does not generate the first and last byte enables (FBE, LBE) based on the address and number of bytes of the TLP requested from the client interface
        4'b0001: first_be = tlp_dwlen_nonzero ? 4'b1111 : 4'b0001;
        4'b0010: first_be = tlp_dwlen_nonzero ? 4'b1111 : 4'b0011;
        4'b0011: first_be = tlp_dwlen_nonzero ? 4'b1111 : 4'b0111;
// ccx_line_cond_end
        4'b0100: first_be = tlp_dwlen_nonzero ? 4'b1110 : 4'b0000;
// ccx_line_cond_begin: ; Redundant code for configs where GLOB_ADDR_ALIGN_EN = 0
        4'b0101: first_be = tlp_dwlen_nonzero ? 4'b1110 : 4'b0010;
        4'b0110: first_be = tlp_dwlen_nonzero ? 4'b1110 : 4'b0110;
        4'b0111: first_be = 4'b1110;
// ccx_line_cond_end
        4'b1000: first_be = tlp_dwlen_nonzero ? 4'b1100 : 4'b0000;
// ccx_line_cond_begin: ; Redundant code for configs where GLOB_ADDR_ALIGN_EN = 0
        4'b1001: first_be = tlp_dwlen_nonzero ? 4'b1100 : 4'b0100;
        4'b101?: first_be = 4'b1100;
// ccx_line_cond_end
        4'b1100: first_be = tlp_dwlen_nonzero ? 4'b1000 : 4'b0000;
// ccx_line_begin: ; Redundant code for configs where GLOB_ADDR_ALIGN_EN = 0
        4'b1101: first_be = 4'b1000;
        4'b111?: first_be = 4'b1000;
// ccx_line_end
     endcase

//
// Case 1: Data may not be at memory DW boundry when come from application
// last dw count calulation to fill the header dwlength field
// data is aligned for DW

assign   last_be              = 4'h0;
assign   hdr_dw_len_w_ecrc    = |tlp_byte_len_w_ecrc ?  (|tlp_byte_len_w_ecrc[1:0] ? (tlp_byte_len_w_ecrc[12:2] + 1'b1) : tlp_byte_len_w_ecrc[12:2]) : 11'h001;   
assign   hdr_dw_len           = hdr_dw_len_w_ecrc[9:0];

// =====================================================================================
//             HEADER Formation --  End
// =====================================================================================

// Output Assignment
//
// ECC GEN
wire   tlp_formed_hdr_parerr;
assign tlp_formed_hdr_parerr  = 1'b0;
assign   tlp_formed_hdr       = tmp_hdr;

assign   tlp_formed_last_dwen = dw_decode(tmp_dw_len[LEN_OFFSET_WIDTH-1:0]);
// for transactions required data alignment
assign   tlp_data_align_en   = (curnt_ismemwr | curnt_isdefmemwr | curnt_iscfgwr | curnt_isiowr) & int_tlp_addr_align_en;
assign   tlp_formed_add_ecrc = !intf_tlp_hdr_pt & tlp_td;


 wire   prfx_formed_parerr; 
 assign prfx_formed_parerr        = 1'b0;


function automatic [NW-1:0] dw_decode;
input [LEN_OFFSET_WIDTH-1:0] len;

reg     [NW-1:0]   l_decode;
begin
    l_decode = (len[0]) ? 2'b01 : 2'b11 ;
  dw_decode = l_decode[NW-1:0];
end
endfunction


function automatic get_ecrc_en;
    input [NF-1:0] cfg_ecrc_gen_en;
    input [NF_WD-1:0] tlp_func_num;
    integer i;
    begin
        get_ecrc_en = 0;
        for (i=0; i<NF; i=i+1) begin
            if (i== tlp_func_num)
                get_ecrc_en = cfg_ecrc_gen_en[i];
        end
    end
endfunction

endmodule

