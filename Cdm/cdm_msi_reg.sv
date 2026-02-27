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
// ---    $DateTime: 2020/09/18 09:14:47 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_msi_reg.sv#5 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the MSI capability registers.
// --- Both PF and VF implementations are supported, selected via the VF_IMPL parameter.
// --- The difference between the two implementations is in the handling of the next
// --- pointer field:
// ---  - flip-flops DBI writeable for PFs
// ---  - hardcoded value for VFs
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_msi_reg (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    flr_rst_n,
    lbc_cdm_data,
    lbc_cdm_dbi,
    msi_write_pulse,
    msi_read_pulse,
    msi_reg_id,
    cfg_msi_pending,
    sticky_rst_n,
// -- outputs --
    cfg_multi_msi_en,
    cfg_msi_en,
    cfg_msi_addr,
    cfg_msi_data,
    cfg_msi_64,
    cfg_msi_mask,
    cfg_msi_ext_data_en,

    msi_reg_data
);
parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter VF_IMPL       = 0;                    // 0: PF impl. 1: VF impl.
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
parameter FUNC_NUM      = 0;

localparam MSI_CAP_ENABLE = VF_IMPL ? `VF_MSI_CAP_ENABLE : `MSI_CAP_ENABLE;
localparam MSI_NEXT_PTR = VF_IMPL ? `VF_MSI_NEXT_PTR : `MSI_NEXT_PTR;
localparam MSI_PVM_ENABLE = `MSI_PVM_EN_VALUE;

localparam VECTORS_01 = 3'b000;                 // Number of selected vectors based on cfg_multi_msi_cap. Unused masked and pending bits are reserved
localparam VECTORS_02 = 3'b001;
localparam VECTORS_04 = 3'b010;
localparam VECTORS_08 = 3'b011;
localparam VECTORS_16 = 3'b100;
localparam VECTORS_32 = 3'b101;

// -------------- Inputs ---------------
input           core_clk;
input           non_sticky_rst_n;
input           sticky_rst_n;                   
input           flr_rst_n;
input   [31:0]  lbc_cdm_data;                   // Data for write
input           lbc_cdm_dbi;
input    [3:0]  msi_write_pulse;
input           msi_read_pulse;
input    [5:0]  msi_reg_id;
input   [31:0]  cfg_msi_pending;                // MSI Pending bits, implemented in application

// -------------- Outputs --------------
output   [2:0]  cfg_multi_msi_en;               // Multiple MSI enable
output          cfg_msi_en;                     // MSI enable
output  [63:0]  cfg_msi_addr;                   // MSI address
output  [31:0]  cfg_msi_data;                   // MSI data field
output          cfg_msi_64;                     // 64 bits MSI addressing enable
output  [31:0]  cfg_msi_mask;                   // MSI Mask bits
output          cfg_msi_ext_data_en;            // Extended Message Data Enable
output  [31:0]  msi_reg_data;                   // Read data back from core

wire    [7:0]   cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0;
wire    [7:0]   cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4;
reg     [7:0]   cfg_reg_11, cfg_reg_10, cfg_reg_9, cfg_reg_8;
reg     [7:0]   cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12;
reg     [7:0]   cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16;
wire    [7:0]   cfg_reg_23, cfg_reg_22, cfg_reg_21, cfg_reg_20;

reg cfg_msi_ext_data_cap;           // Extended Message Data capable
reg cfg_msi_ext_data_en;            // Extended Message Data Enable

// =============================================================================
// MSI Capability Structure
// =============================================================================
// MSI CAP register
// msi_reg_id       - 0
// PCIE Offset      - CFG_MSI_CAP
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0
// -----------------------------------------------------------------------------
wire [7:0]  cfg_msi_cap_id = 8'h05;
reg [7:0]   cfg_msi_next_ptr;
reg         cfg_msi_en;
reg [2:0]   cfg_multi_msi_en;
reg [2:0]   cfg_multi_msi_cap;
reg         cfg_msi_64;
assign {cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0} = {5'd0, cfg_msi_ext_data_en, cfg_msi_ext_data_cap, MSI_PVM_ENABLE, {cfg_msi_64, cfg_multi_msi_en, cfg_multi_msi_cap, cfg_msi_en}, cfg_msi_next_ptr, cfg_msi_cap_id};

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_msi_en           <= #TP 0;
        cfg_multi_msi_en     <= #TP 0;
        cfg_msi_ext_data_en  <= #TP 1'b0;
    end else begin
        if (MSI_CAP_ENABLE) begin
            // RW
            cfg_msi_en           <= #TP (msi_write_pulse[2] & msi_reg_id[0]) ? lbc_cdm_data[16]    : cfg_msi_en;
            cfg_multi_msi_en     <= #TP (msi_write_pulse[2] & msi_reg_id[0]) ? lbc_cdm_data[22:20] : cfg_multi_msi_en;
            cfg_msi_ext_data_en  <= #TP (msi_write_pulse[3] & msi_reg_id[0]) ? (lbc_cdm_data[26] & cfg_msi_ext_data_cap) : cfg_msi_ext_data_en; // if capability is cleared, do not allow enable to be set
            // Read-Only register, but writable through DBI
        end else begin
            cfg_msi_en           <= #TP 0;
            cfg_multi_msi_en     <= #TP 0;
            cfg_msi_ext_data_en  <= #TP 1'b0;
        end
    end
end


always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_msi_next_ptr     <= #TP MSI_NEXT_PTR;
        cfg_multi_msi_cap    <= #TP `DEFAULT_MULTI_MSI_CAPABLE;
        cfg_msi_64           <= #TP `MSI_64_EN;
        cfg_msi_ext_data_cap <= #TP `DEFAULT_EXT_MSI_DATA_CAPABLE;
    end else begin
        if (MSI_CAP_ENABLE) begin
            // Read-Only register, but writable through DBI
            cfg_msi_next_ptr     <= #TP (lbc_cdm_dbi & msi_write_pulse[1] & msi_reg_id[0] & VF_IMPL==0) ? lbc_cdm_data[15:8]  : cfg_msi_next_ptr; // no dbi access for VFs
            cfg_multi_msi_cap    <= #TP (lbc_cdm_dbi & msi_write_pulse[2] & msi_reg_id[0])            ? lbc_cdm_data[19:17] : cfg_multi_msi_cap;
            cfg_msi_64           <= #TP (lbc_cdm_dbi & msi_write_pulse[2] & msi_reg_id[0])            ? lbc_cdm_data[23]    : cfg_msi_64;
            cfg_msi_ext_data_cap <= #TP (lbc_cdm_dbi & msi_write_pulse[3] & msi_reg_id[0])            ? lbc_cdm_data[25]    : cfg_msi_ext_data_cap;
        end else begin
            cfg_msi_next_ptr     <= #TP MSI_NEXT_PTR;
            cfg_multi_msi_cap    <= #TP `DEFAULT_MULTI_MSI_CAPABLE;
            cfg_msi_64           <= #TP `MSI_64_EN;
            cfg_msi_ext_data_cap <= #TP `DEFAULT_EXT_MSI_DATA_CAPABLE;
        end
    end
