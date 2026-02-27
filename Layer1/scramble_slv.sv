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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble_slv.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// -- PCI-E scrambler - 16bit version (1 or 2 symbols per cycle)
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module scramble_slv (
    // Inputs
    core_rst_n,
    core_clk,
    scrambler_disable,
    scramble_en,
    data_dv,
    aligned,
    data,
    datak,
    error,
    skipremoved,
    active_nb,
    deskew_ds_g12,

    // Outputs
    scramble_data_dv,
    scramble_aligned,
    scramble_data,
    scramble_data_comma,
    scramble_data_skip,
    scramble_data_skprm,
    scramble_datak,
    scramble_error
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance.
parameter   REGOUT  = 1;        // Optional output registering
parameter   NB      = `CX_NB;   // Number of symbols (bytes) per clock cycle
parameter   NBK     = `CX_NBK;  // Number of symbols (bytes) per clock cycle for datak
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)


// ---------------------------------------------------------------------------------------------------
// IO Declarations
// ---------------------------------------------------------------------------------------------------
input                   core_rst_n;
input                   core_clk;
input                   scrambler_disable;  // disable scrambler
input                   scramble_en;
input                   data_dv;            // data bytes are valid
input                   aligned;            // data bytes are valid
input   [(NB*8)-1:0]    data;               // data bytes
input   [NBK-1:0]       datak;              // K character indication for each byte
input   [NB-1:0]        error;              // error indication for each byte
input                   skipremoved;        // skip symbols removed indication
input   [3:0]           active_nb;
input                   deskew_ds_g12;      // in data stream

output                  scramble_data_dv;   // output is valid
output                  scramble_aligned;   // output is valid
output  [(NB*8)-1:0]    scramble_data;      // data bytes
output  [NB-1:0]        scramble_data_comma;// comma character indication for each byte
output  [NB-1:0]        scramble_data_skip; // skip character indication for each byte
output  [NB-1:0]        scramble_data_skprm;// COM & skipremoved (take lower COM if two COMs are in the clock)
output  [NBK-1:0]       scramble_datak;     // K character indication for each byte
output  [NB-1:0]        scramble_error;     // error indication for each byte

// ---------------------------------------------------------------------------------------------------
// Regs & Wires
// ---------------------------------------------------------------------------------------------------
// Output registers
reg                     scramble_data_dv_r;
reg                     scramble_aligned_r;
reg     [(NB*8)-1:0]    scramble_data_r;
reg     [NB-1:0]        scramble_data_comma_r;
reg     [NB-1:0]        scramble_data_skip_r;
reg     [NB-1:0]        scramble_data_skprm_r;
reg     [NB-1:0]        scramble_datak_r;
reg     [NB-1:0]        scramble_error_r;

// Output (combinational)
wire                    scramble_data_dv_c;
wire                    scramble_aligned_c;
wire    [(NB*8)-1:0]    scramble_data_c;
wire    [NB-1:0]        scramble_data_comma_c;
wire    [NB-1:0]        scramble_data_skip_c;
wire    [NB-1:0]        scramble_data_skprm_c;
wire    [NB-1:0]        scramble_datak_c;
wire    [NB-1:0]        scramble_error_c;

// Internal registers
reg     [15:0]  lfsr;

// Define internal buses based on 2 symbols per clock. When NB=1 only low bits are used.
//parameter   MNB     = 2;        // Maximum supported symbols per cycle

wire [(NB*8)-1:0]       i_data;
wire [(NB-1):0]         i_datak;
wire [(NB-1):0]         i_error;
wire [(NB*8-1):0]       i_scrambled_data;

wire                    comma0;
wire                    skip0;
wire                    bypass0;
wire [15:0]             lfsr_adv8;

wire                    comma1;
wire                    skip1;
wire                    bypass1;
wire [15:0]             lfsr_adv16;






assign i_data   = data  ;
assign i_datak  = datak[NB-1:0] ;
assign i_error  = error ;

assign scramble_data_comma_c = {
                                comma1,
                                comma0
                                };

assign scramble_data_skip_c = {
                                skip1,
                                skip0
                                } | scramble_data_skprm_c;

assign scramble_data_skprm_c =  deskew_ds_g12 ?
                                {
                                skipremoved & comma1,
                                skipremoved & comma0
                                } :
                                {
                                skipremoved & comma1 & ~comma0,
                                skipremoved & comma0
                                };

assign comma0   = (i_datak[0] && (i_data[(0*8)+7:(0*8)] == `COMMA_8B));
assign skip0    = (i_datak[0] && (i_data[(0*8)+7:(0*8)] == `SKIP_8B));
assign bypass0  = (scrambler_disable | i_datak[0]);

assign comma1   = (i_datak[1] && (i_data[(1*8)+7:(1*8)] == `COMMA_8B));
assign skip1    = (i_datak[1] && (i_data[(1*8)+7:(1*8)] == `SKIP_8B));
assign bypass1  = (scrambler_disable | i_datak[1]);


//
// The LFSR logic
//

assign lfsr_adv8    =   comma0          ?   16'hFFFF            :
                        skip0           ?   lfsr                : adv8_1dot0a(lfsr);

assign lfsr_adv16   =   comma1          ?   16'hFFFF            :
                        skip1           ?   lfsr_adv8           : adv8_1dot0a(lfsr_adv8);


always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        lfsr        <= #TP 16'hFFFF;
    else if (data_dv)
               lfsr        <= #TP lfsr_adv16; // expect these to be mutually exclusive when CX_GEN2_DYNAMIC_WIDTH==undef
end


// If the scrambler is not bypassed, scramble the output data (based on spec revision)
assign i_scrambled_data[(0*8)+7:(0*8)]  = bypass0 ? i_data[(0*8)+7:(0*8)] :
                                                    scramble8_1dot0a(lfsr, i_data[(0*8)+7:(0*8)]);

