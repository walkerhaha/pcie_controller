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
// ---    $DateTime: 2020/09/18 13:59:22 $
// ---    $Revision: #18 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/lbc.sv#18 $
// -------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  This module is used in endpoint applications
//  Its main functions are :
//     (1) Process all configuration requests
//     (2) Process memory and IO requests to external application blocks
//     (3) Since RADM has the queue for all requests, This block takes one
//     tlp at a time to process and its latency is dependent upon
//     application or CDM's local bus reply time. The local bus interface
//     is not designed to have the fastest performance based on its nature.
//     (4) This module supports two memory BAR design and one ROM range.
//     For memory rd/wr requests within in the BAR range, this block will
//     output an external local bus interface called lbc_ext*. It can
//     address any internal registers mapped into the BAR range.
//     (5) This module also supports an outband access to internal
//     registers like CDM or others.
//     (6) An interface signal called lbc_cdm_dbi to indicate that current
//     local bus cycle is initiated from outband interface such as dbi
//     (7) An interface signal called lbc_ext_rom_access to indicate that
//     current external local bus access is targetted to ROM base.
//     (8) Total supported memory map range is 4 GB for either BAR0 or
//     BAR1. 2 BARs are supported
//     (9) Both 32bit and 64 bit memory access are supported for 2 BARs.
//     (10) IO access was indicated to external local bus interface through
//     lbc_ext_io_access
//     (11) This block also handles the posted interface from RADM. It
//     sends out to a slave interface when a posted and some types of
//     nonposted requests have targetted to external completer. The
//     requests asserted into the slave interface is expected to be
//     completed by external completer. This module will not be responsible
//     to these requests.
//     (14) lock read will be returned as non supported read request
//     (15) Configuration Intercept Feature
//        - Interrupt to Application when config request is received
//        - provide halt interface to pend proceed config request
//        - provide override interface to modify config write data and read data for config read request
//
// -----------------------------------------------------------------------------

//    Notes:
//         When the application only wants to support one bar, then it should go
//         through this code beneath to delete anything todo with Bar0 so that you
//         can save gates on large comparator etc.
//         The same applies to IO and expansion ROM support. If the design does not support
//         these two, then deletion of the related code is recommendated.

// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
 
 module lbc
   (
    // -- inputs --
    core_clk,
    core_rst_n,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    device_type,
    cfg_bar0_mask,
    cfg_bar1_mask,
    cfg_bar2_mask,
    cfg_bar3_mask,
    cfg_bar4_mask,
    cfg_bar5_mask,

    radm_data,
    radm_hdr,
    radm_dv,
    radm_hv,
    radm_eot,
    radm_abort,
    radm_trgt0_pending,


    // local bus interface with external registers,
    ext_lbc_ack,
    ext_lbc_din,

    // from cdm,
    cdm_lbc_din,
    cdm_lbc_ack,

    // from  XADM,
    xadm_cpl_halt,

    dbi_addr,
    dbi_din,
    dbi_cs,
    dbi_cs2,
    dbi_wr,



    cfg_config_limit,

    lbc_dbi_ack,
    lbc_dbi_dout,
    // to XADM as completion request of device local bus read or write,
    lbc_cpl_hv,
    lbc_cpl_dv,
    lbc_cpl_data,
    lbc_cpl_hdr,
    lbc_cpl_eot,

    // local bus interface with cdm to read registers locally,
    lbc_cdm_addr,
    lbc_cdm_data,
    lbc_cdm_cs,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    lbc_cdm_dbi2,

    lbc_xmt_cpl_ca,

    // local bus interface with external registers,
    lbc_ext_addr,
    lbc_ext_dout,
    lbc_ext_cs,
    lbc_ext_wr,
    lbc_ext_rom_access,
    lbc_ext_bar_num,
    lbc_ext_io_access,


    pm_l1_aspm_entr,
    rtfcgen_ph_diff,
    lbc_deadlock_det,
    // radm block interface control signal to allow back pressure applied,
    // to radm queues.,
    //,
    trgt0_radm_halt,
    lbc_active


    );
parameter   INST    = 0;            // The uniquifying parameter for each port logic instance.
parameter   NW      = `CX_NW;       // Number of 32-bit dwords handled by the datapath each clock.
parameter   NF      = `CX_NFUNC;    // Number of functions
parameter   NVC     = `CX_NVC;      // Max number of Virtual Channels
parameter   DW      = (32*NW);      // Width of datapath in bits.
parameter   TP      = `TP;          // Clock to Q delay (simulator insurance)
parameter BUSNUM_WD = `CX_BUSNUM_WD;               // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD = `CX_DEVNUM_WD;               // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.



// ----------------------------------------------------------------------------
// --- Parameters
// ----------------------------------------------------------------------------
parameter   LBC_DW               = 32;
parameter   LBC_NW               = `CX_LBC_NW;
parameter   ELBI_WD              = `CX_LBC_NW*32;
parameter   LBC_INT_WD           = `CX_LBC_INT_WD;    // LBC - XADM data bus width can be 32, 64 or 128
parameter   LBC_EXT_AW           = `CX_LBC_EXT_AW;
parameter   LBC_IDLE             = 3'b000;
parameter   LBC_NP_ASSERT        = 3'b010;
parameter   LBC_IN_CPL_REQ       = 3'b011;
parameter   LBC_EXT_DBI_REQ      = 3'b100;
parameter   LBC_RETURN_ERR       = 3'b101;
parameter   RADM_P_HWD           = `RADM_P_HWD;       // Header width
parameter   DATA_PAR_WD          = `TRGT_DATA_PROT_WD;
parameter   ST_HDR               = `ST_HDR;
parameter   HDR_PROT_WD          = 0  
                                   ;
parameter   DEVICE_TYPE          = `CX_DEVICE_TYPE;
parameter   NFUNC_WD             = `CX_NFUNC_WD;
localparam ATTR_WD               = `FLT_Q_ATTR_WIDTH;
localparam PCI_CONFIG_MAX        = 10'h03f;

