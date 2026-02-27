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
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_control_64b.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer Handler Controller
// -----------------------------------------------------------------------------
// --- This module handles DLP layer dllp and tlp mux/control logic. And it includes the following functions:
// --- 1. Arbitrates for transmitting DLLP and TLP.
// --- 2. Mux the tlp and dllp data and output to xmlh
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xdlh_control_64b (
    // Inputs
    core_clk,
    core_rst_n,
    rdlh_link_up,
    current_data_rate,
    phy_type,
    smlh_link_mode,
    dllp_xmt_req,
    dllp_req_low_prior,

    dllp_xmt_pkt_10b, 
    tlp_sot,
    tlp_eot,
    tlp_data,
    tlp_dwen,
    last_pmdllp_ack,

    xmlh_xdlh_halt,
// Outputs
    xdlh_xmlh_stp,
    xdlh_xmlh_sdp,
    xdlh_xmlh_eot,
    next_xdlh_xmlh_eot,
    next_xdlh_xmlh_stp,
    next_xdlh_xmlh_sdp,   
    xdlh_xmlh_data,
    xdlh_xmlh_pad,
    xdctrl_tlp_halt,
    xdctrl_dllp_halt,
    xdlh_xmt_pme_ack,
    xdctrl_nodllp_pending,
    xdlh_last_pmdllp_ack,
    xdlh_match_pmdllp,
    xdlh_dllp_sent
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance.
parameter   NW      = 2;        // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW      = (32*NW);  // Width of datapath in bits.
parameter   NB      = `CX_NB;   // Number of 32-bit dwords handled by the datapath each clock.
parameter   TX_NDLLP= 1;        // number of DLLPs send possible per cycle

parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)

// ==========================================================================
// Parameters
// ==========================================================================

parameter S_IDLE            = 3'b0;
parameter S_DLLP_LSB        = 3'b001;
parameter S_DLLP_MSB        = 3'b010;
parameter S_TLP             = 3'b100;
parameter S_TLP_END         = 3'b101;

// ==========================================================================
// inputs
// ==========================================================================
input                           core_clk;
input                           core_rst_n;
input   [2:0]                   current_data_rate;    
input                           phy_type;
input   [DW-1:0]                tlp_data;
input   [NW-1:0]                tlp_dwen;
input                           tlp_sot;
input                           tlp_eot;
input                           rdlh_link_up;
input   [5:0]                   smlh_link_mode;
input   [TX_NDLLP-1:0]          dllp_xmt_req;

input [(64*TX_NDLLP)-1:0] dllp_xmt_pkt_10b;
input                           dllp_req_low_prior;
input                           xmlh_xdlh_halt;
input                           last_pmdllp_ack;

// ==========================================================================
// outputs
// ==========================================================================
output  [DW-1:0]               xdlh_xmlh_data;
output  [NW-1:0]               xdlh_xmlh_pad;
output  [NW-1:0]               xdlh_xmlh_sdp;                      // Start DLP packet
output  [NW-1:0]               xdlh_xmlh_stp;                      // Start TLP packet
output  [NW-1:0]               xdlh_xmlh_eot;                      // End DLP or TLP packet
output  [NW-1:0]               next_xdlh_xmlh_eot;                 // End DLP or TLP packet
output  [NW-1:0]               next_xdlh_xmlh_stp;                 // Strat  TLP on next packet
output  [NW-1:0]               next_xdlh_xmlh_sdp;                 // Start DLLP on next packet

output                         xdctrl_dllp_halt;
output                         xdlh_xmt_pme_ack;
output                         xdctrl_tlp_halt;
output                         xdctrl_nodllp_pending;
output                         xdlh_last_pmdllp_ack;
output  [3:0]                  xdlh_match_pmdllp;
output  [NW-1:0]               xdlh_dllp_sent;

// ==========================================================================
// IO declaration
// ==========================================================================
reg    [(TX_NDLLP*64) -1:0]   clkd_dllp_pkt;
reg     [DW-1:0]              xdlh_xmlh_data;
reg     [NW-1:0]              xdlh_xmlh_pad;
reg     [NW-1:0]              xdlh_xmlh_sdp;                      // Start DLP packet
reg     [NW-1:0]              xdlh_xmlh_stp;                      // Start TLP packet
reg     [NW-1:0]              xdlh_xmlh_eot;                      // End DLP or TLP packet
wire    [7:0]                 int_l23_dllp_type;
wire    [7:0]                 int_l1aspm_dllp_type;
wire    [7:0]                 int_l1pm_dllp_type;
wire    [7:0]                 int_pmack_dllp_type;
wire                          xdctrl_dllp_halt;
wire                          xdctrl_tlp_halt;
reg                           xdlh_xmt_pme_ack;
reg                           xdctrl_nodllp_pending;
reg                           xdlh_last_pmdllp_ack;
reg     [3:0]                 xdlh_match_pmdllp;
wire    [NW-1:0]              xdlh_dllp_sent;
wire    [3:0]                 int_match_pmdllp;

// ==========================================================================
// internal signal declaration
// ==========================================================================
wire    [DW-1:0]        int_xmlh_data;
//wire    [NW-1:0]        int_xmlh_dwen;
wire    [NW-1:0]        int_xmlh_pad;
wire    [NW-1:0]        int_xmlh_sdp;                      // Start DLP packet
wire    [NW-1:0]        int_xmlh_stp;                      // Start TLP packet
wire    [NW-1:0]        int_xmlh_eot;                      // End DLP or TLP packet
wire    [NW-1:0]        next_xdlh_xmlh_eot;                // End DLP or TLP packet
wire    [NW-1:0]        next_xdlh_xmlh_stp;                // Start  TLP next packet
wire    [NW-1:0]        next_xdlh_xmlh_sdp;                // Start DLP next packet

reg     [DW-1:0]        latchd_xmlh_data;
reg     [NW-1:0]        latchd_xmlh_dwen;
reg     [NW-1:0]        latchd_xmlh_sdp;                      // Start DLP packet
reg     [NW-1:0]        latchd_xmlh_stp;                      // Start TLP packet
reg     [NW-1:0]        latchd_xmlh_eot;                      // End DLP or TLP packet
reg     [63:0]          clkd_tlpdata_2msb_dw;

reg     [NW-1:0]        clkd_tlp_dwen;
wire                    or_xdlh_sdp;
wire                    or_xdlh_stp;
wire                    or_xdlh_eot;
reg                     latchd_tlp_packd;
wire   [DW-1:0]         int_tlp_data;
reg                     tlp_in_progress;
reg                     xdlh_xmlh_dv;
wire                    int_xmlh_dv;
wire    [NW-1:0]        int_xmlh_pad_x16;
wire                    high_prior_dllp_req;
wire                    low_prior_dllp_req;
wire                    insert_dllp_en;
wire                    valid_tlp_sot;
wire                    tlp_is_pme_to_ack;
wire [(64*TX_NDLLP)-1:0]    dllp_xmt_pkt ;  
wire                    int_any_pmdllp_match;
reg                     int_last_pmdllp_ack;
wire                    int_clear_pmdllp_ack;
wire                    int_set_pmdllp_ack;

//-----------------------------------------------------------------------------------
//

assign  dllp_xmt_pkt = dllp_xmt_pkt_10b;


assign      high_prior_dllp_req  = dllp_xmt_req[0] && !dllp_req_low_prior;
assign      low_prior_dllp_req   = dllp_xmt_req[0] && dllp_req_low_prior;
assign      valid_tlp_sot        = tlp_sot && rdlh_link_up;

assign      or_xdlh_stp  = |xdlh_xmlh_stp;
assign      or_xdlh_sdp  = |xdlh_xmlh_sdp;
assign      or_xdlh_eot  = |xdlh_xmlh_eot;
assign      int_tlp_data = { ({32{tlp_dwen[1]}} & tlp_data[63:32]),
                             ({32{tlp_dwen[0]}} & tlp_data[31:0])};

// output drive mux
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        xdlh_xmlh_stp       <= #TP 0;
        xdlh_xmlh_sdp       <= #TP 0;
        xdlh_xmlh_data      <= #TP 0;
        xdlh_xmlh_pad       <= #TP 0;
        xdlh_xmlh_eot       <= #TP 0;
        xdlh_xmlh_dv       <= #TP 0;
    end else if (!xdlh_xmlh_dv | !xmlh_xdlh_halt) begin
        xdlh_xmlh_data      <= #TP int_xmlh_data;
        xdlh_xmlh_pad       <= #TP int_xmlh_pad;
        xdlh_xmlh_eot       <= #TP int_xmlh_eot;
        xdlh_xmlh_stp       <= #TP int_xmlh_stp;
        xdlh_xmlh_sdp       <= #TP int_xmlh_sdp;
        xdlh_xmlh_dv        <= #TP int_xmlh_dv;
    end

assign next_xdlh_xmlh_eot = (!xdlh_xmlh_dv | !xmlh_xdlh_halt) ? int_xmlh_eot : xdlh_xmlh_eot;
assign next_xdlh_xmlh_stp = (!xdlh_xmlh_dv | !xmlh_xdlh_halt) ? int_xmlh_stp : xdlh_xmlh_stp;
assign next_xdlh_xmlh_sdp = (!xdlh_xmlh_dv | !xmlh_xdlh_halt) ? int_xmlh_sdp : xdlh_xmlh_sdp;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) 
        tlp_in_progress      <= #TP 0;
    else
        tlp_in_progress      <= #TP (tlp_eot && !xdctrl_tlp_halt) ? 1'b0 
                                    : (valid_tlp_sot && !high_prior_dllp_req && (!xdlh_xmlh_dv | !xmlh_xdlh_halt)) ? 1'b1 
                                    :tlp_in_progress;

// When we have a dllp request being asserted to xmlh interface, then we
// will halt the next dllp if the current dllp has been halted.
// Or when there is a tlp in progress, then we need to halt dllp.
assign   xdctrl_dllp_halt   = (xmlh_xdlh_halt & xdlh_xmlh_dv) || tlp_in_progress || (valid_tlp_sot && !high_prior_dllp_req) ;
                              
assign   xdctrl_tlp_halt    = (xmlh_xdlh_halt & xdlh_xmlh_dv) || (valid_tlp_sot && high_prior_dllp_req) || (tlp_sot & !rdlh_link_up) ;

assign   insert_dllp_en     = (high_prior_dllp_req || (low_prior_dllp_req && !valid_tlp_sot)) && !tlp_in_progress;

assign   int_xmlh_data      = (insert_dllp_en) ? dllp_xmt_pkt[63:0] : int_tlp_data;

assign  int_xmlh_pad        =  (smlh_link_mode[3] & int_xmlh_eot[0]) ? 2'b10 : 2'b00;

wire [NW-1:0] tmp_eot;
assign tmp_eot       =   (tlp_dwen == 2'b01)     ? 2'b01 :
                                (tlp_dwen == 2'b11)     ? 2'b10 :
                                                          2'b00 ;

assign   int_xmlh_eot       =   (insert_dllp_en) ? 2'b10 
                                 : tlp_eot ? tmp_eot : 2'b00;

assign   int_xmlh_dv        = valid_tlp_sot || high_prior_dllp_req || low_prior_dllp_req || tlp_in_progress;

assign   int_xmlh_stp       = (valid_tlp_sot && !high_prior_dllp_req ) ?   2'b01 : 2'b00;

assign   int_xmlh_sdp       = (insert_dllp_en) ? 2'b01 : 2'b00;


// assign   tlp_is_pme_to_ack  = (current_data_rate == `GEN3_RATE) ? ((xdlh_xmlh_data[38:35] == `MSG_4) && (int_xmlh_data[31:24] == `PME_TO_ACK))
//                                                                : ((xdlh_xmlh_data[30:27] == `MSG_4) && (int_xmlh_data[23:16] == `PME_TO_ACK));


