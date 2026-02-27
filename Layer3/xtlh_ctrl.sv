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
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_ctrl.sv#16 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles the following conditions:
// --- 1 Generate a requst to enqueue a non posted request into
//        a completion lookup table. This is designed for end device port
// --- 2. notify the power management block when tlp is pending
// --- 3. monitor the tlps that are transmitted with completion abort or
//        "EP" bit of hdr turned on.
// --- 4. Insertion of ecrc
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xtlh_ctrl(
    // inputs
    core_rst_n,
    core_clk,

    merged_tlp_soh,
    merged_tlp_sot,
    merged_tlp_dv,
    merged_tlp_eot,
    merged_tlp_badeot,
    merged_tlp_data,
    merged_tlp_add_ecrc,
    merged_par_err,
    merged_tlp_dwen,



    xdlh_xtlh_halt,
    pm_xtlh_block_tlp,
   device_type,
// ----- Outputs-----

    //outputs
    xtlh_ctrl_halt,

    xtlh_xdlh_sot,
    xtlh_xdlh_data,

    xtlh_xdlh_dwen,
    xtlh_xdlh_eot,
    xtlh_xdlh_dv,

    xtlh_xdlh_badeot,

    xtlh_sot_is_first,
    xtlh_badeot,
    xtlh_first_badeot,
    xtlh_eot_sot,
    xtlh_eot_sot_eot,

    xtlh_xmt_cpl_ca,
    xtlh_xmt_cpl_ur,
    xtlh_xmt_cpl_poisoned,
    xtlh_xmt_wreq_poisoned,
    xtlh_data_parerr,
    // from xtlh for keeping track of completions and handling of completions
    xtlh_xmt_tlp_done,
    xtlh_xmt_tlp_done_early,
    xtlh_xmt_tlp_req_id,
    xtlh_xmt_tlp_tag,
    xtlh_xmt_tlp_attr,
    xtlh_xmt_cfg_req,
    xtlh_xmt_memrd_req,
    xtlh_xmt_atomic_req,
    xtlh_xmt_ats_req,
    xtlh_xmt_tlp_tc,
    xtlh_xmt_tlp_len_inbytes,
    xtlh_xmt_tlp_first_be,
    xtlh_xadm_restore_enable,
    xtlh_xadm_restore_capture,
    xtlh_xadm_restore_tc,
    xtlh_xadm_restore_type,
    xtlh_xadm_restore_word_len
);

// =============================================================================
// -- Parameters
// =============================================================================
parameter INST                          = 0;                    // The uniquifying parameter for each port logic instance.
parameter NW                            = `CX_NW;               // Number of 32-bit dwords handled by the datapath each clock.
parameter NF                            = `CX_NFUNC;            // Number of functions
parameter DATA_PAR_WD                   = `TRGT_DATA_PROT_WD;      // data bus parity width
parameter PAR_CALC_WIDTH                = `DATA_BUS_PAR_CALC_WIDTH;
parameter DW_W_PAR                      = (32*NW)+DATA_PAR_WD;  // Width of datapath in bits plus the parity bits.
parameter DW_WO_PAR                     = (32*NW);              // Width of datapath in bits.
parameter TP                            = `TP;                  // Clock to Q delay (simulator insurance)
parameter HAS_SEQNUM                    = 0;

parameter CRC_LATENCY = `CX_CRC_LATENCY_XTLH; // default is 1, can be set to 2 for pipelining to ease timing
localparam CRC_LATENCY_M1 = CRC_LATENCY-1;  //adds a clk cycle delay if crc pipeline on; else 0

localparam TX_CRC_TLP = (NW>2) ? 2 : 1; // Number of TLPs that can be processed by the ECRC block in a single cycle

parameter XTLH_CTRL_REGOUT              = `CX_XTLH_CTRL_REGOUT;   // can be programed to >0 (1 will be the necessary if you have timing problem)


parameter XTLH_PIPELINE_CRC = 0;


parameter CTL_WD = `CX_XTLH_XDLH_CTL_WD; // (NW == 2)? 1 : @CX_NW
parameter SOH_WD = (NW>2) ? NW : 2;

parameter XTLH_CRC_WD1                   = DW_WO_PAR +

                 NW + NW + NW + NW + 1 + 2;

parameter XTLH_CRC_WD2                   = DW_W_PAR +
                 NW + 1 + 1 + 1 + 1 + 2;


parameter XTLH_CTRL_REGOUT_WD1 = DW_WO_PAR +
                                 CTL_WD + SOH_WD + CTL_WD + CTL_WD + 1 + 5;

parameter XTLH_CTRL_REGOUT_WD =  DW_WO_PAR +
                                 NW + 1 + 1 + 1 + 2 + 1;

parameter XTLH_CTRL_REGOUT_CAN_STALL    = (`CX_XTLH_CTRL_REGOUT != 0) ? 1'b1 : 1'b0;

parameter S_IDLE                        = 2'h0;
parameter S_HDR_NEXT_CYCLE              = 2'h1;
parameter S_HDR_OR_PYLD                 = 2'h2;
parameter S_ECRC                        = 2'h3;
parameter PF_WD                         = `CX_NFUNC_WD;         // Width of physical function number signal
parameter ATOMIC_OPS_SUPPORTED          = `CX_ATOMIC_ENABLE_VALUE;  // Set when atomic ops are supported.
parameter DEVNUM_WD                     = `CX_DEVNUM_WD;
parameter MIN_PF_WD_3         = (PF_WD < 3) ? PF_WD : 3;



// =============================================================================
// --------- inputs --------------------
// =============================================================================
input                   core_rst_n;
input                   core_clk;

input   [SOH_WD-1:0]    merged_tlp_soh;             // Start of Header
input                   merged_tlp_dv;              // data valid
input   [CTL_WD-1:0]    merged_tlp_eot;             // end of transaction
input   [CTL_WD-1:0]    merged_tlp_badeot;          // end of nullified transaction
input   [DW_W_PAR-1:0]  merged_tlp_data;            // TLP data including hdr, prefix and paylaod
input [NW-1:0]          merged_tlp_sot;             //Start of TLP
input [1:0]             merged_tlp_add_ecrc;
input                   merged_par_err;

input [NW-1:0]          merged_tlp_dwen;

input                   xdlh_xtlh_halt;             // Data link layer halt
input                   pm_xtlh_block_tlp;          // power management unit requests to block TLPs


input[3:0]              device_type;

localparam TAG_SIZE = `CX_TAG_SIZE;

// =============================================================================
// --------- outputs --------------------
// =============================================================================
// Interface with xdlh block for tlp transmision

output                  xtlh_ctrl_halt;             // Output halt to XADM layer
output                  xtlh_xdlh_dv;               // XTLH pushes down packet down qualified by this data
output  [CTL_WD-1:0]    xtlh_xdlh_sot;              // XTLH Start Of TLP control bus
output  [CTL_WD-1:0]    xtlh_xdlh_eot;              // XTLH End Of TLP control bus
output  [CTL_WD-1:0]    xtlh_xdlh_badeot;           // XTLH Bad Eot control bus
output  [DW_W_PAR-1:0]  xtlh_xdlh_data;             // XTLH outputs header/data bus to XDLH
output  [NW-1:0]        xtlh_xdlh_dwen;


// Misc signals
output  [NF-1:0]        xtlh_xmt_cpl_ca;            // indicates that core transmitted a completion with CA status
output  [NF-1:0]        xtlh_xmt_cpl_ur;            // indicates that core transmitted a completion with UR status
output  [NF-1:0]        xtlh_xmt_cpl_poisoned;      // indicates that core transmitted a completion with poisoned
output  [NF-1:0]        xtlh_xmt_wreq_poisoned;     // indicates that core transmitted a memory write with poisoned
output                  xtlh_data_parerr;           // indicates that the xtlh has detect parity error on the internal large buses

// Interface to radm block for completion look up
output                  xtlh_xmt_tlp_done;          // Control bit of the xtlh_xmt*interface. This bit indicated that we have transmitted a NP TLP
output                  xtlh_xmt_tlp_done_early;    // Unregistered version of xtlh_xmt_tlp_done
output                  xtlh_xmt_cfg_req;           // This indicates the type of the TLP is the configuration request
output                  xtlh_xmt_memrd_req;         // This indicates the type of the TLP is a memory read
output                  xtlh_xmt_atomic_req;        // This indicates the type of the TLP is an Atomic request
output                  xtlh_xmt_ats_req;           // This indicates the type of the TLP is a memory read for an ATS Request
output  [15:0]          xtlh_xmt_tlp_req_id;        // Indicates the request id, it is designed to identify which interface the completion belongs to.
output  [TAG_SIZE-1:0]  xtlh_xmt_tlp_tag;           // This indicates the tag of the NP TLP read
output  [1:0]           xtlh_xmt_tlp_attr;          // This indicates the TLP's attributes
output  [2:0]           xtlh_xmt_tlp_tc;            // Traffic class of the TLP
output  [11:0]          xtlh_xmt_tlp_len_inbytes;   // The number of bytes that the read TLP has expected to be completed
output  [3:0]           xtlh_xmt_tlp_first_be;      // The first be of the TLP
output                  xtlh_xadm_restore_enable;
output                  xtlh_xadm_restore_capture;
output  [2:0]           xtlh_xadm_restore_tc;
output  [6:0]           xtlh_xadm_restore_type;
output  [9:0]           xtlh_xadm_restore_word_len;


output xtlh_sot_is_first;
output xtlh_eot_sot_eot;
output xtlh_badeot;
output xtlh_first_badeot;
output xtlh_eot_sot;


// =============================================================================
// --------- IO declaration --------------------
// =============================================================================
wire                    xtlh_ctrl_halt;
wire                    xtlh_xdlh_dv;
wire    [CTL_WD-1:0]    xtlh_xdlh_sot;
wire    [SOH_WD-1:0]    xtlh_xdlh_soh;
wire    [CTL_WD-1:0]    xtlh_xdlh_eot;
wire    [CTL_WD-1:0]    xtlh_xdlh_badeot;
wire    [DW_W_PAR-1:0]  xtlh_xdlh_data;
wire    [NW-1:0]        xtlh_xdlh_dwen;

reg     [NF-1:0]        xtlh_xmt_cpl_ca;
reg     [NF-1:0]        xtlh_xmt_cpl_ur;
reg     [NF-1:0]        xtlh_xmt_cpl_poisoned;
reg     [NF-1:0]        xtlh_xmt_wreq_poisoned;

// reg                     xtlh_xmt_tlp_done;

reg hdr1_next_cycle;
reg hdr1_next_cycle_q;
reg latchd_mem_rd_q;
reg latchd_def_mem_wr_q;
reg latchd_ats_req_q;
reg xtlh_xmt_tlp_done_i;
reg xtlh_xmt_tlp_done_q;
wire xtlh_xmt_tlp_done;
reg xtlh_xmt_tlp_done_to_cdm_i;
reg xtlh_xmt_tlp_done_to_cdm_q;
logic xtlh_xmt_tlp_done_to_cdm;


reg latchd_cfg_req_q;
reg latchd_cfg_req;

reg latchd_wreq_poisoned_to_cdm_q;
reg latchd_wreq_poisoned_to_cdm;
reg latchd_cpl_poisoned_to_cdm_q;
reg latchd_cpl_poisoned_to_cdm;
reg latchd_cpl_to_cdm;
reg latchd_cpl_to_cdm_q;

reg     [1:0]           latchd_tlp_attr_q;
reg     [1:0]           latchd_tlp_attr;
reg     [2:0]           latchd_tlp_tc_q;
reg     [2:0]           latchd_tlp_tc;


reg     [TAG_SIZE-1:0]  xtlh_xmt_tlp_tag;

wire                    xtlh_xmt_memrd_req;
wire                    xtlh_xmt_def_memwr_req;
wire                    xtlh_xmt_atomic_req;
wire                    xtlh_xmt_ats_req;
wire                    xtlh_xmt_cfg_req;
wire                    xtlh_xmt_wreq_poisoned_to_cdm;
wire                    xtlh_xmt_cpl_poisoned_to_cdm;
wire                    xtlh_xmt_cpl_to_cdm;
wire                    xtlh_xmt_tlp_done_early;
wire     [1:0]          xtlh_xmt_tlp_attr;
wire     [2:0]          xtlh_xmt_tlp_tc;

reg     [15:0]          xtlh_xmt_tlp_req_id;
reg     [2:0]           xtlh_xmt_cpl_status_to_cdm;
reg     [PF_WD-1:0]     xtlh_xmt_tlp_func_num_to_cdm;
reg     [11:0]          xtlh_xmt_tlp_len_inbytes;
reg     [3:0]           xtlh_xmt_tlp_first_be;

// =============================================================================
// --------- Internal Signal declaration --------------------
// =============================================================================
wire                    pipe_tlp_dv;                // data valid
wire   [CTL_WD-1:0]     pipe_tlp_eot;               // end of transaction
wire   [CTL_WD-1:0]     pipe_tlp_badeot;            // end of transaction
wire    [NW-1:0]        pipe_tlp_dwen;
wire    [NW-1:0]        int_tlp_dwen;
wire    [DW_WO_PAR-1:0] pipe_tlp_data;
wire    [DW_W_PAR-1:0]  pipe_tlp_data_int;

wire                    pipe_out_halt;
wire                    pipe_in_halt;

reg                     pipe_out_halt_d;

reg                     latchd_set_td;
wire    [31:0]          ecrc;
wire    [31:0]          ecrc0;
wire    [31:0]          ecrc1;
wire                    ecrc_valid;
wire    [31:0]          int_ecrc;
reg     [31:0]          ecrc_d;
reg     [31:0]          latchd_ecrc;
wire                    int_dv;

reg     [31:0]          int_ecrc0_d;
reg     [31:0]          int_ecrc1_d;
reg     [31:0]          latchd_ecrc0;
reg     [31:0]          latchd_ecrc1;
wire    [31:0]          int_ecrc0;
wire    [31:0]          int_ecrc1;

wire                    outreg_in_halt;
wire                    outreg_out_halt;

wire                    set_td;


reg     [9:0]          latchd_tlp_dwlen;
reg                    latchd_mem_rd;
reg                    latchd_def_mem_wr;
reg                    latchd_ats_req;
reg                    latchd_np_tlp;
reg                    latchd_p_wr_np_wr_cpl;
reg                    latchd_atomic_fas;
reg                    latchd_atomic_cas;




// ================== Internal Design ==========================================

//pipeline credit restore interface for QoR




wire                    xtlh_xadm_restore_enable_i;
wire                    xtlh_xadm_restore_capture_i;
reg     [2:0]           xtlh_xadm_restore_tc_i;
reg     [6:0]           xtlh_xadm_restore_type_i;
reg     [9:0]           xtlh_xadm_restore_word_len_i;

wire     [2:0]           xtlh_xadm_restore_tc;
wire     [6:0]           xtlh_xadm_restore_type;
wire     [9:0]           xtlh_xadm_restore_word_len;

localparam RESTORE_WIDTH =                                1 + 1 + 3 + 7 + 10 ; 

localparam RASDP_PIPE_DELAY = `CX_RASDP_XDLH_PIPE_EN ; 

// ================= ECRC Matching Pipe Delay ================================
    delay_n
     //pipeline the xtlh_xadm_restore* interface to improve timing
#(RASDP_PIPE_DELAY, RESTORE_WIDTH, 0) u0_restore_delay (
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .din        ({
 xtlh_xadm_restore_enable_i,  xtlh_xadm_restore_capture_i,  xtlh_xadm_restore_tc_i,  xtlh_xadm_restore_type_i,  xtlh_xadm_restore_word_len_i
           }),

        .dout       ({
 xtlh_xadm_restore_enable,  xtlh_xadm_restore_capture,  xtlh_xadm_restore_tc,  xtlh_xadm_restore_type,  xtlh_xadm_restore_word_len
           })

    );
