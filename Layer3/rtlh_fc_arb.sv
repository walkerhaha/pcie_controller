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
// ---    $DateTime: 2020/06/26 01:14:06 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_fc_arb.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module performs arbitration of flow control requests among the
// --- FC init and update for all virtual channels.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rtlh_fc_arb (
    core_clk,
    core_rst_n,
    rdlh_rtlh_link_state,
    cfg_vc_enable,
    cfg_vc_struc_vc_id_map,
    cfg_fc_wdog_disable,
    cfg_ext_synch,

    cfg_fc_credit_ph,
    cfg_fc_credit_nph,
    cfg_fc_credit_cplh,
    cfg_fc_credit_pd,
    cfg_fc_credit_npd,
    cfg_fc_credit_cpld,
    pm_freeze_fc_timer,
    xdlh_rtlh_fc_ack,
    rtfcgen_reqs,
    rtfcgen_reqs_hi,
    rtfcgen_data,
    rx_fc1_p,
    rx_fc1_np,
    rx_fc1_cpl,
    rx_fc2_p,
    rx_fc2_np,
    rx_fc2_cpl,
    rx_updt_p,
    rx_updt_np,
    rx_updt_cpl,
    rx_tlp,
    rx_vc,
    xadm_all_type_infinite,
    rdlh_rtlh_rcvd_dllp,

    current_data_rate,
    phy_type,
    smlh_in_l0_l0s,
    // Outputs
    rtfcarb_acks,
    rtlh_fc_init_status,
    rtlh_fc_init1_status,
    rtlh_req_link_retrain,
    fc_update_timer_expired,
    rtlh_xdlh_fc_req,
    rtlh_xdlh_fc_req_hi,
    rtlh_xdlh_fc_req_low,
    rtlh_xdlh_fc_data
);

parameter   INST                      = 0;                               // The uniquifying parameter for each port logic instance.
parameter   NVC                       = `CX_NVC;                         // Number of virtual channels
parameter   TP                        = `TP;                             // Clock to Q delay (simulator insurance)
parameter   NW                        = `CX_NW;                          // Number of 32-bit dwords handled by the datapath each clock.
parameter   FREQ_MULTIPLIER           = `CX_FREQ_MULTIPLIER;             // Frequency of operation
parameter   NB                        = `CX_NB;                          // Number of 32-bit dwords handled by the datapath each clock.
parameter   NL                        = `CX_NL;                          // Number of lanes active
// parameter   TX_NDLLP                  = ((NB >= 2) & (NW>=4)) ? 2 : 1;   // Max number of DLLPs send per cycle
parameter   TX_NDLLP                  = 1;

parameter   RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1; // Max number of DLLPs received per cycle

parameter SCALED_WDOG_TIMER_EXP_VALUE = `CX_SCALED_WDOG_TIMER_EXP_VALUE; // scaled watch dog timer expiration value
parameter SCALED_WDOG_TIMER_PTR_WD    = `CX_SCALED_WDOG_TIMER_PTR_WD;    // scaled watch dog timer pointer width defined in cxpl_defs.vh


parameter S_IDLE                = 3'h0;
parameter S_FC1_P               = 3'h1;
parameter S_FC1_NP              = 3'h2;
parameter S_FC1_CPL             = 3'h3;
parameter S_FC2_P               = 3'h4;
parameter S_FC2_NP              = 3'h5;
parameter S_FC2_CPL             = 3'h6;

