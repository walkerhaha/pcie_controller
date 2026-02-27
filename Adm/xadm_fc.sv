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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/xadm_fc.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Provide flow control credit calculation.  FC can gate the transmission
// --- requests from client interfaces with insufficient credit.
// --- Request of any of the four interfaces will be granted according to the
// --- above priority only if the requested tlp consumed allowable credits. The
// --- all four interfaces here are order independent, any of the requests can
// --- by-pass others.
// ---
// --- For each client, back-2-back grants of same FC type are not allowed
// --- (due to pipeline delay)
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xadm_fc (
// ---- Inputs ----
    core_clk,
    core_rst_n,
    rstctl_core_flush_req,
    cfg_max_payload_size,
    cfg_tc_vc_map,
    cfg_vc_id,
    cfg_vc_enable,


    // Once a decision has been made, consume the credits
    active_grant,
    // In the event that we nullify the packet, we must restore credits
    restore_enable,
    restore_capture,
    restore_tc,
    restore_type,
    restore_word_len,

    rdlh_link_down,

    // Update packets from RTLH
    rtlh_rfc_upd,
    rtlh_rfc_data,
    rtlh_fc_init_status,

    // Client requests
    clients_tc,
    clients_type,
    clients_addr_offset,
    clients_byte_len,

// ----Outputs----
    fc_cds_pass,
    next_fc_cds_pass,
    next_credit_enough,
    next_2credit_enough,
    xadm_no_fc_credit,
    xadm_had_enough_credit,
    xadm_all_type_infinite,
    xadm_ph_cdts,
    xadm_pd_cdts,
    xadm_nph_cdts,
    xadm_npd_cdts,
    xadm_cplh_cdts,
    xadm_cpld_cdts


);
parameter INST      = 0;                            // The uniquifying parameter for each port logic instance.
parameter NCL       = `CX_NCLIENTS + 2;             // The number of clients vying for flow control, MAX supported=7
parameter NVC       = `CX_NVC;                      // The number of virtual channels supported
parameter NW        = `CX_NW;                       // The number of dwords per cycle
parameter NB        = `CX_NB;                       // The number of bytes per cycle per lane
parameter RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1; // Max number of DLLPs received
parameter TP        = `TP;                          // Clock to Q delay (simulator insurance)
parameter SPECIAL_MAX_CPL_CRD1 = `SPECIAL_MAX_CPL_CRD;
parameter SPECIAL_MAX_CPL_CRD_2 = SPECIAL_MAX_CPL_CRD1*2;
parameter NF        = `CX_NFUNC;                // Number of functions
parameter HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
parameter DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;

// -----------------------------------------------------------------------------
// --- Parameters
// -----------------------------------------------------------------------------
input                   core_clk;
input                   core_rst_n;
input                   rstctl_core_flush_req;
input   [2:0]           cfg_max_payload_size;
input   [23:0]          cfg_tc_vc_map;              // Index by TC, returns VC
input   [2:0]           cfg_vc_id;                  // VC identifier for this physical VC
input                   cfg_vc_enable;              // This VC is enabled


input   [NCL-1:0]       active_grant;

input                   restore_enable;
input                   restore_capture;
input   [2:0]           restore_tc;
input   [6:0]           restore_type;
input   [9:0]           restore_word_len;


input                   rdlh_link_down;

input   [RX_NDLLP-1:0]  rtlh_rfc_upd;
input                   rtlh_fc_init_status;
input   [32*RX_NDLLP-1:0]  rtlh_rfc_data;

input   [NCL*3-1:0]     clients_tc;
input   [NCL*7-1:0]     clients_type;
input   [NCL*2-1:0]     clients_addr_offset;
input   [NCL*13-1:0]    clients_byte_len;




output  [NCL-1:0]       fc_cds_pass;
output  [NCL-1:0]       next_fc_cds_pass;
output                  xadm_no_fc_credit;
output                  xadm_had_enough_credit;
output                  xadm_all_type_infinite;

output  [HCRD_WD-1:0]           xadm_ph_cdts;               // VC0 P header credits - Change to HCRD_WD
output  [DCRD_WD-1:0]          xadm_pd_cdts;               // VC0 P data credits - Change to DCRD_WD
output  [HCRD_WD-1:0]           xadm_nph_cdts;              // VC0 NP header credits - Change to HCRD_WD
output  [DCRD_WD-1:0]          xadm_npd_cdts;              // VC0 NP data credits - Change to DCRD_WD
output  [HCRD_WD-1:0]           xadm_cplh_cdts;             // VC0 CPL header credits - Change to HCRD_WD
output  [DCRD_WD-1:0]          xadm_cpld_cdts;             // VC0 CPL data credits - Change to DCRD_WD

output next_credit_enough;
output next_2credit_enough;




// Register outputs
reg                     xadm_no_fc_credit;
reg                     xadm_had_enough_credit;
wire                    xadm_all_type_inifinite;
wire    [3:0]           NVC_wire;
assign                  NVC_wire = NVC;



//
// Capture Updates from link partner and store in credit limit array
//

reg    [RX_NDLLP*12-1:0]          rtlh_rfc_upd_DATA;   // Remains 12 bits even with scaling since this is the data field from the DLLP
reg    [RX_NDLLP-1:0]             rtlh_rfc_upd_ENABLE;
reg    [RX_NDLLP-1:0]             rtlh_rfc_upd_FCI;
reg    [RX_NDLLP*2-1:0]           rtlh_rfc_upd_FCTYPE;
reg    [RX_NDLLP*8-1:0]           rtlh_rfc_upd_HDR; // Remains 8 bits even with scaling since this is the header field from the DLLP
reg    [RX_NDLLP*3-1:0]           rtlh_rfc_upd_VC;
always @(*) begin : DECODE_FC_UPDATES
    integer i;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        rtlh_rfc_upd_VC[i*3 +: 3]       = rtlh_rfc_data[i*32 +: 3];
        rtlh_rfc_upd_DATA[i*12 +: 12]   =
            {rtlh_rfc_data[i*32 + 16 +: 4],rtlh_rfc_data[i*32 + 24 +: 8]};
        rtlh_rfc_upd_ENABLE[i]          =
            cfg_vc_enable &&
            rtlh_rfc_upd_VC[i*3 +: 3] == cfg_vc_id &&
            rtlh_rfc_upd[i];
        rtlh_rfc_upd_FCI[i]             =
            rtlh_rfc_upd_ENABLE[i] && !(rtlh_rfc_data[i*32 + 6 +: 2] == 2'b10);
        rtlh_rfc_upd_FCTYPE[i*2 +: 2]   = rtlh_rfc_data[i*32 + 4 +: 2];
        rtlh_rfc_upd_HDR[i*8 +: 8]      =
            {rtlh_rfc_data[i*32 + 8 +: 6],rtlh_rfc_data[i*32 + 22 +: 2]};
    end
end

// Store current limit information
reg     [HCRD_WD-1:0]   limit_h_p, limit_h_np, limit_h_cpl;
reg     [DCRD_WD-1:0]   limit_d_p, limit_d_np, limit_d_cpl;
reg                     infinite_h_p, infinite_h_np, infinite_h_cpl;
reg                     infinite_d_p, infinite_d_np, infinite_d_cpl;

wire [1:0]              FCTYPE_client_0;
wire [1:0]              FCTYPE_client_1;
wire [1:0]              FCTYPE_client_2;
wire [1:0]              FCTYPE_client_3;

wire [8:0]              p_credits_requested_client_0;
wire [8:0]              p_credits_requested_client_1;
wire [8:0]              p_credits_requested_client_2;
wire [8:0]              p_credits_requested_client_3;

wire [8:0]              np_credits_requested_client_0;
wire [8:0]              np_credits_requested_client_1;
wire [8:0]              np_credits_requested_client_2;
wire [8:0]              np_credits_requested_client_3;

wire [8:0]              cpl_credits_requested_client_0;
wire [8:0]              cpl_credits_requested_client_1;
wire [8:0]              cpl_credits_requested_client_2;
wire [8:0]              cpl_credits_requested_client_3;

wire [8:0]              prev_credits_client_0;
wire [8:0]              prev_credits_client_1;
wire [8:0]              prev_credits_client_2;
wire [8:0]              prev_credits_client_3;

wire [1:0]              prev_fctype_client_0;
wire [1:0]              prev_fctype_client_1;
wire [1:0]              prev_fctype_client_2;
wire [1:0]              prev_fctype_client_3;


// Registers to capture the flow control update information
reg [RX_NDLLP-1:0]      advert_FCI;
reg [RX_NDLLP*HCRD_WD-1:0]    advert_HDR;
reg [RX_NDLLP*HCRD_WD-1:0]    int_advert_HDR;
reg [RX_NDLLP*DCRD_WD-1:0]   advert_DATA;
reg [RX_NDLLP*DCRD_WD-1:0]   int_advert_DATA;
reg [RX_NDLLP*2-1:0]    advert_FCTYPE;
reg [RX_NDLLP*3-1:0]    advert_VC;
wire [11:0]             int_max_plyd_cr;
wire [DCRD_WD-1:0]      int2_max_plyd_cr;
reg  [DCRD_WD-1:0]      max_payload_credits;

reg                     curnt_vc_rdy;  // to help on critical time area


reg  [RX_NDLLP*HCRD_WD-1:0]   advert_current_h;
reg  [RX_NDLLP*DCRD_WD-1:0]  advert_current_d;
reg  [RX_NDLLP*DCRD_WD-1:0]  advert_delta_d;
reg  [RX_NDLLP*HCRD_WD-1:0]   advert_delta_h;
wire                    restore_cpl;
wire                    restore_np;
wire                    restore_p;
reg                     update_add_cpl;
reg  [DCRD_WD-1:0]             update_add_cpl_d;
reg  [HCRD_WD-1:0]              update_add_cpl_h;
reg                     update_add_np;
reg  [DCRD_WD-1:0]             update_add_np_d;
reg  [HCRD_WD-1:0]              update_add_np_h;
reg                     update_add_p;
reg  [DCRD_WD-1:0]             update_add_p_d;
reg  [HCRD_WD-1:0]              update_add_p_h;

reg [1:0]               restore_fctype_r;
reg [8:0]               restore_amt_r;
wire [1:0]              restore_fctype;
wire [8:0]              restore_amt;
// amount of data credits to be returned due to nullified TLPs
// when RASDP is used and error mode is activated.
// solution assumes there is at most 1 SOT in each clock cycle and at most 2 EOTs
// when there is no RASDP, the following 3 signals are hardwired to 
// tmp_amt to be equivalent to the original credits handling logic
reg [9:0]               cpl_tmp_amt;
reg [9:0]               np_tmp_amt;
reg [9:0]               p_tmp_amt;
// deal with multiple TLPs being nullified in the same cycle
// situation can only occur when RASDP is used for those TLPs already 
// beyond xtlh_merge when ERROR mode is activated
// for non RASDP implementations, the following 3 signals are hardwired to 0
// to be equivalent to the original credits handling logic
wire                    np_hdr_inc;
wire                    cpl_hdr_inc;
wire                    p_hdr_inc;
wire                    consume_p;
wire                    consume_np;
wire                    consume_cpl;
reg [8:0]               consume_amt;

wire [NCL-1:0]          credit_enough_p;
wire [NCL-1:0]          credit_enough_np;
wire [NCL-1:0]          credit_enough_cpl;
wire [NCL-1:0]          credit_enough_p_pm;
wire [NCL-1:0]          credit_enough_np_pm;
wire [NCL-1:0]          credit_enough_cpl_pm;
wire [NCL-1:0]          int_credit_enough_np;

wire [NCL-1:0]          next_credit_enough_p;
wire [NCL-1:0]          next_credit_enough_np;
wire [NCL-1:0]          next_credit_enough_cpl;
wire [NCL-1:0]          next_2credit_enough_p;
wire [NCL-1:0]          next_2credit_enough_np;
wire [NCL-1:0]          next_2credit_enough_cpl;
wire [NCL-1:0]          next_credit_enough_p_pm;
wire [NCL-1:0]          next_credit_enough_np_pm;
wire [NCL-1:0]          next_credit_enough_cpl_pm;
wire [NCL-1:0]          int_next_credit_enough_np;
wire [NCL-1:0]          int_next_2credit_enough_np;

reg     [NCL-1:0]       int_next_credit_enough_cpl;
reg     [NCL-1:0]       int_next_2credit_enough_cpl;

reg     [NCL-1:0]       int_next_credit_enough_p;
reg     [NCL-1:0]       int_next_2credit_enough_p;

// Client Pullback - Needs update also for scaling

reg     [NCL-1:0]       int_credit_enough_cpl;

reg     [NCL-1:0]       int_credit_enough_p;

reg [HCRD_WD-1:0]               tmp_p_h;
reg [HCRD_WD-1:0]               tmp_np_h;
reg [HCRD_WD-1:0]               tmp_cpl_h;

wire [HCRD_WD-1:0]              p_h_restore_credit_adjust;
wire [HCRD_WD-1:0]              np_h_restore_credit_adjust;
wire [HCRD_WD-1:0]              cpl_h_restore_credit_adjust;
wire [HCRD_WD-1:0]              p_h_upd_adv_credit_adjust ;
wire [HCRD_WD-1:0]              np_h_upd_adv_credit_adjust;
wire [HCRD_WD-1:0]              cpl_h_upd_adv_credit_adjust;

reg [DCRD_WD-1:0]              tmp_p_d;
reg [DCRD_WD-1:0]              tmp_np_d;
reg [DCRD_WD-1:0]              tmp_cpl_d;

wire [DCRD_WD-1:0]             p_d_restore_credit_adjust;
wire [DCRD_WD-1:0]             np_d_restore_credit_adjust;
wire [DCRD_WD-1:0]             cpl_d_restore_credit_adjust;

wire [DCRD_WD-1:0]             p_d_upd_adv_credit_adjust;
wire [DCRD_WD-1:0]             np_d_upd_adv_credit_adjust;
wire [DCRD_WD-1:0]             cpl_d_upd_adv_credit_adjust;


wire [HCRD_WD-1:0]              avail_h_p_c;
wire [HCRD_WD-1:0]              avail_h_np_c;
wire [HCRD_WD-1:0]              avail_h_cpl_c;
wire [DCRD_WD-1:0]             avail_d_p_c;
wire [DCRD_WD-1:0]             avail_d_np_c;
wire [DCRD_WD-1:0]             avail_d_cpl_c;

reg [HCRD_WD-1:0]               avail_h_p, avail_h_np, avail_h_cpl;     // Credits available for header
reg [DCRD_WD-1:0]              avail_d_p, avail_d_np, avail_d_cpl;     // Credits available for data

wire next_credit_enough;
wire next_credit_enough_int;
wire next_2credit_enough; 
wire next_2credit_enough_int;

wire   [NCL-1:0]       int_active_grant;
assign int_active_grant = {NCL{~rstctl_core_flush_req}} & active_grant;

assign   next_credit_enough  =  next_credit_enough_int | (~cfg_vc_enable);
assign   next_2credit_enough = next_2credit_enough_int | (~cfg_vc_enable);


// rtlh block needs a signal to indicate that all types have been infinite
// credit so that it can disable the watch dog timer
//
assign xadm_all_type_infinite  =   (infinite_h_p   & infinite_d_p
                                    & infinite_h_np  & infinite_d_np
                                    & infinite_h_cpl & infinite_d_cpl);

// Internal registers to capture restore information (used when packets are nullified)
assign restore_fctype  = ((NVC==1) || (cfg_vc_enable & (get_vcnum_from_tcnum(restore_tc,cfg_tc_vc_map)==cfg_vc_id)))
                                           ? type_to_fctype(restore_type[6:5],restore_type[4:0])
                                           : 2'd3;    // Set type to invalid (3) if not our VC


  assign restore_amt     = (!restore_type[6]) ? 9'h000 : (restore_word_len == 10'h0) ? 9'h100 : (restore_word_len[9:2] + {8'h0,|restore_word_len[1:0]});






// Calculate the flow control type of the request being consumed
assign FCTYPE_client_0                  = type_to_fctype(clients_type[ 6: 5], clients_type[ 4: 0]);
assign FCTYPE_client_1                  = type_to_fctype(clients_type[13:12], clients_type[11: 7]);
assign FCTYPE_client_2                  = type_to_fctype(clients_type[20:19], clients_type[18:14]);
assign FCTYPE_client_3                  = type_to_fctype(clients_type[27:26], clients_type[25:21]);

// For each client, store the required credits for later consumption
assign prev_credits_client_0            = get_prev_credits(FCTYPE_client_0, clients_type[ 6], p_credits_requested_client_0, np_credits_requested_client_0, cpl_credits_requested_client_0);
assign prev_credits_client_1            = get_prev_credits(FCTYPE_client_1, clients_type[13], p_credits_requested_client_1, np_credits_requested_client_1, cpl_credits_requested_client_1);
assign prev_credits_client_2            = get_prev_credits(FCTYPE_client_2, clients_type[20], p_credits_requested_client_2, np_credits_requested_client_2, cpl_credits_requested_client_2);
assign prev_credits_client_3            = get_prev_credits(FCTYPE_client_3, clients_type[27], p_credits_requested_client_3, np_credits_requested_client_3, cpl_credits_requested_client_3);

assign prev_fctype_client_0             = ((NVC==1) || (cfg_vc_enable & (get_vcnum_from_tcnum(clients_tc[ 2:0],cfg_tc_vc_map) == cfg_vc_id)) )  ? FCTYPE_client_0 : 2'd3;
assign prev_fctype_client_1             = ((NVC==1) || (cfg_vc_enable & (get_vcnum_from_tcnum(clients_tc[ 5:3],cfg_tc_vc_map) == cfg_vc_id)) )  ? FCTYPE_client_1 : 2'd3;
assign prev_fctype_client_2             = ((NVC==1) || (cfg_vc_enable & (get_vcnum_from_tcnum(clients_tc[ 8:6],cfg_tc_vc_map) == cfg_vc_id)) )  ? FCTYPE_client_2 : 2'd3;
assign prev_fctype_client_3             = ((NVC==1) || (cfg_vc_enable & (get_vcnum_from_tcnum(clients_tc[11:9],cfg_tc_vc_map) == cfg_vc_id)) )  ? FCTYPE_client_3 : 2'd3;

localparam MSG_MSGD_TYPE = 3'b110;
assign p_credits_requested_client_0     = conv_byte_len_2_credits(clients_type[6] ,clients_byte_len[12: 0]);
assign p_credits_requested_client_1     = conv_byte_len_2_credits(clients_type[13],clients_byte_len[25:13]);
assign p_credits_requested_client_2     = conv_byte_len_2_credits(clients_type[20],clients_byte_len[38:26]);
assign p_credits_requested_client_3     = conv_byte_len_2_credits(clients_type[27],clients_byte_len[51:39]);
assign np_credits_requested_client_0    = conv_byte_len_2_credits(clients_type[6],clients_byte_len[12: 0]);
assign np_credits_requested_client_1    = conv_byte_len_2_credits(clients_type[13],clients_byte_len[25:13]);
assign np_credits_requested_client_2    = conv_byte_len_2_credits(clients_type[20],clients_byte_len[38:26]);
assign np_credits_requested_client_3    = conv_byte_len_2_credits(clients_type[27],clients_byte_len[51:39]);
assign cpl_credits_requested_client_0   = conv_byte_len_2_credits(clients_type[6] ,clients_byte_len[12: 0]);
assign cpl_credits_requested_client_1   = conv_byte_len_2_credits(clients_type[13],clients_byte_len[25:13]);
assign cpl_credits_requested_client_2   = conv_byte_len_2_credits(clients_type[20],clients_byte_len[38:26]);
assign cpl_credits_requested_client_3   = conv_byte_len_2_credits(clients_type[27],clients_byte_len[51:39]);




always @(int_active_grant
         or prev_credits_client_0
         or prev_credits_client_1
         or prev_credits_client_2
         or prev_credits_client_3
         )

begin : SEL_CONSUME_CREDIT

    case (int_active_grant)
        4'b0001 :       consume_amt     = prev_credits_client_0;
        4'b0010 :       consume_amt     = prev_credits_client_1;
        4'b0100 :       consume_amt     = prev_credits_client_2;
        4'b1000 :       consume_amt     = prev_credits_client_3;
        default :       consume_amt     = 0;
    endcase
end
//
// Process flow control updates from link partner
//

// Figure out if we need to update or not
reg [RX_NDLLP*2-1:0]    l_advert_FCTYPE;
always @(*) begin : UPDATE_FCTYPE
    integer i;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        l_advert_FCTYPE[i*2 +: 2] =
            rtlh_rfc_upd_ENABLE[i] ?
            rtlh_rfc_upd_FCTYPE[i*2 +: 2] : 2'h3;  // 3 means no update
    end
end

// Decode which type of update we have got.
reg [HCRD_WD-1:0] l_limit_h_p, l_limit_h_np, l_limit_h_cpl;
reg [DCRD_WD-1:0] l_limit_d_p, l_limit_d_np, l_limit_d_cpl;
reg               l_infinite_h_p, l_infinite_h_np, l_infinite_h_cpl;
reg               l_infinite_d_p, l_infinite_d_np, l_infinite_d_cpl;

// Higher valued DLLPs will take priority in the case of more than one FC DLLP
// of a particular type being received.
always @(*) begin : FC_DECODE
    integer i;
    l_limit_h_p         = limit_h_p;
    l_limit_d_p         = limit_d_p;
    l_limit_h_np        = limit_h_np;
    l_limit_d_np        = limit_d_np;
    l_limit_h_cpl       = limit_h_cpl;
    l_limit_d_cpl       = limit_d_cpl;

    l_infinite_h_p      = infinite_h_p;
    l_infinite_d_p      = infinite_d_p;
    l_infinite_h_np     = infinite_h_np;
    l_infinite_d_np     = infinite_d_np;
    l_infinite_h_cpl    = infinite_h_cpl;
    l_infinite_d_cpl    = infinite_d_cpl;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        l_limit_h_p         = (advert_FCTYPE[i*2 +: 2] == 2'h0) ?
            advert_HDR[i*HCRD_WD +: HCRD_WD] : l_limit_h_p;
        l_limit_d_p         = (advert_FCTYPE[i*2 +: 2] == 2'h0) ?
            advert_DATA[i*DCRD_WD +: DCRD_WD] : l_limit_d_p;
        l_limit_h_np        = (advert_FCTYPE[i*2 +: 2] == 2'h1) ?
            advert_HDR[i*HCRD_WD +: HCRD_WD] : l_limit_h_np;
        l_limit_d_np        = (advert_FCTYPE[i*2 +: 2] == 2'h1) ?
            advert_DATA[i*DCRD_WD +: DCRD_WD]: l_limit_d_np;
        l_limit_h_cpl       = (advert_FCTYPE[i*2 +: 2] == 2'h2) ?
            advert_HDR[i*HCRD_WD +: HCRD_WD] : l_limit_h_cpl;
        l_limit_d_cpl       = (advert_FCTYPE[i*2 +: 2] == 2'h2) ?
            advert_DATA[i*DCRD_WD +: DCRD_WD]: l_limit_d_cpl;

        // Check for infinite credit initialization
        l_infinite_h_p      =
            (advert_FCI[i] && advert_FCTYPE[i*2 +: 2] == 2'h0) ?
            (advert_HDR[i*HCRD_WD +: HCRD_WD] == {HCRD_WD{1'h0}}) : l_infinite_h_p;
        l_infinite_d_p      =
            (advert_FCI[i] && advert_FCTYPE[i*2 +: 2] == 2'h0) ?
            (advert_DATA[i*DCRD_WD +: DCRD_WD] == {DCRD_WD{1'h0}}) : l_infinite_d_p;
        l_infinite_h_np     =
            (advert_FCI[i] && advert_FCTYPE[i*2 +: 2] == 2'h1) ?
            (advert_HDR[i*HCRD_WD +: HCRD_WD] == {HCRD_WD{1'h0}}) : l_infinite_h_np;
        l_infinite_d_np     =
            (advert_FCI[i] && advert_FCTYPE[i*2 +: 2] == 2'h1) ?
            (advert_DATA[i*DCRD_WD +: DCRD_WD] == {DCRD_WD{1'h0}}) : l_infinite_d_np;
        l_infinite_h_cpl    =
            (advert_FCI[i] && advert_FCTYPE[i*2 +: 2] == 2'h2) ?
            (advert_HDR[i*HCRD_WD +: HCRD_WD] == {HCRD_WD{1'h0}}) : l_infinite_h_cpl;
        l_infinite_d_cpl    =
            (advert_FCI[i] && advert_FCTYPE[i*2 +: 2] == 2'h2) ?
            (advert_DATA[i*DCRD_WD +: DCRD_WD] == {DCRD_WD{1'h0}}) : l_infinite_d_cpl;
    end
end

// Get the credits advertised info from each DLLP and stripe it into
// int_advert_*. The DLLP values are always 8 (HDR) and 12(DATA) bits wide.
// The width of the int_advert_* and advert_* signals depends on FC scaling
// We must account for multiple DLLPs received in a cycle.
always @(*) begin : EXTRACT_ADV_FROM_DLLP
  integer i;
  int_advert_HDR = 0;
  int_advert_DATA = 0;
  for(i = 0; i < RX_NDLLP; i = i + 1) begin
    int_advert_HDR[i*HCRD_WD +: HCRD_WD]  =  rtlh_rfc_upd_HDR[i*8 +: 8];
    int_advert_DATA[i*DCRD_WD +: DCRD_WD] =  rtlh_rfc_upd_DATA[i*12 +: 12];
  end
end

always @(posedge core_clk or negedge core_rst_n)
begin : track_credit_limits
    if (!core_rst_n) begin
        advert_FCI             <= #TP {RX_NDLLP{1'b0}};
        advert_HDR             <= #TP {RX_NDLLP*HCRD_WD{1'h0}};
        advert_DATA            <= #TP {RX_NDLLP*DCRD_WD{1'h0}};
        advert_FCTYPE          <= #TP {RX_NDLLP{2'h3}};                    // Set a special flag indicating not valid
        advert_VC              <= #TP {RX_NDLLP{3'h0}};
        limit_h_p               <= #TP {HCRD_WD{1'b0}};
        limit_h_np              <= #TP {HCRD_WD{1'b0}};
        limit_h_cpl             <= #TP {HCRD_WD{1'b0}};
        limit_d_p               <= #TP {DCRD_WD{1'b0}};
        limit_d_np              <= #TP {DCRD_WD{1'b0}};
        limit_d_cpl             <= #TP {DCRD_WD{1'b0}};

        infinite_h_p            <= #TP 1'b0;
        infinite_d_p            <= #TP 1'b0;
        infinite_h_np           <= #TP 1'b0;
        infinite_d_np           <= #TP 1'b0;
        infinite_h_cpl          <= #TP 1'b0;
        infinite_d_cpl          <= #TP 1'b0;
    end else if (!cfg_vc_enable || rdlh_link_down) begin
        advert_FCI             <= #TP {RX_NDLLP{1'b0}};
        advert_HDR             <= #TP {RX_NDLLP*HCRD_WD{1'b0}};
        advert_DATA            <= #TP {RX_NDLLP*DCRD_WD{1'b0}};
        advert_FCTYPE          <= #TP {RX_NDLLP{2'h3}};                    // Set a special flag indicating not valid
        advert_VC              <= #TP {RX_NDLLP{3'h0}};

        limit_h_p               <= #TP {HCRD_WD{1'b0}};
        limit_h_np              <= #TP {HCRD_WD{1'b0}};
        limit_h_cpl             <= #TP {HCRD_WD{1'b0}};
        limit_d_p               <= #TP {DCRD_WD{1'b0}};
        limit_d_np              <= #TP {DCRD_WD{1'b0}};
        limit_d_cpl             <= #TP {DCRD_WD{1'b0}};

        infinite_h_p            <= #TP 1'b0;
        infinite_d_p            <= #TP 1'b0;
        infinite_h_np           <= #TP 1'b0;
        infinite_d_np           <= #TP 1'b0;
        infinite_h_cpl          <= #TP 1'b0;
        infinite_d_cpl          <= #TP 1'b0;
    end else begin

        advert_FCI             <= #TP rtlh_rfc_upd_FCI;
        advert_HDR             <= #TP int_advert_HDR;
        advert_DATA            <= #TP int_advert_DATA;
        advert_FCTYPE          <= #TP l_advert_FCTYPE;
        advert_VC              <= #TP rtlh_rfc_upd_VC;

        // Check to see if this VC and fctype are being updated
        // NOTE: higher DLLPs (if any) have priority
        limit_h_p               <= #TP l_limit_h_p;
        limit_d_p               <= #TP l_limit_d_p;
        limit_h_np              <= #TP l_limit_h_np;
        limit_d_np              <= #TP l_limit_d_np;
        limit_h_cpl             <= #TP l_limit_h_cpl;
        limit_d_cpl             <= #TP l_limit_d_cpl;

        // Check for infinite credit initialization
        infinite_h_p            <= #TP l_infinite_h_p;
        infinite_d_p            <= #TP l_infinite_d_p;
        infinite_h_np           <= #TP l_infinite_h_np;
        infinite_d_np           <= #TP l_infinite_d_np;
        infinite_h_cpl          <= #TP l_infinite_h_cpl;
        infinite_d_cpl          <= #TP l_infinite_d_cpl;
    end
end

//
// Create updates for each type of credit
//
always @(*) begin : CURRENT_CREDIT
    integer i;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        advert_current_h[i*HCRD_WD +: HCRD_WD] =
            (advert_FCTYPE[i*2 +: 2] == 2'b0) ? limit_h_p :
            (advert_FCTYPE[i*2 +: 2] == 2'b1) ? limit_h_np :
            limit_h_cpl;
        advert_current_d[i*DCRD_WD +: DCRD_WD] =
            (advert_FCTYPE[i*2 +: 2] == 2'b0) ? limit_d_p :
            (advert_FCTYPE[i*2 +: 2] == 2'b1) ? limit_d_np :
            limit_d_cpl;
    end
end

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Credit counters are intended to
// wrap without preseveration of carry/borrow
always @(*) begin : DELTA_CREDIT
    integer i;
    advert_delta_d = {RX_NDLLP*DCRD_WD{1'b0}};
    advert_delta_h = {RX_NDLLP*HCRD_WD{1'b0}};
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        advert_delta_d[i*DCRD_WD +: DCRD_WD] =
            advert_DATA[i*DCRD_WD +: DCRD_WD] - advert_current_d[i*DCRD_WD +: DCRD_WD];
        advert_delta_h[i*HCRD_WD +: HCRD_WD] =
            advert_HDR[i*HCRD_WD +: HCRD_WD] - advert_current_h[i*HCRD_WD +: HCRD_WD];
    end
end
// spyglass enable_block W164a

wire [8:0] tmp_amt;
// to serve the 128bit architecture with back2back single cycle tlp
assign tmp_amt          = restore_capture ? restore_amt : restore_amt_r;

assign cpl_hdr_inc      = 1'b0;
assign np_hdr_inc       = 1'b0;
assign p_hdr_inc        = 1'b0;

assign restore_cpl      = restore_enable & ((!restore_capture & (restore_fctype_r == 2'h2)) | (restore_capture & (restore_fctype == 2'h2)));
assign restore_np       = restore_enable & ((!restore_capture & (restore_fctype_r == 2'h1)) | (restore_capture & (restore_fctype == 2'h1)));
assign restore_p        = restore_enable & ((!restore_capture & (restore_fctype_r == 2'h0)) | (restore_capture & (restore_fctype == 2'h0)));

always @ (*)
begin: tmp_amt_noras_PROC
  cpl_tmp_amt = {1'b0, tmp_amt};
  np_tmp_amt  = {1'b0, tmp_amt};
  p_tmp_amt   = {1'b0, tmp_amt};
end

always @(*) begin : UPDATE_FC
    integer i;
    update_add_cpl = 0;
    update_add_cpl_d = advert_delta_d[0 +: DCRD_WD];
    update_add_cpl_h = advert_delta_h[0 +: HCRD_WD];
    update_add_np = 0;
    update_add_np_d = advert_delta_d[0 +: DCRD_WD];
    update_add_np_h = advert_delta_h[0 +: HCRD_WD];
    update_add_p = 0;
    update_add_p_d = advert_delta_d[0 +: DCRD_WD];
    update_add_p_h = advert_delta_h[0 +: HCRD_WD];
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        if(advert_FCTYPE[i*2 +: 2] == 2'h2) begin
            update_add_cpl      = 1;
            update_add_cpl_d    = advert_delta_d[i*DCRD_WD +: DCRD_WD];
            update_add_cpl_h    = advert_delta_h[i*HCRD_WD +: HCRD_WD];
        end
        if(advert_FCTYPE[i*2 +: 2] == 2'h1) begin
            update_add_np       = 1;
            update_add_np_d     = advert_delta_d[i*DCRD_WD +: DCRD_WD];
            update_add_np_h     = advert_delta_h[i*HCRD_WD +: HCRD_WD];
        end
        if(advert_FCTYPE[i*2 +: 2] == 2'h0) begin
            update_add_p        = 1;
            update_add_p_d      = advert_delta_d[i*DCRD_WD +: DCRD_WD];
            update_add_p_h      = advert_delta_h[i*HCRD_WD +: HCRD_WD];
        end
    end
end



// Calculate the consume amount

assign          consume_p      =  (int_active_grant[3] && (prev_fctype_client_3 == 2'b0))
                                 | (int_active_grant[2] && (prev_fctype_client_2 == 2'b0))
                                 | (int_active_grant[1] && (prev_fctype_client_1 == 2'b0))
                                 ;
                                 //| (int_active_grant[0] && (prev_fctype_client_0 == 2'b0));  // this interface can not generate P request
assign          consume_np     =  (int_active_grant[3] && (prev_fctype_client_3 == 2'b01))
                                 | (int_active_grant[2] && (prev_fctype_client_2 == 2'b01));
                                 //| (int_active_grant[1] && (prev_fctype_client_1 == 2'b01))  // this interface can not generate NP request
                                 //| (int_active_grant[0] && (prev_fctype_client_0 == 2'b01));  // this interface can not generate NP request
assign          consume_cpl    =  (int_active_grant[3] && (prev_fctype_client_3 == 2'b10))
                                 | (int_active_grant[2] && (prev_fctype_client_2 == 2'b10))
                                 | (int_active_grant[0] && (prev_fctype_client_0 == 2'b10));
                                 //| (int_active_grant[1] && (prev_fctype_client_1 == 2'b10))  // this interface can not generate CPL request
                                 //| (int_active_grant[0] && (prev_fctype_client_0 == 2'b10));
//
// Track credits available for transmissions
//


assign p_h_restore_credit_adjust               = ((restore_p)          ? (1'b1 + p_hdr_inc)      : 0);
assign np_h_restore_credit_adjust              = ((restore_np)         ? (1'b1 + np_hdr_inc)     : 0);
assign cpl_h_restore_credit_adjust             = ((restore_cpl)        ? (1'b1 + cpl_hdr_inc)    : 0);

assign p_h_upd_adv_credit_adjust               = ((update_add_p)       ? update_add_p_h          : 0);
assign np_h_upd_adv_credit_adjust              = ((update_add_np)      ? update_add_np_h         : 0);
assign cpl_h_upd_adv_credit_adjust             = ((update_add_cpl)     ? update_add_cpl_h        : 0);



// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Credit counters are intended to
// wrap without preseveration of carry/borrow
always @(posedge core_clk or negedge core_rst_n)
begin : REDUCE_HDR_CRD_ADDRS
    if (!core_rst_n) begin
        tmp_p_h          <= #TP 0;
        tmp_np_h         <= #TP 0;
        tmp_cpl_h        <= #TP 0;
    end else begin

        tmp_p_h         <= #TP
                           p_h_upd_adv_credit_adjust          + p_h_restore_credit_adjust;

        tmp_np_h        <= #TP
                           np_h_upd_adv_credit_adjust         +   np_h_restore_credit_adjust;


        tmp_cpl_h       <= #TP
                           cpl_h_upd_adv_credit_adjust        +  cpl_h_restore_credit_adjust;
    end
end
// spyglass enable_block W164a

assign    p_d_restore_credit_adjust               = ((restore_p)          ? {{(DCRD_WD-10){1'b0}},p_tmp_amt}               : 0);
assign    np_d_restore_credit_adjust              = ((restore_np)         ? {{(DCRD_WD-10){1'b0}},np_tmp_amt}              : 0);
assign    cpl_d_restore_credit_adjust             = ((restore_cpl)        ? {{(DCRD_WD-10){1'b0}},cpl_tmp_amt}             : 0);

assign    p_d_upd_adv_credit_adjust               = ((update_add_p)       ? update_add_p_d                 : 0);
assign    np_d_upd_adv_credit_adjust              = ((update_add_np)      ? update_add_np_d                : 0);
assign    cpl_d_upd_adv_credit_adjust             = ((update_add_cpl)     ? update_add_cpl_d               : 0);



// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Credit counters are intended to
// wrap without preseveration of carry/borrow
always @(posedge core_clk or negedge core_rst_n)
begin : REDUCE_DATA_CRD_ADDRS
    if (!core_rst_n) begin
        tmp_p_d       <= #TP 0;
        tmp_np_d      <= #TP 0;
        tmp_cpl_d     <= #TP 0;
    end else begin


        tmp_p_d         <= #TP
                           p_d_upd_adv_credit_adjust          + p_d_restore_credit_adjust;

        tmp_np_d        <= #TP
                           np_d_upd_adv_credit_adjust         +   np_d_restore_credit_adjust;


        tmp_cpl_d       <= #TP
                           cpl_d_upd_adv_credit_adjust        +  cpl_d_restore_credit_adjust;
    end
end
// spyglass enable_block W164a


// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Credit counters are intended to
// wrap without preseveration of carry/borrow
assign          avail_h_p_c     = avail_h_p   - consume_p   + tmp_p_h;
assign          avail_h_np_c    = avail_h_np  - consume_np  + tmp_np_h;
assign          avail_h_cpl_c   = avail_h_cpl - consume_cpl + tmp_cpl_h;

assign          avail_d_p_c     = avail_d_p   - (consume_p   ? ( consume_amt ) :{DCRD_WD{1'h0}}) + tmp_p_d;
assign          avail_d_np_c    = avail_d_np  - (consume_np  ? consume_amt      :{DCRD_WD{1'h0}}) + tmp_np_d;
assign          avail_d_cpl_c   = avail_d_cpl - (consume_cpl ? consume_amt      :{DCRD_WD{1'h0}}) + tmp_cpl_d;
// spyglass enable_block W164a

always @(posedge core_clk or negedge core_rst_n)
begin : TRACK_CREDITS_AVAILABLE
    if (!core_rst_n) begin
        avail_h_p       <= #TP {HCRD_WD{1'b0}};
        avail_d_p       <= #TP {DCRD_WD{1'b0}};
        avail_h_np      <= #TP {HCRD_WD{1'b0}};
        avail_d_np      <= #TP {DCRD_WD{1'b0}};
        avail_h_cpl     <= #TP {HCRD_WD{1'b0}};
        avail_d_cpl     <= #TP {DCRD_WD{1'b0}};
    end else if (!cfg_vc_enable || rdlh_link_down) begin
        avail_h_p       <= #TP {HCRD_WD{1'b0}};
        avail_d_p       <= #TP {DCRD_WD{1'b0}};
        avail_h_np      <= #TP {HCRD_WD{1'b0}};
        avail_d_np      <= #TP {DCRD_WD{1'b0}};
        avail_h_cpl     <= #TP {HCRD_WD{1'b0}};
        avail_d_cpl     <= #TP {DCRD_WD{1'b0}};
    end else begin
        avail_h_p       <= #TP avail_h_p_c;
        avail_d_p       <= #TP avail_d_p_c;
        avail_h_np      <= #TP avail_h_np_c;
        avail_d_np      <= #TP avail_d_np_c;
        avail_h_cpl     <= #TP avail_h_cpl_c;
        avail_d_cpl     <= #TP avail_d_cpl_c;
    end
end




//
// Calculate the pass fail credit check for each client
//
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        curnt_vc_rdy     <= #TP 0;
    else
        curnt_vc_rdy     <= #TP rtlh_fc_init_status & cfg_vc_enable;
end

// Bypass credit check when flush in progress
assign fc_cds_pass[0] = rstctl_core_flush_req ? 1'b1 : calculate_cds_pass(FCTYPE_client_0, curnt_vc_rdy, credit_enough_p[0], credit_enough_np[0], credit_enough_cpl[0] );
assign fc_cds_pass[1] = rstctl_core_flush_req ? 1'b1 : calculate_cds_pass(FCTYPE_client_1, curnt_vc_rdy, credit_enough_p[1], credit_enough_np[1], credit_enough_cpl[1] );
assign fc_cds_pass[2] = rstctl_core_flush_req ? 1'b1 : calculate_cds_pass(FCTYPE_client_2, curnt_vc_rdy, credit_enough_p[2], credit_enough_np[2], credit_enough_cpl[2] );
assign fc_cds_pass[3] = rstctl_core_flush_req ? 1'b1 : calculate_cds_pass(FCTYPE_client_3, curnt_vc_rdy, credit_enough_p[3], credit_enough_np[3], credit_enough_cpl[3] );

assign next_credit_enough_int  = (&next_credit_enough_p) && (&next_credit_enough_np) && (&next_credit_enough_cpl);
assign next_2credit_enough_int = (&next_2credit_enough_p) && (&next_2credit_enough_np) && (&next_2credit_enough_cpl);


assign next_fc_cds_pass[0] = calculate_cds_pass(FCTYPE_client_0, curnt_vc_rdy, next_credit_enough_p[0], next_credit_enough_np[0], next_credit_enough_cpl[0] );
assign next_fc_cds_pass[1] = calculate_cds_pass(FCTYPE_client_1, curnt_vc_rdy, next_credit_enough_p[1], next_credit_enough_np[1], next_credit_enough_cpl[1] );
assign next_fc_cds_pass[2] = calculate_cds_pass(FCTYPE_client_2, curnt_vc_rdy, next_credit_enough_p[2], next_credit_enough_np[2], next_credit_enough_cpl[2] );
assign next_fc_cds_pass[3] = calculate_cds_pass(FCTYPE_client_3, curnt_vc_rdy, next_credit_enough_p[3], next_credit_enough_np[3], next_credit_enough_cpl[3] );



// Capture information as packets are transferred to core, to support nullify operation (restore credits)
//
always @(posedge core_clk or negedge core_rst_n)
begin : capture_outgoing_packets
    if (!core_rst_n) begin
        restore_fctype_r    <= #TP 0;
        restore_amt_r       <= #TP 0;
    end else if (restore_capture) begin
        restore_fctype_r    <= #TP ((NVC==1) || (cfg_vc_enable & get_vcnum_from_tcnum(restore_tc,cfg_tc_vc_map)==cfg_vc_id)) ? restore_fctype : 2'd3;    // Set type to invalid (3) if not our VC
        restore_amt_r       <= #TP restore_amt;
    end
end

// Operating max payload size
assign int_max_plyd_cr = (12'h0_08 << cfg_max_payload_size) & 12'b0001_1111_1000;

generate if (DCRD_WD <= 12) 
 assign int2_max_plyd_cr = int_max_plyd_cr;
else 
 assign int2_max_plyd_cr = {{DCRD_WD-12{1'b0}}, int_max_plyd_cr};
endgenerate


always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        max_payload_credits <= #TP {DCRD_WD{1'b0}};
    else
        max_payload_credits <= #TP int2_max_plyd_cr;
end

//------------------------Start Next TLP  CREDIT_ENOUGH--------------------------------------------------------------
// number of NP data credits required - 0 padded to 12 bits to have comparisons using operands with the same width
reg [DCRD_WD-1:0] max_np_payload_credits;
// bus to hold 2*max_np_payload_credits - no need to increase bus width since maximum value for max_np_payload_credits can not be greater than 8
wire [DCRD_WD-1:0] double_max_np_payload_credits;
// aux wire to determine when NP data credits required are affect by atomic requests
wire valid_atomic_req;
// aux wire to determine when NP data credits required are affected by DMWr requests
wire valid_dmwr_req;

assign valid_atomic_req = 1'b0;
assign valid_dmwr_req   = 1'b0;

always @(*) begin : MAX_NP_PYLD_CRD
  max_np_payload_credits = {DCRD_WD{1'b0}};
  if(valid_dmwr_req) begin
    max_np_payload_credits[3:0] = (`CX_DEF_MEM_WR_LEN_SUPP == 0)? 4'd4 : 4'd8;
  end else if(valid_atomic_req) begin
    max_np_payload_credits[3:0] = 4'd2;
  end else begin
    max_np_payload_credits[3:0] = 4'd1;
  end
