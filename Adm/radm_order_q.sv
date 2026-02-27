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
// ---    $DateTime: 2018/08/30 02:24:02 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_order_q.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Select what's next to go out within one VC.
// --- 2 Order selection modes:
// --- (1) Preserved order - using tags, keep transactions ordered as in table
// ---     4-14 of the PCIE 1.0a spec.
// --- (2) Strict priority - Posted -> Completion -> Non-Posted
// --- Also need to take into considered the relaxed order bit.  If it's on,
// --- then order doesn't matter anymore, I think..
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module radm_order_q(
// --- Inputs ---
    core_clk,
    core_rst_n,
    vc_num,
    cfg_radm_order_rule,
    cfg_order_rule_ctrl,
    bypass_mode_vec,
    hdrq_wr_keep,
    trgt0_radm_halt,
    trgt1_radm_halt,

    dataq_wr_keep,
    hdrq_wr_type,
    hdrq_wr_vc,
    hdrq_wr_relax_ordr,
    hdrq_wr_4trgt0,
    hdrq_wr_4tlp_abort,
    rd_ackd,

// --- Outputs ---
    rd_p_valid,
    rd_np_valid,
    rd_cpl_valid,
    rd_4trgt0,
    rd_4_tlp_abort,
    rd_tlp_w_pyld,
    radm_pend_cpl_so
);

parameter INST              = 0;                        // The uniquifying parameter for each port logic instance.
parameter INT_RADM_PQ_HDP   = `RADM_PQ_HDP_VC0;         // Order queue depth (Posted)
parameter INT_RADM_NPQ_HDP  = `RADM_NPQ_HDP_VC0;        // Order queue depth (Non-Posted)
parameter INT_RADM_CPLQ_HDP = `RADM_CPLQ_HDP_VC0;       // Order queue depth (Completion)
parameter RADM_PQ_HPW       = `RADM_PQ_HPW_VC0;         // Order queue pointer width (Posted)
parameter RADM_NPQ_HPW      = `RADM_NPQ_HPW_VC0;        // Order queue pointer width (Non-Posted)
parameter RADM_CPLQ_HPW     = `RADM_CPLQ_HPW_VC0;       // Order queue pointer width (Completion)
parameter P_ORDQ_WD         = `CX_P_ORDQ_WD_VC0;        // Order queue width (Posted)
parameter NP_ORDQ_WD        = `CX_NP_ORDQ_WD_VC0;       // Order queue width (Non-Posted)
parameter CPL_ORDQ_WD       = `CX_CPL_ORDQ_WD_VC0;      // Order queue width (Completion)
parameter NL                = `CX_NL;                   // Max number of lanes supported
parameter NB                = `CX_NB;                   // Number of symbols (bytes) per clock cycle
parameter NW                = `CX_NW;                   // Number of 32-bit dwords handled by the datapath each clock.
parameter NVC               = `CX_NVC;                  // Number of VC designed to support
parameter NHQ               = `CX_NHQ;                  // Number of Header Queues per VC
parameter NDQ               = `CX_NDQ;                  // Number of Data Queues per VC
parameter DW                = (32*NW);                  // Width of datapath in bits.
parameter HW                = `FLT_Q_HDR_WIDTH;         // Header width
parameter P_TYPE            = 0;
parameter NP_TYPE           = 1;
parameter CPL_TYPE          = 2;