localparam TAG_SIZE              = `CX_TAG_SIZE;
// -------------------------------- Inputs ------------------------------------
input                        core_clk;                   // Core clock
input                        core_rst_n;                 // Core reset
input    [BUSNUM_WD -1:0]    cfg_pbus_num;
input    [DEVNUM_WD -1:0]    cfg_pbus_dev_num;
input    [3:0]    device_type;
input [(64*NF)-1:0]          cfg_bar0_mask;              // BAR0 mask register
input [(32*NF)-1:0]          cfg_bar1_mask;              // BAR1 mask register
input [(64*NF)-1:0]          cfg_bar2_mask;              // BAR2 mask register
input [(32*NF)-1:0]          cfg_bar3_mask;              // BAR3 mask register
input [(64*NF)-1:0]          cfg_bar4_mask;              // BAR4 mask register
input [(32*NF)-1:0]          cfg_bar5_mask;              // BAR5 mask register


input [DW-1:0]               radm_data;                  // Received request TLP data from RADM
input [RADM_P_HWD-1:0]       radm_hdr;                   // Received request TLP data from RADM
input                        radm_dv;                    // Received TLP data valid
input                        radm_hv;                    // Received TLP data valid
input                        radm_eot;                   // Received TLP EOT
input                        radm_abort;                 // Received TLP EOT with abort
input                        radm_trgt0_pending;         // TLP enroute from RADM prevent DBI access

input [NF-1:0]               ext_lbc_ack;                // ACK from external register access
input [(ELBI_WD*NF) -1:0]    ext_lbc_din;                // Data Input from external register access
input [(LBC_DW * NF)-1:0]    cdm_lbc_din;                // Data Input from CDM register access
input [NF-1:0]               cdm_lbc_ack;                // ACK from CDM register access
input                        xadm_cpl_halt;              // XADM halts CPL from LBC
// internal configuration register values of this port for HBC

input [LBC_DW -1:0]          dbi_addr;                   // External DBI interface address
input [LBC_DW -1:0]          dbi_din;                    // external DBI interface Data input
input                        dbi_cs;                 // external DBI interface chip select
input                        dbi_cs2;                    // external DBI interface chip select
input [3:0]                  dbi_wr;                     // external DBI write enable

input                        pm_l1_aspm_entr;
input [7:0]                  rtfcgen_ph_diff;



input [9:0]                  cfg_config_limit;

// external outband Local bus access interface
output [LBC_DW -1:0]         lbc_dbi_dout;               // Data out to external DBI
output                       lbc_dbi_ack;                // ACk to external DBI

output                       lbc_cpl_hv;                 // LBC generated CPL request
output                       lbc_cpl_dv;
output [DW+DATA_PAR_WD-1:0]  lbc_cpl_data;               // LBC generated CPL data
output [ST_HDR+HDR_PROT_WD-1:0]lbc_cpl_hdr;

output                       lbc_cpl_eot;                // LBC generated CPL EOT

output [LBC_DW -1:0]         lbc_cdm_addr;               // LBC address to CDM register access
output [LBC_DW -1:0]         lbc_cdm_data;               // LBC data to CDM register access
output [NF-1:0]              lbc_cdm_cs;                 // LBC chip select to CDM register access
output [3:0]                 lbc_cdm_wr;                 // LBC write enable to CDM register access
output                       lbc_cdm_dbi;                // LBC indicates to CDM that register is accessed via DBI
output                       lbc_cdm_dbi2;               // LBC indicates to CDM that register is accessed via DBI
output [NF-1:0]              lbc_xmt_cpl_ca;             // LBC indicates to CDM that it send CPL w/ CA

output [LBC_EXT_AW -1:0]     lbc_ext_addr;               // LBC address to external register access
output [ELBI_WD-1:0]         lbc_ext_dout;               // LBC data output to external register access
output [NF-1:0]              lbc_ext_cs;                 // LBC cs to external register access
output [(LBC_NW*4)-1:0]      lbc_ext_wr;                 // LBC write enable to external register access
output                       lbc_ext_rom_access;         // LBC inidcates that this access is for rom expansion
output                       lbc_ext_io_access;          // LBC inidcates that this access is for IO
output [2:0]                 lbc_ext_bar_num;            // LBC inidcates which bar this is

output                       lbc_deadlock_det;
output [3*NVC-1:0]           trgt0_radm_halt;            // LBC halts TLP from RADM
output                       lbc_active;                 // LBC may need to send CPL hold L1 timer



//----------- output register -------------------------
wire  [3*NVC-1:0]            int_trgt0_radm_halt;            // LBC halts TLP from RADM
wire  [DW-1:0]               int_radm_data;                  // Received request TLP data from RADM
wire  [ELBI_WD-1:0]          radm_elbi_data;                 // Received request TLP data from RADM for ELBI
wire  [RADM_P_HWD-1:0]       int_radm_hdr;                   // Received request TLP data from RADM
wire                         int_radm_dv;                    // Received TLP data valid
wire                         int_radm_hv;                    // Received TLP data valid
wire                         int_radm_eot;                   // Received TLP EOT
wire                         int_radm_abort;                 // Received TLP EOT with abort
wire                         int_radm_trgt0_pending;

reg                          lbc_cpl_dv;
reg                          lbc_cpl_hv;
wire [DW+DATA_PAR_WD-1:0]    lbc_cpl_data;
wire [ST_HDR+HDR_PROT_WD-1:0]lbc_cpl_hdr;
wire [ST_HDR-1:0]            lbc_cpl_hdr_nxt;                         
reg                          lbc_cpl_eot;

wire                          int_dbi_cs;
wire                          int_dbi_cs2;

wire [NF-1:0]                 lbc_cdm_cs;
reg                          next_lbc_cdm_cs;
wire                          lbc_cdm_dbi;
wire                          lbc_cdm_dbi2;
reg [NF-1:0]                 lbc_xmt_cpl_ca;
reg                          next_lbc_cdm_dbi;


//wire                          lbc_deadlock_det;

reg [NF-1:0]                 lbc_ext_cs;
reg [LBC_EXT_AW -1:0]        lbc_ext_addr;               // LBC address to external register access
reg [(LBC_NW*4)-1:0]         lbc_ext_wr;                 // LBC write enable to external register access
reg                          next_lbc_ext_cs;
reg                          int_lbc_dbi_ack ;
reg                          lbc_arb_halt_radm;          // Signal to halt radm interface and allow DBI access to CDM
wire [LBC_DW -1:0]            lbc_cdm_addr;               // LBC address to external register access
wire [3:0]                    lbc_cdm_wr;                 // LBC write enable to external register access
wire                         radm_halt;

reg                          lbc_ext_rom_access;
reg                          lbc_ext_io_access;   // LBC inidcates that this access is for IO
reg  [2:0]                   lbc_ext_bar_num;     // LBC inidcates which bar this is
wire [LBC_DW -1:0]           lbc_dbi_dout;        // Data out to external DBI

//--------------------------- Internal Signals ------------------

reg [2:0]                    lbc_proc_state;
reg [2:0]                    next_lbc_proc_state;

reg [LBC_INT_WD-1:0]         latchd_lbc_din;
reg [LBC_INT_WD-1:0]         lbc_cpl_data_int;
reg [(LBC_INT_WD*NF)-1:0]    int_lbc_din;
reg [ELBI_WD-1:0]            latchd_data;
reg [ELBI_WD-1:0]            dbi_elbi_din;          // DBI write data targeting ELBI
reg [(LBC_NW*4)-1:0]         dbi_elbi_wr;           // DBI write byte enables targeting ELBI

reg [1:0]                    byte_addr;

// TLP decoding


wire [TAG_SIZE-1:0]          rcvd_tag;
wire [15:0]                  rcvd_reqid;
wire                         rcvd_np_rd;
wire [NFUNC_WD-1:0]          rcvd_func_id;
wire                         rcvd_atomic_fas;
wire                         rcvd_atomic_cas;
wire                         rcvd_atomic_req;
wire                         rcvd_memrd_req;
wire                         rcvd_memwr_req;
wire                         rcvd_dmwr_req;
wire                         rcvd_p_req;
wire [6:0]                   lower_addr;
wire                         rcvd_locked_rd;
wire [7:0]                   addr_byte0;
wire [3:0]                   first_be;
wire [3:0]                   last_be;
wire [2:0]                   cpl_status;
wire [LBC_DW -1:0]           int_addr_low;
wire [11:0]                  byte_cnt;
wire                         int_radm_zerobyte;
wire                         rcvd_iord_req;
wire                         rcvd_iowr_req;
wire [1:0]                   rcvd_fmt;
wire [4:0]                   rcvd_type;
wire                         rcvd_td;
wire [2:0]                   rcvd_tc;
wire [ATTR_WD-1:0]           rcvd_attr;
wire [7:0]                   rcvd_bus_nmbr;
wire [4:0]                   rcvd_dvc_nmbr;

wire                         status_sc;

reg  [TAG_SIZE-1:0]          latchd_rcvd_tag;
reg  [15:0]                  latchd_rcvd_reqid;
reg  [NFUNC_WD-1:0]          latchd_rcvd_func_id;
reg                          latchd_rcvd_atomic_req;
reg                          latchd_rcvd_dmwr_req;
reg                          latchd_rcvd_np_rd;
reg                          latchd_rcvd_p_req;
reg  [6:0]                   latchd_lower_addr;
reg                          latchd_rcvd_locked_rd;
reg  [2:0]                   latchd_cpl_status;
reg                          latchd_status_sc;
reg  [11:0]                  latchd_byte_cnt;
reg  [2:0]                   latchd_rcvd_tc;
reg  [ATTR_WD-1:0]           latchd_rcvd_attr;
reg                          latchd_rcvd_td;
reg  [9:0]                   latchd_rcvd_tlp_len;


wire [2:0]                   in_bar_range;
wire                         rom_in_range;
wire                         io_req_in_range;
wire                         rcvd_cfg0rd_req;
wire                         rcvd_cfg0wr_req;
wire [NFUNC_WD-1:0]          dbi_rcvd_func_id;
wire [9:0]                   rcvd_tlp_len;
wire                         select_radm;       // when asserted, radm_data (target 0 data) is selected in ELBI and CDM data muxes.


parameter LBC_CDM_REGOUT = 0
                           ;

parameter LBC_CDM_PIPEWIDTH = LBC_DW 
                           + LBC_DW + NF + 1 + 1 + 4    // lbc_cdm_data + lbc_cdm_cs + lbc_cdm_dbi + lbc_cdm_dbi2 + lbc_cdm_wr
                          ;
reg  [LBC_DW-1:0]         lbc_cdm_addr_int;
wire [LBC_DW-1:0]         lbc_cdm_data_int;
reg  [NF-1:0]             lbc_cdm_cs_int;
reg  [3:0]                lbc_cdm_wr_int;
reg                       lbc_cdm_dbi_int;
reg                       lbc_cdm_dbi2_int;


wire [12:0]  tlp_byte_len;      // TLP data payload length in bytes
wire  [3:0]  sc_last_be;        // Successful Completion last byte enable field


wire   [DW-1:0]              cic_data;               // Received request TLP data from RADM
wire   [RADM_P_HWD-1:0]      cic_hdr;                // Received request TLP data from RADM
wire                         cic_dv;                 // Received TLP data valid
wire                         cic_hv;                 // Received TLP data valid
wire                         cic_eot;                // Received TLP EOT
wire                         cic_abort;              // Received TLP EOT with abort
wire                         cic_pending;            // TLP enroute from RADM prevent DBI access
wire                         cic_active;
 assign cic_data        = radm_data;
 assign cic_hdr         = radm_hdr;
 assign cic_dv          = radm_dv;
 assign cic_hv          = radm_hv;
 assign cic_eot         = radm_eot;
 assign cic_abort       = radm_abort;
 assign cic_pending     = radm_trgt0_pending;
 assign cic_active      = 1'b0;
 assign trgt0_radm_halt = int_trgt0_radm_halt;


delay_n

#(LBC_CDM_REGOUT, LBC_CDM_PIPEWIDTH) u_lbc_cdm_pipe(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({lbc_cdm_addr_int[LBC_DW-1:2],2'b00
                ,lbc_cdm_data_int,lbc_cdm_cs_int,lbc_cdm_wr_int,lbc_cdm_dbi_int,lbc_cdm_dbi2_int
                }),
    .dout       ({lbc_cdm_addr
                ,lbc_cdm_data,lbc_cdm_cs,lbc_cdm_wr,lbc_cdm_dbi,lbc_cdm_dbi2
                })
  );


assign int_radm_data = cic_data;
assign radm_elbi_data = cic_data[ELBI_WD-1:0];


    assign int_radm_hdr  = cic_hdr ;
    assign int_radm_dv   = cic_dv ;
    assign int_radm_hv   = cic_hv ;
    assign int_radm_eot  = cic_eot ;
    assign int_radm_abort  = cic_abort ;
    assign int_radm_trgt0_pending  = cic_pending ;
//Detects possible deadlock
assign lbc_deadlock_det = 0;
reg [3*NVC-1:0] trgt0_block_np;

// Block NP TLPs when entering L1
always @(*) begin : TRGT0_BLOCK_NP
    integer i;
    trgt0_block_np = 0;
    for(i = 0; i < NVC; i = i + 1) begin
        trgt0_block_np[i*3 +: 3] = {1'b0, pm_l1_aspm_entr, 1'b0};
    end
end
assign int_trgt0_radm_halt = {3*NVC{radm_halt}} | trgt0_block_np;
assign  rcvd_fmt                = int_radm_hdr[ `RADM_Q_FMT_RANGE];
assign  rcvd_type               = int_radm_hdr[ `RADM_Q_TYPE_RANGE];
assign  rcvd_td                 = int_radm_hdr[ `RADM_NPQ_TD_RANGE];


