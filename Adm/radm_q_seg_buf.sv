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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_q_seg_buf.sv#11 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles queue managment functions for receive TLPs.
// --- Its main functions are:
// ---    (1) Store incoming TLPs (hdr and data seperately)
// ---    into three different queues depending on types of P, NP and CPL when
// ---    not in single queue mode.
// ---    (2) Move pointer back when tlp was aborted.
// ---    (3) update queue credits available every clock to flow conrol block.
//
// -----------------------------------------------------------------------------
`ifndef SYNTHESIS
//VCS coverage off
//VCS coverage on
`endif

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module radm_q_seg_buf(
// ------ inputs ------
    core_clk,
    core_rst_n,
    cfg_radm_q_mode,
    cfg_radm_order_rule,
    cfg_order_rule_ctrl,
    cfg_filter_rule_mask,
    cfg_radm_strict_vc_prior,
    cfg_hq_depths,
    cfg_dq_depths,

    // Inputs from the Wire side.
    flt_q_hv,
    flt_q_dv,
    flt_q_data,
    flt_q_header,
    flt_q_dwen,
    flt_q_eot,
    flt_q_dllp_abort,
    flt_q_tlp_abort,
    flt_q_ecrc_err,
    flt_q_tlp_type,
    flt_q_seg_num,
    flt_q_vc,
    flt_q_parerr,
    // halt inputs for halting a TLP packet
    trgt0_radm_halt,
    trgt1_radm_halt,
    trgt1_radm_pkt_halt,
    bridge_trgt1_radm_pkt_halt,
    trgt_lut_trgt1_radm_pkt_halt,

// ------ outputs ------
    sb_init_done,
    // Outputs to the Wire side.
    //   Credit return signals.
    radm_rtlh_ph_ca,
    radm_rtlh_pd_ca,
    radm_rtlh_nph_ca,
    radm_rtlh_npd_ca,
    radm_rtlh_cplh_ca,
    radm_rtlh_cpld_ca,
    radm_rtlh_crd_pending,

    // Queue status outputs.
    radm_qoverflow,
    radm_q_not_empty,

    // MISC
    radm_grant_tlp_type,
    radm_pend_cpl_so,
    radm_q_cpl_not_empty,
    radm_parerr,
    radm_trgt0_pending,

    // target 0 interface
    radm_trgt0_data,
    radm_trgt0_hdr,
    radm_trgt0_dwen,
    radm_trgt0_dv,
    radm_trgt0_hv,
    radm_trgt0_eot,
    radm_trgt0_abort,
    radm_trgt0_ecrc_err,

    radm_trgt1_data,
    radm_trgt1_hdr,
    radm_trgt1_dwen,
    radm_trgt1_dv,
    radm_trgt1_hv,
    radm_trgt1_eot,
    radm_trgt1_tlp_abort,
    radm_trgt1_dllp_abort,
    radm_trgt1_ecrc_err,
    radm_trgt1_vc_num,
    // bypass interface
    radm_bypass_data,
    radm_bypass_hdr,    
    radm_bypass_dwen,
    radm_bypass_dv,
    radm_bypass_hv,
    radm_bypass_eot,
    radm_bypass_tlp_abort,
    radm_bypass_dllp_abort,
    radm_bypass_ecrc_err,

// ---- RAM external interface, Combine of inputs and outputs
    dataq_addra,
    dataq_addrb,
    dataq_datain,
    dataq_dataout,
    dataq_ena,
    dataq_enb,
    dataq_wea,
    dataq_parerr,
    dataq_par_chk_val,
    dataq_parerr_out,
    hdrq_addra,
    hdrq_addrb,
    hdrq_datain,
    hdrq_dataout,
    hdrq_ena,
    hdrq_enb,
    hdrq_wea,
    hdrq_parerr,
    hdrq_par_chk_val,
    hdrq_parerr_out
);

parameter INST                      = 0;                        // The uniquifying parameter for each port logic instance.
parameter NL                        = `CX_NL;                   // Max number of lanes supported
parameter NB                        = `CX_NB;                   // Number of symbols (bytes) per clock cycle
parameter NW                        = `CX_NW;                   // Number of 32-bit dwords handled by the datapath each clock.
parameter NVC                       = `CX_NVC;                  // Number of VC designed to support
parameter NHQ                       = `CX_NHQ;                  // Number of Header Queues per VC
parameter NDQ                       = `CX_NDQ;                  // Number of Data Queues per VC
parameter NDQ_LOG2                  = `CX_LOGBASE2(NDQ);
parameter NHQ_LOG2                  = `CX_LOGBASE2(NHQ);
parameter DW                        = (32*NW);                  // Width of datapath in bits.
parameter TP                        = `TP;                      // Clock to Q delay (simulator insurance)

//
// Local parameters
//

parameter P_TYPE                    = 0;
parameter NP_TYPE                   = 1;
parameter CPL_TYPE                  = 2;
parameter DATA_PAR_WD               = `TRGT_DATA_PROT_WD;
// Header protection code covers the complete header
parameter HDR_PROT_WD               = `CX_FLT_OUT_PROT_WD;
parameter RADM_SBUF_HDRQ_PW         = `CX_RADM_SBUF_HDRQ_PW;
parameter RADM_SBUF_DATAQ_WD        = `CX_RADM_SBUF_DATAQ_WD;
parameter RADM_SBUF_DATAQ_RAM_WD    = `CX_RADM_SBUF_DATAQ_RAM_WD;
parameter RADM_SBUF_DATAQ_PW        = `CX_RADM_SBUF_DATAQ_PW;
parameter HW                        = `FLT_Q_HDR_WIDTH;
parameter RADM_SBUF_HDRQ_WD         = `CX_RADM_SBUF_HDRQ_WD;
parameter RADM_P_HWD                = `RADM_P_HWD;

parameter SBUF_DATA_PROT_WD         = `CX_RADM_SBUF_DATAQ_PROT_WD;
parameter RADM_SBUF_DATAQ_NOPROT_WD = `CX_RADM_SBUF_DATAQ_NOPROT_WD;

parameter TRGT_HDR_WD               = `TRGT_HDR_WD;
parameter TRGT_DATA_WD              = `TRGT_DATA_WD;

parameter NUM_SEGMENTS              = `CX_NUM_SEGMENTS;
parameter SEG_WIDTH                 = `CX_SEG_WIDTH;
parameter HOLD_RADDR                = 0;

parameter GENERATE_STARTEND_ADDRS   = 1;
parameter DEBUG_WRITES              = 0;
parameter N_FLT_MASK                = `CX_N_FLT_MASK;


parameter RADM_SBUF_DATAQ_CTRLQ_WD = `CX_RADM_SBUF_DATAQ_CTRLQ_WD;
parameter RADM_SBUF_DATAQ_DEPTH = `CX_RADM_DATAQ_DEPTH;


parameter  DCA_WD                   = `CX_LOGBASE2(NW/4+1);

