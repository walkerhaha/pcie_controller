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
// ---    $DateTime: 2020/09/18 02:33:28 $
// ---    $Revision: #17 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/xadm.sv#17 $
// -------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// XADM module contains 6 sub modules.
// XADM_ARB: It arbitrates the different tlp transmit requests.
// There are four sources that arbitrate for transmission of a tlp to xtlh.
// These tlps are: client0, client1, completion I/F and internal generated message
// due to error, interrupt, etc.
// The arbitration results are determined on the credits available and priority.
// Priority of arbitration is : Internal MSG  is highest priority, cpl is
// the second, and round robin between client interfaces.
//
// XADM_FC: This is FC calculating block. It does the flow control credit
// calculating to gate the transmission requests from these four interfaces. The
// request of any of the four interfaces will be granted according to the
// above priority only if the requested tlp consumed allowable credits. The
// key assumption is that all four interfaces here are order independent.
// In other words, any of the requests can by-pass others.
//
// XADM_OUT_FORMATION: this takes formed 128bit TLPs converts to data path to 64/32
// bit data path applications -- as configured.
//
// XADM_MUX: It multiplexes the incoming client interfaces.
// This block receives control from the arbitration block, and act to control client
// interface back pressure as needed.
//
// XADM_HDR_FORM: Form PCIE tlp header received from the XADM_MUX.
//
// XADM_DATA_ALIGN: provide addess alignment for the byte address offset
//
// Note: There is no queues in XADM. All four interfaces contain halt
// signals to allow back presure when xtlh could not accept the next valid
// data.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Adm/client_defs_pkg.svh"

module xadm

import client_defs_pkg::*;
   (
    // ----------- Inputs -----------
    core_clk,
    core_rst_n,
    rstctl_core_flush_req,
    cfg_max_payload_size,
    cfg_vc_enable,
    cfg_vc_struc_vc_id_map,
    cfg_tc_struc_vc_map,
    cfg_lpvc_wrr_weight,
    cfg_lpvc_wrr_phase,
    cfg_lpvc,
    cfg_tc_vc_map,
    cfg_ecrc_gen_en,
    cfg_trgt_cpl_lut_delete_entry,
    cfg_max_rd_req_size,
    cfg_hq_depths,
    cfg_dq_depths,
    xtlh_xadm_halt,

    client0_addr_align_en,
    client0_tlp_byte_en,
    client0_cpl_req_id,
    client0_cpl_status,
    client0_cpl_bcm,
    client0_cpl_byte_cnt,
    client0_req_id,
    client0_tlp_dv,
    client0_tlp_hv,
    client0_tlp_eot,
    client0_tlp_data,
    client0_tlp_bad_eot,
    client0_tlp_fmt,
    client0_tlp_type,
    client0_tlp_tc,
    client0_tlp_td,
    client0_tlp_ep,
    client0_tlp_attr,
    client0_tlp_byte_len,
    client0_tlp_tid,
    client0_tlp_addr,






    client1_addr_align_en,
    client1_tlp_byte_en,
    client1_cpl_req_id,
    client1_cpl_status,
    client1_cpl_bcm,
    client1_cpl_byte_cnt,
    client1_req_id,
    client1_tlp_dv,
    client1_tlp_hv,
    client1_tlp_eot,
    client1_tlp_data,
    client1_tlp_bad_eot,
    client1_tlp_fmt,
    client1_tlp_type,
    client1_tlp_tc,
    client1_tlp_td,
    client1_tlp_ep,
    client1_tlp_attr,
    client1_tlp_byte_len,
    client1_tlp_tid,
    client1_tlp_addr,



    radm_trgt1_hv,
    radm_trgt1_eot,
    radm_trgt1_tlp_abort,
    radm_trgt1_dllp_abort,
    radm_trgt1_fmt,
    radm_trgt1_type,
    radm_trgt1_dw_len,
    radm_trgt1_addr,
 
    radm_trgt1_cpl_last, 
    radm_trgt1_cpl_status,
    radm_trgt1_byte_cnt,

    radm_trgt1_tc,
    radm_trgt1_tag,
    trgt1_radm_halt,

    radm_cpl_timeout,    
    radm_timeout_cpl_byte_len,
    radm_timeout_cpl_tc,
    radm_timeout_cpl_tag,



    lbc_cpl_dv,
    lbc_cpl_hv ,
    lbc_cpl_data,
    lbc_cpl_hdr,
    lbc_cpl_eot,

    msg_gen_hv,
    msg_gen_dv,
    msg_gen_eot,
    msg_gen_data,
    msg_gen_hdr,
    pm_xtlh_block_tlp,
    cfg_client0_block_new_tlp,
    cfg_client1_block_new_tlp,
    cfg_client2_block_new_tlp,
    pm_block_all_tlp,
    rdlh_link_down,
    rtlh_rfc_upd,
    rtlh_rfc_data,
    rtlh_fc_init_status,
    xtlh_xadm_restore_enable,
    xtlh_xadm_restore_capture,
    xtlh_xadm_restore_tc,
    xtlh_xadm_restore_type,
    xtlh_xadm_restore_word_len,

    radm_grant_tlp_type,
    trgt_lut_trgt1_radm_pkt_halt,
    cfg_2ndbus_num,
    device_type,
// --------- Outputs ---------

    xadm_client0_halt,
    xadm_client1_halt,
    xadm_msg_halt,
    xadm_cpl_halt,

    xadm_xtlh_soh,
    xadm_xtlh_hv,
    xadm_xtlh_dv,
    xadm_xtlh_data,
    xadm_xtlh_hdr,
    xadm_xtlh_dwen,
    xadm_xtlh_vc,
    xadm_xtlh_eot,
    xadm_xtlh_bad_eot,
    xadm_xtlh_add_ecrc,
    xadm_tlp_pending,
    xadm_block_tlp_ack,
    xadm_no_fc_credit,
    xadm_had_enough_credit,
    xadm_all_type_infinite,
    xadm_ph_cdts,
    xadm_pd_cdts,
    xadm_nph_cdts,
    xadm_npd_cdts,
    xadm_cplh_cdts,
    xadm_cpld_cdts,
    //DE:Deadlock fix
    lbc_deadlock_det,
    xadm_parerr_detected
);
parameter   INST         = 0;                           // The uniquifying parameter for each port logic instance.
parameter   NW           = `CX_NW;                      // Number of 32-bit dwords handled by the datapath each clock.
parameter   NB           = `CX_NB;                      // Number of bytes per cycle per lane
parameter   DW           = (32*NW) + `TRGT_DATA_PROT_WD;// Width of datapath in bits. Plus parity for the special function
parameter   DATA_PAR_WD  = `TRGT_DATA_PROT_WD;
parameter RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1; // Max number of DLLPs received per cycle
parameter   NVC          = `CX_NVC;                     // Number of virtual channels
parameter   NVC_XALI_EXP = `CX_NVC_XALI_EXPANSION;      // Max number of Virtual Channels used on Xali Expansion
parameter   NCL          = `CX_NCLIENTS + 2;            // Two user clients plus the MSG and CPL interfaces
parameter   ST_HDR       = `ST_HDR;                     // XADM Common Header Width.
parameter   HDR_PROT_WD  = `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD; // XADM Common Header ecc/parity protection width
parameter   LBC_MSG_HDR_WD= `ST_HDR
                                  ;
parameter   NF           = `CX_NFUNC;                   // Number of functions
parameter   WRR_ARB_WD   = `CX_XADM_ARB_WRR_WEIGHT_BIT_WIDTH;
parameter   TP           = `TP;                         // Clock to Q delay (simulator insurance)
parameter   PF_WD        = `CX_NFUNC_WD;                // Width of virtual function number signal
parameter   BUSNUM_WD    = `CX_BUSNUM_WD;               // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter   DEVNUM_WD    = `CX_DEVNUM_WD;               // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.
localparam ATTR_WD = `SF_HDR_TLP_ATTR;
parameter RAS_PCIE_HDR_PROT_WD = `CX_RAS_PCIE_HDR_PROT_WD;
parameter RAS_HDR_WD           = 128 + RAS_PCIE_HDR_PROT_WD;



