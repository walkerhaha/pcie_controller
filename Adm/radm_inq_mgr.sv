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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_inq_mgr.sv#5 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module controles the in-queuing of a TLP to our segment buffer
// --- Its main functions are:
// ---    (1) Generated seg buffer push logic
// ---    (2) Allow bypass selection to output the bypass interface
// ---
// ---
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module radm_inq_mgr(
// ------ generic inputs ------
    core_clk,
    core_rst_n,
    bypass_mode_vec,
    cutthru_mode_vec,
    cfg_filter_rule_mask,

    // Filter interfaces
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

    // Seq buffer interface
    hdrq_seg_pkt_avail,
    hdrq_full,
    hdrq_full_m_1,

    dataq_full_m_1,
    dataq_full,



    hdrq_wr_en,
    hdrq_wr_start,
    hdrq_wr_keep,

                     
    hdrq_wr_seg_num,
    hdrq_wr_data,
    hdrq_wr_type,
    hdrq_wr_vc,
    hdrq_wr_4trgt0,
    hdrq_wr_4tlp_abort,
    hdrq_wr_relax_ordr,
    dataq_wr_start,
    dataq_wr_en,

    dataq_wr_keep,
    dataq_wr_drop,

                     
    dataq_wr_seg_num,
    dataq_wr_data,

    radm_qoverflow,
    radm_inq_parerr,

    // bypass interface
    radm_bypass_data,
    radm_bypass_hdr,
    radm_bypass_dwen,
    radm_bypass_dv,
    radm_bypass_hv,
    radm_bypass_eot,
    radm_bypass_tlp_abort,
    radm_bypass_dllp_abort,
    radm_bypass_ecrc_err
);

// spyglass disable_block W116
// SMD: For operator (|), left expression
// SJ: Waive this rule for legacy code.

parameter INST                      = 0;                    // The uniquifying parameter for each port logic instance.
parameter NL                        = `CX_NL;               // Max number of lanes supported
parameter NB                        = `CX_NB;               // Number of symbols (bytes) per clock cycle
parameter NW                        = 16;                   // Number of 32-bit dwords handled by the datapath each clock.
parameter NVC                       = `CX_NVC;              // Number of VC designed to support
parameter DW                        = (32*NW);              // Width of datapath in bits.

parameter RADM_SBUF_DATAQ_CTRL_WD   = `CX_RADM_SBUF_DATAQ_CTRL_WD; // with of the control bits to store alongside the data in the RAM
parameter RADM_SBUF_HDRQ_CTRL_WD    = `CX_RADM_SBUF_HDRQ_CTRL_WD;  // with of the control bits to store alongside the data in the RAM

parameter PAR_CALC_WIDTH            = `DATA_BUS_PAR_CALC_WIDTH;
parameter DATA_PROT_WD              = `TRGT_DATA_PROT_WD;
// width of the protection code coming from the filters - with for 1 filter only
// multiplied later by the number of header queues
parameter ADDR_PAR_WD               = `CX_FLT_OUT_PROT_WD;



parameter SBUF_HDR_PROT_WD          = `CX_RADM_SBUF_HDRQ_PROT_WD;
parameter SBUF_DATA_PROT_WD         = `CX_RADM_SBUF_DATAQ_PROT_WD;
parameter RADM_SBUF_DATAQ_NOPROT_WD = `CX_RADM_SBUF_DATAQ_NOPROT_WD;

parameter HW                        = `FLT_Q_HDR_WIDTH;     // Header width
parameter RADM_P_HWD                = `RADM_P_HWD;
parameter RADM_SBUF_HDRQ_WD         = `CX_RADM_SBUF_HDRQ_WD;
parameter RADM_SBUF_HDRQ_NOPROT_WD  = `CX_RADM_SBUF_HDRQ_NOPROT_WD;



parameter TP                        = `TP;                  // Clock to Q delay (simulator insurance)
parameter RADM_ECRC_ERR_NEG_OFFSET  = `CX_RADM_ECRC_ERR_NEG_OFFSET;
parameter RADM_DLLP_ABORT_NEG_OFFSET= `CX_RADM_DLLP_ABORT_NEG_OFFSET;
parameter RADM_TLP_ABORT_NEG_OFFSET = `CX_RADM_TLP_ABORT_NEG_OFFSET;
parameter RADM_EOT_NEG_OFFSET       = `CX_RADM_EOT_NEG_OFFSET;
parameter REGOUT                    = `CX_RADM_INQ_MGR_REGOUT;

parameter NUM_SEGMENTS              = `CX_NUM_SEGMENTS;
parameter SEG_WIDTH                 = `CX_SEG_WIDTH;

parameter GENERATE_STARTEND_ADDRS   = 1;
parameter DEBUG_WRITES              = 0;
parameter N_FLT_MASK                = `CX_N_FLT_MASK;

