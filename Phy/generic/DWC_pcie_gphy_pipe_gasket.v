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
// ---    $DateTime: 2020/10/14 01:42:33 $
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pipe_gasket.v#20 $
// -------------------------------------------------------------------------
// --- Module Description: Frequency step-up/down module
// -----------------------------------------------------------------------------

module DWC_pcie_gphy_pipe_gasket #(
   parameter PIPE_NB    = 8,
   parameter TP         = 0,
   parameter WIDTH_WD   = 0,
   parameter RXSB_WD    = 1,
   parameter PIPE_DATA_WD   = -1,
   parameter TXEI_WD        = -1
) (
// ---- inputs ---------------
   input                         int_clk,
   input                         txclk,   
   input                         recvdclk_pipe,
   input                         phy_rst_n,
   input                         pclk,
   input                         lock,
   input                         pclk_mode_input,
   input                         lane_disabled,
   input [PIPE_DATA_WD-1:0]      phy_mac_rxdata,
   input                         phy_mac_rxdatak,
   input                         phy_mac_rxvalid,
   input [2:0]                   phy_mac_rxstatus,
   input                         phy_mac_phystatus,
   input [7:0]                   phy_mac_ebuf_location,
   input [1:0]                   mac_phy_pclkreq_n,
   input                         rxelecidle_disable,
   input                         txcommonmode_disable,
   input [WIDTH_WD-1:0]          mac_phy_width,
   input [3:0]                   mac_phy_pclk_rate,
   input                         phy_mac_rxdatavalid,
   input                         P1X_to_P1_exit_mode,            // 0 = any type ; 1 = always as P2 exit
   input                         randomize_P1X_to_P1,
   input                         phy_mac_rxstartblock,
   input [1:0]                   phy_mac_rxsynchdr,
   input                         phy_mac_pipe_rxdatavalid,
   input [(PIPE_NB*PIPE_DATA_WD)-1:0]       mac_phy_txdata,
   input [PIPE_NB-1:0]           mac_phy_txdatak,
   input                         mac_phy_txdetectrx_loopback,
   input [TXEI_WD-1:0]           mac_phy_txelecidle,
   input                         mac_phy_txcompliance,
   input [3:0]                   mac_phy_powerdown,
   input [2:0]                   mac_phy_rate,
   input                         mac_phy_rxpolarity,
   input                         mac_phy_txdatavalid,
   input                         mac_phy_txdeemph,
   input [2:0]                   mac_phy_txmargin,
   input                         mac_phy_txswing,
   input                         mac_phy_txstartblock,
   input [1:0]                   mac_phy_txsynchdr,
   input                         smlh_blockaligncontrol,
   input                         mac_phy_pipe_txdatavalid,
   
   input                         phy_mac_pclkchangeok,

   input                         serdes_arch,
   input [WIDTH_WD-1:0]          rxwidth,

// ---- outputs ---------------
   output [(PIPE_NB*PIPE_DATA_WD)-1:0]      sdown_phy_mac_rxdata,
   output [PIPE_NB-1:0]          sdown_phy_mac_rxdatak,
   output                        sdown_phy_mac_rxvalid,
   output [2:0]                  sdown_phy_mac_rxstatus,
   output                        sdown_phy_mac_phystatus,
   output [7:0]                  sdown_phy_mac_ebuf_location,
   output                        sdown_phy_mac_rxdatavalid,
   output [RXSB_WD-1:0]          sdown_phy_mac_rxstartblock,
   output [RXSB_WD*2-1:0]        sdown_phy_mac_rxsynchdr,
   output reg                    sdown_phy_mac_pclkchangeok,
`ifdef GPHY_ESM_SUPPORT
  input                          esm_enable,
  input  [6:0]                   esm_data_rate0,
  input  [6:0]                   esm_data_rate1,
`endif // GPHY_ESM_SUPPORT
   output  [PIPE_DATA_WD-1:0]                 sup_mac_phy_txdata,
   output                        sup_mac_phy_txdatak,
   output                        sup_mac_phy_txdetectrx_loopback,
   output                        sup_mac_phy_txelecidle,
   output reg                    sup_mac_phy_txcompliance,
   output reg [2:0]              sup_mac_phy_rate,
   output reg [WIDTH_WD-1:0]     sup_mac_phy_width,
   output reg [3:0]              sup_mac_phy_pclk_rate,

   output reg                    sup_mac_phy_txdeemph,
   output reg [2:0]              sup_mac_phy_txmargin,
   output reg                    sup_mac_phy_txswing,
   output reg                    sup_mac_phy_txstartblock,
   output reg [1:0]              sup_mac_phy_txsynchdr,
   output reg                    sup_smlh_blockaligncontrol,
   output reg                    sup_mac_phy_txdatavalid,
   output reg                    sup_mac_phy_rxpolarity

);

// local params
localparam MAX_NB           = `GPHY_MAX_NB;
localparam MAX_RXSB_WD      = `GPHY_MAX_RXSB_WD;
wire mux_pclk;
assign mux_pclk = serdes_arch ? recvdclk_pipe : pclk;

// -----------------------------------------------------------------------------
// internal signals
// -----------------------------------------------------------------------------
wire                        rx_dst_byte_enable_wire_change;
wire    [MAX_NB-1:0]        rx_dst_byte_enable_wire_shift;
wire    [MAX_NB-1:0]        rx_dst_byte_enable_wire;
reg     [MAX_NB-1:0]        rx_dst_byte_enable;
reg     [3:0]               mac_phy_powerdown_r;
reg                         P1X_to_P1_transition;
wire                        phy_mac_phystatus_negedge;

reg     [PIPE_DATA_WD-1:0]               phy_mac_rxdata_r;
reg                         phy_mac_rxdatak_r;
reg                         phy_mac_rxvalid_r;
reg     [2:0]               phy_mac_rxstatus_r;
reg                         phy_mac_phystatus_r;
reg                         phy_mac_rxdatavalid_r;
reg     [PIPE_DATA_WD-1:0]  phy_mac_rxdata_rr;
reg                         phy_mac_rxdatak_rr;
reg                         phy_mac_rxvalid_rr;
reg     [2:0]               phy_mac_rxstatus_rr;
reg                         phy_mac_phystatus_rr;
reg                         phy_mac_rxdatavalid_rr;
reg                         phy_mac_rxstartblock_r;
reg     [1:0]               phy_mac_rxsynchdr_r;
reg                         phy_mac_rxstartblock_rr;
reg     [1:0]               phy_mac_rxsynchdr_rr;
reg     [7:0]               phy_mac_ebuf_location_r;
reg     [7:0]               phy_mac_ebuf_location_rr;

reg     [(MAX_NB*PIPE_DATA_WD)-1:0]    int_phy_mac_rxdata;             // PHY_mac* interface is designed for PIPE spec. receive interface. data contains the pkt data
reg     [MAX_NB-1:0]        int_phy_mac_rxdatak;            // K char indication
reg     [MAX_NB-1:0]        int_phy_mac_rxvalid;            // PIPE receive data valid signal
reg     [(MAX_NB*3)-1:0]    int_phy_mac_rxstatus;           // PIPE receive status
reg     [MAX_NB-1:0]        int_phy_mac_phystatus;

reg     [(MAX_NB*3)-1:0]    int_serdes_phy_mac_rxstatus;           // PIPE receive status
reg     [MAX_NB-1:0]        int_serdes_phy_mac_phystatus;

reg   [19:0]                rx_input_queue[$];
reg   [3:0]                 phystatus_in_rx_input_queue;
reg   [3:0]                 phystatus_invalid_sym_queue;
reg   [3:0]                 phystatus_valid_sym_queue;

reg                         valid_sym_queue_phy_mac_rxvalid[$];
reg   [2:0]                 valid_sym_queue_phy_mac_rxstatus[$];
reg   [PIPE_DATA_WD-1:0]                 valid_sym_queue_phy_mac_rxdata[$];
reg                         valid_sym_queue_phy_mac_rxdatak[$];
reg                         valid_sym_queue_phy_mac_rxdatavalid[$];
reg                         valid_sym_queue_phy_mac_phystatus[$];
reg                         invalid_sym_queue_phy_mac_rxvalid[$];
reg   [2:0]                 invalid_sym_queue_phy_mac_rxstatus[$];
reg   [PIPE_DATA_WD-1:0]                 invalid_sym_queue_phy_mac_rxdata[$];
reg                         invalid_sym_queue_phy_mac_rxdatak[$];
reg                         invalid_sym_queue_phy_mac_rxdatavalid[$];
reg                         invalid_sym_queue_phy_mac_phystatus[$];

reg                         pop_enable;
reg                         pop_enable_d;
wire                        pop_enable_negedge;
reg                         pop_invalid_sym;
reg                         reg_phy_mac_rxvalid_from_queue;
reg                         phy_mac_rxvalid_from_queue;

reg    [MAX_NB-1:0]         int_phy_mac_rxdatavalid;        // ignore a byte or word on the data interface

reg                         valid_sym_queue_phy_mac_rxstartblock[$];
reg    [1:0]                valid_sym_queue_phy_mac_rxsynchdr[$];
reg                         invalid_sym_queue_phy_mac_rxstartblock[$];
reg    [1:0]                invalid_sym_queue_phy_mac_rxsynchdr[$];
reg    [MAX_NB-1:0]         int_phy_mac_rxstartblock;       // first byte of the data interface is the first byte of the block.
reg    [(MAX_NB*2)-1:0]     int_phy_mac_rxsynchdr;          // sync header to use in the next 130b block

// registered signals
reg   [2:0]                 mac_phy_rate_d;
reg   [2:0]                 mac_phy_rate_dd;
reg                         phy_mac_rxvalid_d;
wire                        phy_mac_rxvalid_posedge;
reg                         rate_changed;
wire                        int_rxdatavalid;
reg    [3:0]                int_rxdatavalid_reg;
reg                         mac_phy_txdetectrx_loopback_reg;
reg                         sdown_phy_mac_phystatus_reg;
wire                        sdown_phy_mac_phystatus_negedge;

reg     [2:0]                  sdown_phy_mac_rxstatus_int_clk;
reg                            sdown_phy_mac_phystatus_int_clk;
reg     [2:0]                  sdown_serdes_phy_mac_rxstatus_int_clk;
reg                            sdown_serdes_phy_mac_phystatus_int_clk;
reg     [(MAX_NB*PIPE_DATA_WD)-1:0]       sdown_phy_mac_rxdata_int_clk;
reg     [MAX_NB-1:0]           sdown_phy_mac_rxdatak_int_clk;
reg                            sdown_phy_mac_rxdatavalid_int_clk;      // ignore a byte or word on the data interface
reg                            sdown_phy_mac_rxdatavalid_int_clk_r;
reg     [MAX_RXSB_WD-1:0]      sdown_phy_mac_rxstartblock_int_clk;     // first byte of the data interface is the first byte of the block.
reg     [MAX_RXSB_WD*2-1:0]    sdown_phy_mac_rxsynchdr_int_clk;        // sync header to use in the next 130b block
reg     [7:0]                  sdown_phy_mac_ebuf_location_int_clk;

// signals sync in pclk domain
reg     [2:0]                  sdown_phy_mac_rxstatus_pclk;
reg     [2:0]                  sdown_phy_mac_rxstatus_pclk_d;
reg     [(MAX_NB*PIPE_DATA_WD)-1:0]       sdown_phy_mac_rxdata_pclk;
reg     [MAX_NB-1:0]           sdown_phy_mac_rxdatak_pclk;
reg                            sdown_phy_mac_phystatus_pclk;
reg                            sdown_phy_mac_phystatus_pclk_d;
reg                            sdown_phy_mac_rxvalid_pclk;
reg                            sdown_phy_mac_rxvalid_int_clk;
reg                            sdown_phy_mac_rxdatavalid_pclk;
reg     [RXSB_WD-1:0]          sdown_phy_mac_rxstartblock_pclk;
reg     [RXSB_WD*2-1:0]        sdown_phy_mac_rxsynchdr_pclk;
reg     [7:0]                  sdown_phy_mac_ebuf_location_pclk;

reg                            output_en;


reg     [WIDTH_WD-1:0]         sup_rxwidth;
wire    [WIDTH_WD-1:0]         muxed_rxwidth;

assign muxed_rxwidth = serdes_arch ? sup_rxwidth : sup_mac_phy_width;

initial
begin
   sdown_phy_mac_rxstatus_pclk  = 3'b000;
   sdown_phy_mac_rxdata_pclk    = '0;
   sdown_phy_mac_rxdatak_pclk   = '0;
   sdown_phy_mac_phystatus_pclk = 1'b1;
   sdown_phy_mac_rxdatavalid_pclk  = 1'b0;
end

// -----------------------------------------------------------------------------
// 2-stage synchronizer for the reset
// -----------------------------------------------------------------------------
reg   phy_rst_n_s1;
reg   phy_rst_n_s2;
wire  pipe_rst_n;

assign pipe_rst_n = phy_rst_n_s2;

always @(posedge txclk or negedge phy_rst_n)
begin
  if ( !phy_rst_n )
  begin
    phy_rst_n_s1 <= #TP 1'b0;
    phy_rst_n_s2 <= #TP 1'b0;
  end else begin
    phy_rst_n_s1 <= #TP 1'b1;
    phy_rst_n_s2 <= #TP phy_rst_n_s1;
  end
end

// detect when we are in reset till falling edge of phystatus
reg in_rst; initial in_rst = 1'b1;
always @(negedge sdown_phy_mac_phystatus_pclk or negedge phy_rst_n)
begin
    if (!phy_rst_n)               in_rst  <= #TP 1'b1;
    else if (!phy_mac_phystatus)  in_rst  <= #TP 1'b0;
end

// ---------------------------------------------------------------------------
// detect/decode if we have pacing on RX and TX path
// ---------------------------------------------------------------------------
// tx_pacing_value = pclk_rate*width/rate (if pclk_rate*width > rate)

reg [4:0] tx_pace_value;
always @(pclk)
begin
`ifdef GPHY_ESM_SUPPORT
   if (esm_enable && sup_mac_phy_pclk_rate == 3 && sup_mac_phy_width == 2 && sup_mac_phy_rate == 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT)  tx_pace_value = 2; else //5000,4s,8000
   if (esm_enable && sup_mac_phy_pclk_rate == 4 && sup_mac_phy_width == 1 && sup_mac_phy_rate == 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT)  tx_pace_value = 2; else //10000,2s,8000
   if (esm_enable && sup_mac_phy_pclk_rate == 3 && sup_mac_phy_width == 2 && sup_mac_phy_rate == 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT) tx_pace_value = 0; else //5000,4s,16000
   if (esm_enable && sup_mac_phy_pclk_rate == 4 && sup_mac_phy_width == 1 && sup_mac_phy_rate == 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT) tx_pace_value = 0; else //10000,2s,16000

   if (esm_enable && sup_mac_phy_pclk_rate == 8   && sup_mac_phy_width == 2 && sup_mac_phy_rate == 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT)  tx_pace_value = 0; else //6250,4s,20000
   if (esm_enable && sup_mac_phy_pclk_rate == 'hA && sup_mac_phy_width == 1 && sup_mac_phy_rate == 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT)  tx_pace_value = 0; else //12500,2s,20000
   if (esm_enable && sup_mac_phy_pclk_rate == 9   && sup_mac_phy_width == 2 && sup_mac_phy_rate == 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT)  tx_pace_value = 0; else //7812.5,4s,25000
   if (esm_enable && sup_mac_phy_pclk_rate == 'hB && sup_mac_phy_width == 1 && sup_mac_phy_rate == 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT)  tx_pace_value = 0; else //1562.5,2s,25000
`endif //GPHY_ESM_SUPPORT
   if (sup_mac_phy_pclk_rate == 2 && sup_mac_phy_width == 1 && sup_mac_phy_rate == 0) tx_pace_value = 2; else //2500,2s,2500
   if (sup_mac_phy_pclk_rate == 2 && sup_mac_phy_width == 2 && sup_mac_phy_rate == 0) tx_pace_value = 4; else //2500,4s,2500
   if (sup_mac_phy_pclk_rate == 2 && sup_mac_phy_width == 2 && sup_mac_phy_rate == 1) tx_pace_value = 2; else //2500,4s,5000

   if (sup_mac_phy_pclk_rate == 3 && sup_mac_phy_width == 0 && sup_mac_phy_rate == 0) tx_pace_value = 2; else //5000,1s,2500
   if (sup_mac_phy_pclk_rate == 3 && sup_mac_phy_width == 1 && sup_mac_phy_rate == 0) tx_pace_value = 4; else //5000,2s,2500
   if (sup_mac_phy_pclk_rate == 3 && sup_mac_phy_width == 1 && sup_mac_phy_rate == 1) tx_pace_value = 2; else //5000,2s,5000
   if (sup_mac_phy_pclk_rate == 3 && sup_mac_phy_width == 2 && sup_mac_phy_rate == 2) tx_pace_value = 2; else //5000,4s,8000

   if (sup_mac_phy_pclk_rate == 4 && sup_mac_phy_width == 0 && sup_mac_phy_rate == 0) tx_pace_value = 4; else //10000,1s,2500
   if (sup_mac_phy_pclk_rate == 4 && sup_mac_phy_width == 0 && sup_mac_phy_rate == 1) tx_pace_value = 2; else //10000,1s,5000
   if (sup_mac_phy_pclk_rate == 4 && sup_mac_phy_width == 1 && sup_mac_phy_rate == 2) tx_pace_value = 2; else //10000,2s,8000
   
   if (sup_mac_phy_pclk_rate == 4 && sup_mac_phy_width == 2 && sup_mac_phy_rate == 2) tx_pace_value = 4; else //10000,4s,8000
   if (sup_mac_phy_pclk_rate == 4 && sup_mac_phy_width == 2 && sup_mac_phy_rate == 3) tx_pace_value = 2; else //10000,4s,16000
 
   
   
                                                                                      tx_pace_value = 0;
