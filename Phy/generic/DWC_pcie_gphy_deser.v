
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
// ---    $Revision: #25 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_deser.v#25 $
// -------------------------------------------------------------------------
// --- Module Description: Deserializer
// -------------------------------------------------------------------------

module DWC_pcie_gphy_deser #(
  parameter   TP       = -1,                           // Clock to Q delay (simulator insurance)
  parameter   WIDTH_WD = -1
) (
  input            refclk,                     // reference clock
  input            rst_n,                      // reset
  input            rx_clock_off,               // clock has been turned off in P1
  input            rxpolarity,                 // invert serial data
  input            serdes_arch,
  input  [WIDTH_WD-1:0]   rxwidth,
  
  input            rxp,                        // serial receive data (pos)
  input            rxn,                        // serial receive data (neg)
  input      [2:0] rate,                       // current data rate
  input      [2:0] current_rate,  
  input      [3:0] powerdown,
  input            rxstandby,
  input            rxsymclk_random_drift_en,
  input            rxelecidle_filtered,        // electrical idle detected filtered
  input            rxelecidle_unfiltered,      // electrical idle detected
  input            sris_mode,
  input            cdr_fast_lock,
  output reg       rxbitclk,
`ifdef GPHY_ESM_SUPPORT
  input            esm_enable,
  input [6:0]      esm_data_rate0,
  input [6:0]      esm_data_rate1, 
`endif // GPHY_ESM_SUPPORT
  output reg [9:0] rxdata_10b,                 // parallel 10 bit receive data
  output           beacondetected,             // beacondetected
  output reg       recvdclk,                   // recovered receiver symbol clock
  output           recvdclk_pipe,
  output           rcvdrst_n,
  output reg       serdes_rx_valid,
  output reg       recvdclk_stopped
); 

timeunit 10fs;
timeprecision 1fs;

// symbol clock reference times
// GEN1_CYCLE       = 400_000;   //  250 MHz
// GEN2_CYCLE       = 200_000;   //  500 MHz
// GEN3_CYCLE       = 100_000;   // 1000 MHz
// GEN4_CYCLE       =  50_000;   // 2000 MHz
// ESM_GEN4_20GT    =  40_000;   // 2500 MHZ
// ESM_GEN4_25GT    =  32_000;   // 3125 MHz
reg pop_enable;
reg  [WIDTH_WD-1:0]   rxwidth_sync, rxwidth_sync_r, rxwidth_sync_rr;


wire   cdr_enable;
assign cdr_enable = !rx_clock_off;

wire int_rxpolarity;
assign int_rxpolarity = serdes_arch ? 1'b0 : rxpolarity;

reg align_en;

always @(posedge rxbitclk or negedge rst_n)
begin
   if (!rst_n) begin
      align_en <= #TP 0;
   end else begin
      if (rate != current_rate) 
          align_en <= #TP 0; 
      else if (rxstandby)   
          align_en <= #TP 0;
      else if (powerdown inside { `GPHY_PDOWN_P0, `GPHY_PDOWN_P0S })
         align_en <= #TP 1;
      else  
         align_en <= #TP 0;
   end
   
end
//=============================================================================
// Simlified CDR Model
// Not support for Refclk Deviation
// Minimum unit of UI should be 1fs
//=============================================================================
reg bit_time_lock; initial bit_time_lock = 0;
reg       bit_time_change; initial bit_time_change = 0;
realtime  bit_time;        initial bit_time = 40_000;
realtime  first_bit_time;  initial first_bit_time = 40_000;
realtime  rxp_time1;
realtime  rxp_time2;
realtime  rxbitclk_sample;

// rxbitclk generation
always begin : create_rxclk
    if (!rst_n) begin
        rxbitclk       = 1'b0;
        #0.4ns ;
    end else begin
        if (cdr_enable) begin  
         // move the sampling point at the mid of the bit
         // we do this by having a clock period smaller or bigger then standard
         // this happens from time to time when the sampling point it is shifted
         if (bit_time_change)
         begin              
          rxbitclk       = 1'b0;
          #(first_bit_time) ;
          rxbitclk       = 1'b1;
          #(bit_time) ;        
          bit_time_change = 0;
         end
              
          rxbitclk       = 1'b0;
          #(bit_time) ;
          rxbitclk       = 1'b1;
          #(bit_time) ;        
        end else begin
          rxbitclk       = 1'b0;
          #0.4ns ;
        end
    end
