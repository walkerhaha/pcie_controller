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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_pipe.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer PIPE interface.
// -----------------------------------------------------------------------------

// LMD: 2 clocks in the module
// LJ: core_clk and core_clk_ug have to be introduced into the module
// leda W389 off
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rmlh_pipe(
// ---- inputs ---------------
    core_rst_n,
    core_clk,
    core_clk_ug,
    cfg_elastic_buffer_mode,
    cfg_pipe_garbage_data_mode,

    phy_type,
    smlh_ltssm_state,
    phy_mac_rxdata,
    phy_mac_rxdatak,
    phy_mac_rxvalid,
    phy_mac_rxdatavalid,
    phy_mac_rxstatus,
    phy_mac_rxelecidle,
    phy_mac_phystatus,
    smlh_lanes_active,
    smlh_no_turnoff_lanes,
    smlh_link_up,
    ltssm_clear,
    ltssm_powerdown, // used for phy_mac_powerdown comparison
    mac_phy_rate,
    active_nb,
    pm_current_data_rate,

// ---- outputs ---------------
    current_powerdown,           // 0/1/2/3 = p0/p0s/p1/p2
    current_data_rate,           // 0/1/2 = running at gen1/2/3 speeds, goto PM block for shadowing the signal
    current_data_rate_others,    // pipeline to pm_current_data_rate
    current_data_rate_xmlh_xmt,  // pipeline to pm_current_data_rate
    current_data_rate_xmlh_scr,  // pipeline to pm_current_data_rate
    current_data_rate_rmlh_dsk,  // pipeline to pm_current_data_rate
    current_data_rate_rmlh_scr,  // pipeline to pm_current_data_rate
    current_data_rate_rmlh_pkf,  // pipeline to pm_current_data_rate
    current_data_rate_smlh_sqf,  // pipeline to pm_current_data_rate
    current_data_rate_smlh_lnk,  // pipeline to pm_current_data_rate
    current_data_rate_smlh_eq,   // pipeline to pm_current_data_rate
    current_data_rate_ltssm,     // pipeline to pm_current_data_rate

    rpipe_rxdata,
    rpipe_rxdatak, // gen3: repurposed to rxsyncheader
    rpipe_rxdata_dv, // gen3: incorporates rxdatavalid
    rpipe_rxaligned,
    rpipe_all_sym_locked,
    rpipe_rxskipadded,   // unused
    rpipe_rxskipremoved, // unused
    rpipe_rxcodeerror,   // OR-ed at top level into rxerror
    rpipe_rxdisperror,   // OR-ed at top level into rxerror
    rpipe_rxunderflow,   // unused, routed to deskew block
    rpipe_rxoverflow,    // unused, routed to deskew block
    rpipe_rxelecidle,    // used by eidle_infer & ltssm
    rpipe_rcvd_eidle_set,// latched by ltssm and exported to pm_ctrl
    rpipe_eios_eieos_det, // eieos or eios detected
    act_rpipe_rcvd_eidle_set // used by ltssm
    ,
    rpipe_rxdetected,    // used by ltssm
    rpipe_rxdetect_done, // used by ltssm
    rpipe_all_phystatus_asserted,// used by ltssm
    rpipe_all_phystatus_deasserted// used by ltssm
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance.
parameter   REGOUT  = `CX_RMLH_PIPE_REGOUT;
parameter   NL      = `CX_NL;   // Max number of lanes supported
parameter   NB      = `CX_NB;   // Number of symbols (bytes) per clock cycle
parameter   NBK     = `CX_NBK;  // Number of symbols (bytes) per clock cycle for datak
parameter   AW      = `CX_ANB_WD; // Width of the active number of bytes
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)
localparam  SYNC_DEPTH  = 2;

input                   core_rst_n;
input                   core_clk;
input                   core_clk_ug;                    // An ungated version of core_clk used to track phystatus during powerdown states
input                   cfg_elastic_buffer_mode;        // 0 - nominnal half full mode, 1 - nominal empty mode
input                   cfg_pipe_garbage_data_mode;     // 0 - until rxvalid=0 , 1 - until rxvalid=0 or rxstart=1 or COM symbol detection

input                   phy_type;                       // Mac type
input   [5:0]           smlh_ltssm_state;

input   [(NL*NB*8)-1:0] phy_mac_rxdata;
input   [(NL*NB)-1:0]   phy_mac_rxdatak;
input   [NL-1:0]        phy_mac_rxvalid;
input   [NL-1:0]        phy_mac_rxdatavalid;
input   [(NL*3) -1:0]   phy_mac_rxstatus;
input   [NL-1:0]        phy_mac_rxelecidle;
input   [NL-1:0]        phy_mac_phystatus;
input   [NL-1:0]        smlh_lanes_active;
input   [NL-1:0]        smlh_no_turnoff_lanes;
input                   smlh_link_up;
input                   ltssm_clear;
input   [1:0]           ltssm_powerdown;        // From LTSSM indicating power down state (P0/P0s/P1).
input   [2:0]           mac_phy_rate;           // From LTSSM indicating data rate change
input   [AW-1:0]           active_nb;
input   [2:0]           pm_current_data_rate;   // Current_data_rate shadowed in pm_ctrl

output  [1:0]           current_powerdown;            // 0/1/2/3 = p0/p0s/p1/p2
output  [2:0]           current_data_rate;            // 0/1/2 = running at gen1/2/3 speeds
output  [2:0]           current_data_rate_others;     // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_xmlh_xmt;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_xmlh_scr;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_rmlh_dsk;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_rmlh_scr;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_rmlh_pkf;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_smlh_sqf;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_smlh_lnk;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_smlh_eq;    // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_ltssm;      // pipeline to pm_current_data_rate

output  [(NL*NB*8)-1:0] rpipe_rxdata;
output  [(NL*NBK)-1:0]  rpipe_rxdatak;          //it is rxsyncheader if gen3 data rate
output  [NL-1:0]        rpipe_rxdata_dv;
output  [NL-1:0]        rpipe_rxaligned;        // squelched phy_mac_rxvalid 
output                  rpipe_all_sym_locked;
output  [NL-1:0]        rpipe_rxskipadded;
output  [NL-1:0]        rpipe_rxskipremoved;
output  [NL-1:0]        rpipe_rxcodeerror;
output  [NL-1:0]        rpipe_rxdisperror;
output  [NL-1:0]        rpipe_rxunderflow;
output  [NL-1:0]        rpipe_rxoverflow;
output  [NL-1:0]        rpipe_rxelecidle;
output                  rpipe_rcvd_eidle_set;
output  [NL-1:0]        act_rpipe_rcvd_eidle_set;
output                  rpipe_eios_eieos_det;
output  [NL-1:0]        rpipe_rxdetected;
output                  rpipe_rxdetect_done;
output                  rpipe_all_phystatus_asserted;
output                  rpipe_all_phystatus_deasserted;

// When entering electrical idle, ignore data
wire    [NL-1:0]        lanes_on;
wire    [NL-1:0]        eios_eieos_det_i;
wire                    rpipe_eios_eieos_det;
wire    [NL-1:0]        squelch;
wire    [NL-1:0]        squelch_i;
wire    [NL-1:0]        set_squelch;
wire    [NL-1:0]        set_squelch_i;
wire    [NL-1:0]        squelch_act;
wire    [NL-1:0]        sq_rxvalid;
wire    [NL-1:0]        sq_rxdata_dv;
wire    [NL*NBK-1:0]    sq_rxdatak;
wire    [NL*NB-1:0]     int_rxdatak;
reg  [2:0]              current_data_rate;            //used in PM to shadow (hold) the value when main power is off
reg  [2:0]              current_data_rate_others;     //used in layers other than layer1
reg  [2:0]              current_data_rate_xmlh_xmt;   //used in xmlh
reg  [2:0]              current_data_rate_xmlh_scr;   //used in xmlh
reg  [2:0]              current_data_rate_rmlh;       //used in rmlh
reg  [2:0]              current_data_rate_rmlh_dsk;   //used in rmlh
reg  [2:0]              current_data_rate_rmlh_scr;   //used in rmlh
reg  [2:0]              current_data_rate_rmlh_pkf;   //used in rmlh
reg  [2:0]              current_data_rate_smlh_sqf;   //used in smlh
reg  [2:0]              current_data_rate_smlh_lnk;   //used in smlh
reg  [2:0]              current_data_rate_smlh_eq ;   //used in smlh
reg  [2:0]              current_data_rate_ltssm;      //used in ltssm of smlh because ltssm has a lot of fan-outs

reg  [1:0]              current_powerdown;

reg                     latched_smlh_link_up;

always @( posedge core_clk or negedge core_rst_n ) begin : latched_smlh_link_up_PROC
    if ( ~core_rst_n )
        latched_smlh_link_up <= #TP 0;
    else if ( smlh_ltssm_state == `S_DETECT_QUIET )
        latched_smlh_link_up <= #TP 0;
    else if ( smlh_link_up )
        latched_smlh_link_up <= #TP 1;
