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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/xadm_arb.sv#8 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Arbitrates the different tlp transmit requests.
// There are four sources that arbitrate for transmission of a tlp to xtlh.
// These tlps are: client0, client1, completion I/F and internal generated message
// due to error, interrupt, etc.
// The arbitration results are determined on the credits available and priority.
// Priority of arbitration is : Internal MSG  is highest priority, cpl is
// the second, and round robin between client interfaces.
// ----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xadm_arb
    (
     // ------ Inputs ------
     core_rst_n,
     core_clk,
     cfg_tc_vc_map,
     cfg_tc_struc_vc_map,
     cfg_lpvc_wrr_weight,
     cfg_lpvc,
     cfg_lpvc_wrr_phase,
     pm_xtlh_block_tlp,
     cfg_client0_block_new_tlp,
     cfg_client1_block_new_tlp,
     cfg_client2_block_new_tlp,
     pm_block_all_tlp,
     //DE:Deadlock Fix
     lbc_deadlock_det,
     arb_reqs,
     clients_type,
     clients_tc,
     cdts_pass,
     next_cdts_pass,
     grant_ack,
     arb_enable, //Performance
     clear_active_grant,
     // ------ Outputs ------

     next_cpl_cdts_pass,
     next_msg_cdts_pass,
     next_client0_cdts_pass,
     next_client1_cdts_pass,
     arb_grant_valid,         // grant
     active_grant,
     qualified_arb_req     //Performance
     );

