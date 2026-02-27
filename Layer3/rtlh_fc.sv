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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_fc.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles flow control functions.
// --- Its main functions are:
// ---    (1) FC-Initialization state machine
// ---    (2) Generate FC status updates (upon requests from ADM and timer-based)
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rtlh_fc (
    // Inputs
    core_clk,
    core_rst_n,
    cfg_max_payload,
    cfg_ext_synch,
    cfg_vc_enable,
    cfg_upstream_port,
    cfg_vc_struc_vc_id_map,
    cfg_vc_id_vc_struc_map,
    cfg_fc_wdog_disable,
    cfg_fc_latency_value,
    cfg_fc_credit_ph,
    cfg_fc_credit_nph,
    cfg_fc_credit_cplh,
    cfg_fc_credit_pd,
    cfg_fc_credit_npd,
    cfg_fc_credit_cpld,
    smlh_in_l1,
    rdlh_rtlh_rcvd_dllp,
    rdlh_rtlh_dllp_content,
    rdlh_rtlh_link_state,
    xdlh_rtlh_fc_ack,
    radm_rtlh_ph_ca,
    radm_rtlh_pd_ca,
    radm_rtlh_nph_ca,
    radm_rtlh_npd_ca,
    radm_rtlh_cplh_ca,
    radm_rtlh_cpld_ca,
    rtcheck_rtfcgen_vc,
    rtcheck_rtfcgen_fctype,
    rtcheck_rtfcgen_incr_enable,
    rtcheck_rtfcgen_incr_amt,
    pm_freeze_fc_timer,
    xadm_all_type_infinite,
    current_data_rate,
    phy_type,
    smlh_in_l0_l0s,

    // Outputs
    rtlh_fc_init_status,
    rtlh_fc_init1_status,
    rtlh_xdlh_fc_req,
    rtlh_xdlh_fc_req_hi,
    rtlh_xdlh_fc_req_low,
    rtlh_xdlh_fc_data,
    rtlh_rfc_upd,
    rtlh_rfc_data,
    rtlh_crd_not_rtn,
    rtlh_req_link_retrain,
    rtfcgen_rtcheck_overfl_err,
    rtfcgen_ph_diff
);
parameter   INST       = 0;        // The uniquifying parameter for each port logic instance.
parameter   NL         = `CX_NL;   // Max number of lanes supported
parameter   NVC        = `CX_NVC;  // Number of virtual channels
parameter   NW         = `CX_NW;   // Number of 32-bit dwords handled by the datapath each clock.
parameter   NB         = `CX_NB;   // Number of bytes per cycle per lane
parameter   RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1; // Max number of DLLPs received per cycle
// parameter   TX_NDLLP   = ((NB >= 2) & (NW>=4)) ? 2 : 1;  // Max number of DLLPs send per cycle
parameter   TX_NDLLP   = 1;
parameter   TP         = `TP;      // Clock to Q delay (simulator insurance)

parameter   RX_TLP     = `CX_RX_TLP; // Number of TLPs that can be processed in a single cycle