parameter   LBC_INT_WD        = `CX_LBC_INT_WD;    // LBC - XADM data bus width can be 32, 64 or 128

parameter LEN_OFFSET_WIDTH = NW==16 ? 6 : NW==8 ? 5 : NW==4 ? 4 : NW==2 ? 3 : 2;  // bus width of tlp_raw_bytelen_offset in xadm_data_align module


parameter CLIENT0_INDEX = 2;
parameter CLIENT1_INDEX = 3;
parameter CLIENT2_INDEX = 4;


localparam TAG_SIZE    = `CX_TAG_SIZE;
localparam LOOKUPID_WD = `CX_REMOTE_LOOKUPID_WD;

localparam HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
localparam DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;

// CCIX related parameters
localparam CX_CCIX_HDR_WD       = RAS_HDR_WD;     
localparam CX_CCIX_DATA_WD      = DW;  

// ---------------- Inputs -----------------
input                      core_clk;
input                      core_rst_n;
input                      rstctl_core_flush_req;
input [2:0]                cfg_max_payload_size;
input [NVC-1:0]            cfg_vc_enable;                // Which VCs are enabled - VC0 is always enabled
input [(NVC*3)-1:0]        cfg_vc_struc_vc_id_map;       // VC Structure to VC ID mapping
input [23:0]               cfg_tc_vc_map;                // Index by TC, returns VC
input [23:0]               cfg_tc_struc_vc_map;          // Index by TC, returns structure VC ID number
input [(8*WRR_ARB_WD)-1:0] cfg_lpvc_wrr_weight;
input [1:0]                cfg_lpvc_wrr_phase;
input [2:0]                cfg_lpvc;

input                      xtlh_xadm_halt;               // xtlh layer asserts halt to stop the XADM transmition momentarily

input [NF-1:0]             cfg_ecrc_gen_en;              // enables ECRC assertion per function
input [31:0]               cfg_trgt_cpl_lut_delete_entry;// (PL) trgt_cpl_lut delete one entry
input [(3*NF)-1:0]         cfg_max_rd_req_size;
input [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0]  cfg_hq_depths;
input [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0] cfg_dq_depths;
// Client 0 interface
input [NVC_XALI_EXP-1:0]            client0_addr_align_en;        // 1-XADM will does address alignment, prempting ; 0-use client0_tlp_byte_en
input [(NVC_XALI_EXP*8)-1:0]        client0_tlp_byte_en;          // first/last byte enables per pcie spec, used only if client0_addr_align_en=0;
input [(NVC_XALI_EXP*16)-1:0]       client0_cpl_req_id;           // Completion's Requester's ID
input [(NVC_XALI_EXP*3)-1:0]        client0_cpl_status;           // Completion status
input [NVC_XALI_EXP-1:0]            client0_cpl_bcm;              // BCM bit (for Bridge only), tie LOW for EP
input [(NVC_XALI_EXP*12)-1:0]       client0_cpl_byte_cnt;         // Completion byte count
input [(NVC_XALI_EXP*16)-1:0]       client0_req_id;               // Curnt PCIE port's id
input [NVC_XALI_EXP-1:0]            client0_tlp_dv;               // TLP data valid
input [NVC_XALI_EXP-1:0]            client0_tlp_eot;              // end of TLP
input [NVC_XALI_EXP-1:0]            client0_tlp_bad_eot;          // BAD EOT
input [NVC_XALI_EXP-1:0]            client0_tlp_hv;               // Header valid
input [(NVC_XALI_EXP*2)-1:0]        client0_tlp_fmt;              // TLP Header Format
input [(NVC_XALI_EXP*5)-1:0]        client0_tlp_type;             // TLP Header Type field
input [(NVC_XALI_EXP*3)-1:0]        client0_tlp_tc;               // TLP Header TC
input [NVC_XALI_EXP-1:0]            client0_tlp_td;               // TLP Header digest
input [NVC_XALI_EXP-1:0]            client0_tlp_ep;               // TLP Header EP
input [(NVC_XALI_EXP*ATTR_WD)-1:0]  client0_tlp_attr;             // TLP Header Attibutes
input [(NVC_XALI_EXP*13)-1:0]       client0_tlp_byte_len;         // TLP Header Byte Length, 13'h0 for 0 byte, 13'h1000 for 4K bytes
input [(NVC_XALI_EXP*TAG_SIZE)-1:0] client0_tlp_tid;              // TLP Header TAG ID
input [(NVC_XALI_EXP*64)-1:0]       client0_tlp_addr;             // TLP Header address
input [(NVC_XALI_EXP*DW)-1:0]       client0_tlp_data;             // TLP Data Payload




// Client 1 Interface
input [NVC_XALI_EXP-1:0]            client1_addr_align_en;        // 1-XADM will does address alignment, prempting ; 0-use client1_tlp_byte_en
input [(NVC_XALI_EXP*8)-1:0]        client1_tlp_byte_en;          // first/last byte enables per pcie spec, used only if client1_addr_align_en=0;
input [(NVC_XALI_EXP*16)-1:0]       client1_cpl_req_id;           // Completion's Requester's ID

input [(NVC_XALI_EXP*3)-1:0]        client1_cpl_status;           // Completion status
input [NVC_XALI_EXP-1:0]            client1_cpl_bcm;              // BCM bit (for Bridge only), tie LOW for EP
input [(NVC_XALI_EXP*12)-1:0]       client1_cpl_byte_cnt;         // Completion byte count
input [(NVC_XALI_EXP*16)-1:0]       client1_req_id;               // Curnt PCIE port's id
input [NVC_XALI_EXP-1:0]            client1_tlp_dv;               // TLP data valid
input [NVC_XALI_EXP-1:0]            client1_tlp_eot;              // end of TLP
input [NVC_XALI_EXP-1:0]            client1_tlp_bad_eot;          // BAD EOT
input [NVC_XALI_EXP-1:0]            client1_tlp_hv;               // Header valid
input [(NVC_XALI_EXP*2)-1:0]        client1_tlp_fmt;              // TLP Header Format
input [(NVC_XALI_EXP*5)-1:0]        client1_tlp_type;             // TLP Header Type field
input [(NVC_XALI_EXP*3)-1:0]        client1_tlp_tc;               // TLP Header TC
input [NVC_XALI_EXP-1:0]            client1_tlp_td;               // TLP Header digest
input [NVC_XALI_EXP-1:0]            client1_tlp_ep;               // TLP Header EP
input [(NVC_XALI_EXP*ATTR_WD)-1:0]  client1_tlp_attr;             // TLP Header Attibutes
input [(NVC_XALI_EXP*13)-1:0]       client1_tlp_byte_len;         // TLP Header Byte Length, 13'h0 for 0 byte, 13'h1000 for 4K bytes
input [(NVC_XALI_EXP*TAG_SIZE)-1:0] client1_tlp_tid;              // TLP Header TAG ID
input [(NVC_XALI_EXP*64)-1:0]       client1_tlp_addr;             // TLP Header address
input [(NVC_XALI_EXP*DW)-1:0]       client1_tlp_data;             // TLP Data Payload




// SW || !TRGT1 => NO TRGT_LUT, NO CPLQ_MNG => !(SW || !TRGT1)=!SW && TRGT1
input                      radm_trgt1_hv;
input                      radm_trgt1_eot;
input                      radm_trgt1_tlp_abort;
input                      radm_trgt1_dllp_abort;
input [1:0]                radm_trgt1_fmt;
input [4:0]                radm_trgt1_type;
input [9:0]                radm_trgt1_dw_len;
input [6:0]                radm_trgt1_addr;
input                      radm_trgt1_cpl_last;
input [2:0]                radm_trgt1_cpl_status;
input [11:0]               radm_trgt1_byte_cnt;

input [2:0]                radm_trgt1_tc;
input [TAG_SIZE-1:0]       radm_trgt1_tag;
input                      trgt1_radm_halt;

input                      radm_cpl_timeout;
input [11:0]               radm_timeout_cpl_byte_len;
input [2:0]                radm_timeout_cpl_tc;
input [TAG_SIZE-1:0]       radm_timeout_cpl_tag;

wire                       xadm_halted;                  // Combination of xtlh_xadm_halt and the halt of the xadm_out_formation

// from CDM MSG GEN
input                      msg_gen_hv;                   // CDM generated MSG Header Valid
input                      msg_gen_dv;                   // CDM generated MSG Data valid
input                      msg_gen_eot;                  // CDM generated MSG EOT
input [DW-1:0]             msg_gen_data;                 // CDM generated MSG data
input [LBC_MSG_HDR_WD-1:0] msg_gen_hdr;              // CDM generated MSG hdr (with protection is RAS is used)


// from RADM
input                      lbc_cpl_hv;                   // RADM generated CPL Header Valid
input                      lbc_cpl_dv;                   // RADM generated CPL request with valid data
input [DW-1:0]             lbc_cpl_data;                 // RADM generated CPL data
input [LBC_MSG_HDR_WD-1:0] lbc_cpl_hdr;              // RADM generated CPL hdr (with address protection if RAS is used)
input                      lbc_cpl_eot;                  // RADM generated CPL eot
//DE: Deadlock Fix
input                      lbc_deadlock_det;

input                      pm_xtlh_block_tlp;            // power management module to block the scheduling of the next tlp
input                      cfg_client0_block_new_tlp;    // power management module to block the scheduling of the next tlp for Client0
input                      cfg_client1_block_new_tlp;    // power management module to block the scheduling of the next tlp for Client1
input                      cfg_client2_block_new_tlp;    // power management module to block the scheduling of the next tlp for Client2
input                      pm_block_all_tlp;             // power management module assert to block all TLPs
input                      rdlh_link_down;               // RDLH data link down
input [RX_NDLLP-1:0]       rtlh_rfc_upd;                 // FC pkt rcvd
input [NVC-1:0]            rtlh_fc_init_status;          // per VC init status
input [RX_NDLLP*32-1:0]    rtlh_rfc_data;                // FC data from RTLH
input                      xtlh_xadm_restore_enable;
input                      xtlh_xadm_restore_capture;
input  [2:0]               xtlh_xadm_restore_tc;
input  [6:0]               xtlh_xadm_restore_type;
input  [9:0]               xtlh_xadm_restore_word_len;




input  [(NVC*3)-1:0]       radm_grant_tlp_type;
output [(NVC*3)-1:0]       trgt_lut_trgt1_radm_pkt_halt;
input [3:0]                device_type;                  //Device type - RC, EP, SW or DM.
input  [(8*NF)-1:0]        cfg_2ndbus_num;               // Secondary Bus Number


// -------------   output signals  --------------
output [NVC_XALI_EXP-1:0]           xadm_client0_halt;            // XADM halts traffics from Client0
output [NVC_XALI_EXP-1:0]           xadm_client1_halt;            // XADM halts traffics from Client1
output                     xadm_msg_halt;                // XADM halts CDM MSG generation
output                     xadm_cpl_halt;                // XADM halts LBC CPL generation

output [1:0]               xadm_xtlh_soh;                // Indicates start of header loacation for 32/64-bit
output                     xadm_xtlh_hv;                 // hdr valid
output                     xadm_xtlh_dv;                 // data valid
output [2:0]               xadm_xtlh_vc;                 // vc
output [DW-1:0]            xadm_xtlh_data;               // tlp data bus (with Header formed)
output [RAS_HDR_WD-1:0]    xadm_xtlh_hdr;                // tlp hdr bus (with Header formed)
output [NW-1:0]            xadm_xtlh_dwen;               // dword enable of the data bus
output                     xadm_xtlh_eot;                // end of transaction
output                     xadm_xtlh_bad_eot;            // bad end of transaction for test purpose
output                     xadm_xtlh_add_ecrc;




output                     xadm_tlp_pending;             // indicates that there is a tlp pending in the datapath
output                     xadm_block_tlp_ack;           // Indicates that TLP transmission has been blocked and there are no in progress TLP's
output [NVC-1:0]           xadm_no_fc_credit;            // Indicates that there is no FC credit available for power management protocol
output [NVC-1:0]           xadm_had_enough_credit;       // indicate that there is enough credit for power management protocol
output                     xadm_all_type_infinite;       // Indicate to receiver that all tlp types are advertised by the remote site as infinite credit so that rtlh can block watch dog timer
output [NVC*HCRD_WD-1:0]   xadm_ph_cdts;                 // header for P credits
output [NVC*DCRD_WD-1:0]   xadm_pd_cdts;                 // data for P credits
output [NVC*HCRD_WD-1:0]   xadm_nph_cdts;                // header for NPR credits
output [NVC*DCRD_WD-1:0]   xadm_npd_cdts;                // data for NPR credits
output [NVC*HCRD_WD-1:0]   xadm_cplh_cdts;               // header for cPL credits
output [NVC*DCRD_WD-1:0]   xadm_cpld_cdts;               // data for cPL credits
output                     xadm_parerr_detected;



//ifdef VCs output msg and cpl traffic class






wire [ST_HDR-1:0]   client0_hdr;
wire client0_hdr_err_detect;
wire client0_hdr_err_multpl;
// wire [ST_HDR+HDR_PROT_WD-1:0] client0_hdr_p;


wire [12:0]          client0_tlp_byte_len_p;
wire [ 2:0]          client0_tlp_tc_p;
wire [ 4:0]          client0_tlp_type_p;
wire [ 1:0]          client0_tlp_fmt_p;
wire [63:0]          client0_tlp_addr_p;
//wire                 xadm_client0_halt;
wire [4:0]           int_client0_tlp_type;             // TLP Header Type field
wire [1:0]           int_client0_tlp_fmt;              // TLP Header Fmt field
wire [2:0]           int_client0_tlp_tc;               // TLP Header TC
//wire                 xadm_client1_halt;
wire [ST_HDR-1:0]   client1_hdr;
wire client1_hdr_err_detect;
wire client1_hdr_err_multpl;
// wire [ST_HDR+HDR_PROT_WD-1:0] client1_hdr_p;
wire [12:0]          client1_tlp_byte_len_p;
wire [ 2:0]          client1_tlp_tc_p;
wire [ 4:0]          client1_tlp_type_p;
wire [ 1:0]          client1_tlp_fmt_p;
wire [63:0]          client1_tlp_addr_p;
wire [4:0]           int_client1_tlp_type;             // TLP Header Type field
wire [1:0]           int_client1_tlp_fmt;              // TLP Header Fmt field
wire [2:0]           int_client1_tlp_tc;               // TLP Header TC

wire                 arb_grant_valid;
wire [NCL-1:0]       active_grant;
wire [NCL-1:0]       grant_ack;
wire [(NCL*3)-1:0]   clients_tc;

wire                 arb_enable;
wire                 clear_active_grant;
wire [NCL-1:0]       arb_reqs;
wire [NCL*7-1:0]     clients_type;

wire [NCL*13-1:0]    clients_byte_len;
wire [NCL*2-1:0]     clients_addr_offset;

wire [NCL*NVC-1:0]   fc_cds_pass;
wire [NCL*NVC-1:0]   next_fc_cds_pass;

wire                 tlp_is_mem;
wire                 addr64;
wire                 xadm_xtlh_sot;
wire                 xtlh_xadm_restore_enable;
wire                 xtlh_xadm_restore_capture;
wire [2:0]           xtlh_xadm_restore_tc;
wire [6:0]           xtlh_xadm_restore_type;
wire [9:0]           xtlh_xadm_restore_word_len;

wire                 data_align_out_halt;
wire [NVC-1:0]       vc_arb_halt;
wire                 mux_out_hv;
wire [ST_HDR-1:0]    out_hdr;
wire  [ST_HDR-1:0]    out_hdr_tmp;
wire [ST_HDR-1:0]    mux_out_hdr;
wire [14:0]          mux_hdr_rsvd;
wire [1:0]           mux_hdr_ats;
wire                 mux_hdr_nw;
wire                 mux_hdr_th;
wire [1:0]           mux_hdr_ph;
wire [7:0]           mux_hdr_st;
wire                 mux_out_dv;
wire [DW-1:0]        mux_out_data;
wire                 mux_out_eot;
wire                 mux_out_bad_eot;
wire [63:0]          mux_out_hdr_addr;
wire [1:0]           mux_out_addr_byte_offset;
wire [12:0]          mux_out_byte_len;


wire [DW-1:0]        formed_tlp_data;
wire [RAS_HDR_WD-1:0]formed_tlp_hdr;       // header bus with RAS Logic  
wire                 formed_tlp_dv;
wire                 formed_tlp_hv;
wire                 formed_tlp_eot;
wire                 formed_tlp_badeot;
wire [NW-1:0]        formed_tlp_dwen;
wire [NW-1:0]        formed_last_dwen;
wire                 formed_tlp_add_ecrc;
wire                 out_formation_out_halt;
wire                 formation_out_halt;


wire  [2:0]          xadm_xtlh_vc;
assign xadm_xtlh_vc = 3'b0;            // Not needed signal defined for legacy interface protocol of cxpl
wire [NVC-1:0]       int_all_type_infinite;
wire                 xadm_all_type_infinite;
assign xadm_all_type_infinite = &int_all_type_infinite; //acrossing all VC

wire                 formed_addr_parerr, formed_data_parerr , xadm_xtlh_parerr;
wire                 tlp_data_align_en;






wire [NVC_XALI_EXP-1:0] xadm_tlp_fltr_bad_eot;     // Bad EOT after TLP filter

wire  formed_prfx_parerr;


wire xadm_mux_idle;


logic [NVC-1:0] msg_gen_tlp_rdy, lbc_cpl_tlp_rdy;

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
assign  xadm_parerr_detected   = 1'b0;




//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



// ---------------------------------- Internal Design ---------------------------------------------



// Client 0 interface ----- Registers ---- 
reg                      client0_addr_align_en_reg;        // 1-XADM will does address alignment, prempting _reg; 0-use client0_tlp_byte_en
reg [7:0]                client0_tlp_byte_en_reg;          // first/last byte enables per pcie spec, used only if client0_addr_align_en=0_reg;
reg [15:0]               client0_cpl_req_id_reg;           // Completion's Requester's ID
reg [2:0]                client0_cpl_status_reg;           // Completion status
reg                      client0_cpl_bcm_reg;              // BCM bit (for Bridge only), tie LOW for EP
reg [11:0]               client0_cpl_byte_cnt_reg;         // Completion byte count
reg [15:0]               client0_req_id_reg;               // Curnt PCIE port's id
reg                      client0_tlp_dv_reg;               // TLP data valid
reg                      client0_tlp_eot_reg;              // end of TLP
reg                      client0_tlp_bad_eot_reg;          // BAD EOT
reg                      client0_tlp_hv_reg;               // Header valid
reg [1:0]                client0_tlp_fmt_reg;              // TLP Header Format
reg [4:0]                client0_tlp_type_reg;             // TLP Header Type field
reg [2:0]                client0_tlp_tc_reg;               // TLP Header TC
reg                      client0_tlp_td_reg;               // TLP Header digest
reg                      client0_tlp_ep_reg;               // TLP Header EP
reg [ATTR_WD-1:0]        client0_tlp_attr_reg;             // TLP Header Attibutes
reg [12:0]               client0_tlp_byte_len_reg;         // TLP Header Byte Length, 13'h0 for 0 byte, 13'h1000 for 4K bytes
reg [TAG_SIZE-1:0]       client0_tlp_tid_reg;              // TLP Header TAG ID
reg [63:0]               client0_tlp_addr_reg;             // TLP Header address
reg [DW -1 :0]           client0_tlp_data_reg;             // TLP Data Payload






// ### IF TRGT1 && CLIENT1 DEFINED = CX_CPLQ_MNGM_ENABLE
wire next_credit_enough_all_cplq_management, next_2credit_enough_all_cplq_management;
wire [NVC-1:0] client0_cdts_pass_cplq_management_vc, client1_cdts_pass_cplq_management_vc, client2_cdts_pass_cplq_management_vc;

reg                      client0_tlp_eot_int_reg;
reg                      client0_tlp_bad_eot_int_reg;
reg                      client0_tlp_hv_int_reg; 

always @(posedge core_clk or negedge core_rst_n)
begin
  if (!core_rst_n) begin
  client0_tlp_eot_int_reg           <= #TP  'd0 ;    // end of TLP
  client0_tlp_bad_eot_int_reg       <= #TP  'd0 ;    // BAD EOT
  client0_tlp_hv_int_reg            <= #TP  'd0 ;    // Header valid
  end
  else begin//no enable signal to sampling the HV / EOT and BADEOT.
       //It's usefull to clear request when the clients decides to release the request and there is an internal halt
  client0_tlp_eot_int_reg           <= #TP  client0_tlp_eot;      // end of TLP
  client0_tlp_bad_eot_int_reg       <= #TP  client0_tlp_bad_eot;  // BAD EOT
  client0_tlp_hv_int_reg            <= #TP  client0_tlp_hv;         // Header valid
  end
end

//Client 0 Interface Registered
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
  client0_addr_align_en_reg     <= #TP  'd0 ;    // 1-XADM will does address alignment, prempting _reg <= #TP  'd0 ; 0-use client0_tlp_byte_en
  client0_tlp_byte_en_reg       <= #TP  'd0 ;    // first/last byte enables per pcie spec, used only if client0_addr_align_en=0_reg <= #TP  'd0 ;
  client0_cpl_req_id_reg        <= #TP  'd0 ;    // Completion's Requester's ID
  client0_cpl_status_reg        <= #TP  'd0 ;    // Completion status
  client0_cpl_bcm_reg           <= #TP  'd0 ;    // BCM bit (for Bridge only), tie LOW for EP
  client0_cpl_byte_cnt_reg      <= #TP  'd0 ;    // Completion byte count
  client0_req_id_reg            <= #TP  'd0 ;    // Curnt PCIE port's id
  client0_tlp_dv_reg            <= #TP  'd0 ;    // TLP data valid
  client0_tlp_eot_reg           <= #TP  'd0 ;    // end of TLP
  client0_tlp_bad_eot_reg       <= #TP  'd0 ;    // BAD EOT
  client0_tlp_hv_reg            <= #TP  'd0 ;    // Header valid
  client0_tlp_fmt_reg           <= #TP  'd0 ;    // TLP Header Format
  client0_tlp_type_reg          <= #TP  'd0 ;    // TLP Header Type field
  client0_tlp_tc_reg            <= #TP  'd0 ;    // TLP Header TC
  client0_tlp_td_reg            <= #TP  'd0 ;    // TLP Header digest
  client0_tlp_ep_reg            <= #TP  'd0 ;    // TLP Header EP
  client0_tlp_attr_reg          <= #TP  'd0 ;    // TLP Header Attibutes
  client0_tlp_byte_len_reg      <= #TP  'd0 ;    // TLP Header Byte Length, 13'h0 for 0 byte, 13'h1000 for 4K bytes
  client0_tlp_tid_reg           <= #TP  'd0 ;    // TLP Header TAG ID
  client0_tlp_addr_reg          <= #TP  'd0 ;    // TLP Header address
  client0_tlp_data_reg          <= #TP  'd0 ;    // TLP Data Payload
    end
    else if (!data_align_out_halt)
    begin
  client0_addr_align_en_reg     <= #TP  client0_addr_align_en ;      
  client0_tlp_byte_en_reg       <= #TP  client0_tlp_byte_en ;     
  client0_cpl_req_id_reg        <= #TP  client0_cpl_req_id ;           // Completion's Requester's ID
  client0_cpl_status_reg        <= #TP  client0_cpl_status ;           // Completion status
  client0_cpl_bcm_reg           <= #TP  client0_cpl_bcm ;              // BCM bit (for Bridge only), tie LOW for EP
  client0_cpl_byte_cnt_reg      <= #TP  client0_cpl_byte_cnt ;         // Completion byte count
  client0_req_id_reg            <= #TP  client0_req_id ;               // Curnt PCIE port's id
  client0_tlp_dv_reg            <= #TP  client0_tlp_dv ;               // TLP data valid
  client0_tlp_eot_reg           <= #TP  client0_tlp_eot ;              // end of TLP
  client0_tlp_bad_eot_reg       <= #TP  client0_tlp_bad_eot ;          // BAD EOT
  client0_tlp_hv_reg            <= #TP  client0_tlp_hv ;               // Header valid
  if (client0_tlp_hv) begin
  client0_tlp_fmt_reg           <= #TP  client0_tlp_fmt ;              // TLP Header Format
  client0_tlp_type_reg          <= #TP  client0_tlp_type ;             // TLP Header Type field
  client0_tlp_tc_reg            <= #TP  client0_tlp_tc ;               // TLP Header TC
  client0_tlp_td_reg            <= #TP  client0_tlp_td ;               // TLP Header digest
  client0_tlp_ep_reg            <= #TP  client0_tlp_ep ;               // TLP Header EP
  client0_tlp_attr_reg          <= #TP  client0_tlp_attr ;             // TLP Header Attibutes
  client0_tlp_byte_len_reg      <= #TP  client0_tlp_byte_len ;         // TLP Header Byte Length, 13'h0 for 0 byte, 13'h1000 for 4K bytes
  client0_tlp_tid_reg           <= #TP  client0_tlp_tid ;              // TLP Header TAG ID
  client0_tlp_addr_reg          <= #TP  client0_tlp_addr ;             // TLP Header address
  end
  client0_tlp_data_reg          <= #TP  client0_tlp_data ;             // TLP Data Payload
    end
end

//Client 1 Interface Registered
reg                      client1_addr_align_en_reg;        // 1-XADM will does address alignment, prempting _reg; 0-use client1_tlp_byte_en
reg [7:0]                client1_tlp_byte_en_reg;          // first/last byte enables per pcie spec, used only if client1_addr_align_en=0_reg;
reg [15:0]               client1_cpl_req_id_reg;           // Completion's Requester's ID

reg [2:0]                client1_cpl_status_reg;           // Completion status
reg                      client1_cpl_bcm_reg;              // BCM bit (for Bridge only), tie LOW for EP
reg [11:0]               client1_cpl_byte_cnt_reg;         // Completion byte count
reg [15:0]               client1_req_id_reg;               // Curnt PCIE port's id
reg                      client1_tlp_dv_reg;               // TLP data valid
reg                      client1_tlp_eot_reg;              // end of TLP
reg                      client1_tlp_bad_eot_reg;          // BAD EOT
reg                      client1_tlp_hv_reg;               // Header valid
reg [1:0]                client1_tlp_fmt_reg;              // TLP Header Format
reg [4:0]                client1_tlp_type_reg;             // TLP Header Type field
reg [2:0]                client1_tlp_tc_reg;               // TLP Header TC
reg                      client1_tlp_td_reg;               // TLP Header digest
reg                      client1_tlp_ep_reg;               // TLP Header EP
reg [ATTR_WD-1:0]        client1_tlp_attr_reg;             // TLP Header Attibutes
reg [12:0]               client1_tlp_byte_len_reg;         // TLP Header Byte Length, 13'h0 for 0 byte, 13'h1000 for 4K bytes
reg [TAG_SIZE-1:0]       client1_tlp_tid_reg;              // TLP Header TAG ID
reg [63:0]               client1_tlp_addr_reg;             // TLP Header address
reg [DW -1:0]            client1_tlp_data_reg;             // TLP Data Payload


reg                      client1_tlp_eot_int_reg;
reg                      client1_tlp_bad_eot_int_reg;
reg                      client1_tlp_hv_int_reg; 

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
  client1_tlp_eot_int_reg           <= #TP  'd0 ;    // end of TLP
  client1_tlp_bad_eot_int_reg       <= #TP  'd0 ;    // BAD EOT
  client1_tlp_hv_int_reg            <= #TP  'd0 ;    // Header valid
  end
  else begin//no enable signal to sampling the HV / EOT and BADEOT.
       //It's usefull to clear request when the clients decides to release the request and there is an internal halt
  client1_tlp_eot_int_reg           <= #TP  client1_tlp_eot;      // end of TLP
  client1_tlp_bad_eot_int_reg       <= #TP  client1_tlp_bad_eot;  // BAD EOT
  client1_tlp_hv_int_reg            <= #TP  client1_tlp_hv;       // Header valid
  end
end


always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
  client1_addr_align_en_reg     <= #TP  'd0 ;    // 1-XADM will does address alignment, prempting _reg <= #TP  'd0 ; 0-use client1_tlp_byte_en
  client1_tlp_byte_en_reg       <= #TP  'd0 ;    // first/last byte enables per pcie spec, used only if client1_addr_align_en=0_reg <= #TP  'd0 ;
  client1_cpl_req_id_reg        <= #TP  'd0 ;    // Completion's Requester's ID
  client1_cpl_status_reg        <= #TP  'd0 ;    // Completion status
  client1_cpl_bcm_reg           <= #TP  'd0 ;    // BCM bit (for Bridge only), tie LOW for EP
  client1_cpl_byte_cnt_reg      <= #TP  'd0 ;    // Completion byte count
  client1_req_id_reg            <= #TP  'd0 ;    // Curnt PCIE port's id
  client1_tlp_dv_reg            <= #TP  'd0 ;    // TLP data valid
  client1_tlp_eot_reg           <= #TP  'd0 ;    // end of TLP
  client1_tlp_bad_eot_reg       <= #TP  'd0 ;    // BAD EOT
  client1_tlp_hv_reg            <= #TP  'd0 ;    // Header valid
  client1_tlp_fmt_reg           <= #TP  'd0 ;    // TLP Header Format
  client1_tlp_type_reg          <= #TP  'd0 ;    // TLP Header Type field
  client1_tlp_tc_reg            <= #TP  'd0 ;    // TLP Header TC
  client1_tlp_td_reg            <= #TP  'd0 ;    // TLP Header digest
  client1_tlp_ep_reg            <= #TP  'd0 ;    // TLP Header EP
  client1_tlp_attr_reg          <= #TP  'd0 ;    // TLP Header Attibutes
  client1_tlp_byte_len_reg      <= #TP  'd0 ;    // TLP Header Byte Length, 13'h0 for 0 byte, 13'h1000 for 4K bytes
  client1_tlp_tid_reg           <= #TP  'd0 ;    // TLP Header TAG ID
  client1_tlp_addr_reg          <= #TP  'd0 ;    // TLP Header address
  client1_tlp_data_reg          <= #TP  'd0 ;    // TLP Data Payload
    end
    else if (!data_align_out_halt)
    begin
  client1_addr_align_en_reg     <= #TP  client1_addr_align_en ;      
  client1_tlp_byte_en_reg       <= #TP  client1_tlp_byte_en ;     
  client1_cpl_req_id_reg        <= #TP  client1_cpl_req_id ;           // Completion's Requester's ID
  client1_cpl_status_reg        <= #TP  client1_cpl_status ;           // Completion status
  client1_cpl_bcm_reg           <= #TP  client1_cpl_bcm ;              // BCM bit (for Bridge only), tie LOW for EP
  client1_cpl_byte_cnt_reg      <= #TP  client1_cpl_byte_cnt ;         // Completion byte count
  client1_req_id_reg            <= #TP  client1_req_id ;               // Curnt PCIE port's id
  client1_tlp_dv_reg            <= #TP  client1_tlp_dv ;               // TLP data valid
  client1_tlp_eot_reg           <= #TP  client1_tlp_eot ;              // end of TLP
  client1_tlp_bad_eot_reg       <= #TP  client1_tlp_bad_eot ;          // BAD EOT
  client1_tlp_hv_reg            <= #TP  client1_tlp_hv ;               // Header valid
  if (client1_tlp_hv) begin
  client1_tlp_fmt_reg           <= #TP  client1_tlp_fmt ;              // TLP Header Format
  client1_tlp_type_reg          <= #TP  client1_tlp_type ;             // TLP Header Type field
  client1_tlp_tc_reg            <= #TP  client1_tlp_tc ;               // TLP Header TC
  client1_tlp_td_reg            <= #TP  client1_tlp_td ;               // TLP Header digest
  client1_tlp_ep_reg            <= #TP  client1_tlp_ep ;               // TLP Header EP
  client1_tlp_attr_reg          <= #TP  client1_tlp_attr ;             // TLP Header Attibutes
  client1_tlp_byte_len_reg      <= #TP  client1_tlp_byte_len ;         // TLP Header Byte Length, 13'h0 for 0 byte, 13'h1000 for 4K bytes
  client1_tlp_tid_reg           <= #TP  client1_tlp_tid ;              // TLP Header TAG ID
  client1_tlp_addr_reg          <= #TP  client1_tlp_addr ;             // TLP Header address
  end
  client1_tlp_data_reg          <= #TP  client1_tlp_data ;             // TLP Data Payload

    end
end



reg client0_dv_request;
wire client0_tlp_request;
assign client0_tlp_request = client0_tlp_hv_reg & !client0_tlp_bad_eot_reg || client0_dv_request ;
reg client1_dv_request;
wire client1_tlp_request;
assign client1_tlp_request = client1_tlp_hv_reg & !client1_tlp_bad_eot_reg || client1_dv_request ;

wire [NCL-1:0]    active_grant_for_fc;
wire [NCL-1:0]    qualified_arb_req;   // Perforomance

wire      next_cpl_cdts_pass;
wire      next_msg_cdts_pass;
wire      next_client0_cdts_pass;
wire      next_client1_cdts_pass;

wire [NVC-1:0] next_credit_enough;
wire next_credit_enough_all;
wire [NVC-1:0] next_2credit_enough;
wire next_2credit_enough_all;

assign next_credit_enough_all = &next_credit_enough;
assign next_2credit_enough_all = &next_2credit_enough;

assign  client0_hdr[`F_HDR_CPL_REQ_ID    ]  = client0_cpl_req_id_reg;
assign  client0_hdr[`F_HDR_CPL_STATUS    ]  = client0_cpl_status_reg;
assign  client0_hdr[`F_HDR_CPL_BCM       ]  = client0_cpl_bcm_reg;
assign  client0_hdr[`F_HDR_CPL_BYTE_CNT  ]  = client0_cpl_byte_cnt_reg;
assign  client0_hdr[`F_HDR_REQ_ID        ]  = client0_req_id_reg;
assign  client0_hdr[`F_HDR_TLP_TAG       ]  = client0_tlp_tid_reg;
assign  client0_hdr[`F_HDR_TLP_BYTE_LEN  ]  = client0_tlp_byte_len_reg;
assign  client0_tlp_byte_len_p              = client0_hdr[`F_HDR_TLP_BYTE_LEN  ];
assign  client0_hdr[`F_HDR_TLP_ATTR      ]  = client0_tlp_attr_reg;
assign  client0_hdr[`F_HDR_TLP_EP        ]  = client0_tlp_ep_reg;
assign  client0_hdr[`F_HDR_TLP_TD        ]  = client0_tlp_td_reg;
assign  client0_hdr[`F_HDR_TLP_TC        ]  = client0_tlp_tc_reg;
assign  client0_tlp_tc_p                    = client0_hdr[`F_HDR_TLP_TC        ];
assign  client0_hdr[`F_HDR_TLP_TYPE      ]  = client0_tlp_type_reg;
assign  client0_tlp_type_p                  = client0_hdr[`F_HDR_TLP_TYPE      ];
assign  client0_hdr[`F_HDR_TLP_FMT       ]  = client0_tlp_fmt_reg;
assign  client0_tlp_fmt_p                   = client0_hdr[`F_HDR_TLP_FMT       ];
assign  client0_hdr[`F_HDR_TLP_ADDR      ]  = client0_tlp_addr_reg[63:0];
assign  client0_tlp_addr_p                  = client0_hdr[`F_HDR_TLP_ADDR      ];
assign  client0_hdr[`F_HDR_BYTE_EN       ]  = client0_tlp_byte_en_reg;  // overloaded with MSG code
assign  client0_hdr[`F_HDR_ADDR_ALIGN_EN ]  = client0_addr_align_en_reg;