end




// -----------------------------------------------------------------------------
// MSI Message addr
// msi_reg_id       - 1
// PCIE Offset      - CFG_MSI_CAP + 04h
// Length           - 4 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4
// -----------------------------------------------------------------------------
reg     [31:0]  cfg_msi_addr_low32;
assign {cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4} = cfg_msi_addr_low32;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_msi_addr_low32          <= #TP 0;
    end else begin
        if (MSI_CAP_ENABLE) begin
            cfg_msi_addr_low32[7:0]     <= #TP (msi_write_pulse[0] & msi_reg_id[1]) ? {lbc_cdm_data[7:2], 2'b0} : cfg_msi_addr_low32[7:0];
            cfg_msi_addr_low32[15:8]    <= #TP (msi_write_pulse[1] & msi_reg_id[1]) ? lbc_cdm_data[15:8]        : cfg_msi_addr_low32[15:8];
            cfg_msi_addr_low32[23:16]   <= #TP (msi_write_pulse[2] & msi_reg_id[1]) ? lbc_cdm_data[23:16]       : cfg_msi_addr_low32[23:16];
            cfg_msi_addr_low32[31:24]   <= #TP (msi_write_pulse[3] & msi_reg_id[1]) ? lbc_cdm_data[31:24]       : cfg_msi_addr_low32[31:24];
        end else begin
            cfg_msi_addr_low32          <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// MSI Message Data (32bit) / Message Upper addr (64bit)