assign  rcvd_tag                = int_radm_hdr[ `RADM_Q_TAG_RANGE];
assign  rcvd_reqid              = int_radm_hdr[ `RADM_Q_REQID_RANGE];
   assign  rcvd_func_id            = int_radm_hdr[ `RADM_Q_FUNC_NMBR_RANGE]; 

assign  rcvd_np_rd              = (({rcvd_fmt,rcvd_type} == `IORD)    ||
                                   ({rcvd_fmt,rcvd_type} == `CFGRD0)  ||
                                   ({rcvd_fmt,rcvd_type} == `CFGRD1)  ||
                                   ({rcvd_fmt,rcvd_type} == `MRD32)   ||
                                   ({rcvd_fmt,rcvd_type} == `MRD64)   ||
                                   ({rcvd_fmt,rcvd_type} == `MRDLK32) ||
                                   ({rcvd_fmt,rcvd_type} == `MRDLK64));

assign  rcvd_locked_rd          = (({rcvd_fmt,rcvd_type} == `MRDLK32) ||
                                   ({rcvd_fmt,rcvd_type} == `MRDLK64));

assign  first_be                = int_radm_hdr[ `RADM_PQ_FRSTDW_BE_RANGE];

assign  sc_last_be              = 4'b0;
assign  last_be                 = status_sc ? sc_last_be : int_radm_hdr[ `RADM_PQ_UNSC_LSTDW_BE_RANGE];
assign  addr_byte0              = int_addr_low[7:0];