end

//rx_pacing_value = pclk_rate/rate*width
reg [4:0] rx_pace_value;
always @(int_clk)
begin
  if (serdes_arch) begin
    rx_pace_value = 0;
  end else begin
  if (!output_en) begin
  `ifdef GPHY_ESM_SUPPORT
     if (esm_enable && sup_mac_phy_pclk_rate == 3 && sup_rxwidth == 2 && sup_mac_phy_rate == 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT)  rx_pace_value = 2; else //5000,4s,8000
     if (esm_enable && sup_mac_phy_pclk_rate == 4 && sup_rxwidth == 1 && sup_mac_phy_rate == 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT)  rx_pace_value = 2; else //10000,2s,8000
     if (esm_enable && sup_mac_phy_pclk_rate == 3 && sup_rxwidth == 2 && sup_mac_phy_rate == 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT) rx_pace_value = 0; else //5000,4s,16000
     if (esm_enable && sup_mac_phy_pclk_rate == 4 && sup_rxwidth == 1 && sup_mac_phy_rate == 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT) rx_pace_value = 0; else //10000,2s,16000

     if (esm_enable && sup_mac_phy_pclk_rate == 8   && sup_rxwidth == 2 && sup_mac_phy_rate == 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT)  rx_pace_value = 0; else //6250,4s,20000
     if (esm_enable && sup_mac_phy_pclk_rate == 'hA && sup_rxwidth == 1 && sup_mac_phy_rate == 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT)  rx_pace_value = 0; else //12500,2s,20000
     if (esm_enable && sup_mac_phy_pclk_rate == 9   && sup_rxwidth == 2 && sup_mac_phy_rate == 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT)  rx_pace_value = 0; else //7812.5,4s,25000
     if (esm_enable && sup_mac_phy_pclk_rate == 'hB && sup_rxwidth == 1 && sup_mac_phy_rate == 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT)  rx_pace_value = 0; else //1562.5,2s,25000
  `endif //GPHY_ESM_SUPPORT
     if (sup_mac_phy_pclk_rate == 2 && sup_rxwidth == 1 && sup_mac_phy_rate == 0) rx_pace_value = 2; else //2500,2s,2500
     if (sup_mac_phy_pclk_rate == 2 && sup_rxwidth == 2 && sup_mac_phy_rate == 0) rx_pace_value = 4; else //2500,4s,2500
     if (sup_mac_phy_pclk_rate == 2 && sup_rxwidth == 2 && sup_mac_phy_rate == 1) rx_pace_value = 2; else //2500,4s,5000

     if (sup_mac_phy_pclk_rate == 3 && sup_rxwidth == 0 && sup_mac_phy_rate == 0) rx_pace_value = 2; else //5000,1s,2500
     if (sup_mac_phy_pclk_rate == 3 && sup_rxwidth == 1 && sup_mac_phy_rate == 0) rx_pace_value = 4; else //5000,2s,2500
     if (sup_mac_phy_pclk_rate == 3 && sup_rxwidth == 1 && sup_mac_phy_rate == 1) rx_pace_value = 2; else //5000,2s,5000
     if (sup_mac_phy_pclk_rate == 3 && sup_rxwidth == 2 && sup_mac_phy_rate == 2) rx_pace_value = 2; else //5000,4s,8000

     if (sup_mac_phy_pclk_rate == 4 && sup_rxwidth == 0 && sup_mac_phy_rate == 0) rx_pace_value = 4; else //10000,1s,2500
     if (sup_mac_phy_pclk_rate == 4 && sup_rxwidth == 0 && sup_mac_phy_rate == 1) rx_pace_value = 2; else //10000,1s,5000
     if (sup_mac_phy_pclk_rate == 4 && sup_rxwidth == 1 && sup_mac_phy_rate == 2) rx_pace_value = 2; else //10000,2s,8000
     if (sup_mac_phy_pclk_rate == 4 && sup_rxwidth == 2 && sup_mac_phy_rate == 2) rx_pace_value = 4; else //10000,2s,8000
     if (sup_mac_phy_pclk_rate == 4 && sup_rxwidth == 2 && sup_mac_phy_rate == 3) rx_pace_value = 2; else //10000,2s,8000
                                                                                  rx_pace_value = 0;
   end else begin
     rx_pace_value = rx_pace_value;
   end                                                                              
                                                                              
   end
end

// register inputs
always @(posedge int_clk or negedge phy_rst_n)
begin
   if (!phy_rst_n) begin
     phy_mac_rxdata_r        <= #TP 'd0;
     phy_mac_rxdatak_r       <= #TP 'd0;
     phy_mac_rxvalid_r       <= #TP 'd0;
     phy_mac_rxstatus_r      <= #TP 'd0;
     phy_mac_phystatus_r     <= #TP 'b1;
     phy_mac_rxdatavalid_r   <= #TP 'd0;
     phy_mac_rxdata_rr        <= #TP 'd0;
     phy_mac_rxdatak_rr       <= #TP 'd0;
     phy_mac_rxvalid_rr       <= #TP 'd0;
     phy_mac_rxstatus_rr      <= #TP 'd0;
     phy_mac_phystatus_rr     <= #TP 'b1;
     phy_mac_rxdatavalid_rr   <= #TP 'd0;
     phy_mac_rxstartblock_r   <= #TP 'd0;
     phy_mac_rxsynchdr_r      <= #TP 'd0;
     phy_mac_rxstartblock_rr  <= #TP 'd0;
     phy_mac_rxsynchdr_rr     <= #TP 'd0;
     phy_mac_ebuf_location_r  <= #TP 'd0;
     phy_mac_ebuf_location_rr <= #TP 'd0;
   end else begin
     phy_mac_rxdata_r        <= #TP phy_mac_rxdata;
     phy_mac_rxdatak_r       <= #TP phy_mac_rxdatak;
     phy_mac_rxvalid_r       <= #TP phy_mac_rxvalid;
     phy_mac_rxstatus_r      <= #TP phy_mac_rxstatus;
     phy_mac_phystatus_r     <= #TP phy_mac_phystatus;
     phy_mac_rxdatavalid_r   <= #TP phy_mac_rxdatavalid;
     phy_mac_rxdata_rr        <= #TP phy_mac_rxdata_r;
     phy_mac_rxdatak_rr       <= #TP phy_mac_rxdatak_r;
     phy_mac_rxvalid_rr       <= #TP phy_mac_rxvalid_r;
     phy_mac_rxstatus_rr      <= #TP phy_mac_rxstatus_r;
     phy_mac_phystatus_rr     <= #TP phy_mac_phystatus_r;
     phy_mac_rxdatavalid_rr   <= #TP phy_mac_rxdatavalid_r;
     phy_mac_rxstartblock_r   <= #TP phy_mac_rxstartblock;
     phy_mac_rxsynchdr_r      <= #TP phy_mac_rxsynchdr;
     phy_mac_rxstartblock_rr  <= #TP phy_mac_rxstartblock_r;
     phy_mac_rxsynchdr_rr     <= #TP phy_mac_rxsynchdr_r;
     phy_mac_ebuf_location_r  <= #TP phy_mac_ebuf_location;
     phy_mac_ebuf_location_rr <= #TP phy_mac_ebuf_location_r;
   end
end

// detect rise of rx_valid and rise of rxdatavalid
wire   rise_of_rxvalid_rxdatavalid;
assign rise_of_rxvalid_rxdatavalid = phy_mac_rxvalid && !phy_mac_rxvalid_r;// && phy_mac_rxdatavalid && !phy_mac_rxdatavalid_r;
assign phy_mac_phystatus_negedge = ~phy_mac_phystatus && phy_mac_phystatus_r;
// -------------------------------------------------------------------------------------------------------
// controls for stepping up/down
// -------------------------------------------------------------------------------------------------------
wire [4:0] pipe_nr_sym;
reg step_down_1s_1s_en;
reg step_down_1s_2s_en;
reg step_down_1s_4s_en;
reg step_down_1s_8s_en;
reg step_down_1s_16s_en;
wire [15:0] max_pipe_byte_dec;

always@(posedge txclk or negedge pipe_rst_n)
begin
   if (!pipe_rst_n) begin
       step_down_1s_1s_en   <= #TP 1'b0;
       step_down_1s_2s_en   <= #TP 1'b0;
       step_down_1s_4s_en   <= #TP 1'b0;
       step_down_1s_8s_en   <= #TP 1'b0;
       step_down_1s_16s_en  <= #TP 1'b0;
   end else if (!lock && !sdown_phy_mac_rxvalid) begin
       step_down_1s_1s_en   <= #TP (rxwidth == 0);
       step_down_1s_2s_en   <= #TP (rxwidth == 1) ;
       step_down_1s_4s_en   <= #TP (rxwidth == 2) ;
       step_down_1s_8s_en   <= #TP (rxwidth == 3) ;
       step_down_1s_16s_en  <= #TP (rxwidth == 4) ;
   end else begin
       step_down_1s_1s_en   <= #TP step_down_1s_1s_en;
       step_down_1s_2s_en   <= #TP step_down_1s_2s_en;
       step_down_1s_4s_en   <= #TP step_down_1s_4s_en ;
       step_down_1s_8s_en   <= #TP step_down_1s_8s_en ;
       step_down_1s_16s_en  <= #TP step_down_1s_16s_en ;
   end
end

assign pipe_nr_sym = step_down_1s_1s_en ? 1 :
                     step_down_1s_2s_en ? 2 :
                     step_down_1s_4s_en ? 4 :
                     step_down_1s_8s_en ? 8 : 16;

assign max_pipe_byte_dec = (pipe_nr_sym == 1) ? 'h0001 :
                           (pipe_nr_sym == 2) ? 'h0002 :
                           (pipe_nr_sym == 4) ? 'h0008 :
                           (pipe_nr_sym == 8) ? 'h0080 : 'h8000;

// ---------------------------------------------------------------------------
// register some signals
// ---------------------------------------------------------------------------
wire mux_int_clk;
assign mux_int_clk = serdes_arch ? txclk : int_clk;

always@(posedge mux_int_clk or negedge pipe_rst_n)
begin
   if (!pipe_rst_n) begin
      sdown_phy_mac_phystatus_reg     <= #TP 1;
      mac_phy_txdetectrx_loopback_reg <= #TP 0;
   end else begin
      sdown_phy_mac_phystatus_reg     <= #TP sdown_phy_mac_phystatus_pclk;
      mac_phy_txdetectrx_loopback_reg <= #TP mac_phy_txdetectrx_loopback;
   end
end

// -------------------------------------------------------------------------------------------------------
// if elec_idle, from the moment txdetectrx_loopback it is asserted till phystatus is returned
// we are in detection window
// -------------------------------------------------------------------------------------------------------
reg    detection_window;
wire   txdetectrx_loopback_rise;
assign txdetectrx_loopback_rise = mac_phy_txdetectrx_loopback && !mac_phy_txdetectrx_loopback_reg;

always@(posedge mux_int_clk or negedge pipe_rst_n)
begin
   if (!pipe_rst_n)                                                                detection_window <= #TP 1'b0;
   else if (txdetectrx_loopback_rise & mac_phy_txelecidle)                         detection_window <= #TP 1'b1;
   else if (!sdown_phy_mac_phystatus & sdown_phy_mac_phystatus_reg)                detection_window <= #TP 1'b0;
   else if (mac_phy_txdetectrx_loopback & mac_phy_txelecidle & detection_window)   detection_window <= #TP 1'b1;
end

assign sdown_phy_mac_phystatus_negedge = sdown_phy_mac_phystatus_reg && !sdown_phy_mac_phystatus_pclk;


// ------------------------------------------------------------------------
// When we have receier detection, register if we receive answer with receiver present
// We need this synced on pclk
// ------------------------------------------------------------------------
reg receiver_present;
always @(posedge mux_int_clk or negedge pipe_rst_n)
begin
   if (!pipe_rst_n)
         receiver_present <= #TP 1'b0;
   else if (phy_mac_rxstatus == 3'b011)
         receiver_present <= #TP 1'b1;
   else if (sdown_phy_mac_phystatus_negedge)
         receiver_present <= #TP 1'b0;
   else
         receiver_present <= #TP receiver_present;
end


// ------------------------------------------------------------------------
reg rxvalid_in_queue;
// this may need to be int_clk, if so, then could just use sup_mac_phy_rate
always@(posedge int_clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
      mac_phy_rate_d     <= #TP 3'h0;
      mac_phy_rate_dd    <= #TP 3'h0;
      phy_mac_rxvalid_d  <= #TP 1'b0;
      reg_phy_mac_rxvalid_from_queue  <= #TP 1'b0;
      phy_mac_rxvalid_from_queue      <= #TP 1'b0;
    end else begin
      mac_phy_rate_d    <= #TP sup_mac_phy_rate;
      mac_phy_rate_dd   <= #TP mac_phy_rate_d;
      phy_mac_rxvalid_d <= #TP phy_mac_rxvalid;
      if (valid_sym_queue_phy_mac_rxvalid.size() > 0 ) begin
          phy_mac_rxvalid_from_queue     <= #TP valid_sym_queue_phy_mac_rxvalid[0];
          reg_phy_mac_rxvalid_from_queue <= #TP phy_mac_rxvalid_from_queue;
      end else begin
          phy_mac_rxvalid_from_queue     <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0) ? invalid_sym_queue_phy_mac_rxvalid[0] : 'd0;
          reg_phy_mac_rxvalid_from_queue <= #TP phy_mac_rxvalid_from_queue;
      end
    end
end

//detect posedge on rxvalid
assign phy_mac_rxvalid_posedge = phy_mac_rxvalid && !phy_mac_rxvalid_d;

// detect a rate change window
always @(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n)                                rate_changed <= #TP 1'b0; else
    if (mac_phy_rate_d != mac_phy_rate_dd)          rate_changed <= #TP 1'b1; else
    if (rate_changed & phy_mac_phystatus)           rate_changed <= #TP 1'b0; else
    if (rate_changed & phy_mac_rxvalid_posedge)     rate_changed <= #TP 1'b0;
end

// current powerdown after phystatus ack
reg [3:0] current_powerdown_int_clk;
reg [3:0] current_powerdown;
reg pwdw_ch_P1CPM_to_P1x;
reg pwdw_ch_P1x_to_P1CPM;

// pwdw change from P1CPM to P1X
always @(mac_phy_powerdown or current_powerdown_int_clk or  negedge pipe_rst_n)
begin
   if (!pipe_rst_n)     pwdw_ch_P1CPM_to_P1x <= #TP 0;
   else if (mac_phy_powerdown inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2} && current_powerdown_int_clk == `GPHY_PDOWN_P1_CPM)
                        pwdw_ch_P1CPM_to_P1x <= #TP 1;
   else if (current_powerdown_int_clk != `GPHY_PDOWN_P1_CPM) pwdw_ch_P1CPM_to_P1x <= #TP 0;
end

