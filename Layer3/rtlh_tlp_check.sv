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
// ---    $DateTime: 2020/06/26 01:14:06 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_tlp_check.sv#6 $
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

 
 module rtlh_tlp_check (
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
    rtlh_extrct_ecrc_len_mismatch,
    rtlh_extrct_ecrc_err,
    rtlh_fc_init1_status,
    cfg_tc_enable,

    rtfcgen_rtcheck_overfl_err,

    
// outputs
    rtlh_radm_data,
    rtlh_radm_hdr,
    rtlh_radm_dwen,
    rtlh_radm_hv,
    rtlh_radm_dv,
    rtlh_radm_eot,
    rtlh_radm_malform_tlp_err,
    rtlh_radm_ecrc_err,
    rtlh_radm_dllp_err,
    rtlh_radm_ant_addr,
    rtlh_radm_ant_rid,
    rtlh_radm_pending,
    rtfcgen_vc,
    rtfcgen_fctype,
    rtfcgen_incr_enable,
    rtfcgen_incr_amt
);
// ----------------------------------------------------------------------------
// --- Parameters
// ----------------------------------------------------------------------------

parameter   INST            = 0;          // The uniquifying parameter for each port logic instance.
parameter   NW              = `CX_NW;     // Number of 32-bit dwords handled by the datapath each clock.
parameter   NVC             = `CX_NVC;    // Number of VC
parameter   DW              = (32*NW);    // Width of datapath in bits.
parameter   TP              = `TP;        // Clock to Q delay (simulator insurance)
parameter   DATA_PAR_WD     = `TRGT_DATA_PROT_WD; // data bus parity width
parameter   RAS_PCIE_HDR_PROT_WD = `CX_RAS_PCIE_HDR_PROT_WD;

localparam  RX_TLP          = `CX_RX_TLP; // Number of TLPs that can be processed in a single cycle

localparam  HW_W_PAR        = RX_TLP*(128+RAS_PCIE_HDR_PROT_WD);
localparam  DW_W_PAR        = DW+DATA_PAR_WD;
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
input   [RX_TLP-1:0]          rtlh_extrct_dv;                 // Payload data valid
input   [RX_TLP-1:0]          rtlh_extrct_sot;                // hdr is valid this cycle
input   [RX_TLP-1:0]          rtlh_extrct_eot;                // end of a TLP
input   [RX_TLP-1:0]          rtlh_extrct_abort;              // DLLP layer abort due to DLLP layer error detected
input   [RX_TLP-1:0]          rtlh_extrct_ecrc_err;           // ECRC error detected when TD bit is set a TLP header
input   [RX_TLP-1:0]          rtlh_extrct_ecrc_len_mismatch;  // ECRC error detected when TD bit is set a TLP header and there is a length mismatch
input   [NVC-1:0]             rtlh_fc_init1_status;           // FC init status indicates that IFC1 state has been done

input  [RX_TLP-1:0]           rtfcgen_rtcheck_overfl_err;       // Credit error from FC

// -------------------------------- Outputs ------------------------------------
output  [DW+DATA_PAR_WD-1:0]  rtlh_radm_data;                 // Data (payload/hdr) of TLP packet, When it is 32b and 64b, hdr is merged onto this bus
output  [(128+RAS_PCIE_HDR_PROT_WD)*RX_TLP-1:0]  rtlh_radm_hdr;                  // hdr of TLP packet, only for 128b arch
output  [NW-1:0]              rtlh_radm_dwen;                 // Dword enable of the data bus
output  [RX_TLP-1:0]          rtlh_radm_dv;                   // Data (payload) is valid this cycle
output  [RX_TLP-1:0]          rtlh_radm_hv;                   // hdr is valid this cycle
output  [RX_TLP-1:0]          rtlh_radm_eot;                  // end of TLP
output  [RX_TLP-1:0]          rtlh_radm_dllp_err;             // Indicates current packet should be dropped because of DLLP layer err
output  [RX_TLP-1:0]          rtlh_radm_ecrc_err;             // Indicates current packet should be dropped because of ecrc error
output  [RX_TLP-1:0]          rtlh_radm_malform_tlp_err;      // Indicates current packet should be dropped because of checkers failed in this module
output  [64*RX_TLP-1:0]       rtlh_radm_ant_addr;             // anticipated address (1 clock earlier)
output  [16*RX_TLP-1:0]       rtlh_radm_ant_rid;              // anticipated RID (1 clock earlier)
output                        rtlh_radm_pending;              // Indicates RTLH is providing one or more TLPs.

