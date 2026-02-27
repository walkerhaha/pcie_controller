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
// ---    $DateTime: 2020/06/29 10:07:26 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_pat_gen.sv#11 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit MAC Layer Pattern Generator
// --- This module generates the following patterns:
// ---     1. Training Sequence Ordered Sets (TS1, TS2)
// ---     2. Skip Ordered Sets
// ---     3. Fast Training Sequence Ordered Sets (FTS)
// ---     4. Electrical Idle Ordered Sets (EIDLE)
// ---     5. Compliance Pattern
// ---
// --- Data is passed to the xmlh_byte_xmt module in the same format as data coming
// --- from the xdlh (CX_NB*8*CX_NL bits) with CX_NB*8 bits for each lane.
// --- The xmlh_byte_xmt handles this data in the same way it handles data from the
// --- xmlh.
// ---
// --- Major sections:
// ---     1. Ordered set generator
// ---     2. Compliance pattern generator
// ---     3. Skip timer
// ---
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xmlh_pat_gen (
    core_clk,
    core_rst_n,

    poll_cmp_enter_act_pulse,
    cfg_n_fts,
  `ifndef SYNTHESIS
    smlh_ltssm_state,
  `endif // SYNTHESIS

    next_pat,
    load_pat,
    ltssm_ts_cntrl,
    ltssm_mod_ts,
    ltssm_ts_alt_protocol,
    ltssm_ts_auto_change,
    ltssm_ts_alt_prot_info,
    current_data_rate,
    active_nb,
    xmtbyte_idle_sent,
    xmtbyte_eidle_sent,

    // ---------------------------------outputs ------------------------
    os_start,
    os_end,
    xmlh_pat_ack,
    xmlh_pat_dv,
    xmlh_pat_data,
    xmlh_pat_datak,
    xmlh_pat_linkloc,
    xmlh_pat_laneloc,
    xmlh_pat_s15_4loc,
    xmlh_cmp_errloc,

    xmlh_dly_cmp_data,
    xmlh_dly_cmp_datak,
    xmlh_dly_cmp_errloc,

    xmtbyte_ts1_sent,
    xmtbyte_ts2_sent,
    xmlh_pat_fts_sent,
    xmlh_pat_eidle_sent,
    xmtbyte_skip_sent
);
// =============================================================================
// Parameters
// =============================================================================
parameter INST      = 0;                                // The uniquifying parameter for each port logic instance.
parameter NL        = `CX_NL;                           // Max number of lanes supported
parameter NB        = `CX_NB;                           // Number of symbols (bytes) per clock cycle
parameter NBK       = `CX_NBK;                          // Number of symbols (bytes) per clock cycle for datak
parameter NW        = `CX_PL_NW;                        // Number of 32-bit dwords handled by the datapath each clock.
parameter DW        = `CX_PL_DW;                        // Width of datapath in bits.
parameter AW        = `CX_ANB_WD;                       // Width of the active number of bytes
parameter NBIT      = `CX_NB * 8;                       // Number of bits per lane
parameter TP        = `TP;                              // Clock to Q delay (simulator insurance)

// =============================================================================
// input IO Declarations
// =============================================================================
input                   core_clk;
input                   core_rst_n;

input                   poll_cmp_enter_act_pulse;       // the first clock pulse in Polling.Active sending Compliance Pattern following from Polling.Compliance state
input   [7:0]           cfg_n_fts;                      // 8bits bus to specify the number of FTS we wish to receive for our receiver
  `ifndef SYNTHESIS
input   [5:0]           smlh_ltssm_state;               // ltssm states
  `endif // SYNTHESIS

input   [3:0]           next_pat;                       // encoded command from the xmlh_byte_xmt to select a pattern to generate
input                   load_pat;                       // load the symbol counter
input   [7:0]           ltssm_ts_cntrl;                 // training sequence control
input                   ltssm_mod_ts;                   // Tx modified TS
input                   ltssm_ts_alt_protocol;          // Alternate protocol
input                   ltssm_ts_auto_change;           // autonomous change/upconfig capable/select de-emphasis bit.  bit 6 of the data rate identifier field.
input   [56-1:0]        ltssm_ts_alt_prot_info;         // Alternate protocol info for sym14-8
input   [2:0]           current_data_rate;              // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
input   [AW-1:0]        active_nb;                      // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
input                   xmtbyte_idle_sent;
input                   xmtbyte_eidle_sent;

