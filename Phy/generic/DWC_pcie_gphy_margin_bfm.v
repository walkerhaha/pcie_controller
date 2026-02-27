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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_margin_bfm.v#3 $
// -------------------------------------------------------------------------
// --- Description: Margining at the receiver PIPE model
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_margin_bfm
#(
    parameter TP              = 0,
    parameter WIDTH_WD        = 0,
    parameter RXSB_WD         = 1,
    // constants
    parameter pNO_COMMAND     = 3'b000,
    parameter pSTATUS_NOCMD   = 2'b00,
    parameter pSTATUS_SETUP   = 2'b01,
    parameter pSTATUS_MARGIN  = 2'b10,
    parameter pSTATUS_NAK     = 2'b11,
    parameter pBITS_WIDTH     = 43,  // 3*log2(number_of_bits_margined)={7{1'b1}} => 2^(127/3) => 42.3333
    parameter pFIXED_MODE     = 2'b00,
    parameter pPERIOD_MODE    = 2'b01,
    parameter pBER_MODE       = 2'b10
) (
input                         pclk,
input                         phy_rst_n,
input                         random_margin_status_en,      // margin_status random enable
input       [7:0]             fixed_margin_status_thr,      // margin_status fixed delay
input                         VoltageSupported,             // RXMarginingVoltageSupported
input                         IndErrorSampler,              // RXMarginingIndependentErrorSampler
input       [6:0]             MaxVoltageOffset,             // RXMarginingMaxVoltageOffset
input       [5:0]             MaxTimingOffset,              // RXMarginingMaxTimingOffset
input       [6:0]             UnsupportedVoltageOffset,

input                         SampleReportingMethod,        // RXMarginingSampleReportingMethod
input       [2:0]             mac_phy_rate,                 // data rate
input       [WIDTH_WD-1:0]    mac_phy_width,                // pipe width: 0 = 1s; 1 = 2s; 2 = 4s; 3 = 8s
input       [RXSB_WD-1:0]     phy_mac_rxstartblock,         // RxStartBlock
// From phy_reg
input                         phy_reg_margin_sampl_cnt_clr,
input                         phy_reg_margin_error_cnt_clr,
input                         phy_reg_margin_voltage_or_timing,
input                         phy_reg_margin_start,
input                         phy_reg_margin_left_right,
input                         phy_reg_margin_up_down,
input       [6:0]             phy_reg_margin_offset,

output  reg                   phy_mac_margin_status,        // MarginStatus
output  reg                   phy_mac_margin_nak,           // Nak
output  reg [1:0]             phy_mac_margin_respinfo,      // Information for phy_mac_margin_status/phy_mac_margin_nak
                                                            // 00 : IDLE
                                                            // 01 : Response for StartMargin
                                                            // 10 : Response for OffsetChange
                                                            // 11 : Response for StopMargin)
output  reg                   phy_mac_margin_cnt_updated,   // To send PIPE Message for ErrorCount/SampleCount
output  reg [6:0]             phy_mac_margin_sampl_cnt,     // MarginSampleCount[6:0]
output  reg [5:0]             phy_mac_margin_error_cnt,     // MarginErrorCount[5:0]
// For Task
input       [1:0]             margin_error_cnt_mode,
input       [31:0]            margin_cycle_for_an_error,
input       [3:0]             margin_bit_error_rate_factor,
input       [1:0]             set_margin_cnt,
input       [6:0]             margin_sampl_cnt_to_set,
input       [5:0]             margin_error_cnt_to_set
);

// Parameters Advertised in PHY Datasheet for Lane Margining
// RXMarginingVoltageSupported            : As VoltageSupported
// RXMarginingSamplingRateVoltage[5:0]    : Not used
// RXMarginingSamplingRateTiming[5:0]     : Not used
// RXMarginingIndependentLeftRight        : Not used
// RXMarginingIndependentUpDown           : Not used
// RXMarginingIndependentErrorSampler     : As IndErrorSampler
// RXMarginingVoltageSteps[6:0]           : Not used
// RXMarginingTimingSteps[5:0]            : Not used
// RXMarginingMaxVoltageOffset[6:0]       : As MaxVoltageOffse
// RXMarginingMaxTimingOffset[6:0]        : As MaxTimingOffset
// RXMarginingMaxLanes[4:0]               : Not used
// RXMarginingSampleReportingMethod       : As SampleReportingMethod
// RXMarginingMaxTimingOffsetChange[6:0]  : Not used
// RXMarginingMaxVoltageOffsetChange[6:0] : Not used
// RXMessageBusWriteBufferDepth[3:0]      : Not used
// TXMessageBusMinWriteBufferDepth[3:0]   : Not used

