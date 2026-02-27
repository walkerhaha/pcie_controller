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
// ---    $DateTime: 2019/10/03 14:27:33 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/xadm_out_formation.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// Takes formed 128bit TLPs converts to data path to 64/32
// bit data path applications -- as configured.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xadm_out_formation
   (
// ------ Inputs ------
    core_rst_n,
    core_clk,
    xtlh_xadm_halt,

    formed_tlp_hv,
    formed_tlp_hdr,
    formed_addr_parerr,
    formed_tlp_dv,
    formed_tlp_data,
    formed_data_parerr,
    formed_tlp_dwen,
    formed_tlp_eot,
    formed_tlp_badeot,
    formed_tlp_add_ecrc,


// ------ Outputs ------
    xadm_xtlh_soh,
    xadm_xtlh_hv,
    xadm_xtlh_hdr,
    xadm_xtlh_dv,
    xadm_xtlh_data,
    xadm_xtlh_dwen,
    xadm_xtlh_eot,
    xadm_xtlh_sot,
    xadm_xtlh_bad_eot,
    xadm_xtlh_add_ecrc,


    out_formation_out_halt,
    xadm_xtlh_parerr
    ,
    xadm_halted
);

parameter INST              = 0;                        // The uniquifying parameter for each port logic instance.
parameter NW                = `CX_NW;                   // Number of 32-bit dwords handled by the datapath each clock.
parameter DATA_PAR_WD       =`TRGT_DATA_PROT_WD;
parameter RAS_PCIE_HDR_PROT_WD  = `CX_RAS_PCIE_HDR_PROT_WD;
parameter RAS_PCIE_HDR_WD   = 128 + RAS_PCIE_HDR_PROT_WD;
parameter PAR_CALC_WIDTH    = `DATA_BUS_PAR_CALC_WIDTH;
parameter DW                = (32*NW);                  // Width of datapath in bits.
parameter TP                = `TP;                      // Clock to Q delay (simulator insurance)


parameter PF_WD             = `CX_NFUNC_WD;                // Width of physical function number signal

parameter S_IDLE            = 4'h0;
parameter S_IN_HDR1_XMT     = 4'h1;
parameter S_IN_HDR2_XMT     = 4'h2;
parameter S_IN_HDR3_XMT     = 4'h3;
parameter S_IN_DATA_XMT     = 4'h4;
parameter S_EXTEND_XMT      = 4'h5;


// states for Prefix - 64-bit 
parameter S_IN_H1_H0_XMT    = 4'h6;
parameter S_IN_H2_H1_XMT    = 4'h7;
parameter S_IN_H0_P2_XMT    = 4'h8;
parameter S_IN_H0_P4_XMT    = 4'h9;
parameter S_IN_H0_P6_XMT    = 4'ha;

parameter S_IN_P3_P2_XMT    = 4'hb;
parameter S_IN_P5_P4_XMT    = 4'hc;
parameter S_IN_P7_P6_XMT    = 4'hd;

parameter S_IN_H3_XMT     = 4'he;



// states for Prefix - 32-bit 

parameter S_IN_H0_XMT    = 4'h6;
parameter S_IN_P1_XMT    = 4'h7;
parameter S_IN_P2_XMT    = 4'h8;
parameter S_IN_P3_XMT    = 4'h9;

parameter S_IN_P4_XMT    = 4'ha;
parameter S_IN_P5_XMT    = 4'hb;
parameter S_IN_P6_XMT    = 4'hc;
parameter S_IN_P7_XMT    = 4'hd;




localparam ATTR_WD = `SF_HDR_TLP_ATTR;
localparam TAG_SIZE = `CX_TAG_SIZE;

input                         core_rst_n;
input                         core_clk;
input                         xtlh_xadm_halt;           // back pressure from Core
input                         formed_tlp_hv;            // multiplexed client tlp header valid
input                         formed_addr_parerr;       // detected the parity error at the address within the formed_tlp_hdr
input                         formed_data_parerr;       // detected the parity error at the data within the formed_tlp_data
input [128-1+RAS_PCIE_HDR_PROT_WD :0 ]formed_tlp_hdr;// multiplexed client tlp header + ECC PROT
input                         formed_tlp_dv;            // multiplexed client tlp data valid
input [DW+DATA_PAR_WD-1 :0 ]  formed_tlp_data;          // multiplexed client tlp data
input [NW-1 :0 ]              formed_tlp_dwen;          // multiplexed client dwen
input                         formed_tlp_eot;           // multiplexed client end of tlp
input                         formed_tlp_badeot;        // multiplexed client bad eot
input                         formed_tlp_add_ecrc;

