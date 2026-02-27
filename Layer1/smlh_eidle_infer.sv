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
// ---    $DateTime: 2019/10/11 02:17:59 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_eidle_infer.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module calculates the inference of electrical idle
// ----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module smlh_eidle_infer
#(
    // ----------------------------------------------------------------------------
    // --- Parameters
    // ----------------------------------------------------------------------------
    parameter INST    = 0,                                    // The uniquifying parameter
    parameter TP      = `TP,                                  // Clock to Q delay (simulator insurance)
    parameter NL      = `CX_NL                                // Number of lanes
)
(
    // -------------------------------- Inputs ------------------------------------
    input                   core_clk,                         // Core clock
    input                   core_rst_n,                       // Core system reset
    input   [NL-1:0]        smlh_lanes_active,                // Which lanes are actively (begin) configured
    input   [5:0]           smlh_ltssm_state,                 // Current state of Link Training and Status State Machine
    input   [NL-1:0]        smseq_inskip_rcv,                 // Per lane skip received
    input   [NL-1:0]        smseq_ts1_rcvd_pulse,             // Per lane TS1 received
    input   [NL-1:0]        smseq_ts2_rcvd_pulse,             // Per lane TS2 received
    input   [NL-1:0]        rpipe_rxdata_dv,                  // PIPE receive valid RX data signal
    input   [NL-1:0]        rpipe_rxelecidle,                 // PIPE receives physical Rx Elecidle signal detected by PHY
    input                   cfg_fast_link_mode,               // for simulation
    input                   cfg_gen1_ei_inference_mode,       // EI inference mode for Gen1 rate. default 0 - using rxelecidle==1; 1 - using rxvalid==0
    input   [24:0]          fast_time_4ms,                    // fast timer controlled from the top for verification purposes

    // -------------------------Outputs ------------------------------------
    output  reg             smlh_eidle_inferred               // Electrical Idle has been inferred on at least one lane
);

// -----------------------------------------------------------------------------
// Parameter definition (to avoid spyglass warning)
// -----------------------------------------------------------------------------
localparam    TIME_GEN1_1280UI       = `CX_TIME_GEN1_1280UI;
localparam    TIME_GEN1_2000UI       = `CX_TIME_GEN1_2000UI;
localparam    TIME_GEN1_4680UI       = `CX_TIME_GEN1_4680UI;
localparam    TIME_GEN1_16000UI      = `CX_TIME_GEN1_16000UI;
localparam    TIME_GEN2_1280UI       = `CX_TIME_GEN2_1280UI;
localparam    TIME_GEN2_2000UI       = `CX_TIME_GEN2_2000UI;
localparam    TIME_GEN2_4680UI       = `CX_TIME_GEN2_4680UI;
localparam    TIME_GEN2_16000UI      = `CX_TIME_GEN2_16000UI;
localparam    TIME_GEN3_1280UI       = `CX_TIME_GEN3_1280UI;
localparam    TIME_GEN3_2000UI       = `CX_TIME_GEN3_2000UI;
localparam    TIME_GEN3_4680UI       = `CX_TIME_GEN3_4680UI;
localparam    TIME_GEN3_16000UI      = `CX_TIME_GEN3_16000UI;
localparam    TIME_GEN4_1280UI       = `CX_TIME_GEN4_1280UI;
localparam    TIME_GEN4_2000UI       = `CX_TIME_GEN4_2000UI;
localparam    TIME_GEN4_4680UI       = `CX_TIME_GEN4_4680UI;
localparam    TIME_GEN4_16000UI      = `CX_TIME_GEN4_16000UI;
localparam    TIME_GEN5_1280UI       = `CX_TIME_GEN5_1280UI;
localparam    TIME_GEN5_2000UI       = `CX_TIME_GEN5_2000UI;
localparam    TIME_GEN5_4680UI       = `CX_TIME_GEN5_4680UI;
localparam    TIME_GEN5_16000UI      = `CX_TIME_GEN5_16000UI;
localparam    TIME_128US             = `CX_TIME_128US;
localparam    TIME_4MS               = `CX_TIME_4MS;