assign  rcvd_tlp_len            = int_radm_hdr[`RADM_PQ_DW_LENGTH_RANGE];

assign  lower_addr              = (rcvd_memrd_req || rcvd_locked_rd) ? {addr_byte0[6:2], byte_addr} : 7'b0;
assign  byte_cnt                = (rcvd_memrd_req || rcvd_locked_rd) ? get_byte_count(first_be, last_be, rcvd_tlp_len)     :
                                  (rcvd_atomic_fas)                  ? get_byte_count(4'hf,4'hf,rcvd_tlp_len)              :
                                  (rcvd_atomic_cas)                  ? get_byte_count(4'hf,4'hf,{1'b0,rcvd_tlp_len[9:1]})  :
                                  12'h004;

assign  cpl_status              = int_radm_hdr[ `RADM_Q_CPL_STATUS_RANGE];
assign  status_sc               = (cpl_status == `SU_CPL_STATUS);  // Successful  Completion

assign  rcvd_iord_req           = ( {rcvd_fmt,rcvd_type} == `IORD);
assign  rcvd_iowr_req           = ( {rcvd_fmt,rcvd_type} == `IOWR);
assign  io_req_in_range         = int_radm_hdr[ `RADM_PQ_IO_REQ_IN_RANGE_RANGE];

assign  in_bar_range            = int_radm_hdr[ `RADM_PQ_IN_MEMBAR_RANGE_RANGE];

assign  rom_in_range            = int_radm_hdr[ `RADM_PQ_ROM_IN_RANGE_RANGE];