output                        xadm_xtlh_hv;             // Header valid
output [RAS_PCIE_HDR_WD-1:0]  xadm_xtlh_hdr;            // Header bus
output                        xadm_xtlh_dv;             // data valid
output [1:0]                  xadm_xtlh_soh;            // Indicates start of header loacation for 32/64-bit
output [DW+DATA_PAR_WD-1:0]   xadm_xtlh_data;           // data bus
output [NW-1:0]               xadm_xtlh_dwen;           //
output                        xadm_xtlh_eot;            // end of transaction
output                        xadm_xtlh_sot;            // start of transaction
output                        xadm_xtlh_bad_eot;        // end of transaction
output                        xadm_xtlh_add_ecrc;
output                        out_formation_out_halt;   // back pressure signal to halt upstream flow.
output                        xadm_xtlh_parerr;         // parity error detected at xadm outputs;





output                        xadm_halted;

reg                           int_128b_hv;
reg                           int_128b_dv;
reg                           int_128b_eot;
reg                           int_128b_badeot;
reg                           int_128b_add_ecrc;
reg                           int_128b_addr_parerr;
// int_128b_addr_parerr qualified by int_128b_hv
wire                          int_128b_addr_parerr_qual;
reg                           int_128b_data_parerr;
reg [127   :0]                int_128b_hdr_inpar;
wire[127   :0]                int_128b_hdr;
reg [127  :0 ]                latchd_tlp_hdr;
reg [DW+DATA_PAR_WD-1 :0]     int_128b_data_inpar;
wire [DW+DATA_PAR_WD-1 :0]    int_128b_data;
reg [NW-1 :0]                 int_128b_dwen;

reg                               muxd_parerr;
reg [127+RAS_PCIE_HDR_PROT_WD :0] muxd_hdr;
reg [(NW*32)-1 :0]            muxd_data;
reg [NW-1 :0]                 muxd_dwen;
wire                          muxd_hv;
wire                          muxd_dv;
wire                          muxd_eot;
wire                          muxd_badeot;
reg                           muxd_add_ecrc;

reg                           latchd_tlp_hv;
reg                           latchd_addr_parerr;
reg                           latchd_data_parerr;
reg                           latchd_tlp_dv;
reg [DW+DATA_PAR_WD-1 :0 ]    latchd_tlp_data;
reg [NW-1 :0 ]                latchd_tlp_dwen;
reg                           latchd_tlp_eot;
reg                           latchd_tlp_badeot;
reg                           latchd_tlp_add_ecrc;

reg                           out_halt;
wire                          halt_128b_interface;
wire                          int_halt;

reg [3:0]                     current_state;

wire [3:0]                    next_state;

wire                          tlp_from_client;
wire                          tlp_has_ecrc;
wire                          tlp_has_pyld;
wire                          tlp_hdr_4dw;
wire                          tlp_payload_and_ecrc;
wire                          pipe_start;
wire                          pipe_stall;




reg [1:0]       muxd_soh;








assign tlp_from_client = !muxd_add_ecrc;
assign tlp_has_ecrc    = int_128b_hdr[23];
assign tlp_hdr_4dw     = int_128b_hdr[5];
assign tlp_has_pyld    = int_128b_hdr[6];

assign tlp_payload_and_ecrc   = tlp_has_pyld;

assign int_halt = ( (current_state == S_IDLE) || xtlh_xadm_halt  || (next_state == S_EXTEND_XMT) 
                    || ((current_state == S_IN_HDR1_XMT) && tlp_payload_and_ecrc && ((int_128b_eot && (int_128b_dwen[NW-1] || tlp_hdr_4dw)) ||
                                                                                    (!int_128b_eot && tlp_hdr_4dw && int_128b_dwen[NW-1]))));




assign  halt_128b_interface   = int_halt && (int_128b_hv || int_128b_dv);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
         out_halt                 <= #TP 0;
    else
         out_halt                 <= #TP halt_128b_interface;

assign xadm_halted = xtlh_xadm_halt || pipe_stall;

