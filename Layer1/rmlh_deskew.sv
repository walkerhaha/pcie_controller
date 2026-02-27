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
// ---    $DateTime: 2020/06/26 01:14:06 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_deskew.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer handler deskew logic.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rmlh_deskew
(
// ---- inputs ---------------
    core_rst_n,
    core_clk,
    cfg_elastic_buffer_mode,
    cfg_ts2_lid_deskew,
    rmlh_deskew_bypass,
    ltssm_cxl_ll_mod,
    drift_buffer_deskew_disable,
    deskew_lanes_active,
    smlh_in_rl0s_i,
    smlh_do_deskew_i,
    smseq_ts1_rcvd_pulse_bus_i,
    smseq_ts2_rcvd_pulse_bus_i,
    smseq_loc_ts2_rcvd_bus_i,
    smseq_in_skp_bus_i,
    smseq_fts_skp_do_deskew_bus_i,
    active_nb,
    rxdata_dv_i,
    rxaligned_i,
    rxdata_i,
    rxdata_comma_i,
    rxdata_skip_i,
    rxdata_skprm_i,
    rxdatak_i,
    rxerror_i,
    rxunderflow_i,
    rxoverflow_i,
    current_data_rate,
    smlh_ltssm_state_i,
    cxl_mode_enable,
    ltssm_lpbk_master_i,
    phy_type,
    rpipe_eios_eieos_det_i,
// ---- outputs ---------------
    deskew_rxdata_dv,
    deskew_rxdata,
    deskew_rxdatak,
    deskew_rxerror,
    deskew_rxdata_flush_gen12,
    deskew_ds_g12,
    deskew_alignment_err,
    deskew_complete
);

parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter NL            = `CX_NL;               // Max number of lanes supported
parameter NB            = `CX_NB;               // Number of symbols (bytes) per clock cycle
parameter NBK           = `CX_NBK;              // Number of symbols (bytes) per clock cycle for datak
parameter AW            = `CX_ANB_WD;           // Width of the active number of bytes
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
parameter REGIN         =  `CX_RMLH_DESKEW_REGIN; // PIPELine Option for Deskew inputs

input                   core_rst_n;
input                   core_clk;
input                   cfg_elastic_buffer_mode;
input                   cfg_ts2_lid_deskew;
input                   rmlh_deskew_bypass;
input   [1:0]           ltssm_cxl_ll_mod;        // {drift_buffer, common_clk} enabled
input                   drift_buffer_deskew_disable;
input   [NL-1:0]        deskew_lanes_active;
input                   smlh_in_rl0s_i;
input                   smlh_do_deskew_i;
input   [NL-1:0]        smseq_ts1_rcvd_pulse_bus_i;
input   [NL-1:0]        smseq_ts2_rcvd_pulse_bus_i;
input   [NL*4-1:0]      smseq_loc_ts2_rcvd_bus_i;
input   [NL*4-1:0]      smseq_in_skp_bus_i;
input   [NL-1:0]        smseq_fts_skp_do_deskew_bus_i;
input   [AW-1:0]        active_nb;
input   [NL-1:0]        rxdata_dv_i;
input   [NL-1:0]        rxaligned_i;
input   [(NL*NB*8)-1:0] rxdata_i;
input   [(NL*NB)-1:0]   rxdata_comma_i;
input   [(NL*NB)-1:0]   rxdata_skip_i;
input   [(NL*NB)-1:0]   rxdata_skprm_i;
input   [(NL*NBK)-1:0]  rxdatak_i;
input   [(NL*NB)-1:0]   rxerror_i;
input   [NL-1:0]        rxunderflow_i;
input   [NL-1:0]        rxoverflow_i;
input   [2:0]           current_data_rate;
input   [5:0]           smlh_ltssm_state_i;
input                   cxl_mode_enable;
input                   ltssm_lpbk_master_i;
input                   phy_type;
input                   rpipe_eios_eieos_det_i;

output                  deskew_rxdata_dv;
output  [(NL*NB*8)-1:0] deskew_rxdata;
output  [(NL*NB)-1:0]   deskew_rxdatak;
output  [(NL*NB)-1:0]   deskew_rxerror;
output                  deskew_rxdata_flush_gen12; // active high RX data flushing signal to pkt_finder at Gen1/2 rate
output  [NL-1:0]        deskew_ds_g12;
output                  deskew_alignment_err;
output                  deskew_complete;


// Pipeline option for timing closure
wire                    smlh_in_rl0s;
wire                    smlh_do_deskew;
wire    [NL-1:0]        smseq_ts1_rcvd_pulse_bus;
wire    [NL-1:0]        smseq_ts2_rcvd_pulse_bus;
wire    [NL*4-1:0]      smseq_loc_ts2_rcvd_bus;
wire    [NL*4-1:0]      smseq_in_skp_bus;
wire    [NL-1:0]        smseq_fts_skp_do_deskew_bus;
wire    [NL-1:0]        rxdata_dv;
wire    [NL-1:0]        rxaligned;
wire    [(NL*NB*8)-1:0] rxdata;
wire    [(NL*NB)-1:0]   rxdata_comma;
wire    [(NL*NB)-1:0]   rxdata_skip;
wire    [(NL*NB)-1:0]   rxdata_skprm;
wire    [(NL*NBK)-1:0]  rxdatak;
wire    [(NL*NB)-1:0]   rxerror;
wire    [NL-1:0]        rxunderflow;
wire    [NL-1:0]        rxoverflow;
wire    [5:0]           smlh_ltssm_state;
wire                    ltssm_lpbk_master;

wire delay_en = (smlh_ltssm_state_i != `S_DETECT_QUIET) & (smlh_ltssm_state_i != `S_DETECT_ACT);

delay_n_w_enable
 #(REGIN,       1) u_delay0  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smlh_in_rl0s_i),                .dout(smlh_in_rl0s));
delay_n_w_enable
 #(REGIN,       1) u_delay1  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smlh_do_deskew_i),              .dout(smlh_do_deskew));
delay_n_w_enable
 #(REGIN,      NL) u_delay2  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_ts1_rcvd_pulse_bus_i),    .dout(smseq_ts1_rcvd_pulse_bus));
delay_n_w_enable
 #(REGIN,      NL) u_delay3  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_ts2_rcvd_pulse_bus_i),    .dout(smseq_ts2_rcvd_pulse_bus));
delay_n_w_enable
 #(REGIN,    NL*4) u_delay4  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_loc_ts2_rcvd_bus_i),      .dout(smseq_loc_ts2_rcvd_bus));
delay_n_w_enable
 #(REGIN,    NL*4) u_delay5  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_in_skp_bus_i),            .dout(smseq_in_skp_bus));
delay_n_w_enable
 #(REGIN,      NL) u_delay6  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_fts_skp_do_deskew_bus_i), .dout(smseq_fts_skp_do_deskew_bus));
delay_n_w_enable
 #(REGIN,      1) u_delay61 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rpipe_eios_eieos_det_i),        .dout(rpipe_eios_eieos_det));
delay_n_w_enable
 #(REGIN,      NL) u_delay8  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_dv_i),         .dout(rxdata_dv));
delay_n_w_enable
 #(REGIN,      NL) u_delay9  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxaligned_i),         .dout(rxaligned));
delay_n_w_enable
 #(REGIN, NL*NB*8) u_delay10 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_i),            .dout(rxdata));
delay_n_w_enable
 #(REGIN,   NL*NB) u_delay11 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_comma_i),      .dout(rxdata_comma));
delay_n_w_enable
 #(REGIN,   NL*NB) u_delay12 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_skip_i),       .dout(rxdata_skip));
delay_n_w_enable
 #(REGIN,   NL*NB) u_delay13 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_skprm_i),      .dout(rxdata_skprm));
delay_n_w_enable
 #(REGIN,  NL*NBK) u_delay14 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdatak_i),           .dout(rxdatak));
delay_n_w_enable
 #(REGIN,   NL*NB) u_delay15 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxerror_i),           .dout(rxerror));
delay_n_w_enable
 #(REGIN,      NL) u_delay16 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxunderflow_i),       .dout(rxunderflow));
delay_n_w_enable
 #(REGIN,      NL) u_delay17 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxoverflow_i),        .dout(rxoverflow));
delay_n_w_enable
 #(REGIN,       6) u_delay18 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smlh_ltssm_state_i),  .dout(smlh_ltssm_state));
delay_n_w_enable
 #(REGIN,       1) u_delay19 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(ltssm_lpbk_master_i), .dout(ltssm_lpbk_master));

//



// Output internal version
wire                    deskew_alignmenterror_i;
wire                    deskew_alignmenterror_dnew_i;
reg                     int_deskew_alignmenterror;
reg                     deskew_complete_i;
wire                    deskew_rxdata_dv_i;
wire    [(NL*NB*8)-1:0] deskew_rxdata_i;
wire    [(NL*NB)-1:0]   deskew_rxdatak_i;
wire    [(NL*NB)-1:0]   deskew_rxerror_i;
wire                    slv_do_deskew;
wire                    deskew_bypass;


// Output assignment
// deskew is not bypassed when data rate is GEN3_RATE
wire   cxl_drift_buffer_deskew_enabled = !drift_buffer_deskew_disable && ltssm_cxl_ll_mod[1]; // if drift buffer enabled, no deskew required for cxl gen3/4/5 rates to reduce latency


assign deskew_bypass = rmlh_deskew_bypass;

assign deskew_alignment_err    = deskew_alignmenterror_i;
assign deskew_complete         = deskew_complete_i;
assign deskew_rxdata_dv        = deskew_rxdata_dv_i;
assign deskew_rxdata           = deskew_rxdata_i;
assign deskew_rxdatak          = deskew_rxdatak_i;
assign deskew_rxerror          = deskew_rxerror_i;
/*
assign deskew_alignment_err    = rmlh_deskew_bypass ? 1'b0             : deskew_alignmenterror_i;
assign deskew_complete         = rmlh_deskew_bypass ? 1'b1             : deskew_complete_i;
assign deskew_rxdata_dv        = rmlh_deskew_bypass ? |rxdata_dv       : deskew_rxdata_dv_i;
assign deskew_rxdata           = rmlh_deskew_bypass ? rxdata           : deskew_rxdata_i;
assign deskew_rxdatak          = rmlh_deskew_bypass ? rxdatak          : deskew_rxdatak_i;
assign deskew_rxerror          = rmlh_deskew_bypass ? rxerror          : deskew_rxerror_i;
*/

// Internal regs and wires
reg     [NL-1:0]        lanes_active;  // registered version of deskew_lanes_active for timing reasons
wire    [NL-1:0]        deskew_rxdata_dv_bus;
wire    [NL-1:0]        deskew_overflow;            // Deskew logic is overflowing (indicates an error)
wire    [NL-1:0]        deskew_see_idl_os;          // EIOS detected
reg                     any_deskew_see_idl_os;      // A EIOS detected on any active lane
wire    [NL-1:0]        deskew_skp_alignment_err;
wire    [NL-1:0]        deskew_ds_g12;              // in data stream
wire                    deskew_rxdata_flush_gen12;  // active high data flushing signal for pkt_finder at Gen1/2 rate
reg                     deskew_rxdata_flush_gen12_d;// active high data flushing signal for pkt_finder at Gen1/2 rate
wire    [NL-1:0]        deskew_enable;              // deskew takes effect
wire                    deskew_enable_all;
reg                     deskew_rxdata_dv_d;         // latch and clear version to deskew_rxdata_dv
wire                    unload;
   wire [NL-1:0]        skp_vec1;  // collection of lanes, SKP symbol on byte lane 1
   wire [NL-1:0]        skp_vec1_active;  // only active lanes
   wire [NL-1:0]        skp_vec0;  // collection of lanes, SKP symbol on byte lane 0
   wire [NL-1:0]        skp_vec0_active;  // only active lanes

   wire [NB-1:0]        valid_skp_n;

   // if one lane has a SKP symbol on a particular byte lane, then all active
   // lanes should have a SKP symbol on the same byte lane
assign valid_skp_n = {
                      |skp_vec1_active ^ &skp_vec1_active,
                      |skp_vec0_active ^ &skp_vec0_active
                      };


assign skp_vec1_active =  // clear non-active lanes
                          skp_vec1 & lanes_active
                          // make non-active lanes have same value as lane 0, lane 0 must always be active
                        | {NL{skp_vec1[0]}} & ~lanes_active;

assign skp_vec0_active =  // clear non-active lanes
                          skp_vec0 & lanes_active
                          // make non-active lanes have same value as lane 0, lane 0 must always be active
                        | {NL{skp_vec0[0]}} & ~lanes_active;

assign                  deskew_rxdata_dv_i      = &(~lanes_active | deskew_rxdata_dv_bus)
                                                  & lanes_active[0];  // at reset lanes_active==0, need to make sure that at least one lane is active

assign                  unload                  =  deskew_rxdata_dv_i;

assign                  deskew_enable_all       = &(~deskew_lanes_active | deskew_enable);

always @( posedge core_clk or negedge core_rst_n ) begin : deskew_rxdata_dv_d_PROC
    if ( ~core_rst_n ) begin
        deskew_rxdata_dv_d <= #TP 0;
    end else if ( ~deskew_enable_all ) begin
        deskew_rxdata_dv_d <= #TP 0;
    end else if ( deskew_rxdata_dv ) begin
        deskew_rxdata_dv_d <= #TP 1;
    end
end // deskew_rxdata_dv_d_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : deskew_rxdata_flush_gen12_d_PROC
    if ( ~core_rst_n ) begin
        deskew_rxdata_flush_gen12_d <= #TP 0;
    end else begin
        deskew_rxdata_flush_gen12_d <= #TP deskew_rxdata_flush_gen12;
    end
end // deskew_rxdata_flush_gen12_d_PROC

assign deskew_rxdata_flush_gen12 = (current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE) & // flushing only for Gen1/2
                                   ~(smlh_ltssm_state == `S_DETECT_QUIET || smlh_ltssm_state == `S_DETECT_ACT || smlh_ltssm_state == `S_DETECT_WAIT) & // no flushing in Detect states
                                   // if deskew_lanes_active changes, keep previous deskew_rxdata_flush_gen12. Then at next cycle smlh_do_deskew will resets deskew_enable and deskew_rxdata_dv.
                                   // if lanes receives SKP OS and deskew_rxdata_dv=1 and deskew_enable_all=1 during the clock (deskew_lanes_active != lanes_active), needs to disable deskew_rxdata_flush_gen12.
                                   // at the next clock deskew_enable_all will be 0 because deskew gets reset from (deskew_lanes_active != lanes_active), i.e. smlh_do_deskew = 0.
                                   ( (deskew_lanes_active != lanes_active) ? (deskew_rxdata_flush_gen12_d & ~deskew_rxdata_dv) : // ~deskew_rxdata_dv to avoid deskew_rxdata_flush_gen12=1 and deskew_rxdata_dv=1.
                                   ((~deskew_enable_all) ? 1'b1 : // flushing immediately if any active lanes deskew_enable=0
                                                           ~(deskew_rxdata_dv | deskew_rxdata_dv_d) // no flushing if deskew_rxdata_dv = 1
                                   ) );