assign  rcvd_cfg0rd_req         = ( {rcvd_fmt,rcvd_type} == `CFGRD0);
assign  rcvd_cfg0wr_req         = ( {rcvd_fmt,rcvd_type} == `CFGWR0);
//assign  int_radm_dwlenEq1           = (int_radm_hdr[`RADM_PQ_DW_LENGTH_RANGE] == 10'b00000001);
assign  int_radm_zerobyte           = (int_radm_hdr[ `RADM_PQ_FRSTDW_BE_RANGE] == 4'b0) ;

assign  rcvd_memrd_req           = (({rcvd_fmt,rcvd_type} == `MRD32)   ||
                                   ({rcvd_fmt,rcvd_type} == `MRD64));

assign  rcvd_atomic_fas          = ({rcvd_fmt,rcvd_type} == `FETCHADD32) ||
                                   ({rcvd_fmt,rcvd_type} == `FETCHADD64) ||
                                   ({rcvd_fmt,rcvd_type} == `SWAP32)     ||
                                   ({rcvd_fmt,rcvd_type} == `SWAP64);

assign  rcvd_atomic_cas          = ({rcvd_fmt,rcvd_type} == `CAS32) ||
                                   ({rcvd_fmt,rcvd_type} == `CAS64);

assign  rcvd_atomic_req          = rcvd_atomic_cas || rcvd_atomic_fas;

assign  rcvd_memwr_req           = (({rcvd_fmt,rcvd_type} == `MWR32)   ||
                                   ({rcvd_fmt,rcvd_type} == `MWR64));

assign  rcvd_dmwr_req            = 0;

assign  rcvd_p_req               = ({rcvd_fmt,rcvd_type} == `MWR32)   ||
                                   ({rcvd_fmt,rcvd_type} == `MWR64)   ||
                                   ({rcvd_fmt,rcvd_type[4:3]} == `MSG_4) ||
                                   ({rcvd_fmt,rcvd_type[4:3]} == `MSGD_4);
  assign  dbi_rcvd_func_id         = dbi_addr[18:16];

parameter FLT_Q_ADDR_WIDTH = `FLT_Q_ADDR_WIDTH;
reg [FLT_Q_ADDR_WIDTH-1:0] int_addr;
always @(*) begin : EXTRACT_ADDR
  int_addr = 0;
  int_addr[0 +: FLT_Q_ADDR_WIDTH] = int_radm_hdr[ `RADM_PQ_ADDR_RANGE   ];
  
end 
assign int_addr_low = int_addr[LBC_DW-1:0];

assign  rcvd_bus_nmbr            = int_radm_hdr[`RADM_PQ_BUS_NMBR_RANGE];
assign  rcvd_dvc_nmbr            = int_radm_hdr[`RADM_PQ_DEV_NMBR_RANGE];

assign  rcvd_tc                  = int_radm_hdr[ `RADM_Q_TC_RANGE];
assign  rcvd_attr                = int_radm_hdr[ `RADM_Q_ATTR_RANGE];

always @(first_be)
    casez(first_be)
        4'b0000:     byte_addr = 2'b00;
        4'b???1:     byte_addr = 2'b00;
        4'b??10:     byte_addr = 2'b01;
        4'b?100:     byte_addr = 2'b10;
        4'b1000:     byte_addr = 2'b11;
    endcase



always @(posedge core_clk or negedge core_rst_n)
begin:  HEADER_INFO
    if(!core_rst_n) begin
        latchd_rcvd_tag          <= #TP 0;
        latchd_rcvd_reqid        <= #TP 0;
        latchd_rcvd_func_id      <= #TP 0;
        latchd_rcvd_atomic_req   <= #TP 0;
        latchd_rcvd_dmwr_req     <= #TP 0;
        latchd_rcvd_np_rd        <= #TP 0;
        latchd_rcvd_p_req        <= #TP 0;
        latchd_lower_addr        <= #TP 0;
        latchd_rcvd_locked_rd    <= #TP 0;
        latchd_cpl_status        <= #TP 0;
        latchd_status_sc         <= #TP 0;
        latchd_byte_cnt          <= #TP 0;
        latchd_rcvd_tc           <= #TP 0;
        latchd_rcvd_attr         <= #TP 0;
        latchd_rcvd_td           <= #TP 0;
        latchd_rcvd_tlp_len      <= #TP 0;
    end else if (int_radm_hv & ~radm_halt) begin
        latchd_rcvd_tag          <= #TP rcvd_tag;
        latchd_rcvd_reqid        <= #TP rcvd_reqid;
        latchd_rcvd_func_id      <= #TP rcvd_func_id;
        latchd_rcvd_atomic_req   <= #TP rcvd_atomic_req;
        latchd_rcvd_dmwr_req     <= #TP rcvd_dmwr_req;
        latchd_rcvd_np_rd        <= #TP rcvd_np_rd;
        latchd_rcvd_p_req        <= #TP rcvd_p_req;
        latchd_lower_addr        <= #TP lower_addr;
        latchd_rcvd_locked_rd    <= #TP rcvd_locked_rd;
        latchd_cpl_status        <= #TP cpl_status;
        latchd_status_sc         <= #TP status_sc;
        latchd_byte_cnt          <= #TP byte_cnt;
        latchd_rcvd_tc           <= #TP rcvd_tc;
        latchd_rcvd_attr         <= #TP rcvd_attr;
        latchd_rcvd_td           <= #TP rcvd_td;
        latchd_rcvd_tlp_len      <= #TP rcvd_tlp_len;
    end
end


// only support memory mapped request for the register access

// --------------------  Received TLP processing --------------------------------
//  lbc processing state is designed to walk through the sequential
//  event of a local bus tlp request:  decode, local bus access and completion request
//
//wire  good_hv  = int_radm_hv && int_radm_eot && !int_radm_abort;
wire  good_hv;
    assign good_hv  = int_radm_hv && int_radm_eot && !int_radm_abort;


// Used separately for handling malformed TLPs. If unsupported operand size is used i.e., the requests should be handled and a completion should be sent.
wire good_atomic_req;
assign good_atomic_req = latchd_rcvd_atomic_req && int_radm_eot && !int_radm_abort;
wire good_dmwr_req;
assign good_dmwr_req = latchd_rcvd_dmwr_req && int_radm_eot && !int_radm_abort;

wire lbc_return_err;
assign lbc_return_err = ((dbi_rcvd_func_id >=NF ) && (int_dbi_cs && !good_hv  & !int_radm_hv && !int_radm_trgt0_pending)
                        && !(good_hv && status_sc && !int_radm_zerobyte)
                        && !(good_hv && !rcvd_p_req));


always @(posedge core_clk or negedge core_rst_n)
begin: TLP_RECEPTION_PROCESS
integer                      i;
    if(!core_rst_n)
    begin
        lbc_cdm_cs_int         <= #TP  0;
        lbc_ext_cs         <= #TP  0;
        lbc_cdm_dbi_int        <= #TP  0;
        lbc_cdm_dbi2_int       <= #TP  0;
    end
    else if (lbc_proc_state == LBC_IDLE)
    begin

        for (i = 0; i<NF; i = i+1)
            if (((rcvd_func_id == i) && good_hv && status_sc && !int_radm_zerobyte)
                | ((dbi_rcvd_func_id == i) && (int_dbi_cs && !good_hv & !int_radm_hv && !int_radm_trgt0_pending) && !(good_hv && status_sc && !int_radm_zerobyte)
                       && !(good_hv && !rcvd_p_req)))
                lbc_cdm_cs_int[i] <= #TP next_lbc_cdm_cs;
            else
                lbc_cdm_cs_int[i] <= #TP 1'b0;

        for (i = 0; i<NF; i = i+1)
            if (((rcvd_func_id == i) && good_hv && status_sc && !int_radm_zerobyte)
                | ((dbi_rcvd_func_id == i) && (int_dbi_cs && !good_hv  & !int_radm_hv && !int_radm_trgt0_pending)
                     && !(good_hv && status_sc && !int_radm_zerobyte)
                     && !(good_hv && !rcvd_p_req)))
                lbc_ext_cs[i] <= #TP next_lbc_ext_cs;
            else
                lbc_ext_cs[i] <= #TP 1'b0;

        lbc_cdm_dbi_int        <= #TP next_lbc_cdm_dbi & !int_dbi_cs2;
        lbc_cdm_dbi2_int       <= #TP next_lbc_cdm_dbi & int_dbi_cs2;
    end
    else if((|cdm_lbc_ack) | (|ext_lbc_ack))
    begin
        lbc_cdm_cs_int         <= #TP  0;
        lbc_ext_cs         <= #TP  0;
        lbc_cdm_dbi_int        <= #TP  0;
        lbc_cdm_dbi2_int       <= #TP  0;
    end
end
  



always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        lbc_proc_state     <= #TP  LBC_IDLE;
    else
        lbc_proc_state     <= #TP next_lbc_proc_state;




wire rcvd_memrd_or_mrdlk_req;
assign rcvd_memrd_or_mrdlk_req = rcvd_memrd_req | rcvd_locked_rd;

wire lbc_ack_d_nd;


assign lbc_ack_d_nd =((|cdm_lbc_ack) | (|ext_lbc_ack)) ;
                          
always @(*)
begin
    // set when a new TLP has being taken, clear when ack comes. dbi_addr
    // set has priority over clear
    case (lbc_proc_state)
        LBC_IDLE:
            if (good_hv && status_sc && !int_radm_zerobyte ) begin
                next_lbc_proc_state      = LBC_NP_ASSERT;

                next_lbc_cdm_cs          =  ((rcvd_cfg0rd_req | rcvd_cfg0wr_req) && 
                                             ((int_addr_low[11:2] <= cfg_config_limit && int_addr_low[11:2]>PCI_CONFIG_MAX) || 
                                               ~|int_addr_low[11:8] && int_addr_low[7:2] <= `PCI_CONFIG_LIMIT)
                                            )
                                             ;

                next_lbc_ext_cs          =  ~next_lbc_cdm_cs;

                next_lbc_cdm_dbi         = 1'b0;
            // good_hv accounts for all requests including atomic requests. However, AtomicOp requests should handle packets whose length is not equal to the architected value i.e.Malformed TLPs#
            // So AtomicOp requests should be handled separately. Limitation - The controller rejects AtomicOps that target the ELBI, and returns a completion with CA status (3.21 databook)
            end else if (((good_atomic_req || good_dmwr_req) && !rcvd_p_req) || (good_hv && !rcvd_p_req)) begin    // for anything non posted, we need to completion. Here we can only receive memory write as a posted because messages are terminated at demux
                next_lbc_proc_state      = LBC_IN_CPL_REQ;
                next_lbc_ext_cs          = 1'b0;
                next_lbc_cdm_cs          = 1'b0;
                next_lbc_cdm_dbi         = 1'b0;
            end else if (int_dbi_cs && !good_hv & !int_radm_hv && !int_radm_trgt0_pending)  begin // This is to make sure that there is no tlp in progress from np or p interface
                next_lbc_proc_state      = lbc_return_err ? LBC_RETURN_ERR : LBC_EXT_DBI_REQ;
                next_lbc_cdm_dbi         = 1'b1;
                next_lbc_ext_cs          = (dbi_addr[0] && ~int_dbi_cs2);
                next_lbc_cdm_cs          = (!dbi_addr[0] || int_dbi_cs2) && !lbc_return_err;
            end else begin
                next_lbc_proc_state     = LBC_IDLE;
                next_lbc_ext_cs         = 1'b0;
                next_lbc_cdm_cs         = 1'b0;
                next_lbc_cdm_dbi        = 1'b0;
            end
        LBC_NP_ASSERT:  begin
            next_lbc_cdm_dbi            = 1'b0;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_ext_cs             = 1'b0;
            if (((|cdm_lbc_ack) | (|ext_lbc_ack)) & (!latchd_rcvd_p_req)) begin
                next_lbc_proc_state     = LBC_IN_CPL_REQ;
                next_lbc_cdm_cs         = 0;
                next_lbc_ext_cs         = 0;
            end else if (lbc_ack_d_nd & latchd_rcvd_p_req) begin
                next_lbc_proc_state     = LBC_IDLE;
                next_lbc_cdm_cs         = 0;
                next_lbc_ext_cs         = 0;
            end else begin
                next_lbc_proc_state     = LBC_NP_ASSERT;
            end
        end
        LBC_EXT_DBI_REQ:  begin
            next_lbc_cdm_dbi            = 1'b0;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_ext_cs             = 1'b0;
            if (int_lbc_dbi_ack) begin
                next_lbc_proc_state     = LBC_IDLE;
                next_lbc_cdm_cs         = 1'b0;
                next_lbc_cdm_dbi        = 1'b0;

            end else begin

                next_lbc_proc_state     = LBC_EXT_DBI_REQ;
            end
        end
        LBC_IN_CPL_REQ: begin
            next_lbc_cdm_dbi            = 1'b0;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_ext_cs             = 1'b0;
            if (!xadm_cpl_halt ) begin
                next_lbc_proc_state     = LBC_IDLE;
            end else begin
                next_lbc_proc_state     = LBC_IN_CPL_REQ;
            end

        end
        LBC_RETURN_ERR: begin
            next_lbc_cdm_dbi            = 1'b0;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_ext_cs             = 1'b0;
            next_lbc_proc_state         = LBC_IDLE;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_cdm_dbi            = 1'b0;
        end
        default:
            begin
                next_lbc_proc_state     = LBC_IDLE;
                next_lbc_cdm_dbi        = 1'b0;
                next_lbc_cdm_cs         = 1'b0;
                next_lbc_ext_cs         = 1'b0;
            end
    endcase // case(lbc_proc_state)
end // always @ (...



// When local bus access returned the data of read
// we will latch it for the later completion tlp formation
always @(posedge core_clk or negedge core_rst_n)
begin : MUX_OUTPUTS
integer i,j;

    if (!core_rst_n)
    begin
        latchd_lbc_din <= #TP 0;

    end
    else
        if ((|cdm_lbc_ack) & (!(|lbc_cdm_wr_int)))
        begin
            for (i = 0; i<NF; i = i+1)
                if (cdm_lbc_ack[i])
                    for (j=0; j<32; j=j+1) begin
                        latchd_lbc_din[j] <= #TP cdm_lbc_din[i*32+j];
                    end
        end
        else
        begin
            if ((|ext_lbc_ack) & (!(|lbc_ext_wr)))
            begin
                for (i = 0; i<NF; i = i+1)
                    if (ext_lbc_ack[i])
                      for (j=0; j<LBC_INT_WD; j=j+1) begin
                            latchd_lbc_din[j] <= #TP int_lbc_din[i*LBC_INT_WD+j];
                      end
            end
        end
end

always @(*)
begin : INT_LBC_DIN_MUX
    int_lbc_din = ext_lbc_din;
end

// ------------------------ Completion Generation Section -----------
// all read requests and non posted write requests required completions.
// completion state machine is designed to drive 32 bits completion bus to
// xadm for the transmission of tlp
//


wire [6:0] tmp_type;
assign tmp_type  =   (latchd_status_sc & latchd_rcvd_np_rd & latchd_rcvd_locked_rd) ? `CPLDLK
                         : (latchd_status_sc & latchd_rcvd_np_rd & !latchd_rcvd_locked_rd) ? `CPLD
                         : (latchd_rcvd_locked_rd) ? `CPLLK
                         : `CPL ;
wire [15:0]   cmpltr_vf_rid;

wire [15:0]   cmpltr_id;
assign cmpltr_id     = {cfg_pbus_num, cfg_pbus_dev_num, latchd_rcvd_func_id};

assign     tlp_byte_len = 13'h0004;     // Length = 1 DW

assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_ADDR     ] = {57'b0, latchd_lower_addr[6:0]}; // low address is overlayed on the regular address location
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_FMT      ] = tmp_type[6:5];
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_TYPE     ] = tmp_type[4:0];
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_TC       ] = latchd_rcvd_tc;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_TD       ] = 1'b0;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_EP       ] = 1'b0;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_ATTR     ] = latchd_rcvd_attr;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_BYTE_LEN ] = (latchd_rcvd_np_rd & latchd_status_sc) ? tlp_byte_len : 13'h0000;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_TAG      ] = latchd_rcvd_tag;
assign     lbc_cpl_hdr_nxt[`F_HDR_CPL_REQ_ID   ] = latchd_rcvd_reqid[15:0];
assign     lbc_cpl_hdr_nxt[`F_HDR_CPL_BYTE_CNT ] = latchd_byte_cnt[11:0];
assign     lbc_cpl_hdr_nxt[`F_HDR_CPL_BCM      ] = 1'b0;
assign     lbc_cpl_hdr_nxt[`F_HDR_CPL_STATUS   ] = latchd_cpl_status[2:0];
assign     lbc_cpl_hdr_nxt[`F_HDR_REQ_ID   ]     = cmpltr_id;
assign     lbc_cpl_hdr_nxt[`F_HDR_BYTE_EN      ] = 0;
assign     lbc_cpl_hdr_nxt[`F_HDR_ADDR_ALIGN_EN] = 1'b1;
assign     lbc_cpl_data_int                  = latchd_lbc_din;

wire [DW-1:0] rasdp_cpl_data_int;
assign rasdp_cpl_data_int = {{(DW-LBC_INT_WD){1'b0}}, lbc_cpl_data_int};

//
 assign     lbc_cpl_data   = rasdp_cpl_data_int;

 assign lbc_cpl_hdr = lbc_cpl_hdr_nxt;

always @(posedge core_clk or negedge core_rst_n)
begin: GEN_CPL_HDR
    if (!core_rst_n)
    begin
        lbc_cpl_hv      <= #TP 0;
        lbc_cpl_dv      <= #TP 0;
        lbc_cpl_eot     <= #TP 0;
    end
    else
    begin
        // when it is a read request, it will have completion with
        // data
        // 1. when we are in CPL processing state, then we will set
        // request
        // 2. when a completion has been acknowledged, then will
        // deassert the request, a completion can have 3 hdr and
        // 1 data if it is a read
        // NOte: When a Read Completion is received with a Completion Status other than successful CPL:
        // - No data is included with the CPL, the CPL (or CPLLK) encoding is used instead of CPLD (CPLDLK)

        if (( lbc_proc_state == LBC_IN_CPL_REQ) & !lbc_cpl_hv) begin
         lbc_cpl_dv       <= #TP latchd_rcvd_np_rd && latchd_status_sc;
         lbc_cpl_hv       <= #TP 1'b1;
         lbc_cpl_eot      <= #TP 1'b1;
       end else if (!xadm_cpl_halt) begin
         lbc_cpl_dv       <= #TP 1'b0;
         lbc_cpl_hv       <= #TP 1'b0;
         lbc_cpl_eot      <= #TP 1'b0;
       end
    end
end // block: GEN_CPL_HDR

// Sending CPL w/ CA.
// Needed for error reporting when core internally generate CPL w/ CA.
assign lbc_xmt_cpl_ca = {{(NF-1){1'b0}} , ((cmpltr_id[NFUNC_WD-1:0] == 0)          &
                                            lbc_cpl_hv                             &
                                            !xadm_cpl_halt                         &
                                            (latchd_cpl_status == `CA_CPL_STATUS))
                                                                                   };