assign pipe_start = !halt_128b_interface && out_halt;
assign pipe_stall = halt_128b_interface && !out_halt;

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        latchd_tlp_hv                   <= #TP 0;
        latchd_tlp_hdr                  <= #TP 0;
        latchd_addr_parerr              <= #TP 0;
        latchd_data_parerr              <= #TP 0;
        latchd_tlp_dwen                 <= #TP 0;
        latchd_tlp_data                 <= #TP 0;
        latchd_tlp_eot                  <= #TP 0;
        latchd_tlp_dv                   <= #TP 0;
        latchd_tlp_badeot               <= #TP 0;
        latchd_tlp_add_ecrc             <= #TP 0;
    end else begin
        if (pipe_stall) begin
        latchd_tlp_hv                  <= #TP formed_tlp_hv;

        latchd_tlp_hdr                 <= #TP formed_tlp_hdr;
        latchd_addr_parerr             <= #TP formed_addr_parerr;
        latchd_data_parerr             <= #TP formed_data_parerr;
        latchd_tlp_dwen                <= #TP formed_tlp_dwen;
        latchd_tlp_data                <= #TP formed_tlp_data;
        latchd_tlp_eot                 <= #TP formed_tlp_eot;
        latchd_tlp_dv                  <= #TP formed_tlp_dv;
        latchd_tlp_badeot              <= #TP formed_tlp_badeot;
        latchd_tlp_add_ecrc            <= #TP formed_tlp_add_ecrc;

    end

    end // else: !if(!core_rst_n)

end // always @ (posedge core_clk or negedge core_rst_n)



always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
                int_128b_hv             <= #TP   0;
                int_128b_eot            <= #TP   0;
                int_128b_badeot         <= #TP   0;
                int_128b_dv             <= #TP   0;
                int_128b_data_inpar[DW-1:0] <= #TP   0;
                int_128b_hdr_inpar[127:0]   <= #TP   0;
                int_128b_dwen           <= #TP   0;
                int_128b_add_ecrc       <= #TP   0;
                int_128b_addr_parerr    <= #TP   0;
                int_128b_data_parerr    <= #TP   0;
    end else if (pipe_start) begin
                int_128b_hv             <= #TP   latchd_tlp_hv;
                int_128b_eot            <= #TP   latchd_tlp_eot;
                int_128b_badeot         <= #TP   latchd_tlp_badeot;
                int_128b_dv             <= #TP   latchd_tlp_dv;
                int_128b_data_inpar     <= #TP   latchd_tlp_data;
                int_128b_dwen           <= #TP   latchd_tlp_dwen;
                int_128b_hdr_inpar      <= #TP   latchd_tlp_hdr;
                int_128b_add_ecrc       <= #TP   latchd_tlp_add_ecrc;
                int_128b_addr_parerr    <= #TP   latchd_addr_parerr;
                int_128b_data_parerr    <= #TP   latchd_data_parerr;
             
    end else if (!halt_128b_interface) begin
                int_128b_hv             <= #TP   formed_tlp_hv;
                int_128b_eot            <= #TP formed_tlp_eot;
                int_128b_badeot         <= #TP   formed_tlp_badeot;
                int_128b_add_ecrc       <= #TP   formed_tlp_add_ecrc;
                int_128b_dv             <= #TP   formed_tlp_dv;
                int_128b_data_inpar     <= #TP   formed_tlp_data;
                int_128b_dwen           <= #TP   formed_tlp_dwen;
                int_128b_hdr_inpar      <= #TP   formed_tlp_hdr;
                int_128b_addr_parerr    <= #TP   formed_addr_parerr;
                int_128b_data_parerr    <= #TP   formed_data_parerr;
    end
end

// int_128b_addr_parerr qualified by int_128b_hv - to be used instead of int_128b_addr_parerr && int_128b_hv
assign int_128b_addr_parerr_qual = (int_128b_hv)? int_128b_addr_parerr: 1'b0;

wire out_formation_data_parerr;
assign int_128b_data   = int_128b_data_inpar;
assign int_128b_hdr              = int_128b_hdr_inpar;
assign out_formation_data_parerr = 1'b0;


//   -------------------------    Logic For TLP Prefix    --------

wire [3:0] prfx_nw; 
wire [7:0] prfx_dwen;
wire [7:0] l_prfx_dwen;
wire [7:0] e_prfx_dwen;