parameter RADM_RAM_RD_CTL_REGOUT    = `CX_RADM_RAM_RD_CTL_REGOUT;
parameter RADM_RAM_WR_REGOUT        = `CX_RADM_RAM_WR_REGOUT;

// -------------------------------- Inputs ------------------------------------
input                               core_clk;                   // Core clock
input                               core_rst_n;                 // Core system reset
input   [(NVC*3*3)-1:0]             cfg_radm_q_mode;            // Indicates that queue is in bypass, cut-through, and store-forward mode for posted TLP.
                                                                // 3bits per VC, bit0 for bypass, bit1 for cut-through and bit2 for store and forward
                                                                // 3bits for type posted, non posted and completion
input   [NVC-1:0]                   cfg_radm_order_rule;        // Indicates what scheme the order queue selection mechanism should be used
                                                                // 1'b0 used for strict priority scheme
input                               cfg_radm_strict_vc_prior;   // 1 indicates strict priority, 0 indicates round roubin
input   [N_FLT_MASK-1:0]            cfg_filter_rule_mask;       // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
input   [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0] cfg_hq_depths;      // Indicates the depth of the header queues per type per vc
input   [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]cfg_dq_depths;      // Indicates the depth of the data queues per type per vc
input   [15:0]                      cfg_order_rule_ctrl;        // cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC 

input   [NHQ -1:0]                  flt_q_hv;                   // Header from TLP alignment block is valid (Start of packet)
input   [NHQ*(HW+HDR_PROT_WD) -1:0] flt_q_header;               // Packet header information.
input   [NDQ -1:0]                  flt_q_dv;                   // Data from TLP alignment block is valid
input   [DW+DATA_PAR_WD -1:0]       flt_q_data;                 // Packet data.
input   [NW -1:0]                   flt_q_dwen;                 // DWord Enable for Data Interface.
input   [NHQ -1: 0]                 flt_q_eot;                  // Indicate end of packet
input   [NHQ-1:0]                   flt_q_dllp_abort;           // Data Link Layer abort. (Recall packet in store-and-forward mode.)
input   [NHQ-1:0]                   flt_q_tlp_abort;            // Transaction Layer abort (Malformed TLP, etc.)  Flow Control Credits are still returned for pkts w/ this type of abort.
input   [NHQ-1:0]                   flt_q_ecrc_err;             // Transaction Layer ECRC Error indication.
input   [NHQ*3-1:0]                 flt_q_tlp_type;
input   [NHQ*SEG_WIDTH-1:0]         flt_q_seg_num;              // segment number
input   [NHQ*3-1:0]                 flt_q_vc;                   // VC number
input   [NHQ-1:0]                   flt_q_parerr;
input                               trgt1_radm_halt;              // halt the cycle of the outputq
input   [(NVC*3)-1:0]               trgt1_radm_pkt_halt;          // halt a TLP packet from external input
input   [(NVC*3)-1:0]               bridge_trgt1_radm_pkt_halt;   // Halt for order queue to select in packet unit from the bridge tracker
input   [(NVC*3)-1:0]               trgt_lut_trgt1_radm_pkt_halt; // Halt for order queue to select in packet unit from the xadm.trgt_lut tracker
input   [NVC*3-1:0]                 trgt0_radm_halt;
// Posted.

output                              sb_init_done;

// Credit return output signals.
output  [NVC-1:0]                   radm_rtlh_ph_ca;
output  [NVC-1:0]                   radm_rtlh_pd_ca;
output  [NVC-1:0]                   radm_rtlh_nph_ca;
output  [NVC-1:0]                   radm_rtlh_npd_ca;
output  [NVC-1:0]                   radm_rtlh_cplh_ca;
output  [NVC-1:0]                   radm_rtlh_cpld_ca;
output                              radm_rtlh_crd_pending;      // credit return pending indication
wire                                radm_rtlh_crd_pending;

output  [NVC-1:0]                   radm_qoverflow;             // per VC indication for queue overflow
output  [NVC-1:0]                   radm_q_not_empty;           // per VC indication that queues aren't empty

output  [(NVC*3)-1:0]               radm_grant_tlp_type;        // A vector to indicate which type&VC has been granted for the next read out of receive queue
output  [NVC-1:0]                   radm_pend_cpl_so;           // A vector to indicate which VCs have strongly ordered completions pending
output  [NVC-1:0]                   radm_q_cpl_not_empty;       // A vector to indicate which VCs have CPL's stored in the buffer
output                              radm_parerr;
output                              radm_trgt0_pending;         // TLP enroute from RADM prevent DBI access

// target0 interface designed for internal local bus module
output  [TRGT_DATA_WD-1:0]          radm_trgt0_data;            // trgt0 request TLP data
output  [TRGT_HDR_WD-1:0]           radm_trgt0_hdr;             // trgt0 request TLP hdr
output  [NW-1:0]                    radm_trgt0_dwen;            // trgt0 request TLP data with dword enable of the data bus
output                              radm_trgt0_dv;              // trgt0 TLP data valid
output                              radm_trgt0_hv;              // trgt0 TLP hdr valid
output                              radm_trgt0_eot;             // trgt0 TLP end of TLP
output                              radm_trgt0_abort;           // trgt0 or of TLP & DLLP abort
output                              radm_trgt0_ecrc_err;        // trgt0 TLP with ECRC error

// target1 interface designed for application to receive the TLP
output  [TRGT_DATA_WD-1:0]          radm_trgt1_data;            // trgt1 request TLP data
output  [TRGT_HDR_WD-1:0]           radm_trgt1_hdr;             // trgt1 request TLP hdr
output  [NW-1:0]                    radm_trgt1_dwen;            // trgt1 request TLP data with dword enable of the data bus
output                              radm_trgt1_dv;              // trgt1 TLP data valid
output                              radm_trgt1_hv;              // trgt1 TLP hdr valid
output                              radm_trgt1_eot;             // trgt1 TLP end of TLP
output                              radm_trgt1_tlp_abort;       // trgt1 TLP abort
output                              radm_trgt1_dllp_abort;      // trgt1 DLLP abort
output                              radm_trgt1_ecrc_err;        // trgt1 TLP with ECRC error
output  [2:0]                       radm_trgt1_vc_num;          // trgt1 VC num
// bypass interface designed for TLP that is configured to bypass the queue
output  [TRGT_DATA_WD-1:0]          radm_bypass_data;           // bypass request TLP data
output  [NHQ*RADM_P_HWD-1:0]        radm_bypass_hdr;            // bypass request TLP hdr
output  [NW-1:0]                    radm_bypass_dwen;           // bypass request TLP data with dword enable of the data bus
output  [NHQ-1:0]                   radm_bypass_dv;             // bypass TLP data valid
output  [NHQ-1:0]                   radm_bypass_hv;             // bypass TLP hdr valid
output  [NHQ-1:0]                   radm_bypass_eot;            // bypass TLP end of TLP
output  [NHQ-1:0]                   radm_bypass_dllp_abort;     // bypass TLP abort
output  [NHQ-1:0]                   radm_bypass_tlp_abort;      // bypass DLLP abort
output  [NHQ-1:0]                   radm_bypass_ecrc_err;       // bypass TLP with ECRC error