//////////////////////////////////////////////////
// state[1:0]
//////////////////////////////////////////////////
reg         [6:0]             phy_mac_margin_sampl_cnt_1d;
reg         [5:0]             phy_mac_margin_error_cnt_1d;
reg                           phy_reg_margin_voltage_or_timing_1d;
reg                           phy_reg_margin_start_1d;
reg                           phy_reg_margin_up_down_1d;
reg                           phy_reg_margin_left_right_1d;
reg     [6:0]                 margin_offset_1d;
wire                          margin_start;
wire                          margin_offset_change;
wire                          margin_stop;
wire    [7:0]                 margin_timer_thr;
wire    [7:0]                 margin_timer_lo_rnd; // low limit for randomization - before scaling
wire    [7:0]                 margin_timer_hi_rnd; // high limit for randomization - before scaling
reg                           margin_start_timer_en;
reg                           margin_offset_timer_en;
reg                           margin_stop_timer_en;
wire                          margin_start_timer_exp;
wire                          margin_offset_timer_exp;
wire                          margin_stop_timer_exp;

reg     [1:0]                 next_state;
reg     [1:0]                 state;
reg                           auto_cnt_clr;
reg                           nak_condition;

always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        phy_reg_margin_voltage_or_timing_1d <= #TP 1'b0;
        phy_reg_margin_start_1d             <= #TP 1'b0;
        phy_reg_margin_up_down_1d           <= #TP 1'b0;
        phy_reg_margin_left_right_1d        <= #TP 1'b0;
        margin_offset_1d                    <= #TP {7{1'b0}};
    end else begin
        phy_reg_margin_voltage_or_timing_1d <= #TP phy_reg_margin_voltage_or_timing;
        phy_reg_margin_start_1d             <= #TP phy_reg_margin_start;
        phy_reg_margin_up_down_1d           <= #TP phy_reg_margin_up_down;
        phy_reg_margin_left_right_1d        <= #TP phy_reg_margin_left_right;
        margin_offset_1d                    <= #TP phy_reg_margin_offset;
    end
end

always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        margin_start_timer_en  <= #TP 1'b0;
        margin_offset_timer_en <= #TP 1'b0;
        margin_stop_timer_en   <= #TP 1'b0;
    end else begin
        margin_start_timer_en  <= #TP (margin_start)            ? 1'b1 :
                                      (margin_start_timer_exp)  ? 1'b0 : margin_start_timer_en;
        margin_offset_timer_en <= #TP (margin_offset_change)    ? 1'b1 :
                                      (margin_offset_timer_exp) ? 1'b0 : margin_offset_timer_en;
        margin_stop_timer_en   <= #TP (margin_stop)             ? 1'b1 :
                                      (margin_stop_timer_exp)   ? 1'b0 : margin_stop_timer_en;
    end
end

assign margin_start         = (state==pSTATUS_NOCMD) ? (phy_reg_margin_start==1) : 1'b0 ;

assign margin_offset_change = (state==pSTATUS_NOCMD)  ?                                      1'b0 : // pSTATUS_MARGIN||pSTATUS_NAK.
                              (state==pSTATUS_SETUP)  ?                                      1'b0 : // pSTATUS_MARGIN||pSTATUS_NAK.
                              (margin_stop)           ?                                      1'b0 : // Margin Offset is changed when Margin Stop process is not executed.
                              (margin_stop_timer_en)  ?                                      1'b0 :
                                                        (margin_offset_1d!=phy_reg_margin_offset) ;

assign margin_stop          = (state==pSTATUS_MARGIN) ? (phy_reg_margin_start_1d==1 && phy_reg_margin_start==0) :
                              (state==pSTATUS_NAK)    ? (phy_reg_margin_start_1d==1 && phy_reg_margin_start==0) : 1'b0 ;

