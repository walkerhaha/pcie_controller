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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh.sv#13 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit MAC Layer Handler
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module xmlh
#(
parameter INST              = 0,                                     // The uniquifying parameter for each port logic instance.

parameter AW                = `CX_ANB_WD,                            // Width of the active number of bytes
parameter NL                = `CX_NL,                                // Max number of lanes supported
parameter NB                = `CX_NB,                                // Number of symbols (bytes) per clock cycle
parameter NBK               = `CX_NBK,                               // Number of symbols (bytes) per clock cycle for datak
parameter NW                = `CX_PL_NW,                             // Number of 32-bit dwords handled by the datapath each clock.
parameter L2NL              = NL==1 ? 1 : `CX_LOGBASE2(NL)           // log2 number of NL
)
(
// Interface Ports
tx_lp_if.slave_mp           b_xplh_xmlh_sp,                 // Link Layer to Physical Layer transmit slave modport
// inputs
input                                core_clk,
input                                core_rst_n,
input                                latched_smlh_link_up,
input   [L2NL-1:0]                   latched_flip_ctrl,
input   [L2NL-1:0]                   smlh_lane_flip_ctrl,
input   [NL-1:0]                     ltssm_lpbk_slave_lut,           // lane under test
input   [7:0]                        muxed_n_fts,                    // 8bits bus to specify the number of FTS we wish to receive for our receiver
input   [5:0]                        cfg_link_capable,               // It is application specific. It needs to be decided by application at implementation
                                                                     // time. It indicates the x1, x2, x4 capability of a port. This is an output of
                                                                     // PCIE spec. required config register.
input                                cfg_fast_link_mode,             //
input  [10:0]                        cfg_skip_interval,              // the number of symbol times between skip requests
input                                cfg_ext_synch,
input                                cfg_mod_ts,                     // modified TS format
input                                phy_type,                       // Mac type
input   [2:0]                        current_data_rate_xmt,          // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
input   [2:0]                        current_data_rate_scr,          // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
input   [AW-1:0]                     active_nb,                      // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
input   [NL-1:0]                     phy_mac_phystatus,
input                                ltssm_ts_auto_change,
input   [7:0]                        ltssm_xlinknum,
input   [NL-1:0]                     ltssm_xk237_4lannum,
input   [NL-1:0]                     ltssm_xk237_4lnknum,
input   [7:0]                        ltssm_ts_cntrl,                 // training sequence control
input                                ltssm_mod_ts,                   // Tx modified TS OS
input                                ltssm_ts_alt_protocol,          // Alternate Protocol
input                                ltssm_no_idle_need_sent,        // No idle need sent
input   [55:0]                       ltssm_ts_alt_prot_info,         // sym14-8 for AP
input   [3:0]                        ltssm_eidle_cnt,
input                                ltssm_clear,
input   [3:0]                        ltssm_cmd,
input   [1:0]                        ltssm_powerdown,                // powerdown from LTSSM to rmlh_pipe
input                                ltssm_lpbk_master,              // 
input                                ltssm_in_lpbk,
input   [7:0]                        latched_ts_nfts,
input   [5:0]                        smlh_link_mode,
input   [NL-1:0]                     smlh_lanes_active,
input   [NL-1:0]                     lpbk_eq_lanes_active,
input   [NL-1:0]                     power_saving_lanes_active,
input   [NL-1:0]                     smlh_no_turnoff_lanes,
input   [5:0]                        smlh_ltssm_state,
input   [5:0]                        smlh_ltssm_next,
input   [5:0]                        smlh_ltssm_last,
input                                smlh_scrambler_disable,         // when asserted, scramble disabled.

// outputs
output  [10:0]                       xmtbyte_ts_pcnt,                // transmit ts persistency count
output                               xmtbyte_ts_data_diff,           // current ts data different from previous
output                               xmtbyte_1024_ts_sent,
output                               xmtbyte_spd_chg_sent,           // transmit ts with speed_change bit set
output                               xmtbyte_dis_link_sent,          // transmit TS with disable_link bit set
output                               xmlh_cmd_is_data,               // xmtbyte state machine is waiting for packet start or packet end
output  [(NL*NB*8)-1:0]              mac_phy_txdata,                 // 2 bytes parallel transmit data
output  [(NL*NB)-1:0]                mac_phy_txdatak,                // Indicates K characters
output  [NL-1:0]                     mac_phy_txdetectrx_loopback,    // Enable receiver detect (loopback)
output  [NL-1:0]                     mac_phy_txelecidle,             // Enable Transmitter Electical Idle
output  [NL-1:0]                     mac_phy_txcompliance,           // Set negative running disparity (for compliance pattern)
output                               xmtbyte_skip_sent,
output                               xmtbyte_ts1_sent,
output                               xmtbyte_ts2_sent,
output                               xmtbyte_idle_sent,
output                               xmtbyte_eidle_sent,
output                               xmtbyte_fts_sent,
output                               xmtbyte_txdata_dv,
output [(NL*NB*8)-1:0]               xmtbyte_txdata,
output [(NL*NBK)-1:0]                xmtbyte_txdatak,
output [NL-1:0]                      xmtbyte_txelecidle,
output                               xmtbyte_txdetectrx_loopback,
output  [1:0]                        xpipe_powerdown                 // Set PHY to P0/P0s/P1 (PME will set P2)
                                                                     // without the port transitioning through DL_Down status
                                                                     // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
);