end

realtime rxp_delta;
assign   rxp_delta = rxp_time1 - rxp_time2;

wire   rate_changing;
assign rate_changing = (rate != current_rate) ? 1 : 0;
reg    rate_changing_r;
reg    rate_changing_rr;


always @(posedge rxbitclk or negedge rst_n) begin
   if (!rst_n) begin
      rate_changing_r  <= 'd0;
      rate_changing_rr <= 'd0;
   end else begin
      rate_changing_r  <= rate_changing;
      rate_changing_rr <= rate_changing_r;
   end          
end

// sample rxbitclk
always @(rxbitclk or negedge rst_n) begin
      rxbitclk_sample <= $realtime;      
end

// measure rxp width from edge to edge
always @(rxp or negedge rst_n) begin
    if (!rst_n) begin
        rxp_time1    <= 40_000;
        rxp_time2    <= 0;        
    end else begin
        rxp_time1  <= $realtime;
        rxp_time2  <= rxp_time1;    
    end
end

// compute bit time 
always @(rxp or rate_changing_r or rate_changing or negedge rst_n) begin
    if (!rst_n) begin
        bit_time     <= 40_000;
        bit_time_lock <= 1'b0;
        
    end else if (rate_changing && !cdr_fast_lock) begin
        bit_time      <= bit_time ;
        bit_time_lock <= 1'b0;
    end else if (rate_changing_rr && !rate_changing_r && cdr_fast_lock) begin   
        bit_time     <= (rate == 0) ?   40_000 :
                        (rate == 1) ?   20_000 :
                        (rate == 2) ?   12_500 :
                        (rate == 3) ?    6_250 :
                        (rate == 4) ?    3_125 :
                        (rate == 5) ?    1_562 : 1_562 ;
        bit_time_lock <= 1'b1;
        
    end else if (rxelecidle_filtered) begin   
        bit_time     <= bit_time ;
        bit_time_lock <= 1'b0;
    end else begin
            
        if (
          `ifdef GPHY_ESM_SUPPORT
            (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT  && rxp_delta < 126_00   && rxp_delta > 124_00 ) || 
            (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT && rxp_delta < 63_00    && rxp_delta > 62_00  ) ||
            (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_16GT && rxp_delta < 63_00    && rxp_delta > 62_00  ) ||
            (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT && rxp_delta < 51_00    && rxp_delta > 49_00  ) ||  //ESM_GEN4_20GT/8.0 
            (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT && rxp_delta < 40_50    && rxp_delta > 39_50  ) ||  //ESM_GEN4_25GT/8.0
          `endif// GPHY_ESM_SUPPORT
        
           ( (rate === 0) && rxp_delta < 403_00 && rxp_delta > 398_00 ) ||       
           ( (rate === 1) && rxp_delta < 202_00 && rxp_delta > 199_00 ) ||       
           (`ifdef GPHY_ESM_SUPPORT 
              !esm_enable &&
            `endif // GPHY_ESM_SUPPORT
             (rate === 2) && rxp_delta < 126_00 && rxp_delta > 124_00 ) ||       
           (`ifdef GPHY_ESM_SUPPORT
              !esm_enable && 
            `endif // GPHY_ESM_SUPPORT
              (rate === 3) && rxp_delta <  63_00 && rxp_delta >  62_00 ) ||
             ( (rate === 4) && rxp_delta <  31_50 && rxp_delta >  31_00 )||
             ( (rate === 5) && rxp_delta <  15_90 && rxp_delta >  15_35 )) begin

            // we calculate the offset between the edge of the rxbitclk and midd of the rxp bit
            // we need to do this to be able to move dinamicaly the sampling point to the midd of the bit
            // this is needded to be able to compensate the jitteri incoming clock
            if ($realtime - rxbitclk_sample < 40_500 )  begin           
               if ($realtime - rxbitclk_sample == rxp_delta )
                 first_bit_time <= rxp_delta/2;               
               else if ($realtime - rxbitclk_sample > rxp_delta/2 )
                 first_bit_time <= rxp_delta + (($realtime - rxbitclk_sample) - rxp_delta/2);
               else if ($realtime - rxbitclk_sample < rxp_delta/2 )
                 first_bit_time <= rxp_delta - (rxp_delta/2 - ($realtime - rxbitclk_sample) );  
               else if ($realtime - rxbitclk_sample == rxp_delta/2 )      
                 first_bit_time <= rxp_delta;
               bit_time_change <= 1;    
            end
            
            bit_time <= rxp_delta;
            bit_time_lock <= 1'b1;
        end
    end
