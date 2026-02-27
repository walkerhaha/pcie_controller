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
// ---    $DateTime: 2020/01/17 02:36:30 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_qformation.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module takes the output of 2 radm_filter modules operating in 
// --- parallel and ensures that the output of the filters is presented to
// --- the receive queues in the same order that the packets were received by
// --- the core.
// --- When both filters are generating valid data at the same time, the
// --- flt_q_formation input is used to determine which filter contains the
// --- packet that was received first by the core (0 = filter[0],
// --- 1 = filter[1]).
// --- As the filters each output 256-bits of packet data (512 bits in total
// --- excluding parity), this module selects the valid data and supplies up 
// --- to 256-bits of this data to be written to the queue. (Note: There can never 
// --- be more than 256-bits of valid data available on the 512-bit flt_q_data 
// --- input at any time)
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module radm_qformation (
// -- inputs --
    core_clk,
    core_rst_n,
    flt_q_dv,
    flt_q_hv,
    flt_q_eot,
    flt_q_data,
    flt_q_header,
    flt_q_dwen,
    flt_q_dllp_abort,
    flt_q_tlp_abort,
    flt_q_ecrc_err,
    flt_q_parerr,
    flt_q_tlp_type,
    flt_q_seg_num,
    flt_q_vc,
// -- outputs --
    flt_qform_dv,             
    flt_qform_hv,            
    flt_qform_eot,            
    flt_qform_data,           
    flt_qform_header,            
    flt_qform_dwen,           
    flt_qform_dllp_abort,       
    flt_qform_tlp_abort,
    flt_qform_ecrc_err,       
    flt_qform_parerr,        
    flt_qform_seg_num,
    flt_qform_vc,
    flt_qform_tlp_type       
);

parameter TP                    = `TP;                  // Clock to Q delay (simulator insurance)
parameter INST                  = 0;                    // The uniquifying parameter for each port logic instance.
parameter NW                    = `CX_NW;               // Number of 32-bit dwords handled by the datapath each clock.
parameter NVC                   = `CX_NVC;              // Number of virtual channels
parameter HW                    = `FLT_Q_HDR_WIDTH;     // Header width
parameter DW                    = (32*NW);              // Width of datapath in bits.
parameter DATA_PAR_WD           = `TRGT_DATA_PROT_WD;

// protection code covers the complete header
parameter RX_HDR_PROT_WD        = `CX_FLT_OUT_PROT_WD;

parameter SEG_WIDTH             = `CX_SEG_WIDTH;

localparam FX_TLP               = `CX_FX_TLP;            // Number of TLPs that can be processed in a single cycle after the formation block
localparam Q_DW                 = (DW+DATA_PAR_WD) >> 1; // Width of Data for Queues

