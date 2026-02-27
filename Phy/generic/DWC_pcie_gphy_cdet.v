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
// ---    $DateTime: 2020/01/17 06:46:25 $
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_cdet.v#10 $
// -------------------------------------------------------------------------
// --- Module Description:  Generic comma detect function.  Pulled out of the
// --- generic r_phy_deser module as some SerDes vendors do not support this.
// --- SDM may or may not assume this capability.
// ---
// --- This module assumes no bit clock is available and must brute force select
// --- alignment based on the symbol clock and 10 bit data paths.  May convert
// --- selectable datapaths in a future version.
// -----------------------------------------------------------------------------


module DWC_pcie_gphy_cdet #(
  parameter TP        = 0
) (
   input             recvdclk,                   // symbol clock
   input             rst_n,                      // reset
   input      [9:0]  rxdata_10b_nonaligned,      // non-aligned parallel receive data
   input             en_cdet,                    // enable comma detect
   input      [2:0]  req_rate,    
   input      [2:0]  curr_rate,   

   output reg        comma_lock,                 // comma alignment lock achieved
   output reg [9:0]  rxdata_10b                  // aligned parallel receive data

);


//==============================================================================
// Regs and wires
//==============================================================================
reg     [9:0]           rxdata_reg_a;
reg     [9:0]           cdetp_reg;                  // registers for position selection
reg     [9:0]           cdetn_reg;
reg     [1:0]           cdlock_state;               // state for comma lock state machine
reg     [9:0]           latched_algn;               // registered/held comma alignment for rxdata10 alignment

reg     [9:0]           rxdata_10b_r;
reg     [9:0]           rxdata_10b_rr;
reg     [9:0]           rxdata_10b_rrr;

reg                     comma_detect;               // indicates comma
wire    [19:0]          combined_reg;               // combined bus for detection
wire    [ 9:0]          cdetp;                      // compare bus for positive canon match
wire    [ 9:0]          cdetn;                      // compare bus for negative canon match
wire                    comma_detect_comb;
wire                    cd_algn_match;              // current and previous commas are aligned
wire    [ 9:0]          detected_algn;              // combined pos/neg alignment vector
reg                     en_cdet_reg;
reg                     en_cdet_rr;
// Non-register
reg     [ 9:0]          rxdata_aligned;

// STP detect
// this is for debug purpose only
wire  rx_stp_detect;
assign rx_stp_detect = (rxdata_aligned == `GPHY_STP_10B_NEG) | (rxdata_aligned == `GPHY_STP_10B_POS);


// COM detection on rxdata_aligned
wire   com_detection;
assign com_detection = (rxdata_aligned == `GPHY_COM_10B_NEG) | (rxdata_aligned == `GPHY_COM_10B_POS);

// EIOS detection
// EIOS is detected when 2 of the 3 7C symbols are seen
wire                  eios_detect;
assign eios_detect   = ( ((rxdata_10b_rrr == `GPHY_COM_10B_NEG) | (rxdata_10b_rrr == `GPHY_COM_10B_POS)) && 
                        (
                         (((rxdata_10b_rr == `GPHY_IDL_10B_NEG) | (rxdata_10b_rr  == `GPHY_IDL_10B_POS)) &&
                          ((rxdata_10b_r  == `GPHY_IDL_10B_NEG) | (rxdata_10b_r   == `GPHY_IDL_10B_POS)))
                         ||
                         (((rxdata_10b_rr == `GPHY_IDL_10B_NEG) | (rxdata_10b_rr  == `GPHY_IDL_10B_POS)) &&
                          ((rxdata_10b    == `GPHY_IDL_10B_NEG) | (rxdata_10b     == `GPHY_IDL_10B_POS)))
                         ||
                         (((rxdata_10b_rr == `GPHY_IDL_10B_NEG) | (rxdata_10b_rr  == `GPHY_IDL_10B_POS)) && 
                          ((rxdata_10b    == `GPHY_IDL_10B_NEG) | (rxdata_10b     == `GPHY_IDL_10B_POS))) 
                        ));

reg first_eios_seen;
reg first_eios_seen_d;
wire consecutive_eios_end;
always @(posedge recvdclk or negedge rst_n) begin
    if (!rst_n)         first_eios_seen <= #TP 1'b0; else
    if (eios_detect)    first_eios_seen <= #TP 1'b1; else
    if ((!eios_detect && com_detection) || 
        !(rxdata_aligned inside {`GPHY_COM_10B_NEG,`GPHY_COM_10B_POS, `GPHY_IDL_10B_NEG, `GPHY_IDL_10B_POS }))
                        first_eios_seen <= #TP 1'b0; else
                        first_eios_seen <= #TP first_eios_seen;
end    


always @(posedge recvdclk or negedge rst_n) begin
    if (!rst_n) first_eios_seen_d  <= #TP 1'b0; else
                first_eios_seen_d  <= #TP first_eios_seen;
end    