output  [3*RX_TLP-1:0]        rtfcgen_vc;                     // interface to flow contorl book keeping module, TC value
output  [2*RX_TLP-1:0]        rtfcgen_fctype;                 // FC type 00 = posted, 01== NP, 10 == CPL
output  [RX_TLP-1:0]          rtfcgen_incr_enable;            // FC increment enable. This is a strobe signal which indicates the FC type, FC amount and TC are valid.
output  [9*RX_TLP-1:0]        rtfcgen_incr_amt;               // FC credit amount. 9 bits used to allow max payload size of 4096 bytes

// ----------------------------------------------------------------------------
// Registered outputs
// ----------------------------------------------------------------------------
wire     [DW+DATA_PAR_WD-1:0]   rtlh_radm_data;
wire     [(128+RAS_PCIE_HDR_PROT_WD)*RX_TLP-1:0] rtlh_radm_hdr;
wire     [NW-1:0]   rtlh_radm_dwen;
wire     [RX_TLP-1:0]  rtlh_radm_dv;
wire     [RX_TLP-1:0]  rtlh_radm_hv;
wire     [RX_TLP-1:0]  rtlh_radm_eot;
wire     [RX_TLP-1:0]  rtlh_radm_dllp_err;
wire     [RX_TLP-1:0]  rtlh_radm_ecrc_err;     // Indicates current packet should be dropped because of tlp(aborted)
wire     [RX_TLP-1:0]  rtlh_radm_malform_tlp_err;     // Indicates current packet should be dropped because of tlp(aborted)

wire   [RX_TLP*11-1:0] next_pyld_dwcnt;
reg    [RX_TLP*11-1:0] prev_pyld_dwcnt;
reg    [10:0]          r_pyld_dwcnt;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        r_pyld_dwcnt <= #TP 0;
    end else begin
        r_pyld_dwcnt <= #TP next_pyld_dwcnt[11*(RX_TLP-1) +: 11];
    end

// Interconnect between tlp_check_slv stages
always @(*) begin : tlp_check_slv_interconnect
    integer i;
    prev_pyld_dwcnt[0 +: 11] = r_pyld_dwcnt;
    for(i = 1; i < RX_TLP; i = i + 1) begin
        prev_pyld_dwcnt[i*11 +: 11] = next_pyld_dwcnt[(i-1)*11 +: 11];
    end
end


////////////////////////////////////////////////////////////////////////////////
// Instantiation of rtlh_tlp_check_slv modules
////////////////////////////////////////////////////////////////////////////////
genvar tlp_check_slv;
generate
for (tlp_check_slv=0; tlp_check_slv<RX_TLP; tlp_check_slv = tlp_check_slv + 1 ) begin : gen_tlp_check_slv
    // Note that for 256b phase2 the width of the data processed by each slv is one half of the full width
    rtlh_tlp_check_slv
     #(.INST(INST), .NW(NW/RX_TLP), .DATA_PAR_WD(DATA_PAR_WD/RX_TLP)) u_rtlh_tlp_check_slv (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_max_payload                (cfg_max_payload),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_root_compx                 (cfg_root_compx),
    .cfg_endpoint                   (cfg_endpoint),
    .cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map),
    .rtlh_extrct_data               (rtlh_extrct_data[tlp_check_slv*DW_W_PAR/RX_TLP +: DW_W_PAR/RX_TLP]),
    .rtlh_extrct_hdr                (rtlh_extrct_hdr[tlp_check_slv*HW_W_PAR/RX_TLP +: HW_W_PAR/RX_TLP]),
    .rtlh_extrct_dwen               (rtlh_extrct_dwen[tlp_check_slv*NW/RX_TLP +: NW/RX_TLP]),
    .rtlh_extrct_sot                (rtlh_extrct_sot[tlp_check_slv]),
    .rtlh_extrct_dv                 (rtlh_extrct_dv[tlp_check_slv]),
    .rtlh_extrct_eot                (rtlh_extrct_eot[tlp_check_slv]),
    .rtlh_extrct_abort              (rtlh_extrct_abort[tlp_check_slv]),
    .rtlh_extrct_ecrc_err           (rtlh_extrct_ecrc_err[tlp_check_slv]),
    .rtlh_extrct_ecrc_len_mismatch  (rtlh_extrct_ecrc_len_mismatch[tlp_check_slv]),
    .rtlh_fc_init1_status           (rtlh_fc_init1_status),
    .cfg_tc_enable                  (cfg_tc_enable),

   .rtlh_radm_ant_addr              (rtlh_radm_ant_addr[tlp_check_slv*64 +: 64]),
   .rtlh_radm_ant_rid               (rtlh_radm_ant_rid[tlp_check_slv*16 +: 16]),

   .prev_pyld_dwcnt                 (prev_pyld_dwcnt[tlp_check_slv*11 +: 11]),


   .rtfcgen_overfl_err              (rtfcgen_rtcheck_overfl_err[tlp_check_slv]),

