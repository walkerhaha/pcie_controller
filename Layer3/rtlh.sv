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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles receive transaction Layer. Its main functions are:
//     (1) TLP Extract and alignment from DLLP interface
//     (2) Flow Control Tracking/messaging
//     (3) TLP header snoop and malform TLP checks that are required from
//     spec.
//     (4) ECRC strip off and error check , ECRC enable `define can reduce
//     the latency and save the gates if ECRC is not desired
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rtlh (
    // Inputs
    core_clk,
    core_rst_n,
    cfg_endpoint,
    cfg_root_compx,
    cfg_upstream_port,
    cfg_max_payload,
    cfg_fc_latency_value,
    cfg_ext_synch,
    cfg_vc_enable,
    cfg_vc_struc_vc_id_map,
    cfg_vc_id_vc_struc_map,
    cfg_tc_struc_vc_map,
    cfg_tc_enable,
    cfg_fc_wdog_disable,
    cfg_fc_credit_ph,
    cfg_fc_credit_nph,
    cfg_fc_credit_cplh,
    cfg_fc_credit_pd,
    cfg_fc_credit_npd,
    cfg_fc_credit_cpld,
    smlh_in_l1    ,
    rdlh_rtlh_data,
    rdlh_rtlh_sot,
    rdlh_rtlh_eot,
    rdlh_rtlh_dv,
    rdlh_rtlh_abort,
    rdlh_rtlh_rcvd_dllp,
    rdlh_rtlh_dllp_content,
    rdlh_rtlh_link_state,
    radm_rtlh_ph_ca,
    radm_rtlh_pd_ca,
    radm_rtlh_nph_ca,
    radm_rtlh_npd_ca,
    radm_rtlh_cplh_ca,
    radm_rtlh_cpld_ca,
    xdlh_rtlh_fc_ack,
    xadm_all_type_infinite,
    // inputs from pm module
    pm_freeze_fc_timer,
    current_data_rate,

    phy_type,
    smlh_in_l0_l0s,


    // Outputs
    rtlh_parerr,
    rtlh_rdlh_fci1_fci2,
    rtlh_xdlh_fc_req,
    rtlh_xdlh_fc_req_hi,
    rtlh_xdlh_fc_req_low,
    rtlh_xdlh_fc_data,
    rtlh_rfc_upd,
    rtlh_rfc_data,
    rtlh_radm_data,
    rtlh_radm_dwen,
    rtlh_radm_hdr,
    rtlh_radm_hv,
    rtlh_radm_dv,
    rtlh_radm_eot,
    rtlh_radm_malform_tlp_err,
    rtlh_radm_ecrc_err,
    rtlh_radm_dllp_err,
    rtlh_radm_ant_addr,
    rtlh_radm_ant_rid,
    rtlh_radm_pending,
    rtlh_fc_init_status,
    rtlh_crd_not_rtn,
    rtlh_req_link_retrain,
    rtfcgen_ph_diff_vc0,
    rtlh_overfl_err
);
parameter   INST        = 0;                              // The uniquifying parameter for each port logic instance.
parameter   NVC         = `CX_NVC;                        // Number of virtual channels
parameter   NW          = `CX_NW;                         // Number of 32-bit dwords handled by the datapath each clock.
parameter   NB          = `CX_NB;                         // Number of bytes per cycle.
parameter   NF          = `CX_NFUNC;                      // Number of functions
parameter   DW          = (32*NW);                        // Width of datapath in bits.
parameter   TP          = `TP;                            // Clock to Q delay (simulator insurance)
parameter   RX_NDLLP    = (NW>>1 == 0) ? 1 : NW>>1;       // Max number of DLLPs received per cycle
parameter   TX_NDLLP    = 1;                              // Max number of DLLPs send per cycle
parameter   DATA_PAR_WD = `TRGT_DATA_PROT_WD ;               // data bus parity width
parameter   RAS_PCIE_HDR_PROT_WD  = `CX_RAS_PCIE_HDR_PROT_WD;

parameter TW = 3;               // Number of bits of tag information to use for lookup
parameter FW = 3;               // Number of bits for function ID
parameter WD = 12 + 2 + 3;      // Width of completion entry (length, attribute, Traffic Class)
parameter RX_TLP = `CX_RX_TLP;  // Number of TLPs that can be processed in a single cycle
parameter HW_W_PAR = RX_TLP*(128+RAS_PCIE_HDR_PROT_WD);
parameter DW_W_PAR = DW+DATA_PAR_WD;
parameter DCAW         = `CX_LOGBASE2(NW/4+1);     // Number of bits needed to represent the maximum number 
                                                   // of Data CA returned from the radm (512:3, 256:2, 128 or below:1)
                                                   
localparam HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
localparam DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;



// -------------------------------- Inputs -------------------------------------
input                        core_clk;               // Core clock
input                        core_rst_n;             // Core system reset
input                        cfg_endpoint;           // Port logic mode  1=endpoint
input                        cfg_root_compx;         // Port logic mode 1=root complex;
input                        cfg_upstream_port;      // Port logic mode (0=downstream, 1=upstream)
input   [2:0]                cfg_max_payload;        // MAX paylaod configured in CDM
input   [12:0]               cfg_fc_latency_value;   // FC update latency timer value
input                        cfg_ext_synch;          // Extended synch for N_FTS configured in CDM
input   [NVC-1:0]            cfg_vc_enable;          // VC enable map from CDM
input   [3*NVC-1:0]          cfg_vc_struc_vc_id_map; // Structure VC id to actual VC id map from CDM
input   [23:0]               cfg_vc_id_vc_struc_map; // Index by vc, returns structure VC
input   [23:0]               cfg_tc_struc_vc_map;    // Index by TC, returns VC
input   [7 :0]               cfg_tc_enable;          // TCs that are enabled
input                        cfg_fc_wdog_disable;    // disable watch dog timer in FC for some debug purpose
input   [(NVC*8)-1:0]        cfg_fc_credit_ph;       // Posted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]        cfg_fc_credit_nph;      // Nonposted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]        cfg_fc_credit_cplh;     // Completion header Wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]       cfg_fc_credit_pd;       // Posted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]       cfg_fc_credit_npd;      // Nonposted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]       cfg_fc_credit_cpld;     // Completion data wire to control the FC initial value for FC credit advertisement
input                        smlh_in_l1 ;            // Indicates LTSSM in L1 state

input   [DW_W_PAR-1:0]       rdlh_rtlh_data;         // Current TLP header and data
input   [NW-1:0]             rdlh_rtlh_sot;          // When asserted, it indicates the Start of a TLP pkt
input   [NW-1:0]             rdlh_rtlh_eot;          // When asserted, it indicates the end of a good TLP pkt
input   [RX_TLP-1:0]         rdlh_rtlh_abort;        // TLP abort due to the data link layer detected error
input                        rdlh_rtlh_dv;           // TLP valid at this cycle
input   [RX_NDLLP-1:0]       rdlh_rtlh_rcvd_dllp;    // When asserted, it indicates reception of DLLP packet(s)
input   [(32*RX_NDLLP)-1:0]  rdlh_rtlh_dllp_content; // The received DLLP packet(s)
input   [1:0]                rdlh_rtlh_link_state;   // RDLH link up FSM current state.

input   [DCAW*NVC-1:0]       radm_rtlh_ph_ca;        // Credit allocated (posted header)
input   [DCAW*NVC-1:0]       radm_rtlh_pd_ca;        // Credit allocated (posted data)
input   [DCAW*NVC-1:0]       radm_rtlh_nph_ca;       // Credit allocated (non-posted header)
input   [DCAW*NVC-1:0]       radm_rtlh_npd_ca;       // Credit allocated (non-posted data)
input   [DCAW*NVC-1:0]       radm_rtlh_cplh_ca;      // Credit allocated (completion header)
input   [DCAW*NVC-1:0]       radm_rtlh_cpld_ca;      // Credit allocated (completion data)

input                        xdlh_rtlh_fc_ack;       // When asserted, it indicates XDLH has accepted the request to XMIT a FC packet
input                        xadm_all_type_infinite; // XADM FC book keeping block indicates that remote link advertised all FC credits to infinite.
input                        pm_freeze_fc_timer;
input   [2:0]                current_data_rate;      // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4
input                        phy_type;               // Mac type
input                        smlh_in_l0_l0s;         // LTSSM is in L0 or L0s state


// -------------------------------- Outputs ------------------------------------
output                       rtlh_rdlh_fci1_fci2;    // RTLH VC0 flow control has done init 1

output  [TX_NDLLP-1:0]       rtlh_xdlh_fc_req;       // Request to send a FCP
output                       rtlh_xdlh_fc_req_hi;    // Request to send a high-priority FCP that is higher than ACK/NACK
output                       rtlh_xdlh_fc_req_low;   // Request to send a low-priority FCP that is lower than TLP
output  [(32*TX_NDLLP)-1:0]  rtlh_xdlh_fc_data;      // Data associated with request

output  [RX_NDLLP-1:0]       rtlh_rfc_upd;           // Update Transmit credit information
output  [RX_NDLLP*32-1:0]    rtlh_rfc_data;          // 32bits FC update data

output  [DW+DATA_PAR_WD-1:0] rtlh_radm_data;         // Packet Data
output  [(128+RAS_PCIE_HDR_PROT_WD)*RX_TLP-1:0] rtlh_radm_hdr; // Packet Header
output  [NW-1:0]             rtlh_radm_dwen;         // Packet hdr bus dword enable
output  [RX_TLP-1:0]         rtlh_radm_dv;               // Data is valid this cycle
output  [RX_TLP-1:0]         rtlh_radm_hv;               // hdr is valid this cycle
output  [RX_TLP-1:0]         rtlh_radm_eot;              // end of tlp is valid this cycle
output  [RX_TLP-1:0]         rtlh_radm_dllp_err;         // This packet should not be added to queue due to dllp
output  [RX_TLP-1:0]         rtlh_radm_malform_tlp_err;  // This packet should not be added to queue due tomalform
output  [RX_TLP-1:0]         rtlh_radm_ecrc_err;         // This packet should not be added to queue due to ecrc
output  [64*RX_TLP-1:0]      rtlh_radm_ant_addr;    // anticipated address (1 clock earlier)
output  [16*RX_TLP-1:0]      rtlh_radm_ant_rid;     // anticipated RID (1 clock earlier)
output                       rtlh_radm_pending;      // Indicates a pending TLP In Transaction Layer
output  [NVC-1:0]            rtlh_fc_init_status;    // Report VC as ready for traffic
output  [NVC-1:0]            rtlh_crd_not_rtn;       // A debug feature for credit not return indication
output                       rtlh_req_link_retrain;  // Alink retrain request due to FC watch dog timer expiration
output                       rtlh_parerr;
output  [7:0]                rtfcgen_ph_diff_vc0;
output                       rtlh_overfl_err;        // Indicates receiver overflow (credit based)


// ----------------------------------------------------------------------------
// --- Internal signals
// ----------------------------------------------------------------------------
wire    [127:0]         rtlh_hdr_log_reg;
wire    [3*RX_TLP-1:0]  rtcheck_rtfcgen_vc;
wire    [2*RX_TLP-1:0]  rtfcgen_fctype;
wire    [RX_TLP-1:0]    rtfcgen_incr_enable;
wire    [9*RX_TLP-1:0]  rtfcgen_incr_amt;
wire                    rtlh_rdlh_fci1_fci2;    // RTLH VC0 flow control has done init 1
wire    [NVC-1:0]       rtlh_fc_init1_status;   // Report VC as ready for traffic
wire                    rtlh_extrct_parerr;
wire                    rtlh_overfl_err;        // Indicates receiver overflow (credit based)

wire    [DW_W_PAR-1:0]        rtlh_extrct_data;               // Packet Data
wire    [HW_W_PAR-1:0]        rtlh_extrct_hdr;                // Packet Data
wire    [NW-1:0]              rtlh_extrct_dwen;               // Packet hdr bus dword enable
wire    [RX_TLP-1:0]          rtlh_extrct_sot;                // hdr is valid this cycle
wire    [RX_TLP-1:0]          rtlh_extrct_dv;                 // Data is valid this cycle
wire    [RX_TLP-1:0]          rtlh_extrct_eot;                // end of tlp is valid this cycle
wire    [RX_TLP-1:0]          rtlh_extrct_abort;              // This packet should not be added to queue
wire    [RX_TLP-1:0]          rtlh_extrct_ecrc_len_mismatch;
wire    [RX_TLP-1:0]          rtlh_extrct_ecrc_err;

wire                    rtlh_ecrc_parerr;
wire   [DW_W_PAR-1:0]   rtlh_ecrc_data;
wire   [NW-1:0]         rtlh_ecrc_sot;
wire                    rtlh_ecrc_dv;
wire   [NW-1:0]         rtlh_ecrc_eot;
wire   [RX_TLP-1:0]     rtlh_ecrc_abort;
wire   [RX_TLP-1:0]     rtlh_ecrc_err;
wire   [RX_TLP-1:0]     rtlh_ecrc_len_mismatch;


wire   [RX_TLP-1:0]         rtfcgen_rtcheck_overfl_err;
wire   [NVC*HCRD_WD-1:0]    rtfcgen_ph_diff;



assign     rtlh_rdlh_fci1_fci2 = rtlh_fc_init1_status[0];

// receiver overflow errors
assign rtlh_overfl_err = |rtfcgen_rtcheck_overfl_err;

// lbc needs ph credits from VC0
assign rtfcgen_ph_diff_vc0 = rtfcgen_ph_diff[7:0];



rtlh_tlp_ecrc

#(INST) u_rtlh_ecrc(
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),

    .rdlh_rtlh_data                 (rdlh_rtlh_data),
    .rdlh_rtlh_sot                  (rdlh_rtlh_sot),
    .rdlh_rtlh_eot                  (rdlh_rtlh_eot),
    .rdlh_rtlh_abort                (rdlh_rtlh_abort),
    .rdlh_rtlh_dv                   (rdlh_rtlh_dv),

    .rtlh_ecrc_parerr               (rtlh_ecrc_parerr),
    .rtlh_ecrc_data                 (rtlh_ecrc_data),
    .rtlh_ecrc_sot                  (rtlh_ecrc_sot),
    .rtlh_ecrc_dv                   (rtlh_ecrc_dv),
    .rtlh_ecrc_eot                  (rtlh_ecrc_eot),
    .rtlh_ecrc_abort                (rtlh_ecrc_abort),
    .rtlh_ecrc_err                  (rtlh_ecrc_err),
    .rtlh_ecrc_len_mismatch         (rtlh_ecrc_len_mismatch)
);


// receive TLP extract and alignment
rtlh_tlp_extract

#(INST) u_rtlh_extract(
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),

    .rtlh_ecrc_data                 (rtlh_ecrc_data),
    .rtlh_ecrc_sot                  (rtlh_ecrc_sot),
    .rtlh_ecrc_dv                   (rtlh_ecrc_dv),
    .rtlh_ecrc_eot                  (rtlh_ecrc_eot),
    .rtlh_ecrc_abort                (rtlh_ecrc_abort),
    .rtlh_ecrc_err                  (rtlh_ecrc_err),
    .rtlh_ecrc_len_mismatch         (rtlh_ecrc_len_mismatch),


    .rtlh_extrct_sot                     (rtlh_extrct_sot),
    .rtlh_extrct_hdr                     (rtlh_extrct_hdr),
    .rtlh_extrct_dv                      (rtlh_extrct_dv),
    .rtlh_extrct_data                    (rtlh_extrct_data),
    .rtlh_extrct_dwen                    (rtlh_extrct_dwen),
    .rtlh_extrct_eot                     (rtlh_extrct_eot),
    .rtlh_extrct_abort                   (rtlh_extrct_abort),
    .rtlh_extrct_ecrc_len_mismatch       (rtlh_extrct_ecrc_len_mismatch),
    .rtlh_extrct_ecrc_err                (rtlh_extrct_ecrc_err),
    .rtlh_extrct_parerr                  (rtlh_extrct_parerr)
);

rtlh_tlp_check

#(INST) u_rtlh_tlp_check(
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_max_payload                (cfg_max_payload),
    .cfg_root_compx                 (cfg_root_compx),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_endpoint                   (cfg_endpoint),
    .cfg_tc_enable                  (cfg_tc_enable),
    .rtlh_fc_init1_status           (rtlh_fc_init1_status),
    .cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map),

    .rtlh_extrct_sot                     (rtlh_extrct_sot),
    .rtlh_extrct_hdr                     (rtlh_extrct_hdr),
    .rtlh_extrct_dv                      (rtlh_extrct_dv),
    .rtlh_extrct_data                    (rtlh_extrct_data),
    .rtlh_extrct_dwen                    (rtlh_extrct_dwen),
    .rtlh_extrct_eot                     (rtlh_extrct_eot),
    .rtlh_extrct_abort                   (rtlh_extrct_abort),
    .rtlh_extrct_ecrc_err                (rtlh_extrct_ecrc_err),
    .rtlh_extrct_ecrc_len_mismatch       (rtlh_extrct_ecrc_len_mismatch),

    .rtfcgen_rtcheck_overfl_err     (rtfcgen_rtcheck_overfl_err),

    .rtlh_radm_hv                   (rtlh_radm_hv),
    .rtlh_radm_hdr                  (rtlh_radm_hdr),
    .rtlh_radm_dv                   (rtlh_radm_dv),
    .rtlh_radm_data                 (rtlh_radm_data),
    .rtlh_radm_dwen                 (rtlh_radm_dwen),
    .rtlh_radm_eot                  (rtlh_radm_eot),
    .rtlh_radm_malform_tlp_err      (rtlh_radm_malform_tlp_err),
    .rtlh_radm_ecrc_err             (rtlh_radm_ecrc_err),
    .rtlh_radm_dllp_err             (rtlh_radm_dllp_err),
    .rtlh_radm_ant_addr             (rtlh_radm_ant_addr),
    .rtlh_radm_ant_rid              (rtlh_radm_ant_rid),
    .rtfcgen_vc                     (rtcheck_rtfcgen_vc),
    .rtfcgen_fctype                 (rtfcgen_fctype),
    .rtfcgen_incr_enable            (rtfcgen_incr_enable),
    .rtfcgen_incr_amt               (rtfcgen_incr_amt),
    .rtlh_radm_pending              (rtlh_radm_pending)
);

rtlh_fc

#(INST) u_rtlh_fc(
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_max_payload                (cfg_max_payload),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_fc_latency_value           (cfg_fc_latency_value),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_vc_enable                  (cfg_vc_enable),
    .cfg_vc_struc_vc_id_map         (cfg_vc_struc_vc_id_map),
    .cfg_vc_id_vc_struc_map         (cfg_vc_id_vc_struc_map),
    .cfg_fc_wdog_disable            (cfg_fc_wdog_disable),
    .cfg_fc_credit_ph               (cfg_fc_credit_ph),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld),
    .smlh_in_l1                     (smlh_in_l1    ),
    .rdlh_rtlh_rcvd_dllp            (rdlh_rtlh_rcvd_dllp),
    .rdlh_rtlh_dllp_content         (rdlh_rtlh_dllp_content),
    .rdlh_rtlh_link_state           (rdlh_rtlh_link_state),
    .xdlh_rtlh_fc_ack               (xdlh_rtlh_fc_ack),
    .radm_rtlh_ph_ca                (radm_rtlh_ph_ca),
    .radm_rtlh_pd_ca                (radm_rtlh_pd_ca),
    .radm_rtlh_nph_ca               (radm_rtlh_nph_ca),
    .radm_rtlh_npd_ca               (radm_rtlh_npd_ca),
    .radm_rtlh_cplh_ca              (radm_rtlh_cplh_ca),
    .radm_rtlh_cpld_ca              (radm_rtlh_cpld_ca),
    .rtcheck_rtfcgen_vc             (rtcheck_rtfcgen_vc),
    .rtcheck_rtfcgen_fctype         (rtfcgen_fctype),
    .rtcheck_rtfcgen_incr_enable    (rtfcgen_incr_enable),
    .rtcheck_rtfcgen_incr_amt       (rtfcgen_incr_amt),
    .pm_freeze_fc_timer             (pm_freeze_fc_timer),
    .xadm_all_type_infinite         (xadm_all_type_infinite),
    .current_data_rate              (current_data_rate),
    .phy_type                       (phy_type),
    .smlh_in_l0_l0s                 (smlh_in_l0_l0s),

    .rtlh_fc_init_status            (rtlh_fc_init_status),
    .rtlh_fc_init1_status           (rtlh_fc_init1_status),
    .rtlh_xdlh_fc_req               (rtlh_xdlh_fc_req),
    .rtlh_xdlh_fc_req_hi            (rtlh_xdlh_fc_req_hi),
    .rtlh_xdlh_fc_req_low           (rtlh_xdlh_fc_req_low),
    .rtlh_xdlh_fc_data              (rtlh_xdlh_fc_data),
    .rtlh_rfc_upd                   (rtlh_rfc_upd),
    .rtlh_rfc_data                  (rtlh_rfc_data),
    .rtlh_crd_not_rtn               (rtlh_crd_not_rtn),
    .rtlh_req_link_retrain          (rtlh_req_link_retrain),
    .rtfcgen_rtcheck_overfl_err     (rtfcgen_rtcheck_overfl_err),
    .rtfcgen_ph_diff                (rtfcgen_ph_diff)
);

assign rtlh_parerr = rtlh_extrct_parerr || rtlh_ecrc_parerr;


endmodule