end


//======================================================================
// Beacon detection
// Just using a simple indication when both rx lines are high (strictly
// speaking this would be an electrical idle condition)
//======================================================================
assign beacondetected  = (rxp == 1) & (rxn == 1);


//======================================================================
// Infinite queue used to buffer up serial data and model symbol clock 
// drifting
//======================================================================
//we write the bits into the queue on rxclk as it comes in
reg rx_q[$];
always @(rxbitclk)
begin
   if (!rst_n) begin
     rx_q = {};
   end else if (!align_en) begin
     rx_q = {};
   end else if (!rxelecidle_unfiltered && align_en && bit_time_lock) begin // rxelecidle_synthesized
     rx_q.push_back(rxp);
  end 
end

//======================================================================
// Setup thread randomization
// this is required to support the randomization of the recvdclk drift
//======================================================================
int rxclk_drift_lo;
int rxclk_drift_hi;
int rxclk_drift_temp;

// TODO : use actual values  - this is drift expressed in timeunits (10fs)
// TODO : take SRIS into account
// +/-300ppm frequency deviation
// frequency (MHz) Max frequency (MHz) Corresponding min period (ns) deviation (10fs)
// 250             250.075             3.99880036                    119
// 500             500.15              1.99940018                    59
// 1000            1000.3              0.99970009                    29
// 2000            2000.6              0.499850045                   14
// 2500            2500.75             0.399880035                   11
// 3125            3125.937            0.319904079                    9

// with SRIS
// frequency (MHz) Max frequency (MHz) Corresponding min period (ns) deviation (10fs)
// 250             250.7              3.988831272                    1116
// 500             501.4              1.994415636                    558
// 1000            1002.8             0.997207818                    279
// 2000            2005.6             0.498603909                    139
// 2500            2507.00            0.398883130                    116
// 3125            3133.750           0.319106500                     89

assign rxclk_drift_temp =
                        `ifdef GPHY_ESM_SUPPORT
                         (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT)  ? ( sris_mode ? 279  : 29) :
                         (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT) ? ( sris_mode ? 139  : 14) :
                         (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT) ? ( sris_mode ? 116  : 11) :
                         (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT) ? ( sris_mode ? 89  :   9) :
                        `endif// GPHY_ESM_SUPPORT
                        (rate == 5) ? ( sris_mode ?   34 :  3) :
                        (rate == 4) ? ( sris_mode ?   69 :  7) :
                        (rate == 3) ? ( sris_mode ?  139 : 14) :
                        (rate == 2) ? ( sris_mode ?  279 : 29) :
                        (rate == 1) ? ( sris_mode ?  558 : 59) : 
                                      ( sris_mode ? 1116 : 119);
                                      
// Recude the amount of jitter that we introduce by 10th part
// TODO Refine more the range of jitter                                       
assign rxclk_drift_hi = rxclk_drift_temp/10 + 1;

// PPM deviation is symmetric
assign rxclk_drift_lo = -1*(rxclk_drift_hi);


DWC_pcie_gphy_pkg::DWC_pcie_gphy_rxdrift rnd_delta;
initial begin
  string inst;
  int seed;

  // generate a seed which is unique to this instance
  $sformat(inst, "%m");
  seed = $get_initial_random_seed();
  for (int i=0 ; i< inst.len(); i++) seed += inst.getc(i);

  rnd_delta = new(inst, seed);
  forever @(posedge recvdclk)
  begin
    rnd_delta.newValue(rxclk_drift_lo, rxclk_drift_hi, rx_q.size());
  end
end



// when we turn off the recvdclk we need to give some rcvd clk cycles
// so that the last symbol read from serials lines reaches the elastic buffer and it is pushed
// into the elastic buffer
// this means 30 rcvdclk before turning off the rcvdclk
reg [3:0] rate_delayed;
always @(rxbitclk or negedge rst_n)
begin
   if (!rst_n)                            rate_delayed <= 'd0; else
   if (rate_changing && recvdclk_stopped) rate_delayed <= rate; else
   if (rate == current_rate)              rate_delayed <= rate; 
end 