parameter TP                = `TP;                      // Clock to Q delay (simulator insurance)

parameter NUM_SEGMENTS      = `CX_NUM_SEGMENTS;
parameter SEG_WIDTH         = `CX_SEG_WIDTH;

parameter RADM_PQ_HDP       = |INT_RADM_PQ_HDP   ? INT_RADM_PQ_HDP   : 1;    // Order queue depth (Posted)
parameter RADM_NPQ_HDP      = |INT_RADM_NPQ_HDP  ? INT_RADM_NPQ_HDP  : 1;    // Order queue depth (Non-Posted)
parameter RADM_CPLQ_HDP     = |INT_RADM_CPLQ_HDP ? INT_RADM_CPLQ_HDP : 1;    // Order queue depth (Completion)

// -------------------------------- Inputs -------------------------------------
input                   core_clk;                   // Core clock
input                   core_rst_n;                 // Core system reset
input   [2:0]           vc_num;

input                   cfg_radm_order_rule;        // Indicates what scheme the order queue selection mechanism should be used
                                                    // Currently there are two  scheme used, 1'b1 for order preserved scheme,
                                                    // 1'b0 used for strict priority scheme
input   [1:0]           cfg_order_rule_ctrl;        // cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC 
input   [2:0]           bypass_mode_vec;            // Indicates which queues are in bypass mode. ??1-- Posted, ?1?-- NON posted, 1?? -- CPL
input   [2:0]           trgt0_radm_halt;            // trgt0 back pressure signal
input   [2:0]           trgt1_radm_halt;            // trgt1 back pressure signal

input   [NDQ-1:0]       dataq_wr_keep;              // data segment buffer write complted a TLP with a good end

input   [NHQ-1:0]       hdrq_wr_keep;               // header segment buffer write completed a TLP with a good end
input   [NHQ*3-1:0]     hdrq_wr_type;               // header queue write on what type of the queue. 001-- Posted, 010-- NON posted, 100 -- CPL
input   [NHQ*3-1:0]     hdrq_wr_vc;                 // current enqueue TLP's VC number
input   [NHQ-1:0]       hdrq_wr_relax_ordr;         // TLP's relax order bit
input   [NHQ-1:0]       hdrq_wr_4trgt0;             // TLP destinates to target0 interface
input   [NHQ-1:0]       hdrq_wr_4tlp_abort;         // TLP destinates to trash

input                   rd_ackd;                    // Next request has been accepted after VC arbitration

// -------------------------------- Outputs ------------------------------------
output                  rd_p_valid;                 // Read Posted type next
output                  rd_np_valid;                // Read Non-Posted type next
output                  rd_cpl_valid;               // Read Completion type next
output                  rd_4trgt0;                  // This read is for TRGT0
output                  rd_4_tlp_abort;
output                  rd_tlp_w_pyld;              // This TLP has payload
output                  radm_pend_cpl_so;           // Indicates a strongly ordered completion pending

// Output registers/wires
wire                    rd_p_valid;
wire                    rd_np_valid;
wire                    rd_cpl_valid;
reg                     rd_4trgt0;
reg                     rd_4_tlp_abort;
reg                     rd_tlp_w_pyld;
// -----------------------------------------------------------------------------
// Internal Design Section
// -----------------------------------------------------------------------------
wire pcpl_cnt_is0;
wire pcpl_cnt_lt0;
wire pnp_cnt_is0;
wire pnp_cnt_lt0;
wire cplnp_cnt_is0;
wire cplnp_cnt_lt0;

wire p_4_target0;
wire np_4_target0;
wire cpl_4_target0;
wire p_4_tlp_abort;
wire np_4_tlp_abort;
wire cpl_4_tlp_abort;
wire p_1_cycle;
wire np_1_cycle;
wire cpl_1_cycle;
wire p_halt;
wire np_halt;
wire cpl_halt;
wire inc_pnp_cnt;
wire inc_pcpl_cnt;
wire inc_cplnp_cnt;
wire dec_pnp_cnt;
wire dec_pcpl_cnt;
wire dec_cplnp_cnt;

reg     p_np_tag;
reg     cpl_np_tag;
reg     p_cpl_tag;
reg  [NHQ-1:0]   np_rcvd;
reg  [NHQ-1:0]   cpl_rcvd;
reg  [NHQ-1:0]   cpl_np_rcvd;
wire    wr_pnp_tag;
wire    wr_pcpl_tag;
wire    wr_cplnp_tag;
wire    wr_np_tag;
wire    wr_cpl_tag;
wire    wr_npcpl_tag;
wire    rd_pnp_tag_p1;
wire    rd_pcpl_tag_p1;
wire [2:0] curnt_output;

wire [NHQ-1:0]  curnt_wr_p;
wire [NHQ-1:0]  curnt_wr_np;
wire [NHQ-1:0]  curnt_wr_cpl;

wire   curnt_sel_p;
wire   curnt_sel_np;
wire   curnt_sel_cpl;

reg [2:0]   sel_output;

reg [1:0] cfg_order_rule_ctrl;
wire np_pass_p_if_phalted;
wire cpl_pass_p_if_phalted;
assign np_pass_p_if_phalted  = cfg_order_rule_ctrl[0];
assign cpl_pass_p_if_phalted = cfg_order_rule_ctrl[1];

assign p_halt     = p_4_target0 ? trgt0_radm_halt[P_TYPE] : trgt1_radm_halt[P_TYPE];
assign np_halt    = np_4_target0 ? trgt0_radm_halt[NP_TYPE] : trgt1_radm_halt[NP_TYPE];
assign cpl_halt   = cpl_4_target0 ? trgt0_radm_halt[CPL_TYPE] : trgt1_radm_halt[CPL_TYPE];

// Only if it's in this VC
reg [NHQ-1:0] hdrq_wr_keep_invc;
reg [NHQ-1:0] dataq_wr_keep_invc;
always @(*) begin : HDR_IN_VC
    integer i;
    for(i = 0; i < NHQ; i = i + 1) begin
        hdrq_wr_keep_invc[i] = hdrq_wr_keep[i] && vc_num == hdrq_wr_vc[3*i +: 3];
    end
end
always @(*) begin : DATA_IN_VC
    integer i;
    for(i = 0; i < NDQ; i = i + 1) begin
        dataq_wr_keep_invc[i] = dataq_wr_keep[i] && vc_num == hdrq_wr_vc[3*i +: 3];
    end
end

// -----------------------------------------------------------------------------
// --- Select used bits ---
// Posted
reg     [RADM_PQ_HPW:0]     p_wr_addr;
reg     [P_ORDQ_WD-1:0]     p_ordq [RADM_PQ_HDP-1:0];
wire    [RADM_PQ_HPW-1:0]   p_wr_ptr;
assign p_wr_ptr = p_wr_addr[RADM_PQ_HPW-1:0];
// Non-Posted
reg     [RADM_NPQ_HPW:0]    np_wr_addr;
reg     [NP_ORDQ_WD-1:0]    np_ordq [RADM_NPQ_HDP-1:0];
wire    [RADM_NPQ_HPW-1:0]  np_wr_ptr;
assign np_wr_ptr = np_wr_addr[RADM_NPQ_HPW-1:0];
// Completion
reg     [RADM_CPLQ_HPW:0]   cpl_wr_addr;
reg     [CPL_ORDQ_WD-1:0]   cpl_ordq [RADM_CPLQ_HDP-1:0];
wire    [RADM_CPLQ_HPW-1:0] cpl_wr_ptr;
assign cpl_wr_ptr = cpl_wr_addr[RADM_CPLQ_HPW-1:0];

// Note: TAG is 1 bit for NP & CPL order queue.  Can save gates below
reg    [NHQ*P_ORDQ_WD-1:0]     p_write_entry;
reg    [NHQ*NP_ORDQ_WD-1:0]    np_write_entry;
reg    [NHQ*CPL_ORDQ_WD-1:0]   cpl_write_entry;

wire p_full;
wire np_full;
wire cpl_full;

// +++ WRITING +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// --- Figuring out the TAGs ---

// P type traffic's tag is set by its relative location to NP and CPL
always @(posedge core_clk or negedge core_rst_n)
begin : P_NP_TAG_SET
    if (!core_rst_n) begin
        p_np_tag    <= #TP 1'b0;
    end
    else begin
        if (hdrq_wr_keep_invc & hdrq_wr_type[P_TYPE] & np_rcvd) begin
            p_np_tag    <= #TP !p_np_tag;
        end
    end
end

// P type traffic's tag is set by its relative location to NP and CPL
always @(posedge core_clk or negedge core_rst_n)
begin : P_CPL_TAG_SET
    if (!core_rst_n) begin
        p_cpl_tag   <= #TP 1'b0;
    end
    else begin
        if (hdrq_wr_keep_invc & hdrq_wr_type[P_TYPE] & cpl_rcvd) begin
            p_cpl_tag   <= #TP !p_cpl_tag;
        end
    end
end

// CPL type traffic's tag is set by its relative location to NP
always @(posedge core_clk or negedge core_rst_n)
begin : CPL_NP_TAG_SET
    if (!core_rst_n) begin
        cpl_np_tag  <= #TP 1'b0;
    end
    else begin
        if (hdrq_wr_keep_invc & hdrq_wr_type[CPL_TYPE] & cpl_np_rcvd) begin
            cpl_np_tag  <= #TP !cpl_np_tag;
        end
    end
end


// Set a flag to identify that there are NP or CPL between P packets
always @(posedge core_clk or negedge core_rst_n)
begin : LATCH_NP_RCVD
    if (!core_rst_n) begin
        np_rcvd <= #TP 1'b1;
    end
    else begin
        if (hdrq_wr_keep_invc & hdrq_wr_type[NP_TYPE] ) begin
            np_rcvd <= #TP 1'b1;
        end else if (hdrq_wr_keep_invc & hdrq_wr_type[P_TYPE]) begin // a posted received will reset the flag
            np_rcvd <= #TP 1'b0;
        end
    end
end

always @(posedge core_clk or negedge core_rst_n)
begin : LATCH_CPL_RCVD
    if (!core_rst_n) begin
        cpl_rcvd    <= #TP 1'b1;
    end
    else begin
        if (hdrq_wr_keep_invc & hdrq_wr_type[CPL_TYPE] ) begin
            cpl_rcvd    <= #TP 1'b1;
        end else if (hdrq_wr_keep_invc & hdrq_wr_type[P_TYPE]) begin // a posted received will reset the flag
            cpl_rcvd    <= #TP 1'b0;
        end
    end
end

// Set a flag to identify that there are NP between CPL packets
always @(posedge core_clk or negedge core_rst_n)
begin : LATCH_CPL_NP_RCVD
    if (!core_rst_n) begin
        cpl_np_rcvd <= #TP 1'b1;
    end
    else begin
        if (hdrq_wr_keep_invc & hdrq_wr_type[NP_TYPE] ) begin
            cpl_np_rcvd <= #TP 1'b1;
        end else if (hdrq_wr_keep_invc & hdrq_wr_type[CPL_TYPE]) begin // a posted received will reset the flag
            cpl_np_rcvd <= #TP 1'b0;
        end
    end
end

// Tags that are written to the order queue
assign wr_pnp_tag   = (np_rcvd)  ? (!p_np_tag)  : p_np_tag;
assign wr_pcpl_tag  = (cpl_rcvd) ? (!p_cpl_tag) : p_cpl_tag;
assign wr_cplnp_tag = (cpl_np_rcvd) ? (!cpl_np_tag) : cpl_np_tag;
assign wr_np_tag    = p_np_tag;
assign wr_cpl_tag   = p_cpl_tag;
assign wr_npcpl_tag = cpl_np_tag;

always @(*)
  begin: write_entry_PROC

    // Initialize all bits to zero
    p_write_entry                                = {P_ORDQ_WD{1'b0}};
    np_write_entry                               = {NP_ORDQ_WD{1'b0}};
    cpl_write_entry                              = {CPL_ORDQ_WD{1'b0}};

    p_write_entry[`RADM_ORDQ_PYLD_OFFSET]        = dataq_wr_keep_invc[0];
    np_write_entry[`RADM_ORDQ_PYLD_OFFSET]       = dataq_wr_keep_invc[0];
    cpl_write_entry[`RADM_ORDQ_PYLD_OFFSET]      = dataq_wr_keep_invc[0];

    p_write_entry[`RADM_ORDQ_TRGT0_OFFSET]       = hdrq_wr_4trgt0[0];
    np_write_entry[`RADM_ORDQ_TRGT0_OFFSET]      = hdrq_wr_4trgt0[0];
    cpl_write_entry[`RADM_ORDQ_TRGT0_OFFSET]     = hdrq_wr_4trgt0[0];
    p_write_entry[`RADM_ORDQ_TLP_ABORT_OFFSET]   = hdrq_wr_4tlp_abort[0];
    np_write_entry[`RADM_ORDQ_TLP_ABORT_OFFSET]  = hdrq_wr_4tlp_abort[0];
    cpl_write_entry[`RADM_ORDQ_TLP_ABORT_OFFSET] = hdrq_wr_4tlp_abort[0];

    cpl_write_entry[`RADM_ORDQ_RLXORD_OFFSET]    = hdrq_wr_relax_ordr[0];

    p_write_entry[`RADM_ORDQ_P_CLUMP_OFFSET]     = {wr_pnp_tag, wr_pcpl_tag};
    np_write_entry[`RADM_ORDQ_NP_CLUMP_OFFSET]   = {wr_npcpl_tag, wr_np_tag};
    cpl_write_entry[`RADM_ORDQ_CPL_CLUMP_OFFSET] = {wr_cpl_tag, wr_cplnp_tag};
  end // block: write_entry_PROC