// pwdw change from P1x to P1CPM
always @(mac_phy_powerdown or current_powerdown_int_clk or  negedge pipe_rst_n)
begin
   if (!pipe_rst_n)     pwdw_ch_P1x_to_P1CPM <= #TP 0;
   else if (mac_phy_powerdown == `GPHY_PDOWN_P1_CPM && current_powerdown_int_clk inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2})
                        pwdw_ch_P1x_to_P1CPM <= #TP 1;
   else if (!(current_powerdown_int_clk inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2})) pwdw_ch_P1x_to_P1CPM <= #TP 0;
end


always @(posedge txclk or negedge pipe_rst_n or posedge phy_mac_phystatus or posedge pwdw_ch_P1CPM_to_P1x or posedge pwdw_ch_P1x_to_P1CPM)
begin
   if (!pipe_rst_n && current_powerdown_int_clk !== 4'b0011)  current_powerdown_int_clk <= #TP mac_phy_powerdown;
   else if (pwdw_ch_P1CPM_to_P1x)                             current_powerdown_int_clk <= #TP mac_phy_powerdown;
   else if (pwdw_ch_P1x_to_P1CPM)                             current_powerdown_int_clk <= #TP mac_phy_powerdown;
   else if (phy_mac_phystatus)                                current_powerdown_int_clk <= #TP mac_phy_powerdown;
end


always @(posedge pclk or negedge pipe_rst_n or current_powerdown_int_clk)
begin
   if (!pipe_rst_n)                                                                                                                 current_powerdown <= #TP current_powerdown_int_clk;
   else if (pclk && !phy_mac_phystatus && !(current_powerdown_int_clk inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2,`GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON })) current_powerdown <= #TP current_powerdown_int_clk;
   else if (current_powerdown_int_clk inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2, `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON})                                  current_powerdown <= #TP current_powerdown_int_clk;
   else                                                                                                                             current_powerdown <= #TP current_powerdown;
end

always @(posedge int_clk or negedge pipe_rst_n )
begin
   if (!pipe_rst_n )  mac_phy_powerdown_r <= #TP `GPHY_PDOWN_P1;
   else               mac_phy_powerdown_r <= #TP mac_phy_powerdown;
end
// ---------------------------------------------------------------------------
// Register Rx input signals
// we push all incoming symbols in this queue
// if we are in nominal empty mode and pipe width is bigger then 1s then each time
// rx_Datavalid goes to 0 for only one symbol we need to add extra symbol to complete the rest of the bytes
// in such a moment this queue will gain symbols
// ---------------------------------------------------------------------------
always @(posedge int_clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       rx_input_queue = {};
       rxvalid_in_queue <= 1'b0;
       phystatus_in_rx_input_queue <= 'h0;
    end else if (pop_enable_negedge && !phy_mac_rxvalid && (phystatus_in_rx_input_queue == 'h0) && !phy_mac_phystatus_rr) begin
       rx_input_queue = {};
       rxvalid_in_queue <= 1'b0;
       phystatus_in_rx_input_queue <= 'h0;
    end else if (rise_of_rxvalid_rxdatavalid && (phystatus_in_rx_input_queue == 'h0) && !phy_mac_phystatus_rr) begin
       rx_input_queue = {};
       rxvalid_in_queue <= 1'b0;
       phystatus_in_rx_input_queue <= 'h0;
    end else begin
     #TP;
      if (phy_mac_phystatus_rr)
         phystatus_in_rx_input_queue = phystatus_in_rx_input_queue + 1;
      if (mac_phy_rate > 1)
        rx_input_queue.push_back({ phy_mac_rxdata_rr,phy_mac_rxsynchdr_rr,phy_mac_rxstartblock_rr,phy_mac_phystatus_rr,phy_mac_rxstatus_rr,phy_mac_rxdatak_rr,phy_mac_rxvalid_rr,phy_mac_rxdatavalid_rr});
      else
        rx_input_queue.push_back({ phy_mac_rxdata_rr,3'b0,phy_mac_phystatus_rr,phy_mac_rxstatus_rr,phy_mac_rxdatak_rr,phy_mac_rxvalid_rr,phy_mac_rxdatavalid_rr});
      rxvalid_in_queue  <= rx_input_queue.size() > 0 ? rx_input_queue[0][1] : rxvalid_in_queue;
    end
end

// ---------------------------------------------------------------------------
// Register Rx input signals
// if current symbol is valid (rx_valid & rx_datavalid) push into valid symbols queue
// the number of symbols in valid queue should not be bigger then the number of pipe width
// to not change the order of the data because invalid symbols they have priority at output
// if current symbol is invalid push into invalid symbols queue
// ---------------------------------------------------------------------------
always @(posedge int_clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
      valid_sym_queue_phy_mac_rxvalid         = {};
      valid_sym_queue_phy_mac_rxstatus        = {};
      valid_sym_queue_phy_mac_rxdata          = {};
      valid_sym_queue_phy_mac_rxdatak         = {};
      valid_sym_queue_phy_mac_rxdatavalid     = {};
      valid_sym_queue_phy_mac_phystatus       = {};
      invalid_sym_queue_phy_mac_rxvalid       = {};
      invalid_sym_queue_phy_mac_rxstatus      = {};
      invalid_sym_queue_phy_mac_rxdata        = {};
      invalid_sym_queue_phy_mac_rxdatak       = {};
      invalid_sym_queue_phy_mac_rxdatavalid   = {};
      invalid_sym_queue_phy_mac_phystatus     = {};
      valid_sym_queue_phy_mac_rxstartblock     = {};
      valid_sym_queue_phy_mac_rxsynchdr        = {};
      invalid_sym_queue_phy_mac_rxstartblock   = {};
      invalid_sym_queue_phy_mac_rxsynchdr      = {};
      phystatus_invalid_sym_queue ='h0;
      phystatus_valid_sym_queue ='h0;
    end else if (pop_enable_negedge && !phy_mac_rxvalid && (phystatus_invalid_sym_queue == 'h0) && !phy_mac_phystatus_rr) begin
      invalid_sym_queue_phy_mac_rxvalid       = {};
      invalid_sym_queue_phy_mac_rxstatus      = {};
      invalid_sym_queue_phy_mac_rxdata        = {};
      invalid_sym_queue_phy_mac_rxdatak       = {};
      invalid_sym_queue_phy_mac_rxdatavalid   = {};
      invalid_sym_queue_phy_mac_phystatus     = {};
      invalid_sym_queue_phy_mac_rxstartblock   = {};
      invalid_sym_queue_phy_mac_rxsynchdr      = {};
    end else if (rise_of_rxvalid_rxdatavalid && (phystatus_valid_sym_queue == 'h0)) begin
      valid_sym_queue_phy_mac_rxvalid         = {};
      valid_sym_queue_phy_mac_rxstatus        = {};
      valid_sym_queue_phy_mac_rxdata          = {};
      valid_sym_queue_phy_mac_rxdatak         = {};
      valid_sym_queue_phy_mac_rxdatavalid     = {};
      valid_sym_queue_phy_mac_phystatus       = {};
      valid_sym_queue_phy_mac_rxstartblock    = {};
      valid_sym_queue_phy_mac_rxsynchdr       = {};
    end else begin
      #TP;
      if (rx_input_queue[0][0] && rx_input_queue[0][1] && valid_sym_queue_phy_mac_rxdatavalid.size() <= pipe_nr_sym*2-1) begin
         valid_sym_queue_phy_mac_rxdatavalid.push_back(rx_input_queue[0][0]);
         valid_sym_queue_phy_mac_rxvalid.push_back(rx_input_queue[0][1]);
         valid_sym_queue_phy_mac_rxdatak.push_back(rx_input_queue[0][2]);
         valid_sym_queue_phy_mac_rxstatus.push_back(rx_input_queue[0][5:3]);
         valid_sym_queue_phy_mac_phystatus.push_back(rx_input_queue[0][6]);
         valid_sym_queue_phy_mac_rxstartblock.push_back(rx_input_queue[0][7]);
         valid_sym_queue_phy_mac_rxsynchdr.push_back(rx_input_queue[0][9:8]);
         valid_sym_queue_phy_mac_rxdata.push_back(rx_input_queue[0][10+PIPE_DATA_WD-1:10]);

         if (rx_input_queue[0][6]) begin
            phystatus_valid_sym_queue   = phystatus_valid_sym_queue + 1;
            phystatus_in_rx_input_queue = phystatus_in_rx_input_queue - 1;
         end
         void'(rx_input_queue.pop_front());
      end else if (!(rx_input_queue[0][0] && rx_input_queue[0][1])) begin
         invalid_sym_queue_phy_mac_rxdatavalid.push_back(rx_input_queue[0][0]);
         invalid_sym_queue_phy_mac_rxvalid.push_back(rx_input_queue[0][1]);
         invalid_sym_queue_phy_mac_rxdatak.push_back(rx_input_queue[0][2]);
         invalid_sym_queue_phy_mac_rxstatus.push_back(rx_input_queue[0][5:3]);
         invalid_sym_queue_phy_mac_phystatus.push_back(rx_input_queue[0][6]);
         invalid_sym_queue_phy_mac_rxstartblock.push_back(rx_input_queue[0][7]);
         invalid_sym_queue_phy_mac_rxsynchdr.push_back(rx_input_queue[0][9:8]);
         invalid_sym_queue_phy_mac_rxdata.push_back(rx_input_queue[0][10+PIPE_DATA_WD-1:10]);
         if (rx_input_queue[0][6]) begin
            phystatus_invalid_sym_queue = phystatus_invalid_sym_queue + 1;
            phystatus_in_rx_input_queue = phystatus_in_rx_input_queue - 1;
         end
         void'(rx_input_queue.pop_front());
      end
    end
end

assign pop_enable_negedge = pop_enable_d && !pop_enable;

always @(posedge int_clk or negedge pipe_rst_n)
begin
   if (!pipe_rst_n)  pop_enable_d <= #TP 1'b0; else
                     pop_enable_d <= #TP pop_enable;
end

// we should start poping symbols from the queue only when we have at least the number of pipe width symbols
// in the queue
always @(posedge int_clk or negedge pipe_rst_n)
begin
  if (!pipe_rst_n)                                                                        pop_enable <= #TP 1'b0; else
  if (rise_of_rxvalid_rxdatavalid && (phystatus_valid_sym_queue == 'h0))                  pop_enable <= #TP 1'b0; else
  if (!pop_enable && valid_sym_queue_phy_mac_rxvalid.size() >= 1 && (!phy_mac_rxvalid_rr && !rx_input_queue[0][1])) pop_enable <= #TP 1'b1; else
  if ((valid_sym_queue_phy_mac_rxvalid.size() >= pipe_nr_sym*2-1 && (pipe_nr_sym > 1)) ||
      (valid_sym_queue_phy_mac_rxvalid.size() >  pipe_nr_sym && (pipe_nr_sym == 1)))                            pop_enable <= #TP 1'b1; else
  if (valid_sym_queue_phy_mac_rxvalid.size()  <= 1 && !phy_mac_rxvalid_rr  )              pop_enable <= #TP 1'b0;
end

// managed when to output from the invalid queue
// if we have a qymbol in the invalid queue it has priority and it will be outputte on the first new group of bytes
// the only exception before going to elecidle when we should wait to output all symbols from the valid queue
always @(posedge int_clk or negedge pipe_rst_n)
begin
   if (!pipe_rst_n)                                                                          pop_invalid_sym <= #TP 1'b1; else
   if (pop_enable && valid_sym_queue_phy_mac_rxvalid.size() <= 1 && (!phy_mac_rxvalid_rr && !rx_input_queue[0][1]))     pop_invalid_sym <= #TP 1'b1; else
   if (pop_enable && invalid_sym_queue_phy_mac_rxdatavalid.size() < pipe_nr_sym)             pop_invalid_sym <= #TP 1'b0; else
   if (pop_enable && !phy_mac_rxvalid && valid_sym_queue_phy_mac_rxvalid.size() > 1)         pop_invalid_sym <= #TP 1'b0; else
   if (!pop_enable && valid_sym_queue_phy_mac_rxvalid.size() == 1  && !phy_mac_rxvalid_rr)   pop_invalid_sym <= #TP 1'b0; else
   if (invalid_sym_queue_phy_mac_rxdatavalid.size() >= pipe_nr_sym )                         pop_invalid_sym <= #TP 1'b1; else
   if (!pop_enable)                                                                          pop_invalid_sym <= #TP 1'b1;
end

reg [5:0] valid_sym_size;
reg [5:0] invalid_sym_size;
reg [5:0] rx_input_size;

always @(posedge int_clk or negedge pipe_rst_n)
begin
 valid_sym_size <= valid_sym_queue_phy_mac_rxvalid.size();
 invalid_sym_size <= invalid_sym_queue_phy_mac_rxvalid.size();
 rx_input_size <= rx_input_queue.size();
end
// -----------------------------------------------------------------------------
// logic for pacing
// -----------------------------------------------------------------------------
reg [2:0] rx_pace_cnt;
reg       pace_rxdatavalid;
reg       pace_rxdatavalid_r;

always @(posedge pclk or negedge phy_rst_n)
begin
    if (!phy_rst_n) begin
        rx_pace_cnt        <= #TP 0;
        pace_rxdatavalid   <= #TP 0;
        pace_rxdatavalid_r <= #TP 0;
    end else if (rx_pace_value > 0)
    begin
        if ((rx_pace_cnt == rx_pace_value - 1))  begin
            rx_pace_cnt       <= #TP 0;
            pace_rxdatavalid  <= #TP 1;
        end else begin
            rx_pace_cnt       <= #TP rx_pace_cnt + 1;
            pace_rxdatavalid  <= #TP 0;
        end
        pace_rxdatavalid_r <= #TP pace_rxdatavalid;
    end else begin 
        rx_pace_cnt        <= #TP 0;
        pace_rxdatavalid   <= #TP 1;
        pace_rxdatavalid_r <= #TP 1;
    end
end

// -------------------------------------------------------------------------------------------------------
// SDOWN Side - phy_mac
// Create a counter to count the number of symbols that we have and point
// to the current symbol that we are writing
// -------------------------------------------------------------------------------------------------------
// at gen3/4 we need to synch the start with the first startblock
 reg start_shift;

always@(posedge int_clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n)                                                          start_shift <= #TP 1'b0; else
    if (valid_sym_queue_phy_mac_rxvalid.size()  <= 1 && !rxvalid_in_queue)    start_shift <= #TP 1'b0; else
    if ((mac_phy_rate > 1) && invalid_sym_queue_phy_mac_rxdatavalid.size() <= 1) start_shift <= #TP 1'b1; else
    if (((valid_sym_queue_phy_mac_rxvalid.size() >= pipe_nr_sym && (pipe_nr_sym > 1)) ||
        (valid_sym_queue_phy_mac_rxvalid.size() >  pipe_nr_sym)) && invalid_sym_queue_phy_mac_rxdatavalid.size() <= 1)
                                                                              start_shift <= #TP 1'b1;
end

always@(posedge int_clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       rx_dst_byte_enable   <= #TP 8'b1;
    end else if (RXSB_WD == 1 && valid_sym_queue_phy_mac_rxstartblock[1] && invalid_sym_queue_phy_mac_rxstartblock.size() == 0 && pop_enable) begin
       rx_dst_byte_enable   <= #TP 8'h01;
    end else if (((!int_rxdatavalid && rx_dst_byte_enable[0]) || (!start_shift)) && (rx_dst_byte_enable == max_pipe_byte_dec))  begin
       rx_dst_byte_enable   <= #TP 8'h01;
    end else if (!int_rxdatavalid && rx_dst_byte_enable[0])  begin
       rx_dst_byte_enable   <= #TP 8'h01;
    end else if ((rate_changed && !lock) || (!(sdown_phy_mac_rxvalid_pclk || valid_sym_queue_phy_mac_rxvalid[0]))) begin
       rx_dst_byte_enable   <= #TP 8'h01;
    end else if ( sdown_phy_mac_rxvalid_pclk || int_rxdatavalid) begin
       rx_dst_byte_enable   <= #TP rx_dst_byte_enable_wire_shift;
    end else if (!sdown_phy_mac_rxvalid_pclk && !int_rxdatavalid && !pop_enable) begin
       rx_dst_byte_enable   <= #TP 8'h01;
    end   
end

assign rx_dst_byte_enable_wire_change = 1 ;
assign rx_dst_byte_enable_wire_shift = step_down_1s_1s_en  ? 1                                                 :
                                       step_down_1s_2s_en  ? {rx_dst_byte_enable[0],rx_dst_byte_enable[1]}     :
                                       step_down_1s_4s_en  ? {rx_dst_byte_enable[2:0],rx_dst_byte_enable[3]}   :
                                       step_down_1s_8s_en  ? {rx_dst_byte_enable[6:0],rx_dst_byte_enable[7]}   :
                                       step_down_1s_16s_en ? {rx_dst_byte_enable[14:0],rx_dst_byte_enable[15]} : {rx_dst_byte_enable[3:0],rx_dst_byte_enable[7:4]};




// ------------------------------------------------------------------------
// This logic applies only for SERDES ARCH
// ------------------------------------------------------------------------
always@(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       int_serdes_phy_mac_rxstatus     <= #TP '0;
       int_serdes_phy_mac_phystatus    <= #TP {{MAX_NB-1{1'b0}}, 1'b1};
    // this is to un-pace data, no pacing at gen3 rate
    end else begin
       int_serdes_phy_mac_phystatus[0]      <= #TP  phy_mac_phystatus;

       if (step_down_1s_2s_en || step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
       begin
         int_serdes_phy_mac_phystatus[1]    <= #TP int_serdes_phy_mac_phystatus[0];
       end
       if (step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
       begin
         int_serdes_phy_mac_phystatus[2]    <= #TP int_serdes_phy_mac_phystatus[1];
         int_serdes_phy_mac_phystatus[3]    <= #TP int_serdes_phy_mac_phystatus[2];
       end
       if (step_down_1s_8s_en || step_down_1s_16s_en)
       begin
         int_serdes_phy_mac_phystatus[4]    <= #TP int_serdes_phy_mac_phystatus[3];
         int_serdes_phy_mac_phystatus[5]    <= #TP int_serdes_phy_mac_phystatus[4];
         int_serdes_phy_mac_phystatus[6]    <= #TP int_serdes_phy_mac_phystatus[5];
         int_serdes_phy_mac_phystatus[7]    <= #TP int_serdes_phy_mac_phystatus[6];
       end
       if (step_down_1s_16s_en)
       begin
         int_serdes_phy_mac_phystatus[8]    <= #TP int_serdes_phy_mac_phystatus[7];
         int_serdes_phy_mac_phystatus[9]    <= #TP int_serdes_phy_mac_phystatus[8];
         int_serdes_phy_mac_phystatus[10]   <= #TP int_serdes_phy_mac_phystatus[9];
         int_serdes_phy_mac_phystatus[11]   <= #TP int_serdes_phy_mac_phystatus[10];
         int_serdes_phy_mac_phystatus[12]   <= #TP int_serdes_phy_mac_phystatus[11];
         int_serdes_phy_mac_phystatus[13]   <= #TP int_serdes_phy_mac_phystatus[12];
         int_serdes_phy_mac_phystatus[14]   <= #TP int_serdes_phy_mac_phystatus[13];
         int_serdes_phy_mac_phystatus[15]   <= #TP int_serdes_phy_mac_phystatus[14];
       end

       // Rx_status for serdes
       int_serdes_phy_mac_rxstatus[2:0]      <= #TP phy_mac_rxstatus;

       if (step_down_1s_2s_en || step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
       begin
         int_serdes_phy_mac_rxstatus[5:3]   <= #TP int_serdes_phy_mac_rxstatus[2:0];
       end
       if (step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
       begin
         int_serdes_phy_mac_rxstatus[8:6]   <= #TP int_serdes_phy_mac_rxstatus[5:3];
         int_serdes_phy_mac_rxstatus[11:9]  <= #TP int_serdes_phy_mac_rxstatus[8:6];
       end
       if (step_down_1s_8s_en || step_down_1s_16s_en)
       begin
         int_serdes_phy_mac_rxstatus[14:12] <= #TP int_serdes_phy_mac_rxstatus[11:9];
         int_serdes_phy_mac_rxstatus[17:15] <= #TP int_serdes_phy_mac_rxstatus[14:12];
         int_serdes_phy_mac_rxstatus[20:18] <= #TP int_serdes_phy_mac_rxstatus[17:15];
         int_serdes_phy_mac_rxstatus[23:21] <= #TP int_serdes_phy_mac_rxstatus[20:18];
       end
       if (step_down_1s_16s_en)
       begin
         int_serdes_phy_mac_rxstatus[26:24] <= #TP int_serdes_phy_mac_rxstatus[23:21];
         int_serdes_phy_mac_rxstatus[29:27] <= #TP int_serdes_phy_mac_rxstatus[26:24];
         int_serdes_phy_mac_rxstatus[32:30] <= #TP int_serdes_phy_mac_rxstatus[29:27];
         int_serdes_phy_mac_rxstatus[35:33] <= #TP int_serdes_phy_mac_rxstatus[32:30];
         int_serdes_phy_mac_rxstatus[38:36] <= #TP int_serdes_phy_mac_rxstatus[35:33];
         int_serdes_phy_mac_rxstatus[41:39] <= #TP int_serdes_phy_mac_rxstatus[38:36];
         int_serdes_phy_mac_rxstatus[44:42] <= #TP int_serdes_phy_mac_rxstatus[41:39];
         int_serdes_phy_mac_rxstatus[47:45] <= #TP int_serdes_phy_mac_rxstatus[47:45];
       end
     end
end


// -------------------------------------------------------------------------------------------------------
// Pass only the necessary data to the next level
// On RX path transform from 1s domain to Ns domain (i.e. 1s to 4s)
// if there is no valid data (RxValid = 0 ) we pass only phystatus, rxstatus and rxvalid
// if we have more then 1s we need to extend phystatus, rxstatus to all nr of symbols
// depending on the number os symbols that we have we need to delay the rx_valid
// so that all bytes/symbols have rx_valid
// -------------------------------------------------------------------------------------------------------
assign int_rxdatavalid = (phy_mac_rxvalid_from_queue || reg_phy_mac_rxvalid_from_queue) && pop_enable && !rise_of_rxvalid_rxdatavalid;

always@(posedge int_clk or negedge pipe_rst_n)
begin
   if (!pipe_rst_n) begin
      int_rxdatavalid_reg <= #TP 4'b0;
   end else if (!(int_rxdatavalid || sdown_phy_mac_rxvalid_pclk)) begin
      int_rxdatavalid_reg <= #TP 4'b0;
   end else begin
      int_rxdatavalid_reg[1] <= #TP int_rxdatavalid;
      int_rxdatavalid_reg[2] <= #TP int_rxdatavalid_reg[1];
      int_rxdatavalid_reg[3] <= #TP int_rxdatavalid_reg[2];
   end
end

always@(posedge int_clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       int_phy_mac_rxstatus     <= #TP '0;
       int_phy_mac_rxdata       <= #TP '0;
       int_phy_mac_rxdatak      <= #TP '0;
       int_phy_mac_rxvalid      <= #TP '0;
       int_phy_mac_phystatus    <= #TP {{MAX_NB-1{1'b0}}, 1'b1};
       int_phy_mac_rxdatavalid  <= #TP '0;
       int_phy_mac_rxstartblock <= #TP '0;
       int_phy_mac_rxsynchdr    <= #TP '0;
    // this is to un-pace data, no pacing at gen3 rate
    end else begin
       if (invalid_sym_queue_phy_mac_phystatus[0] || valid_sym_queue_phy_mac_phystatus[0] ||  |int_phy_mac_phystatus) begin

          if ((rx_dst_byte_enable[0] && invalid_sym_queue_phy_mac_rxdatavalid.size() >= pipe_nr_sym &&  pop_invalid_sym) ||
              (rx_dst_byte_enable[0] && phystatus_invalid_sym_queue > 0 && phy_mac_rxvalid && mac_phy_rate < 2) ||
              (!int_phy_mac_rxdatavalid[0] && !rx_dst_byte_enable[0] && invalid_sym_queue_phy_mac_rxdatavalid.size() > 0) ||
              (!pop_enable) )

            int_phy_mac_phystatus[0]      <= #TP (invalid_sym_queue_phy_mac_phystatus.size () == 0 && valid_sym_queue_phy_mac_phystatus.size () == 0) ? 1'b1 :
                                                 invalid_sym_queue_phy_mac_phystatus.size () > 0 ?    invalid_sym_queue_phy_mac_phystatus[0] : int_phy_mac_phystatus[0];

          else
            int_phy_mac_phystatus[0]      <= #TP valid_sym_queue_phy_mac_phystatus.size () > 0 ? valid_sym_queue_phy_mac_phystatus[0] : 1'b0;

          if (step_down_1s_2s_en || step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
          begin
            int_phy_mac_phystatus[1]    <= #TP int_phy_mac_phystatus[0];
          end
          if (step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
          begin
            int_phy_mac_phystatus[2]    <= #TP int_phy_mac_phystatus[1];
            int_phy_mac_phystatus[3]    <= #TP int_phy_mac_phystatus[2];
          end
          if (step_down_1s_8s_en || step_down_1s_16s_en)
          begin
            int_phy_mac_phystatus[4]    <= #TP int_phy_mac_phystatus[3];
            int_phy_mac_phystatus[5]    <= #TP int_phy_mac_phystatus[4];
            int_phy_mac_phystatus[6]    <= #TP int_phy_mac_phystatus[5];
            int_phy_mac_phystatus[7]    <= #TP int_phy_mac_phystatus[6];
          end
          if (step_down_1s_16s_en)
          begin
            int_phy_mac_phystatus[8]    <= #TP int_phy_mac_phystatus[7];
            int_phy_mac_phystatus[9]    <= #TP int_phy_mac_phystatus[8];
            int_phy_mac_phystatus[10]    <= #TP int_phy_mac_phystatus[9];
            int_phy_mac_phystatus[11]    <= #TP int_phy_mac_phystatus[10];
            int_phy_mac_phystatus[12]    <= #TP int_phy_mac_phystatus[11];
            int_phy_mac_phystatus[13]    <= #TP int_phy_mac_phystatus[12];
            int_phy_mac_phystatus[14]    <= #TP int_phy_mac_phystatus[13];
            int_phy_mac_phystatus[15]    <= #TP int_phy_mac_phystatus[14];
          end

       end

       if (receiver_present) begin
        if ((rx_dst_byte_enable[0] && invalid_sym_queue_phy_mac_rxdatavalid.size() >= pipe_nr_sym &&  pop_invalid_sym) ||
            (rx_dst_byte_enable[0] && phystatus_invalid_sym_queue > 0 && phy_mac_rxvalid && mac_phy_rate < 2) ||
            (!int_phy_mac_rxdatavalid[0] && !rx_dst_byte_enable[0] && invalid_sym_queue_phy_mac_rxdatavalid.size() > 0) ||
            (!pop_enable))
            int_phy_mac_rxstatus[2:0]      <= #TP invalid_sym_queue_phy_mac_rxstatus.size() > 0 ? invalid_sym_queue_phy_mac_rxstatus[0] : 3'b000;
        else
            int_phy_mac_rxstatus[2:0]      <= #TP valid_sym_queue_phy_mac_rxstatus.size () > 0 ? valid_sym_queue_phy_mac_rxstatus[0] : 3'b000;

         if (step_down_1s_2s_en || step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
          begin
            int_phy_mac_rxstatus[5:3]   <= #TP int_phy_mac_rxstatus[2:0];
          end
          if (step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
          begin
            int_phy_mac_rxstatus[8:6]   <= #TP int_phy_mac_rxstatus[5:3];
            int_phy_mac_rxstatus[11:9]  <= #TP int_phy_mac_rxstatus[8:6];
          end
          if (step_down_1s_8s_en || step_down_1s_16s_en)
          begin
            int_phy_mac_rxstatus[14:12] <= #TP int_phy_mac_rxstatus[11:9];
            int_phy_mac_rxstatus[17:15] <= #TP int_phy_mac_rxstatus[14:12];
            int_phy_mac_rxstatus[20:18] <= #TP int_phy_mac_rxstatus[17:15];
            int_phy_mac_rxstatus[23:21] <= #TP int_phy_mac_rxstatus[20:18];
          end
          if (step_down_1s_16s_en)
          begin
            int_phy_mac_rxstatus[26:24] <= #TP int_phy_mac_rxstatus[23:21];
            int_phy_mac_rxstatus[29:27] <= #TP int_phy_mac_rxstatus[26:24];
            int_phy_mac_rxstatus[32:30] <= #TP int_phy_mac_rxstatus[29:27];
            int_phy_mac_rxstatus[35:33] <= #TP int_phy_mac_rxstatus[32:30];
            int_phy_mac_rxstatus[38:36] <= #TP int_phy_mac_rxstatus[35:33];
            int_phy_mac_rxstatus[41:39] <= #TP int_phy_mac_rxstatus[38:36];
            int_phy_mac_rxstatus[44:42] <= #TP int_phy_mac_rxstatus[41:39];
            int_phy_mac_rxstatus[47:45] <= #TP int_phy_mac_rxstatus[47:45];
          end
       end

       if (!int_rxdatavalid && rx_dst_byte_enable[0]) begin
         if (!detection_window || (detection_window && !receiver_present))
         
         if (! (|int_phy_mac_rxvalid))
            int_phy_mac_rxstatus       <= #TP '0;
          // if we want a clean phy interface if rx_valid is 0 we can output all 0 on the rx_data and rx_datak
          // int_phy_mac_rxdata       <= #TP '0;
          // int_phy_mac_rxdatak      <= #TP '0;
          int_phy_mac_rxvalid[0]      <= #TP 1'b0;
          int_phy_mac_rxdatavalid[0]  <= #TP 1'b0;
          if ( !(|int_phy_mac_rxdatavalid))
          begin
            int_phy_mac_rxstartblock    <= #TP '0;
            int_phy_mac_rxsynchdr       <= #TP '0;
          end

          if (step_down_1s_2s_en || step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
          begin
            int_phy_mac_rxvalid[1]      <= #TP int_phy_mac_rxvalid[0];
            int_phy_mac_rxdatavalid[1]  <= #TP int_phy_mac_rxdatavalid[0];
          end
          if (step_down_1s_4s_en || step_down_1s_8s_en || step_down_1s_16s_en)
          begin
            int_phy_mac_rxvalid[2]      <= #TP int_phy_mac_rxvalid[1];
            int_phy_mac_rxvalid[3]      <= #TP int_phy_mac_rxvalid[2];
            int_phy_mac_rxdatavalid[2]  <= #TP int_phy_mac_rxdatavalid[1];
            int_phy_mac_rxdatavalid[3]  <= #TP int_phy_mac_rxdatavalid[2];
          end
          if (step_down_1s_8s_en || step_down_1s_16s_en)
          begin
            int_phy_mac_rxvalid[4]      <= #TP int_phy_mac_rxvalid[3];
            int_phy_mac_rxvalid[5]      <= #TP int_phy_mac_rxvalid[4];
            int_phy_mac_rxvalid[6]      <= #TP int_phy_mac_rxvalid[5];
            int_phy_mac_rxvalid[7]      <= #TP int_phy_mac_rxvalid[6];
            int_phy_mac_rxdatavalid[4]  <= #TP int_phy_mac_rxdatavalid[3];
            int_phy_mac_rxdatavalid[5]  <= #TP int_phy_mac_rxdatavalid[4];
            int_phy_mac_rxdatavalid[6]  <= #TP int_phy_mac_rxdatavalid[5];
            int_phy_mac_rxdatavalid[7]  <= #TP int_phy_mac_rxdatavalid[6];

          end
          if (step_down_1s_16s_en)
          begin
            int_phy_mac_rxvalid[8]       <= #TP int_phy_mac_rxvalid[7];
            int_phy_mac_rxvalid[9]       <= #TP int_phy_mac_rxvalid[8];
            int_phy_mac_rxvalid[10]      <= #TP int_phy_mac_rxvalid[9];
            int_phy_mac_rxvalid[11]      <= #TP int_phy_mac_rxvalid[10];
            int_phy_mac_rxvalid[12]      <= #TP int_phy_mac_rxvalid[11];
            int_phy_mac_rxvalid[13]      <= #TP int_phy_mac_rxvalid[12];
            int_phy_mac_rxvalid[14]      <= #TP int_phy_mac_rxvalid[13];
            int_phy_mac_rxvalid[15]      <= #TP int_phy_mac_rxvalid[14];
            int_phy_mac_rxdatavalid[8]   <= #TP int_phy_mac_rxdatavalid[7];
            int_phy_mac_rxdatavalid[9]   <= #TP int_phy_mac_rxdatavalid[8];
            int_phy_mac_rxdatavalid[10]  <= #TP int_phy_mac_rxdatavalid[9];
            int_phy_mac_rxdatavalid[11]  <= #TP int_phy_mac_rxdatavalid[10];
            int_phy_mac_rxdatavalid[12]  <= #TP int_phy_mac_rxdatavalid[11];
            int_phy_mac_rxdatavalid[13]  <= #TP int_phy_mac_rxdatavalid[12];
            int_phy_mac_rxdatavalid[14]  <= #TP int_phy_mac_rxdatavalid[13];
            int_phy_mac_rxdatavalid[15]  <= #TP int_phy_mac_rxdatavalid[14];
          end

       end
       if (rate_changed && !lock) begin
           int_phy_mac_rxstatus     <= #TP '0;
           int_phy_mac_rxdata       <= #TP '0;
           int_phy_mac_rxdatak      <= #TP '0;
           int_phy_mac_rxvalid      <= #TP '0;
           int_phy_mac_rxdatavalid  <= #TP '0;
           int_phy_mac_rxstartblock <= #TP '0;
           int_phy_mac_rxsynchdr    <= #TP '0;
       end else
       if (int_rxdatavalid) begin
          if (rx_dst_byte_enable[0]) begin
            // if there are invalid symbols make this group of bites invalid
            if ((pop_invalid_sym && invalid_sym_queue_phy_mac_rxdatavalid.size() >= pipe_nr_sym) || (phystatus_invalid_sym_queue > 0 && phy_mac_rxvalid && mac_phy_rate < 2) )
            begin
               int_phy_mac_rxvalid[0]     <= #TP invalid_sym_queue_phy_mac_rxvalid[0];
               if (!receiver_present)
                 int_phy_mac_rxstatus[2:0]<= #TP {45'b0, invalid_sym_queue_phy_mac_rxstatus[0]};
                 
               int_phy_mac_rxdata[PIPE_DATA_WD-1:0]    <= #TP invalid_sym_queue_phy_mac_rxdata[0];
               int_phy_mac_rxdatak[0]     <= #TP invalid_sym_queue_phy_mac_rxdatak[0];
               int_phy_mac_rxdatavalid[0] <= #TP invalid_sym_queue_phy_mac_rxdatavalid[0];
               int_phy_mac_rxstartblock[0]<= #TP invalid_sym_queue_phy_mac_rxstartblock[0];
               int_phy_mac_rxsynchdr[1:0] <= #TP invalid_sym_queue_phy_mac_rxsynchdr[0];
            end else begin // if no invalid sym
                 int_phy_mac_rxvalid[0]   <= #TP valid_sym_queue_phy_mac_rxvalid[0];
               if (!receiver_present)
                 int_phy_mac_rxstatus[2:0]<= #TP {45'b0, valid_sym_queue_phy_mac_rxstatus[0]};
                 
               int_phy_mac_rxdata[PIPE_DATA_WD-1:0]    <= #TP valid_sym_queue_phy_mac_rxdata[0];
               int_phy_mac_rxdatak[0]     <= #TP valid_sym_queue_phy_mac_rxdatak[0];
               int_phy_mac_rxdatavalid[0] <= #TP valid_sym_queue_phy_mac_rxdatavalid[0];
               int_phy_mac_rxstartblock[0]<= #TP valid_sym_queue_phy_mac_rxstartblock[0];
               int_phy_mac_rxsynchdr[1:0] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end   // symbol 0
         end else
          if (rx_dst_byte_enable[1]) begin
             int_phy_mac_rxdatavalid[1]   <= #TP int_phy_mac_rxdatavalid[0];
             if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0]) begin // if current group of symbols is invalid
               // if (invalid_sym_queue_phy_mac_rxdatavalid.size() > 0) begin
                int_phy_mac_rxvalid[1]       <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)      ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
                if (!receiver_present)
                   int_phy_mac_rxstatus[5:3] <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)     ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
                int_phy_mac_rxdata[PIPE_DATA_WD*2-1:PIPE_DATA_WD*1]     <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)       ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
                int_phy_mac_rxdatak[1]       <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)      ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
                int_phy_mac_rxstartblock[1]  <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0) ? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
                int_phy_mac_rxsynchdr[3:2]   <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)    ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
              //  end
             end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0) begin
                int_phy_mac_rxvalid[1]       <= #TP valid_sym_queue_phy_mac_rxvalid[0];
                if (!receiver_present)
                   int_phy_mac_rxstatus[5:3] <= #TP valid_sym_queue_phy_mac_rxstatus[0];
                int_phy_mac_rxdata[PIPE_DATA_WD*2-1:PIPE_DATA_WD*1]     <= #TP valid_sym_queue_phy_mac_rxdata[0];
                int_phy_mac_rxdatak[1]       <= #TP valid_sym_queue_phy_mac_rxdatak[0];
                int_phy_mac_rxstartblock[1]  <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
                int_phy_mac_rxsynchdr[3:2]   <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
             end // symbol 1
          end else
          if (rx_dst_byte_enable[2]) begin
            int_phy_mac_rxdatavalid[2]   <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
                int_phy_mac_rxvalid[2]     <=  #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
                if (!receiver_present)
                int_phy_mac_rxstatus[8:6]  <=  #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
                int_phy_mac_rxdata[PIPE_DATA_WD*3-1:PIPE_DATA_WD*2]  <=  #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
                int_phy_mac_rxdatak[2]     <=  #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
                int_phy_mac_rxstartblock[2]<=  #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
                int_phy_mac_rxsynchdr[5:4] <=  #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
                //end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0) begin
                int_phy_mac_rxvalid[2]     <=  #TP valid_sym_queue_phy_mac_rxvalid[0];
                if (!receiver_present)
                int_phy_mac_rxstatus[8:6]   <=  #TP valid_sym_queue_phy_mac_rxstatus[0];
                int_phy_mac_rxdata[PIPE_DATA_WD*3-1:PIPE_DATA_WD*2]   <=  #TP valid_sym_queue_phy_mac_rxdata[0];
                int_phy_mac_rxdatak[2]      <=  #TP valid_sym_queue_phy_mac_rxdatak[0];
                int_phy_mac_rxstartblock[2] <=  #TP valid_sym_queue_phy_mac_rxstartblock[0];
                int_phy_mac_rxsynchdr[5:4]  <=  #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end // symbol 2
          end else
          if (rx_dst_byte_enable[3]) begin
              int_phy_mac_rxdatavalid[3]   <= #TP int_phy_mac_rxdatavalid[0];
              if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
                int_phy_mac_rxvalid[3]      <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
                if (!receiver_present)
                int_phy_mac_rxstatus[11:9]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
                int_phy_mac_rxdata[PIPE_DATA_WD*4-1:PIPE_DATA_WD*3]   <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
                int_phy_mac_rxdatak[3]      <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
                int_phy_mac_rxstartblock[3] <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
                int_phy_mac_rxsynchdr[7:6]  <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
               // end
              end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0) begin
               int_phy_mac_rxvalid[3]      <= #TP valid_sym_queue_phy_mac_rxvalid[0];
               if (!receiver_present)
               int_phy_mac_rxstatus[11:9]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
               int_phy_mac_rxdata[PIPE_DATA_WD*4-1:PIPE_DATA_WD*3]   <= #TP valid_sym_queue_phy_mac_rxdata[0];
               int_phy_mac_rxdatak[3]      <= #TP valid_sym_queue_phy_mac_rxdatak[0];
               int_phy_mac_rxstartblock[3] <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
               int_phy_mac_rxsynchdr[7:6]  <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
              end // symbol 3
          end else
          if (rx_dst_byte_enable[4]) begin
            int_phy_mac_rxdatavalid[4]    <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[4]      <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[14:12] <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*5-1:PIPE_DATA_WD*4]   <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[4]      <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[4] <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[9:8]  <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
           end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0) begin
              int_phy_mac_rxvalid[4]      <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[14:12] <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*5-1:PIPE_DATA_WD*4]   <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[4]      <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[4] <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[9:8]  <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
           end   // symbol 4
          end else
          if (rx_dst_byte_enable[5]) begin
            int_phy_mac_rxdatavalid[5]     <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[5]       <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[17:15]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*6-1:PIPE_DATA_WD*5]    <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[5]       <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[5]  <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[11:10] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0) begin
              int_phy_mac_rxvalid[5]       <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[17:15]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*6-1:PIPE_DATA_WD*5]    <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[5]       <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[5]  <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[11:10] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end // symbol 5
          end else
          if (rx_dst_byte_enable[6]) begin
            int_phy_mac_rxdatavalid[6]     <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[6]       <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[20:18]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*7-1:PIPE_DATA_WD*6]    <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[6]       <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[6]  <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[13:12] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
            //  end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0) begin
              int_phy_mac_rxvalid[6]       <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[20:18]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*7-1:PIPE_DATA_WD*6]    <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[6]       <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[6]  <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[13:12] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end  // symbol 6
          end else
          if (rx_dst_byte_enable[7]) begin
            int_phy_mac_rxdatavalid[7]     <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[7]       <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[23:21]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*8-1:PIPE_DATA_WD*7]    <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[7]       <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[7]  <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[15:14] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0)  begin
              int_phy_mac_rxvalid[7]      <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[23:21]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*8-1:PIPE_DATA_WD*7]    <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[7]       <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[7]  <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[15:14] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end
          end else
          if (rx_dst_byte_enable[8]) begin
            int_phy_mac_rxdatavalid[8]   <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[8]      <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[26:24]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*9-1:PIPE_DATA_WD*8]    <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[8]       <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[8]  <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[17:16] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0)  begin
              int_phy_mac_rxvalid[8]      <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[26:24]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*9-1:PIPE_DATA_WD*8]    <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[8]       <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[8]  <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[17:16] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end
          end else
          if (rx_dst_byte_enable[9]) begin
            int_phy_mac_rxdatavalid[9]     <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[9]       <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[29:27]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*10-1:PIPE_DATA_WD*9]    <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[9]       <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[9]  <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[19:18] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0)  begin
              int_phy_mac_rxvalid[9]       <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[29:27]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*10-1:PIPE_DATA_WD*9]    <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[9]       <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[9]  <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[19:18] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end
          end else
          if (rx_dst_byte_enable[10]) begin
            int_phy_mac_rxdatavalid[10]    <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[10]      <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[32:30]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*11-1:PIPE_DATA_WD*10]    <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[10]      <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[10] <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[21:20] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0)  begin
              int_phy_mac_rxvalid[10]       <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[32:30]   <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*11-1:PIPE_DATA_WD*10]     <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[10]       <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[10]  <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[21:20]  <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end
          end else
          if (rx_dst_byte_enable[11]) begin
            int_phy_mac_rxdatavalid[11]    <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[11]      <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[35:33]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*12-1:PIPE_DATA_WD*11]    <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[11]      <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[11] <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[23:22] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0)  begin
              int_phy_mac_rxvalid[11]      <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[35:33]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*12-1:PIPE_DATA_WD*11]    <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[11]      <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[11] <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[23:22] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end
          end else
          if (rx_dst_byte_enable[12]) begin
            int_phy_mac_rxdatavalid[12]   <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[12]      <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[38:36]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*13-1:PIPE_DATA_WD*12]   <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[12]      <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[12] <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[25:24] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0)  begin
              int_phy_mac_rxvalid[12]      <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[38:36]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*13-1:PIPE_DATA_WD*12]   <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[12]      <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[12] <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[25:24] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end
          end else
          if (rx_dst_byte_enable[13]) begin
            int_phy_mac_rxdatavalid[13]    <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[13]      <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[41:39]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*14-1:PIPE_DATA_WD*13]  <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[13]      <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[13] <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[27:26] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0)  begin
              int_phy_mac_rxvalid[13]      <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[41:39]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*14-1:PIPE_DATA_WD*13]  <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[13]      <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[13] <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[27:26] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end
          end else
          if (rx_dst_byte_enable[14]) begin
            int_phy_mac_rxdatavalid[14]    <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[14]      <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[44:42]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*15-1:PIPE_DATA_WD*14]  <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[14]      <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[14] <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[29:28] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0)  begin
              int_phy_mac_rxvalid[14]      <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[44:42]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*15-1:PIPE_DATA_WD*14]  <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[14]      <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[14] <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[29:28] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end
          end else
          if (rx_dst_byte_enable[15]) begin
            int_phy_mac_rxdatavalid[15]    <= #TP int_phy_mac_rxdatavalid[0];
            if (!int_phy_mac_rxdatavalid[0] || !int_phy_mac_rxvalid[0])  begin // if current group of symbols is invalid
              int_phy_mac_rxvalid[15]      <= #TP (invalid_sym_queue_phy_mac_rxvalid.size() > 0)     ? invalid_sym_queue_phy_mac_rxvalid[0]     : 'd0;
              if (!receiver_present)
              int_phy_mac_rxstatus[47:45]  <= #TP (invalid_sym_queue_phy_mac_rxstatus.size() > 0)    ? invalid_sym_queue_phy_mac_rxstatus[0]    : 'd0;
              int_phy_mac_rxdata[PIPE_DATA_WD*16-1:PIPE_DATA_WD*15]  <= #TP (invalid_sym_queue_phy_mac_rxdata.size() > 0)      ? invalid_sym_queue_phy_mac_rxdata[0]      : 'd0;
              int_phy_mac_rxdatak[15]      <= #TP (invalid_sym_queue_phy_mac_rxdatak.size() > 0)     ? invalid_sym_queue_phy_mac_rxdatak[0]     : 'd0;
              int_phy_mac_rxstartblock[15] <= #TP (invalid_sym_queue_phy_mac_rxstartblock.size() > 0)? invalid_sym_queue_phy_mac_rxstartblock[0]: 'd0;
              int_phy_mac_rxsynchdr[31:30] <= #TP (invalid_sym_queue_phy_mac_rxsynchdr.size() > 0)   ? invalid_sym_queue_phy_mac_rxsynchdr[0]   : 'd0;
             // end
            end else if (valid_sym_queue_phy_mac_rxdatavalid.size() > 0)  begin
              int_phy_mac_rxvalid[15]      <= #TP valid_sym_queue_phy_mac_rxvalid[0];
              if (!receiver_present)
              int_phy_mac_rxstatus[47:45]  <= #TP valid_sym_queue_phy_mac_rxstatus[0];
              int_phy_mac_rxdata[PIPE_DATA_WD*16-1:PIPE_DATA_WD*15]  <= #TP valid_sym_queue_phy_mac_rxdata[0];
              int_phy_mac_rxdatak[15]      <= #TP valid_sym_queue_phy_mac_rxdatak[0];
              int_phy_mac_rxstartblock[15] <= #TP valid_sym_queue_phy_mac_rxstartblock[0];
              int_phy_mac_rxsynchdr[31:30] <= #TP valid_sym_queue_phy_mac_rxsynchdr[0];
            end
          end
      end
    end