// msi_reg_id       - 2
// PCIE Offset      - CFG_MSI_CAP + 08h
// Length           - 4 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_11,  cfg_reg_10,  cfg_reg_9,  cfg_reg_8
// -----------------------------------------------------------------------------
wire    [31:0]  cfg_msi_addr_high32;
assign cfg_msi_addr = {cfg_msi_addr_high32, cfg_msi_addr_low32};
assign cfg_msi_addr_high32 = cfg_msi_64 ? {cfg_reg_11, cfg_reg_10, cfg_reg_9, cfg_reg_8} : 32'b0;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        {cfg_reg_11,  cfg_reg_10,  cfg_reg_9,  cfg_reg_8}  <= #TP 0;
    end else begin
        if (MSI_CAP_ENABLE) begin
            cfg_reg_8  <= #TP (msi_write_pulse[0] & msi_reg_id[2]) ? lbc_cdm_data[7:0]  : cfg_reg_8;
            cfg_reg_9  <= #TP (msi_write_pulse[1] & msi_reg_id[2]) ? lbc_cdm_data[15:8] : cfg_reg_9;
            cfg_reg_10 <= #TP (msi_write_pulse[2] & msi_reg_id[2]) ? ((cfg_msi_64 | cfg_msi_ext_data_cap)? lbc_cdm_data[23:16] : cfg_reg_10) : cfg_reg_10;
            cfg_reg_11 <= #TP (msi_write_pulse[3] & msi_reg_id[2]) ? ((cfg_msi_64 | cfg_msi_ext_data_cap)? lbc_cdm_data[31:24] : cfg_reg_11) : cfg_reg_11;
        end else begin
            {cfg_reg_11,  cfg_reg_10,  cfg_reg_9,  cfg_reg_8}  <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// MSI mask (32bit) / MSI data (64bit)
// msi_reg_id       - 3
// PCIE Offset      - CFG_MSI_CAP + 0Ch
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12
// -----------------------------------------------------------------------------
wire    [31:0]  cfg_msi_data;     // System specific message
wire    [31:0]  int_cfg_msi_data; // Aux bus for System specific message  always 32 bits wide

assign int_cfg_msi_data = cfg_msi_64 ? { cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12} : 
                                       { cfg_reg_11, cfg_reg_10, cfg_reg_9, cfg_reg_8};

assign cfg_msi_data = {(int_cfg_msi_data[31:16] & {16{cfg_msi_ext_data_en}}), int_cfg_msi_data[15:0]}; 

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        {cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12}  <= #TP 0;
    end else begin
        if (MSI_CAP_ENABLE && !cfg_msi_64) begin // capability layout for 32-bit msi-addr: this location implements RW MSI mask bits
            cfg_reg_12[0]   <= #TP (MSI_PVM_ENABLE) ? ((msi_write_pulse[0] & msi_reg_id[3]) ? lbc_cdm_data[0]     : cfg_reg_12[0]) : 0;
            cfg_reg_12[1]   <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_02)) ? ((msi_write_pulse[0] & msi_reg_id[3]) ? lbc_cdm_data[1]     : cfg_reg_12[1]) : 0;
            cfg_reg_12[3:2] <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_04)) ? ((msi_write_pulse[0] & msi_reg_id[3]) ? lbc_cdm_data[3:2]   : cfg_reg_12[3:2]) : 0;
            cfg_reg_12[7:4] <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_08)) ? ((msi_write_pulse[0] & msi_reg_id[3]) ? lbc_cdm_data[7:4]   : cfg_reg_12[7:4]) : 0;
            cfg_reg_13      <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_16)) ? ((msi_write_pulse[1] & msi_reg_id[3]) ? lbc_cdm_data[15:8]  : cfg_reg_13) : 0;
            cfg_reg_14      <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap == VECTORS_32)) ? ((msi_write_pulse[2] & msi_reg_id[3]) ? lbc_cdm_data[23:16] : cfg_reg_14) : 0;
            cfg_reg_15      <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap == VECTORS_32)) ? ((msi_write_pulse[3] & msi_reg_id[3]) ? lbc_cdm_data[31:24] : cfg_reg_15) : 0;
         end else if (MSI_CAP_ENABLE && cfg_msi_64) begin
            cfg_reg_12  <= #TP (msi_write_pulse[0] & msi_reg_id[3]) ? lbc_cdm_data[7:0]   : cfg_reg_12;
            cfg_reg_13  <= #TP (msi_write_pulse[1] & msi_reg_id[3]) ? lbc_cdm_data[15:8]  : cfg_reg_13;
            cfg_reg_14  <= #TP (msi_write_pulse[2] & msi_reg_id[3]) ? (cfg_msi_ext_data_cap? lbc_cdm_data[23:16]: cfg_reg_14) : cfg_reg_14;
            cfg_reg_15  <= #TP (msi_write_pulse[3] & msi_reg_id[3]) ? (cfg_msi_ext_data_cap? lbc_cdm_data[31:24]: cfg_reg_15) : cfg_reg_15;
         end else begin
            {cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12}  <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// MSI pending (32bit) / MSI mask (64bit)
