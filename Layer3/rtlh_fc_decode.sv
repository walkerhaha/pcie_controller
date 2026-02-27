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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_fc_decode.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module performs the decoding on received flow control packets
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rtlh_fc_decode (
    core_clk,
    core_rst_n,
    cfg_vc_id_vc_struc_map,
    rdlh_rtlh_link_state,
    rdlh_rtlh_rcvd_dllp,
    rdlh_rtlh_dllp_content,
    rtlh_fc_init1_status,
    // Outputs
    rx_fc1_p,
    rx_fc1_np,
    rx_fc1_cpl,
    rx_fc2_p,
    rx_fc2_np,
    rx_fc2_cpl,
    rx_updt_p,
    rx_updt_np,
    rx_updt_cpl,
    rx_rfc_upd,
    rx_rfc_data
);
parameter INST      = 0;                    // The uniquifying parameter for each port logic instance.
parameter NVC       = `CX_NVC;              // How many VCs are supported
parameter NW        = `CX_NW;               // Number of 32-bit dwords handled by the datapath each clock.
//parameter RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1; // Max number of DLLPs received per cycle
parameter RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1; // Max number of DLLPs received
parameter TP        = `TP;                  // Clock to Q delay (simulator insurance)


// -------------------------------- Inputs ------------------------------------
input                       core_clk;               // Core clock
input                       core_rst_n;             // Core system reset

input   [23:0]              cfg_vc_id_vc_struc_map; // map a vid to structure vid
input   [1:0]               rdlh_rtlh_link_state;   // RDLH link up FSM current state.
input   [RX_NDLLP -1:0]     rdlh_rtlh_rcvd_dllp;    // When asserted, it indicates DLLP packet(s) received
input   [32*RX_NDLLP -1:0]  rdlh_rtlh_dllp_content; // The received DLLP packet(s)
input   [NVC-1:0]           rtlh_fc_init1_status;

output  [NVC-1:0]           rx_fc1_p;
output  [NVC-1:0]           rx_fc1_np;
output  [NVC-1:0]           rx_fc1_cpl;
output  [NVC-1:0]           rx_fc2_p;
output  [NVC-1:0]           rx_fc2_np;
output  [NVC-1:0]           rx_fc2_cpl;
output  [NVC-1:0]           rx_updt_p;
output  [NVC-1:0]           rx_updt_np;
output  [NVC-1:0]           rx_updt_cpl;
output  [RX_NDLLP -1:0]     rx_rfc_upd;             // Update Transmit credit information
output  [32*RX_NDLLP -1:0]  rx_rfc_data;            // 32bits FC update data


// Registered ouputs
reg     [NVC-1:0]           rx_fc1_p;
reg     [NVC-1:0]           rx_fc1_np;
reg     [NVC-1:0]           rx_fc1_cpl;
reg     [NVC-1:0]           rx_fc2_p;
reg     [NVC-1:0]           rx_fc2_np;
reg     [NVC-1:0]           rx_fc2_cpl;
reg     [NVC-1:0]           rx_updt_p;
reg     [NVC-1:0]           rx_updt_np;
reg     [NVC-1:0]           rx_updt_cpl;

reg     [RX_NDLLP -1:0]     rx_rfc_upd;             // Update Transmit credit information
reg     [32*RX_NDLLP -1:0]  rx_rfc_data;            // 32bits FC update data


// -----------------------------------------------------------------------------
// --- Internal reg
// -----------------------------------------------------------------------------
reg    [RX_NDLLP*5-1:0]   rdlh_rtlh_dllp_TYPE;
reg    [RX_NDLLP*3-1:0]   rdlh_rtlh_dllp_VCID;
reg    [RX_NDLLP*3-1:0]   rdlh_rtlh_dllp_struc_VCID;
reg    [RX_NDLLP-1:0]     rcvd_fc1_p;
reg    [RX_NDLLP-1:0]     rcvd_fc1_np;
reg    [RX_NDLLP-1:0]     rcvd_fc1_cpl;
reg    [RX_NDLLP-1:0]     rcvd_fc2_p;
reg    [RX_NDLLP-1:0]     rcvd_fc2_np;
reg    [RX_NDLLP-1:0]     rcvd_fc2_cpl;
reg    [RX_NDLLP-1:0]     rcvd_updt_p;
reg    [RX_NDLLP-1:0]     rcvd_updt_np;
reg    [RX_NDLLP-1:0]     rcvd_updt_cpl;
reg    [RX_NDLLP*NVC-1:0] rcvd_fc_match;
reg    [RX_NDLLP*NVC-1:0] rcvd_fc_for_uninit_vc;
reg    [RX_NDLLP*NVC-1:0] rcvd_fc_for_init_vc;

// Decode the DLLPs
always @(*) begin : DLLP_DECODE
    integer i;
    integer j;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        rdlh_rtlh_dllp_TYPE[i*5 +: 5]       =
            rdlh_rtlh_dllp_content[i*32 + 3 +: 5];
        rdlh_rtlh_dllp_VCID[i*3 +: 3]       =
            rdlh_rtlh_dllp_content[i*32 +: 3];
        rdlh_rtlh_dllp_struc_VCID[i*3 +: 3] =
            { get_VCID(cfg_vc_id_vc_struc_map,rdlh_rtlh_dllp_VCID[i*3 +: 3],2),
              get_VCID(cfg_vc_id_vc_struc_map,rdlh_rtlh_dllp_VCID[i*3 +: 3],1),
              get_VCID(cfg_vc_id_vc_struc_map,rdlh_rtlh_dllp_VCID[i*3 +: 3],0)};
        for(j = 0; j < NVC; j = j + 1) begin
            rcvd_fc_match[i*NVC + j] = rdlh_rtlh_dllp_struc_VCID[i*3 +: 3] == j;
            rcvd_fc_for_uninit_vc[i*NVC + j] =
                rcvd_fc_match[i*NVC + j] && !rtlh_fc_init1_status[j];
            rcvd_fc_for_init_vc[i*NVC + j] = 
                rcvd_fc_match[i*NVC + j] && rtlh_fc_init1_status[j];
        end
        if (NVC == 1) begin
        rcvd_fc1_p[i]    = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_P)   && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
        rcvd_fc1_np[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_NP)  && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
        rcvd_fc1_cpl[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_CPL) && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
        rcvd_fc2_p[i]    = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_P)   && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
        rcvd_fc2_np[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_NP)  && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
        rcvd_fc2_cpl[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_CPL) && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
        rcvd_updt_p[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_P)     && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
        rcvd_updt_np[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_NP)    && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
        rcvd_updt_cpl[i] = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_CPL)   && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
        end else begin
        rcvd_fc1_p[i]    = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_P);
        rcvd_fc1_np[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_NP);
        rcvd_fc1_cpl[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_CPL);
        rcvd_fc2_p[i]    = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_P);
        rcvd_fc2_np[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_NP);
        rcvd_fc2_cpl[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_CPL);
        rcvd_updt_p[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_P);
        rcvd_updt_np[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_NP);
        rcvd_updt_cpl[i] = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_CPL);
        end
    end
end

// Drive outputs per VC
always @(*) begin : DRIVE_RX_FC_INDICATIONS
    integer i;
    rx_fc1_p = 0;
    rx_fc1_np = 0;
    rx_fc1_cpl = 0;
    rx_fc2_p = 0;
    rx_fc2_np = 0;
    rx_fc2_cpl = 0;
    rx_updt_p = 0;
    rx_updt_np = 0;
    rx_updt_cpl = 0;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        rx_fc1_p    =
            rx_fc1_p | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc1_p[i]}};
        rx_fc1_np   =
            rx_fc1_np | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc1_np[i]}};
        rx_fc1_cpl  =
            rx_fc1_cpl | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc1_cpl[i]}};
        rx_fc2_p    =
            rx_fc2_p   | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc2_p[i]}};
        rx_fc2_np   =
            rx_fc2_np  | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc2_np[i]}};
        rx_fc2_cpl  =
            rx_fc2_cpl | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc2_cpl[i]}};
        rx_updt_p   =
            rx_updt_p  | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_updt_p[i]}};
        rx_updt_np  =
            rx_updt_np | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_updt_np[i]}};
        rx_updt_cpl =
            rx_updt_cpl | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_updt_cpl[i]}};
    end
end

//
// Drive received flow control information over to XADM
//
// when fc state of fc_gen block is in fc1 init or fc update, a received fc
// dllp value will be used to update xadm fc credit account block
//
reg [RX_NDLLP-1:0] l_rx_rfc_upd;
always @(*) begin : FC_UPDATE
    integer i;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        l_rx_rfc_upd[i] =
            |rcvd_fc_for_uninit_vc[i*NVC +: NVC] &&
            rdlh_rtlh_rcvd_dllp[i] &&
            (rcvd_fc1_p[i] || rcvd_fc1_np[i] || rcvd_fc1_cpl[i] ||
             rcvd_fc2_p[i] || rcvd_fc2_np[i] || rcvd_fc2_cpl[i] ) ||
            |rcvd_fc_for_init_vc[i*NVC +: NVC] && 
            rdlh_rtlh_rcvd_dllp[i] &&
            (rcvd_updt_p[i] || rcvd_updt_np[i] || rcvd_updt_cpl[i]);

    end
end

always @(posedge core_clk or negedge core_rst_n)
begin : decode_fc_updates
    if(!core_rst_n) begin
        rx_rfc_upd   <= #TP 0;
        rx_rfc_data  <= #TP 0;
    end else begin
        // identify FC pkt(s) - INIT_FC1, INIT_FC2, UPDATE
        rx_rfc_upd   <= #TP l_rx_rfc_upd;
        if(|l_rx_rfc_upd)
           rx_rfc_data  <= #TP rdlh_rtlh_dllp_content;
    end
end


function automatic get_VCID;
    input [23:0] vcid_struct_map_local;
    input [2:0] strct_vcid;
    input [1:0] client_ndx;
    reg [24:0] vcid_struct_map_local_padded;
//cfg_vc_id_vc_struc_map[(3*rdlh_rtlh_dllp1_VCID) +2]
    begin
        get_VCID                    = 0;
        vcid_struct_map_local_padded= {1'b0,vcid_struct_map_local};
        case (strct_vcid)
            3'b000:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (0*3)];
            3'b001:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (1*3)];
            3'b010:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (2*3)];
            3'b011:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (3*3)];
            3'b100:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (4*3)];
            3'b101:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (5*3)];
            3'b110:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (6*3)];
            3'b111:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (7*3)];
        endcase // case(strct_vcid)
    end
endfunction

endmodule