// Emulate processing time to phystatus
// set the fixed threshold
localparam MIN_MARGIN_PHYSTATUS_RET_DLY = 8;
localparam MAX_MARGIN_PHYSTATUS_RET_DLY = 100;

assign margin_timer_thr     = (random_margin_status_en) ? MIN_MARGIN_PHYSTATUS_RET_DLY : fixed_margin_status_thr;
assign margin_timer_lo_rnd  = (random_margin_status_en) ? MIN_MARGIN_PHYSTATUS_RET_DLY : fixed_margin_status_thr;
assign margin_timer_hi_rnd  = (random_margin_status_en) ? MAX_MARGIN_PHYSTATUS_RET_DLY : fixed_margin_status_thr;

DWC_pcie_gphy_timer #(
  .WD        (8),
  .TP        (TP)
) margin_start_timer (
  .clk       (pclk),
  .rst_n     (phy_rst_n),
  .start     (margin_start),
  .thr       (margin_timer_thr),
  .rnd_en    (random_margin_status_en),
  .rnd_lo    (margin_timer_lo_rnd),
  .rnd_hi    (margin_timer_hi_rnd),
  .expired   (margin_start_timer_exp)
);

DWC_pcie_gphy_timer #(
  .WD        (8),
  .TP        (TP)
) margin_offset_timer (
  .clk       (pclk),
  .rst_n     (phy_rst_n),
  .start     (margin_offset_change),
  .thr       (margin_timer_thr),
  .rnd_en    (random_margin_status_en),
  .rnd_lo    (margin_timer_lo_rnd),
  .rnd_hi    (margin_timer_hi_rnd),
  .expired   (margin_offset_timer_exp)
);

DWC_pcie_gphy_timer #(
  .WD        (8),
  .TP        (TP)
) margin_stop_timer (
  .clk       (pclk),
  .rst_n     (phy_rst_n),
  .start     (margin_stop),
  .thr       (margin_timer_thr),
  .rnd_en    (random_margin_status_en),
  .rnd_lo    (margin_timer_lo_rnd),
  .rnd_hi    (margin_timer_hi_rnd),
  .expired   (margin_stop_timer_exp)
);

always @(*) begin
    case (state)
        pSTATUS_NOCMD : begin
            if(margin_start) begin
              next_state = pSTATUS_SETUP;
            end else begin
              next_state = pSTATUS_NOCMD;
            end
        end
        pSTATUS_SETUP : begin
            if((margin_start_timer_en  && margin_start_timer_exp)
            || (margin_offset_timer_en && margin_offset_timer_exp)
            ) begin
              if(nak_condition) next_state = pSTATUS_NAK;
              else              next_state = pSTATUS_MARGIN;
            end else begin
              next_state = pSTATUS_SETUP;
            end
        end
        pSTATUS_MARGIN : begin
            if(margin_stop_timer_en && margin_stop_timer_exp) begin
              next_state = pSTATUS_NOCMD;
            end else if(margin_offset_change) begin
              next_state = pSTATUS_SETUP;
            end else begin
              next_state = pSTATUS_MARGIN;
            end
        end
        pSTATUS_NAK : begin
            if(margin_stop_timer_en && margin_stop_timer_exp) begin
              next_state = pSTATUS_NOCMD;
            end else if(margin_offset_change) begin
              next_state = pSTATUS_SETUP;
            end else begin
              next_state = pSTATUS_NAK;
            end
        end
        default: begin
            next_state = pSTATUS_NOCMD;
        end
    endcase
end

always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        state <= #TP pSTATUS_NOCMD;
    end else begin
        state <= #TP next_state;
    end
end

