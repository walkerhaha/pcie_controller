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
// ---    $DateTime: 2020/02/06 04:21:30 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_outq_mgr.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module controles the out-queuing of a TLP to our segment buffer
// --- Its main functions are:
// ---    (1) Seg buffer pop logic control
// ---    (2) Calculating the credit returns
// ---
// ---
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module radm_outq_mgr
  (
    // Clocks and Resets
    core_clk,
    core_rst_n,

    // Configuration Interface
    cfg_radm_q_mode,
    cutthru_mode_vec,

    // Order Manager Request Interface
    req_rd,
    req_rd_4trgt0,
    req_rd_segnum,
    req_tlp_w_pyld,
    req_ackd,
    // Header Q Interface
    hdrq_rd_en,
    hdrq_rd_seg_num,
    hdrq_rd_data,
`ifndef SYNTHESIS
    hdrq_pdly1_rd_en,
    hdrq_pdly1_rd_seg_num,
    hdrq_pdly1_rd_data,
`endif
    hdrq_par_chk_val,
    hdrq_empty,

    // Data Control Q Interface
    dctlq_rdata,
    // Data Q Interface
    dataq_rd_en,
    dataq_rd_seg_num,
    dataq_rd_data,
    dataq_par_chk_val,
    dataq_empty,
    // TRGT0 interface
    radm_trgt0_data,
    radm_trgt0_hdr,
    radm_trgt0_dwen,
    radm_trgt0_dv,
    radm_trgt0_hv,
    radm_trgt0_eot,
    radm_trgt0_abort,
    radm_trgt0_ecrc_err,
    trgt0_outq_halt,

    // TRGT1 interface
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
    trgt1_outq_halt,



    // Order Manager Status interface
    outq_trgt0_ack,
    trgt1_in_progress,

    // RADM Q Status Interface
    radm_q_not_empty,
    radm_q_cpl_not_empty,
    // Credit return interface
    radm_rtlh_ph_ca,
    radm_rtlh_pd_ca,
    radm_rtlh_nph_ca,
    radm_rtlh_npd_ca,
    radm_rtlh_cplh_ca,
    radm_rtlh_cpld_ca
  );

// spyglass disable_block W164b
// SMD: Possible loss of carry or borrow due to addition or subtraction
// SJ: Waive this rule for legacy code.


  parameter NW                          = `CX_NW;       // Number of 32-bit dwords handled by the datapath each clock.
  parameter NVC                         = `CX_NVC;      // Number of VC designed to support
  parameter NHQ                         = `CX_NHQ;      // Number of Header Queues per VC
  parameter NDQ                         = `CX_NDQ;      // Number of Data Queues per VC
  parameter NDQ_LOG2                    = `CX_LOGBASE2(NDQ);
  parameter NHQ_LOG2                    = `CX_LOGBASE2(NHQ);
  parameter DW                          = (32*NW);      // Width of datapath in bits.

  parameter P_TYPE                      = 0;
  parameter NP_TYPE                     = 1;
  parameter CPL_TYPE                    = 2;

  // Number of bits required to represent the number of DWORD's present in the last data beat.
parameter   DWLEN_WD                    = (NW==16) ? 4 : (NW == 8) ? 3 : NW >> 1;      // Number of bits from the DW length field to use in calculating DWEN
  parameter DWLEN_END_BIT               = DWLEN_WD-1;

  parameter DATA_PROT_WD                = `TRGT_DATA_PROT_WD;
  parameter RADM_SBUF_HDRQ_CTRL_WD      = `CX_RADM_SBUF_HDRQ_CTRL_WD;  // with of the control bits to store alongside the data in the RAM
  parameter TRGT_HDR_PROT_WD            = `TRGT_HDR_PROT_WD;
  parameter TRGT_HDR_WD                 = `TRGT_HDR_WD;

  parameter HDR_PROT_WD                 = `CX_RADM_SBUF_HDRQ_PROT_WD;
  parameter RADM_SBUF_HDRQ_NOPROT_WD    = `CX_RADM_SBUF_HDRQ_NOPROT_WD;
  parameter RADM_SBUF_DATA_PROT_WD      = `CX_RADM_SBUF_DATAQ_PROT_WD;
  parameter RASDP_HDRQ_ERR_SYND_WD      = `CX_RASDP_HDRQ_ERR_SYND_WD;
  parameter RADM_SBUF_DATAQ_NOPROT_WD   = `CX_RADM_SBUF_DATAQ_NOPROT_WD;
//  parameter RAM_DATA_PARBITS            = `CX_RAM_DATA_PARBITS;
  parameter RADM_SBUF_HDRQ_WD           = `CX_RADM_SBUF_HDRQ_WD;
  parameter RADM_P_HWD                  = `RADM_P_HWD;
  parameter RADM_SBUF_DATAQ_WD          = `CX_RADM_SBUF_DATAQ_WD;
  parameter RADM_SBUF_DATAQ_CTRLQ_WD    = `CX_RADM_SBUF_DATAQ_CTRLQ_WD;
  parameter RADM_SBUF_DATAQ_CTRL_WD     = `CX_RADM_SBUF_DATAQ_CTRL_WD; // with of the control bits to store alongside the data in the RAM
  parameter RADM_ECRC_ERR_NEG_OFFSET    = `CX_RADM_ECRC_ERR_NEG_OFFSET;
  parameter RADM_DLLP_ABORT_NEG_OFFSET  = `CX_RADM_DLLP_ABORT_NEG_OFFSET;
  parameter RADM_TLP_ABORT_NEG_OFFSET   = `CX_RADM_TLP_ABORT_NEG_OFFSET;
  parameter RADM_PQ_DW_LENGTH_FO        = `RADM_PQ_DW_LENGTH_FO;
  parameter RADM_PQ_TD_FO               = `RADM_PQ_TD_FO;
  parameter RADM_CPLQ_DW_LENGTH_FO      = `RADM_CPLQ_DW_LENGTH_FO;
  parameter RADM_CPLQ_TD_FO             = `RADM_CPLQ_TD_FO;

  parameter NUM_SEGMENTS                = `CX_NUM_SEGMENTS;
  parameter SEG_WIDTH                   = `CX_SEG_WIDTH;

  parameter RADM_RAM_RD_CTL_REGOUT      = `CX_RADM_RAM_RD_CTL_REGOUT;
  parameter RADM_RAM_RD_LATENCY         = `CX_RADM_RAM_RD_LATENCY;



  parameter  DCA_WD                     = `CX_LOGBASE2(NW/4+1);

  parameter TP                          = `TP;

  // -------------------------------------------------------------------------------------
  // Input/Output declarations
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  input                                              core_clk;
  input                                              core_rst_n;

  // Configuration
  // Indicates that queue is in bypass, cut-through, and store-forward mode for posted TLP.
  // 3bits per VC, bit0 for bypass, bit1 for cut-through and bit2 for store and forward
  input   [(NVC*3*3)-1:0]                            cfg_radm_q_mode;
  input   [(NVC*3)-1:0]                              cutthru_mode_vec;

  // Order Manager TLP Request Interface
  input                                              req_rd;
  input   [SEG_WIDTH -1:0]                           req_rd_segnum;
  input                                              req_rd_4trgt0;
  input                                              req_tlp_w_pyld;
  output                                             req_ackd;



  // Data Control Queue Interface
  input   [NDQ*RADM_SBUF_DATAQ_CTRLQ_WD-1:0]         dctlq_rdata;


  // Header Queue Interface
  output                                             hdrq_rd_en;
  output  [SEG_WIDTH-1:0]                            hdrq_rd_seg_num;
  input   [NHQ*RADM_SBUF_HDRQ_WD-1:0]                hdrq_rd_data;
