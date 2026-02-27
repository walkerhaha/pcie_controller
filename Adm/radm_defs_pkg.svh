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
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_defs_pkg.svh#1 $
// -------------------------------------------------------------------------

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

`ifndef __GUARD__RADM_DEFS_PKG__SVH__
`define __GUARD__RADM_DEFS_PKG__SVH__


package radm_defs_pkg;

localparam NP_REQ_TYPE_WD = $clog2(     1
                                       +1
                  +1



                                       );

typedef enum logic[NP_REQ_TYPE_WD-1:0]   {
                                           NP_REQ_MEMRD 
                                          ,NP_REQ_IO 
                     ,NP_REQ_CFG



} np_req_type_t;

localparam NP_REQ_MEMRD_INDEX = 0;
localparam NP_REQ_IO_INDEX =  1;
localparam NP_REQ_CFG_INDEX =    NP_REQ_IO_INDEX        +1;
localparam NP_REQ_ATS_INDEX =    NP_REQ_CFG_INDEX;
localparam NP_REQ_ATOMIC_INDEX = NP_REQ_ATS_INDEX;
localparam NP_REQ_DMWR_INDEX =   NP_REQ_ATOMIC_INDEX;
localparam NP_REQ_TYPE_DECODED_WD = NP_REQ_DMWR_INDEX + 1;

function automatic logic[NP_REQ_TYPE_DECODED_WD-1:0] radm_np_req_type_decode(np_req_type_t req_type);
logic [NP_REQ_TYPE_DECODED_WD-1:0] x;
    unique case(req_type)
                                    NP_REQ_IO     : x = 1 << NP_REQ_IO_INDEX;
               NP_REQ_CFG    : x = 1 << NP_REQ_CFG_INDEX;



                                    default       : x = 1 << NP_REQ_MEMRD_INDEX; //NP_REQ_MEMRD
    endcase // case (req_type)
    return x;
endfunction // radm_np_req_type_decode

function automatic np_req_type_t radm_np_req_type_encode(logic[NP_REQ_TYPE_DECODED_WD-1:0] dec);
    np_req_type_t enc;
    unique case(1'b1)
                                      dec[NP_REQ_MEMRD_INDEX] : enc  = NP_REQ_MEMRD;
                 dec[NP_REQ_CFG_INDEX] : enc    = NP_REQ_CFG; 
 
 
 
                                      default : enc                  = NP_REQ_IO;
    endcase // unique case (1'b1)
    return enc;
endfunction // radm_np_req_type_encode

endpackage : radm_defs_pkg

`endif // __GUARD__CLIENT_DEFS_PKG__SVH__
