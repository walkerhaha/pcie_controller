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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_order_mgr.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module controles the order of reading out of segment buffer
// --- Its main functions are:
// ---    (1) provide the information to direct outq manager module to read
// ---        segment buffer
// ---    (2) handles the incoming interface halt to assis the decision
// ---
// ---
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module radm_order_mgr(
// --- Inputs ---
    core_clk,
    core_rst_n,
    bypass_mode_vec,
    cutthru_mode_vec,
    storfwd_mode_vec,
    cfg_radm_order_rule,
    cfg_order_rule_ctrl,
    cfg_radm_strict_vc_prior,
    trgt0_radm_halt,
    outq_trgt0_ack,
    trgt1_radm_halt,
    hdrq_wr_keep,
    hdrq_wr_type,
    hdrq_wr_vc,
    hdrq_wr_relax_ordr,
    hdrq_wr_4trgt0,
    hdrq_wr_4tlp_abort,

    dataq_wr_keep,

    req_ackd,

// --- Outputs ---
    req_rd_segnum,
    req_rd,
    req_rd_4trgt0,
    req_tlp_w_pyld,

    radm_grant_tlp_type,
    radm_trgt1_ack_tlp_np,
    radm_trgt1_ack_tlp_p,
    radm_pend_cpl_so, 
    radm_trgt0_pending
);

parameter INST          = 0;                        // The uniquifying parameter for each port logic instance.
parameter NVC           = `CX_NVC;                  // Number of VC designed to support
parameter NHQ                   = `CX_NHQ;                  // Number of Header Queues per VC
parameter NDQ                   = `CX_NDQ;                  // Number of Data Queues per VC
parameter P_TYPE        = 2'h0;
parameter NP_TYPE       = 2'h1;
parameter CPL_TYPE      = 2'h2;

parameter TP            = `TP;                      // Clock to Q delay (simulator insurance)

parameter NUM_SEGMENTS  = `CX_NUM_SEGMENTS;
parameter SEG_WIDTH     = `CX_SEG_WIDTH;

// -------------------------------- Inputs -------------------------------------
input                       core_clk;               // Core clock
input                       core_rst_n;             // Core system reset
                                                    // 3bits per VC, bit0 for bypass, bit1 for cut-through and bit2 for store and forward
input   [(NVC*3)-1:0]       bypass_mode_vec;
input   [(NVC*3)-1:0]       cutthru_mode_vec;
input   [(NVC*3)-1:0]       storfwd_mode_vec;
input   [NVC-1:0]           cfg_radm_order_rule;    // Indicates what scheme the order queue selection mechanism should be used
                                                    // Currently there are two  scheme used, 1'b1 for order reserved scheme,
                                                    // 1'b0 used for strict priority scheme
input   [15:0]              cfg_order_rule_ctrl;    // cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC 

input                       cfg_radm_strict_vc_prior;// 1 indicates strict priority, 0 indicates round roubin
input   [NVC*3-1:0]         trgt0_radm_halt;        // trgt0 back pressure signal
input                       outq_trgt0_ack;         // trgt0 request received, allow another to be selected in order_q.
input   [(NVC*3)-1:0]       trgt1_radm_halt;        // trgt1 back pressure signal (CPL, NP, P)

input   [NHQ-1:0]           hdrq_wr_keep;           // header segment buffer write completed a TLP with a good end
input   [NHQ*3-1:0]         hdrq_wr_type;           // header queue write on what type of the queue. 001-- Posted, 010-- NON posted, 100 -- CPL
input   [NHQ*3-1:0]         hdrq_wr_vc;             // current enqueue TLP's VC number
input   [NHQ-1:0]           hdrq_wr_relax_ordr;     // Transaction destinated to target0 interface
input   [NHQ-1:0]           hdrq_wr_4trgt0;         // TLP destinates to target0 interface
input   [NHQ-1:0]           hdrq_wr_4tlp_abort;     // TLP destinates to trash

input   [NDQ-1:0]           dataq_wr_keep;          // data segment buffer write complted a TLP with a good end