end


always@(posedge int_clk or negedge pipe_rst_n)
begin
   if (!pipe_rst_n) begin
    //todo
   end else begin
     #(TP/2.0);
      // trash first symbol from all queues
      if ((rx_dst_byte_enable[0] && invalid_sym_queue_phy_mac_rxdatavalid.size() >= pipe_nr_sym && pop_invalid_sym ) ||
          (rx_dst_byte_enable[0] && phystatus_invalid_sym_queue > 0 && phy_mac_rxvalid && mac_phy_rate < 2) ||
          (!int_phy_mac_rxdatavalid[0] && !rx_dst_byte_enable[0] ) ||
          (!pop_enable))
      begin
        if (invalid_sym_queue_phy_mac_phystatus[0])
            phystatus_invalid_sym_queue = phystatus_invalid_sym_queue - 1;
        void'(invalid_sym_queue_phy_mac_rxvalid.pop_front());
        void'(invalid_sym_queue_phy_mac_rxstatus.pop_front());
        void'(invalid_sym_queue_phy_mac_rxdata.pop_front());
        void'(invalid_sym_queue_phy_mac_rxdatak.pop_front());
        void'(invalid_sym_queue_phy_mac_rxdatavalid.pop_front());
        void'(invalid_sym_queue_phy_mac_phystatus.pop_front());
        void'(invalid_sym_queue_phy_mac_rxstartblock.pop_front());
        void'(invalid_sym_queue_phy_mac_rxsynchdr.pop_front());
      end else begin
         if (pop_enable)
         begin
           if (valid_sym_queue_phy_mac_phystatus[0])
              phystatus_valid_sym_queue = phystatus_valid_sym_queue - 1;

              void'(valid_sym_queue_phy_mac_rxvalid.pop_front());
              void'(valid_sym_queue_phy_mac_rxstatus.pop_front());
              void'(valid_sym_queue_phy_mac_rxdata.pop_front());
              void'(valid_sym_queue_phy_mac_rxdatak.pop_front());
              void'(valid_sym_queue_phy_mac_rxdatavalid.pop_front());
              void'(valid_sym_queue_phy_mac_phystatus.pop_front());
              void'(valid_sym_queue_phy_mac_rxstartblock.pop_front());
              void'(valid_sym_queue_phy_mac_rxsynchdr.pop_front());
           end
       end
    end
   