// output process for external dbi interface

assign lbc_dbi_dout = latchd_lbc_din[31:0];

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
         int_lbc_dbi_ack    <= #TP 0;
    else
         int_lbc_dbi_ack    <= #TP ((lbc_proc_state == LBC_EXT_DBI_REQ) & ((|cdm_lbc_ack) || (|ext_lbc_ack))) ||
                               (next_lbc_proc_state == LBC_RETURN_ERR);
end

// To ensure fairness between the DBI requestor and the RADM requestor
// BLock the RADM interface when the LBC hass completed processing a RADM CPL
// to allow the DBI access to the CDM. The halt is for a single cycle and is
// only asserted if there is a pending DBI request
always @(posedge core_clk or negedge core_rst_n)
begin
  if (!core_rst_n)
    lbc_arb_halt_radm <= #TP 1'b0;
  else begin
    if(lbc_proc_state == LBC_IN_CPL_REQ & next_lbc_proc_state == LBC_IDLE & int_dbi_cs)
      lbc_arb_halt_radm <= #TP 1'b1;
    else
      lbc_arb_halt_radm <= #TP 1'b0;
  end
end

// Halt can be generated from lbc and slave states to control the np and
// p interface with RADM independently. This is due to the memory read and
// write access can go through to lbc or slave interface
//
//Since we latchd the request transaction for better timing, then we halt
//under following conditions:
//1. when lbc proc state is not idle
//2. when lbc proc state is idle and the request is being latchd
//3. When LBC is completing a RADM CPL and DBI Req is Pending
assign  radm_halt = (lbc_proc_state != LBC_IDLE) | lbc_arb_halt_radm;