assign prfx_dwen = 8'h00;
assign l_prfx_dwen = 8'h00;
assign e_prfx_dwen = 8'h00;
assign prfx_nw = 4'h0;



wire no_prefix;
assign no_prefix = ~(|prfx_dwen[7:0]);

reg h3_flag;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        h3_flag      <= #TP 0;
    end else begin
      if (current_state == S_IN_H3_XMT)
        h3_flag <= #TP 1'b1;
      else if (current_state == S_IDLE)
           h3_flag <= #TP 1'b0;   
      end    

reg h2_h1_flag;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        h2_h1_flag      <= #TP 0;
    end else begin
      if (current_state == S_IN_H2_H1_XMT)
        h2_h1_flag <= #TP 1'b1;
      else if (current_state == S_IDLE || current_state == S_IN_H3_XMT)
             h2_h1_flag <= #TP 1'b0;   
      end

//  ---------------------------------------------


// state machine to control the hdr and data merge

reg  latchd_tlp_hdr_4dw;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latchd_tlp_hdr_4dw      <= #TP 0;
    end else begin
        if (!xtlh_xadm_halt && (current_state == S_IDLE) && int_128b_hv)
        latchd_tlp_hdr_4dw      <= #TP tlp_hdr_4dw;
    end


// state machine to control the fork of hdr and data
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        current_state           <= #TP S_IDLE;
    else if (!xtlh_xadm_halt)
        current_state           <= #TP next_state;

// clkd_data32 is only used in a process below if NW_2 is defined     
reg [31:0] clkd_data32;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        clkd_data32             <= #TP 0;
    else if (!xtlh_xadm_halt)
        clkd_data32             <= #TP int_128b_data[(NW*32) -1:((NW*32) -32)];

///////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////
reg     [3:0]      int_next_state;
always @(current_state or int_128b_dv or
         int_128b_hv or
         latchd_tlp_hdr_4dw or
         tlp_payload_and_ecrc or
         int_128b_dwen or
         int_128b_eot or tlp_hdr_4dw or
         h2_h1_flag or h3_flag 
       )
begin: FORMATION_STATEMACHINE_NW_2

     case (current_state)
         S_IDLE:
            // We need to identify if we have payload extend over the hdr cycle
           // If PRefix words are valid, first 2 prefix DWs are transferred in IDLE


            if  (int_128b_hv)                 // 0 Prefix DWORDs    
                int_next_state   = S_IN_HDR1_XMT;
            else
                int_next_state   = S_IDLE;


         S_IN_HDR1_XMT:
            if (int_128b_eot && tlp_payload_and_ecrc && (int_128b_dwen[NW-1] || tlp_hdr_4dw))
               int_next_state    = S_EXTEND_XMT;
            else if (int_128b_eot)
               int_next_state    = S_IDLE;
            else if (int_128b_dv)
               int_next_state    = S_IN_DATA_XMT;
            else
               int_next_state    = S_IDLE;


        S_IN_DATA_XMT:
            if (int_128b_eot && int_128b_dwen[NW-1] && (!latchd_tlp_hdr_4dw && !h2_h1_flag) | h3_flag)
               int_next_state    = S_EXTEND_XMT;
            else if (int_128b_eot)
               int_next_state    = S_IDLE;
            else
               int_next_state    = S_IN_DATA_XMT;
        S_EXTEND_XMT:
            int_next_state       = S_IDLE;

        default:
            int_next_state       = S_IDLE;
    endcase
end

assign  next_state = int_next_state;

///////////////////////////////////////////////////////////////////////////////////////



