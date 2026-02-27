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
// ---  $DateTime: 2020/10/14 01:40:47 $
// ---  $Revision: #33 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pll.v#33 $
// -------------------------------------------------------------------------
// --- Module Description: generate txclk and pclk
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_pll #(
    parameter TP = 0.25,
    parameter NL = 1
) (
  input  [NL-1 : 0]       i_pclk,           // pclk as input
  input                   refclk,           // reference clock input
  input                   rst_n,            // serdes reset input
  input  [2 : 0]          rate,             // selected data rate
  input  [3 : 0]          pclk_rate,        // encoded pclk rate
  input  [NL-1 : 0]       pclk_off_req,     // request to turn-off pclk in a PM state from all lanes
  input  [NL-1 : 0]       rate_change_req,  // request to turn-off pclk in a rate change from all lanes
  input                   pclkack_off_time_load_en,
  input  [30:0]           pclkack_off_time,
  input                   pclkack_on_time_load_en,
  input  [30:0]           pclkack_on_time,
  input  [NL-1:0]         mac_phy_pclkchangeack,
  input  [NL-1:0]         phy_mac_pclkchangeok,
  `ifdef GPHY_ESM_SUPPORT
  input                    calibration_complete_en,
  input                   random_calibrt_complete_en,      // Enable/disable random delay when generationg calibrt_complete
  input   [7:0]           fixed_calibrt_complete_thr,      // Fixed delay when generationg calibrt_complete
  input                   esm_calibrt_req,
  input                   esm_enable,
  input [6:0]             esm_reg_data_rate0,
  input [6:0]             esm_reg_data_rate1,
  input                   pipe_command_ack,
  output                  esm_calibrt_complete_pulse,
  `endif // GPHY_ESM_SUPPORT
  
   // PCLK as PHY input
  input                   pclk_mode_input,
  input                   maxpclkreq_n,
  output reg              maxpclkack_n, 

  output                  txbitclk,         // Tx Bit clk
  output reg              pclk_off_ack,     // confirmation pclk was removed
  output                  txclk,            // Transmit symbol clock
  output                  txclk_ug,
  output                  pclk,             // Pipe clock
  output                  pclkx2,           // Pipe clock x2
  output                  max_pclk,
  output reg              ready,            // PLL is on
  output reg [NL-1 : 0]   lock_out              // PLL is locked
);

timeunit 1fs;
timeprecision 1fs;

localparam TP_FS = TP*1_000_000;

// internal used delays 
integer PCLK_OFF_RATE_DLY = 80;             // time that pclk will be off at rate change
integer LOCK_RET_DLY = 5;                   // time for lock to be returned ofter pclk in on

integer PCLKACK_MIN_DELAY_OFF = 95;
integer PCLKACK_MAX_DELAY_OFF = 95;

integer PCLKACK_MIN_DELAY_ON = 0;
integer PCLKACK_MAX_DELAY_ON = 128;

// pclk as input timing values for maxpclk turn on and ack drive
integer MAXPCLK_START_DELAY_MIN = 1;
integer MAXPCLK_START_DELAY_MAX = 4;

integer MAXPCLKACK_ASSERT_DELAY_MIN = 1;
integer MAXPCLKACK_ASSERT_DELAY_MAX = 40;
integer MEDIUM_PCLKACK_ASSERT_DELAY_MAX  = 20;




wire [NL-1 : 0] pclk_off_powerstate;
wire [NL-1 : 0] pclk_off_rate;

assign pclk_off_powerstate = pclk_off_req;    // lane either has req either is disabled
assign pclk_off_rate       = rate_change_req; // lane either has req either is disabled

reg lock;
reg [NL-1 : 0] lock_pclk_in;

//TODO lock when pclk as input: maybe turn off when maxpclk is off (!maxpclkack_n ????)
assign  lock_out = pclk_mode_input ? lock_pclk_in :  {NL{lock}};

wire             rate_change_off;
wire             pclk_enable_rise;

reg pclk_enable;      initial pclk_enable    = 1'b0;
reg pclk_enable_r;    initial pclk_enable_r  = 1'b0;
reg txclk_enable;     initial txclk_enable   = 1'b0;
reg txserclk_lock; 

reg refclk_running;   initial refclk_running   = 1'b0;

// internal generate clk
reg internal_txser_clk;
reg internal_txclk;
reg internal_pclk;
reg internal_pclkx2;
reg internal_clk_4000;
reg internal_clk_2000;
reg internal_clk_1000;
reg internal_clk_500;
reg internal_clk_250;
reg internal_clk_125;
reg internal_clk_62_5;
wire internal_max_pclk;
reg internal_max_pclk_mode2;
reg internal_max_pclk_mode3;

realtime refclk_period;
realtime refclk_period_r;
realtime refclk_time1;
realtime refclk_time2;

reg [NL-1:0] sync_txclk_done_d;
reg [NL-1:0] sync_txclk_done_dd;
reg [NL-1:0] sync_txclk_done_ddd;
// reg [NL-1:0] sync_txclk_done_rise_edge;
// reg [NL-1:0] pclk_off_rate_dd;
// reg [NL-1:0] pclk_off_rate_ddd;

reg [NL-1:0] rate_change_off_d, rate_change_off_dd;
reg en_max_pclk_mode2_latch;
reg en_max_pclk_mode3_latch;
reg en_max_pclk_latch;

initial begin
  refclk_time1   <= 10_000_000;
  refclk_time2   <= 0;
  refclk_period  <= 10_000_000;
end

// rate/pclk rate related signals
real pclk_period_decode;
real rate_period_dec;

//real local_serclk_2000_period_final;
real local_serclk_4000_period_final;
real local_txser_clk_period_int1;
real local_txser_clk_period_int2;
real local_txser_clk_period_int3;
real local_txser_clk_period_int4;
real local_txser_clk_period_int5;
real local_txser_clk_period_int6;

// txser_clk period and serclk_2000 perio real values i
real serclk_2000_period; initial serclk_2000_period = 25_000; 
real serclk_4000_period; initial serclk_4000_period = 12_500; 
real txser_clk_period;   initial txser_clk_period   = 400_000;
real txser_clk_period_r; initial txser_clk_period_r = 400_000;

reg [5:0] refclk_running_dly;
// =======================================================================
// Generation of multiplication factors between clk
// Measure the reflck period and we calucate new clk perioads
// ======================================================================
real tx_rate_multiplication_factor;               initial tx_rate_multiplication_factor                = 2.5;
real pclkx2_rate_multiplication_factor_vs_refclk; initial pclkx2_rate_multiplication_factor_vs_refclk  = 2.5;
real tx_rate_vs_clk_2000_multiplication_factor;   initial tx_rate_vs_clk_2000_multiplication_factor    = 8;
real tx_rate_vs_clk_4000_multiplication_factor;   initial tx_rate_vs_clk_4000_multiplication_factor    = 16;
real pclkx2_vs_clk_4000_multiplication_factor;    initial pclkx2_vs_clk_4000_multiplication_factor     = 16;

real instant_txser_clk_multiplication_factor;
real txser_clk_multiplication_factor;             initial  txser_clk_multiplication_factor             = 10;
real pclkx2_multiplication_factor_vs_txser;       initial pclkx2_multiplication_factor_vs_txser        = 20;
real tx_rate_vs_pclkx2_rate_multiplication_factor;initial tx_rate_vs_pclkx2_rate_multiplication_factor = 1;

// final stage sync on slowest clk
real txser_clk_multiplication_factor_final;             initial txser_clk_multiplication_factor_final              = 10;
real pclkx2_multiplication_factor_vs_txser_final;       initial pclkx2_multiplication_factor_vs_txser_final        = 20;
real tx_rate_vs_pclkx2_rate_multiplication_factor_final;initial tx_rate_vs_pclkx2_rate_multiplication_factor_final = 1;
  
integer serclk_4000_period_int; 
// final values that we use
integer txser_clk_period_int;         
integer txser_clk_period_final;        initial txser_clk_period_final        = 400_000;


integer txser_clk_period_standard;
assign txser_clk_period_standard = (pclk_period_decode/2 >= rate_period_dec ) ? (10_000_000 / tx_rate_multiplication_factor) / instant_txser_clk_multiplication_factor :
                                                                                (10_000_000 / pclkx2_rate_multiplication_factor_vs_refclk) / instant_txser_clk_multiplication_factor;
                                                                                
assign instant_txser_clk_multiplication_factor  = (rate > 1 )  ? 8  : 10;                                                                                 
                                                                                
integer serclk_4000_period_final;      initial serclk_4000_period_final      = 12_500;
integer txser_clk_period_final_sync;   initial txser_clk_period_final_sync   = 400_000;
integer serclk_4000_period_final_sync; initial serclk_4000_period_final_sync = 12_500;

integer serclk_2000_period_int;
assign serclk_2000_period_int = serclk_2000_period > 6250 ? serclk_2000_period - 0.5 : serclk_2000_period + 0.5; 

// of the deviation is at the limits we need to be carefull how we round to not exceed the maximum/minimum allowd deviation because of the rounding
// if deviation nis with "+" we need to round down
// if deviation nis with "-" we need to round up
assign serclk_4000_period_int =  serclk_4000_period*txser_clk_multiplication_factor < 125_000 ? serclk_4000_period + 0.5 : serclk_4000_period - 0.5;
assign txser_clk_period_int   =  txser_clk_period < txser_clk_period_standard ? txser_clk_period + 0.5 : txser_clk_period - 0.5;

    
//=================================================================
// Measure refclk perioad and extrract the deviation
//=================================================================
reg [2 : 0] rate_r, rate_rr;
always @(posedge refclk or negedge rst_n)
begin
    if (!rst_n) begin   
       rate_r   <= #TP '0;
       rate_rr  <= #TP '0;           
    end else begin
       rate_r   <= #TP rate;
       rate_rr  <= #TP rate_r;
    end             