// For the effort of bring RAM outside of the hiarch.
// Beneath are grouped inputs and outputs just for RAM
input   [NHQ*RADM_SBUF_HDRQ_WD-1:0] hdrq_dataout;
input   [NHQ-1:0]                     hdrq_parerr;
output  [NHQ-1:0]                     hdrq_par_chk_val;
output  [NHQ-1:0]                     hdrq_parerr_out;
output  [NHQ*(RADM_SBUF_HDRQ_PW)-1:0] hdrq_addra;
output  [NHQ*(RADM_SBUF_HDRQ_PW)-1:0] hdrq_addrb;
output  [NHQ*(RADM_SBUF_HDRQ_WD)-1:0] hdrq_datain;
output  [NHQ-1:0]                     hdrq_ena;
output  [NHQ-1:0]                     hdrq_enb;
output  [NHQ-1:0]                     hdrq_wea;
input   [NDQ*RADM_SBUF_DATAQ_RAM_WD-1:0] dataq_dataout;
input   [NDQ-1:0]                     dataq_parerr;
output  [NDQ-1:0]                     dataq_par_chk_val;
output  [NDQ-1:0]                     dataq_parerr_out;
output  [NDQ*(RADM_SBUF_DATAQ_PW)-1:0] dataq_addra;
output  [NDQ*(RADM_SBUF_DATAQ_PW)-1:0] dataq_addrb;
output  [NDQ*(RADM_SBUF_DATAQ_RAM_WD)-1:0]  dataq_datain;
output  [NDQ-1:0]                     dataq_ena;
output  [NDQ-1:0]                     dataq_enb;
output  [NDQ-1:0]                     dataq_wea;

// -------------------------------------------------------------
// Local parameters
// -------------------------------------------------------------
  // Inq to Order Mgr Interface
  //{hdrq_wr: keep, type, vc, relax_ordr, 4trgt0, 4tlp_abort, dataq_wr: keep}
  localparam INQ_ORDR_MGR_INTF_WD = NHQ + NHQ*3 + NHQ*3 + NHQ + NHQ + NHQ
                                    + NDQ;

  // {hdrq: wea, ena, addra, datain, dataq: wea, ena, addra, datain}
  localparam RAM_WR_INTF_WD = NHQ*2
                              + NHQ*(RADM_SBUF_HDRQ_PW) 
                              + NHQ*(RADM_SBUF_HDRQ_WD)
                              + NDQ*2
                              + NDQ*(RADM_SBUF_DATAQ_PW)
                              + NDQ*(RADM_SBUF_DATAQ_RAM_WD);

  // { hdrq: addrb, enb, dataq: addrb, enb}
  localparam RAM_RD_CTL_INTF_WD = NHQ*(RADM_SBUF_HDRQ_PW) 
                                      + NHQ
                                      + NDQ*(RADM_SBUF_DATAQ_PW)
                                      + NDQ
                                      ;

// -------------------------------------------------------------
// Internal Signals.
// -------------------------------------------------------------
wire    [NUM_SEGMENTS-1:0]          hdrq_empty;
wire    [NUM_SEGMENTS-1:0]          hdrq_empty_p_1;
wire    [NUM_SEGMENTS-1:0]          hdrq_full;
wire    [NUM_SEGMENTS-1:0]          hdrq_full_m_1;
wire    [NUM_SEGMENTS-1:0]          hdrq_seg_pkt_avail;

wire    [NHQ-1:0]                      hdrq_enb;
wire    [NHQ*(RADM_SBUF_HDRQ_PW)-1:0]  hdrq_addrb;
wire    [NDQ-1:0]                      dataq_enb;
wire    [NDQ*(RADM_SBUF_DATAQ_PW)-1:0] dataq_addrb;

wire    [NUM_SEGMENTS-1:0]          dataq_empty;
wire    [NUM_SEGMENTS-1:0]          dataq_empty_p_1;

wire    [NUM_SEGMENTS-1:0]          dataq_full;
wire    [NUM_SEGMENTS-1:0]          dataq_full_m_1;
wire    [NUM_SEGMENTS-1:0]          dataq_seg_pkt_avail;

wire                                trgt1_in_progress;          // Indicates to the order mgr that the target 1 interface is active
  // Inq Mgr Header Write Interface
  wire [NHQ-1:0]                     hdrq_wr_keep;
  wire [NHQ-1:0]                     hdrq_wr_4trgt0;
  wire [NHQ-1:0]                     hdrq_wr_4tlp_abort;
  wire [NHQ-1:0]                     hdrq_wr_relax_ordr;
  wire [NHQ*3-1:0]                   hdrq_wr_type;
  wire [NHQ*3-1:0]                   hdrq_wr_vc;
  wire [NHQ-1:0]                     hdrq_wr_en;
  wire [NHQ-1:0]                     hdrq_wr_start;
  wire [NHQ*RADM_SBUF_HDRQ_WD-1:0]   hdrq_wr_data;
  wire [NHQ*SEG_WIDTH-1:0]           hdrq_wr_seg_num;
  wire                               hdrq_rd_en;
  wire [SEG_WIDTH-1:0]               hdrq_rd_seg_num;
  wire [NHQ*RADM_SBUF_HDRQ_WD-1:0]   hdrq_rd_data;

  // Inq Mgr Data Q Interface
  wire  [NDQ-1:0]                     dataq_wr_en;
  wire  [NDQ-1:0]                     dataq_wr_start;
  wire  [NDQ-1:0]                     dataq_wr_keep;
  wire  [NDQ-1:0]                     dataq_wr_drop;
  wire  [NDQ*SEG_WIDTH-1:0]           dataq_wr_seg_num;
  wire  [NDQ*RADM_SBUF_DATAQ_WD-1 :0] dataq_wr_data;
  wire                                dataq_rd_en;
  wire    [NDQ*RADM_SBUF_DATAQ_CTRLQ_WD-1:0] dctlq_rdata;
  wire  [(NDQ*RADM_SBUF_DATAQ_WD)-1 :0] dataq_rd_data;

wire                                dataq_rd_half_en;
wire  [SEG_WIDTH-1:0]               dataq_rd_seg_num;

  // Order Q Mgr Read Request Interface
wire                                req_ackd;
wire    [SEG_WIDTH -1:0]            req_rd_segnum;
wire                                req_rd;
wire                                req_tlp_w_pyld;
wire                                req_rd_4trgt0;
wire                                outq_trgt0_ack;         // trgt0 request received, allow another to be selected in order_q.

