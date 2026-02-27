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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_cpl_lut_vec_extractor.sv#5 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Extracts LUT_VEC and LUT_VEC2 from CPL_LUT structure
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Adm/radm_defs_pkg.svh"


 module radm_cpl_lut_vec_extractor
import radm_defs_pkg::*;
(
// ---- inputs ---------------
    core_clk,
    core_rst_n,

    rtlh_radm_hdr,
    cpl_lut,
    cpl_lut2,


// ---- outputs ---------------
    lut_addr,
    lut_vec
    ,lut_vec2

);

localparam TAG_SIZE               = `CX_TAG_SIZE;

parameter NP_REQ_TYPE_INDEX = 0;

parameter INST                    = 1'b0;
parameter NB                      = `CX_NB;                  // Number of symbols (bytes) per clock cycle
parameter CPL_LUT_DEPTH           = `CX_MAX_TAG + 1
                                    ;                       // number of max tag that this core is configured to run

parameter NF                      = `CX_NFUNC;              // Number of Physical Functions
parameter NVF                     = `CX_NVFUNC;             // Number of virtual functions
parameter NW                      = `CX_NW;                 // Number of Dwords in datapath
localparam FX_TLP                 = `CX_FX_TLP;             // Number of TLPs that can be processed in a single cycle after the formation block
localparam PF_WD                  = `CX_NFUNC_WD;           // Number of bits needed to address the physical functions
localparam VFI_WD                 = `CX_LOGBASE2(NVF);      // number of bits needed to represent the vf index [0 ... NVF-1]
localparam VF_WD                  = `CX_LOGBASE2(NVF) + 1;  // number of bits needed to represent the vf number plus one bit to indicate vf_active, i.e. if the pf,vf pair indicates a pf only or a vf within a pf
parameter FUNC_NUM_INDEX          =  PF_WD;
parameter BYTECNT_INDEX           = FUNC_NUM_INDEX;
// ## CPL_LUT2 ##
parameter LOW_ADDR_WD2            = 2;
parameter BYTECNT_WD2             = 12;
parameter LOW_ADDR_INDEX2         = 0;
parameter BYTECNT_INDEX2          = LOW_ADDR_WD2;
parameter CPL_ENTRY_WIDTH2        = LOW_ADDR_WD2 + BYTECNT_WD2;
parameter TC_INDEX                = 3 + BYTECNT_INDEX;

parameter ATTR_INDEX = 2 + TC_INDEX;

parameter CPL_ENTRY_WIDTH         = NP_REQ_TYPE_INDEX
                                    ; // This parameter is passing up from another module, Width of completion entry (length, attribute, Traffic Class, func number)

parameter CPL_LUT_PTR_WD          = `CX_LUT_PTR_WIDTH;        // Number of bits needed to index completion table

parameter TP                      = `TP;                      // Clock to Q delay (simulator insurance)
parameter HW                      = 128;                      // Width of header in bits.
// Width of the header protection bus. 0 if RAS is not enabled!
parameter HDR_PROT_WD             = `CX_RAS_PCIE_HDR_PROT_WD;

parameter RADM_CPL_LUT_PIPE_EN    = `CX_RADM_CPL_LUT_PIPE_EN_VALUE;
parameter RADM_FILTER_TO_LUT_PIPE    = 0;

// ---- inputs ---------------
input                           core_clk;
input                           core_rst_n;

input [HW+HDR_PROT_WD-1:0]      rtlh_radm_hdr;

input [CPL_ENTRY_WIDTH-1:0]     cpl_lut [CPL_LUT_DEPTH-1:0];
input [CPL_ENTRY_WIDTH2-1:0]    cpl_lut2 [CPL_LUT_DEPTH-1:0];


// ---- outputs ---------------
output  [CPL_LUT_PTR_WD-1:0]    lut_addr;

output   [CPL_ENTRY_WIDTH-1:0]  lut_vec;
output   [CPL_ENTRY_WIDTH2-1:0] lut_vec2;

wire    [TAG_SIZE-1:0]          rcvd_cpl_tlp_tag;

// ----------------------------------------------------------
// Decode Logic
// ----------------------------------------------------------

// ### TAG extraction ###
assign rcvd_cpl_tlp_tag         =  rtlh_radm_hdr[87:80];

// ### Extract LUT Address ###
assign lut_addr                     = rcvd_cpl_tlp_tag[CPL_LUT_PTR_WD -1:0];

// spyglass disable_block W468
// SMD: Variable/Signal 'cpl_lut' is indexed by 'lut_addr' which cannot index the full range of this vector.
// SJ: The completion_lut (cpl_lut) is oversized by one location to facilitate a park location which should never be addressed. This is necessary //     due to the implementation chosen for the timeout feature

// ### LUT_VEC extraction ###
assign  lut_vec                    = cpl_lut[lut_addr];

reg   [CPL_ENTRY_WIDTH2-1:0] lut_vec2;
always @(*) begin
   lut_vec2 = cpl_lut2[lut_addr];

end
// spyglass enable_block W468
endmodule
