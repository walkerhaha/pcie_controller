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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_bar_match.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// ---  This module performs BAR matching for a single Physical Function
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_bar_match (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    flt_cdm_addr,
    upstream_port,
    type0,
    cfg_io_limit_upper16,
    cfg_io_base_upper16,
    cfg_io_base,
    cfg_io_limit,
    io_is_32bit,
    cfg_io_space_en,
    cfg_mem_space_en,
    cfg_bus_master_en,
    cfg_isa_enable,
    cfg_vga_enable,
    cfg_vga16_decode,
    cfg_bar_is_io,
    cfg_bar_enabled,
    cfg_bar0_start,
    cfg_bar0_limit,
    cfg_bar0_mask,
    cfg_bar1_start,
    cfg_bar1_limit,
    cfg_bar1_mask,
    cfg_bar2_start,
    cfg_bar2_limit,
    cfg_bar2_mask,
    cfg_bar3_start,
    cfg_bar3_limit,
    cfg_bar3_mask,
    cfg_bar4_start,
    cfg_bar4_limit,
    cfg_bar4_mask,
    cfg_bar5_start,
    cfg_bar5_limit,
    cfg_bar5_mask,
    cfg_exp_rom_enable,
    cfg_exp_rom_start,
    cfg_exp_rom_mask,
    cfg_mem_base,
    cfg_mem_limit,
    cfg_pref_mem_base,
    cfg_pref_mem_limit,
    cfg_config_limit,

// -- outputs --
    cfg_io_match,
    cfg_config_above_match,
    cfg_rom_match,
    cfg_bar_match,
    cfg_mem_match,
    cfg_prefmem_match
);