// ---------------------------------------------------------------------------------------
// Internal Signal Declaration
// ---------------------------------------------------------------------------------------
reg                     eidle_check_pulse;      // This pulse indicate that the timer has expired and all lanes should be checked for inferred electrical idle
wire    [NL-1:0]        smseq_ts_rcvd_pulse;    // Per lane TS received
reg     [5:0]           smlh_ltssm_state_d;
wire    [NL-1:0]        eidle_exit;             // Electrical Idle Exit
wire                    state_changed;          // indicates the LTSSM has changed state
reg     [21:0]          eidle_timer[0:NL-1];    // infer electrical idle timer per lane
wire    [NL-1:0]        eidle_rst;              // Restart eidle check
wire                    eidle_clr;              // clear inferred signal
reg                     eidle_timeout_1280ui;
reg                     eidle_timeout_2000ui;
reg                     eidle_timeout_128us;
reg                     eidle_timeout_16000ui;
reg                     eidle_timeout_4680ui;
reg     [NL-1:0]        lane_activity;          // per lane signal indicating which lanes activity was seen on
wire                    all_lanes_active;       // Indicates that activity has been detected on all lanes.
reg                     smlh_eidle_inferred_d;


wire [2:0]             current_data_rate;       // 0=running at gen1 speeds, 1=running at gen2 speeds
assign                 current_data_rate = `GEN1_RATE ;

assign  smseq_ts_rcvd_pulse = smseq_ts1_rcvd_pulse | smseq_ts2_rcvd_pulse;



assign  eidle_rst[NL-1:0] = {NL{state_changed}} | {NL{eidle_check_pulse}} | lane_activity;
assign  eidle_clr         = state_changed | eidle_check_pulse;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_ltssm_state_d      <= #TP 5'b0;
    else
        smlh_ltssm_state_d      <= #TP smlh_ltssm_state;

assign  state_changed = smlh_ltssm_state != smlh_ltssm_state_d;

wire        timer2;
DWC_pcie_tim_gen
 u_gen_timer2
(
     .clk               (core_clk)
    ,.rst_n             (core_rst_n)
    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)

    ,.cnt_up_en         (timer2)  // timer count-up
);

always @(posedge core_clk or negedge core_rst_n) begin : eidle_timer0_PROC
    integer i;

    if (!core_rst_n)
        for (i=0; i<NL; i=i+1)
            eidle_timer[i] <= #TP 0;
    else begin
        for (i=0; i<NL; i=i+1) begin
            if ( eidle_rst[i] )
                eidle_timer[i] <= #TP 0;
            else if ( !eidle_timeout_128us )
                eidle_timer[i] <= #TP eidle_timer[i] + 1'b1;
        end
    end
end // eidle_timer0_PROC

always @(posedge core_clk or negedge core_rst_n) begin : eidle_timeout_1280ui_PROC
    integer i;

    if (!core_rst_n)
        eidle_timeout_1280ui    <= #TP 1'b0;
    else begin
        for (i=0; i<NL; i=i+1) begin
            if (eidle_clr)
                eidle_timeout_1280ui    <= #TP 1'b0;
            else if ( 
                   (smlh_lanes_active[i] && (current_data_rate == `GEN1_RATE) && (eidle_timer[i] == TIME_GEN1_1280UI) )
            )
                eidle_timeout_1280ui    <= #TP 1'b1 ;
        end
    end
end // eidle_timeout_1280ui_PROC

always @(posedge core_clk or negedge core_rst_n) begin : eidle_timeout_2000ui_PROC
    integer i;

    if (!core_rst_n)
        eidle_timeout_2000ui    <= #TP 1'b0;
    else begin
        for (i=0; i<NL; i=i+1) begin
            if (eidle_clr)
                eidle_timeout_2000ui    <= #TP 1'b0;
            else if ( 
                   (smlh_lanes_active[i] && (current_data_rate == `GEN1_RATE) && (eidle_timer[i] == TIME_GEN1_2000UI) )
            )
                eidle_timeout_2000ui    <= #TP 1'b1;
        end
    end
end // eidle_timeout_2000ui_PROC

always @(posedge core_clk or negedge core_rst_n) begin : eidle_timeout_4680ui_PROC
    integer i;

    if (!core_rst_n)
        eidle_timeout_4680ui    <= #TP 1'b0;
    else begin
        for (i=0; i<NL; i=i+1) begin
            if (eidle_clr)
                eidle_timeout_4680ui    <= #TP 1'b0;
            else if ( 
                   (smlh_lanes_active[i] && (current_data_rate == `GEN1_RATE) && (eidle_timer[i] == TIME_GEN1_4680UI) )
            )
                eidle_timeout_4680ui    <= #TP 1'b1;
        end
    end