end : MAX_NP_PYLD_CRD
assign double_max_np_payload_credits = {max_np_payload_credits[DCRD_WD-2:0], 1'b0};

// parameter 9 bits narrow than DCRD_WD, value is 0
localparam [DCRD_WD-9-1:0] ZERO_PAD = {(DCRD_WD-9){1'b0}};

            always @(avail_d_p_c or avail_h_p_c or infinite_d_p or infinite_h_p
                     or p_credits_requested_client_0 or p_credits_requested_client_1
                     or p_credits_requested_client_2 or p_credits_requested_client_3 or max_payload_credits
                     )
            begin : calculate_p_credits_ok_next
                    int_next_credit_enough_p[0]   = ((avail_h_p_c > 'h01) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_0  }  + max_payload_credits));
                    int_next_credit_enough_p[1]   = ((avail_h_p_c > 'h01) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_1  }  + max_payload_credits));
                    int_next_credit_enough_p[2]   = ((avail_h_p_c > 'h01) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_2  }  + max_payload_credits));
                    int_next_credit_enough_p[3]   = ((avail_h_p_c > 'h01) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_3  }  + max_payload_credits));
                    int_next_2credit_enough_p[0]  = ((avail_h_p_c > 'h02) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_0  }  + max_payload_credits + max_payload_credits));
                    int_next_2credit_enough_p[1]  = ((avail_h_p_c > 'h02) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_1  }  + max_payload_credits + max_payload_credits));
                    int_next_2credit_enough_p[2]  = ((avail_h_p_c > 'h02) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_2  }  + max_payload_credits + max_payload_credits));
                    int_next_2credit_enough_p[3]  = ((avail_h_p_c > 'h02) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_3  }  + max_payload_credits + max_payload_credits));
            end
            assign next_credit_enough_p   = int_next_credit_enough_p;
            assign next_2credit_enough_p  = int_next_2credit_enough_p;

    assign int_next_credit_enough_np[0]    = ((avail_h_np_c  > 'h01) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= double_max_np_payload_credits));
    assign int_next_credit_enough_np[1]    = ((avail_h_np_c  > 'h01) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= double_max_np_payload_credits));
    assign int_next_credit_enough_np[2]    = ((avail_h_np_c  > 'h01) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= double_max_np_payload_credits));
    assign int_next_credit_enough_np[3]    = ((avail_h_np_c  > 'h01) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= double_max_np_payload_credits));
    assign int_next_2credit_enough_np[0]    = ((avail_h_np_c  > 'h02) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= 2 * double_max_np_payload_credits));
    assign int_next_2credit_enough_np[1]    = ((avail_h_np_c  > 'h02) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= 2 * double_max_np_payload_credits));
    assign int_next_2credit_enough_np[2]    = ((avail_h_np_c  > 'h02) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= 2 * double_max_np_payload_credits));
    assign int_next_2credit_enough_np[3]    = ((avail_h_np_c  > 'h02) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= 2 * double_max_np_payload_credits));
    assign next_credit_enough_np       = int_next_credit_enough_np;
    assign next_2credit_enough_np      = int_next_2credit_enough_np;


            always @(avail_d_cpl_c or avail_h_cpl_c or infinite_d_cpl or infinite_h_cpl
                     or cpl_credits_requested_client_0 or cpl_credits_requested_client_1
                     or cpl_credits_requested_client_2 or cpl_credits_requested_client_3 or max_payload_credits
                     )
            begin : calculate_cpl_credits_ok_next
                int_next_credit_enough_cpl[0]   = ((avail_h_cpl_c > 'h01) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_0 }  + max_payload_credits ));
                int_next_credit_enough_cpl[1]   = ((avail_h_cpl_c > 'h01) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_1 }  + max_payload_credits ));
                int_next_credit_enough_cpl[2]   = ((avail_h_cpl_c > 'h01) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_2 }  + max_payload_credits ));
                int_next_credit_enough_cpl[3]   = ((avail_h_cpl_c > 'h01) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_3 }  + max_payload_credits ));
                int_next_2credit_enough_cpl[0]   = ((avail_h_cpl_c > 'h02) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_0 }  + 2* max_payload_credits ));
                int_next_2credit_enough_cpl[1]   = ((avail_h_cpl_c > 'h02) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_1 }  + 2* max_payload_credits ));
                int_next_2credit_enough_cpl[2]   = ((avail_h_cpl_c > 'h02) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_2 }  + 2* max_payload_credits ));
                int_next_2credit_enough_cpl[3]   = ((avail_h_cpl_c > 'h02) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_3 }  + 2* max_payload_credits ));
            end
            assign next_credit_enough_cpl   = int_next_credit_enough_cpl;
            assign next_2credit_enough_cpl   = int_next_2credit_enough_cpl;




//------------------------------Finish Next TLP  CREDIT_ENOUGH ---------------------------------------------------------
    assign credit_enough_p_pm   = {NCL{((avail_h_p_c != 'h0) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= max_payload_credits))}};
            always @(avail_d_p_c or avail_h_p_c or infinite_d_p or infinite_h_p
                     or p_credits_requested_client_0 or p_credits_requested_client_1
                     or p_credits_requested_client_2 or p_credits_requested_client_3
                     )
            begin : calculate_p_credits_ok
                    int_credit_enough_p[0]   = ((avail_h_p_c != 'h0) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_0  }));
                    int_credit_enough_p[1]   = ((avail_h_p_c != 'h0) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_1  }));
                    int_credit_enough_p[2]   = ((avail_h_p_c != 'h0) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_2  }));
                    int_credit_enough_p[3]   = ((avail_h_p_c != 'h0) || infinite_h_p) & (infinite_d_p || (avail_d_p_c  >= {ZERO_PAD,p_credits_requested_client_3  }));
            end
            assign credit_enough_p   = int_credit_enough_p;

    assign int_credit_enough_np[0]    = ((avail_h_np_c  != 'h0) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= {ZERO_PAD, np_credits_requested_client_0}));
    assign int_credit_enough_np[1]    = ((avail_h_np_c  != 'h0) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= {ZERO_PAD, np_credits_requested_client_1}));
    assign int_credit_enough_np[2]    = ((avail_h_np_c  != 'h0) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= {ZERO_PAD, np_credits_requested_client_2}));
    assign int_credit_enough_np[3]    = ((avail_h_np_c  != 'h0) || infinite_h_np)  & (infinite_d_np  || (avail_d_np_c >= {ZERO_PAD, np_credits_requested_client_3}));
    assign credit_enough_np       = int_credit_enough_np;
    assign credit_enough_np_pm    = {NCL{((avail_h_np_c != 'h0) || infinite_h_np) & (infinite_d_np || (avail_d_np_c  >= max_np_payload_credits))}};
    assign credit_enough_cpl_pm   = {NCL{((avail_h_cpl_c != 'h0) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= max_payload_credits))}};
            always @(avail_d_cpl_c or avail_h_cpl_c or infinite_d_cpl or infinite_h_cpl
                     or cpl_credits_requested_client_0 or cpl_credits_requested_client_1
                     or cpl_credits_requested_client_2 or cpl_credits_requested_client_3
                     )
            begin : calculate_cpl_credits_ok
                int_credit_enough_cpl[0]   = ((avail_h_cpl_c != 'h0) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_0 } ));
                int_credit_enough_cpl[1]   = ((avail_h_cpl_c != 'h0) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_1 } ));
                int_credit_enough_cpl[2]   = ((avail_h_cpl_c != 'h0) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_2 } ));
                int_credit_enough_cpl[3]   = ((avail_h_cpl_c != 'h0) || infinite_h_cpl) & (infinite_d_cpl || (avail_d_cpl_c  >= {ZERO_PAD, cpl_credits_requested_client_3 } ));
            end
            assign credit_enough_cpl   = int_credit_enough_cpl;

always @(posedge core_clk or negedge core_rst_n)
begin : check_pm_credits
    if (!core_rst_n) begin
        xadm_no_fc_credit      <= #TP 0;
        xadm_had_enough_credit <= #TP 0;
    end else begin
        xadm_no_fc_credit      <= #TP (avail_h_p_c    == 'h0) & (!infinite_d_p   && (avail_d_p_c    == 'h0)) &&
                                      (avail_h_np_c   == 'h0) & (!infinite_d_np  && (avail_d_np_c   == 'h0)) &&
                                      (avail_h_cpl_c  == 'h0) & (!infinite_d_cpl && (avail_d_cpl_c  == 'h0));
        xadm_had_enough_credit <= #TP ((&credit_enough_p_pm) &&
            (&credit_enough_np_pm) &&(&credit_enough_cpl_pm)) || !cfg_vc_enable;
    end
end



wire [HCRD_WD-1:0] all_ones_h;
wire [DCRD_WD-1:0] all_ones_d;
assign all_ones_h = 8'hff;
assign all_ones_d = 12'hfff;

// Provide the following debug outputs for VC0
assign xadm_ph_cdts     = infinite_h_p   ? all_ones_h : avail_h_p;
assign xadm_nph_cdts    = infinite_h_np  ? all_ones_h : avail_h_np;
assign xadm_cplh_cdts   = infinite_h_cpl ? all_ones_h : avail_h_cpl;
assign xadm_pd_cdts     = infinite_d_p   ? all_ones_d : avail_d_p;
assign xadm_npd_cdts    = infinite_d_np  ? all_ones_d : avail_d_np;
assign xadm_cpld_cdts   = infinite_d_cpl ? all_ones_d : avail_d_cpl;

function automatic[2:0]  get_vcnum_from_tcnum;
    input [2:0]         tc;
    input [23:0]        tc_vc_map;
begin
    get_vcnum_from_tcnum = 3'b0;

    case (tc)
        3'b000: get_vcnum_from_tcnum = tc_vc_map[ 2: 0];
        3'b001: get_vcnum_from_tcnum = tc_vc_map[ 5: 3];
        3'b010: get_vcnum_from_tcnum = tc_vc_map[ 8: 6];
        3'b011: get_vcnum_from_tcnum = tc_vc_map[11: 9];
        3'b100: get_vcnum_from_tcnum = tc_vc_map[14:12];
        3'b101: get_vcnum_from_tcnum = tc_vc_map[17:15];
        3'b110: get_vcnum_from_tcnum = tc_vc_map[20:18];
        3'b111: get_vcnum_from_tcnum = tc_vc_map[23:21];
    endcase
end
endfunction


function automatic [8:0]  conv_byte_len_2_credits;
    input        has_payload;
    input [12:0] clients_byte_len;
    reg          align_adjust;
    reg [9:0]    credits;

begin
    align_adjust        = ( |clients_byte_len[3:0] );
    credits             = (clients_byte_len == 13'h0) ? 10'h001 : {1'b0, clients_byte_len[12:4]} + align_adjust ;
    conv_byte_len_2_credits     = has_payload ? credits[8:0] : 0;
end
endfunction

function automatic [8:0]  get_prev_credits;
    input [1:0] fc_type;
    input       packet_has_data;
    input [8:0] p_credits_req;
    input [8:0] np_credits_req;
    input [8:0] cpl_credits_req;
begin

    case(fc_type)
        2'h0 :      get_prev_credits    = packet_has_data ? p_credits_req   : 9'h0;
        2'h1 :      get_prev_credits    = packet_has_data ? np_credits_req  : 9'h0;
        2'h2 :      get_prev_credits    = packet_has_data ? cpl_credits_req : 9'h0;
        default :   get_prev_credits    = 9'h0;  // fc_type can only be 0,1,2
    endcase
end
endfunction

function automatic    calculate_cds_pass;
    input [1:0] fc_type;
    input       curnt_vc_rdy;
    input       credit_enough_p;
    input       credit_enough_np;
    input       credit_enough_cpl;
begin

    case(fc_type)
        2'h0 :   calculate_cds_pass =  credit_enough_p   & curnt_vc_rdy;
        2'h1 :   calculate_cds_pass =  credit_enough_np  & curnt_vc_rdy;
        2'h2 :   calculate_cds_pass =  credit_enough_cpl & curnt_vc_rdy;
     default :   calculate_cds_pass = 0; // fc_type can only be 0,1,2
    endcase
end
endfunction



// This function converts the 7 bits of type and format from the TLP header to flow control types (P=0, NP=1, CPL=2)
// NOTE: There is no error checking
function automatic   [1:0]   type_to_fctype;
    input   [1:0]   fmt;
    input   [4:0]   pkt_type;

    type_to_fctype =
                        (pkt_type[4])    ? `P_TYPE     :   // Message
                        (&pkt_type[3:2]) ? `NP_TYPE    :   // Atomic
                        (pkt_type[3])    ? `CPL_TYPE   :   // Completion
                        (pkt_type[2])    ? `NP_TYPE    :   // Configuration
                        (pkt_type[1])    ? `NP_TYPE    :   // IO
                        (!fmt[1])        ? `NP_TYPE    :   // Memory Read
                                           `P_TYPE;        // Memory Write
endfunction


endmodule