// after the queue is empty we give extrac ckl cycles so that the data reached phy output
// in serdes mode the number of clk needs to be > 50
reg     [8:0]  rcvdclk_counter; initial rcvdclk_counter = 8'h00;
always @(posedge recvdclk_pipe or negedge rst_n)
begin
   if (!rst_n )                                         rcvdclk_counter <= #TP 8'h00;
   else if (rxelecidle_filtered && rcvdclk_counter > 0) rcvdclk_counter <= #TP rcvdclk_counter - 1;
   else if (!rxelecidle_filtered && serdes_arch)        rcvdclk_counter <= #TP `GPHY_RXVALID_DEASSERT_DELAY;
   else if (!rxelecidle_filtered)                       rcvdclk_counter <= #TP (rate_delayed > 1) ? 8'h37 :8'h06 ;
   
end


// in serdes mode after rx_valid is dropped we need at least 50 clk cycles
reg     [8:0]  serdes_rcvdclk_counter; initial serdes_rcvdclk_counter = 8'h00;
always @(posedge recvdclk_pipe or negedge rst_n)
begin
   if (!rst_n )                                        serdes_rcvdclk_counter <= #TP 8'h00;
   else if (!pop_enable && serdes_rcvdclk_counter > 0) serdes_rcvdclk_counter <= #TP serdes_rcvdclk_counter - 1;
   else if (pop_enable)                                serdes_rcvdclk_counter <= #TP `GPHY_RECVDCLK_OFF_DELAY + `GPHY_LATENCY_SERDES;
   
end

// this is an indication that recvdclk is off
always @(posedge rxbitclk or negedge rst_n)
begin
  if (!rst_n)                                                     recvdclk_stopped <= #TP 1'b1; else
  if (!serdes_arch && !pop_enable && rcvdclk_counter == 0)        recvdclk_stopped <= #TP 1'b1; else
  if (serdes_arch && !pop_enable && serdes_rcvdclk_counter == 0)  recvdclk_stopped <= #TP 1'b1; else
  if (bit_time_lock)                                              recvdclk_stopped <= #TP 1'b0; else
                                                                  recvdclk_stopped <= #TP recvdclk_stopped;
end

//=============================================================================
// Deserializer
//=============================================================================
int        wordlen;
int        delta;
realtime   half_period;
reg [9:0]  rxdata_10b_int; 
reg recvdclk_div2;
reg recvdclk_div4;
reg recvdclk_div8;
reg recvdclk_div16;


assign     wordlen = (rate > 1) ? 8 : 10;

always @(rxbitclk or negedge rst_n)
  if (!rst_n)                                   pop_enable <= #TP 1'b0; else
  if (!align_en)                                pop_enable <= #TP 1'b0; else
  if (rx_q.size() > wordlen)                    pop_enable <= #TP 1'b1; else 
  if (rx_q.size() == 0 && rcvdclk_counter == 0) pop_enable <= #TP 1'b0;
  else                                          pop_enable <= #TP pop_enable;
  
always @(rxbitclk or negedge rst_n)
begin
  if (!rst_n) begin
      half_period <= #TP 40_000*4;
  end else begin
     if (bit_time_lock) begin
     `ifdef GPHY_ESM_SUPPORT
      if (esm_enable && current_rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT)  half_period <= #TP bit_time*4; else  
      if (esm_enable && current_rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT) half_period <= #TP bit_time*4; else   
      if (esm_enable && current_rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT) half_period <= #TP bit_time*4; else   
      if (esm_enable && current_rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT) half_period <= #TP bit_time*4; else   
      `endif// GPHY_ESM_SUPPORT
      if (current_rate === 5) half_period <= #TP bit_time*4; else 
      if (current_rate === 4) half_period <= #TP bit_time*4; else 
      if (current_rate === 3) half_period <= #TP bit_time*4; else 
      if (current_rate === 2) half_period <= #TP bit_time*4; else 
      if (current_rate === 1) half_period <= #TP bit_time*5; else 
                              half_period <= #TP bit_time*5;
     
     
     
     end else begin
        half_period <= #TP half_period;
     end 
  
  end
    
end  
                                    