always @(*)
begin:  FORMATION_DATAMUX

    muxd_data = 0;
    muxd_dwen = 0;
    muxd_add_ecrc = 0;
    muxd_parerr = 0;
    muxd_hdr  =  0;
    muxd_soh  =  2'b00;
     case (current_state)

        S_IDLE: begin //1
           muxd_add_ecrc       = int_128b_add_ecrc;
           muxd_data           = int_128b_hdr[63:0];

 
                muxd_soh                  = {1'b0, int_128b_hv};
            muxd_dwen                    = 2'b11;
            muxd_parerr                  = int_128b_addr_parerr_qual;
       end  //1


        S_IN_HDR1_XMT: begin
            muxd_add_ecrc                = int_128b_add_ecrc;
            muxd_soh                     = 2'b00;
            if (tlp_hdr_4dw) begin
                muxd_data                = int_128b_hdr[127:64];
               muxd_parerr               = int_128b_addr_parerr_qual;
            end else begin
                muxd_data                = {int_128b_data[31:0], int_128b_hdr[95:64]};
               muxd_parerr               = int_128b_data_parerr | int_128b_addr_parerr_qual;
            end
            muxd_dwen                    =  {(tlp_hdr_4dw || tlp_payload_and_ecrc), 1'b1};
        end


        S_IN_DATA_XMT: begin
            muxd_add_ecrc                = int_128b_add_ecrc;
            muxd_parerr                  = int_128b_data_parerr;
            muxd_soh                     = 2'b00;
            if (latchd_tlp_hdr_4dw & !h3_flag || h2_h1_flag) begin
                muxd_dwen                = int_128b_dwen[1:0];
                muxd_data                = int_128b_data[63:0];
            end else begin
                muxd_dwen                = 2'b11;
                muxd_data                = {int_128b_data[31:0], clkd_data32};
            end
          end



        S_EXTEND_XMT: begin
            muxd_add_ecrc                = int_128b_add_ecrc;
            muxd_parerr                  = int_128b_data_parerr;
            muxd_soh                     = 2'b00;
              if (latchd_tlp_hdr_4dw& !h3_flag || h2_h1_flag) begin
                muxd_dwen                = int_128b_dwen[1:0];
                muxd_data                = int_128b_data[63:0];
            end else begin
                muxd_dwen                = 2'b01;
                muxd_data                = {int_128b_data[31:0], clkd_data32};
            end
        end
        default: begin
            muxd_add_ecrc                = int_128b_add_ecrc;
            muxd_dwen                    = 0;
            muxd_parerr                  = 0;
            muxd_data                    = int_128b_data[63:0];
            muxd_soh                     = 2'b00;
       end


    endcase

end

               
assign   muxd_hv    = ((int_128b_hv && (current_state  == S_IDLE       ))  
                 || (current_state == S_IN_HDR1_XMT)   
                           );  // for 32b and 64bit architecture, this is only SOT indication


assign   muxd_dv         = ((int_128b_hv || (current_state != S_IDLE)) && (NW < 4)) || int_128b_dv;

assign   muxd_eot        = int_128b_eot &&
                             (NW >= 4 ||
                              NW == 2 && (
                              current_state == S_IN_HDR1_XMT && (!tlp_payload_and_ecrc || !tlp_hdr_4dw && !int_128b_dwen[NW-1]) ||
                              current_state == S_IN_DATA_XMT &&  next_state  == S_IDLE ||
                              current_state == S_IN_H2_H1_XMT && !tlp_hdr_4dw && !tlp_payload_and_ecrc ||
                              current_state == S_IN_H3_XMT && (!tlp_payload_and_ecrc || !int_128b_dwen[NW-1])) ||
                              NW == 1 && next_state == S_IDLE) ||
                              NW == 2 & current_state == S_EXTEND_XMT;

assign   muxd_badeot     = (muxd_eot)? int_128b_badeot: 1'b0;


// latch the parerr to nullify the packet at the end
wire int_parerr_detected;
assign   int_parerr_detected     = out_formation_data_parerr | muxd_parerr;

// ------- Output Drives  ------------


assign   xadm_xtlh_soh           = muxd_soh; 
assign   out_formation_out_halt  = out_halt;
assign   xadm_xtlh_hv            = muxd_hv;
assign   xadm_xtlh_dv            = muxd_dv;
assign   xadm_xtlh_eot           = muxd_eot;
assign   xadm_xtlh_sot           = muxd_hv && (current_state == S_IDLE);
assign   xadm_xtlh_bad_eot       = (muxd_eot)? int_128b_badeot: 1'b0;
assign   xadm_xtlh_parerr        = int_parerr_detected;
assign   xadm_xtlh_dwen[NW-1:0]  = muxd_dwen;             // based on architecture, some of the MSB bits are not driven
assign   xadm_xtlh_add_ecrc      = muxd_add_ecrc;


 assign   xadm_xtlh_hdr = muxd_hdr; 
 
 assign   xadm_xtlh_data            = muxd_data;                         // based on architecture, some of the MSB bits are not driven







endmodule