// =============================================================================
// output IO Declarations
// =============================================================================
output                  os_start;
output                  os_end;
output                  xmlh_pat_ack;
output                  xmlh_pat_dv;                    // Data valid from the pattern generator
output  [NBIT-1:0]      xmlh_pat_data;                  // Data from the pattern generator
output  [NBK-1:0]       xmlh_pat_datak;                 // Data K-char indicator from the pattern generator
output                  xmlh_pat_linkloc;               // Indicates the current data contains the link # field. Its location can be inferred from active_nb
output                  xmlh_pat_laneloc;               // Indicates the current data contains the lane # field. Its location can be inferred from active_nb
output  [15:4]          xmlh_pat_s15_4loc;              // Indicates the current data contains the sym15-4. Its location can be inferred from active_nb with [15] = sym15, ..., [4] = sym4
output                  xmlh_cmp_errloc;                // Indicates the current data contains the error count field. Its location can be inferred from active_nb

output  [NBIT-1:0]      xmlh_dly_cmp_data;              // Delayed compliance Data
output  [NBK-1:0]       xmlh_dly_cmp_datak;             // Delayed compliance K char
output                  xmlh_dly_cmp_errloc;            // Indicates the current data contains the error count field. Its location can be inferred from active_nb

output                  xmtbyte_ts1_sent;               // Indicates 1 TS1 ordered set has been sent based on LTSSM's command
output                  xmtbyte_ts2_sent;               // Indicates 1 TS2 ordered set has been sent based on LTSSM's command
output                  xmlh_pat_fts_sent;              // Indicates all fast training sequences have been sent based on LTSSM's command
output                  xmlh_pat_eidle_sent;            // Indicates 1 eidle ordered set has been sent based on LTSSM's command
output                  xmtbyte_skip_sent;              // Indicates 1 skip ordered set has been sent based on LTSSM's command


// =============================================================================
// Regs & Wires
// =============================================================================
// Register outputs
wire                    xmlh_pat_ack;                   // pattern command acknowledge
wire                    xmlh_pat_dv;                    // Data valid from the pattern generator
wire    [NBIT-1:0]      xmlh_pat_data;                  // Data from the pattern generator
wire    [NBK-1:0]       xmlh_pat_datak;                 // Data K-char indicator from the pattern generator
wire                    xmlh_pat_linkloc;               // Indicates the current data contains the link # field. Its location can be inferred from active_nb
wire                    xmlh_pat_laneloc;               // Indicates the current data contains the lane # field. Its location can be inferred from active_nb
wire    [15:4]          xmlh_pat_s15_4loc;              // Indicates Sym15 - 4
wire                    xmlh_cmp_errloc;                // Indicates the current data contains the error count field. Its location can be inferred from active_nb

wire                    xmtbyte_ts1_sent;               // Indicates 1 TS1 ordered set has been sent based on LTSSM's command
wire                    xmtbyte_ts2_sent;               // Indicates 1 TS2 ordered set has been sent based on LTSSM's command
wire                    xmlh_pat_fts_sent;              // Indicates all fast training sequences have been sent based on LTSSM's command
wire                    xmlh_pat_eidle_sent;             // Indicates 1 eidle ordered set has been sent based on LTSSM's command
wire                    xmtbyte_skip_sent;              // Indicates 1 skip ordered set has been sent based on LTSSM's command

wire    [NBIT-1:0]      xmlh_dly_cmp_data;              // Delayed compliance Data
wire    [NBK-1:0]       xmlh_dly_cmp_datak;             // Delayed compliance K char
wire                    xmlh_dly_cmp_errloc;            // Indicates the current data contains the error count field. Its location can be inferred from active_nb


// =============================================================================
// Internal registers
// =============================================================================
wire                    int_pat_ack;                    // pattern command acknowledge
reg                     int_pat_dv;                     // Internal Data Valid
wire    [NBIT-1:0]      int_pat_data;                   // Internal Data from the pattern generator
wire    [NBK-1:0]       int_pat_datak;                  // Internal Data K-char indicator from the pattern generator
reg                     int_pat_linkloc;                // Indicates the current data contains the link # field. Its location can be inferred from active_nb
reg                     int_pat_laneloc;                // Indicates the current data contains the lane # field. Its location can be inferred from active_nb
reg     [15:4]          int_pat_s15_4loc;               // Indicates the current data contains Symbol 15 - 4
reg                     int_cmp_errloc;                 // Indicates the current data contains the error count field. Its location can be inferred from active_nb
wire    [NBIT-1:0]      int_cmp_data;                   // Internal Data from the pattern generator
wire    [NBK-1:0]       int_cmp_datak;                  // Internal Data K-char indicator from the pattern generator
reg                     int_dly_cmp_errloc;             // Indicates the current data contains the error count field. Its location can be inferred from active_nb
wire    [4:0]           int_active_nb;                  // Indicates the active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s

wire                    int_ts1_sent;                   // Indicates 1 TS1 ordered set has been sent based on LTSSM's command
wire                    int_ts2_sent;                   // Indicates 1 TS2 ordered set has been sent based on LTSSM's command
wire                    int_fts_sent;                   // Indicates all fast training sequences have been sent based on LTSSM's command
wire                    int_eidle_sent;                 // Indicates 1 eidle ordered set has been sent based on LTSSM's command
wire                    int_skip_sent;                  // Indicates 1 skip ordered set has been sent based on LTSSM's command


