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
// ---    $DateTime: 2020/10/16 15:45:59 $
// ---    $Revision: #44 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_byte_xmt.sv#44 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit MAC Layer handler Byte Transmitter
// -----------------------------------------------------------------------------
// --- Terminology
// --- chunk: The amount of data that can be transmitted by all active lanes in one clock cycle
// --- slice: The amount of data that can be transmitted by one lane in one clock cycle
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xmlh_byte_xmt (
    core_clk,
    core_rst_n,

    ltssm_cxl_sh_bypass, // SyncHeader_Bypass
    cxl_mode_enable,
    cfg_fast_link_mode,
    ltssm_clear,
    smlh_ltssm_state,
    smlh_ltssm_last,
    ltssm_lpbk_slave_lut,
    cfg_n_fts,
    cfg_skip_interval,
    cfg_ext_synch,
    cfg_mod_ts,
    smlh_link_mode,
    ltssm_cmd_i,
    ltssm_xlinknum,
    ltssm_xk237_4lannum,
    ltssm_xk237_4lnknum,
    ltssm_ts_cntrl,
    ltssm_mod_ts,
    ltssm_ts_alt_protocol,
    ltssm_ts_alt_prot_info,
    ltssm_ts_auto_change,
    ltssm_in_lpbk,
    ltssm_lanes_active,
    lpbk_eq_lanes_active,
    smlh_no_turnoff_lanes,
    ltssm_eidle_cnt,
    latched_ts_nfts,

    xdlh_xmlh_stp_i,
    xdlh_xmlh_sdp_i,
    xdlh_xmlh_eot_i,
    next_xdlh_xmlh_eot_i,
    next_xdlh_xmlh_stp_i,
    next_xdlh_xmlh_sdp_i,
    xdlh_xmlh_pad_i,
    xdlh_xmlh_data_i,
    ltssm_in_compliance,

    active_nb,
    current_data_rate,
    lpbk_master,
    xdlh_xmlh_pid,
    // ---------------------------------outputs ------------------------
    xmtbyte_ts_pcnt,
    xmtbyte_ts_data_diff,
    xmtbyte_1024_ts_sent,
    xmtbyte_spd_chg_sent,
    xmtbyte_dis_link_sent,
    xmtbyte_txdata_dv,
    xmtbyte_txdata,
    xmtbyte_txdatak,
    xmtbyte_txelecidle,
    xmtbyte_g5_lpbk_deassert,
    xmtbyte_txdetectrx_loopback,

    xmtbyte_xdlh_halt,
    xmlh_skip_pending,
    xmtbyte_cmd_is_data,

    xmtbyte_ts1_sent,
    xmtbyte_ts2_sent,
    xmtbyte_fts_sent,
    xmtbyte_idle_sent,
    xmtbyte_eidle_sent,
    xmtbyte_skip_sent,
    xmtbyte_link_in_training,
    xmlh_rst_flit_alignment,
    xmtbyte_txcompliance
);
parameter INST          = 0;                        // The uniquifying parameter for each port logic instance.
parameter NL            = `CX_NL;                   // Max number of lanes supported
parameter NB            = `CX_NB;                   // Number of symbols (bytes) per clock cycle
parameter NBK           = `CX_NBK;                  // Number of symbols (bytes) per clock cycle for datak
parameter NW            = `CX_PL_NW;                // Number of 32-bit dwords handled by the datapath each clock.
parameter DW            = `CX_PL_DW;                // Width of datapath in bits.
parameter NBIT          = `CX_NB * 8;               // Number of bits per lane
parameter NBYTE         = `CX_PL_NW * 4;            // The number of bytes in CX_DW
parameter LOG2NBYTE     = `CX_LOGBASE2(NBYTE);      // log2 number of bytes in CX_DW
parameter TP            = `TP;                      // Clock to Q delay (simulator insurance)
parameter TIMER_BITS    = 11;
parameter TX_PSET_WD    = 4;                        // preset bit width
parameter EIEOS_MASK_LOGIC_ENABLE = 0;              // set to 1 if you want to go back to per lane mechanism
parameter TS1_NUM = `GEN3_TS1_NUM_FOR_RESET_EIEOS;  // <65535 for test only. real is default 65535
parameter AW            = `CX_ANB_WD;               // Width of the active number of bytes

localparam EQTS_WD      = 32;                       // Number of bits of Per Lane Equalization Information
localparam SLICE_WD     = (NW>8) ? LOG2NBYTE : 5;   // scale for 512b and higher widths, hardcoded for lower widths for backward compatibility


// =============================================================================
// State Parameters
// =============================================================================
parameter /* VCS enum enum_xbyte_curnt_state */
          S_IDLE                =   4'h0,
          S_EIDLE               =   4'h1,
          S_XMT_EIDLE           =   4'h2,
          S_FTS                 =   4'h3,
          S_TS                  =   4'h4,
          S_SKIP                =   4'h5,
          S_CMP                 =   4'h6,
          S_XPKT_WAIT4_START    =   4'h7,
          S_XPKT_WAIT4_STOP     =   4'h8;

// =============================================================================
// input IO Declarations
// =============================================================================
input                   core_clk;
input                   core_rst_n;

input                   ltssm_cxl_sh_bypass;        // SyncHeader_Bypass
input                   cxl_mode_enable;            // Indicates whether the link should operate in CXL or PCIe mode
input                   cfg_fast_link_mode;
input                   ltssm_clear;                // used to clear persistency count when a ltssm state transition
input   [5:0]           smlh_ltssm_state;           // for debug
input   [5:0]           smlh_ltssm_last;            // last ltssm state
input   [NL-1:0]        ltssm_lpbk_slave_lut;       // lane under test for lpbk slave
input   [7:0]           cfg_n_fts;                  // 8bits bus to specify the number of FTS we wish to receive for our receiver
input   [10:0]          cfg_skip_interval;          // the number of symbol times between skip requests
input                   cfg_ext_synch;              // Extended synch for N_FTS configured in CDM
input                   cfg_mod_ts;                 // modified ts format
input   [5:0]           smlh_link_mode;             // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
input   [3:0]           ltssm_cmd_i;                // encoded command to notify transmitter of the proper action based on LTSSM states
input   [7:0]           ltssm_xlinknum;             // 8bits indicate link number to be inserted in training sequence
input   [NL-1:0]        ltssm_xk237_4lnknum;        // 1 bit per lane, 1 -- K237, 0 -- send lane number
input   [NL-1:0]        ltssm_xk237_4lannum;        // 1 bit per lane, 1 -- K237, 0 -- send link number
input   [7:0]           ltssm_ts_cntrl;             // training sequence control
input                   ltssm_mod_ts;               // Tx modified TS
input                   ltssm_ts_alt_protocol;      // Alternate protocol
input   [55:0]          ltssm_ts_alt_prot_info;     // sym14-8 for AP
input                   ltssm_ts_auto_change;       // autonomous change/upconfig capable/select de-emphasis bit.  bit 6 of the data rate identifier field.
input   [7:0]           latched_ts_nfts;            // latched number of fast training sequence number from TS ordered set of receiver
input                   ltssm_in_lpbk;              // LTSSM in Loopback.Active state
input   [2:0]           ltssm_eidle_cnt;            // 4 bits, indicates how many EIOS sets to send before returning xmtbyte_eidle_sent.  0=1 EIOS, 1=2 EIOS, etc.
input   [NL-1 :0]       ltssm_lanes_active;         // LTSSM latched lanes that are active based on the link negotiation
input   [NL-1:0]        lpbk_eq_lanes_active;       // One active lane from the cfg_lane_under_test
input   [NL-1 :0]       smlh_no_turnoff_lanes;      // No turnoff lanes

input   [NW-1 :0]       xdlh_xmlh_stp_i;            // 1 bit per dword, indicates which dword is stp
input   [NW-1 :0]       xdlh_xmlh_sdp_i;            // 1 bit per dword, indicates which dword is sdp
input   [NW-1 :0]       xdlh_xmlh_eot_i;            // 1 bit per dword, indicates which dword is eot
input   [NW-1 :0]       next_xdlh_xmlh_eot_i;       // 1 bit per dword, indicates which dword is eot
input   [NW-1 :0]       xdlh_xmlh_pad_i;            // 1 bit per dword, indicates which dword is pad
input   [NW-1 :0]       next_xdlh_xmlh_stp_i;
input   [NW-1 :0]       next_xdlh_xmlh_sdp_i;
input   [DW-1:0]        xdlh_xmlh_data_i;           // Data from the Data Link Layer to transmit
input                   ltssm_in_compliance;        // LTSSM in polling.compliance state

input   [2:0]           current_data_rate;          // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
input                   lpbk_master;                // indicates that the ltssm is the loopback master
input   [AW-1:0]        active_nb;                  // active number of symbols per lane per clock. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
input   [NW-1:0]        xdlh_xmlh_pid;               // PID location per DW on xdlh_xmlh_data[511:0]

// =============================================================================
// output IO Declarations
// =============================================================================
output  [10:0]          xmtbyte_ts_pcnt;            // transmit ts persistency count
output                  xmtbyte_ts_data_diff;       // current ts data different from previous
output                  xmtbyte_1024_ts_sent;       // 1024 ts sent in a state
output                  xmtbyte_spd_chg_sent;       // speed_change bit sent
output                  xmtbyte_dis_link_sent;      // disable link bit set in Tx TS
output                  xmtbyte_txdata_dv;          // Data Valid, gen1/gen2: always 1, gen3: 0 for one cycle every 4*active_nb blocks
output  [(NB*8*NL)-1:0] xmtbyte_txdata;             // Transmit data to the phy
output  [(NBK*NL)-1:0]  xmtbyte_txdatak;            // Indicates which bytes are k characters.  1 bit per byte of xmtbyte_txdata

output                  xmtbyte_ts1_sent;           // Indicates 1 TS1 ordered set has been sent based on LTSSM's command
output                  xmtbyte_ts2_sent;           // Indicates 1 TS2 ordered set has been sent based on LTSSM's command
output                  xmtbyte_fts_sent;           // Indicates all fast training sequences have been sent based on LTSSM's command
output                  xmtbyte_idle_sent;          // Indicates 1 idle has been sent based on LTSSM's command
output                  xmtbyte_eidle_sent;         // Indicates 1 eidle ordered set has been sent based on LTSSM's command
output                  xmtbyte_skip_sent;          // Indicates 1 skip ordered set has been sent based on LTSSM's command
output                  xmtbyte_xdlh_halt;          // Halt the flow of data from the xdlh
output                  xmlh_skip_pending;          // XMLH Skip pending to XDLH TLP GEN
output                  xmtbyte_cmd_is_data;        // xmtbyte state machine is waiting for packet start or packet end
output                  xmtbyte_link_in_training;   // Indicates byte machine is sending training sequences or compliance pattern

output  [NL-1:0]        xmtbyte_txelecidle;         // Lanes to put in electrical idle
output                  xmtbyte_g5_lpbk_deassert;   // deassert loopback signal at gen5 rate in LPBK_EXIT_TIMEOUT
output                  xmtbyte_txdetectrx_loopback;// Indicates detectrx or loopback mode
output  [NL-1:0]        xmtbyte_txcompliance;       // Set negative running disparity (for compliance pattern)
output                  xmlh_rst_flit_alignment;

// =============================================================================
// Regs & Wires
// =============================================================================
// Register outputs
wire                    pid_rcvd_pulse;
wire                    skp_win;
reg                     skp_win_d;
wire                    eie_win;
wire                    eid_win;
wire                    eie_win_i;
wire                    eid_win_i;
reg                     eie_win_d;
reg                     eid_win_d;
reg  [11:0]             pid_count;   //count PID
reg  [11:0]             pid_count_i; //count PID
wire                    xmlh_rst_flit_alignment;
reg                     null_ieds_for_skip_sent_d;
wire                    null_ieds_for_skip_sent;
wire                    null_ieds_en;
wire                    ds_null_ieds; // downsized linkwidth null ieds
wire                    cxl_x1;   // 
wire                    cxl_x1_sris;   // 
wire                    cxl_x1_no_sh_bp;   // 
wire                    xmtbyte_xdlh_halt;
reg                     xmtbyte_xdlh_halt_d;
reg                     flit_null_d_r;
wire                    latched_flit_null_d;
wire                    pid_rcvd   = |xdlh_xmlh_pid & ~xmtbyte_xdlh_halt;
wire                    pid_rcvd_d = |xdlh_xmlh_pid & ~xmtbyte_xdlh_halt_d;
wire                    flit_null_i;
wire                    flit_null_d;
wire                    cmd_is_data;                    // The current cmd is data
wire                    eds_on;                         // convert the whole null flit to iEDS for cxl including narrow linkwidth
wire                    eds_inserted;                   // Indicates EDS token has been inserted into data block
reg                     cxl_x1_sris_null_for_ieds;      // detect x1 null flit for ieds
wire                    cxl_x1_sris_null_ieds_halt_n;
reg                     cxl_x1_no_sh_bp_null_for_ieds;    // detect x1 null flit for ieds
wire                    cxl_x1_no_sh_bp_null_ieds_halt_n;
wire                    cxl_x1_nsris_nshb_pid4000_i = (cxl_mode_enable & active_nb == 8 & smlh_link_mode == 1 & ltssm_cxl_sh_bypass == 0 & xdlh_xmlh_pid == 16'h4000);
wire                    cxl_x1_ns_nsb_p4000; // no syncheaderbypass, no sris, 8sx1, pid = 4000h
assign                  flit_null_i         = 1'b0;
assign                  flit_null_d         = 1'b0;
assign                  ds_null_ieds        = 1'b0;
assign                  null_ieds_en        = 1'b0;
assign                  cxl_x1_ns_nsb_p4000 = 1'b0;
assign                  cxl_x1              = 1'b0;
assign                  cxl_x1_sris         = 1'b0;
assign                  cxl_x1_no_sh_bp     = 1'b0;
wire                    ltssm_cmd_data      = ltssm_cmd_i == `NORM | ltssm_cmd_i == `SEND_IDLE;
wire    [NW-1 :0]       xdlh_xmlh_stp       = xdlh_xmlh_stp_i; // 1 bit per dword, indicates which dword is stp
wire    [NW-1 :0]       xdlh_xmlh_sdp       = xdlh_xmlh_sdp_i; // 1 bit per dword, indicates which dword is sdp
wire    [NW-1 :0]       xdlh_xmlh_eot       = xdlh_xmlh_eot_i; // 1 bit per dword, indicates which dword is eot, no eot for CXL because Layer2 sends null flits if no pkts
wire    [NW-1 :0]       next_xdlh_xmlh_eot  = next_xdlh_xmlh_eot_i; // 1 bit per dword, indicates which dword is eot
wire    [NW-1 :0]       xdlh_xmlh_pad       = xdlh_xmlh_pad_i;      // 1 bit per dword, indicates which dword is pad
wire    [NW-1 :0]       next_xdlh_xmlh_stp  = next_xdlh_xmlh_stp_i;
wire    [NW-1 :0]       next_xdlh_xmlh_sdp  = next_xdlh_xmlh_sdp_i;
wire                    ieds_on             = ltssm_cxl_sh_bypass ? 1'b1 : eds_on;
wire    [DW-1:0]        xdlh_xmlh_data      = xdlh_xmlh_data_i;
reg     [(NB*8*NL)-1:0] int_xmtbyte_txdata;
reg     [(NBK*NL)-1:0]  int_xmtbyte_txdatak;

wire                    os_sent_d;
wire                    skip_os_sent_d;
wire                    xmtbyte_ts1_sent;
reg                     ts1_sent_d;
wire                    xmtbyte_ts2_sent;
wire                    xmtbyte_fts_sent;
reg                     xmtbyte_idle_sent;
wire                    xmtbyte_eidle_sent;
wire                    xmtbyte_skip_sent;
reg                     xmtbyte_skip_sent_d;
reg                     xmtbyte_link_in_training;
wire                    xmlh_pat_fts_sent;
wire                    ltssm_in_lpbk_i;
wire                    ltssm_in_lpbk_g3;
reg                     xmtbyte_txdetectrx_loopback;
wire    [NL-1:0]        xmtbyte_txcompliance;
wire    [NL-1:0]        xmtbyte_txcompliance_g12;
wire    [NL-1:0]        xmtbyte_txcompliance_g3;
wire            xmlh_skip_pending;

// =============================================================================
// Internal signals
// =============================================================================
wire                    xmlh_pat_eidle_sent;
reg     [NL-1:0]        xmtbyte_txcompliance_cmp_i;
wire    [NL-1:0]        xmtbyte_txcompliance_turnoff_i;
wire    [NL-1:0]        xmtbyte_txcompliance_i;
wire                    os_start;                       // Indicate the start of an ordered set
wire                    os_end;                         // Indicate the start of an ordered set
//reg                     xmtbyte_link_in_training_i;
wire    [4:0]           int_active_nb;                  // Internal active_nb
reg     [3:0]           next_cmd;                       // the next command to execute

wire                    int_eidle_i;
reg                     int_eidle;
reg     [NL-1:0]        int_lanes_active;
reg     [5:0]           int_link_mode;                  // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
wire    [4:0]           active_lane_cnt;                // the number of active lanes 1=1 lane, 2=2 lanes, etc.
                                                        // Not used in 1s mode so it will be zero when 16 lanes are active

reg     [SLICE_WD:0]    data_cycles;                    // the number of cycles needed to send one CX_DW of data with
                                                        // the current active_nb and active_lanes
wire                    last_chunk;

reg    [TIMER_BITS-1:0] skip_timer;                     // Skip timer for 2.5 GT/s and 5 GT/s data rate

wire                    pkt_in_progress;
wire                    pkt_in_progress_i;
reg                     latched_pkt_in_progress;
wire                    valid_pkt_in_progress;
wire                    valid_pkt_in_progress_i;

reg     [7:0]           cmp_dly_lane;                   // Select which lane gets delayed compliance pattern.  One hot for lanes 0-7, lanes above replicate 0-7
wire    [15:0]          int_cmp_dly_lane;               // Select which lane gets delayed compliance pattern.  One hot for lanes 0-7, lanes above replicate 0-7
reg     [(NL*7)-1:0]    err_cnt;                        // Per lane receive error count for compliance

reg     [NL-1:0]        pattern_lock;                   // Per lane compliance pattern lock
wire    [3:0]           insert_eqts_info;               // Replace Symbol 6-9 of current TS with Equalization Information
wire    [15:4]          insert_s15_4;                   // Replace Symbol sym15 - 4 for Mod TS Format
wire                    insert_s6;                      // Replace Symbol sym6 for Modified TS Format
wire    [NL*EQTS_WD-1:0]int_eqts_info;                  // Per Lane Equalization Information to be inserted in Symbol 6-9 of current TS
wire    [NL-1:0]        int_mask_eieos;                 // Per lane masking of EIEOS Identifier




// ==================
// Internal Data Path
// ==================
reg     [NBYTE-1:0]     xdlh_xmlh_datak;                // kchar indicator from xdlh.  Combination of xdlh_xmlh_stp, sdp, eot, pad

wire    [(NB*8*NL)-1:0] cmp_data;                       // compliance data
wire    [(NBK*NL)-1:0]  cmp_datak;                      // compliance datak

reg     [DW-1:0]        pad_data;                       // xdlh data with pad symbols added
wire    [31:0]          int_pad_data;                   // pad data added to xdlh data based on current_data_rate

wire    [DW-1:0]        int_xdlh_data;                  // one chunk of combined xdlh or compliance data
wire    [NBYTE-1:0]     int_xdlh_datak;                 // k chars associated with int_xdlh_data

wire    [(NB*8*NL)-1:0] int_xmt_data;                   // one chunk of data in lane slices
// LMD: Undriven net Range
// LJ: All nets are driven
// leda NTL_CON12 off
wire    [(NBK*NL)-1:0]   int_xmt_datak;                 // k chars associated with int_xmt_data
// leda NTL_CON12 on

wire    [(NB*8*NL)-1:0] xmt_data;                       // one chunk of data in lane slices (after optional flop)
wire    [(NBK*NL)-1:0]  xmt_datak;                      // k chars associated with xmt_data

wire    [(NB*8*NL)-1:0] int_pat_data;                   // one chunk of pattern data in lane slices with link/lane # replaced
wire    [(NB*8*NL)-1:0] i_pat_data;                     // one chunk of pattern data in lane slices with link/lane # replaced
wire    [(NBK*NL)-1:0]  int_pat_datak;                  // k chars associated with pat_data

reg     [NL*8-1:0]      latched_parity;                 // even parity until previous clock
wire    [(NB*8*NL)-1:0] pat_data;                       // one chunk of pattern data in lane slices with link/lane # replaced
wire    [(NBK*NL)-1:0]  pat_datak;                      // k chars associated with pat_data


wire    [NL-1:0]        xmtbyte_txelecidle_i;
wire    [NL-1:0]        xmtbyte_txelecidle_g12;
wire    [NL-1:0]        xmtbyte_txelecidle_g3;


wire                    xmlh_pat_ack;                   // pattern command acknowledge
wire                    xmlh_pat_dv;                    // Data valid from the pattern generator
reg                     xmlh_pat_dv_d;
wire    [NBIT-1:0]      xmlh_pat_data;                  // Data from the pattern generator
wire    [NBK-1:0]       xmlh_pat_datak;                 // Data K-char indicator from the pattern generator
wire                    xmlh_pat_linkloc;               // Indicates the current data contains the link # field. Its location can be inferred from active_nb
wire                    xmlh_pat_laneloc;               // Indicates the current data contains the lane # field. Its location can be inferred from active_nb
wire    [15:4]          xmlh_pat_s15_4loc;              // current data with [15] = sym15, ..., [4] = sym4
wire                    xmlh_cmp_errloc;                // Indicates the current data contains the error count field. Its location can be inferred from active_nb

wire    [NBIT-1:0]      xmlh_dly_cmp_data;              // Delayed compliance Data
wire    [NBK-1:0]       xmlh_dly_cmp_datak;             // Delayed compliance K char
wire                    xmlh_dly_cmp_errloc;            // Indicates the current data contains the error count field. Its location can be inferred from active_nb

reg     [SLICE_WD-1:0]  chunk_cnt;                      // chunk counter
wire    [SLICE_WD-1:0]  chunk_offset;
wire    [AW-3:0]        active_nb_shift;                // Used to shift certain values according to S-ness. 1s = 0, 2s = 1, 4s = 2, 8s = 3 , 16s = 4

reg                     curnt_compliance_finished;


reg                     xmtbyte_eidle_sent_d;
reg     [12:0]          fts_sent_cnt;
wire                    int_xmt_nfts_done;
wire                    cmd_is_fts_send;
reg                     dlyd_cmd_is_fts_send;
reg                     xmtfts_req;
wire                    fts_skip_req;                   // indicates the need to send the post FTS Skip OS
reg                     latched_fts_skip_req;
reg     [3:0]           next_pat;                       // encoded command from the xmlh_byte_xmt to select a pattern to generate

wire                    short_os_pat;                   // Indicates the OS pattern indicated by next_pat is a 4 symbol pattern
wire                    short_os_4s;                    // Indicates a 1 cycle OS when active_nb[2] 4S mode
wire                    load_pat_i;
wire                    load_pat;
wire                    load_pat_easy;
wire                    next_is_pat;                    // the next cmd is a os pattern (handled by this module)
wire                    state_halt;                     // halt that is driven by state in non pkt transmission state
wire                    data_halt;
reg                     latched_eidle_sent_cmd;
reg                     goto_xmt_eidle;

/* VCS state_vector xbyte_curnt_state enum enum_xbyte_curnt_state */
reg     [3:0]           xbyte_curnt_state;
reg     [3:0] /* VCS enum enum_xbyte_curnt_state */ xbyte_next_state;
wire                    os_sent;
wire                    skip_req;
wire                    skip_insert;
wire                    null_ieds_insert    = null_ieds_en & skip_insert;
wire                    null_ieds_req       = null_ieds_en & skip_req;
wire                    or_sdp;
wire                    or_stp;
wire                    or_eot;
wire                    valid_sdp;
reg     [2:0]           accumed_skips;
wire    [2:0]           prev_accumed_skips;
wire                    accumed_skips_is_0;
wire                    accumed_skips_is_not_0;
reg                     latched_int_xmt_nfts_done;
wire    [NW-1 :0]       int_xdlh_pad;

wire    [NW-1 :0]       xdlh_eot_or_pad;                // bitwise or of xdlh_xmlh_eot and xdlh_xmlh_pad
wire    [NW-1 :0]       xdlh_sp_or_pad;                 // bitwise or of xdlh_xmlh_sdp, xdlh_xmlh_stp, and xdlh_xmlh_pad
reg     [7:0]           latched_ts_cntrl;               // training sequence control
reg                     latched_mod_ts;
reg     [56-1:0]        latched_alt_prot_info;          // Alternate protocol info for sym14-8
reg                     latched_ts_alt_protocol;        // Alternate protocol
reg                     ltssm_ts_auto_change_d;
reg                     ltssm_ts_auto_change_r;
reg                     latched_ts_auto_change_i;
reg     [7:0]           int_xlinknum;                   // 8bits indicate link number to be inserted in training sequence
reg     [NL-1:0]        int_xk237_4lnknum;              // 1 bit per lane, 1 -- K237, 0 -- send lane number
reg     [NL-1:0]        int_xk237_4lannum;              // 1 bit per lane, 1 -- K237, 0 -- send link number
wire    [NL-1:0]        insert_linknum;
wire    [NL-1:0]        insert_lanenum;

wire                    cfg_compliance_sos;         // Send skips during compliance
assign cfg_compliance_sos = 1'b0;


wire                    xmtbyte_sds_sent;
wire                    xmtbyte_eidle_fts_idle_sds_sent;
wire                    xmtbyte_loe_2_ts1_ec_00b_sent;  // less or equal to 2 ts1s with ec==00b sent
reg     [10:0]          xmtbyte_ts_pcnt;
wire                    xmtbyte_ts_data_diff;           // current ts data is different from previous
reg     [10:0]          xmtbyte_ts_cnt;
reg     [3:0]           ts_sym_cnt;
wire                    xmtbyte_1024_ts_sent;
wire                    xmtbyte_spd_chg_sent;
wire                    xmtbyte_dis_link_sent;
reg                     ts_speed_change_sent;
reg                     ts_disable_link_sent;
reg     [NL*8*16-1:0]   latched_xmtbyte_txdata;         // a TS OS
reg                     xmtbyte_ints1;
reg                     xmtbyte_ints2;
reg                     xmtbyte_ints;
reg                     xmtbyte_ineieos;
reg                     xmtbyte_inskip;

wire    [3:0]           ltssm_cmd;

reg                     data_stream_window;   // only data stream in the window





always @( posedge core_clk or negedge core_rst_n ) begin : flit_null_d_r_PROC
    if ( ~core_rst_n )
        flit_null_d_r <= #TP 0;
    else if ( flit_null_d )
        flit_null_d_r <= #TP 1'b1;
    else if ( pid_rcvd_d || os_sent_d || xmtbyte_ts1_sent || xmtbyte_ts2_sent )
        flit_null_d_r <= #TP 0;
end // flit_null_d_r_PROC

assign latched_flit_null_d = 1'b0;


assign ltssm_cmd = ltssm_cmd_i;

//
//count TS sent
//
//SDS sent
assign xmtbyte_eidle_fts_idle_sds_sent = xmtbyte_fts_sent | xmtbyte_idle_sent | xmtbyte_eidle_sent;

//symbol count
always @( posedge core_clk or negedge core_rst_n ) begin : ts_sym_cnt_PROC
    if ( ~core_rst_n ) begin
        ts_sym_cnt <= #TP 0;
    end else if ( xmtbyte_ts1_sent || xmtbyte_ts2_sent ) begin
        ts_sym_cnt <= #TP 0;
    end else if ( ((ts_sym_cnt + 1) << active_nb_shift) >= 16 ) begin
        ts_sym_cnt <= #TP ts_sym_cnt;
    end else if ( xmtbyte_txdata_dv ) begin
        ts_sym_cnt <= #TP ts_sym_cnt + 1;
    end
end // ts_sym_cnt_PROC

//xmt is in ts1 transmission
always @( posedge core_clk or negedge core_rst_n ) begin : xmtbyte_ints1_PROC
    if ( ~core_rst_n ) begin
        xmtbyte_ints1 <= #TP 0;
    end else if ( xmtbyte_ts1_sent ) begin
        xmtbyte_ints1 <= #TP 1;
    end else if ( xmtbyte_eidle_fts_idle_sds_sent || xmtbyte_ts2_sent || xmtbyte_skip_sent ) begin
        xmtbyte_ints1 <= #TP 0;
    end
end // xmtbyte_ints1_PROC

//xmt is in ts2 transmission
always @( posedge core_clk or negedge core_rst_n ) begin : xmtbyte_ints2_PROC
    if ( ~core_rst_n ) begin
        xmtbyte_ints2 <= #TP 0;
    end else if ( xmtbyte_ts2_sent ) begin
        xmtbyte_ints2 <= #TP 1;
    end else if ( xmtbyte_eidle_fts_idle_sds_sent || xmtbyte_ts1_sent || xmtbyte_skip_sent ) begin
        xmtbyte_ints2 <= #TP 0;
    end
end // xmtbyte_ints2_PROC

//xmt is in ts transmission
always @( * ) begin : xmtbyte_ints_PROC
    xmtbyte_ints = 0;

    xmtbyte_ints = xmtbyte_ints1 | xmtbyte_ints2;
end //xmtbyte_ints_PROC

//xmt is in skip transmission
always @( posedge core_clk or negedge core_rst_n ) begin : xmtbyte_inskip_PROC
    if ( ~core_rst_n ) begin
        xmtbyte_inskip <= #TP 0;
    end else if ( xmtbyte_skip_sent ) begin
        xmtbyte_inskip <= #TP 1;
    end else if ( xmtbyte_ts1_sent || xmtbyte_ts2_sent || xmtbyte_eidle_fts_idle_sds_sent ) begin
        xmtbyte_inskip <= #TP 0;
    end
end // xmtbyte_inskip_PROC


//latch transmit TS data in order to compare with the next transmit TS data
always @( posedge core_clk or negedge core_rst_n ) begin : latched_xmtbyte_txdata_PROC
    if ( ~core_rst_n ) begin
        latched_xmtbyte_txdata <= #TP 0;
    end else if ( ~(xmtbyte_ints || xmtbyte_inskip) ) begin
        latched_xmtbyte_txdata <= #TP 0;
    end else if ( xmtbyte_ints && xmtbyte_txdata_dv ) begin
        // LMD: Range index out of bound
        // LJ: latched_xmtbyte_txdata is not out of index bound because ts_sym_cnt is reset to 0 whenever xmtbyte_ts_sent in xmtbyte_ints window
        // leda E267 off
        // spyglass disable_block ImproperRangeIndex-ML
        // SMD: Possible discrepancy in the range index or slice of an array
        // SJ: Rule will flag violation if number of bits required to cover index doesn't matches with log2N. In this code, this signal is not out of index bound. So, disable SpyGlass from reporting this warning.
        latched_xmtbyte_txdata[ts_sym_cnt*NB*8*NL +: NB*8*NL] <= #TP xmtbyte_txdata[0 +: NB*8*NL];
        // leda E267 on
        // spyglass enable_block ImproperRangeIndex-ML
    end
end // latched_xmtbyte_txdata_PROC

//persistency count
//note that xmtbyte_ts1_sent/xmtbyte_ts2_sent is a pulse and always one cycle earlier than the real ts data sent out

// LMD: Range index out of bound
// LJ: latched_xmtbyte_txdata is not out of index bound because ts_sym_cnt is reset to 0 whenever xmtbyte_ts_sent in xmtbyte_ints window
// leda E267 off
// spyglass disable_block ImproperRangeIndex-ML
// SMD: Possible discrepancy in the range index or slice of an array
// SJ: Rule will flag violation if number of bits required to cover index doesn't matches with log2N. In this code, this signal is not out of index bound. So, disable SpyGlass from reporting this warning.
assign xmtbyte_ts_data_diff = xmtbyte_txdata_dv && xmtbyte_ints && (xmtbyte_txdata[0 +: NB*8*NL] != latched_xmtbyte_txdata[ts_sym_cnt*NB*8*NL +: NB*8*NL]);
// leda E267 on
// spyglass enable_block ImproperRangeIndex-ML

always @( posedge core_clk or negedge core_rst_n ) begin : xmtbyte_pcnt_PROC
    if ( ~core_rst_n ) begin
        xmtbyte_ts_pcnt <= #TP 0;
    end else if ( ltssm_clear ) begin //clear pcnt if state transition
        if ( xmtbyte_ts1_sent || xmtbyte_ts2_sent ) begin
            xmtbyte_ts_pcnt <= #TP 1;
        end else begin
            xmtbyte_ts_pcnt <= #TP 0;
        end
    end else if ( (~xmtbyte_txdata_dv && ~(xmtbyte_ts1_sent || xmtbyte_ts2_sent || xmtbyte_skip_sent )) ||
                  xmtbyte_eidle_fts_idle_sds_sent ) begin
        //~txdata_dv with nothing going to sent, fts sent, idle sent, eios sent, sds sent. ~xmtbyte_txdata_dv is always at the end of a block for gen3/4
        xmtbyte_ts_pcnt <= #TP 0;
    end else if ( xmtbyte_ts_data_diff ) begin
        //reset if current transmitting data is different from previous in ts window
        if ( xmtbyte_ts1_sent || xmtbyte_ts2_sent ) begin //set to 2 if it is the last cycle of the TS
            xmtbyte_ts_pcnt <= #TP 2;
        end else begin
            xmtbyte_ts_pcnt <= #TP 1; //set to 1 if it is in the mid of the TS
        end
    end else if ( &xmtbyte_ts_pcnt != 1'b1 ) begin
        if ( xmtbyte_ts1_sent || xmtbyte_ts2_sent ) begin
            xmtbyte_ts_pcnt <= #TP xmtbyte_ts_pcnt + 1;
        end
    end
end // xmtbyte_pcnt_PROC

//xmtbyte_ts_cnt is purely a ts1/2 sent count. No TS content comparison to reset the count
always @( posedge core_clk or negedge core_rst_n ) begin : xmtbyte_cnt_PROC
    if ( ~core_rst_n ) begin
        xmtbyte_ts_cnt <= #TP 0;
    end else if ( ltssm_clear ) begin //clear count if state transition
        if ( xmtbyte_ts1_sent || xmtbyte_ts2_sent ) begin
            xmtbyte_ts_cnt <= #TP 1;
        end else begin
            xmtbyte_ts_cnt <= #TP 0;
        end
    end else if ( (xmtbyte_ints1 && xmtbyte_ts2_sent) || (xmtbyte_ints2 && xmtbyte_ts1_sent) ) begin
        xmtbyte_ts_cnt <= #TP 1; //set to 1 if there is a ts1 -> ts2 or ts2 -> ts1 transition
    end else if ( &xmtbyte_ts_cnt != 1'b1 ) begin
        if ( xmtbyte_ts1_sent || xmtbyte_ts2_sent ) begin
            xmtbyte_ts_cnt <= #TP xmtbyte_ts_cnt + 1;
        end
    end
end // xmtbyte_cnt_PROC


localparam CNT_16 = 16 
;
localparam CNT_1024 = 1024 
;

 assign xmtbyte_1024_ts_sent           = (cfg_fast_link_mode & (xmtbyte_ts_cnt>=CNT_16)) | (~cfg_fast_link_mode & (xmtbyte_ts_cnt>=CNT_1024)); //for Polling.Active

always @( posedge core_clk or negedge core_rst_n ) begin : ts_speed_change_sent_PROC
    if ( ~core_rst_n ) begin
        ts_speed_change_sent <= #TP 0;
    end else if ( xmtbyte_ints && ((active_nb == 1 && ts_sym_cnt == 4) || (active_nb == 2 && ts_sym_cnt == 2) || (active_nb == 4 && ts_sym_cnt == 1)) ) begin
        ts_speed_change_sent <= #TP xmtbyte_txdata[7];
    end
end // ts_speed_change_sent_PROC

assign xmtbyte_spd_chg_sent = 0;

always @( posedge core_clk or negedge core_rst_n ) begin : ts_disable_link_sent_PROC
    if ( ~core_rst_n ) begin
        ts_disable_link_sent <= #TP 0;
    end else if ( xmtbyte_ints && active_nb == 1 && ts_sym_cnt == 5 ) begin
        ts_disable_link_sent <= #TP xmtbyte_txdata[1];
    end else if ( xmtbyte_ints && ((active_nb == 2 && ts_sym_cnt == 2) || (active_nb == 4 && ts_sym_cnt == 1)) ) begin
        ts_disable_link_sent <= #TP xmtbyte_txdata[9];
    end
end // ts_disable_link_sent_PROC

assign xmtbyte_dis_link_sent = ts_disable_link_sent;

//pcie_perf

wire eot_is_last;
wire sot_is_last;
wire sdp_is_last;

wire nw_gtr_2;
wire next_eot_is_last;
// =============================================================================

assign nw_gtr_2 = (NW > 2); // CX_PL_NW for layer1 is equal to CX_NW for layer2,3

assign  int_active_nb = `CX_NB;