end // latched_smlh_link_up_PROC

// smlh_no_turnoff_lanes is latched smlh_lanes_active when entry to linkup.
// So for ~linkup, use smlh_lanes_active
assign lanes_on = (smlh_link_up || latched_smlh_link_up) ? smlh_no_turnoff_lanes : smlh_lanes_active;

// Now create squelched version of the data
assign sq_rxvalid = ~squelch & phy_mac_rxvalid & ~({NL{current_powerdown[1]}});

assign sq_rxdata_dv = 
                      (phy_type == `PHY_TYPE_MPCIE) ? sq_rxvalid :
                       (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid : {NL{1'b1}}) &
                      sq_rxvalid;

assign sq_rxdatak = 
                    (dup_squelch(sq_rxvalid) & int_rxdatak);

assign rpipe_eios_eieos_det = |(eios_eieos_det_i & smlh_lanes_active);


// The non-registers
reg     [NL-1:0]        l_rxskipadded;
reg     [NL-1:0]        l_rxskipremoved;
reg     [NL-1:0]        l_rxdisperror;
reg     [NL-1:0]        l_rxcodeerror;
reg     [NL-1:0]        l_rxunderflow;
reg     [NL-1:0]        l_rxoverflow;
reg     [NL-1:0]        l_rxdetected;
reg                     rpipe_rcvd_eidle_set;
wire    [NL-1:0]        int_rpipe_rcvd_eidle_set;
wire    [NL-1:0]        int_rpipe_rcvd_eidle_set_i;
reg     [NL-1:0]        act_rpipe_rcvd_eidle_set;

wire    [NL-1:0]        rxelecidle_r;

// Output registering (optional)
parameter N_DELAY_CYLES = REGOUT ? 1 : 0;
parameter DATAPATH_WIDTH = (NL*NB*8) + (NL*NBK) + 8*NL;
parameter RESET_VALUE = { {(NL*NB*8) + (NL*NBK) + 7*NL{1'b0}}, {NL{1'b1}}} ; // Reset value of Rxelecidle=1, The others = 0
delay_n

#(N_DELAY_CYLES, DATAPATH_WIDTH, RESET_VALUE) u_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ( { phy_mac_rxdata,sq_rxdatak,      sq_rxdata_dv,
                    l_rxskipadded, l_rxskipremoved, l_rxcodeerror,
                    l_rxoverflow,  l_rxunderflow,   l_rxdisperror, rxelecidle_r  }),
    .dout       ({  rpipe_rxdata,      rpipe_rxdatak,       rpipe_rxdata_dv,
                    rpipe_rxskipadded, rpipe_rxskipremoved, rpipe_rxcodeerror,
                    rpipe_rxoverflow,  rpipe_rxunderflow,   rpipe_rxdisperror, rpipe_rxelecidle })
);

delay_n

#(N_DELAY_CYLES, NL) u_delay_g_rxaligned(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ sq_rxvalid }),
    .dout       ({ rpipe_rxaligned }) // rxaligned=0 is used to keep scrambler under reset
);




wire   rpipe_all_sym_locked; //symbol locked on all active lanes
reg    rpipe_all_sym_locked_d;

always @(posedge core_clk or negedge core_rst_n)
begin : latch_all_sym_locked
  if (!core_rst_n)
    rpipe_all_sym_locked_d <= 0;
  else
    rpipe_all_sym_locked_d <= &((phy_mac_rxvalid & smlh_lanes_active) | ~smlh_lanes_active);
end

assign rpipe_all_sym_locked = rpipe_all_sym_locked_d;

// if the squelch module is defined, then it will synchronize phy_mac_rxelecidle.
assign  rxelecidle_r = phy_mac_rxelecidle;

reg     [NL-1:0]    rpipe_rxdetected;
reg                 rpipe_rxdetect_done;
always @(posedge core_clk or negedge core_rst_n)
begin : latch_detection_results
    integer ln;

    if (!core_rst_n) begin
        rpipe_rxdetected        <= #TP {NL{1'b0}};
    end else if (ltssm_clear) begin
        rpipe_rxdetected        <= #TP {NL{1'b0}};
    end else begin
        for (ln=0; ln<NL; ln=ln+1) begin
            if (phy_mac_phystatus[ln]) begin
                rpipe_rxdetected[ln]    <= #TP l_rxdetected[ln];
            end
        end
    end
end // latch_detection_results


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rpipe_rxdetect_done     <= #TP 1'b0;
    end else if (ltssm_clear) begin
        rpipe_rxdetect_done     <= #TP 1'b0;
    end else begin
        rpipe_rxdetect_done     <= #TP rpipe_all_phystatus_asserted;
    end

reg [NL-1:0]    rpipe_phystatus_asserted;
always @(posedge core_clk_ug or negedge core_rst_n)
begin : collect_phystatus_assertions
    integer ln;

    if (!core_rst_n) begin
        rpipe_phystatus_asserted                <= #TP {NL{1'b1}};
    end else if (ltssm_clear) begin
        rpipe_phystatus_asserted                <= #TP {NL{1'b0}};
    end else begin
        for (ln=0; ln<NL; ln=ln+1)
            if (phy_mac_phystatus[ln])
                rpipe_phystatus_asserted[ln]    <= #TP 1'b1;
    end
end // collect_phystatus_assertions

reg                     rpipe_all_phystatus_deasserted;
reg                     rpipe_all_phystatus_asserted;
always @(posedge core_clk_ug or negedge core_rst_n)
    if (!core_rst_n) begin
        rpipe_all_phystatus_asserted        <= #TP 1'b1;
        rpipe_all_phystatus_deasserted      <= #TP 1'b0;
    end else begin
        rpipe_all_phystatus_asserted        <= #TP &((lanes_on &  rpipe_phystatus_asserted) | ~lanes_on);
        rpipe_all_phystatus_deasserted      <= #TP &((lanes_on & ~phy_mac_phystatus) | ~lanes_on);
    end


reg  [NL*2-1:0] phy_mac_powerdown;
reg  [NL*3-1:0] phy_mac_rate;
reg  [NL-1:0]   phy_mac_powerdown_ready_bus;
reg  [NL-1:0]   phy_mac_rate_ready_bus;
wire            all_phy_mac_powerdown_ready;
wire            all_phy_mac_rate_ready;
always @(posedge core_clk_ug or negedge core_rst_n) begin : phy_mac_powerdown_rate_seq_PROC
    integer j;
    if ( ~core_rst_n ) begin
        phy_mac_powerdown <= #TP {NL{`P1}};
        phy_mac_rate      <= #TP 0;
    end else begin
        for ( j=0; j<NL; j=j+1 ) begin
            if ( phy_mac_phystatus[j] ) begin
                phy_mac_rate[j*3 +: 3]      <= #TP mac_phy_rate;
                phy_mac_powerdown[j*2 +: 2] <= #TP ltssm_powerdown;
            end
        end //for
    end
