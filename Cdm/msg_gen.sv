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
// ---    $DateTime: 2020/02/14 07:03:57 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/msg_gen.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Module Description:
// --- Top level for internal TLP message generation
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module msg_gen (
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
    cfg_nond0_vdm_block,

    pm_asnak,
    pm_pme,
    pme_turn_off,
    pme_to_ack,

    unlock,

    send_cor_err,
    send_nf_err,
    send_f_err,
    cfg_func_spec_err,

    inta_wire,
    intb_wire,
    intc_wire,
    intd_wire,
//    nhp_int,

    cfg_slot_pwr_limit_wr,
    set_slot_pwr_limit_val,
    set_slot_pwr_limit_scale,

    cfg_msi_addr,
    cfg_msi_data,
    cfg_msi_64,
    cfg_multi_msi_en,
//    hp_msi_request,
    cfg_bus_master_en,
    cfg_msix_en,
    msix_addr,
    msix_data,
    ven_msi_req,
    ven_msi_func_num,
    ven_msi_tc,
    ven_msi_vector,

    ven_msg_fmt,
    ven_msg_type,
    ven_msg_tc,
    ven_msg_td,
    ven_msg_ep,
    ven_msg_attr,
    ven_msg_len,
    ven_msg_func_num,
    ven_msg_tag,
    ven_msg_code,
    ven_msg_data,
    ven_msg_req,

    xadm_msg_halt,

    pm_dstate,



    cfg_auto_slot_pwr_lmt_dis,

// ---- outputs ---------------
    msg_gen_hv,
    msg_gen_dv,
    msg_gen_eot,
    msg_gen_hdr,
    msg_gen_data,


    assert_inta_grt,
    assert_intb_grt,
    assert_intc_grt,
    assert_intd_grt,
    deassert_inta_grt,
    deassert_intb_grt,
    deassert_intc_grt,
    deassert_intd_grt,
    ven_msi_grant,
    ven_msg_grant,
    pme_to_ack_grt,
    pm_pme_grant,
    pme_turn_off_grt
//    hp_msi_grant
    ,
    msg_gen_asnak_grt,
    msg_gen_unlock_grant
);

parameter INST          = 0;                        // The uniquifying parameter for each port logic instance.
parameter TP            = `TP;
parameter NF            = `CX_NFUNC;                // Number of functions implemented in this device
parameter PF_WD         = `CX_NFUNC_WD;             // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise
parameter ST_HDR        = `ST_HDR;
parameter NW            = `CX_NW;                   // Number of 32-bit dwords handled by the datapath each clock.
parameter DW            = (32*NW) + `TRGT_DATA_PROT_WD;  // Width of datapath in bits. Plus parity for the special function
parameter   HDR_PROT_WD          = 0  
                                   ;
parameter BUSNUM_WD     = `CX_BUSNUM_WD;            // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD     = `CX_DEVNUM_WD;            // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.

localparam ATTR_WD = `SF_HDR_TLP_ATTR;

localparam TAG_SIZE = `CX_TAG_SIZE;

input                   core_rst_n;
input                   core_clk;
input                   rdlh_link_up;               // Layer 2 link up
input   [BUSNUM_WD -1:0] pm_bus_num;
input   [DEVNUM_WD -1:0] pm_dev_num;
input   [BUSNUM_WD -1:0] cfg_pbus_num;
input   [DEVNUM_WD -1:0] cfg_pbus_dev_num;

input   [3:0]           device_type;                // Device type
input                   pm_xtlh_block_tlp;          // Block MSG & MSI.
input                   cfg_nond0_vdm_block;        // Block VDM.
// Power Management Message
input                   pm_asnak;                   // PM Active State NAK (downstream)
input   [NF-1:0]        pm_pme;                     // PM PME (upstream)
input                   pme_turn_off;               // PM Turn Off (broadcast downstream)
input   [NF-1:0]        pme_to_ack;                 // PM Turn Off ACK (upstream)
// Unlock Message (downstream)
input                   unlock;                     // Only for RC
// Error report Message (upstream)
input   [NF-1:0]        send_cor_err;               // Correctable Error
input   [NF-1:0]        send_nf_err;                // Uncorrectable Non-Fatal Error
input   [NF-1:0]        send_f_err;                 // Uncorrectable Fatal Error
input   [(3*NF)-1:0]     cfg_func_spec_err;
// Interrupt Message
input                   inta_wire;                  // INTA
input                   intb_wire;                  // INTB
input                   intc_wire;                  // INTC
input                   intd_wire;                  // INTD
//input   [NF-1:0]        nhp_int;                    // from native hot plug logic - create an interrupt
// Slot Power Limit Message (downstream)
input                   cfg_slot_pwr_limit_wr;      // On a configuration write to the Slot Capabilities register of Downstream port
input   [7:0]           set_slot_pwr_limit_val;     // Slot Power Limit Value
input   [1:0]           set_slot_pwr_limit_scale;   // Slot Power Limit Scale

