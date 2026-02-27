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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_trgt_map.sv#2 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the programmable target map
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_trgt_map(
// ------------ Inputs ---------------
    core_clk,
    sticky_rst_n,
    lbc_cdm_data,
    trgt_map_write_pulse,
    trgt_map_reg_id,
// ------------ Outputs --------------
    trgt_map_reg_data,
    target_mem_map,
    target_rom_map
);

parameter INST  = 0;  // The uniquifying parameter for each port logic instance.
parameter NF    = `CX_NFUNC;                    // number of functions
parameter TP    = `TP;// Clock to Q delay (simulator insurance)

// ----------- Inputs ---------------
input            core_clk;                       // Core clock
input            sticky_rst_n;                   // Reset for non-sticky registers
input     [31:0] lbc_cdm_data;                   // Write Data
input     [3:0]  trgt_map_write_pulse;           // Write Data Byte Enables
input     [0:0]  trgt_map_reg_id;                // Target Map Register ID

// ---------- Outputs ----------------
output    [31:0] trgt_map_reg_data;              // target map register read data
output    [(6*NF)-1:0]    target_mem_map;        // Each bit of this vector indicates which target receives memory transactions for that bar #
output    [NF-1:0]        target_rom_map;        // Each bit of this vector indicates which target receives rom    transactions for that bar #

// ---------- Internal Signals --------
reg       [31:0] trgt_map_reg_data;               // register read data
reg       [4:0]  index;                           // Target Map viewport (index)
reg       [(6*NF)-1:0] target_mem_map;
reg       [NF-1:0] target_rom_map;
reg       any_write_pulse;

// -----------------------------------------------------------------------------
// Programmable Targer Map Register
// -----------------------------------------------------------------------------
// trgt_map_reg_id      - 0
// Port Logic Offset    -`CFG_PL_REG + 220h
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Keeping track of any change occuring to the Target Map Register, 
// for simultaneous update of index and target values
// -----------------------------------------------------------------------------
always @(posedge core_clk or negedge sticky_rst_n)
begin : pulse_proc
    if(!sticky_rst_n) begin    
        any_write_pulse               <= #TP 0;
    end else begin
        any_write_pulse               <= #TP |trgt_map_write_pulse & trgt_map_reg_id[0];
    end
end

// -----------------------------------------------------------------------------
// Registering the index value for a Read operation on the Target Map Register
// -----------------------------------------------------------------------------
always @(posedge core_clk or negedge sticky_rst_n)
begin : index_proc
    if(!sticky_rst_n) begin    
        index                         <=  #TP 0;
    end else begin
        index                         <= #TP (trgt_map_write_pulse[2] & trgt_map_reg_id[0]) ? // Index coding the PF Function number
                                         lbc_cdm_data[20:16] : index;
    end
end

generate
genvar func;
for (func=0; func<NF; func = func+1) begin : gen_trgt_map_reg
localparam FUNC_NUM  = func;              // uniquifying parameter per function
wire index_in;
// Retrieve the index value (lbc_cdm_data[20:16]) active at a time,
// and store the corresponding target values available for this index 
assign index_in = (any_write_pulse && (lbc_cdm_data[20:16] == func));

always @(posedge core_clk or negedge sticky_rst_n)
begin : proc_trgt_map_reg 
  if(!sticky_rst_n) begin    
    target_mem_map[6*(1+func)-1:6*func]    <= #TP {`MEM_FUNC_BAR5_TARGET_MAP, `MEM_FUNC_BAR4_TARGET_MAP, `MEM_FUNC_BAR3_TARGET_MAP,
                                               `MEM_FUNC_BAR2_TARGET_MAP, `MEM_FUNC_BAR1_TARGET_MAP, `MEM_FUNC_BAR0_TARGET_MAP};
    target_rom_map[func]                   <= #TP {`ROM_FUNC_TARGET_MAP};
  end 
  else begin
  if (index_in & any_write_pulse) begin
        target_mem_map[6*(1+func)-1:6*func]      <= #TP lbc_cdm_data[5:0];
        target_rom_map[func]                     <= #TP lbc_cdm_data[6];
   end
  end
end    

end // for loop
endgenerate

// -----------------------------------------------------------------------------
// Read Mux
// -----------------------------------------------------------------------------
always @(*)
begin : read_data_proc
    trgt_map_reg_data[31:0] = {19'b0, 6'h0, 7'h7F};

    if (trgt_map_reg_id[0] && !any_write_pulse)   begin
       if (index <= NF) begin
         trgt_map_reg_data[31:0] = {11'b0, index, 3'b0, 6'h0, target_rom_map[index], target_mem_map[index*6 +: 6]};
       end    
    end
end
// leda E267 on
endmodule
