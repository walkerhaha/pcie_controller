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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/ram_latency_pipe.sv#6 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//
//              Parameters:        Valid Values       Description
//              ==========         ============       ===========
//              PIPE_WIDTH         [ 1 to N  ]         Number of bits of the pipe
//              PIPE_INPUT_REG     [ 0 to 32 ]         Number of registers used at the input to the pipe
//              PIPE_LATENCY       [ 1 to 32 ]         Number of latency cycles that the pipe can handle [Normal RAM RD Latency = 1 cycle]
//              PIPE_EXTRA_STORAGE [ 0 to N  ]         Number of extra positions to be added to the FIFO depth.
//
//              PIPE_INPUT_REG + PIPE_LATENCY  + PIPE_EXTRA_STORAGE = Number storage elements needed = FIFO DEPTH
//              * Note =  PIPE_INPUT_REG + PIPE_LATENCY + PIPE_EXTRA_STORAGE < 32
//
//              Input Ports:       Size               Description
//              ===========        ====               ===========
//              core_clk           1 bit              Input Clock
//              core_rst_n         1 bit              Active Low Asynchronous Reset
//              halt_in            1 bit              Active high halt the pipe
//              pipe_in_data_valid 1 bit              Active high indicates valid data entry to the pipe
//              pipe_in_data       PIPE_WIDTH bits    Data input
//
//              Output Ports:      Size               Description
//              ===========        ====               ===========
//              pipe_out_data      PIPE_WIDTH bits    Data output
//
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module ram_latency_pipe(
// ------ Inputs ------
    core_clk,
    core_rst_n,
    halt_in,
    pipe_in_data_valid,
    pipe_in_data,
// ------ Outputs ------
    halt_out,
    pipe_out_data,
    pipe_out_data_valid
);

parameter PIPE_WIDTH                    = 1;
parameter PIPE_INPUT_REG                = 1;
parameter PIPE_LATENCY                  = 1;
parameter PIPE_LATENCY_PLUS_REGOUT      = PIPE_LATENCY + PIPE_INPUT_REG;
parameter PIPE_EXTRA_STORAGE            = 0;
parameter HALT_THLD                     = 0;

