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
// ---    $DateTime: 2018/08/30 02:24:02 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_crd_return.sv#2 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module handles parsing of transmit CPL Transactions  (TLPs).
//  Its main functions are:
//     (1) Count valid credit for a particular type
//     (2) And return credit to RTLH one by one
//
//  Interface assumtions
//     (1) tlp_td is asserted with tlp_eot and tlp_dv to indicate the last tlp_dv was caused by ECRC data only.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module radm_crd_return (
//---------- inputs --------------
    core_clk,
    core_rst_n,
    cfg_radm_q_mode,
    tlp_hv,
    tlp_dv,
    tlp_eot,
    tlp_abort,
    tlp_vc,
    tlp_type,
    tlp_td,
    tlp_dwen,

// ------ Outputs ------
    // Credit return interface
    radm_rtlh_ph_ca,
    radm_rtlh_pd_ca,
    radm_rtlh_nph_ca,
    radm_rtlh_npd_ca,
    radm_rtlh_cplh_ca,
    radm_rtlh_cpld_ca
);
// ----------------------------------------------------------------------------
// --- Parameters
// ----------------------------------------------------------------------------
parameter INST          = 0;        // The uniquifying parameter for each port logic instance.
parameter NW            = `CX_NW;   // Number of 32-bit dwords handled by the datapath each clock.
parameter NVC           = `CX_NVC;  // Number of VC designed to support
parameter DW            = (32*NW);  // Width of datapath in bits.
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)

parameter P_TYPE        = 0;
parameter NP_TYPE       = 1;
parameter CPL_TYPE      = 2;

parameter STOREFWD      = `CX_QMODE_STORE_N_FWD;
parameter CUTTHRU       = `CX_QMODE_CUT_THROUGH;
parameter BYPASS        = `CX_QMODE_BYPASS;

parameter all_vc_num    = {3'h7, 3'h6, 3'h5, 3'h4, 3'h3, 3'h2, 3'h1, 3'h0};

// Indicates the width of the "*d_ca" signals indicating how many data credits have been released per-VC per cycle.
parameter  DCA_WD       = `CX_LOGBASE2(NW/4+1);

// -------------------------------- Inputs ------------------------------------
//
input                   core_clk;               // Core clock
input                   core_rst_n;             // Core system reset

input [(NVC*3*3)-1:0]   cfg_radm_q_mode;        // Indicates that queue is in bypass, cut-through, and store-forward mode for posted TLP.
                                                // 3bits per VC, bit0 for bypass, bit1 for cut-through and bit2 for store and forward
                        // 3bits for type posted, non posted and completion


input                   tlp_hv;
input                   tlp_dv;
input                   tlp_eot;
input                   tlp_abort;
input   [2:0]           tlp_vc;
input   [2:0]           tlp_type;
input                   tlp_td;                 // Indicates TLP has ECRC and that is causing an extra tlp_dv.  Credits shouldn't be returned for this tlp_dv.
input   [NW-1:0]        tlp_dwen;

// -------------------------Outputs ------------------------------------
// Credit return output signals.
output  [NVC-1:0]       radm_rtlh_ph_ca;
output  [DCA_WD*NVC-1:0]radm_rtlh_pd_ca;
output  [NVC-1:0]       radm_rtlh_nph_ca;
output  [DCA_WD*NVC-1:0]radm_rtlh_npd_ca;
output  [NVC-1:0]       radm_rtlh_cplh_ca;
output  [DCA_WD*NVC-1:0]radm_rtlh_cpld_ca;

// -------------------------------- Local Parameters ------------------------------------
//
// -------------------------------- Internal Signals  ------------------------------------
reg     [2:0]           latched_tlp_vc;
reg     [2:0]           latched_tlp_type;

wire  [23:0] ALL_VC_NUM;
assign ALL_VC_NUM = all_vc_num;

// Latch the current packet type and VC so we have them to distribute the credits
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n) begin
    latched_tlp_type    <= #TP  3'b0;
    latched_tlp_vc      <= #TP  3'b0;
end else begin
    latched_tlp_type    <= #TP  tlp_hv ? tlp_type : latched_tlp_type;
    latched_tlp_vc      <= #TP  tlp_hv ? tlp_vc : latched_tlp_vc;
end


// ---------------------------------------------------------
// Credit return calcuation logic
// ---------------------------------------------------------
// /////
// Return Flow Control Credits.
/////
  // The RTLH returns credits.  For Cut-through mode, if this eot signal is asserted without either h_ca or d_ca
  // assertion, the RTLH knows that the packet has been aborted and to NOT return credtis in this case.
  // Furthermore, we assume that the RTLH knows the width of our data path.  If our data path is 128-bits,
  // this means that each pulse on the x_ca signal is a full credit.  However, if our data path is 32-bits,
  // the RTLH must accumulate credits and return the appropriate values.