input                       req_ackd;

// -------------------------------- Outputs ------------------------------------
output  [SEG_WIDTH -1:0]    req_rd_segnum;
output                      req_rd;
output                      req_rd_4trgt0;
output                      req_tlp_w_pyld;

output  [(NVC*3)-1:0]       radm_grant_tlp_type;        // A vector to indicate which type&VC has been granted for the next read out of receive queue
output  [NVC-1:0]           radm_trgt1_ack_tlp_np;            // A vector to indicate which per VC NP type has been acknowledged by the receive queue VC arbiter.
output  [NVC-1:0]           radm_trgt1_ack_tlp_p;             // A vector to indicate which per VC P type has been acknowledged by the receive queue VC arbiter.
output  [NVC-1:0]           radm_pend_cpl_so;           // A vector to indicate which VCs have strongly ordered completions pending
output                      radm_trgt0_pending;         // TLP enroute from RADM prevent DBI access


// -----------------------------------------------------------------------------
// Internal Signal Declaration
// -----------------------------------------------------------------------------
wire    [NVC-1:0]           rd_tlp_w_pyld;
wire    [NVC-1:0]           rd_p_valid;
wire    [NVC-1:0]           rd_np_valid;
wire    [NVC-1:0]           rd_cpl_valid;
wire    [NVC-1:0]           rd_4trgt0;
wire    [NVC-1:0]           rd_4_tlp_abort;

wire    [NUM_SEGMENTS-1:0]  cutthru_rd_req;
wire    [NUM_SEGMENTS-1:0]  str_fwd_rd_req;
wire    [NUM_SEGMENTS-1:0]  queue_rdy_4rd;

wire    [NVC-1:0]           rd_ackd;

// -----------------------------------------------------------------------------
// Internal Design Section
// -----------------------------------------------------------------------------
// EAW  TBD Add some descriptions here


// -----------------------------------------------------------------------------
// Arbitration among VC: strict priority or round robin
//------------------------------------------------------------------------------
reg     [7:0]           last_grant;
reg     [2:0]           next_grant;
reg                     arb_result_valid;
reg                     arb_tlp_w_pyld;

reg                     arb_rd_4trgt0;
reg     [SEG_WIDTH-1:0] arb_segnum;

wire    [NVC-1:0]       valid_vc_req;
wire    [8:0]           padded_valid_vc_req;

reg     [NVC-1:0]       trgt0_p_block;
reg     [NVC-1:0]       trgt0_np_block;
reg     [NVC-1:0]       trgt0_cpl_block;
assign                  valid_vc_req =  rd_p_valid   & ~trgt0_p_block  |
                                        rd_np_valid  & ~trgt0_np_block |
                                        rd_cpl_valid & ~trgt0_cpl_block;