// -------------- Inputs ---------------
input                                       core_clk;
input                                       core_rst_n;
input  [(FX_TLP*NVC)-1:0]                   flt_q_dv;             // {flt_q_dv[2*NVC-1:NVC],    flt_q_dv[NVC-1:0]}
input  [(FX_TLP*NVC)-1:0]                   flt_q_hv;             // {flt_q_hv[2*NVC-1:NVC],    flt_q_hv[NVC-1:0]}
input  [(FX_TLP*NVC)-1:0]                   flt_q_eot;            // {flt_q_eot[2*NVC-1:NVC],   flt_q_eot[NVC-1:0]}
input  [(FX_TLP*(DW+DATA_PAR_WD))-1:0]      flt_q_data;           // {flt_q_data[511:256],      flt_q_data[255:0]}  
input  [(FX_TLP*(HW+RX_HDR_PROT_WD))-1:0]   flt_q_header;         // {flt_q_header[255:HW],    flt_q_header[127:0]} 
input  [(FX_TLP*NW)-1:0]                    flt_q_dwen;           // {flt_q_dwen[15:8],         flt_q_dwen[7:0]} 
input  [FX_TLP-1:0]                         flt_q_dllp_abort;     // {flt_q_dllp_abort[1],      flt_dllp_abort[0]} 
input  [FX_TLP-1:0]                         flt_q_tlp_abort;      // {flt_q_tlp_abort[1],       flt_q_tlp_abort[0]} 
input  [FX_TLP-1:0]                         flt_q_ecrc_err;       // {flt_q_ecrc_err[1],        flt_q_ecrc_err[0]} 
input  [FX_TLP-1:0]                         flt_q_parerr;         // {flt_q_parerr[1],          flt_q_parerr[0]}
input  [(FX_TLP*3)-1:0]                     flt_q_tlp_type;       // {flt_q_tlp_type[5:3],      flt_q_tlp_type[2:0]}
input  [(FX_TLP*SEG_WIDTH)-1:0]             flt_q_seg_num;
input  [(FX_TLP*3)-1:0]                     flt_q_vc;
// -------------- Outputs --------------
output [(FX_TLP*NVC)-1:0]                   flt_qform_dv;         // {flt_qform_dv[2*NVC-1:NVC],    flt_qform_dv[NVC-1:0]}
output [(FX_TLP*NVC)-1:0]                   flt_qform_hv;         // {flt_qform_hv[2*NVC-1:NVC],    flt_qform_hv[NVC-1:0]}
output [(FX_TLP*NVC)-1:0]                   flt_qform_eot;        // {flt_qform_eot[2*NVC-1:NVC],   flt_qform_eot[NVC-1:0]}
output [DW+DATA_PAR_WD-1:0]                 flt_qform_data;       // {flt_qform_data[255:HW],      flt_qform_data[127:0]}  
output [(FX_TLP*(HW+RX_HDR_PROT_WD))-1:0]  flt_qform_header;     // {flt_qform_header[255:HW],    flt_qform_header[127:0]} 
output [NW-1:0]                             flt_qform_dwen;       // {flt_qform_dwen[15:8],         flt_qform_dwen[7:0]} 
output [FX_TLP-1:0]                         flt_qform_dllp_abort; // {flt_qform_dllp_abort[1],      radm_qformllp_err[0]} 
output [FX_TLP-1:0]                         flt_qform_tlp_abort;  // {flt_qform_tlp_abort[1],       flt_qform_tlp_abort[0]} 
output [FX_TLP-1:0]                         flt_qform_ecrc_err;   // {flt_qform_ecrc_err[1],        flt_qform_ecrc_err[0]} 
output [FX_TLP-1:0]                         flt_qform_parerr;     // {flt_qform_parerr[1],          flt_qform_parerr[0]}
output [(FX_TLP*SEG_WIDTH)-1:0]             flt_qform_seg_num;
output [(FX_TLP*3)-1:0]                     flt_qform_vc;
output [(FX_TLP*3)-1:0]                     flt_qform_tlp_type;   // {flt_qform_tlp_type[5:3],      flt_qform_tlp_type[2:0]}

// Module is a pass-through block for non-256-bit architectures
assign flt_qform_dv                = flt_q_dv;
assign flt_qform_hv                = flt_q_hv;
assign flt_qform_eot               = flt_q_eot;
assign flt_qform_data              = flt_q_data[DW+DATA_PAR_WD-1:0];
assign flt_qform_header            = flt_q_header;
assign flt_qform_dwen              = flt_q_dwen[NW-1:0];
assign flt_qform_dllp_abort        = flt_q_dllp_abort;
assign flt_qform_tlp_abort         = flt_q_tlp_abort;
assign flt_qform_ecrc_err          = flt_q_ecrc_err;
assign flt_qform_parerr            = flt_q_parerr;
assign flt_qform_seg_num           = flt_q_seg_num ;
assign flt_qform_vc                = flt_q_vc ;
assign flt_qform_tlp_type          = flt_q_tlp_type;

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule
