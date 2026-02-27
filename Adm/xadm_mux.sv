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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/xadm_mux.sv#7 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Multiplexes the incoming client interfaces.
// This block receives control from the arbitration block, and act to control client
// interface back pressure as needed.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xadm_mux
   (
    // ------ Inputs ------
    core_rst_n,
    core_clk,
    pm_block_all_tlp,
    out_halt,

    arb_grant_valid,
    active_grant,
    qualified_arb_req,  //Performance
    arb_reqs,           //Performance

    cpl_hv,
    cpl_dv,
    cpl_data,
    cpl_eot,
    cpl_hdr,
    cpl_badeot,

    msg_hv,
    msg_dv,
    msg_data,
    msg_eot,
    msg_hdr,
    msg_badeot,
    client0_hv,
    client0_hdr,
    client0_dv,
    client0_data,
    client0_eot,
    client0_eot_pre,
    client0_badeot,



    client1_hv,
    client1_hdr,
    client1_dv,
    client1_data,
    client1_eot,
    client1_eot_pre,
    client1_badeot,




     next_cpl_cdts_pass,
     next_msg_cdts_pass,
     next_client0_cdts_pass,
     next_client1_cdts_pass,
     next_credit_enough_all,
     next_2credit_enough_all,
     device_type,
     
// ------ Outputs ------
    grant_ack,
    active_grant_for_fc,
    arb_enable, //Performance
    client0_halt,
    client1_halt,
    msg_halt,
    cpl_halt,

    out_hv,
    out_hdr,
    out_hdr_rsvd,
    out_hdr_ats,
    out_hdr_nw,
    out_hdr_th,
    out_hdr_ph,
    out_hdr_st,
    
  
    out_dv,
    out_data,
    out_eot,
    out_bad_eot,
    clear_active_grant,
    arb_in_idle
);

parameter   INST              = 0;                                  // The uniquifying parameter for each port logic instance.
parameter   NW                = `CX_NW;                             // Number of 32-bit dwords handled by the datapath each clock.
parameter   DATA_PROT_WD      = `TRGT_DATA_PROT_WD;
parameter   DW                = (32*NW) + DATA_PROT_WD;             // Width of datapath in bits. Plus parity for the special function
parameter   HDR_PROT_WD       = `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD;  // XADM Common Header ecc/parity protection width

parameter   PAR_CALC_WIDTH    = `DATA_BUS_PAR_CALC_WIDTH;
parameter   TP                = `TP;      // Clock to Q delay (simulator insurance)
parameter   NCL               = `CX_NCLIENTS;
parameter   MAX_NCL           = 3;
parameter   ST_HDR            = `ST_HDR;

parameter   FIFOWIDTH         = NCL+2;
parameter   FIFOPTRWIDTH      = 2;
parameter   FIFOSIZE          = 4;

parameter   XADM_MSG_GRANT_VEC      = 5'h1 << `XADM_MSG_GRANT;
parameter   XADM_CPL_GRANT_VEC      = 5'h1 << `XADM_CPL_GRANT;
parameter   XADM_CLIENT0_GRANT_VEC  = 5'h1 << `XADM_CLIENT0_GRANT;
parameter   XADM_CLIENT1_GRANT_VEC  = 5'h1 << `XADM_CLIENT1_GRANT;



parameter   LBC_INT_WD           = `CX_LBC_INT_WD;    // LBC - XADM data bus width can be 32, 64 or 128


localparam LOOKUPID_WD = `CX_REMOTE_LOOKUPID_WD;

input                   core_rst_n;
input                   core_clk;


input                   pm_block_all_tlp;    // PM block all TLPs
input                   out_halt;            // applies back-presure from the formation block

input                   arb_grant_valid;     // strobe for active_grant
input   [NCL+2-1:0]     active_grant;        // show which client is granted, only when arb_grant_valid=1

//performance 8-23-2011
input   [NCL+2-1:0]     qualified_arb_req;
input   [NCL+2-1:0]     arb_reqs;


// from radm
input                   cpl_hv;              // cpl client header valid
input                   cpl_dv;              // cpl client data valid
input                   cpl_eot;             // cpl client end of tlp
input                   cpl_badeot;          // cpl client bad eot
input  [DW-1:0]         cpl_data;            // cpl client payload data
input  [ST_HDR-1 :0]    cpl_hdr;             // cpl client XADM commmon hdr

// from MSG GEN
input                   msg_hv;              // msg client header valid
input                   msg_dv;              // msg client data valid
input                   msg_eot;             // msg client end of tlp
input                   msg_badeot;          // msg client bad eot
input   [DW-1 :0 ]      msg_data;            // msg client payload data
input   [ST_HDR-1 :0]   msg_hdr;             // msg client XADM commmon hdr