localparam RX_TLP   = `CX_RX_TLP; // Number of TLPs that can be processed in a single cycle

// -------------------------------- Inputs -------------------------------------
input                       core_clk;               // Core clock
input                       core_rst_n;             // Core system reset
input                       pm_freeze_fc_timer;     // power module request to freeze the central FC 8us timer which is sharec between arbiter and gen block
input                       xdlh_rtlh_fc_ack;       // When asserted, it indicates it is DLLP1 packet
                                                    // (when used in x8/x16 configurations, each 128-bit words could carry two DLLP packets)
input   [NVC-1:0]           rtfcgen_reqs;           // Requests from each VC
input   [NVC-1:0]           rtfcgen_reqs_hi;        // Requests for high-priority from each VC
input   [32*NVC-1:0]        rtfcgen_data;           // Data corresponding to requests
input   [1:0]               rdlh_rtlh_link_state;
input   [NVC-1:0]           cfg_vc_enable;          // Which VCs are enabled (VC0 is always enabled)
input   [NVC*3-1:0]         cfg_vc_struc_vc_id_map; // Map physical VC resource to VC identifier
input                       cfg_fc_wdog_disable;    // disable watch dog timer in FC for some debug purpose
input                       cfg_ext_synch;          // Indicates LTSSM is in extended sync enable

input   [(NVC*8)-1:0]       cfg_fc_credit_ph;       // Posted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]       cfg_fc_credit_nph;      // Nonposted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]       cfg_fc_credit_cplh;     // Completion header Wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]      cfg_fc_credit_pd;       // Posted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]      cfg_fc_credit_npd;      // Nonposted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]      cfg_fc_credit_cpld;     // Completion data wire to control the FC initial value for FC credit advertisement
input   [NVC-1:0]           rx_fc1_p;               // Received an FC_INIT1 packet (posted type)
input   [NVC-1:0]           rx_fc1_np;              // Received an FC_INIT1 packet (non-posted type)
input   [NVC-1:0]           rx_fc1_cpl;             // Received an FC_INIT1 packet (completion type)
input   [NVC-1:0]           rx_fc2_p;               // Received an FC_INIT2 packet (posted type)
input   [NVC-1:0]           rx_fc2_np;              // Received an FC_INIT2 packet (non-posted type)
input   [NVC-1:0]           rx_fc2_cpl;             // Received an FC_INIT2 packet (completion type)
input   [NVC-1:0]           rx_updt_p;              // Received an FC_update packet (posted type)
input   [NVC-1:0]           rx_updt_np;             // Received an FC_update packet (non-posted type)
input   [NVC-1:0]           rx_updt_cpl;            // Received an FC_update packet (completion type)
input   [RX_TLP-1:0]        rx_tlp;                 // Received a TLP
input   [3*RX_TLP-1:0]      rx_vc;                  // Structure VC of the  current Received a TLP
input                       xadm_all_type_infinite; // This is used for watch dog timer. XADM FC book keeping block indicates that remote link advertised all FC credits to infinite.
input   [RX_NDLLP-1:0]      rdlh_rtlh_rcvd_dllp;    // This is used for watch dog timer. this signal indicates that we have received a DLLP
input   [2:0]               current_data_rate;      // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4

input                       phy_type;               // Mac type
input                       smlh_in_l0_l0s;         // LTSSM is in L0 or L0s state


// -------------------------------- Outputs ------------------------------------
output  [NVC-1:0]           rtfcarb_acks;           // Requests from each VC
output  [TX_NDLLP-1:0]      rtlh_xdlh_fc_req;
output                      rtlh_xdlh_fc_req_hi;
output                      rtlh_xdlh_fc_req_low;
output  [(32*TX_NDLLP)-1:0] rtlh_xdlh_fc_data;
output  [NVC-1:0]           rtlh_fc_init_status;
output  [NVC-1:0]           rtlh_fc_init1_status;
output                      fc_update_timer_expired;// A signal from fc_gen block to share the timer of 30
output                      rtlh_req_link_retrain;  // A signal to request LTSSM to start a link training due to watch dog timeout

// Output registers
wire    [TX_NDLLP-1:0]      rtlh_xdlh_fc_req;
wire                        rtlh_xdlh_fc_req_hi;
wire                        rtlh_xdlh_fc_req_low;
wire    [(32*TX_NDLLP)-1:0] rtlh_xdlh_fc_data;
reg     [NVC-1:0]           rtfcarb_acks;           // Requests from each VC
reg     [NVC-1:0]           rtlh_fc_init_status;
reg     [NVC-1:0]           rtlh_fc_init1_status;
wire                        fc_update_timer_expired;// A signal from fc_gen block to share the timer of 30
reg                         rtlh_req_link_retrain;

// ------------------- Internal signals --------------------------------
reg     [TX_NDLLP-1:0]      int_fc_req;
reg                         int_fc_req_hi;
reg                         int_fc_req_low;
reg     [(32*TX_NDLLP)-1:0] int_fc_data;

wire    [2:0]               selected_next;
reg     [2:0]               fc_state;

reg     [NVC-1:0]           fc_init1_rcvd_pflags;
reg     [NVC-1:0]           fc_init1_rcvd_npflags;
reg     [NVC-1:0]           fc_init1_rcvd_cplflags;
reg     [NVC-1:0]           fc_init1_sent_flags;
reg     [NVC-1:0]           fc_init2_sent_flags;
wire    [NVC-1:0]           fc_init1_rcvd_flags;
reg     [NVC-1:0]           fc_init2_rcvd_flags;
wire                        fc2_rollover;           // VC0 is default always roll over
wire                        fc1_rollover;           // VC0 is default always roll over
reg     [2:0]               struc_vc_in_init;
wire    [2:0]               vc_in_init;
reg     [63:0]              fc_init_req_data;
reg     [1:0]               fc_init_req;
reg                         fc_init_req_hi;
reg                         fc_init_req_low;
wire                        fc_init_req_ackd;
//wire    [TX_NDLLP-1:0]      fc_upd_req;
wire    [1:0]               fc_upd_req;
wire                        this_is_vc0;
wire                        more_vc_uninited_1;
wire                        more_vc_uninited_2;
reg                         previous_is_fc1;
reg     [1:0]               timer_32us_fc1;
reg     [1:0]               timer_32us_fc2;
reg                         init2_triplet_sent;
reg                         init1_triplet_sent;
reg                         in_init1_state;
reg                         in_init2_state;
wire                        all_fc_init1_done;
wire                        all_fc_init2_done;
reg     [NVC-1:0]           latched_cfg_vc_enable;
wire    [NVC-1:0]           vc_disable;
wire                        tmp_link_down;
wire    [NVC-1:0]           uninit_vc_1;
wire    [NVC-1:0]           uninit_vc_2;
wire                        timer8us_timeout;       // A signal from fc_gen block to share the timer of 8us
wire                        latch_next_req_en;
wire                        expired_8us_time;
wire                        expired_8us_time_int;
wire                        expired_8us_time_mpcie;
// --------------------- Internal Design ------------------------------
//
// VC enable can only be changed during IDLE state and there is no more VC
// to go for INIT to ensure internal state
// non deadlock
always @(posedge core_clk or negedge core_rst_n)
begin : LATCH_VC_ENABLE
    if(!core_rst_n) begin
        latched_cfg_vc_enable             <= #TP 0;
    end else if (fc_state == S_IDLE) begin
        latched_cfg_vc_enable             <= #TP cfg_vc_enable;
    end
end

assign vc_disable       = ~latched_cfg_vc_enable;

assign tmp_link_down    = (rdlh_rtlh_link_state == `S_DL_INACTIVE) 
;

