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
// ---    $DateTime: 2020/02/07 03:23:56 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_pipe_squelch.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Per Lane Squelching
// -----------------------------------------------------------------------------
// --- this module detects 2 out of 3 IDLs in an EI ordered set.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rmlh_pipe_squelch (
// ---- inputs ---------------
    core_clk,
    core_clk_ug,
    core_rst_n,
    cfg_elastic_buffer_mode,
    cfg_pipe_garbage_data_mode,
    rxvalid,
    rxdata,
    rxdatak,
    active_nb,
    disable_squelch_turnoff,
    current_data_rate,
    phy_type,
    smlh_ltssm_state,
    rxdatavalid,
    mac_phy_rate,
    sq_rxdatak,
    int_rpipe_rcvd_eidle_set,
    set_squelch,
    eios_eieos_det,
    squelch
);

parameter   NB      = `CX_NB;   // Number of symbols (bytes) per clock cycle
parameter   AW      = `CX_ANB_WD; // Width of the active number of bytes
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)

input            core_clk;
input            core_clk_ug;
input            core_rst_n;
input            cfg_elastic_buffer_mode;
input            cfg_pipe_garbage_data_mode;
input            rxvalid;
input [NB*8-1:0] rxdata;
input [NB-1:0]   rxdatak;
input [AW-1:0]   active_nb;
input            disable_squelch_turnoff;
input   [2:0]    current_data_rate;
input            phy_type;
input [5:0]      smlh_ltssm_state;
input            rxdatavalid;
input [2:0]      mac_phy_rate;
output reg [NB-1:0]  sq_rxdatak;
output           int_rpipe_rcvd_eidle_set;
output           set_squelch;
output           squelch;
output reg       eios_eieos_det;

wire       set_squelch_i;
wire       reset_squelch;
reg        squelch_reg;

wire [7:1] chk_com;
wire [7:2] chk_idl;

wire [3:0] comk;
wire       int_comk;
reg  [3:1] comkq;

wire [3:0] idlk;
reg  [3:2] idlkq ;
wire       int_rpipe_rcvd_eidle_set;
reg        r_rpipe_rcvd_eidle_set;
wire       s_rpipe_rcvd_eidle_set;
wire       g12_rxeios_detect;
reg        g12_rxeios_detect_d;
reg        latched_g12_rxeios_detect;
wire       int_g12_rxeios_detect;
wire       int_reset_squelch;
wire [7:0] current_rxdatak_i;

wire       rxvalid_i;
assign     rxvalid_i = cfg_elastic_buffer_mode ? rxvalid & rxdatavalid : rxvalid;

// Electrical Idle ordered set detection

// int_rpipe_rcvd_eidle_set is used in xmlh_ltssm to count EIDL o/s
//   so keep signal high if we continue to receive EIDL o/s
assign s_rpipe_rcvd_eidle_set =
                                   // in 1s mode do this
                                   active_nb[0] ?
                                       ( chk_com[1] & enuf(chk_idl[4:2]) ) : 1'b0
                                 |
                                   // in 2s mode do this
                                   active_nb[1] ?
                                       (  chk_com[1] & enuf(chk_idl[4:2])
                                        | chk_com[2] & enuf(chk_idl[5:3]) ) : 1'b0
                                 |
                                   // in 4s mode do this
                                   active_nb[2] ?
                                       (  chk_com[1] & enuf(chk_idl[4:2])
                                        | chk_com[2] & enuf(chk_idl[5:3])
                                        | chk_com[3] & enuf(chk_idl[6:4])
                                        | chk_com[4] & enuf(chk_idl[7:5]) ) : 1'b0;

always @(posedge core_clk or negedge core_rst_n) begin
  if (~core_rst_n)
    r_rpipe_rcvd_eidle_set <= #TP 1'b0;
  else
    r_rpipe_rcvd_eidle_set <= #TP s_rpipe_rcvd_eidle_set;
end

//to be sure int_rpipe_rcvd_eidle_set is only one cycle long for 1s.
//for SVA check
assign int_rpipe_rcvd_eidle_set =
                                 ( (active_nb[0] | active_nb[1]) ? s_rpipe_rcvd_eidle_set & ~r_rpipe_rcvd_eidle_set :
                                  s_rpipe_rcvd_eidle_set );

// the squelch signal is asserted as quickly as possible
assign squelch =  set_squelch_i
                | squelch_reg & ~reset_squelch;

assign set_squelch = g12_rxeios_detect; //set_squelch_i;

// stay squelched until comma or rxvalid goes away. rxstartblock for gen3 data rate
assign g12_rxeios_detect =   chk_com[1] & enuf(chk_idl[4:2])
                           | chk_com[2] & enuf(chk_idl[5:3])
                           | chk_com[3] & enuf(chk_idl[6:4])
                           | chk_com[4] & enuf(chk_idl[7:5]);

always @(posedge core_clk or negedge core_rst_n) begin : g12_rxeios_detect_d_PROC
    if ( ~core_rst_n )
        g12_rxeios_detect_d <= #TP 0;
    else
        g12_rxeios_detect_d <= #TP g12_rxeios_detect;
end // g12_rxeios_detect_d_PROC

assign set_squelch_i = ~squelch_reg & (
                      g12_rxeios_detect_d /*g12_rxeios_detect*/ ); // take next cycle. mask bytes for current cycle

