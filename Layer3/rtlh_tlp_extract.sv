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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_tlp_extract.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles parsing of received Transaction Layer Packets (TLPs).
// --- Its main functions are:
// ---    (1) Align data onto header and address busses for 128bit
//        architecture due to the bandwidth requirement
//        (2) Align header and data onto the data bus for 64bit and 32bit
//        architectures and using hv and dv to indicate header or data
//        valid. hv and dv will not asserted at the same cycle for 64 and
//        32bit architectures

// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rtlh_tlp_extract(
    core_clk,
    core_rst_n,

    rtlh_ecrc_data,
    rtlh_ecrc_sot,
    rtlh_ecrc_dv,
    rtlh_ecrc_eot,
    rtlh_ecrc_abort,
    rtlh_ecrc_err,
    rtlh_ecrc_len_mismatch,

    
// outputs
    rtlh_extrct_data,
    rtlh_extrct_hdr,
    rtlh_extrct_dwen,
    rtlh_extrct_sot,
    rtlh_extrct_dv,
    rtlh_extrct_eot,
    rtlh_extrct_abort,
    rtlh_extrct_ecrc_len_mismatch,
    rtlh_extrct_ecrc_err,
    rtlh_extrct_parerr
);

parameter  INST                = 0;                           // The uniquifying parameter for each port logic instance.
parameter  NW                  = `CX_NW;                      // Number of 32-bit dwords handled by the datapath each clock.
parameter  DW                  = (32*NW);                     // Width of datapath in bits.
parameter  TP                  = `TP;                         // Clock to Q delay (simulator insurance)
                               
parameter DATA_PROT_WD          = `TRGT_DATA_PROT_WD;
parameter RAS_PCIE_HDR_PROT_WD  = `CX_RAS_PCIE_HDR_PROT_WD;
parameter DW_W_PAR              = DW + DATA_PROT_WD;
parameter HW_W_PAR              = 128+RAS_PCIE_HDR_PROT_WD;

