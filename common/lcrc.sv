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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/lcrc.sv#6 $
// -------------------------------------------------------------------------
// ---
// --- Module Description: 
// --- LCRC/ECRC generation and checking for 32b/64b/128b/256b/512b.
// --- Output result after CX_CRC_LATENCY cycles ; 1: no pipeline,2: pipeline
// --- The max number of independent CRCs which can be output based on the 
// --- lcrc module location and parameters is presented in table below.
//            ------------------------  
//           |NOUT|rdlh rtlh xtlh xdlh|
//           |------------------------|
//           |32b  |1   1    1    1   |
//           |64b  |1   1    1    1   |
//           |128b |1   1    2    2   |
//           |256b |2   2    2    2   |
//           |512b |4   4    2    2   |
//            ------------------------  
//
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module lcrc
#(
    parameter NW   = `CX_NW,               // Number of 32-bit dwords handled by the datapath each clock.
    parameter CRC_MODE = `CX_XDLH,         // select appropriate functionality depending on where this module is instantiated
    parameter NOUT = 2,                    // number of outputs, determines how many independent CRCs can exist at the output interface    
    parameter OPTIMIZE_FOR_1SOT_1EOT = 1,  // simplifying assumption of at most one sot followed by one eot, i.e. handling of one tlp at a time each clock
                                           // should be set to 0 for RDLH/RTLH instance and XDLH/XTLH 128/256, set to 1 for XDLH/XTLH 64/32
    parameter CRC_LATENCY = 1,             // default is 1, can be set to 2 for pipelining to ease timing. Defined in module above.
    // derived parameters
    parameter DW   = (32*NW)               // Width of datapath in bits.
)
(
    input                   clk,
    input                   rst_n,
    input                   enable_in,
    input   [DW-1:0]        data_in,
    input   [15:0]          seqnum_in_0, // already in the format {[7:0], 4'h0, [11:8]}
    input   [15:0]          seqnum_in_1,
    input   [NW-1:0]        sot_in,
    input   [NW-1:0]        eot_in,

    output  [NOUT*32-1:0]   crc_out,              // used in XDLH, XTLH
    output  [NOUT-1:0]      crc_out_valid,        // used in XTLH, RTLH
    output  [NOUT-1:0]      crc_out_match,        // used in RDLH, RTLH
    output  [NOUT-1:0]      crc_out_match_inv     // used in RDLH
);

parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)

localparam LCRC_TX = (CRC_MODE == `CX_XDLH);
localparam LCRC_RX = (CRC_MODE == `CX_RDLH);
localparam ECRC_TX = (CRC_MODE == `CX_XTLH);
localparam ECRC_RX = (CRC_MODE == `CX_RTLH);
localparam OPTIMIZE_FOR_1SOT_2EOT = (LCRC_TX || ECRC_TX);  // simplifying assumption of at most one sot and two eot, true on tx side
localparam CRC_LATENCY_M1 = CRC_LATENCY-1;                 //adds a clk cycle delay if crc pipeline on; else 0

localparam NW_SEL = (NW == 16) ? 10 : (NW == 8) ? 2 : 1;   //selects the input bus sizes for lcrc_2 for 512/256

reg [NW-1:0] sot_in_0, sot_in_1, eot_in_0, eot_in_1;
wire crc_out_sot_or_eot_0, crc_out_sot_or_eot_1;
wire [31:0] crc_in_lcrc_rx;
wire [31:0] crc_in_lcrc_tx;
wire [31:0] crc_in_ecrc_rx;
wire [31:0] crc_in_ecrc_tx;
wire [31:0] crc_in;
wire [31:0] crc_in_2;

// these are only used in 512 RDLH/RTLH
reg [NW-1:0] sot_in_3, eot_in_3;
wire         crc_out_sot_or_eot_3;
wire [31:0]  crc_out_3_loop;

// these are only used in 512b/256b RDLH/RTLH
reg [NW-1:0] sot_in_2, eot_in_2;
wire         crc_out_sot_or_eot_2;
wire [31:0]  crc_out_2_loop;
wire [31:0]  crc_in_seqnum_0, crc_in_seqnum_2;

reg [15:0]   int_seqnum_in_0, int_seqnum_in_1, int_seqnum_in_2;
reg [31:0]   int_seqnum_in;