`ifndef SYNTHESIS
  output                                             hdrq_pdly1_rd_en;
  output  [SEG_WIDTH-1:0]                            hdrq_pdly1_rd_seg_num;
  output  [RADM_SBUF_HDRQ_WD-1:0]                    hdrq_pdly1_rd_data;
`endif
  output  [NHQ-1:0]                                  hdrq_par_chk_val;
  input   [NUM_SEGMENTS-1:0]                         hdrq_empty;

  // Data Queue Interface
  output                                             dataq_rd_en;
  output  [SEG_WIDTH-1:0]                            dataq_rd_seg_num;
  input   [NDQ*RADM_SBUF_DATAQ_WD-1 :0]              dataq_rd_data;
  output  [NDQ-1:0]                                  dataq_par_chk_val;
  input   [NUM_SEGMENTS-1:0]                         dataq_empty;

  // Target0 interface designed for internal local bus module
  output  [DW+DATA_PROT_WD-1:0]                      radm_trgt0_data;
  output  [TRGT_HDR_WD-1:0]                          radm_trgt0_hdr;
  output  [NW-1:0]                                   radm_trgt0_dwen;
  output                                             radm_trgt0_dv;
  output                                             radm_trgt0_hv;
  output                                             radm_trgt0_eot;
  output                                             radm_trgt0_abort;
  output                                             radm_trgt0_ecrc_err;
  input                                              trgt0_outq_halt;

  // Target1 interface designed for application to receive the TLP
  output  [DW+DATA_PROT_WD-1:0]                      radm_trgt1_data;
  output  [TRGT_HDR_WD-1:0]                          radm_trgt1_hdr;
  output  [NW-1:0]                                   radm_trgt1_dwen;
  output                                             radm_trgt1_dv;
  output                                             radm_trgt1_hv;
  output                                             radm_trgt1_eot;
  output                                             radm_trgt1_tlp_abort;
  output                                             radm_trgt1_dllp_abort;
  output                                             radm_trgt1_ecrc_err;
  output  [2:0]                                      radm_trgt1_vc_num;
  input                                              trgt1_outq_halt;


  // Order Manager Status Interface
  output                                             outq_trgt0_ack;
  output                                             trgt1_in_progress;

  output  [NVC-1:0]                                  radm_q_not_empty;
  output  [NVC-1:0]                                  radm_q_cpl_not_empty;

  // Credit Return Interface
  output  [NVC-1:0]                                  radm_rtlh_ph_ca;
  output  [NVC-1:0]                                  radm_rtlh_pd_ca;
  output  [NVC-1:0]                                  radm_rtlh_nph_ca;
  output  [NVC-1:0]                                  radm_rtlh_npd_ca;
  output  [NVC-1:0]                                  radm_rtlh_cplh_ca;
  output  [NVC-1:0]                                  radm_rtlh_cpld_ca;

  // ---------------------------------------------------------------------------------------
  // Output signal declarations
  // ---------------------------------------------------------------------------------------
  wire                                               hdrq_rd_en;
  wire                                               dataq_rd_en;
  wire [SEG_WIDTH-1:0]                               hdrq_rd_seg_num;

`ifndef SYNTHESIS
  wire                                               hdrq_pdly1_rd_en;
  wire [SEG_WIDTH-1:0]                               hdrq_pdly1_rd_seg_num;
  wire [RADM_SBUF_HDRQ_WD-1:0]                       hdrq_pdly1_rd_data;
`endif

  wire [SEG_WIDTH-1:0]                               dataq_rd_seg_num;
  wire                                               req_ackd;

  wire [NDQ-1:0]                                     dataq_par_chk_val;
  wire [NHQ-1:0]                                     hdrq_par_chk_val;

  // Credit Return Interface
  // ---------------------------------------------------------------------------------------
  // Local parameters
  // ---------------------------------------------------------------------------------------
  // Total read data latency
  localparam RD_LATENCY = RADM_RAM_RD_CTL_REGOUT + RADM_RAM_RD_LATENCY;

  // Width of the RAM pipe delay interface
  localparam PDLY1_WIDTH = RADM_SBUF_HDRQ_WD                       // hdrq data
                          + NDQ*RADM_SBUF_DATAQ_WD                 // dataq data
                          + 1                                      // hdrq read enable
                          + 1                                      // dataq read enable
                          + NDQ                                    // data control queue data
                          + NDQ                                    // dataq RAM parity check signals
                          + 1                                      // Order Manager request for TRGT0 info flag
                          + SEG_WIDTH                              // Order Manager request seg number
                          + 1                                      // Order Manager payload info flag
                          + 1                                      // Cut configuration info flag
                          ;


  // 6bits per interface control signals, trgt0 has ack/trgt1 has dlp abort, plus NW bits for dwen
  localparam PKT_INTF_WD = SEG_WIDTH                  // seg number