// from applications
input                   client0_hv;          // client0 header valid
input                   client0_dv;          // client0 data valid
input                   client0_eot;         // client0 end of tlp
input                   client0_eot_pre;         // client0 end of tlp
input                   client0_badeot;      // client0 bad eot
input   [DW-1 :0 ]      client0_data;        // client0 payload data
input   [ST_HDR-1 :0 ]  client0_hdr;         // client0 XADM commmon hdr




input                   client1_hv;          // client1 header valid
input                   client1_dv;          // client1 data valid
input                   client1_eot;         // client1 end of tlp
input                   client1_eot_pre;         // client0 end of tlp
input                   client1_badeot;      // client1 bad eot
input   [DW-1 :0 ]      client1_data;        // client1 payload data
input   [ST_HDR-1:0 ]   client1_hdr;         // client1 XADM commmon hdr



input                         next_credit_enough_all;
input                         next_2credit_enough_all;
input [3:0]                   device_type;
input                         next_cpl_cdts_pass;
input                         next_msg_cdts_pass;
input                         next_client0_cdts_pass;
input                         next_client1_cdts_pass;

output                  client1_halt;        // back-pressure control for client1
output                  client0_halt;        // back-pressure control for client0

output                  msg_halt;            // back-pressure control for mgs client
output                  cpl_halt;            // back-pressure control for cpl client

output                  arb_enable;          // Performance - Arbitration enable repalcing the fifofull

output                  out_hv;              // Multiplexed Header valid
output  [ST_HDR-1:0]    out_hdr;             // Multiplexed Header bus
output  [14:0]          out_hdr_rsvd;        // Multiplexed header reserved fields
output  [1:0]           out_hdr_ats;
output                  out_hdr_nw;
output                  out_hdr_th;
output  [1:0]           out_hdr_ph;
output  [7:0]           out_hdr_st;
output                  out_dv;              // Multiplexed data valid
output  [DW-1:0]        out_data;            // Multiplexed data bus
output                  out_eot;             // Multiplexed end of transaction
output                  out_bad_eot;         // Multiplexed end of transaction

output  [NCL+2-1 :0]    grant_ack;           // One-hot Grant Acknowledge.





output   [NCL+2-1:0]    active_grant_for_fc;    // Active grant for fc is based on new ARB scheme
output                  clear_active_grant;     // inform xadm_arb about invalidated grants
output                  arb_in_idle; // arbiter is idle
wire arb_in_idle;
wire [NCL+2-1 :0]       grant_ack;

reg [DW-1:0]            out_data;

wire[ST_HDR-1:0]        out_hdr;
reg [14:0]              out_hdr_rsvd;
reg [1:0]               out_hdr_ats;
reg                     out_hdr_nw;
reg [1:0]               out_hdr_ph;
reg [7:0]               out_hdr_st;
reg                     out_hdr_th;


reg [MAX_NCL+2-1 :0]    active_client;
reg [MAX_NCL+2-1 :0]    active_client_d;
wire                    grantfifoempty;

reg     [ST_HDR-1:0]    int_out_hdr;

wire   [NCL+2-1:0]    active_grant_for_fc;


wire          clear_fifofull_flag = |(
                                     grant_ack);


wire  out_hv;
wire  out_dv;
wire  out_eot;
wire  out_bad_eot;

reg out_dv_int;
reg out_hv_int;
reg out_eot_int;
reg out_bad_eot_int;

assign out_hv =  !out_bad_eot_int & out_hv_int;
assign out_dv =  !out_bad_eot_int & out_hv_int & out_dv_int  | !out_hv_int & out_dv_int;
assign out_eot = !out_bad_eot_int & out_hv_int & out_eot_int | !out_hv_int & out_eot_int;
assign out_bad_eot = out_bad_eot_int & !out_hv_int;


// Performance enhancement 
// Arbitration State Machine and logic

parameter ARB_IDLE = 3'b000;
parameter ARB_GRNT = 3'b001;
parameter ARB_PARK = 3'b010;
parameter ARB_DLY1 = 3'b011;
reg [2:0] arb_state;
wire or_eot;
wire or_eot_int;
wire or_hv;
reg next_credit_enough_all_d;
reg next_2credit_enough_all_d;