parameter RADM_SBUF_HDRQ_PW         = `CX_RADM_SBUF_HDRQ_PW;
parameter RADM_SBUF_DATAQ_WD        = `CX_RADM_SBUF_DATAQ_WD;
parameter RADM_SBUF_DATAQ_PW        = `CX_RADM_SBUF_DATAQ_PW;

parameter NHQ           = `CX_NHQ;  // Number of Header Queues
parameter NDQ           = 4;        // Number of Data Queues

// determines the width of the header fields presented at the target interfaces
parameter TRGT_HDR_WD               = `TRGT_HDR_WD;
parameter TRGT_DATA_WD              = `TRGT_DATA_WD;
parameter TRGT_DATA_PROT_WD         = `TRGT_DATA_PROT_WD;
parameter TRGT_HDR_PROT_WD          = `TRGT_HDR_PROT_WD;

// -------------------------------- Inputs -------------------------------------
input                           core_clk;               // Core clock
input                           core_rst_n;             // Core system reset
                                                        // 3bits per VC, bit0 for bypass, bit1 for cut-through and bit2 for store and forward
input   [(NVC*3)-1:0]           bypass_mode_vec;
input   [(NVC*3)-1:0]           cutthru_mode_vec;
input   [N_FLT_MASK-1:0]        cfg_filter_rule_mask;   // PL reg outputs to control the selection of filter rules that are designed in radm_filter*

input   [NHQ-1:0]               flt_q_hv;               // Header from TLP alignment block is valid (Start of packet)
input   [NHQ*(HW+ADDR_PAR_WD)-1:0]    flt_q_header;           // Packet header information.
input   [NHQ -1:0]              flt_q_dv;                   // Data from TLP alignment block is valid
input   [DW+DATA_PROT_WD-1:0]   flt_q_data;             // Packet data.
input   [NW-1:0]                flt_q_dwen;             // DWord Enable for Data Interface.
input   [NHQ-1:0]               flt_q_eot;              // Indicate end of packet
input   [NHQ-1:0]               flt_q_dllp_abort;       // Data Link Layer abort. (Recall packet in store-and-forward mode.)
input   [NHQ-1:0]               flt_q_tlp_abort;        // Transaction Layer abort (Malformed TLP, etc.)  Flow Control Credits are still returned for pkts w/ this type of abort.
input   [NHQ-1:0]               flt_q_ecrc_err;         // Transaction Layer ECRC Error indication.
input   [NHQ*3-1:0]             flt_q_tlp_type;         // FLT output to indicate the type of the TLP received. 001 -- posted, 010 -- Non posted, 100 -- Completion
input   [NHQ*SEG_WIDTH-1:0]     flt_q_seg_num;          // segment number
input   [NHQ*3-1:0]             flt_q_vc;               // VC number
input   [NHQ-1:0]               flt_q_parerr;

input   [NUM_SEGMENTS-1:0]      hdrq_seg_pkt_avail;
input   [NUM_SEGMENTS-1:0]      hdrq_full;              // Segment buffer output header queue full inidcation per VC per type that is not bypassed
input   [NUM_SEGMENTS-1:0]      hdrq_full_m_1;          // Segment buffer output header queue full -1 inidcation per VC per type that is not bypassed

input   [NUM_SEGMENTS-1:0]       dataq_full;             // Segment buffer output data queue full inidcation per VC per type that is not bypassed
input   [NUM_SEGMENTS-1:0]       dataq_full_m_1;         // Segment buffer output data queue full -1 inidcation per VC per type that is not bypassed
output  [NHQ-1:0]               hdrq_wr_en;             // header segment buffer write enable
output  [NHQ-1:0]               hdrq_wr_start;          // header segment buffer write start
output  [NHQ-1:0]               hdrq_wr_keep;           // header segment buffer write completed a TLP with a good end