reg             hv;
reg             dv;
reg             eot;
reg  [NW-1:0]   dwen;
reg             abort;
reg             td;

reg     [1:0]   data_cdt_cycles;
wire    [1:0]   cycles_per_cdt;
assign cycles_per_cdt = ((16*8)/DW)-1; // Number of cycles of data which consume 1 credit.

always@(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n) begin
        hv              <= #TP 0;
        dv              <= #TP 0;
        eot             <= #TP 0;
        dwen            <= #TP 0;
        td              <= #TP 0;
        abort           <= #TP 0;
        data_cdt_cycles <= #TP 0;
    end else begin
        // Determine when to return header credits.
        hv              <= #TP tlp_hv && !tlp_abort;

        // Determine when to return data credits.
        if (tlp_dv && !tlp_abort) begin
            // Here we check to see if there are partial credits that need to be returned at eot, otherwise the tlp_td signal suppresses returing credit for the digest field
            dv          <= #TP (tlp_eot && ( !tlp_td || (tlp_td && |data_cdt_cycles) )) || (data_cdt_cycles == cycles_per_cdt) ;
        end
        else
            dv          <= #TP 0;


        // delay tlp_eot and tlp_dwen to line up with hv and dv
        eot             <= #TP tlp_eot;
        dwen            <= #TP tlp_dwen;
        td              <= #TP tlp_td;
        abort           <= #TP tlp_abort;


        // This counter accumulates partial credits in 32 & 64 bit architectures.
        if (tlp_dv && !tlp_abort)
            if (tlp_eot || (data_cdt_cycles == cycles_per_cdt)) begin
                data_cdt_cycles <= #TP 0;
            end else begin
                data_cdt_cycles <= #TP data_cdt_cycles + 1;
            end
        else if (tlp_dv && tlp_abort) begin
            data_cdt_cycles <= #TP 0;
        end
    end
end



///////////////////////
// Cut Through Logic //
///////////////////////
wire    [DCA_WD*NVC-1:0]ct_d_ca_p;                                  // Credit allocated (posted data)
wire    [DCA_WD*NVC-1:0]ct_d_ca_np;                                 // Credit allocated (non-posted data)
wire    [DCA_WD*NVC-1:0]ct_d_ca_cpl;                                // Credit allocated (completion data)
wire    [NVC-1:0]       ct_h_ca_p;                                  // Credit allocated (posted header)
wire    [NVC-1:0]       ct_h_ca_np;                                 // Credit allocated (non-posted header)
wire    [NVC-1:0]       ct_h_ca_cpl;                                // Credit allocated (completion header)

    assign ct_h_ca_p = 0;
    assign ct_d_ca_p = 0;
    assign ct_h_ca_np = 0;
    assign ct_d_ca_np = 0;
    assign ct_h_ca_cpl = 0;
    assign ct_d_ca_cpl = 0;

wire    [NVC-1:0] p_bypass_mode;
wire    [NVC-1:0] np_bypass_mode;
wire    [NVC-1:0] cpl_bypass_mode;
wire    [NVC-1:0] p_cutthru_mode;
wire    [NVC-1:0] np_cutthru_mode;
wire    [NVC-1:0] cpl_cutthru_mode;
wire    [NVC-1:0] p_storefwd_mode;
wire    [NVC-1:0] np_storefwd_mode;
wire    [NVC-1:0] cpl_storefwd_mode;

assign p_bypass_mode       = Select_one_bit_per_vc ( Select_one_type_per_vc(cfg_radm_q_mode, P_TYPE   ), BYPASS   );
assign np_bypass_mode      = Select_one_bit_per_vc ( Select_one_type_per_vc(cfg_radm_q_mode, NP_TYPE  ), BYPASS   );
assign cpl_bypass_mode     = Select_one_bit_per_vc ( Select_one_type_per_vc(cfg_radm_q_mode, CPL_TYPE ), BYPASS   );
assign p_cutthru_mode      = Select_one_bit_per_vc ( Select_one_type_per_vc(cfg_radm_q_mode, P_TYPE   ), CUTTHRU  );
assign np_cutthru_mode     = Select_one_bit_per_vc ( Select_one_type_per_vc(cfg_radm_q_mode, NP_TYPE  ), CUTTHRU  );
assign cpl_cutthru_mode    = Select_one_bit_per_vc ( Select_one_type_per_vc(cfg_radm_q_mode, CPL_TYPE ), CUTTHRU  );
assign p_storefwd_mode     = Select_one_bit_per_vc ( Select_one_type_per_vc(cfg_radm_q_mode, P_TYPE   ), STOREFWD );
assign np_storefwd_mode    = Select_one_bit_per_vc ( Select_one_type_per_vc(cfg_radm_q_mode, NP_TYPE  ), STOREFWD );
assign cpl_storefwd_mode   = Select_one_bit_per_vc ( Select_one_type_per_vc(cfg_radm_q_mode, CPL_TYPE ), STOREFWD );

