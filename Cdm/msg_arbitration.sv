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
// ---    $DateTime: 2019/10/03 14:27:33 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/msg_arbitration.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module generates message TLP
// --- Note that no all messages are generatd for a specific application
// ---   msg_inta_asserted       (EP, BR)
// ---   msg_intb_asserted       (EP, BR)
// ---   msg_intc_asserted       (EP, BR)
// ---   msg_intd_asserted       (EP, BR)
// ---   msg_inta_deasserted     (EP, BR)
// ---   msg_intb_deasserted     (EP, BR)
// ---   msg_intc_deasserted     (EP, BR)
// ---   msg_intd_deasserted     (EP, BR)
// ---   msg_pm_as_nak           (RC, SW)
// ---   msg_pm_pme              (EP)
// ---   msg_pme_turnoff         (RC, SW)
// ---   msg_pme_toack           (EP, PR)
// ---   msg_err_cor             (EP, BR)
// ---   msg_err_nf              (EP, BR)
// ---   msg_err_f               (EP, BR)
// ---   msg_unlock              (RC, SW)
// ---   msg_set_slot_pwr_limit  (RC, SW)
// ---   msg_att_ind_on          (RC, SW)
// ---   msg_att_ind_blink       (RC, SW)
// ---   msg_att_ind_off         (RC, SW)
// ---   msg_pwr_ind_on          (RC, SW)
// ---   msg_pwr_ind_blink       (RC, SW)
// ---   msg_pwr_ind_off         (RC, SW)
// ---   msg_att_button_pressed  (EP, BR)
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module msg_arbitration (
// ---- inputs ---------------
    core_rst_n,
    core_clk,
    rdlh_link_up,
    pm_bus_num,
    pm_dev_num,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    device_type,
    pm_xtlh_block_tlp,

    pm_asnak,
    pm_pme,
    pme_turn_off,
    pme_to_ack,

    send_cor_err,
    send_nf_err,
    send_f_err,
    cfg_func_spec_err,

    unlock,

    inta_wire,
    intb_wire,
    intc_wire,
    intd_wire,
//    nhp_int,

    cfg_slot_pwr_limit_wr,
    cfg_auto_slot_pwr_lmt_dis,

//    hp_msi_request,
    cfg_bus_master_en,
    ven_msi_req,
    ven_msi_func_num,
    ven_msi_tc,
    ven_msi_vector,

    msg_xmt_grant,
    msi_xmt_grant,


    pm_dstate,



// ---- outputs ---------------
    msg_code,
    msg_fmt,
    msg_type,
    msg_req_id,
    msg_xmt_request,

    msi_func_num,

    msi_tc,
    msi_vector,
    msi_xmt_request,
    assert_inta_grt,
    assert_intb_grt,
    assert_intc_grt,
    assert_intd_grt,
    deassert_inta_grt,
    deassert_intb_grt,
    deassert_intc_grt,
    deassert_intd_grt,



    
    ven_msi_grant,
    pme_to_ack_grt,
    pme_turn_off_grt,
    pm_pme_grant
    ,
    pm_asnak_grt,
//    hp_msi_grant
    unlock_grt
);
parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
parameter NF            = `CX_NFUNC;            // number of functions
parameter PF_WD         = `CX_NFUNC_WD;         // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise
parameter BUSNUM_WD     = `CX_BUSNUM_WD;        // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD     = `CX_DEVNUM_WD;        // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.

input               core_rst_n;
input               core_clk;
input               rdlh_link_up;               // Layer 2 link up
input   [BUSNUM_WD-1:0] pm_bus_num;
input   [DEVNUM_WD-1:0] pm_dev_num;
input   [BUSNUM_WD-1:0] cfg_pbus_num;
input   [DEVNUM_WD-1:0] cfg_pbus_dev_num;
wire                    cfg_device_num_ari;
input   [3:0]       device_type;                // Device type
input               pm_xtlh_block_tlp;          // Block MSG & MSI.
// Power Management Message
input               pm_asnak;                   // PM Active State NAK (downstream)
input   [NF-1:0]    pm_pme;                     // PM PME (upstream)
input               pme_turn_off;               // PM Turn Off (broadcast downstream)
input   [NF-1:0]    pme_to_ack;                 // PM Turn Off ACK (upstream)
// Error Signaling Message
input   [NF-1:0]    send_cor_err;               // Correctable Error
input   [NF-1:0]    send_nf_err;                // Uncorrectable Non-Fatal Error
input   [NF-1:0]    send_f_err;                 // Uncorrectable Fatal Error
input [(3*NF)-1:0]  cfg_func_spec_err;          // indicates that the above errors are related with function specific
// Unlock Message
input               unlock;                     // Only for RC
// Interrupt Message
input               inta_wire;                  // INTA
input               intb_wire;                  // INTB
input               intc_wire;                  // INTC
input               intd_wire;                  // INTD
//input   [NF-1:0]    nhp_int;                    // from native hot plug logic - create an interrupt
// Slot Power Limit Message
input               cfg_slot_pwr_limit_wr;      // On a configuration write to the Slot Capabilities register of Down stream port
input   [NF-1:0]    cfg_auto_slot_pwr_lmt_dis;  // Auto Slot Power Limit Disable field of Slot Control Register; hardwired to 0 if DPC is not configured.
// MSI
input   [NF-1:0]    cfg_bus_master_en;          // Bus master enabled
//input   [NF-1:0]    hp_msi_request;             // Native hot plug logic - create an MSI
    // from App
