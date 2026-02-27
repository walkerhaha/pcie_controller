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
// ---    $DateTime: 2020/06/26 01:14:06 $
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pmu.v#16 $
// -------------------------------------------------------------------------
// --- Module Description:  Generic PHY power management unit
// -----------------------------------------------------------------------------
// --- This module is responsible for the control of PHY isolation, power, and
// --- reset sequences when the PHY supports power gating. The module
// --- performs power gating operations based upon the decode of the powerdown signal
// --- from the MAC.
// -----------------------------------------------------------------------------

module DWC_pcie_gphy_pmu #(
  parameter TP = 0,
  parameter NL = 0,
  parameter TXEI_WD = 0
) (
  input                  power_on_rst_n,
  input                  phy_dig_rst_n,
  input                  perst_n,
  input                  refclk,
  input [3:0]            powerdown,
  input [NL-1:0]         phy_mac_phystatus,
  input [NL*TXEI_WD-1:0] mac_phy_txelecidle,
  input [NL-1:0]         mac_phy_txcompliance,
  input [NL-1:0]         serdes_pipe_turnoff_lanes,
  input                  serdes_arch,
  output reg             phy_pmu_en_iso_n_r
);

localparam  S_RESET = 3'b000;
localparam  S_P0 = 3'b001;
localparam  S_P1 = 3'b010;
localparam  S_P2 = 3'b011;
localparam  S_ISOLATE = 3'b100;

reg [2:0]   int_pmu_state_r;
reg [2:0]   int_pmu_state_s;
reg [3:0]   int_current_pd_p2_r;
reg         int_current_pd_p1_r;
reg         int_pd_override_r;
wire        int_current_pd_p1_s;
wire        int_current_pd_p2_s;
reg         int_pd_override_s;

wire        int_set_pd_override_s;
wire        int_clear_pd_override_s;

reg [3:0]    current_powerdown;
reg [NL-1:0] collect_phystatus;
reg [NL-1:0] all_phystatus_dropped;
reg [NL-1:0] all_phystatus_dropped_r;


logic [NL-1:0]  int_mac_phy_txelecidle;
always_comb begin: int_mac_phy_txelecidle_PROC
  for(int i = 0; i < NL; i++) begin
    int_mac_phy_txelecidle[i] = mac_phy_txelecidle[TXEI_WD*i];
  end
end

wire [NL-1:0] disabled_lanes;
assign disabled_lanes = serdes_arch ? serdes_pipe_turnoff_lanes : int_mac_phy_txelecidle & mac_phy_txcompliance;

wire int_perst_n;
reg [2:0] perst_n_sync;
always_ff@(posedge refclk or negedge power_on_rst_n)
begin
  integer i;
  if (!power_on_rst_n)
    perst_n_sync <= #TP '0;
  else begin
    perst_n_sync[0] <= #TP perst_n;
    for(i=1; i<3; i=i+1) begin
      perst_n_sync[i] <= #TP perst_n_sync[i-1];
    end
  end
end
assign int_perst_n = perst_n_sync[2];