parameter   INST    = 0;                 // The uniquifying parameter for each port logic instance.
parameter   NCL     = `CX_NCLIENTS + 2;  // number of clients from application (plus 2 internal)
parameter   NVC     = `CX_NVC;           // number of vitrual channels
parameter   TP      = `TP;               // Clock to Q delay (simulator insurance)
parameter   WRR_ARB_WD           = `CX_XADM_ARB_WRR_WEIGHT_BIT_WIDTH;
parameter   NCLIENTS = `CX_NCLIENTS;
parameter   LFSR_MAX_WD = 7;


parameter   XADM_MSG_GRANT_VEC      = 1 << `XADM_MSG_GRANT;
parameter   XADM_CPL_GRANT_VEC      = 1 << `XADM_CPL_GRANT;
parameter   XADM_CLIENT0_GRANT_VEC  = 1 << `XADM_CLIENT0_GRANT;
parameter   XADM_CLIENT1_GRANT_VEC  = 1 << `XADM_CLIENT1_GRANT;

input                        core_rst_n;
input                        core_clk;

input [23:0]                 cfg_tc_vc_map;         // Index by TC, returns VC
input [23:0]                 cfg_tc_struc_vc_map;   // Index by TC, returns VC
input [(8*WRR_ARB_WD)-1:0]   cfg_lpvc_wrr_weight;
input [1:0]                  cfg_lpvc_wrr_phase;
input [2:0]                  cfg_lpvc;

input [NCL-1 :0]             arb_reqs;               // client requests
input [NCL*7-1:0]            clients_type;           // Fmt/Type of request P, NP, CPL
input [NCL*3-1:0]            clients_tc;             // TC of request
input [NVC*NCL-1:0]          cdts_pass;              // Pass indication from each of the VC checks
input [NVC*NCL-1:0]          next_cdts_pass;          // Next TLP Pass indication from each of the VC checks

input [NCL-1 :0]             grant_ack;              // acceptance of grant
input                        arb_enable;             // Performance
input                        pm_xtlh_block_tlp;      // block all client grants except for msg
input                        cfg_client0_block_new_tlp;    // power management module to block the scheduling of the next tlp for Client0
input                        cfg_client1_block_new_tlp;    // power management module to block the scheduling of the next tlp for Client1
input                        cfg_client2_block_new_tlp;    // power management module to block the scheduling of the next tlp for Client2
input                        pm_block_all_tlp;       // block all interface's requests
//DE:Deadlock Fix
input                        lbc_deadlock_det;       // deadlock detected in lbc module
input                        clear_active_grant;

// -- Outputs --

output                       arb_grant_valid;        // control to grant client
output [NCL-1:0]             active_grant;           // indicate which client is granted

output [NCL-1:0]             qualified_arb_req;      // Peformance 

output                         next_cpl_cdts_pass;
output                         next_msg_cdts_pass;
output                         next_client0_cdts_pass;
output                         next_client1_cdts_pass;
reg [NCL-1:0]                active_grant;
wire [NCL-1:0]                client_rr_grant;
reg [NCL-1:0]                client_priority_grant;

wire [NCL-1:0]               qualified_arb_req;
wire [NCLIENTS-1:0]          last_grant_is_client;
reg [NCLIENTS-1:0]           last_grant_is_client_d;


wire [1:0]                   num_qual_req;



wire [2:0]                   cpl_intrf_strct_vid;
wire [2:0]                   msg_intrf_strct_vid;
wire [2:0]                   client0_strct_vid;
wire [2:0]                   client1_strct_vid;
wire                         cpl_cdts_pass;
wire                         msg_cdts_pass;
wire                         client0_cdts_pass;
wire                         client1_cdts_pass;
wire [2:0]                   cpl_tc;
wire [2:0]                   msg_tc;
wire [2:0]                   client0_tc; // = clients_tc[ `XADM_CLIENT0_GRANT *3 + 2 : `XADM_CLIENT0_GRANT*3 ];
wire [2:0]                   client1_tc; // = clients_tc[ `XADM_CLIENT1_GRANT *3 + 2 : `XADM_CLIENT1_GRANT*3 ];






assign arb_grant_valid                          = |active_grant;

assign cpl_tc                                   = clients_tc[ `XADM_CPL_GRANT *3 + 2     : `XADM_CPL_GRANT *3];
assign msg_tc                                   = clients_tc[ `XADM_MSG_GRANT *3 + 2     : `XADM_MSG_GRANT *3];
assign client0_tc                               = clients_tc[ `XADM_CLIENT0_GRANT *3 + 2 : `XADM_CLIENT0_GRANT*3 ];
assign client1_tc                               = clients_tc[ `XADM_CLIENT1_GRANT *3 + 2 : `XADM_CLIENT1_GRANT*3 ];


// Get the structure VC ID for the TC
assign cpl_intrf_strct_vid                      = get_vcnum(cpl_tc,              cfg_tc_struc_vc_map);
assign msg_intrf_strct_vid                      = get_vcnum(msg_tc,              cfg_tc_struc_vc_map);
assign client0_strct_vid                        = get_vcnum(client0_tc,          cfg_tc_struc_vc_map);
assign client1_strct_vid                        = get_vcnum(client1_tc,          cfg_tc_struc_vc_map);


// For credit pass bus, we need to use structure ID
assign cpl_cdts_pass                            = get_cdts_pass(cdts_pass,cpl_intrf_strct_vid,`XADM_CPL_GRANT);
assign msg_cdts_pass                            = get_cdts_pass(cdts_pass,msg_intrf_strct_vid,`XADM_MSG_GRANT);
assign client0_cdts_pass                        = get_cdts_pass(cdts_pass,client0_strct_vid  ,`XADM_CLIENT0_GRANT);
assign client1_cdts_pass                        = get_cdts_pass(cdts_pass,client1_strct_vid  ,`XADM_CLIENT1_GRANT);


assign next_cpl_cdts_pass                            = get_cdts_pass(next_cdts_pass,cpl_intrf_strct_vid,`XADM_CPL_GRANT);
assign next_msg_cdts_pass                            = get_cdts_pass(next_cdts_pass,msg_intrf_strct_vid,`XADM_MSG_GRANT);
assign next_client0_cdts_pass                        = get_cdts_pass(next_cdts_pass,client0_strct_vid  ,`XADM_CLIENT0_GRANT);
assign next_client1_cdts_pass                        = get_cdts_pass(next_cdts_pass,client1_strct_vid  ,`XADM_CLIENT1_GRANT);



assign qualified_arb_req[`XADM_MSG_GRANT ]      = arb_reqs[`XADM_MSG_GRANT]     && arb_enable && msg_cdts_pass && !pm_block_all_tlp  
                                                                        ;
assign qualified_arb_req[`XADM_CPL_GRANT ]      = arb_reqs[`XADM_CPL_GRANT ]    && arb_enable && cpl_cdts_pass && (!pm_block_all_tlp || lbc_deadlock_det)
                                                                        ;



assign qualified_arb_req[`XADM_CLIENT0_GRANT ]  = arb_reqs[`XADM_CLIENT0_GRANT] && arb_enable && client0_cdts_pass && (!(pm_xtlh_block_tlp && cfg_client0_block_new_tlp)) && !pm_block_all_tlp;
assign qualified_arb_req[`XADM_CLIENT1_GRANT ]  = arb_reqs[`XADM_CLIENT1_GRANT] && arb_enable && client1_cdts_pass && (!(pm_xtlh_block_tlp && cfg_client1_block_new_tlp)) && !pm_block_all_tlp;







assign num_qual_req                             =
        {1'b0,qualified_arb_req[`XADM_CLIENT1_GRANT ]} + {1'b0,qualified_arb_req[`XADM_CLIENT0_GRANT ]};



// since only quailfied arb requests make it here,
// a grant that makes it into the queue will
// not block due to lack-of-credit, so any blocking
// will be temporary.

always @(/*AUTOSENSE*/qualified_arb_req)
begin: CLIENT_STRICT_PRIORITY_ARB
    if (qualified_arb_req[`XADM_MSG_GRANT ]           )   // priority select, msg highest
        client_priority_grant      = XADM_MSG_GRANT_VEC;
    else if (qualified_arb_req[`XADM_CPL_GRANT ]      )
        client_priority_grant      = XADM_CPL_GRANT_VEC;
    else
        client_priority_grant      = {NCL{1'b0}};
end


wire grant_ack_is_client;
assign grant_ack_is_client = grant_ack[3] | grant_ack[2];

assign last_grant_is_client[0] = (grant_ack_is_client)? grant_ack[2] : last_grant_is_client_d[0];
assign last_grant_is_client[1] = (grant_ack_is_client)? grant_ack[3] : last_grant_is_client_d[1];



always @(posedge core_clk or negedge core_rst_n)
begin:  TRACK_GRANT_PROCESS
    if (!core_rst_n)
    begin
        last_grant_is_client_d    <= # TP 1;
    end
    else
    begin
    if (grant_ack_is_client & !clear_active_grant) begin
            last_grant_is_client_d <= #TP last_grant_is_client;
    end
    end
end



//////////////////////////////////////////////////////////
// Round robin results from client's request
//////////////////////////////////////////////////////////
assign client_rr_grant = round_robin_arb({ qualified_arb_req[`XADM_CLIENT1_GRANT ],
                                           qualified_arb_req[`XADM_CLIENT0_GRANT ] }, num_qual_req[1], last_grant_is_client);

//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////


always @(client_priority_grant or client_rr_grant)
    begin
        if (client_priority_grant > 0)
            active_grant = client_priority_grant;
        else
            active_grant = client_rr_grant;
    end
//////////////////////////////////////////////////////////

function automatic  [NCL-1:0] round_robin_arb;
    input [NCLIENTS-1:0]   req;
    input                  tied;
    input [NCLIENTS-1:0]   last_grant_is_client;
    begin
        if ((req[0] ) &
            (!tied | (!last_grant_is_client[0])))
            round_robin_arb =  XADM_CLIENT0_GRANT_VEC;
        else if (req[1] )
            round_robin_arb =  XADM_CLIENT1_GRANT_VEC;
        else
            round_robin_arb =  {NCL{1'b0}};
    end
endfunction

function automatic [2:0]  get_vcnum;
    input [2:0]   tc;
    input [23:0]  tc_vc_map;
begin
    get_vcnum = 3'b0;

    case  (tc)
        3'b000:   get_vcnum  = tc_vc_map[ 2: 0];
        3'b001:   get_vcnum  = tc_vc_map[ 5: 3];
        3'b010:   get_vcnum  = tc_vc_map[ 8: 6];
        3'b011:   get_vcnum  = tc_vc_map[11: 9];
        3'b100:   get_vcnum  = tc_vc_map[14:12];
        3'b101:   get_vcnum  = tc_vc_map[17:15];
        3'b110:   get_vcnum  = tc_vc_map[20:18];
        3'b111:   get_vcnum  = tc_vc_map[23:21];
    endcase
end
endfunction


function automatic get_cdts_pass;
    input [NVC*NCL-1:0] cdts_pass_local;
    input [2:0] strct_vid;
    input [2:0] client_ndx;
    reg [63:0] cdts_pass_local_padded;
    begin
        get_cdts_pass           = 0;
        cdts_pass_local_padded = {{(64-NVC*NCL){1'b0}},cdts_pass_local};

        case (strct_vid)
            3'b000:  get_cdts_pass   = cdts_pass_local_padded[client_ndx + (0*NCL)];
            3'b001:  get_cdts_pass   = cdts_pass_local_padded[client_ndx + (  NCL)];
            3'b010:  get_cdts_pass   = cdts_pass_local_padded[client_ndx + (2*NCL)];
            3'b011:  get_cdts_pass   = cdts_pass_local_padded[client_ndx + (3*NCL)];
            3'b100:  get_cdts_pass   = cdts_pass_local_padded[client_ndx + (4*NCL)];
            3'b101:  get_cdts_pass   = cdts_pass_local_padded[client_ndx + (5*NCL)];
            3'b110:  get_cdts_pass   = cdts_pass_local_padded[client_ndx + (6*NCL)];
            3'b111:  get_cdts_pass   = cdts_pass_local_padded[client_ndx + (7*NCL)];
        endcase // case(strct_vid)
    end
endfunction





endmodule