always @(posedge core_clk or negedge core_rst_n)
    if(~core_rst_n)
        int_deskew_alignmenterror <= #TP 1'b0;
    else
        int_deskew_alignmenterror <= #TP
                                        (deskew_rxdata_dv_i & |valid_skp_n & (&(~lanes_active | deskew_ds_g12)))
                                      | (deskew_complete_i  & |(deskew_skp_alignment_err & lanes_active) )
                                      | (deskew_complete_i  & |(deskew_overflow & lanes_active));

assign deskew_alignmenterror_i = ~cxl_drift_buffer_deskew_enabled & deskew_bypass ? 0 : // no alignment error if bypass deskew for Gen1/2 rate
                                 int_deskew_alignmenterror
                                 ;
assign deskew_alignmenterror_dnew_i = ~cxl_drift_buffer_deskew_enabled & deskew_bypass ? 0 : // no alignment error if bypass deskew for Gen1/2 rate
                                      int_deskew_alignmenterror 
 ;

always @(posedge core_clk or negedge core_rst_n) begin : any_deskew_see_idl_os_PROC
    if (~core_rst_n)
        any_deskew_see_idl_os <= #TP 0;
    else
        any_deskew_see_idl_os <= #TP ( |( deskew_see_idl_os & lanes_active) );