input               ven_msi_req;                // Vendor MSI request
input   [PF_WD-1:0] ven_msi_func_num;         // Vendor MSI Function number


input  [(3*NF)-1:0] pm_dstate;                  // PF Power Management D-state 



input   [2:0]       ven_msi_tc;             // Vendor MSI TC
input   [4:0]       ven_msi_vector;         // Vendor MSI vector, used to modify the lower 5-bit msi_data

input               msg_xmt_grant;
input               msi_xmt_grant;

output  [7:0]       msg_code;
output  [1:0]       msg_fmt;
output  [4:0]       msg_type;
output  [15:0]      msg_req_id;
output              msg_xmt_request;            // pulse to XADM

output  [PF_WD-1:0] msi_func_num;             // MSI Function number
output  [2:0]       msi_tc;                     // MSI TC
output  [4:0]       msi_vector;                 // MSI vector, used to modify the lower 5-bit msi_data
output              msi_xmt_request;            // MSI request
output              assert_inta_grt;
output              assert_intb_grt;
output              assert_intc_grt;
output              assert_intd_grt;
output              deassert_inta_grt;
output              deassert_intb_grt;
output              deassert_intc_grt;
output              deassert_intd_grt;

output              ven_msi_grant;
output              pme_to_ack_grt;
output  [NF-1:0]    pm_pme_grant;
output              pme_turn_off_grt;
output              pm_asnak_grt; // PM_Active_State_Nak granted
output              unlock_grt;
//output  [NF-1:0]    hp_msi_grant;




reg     [7:0]    msg_code;
reg     [1:0]    msg_fmt;
reg     [4:0]    msg_type;
reg     [15:0]   msg_req_id;
reg                 msg_xmt_request;

wire    [PF_WD-1:0] msi_func_num;               // MSI Function number
wire    [2:0]       msi_tc;                     // MSI TC
wire    [4:0]       msi_vector;                 // MSI vector, used to modify the lower 5-bit msi_data
wire                msi_xmt_request;            // MSI request

reg     [30:0]      msg_sel_vector;
reg     [8:0]       msi_sel_vector;


// -----------------------------------------------------------------------------
// --- Internal Wires
// -----------------------------------------------------------------------------
wire                end_device;
assign end_device      = (device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY);
wire                rc_device;
assign rc_device       = (device_type == `PCIE_RC);
wire                bridge_device;
assign bridge_device   = (device_type == `PCIE_PCIX);
wire                pcie_sw_up;
assign pcie_sw_up      = (device_type == `PCIE_SW_UP);
wire                pcie_sw_down;
assign pcie_sw_down    = (device_type == `PCIE_SW_DOWN);
wire                upstream_port;
assign upstream_port   = end_device | bridge_device | pcie_sw_up;
wire                downstream_port;
assign downstream_port = rc_device | pcie_sw_down;

wire                assert_inta_req;
wire                assert_intb_req;
wire                assert_intc_req;
wire                assert_intd_req;
wire                deassert_inta_req;
wire                deassert_intb_req;
wire                deassert_intc_req;
wire                deassert_intd_req;
wire                pm_asnak_req;
wire                pm_pme_req;
wire                pm_pme_2nd_req;
wire                pm_vf_pme_req;
wire                pme_turn_off_req;
wire                pme_to_ack_req;
wire                send_cor_err_req;
wire                send_nf_err_req;
wire                send_f_err_req;
wire                send_vf_cor_err_req;
wire                send_vf_nf_err_req;
wire                send_vf_f_err_req;
wire                unlock_req;
wire                idle_req;
wire                obff_req;
wire                cpu_active_req;
wire                att_ind_on_req;
wire                att_ind_blink_req;
wire                att_ind_off_req;
wire                pwr_ind_on_req;
wire                pwr_ind_blink_req;
wire                pwr_ind_off_req;
wire                att_button_pressed_req;
wire                slot_pwr_limit_req;

reg                 att_ind_on_q;
reg                 att_ind_blink_q;
reg                 att_ind_off_q;
reg                 pwr_ind_on_q;
reg                 pwr_ind_blink_q;
reg                 pwr_ind_off_q;
reg                 att_button_pressed_q;
reg                 dl_up_q;
reg                 slot_msg_q;
reg                 send_pme_to_ack_q;
wire                send_pme_to_ack_assert;
wire                att_ind_blink_assert;
wire                att_ind_off_assert;
wire                pwr_ind_on_assert;
wire                pwr_ind_blink_assert;
wire                pwr_ind_off_assert;
wire                att_button_pressed_assert;
wire                slot_msg_assert;
reg     [NF-1:0]    int_pm_pme;
reg     [NF-1:0]    int_pme_to_ack;
reg     [NF-1:0]    int_send_cor_err;
reg     [NF-1:0]    int_send_nf_err;
reg     [NF-1:0]    int_send_f_err;
wire                 drs_req;
assign               drs_req = 1'b0;