parameter INST              = 0;                    // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM          = 0;                    // uniquifying parameter per function
parameter TP                = `TP;                  // Clock to Q delay (simulator insurance)

// -------------- Inputs ---------------
input                           core_clk;                       // Core Clock
input                           non_sticky_rst_n;               // Non-Sticky Reset
input   [63:0]                  flt_cdm_addr;                   // 64-bit address to be compared with BAR
input                           upstream_port;                  // upstream port when set
input                           type0;                          // Maybe make this a bus??
input   [15:0]                  cfg_io_base_upper16;            // Upper 16 bit IO base address
input   [15:0]                  cfg_io_limit_upper16;           // Upper 16 bit IO limit address
input   [7:0]                   cfg_io_base;                    // IO base address
input   [7:0]                   cfg_io_limit;                   // IO limit address
input                           io_is_32bit;
input                           cfg_io_space_en;                // IO Space enable
input                           cfg_mem_space_en;               // Memory space enable
input                           cfg_bus_master_en;              // Bus master enable
input                           cfg_isa_enable;                 // For bridge: ISA enable
input                           cfg_vga_enable;                 // For bridge: VGA enable (optional)
input                           cfg_vga16_decode;               // For bridge: VGA 16-bit decode (optional)
input   [5:0]                   cfg_bar_is_io;                  // Indicates whether the BAR is set as IO or memory
input   [5:0]                   cfg_bar_enabled;                // Indicates whether the BAR is enabled or not
input   [63:0]                  cfg_bar0_start;                 // BAR0 start address
input   [63:0]                  cfg_bar0_limit;                 // BAR0 limit address
input   [63:0]                  cfg_bar0_mask;                  // BAR0 mask register
input   [31:0]                  cfg_bar1_start;                 // BAR1 start address
input   [31:0]                  cfg_bar1_limit;                 // BAR1 limit address
input   [31:0]                  cfg_bar1_mask;                  // BAR1 mask register
input   [63:0]                  cfg_bar2_start;                 // BAR2 start address
input   [63:0]                  cfg_bar2_limit;                 // BAR2 limit address
input   [63:0]                  cfg_bar2_mask;                  // BAR2 mask register
input   [31:0]                  cfg_bar3_start;                 // BAR3 start address
input   [31:0]                  cfg_bar3_limit;                 // BAR3 limit address
input   [31:0]                  cfg_bar3_mask;                  // BAR3 mask register
input   [63:0]                  cfg_bar4_start;                 // BAR4 start address
input   [63:0]                  cfg_bar4_limit;                 // BAR4 limit address
input   [63:0]                  cfg_bar4_mask;                  // BAR4 mask register
input   [31:0]                  cfg_bar5_start;                 // BAR5 start address
input   [31:0]                  cfg_bar5_limit;                 // BAR5 limit address
input   [31:0]                  cfg_bar5_mask;                  // BAR5 mask register
input                           cfg_exp_rom_enable;             // Indicates whether the ROM BAR is enabled or not
input   [31:0]                  cfg_exp_rom_start;              // Expansion ROM start address
input   [31:0]                  cfg_exp_rom_mask;               // ROM BAR Mask
input   [15:0]                  cfg_mem_base;                   // Memory start address
input   [15:0]                  cfg_mem_limit;                  // Memory limit address
input   [63:0]                  cfg_pref_mem_base;              // Prefetchable memory start address
input   [63:0]                  cfg_pref_mem_limit;             // Prefetchable memory limit address
input   [9:0]                   cfg_config_limit;               // CONFIG_LIMIT_REG

// -------------- Outputs --    ------------
output                          cfg_io_match;                   // Within IO address range
output                          cfg_config_above_match;         // Adress is above certain user configuration limit
output                          cfg_rom_match;                  // Within expansion ROM address range
output  [5:0]                   cfg_bar_match;                  // Within BAR range
output                          cfg_mem_match;                  // Within Memory range (Type 1 only)
output                          cfg_prefmem_match;              // Within Prefetchable Memorey range (Type 1 only)
reg                             cfg_io_match;
reg                             cfg_config_above_match;
reg                             cfg_rom_match;
reg                             cfg_mem_match;
reg                             cfg_prefmem_match;
reg     [5:0]                   cfg_bar_match;
wire                            io16_range;
wire                            io32_range;
wire                            isa_io_match;
wire                            vga_io_match;
wire                            vga_mem_match;


// =============================================================================
// =============================================================================
// Address matching with available BARs
// =============================================================================
// =============================================================================

assign io16_range =  type0 ? 1'b1 :
                    ((flt_cdm_addr[15:0] <= {cfg_io_limit[7:4], 12'hFFF}) &
                    (flt_cdm_addr[15:0] >= {cfg_io_base[7:4], 12'h0}) & (flt_cdm_addr[63:16] == 48'h0) &
                    cfg_io_space_en);

assign io32_range =  type0 ? 1'b1 :
                    ((flt_cdm_addr[31:0] <= {cfg_io_limit_upper16, cfg_io_limit[7:4], 12'hFFF}) &
                    (flt_cdm_addr[31:0] >= {cfg_io_base_upper16, cfg_io_base[7:4], 12'h0}) &
                    (flt_cdm_addr[63:32] == 32'h0) & cfg_io_space_en);


assign isa_io_match     = 0;


assign vga_io_match  = 0;
assign vga_mem_match = 0;


always @(posedge core_clk or negedge non_sticky_rst_n)
begin : bar_match_PROC
    if (!non_sticky_rst_n) begin
        cfg_config_above_match  <= #TP 0;
        cfg_io_match            <= #TP 0;
        cfg_rom_match           <= #TP 0;
        cfg_mem_match           <= #TP 0;
        cfg_prefmem_match       <= #TP 0;
        cfg_bar_match           <= #TP 0;
    end
    else begin
        // This signal is to allow certain configuration accesses (above
        // CONFIG_LIMIT_REG) to be routed to TRGT1 interface
        cfg_config_above_match  <= #TP (flt_cdm_addr[11:2] > cfg_config_limit || ~|flt_cdm_addr[11:8] && flt_cdm_addr[7:2] > `PCI_CONFIG_LIMIT);
        cfg_io_match            <= #TP ((io_is_32bit ? io32_range : io16_range) || vga_io_match || isa_io_match);
        cfg_rom_match           <= #TP cfg_exp_rom_enable & ((flt_cdm_addr[31:0] & ~cfg_exp_rom_mask) == (cfg_exp_rom_start & ~cfg_exp_rom_mask)) & (flt_cdm_addr[63:32] == 32'b0);
        cfg_bar_match[0]        <= #TP cfg_bar_enabled[0] & ((flt_cdm_addr & ~cfg_bar0_mask) == (cfg_bar0_start & ~cfg_bar0_mask))
                                        & ((~cfg_bar_is_io[0] & (cfg_mem_space_en||!upstream_port)) | (cfg_bar_is_io[0] & (cfg_io_space_en||!upstream_port)));
        cfg_bar_match[1]        <= #TP cfg_bar_enabled[1] & ((flt_cdm_addr[31:0] & ~cfg_bar1_mask) == (cfg_bar1_start[31:0] & ~cfg_bar1_mask)) & (flt_cdm_addr[63:32] == 32'b0)
                                        & ((~cfg_bar_is_io[1] & (cfg_mem_space_en||!upstream_port)) | (cfg_bar_is_io[1] & (cfg_io_space_en||!upstream_port)));
        cfg_bar_match[2]        <= #TP cfg_bar_enabled[2] & ((flt_cdm_addr & ~cfg_bar2_mask) == (cfg_bar2_start & ~cfg_bar2_mask))
                                        & ((~cfg_bar_is_io[2] & cfg_mem_space_en) | (cfg_bar_is_io[2] & cfg_io_space_en));
        cfg_bar_match[3]        <= #TP cfg_bar_enabled[3] & ((flt_cdm_addr[31:0] & ~cfg_bar3_mask) == (cfg_bar3_start[31:0] & ~cfg_bar3_mask)) & (flt_cdm_addr[63:32] == 32'b0)
                                        & ((~cfg_bar_is_io[3] & cfg_mem_space_en) | (cfg_bar_is_io[3] & cfg_io_space_en));
        cfg_bar_match[4]        <= #TP cfg_bar_enabled[4] & ((flt_cdm_addr & ~cfg_bar4_mask) == (cfg_bar4_start & ~cfg_bar4_mask))
                                        & ((~cfg_bar_is_io[4] & cfg_mem_space_en) | (cfg_bar_is_io[4] & cfg_io_space_en));
        cfg_bar_match[5]        <= #TP cfg_bar_enabled[5] & ((flt_cdm_addr[31:0] & ~cfg_bar5_mask) == (cfg_bar5_start[31:0] & ~cfg_bar5_mask)) & (flt_cdm_addr[63:32] == 32'b0)
                                        & ((~cfg_bar_is_io[5] & cfg_mem_space_en) | (cfg_bar_is_io[5] & cfg_io_space_en));

        // In RC & SW downstream device, since we accept transactions that are
        // outside the range,
        // if the bus master is not enabled, we have to say that it's
        // a match so the filter will reject it
        // Also, an upstream port should treat transactions inside the range
        // as UR when mem space enable is clear 
        if (~upstream_port & !cfg_bus_master_en) begin
            cfg_mem_match       <= #TP 1'b1;
            cfg_prefmem_match   <= #TP 1'b1;
        end
        else if (upstream_port & !cfg_mem_space_en) begin
            cfg_mem_match       <= #TP 1'b0;
            cfg_prefmem_match   <= #TP 1'b0;
        end
        else begin
            cfg_mem_match       <= #TP ((flt_cdm_addr >= {32'b0, cfg_mem_base, 16'b0}) & (flt_cdm_addr <= {32'b0, cfg_mem_limit, 16'hFFFF}))
                                       || vga_mem_match;
            cfg_prefmem_match   <= #TP (flt_cdm_addr >= cfg_pref_mem_base) & (flt_cdm_addr <= cfg_pref_mem_limit);
        end
     end
end


endmodule // cdm_bar_match