assign  xmlh_skip_pending = skip_req & !eot_is_last;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        xmtbyte_txcompliance_cmp_i <= #TP 0;
    end else if ( ~ltssm_in_compliance ) begin // clear txcompliance_cmp for 1337818
        xmtbyte_txcompliance_cmp_i <= #TP 0; // clear txcompliance_cmp to not make txelecidle=1 and txcompliance=1 for 2 clocks
    end else begin
        xmtbyte_txcompliance_cmp_i <= #TP 
                                           {NL{(xbyte_curnt_state == S_CMP) && os_start}};
    end

assign xmtbyte_txcompliance_turnoff_i = ~(int_lanes_active | smlh_no_turnoff_lanes);

assign xmtbyte_txcompliance_i = (xmtbyte_txcompliance_cmp_i | xmtbyte_txcompliance_turnoff_i);

assign  cmd_is_data = ((xbyte_curnt_state == S_XPKT_WAIT4_START) || (xbyte_curnt_state == S_XPKT_WAIT4_STOP));
assign  xmtbyte_cmd_is_data = cmd_is_data;


assign  next_is_pat  = (xbyte_next_state == S_EIDLE)   || (xbyte_next_state == S_FTS)
                      || (xbyte_next_state == S_TS)
                      || (xbyte_next_state == S_SKIP) || (xbyte_next_state == S_CMP);