end //always

always @( * ) begin : phy_mac_powerdown_rate_PROC
    integer j;
    phy_mac_powerdown_ready_bus = {NL{1'b1}};
    phy_mac_rate_ready_bus      = {NL{1'b1}};

    for ( j=0; j<NL; j=j+1 ) begin
    //if PHY acknowledged on a Lane, the Lane's powerdown/datarate change was done
        phy_mac_powerdown_ready_bus[j] = ( phy_mac_powerdown[j*2 +: 2] == ltssm_powerdown );
        phy_mac_rate_ready_bus[j]      = ( phy_mac_rate[j*3 +: 3] == mac_phy_rate );
    end //for
end //always

//when all ACTIVE Lanes' powerdown/datarate changes are done by PHY, phystatus_wait_done = 1
//powerdown and datarate changes are exclusive
assign all_phy_mac_powerdown_ready = &(phy_mac_powerdown_ready_bus | ~lanes_on);
assign all_phy_mac_rate_ready      = &(phy_mac_rate_ready_bus | ~lanes_on);

always @(posedge core_clk_ug or negedge core_rst_n) begin : current_powerdown_PROC
    if ( ~core_rst_n ) begin
        current_powerdown <= #TP `P1;
    end else if ( all_phy_mac_powerdown_ready ) begin
    //sync to requested powerdown to get current powerdown after all ACTIVE Lanes phystatus back
        current_powerdown <= #TP ltssm_powerdown;
    end
end //always

// current_data_rate goto PM for shadowing the value when the main power is off
always @(posedge core_clk_ug or negedge core_rst_n) begin : current_data_rate_PROC
    if ( ~core_rst_n ) begin
        current_data_rate <= #TP 0;
    end 
    else if ( all_phy_mac_rate_ready ) begin
    //sync to requested datarate to get current data rate after all ACTIVE Lanes phystatus back
        current_data_rate <= #TP mac_phy_rate;
    end
end //always


// branch pm_current_data_rate to resolve synthesis timing closure issue because of massive fan-outs
// using core_clk is ok because current_data_rate (using core_clk_ug) catches phystatus when core_clk is off
always @( posedge core_clk or negedge core_rst_n ) begin : branch_pm_current_data_rate_PROC
    if ( ~core_rst_n ) begin
        current_data_rate_others     <= #TP 0;
        current_data_rate_xmlh_xmt   <= #TP 0;
        current_data_rate_xmlh_scr   <= #TP 0;
        current_data_rate_rmlh       <= #TP 0;
        current_data_rate_rmlh_dsk   <= #TP 0;
        current_data_rate_rmlh_scr   <= #TP 0;
        current_data_rate_rmlh_pkf   <= #TP 0;
        current_data_rate_smlh_sqf   <= #TP 0;
        current_data_rate_smlh_lnk   <= #TP 0;
        current_data_rate_smlh_eq    <= #TP 0;
        current_data_rate_ltssm      <= #TP 0;
    end else begin
        current_data_rate_others     <= #TP pm_current_data_rate;
        current_data_rate_xmlh_xmt   <= #TP pm_current_data_rate;
        current_data_rate_xmlh_scr   <= #TP pm_current_data_rate;
        current_data_rate_rmlh       <= #TP pm_current_data_rate;
        current_data_rate_rmlh_dsk   <= #TP pm_current_data_rate;
        current_data_rate_rmlh_scr   <= #TP pm_current_data_rate;
        current_data_rate_rmlh_pkf   <= #TP pm_current_data_rate;
        current_data_rate_smlh_sqf   <= #TP pm_current_data_rate;
        current_data_rate_smlh_lnk   <= #TP pm_current_data_rate;
        current_data_rate_smlh_eq    <= #TP pm_current_data_rate;
        current_data_rate_ltssm      <= #TP pm_current_data_rate;
    end
end // branch_pm_current_data_rate_PROC

reg [NL*NB-1:0] edb_i;
always @* begin: detect_edb_PROC // detect EDB on a symbol
    integer nl, nb; //lane#, byte#
    edb_i = 0;
    for ( nl=0; nl<NL; nl=nl+1 ) begin
        for ( nb=0; nb<NB; nb=nb+1 ) begin
            edb_i[nl*NB+nb] = (phy_mac_rxdata[(nl*NB*8 + nb*8) +: 8] == 8'hFE & phy_mac_rxdatak[(nl*NB*1 + nb*1) +: 1] & phy_mac_rxvalid[nl] & phy_mac_rxdatavalid[nl] & smlh_lanes_active[nl] & nb < active_nb);
        end
    end
end // detect_edb_PROC

reg [NL-1:0] edb; // detect EDB on a lane
always @* begin : edb_PROC
integer nl; //lane#

    edb = 0;
    for ( nl=0; nl<NL; nl=nl+1 ) begin
        edb[nl] = |edb_i[nl*NB +: NB];

        if ( current_data_rate_rmlh >= `GEN3_RATE ) // decode_err EDB check is only for Gen1/2 rate
            edb[nl] = 1'b1;
    end
end // edb_PROC

reg [2:0] val;
assign squelch_act = squelch | set_squelch;

always @(*)
begin: decode_status

integer ln;

    for ( ln=0; ln<NL; ln=ln+1 ) begin
        val[0] = phy_mac_rxstatus[ln*3];
        val[1] = phy_mac_rxstatus[ln*3+1];
        val[2] = phy_mac_rxstatus[ln*3+2];

        l_rxskipadded[ln]       = (val == 3'b001) ;
        l_rxskipremoved[ln]     = (val == 3'b010) ;
        l_rxdetected[ln]        = (val == 3'b011) ;

        // Mask these errors during electrical idle
        l_rxoverflow[ln]        = (val == 3'b101) & (!squelch_act[ln] & phy_mac_rxvalid[ln] & (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid[ln] : {NL{1'b1}})) ;
        l_rxunderflow[ln]       = (val == 3'b110) & (!squelch_act[ln] & phy_mac_rxvalid[ln] & (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid[ln] : {NL{1'b1}})) ;
        l_rxcodeerror[ln]       = (val == 3'b100) & (!squelch_act[ln] & phy_mac_rxvalid[ln] & (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid[ln] : {NL{1'b1}})) & edb[ln]; //PIPE: decode_err = EDB & RxStatus=100b
        l_rxdisperror[ln]       = (val == 3'b111) & (!squelch_act[ln] & phy_mac_rxvalid[ln] & (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid[ln] : {NL{1'b1}})) ;

        // Ignore electrical idle while data is valid
        // l_rxelecidle[ln]        = (rxelecidle_r[ln] & (!rpipe_rxvalid[ln]));
    end // For each lane

end // Always

// This function duplicates the squelch bit on a per-symbol basis
function automatic [NL*NBK-1:0] dup_squelch;
    input   [NL-1:0]    squelch;        // squelch control - per lane

    integer ln, sym;
begin
    dup_squelch = {NL*NBK{1'b0}};
    for (ln=0; ln<NL; ln=ln+1)
        for (sym=0; sym<NBK; sym=sym+1)
            dup_squelch[ln*NBK+sym] = squelch[ln];
end
endfunction

// bring act_rpipe_rcvd_eidle_set to LTSSM for any lane receiving eidle set
always @(posedge core_clk or negedge core_rst_n)
  if (~core_rst_n)
      act_rpipe_rcvd_eidle_set <= #TP 1'b0;
  else
      act_rpipe_rcvd_eidle_set <= #TP int_rpipe_rcvd_eidle_set & smlh_lanes_active;

// for the lanes that are active, we will detect the earlest eidleOS receving
always @(posedge core_clk or negedge core_rst_n)
  if (~core_rst_n)
      rpipe_rcvd_eidle_set <= #TP 1'b0;
  else
      rpipe_rcvd_eidle_set <= #TP |(int_rpipe_rcvd_eidle_set & smlh_lanes_active);

// Array of instances, implies new synthax in tb code for forcing internal wires, for example:
// force u_squelch[1].core_clk = 1;
rmlh_pipe_squelch
 u_squelch[NL-1:0]
(
// ---------- Inputs --------
  .core_clk                 (core_clk),
  .core_clk_ug              (core_clk_ug),
  .core_rst_n               (core_rst_n),
  .cfg_elastic_buffer_mode  (cfg_elastic_buffer_mode),
  .cfg_pipe_garbage_data_mode (cfg_pipe_garbage_data_mode),
  .rxvalid                  (phy_mac_rxvalid),
  .rxdata                   (phy_mac_rxdata),
  .rxdatak                  (phy_mac_rxdatak),
  .active_nb                (active_nb),
  .disable_squelch_turnoff  (1'b0),
  .current_data_rate        (current_data_rate_rmlh),
  .phy_type                 (phy_type),
  .smlh_ltssm_state         (smlh_ltssm_state),
  .rxdatavalid              (phy_mac_rxdatavalid),
  .mac_phy_rate             (mac_phy_rate),
  .sq_rxdatak               (int_rxdatak),
  .int_rpipe_rcvd_eidle_set (int_rpipe_rcvd_eidle_set_i),
  .set_squelch              (set_squelch_i),
  .eios_eieos_det           (eios_eieos_det_i),
  .squelch                  (squelch_i)
);

assign int_rpipe_rcvd_eidle_set = int_rpipe_rcvd_eidle_set_i;
assign set_squelch              = set_squelch_i;
assign squelch                  = squelch_i;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// System Verilog Assertions.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


endmodule
// leda W389 on