wire                 frs_pf_req;
reg                  frs_pf_req_q;
wire                 frs_vf_req;
assign               frs_pf_req = 1'b0;

assign               frs_vf_req = 1'b0;


wire                 ptm_request_req;
wire                 ptm_res_req;
wire                 ptm_res_d_req;
assign               ptm_request_req = 1'b0;
assign               ptm_res_req = 1'b0;
assign               ptm_res_d_req = 1'b0;

assign cfg_device_num_ari = 1'b0;

// Order 0..n in decreasing priority (ie: ptm_res_d_req is highest):
wire    [30:0]       msg_req_vector; 
assign msg_req_vector = {
                                        frs_vf_req,          // 30
                                        frs_pf_req,          // 29
                                        drs_req,             // 28
                                        idle_req,            // 27
                                        obff_req,            // 26
                                        cpu_active_req,      // 25
                                        pm_pme_2nd_req,      // 24
                                        slot_pwr_limit_req,  // 23
                                        unlock_req,          // 22
                                        send_vf_f_err_req,   // 21
                                        send_f_err_req,      // 20
                                        send_vf_nf_err_req,  // 19
                                        send_nf_err_req,     // 18
                                        send_vf_cor_err_req, // 17
                                        send_cor_err_req,    // 16
                                        pme_to_ack_req,      // 15
                                        pme_turn_off_req,    // 14
                                        pm_vf_pme_req,       // 13
                                        pm_pme_req,          // 12
                                        pm_asnak_req,        // 11
                                        assert_intd_req,     // 10
                                        assert_intc_req,     // 9
                                        assert_intb_req,     // 8
                                        assert_inta_req,     // 7
                                        deassert_intd_req,   // 6
                                        deassert_intc_req,   // 5
                                        deassert_intb_req,   // 4
                                        deassert_inta_req,   // 3
                                        ptm_request_req,     // 2
                                        ptm_res_req,         // 1
                                        ptm_res_d_req        // 0
                                    };


wire deassert_inta_grt ;
wire deassert_intb_grt ;
wire deassert_intc_grt ;
wire deassert_intd_grt ;
wire assert_inta_grt   ;
wire assert_intb_grt   ;
wire assert_intc_grt   ;
wire assert_intd_grt   ;
wire pm_asnak_grt      ;
wire pme_turn_off_grt  ;
wire pme_to_ack_grt    ;
wire send_cor_err_grt  ;
wire send_nf_err_grt   ;
wire send_f_err_grt    ;
wire unlock_grt          ;
wire slot_pwr_limit_grt  ;
wire send_pm_asnak       ;
wire send_pm_pme         ;

wire send_pme_turn_off   ;

wire send_pme_to_ack     ;
wire send_cor_err_msg    ;
wire send_nf_err_msg     ;
wire send_f_err_msg      ;

wire send_unlock         ;
wire pm_pme_grt;

assign deassert_inta_grt       = msg_xmt_grant & msg_sel_vector[3];
assign deassert_intb_grt       = msg_xmt_grant & msg_sel_vector[4];
assign deassert_intc_grt       = msg_xmt_grant & msg_sel_vector[5];
assign deassert_intd_grt       = msg_xmt_grant & msg_sel_vector[6];
assign assert_inta_grt         = msg_xmt_grant & msg_sel_vector[7];
assign assert_intb_grt         = msg_xmt_grant & msg_sel_vector[8];
assign assert_intc_grt         = msg_xmt_grant & msg_sel_vector[9];
assign assert_intd_grt         = msg_xmt_grant & msg_sel_vector[10];
assign pm_asnak_grt            = msg_xmt_grant & msg_sel_vector[11];
assign pm_pme_grt              = msg_xmt_grant & msg_sel_vector[12];


assign pme_turn_off_grt        = msg_xmt_grant & msg_sel_vector[14];
assign pme_to_ack_grt          = msg_xmt_grant & msg_sel_vector[15];

assign send_cor_err_grt        = msg_xmt_grant & msg_sel_vector[16];
assign send_nf_err_grt         = msg_xmt_grant & msg_sel_vector[18];
assign send_f_err_grt          = msg_xmt_grant & msg_sel_vector[20];

assign unlock_grt              = msg_xmt_grant & msg_sel_vector[22];
assign slot_pwr_limit_grt      = msg_xmt_grant & msg_sel_vector[23];



// qualified by configuration
assign send_pm_asnak           = downstream_port & pm_asnak;
assign send_pm_pme             = upstream_port & |int_pm_pme;

assign send_pme_turn_off       = downstream_port & pme_turn_off;