parameter DCAW         = `CX_LOGBASE2(NW/4+1);     // Number of bits needed to represent the maximum number 
                                                   // of Data CA returned from the radm (512:3, 256:2, 128 or below:1)

localparam HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
localparam DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;
// -----------------------------------------------------------------------------
// --- Local Parameters
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// -------------------------------- Inputs -------------------------------------
// -----------------------------------------------------------------------------
input                   core_clk;                   // Core clock
input                   core_rst_n;                 // Core system reset
input   [2:0]           cfg_max_payload;
input                   cfg_ext_synch;              // This is added for FC update frequency
input                   cfg_upstream_port ;         // indicates that it is a upstream port of a down stream component
input   [NVC-1:0]       cfg_vc_enable;              // Which VCs are enabled (VC0 is always enabled)
input   [NVC*3-1:0]     cfg_vc_struc_vc_id_map;     // Map physical VC resource to VC identifier
input   [23:0]          cfg_vc_id_vc_struc_map;     // Index by vid, returns VC structure ID
input                   cfg_fc_wdog_disable;        // disable watch dog timer in FC for some debug purpose
input   [12:0]          cfg_fc_latency_value;       // Latency guideline from spec, based on current operating max payload
input   [(NVC*8)-1:0]   cfg_fc_credit_ph;           // Posted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]   cfg_fc_credit_nph;          // Nonposted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]   cfg_fc_credit_cplh;         // Completion header Wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]  cfg_fc_credit_pd;           // Posted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]  cfg_fc_credit_npd;          // Nonposted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]  cfg_fc_credit_cpld;         // Completion data wire to control the FC initial value for FC credit advertisement
input                   smlh_in_l1;             // 6 bit link width; 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1

input   [RX_NDLLP-1:0]  rdlh_rtlh_rcvd_dllp;        // When asserted, it indicates reception of DLLP packet(s)
input   [(32*RX_NDLLP)-1:0] rdlh_rtlh_dllp_content; // The received DLLP packet
input   [1:0]           rdlh_rtlh_link_state;       // RDLH link up FSM current state.
input                   xdlh_rtlh_fc_ack;           // When asserted, it indicates FC packet received
input   [3*RX_TLP-1:0]  rtcheck_rtfcgen_vc;         // Which Structure VC does current packet belong to
input   [2*RX_TLP-1:0]  rtcheck_rtfcgen_fctype;     // What type of packet (posted, nonposted, completion)
input   [RX_TLP-1:0]    rtcheck_rtfcgen_incr_enable;// Count headers going to application
input   [9*RX_TLP-1:0]  rtcheck_rtfcgen_incr_amt;   // Count payload going to application

input   [DCAW*NVC-1:0]  radm_rtlh_ph_ca;            // Credit allocated (posted header)
input   [DCAW*NVC-1:0]  radm_rtlh_pd_ca;            // Credit allocated (posted data)
input   [DCAW*NVC-1:0]  radm_rtlh_nph_ca;           // Credit allocated (non-posted header)
input   [DCAW*NVC-1:0]  radm_rtlh_npd_ca;           // Credit allocated (non-posted data)
input   [DCAW*NVC-1:0]  radm_rtlh_cplh_ca;          // Credit allocated (completion header)
input   [DCAW*NVC-1:0]  radm_rtlh_cpld_ca;          // Credit allocated (completion data)

input                   pm_freeze_fc_timer;         // power management request to freeze the timer
input                   xadm_all_type_infinite;     // XADM FC book keeping block indicates that remote link advertised all FC credits to infinite.
input   [2:0]           current_data_rate;          // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4

input                   phy_type;                   // Mac type
input                   smlh_in_l0_l0s;             // LTSSM is in L0 or L0s state

// -----------------------------------------------------------------------------
// -------------------------------- Outputs ------------------------------------
// -----------------------------------------------------------------------------

output  [NVC-1:0]       rtlh_fc_init_status;        // Set for each VC at completion of FCINIT1 and FCINIT2
output  [NVC-1:0]       rtlh_fc_init1_status;       // Set for each VC at completion of FCINIT1

output  [TX_NDLLP-1:0]  rtlh_xdlh_fc_req;           // Request to send a FCP
output                  rtlh_xdlh_fc_req_hi;        // Request to send a high-priority FCP that is higher than ACK/NACK
output                  rtlh_xdlh_fc_req_low;       // Request to send a low-priority FCP that is lower than TLP
output  [(32*TX_NDLLP)-1:0]  rtlh_xdlh_fc_data;     // Data associated with request

output  [RX_NDLLP-1:0]  rtlh_rfc_upd;               // Update Transmit credit information
output  [(32*RX_NDLLP)-1:0]  rtlh_rfc_data;         // 32bits FC update data
output  [NVC-1:0]       rtlh_crd_not_rtn;
output                  rtlh_req_link_retrain;
output  [RX_TLP-1:0]         rtfcgen_rtcheck_overfl_err;
output  [NVC*HCRD_WD-1:0]    rtfcgen_ph_diff;



// -----------------------------------------------------------------------------
// ----------------------------- Internal declaration --------------------------
// -----------------------------------------------------------------------------
//
// Local wires (per-VC status/control)
//
wire    [NVC-1:0]       rtfcarb_acks;
wire    [NVC-1:0]       rx_fc1_p;
wire    [NVC-1:0]       rx_fc1_np;
wire    [NVC-1:0]       rx_fc1_cpl;
wire    [NVC-1:0]       rx_fc2_p;
wire    [NVC-1:0]       rx_fc2_np;
wire    [NVC-1:0]       rx_fc2_cpl;
wire    [NVC-1:0]       rx_updt_p;
wire    [NVC-1:0]       rx_updt_np;
wire    [NVC-1:0]       rx_updt_cpl;
wire    [NVC-1:0]       rtfcgen_reqs;
wire    [NVC-1:0]       rtfcgen_reqs_hi;
wire    [(NVC*32)-1:0]  rtfcgen_data;
wire    [NVC-1:0]       rtfcgen_fcstate_in_upd_bus;
wire                    fc_update_timer_expired;
wire    [NVC-1:0]       rtlh_fc_init1_status;        // Set for each VC at completion of FCINIT

wire    [NVC*8-1:0]     int_rtfcgen_ph_diff;

// Decode incoming FCPs
rtlh_fc_decode

#(INST) u_rtlh_fc_decode (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_vc_id_vc_struc_map         (cfg_vc_id_vc_struc_map),
    .rdlh_rtlh_rcvd_dllp            (rdlh_rtlh_rcvd_dllp),
    .rdlh_rtlh_dllp_content         (rdlh_rtlh_dllp_content),
    .rdlh_rtlh_link_state           (rdlh_rtlh_link_state),
    .rtlh_fc_init1_status           (rtlh_fc_init1_status),
    // Outputs
    .rx_fc1_p                       (rx_fc1_p),
    .rx_fc1_np                      (rx_fc1_np),
    .rx_fc1_cpl                     (rx_fc1_cpl),
    .rx_fc2_p                       (rx_fc2_p),
    .rx_fc2_np                      (rx_fc2_np),
    .rx_fc2_cpl                     (rx_fc2_cpl),
    .rx_updt_p                      (rx_updt_p),
    .rx_updt_np                     (rx_updt_np),
    .rx_updt_cpl                    (rx_updt_cpl),
    .rx_rfc_upd                     (rtlh_rfc_upd),
    .rx_rfc_data                    (rtlh_rfc_data)
);

// Merge overflow error from all VCs
reg  [RX_TLP-1:0]     rtfcgen_rtcheck_overfl_err_rxtlp;
wire [NVC*RX_TLP-1:0] rtfcgen_rtcheck_overfl_err_vc;
always @(*) begin : merge_overfl_err_vc_into_rxtlp
    rtfcgen_rtcheck_overfl_err_rxtlp = 0;
    for(int fc_i=0; fc_i<NVC; fc_i++) begin
        rtfcgen_rtcheck_overfl_err_rxtlp = rtfcgen_rtcheck_overfl_err_rxtlp | rtfcgen_rtcheck_overfl_err_vc[fc_i*RX_TLP +: RX_TLP];
    end
end
assign rtfcgen_rtcheck_overfl_err = rtfcgen_rtcheck_overfl_err_rxtlp;


// Generate outgoing FCPs
genvar fc_gen;
generate
for(fc_gen = 0; fc_gen < NVC; fc_gen = fc_gen + 1) begin : gen_rtlh_fc
// rtlh_fc_gen instantiation for virtual channel fc_gen.
wire [2:0] cfg_struc_vc_id;
assign cfg_struc_vc_id = fc_gen[2:0];
rtlh_fc_gen

#(INST) u_rtlh_fc_gen (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_max_payload                (cfg_max_payload),
    .cfg_upstream_port              (cfg_upstream_port  ),
    .cfg_vc_id                      (cfg_vc_struc_vc_id_map[3*fc_gen +: 3]),
    .cfg_struc_vc_id                (cfg_struc_vc_id),
    .cfg_vc_enable                  (cfg_vc_enable[fc_gen*1 +: 1]),    
    .cfg_fc_credit_ph               (cfg_fc_credit_ph[fc_gen*8 +: 8]),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph[fc_gen*8 +: 8]),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh[fc_gen*8 +: 8]),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd[fc_gen*12 +: 12]),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd[fc_gen*12 +: 12]),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld[fc_gen*12 +: 12]),
    .smlh_in_l1                     (smlh_in_l1),
    .cfg_fc_latency_value           (cfg_fc_latency_value),
    .rtfcarb_ack                    (rtfcarb_acks[fc_gen]),
    .rdlh_rtlh_link_state           (rdlh_rtlh_link_state),
    .rtlh_fc_init_status            (rtlh_fc_init_status[fc_gen]),
    .fc_update_timer_expired        (fc_update_timer_expired),
    .pm_freeze_fc_timer             (pm_freeze_fc_timer),
    .radm_rtlh_ph_ca                (radm_rtlh_ph_ca[fc_gen*DCAW +: DCAW]),
    .radm_rtlh_pd_ca                (radm_rtlh_pd_ca[fc_gen*DCAW +: DCAW]),
    .radm_rtlh_nph_ca               (radm_rtlh_nph_ca[fc_gen*DCAW +: DCAW]),
    .radm_rtlh_npd_ca               (radm_rtlh_npd_ca[fc_gen*DCAW +: DCAW]),
    .radm_rtlh_cplh_ca              (radm_rtlh_cplh_ca[fc_gen*DCAW +: DCAW]),
    .radm_rtlh_cpld_ca              (radm_rtlh_cpld_ca[fc_gen*DCAW +: DCAW]),
    .rtcheck_rtfcgen_vc             (rtcheck_rtfcgen_vc),
    .rtcheck_rtfcgen_fctype         (rtcheck_rtfcgen_fctype),
    .rtcheck_rtfcgen_incr_enable    (rtcheck_rtfcgen_incr_enable),
    .rtcheck_rtfcgen_incr_amt       (rtcheck_rtfcgen_incr_amt),

    // Outputs
    .rtfcgen_fc_req                 (rtfcgen_reqs[fc_gen]),
    .rtfcgen_fc_req_hi              (rtfcgen_reqs_hi[fc_gen]),
    .rtfcgen_fc_data                (rtfcgen_data[fc_gen*32 +: 32]),
    .rtlh_crd_not_rtn               (rtlh_crd_not_rtn[fc_gen]),
    .rtfcgen_rtcheck_overfl_err     (rtfcgen_rtcheck_overfl_err_vc[fc_gen*RX_TLP +: RX_TLP]),
    .rtfcgen_ph_diff                (rtfcgen_ph_diff[fc_gen*HCRD_WD +: HCRD_WD])
);
end
endgenerate


// Arbitrate flow control reporting between the virtual channels
rtlh_fc_arb

#(INST) u_rtlh_fc_arb (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .rdlh_rtlh_link_state           (rdlh_rtlh_link_state),
    .xdlh_rtlh_fc_ack               (xdlh_rtlh_fc_ack),
    .cfg_vc_enable                  (cfg_vc_enable),
    .cfg_vc_struc_vc_id_map         (cfg_vc_struc_vc_id_map),
    .cfg_fc_wdog_disable            (cfg_fc_wdog_disable),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_fc_credit_ph               (cfg_fc_credit_ph),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld),
    .pm_freeze_fc_timer             (pm_freeze_fc_timer),
    .rx_fc1_p                       (rx_fc1_p),
    .rx_fc1_np                      (rx_fc1_np),
    .rx_fc1_cpl                     (rx_fc1_cpl),
    .rx_fc2_p                       (rx_fc2_p),
    .rx_fc2_np                      (rx_fc2_np),
    .rx_fc2_cpl                     (rx_fc2_cpl),
    .rx_updt_p                      (rx_updt_p),
    .rx_updt_np                     (rx_updt_np),
    .rx_updt_cpl                    (rx_updt_cpl),
    .rx_tlp                         (rtcheck_rtfcgen_incr_enable),
    .rx_vc                          (rtcheck_rtfcgen_vc),
    .current_data_rate              (current_data_rate),
    .phy_type                       (phy_type),
    .smlh_in_l0_l0s                 (smlh_in_l0_l0s),
    .rtfcgen_reqs                   (rtfcgen_reqs),
    .rtfcgen_reqs_hi                (rtfcgen_reqs_hi),
    .rtfcgen_data                   (rtfcgen_data),
    .rdlh_rtlh_rcvd_dllp            (rdlh_rtlh_rcvd_dllp),
    .xadm_all_type_infinite         (xadm_all_type_infinite),
    // Outputs
    .rtlh_fc_init_status            (rtlh_fc_init_status),
    .rtlh_fc_init1_status           (rtlh_fc_init1_status),
    .rtlh_req_link_retrain          (rtlh_req_link_retrain),
    .fc_update_timer_expired        (fc_update_timer_expired),
    .rtfcarb_acks                   (rtfcarb_acks),
    .rtlh_xdlh_fc_req               (rtlh_xdlh_fc_req),
    .rtlh_xdlh_fc_req_hi            (rtlh_xdlh_fc_req_hi),
    .rtlh_xdlh_fc_req_low           (rtlh_xdlh_fc_req_low),
    .rtlh_xdlh_fc_data              (rtlh_xdlh_fc_data)
);


endmodule