assign eds_on = 1'b0;

reg curnt_is_short;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
         curnt_is_short    <= #TP 1'b0;
    else if (load_pat)
         curnt_is_short    <= #TP short_os_4s;


assign  load_pat_i  =
                      ( os_end || (short_os_4s && curnt_is_short));


assign  load_pat    = next_is_pat && ( load_pat_i);
// Improved timing closure: use the ltssm_cmd insted of the next_is_pat(xbyte_next_state)
assign  load_pat_easy =                        load_pat
                        ;


assign  short_os_pat= (next_pat == `SEND_SKP) || (next_pat == `SEND_N_FTS);

assign  short_os_4s = short_os_pat &&
                      int_active_nb[2];

// combine xdlh_xmlh special symbol signals into a per byte kchar signal
assign  xdlh_eot_or_pad         = xdlh_xmlh_eot | int_xdlh_pad;
assign  xdlh_sp_or_pad          = xdlh_xmlh_sdp | xdlh_xmlh_stp | int_xdlh_pad;


always @(*) begin : XDLH_PAD
    integer i;
    for(i = 0; i < NW; i = i + 1) begin
        xdlh_xmlh_datak[i*4 +: 4] =
            {xdlh_eot_or_pad[i], int_xdlh_pad[i],
            int_xdlh_pad[i], xdlh_sp_or_pad[i]};
    end
