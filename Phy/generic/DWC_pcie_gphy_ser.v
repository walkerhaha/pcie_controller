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
// ---  $DateTime: 2019/06/06 16:32:01 $
// ---  $Revision: #14 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_ser.v#14 $
// -------------------------------------------------------------------------
// --- Module Description: serializer (behavioral implementation)
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_ser #(
  parameter TP      = 0                            // Clock to Q delay (simulator insurance)
) (
  input                   refclk,                   // reference clock
  input                   txbitclk,                 // Transmit bit clock
  input                   txclk,                    // Transmit symbol clock
  input                   rst_n,                    // serdes reset input
  input                   serdes_arch,
  input                   elecidle,                 // enable electrical idle
  input                   loopback,
  input                   common_mode_disable,      // disable common mode, lines in Hi-Z
  input   [3:0]           powerdown,                // put transmitter in power down mode
  input                   beacongen,                // enable beacon pattern generation
  input                   txdetectrx,               // request to perform receiver detect sequence
  input   [9:0]           txdata_10b,               // parallel 10b symbol data in
  input   [2:0]           rate,                     // currently selected data rate
  input                   txdatavalid_10b,          // ignore a byte or word on the data interface
  input                   txstartblock_10b,         // first byte of the data interface is the first byte of the block.
  input  [1:0]            txsynchdr_10b,            // sync header to use in the next 130b block

  output reg              rxdetected,               // Receiver detected
  output                  txp,                      // serial data out (positive)
  output                  txn                       // serial data out (negative)
);

timeunit 1ns;
timeprecision 1fs;

//==============================================================================
//
// Very simple serializer emulation used for the generic implementation
//
//==============================================================================
// register data and data flow control signals
reg        elecidle_r;
reg        elecidle_rr;
reg        loopback_r;
reg        loopback_sync_startblock;
reg [9:0]  txdata_10b_r;
reg        txdatavalid_r;

// detect an STP
// this is for debug purpose only
wire       tx_stp_detect;
assign     tx_stp_detect = (((txdata_10b == `GPHY_STP_10B_NEG) | (txdata_10b == `GPHY_STP_10B_POS)) && (rate < 2)); // for gen1/2

// register data flow control signals
reg        txstartblock_r;
reg [1:0]  txsynchdr_r;
wire       elecidle_changed;
wire       rise_txdatavalid;

assign rise_txdatavalid = txdatavalid_10b && !txdatavalid_r;

always @(posedge txclk or negedge rst_n)
begin
    if (!rst_n) begin
      txdata_10b_r      <= #TP 10'bZ;
      elecidle_r        <= #TP 1;
      elecidle_rr       <= #TP 1;
      loopback_r        <= #TP 0;
      txdatavalid_r     <= #TP 0;
      txstartblock_r  <= #TP 0;
      txsynchdr_r     <= #TP 0;
    end else begin
      txdata_10b_r      <= #TP txdata_10b;
      elecidle_r        <= #TP elecidle;
      elecidle_rr       <= #TP elecidle_r;
      loopback_r        <= #TP loopback_sync_startblock;
      txdatavalid_r     <= #TP txdatavalid_10b;
      txstartblock_r    <= #TP txstartblock_10b;
      txsynchdr_r       <= #TP txsynchdr_10b;
      if (rate > 1) begin
         if (txstartblock_10b && rise_txdatavalid)
            loopback_sync_startblock <= #TP loopback;
      end else begin
        loopback_sync_startblock    <= #TP loopback;
      end        
    end
end
//assign elecidle_changed = elecidle ^ elecidle_r;
wire into_elecidle;
wire outof_elecidle;
wire into_loopback;
reg into_elecidle_flag; 

assign into_elecidle  = (elecidle_r ^ elecidle_rr) && elecidle_r;
assign outof_elecidle = (elecidle ^ elecidle_r) && elecidle_r;

assign into_loopback = loopback_sync_startblock && !loopback_r;

// how many bits in a txclk cycle
int  bitnum;
assign bitnum = ( rate inside {1,0} ) ? 10 : 8;

// serialize parallel data into a queue
// note the priority mux to handle pipelined data
// across elecidle transitions
reg tx_q [$];
always @(posedge txclk or negedge rst_n)
begin
   if (!rst_n) begin
     tx_q = {};
     for (int i=0; i<10; i=i+1) begin
        tx_q.push_back(1'bZ);
     end
    end else if (outof_elecidle ) 
    begin
      tx_q = {};
    end
    else if ( (!elecidle_r) || (elecidle_r && !elecidle_rr))
    begin
     if (into_loopback) 
       tx_q = {};  
     if (txdatavalid_r) 
     begin
        if (rate > 1 && txstartblock_r && !serdes_arch) begin
          // send the syncheader
          for (int i=0; i<2; i=i+1) begin
            tx_q.push_back(txsynchdr_r[i]);
          end // for i
        end // txstartblock
        // send the data
        for (int i=0; i<bitnum; i=i+1) begin
          tx_q.push_back(txdata_10b_r[i]);
        end // for i
     end else begin
         // do not push anything as tx_datavalid is 0
     end    
   end
end

reg tx_o;
always @(posedge txclk or negedge rst_n)
begin
   if (!rst_n) begin
     tx_o = 1'bZ;
   end else 
    repeat (bitnum) 
    begin
// Use Bit clock generated from Refclk
      @(txbitclk);
      tx_o = (tx_q.size() > 0        ) ? tx_q.pop_front() :  
             (into_elecidle_flag == 0 && rate > 1) ? 1'b0 : 1'bZ;
    end
end


always  @(posedge txclk or negedge rst_n)
begin
   if (!rst_n)                                            into_elecidle_flag <= 1; else
   if (tx_q.size() > 0)                                   into_elecidle_flag <= 0; else
   if (elecidle && tx_q.size() == 0)                      into_elecidle_flag <= 1; else   
                                                          into_elecidle_flag <= 0;
    
end

// ------------------------------
// drive the serial lines
// ------------------------------
wire txp_val;
wire txn_val;
reg beaconpattern; initial beaconpattern = 1'b1;
always begin: beacon_pattern
   #50ns;
   beaconpattern = ~beaconpattern;
end: beacon_pattern

assign txp_val = (beacongen) ?  beaconpattern : (tx_o === 1'bZ ) ? 1'b0 :  tx_o;
assign txn_val = (beacongen) ? ~beaconpattern : (tx_o === 1'bZ ) ? 1'b0 : ~tx_o;

bufif0 (pull1,pull0) pull_p (txp, txp_val, common_mode_disable);
bufif0 (pull1,pull0) pull_n (txn, txn_val, common_mode_disable);


// --------------------------------------------------
// Simulated receiver detection
// this can be forced from the TB to change the
// result of receiver detection (detected by default)
// --------------------------------------------------
reg sim_rcvr_present; initial sim_rcvr_present = 1'b1;
always @(posedge refclk or negedge rst_n)
    if (!rst_n) begin
        rxdetected  <= #TP 0;
    end else begin
        rxdetected  <= #TP txdetectrx ? sim_rcvr_present : 0;
    end

endmodule