localparam RX_TLP               = `CX_RX_TLP;                 // Number of TLPs that can be processed in a single cycle


// Slave processor parameters
localparam SNW                 = 4;                           // Number of 32-bit dwords handled by each slave processor.
localparam SNW_LOG2            = log2floor(SNW);
localparam SDW                 = (32*SNW);                    // Width of datapath processed by each slave processor in bits.


// -------------------------------- Inputs -------------------------------------
input                     core_clk;                       // Core clock
input                     core_rst_n;                     // Core system reset

input   [DW_W_PAR-1:0]    rtlh_ecrc_data;
input   [NW-1:0]          rtlh_ecrc_sot;

input                     rtlh_ecrc_dv;
input   [NW-1:0]          rtlh_ecrc_eot;
input   [RX_TLP-1:0]      rtlh_ecrc_abort;
input   [RX_TLP-1:0]      rtlh_ecrc_err;
input   [RX_TLP-1:0]      rtlh_ecrc_len_mismatch;


// -------------------------------- Outputs------------------------------------


output                    rtlh_extrct_parerr;             // Parity/ECC Error flag
output  [DW_W_PAR-1:0]          rtlh_extrct_data;               // Data (payload/hdr) of TLP packet
output  [(RX_TLP*HW_W_PAR)-1:0] rtlh_extrct_hdr;                // hdr of TLP packet for 128bit architecture only
output  [NW-1:0]                rtlh_extrct_dwen;               // Data dword enable
output  [RX_TLP-1:0]            rtlh_extrct_dv;                 // Data (payload for 128b and 64bit arch, payload and hdr for 32bit arch) is valid this cycle
output  [RX_TLP-1:0]            rtlh_extrct_sot;                // Header cycle of a TLP
output  [RX_TLP-1:0]            rtlh_extrct_eot;                // End of TLP indication
output  [RX_TLP-1:0]            rtlh_extrct_abort;              // DLLP layer abort due to DLLP layer detecting error
output  [RX_TLP-1:0]            rtlh_extrct_ecrc_len_mismatch;  // ECRC err when there is an ECRC length mismatch
output  [RX_TLP-1:0]            rtlh_extrct_ecrc_err;           // ECRC err when there is an ECRC

// ----------------- internal design ------------------------------------
wire [DW_W_PAR-1:0]    int_rtlh_data;
wire [NW-1:0]          int_rtlh_sot;
wire                   int_rtlh_dv;
wire [NW-1:0]          int_rtlh_eot;
wire [RX_TLP-1:0]      int_rtlh_abort;
wire [RX_TLP-1:0]      int_rtlh_ecrc_err;
wire [RX_TLP-1:0]      int_rtlh_ecrc_len_mismatch;

assign  int_rtlh_data =              rtlh_ecrc_data;
assign  int_rtlh_sot =               rtlh_ecrc_sot;
assign  int_rtlh_dv =                rtlh_ecrc_dv;
assign  int_rtlh_eot =               rtlh_ecrc_eot;
assign  int_rtlh_abort =             rtlh_ecrc_abort;
assign  int_rtlh_ecrc_err =          rtlh_ecrc_err;
assign  int_rtlh_ecrc_len_mismatch = rtlh_ecrc_len_mismatch;


// ----------------------------------------------------------------------------
// Support Functions
// ----------------------------------------------------------------------------

// Only used for parameter calculation
function automatic integer log2floor;
    input integer value;
    begin
        log2floor = 1;
        while(1<<log2floor < value)
            log2floor = log2floor + 1;
    end
endfunction

  




// ====================== TLP Extract/Alignment START for 64b interface ================================
// ----------------------------------------------------------------------------
// Beneath is the code that is designed for extract a TLP out of the rdlh
// 64bit interface where sot and eot are  NW wide vectors to a single bit control
// interface
// ----------------------------------------------------------------------------
// Design is to extract the tlp from rdlh interface into a hdr and data
// seperated interface where header is part of the first 2 cycle of a tlp
// and data is after regardless of a 3 hdr or 4 hdr dword
// ----------------------------------------------------------------------------
// Registered outputs
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- State Parameters
// ----------------------------------------------------------------------------

parameter S_IDLE                 = 3'h0;
parameter S_HDR_ODD              = 3'h1;
parameter S_HDR_EVEN             = 3'h2;
parameter S_PYLD_DATA_ODD        = 3'h3;
parameter S_PYLD_DATA_EVEN       = 3'h4;
parameter S_HDR_EXTRA            = 3'h5;
parameter S_PYLD_EXTRA_END       = 3'h6;
parameter S_HDR_EXTRA_END        = 3'h7;

wire [((128*RX_TLP) - 1):0] rtlh_extrct_hdr_int;
assign rtlh_extrct_hdr_int = {(128*RX_TLP){1'b0}};
reg  [DW-1:0]       rtlh_extrct_data_int;
reg  [NW-1:0]       rtlh_extrct_dwen;
reg  [RX_TLP-1:0]   rtlh_extrct_sot;
reg  [RX_TLP-1:0]   rtlh_extrct_dv;
reg  [RX_TLP-1:0]   rtlh_extrct_eot;
reg  [RX_TLP-1:0]   rtlh_extrct_abort;
reg  [RX_TLP-1:0]   rtlh_extrct_ecrc_err;
reg  [RX_TLP-1:0]   rtlh_extrct_ecrc_len_mismatch;

reg  [DW-1:0]       tmp_extrct_data;
reg  [NW-1:0]       tmp_extrct_dwen;
reg                 tmp_extrct_sot;
reg                 tmp_extrct_dv;
reg                 tmp_extrct_eot;
reg                 tmp_extrct_abort;
reg                 tmp_extrct_ecrc_err;
reg                 tmp_extrct_ecrc_len_mismatch;
reg                 tmp_dlyd_data_en;
reg                 dlyd_data_en;

reg  [DW-1:0]       int_rtlh_data_d;
reg  [2:0]          current_state;
reg  [2:0]          next_state;
reg                 clkd_rtlh_abort;
reg                 clkd_rtlh_ecrc_err;
reg                 clkd_rtlh_ecrc_len_mismatch;
reg                 clkd2_rtlh_ecrc_len_mismatch;
reg  [NW-1:0]       clkd_rtlh_eot;
reg                 int_latchd_hdr_4dw;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        clkd_rtlh_abort              <= #TP 0;
        clkd_rtlh_eot                <= #TP 0;
        clkd_rtlh_ecrc_err           <= #TP 0;
        clkd_rtlh_ecrc_len_mismatch  <= #TP 0;
        clkd2_rtlh_ecrc_len_mismatch <= #TP 0;
    end else if (int_rtlh_dv) begin
        clkd_rtlh_abort              <= #TP int_rtlh_abort[0];
        clkd_rtlh_eot                <= #TP int_rtlh_eot;
        clkd_rtlh_ecrc_err           <= #TP int_rtlh_ecrc_err[RX_TLP-1:0];
        clkd_rtlh_ecrc_len_mismatch  <= #TP int_rtlh_ecrc_len_mismatch[RX_TLP-1:0];
        clkd2_rtlh_ecrc_len_mismatch <= #TP clkd_rtlh_ecrc_len_mismatch;
    end
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        int_rtlh_data_d             <= #TP 0;
        dlyd_data_en                <= #TP 0;
    end else if (int_rtlh_dv) begin
        int_rtlh_data_d             <= #TP int_rtlh_data[DW-1:0];
        dlyd_data_en                <= #TP tmp_dlyd_data_en; // this signal is designed to latch the condition that we have inserted an extra hdr delay such that the data will be delay evenly.
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        int_latchd_hdr_4dw               <= #TP 0;
    end else if (int_rtlh_sot[0]) begin
        int_latchd_hdr_4dw               <= #TP int_rtlh_data[5];
    end else if (int_rtlh_sot[1]) begin
        int_latchd_hdr_4dw               <= #TP int_rtlh_data[37];
    end

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        current_state                 <= #TP S_IDLE;
    else if (int_rtlh_dv | (current_state == S_PYLD_EXTRA_END) | (current_state == S_HDR_EXTRA_END))  // hdr or data can be inserted to an extra cycle where DV may not be asserted
        current_state                 <= #TP next_state;
end

wire  or_eot;
assign or_eot = |int_rtlh_eot;

always @(/*AUTOSENSE*/clkd2_rtlh_ecrc_len_mismatch or clkd_rtlh_abort
         or clkd_rtlh_ecrc_err or clkd_rtlh_ecrc_len_mismatch
         or clkd_rtlh_eot or current_state or dlyd_data_en
         or int_latchd_hdr_4dw or int_rtlh_abort or int_rtlh_data
         or int_rtlh_data_d or int_rtlh_ecrc_err
         or int_rtlh_ecrc_len_mismatch or int_rtlh_eot or int_rtlh_sot
         or or_eot)
begin
        case(current_state)
        S_IDLE:  begin
            if (int_rtlh_sot[0] & !or_eot)
               next_state             = S_HDR_EVEN ;
            else if (int_rtlh_sot[1] & !or_eot)
               next_state             = S_HDR_ODD ;
            else
               next_state             = S_IDLE;

           tmp_extrct_sot            = int_rtlh_sot[0] & !or_eot;
           tmp_extrct_eot            = 1'b0;
           tmp_extrct_dv             = 1'b0;
           tmp_extrct_abort          = 1'b0;
           tmp_extrct_ecrc_err       = 1'b0;
           tmp_extrct_ecrc_len_mismatch = 1'b0;
           tmp_extrct_dwen           = {NW{1'b1}};
           tmp_extrct_data           = int_rtlh_data[DW-1:0] ;
           tmp_dlyd_data_en          = 1'b0;
        end
        S_HDR_EVEN: begin  // hdr + maybe payload
            if (int_rtlh_eot[0] | (int_rtlh_eot[1] & int_latchd_hdr_4dw)) // no payload exist
               next_state             = S_IDLE ;
            else if (int_rtlh_eot[1] & !int_latchd_hdr_4dw) // 1dword payload exist
               next_state             = S_PYLD_EXTRA_END ;
            else if (!int_latchd_hdr_4dw) // 1dword payload exist
               next_state             = S_PYLD_DATA_ODD ;
            else
               next_state             = S_PYLD_DATA_EVEN ;

           tmp_extrct_sot            = 1'b1;
           tmp_extrct_eot            = (int_rtlh_eot[0]) | (int_rtlh_eot[1] & int_latchd_hdr_4dw);
           tmp_extrct_dv             = 1'b0;
           tmp_extrct_abort          = (int_rtlh_eot[0] | (int_rtlh_eot[1] & int_latchd_hdr_4dw)) & int_rtlh_abort;
           tmp_extrct_ecrc_err       = (int_rtlh_eot[0] | (int_rtlh_eot[1] & int_latchd_hdr_4dw)) & int_rtlh_ecrc_err;
           tmp_extrct_ecrc_len_mismatch = int_rtlh_ecrc_len_mismatch | clkd_rtlh_ecrc_len_mismatch;
           tmp_extrct_dwen           = {NW{1'b1}};
           tmp_extrct_data           = int_rtlh_data[DW-1:0] ;
           tmp_dlyd_data_en          = 1'b0;
        end
        S_HDR_ODD: begin  // hdr + maybe payload
           if (or_eot)
               next_state             = S_HDR_EXTRA_END ;   // no payload exit
           else
               next_state             = S_HDR_EXTRA ;

           tmp_extrct_sot               = 1'b1;
           tmp_extrct_eot               = 1'b0;
           tmp_extrct_dv                = 1'b0;
           tmp_extrct_abort             = int_rtlh_abort[RX_TLP-1:0];
           tmp_extrct_ecrc_err          = int_rtlh_ecrc_err[RX_TLP-1:0];
           tmp_extrct_ecrc_len_mismatch = clkd_rtlh_ecrc_len_mismatch;
           tmp_extrct_dwen              = {NW{1'b1}};
           tmp_extrct_data              = {int_rtlh_data[31:0], int_rtlh_data_d[63:32]};
           tmp_dlyd_data_en             = 1'b0;
        end
        S_HDR_EXTRA_END: begin  // hdr last cycle
            // If there is a sot asserted, it is an error condition
           if (int_rtlh_sot[0] & !or_eot)
               next_state             = S_HDR_EVEN ;
           else if (int_rtlh_sot[1] & !or_eot)
               next_state             = S_HDR_ODD ;
           else
               next_state             = S_IDLE;

           tmp_extrct_sot            = 1'b1;
           tmp_extrct_eot            = 1'b1;
           tmp_extrct_dv             = 1'b0;
           tmp_extrct_abort          = clkd_rtlh_abort;
           tmp_extrct_ecrc_err       = clkd_rtlh_ecrc_err;
           tmp_extrct_ecrc_len_mismatch = clkd_rtlh_ecrc_len_mismatch | clkd2_rtlh_ecrc_len_mismatch;
           tmp_extrct_dwen           = {int_latchd_hdr_4dw, 1'b1};
           tmp_extrct_data           = {int_rtlh_data[31:0], int_rtlh_data_d[63:32]};
           tmp_dlyd_data_en          = 1'b0;
        end
        S_HDR_EXTRA: begin  // extra header in this cycle + may be payload, This state is a wait state to collect all hdrs
           if (int_rtlh_eot[0] & int_latchd_hdr_4dw) begin   // no payload exist
               next_state             = S_IDLE ;
               tmp_dlyd_data_en       = 1'b0;
           end  else if (or_eot) begin // 1 or 2 dword of payload
               next_state             = S_PYLD_EXTRA_END ;
               tmp_dlyd_data_en       = !int_latchd_hdr_4dw; // when it is 4hdr, then it will be an odd alignment,
           end  else if (int_latchd_hdr_4dw) begin
               next_state             = S_PYLD_DATA_ODD ;
               tmp_dlyd_data_en       = 1'b0;
           end  else  begin
               next_state             = S_PYLD_DATA_EVEN ;
               tmp_dlyd_data_en       = 1'b1;
           end

           tmp_extrct_sot            = 1'b1;
           tmp_extrct_eot            = int_rtlh_eot[0] & int_latchd_hdr_4dw;
           tmp_extrct_dv             = 1'b0;
           tmp_extrct_abort          = (int_rtlh_eot[0] & int_latchd_hdr_4dw) & int_rtlh_abort;
           tmp_extrct_ecrc_err       = (int_rtlh_eot[0] & int_latchd_hdr_4dw) & int_rtlh_ecrc_err;
           tmp_extrct_ecrc_len_mismatch = clkd_rtlh_ecrc_len_mismatch;
           tmp_extrct_dwen           = {(!(int_rtlh_eot[0] & int_latchd_hdr_4dw)), 1'b1};
           tmp_extrct_data           = {int_rtlh_data[31:0], int_rtlh_data_d[63:32]};
        end
        S_PYLD_EXTRA_END: begin
           if (int_rtlh_sot[0] & !or_eot)
               next_state             = S_HDR_EVEN ;
           else if (int_rtlh_sot[1] & !or_eot)
               next_state             = S_HDR_ODD ;
           else
               next_state             = S_IDLE;

           tmp_extrct_sot            = int_rtlh_sot[0];
           tmp_extrct_eot            = 1'b1;
           tmp_extrct_dv             = 1'b1;
           tmp_extrct_abort          = clkd_rtlh_abort;
           tmp_extrct_ecrc_err       = clkd_rtlh_ecrc_err;
           tmp_extrct_ecrc_len_mismatch = clkd_rtlh_ecrc_len_mismatch | clkd2_rtlh_ecrc_len_mismatch;
           tmp_extrct_dwen           = {(dlyd_data_en & clkd_rtlh_eot[1]), 1'b1};
           tmp_extrct_data           = dlyd_data_en ? int_rtlh_data_d : {int_rtlh_data[31:0], int_rtlh_data_d[63:32]};
           tmp_dlyd_data_en          = 1'b0;
        end
        S_PYLD_DATA_EVEN: begin
           if (or_eot & !dlyd_data_en)
               next_state             = S_IDLE ;
           else if (or_eot)
               next_state             = S_PYLD_EXTRA_END ;
            // If there is a sot asserted, it is an error condition
           else if (int_rtlh_sot[0] & !or_eot)
               next_state             = S_HDR_EVEN ;
           else if (int_rtlh_sot[1] & !or_eot)
               next_state             = S_HDR_ODD ;
           else
               next_state             = S_PYLD_DATA_EVEN ;

           if (int_rtlh_eot[0] & !dlyd_data_en) begin
               tmp_extrct_dwen       = 2'b01 ;
           end else begin
               tmp_extrct_dwen       = 2'b11;
           end
           tmp_extrct_sot            = int_rtlh_sot[0];
           tmp_extrct_dv             = 1'b1;
           tmp_extrct_eot            = or_eot            & !int_rtlh_sot[0] & !dlyd_data_en;
           tmp_extrct_abort          = int_rtlh_abort    & !int_rtlh_sot[0] & !dlyd_data_en;
           tmp_extrct_ecrc_err       = int_rtlh_ecrc_err & !int_rtlh_sot[0] & !dlyd_data_en;
           tmp_extrct_ecrc_len_mismatch = clkd_rtlh_ecrc_len_mismatch;
           tmp_extrct_data           = dlyd_data_en ? int_rtlh_data_d : int_rtlh_data[DW-1:0];
           tmp_dlyd_data_en          = dlyd_data_en;
        end
        S_PYLD_DATA_ODD: begin
           if (int_rtlh_eot[0])
               next_state             = S_IDLE ;
           else if (int_rtlh_eot[1])
               next_state             = S_PYLD_EXTRA_END ;
            // If there is a sot asserted, it is an error condition
           else if (int_rtlh_sot[0] & !or_eot)
               next_state             = S_HDR_EVEN ;
           else if (int_rtlh_sot[1] & !or_eot)
               next_state             = S_HDR_ODD ;
           else
               next_state             = S_PYLD_DATA_ODD ;

           tmp_extrct_dwen           = 2'b11;
           tmp_extrct_sot            = 1'b0;
           tmp_extrct_dv             = 1'b1;
           tmp_extrct_eot            = int_rtlh_eot[0];
           tmp_extrct_abort          = int_rtlh_abort    & int_rtlh_eot[0];
           tmp_extrct_ecrc_err       = int_rtlh_ecrc_err & int_rtlh_eot[0];
           tmp_extrct_ecrc_len_mismatch = clkd_rtlh_ecrc_len_mismatch;
           tmp_extrct_data           = {int_rtlh_data[31:0], int_rtlh_data_d[63:32]};
           tmp_dlyd_data_en          = 1'b0;
        end
// default cannot be reached.
//        default: begin
//           next_state                 = S_IDLE;
//           tmp_extrct_sot            = 1'b0;
//           tmp_extrct_eot            = 1'b0;
//           tmp_extrct_dv             = 1'b0;
//           tmp_extrct_abort          = 1'b0;
//           tmp_extrct_ecrc_err       = 1'b0;
//           tmp_extrct_dwen           = 2'b0;
//           tmp_extrct_data           = int_rtlh_data[DW-1:0];
//           tmp_dlyd_data_en          = 1'b0;
//        end
        endcase
end

wire output_en;
assign output_en = (int_rtlh_dv | (current_state == S_PYLD_EXTRA_END) | (current_state == S_HDR_EXTRA_END)) ; // hdr or data can be inserted to an extra cycle where DV may not be asserted
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        rtlh_extrct_sot                <= #TP 0;
        rtlh_extrct_eot                <= #TP 0;
        rtlh_extrct_dv                 <= #TP 0;
        rtlh_extrct_dwen               <= #TP 0;
        rtlh_extrct_data_int           <= #TP 0;
        rtlh_extrct_abort              <= #TP 0;
        rtlh_extrct_ecrc_err           <= #TP 0;
        rtlh_extrct_ecrc_len_mismatch  <= #TP 0;
    end else begin
        rtlh_extrct_sot                <= #TP tmp_extrct_sot     & output_en;
        rtlh_extrct_eot                <= #TP tmp_extrct_eot     & output_en;
        rtlh_extrct_dv                 <= #TP tmp_extrct_dv      & output_en;
        rtlh_extrct_abort              <= #TP tmp_extrct_abort    & output_en;
        rtlh_extrct_ecrc_err           <= #TP tmp_extrct_ecrc_err & output_en;
        rtlh_extrct_ecrc_len_mismatch  <= #TP tmp_extrct_ecrc_len_mismatch & output_en;

        if(output_en) begin
           rtlh_extrct_dwen            <= #TP tmp_extrct_dwen;
           rtlh_extrct_data_int        <= #TP tmp_extrct_data;
        end
    end
// ====================== TLP Extract/Alignment END for 64b interface ================================



assign rtlh_extrct_parerr = 0;
assign rtlh_extrct_data   = rtlh_extrct_data_int;
assign rtlh_extrct_hdr    = rtlh_extrct_hdr_int;


`ifndef SYNTHESIS
`endif // SYNTHESIS



endmodule