wire [31:0] crc_out_0_loop; //output feedback lcrc_0
wire [31:0] crc_out_1_loop; //output feedback lcrc_1

//delayed control signals
wire enable_in_r; //enable delayed input to lcrc_unit
wire [NW-1:0] sot_in_r; //pipelined later but need sot_in_r and _r[0] to delay enable
wire [NW-1:0] sot_in_3_r, eot_in_3_r; //delayed control signals
wire [31:0] crc_in_seqnum_0_r, crc_in_seqnum_2_r;

// outputs - 32/64/128/256/512
wire [31:0] crc_out_0, crc_out_1;
wire crc_out_valid_0, crc_out_valid_1;
wire crc_out_match_0, crc_out_match_1;
wire crc_out_match_inv_0, crc_out_match_inv_1;

// outputs - these are only used in 512 RDLH/RTLH
wire [31:0] crc_out_2, crc_out_3;
wire crc_out_valid_2, crc_out_valid_3;
wire crc_out_match_2, crc_out_match_3;
wire crc_out_match_inv_2, crc_out_match_inv_3;

//delayed signals
wire [15:0] int_seqnum_in_0_r, int_seqnum_in_1_r, int_seqnum_in_2_r; 
wire [NW-1:0] sot_in_0_r, sot_in_1_r;
wire [NW-1:0] eot_in_0_r, eot_in_1_r;
wire [NW-1:0] sot_in_2_r, eot_in_2_r;
wire [DW-1:0] data_in_r; //delayed input

// Spyglass conditional fix
wire [127:0]    crc_out_int;
wire [3:0]      crc_out_valid_int;
wire [3:0]      crc_out_match_int;
wire [3:0]      crc_out_match_inv_int;

assign crc_out           = crc_out_int[NOUT*32-1:0];
assign crc_out_valid     = crc_out_valid_int[NOUT-1:0];
assign crc_out_match     = crc_out_match_int[NOUT-1:0];
assign crc_out_match_inv = crc_out_match_inv_int[NOUT-1:0];

// CTRL Path
delay_n
 //one clk cycle delay added if crc pipeline on, else 0 delay
#(.N(CRC_LATENCY_M1), .WD(1+NW+NW)) u_crc_delay_ctrl (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear      (1'b0),
    .din        ({enable_in, sot_in, sot_in_2}),
    .dout       ({enable_in_r, sot_in_r, sot_in_2_r})
);

delay_n_w_enable
 //one clk cycle delay added if crc pipeline on, else 0 delay
#(.N(CRC_LATENCY_M1), .WD(DW+32+32)) u_crc_delay_w_enable_ctrl (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear      (1'b0),
    .en         (enable_in),
    .din        ({data_in, crc_in_seqnum_0, crc_in_seqnum_2}),
    .dout       ({data_in_r, crc_in_seqnum_0_r, crc_in_seqnum_2_r})
);