output  [NHQ*SEG_WIDTH-1:0]     hdrq_wr_seg_num;        // header segment buffer write segment number
output  [NHQ*RADM_SBUF_HDRQ_WD-1 :0]hdrq_wr_data;           // header segment buffer write data
output  [NHQ*3-1 :0]            hdrq_wr_type;           // header queue write on what type of the queue. 001-- Posted, 010-- NON posted, 100 -- CPL
output  [NHQ*3-1 :0]            hdrq_wr_vc;             // VC number of current enqueue tlp
output  [NHQ-1:0]               hdrq_wr_4trgt0;         // TLP destinates to target0 interface
output  [NHQ-1:0]               hdrq_wr_4tlp_abort;     // TLP destinates to trash
output  [NHQ-1:0]               hdrq_wr_relax_ordr;     // Not sure if this should really be here
output  [NDQ-1:0]               dataq_wr_en;            // data segment buffer write enable
output  [NDQ-1:0]               dataq_wr_start;         // data segment buffer write start of a TLP
output  [NDQ-1:0]               dataq_wr_keep;          // data segment buffer write complted a TLP with a good end
output  [NDQ-1:0]               dataq_wr_drop;          // data segment buffer write abort.  Used instead of keep to abort current pkt

output  [NDQ*SEG_WIDTH-1:0]     dataq_wr_seg_num;       // data segment buffer write segment number
output  [NDQ*RADM_SBUF_DATAQ_WD-1:0] dataq_wr_data;     // data segment buffer write data


output  [NVC-1:0]               radm_qoverflow;         // per VC indication for queue overflow
output                          radm_inq_parerr;

// bypass interface designed for TLP that are configured to bypass the queue
output  [TRGT_DATA_WD-1:0]      radm_bypass_data;       // bypass request TLP data
output  [NHQ*RADM_P_HWD-1:0]    radm_bypass_hdr;        // bypass request TLP hdr
output  [NW-1:0]                radm_bypass_dwen;       // bypass request TLP dword enable for the data bus
output  [NHQ-1:0]               radm_bypass_dv;         // bypass TLP data valid
output  [NHQ-1:0]               radm_bypass_hv;         // bypass TLP hdr valid
output  [NHQ-1:0]               radm_bypass_eot;        // bypass TLP end of TLP
output  [NHQ-1:0]               radm_bypass_dllp_abort; // bypass TLP abort
output  [NHQ-1:0]               radm_bypass_tlp_abort;  // bypass DLLP abort
output  [NHQ-1:0]               radm_bypass_ecrc_err;   // bypass TLP with ECRC error

reg     [NVC-1:0]               radm_qoverflow;         // per VC indication for queue overflow


// aux wire to decouple internal logic from RAS. If RAS is used chk_flt_q_data is the output of the 
// bus_protect_chk module. Otherwise, it's just a feedthrough for flt_q_data
wire [DW+DATA_PROT_WD-1:0]   chk_flt_q_data;             // Packet data.
wire [HW+ADDR_PAR_WD-1:0]    chk_flt_q_header;           // Packet header information.
wire [ADDR_PAR_WD-1:0]       chk_flt_q_header_syndout_unc;
wire [DATA_PROT_WD-1:0]      chk_flt_q_data_syndout_unc;

wire flt_q_data_err_detect;
wire flt_q_data_err_multpl;
wire flt_q_header_err_detect;
wire flt_q_header_err_multpl;

  assign chk_flt_q_header = flt_q_header;
  assign chk_flt_q_data   = flt_q_data;


reg     [TRGT_DATA_WD-1:0]      radm_bypass_data;       // bypass request TLP data

// wire    [NHQ*TRGT_HDR_WD-1:0]   radm_bypass_hdr;        // bypass request TLP hdr 
// aux varibale to decouple radm_bypass_hdr from the use of RAS
reg     [NHQ*RADM_P_HWD-1:0]    radm_bypass_hdr;        // bypass request TLP hdr - further manipulation is done in radm_xx so protection is generated there
reg     [NW-1:0]                radm_bypass_dwen;       // bypass request TLP dword enable for the data bus
reg     [NHQ-1:0]               radm_bypass_dv;         // bypass TLP data valid
reg     [NHQ-1:0]               radm_bypass_hv;         // bypass TLP hdr valid
reg     [NHQ-1:0]               radm_bypass_eot;        // bypass TLP end of TLP
reg     [NHQ-1:0]               radm_bypass_dllp_abort; // bypass TLP abort
reg     [NHQ-1:0]               radm_bypass_tlp_abort;  // bypass DLLP abort
reg     [NHQ-1:0]               radm_bypass_ecrc_err;   // bypass TLP with ECRC error

