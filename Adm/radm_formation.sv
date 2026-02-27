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
// ---    $DateTime: 2020/09/11 01:49:10 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_formation.sv#7 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Recieve Application Dependent Module (endpoint
// --- version. It is intended for an end device application interface with
// --- the cxpl core.
// --- This module contains:
// --- (1) interface convertion between 32bit architecture, 64bit and
// ---     128bit architecture.
// ---     It forms one interface that radm_filter* will have to deal
// ---     with. It isolates the filter* module from differences of the
// ---     interfaces between architectues.
// --- (2) For 256-bit Core with support for processing 2 TLPs per cycle, this 
// ---     module controls the routing of data from RTLH to 2 independent 
// ---     radm_filters operating in parallel
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module radm_formation(
// ---- inputs ---------------
    clk,
    rst_n,

    rtlh_radm_hv,
    rtlh_radm_hdr,
    rtlh_radm_dv,
    rtlh_radm_data,
    rtlh_radm_eot,
    rtlh_radm_dwen,
    rtlh_radm_dllp_err,
    rtlh_radm_malform_tlp_err,
    rtlh_radm_ecrc_err,
    rtlh_radm_ant_addr,
    rtlh_radm_ant_rid,
    cfg_io_match,
    cfg_config_above_match,
    cfg_bar_match,
    cfg_rom_match,
    cfg_mem_match,
    cfg_prefmem_match,

// ---- outputs ---------------
    form_filt_hv,
    form_filt_hdr,
    form_filt_dv,
    form_filt_data,
    form_filt_eot,
    form_filt_dwen,
    form_filt_dllp_err,
    form_filt_malform_tlp_err,
    form_filt_ecrc_err,
    form_filt_ant_addr,
    form_filt_ant_rid,
    form_filt_io_match,
    form_filt_config_above_match,
    form_filt_bar_match,
    form_filt_rom_match,
    form_filt_mem_match,
    form_filt_prefmem_match,
    form_par_err
);

parameter INST              = 0;                        // The uniquifying parameter for each port logic instance.
parameter NF                = `CX_NFUNC;                // Number of functions
parameter NW                = `CX_NW;                   // Number of 32-bit dwords handled by the datapath each clock.
parameter HW                = 128;                      // Header width
parameter DW                = (32*NW);                  // Width of datapath in bits.
parameter TP                = `TP;                      // Clock to Q delay (simulator insurance)
parameter RX_TLP            = `CX_RX_TLP;               // Number of TLPs that can be received in a single cycle
parameter FX_TLP            = `CX_FX_TLP;               // Number of TLPs that can be processed in a single cycle after the formation block
parameter PAR_CALC_WIDTH    = `DATA_BUS_PAR_CALC_WIDTH;
parameter DATA_PAR_WD       = `TRGT_DATA_PROT_WD;          // data bus parity width
parameter RX_HDR_PROT_WD    = `CX_RAS_PCIE_HDR_PROT_WD;
parameter NVF               = `CX_NVFUNC;               // Number of virtual functions

localparam VF_WD            = `CX_LOGBASE2(NVF) + 1;    // number of bits needed to represent the vf number plus one bit to indicate vf_active, i.e. if the pf,vf pair indicates a pf only or a vf within a pf
localparam DW_W_PAR         = DW+DATA_PAR_WD;
localparam HW_W_PAR         = HW+RX_HDR_PROT_WD;