//------------




wire     [CTL_WD-1:0]   int_sot;







// ---------------------- Start of 64/32 ---------------------------


reg     [1:0]           state;
reg     [1:0]           next_state;

wire    [DW_W_PAR-1:0] int_datao_prot;

// wire     [CTL_WD-1:0]   int_sot;
wire    [CTL_WD-1:0]    int_eot;
wire    [CTL_WD-1:0]    int_badeot;
wire    [DW_WO_PAR-1:0] int_datao;
wire    [NW-1:0]        int_dwen;
wire    [SOH_WD-1:0]    pipe_tlp_soh;
wire    [0:0]           pipe_tlp_add_ecrc;
wire    [SOH_WD-1:0]    int_soh;


wire            cfg_req1;
wire            mem_rd1_nolock;
wire            mem_rd1;
wire            def_mem_wr1;
wire            ats_req1;
wire            io_req1;
wire            atomic_fa_or_swp1;
wire            atomic_cas1;
wire            atomic_req;
wire            latchd_atomic_req;

wire [3:0]   first_dwen1;
wire [3:0]   last_dwen1;

wire         th1;

wire [TAG_SIZE-1:0] tlp_tag1;
wire [15:0]         tlp_req_id1;
reg  [PF_WD-1:0]    tlp_func_num1;
wire [2:0]          cpl_status1;

wire [2:0]          tlp_tc1;
wire [1:0]          tlp_attr1;
wire [9:0]          tlp_dwlen1;
wire                np_tlp;


reg latchd_cpl_poisoned;
reg latchd_wreq_poisoned;
reg latchd_cpl;




// ================= ECRC Matching Pipe Delay ================================
// Delay the incoming data to allow time to calculate CRC
    delay_n_w_stalling
     //crc pipeline delay min 1, max 2 for crc pipeline on
#(CRC_LATENCY, XTLH_CRC_WD2, XTLH_PIPELINE_CRC) u0_xtlh_ctrl_delay (
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .stall      (pipe_in_halt),
        .clear      (1'b0),

        .din        ({merged_tlp_data, merged_tlp_dwen, merged_tlp_dv, merged_tlp_soh, merged_tlp_eot,
           merged_tlp_badeot, merged_tlp_add_ecrc[0]
           }),

        .stallout   (pipe_out_halt),

        .dout       ({pipe_tlp_data_int, pipe_tlp_dwen, pipe_tlp_dv, pipe_tlp_soh, pipe_tlp_eot,
                pipe_tlp_badeot, pipe_tlp_add_ecrc[0]
           })

    );
