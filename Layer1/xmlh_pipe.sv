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
// ---    $DateTime: 2019/10/11 02:17:59 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_pipe.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit MAC layer PIPE interface.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module xmlh_pipe(
    core_clk,
    core_rst_n,
    cfg_link_capable,

    txdata,
    txdatak,
    txerror,
    txdetectrx_loopback,
    txelecidle,
    tx_g5_lpbk_deassert,
    txcompliance,
    ltssm_lpbk_slave_lut,
    ltssm_in_lpbk_exit_timeout,
    ltssm_in_lpbk,
    ltssm_powerdown,

    phy_mac_phystatus,

    xpipe_txdata,
    xpipe_txdatak,
    xpipe_txdetectrx_loopback,
    xpipe_txelecidle,
    xpipe_txcompliance,
    xpipe_powerdown,

    xpipe_phystatus
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance. Should be 1st parameter.
parameter   REGOUT  = `CX_XMLH_PIPE_REGOUT; // Optional output registration
parameter   NL      = `CX_NL;   // Max number of lanes supported
parameter   NB      = `CX_NB;   // Number of symbols (bytes) per clock cycle
parameter   NBK     = `CX_NBK;  // Number of symbols (bytes) per clock cycle for datak
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)

input                   core_rst_n;
input                   core_clk;
input   [5:0]           cfg_link_capable;   // It is application specific. It needs to be decided by application at implementation
                                            // time. It indicates the x1, x2, x4 capability of a port. This is an output of
                                            // PCIE spec. required config register.

// From transmit MAC
input   [(NL*NB*8)-1:0] txdata;             // 2 bytes parallel transmit data
input   [(NL*NBK)-1:0]  txdatak;            // Indicates K characters
input   [(NL*NB)-1:0]   txerror;            // Indicates Error generation
input                   txdetectrx_loopback;// Enable receiver detect (loopback)
input   [NL-1:0]        txelecidle;         // Enable Transmitter Electical Idle
input                   tx_g5_lpbk_deassert;// deassert loopback signal in LPBK_EXIT_TIMEOUT at gen5 rate
input   [NL-1:0]        txcompliance;       // Set negative running disparity (for compliance pattern)
input   [NL-1:0]        ltssm_lpbk_slave_lut; // lane under test for lpbk slave
input                   ltssm_in_lpbk_exit_timeout;
input                   ltssm_in_lpbk;      // lpbk_active || (lpbk_exit & lpbk_slave)
input   [1:0]           ltssm_powerdown;    // Ltssm powerdown (based on LTSSM state)

// From PIPE phy
input   [NL-1:0]        phy_mac_phystatus;
// To PIPE phy
output  [(NL*NB*8)-1:0] xpipe_txdata;
output  [(NL*NB)-1:0]   xpipe_txdatak;
output  [NL-1:0]        xpipe_txdetectrx_loopback;
output  [NL-1:0]        xpipe_txelecidle;
output  [NL-1:0]        xpipe_txcompliance;
output  [1:0]           xpipe_powerdown;    // 2 bit power state P0/P0s/P1/P2

//
output  [NL-1:0]        xpipe_phystatus;

// Output registering (optional)
wire    [NL-1:0]        xpipe_txdetectrx_loopback;


// Extract txdatak
reg     [(NL*NB)-1:0]  int_txdatak;
assign int_txdatak = txdatak;

parameter N_DELAY_CYLES     = REGOUT ? 1 : 0;
parameter DATAPATH_WIDTH    = (NL*NB*8)  // data
                            + (NL*NB)    // datak
                            + NL         // compliance
                            + NL         // mac_phystatus
                            + NL         // detectrx_loopback
                            + NL         // txelecidle
                            + 2;         // powerdown

// We need to clear this signal quickly
reg             txdetectrx_loopback_d;
reg [NL-1:0]    int_xpipe_txdetectrx_loopback;
wire [1:0]      xpipe_powerdown;
wire [1:0]      int_xpipe_powerdown;
wire [NL-1:0]   ltssm_lpbk_slave_lut_i = |ltssm_lpbk_slave_lut ? ltssm_lpbk_slave_lut : {NL{1'b1}}; // only one lane active in ltssm_lpbk_slave_lut if effect

//         NDEL,          WD,            RESET_VAL                     phystatus, txeidle, powerdown
delay_n

#(N_DELAY_CYLES, DATAPATH_WIDTH,  {{DATAPATH_WIDTH-(NL+NL+3){1'b0}}, 1'b1, {NL{1'b0}}, {NL{1'b1}}, 2'b10}) u0_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({  txdata,    int_txdatak, txcompliance,
                    phy_mac_phystatus, (int_xpipe_txdetectrx_loopback), txelecidle, ltssm_powerdown }), // ltssm_lpbk_slave_lut to get the lane under test for gen5 lpbk.active slave
    .dout       ({  xpipe_txdata,      xpipe_txdatak,  xpipe_txcompliance,
                    xpipe_phystatus, xpipe_txdetectrx_loopback, xpipe_txelecidle, int_xpipe_powerdown})
);

assign xpipe_powerdown = int_xpipe_powerdown;

wire [NL-1:0] lane_en;
assign lane_en[0] = 1'b1;
assign lane_en[1] = cfg_link_capable[1];
assign lane_en[3:2] = cfg_link_capable[2] ? 2'b11 : 2'b00;


wire    txdetectrx_rise;
assign txdetectrx_rise = (txdetectrx_loopback & !txdetectrx_loopback_d);
always @(posedge core_clk or negedge core_rst_n)
begin : drive_txdetectrx_loopback
    integer ln;

    if (!core_rst_n) begin
        int_xpipe_txdetectrx_loopback   <= #TP 0;
        txdetectrx_loopback_d           <= #TP 0;
    end else begin
        for (ln=0; ln<NL; ln=ln+1)
            int_xpipe_txdetectrx_loopback[ln] <= #TP (!lane_en[ln])                                     ? 1'b0 : // always 0 when downsized by cfg_link_capable
 // 1 if txdetectrx_loopback rising at gen5 rate, i.e. lpbk slave in lpbk.active || lpbk.exit
 // always 0 when in LPBK_EXIT_TIMEOUT at txelecidle rising at gen5 rate
                                                     txdetectrx_rise                                    ? 1'b1 :
                                                     (!txelecidle[0] & !txdetectrx_loopback_d)          ? 1'b0 : // Loopback
                                                     (phy_mac_phystatus[ln] && ltssm_powerdown==2'b10)  ? 1'b0 : // Knock down quickly for RxDetect
                                                     int_xpipe_txdetectrx_loopback[ln];
        txdetectrx_loopback_d       <= #TP txdetectrx_loopback;
    end
end

endmodule
