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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/delay_n_w_enable.sv#2 $
// -------------------------------------------------------------------------
// ---
// --- This block delays the input by n cycles.
// ---
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module delay_n_w_enable(
    clk,
    rst_n,
    clear,
    en,
    din,

    dout
);
parameter N         = 0;            // Number of cycles to delay
parameter WD        = 1;            // Width of datapath
parameter RESETVAL  = {WD{1'b0}};   // Allow for non-zero reset value

input               clk;
input               rst_n;
input               clear; // Synchronus reset
input               en;
input   [WD-1:0]    din;

output  [WD-1:0]    dout;

reg     [WD-1:0]    mem[0:N];  
reg     [WD-1:0]    dout_r;

wire    [WD-1:0]    dout0_mux;
assign dout0_mux = din;
assign dout     = (N == 0) ? dout0_mux : mem[N];

reg en_int;
generate if (N > 1) 
    begin : enabledr
       reg     [N-2:0]     en_r;

       always @(posedge clk or negedge rst_n)
       begin
         integer i;

         if (!rst_n) begin
             en_r       <= #(`TP) 0;
         end else begin
           for(i = 0; i < N-1; i = i + 1) begin
             if(i==0) 
                en_r[i]    <= #(`TP) en;
             else
                en_r[i]    <= #(`TP) en_r[i-1]; 
           end // for
         end
       end // always

       assign en_int = |en_r;

   end else begin : enabledr_eq0 
       assign en_int = 0;
   end
endgenerate


integer i;
always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        for (i=0; i<=N; i=i+1)  mem[i]  <= #(`TP) RESETVAL;
        dout_r      <= #(`TP) RESETVAL;

    end else if (clear) begin
        for (i=0; i<=N; i=i+1)  mem[i]  <= #(`TP) RESETVAL;
        dout_r      <= #(`TP) RESETVAL;
    end else if (en | en_int) begin
        for (i=0; i<N; i=i+1)
      //VCS coverage off
            mem[i+1]    <= #(`TP) (i==0) ? din : mem[i];
      //VCS coverage on
    end
endmodule
