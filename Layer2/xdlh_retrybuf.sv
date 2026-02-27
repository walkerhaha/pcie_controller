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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_retrybuf.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer Handler Retry Buffer
// -----------------------------------------------------------------------------
// --- This module handles retry buffer function for DLH
// --- 1. retry buffer is designed to keep the previous transmitted tlps
// --- for the necessary retry requirement defined in spec.
// --- 2. retry buffer releases the buffer room when there is an ack
// --- received
// --- 3. Retry buffer size is determined by RBUF_DEPTH and RBUF_WIDTH. The
// --- retry buffer size will also determine the size of the buffer that we
// --- used to store the begining of each tlp's retry buffer address.
// --- This module handles 32b, 64b, 128b, 256b and 512b datapath widths.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module xdlh_retrybuf(
    // -- inputs --
    b_xdlh_replay_num,
    b_xdlh_replay,
    core_clk,
    core_rst_n,
    smlh_link_in_training,
    rdlh_link_up,
    tlpgen_rbuf_data,
    tlpgen_rbuf_dwen,
    tlpgen_rbuf_dv,

    tlpgen_rbuf_sot,
    tlpgen_rbuf_eot,
    tlpgen_rbuf_badeot,
    tlpgen_rbuf_seqnum,
    tlpgen_reply_grant,
    rbuf_halt,
    rdlh_xdlh_rcvd_nack,
    rdlh_xdlh_rcvd_ack,
    rdlh_xdlh_rcvd_acknack_seqnum,

    // -- outputs --
    rbuf_xmt_data,
    rbuf_xmt_dwen,
    rbuf_xmt_dv,
    rbuf_xmt_done,
    rbuf_xmt_sot,
    rbuf_xmt_eot,
    rbuf_xmt_badeot,
    rbuf_xmt_seqnum,
    rbuf_reply_req,
    rbuf_entry_cnt,
    rbuf_pkt_cnt,
    rbuf_block_new_tlp,
    xdlh_smlh_start_link_retrain,
    xdlh_rbuf_not_empty,
    xdlh_not_expecting_ack,
    xdlh_rdlh_last_xmt_seqnum,



    // Retry buffer RAM interface
    xdlh_retryram_addr,
    xdlh_retryram_data,
    xdlh_retryram_we,
    xdlh_retryram_en,
    xdlh_retryram_par_chk_val,
    xdlh_retryram_halt,
    retryram_xdlh_data,
    retryram_xdlh_depth,
    retryram_xdlh_parerr,

// Performance changes - 2p RAM I/F
 //   xdlh_retrysotram_addr,
    xdlh_retrysotram_waddr,
    xdlh_retrysotram_raddr,
    xdlh_retrysotram_data,
    xdlh_retrysotram_en,
    xdlh_retrysotram_we,
    xdlh_retrysotram_par_chk_val,
    retrysotram_xdlh_data,
    retrysotram_xdlh_parerr,
    retrysotram_xdlh_depth,
    xdlh_retry_req
    ,
    xdlh_in_reply
);
// ===============================================================
// ----------------------- Parameters ----------------------------
// ===============================================================

parameter INST          = 0;                                // The uniquifying parameter for each port logic instance.
parameter NL            = `CX_NL;                           // Max number of lanes supported
parameter NB            = `CX_NB;                           // Number of symbols (bytes) per clock cycle
parameter NW            = `CX_NW;                           // Number of 32-bit dwords handled by the datapath each clock.
parameter DW            = (32*NW);                          // Width of datapath in bits.
parameter TP            = `TP;                              // Clock to Q delay (simulator insurance)

parameter RBUF_WD       = `RBUF_WIDTH;
parameter RBUF_PW       = `RBUF_PW;

parameter SOTBUF_WD     = `SOTBUF_WIDTH;                    // Stores pointer into RBUF RAM
parameter SOTBUF_PW     = `SOTBUF_L2DEPTH;                  // Indexed by sequence number (or some bits of it)

parameter DATA_PAR_WD         = `TRGT_DATA_PROT_WD;         // data bus parity width
parameter DW_W_PAR            = (32*NW)+DATA_PAR_WD;        // Width of datapath in bits plus the parity bits.
parameter RBUF_PROT_WD        = `RBUF_PROT_WD;
parameter RBUF_CTRL_BITS_WD   = `CX_RBUF_CTRL_WD;
parameter RBUF_CTRL_PROT_WD   = `RBUF_CTRL_PROT_WD;



parameter DATA_PROT_WD        =
                                    0 ;