end

// -----------------------------------------------------------------------------
// int_phy_mac_rxstatus goes to priority logic
// get the priority of rxstatus
// -----------------------------------------------------------------------------
wire    [2:0]    sdown_phy_mac_rxstatus_priority;
wire    [2:0]    sdown_phy_mac_rxstatus_priority_nb8_low;
wire    [2:0]    sdown_phy_mac_rxstatus_priority_nb8_high;
wire    [2:0]    sdown_phy_mac_rxstatus_priority_nb16;
wire    [2:0]    sdown_phy_mac_rxstatus_priority10;
wire    [2:0]    sdown_phy_mac_rxstatus_priority32;
wire    [2:0]    sdown_phy_mac_rxstatus_priority54;
wire    [2:0]    sdown_phy_mac_rxstatus_priority76;

wire    [2:0]    sdown_phy_mac_rxstatus_priority98;
wire    [2:0]    sdown_phy_mac_rxstatus_priority1110;
wire    [2:0]    sdown_phy_mac_rxstatus_priority1312;
wire    [2:0]    sdown_phy_mac_rxstatus_priority1514;



wire    [2:0]    sdown_phy_mac_rxstatus_priority30;
wire    [2:0]    sdown_phy_mac_rxstatus_priority74;

wire    [2:0]    sdown_phy_mac_rxstatus_priority118;
wire    [2:0]    sdown_phy_mac_rxstatus_priority1512;