assign i_scrambled_data[(1*8)+7:(1*8)]  = (bypass1         ? i_data[(1*8)+7:(1*8)] :
                                           scramble8_1dot0a(lfsr_adv8, i_data[(1*8)+7:(1*8)]));
//
// Output result
//
assign scramble_data_dv = REGOUT ? scramble_data_dv_r : data_dv;
assign scramble_aligned = REGOUT ? scramble_aligned_r : aligned;
assign scramble_data    = REGOUT ? scramble_data_r  : i_scrambled_data[(NB*8)-1:0];
assign scramble_data_comma = REGOUT ? scramble_data_comma_r  : scramble_data_comma_c;
assign scramble_data_skip  = REGOUT ? scramble_data_skip_r  : scramble_data_skip_c;
assign scramble_data_skprm = REGOUT ? scramble_data_skprm_r  : scramble_data_skprm_c;
assign scramble_datak   = REGOUT ? scramble_datak_r : i_datak[NB-1:0];
assign scramble_error   = REGOUT ? scramble_error_r : i_error[NB-1:0];

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        scramble_data_dv_r              <= #TP 0;
        scramble_aligned_r              <= #TP 0;
        scramble_data_r                 <= #TP 0;
        scramble_data_comma_r           <= #TP 0;
        scramble_data_skip_r            <= #TP 0;
        scramble_data_skprm_r           <= #TP 0;
        scramble_datak_r                <= #TP 0;
        scramble_error_r                <= #TP 0;
    end
    else begin
        if(scramble_en)begin 
            scramble_data_dv_r              <= #TP data_dv;
            scramble_aligned_r              <= #TP aligned;
            scramble_data_comma_r           <= #TP scramble_data_comma_c;
            scramble_data_skip_r            <= #TP scramble_data_skip_c;  
            scramble_data_skprm_r           <= #TP scramble_data_skprm_c;
            scramble_data_r                 <= #TP i_scrambled_data[(NB*8)-1:0];
            scramble_datak_r                <= #TP i_datak[NB-1:0];
            scramble_error_r                <= #TP i_error[NB-1:0];
        end
    end

//-----------------------------------------------------------------------------
//   Scramble functions for the 1.0a version of the standard
//-----------------------------------------------------------------------------

//
// 8 Bit scramble function
//
function automatic [7:0] scramble8_1dot0a;
input   [15:0]  lfsr_bit;
input   [7:0]   inbyte_bit;

reg [15:0] bit_in;
reg [7:0] scrambit;
begin
    scrambit = 8'h00;
    bit_in  = lfsr_bit;
    scrambit[0] = bit_in[15]   ; // 0: 15
    scrambit[1] = bit_in[14]   ; // 1: 14
    scrambit[2] = bit_in[13]   ; // 2: 13
    scrambit[3] = bit_in[12]   ; // 3: 12
    scrambit[4] = bit_in[11]   ; // 4: 11
    scrambit[5] = bit_in[10]   ; // 5: 10
    scrambit[6] = bit_in[ 9]   ; // 6: 9
    scrambit[7] = bit_in[ 8]   ; // 7: 8
    scramble8_1dot0a = scrambit ^ inbyte_bit;
end
endfunction

// function lfsr shift by 8
function automatic [15:0] adv8_1dot0a;
input   [15:0]  bit_in;
begin
    adv8_1dot0a       = 16'h0000;
    adv8_1dot0a  [ 0] = bit_in[ 8]                                          ;   //  0:  8
    adv8_1dot0a  [ 1] = bit_in[ 9]                                          ;   //  1:  9
    adv8_1dot0a  [ 2] = bit_in[10]                                          ;   //  2: 10
    adv8_1dot0a  [ 3] = bit_in[11] ^ bit_in[ 8]                             ;   //  3: 11,  8
    adv8_1dot0a  [ 4] = bit_in[12] ^ bit_in[ 9] ^ bit_in[ 8]                ;   //  4: 12,  9,  8
    adv8_1dot0a  [ 5] = bit_in[13] ^ bit_in[10] ^ bit_in[ 9] ^ bit_in[ 8]   ;   //  5: 13, 10,  9,  8
    adv8_1dot0a  [ 6] = bit_in[14] ^ bit_in[11] ^ bit_in[10] ^ bit_in[ 9]   ;   //  6: 14, 11, 10,  9
    adv8_1dot0a  [ 7] = bit_in[15] ^ bit_in[12] ^ bit_in[11] ^ bit_in[10]   ;   //  7: 15, 12, 11, 10
    adv8_1dot0a  [ 8] = bit_in[ 0] ^ bit_in[13] ^ bit_in[12] ^ bit_in[11]   ;   //  8:  0, 13, 12, 11
    adv8_1dot0a  [ 9] = bit_in[ 1] ^ bit_in[14] ^ bit_in[13] ^ bit_in[12]   ;   //  9:  1, 14, 13, 12
    adv8_1dot0a  [10] = bit_in[ 2] ^ bit_in[15] ^ bit_in[14] ^ bit_in[13]   ;   // 10:  2, 15, 14, 13
    adv8_1dot0a  [11] = bit_in[ 3]              ^ bit_in[15] ^ bit_in[14]   ;   // 11:  3, 15,     14
    adv8_1dot0a  [12] = bit_in[ 4]                           ^ bit_in[15]   ;   // 12:  4,         15
    adv8_1dot0a  [13] = bit_in[ 5]                                          ;   // 13:  5
    adv8_1dot0a  [14] = bit_in[ 6]                                          ;   // 14:  6
    adv8_1dot0a  [15] = bit_in[ 7]                                          ;   // 15:  7
end
endfunction


endmodule