end

always @(posedge core_clk or negedge core_rst_n)
    if(~core_rst_n)
      deskew_complete_i <= #TP 1'b0;
    else if ( ~cxl_drift_buffer_deskew_enabled & deskew_bypass )
      deskew_complete_i <= #TP 1'b1; // always deskew complete if bypass deskew for Gen1/2 rate
    else if (  deskew_alignmenterror_dnew_i
             | ~smlh_do_deskew
             | (any_deskew_see_idl_os
               ) )
      deskew_complete_i <= #TP 1'b0;
    else if (deskew_rxdata_dv_i)
      deskew_complete_i <= #TP 1'b1;  // we are only complete on the deskew if there is
                                      //  no alignment error and we are being told to do_deskew

assign slv_do_deskew = 
                       (~deskew_alignmenterror_i & smlh_do_deskew & ~any_deskew_see_idl_os);

wire [(NL*NB)-1:0] deskew_skp_i;


reg [AW-1:0] active_nb_d;
always @(posedge core_clk or negedge core_rst_n) begin : active_nb_d_PROC
    if(~core_rst_n)
        active_nb_d <= #TP 1;
    else
        active_nb_d <= #TP active_nb;
end

wire [NL-1:0] smseq_ts1_rcvd_pulse_bus_int = smseq_ts1_rcvd_pulse_bus[NL-1:0];
wire [NL-1:0] smseq_ts2_rcvd_pulse_bus_int = smseq_ts2_rcvd_pulse_bus[NL-1:0];
wire [(NL*NB)-1:0]        rxdata_comma_int = rxdata_comma[(NL*NB)-1:0];
wire [NL*4-1:0] smseq_loc_ts2_rcvd_bus_int = smseq_loc_ts2_rcvd_bus[NL*4-1:0];