end



assign  or_sdp                  = |xdlh_xmlh_sdp;
assign  or_stp                  = |xdlh_xmlh_stp;
assign  or_eot                  = |(xdlh_xmlh_eot);
assign  int_xdlh_pad            = |int_link_mode[4:3] ? xdlh_xmlh_pad : {NW{1'b0}};


// pcie_perf
assign eot_is_last = (xdlh_xmlh_stp < xdlh_xmlh_eot) & (xdlh_xmlh_sdp < xdlh_xmlh_eot);
assign next_eot_is_last = (next_xdlh_xmlh_eot > next_xdlh_xmlh_stp) & (next_xdlh_xmlh_eot > next_xdlh_xmlh_sdp);
assign sot_is_last = (xdlh_xmlh_stp > xdlh_xmlh_eot);
assign sdp_is_last = (xdlh_xmlh_sdp > xdlh_xmlh_eot);

always @(posedge core_clk or negedge core_rst_n)
begin : eidle_sent_cmd_proc
    if (!core_rst_n)
        latched_eidle_sent_cmd      <= #TP 1'b0;
    else if ((xmtbyte_eidle_sent & ~(ltssm_cmd == `SEND_EIDLE)) || (ltssm_cmd == `XMT_IN_EIDLE))
        latched_eidle_sent_cmd      <= #TP 1'b0;
    else if (ltssm_cmd == `SEND_EIDLE)
        latched_eidle_sent_cmd      <= #TP 1'b1;
end


// figure out the next command here so we don't have to do it in each state of the state machine
always @(*)
begin : next_cmd_proc
    if ((skip_req && (ltssm_cmd != `XMT_IN_EIDLE)
                 && (ltssm_cmd != `SEND_N_FTS)
                 && (ltssm_cmd != `SEND_EIDLE)
                 && (ltssm_cmd != `SEND_RCVR_DETECT_SEQ))
                 ) begin
        next_cmd   =  S_SKIP;
        next_pat   = `SEND_SKP;
    // since the interface handshake between this block and ltssm block is
    // asynchronious, we use edge detect to identify the next eidle send command
    end
    // At 2.5 GT/s and 5.0 GT/s, send a SKP OS at the end of the FTS sequnce
    else if ((int_xmt_nfts_done && cmd_is_fts_send && !cfg_ext_synch && (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE)) ||
             (fts_skip_req && (curnt_is_short || (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE))) ||
             (latched_fts_skip_req && !curnt_is_short && (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE))) begin
        next_cmd   =  S_SKIP;
        next_pat   = `SEND_SKP;
    end
    else if (((cxl_mode_enable && ltssm_cxl_sh_bypass) ? ((((ltssm_cmd == `SEND_EIDLE) || latched_eidle_sent_cmd) & pid_count == 0) | eid_win_i | eid_win_d) : ((ltssm_cmd == `SEND_EIDLE) || latched_eidle_sent_cmd)) && (!int_eidle | xmtbyte_eidle_sent)) begin
        next_cmd   =  S_EIDLE;
        next_pat   = `SEND_EIDLE;
    end
    else if (xmtfts_req) begin
        next_cmd   =  S_FTS;
        next_pat   = `SEND_N_FTS;
    end
    else if (ltssm_cmd == `SEND_TS1 | ltssm_cmd == `SEND_TS2) begin
        begin
            next_cmd   =  S_TS;
            next_pat   = ltssm_cmd;
        end
    end
    else if (ltssm_cmd == `COMPLIANCE_PATTERN) begin
        next_cmd   =  S_CMP;
        next_pat   = `COMPLIANCE_PATTERN;
    end
    else if (ltssm_cmd == `NORM || (ltssm_cmd == `SEND_IDLE && cxl_mode_enable)) begin
        next_cmd   =  S_XPKT_WAIT4_START;
        next_pat   = `SEND_IDLE;
    end
    else begin
        next_cmd   =  S_IDLE;
        next_pat   = `SEND_IDLE;
    end
end

assign  state_halt = (data_halt);
assign  data_halt  = 1'b0;

// synchronous state machine
always @(posedge core_clk or negedge core_rst_n)
begin : curnt_state_proc
    if (!core_rst_n)
        xbyte_curnt_state   <= #TP S_IDLE;
    else if ( !state_halt )
        xbyte_curnt_state   <= #TP xbyte_next_state;
end


always @(*)
begin : next_state_proc
        case (xbyte_curnt_state)

        S_IDLE : begin
                xbyte_next_state   =  next_cmd;
        end

        S_FTS :
            // SKP always sent at end of FTS for Gen1/Gen2
            if (fts_skip_req && (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE))
                xbyte_next_state   =  S_SKIP;
            else
                xbyte_next_state   =  S_FTS;

        S_SKIP :
            if ( (os_end || (short_os_4s && curnt_is_short))
                 && !skip_req )
                xbyte_next_state   =  next_cmd;
            else
                xbyte_next_state   = S_SKIP;

        S_EIDLE :
            if (os_end)
                xbyte_next_state   = next_cmd;
            else
                xbyte_next_state   = S_EIDLE;

        S_TS :
            if (os_end)
                xbyte_next_state   = next_cmd;
            else
                xbyte_next_state   = S_TS;


        S_CMP :
            if ( os_end )
                if ( (ltssm_cmd != `COMPLIANCE_PATTERN) && (ltssm_cmd != `MOD_COMPL_PATTERN) )
                        xbyte_next_state   =  next_cmd;
                else
                    xbyte_next_state   =  S_CMP;
            else
                xbyte_next_state   =  S_CMP;

        S_XPKT_WAIT4_START :
// perf_enh

            if ( nw_gtr_2 && ( (sdp_is_last || sot_is_last)  || ((or_sdp || or_stp) && !(eot_is_last & !xmtbyte_xdlh_halt)))  && !(skip_req || skip_insert) ||
       //      if ( nw_gtr_2 && ((sdp_is_last || sot_is_last) && !xmtbyte_xdlh_halt && !(skip_req || skip_insert)) ||
           !nw_gtr_2 && ((or_sdp || or_stp) && !(or_eot && !xmtbyte_xdlh_halt) &&  !(skip_req || skip_insert)) )

                              // wait for the end unless we can handle this pkt in the current cycle
                             // Do no start pkt if SKP is pending transmission
                xbyte_next_state   =  S_XPKT_WAIT4_STOP;
            else if  (!valid_pkt_in_progress_i | valid_pkt_in_progress_i & !xmtbyte_xdlh_halt)
                xbyte_next_state   =  next_cmd;
       else
           xbyte_next_state   =  S_XPKT_WAIT4_START;

        S_XPKT_WAIT4_STOP :
 // perf_enh

       if  ( (nw_gtr_2 && eot_is_last || !nw_gtr_2 && or_eot) &&

                !xmtbyte_xdlh_halt )     // wait for the end of the pkt
                xbyte_next_state   =  next_cmd;
            else
                xbyte_next_state   =  S_XPKT_WAIT4_STOP;


        default :
            xbyte_next_state   =  S_IDLE;

        endcase
end

// FTS support logic
wire                int_ext_synch_done;
assign  cmd_is_fts_send      = (ltssm_cmd == `SEND_N_FTS);
assign  int_xmt_nfts_done    = ( cmd_is_fts_send && ((fts_sent_cnt[7:0] == latched_ts_nfts) || latched_int_xmt_nfts_done) );
assign  int_ext_synch_done   = cmd_is_fts_send && cfg_ext_synch && fts_sent_cnt[12];
assign  xmtbyte_fts_sent     = ( (int_xmt_nfts_done && !cfg_ext_synch) || (int_ext_synch_done && cfg_ext_synch) );
// Sending SKP during SEND_N_FTS Command
// 1. A single SKP is sent after N_FTS FTSs at 2.5 GT/s and 5 GT/s data rates when Extended Synch bit is not set
// 2. A single SKP is sent after 4096 FTSs  at 2.5 GT/s and 5 GT/s data rates when Extended Synch bit is set
// 3. SKP must not be transmitted during first N_FTS FTSs after which SKP must be scheduled and transmitted between
//    FTS and/or EIEOS as necessary to meet definitions in "Clock Tolerance Compensation" section in Base Specification.
//    This applies at all data rates
assign  fts_skip_req         = (cmd_is_fts_send && int_xmt_nfts_done && (
                                   (!cfg_ext_synch && (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE)) ||
                                   (int_ext_synch_done && cfg_ext_synch && (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE)) ||
                                   (skip_req && cfg_ext_synch)));

// latch int_xmt_nfts_done during extended sync
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_int_xmt_nfts_done   <= #TP 1'b0;
    else if (xmtbyte_fts_sent)
        latched_int_xmt_nfts_done   <= #TP 1'b0;
    else if (int_xmt_nfts_done && cfg_ext_synch)
        latched_int_xmt_nfts_done   <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_fts_skip_req    <= #TP 1'b0;
    else if ( (next_pat == `SEND_SKP) && load_pat )    // clear after the pattern has been loaded
        latched_fts_skip_req    <= #TP 1'b0;
    else if (( (xbyte_curnt_state == S_FTS) && fts_skip_req )
            )
        latched_fts_skip_req    <= #TP 1'b1;


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
         fts_sent_cnt    <= #TP 13'h0000;
    end else if (xmtbyte_fts_sent || ((xbyte_curnt_state != S_FTS)
                               && (xbyte_curnt_state != S_SKIP)) ) begin
         fts_sent_cnt    <= #TP 13'h0000;
    end else if (((xbyte_curnt_state == S_FTS)  ||
              (xbyte_curnt_state == S_SKIP)) && xmlh_pat_fts_sent) begin
         fts_sent_cnt    <= #TP fts_sent_cnt + 13'h1;
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
         dlyd_cmd_is_fts_send    <= #TP 1'b0;
    else
         dlyd_cmd_is_fts_send    <= #TP cmd_is_fts_send;



reg     [2:0]           eidle_sent_cnt;

always @(posedge core_clk or negedge core_rst_n)
begin : eidle_sent_cnt_proc
    if(!core_rst_n )
         eidle_sent_cnt    <= #TP 3'b0;
    else if (ltssm_cmd != `SEND_EIDLE)
         eidle_sent_cnt    <= #TP 3'b0;
    else
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
         eidle_sent_cnt    <= #TP eidle_sent_cnt + xmlh_pat_eidle_sent;
// spyglass enable_block W164a
end


assign xmtbyte_eidle_sent = xmlh_pat_eidle_sent                                                 && (eidle_sent_cnt == ltssm_eidle_cnt) 
                                                ;

always @(posedge core_clk or negedge core_rst_n)
begin : xmtfts_req_proc
    if (!core_rst_n)
        xmtfts_req  <= #TP 0;
    else
      // detected the assertion edge of SEND NFTS command to start the
      // fts transmit process. Until all fts sent, we should not
      // send any other sequence.
        xmtfts_req  <= #TP xmtbyte_fts_sent ? 1'b0
                           : (cmd_is_fts_send & !dlyd_cmd_is_fts_send)  ? 1'b1
                           : xmtfts_req;
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        curnt_compliance_finished       <= #TP 1'b0;
    else
        curnt_compliance_finished       <= #TP (xbyte_curnt_state != S_CMP);


wire  int_in_training;
assign  int_in_training = (xbyte_curnt_state == S_CMP)
                          || (xbyte_curnt_state == S_TS);

// Receiver Detect / Loopback signaling
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        xmtbyte_txdetectrx_loopback <= #TP 0;
    else
        // According to PIPE, loopback was indicated to PHY as overload of txdetectrx signal
        xmtbyte_txdetectrx_loopback <= #TP (  (ltssm_cmd == `SEND_RCVR_DETECT_SEQ) // for signalling receiver detect
                                            | (ltssm_in_lpbk_i && !lpbk_master && (     // for signalling loopback
 // ltssm_cmd == XMT_IN_EIDLE in ltssm_in_lpbk_i means Loopback.Active from Loopback EQ
                                                &(~ltssm_lanes_active | (ltssm_lanes_active & ~xmtbyte_txelecidle)))) ); // active lanes aren't in eidle


// Electrical Idle signaling
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        goto_xmt_eidle              <= #TP 1'b0;
    else
        if (ltssm_cmd == `SEND_EIDLE)
            goto_xmt_eidle              <= #TP 1'b1;
        else if ((ltssm_cmd != `SEND_EIDLE) && (ltssm_cmd != `XMT_IN_EIDLE) && (ltssm_cmd != `SEND_RCVR_DETECT_SEQ))
            goto_xmt_eidle              <= #TP 1'b0;
        else
            goto_xmt_eidle              <= #TP goto_xmt_eidle;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        xmtbyte_eidle_sent_d        <= #TP 1'b0;
        xmtbyte_skip_sent_d         <= #TP 1'b0;
    end else begin
        xmtbyte_eidle_sent_d        <= #TP xmtbyte_eidle_sent;
        xmtbyte_skip_sent_d         <= #TP xmtbyte_skip_sent;
    end

