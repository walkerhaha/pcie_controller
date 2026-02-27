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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_reg_decode.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module decodes the local bus address into the different CDM
// --- register blocks (default values):
// --- Configuration Regs       : 0x0 - 0x3F
// --- Capabilities Config Regs : 0x40 - 0xFF
// --- Extended Config Regs     : 0x100 - 0x1FF (`ECFG_REG_OFFSET)
// --- Port Logic Regs          : 0x700 - 0x7FF (`PL_REG_OFFSET)
// --- CRGB EDMA  Regs          : 0x970 - 0xB2C (`CRGB_REG_OFFSET)
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_reg_decode(
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    lbc_cdm_addr,
    lbc_cdm_cs,
    pl_reg_ack,
    pl_reg_data,
    cfg_reg_ack,
    cfg_reg_data,
    cfg_cap_reg_ack,
    cfg_cap_reg_data,
    ecfg_reg_ack,
    ecfg_reg_data,

// -- outputs --
    pl_reg_sel,
    cfg_reg_sel,
    cfg_cap_reg_sel,
    ecfg_reg_sel,
    cdm_pf_ecfg_addr,
   lbc_cdm_dbi2,
    cdm_lbc_data,
    cdm_lbc_ack
);
parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
parameter NF            = `CX_NFUNC;            // number of functions
parameter PF_WD         = `CX_NFUNC_WD;         // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise

// ----- Inputs ---------------
input                    core_clk;              // Core clock
input                    non_sticky_rst_n;      // Reset for non-sticky registers

input   [31:0]           lbc_cdm_addr;          // Address of resource being accessed
input   [NF-1:0]         lbc_cdm_cs;            // bus strobe (indicates an active bus cycle)
input                    pl_reg_ack;
input   [31:0]           pl_reg_data;           // Returning data from Port Logic Registers
input   [NF-1:0]         cfg_reg_ack;
input   [(32*NF)-1:0]    cfg_reg_data;          // Returning data from Configuration Registers
input   [NF-1:0]         cfg_cap_reg_ack;
input   [(32*NF)-1:0]    cfg_cap_reg_data;      // Returning data from Configuration Capabilities Registers
input   [NF-1:0]         ecfg_reg_ack;
input   [(32*NF)-1:0]    ecfg_reg_data;         // Returning data from Extended Configuration Registers


input                             lbc_cdm_dbi2;



// ----- Outputs ---------------
output                   pl_reg_sel;            // access port logic registers
output  [NF-1:0]         cfg_reg_sel;           // access cfg registers
output  [NF-1:0]         cfg_cap_reg_sel;       // access cfg capabilities registers
output  [NF-1:0]         ecfg_reg_sel;          // access extended cfg registers
output  [31:0]           cdm_pf_ecfg_addr;      // Address of resource being accessed
output  [(32*NF-1):0]    cdm_lbc_data;          // Data back from CDM
output  [NF-1:0]         cdm_lbc_ack;           // Acknowledge - indicates completion, read data is valid

// Registers and wires
wire                     pl_reg_sel;
wire    [NF-1:0]         cfg_reg_sel;
wire    [NF-1:0]         cfg_cap_reg_sel;
wire    [NF-1:0]         ecfg_reg_sel;
wire    [(32*NF)-1:0]    cdm_lbc_data;
wire    [NF-1:0]         cdm_lbc_ack;

wire    [(32*NF)-1:0]    cdm_pf_data;
wire    [NF-1:0]         cdm_pf_ack;
wire    [31:0]           cdm_pf_ecfg_addr; 

wire            pl_reg_space;
wire            cfg_reg_space;
wire            ecfg_reg_space;
wire            cdm_vf_vf_active;
wire            hit_pf_reg_space;


wire [NF-1:0]         int_pl_reg_ack;
wire [NF-1:0]         int_no_ack;


// =============================================================================
// Address Decode space for 4K config. space
// (1) Control registers (including Port logic) in configuration space: OFFSET = `PL_REG_OFFSET
// (2) PCIE Configuration space register space: OFFSET = `ECFG_REG_OFFSET
//    --- Address 0h and FFh: PCI Configuration Space for Legacy OS
//         (a) 0-3Fh (128 bytes) is for PCI2.3 Compatible Config Space Header
//         (b) Somewhere between 3Fh and FFh is for PCI Express Capability Structure
// (3) PCI Express Entended Configuration Space = `ECFG_REG_OFFSET
// =============================================================================
//assign access_func_num  = lbc_cdm_addr[18:16];