end

// measure refclk period
always @(posedge refclk)
begin
    refclk_time1  <= $realtime;
    refclk_time2  <= refclk_time1;
    if (refclk_time1 - refclk_time2 < 10_500_000)
    begin   
       refclk_period       <= refclk_time1 - refclk_time2;
       refclk_period_r     <= #TP_FS refclk_period;
    end
end

// compute clks period
always @(posedge refclk or negedge rst_n)
begin
    if (!rst_n) begin   
       // default value for gen1 at reset
       txserclk_lock        <= #TP 1'b1;
       txser_clk_period     <= #TP 400_000; 
       serclk_2000_period   <= #TP 25_000 ; 
       serclk_4000_period   <= #TP 12_500 ; 
       txser_clk_period_r   <= #TP 400_000;
           
    end 
    // Not support for Refclk Deviation
    else if ( (refclk_period > 9_950_000 ) && (refclk_period < 10_060_000 ) && (!pclk_enable || refclk_period != refclk_period_r || rate_r != rate_rr) && refclk_running_dly[2])  begin
      
      if (pclk_period_decode/2 >= rate_period_dec )
          txser_clk_period     <= #TP (refclk_period / tx_rate_multiplication_factor) / txser_clk_multiplication_factor;
      else
          txser_clk_period     <= #TP (refclk_period / pclkx2_rate_multiplication_factor_vs_refclk) / txser_clk_multiplication_factor;
                 
       serclk_2000_period   <= #TP (refclk_period / 20) / txser_clk_multiplication_factor/2;
       serclk_4000_period   <= #TP (refclk_period / 40) / txser_clk_multiplication_factor/2;
       txser_clk_period_r   <= #TP txser_clk_period;
    end             
end