always begin : create_symbol_recvdclk
   if (!rst_n) begin
     recvdclk = 1'b1;
     rxdata_10b_int = 10'b0;
     #1ns ;
   end else
   if ( !recvdclk_stopped ) 
   begin
      recvdclk = 1'b1;
      #(half_period);
      
      for (int i=0; i< wordlen ; i=i+1) 
          rxdata_10b_int[i] = (pop_enable && rx_q.size() > 0) ? rx_q.pop_front()^int_rxpolarity : 1'b0;
      
      recvdclk = 1'b0;
      // get the last calculated drift
      
      // currently for serdes arch we do not use the drift
      // when refclk deviaiton is close to 2800ppm if we add jitter we might exceed the maximum clk period
      // to be removed after SSC is implemented
      delta = ( rxsymclk_random_drift_en && !serdes_arch) ? rnd_delta.getValue() : 0;
      #(half_period+delta);
   end else begin
     recvdclk = 1'b1;
     rxdata_10b_int = 10'b0;
     #1ns;
   end   
end

// divide recvdclk by 2
always @(posedge recvdclk or negedge rst_n)
begin
   if (!rst_n) begin
      recvdclk_div2 = 1'b1;
      #1ns ;
   end else begin
      recvdclk_div2 = !recvdclk_div2;
   end
end

// divide recvdclk by 4
always @(posedge recvdclk_div2 or negedge rst_n)
begin
   if (!rst_n) begin
      recvdclk_div4 = 1'b1;
      #1ns ;
   end else begin
      recvdclk_div4 = !recvdclk_div4;
   end
end

// divide recvdclk by 8
always @(posedge recvdclk_div4 or negedge rst_n)
begin
   if (!rst_n) begin
      recvdclk_div8 = 1'b1;
      #1ns ;
   end else begin
      recvdclk_div8 = !recvdclk_div8;
   end
end

// divide recvdclk by 16
always @(posedge recvdclk_div8 or negedge rst_n)
begin
   if (!rst_n) begin
      recvdclk_div16 = 1'b1;
      #1ns ;
   end else begin
      recvdclk_div16 = !recvdclk_div16;
   end
end

// sync the selection for clk on the negedge of fastest clk and all other clks are in 0
always @(posedge recvdclk or negedge rst_n or rxwidth)
begin
   if (!rst_n)                                                                              rxwidth_sync <= #TP rxwidth; else
   if (recvdclk_stopped)                                                                    rxwidth_sync <= #TP rxwidth; else
                                                                                            rxwidth_sync <= #TP rxwidth_sync;
        
end  


assign recvdclk_pipe = !serdes_arch  ? recvdclk :
                          (rxwidth_sync == 0 ? recvdclk :
                           rxwidth_sync == 1 ? recvdclk_div2 :
                           rxwidth_sync == 2 ? recvdclk_div4 :
                           rxwidth_sync == 3 ? recvdclk_div8 : recvdclk_div16
                          ); 

//=============================================================================
// Register aligned RX data -- swizzle at this point for proper ordering from
// the wire.
//=============================================================================
 
always @(posedge recvdclk or negedge rst_n)
begin
  if (!rst_n)  begin
     rxdata_10b       <= #TP '0;
     serdes_rx_valid  <= #TP 0; 
  end else if (!align_en)   begin
     rxdata_10b       <= #TP '0;
     serdes_rx_valid  <= #TP 0;
  end else if (bit_time_lock && pop_enable)   begin 
     rxdata_10b       <= #TP rxdata_10b_int;
     serdes_rx_valid  <= #TP 1'b1;   
  end else  begin
     rxdata_10b       <= #TP rxdata_10b;
     serdes_rx_valid  <= #TP 1'b0;
  end
end

// ========================================================================
// Synchronize the pma reset signal into the receive clock domain.
// ========================================================================   
reg    sync_rcvdrst_n_r1;          // needed to retime reset to RX domain
reg    sync_rcvdrst_n_r2;          // needed to retime reset to RX domain

assign rcvdrst_n = (sync_rcvdrst_n_r2 & rst_n); // async assert; synch deassert

always @(posedge recvdclk or negedge rst_n)
    if (!rst_n) begin
        sync_rcvdrst_n_r1   <= #TP 1'b0;          // reset when "reset"
        sync_rcvdrst_n_r2   <= #TP 1'b0;          // reset when "reset"
    end else begin
        sync_rcvdrst_n_r1   <= #TP rst_n;
        sync_rcvdrst_n_r2   <= #TP sync_rcvdrst_n_r1;
    end   
   
endmodule: DWC_pcie_gphy_deser