// outputs
    .next_pyld_dwcnt                (next_pyld_dwcnt[tlp_check_slv*11 +: 11]),

    .rtlh_radm_data                 (rtlh_radm_data[tlp_check_slv*(DW+DATA_PAR_WD)/RX_TLP +: (DW+DATA_PAR_WD)/RX_TLP]),
    .rtlh_radm_hdr                  (rtlh_radm_hdr[tlp_check_slv*(128+RAS_PCIE_HDR_PROT_WD) +: (128+RAS_PCIE_HDR_PROT_WD)]),
    .rtlh_radm_dwen                 (rtlh_radm_dwen[tlp_check_slv*NW/RX_TLP +: NW/RX_TLP]),
    .rtlh_radm_hv                   (rtlh_radm_hv[tlp_check_slv]),
    .rtlh_radm_dv                   (rtlh_radm_dv[tlp_check_slv]),
    .rtlh_radm_eot                  (rtlh_radm_eot[tlp_check_slv]),
    .rtlh_radm_malform_tlp_err      (rtlh_radm_malform_tlp_err[tlp_check_slv]),
    .rtlh_radm_ecrc_err             (rtlh_radm_ecrc_err[tlp_check_slv]),
    .rtlh_radm_dllp_err             (rtlh_radm_dllp_err[tlp_check_slv]),
    .rtfcgen_vc                     (rtfcgen_vc[tlp_check_slv*3 +: 3]),
    .rtfcgen_fctype                 (rtfcgen_fctype[tlp_check_slv*2 +: 2]),
    .rtfcgen_incr_enable            (rtfcgen_incr_enable[tlp_check_slv]),
    .rtfcgen_incr_amt               (rtfcgen_incr_amt[tlp_check_slv*9 +: 9])
);
end
endgenerate


// rtlh_radm_pending indicates RTLH is providing one or more TLPs.
// Depending on the latency of this module (i.e. 1 or 2 clock cycles), the signal is enabled 1 or 2 clock cycles before 
// the 1st TLP is provided and stays high until last TLP finishes or 1 clock cycle after the last TLP finishes.
wire rtlh_extrct_valid;
reg pkt_in_progress_d;

assign rtlh_extrct_valid = (|rtlh_extrct_sot) | (|rtlh_extrct_dv) | (|rtlh_extrct_eot);

reg [RX_TLP-1:0] l_pkt_in_progress;
always @(*) begin : packet_in_progress
    for(int i = 0; i< RX_TLP; i = i + 1) begin
        l_pkt_in_progress[i] = rtlh_extrct_eot[i] ? 0 : 
                               rtlh_extrct_sot[i]  ? 1 :
                               (i==0)? pkt_in_progress_d : l_pkt_in_progress[i-1];
    end
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        pkt_in_progress_d <= #TP 0;
    end else if (rtlh_extrct_valid) begin
        pkt_in_progress_d <= #TP l_pkt_in_progress[RX_TLP-1];
    end

logic [2:0] int_rtlh_radm_pending;
assign int_rtlh_radm_pending[0] = rtlh_extrct_valid || pkt_in_progress_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        int_rtlh_radm_pending[2:1] <= #TP 0;
    end else begin
        int_rtlh_radm_pending[2:1] <= #TP int_rtlh_radm_pending[1:0];
    end

assign rtlh_radm_pending = |int_rtlh_radm_pending;

endmodule