// calculate multiplication factors
always @(posedge refclk or negedge rst_n)
begin
    if (!rst_n) begin   
       // number of bits on the serial line depending on rate / 1 txclk
       txser_clk_multiplication_factor <= #TP 10;
      
       // multiplication factor between txclk and refclk
       tx_rate_multiplication_factor   <= #TP 10_000_000 / rate_period_dec; 
                   
       pclkx2_vs_clk_4000_multiplication_factor <= #TP (pclk_period_decode/2) / 250_000;

        // multiplication factor between pclkx2 and refclk
       pclkx2_rate_multiplication_factor_vs_refclk <= #TP 10_000_000 / (pclk_period_decode / 2); 
       
       serclk_4000_period_final   <= #TP 125_000; 
            
       txser_clk_period_final     <= #TP 400_000; 
                                                       
        // multiplication factor between tx_Rate and clk 2000
       tx_rate_vs_clk_2000_multiplication_factor <= #TP txser_clk_period/ serclk_2000_period;
       
        // multiplication factor between tx_Rate and clk 2000
       tx_rate_vs_clk_4000_multiplication_factor <= #TP txser_clk_period / serclk_4000_period;
       
          
        //multiplication factor between txclk and pclk if pclk is faster then txclk
       tx_rate_vs_pclkx2_rate_multiplication_factor <= #TP  ((pclk_period_decode/2 >= rate_period_dec) ? 1 : rate_period_dec/ (pclk_period_decode/2));

       // pclk period multiplication factor from txser_clk_period
       pclkx2_multiplication_factor_vs_txser <= #TP  pclk_period_decode / (rate_period_dec / txser_clk_multiplication_factor)*tx_rate_vs_pclkx2_rate_multiplication_factor;
      
       rate_period_dec <= #TP  `ifdef GPHY_ESM_SUPPORT
                         (esm_enable && esm_reg_data_rate0 == `GPHY_ESM_RATE0_8GT   && rate === 2) ? 1_000_000 :
                         (esm_enable && esm_reg_data_rate0 == `GPHY_ESM_RATE0_16GT  && rate === 2) ? 500_000   :
                         (esm_enable && esm_reg_data_rate1 == `GPHY_ESM_RATE1_20GT  && rate === 3) ? 400_000   :
                         (esm_enable && esm_reg_data_rate1 == `GPHY_ESM_RATE1_25GT  && rate === 3) ? 320_000   :
                         `endif //GPHY_ESM_SUPPORT
                         (rate === 5)                                                     ? 125_000    :
                         (rate === 4)                                                     ? 250_000    :
                         (rate === 3)                                                     ? 500_000    :
                         (rate === 2)                                                     ? 1_000_000  :
                         (rate === 1)                                                     ? 2_000_000  : 4_000_000;    



// decode pclk period in fs
       pclk_period_decode <= #TP `ifdef GPHY_ESM_SUPPORT
                                    (pclk_rate === 'h8) ? 1_600_000    :
                                    (pclk_rate === 'h9) ? 1_280_000    :
                                    (pclk_rate === 'hA) ? 800_000      :
                                    (pclk_rate === 'hB) ? 640_000      :
                                    (pclk_rate === 'hC) ? 6_400_000    :
                                    (pclk_rate === 'hD) ? 5_120_000    :
                                    (pclk_rate === 'hE) ? 3_200_000    :
                                    (pclk_rate === 'hF) ? 2_560_000    :
                                    `endif // GPHY_ESM_SUPPORT
                                    (pclk_rate === 5) ? 500_000     :
                                    (pclk_rate === 4) ? 1_000_000   :
                                    (pclk_rate === 3) ? 2_000_000   :
                                    (pclk_rate === 2) ? 4_000_000   :
                                    (pclk_rate === 1) ? 8_000_000   : 16_000_000;



    end else if (!pclk_enable || refclk_period != refclk_period_r || txser_clk_period_r != txser_clk_period) begin
       // txser_clk_multiplication_factor <= #TP (rate > 1 )  ? 8  : 10;
       
       if (!pclk_enable) begin
              // number of bits on the serial line depending on rate / 1 txclk
            txser_clk_multiplication_factor <= #TP (rate > 1 )  ? 8  : 10;

            // multiplication factor between txclk and refclk
            tx_rate_multiplication_factor <= #TP 10_000_000 / rate_period_dec; 

            // multiplication factor between pclk and refclk
            pclkx2_rate_multiplication_factor_vs_refclk <= #TP 10_000_000 / (pclk_period_decode / 2); 


            // multiplication factor between tx_Rate and clk 2000
            tx_rate_vs_clk_2000_multiplication_factor <= #TP txser_clk_period / serclk_2000_period ;


            // multiplication factor between txclk and pclk if pclk is faster then txclk
            tx_rate_vs_pclkx2_rate_multiplication_factor <= #TP  ((pclk_period_decode/2 >= rate_period_dec) ? 1 : rate_period_dec/ (pclk_period_decode/2));

                                                                                              
            // pclk period multiplication factor from txser_clk_period
            pclkx2_multiplication_factor_vs_txser <= #TP  pclk_period_decode / (rate_period_dec / txser_clk_multiplication_factor)*tx_rate_vs_pclkx2_rate_multiplication_factor;
            
            rate_period_dec <= #TP  `ifdef GPHY_ESM_SUPPORT
                         (esm_enable && esm_reg_data_rate0 == `GPHY_ESM_RATE0_8GT   && rate === 2) ? 1_000_000 :
                         (esm_enable && esm_reg_data_rate0 == `GPHY_ESM_RATE0_16GT  && rate === 2) ? 500_000   :
                         (esm_enable && esm_reg_data_rate1 == `GPHY_ESM_RATE1_20GT  && rate === 3) ? 400_000   :
                         (esm_enable && esm_reg_data_rate1 == `GPHY_ESM_RATE1_25GT  && rate === 3) ? 320_000   :
                         `endif //GPHY_ESM_SUPPORT
                         (rate === 4)                                                     ? 250_000    :
                         (rate === 3)                                                     ? 500_000    :
                         (rate === 2)                                                     ? 1_000_000  :
                         (rate === 1)                                                     ? 2_000_000  : 4_000_000;    



           // decode pclk period in fs
           pclk_period_decode <= #TP `ifdef GPHY_ESM_SUPPORT
                                    (pclk_rate === 'h8) ? 1_600_000    :
                                    (pclk_rate === 'h9) ? 1_280_000    :
                                    (pclk_rate === 'hA) ? 800_000      :
                                    (pclk_rate === 'hB) ? 640_000      :
                                    (pclk_rate === 'hC) ? 6_400_000    :
                                    (pclk_rate === 'hD) ? 5_120_000    :
                                    (pclk_rate === 'hE) ? 3_200_000    :
                                    (pclk_rate === 'hF) ? 2_560_000    :
                                    `endif // GPHY_ESM_SUPPORT
                                    (pclk_rate === 5) ? 500_000     :
                                    (pclk_rate === 4) ? 1_000_000   :
                                    (pclk_rate === 3) ? 2_000_000   :
                                    (pclk_rate === 2) ? 4_000_000   :
                                    (pclk_rate === 1) ? 8_000_000   : 16_000_000;

  
       end
     
       txser_clk_period_final <= #TP (tx_rate_vs_clk_2000_multiplication_factor < 1) ? txser_clk_period_int : 
                                     (pclk_period_decode/2 >= rate_period_dec )      ? tx_rate_vs_clk_4000_multiplication_factor*serclk_4000_period_int :
                                                                                        pclkx2_vs_clk_4000_multiplication_factor*serclk_4000_period_int;

       serclk_4000_period_final <= #TP (tx_rate_vs_clk_2000_multiplication_factor >= 1) ? serclk_4000_period_int : 
                                                                                         (serclk_4000_period_int/txser_clk_period_int)*txser_clk_period_final ;
       
       // multiplication factor between tx_Rate and clk 2000
       tx_rate_vs_clk_2000_multiplication_factor <= #TP txser_clk_period / serclk_2000_period ;
       
       tx_rate_vs_clk_4000_multiplication_factor <= #TP txser_clk_period / serclk_4000_period ;
       
       pclkx2_vs_clk_4000_multiplication_factor  <= #TP (pclk_period_decode/2) / 125_000;
       
    
       // multiplication factor between txclk and pclk if pclk is faster then txclk
       tx_rate_vs_pclkx2_rate_multiplication_factor <= #TP  ((pclk_period_decode/2 >= rate_period_dec) ? 1 : rate_period_dec/ (pclk_period_decode/2));


      
    end    
end    


//=================================================================
// when pclk enable goes to 0 we do not lock signals, until we finish all new calculations we use old values
// we need a time of 5 refclk cycles to do all calculation for new freq
// once calculationas are done we can lock on the new values    
//=================================================================
reg       lock_signals;
reg [3:0] lock_signal_time;

always @(posedge refclk or negedge rst_n)
begin
    if (!rst_n) begin   
      lock_signals     <= #TP 0;
      lock_signal_time <= #TP 7;
    end else begin
      if (!pclk_enable) begin
        if (lock_signal_time == 8)
            lock_signals <= #TP 0; 
        if (lock_signal_time > 0)
            lock_signal_time <= #TP lock_signal_time - 1;    
        else if (lock_signal_time == 0 )
           lock_signals <= #TP 1;
      
      end else if (pclk_enable) begin
          lock_signal_time <= #TP 8;
          lock_signals     <= #TP lock_signals; 
      end else begin
          lock_signal_time <= #TP lock_signal_time;
          lock_signals     <= #TP lock_signals; 
      end             
    end
end     
          
//=================================================================      
// the new values to be used in clk generation will change only when all calculation have been done
// and in sync with slowest clk  
//=================================================================
always @(posedge internal_clk_62_5 or negedge rst_n)
begin
    if (!rst_n) begin 
      txser_clk_multiplication_factor_final              <= 10;             
      pclkx2_multiplication_factor_vs_txser_final        <= 20;       
      tx_rate_vs_pclkx2_rate_multiplication_factor_final <= 1;  
      txser_clk_period_final_sync   <= 400_000;
      serclk_4000_period_final_sync <= 12_500;  
    end else begin
      if (!lock_signals) begin
         txser_clk_multiplication_factor_final              <= txser_clk_multiplication_factor_final;             
         pclkx2_multiplication_factor_vs_txser_final        <= pclkx2_multiplication_factor_vs_txser_final;       
         tx_rate_vs_pclkx2_rate_multiplication_factor_final <= tx_rate_vs_pclkx2_rate_multiplication_factor_final;
         txser_clk_period_final_sync                        <= txser_clk_period_final_sync;
         serclk_4000_period_final_sync                      <= serclk_4000_period_final_sync;       
      
      end else if (lock_signals && pclk_enable)
      begin
         // update signal when lock_signals
         @(negedge internal_clk_62_5);
         @(negedge internal_clk_125);
         @(negedge internal_clk_250);
         @(negedge internal_clk_500); 
         @(negedge internal_clk_1000);
         @(negedge internal_clk_2000);  
         @(negedge internal_clk_4000);
         
         txser_clk_period_final_sync                        <= txser_clk_period_final; 
         serclk_4000_period_final_sync                      <= serclk_4000_period_final; 
               
      end else if (!pclk_enable) begin
         // update signal when lock_signals
         @(negedge internal_clk_62_5);
         @(negedge internal_clk_125);
         @(negedge internal_clk_250);
         @(negedge internal_clk_500); 
         @(negedge internal_clk_1000);
         @(negedge internal_clk_2000);  
         @(negedge internal_clk_4000);
          
         if (lock_signals) begin
            txser_clk_multiplication_factor_final              <= txser_clk_multiplication_factor;             
            pclkx2_multiplication_factor_vs_txser_final        <= pclkx2_multiplication_factor_vs_txser;       
            tx_rate_vs_pclkx2_rate_multiplication_factor_final <= tx_rate_vs_pclkx2_rate_multiplication_factor;
            txser_clk_period_final_sync                        <= txser_clk_period_final; 
            serclk_4000_period_final_sync                      <= serclk_4000_period_final; 
         end 
        
            
      end else begin
         txser_clk_multiplication_factor_final              <= txser_clk_multiplication_factor_final;             
         pclkx2_multiplication_factor_vs_txser_final        <= pclkx2_multiplication_factor_vs_txser_final;       
         tx_rate_vs_pclkx2_rate_multiplication_factor_final <= tx_rate_vs_pclkx2_rate_multiplication_factor_final;
         txser_clk_period_final_sync                        <= txser_clk_period_final_sync;
         serclk_4000_period_final_sync                      <= serclk_4000_period_final_sync;      
      end
   end 
end        
    
    
//     
//       if (lock_signals) begin
//          
//          // update signal when lock_signals
//          @(negedge internal_clk_62_5);
//          @(negedge internal_clk_125);
//          @(negedge internal_clk_250);
//          @(negedge internal_clk_500); 
//          @(negedge internal_clk_1000);
//          @(negedge internal_clk_2000);  
//          @(negedge internal_clk_4000);
//           
//          if (!pclk_enable) begin
//             txser_clk_multiplication_factor_final              <= txser_clk_multiplication_factor;             
//             pclkx2_multiplication_factor_vs_txser_final        <= pclkx2_multiplication_factor_vs_txser;       
//             tx_rate_vs_pclkx2_rate_multiplication_factor_final <= tx_rate_vs_pclkx2_rate_multiplication_factor;
//          end 
//             txser_clk_period_final_sync                        <= txser_clk_period_final; 
//             serclk_4000_period_final_sync                      <= serclk_4000_period_final; 
//          
//       end else begin
//          txser_clk_multiplication_factor_final              <= txser_clk_multiplication_factor_final;             
//          pclkx2_multiplication_factor_vs_txser_final        <= pclkx2_multiplication_factor_vs_txser_final;       
//          tx_rate_vs_pclkx2_rate_multiplication_factor_final <= tx_rate_vs_pclkx2_rate_multiplication_factor_final;
//          txser_clk_period_final_sync                        <= txser_clk_period_final_sync;
//          serclk_4000_period_final_sync                      <= serclk_4000_period_final_sync; 
//       end  
//     end
// end    
    
   
reg sync_txser_clk_done;
reg sync_txclk_done;
reg sync_pclk_done;
reg sync_pclkx2_done;
reg sync_max_pclk_mode2_done;
reg sync_max_pclk_mode3_done;

//=================================================================      
// Generation of all internal clk 
//=================================================================
// generate txser_clk
always begin : create_internal_txserclk
    if (!rst_n) begin   
        sync_txser_clk_done = 0;     
        local_txser_clk_period_int1 = txser_clk_period_final_sync;
        internal_txser_clk       = 1'b1;   
        #(local_txser_clk_period_int1*tx_rate_vs_pclkx2_rate_multiplication_factor_final) ;              
        internal_txser_clk       = 1'b0;   
        #(local_txser_clk_period_int1*tx_rate_vs_pclkx2_rate_multiplication_factor_final) ; 
    end else begin
      if (txserclk_lock === 1) begin
         if (!lock_signals) begin
         // keep the clk off while changing values
            sync_txser_clk_done = 0;
         end else if (lock_signals && !sync_txser_clk_done) begin
         // sync the clk with internal_clk_62_5
            sync_txser_clk_done = 1;
            @(posedge internal_clk_62_5);
            @(posedge internal_clk_62_5);
            
            local_txser_clk_period_int1 = txser_clk_period_final_sync;
            // unsync txser_clk and txclk
            #((local_txser_clk_period_int1/2*tx_rate_vs_pclkx2_rate_multiplication_factor_final));
         
            
            internal_txser_clk       = 1'b1;   
            #(local_txser_clk_period_int1*tx_rate_vs_pclkx2_rate_multiplication_factor_final) ;              
            internal_txser_clk       = 1'b0;   
            #(local_txser_clk_period_int1*tx_rate_vs_pclkx2_rate_multiplication_factor_final) ; 
            sync_txser_clk_done = 1;
         end

        local_txser_clk_period_int1 = txser_clk_period_final_sync;
        internal_txser_clk       = 1'b1;   
        #(local_txser_clk_period_int1*tx_rate_vs_pclkx2_rate_multiplication_factor_final) ;              
        internal_txser_clk       = 1'b0;   
        #(local_txser_clk_period_int1*tx_rate_vs_pclkx2_rate_multiplication_factor_final) ; 
      end else begin
        local_txser_clk_period_int1 = txser_clk_period_final_sync;
        internal_txser_clk       = 1'b1; 
        #8ns;
      end               
    end
end

// generate txclk
always
begin
   if (!rst_n) begin
        sync_txclk_done = 0;
        local_txser_clk_period_int2 = txser_clk_period_final_sync;          
        internal_txclk = 1'b1; 
        repeat (txser_clk_multiplication_factor_final/2) #(local_txser_clk_period_int2*tx_rate_vs_pclkx2_rate_multiplication_factor_final);  
        internal_txclk = 1'b0; 
        repeat (txser_clk_multiplication_factor_final/2) #(local_txser_clk_period_int2*tx_rate_vs_pclkx2_rate_multiplication_factor_final);         
   end else begin
     if (txserclk_lock === 1) begin     
         if (!lock_signals) begin
         // keep the clk off while changing values
            sync_txclk_done = 0;
         end else if (lock_signals && !sync_txclk_done) begin
         // sync the clk with internal_clk_62_5
            sync_txclk_done = 1;
            @(posedge internal_clk_62_5);
            @(posedge internal_clk_62_5);
         
           local_txser_clk_period_int2 = txser_clk_period_final_sync;          
           internal_txclk = 1'b1; 
           repeat (txser_clk_multiplication_factor_final/2) #(local_txser_clk_period_int2*tx_rate_vs_pclkx2_rate_multiplication_factor_final);  
           internal_txclk = 1'b0; 
           repeat (txser_clk_multiplication_factor_final/2) #(local_txser_clk_period_int2*tx_rate_vs_pclkx2_rate_multiplication_factor_final);              
           sync_txclk_done = 1;
         end

        local_txser_clk_period_int2 = txser_clk_period_final_sync;          
        internal_txclk = 1'b1; 
        repeat (txser_clk_multiplication_factor_final/2) #(local_txser_clk_period_int2*tx_rate_vs_pclkx2_rate_multiplication_factor_final);  
        internal_txclk = 1'b0; 
        repeat (txser_clk_multiplication_factor_final/2) #(local_txser_clk_period_int2*tx_rate_vs_pclkx2_rate_multiplication_factor_final);              
      end else begin
        local_txser_clk_period_int2 = txser_clk_period_final_sync;
        internal_txclk = 1'b1;
        #8ns;
     end 
   end
end

// generate pclk
always
begin
   if (!rst_n) begin
        sync_pclk_done = 0;
        local_txser_clk_period_int3 = txser_clk_period_final_sync;   
        internal_pclk = 1'b1; 
        repeat (pclkx2_multiplication_factor_vs_txser_final/2) #(local_txser_clk_period_int3);  
        internal_pclk = 1'b0; 
        repeat (pclkx2_multiplication_factor_vs_txser_final/2) #(local_txser_clk_period_int3);   
   end else begin
     if (txserclk_lock === 1) begin     
         if (!lock_signals) begin
            // keep the clk off while changing values
            sync_pclk_done = 0;
         end else if (lock_signals && !sync_pclk_done) begin
            // sync the clk with internal_clk_62_5
            sync_pclk_done = 1;
            @(posedge internal_clk_62_5);
            @(posedge internal_clk_62_5);
         
           local_txser_clk_period_int3 = txser_clk_period_final_sync;   
           internal_pclk = 1'b1; 
           repeat (pclkx2_multiplication_factor_vs_txser_final/2) #(local_txser_clk_period_int3);  
           internal_pclk = 1'b0; 
           repeat (pclkx2_multiplication_factor_vs_txser_final/2) #(local_txser_clk_period_int3);       
           sync_pclk_done = 1;
         end

        local_txser_clk_period_int3 = txser_clk_period_final_sync;   
        internal_pclk = 1'b1; 
        repeat (pclkx2_multiplication_factor_vs_txser_final/2) #(local_txser_clk_period_int3);  
        internal_pclk = 1'b0; 
        repeat (pclkx2_multiplication_factor_vs_txser_final/2) #(local_txser_clk_period_int3);             
     end else begin
       local_txser_clk_period_int3 = txser_clk_period_final_sync;
       internal_pclk = 1'b1;
       #16ns;
     end
   end
end

// generate pclkx2
always 
begin
   if (!rst_n) begin
      sync_pclkx2_done = 0;
      local_txser_clk_period_int4 = txser_clk_period_final_sync;  
      internal_pclkx2 = 1'b1; 
      repeat (pclkx2_multiplication_factor_vs_txser_final/4) #(local_txser_clk_period_int4);  
      internal_pclkx2 = 1'b0; 
      repeat (pclkx2_multiplication_factor_vs_txser_final/4) #(local_txser_clk_period_int4);      
   end else begin
     if (txserclk_lock === 1) begin     
         if (!lock_signals) begin
            // keep the clk off while changing values
            sync_pclkx2_done = 0;
         end else if (lock_signals && !sync_pclkx2_done) begin
            // sync the clk with internal_clk_62_5
            sync_pclkx2_done = 1;
            @(posedge internal_clk_62_5);
            @(posedge internal_clk_62_5);
         
           local_txser_clk_period_int4 = txser_clk_period_final_sync;  
           internal_pclkx2 = 1'b1; 
           repeat (pclkx2_multiplication_factor_vs_txser_final/4) #(local_txser_clk_period_int4);  
           internal_pclkx2 = 1'b0; 
           repeat (pclkx2_multiplication_factor_vs_txser_final/4) #(local_txser_clk_period_int4);   
           sync_pclkx2_done = 1;
         end
     
        local_txser_clk_period_int4 = txser_clk_period_final_sync;  
        internal_pclkx2 = 1'b1; 
        repeat (pclkx2_multiplication_factor_vs_txser_final/4) #(local_txser_clk_period_int4);  
        internal_pclkx2 = 1'b0; 
        repeat (pclkx2_multiplication_factor_vs_txser_final/4) #(local_txser_clk_period_int4);             
     end else begin
        local_txser_clk_period_int4 = txser_clk_period_final_sync;
        internal_pclkx2 = 1'b1;
        #8ns;
     end
   end
end




// generate max_pclk_mode2
real local_pclkx2_multiplication_factor_vs_txser_final_mode2; 
always
begin
   if (!rst_n) begin
        sync_max_pclk_mode2_done = 0;
        local_txser_clk_period_int5 = txser_clk_period_final_sync;  
        local_pclkx2_multiplication_factor_vs_txser_final_mode2 = pclkx2_multiplication_factor_vs_txser_final;
         
        internal_max_pclk_mode2 = 1'b1; 
        repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode2/2) #(local_txser_clk_period_int5);  
        internal_max_pclk_mode2 = 1'b0; 
        repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode2/2) #(local_txser_clk_period_int5);   
   end else begin
     if (txserclk_lock === 1) begin   
        if (!lock_signals && !en_max_pclk_mode2_latch) begin
            // keep the clk off while changing values
            sync_max_pclk_mode2_done = 0;
         end else if (lock_signals && !sync_max_pclk_mode2_done) begin
            // sync the clk with internal_clk_62_5
            sync_max_pclk_mode2_done = 1;
            @(posedge internal_clk_62_5);
            @(posedge internal_clk_62_5);
         
            local_txser_clk_period_int5 = txser_clk_period_final_sync; 
            local_pclkx2_multiplication_factor_vs_txser_final_mode2 = pclkx2_multiplication_factor_vs_txser_final;
         
           
           internal_max_pclk_mode2 = 1'b1; 
           repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode2/2) #(local_txser_clk_period_int5);  
           internal_max_pclk_mode2 = 1'b0; 
           repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode2/2) #(local_txser_clk_period_int5);  
           sync_max_pclk_mode2_done = 1;
         end

        local_txser_clk_period_int5 = txser_clk_period_final_sync;
        internal_max_pclk_mode2 = 1'b1; 
        repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode2/2) #(local_txser_clk_period_int5);  
        internal_max_pclk_mode2 = 1'b0; 
        repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode2/2) #(local_txser_clk_period_int5);             
     end else begin
       local_txser_clk_period_int5 = txser_clk_period_final_sync;
       local_pclkx2_multiplication_factor_vs_txser_final_mode2 = pclkx2_multiplication_factor_vs_txser_final;
       internal_max_pclk_mode2 = 1'b1;
       #16ns;
     end
   end
end

// generate max_pclk_mode3
real local_pclkx2_multiplication_factor_vs_txser_final_mode3;
always 
begin
   if (!rst_n) begin
      sync_max_pclk_mode3_done = 0;
      local_txser_clk_period_int6 = txser_clk_period_final_sync;  
      local_pclkx2_multiplication_factor_vs_txser_final_mode3 = pclkx2_multiplication_factor_vs_txser_final;
      
      internal_max_pclk_mode3 = 1'b1; 
      repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode3/4) #(local_txser_clk_period_int6);  
      internal_max_pclk_mode3 = 1'b0; 
      repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode3/4) #(local_txser_clk_period_int6);      
   end else begin
     if (txserclk_lock === 1) begin  
       
       if (!lock_signals && !en_max_pclk_mode3_latch) begin
            // keep the clk off while changing values
            sync_max_pclk_mode3_done = 0;
         end else if (lock_signals && !sync_max_pclk_mode3_done) begin
            // sync the clk with internal_clk_62_5
            sync_max_pclk_mode3_done = 1;
            @(posedge internal_clk_62_5);
            @(posedge internal_clk_62_5);
         
                 
            local_txser_clk_period_int6 = txser_clk_period_final_sync; 
            local_pclkx2_multiplication_factor_vs_txser_final_mode3 = pclkx2_multiplication_factor_vs_txser_final;           
           
            internal_max_pclk_mode3 = 1'b1; 
            repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode3/4) #(local_txser_clk_period_int6);  
            internal_max_pclk_mode3 = 1'b0; 
            repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode3/4) #(local_txser_clk_period_int6); 
           sync_max_pclk_mode3_done = 1;
         end
                            
       if (lock_signals) begin      
         local_txser_clk_period_int6 = txser_clk_period_final_sync; 
         local_pclkx2_multiplication_factor_vs_txser_final_mode3 = pclkx2_multiplication_factor_vs_txser_final;
       end  
         
        internal_max_pclk_mode3 = 1'b1; 
        repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode3/4) #(local_txser_clk_period_int6);  
        internal_max_pclk_mode3 = 1'b0; 
        repeat (local_pclkx2_multiplication_factor_vs_txser_final_mode3/4) #(local_txser_clk_period_int6);             
     end else begin
        local_txser_clk_period_int6 = txser_clk_period_final_sync;
        local_pclkx2_multiplication_factor_vs_txser_final_mode3 = pclkx2_multiplication_factor_vs_txser_final;
        internal_max_pclk_mode3 = 1'b1;
        #8ns;
     end
   end
end


// generate clk with freq 4000 MHz
always
begin
   if (!rst_n) begin
      internal_clk_4000 = 1'b1; #0.125ns;
      internal_clk_4000 = 1'b0; #0.125ns;
      local_serclk_4000_period_final = serclk_4000_period_final_sync;
   end else begin
// 2000Mhz (clock period=500ps) 
     if (txserclk_lock === 1) begin
        local_serclk_4000_period_final = serclk_4000_period_final_sync;          
        internal_clk_4000 = 1'b1; 
        #(local_serclk_4000_period_final*txser_clk_multiplication_factor_final);  
        internal_clk_4000 = 1'b0; 
        #(local_serclk_4000_period_final*txser_clk_multiplication_factor_final);         
     end else begin
        local_serclk_4000_period_final = serclk_4000_period_final_sync;
        internal_clk_4000 = 1'b1; #0.125ns;
        internal_clk_4000 = 1'b0; #0.125ns;
     end
   end
end

// generate clk with frew 1000 MHz
always @(posedge internal_clk_4000 or negedge rst_n)
begin 
    if (!rst_n) begin
      internal_clk_2000 = 1'b1; #0.25ns;
      internal_clk_2000 = 1'b0; #0.25ns;
    end else begin                     
      internal_clk_2000 = !internal_clk_2000; 

    end  
end

// generate clk with frew 1000 MHz
always @(posedge internal_clk_2000 or negedge rst_n)
begin 
    if (!rst_n) begin
      internal_clk_1000 = 1'b1; #0.5ns;
      internal_clk_1000 = 1'b0; #0.5ns;
    end else begin                     
      internal_clk_1000 = !internal_clk_1000; 

    end  
end

// generate clk with frew 500 MHz
always @(posedge internal_clk_1000 or negedge rst_n)
begin 
    if (!rst_n) begin
      internal_clk_500 = 1'b1; #1ns;
      internal_clk_500 = 1'b0; #1ns;      
    end else begin                                 
      internal_clk_500 = !internal_clk_500;    
    end  
end

// generate clk with frew 250 MHz
always @(posedge internal_clk_500 or negedge rst_n)
begin 
    if (!rst_n) begin
      internal_clk_250 = 1'b1; #2ns;
      internal_clk_250 = 1'b0; #2ns;
    end else begin
      internal_clk_250 = !internal_clk_250;
    end  
end


// generate clk with freq 125 MHz
always @(posedge internal_clk_250 or negedge rst_n)
begin
   if (!rst_n) begin
      internal_clk_125 = 1'b1; #4ns;
      internal_clk_125 = 1'b0; #4ns;
   end else begin
// 125 (clock period=8000ps) 
      internal_clk_125 = !internal_clk_125;        

   end
end

// generate clk with freq 62.5 MHz
always @(posedge internal_clk_125 or negedge rst_n)
begin
   if (!rst_n) begin
      internal_clk_62_5 = 1'b1; #8ns;
      internal_clk_62_5 = 1'b0; #8ns;
   end else begin
// 125 (clock period=8000ps) 
      internal_clk_62_5 = !internal_clk_62_5;           
   end
end




//=================================================================
// this is used for pclk as input
//=================================================================
reg maxpclk_enable;
reg maxpclk_enable_d;
wire maxpclk_enable_rise;

reg maxpclkreq_n_d, maxpclkreq_n_dd;
reg maxpclkack_n_d, maxpclkack_n_dd;
reg [7:0] maxpclk_ack_delay;

wire maxpclkreq_n_rise;
wire maxpclkreq_n_fall;
wire maxpclkack_n_fall;

assign maxpclkreq_n_rise = maxpclkreq_n_d  && !maxpclkreq_n_dd;
assign maxpclkreq_n_fall = !maxpclkreq_n_d && maxpclkreq_n_dd;
assign maxpclkack_n_fall = !maxpclkack_n_d && maxpclkack_n_dd;

// synch twice maxpclkreq_n and maxpclkack_n as they are asynch signals
always @(posedge internal_clk_2000 or negedge rst_n)
begin
   if (!rst_n) begin
      maxpclkreq_n_d  <= #TP 0;
      maxpclkreq_n_dd <= #TP 0;
      maxpclkack_n_d  <= #TP 0;
      maxpclkack_n_dd <= #TP 0;
   end else begin
      maxpclkreq_n_d  <= #TP maxpclkreq_n;
      maxpclkreq_n_dd <= #TP maxpclkreq_n_d;
      
      maxpclkack_n_d  <= #TP maxpclkack_n;
      maxpclkack_n_dd <= #TP maxpclkack_n_d;
   end

end


// timer to count a small delay before driving maxpclkack_n
wire       maxpclkack_assert_timer_exp;
wire [8:0] maxpclkack_assert_timer_min_value;
wire [8:0] maxpclkack_assert_timer_max_value;

integer maxpclkack_delay;
`ifndef CORETOOLS
always @(posedge maxpclkreq_n)
begin
    assert (randomize(maxpclkack_delay) with {maxpclkack_delay dist { [MAXPCLKACK_ASSERT_DELAY_MIN     : MEDIUM_PCLKACK_ASSERT_DELAY_MAX] := 10,
                                                                      [MEDIUM_PCLKACK_ASSERT_DELAY_MAX : MAXPCLKACK_ASSERT_DELAY_MAX]  := 90};});
end   
`endif // CORETOOLS

assign maxpclkack_assert_timer_min_value   = MAXPCLKACK_ASSERT_DELAY_MIN;
assign maxpclkack_assert_timer_max_value   = maxpclkack_delay;


wire max_pclk_turned_off;
reg  max_pclk_turned_off_r, max_pclk_turned_off_rr;
wire max_pclk_turned_off_rise_edge;

assign max_pclk_turned_off = 
//reuse-pragma process_ifdef standard
  `ifdef GPHY_PIPE_PCLK_MODE_2 
    !en_max_pclk_mode2_latch
  `elsif GPHY_PIPE_PCLK_MODE_3
    !en_max_pclk_mode3_latch
  `else
    !en_max_pclk_latch
  `endif
  ;
  
  
always @(posedge internal_clk_2000 or negedge rst_n)
begin
   if (!rst_n) begin
      max_pclk_turned_off_r  <= #TP '0;
      max_pclk_turned_off_rr <= #TP '0;
   end else begin
      max_pclk_turned_off_r  <= #TP max_pclk_turned_off;
      max_pclk_turned_off_rr <= #TP max_pclk_turned_off_r;   
   end
end  

assign max_pclk_turned_off_rise_edge = max_pclk_turned_off_r && !max_pclk_turned_off_rr; 

DWC_pcie_gphy_timer #(
  .WD        (9),
  .TP        (TP)
) maxpclkack_assert_timer (
  .clk       (internal_clk_2000),
  .rst_n     (rst_n),

  .start     (max_pclk_turned_off_rise_edge && maxpclkreq_n),
  .thr       (maxpclkack_assert_timer_max_value),
  .rnd_en    (1'b1),
  .rnd_lo    (maxpclkack_assert_timer_min_value),
  .rnd_hi    (maxpclkack_assert_timer_max_value),

  .expired   (maxpclkack_assert_timer_exp)
);


// timer to count a small delay before driving maxpclkack_n

wire       maxpclk_start_timer_exp;
wire [3:0] maxpclk_start_timer_min_value;
wire [3:0] maxpclk_start_timer_max_value;

assign maxpclk_start_timer_min_value = MAXPCLK_START_DELAY_MIN;
assign maxpclk_start_timer_max_value = MAXPCLK_START_DELAY_MAX;


DWC_pcie_gphy_timer #(
  .WD        (4),
  .TP        (TP)
) maxpclk_start_timer (
  .clk       (internal_clk_2000),
  .rst_n     (rst_n),

  .start     (maxpclkreq_n_fall),
  .thr       (maxpclk_start_timer_max_value),
  .rnd_en    (1'b1),
  .rnd_lo    (maxpclk_start_timer_min_value),
  .rnd_hi    (maxpclk_start_timer_max_value),

  .expired   (maxpclk_start_timer_exp)
);

// drive maxpclk_enable 
// if pclk as output mode maxpclk_enable always 1
// if there is a req to turn off maxpclk we turn it off immediatly 
// when the req is gone and timer expired turn back on maxpclk
always @(posedge internal_clk_2000 or negedge rst_n)
begin
   if (!rst_n) begin
      maxpclk_enable <= #TP 1;
   end else begin
      if (pclk_mode_input == 0)                                            maxpclk_enable <= #TP 1; else
      if (maxpclkreq_n)                                                    maxpclk_enable <= #TP 0; else
      if (!maxpclkreq_n && !maxpclkreq_n_fall && maxpclk_start_timer_exp)  maxpclk_enable <= #TP 1; else
                                                                           maxpclk_enable <= #TP maxpclk_enable;
   end
end

// drive maxpclkack_n
// if pclk as output mode maxpclkack_n always 0
// if there is a req to turn of maxpclk and a timer expired drive ack
// if maxpclk is back running clear ack
always @(posedge internal_clk_2000 or negedge rst_n)
begin
   if (!rst_n) begin
      maxpclkack_n <= #TP 0;
   end else begin
      if (pclk_mode_input == 0)                                                    maxpclkack_n <= #TP 0; else
      if (maxpclkreq_n_d  && !max_pclk_turned_off_rise_edge && max_pclk_turned_off_r && maxpclkack_assert_timer_exp 
           `ifdef GPHY_PIPE_PCLK_MODE_2 
             && !en_max_pclk_mode2_latch
           `endif 
           `ifdef GPHY_PIPE_PCLK_MODE_3
             && !en_max_pclk_mode3_latch
           `endif
           )   maxpclkack_n <= #TP 1; else
      if (!maxpclkreq_n_d && maxpclk_enable 
           `ifdef GPHY_PIPE_PCLK_MODE_2 
             && en_max_pclk_mode2_latch 
           `endif
           `ifdef GPHY_PIPE_PCLK_MODE_3
             && en_max_pclk_mode3_latch 
           `endif
          )                                     
            maxpclkack_n <= #TP 0; else
                                                                                   maxpclkack_n <= #TP maxpclkack_n;
   end
end



//===================================================================
// Logic to turn off PCLK when a powerstate that requests that
// handle the pclk_off_powerstate and generate an internal signal that will
// eventually drive pclk_enable to zero, causing pclk to be removed
// we have 2 counter that are saying when to turn off/on pclk
// ------------------------------------------------------------------------------
// generating the command to turn off pclk
reg pclk_off_cmd; initial pclk_off_cmd = 1'b1;
reg pclk_off_powerstate_d;

always @(posedge internal_clk_2000 or negedge rst_n)
begin
   if (!rst_n) pclk_off_powerstate_d <= # TP_FS 1'b0;
   else        pclk_off_powerstate_d <= # TP_FS &pclk_off_powerstate;
end

// pclk off counter
wire        pclk_off_timer_start;
wire        pclk_off_timer_exp;
wire [30:0] pclk_off_timer_lo_rnd;
wire [30:0] pclk_off_timer_hi_rnd;
wire [30:0] pclk_off_timer_fixed_value;

assign pclk_off_timer_lo_rnd      = PCLKACK_MIN_DELAY_OFF;
assign pclk_off_timer_hi_rnd      = PCLKACK_MAX_DELAY_OFF;
assign pclk_off_timer_fixed_value = (pclkack_off_time_load_en) ? pclkack_off_time : PCLKACK_MAX_DELAY_OFF;

assign pclk_off_timer_start = &pclk_off_powerstate == 1'b1 && !pclk_off_powerstate_d && pclk_off_cmd == 1'b0;

DWC_pcie_gphy_timer #(
  .WD        (31),
  .TP        (TP)
) pclk_off_timer (
  .clk       (internal_clk_2000),
  .rst_n     (rst_n),

  .start     (pclk_off_timer_start),
  .thr       (pclk_off_timer_fixed_value),
  .rnd_en    (!pclkack_off_time_load_en),
  .rnd_lo    (pclk_off_timer_lo_rnd),
  .rnd_hi    (pclk_off_timer_hi_rnd),

  .expired   (pclk_off_timer_exp)
);

// turn pclk on counter
wire        pclk_on_timer_start;
wire        pclk_on_timer_exp;
wire [30:0] pclk_on_timer_lo_rnd;
wire [30:0] pclk_on_timer_hi_rnd;
assign pclk_on_timer_lo_rnd = PCLKACK_MIN_DELAY_ON;
assign pclk_on_timer_hi_rnd = (pclkack_on_time_load_en) ? pclkack_on_time : PCLKACK_MAX_DELAY_ON;

assign pclk_on_timer_start = &pclk_off_powerstate == 1'b0 && pclk_off_powerstate_d && pclk_off_cmd == 1'b1;

DWC_pcie_gphy_timer #(
  .WD        (31),
  .TP        (TP)
) pclk_on_timer (
  .clk       (internal_clk_2000),
  .rst_n     (rst_n),

  .start     (pclk_on_timer_start),
  .thr       (pclk_on_timer_hi_rnd),
  .rnd_en    (!pclkack_on_time_load_en),
  .rnd_lo    (pclk_on_timer_lo_rnd),
  .rnd_hi    (pclk_on_timer_hi_rnd),

  .expired   (pclk_on_timer_exp)
);

// command generation
always @(posedge internal_clk_2000 or negedge rst_n)
begin
   if (!rst_n )
   begin
     pclk_off_cmd   <= #TP_FS 1'b0;
   end else begin
     if ((&pclk_off_powerstate) && !pclk_off_timer_start && pclk_off_timer_exp) 
       // request to turn off pclk and counter expired, go for it
       pclk_off_cmd  <= #TP_FS 1'b1;
     else if ((&pclk_off_powerstate == 0) && !pclk_on_timer_start && pclk_on_timer_exp)
       // request to turn on pclk and counter expired, go for it
       pclk_off_cmd <= #TP_FS 1'b0;
     else
       pclk_off_cmd <= #TP_FS pclk_off_cmd;
   end
end

// pipeline on command
// use intermediate stage to turn off pclk
// use final stage to pass ack back to the PCS
reg [6:0] pclk_off_cmd_d;
always @(posedge internal_clk_125 or negedge rst_n)
begin
   if (!rst_n)
   begin
     pclk_off_cmd_d    <= #TP_FS 5'b0;
     pclk_off_ack      <= #TP_FS '0;
   end else begin
     if (refclk_running) begin 
        pclk_off_cmd_d[0] <= #TP_FS pclk_off_cmd;
        pclk_off_cmd_d[1] <= #TP_FS pclk_off_cmd_d[0];
        pclk_off_cmd_d[2] <= #TP_FS pclk_off_cmd_d[1];
        pclk_off_cmd_d[3] <= #TP_FS pclk_off_cmd_d[2];
        pclk_off_cmd_d[4] <= #TP_FS pclk_off_cmd_d[3];
        pclk_off_cmd_d[5] <= #TP_FS pclk_off_cmd_d[4];
        pclk_off_cmd_d[6] <= #TP_FS pclk_off_cmd_d[5];     
     end
     
       pclk_off_ack <=  #TP_FS pclk_off_cmd_d[6];
   end
end


`ifdef GPHY_ESM_SUPPORT
//==============================================================================
//Cariblation Complete logic
//==============================================================================
// Emulate processing time to calibration
// set the fixed threshold
localparam MIN_CALIBRT_RET_DLY = 8;
localparam MAX_CALIBRT_RET_DLY = 100;
reg                           esm_calibrt_req_int;
reg [5:0]                     esm_calibrt_req_int_d;
reg                           esm_calibrt_req_pos;
reg                           esm_calibrt_complete;
reg                           esm_calibrt_complete_d;
reg                           esm_pre_calibrt_complete;
reg                           calibrt_timer_en;
reg                           calibrt_timer_exp;
wire    [7:0]                 calibrt_timer_thr;
wire    [7:0]                 calibrt_timer_lo_rnd; // low limit for randomization - before scaling
wire    [7:0]                 calibrt_timer_hi_rnd; // high limit for randomization - before scaling

assign calibrt_timer_thr    = (random_calibrt_complete_en) ? MIN_CALIBRT_RET_DLY : fixed_calibrt_complete_thr;
assign calibrt_timer_lo_rnd = (random_calibrt_complete_en) ? MIN_CALIBRT_RET_DLY : fixed_calibrt_complete_thr;
assign calibrt_timer_hi_rnd = (random_calibrt_complete_en) ? MAX_CALIBRT_RET_DLY : fixed_calibrt_complete_thr;

// internaly register the esm_calibration_req
always @(posedge internal_clk_2000 or negedge rst_n) begin
    if (!rst_n)                 esm_calibrt_req_int    <= #TP 5'b0; else 
    if (esm_calibrt_req)        esm_calibrt_req_int    <= #TP 1'b1; else
    if (esm_calibrt_req_pos)    esm_calibrt_req_int    <= #TP 5'b0; else
                                esm_calibrt_req_int    <= #TP esm_calibrt_req_int;  
                                                           
end

// we delay the esm_calibration ack to give some pclk cycles before turnig off the pclk
always @(posedge internal_clk_125 or negedge rst_n) begin
    if (!rst_n)   begin
        esm_calibrt_req_int_d  <= #TP 'd0;  
    end else if (esm_calibrt_req_pos) begin
        esm_calibrt_req_int_d  <= #TP 'd0;  
    end else begin 
        esm_calibrt_req_int_d[0] <= #TP esm_calibrt_req_int;
        esm_calibrt_req_int_d[1] <= #TP esm_calibrt_req_int_d[0]; 
        esm_calibrt_req_int_d[2] <= #TP esm_calibrt_req_int_d[1]; 
        esm_calibrt_req_int_d[3] <= #TP esm_calibrt_req_int_d[2]; 
        esm_calibrt_req_int_d[4] <= #TP esm_calibrt_req_int_d[3];
        esm_calibrt_req_int_d[5] <= #TP esm_calibrt_req_int_d[4];
    end    
end

// signal to turn off pclk
always @(posedge internal_clk_125 or negedge rst_n) begin
    if (!rst_n)                                       esm_calibrt_req_pos  <= #TP 1'b0; else
    if (esm_calibrt_req_int_d[5])                     esm_calibrt_req_pos  <= #TP 1'b1; else
    if (!pclk_enable)                                 esm_calibrt_req_pos  <= #TP 1'b0; else
                                                      esm_calibrt_req_pos  <= #TP esm_calibrt_req_pos;
end

// calibration enable
always @(posedge internal_clk_125 or negedge rst_n) begin
    if (!rst_n) begin
        calibrt_timer_en  <= #TP 1'b0;
    end else begin
        calibrt_timer_en  <= #TP (esm_calibrt_req_pos) ? 1'b1 :
                                 (calibrt_timer_exp)   ? 1'b0 : calibrt_timer_en;
    end
end

DWC_pcie_gphy_timer #(
  .WD        (8),
  .TP        (TP)
) calibrt_timer (
  .clk       (internal_clk_125),
  .rst_n     (rst_n),
  .start     (esm_calibrt_req_pos),
  .thr       (calibrt_timer_thr),
  .rnd_en    (random_calibrt_complete_en),
  .rnd_lo    (calibrt_timer_lo_rnd),
  .rnd_hi    (calibrt_timer_hi_rnd),
  .expired   (calibrt_timer_exp)
);

// generate pre-calibration complete
// on this signal we turn on pclk
always @(posedge internal_clk_125 or negedge rst_n) begin
    if (!rst_n) begin
        esm_pre_calibrt_complete <= #TP 1'b0;
    end else begin
        if(calibrt_timer_en && calibrt_timer_exp) begin
            esm_pre_calibrt_complete <= #TP 1'b1;
        end else if (pclk_enable && lock && esm_calibrt_complete) begin
           esm_pre_calibrt_complete <= #TP 1'b0;
        end
    end
end


// generate calibration complete when pclk is on and stable
always @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
        esm_calibrt_complete   <= #TP 1'b0;
        esm_calibrt_complete_d <= #TP 1'b0;
    end else if (esm_pre_calibrt_complete && pclk_enable && lock) begin
        esm_calibrt_complete   <= #TP 1'b1;
        esm_calibrt_complete_d <= #TP esm_calibrt_complete;
    end else begin
        esm_calibrt_complete <= #TP 1'b0;
        esm_calibrt_complete_d <= #TP esm_calibrt_complete;
    end    
end

assign esm_calibrt_complete_pulse = esm_calibrt_complete && ~esm_calibrt_complete_d && calibration_complete_en;

`endif // GPHY_ESM_SUPPORT
//=================================================================
// Measure refclk perioad and extract the deviation
// Determin when refclk is off
//=================================================================
reg [2:0] refclk_cnt; initial refclk_cnt   = 3'b0;
reg refclk_cnt_rst_n; initial refclk_cnt_rst_n = 1'b0;

always @(posedge refclk or negedge refclk_cnt_rst_n)
begin
  if ( !refclk_cnt_rst_n )
  begin
    refclk_cnt     <= #TP '0;
  end else begin
    refclk_cnt     <= #TP refclk_cnt + 1'b1;
  end
end

// refclk=100Mhz=10ns period
// txclk_max (1s) = 2000Mz = 0.5ns period. need to wait > 20 cycles
// txclk_max (1s) = 1000Mz = 1ns   period. need to wait > 10 cycles
// txclk_max (2s) =  500Mz = 2ns   period. need to wait >  5 cycles

//refclk monitor to determin when refclk is on/off
reg [4:0] txclk_max_cnt; initial txclk_max_cnt = 5'b0;

always @(posedge internal_clk_2000 or negedge rst_n)
begin
  if (!rst_n)
  begin
    refclk_cnt_rst_n <= #TP 1'b0;
    txclk_max_cnt    <= #TP 5'b0;
    refclk_running   <= #TP 1'b0;
  end else begin
    if (txclk_max_cnt <= 20) begin
      refclk_running   <= #TP refclk_running;
      refclk_cnt_rst_n <= #TP 1'b1;
      txclk_max_cnt    <= #TP txclk_max_cnt + 1'b1;
    end else if (txclk_max_cnt > 20) begin
      refclk_running   <= #TP (refclk_cnt == '0) ? 1'b0 : 1'b1;
      refclk_cnt_rst_n <= #TP 1'b0;
      txclk_max_cnt    <= #TP 5'b0;
    end
  end
end

always @(posedge internal_clk_125 or negedge rst_n)
begin
   if (!rst_n)   txclk_enable   <= 1'b0;
   else begin
      if (!refclk_running) txclk_enable   <= 1'b0;
      else                 txclk_enable   <= 1'b1;
   end
end



always @(posedge refclk or negedge rst_n or negedge refclk_running)
begin
   if (!rst_n)                refclk_running_dly   <= '0;
   else if (!refclk_running)  refclk_running_dly   <= '0;
   else begin
      refclk_running_dly[0]   <= #TP refclk_running;
      refclk_running_dly[5:1] <= #TP refclk_running_dly[4:0];
   end
end

// pclk turn on/off
// we gate pclk:
// - during reset
// - during a rate change, if pclk frequency switch is required
// - as determined by pipe2phy (via pclk_off_req) in low power states
always @(posedge internal_clk_125 or negedge rst_n)
begin
   if (!rst_n)
   begin
     pclk_enable   <= 1'b0;
   end else begin
     pclk_enable <=  (!ready)                                   ? 1'b0 :
                     (rate_change_off)                          ? 1'b0 :
                     `ifdef GPHY_ESM_SUPPORT
                     (esm_calibrt_req_pos ||calibrt_timer_en )  ? 1'b0 :
                     `endif //GPHY_ESM_SUPPORT
                     (pclk_off_cmd_d[1] || (!refclk_running && !refclk_running_dly[5]))     ? 1'b0 : 1'b1;

   end
end

always @(posedge internal_pclk or negedge rst_n)
begin
   if (!rst_n) 
      pclk_enable_r <= #TP_FS 0;
   else  
      pclk_enable_r <= #TP_FS  pclk_enable;
end  

// we need to turn of pclk on pclk_enable and turn on on pclk_enable_r
// wire pclk_enable_final;
// assign  pclk_enable_final =  pclk_enable && pclk_enable_r;


reg en_pclk_latch;
always @(internal_pclk or negedge rst_n) 
begin
   if (!rst_n) begin
      if (!internal_pclk)
        en_pclk_latch <= 0; 
   end else
   if (!internal_pclk)
      en_pclk_latch <= pclk_enable;
end 

reg en_pclkx2_latch;
always @(internal_pclkx2 or negedge rst_n) 
begin
   if (!rst_n) begin
      if (!internal_pclkx2)
        en_pclkx2_latch <= 0;
   end else
   if (!internal_pclkx2)
      en_pclkx2_latch <= pclk_enable;
end 

reg en_txclk_latch; initial en_txclk_latch = 0;
always @(internal_txclk) 
begin
   if (!internal_txclk && pclk_enable_r)
      en_txclk_latch <= txclk_enable;
end 

always @(internal_max_pclk or negedge rst_n) 
begin
   if (!rst_n) begin
      if (!internal_max_pclk)
        en_max_pclk_latch <= pclk_mode_input ? maxpclk_enable : 0; 
   end else
   if (!internal_max_pclk)
      en_max_pclk_latch <= pclk_mode_input ? maxpclk_enable : pclk_enable;
end 




// wire gate_max_pclk_mode_2;
// assign gate_max_pclk_mode_2 = rate_change_off && pclk_off_rate_ddd[0];


always @(internal_max_pclk_mode2 or negedge rst_n) 
begin
   if (!rst_n) begin
      if (!internal_max_pclk_mode2)
        en_max_pclk_mode2_latch <= pclk_mode_input ? maxpclk_enable && !rate_change_off_dd[0] && ready : 0; 
   end else
   if (!internal_max_pclk_mode2)
      en_max_pclk_mode2_latch <= pclk_mode_input ? maxpclk_enable && !rate_change_off_dd[0] && ready : pclk_enable;
end

always @(internal_max_pclk_mode3 or negedge rst_n) 
begin
   if (!rst_n) begin
      if (!internal_max_pclk_mode3)
        en_max_pclk_mode3_latch <= pclk_mode_input ? maxpclk_enable && !rate_change_off_dd[0] && ready : 0; 
   end else
   if (!internal_max_pclk_mode3)
      en_max_pclk_mode3_latch <= pclk_mode_input ? maxpclk_enable && !rate_change_off_dd[0] && ready : pclk_enable;
end
 
// ------------------------------------------------------------------------------
// this counter counts the period that pclk it is off when we have a rate change
// when we get a req to change the rate from all lanes we start counting few more clk 
// cycles before turning off pclk
// ------------------------------------------------------------------------------
reg    lock_d;
wire   lock_negedge;
assign lock_negedge = !lock & lock_d;

always @(posedge refclk or negedge rst_n)
begin
   if      (!rst_n)   lock_d <= #TP_FS 1'b0;
   else               lock_d <= #TP_FS lock;       
end

// pclk rate off timer
reg  [7:0] pclk_rate_off_timer_start;
wire       pclk_rate_off_timer_exp;
wire [7:0] pclk_rate_off_timer_thr; 
assign pclk_rate_off_timer_thr   = PCLK_OFF_RATE_DLY;
 
// we have to start the counter later do that we give few more pclk cycles before we turn off pclk
always @(posedge refclk or negedge rst_n)
begin
  if (!rst_n)
   begin
     pclk_rate_off_timer_start    <= #TP_FS 5'b0;
   end else begin
     pclk_rate_off_timer_start[0]   <= #TP_FS lock_negedge && &pclk_off_rate;          
     pclk_rate_off_timer_start[7:1] <= #TP_FS pclk_rate_off_timer_start[6:0];     
   end 
end



DWC_pcie_gphy_timer #(
  .WD        (8),
  .TP        (TP)
) pclk_rate_off_timer (
  .clk       (refclk),
  .rst_n     (rst_n),

  .start     (pclk_mode_input ? pclk_rate_off_timer_start[7] : pclk_rate_off_timer_start[5]),
  .thr       (pclk_rate_off_timer_thr),
  .rnd_en    (1'b0),
  .rnd_lo    (8'b0),
  .rnd_hi    (8'b0),

  .expired   (pclk_rate_off_timer_exp)
);

// range when pclk_rate in changing; durin this time pclk should be off
assign rate_change_off = !pclk_rate_off_timer_exp ; //(rate_counter > 0) && (rate_counter < rate_delay_value - 5);

// ------------------------------------------------------------------------------
// lock counter. After pclk starts lock will be set after a delay so that the pclk it is stable
// ------------------------------------------------------------------------------
reg pclk_enable_r_sync_125;
reg pclk_enable_rr_sync_125;

always @(posedge internal_clk_125 or negedge rst_n)
begin
   if (!rst_n) begin
      pclk_enable_r_sync_125   <= #TP '0;
      pclk_enable_rr_sync_125  <= #TP '0;
   end else begin
      pclk_enable_r_sync_125  <= #TP pclk_enable;
      pclk_enable_rr_sync_125 <= #TP pclk_enable_r_sync_125;
   end     
end   


wire        lock_timer_start;
wire        lock_timer_exp;
reg         lock_timer_exp_d;
wire  [5:0] lock_timer_thr;
assign      lock_timer_thr   = LOCK_RET_DLY;
assign      lock_timer_start = pclk_enable_rise;

DWC_pcie_gphy_timer #(
  .WD        (6),
  .TP        (TP)
) lock_timer (
  .clk       (internal_clk_125),
  .rst_n     (rst_n),

  .start     (lock_timer_start),
  .thr       (lock_timer_thr),
  .rnd_en    (1'b0),
  .rnd_lo    (6'b0),
  .rnd_hi    (6'b0),

  .expired   (lock_timer_exp)
);

// registred version of lock_timer_expired
always @(posedge internal_pclk or negedge rst_n)
begin
   if      (!rst_n)   lock_timer_exp_d <= #TP_FS 1'b1;
   else               lock_timer_exp_d <= #TP_FS lock_timer_exp;       
end

assign    pclk_enable_rise = pclk_enable_r_sync_125 && !pclk_enable_rr_sync_125;

// lock it is 0 while pclk is off and until pclk it is stable
// when we get a request to turn off pclk, lock goes to 0
reg  pclk_off_rate_d;
wire pclk_off_rate_posedge;

assign pclk_off_rate_posedge = !pclk_off_rate_d & (&pclk_off_rate);

always @(posedge internal_pclk or negedge rst_n)
begin
   if      (!rst_n)   pclk_off_rate_d <= #TP_FS 1'b0;
   else               pclk_off_rate_d <= #TP_FS &pclk_off_rate;       
end

always @(posedge internal_pclk or negedge rst_n)
begin
  if (!rst_n)                                    lock <= #TP_FS 1'b0;
  else if (pclk_off_rate_posedge)                lock <= #TP_FS 1'b0; 
  else if (rate_change_off || !pclk_enable)      lock <= #TP_FS 1'b0; //setting a range to give more pclk cycles before turning off pclk
  else if (lock_timer_exp && !lock_timer_exp_d)  lock <= #TP_FS 1'b1;
end


wire [NL-1:0] pclk_off_rate_sync_clk_62_5_posedge;

reg en_txclk_latch_r;
reg en_txclk_latch_rr;
reg drop_lock;


// pclk_i is per lane => lock_pclk_in needs to be per lane
// When we are in reset we put lock_pclk_in in 0
genvar lane;
generate
for (lane = 0; lane<NL; lane = lane + 1) begin : lock_pclk_in_lane

always @(posedge internal_clk_62_5 or negedge rst_n)
begin
  if (!rst_n) begin
   sync_txclk_done_d[lane]   <= #TP_FS 0;
   sync_txclk_done_dd[lane]  <= #TP_FS 0;
   sync_txclk_done_ddd[lane] <= #TP_FS 0;
   en_txclk_latch_r          <= #TP_FS 0;
   en_txclk_latch_rr         <= #TP_FS 0;
   rate_change_off_d[lane]   <= #TP_FS 0;
   rate_change_off_dd[lane]  <= #TP_FS 0;
   drop_lock                 <= #TP_FS 0; 
  end else begin
   if (en_txclk_latch) begin
     sync_txclk_done_d[lane]   <= #TP_FS sync_txclk_done;
     sync_txclk_done_dd[lane]  <= #TP_FS sync_txclk_done_d[lane];
     sync_txclk_done_ddd[lane] <= #TP_FS sync_txclk_done_dd[lane];      

   end
   en_txclk_latch_r          <= #TP_FS en_txclk_latch;
   en_txclk_latch_rr         <= #TP_FS en_txclk_latch_r;
   rate_change_off_d[lane]   <= #TP_FS rate_change_off;
   rate_change_off_dd[lane]  <= #TP_FS rate_change_off_d[lane];
   
   drop_lock <= #TP_FS  (pclk_off_rate_d && !sync_txclk_done) || !pclk_enable || !maxpclk_enable;
  end    
end

always @(posedge i_pclk[lane] or negedge rst_n or posedge drop_lock)
begin
  if (!rst_n)                                          lock_pclk_in[lane] <= #TP_FS 1'b0;
//reuse-pragma process_ifdef standard
  `ifdef GPHY_PIPE_PCLK_MODE_1
  else if (drop_lock)                                  lock_pclk_in[lane] <= #TP_FS 1'b0;
  else if (sync_txclk_done && en_txclk_latch_rr && lock && maxpclk_enable)       lock_pclk_in[lane] <= #TP_FS 1'b1;
  else                                                 lock_pclk_in[lane] <= #TP_FS lock_pclk_in[lane] ;   
  `else    
  else                                                 lock_pclk_in[lane] <= #TP_FS !rate_change_off && ready && sync_txclk_done_ddd;
  `endif // GPHY_PIPE_PCLK_MODE_1
//reuse-pragma process_ifdef all_branches
end

end 
endgenerate

// ------------------------------------------------------------------------------
// Generation of the output clocks (txclk/pclk/pclk2)
// ------------------------------------------------------------------------------
// change clk freq
assign txbitclk = internal_txser_clk;

assign txclk    = en_txclk_latch && internal_txclk;

assign txclk_ug = internal_txclk;

assign pclk     = en_pclk_latch && internal_pclk ;

assign pclkx2 = en_pclkx2_latch && internal_pclkx2;

assign internal_max_pclk = (`GPHY_MAX_PCLK_FREQ_MHZ == 2000) ? internal_clk_2000 : 
                           (`GPHY_MAX_PCLK_FREQ_MHZ == 1000) ? internal_clk_1000 : 
                           (`GPHY_MAX_PCLK_FREQ_MHZ ==  500) ? internal_clk_500  :
                           (`GPHY_MAX_PCLK_FREQ_MHZ ==  250) ? internal_clk_250  :
                                                               internal_clk_125  ;

assign max_pclk = 
//reuse-pragma process_ifdef standard
  `ifdef GPHY_PIPE_PCLK_MODE_2 
    internal_max_pclk_mode2 && en_max_pclk_mode2_latch
  `elsif GPHY_PIPE_PCLK_MODE_3
    internal_max_pclk_mode3 && en_max_pclk_mode3_latch
  `else
    internal_max_pclk && en_max_pclk_latch
  `endif
//reuse-pragma process_ifdef all_branches
  ;
  

// ------------------------------------------------------------------------------
// model PLL power on time
// wait for 8 pclks after reset to enable the ready signal
// FIXME: there is a CDC here!
// ------------------------------------------------------------------------------
reg [4:0] ready_cnt;
always @(posedge internal_clk_125 or negedge rst_n)
begin
 if (!rst_n)
   ready_cnt <= #TP_FS 4'b1111;
 else
   ready_cnt <= #TP_FS (ready_cnt > 0) ? ready_cnt - 1 : ready_cnt;
end

always @(posedge internal_pclk or negedge rst_n)
begin
   if (!rst_n)
     ready <= #TP_FS 1'b0;
   else
     ready <= #TP_FS (ready_cnt == 0) ? 1'b1 : 1'b0;
end

endmodule: DWC_pcie_gphy_pll