// external lbc interface output drives
assign  lbc_ext_dout      = latchd_data;
assign  lbc_cdm_data_int  = latchd_data;

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        lbc_ext_rom_access       <= #TP 0;
        lbc_ext_io_access        <= #TP 0;
        lbc_ext_bar_num          <= #TP `RADM_OUTSIDE_MEMBAR;
        lbc_ext_wr               <= #TP 0;
        lbc_ext_addr             <= #TP 0;
    end
    else
    begin
        if (int_radm_hv & !radm_halt) begin
            lbc_ext_rom_access   <= #TP rom_in_range    && (rcvd_memrd_req || rcvd_memwr_req);
            lbc_ext_io_access    <= #TP io_req_in_range && (rcvd_iord_req  || rcvd_iowr_req );
            lbc_ext_bar_num      <= #TP in_bar_range;
            lbc_ext_wr           <= #TP rcvd_np_rd ? 4'b0 : first_be;

            lbc_ext_addr         <= #TP int_addr_low[LBC_EXT_AW-1:0];
        end else if (!radm_halt || (int_dbi_cs & lbc_proc_state == LBC_IDLE)) begin

            lbc_ext_rom_access   <= #TP 1'b0;
            lbc_ext_io_access    <= #TP 1'b0;
            lbc_ext_bar_num      <= #TP 3'h7;
            lbc_ext_wr           <= #TP dbi_elbi_wr;
            lbc_ext_addr         <= #TP {dbi_addr[LBC_EXT_AW-1:1], 1'b0};
        end

    end