wire os_start_needed = (current_data_rate > `GEN2_RATE) ? os_start : 1'b1; // TxCmpl=1 in Polling.Compliance is only for Gen1/2 rate. So for >gen2_rate it is safe to use os_start.


assign int_eidle_i = (xmtbyte_eidle_sent_d || (ltssm_cmd == `XMT_IN_EIDLE) || (ltssm_cmd == `SEND_RCVR_DETECT_SEQ)) ? 1'b1 :
        ((ltssm_cmd != `SEND_EIDLE) && (ltssm_cmd != `XMT_IN_EIDLE) && (ltssm_cmd != `SEND_RCVR_DETECT_SEQ)
                 && (xmtbyte_ts1_sent || xmtbyte_ts2_sent || (os_start_needed && ((ltssm_cmd == `COMPLIANCE_PATTERN) || (ltssm_cmd == `MOD_COMPL_PATTERN))) // immediately no TxEIdle if sending COMPLIANCE_PATTERN to avoid TxEIdle=1 & TxCmpl=1 on all lanes
                    || xmtbyte_skip_sent
                    || xmlh_pat_fts_sent
                    || ltssm_in_lpbk)) ? 1'b0 : int_eidle;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        int_eidle                   <= #TP 1'b1;
    else
        int_eidle                   <= #TP int_eidle_i;

assign os_sent_d      = xmtbyte_skip_sent_d | xmtbyte_eidle_sent_d;
assign skip_os_sent_d = xmtbyte_skip_sent_d;
wire   skip_os_sent   = xmtbyte_skip_sent;
assign os_sent        = skip_os_sent | xmtbyte_eidle_sent;


// when lanes that are not active, we will set it eidle
// for gen5 lpbk.active slave not sending Modified Compliance Pattern after EQ, the lane under test loops back data from rx to tx, the lanes not under test transitioned to TxElecIdle
assign xmtbyte_txelecidle_i = ({NL{int_eidle}} | (~(int_lanes_active))) ;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        int_lanes_active            <= #TP {NL{1'b1}};
    else
        int_lanes_active            <= #TP ( (xbyte_curnt_state == S_IDLE) // Detect state / downsizing in gen1/gen2
                                            || (ltssm_in_lpbk && (lpbk_master)) //for implementation-specific lanes or the lane under test from loopback eq
                                            || (xmtbyte_ts1_sent && (current_data_rate == `GEN1_RATE))  // upconfigure in gen1
                                          ) 
                                       ? ltssm_lanes_active : int_lanes_active;


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        int_link_mode               <= #TP 0;
    else
        int_link_mode               <= #TP ( (xbyte_curnt_state == S_IDLE) // Detect state / downsizing in gen1/gen2
                                            || (ltssm_in_lpbk && lpbk_master) //for implementation-specific lanes
                                            || (xmtbyte_ts1_sent && (current_data_rate == `GEN1_RATE))  // upconfigure in gen1
                                          ) 
                                       ? smlh_link_mode : int_link_mode;

assign  active_lane_cnt     =
                              (int_link_mode[3]) ? 5'd8 :
                              (int_link_mode[2]) ? 5'd4 :
                              (int_link_mode[1]) ? 5'd2 :
                              (int_link_mode[0]) ? 5'd1 :
                                                    5'd0;

always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)
    xmtbyte_idle_sent       <= #TP 1'b0;
else
    xmtbyte_idle_sent       <= #TP (xbyte_curnt_state == S_IDLE);

always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)
    cmp_dly_lane       <= #TP 1;
else
    if ( (xbyte_next_state == S_CMP) && ((xbyte_curnt_state != S_CMP) && (xbyte_curnt_state != S_SKIP)) ) // when we are about to start sending compliance
        cmp_dly_lane       <= #TP 1;
//    else if ( ((xbyte_next_state == S_CMP) || ((xbyte_next_state == S_SKIP) && xbyte_curnt_state == S_CMP)) && ((cmp_dly_lane[7]) && os_end) )   // Or we need to wrap back to lane zero
    else if ( (xbyte_curnt_state == S_CMP) && cmp_dly_lane[7] && os_end )   // Or we need to wrap back to lane zero
        cmp_dly_lane       <= #TP 1;
    else if ( (xbyte_curnt_state == S_CMP) && os_end )              // Its time to switch delayed lanes
        cmp_dly_lane       <= #TP cmp_dly_lane << 1;
// leda W565 on


// =============================================================================
// Skip Logic
// =============================================================================

// Skips are accumulated when a time out happened during a pkt transmission.
//
// A skip is transmitted at every start of link negotiation

assign skip_req = ((~accumed_skips_is_0)

                   );

wire [10:0] cfg_skip_interval_not_8gt = cfg_skip_interval;

assign skip_insert = (skip_timer >= cfg_skip_interval_not_8gt);

// do not send skip during compliance state and L0s, L1 and L2 state
always @(posedge core_clk or negedge core_rst_n)
begin : skip_timer_10b_proc
    if(!core_rst_n ) begin
        skip_timer      <= #TP {TIMER_BITS{1'b0}};
    end else if (skip_insert) begin
        skip_timer      <= #TP {TIMER_BITS{1'b0}};
    end else if (  (ltssm_cmd == `SEND_BEACON)
                || (ltssm_cmd == `XMT_IN_EIDLE)
                || ((ltssm_cmd == `COMPLIANCE_PATTERN) && !cfg_compliance_sos)
                || ((ltssm_cmd == `MOD_COMPL_PATTERN)  && !cfg_compliance_sos)
                ) begin
        skip_timer      <= #TP {TIMER_BITS{1'b0}};
    end else begin
        skip_timer     <= #TP  skip_timer + 1'b1;
    end
end


        // Since we have plus1 priority higher than minus 1, we decided to
        // send one more skip under boundary condition so that we can have
        // this simplified logic.
assign prev_accumed_skips  = (   (ltssm_cmd == `SEND_BEACON)
                               || (ltssm_cmd == `XMT_IN_EIDLE)
                               || ((ltssm_cmd == `COMPLIANCE_PATTERN) && !cfg_compliance_sos)
                               || ((ltssm_cmd == `MOD_COMPL_PATTERN) && !cfg_compliance_sos)) ? 0
                                   : ( (skip_insert && cfg_compliance_sos && ((ltssm_cmd == `COMPLIANCE_PATTERN) || (ltssm_cmd == `MOD_COMPL_PATTERN)))
                                   || null_ieds_insert
                                     )
                                   ? accumed_skips + 2'h2
                                   : ( (skip_insert)
                                     )
                                   ? accumed_skips + 1'b1
                                   : ( ((xbyte_next_state == S_SKIP) && load_pat && (accumed_skips_is_not_0) && (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE))
                                     )
                                   ? accumed_skips - 1'b1 : accumed_skips;

always @(posedge core_clk or negedge core_rst_n)
begin : accumed_skips_proc
    if(!core_rst_n ) begin
        accumed_skips   <= #TP 0;
    end else begin
       accumed_skips   <= #TP prev_accumed_skips;
    end
end

assign accumed_skips_is_0 = (accumed_skips == 0);
assign accumed_skips_is_not_0 = (accumed_skips != 0);

assign null_ieds_for_skip_sent = 0;

wire first_g5_eieos_sent = 0;



// =============================================================================

// number of cycles to pass one CX_DW of data
wire [31:0] data_cycles_i; // to avoid spyglass warning
assign data_cycles_i = (NBYTE >> active_nb_shift) >> OneHotToBitNum(int_link_mode[4:0]);
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n )
        data_cycles <= #TP 0;
    else
        data_cycles <= #TP data_cycles_i[SLICE_WD:0];