rmlh_deskew_slv
 #(INST) u_rmlh_deskew_slv[NL-1:0] //  per lane array of instances
(
// ---- inputs ---------------
    .core_rst_n                   (core_rst_n),
    .core_clk                     (core_clk),
    .cfg_elastic_buffer_mode      (cfg_elastic_buffer_mode),
    .cfg_ts2_lid_deskew           (cfg_ts2_lid_deskew),
    .active_nb                    (active_nb),
    .active_nb_d                  (active_nb_d),

    .slv_do_deskew                (slv_do_deskew),
    .smseq_ts1_rcvd_pulse         (smseq_ts1_rcvd_pulse_bus_int[NL-1:0]),
    .smseq_ts2_rcvd_pulse         (smseq_ts2_rcvd_pulse_bus_int[NL-1:0]),
    .smseq_loc_ts2_rcvd           (smseq_loc_ts2_rcvd_bus_int[NL*4-1:0]),
    .smseq_in_skp                 (smseq_in_skp_bus[NL*4-1:0]),
    .smseq_fts_skp_do_deskew      (smseq_fts_skp_do_deskew_bus[NL-1:0]),
    .rxdata_dv                    (rxdata_dv[NL-1:0]),
    .rxaligned                    (rxaligned[NL-1:0]),
    .rxdata                       (rxdata[(NL*NB*8)-1:0]),
    .rxdata_comma                 (rxdata_comma_int[(NL*NB)-1:0]),
    .rxdata_skip                  (rxdata_skip[(NL*NB)-1:0]),
    .rxdata_skprm                 (rxdata_skprm[(NL*NB)-1:0]),
    .rxdatak_i                    (rxdatak[(NL*NBK)-1:0]),
    .rxerror                      (rxerror[(NL*NB)-1:0]),
    .current_data_rate            (current_data_rate[2:0]),
    .smlh_ltssm_state             (smlh_ltssm_state),
    .cxl_mode_enable              (cxl_mode_enable),
    .smlh_in_rl0s                 (smlh_in_rl0s),
    .ltssm_lpbk_master            (ltssm_lpbk_master),
    .phy_type                     (phy_type),
    .unload                       (unload),
    .deskew_bypass                (deskew_bypass),
    .rpipe_eios_eieos_det         (rpipe_eios_eieos_det),
// ---- outputs ---------------
    .deskew_rxdata_dv             (deskew_rxdata_dv_bus), // www: putting [NL-1:0] causes simulator to badly initialize bus and later cause X's
    .deskew_rxdata                (deskew_rxdata_i[(NL*NB*8)-1:0]),
    .deskew_rxdatak               (deskew_rxdatak_i[(NL*NB)-1:0]),
    .deskew_rxerror               (deskew_rxerror_i[(NL*NB)-1:0]),
    .deskew_overflow              (deskew_overflow[NL-1:0]),
    .deskew_skp                   (deskew_skp_i[(NL*NB)-1:0]),
    .deskew_see_idl_os            (deskew_see_idl_os[NL-1:0]),
    .deskew_enable                (deskew_enable[NL-1:0]),
    .deskew_ds_g12                (deskew_ds_g12[NL-1:0]),
    .deskew_skp_alignment_err     (deskew_skp_alignment_err[NL-1:0])
);

   assign  {
            skp_vec1[0],
            skp_vec0[0]} = deskew_skp_i[(0*NB)+NB-1:(0*NB)];

   assign  {
            skp_vec1[1],
            skp_vec0[1]} = deskew_skp_i[(1*NB)+NB-1:(1*NB)];

   assign  {
            skp_vec1[2],
            skp_vec0[2]} = deskew_skp_i[(2*NB)+NB-1:(2*NB)];

   assign  {
            skp_vec1[3],
            skp_vec0[3]} = deskew_skp_i[(3*NB)+NB-1:(3*NB)];