//
// separate sot and eot into components sot_0/1/2 and eot_0/1 containing at most one sot and one eot
//
always @(*) begin : sot_eot_split_PROC
    integer i;
    reg [2:0] sot_in_num, eot_in_num;
    sot_in_num = 0;
    eot_in_num = 0;
    sot_in_0 = 0;
    sot_in_1 = 0;
    sot_in_2 = 0;
    eot_in_0 = 0;
    eot_in_1 = 0;
    int_seqnum_in_0 = 0;
    int_seqnum_in_1 = 0;
    int_seqnum_in_2 = 0;
    
    int_seqnum_in = 0;
    int_seqnum_in = {seqnum_in_1, seqnum_in_0};
    int_seqnum_in[7:4] = 0; // ensure the 0 bits are seen by synthesis
    int_seqnum_in[23:20] = 0;

    //$display("%t sot=%b eot=%b", $time, sot_in, eot_in);
    for ( i=0; i<NW; i=i+1 ) begin
        if ( sot_in[i] ) begin
            if ( OPTIMIZE_FOR_1SOT_1EOT ) begin
                begin sot_in_0[i] = 1'b1; sot_in_num = 1; int_seqnum_in_0 = int_seqnum_in[15:0]; end  // ------s-  first found is sot
            end else if ( OPTIMIZE_FOR_1SOT_2EOT ) begin
                case ( { eot_in_num[0] } )
                    {1'b0} : begin sot_in_0[i] = 1'b1; sot_in_num = 1; int_seqnum_in_0 = int_seqnum_in[15:0]; end  // ------s-  first found is sot
                    default : begin sot_in_1[i] = 1'b1; sot_in_num = 1; int_seqnum_in_1 = int_seqnum_in[15:0]; end  // --s---e-  sot after eot, note that we load sot_in_1 instead of sot_in_0
                endcase
            end else begin
                case ( { 1'b0, sot_in_num[0], eot_in_num[1:0] } )
                    {2'b00, 2'b00} : begin sot_in_0[i] = 1'b1; sot_in_num = 1; int_seqnum_in_0 = int_seqnum_in[15:0]; end  // [s]---------------  first found is sot
                    {2'b00, 2'b01} : begin sot_in_1[i] = 1'b1; sot_in_num = 1; int_seqnum_in_1 = int_seqnum_in[15:0]; end  // [s]e--------------  sot after eot, 
                  //{2'b01, 2'b00}                                                                                            [s]---s-----------  sot after sot is illegal
                    default : begin sot_in_0[i] = 1'b0; sot_in_1[i] = 1'b0; sot_in_2[i] = 1'b0; sot_in_num = 0; int_seqnum_in_0 = 0; int_seqnum_in_1 = 0; int_seqnum_in_2 = 0; end
                endcase
            end
        end else if ( eot_in[i] ) begin
            if ( OPTIMIZE_FOR_1SOT_1EOT ) begin
                begin eot_in_0[i] = 1'b1; eot_in_num = 1; end // ------e-  first found is eot or ---e--s-  eot after sot
            end else if ( OPTIMIZE_FOR_1SOT_2EOT ) begin
                case ( { eot_in_num[0] } )
                    {1'b0} : begin eot_in_0[i] = 1'b1; eot_in_num = 1; end // ------e-  first found is eot
                    default : begin eot_in_1[i] = 1'b1; eot_in_num = 2; end // -e-s--e-  eot after sot after eot
                endcase
            end else begin
                case ( { 1'b0, sot_in_num[0], 1'b0, eot_in_num[0] } )
                    {2'b00, 2'b00} : begin eot_in_0[i] = 1'b1; eot_in_num = 1; end     // [e]---------------  first found is eot
                  //{2'b00, 2'b01}                                                         [e]---e-----------  eot after eot is illegal
                    {2'b01, 2'b00} : begin eot_in_0[i] = 1'b1; eot_in_num = 1; end     // [e]---s-----------  eot after sot
                    default : begin eot_in_0[i] = 1'b0; eot_in_1[i] = 1'b0; eot_in_num = 0; end
                endcase
            end
        end
    end // for i ...
    if( ECRC_RX || ECRC_TX ) begin //ECRC: no seqnum
        int_seqnum_in_0 = 0;
        int_seqnum_in_1 = 0;
        int_seqnum_in_2 = 0;
    end // ECRC_RX || ECRC_TX
    if( OPTIMIZE_FOR_1SOT_1EOT ) begin  // simplifying assumption for handling no more than one packet
        sot_in_0 = sot_in;
        sot_in_1 = 0;
        sot_in_2 = 0;
        sot_in_num[1] = 0;
        eot_in_0 = eot_in;
        eot_in_1 = 0;
        eot_in_num[1] = 0;
        int_seqnum_in_0 = int_seqnum_in[15:0];
        int_seqnum_in_1 = 0;
        int_seqnum_in_2 = 0;
    end
    if( OPTIMIZE_FOR_1SOT_2EOT ) begin  // simplifying assumption for handling no more than two packets
        sot_in_2 = 0;
        sot_in_num[1] = 0;
        int_seqnum_in_2 = 0;
    end
end

// Select which crc result to use from previous cycle to initialize the calculation for the current cycle.
// For 32b the second instance of the crc unit module is never used
// For 64b/128b the second instance of the crc unit module is never used
// For 256b the fourth instance of the crc unit module is never used
// For 512b RDLH/RTLH all four modules can be in use                                                             
assign crc_in_lcrc_rx = 
                    ((NW==1) || OPTIMIZE_FOR_1SOT_1EOT==1) ? crc_out_0_loop : 
                    ((NW==8) && OPTIMIZE_FOR_1SOT_2EOT==0) ? (crc_out_sot_or_eot_2 ? crc_out_2_loop : (crc_out_sot_or_eot_1 ? crc_out_1_loop : crc_out_0_loop)) :
                    ((NW==16) && OPTIMIZE_FOR_1SOT_2EOT==0) ? (crc_out_sot_or_eot_3 ? crc_out_3_loop : (crc_out_sot_or_eot_2 ? crc_out_2_loop : (crc_out_sot_or_eot_1 ? crc_out_1_loop : crc_out_0_loop))) :
                    (crc_out_sot_or_eot_1 ? crc_out_1_loop : crc_out_0_loop);


// when sot[0]=1 the seqnum contribution is passed in as crc input state.
assign crc_in_lcrc_tx = sot_in_r[0] ? crc_in_seqnum_0_r : crc_in_lcrc_rx; 

assign crc_in = LCRC_TX ? crc_in_lcrc_tx : crc_in_lcrc_rx;

// u_lcrc_2 is only used when there is an sot, in which case in RX mode the crc input is irrelevant,
// for TX mode the crc input is needed for the seqnum contribution. Should be [6] for 512/256. Unused for others.

assign crc_in_2 = LCRC_TX ? ((OPTIMIZE_FOR_1SOT_1EOT==1 || OPTIMIZE_FOR_1SOT_2EOT==1) ? 32'b0 : (sot_in_2_r[NW-NW_SEL] ? crc_in_seqnum_2_r : 32'b0)) : 32'b0; 

reg [NW-1:0] int_sot_in_reg;
reg [NW-1:0] int_eot_in_reg;
reg [15:0]   int_seqnum_in_16lsb_reg; // if NW=<4 int_seqnum_in_reg[31:16] is 0 always. No variation.
always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      int_sot_in_reg <= #TP 0;
      int_eot_in_reg <= #TP 0;
      int_seqnum_in_16lsb_reg <= #TP 0;
    end else begin
      int_sot_in_reg <= #TP sot_in;
      int_eot_in_reg <= #TP eot_in;
      int_seqnum_in_16lsb_reg <= #TP  int_seqnum_in[15:0];
    end

wire crc_delay_inputs_en;
assign  crc_delay_inputs_en = ( (int_sot_in_reg != sot_in) || (int_eot_in_reg != eot_in) 
                                || (int_seqnum_in_16lsb_reg != int_seqnum_in[15:0])
                              );

delay_n_w_enable
 //one clk cycle delay added if crc pipeline on, else 0 delay
#(.N(CRC_LATENCY_M1), .WD(16+16+16+NW+NW+NW+NW
                 ))
 u_crc_delay_inputs (
    .clk            (clk),
    .rst_n          (rst_n),
    .clear          (1'b0),
    .en             (crc_delay_inputs_en), 
    .din            ({int_seqnum_in_0,   int_seqnum_in_1,   int_seqnum_in_2,   sot_in_0,   sot_in_1,   eot_in_0,   eot_in_1   
                  }),

    .dout           ({int_seqnum_in_0_r, int_seqnum_in_1_r, int_seqnum_in_2_r, sot_in_0_r, sot_in_1_r, eot_in_0_r, eot_in_1_r 
                  })
);

wire [DW-1:((NW-NW_SEL)*32)] data_in_r_2= data_in_r[DW-1:((NW-NW_SEL)*32)]; // u_lcrc_2 [DW-1:192] for 512/256 else dont care 


assign eot_in_2_r = 0;

assign crc_out_2_loop = 0;
assign crc_out_sot_or_eot_2 = 0;
assign crc_out_3_loop = 0;
assign crc_out_sot_or_eot_3 = 0;

// this is used on the second packet present on the datapath
lcrc_unit
 #(.NW(NW), .CRC_MODE(CRC_MODE), .CRC_LATENCY(CRC_LATENCY)) u_lcrc_1 (
// inputs
        .clk                (clk),
        .rst_n              (rst_n),
        .enable_in          (enable_in_r),
        .data_in            (data_in_r),
        .sot_in             (sot_in_1_r),
        .eot_in             (eot_in_1_r),
        .seqnum_in          (int_seqnum_in_1_r),
        .crc_in             (crc_in),
// outputs
        .crc_out_loop       (crc_out_1_loop),    //feedback path
        .crc_out            (crc_out_1),         //output path
        .crc_out_valid      (crc_out_valid_1),
        .crc_out_match      (crc_out_match_1),
        .crc_out_match_inv  (crc_out_match_inv_1),
        .crc_out_sot_or_eot (crc_out_sot_or_eot_1)
    );


// this is used on the first packet present on the datapath
lcrc_unit
 #(.NW(NW), .CRC_MODE(CRC_MODE), .CRC_LATENCY(CRC_LATENCY)) u_lcrc_0 (
// inputs
        .clk                (clk),
        .rst_n              (rst_n),
        .enable_in          (enable_in_r), 
        .data_in            (data_in_r),
        .sot_in             (sot_in_0_r),
        .eot_in             (eot_in_0_r),
        .seqnum_in          (int_seqnum_in_0_r),
        .crc_in             (crc_in),
// outputs
        .crc_out_loop       (crc_out_0_loop),     //feedback path
        .crc_out            (crc_out_0),          //output path
        .crc_out_valid      (crc_out_valid_0),
        .crc_out_match      (crc_out_match_0),
        .crc_out_match_inv  (crc_out_match_inv_0),
        .crc_out_sot_or_eot (crc_out_sot_or_eot_0)
    );