parameter ALL_ZERO_DATA   = {
                              {DW{1'b0}}
                            };
parameter ALL_ZERO_SOTBUF = {
                             {RBUF_PW{1'b0}}
                             };

parameter MAX_SEQNUM    = 13'd4096;

parameter S_IDLE                = 4'h0;
parameter S_REPLY_REQ           = 4'h1;
parameter S_IN_REPLY            = 4'h2;
parameter S_WAIT_N_LATENCY_RETRYRAM = 4'h3;
parameter S_DONE_PIPE           = 4'h4;
parameter S_PRE_REQ             = 4'h6;
parameter S_WAIT_LATENCY        = 4'h8;
parameter S_SET_REPLY_REQ       = 4'h9;
parameter S_WAIT_N_LATENCY_SOTRAM = 4'ha;

parameter ESOT_WD =  (NW==16) ? 5 : (NW==8) ? (NW/2) : (NW-1);

parameter RETRYRAM_REG_RETRYBUF_INPUTS     = 1; // >= 1 always
parameter RETRYSOTRAM_REG_RETRYBUF_INPUTS  = 1; // >= 1 always

// To meet timing it is possible register the retrybuf output signals to the RAMs
parameter RETRYSOTRAM_REG_RETRYBUF_OUTPUTS = `CX_RETRYSOTRAM_REGOUT; // 0,1
parameter RETRYRAM_REG_RETRYBUF_OUTPUTS    = `CX_RETRYRAM_REGOUT;    // 0,1

parameter RETRY_RAM_RD_LATENCY             = `CX_RETRY_RAM_RD_LATENCY;     // 1(default), 2  #Latency = 1 for normal RAM
parameter RETRY_SOT_RAM_RD_LATENCY         = `CX_RETRY_SOT_RAM_RD_LATENCY; // 1(default), 2  #Latency = 1 for normal RAM

parameter DFIFO_WIDTH  =  (
                         // Data signals
                        RBUF_WD +                   // retryram_xdlh_data,
                        1 +                         // retryram_xdlh_parerr,
                        1                           // xdlh_retryram_rd_d

                        );

parameter PIPE2_WIDTH  =  (
                        // RETRY CTRL signals
                        1                           // xdlh_retryram_rd
                        );

parameter PIPE3_WIDTH  =  (
                         // Data signals
                        SOTBUF_WD +                 // retrysotram_xdlh_data,
                        1                           // retrysotram_xdlh_parerr,
                        );
parameter PIPE4_WIDTH  =  (
                        // SOT CTRL signals
                        1 +                         // xdlh_retrysotram_rd
                        1                           // latch_retry_start_addr
                        );

// REGOUT
parameter RETRYSOTRAM_REGOUT_WIDTH  =  (
                        SOTBUF_PW +                 // xdlh_retrysotram_waddr;          // Write Adrress to retry buffer RAM
            SOTBUF_PW +                 // xdlh_retrysotram_raddr;          // Read Adrress to retry buffer RAM
            SOTBUF_WD +                 // xdlh_retrysotram_data;            // Write data to retry buffer RAM
            1 +                         // xdlh_retrysotram_we;              // Write enable to retry buffer RAM
            1                           // xdlh_retrysotram_en;              // Read enable to retry buffer RAM
                        );

parameter RETRYRAM_REGOUT_WIDTH  =  (
                        RBUF_PW +                   // xdlh_retryram_addr;               // Adrress to retry buffer RAM
                        RBUF_WD +                   // xdlh_retryram_data;               // Write data to retry buffer RAM
                        1 +                         // xdlh_retryram_we;                 // Write enable to retry buffer RAM
                        1 +                         // xdlh_retryram_en;                 // Read enable to retry buffer RAM
                        1                           // xdlh_retryram_halt;
                        );
// END REGOUT

// ===============================================================
// ----- Inputs ---------------
// ===============================================================
xdlh_replay_num_if.master_mp    b_xdlh_replay_num;
xdlh_replay_timer_if.master_mp  b_xdlh_replay;
input                    core_clk;
input                    core_rst_n;
input                    smlh_link_in_training;
input                    rdlh_link_up;
input   [DW_W_PAR-1:0]   tlpgen_rbuf_data;
input   [NW-1:0]        tlpgen_rbuf_dwen;
input                    tlpgen_rbuf_dv;

input                    tlpgen_rbuf_sot;
input                    tlpgen_rbuf_eot;
input                    tlpgen_rbuf_badeot;

input   [11:0]           tlpgen_rbuf_seqnum;
input                    tlpgen_reply_grant;
input                    rbuf_halt;
input                   rdlh_xdlh_rcvd_nack;            // RDLP pulse signal to indicate that there was a nack pkt received, and its nack sequence number driven to rdlh_xdlh_rcvd_acknack_seqnum
input                   rdlh_xdlh_rcvd_ack;             // RDLP pulse signal to indicate that there was a ack pkt received, and its ack sequence number driven to rdlh_xdlh_rcvd_acknack_seqnum
input   [11:0]          rdlh_xdlh_rcvd_acknack_seqnum;  // RDLP received ack or nack pkt sequence number





// ===============================================================
// ----- outputs -----
// ===============================================================

// a tlp has request to be transmitted. At worst case, the tlp should be scheduled out at next 4 cycles (3 for FC pkt, 1for acknack)
output  [DW_W_PAR-1:0]  rbuf_xmt_data;
output  [NW-1:0]        rbuf_xmt_dwen;

output                  rbuf_xmt_sot;
output                  rbuf_xmt_eot;
output                  rbuf_xmt_badeot;

output                  rbuf_xmt_dv;
output                  rbuf_xmt_done;
output                  rbuf_reply_req;

output  [11:0]           rbuf_xmt_seqnum;
output  [11:0]           rbuf_pkt_cnt;
output  [RBUF_PW:0]     rbuf_entry_cnt;                 // Number of entry available
output                  rbuf_block_new_tlp;             // stop new tlp when a reply started, until a new progress has been made from ACK or NAK.
output                  xdlh_smlh_start_link_retrain;
output                   xdlh_rbuf_not_empty;
output                   xdlh_not_expecting_ack;
output  [11:0]           xdlh_rdlh_last_xmt_seqnum;


// Retry buffer RAM interfaces inputs/outputs declaration
input   [SOTBUF_WD -1:0]  retrysotram_xdlh_data;            // Data coming back from Retry buffer RAM
input   [SOTBUF_PW -1:0]  retrysotram_xdlh_depth ;
input                     retrysotram_xdlh_parerr ;
input   [RBUF_WD-1:0]     retryram_xdlh_data;               // Data coming back from Retry buffer RAM
input   [RBUF_PW-1:0]     retryram_xdlh_depth;              // Depth of retry buffer
input                     retryram_xdlh_parerr;             // retry buffer ram parity error detected
output  [RBUF_PW-1:0]     xdlh_retryram_addr;               // Adrress to retry buffer RAM
output  [RBUF_WD-1:0]     xdlh_retryram_data;               // Write data to retry buffer RAM
output                    xdlh_retryram_we;                 // Write enable to retry buffer RAM
output                    xdlh_retryram_en;                 // Read enable to retry buffer RAM
output                    xdlh_retryram_par_chk_val;        // parity check valid to retry buffer RAM
output                    xdlh_retryram_halt;

// Performance changes - 2p RAM I/F
// output  [SOTBUF_PW -1:0]  xdlh_retrysotram_addr;          // Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]  xdlh_retrysotram_waddr;          // Write Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]  xdlh_retrysotram_raddr;          // Read Adrress to retry buffer RAM
output  [SOTBUF_WD -1:0]  xdlh_retrysotram_data;            // Write data to retry buffer RAM
output                    xdlh_retrysotram_we;              // Write enable to retry buffer RAM
output                    xdlh_retrysotram_en;              // Read enable to retry buffer RAM
output                    xdlh_retrysotram_par_chk_val;     // parity check valid to retry buffer RAM
output                    xdlh_retry_req;                   // Retry Event
output                    xdlh_in_reply;                    // Retry FSM in the REPLY state
//
// ===============================================================
// ------------- IO declaration  ----------------
// ===============================================================
reg     [DW_W_PAR-1:0]   rbuf_xmt_data;
reg     [NW-1:0]         rbuf_xmt_dwen;
reg                      rbuf_xmt_sot;
reg                      rbuf_xmt_eot;
reg                      rbuf_xmt_badeot;
reg                      rbuf_xmt_dv;
wire                     rbuf_reply_req;
wire                     rbuf_xmt_done;
reg     [11:0]           rbuf_xmt_seqnum;
reg                      xdlh_smlh_start_link_retrain;
reg                      xdlh_rbuf_not_empty;
reg                      xdlh_not_expecting_ack;
reg                      rbuf_block_new_tlp;
wire    [11:0]           xdlh_rdlh_last_xmt_seqnum;
reg     [RBUF_PW:0]      rbuf_entry_cnt;                 // Number of entries available
reg     [11:0]           rbuf_pkt_cnt;
wire                     sotbuf_parerr;
reg                      xdlh_retry_req;

// ===============================================================
// ------------- Internal signals declaration  ----------------
// ===============================================================
//
// Now assign RAM input data
wire     [DW_W_PAR-1:0] int_data;
reg      [NW-1:0]       latchd_int_dwen;
wire     [NW-1:0]       int_dwen;
wire     [NW-1:0]       retry_ram_dwen;
wire     [DW_W_PAR-1:0] retry_ram_data;
wire                    int_sot;
wire                    int_eot;
wire                    int_badeot;
reg                     latchd_int_sot;
reg                     latchd_int_eot;
reg                     latchd_int_badeot;
reg      [11:0]         int_seqnum;
reg      [DW_W_PAR-1:0] latchd_int_data;
reg      [11:0]         latchd_int_seqnum;

wire                    int_halt;
reg                     dlyd_int_halt;

wire    [RBUF_WD-1:0]   rbuf_din;
wire    [RBUF_WD-1:0]   rbuf_dout;
wire    [RBUF_WD-1:0]   rbuf_dout_chk;
wire                    rbuf_parerr;


reg     [RBUF_WD-1:0]   retryram_xdlh_data_dd;
reg                     retryram_xdlh_parerr_dd;

// To report the right address when there is a failure
reg [RBUF_PW-1:0] xdlh_retryram_addr_dd[RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS-1:0];
always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
       for(i = 0; i < RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS; i = i + 1)
          xdlh_retryram_addr_dd[i] <= #TP 0;
    end else begin
       for(i = 0; i < RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if (xdlh_retryram_halt)
           xdlh_retryram_addr_dd[i] <= #TP xdlh_retryram_addr_dd[i];
         else begin
          if(i==0)
            xdlh_retryram_addr_dd[i] <= #TP xdlh_retryram_addr;
          else
            xdlh_retryram_addr_dd[i] <= #TP xdlh_retryram_addr_dd[i-1];
         end
      end // for
    end
  end


assign rbuf_dout   = retryram_xdlh_data_dd;
// assign rbuf_parerr = retryram_xdlh_parerr_dd; // NOTE: it was already commented

wire    [RBUF_PW-1:0]   rbuf_addr;
reg     [RBUF_PW-1:0]   rbuf_raddr;
reg     [RBUF_PW-1:0]   rbuf_waddr;
reg     [RBUF_PW-1:0]   latchd_start_waddr;
reg     [RBUF_PW-1:0]   next_ackd_tlp_addr; // the rbuf addr of the first unacknowledged tlp
wire                    rbuf_we;
wire    [RBUF_PW-1:0]   rbuf_waddr_plus1;
wire    [RBUF_PW-1:0]   rbuf_raddr_plus1;
// We assume the SOTBUF buffer is a register file under normal conditions, so it is not external
wire    [SOTBUF_PW-1:0] sotbuf_addr;
wire    [SOTBUF_PW-1:0] sotbuf_raddr;
reg     [SOTBUF_PW-1:0] sotbuf_waddr;
wire    [SOTBUF_PW-1:0] sotbuf_waddr_plus1;
wire    [SOTBUF_PW-1:0] sotbuf_waddr_minus1;
wire                    sotbuf_en;
wire                    sotbuf_we;
wire    [SOTBUF_WD-1:0] sotbuf_din;
wire    [RBUF_PW-1:0]   sotbuf_dout;

reg                     latchd_int_dv;
wire                    int_dv;
reg     [11:0]          schd_ackd_seqnum;
wire    [12:0]          schd_ackd_seqnum_plus1;
reg     [11:0]          ackd_seqnum;
wire    [12:0]          ackd_seqnum_plus1;
reg     [11:0]          rbuf_last_xmt_seqnum;
wire                    block_reply_start;
wire                    latch_retry_start_addr;
reg                     latch_retry_start_addr_regout;    // DELAY(RETRYSOTRAM_REGOUT)  [latch_retry_start_addr]
wire                    latch_retry_start_addr_d;         // DELAY(RETRY_SOT_RAM_RD_LATENCY)  [latch_retry_start_addr]
reg                     latch_retry_start_addr_dd;        // DELAY(RETRY_SOT_RAM_RD_LATENCY+1)[latch_retry_start_addr]

reg                     retry_requested;
reg     [3:0]           state;
wire                    all_tlp_schd_ackd;
wire                    xdlh_in_reply;
wire                    seqnum_upd;
reg                     seqnum_upd_by_ack;
reg                     seqnum_upd_by_nak;
reg                     rdlh_xdlh_rcvd_nack_d;
reg                     rdlh_xdlh_rcvd_ack_d;
wire                    reply_req;
wire                    rbuf_reply_done;
wire                    rbuf_reply_abort;
wire                    retryram_eot;
wire                    retryram_sot;
reg                     tlpgen_reply_grant_d;
wire                    reply_grant;

wire [RBUF_CTRL_BITS_WD-1:0] rbuf_ctrlbits;





reg reload_start_addr;
reg reload_start_addr_q;

reg smlh_link_in_training_d;
wire smlh_link_in_training_fall; // indicates an exit from the macro state (Configuration+Recovery)
wire link_retrain_pending;


// ===============================================================
// Design begin
// ===============================================================


//64b block
/*
`ifdef CX_TLP_PREFIX_ENABLE
`ifdef CX_GEN3_SPEED
assign rbuf_din         = {tlpgen_rbuf_len, tlpgen_rbuf_eot, tlpgen_rbuf_sot, tlpgen_rbuf_dwen, tlpgen_rbuf_data};
`else  // !CX_GEN3_SPEED
assign rbuf_din         = {tlpgen_rbuf_eot, tlpgen_rbuf_sot, tlpgen_rbuf_dwen, tlpgen_rbuf_data};
`endif  // CX_GEN3_SPEED
`else // !CX_TLP_PREFIX_ENABLE
assign rbuf_din         = {tlpgen_rbuf_eot, tlpgen_rbuf_sot, tlpgen_rbuf_dwen, tlpgen_rbuf_data};
`endif // CX_TLP_PREFIX_ENABLE
*/

assign rbuf_ctrlbits = {
                         tlpgen_rbuf_eot,
                         tlpgen_rbuf_sot,
                         tlpgen_rbuf_dwen };


assign rbuf_din = {rbuf_ctrlbits, tlpgen_rbuf_data};


//-----------------------------------------------------

//32b block
//-----------------------------------------------------

assign rbuf_we              = tlpgen_rbuf_dv;
assign rbuf_addr            = rbuf_we ? rbuf_waddr : rbuf_raddr;
assign rbuf_waddr_plus1     = (rbuf_waddr == retryram_xdlh_depth) ?  0 : rbuf_waddr + 1'b1;
assign rbuf_raddr_plus1     = (rbuf_raddr == retryram_xdlh_depth) ?  0 : rbuf_raddr + 1'b1;



wire rbuf_en;
assign rbuf_en = ((state != S_IDLE)
&& (state != S_PRE_REQ) && (state != S_SET_REPLY_REQ)
&& (state != S_REPLY_REQ) && (state != S_WAIT_N_LATENCY_SOTRAM)
) | rbuf_we;

reg xdlh_retryram_rd_regout;     // RD RETRYRAM RETRY_RAM_REG_RETRY_OUTPUTS                                     DELAYED
reg xdlh_retryram_rd_d;          // RD RETRYRAM RETRY_RAM_REG_RETRY_OUTPUTS+RETRY_RAM_RD_LATENCY                DELAYED
reg xdlh_retryram_rd_dd_m1;      // RD RETRYRAM RETRY_RAM_REG_RETRY_OUTPUTS+RETRY_RAM_RD_LATENCY+N REGOUT-1     DELAYED

wire xdlh_retrysotram_rd;        // RD SOTRAM
reg  xdlh_retrysotram_rd_regout; // RD SOTRAM RETRY_SOT_RAM_REG_RETRY_OUTPUTS                                   DELAYED
reg  xdlh_retrysotram_rd_d;      // RD SOTRAM RETRY_SOT_RAM_REG_RETRY_OUTPUTS+RETRY_SOT_RAM_RD_LATENCY          DELAYED
reg  xdlh_retrysotram_rd_dd;     // RD SOTRAM RETRY_SOT_RAM_REG_RETRY_OUTPUTS+RETRY_SOT_RAM_RD_LATENCY+N REGOUT DELAYED

wire xdlh_retryram_rd;
assign xdlh_retryram_rd = rbuf_en & !rbuf_we & !rbuf_reply_done; //rbuf_reply_done = (rbuf_wadd == rbuf_radd)
assign xdlh_retryram_par_chk_val = xdlh_retryram_rd_d;
wire xdlh_retryram_par_chk_val_dd;


// To know if the retrybuf is full or empty. empty only if last_retryram_action_was_we=0
reg last_retryram_action_was_we;
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        last_retryram_action_was_we <= #TP 1'b1;
            end else if(xdlh_retryram_we) begin
                last_retryram_action_was_we <= #TP 1'b1;
            end else if(xdlh_retryram_rd) begin
                last_retryram_action_was_we <= #TP 1'b0;
            end else begin
                last_retryram_action_was_we <= #TP last_retryram_action_was_we;
    end
end

// ##############################################################################################################################
// BEGIN RETRYRAM REGOUT RETRYBUF OUTPUTs
// ##############################################################################################################################

wire   [RETRYRAM_REGOUT_WIDTH-1 :0]        xdlh_retryram_bus_regin;

assign xdlh_retryram_bus_regin = {
                                   rbuf_addr,
                                   rbuf_din,
                                   rbuf_we,
                                   rbuf_en,
                                   dlyd_int_halt
                                 };

reg   [RETRYRAM_REGOUT_WIDTH-1 :0]        xdlh_retryram_bus;
reg xdlh_retryram_rd_ctrl;
genvar i;
generate if (RETRYRAM_REG_RETRYBUF_OUTPUTS > 0)begin : retrybufout
    reg    [RETRYRAM_REGOUT_WIDTH-1 :0]        xdlh_retryram_bus_regout[RETRYRAM_REG_RETRYBUF_OUTPUTS-1:0];
    reg [RETRYRAM_REG_RETRYBUF_OUTPUTS-1:0]    xdlh_retryram_rd_reg;

    always @(posedge core_clk or negedge core_rst_n)begin
        if(!core_rst_n)begin
            xdlh_retryram_bus_regout[0] <= #TP 0;
            xdlh_retryram_rd_reg[0] <= #TP 0;
        end else begin
            xdlh_retryram_bus_regout[0] <= #TP xdlh_retryram_bus_regin;
            xdlh_retryram_rd_reg[0] <= #TP xdlh_retryram_rd;
        end
    end

    for(i = 1; i < RETRYRAM_REG_RETRYBUF_OUTPUTS; i++)begin
        always @(posedge core_clk or negedge core_rst_n)begin
            if(!core_rst_n)begin
                xdlh_retryram_bus_regout[i] <= #TP 0;
                xdlh_retryram_rd_reg[i] <= #TP 0;
            end else begin
                xdlh_retryram_bus_regout[i] <= #TP xdlh_retryram_bus_regout[i-1];
                xdlh_retryram_rd_reg[i] <= #TP xdlh_retryram_rd_reg[i-1];
            end
        end
    end
    
    assign xdlh_retryram_bus = xdlh_retryram_bus_regout[RETRYRAM_REG_RETRYBUF_OUTPUTS-1];
    assign xdlh_retryram_rd_ctrl    = xdlh_retryram_rd_reg[RETRYRAM_REG_RETRYBUF_OUTPUTS-1];
end else begin  : retrybufout // if (RETRYRAM_REG_RETRYBUF_OUTPUTS > 0)
    assign xdlh_retryram_bus          = xdlh_retryram_bus_regin;
    assign xdlh_retryram_rd_ctrl      = xdlh_retryram_rd;
end
endgenerate

// Assign outputs to physical RAM
assign {
                        xdlh_retryram_addr,               // Adrress to retry buffer RAM
                        xdlh_retryram_data,               // Write data to retry buffer RAM
                        xdlh_retryram_we,                 // Write enable to retry buffer RAM
                        xdlh_retryram_en,                 // Read enable to retry buffer RAM
                        xdlh_retryram_halt
        } = xdlh_retryram_bus;

assign xdlh_retryram_rd_regout    = xdlh_retryram_rd_ctrl;

// ##############################################################################################################################
// END RETRYRAM REGOUT RETRYBUF OUTPUTs
// ##############################################################################################################################

//-----------------------------------------------------

// address control logic
//
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
       reload_start_addr <= #TP 1'b0;
    else reload_start_addr <= #TP  latch_retry_start_addr & seqnum_upd;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
       reload_start_addr_q <= #TP 1'b0;
    else reload_start_addr_q <= #TP  reload_start_addr;

assign reply_grant = tlpgen_reply_grant_d;

reg [RBUF_PW-1:0] rbuf_raddr_nxt;

always @ (*)
begin: rbuf_raddr_nxt_PROC
         if (latch_retry_start_addr_dd | reload_start_addr)
         rbuf_raddr_nxt  = sotbuf_dout;
        else if (((state == S_IN_REPLY | state == S_WAIT_N_LATENCY_RETRYRAM) & !int_halt & !rbuf_reply_done))
          rbuf_raddr_nxt = rbuf_raddr_plus1;
  else
    rbuf_raddr_nxt = rbuf_raddr;
end

reg sotbuf_we_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rbuf_waddr          <= #TP {RBUF_PW{1'b0}};
        rbuf_raddr          <= #TP {RBUF_PW{1'b0}};
        latchd_start_waddr  <= #TP {RBUF_PW{1'b0}};
        next_ackd_tlp_addr  <= #TP {RBUF_PW{1'b0}};
        ackd_seqnum         <= #TP 12'hFFF;
        sotbuf_we_d         <= #TP 1'b1;
        tlpgen_reply_grant_d<= #TP 1'b0;
    end else begin
        sotbuf_we_d         <= #TP sotbuf_we;
        tlpgen_reply_grant_d<= #TP tlpgen_reply_grant;
        rbuf_raddr          <= #TP rbuf_raddr_nxt;

//-----------------------------------------------------
//128b, 256b, 512b block
        if (rbuf_we & tlpgen_rbuf_eot & !tlpgen_rbuf_sot & tlpgen_rbuf_badeot)
          rbuf_waddr   <= #TP latchd_start_waddr;
        else if (rbuf_we & ( !tlpgen_rbuf_eot | (tlpgen_rbuf_eot & !tlpgen_rbuf_badeot)))
          rbuf_waddr   <= #TP rbuf_waddr_plus1;
//-----------------------------------------------------

        //
        // latch the starting address of a tlp when the tlp has been
        // written into retry buffer so that we can rewind when it is
        // a poisond tlp
        if (rbuf_we & tlpgen_rbuf_sot)
        latchd_start_waddr <= #TP rbuf_waddr;

        // When update the acked sequence number and the next acked tlp
        // addre, there could be a contention with current transmission of
        // a tlp that is also update the single port SOT RAM. Therefore, we
        // need to schedule a cycle that sot RAM read output is stable
        // to take a snap shot for updating the next ackd address pointer and the ackd sequence number.
    // Note: it is important to update the next acked address together
    // with acked sequence number.
        //
        //
        // Note: sotbuf_we_d indicates that the sotram output is not capable of providing the read out results.
        //       and when seq_upd_en is not assert, it inidcates that scheduled sequence number (i.e, SOT read address) has been stable for a cycle such that the output data from RAM
        //       on sotbuf_dout has bee ready for correlating to acked sequence number.


 // Performance change
//128b, 256b, 512b block
        if (all_tlp_schd_ackd)
           next_ackd_tlp_addr       <= #TP  rbuf_waddr; // when all pkt acked, then we will have to point to the next highest addr of rbuf
        else
           if (xdlh_retrysotram_rd_dd)
           next_ackd_tlp_addr       <= #TP  sotbuf_dout;

        if (!sotbuf_we_d & !seqnum_upd )
    // update the actual seqnum togather with the next acked address
           ackd_seqnum             <= #TP schd_ackd_seqnum ;
    end


// NEXTACK pointer RAM is designed to store the starting address of a tlp that
// is stored inside retrybuffer. It is address by the sequence number of
// an ack or nack dllp.
// NEXTACK buffer has the size of the max number of allowed tlp into retry buffer assuming the shortest tlp (3dword long)
// NEXTACK buffer is a circular buffer that wraps around  according to
// ackd_seqnum or last_xmt_seqnum. These seqnum mod NEXTACKBUF_DEPTH determines
// the address of the NEXTACK buffer read or write. Read address is depending
// on the ackd_seqnum. Write address is depending on last_xmt_seqnum
//
assign sotbuf_we                = (tlpgen_rbuf_sot & tlpgen_rbuf_dv & !tlpgen_rbuf_badeot); // update the sot content at the sot cycle

assign sotbuf_addr              = sotbuf_we ? sotbuf_waddr : sotbuf_raddr;


assign sotbuf_waddr_plus1       = (sotbuf_waddr == retrysotram_xdlh_depth) ? 0 : (sotbuf_waddr + 1);
assign sotbuf_waddr_minus1      = (sotbuf_waddr == {SOTBUF_PW{1'b0}}) ? retrysotram_xdlh_depth: (sotbuf_waddr - 1);


assign schd_ackd_seqnum_plus1   = {1'b0, schd_ackd_seqnum} + 1'b1;
assign sotbuf_raddr             = schd_ackd_seqnum_plus1[SOTBUF_PW-1 :0];

assign sotbuf_din               = rbuf_waddr;

//-----------------------------------------------------
//128b, 256b, 512b block
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        sotbuf_waddr    <= #TP 0;
    end else if(!rdlh_link_up) begin
        sotbuf_waddr    <= #TP 0;
    end else if (tlpgen_rbuf_eot & tlpgen_rbuf_badeot & !tlpgen_rbuf_sot & tlpgen_rbuf_dv) begin
        sotbuf_waddr    <= #TP sotbuf_waddr_minus1;
    end else if (sotbuf_we) begin
        sotbuf_waddr    <= #TP sotbuf_waddr_plus1;
    end


//-----------------------------------------------------

parameter S_ALL_ACKD                     = 2'h0;
parameter S_READ_SOT_ADD                 = 2'h1;
parameter S_WAIT_TO_ALL_ACKD             = 2'h2;

reg     [1:0]                   sot_state;
reg     [1:0]                   next_sot_state;

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        sot_state       <= #TP S_ALL_ACKD;
    end else begin
        sot_state       <= #TP next_sot_state;
    end
end

reg fsm_sotram_rd_en; // Output of SOTRAM FSM

always @(*) begin : SOTRAM_RD_EN_FSM

   fsm_sotram_rd_en = 1'b0;
   case (sot_state)
        S_ALL_ACKD:        begin
                              if(all_tlp_schd_ackd)
                                 next_sot_state    =  S_ALL_ACKD;
                              else
                                 next_sot_state    =  S_READ_SOT_ADD;
                           end

        S_READ_SOT_ADD:    begin
                              next_sot_state  =  S_WAIT_TO_ALL_ACKD;
                              fsm_sotram_rd_en = 1'b1;
                           end

        // SOTRAM is ram2p and we can read at the same time that write.
        S_WAIT_TO_ALL_ACKD:begin
                              if(all_tlp_schd_ackd)
                                 next_sot_state    =  S_ALL_ACKD;
                              else begin
                                 next_sot_state    =  S_WAIT_TO_ALL_ACKD;
                                 // all_tlp_schd_ackd=(sch_ackd_seqnum==rbuf_last_xmt_seqnum) both are DELAYED(1)[rdlh_xdlh_rcvd_acknack_seqnum] then
                                 // it has to be delayed 1clk the ack/nack signals checking.
                                 if(rdlh_xdlh_rcvd_ack_d | rdlh_xdlh_rcvd_nack_d) // RD again if it's received an ACK/NACK
                                    fsm_sotram_rd_en = 1'b1;
                              end
                           end

            default:    begin
                            next_sot_state  = S_ALL_ACKD;
                        end
   endcase
end

// ##############################################################################################################################
// BEGIN RETRYSOTRAM REGOUT RETRYBUF OUTPUTs
// ##############################################################################################################################

assign xdlh_retrysotram_rd = ( ((state == S_REPLY_REQ) & (!all_tlp_schd_ackd)) | fsm_sotram_rd_en );
assign xdlh_retrysotram_par_chk_val = xdlh_retrysotram_rd_d; // xdlh_retrysotram_rd_d is RD SOTRAM (RETRY_SOT_RAM_RD_REGOUT+RETRY_SOT_RAM_RD_LATENCY) DELAYED
assign sotbuf_en = ( ((state == S_REPLY_REQ) & (!all_tlp_schd_ackd)) | fsm_sotram_rd_en );

wire   [RETRYSOTRAM_REGOUT_WIDTH-1 :0]       xdlh_retrysotram_bus_regin;

assign xdlh_retrysotram_bus_regin = {
                        sotbuf_waddr,
                        sotbuf_raddr,
                        sotbuf_din,
                        sotbuf_we,
                        sotbuf_en
                      };

// REGOUT RETRYSOTRAM memory OUTPUT signals
reg [RETRYSOTRAM_REGOUT_WIDTH-1 :0] xdlh_retrysotram_bus;
reg xdlh_retrysotram_rd_ctrl;
reg latch_retry_start_addr_ctrl;
generate if (RETRYSOTRAM_REG_RETRYBUF_OUTPUTS > 0)begin : sotretrybuf
    reg    [RETRYSOTRAM_REGOUT_WIDTH-1 :0]        xdlh_retrysotram_bus_regout[RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1:0];
    reg [RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1:0]    xdlh_retrysotram_rd_reg;
    reg [RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1:0]    latch_retry_start_addr_reg;

    always @(posedge core_clk or negedge core_rst_n)begin
        if(!core_rst_n)begin
            xdlh_retrysotram_bus_regout[0] <= #TP 0;
            xdlh_retrysotram_rd_reg[0]     <= #TP 0;
            latch_retry_start_addr_reg[0] <= #TP 0;
        end else begin
            xdlh_retrysotram_bus_regout[0] <= #TP xdlh_retrysotram_bus_regin;
            xdlh_retrysotram_rd_reg[0]     <= #TP xdlh_retrysotram_rd;
            latch_retry_start_addr_reg[0] <= #TP latch_retry_start_addr;
        end
    end

    for(i = 1; i < RETRYSOTRAM_REG_RETRYBUF_OUTPUTS; i++)begin
        always @(posedge core_clk or negedge core_rst_n)begin
            if(!core_rst_n)begin
                xdlh_retrysotram_bus_regout[i] <= #TP 0;
                xdlh_retrysotram_rd_reg[i]     <= #TP 0;
                latch_retry_start_addr_reg[i] <= #TP 0;
            end else begin
                xdlh_retrysotram_bus_regout[i] <= #TP xdlh_retrysotram_bus_regout[i-1];
                xdlh_retrysotram_rd_reg[i]     <= #TP xdlh_retrysotram_rd_reg[i-1];
                latch_retry_start_addr_reg[i] <= #TP latch_retry_start_addr_reg[i-1];
            end
        end
    end
    
    assign xdlh_retrysotram_bus = xdlh_retrysotram_bus_regout[RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1];
    assign xdlh_retrysotram_rd_ctrl      = xdlh_retrysotram_rd_reg[RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1];
    assign latch_retry_start_addr_ctrl   = latch_retry_start_addr_reg[RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1];
end else begin  : sotretrybuf // if (RETRYSOTRAM_REG_RETRYBUF_OUTPUTS > 0)
    assign xdlh_retrysotram_bus          = xdlh_retrysotram_bus_regin;
    assign xdlh_retrysotram_rd_ctrl      = xdlh_retrysotram_rd;
    assign latch_retry_start_addr_ctrl   = latch_retry_start_addr;
end

endgenerate


assign {
                        xdlh_retrysotram_waddr,           // Write Adrress to retry buffer RAM
                        xdlh_retrysotram_raddr,           // Read Adrress to retry buffer RAM
                        xdlh_retrysotram_data,            // Write data to retry buffer RAM
                        xdlh_retrysotram_we,              // Write enable to retry buffer RAM
                        xdlh_retrysotram_en              // Read enable to retry buffer RAM
        } = xdlh_retrysotram_bus;

       assign xdlh_retrysotram_rd_regout    = xdlh_retrysotram_rd_ctrl;
       assign latch_retry_start_addr_regout = latch_retry_start_addr_ctrl;
// ##############################################################################################################################
// END RETRYSOTRAM REGOUT RETRYBUF OUTPUTs
// ##############################################################################################################################


reg     [SOTBUF_WD-1:0]   retrysotram_xdlh_data_dd;
reg                       retrysotram_xdlh_parerr_dd;
reg                       rbuf_reply_done_dd;

wire [RBUF_PW-1:0] ras_sotram_protect_dout;
reg  [RBUF_PW-1:0] ras_sotram_protect_dout_latchd;
reg ras_sotram_protect_parerr;
reg ras_sotram_protect_parerr_latchd;
always @(posedge core_clk or negedge core_rst_n)
  begin
    if (!core_rst_n) begin
      ras_sotram_protect_dout_latchd   <= #TP 1'b0;
      ras_sotram_protect_parerr_latchd <= #TP 1'b0;
    end else if(xdlh_retrysotram_rd_dd) begin
      ras_sotram_protect_dout_latchd   <= #TP ras_sotram_protect_dout[RBUF_PW-1:0];
      ras_sotram_protect_parerr_latchd <= #TP ras_sotram_protect_parerr;
  end
  end

assign sotbuf_dout   = xdlh_retrysotram_rd_dd ? ras_sotram_protect_dout[RBUF_PW-1:0] : ras_sotram_protect_dout_latchd;
assign sotbuf_parerr = xdlh_retrysotram_rd_dd ? ras_sotram_protect_parerr            : ras_sotram_protect_parerr_latchd;

assign pre_xdlh_retrysotram_en =  ((state == S_SET_REPLY_REQ) && reply_req && tlpgen_reply_grant )|| (next_sot_state  ==  S_READ_SOT_ADD );

// ###############################################################################################
//
// Data signals are delayed N cycles RAM Latency + 1 cycle RAM REGOUT(Register output of the RAM)
// signal_name       = DELAYED(0)
// signal_name_d     = DELAYED(LATENCY)
// signal_name_dd_m1 = DELAYED(LATENCY+REGOUT-1)
// signal_name_dd    = DELAYED(LATENCY+REGOUT)
//
// ###############################################################################################

// ##############################################################################################################################
// ### TO REGISTER RETRYRAM DATA SIGNALS 1 REGOUT AND STORE in FIFO if dlyd_int_halt ###
// ##############################################################################################################################

wire   [DFIFO_WIDTH-1 :0]       pipe_in_data;
wire   [DFIFO_WIDTH-1 :0]       pipe_out_data;
wire                            uncon_pipe_halt_out;
wire                            uncon_pipe_pipe_out_data_valid;

assign pipe_in_data = {
                        // Data from RETRYRAM memory
                          retryram_xdlh_data,
                          retryram_xdlh_parerr,
                          xdlh_retryram_rd_d
                      };

ram_latency_pipe
 #(
       .PIPE_WIDTH(DFIFO_WIDTH),
       .PIPE_INPUT_REG(RETRYRAM_REG_RETRYBUF_INPUTS),
       .PIPE_LATENCY(RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_OUTPUTS)
      )
u1_retry_pipe(
// ------ Inputs ------
    .core_clk              (core_clk),
    .core_rst_n            (core_rst_n),
    .halt_in               (dlyd_int_halt),
    .pipe_in_data_valid    (!dlyd_int_halt & (xdlh_retryram_en & !xdlh_retryram_we)),
    .pipe_in_data          (pipe_in_data),

// ------ Outputs ------
    .halt_out              (uncon_pipe_halt_out),
    .pipe_out_data_valid   (uncon_pipe_pipe_out_data_valid),
    .pipe_out_data         (pipe_out_data)
);

assign {
                        // Data REGOUT from RETRYRAM memory
                        retryram_xdlh_data_dd,
                        retryram_xdlh_parerr_dd,
                        xdlh_retryram_par_chk_val_dd
        } = pipe_out_data;

// ##############################################################################################################################
// pipe  => To register the data output of the RETRYRAM and store it in case dlyd_int_halt is set
// pipe2 => to align xdlh_retryram_rd_regout signal with the RAM latency of the incoming data => To generate xdlh_retryram_par_chk_val = xdlh_retryram_rd_d
// pipe3 => To register the data output of the SOTRAM
// pipe4 => To align xdlh_retrysotram_rd_regout signal with the  RAM latency of the incoming data => To generate xdlh_retrysotram_par_chk_val = xdlh_retrysotram_rd_d
// ##############################################################################################################################

wire   [PIPE2_WIDTH-1 :0]       pipe2_in_retry_ctrl;
reg    [PIPE2_WIDTH-1 :0]       pipe2_out_retry_ctrl[RETRY_RAM_RD_LATENCY-1:0];
wire   [PIPE3_WIDTH-1 :0]       pipe3_in_sot_data;
reg    [PIPE3_WIDTH-1 :0]       pipe3_out_sot_data[RETRYSOTRAM_REG_RETRYBUF_INPUTS-1:0];
wire   [PIPE4_WIDTH-1 :0]       pipe4_in_sot_ctrl;
reg    [PIPE4_WIDTH-1 :0]       pipe4_out_sot_ctrl[RETRY_SOT_RAM_RD_LATENCY-1:0];

// ### TO ALIGN RETRYRAM CTRL SIGNALS N LATENCY ###
assign pipe2_in_retry_ctrl = {
                        // Retry CTRL signals
                        xdlh_retryram_rd_regout
                      };

// ### TO REGISTER SOTRAM DATA SIGNALS 1 REGOUT ###
// They are not affected for the halt because they will be latched
assign pipe3_in_sot_data = {
                        // Data from SOTRAM memory
                        retrysotram_xdlh_data,
                        retrysotram_xdlh_parerr
                      };

// ### TO ALIGN SOTRAM CTRL SIGNALS N LATENCY ###
assign pipe4_in_sot_ctrl = {
                        // SOTRAM CTRL signals
                        xdlh_retrysotram_rd_regout,
                        latch_retry_start_addr_regout
                      };

always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
       for(i = 0; i < RETRY_RAM_RD_LATENCY; i = i + 1)
          pipe2_out_retry_ctrl[i] <= #TP 0;
    end else begin
       for(i = 0; i < RETRY_RAM_RD_LATENCY; i = i + 1) begin
         if(i==0)
            pipe2_out_retry_ctrl[i] <= #TP pipe2_in_retry_ctrl;
         else
            pipe2_out_retry_ctrl[i] <= #TP pipe2_out_retry_ctrl[i-1];
       end // for
    end
  end

always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
       for(i = 0; i < RETRYSOTRAM_REG_RETRYBUF_INPUTS; i = i + 1)
          pipe3_out_sot_data[i] <= #TP 0;
    end else begin
       for(i = 0; i < RETRYSOTRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if(i==0)
            pipe3_out_sot_data[i] <= #TP pipe3_in_sot_data;
         else
            pipe3_out_sot_data[i] <= #TP pipe3_out_sot_data[i-1];
       end // for
    end
  end

always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
       for(i = 0; i < RETRY_SOT_RAM_RD_LATENCY; i = i + 1)
          pipe4_out_sot_ctrl[i] <= #TP 0;
    end else begin
       for(i = 0; i < RETRY_SOT_RAM_RD_LATENCY; i = i + 1) begin
         if(i==0)
            pipe4_out_sot_ctrl[i] <= #TP pipe4_in_sot_ctrl;
      else
            pipe4_out_sot_ctrl[i] <= #TP pipe4_out_sot_ctrl[i-1];
       end // for
    end
  end

assign {
                        // Retry CTRL signals
                        xdlh_retryram_rd_d
        } = pipe2_out_retry_ctrl[RETRY_RAM_RD_LATENCY-1];

assign {
                        // Data from SOTRAM memory
                        retrysotram_xdlh_data_dd,
                        retrysotram_xdlh_parerr_dd
        } = pipe3_out_sot_data[RETRYSOTRAM_REG_RETRYBUF_INPUTS-1];

assign {
                        // SOTRAM CTRL signals
                        xdlh_retrysotram_rd_d,
                        latch_retry_start_addr_d
        } = pipe4_out_sot_ctrl[RETRY_SOT_RAM_RD_LATENCY-1];

// ### TO ALIGN CTRL SIGNALS N REGOUT ###
// In pipe4_in_sot_ctrl latch_retry_start_addr_d = DELAY(RETRY_SOT_RAM_RD_LATENCY)[latch_retry_start_addr]
// latch_retry_start_addr_dd = DELAY(RETRYSOTRAM_REG_RETRYBUF_INPUTS)[latch_retry_start_addr_d] = DELAY(RETRY_SOT_RAM_RD_LATENCY+RETRYSOTRAM_REG_RETRYBUF_INPUTS)[latch_retry_start_addr] because
// RAM is regout and Latency clk because latency
reg [RETRYSOTRAM_REG_RETRYBUF_INPUTS-1:0] xdlh_retrysotram_rd_d_nregout;
reg [RETRYSOTRAM_REG_RETRYBUF_INPUTS-1:0] latch_retry_start_addr_d_nregout;
always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
      xdlh_retrysotram_rd_d_nregout     <= #TP 0;
      latch_retry_start_addr_d_nregout  <= #TP 0;
    end else begin
      for(i = 0; i < RETRYSOTRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if(i==0) begin
            xdlh_retrysotram_rd_d_nregout[i]     <= #TP xdlh_retrysotram_rd_d;
            latch_retry_start_addr_d_nregout[i]  <= #TP latch_retry_start_addr_d;
         end else begin
            xdlh_retrysotram_rd_d_nregout[i]     <= #TP xdlh_retrysotram_rd_d_nregout[i-1];
            latch_retry_start_addr_d_nregout[i]  <= #TP latch_retry_start_addr_d_nregout[i-1];
         end
      end // for
    end
  end

assign xdlh_retrysotram_rd_dd    = xdlh_retrysotram_rd_d_nregout[RETRYSOTRAM_REG_RETRYBUF_INPUTS-1];
assign latch_retry_start_addr_dd = latch_retry_start_addr_d_nregout[RETRYSOTRAM_REG_RETRYBUF_INPUTS-1];

// To generate xdlh_retryram_rd_dd_m1 signal the core needs to take into account dlyd_int_halt as the ram_latency_pipe does to maintain the alignement
// To generate par_chk_val it is not needed dlyd_int_halt because the RAM it is not affected for the halt.
reg [RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS-1:0] xdlh_retryram_rd_dlyd_pipe;
always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
         xdlh_retryram_rd_dlyd_pipe <= #TP 0;
    end else begin
      if(!dlyd_int_halt) begin
        for(i = 0; i < RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if(i==0) begin
            xdlh_retryram_rd_dlyd_pipe[i]  <= #TP xdlh_retryram_rd;
         end else begin
            xdlh_retryram_rd_dlyd_pipe[i]  <= #TP xdlh_retryram_rd_dlyd_pipe[i-1];
         end
        end // for
      end //if(!dlyd_...
    end
  end

assign rbuf_reply_done_dd = !xdlh_retryram_rd_dlyd_pipe[RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS-2];

reg xdlh_retryram_rd_dd_m1_int;
generate if (RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS > 1)
    begin : retrybufall
       assign xdlh_retryram_rd_dd_m1_int = xdlh_retryram_rd_dlyd_pipe[RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS-2];
    end else begin : retrybufall
       assign xdlh_retryram_rd_dd_m1_int = xdlh_retryram_rd;
end
endgenerate
assign xdlh_retryram_rd_dd_m1 = xdlh_retryram_rd_dd_m1_int;

    assign ras_sotram_protect_dout[RBUF_PW-1:0] = retrysotram_xdlh_data_dd[RBUF_PW-1:0]; //  NO RAS
    assign ras_sotram_protect_parerr            = retrysotram_xdlh_parerr_dd;


// Logic beneath is designed to handle all the sequence related vectors
wire duplicate_ack;
assign duplicate_ack       =  (rdlh_xdlh_rcvd_acknack_seqnum == schd_ackd_seqnum);

assign ackd_seqnum_plus1 = {1'b0, ackd_seqnum} + 1'b1;

//-----------------------------------------------------

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rbuf_last_xmt_seqnum    <= #TP 12'hFFF;
    end else if(!rdlh_link_up) begin
        rbuf_last_xmt_seqnum    <= #TP 12'hFFF;
    end else if (tlpgen_rbuf_sot & tlpgen_rbuf_dv & !(tlpgen_rbuf_eot & tlpgen_rbuf_badeot)) begin
        // Capture the sequence number as packets are transmitted
        rbuf_last_xmt_seqnum    <= #TP tlpgen_rbuf_seqnum;
    end else if (!tlpgen_rbuf_sot & tlpgen_rbuf_eot & tlpgen_rbuf_dv & tlpgen_rbuf_badeot) begin
        rbuf_last_xmt_seqnum    <= #TP (rbuf_last_xmt_seqnum - 1'b1);
    end
//-----------------------------------------------------

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        schd_ackd_seqnum        <= #TP 12'hFFF;
    end else if (!rdlh_link_up) begin
        schd_ackd_seqnum        <= #TP 12'hFFF;
    end else if (rdlh_xdlh_rcvd_ack | rdlh_xdlh_rcvd_nack) begin
        schd_ackd_seqnum        <= #TP  rdlh_xdlh_rcvd_acknack_seqnum;
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        seqnum_upd_by_ack           <= #TP 1'b0;
        seqnum_upd_by_nak           <= #TP 1'b0;
        rdlh_xdlh_rcvd_nack_d       <= #TP 1'b0;
        rdlh_xdlh_rcvd_ack_d        <= #TP 1'b0;
    end else begin
        seqnum_upd_by_nak           <= #TP rdlh_xdlh_rcvd_nack & !duplicate_ack;
        seqnum_upd_by_ack           <= #TP rdlh_xdlh_rcvd_ack & !duplicate_ack;
        rdlh_xdlh_rcvd_nack_d       <= #TP rdlh_xdlh_rcvd_nack;
        rdlh_xdlh_rcvd_ack_d        <= #TP rdlh_xdlh_rcvd_ack;
    end
assign seqnum_upd           = seqnum_upd_by_ack | seqnum_upd_by_nak;
assign all_tlp_schd_ackd    = rbuf_last_xmt_seqnum == schd_ackd_seqnum;

// arbitration control process to control the retry and replay verse
// regular transmission

//32b block
assign reply_req = (retry_requested | b_xdlh_replay.replay_req) & !all_tlp_schd_ackd;

// ensure that we never consider a replay complete before it begins, always do
// at least one read, on the first cycle in the S_WAIT_N_LATENCY_RETRYRAM
// state
reg kickstart_reply;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        kickstart_reply <= #TP 1'b0;
    end else begin
        kickstart_reply <= #TP (state == S_WAIT_N_LATENCY_SOTRAM) && latch_retry_start_addr_dd;
    end
// we will terminate a reply by 3 conditions met:
// 1. When we have finished replay of all the tlp in retry buffer
// 2. When we have received an ack dllp that has acked all tlp in retry
// buffer
// 3. a parity error has happened during the replay.
assign rbuf_reply_done      = (rbuf_raddr == rbuf_waddr) && !last_retryram_action_was_we && !kickstart_reply;
// two conditions that cause a reply abort. One is all TLP acked and another one is the retryram_xdlh_parerr, the OR here is for instantant termination in the case of parerr asserted at the same cycle of eot.
// assign rbuf_reply_abort     = all_tlp_schd_ackd | rbuf_parerr | sotbuf_parerr;
assign rbuf_reply_abort     = all_tlp_schd_ackd;

// when replay start, the state machine leaves the idle state. The
// important thing to do at this cycle is to take a snap shot of currnt
// next acked address pointer as well as acked sequence number to start the
// replay at the right location. Due to the new ack/nack request could be
// asserted from rdlh asynchronious, there could be a boundary condition
// that the next acked address pointer is updated later than the acked
// sequence number. In order to make sure that we do not get out of synch,
// we need to block transition from idle state and delay the snapshot
// cycle.

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        state       <= #TP S_IDLE;
    end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Legacy code
        case (state)
        S_IDLE:
            if (reply_req)
               state       <= #TP S_PRE_REQ;
            else
               state       <= #TP S_IDLE;
        S_PRE_REQ:
            if (reply_req) begin
            if (!sotbuf_we)
                  state       <= #TP S_SET_REPLY_REQ;
               else
                  state       <= #TP S_PRE_REQ;
            end else
               state       <= #TP S_IDLE;

        S_SET_REPLY_REQ:
            if (reply_req) begin
              if (tlpgen_reply_grant)
               state       <= #TP S_REPLY_REQ;
            else
                  state       <= #TP S_SET_REPLY_REQ;
            end else
               state       <= #TP S_IDLE;

      //S_SOTRAM_RD
        S_REPLY_REQ: // xdlh_retrysotram_en = ((state == S_REPLY_REQ) & (!all_tlp_schd_ackd)) | sotbuf_we | fsm_sotram_rd_en ;
            // if there is a ECC error when reading from the SOT buffer we can't trust the start address
            // so the replay does not start. And never start a replay if core is in RASDP error mode
           if (sotbuf_parerr)
              state       <= #TP S_IDLE;
           else if (!seqnum_upd & !rbuf_reply_abort & !link_retrain_pending) begin
              // latch_retry_start_addr = !seqnum_upd & ((state == S_REPLY_REQ) & reply_grant & !rbuf_reply_abort) & !link_retrain_pending
              state                                <= #TP S_WAIT_N_LATENCY_SOTRAM;
           end else if (rbuf_reply_abort)
              state       <= #TP S_IDLE;
            else
              state       <= #TP S_REPLY_REQ;

        S_WAIT_N_LATENCY_SOTRAM:
            if (latch_retry_start_addr_dd)
              state       <= #TP S_WAIT_N_LATENCY_RETRYRAM;
            else
              state       <= #TP S_WAIT_N_LATENCY_SOTRAM;

        S_WAIT_N_LATENCY_RETRYRAM: begin
            if (xdlh_retryram_rd_dd_m1)
               state   <= #TP  S_IN_REPLY;
            else
              state       <= #TP S_WAIT_N_LATENCY_RETRYRAM;
        end

        S_IN_REPLY:
            // reply stop conditions:
            // 1. when read pointer reaches write pointer
            // 2. When all tlp have been ascked, we can abort to save some
            // bandwidth
            // Depending upon the halt condition, we need to make sure that
            // all tlps in the pipe will be transmitted to tlp gen block
            // Done state is designed to allow a cycle for the pipe to be
            // cleared up.

            if ((rbuf_reply_done_dd | rbuf_reply_abort ) & int_eot & !dlyd_int_halt)
               state       <= #TP S_WAIT_LATENCY;
            else
               state       <= #TP S_IN_REPLY;

        S_WAIT_LATENCY:
            // if (!int_halt & !dlyd_int_halt) => rbuf_xmt_dv <= #TP int_dv; else if(!int_halt & dlyd_int_halt) => rbuf_xmt_dv <= #TP latchd_int_dv
            if (!rbuf_xmt_dv)
               state   <= #TP S_DONE_PIPE;
    else
               state       <= #TP S_WAIT_LATENCY;

        S_DONE_PIPE:
            //in xdlh_tlp_gen_32b int_halt = xdctrl_tlp_halt & tlp_dv; then rbuf_halt=0 always but just in case..To set rbuf_xmt_done=1 1cycle without rbuf_hat=1
            if (!rbuf_halt)
              state       <= #TP S_IDLE;
            else
               state   <= #TP S_DONE_PIPE;

        default:
               state  <= #TP S_IDLE;
        endcase
// spyglass enable_block STARC05-2.11.3.1
    end//if else

// start block a new tlp from entering the retry buffer after a reply has been started
// until a forward progress of ack has been made
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        rbuf_block_new_tlp           <= #TP 1'b0;
    else if  (rdlh_xdlh_rcvd_ack_d | seqnum_upd_by_nak | all_tlp_schd_ackd | state == S_IDLE)  // when a new ack received, we should be able to make assumption that new TLP can be progressed regardless of the seqnum progressing

        rbuf_block_new_tlp           <= #TP 1'b0;
    else if (state == S_WAIT_N_LATENCY_RETRYRAM | state == S_PRE_REQ)
        rbuf_block_new_tlp           <= #TP 1'b1;

//-----------------------------------------------------
// State outputs
assign rbuf_xmt_done = (state == S_IDLE) || (state == S_DONE_PIPE);

// This signal controls when to take a snap shot at the address that we need to start reply with
assign latch_retry_start_addr = !seqnum_upd & (state == S_REPLY_REQ) & !rbuf_reply_abort & !link_retrain_pending // !link_retrain_pending to do 1 pulse only
;

// FSM is in the replay request state
assign xdlh_in_reply = (state != S_IDLE);

// ------------------------------------------------------------------------
// Logic beneath is designed for retry and replay functions.
// Here retry means when nack received, reply means the missing ack/nack
// for a period of time and replay timer expired
//
// retry control
// last xmt seqnum represents the transmitted highest seqnumber. It is used
// in receiver to detect whether or not a ACK/NACK DLLP contains the
// correct sequence number
// In order to identify the last transmitted highest sequence number, we
// need to make sure that this seq number is not updated by the replay or retry sequence
// number

// when rcvd seqnum wrap around 4096, then the delta between received
// seqnum and ackd_seqnum has to be greater than 2048 in order to identify
// a higher sequnce number recieved
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        retry_requested <= #TP 1'b0;
    end else begin

    // according to spec, a NAK can be ignored if a ACK received
    // afterwards with higher sequence number
    // A special function implemented here to ignore a nack that has same
    // seqnum as we transmitted
    // Note: when all tlp acked, if state has not entered into the reply,
    // the reply request will be deasserted, therefore we need to clear
    // all the requests for retry or reply.
        retry_requested <= #TP  (rdlh_xdlh_rcvd_nack_d & !all_tlp_schd_ackd) ? 1'b1
                            : ((state == S_REPLY_REQ) | all_tlp_schd_ackd | seqnum_upd_by_ack)
                                ? 1'b0 : retry_requested;
   end

// The following logic implements the replay timer
// 1. start at the eot of any TLP transmission
// 2. restart and reset the timer on each reply. Restart on the reply eot
// 3. ack received with forward progress, reset the replay timer
// 4. When replay timer expired or NACK received during non replay state, reset and hold the timer until reply with EOT
// 5. hold replay timer when LTSSM is in training
// 6. resets and hold when there is no outstanding unACKed TLPs
//
wire replay_timer_restart;


assign replay_timer_restart = !all_tlp_schd_ackd & (seqnum_upd_by_ack
                                                   ) ;

assign b_xdlh_replay.replay_timer_start = replay_timer_restart | ((b_xdlh_replay.replay_timer == 17'b0) & ((tlpgen_rbuf_dv & tlpgen_rbuf_eot & (state == S_IDLE))
                                                       | ((state != S_IDLE) & rbuf_xmt_eot & !rbuf_halt)));

assign b_xdlh_replay.replay_timer_hold  = smlh_link_in_training | b_xdlh_replay.replay_req;  // NACK will cause a replay request

assign b_xdlh_replay.replay_timer_reset = (reply_req & (state == S_IDLE)) | seqnum_upd_by_ack | all_tlp_schd_ackd | !rdlh_link_up;

assign b_xdlh_replay.replay_ack = ((state == S_REPLY_REQ) | all_tlp_schd_ackd);

// Replay Num Interface Drivers
assign b_xdlh_replay_num.replay_num_incr = (state == S_IDLE) & reply_req;
assign b_xdlh_replay_num.replay_num_reset = seqnum_upd;
assign b_xdlh_replay_num.replay_num_retrain_ack = smlh_link_in_training_fall;
// Request to retrain the link
assign link_retrain_pending = b_xdlh_replay_num.replay_num_retrain_req;

always @ (posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        xdlh_smlh_start_link_retrain    <= #TP 1'b0;
    else
        xdlh_smlh_start_link_retrain    <= #TP (b_xdlh_replay_num.replay_num == 2'b11) & (state == S_IDLE) & reply_req & !seqnum_upd ;

always @ (posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_link_in_training_d    <= #TP 1'b0;
    else
        smlh_link_in_training_d    <= #TP smlh_link_in_training;

assign smlh_link_in_training_fall = smlh_link_in_training_d & !smlh_link_in_training;


// misc error monitor
//wire        sotbuf_overflow_err   = (sotbuf_waddr == ackd_seqnum_plus1) & sotbuf_we;
//wire        rbuf_overflow_err     = (rbuf_waddr   == next_ackd_tlp_addr) & rbuf_we;

// -----------------------------------------------------------------------------
// output drives
assign rbuf_reply_req   = (state == S_SET_REPLY_REQ); //(state == S_REPLY_REQ); // ###


always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        xdlh_retry_req  <= #TP 1'b0;
    end
    else begin
        xdlh_retry_req  <= #TP (state == S_IDLE) & reply_req;
    end
end


//-----------------------------------------------------
//128b, 256b, 512b block
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        int_seqnum  <= #TP 12'b0;
    end else if (latch_retry_start_addr) begin
        // taking the same snap shot as rbuf_raddr being updated for the starting point of the reply
        int_seqnum  <= #TP schd_ackd_seqnum_plus1[11:0];
    end else if (int_eot & !dlyd_int_halt) begin
        int_seqnum  <= #TP int_seqnum + 1'b1;
    end
//-----------------------------------------------------

assign int_halt = rbuf_halt & rbuf_xmt_dv;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        dlyd_int_halt       <= #TP 1'b0;
    end else begin
        dlyd_int_halt       <= #TP int_halt;
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latchd_int_data     <= #TP ALL_ZERO_DATA;
        latchd_int_dwen     <= #TP 0;
        latchd_int_dv       <= #TP 1'b0;
        latchd_int_sot      <= #TP 1'b0;
        latchd_int_eot      <= #TP 1'b0;
        latchd_int_badeot   <= #TP 1'b0;
        latchd_int_seqnum   <= #TP 12'b0;
//`ifdef CX_TLP_PREFIX_ENABLE
//`endif
    end else if (!dlyd_int_halt) begin
        latchd_int_data     <= #TP int_data;
        latchd_int_dwen     <= #TP int_dwen;
        latchd_int_dv       <= #TP int_dv;
        latchd_int_sot      <= #TP int_sot;
        latchd_int_eot      <= #TP int_eot;
        latchd_int_badeot   <= #TP int_badeot;
        latchd_int_seqnum   <= #TP int_seqnum;
// `ifdef CX_TLP_PREFIX_ENABLE
//`endif
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rbuf_xmt_data       <= #TP ALL_ZERO_DATA;
        rbuf_xmt_dwen       <= #TP 0;
        rbuf_xmt_dv         <= #TP 1'b0;
        rbuf_xmt_sot        <= #TP 1'b0;
        rbuf_xmt_eot        <= #TP 1'b0;
        rbuf_xmt_badeot     <= #TP 1'b0;
        rbuf_xmt_seqnum     <= #TP 12'b0;
//`ifdef CX_TLP_PREFIX_ENABLE
//`endif
    end else if (!int_halt & dlyd_int_halt) begin
        rbuf_xmt_data       <= #TP latchd_int_data;
        rbuf_xmt_dwen       <= #TP latchd_int_dwen;
        rbuf_xmt_dv         <= #TP latchd_int_dv;
        rbuf_xmt_sot        <= #TP latchd_int_sot;
        rbuf_xmt_eot        <= #TP latchd_int_eot;
        rbuf_xmt_badeot     <= #TP latchd_int_badeot;
        rbuf_xmt_seqnum     <= #TP latchd_int_seqnum;
//`ifdef CX_TLP_PREFIX_ENABLE
//`endif
    end else if (!int_halt & !dlyd_int_halt) begin
        rbuf_xmt_data       <= #TP int_data;
        rbuf_xmt_dwen       <= #TP int_dwen;
        rbuf_xmt_dv         <= #TP int_dv;
        rbuf_xmt_sot        <= #TP int_sot;
        rbuf_xmt_eot        <= #TP int_eot;
        rbuf_xmt_badeot     <= #TP int_badeot;
        rbuf_xmt_seqnum     <= #TP int_seqnum;
//`ifdef CX_TLP_PREFIX_ENABLE
//`endif
    end

/*
    `ifdef CX_TLP_PREFIX_ENABLE
    `ifdef CX_GEN3_SPEED
    assign {retry_ram_tlp_len, retryram_eot, retryram_sot_enc, retry_ram_data} = rbuf_dout;
    `else  // !CX_GEN3_SPEED

    assign {retryram_eot, retryram_sot_enc, retry_ram_data} = rbuf_dout;
    `endif // CX_GEN3_SPEED

    `else  // !CX_TLP_PREFIX_ENABLE
    assign {retryram_eot, retryram_sot_enc, retry_ram_data} = rbuf_dout;
    `endif  // CX_TLP_PREFIX_ENABLE
*/


//-----------------------------------------------------
assign {retryram_eot, retryram_sot, retry_ram_dwen, retry_ram_data} = rbuf_dout;

    assign rbuf_parerr = retryram_xdlh_parerr_dd;



//-----------------------------------------------------
//128b, 256b, 512b block
assign int_dv               = (state == S_IN_REPLY) &  !reload_start_addr_q;
// assign int_sot              = (state == S_IN_REPLY) && retryram_sot && !rbuf_parerr;
// assign int_eot              = (state == S_IN_REPLY) && ((retryram_eot && !rbuf_parerr) || rbuf_parerr);
// assign int_badeot           = (state == S_IN_REPLY) && rbuf_parerr ;
// assign int_data             = int_dv ? retry_ram_data : {DW{1'b0}};

assign int_sot              = (state == S_IN_REPLY) && retryram_sot;
assign int_eot              = (state == S_IN_REPLY) && retryram_eot;
assign int_badeot           = 1'b0;
assign int_data             = int_dv ? retry_ram_data : ALL_ZERO_DATA;

assign int_dwen             = int_dv ? retry_ram_dwen : {NW{1'b0}};

/*
`ifdef CX_TLP_PREFIX_ENABLE
`ifdef CX_GEN3_SPEED
assign int_rbuf_tlp_len     = int_dv ? retry_ram_tlp_len : {11{1'b0}};
`endif
`endif
*/


//-----------------------------------------------------
// MISC outputs
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        xdlh_rbuf_not_empty         <= #TP 1'b0;
        xdlh_not_expecting_ack      <= #TP 1'b0;
    end else begin
        xdlh_rbuf_not_empty             <= #TP !all_tlp_schd_ackd;
        xdlh_not_expecting_ack          <= #TP all_tlp_schd_ackd;
    end

assign xdlh_rdlh_last_xmt_seqnum  = rbuf_last_xmt_seqnum;

wire[RBUF_PW:0] rbuf_entry_cnt_comb = 
                                      (next_ackd_tlp_addr > rbuf_waddr) ?
                                      ({1'b0,next_ackd_tlp_addr} - {1'b0,rbuf_waddr}) :
                                      next_ackd_tlp_addr == rbuf_waddr && !all_tlp_schd_ackd ?  // thoughts: condition on rbuf_entry_cnt being exactly 1 in previous cycle can be added to avoid spurious transitions to 0 when all_tlp_schd_ackd deasserts
                                      1'b0 :
                                      (({1'b0,retryram_xdlh_depth} +1'b1  - {1'b0,rbuf_waddr}) +
                                       {1'b0,next_ackd_tlp_addr});

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Sequence counters are intended to
// wrap without preseveration of carry/borrow
wire [11:0] rbuf_pkt_cnt_comb  = 
            (rbuf_last_xmt_seqnum > schd_ackd_seqnum)
            ?  (rbuf_last_xmt_seqnum - schd_ackd_seqnum)
            : ((MAX_SEQNUM -schd_ackd_seqnum) + rbuf_last_xmt_seqnum);
// spyglass enable_block W164a

always_comb begin
    rbuf_entry_cnt = rbuf_entry_cnt_comb;
    rbuf_pkt_cnt   = rbuf_pkt_cnt_comb;
end






// few thoughts:
// making receiver to get rid of the duplicate ack/nack and latch the sequence number, then there can be quit a good gate saving.
//------------------------------------------------------------------------------



endmodule