// --- Writing to Order Queue ---
// Information to be saved: TLP type (N/NP/CPL), Relaxed Order, TRGT destination & payload
// Need counters on how many of each type in queue or keep track for any packets inside.
always @(posedge core_clk or negedge core_rst_n)
begin: WRITE_ORDQ
integer i,j,k;
    if (~core_rst_n) begin
        p_wr_addr   <= #TP 0;
        np_wr_addr  <= #TP 0;
        cpl_wr_addr <= #TP 0;
        for (i=0; i<RADM_PQ_HDP; i=i+1)
            p_ordq[i]      <= #TP 0;
        for (j=0; j<RADM_CPLQ_HDP; j=j+1)
            cpl_ordq[j]    <= #TP 0;
        for (k=0; k<RADM_NPQ_HDP; k=k+1)
            np_ordq[k]     <= #TP 0;
    end else begin
        // Only care if there's a new header being written in
        if (hdrq_wr_keep_invc) begin
            if(hdrq_wr_type[P_TYPE] && !p_full) begin
                    p_ordq[p_wr_ptr]    <= #TP p_write_entry;
                    if (p_wr_ptr == RADM_PQ_HDP-1) begin
                        p_wr_addr[RADM_PQ_HPW-1:0]  <= #TP 0;
                        p_wr_addr[RADM_PQ_HPW]      <= #TP ~p_wr_addr[RADM_PQ_HPW];
                    end else begin
                        p_wr_addr       <= #TP p_wr_addr + 1;
                    end
            end else if(hdrq_wr_type[CPL_TYPE] && !cpl_full) begin
                    cpl_ordq[cpl_wr_ptr]<= #TP cpl_write_entry;
                    if (cpl_wr_ptr == RADM_CPLQ_HDP-1) begin
                        cpl_wr_addr[RADM_CPLQ_HPW-1:0]  <= #TP 0;
                        cpl_wr_addr[RADM_CPLQ_HPW]      <= #TP ~cpl_wr_addr[RADM_CPLQ_HPW];
                    end else begin
                        cpl_wr_addr     <= #TP cpl_wr_addr + 1;
                    end
            end else if(hdrq_wr_type[NP_TYPE] && !np_full) begin
                    np_ordq[np_wr_ptr]  <= #TP np_write_entry;
                    if (np_wr_ptr == RADM_NPQ_HDP-1) begin
                        np_wr_addr[RADM_NPQ_HPW-1:0]    <= #TP 0;
                        np_wr_addr[RADM_NPQ_HPW]        <= #TP ~np_wr_addr[RADM_NPQ_HPW];
                    end else begin
                        np_wr_addr      <= #TP np_wr_addr + 1;
                    end
            end
        end
    end