// internal signals
wire    [10:0]                       cpcie_xmtbyte_ts_pcnt;
wire                                 cpcie_xmtbyte_ts_data_diff;
wire                                 cpcie_xmtbyte_1024_ts_sent;
wire                                 cpcie_xmtbyte_spd_chg_sent;
wire                                 cpcie_xmtbyte_dis_link_sent;
wire    [(NL*NBK)-1:0]               xmtbyte_txdatak_org;              // Error inserted txdatak
wire                                 xmtbyte_link_in_training;
wire    [NL-1:0]                     xmtbyte_txcompliance;             // Set negative running disparity (for compliance pattern)
wire    [NL-1:0]                     xpipe_phystatus;                  // PIPE phy status signal
wire    [NL-1:0]                     scramble_data_dv;
wire    [(NL*NB*8)-1:0]              scramble_data;
wire    [(NL*NBK)-1:0]               scramble_datak;
wire    [(NL*NB)-1:0]                scramble_error;
wire    [(NL*NB*8)-1:0]              scramble_data_org;
wire    [(NL*NB*8)-1:0]              reversed_data;
wire    [(NL*NBK)-1:0]               reversed_datak;
wire    [(NL*NB)-1:0]                reversed_error;


// This block takes care of the muxing of special order set and dllp/tlp
// data from xdlh module
// For core clock running at 125Mhz, this block also takes care of symbol
// aligning so that it transmits to pipe interface two symbols per clock
wire                    cpcie_xmtbyte_txdata_dv;
wire    [(NL*NB*8)-1:0] cpcie_xmtbyte_txdata;
wire    [(NL*NBK)-1:0]  cpcie_xmtbyte_txdatak;
wire    [NL-1:0]        cpcie_xmtbyte_txstartblock;
wire                    cpcie_xmtbyte_ts1_sent;
wire                    cpcie_xmtbyte_ts2_sent;
wire                    cpcie_xmtbyte_fts_sent;
wire                    cpcie_xmtbyte_idle_sent;
wire                    cpcie_xmtbyte_eidle_sent;
wire                    cpcie_xmtbyte_skip_sent;
wire                    xmlh_rst_flit_alignment;
wire                    cpcie_xmlh_xdlh_halt;
wire                    cpcie_xmlh_skip_pending;
wire                    cpcie_xmtbyte_link_in_training;
wire    [NL-1:0]        cpcie_xmtbyte_txelecidle;             // Enable Transmitter Electical Idle
wire                    cpcie_xmtbyte_txdetectrx_loopback;    // Enable receiver detect (loopback)
wire    [NL-1:0]        cpcie_xmtbyte_txcompliance;           // Set negative running disparity (for compliance pattern)
wire                    cpcie_xmtbyte_cmd_is_data;