// Message Signaled Interrupt (MSI)
input   [(64*NF)-1:0]   cfg_msi_addr;               // MSI address
input   [(32*NF)-1:0]   cfg_msi_data;               // MSI data
input   [NF-1:0]        cfg_msi_64;                 // MSI is enabled for 64 bit addressing
input   [(3*NF)-1:0]    cfg_multi_msi_en;           // Multiple MSI Message
//input   [NF-1:0]        hp_msi_request;             // from native hot plug logic - create an MSI
input   [NF-1:0]        cfg_bus_master_en;          // Bus master enabled
// MSI-X
input   [NF-1:0]        cfg_msix_en;                // MSI-X enable
input   [63:0]          msix_addr;                  // MSI-X address
input   [31:0]          msix_data;                  // MSI-X data
    // From app


input                   ven_msi_req;                // MSI request
input   [PF_WD-1:0]     ven_msi_func_num;           // MSI Function number
input   [2:0]           ven_msi_tc;                 // MSI TC
input   [4:0]           ven_msi_vector;             // MSI vector

// Vendor Specified message
input   [1:0]           ven_msg_fmt;                // Vendor MSG fmt
input   [4:0]           ven_msg_type;               // Vendor MSG type
input   [2:0]           ven_msg_tc;                 // Vendor MSG traffic class
input                   ven_msg_td;                 // Vendor MSG TLP digest
input                   ven_msg_ep;                 // Vendor MSG EP bit
input   [ATTR_WD-1:0]   ven_msg_attr;               // Vendor MSG attribute
input   [9:0]           ven_msg_len;                // Vendor MSG length
input   [PF_WD-1:0]     ven_msg_func_num;           // Vendor MSG function number
input   [TAG_SIZE-1:0]  ven_msg_tag;                // Vendor MSG tag
input   [7:0]           ven_msg_code;               // Vendor MSG code
input   [63:0]          ven_msg_data;               // Vendor MSG data
input                   ven_msg_req;                // Vendor MSG xmt request

input                   xadm_msg_halt;              // TLP msg advance from XADM
input  [(3*NF)-1:0]     pm_dstate;         // PF Power Management D-state 




input   [NF-1:0]       cfg_auto_slot_pwr_lmt_dis; // Auto Slot Power Limit Disable field of Slot Control Register; hardwired to 0 if DPC is not configured.

output logic                  msg_gen_hv;                 // TLP msg start of transaction
output logic                 msg_gen_dv;                 // TLP msg data valid
output logic                 msg_gen_eot;                // TLP msg end of transaction
output logic [DW-1:0]        msg_gen_data;               // TLP msg data
output logic [ST_HDR+HDR_PROT_WD-1:0]msg_gen_hdr;        // MSG header including protection code if RAS is used


output                  msg_gen_asnak_grt;
wire                    msg_gen_asnak_grt;
output                  msg_gen_unlock_grant;
wire                    msg_gen_unlock_grant;

output              assert_inta_grt;
output              assert_intb_grt;
output              assert_intc_grt;
output              assert_intd_grt;
output              deassert_inta_grt;
output              deassert_intb_grt;
output              deassert_intc_grt;
output              deassert_intd_grt;
output                  ven_msi_grant;              // MSI grant
output                  ven_msg_grant;              // App grant
output                  pme_to_ack_grt;             // PME_TO_ACK grant
output  [NF-1:0]    pm_pme_grant;                   // PM PME grant
output              pme_turn_off_grt;               // PM Turn Off grant
//output  [NF-1:0]        hp_msi_grant;               // Native hot plug grant