wire    [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0]     cfg_hq_depths;  // Indicates the depth of the header queues per type per vc
wire    [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]    cfg_dq_depths;  // Indicates the depth of the data queues per type per vc
wire                                radm_trgt0_pending;         // TLP enroute from RADM
wire    [NVC-1:0]                   radm_trgt1_ack_tlp_np;      // A vector to indicate which per VC NP type has been acknowledged by the receive queue VC arbiter.
wire    [NVC-1:0]                   radm_trgt1_ack_tlp_p;       // A vector to indicate which per VC P type has been acknowledged by the receive queue VC arbiter.

`ifndef SYNTHESIS
  wire                              hdrq_pdly1_rd_en;
  wire [SEG_WIDTH-1:0]              hdrq_pdly1_rd_seg_num;
  wire [RADM_SBUF_HDRQ_WD-1:0]      hdrq_pdly1_rd_data;
`endif

  // SBC Header Q Interface
  wire [NHQ-1:0]                     sb_hdrq_wea_n;
  wire [NHQ-1:0]                     sb_hdrq_wea;
  wire [NHQ-1:0]                     sb_hdrq_ena;
  wire [NHQ*(RADM_SBUF_HDRQ_PW)-1:0] sb_hdrq_addra;
  wire [NHQ*(RADM_SBUF_HDRQ_WD)-1:0] sb_hdrq_datain;

  wire [NHQ-1:0]                      sb_hdrq_enb_n;
  wire [NHQ-1:0]                      sb_hdrq_enb;
  wire [NHQ*(RADM_SBUF_HDRQ_PW)-1:0]  sb_hdrq_addrb;
  wire [NHQ*(RADM_SBUF_HDRQ_PW)-1:0]  sb_hdrq_raddr;

  // SBC Data Q Interface
  wire [NDQ-1:0]                          sb_dataq_wea_n;
  wire [NDQ-1:0]                          sb_dataq_wea;
  wire [NDQ-1:0]                          sb_dataq_ena;
//wire [NDQ-1:0] dataq_enb;
  wire [NDQ*(RADM_SBUF_DATAQ_PW)-1:0]     sb_dataq_addra;
  wire [NDQ*(RADM_SBUF_DATAQ_WD)-1:0]     sb_dataq_wdata;
  reg  [NDQ*(RADM_SBUF_DATAQ_RAM_WD)-1:0] sb_dataq_datain;
  reg  [NDQ*RADM_SBUF_DATAQ_CTRLQ_WD-1:0] sb_dataq_ctl_wdata;

  wire [NDQ-1:0]                          sb_dataq_enb_n;
  wire [NDQ-1:0]                          sb_dataq_enb;
  wire [NDQ*(RADM_SBUF_DATAQ_PW)-1:0]     sb_dataq_addrb;
  reg  [NDQ*RADM_SBUF_DATAQ_WD-1:0]       sb_dataq_rdata;


  // Order manager pipe delayed interface
  wire [INQ_ORDR_MGR_INTF_WD-1:0]   s_inq_ordr_mgr_intf;
  wire [INQ_ORDR_MGR_INTF_WD-1:0]   pdly0_inq_ordr_mgr_intf;
  wire [NHQ-1:0]                    pdly0_hdrq_wr_keep;
  wire [NHQ*3-1:0]                  pdly0_hdrq_wr_type;
  wire [NHQ*3-1:0]                  pdly0_hdrq_wr_vc;
  wire [NHQ-1:0]                    pdly0_hdrq_wr_relax_ordr;
  wire [NHQ-1:0]                    pdly0_hdrq_wr_4trgt0;
  wire [NHQ-1:0]                    pdly0_hdrq_wr_4tlp_abort;
  wire [NDQ-1:0]                    pdly0_dataq_wr_keep;

  // SBC to RAM Wr Control Interface
  wire [RAM_WR_INTF_WD-1:0]         s_ram_wr_intf;
  wire [RAM_WR_INTF_WD-1:0]         pdly1_ram_wr_intf;

  // SBC to RAM Rd Control Interface
  wire [RAM_RD_CTL_INTF_WD-1:0]     s_ram_rdctl_intf; 
  wire [RAM_RD_CTL_INTF_WD-1:0]     pdly2_ram_rdctl_intf; 

  wire [(NVC*3)-1:0]                bypass_mode_vec;
  wire [(NVC*3)-1:0]                cutthru_mode_vec;
  wire [(NVC*3)-1:0]                storfwd_mode_vec;
// ---------------------------------------------------------------------
// Internal Design
// ---------------------------------------------------------------------
wire   [(NVC*3)-1:0]                radm_pkt_halt; 
assign radm_pkt_halt =  trgt1_radm_pkt_halt | bridge_trgt1_radm_pkt_halt | trgt_lut_trgt1_radm_pkt_halt;

wire                                radm_inq_parerr;
assign radm_parerr = radm_inq_parerr;