//                           + RADM_P_HWD + HDR_PROT_WD // hdrq data and protection code if RASDP is enabled
                           + TRGT_HDR_WD              // hdrq data and protection code if RASDP is enabled
                           + DW + DATA_PROT_WD        // dataq data and protection code if RASDP is enabled
                           + 3                        // type,
                           + 6                        // hv, dv, eot, abort, ecrc_err, ack
                           + 6                        // hv, dv, eot, tlp_abort, dllp_abort, ecrc_err
                           + NW                       // dwen
                           ;



  // ---------------------------------------------------------------------------------------
  // Internal Signal Declaration
  // ---------------------------------------------------------------------------------------
  // Configuration signals
  wire                                               cfg_is_cut_through;

  // RADM Queue status signals
  wire [NVC-1:0]                                     radm_q_not_empty;
  wire [NVC-1:0]                                     radm_q_cpl_not_empty;

  // Data/Hdr Q FSM control signals
  wire [NDQ-1:0]                                     s_dataq_rd_end;
  wire [NDQ-1:0]                                     ss_dataq_rd_end;

  // Header/Data Queue Control signals
  wire                                               qctl_req_ack;
  wire                                               qctl_hdrq_rd_en;
  wire                                               qctl_dataq_rd_en;
  wire                                               qctl_rd_tlp_w_pyld, qctl_rd_4trgt0, qctl_is_cut_through;
  wire [NDQ-1:0]                                     qctl_eot, qctl_dataq_par_chk_val;
  wire [SEG_WIDTH-1:0]                               qctl_rd_seg_num;

  // Shifted data/hdr control signals
  reg  [RD_LATENCY-1:0]                          r_qctl_hdrq_rd_en;
  reg  [RD_LATENCY-1:0]                          r_qctl_dataq_rd_en;
  reg  [RD_LATENCY*NDQ-1:0]                      r_qctl_eot, r_qctl_dataq_par_chk_val;
  reg  [RD_LATENCY-1:0]                          r_qctl_rd_4trgt0, r_qctl_rd_tlp_w_pyld, r_qctl_is_cut_through;
  reg  [RD_LATENCY*SEG_WIDTH-1:0]                r_qctl_rd_seg_num;

  // Aligned data/hdr control signal interface prior to the pipeline
  wire                                               s_algn_hv;
  wire                                               s_algn_dv;
  logic [RADM_SBUF_HDRQ_WD-1:0]                      s_algn_hdrq_rd_data;
  wire [NDQ-1:0]                                     s_algn_eot, s_algn_dataq_par_chk_val;
  wire                                               s_algn_4trgt0, s_algn_tlp_w_pyld, s_algn_ct;
  wire [SEG_WIDTH-1:0]                               s_algn_seg_num;

  // Pipe Delay Interface Signals
  wire [PDLY1_WIDTH-1:0]                             s_algn_intf;
  wire [PDLY1_WIDTH-1:0]                             pdly1_intf;

  wire                                               pdly1_is_ct;
  wire                                               pdly1_4trgt0;
  wire                                               pdly1_tlp_w_pyld;
  wire [SEG_WIDTH -1:0]                              pdly1_seg_num;
  reg                                                pdly1_hv;
  wire [RADM_SBUF_HDRQ_WD-1 :0]                      pdly1_hdrq_rd_data;
  reg                                                pdly1_dv;
  wire [NDQ_LOG2-1:0]                                pdly1_dataq_rd_index;
  reg  [NDQ-1:0]                                     pdly1_eot;
  wire [NDQ-1:0]                                     pdly1_dataq_par_chk_val;

  // Hold hdrq data interface signals
  reg  [RADM_SBUF_HDRQ_WD-1 :0]                      r_pdly1_hdrq_rd_data;
  wire [RADM_SBUF_HDRQ_WD-1 :0]                      s_pdly1_hdrq_rd_data;

// spyglass disable_block W497
// SMD: Not all bits of bus 'ss_pdly1_hdrq_rd_data'(22 bits) are set
// SJ: The bus has been defined as larger than needed to facilitate stripping of ECC codes. The parts of the bus which correspond to ECC code are// not assigned after the ECC code is checked

 // Hdr/Data Q signals post ECC
  wire [RADM_SBUF_HDRQ_WD-1:0]                       ss_pdly1_hdrq_rd_data;
// spyglass enable_block W497
  wire [NDQ*RADM_SBUF_DATAQ_WD-1 :0]                 pdly1_dataq_rd_data;
  reg  [NDQ*RADM_SBUF_DATAQ_WD-1:0]                  s_pdly1_dataq_rd_data_xb;
  logic [NDQ*RADM_SBUF_DATAQ_WD-1:0]                 s_pdly1_dataq_rd_data;
// spyglass disable_block W497
// SMD: Not all bits of bus 'ss_pdly1_dataq_rd_data'(22 bits) are set
// SJ: The bus has been defined as larger than needed to facilitate stripping of ECC codes. The parts of the bus which correspond to ECC code are// not assigned after the ECC code is checked

  wire  [NDQ*RADM_SBUF_DATAQ_WD-1:0]                 ss_pdly1_dataq_rd_data;
// spyglass enable_block W497

  // Packet Interface Signals
  wire                                               pkt_is_ct;
  wire                                               pkt_4trgt0;
  wire [SEG_WIDTH -1:0]                              pkt_seg_num;
  reg                                                pkt_hv;
  reg                                                pkt_dv;
  reg  [NDQ-1:0]                                     pkt_eot;
  wire [NDQ-1:0]                                     pkt_dataq_par_chk_val;
  wire [NDQ-1:0]                                     pkt_ecrc_err;
  wire [NDQ-1:0]                                     pkt_dllp_abort;
  wire [NDQ-1:0]                                     pkt_tlp_abort;
  reg  [DW+DATA_PROT_WD-1:0]                         pkt_data;
  wire [2:0]                                         pkt_type;
  wire [2:0]                                         pkt_vc_num;
  wire                                               pkt_hdrq_tlp_abort;
  wire                                               pkt_hdrq_td;
  wire                                               pkt_hdrq_td_popped;
  wire                                               pkt_hdrq_fmt_pyld;           // the Format field indicates this TLP has data
  wire [DWLEN_WD-1:0]                                pkt_hdrq_dw_length;
  wire [TRGT_HDR_WD-1:0]                             pkt_hdr;
  wire [NW-1:0]                                      pkt_dwen;

  wire                                               s_pkt_mask;
  reg                                                s_pkt_dllp_abort;

  wire                                               s_trgt0_hv;
  wire                                               s_trgt0_dv;
  wire                                               s_trgt0_eot;
  reg                                                s_trgt0_abort;
  reg                                                s_trgt0_ecrc_err;
  wire                                               s_trgt0_ack;

  wire                                               s_trgt1_hv;
  wire                                               s_trgt1_dv;
  wire                                               s_trgt1_eot;
  reg                                                s_trgt1_tlp_abort;
  reg                                                s_trgt1_dllp_abort;
  reg                                                s_trgt1_ecrc_err;

  wire [PKT_INTF_WD-1:0]                             s_pkt_intf;
  reg  [PKT_INTF_WD-1:0]                             r_pkt_intf;
  wire                                               s_pkt_hv;
  wire                                               s_pkt_dv;
  wire                                               s_pkt_eot;
  wire                                               ss_pkt_dllp_abort;
  wire                                               s_pkt_td;
  wire [NW-1:0]                                      s_pkt_dwen;
  wire [2:0]                                         r_pkt_type;

  // Aligned data/hdr control signal interface post the TRGT* interface register slice
  wire    [DW+DATA_PROT_WD-1 :0]                     r_pkt_data;
  wire    [TRGT_HDR_WD-1 :0]                         r_pkt_hdr;
  wire    [NW-1:0]                                   r_pkt_dwen;
  wire                                               r_trgt0_hv;
  wire                                               r_trgt0_eot;
  wire                                               r_trgt0_dv;
  wire                                               r_trgt0_abort;
  wire                                               r_trgt0_ecrc_err;
  wire                                               r_trgt0_ack;
  wire                                               r_trgt1_hv;
  wire                                               r_trgt1_eot;
  wire                                               r_trgt1_dv;
  wire                                               r_trgt1_tlp_abort;
  wire                                               r_trgt1_dllp_abort;
  wire                                               r_trgt1_ecrc_err;
  wire    [SEG_WIDTH -1:0]                           r_pkt_seg_num;
  wire                                               trgt1_in_progress;

  wire                                               halt_app;
  wire                                               halt_in;

  // ---------------------------------------------------------------------------------------
  // Design
  // ---------------------------------------------------------------------------------------
  assign cfg_is_cut_through = Build_is_cut_through(cutthru_mode_vec,req_rd_segnum);

  // -------------------------------------------------------------------------------------
  // Instantiate the Data/Header Queue Read Control module
  // -------------------------------------------------------------------------------------
  // Extract Data Q Control Info
  assign s_dataq_rd_end = dctlq_rdata[NDQ-1:0];
  assign ss_dataq_rd_end = s_dataq_rd_end;

  radm_outq_mgr_ctl
  
  #(
  .NDQ                               (NDQ)
  ,.NDQ_LOG2                         (NDQ_LOG2)
  ,.NUM_SEGMENTS                     (NUM_SEGMENTS)
  ,.NUM_SEGMENTS_LOG2                (SEG_WIDTH)
  )
  u_qctl
  (
  // Clocks and resets
  .core_clk                          (core_clk)
  ,.core_rst_n                       (core_rst_n)
  // Configuration
  ,.cfg_is_cut_through               (cfg_is_cut_through)
  // Data Q Info Interface
  ,.dataq_rd_end                     (ss_dataq_rd_end)
  // Order Q Read Interface
  ,.ordrq_rd_req                     (req_rd)
  ,.qctl_req_ack                     (qctl_req_ack)
  ,.ordrq_rd_seg_num                 (req_rd_segnum)
  ,.ordrq_rd_tlp_w_pyld              (req_tlp_w_pyld)
  ,.ordrq_rd_4trgt0                  (req_rd_4trgt0)
  // Header Q Read Interface
  ,.hdrq_empty                       (hdrq_empty)
  ,.qctl_hdrq_rd_en                  (qctl_hdrq_rd_en)
  // Data Q Data Interface
  ,.qctl_dataq_rd_en                 (qctl_dataq_rd_en)
  ,.qctl_dataq_par_chk_val           (qctl_dataq_par_chk_val)
  ,.dataq_empty                      (dataq_empty)
  // Data Q Control Interface
  ,.qctl_is_cut_through              (qctl_is_cut_through)
  ,.qctl_eot                         (qctl_eot)
  ,.qctl_rd_seg_num                  (qctl_rd_seg_num)
  ,.qctl_rd_tlp_w_pyld               (qctl_rd_tlp_w_pyld)
  ,.qctl_rd_4trgt0                   (qctl_rd_4trgt0)
  ,.halt                             (halt_in)
  );

  // Assign outputs
  assign req_ackd         = qctl_req_ack;
  assign hdrq_rd_en       = qctl_hdrq_rd_en;
  assign dataq_rd_en      = qctl_dataq_rd_en;
  assign hdrq_rd_seg_num  = qctl_rd_seg_num;
  assign dataq_rd_seg_num = qctl_rd_seg_num;

  // -------------------------------------------------------------------------------------
  // Align control info to header and data
  // -------------------------------------------------------------------------------------
  generate
    if (RD_LATENCY > 1) begin : gen_dlyn_ctl_info

      always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_dlyn_ctl_info
        integer i, j, k, l, m, n, o, p;

        if (!core_rst_n) begin
          r_qctl_rd_4trgt0         <= # TP 0;
          r_qctl_rd_tlp_w_pyld     <= # TP 0;
          r_qctl_is_cut_through    <= # TP 0;
          r_qctl_rd_seg_num        <= # TP 0;
          r_qctl_hdrq_rd_en        <= # TP 0;
          r_qctl_dataq_rd_en       <= # TP 0;
          r_qctl_eot               <= # TP 0;
          r_qctl_dataq_par_chk_val <= # TP 0;
        end else begin
          for (i=0; i<RD_LATENCY; i=i+1) begin : dly_ctl_info
            if (i==0) begin
              // Capture ordq info
              r_qctl_rd_4trgt0[i]                         <= # TP qctl_rd_4trgt0;
              r_qctl_rd_tlp_w_pyld[i]                     <= # TP qctl_rd_tlp_w_pyld;
              r_qctl_is_cut_through[i]                    <= # TP qctl_is_cut_through;
              r_qctl_rd_seg_num[i*SEG_WIDTH +: SEG_WIDTH] <= # TP qctl_rd_seg_num;
              r_qctl_hdrq_rd_en[i]                        <= # TP qctl_hdrq_rd_en;
              r_qctl_dataq_rd_en[i]                       <= # TP qctl_dataq_rd_en;
              r_qctl_eot[i*NDQ +: NDQ]                    <= # TP qctl_eot;
              r_qctl_dataq_par_chk_val[i*NDQ +: NDQ]      <= # TP qctl_dataq_par_chk_val;
            end else begin
              // Shift control info
              r_qctl_rd_4trgt0[i]      <= # TP r_qctl_rd_4trgt0[i-1];
              r_qctl_rd_tlp_w_pyld[i]  <= # TP r_qctl_rd_tlp_w_pyld[i-1];
              r_qctl_is_cut_through[i] <= # TP r_qctl_is_cut_through[i-1];
              for (j=0; j<SEG_WIDTH; j=j+1) begin
                r_qctl_rd_seg_num[j+(SEG_WIDTH*i)] <= # TP r_qctl_rd_seg_num[j+(SEG_WIDTH*(i-1))];
              end
              r_qctl_hdrq_rd_en[i]       <= # TP r_qctl_hdrq_rd_en[i-1];
              r_qctl_dataq_rd_en[i]      <= # TP r_qctl_dataq_rd_en[i-1];
              for (k=0; k<NDQ; k=k+1) begin
                r_qctl_eot[k+(NDQ*i)]               <= # TP r_qctl_eot[k+(NDQ*(i-1))];
                r_qctl_dataq_par_chk_val[k+(NDQ*i)] <= # TP r_qctl_dataq_par_chk_val[k+(NDQ*(i-1))];
              end
            end
          end
        end
      end

    end else begin : gen_dly1_ctl_info

      always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_dly1_ctl_info
        if (!core_rst_n) begin
          r_qctl_rd_4trgt0         <= # TP 0;
          r_qctl_rd_tlp_w_pyld     <= # TP 0;
     r_qctl_is_cut_through    <= # TP 0;
          r_qctl_rd_seg_num        <= # TP 0;
          r_qctl_hdrq_rd_en        <= # TP 0;
          r_qctl_dataq_rd_en       <= # TP 0;
          r_qctl_eot               <= # TP 0;
          r_qctl_dataq_par_chk_val <= # TP 0;
        end else begin
          // Capture ordq info
          r_qctl_rd_4trgt0         <= # TP qctl_rd_4trgt0;
          r_qctl_rd_tlp_w_pyld     <= # TP qctl_rd_tlp_w_pyld;
          r_qctl_is_cut_through    <= # TP qctl_is_cut_through;
          r_qctl_rd_seg_num        <= # TP qctl_rd_seg_num;
          r_qctl_hdrq_rd_en        <= # TP qctl_hdrq_rd_en;
          r_qctl_dataq_rd_en       <= # TP qctl_dataq_rd_en;
          r_qctl_eot               <= # TP qctl_eot;
          r_qctl_dataq_par_chk_val <= # TP qctl_dataq_par_chk_val;
        end
      end

    end
  endgenerate

  // Aligned control info interface
  assign s_algn_ct                = r_qctl_is_cut_through[RD_LATENCY-1];
  assign s_algn_4trgt0            = r_qctl_rd_4trgt0[RD_LATENCY-1];
  assign s_algn_tlp_w_pyld        = r_qctl_rd_tlp_w_pyld[RD_LATENCY-1];
  assign s_algn_seg_num           = r_qctl_rd_seg_num[(RD_LATENCY-1)*SEG_WIDTH +: SEG_WIDTH];
  assign s_algn_hv                = r_qctl_hdrq_rd_en[RD_LATENCY-1];
  assign s_algn_dv                = r_qctl_dataq_rd_en[RD_LATENCY-1];
  assign s_algn_eot               = r_qctl_eot[(RD_LATENCY-1)*NDQ +: NDQ];
  assign s_algn_dataq_par_chk_val = r_qctl_dataq_par_chk_val[(RD_LATENCY-1)*NDQ +: NDQ];

  assign s_algn_hdrq_rd_data = hdrq_rd_data;

  // -------------------------------------------------------------------------------------
  // RAM Parity check signals
  // -------------------------------------------------------------------------------------
  assign hdrq_par_chk_val  = {{(NHQ-1){1'b0}}, s_algn_hv};
  assign dataq_par_chk_val = s_algn_dataq_par_chk_val;

  // -------------------------------------------------------------------------------------
  // Register the output data of the RAM; support N RAM read access cycles
  // -------------------------------------------------------------------------------------
  assign s_algn_intf = { s_algn_hdrq_rd_data
                        ,dataq_rd_data
                        ,s_algn_hv
                        ,s_algn_dv
                        ,s_algn_eot
                        ,s_algn_dataq_par_chk_val
                        ,s_algn_4trgt0
                        ,s_algn_seg_num
                        ,s_algn_tlp_w_pyld
                        ,s_algn_ct
                       };

  wire uncon_pipe_halt_out;

  ram_latency_pipe
  
  #(
   .PIPE_WIDTH(PDLY1_WIDTH),
   .PIPE_INPUT_REG(1),
   .PIPE_LATENCY(RD_LATENCY),
   .PIPE_EXTRA_STORAGE(1)
   )
   u_pdly1(
// ------ Inputs ------
    .core_clk              (core_clk),
    .core_rst_n            (core_rst_n),
    .halt_in               (halt_in),
    .pipe_in_data_valid    (|qctl_dataq_rd_en | qctl_hdrq_rd_en),
    .pipe_in_data          (s_algn_intf),

// ------ Outputs ------
    .halt_out              (uncon_pipe_halt_out),
    .pipe_out_data_valid   ( /* UNCONNECTED */ ),
    .pipe_out_data         (pdly1_intf)
);

  assign { pdly1_hdrq_rd_data
           ,pdly1_dataq_rd_data
           ,pdly1_hv
           ,pdly1_dv
           ,pdly1_eot
           ,pdly1_dataq_par_chk_val
           ,pdly1_4trgt0
           ,pdly1_seg_num
           ,pdly1_tlp_w_pyld
           ,pdly1_is_ct
         } = pdly1_intf;

// -------------------------------------------------------------------------------------
// Hold header over for duration of TLP
// -------------------------------------------------------------------------------------
  always @(posedge core_clk or negedge core_rst_n) begin : LATCH_HDR
    if (!core_rst_n) begin
        r_pdly1_hdrq_rd_data <= #TP 0;
    end else if (pdly1_hv) begin
        r_pdly1_hdrq_rd_data <= #TP pdly1_hdrq_rd_data;
    end
  end

  assign s_pdly1_hdrq_rd_data = pdly1_hv ? pdly1_hdrq_rd_data : r_pdly1_hdrq_rd_data;

`ifndef SYNTHESIS
  assign hdrq_pdly1_rd_en      = pdly1_hv && !halt_in;
  assign hdrq_pdly1_rd_seg_num = pdly1_seg_num;
  assign hdrq_pdly1_rd_data    = s_pdly1_hdrq_rd_data;
`endif


  assign s_pdly1_dataq_rd_data = pdly1_dv ? pdly1_dataq_rd_data : 0;

  assign ss_pdly1_hdrq_rd_data     = s_pdly1_hdrq_rd_data;
  assign ss_pdly1_dataq_rd_data    = s_pdly1_dataq_rd_data;

  // -------------------------------------------------------------------------------------
  // Assign Packet Interface Signals
  // -------------------------------------------------------------------------------------
  // Extract packet data
  always @(*) begin : proc_comb_extract_data
    integer i;
    pkt_data = 0;
    for(i = 0; i < NDQ; i = i + 1) begin
      pkt_data[i*DW/NDQ +: DW/NDQ] = ss_pdly1_dataq_rd_data[i*RADM_SBUF_DATAQ_WD +: DW/NDQ];
    end
  end

  // Internal signals that drive application output interfaces
  // Needs to get discard and abort signals from either hdr and data
  // queue. If it is a pkt without payload, then discard and abort signals
  // came from hdr queue. If it is a pkt with payload, then the discard and
  // abort signals come from data queue.
  genvar g_ctrl_info;
  generate for(g_ctrl_info = 0; g_ctrl_info < NDQ; g_ctrl_info = g_ctrl_info + 1) begin : gen_ctrl_info
    assign pkt_ecrc_err[g_ctrl_info]= 0;

    assign pkt_dllp_abort[g_ctrl_info] = 0;


    assign  pkt_tlp_abort[g_ctrl_info]  = ( (pdly1_tlp_w_pyld & ss_pdly1_dataq_rd_data[(g_ctrl_info+1)*RADM_SBUF_DATAQ_WD-RADM_SBUF_DATA_PROT_WD-RADM_TLP_ABORT_NEG_OFFSET])
                                          | (ss_pdly1_hdrq_rd_data[RADM_SBUF_HDRQ_NOPROT_WD-RADM_TLP_ABORT_NEG_OFFSET+1]));
  end
  endgenerate

  assign pkt_hdr[0 +: RADM_P_HWD]                = ss_pdly1_hdrq_rd_data[0 +: RADM_P_HWD];

  assign pkt_is_ct              = pdly1_is_ct;
  assign pkt_4trgt0             = pdly1_4trgt0;
  assign pkt_seg_num            = pdly1_seg_num;
  assign pkt_hv                 = pdly1_hv;
  assign pkt_dv                 = |pdly1_dv;
  assign pkt_eot                = pdly1_eot;
  assign {pkt_vc_num, pkt_type} = Get_vc_type(pkt_seg_num);
  assign pkt_hdrq_tlp_abort     = ss_pdly1_hdrq_rd_data[RADM_SBUF_HDRQ_NOPROT_WD-RADM_TLP_ABORT_NEG_OFFSET+1];
  assign pkt_hdrq_td_popped     =

                                  (pkt_type[CPL_TYPE])    ? ss_pdly1_hdrq_rd_data[RADM_CPLQ_TD_FO]
                                                          : ss_pdly1_hdrq_rd_data[RADM_PQ_TD_FO];

  assign pkt_hdrq_td            = 0; // To avoid returning an ECRC credit because of CX_FLT_UNMASK_TD.
                                     // In radm_filter_ep/rc  flt_q_td = cfg_filter_rule_mask[`CX_FLT_UNMASK_TD] ? flt_q_hdr_dw1[23] : 1'b0;

  assign pkt_hdrq_fmt_pyld      =
                                                            ss_pdly1_hdrq_rd_data[`FLT_Q_FMT_WIDTH + `FLT_Q_FMT_FO - 1];
  assign pkt_hdrq_dw_length     =
                                  (pkt_type[CPL_TYPE])    ? ss_pdly1_hdrq_rd_data[(RADM_CPLQ_DW_LENGTH_FO+DWLEN_END_BIT):RADM_CPLQ_DW_LENGTH_FO]
                                                          : ss_pdly1_hdrq_rd_data[(RADM_PQ_DW_LENGTH_FO+DWLEN_END_BIT):RADM_PQ_DW_LENGTH_FO];

  // -------------------------------------------------------------------------------------
  // pkt_ecrc_err is excluded from this expression because it can only be nonzero when
  // ECRC_ERR_PASS_THROUGH is defined.
  // In that case the packet should be passed on regardless of the value of pkt_ecrc_err
  // In cut-thru mode, we can't tell if a packet is aborted at the beginning of the packet
  // so we have to let the packet out to the trgt interfaces and pass on any aborts with eot
  //
  // In case of a RASDP error, dv, hv and eot are deasserted to prevent
  // forwarding TLP to TRGT0
  // -------------------------------------------------------------------------------------
  assign s_pkt_mask = !pkt_is_ct && pkt_hdrq_tlp_abort;

  assign s_trgt0_hv  = !s_pkt_mask && pkt_4trgt0 && pkt_hv
                     ;
  assign s_trgt0_dv  = !s_pkt_mask && pkt_4trgt0 && pkt_dv
                     ;
  assign s_trgt0_eot = !s_pkt_mask && pkt_4trgt0 && |pkt_eot
                     ;
  assign s_trgt1_hv  = !s_pkt_mask && !pkt_4trgt0 && pkt_hv
                     ;
  assign s_trgt1_dv  = !s_pkt_mask && !pkt_4trgt0 && pkt_dv
                     ;
  assign s_trgt1_eot = !s_pkt_mask && !pkt_4trgt0 && |pkt_eot
                     ;


  // Qualify abort/ecrc_err signals with eot
  always @(*) begin : Assign_on_eot
    integer i;
    s_pkt_dllp_abort   = 0;
    s_trgt0_abort      = 0;
    s_trgt0_ecrc_err   = 0;
    s_trgt1_tlp_abort  = 0;
    s_trgt1_dllp_abort = 0;
    s_trgt1_ecrc_err   = 0;
    // Loop down so first eot takes precedence, we only process 1 eot per
    // cycle on the output of the queues
    for(i = NDQ-1; i >= 0; i = i - 1) begin
        if(pkt_eot[i]) begin
            s_pkt_dllp_abort   =  pkt_dllp_abort[i];
            s_trgt0_abort      =  (pkt_dllp_abort[i] || pkt_tlp_abort[i]) && !s_pkt_mask && pkt_4trgt0
                               ;
            s_trgt0_ecrc_err   =  pkt_ecrc_err[i]  && !s_pkt_mask &&  pkt_4trgt0
                               ;
            s_trgt1_tlp_abort  =  pkt_tlp_abort[i] && !s_pkt_mask && !pkt_4trgt0
                               ;
            s_trgt1_dllp_abort =  pkt_dllp_abort[i] && !s_pkt_mask && !pkt_4trgt0
                               ;
            s_trgt1_ecrc_err   =  pkt_ecrc_err[i]  && !s_pkt_mask && !pkt_4trgt0
                               ;
        end
    end
  end

  // -------------------------------------------------------------------------------------
  // Acknowledge TLP destined for TRGT0
  // -------------------------------------------------------------------------------------
  assign s_trgt0_ack =  pkt_4trgt0 & |pkt_eot
                     ;

  // -------------------------------------------------------------------------------------
  // Calculate DW enables
  // -------------------------------------------------------------------------------------
  // the correct dwen for the final cycle of dv
  assign  pkt_dwen = (s_trgt0_eot
                   || s_trgt1_eot
                    ) ? Calc_dwen(pkt_hdrq_dw_length, pkt_hdrq_td, pkt_hdrq_fmt_pyld) : {NW{1'b1}};

  // -------------------------------------------------------------------------------------
  // Credit return calcuation logic
  // -------------------------------------------------------------------------------------
  // Indicates last beat contains ECRC only
  assign s_pkt_td = (|pkt_eot && !halt_in) ? ( (pkt_hdrq_fmt_pyld && pkt_hdrq_dw_length == 0 && pkt_hdrq_td)
                                                || (!pkt_hdrq_fmt_pyld && pkt_hdrq_td) )
                                            : 1'b0;

  assign s_pkt_hv          = pkt_hv & !halt_in;
  assign s_pkt_dv          = pkt_dv & !halt_in;
  assign s_pkt_eot         = (|pkt_eot) & !halt_in;
  assign ss_pkt_dllp_abort = (|s_pkt_dllp_abort) & !halt_in;

  // s_pkt_dwen is only to pass to credit return. It takes no account of td
  // because the ECRC does not consume credit
  assign s_pkt_dwen = Calc_dwen(pkt_hdrq_dw_length, 1'b0, pkt_hdrq_fmt_pyld);


  // -------------------------------------------------------------------------------------
  // Return Flow Control Credits.
  // -------------------------------------------------------------------------------------
  // The RTLH returns credits.  For Cut-through mode, if this eot signal is asserted without either h_ca or d_ca
  // assertion, the RTLH knows that the packet has been aborted and to NOT return credtis in this case.
  // Furthermore, we assume that the RTLH knows the width of our data path.  If our data path is 128-bits,
  // this means that each pulse on the x_ca signal is a full credit.  However, if our data path is 32-bits,
  // the RTLH must accumulate credits and return the appropriate values.

  radm_crd_return
  
   #(.NW     (NW)
    )
  u_radm_crd_return
    (
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .cfg_radm_q_mode            (cfg_radm_q_mode),
    .tlp_hv                     (s_pkt_hv),
    .tlp_dv                     (s_pkt_dv),
    .tlp_eot                    (s_pkt_eot),
    .tlp_abort                  (ss_pkt_dllp_abort),
    .tlp_type                   (pkt_type),
    .tlp_vc                     (pkt_vc_num),
    .tlp_td                     (s_pkt_td),
    .tlp_dwen                   (s_pkt_dwen),

    // Credit return interface
    .radm_rtlh_ph_ca             (radm_rtlh_ph_ca),
    .radm_rtlh_pd_ca             (radm_rtlh_pd_ca),
    .radm_rtlh_nph_ca            (radm_rtlh_nph_ca),
    .radm_rtlh_npd_ca            (radm_rtlh_npd_ca),
    .radm_rtlh_cplh_ca           (radm_rtlh_cplh_ca),
    .radm_rtlh_cpld_ca           (radm_rtlh_cpld_ca)
    );




// -------------------------------------------------------------------------------------
// Register the RTRGT1* interface signals
// -------------------------------------------------------------------------------------
  // Pack target header/data signals
  assign s_pkt_intf = {
                  pkt_seg_num,
                  pkt_hdr,
                  pkt_data,
                  pkt_type,
                  s_trgt0_hv, s_trgt0_dv, s_trgt0_eot, s_trgt0_abort,
                  s_trgt0_ecrc_err, s_trgt0_ack, s_trgt1_hv, s_trgt1_dv, s_trgt1_eot,
                  s_trgt1_tlp_abort, s_trgt1_dllp_abort, s_trgt1_ecrc_err, pkt_dwen
                  };

  // Extract target header/data signals
  // Hold header/data if halt asserted.
  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      r_pkt_intf    <= # TP 0;
    end else begin
      if (!halt_app) begin
          r_pkt_intf <= # TP s_pkt_intf;
      end
    end
  end

  assign {
          r_pkt_seg_num, r_pkt_hdr, r_pkt_data,
          r_pkt_type,
          r_trgt0_hv, r_trgt0_dv, r_trgt0_eot, r_trgt0_abort,
          r_trgt0_ecrc_err, r_trgt0_ack, r_trgt1_hv, r_trgt1_dv, r_trgt1_eot,
          r_trgt1_tlp_abort, r_trgt1_dllp_abort, r_trgt1_ecrc_err, r_pkt_dwen
         } = r_pkt_intf;





  // -------------------------------------------------------------------------------------
  // Halt header and data if target data or header valid and halt asserted.
  // If header/data not valid allow pipeline to advance.
  // -------------------------------------------------------------------------------------
  // Backpressure
  assign  halt_app = (trgt1_outq_halt & (r_trgt1_hv | r_trgt1_dv))
                   | (trgt0_outq_halt & (r_trgt0_hv | r_trgt0_dv))
                   ;
  // Halt reading the data from the buffer
  assign  halt_in = halt_app
                  ;


  // -------------------------------------------------------------------------------------
  // Assign outputs
  // -------------------------------------------------------------------------------------
  // TRGT1
  assign  radm_trgt1_hv         = r_trgt1_hv;
  assign  radm_trgt1_dv         = r_trgt1_dv;
  assign  radm_trgt1_eot        = r_trgt1_eot;
  assign  radm_trgt1_dllp_abort = r_trgt1_dllp_abort;
  assign  radm_trgt1_tlp_abort  = r_trgt1_tlp_abort;
  assign  radm_trgt1_ecrc_err   = r_trgt1_ecrc_err;
  assign  radm_trgt1_data       = r_pkt_data;
  assign  radm_trgt1_dwen       = r_pkt_dwen;
  assign  radm_trgt1_hdr        = r_pkt_hdr;
  // VC num here is calculated from the SEGNUM not from either
  // tc2vcmap(logical/physical). Since it is based on the queue used it
  // corresponds to the physical VC.
  reg [2:0]    radm_trgt1_vc_num;
  always @(*) begin : SEG2_VC_NUM
    integer i;
    radm_trgt1_vc_num = 0;
    for(i = 0; i < NUM_SEGMENTS/3; i = i + 1) begin
      if(r_pkt_seg_num == i*3 || r_pkt_seg_num == i*3 + 1 || r_pkt_seg_num == i*3 + 2) begin
        radm_trgt1_vc_num = i;
      end
    end
  end

  // TRGT0
  assign radm_trgt0_hv       = r_trgt0_hv;
  assign radm_trgt0_dv       = r_trgt0_dv;
  assign radm_trgt0_eot      = r_trgt0_eot;
  assign radm_trgt0_abort    = r_trgt0_abort;
  assign radm_trgt0_ecrc_err = r_trgt0_ecrc_err;
  assign radm_trgt0_data     = r_pkt_data;
  assign radm_trgt0_dwen     = r_pkt_dwen;
  assign radm_trgt0_hdr      = r_pkt_hdr;

  // Order Manager Status interface
  assign trgt1_in_progress = radm_trgt1_hv | radm_trgt1_dv;
  assign outq_trgt0_ack    = r_trgt0_ack;


  // -------------------------------------------------------------------------------------
  // RADM Queue Status

  // Per VC indication that queues aren't empty
  assign radm_q_not_empty = Build_vc_vec_from_seg_num_vec((~hdrq_empty) | (~dataq_empty));
  //Per VC indication that the CPL queues are not empty
  assign radm_q_cpl_not_empty = Build_cpl_empty_pervc_from_seg_num_vec((~hdrq_empty) | (~dataq_empty));



  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------

    // Calculates the DWEN for the final cycle of data
    function automatic [NW-1:0]               Calc_dwen;
    input   [DWLEN_WD-1:0]          dw_length;
    input                           td;
    input                           fmt_data;
    begin
        Calc_dwen = 0;
        if ( td && !fmt_data ) begin        // if this packet shouldn't have data but has the TD bit set. give 1 Dword for the ECRC Field
            Calc_dwen = 1;
        end
        else
            begin
                Calc_dwen = { (~dw_length ^ td), 1'b1 };
            end
    end
    endfunction

  // Return the vc number and type for a given segment number.  FORMAT: {vc_num[2:0],type[1:0]}
  function automatic [5:0] Get_vc_type;
  input   [SEG_WIDTH-1:0]             seg_num;

  reg     [4:0]                       seg;

  begin
    seg = 0;
    seg[SEG_WIDTH-1:0] = seg_num;
    Get_vc_type = 0;
        case (seg)
            5'd2    :  Get_vc_type = { 3'd0, 3'b100 };
            5'd1    :  Get_vc_type = { 3'd0, 3'b010 };
            default :  Get_vc_type = { 3'd0, 3'b001 };
    endcase
  end
  endfunction

  // Creates a per VC vector from a per segment number vector by or'ing the type bits for each segment in the same VC
  function automatic [NVC-1:0] Build_vc_vec_from_seg_num_vec;
  input   [NUM_SEGMENTS-1:0]          per_segment_vec;

 begin
    Build_vc_vec_from_seg_num_vec = 0;
     Build_vc_vec_from_seg_num_vec[0]  = |per_segment_vec[02:00];








 end
 endfunction


  function automatic [NVC-1:0] Build_cpl_empty_pervc_from_seg_num_vec;
  input   [NUM_SEGMENTS-1:0]          per_segment_vec;

  begin
    Build_cpl_empty_pervc_from_seg_num_vec = 0;
     Build_cpl_empty_pervc_from_seg_num_vec[0]  = per_segment_vec[(CPL_TYPE+1)*1-1];








  end
  endfunction

  function automatic Build_is_cut_through;
  input   [NUM_SEGMENTS-1:0]          cut_through;
  input   [SEG_WIDTH -1:0]            latchd_req_rd_segnum;

  integer seg_num;

  begin
   Build_is_cut_through = 1'b0;
   for (seg_num=0; seg_num<NUM_SEGMENTS; seg_num=seg_num+1) begin
     if (seg_num==latchd_req_rd_segnum)
       Build_is_cut_through = cut_through[seg_num];
   end

  end
  endfunction

`ifndef SYNTHESIS
`endif // SYNTHESIS

// spyglass enable_block W164b
endmodule