assign        or_eot = |{
                             (client1_badeot | client1_eot) & (active_client_d[`XADM_CLIENT1_GRANT] ), 
                             (client0_badeot | client0_eot) & (active_client_d[`XADM_CLIENT0_GRANT] ),
                             (msg_badeot     | msg_eot) & active_client_d[`XADM_MSG_GRANT],
                             (cpl_badeot     | cpl_eot) & active_client_d[`XADM_CPL_GRANT] };

assign        or_eot_int = |{
                             (client1_badeot | client1_eot) & (active_client[`XADM_CLIENT1_GRANT] ), 
                             (client0_badeot | client0_eot) & (active_client[`XADM_CLIENT0_GRANT] ),
                             (msg_badeot     | msg_eot) & active_client[`XADM_MSG_GRANT],
                             (cpl_badeot     | cpl_eot) & active_client[`XADM_CPL_GRANT] };


assign        or_hv= |{
                             client1_hv & active_client_d[`XADM_CLIENT1_GRANT], 
                             client0_hv & active_client_d[`XADM_CLIENT0_GRANT],
                             msg_hv & active_client_d[`XADM_MSG_GRANT],
                             cpl_hv & active_client_d[`XADM_CPL_GRANT] };




wire arb_in_grant;
wire arb_in_park;
wire arb_in_delay1;

wire arb_enable;
wire clear_active_grant;

// indication that some client is granted and and there is TLP starting (hv is asserted)

assign clear_active_grant = 1'b0;

assign arb_in_idle  = (arb_state == ARB_IDLE);
assign arb_in_grant = (arb_state == ARB_GRNT);
assign arb_in_park  = (arb_state == ARB_PARK);
assign arb_in_delay1= (arb_state == ARB_DLY1);

// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: This logic seems good and was verified for several times. The recoding is not required
   always @(posedge core_clk or negedge core_rst_n)
     if (!core_rst_n) begin
      arb_state      <= #TP ARB_IDLE;
     end else
       begin
       if (!out_halt) begin
          case(arb_state)
         ARB_DLY1:
                 if (pm_block_all_tlp) begin
                   arb_state <= #TP ARB_IDLE;
                 end else begin
                   if (or_eot_int)
                    arb_state <= #TP ARB_PARK;
                   else  
                    arb_state <= #TP ARB_GRNT;
                 end
       ARB_GRNT:  
               if (or_eot)
                  if (next_credit_enough_all_d && !pm_block_all_tlp)
                     arb_state     <= #TP ARB_PARK ;
                   else //no credits available
                   arb_state     <= #TP ARB_IDLE;
                 //end
               else                
                 arb_state <= #TP ARB_GRNT;
      ARB_PARK: 
               if (or_hv) 
                begin
                  if (or_eot) begin //single TLP
                    if (next_2credit_enough_all_d && !pm_block_all_tlp) begin
                      if ( (active_client[`XADM_MSG_GRANT] && active_client_d[`XADM_MSG_GRANT]) ||  ( active_client[`XADM_CPL_GRANT] && active_client_d[`XADM_CPL_GRANT]) ) 
                        arb_state   <= #TP ARB_IDLE;
                      else
                        arb_state   <= #TP ARB_PARK;
                    end else begin//No credits 
                      arb_state   <= #TP ARB_IDLE;
                    end
                  end else begin//no eot
                   arb_state    <= #TP ARB_GRNT;     
                  end
                end else begin //no_hv
                 arb_state    <= #TP ARB_IDLE;
                end
              // map ARB_IDLE to default state to facilitate code coverage
        default:  if (|active_grant)
                  arb_state      <= #TP ARB_DLY1;
                  else
                  arb_state      <= #TP ARB_IDLE; 
         endcase
       end
   end
// spyglass enable_block STARC05-2.11.3.1

          
  // Latch the arbiter result
always @(posedge core_clk or negedge core_rst_n)
       if (!core_rst_n) begin
           active_client               <= #TP 0;
       end else if ( ( (out_halt && active_client==0) || !out_halt) && arb_enable ) begin
         if (arb_in_grant && !next_credit_enough_all_d & or_eot)
          active_client               <= #TP 0;
         else if (arb_in_park && (!or_hv || !next_2credit_enough_all_d & or_eot))
          active_client               <= #TP 0;
         else if (active_grant==0 && (arb_in_grant || arb_in_park || arb_in_delay1))
          active_client               <= #TP active_client;
         else
           active_client               <= #TP {{(MAX_NCL-NCL){1'b0}}, active_grant}; 
       end

always @(posedge core_clk or negedge core_rst_n)
       if (!core_rst_n) begin
           active_client_d               <= #TP 0;
       end else begin
           if (out_halt || active_client==0 && ( (arb_in_grant && or_eot && next_credit_enough_all_d) || (arb_in_park  && or_hv && next_2credit_enough_all_d & or_eot)))
              active_client_d               <= #TP active_client_d;
             else
              active_client_d               <= #TP active_client;
       end