// to avoid spyglass warning
wire    [SLICE_WD:0]  data_cycles_sub_1_i;
wire    [SLICE_WD-1:0] data_cycles_sub_1;
assign data_cycles_sub_1_i = (data_cycles - 1'b1);
assign data_cycles_sub_1 = data_cycles_sub_1_i[SLICE_WD-1:0];
// data_cycles is essentially static
// next_xdlh_xmlh_eot is the look-ahead version from the xdlh_control
reg [SLICE_WD-1:0] pkt_end_cnt;
always @(posedge core_clk or negedge core_rst_n)
begin : pkt_end_cnt_proc
    if(!core_rst_n ) begin
        pkt_end_cnt <= #TP 5'b0;
    end else begin
        pkt_end_cnt <= #TP Calc_pkt_end(next_xdlh_xmlh_eot, data_cycles);
    end
end




reg      early_pkt_end;
always @(posedge core_clk or negedge core_rst_n)
begin : early_pkt_end_proc
    if(!core_rst_n ) begin
        early_pkt_end <= #TP 1'b0;
    end else begin
        early_pkt_end <= #TP nw_gtr_2 & (data_cycles != 1) && next_eot_is_last && |(next_xdlh_xmlh_eot) && !next_xdlh_xmlh_eot[NW-1] ||
                       !nw_gtr_2 & (data_cycles != 1) && |(next_xdlh_xmlh_eot) && !next_xdlh_xmlh_eot[NW-1];
    end
end

assign  last_chunk  = early_pkt_end ? (chunk_cnt == pkt_end_cnt) : (chunk_cnt == data_cycles_sub_1); //(data_cycles - 1'b1)


// chunk counter
always @(posedge core_clk or negedge core_rst_n)
begin : chunk_cnt_proc
    if (!core_rst_n)
        chunk_cnt   <= #TP 0;
    else
        if ( last_chunk || !pkt_in_progress_i
             || (!cmd_is_data && (xbyte_curnt_state != S_CMP))) // reset the chunk count went we get new data
            chunk_cnt   <= #TP 0;
        else
            chunk_cnt   <= #TP chunk_cnt + 1'b1;
end

assign active_nb_shift = int_active_nb[2:1];                             // 1s = 0 , 2s = 1, 4s = 2

reg [2:0] chunk_cnt_shift ; // Used to multiply increment of chunk_cnt

always @(*)
begin
  case({int_active_nb,active_lane_cnt[4:0]})
      10'b00010_00001 : chunk_cnt_shift = 1;  // 2sx1
      10'b00010_00010 : chunk_cnt_shift = 2;  // 2sx2
      10'b00010_00100 : chunk_cnt_shift = 3;  // 2sx4
      default      : chunk_cnt_shift = 0;  // Full Datapath in operation
  endcase
end

assign chunk_offset = chunk_cnt << chunk_cnt_shift;

// keep the xdlh_data halted until all of it has been processed
assign  xmtbyte_xdlh_halt   = (cmd_is_data) ? !(last_chunk && pkt_in_progress) : 1'b1;

always @( posedge core_clk or negedge core_rst_n ) begin : xmtbyte_xdlh_halt_d_PROC
    if ( ~core_rst_n )
        xmtbyte_xdlh_halt_d <= #TP 0;
    else
        xmtbyte_xdlh_halt_d <= #TP xmtbyte_xdlh_halt;
end // xmtbyte_xdlh_halt_d_PROC


// Aligen to xbyte_next_state
assign  pkt_in_progress     = ( cmd_is_data && (or_stp || or_sdp) && !(skip_insert || skip_req)) || latched_pkt_in_progress;
assign  pkt_in_progress_i   = pkt_in_progress;


assign valid_pkt_in_progress    = pkt_in_progress;
assign valid_pkt_in_progress_i  = valid_pkt_in_progress;

always @(posedge core_clk or negedge core_rst_n) begin : latched_pkt_in_progress_PROC
    if (!core_rst_n) begin
        latched_pkt_in_progress         <= #TP 1'b0;
    end else begin
//pcie_perf
        if ((eot_is_last && !xmtbyte_xdlh_halt) ) begin
            latched_pkt_in_progress         <= #TP 1'b0;
        end
        else begin
            latched_pkt_in_progress         <= #TP pkt_in_progress;
        end
    end
end


wire [NL-1:0] lpbk_entry_not_lane_under_test_for_master;
assign lpbk_entry_not_lane_under_test_for_master = 0;

assign xmtbyte_txdata_dv =
                         1'b1;

// =============================================================================
// Receive Error Counters for compliance
// =============================================================================


// latch pattern lock
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)
    pattern_lock                <= #TP {NL{1'b0}};