wire                    xmtbyte_cmd_is_data;


//--------------------------------------
// xmlh_byte_xmt Selector
//--------------------------------------


 assign xmtbyte_ts_pcnt              = cpcie_xmtbyte_ts_pcnt;
 assign xmtbyte_ts_data_diff         = cpcie_xmtbyte_ts_data_diff;

   assign xmtbyte_dis_link_sent        = cpcie_xmtbyte_dis_link_sent;
   assign xmtbyte_ts1_sent             = cpcie_xmtbyte_ts1_sent;
   assign xmtbyte_ts2_sent             = cpcie_xmtbyte_ts2_sent;
   assign xmtbyte_eidle_sent           = cpcie_xmtbyte_eidle_sent;
   assign xmtbyte_txelecidle           = cpcie_xmtbyte_txelecidle;
   assign xmtbyte_cmd_is_data          = cpcie_xmtbyte_cmd_is_data;
   assign xmtbyte_1024_ts_sent         = cpcie_xmtbyte_1024_ts_sent; 
   assign xmtbyte_spd_chg_sent         = cpcie_xmtbyte_spd_chg_sent;
   assign xmtbyte_fts_sent             = cpcie_xmtbyte_fts_sent;
   assign xmtbyte_idle_sent            = cpcie_xmtbyte_idle_sent;
   assign xmtbyte_skip_sent            = cpcie_xmtbyte_skip_sent;
 assign xmtbyte_txdata_dv            = cpcie_xmtbyte_txdata_dv;
 assign xmtbyte_txdata               = cpcie_xmtbyte_txdata;
 assign xmtbyte_txdatak_org          = cpcie_xmtbyte_txdatak;
 assign xmtbyte_link_in_training     = cpcie_xmtbyte_link_in_training;
 assign xmtbyte_txdetectrx_loopback  = cpcie_xmtbyte_txdetectrx_loopback;
 assign xmtbyte_txcompliance         = cpcie_xmtbyte_txcompliance;


assign xmlh_cmd_is_data              = xmtbyte_cmd_is_data;
assign b_xplh_xmlh_sp.cmd_is_data    = xmtbyte_cmd_is_data;
assign b_xplh_xmlh_sp.skip_pending   = cpcie_xmlh_skip_pending;
assign b_xplh_xmlh_sp.halt_in        = cpcie_xmlh_xdlh_halt;


//--------------------------------------
// Instance of xmlh_byte_xmt for PCIe
//--------------------------------------
xmlh_byte_xmt