end


assign select_radm = (cic_hv & cic_dv & ~radm_halt);

// Data bus output process
always @(posedge core_clk or negedge core_rst_n)
begin:  DBI_REGS
    if(!core_rst_n) begin
        latchd_data              <= #TP 0;
    end
    else if (select_radm)
    begin
        latchd_data              <= #TP radm_elbi_data;
    end
    else if (next_lbc_proc_state == LBC_EXT_DBI_REQ)
    begin
        latchd_data              <= #TP dbi_elbi_din;          // park on dbi interface
    end
end

// Select DBI data
always @(*)
begin:  SELECT_DBI_DIN_32
        dbi_elbi_din = dbi_din;
        dbi_elbi_wr  = dbi_wr;
end








always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        lbc_cdm_wr_int               <= #TP 0;
        lbc_cdm_addr_int         <= #TP 0;
    end
    else if (int_radm_hv & !radm_halt)
    begin
        lbc_cdm_wr_int           <= #TP rcvd_np_rd ? 4'b0 : first_be;

           lbc_cdm_addr_int         <= #TP {rcvd_bus_nmbr,rcvd_dvc_nmbr,{(3 - NFUNC_WD) {1'b0}},rcvd_func_id,4'h0,int_addr_low[11:0]};
    end
    else if (int_dbi_cs & lbc_proc_state == LBC_IDLE)
    begin
        lbc_cdm_wr_int               <= #TP dbi_wr   ;
        

        lbc_cdm_addr_int             <= #TP {dbi_addr[LBC_DW-1:1],1'b0};
    end
end


  assign int_dbi_cs  = dbi_cs;
  assign int_dbi_cs2 = dbi_cs2;
  assign lbc_dbi_ack = int_lbc_dbi_ack;






// Detect when the LBC is processing a request
// This signal is intended to be used by the PM control to stop the L1
// idle_timer.
// Entering L1 when there is a NP request in the LBC causes a potential
// deadlock since the completion cannot be sent when entering L1 and single
// threaded nature of the LBC means that posted requests cannot be accepted
// until the current NP request completes.
// Entering L1 when there is a P request means there is a potential that the
// clock will be removed when that request is still active
// If posted requests cannot be accepted then it is possible that credits
// become exhausted and the link partner cannot send an active state Nak
// causing deadlock.
wire lbc_active;
assign lbc_active = lbc_proc_state == LBC_NP_ASSERT ||
    lbc_proc_state == LBC_IN_CPL_REQ ||
    cic_active;

function automatic [11:0] get_byte_count;
    input   [3:0]   first_dwen;
    input   [3:0]   last_dwen;
    input   [9:0]   latchd_dwlen;

    reg     [11:0]  f_length_times4;
    reg     [11:0]  f_bytelength;
    reg     [2 :0]  f_subend;
begin

    f_length_times4 = {latchd_dwlen, 2'b0};
    f_subend = 3'b0;

    if (last_dwen == 0) begin
        case (first_dwen)
            4'b1001, 4'b1011, 4'b1101, 4'b1111 : f_bytelength = 4;
            4'b0101, 4'b0111, 4'b1010, 4'b1110 : f_bytelength = 3;
            4'b0011, 4'b0110, 4'b1100          : f_bytelength = 2;
            default                            : f_bytelength = 1;
        endcase
    end else begin
        if (first_dwen[0])
            f_subend = 0;
        else if (first_dwen[1])
            f_subend = 1;
        else if (first_dwen[2])
            f_subend = 2;
        else
            f_subend = 3;

        if (last_dwen[3])
            f_subend = f_subend + 0;
        else if (last_dwen[2])
            f_subend = f_subend + 1;
        else if (last_dwen[1])
            f_subend = f_subend + 2;
        else
            f_subend = f_subend + 3;
// spyglass disable_block W484
// SMD: Possible loss of carry or borrow due to addition or subtraction
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        f_bytelength = 12'(f_length_times4 - f_subend);
// spyglass enable_block W484
    end

    get_byte_count = f_bytelength;

end
endfunction


//VCS coverage off
`ifndef SYNTHESIS
//----------------------------------------------------------------------------------
wire    [15*8:0]         LBC_STATE;
assign  LBC_STATE   =        (lbc_proc_state  == LBC_IDLE ) ? "LBC_IDLE"   :
                             ((lbc_proc_state  == LBC_EXT_DBI_REQ  ) ? "LBC_EXT_DBI_REQ" :
                             ((lbc_proc_state  == LBC_IN_CPL_REQ   ) ? "LBC_IN_CPL_REQ" :
                             ((lbc_proc_state  == LBC_EXT_AW       ) ? "LBC_EXT_AW" :
                             ((lbc_proc_state  == LBC_NP_ASSERT    ) ? "LBC_NP_ASSERT" :
                             ((lbc_proc_state  == LBC_DW           ) ? "LBC_DW" : "ERR")))));
//----------------------------------------------------------------------------------
`endif // SYNTHESIS
//VCS coverage on

endmodule