else
    if ((xbyte_curnt_state != S_CMP) && !((ltssm_cmd == `MOD_COMPL_PATTERN) && (xbyte_curnt_state == S_SKIP)))
        pattern_lock            <= #TP {NL{1'b0}};


always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)
    err_cnt                     <= #TP {NL{7'b0}};
else begin
    err_cnt                     <= #TP {NL{7'b0}};
end

// in the first clock of Recovery.Speed state load_pat might be low for TxDataValid but the pending TS2 needs to be sent.
// So load the ltssm_ts_auto_change in the second clock. ltssm_ts_auto_change_r (delay one cycle to ltssm_ts_auto_change) is for this.
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_ts_auto_change_r_PROC
    if ( ~core_rst_n )
        ltssm_ts_auto_change_r <= #TP 0;
    else
        ltssm_ts_auto_change_r <= #TP ltssm_ts_auto_change;
end // ltssm_ts_auto_change_r_PROC

// Latch these signals because they can change while being used
//delay ltssm_ts_auto_change by 1 cycle because this signal updates at the same cycle when ltssm enters new state.
//If load_pat asserts at the same cycle when ltssm enters new state, the core still sends previous TS but with new state ltssm_ts_auto_change.
always @( * ) begin : ltssm_ts_auto_change_newltssm_d_PROC
    ltssm_ts_auto_change_d = (smlh_ltssm_state == `S_RCVRY_SPEED) ? ltssm_ts_auto_change_r : ltssm_ts_auto_change;
end // ltssm_ts_auto_change_newltssm_d_PROC

// Alternate Protocols informatiom for sym14-8
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n) begin
    latched_ts_cntrl            <= #TP 0;
    latched_mod_ts              <= #TP 0;
    latched_ts_alt_protocol     <= #TP 0;
    latched_ts_auto_change_i    <= #TP 0;
    int_xlinknum                <= #TP 8'h00;
    int_xk237_4lnknum           <= #TP {NL{1'b1}};
    int_xk237_4lannum           <= #TP {NL{1'b1}};
    latched_alt_prot_info       <= #TP 0;
end else if (load_pat_easy) begin
    latched_ts_cntrl            <= #TP ltssm_ts_cntrl;
    latched_mod_ts              <= #TP ltssm_mod_ts;
    latched_ts_alt_protocol     <= #TP ltssm_ts_alt_protocol;
    latched_ts_auto_change_i    <= #TP ltssm_ts_auto_change_d;
    latched_alt_prot_info       <= #TP ltssm_ts_alt_prot_info;
    int_xlinknum                <= #TP ltssm_xlinknum;
    int_xk237_4lnknum           <= #TP ltssm_xk237_4lnknum;
    int_xk237_4lannum           <= #TP ltssm_xk237_4lannum;
end


// =============================================================================
// Data Path
// =============================================================================
// At 2.5 GT/s and 5 GT/s, PAD Symbols are inserted to preserve link alignment
// when a TLP does not finish on the last lane of the link.
assign  int_pad_data        = {`PAD_8B, `PAD_8B, `PAD_8B, `PAD_8B } ;

always @(*) begin : PAD_DATA
    integer i;
    for(i = 0; i < NW; i = i + 1) begin
        pad_data[i*32 +: 32] = int_xdlh_pad[i] ? int_pad_data : xdlh_xmlh_data[i*32 +: 32];
    end
    // int_xdlh_pad[0] can never be set
    pad_data[31:0] = xdlh_xmlh_data[31:0];
end

// Per lane compliance data
//      cmp_data[(01*NBIT)-1:(00*NBIT)] = BuildCmpData( xmlh_pat_data, xmlh_dly_cmp_data, err_cnt[(01*7)-1:00*7], pattern_lock[00], int_active_nb, cmp_dly_lane[0], xmlh_cmp_errloc, xmlh_dly_cmp_errloc);
assign  cmp_data[(1 *NBIT)-1:(0 *NBIT)] = BuildCmpData( xmlh_pat_data, xmlh_dly_cmp_data, err_cnt[(1 *7)-1:0 *7], pattern_lock[0 ], int_active_nb, cmp_dly_lane[0], xmlh_cmp_errloc, xmlh_dly_cmp_errloc);
assign  cmp_data[(2 *NBIT)-1:(1 *NBIT)] = BuildCmpData( xmlh_pat_data, xmlh_dly_cmp_data, err_cnt[(2 *7)-1:1 *7], pattern_lock[1 ], int_active_nb, cmp_dly_lane[1], xmlh_cmp_errloc, xmlh_dly_cmp_errloc);
assign  cmp_data[(3 *NBIT)-1:(2 *NBIT)] = BuildCmpData( xmlh_pat_data, xmlh_dly_cmp_data, err_cnt[(3 *7)-1:2 *7], pattern_lock[2 ], int_active_nb, cmp_dly_lane[2], xmlh_cmp_errloc, xmlh_dly_cmp_errloc);
assign  cmp_data[(4 *NBIT)-1:(3 *NBIT)] = BuildCmpData( xmlh_pat_data, xmlh_dly_cmp_data, err_cnt[(4 *7)-1:3 *7], pattern_lock[3 ], int_active_nb, cmp_dly_lane[3], xmlh_cmp_errloc, xmlh_dly_cmp_errloc);

// Per lane Compliance k char
//      cmp_datak[(01*NBK)-1:(00*NBK)]  = cmp_dly_lane[0] ? xmlh_dly_cmp_datak : xmlh_pat_datak;
assign  cmp_datak[(1 *NBK)-1:(0 *NBK)]  = cmp_dly_lane[0] ? xmlh_dly_cmp_datak : xmlh_pat_datak;
assign  cmp_datak[(2 *NBK)-1:(1 *NBK)]  = cmp_dly_lane[1] ? xmlh_dly_cmp_datak : xmlh_pat_datak;
assign  cmp_datak[(3 *NBK)-1:(2 *NBK)]  = cmp_dly_lane[2] ? xmlh_dly_cmp_datak : xmlh_pat_datak;
assign  cmp_datak[(4 *NBK)-1:(3 *NBK)]  = cmp_dly_lane[3] ? xmlh_dly_cmp_datak : xmlh_pat_datak;


// combined xdlh & compliance data
assign  int_xdlh_data   = pad_data;
assign  int_xdlh_datak  = xdlh_xmlh_datak;

always @( posedge core_clk or negedge core_rst_n ) begin : xmlh_pat_dv_d_PROC
    if ( ~core_rst_n )
        xmlh_pat_dv_d <= #TP 0;
    else
        xmlh_pat_dv_d <= #TP xmlh_pat_dv;
end // xmlh_pat_dv_d_PROC

// Per lane data
assign  int_xmt_data[(0 *NBIT)+(NBIT)-1:(0 *NBIT)]  = GetSlice( int_xdlh_data, (0  + chunk_offset), int_active_nb, active_lane_cnt, int_lanes_active[0]  );
assign  int_xmt_data[(1 *NBIT)+(NBIT)-1:(1 *NBIT)]  = GetSlice( int_xdlh_data, (1  + chunk_offset), int_active_nb, active_lane_cnt, int_lanes_active[1]  );
assign  int_xmt_data[(2 *NBIT)+(NBIT)-1:(2 *NBIT)]  = GetSlice( int_xdlh_data, (2  + chunk_offset), int_active_nb, active_lane_cnt, int_lanes_active[2]  );
assign  int_xmt_data[(3 *NBIT)+(NBIT)-1:(3 *NBIT)]  = GetSlice( int_xdlh_data, (3  + chunk_offset), int_active_nb, active_lane_cnt, int_lanes_active[3]  );

// Per lane k char
assign  int_xmt_datak[(0 *NBK)+(NBK)-1:(0 *NBK)]    = GetKSlice( int_xdlh_datak, (0  + chunk_offset), int_active_nb, active_lane_cnt, int_lanes_active[0]  );
assign  int_xmt_datak[(1 *NBK)+(NBK)-1:(1 *NBK)]    = GetKSlice( int_xdlh_datak, (1  + chunk_offset), int_active_nb, active_lane_cnt, int_lanes_active[1]  );
assign  int_xmt_datak[(2 *NBK)+(NBK)-1:(2 *NBK)]    = GetKSlice( int_xdlh_datak, (2  + chunk_offset), int_active_nb, active_lane_cnt, int_lanes_active[2]  );
assign  int_xmt_datak[(3 *NBK)+(NBK)-1:(3 *NBK)]    = GetKSlice( int_xdlh_datak, (3  + chunk_offset), int_active_nb, active_lane_cnt, int_lanes_active[3]  );


// only insert link and lane numbers if we aren't putting K237 there
assign  insert_linknum  = {NL{xmlh_pat_linkloc}} & ~int_xk237_4lnknum;
assign  insert_lanenum  = {NL{xmlh_pat_laneloc}} & ~int_xk237_4lannum;
assign insert_eqts_info = 4'b0000;
assign int_eqts_info    = {NL*EQTS_WD{1'b0}};
assign int_mask_eieos   = {NL{1'b0}};

assign insert_s15_4     = 0;
assign insert_s6        = 0;


// Per lane pattern data
assign  int_pat_data[(0 *NBIT)+(NBIT)-1:(0 *NBIT)]  = BuildOsData( xmlh_pat_data, int_xlinknum, 8'd0,  int_active_nb, insert_linknum[0],  insert_lanenum[0],  insert_eqts_info, int_eqts_info[EQTS_WD*1-1 : EQTS_WD*0],   int_mask_eieos[0]);
assign  int_pat_data[(1 *NBIT)+(NBIT)-1:(1 *NBIT)]  = BuildOsData( xmlh_pat_data, int_xlinknum, 8'd1,  int_active_nb, insert_linknum[1],  insert_lanenum[1],  insert_eqts_info, int_eqts_info[EQTS_WD*2-1 : EQTS_WD*1],   int_mask_eieos[1]);
assign  int_pat_data[(2 *NBIT)+(NBIT)-1:(2 *NBIT)]  = BuildOsData( xmlh_pat_data, int_xlinknum, 8'd2,  int_active_nb, insert_linknum[2],  insert_lanenum[2],  insert_eqts_info, int_eqts_info[EQTS_WD*3-1 : EQTS_WD*2],   int_mask_eieos[2]);
assign  int_pat_data[(3 *NBIT)+(NBIT)-1:(3 *NBIT)]  = BuildOsData( xmlh_pat_data, int_xlinknum, 8'd3,  int_active_nb, insert_linknum[3],  insert_lanenum[3],  insert_eqts_info, int_eqts_info[EQTS_WD*4-1 : EQTS_WD*3],   int_mask_eieos[3]);


// Per lane pattern k char
//      pat_datak[(00*NBK)+(NBK)-1:(00*NBK)]  = InsertKNum( xmlh_pat_datak, int_active_nb, insert_linknum[00], insert_lanenum[00]  );
assign  int_pat_datak[(0 *NBK)+(NBK)-1:(0 *NBK)]  = InsertKNum( xmlh_pat_datak, int_active_nb, insert_linknum[0],  insert_lanenum[0] );
assign  int_pat_datak[(1 *NBK)+(NBK)-1:(1 *NBK)]  = InsertKNum( xmlh_pat_datak, int_active_nb, insert_linknum[1],  insert_lanenum[1] );
assign  int_pat_datak[(2 *NBK)+(NBK)-1:(2 *NBK)]  = InsertKNum( xmlh_pat_datak, int_active_nb, insert_linknum[2],  insert_lanenum[2] );
assign  int_pat_datak[(3 *NBK)+(NBK)-1:(3 *NBK)]  = InsertKNum( xmlh_pat_datak, int_active_nb, insert_linknum[3],  insert_lanenum[3] );



// This optional register is currently not needed
// Optional Register
//parameter N_DELAY_CYLES     = REGOUT ? 1 : 0;
//parameter DATAPATH_WIDTH    = (NB*8*NL) + (NB*NL);
//delay_n #(N_DELAY_CYLES, DATAPATH_WIDTH) u0_delay(
//    .clk        (core_clk),
//    .rst_n      (core_rst_n),
//    .clear      (1'b0),
//    .din        ({ int_xmt_data, int_xmt_datak }),
//    .dout       ({ xmt_data,     xmt_datak     })
//);

assign  xmt_data    = (xbyte_curnt_state == S_CMP)      ?
                                                          cmp_data               :
                      (valid_pkt_in_progress_i)         ? int_xmt_data :
                                                          {DW{1'b0}}             ;
assign  xmt_datak   = (xbyte_curnt_state == S_CMP)      ?
                                                          cmp_datak              :
                      (valid_pkt_in_progress_i)         ? int_xmt_datak          :
                                                          {NBYTE{1'b0}}          ;

// if ltssm_cmd == `XMT_IN_EIDLE, transmitter shoud be idle 0s
assign  pat_data    = (ltssm_cmd == `XMT_IN_EIDLE)      ? {DW{1'b0}}             :
                                                          int_pat_data           ;
assign  pat_datak   = (ltssm_cmd == `XMT_IN_EIDLE)      ? {NBYTE{1'b0}}          :
                                                          int_pat_datak          ;


// =============================================================================
// Output Data Mux and register
// =============================================================================

always @(posedge core_clk or negedge core_rst_n)
begin : output_data_proc
    if (!core_rst_n) begin
        int_xmtbyte_txdata             <= #TP {DW{1'b0}};
        int_xmtbyte_txdatak            <= #TP {NBYTE{1'b0}};
        xmtbyte_link_in_training   <= #TP 1'b0 ;
    end else if(int_eidle_i) begin
        int_xmtbyte_txdata             <= #TP {DW{1'b0}};
        int_xmtbyte_txdatak            <= #TP {NBYTE{1'b0}};
        xmtbyte_link_in_training   <= #TP int_in_training;
    end else begin
        if (cmd_is_data
            || (xbyte_curnt_state == S_CMP)) begin
            int_xmtbyte_txdata         <= #TP xmt_data;
            int_xmtbyte_txdatak        <= #TP xmt_datak;
        end else if (xmlh_pat_dv) begin
            int_xmtbyte_txdata         <= #TP pat_data;
            int_xmtbyte_txdatak        <= #TP pat_datak;
        end else begin
            int_xmtbyte_txdata         <= #TP {DW{1'b0}};
            int_xmtbyte_txdatak        <= #TP {NBYTE{1'b0}};
        end
        xmtbyte_link_in_training   <= #TP int_in_training;
    end
end

assign xmtbyte_txdata  = int_xmtbyte_txdata  ;
assign xmtbyte_txdatak = int_xmtbyte_txdatak ;

parameter N_DELAY_CYLES2    = `CX_XMLH_SCRAMBLE_REGOUT;
parameter RESETVAL  = {NL{1'b1}};
delay_n

#(N_DELAY_CYLES2, NL, RESETVAL) u1_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (xmtbyte_txelecidle_i),
    .dout       (xmtbyte_txelecidle_g12)
);

assign xmtbyte_txelecidle_g3 = 0;
assign xmtbyte_txelecidle = (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? xmtbyte_txelecidle_g3 : xmtbyte_txelecidle_g12;

assign xmtbyte_g5_lpbk_deassert = 1'b0;

//pipeline for txcompliance to align txdata and txelecidle
parameter RESET_VALUE = {NL{1'b0}};
delay_n

#(N_DELAY_CYLES2, NL, RESET_VALUE) txcompl_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (xmtbyte_txcompliance_i),
    .dout       (xmtbyte_txcompliance_g12)
);

assign xmtbyte_txcompliance_g3 = 0;
assign xmtbyte_txcompliance = (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? xmtbyte_txcompliance_g3 : xmtbyte_txcompliance_g12;

//pipeline for loopback to align txdata and txelecidle
parameter RST_VALUE = 1'b0;

assign ltssm_in_lpbk_g3 = 0;
assign ltssm_in_lpbk_i = (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? ltssm_in_lpbk_g3 : ltssm_in_lpbk;

// =============================================================================
// Pattern Generator
// =============================================================================
wire poll_cmp_enter_act_pulse;
wire pre_poll_cmp_enter_act_pulse = (xbyte_curnt_state == S_CMP) & (smlh_ltssm_state == `S_POLL_ACTIVE) & (next_pat == `COMPLIANCE_PATTERN) & ltssm_clear;
assign poll_cmp_enter_act_pulse = pre_poll_cmp_enter_act_pulse;
xmlh_pat_gen

u_xmlh_pat_gen (
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),

    .poll_cmp_enter_act_pulse   (poll_cmp_enter_act_pulse),
    .cfg_n_fts                  (cfg_n_fts),
  `ifndef SYNTHESIS
    .smlh_ltssm_state           (smlh_ltssm_state),
  `endif // SYNTHESIS

    .next_pat                   (next_pat),
    .load_pat                   (load_pat),
    .ltssm_ts_cntrl             (latched_ts_cntrl),
    .ltssm_mod_ts               (latched_mod_ts),
    .ltssm_ts_alt_protocol      (latched_ts_alt_protocol),
    .ltssm_ts_auto_change       (latched_ts_auto_change_i),
    .ltssm_ts_alt_prot_info     (latched_alt_prot_info),
    .current_data_rate          (current_data_rate),
    .active_nb                  (int_active_nb[AW-1:0]),
    .xmtbyte_idle_sent          (xmtbyte_idle_sent),
    .xmtbyte_eidle_sent         (xmtbyte_eidle_sent),

    // ---------------------------------outputs ------------------------
    .os_start                   (os_start),
    .os_end                     (os_end),
    .xmlh_pat_ack               (xmlh_pat_ack),
    .xmlh_pat_dv                (xmlh_pat_dv),
    .xmlh_pat_data              (xmlh_pat_data),
    .xmlh_pat_datak             (xmlh_pat_datak),
    .xmlh_pat_linkloc           (xmlh_pat_linkloc),
    .xmlh_pat_laneloc           (xmlh_pat_laneloc),
    .xmlh_pat_s15_4loc          (xmlh_pat_s15_4loc),
    .xmlh_cmp_errloc            (xmlh_cmp_errloc),

    .xmlh_dly_cmp_data          (xmlh_dly_cmp_data),
    .xmlh_dly_cmp_datak         (xmlh_dly_cmp_datak),
    .xmlh_dly_cmp_errloc        (xmlh_dly_cmp_errloc),

    .xmtbyte_ts1_sent           (xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent           (xmtbyte_ts2_sent),
    .xmlh_pat_fts_sent          (xmlh_pat_fts_sent),
    .xmlh_pat_eidle_sent        (xmlh_pat_eidle_sent),
    .xmtbyte_skip_sent          (xmtbyte_skip_sent)

);

// =============================================================================
// Functions
// =============================================================================

// Function to get a Lanes worth of data from the data stream
function automatic [NBIT-1:0] GetSlice;
  input  [DW-1:0]   data;
  input  [SLICE_WD-1:0] slice;
  input  [4:0]      active_nb;
  input  [4:0]      active_lane_cnt;    // this input not used in 1s only mode
  input             lane_enable;

  reg    [SLICE_WD-1:0] tmp_slice[1:NB-1];
begin
    GetSlice = {NBIT{1'b0}};
    if (lane_enable) begin // first byte
        GetSlice[7:0]   = Bget( data, slice);
    end

    if ((|active_nb[4:1]) && lane_enable) begin // second byte
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        tmp_slice[1] = (slice + active_lane_cnt);
// spyglass enable_block W164a
        GetSlice[15:8]  = Bget( data, tmp_slice[1]);
    end




end
endfunction // GetSlice


// Function to get a Lanes worth of data kchar indicators from the data stream
function automatic [NBK-1:0]  GetKSlice;
  input  [NBYTE-1:0]datak;
  input  [SLICE_WD-1:0] slice;
  input  [4:0]      active_nb;
  input  [4:0]      active_lane_cnt;    // this input not used in 1s only mode
  input             lane_enable;

  reg    [SLICE_WD-1:0] tmp_slice[1:NB-1];
begin
// spyglass disable_block ImproperRangeIndex-ML
// SMD: Possible discrepancy in the range index or slice of an array
// SJ: Rule will flag violation if number of bits required to cover index doesn't matches with log2N. In this code, this signal is not out of index bound. So, disable SpyGlass from reporting this warning.
    GetKSlice = {NBK{1'b0}};
    if (lane_enable) begin // first byte
        GetKSlice[0] = datak[slice];
    end

    if ((|active_nb[4:1]) && lane_enable) begin // second byte
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        tmp_slice[1]    = (slice + active_lane_cnt);
// spyglass enable_block W164a
        GetKSlice[1]    = datak[tmp_slice[1]];
    end

// spyglass enable_block ImproperRangeIndex-ML

end
endfunction // GetKSlice

// Function to replace k char for link and lane numbers in TS ordered sets on a given lane.
function automatic [NBK-1:0]  InsertKNum;
  input  [NBK-1:0]  in_datak;                   // Lane datak in
  input  [4:0]      active_nb;                  // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s
  input             linkloc;                    // Indicates the current data contains the link # field. Its location can be inferred from active_nb
  input             laneloc;                    // Indicates the current data contains the lane # field. Its location can be inferred from active_nb

  reg    [NBK-1:0]  InsertKNum_i;
begin
    InsertKNum_i = in_datak;

         case ({active_nb, linkloc, laneloc})
        7'b00010_10 : InsertKNum_i[1]    = 1'b0;
        7'b00010_01 : InsertKNum_i[0]    = 1'b0;
        default   : InsertKNum_i = in_datak;
    endcase

    InsertKNum = InsertKNum_i;
end
endfunction // InsertKNum


// Function to build a lanes compliance data
function automatic [NBIT-1:0] BuildCmpData;
  input  [NBIT-1:0] in_data;                    // Compliance Data
  input  [NBIT-1:0] dly_in_data;                // Delayed Compliance Data
  input  [6:0]      error_cnt;                  // Error Count
  input             pattern_lock;               // Pattern lock bit
  input  [4:0]      active_nb;                  // active number of symbols. bit0=1s, bit1=2s, bit2=4s,bit3=8s,bit4=16s
  input             dly_lane;                   // Indicates this lane should use delayed Compliance data
  input             cmploc;                     // Indicates the current data contains the compliance error count field. Its location can be inferred from active_nb
  input             dlyloc;                     // Indicates the current data contains the compliance error count field. Its location can be inferred from active_nb

  reg    [7:0]      err_field;                  // the error count and pattern lock combined
  reg               loc;                        // the location to insert error
begin
    BuildCmpData    = dly_lane ? dly_in_data : in_data;
    loc             = (dly_lane) ? dlyloc : cmploc;
    err_field       = {pattern_lock, error_cnt};

    case ({active_nb, loc})
        6'b00010_1 : BuildCmpData[15:0]  = {2{err_field}};
        default : BuildCmpData        = dly_lane ? dly_in_data : in_data;
    endcase
end
endfunction // InsertCmpErr

// Function to replace link and lane numbers in TS ordered sets on a given lane.
// This function is also used to insert per lane equalization information for
// Symbols 6-9 of a TS Ordered Set and to mask OS Identifier of EIEOS when
// required
function automatic [NBIT-1:0]         BuildOsData;
  input  [NBIT-1:0]         in_data;        // Lane data in
  input  [7:0]              linknum;        // Link Number
  input  [7:0]              lanenum;        // Lane Number
  input  [4:0]              active_nb;      // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s,bit4=16s
  input                     linkloc;        // Indicates the current data contains the link # field. Its location can be inferred from active_nb
  input                     laneloc;        // Indicates the current data contains the lane # field. Its location can be inferred from active_nb
  input  [3:0]              eqloc;          // Indicates the current data contains one or more of Symbols 6-9 of a TS
  input  [EQTS_WD-1:0]      eqinfo;         // Equalization Information for Symbols 6-9 of EQ TSs and Gen3 TSs
  input                     eieosloc;       // Indicates the current data contains the EIEOS OS Identifier and should be replaced with TS1 OS Identifier

begin
    BuildOsData = in_data;

         case ({active_nb, linkloc, laneloc, eqloc, eieosloc})
        12'b00010_10_0000_0 : BuildOsData[15:8]  = linknum;       // Symbol 1 Link Number
        12'b00010_01_0000_0 : BuildOsData[7:0]   = lanenum;       // Symbol 2 Lane Number
        12'b00010_00_0011_0 : BuildOsData[15:0]  = eqinfo[15:0];  // Symbol 7 Symbol 6 EQ Data
        12'b00010_00_1100_0 : BuildOsData[15:0]  = eqinfo[31:16]; // Symbol 9 Symbol 8 EQ Data
        default  : BuildOsData = in_data;
    endcase
end
endfunction // BuildOsData



// Function returns the bit number of the hot bit in a one hot.
// used for data cycles calculation on int_link_mode
function automatic [3:0]   OneHotToBitNum;
    input   [4:0]   onehot;

begin
    OneHotToBitNum = 0;
    case (onehot)
        5'b00001 :  OneHotToBitNum = 0;
        5'b00010 :  OneHotToBitNum = 1;
        5'b00100 :  OneHotToBitNum = 2;
        default  :  OneHotToBitNum = 0;
    endcase
end
endfunction

// Function to grab a byte from a bus
function automatic [7:0] Bget;
input [DW-1:0]   vector;
input [SLICE_WD-1:0]      index_i;

reg   [LOG2NBYTE-1:0]      index;
begin
    index = index_i[LOG2NBYTE-1:0]; // to avoid spyglass warning
    case (index)
              0 : Bget = vector[0*8+7:0*0];
              1 : Bget = vector[1*8+7:1*8];
              2 : Bget = vector[2*8+7:2*8];
              3 : Bget = vector[3*8+7:3*8];
              4 : Bget = vector[4*8+7:4*8];
              5 : Bget = vector[5*8+7:5*8];
              6 : Bget = vector[6*8+7:6*8];
              7 : Bget = vector[7*8+7:7*8];
        default : Bget = vector[0*8+7:0*0];
    endcase
end
endfunction

function automatic [SLICE_WD-1:0] Calc_pkt_end;
  input  [NW-1:0]   eot_dw;                     // one hot indicating the last Dword
  input  [SLICE_WD:0] data_cycles;                // the number of cycles needed to send one CX_DW of data

  reg    [SLICE_WD:0] pkt_cycles;                 // the number of cycles needed to send this chunk of data
begin
    case (1'b1)
        eot_dw[1]   :  pkt_cycles =  data_cycles;
        eot_dw[0]   :  pkt_cycles =  data_cycles >> 1;
        default     :  pkt_cycles =  data_cycles;
    endcase
  Calc_pkt_end = (pkt_cycles == 6'h0) ? 5'h0 : pkt_cycles - 1;
end
endfunction

assign xmlh_rst_flit_alignment = 1'b0;
assign skp_win                 = 1'b0;
assign eie_win                 = 1'b0;
assign eid_win                 = 1'b0;
assign pid_rcvd_pulse          = 1'b0;
assign eie_win_i               = 1'b0;
assign eid_win_i               = 1'b0;
wire   eie_eid_0               = 1'b0;
always @* begin : eie_eid_win_d_PROC
    eie_win_d                  = 1'b0;
    eid_win_d                  = 1'b0;
    eie_win_d                  = eie_eid_0;
    eid_win_d                  = eie_eid_0;
end // eie_eid_win_d_PROC

wire [11:0] pid_count_0s;
assign      pid_count_0s = 0;
always @* begin : pid_count_0s_PROC
    pid_count = 0;
    pid_count = pid_count_0s;
end // pid_count_0s_PROC

// assertions
// check that each command from the ltssm is executed before we start processing the next command
// active lanes and active_nb should never change when data is being processed
//  chunk_cnt should never be greater than data_cycles;

// xdlh_xmlh_pad[0] should never be set.

`ifndef SYNTHESIS
wire    [(24*8)-1:0]        XBYTE_CURNT_STATE;
wire    [(24*8)-1:0]        XBYTE_NEXT_STATE;
wire    [(24*8)-1:0]        NEXT_CMD;
wire    [(21*8)-1:0]        LTSSM_CMD;
wire    [(21*8)-1:0]        NEXT_PAT;
wire    [5*8-1:0]           XMT_LAYER2_STATE;
wire    [5*8-1:0]           NEXT_XMT_LAYER2_STATE;

assign  XBYTE_CURNT_STATE =
               ( xbyte_curnt_state == S_IDLE                   ) ? "S_IDLE" :
               ( xbyte_curnt_state == S_EIDLE                  ) ? "S_EIDLE" :
               ( xbyte_curnt_state == S_XMT_EIDLE              ) ? "S_XMT_EIDLE" :
               ( xbyte_curnt_state == S_FTS                    ) ? "S_FTS" :
               ( xbyte_curnt_state == S_TS                     ) ? "S_TS" :
               ( xbyte_curnt_state == S_SKIP                   ) ? "S_SKIP" :
               ( xbyte_curnt_state == S_CMP                    ) ? "S_CMP" :
               ( xbyte_curnt_state == S_XPKT_WAIT4_START       ) ? "S_XPKT_WAIT4_START" :
               ( xbyte_curnt_state == S_XPKT_WAIT4_STOP        ) ? "S_XPKT_WAIT4_STOP" :
                                                                   "Bogus";

assign  XBYTE_NEXT_STATE =
               ( xbyte_next_state == S_IDLE                   ) ? "S_IDLE" :
               ( xbyte_next_state == S_EIDLE                  ) ? "S_EIDLE" :
               ( xbyte_next_state == S_XMT_EIDLE              ) ? "S_XMT_EIDLE" :
               ( xbyte_next_state == S_FTS                    ) ? "S_FTS" :
               ( xbyte_next_state == S_TS                     ) ? "S_TS" :
               ( xbyte_next_state == S_SKIP                   ) ? "S_SKIP" :
               ( xbyte_next_state == S_CMP                    ) ? "S_CMP" :
               ( xbyte_next_state == S_XPKT_WAIT4_START       ) ? "S_XPKT_WAIT4_START" :
               ( xbyte_next_state == S_XPKT_WAIT4_STOP        ) ? "S_XPKT_WAIT4_STOP" :
                                                                   "Bogus";

assign  NEXT_CMD =
               ( next_cmd == S_IDLE                   ) ? "S_IDLE" :
               ( next_cmd == S_EIDLE                  ) ? "S_EIDLE" :
               ( next_cmd == S_XMT_EIDLE              ) ? "S_XMT_EIDLE" :
               ( next_cmd == S_FTS                    ) ? "S_FTS" :
               ( next_cmd == S_TS                     ) ? "S_TS" :
               ( next_cmd == S_SKIP                   ) ? "S_SKIP" :
               ( next_cmd == S_CMP                    ) ? "S_CMP" :
               ( next_cmd == S_XPKT_WAIT4_START       ) ? "S_XPKT_WAIT4_START" :
               ( next_cmd == S_XPKT_WAIT4_STOP        ) ? "S_XPKT_WAIT4_STOP" :
                                                                   "Bogus";
assign  LTSSM_CMD =
               ( ltssm_cmd == `SEND_IDLE             ) ? "SEND_IDLE" :
               ( ltssm_cmd == `SEND_EIDLE            ) ? "SEND_EIDLE" :
               ( ltssm_cmd == `XMT_IN_EIDLE          ) ? "XMT_IN_EIDLE" :
               ( ltssm_cmd == `SEND_RCVR_DETECT_SEQ  ) ? "SEND_RCVR_DETECT_SEQ" :
               ( ltssm_cmd == `SEND_TS1              ) ? "SEND_TS1" :
               ( ltssm_cmd == `SEND_TS2              ) ? "SEND_TS2" :
               ( ltssm_cmd == `COMPLIANCE_PATTERN    ) ? "COMPLIANCE_PATTERN" :
               ( ltssm_cmd == `MOD_COMPL_PATTERN     ) ? "MOD_COMPL_PATTERN" :
               ( ltssm_cmd == `SEND_BEACON           ) ? "SEND_BEACON" :
               ( ltssm_cmd == `SEND_N_FTS            ) ? "SEND_N_FTS" :
               ( ltssm_cmd == `NORM                  ) ? "NORM" :
                                                         "Bogus";
assign  NEXT_PAT =
               ( next_pat == `SEND_IDLE             ) ? "SEND_IDLE" :
               ( next_pat == `SEND_EIDLE            ) ? "SEND_EIDLE" :
               ( next_pat == `XMT_IN_EIDLE          ) ? "XMT_IN_EIDLE" :
               ( next_pat == `SEND_RCVR_DETECT_SEQ  ) ? "SEND_RCVR_DETECT_SEQ" :
               ( next_pat == `SEND_TS1              ) ? "SEND_TS1" :
               ( next_pat == `SEND_TS2              ) ? "SEND_TS2" :
               ( next_pat == `COMPLIANCE_PATTERN    ) ? "COMPLIANCE_PATTERN" :
               ( next_pat == `MOD_COMPL_PATTERN     ) ? "MOD_COMPL_PATTERN" :
               ( next_pat == `SEND_BEACON           ) ? "SEND_BEACON" :
               ( next_pat == `SEND_N_FTS            ) ? "SEND_N_FTS" :
               ( next_pat == `NORM                  ) ? "NORM" :
               ( next_pat == `SEND_SKP              ) ? "SEND_SKP" :
                                                         "Bogus";
`endif // SYNTHESIS



`ifndef SYNTHESIS
`endif // !SYNTHESIS

endmodule