// Output declarations
assign crc_out_int           = (NOUT==4) ? ({crc_out_3, crc_out_2, crc_out_1, crc_out_0})                         : (NOUT==2) ? ({64'b0, crc_out_1, crc_out_0})            : {96'b0, crc_out_0};
assign crc_out_valid_int     = (NOUT==4) ? ({crc_out_valid_3, crc_out_valid_2, crc_out_valid_1, crc_out_valid_0}) : (NOUT==2) ? ({2'b0, crc_out_valid_1, crc_out_valid_0}) : {3'b0, crc_out_valid_0};
assign crc_out_match_int     = (NOUT==4) ? ({crc_out_match_3, crc_out_match_2, crc_out_match_1, crc_out_match_0}) : (NOUT==2) ? ({2'b0, crc_out_match_1, crc_out_match_0}) : {3'b0, crc_out_match_0};
assign crc_out_match_inv_int = (NOUT==4) ? ({crc_out_match_inv_3, crc_out_match_inv_2, crc_out_match_inv_1, crc_out_match_inv_0}) : (NOUT==2) ? ({2'b0, crc_out_match_inv_1, crc_out_match_inv_0}) : {3'b0, crc_out_match_inv_0};

//
// These are used in lcrc_tx mode only to generate the crc_state of the seqnum
// Since there are no conditions where the results are both needed on the same cycle the implementation with
// two separate modules could be replaced by one single module with the data_in input driven by int_seqnum_in_2 or
// int_seqnum_in_0, depending on the conditions. Results are never needed on same cycle because in 256b if we have a third
// packet starting we cannot have the first packet also starting on the same cycle, hence sot[0]=0
//
DWC_pcie_ctl_bcm48_sv
 #(.DATA_WIDTH(16), .POLY_SIZE(32), .POLY_COEF0(16'h1DB7), .POLY_COEF1(16'h04C1)) u_lcrc_seqnum_2 (
// inputs
        .data_in                (flipbits16(int_seqnum_in_2)),
        .crc_i                  (32'hffffffff),
// outputs
        .crc_j                  (crc_in_seqnum_2)  // used as crc input for u_lcrc_2 when sot[6]==1
    );

DWC_pcie_ctl_bcm48_sv
 #(.DATA_WIDTH(16), .POLY_SIZE(32), .POLY_COEF0(16'h1DB7), .POLY_COEF1(16'h04C1)) u_lcrc_seqnum_0 (
// inputs
        .data_in                (flipbits16(int_seqnum_in_0)),
        .crc_i                  (32'hffffffff),
// outputs
        .crc_j                  (crc_in_seqnum_0)  // used as crc input for u_lcrc_0 when sot[0]==1
    );

function automatic [15:0] flipbits16(input [15:0] data);
    integer i;
    begin
        for (i=0; i<16; i=i+1) flipbits16[i] = data[15-i];
    end
endfunction

endmodule //lcrc