end // eidle_timeout_4680ui_PROC

always @(posedge core_clk or negedge core_rst_n) begin : eidle_timeout_128us_PROC
    integer i;
    if (!core_rst_n)
        eidle_timeout_128us     <= #TP 1'b0;
    else begin
        for (i=0; i<NL; i=i+1) begin
            if (eidle_clr)
                eidle_timeout_128us     <= #TP 1'b0;
            else if ( smlh_lanes_active[i] && (eidle_timer[i] == TIME_128US) )
                eidle_timeout_128us     <= #TP 1'b1;
        end
    end
end // eidle_timeout_128us_PROC


always @(posedge core_clk or negedge core_rst_n) begin : eidle_timeout_16000ui_PROC
    integer i;
    if (!core_rst_n)
        eidle_timeout_16000ui   <= #TP 1'b0;
    else begin
        for (i=0; i<NL; i=i+1) begin
            if (eidle_clr)
                eidle_timeout_16000ui   <= #TP 1'b0;
            else if ( 
                   (smlh_lanes_active[i] && (current_data_rate == `GEN1_RATE) && (eidle_timer[i] == TIME_GEN1_16000UI) )
            )
                eidle_timeout_16000ui   <= #TP 1'b1;
        end
    end
end // eidle_timeout_16000ui_PROC

always @(eidle_timeout_1280ui or eidle_timeout_128us
         or smlh_ltssm_state)
begin
    if (smlh_ltssm_state == `S_L0)
        eidle_check_pulse = eidle_timeout_128us;
    else if (smlh_ltssm_state == `S_RCVRY_RCVRCFG)
        eidle_check_pulse = eidle_timeout_1280ui;
    else if (smlh_ltssm_state == `S_LPBK_ACTIVE)
        eidle_check_pulse = eidle_timeout_128us;
    else
        eidle_check_pulse = 1'b0;
end

// Electrical Idle Exit Detection
// In Recovery.Speed when successful_speed_negotiation = 0b and in 
// Loopback.Active, Electrical Idle is inferred if there is an absence of an
// exit from Electrical Idle in a given interval
// * In 2.5 GT/s speed, Electrical Idle exit must be detected with every Symbol 
//   received.
// * In speeds other than 2.5 GT/s, Electrical Idle exit is guaranteed only on 
//   receipt of an EIEOS. 
assign eidle_exit = (cfg_gen1_ei_inference_mode ? rpipe_rxdata_dv : ~rpipe_rxelecidle);

// This signal latches activity on each lane that would keep eidle from being inferred
always @( * ) begin : lane_activity_PROC
    lane_activity     = 0;

    if (smlh_ltssm_state == `S_L0)                 // Look for Skips
        lane_activity = smseq_inskip_rcv;
    else if (smlh_ltssm_state == `S_RCVRY_RCVRCFG)
        lane_activity = smseq_ts_rcvd_pulse;
    else if (smlh_ltssm_state == `S_LPBK_ACTIVE)
        lane_activity = eidle_exit;
end // lane_activity_PROC

// combine activity from all lanes
assign  all_lanes_active = &(lane_activity | ~smlh_lanes_active);

always @(posedge core_clk or negedge core_rst_n) begin : smlh_eidle_inferred_PROC
    if (!core_rst_n)
        smlh_eidle_inferred     <= #TP 1'b0;
    else if (eidle_check_pulse && !state_changed)
        smlh_eidle_inferred     <= #TP !smlh_eidle_inferred_d;
    else
        smlh_eidle_inferred     <= #TP 1'b0;
end // smlh_eidle_inferred_PROC

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_eidle_inferred_d   <= #TP 1'b0;
    else if (state_changed)
        smlh_eidle_inferred_d   <= #TP 1'b0;
    else
        smlh_eidle_inferred_d   <= #TP smlh_eidle_inferred || smlh_eidle_inferred_d;


endmodule