reg     [(MAX_NB*3)-1:0]    mux_int_phy_mac_rxstatus;           // PIPE receive status
reg     [MAX_NB-1:0]        mux_int_phy_mac_phystatus;

assign mux_int_phy_mac_rxstatus  = serdes_arch ? int_serdes_phy_mac_rxstatus  : int_phy_mac_rxstatus;
assign mux_int_phy_mac_phystatus = serdes_arch ? int_serdes_phy_mac_phystatus : int_phy_mac_phystatus;

assign sdown_phy_mac_rxstatus_priority10 =
    (error_priority(mux_int_phy_mac_rxstatus[5:3], mux_int_phy_mac_phystatus, detection_window) >
     error_priority(mux_int_phy_mac_rxstatus[2:0], mux_int_phy_mac_phystatus, detection_window)) ?
        mux_int_phy_mac_rxstatus[5:3] :
        mux_int_phy_mac_rxstatus[2:0];
assign sdown_phy_mac_rxstatus_priority32 =
    (error_priority(mux_int_phy_mac_rxstatus[11:9], mux_int_phy_mac_phystatus, detection_window) >
     error_priority(mux_int_phy_mac_rxstatus[8:6],  mux_int_phy_mac_phystatus, detection_window)) ?
        mux_int_phy_mac_rxstatus[11:9] :
        mux_int_phy_mac_rxstatus[8:6];
assign sdown_phy_mac_rxstatus_priority54 =
     (error_priority(mux_int_phy_mac_rxstatus[17:15], mux_int_phy_mac_phystatus, detection_window) >
      error_priority(mux_int_phy_mac_rxstatus[14:12],   mux_int_phy_mac_phystatus, detection_window)) ?
        mux_int_phy_mac_rxstatus[17:15] :
        mux_int_phy_mac_rxstatus[14:12];
assign sdown_phy_mac_rxstatus_priority76 =
    (error_priority(mux_int_phy_mac_rxstatus[23:21], mux_int_phy_mac_phystatus, detection_window) >
     error_priority(mux_int_phy_mac_rxstatus[20:18], mux_int_phy_mac_phystatus, detection_window)) ?
        mux_int_phy_mac_rxstatus[23:21] :
        mux_int_phy_mac_rxstatus[20:18];
assign sdown_phy_mac_rxstatus_priority98 =
    (error_priority(mux_int_phy_mac_rxstatus[29:27], mux_int_phy_mac_phystatus, detection_window) >
     error_priority(mux_int_phy_mac_rxstatus[26:24], mux_int_phy_mac_phystatus, detection_window)) ?
        mux_int_phy_mac_rxstatus[29:27] :
        mux_int_phy_mac_rxstatus[26:24];
assign sdown_phy_mac_rxstatus_priority1110 =
    (error_priority(mux_int_phy_mac_rxstatus[35:33], mux_int_phy_mac_phystatus, detection_window) >
     error_priority(mux_int_phy_mac_rxstatus[32:30], mux_int_phy_mac_phystatus, detection_window)) ?
        mux_int_phy_mac_rxstatus[35:33] :
        mux_int_phy_mac_rxstatus[32:30];
assign sdown_phy_mac_rxstatus_priority1312 =
    (error_priority(mux_int_phy_mac_rxstatus[41:39], mux_int_phy_mac_phystatus, detection_window) >
     error_priority(mux_int_phy_mac_rxstatus[38:36], mux_int_phy_mac_phystatus, detection_window)) ?
        mux_int_phy_mac_rxstatus[41:39] :
        mux_int_phy_mac_rxstatus[38:36];
assign sdown_phy_mac_rxstatus_priority1514 =
    (error_priority(mux_int_phy_mac_rxstatus[47:45], mux_int_phy_mac_phystatus, detection_window) >
     error_priority(mux_int_phy_mac_rxstatus[44:42], mux_int_phy_mac_phystatus, detection_window)) ?
        mux_int_phy_mac_rxstatus[47:45] :
        mux_int_phy_mac_rxstatus[44:42];



assign sdown_phy_mac_rxstatus_priority30 =
    (error_priority(sdown_phy_mac_rxstatus_priority32, mux_int_phy_mac_phystatus, detection_window) >
     error_priority(sdown_phy_mac_rxstatus_priority10, mux_int_phy_mac_phystatus, detection_window)) ?
        sdown_phy_mac_rxstatus_priority32 :
        sdown_phy_mac_rxstatus_priority10 ;

assign sdown_phy_mac_rxstatus_priority74 =
    (error_priority(sdown_phy_mac_rxstatus_priority76, mux_int_phy_mac_phystatus, detection_window) >
     error_priority(sdown_phy_mac_rxstatus_priority54, mux_int_phy_mac_phystatus, detection_window)) ?
        sdown_phy_mac_rxstatus_priority76 :
        sdown_phy_mac_rxstatus_priority54 ;

assign sdown_phy_mac_rxstatus_priority_nb8_low =
    (error_priority(sdown_phy_mac_rxstatus_priority74, mux_int_phy_mac_phystatus, detection_window) >
    error_priority(sdown_phy_mac_rxstatus_priority30,  mux_int_phy_mac_phystatus, detection_window)) ?
        sdown_phy_mac_rxstatus_priority74 :
        sdown_phy_mac_rxstatus_priority30;


assign sdown_phy_mac_rxstatus_priority118 =
    (error_priority(sdown_phy_mac_rxstatus_priority1110, mux_int_phy_mac_phystatus, detection_window) >
     error_priority(sdown_phy_mac_rxstatus_priority98,   mux_int_phy_mac_phystatus, detection_window)) ?
        sdown_phy_mac_rxstatus_priority1110 :
        sdown_phy_mac_rxstatus_priority98 ;

assign sdown_phy_mac_rxstatus_priority1512 =
    (error_priority(sdown_phy_mac_rxstatus_priority1514, mux_int_phy_mac_phystatus, detection_window) >
     error_priority(sdown_phy_mac_rxstatus_priority1312, mux_int_phy_mac_phystatus, detection_window)) ?
        sdown_phy_mac_rxstatus_priority1514 :
        sdown_phy_mac_rxstatus_priority1312 ;

assign sdown_phy_mac_rxstatus_priority_nb8_high =
    (error_priority(sdown_phy_mac_rxstatus_priority1512, mux_int_phy_mac_phystatus, detection_window) >
    error_priority(sdown_phy_mac_rxstatus_priority118,   mux_int_phy_mac_phystatus, detection_window)) ?
        sdown_phy_mac_rxstatus_priority1512 :
        sdown_phy_mac_rxstatus_priority118;

assign sdown_phy_mac_rxstatus_priority_nb16 =
    (error_priority(sdown_phy_mac_rxstatus_priority_nb8_high, mux_int_phy_mac_phystatus, detection_window) >
    error_priority(sdown_phy_mac_rxstatus_priority_nb8_low,   mux_int_phy_mac_phystatus, detection_window)) ?
        sdown_phy_mac_rxstatus_priority_nb8_high :
        sdown_phy_mac_rxstatus_priority_nb8_low;

assign sdown_phy_mac_rxstatus_priority = sdown_phy_mac_rxstatus_priority_nb16;

