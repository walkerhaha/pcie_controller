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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/xadm_vc_fc.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module groups all of the xadm_fc instantiations for the virtual
// --- channels under one level of hierarchy
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xadm_vc_fc
    #(
    // Parameters
    parameter INST  = 0,
    parameter NCL  = `CX_NCLIENTS + 2,
    parameter NVC  = `CX_NVC,
    parameter NW   = `CX_NW,
    parameter RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1,
    parameter NF   = `CX_NFUNC,
    parameter  HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8,
    parameter  DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12
    )
    
                      (
    // Inputs
    input                   core_clk,
    input                   core_rst_n,
    input                   rstctl_core_flush_req,
    input [2:0]             cfg_max_payload_size,
    input [23:0]            cfg_tc_vc_map,
    input [(NVC*3)-1:0]     cfg_vc_id,
    input [NVC-1:0]         cfg_vc_enable,


    // Once a decision has been made, consume the credits
    input [NCL-1:0]         active_grant,
    // In the event that we nullify the packet, we must restore credits
    input                   restore_enable,
    input                   restore_capture,
    input [2:0]             restore_tc,
    input [6:0]             restore_type,
    input [9:0]             restore_word_len,

    // RDLH data link down
    input                   rdlh_link_down,
    // Update packets from RTLH
    input [RX_NDLLP-1:0]    rtlh_rfc_upd,
    input [RX_NDLLP*32-1:0] rtlh_rfc_data,
    input [NVC-1:0]         rtlh_fc_init_status,

    // Client requests
    input [(NCL*3)-1:0]     clients_tc,
    input [NCL*7-1:0]       clients_type,
    input [NCL*2-1:0]       clients_addr_offset,
    input [NCL*13-1:0]      clients_byte_len,



    // Outputs 
    output [NCL*NVC-1:0]    fc_cds_pass,
    output [NCL*NVC-1:0]    next_fc_cds_pass,
    output [NVC-1:0]        next_credit_enough,
    output [NVC-1:0]        next_2credit_enough,
    output [NVC-1:0]        xadm_no_fc_credit,
    output [NVC-1:0]        xadm_had_enough_credit,
    output [NVC-1:0]        xadm_all_type_infinite,
    output [NVC*HCRD_WD-1:0] xadm_ph_cdts,
    output [NVC*DCRD_WD-1:0] xadm_pd_cdts,
    output [NVC*HCRD_WD-1:0] xadm_nph_cdts,
    output [NVC*DCRD_WD-1:0] xadm_npd_cdts,
    output [NVC*HCRD_WD-1:0] xadm_cplh_cdts,
    output [NVC*DCRD_WD-1:0] xadm_cpld_cdts
    

);

// Instantiate xadm_fc once per virtual channel
genvar j;
generate
    for(j = 0; j < NVC; j = j + 1) begin:u_vc_xadm_fc
        xadm_fc
        
        #(INST) u_xadm_fc
           (
            .core_clk                   (core_clk),
            .core_rst_n                 (core_rst_n),
            .rstctl_core_flush_req      (rstctl_core_flush_req),
            .cfg_max_payload_size       (cfg_max_payload_size),
            .cfg_tc_vc_map              (cfg_tc_vc_map),
            .cfg_vc_id                  (cfg_vc_id[3*(1+j)-1:3*j]),
            .cfg_vc_enable              (cfg_vc_enable[j]),
            .active_grant               (active_grant),
            .restore_enable             (restore_enable),
            .restore_capture            (restore_capture),
            .restore_tc                 (restore_tc),
            .restore_type               (restore_type),
            .restore_word_len           (restore_word_len),
        
            .rdlh_link_down             (rdlh_link_down),
            .rtlh_rfc_upd               (rtlh_rfc_upd),
            .rtlh_rfc_data              (rtlh_rfc_data),
            .rtlh_fc_init_status        (rtlh_fc_init_status[j]),
        
            .clients_tc                 (clients_tc),
            .clients_type               (clients_type),
            .clients_byte_len           (clients_byte_len),
            .clients_addr_offset        (clients_addr_offset),
        
            .fc_cds_pass                (fc_cds_pass[NCL*(1+j)-1:NCL*j]),
            .next_fc_cds_pass           (next_fc_cds_pass[NCL*(1+j)-1:NCL*j]), 
            .next_credit_enough         (next_credit_enough[j]),  
            .next_2credit_enough        (next_2credit_enough[j]), 
            .xadm_no_fc_credit          (xadm_no_fc_credit[j]),
        
            .xadm_had_enough_credit     (xadm_had_enough_credit[j]),
            .xadm_all_type_infinite     (xadm_all_type_infinite[j]),
            .xadm_ph_cdts               (xadm_ph_cdts[HCRD_WD*(1+j)-1:HCRD_WD*j]),
            .xadm_pd_cdts               (xadm_pd_cdts[DCRD_WD*(1+j)-1:DCRD_WD*j]),
            .xadm_nph_cdts              (xadm_nph_cdts[HCRD_WD*(1+j)-1:HCRD_WD*j]),
            .xadm_npd_cdts              (xadm_npd_cdts[DCRD_WD*(1+j)-1:DCRD_WD*j]),
            .xadm_cplh_cdts             (xadm_cplh_cdts[HCRD_WD*(1+j)-1:HCRD_WD*j]),
            .xadm_cpld_cdts             (xadm_cpld_cdts[DCRD_WD*(1+j)-1:DCRD_WD*j])
        );
    end
endgenerate

endmodule