// ---------------------------------------------------------------------------------------
// Internal Signal Declaration
// ---------------------------------------------------------------------------------------

wire    [NVC-1:0]               p_tlp_bypass_en;        // posted bypass enable per VC
wire    [NVC-1:0]               np_tlp_bypass_en;       // non-posted bypass enable per VC
wire    [NVC-1:0]               cpl_tlp_bypass_en;      // completion bypass enable per VC
wire                            tlp_bypass_en;
reg                             tlp_bypass_en_latched;
wire                            tlp_cutthru_en;
wire    [SEG_WIDTH -1 :0]       curnt_segnum;
wire    [SEG_WIDTH -1 :0]       curnt_dataq_segnum;
reg     [SEG_WIDTH -1 :0]       latchd_hdrq_segnum;
reg     [SEG_WIDTH -1 :0]       latchd_dataq_segnum;

wire                            valid_hdrq_wr;
wire                            valid_dataq_wr;
wire                            destination_abort;
reg                             latchd_overflow;

wire                            curnt_hdr_full_m_1;

wire                            curnt_data_full_m_1;
wire                            curnt_overflow;

wire                            int_hdrq_wr_en;
wire                            int_hdrq_wr_start;
wire                            int_hdrq_wr_keep;
wire                            int_hdrq_wr_one_cycle_pkt;

wire    [SEG_WIDTH-1:0]         int_hdrq_wr_seg_num;
wire    [2:0]                   int_hdrq_wr_type;
wire    [2:0]                   int_hdrq_wr_vc;
wire                            int_hdrq_wr_4trgt0;
wire                            int_hdrq_wr_4tlp_abort;
wire                            int_hdrq_wr_relax_ordr;
wire    [RADM_SBUF_HDRQ_WD-SBUF_HDR_PROT_WD-1 :0] next_hdrq_wr_data;  // header segment buffer write data
wire    [RADM_P_HWD-1 :0]            int_hdrq_wr_data;                // header segment buffer write data
wire    [RADM_SBUF_HDRQ_CTRL_WD-1:0] int_hdrq_ctrl_bits;              // Internal control bits to be stored in the RAM alongside the data
wire    [RADM_SBUF_HDRQ_WD-1:0] tmp_hdrq_wr_data;                     // header segment buffer write data

wire                            int_dataq_wr_en;
wire                            int_dataq_wr_start;
wire                            int_dataq_wr_keep;
wire                            int_dataq_wr_drop;
wire    [SEG_WIDTH-1:0]         int_dataq_wr_seg_num;

wire    [RADM_SBUF_DATAQ_WD-SBUF_DATA_PROT_WD-1:0] next_dataq_wr_data;  // data segment buffer write data
wire    [DW-1:0]                                   int_dataq_wr_data;   // data segment buffer write data
wire    [RADM_SBUF_DATAQ_CTRL_WD-1:0]              int_dataq_ctrl_bits; // Internal control bits to be stored in the RAM alongside the data
wire    [RADM_SBUF_DATAQ_WD-1:0]                   tmp_dataq_wr_data;   // data segment buffer write data

wire    [2:0]                   curnt_vc;
wire                            clkd_hdrq_wr_en;            // header segment buffer write enable
wire                            clkd_hdrq_wr_start;         // header segment buffer write start
wire                            clkd_hdrq_wr_keep;          // header segment buffer write completed a TLP with a good end

wire                            clkd_dataq_wr_en;           // data segment buffer write enable
wire                            clkd_dataq_wr_start;        // data segment buffer write start of a TLP
wire                            clkd_dataq_wr_keep;         // data segment buffer write complted a TLP with a good end
wire                            clkd_dataq_wr_drop;         // data segment buffer write abort.  Used instead of keep to abort current pkt
wire                            clkd_eot;
wire                            clkd_bad_eot;

reg     [NVC-1:0]               radm_qoverflow_int_data;    // per VC indication for queue overflow
wire    [NVC-1:0]               radm_qoverflow_int_ls;      // per VC indication for queue overflow

reg                             dlyd_hv;


// ---------------------------------------------------------------------------------------
// Internal Design Section
// ---------------------------------------------------------------------------------------

// this signal is only needed when writing the header must be delayed due to forecasting the eot
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        dlyd_hv             <= #TP 1'b0;
    else
            dlyd_hv         <= #TP 1'b0;