assign                  padded_valid_vc_req = {{9-NVC{1'b0}}, valid_vc_req};

wire                    req_rd;
wire                    req_tlp_w_pyld;
wire                    req_rd_4trgt0;
wire    [SEG_WIDTH-1:0] req_rd_segnum;

wire                    int_req_ackd;
wire                    int_ack_from_outq;
wire                    int_req_ackd_n;
wire                    int_req_rd;
wire                    int_req_tlp_w_pyld;
wire                    int_req_rd_4trgt0;
wire    [SEG_WIDTH-1:0] int_req_rd_segnum;

assign int_req_ackd             = (!req_rd || !int_req_ackd_n) && int_req_rd;
assign int_ack_from_outq        = req_ackd && req_rd;
assign int_req_rd               = arb_result_valid;
assign int_req_rd_segnum        = arb_segnum;
assign int_req_tlp_w_pyld       = arb_tlp_w_pyld;
assign int_req_rd_4trgt0        = arb_rd_4trgt0;

// When VC arbitration selects a request bound for trgt0 block any requests
// from any other VC to trgt0 until outq_trgt0_ack is seen
reg    trgt0_pending;
always @(posedge core_clk or negedge core_rst_n) begin : TRGT0_BLOCK
    if (!core_rst_n) begin
        trgt0_pending <= #TP 0;
    end else begin
        if(arb_rd_4trgt0 && int_req_ackd) begin
            trgt0_pending <= #TP 1;
        end else if(outq_trgt0_ack) begin
            trgt0_pending <= #TP 0;
        end
    end
end

wire                      radm_trgt0_pending;
assign radm_trgt0_pending = trgt0_pending || arb_rd_4trgt0 && int_req_ackd;

wire [3*NVC-1:0] int_trgt0_radm_halt;
assign int_trgt0_radm_halt = {3*NVC{trgt0_pending}} | trgt0_radm_halt;

// seperate the per type and per VC halt signals into per VC signals of each
// type. Used to block TLPs of a particular type to TRGT0
always @(*) begin : BLOCK_PER_VC
    integer i;
    trgt0_p_block = 0;
    trgt0_np_block = 0;
    trgt0_cpl_block = 0;
    for(i = 0; i < NVC; i = i + 1) begin
        trgt0_p_block[i] = int_trgt0_radm_halt[i*3 + 0] & rd_4trgt0[i];
        trgt0_np_block[i] = int_trgt0_radm_halt[i*3 + 1] & rd_4trgt0[i];
        trgt0_cpl_block[i] = int_trgt0_radm_halt[i*3 + 2] & rd_4trgt0[i];
    end
end

    parameter N_DELAY_CYCLES = 1;
    // DATAPATH_WIDTH = req_rd + req_typ_w_pyld
    // + req_rd_4trgt0 + SEG_WIDTH (3*NVC)
    parameter DATAPATH_WIDTH = (3 +
                                SEG_WIDTH); 
    parameter CAN_STALL      = 1;

    delay_n_w_stalling
    
    #(N_DELAY_CYCLES, DATAPATH_WIDTH, CAN_STALL) u_delay (
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .stall      (req_rd && !req_ackd),
        .clear      (1'b0),

        .din        ( { int_req_rd, int_req_tlp_w_pyld, int_req_rd_4trgt0,
                        int_req_rd_segnum}),
        .stallout   (int_req_ackd_n),
        .dout       ( { req_rd, req_tlp_w_pyld, req_rd_4trgt0,
                        req_rd_segnum})
    );

`ifndef SYNTHESIS
//VCS coverage off
// for debug
wire [2:0]  tmp_vc_num;
assign      tmp_vc_num = Get_vc(int_req_rd_segnum);

// Return the vc number for a given segment number.
function automatic [2:0] Get_vc;
input   [SEG_WIDTH-1:0]             seg_num;

reg     [4:0]                       seg;

begin
    Get_vc = 0;
    seg    = 0;
    seg[SEG_WIDTH-1:0] = seg_num;


    case (seg)
       5'd00, 5'd01, 5'd02 :  Get_vc = 3'd0;
            default: Get_vc = 3'd0;
    endcase

end
endfunction

//VCS coverage on
`endif // SYNTHESIS

// Assert the ack to the correct VC request module
assign rd_ackd  = Get_vc_and_shift(int_req_rd_segnum, int_req_ackd);
wire    [NVC-1:0]       rd_ackd_from_outq;
assign rd_ackd_from_outq  = Get_vc_and_shift(req_rd_segnum, int_ack_from_outq);

// Arbitration process

always @(padded_valid_vc_req )
begin
    if (|padded_valid_vc_req)
        arb_result_valid = 1'b1;
    else
        arb_result_valid = 1'b0;
end

always @(padded_valid_vc_req or cfg_radm_strict_vc_prior or last_grant)
begin
    if (|padded_valid_vc_req) begin
        // --- STRICT PRIORITY ---
        if (cfg_radm_strict_vc_prior) begin
            next_grant = Select_highest(padded_valid_vc_req[7:0]);
        end // --- END STRICT PRIORITY ---
        // --- ROUND ROBIN ---
        else begin
            case (1'b1)
                last_grant[0]: begin
                    next_grant = Select_highest(padded_valid_vc_req[7:0]);
                end
                last_grant[1]: begin
                    next_grant  = Select_highest({padded_valid_vc_req[0], padded_valid_vc_req[7:1]}) + 3'h1;
                end
                last_grant[2]: begin
                    next_grant  = Select_highest({padded_valid_vc_req[1:0], padded_valid_vc_req[7:2]}) + 3'h2;
                end
                last_grant[3]: begin
                    next_grant  = Select_highest({padded_valid_vc_req[2:0], padded_valid_vc_req[7:3]}) + 3'h3;
                end
                last_grant[4]: begin
                    next_grant  = Select_highest({padded_valid_vc_req[3:0], padded_valid_vc_req[7:4]}) + 3'h4;
                end
                last_grant[5]: begin
                    next_grant  = Select_highest({padded_valid_vc_req[4:0], padded_valid_vc_req[7:5]}) + 3'h5;
                end
                last_grant[6]: begin
                    next_grant  = Select_highest({padded_valid_vc_req[5:0], padded_valid_vc_req[7:6]}) + 3'h6;
                end
                last_grant[7]: begin
                    next_grant  = Select_highest({padded_valid_vc_req[6:0], padded_valid_vc_req[7]}) + 3'h7;
                end
                default: begin
                    next_grant = 0;
                end
            endcase
        end // --- END ROUND ROBIN ---
    end
    else begin
        next_grant = 0;
    end
end


// Drive output depending on who's granted
reg [1:0] tmp_type;
//always @(next_grant or rd_p_valid or rd_np_valid or rd_cpl_valid or rd_4trgt0 or rd_tlp_w_pyld)
always @(*) begin
   integer i,j;
    tmp_type            = Onehot2bin({get_next_valid(rd_cpl_valid,next_grant), get_next_valid(rd_np_valid,next_grant), get_next_valid(rd_p_valid,next_grant)});
    arb_segnum          = Get_seg_num(next_grant, tmp_type);
    arb_tlp_w_pyld      = get_next_valid(rd_tlp_w_pyld,next_grant);   
    arb_rd_4trgt0       = get_next_valid(rd_4trgt0,next_grant);
end

// Save last granted when we're ACKed
always @(posedge core_clk or negedge core_rst_n)
begin: LATCH_LAST_GRANT
integer i;
    if (~core_rst_n) begin
        last_grant  <= #TP 8'h1;
    end
    else begin
        if (int_req_ackd) begin
            for (i=0; i<8; i=i+1) begin
                if (i==next_grant)
                    last_grant[i]   <= #TP 1'b1;
                else
                    last_grant[i]   <= #TP 1'b0;
            end
        end
    end
end
wire  [(NVC*3)-1:0]       s_radm_grant_tlp_type;
reg  [(NVC*3)-1:0]       radm_grant_tlp_type;
assign   s_radm_grant_tlp_type = put_vec((rd_cpl_valid & rd_ackd & ~rd_4_tlp_abort & ~rd_4trgt0),
  (rd_np_valid & rd_ackd & ~rd_4_tlp_abort & ~rd_4trgt0),
  (rd_p_valid & rd_ackd & ~rd_4_tlp_abort & ~rd_4trgt0));

// Save last granted when we're ACKed
always @(posedge core_clk or negedge core_rst_n)
begin: TLP_GRANT
    if (~core_rst_n) begin
        radm_grant_tlp_type  <= #TP {NVC*3{1'b0}};
    end
    else begin
      radm_grant_tlp_type <= #TP s_radm_grant_tlp_type;
    end
end
   
// One hot signal to notify the application which VC TRGT1 NP/P TLP has been acknowledged by the VC arbiter
// and is in flight. This is a remapping of radm_grant_tlp_type
reg [NVC-1:0]      s_rd_trgt1_ack_tlp_np;
reg [NVC-1:0]      s_rd_trgt1_ack_tlp_p;
reg [NVC-1:0]      s_rd_trgt1_ack_tlp_cpl;
always @(*) begin : P_NP_ACK_TO_TRKR
  integer i;
  s_rd_trgt1_ack_tlp_np = {NVC{1'b0}};
  s_rd_trgt1_ack_tlp_p  = {NVC{1'b0}};
  s_rd_trgt1_ack_tlp_cpl= {NVC{1'b0}};
  for(i = 0; i < NVC; i=i+1) begin
    s_rd_trgt1_ack_tlp_cpl[i] = radm_grant_tlp_type[i*3+2];
    s_rd_trgt1_ack_tlp_np[i]  = radm_grant_tlp_type[i*3+1];
    s_rd_trgt1_ack_tlp_p[i]   = radm_grant_tlp_type[i*3];
  end
end

wire  [NVC-1:0]          radm_trgt1_ack_tlp_np;
wire  [NVC-1:0]          radm_trgt1_ack_tlp_p;
assign  radm_trgt1_ack_tlp_np =  s_rd_trgt1_ack_tlp_np;
assign  radm_trgt1_ack_tlp_p  =  s_rd_trgt1_ack_tlp_p;

reg [NVC-1:0] radm_pend_cpl_so;
wire [NVC-1:0] int_radm_pend_cpl_so;

reg [NVC-1:0] r_cpl_so_pending;
always @(posedge core_clk or negedge core_rst_n) begin : R_CPL_SO_PENDING
    if(!core_rst_n) begin
        r_cpl_so_pending <= #TP 0;
    end else begin
        r_cpl_so_pending <= #TP int_radm_pend_cpl_so;
    end
end : R_CPL_SO_PENDING



always @(*) begin : CPL_SO
   // pend_cpl_so does not needs to be a pulse, just an indication that a strick ordering will be dequeued
   // Each time a CPL is dequeued (grant) if there's a SO at the head of the queue folling pulse so again
   radm_pend_cpl_so = (int_radm_pend_cpl_so & ~r_cpl_so_pending) | (int_radm_pend_cpl_so & s_rd_trgt1_ack_tlp_cpl);
end

//------------------------------------------------------------------------------
// Ordering within each VC
//------------------------------------------------------------------------------
wire   [(NVC*3)-1:0]       s_trgt1_radm_halt;
assign s_trgt1_radm_halt = trgt1_radm_halt;

radm_order_q

#(INST, `RADM_PQ_HDP_VC0*NHQ, `RADM_NPQ_HDP_VC0*NHQ, `RADM_CPLQ_HDP_VC0*NHQ,
                     `CX_LOGBASE2(`RADM_PQ_HDP_VC0*NHQ), `CX_LOGBASE2(`RADM_NPQ_HDP_VC0*NHQ), `CX_LOGBASE2(`RADM_CPLQ_HDP_VC0*NHQ),
                     `CX_P_ORDQ_WD_VC0, `CX_NP_ORDQ_WD_VC0, `CX_CPL_ORDQ_WD_VC0,
                     `CX_NL, `CX_NB, `CX_NW, `CX_NVC, `CX_NHQ,
                     NDQ
) u_vc0_radm_order_q (
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .vc_num                     (3'b0),
    .cfg_radm_order_rule        (cfg_radm_order_rule[0]),
    .cfg_order_rule_ctrl        ({cfg_order_rule_ctrl[8], cfg_order_rule_ctrl[0]}),
    .bypass_mode_vec            (bypass_mode_vec[((3*(0+1))-1):3*0]),
    .hdrq_wr_keep               (hdrq_wr_keep),
    .trgt0_radm_halt            (int_trgt0_radm_halt[((3*(0+1))-1):3*0]),
    .trgt1_radm_halt            (s_trgt1_radm_halt[((3*(0+1))-1):3*0]),

    .dataq_wr_keep              (dataq_wr_keep),
    .hdrq_wr_type               (hdrq_wr_type),
    .hdrq_wr_vc                 (hdrq_wr_vc),
    .hdrq_wr_relax_ordr         (hdrq_wr_relax_ordr),
    .hdrq_wr_4trgt0             (hdrq_wr_4trgt0),
    .hdrq_wr_4tlp_abort         (hdrq_wr_4tlp_abort),

    .rd_ackd                    (rd_ackd[0]),

    .rd_p_valid                 (rd_p_valid[0]),
    .rd_np_valid                (rd_np_valid[0]),
    .rd_cpl_valid               (rd_cpl_valid[0]),
    .rd_4trgt0                  (rd_4trgt0[0]),
    .rd_4_tlp_abort             (rd_4_tlp_abort[0]),
    .rd_tlp_w_pyld              (rd_tlp_w_pyld[0]),
    .radm_pend_cpl_so           (int_radm_pend_cpl_so[0])
   );








//------------------------------------------------------------------------------
// Various Functions
//------------------------------------------------------------------------------
// Priority arbitration
// input: 8 bit vector, multiple bits can be 1
// output: 3 bit index of highest one
function automatic  [2:0]  Select_highest;
input   [7:0]   input_vector;

begin
    casez (input_vector)
        8'b1???????: Select_highest = 3'h7;
        8'b01??????: Select_highest = 3'h6;
        8'b001?????: Select_highest = 3'h5;
        8'b0001????: Select_highest = 3'h4;
        8'b00001???: Select_highest = 3'h3;
        8'b000001??: Select_highest = 3'h2;
        8'b0000001?: Select_highest = 3'h1;
        //8'b00000001: Select_highest = 3'h0; // = default case item
        default:     Select_highest = 3'h0;
    endcase
end
endfunction

// Return the vc number for a given segment number.
function automatic [NVC-1:0] Get_vc_and_shift;
input   [SEG_WIDTH-1:0]             seg_num;
input                               req_ackd;
reg     [4:0]                       seg;
reg [NVC-1:0] req_ackd_vec;
begin
    Get_vc_and_shift = 0;
    seg = 0;
    seg[SEG_WIDTH-1:0] = seg_num;
    req_ackd_vec = 0;
    req_ackd_vec[0] = req_ackd;
    case (seg)
            5'd00, 5'd01, 5'd02 :  Get_vc_and_shift = (req_ackd_vec << 3'd0);
            default: Get_vc_and_shift = 0;
    endcase

end
endfunction

// Returns the segment number for a given vc and type.
function automatic [SEG_WIDTH-1:0] Get_seg_num;
input [2:0] vc;
input [1:0] pkt_type;

begin
    Get_seg_num = 0;


    case ({vc, pkt_type})
        //5'b00000  : Get_seg_num =  0;  // = default case item
        5'b00001  : Get_seg_num =  1;
        5'b00010  : Get_seg_num =  2;
        default: Get_seg_num = 0;
    endcase
end
endfunction



// One-hot to binary conversion
function automatic [1:0] Onehot2bin;
input   [2:0]   onehot;

begin
    case (1'b1)
        onehot[0]: Onehot2bin = 2'b00;
        onehot[1]: Onehot2bin = 2'b01;
        onehot[2]: Onehot2bin = 2'b10;
        default  : Onehot2bin = 2'b00;
    endcase
end
endfunction


function automatic            get_next_valid;
input    [NVC-1:0]  valid;
input        [2:0]  next_grant;
integer             ii;
begin
    get_next_valid = 1'b0;
    for (ii=0; ii<NVC; ii=ii+1) begin
      if (ii==next_grant) begin
        get_next_valid = valid[ii];
      end
    end

end
endfunction

// Function to ensure the signal is routed as data book specified.
function automatic [(3*NVC)-1 :0]           put_vec;
input    [NVC-1:0]  cpl_vec; // completion
input    [NVC-1:0]  np_vec; // non-posted type
input    [NVC-1:0]  p_vec; // posted type
integer             i;
integer             j;
begin
    put_vec = {3*NVC{1'b0}};
    for (i=0; i<NVC; i=i+1) begin
       for (j=0; j<3; j=j+1) begin
          if (j == 0)
            put_vec[(3*i)+j] = p_vec[i];
          else if (j == 1)
            put_vec[(3*i)+j] = np_vec[i];
          else if (j == 2)
            put_vec[(3*i)+j] = cpl_vec[i];
       end
    end
end
endfunction


endmodule