assign bypass_mode_vec  = Build_mode_vec(cfg_radm_q_mode, `CX_QMODE_BYPASS);
assign cutthru_mode_vec = Build_mode_vec(cfg_radm_q_mode, `CX_QMODE_CUT_THROUGH);
assign storfwd_mode_vec = Build_mode_vec(cfg_radm_q_mode, `CX_QMODE_STORE_N_FWD);

// *_par_chk_val signals are connected to the outq_mgr signals instead to the sbc as before
wire [NHQ-1:0]                   hdrq_par_chk_val_sbc;
wire [NDQ-1:0]                   dataq_par_chk_val_sbc;
wire [NHQ-1:0]                   hdrq_par_chk_val_outq_mgr;
wire [NDQ-1:0]                   dataq_par_chk_val_outq_mgr;
assign hdrq_par_chk_val  = hdrq_par_chk_val_outq_mgr;
assign dataq_par_chk_val = dataq_par_chk_val_outq_mgr;


radm_inq_mgr

  #(
  .INST                              (INST)
  ,.NW                               (NW)
  ,.NDQ                              (NDQ)
   ) 
   u_radm_inq_mgr
   (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .bypass_mode_vec                (bypass_mode_vec),
    .cutthru_mode_vec               (cutthru_mode_vec),
    .cfg_filter_rule_mask           (cfg_filter_rule_mask),

    //   Inputs from the Wire side.
    .flt_q_hv                       (flt_q_hv),
    .flt_q_dv                       (flt_q_dv),
    .flt_q_header                   (flt_q_header),
    .flt_q_data                     (flt_q_data),
    .flt_q_dwen                     (flt_q_dwen),
    .flt_q_eot                      (flt_q_eot),
    .flt_q_dllp_abort               (flt_q_dllp_abort),
    .flt_q_tlp_abort                (flt_q_tlp_abort),
    .flt_q_ecrc_err                 (flt_q_ecrc_err),
    .flt_q_tlp_type                 (flt_q_tlp_type),
    .flt_q_seg_num                  (flt_q_seg_num),
    .flt_q_vc                       (flt_q_vc),
    .flt_q_parerr                   (flt_q_parerr),
    .hdrq_seg_pkt_avail             (hdrq_seg_pkt_avail),
    .hdrq_full                      (hdrq_full),
    .hdrq_full_m_1                  (hdrq_full_m_1),

    .dataq_full_m_1                 (dataq_full_m_1),
    .dataq_full                     (dataq_full),

    // Push side
    .hdrq_wr_en                     (hdrq_wr_en),
    .hdrq_wr_start                  (hdrq_wr_start),
    .hdrq_wr_keep                   (hdrq_wr_keep),

    
    .hdrq_wr_seg_num                (hdrq_wr_seg_num),
    .hdrq_wr_data                   (hdrq_wr_data),
    .hdrq_wr_type                   (hdrq_wr_type),
    .hdrq_wr_vc                     (hdrq_wr_vc),
    .hdrq_wr_relax_ordr             (hdrq_wr_relax_ordr),
    .hdrq_wr_4trgt0                 (hdrq_wr_4trgt0),
    .hdrq_wr_4tlp_abort             (hdrq_wr_4tlp_abort),

    // Push side
    .dataq_wr_start                 (dataq_wr_start),
    .dataq_wr_en                    (dataq_wr_en),
    .dataq_wr_keep                  (dataq_wr_keep),
    .dataq_wr_drop                  (dataq_wr_drop),

    
    .dataq_wr_seg_num               (dataq_wr_seg_num),
    .dataq_wr_data                  (dataq_wr_data),

    .radm_qoverflow                 (radm_qoverflow),
    .radm_inq_parerr                (radm_inq_parerr),

    // BYPASS interface
    .radm_bypass_ecrc_err           (radm_bypass_ecrc_err),
    .radm_bypass_tlp_abort          (radm_bypass_tlp_abort),
    .radm_bypass_dllp_abort         (radm_bypass_dllp_abort),
    .radm_bypass_hv                 (radm_bypass_hv),
    .radm_bypass_dv                 (radm_bypass_dv),
    .radm_bypass_eot                (radm_bypass_eot),
    .radm_bypass_dwen               (radm_bypass_dwen),
    .radm_bypass_data               (radm_bypass_data),
    .radm_bypass_hdr                (radm_bypass_hdr)
);

  radm_order_mgr
  
  #(
  .INST                              (INST)
  ,.NDQ                              (NDQ)
   ) 
   u_radm_order_mgr
   (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .bypass_mode_vec                (bypass_mode_vec),
    .cutthru_mode_vec               (cutthru_mode_vec),
    .storfwd_mode_vec               (storfwd_mode_vec),

    .cfg_radm_order_rule            (cfg_radm_order_rule),
    .cfg_order_rule_ctrl            (cfg_order_rule_ctrl),
    .cfg_radm_strict_vc_prior       (cfg_radm_strict_vc_prior),
    .trgt0_radm_halt                (trgt0_radm_halt),
    .outq_trgt0_ack                 (outq_trgt0_ack),
    .trgt1_radm_halt                (radm_pkt_halt),
    .hdrq_wr_keep                   (pdly0_hdrq_wr_keep),
    .hdrq_wr_type                   (pdly0_hdrq_wr_type),
    .hdrq_wr_vc                     (pdly0_hdrq_wr_vc),
    .hdrq_wr_relax_ordr             (pdly0_hdrq_wr_relax_ordr),
    .hdrq_wr_4trgt0                 (pdly0_hdrq_wr_4trgt0),
    .hdrq_wr_4tlp_abort             (pdly0_hdrq_wr_4tlp_abort),

    .dataq_wr_keep                  (pdly0_dataq_wr_keep),

    .req_ackd                       (req_ackd),

    .req_rd_segnum                  (req_rd_segnum),
    .req_rd                         (req_rd),
    .req_rd_4trgt0                  (req_rd_4trgt0),
    .req_tlp_w_pyld                 (req_tlp_w_pyld),

    .radm_grant_tlp_type            (radm_grant_tlp_type),
    .radm_trgt1_ack_tlp_np          (radm_trgt1_ack_tlp_np),
    .radm_trgt1_ack_tlp_p           (radm_trgt1_ack_tlp_p),
    .radm_pend_cpl_so               (radm_pend_cpl_so),
    .radm_trgt0_pending             (radm_trgt0_pending)
   );

  assign hdrq_parerr_out = 0;
  assign dataq_parerr_out = 0;

  radm_outq_mgr
  
  #(.NW                             (NW)
  ,.NDQ                             (NDQ)
  ,.RADM_SBUF_DATAQ_CTRLQ_WD        (RADM_SBUF_DATAQ_CTRLQ_WD)           
  ) 
  u_radm_outq_mgr
  (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_radm_q_mode                (cfg_radm_q_mode),
    .cutthru_mode_vec               (cutthru_mode_vec),
    .trgt0_outq_halt                (1'b0),
    .trgt1_outq_halt                (trgt1_radm_halt),
    .req_ackd                       (req_ackd),
    .req_rd                         (req_rd),
    .req_rd_4trgt0                  (req_rd_4trgt0),
    .req_rd_segnum                  (req_rd_segnum),
    .req_tlp_w_pyld                 (req_tlp_w_pyld),
    .hdrq_rd_en                     (hdrq_rd_en),
    .hdrq_rd_seg_num                (hdrq_rd_seg_num),
    .hdrq_rd_data                   (hdrq_rd_data),
`ifndef SYNTHESIS
    .hdrq_pdly1_rd_en               (hdrq_pdly1_rd_en),
    .hdrq_pdly1_rd_seg_num          (hdrq_pdly1_rd_seg_num),
    .hdrq_pdly1_rd_data             (hdrq_pdly1_rd_data),
`endif
    .hdrq_par_chk_val               (hdrq_par_chk_val_outq_mgr),
    .dctlq_rdata                    (dctlq_rdata),
    .dataq_rd_en                    (dataq_rd_en),
    .dataq_rd_seg_num               (dataq_rd_seg_num),
    .dataq_rd_data                  (dataq_rd_data),
    .dataq_par_chk_val              (dataq_par_chk_val_outq_mgr),

    .hdrq_empty                     (hdrq_empty),

    .dataq_empty                    (dataq_empty),

    .radm_trgt0_data                (radm_trgt0_data),
    .radm_trgt0_hdr                 (radm_trgt0_hdr),
    .radm_trgt0_dwen                (radm_trgt0_dwen),
    .radm_trgt0_dv                  (radm_trgt0_dv),
    .radm_trgt0_hv                  (radm_trgt0_hv),
    .radm_trgt0_eot                 (radm_trgt0_eot),
    .radm_trgt0_abort               (radm_trgt0_abort),
    .radm_trgt0_ecrc_err            (radm_trgt0_ecrc_err),
    .outq_trgt0_ack                 (outq_trgt0_ack),

    .radm_trgt1_data                (radm_trgt1_data),
    .radm_trgt1_hdr                 (radm_trgt1_hdr),
    .radm_trgt1_dwen                (radm_trgt1_dwen),
    .radm_trgt1_dv                  (radm_trgt1_dv),
    .radm_trgt1_hv                  (radm_trgt1_hv),
    .radm_trgt1_eot                 (radm_trgt1_eot),
    .radm_trgt1_tlp_abort           (radm_trgt1_tlp_abort),
    .radm_trgt1_dllp_abort          (radm_trgt1_dllp_abort),
    .radm_trgt1_ecrc_err            (radm_trgt1_ecrc_err),
    .radm_trgt1_vc_num              (radm_trgt1_vc_num),
    .trgt1_in_progress              (trgt1_in_progress),


    .radm_q_not_empty               (radm_q_not_empty),
    .radm_q_cpl_not_empty           (radm_q_cpl_not_empty),
    // Credit return interface
    .radm_rtlh_ph_ca                (radm_rtlh_ph_ca),
    .radm_rtlh_pd_ca                (radm_rtlh_pd_ca),
    .radm_rtlh_nph_ca               (radm_rtlh_nph_ca),
    .radm_rtlh_npd_ca               (radm_rtlh_npd_ca),
    .radm_rtlh_cplh_ca              (radm_rtlh_cplh_ca),
    .radm_rtlh_cpld_ca              (radm_rtlh_cpld_ca)
    );

  // The ca signals are used to increment the FC credit counters in the RTLH therefore
  // the RADM clock should not be gated while these signals are asserted to insure
  // the FC counters increment as intended
  assign radm_rtlh_crd_pending = ((|radm_rtlh_ph_ca) || (|radm_rtlh_pd_ca) || (|radm_rtlh_nph_ca)
                                  || (|radm_rtlh_npd_ca) || (|radm_rtlh_cplh_ca) || (|radm_rtlh_cpld_ca));
  assign sb_hdrq_enb = ~sb_hdrq_enb_n;
  assign sb_hdrq_wea = ~sb_hdrq_wea_n;
  assign sb_hdrq_ena = sb_hdrq_wea;



reg core_rst_n_d1;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        core_rst_n_d1    <= #TP 1'b0;
    end
    else begin
        core_rst_n_d1    <= #TP 1'b1;
    end

reg core_rst_n_d2;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        core_rst_n_d2    <= #TP 1'b0;
    end
    else begin
        core_rst_n_d2    <= #TP core_rst_n_d1;
    end

wire reset_p;       // used to start the initialization of the segment buffer controllers

assign reset_p = core_rst_n_d1 & !core_rst_n_d2;

// Segment calculations
wire    [SEG_WIDTH :0]                    num_segments;
wire    [(NVC*3*RADM_SBUF_HDRQ_PW)-1:0]    hdr_q_depths;
wire    [(NVC*3*RADM_SBUF_DATAQ_PW)-1:0]   data_q_depths;

assign num_segments     = NUM_SEGMENTS;

assign hdr_q_depths     = Build_hdr_depth_vec(bypass_mode_vec, cfg_hq_depths);
assign data_q_depths    = Build_data_depth_vec(bypass_mode_vec, cfg_dq_depths);

wire sb_hdr_init_done;
wire sb_data_init_done; 
assign sb_init_done = sb_hdr_init_done && sb_data_init_done;

`define SBC DW_sbc

`SBC
  #(
    .SEGS                            (NUM_SEGMENTS)
    ,.SEG_W                          (SEG_WIDTH)
    ,.RAM_W                          (RADM_SBUF_HDRQ_WD)
    ,.RAM_WEC                        (RADM_SBUF_HDRQ_WD)
    ,.RAM_AW                         (RADM_SBUF_HDRQ_PW)
    ,.GEN_STARTEND_ADDRS             (GENERATE_STARTEND_ADDRS)
    ,.HOLD_RADDR                     (HOLD_RADDR)
    ,.GEN_FULL_M_2                   (0)
   )
u_hdr_DW_sbc (
    .clk                            (core_clk),
    .rst_n                          (core_rst_n),
    .srst_n                         (1'b1),

    // Push side
    .sb_push_i                      (hdrq_wr_en),
    .sb_push_start_i                (hdrq_wr_start),
    .sb_push_keep_i                 (hdrq_wr_keep),
    .sb_push_drop_i                 ({NHQ{1'b0}}),             // not needed for header

              
    .sb_push_seg_i                  (hdrq_wr_seg_num),
    .sb_push_data_i                 (hdrq_wr_data),
    .sb_reset_push_ptr              (1'b0),
    .sb_reset_push_seg_i            ({SEG_WIDTH{1'b0}}),

    // Pop side
    .sb_pop_i                       (hdrq_rd_en),
    .sb_pop_seg_i                   (hdrq_rd_seg_num),
    .sb_pop_look_i                  (1'b0),
    .sb_pop_data_o                  (hdrq_rd_data),
    .sb_reset_pop_ptr               (1'b0),
    .sb_reset_pop_seg_i             ({SEG_WIDTH{1'b0}}),

    // Segment size interface
    .sb_init_i                      (reset_p),
    .sb_init_seg_sizes_i            (hdr_q_depths),
    .sb_init_done_o                 (sb_hdr_init_done),
    .sb_init_num_segs_i             (num_segments),

    .sb_seg_start_i                 ({(NUM_SEGMENTS*RADM_SBUF_HDRQ_PW){1'b0}}),
    .sb_seg_end_i                   ({(NUM_SEGMENTS*RADM_SBUF_HDRQ_PW){1'b0}}),

    // Info interface
    .sb_empty_o                     (hdrq_empty),
    .sb_empty_p_1_o                 (hdrq_empty_p_1),
    .sb_full_o                      (hdrq_full),
    .sb_full_m_1_o                  (hdrq_full_m_1),
    .sb_full_m_2_o                  (),
    .sb_seg_pkt_avail_o             (hdrq_seg_pkt_avail),


    // Memory interface
    .sb_waddr_o                     (sb_hdrq_addra),
    .sb_wen_n_o                     (sb_hdrq_wea_n),
    .sb_wdata_o                     (sb_hdrq_datain),

    .sb_raddr_o                     (sb_hdrq_addrb),
    .sb_ren_n_o                     (sb_hdrq_enb_n),

    .sb_par_chk_val_o               (hdrq_par_chk_val_sbc),

    .sb_rdata_i                     (hdrq_dataout)

);

// -------------------------------------------------------------------------------------
// Data Queue  
// -------------------------------------------------------------------------------------
  assign sb_dataq_wea = ~sb_dataq_wea_n;
  assign sb_dataq_enb = ~sb_dataq_enb_n;
  assign sb_dataq_ena = sb_dataq_wea;

// The control bits from the dataq are stored internally in a register based
// RAM to improve timing. With large RAM access times reading these bits from
// the RAMs creates a critical path. To u_data_SW_sbc it appears as if it is
// accessing a single RAM, or in the case of 256 bit core two RAMS but we
// implement the control bits internally here

//`ifdef CX_RAS_EN
//localparam SBUF_RAM_PARBITS = `CX_RAM_DATA_PARBITS;
//`endif // CX_RAS_EN

always @(*) begin : p_dataq_dataout
    integer i;
    for(i = 0; i < NDQ; i = i + 1) begin : JoinRamAndCtrlQ
        sb_dataq_rdata[i*RADM_SBUF_DATAQ_WD +: RADM_SBUF_DATAQ_WD] =
            { 
              // protection code is calculated in inq_mgr setting the EOT field to 0 so here we restore the same word that has been
              // used to calculate the protection code - If RASDP is not used this bit is not used
              {RADM_SBUF_DATAQ_CTRLQ_WD{1'b0}},  
              dataq_dataout[i*RADM_SBUF_DATAQ_RAM_WD +: (RADM_SBUF_DATAQ_NOPROT_WD - 1)]
             };

    end
end

// Extract the RAM write data
always @(*) begin : p_dataq_datain
    integer i;
    for(i = 0; i < NDQ; i = i + 1) begin
        sb_dataq_datain[i*RADM_SBUF_DATAQ_RAM_WD +: RADM_SBUF_DATAQ_RAM_WD] = {
            sb_dataq_wdata[i*RADM_SBUF_DATAQ_WD +: (RADM_SBUF_DATAQ_NOPROT_WD-1)] };

        sb_dataq_ctl_wdata[i*RADM_SBUF_DATAQ_CTRLQ_WD +: RADM_SBUF_DATAQ_CTRLQ_WD] =
            sb_dataq_wdata[i*RADM_SBUF_DATAQ_WD + RADM_SBUF_DATAQ_NOPROT_WD - 1  +: RADM_SBUF_DATAQ_CTRLQ_WD];
    end
end


      // Control queue 
      DWC_pcie_ctl_bcm57
       
      #(
      .DATA_WIDTH                        (RADM_SBUF_DATAQ_CTRLQ_WD)           
      ,.DEPTH                            (RADM_SBUF_DATAQ_DEPTH)           
      ,.ADDR_WIDTH                       (RADM_SBUF_DATAQ_PW)           
      ) 
      u_dctlq [NDQ-1:0]
      (
      .clk                               (core_clk)
      ,.rst_n                            (core_rst_n)
      ,.wr_n                             (sb_dataq_wea_n)
      ,.wr_addr                          (sb_dataq_addra)
      ,.data_in                          (sb_dataq_ctl_wdata)
      ,.rd_addr                          (sb_dataq_addrb)
      ,.data_out                         (dctlq_rdata)
      );




`SBC
  #(
    .SEGS                            (NUM_SEGMENTS)
    ,.SEG_W                          (SEG_WIDTH)
    ,.RAM_W                          (RADM_SBUF_DATAQ_WD)
    ,.RAM_WEC                        (RADM_SBUF_DATAQ_WD)
    ,.RAM_AW                         (RADM_SBUF_DATAQ_PW)
    ,.GEN_STARTEND_ADDRS             (GENERATE_STARTEND_ADDRS)
    ,.HOLD_RADDR                     (HOLD_RADDR)
    ,.GEN_FULL_M_2                   (0)
   )

u_data_DW_sbc (
    .clk                            (core_clk),
    .rst_n                          (core_rst_n),
    .srst_n                         (1'b1),


    // Push side
    .sb_push_i                      (dataq_wr_en),
    .sb_push_start_i                (dataq_wr_start),
    .sb_push_keep_i                 (dataq_wr_keep),
    .sb_push_drop_i                 (dataq_wr_drop),
    .sb_push_seg_i                  (dataq_wr_seg_num),
    .sb_push_data_i                 (dataq_wr_data),
    .sb_reset_push_ptr              (1'b0),
    .sb_reset_push_seg_i            ({SEG_WIDTH{1'b0}}),

    // Pop side
    .sb_pop_i                       (dataq_rd_en),
    .sb_pop_seg_i                   (dataq_rd_seg_num),
    .sb_pop_look_i                  (1'b0),
    .sb_pop_data_o                  (dataq_rd_data),
    .sb_reset_pop_ptr               (1'b0),
    .sb_reset_pop_seg_i             ({SEG_WIDTH{1'b0}}),

    // Segment size interface
    .sb_init_i                      (reset_p),
    .sb_init_seg_sizes_i            (data_q_depths),
    .sb_init_done_o                 (sb_data_init_done),
    .sb_init_num_segs_i             (num_segments),

    .sb_seg_start_i                 ({(NUM_SEGMENTS*RADM_SBUF_DATAQ_PW){1'b0}}),
    .sb_seg_end_i                   ({(NUM_SEGMENTS*RADM_SBUF_DATAQ_PW){1'b0}}),

    // Info interface
    .sb_empty_o                     (dataq_empty),
    .sb_empty_p_1_o                 (dataq_empty_p_1),
    .sb_full_o                      (dataq_full),
    .sb_full_m_1_o                  (dataq_full_m_1),
    .sb_full_m_2_o                  (),
    .sb_seg_pkt_avail_o             (dataq_seg_pkt_avail),


    // Memory interface
    .sb_waddr_o                     (sb_dataq_addra),
    .sb_wen_n_o                     (sb_dataq_wea_n),
    .sb_wdata_o                     (sb_dataq_wdata),

    .sb_raddr_o                     (sb_dataq_addrb),
    .sb_ren_n_o                     (sb_dataq_enb_n),

    .sb_par_chk_val_o               (dataq_par_chk_val_sbc),

    .sb_rdata_i                     (sb_dataq_rdata)

);
 
 assign ras_err_inj_done_radm_q = 1'b0;


  // -------------------------------------------------------------------------------------
  // Configurable Data/Hdr Q RAM Pipeline Stages
  // -------------------------------------------------------------------------------------
  // Inq to Order Mgr Interface
  assign s_inq_ordr_mgr_intf = { hdrq_wr_keep, hdrq_wr_type, hdrq_wr_vc, hdrq_wr_relax_ordr,
                                 hdrq_wr_4trgt0, hdrq_wr_4tlp_abort,
                                 dataq_wr_keep}; 

  delay_n
   
  #(RADM_RAM_WR_REGOUT,
    INQ_ORDR_MGR_INTF_WD
   ) 
   u_pdly0
   (.clk        (core_clk)
   ,.rst_n      (core_rst_n)
   ,.clear      (1'b0)
   ,.din        (s_inq_ordr_mgr_intf)
   ,.dout       (pdly0_inq_ordr_mgr_intf)
   );

  assign { pdly0_hdrq_wr_keep
           ,pdly0_hdrq_wr_type
           ,pdly0_hdrq_wr_vc
           ,pdly0_hdrq_wr_relax_ordr
           ,pdly0_hdrq_wr_4trgt0
           ,pdly0_hdrq_wr_4tlp_abort
           ,pdly0_dataq_wr_keep
         } = pdly0_inq_ordr_mgr_intf;


  // SBC to RAM Wr Control Interface
  assign s_ram_wr_intf = { sb_hdrq_wea, sb_hdrq_ena, sb_hdrq_addra, sb_hdrq_datain,
                           sb_dataq_wea, sb_dataq_ena, sb_dataq_addra, sb_dataq_datain};   

  delay_n
   
  #(RADM_RAM_WR_REGOUT,
    RAM_WR_INTF_WD
   ) 
   u_pdly1
   (.clk        (core_clk)
   ,.rst_n      (core_rst_n)
   ,.clear      (1'b0)
   ,.din        (s_ram_wr_intf)
   ,.dout       (pdly1_ram_wr_intf)
   );

   assign { hdrq_wea
            ,hdrq_ena
            ,hdrq_addra
            ,hdrq_datain
            ,dataq_wea
            ,dataq_ena
            ,dataq_addra
            ,dataq_datain
          } = pdly1_ram_wr_intf;


  // SBC to RAM Rd Control Interface
  assign s_ram_rdctl_intf = { sb_hdrq_addrb, sb_hdrq_enb, sb_dataq_addrb, sb_dataq_enb};

  delay_n
   
  #(RADM_RAM_RD_CTL_REGOUT,
    RAM_RD_CTL_INTF_WD
   ) 
   u_pdly2
   (.clk        (core_clk)
   ,.rst_n      (core_rst_n)
   ,.clear      (1'b0)
   ,.din        (s_ram_rdctl_intf)
   ,.dout       (pdly2_ram_rdctl_intf)
   );

  assign { hdrq_addrb, hdrq_enb, dataq_addrb, dataq_enb} = pdly2_ram_rdctl_intf;


// Selects the specified mode bit for each type of each vc and returns them in a vector
function automatic  [(NVC*3)-1:0]   Build_mode_vec;
input   [(NVC*9)-1:0]       cfg_radm_q_mode;
input   [1:0]               mode;

integer i;
begin
    Build_mode_vec = 0;
    for (i=0; i<NVC*3; i=i+1) begin
        if      (mode == 2'h0) Build_mode_vec[i] = cfg_radm_q_mode[(i*3)+0];
        else if (mode == 2'h1) Build_mode_vec[i] = cfg_radm_q_mode[(i*3)+1];
        else                   Build_mode_vec[i] = cfg_radm_q_mode[(i*3)+2];
    end
end
endfunction

// spyglass disable_block W489
// SMD: The last statement in a function does not assign to the function
// SJ: The variable seg_num is being used to index a vector and it needs to be incremented after the vector is indexed
// Position sensitive logic (seg_num).
// Creates a vector containing the depth for each non-bypassed Header segment
function automatic [(NVC*3*RADM_SBUF_HDRQ_PW)-1:0]    Build_hdr_depth_vec;
input   [(NVC*3)-1:0]       bypass_mode_vec;
input   [(NVC*3*RADM_SBUF_HDRQ_PW)-1:0]  cfg_hq_depths;      // Indicates the depth of the header queues per type per vc

integer vc;
integer q_type;
integer seg_num;
integer depth_bits;
begin
    seg_num = 0;
    Build_hdr_depth_vec = 0;
    for (vc=0; vc<NVC; vc=vc+1)
        for (q_type=0; q_type<3; q_type=q_type+1)
            begin
                for (depth_bits=0; depth_bits<RADM_SBUF_HDRQ_PW; depth_bits=depth_bits+1)
                    Build_hdr_depth_vec[(seg_num*RADM_SBUF_HDRQ_PW)+depth_bits]=cfg_hq_depths[((vc*3+q_type)*RADM_SBUF_HDRQ_PW)+depth_bits];
                seg_num = seg_num + 1;
            end
end
endfunction

// Creates a vector containing the depth for each non-bypassed Data segment
function automatic [(NVC*3*RADM_SBUF_DATAQ_PW)-1:0]    Build_data_depth_vec;
input   [(NVC*3)-1:0]       bypass_mode_vec;
input   [(NVC*3*RADM_SBUF_DATAQ_PW)-1:0]  cfg_dq_depths;      // Indicates the depth of the header queues per type per vc

integer vc;
integer q_type;
integer seg_num;
integer depth_bits;
begin
    seg_num = 0;
    Build_data_depth_vec = 0;
    for (vc=0; vc<NVC; vc=vc+1)
        for (q_type=0; q_type<3; q_type=q_type+1)
            begin
                for (depth_bits=0; depth_bits<RADM_SBUF_DATAQ_PW; depth_bits=depth_bits+1)
                    Build_data_depth_vec[(seg_num*RADM_SBUF_DATAQ_PW)+depth_bits]=cfg_dq_depths[((vc*3+q_type)*RADM_SBUF_DATAQ_PW)+depth_bits];
                seg_num = seg_num + 1;
            end
end
endfunction
// spyglass enable_block W489

`ifndef SYNTHESIS

//VCS coverage off
// -------------------------------------------------------------------------------------
// Extract SBC Data/Hdr Q Segment Status signals
// -------------------------------------------------------------------------------------
  wire        hdrq_seg_empty;
  wire        hdrq_seg_empty_p_1;
  wire        hdrq_seg_full;
  wire        hdrq_seg_full_m_1;
  wire        dataq_seg_empty;
  wire        dataq_seg_empty_p_1;
  wire        dataq_seg_full;
  wire        dataq_seg_full_m_1;

  assign hdrq_seg_empty      = hdrq_empty[hdrq_rd_seg_num];
  assign hdrq_seg_empty_p_1  = hdrq_empty_p_1[hdrq_rd_seg_num];
  assign hdrq_seg_full       = hdrq_full[hdrq_wr_seg_num];
  assign hdrq_seg_full_m_1   = hdrq_full_m_1[hdrq_wr_seg_num];

  assign dataq_seg_empty     = dataq_empty[dataq_rd_seg_num];
  
  assign dataq_seg_empty_p_1 = dataq_empty_p_1[dataq_rd_seg_num];
  assign dataq_seg_full      = dataq_full[dataq_wr_seg_num];
  assign dataq_seg_full_m_1  = dataq_full_m_1[dataq_wr_seg_num];

//VCS coverage on
`endif // SYNTHESIS

endmodule