end


// +++ READING +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// --- Decide which type to go next ---
// (0) Strict Priority Scheme
// If there's a Posted type, let that go first, unless it's halted
// (1) Preserved Order
// Follow PCIE table
// Posted
reg     [RADM_PQ_HPW:0]     p_rd_addr;
wire    [RADM_PQ_HPW-1:0]   p_rd_ptr;  // plus 1
wire    [RADM_PQ_HPW-1:0]   p_rd_ptr_p1;
wire    [P_ORDQ_WD-1:0]     p_ordq_entry;
wire    [P_ORDQ_WD-1:0]     p_ordq_entry_p1;
wire                        p_w_payload;
wire                        rd_cplnp_tag;
wire                        rd_pnp_tag;
wire                        rd_pcpl_tag;
wire                        rd_npcpl_tag;

assign p_rd_ptr             = p_rd_addr[RADM_PQ_HPW-1:0];
assign p_rd_ptr_p1          = (p_rd_ptr == (RADM_PQ_HDP-1)) ? 0 : p_rd_ptr +1;

assign p_ordq_entry         = bypass_mode_vec[P_TYPE] ? 0 : p_ordq[p_rd_ptr];
assign p_ordq_entry_p1      = bypass_mode_vec[P_TYPE] ? 0 : p_ordq[p_rd_ptr_p1];
assign p_w_payload          = p_ordq_entry[`RADM_ORDQ_PYLD_OFFSET];

    assign {rd_pnp_tag,
            rd_pcpl_tag}    = bypass_mode_vec[P_TYPE] ? 0 : p_ordq_entry[`RADM_ORDQ_P_CLUMP_OFFSET];
    assign {rd_pnp_tag_p1,
            rd_pcpl_tag_p1} = bypass_mode_vec[P_TYPE] ? 0 : p_ordq_entry_p1[`RADM_ORDQ_P_CLUMP_OFFSET];
wire p_empty;
wire p_2b_empty;
assign p_empty              = (p_wr_addr == p_rd_addr);
assign p_2b_empty           = (p_rd_ptr == RADM_PQ_HDP-1) ?
    p_wr_addr[RADM_PQ_HPW] != p_rd_addr[RADM_PQ_HPW] && p_wr_ptr == 0 :
    p_wr_addr[RADM_PQ_HPW] == p_rd_addr[RADM_PQ_HPW] && p_wr_ptr == p_rd_ptr + 1;
assign p_full               = p_wr_addr[RADM_PQ_HPW-1:0] == p_rd_addr[RADM_PQ_HPW-1:0] &&
    p_wr_addr[RADM_PQ_HPW] != p_rd_addr[RADM_PQ_HPW];
// Non-Posted
reg     [RADM_NPQ_HPW:0]    np_rd_addr;
wire    [RADM_NPQ_HPW-1:0]  np_rd_ptr;
wire    [RADM_NPQ_HPW-1:0]  np_rd_ptr_p1;
wire    [NP_ORDQ_WD-1:0]    np_ordq_entry;
wire    [NP_ORDQ_WD-1:0]    np_ordq_entry_p1;
wire                        np_w_payload;
wire                        rd_np_tag;
wire                        rd_np_tag_p1;
wire                        rd_npcpl_tag_p1;

assign np_rd_ptr            = np_rd_addr[RADM_NPQ_HPW-1:0];
assign np_rd_ptr_p1         = (np_rd_ptr == (RADM_NPQ_HDP-1)) ? 0 : np_rd_ptr +1;
assign np_ordq_entry        = bypass_mode_vec[NP_TYPE] ? 0 : np_ordq[np_rd_ptr];
assign np_ordq_entry_p1     = bypass_mode_vec[NP_TYPE] ? 0 : np_ordq[np_rd_ptr_p1];
assign np_w_payload         = np_ordq_entry[`RADM_ORDQ_PYLD_OFFSET];

    assign {rd_npcpl_tag,
            rd_np_tag}      = bypass_mode_vec[NP_TYPE] ? 0 : np_ordq_entry[`RADM_ORDQ_NP_CLUMP_OFFSET];
    assign {rd_npcpl_tag_p1,
            rd_np_tag_p1}   = bypass_mode_vec[NP_TYPE] ? 0 : np_ordq_entry_p1[`RADM_ORDQ_NP_CLUMP_OFFSET];