#(INST) u_xmlh_byte_xmt(
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .ltssm_cxl_sh_bypass            (1'b0),
    .cxl_mode_enable                (1'b0),
    .ltssm_clear                    (ltssm_clear),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .smlh_ltssm_last                (smlh_ltssm_last),
    .current_data_rate              (current_data_rate_xmt),
    .ltssm_eidle_cnt                (ltssm_eidle_cnt[2:0]),
    .lpbk_master                    (ltssm_lpbk_master),
    .active_nb                      (active_nb),
    .cfg_mod_ts                     (cfg_mod_ts),
    .ltssm_lpbk_slave_lut           (ltssm_lpbk_slave_lut),
    .cfg_n_fts                      (muxed_n_fts),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_skip_interval              (cfg_skip_interval),
    .smlh_link_mode                 (smlh_link_mode),
    .ltssm_cmd_i                    (ltssm_cmd),
    .ltssm_xlinknum                 (ltssm_xlinknum),
    .ltssm_xk237_4lannum            (ltssm_xk237_4lannum),
    .ltssm_xk237_4lnknum            (ltssm_xk237_4lnknum),
    .ltssm_ts_cntrl                 (ltssm_ts_cntrl),
    .ltssm_mod_ts                   (ltssm_mod_ts),
    .ltssm_ts_alt_protocol          (ltssm_ts_alt_protocol),
    .ltssm_ts_alt_prot_info         (ltssm_ts_alt_prot_info),
    .ltssm_ts_auto_change           (ltssm_ts_auto_change),
    .latched_ts_nfts                (latched_ts_nfts),
    .xdlh_xmlh_stp_i                (b_xplh_xmlh_sp.stp),
    .xdlh_xmlh_sdp_i                (b_xplh_xmlh_sp.sdp),
    .xdlh_xmlh_eot_i                (b_xplh_xmlh_sp.eot),
    .next_xdlh_xmlh_eot_i           (b_xplh_xmlh_sp.next_eot),
    .next_xdlh_xmlh_stp_i           (b_xplh_xmlh_sp.next_stp),    
    .next_xdlh_xmlh_sdp_i           (b_xplh_xmlh_sp.next_sdp),    
    .xdlh_xmlh_pad_i                (b_xplh_xmlh_sp.pad),
    .xdlh_xmlh_data_i               (b_xplh_xmlh_sp.data_out),
    .ltssm_in_compliance            (smlh_ltssm_state==`S_POLL_COMPLIANCE),
    .ltssm_in_lpbk                  (ltssm_in_lpbk),
    .ltssm_lanes_active             (smlh_lanes_active),
    .lpbk_eq_lanes_active           (lpbk_eq_lanes_active),
    .smlh_no_turnoff_lanes          (smlh_no_turnoff_lanes),
    .xdlh_xmlh_pid                  ({NW{1'b0}}),
// ---------------------------------outputs ------------------------
    .xmtbyte_ts_pcnt                (cpcie_xmtbyte_ts_pcnt),
    .xmtbyte_ts_data_diff           (cpcie_xmtbyte_ts_data_diff),
    .xmtbyte_1024_ts_sent           (cpcie_xmtbyte_1024_ts_sent),
    .xmtbyte_spd_chg_sent           (cpcie_xmtbyte_spd_chg_sent),
    .xmtbyte_dis_link_sent          (cpcie_xmtbyte_dis_link_sent),
    .xmtbyte_txdata_dv              (cpcie_xmtbyte_txdata_dv),
    .xmtbyte_txdata                 (cpcie_xmtbyte_txdata),
    .xmtbyte_txdatak                (cpcie_xmtbyte_txdatak),
    .xmtbyte_ts1_sent               (cpcie_xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent               (cpcie_xmtbyte_ts2_sent),
    .xmtbyte_fts_sent               (cpcie_xmtbyte_fts_sent),
    .xmtbyte_idle_sent              (cpcie_xmtbyte_idle_sent),
    .xmtbyte_eidle_sent             (cpcie_xmtbyte_eidle_sent),
    .xmtbyte_skip_sent              (cpcie_xmtbyte_skip_sent),
    .xmtbyte_xdlh_halt              (cpcie_xmlh_xdlh_halt),
    .xmlh_skip_pending              (cpcie_xmlh_skip_pending),
    .xmtbyte_cmd_is_data            (cpcie_xmtbyte_cmd_is_data),
    .xmtbyte_link_in_training       (cpcie_xmtbyte_link_in_training),
    .xmtbyte_txelecidle             (cpcie_xmtbyte_txelecidle),
    .xmtbyte_g5_lpbk_deassert       (xmtbyte_g5_lpbk_deassert),
    .xmtbyte_txdetectrx_loopback    (cpcie_xmtbyte_txdetectrx_loopback),
    .xmlh_rst_flit_alignment        (xmlh_rst_flit_alignment),
    .xmtbyte_txcompliance           (cpcie_xmtbyte_txcompliance)
); // xmlh_byte_xmt




assign xmtbyte_txdatak = xmtbyte_txdatak_org ;

// Scramble logic
//CALC_PARITY_BEFORE_SCRAMBLE=0 denotes SKP parity calculation done after scrambling in Tx side
scramble
 #(.INST(INST), .REGOUT(`CX_XMLH_SCRAMBLE_REGOUT), .GEN3_REGIN(`CX_XMLH_GEN3_SCRAMBLE_REGIN), .GEN3_REGOUT(`CX_XMLH_GEN3_SCRAMBLE_REGOUT), .CALC_PARITY_BEFORE_SCRAMBLE(0), .SKIP_ALIGN(NB>=8)) u_scramble (
// ---- inputs ---------------
    .core_rst_n                     (core_rst_n),
    .core_clk                       (core_clk),
    .cfg_elastic_buffer_mode        (1'b0),
    .scrambler_disable              (smlh_scrambler_disable | xmtbyte_link_in_training),
    .data_dv                        ({NL{xmtbyte_txdata_dv}}),
    .data                           (xmtbyte_txdata),
    .datak                          (xmtbyte_txdatak),
    .error                          ({NL*NB{1'b0}}),
    .rxskipremoved                  ({NL{1'b0}}),
    .active_nb                      (active_nb),
    .aligned                        ({NL{1'b1}}), //gates: must revisit for first EIEOS occuring in core
    .latched_smlh_link_up           (latched_smlh_link_up),
    .latched_flip_ctrl              (latched_flip_ctrl),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),
    .lanes_active                   (power_saving_lanes_active),
    .deskew_ds_g12                  ( {NL{1'b0}} ),

// ---- outputs ---------------
    .scramble_data_dv               (scramble_data_dv),
    .scramble_data                  (scramble_data_org),
    .scramble_aligned               (),
    .scramble_data_comma            (),
    .scramble_data_skip             (),
    .scramble_data_skprm            (),
    .scramble_datak                 (scramble_datak),
    .scramble_error                 (scramble_error)
); // scramble

assign scramble_data = scramble_data_org ;

assign reversed_data  = scramble_data;
assign reversed_datak = scramble_datak;
assign reversed_error = scramble_error;

//Tx pipe
wire ltssm_in_lpbk_exit_timeout = smlh_ltssm_state == `S_LPBK_EXIT_TIMEOUT;
xmlh_pipe

#(INST) u_xmlh_pipe(
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_link_capable               (cfg_link_capable),
    .txdata                         (reversed_data),
    .txdatak                        (reversed_datak),
    .txerror                        (reversed_error),
    .txdetectrx_loopback            (xmtbyte_txdetectrx_loopback),
    .txelecidle                     (xmtbyte_txelecidle),
    .tx_g5_lpbk_deassert            (xmtbyte_g5_lpbk_deassert),
    .txcompliance                   (xmtbyte_txcompliance),
    .ltssm_lpbk_slave_lut           (ltssm_lpbk_slave_lut),
    .ltssm_in_lpbk_exit_timeout     (ltssm_in_lpbk_exit_timeout),
    .ltssm_in_lpbk                  (ltssm_in_lpbk),
    .ltssm_powerdown                (ltssm_powerdown),
    .phy_mac_phystatus              (phy_mac_phystatus),

    .xpipe_txdata                   (mac_phy_txdata),
    .xpipe_txdatak                  (mac_phy_txdatak),
    .xpipe_txdetectrx_loopback      (mac_phy_txdetectrx_loopback),
    .xpipe_txelecidle               (mac_phy_txelecidle),
    .xpipe_txcompliance             (mac_phy_txcompliance),
    .xpipe_powerdown                (xpipe_powerdown),
    .xpipe_phystatus                (xpipe_phystatus)
); // xmlh_pipe


endmodule