assign reset_squelch = ~disable_squelch_turnoff & ( ~rxvalid | (
                                                             (~cfg_pipe_garbage_data_mode) ? (smlh_ltssm_state == `S_RCVRY_LOCK) :
                                                             int_reset_squelch )
                                                  );

assign int_comk = |comk;

always @(posedge core_clk or negedge core_rst_n) begin : latched_g12_rxeios_detect_PROC
    if (~core_rst_n)
        latched_g12_rxeios_detect <= #TP 1'h0;
    else if (g12_rxeios_detect)
        latched_g12_rxeios_detect <= #TP 1'h1;
    else if (!rxvalid || int_comk) //keep latched_g12_rxeios_detect until !rxvalid (rxvalid goes low after EIOS)
        latched_g12_rxeios_detect <= #TP 1'h0;
end

assign int_g12_rxeios_detect = g12_rxeios_detect | latched_g12_rxeios_detect;

assign int_reset_squelch = int_comk & !int_g12_rxeios_detect;

// When LTSSM entries/exits L1 state, core_clk is stopped before the squelch_reg isn't cleared.
// This FF uses ungarted core clock.
always @(posedge core_clk_ug or negedge core_rst_n) begin : squelch_reg_PROC
    if (~core_rst_n)
        squelch_reg <= #TP 1'h0;
    else if (set_squelch_i)
        squelch_reg <= #TP 1'h1;
    else if (reset_squelch)
        squelch_reg <= #TP 1'h0;
end // squelch_reg_PROC

// function to determine when enough IDL symbols are detected.
function automatic enuf;
input [2:0] chk;
begin
// Spec requires 2 of 3 valid IDL characters. RocketIO needs weaker checking
     enuf =  chk[0] & chk[1]
           | chk[1] & chk[2]
           | chk[0] & chk[2];
end
endfunction // enuf

// detect commas (COM) and save some past history
assign chk_com = {comk[3:0], comkq[3:1]};

always @(posedge core_clk or negedge core_rst_n)
    if (~core_rst_n)
        comkq <= #TP 3'h0;
    else if ( cfg_elastic_buffer_mode && ~rxdatavalid )
        comkq <= #TP (rxvalid) ? comkq : 3'h0;
    else if (active_nb[2])  // 4s
        comkq <= #TP comk[3:1];
    else if (active_nb[1])  // 2s
        comkq <= #TP {comk[1:0], comkq[3]};
    else
        comkq <= #TP {comk[0], comkq[3:2]};

assign comk = {
               2'h0,
               (active_nb[2]|active_nb[1]) & rxvalid_i & rxdatak[1] & (rxdata[15:8]  == `COMMA_8B),
               |active_nb                  & rxvalid_i & rxdatak[0] & (rxdata[7:0]   == `COMMA_8B)
               };

// detect idles (IDL) and save some past history

assign chk_idl = {idlk[3:0], idlkq[3:2]};

always @(posedge core_clk or negedge core_rst_n)
    if (~core_rst_n)
        idlkq <= #TP 2'h0;
    else if ( cfg_elastic_buffer_mode && ~rxdatavalid )
        idlkq <= #TP (rxvalid) ? idlkq : 2'h0;
    else if (active_nb[2])  // 4s
        idlkq <= #TP idlk[3:2];
    else if (active_nb[1])  // 2s
        idlkq <= #TP idlk[1:0];
    else
        idlkq <= #TP {idlk[0], idlkq[3]};

assign idlk = {
               2'h0,
               (active_nb[2]|active_nb[1]) & rxvalid_i & rxdatak[1] & (rxdata[15:8]  == `EIDLE_8B),
               |active_nb                  & rxvalid_i & rxdatak[0] & (rxdata[7:0]   == `EIDLE_8B)
               };

// chk_idl[7:2] = {idlk[3;0], idlkq[3:2]}, idlk[3:0] is for current cycle, idlkq[3:2] is for previous cycle,
// i.e. chk_idl[7:4] is for current cycle.
// current_rxdatak_i is rxdatak mask for current cycle. So only need consider idlk[3:0].
// If eios was detected on the previous cycle, rxvalid=0 on the current cycle, mask rxdatak = 0 regardless.
// for RIO_POPULATED, only need one IDL symbol, so take higher priority from byte 0, chk_idl[4] = idlk[0].
// for ~RIO_POPULATED, need two IDLs, so take higher priority from byte[1:0], chk_idl[5:4] = idlk[1:0].
assign current_rxdatak_i =                             // chk_idl[4] = 1 for chk_com[1] or chk_com[2]
                             ((chk_com[1] & (&chk_idl[4:3] | (chk_idl[4] & chk_idl[2]))) |
                              (chk_com[2] & (&chk_idl[4:3])))                              ? 8'b00000001 :
                             // chk_idl[5] = 1 for chk_com[2] or chk_com[3]
                             ((chk_com[2] & enuf(chk_idl[5:3])) |
                              (chk_com[3] & (&chk_idl[5:4])))                              ? 8'b00000011 :
                             // chk_idl[6] = 1 for chk_com[3] or chk_com[4]
                             ((chk_com[3] & enuf(chk_idl[6:4])) |
                              (chk_com[4] & (&chk_idl[6:5])))                              ? 8'b00000111 :
                             // chk_idl[7] = 1 for chk_com[4]
                             ( chk_com[4] & enuf(chk_idl[7:5]))                            ? 8'b00001111 : 8'b00000000 ;
                             // default is chk_com[5] = 1, so set to 0s for the next cycle

always @* begin : sq_rxdatak_PROC
    sq_rxdatak = 0;
    sq_rxdatak = g12_rxeios_detect ? (rxdatak & current_rxdatak_i[NB-1:0]) : rxdatak;
end // sq_rxdatak_PROC

always @(*) begin : eios_eieos_det_PROC
    eios_eieos_det = 0;
    eios_eieos_det = |{
        (|active_nb[2:1]) & rxdatak[1] & (rxdata[15:8]  == 8'h7C),
        |active_nb        & rxdatak[0] & (rxdata[7:0]   == 8'h7C)
                      };
end // eios_eieos_det_PROC




endmodule
