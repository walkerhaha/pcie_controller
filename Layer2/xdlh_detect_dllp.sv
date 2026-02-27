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
// ---    $DateTime: 2019/10/03 14:27:33 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_detect_dllp.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description: This module detects a particular type of DLLP
// --- when detected it generates a flag to indicate a match.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xdlh_detect_dllp
  // Parameters
  #(
    parameter NW = `CX_NW,
    parameter DW = `CX_DW,
    parameter INST = 0,
    parameter DLLP_WD = 8,
    parameter PCIE_MODE = `CX_PCIE_MODE,
    parameter MATCH_TYPE = 1'b1
  )
  (
    // Inputs
    input         [DLLP_WD - 1 : 0] dllp_type,          // Any valid DLLP encoding
    input         [NW - 1 : 0]      sdp,                // Indicates which DWORD is SDP
    input         [DW - 1 : 0]      data,               // Data from the Data Link Layer to transmit       
    input         [NW - 1 : 0]      eot,                // 1 bit per dword, indicates which dword is eot
    input         [2:0]             current_data_rate,  // 00 - gen1, 01 - gen2, 10 - gen3, 11 - gen4
    input                           phy_type,           // 0 - PCIE PHY, 1 MPHY this may change SDP encoding
    input                           clk,                // Clock
    input                           rst_n,              // Reset
    input                           halt,               // Halt from layer1
    // Outputs
    output  wire                    dllp_match,         // Indicates DLLP match
    output  reg   [NW - 1 : 0]      dllp_sent           // Indicates that a DLLP has been sent 
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
localparam  P_SDP_8B = 8;
localparam  P_SDP_16B = 16;
parameter   TP = `TP;

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
reg   [NW - 1 : 0]  int_dllp_det_s;
wire  [NW - 1 : 0]  int_dllp_match_s;
reg                 int_eot_next_s;
wire                int_curr_dllp_match_s;
reg                 int_next_dllp_match_s;
wire                int_set_next_dllp_match_s;
wire                int_clear_next_dllp_match_s;

// ----------------------------------------------------------------------------
// Register Declarations
// ----------------------------------------------------------------------------
reg int_next_dllp_match_r;

// ----------------------------------------------------------------------------
// Detect a possible match for DLLP type
// ----------------------------------------------------------------------------
always @(*)
begin
  integer i;
  int_dllp_det_s = {NW{1'b0}};
  for(i = 0; i < NW; i = i + 1)
  begin
    // GEN1/GEN2 SDP is 8-bits wide
    int_dllp_det_s[i] = ((current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE) ?
    (data[i*32 + P_SDP_8B +: DLLP_WD] == dllp_type) :
    // GEN3/GEN4 for selectable PHY with MPCIE SDP is 8-bits wide
    (((PCIE_MODE > 0) && (phy_type == `PHY_TYPE_MPCIE)) ?
    (data[i*32 + P_SDP_8B +: DLLP_WD] == dllp_type) :
    // GEN3/GEN4 CPCIE PHY SDP is 16-bits wide
    (data[i*32 + P_SDP_16B +: DLLP_WD] == dllp_type)));
  end
end

// Confirm a valid DLLP type match by checking that the SDP occurs in the same data double word
assign int_dllp_match_s = MATCH_TYPE ? (int_dllp_det_s & sdp) : sdp;

// ----------------------------------------------------------------------------
// Search for DLLP matches and generate a flag when DLLP END is detected
// ----------------------------------------------------------------------------
always @(*)
begin
  integer i;
  int_eot_next_s = 1'b0;
  for(i = 0; i < NW; i = i + 1)
  begin
    if(int_dllp_match_s[i])
    begin
      // If the DLLP type and SDP is matched in the last DW of the data the eot will be in the next cycle
      if(i == NW - 1)
      begin
        // mask the next eot which is in the first DW of data in the next data packet
        int_eot_next_s = 1'b1;
      end
    end
  end
end

// DLLP SDP and EOT in the same cycle
assign int_curr_dllp_match_s = (!int_eot_next_s && (|int_dllp_match_s)) && !halt;

assign int_set_next_dllp_match_s = int_eot_next_s && !halt;
assign int_clear_next_dllp_match_s = !int_eot_next_s && !halt && eot[0];

always @(*)
begin
  if(int_clear_next_dllp_match_s)
    int_next_dllp_match_s = 1'b0;
  else if(int_set_next_dllp_match_s)
    int_next_dllp_match_s = 1'b1;
  else
    int_next_dllp_match_s = int_next_dllp_match_r;
end

always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
  begin
    int_next_dllp_match_r <= #TP 1'b0;
  end
  else
  begin
    int_next_dllp_match_r <= #TP int_next_dllp_match_s;
  end
end

assign dllp_match = int_curr_dllp_match_s || (int_next_dllp_match_r && int_clear_next_dllp_match_s);

// Create a bus indicating when a DLLP has been transmitted
always @(*)
begin
  integer i;
  dllp_sent = {NW{1'b0}};
   for(i = 0; i < NW; i = i + 1) begin
      if (i == 0) begin
        if (int_next_dllp_match_r)
          dllp_sent[i] =  1'b1; // SDP in last DW of previous cycle => EOT is first DW
        else
          dllp_sent[i + 1] = (int_dllp_match_s[i] && !halt); //  EOT is in DW + 1
      end else if (i < (NW - 1)) begin
        dllp_sent[i + 1] = (int_dllp_match_s[i] && !halt); //  EOT is in DW + 1
      end
    end
end

endmodule