// Module outputs

reg   [NVC-1:0]    sf_h_ca_p;
reg   [NVC-1:0]    sf_d_ca_p;
reg   [NVC-1:0]    sf_h_ca_np;
reg   [NVC-1:0]    sf_d_ca_np;
reg   [NVC-1:0]    sf_h_ca_cpl;
reg   [NVC-1:0]    sf_d_ca_cpl;

always@(latched_tlp_vc or latched_tlp_type or hv or dv)
begin
    sf_h_ca_p     = 0;
    sf_d_ca_p     = 0;
    sf_h_ca_np    = 0;
    sf_d_ca_np    = 0;
    sf_h_ca_cpl   = 0;
    sf_d_ca_cpl   = 0;

    if (latched_tlp_type[P_TYPE]) begin
    sf_h_ca_p   = select_sf_ca(latched_tlp_vc,hv);
    sf_d_ca_p   = select_sf_ca(latched_tlp_vc,dv);
    end else if (latched_tlp_type[NP_TYPE]) begin
    sf_h_ca_np  = select_sf_ca(latched_tlp_vc,hv);
    sf_d_ca_np  = select_sf_ca(latched_tlp_vc,dv);
    end else if (latched_tlp_type[CPL_TYPE]) begin
    sf_h_ca_cpl = select_sf_ca(latched_tlp_vc,hv);
    sf_d_ca_cpl = select_sf_ca(latched_tlp_vc,dv);
    end
end

assign radm_rtlh_ph_ca     = ~p_bypass_mode   & ( (p_cutthru_mode   & ct_h_ca_p  ) | (p_storefwd_mode   & sf_h_ca_p  ) );
assign radm_rtlh_pd_ca     = ~p_bypass_mode   & ( (p_cutthru_mode   & ct_d_ca_p  ) | (p_storefwd_mode   & sf_d_ca_p  ) );
assign radm_rtlh_nph_ca    = ~np_bypass_mode  & ( (np_cutthru_mode  & ct_h_ca_np ) | (np_storefwd_mode  & sf_h_ca_np ) );
assign radm_rtlh_npd_ca    = ~np_bypass_mode  & ( (np_cutthru_mode  & ct_d_ca_np ) | (np_storefwd_mode  & sf_d_ca_np ) );
assign radm_rtlh_cplh_ca   = ~cpl_bypass_mode & ( (cpl_cutthru_mode & ct_h_ca_cpl) | (cpl_storefwd_mode & sf_h_ca_cpl) );
assign radm_rtlh_cpld_ca   = ~cpl_bypass_mode & ( (cpl_cutthru_mode & ct_d_ca_cpl) | (cpl_storefwd_mode & sf_d_ca_cpl) );

// Selects the mode bits for a specific type from all vcs
function automatic [(NVC*3)-1:0] Select_one_type_per_vc;
input   [(NVC*9)-1:0]   vector;
input   [1:0]           q_type;
integer vc;
integer bits;
begin
    Select_one_type_per_vc = 0;
    for (vc=0; vc<NVC; vc=vc+1)
        for (bits=0; bits<3; bits=bits+1) begin
            if      (q_type == 2'h0) Select_one_type_per_vc[(vc*3)+bits] = vector[(vc*9)+(0*3)+bits];
            else if (q_type == 2'h1) Select_one_type_per_vc[(vc*3)+bits] = vector[(vc*9)+(1*3)+bits];
            else                     Select_one_type_per_vc[(vc*3)+bits] = vector[(vc*9)+(2*3)+bits];
        end
end
endfunction

// Selects a specific mode bit for each vc used after Select_one_type_per_vc
function automatic [NVC-1:0] Select_one_bit_per_vc;
input   [(NVC*3)-1:0]   vector;
input   [1:0]           bit_select;

integer i;
begin
    Select_one_bit_per_vc = 0;
    for (i=0; i<NVC; i=i+1) begin
        if      (bit_select == 2'h0) Select_one_bit_per_vc[i] = vector[(i*3)+0];
        else if (bit_select == 2'h1) Select_one_bit_per_vc[i] = vector[(i*3)+1];
        else                         Select_one_bit_per_vc[i] = vector[(i*3)+2];
    end
end
endfunction

function automatic [NVC-1:0] select_sf_ca;
input    [2:0] latched_tlp_vc;
input              valid;
begin
  select_sf_ca = 0;
    case (latched_tlp_vc)
          3'b000:  select_sf_ca = {{(NVC-1){1'b0}},valid};
    endcase // case
end
endfunction


endmodule

