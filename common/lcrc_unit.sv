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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/lcrc_unit.sv#4 $
// -------------------------------------------------------------------------
// ---
// --- Module Description: 
// --- LCRC/ECRC generation and checking on a datapath containing 
// --- data from one tlp only
// --- Output result after one clock cycle, or two clock cycles 
// --- for pipelined architecture if CX_CRC_LATENCY is enabled.
//
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module lcrc_unit
#(
    parameter NW = `CX_NW,  // Number of 32-bit dwords handled by the datapath each clock.
    parameter CRC_MODE = `CX_RDLH,
    // derived parameters
    parameter DW = (32*NW), // Width of datapath in bits.
    // constants
    parameter TP = `TP,      // Clock to Q delay (simulator insurance)
    parameter CRC_LATENCY = 1 // default is 1, can be set to 2 for pipelining to ease timing. Defined in module above.
)
(
    input                   clk,
    input                   rst_n,
    input                   enable_in,    
    input   [DW-1:0]        data_in,
    input   [31:0]          crc_in,
    input   [NW-1:0]        sot_in,
    input   [NW-1:0]        eot_in,
    input   [15:0]          seqnum_in,

    output  [31:0]          crc_out,            //latched output
    output  [31:0]          crc_out_loop,       // feedback output
    output                  crc_out_valid,
    output                  crc_out_match,
    output                  crc_out_match_inv,
    output                  crc_out_sot_or_eot // indicate that the current crc output has been made on a datapath that contains eot and/or sot,
                                               // it is used to select which one of the two crc ouputs must be used to initialize the calculation on the next cycle
);

localparam NW_WD = (NW>8) ? 4 : (NW>4) ? 3 : (NW>2) ? 2 : 1;
localparam LCRC_TX = (CRC_MODE == `CX_XDLH);
localparam LCRC_RX = (CRC_MODE == `CX_RDLH);
localparam ECRC_TX = (CRC_MODE == `CX_XTLH);
localparam ECRC_RX = (CRC_MODE == `CX_RTLH);
localparam CRC_LATENCY_M1 = CRC_LATENCY-1;  //adds a clk cycle delay if crc pipeline on; else 0

//
// init_vec definition: the value at location [32*i +: 32] represents the initial crc state needed when sot[i] = 1.
// exp_vec definition: the value at location [32*i +: 32] represents the expected crc state needed when eot[i] = 1.
//
// The value at location [32*i +: 32] is the initial crc state when sot[i] = 1 and the bits prior to sot[i] contain zeros
// The value is obtained rolling back a crc state of 32'h44F1A90F with a data pattern consisting of i dwords of all 0's.
// The value 32'h44F1A90F is obtained rolling back 8 bits a crc state of 32'hFFFFFFFF with a data pattern consisting of 8'hFB (STP symbol)
// Including the STP symbol is useful to avoid byte oriented shifting of the data when checking the LCRC rx side.
wire [511:0] lcrc_rx_init_vec  = 512'hFD1A39E8A886999E8E7F11E5D4BD8CEB9DA0FA2684E4B2882191D7505A43018B87EB333FB9C482ACE5DE0F537836A8E7E4C10B1FF6B11337C939EC0444F1A90F;

// The value at location [32*i +: 32] is the initial crc state when sot[i] = 1 and the bits prior to sot[i] contain the seqnum and zeros
// The value is obtained rolling back a crc state of 32'hFFFFFFFF with a data pattern consisting of (32*i-16) bits of all 0's.
// This is useful when generating the LCRC tx side, where the 16 bit seqnum is merged into the dword. Location [31:0] is not valid, the sequence number
// in this case is not embedded into the data and its contribution is provided by crc_in
wire [511:0] lcrc_tx_init_vec  = 512'h53FAF40A6E70E6E0915D480F1D008BB94BBEDA739C87E7AF2076D79F4788032DF407266660A0CF2F3298876550DDA75D7535D07568B932F509B9385900000000;

// The value at location [32*i +: 32] is obtained rolling back a crc state of 32'hFFFFFFFF with a data pattern consisting of (i) dwords of all 0's.
// This is useful when checking the ECRC rx side and sot[i] = 1. Location [31:0] correspond to rolling back 0 bits when sot[0] = 1.
wire [511:0] ecrc_rx_init_vec  = 512'hDF27BB8271C48353082FBB794191AF83869D3834E2265DB9CD55919B0D0E66733AA01F608E3D684D5FE50C641470E51CD61C3A65F50B27F746AF6449FFFFFFFF;

wire [DW-1:0] crc_init_vec      = LCRC_RX ? lcrc_rx_init_vec[DW-1:0] :
                                 LCRC_TX ? lcrc_tx_init_vec[DW-1:0] :
                                 ecrc_rx_init_vec[DW-1:0];

// The value at location [32*i +: 32] is the expected crc state for a good tlp when eot[i] = 1 and the bits following END are filled in with zeros
wire [511:0] lcrc_rx_exp_vec  = 512'hC2618B5FBDFE4A950DB94CE9F5EC45D6BF39BE4EA219F925C60D151E4896B32BAE0B3F42C9D7CD8F5F7208F0939A459237C998DFA55EC94B097646889A744E43 >> ((16-NW)*32); 
// "C2618B5F" must be aligned to the highest dword for each datapath widths

// expected constants for ecrc, difference with lcrc is that ecrc doesn't include the effect of the final END symbol
wire [511:0] ecrc_rx_exp_vec  = 512'hC704DD7B6904BB59099C5421552D22C84E26540FFBAC7C3A6811F1FE4A55AF6754B292A97243C868C799DB3E5632EEB0F20F2BCC6D5AEC34EF6EB7DF93394E51 >> ((16-NW)*32); 
// "C704DD7B" must be aligned to the highest dword for each datapath widths

// expected constants for lcrc when there is EDB instead of END
wire [511:0] crc_exp_null_vec = 512'hD8FBA05A3C7720EF10182C7AC4AA1E07B0BF38F96BD78D93973C779D30E3622FDF87A34365D5055CC08964AB6A1BC0DB96360BEAA1D12BCEAF49FDD8098FE865 >> ((16-NW)*32);
wire [DW-1:0] crc_exp_vec      = LCRC_RX ? lcrc_rx_exp_vec[DW-1:0] : ecrc_rx_exp_vec[DW-1:0];

wire [DW-1:0] data_t1 = datatransform_sot(data_in, sot_in, seqnum_in); // fill in zeros prior to sot
wire [DW-1:0] data_t2 = datatransform_eot(data_t1, eot_in); // fill in zeros after eot
wire [DW-1:0] data = (LCRC_RX || ECRC_RX) ? data_t2 : data_t1; // 2nd transform only needed when checking, not needed when generating
wire [31:0] icrc = select_init(crc_in, crc_init_vec, sot_in);
wire [NW-1:0] ieot = eot_in;
wire icrc_sot_or_eot = |(sot_in|eot_in);

wire [DW-1:0] ocrc_lcrc_tx_tmp;
reg  [32*(1<<NW_WD)-1:0] ocrc_lcrc_tx_full; // when NW is not a power of 2 round up to a power of 2


wire [31:0] ocrc;
wire [31:0] ocrc_lcrc_rx;
reg [31:0] ocrc_lcrc_tx;

reg [DW-1:0] idata_lcrc_tx;
wire [DW-1:0] idata_lcrc_rx = data;
wire [DW-1:0] idata = (LCRC_RX || ECRC_RX) ? idata_lcrc_rx : idata_lcrc_tx;


// outputs all intermediate states so that we can pick the correct one depending on eot when generating
DWC_pcie_ctl_bcmmod48
 #(.DATA_WIDTH(DW), .POLY_SIZE(32), .POLY_COEF0(16'h1DB7), .POLY_COEF1(16'h04C1))
    u_crc_lcrc_tx (
// inputs
        .data_in                (flipbits(idata)),
        //.crc_i                  (icrc), // icrc contribution is incorporated into the data
// outputs
        .crc_j                  (ocrc_lcrc_tx_tmp[DW-1:0])
    );
    
always @(*) begin : EXPAND_OCRC_LCRC
  ocrc_lcrc_tx_full = 0;
  ocrc_lcrc_tx_full[DW-1:0] = ocrc_lcrc_tx_tmp;
end


// only outputs the final state so that we can pick the correct expected value depending on eot when checking
DWC_pcie_ctl_bcm48_sv
 #(.DATA_WIDTH(DW), .POLY_SIZE(32), .POLY_COEF0(16'h1DB7), .POLY_COEF1(16'h04C1))
    u_crc_lcrc_rx (
// inputs
        .data_in                (flipbits(idata)),
        .crc_i                  (icrc),
// outputs
        .crc_j                  (ocrc_lcrc_rx)
    );

always @(*) begin : ocrc_lcrc_tx_PROC
    reg [15:0] ieot_ext; // sized to max NW
    reg [DW-1:0] icrc_data;
    integer i;
    ieot_ext = 0;
    ieot_ext[NW-1:0] = ieot;
    icrc_data = 0;
    icrc_data[31:0] = flipbits32(icrc);
    ocrc_lcrc_tx  = ocrc_lcrc_tx_full[32*(NW-1) +: 32]; 
    idata_lcrc_tx = (data ^ icrc_data);
    
    for (i=0; i<NW; i = i+1) begin
        if (ieot_ext[i]) begin
            ocrc_lcrc_tx = ocrc_lcrc_tx_full[32*i +: 32];
            idata_lcrc_tx = (data ^ icrc_data) << (32*(NW-1-i));
        end
    end
end

// when generating crc: inversion and flipping is required for the final crc value, not for intermediate results
assign ocrc = (LCRC_RX || ECRC_RX) ? ocrc_lcrc_rx : ((|ieot) ? flipbits32(~ocrc_lcrc_tx) : ocrc_lcrc_tx);

// register stage at the output of the bcm module
reg [31:0] ocrc_r2;
reg [31:0] ocrc_r;

reg [NW-1:0] oeot_r; 
reg ocrc_sot_or_eot_r; 

//output register for loop. Need continuous loopback for larger packets
always @(posedge clk or negedge rst_n) begin : oreg_seq_PROC
    integer i;
    if (!rst_n) begin
        ocrc_r <= #TP 0;
        oeot_r <= #TP 0;
        ocrc_sot_or_eot_r <= #TP 0;
    end else begin
        if( enable_in ) begin
            ocrc_r <= #TP ocrc;
            oeot_r <= #TP ieot;
            ocrc_sot_or_eot_r <= #TP icrc_sot_or_eot;
        end
    end
end

//output register for latch. Need to latch output to capture and hold CRC only on EOT
always @(posedge clk or negedge rst_n) begin : ocrc_data_PROC //latching data_out to data_valid
    integer i;
    if (!rst_n) begin
            ocrc_r2 <= #TP 0;
    end else begin 
    if ( enable_in && |ieot  && LCRC_TX && (CRC_LATENCY_M1 != 0)) //needs to be enabled only when pipelined data on line and Layer 2 TX mode
            ocrc_r2 <= #TP ocrc;
    else 
            ocrc_r2 <= #TP ocrc_r2;
    end
end

// select expected crc value to be used in the crc matching logic
wire [31:0] ocrc_exp = select_exp(crc_exp_vec, oeot_r);
wire [31:0] ocrc_exp_null = select_exp(crc_exp_null_vec[DW-1:0], oeot_r);
wire ocrc_r_valid = |oeot_r; 

//Output select
wire [31:0] crc_out_tmp;
assign crc_out_tmp = (LCRC_TX && (CRC_LATENCY_M1 != 0)) ? ocrc_r2 : ocrc_r; //selects the value to be used for crc output. output is held for LCRC_TX, for all other cases is updated every clock
// Outputs
assign crc_out = crc_out_tmp;
assign crc_out_loop = ocrc_r;
assign crc_out_match = ocrc_r_valid ? (ocrc_r == ocrc_exp) : 1'b0;
assign crc_out_match_inv = ocrc_r_valid ? (ocrc_r == ocrc_exp_null) : 1'b0;
assign crc_out_sot_or_eot = ocrc_sot_or_eot_r;
assign crc_out_valid = ocrc_r_valid;

//
// Functions
//

// convert one-hot to binary
function automatic [NW_WD-1:0] one_hot_to_bin(input [NW-1:0] one_hot_data);
    integer i;
    begin
        one_hot_to_bin = 0;
        if(NW>1)
            for (i=0; i<NW; i=i+1)
                if (one_hot_data[i])
                    one_hot_to_bin = i;
    end
endfunction

// transform the data by setting to 32'b0 dwords prior to sot
function automatic [DW-1:0] datatransform_sot(input [DW-1:0] data, input [NW-1:0] sot, input [15:0] seqnum);
    integer i;
    reg [NW_WD-1:0] index;
    begin
        datatransform_sot = data;
        if( sot != 0 ) begin
            index = one_hot_to_bin(sot);
            for (i=0; i<NW; i=i+1) begin
                if(i<index)
                    datatransform_sot[32*i +: 32] = 0;
            end
            if( LCRC_TX )
                // when sot is on a dword greater than first dword, embed the seqnum into the data assigning the bits [31:16] of the dword prior to sot
                if(index>0) // when sot[0]=1 the seqnum contribution is provided as icrc
                    for (i=1; i<NW; i=i+1)
                        if(i==index)
                            datatransform_sot[32*i-1 -: 16] = seqnum;
        end
    end
endfunction

// transform the data by setting to 32'b0 dwords after to eot
function automatic [DW-1:0] datatransform_eot(input [DW-1:0] data, input [NW-1:0] eot);
    integer i;
    reg [NW_WD-1:0] index;
    begin
        datatransform_eot = data;
        if( eot != 0 ) begin
            index = one_hot_to_bin(eot);
            for (i=0; i<NW; i=i+1) begin
                if(i>index)
                    datatransform_eot[32*i +: 32] = 0;
            end
        end
    end
endfunction

// select the crc initialization value to use to calculate next state
function automatic [31:0] select_init(input [31:0] crc, input [NW*32-1:0] crc_init_vec, input [NW-1:0] sot);
    integer i;
    begin
        select_init = 0;    
        if( sot == 0 || (sot == 1 && LCRC_TX) ) begin
            select_init = crc;
        end else begin
            for (i=0; i<NW; i=i+1) begin
                if(sot[i]) begin
                    select_init = crc_init_vec[32*i +: 32];
            end
        end
        end
    end
endfunction

// select the crc expected result to use to calculate match/mismatch
function automatic [31:0] select_exp(input [NW*32-1:0] crc_exp, input [NW-1:0] eot);
    integer i;
    begin
        select_exp = 0;
        if( eot == 0 ) begin
            select_exp = 0;
        end else begin
            for (i=0; i<NW; i=i+1) begin
                if(eot[i]) begin
                    select_exp = crc_exp[32*i +: 32];
            end
        end
        end
    end
endfunction

// reflect the bits in the full datapath word
function automatic [DW-1:0] flipbits(input [DW-1:0] data);
    integer i;
    begin
        for (i=0; i<DW; i=i+1) flipbits[i] = data[DW-1-i];
    end
endfunction

function automatic [31:0] flipbits32(input [31:0] data);
    integer i;
    begin
        for (i=0; i<32; i=i+1) flipbits32[i] = data[31-i];
    end
endfunction

endmodule // lcrc_unit