assign consecutive_eios_end = !first_eios_seen && first_eios_seen_d;

wire   enter_elecidle;
assign enter_elecidle = (eios_detect && !com_detection) || consecutive_eios_end;
                        
//==============================================================================
// Register the receive data for comparison... this is specific to the 1s
// implementation.
//==============================================================================

always @(posedge recvdclk or negedge rst_n) begin
    if (!rst_n)
    begin
        rxdata_reg_a <= #TP 0;
        en_cdet_reg  <= #TP 1;
        en_cdet_rr   <= #TP 1;
    end
    else
    begin
        rxdata_reg_a <= #TP rxdata_10b_nonaligned;
        en_cdet_reg  <= #TP en_cdet;
        en_cdet_rr   <= #TP en_cdet_reg;
    end
end // always

//==============================================================================
// merge into one 20 bit compare bus to check against comma pattern
//
// May want to register rxdata_20b_nonaligned before combining for timing for
// FPGA implementations, however did not need to do this for the PTC
// implementation.
//==============================================================================
assign combined_reg = {rxdata_10b_nonaligned, rxdata_reg_a};

//==============================================================================
// Simple compare across 20 bits for the right patterns and latch immediately
//==============================================================================
// Brute force compare across combined_reg bus
//
// May be able to simplify by using 5 bits of comma to compare and/or do in
// multiple steps for better timing at 250MHz.
//==============================================================================

assign cdetp[0]   = (combined_reg[9:0]    == `GPHY_COM_10B_POS);
assign cdetp[1]   = (combined_reg[10:1]   == `GPHY_COM_10B_POS);
assign cdetp[2]   = (combined_reg[11:2]   == `GPHY_COM_10B_POS);
assign cdetp[3]   = (combined_reg[12:3]   == `GPHY_COM_10B_POS);
assign cdetp[4]   = (combined_reg[13:4]   == `GPHY_COM_10B_POS);
assign cdetp[5]   = (combined_reg[14:5]   == `GPHY_COM_10B_POS);
assign cdetp[6]   = (combined_reg[15:6]   == `GPHY_COM_10B_POS);
assign cdetp[7]   = (combined_reg[16:7]   == `GPHY_COM_10B_POS);
assign cdetp[8]   = (combined_reg[17:8]   == `GPHY_COM_10B_POS);
assign cdetp[9]   = (combined_reg[18:9]   == `GPHY_COM_10B_POS);

assign cdetn[0]   = (combined_reg[9:0]    == `GPHY_COM_10B_NEG);
assign cdetn[1]   = (combined_reg[10:1]   == `GPHY_COM_10B_NEG);
assign cdetn[2]   = (combined_reg[11:2]   == `GPHY_COM_10B_NEG);
assign cdetn[3]   = (combined_reg[12:3]   == `GPHY_COM_10B_NEG);
assign cdetn[4]   = (combined_reg[13:4]   == `GPHY_COM_10B_NEG);
assign cdetn[5]   = (combined_reg[14:5]   == `GPHY_COM_10B_NEG);
assign cdetn[6]   = (combined_reg[15:6]   == `GPHY_COM_10B_NEG);
assign cdetn[7]   = (combined_reg[16:7]   == `GPHY_COM_10B_NEG);
assign cdetn[8]   = (combined_reg[17:8]   == `GPHY_COM_10B_NEG);
assign cdetn[9]   = (combined_reg[18:9]   == `GPHY_COM_10B_NEG);

assign comma_detect_comb = en_cdet_rr & ((|cdetp) | (|cdetn));             // detection indication (pos or neg)

//==============================================================================
// Register position indicators; init to first position & register comma
// detect.
//==============================================================================

always @(posedge recvdclk or negedge rst_n)
    if (!rst_n) begin
        cdetp_reg    <= #TP 10'h1;
        cdetn_reg    <= #TP 10'h1;
        comma_detect <= #TP 1'b0;
    end
    else begin
        cdetp_reg    <= #TP cdetp;
        cdetn_reg    <= #TP cdetn;
        comma_detect <= #TP comma_detect_comb;
    end

assign detected_algn = (cdetp_reg | cdetn_reg);                         // combine position indicators

//==============================================================================
// Comma Lock FSM:
//
//  -- IDLE on reset
//      -> CDLK1 after 1st cdet (latch position); clear lock
//      -> else IDLE; clear lock
//  -- CDLK1
//      -> CDLK1 if != latched; re-latch position; clear lock
//      -> CDLK2 after next cdet and == latched; clear lock
//      -> else CDLK1; clear lock
//  -- CDLK2
//      -> CDLOCK if next cdet == latched; set lock
//      -> CDLK1 if next cdet != latched; latch position; clear lock
//      -> else CDLK2; clear lock
//  -- CDLOCK
//      -> CDLK2 if next cdet != latched; set lock
//      -> else CDLOCK; set lock
//
// * takes three commas in same position to get to "lock" from reset, although
//      the first comma position is locked in immediately
// * once in lock, takes two bad commas to fall out of lock & two to recover
//
//==============================================================================