always @(posedge core_clk or negedge core_rst_n)
       if (!core_rst_n) begin
           next_credit_enough_all_d    <= #TP 0;
           next_2credit_enough_all_d   <= #TP 0;
       end else begin
           next_credit_enough_all_d    <= #TP next_credit_enough_all;
           next_2credit_enough_all_d   <= #TP next_2credit_enough_all;
       end


   assign msg_halt     =  (out_halt && active_client_d[`XADM_MSG_GRANT    ]) || arb_in_idle || arb_in_delay1 || !active_client_d[`XADM_MSG_GRANT];

   assign client0_halt =   out_halt || (
                                          (  arb_in_idle
                                          || arb_in_delay1 && pm_block_all_tlp
                                          || arb_in_grant && or_eot && (!next_credit_enough_all_d || pm_block_all_tlp)
                                          || arb_in_park  && (!or_hv || (!next_2credit_enough_all_d || pm_block_all_tlp) & or_eot)
                                          ) && (active_client[`XADM_CLIENT0_GRANT] ||  (active_client==0 &&  active_client_d[`XADM_CLIENT0_GRANT]))
                                        ||    !(active_client[`XADM_CLIENT0_GRANT] ||  (active_client==0 &&  active_client_d[`XADM_CLIENT0_GRANT])) 
                                       );

  assign client1_halt =    out_halt || (
                                          (  arb_in_idle
                                          || arb_in_delay1 && pm_block_all_tlp
                                          || arb_in_grant && or_eot && (!next_credit_enough_all_d || pm_block_all_tlp)
                                          || arb_in_park  && (!or_hv || (!next_2credit_enough_all_d || pm_block_all_tlp) & or_eot)
                                          ) && (active_client[`XADM_CLIENT1_GRANT] ||  (active_client==0 &&  active_client_d[`XADM_CLIENT1_GRANT]))
                                        ||    !(active_client[`XADM_CLIENT1_GRANT] ||  (active_client==0 &&  active_client_d[`XADM_CLIENT1_GRANT])) 
                                       );

   assign cpl_halt     =  (out_halt && active_client_d[`XADM_CPL_GRANT    ]) || arb_in_idle || arb_in_delay1 || !active_client_d[`XADM_CPL_GRANT];





assign active_grant_for_fc[`XADM_MSG_GRANT]     = active_client_d[`XADM_MSG_GRANT]     & !out_halt & out_hv & !out_bad_eot; 
assign active_grant_for_fc[`XADM_CPL_GRANT]     = active_client_d[`XADM_CPL_GRANT]     & !out_halt & out_hv & !out_bad_eot;
assign active_grant_for_fc[`XADM_CLIENT0_GRANT] = active_client_d[`XADM_CLIENT0_GRANT] & !out_halt & out_hv & !out_bad_eot;
assign active_grant_for_fc[`XADM_CLIENT1_GRANT] = active_client_d[`XADM_CLIENT1_GRANT] & !out_halt & out_hv & !out_bad_eot;


assign grantfifoempty     =  arb_in_idle | arb_in_delay1 | out_halt ;
assign arb_enable         =  !out_halt && (                    arb_in_idle 
                                                         ||  (client0_eot_pre && active_client[`XADM_CLIENT0_GRANT])
 ||  (client1_eot_pre && active_client[`XADM_CLIENT1_GRANT])

                                                         ||  (arb_in_grant || arb_in_park) && or_eot && (active_client_d[`XADM_CPL_GRANT] ||  active_client_d[`XADM_MSG_GRANT    ])                                                       
                                         );
                         



always @( /*AUTOSENSE*/active_client_d or client0_badeot or client0_data
     or client0_dv or client0_eot or client0_hdr or client0_hv
     or client1_badeot or client1_data or client1_dv
     or client1_eot or client1_hdr or client1_hv

     or cpl_badeot or cpl_data or cpl_dv or cpl_eot or cpl_hdr or cpl_hv
     or grantfifoempty or msg_badeot or msg_data or msg_dv
     or msg_eot or msg_hdr or msg_hv
     )
begin

  out_hv_int          = 0;
  int_out_hdr         =0;
  out_hdr_rsvd        = 15'b0;
  out_hdr_ats         = 2'b0;
  out_hdr_nw          = 1'b0;
  out_hdr_th          = 1'b0;
  out_hdr_ph          = 2'b00;
  out_hdr_st          = 8'h00;
  out_dv_int          = 0;
   out_data[DW-1:0]    = 0;
  out_eot_int             = 0;
  out_bad_eot_int         = 0;

        if (!grantfifoempty )
          case (active_client_d)
            XADM_MSG_GRANT_VEC:
                begin
                    out_hv_int          = msg_hv;
                    int_out_hdr         = msg_hdr;
                    out_hdr_rsvd        = 15'b0;
                    out_hdr_ats         = 2'b0;
                    out_hdr_nw          = 1'b0;
                    out_hdr_th          = 1'b0;
                    out_hdr_ph          = 2'b00;
                    out_hdr_st          = 8'h00;
                    out_dv_int          = msg_dv;
                    out_data            = msg_data;

                    out_eot_int             = msg_eot;
                    out_bad_eot_int         = msg_badeot;
                end
            XADM_CPL_GRANT_VEC:
                begin
                    out_hv_int          = cpl_hv;
                    int_out_hdr         = cpl_hdr;
                    out_hdr_rsvd        = 15'b0;
                    out_hdr_ats         = 2'b0;
                    out_hdr_nw          = 1'b0;
                    out_hdr_th          = 1'b0;
                    out_hdr_ph          = 2'b0;
                    out_hdr_st          = 8'h00;
                    out_dv_int          = cpl_dv;
                    out_data            = cpl_data;
                    out_eot_int             = cpl_eot;
                    out_bad_eot_int         = cpl_badeot;
                end
            XADM_CLIENT0_GRANT_VEC  :
                begin
                    out_hv_int              = client0_hv;
                    int_out_hdr         = client0_hdr;
                    out_hdr_rsvd        = 15'b0;
                    out_hdr_ats         = 2'b0;
                    out_hdr_nw          = 1'b0;
                    out_hdr_th          = 1'b0;
                    out_hdr_ph          = 2'b0;
                    out_hdr_st          = 8'h00;
                    out_dv_int          = client0_dv;
                    out_data            = client0_data;
                    out_eot_int             = client0_eot;
                    out_bad_eot_int         = client0_badeot;
   //   `endif
                end

            XADM_CLIENT1_GRANT_VEC  :
                begin
                    out_hv_int              = client1_hv;
                    int_out_hdr         = client1_hdr;
                    out_hdr_rsvd        = 15'b0;
                    out_hdr_ats         = 2'b0;
                    out_hdr_nw          = 1'b0;
                    out_hdr_th          = 1'b0;
                    out_hdr_ph          = 2'b0;
                    out_hdr_st          = 8'h00;
                    out_dv_int          = client1_dv;
                    out_data            = client1_data;
                    out_eot_int             = client1_eot;
                    out_bad_eot_int         = client1_badeot;
                end

    
            default :
                begin
                    out_hv_int          = 0;
                    int_out_hdr         = 0;   
                    out_hdr_rsvd        = 15'b0;
                    out_hdr_ats         = 2'b0;
                    out_hdr_nw          = 1'b0;
                    out_hdr_th          = 1'b0;
                    out_hdr_ph          = 2'b00;
                    out_dv_int              = 0;
                    out_data[DW-1:0] = 0; 
                    out_eot_int             = 0;
                    out_bad_eot_int         = 0;
                end
           endcase // case(active_client_d)
end // always @ (...

assign out_hdr = int_out_hdr;




assign  grant_ack[`XADM_MSG_GRANT     ] =  msg_eot     && ! msg_halt;
assign  grant_ack[`XADM_CPL_GRANT     ] =  cpl_eot     && ! cpl_halt;
assign  grant_ack[`XADM_CLIENT0_GRANT ] = !out_halt && active_client[`XADM_CLIENT0_GRANT] && (
                                                                                       arb_in_delay1
                                                                                  || ( arb_in_grant  &&           or_eot && next_credit_enough_all_d && !pm_block_all_tlp)
                                                                                  || ( arb_in_park   &&  or_hv && or_eot && next_2credit_enough_all_d && !pm_block_all_tlp)
                                                                                     );
assign  grant_ack[`XADM_CLIENT1_GRANT] = !out_halt && active_client[`XADM_CLIENT1_GRANT] && (
                                                                                       arb_in_delay1
                                                                                  || ( arb_in_grant  &&           or_eot && next_credit_enough_all_d && !pm_block_all_tlp)
                                                                                  || ( arb_in_park   &&  or_hv && or_eot && next_2credit_enough_all_d && !pm_block_all_tlp)
                                                                                     );


`ifndef SYNTHESIS
`endif

endmodule