// Check also the TLP is not prefix
assign   tlp_is_pme_to_ack  = (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) & (phy_type != `PHY_TYPE_MPCIE) ? ((xdlh_xmlh_data[39:35] == {1'b0, `MSG_4}) && (int_xmlh_data[31:24] == `PME_TO_ACK))
                                                                                                                                   : ((xdlh_xmlh_data[31:27] == {1'b0, `MSG_4}) && (int_xmlh_data[23:16] == `PME_TO_ACK)) ;
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        xdlh_xmt_pme_ack      <= #TP 1'b0;
        xdlh_last_pmdllp_ack  <= #TP 1'b0;
    end
    else begin
        xdlh_xmt_pme_ack      <= #TP xdlh_xmlh_stp[0] && tlp_is_pme_to_ack && !xmlh_xdlh_halt;
        xdlh_last_pmdllp_ack  <= #TP int_clear_pmdllp_ack;
    end
end

// for pm module output
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        xdctrl_nodllp_pending        <= #TP 1;
    else
        xdctrl_nodllp_pending        <= #TP !int_xmlh_dv & !xdlh_xmlh_dv;



xdlh_detect_dllp

  // Parameters
  #(
    .INST       (INST),
    .NW         (NW),
    .DW         (DW),
    .DLLP_WD    (8),
    .MATCH_TYPE (1'b0)
  ) u_det_any_dllp (
    // Inputs
    .clk                  (core_clk),
    .rst_n                (core_rst_n),
    .dllp_type            (8'hFF),
    .sdp                  (xdlh_xmlh_sdp),
    .data                 (xdlh_xmlh_data),
    .eot                  (xdlh_xmlh_eot),
    .current_data_rate    (current_data_rate),
    .phy_type             (phy_type),
    .halt                 (xmlh_xdlh_halt),
    // Outputs
    .dllp_match           (),
    .dllp_sent            (xdlh_dllp_sent)
);

assign int_l23_dllp_type = `PM_ENTER_L23;
assign int_l1pm_dllp_type = `PM_ENTER_L1;
assign int_l1aspm_dllp_type = `PM_AS_REQ_L1;
assign int_pmack_dllp_type = `PM_REQ_ACK;

xdlh_detect_dllp

  // Parameters
  #(
    .INST     (INST),
    .NW       (NW),
    .DW       (DW),
    .DLLP_WD  (8)
  ) u_det_pm_dllp[3:0] (
    // Inputs
    .clk                  (core_clk),
    .rst_n                (core_rst_n),
    .dllp_type            ({int_l23_dllp_type, int_l1pm_dllp_type, int_l1aspm_dllp_type, int_pmack_dllp_type}),
    .sdp                  (xdlh_xmlh_sdp),
    .data                 (xdlh_xmlh_data),
    .eot                  (xdlh_xmlh_eot),
    .current_data_rate    (current_data_rate),
    .phy_type             (phy_type),
    .halt                 (xmlh_xdlh_halt),
    // Outputs
    .dllp_match           (int_match_pmdllp),
    .dllp_sent            ()
);

assign int_any_pmdllp_match = |int_match_pmdllp;

assign int_clear_pmdllp_ack = int_last_pmdllp_ack && int_any_pmdllp_match && !xmlh_xdlh_halt;
assign int_set_pmdllp_ack = (!xdlh_xmlh_dv | !xmlh_xdlh_halt) && last_pmdllp_ack;

always @(posedge core_clk or negedge core_rst_n)
begin
  if (!core_rst_n)
  begin
    int_last_pmdllp_ack <= #TP 1'b0;
    xdlh_match_pmdllp   <= #TP 4'h0;
  end
  else
  begin
    xdlh_match_pmdllp <= #TP int_match_pmdllp;
    if (int_clear_pmdllp_ack)
      int_last_pmdllp_ack <= #TP 1'b0;
    else if (int_set_pmdllp_ack)
      int_last_pmdllp_ack <= #TP 1'b1;
    else
      int_last_pmdllp_ack <= #TP int_last_pmdllp_ack;
  end
end


endmodule