always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        auto_cnt_clr <= #TP 1'b0;
    end else begin
      if(!`GPHY_IS_PIPE_44) begin
        if((margin_start_timer_en  && margin_start_timer_exp)
        || (margin_offset_timer_en && margin_offset_timer_exp)
        ) begin
            auto_cnt_clr <= #TP 1'b1;
        end else if(margin_stop_timer_en && margin_stop_timer_exp) begin
            auto_cnt_clr <= #TP 1'b0;
        end else begin
            auto_cnt_clr <= #TP 1'b0;
        end
      end
    end
end

always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        nak_condition <= #TP 1'b0;
    end else begin
      if(`GPHY_IS_PIPE_44) begin
        if(state == pSTATUS_SETUP && (
          (phy_reg_margin_voltage_or_timing==0 && !VoltageSupported)        // Invalid Start Margin(Voltage) when RXMarginingVoltageSupported==0
        ||(phy_reg_margin_voltage_or_timing==0 && phy_reg_margin_offset < MaxVoltageOffset && phy_reg_margin_offset == UnsupportedVoltageOffset) // Invalid offset that is inside the supported range(Voltage)
        )) begin
            nak_condition <= #TP 1'b1;
        end else if(state == pSTATUS_NAK) begin
            nak_condition <= #TP 1'b0;
        end
      end
    end
end

always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        phy_mac_margin_status   <= #TP 1'b0;
        phy_mac_margin_nak      <= #TP 1'b0;
    end else begin
        if(margin_start_timer_en  && margin_start_timer_exp) begin
            phy_mac_margin_status   <= #TP ~nak_condition;
            phy_mac_margin_nak      <= #TP  nak_condition;
         end else if(margin_offset_timer_en && margin_offset_timer_exp) begin
            phy_mac_margin_status   <= #TP ~nak_condition;
            phy_mac_margin_nak      <= #TP  nak_condition;
         end else if(margin_stop_timer_en && margin_stop_timer_exp) begin
            phy_mac_margin_status   <= #TP 1'b1;
            phy_mac_margin_nak      <= #TP 1'b0;
        end else begin
            phy_mac_margin_status   <= #TP 1'b0;
            phy_mac_margin_nak      <= #TP 1'b0;
        end
    end
end

always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        phy_mac_margin_respinfo <= #TP 2'b00;
    end else begin
      if(margin_start_timer_en  && margin_start_timer_exp) begin
          phy_mac_margin_respinfo <= #TP 2'b01;
       end else if(margin_offset_timer_en && margin_offset_timer_exp) begin
          phy_mac_margin_respinfo <= #TP 2'b10;
       end else if(margin_stop_timer_en && margin_stop_timer_exp) begin
          phy_mac_margin_respinfo <= #TP 2'b11;
      end else begin
          phy_mac_margin_respinfo <= #TP 2'b00;
      end
    end
end