// ------------------------------------------------------------------------------
// cdm_pl_reg block address decode
// ------------------------------------------------------------------------------
assign pl_reg_space     =                            (lbc_cdm_addr[11:8] == `PL_REG_OFFSET) |      //7
                          (lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 1))  //8


                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && ((lbc_cdm_addr[7:4] < 4'h2)) && (lbc_cdm_addr[7:4] > 4'h0))  // APP Bus and Device Number Status (0xB10) (address 0x410 in PL - offset 4, addr 10)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && (lbc_cdm_addr[7:2] == 6'b0001_11)) // 0xB1C Blocking Traffic during non-D0 state




                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && (lbc_cdm_addr[7:2] == 6'b1001_00)) // PIPE Related (0xB90 to 0xB93)


                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && ((lbc_cdm_addr[7:4] < 4'h5)) && (lbc_cdm_addr[7:4] > 4'h3)); // AUX_FREQ (0xB40 to 0xB43)



assign pl_reg_sel       = pl_reg_space & (|lbc_cdm_cs)
;



assign cfg_reg_space    = lbc_cdm_addr[11:8] == `CFG_REG_OFFSET  
                          ;        
assign ecfg_reg_space   = ((lbc_cdm_addr[11:8] >= `ECFG_REG_OFFSET) & (lbc_cdm_addr[11:8] < `PL_REG_OFFSET))
                           ; //Port Logic Regs : 0x700
                          // DMA Port Logic Registers VSEC can be ORed to the ecfg_reg_space


assign cfg_reg_sel      = ({NF{cfg_reg_space}}) & ({NF{(~|lbc_cdm_addr[7:6])}}) & lbc_cdm_cs
;
assign cfg_cap_reg_sel  = ({NF{cfg_reg_space}}) & ({NF{(|lbc_cdm_addr[7:6])}}) & lbc_cdm_cs
;
assign ecfg_reg_sel     =  ({NF{ecfg_reg_space}}) & lbc_cdm_cs
;

assign cdm_pf_ecfg_addr = lbc_cdm_addr ;



reg no_ack;
wire no_ack_sr_clr;
reg [NF-1:0] cs_mask_l;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
  if (~non_sticky_rst_n) 
     cs_mask_l    <= #TP 0;        
  else
     cs_mask_l <= #TP lbc_cdm_cs;
  end

assign int_pl_reg_ack = cs_mask_l & {NF{pl_reg_ack}};
assign int_no_ack = cs_mask_l & {NF{no_ack}};
assign no_ack_sr_clr = 1;

assign hit_pf_reg_space = (|cfg_reg_sel) | (|cfg_cap_reg_sel) | (|ecfg_reg_sel) | pl_reg_sel
                        ;
         
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        no_ack          <= #TP 0;
    end
    else if ( no_ack 
             ) begin
           no_ack       <= #TP 1'b0;
    end
    else if ((|lbc_cdm_cs) && no_ack_sr_clr
            ) begin
           no_ack       <= #TP ~hit_pf_reg_space
                           ;
    end

end

// Returning data mux
assign cdm_pf_data     =      (|cfg_reg_ack)       ? cfg_reg_data
                            : (|cfg_cap_reg_ack)   ? cfg_cap_reg_data
                            : (|ecfg_reg_ack)      ? ecfg_reg_data
                            : (pl_reg_ack)         ? {NF{pl_reg_data}}
                            : {NF{`PCIE_UNUSED_RESPONSE}};

assign cdm_lbc_data     =  
                           |cdm_pf_ack                             ? cdm_pf_data
                            : {NF{`PCIE_UNUSED_RESPONSE}};

// Returning Ack mux
assign cdm_pf_ack        = int_pl_reg_ack | cfg_reg_ack | ecfg_reg_ack | cfg_cap_reg_ack
                         ;

assign cdm_lbc_ack      =  
                           cdm_pf_ack
                         | int_no_ack;




endmodule
