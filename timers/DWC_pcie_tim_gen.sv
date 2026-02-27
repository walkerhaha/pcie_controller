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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/timers/DWC_pcie_tim_gen.sv#4 $
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module is timing generator for (a) timers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_tim_gen
#(
     parameter CLEAR_CNTR_TO_1=0
)
(
     input          clk
    ,input          rst_n

    ,input  [2:0]   current_data_rate
    ,input          clr_cntr            // clear cycle counter
    
    ,output         cnt_up_en           // timer count-up 
);

parameter   TP = `TP;

logic   [3:0]       gen1_freq;        // 62.5MHz, 125MHz or 250MHz
logic   [3:0]       gen1_freq_l1;     // 62.5MHz, 125MHz or 250MHz


// genx_freq :
//  1:31.25MHz
//  2:62.5MHz
//  4:125MHz
//  8:250MHz
//  16:500MHz
//  32:1000MHz

assign gen1_freq_l1 = (`CX_MAC_SMODE_GEN1==1)?8:     // 250MHz
                      (`CX_MAC_SMODE_GEN1==2)?4:     // 125MHz
                      (`CX_MAC_SMODE_GEN1==4)?2:2;   // 62.5MHz

assign gen1_freq = gen1_freq_l1;




logic   [5:0]   timer_count; // 
logic           timer2;
logic           timer2_comb;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer_count  <= #TP 0;
    end
    else begin
        if( clr_cntr )begin
            timer_count <= #TP CLEAR_CNTR_TO_1;
        end
        else begin
            timer_count  <= #TP timer_count + 1'b1;
        end
    end
end

always_comb begin
    case(current_data_rate)
        0: timer2_comb = gen_timer2(7'h1,timer_count);
        default : timer2_comb = 0;
    endcase
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer2  <= #TP 1'b0;
    end
    else begin
        if( clr_cntr && 
           !(current_data_rate == `GEN1_RATE
           )
        )begin
            timer2  <= #TP 1'b0;
        end
        else if ( current_data_rate == `GEN1_RATE )begin
            timer2  <= #TP 1'b1;
        end
        else begin
          timer2 <= #TP timer2_comb;
        end
    end
end

assign cnt_up_en = timer2;

function automatic gen_timer2;
 input      [6:0] freq_ratio;
 input      [5:0] timer_count;

begin
    case(freq_ratio)
      1:begin
        gen_timer2 = 1'b1;
      end
      2:begin
        if( timer_count[0] )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      4:begin
        if( timer_count[1:0] == 2'h3 )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      8:begin
        if( timer_count[2:0] == 3'h7 )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      16:begin
        if( timer_count[3:0] == 4'hf )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      32:begin
        if( timer_count[4:0] == 5'h1f )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      64:begin
        if( timer_count[5:0] == 6'h3f )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      default:begin
          gen_timer2 = 1'b1;
      end
    endcase
end
endfunction


endmodule
