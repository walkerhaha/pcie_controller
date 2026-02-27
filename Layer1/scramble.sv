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
// ---    $DateTime: 2020/01/17 02:36:30 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// -- PCI-E scrambler - Top-level
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module scramble(
// ---- inputs ---------------
    core_rst_n,
    core_clk,
    cfg_elastic_buffer_mode,
    scrambler_disable,
    data_dv,
    data,
    datak,
    error,
    rxskipremoved,
    active_nb,
    aligned,
    latched_smlh_link_up,
    latched_flip_ctrl,
    smlh_lane_flip_ctrl,
    deskew_ds_g12,
    lanes_active,

// ---- outputs ---------------
    scramble_data_dv,
    scramble_aligned,
    scramble_data,
    scramble_data_comma,
    scramble_data_skip,
    scramble_data_skprm,
    scramble_datak,
    scramble_error
);
parameter   INST                          = 0;         // The uniquifying parameter for each port logic instance.
parameter   REGOUT                        = 1;         // Optional output registering
parameter   GEN3_REGIN                    = 1;         // Optional input registering for 128b/130b encoding
parameter   GEN3_REGOUT                   = 1;         // Optional output registering for 128b/130b encoding
parameter   CALC_PARITY_BEFORE_SCRAMBLE   = 0;         // Select parity of scrambler input data or scrambler output data
parameter   SKIP_ALIGN                    = 0;         // Align LFSR values in SKP OS with current LFSR values (8s mode only)
parameter   NL                            = `CX_NL;    // Max number of lanes supported
parameter   NB                            = `CX_NB;    // Number of symbols (bytes) per clock cycle
parameter   NBK                           = `CX_NBK;   // Number of symbols (bytes) per clock cycle for datak
parameter   AW                            = `CX_ANB_WD;// Width of the active number of bytes
parameter   L2NL                          = NL==1 ? 1 : `CX_LOGBASE2(NL);

input                   core_rst_n;
input                   core_clk;
input                   cfg_elastic_buffer_mode;
input                   scrambler_disable;  // This will always affect 2 bytes when in 2S mode (NB=2)
input   [NL-1:0]        data_dv;            // data bytes are valid
input   [(NL*NB*8)-1:0] data;               // data bytes
input   [(NL*NBK)-1:0]  datak;              // K character indication for each byte
input   [(NL*NB)-1:0]   error;              // error indication for each byte
input   [NL-1:0]        rxskipremoved;      // skip symbol removed flag
input   [AW-1:0]        active_nb;
input   [NL-1:0]        aligned;                      //gates: must revisit
input                   latched_smlh_link_up;
input   [L2NL-1:0]      latched_flip_ctrl;   //latch smlh_lane_flip_ctrl at the rising edge of smlh_link_up
input   [L2NL-1:0]      smlh_lane_flip_ctrl;
input    [NL-1:0]       lanes_active;
input    [NL-1:0]       deskew_ds_g12;             // in data stream

output  [NL-1:0]        scramble_data_dv;   // data bytes are valid
output  [NL-1:0]        scramble_aligned;   // data bytes are valid
output  [(NL*NB*8)-1:0] scramble_data;      // data bytes
output  [(NL*NB)-1:0]   scramble_data_comma; // comma character indication for each byte
output  [(NL*NB)-1:0]   scramble_data_skip; // skip character indication for each byte
output  [(NL*NB)-1:0]   scramble_data_skprm; // skp symbol removed aligned with the lower COM
output  [(NL*NBK)-1:0]  scramble_datak;     // K character indication for each byte
output  [(NL*NB)-1:0]   scramble_error;     // error indication for each byte

localparam TP     = `TP;
wire    [NL-1:0]         scramble_g12_data_dv;
wire    [NL-1:0]         scramble_g12_aligned;
wire    [(NL*NB*8)-1:0]  scramble_g12_data;
wire    [(NL*NB)-1:0]    scramble_g12_data_comma;
wire    [(NL*NB)-1:0]    scramble_g12_data_skip;
wire    [(NL*NB)-1:0]    scramble_g12_data_skprm;
wire    [(NL*NBK)-1:0]   scramble_g12_datak;
wire    [(NL*NB)-1:0]    scramble_g12_error;

assign {scramble_data_dv, scramble_aligned, scramble_datak, scramble_data, scramble_data_comma, scramble_data_skip, scramble_data_skprm, scramble_error} = 
                            {scramble_g12_data_dv, scramble_g12_aligned, scramble_g12_datak, scramble_g12_data, scramble_g12_data_comma, scramble_g12_data_skip, scramble_g12_data_skprm, scramble_g12_error};

// Generate Gen1/2 or Gen3/4 scrambler enable


reg     [NL-1:0]               g12_scramble_en;      // scramble enable when data rate is Gen1/2

reg      [NL-1:0]               g12_data_dv;            // data bytes are valid when data rate is Gen1/2
reg      [(NL*NB*8)-1:0] g12_data;             // data when data rate is Gen1/2
reg      [(NL*NBK)-1:0]    g12_datak;

integer                     lane_num;

always@* begin
        g12_scramble_en = lanes_active;
        g12_data_dv = data_dv;
        g12_data= data;
        g12_datak= datak;
end

// up to here : Generate Gen1/2 or Gen3/4 scrambler enable

// gen1/gen2 scrambler
scramble_slv
 #(INST, REGOUT) u_scramble_slv[NL-1:0] (
// ---- inputs ---------------
    .core_rst_n                 (core_rst_n),
    .core_clk                   (core_clk),
    .scrambler_disable          (scrambler_disable),
    .scramble_en                (g12_scramble_en),
    .data_dv                    (g12_data_dv[NL-1:0]),
    .data                       (g12_data[(NL*NB*8)-1:0]),
    .datak                      (g12_datak[(NL*NBK)-1:0]),
    .error                      (error[(NL*NB)-1:0]),
    .skipremoved                (rxskipremoved[NL-1:0]),
    .active_nb                  (active_nb[3:0]),
    .aligned                    (aligned[NL-1:0]),
    .deskew_ds_g12              (deskew_ds_g12[NL-1:0]),

// ---- outputs ---------------
    .scramble_data_dv           (scramble_g12_data_dv[NL-1:0]),
    .scramble_aligned           (scramble_g12_aligned[NL-1:0]),
    .scramble_data              (scramble_g12_data[(NL*NB*8)-1:0]),
    .scramble_data_comma        (scramble_g12_data_comma[(NL*NB)-1:0]),
    .scramble_data_skip         (scramble_g12_data_skip[(NL*NB)-1:0]),
    .scramble_data_skprm        (scramble_g12_data_skprm[(NL*NB)-1:0]),
    .scramble_datak             (scramble_g12_datak[(NL*NBK)-1:0]),
    .scramble_error             (scramble_g12_error[(NL*NB)-1:0])
);



endmodule