// Internal wires
wire    [7:0]           msg_code;                   // Internal MSG code
wire    [1:0]           msg_fmt;                    // Internal MSG fmt
wire    [4:0]           msg_type;                   // Internal MSG type
wire    [15:0]          msg_req_id;                 // Internal MSG req id
wire                    msg_xmt_grant;
wire                    msg_xmt_request;
wire    [PF_WD-1:0]     msi_func_num;
wire    [2:0]           msi_tc;
wire    [4:0]           msi_vector;
wire                    msi_xmt_grant;
wire                    msi_xmt_request;

wire                    int_ven_msi_req;            // MSI request
wire    [PF_WD-1:0]     int_ven_msi_func_num;       // MSI Function number
wire    [2:0]           int_ven_msi_tc;             // MSI TC
wire    [4:0]           int_ven_msi_vector;         // MSI vector




logic                  msg_gen_hv_int;                 // TLP msg start of transaction
logic                  msg_gen_dv_int;                 // TLP msg data valid
logic                  msg_gen_eot_int;                // TLP msg end of transaction
logic  [DW-1:0]        msg_gen_data_int;               // TLP msg data
logic  [ST_HDR+HDR_PROT_WD-1:0]msg_gen_hdr_int;        // MSG header including protection code if RAS is used
logic                  xadm_msg_halt_int;