//
// Determine what is the next uninitialized VC for INIT1 and INIT2
//
assign uninit_vc_1          = ~rtlh_fc_init1_status & latched_cfg_vc_enable;
assign uninit_vc_2          = ~rtlh_fc_init_status & latched_cfg_vc_enable & rtlh_fc_init1_status;

assign more_vc_uninited_1   = |(uninit_vc_1);
assign more_vc_uninited_2   = |(uninit_vc_2);

// When there are more than one VC to be init, the critia to select VC are:
// 1. If there is a VC that has been gone through INIT1 states, and it received the ALL INIT1 from remote, then we will go to INIT2 state
// 2. If there is no VC that has gone through the INIT1 states, then we will go to INIT1 state

always @(posedge core_clk or negedge core_rst_n)
begin : SELECT_VC_TOBE_INIT
    if(!core_rst_n) begin
        struc_vc_in_init    <= #TP 0;
    end else if (tmp_link_down | (!rtlh_fc_init_status[0])) begin
        struc_vc_in_init    <= #TP 0;
    end else begin
        if ((fc_state == S_IDLE) && more_vc_uninited_2 && (previous_is_fc1 || (!more_vc_uninited_1)))   // there is a VC that is ready for INIT2, and priority coding will be ok since we are going into FC2 init
            struc_vc_in_init    <= #TP priority_encode(uninit_vc_2);                                    // init2 flag changes at the 1st of the triplet,
        else if (init2_triplet_sent )
            struc_vc_in_init    <= #TP priority_encode(uninit_vc_2 & ~fc_init2_sent_flags);  // init2 flag changes at the 1st of the triplet,
                                                                                             // This VID is updated on the last state of the triplet
                                                                                             // Therefore they are in different cycles
        else if ((fc_state == S_IDLE) & more_vc_uninited_1)     // there is a VC that is ready for INIT1
            struc_vc_in_init    <= #TP priority_encode(uninit_vc_1);
        else if (init1_triplet_sent )
            struc_vc_in_init    <= #TP priority_encode(uninit_vc_1 & ~fc_init1_sent_flags);
    end
end


always @(posedge core_clk or negedge core_rst_n)
begin : STORE_PREVIOUS_INIT1
    if(!core_rst_n)
        previous_is_fc1 <= #TP 1'b0;
    else if (init1_triplet_sent && all_fc_init1_done)
        previous_is_fc1 <= #TP 1'b1;
    else if (init2_triplet_sent && all_fc_init2_done)
        previous_is_fc1 <= #TP 1'b0;
end

assign this_is_vc0  = (struc_vc_in_init == 3'b0);

always @(posedge core_clk or negedge core_rst_n)
begin : RECEIVE_INIT1_FLAG
integer i;
    if(!core_rst_n) begin
        fc_init1_rcvd_pflags    <= #TP 0;
        fc_init1_rcvd_npflags   <= #TP 0;
        fc_init1_rcvd_cplflags  <= #TP 0;
    end else if (tmp_link_down) begin
        fc_init1_rcvd_pflags    <= #TP 0;
        fc_init1_rcvd_npflags   <= #TP 0;
        fc_init1_rcvd_cplflags  <= #TP 0;
    end else begin
        for (i = 0; i < NVC; i = i+1) begin
           if (vc_disable[i]) begin // disabled VC
               fc_init1_rcvd_pflags[i]   <= #TP 1'b0;
               fc_init1_rcvd_npflags[i]  <= #TP 1'b0;
               fc_init1_rcvd_cplflags[i] <= #TP 1'b0;
           end else begin
               fc_init1_rcvd_pflags[i]   <= #TP fc_init1_rcvd_pflags[i]   | rx_fc1_p[i]   | rx_fc2_p[i];
               fc_init1_rcvd_npflags[i]  <= #TP fc_init1_rcvd_npflags[i]  | rx_fc1_np[i]  | rx_fc2_np[i];
               fc_init1_rcvd_cplflags[i] <= #TP fc_init1_rcvd_cplflags[i] | rx_fc1_cpl[i] | rx_fc2_cpl[i];
           end
        end
    end
end


// In a 256/512 bit core more than one TLP may be received per cycle.
// Iterate through each TLP in rx_tlp|rx_vc and decode which VC it maps to.
reg  [NVC-1:0]  rx_tlp_vc;
reg  [7:0]      tmp_rx_tlp_vc;
always @(*) begin : map_rx_tlp_to_vc
    integer i;
    rx_tlp_vc = 0;
    tmp_rx_tlp_vc = 0;
    for(i = 0; i < RX_TLP; i = i + 1) begin
        if(rx_tlp[i]) begin
            tmp_rx_tlp_vc = map_to_8_bits(rx_vc[3*i +: 3]);
            rx_tlp_vc = tmp_rx_tlp_vc[NVC-1:0];
        end
    end
end

always @(posedge core_clk or negedge core_rst_n)
begin : RECEIVE_INIT2_FLAG
integer i;
    if(!core_rst_n) begin
        fc_init2_rcvd_flags <= #TP 0;
    end else if (tmp_link_down) begin
        fc_init2_rcvd_flags <= #TP 0;
    end else begin
        for (i = 0; i < NVC; i = i+1) begin
           if (vc_disable[i]) begin // disabled VC
               fc_init2_rcvd_flags[i]   <= #TP 1'b0;
           end else begin
               fc_init2_rcvd_flags[i]   <= #TP fc_init2_rcvd_flags[i] | rx_fc2_p[i] | rx_fc2_np[i] | rx_fc2_cpl[i] |
                                               rx_tlp_vc[i] | rx_updt_p[i] | rx_updt_np[i] | rx_updt_cpl[i];
           end
        end
    end
end

assign fc_init1_rcvd_flags = fc_init1_rcvd_pflags & fc_init1_rcvd_npflags & fc_init1_rcvd_cplflags;

always @(posedge core_clk or negedge core_rst_n)
begin : RECORD_SENT_FC1
integer i;
    if(!core_rst_n)
        fc_init1_sent_flags <= #TP 0;
    else if (tmp_link_down)
        fc_init1_sent_flags <= #TP 0;
    else
        for (i = 0; i < NVC; i = i+1) begin
            if (vc_disable[i] | ((fc_state == S_IDLE) & !rtlh_fc_init1_status[i] & !(more_vc_uninited_2 & previous_is_fc1) & more_vc_uninited_1 ))
                fc_init1_sent_flags[i]  <= #TP 0;
            else if ((struc_vc_in_init == i) && in_init1_state)
                fc_init1_sent_flags[i]  <= #TP 1'b1;
        end
end
always @(posedge core_clk or negedge core_rst_n)
begin : RECORD_SENT_FC2
integer i;
    if(!core_rst_n)
        fc_init2_sent_flags <= #TP 0;
    else if (tmp_link_down)
        fc_init2_sent_flags <= #TP 0;
    else
        for (i = 0; i < NVC; i = i+1) begin
            if (vc_disable[i] | ((fc_state == S_IDLE) & !rtlh_fc_init_status[i] & more_vc_uninited_2 & (previous_is_fc1 | !more_vc_uninited_1)))
                fc_init2_sent_flags[i]  <= #TP 0;
            else if ((struc_vc_in_init == i) && in_init2_state)
                fc_init2_sent_flags[i]  <= #TP 1'b1;
        end
end

assign fc1_rollover = (&timer_32us_fc1); // Set timeout value to >24us <32us to roll over so that the high priority request will start
assign fc2_rollover = (&timer_32us_fc2); // Set timeout value to >24us <32us to roll over so that the high priority request will start

wire        timer2;

DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1 (0)
) u_gen_timer2
(
     .clk               (core_clk)
    ,.rst_n             (core_rst_n)
    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)

    ,.cnt_up_en         (timer2)      // timer count-up
);