// Register the active lanes to help with timing.
always @(posedge core_clk or negedge core_rst_n)
    if(~core_rst_n)
        lanes_active <= #TP {NL{1'b0}};
    else
        lanes_active <= #TP deskew_lanes_active;

// ASSERTIONS!
//
// want to see a COM on some lanes, with smlh_do_deskew low
// then within 5 clocks I want to see COM on the other lanes with smlh_do_deskew high
//    this should result in an overflow on the later lanes, thereby reseting the rmlh_deskew_slv logic
//
// deskew_rxdata_dv should not be asserted when deskew_complete is low

// COVERAGE!
//
//  BFM transitions tx to electrical idle w/o sending an EIOS (and skew changes)
//
//  want to see an alignment error (deskew_alignmenterror)
//

/* -----\/----- EXCLUDED -----\/-----
property p_comma0 ;
  @(posedge core_clk) rxdata_dv && rxdatak[0] && (rxdata[7:0]==`COMMA_8B);
endproperty

property p_comma1 ;
  @(posedge core_clk) rxdata_dv && rxdatak[1] && (rxdata[15:8]==`COMMA_8B);
endproperty

property p_comma2 ;
  @(posedge core_clk) rxdata_dv && rxdatak[2] && (rxdata[23:16]==`COMMA_8B);
endproperty

property p_comma3 ;
  @(posedge core_clk) rxdata_dv && rxdatak[3] && (rxdata[31:24]==`COMMA_8B);
endproperty

  c_comma0 : cover property (p_comma0);

property p_comma0_no_do_deskew ;
   @(posedge core_clk) rxdata_dv && rxdatak[0] && (rxdata[7:0]==`COMMA_8B) && ~smlh_do_deskew ;
endproperty

property p_comma3_do_deskew ;
   @(posedge core_clk) rxdata_dv && rxdatak[3] && (rxdata[31:24]==`COMMA_8B) && smlh_do_deskew ;
endproperty

property p_this_is_it ;
   @(posedge core_clk) (rxdata_dv && rxdatak[0] && (rxdata[7:0]==`COMMA_8B) && ~smlh_do_deskew) |-> ##[1:5] (rxdata_dv && rxdatak[3] && (rxdata[31:24]==`COMMA_8B) && smlh_do_deskew) ;
endproperty

  c_comma0_no_do_deskew : cover property (p_comma0_no_do_deskew);
  c_comma3_do_deskew    : cover property (p_comma3_do_deskew);
  c_this_is_it : cover property (p_this_is_it);
 -----/\----- EXCLUDED -----/\----- */


endmodule