wire np_empty;
wire np_2b_empty;
assign np_empty             = (np_wr_addr == np_rd_addr);
assign np_2b_empty           = (np_rd_ptr == RADM_NPQ_HDP-1) ?
    np_wr_addr[RADM_NPQ_HPW] != np_rd_addr[RADM_NPQ_HPW] && np_wr_ptr == 0 :
    np_wr_addr[RADM_NPQ_HPW] == np_rd_addr[RADM_NPQ_HPW] && np_wr_ptr == np_rd_ptr + 1;
assign np_full               = np_wr_addr[RADM_NPQ_HPW-1:0] == np_rd_addr[RADM_NPQ_HPW-1:0] &&
    np_wr_addr[RADM_NPQ_HPW] != np_rd_addr[RADM_NPQ_HPW];

// Completion
reg     [RADM_CPLQ_HPW:0]   cpl_rd_addr;
wire    [RADM_CPLQ_HPW-1:0] cpl_rd_ptr;
wire    [RADM_CPLQ_HPW-1:0] cpl_rd_ptr_p1;
wire    [CPL_ORDQ_WD-1:0]   cpl_ordq_entry;
wire    [CPL_ORDQ_WD-1:0]   cpl_ordq_entry_p1;
wire                        cpl_rlx_order;
wire                        cpl_w_payload;
wire                        rd_cpl_tag;
wire                        rd_cpl_tag_p1;
wire                        rd_cplnp_tag_p1;