//--------------------------------

 reg    [DW_WO_PAR-1:0] data_for_ecrco;

    wire    [NW-1:0]        sot_to_crco;
    reg                     crc_in_progress;


always @(*) begin : gen_data_for_crc
    integer i;
    data_for_ecrco = merged_tlp_data[DW_WO_PAR-1:0];

    for (i = 0; i < NW; i = i + 1)
        if (merged_tlp_soh[i]) begin
            data_for_ecrco[32*i +:32] = {merged_tlp_data[(32*(i)+23) +: 9], 1'b1, merged_tlp_data[(32*(i)+1) +:21], 1'b1};
        end
end

    wire   ecrc_en;
    assign ecrc_en = !pipe_out_halt;
    wire   [NW-1:0] eot_to_crc;
    always @(posedge core_clk or negedge core_rst_n)
        if (!core_rst_n) begin
            crc_in_progress <= #TP 0;
        end else if (merged_tlp_eot & !pipe_out_halt) begin
            crc_in_progress <= #TP 1'b0;
        end else if ( (|sot_to_crco) & !pipe_out_halt) begin
            crc_in_progress <= #TP 1'b1;
        end
//--------------------------------



     assign sot_to_crco = {1'b0, (!crc_in_progress & merged_tlp_soh[0] & merged_tlp_dv)};



    assign eot_to_crc[1] = (merged_tlp_eot & merged_tlp_dwen[1]);
    assign eot_to_crc[0] = (merged_tlp_eot & merged_tlp_dwen[0] & !merged_tlp_dwen[1]);

//--------------------------------

//--------------------------------

    wire                    del_ecrc_en;
    wire    [DW_WO_PAR-1:0] del_data_for_ecrco;
    wire    [NW-1:0]        del_sot_to_crco;
    wire    [NW-1:0]        del_eot_to_crc;
    delay_n
    
#(.N(0), .WD((2*NW)+DW_WO_PAR+1)) u0_crc_input_delay (
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .din        ({ecrc_en, sot_to_crco, eot_to_crc, data_for_ecrco}),

        .dout       ({del_ecrc_en, del_sot_to_crco, del_eot_to_crc, del_data_for_ecrco})
    );

    wire del_ecrc_en_d; //additional delay for pipeline crc o/p en    
    wire [TX_CRC_TLP*32-1:0] ecrc_int;
    wire [TX_CRC_TLP-1:0] ecrc_valid_int;

lcrc
 #(.NW(NW), .NOUT(1), .CRC_MODE(`CX_XTLH), .OPTIMIZE_FOR_1SOT_1EOT(1), .CRC_LATENCY(`CX_CRC_LATENCY_XTLH)) u_lcrc (
    // inputs
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .enable_in          (del_ecrc_en),
    .data_in            (del_data_for_ecrco),
    .sot_in             (del_sot_to_crco),
    .eot_in             (del_eot_to_crc),
    .seqnum_in_0        (16'h0), // unused for ecrc
    .seqnum_in_1        (16'h0),
    // outputs
    .crc_out            (ecrc_int), // www: this value must be latched (see ref model) for use with 32b/64b/128b
    .crc_out_valid      (ecrc_valid_int),
    .crc_out_match      (),  // unused when generating
    .crc_out_match_inv  ()  // unused when generating
);

//--------------------------------

delay_n
 ////delay: 0 clk delays standard mode, 1 clk delays crc pipeline mode
#(.N(CRC_LATENCY_M1), .WD(1)) crc_xtlh_delay1 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({del_ecrc_en}),
    .dout       ({del_ecrc_en_d})
);
//--------------------------------

    assign ecrc_valid = ecrc_valid_int & del_ecrc_en_d;

    reg [31:0] ecrc_int_r;
    always @(posedge core_clk or negedge core_rst_n) begin : ecrc_seq_PROC1
        if (!core_rst_n) begin
            ecrc_int_r <= #TP 0;
        end else begin
        if ( ecrc_valid ) begin
                ecrc_int_r <= #TP ecrc_int;
            end
        end
    end
    assign ecrc = ecrc_valid ? ecrc_int : ecrc_int_r; // extend the value

    assign xtlh_ctrl_halt = pipe_in_halt;

    // When the ECRC module is available, the ecrc will be asserted based on td bit set

    assign set_td           = pipe_tlp_add_ecrc[0];


  wire xtlh_data_parerr;
  assign xtlh_data_parerr = 1'b0;
  assign pipe_tlp_data = pipe_tlp_data_int;



// ================= State machine used to snoop header information ===
// ================= And ECRC insertion ===============================
//

always @(*) begin
    next_state = state;
    case (state)
        S_IDLE:
            if (pipe_tlp_dv & !pipe_tlp_eot )
                next_state   = S_HDR_NEXT_CYCLE;
        S_HDR_NEXT_CYCLE:
            if (pipe_tlp_eot & pipe_tlp_dv & latchd_set_td & pipe_tlp_dwen[NW-1])
                next_state   = S_ECRC;
            else if (pipe_tlp_eot & pipe_tlp_dv)
                next_state   = S_IDLE;
            else
                next_state   = S_HDR_OR_PYLD;
        S_HDR_OR_PYLD:
            if (pipe_tlp_eot & pipe_tlp_dv & latchd_set_td & pipe_tlp_dwen[NW-1])
                next_state   = S_ECRC;
            else if (pipe_tlp_eot & pipe_tlp_dv)
                next_state   = S_IDLE;
            else
                next_state   = S_HDR_OR_PYLD;
        S_ECRC:
                next_state   = S_IDLE;
    endcase
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        state   <= #TP S_IDLE;
    else if (!outreg_out_halt)
        state   <= #TP next_state;

// latched ecrc for stall so that we can have the correct ECRC for the pipe delay


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        pipe_out_halt_d <= #TP 0;
    end else begin
        pipe_out_halt_d <= #TP pipe_out_halt;
    end


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ecrc_d  <= #TP 0;
    else
    if (state != S_ECRC)
        ecrc_d  <= #TP int_ecrc;



wire                   ecrc_err_insert;
assign ecrc_err_insert = 1'b0;
//--------------------------------

assign int_ecrc = ecrc_err_insert ? {ecrc[31:1], !ecrc[0]} : ecrc; //crc pipeline delay

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latchd_ecrc <= #TP 0;
     end else if (pipe_out_halt & !pipe_out_halt_d) begin

        latchd_ecrc <= #TP ecrc;
    end