assign  client0_hdr_err_detect = 1'b0;
assign  client0_hdr_err_multpl = 1'b0;

assign  client1_hdr[`F_HDR_CPL_REQ_ID    ]  = client1_cpl_req_id_reg;
assign  client1_hdr[`F_HDR_CPL_STATUS    ]  = client1_cpl_status_reg;
assign  client1_hdr[`F_HDR_CPL_BCM       ]  = client1_cpl_bcm_reg;
assign  client1_hdr[`F_HDR_CPL_BYTE_CNT  ]  = client1_cpl_byte_cnt_reg;
assign  client1_hdr[`F_HDR_REQ_ID        ]  = client1_req_id_reg;
assign  client1_hdr[`F_HDR_TLP_TAG       ]  = client1_tlp_tid_reg;
assign  client1_hdr[`F_HDR_TLP_BYTE_LEN  ]  = client1_tlp_byte_len_reg;
assign  client1_tlp_byte_len_p              = client1_hdr [`F_HDR_TLP_BYTE_LEN];
assign  client1_hdr[`F_HDR_TLP_ATTR      ]  = client1_tlp_attr_reg;
assign  client1_hdr[`F_HDR_TLP_EP        ]  = client1_tlp_ep_reg;
assign  client1_hdr[`F_HDR_TLP_TD        ]  = client1_tlp_td_reg;
assign  client1_hdr[`F_HDR_TLP_TC        ]  = client1_tlp_tc_reg;
assign  client1_tlp_tc_p                    = client1_hdr [`F_HDR_TLP_TC];
assign  client1_hdr[`F_HDR_TLP_TYPE      ]  = client1_tlp_type_reg;
assign  client1_tlp_type_p                  = client1_hdr [`F_HDR_TLP_TYPE];
assign  client1_hdr[`F_HDR_TLP_FMT       ]  = client1_tlp_fmt_reg;
assign  client1_tlp_fmt_p                   = client1_hdr [`F_HDR_TLP_FMT];
assign  client1_hdr[`F_HDR_TLP_ADDR      ]  = client1_tlp_addr_reg[63:0];
assign  client1_tlp_addr_p                  = client1_hdr [`F_HDR_TLP_ADDR];
assign  client1_hdr[`F_HDR_BYTE_EN       ]  = client1_tlp_byte_en_reg;  // overloaded with MSG code
assign  client1_hdr[`F_HDR_ADDR_ALIGN_EN ]  = client1_addr_align_en_reg;

assign  client1_hdr_err_detect = 1'b0;
assign  client1_hdr_err_multpl = 1'b0;


assign int_client1_tlp_type = client1_tlp_request ? client1_tlp_type_p : 0;
assign int_client1_tlp_fmt  = client1_tlp_request ? client1_tlp_fmt_p : 0;
assign int_client1_tlp_tc   = client1_tlp_request ?  client1_tlp_tc_p : 0;
assign int_client0_tlp_type = client0_tlp_request ? client0_tlp_type_p : 0;
assign int_client0_tlp_fmt  = client0_tlp_request ? client0_tlp_fmt_p : 0;
assign int_client0_tlp_tc   = client0_tlp_request ? client0_tlp_tc_p : 0;

wire [12:0] int_client0_tlp_byte_len;
wire [12:0] int_client1_tlp_byte_len;


always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        client0_dv_request          <= #TP 0;
    end
    else
    begin
        //Client0 Request
        if (client0_tlp_hv_int_reg && client0_tlp_bad_eot_int_reg && client0_tlp_eot_int_reg)
           client0_dv_request          <= #TP 1'b0;
        else if (data_align_out_halt)
           client0_dv_request          <= #TP client0_dv_request;
        else if (client0_tlp_eot_reg) 
           client0_dv_request          <= #TP 1'b0;
        else if (client0_tlp_hv_reg) 
           client0_dv_request          <= #TP 1'b1;
        else
           client0_dv_request          <= #TP client0_dv_request;
    end
end

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        client1_dv_request          <= #TP 0;
    end
    else
    begin
         //Client1 Request
        if (client1_tlp_hv_int_reg && client1_tlp_bad_eot_int_reg && client1_tlp_eot_int_reg)
           client1_dv_request          <= #TP 1'b0;
        else if (data_align_out_halt)
           client1_dv_request          <= #TP client1_dv_request;
        else if (client1_tlp_eot_reg)
           client1_dv_request          <= #TP 1'b0;
        else if (client1_tlp_hv_reg) 
           client1_dv_request          <= #TP 1'b1;
        else
           client1_dv_request          <= #TP client1_dv_request;
    end
end





assign  arb_reqs                 = {     client1_tlp_request, client0_tlp_request, msg_gen_hv, lbc_cpl_hv};

    assign  int_client0_tlp_byte_len = client0_tlp_request ? client0_tlp_byte_len_p : 0;
    assign  int_client1_tlp_byte_len = client1_tlp_request ? client1_tlp_byte_len_p : 0;

    assign  clients_addr_offset      = {client1_tlp_addr_p[1:0], client0_tlp_addr_p[1:0], 2'b0, 2'b0};
    assign  clients_byte_len         = {int_client1_tlp_byte_len,  int_client0_tlp_byte_len, 13'h004, 13'h004};
    assign  clients_type             = {int_client1_tlp_fmt, int_client1_tlp_type,
                                    int_client0_tlp_fmt, int_client0_tlp_type,
                                    msg_gen_hdr[`F_HDR_TLP_FMT], msg_gen_hdr[`F_HDR_TLP_TYPE],
                                    lbc_cpl_hdr[`F_HDR_TLP_FMT], lbc_cpl_hdr[`F_HDR_TLP_TYPE]};
       assign  clients_tc               = {int_client1_tlp_tc, int_client0_tlp_tc,
                                    msg_gen_hdr[`F_HDR_TLP_TC], lbc_cpl_hdr[`F_HDR_TLP_TC]};


assign  mux_out_hdr_addr         = mux_out_hdr[`F_HDR_TLP_ADDR];
assign  mux_out_addr_byte_offset = mux_out_hdr_addr[1:0];
assign  mux_out_byte_len         = mux_out_hdr[`F_HDR_TLP_BYTE_LEN];


// xadm_fc instantiations for virtual channels
xadm_vc_fc

#(INST) u_vc_xadm_fc
   (
    .rstctl_core_flush_req      (rstctl_core_flush_req),
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .cfg_max_payload_size       (cfg_max_payload_size),
    .cfg_tc_vc_map              (cfg_tc_vc_map),
    .cfg_vc_id                  (cfg_vc_struc_vc_id_map),
    .cfg_vc_enable              (cfg_vc_enable),
    .active_grant               (active_grant_for_fc),
    .restore_enable             (xtlh_xadm_restore_enable),
    .restore_capture            (xtlh_xadm_restore_capture),
    .restore_tc                 (xtlh_xadm_restore_tc),
    .restore_type               (xtlh_xadm_restore_type),
    .restore_word_len           (xtlh_xadm_restore_word_len),

    .rdlh_link_down             (rdlh_link_down),
    .rtlh_rfc_upd               (rtlh_rfc_upd),
    .rtlh_rfc_data              (rtlh_rfc_data),
    .rtlh_fc_init_status        (rtlh_fc_init_status),

    .clients_tc                 (clients_tc),
    .clients_type               (clients_type),
    .clients_byte_len           (clients_byte_len),
    .clients_addr_offset        (clients_addr_offset),


    .fc_cds_pass                (fc_cds_pass),
    .next_fc_cds_pass           (next_fc_cds_pass), 
    .next_credit_enough         (next_credit_enough), 
    .next_2credit_enough        (next_2credit_enough), 
    .xadm_no_fc_credit          (xadm_no_fc_credit),

    .xadm_had_enough_credit     (xadm_had_enough_credit),
    .xadm_all_type_infinite     (int_all_type_infinite),
    .xadm_ph_cdts               (xadm_ph_cdts),
    .xadm_pd_cdts               (xadm_pd_cdts),
    .xadm_nph_cdts              (xadm_nph_cdts),
    .xadm_npd_cdts              (xadm_npd_cdts),
    .xadm_cplh_cdts             (xadm_cplh_cdts),
    .xadm_cpld_cdts             (xadm_cpld_cdts)
 

);


reg [NVC*NCL-1:0] int_fc_cds_pass; 
reg [NVC*NCL-1:0] int_next_fc_cds_pass;
always @(*)
begin
   integer i;
  
   int_fc_cds_pass      = fc_cds_pass;
   int_next_fc_cds_pass = next_fc_cds_pass;

   for(i = 0; i < NVC; i = i + 1) begin
      // ### CLIENT1_INDEX = 3 in NCL(Num Clients) ###
      int_fc_cds_pass[CLIENT0_INDEX+(NCL*i)]      = fc_cds_pass[CLIENT0_INDEX+(NCL*i)]      && client0_cdts_pass_cplq_management_vc[i];
      int_fc_cds_pass[CLIENT1_INDEX+(NCL*i)]      = fc_cds_pass[CLIENT1_INDEX+(NCL*i)]      && client1_cdts_pass_cplq_management_vc[i];

      int_next_fc_cds_pass[CLIENT0_INDEX+(NCL*i)] = next_fc_cds_pass[CLIENT0_INDEX+(NCL*i)] && next_credit_enough_all_cplq_management;
      int_next_fc_cds_pass[CLIENT1_INDEX+(NCL*i)] = next_fc_cds_pass[CLIENT1_INDEX+(NCL*i)] && next_credit_enough_all_cplq_management;
   end

end

xadm_arb

u_xadm_arb
   (/*AUTO INST*/
    // Inputs
    .core_rst_n                 (core_rst_n),
    .core_clk                   (core_clk),
    .cfg_tc_vc_map              (cfg_tc_vc_map),
    .cfg_tc_struc_vc_map        (cfg_tc_struc_vc_map),
    .cfg_lpvc_wrr_weight        (cfg_lpvc_wrr_weight),
    .cfg_lpvc_wrr_phase         (cfg_lpvc_wrr_phase),
    .cfg_lpvc                   (cfg_lpvc),
    .arb_enable                 (arb_enable), //Performance
    //

    .arb_reqs                   (arb_reqs),
    .clients_tc                 (clients_tc),
    .clients_type               (clients_type),
    .cdts_pass                  (int_fc_cds_pass), 
    .next_cdts_pass             (int_next_fc_cds_pass), 
    .grant_ack                  (grant_ack),
    .pm_xtlh_block_tlp          (pm_xtlh_block_tlp),
    .cfg_client0_block_new_tlp  (cfg_client0_block_new_tlp),
    .cfg_client1_block_new_tlp  (cfg_client1_block_new_tlp),
    .cfg_client2_block_new_tlp  (cfg_client2_block_new_tlp),
    .pm_block_all_tlp           (pm_block_all_tlp),
    //DE:Deadlock fix
    .lbc_deadlock_det           (lbc_deadlock_det),
    .clear_active_grant         (clear_active_grant),
    // Outputs
     .next_cpl_cdts_pass             (next_cpl_cdts_pass),
     .next_msg_cdts_pass             (next_msg_cdts_pass),
     .next_client0_cdts_pass         (next_client0_cdts_pass),
     .next_client1_cdts_pass         (next_client1_cdts_pass),
    .arb_grant_valid            (arb_grant_valid),
    .active_grant               (active_grant),
    .qualified_arb_req    (qualified_arb_req)    // Performance
);



assign client0_cdts_pass_cplq_management_vc    = {NVC{1'b1}};
assign client1_cdts_pass_cplq_management_vc    = {NVC{1'b1}};
assign client2_cdts_pass_cplq_management_vc    = {NVC{1'b1}};
assign next_credit_enough_all_cplq_management  = 1'b1;
assign next_2credit_enough_all_cplq_management = 1'b1;

xadm_mux

u_xadm_mux
   (/*AUTO INST*/
    // Inputs
    .core_rst_n                 (core_rst_n),
    .core_clk                   (core_clk),
    .pm_block_all_tlp           (pm_block_all_tlp),
    .out_halt                   (data_align_out_halt),
    .arb_grant_valid            (arb_grant_valid),
    .active_grant               (active_grant),
    .qualified_arb_req          (qualified_arb_req), //Perforamnce
    .arb_reqs                   (arb_reqs),          //Perforamnce
    .cpl_hv                     (lbc_cpl_hv),
    .cpl_dv                     (lbc_cpl_dv),
    .cpl_eot                    (lbc_cpl_eot),
    .cpl_badeot                 (1'b0),
    .cpl_data                   (lbc_cpl_data),
    .cpl_hdr                    (lbc_cpl_hdr),
    .msg_hv                     (msg_gen_hv),
    .msg_dv                     (msg_gen_dv),
    .msg_eot                    (msg_gen_eot),
    .msg_badeot                 (1'b0),
    .msg_data                   (msg_gen_data),
    .msg_hdr                    (msg_gen_hdr),
    .client0_hv                 (client0_tlp_hv_reg),
    .client0_dv                 (client0_tlp_dv_reg),
    .client0_eot                (client0_tlp_eot_reg),
    .client0_eot_pre            (client0_tlp_eot),
    .client0_badeot             (client0_tlp_bad_eot_reg),
    .client0_data               (client0_tlp_data_reg),
    .client0_hdr                (client0_hdr),





    .client1_hv                 (client1_tlp_hv_reg),
    .client1_dv                 (client1_tlp_dv_reg),
    .client1_eot                (client1_tlp_eot_reg),
    .client1_eot_pre            (client1_tlp_eot),
    .client1_badeot             (client1_tlp_bad_eot_reg),
    .client1_hdr                (client1_hdr),
    .client1_data               (client1_tlp_data_reg),



     .next_credit_enough_all         (next_credit_enough_all  && next_credit_enough_all_cplq_management),
     .next_2credit_enough_all        (next_2credit_enough_all && next_2credit_enough_all_cplq_management),
     .next_cpl_cdts_pass             (next_cpl_cdts_pass),
     .next_msg_cdts_pass             (next_msg_cdts_pass),
     .next_client0_cdts_pass         (next_client0_cdts_pass),
     .next_client1_cdts_pass         (next_client1_cdts_pass), 
     .device_type                    (device_type),
    
    // Outputs
    .client0_halt               (xadm_client0_halt),
    .client1_halt               (xadm_client1_halt),
    .msg_halt                   (xadm_msg_halt),
    .cpl_halt                   (xadm_cpl_halt),
    .arb_enable                 (arb_enable), //Performance
    .active_grant_for_fc        (active_grant_for_fc),
    .out_hv                     (mux_out_hv),
    .out_hdr                    (out_hdr_tmp),
    .out_dv                     (mux_out_dv),
    .out_data                   (mux_out_data),
    .out_eot                    (mux_out_eot),
    .out_bad_eot                (mux_out_bad_eot),
    .out_hdr_rsvd               (mux_hdr_rsvd),
    .out_hdr_ats                (mux_hdr_ats),
    .out_hdr_nw                 (mux_hdr_nw),
    .out_hdr_th                 (mux_hdr_th),
    .out_hdr_ph                 (mux_hdr_ph),
    .out_hdr_st                 (mux_hdr_st),



    .grant_ack                  (grant_ack),
    .clear_active_grant         (clear_active_grant),
    .arb_in_idle                (xadm_mux_idle)
);

// End of Old XADM (NO XADM Client Expansion)// ---------------------------------------------------------------------------------------------------------------------------------------------------------------

xadm_hdr_form

#(INST) u0_xadm_hdr_form
    (
     // ---- Inputs ----
     .core_clk                   (core_clk),
     .core_rst_n                 (core_rst_n),
     .cfg_ecrc_gen_en            (cfg_ecrc_gen_en),
     .device_type                (device_type),
     .intf_tlp_hdr_int           (mux_out_hdr),
     .intf_hdr_rsvd              (mux_hdr_rsvd),
     .intf_hdr_ats               (mux_hdr_ats),
     .intf_hdr_nw                (mux_hdr_nw),
     .intf_hdr_th                (mux_hdr_th),
     .intf_hdr_ph                (mux_hdr_ph),
     .intf_hdr_st                (mux_hdr_st),

     .intf_tlp_hv                (formed_tlp_hv),
     .intf_tlp_eot               (formed_tlp_eot),
     .intf_in_halt               (formation_out_halt),
     .cfg_2ndbus_num             (cfg_2ndbus_num),

     // ---- Outputs ----
     .tlp_formed_hdr             (formed_tlp_hdr),
     .tlp_formed_hdr_parerr      (formed_addr_parerr),
     .tlp_data_align_en          (tlp_data_align_en),
     .tlp_formed_last_dwen       (formed_last_dwen),
     .tlp_is_mem                 (tlp_is_mem),
     .addr64                     (addr64),


     .prfx_formed_parerr   (formed_prfx_parerr),
     .tlp_formed_add_ecrc        (formed_tlp_add_ecrc)


);



    assign formed_tlp_data            = mux_out_data;
reg [NW-1:0]        latched_last_dwen;
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        latched_last_dwen            <= #TP 0;
    end else if (mux_out_hv)  begin
        latched_last_dwen            <= #TP formed_last_dwen;
    end

    assign formed_tlp_dwen     = (mux_out_hv & mux_out_eot)  ? formed_last_dwen
                                 : (!mux_out_hv & mux_out_eot) ? latched_last_dwen
                                 : {NW{1'b1}};
    assign formed_tlp_dv       = mux_out_dv;
    assign formed_tlp_hv       = mux_out_hv;
    assign formed_tlp_eot      = mux_out_eot;
    assign formed_tlp_badeot   = mux_out_bad_eot;
    assign data_align_out_halt = formation_out_halt;
    assign formed_data_parerr     = 1'b0;



// Register inputs to xadm_formation for timing if necessary
parameter CX_XADM_FORMATION_REGIN     = `CX_XADM_FORMATION_REGIN;
// Add Prefix to staging
parameter FORMATION_REGIN_WIDTH    = DW + 128 + 1 + 1 + 1 + 1 + NW + 1 + 1 + 1

;
parameter FORMATION_REGIN_CAN_STALL = CX_XADM_FORMATION_REGIN > 0;
wire [DW-1:0]        formed_tlp_data_d;
wire [RAS_HDR_WD-1:0]formed_tlp_hdr_d;
wire                 formed_tlp_dv_d;
wire                 formed_tlp_hv_d;
wire                 formed_tlp_eot_d;
wire                 formed_tlp_badeot_d;
wire [NW-1:0]        formed_tlp_dwen_d;
wire                 formed_tlp_add_ecrc_d;
wire                 formed_addr_parerr_d, formed_data_parerr_d;
wire                 formation_in_halt;



assign formation_in_halt = CX_XADM_FORMATION_REGIN ?
    out_formation_out_halt && (formed_tlp_hv_d||formed_tlp_dv_d) :
    out_formation_out_halt;
delay_n_w_stalling

#(CX_XADM_FORMATION_REGIN, FORMATION_REGIN_WIDTH, FORMATION_REGIN_CAN_STALL) u_formation_regin_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .stall      (formation_in_halt),
    .clear      (1'b0),

// OR formed_prfx_parerr with formed_addr_parerr, since they happen at the same phase of header cycle
    .din        ({formed_tlp_hv,formed_tlp_dv,
     formed_tlp_eot,formed_tlp_badeot,formed_tlp_dwen,formed_addr_parerr | formed_prfx_parerr, formed_data_parerr,formed_tlp_add_ecrc,formed_tlp_hdr,formed_tlp_data


       }),

    .stallout   (formation_out_halt),
    .dout       ({formed_tlp_hv_d,formed_tlp_dv_d,
    formed_tlp_eot_d,formed_tlp_badeot_d,formed_tlp_dwen_d,formed_addr_parerr_d,formed_data_parerr_d,formed_tlp_add_ecrc_d,formed_tlp_hdr_d,formed_tlp_data_d

    })
);

xadm_out_formation

#(INST) u1_xadm_out_formation
   (
     // ---- Inputs ----
     .core_clk                   (core_clk),
     .core_rst_n                 (core_rst_n),
     .xtlh_xadm_halt             (xtlh_xadm_halt),
     .formed_tlp_data            (formed_tlp_data_d),
     .formed_data_parerr         (formed_data_parerr_d),
     .formed_tlp_hdr             (formed_tlp_hdr_d),
     .formed_addr_parerr         (formed_addr_parerr_d),
     .formed_tlp_dv              (formed_tlp_dv_d),
     .formed_tlp_hv              (formed_tlp_hv_d),
     .formed_tlp_eot             (formed_tlp_eot_d),
     .formed_tlp_badeot          (formed_tlp_badeot_d),
     .formed_tlp_dwen            (formed_tlp_dwen_d),
     .formed_tlp_add_ecrc        (formed_tlp_add_ecrc_d),


     // ---- Outputs ----

     .xadm_xtlh_soh              (xadm_xtlh_soh),
     .xadm_xtlh_data             (xadm_xtlh_data),
     .xadm_xtlh_hdr              (xadm_xtlh_hdr),
     .xadm_xtlh_dv               (xadm_xtlh_dv),
     .xadm_xtlh_hv               (xadm_xtlh_hv),
     .xadm_xtlh_sot              (xadm_xtlh_sot),
     .xadm_xtlh_eot              (xadm_xtlh_eot),
     .xadm_xtlh_bad_eot          (xadm_xtlh_bad_eot),
     .xadm_xtlh_add_ecrc         (xadm_xtlh_add_ecrc),
     .xadm_xtlh_dwen             (xadm_xtlh_dwen),



     .out_formation_out_halt     (out_formation_out_halt),

     .xadm_xtlh_parerr           (xadm_xtlh_parerr)
     ,
     .xadm_halted                (xadm_halted)
);



    assign out_hdr      = out_hdr_tmp;
    assign mux_out_hdr  = out_hdr;
    assign hdrout_err_detect = 0;
    assign hdrout_err_multpl = 0;

assign trgt_lut_trgt1_radm_pkt_halt = {(NVC*3){1'b0}};
assign trgt_lut_dma_pkt_halt = 1'b0;


assign xadm_tlp_fltr_bad_eot = client1_tlp_bad_eot;

xadm_tracker
 #(
  .CX_CCIX_HDR_WD       (CX_CCIX_HDR_WD),
  .NW                   (NW)
) u_xadm_tracker(
// Inputs
  .core_clk             (core_clk),
  .core_rst_n           (core_rst_n),
  .msg_gen_hv           (msg_gen_hv),
  .xadm_msg_halt        (xadm_msg_halt),
  .lbc_cpl_hv           (lbc_cpl_hv),
  .xadm_cpl_halt        (xadm_cpl_halt),
  .client0_tlp_hv       (client0_tlp_hv),
  .client0_tlp_bad_eot  (client0_tlp_bad_eot),
  .xadm_client0_halt    (xadm_client0_halt),
  .client1_tlp_hv       (client1_tlp_hv),
  .client1_tlp_bad_eot  (client1_tlp_bad_eot),
  .xadm_client1_halt    (xadm_client1_halt),
  .xadm_halted          (xtlh_xadm_halt),
  .xadm_xtlh_eot        (xadm_xtlh_eot),
  .xadm_mux_idle        (xadm_mux_idle),
  .pm_block_all_tlp     (pm_block_all_tlp),
  // Outputs
  .xadm_tlp_pending     (xadm_tlp_pending),
  .xadm_block_tlp_ack_r (xadm_block_tlp_ack)
);


function automatic[2:0] vc_from_tc;
    input   [23:0]  cfg_tc_struc_vc_map;  // TC to VC Structure mapping
    input   [2:0]   tc;                   // Traffic class
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

// This function converts the 7 bits of type and format from the TLP header to flow control types (P=0, NP=1, CPL=2)
// NOTE: There is no error checking
function automatic   [1:0]   type_to_fctype;
    input   [1:0]   fmt;
    input   [4:0]   pkt_type;

    type_to_fctype =  
                        (pkt_type[4])    ? `P_TYPE     :   // Message
                        (&pkt_type[3:2]) ? `NP_TYPE    :   // Atomic
                        (pkt_type[3])    ? `CPL_TYPE   :   // Completion
                        (pkt_type[2])    ? `NP_TYPE    :   // Configuration
                        (pkt_type[1])    ? `NP_TYPE    :   // IO
                        (!fmt[1])        ? `NP_TYPE    :   // Memory Read
                                           `P_TYPE;        // Memory Write
endfunction



endmodule

