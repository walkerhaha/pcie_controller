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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_dllp_gen.sv#7 $
// -------------------------------------------------------------------------
// --- Function Description:
// -----------------------------------------------------------------------------
//      This block is designed to arbitrate the DLLPs. DLLP generation came from
//      four requests:
//      1. Upper TLH layer request to send a FC DLLP
//      2. RDLH layer request to send a ACK or NACK DLLP
//      3. Upper TLH layer or software request to send a special DLLP
//      4. power management module requests to send pm dllp
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xdlh_dllp_gen(
    core_clk,
    core_rst_n,
    cfg_ack_freq,
    cfg_ack_latency_timer,
    cfg_acknack_disable,
    cfg_flow_control_disable,
    phy_type,
    
    rdlh_link_up,
    rdlh_link_state,

    // local bus controlled dllp message
    cfg_other_msg_request,
    cfg_other_msg_payload,

    // rtlh fc gen block interface signals for fc generation
    rtlh_xdlh_fc_data,
    rtlh_xdlh_fc_req,
    rtlh_xdlh_fc_req_hi,
    rtlh_xdlh_fc_req_low,

    // rdlh  tlp extrace block interface signals for ack/nak generation
    rdlh_xdlh_req2send_ack,
    rdlh_xdlh_req2send_ack_due2dup,
    rdlh_xdlh_req2send_nack,
    rdlh_xdlh_req_acknack_seqnum,

    // pm module contorlled dllp message
    pm_xdlh_enter_l1 ,
    pm_xdlh_req_ack,
    pm_xdlh_enter_l23,
    pm_xdlh_actst_req_l1,
    pm_freeze_ack_timer,

    xdctrl_dllp_halt,
    xmlh_xdlh_halt,
    xdlh_last_pmdllp_ack,
    smlh_in_rcvry,
    // -------------- outputs ----------------
    nak_scheduled,
    dllp_xmt_req,
    dllp_last_pmdllp_req,
    dllp_req_low_prior,
 //   dllp_xmt_pkt,
    dllp_xmt_pkt_10b,
 
    nodllp_pending,
//    xdlh_nodllp_pending,
    xdlh_rtlh_fc_ack
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance.
parameter   NW      = `CX_NW;   // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW      = (32*NW);  // Width of datapath in bits.
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)
parameter   NB      = `CX_NB;   // Number of 32-bit dwords handled by the datapath each clock.
// parameter   TX_NDLLP= ((NW >= 4) & (NB >= 2)) ? 2 : 1; // number of DLLPs send per cycle
parameter   TX_NDLLP  =  1;

// =============================================================================
// -------------- parameters ----------------
// =============================================================================

//parameter PM_REQ_ACK        = 8'b00100100;  // Power Management dllp opcode
//parameter PM_ENTR_L1        = 8'b00100000;
//parameter PM_ENTR_L23       = 8'b00100001;
//parameter PM_AS_REQ_L1      = 8'b00100011;

// =============================================================================
// -------------- inputs ----------------
// =============================================================================
input                        core_clk;
input                        core_rst_n;
input                        rdlh_link_up;
input   [1:0]                rdlh_link_state;
input   [7:0]                cfg_ack_freq;                   // 8bits programmable value to allow up to 256 ack accumulated before send
input   [15:0]               cfg_ack_latency_timer;          // If the core is dynamic width, this timer has already been divided by NB
input                        cfg_acknack_disable;            // Prevent sending of ack/nak packetsw
input                        cfg_flow_control_disable;       // Prevent sending of flow control packets
input                        phy_type;                       // Phy Type

input                        cfg_other_msg_request;
input   [31:0]               cfg_other_msg_payload;

input                        rdlh_xdlh_req2send_ack;         // rdlh received a good packed and has been asking to send an ack back. This signal is muturally exclusive with nak signal
input                        rdlh_xdlh_req2send_ack_due2dup; // rcv_dup indicated that the current pkt received is a duplicated pkt and rdlh is requesting an ack being sent by xdlh through req2send_ack signal
input                        rdlh_xdlh_req2send_nack;        // rdlh received a good packed and has been asking to send an ack back. This signal is muturally exclusive with nak signal
input   [11:0]               rdlh_xdlh_req_acknack_seqnum;   // signal fromIRU that  is programmed by softwre

input                        pm_xdlh_enter_l1;
input                        pm_xdlh_req_ack;
input                        pm_xdlh_enter_l23;
input                        pm_xdlh_actst_req_l1;
input                        pm_freeze_ack_timer;            // PM module request to freeze acknack latency timer.

input   [TX_NDLLP -1:0]      rtlh_xdlh_fc_req;
input   [(32*TX_NDLLP)-1:0]  rtlh_xdlh_fc_data;
input                        rtlh_xdlh_fc_req_hi;            // When asserted, RTLH has requested to send a high-priority FC packet that has higher priority than ACK/NACK
input                        rtlh_xdlh_fc_req_low;           // When asserted, RTLH has requested to send a low-priority FC packet that has lower priority than TLP

input                        xdctrl_dllp_halt;
input                        xmlh_xdlh_halt;                // Since there is a priority request which influence the tlp and dllp arbitration happened in xdlh control. It is important to monitor the halt from the XMLH layer so that we know that it is making progress from the lower layer.
input                        xdlh_last_pmdllp_ack;           // The last PM DLLP has been detected
input                        smlh_in_rcvry;                  // LTSSM enters recovery so all PM DLLP transmit requests will be masked
// =============================================================================
// -------------- outputs ----------------
// =============================================================================
output                       nak_scheduled;                // dllp generation block requests nak is scheduled to be transmitted
// output  [64*TX_NDLLP-1:0]    dllp_xmt_pkt;


output  [64*TX_NDLLP-1:0]    dllp_xmt_pkt_10b;  
 
output  [TX_NDLLP-1:0]       dllp_xmt_req;
output                       dllp_last_pmdllp_req;
output                       dllp_req_low_prior;
output                       xdlh_rtlh_fc_ack;
output                       nodllp_pending;
//output                       xdlh_nodllp_pending;

// =============================================================================
// -------------- Parameter declaration ----------------
// =============================================================================
localparam  P_ACK_DLLP    = 4'b0001,
            P_ASPM_DLLP   = 4'b0010,
            P_L1_DLLP     = 4'b0100,
            P_L2_DLLP     = 4'b1000;
localparam  P_PM_DLLP_WD  = 4;
           
// =============================================================================
// -------------- IO declaration ----------------
// =============================================================================
wire    [64*TX_NDLLP-1:0]    dllp_xmt_pkt;
wire    [TX_NDLLP -1:0]      dllp_xmt_req;
reg                          dllp_last_pmdllp_req;
wire                         xdlh_rtlh_fc_ack;
//reg                          xdlh_nodllp_pending;
reg                          dllp_req_low_prior;

wire                       send_feature_dllp = 1'b0;
wire [22:0]                cfg_local_feature_support = 23'b0;       // Local Feature (Including local scaled flow control) Support
wire                       cfg_dlink_feature_valid = 1'b0;

// =============================================================================
// -------------- Internal Signal declaration ----------------
// =============================================================================
reg                     int_enter_l1;
reg                     int_req_ack;
reg                     int_enter_l23;
reg                     int_actst_req_l1;
wire                    int_acknack_disable;
wire                    int_flow_control_disable;
wire    [1:0]           wire_TX_NDLLP;
assign wire_TX_NDLLP  = TX_NDLLP;
wire    [127:0]         int_dllp_xmt_pkt;
assign int_dllp_xmt_pkt = 128'h0;
wire    [127:0]         int_dllp_xmt_pkt_10b;

reg     [1:0]           int_dllp_xmt_req;
reg     [3:0]           int_last_pm_req;
wire                    link_rdy4dllp;
assign link_rdy4dllp       = (rdlh_link_state != `S_DL_INACTIVE);

wire    [15:0]          dllp1_checksum;
wire    [15:0]          dllp2_checksum;
wire    [15:0]          dllp1_checksum_org;
wire    [15:0]          dllp2_checksum_org;

//reg     [15:0]          ack_latency_timer;

wire                    int_pm_req;
reg     [P_PM_DLLP_WD - 1 : 0]  int_req_pmdllp_r;
reg     [P_PM_DLLP_WD - 1 : 0]  int_last_pm_req_r;
wire    [P_PM_DLLP_WD - 1 : 0]  int_pm_req_fe;
wire    [P_PM_DLLP_WD - 1 : 0]  int_req_pmdllp;
wire                    int_last_pm_req_or;
wire                    int_pmdllp_pending;
reg                     int_pmdllp_pending_r;
wire                    int_clear_pmdllp_req;
wire                    int_set_last_pm_req;
wire                    int_clear_pmdllp_pending;

reg  ack_transmitted;

// Detect the de-assertion of the PM DLLP transmit request in order to schedule
// a last DLLP for transmission
assign int_last_pm_req_or = |int_last_pm_req;
assign int_pm_req_fe  = int_req_pmdllp_r & ~int_req_pmdllp;
assign int_req_pmdllp = {int_enter_l23, int_enter_l1, int_actst_req_l1, int_req_ack};
// PM DLLP request generation
assign int_pm_req     = ((|int_req_pmdllp) || (int_last_pm_req_or)) && !smlh_in_rcvry;

wire                    int_fc_req;
assign int_fc_req     = (|rtlh_xdlh_fc_req) & link_rdy4dllp & !int_flow_control_disable;  // fc dllp can be transmitted during rdlh_link_state in init
assign int_flow_control_disable = cfg_flow_control_disable
                                ;

// fc dllp can be transmitted during rdlh_link_state in init
wire                    fc_req_dual;
assign fc_req_dual    = (wire_TX_NDLLP == 2 ) ? ((rtlh_xdlh_fc_req == 2'b11) & link_rdy4dllp) : 1'b0;  
wire                    int_acknak_req;
reg                     int_msg_req;

reg                     int_pm_req_ack;
wire                    int_fc_req_ack;
reg                     int_acknak_req_ack;
reg                     int_msg_req_ack;

wire    [7:0]           pm_msg_opcode;
reg     [7:0]           int_last_pmdllp_opcode;
reg     [7:0]           int_pm_msg_opcode;
reg                     ack_latched;

always @(posedge core_clk or negedge core_rst_n)
begin
  if (!core_rst_n)
    int_pm_msg_opcode <= #TP 8'hff;
  else
    int_pm_msg_opcode <= #TP pm_msg_opcode;
end

// PM message opcode will be set based on the type of PM DLLP being requested
// This signal holds its value to insure that if the low power entry was
// aborted the last DLLP being sent would still have the correct CRC.
// Otherwire when dllp_xmt_req is cleared by int_clear_pmdllp_req the
// int_dllp_data would be changed before the CRC was calculated on the PM DLLP
assign pm_msg_opcode        =  (int_req_ack) ? `PM_REQ_ACK
                                                : (int_enter_l1) ? `PM_ENTER_L1
                                                : (int_enter_l23) ? `PM_ENTER_L23
                                                : (int_actst_req_l1) ? `PM_AS_REQ_L1
                                                : (int_last_pm_req_or) ? int_last_pmdllp_opcode
                                                : int_pm_msg_opcode;

wire    [31:0]          pm_dllp_data;
assign pm_dllp_data          = {24'b0, pm_msg_opcode};

wire     [63:0]          int_dllp_data  ;
reg     [63:0]          int_dllp_data_pre  ;
wire    [4:0]           int_grant;
reg     [4:0]           int_1dllp_grant;

reg                     ack_timer_expired;
reg  [`ACK_TIMER_WIDTH-1:0]      ack_timer; // ACK_TIMER_WIDTH should be set to 14 according to current spec.

reg     [11:0]          scheduled_acknak_seqnum_org;
wire    [11:0]          scheduled_acknak_seqnum;
reg                     nak_scheduled;
reg                     ack_scheduled;
reg                     nak_sent;
reg                     ack_due2dup;
wire    [7:0]           ack_nak_code;
wire    [7:0]           ack_nak_code_org;
assign ack_nak_code_org     = (nak_scheduled & !nak_sent) ? 8'b00010000 : 8'b0;

wire    [31:0]          acknak_dllp_data;
assign acknak_dllp_data     = {scheduled_acknak_seqnum[7:0], 4'b0, scheduled_acknak_seqnum[11:8], 8'b0, ack_nak_code};

assign ack_nak_code         = ack_nak_code_org ;

reg                     previous_send_nak;
wire                    ack_req_low_prior ;

// This signal is designed to use as a sample point control. When it is
// asserted, output data from this block will be valid until the next
// assertion.
wire                    latch_outdata_en;

always @(*) int_req_ack = pm_xdlh_req_ack;
always @(*) int_enter_l1 = pm_xdlh_enter_l1;
always @(*) int_enter_l23 = pm_xdlh_enter_l23;
always @(*) int_actst_req_l1 = pm_xdlh_actst_req_l1;

// cfg msg register request a dllp can be asserted based on rising edge of
// the cfg request
reg dlyd_msg_req;
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)  begin
        dlyd_msg_req <= #TP 0;
    end else begin
        dlyd_msg_req <= #TP cfg_other_msg_request;
    end

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)  begin
        int_msg_req  <= #TP 0;
    end else if (int_msg_req_ack) begin
        int_msg_req  <= #TP 1'b0 ;
    end else if (cfg_other_msg_request & !dlyd_msg_req) begin
        int_msg_req  <= #TP 1'b1 ;
    end