// ---- inputs ---------------
input                                           clk;                        // Core clock
input                                           rst_n;                      // Core system reset
input   [RX_TLP-1:0]                            rtlh_radm_hv;               // When asserted; indicates the hdr valid
input   [RX_TLP*HW_W_PAR-1:0]                   rtlh_radm_hdr;              // hdr payload
input   [RX_TLP-1:0]                            rtlh_radm_dv;               // When asserted; indicates the payload is valid
input   [DW+DATA_PAR_WD-1:0]                    rtlh_radm_data;             // Packet data
input   [RX_TLP-1:0]                            rtlh_radm_eot;              // When asserted; indicates the tlp end
input   [NW-1:0]                                rtlh_radm_dwen;             // Data Bus DW Enable
input   [RX_TLP-1:0]                            rtlh_radm_dllp_err;         // Data Link Layer Error
input   [RX_TLP-1:0]                            rtlh_radm_malform_tlp_err;  // Malformed TLP Error
input   [RX_TLP-1:0]                            rtlh_radm_ecrc_err;         // ECRC Error
input   [(RX_TLP*64)-1:0]                       rtlh_radm_ant_addr;         // anticipated address (1 clock earlier)
input   [(RX_TLP*16)-1:0]                       rtlh_radm_ant_rid;          // anticipated RID (1 clock earlier)
input   [(FX_TLP*NF)-1:0]                       cfg_io_match;               // indication that tlp is within a IO BAR
input   [(FX_TLP*NF)-1:0]                       cfg_config_above_match;     // configuaration access belongs to the above our customer set address limit
input   [(FX_TLP*NF)-1:0]                       cfg_rom_match;              // indication that tlp is within a ROM BAR
input   [(FX_TLP*NF*6)-1:0]                     cfg_bar_match;              // indication that tlp is within a MEM BAR
input   [(FX_TLP*NF)-1:0]                       cfg_mem_match;              // memory match indication for RC device
input   [(FX_TLP*NF)-1:0]                       cfg_prefmem_match;          // prefetch memory match indication for RC device



// ---- outputs ---------------
output  [FX_TLP-1:0]                            form_filt_hv;               // Output Header Valid
output  [(FX_TLP*HW_W_PAR)-1:0]                 form_filt_hdr;              // Output Header
output  [FX_TLP-1:0]                            form_filt_dv;               // Output Data Valid
output  [(FX_TLP*(DW+DATA_PAR_WD))-1:0]         form_filt_data;             // Output Data
output  [FX_TLP-1:0]                            form_filt_eot;              // Output End of Transfer
output  [(FX_TLP*NW)-1:0]                       form_filt_dwen;             // Output Data Bus DW Enable
output  [FX_TLP-1:0]                            form_filt_dllp_err;         // Output Data Link Layer Error
output  [FX_TLP-1:0]                            form_filt_malform_tlp_err;  // Output Malformed TLP Error
output  [FX_TLP-1:0]                            form_filt_ecrc_err;         // Output ECRC Error
output  [(FX_TLP*64)-1:0]                       form_filt_ant_addr;         // Output anticipated address
output  [(FX_TLP*16)-1:0]                       form_filt_ant_rid;          // Output anticipated RID
output  [(FX_TLP*NF)-1:0]                       form_filt_io_match;         // indication that tlp is within a IO BAR
output  [(FX_TLP*NF)-1:0]                       form_filt_config_above_match; // configuaration access belongs to the above our customer set address limit
output  [(FX_TLP*NF)-1:0]                       form_filt_rom_match;        // indication that tlp is within a ROM BAR
output  [(FX_TLP*NF*6)-1:0]                     form_filt_bar_match;        // indication that tlp is within a MEM BAR
output  [(FX_TLP*NF)-1:0]                       form_filt_mem_match;        // memory match indication for RC device
output  [(FX_TLP*NF)-1:0]                       form_filt_prefmem_match;    // prefetch memory match indication for RC device
output  [FX_TLP-1:0]                            form_par_err;               // Output Header Parity Error Detected



// ---------------- Internal Design ----------------
wire    [FX_TLP-1:0]                   int_form_filt_hv;               // Output Header Valid
wire    [FX_TLP-1:0]                   int_form_filt_dv;               // Output Data Valid
wire    [FX_TLP-1:0]                   int_form_filt_eot;              // Output End of Transfer
wire    [FX_TLP-1:0]                   int_form_filt_malform_tlp_err;  // Output Malformed TLP Error
wire    [RX_TLP*HW_W_PAR-1:0]          rtlh_radm_hdr_int;
wire    [(FX_TLP*HW_W_PAR)-1:0]        form_filt_hdr;
wire    [FX_TLP-1:0]                   form_par_err;


   wire    [HW-1:0]                     filt_hdr[RX_TLP-1:0];

// Assign outputs:
assign form_filt_hv     = int_form_filt_hv;
assign form_filt_dv     = int_form_filt_dv;
assign form_filt_eot    = int_form_filt_eot;
assign form_filt_malform_tlp_err = int_form_filt_malform_tlp_err;








// ----------------------------- START OF 64-bit architecture  ------------------------------
//
// 64-bit mode (header coming from the core is always 2 cycles. Register the first
//
reg [1:0] state;
parameter S_IDLE     = 2'b00;
parameter S_HDR1     = 2'b01;
parameter S_1ST_PYLD = 2'b10;
parameter S_PYLD     = 2'b11;

// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Disable this check on legacy code. 
always @(posedge clk or negedge rst_n)
    if (!rst_n)
       state              <= #TP S_IDLE;
    else
       case (state)
       S_IDLE:
          if (rtlh_radm_hv & !rtlh_radm_eot)
             state        <= #TP S_HDR1;
       S_HDR1:
          if (rtlh_radm_eot)
             state        <= #TP S_IDLE;
          else if (rtlh_radm_hv )
             state        <= #TP S_1ST_PYLD;
       S_1ST_PYLD:
          if (rtlh_radm_eot)
             state        <= #TP S_IDLE;
          else if (rtlh_radm_dv)
             state        <= #TP S_PYLD;
         // Since this following branch is a protection to a unexpected
         // condition, normally, we are not able to create this condition.
         // In order to get correct coverage analysis, we pragma off this
         // line
         
          else if (rtlh_radm_hv & !rtlh_radm_eot)  // an error condition
             state        <= #TP S_HDR1;
         
       S_PYLD:
          if (rtlh_radm_eot)
             state        <= #TP S_IDLE;
         
          else if (rtlh_radm_hv & !rtlh_radm_eot)  // an error condition
             state        <= #TP S_HDR1;
         
// since all values of state are fully decoded in this case statement, this default branch is unreachable.
//       default:
//             state        <= #TP S_IDLE;
       endcase
// spyglass enable_block STARC05-2.11.3.1

reg [127:0]           latchd_hdr;

always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      latchd_hdr                                          <= #TP 0;
    end else begin
        if (state == S_IDLE) begin
            latchd_hdr[63:0]                                <= #TP  rtlh_radm_data[63:0];
        end else if (state == S_HDR1) begin
            latchd_hdr[127:64]                              <= #TP  rtlh_radm_data[63:0];
        end
    end



//wire  [FX_TLP-1:0]  form_filt_hv;
assign int_form_filt_hv          = (rtlh_radm_hv & rtlh_radm_eot) | ((state == S_1ST_PYLD) & rtlh_radm_dv);
assign int_form_filt_dv          = rtlh_radm_dv;
assign filt_hdr[0]           = ((state == S_HDR1) & rtlh_radm_eot) ? {rtlh_radm_data[63:0], latchd_hdr[63:0]} : latchd_hdr;


// Pass Through the following signals
assign form_filt_ant_addr           = rtlh_radm_ant_addr;
assign form_filt_ant_rid            = rtlh_radm_ant_rid;
assign form_filt_data               = rtlh_radm_data;
assign int_form_filt_eot                = rtlh_radm_eot;
assign form_filt_dwen               = rtlh_radm_dwen;
assign form_filt_dllp_err           = rtlh_radm_dllp_err;
assign int_form_filt_malform_tlp_err    = rtlh_radm_malform_tlp_err;
assign form_filt_ecrc_err           = rtlh_radm_ecrc_err;


// ----------------------------- END OF 64-bit architecture  ------------------------------




assign rtlh_radm_hdr_int = rtlh_radm_hdr;
assign form_par_err  = 0;
assign form_filt_hdr = filt_hdr[0];


// Routing of BAR Matching Signals
// For 32-bit, 64-bit, 128-bit and 256-bit Phase 1 Architectures this block is
// a pass through block.
// For 256-bit Phase 2 Architecture it is necessary to re-order the BAR
// matching buses to route the correct BAR matching singals to each
// radm_filter on a per TLP basis
wire    [(FX_TLP*NF)-1:0]                    form_filt_io_match;
wire    [(FX_TLP*NF)-1:0]                    form_filt_config_above_match;
wire    [(FX_TLP*NF)-1:0]                    form_filt_rom_match;
wire    [(FX_TLP*NF*6)-1:0]                  form_filt_bar_match;
wire    [(FX_TLP*NF)-1:0]                    form_filt_mem_match;
wire    [(FX_TLP*NF)-1:0]                    form_filt_prefmem_match;

// Pass Through BAR Matching Signals
assign form_filt_io_match           =   cfg_io_match;
assign form_filt_config_above_match =   cfg_config_above_match;
assign form_filt_rom_match          =   cfg_rom_match;
assign form_filt_bar_match          =   cfg_bar_match;
assign form_filt_mem_match          =   cfg_mem_match;
assign form_filt_prefmem_match      =   cfg_prefmem_match;





endmodule