assign p_tlp_bypass_en      = {
                               bypass_mode_vec[0*3+0] };

assign np_tlp_bypass_en     = {
                               bypass_mode_vec[0*3+1] };

assign cpl_tlp_bypass_en    = {
                               bypass_mode_vec[0*3+2] };


assign  destination_abort       = chk_flt_q_header[`FLT_Q_DESTINATION_RANGE] == `FLT_DESTINATION_TRASH;

wire                            flt_q_tlp_inprogress;
reg                             latchd_hv;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        latchd_hv               <= #TP 1'b0;
    else
        latchd_hv               <= #TP (flt_q_eot) ? 1'b0
                                                    : flt_q_hv || latchd_hv;

assign  flt_q_tlp_inprogress    = flt_q_hv || latchd_hv;

assign  curnt_vc = flt_q_vc;
// determine the current vc number

// latch in tlp_bypass_en because the flt_q_tlp_type is only valid on hv
always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n) begin
      tlp_bypass_en_latched <= #TP 0;
    end else if (flt_q_hv) begin
      tlp_bypass_en_latched <= #TP tlp_bypass_en;
    end
end


reg     [NUM_SEGMENTS-1:0]      hdrq_seg_pkt_avail_d;
// register hdrq_seg_pkt_avail to help timing
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        hdrq_seg_pkt_avail_d    <= #TP 1'b0;
    else
        hdrq_seg_pkt_avail_d    <= #TP hdrq_seg_pkt_avail;

// Indicate that the current packet is at the head of the queue
wire                            curnt_is_head_pkt;
reg                             latchd_is_head_pkt;
wire                            curnt_hdr_pkt_avail;
assign  curnt_hdr_pkt_avail     = get_curnt_segnum_val(hdrq_seg_pkt_avail_d,curnt_segnum);

assign  curnt_is_head_pkt       = (flt_q_hv && !tlp_bypass_en) ? !curnt_hdr_pkt_avail : latchd_is_head_pkt;

// remember if the current packet was at the head of the queue when we started storing it
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        latchd_is_head_pkt      <= #TP 1'b1;
    else
        if (tlp_cutthru_en)
            latchd_is_head_pkt      <= #TP (flt_q_hv) ? !curnt_hdr_pkt_avail
                                           : (!curnt_hdr_pkt_avail && int_dataq_wr_en) ? 1'b1
                                             : latchd_is_head_pkt;

wire                            became_head_pkt;                        // Indicates that this packet is now the only packet in the queue

assign  became_head_pkt         = !latchd_is_head_pkt && !curnt_hdr_pkt_avail
                                   && tlp_cutthru_en                    // restrict to only cut-thru packets
                                   && int_dataq_wr_en                       // align this with a data write
                                   && (flt_q_tlp_inprogress)            // only when we are in the middle of a packet
                                   && !flt_q_hv;                        // don't trigger when we start a new packet (we could be changing
                                                                        // sequence numbers which will cause a false trigger


// Indicate if the current TLP is associated with a bypassed VC & type
assign  tlp_bypass_en           = (flt_q_hv) ? get_tlp_mode_en(bypass_mode_vec,curnt_vc,flt_q_tlp_type) : tlp_bypass_en_latched;

// Indicate if the current TLP is associated with a cut_thru VC & type
assign  tlp_cutthru_en          = get_tlp_mode_en(cutthru_mode_vec,curnt_vc,flt_q_tlp_type);

// determine the current segment number
assign  curnt_segnum            = flt_q_seg_num;

// the dataq segment number can't change unless data is written to it otherwise it will mess up the SBC's full/empty signals
assign  curnt_dataq_segnum      = ( valid_dataq_wr ) ? curnt_segnum : latchd_dataq_segnum;

wire                            good_eot;
wire                            bad_eot;
// when it is in cut through mode of the type of TLP or we have not dllp abort
assign  good_eot                = (flt_q_eot) && ( !flt_q_dllp_abort || (tlp_cutthru_en && curnt_is_head_pkt) );
assign  bad_eot                 = (flt_q_eot) && !good_eot;

// write the header queue at the eot cycle when store-n-fwd mode
// write the header queue at the hv cycle when cut-through mode
// Do not write anything when bypass mode
assign valid_hdrq_wr  = became_head_pkt || (                                     // if this happens we need to write the header
                                          (tlp_cutthru_en & curnt_is_head_pkt) ? (!tlp_bypass_en & ( (flt_q_hv & (flt_q_eot | valid_dataq_wr) )
                                                                                                   | (dlyd_hv & valid_dataq_wr) ))
                                                                               : (!tlp_bypass_en & flt_q_eot
                                                                                 & ( !flt_q_dllp_abort || (tlp_cutthru_en && curnt_is_head_pkt && !dlyd_hv) ))
                                          );

always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n)
        latchd_hdrq_segnum      <= #TP 0;
    else if (valid_hdrq_wr)
        latchd_hdrq_segnum      <= #TP curnt_segnum;
end

always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n)
        latchd_dataq_segnum     <= #TP 0;
    else if (valid_dataq_wr)
        latchd_dataq_segnum     <= #TP curnt_segnum;
end


// Do not write anything when bypass mode
// Write all incoming data unless bad_eot is asserted
assign  valid_dataq_wr          = !tlp_bypass_en && flt_q_dv && !bad_eot ;

// ------------------------------------------------------------
// Output drives
// ------------------------------------------------------------
//
wire                   bypass_parerr;
assign bypass_parerr = 0;

// Bypass Output Mux
always @(*)
begin
    if (tlp_bypass_en) begin
        radm_bypass_hv          = flt_q_hv;
        radm_bypass_dv          = flt_q_dv;
        radm_bypass_eot         = flt_q_eot;
        radm_bypass_dllp_abort  = flt_q_dllp_abort;
        radm_bypass_tlp_abort   = flt_q_tlp_abort | destination_abort;
        radm_bypass_ecrc_err    = flt_q_ecrc_err;
    end else begin
        radm_bypass_hv          = 1'b0;
        radm_bypass_dv          = 1'b0;
        radm_bypass_eot         = 1'b0;
        radm_bypass_dllp_abort  = 1'b0;
        radm_bypass_tlp_abort   = 1'b0;
        radm_bypass_ecrc_err    = 1'b0;
    end

    radm_bypass_dwen            = flt_q_dwen;
    radm_bypass_data            = chk_flt_q_data;
    case (flt_q_tlp_type)
        3'b001 : radm_bypass_hdr = `RADM_PQ_HDR_SELECT;     // Posted
        3'b010 : radm_bypass_hdr = `RADM_NPQ_HDR_SELECT;    // Non-Posted
        3'b100 : radm_bypass_hdr = `RADM_CPLQ_HDR_SELECT;   // Completion
        default: radm_bypass_hdr = `RADM_CPLQ_HDR_SELECT;
    endcase
end


// hdr segment buffer control interface
assign  int_hdrq_wr_en              = valid_hdrq_wr;
assign  int_hdrq_wr_start           = int_hdrq_wr_en;
assign  int_hdrq_wr_keep            = became_head_pkt
                                        | ( (tlp_cutthru_en) ? int_hdrq_wr_en : !tlp_bypass_en && good_eot );
assign  int_hdrq_wr_seg_num         = ( valid_hdrq_wr ) ? curnt_segnum : latchd_hdrq_segnum;
assign  int_hdrq_wr_type            = flt_q_tlp_type;
assign  int_hdrq_wr_vc              = curnt_vc;

assign  int_hdrq_wr_4trgt0          = (chk_flt_q_header[`RADM_Q_DESTINATION_RANGE] == `FLT_DESTINATION_TRGT0) ;
assign  int_hdrq_wr_4tlp_abort     = (flt_q_tlp_abort | destination_abort) && (!tlp_cutthru_en);  // when store forward, we need to notify external logic that order queue has just granted a non-trashed TLP

// Relaxed order bit is the upper bit of the Attribute field
assign  int_hdrq_wr_relax_ordr      = (chk_flt_q_header[`FLT_Q_ATTR_FO + 1]) ;

// When header queue is full such that header is not written in, then data
// queue should not be written for the consistency
// therefore, the write enable of the data queue is related to the hdr
// queue not full
assign  int_dataq_wr_en             = valid_dataq_wr;


assign  int_dataq_wr_start          = valid_dataq_wr && flt_q_hv;

assign  int_dataq_wr_keep           = ((tlp_cutthru_en & curnt_is_head_pkt) | became_head_pkt) ? int_dataq_wr_en
                                                    : valid_dataq_wr && !tlp_bypass_en && good_eot;