assign send_pme_to_ack         = upstream_port & |int_pme_to_ack;
assign send_cor_err_msg        = upstream_port & |int_send_cor_err;
assign send_nf_err_msg         = upstream_port & |int_send_nf_err;
assign send_f_err_msg          = upstream_port & |int_send_f_err;

assign send_unlock             = downstream_port & unlock;
// inlcude the interrupt triggerd by native hot plug event
//wire                send_hp_int;
//assign send_hp_int             = upstream_port & |nhp_int;
wire send_inta_wire;
wire send_intb_wire;
wire send_intc_wire;
wire send_intd_wire;

assign send_inta_wire          = upstream_port & inta_wire & !pm_xtlh_block_tlp;
assign send_intb_wire          = upstream_port & intb_wire & !pm_xtlh_block_tlp;
assign send_intc_wire          = upstream_port & intc_wire & !pm_xtlh_block_tlp;
assign send_intd_wire          = upstream_port & intd_wire & !pm_xtlh_block_tlp;

wire [2:0] cfg_rc_func_num;
assign cfg_rc_func_num = `CX_RC_FUNC_NUM;

reg     [PF_WD-1:0]       func_num_pm_pme;
reg     [PF_WD-1:0]       func_num_pme_to_ack;
reg     [PF_WD-1:0]       func_num_err_cor;
reg     [PF_WD-1:0]       func_num_err_nf;
reg     [PF_WD-1:0]       func_num_err_f;
// Latch the multi-function message requests
wire    [PF_WD-1:0]       lowest_func_num_4cor_err;
wire    [PF_WD-1:0]       lowest_func_num_4nf_err;
wire    [PF_WD-1:0]       lowest_func_num_4f_err;
assign                    lowest_func_num_4cor_err    = get_lowest_func_index(send_cor_err);
assign                    lowest_func_num_4nf_err     = get_lowest_func_index(send_nf_err);
assign                    lowest_func_num_4f_err      = get_lowest_func_index(send_f_err);

reg   [NF-1:0] pm_pme_grant;
always @(*) begin : PME_GRANT
    integer i;
    pm_pme_grant = 0;
    for (i=0; i < NF; i=i+1) begin
// ccx_cond_begin: u_msg_gen.u_msg_arbitration ;;; Redundant code since func_num_pm_pme is 0 always, so equal to index i, for the config with CX_NFUNC = 1.
        if (pm_pme_grt && func_num_pm_pme == i) begin
// ccx_cond_end
            pm_pme_grant[i] = 1'b1;
        end
    end
end


always @(posedge core_clk or negedge core_rst_n)
begin : int_send_seq_PROC
    integer i;
    if (!core_rst_n) begin
        int_pm_pme          <= #TP 0;
        int_pme_to_ack      <= #TP 0;
        int_send_cor_err    <= #TP 0;
        int_send_nf_err     <= #TP 0;
        int_send_f_err      <= #TP 0;
    end
    else begin
        // we have clear over set since if we just transmitted one from this
        // function, it should not need to transmit another one immediately.
        for (i=0; i < NF; i=i+1) begin
            if (pm_pme_grt & (func_num_pm_pme == i))
                int_pm_pme[i]   <= #TP 1'b0;
            else if (pm_pme[i])
                int_pm_pme[i]   <= #TP 1'b1;
            if (pme_to_ack_grt & (func_num_pme_to_ack == i))
                int_pme_to_ack[i]   <= #TP 1'b0;
            else if (pme_to_ack[i])
                int_pme_to_ack[i]   <= #TP 1'b1;

            if (send_cor_err_grt & (func_num_err_cor == i))
                int_send_cor_err[i] <= #TP 1'b0;
            else if (send_cor_err[i] & (cfg_func_spec_err[i*3] | (( lowest_func_num_4cor_err == i) & !cfg_func_spec_err[i*3])))
                int_send_cor_err[i] <= #TP 1'b1;

            if (send_nf_err_grt & (func_num_err_nf == i))
                int_send_nf_err[i]  <= #TP 1'b0;
            else if (send_nf_err[i] & (cfg_func_spec_err[i*3+1] | ((lowest_func_num_4nf_err == i) & !cfg_func_spec_err[i*3+1])))
                int_send_nf_err[i]  <= #TP 1'b1;

            if (send_f_err_grt & (func_num_err_f == i))
                int_send_f_err[i]   <= #TP 1'b0;
            else if (send_f_err[i] & (cfg_func_spec_err[i*3+2] | (( lowest_func_num_4f_err == i) & !cfg_func_spec_err[i*3+2])))
                int_send_f_err[i]   <= #TP 1'b1;
        end
    end
end

//
// Pulse generation
//
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        send_pme_to_ack_q       <= #TP 0;
        dl_up_q                 <= #TP 0;
        slot_msg_q              <= #TP 0;
    end
    else begin
        send_pme_to_ack_q       <= #TP send_pme_to_ack;
        dl_up_q                 <= #TP rdlh_link_up;
        slot_msg_q              <= #TP cfg_slot_pwr_limit_wr;
    end
end

// Rising edge detection
assign send_pme_to_ack_assert       = ~send_pme_to_ack_q    & send_pme_to_ack;

// Latch function numbers
// Only applies to PM_PME, PME_TO_Ack, ERR_COR, ERR_NF, ERR_FATAL & Attention_Button_Pressed
// Need to figure out which function produces the above signal.  Lower function
// number gets priority if multiple happened at the same time.

//the coding style of the following blocks force the implicit else... do not score the implicit

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        func_num_pm_pme             <= #TP 0;
        func_num_pme_to_ack         <= #TP 0;
        func_num_err_cor            <= #TP 0;
        func_num_err_nf             <= #TP 0;
        func_num_err_f              <= #TP 0;
    end
    else begin 
      if (send_pm_pme               == 1'b1 && pm_pme_req       == 1'b0 )    func_num_pm_pme       <= #TP get_lowest_func_index(int_pm_pme);
      if (send_pme_to_ack_assert    == 1'b1 )                                func_num_pme_to_ack   <= #TP get_lowest_func_index(int_pme_to_ack);
      if (send_cor_err_msg          == 1'b1 && send_cor_err_req == 1'b0 )    func_num_err_cor      <= #TP get_lowest_func_index(int_send_cor_err);
      if (send_nf_err_msg           == 1'b1 && send_nf_err_req  == 1'b0 )    func_num_err_nf       <= #TP get_lowest_func_index(int_send_nf_err);
      if (send_f_err_msg            == 1'b1 && send_f_err_req   == 1'b0 )    func_num_err_f        <= #TP get_lowest_func_index(int_send_f_err);
    end
end





//set Slot power limit message under 2 conditions: (2.2.8.5 of 1.0a spec)
// 1.  DLL state from non-link up to link up state if cfg_auto_slot_pwr_lmt_dis (of function 0) is clear.
// 2.  A write to Slot Capabilities register while linked up
assign slot_msg_assert = (downstream_port & ((~dl_up_q & rdlh_link_up & ~cfg_auto_slot_pwr_lmt_dis[0]) |
                         (~slot_msg_q & cfg_slot_pwr_limit_wr & rdlh_link_up)))
                         ;

// -----------------------------------------------------------------------------
// Arbitrate around all message requests. Interrupt has higher priority
// than any other messages
// -----------------------------------------------------------------------------
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        msg_xmt_request <= #TP 0;
    else
        msg_xmt_request <= #TP msg_xmt_grant ? 0 : (msg_req_vector != 0) ? 1'b1 : msg_xmt_request;

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        msg_sel_vector  <= #TP 0;
    end else if (!msg_xmt_request | msg_xmt_grant) begin
        // take a snap shot at the request to grant the selection of
        // the next requests when there is no request pending or when
        // msg_xmt_grant asserted
        casez (msg_req_vector)
            31'b??????????????????????????????1:   msg_sel_vector <= #TP 31'b0000000000000000000000000000001; // ptm_res_d_req
            31'b?????????????????????????????10:   msg_sel_vector <= #TP 31'b0000000000000000000000000000010; // ptm_res_req
            31'b????????????????????????????100:   msg_sel_vector <= #TP 31'b0000000000000000000000000000100; // ptm_request_req
            31'b???????????????????????????1000:   msg_sel_vector <= #TP 31'b0000000000000000000000000001000; // deassert_inta_req
            31'b??????????????????????????10000:   msg_sel_vector <= #TP 31'b0000000000000000000000000010000; // deassert_intb_req  
            31'b?????????????????????????100000:   msg_sel_vector <= #TP 31'b0000000000000000000000000100000; // deassert_intc_req
            31'b????????????????????????1000000:   msg_sel_vector <= #TP 31'b0000000000000000000000001000000; // deassert_intd_req
            31'b???????????????????????10000000:   msg_sel_vector <= #TP 31'b0000000000000000000000010000000; // assert_inta_req
            31'b??????????????????????100000000:   msg_sel_vector <= #TP 31'b0000000000000000000000100000000; // assert_intb_req
            31'b?????????????????????1000000000:   msg_sel_vector <= #TP 31'b0000000000000000000001000000000; // assert_intc_req
            31'b????????????????????10000000000:   msg_sel_vector <= #TP 31'b0000000000000000000010000000000; // assert_intd_req
            31'b???????????????????100000000000:   msg_sel_vector <= #TP 31'b0000000000000000000100000000000; // pm_asnak_req
            31'b??????????????????1000000000000:   msg_sel_vector <= #TP 31'b0000000000000000001000000000000; // pm_pme_req
            31'b?????????????????10000000000000:   msg_sel_vector <= #TP 31'b0000000000000000010000000000000; // pm_vf_pme_req
            31'b????????????????100000000000000:   msg_sel_vector <= #TP 31'b0000000000000000100000000000000; // pme_turn_off_req
            31'b???????????????1000000000000000:   msg_sel_vector <= #TP 31'b0000000000000001000000000000000; // pme_to_ack_req
            31'b??????????????10000000000000000:   msg_sel_vector <= #TP 31'b0000000000000010000000000000000; // send_cor_err_req
            31'b?????????????100000000000000000:   msg_sel_vector <= #TP 31'b0000000000000100000000000000000; // send_vf_cor_err_req
            31'b????????????1000000000000000000:   msg_sel_vector <= #TP 31'b0000000000001000000000000000000; // send_nf_err_req
            31'b???????????10000000000000000000:   msg_sel_vector <= #TP 31'b0000000000010000000000000000000; // send_vf_nf_err_req
            31'b??????????100000000000000000000:   msg_sel_vector <= #TP 31'b0000000000100000000000000000000; // send_f_err_req
            31'b?????????1000000000000000000000:   msg_sel_vector <= #TP 31'b0000000001000000000000000000000; // send_vf_f_err_req
            31'b????????10000000000000000000000:   msg_sel_vector <= #TP 31'b0000000010000000000000000000000; // unlock_req
            31'b???????100000000000000000000000:   msg_sel_vector <= #TP 31'b0000000100000000000000000000000; // slot_pwr_limit_req
            31'b??????1000000000000000000000000:   msg_sel_vector <= #TP 31'b0000001000000000000000000000000; // pm_pme_2nd_req
            31'b?????10000000000000000000000000:   msg_sel_vector <= #TP 31'b0000010000000000000000000000000; // cpu_active_req
            31'b????100000000000000000000000000:   msg_sel_vector <= #TP 31'b0000100000000000000000000000000; // obff_req       
            31'b???1000000000000000000000000000:   msg_sel_vector <= #TP 31'b0001000000000000000000000000000; // idle_req       
            31'b??10000000000000000000000000000:   msg_sel_vector <= #TP 31'b0010000000000000000000000000000; // drs_req
            31'b?100000000000000000000000000000:   msg_sel_vector <= #TP 31'b0100000000000000000000000000000; // frs_pf_req
            31'b1000000000000000000000000000000:   msg_sel_vector <= #TP 31'b1000000000000000000000000000000; // frs_vf_req
            default:                               msg_sel_vector <= #TP 31'b000000000000000000000000000000;  // 
        endcase
    end
end

//
// MSG request logic
//




// Since hot plug interrupt = INTA, combined them together here.
//wire combo_inta;
//assign combo_inta = send_hp_int | send_inta_wire;

cdm_int_req

#(INST) u_inta_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
//    .int_wire           (combo_inta),
    .int_wire           (send_inta_wire),
    .assert_int_grt     (assert_inta_grt),
    .deassert_int_grt   (deassert_inta_grt),
    .cfg_int_disable    (1'b0),

    .assert_int_req     (assert_inta_req),
    .deassert_int_req   (deassert_inta_req)
);

cdm_int_req

#(INST) u_intb_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .int_wire           (send_intb_wire),
    .assert_int_grt     (assert_intb_grt),
    .deassert_int_grt   (deassert_intb_grt),
    .cfg_int_disable    (1'b0),

    .assert_int_req     (assert_intb_req),
    .deassert_int_req   (deassert_intb_req)
);

cdm_int_req

#(INST) u_intc_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .int_wire           (send_intc_wire),
    .assert_int_grt     (assert_intc_grt),
    .deassert_int_grt   (deassert_intc_grt),
    .cfg_int_disable    (1'b0),

    .assert_int_req     (assert_intc_req),
    .deassert_int_req   (deassert_intc_req)
);

cdm_int_req

#(INST) u_intd_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .int_wire           (send_intd_wire),
    .assert_int_grt     (assert_intd_grt),
    .deassert_int_grt   (deassert_intd_grt),
    .cfg_int_disable    (1'b0),

    .assert_int_req     (assert_intd_req),
    .deassert_int_req   (deassert_intd_req)
);



cdm_msg_req

#(INST) u0_cdm_msg_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .msg_event_pulse    (send_pm_asnak),
    .msg_grt            (pm_asnak_grt),

    .msg_req            (pm_asnak_req)
);



cdm_msg_req

#(INST) u1_cdm_msg_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .msg_event_pulse    (send_pm_pme),
    .msg_grt            (pm_pme_grt),

    .msg_req            (pm_pme_req)
);



cdm_msg_req

#(INST) u2_cdm_msg_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .msg_event_pulse    (send_pme_turn_off),
    .msg_grt            (pme_turn_off_grt),

    .msg_req            (pme_turn_off_req)
);



cdm_msg_req

#(INST) u3_cdm_msg_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .msg_event_pulse    (send_pme_to_ack_assert),
    .msg_grt            (pme_to_ack_grt),

    .msg_req            (pme_to_ack_req)
);

cdm_msg_req

#(INST) u4_cdm_msg_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .msg_event_pulse    (send_cor_err_msg),
    .msg_grt            (send_cor_err_grt),

    .msg_req            (send_cor_err_req)
);

cdm_msg_req

#(INST) u5_cdm_msg_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .msg_event_pulse    (send_nf_err_msg),
    .msg_grt            (send_nf_err_grt),

    .msg_req            (send_nf_err_req)
);

assign pm_pme_2nd_req = 0;

assign {send_vf_f_err_req, send_vf_nf_err_req, send_vf_cor_err_req} = 3'b0;

assign pm_vf_pme_req = 1'b0;

cdm_msg_req

#(INST) u6_cdm_msg_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .msg_event_pulse    (send_f_err_msg),
    .msg_grt            (send_f_err_grt),

    .msg_req            (send_f_err_req)
);



cdm_msg_req

#(INST) u7_cdm_msg_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .msg_event_pulse    (send_unlock),
    .msg_grt            (unlock_grt),

    .msg_req            (unlock_req)
);

cdm_msg_req

#(INST) u15_cdm_msg_req (
    .core_rst_n         (core_rst_n),
    .core_clk           (core_clk),
    .msg_event_pulse    (slot_msg_assert),
    .msg_grt            (slot_pwr_limit_grt),

    .msg_req            (slot_pwr_limit_req)
);

assign cpu_active_req = 1'b0;
assign idle_req       = 1'b0;
assign obff_req       = 1'b0;





// msg generation mux based on different type of message
// since the actual formation of TLP is designed in TLP align formation
// block. Here we just need to generate the necessary header fields for the
// TLP align formation block
//
always @(*) begin




    unique case (1'b1)

        // assert/deassert_inta/b/c/d
        |msg_sel_vector[10:3]: begin
            msg_code    = msg_sel_vector[3] ? `DEASSERT_INTA :
                          msg_sel_vector[4] ? `DEASSERT_INTB :
                          msg_sel_vector[5] ? `DEASSERT_INTC :
                          msg_sel_vector[6] ? `DEASSERT_INTD :
                          msg_sel_vector[7] ? `ASSERT_INTA :
                          msg_sel_vector[8] ? `ASSERT_INTB :
                          msg_sel_vector[9] ? `ASSERT_INTC :
                                              `ASSERT_INTD;

            msg_fmt     = 2'b01;
            msg_type    = 5'b10100;
            msg_req_id  = get_req_id(cfg_pbus_num, cfg_pbus_dev_num, {PF_WD{1'b0}}, cfg_device_num_ari, device_type);
        end
        // pm_asnak
        msg_sel_vector[11]: begin
            msg_code    = `PM_ACTIVE_STATE_NAK;
            msg_fmt     = 2'b01;
            msg_type    = 5'b10100;
            msg_req_id  = {cfg_pbus_num[7:0], cfg_pbus_dev_num[4:0], cfg_rc_func_num};
        end
        // pm_pme*
        msg_sel_vector[12]: begin
            msg_code    = `PM_PME;
            msg_fmt     = 2'b01;
            msg_type    = 5'b10000;
            msg_req_id  = get_req_id(pm_bus_num, pm_dev_num, func_num_pm_pme, cfg_device_num_ari, device_type);
        end


        // pme_turn_off
        msg_sel_vector[14]: begin
            msg_code    = `PME_TURN_OFF;
            msg_fmt     = 2'b01;
            msg_type    = 5'b10011;
            msg_req_id  = {cfg_pbus_num[7:0], cfg_pbus_dev_num[4:0], cfg_rc_func_num};
        end
        // pme_to_ack*
        msg_sel_vector[15]: begin
            msg_code    = `PME_TO_ACK;
            msg_fmt     = 2'b01;
            msg_type    = 5'b10101;
            msg_req_id  = get_req_id(cfg_pbus_num, cfg_pbus_dev_num, func_num_pme_to_ack, cfg_device_num_ari, device_type);
        end
        // send_cor_err*
        msg_sel_vector[16]: begin
            msg_code    = `ERR_COR;
            msg_fmt     = 2'b01;
            msg_type    = 5'b10000;
            msg_req_id  = get_req_id(cfg_pbus_num, cfg_pbus_dev_num, func_num_err_cor, cfg_device_num_ari, device_type);
        end
        // err_nonfatal*
        msg_sel_vector[18]: begin
            msg_code    = `ERR_NF;
            msg_fmt     = 2'b01;
            msg_type    = 5'b10000;
            msg_req_id  = get_req_id(cfg_pbus_num, cfg_pbus_dev_num, func_num_err_nf, cfg_device_num_ari, device_type);
        end
        // send_fatal_err*
        msg_sel_vector[20]: begin
            msg_code    = `ERR_F;
            msg_fmt     = 2'b01;
            msg_type    = 5'b10000;
            msg_req_id  = get_req_id(cfg_pbus_num, cfg_pbus_dev_num, func_num_err_f, cfg_device_num_ari, device_type);
        end


        // unlock
        msg_sel_vector[22]: begin
            msg_code    = `UNLOCK;
            msg_fmt     = 2'b01;
            msg_type    = 5'b10011;
            msg_req_id  = {cfg_pbus_num[7:0], cfg_pbus_dev_num[4:0], cfg_rc_func_num};
        end
        // Slot Power Limit Support (with payload)
        // payload will be appended at ADM
        msg_sel_vector[23]: begin
            msg_code    = `SET_SLOT_PWR_LIMIT;
            msg_fmt     = 2'b11;
            msg_type    = 5'b10100;
            msg_req_id  = {cfg_pbus_num[7:0], cfg_pbus_dev_num[4:0], cfg_rc_func_num};
        end


 



     default: begin
            msg_code    = 8'b0;
            msg_fmt     = 2'b01;
            msg_type    = 5'b10000;
            msg_req_id  = get_req_id(cfg_pbus_num, cfg_pbus_dev_num, {PF_WD{1'b0}}, cfg_device_num_ari, device_type);
        end
    endcase
end

// =============================================================================
// MSI
// =============================================================================

assign msi_xmt_request  = ven_msi_req & !pm_xtlh_block_tlp;
assign msi_func_num     = ven_msi_func_num;
assign msi_tc           = ven_msi_tc;
assign msi_vector       = ven_msi_vector;
assign ven_msi_grant    = msi_xmt_grant;


// =============================================================================
// Verilog Functions
// =============================================================================

 // Function to get Requester ID given function #
function automatic [15:0] get_req_id;
input [BUSNUM_WD-1:0]   bus_num;
input [DEVNUM_WD-1:0]   dev_num;
input [PF_WD-1:0]       func_num;
input                   cfg_device_num_ari;
input [3:0]             device_type;
integer i;

reg  [7:0]              int_bus_num;
reg  [4:0]              int_dev_num;
reg  [PF_WD-1:0]        int_func_num;
reg  [7:0]              func_num_8b;
begin
    int_bus_num = 0;
    int_dev_num = 0;
    int_func_num = 0;
    int_func_num[PF_WD-1:0] = func_num[PF_WD-1:0];
    func_num_8b = {{(8-PF_WD){1'b0}},func_num}; // drive at 0 most significant bits

    int_bus_num = bus_num[7:0];
    int_dev_num = dev_num[4:0];

    get_req_id = {int_bus_num, int_dev_num, func_num[2:0]};
end

endfunction // get_req_id

// Convert one-hot to function number
function automatic [PF_WD-1:0] get_lowest_func_index;
input   [NF-1:0]   one_hot_type;
integer i;
begin
    get_lowest_func_index = 0;

    for (i = NF-1; i>=0; i = i-1) begin
        if (one_hot_type[i] == 1'b1)
            get_lowest_func_index = i;
    end
end
endfunction

endmodule // msg_arbitration.v


/*

mb_081218:

msg_arbitration.v:
     __
____/  \__________     send_*[NF-1:0]
         _____________________
________/                     \___        int_send_*[NF-1:0]
         _____________________
________/                     \___     send_*_msg
            __________________
___________/                  \___     send_*_req -> req_vector[18:0]
                           ___
__________________________/   \___     send_*_grt

               __________________
______________/                  \___     sel_vector[18:0]
               _______________
______________/               \___     msg_xmt_request
                  ________
_________________/        \_______     msg_gen_hv -> to xadm
_______________________    ________
                       \__/         from xadm -> xadm_msg_halt
                           ___
__________________________/   \___     msg_xmt_grant


1. Single cycle send_*[NF-1:0] input commands are received by the arbitration
   block from each msg source: corr_err, nf_err, f_err, pm, int, ...
2. Commands are latched into int_send_*[NF-1:0] status flags.
   Each flag will remain set until the corresponding message is transmitted.
3. The flags for all PFs of a given source are OR-ed into a single bit send_*_msg flag, called "msg event", which is characteristic of the msg type.
   The VF flags are serialized into a single bit event with the aid of a free running counter. These events are single bit pulses.
4. Events are latched into "requests" send_*_req, which remain asserted until a message of the corresponding type is transmitted.
5. Requests for all msg types are assembled into a request vector: msg_req_vector[18:0].
6a. The OR of the request vector msg_xmt_request is sent to the msg_formation block which arbitrates between msg, msi and ven_msg and returns a grant when !xadm_msg_halt
   - xadm_msg_halt is generated by the xadm at the first opportunity after msg_hv from msg_gen is seen by the xadm arbiter.
     The xadm arbitrates between all the clients of the transmit side: external client0|1|2, internal completions and messages.
6b. The request vector is also used to select which message type to transmit first: this is done creating the one-hot msg_sel_vector from the multi-hot msg_req_vector with
    a fixed priority rule between the various message types.

7. msg_sel_vector[18:0] is used to construct the msg header according to the msg type, PF/VF info for the requester ID etc.
   - together with the received msg_xmt_grant, msg_sel_vector creates the grant for the message type that was sent: send_*_grt
   - this type specific grant is used to reset the int_send_* flag

8. The process continues requesting other grants until all flags are cleared.
*/