parameter VEN_MSI_REGIN     = `CX_VEN_MSI_REGIN;
parameter DATAPATH_WIDTH    = (1 + PF_WD +              // req, func_num
                               3 + 5);                  // tc, vector
delay_n_w_stalling

#(VEN_MSI_REGIN, DATAPATH_WIDTH, 1) u_ven_msi_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .stall      (ven_msi_grant),                        // Stall input when grant asserted           
    .clear      (ven_msi_grant),                        // Clear pipeline when grant asserted
    .din        ({ven_msi_req, ven_msi_func_num,
                  ven_msi_tc, ven_msi_vector}),
    .stallout   (),
    .dout      ({int_ven_msi_req, int_ven_msi_func_num,
                 int_ven_msi_tc, int_ven_msi_vector}) 
);
//
// MSG generation for everything other than MSI & Vendor MSG
//
msg_arbitration

 #(INST) u_msg_arbitration(
// ---- inputs ---------------
    .core_rst_n                 (core_rst_n),
    .core_clk                   (core_clk),
    .rdlh_link_up               (rdlh_link_up),
    .cfg_pbus_num               (cfg_pbus_num),
    .cfg_pbus_dev_num           (cfg_pbus_dev_num),
    .pm_bus_num                 (pm_bus_num),
    .pm_dev_num                 (pm_dev_num),
    .device_type                (device_type),
    .pm_xtlh_block_tlp          (pm_xtlh_block_tlp),

    .pm_asnak                   (pm_asnak),
    .pm_pme                     (pm_pme),
    .pme_turn_off               (pme_turn_off),
    .pme_to_ack                 (pme_to_ack),
//    .nhp_int                    (nhp_int),

    .send_cor_err               (send_cor_err),
    .send_nf_err                (send_nf_err),
    .send_f_err                 (send_f_err),
    .cfg_func_spec_err          (cfg_func_spec_err),
    .cfg_bus_master_en          (cfg_bus_master_en),

    .unlock                     (unlock),

    .inta_wire                  (inta_wire),
    .intb_wire                  (intb_wire),
    .intc_wire                  (intc_wire),
    .intd_wire                  (intd_wire),

    .cfg_slot_pwr_limit_wr      (cfg_slot_pwr_limit_wr),
    .cfg_auto_slot_pwr_lmt_dis  (cfg_auto_slot_pwr_lmt_dis), 

//    .hp_msi_request             (hp_msi_request),
    .ven_msi_req                (int_ven_msi_req),
    .ven_msi_func_num           (int_ven_msi_func_num),
    .ven_msi_tc                 (int_ven_msi_tc),
    .ven_msi_vector             (int_ven_msi_vector),

    .msg_xmt_grant              (msg_xmt_grant),
    .msi_xmt_grant              (msi_xmt_grant),
    .pm_dstate                  (pm_dstate),

    
    

// ---- outputs ---------------
    .msg_code                   (msg_code),
    .msg_fmt                    (msg_fmt),
    .msg_type                   (msg_type),
    .msg_req_id                 (msg_req_id),
    .msg_xmt_request            (msg_xmt_request),

    .msi_func_num               (msi_func_num),
    .msi_tc                     (msi_tc),
    .msi_vector                 (msi_vector),
    .msi_xmt_request            (msi_xmt_request),
    .assert_inta_grt            (assert_inta_grt),
    .assert_intb_grt            (assert_intb_grt),
    .assert_intc_grt            (assert_intc_grt),
    .assert_intd_grt            (assert_intd_grt),
    .deassert_inta_grt          (deassert_inta_grt),
    .deassert_intb_grt          (deassert_intb_grt),
    .deassert_intc_grt          (deassert_intc_grt),
    .deassert_intd_grt          (deassert_intd_grt),
    .ven_msi_grant              (ven_msi_grant),
    .pme_to_ack_grt             (pme_to_ack_grt),
    .pm_pme_grant               (pm_pme_grant),
    .pme_turn_off_grt           (pme_turn_off_grt)


  ,
  .pm_asnak_grt                 (msg_gen_asnak_grt),
  .unlock_grt                   (msg_gen_unlock_grant)
);


//
// Form Message TLP
//
msg_formation

#(INST) u_msg_formation(
// ---- inputs ---------------
    .core_rst_n                 (core_rst_n),
    .core_clk                   (core_clk),
    .cfg_pbus_num               (cfg_pbus_num),
    .cfg_pbus_dev_num           (cfg_pbus_dev_num),
    .device_type                (device_type),
    .pm_xtlh_block_tlp          (pm_xtlh_block_tlp),
    .cfg_nond0_vdm_block        (cfg_nond0_vdm_block),

    .msg_code                   (msg_code),
    .msg_fmt                    (msg_fmt),
    .msg_type                   (msg_type),
    .msg_req_id                 (msg_req_id),
    .msg_xmt_request            (msg_xmt_request),

    .set_slot_pwr_limit_val     (set_slot_pwr_limit_val),
    .set_slot_pwr_limit_scale   (set_slot_pwr_limit_scale),

    .cfg_msi_addr               (cfg_msi_addr),
    .cfg_msi_data               (cfg_msi_data),
    .cfg_msi_64                 (cfg_msi_64),
    .cfg_multi_msi_en           (cfg_multi_msi_en),

    .msi_req                    (msi_xmt_request),
    .msi_func_num               (msi_func_num),
    .msi_tc                     (msi_tc),
    .msi_vector                 (msi_vector),
    .cfg_msix_en                (cfg_msix_en),
    .msix_addr                  (msix_addr),
    .msix_data                  (msix_data),
    .ven_msg_fmt                (ven_msg_fmt),
    .ven_msg_type               (ven_msg_type),
    .ven_msg_tc                 (ven_msg_tc),
    .ven_msg_td                 (ven_msg_td),
    .ven_msg_ep                 (ven_msg_ep),
    .ven_msg_attr               (ven_msg_attr),
    .ven_msg_len                (ven_msg_len),
    .ven_msg_func_num           (ven_msg_func_num),
    .ven_msg_tag                (ven_msg_tag),
    .ven_msg_code               (ven_msg_code),
    .ven_msg_data               (ven_msg_data),
    .ven_msg_req                (ven_msg_req),

    .xadm_msg_halt              (xadm_msg_halt_int),

// ---- outputs ---------------
    .msg_gen_dv                 (msg_gen_dv_int),
    .msg_gen_hv                 (msg_gen_hv_int),
    .msg_gen_hdr                (msg_gen_hdr_int),
    .msg_gen_eot                (msg_gen_eot_int),
    .msg_gen_data               (msg_gen_data_int),

    .msg_xmt_grant              (msg_xmt_grant),
    .msi_grant                  (msi_xmt_grant),
    .ven_msg_grant              (ven_msg_grant)
);



assign msg_gen_hv = msg_gen_hv_int;
assign msg_gen_dv        = msg_gen_dv_int;
assign msg_gen_hdr       = msg_gen_hdr_int;
assign msg_gen_data      = msg_gen_data_int;
assign msg_gen_eot       = msg_gen_eot_int;
assign xadm_msg_halt_int = xadm_msg_halt;



endmodule