// msi_reg_id       - 4
// PCIE Offset      - CFG_MSI_CAP + 10h
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16
// -----------------------------------------------------------------------------
assign cfg_msi_mask = cfg_msi_64 ? {cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16} : {cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12};

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        {cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16}  <= #TP 0;
    end else begin
        if (MSI_CAP_ENABLE && !cfg_msi_64) begin // capability layout for 32-bit msi-addr: this location implements RO MSI pending bits
            cfg_reg_16[0]   <= #TP (MSI_PVM_ENABLE) ? cfg_msi_pending[0]     : 0;
            cfg_reg_16[1]   <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_02)) ? cfg_msi_pending[1]     : 0;
            cfg_reg_16[3:2] <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_04)) ? cfg_msi_pending[3:2]   : 0;
            cfg_reg_16[7:4] <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_08)) ? cfg_msi_pending[7:4]   : 0;
            cfg_reg_17      <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_16)) ? cfg_msi_pending[15:8]  : 0;
            cfg_reg_18      <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap == VECTORS_32)) ? cfg_msi_pending[23:16] : 0;
            cfg_reg_19      <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap == VECTORS_32)) ? cfg_msi_pending[31:24] : 0;
        end else if (MSI_CAP_ENABLE && cfg_msi_64) begin // capability layout for 64-bit msi-addr: this location implements RW MSI mask bits
            cfg_reg_16[0]   <= #TP (MSI_PVM_ENABLE) ? ((msi_write_pulse[0] & msi_reg_id[4]) ? lbc_cdm_data[0]   : cfg_reg_16[0]) : 0;
            cfg_reg_16[1]   <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_02)) ? ((msi_write_pulse[0] & msi_reg_id[4]) ? lbc_cdm_data[1]   : cfg_reg_16[1]) : 0;
            cfg_reg_16[3:2] <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_04)) ? ((msi_write_pulse[0] & msi_reg_id[4]) ? lbc_cdm_data[3:2]   : cfg_reg_16[3:2]) : 0;
            cfg_reg_16[7:4] <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_08)) ? ((msi_write_pulse[0] & msi_reg_id[4]) ? lbc_cdm_data[7:4]   : cfg_reg_16[7:4]) : 0;
            cfg_reg_17      <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap >= VECTORS_16)) ? ((msi_write_pulse[1] & msi_reg_id[4]) ? lbc_cdm_data[15:8]  : cfg_reg_17) : 0;
            cfg_reg_18      <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap == VECTORS_32)) ? ((msi_write_pulse[2] & msi_reg_id[4]) ? lbc_cdm_data[23:16] : cfg_reg_18) : 0;
            cfg_reg_19      <= #TP (MSI_PVM_ENABLE && (cfg_multi_msi_cap == VECTORS_32)) ? ((msi_write_pulse[3] & msi_reg_id[4]) ? lbc_cdm_data[31:24] : cfg_reg_19) : 0;
        end else begin
            {cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16}  <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// MSI pending (64bit)
// msi_reg_id       - 5
// PCIE Offset      - CFG_MSI_CAP + 14h
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_23, cfg_reg_22, cfg_reg_21, cfg_reg_20
// -----------------------------------------------------------------------------

assign cfg_reg_20[0]    =  cfg_msi_pending[0];
assign cfg_reg_20[1]    = (cfg_multi_msi_cap >= VECTORS_02) ? cfg_msi_pending[1]      : 0;
assign cfg_reg_20[3:2]  = (cfg_multi_msi_cap >= VECTORS_04) ? cfg_msi_pending[3:2]    : 0;
assign cfg_reg_20[7:4]  = (cfg_multi_msi_cap >= VECTORS_08) ? cfg_msi_pending[7:4]    : 0;
assign cfg_reg_21       = (cfg_multi_msi_cap >= VECTORS_16) ? cfg_msi_pending[15:8]   : 0;
assign cfg_reg_22       = (cfg_multi_msi_cap == VECTORS_32) ? cfg_msi_pending[23:16]  : 0;
assign cfg_reg_23       = (cfg_multi_msi_cap == VECTORS_32) ? cfg_msi_pending[31:24]  : 0;

// =============================================================================
// CFG Register Read Operation
// =============================================================================

reg  [31:0]  msi_reg_data;                   // Read data back from core
always @(*)
begin
    unique case (1'b1)
        msi_reg_id[0] : msi_reg_data = {cfg_reg_3,  cfg_reg_2,  cfg_reg_1,  cfg_reg_0};
        msi_reg_id[1] : msi_reg_data = {cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4};
        msi_reg_id[2] : msi_reg_data = {cfg_reg_11, cfg_reg_10, cfg_reg_9,  cfg_reg_8};
        msi_reg_id[3] : msi_reg_data = {cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12};
        msi_reg_id[4] : msi_reg_data = {cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16};
        msi_reg_id[5] : msi_reg_data = {cfg_reg_23, cfg_reg_22, cfg_reg_21, cfg_reg_20};

        default:        msi_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_msi_reg