reg     [3:0]           symbol_cnt;                     // symbol counter
reg                     os_start;                       // Indicate the start of an ordered set
wire                    os_end;                         // Indicate the start of an ordered set
reg                     os_end_d;                       // Registered version of os_end
wire                    load_pat;                       // load the symbol counter
wire    [AW-3:0]        active_nb_shift;                // Used to shift certain values according to S-ness. 1s = 0, 2s = 1, 4s = 2, 8s = 3 , 16s = 4

wire                    cmd_is_pat;                     // the current next_pat is a os pattern (handled by this module)
wire                    short_os_pat;                   // Indicates the OS pattern indicated by next_pat is a 4 symbol pattern
wire                    med_os_pat;                     // Indicates the OS pattern indicated by next_pat is a 8 symbol pattern
wire                    short_os_4s;                    // Indicates a 1 cycle OS when active_nb[2] 4S mode
reg     [3:0]           curnt_cmd;                      // The command currently be executed
reg     [3:0]           latched_cmd;                    // The command currently be executed
                                                        // Uses the PHY TX command defines in cxpl_defs.vh
wire    [127:0]         curnt_pat;                      // The current OS pattern
reg     [127:0]         curnt_pat_10b;                  // The current 8b/10b OS pattern
reg     [15:0]          curnt_pat_k;                    // The current OS kchar pattern

reg     [127:0]         curnt_dly_pat;                  // The current OS pattern
reg     [15:0]          curnt_dly_pat_k;                // The current OS kchar pattern


// Pattern wires
wire    [7:0]           curnt_ts_ident;                 // The identifier byte for the current TS type (TS1/TS2)
wire    [127:0]         ts_pat;                         // The TS1/2 Ordered set data pattern
wire    [31:0]          eidle_pat;                      // The EIDLE Ordered set data pattern
wire    [31:0]          fts_pat;                        // The FTS Ordered set data pattern
wire    [31:0]          skip_pat;                       // The SKIP Ordered set data pattern
wire    [31:0]          cmp_pat;                        // The Compliance data pattern
wire    [63:0]          cmp_dly_pat;                    // The Delayed Compliance data pattern

// Pattern kchar wires
wire                    tx_alt_protocol;                // Tx alternate protocols
wire    [15:0]          ts_pat_k;                       // The TS1/2 Ordered set data pattern
wire    [3:0]           eidle_pat_k;                    // The EIDLE Ordered set data pattern
wire    [3:0]           fts_pat_k;                      // The FTS Ordered set data pattern
wire    [3:0]           skip_pat_k;                     // The SKIP Ordered set data pattern
wire    [3:0]           cmp_pat_k;                      // The Compliance data pattern
wire    [7:0]           cmp_dly_pat_k;                  // The Delayed Compliance data pattern


// =============================================================================
// Internal logic
// =============================================================================

// Indicates the end of an ordered set.
assign  os_end      = (symbol_cnt == 0);

always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)
    os_end_d        <= #TP 1'b0;
else
    os_end_d        <= #TP os_end;

assign  short_os_4s = short_os_pat && active_nb[2];

// The short_os_4s is needed here because os_end will never deassert in 4S for short ordered sets so there would be no edge to pulse on
assign  int_pat_ack = (os_end && !os_end_d) || (load_pat && short_os_4s)
      ;

assign  cmd_is_pat  = (next_pat == `SEND_EIDLE) || (next_pat == `SEND_N_FTS)
                      || (next_pat == `SEND_TS1) || (next_pat == `SEND_TS2)
                      || (next_pat == `SEND_SKP);

assign short_os_pat = ((next_pat == `SEND_N_FTS) ||
                      (next_pat == `SEND_EIDLE) ||
                      (next_pat == `SEND_SKP)
                      );

assign med_os_pat = (next_pat == `COMPLIANCE_PATTERN);

// Indicates the start of an ordered set.
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)
    os_start        <= #TP 0;
else
    os_start        <= #TP load_pat;

//// The command currently in progress
//always @(posedge core_clk or negedge core_rst_n)
//if (!core_rst_n)
//    latched_cmd     <= #TP `SEND_IDLE;
//else
//    latched_cmd     <= #TP load_pat ? next_pat : latched_cmd;
//
//assign  curnt_cmd   = load_pat ? next_pat : latched_cmd;

// The command currently in progress
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)
    curnt_cmd     <= #TP `SEND_IDLE;
else
    curnt_cmd     <= #TP os_end ? next_pat : curnt_cmd;