//--------------------------------

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latchd_set_td   <= #TP 0;
    end else if (state == S_IDLE) begin
        latchd_set_td   <= #TP set_td;
    end
//--------------------------------

// Latch the badeot in the case of ECRC pipeline. (i.e. when CRC_LATENCY = 2)
reg latchd_badeot;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latchd_badeot   <= #TP 0;
    end else if (state != S_ECRC) begin
        latchd_badeot   <= #TP pipe_tlp_badeot;
    end
//--------------------------------

assign int_soh          = !int_eot ? pipe_tlp_soh : 2'b00;
assign int_sot          = ((state == S_IDLE) & pipe_tlp_dv);
assign int_dv           = pipe_tlp_dv | (state != S_IDLE);

assign int_eot          = (state == S_ECRC)
                            | ((state == S_IDLE) & pipe_tlp_eot & ((!pipe_tlp_dwen[NW-1] & set_td) | !set_td))
                            | ((state != S_IDLE) & (state != S_ECRC) & pipe_tlp_eot & ((!pipe_tlp_dwen[NW-1] & latchd_set_td) | !latchd_set_td));

assign int_badeot       = ((state == S_ECRC) & latchd_badeot)
                            | ((state == S_IDLE) & pipe_tlp_eot & pipe_tlp_badeot & ((!pipe_tlp_dwen[NW-1] & set_td) | !set_td))
                            | ((state != S_IDLE) & (state != S_ECRC) & pipe_tlp_eot & pipe_tlp_badeot & ((!pipe_tlp_dwen[NW-1] & latchd_set_td) | !latchd_set_td));
//--------------------------------

assign int_datao[31:0]   = ( int_soh[0]) ? {pipe_tlp_data[31:24], (set_td | pipe_tlp_data[23]), pipe_tlp_data[22:0]}
                            : (state == S_ECRC) ? ecrc_d
                            : pipe_tlp_data[31:0];

//--------------------------------