always @(posedge refclk or negedge power_on_rst_n or phy_mac_phystatus)
begin
    if(!power_on_rst_n)
        collect_phystatus <= #TP '0;
    else if (collect_phystatus != {NL{1'b1}} && powerdown != current_powerdown)
        collect_phystatus <= #TP collect_phystatus | phy_mac_phystatus | disabled_lanes;
    else if (all_phystatus_dropped)
        collect_phystatus <= #TP '0;
    else if (all_phystatus_dropped == {NL{1'b0}} && all_phystatus_dropped_r != {NL{1'b0}})
        collect_phystatus <= #TP '0;
end


always @(posedge refclk or negedge power_on_rst_n)
begin
    if(!power_on_rst_n)
        all_phystatus_dropped <= #TP '0;
    else if (collect_phystatus == {NL{1'b1}})
        all_phystatus_dropped <= #TP collect_phystatus;
    else
        all_phystatus_dropped <= #TP all_phystatus_dropped & phy_mac_phystatus & ~disabled_lanes;
end

always @(posedge refclk or negedge power_on_rst_n)
begin
    if(!power_on_rst_n)
        all_phystatus_dropped_r <= #TP '0;
    else
        all_phystatus_dropped_r <= #TP all_phystatus_dropped;
end

always @(posedge refclk or negedge power_on_rst_n)
begin
    if(!power_on_rst_n)
        current_powerdown <= #TP `GPHY_PDOWN_P1;
    else if (all_phystatus_dropped == {NL{1'b0}} && all_phystatus_dropped_r != {NL{1'b0}})
        current_powerdown <= #TP powerdown;
    else
        current_powerdown <= #TP current_powerdown;
end



always_ff@(posedge refclk or negedge power_on_rst_n)
begin
    if(!power_on_rst_n)
        int_pmu_state_r <= S_RESET;
    else
        int_pmu_state_r <= #TP int_pmu_state_s;
end

always @(*)
begin
    int_pmu_state_s = S_RESET;
    case(int_pmu_state_r)
        S_RESET : begin
            if( int_perst_n && ((powerdown == `GPHY_PDOWN_P1) || !phy_dig_rst_n))
                int_pmu_state_s = S_P1;
            else
                int_pmu_state_s = S_RESET;
        end
        S_P0 : begin
            if(powerdown == `GPHY_PDOWN_P1)
                int_pmu_state_s = S_P1;
            else if(current_powerdown inside { `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON})
                int_pmu_state_s = S_P2;
            else
                int_pmu_state_s = S_P0;
        end
        S_P1 : begin
            if(powerdown == `GPHY_PDOWN_P0)
                int_pmu_state_s = S_P0;
            else if(current_powerdown inside { `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON})
                int_pmu_state_s = S_P2;
            else
                int_pmu_state_s = S_P1;
        end
        S_P2 : begin
            if(powerdown == `GPHY_PDOWN_P0)
                int_pmu_state_s = S_P0;
            else if(powerdown == `GPHY_PDOWN_P1)
                int_pmu_state_s = S_P1;
            // this is the fix for the phy to isolate at p2 entry only when the phy has ended the maxpclkreq handshake    
            else if(int_current_pd_p2_r[3] && !int_pd_override_r && !int_perst_n)
                int_pmu_state_s = S_ISOLATE;
            else
                int_pmu_state_s = S_P2;
        end
        S_ISOLATE : begin
           if (!int_perst_n)
             int_pmu_state_s = S_ISOLATE;
           else
             int_pmu_state_s = S_RESET;
        end
        default : begin
            int_pmu_state_s = S_RESET;
        end
    endcase
end

// The PHY powerdown can be overriden from P1 to P2 when the link is in L1 state
// In this case power is not going to be removed therefore the isolation should
// not be enabled
assign int_current_pd_p1_s = (powerdown == `GPHY_PDOWN_P1);
assign int_current_pd_p2_s = (powerdown inside { `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON});

assign int_set_pd_override_s = int_current_pd_p1_r && int_current_pd_p2_s;
assign int_clear_pd_override_s = !(powerdown inside { `GPHY_PDOWN_P2, `GPHY_PDOWN_P2_NOBEACON});

always @(int_set_pd_override_s or int_clear_pd_override_s or int_pd_override_r)
begin
  if(int_set_pd_override_s)
    int_pd_override_s = 1'b1;
  else if(int_clear_pd_override_s)
    int_pd_override_s = 1'b0;
  else
    int_pd_override_s = int_pd_override_r;
end

always @(posedge refclk or negedge power_on_rst_n)
begin
  integer i;
  if(!power_on_rst_n) begin
    int_current_pd_p2_r <= 0;
  end else begin
    int_current_pd_p2_r[0] <= int_current_pd_p2_s;
    for(i=1; i<4; i=i+1) begin
      int_current_pd_p2_r[i] <= int_current_pd_p2_r[i-1];
    end
  end
end

always @(posedge refclk or negedge power_on_rst_n)
begin
  if(!power_on_rst_n)
  begin
    int_current_pd_p1_r <= #TP 1'b0;
    int_pd_override_r   <= #TP 1'b0;
    phy_pmu_en_iso_n_r  <= #TP 1'b0;
  end else begin
    int_current_pd_p1_r <= #TP int_current_pd_p1_s;
    int_pd_override_r <= #TP int_pd_override_s;
    case(int_pmu_state_s)
      S_RESET   : phy_pmu_en_iso_n_r <= #TP !int_perst_n;
      S_P0      : phy_pmu_en_iso_n_r <= #TP 1'b1;
      S_P1      : phy_pmu_en_iso_n_r <= #TP 1'b1;
      S_P2      : phy_pmu_en_iso_n_r <= #TP 1'b1;
      S_ISOLATE : phy_pmu_en_iso_n_r <= #TP 1'b0;
      default   : phy_pmu_en_iso_n_r <= #TP 1'b0;
    endcase
  end
end

endmodule