//////////////////////////////////////////////////
// phy_mac_margin_cnt_updated
//////////////////////////////////////////////////
// ClearError           Independent  Ack -> SampleCount=current -> ErrorCount=0
// ClearError           Dependent    N/A
// CountUpdate          Independent  SampleCount=current -> ErrorCount=current
// CountUpdate          Dependent    N/A
always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        phy_mac_margin_cnt_updated <= #TP 1'b0;
    end else begin
        if(
            (IndErrorSampler==1 && SampleReportingMethod==0 && phy_mac_margin_sampl_cnt!=phy_mac_margin_sampl_cnt_1d && phy_mac_margin_sampl_cnt!={7{1'b0}})
         || (IndErrorSampler==1 && SampleReportingMethod==0 && phy_reg_margin_sampl_cnt_clr && (state==pSTATUS_MARGIN))
         || (IndErrorSampler==1                             && phy_mac_margin_error_cnt!=phy_mac_margin_error_cnt_1d && phy_mac_margin_error_cnt!={6{1'b0}})
         || (IndErrorSampler==1                             && phy_reg_margin_error_cnt_clr && (state==pSTATUS_MARGIN))
        ) begin
            phy_mac_margin_cnt_updated <= #TP 1'b1;
        end else begin
            phy_mac_margin_cnt_updated <= #TP 1'b0;
        end
    end
end

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        phy_mac_margin_sampl_cnt_1d <= #TP {7{1'b0}};
        phy_mac_margin_error_cnt_1d <= #TP {6{1'b0}};
    end else begin
        phy_mac_margin_sampl_cnt_1d <= #TP phy_mac_margin_sampl_cnt;
        phy_mac_margin_error_cnt_1d <= #TP phy_mac_margin_error_cnt;
    end
end

//////////////////////////////////////////////////
// phy_mac_margin_sampl_cnt[6:0]
//////////////////////////////////////////////////
reg     [pBITS_WIDTH-1:0]     number_of_bits_per_cycle;
reg     [pBITS_WIDTH-1:0]     number_of_bits_margined;
reg     [pBITS_WIDTH-1:0]     number_of_bits_margined_wire;
reg     [pBITS_WIDTH*3-1:0]   number_of_bits_margined_wire_calc;
reg     [6:0]                 phy_mac_margin_sampl_cnt_wire;

always @(*) begin
    // pipe width: 0 = 1s; 1 = 2s; 2 = 4s; 3 = 8s
         if(mac_phy_width==1) begin // 2s
        number_of_bits_per_cycle = 16;
    end else if(mac_phy_width==2) begin // 4s
        number_of_bits_per_cycle = 32;
    end else if(mac_phy_width==3) begin // 8s
        number_of_bits_per_cycle = 64;
    end else if(mac_phy_width==4) begin // 16s
        number_of_bits_per_cycle = 128;
    end else begin
        number_of_bits_per_cycle = 8;
    end
end
always @(*) begin
    if(auto_cnt_clr || phy_reg_margin_sampl_cnt_clr || (IndErrorSampler==0) ) begin
        number_of_bits_margined_wire = {pBITS_WIDTH{1'b0}};
    end else if(state==pSTATUS_MARGIN && phy_mac_rxstartblock!=0) begin // The RxSyncHeader Timing
        number_of_bits_margined_wire = number_of_bits_margined + number_of_bits_per_cycle + 2;
    end else if(state==pSTATUS_MARGIN) begin
        number_of_bits_margined_wire = number_of_bits_margined + number_of_bits_per_cycle;
    end else begin
        number_of_bits_margined_wire = number_of_bits_margined;
    end
end

always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        number_of_bits_margined <= #TP {pBITS_WIDTH{1'b0}};
    end else begin
        if(auto_cnt_clr || phy_reg_margin_sampl_cnt_clr || (IndErrorSampler==0) ) begin
            number_of_bits_margined <= #TP {pBITS_WIDTH{1'b0}};
        end else if(number_of_bits_margined > number_of_bits_margined_wire) begin
            number_of_bits_margined <= #TP {pBITS_WIDTH{1'b1}};
        end else begin
            number_of_bits_margined <= #TP number_of_bits_margined_wire;
        end
    end
end

assign number_of_bits_margined_wire_calc = number_of_bits_margined_wire * number_of_bits_margined_wire * number_of_bits_margined_wire;

always @(*) begin
    phy_mac_margin_sampl_cnt_wire = {7{1'b0}};
    for(int bit_i=128; bit_i>0; bit_i=bit_i-1) begin
        if(number_of_bits_margined_wire_calc[bit_i]) begin
            phy_mac_margin_sampl_cnt_wire = (bit_i==128) ? 127 : bit_i;
            bit_i=0;
        end
    end
end

// Used only when IndErrorSampler=1 and SampleReportingMethod=0.
always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        phy_mac_margin_sampl_cnt <= #TP {7{1'b0}};
    end else begin
        if( !(IndErrorSampler==1 && SampleReportingMethod==0) ) begin // not to be used
            phy_mac_margin_sampl_cnt <= #TP {7{1'b0}};
        end else if(set_margin_cnt[1]) begin
            phy_mac_margin_sampl_cnt <= #TP margin_sampl_cnt_to_set;
        end else begin
            phy_mac_margin_sampl_cnt <= #TP phy_mac_margin_sampl_cnt_wire;
        end
    end
end

//////////////////////////////////////////////////
// phy_mac_margin_error_cnt[5:0]
//////////////////////////////////////////////////
reg  [31:0]  margin_period_cnt;
reg  [63:0]  ber_denominator;
reg  [63:0]  random_value[128];
reg  [5:0]   error_cnt_adding_factor;
reg  [5+1:0] phy_mac_margin_error_cnt_wire;

always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        margin_period_cnt <= #TP {32{1'b0}};
    end else begin
        if(margin_error_cnt_mode!=pPERIOD_MODE || (state!=pSTATUS_MARGIN) || (margin_period_cnt==margin_cycle_for_an_error)) begin
            margin_period_cnt <= #TP {32{1'b0}};
        end else if(phy_reg_margin_error_cnt_clr || auto_cnt_clr) begin
            margin_period_cnt <= #TP {32{1'b0}};
        end else begin
            margin_period_cnt <= #TP margin_period_cnt+32'h0000_0001;
        end
    end
end

assign ber_denominator=(10**margin_bit_error_rate_factor); // (10^(margin_bit_error_rate_factor))

genvar bit_j;
generate
for (bit_j = 0; bit_j<128; bit_j = bit_j + 1) begin : gen_random_value
    wire [63:0]  debug_random_value;
    always @(posedge pclk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            random_value[bit_j] <= #TP {64{1'b0}};
        end else begin
            random_value[bit_j] <= #TP $random;
        end
    end
    assign debug_random_value = random_value[bit_j];
end // for
endgenerate

always @(*) begin
    error_cnt_adding_factor={6{1'b0}};
    if(next_state==pSTATUS_MARGIN) begin
        if(margin_error_cnt_mode==pFIXED_MODE) begin
          error_cnt_adding_factor = 6'b00_0000;
        end
        if(margin_error_cnt_mode==pPERIOD_MODE) begin
          error_cnt_adding_factor = (margin_period_cnt==margin_cycle_for_an_error) ? 6'b00_0001 : 6'b00_0000;
        end
        // Bit Error Rate Modeling Mode(10^-(margin_bit_error_rate_factor))
        if(margin_error_cnt_mode==pBER_MODE) begin
            for(int bit_i=0; bit_i<number_of_bits_per_cycle; bit_i=bit_i+1) begin
                if( (random_value[bit_i] % ber_denominator)==1 ) begin
                    error_cnt_adding_factor=error_cnt_adding_factor+6'b00_0001;
                end
            end
        end
    end
end
always @(*) begin
    if(phy_reg_margin_offset=={7{1'b0}}) begin
        phy_mac_margin_error_cnt_wire = phy_mac_margin_error_cnt;
    end else begin
        phy_mac_margin_error_cnt_wire = phy_mac_margin_error_cnt + error_cnt_adding_factor;
    end
end

// Used only when IndErrorSampler=1.
always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        phy_mac_margin_error_cnt <= #TP {6{1'b0}};
    end else begin
        if(phy_reg_margin_error_cnt_clr || auto_cnt_clr) begin
            phy_mac_margin_error_cnt <= #TP {6{1'b0}};
        end else if( !(IndErrorSampler==1) ) begin // not to be used
            phy_mac_margin_error_cnt <= #TP {6{1'b0}};
        end else if(set_margin_cnt[0]) begin
            phy_mac_margin_error_cnt <= #TP margin_error_cnt_to_set;
        end else if(phy_mac_margin_error_cnt_wire[6]) begin
            phy_mac_margin_error_cnt <= #TP {6{1'b1}};
        end else begin
            phy_mac_margin_error_cnt <= #TP phy_mac_margin_error_cnt_wire;
        end
    end
end

// -------------------------------------------------------------------------
wire    [(34*8)-1:0]          MARGIN_STATE;
assign MARGIN_STATE = ( state == pSTATUS_NOCMD   ) ? "No Command"                :
                      ( state == pSTATUS_SETUP   ) ? "Setup for margin"          :
                      ( state == pSTATUS_MARGIN  ) ? "Margining in progress"     :
                      ( state == pSTATUS_NAK     ) ? "Nak"                       : "UNKNOWN";
wire    [(34*8)-1:0]          ERROR_CNT_STATE;
assign ERROR_CNT_STATE = ( margin_error_cnt_mode == pFIXED_MODE  ) ? "Fixed Value Mode"              :
                         ( margin_error_cnt_mode == pPERIOD_MODE ) ? "Periodical Increment Mode"     :
                         ( margin_error_cnt_mode == pBER_MODE    ) ? "Bit Error Rate Modeling Mode"  : "UNKNOWN";

endmodule // pipe_margin_bfm