// --------------------------------------------------------------------------
// Sinc RX signals on int_clk
// --------------------------------------------------------------------------
// this is for serdes arch
always@(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
        sdown_serdes_phy_mac_phystatus_int_clk        <= #TP 1'b1;
        sdown_serdes_phy_mac_rxstatus_int_clk         <= #TP '0;
    end else begin
        sdown_serdes_phy_mac_phystatus_int_clk <= #TP |int_serdes_phy_mac_phystatus;
        sdown_serdes_phy_mac_rxstatus_int_clk  <= #TP sdown_phy_mac_rxstatus_priority;

    end
end

always@(posedge int_clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
        sdown_phy_mac_rxdata_int_clk           <= #TP '0;
        sdown_phy_mac_rxdatak_int_clk          <= #TP '0;
        sdown_phy_mac_rxvalid_int_clk          <= #TP '0;
        sdown_phy_mac_phystatus_int_clk        <= #TP 1'b1;
        sdown_phy_mac_rxstatus_int_clk         <= #TP '0;
        sdown_phy_mac_rxdatavalid_int_clk      <= #TP '0;
         sdown_phy_mac_rxdatavalid_int_clk_r   <= #TP '0;
    end else begin
        sdown_phy_mac_phystatus_int_clk <= #TP |int_phy_mac_phystatus;
        if (sdown_phy_mac_rxstatus_priority === 3'b011 || (detection_window && (|int_phy_mac_phystatus)))
           sdown_phy_mac_rxstatus_int_clk  <= #TP sdown_phy_mac_rxstatus_priority;
        if (rx_dst_byte_enable[0]) begin
           sdown_phy_mac_rxdata_int_clk        <= #TP int_phy_mac_rxdata;
           sdown_phy_mac_rxdatak_int_clk       <= #TP int_phy_mac_rxdatak;
           sdown_phy_mac_rxvalid_int_clk       <= #TP |int_phy_mac_rxvalid;
           sdown_phy_mac_rxdatavalid_int_clk   <= #TP |int_phy_mac_rxdatavalid;
           sdown_phy_mac_rxstatus_int_clk      <= #TP  sdown_phy_mac_rxstatus_priority;
        end
        sdown_phy_mac_rxdatavalid_int_clk_r    <= #TP sdown_phy_mac_rxdatavalid_int_clk;
    end
end

wire sdown_phy_mac_rxdatavalid_int_clk_mux;
assign sdown_phy_mac_rxdatavalid_int_clk_mux = sdown_phy_mac_rxdatavalid_int_clk && pace_rxdatavalid;

always @(posedge int_clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       sdown_phy_mac_rxstartblock_int_clk  <= #TP '0;
       sdown_phy_mac_rxsynchdr_int_clk     <= #TP '0;
    end else begin
      sdown_phy_mac_rxstartblock_int_clk  <= #TP sdown_phy_mac_rxstartblock_int_clk;
      sdown_phy_mac_rxsynchdr_int_clk     <= #TP sdown_phy_mac_rxsynchdr_int_clk;

      if (!(|int_phy_mac_rxvalid))  begin
         sdown_phy_mac_rxstartblock_int_clk  <= #TP '0;
         sdown_phy_mac_rxsynchdr_int_clk     <= #TP '0;
      end else if (rx_dst_byte_enable[0]) begin

         sdown_phy_mac_rxstartblock_int_clk[0]  <= #TP int_phy_mac_rxstartblock[0] || int_phy_mac_rxstartblock[1] || int_phy_mac_rxstartblock[2] || int_phy_mac_rxstartblock[3] ;
         sdown_phy_mac_rxsynchdr_int_clk[1:0]   <= #TP int_phy_mac_rxstartblock[0] ? int_phy_mac_rxsynchdr[1:0] :
                                                       int_phy_mac_rxstartblock[1] ? int_phy_mac_rxsynchdr[3:2] :  
                                                       int_phy_mac_rxstartblock[2] ? int_phy_mac_rxsynchdr[5:4] : 
                                                       int_phy_mac_rxstartblock[3] ? int_phy_mac_rxsynchdr[7:6] : '0;

         if (RXSB_WD > 1) begin
            sdown_phy_mac_rxstartblock_int_clk[1]  <= #TP int_phy_mac_rxstartblock[4] || int_phy_mac_rxstartblock[5] || int_phy_mac_rxstartblock[6] || int_phy_mac_rxstartblock[7];
            sdown_phy_mac_rxsynchdr_int_clk[3:2]   <= #TP int_phy_mac_rxstartblock[4] ? int_phy_mac_rxsynchdr[9:8]   :
                                                          int_phy_mac_rxstartblock[5] ? int_phy_mac_rxsynchdr[11:10] :  
                                                          int_phy_mac_rxstartblock[6] ? int_phy_mac_rxsynchdr[13:12] : 
                                                          int_phy_mac_rxstartblock[7] ? int_phy_mac_rxsynchdr[15:14] : '0;  

            if (RXSB_WD == 4)
            begin
              sdown_phy_mac_rxstartblock_int_clk[2]  <= #TP int_phy_mac_rxstartblock[8] || int_phy_mac_rxstartblock[9] || int_phy_mac_rxstartblock[10] || int_phy_mac_rxstartblock[11];
              sdown_phy_mac_rxsynchdr_int_clk[5:4]   <= #TP int_phy_mac_rxstartblock[8] ? int_phy_mac_rxsynchdr[17:16]   :
                                                            int_phy_mac_rxstartblock[9] ? int_phy_mac_rxsynchdr[19:18] :  
                                                            int_phy_mac_rxstartblock[10] ? int_phy_mac_rxsynchdr[21:20] : 
                                                            int_phy_mac_rxstartblock[11] ? int_phy_mac_rxsynchdr[23:22] : '0;

              sdown_phy_mac_rxstartblock_int_clk[3]  <= #TP int_phy_mac_rxstartblock[12] || int_phy_mac_rxstartblock[13] || int_phy_mac_rxstartblock[14] || int_phy_mac_rxstartblock[15];
              sdown_phy_mac_rxsynchdr_int_clk[7:6]   <= #TP int_phy_mac_rxstartblock[12] ? int_phy_mac_rxsynchdr[25:24]   :
                                                            int_phy_mac_rxstartblock[13] ? int_phy_mac_rxsynchdr[27:26] :  
                                                            int_phy_mac_rxstartblock[14] ? int_phy_mac_rxsynchdr[29:28] : 
                                                            int_phy_mac_rxstartblock[15] ? int_phy_mac_rxsynchdr[31:30] : '0; 
            end
         end
      end
    end
end

always @(posedge int_clk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
        sdown_phy_mac_ebuf_location_int_clk <= #TP '0;
    end else begin
        sdown_phy_mac_ebuf_location_int_clk <= #TP phy_mac_ebuf_location_rr;
    end
end

// we need to gate the output until pclk it is back (lock is back) after a low power state
// @gen3/4 we need to start outputting data sync with startblock

always @(posedge int_clk or negedge pipe_rst_n or negedge lock)
begin
    if (!pipe_rst_n)                                                   output_en <= #TP 1'b0; else
    if ((mac_phy_rate > 1) && lock && sdown_phy_mac_rxstartblock_int_clk &&
       !sdown_phy_mac_rxdatavalid_int_clk_r)                           output_en <= #TP 1'b1; else
    if (serdes_arch)                                                   output_en <= #TP 1'b1; else
    if (!lock && !(|int_phy_mac_rxvalid))                              output_en <= #TP 1'b0; else
    if (mac_phy_rate < 2)                                              output_en <= #TP 1'b1; else   
                                                                       output_en <= #TP output_en;
end



reg sdown_serdes_phy_mac_phystatus_int_clk_r;
always @(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
        sdown_serdes_phy_mac_phystatus_int_clk_r <= #TP '0;
    end else begin
        sdown_serdes_phy_mac_phystatus_int_clk_r <= #TP sdown_serdes_phy_mac_phystatus_int_clk;
    end 
end

always @(posedge txclk or negedge pipe_rst_n or mac_phy_powerdown)
begin
    if (!pipe_rst_n)    P1X_to_P1_transition <= #TP 1'b0; else
    if (current_powerdown_int_clk inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2} && mac_phy_powerdown == `GPHY_PDOWN_P1 )
                        P1X_to_P1_transition <= #TP 1'b1; else
    if (phy_mac_phystatus_negedge && !serdes_arch)
                        P1X_to_P1_transition <= #TP 1'b0; 
    else if (!sdown_serdes_phy_mac_phystatus_int_clk && sdown_serdes_phy_mac_phystatus_int_clk_r  && serdes_arch)
                        P1X_to_P1_transition <= #TP 1'b0; else
                        P1X_to_P1_transition <= #TP P1X_to_P1_transition;
end
// --------------------------------------------------------------------------
// Sinc RX signals on pclk
// --------------------------------------------------------------------------
// no serdes arch we move to pclk
// serdes acrh we move also to pclk 
always @(posedge pclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
         sdown_phy_mac_phystatus_pclk    <= #TP 1'b1;
         sdown_phy_mac_phystatus_pclk_d  <= #TP 1'b1;         
         sdown_phy_mac_rxstatus_pclk     <= #TP 3'b000;
         sdown_phy_mac_rxstatus_pclk_d   <= #TP 3'b000;
         sdown_phy_mac_pclkchangeok      <= #TP 1'b0;
    end else if (!output_en && !rate_changed
                && !(lock & sdown_phy_mac_rxstartblock_int_clk & !sdown_phy_mac_rxdatavalid_int_clk_r)
            ) begin
            if ((!(mac_phy_powerdown inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2, `GPHY_PDOWN_P1_CPM}))
                  || pclk_mode_input)
            begin
              sdown_phy_mac_phystatus_pclk    <= #TP serdes_arch ? sdown_serdes_phy_mac_phystatus_int_clk : sdown_phy_mac_phystatus_int_clk;
              sdown_phy_mac_phystatus_pclk_d  <= #TP sdown_phy_mac_phystatus_pclk;
            end            
            sdown_phy_mac_rxstatus_pclk     <= #TP serdes_arch ? sdown_serdes_phy_mac_rxstatus_int_clk : 3'b000;
            sdown_phy_mac_rxstatus_pclk_d   <= #TP serdes_arch ? sdown_phy_mac_rxstatus_pclk : 3'b000;   
            if (!sdown_phy_mac_pclkchangeok) 
             sdown_phy_mac_pclkchangeok  <= #TP phy_mac_pclkchangeok;
            else if (sdown_phy_mac_pclkchangeok && sdown_phy_mac_phystatus) 
             sdown_phy_mac_pclkchangeok  <= #TP phy_mac_pclkchangeok;
            else
             sdown_phy_mac_pclkchangeok  <= #TP sdown_phy_mac_pclkchangeok;              
    end else begin
         if ((!(mac_phy_powerdown inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2, `GPHY_PDOWN_P1_CPM}))
             || pclk_mode_input)
         begin
            sdown_phy_mac_phystatus_pclk    <= #TP serdes_arch ? sdown_serdes_phy_mac_phystatus_int_clk : sdown_phy_mac_phystatus_int_clk;
            sdown_phy_mac_phystatus_pclk_d  <= #TP sdown_phy_mac_phystatus_pclk;
         end            
         sdown_phy_mac_rxstatus_pclk     <= #TP serdes_arch ? sdown_serdes_phy_mac_rxstatus_int_clk : sdown_phy_mac_rxstatus_int_clk;  
         sdown_phy_mac_rxstatus_pclk_d   <= #TP sdown_phy_mac_rxstatus_pclk;   
         if (!sdown_phy_mac_pclkchangeok) 
             sdown_phy_mac_pclkchangeok  <= #TP phy_mac_pclkchangeok;
         else if (sdown_phy_mac_pclkchangeok && sdown_phy_mac_phystatus) 
             sdown_phy_mac_pclkchangeok  <= #TP phy_mac_pclkchangeok;
         else
             sdown_phy_mac_pclkchangeok  <= #TP sdown_phy_mac_pclkchangeok;               
    end     
end


// no serdes arch we move to pclk
// serdes acrh we move to recvdclk_pipe 
always @(posedge mux_pclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin  
         sdown_phy_mac_rxdata_pclk       <= #TP '0;
         sdown_phy_mac_rxdatak_pclk      <= #TP '0;
         sdown_phy_mac_rxvalid_pclk      <= #TP '0;
         sdown_phy_mac_rxdatavalid_pclk  <= #TP 1'b0;         
    end else if (!output_en && !rate_changed 
                && !(lock & sdown_phy_mac_rxstartblock_int_clk & !sdown_phy_mac_rxdatavalid_int_clk_r)
            ) begin    
            sdown_phy_mac_rxdata_pclk       <= #TP '0;
            sdown_phy_mac_rxdatak_pclk      <= #TP '0;
            sdown_phy_mac_rxvalid_pclk      <= #TP '0;
            sdown_phy_mac_rxdatavalid_pclk  <= #TP 1'b0;
    end else begin              
         sdown_phy_mac_rxdata_pclk       <= #TP sdown_phy_mac_rxdata_int_clk;     
         sdown_phy_mac_rxdatak_pclk      <= #TP sdown_phy_mac_rxdatak_int_clk;    
        // sdown_phy_mac_rxvalid_pclk      <= #TP sdown_phy_mac_rxvalid_int_clk;    
         sdown_phy_mac_rxdatavalid_pclk  <= #TP sdown_phy_mac_rxdatavalid_int_clk_mux; 
         
         if (rx_pace_value > 0 && pace_rxdatavalid && !sdown_phy_mac_rxvalid_pclk)               
            sdown_phy_mac_rxvalid_pclk  <= #TP sdown_phy_mac_rxvalid_int_clk;
         else if (rx_pace_value == 0)   
            sdown_phy_mac_rxvalid_pclk  <= #TP sdown_phy_mac_rxvalid_int_clk;
         else if (sdown_phy_mac_rxvalid_pclk)
            sdown_phy_mac_rxvalid_pclk  <= #TP sdown_phy_mac_rxvalid_int_clk;
                   
    end     
end



initial
begin
   sdown_phy_mac_rxstartblock_pclk = 1'b0;
   sdown_phy_mac_rxsynchdr_pclk    = 2'b00;
end

always @(posedge mux_pclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       sdown_phy_mac_rxstartblock_pclk  <= #TP '0;
       sdown_phy_mac_rxsynchdr_pclk     <= #TP '0;
    end else if (!output_en && !rate_changed
                && !(lock & sdown_phy_mac_rxstartblock_int_clk & !sdown_phy_mac_rxdatavalid_int_clk_r)
            ) begin
            sdown_phy_mac_rxstartblock_pclk  <= #TP '0;
            sdown_phy_mac_rxsynchdr_pclk     <= #TP '0;
    end else begin
       if (sdown_phy_mac_rxdatavalid_int_clk_mux)
          sdown_phy_mac_rxstartblock_pclk  <= #TP sdown_phy_mac_rxstartblock_int_clk; 
       else 
          sdown_phy_mac_rxstartblock_pclk  <= #TP '0;   
          
       sdown_phy_mac_rxsynchdr_pclk     <= #TP sdown_phy_mac_rxsynchdr_int_clk;
    end
end

initial
begin
    sdown_phy_mac_ebuf_location_pclk = 8'h00;
end
always @(posedge mux_pclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       sdown_phy_mac_ebuf_location_pclk <= #TP 8'h00;
    end else begin
       sdown_phy_mac_ebuf_location_pclk <= #TP sdown_phy_mac_ebuf_location_int_clk;
    end
end


// generate a pulse on phystatus and rxstatus
wire         sdown_phy_mac_phystatus_pclk_pulse;
wire  [2:0]  sdown_phy_mac_rxstatus_pclk_pulse;

assign sdown_phy_mac_phystatus_pclk_pulse = sdown_phy_mac_phystatus_pclk && !sdown_phy_mac_phystatus_pclk_d;
assign sdown_phy_mac_rxstatus_pclk_pulse  = (sdown_phy_mac_rxstatus_pclk != sdown_phy_mac_rxstatus_pclk_d) ? sdown_phy_mac_rxstatus_pclk : 3'b000;

// --------------------------------------------------------------------------
// RX output signals to CORE
// --------------------------------------------------------------------------
// this are the outputs
assign sdown_phy_mac_rxdata        = sdown_phy_mac_rxdata_pclk[(PIPE_NB*PIPE_DATA_WD)-1:0];
assign sdown_phy_mac_rxdatak       = sdown_phy_mac_rxdatak_pclk[PIPE_NB-1:0];
assign sdown_phy_mac_rxdatavalid   = sdown_phy_mac_rxdatavalid_pclk;
assign sdown_phy_mac_rxvalid       = sdown_phy_mac_rxvalid_pclk; //serdes_arch ? phy_mac_rxvalid : sdown_phy_mac_rxvalid_pclk;
assign sdown_phy_mac_rxstatus      = ((rx_pace_value == 0 || serdes_arch)&& (sdown_phy_mac_rxstatus_pclk  inside {3'b011}))  ? sdown_phy_mac_rxstatus_pclk_pulse :
                                     (rx_pace_value == 0 && !(sdown_phy_mac_rxstatus_pclk inside {3'b011}))  ? sdown_phy_mac_rxstatus_pclk       :
                                     (rx_pace_value >= 1 && (sdown_phy_mac_rxstatus_pclk  inside { 3'b011}))                 ? sdown_phy_mac_rxstatus_pclk & {3{pace_rxdatavalid_r}} :
                                     (rx_pace_value >= 1 && (sdown_phy_mac_rxstatus_pclk  inside {3'b001, 3'b010}))          ? sdown_phy_mac_rxstatus_pclk & {3{sdown_phy_mac_rxdatavalid_pclk}} :
                                                                                                                               sdown_phy_mac_rxstatus_pclk & {3{sdown_phy_mac_rxdatavalid_pclk}};

// if in P2, P1.1, P1.2 or P1.CPM entry, phystatus is async
// if in reset phystatus is async
// in receiver detection phystatus and rx_status need to be aligned
// in any other scenario phystauts is a pulse on pclk
assign sdown_phy_mac_phystatus     = (((mac_phy_powerdown inside {`GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON, `GPHY_PDOWN_P1_CPM} && !pclk_mode_input)
                                   || (current_powerdown inside {`GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON} && !pclk_mode_input)
                                   || (mac_phy_powerdown inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2} && (!pclk_mode_input || `GPHY_PDOWN_P1_CPM != `GPHY_PDOWN_P1_1))
                                   || ((randomize_P1X_to_P1 || P1X_to_P1_exit_mode) && P1X_to_P1_transition && !pclk_mode_input)))
                                                                                                      ? phy_mac_phystatus               :
                                     (in_rst )                                                        ? sdown_phy_mac_phystatus_pclk    :
                                     (receiver_present)                                               ? sdown_phy_mac_phystatus_pclk & (sdown_phy_mac_rxstatus == 3'b011 )
                                                                                                      : sdown_phy_mac_phystatus_pclk_pulse;


assign sdown_phy_mac_rxstartblock  = sdown_phy_mac_rxstartblock_pclk;
assign sdown_phy_mac_rxsynchdr     = sdown_phy_mac_rxsynchdr_pclk;
assign sdown_phy_mac_ebuf_location = sdown_phy_mac_ebuf_location_pclk;

// -------------------------------------------------------------------------------------------------------
// TX path
// SUP Side - mac_phy
// -------------------------------------------------------------------------------------------------------
reg                         aligned;
reg     [MAX_NB-1:0]        sup_src_byte_enable;
wire                        sup_dst_byte_enable;

reg                         en_mac_phy_txdetectrx_loopback;
wire                        early_clr_sup_mac_phy_txdetectrx_loopback;

reg    [(MAX_NB*PIPE_DATA_WD)-1:0]     wide_mac_phy_txdata;
reg    [ MAX_NB-1:0]                   wide_mac_phy_txdatak;
reg    [(MAX_NB*PIPE_DATA_WD)-1:0]     wide_sup_mac_phy_txdata;
reg    [ MAX_NB-1:0]                   wide_sup_mac_phy_txdatak;
reg                                    wide_sup_mac_phy_txelecidle;
reg                                    wide_sup_mac_phy_txdetectrx_loopback;
reg                                    mac_phy_txstartblock_r;
reg                                    sup_mac_phy_pipe_txdatavalid;

wire   [ MAX_NB*TXEI_WD-1:0]           extended_mac_phy_txelecidle;
wire   [ MAX_NB*TXEI_WD-1:0]           mux_extended_mac_phy_txelecidle;
reg    [ MAX_NB*TXEI_WD-1:0]           sync_extended_mac_phy_txelecidle;

reg   [ TXEI_WD-1:0]                  mac_phy_txelecidle_d;


// output signals
assign sup_mac_phy_txdata              = wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0];
assign sup_mac_phy_txdatak             = wide_sup_mac_phy_txdatak;
assign sup_mac_phy_txelecidle          = wide_sup_mac_phy_txelecidle;
assign sup_mac_phy_txdetectrx_loopback = wide_sup_mac_phy_txdetectrx_loopback;