// Add the apropriate control signals to the header and data busses


    assign int_hdrq_ctrl_bits[RADM_SBUF_HDRQ_CTRL_WD - RADM_TLP_ABORT_NEG_OFFSET +1]   = (flt_q_tlp_abort[0] | destination_abort);
    assign int_dataq_ctrl_bits[RADM_SBUF_DATAQ_CTRL_WD - RADM_TLP_ABORT_NEG_OFFSET  ]  = (flt_q_tlp_abort[0] | destination_abort );

    assign int_dataq_ctrl_bits[RADM_SBUF_DATAQ_CTRL_WD - RADM_EOT_NEG_OFFSET]     = flt_q_eot[0];

// select the correct field from flt_q_header based on the type of packet
    assign int_hdrq_wr_data [RADM_P_HWD-1:0]        = (flt_q_tlp_type[0]) ? `RADM_PQ_HDR_SELECT  :
                                                      (flt_q_tlp_type[1]) ? `RADM_NPQ_HDR_SELECT :
                                                                            `RADM_CPLQ_HDR_SELECT;

    assign int_dataq_wr_data[DW-1:0]                = chk_flt_q_data[DW-1:0];


assign int_dataq_wr_seg_num = curnt_dataq_segnum ;


  assign next_hdrq_wr_data = {int_hdrq_ctrl_bits,int_hdrq_wr_data};


  assign next_dataq_wr_data = {int_dataq_ctrl_bits, int_dataq_wr_data};  


parameter N_DELAY_CYCLES = REGOUT ? 1 : 0;
parameter DATAPATH_WIDTH = 3 + SEG_WIDTH + 
                           (RADM_SBUF_HDRQ_WD-SBUF_HDR_PROT_WD) + 3 + 3 + 3 +
                           4 + SEG_WIDTH + (RADM_SBUF_DATAQ_WD-SBUF_DATA_PROT_WD)  + 1;

delay_n

#(N_DELAY_CYCLES, DATAPATH_WIDTH) u_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ( { int_hdrq_wr_en, int_hdrq_wr_start, int_hdrq_wr_keep,
                    int_hdrq_wr_seg_num,
                    next_hdrq_wr_data, int_hdrq_wr_type, int_hdrq_wr_vc, int_hdrq_wr_4trgt0, int_hdrq_wr_4tlp_abort,
                    int_hdrq_wr_relax_ordr,
                    int_dataq_wr_en, 
                    int_dataq_wr_start, int_dataq_wr_keep, bad_eot,
                    int_dataq_wr_seg_num, next_dataq_wr_data, flt_q_eot }),
    .dout       ( { clkd_hdrq_wr_en, clkd_hdrq_wr_start, clkd_hdrq_wr_keep,
                    hdrq_wr_seg_num,
                    tmp_hdrq_wr_data[0 +: RADM_SBUF_HDRQ_WD-SBUF_HDR_PROT_WD], hdrq_wr_type, hdrq_wr_vc, hdrq_wr_4trgt0, hdrq_wr_4tlp_abort,
                    hdrq_wr_relax_ordr,
                    clkd_dataq_wr_en,
                    clkd_dataq_wr_start, clkd_dataq_wr_keep, clkd_bad_eot,
                    dataq_wr_seg_num, 
                                        tmp_dataq_wr_data[0 +: RADM_SBUF_DATAQ_WD-SBUF_DATA_PROT_WD],
                    clkd_eot })
);







reg latchd_start;
wire curnt_start;
wire    overflow_drop;
assign  curnt_hdr_full_m_1          = get_curnt_segnum_val(hdrq_full_m_1,hdrq_wr_seg_num);

assign  curnt_data_full_m_1         = get_curnt_segnum_val(dataq_full_m_1,dataq_wr_seg_num);

assign  curnt_overflow              = (clkd_hdrq_wr_en & curnt_hdr_full_m_1 ) | (clkd_dataq_wr_en & curnt_data_full_m_1) ;

// drop the current pkt if an overflow occurs to keep the pointers from becomming equal
assign  overflow_drop               = curnt_overflow & !latchd_overflow;

// inhibit the writes based on full.
assign  hdrq_wr_en      = !curnt_overflow && !latchd_overflow && clkd_hdrq_wr_en;
assign  hdrq_wr_start   = !curnt_overflow && !latchd_overflow && clkd_hdrq_wr_start;
assign  hdrq_wr_keep    = !curnt_overflow && !latchd_overflow && clkd_hdrq_wr_keep;
assign  dataq_wr_en     = !curnt_overflow && !latchd_overflow && clkd_dataq_wr_en;
assign  dataq_wr_start  = !curnt_overflow && !latchd_overflow && clkd_dataq_wr_start;
assign  dataq_wr_keep   = !curnt_overflow && !latchd_overflow && clkd_dataq_wr_keep;
// Only drop if we actually started.
assign  dataq_wr_drop   = (clkd_bad_eot || (curnt_overflow || latchd_overflow) && clkd_eot) && (curnt_start || latchd_start);

// Detect when a normal start occurs
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        latchd_start    <= #TP 1'b0;
    end else begin
        if ( clkd_eot || clkd_bad_eot) begin
            latchd_start    <= #TP 1'b0;
        end else if ( !curnt_overflow && !latchd_overflow && clkd_dataq_wr_start ) begin
            latchd_start    <= #TP 1'b1;
        end
    end
assign curnt_start = !curnt_overflow && !latchd_overflow && clkd_dataq_wr_start;

// Clocked to help timing
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        latchd_overflow          <= #TP 1'b0;
    else
        if ( clkd_eot )
            latchd_overflow          <= #TP 1'b0;
        else if ( curnt_overflow )
            latchd_overflow          <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        radm_qoverflow          <= #TP 0;
    else
        radm_qoverflow          <= #TP radm_qoverflow_int_ls;

// radm_qoverflow_int_data is NVC wide to ease generation of
// radm_qoverflow_int_ls
always @(*) begin : OVERFLOW
  radm_qoverflow_int_data = 0;
  radm_qoverflow_int_data[0] = ((latchd_overflow | curnt_overflow)
                                  && !clkd_bad_eot && clkd_eot && !hdrq_wr_4tlp_abort) ;
end

assign radm_qoverflow_int_ls   = overflow_ls(radm_qoverflow_int_data, hdrq_wr_vc);  // excluded error reported from filter

wire data_par_err;
wire hdr_par_err;
wire inq_par_err;
assign data_par_err = 0;
assign hdr_par_err  = 0;
assign inq_par_err  = 0;
assign radm_inq_parerr = 0;

wire  [NHQ*RADM_SBUF_HDRQ_WD-1 :0] hdrq_wr_data;
wire  [NDQ*RADM_SBUF_DATAQ_WD-1:0] dataq_wr_data;

assign hdrq_wr_data  = tmp_hdrq_wr_data;
assign dataq_wr_data = tmp_dataq_wr_data;

function automatic [NVC-1:0]  overflow_ls;
    input [NVC-1:0] overflow_data;
    input [2:0]     ls_val;
begin
    overflow_ls = {NVC{1'b0}};
    case (ls_val)
     3'h0: overflow_ls = overflow_data << 0;








    endcase // case(hdrq_wr_vc)
end
endfunction

// This functions slices an array.  equivolent to seg_vec[curnt_segnum]
function automatic                    get_curnt_segnum_val;
input   [NUM_SEGMENTS-1:0]   seg_vec;
input   [SEG_WIDTH -1 :0]    curnt_segnum;

begin
    get_curnt_segnum_val = 0;

    case (curnt_segnum)
            0 :  get_curnt_segnum_val = seg_vec[0 ];
            1 :  get_curnt_segnum_val = seg_vec[1 ];
            2 :  get_curnt_segnum_val = seg_vec[2 ];
            default: get_curnt_segnum_val = seg_vec[0];
    endcase


end
endfunction

function  automatic            get_tlp_mode_en;
input  [(NVC*3)-1:0]  mode_vec;
input          [2:0]  curnt_vc;
input          [2:0]  flt_q_tlp_type;
begin
    get_tlp_mode_en = 1'b0;

    if  (flt_q_tlp_type[0]) begin  // p
        case (curnt_vc)
     3'b000:  get_tlp_mode_en  = mode_vec[0*3+0];







           default:  get_tlp_mode_en = 1'b0;
        endcase // case
    end else if (flt_q_tlp_type[1]) begin  // np
        case (curnt_vc)
     3'b000:  get_tlp_mode_en  = mode_vec[0*3+1];







           default:  get_tlp_mode_en = 1'b0;
        endcase // case
    end else if (flt_q_tlp_type[2]) begin  // cpl
        case (curnt_vc)
     3'b000:  get_tlp_mode_en  = mode_vec[0*3+2];







           default:  get_tlp_mode_en = 1'b0;
        endcase // case
    end
end
endfunction



// spyglass enable_block W116
endmodule