// Aligned data width is 5 bits
assign int_active_nb = {1'b0,active_nb};

assign active_nb_shift = active_nb[2:1];                         // 1s = 0 , 2s = 1, 4s = 2

// Symbol Counter
wire [3:0] curr_symbol_cnt;

assign curr_symbol_cnt = symbol_cnt;

always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n) begin
    symbol_cnt      <= #TP 4'b0;
end else if ( poll_cmp_enter_act_pulse ) begin
// if xmtbyte_txcompliance_cmp_i in xmlh_byte_xmt is reset immediately outside Polling.Compliance, the core should not transmit Compliance Pattern immediately
// outside Polling.Compliance. When symbol_cnt = 0, os_end = 1 which causes load_pat = 1. The core sends TS1s in Polling.Active at the next clock.
    symbol_cnt      <= #TP 4'b0;
end else begin
    if (load_pat) begin  // load the symbol counter
        if (short_os_pat) begin
            symbol_cnt          <= #TP 4'd3  >> active_nb_shift;
        end else if (med_os_pat) begin
            symbol_cnt          <= #TP 4'd7  >> active_nb_shift;
        end else begin
            symbol_cnt          <= #TP 4'd15 >> active_nb_shift;
        end
    end else if ((curr_symbol_cnt == 4'h0)) begin // hold the count if the counter is zero
        symbol_cnt              <= #TP symbol_cnt;
    end else begin // advance to the next chunk of data
        symbol_cnt              <= #TP symbol_cnt - 4'h1;
    end
end

// select the current OS pattern and kchar pattern
always @(*)
         case (curnt_cmd)
        `SEND_TS1    : begin
            curnt_pat_10b   = ts_pat;
            curnt_pat_k     = ts_pat_k;
        end
        `SEND_TS2    : begin
            curnt_pat_10b   = ts_pat;
            curnt_pat_k     = ts_pat_k;
        end
        `SEND_EIDLE  : begin    // The eidle pattern is loaded twice because @ gen2 speeds it is sent twice
            curnt_pat_10b   = {eidle_pat, 96'b0};
            curnt_pat_k     = {eidle_pat_k, 12'b0};
        end
        `SEND_N_FTS  : begin
            curnt_pat_10b   = {fts_pat, 96'b0};
            curnt_pat_k     = {fts_pat_k, 12'b0};
        end
        `SEND_SKP    : begin
            curnt_pat_10b   = {skip_pat, 96'b0};
            curnt_pat_k     = {skip_pat_k, 12'b0};
        end
        `COMPLIANCE_PATTERN : begin
            curnt_pat_10b   = {cmp_pat, cmp_pat, 64'b0};
            curnt_pat_k     = {cmp_pat_k, cmp_pat_k, 8'b0};
        end
        default     : begin
            curnt_pat_10b   = 128'b0;
            curnt_pat_k     = 16'b0;
        end
    endcase // curnt_cmd

assign curnt_pat  = curnt_pat_10b;

always @(*)
begin : curnt_dly_proc
        begin
            curnt_dly_pat   = {cmp_dly_pat, 64'b0};
            curnt_dly_pat_k = {cmp_dly_pat_k, 8'b0};
        end
end

// internal data

// Indicates valid data
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)
    int_pat_dv      <= #TP 1'b0;
else
    if (load_pat)
        int_pat_dv  <= #TP 1'b1;
    else if (os_end)
        int_pat_dv  <= #TP 1'b0;
    else
        int_pat_dv  <= #TP int_pat_dv;


assign  int_pat_data    = DataSelect ( curnt_pat,   symbol_cnt, int_active_nb );
assign  int_pat_datak   = DataKSelect( curnt_pat_k, symbol_cnt, int_active_nb );

assign  int_cmp_data    = DataSelect ( curnt_dly_pat,   symbol_cnt, int_active_nb );
assign  int_cmp_datak   = DataKSelect( curnt_dly_pat_k, symbol_cnt, int_active_nb );

// Determine the location of link and lane number fields in TS ordered sets
always @(*)
if ( (curnt_cmd == `SEND_TS1) || (curnt_cmd == `SEND_TS2))  // only needed for TS1 & TS2

         case (int_active_nb)
        5'b00001 : begin   // 1s
            int_pat_linkloc     = (symbol_cnt == 4'd14);
            int_pat_laneloc     = (symbol_cnt == 4'd13);
            int_pat_s15_4loc[4] = (symbol_cnt == 4'd11);    // Symbol 9
            int_pat_s15_4loc[5] = (symbol_cnt == 4'd10);    // Symbol 9
            int_pat_s15_4loc[6] = (symbol_cnt == 4'd9);     // Symbol 9
            int_pat_s15_4loc[7] = (symbol_cnt == 4'd8);     // Symbol 9
            int_pat_s15_4loc[8] = (symbol_cnt == 4'd7);     // Symbol 9
            int_pat_s15_4loc[9] = (symbol_cnt == 4'd6);     // Symbol 9
            int_pat_s15_4loc[10] = (symbol_cnt == 4'd5);    // Symbol 10
            int_pat_s15_4loc[11] = (symbol_cnt == 4'd4);    // Symbol 11
            int_pat_s15_4loc[12] = (symbol_cnt == 4'd3);    // Symbol 12
            int_pat_s15_4loc[13] = (symbol_cnt == 4'd2);    // Symbol 13
            int_pat_s15_4loc[14] = (symbol_cnt == 4'd1);    // Symbol 14
            int_pat_s15_4loc[15] = (symbol_cnt == 4'd0);    // Symbol 15
        end
        5'b00010 : begin   // 2s
            int_pat_linkloc     = (symbol_cnt == 4'd7);
            int_pat_laneloc     = (symbol_cnt == 4'd6);
            int_pat_s15_4loc[4] = (symbol_cnt == 4'd5);     // Symbol 4
            int_pat_s15_4loc[5] = (symbol_cnt == 4'd5);     // Symbol 5
            int_pat_s15_4loc[6] = (symbol_cnt == 4'd4);     // Symbol 6
            int_pat_s15_4loc[7] = (symbol_cnt == 4'd4);     // Symbol 7
            int_pat_s15_4loc[8] = (symbol_cnt == 4'd3);     // Symbol 8
            int_pat_s15_4loc[9] = (symbol_cnt == 4'd3);     // Symbol 9
            int_pat_s15_4loc[10] = (symbol_cnt == 4'd2);    // Symbol 10
            int_pat_s15_4loc[11] = (symbol_cnt == 4'd2);    // Symbol 11
            int_pat_s15_4loc[12] = (symbol_cnt == 4'd1);    // Symbol 12
            int_pat_s15_4loc[13] = (symbol_cnt == 4'd1);    // Symbol 13
            int_pat_s15_4loc[14] = (symbol_cnt == 4'd0);    // Symbol 14
            int_pat_s15_4loc[15] = (symbol_cnt == 4'd0);    // Symbol 15
        end
        5'b00100 : begin   // 4s
            int_pat_linkloc     = (symbol_cnt == 4'd3);
            int_pat_laneloc     = (symbol_cnt == 4'd3);
            int_pat_s15_4loc[4] = (symbol_cnt == 4'd2);     // Symbol 4
            int_pat_s15_4loc[5] = (symbol_cnt == 4'd2);     // Symbol 5
            int_pat_s15_4loc[6] = (symbol_cnt == 4'd2);     // Symbol 6
            int_pat_s15_4loc[7] = (symbol_cnt == 4'd2);     // Symbol 7
            int_pat_s15_4loc[8] = (symbol_cnt == 4'd1);     // Symbol 8
            int_pat_s15_4loc[9] = (symbol_cnt == 4'd1);     // Symbol 9
            int_pat_s15_4loc[10] = (symbol_cnt == 4'd1);    // Symbol 10
            int_pat_s15_4loc[11] = (symbol_cnt == 4'd1);    // Symbol 11
            int_pat_s15_4loc[12] = (symbol_cnt == 4'd0);    // Symbol 12
            int_pat_s15_4loc[13] = (symbol_cnt == 4'd0);    // Symbol 13
            int_pat_s15_4loc[14] = (symbol_cnt == 4'd0);    // Symbol 14
            int_pat_s15_4loc[15] = (symbol_cnt == 4'd0);    // Symbol 15
        end
        5'b01000 : begin   // 8s
            int_pat_linkloc     = (symbol_cnt == 4'd1);
            int_pat_laneloc     = (symbol_cnt == 4'd1);
            int_pat_s15_4loc[4] = (symbol_cnt == 4'd1);     // Symbol 4
            int_pat_s15_4loc[5] = (symbol_cnt == 4'd1);     // Symbol 5
            int_pat_s15_4loc[6] = (symbol_cnt == 4'd1);     // Symbol 6
            int_pat_s15_4loc[7] = (symbol_cnt == 4'd1);     // Symbol 7
            int_pat_s15_4loc[8] = (symbol_cnt == 4'd0);     // Symbol 8
            int_pat_s15_4loc[9] = (symbol_cnt == 4'd0);     // Symbol 9
            int_pat_s15_4loc[10] = (symbol_cnt == 4'd0);     // Symbol 10
            int_pat_s15_4loc[11] = (symbol_cnt == 4'd0);     // Symbol 11
            int_pat_s15_4loc[12] = (symbol_cnt == 4'd0);     // Symbol 12
            int_pat_s15_4loc[13] = (symbol_cnt == 4'd0);     // Symbol 13
            int_pat_s15_4loc[14] = (symbol_cnt == 4'd0);     // Symbol 14
            int_pat_s15_4loc[15] = (symbol_cnt == 4'd0);     // Symbol 15
        end
        default: begin
            int_pat_linkloc     = 1'b0;
            int_pat_laneloc     = 1'b0;
            int_pat_s15_4loc    = 0;
        end
    endcase
else begin
    int_pat_linkloc     = 1'b0;
    int_pat_laneloc     = 1'b0;
    int_pat_s15_4loc    = 0;
end


// Determine the location of error error status fields in compliance patterns
always @(*)
if (curnt_cmd == `MOD_COMPL_PATTERN)  // only needed for Modified Compliance
    case (int_active_nb)
        5'b00001 : begin   // 1s
            int_cmp_errloc      = (symbol_cnt == 4'd11) || (symbol_cnt == 4'd10) || (symbol_cnt == 4'd3) || (symbol_cnt == 4'd2);
            int_dly_cmp_errloc  = (symbol_cnt == 4'd7)  || (symbol_cnt == 4'd6);
        end
        5'b00010 : begin   // 2s
            int_cmp_errloc      = (symbol_cnt == 4'd5) || (symbol_cnt == 4'd1);
            int_dly_cmp_errloc  = (symbol_cnt == 4'd3);
        end
        5'b00100 : begin   // 4s
            int_cmp_errloc      = (symbol_cnt == 4'd2) || (symbol_cnt == 4'd0);
            int_dly_cmp_errloc  = (symbol_cnt == 4'd1);
        end
        5'b01000 : begin   // 8s
            int_cmp_errloc      = (symbol_cnt == 4'd1) || (symbol_cnt == 4'd0);
            int_dly_cmp_errloc  = (symbol_cnt == 4'd0);
        end
        default: begin
            int_cmp_errloc      = 1'b0;
            int_dly_cmp_errloc  = 1'b0;
        end
    endcase
else begin
    int_cmp_errloc              = 1'b0;
    int_dly_cmp_errloc          = 1'b0;
end



assign  int_ts1_sent    = os_start && int_pat_dv && (curnt_cmd == `SEND_TS1);
assign  int_ts2_sent    = os_start && int_pat_dv && (curnt_cmd == `SEND_TS2);
assign  int_fts_sent    = os_start && int_pat_dv && (curnt_cmd == `SEND_N_FTS);
assign  int_eidle_sent  = os_end   && int_pat_dv && (curnt_cmd == `SEND_EIDLE);
assign  int_skip_sent   = os_start && int_pat_dv && (curnt_cmd == `SEND_SKP);

// Output data
parameter N_DELAY_CYLES     = 0;
parameter DATAPATH_WIDTH    = 2                  // ack,dv
                              + NBIT             // data
                              + NBK              // datak
                              + NBIT             // cmp_data
                              + NBK              // cmp_datak
                              + 12               // pat_s15_4loc
                              + 9;               // linkloc, laneloc, cmp_errloc, dly_cmp_errloc
                                                 // ts1_sent, ts2_sent, fts_sent, eidle_sent, skip_sent
delay_n

#(N_DELAY_CYLES, DATAPATH_WIDTH) u0_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({  int_pat_ack, int_pat_dv, int_pat_data, int_pat_datak, int_cmp_data, int_cmp_datak,
                    int_pat_linkloc, int_pat_laneloc, int_cmp_errloc, int_dly_cmp_errloc,
                    int_pat_s15_4loc,
                    int_ts1_sent, int_ts2_sent, int_fts_sent,
                    int_eidle_sent, int_skip_sent}),
    .dout       ({  xmlh_pat_ack, xmlh_pat_dv, xmlh_pat_data, xmlh_pat_datak, xmlh_dly_cmp_data, xmlh_dly_cmp_datak,
                    xmlh_pat_linkloc, xmlh_pat_laneloc, xmlh_cmp_errloc, xmlh_dly_cmp_errloc,
                    xmlh_pat_s15_4loc,
                    xmtbyte_ts1_sent, xmtbyte_ts2_sent, xmlh_pat_fts_sent,
                    xmlh_pat_eidle_sent, xmtbyte_skip_sent})
);



// ====================
// Ordered Set Patterns
// ====================

assign  curnt_ts_ident  = (curnt_cmd == `SEND_TS1) ? `TS1_8B : `TS2_8B;

// TS Ordered Set  Length 16 symbols
assign  tx_alt_protocol = ltssm_mod_ts & ltssm_ts_alt_protocol;
assign  ts_pat_k        = { {10{1'b0}}, 3'b000, 3'b111};// 10 TS, trn. cntl., datarate, n_fts, lane# (pad), link# (pad), comma
assign  ts_pat          = { curnt_ts_ident,             // sym15 of the current TS identifier (TS1/TS2). if Modified TS, will replace the sym with even parity in xmlh_byte_xmt.v
                            ltssm_mod_ts ? (ltssm_ts_alt_protocol ? ltssm_ts_alt_prot_info[55:32] : 24'h0) : {3{curnt_ts_ident}}, // sym14-12, not support Modified TS Usage yet, hardwired to 0
                            ltssm_mod_ts ? (ltssm_ts_alt_protocol ? ltssm_ts_alt_prot_info[31:16] : 16'h0) : {2{curnt_ts_ident}}, // sym11-10, not support Vendor ID yet, hardwired to 0
                            ltssm_mod_ts ? (ltssm_ts_alt_protocol ? ltssm_ts_alt_prot_info[15:0]  : 16'h0) : {2{curnt_ts_ident}}, // sym9-8,   not support Modified TS Usage yet, hardwired to 0
                            {2{curnt_ts_ident}},                           // sym7-6
                    //  Training Control 7:0
                    //        3'b000,                     // Reserved, Training Control bits 7 -> Modified TS Format for Gen5
                            ltssm_ts_cntrl,             // Training Control bits 4:0 -> 7:0, Modified TS Format for Gen5
                    //  Data Rate Identifier 7:0
                            1'b0,                       // Speed change, Data Rate Ident, bit 7
                            ltssm_ts_auto_change,       // autonomous change/upconfig capable/select de-emphasis, Data Rate Ident, bit 6
                            1'b0,                       // Reserved, Data Rate Ident bit 5
                            4'b0001,                    // Supported link speeds, Data Rate Ident bits 4:1 (Only 2.5Gb/s Data Rate Supported)
                            1'b0,                       // Data Rate Ident bit 0, Reserved
                    //  NFTS 7:0
                            cfg_n_fts,                  // N_FTS
                            `K237_8B,                   // Lane Num, Pad here, replaced with actual number elsewhere
                            `K237_8B,                   // Link Num, Pad here, replaced with actual number elsewhere
                            `COMMA_8B };                // Comma

// Electrical Idle Ordered Set  Length 4 symbols
assign  eidle_pat_k     =   4'b1111;                    // All kchars
assign  eidle_pat       = { {3{`EIDLE_8B}},             // 3 EIDLEs, Symbols 3-1
                            `COMMA_8B };                // Comma, Symbol 0

// Skip Ordered Set  Length 4 symbols
assign  skip_pat_k      =   4'b1111;                    // All kchars
assign  skip_pat        = { {3{`SKIP_8B}},              // 3 Skips, Symbols 3-1
                            `COMMA_8B };                // Comma, Symbol 0
// FTS Ordered Set  Length 4 symbols
assign  fts_pat_k       =   4'b1111;                    // All kchars
assign  fts_pat         = { {3{`FTS_8B}},               // 3 FTS, Symbols 3-1
                            `COMMA_8B };                // Comma, Symbol 0

// Compliance Pattern  Length 4 symbols
assign  cmp_pat_k       =   4'b0101;
assign  cmp_pat         = { `D102_8B,                   // D10.2, Symbol 3
                            `COMMA_8B,                  // Comma, Symbol 2
                            `D215_8B,                   // D21.5, Symbol 1
                            `COMMA_8B };                // Comma, Symbol 0

// Delayed Compliance Pattern  Length 8 symbols
assign  cmp_dly_pat_k   =   8'b11010111;
assign  cmp_dly_pat     = { {2{`COMMA_8B}},             // 2 Commas, Symbols 6-7
                            `D102_8B,                   // D10.2, Symbol 5
                            `COMMA_8B,                  // Comma, Symbol 4
                            `D215_8B,                   // D21.5, Symbol 3
                            {3{`COMMA_8B}} };           // 3 Commas, Symbols 2-0




// =============================================================================
// Functions
// =============================================================================

// Selects an active_nb byte section of a pattern and returns it.
// LMD: Case statement without default clause and not all cases are covered
// LJ: don't need "default : DataSelect = {NBIT{1'b0}};" because DataSelect initializes to '0'
// leda W71 off
// LMD: This rule fires if all the alternatives of the case statement are not covered and if there is no default clause.
// LJ: don't need "default : DataKSelect = {NB{1'b0}};" because DataKSelect initializes to '0'
// leda DFT_022 off
function automatic [NBIT-1:0] DataSelect;
    input   [127:0]         pat;                        // The OS pattern
    input   [3:0]           part;                       // which part of the pattern to return
    input   [4:0]           active_nb;                  // Current "S"ness

begin
    DataSelect = {NB{1'b0}};

         case (active_nb)

        5'b00010 :    // 2s

                 case (part)
                4'd7    : DataSelect[15:0] = pat[15:0];
                4'd6    : DataSelect[15:0] = pat[31:16];
                4'd5    : DataSelect[15:0] = pat[47:32];
                4'd4    : DataSelect[15:0] = pat[63:48];
                4'd3    : DataSelect[15:0] = pat[79:64];
                4'd2    : DataSelect[15:0] = pat[95:80];
                4'd1    : DataSelect[15:0] = pat[111:96];
                4'd0    : DataSelect[15:0] = pat[127:112];
                default : DataSelect[15:0] = 16'b0;
            endcase // part




/*
        default :
            DataSelect = {NBIT{1'b0}};
*/
    endcase // active_nb
end
endfunction // DataSelect
// leda W71 on
// leda DFT_022 on

// Selects active_nb bit section of a patterns k char vector and returns it.
// LMD: Case statement without default clause and not all cases are covered
// LJ: don't need "default : DataKSelect = {NB{1'b0}};" because DataKSelect initializes to '0'
// leda W71 off
// LMD: This rule fires if all the alternatives of the case statement are not covered and if there is no default clause.
// LJ: don't need "default : DataKSelect = {NB{1'b0}};" because DataKSelect initializes to '0'
// leda DFT_022 off
function automatic [NBK-1:0] DataKSelect;
    input   [15:0]          patk;                       // The OS pattern
    input   [3:0]           part;                       // which part of the pattern to return
    input   [4:0]           active_nb;                  // Current "S"ness

begin
    DataKSelect = {NBK{1'b0}};

         case (active_nb)

        5'b00010 :    // 2s

                 case (part)
                4'd7    : DataKSelect[1:0]  = patk[1:0];
                4'd6    : DataKSelect[1:0]  = patk[3:2];
                4'd5    : DataKSelect[1:0]  = patk[5:4];
                4'd4    : DataKSelect[1:0]  = patk[7:6];
                4'd3    : DataKSelect[1:0]  = patk[9:8];
                4'd2    : DataKSelect[1:0]  = patk[11:10];
                4'd1    : DataKSelect[1:0]  = patk[13:12];
                4'd0    : DataKSelect[1:0]  = patk[15:14];
                default : DataKSelect[1:0]  = 2'b0;
            endcase // part




/*
        default :
            DataKSelect = {NB{1'b0}};
*/
    endcase // active_nb

end
endfunction // DataKSelect
// leda W71 on
// leda DFT_022 on


`ifndef SYNTHESIS
wire    [21*8:0]           NEXT_PAT;

assign  NEXT_PAT =
               ( next_pat == `SEND_IDLE             ) ? "SEND_IDLE" :
               ( next_pat == `SEND_EIDLE            ) ? "SEND_EIDLE" :
               ( next_pat == `XMT_IN_EIDLE          ) ? "XMT_IN_EIDLE" :
               ( next_pat == `SEND_RCVR_DETECT_SEQ  ) ? "SEND_RCVR_DETECT_SEQ" :
               ( next_pat == `SEND_TS1              ) ? "SEND_TS1" :
               ( next_pat == `SEND_TS2              ) ? "SEND_TS2" :
               ( next_pat == `COMPLIANCE_PATTERN    ) ? "COMPLIANCE_PATTERN" :
               ( next_pat == `MOD_COMPL_PATTERN     ) ? "MOD_COMPL_PATTERN" :
               ( next_pat == `SEND_BEACON           ) ? "SEND_BEACON" :
               ( next_pat == `SEND_N_FTS            ) ? "SEND_N_FTS" :
               ( next_pat == `NORM                  ) ? "NORM" :
               ( next_pat == `SEND_SKP              ) ? "SEND_SKP" :
                                                         "Bogus";

wire    [21*8:0]           CURNT_CMD;

assign  CURNT_CMD =
               ( curnt_cmd == `SEND_IDLE             ) ? "SEND_IDLE" :
               ( curnt_cmd == `SEND_EIDLE            ) ? "SEND_EIDLE" :
               ( curnt_cmd == `XMT_IN_EIDLE          ) ? "XMT_IN_EIDLE" :
               ( curnt_cmd == `SEND_RCVR_DETECT_SEQ  ) ? "SEND_RCVR_DETECT_SEQ" :
               ( curnt_cmd == `SEND_TS1              ) ? "SEND_TS1" :
               ( curnt_cmd == `SEND_TS2              ) ? "SEND_TS2" :
               ( curnt_cmd == `COMPLIANCE_PATTERN    ) ? "COMPLIANCE_PATTERN" :
               ( curnt_cmd == `MOD_COMPL_PATTERN     ) ? "MOD_COMPL_PATTERN" :
               ( curnt_cmd == `SEND_BEACON           ) ? "SEND_BEACON" :
               ( curnt_cmd == `SEND_N_FTS            ) ? "SEND_N_FTS" :
               ( curnt_cmd == `NORM                  ) ? "NORM" :
               ( curnt_cmd == `SEND_SKP              ) ? "SEND_SKP" :
                                                         "Bogus";

`endif // SYNTHESIS



endmodule   // xmlh_pat_gen