//==============================================================================
// FSM State Parameters
//==============================================================================
parameter S_IDLE   = 2'b00;
parameter S_CDLK1  = 2'b01;
parameter S_CDLK2  = 2'b10;
parameter S_CDLOCK = 2'b11;

assign cd_algn_match = (detected_algn == latched_algn);

always@(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
        comma_lock      <= #TP 1'b0;
        latched_algn    <= #TP 20'h1;
        cdlock_state    <= #TP S_IDLE;
    end else if (req_rate != curr_rate) begin
        comma_lock      <= #TP 1'b0;
        latched_algn    <= #TP 20'h1;
        cdlock_state    <= #TP S_IDLE;         
    end else if (!en_cdet_rr || enter_elecidle) begin
        comma_lock      <= #TP 1'b0;
        latched_algn    <= #TP 20'h1;
        cdlock_state    <= #TP S_IDLE;
    end else

    case (cdlock_state)

        S_IDLE:     begin
                        comma_lock      <= #TP 1'b0;
                        latched_algn    <= #TP (comma_detect && !eios_detect) ? detected_algn : latched_algn;
                        cdlock_state    <= #TP (comma_detect && !eios_detect) ? S_CDLK1 : S_IDLE;
                    end
        S_CDLK1:    begin
                        comma_lock      <= #TP 1'b0;
                        latched_algn    <= #TP ((comma_detect && !eios_detect) && !cd_algn_match) ? detected_algn : latched_algn;
                        cdlock_state    <= #TP ((comma_detect && !eios_detect) &&  cd_algn_match) ? S_CDLK2 : S_CDLK1;
                    end

        S_CDLK2:    begin
                        comma_lock      <= #TP ((comma_detect && !eios_detect) &&  cd_algn_match) ? 1'b1 : comma_lock;
                        latched_algn    <= #TP ((comma_detect && !eios_detect) && !cd_algn_match) ? detected_algn : latched_algn;
                        cdlock_state    <= #TP ((comma_detect && !eios_detect) &&  cd_algn_match) ? S_CDLOCK :
                                               ((comma_detect && !eios_detect) && !cd_algn_match) ? S_CDLK1 : S_CDLK2;
                    end

        S_CDLOCK:   begin
                        comma_lock      <= #TP 1'b1;
                        latched_algn    <= #TP latched_algn;
                        cdlock_state    <= #TP ((comma_detect && !eios_detect) && !cd_algn_match) ? S_CDLK2 : S_CDLOCK;
                    end
        default:    begin
                        comma_lock      <= #TP comma_lock;
                        latched_algn    <= #TP latched_algn;
                        cdlock_state    <= #TP S_IDLE;
                    end
    endcase
end

//==============================================================================
// Big mux for RX data alignment
//
// May simplify loading by pipelining the shift decision rather than one large
// mux.  May have trouble meeting timing w/ all these loads at 250MHz.  Trade-
// off will be latency.
//==============================================================================

// timing fix
reg     [29:0]          combined_reg_r;
reg     [9:0]           algn_select;

always @(posedge recvdclk or negedge rst_n)
    if (!rst_n) begin
        combined_reg_r  <= #TP 0;
        algn_select     <= #TP 10'b1;
    end
    else begin
        combined_reg_r  <= #TP combined_reg;
        algn_select     <= #TP latched_algn;
    end

always @(algn_select or combined_reg_r)
    case(algn_select)
        10'h001:    rxdata_aligned = combined_reg_r[9:0];
        10'h002:    rxdata_aligned = combined_reg_r[10:1];
        10'h004:    rxdata_aligned = combined_reg_r[11:2];
        10'h008:    rxdata_aligned = combined_reg_r[12:3];
        10'h010:    rxdata_aligned = combined_reg_r[13:4];
        10'h020:    rxdata_aligned = combined_reg_r[14:5];
        10'h040:    rxdata_aligned = combined_reg_r[15:6];
        10'h080:    rxdata_aligned = combined_reg_r[16:7];
        10'h100:    rxdata_aligned = combined_reg_r[17:8];
        10'h200:    rxdata_aligned = combined_reg_r[18:9];
        default:    rxdata_aligned = 10'h000;
    endcase

//==============================================================================
// Register aligned RX data
//==============================================================================

always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
        rxdata_10b     <= #TP 10'b0;
        rxdata_10b_r   <= #TP 10'b0;
        rxdata_10b_rr  <= #TP 10'b0;
        rxdata_10b_rrr <= #TP 10'b0;
    end else begin
        rxdata_10b     <= #TP rxdata_aligned;
        rxdata_10b_r   <= #TP rxdata_10b;
        rxdata_10b_rr  <= #TP rxdata_10b_r;
        rxdata_10b_rrr <= #TP rxdata_10b_rr;
    end
end

endmodule