// Arbiter logic to select the dllp to be transmitted
//
wire  valid_ack_req;
wire  valid_fc_req;
wire  valid_msg_req;
wire  valid_pm_req;

wire  overwrite_latched_ack = ack_latched && !latch_outdata_en && ack_scheduled;

assign valid_ack_req = (int_acknak_req & !int_acknak_req_ack & !ack_latched & !ack_transmitted &
              (!ack_req_low_prior || !valid_fc_req & !valid_msg_req & !valid_pm_req)  // when ack is high priority or when ack requested and no other requests
              && (rdlh_link_state == `S_DL_ACTIVE));  // when FC is not at its highest priority

assign valid_fc_req  = int_fc_req;               // when fc has normal or low priority

assign valid_msg_req = (int_msg_req & !int_msg_req_ack ) && (rdlh_link_state == `S_DL_ACTIVE); // msg or pm dllps has lower priority than TLP or FC

assign valid_pm_req  = (int_pm_req && !int_pm_req_ack) && (rdlh_link_state == `S_DL_ACTIVE);

always @(send_feature_dllp or valid_ack_req or valid_fc_req or valid_msg_req or valid_pm_req)
    casez ({send_feature_dllp, valid_ack_req, valid_fc_req, valid_msg_req, valid_pm_req})
    5'b00000:
        int_1dllp_grant = 5'b00000;
    5'b00001:
        int_1dllp_grant = 5'b00001;
    5'b0001?:
        int_1dllp_grant = 5'b00010;
    5'b001??:
        int_1dllp_grant = 5'b00100;
    5'b01???:
        int_1dllp_grant = 5'b01000;
    5'b1????:
        int_1dllp_grant = 5'b10000;
//    default: unreachable branch
//        int_1dllp_grant = 4'b0000;
endcase

assign int_grant  = int_1dllp_grant;
// Note: Due to dllp gen block and xdlh_control block interface is defined
// that request has to be asserted first when dllps generated in this block
// is valid. The xdctrl_dllp_halt is served as a halt if necessary from
// xdlh control block.
// In order to serve back to back, we have latched the output data in this
// block so that the block can start to process the next dllp internally.
// !int_dllp_xmt_req is served for this purposes.
assign latch_outdata_en = !xdctrl_dllp_halt | ~(|int_dllp_xmt_req);

// If a transition to RECOVERY occurs when there is a pm dllp waiting to be granted
// a flag is generated to clear the DLLP transmit request. This will
// prevent the PM DLLP from being sent after exit from RECOVERY.
assign int_clear_pmdllp_pending = latch_outdata_en || int_clear_pmdllp_req;
assign int_pmdllp_pending = (int_grant[0] ? 1'b1 : 
                            (int_clear_pmdllp_pending ? 1'b0 : int_pmdllp_pending_r));
assign int_clear_pmdllp_req = int_pmdllp_pending_r && smlh_in_rcvry;

always @(posedge core_clk or negedge core_rst_n)
begin
  if(!core_rst_n)
  begin
    int_req_pmdllp_r      <= #TP 0;
    int_last_pm_req_r     <= #TP 0;
    int_pmdllp_pending_r  <= #TP 1'b0;
  end
  else
  begin
    int_req_pmdllp_r      <= #TP int_req_pmdllp;
    int_last_pm_req_r     <= #TP int_last_pm_req;
    int_pmdllp_pending_r  <= #TP int_pmdllp_pending;
  end
end

// Set the last PM DLLP request based on falling edge detect of the PM
// DLLP request but only if we are not in RECOVERY
assign int_set_last_pm_req = !smlh_in_rcvry && (|int_pm_req_fe);

always @(*)
begin
  if (int_set_last_pm_req)
    int_last_pm_req = int_pm_req_fe;
  else if (int_pm_req_ack)
    int_last_pm_req = {P_PM_DLLP_WD{1'b0}};
  else
    int_last_pm_req = int_last_pm_req_r;
end

// OPCODE for the last PM DLLP
always @ (*)
begin
  unique case(int_last_pm_req)
    P_ACK_DLLP  : int_last_pmdllp_opcode = `PM_REQ_ACK;
    P_ASPM_DLLP : int_last_pmdllp_opcode = `PM_AS_REQ_L1;
    P_L1_DLLP   : int_last_pmdllp_opcode = `PM_ENTER_L1;
    P_L2_DLLP   : int_last_pmdllp_opcode = `PM_ENTER_L23;
    default     : int_last_pmdllp_opcode = int_pm_msg_opcode; 
  endcase
end

// Acknowledgment generation process
//
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        int_pm_req_ack       <= #TP 0;
        int_acknak_req_ack   <= #TP 0;
        int_msg_req_ack      <= #TP 0;
    end else begin
        if (int_pm_req_ack)
           int_pm_req_ack    <= #TP 1'b0 ;
        else if (int_grant[0] & latch_outdata_en)
           int_pm_req_ack    <= #TP 1'b1 ;

        if (int_acknak_req_ack)
           int_acknak_req_ack<= #TP 1'b0 ;
        else if ((int_grant[3] & latch_outdata_en) | overwrite_latched_ack)
           int_acknak_req_ack<= #TP 1'b1 ;

      
        if (int_msg_req_ack)
           int_msg_req_ack   <= #TP 1'b0 ;
        else if (int_grant[1] & latch_outdata_en)
           int_msg_req_ack   <= #TP 1'b1 ;
    end

assign int_fc_req_ack       = (int_grant[2] & latch_outdata_en);

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        previous_send_nak    <= #TP 0;
    end else if (latch_outdata_en & int_grant[3]) begin
        previous_send_nak    <= #TP nak_scheduled;

    end

wire    [31:0]          fc_data_low;
assign fc_data_low  = rtlh_xdlh_fc_data[31:0];
wire    [31:0]          fc_data_high;
assign fc_data_high = (wire_TX_NDLLP == 2 ) ? rtlh_xdlh_fc_data[(32*TX_NDLLP)-1 : (32*TX_NDLLP)-32] : 32'b0;


wire    [64*TX_NDLLP-1:0]         feature_exchange_dllp_10b;
wire    [64*TX_NDLLP-1:0]         feature_exchange_dllp_130b;

wire feature_ack;
assign feature_ack = cfg_dlink_feature_valid;

//Output drives of dllp request and dllp pkt data
//latch the ready dllps to ouput to xdlh control block
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        int_dllp_xmt_req     <= #TP 0;
        int_dllp_data_pre        <= #TP 0;
    end else if (int_clear_pmdllp_req) begin
        int_dllp_xmt_req     <= #TP 0;
    end else if (latch_outdata_en) begin
        if ((int_grant == 5'b00001) | (int_grant == 5'b00010) | (int_grant == 5'b01000) | ((int_grant == 5'b00100) & (!fc_req_dual)) | (int_grant == 5'b10000))
        begin
           int_dllp_xmt_req     <= #TP 2'b01;
        end
        else if ((int_grant == 5'b00100) & fc_req_dual)
        begin
           int_dllp_xmt_req     <= #TP 2'b11;
        end
        else
        begin
           int_dllp_xmt_req     <= #TP 2'b00;
        end
//                                     : (|int_grant)
//                                      ? 2'b11 : 2'b00;

//        int_dllp_data        <= #TP   (int_grant[3] & int_grant[2]) ? {acknak_dllp_data, fc_data_low}
//                                    : (int_grant[3] & int_grant[1]) ? {acknak_dllp_data, cfg_other_msg_payload}
//                                    : (int_grant[3] & int_grant[0]) ? {acknak_dllp_data, pm_dllp_data}
//                                    : (int_grant[2] & int_grant[1]) ? {fc_data_low, cfg_other_msg_payload}
//                                    : (int_grant[2] & int_grant[0]) ? {fc_data_low, pm_dllp_data}
//                                    : (int_grant[1] & int_grant[0]) ? {cfg_other_msg_payload, pm_dllp_data}
//                                    : (int_grant[3]) ?  {32'b0, acknak_dllp_data}
//                                    : (int_grant[2]) ?  {fc_data_high, fc_data_low}
//                                    : (int_grant[1]) ? {32'b0, cfg_other_msg_payload}
//                                    : (int_grant[0]) ? {32'b0, pm_dllp_data}
//                                    : int_dllp_data;

// When send_feature_dllp is high, the feature exchange DLLP has priority over all other DLLPs
// This signal remains high during state S_DL_FEATURE in rdlh_link_cntrl
// During this state we remain link_down
        if (int_grant[4]) begin // Feature Exchange packet format
int_dllp_data_pre <= #TP {cfg_local_feature_support[7:0], cfg_local_feature_support[15:8], feature_ack, cfg_local_feature_support[22:16], 8'b00000010,
                      cfg_local_feature_support[7:0], cfg_local_feature_support[15:8], feature_ack, cfg_local_feature_support[22:16], 8'b00000010};                                
        end else if (int_grant[3]) begin
           int_dllp_data_pre        <= #TP {32'b0, acknak_dllp_data};
        end else if (int_grant[2]) begin
           int_dllp_data_pre        <= #TP {fc_data_high, fc_data_low};
        end else if (int_grant[1]) begin
           int_dllp_data_pre        <= #TP {32'b0, cfg_other_msg_payload};
        end else if (int_grant[0]) begin
           int_dllp_data_pre        <= #TP {32'b0, pm_dllp_data};
        end else begin
           int_dllp_data_pre        <= #TP int_dllp_data_pre;
        end
    end else if(overwrite_latched_ack)begin // if (latch_outdata_en)
        int_dllp_data_pre <= #TP int_dllp_data;
    end

assign int_dllp_data = overwrite_latched_ack ? {32'b0, acknak_dllp_data} : int_dllp_data_pre;


assign dllp1_checksum = dllp1_checksum_org ;
assign dllp2_checksum = dllp2_checksum_org ;

// beneath is a process that drives the priority indication to
// xdlh_control* to indicate that the DLLP's priority is lower or higher
// than TLP. Two conditions have lower priority.
// 1. when FC dllp that is possible to have a priority lower than TLP,
// therefore, we will latch the grant condition when FC has lower priority
// indicated.
// 2. When ACK frequency has not reached but ACK is scheduled.
// Note: When a ACK/NACK or other high priority DLLP requests have
// asserted, then we need to bump up the priority of the current DLLP
// request
always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n) begin
        dllp_req_low_prior   <= #TP 0;
    end else if ((ack_latched & ack_timer_expired) | (int_acknak_req & !ack_req_low_prior) | (!xmlh_xdlh_halt & int_fc_req & !rtlh_xdlh_fc_req_low)) begin  // When FC init for non VC0, the low priority request needs to assert until halt deassert, because we want to give TLP a chance. Otherwise, it can get into dead lock
        dllp_req_low_prior   <= #TP 1'b0;
    end else if (latch_outdata_en) begin  // latch the priority if it is FC grant
        dllp_req_low_prior   <= #TP ((int_grant == 5'b00100) & rtlh_xdlh_fc_req_low)
                                    | (int_grant == 5'b00010)   // for msg or pm dllp, the priority is always low
                                    | (int_grant == 5'b00001)
                                    | (int_grant == 5'b10000) // DL Feature
                                    | ((int_grant == 5'b01000) & ack_req_low_prior);
    end
end

// Last PM DLLP request
// 1. Set to 1 when the last PM DLLP has been granted by the arbitrer
// 2. Set to 0 when the acknowledge that the last PM DLLP has been sent is returned to PM_CTRL
always @(posedge core_clk or negedge core_rst_n)
begin
  if(!core_rst_n)
    dllp_last_pmdllp_req <= #TP 0;
  else
    if (latch_outdata_en && (int_grant == 5'b00001) && int_last_pm_req_or)
      dllp_last_pmdllp_req <= #TP 1;
    else if (xdlh_last_pmdllp_ack)
      dllp_last_pmdllp_req <= #TP 0;
end



assign int_dllp_xmt_pkt_10b   = (TX_NDLLP == 2) ?  {`END_8B, dllp2_checksum, int_dllp_data[63:32], `SDP_8B, `END_8B, dllp1_checksum, int_dllp_data[31:0], `SDP_8B} :
                                                   {64'd0, `END_8B, dllp1_checksum, int_dllp_data[31:0], `SDP_8B};

assign dllp_xmt_pkt_10b = int_dllp_xmt_pkt_10b[64*TX_NDLLP-1:0];



//  ---- Output Drives-------------------------
//
assign dllp_xmt_req     = int_dllp_xmt_req[TX_NDLLP-1:0];
assign dllp_xmt_pkt     = int_dllp_xmt_pkt[(64*TX_NDLLP)-1:0];

assign xdlh_rtlh_fc_ack = int_fc_req_ack;

// for pm module output
//always @(posedge core_clk or negedge core_rst_n)
//    if(!core_rst_n)
//        xdlh_nodllp_pending        <= #TP 0;
//    else
//        xdlh_nodllp_pending        <= #TP !int_acknak_req & !int_fc_req & !int_msg_req & !int_pm_req;

wire  nodllp_pending;
assign nodllp_pending        = !(ack_scheduled | (nak_scheduled & !nak_sent));

// following processes designed to generate the ACK/NACK dllp request
// The request is generated under following conditions:
// 1. when the requested ack sequence number over the last transmitted
// seqence number more than the programmed frequency number
// 2. when nak or duplicated requests arrived.
// 3. when ack/nak timer expired
// Currently the frequency is set to 1.
//

// This process is designed to latch the rdlh requests for sending ack or
// nak. The reason for latching the requests are due to the asynchronious
// interface between xdlh and rdlh regarding to ack/nak handshake

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        nak_scheduled               <= #TP 0;
        nak_sent                    <= #TP 0;
        ack_scheduled               <= #TP 0;
        ack_due2dup                 <= #TP 0;
        scheduled_acknak_seqnum_org <= #TP 12'hfff;
    end else if(!link_rdy4dllp) begin
        nak_scheduled               <= #TP 0;
        nak_sent                    <= #TP 0;
        ack_scheduled               <= #TP 0;
        ack_due2dup                 <= #TP 0;
        scheduled_acknak_seqnum_org <= #TP 12'hfff;
    end else begin
        if (rdlh_xdlh_req2send_ack & !rdlh_xdlh_req2send_ack_due2dup) begin
            nak_scheduled            <= #TP 0;
            nak_sent                 <= #TP 0;
        end else if (rdlh_xdlh_req2send_nack & (!nak_scheduled || (scheduled_acknak_seqnum_org != rdlh_xdlh_req_acknack_seqnum))) begin
            nak_scheduled            <= #TP 1'b1;
            nak_sent                 <= #TP 1'b0;
        end else if ( int_grant[3] & latch_outdata_en) begin
            nak_sent                 <= #TP nak_scheduled;
        end

        if (rdlh_xdlh_req2send_ack) begin
            ack_scheduled            <= #TP 1'b1;
            ack_due2dup              <= #TP rdlh_xdlh_req2send_ack_due2dup;
            scheduled_acknak_seqnum_org  <= #TP rdlh_xdlh_req_acknack_seqnum;
        end else if (rdlh_xdlh_req2send_nack & (!nak_scheduled || (scheduled_acknak_seqnum_org != rdlh_xdlh_req_acknack_seqnum))) begin
            ack_scheduled            <= #TP 1'b0;
            scheduled_acknak_seqnum_org  <= #TP rdlh_xdlh_req_acknack_seqnum;
        end else if ( (int_grant[3] & latch_outdata_en) | overwrite_latched_ack)begin
            // only when a ack or nak request is taken by arbitor
            // and there is no new request coming, we can clear the ack or
            // nak scheduled
            ack_scheduled            <= #TP 1'b0;
        end
    end

assign scheduled_acknak_seqnum = scheduled_acknak_seqnum_org ;

// Change symbol timer to common module
wire       timer2;


DWC_pcie_symbol_timer
 u_gen_timer2
(
     .core_clk          (core_clk)
    ,.core_rst_n        (core_rst_n)
    ,.cnt_up_en         (timer2)      // timer count-up
);


// following two processes are designed to have ack/nak timer timeout such
// that a request of ack/nak will be generated
// 1. when an ack has been scheduled, if we did not serve it due to the ack
    // frequence, then this timer is designed to force the ack request when
    // the ack has been scheduled so long. i.e, we have not received a new
    // TLP for a long time
// 2. Timer needs to be hold until ack has been served.
//always @(posedge core_clk or negedge core_rst_n)
//    if (!core_rst_n) begin
//        ack_timer               <= #TP 0;
//    end else if (!ack_scheduled | (int_grant[3] & latch_outdata_en)) begin
//        ack_timer               <= #TP 0;
//   end else if (ack_scheduled & !ack_timer_expired & !pm_freeze_ack_timer) begin
//`ifdef CX_FREQ_STEP_DL_EN
//        ack_timer               <= #TP ack_timer + (timer2 ? add_ack_timer : 0);
//`else //!CX_FREQ_STEP_DL_EN
//        ack_timer               <= #TP ack_timer + (timer2 ? 1 : 0);
//`endif //CX_FREQ_STEP_DL_EN
//    end

// If a stream of TLPs are received, the Ack latency check only holds true for the first one.
// Subsequent ones follow the table values in base spec Appendix H
//assign ack_latency_timer  = (phy_type == `PHY_TYPE_MPCIE) ?

// (cfg_ack_latency_timer > `CM_MPCIE_INTERNAL_DELAY) ? (cfg_ack_latency_timer - `CM_MPCIE_INTERNAL_DELAY) : (ack_timer==0) ? 16'h0000 : cfg_ack_latency_timer:
// (cfg_ack_latency_timer > `CX_CPCIE_INTERNAL_DELAY) ? (cfg_ack_latency_timer - `CX_CPCIE_INTERNAL_DELAY) : (ack_timer==0) ? 16'h0000 : cfg_ack_latency_timer;

//(ack_timer==0) ? (cfg_ack_latency_timer > `CM_MPCIE_INTERNAL_DELAY) ? (cfg_ack_latency_timer - `CM_MPCIE_INTERNAL_DELAY) : 16'h0000 : cfg_ack_latency_timer:
//(ack_timer==0) ? (cfg_ack_latency_timer > `CX_CPCIE_INTERNAL_DELAY) ? (cfg_ack_latency_timer - `CX_CPCIE_INTERNAL_DELAY) : 16'h0000 : cfg_ack_latency_timer;


// Depending on the state of the timer FSM, it can take up to 5 clock cycles from the reception of the TLP to ack_timer_expired being set
wire[15:0] cfg_ack_latency_timer_reduced = (cfg_ack_latency_timer > 5) ? cfg_ack_latency_timer - 6 : '0;
wire ack_timeout_greater_than_int_delay = (phy_type == `PHY_TYPE_MPCIE) ? ( (cfg_ack_latency_timer_reduced > `CM_MPCIE_INTERNAL_DELAY) ? 1'b1 : 1'b0 ) : ( (cfg_ack_latency_timer_reduced > `CX_CPCIE_INTERNAL_DELAY) ? 1'b1 : 1'b0 ); 

wire[15:0] ack_latency_timeout_value_before_ack = 
           (ack_timeout_greater_than_int_delay) ? 
           ((phy_type == `PHY_TYPE_MPCIE) ? (cfg_ack_latency_timer_reduced - `CM_MPCIE_INTERNAL_DELAY) : (cfg_ack_latency_timer_reduced - `CX_CPCIE_INTERNAL_DELAY)) :
           '0;
wire [15:0] ack_latency_timeout_value_after_ack = 
            (ack_timeout_greater_than_int_delay) ?   
            ((phy_type == `PHY_TYPE_MPCIE) ? (`CM_MPCIE_INTERNAL_DELAY) : (`CX_CPCIE_INTERNAL_DELAY)) : 
            (cfg_ack_latency_timer_reduced);

wire ack_timeout_expired_before_ack = ({{(16-`ACK_TIMER_WIDTH){1'b0}}, ack_timer} >= ack_latency_timeout_value_before_ack);
wire ack_timeout_expired_after_ack = ({{(16-`ACK_TIMER_WIDTH){1'b0}}, ack_timer} >= ack_latency_timeout_value_after_ack);

// Keep trace when an ACK is latched and transmitted. NAKs are not taken into account
always @(posedge core_clk or negedge core_rst_n)begin
    if(!core_rst_n)begin
        ack_latched <= #TP 1'b0;
        ack_transmitted <= #TP 1'b0;
    end else begin
        ack_transmitted <= #TP 1'b0;
        if(int_grant[3] & latch_outdata_en)begin
            ack_latched <= #TP ack_scheduled;
        end
        if(ack_latched & latch_outdata_en)begin
            ack_latched <= #TP int_grant[3] & ack_scheduled;
            ack_transmitted <= #TP 1'b1;
        end
    end
end


// The following FSM controls the ack_timer and the increase of priority of ACKs depending on the timer. 
// This FSM is independent from any other mechanism that can increase the ACK priority (e.g., ACK frequency).
// When in S_ACK_TIMER_HPRIO state, the priority of the ACK has been increased. When in IDLE or any WAIT_* state, the priority of 
// the ACK is left untouched (i.e., can be low or high).
// The FSM is based on the concept that, when a stream of inbound TLPs is received, we have to account for internal datapath
// delay only for the first ACK, while the following ones are fine thanks to the pipeline. Hence, for the first ACK we wait
// a reduced time (or no time at all if internal delay is greater than the configuration value). 
// The FSM breaks the timeout value in a time slice to wait before the priority of the ACK is increased and one after the priority is increased. 
// Basically, the first ACK to send in a stream waits a shorter time before entering HPRIO state where its priority is high, influenced by internal delay,
// while all the subsequent ACKs have to wait for the whole cfg_ack_latency_timeout before returning in HPRIO. 
// When in IDLE and HPRIO states, the ack_timer is reset, while it counts when in WAIT_* states.
// A particular case is when internal delay >= cfg_ack_latency_timeout. In this case, the WAIT_BEFORE_ACK is completely skipped and the priority is increased immediately (HPRIO). 
// However, after the ACK is sent, cfg_ack_latency_timeout must be waited before increasing the priority again, avoiding a continuous stream of ACKs.
// This mechanism guarantees that, between two priority increments, there is never less than cfg_ack_latency_timeout time.

typedef enum reg[1:0] {
                       S_ACK_TIMER_IDLE            = 2'b00,
                       S_ACK_TIMER_WAIT_BEFORE_ACK = 2'b01,
                       S_ACK_TIMER_HPRIO           = 2'b10,
                       S_ACK_TIMER_WAIT_AFTER_ACK  = 2'b11
                       }acktimer_state_e;
acktimer_state_e racktimer_curstate, sacktimer_nextstate;

always_ff @(posedge core_clk or negedge core_rst_n) begin : acktimer_fsm_seq_PROC
    if(!core_rst_n)begin
        racktimer_curstate <= #TP S_ACK_TIMER_IDLE;
    end else begin
        racktimer_curstate <= #TP sacktimer_nextstate;
    end
end : acktimer_fsm_seq_PROC

always_comb begin : acktimer_fsm_comb_PROC
    sacktimer_nextstate = racktimer_curstate;
    unique case(racktimer_curstate)
        S_ACK_TIMER_IDLE:  begin
            if(ack_scheduled || ack_latched)begin
                if(ack_timeout_greater_than_int_delay)begin
                    sacktimer_nextstate = S_ACK_TIMER_WAIT_BEFORE_ACK;
                end else begin
                    sacktimer_nextstate = S_ACK_TIMER_HPRIO;
                end
            end
        end

        S_ACK_TIMER_WAIT_BEFORE_ACK: begin
            if(ack_transmitted || nak_sent)begin
                sacktimer_nextstate = S_ACK_TIMER_IDLE;
            end else if(ack_timeout_expired_before_ack)begin
                sacktimer_nextstate = S_ACK_TIMER_HPRIO;
            end
        end

        S_ACK_TIMER_HPRIO: begin
            if(ack_transmitted || nak_sent)begin
                sacktimer_nextstate = S_ACK_TIMER_WAIT_AFTER_ACK;
            end 
        end

        default: begin //S_ACK_TIMER_WAIT_AFTER_ACK
            if(ack_timeout_expired_after_ack)begin
                sacktimer_nextstate = S_ACK_TIMER_IDLE;
            end
        end
    endcase
end : acktimer_fsm_comb_PROC


always_comb begin : ack_timer_expired_PROC
    ack_timer_expired = 1'b0;
    unique case(racktimer_curstate)
        S_ACK_TIMER_IDLE: begin
            ack_timer_expired = 1'b0;
        end
        S_ACK_TIMER_WAIT_BEFORE_ACK: begin
            ack_timer_expired = 1'b0;
        end
        S_ACK_TIMER_HPRIO: begin
            ack_timer_expired = 1'b1;
        end
        default: begin //S_ACK_TMER_WAIT_AFTER_ACK
            ack_timer_expired = 1'b0;
        end
    endcase
end : ack_timer_expired_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : ack_timer_counting_PROC
    if(!core_rst_n)begin
        ack_timer <= #TP '0;
    end else begin
        case(racktimer_curstate)
            S_ACK_TIMER_IDLE: begin
                ack_timer <= #TP '0;
            end
            S_ACK_TIMER_WAIT_BEFORE_ACK,
            S_ACK_TIMER_WAIT_AFTER_ACK: begin
                if(!pm_freeze_ack_timer)begin
                    ack_timer <= #TP ack_timer + (timer2 ? 1 : 0);
                end
            end 
            default: begin //S_ACK_TIMER_HPRIO
                ack_timer <= #TP '0;
            end
        endcase
    end 
end : ack_timer_counting_PROC

//always @(posedge core_clk or negedge core_rst_n)
//    if (!core_rst_n)
//        ack_timer_expired     <= #TP 0;
//    else
//        ack_timer_expired     <= #TP ({2'b0,ack_timer} > ack_latency_timer);

// This process is designed to generate ack nak request immediately under abnormal conditions :
// 1. when NACK is requested
// 2. when duplicated pkt received
// 3. When previously we have sent an nak and know we received the next
// tlp healthy. Therefore we want to send ack quickly to stop the retrains
// in the remote side. The previous_send_nak signal is latached, so we
// could use it

wire     ack_abnorm_req;
assign ack_abnorm_req = (ack_scheduled & ack_due2dup) | (ack_scheduled & !ack_due2dup & previous_send_nak);


reg[11:0] acknak_seqnum_delta;
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        acknak_seqnum_delta      <= #TP 0;
    end else if (rdlh_xdlh_req2send_ack & !rdlh_xdlh_req2send_ack_due2dup & int_grant[3] & latch_outdata_en) begin
        acknak_seqnum_delta      <= #TP 1;
    end else if (rdlh_xdlh_req2send_ack & !rdlh_xdlh_req2send_ack_due2dup) begin
        acknak_seqnum_delta      <= #TP acknak_seqnum_delta +1;
    end else if (int_grant[3] & latch_outdata_en) begin
        acknak_seqnum_delta      <= #TP 0;
    end

wire freq_gard_enable ;
assign freq_gard_enable = |cfg_ack_freq;

wire     ack_req4freq_expired;
assign   ack_req4freq_expired = freq_gard_enable & (acknak_seqnum_delta >= {4'b0,cfg_ack_freq});
// generate ack or nak request
assign int_acknak_req         = !int_acknack_disable
                                 & ((ack_scheduled & !ack_req_low_prior) | (nak_scheduled & !nak_sent));
assign int_acknack_disable    = cfg_acknack_disable
                              ;

assign ack_req_low_prior      = ack_scheduled & !(ack_req4freq_expired | ack_abnorm_req | (nak_scheduled & !nak_sent) | ack_timer_expired); 

// Calculate checksums
wire [15:0] tmp_dllp1_checksum;
assign tmp_dllp1_checksum  = crc16x32(int_dllp_data[31:0], 16'hFFFF);
assign dllp1_checksum_org       = ~flip16(tmp_dllp1_checksum);
wire [15:0] tmp_dllp2_checksum;
assign tmp_dllp2_checksum  = crc16x32(int_dllp_data[63:32], 16'hFFFF);
assign dllp2_checksum_org       = ~flip16(tmp_dllp2_checksum);




function automatic [15:0] crc16x32;
    input   [31:0] Data;
    input   [15:0]  CRC;

    reg     [31:0]  Data_flip;
begin
    Data_flip   = flip32(Data);                  
    crc16x32    = nextCRC16_D32(Data_flip, CRC); 
end

endfunction

  function automatic [15:0] nextCRC16_D32;

    input [31:0] Data;
    input [15:0] CRC;

    reg [31:0] D;
    reg [15:0] C;
    reg [15:0] NewCRC;

  begin

    D = Data;
    C = CRC;
    NewCRC = 16'h0000;

    NewCRC[0] = D[31] ^ D[29] ^ D[28] ^ D[26] ^ D[23] ^ D[21] ^ D[20] ^
                D[15] ^ D[13] ^ D[12] ^ D[8] ^ D[4] ^ D[0] ^ C[4] ^
                C[5] ^ C[7] ^ C[10] ^ C[12] ^ C[13] ^ C[15];
    NewCRC[1] = D[31] ^ D[30] ^ D[28] ^ D[27] ^ D[26] ^ D[24] ^ D[23] ^
                D[22] ^ D[20] ^ D[16] ^ D[15] ^ D[14] ^ D[12] ^ D[9] ^
                D[8] ^ D[5] ^ D[4] ^ D[1] ^ D[0] ^ C[0] ^ C[4] ^ C[6] ^
                C[7] ^ C[8] ^ C[10] ^ C[11] ^ C[12] ^ C[14] ^ C[15];
    NewCRC[2] = D[31] ^ D[29] ^ D[28] ^ D[27] ^ D[25] ^ D[24] ^ D[23] ^
                D[21] ^ D[17] ^ D[16] ^ D[15] ^ D[13] ^ D[10] ^ D[9] ^
                D[6] ^ D[5] ^ D[2] ^ D[1] ^ C[0] ^ C[1] ^ C[5] ^ C[7] ^
                C[8] ^ C[9] ^ C[11] ^ C[12] ^ C[13] ^ C[15];
    NewCRC[3] = D[31] ^ D[30] ^ D[25] ^ D[24] ^ D[23] ^ D[22] ^ D[21] ^
                D[20] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^ D[14] ^ D[13] ^
                D[12] ^ D[11] ^ D[10] ^ D[8] ^ D[7] ^ D[6] ^ D[4] ^
                D[3] ^ D[2] ^ D[0] ^ C[0] ^ C[1] ^ C[2] ^ C[4] ^ C[5] ^
                C[6] ^ C[7] ^ C[8] ^ C[9] ^ C[14] ^ C[15];
    NewCRC[4] = D[31] ^ D[26] ^ D[25] ^ D[24] ^ D[23] ^ D[22] ^ D[21] ^
                D[19] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^ D[14] ^ D[13] ^
                D[12] ^ D[11] ^ D[9] ^ D[8] ^ D[7] ^ D[5] ^ D[4] ^
                D[3] ^ D[1] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[5] ^ C[6] ^
                C[7] ^ C[8] ^ C[9] ^ C[10] ^ C[15];
    NewCRC[5] = D[27] ^ D[26] ^ D[25] ^ D[24] ^ D[23] ^ D[22] ^ D[20] ^
                D[19] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^ D[14] ^ D[13] ^
                D[12] ^ D[10] ^ D[9] ^ D[8] ^ D[6] ^ D[5] ^ D[4] ^
                D[2] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[6] ^ C[7] ^
                C[8] ^ C[9] ^ C[10] ^ C[11];
    NewCRC[6] = D[28] ^ D[27] ^ D[26] ^ D[25] ^ D[24] ^ D[23] ^ D[21] ^
                D[20] ^ D[19] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^ D[14] ^
                D[13] ^ D[11] ^ D[10] ^ D[9] ^ D[7] ^ D[6] ^ D[5] ^
                D[3] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[7] ^
                C[8] ^ C[9] ^ C[10] ^ C[11] ^ C[12];
    NewCRC[7] = D[29] ^ D[28] ^ D[27] ^ D[26] ^ D[25] ^ D[24] ^ D[22] ^
                D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[17] ^ D[16] ^ D[15] ^
                D[14] ^ D[12] ^ D[11] ^ D[10] ^ D[8] ^ D[7] ^ D[6] ^
                D[4] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^
                C[8] ^ C[9] ^ C[10] ^ C[11] ^ C[12] ^ C[13];
    NewCRC[8] = D[30] ^ D[29] ^ D[28] ^ D[27] ^ D[26] ^ D[25] ^ D[23] ^
                D[22] ^ D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[17] ^ D[16] ^
                D[15] ^ D[13] ^ D[12] ^ D[11] ^ D[9] ^ D[8] ^ D[7] ^
                D[5] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^
                C[7] ^ C[9] ^ C[10] ^ C[11] ^ C[12] ^ C[13] ^ C[14];
    NewCRC[9] = D[31] ^ D[30] ^ D[29] ^ D[28] ^ D[27] ^ D[26] ^ D[24] ^
                D[23] ^ D[22] ^ D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[17] ^
                D[16] ^ D[14] ^ D[13] ^ D[12] ^ D[10] ^ D[9] ^ D[8] ^
                D[6] ^ C[0] ^ C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^
                C[7] ^ C[8] ^ C[10] ^ C[11] ^ C[12] ^ C[13] ^ C[14] ^
                C[15];
    NewCRC[10] = D[31] ^ D[30] ^ D[29] ^ D[28] ^ D[27] ^ D[25] ^ D[24] ^
                 D[23] ^ D[22] ^ D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[17] ^
                 D[15] ^ D[14] ^ D[13] ^ D[11] ^ D[10] ^ D[9] ^ D[7] ^
                 C[1] ^ C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^ C[7] ^ C[8] ^
                 C[9] ^ C[11] ^ C[12] ^ C[13] ^ C[14] ^ C[15];
    NewCRC[11] = D[31] ^ D[30] ^ D[29] ^ D[28] ^ D[26] ^ D[25] ^ D[24] ^
                 D[23] ^ D[22] ^ D[21] ^ D[20] ^ D[19] ^ D[18] ^ D[16] ^
                 D[15] ^ D[14] ^ D[12] ^ D[11] ^ D[10] ^ D[8] ^ C[0] ^
                 C[2] ^ C[3] ^ C[4] ^ C[5] ^ C[6] ^ C[7] ^ C[8] ^ C[9] ^
                 C[10] ^ C[12] ^ C[13] ^ C[14] ^ C[15];
    NewCRC[12] = D[30] ^ D[28] ^ D[27] ^ D[25] ^ D[24] ^ D[22] ^ D[19] ^
                 D[17] ^ D[16] ^ D[11] ^ D[9] ^ D[8] ^ D[4] ^ D[0] ^
                 C[0] ^ C[1] ^ C[3] ^ C[6] ^ C[8] ^ C[9] ^ C[11] ^ C[12] ^
                 C[14];
    NewCRC[13] = D[31] ^ D[29] ^ D[28] ^ D[26] ^ D[25] ^ D[23] ^ D[20] ^
                 D[18] ^ D[17] ^ D[12] ^ D[10] ^ D[9] ^ D[5] ^ D[1] ^
                 C[1] ^ C[2] ^ C[4] ^ C[7] ^ C[9] ^ C[10] ^ C[12] ^
                 C[13] ^ C[15];
    NewCRC[14] = D[30] ^ D[29] ^ D[27] ^ D[26] ^ D[24] ^ D[21] ^ D[19] ^
                 D[18] ^ D[13] ^ D[11] ^ D[10] ^ D[6] ^ D[2] ^ C[2] ^
                 C[3] ^ C[5] ^ C[8] ^ C[10] ^ C[11] ^ C[13] ^ C[14];
    NewCRC[15] = D[31] ^ D[30] ^ D[28] ^ D[27] ^ D[25] ^ D[22] ^ D[20] ^
                 D[19] ^ D[14] ^ D[12] ^ D[11] ^ D[7] ^ D[3] ^ C[3] ^
                 C[4] ^ C[6] ^ C[9] ^ C[11] ^ C[12] ^ C[14] ^ C[15];

    nextCRC16_D32 = NewCRC;

  end

  endfunction

function automatic [31:0] flip32;
    input [31:0] d;

    integer bit_loc;
begin
    flip32 = 32'h0;
    for (bit_loc=0; bit_loc<32; bit_loc=bit_loc+1) flip32[bit_loc] = d[31-bit_loc];
end
endfunction

function automatic [15:0] flip16;
    input [15:0] d;

    integer bit_loc;
begin
    flip16 = 16'h0;
    for (bit_loc=0; bit_loc<16; bit_loc=bit_loc+1) flip16[bit_loc] = d[15-bit_loc];
end
endfunction


`ifndef SYNTHESIS
`endif // SYNTHESIS


endmodule