reg  [11:0] timer_8us;
always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n) begin
        timer_8us   <= #TP 0;
    end else if (tmp_link_down || timer8us_timeout) begin
        timer_8us   <= #TP 0;
    end else if (!pm_freeze_fc_timer | smlh_in_l0_l0s) begin
        timer_8us   <= #TP timer_8us + (timer2 ? FREQ_MULTIPLIER : 1'b0);
    end
end

assign expired_8us_time_mpcie = 1'b0 ;            // Not Used in Conventional PCIe.
assign expired_8us_time_int = timer_8us[11] ;
assign expired_8us_time     = (phy_type == `PHY_TYPE_MPCIE) ? expired_8us_time_mpcie : expired_8us_time_int ;

assign timer8us_timeout = ( expired_8us_time & (!pm_freeze_fc_timer | smlh_in_l0_l0s));


always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n) begin
        timer_32us_fc1   <= #TP 0;
    end else if (tmp_link_down || (init1_triplet_sent & all_fc_init1_done) ) begin   // finished sending the first FC init1, so that we can start off the timer
        timer_32us_fc1   <= #TP 0;
    end else if (timer8us_timeout & !fc1_rollover & rtlh_fc_init_status[0]) begin   // holdinig the timer when there is a roll over
        timer_32us_fc1   <= #TP timer_32us_fc1 + 1;
    end
end

always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n) begin
        timer_32us_fc2   <= #TP 0;
    end else if (tmp_link_down || (init2_triplet_sent & all_fc_init2_done) ) begin   // finished sending the first FC init2, so that we can start off the timer
        timer_32us_fc2   <= #TP 0;
    end else if (timer8us_timeout & !fc2_rollover & rtlh_fc_init_status[0]) begin  // holdinig the timer when there is a roll over
        timer_32us_fc2   <= #TP timer_32us_fc2 + 1;
    end
end




always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        fc_state            <= #TP S_IDLE;
    end else if (tmp_link_down) begin  // terminate the VC init process when vc is disabled
        fc_state            <= #TP S_IDLE;
    end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Legacy code
        case(fc_state)
            S_IDLE: begin
        if (more_vc_uninited_2 & previous_is_fc1 ) begin    // there is a VC that is ready for INIT2, and priority coding will be ok since we are going into FC2 init
                       fc_state            <= #TP S_FC2_P;
        end else if (more_vc_uninited_1) begin
                       fc_state            <= #TP S_FC1_P;
                end else if (more_vc_uninited_2) begin    // there is a VC that is ready for INIT2, and priority coding will be ok since we are going into FC2 init
                       fc_state            <= #TP S_FC2_P;
                end
            end

            S_FC1_P:
                if (fc_init_req_ackd) begin
                    fc_state               <= #TP S_FC1_NP;
                end
            S_FC1_NP:
                if (fc_init_req_ackd) begin
                    fc_state               <= #TP S_FC1_CPL;
                end
            S_FC1_CPL:
                if (fc_init_req_ackd & all_fc_init1_done) begin
                   fc_state                <= #TP S_IDLE;
                end else if (fc_init_req_ackd ) begin
                   fc_state                <= #TP S_FC1_P;
                end
            S_FC2_P:
                if (fc_init_req_ackd) begin
                    fc_state               <= #TP S_FC2_NP;
                end
            S_FC2_NP:
                if (fc_init_req_ackd) begin
                    fc_state               <= #TP S_FC2_CPL;
                end
            S_FC2_CPL:
                if (fc_init_req_ackd & all_fc_init2_done) begin
                   fc_state                <= #TP S_IDLE;
                end else if (fc_init_req_ackd) begin
                    fc_state                <= #TP S_FC2_P;
                end

// mapping S_IDLE to default state to facilitate code coverage
            default: begin
                if (more_vc_uninited_1)
                    fc_state               <= #TP S_FC1_P;
                else
                    fc_state               <= #TP S_IDLE;
                end
                    
        endcase
// spyglass enable_block STARC05-2.11.3.1
    end

// Determine when to exit the INIT1 and INIT2 triplet states
assign all_fc_init1_done = &((uninit_vc_1 & fc_init1_sent_flags) | ~uninit_vc_1);
assign all_fc_init2_done = &((uninit_vc_2 & fc_init2_sent_flags) | ~uninit_vc_2);

// --------- outputs from fc state -------------------
//
always @(posedge core_clk or negedge core_rst_n)
begin: GEN_FC_INITED_FLAG
integer                      i;
    if(!core_rst_n) begin
        rtlh_fc_init_status      <= #TP 0;
    end else if (tmp_link_down) begin
        rtlh_fc_init_status      <= #TP 0;
    end else begin
        for (i = 0; i < NVC; i = i+1) begin
            if (vc_disable[i])  // We need to make sure that the update of the VC enable is in-sync with the state so that we do not terminate in the middle.
               rtlh_fc_init_status[i]      <= #TP 1'b0;
            else if ((i == struc_vc_in_init) && init2_triplet_sent && fc_init2_rcvd_flags[i])
               rtlh_fc_init_status[i]      <= #TP 1'b1;
         end
    end
end

always @(posedge core_clk or negedge core_rst_n)
begin: GEN_FC1_INITED_FLAG
integer                      i;
    if(!core_rst_n) begin
        rtlh_fc_init1_status      <= #TP 0;
    end else if (tmp_link_down) begin
        rtlh_fc_init1_status      <= #TP 0;
    end else begin
        for (i = 0; i < NVC; i = i+1) begin
            if (vc_disable[i])  // We need to make sure that the update of the VC enable is in-sync with the state so that we do not terminate in the middle.
               rtlh_fc_init1_status[i]      <= #TP 1'b0;
            else if ((i == struc_vc_in_init) && init1_triplet_sent && fc_init1_rcvd_flags[i])
               rtlh_fc_init1_status[i]      <= #TP 1'b1;
         end
    end
end


wire     [11:0]      init_ca_pd;             // Payload(data) credits accumulated (posted, non-posted, completion)
wire     [11:0]      init_ca_npd;
wire     [11:0]      init_ca_cpld;
wire     [7:0]       init_ca_ph;             // Header credits accumulated (posted, non-posted, completion)
wire     [7:0]       init_ca_nph;
wire     [7:0]       init_ca_cplh;

wire [7:0]  hdr_fc_max  =  8'h7f;  // max allowable header credits for non-scaling
wire [11:0] data_fc_max = 12'h7ff; // max allowable data credits for non-scaling

// set all scaled inputs to zero if scaling not enabled
wire                  fc_scaled_en =       1'b0;
wire [1:0]            vc_hdr_scale_p =     2'b00;
wire [1:0]            vc_hdr_scale_np =    2'b00;
wire [1:0]            vc_hdr_scale_cpl =   2'b00;
wire [1:0]            vc_data_scale_p =    2'b00;
wire [1:0]            vc_data_scale_np =   2'b00;
wire [1:0]            vc_data_scale_cpl =  2'b00;


wire     [11:0]      init_ca_pd_int;             // Payload(data) credits accumulated (posted, non-posted, completion)
wire     [11:0]      init_ca_npd_int;
wire     [11:0]      init_ca_cpld_int;
wire     [7:0]       init_ca_ph_int;             // Header credits accumulated (posted, non-posted, completion)
wire     [7:0]       init_ca_nph_int;
wire     [7:0]       init_ca_cplh_int;


assign init_ca_pd_int   = get_fc_data_credit(cfg_fc_credit_pd,struc_vc_in_init);
assign init_ca_npd_int  = get_fc_data_credit(cfg_fc_credit_npd,struc_vc_in_init);
assign init_ca_cpld_int = get_fc_data_credit(cfg_fc_credit_cpld,struc_vc_in_init);
assign init_ca_ph_int   = get_fc_hdr_credit(cfg_fc_credit_ph,struc_vc_in_init);
assign init_ca_nph_int  = get_fc_hdr_credit(cfg_fc_credit_nph,struc_vc_in_init);
assign init_ca_cplh_int = get_fc_hdr_credit(cfg_fc_credit_cplh,struc_vc_in_init);
// if link partner does not support FC Scaling and credits are non infinite then reduce credits available to max allowable for non-scaling
assign init_ca_pd   =  (!fc_scaled_en && vc_data_scale_p > 2'b01   && (init_ca_pd_int !=0))   ? data_fc_max : init_ca_pd_int;
assign init_ca_npd  =  (!fc_scaled_en && vc_data_scale_np > 2'b01  && (init_ca_npd_int !=0))  ? data_fc_max : init_ca_npd_int;
assign init_ca_cpld =  (!fc_scaled_en && vc_data_scale_cpl > 2'b01 && (init_ca_cpld_int !=0)) ? data_fc_max : init_ca_cpld_int;
assign init_ca_ph   =  (!fc_scaled_en && vc_hdr_scale_p > 2'b01    && (init_ca_ph_int !=0))   ? hdr_fc_max :  init_ca_ph_int;
assign init_ca_nph  =  (!fc_scaled_en && vc_hdr_scale_np > 2'b01   && (init_ca_nph_int !=0))  ? hdr_fc_max :  init_ca_nph_int;
assign init_ca_cplh =  (!fc_scaled_en && vc_hdr_scale_cpl > 2'b01  && (init_ca_cplh_int !=0)) ? hdr_fc_max :  init_ca_cplh_int;

// The FC init packets contain constant data
//
assign vc_in_init   = { get_VCID(cfg_vc_struc_vc_id_map,struc_vc_in_init,2)
                       ,get_VCID(cfg_vc_struc_vc_id_map,struc_vc_in_init,1)
                       ,get_VCID(cfg_vc_struc_vc_id_map,struc_vc_in_init,0)};
wire    [31:0]  fc1_p_data;
wire    [31:0]  fc1_np_data;
wire    [31:0]  fc1_cpl_data;
wire    [31:0]  fc2_p_data;
wire    [31:0]  fc2_np_data;
wire    [31:0]  fc2_cpl_data;


assign fc1_p_data   = {init_ca_pd[7:0],   init_ca_ph[1:0],   2'b0, init_ca_pd[11:8],  2'b0, init_ca_ph[7:2],   `INITFC1_P,   vc_in_init};
assign fc1_np_data  = {init_ca_npd[7:0],  init_ca_nph[1:0],  2'b0, init_ca_npd[11:8], 2'b0, init_ca_nph[7:2],  `INITFC1_NP,  vc_in_init};
assign fc1_cpl_data = {init_ca_cpld[7:0], init_ca_cplh[1:0], 2'b0, init_ca_cpld[11:8],2'b0, init_ca_cplh[7:2], `INITFC1_CPL, vc_in_init};
assign fc2_p_data   = {init_ca_pd[7:0],   init_ca_ph[1:0],   2'b0, init_ca_pd[11:8],  2'b0, init_ca_ph[7:2],   `INITFC2_P,   vc_in_init};
assign fc2_np_data  = {init_ca_npd[7:0],  init_ca_nph[1:0],  2'b0, init_ca_npd[11:8], 2'b0, init_ca_nph[7:2],  `INITFC2_NP,  vc_in_init};
assign fc2_cpl_data = {init_ca_cpld[7:0], init_ca_cplh[1:0], 2'b0, init_ca_cpld[11:8],2'b0, init_ca_cplh[7:2], `INITFC2_CPL, vc_in_init};

always @(*)
begin
        case(fc_state)
            S_IDLE: begin
                fc_init_req         = 0;
                fc_init_req_data    = 0;
                fc_init_req_hi      = 1'b0;
                fc_init_req_low     = 1'b0;
                init2_triplet_sent  = 1'b0;
                init1_triplet_sent  = 1'b0;
                in_init1_state      = 1'b0;
                in_init2_state      = 1'b0;
            end
            S_FC1_P: begin
                fc_init_req         = 2'b01;
                fc_init_req_data    = {32'b0, fc1_p_data};
                fc_init_req_hi      = (fc1_rollover || this_is_vc0);   // change to high priority when timer expired or VC0 init
                fc_init_req_low     = (!this_is_vc0 && !fc1_rollover);
                init2_triplet_sent  = 1'b0;
                init1_triplet_sent  = 1'b0;
                in_init1_state      = 1'b1;
                in_init2_state      = 1'b0;
            end
            S_FC1_NP:  begin
                fc_init_req         = 2'b01;
                fc_init_req_data    = {32'b0, fc1_np_data};
                fc_init_req_hi      = 1'b1;
                fc_init_req_low     = 1'b0;
                init2_triplet_sent  = 1'b0;
                init1_triplet_sent  = 1'b0;
                in_init1_state      = 1'b1;
                in_init2_state      = 1'b0;
            end
            S_FC1_CPL:  begin
                fc_init_req         = 2'b01;
                fc_init_req_data    = {32'b0, fc1_cpl_data};
                fc_init_req_hi      = 1'b1;
                fc_init_req_low     = 1'b0;
                init2_triplet_sent  = 1'b0;
                init1_triplet_sent  = latch_next_req_en;
                in_init1_state      = 1'b1;
                in_init2_state      = 1'b0;
            end
            S_FC2_P:  begin
                fc_init_req         = 2'b01;
                fc_init_req_data    = {32'b0, fc2_p_data};
                fc_init_req_hi      = (fc2_rollover || this_is_vc0);
                fc_init_req_low     = (!this_is_vc0 && !fc2_rollover);   // change to high priority when timer expired or VC0 init
                init2_triplet_sent  = 1'b0;
                init1_triplet_sent  = 1'b0;
                in_init1_state      = 1'b0;
                in_init2_state      = 1'b1;
            end
            S_FC2_NP:  begin
                fc_init_req         = 2'b01;
                fc_init_req_data    = {32'b0, fc2_np_data};
                fc_init_req_hi      = 1'b1;
                fc_init_req_low     = 1'b0;
                init2_triplet_sent  = 1'b0;
                init1_triplet_sent  = 1'b0;
                in_init1_state      = 1'b0;
                in_init2_state      = 1'b1;
            end
            S_FC2_CPL:  begin
                fc_init_req         = 2'b01;
                fc_init_req_data    = {32'b0, fc2_cpl_data};
                fc_init_req_hi      = 1'b1;
                fc_init_req_low     = 1'b0;
                init2_triplet_sent  = latch_next_req_en;
                init1_triplet_sent  = 1'b0;
                in_init1_state      = 1'b0;
                in_init2_state      = 1'b1;
            end
            default: begin
                fc_init_req         = 0;
                fc_init_req_data    = 0;
                fc_init_req_hi      = 1'b0;
                fc_init_req_low     = 1'b0;
                init2_triplet_sent  = 1'b0;
                init1_triplet_sent  = 1'b0;
                in_init1_state      = 1'b0;
                in_init2_state      = 1'b0;
            end
        endcase
end


// --------- FC requests arbitration logic between regular update and init requests
//
// Get the data associated with the next request
reg     [31:0]  tmp_data_next;
wire    [63:0]  rtfcgen_data_next;
assign rtfcgen_data_next = {32'b0, tmp_data_next};

always @(rtfcgen_data or selected_next)
begin : data_mux

    integer l,j;
    tmp_data_next = 0;
    for (l=0; l<NVC; l=l+1)
        if (l == selected_next)
            for (j=0; j<32; j=j+1)
                tmp_data_next[j] = rtfcgen_data[(l*32)+j];
end



//
// Now make the arbitration decision. Once a client is selected, it stays
// selected until it deasserts its request
//
assign selected_next = priority_encode(rtfcgen_reqs);

assign latch_next_req_en = !(|int_fc_req) || xdlh_rtlh_fc_ack;

// Create a pulse to elevate the priority of a low priority request (fc init) that is being blocked by TLPs
// in order for a high-priority request (fc update due to timeout) to get transmitted
wire   elevate_priority;
assign elevate_priority = int_fc_req_low & (rtfcgen_reqs[selected_next] & rtfcgen_reqs_hi[selected_next]);

always @(posedge core_clk or negedge core_rst_n)
begin : make_requests

    integer k;

    if(!core_rst_n) begin
        int_fc_req          <= #TP 0;
        int_fc_req_hi       <= #TP 0;
        int_fc_req_low      <= #TP 0;
        int_fc_data         <= #TP 0;
    end else if (tmp_link_down) begin
        int_fc_req          <= #TP 0;
        int_fc_req_hi       <= #TP 0;
        int_fc_req_low      <= #TP 0;
        int_fc_data         <= #TP 0;
    end else begin
        if (latch_next_req_en && (this_is_vc0 || fc_init_req_hi) && (|fc_init_req)) begin  // in VC0 init
            int_fc_req      <= #TP fc_init_req[TX_NDLLP-1:0];
            int_fc_req_hi   <= #TP fc_init_req_hi;
            int_fc_req_low  <= #TP fc_init_req_low;
            int_fc_data     <= #TP fc_init_req_data[(TX_NDLLP*32)-1:0];
        end else if (latch_next_req_en && (|fc_upd_req)) begin      // not VC0 init and regular update asserted
            int_fc_req      <= #TP fc_upd_req[TX_NDLLP-1:0];
            int_fc_req_hi   <= #TP 1'b1;
            int_fc_req_low  <= #TP 1'b0;
            int_fc_data     <= #TP rtfcgen_data_next[(TX_NDLLP*32)-1:0];
        end else if (latch_next_req_en && (|fc_init_req)) begin     // not VC0 init and regular fc init req asserted
            int_fc_req      <= #TP fc_init_req[TX_NDLLP-1:0];
            int_fc_req_hi   <= #TP fc_init_req_hi;
            int_fc_req_low  <= #TP fc_init_req_low;
            int_fc_data     <= #TP fc_init_req_data[(TX_NDLLP*32)-1:0];
        end else if (latch_next_req_en) begin                       // not VC0 init and regular fc init req asserted
            int_fc_req      <= #TP 1'b0;
            int_fc_req_hi   <= #TP 1'b0;
            int_fc_req_low  <= #TP 1'b0;
            int_fc_data     <= #TP 0;
        end else if (elevate_priority) begin
            int_fc_req_hi   <= #TP 1'b1;
            int_fc_req_low  <= #TP 1'b0;
        end
    end
end

// request acknowledgment generation

//assign fc_upd_req       = (TX_NDLLP ==2) ? {1'b0, (|rtfcgen_reqs)} : |rtfcgen_reqs;
assign fc_upd_req       = {1'b0, (|rtfcgen_reqs)};

assign fc_init_req_ackd = latch_next_req_en && (|fc_init_req) && (this_is_vc0 || fc_init_req_hi || !(|fc_upd_req));

always @(latch_next_req_en or selected_next or fc_upd_req or this_is_vc0 or fc_init_req or fc_init_req_hi)
begin: gen_rtfcarb_acks
integer m;

    for (m=0; m<NVC; m=m+1) begin
        if (selected_next == m) begin
            rtfcarb_acks[m] = latch_next_req_en && (|fc_upd_req) &&
                              (!(|fc_init_req) || (!this_is_vc0 && !fc_init_req_hi && (|fc_init_req)));
        end else begin
            rtfcarb_acks[m] = 1'b0;
        end
    end
end

// -------- output drives ------------------------------
assign rtlh_xdlh_fc_req     = int_fc_req;
assign rtlh_xdlh_fc_req_hi  = int_fc_req_hi;
assign rtlh_xdlh_fc_req_low = int_fc_req_low;
assign rtlh_xdlh_fc_data    = int_fc_data;


// -------- watch dog timer to monitor link -----------
// Following logic implementing the optional requirement from the spec.
// 2.6.1.2 for a watch dog timer to initiate a link retraining when there
// is a problem receiving any DLLPs. This watch dog timer is required as 256 us long.
// Here is implementation is to have FC timer roll over to the extended
// wdog timer
//
wire   timer8us_timeout_wd; 
assign timer8us_timeout_wd = timer8us_timeout;

reg [SCALED_WDOG_TIMER_PTR_WD -1:0] ext_wdog_timer;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ext_wdog_timer  <= #TP 0;
    else if (|rdlh_rtlh_rcvd_dllp | xadm_all_type_infinite | cfg_fc_wdog_disable)
        ext_wdog_timer  <= #TP 0;
    else
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Timer counters are intended to
// wrap without preseveration of carry/borrow
        ext_wdog_timer  <= #TP timer8us_timeout_wd + ext_wdog_timer;

// spyglass enable_block W164a

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rtlh_req_link_retrain   <= #TP 0;
    end else begin
        // LTSSM expected a pulse
        rtlh_req_link_retrain   <= #TP (ext_wdog_timer == SCALED_WDOG_TIMER_EXP_VALUE) & timer8us_timeout_wd & ~(|rdlh_rtlh_rcvd_dllp);
    end

//  -------- A single 32us update timer is implemented here ----------------
wire    [3:0]           fc_updt_freq_value;
assign fc_updt_freq_value = cfg_ext_synch ? 4'b1111 : 4'b0100; // regularly 32 us otherwise 120us

reg [3:0]   fc_timer;
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        fc_timer    <= #TP 0;
    else if (fc_update_timer_expired)
        fc_timer    <= #TP  0;
    else if (timer8us_timeout)
        fc_timer    <= #TP fc_timer + 1'b1;

assign fc_update_timer_expired = (fc_timer >= fc_updt_freq_value);

// Simple priority encoder, return index of the lowest set bit
function automatic [2:0] priority_encode;
    input [NVC-1:0] reqs;

    integer i;

begin
    priority_encode = 0;
    for (i=0; i<NVC; i=i+1)
        if (reqs[NVC-i-1])
            priority_encode = NVC-i-1;
end
endfunction

// Simple finder to determine the next VC
//function [2:0] get_next_vc;
//    input [NVC-1:0] reqs;
//    input [2:0] previous_reqs;
//
//    integer i;
//    reg [2:0] reqs_below;
//    reg [2:0] reqs_above;
//begin
//    get_next_vc = 0;
//    reqs_above  = 0;
//    reqs_below  = 0;
//    for (i=1; i<previous_reqs; i=i+1) begin
//       if (reqs[i] & (reqs_below == 0))
//              reqs_below = i;
//    end
//    for (i=previous_reqs+1; i>NVC; i=i+1) begin
//        if (reqs[i] & (reqs_above == 0))
//            reqs_above = i;
//    end
//    get_next_vc = (reqs_above != 0) ? reqs_above : reqs_below;
//end
//endfunction

function automatic get_VCID;
input [NVC*3-1:0] vcid_struct_map_local;
input [2:0] strct_vcid;
input [1:0] client_ndx;
reg [NVC*3:0] vcid_struct_map_local_padded;
//cfg_vc_id_vc_struc_map[(3*rdlh_rtlh_dllp1_VCID) +2]
begin
    get_VCID           = 0;
    vcid_struct_map_local_padded =  {1'b0,vcid_struct_map_local};

    case (strct_vcid)
        3'b000:     get_VCID   = vcid_struct_map_local_padded[client_ndx + (0*3)];
        default:    get_VCID   = vcid_struct_map_local_padded[client_ndx + (0*3)];
    endcase // case(strct_vcid)
end
endfunction

  function automatic [7:0] get_fc_hdr_credit;
  input [(NVC*8)-1:0] input_vec;
  input [2:0] bit_loc;
  begin
          get_fc_hdr_credit = input_vec[7:0];

    case  (bit_loc)
             3'b000:  get_fc_hdr_credit = input_vec[7:0];
              default: get_fc_hdr_credit = input_vec[7:0];
    endcase // case
  end
  endfunction


  function automatic [11:0] get_fc_data_credit;
  input [(NVC*12)-1:0] input_vec;
  input [2:0] bit_loc;
  begin
          get_fc_data_credit = input_vec[11:0];

    case  (bit_loc)
             3'b000:  get_fc_data_credit = input_vec[11:0];
              default: get_fc_data_credit = input_vec[11:0];
    endcase // case
  end
  endfunction



function automatic [7:0] map_to_8_bits;
input [2:0] bit_loc;
begin
        map_to_8_bits = 0;

    case  (bit_loc)
        3'b000:     map_to_8_bits = 8'h01;
        3'b001:     map_to_8_bits = 8'h02;
        3'b010:     map_to_8_bits = 8'h04;
        3'b011:     map_to_8_bits = 8'h08;
        3'b100:     map_to_8_bits = 8'h10;
        3'b101:     map_to_8_bits = 8'h20;
        3'b110:     map_to_8_bits = 8'h40;
        default:    map_to_8_bits = 8'h80;
    endcase
end
endfunction




endmodule