assign extended_mac_phy_txelecidle = {{((MAX_NB-PIPE_NB)*TXEI_WD){1'b0}},mac_phy_txelecidle};

reg    [(MAX_NB*PIPE_DATA_WD)-1:0]     wide_pre_mac_phy_txdata;
reg    [ MAX_NB-1:0]                   wide_pre_mac_phy_txdatak;
reg                                    pre_mac_phy_txstartblock;
reg    [1:0]                           pre_mac_phy_txsynchdr;
reg                                    pre_mac_phy_txdatavalid;
reg                                    pre_mac_phy_txcompliance;




integer tx_pipe_nr_startbl;
assign tx_pipe_nr_startbl = (mac_phy_width == 0) ? 4 :
                            (mac_phy_width == 1) ? 8 :
                            (mac_phy_width == 2) ? 16 :
                            (mac_phy_width == 3) ? 32 : 32;   
                            
integer max_tx_pipe_byte_dec;                            
assign max_tx_pipe_byte_dec = (mac_phy_width == 0) ? 'h0001 :
                              (mac_phy_width == 1) ? 'h0002 :
                              (mac_phy_width == 2) ? 'h0008 :
                              (mac_phy_width == 3) ? 'h0080 : 'h8000;
 

reg [7:0] tx_pace_cnt;
reg pace_txdatavalid;
always@(posedge pclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       tx_pace_cnt      <= #TP '0; 
       pace_txdatavalid <= #TP '0;   
    end else begin
       if (tx_pace_value > 0) begin
          if (mac_phy_rate < 2) begin
            tx_pace_cnt      <= #TP '0; 
            pace_txdatavalid <= #TP 1;        
          end else if ((tx_pace_cnt == tx_pipe_nr_startbl * (16 / pipe_nr_sym)) || (&mac_phy_txelecidle)) begin
           // PACING at GEN3
            tx_pace_cnt      <= #TP '0;
            pace_txdatavalid <= #TP 0;
          end else if (mac_phy_txdatavalid && !(&mac_phy_txelecidle)) begin
             tx_pace_cnt <= #TP tx_pace_cnt + 1;
             pace_txdatavalid <= #TP 1;
          end else begin
             tx_pace_cnt      <= #TP tx_pace_cnt;
             pace_txdatavalid <= #TP pace_txdatavalid;                 
          end 
           
       end else begin
       // no pacing
          tx_pace_cnt      <= #TP '0; 
          pace_txdatavalid <= #TP 1; 
       end 
        
   end    
end


always@(posedge pclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
      wide_pre_mac_phy_txdata   <= #TP '0;
      wide_pre_mac_phy_txdatak  <= #TP '0;
      pre_mac_phy_txstartblock  <= #TP '0;
      pre_mac_phy_txsynchdr     <= #TP '0;
      pre_mac_phy_txdatavalid   <= #TP '0; 
      pre_mac_phy_txcompliance  <= #TP '0;
      mac_phy_txelecidle_d      <= #TP {(TXEI_WD){1'b1}};
      sync_extended_mac_phy_txelecidle <= #TP {{((MAX_NB-PIPE_NB)*TXEI_WD){1'b0}},{(TXEI_WD){1'b1}}};
    end else begin
     if ((tx_pace_value > 0 && mac_phy_txdatavalid) || (!pace_txdatavalid && sup_src_byte_enable == max_tx_pipe_byte_dec)) begin
       wide_pre_mac_phy_txdata   <= #TP wide_mac_phy_txdata;
       wide_pre_mac_phy_txdatak  <= #TP wide_mac_phy_txdatak;
       pre_mac_phy_txstartblock  <= #TP mac_phy_txstartblock;
       pre_mac_phy_txsynchdr     <= #TP mac_phy_txsynchdr;
     end else if (tx_pace_value == 0) begin
       wide_pre_mac_phy_txdata   <= #TP wide_mac_phy_txdata;
       wide_pre_mac_phy_txdatak  <= #TP wide_mac_phy_txdatak;
       pre_mac_phy_txstartblock  <= #TP mac_phy_txstartblock;
       pre_mac_phy_txsynchdr     <= #TP mac_phy_txsynchdr;
     end 
       
       pre_mac_phy_txdatavalid   <= #TP mac_phy_txdatavalid; 
       pre_mac_phy_txcompliance  <= #TP mac_phy_txcompliance;
       mac_phy_txelecidle_d      <= #TP mac_phy_txelecidle; 

       if (!(&mac_phy_txelecidle))
          sync_extended_mac_phy_txelecidle <= #TP {{((MAX_NB-PIPE_NB)*TXEI_WD){1'b0}},mac_phy_txelecidle};
       else if (&mac_phy_txelecidle && ( (tx_pace_value > 0 && sup_src_byte_enable == max_tx_pipe_byte_dec) || tx_pace_value == 0 )) 
          sync_extended_mac_phy_txelecidle <= #TP {{((MAX_NB-PIPE_NB)*TXEI_WD){1'b0}},mac_phy_txelecidle};

    end
end

assign mux_extended_mac_phy_txelecidle = (((current_powerdown inside {`GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON}) && !lane_disabled) ||
                                          ((mac_phy_powerdown inside {`GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON}) && lane_disabled))  ? extended_mac_phy_txelecidle : sync_extended_mac_phy_txelecidle;



// extend inputs to maximum number of bytes
always_comb
begin
   // Assign values if tx_datavalid
   wide_mac_phy_txdata  = {{((MAX_NB-PIPE_NB)*PIPE_DATA_WD){1'b0}},mac_phy_txdata};
   wide_mac_phy_txdatak = {{(MAX_NB-PIPE_NB){1'b0}},mac_phy_txdatak};
end

always @(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
        sup_smlh_blockaligncontrol  <= #TP 0;
    end else if (sup_mac_phy_pipe_txdatavalid) begin
        sup_smlh_blockaligncontrol  <= #TP smlh_blockaligncontrol;
    end
end

wire   control_word;

assign control_word = serdes_arch ? 1:
                     (mac_phy_rate > 1) ? (mac_phy_txstartblock && mac_phy_txsynchdr) : wide_mac_phy_txdatak[0];


always@(posedge pclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       aligned <= #TP 0;
    end else if (( serdes_arch && (&mac_phy_txelecidle_d) && (&mac_phy_txelecidle) && ((tx_pace_value > 0 && sup_src_byte_enable == max_tx_pipe_byte_dec) || tx_pace_value == 0 )) ||
                 (!serdes_arch && mac_phy_txelecidle_d[0] && mac_phy_txelecidle[0] && ((tx_pace_value > 0 && sup_src_byte_enable == max_tx_pipe_byte_dec) || tx_pace_value == 0 ))) 
    begin
       aligned <= #TP 0;
    end else if (( serdes_arch && !(|mac_phy_txelecidle) && control_word && mac_phy_txdatavalid) ||
                 (!serdes_arch && !mac_phy_txelecidle[0] && control_word && mac_phy_txdatavalid))
    begin
       aligned <= #TP 1;
    end
end


// Create te symbol counter so we can switch from Ns to 1s domain
// dst_byte is alwasy 1s
// src_byte is Ns (eg. 1s, 2s, 4s, 8s)
assign sup_dst_byte_enable = 1'b1;

always@(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
      sup_src_byte_enable <= #TP 1;
    end else if (aligned  & sup_mac_phy_pipe_txdatavalid) 
    begin
        if (step_down_1s_1s_en)       sup_src_byte_enable  <= #TP 1;
        else if (step_down_1s_2s_en)  sup_src_byte_enable  <= #TP {sup_src_byte_enable[0],sup_src_byte_enable[1]};
        else if (step_down_1s_4s_en)  sup_src_byte_enable  <= #TP {sup_src_byte_enable[2:0],sup_src_byte_enable[3]};
        else if (step_down_1s_8s_en)  sup_src_byte_enable  <= #TP {sup_src_byte_enable[6:0],sup_src_byte_enable[7]};
        else if (step_down_1s_16s_en) sup_src_byte_enable  <= #TP {sup_src_byte_enable[14:0],sup_src_byte_enable[15]};
    end else if (!aligned) begin
      sup_src_byte_enable   <= #TP 1;
    end
end

// when both mac_phy_txelecidle & mac_phy_txcompliance are asserted then that is a
// signal to the PHY to powerdown that specific lane.  mac_phy_txcompliance is also
// used to reset the disparity for the compliance pattern, so on the second symbol
// don't set mac_phy_txcompliance unless mac_phy_txelecidle is also set.
always@(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       wide_sup_mac_phy_txdata              <= #TP 0;
       wide_sup_mac_phy_txdatak             <= #TP 0;
       wide_sup_mac_phy_txelecidle          <= #TP 1;
       sup_mac_phy_txstartblock             <= #TP 0;
       sup_mac_phy_txsynchdr                <= #TP 0;
       sup_mac_phy_txdatavalid              <= #TP 0;
    end else if (sup_mac_phy_pipe_txdatavalid) begin
       wide_sup_mac_phy_txdata              <= #TP 0;
       wide_sup_mac_phy_txdatak             <= #TP 0;
       if (sup_dst_byte_enable) begin

           if (sup_src_byte_enable[0]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD-1:0];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[0];
             sup_mac_phy_txstartblock       <= #TP pre_mac_phy_txstartblock;
             sup_mac_phy_txsynchdr          <= #TP pre_mac_phy_txsynchdr;
             wide_sup_mac_phy_txelecidle      <= #TP  serdes_arch ? mux_extended_mac_phy_txelecidle[0] : mux_extended_mac_phy_txelecidle[0];
             sup_mac_phy_txdatavalid <= #TP (tx_pace_value > 0) ? pace_txdatavalid : pre_mac_phy_txdatavalid ;
           end else
           if (sup_src_byte_enable[1]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*2-1:PIPE_DATA_WD*1];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[1];
             sup_mac_phy_txstartblock       <= #TP 0;
              wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[0] : mux_extended_mac_phy_txelecidle[0];
             //sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end else
           if (sup_src_byte_enable[2]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*3-1:PIPE_DATA_WD*2];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[2];
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[1] : mux_extended_mac_phy_txelecidle[0];
            // sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end else
           if (sup_src_byte_enable[3]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*4-1:PIPE_DATA_WD*3];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[3];
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[1] : mux_extended_mac_phy_txelecidle[0];
             //sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end else
           if (sup_src_byte_enable[4]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*5-1:PIPE_DATA_WD*4];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[4];
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[2] : mux_extended_mac_phy_txelecidle[0];
            // sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr[3:2];

           end else
           if (sup_src_byte_enable[5]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*6-1:PIPE_DATA_WD*5];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[5]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[2] : mux_extended_mac_phy_txelecidle[0];
            // sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end else
           if (sup_src_byte_enable[6]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*7-1:PIPE_DATA_WD*6];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[6]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[3] : mux_extended_mac_phy_txelecidle[0];
            // sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end else
           if (sup_src_byte_enable[7]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*8-1:PIPE_DATA_WD*7];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[7]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[3] : mux_extended_mac_phy_txelecidle[0];
            // sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end
           if (sup_src_byte_enable[8]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*9-1:PIPE_DATA_WD*8];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[8]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[4] : mux_extended_mac_phy_txelecidle[0];
            // sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr[5:4];
           end
           if (sup_src_byte_enable[9]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*10-1:PIPE_DATA_WD*9];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[9]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[4] : mux_extended_mac_phy_txelecidle[0];
            // sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end
           if (sup_src_byte_enable[10]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*11-1:PIPE_DATA_WD*10];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[10]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[5] : mux_extended_mac_phy_txelecidle[0];
            // sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end
           if (sup_src_byte_enable[11]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*12-1:PIPE_DATA_WD*11];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[11]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[5] : mux_extended_mac_phy_txelecidle[0];
             //sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end
           if (sup_src_byte_enable[12]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*13-1:PIPE_DATA_WD*12];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[12]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[6] : mux_extended_mac_phy_txelecidle[0];
             //sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr[7:6];
           end
           if (sup_src_byte_enable[13]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*14-1:PIPE_DATA_WD*13];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[13]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[6] : mux_extended_mac_phy_txelecidle[0];
             //sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end
           if (sup_src_byte_enable[14]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*15-1:PIPE_DATA_WD*14];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[14]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[7] : mux_extended_mac_phy_txelecidle[0];
             //sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end
           if (sup_src_byte_enable[15]) begin
             wide_sup_mac_phy_txdata[PIPE_DATA_WD-1:0]   <= #TP wide_pre_mac_phy_txdata[PIPE_DATA_WD*16-1:PIPE_DATA_WD*15];
             wide_sup_mac_phy_txdatak[0]    <= #TP wide_pre_mac_phy_txdatak[15]   ;
             sup_mac_phy_txstartblock       <= #TP 0;
             wide_sup_mac_phy_txelecidle      <= #TP serdes_arch ? mux_extended_mac_phy_txelecidle[7] : mux_extended_mac_phy_txelecidle[0];
            // sup_mac_phy_txsynchdr          <= #TP mac_phy_txsynchdr;
           end
       end
   end
end

always@(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
        sup_mac_phy_pipe_txdatavalid <= #TP 0;
    end else begin
        sup_mac_phy_pipe_txdatavalid <= #TP 1;
    end
end

always @(posedge txclk or phy_rst_n)
begin
    if (!pipe_rst_n) begin
        sup_mac_phy_rate                    <= #TP 0;
        sup_mac_phy_rxpolarity              <= #TP 0;
        sup_mac_phy_width                   <= #TP '0;
        sup_mac_phy_pclk_rate               <= #TP mac_phy_pclk_rate;
        sup_mac_phy_txdeemph                <= #TP 1'b1;
        sup_mac_phy_txmargin                <= #TP 0;
        sup_mac_phy_txswing                 <= #TP 0;
        sup_rxwidth                         <= #TP '0;
    end else  begin
        sup_mac_phy_rate                    <= #TP mac_phy_rate;
        sup_mac_phy_rxpolarity              <= #TP mac_phy_rxpolarity;
        sup_mac_phy_width                   <= #TP mac_phy_width;
        sup_mac_phy_pclk_rate               <= #TP mac_phy_pclk_rate;
        sup_mac_phy_txdeemph                <= #TP mac_phy_txdeemph;
        sup_mac_phy_txmargin                <= #TP mac_phy_txmargin;
        sup_mac_phy_txswing                 <= #TP mac_phy_txswing;
        sup_rxwidth                         <= #TP rxwidth;
    end
end

reg     [1:0]                 sup_cnt;
always @(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
       sup_cnt <= #TP 0;
    end else if ((aligned | (!mac_phy_txelecidle && wide_mac_phy_txdatak[0])) & sup_mac_phy_pipe_txdatavalid) begin
       sup_cnt <= #TP ((step_down_1s_1s_en ))                 ? 0 :
                      ((step_down_1s_2s_en ) && (sup_cnt==1)) ? 0 : sup_cnt + 1;
    end else if (~aligned) begin
       sup_cnt <= #TP 0;
    end
end

always @(posedge txclk or negedge pipe_rst_n)
begin
    if (!pipe_rst_n) begin
        sup_mac_phy_txcompliance              <= #TP 0;
    end else if (((sup_cnt==0) | (pre_mac_phy_txcompliance & |mac_phy_txelecidle)) & sup_mac_phy_pipe_txdatavalid) begin
        sup_mac_phy_txcompliance              <= #TP pre_mac_phy_txcompliance;
    end else if (aligned & sup_mac_phy_pipe_txdatavalid) begin
        sup_mac_phy_txcompliance              <= #TP 0;
    end
end

assign early_clr_sup_mac_phy_txdetectrx_loopback =
             sup_mac_phy_txdetectrx_loopback & phy_mac_phystatus
                                                 & ( (mac_phy_powerdown==`GPHY_PDOWN_P1)
                                                    |(mac_phy_powerdown==`GPHY_PDOWN_P2)) ;

always @(posedge txclk or negedge pipe_rst_n)
    if (!pipe_rst_n)
        en_mac_phy_txdetectrx_loopback <= #TP 1'b1;
    else if (early_clr_sup_mac_phy_txdetectrx_loopback)
        en_mac_phy_txdetectrx_loopback <= #TP 1'b0;
    else if (~mac_phy_txdetectrx_loopback)
        en_mac_phy_txdetectrx_loopback <= #TP 1'b1;

always @(posedge txclk or negedge pipe_rst_n)
    if (!pipe_rst_n)
        wide_sup_mac_phy_txdetectrx_loopback <= #TP 1'b0;
    else if (early_clr_sup_mac_phy_txdetectrx_loopback)
        wide_sup_mac_phy_txdetectrx_loopback <= #TP 1'b0;
    else if (en_mac_phy_txdetectrx_loopback & sup_mac_phy_pipe_txdatavalid & sup_dst_byte_enable)
        wide_sup_mac_phy_txdetectrx_loopback <= #TP mac_phy_txdetectrx_loopback;

//
// Code to implement the following priority from the PIPE spec
//
// There are four error conditions that can be encoded on the RxStatus signals.
// If more than one error should happen to occur on a received byte (or set of
// bytes transferred across a 16-bit interface), the errors should be signaled
// with the priority shown below.
// 1.   8B/10B decode error
// 2.   Elastic buffer overflow
// 3.   Elastic buffer underflow
// 4.   Disparity error
//
// If an error occurs during a SKP ordered-set, such that the error signaling
// and SKP added/removed signaling on RxStatus would occur on the same CLK,
// then the error signaling has precedence.

function  [2:0] error_priority;
    input [2:0] rxstatus;
    input  detection_window;
    input [MAX_NB-1:0] phystatus;

    if (detection_window && |phystatus) begin
       case (rxstatus)
           3'b011 : error_priority = 3'd7; // Receiver Detected
           3'b000 : error_priority = 3'd6; // Receiver absent
           3'b100 : error_priority = 3'd5; // Code Error
           3'b101 : error_priority = 3'd4; // Elastic Buffer Overflow
           3'b110 : error_priority = 3'd3; // Elastic Buffer Underflow
           3'b111 : error_priority = 3'd2; // Disparity Error
           3'b001 : error_priority = 3'd1; // Skip Added
           3'b010 : error_priority = 3'd0; // Skip Removed
           default: error_priority = 3'd0; // Other
       endcase
    end else begin
       case (rxstatus)
           3'b011 : error_priority = 3'd7; // Receiver Detected
           3'b100 : error_priority = 3'd6; // Code Error
           3'b101 : error_priority = 3'd5; // Elastic Buffer Overflow
           3'b110 : error_priority = 3'd4; // Elastic Buffer Underflow
           3'b111 : error_priority = 3'd3; // Disparity Error
           3'b001 : error_priority = 3'd2; // Skip Added
           3'b010 : error_priority = 3'd1; // Skip Removed
           default: error_priority = 3'd0; // Other
       endcase
    end
endfunction
endmodule