parameter TP                            = `TP;          // Clock to Q delay (simulator insurance)

 `define CLOG2(x) \
   (x <= 2) ? 1 : \
   (x <= 4) ? 2 : \
   (x <= 8) ? 3 : \
   (x <= 16) ? 4 : \
   (x <= 32) ? 5 : \
   (x <= 64) ? 6 : \
   -1

 parameter DFIFO_WIDTH                  = PIPE_WIDTH;
 parameter DREGOUT_WIDTH                = DFIFO_WIDTH;
 parameter FIFO_DEPTH                   = PIPE_LATENCY_PLUS_REGOUT + PIPE_EXTRA_STORAGE;

 parameter FIFO_DEPTH_BASE2 = (FIFO_DEPTH == 1) ? 2 :
                              (FIFO_DEPTH == 2) ? 2 :
                              (FIFO_DEPTH == 3) ? 4 :
                              (FIFO_DEPTH == 4) ? 4 :
                              (FIFO_DEPTH == 5) ? 8 :
                              (FIFO_DEPTH == 6) ? 8 :
                              (FIFO_DEPTH == 7) ? 8 :
                              (FIFO_DEPTH == 8) ? 8 :
                              (FIFO_DEPTH == 9) ? 16 :
                              (FIFO_DEPTH == 10) ? 16 :
                              (FIFO_DEPTH == 11) ? 16 :
                              (FIFO_DEPTH == 12) ? 16 :
                              (FIFO_DEPTH == 13) ? 16 :
                              (FIFO_DEPTH == 14) ? 16 :
                              (FIFO_DEPTH == 15) ? 16 :
                              (FIFO_DEPTH == 16) ? 16 :
                              32;

 parameter FIFO_ADDR_WIDTH              = `CLOG2(FIFO_DEPTH_BASE2);
 parameter FIFO_AE_LEVEL                = {{(FIFO_ADDR_WIDTH-1){1'b0}}, 1'b1};
 parameter FIFO_AF_LEVEL                = {{(FIFO_ADDR_WIDTH-1){1'b0}}, 1'b1};


 localparam HALT_LVL = FIFO_DEPTH - HALT_THLD;

 // BCM64 transport delay parameters
 localparam integer REG_DELAY_DENOM = 1000;
 localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;

input                           core_clk;
input                           core_rst_n;
input                           halt_in;
input                           pipe_in_data_valid; //  dataq_rd_en_delay[RAM_LATENCY_PLUS_REGOUT-1] | hdrq_rd_en_delay[RAM_LATENCY_PLUS_REGOUT-1]
input   [PIPE_WIDTH-1 :0]       pipe_in_data;

output                          halt_out;
output  [PIPE_WIDTH-1 :0]       pipe_out_data;
output                          pipe_out_data_valid;

wire [PIPE_WIDTH-1:0] fifo_in_data;
wire [PIPE_WIDTH-1:0] fifo_out_data;


genvar g_reg_elements;
generate
    if (PIPE_INPUT_REG != 0) begin : gen_pipe_input_reg
       reg  [PIPE_WIDTH-1:0] reg_out_data[PIPE_INPUT_REG-1:0];
       wire [PIPE_WIDTH-1:0] reg_in_data;

       assign reg_in_data = pipe_in_data;

       always @(posedge core_clk or negedge core_rst_n) begin
          if (!core_rst_n) begin
            for (int i=0; i < PIPE_INPUT_REG; i++) begin
              reg_out_data[i] <= #TP 0;
            end 
          end else begin
              reg_out_data[0] <= #TP reg_in_data;
              for (int i=1; i < PIPE_INPUT_REG; i++) begin 
                reg_out_data[i] <= #TP reg_out_data[i-1];
              end
          end
       end 
       assign fifo_in_data = reg_out_data[PIPE_INPUT_REG-1];

    end else begin : gen_pipe_input_reg_eq0
       assign fifo_in_data = pipe_in_data;
    end
endgenerate

// FIFO CTRL SIGNALS
wire pop_fifo;

reg pipe_in_data_valid_delay[PIPE_LATENCY_PLUS_REGOUT-1:0];
always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n) begin
    for (int i=0; i < PIPE_LATENCY_PLUS_REGOUT; i++) begin
      pipe_in_data_valid_delay[i] <= #TP 0;
    end 
  end else begin
    pipe_in_data_valid_delay[0] <= #TP pipe_in_data_valid;
    for (int i=1; i < PIPE_LATENCY_PLUS_REGOUT; i++) begin 
      pipe_in_data_valid_delay[i] <= #TP pipe_in_data_valid_delay[i-1];
    end
  end
end

// FIFO STATUS signals
wire fifo_empty;
wire fifo_almost_empty;
wire fifo_full;
wire fifo_half_full;
wire fifo_almost_full;
wire fifo_error;

assign pop_fifo  = !halt_in & !fifo_empty;

// PUSH FSM
parameter S_NO_PUSH       = 3'h0;
parameter S_PUSH          = 3'h1;

reg     [2:0]                   fifo_state;
reg     [2:0]                   next_fifo_state;

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        fifo_state       <= #TP S_NO_PUSH;
    end else begin
        fifo_state       <= #TP next_fifo_state;
    end
end

reg push_fifo;

always @(*) begin : FIFO_FSM

push_fifo = 1'b0;

   case (fifo_state)
        S_NO_PUSH:  begin
                      next_fifo_state    =  S_NO_PUSH;
                      if (( halt_in & pipe_in_data_valid_delay[PIPE_LATENCY_PLUS_REGOUT-1]) ||
                          (!fifo_empty & pipe_in_data_valid_delay[PIPE_LATENCY_PLUS_REGOUT-1]) ) begin
                         push_fifo = 1'b1;
                         next_fifo_state  =  S_PUSH;
                      end
                 end
        S_PUSH:begin
                      push_fifo = pipe_in_data_valid_delay[PIPE_LATENCY_PLUS_REGOUT-1];
                      next_fifo_state  =  S_PUSH;
                      if ((fifo_full) ||
                          (!halt_in & !(pipe_in_data_valid_delay[PIPE_LATENCY_PLUS_REGOUT-1])) ) begin
                         push_fifo = 1'b0;
                         next_fifo_state  =  S_NO_PUSH;
                      end
                 end
        default: begin
                      next_fifo_state       = S_NO_PUSH;
                 end
   endcase
end
// END FSM

DWC_pcie_ctl_bcm64_td
 #(
                    .WIDTH(DFIFO_WIDTH),
                    .DEPTH(FIFO_DEPTH),
                    .ERR_MODE(0),
                    .RST_MODE(0),
                    .ADDR_WIDTH(FIFO_ADDR_WIDTH),
                    .REG_DELAY_TIME(REG_DELAY_TIME),
                    .REG_DELAY_DENOM(REG_DELAY_DENOM)
                   )
u_radm_fifo(  // Inputs
                  .clk            (core_clk),
                  .rst_n          (core_rst_n),
                  .init_n         (1'b1),
                  .push_req_n     (!push_fifo),
                  .pop_req_n      (!pop_fifo),
                  .diag_n         (1'b1),
                  .ae_level       (FIFO_AE_LEVEL),
                  .af_thresh      (FIFO_AF_LEVEL),
                  .data_in        (fifo_in_data),
              // Outputs
                  .empty          (fifo_empty),
                  .almost_empty   (fifo_almost_empty),
                  .full           (fifo_full),
                  .half_full      (fifo_half_full),
                  .almost_full    (fifo_almost_full),
                  .error          (fifo_error),
                  .data_out       (fifo_out_data)
             );

assign pipe_out_data  = fifo_empty ? fifo_in_data  : fifo_out_data;



reg [FIFO_DEPTH_BASE2-1:0] outstanding_xfer;

wire s_pipe_out_data_valid;

assign s_pipe_out_data_valid = !halt_in && (!fifo_empty || pipe_in_data_valid_delay[PIPE_LATENCY_PLUS_REGOUT-1]);

// Implement an outstanding transfers counter. The counter keeps track of the number of spaces
// available in the FIFO to accommodate the new data coming in. The counter increments when a
// RAM read access is made no matter the latency of the READ data and decrements when data is
// accepted at the output of the block.
always @(posedge core_clk or negedge core_rst_n) begin
   if (!core_rst_n) begin
       outstanding_xfer <= #TP {FIFO_DEPTH_BASE2{1'b0}};
   end else begin
      if (pipe_in_data_valid && !s_pipe_out_data_valid) begin
         outstanding_xfer <= #TP outstanding_xfer + 1;
      end else if (!pipe_in_data_valid && s_pipe_out_data_valid && (outstanding_xfer > 0)) begin
         outstanding_xfer <= #TP outstanding_xfer - 1;
      end
   end
end

assign halt_out = (outstanding_xfer < HALT_LVL) ? 1'b0 : 1'b1;

assign pipe_out_data_valid = fifo_empty ? pipe_in_data_valid_delay[PIPE_LATENCY_PLUS_REGOUT-1] : 1'b1;


`ifndef SYNTHESIS

wire    [(20*8)-1:0]        FIFO_STATE;
wire    [(20*8)-1:0]        NEXT_FIFO_STATE;

assign  FIFO_STATE =
               ( fifo_state == S_NO_PUSH                 ) ? "S_NO_PUSH" :
               ( fifo_state == S_PUSH                    ) ? "S_PUSH" :
                                                         "Bogus";
assign  NEXT_FIFO_STATE =
               ( next_fifo_state == S_NO_PUSH            ) ? "S_NO_PUSH" :
               ( next_fifo_state == S_PUSH               ) ? "S_PUSH" :
                                                         "Bogus";

`endif // SYNTHESIS


endmodule