assign cpl_rd_ptr           = cpl_rd_addr[RADM_CPLQ_HPW-1:0];
assign cpl_rd_ptr_p1        = (cpl_rd_ptr == (RADM_CPLQ_HDP-1)) ? 0 : cpl_rd_ptr +1;
assign cpl_ordq_entry       = bypass_mode_vec[CPL_TYPE] ? 0 : cpl_ordq[cpl_rd_ptr];
assign cpl_ordq_entry_p1    = bypass_mode_vec[CPL_TYPE] ? 0 : cpl_ordq[cpl_rd_ptr_p1];
assign cpl_w_payload        = cpl_ordq_entry[`RADM_ORDQ_PYLD_OFFSET];

    assign {rd_cpl_tag,
            rd_cplnp_tag}   = bypass_mode_vec[CPL_TYPE] ? 0 : cpl_ordq_entry[`RADM_ORDQ_CPL_CLUMP_OFFSET];
    assign {rd_cpl_tag_p1,
            rd_cplnp_tag_p1}= bypass_mode_vec[CPL_TYPE] ? 0 : cpl_ordq_entry_p1[`RADM_ORDQ_CPL_CLUMP_OFFSET];
wire cpl_empty;
wire cpl_2b_empty;
assign cpl_empty            = (cpl_wr_addr == cpl_rd_addr);
assign cpl_2b_empty           = (cpl_rd_ptr == RADM_CPLQ_HDP-1) ?
    cpl_wr_addr[RADM_CPLQ_HPW] != cpl_rd_addr[RADM_CPLQ_HPW] && cpl_wr_ptr == 0 :
    cpl_wr_addr[RADM_CPLQ_HPW] == cpl_rd_addr[RADM_CPLQ_HPW] && cpl_wr_ptr == cpl_rd_ptr + 1;
assign cpl_full               = cpl_wr_addr[RADM_CPLQ_HPW-1:0] == cpl_rd_addr[RADM_CPLQ_HPW-1:0] &&
    cpl_wr_addr[RADM_CPLQ_HPW] != cpl_rd_addr[RADM_CPLQ_HPW];

// Optional order queue bits
    assign p_4_target0      = bypass_mode_vec[P_TYPE] ? 1'b1 : p_ordq_entry[`RADM_ORDQ_TRGT0_OFFSET];
    assign np_4_target0     = bypass_mode_vec[NP_TYPE] ? 1'b1 : np_ordq_entry[`RADM_ORDQ_TRGT0_OFFSET];
    assign cpl_4_target0    = bypass_mode_vec[CPL_TYPE] ? 1'b1 : cpl_ordq_entry[`RADM_ORDQ_TRGT0_OFFSET];
    assign p_4_tlp_abort    = bypass_mode_vec[P_TYPE] ? 1'b0 : p_ordq_entry[`RADM_ORDQ_TLP_ABORT_OFFSET];
    assign np_4_tlp_abort   = bypass_mode_vec[NP_TYPE] ? 1'b0 : np_ordq_entry[`RADM_ORDQ_TLP_ABORT_OFFSET];
    assign cpl_4_tlp_abort  = bypass_mode_vec[CPL_TYPE] ? 1'b0 : cpl_ordq_entry[`RADM_ORDQ_TLP_ABORT_OFFSET];

    assign cpl_rlx_order    = cpl_ordq_entry[`RADM_ORDQ_RLXORD_OFFSET];


// Select which type of TLP that are inqueued to be output
wire  p_passd_np;
wire  p_passd_cpl;
wire  cpl_passd_np;
assign   p_passd_np     = (!pnp_cnt_is0   & !pnp_cnt_lt0 );
assign   cpl_passd_np   = (!cplnp_cnt_is0 & !cplnp_cnt_lt0) ;
assign   p_passd_cpl    = (!pcpl_cnt_is0 & !pcpl_cnt_lt0);

always @(p_passd_np or cpl_passd_np or p_passd_cpl or
         p_empty or np_empty or cpl_empty or
         p_halt  or np_halt  or cpl_halt or
         cpl_rlx_order or cfg_radm_order_rule or
         np_pass_p_if_phalted or cpl_pass_p_if_phalted)
begin : SELECT_NEXT_QUEUE_TYPE
    // Order Preserved (Clump mode)
    if (cfg_radm_order_rule) begin
        // All conditions that the NP can go
        // 1: P and CPL are empty and NP is not
        // 2: pnp count is greater than 0 and cpl is empty
        // 3: pnp count and cplnp count are greater than 0
        // 4: cplnp count is greater than 0 and p is empty
        // 5: if P is halted and cplnp count are greater than 0 and prgrm_ordering_rules[0](Port Logic Reg) enabled
        if (( (p_empty & cpl_empty)                                  // condition 1
            | (p_passd_np   & cpl_empty)                             // condition 2
            | (p_passd_np   & cpl_passd_np)                          // condition 3
            | (p_empty      & cpl_passd_np)                          // condition 4
            | (p_halt       & (cpl_passd_np | cpl_empty) & np_pass_p_if_phalted) ) // condition 5
           & !np_halt & !np_empty)
            sel_output    = 3'b010;

        // All conditions that the CPL can go
        // 1: P are empty and CPL ca go
        // 2: CPL has relax order bit set and P is at halt
        // 3: pcpl count is greater than 0
        // 4: if P is halted and prgrm_ordering_rules[1](Port Logic Reg) enabled
        else if ((p_empty                                   // condition 1
                 | (cpl_rlx_order & p_halt)                 // condition 2
                 | p_passd_cpl                              // condition 3
                 | (p_halt        & cpl_pass_p_if_phalted)) // condition 4
                & !cpl_halt & !cpl_empty)
            sel_output    = 3'b100;

        // All conditions that the P can go
        else if (!p_empty & !p_halt)  // rest of the conditions that we should always allow P to go
            sel_output    = 3'b001;
        else
            sel_output    = 3'b000;  // Otherwise wait...

    end
    // Strict Priority: Posted, Completion & Non-Posted
    // If highest priority halted, everything stops except if CPL is relax order
    else begin
        if (~p_empty) begin
            // P is not halted, it goes first
            if (~p_halt)
                sel_output = 3'b001;
            // P is halted and there's a CPL with relax order
            else if (~cpl_empty & cpl_rlx_order & !cpl_halt)
                sel_output = 3'b100;
            // P is halted but there's nothing in CPL that can jump over - wait
            else
                sel_output = 3'b000;
        end
        else if (~cpl_empty & !cpl_halt)
            sel_output = 3'b100;
        else if (~np_empty & !np_halt)
            sel_output = 3'b010;
        else
            sel_output = 3'b000;
    end
end

assign curnt_output = sel_output;
always @(*)
begin : OUTPUT_COMB
  rd_tlp_w_pyld       = p_w_payload;
  rd_4trgt0           = p_4_target0;
  rd_4_tlp_abort      = p_4_tlp_abort;
  unique case (1'b1)
    sel_output[P_TYPE]:
      begin
        rd_tlp_w_pyld       = p_w_payload;
        rd_4trgt0           = p_4_target0;
      end
    sel_output[NP_TYPE]:
      begin
        rd_tlp_w_pyld       = np_w_payload;
        rd_4trgt0           = np_4_target0;
        rd_4_tlp_abort      = np_4_tlp_abort;
      end
    sel_output[CPL_TYPE]:
      begin
        rd_tlp_w_pyld       = cpl_w_payload;
        rd_4trgt0           = cpl_4_target0;
        rd_4_tlp_abort      = cpl_4_tlp_abort;
      end
    default: begin
      rd_tlp_w_pyld       = p_w_payload;
      rd_4trgt0           = p_4_target0;
      rd_4_tlp_abort      = p_4_tlp_abort;
    end
  endcase // case(1'b1)
end

always @(posedge core_clk or negedge core_rst_n)
begin : OUTPUT_LATCH
    if (~core_rst_n) begin
        p_rd_addr           <= #TP 0;
        np_rd_addr          <= #TP 0;
        cpl_rd_addr         <= #TP 0;
    end
    else begin
        // Current read request has been acknowledged, figure out next packet
        if (rd_ackd) begin
            unique case (1'b1)
              sel_output[P_TYPE]:
              begin
                if (p_rd_ptr == RADM_PQ_HDP-1) begin
                    p_rd_addr[RADM_PQ_HPW-1:0]  <= #TP 0;
                    p_rd_addr[RADM_PQ_HPW]      <= #TP ~p_rd_addr[RADM_PQ_HPW];
                end else begin
                    p_rd_addr       <= #TP p_rd_addr + 1;
                end
              end
              sel_output[NP_TYPE]:
              begin
                if (np_rd_ptr == RADM_NPQ_HDP-1) begin
                    np_rd_addr[RADM_NPQ_HPW-1:0]    <= #TP 0;
                    np_rd_addr[RADM_NPQ_HPW]        <= #TP ~np_rd_addr[RADM_NPQ_HPW];
                end else begin
                    np_rd_addr      <= #TP np_rd_addr + 1;
                end
              end
              sel_output[CPL_TYPE]:
              begin
                if (cpl_rd_ptr == RADM_CPLQ_HDP-1) begin
                    cpl_rd_addr[RADM_CPLQ_HPW-1:0]  <= #TP 0;
                    cpl_rd_addr[RADM_CPLQ_HPW]      <= #TP ~cpl_rd_addr[RADM_CPLQ_HPW];
                end else begin
                    cpl_rd_addr     <= #TP cpl_rd_addr + 1;
                end
              end
              default: begin
                p_rd_addr           <= #TP p_rd_addr;
                np_rd_addr          <= #TP np_rd_addr;
                cpl_rd_addr         <= #TP cpl_rd_addr;
              end
             endcase // case(1'b1)
        end
    end
end


assign rd_cpl_valid    = curnt_output[CPL_TYPE];
assign rd_np_valid     = curnt_output[NP_TYPE];
assign rd_p_valid      = curnt_output[P_TYPE];

// radm_pend_cpl_so: Indicates a completion without RO bit set at the head of
// the completion queue. Pulsed when the next completion will be granted before
// the next posted and that completion is strongly ordered(RO clear)
reg radm_pend_cpl_so;
reg s_cpl_so_pending;
always @(*) begin : CPL_SO_PENDING
    s_cpl_so_pending = 0;
    if(cfg_radm_order_rule) begin
        if((p_empty || p_passd_cpl) && !cpl_empty && !cpl_rlx_order) begin
            s_cpl_so_pending = 1;
        end
    end else begin
        if(p_empty && !cpl_empty && !cpl_rlx_order) begin
            s_cpl_so_pending = 1;
        end
    end
end : CPL_SO_PENDING

always @(*) begin : CPL_SO
   //Avoids pend_cpl_so when the packet is known to be aborted 
   radm_pend_cpl_so = s_cpl_so_pending && (~cpl_4_tlp_abort);
end : CPL_SO

// +++ TAG COUNTERS ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Logic to increment/decrement counters
// Increment counter when Posted tag bit changed
// Decrement counter when NP/CPL tag bit changed


genvar g_curnt_wr;
generate for(g_curnt_wr = 0; g_curnt_wr < NHQ; g_curnt_wr = g_curnt_wr + 1) begin : gen_curnt_wr
    assign curnt_wr_p[g_curnt_wr]          = hdrq_wr_keep_invc[g_curnt_wr] & hdrq_wr_type[g_curnt_wr*3+P_TYPE];
    assign curnt_wr_np[g_curnt_wr]         = hdrq_wr_keep_invc[g_curnt_wr] & hdrq_wr_type[g_curnt_wr*3+NP_TYPE];
    assign curnt_wr_cpl[g_curnt_wr]        = hdrq_wr_keep_invc[g_curnt_wr] & hdrq_wr_type[g_curnt_wr*3+CPL_TYPE];
end
endgenerate

assign curnt_sel_p         = rd_ackd & sel_output[P_TYPE];
assign curnt_sel_np        = rd_ackd & sel_output[NP_TYPE];
assign curnt_sel_cpl       = rd_ackd & sel_output[CPL_TYPE];

// rising priority of a particular type based on the counter is greater than 0.
// therefore, increment counter will get pirority raised.
assign inc_pnp_cnt         = curnt_sel_p && rd_pnp_tag_p1 != rd_pnp_tag && !p_2b_empty      // more than one entry
                             || |(curnt_wr_p & np_rcvd) && (p_empty || p_2b_empty && curnt_sel_p);                // initial condition: When a P arrived and there is clump change because a NP existed
                                                                                             // and it is received after last P served

assign inc_pcpl_cnt        = curnt_sel_p && rd_pcpl_tag_p1 != rd_pcpl_tag && !p_2b_empty   // more than one entries
                              || |(curnt_wr_p & cpl_rcvd) && (p_empty || p_2b_empty && curnt_sel_p); // initial condition: when P arrived, there is a clump change because of CPL exited
                                                                                             // and it is received after last P served
assign inc_cplnp_cnt       = curnt_sel_cpl && rd_cplnp_tag_p1 != rd_cplnp_tag && !cpl_2b_empty  // similiar to the above 2 counters
                              || |(curnt_wr_cpl & cpl_np_rcvd) && (cpl_empty || cpl_2b_empty && curnt_sel_cpl);

// lower priority of a particular type based on the counter is less than 0
// therefore, deccrement counter will lower the priority
assign dec_pnp_cnt         = curnt_sel_np && rd_np_tag_p1 != rd_np_tag && !np_2b_empty    // more than one entry and clump changed
                              || |(curnt_wr_np & ~np_rcvd) && (np_empty || np_2b_empty && curnt_sel_np);    // initial condition where there has a priority rising pending because of a clump change

assign dec_pcpl_cnt        = curnt_sel_cpl && rd_cpl_tag_p1 != rd_cpl_tag && !cpl_2b_empty  // more than one entry and clump changed
                              || |(curnt_wr_cpl & ~cpl_rcvd) && (cpl_empty || cpl_2b_empty && curnt_sel_cpl);     // initial condition where there has a priority rising pending because of a clump change

assign dec_cplnp_cnt       = curnt_sel_np && rd_npcpl_tag_p1 != rd_npcpl_tag && !np_2b_empty  // more than one entry and clump changed
                              || |(curnt_wr_np & ~cpl_np_rcvd) && (np_empty || np_2b_empty && curnt_sel_np);  // initial condition where there has a priority rising pending because of a clump change




// Update counters
// CPL counter is 1 more bit because it can go negative
reg [8:0]   pnp_cnt;
reg [8:0]   pcpl_cnt;
reg [8:0]   cplnp_cnt;
// ***** Intial value of 2, and if cnt needs to be 256
always @(posedge core_clk or negedge core_rst_n)
begin
    if (~core_rst_n) begin
        pnp_cnt     <= #TP 0;
        pcpl_cnt    <= #TP 0;
        cplnp_cnt   <= #TP 0;
    end
    else begin
        if (inc_pnp_cnt & !dec_pnp_cnt) begin
            pnp_cnt <= #TP pnp_cnt + 9'h1;
        end
        else if (dec_pnp_cnt & !inc_pnp_cnt) begin
            pnp_cnt <= #TP pnp_cnt - 9'h1;
        end

        if (inc_pcpl_cnt & !dec_pcpl_cnt) begin
            pcpl_cnt<= #TP pcpl_cnt + 9'h1;
        end
        else if (dec_pcpl_cnt & !inc_pcpl_cnt) begin
            pcpl_cnt<= #TP pcpl_cnt - 9'h1;
        end

        if (inc_cplnp_cnt & !dec_cplnp_cnt) begin
            cplnp_cnt   <= #TP cplnp_cnt + 9'h1;
        end
        else if (dec_cplnp_cnt & !inc_cplnp_cnt) begin
            cplnp_cnt  <= #TP cplnp_cnt - 9'h1;
        end

    end
end


// Counter compares
assign pcpl_cnt_is0        = (pcpl_cnt == 0);
assign pcpl_cnt_lt0        = (pcpl_cnt[8] == 1'b1);
assign pnp_cnt_is0         = (pnp_cnt == 0);
assign pnp_cnt_lt0         = (pnp_cnt[8] == 1'b1);
assign cplnp_cnt_is0       = (cplnp_cnt == 0);
assign cplnp_cnt_lt0       = (cplnp_cnt[8] == 1'b1);

endmodule