// Insert ecrc has different impact on different architectures for its data bus




    assign int_dwen          = (state == S_ECRC) ? 2'b01
                               : ((state != S_IDLE) & latchd_set_td) ? {pipe_tlp_dwen[0],1'b1}
                               : pipe_tlp_dwen;

   assign int_datao[63:32]   = ( int_soh[1]) ? {pipe_tlp_data[63:56], (set_td | pipe_tlp_data[55]), pipe_tlp_data[54:32]} :
                 (latchd_set_td & (state != S_IDLE) & pipe_tlp_eot & !pipe_tlp_dwen[1])  ? int_ecrc : pipe_tlp_data[63:32];



    // header information

    assign first_dwen1  = hdr1_next_cycle ? ((latchd_atomic_req) ? 4'b1111 : pipe_tlp_data[27:24]) :
                         pipe_tlp_soh[0] ? ((atomic_req) ? 4'b1111 : pipe_tlp_data[59:56]) : 4'b0000;

    assign last_dwen1   = hdr1_next_cycle ? ((latchd_atomic_req) ? (tlp_dwlen1 != 1 ? 4'b1111 : 4'b0000) : pipe_tlp_data[31:28]) :
                         pipe_tlp_soh[0] ? (atomic_req ?  (tlp_dwlen1 != 1 ? 4'b1111 : 4'b0000) : pipe_tlp_data[63:60]) : 4'b0000;


always_comb begin
    tlp_func_num1 = '0;
    if(device_type == `PCIE_RC )begin
        tlp_func_num1[MIN_PF_WD_3-1:0] = hdr1_next_cycle ? pipe_tlp_data[(MIN_PF_WD_3-1)+8:8] : pipe_tlp_soh[0] ? pipe_tlp_data[(MIN_PF_WD_3-1)+40:40] : {MIN_PF_WD_3{1'b0}};
    end else begin
        tlp_func_num1 = hdr1_next_cycle ? pipe_tlp_data[(PF_WD-1)+8:8] : pipe_tlp_soh[0] ? pipe_tlp_data[(PF_WD-1)+40:40] : {PF_WD{1'b0}};
    end
end // always_comb

    assign cpl_status1  = hdr1_next_cycle ? pipe_tlp_data[23:21] : pipe_tlp_soh[0] ? pipe_tlp_data[55:53]: 3'b000;


    assign tlp_tag1[0+:8] = hdr1_next_cycle ? pipe_tlp_data[23:16] : pipe_tlp_soh[0] ? pipe_tlp_data[55:48] :8'h00;

    assign tlp_req_id1  = hdr1_next_cycle ? {pipe_tlp_data[7:0], pipe_tlp_data[15:8]} : pipe_tlp_soh[0] ? {pipe_tlp_data[39:32], pipe_tlp_data[47:40]} : 16'h0000;


    assign tlp_tc1   = pipe_tlp_dv & pipe_tlp_soh[0] ? pipe_tlp_data[14:12] : pipe_tlp_soh[1] ? pipe_tlp_data[46:44] : 3'b000;
    assign tlp_attr1 = pipe_tlp_dv & pipe_tlp_soh[0] ? pipe_tlp_data[21:20] : pipe_tlp_soh[1] ? pipe_tlp_data[53:52] : 2'b00;
    assign tlp_dwlen1 = pipe_tlp_dv & pipe_tlp_soh[0] ? {pipe_tlp_data[17:16], pipe_tlp_data[31:24]} : pipe_tlp_soh[1] ? {pipe_tlp_data[49:48], pipe_tlp_data[63:56]} : 10'h000;



assign cfg_req1     =  pipe_tlp_dv & pipe_tlp_soh[0] & ((pipe_tlp_data[6:0] == `CFGRD1 ) | (pipe_tlp_data[6:0] == `CFGRD0)
                                | (pipe_tlp_data[6:0] == `CFGWR1) | (pipe_tlp_data[6:0] == `CFGWR0) ) |
             pipe_tlp_dv & pipe_tlp_soh[1] & ((pipe_tlp_data[38:32] == `CFGRD1 ) | (pipe_tlp_data[38:32] == `CFGRD0)
                                | (pipe_tlp_data[38:32] == `CFGWR1) | (pipe_tlp_data[38:32] == `CFGWR0) );

assign mem_rd1_nolock = (pipe_tlp_dv & pipe_tlp_soh[0] & ((pipe_tlp_data[6:0] == `MRD32) | (pipe_tlp_data[6:0] == `MRD64))) ||
                        (pipe_tlp_dv & pipe_tlp_soh[1] & ((pipe_tlp_data[38:32] == `MRD32) | (pipe_tlp_data[38:32] == `MRD64)));
assign mem_rd1      =  mem_rd1_nolock | (pipe_tlp_dv & pipe_tlp_soh[0] & ((pipe_tlp_data[6:0] == `MRDLK32 ) | (pipe_tlp_data[6:0] == `MRDLK64)) |
                                         pipe_tlp_dv & pipe_tlp_soh[1] & ((pipe_tlp_data[38:32] == `MRDLK32 ) | (pipe_tlp_data[38:32] == `MRDLK64)));

assign def_mem_wr1   = 0;
assign ats_req1 = mem_rd1_nolock && ((pipe_tlp_soh[0] && pipe_tlp_data[19:18] == 2'b01) || (pipe_tlp_soh[1] && pipe_tlp_data[51:50] == 2'b01));


assign io_req1      =  pipe_tlp_dv & pipe_tlp_soh[0] & ( (pipe_tlp_data[6:0] == `IOWR ) | (pipe_tlp_data[6:0] == `IORD)) |
            pipe_tlp_dv & pipe_tlp_soh[1] & ( (pipe_tlp_data[38:32] == `IOWR ) | (pipe_tlp_data[38:32] == `IORD));

assign atomic_fa_or_swp1  = ATOMIC_OPS_SUPPORTED ? pipe_tlp_dv & pipe_tlp_soh[0] & ( (pipe_tlp_data[6:0] == `FETCHADD32) | (pipe_tlp_data[6:0] == `FETCHADD64) |
                           (pipe_tlp_data[6:0] == `SWAP32) | (pipe_tlp_data[6:0] == `SWAP64) ) |
            pipe_tlp_dv & pipe_tlp_soh[1] & ( (pipe_tlp_data[38:32] == `FETCHADD32) | (pipe_tlp_data[38:32] == `FETCHADD64) |
                           (pipe_tlp_data[38:32] == `SWAP32) | (pipe_tlp_data[38:32] == `SWAP64) ) 
                            : 0;         // when atomic ops are not supported, assign 0.


assign atomic_cas1        = ATOMIC_OPS_SUPPORTED ? pipe_tlp_dv & pipe_tlp_soh[0] & ( (pipe_tlp_data[6:0] == `CAS32) | (pipe_tlp_data[6:0] == `CAS64) ) |
                 pipe_tlp_dv & pipe_tlp_soh[1] & ( (pipe_tlp_data[38:32] == `CAS32) | (pipe_tlp_data[38:32] == `CAS64) ) 
                            : 0;   // when atomic ops are not supported, assign 0.

assign atomic_req = atomic_cas1 | atomic_fa_or_swp1;
assign latchd_atomic_req = latchd_atomic_cas | latchd_atomic_fas;


assign np_tlp      = cfg_req1 | mem_rd1 | def_mem_wr1 | io_req1 | atomic_req;


//--------------------------------





wire ep;
wire p_wr;
wire np_wr;
wire cpl;



assign ep       = pipe_tlp_soh[0] & pipe_tlp_data[22] | pipe_tlp_soh[1] & pipe_tlp_data[54];
assign p_wr     = pipe_tlp_soh[0] & ((pipe_tlp_data[6:0] == `MWR32) | (pipe_tlp_data[6:0] == `MWR64)  | (pipe_tlp_data[6:3] == `MSG_4) | (pipe_tlp_data[6:3] == `MSGD_4)) |
      pipe_tlp_soh[1] & ((pipe_tlp_data[38:32] == `MWR32) | (pipe_tlp_data[38:32] == `MWR64)  | (pipe_tlp_data[38:35] == `MSG_4) | (pipe_tlp_data[38:35] == `MSGD_4));

assign np_wr    = pipe_tlp_soh[0] & ((pipe_tlp_data[6:0] == `IOWR)  | (pipe_tlp_data[6:0] == `CFGWR1) | (pipe_tlp_data[6:0] == `CFGWR0) | atomic_req | def_mem_wr1) |
      pipe_tlp_soh[1] & ((pipe_tlp_data[38:32] == `IOWR)  | (pipe_tlp_data[38:32] == `CFGWR1) | (pipe_tlp_data[38:32] == `CFGWR0) | atomic_req | def_mem_wr1);

assign cpl      = pipe_tlp_soh[0] & ((pipe_tlp_data[6:0] == `CPL)  | (pipe_tlp_data[6:0] == `CPLLK)  | (pipe_tlp_data[6:0] == `CPLD) | (pipe_tlp_data[6:0] == `CPLDLK)) |
                pipe_tlp_soh[1] & ((pipe_tlp_data[38:32] == `CPL)  | (pipe_tlp_data[38:32] == `CPLLK)  | (pipe_tlp_data[38:32] == `CPLD) | (pipe_tlp_data[38:32] == `CPLDLK));




wire wreq_poisoned   = (p_wr | np_wr) & ep;
wire cpl_poisoned    = cpl & ep;

//--------------------------------



assign int_datao_prot = int_datao;

// ==================================================================
// Output drives for XDLH interface
// ==================================================================
// This is the only cycle delay within xtlh if there is a xtlh output
// registered stage is desired
//
// Delay the incoming data to allow time to calculate CRC
   delay_n_w_stalling
   
#(XTLH_CTRL_REGOUT, XTLH_CTRL_REGOUT_WD, XTLH_CTRL_REGOUT_CAN_STALL) u1_xtlh_ctrl_delay (
       .clk        (core_clk),
       .rst_n      (core_rst_n),
       .stall      (outreg_in_halt),
       .clear      (1'b0),
       .din        ({int_datao_prot, int_dwen, int_sot, int_soh, int_eot, int_dv, 
               int_badeot}),

       .stallout   (outreg_out_halt),
       .dout       ({xtlh_xdlh_data, xtlh_xdlh_dwen, xtlh_xdlh_sot, xtlh_xdlh_soh, xtlh_xdlh_eot, xtlh_xdlh_dv,
                    xtlh_xdlh_badeot})
   );

assign outreg_in_halt   = xdlh_xtlh_halt & xtlh_xdlh_dv;        // when XDLH interface halt the output stage of the XTLH

assign pipe_in_halt     = outreg_out_halt | (state == S_ECRC);  // When output state of the XTLH halt is used to halt the CRC delay


wire xtlh_sot_is_first;
wire xtlh_eot_sot_eot;
wire xtlh_badeot;
wire xtlh_first_badeot;
wire xtlh_eot_sot;

assign xtlh_sot_is_first = 1'b0;
assign xtlh_eot_sot_eot = 1'b0;
assign xtlh_badeot = 1'b0;
assign xtlh_first_badeot = 1'b0;
assign xtlh_eot_sot = 1'b0;

// ==================================================================
// Output drives for completion look up interface
// Snoop the header information to make a decision
// ==================================================================


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latchd_tlp_tc     <= #TP 0;
        latchd_tlp_attr   <= #TP 0;
        latchd_cfg_req       <= #TP 0;
        latchd_cpl_poisoned  <= #TP 0;
        latchd_wreq_poisoned <= #TP 0;
        latchd_cpl           <= #TP 0;
        latchd_tlp_dwlen     <= #TP 0;
        latchd_mem_rd        <= #TP 0;
        latchd_def_mem_wr    <= #TP 0;
        latchd_ats_req       <= #TP 0;
        latchd_atomic_fas    <= #TP 0;
        latchd_atomic_cas    <= #TP 0;
        latchd_np_tlp <= #TP 0;
        latchd_p_wr_np_wr_cpl <= #TP 0;
    end else if (|pipe_tlp_soh & pipe_tlp_dv) begin
        latchd_tlp_tc     <= #TP tlp_tc1;
        latchd_tlp_attr   <= #TP tlp_attr1;
        latchd_cfg_req       <= #TP cfg_req1;
        latchd_cpl_poisoned  <= #TP cpl & ep;
        latchd_wreq_poisoned <= #TP wreq_poisoned;
        latchd_cpl           <= #TP cpl;
        latchd_tlp_dwlen     <= #TP tlp_dwlen1;
        latchd_mem_rd        <= #TP mem_rd1;
        latchd_def_mem_wr    <= #TP def_mem_wr1;
        latchd_ats_req       <= #TP ats_req1;
        latchd_atomic_fas    <= #TP atomic_fa_or_swp1;
        latchd_atomic_cas    <= #TP atomic_cas1;
        latchd_np_tlp       <= #TP np_tlp;
        latchd_p_wr_np_wr_cpl  <= #TP np_wr | p_wr | cpl;
    end

assign xtlh_xmt_memrd_req = latchd_mem_rd;
assign xtlh_xmt_def_memwr_req = latchd_def_mem_wr;
assign xtlh_xmt_ats_req = 1'b0;

assign xtlh_xmt_cfg_req = latchd_cfg_req;
assign xtlh_xmt_cpl_poisoned_to_cdm = latchd_cpl_poisoned;
assign xtlh_xmt_wreq_poisoned_to_cdm = latchd_wreq_poisoned;
assign xtlh_xmt_cpl_to_cdm = latchd_cpl;
assign xtlh_xmt_tlp_tc = latchd_tlp_tc;
assign xtlh_xmt_tlp_attr = latchd_tlp_attr;
assign xtlh_xmt_atomic_req = latchd_atomic_req;



always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        xtlh_xmt_tlp_tag             <= #TP 0;
        xtlh_xmt_tlp_req_id          <= #TP 0;
        xtlh_xmt_cpl_status_to_cdm   <= #TP 0;
        xtlh_xmt_tlp_func_num_to_cdm <= #TP 0;
    end
    else if (hdr1_next_cycle | pipe_tlp_soh[0]) begin
        xtlh_xmt_tlp_tag             <= #TP tlp_tag1;
        xtlh_xmt_tlp_req_id          <= #TP tlp_req_id1;
        xtlh_xmt_cpl_status_to_cdm   <= #TP cpl_status1;
        xtlh_xmt_tlp_func_num_to_cdm <= #TP tlp_func_num1;
    end



always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        xtlh_xmt_tlp_len_inbytes    <= #TP 0;
        xtlh_xmt_tlp_first_be       <= #TP 0;

    end else if ((pipe_tlp_soh[0]) & (mem_rd1 || atomic_fa_or_swp1) ) begin
        xtlh_xmt_tlp_len_inbytes    <= #TP get_byte_count(first_dwen1, last_dwen1, tlp_dwlen1);
        xtlh_xmt_tlp_first_be       <= #TP first_dwen1;
    end else if ((hdr1_next_cycle) & (latchd_mem_rd || latchd_atomic_fas) ) begin
        xtlh_xmt_tlp_len_inbytes    <= #TP get_byte_count(first_dwen1, last_dwen1, latchd_tlp_dwlen);
        xtlh_xmt_tlp_first_be       <= #TP first_dwen1;

    end else if ((pipe_tlp_soh[0]) & atomic_cas1 ) begin
        // Byte length for a Cpl to an Atomic CAS is half of the request
        // length
        xtlh_xmt_tlp_len_inbytes    <= #TP get_byte_count(first_dwen1, last_dwen1, tlp_dwlen1) >> 1;
        xtlh_xmt_tlp_first_be       <= #TP first_dwen1;
     end else if ((hdr1_next_cycle) & latchd_atomic_cas ) begin
        xtlh_xmt_tlp_len_inbytes    <= #TP get_byte_count(first_dwen1, last_dwen1, latchd_tlp_dwlen) >> 1;
        xtlh_xmt_tlp_first_be       <= #TP first_dwen1;

    end
    else if (state == S_IDLE) begin
           xtlh_xmt_tlp_len_inbytes    <= #TP 12'h004;
    end

assign xtlh_xmt_tlp_done_early = (np_tlp & (state == S_IDLE) & pipe_tlp_eot & pipe_tlp_dv & !pipe_in_halt)
                            | (latchd_np_tlp & (state != S_IDLE) & pipe_tlp_eot & pipe_tlp_dv & !pipe_in_halt);

     
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        xtlh_xmt_tlp_done_i   <= #TP 0;
    else
        xtlh_xmt_tlp_done_i   <= #TP xtlh_xmt_tlp_done_early;

assign xtlh_xmt_tlp_done = xtlh_xmt_tlp_done_i;

always_ff @(posedge core_clk or negedge core_rst_n)begin
    if(!core_rst_n)begin
        xtlh_xmt_tlp_done_to_cdm <= #TP 0;
    end else begin
        xtlh_xmt_tlp_done_to_cdm <= #TP  ((p_wr || np_wr || cpl) & (state == S_IDLE) & pipe_tlp_eot & pipe_tlp_dv & !pipe_in_halt)
                            | (latchd_p_wr_np_wr_cpl & (state != S_IDLE) & pipe_tlp_eot & pipe_tlp_dv & !pipe_in_halt);        
    end
end


// Parity check logic for the application that required high reliable
// delivery. Core will monitor parity of a large bus until the ECRC is
// calculated


assign  xtlh_xadm_restore_capture_i    = (|xtlh_xdlh_soh & !xdlh_xtlh_halt);

// Althoug cfg_rasdp_error_mode already affects the generation of xtlh_xdlh_badeot, it is used again at the output of the 
// delay stage to make sure TLPs which were already in the delay stage before RASDP error mode are nullified and their credits returned
  assign  xtlh_xadm_restore_enable_i   =  xtlh_xdlh_badeot & !xdlh_xtlh_halt;
assign  xtlh_xadm_restore_tc_i         =  xtlh_xdlh_soh[0] ?  xtlh_xdlh_data[14:12] : xtlh_xdlh_soh[1] ? xtlh_xdlh_data[46:44] : 3'b000;
assign  xtlh_xadm_restore_type_i       =  xtlh_xdlh_soh[0] ?  xtlh_xdlh_data[6:0] : xtlh_xdlh_soh[1] ? xtlh_xdlh_data[38:32] : 7'b0000000;
assign  xtlh_xadm_restore_word_len_i   =  xtlh_xdlh_soh[0] ?  {xtlh_xdlh_data[17:16], xtlh_xdlh_data[31:24]} :
                                       xtlh_xdlh_soh[1] ? {xtlh_xdlh_data[49:48], xtlh_xdlh_data[63:56]} : 10'h000;






// ------------- Common code for all datapath widths ----------------



// ==================================================================
// Output drives for CDM AER
// ==================================================================

logic xtlh_xmt_tlp_done_to_cdm_d;
logic xtlh_xmt_wreq_poisoned_to_cdm_d;
logic xtlh_xmt_cpl_poisoned_to_cdm_d;
logic xtlh_xmt_cpl_to_cdm_d;
logic[2:0] xtlh_xmt_cpl_status_to_cdm_d;
logic [PF_WD-1:0] xtlh_xmt_tlp_func_num_to_cdm_d;
wire                 vf_active;

assign vf_active = 0;


delay_n

  #(.N(1), .WD(1+1+1+1+3 + PF_WD)) 
    u0_xtlh_to_cdm_delay_post_rid2pfvf 
    (
     .clk        (core_clk),
     .rst_n      (core_rst_n),
     .clear      (1'b0),
     .din        ({xtlh_xmt_tlp_done_to_cdm, xtlh_xmt_wreq_poisoned_to_cdm, xtlh_xmt_cpl_poisoned_to_cdm, xtlh_xmt_cpl_to_cdm, xtlh_xmt_cpl_status_to_cdm, xtlh_xmt_tlp_func_num_to_cdm}),
     .dout       ({xtlh_xmt_tlp_done_to_cdm_d, xtlh_xmt_wreq_poisoned_to_cdm_d, xtlh_xmt_cpl_poisoned_to_cdm_d, xtlh_xmt_cpl_to_cdm_d, xtlh_xmt_cpl_status_to_cdm_d, xtlh_xmt_tlp_func_num_to_cdm_d })
     );

always_ff @(posedge core_clk or negedge core_rst_n)begin
    if(!core_rst_n)begin
        xtlh_xmt_cpl_ca        <= #TP 0;
        xtlh_xmt_cpl_ur        <= #TP 0;
        xtlh_xmt_wreq_poisoned <= #TP 0;
        xtlh_xmt_cpl_poisoned  <= #TP 0;
    end else begin
        for(int i = 0; i < NF; i++)begin
            xtlh_xmt_cpl_ur[i]        <= #TP xtlh_xmt_tlp_done_to_cdm_d && !vf_active && xtlh_xmt_cpl_to_cdm_d && xtlh_xmt_cpl_status_to_cdm_d == `UR_CPL_STATUS && xtlh_xmt_tlp_func_num_to_cdm_d == i;
            xtlh_xmt_cpl_ca[i]        <= #TP xtlh_xmt_tlp_done_to_cdm_d && !vf_active && xtlh_xmt_cpl_to_cdm_d && xtlh_xmt_cpl_status_to_cdm_d == `CA_CPL_STATUS && xtlh_xmt_tlp_func_num_to_cdm_d == i;
            xtlh_xmt_wreq_poisoned[i] <= #TP xtlh_xmt_tlp_done_to_cdm_d && !vf_active && xtlh_xmt_wreq_poisoned_to_cdm_d && xtlh_xmt_tlp_func_num_to_cdm_d == i;
            xtlh_xmt_cpl_poisoned[i] <= #TP xtlh_xmt_tlp_done_to_cdm_d && !vf_active && xtlh_xmt_cpl_poisoned_to_cdm_d && xtlh_xmt_tlp_func_num_to_cdm_d == i;
        end
    end
end

// Detect when HDR DW1 in on the first DW of next cycle

always @(posedge core_clk or negedge core_rst_n)
  if (!core_rst_n) begin
        hdr1_next_cycle <= #TP 1'b0;
  end else begin
        if (int_soh[NW-1] && !pipe_in_halt)
            hdr1_next_cycle <= #TP 1'b1;
        else
            hdr1_next_cycle <= #TP 1'b0;
  end


// ======================= ALL function declarations =========================================


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
            default                            : f_bytelength = 1;          // TBD Can this ever be 0?
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
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        f_bytelength = f_length_times4 - f_subend;
// spyglass enable_block W164a
    end

    get_byte_count = f_bytelength;

end
endfunction






endmodule
