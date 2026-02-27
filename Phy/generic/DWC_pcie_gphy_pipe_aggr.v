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
// ---    $DateTime: 2019/02/05 05:23:47 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_pipe_aggr.v#9 $
// -------------------------------------------------------------------------
// --- Description: 
// --- * aggregate per-lane output control signals into per-pipe outputs
// --- * distribute per-pipe input control signals into per-lane inputs
// -------------------------------------------------------------------------

module DWC_pcie_gphy_pipe_aggr #(
  parameter TP = 0,
  parameter NL = 1
) (  
  // per-lane outputs --> per-pipe outputs
  // from lower layers
  input  [NL-1:0]   lane_pclkack_n,                // per lane ack that pclk is off  
  input  [NL-1:0]   lane_disabled,
  `ifdef GPHY_ESM_SUPPORT                                       
  input  [NL*7-1:0]        lane_esm_data_rate0,       
  input  [NL*7-1:0]        lane_esm_data_rate1,       
  input  [NL-1:0]          lane_esm_calibrt_req,      
  input  [NL-1:0]          lane_esm_enable,  
  input  [NL-1:0]          lane_command_ack,   
  `endif // GPHY_ESM_SUPPORT                                    
                                                              
  // to PIPE
  `ifdef GPHY_ESM_SUPPORT                                       
  output  [6:0]            pipe_esm_data_rate0,       
  output  [6:0]            pipe_esm_data_rate1,       
  output                   pipe_esm_calibrt_req,      
  output                   pipe_esm_enable,   
  output                   pipe_command_ack,   
  `endif // GPHY_ESM_SUPPORT
  
  output            pipe_pclkack_n,                // global ack that pclk is off 
  output            pipe_ref_clk_req_n,            // global request for refclk
  
  // per-pipe inputs --> per-lane inputs
  // from PIPE 
  `ifdef GPHY_ESM_SUPPORT                                       
  input             pipe_esm_calibrt_complete,          
  `endif // GPHY_ESM_SUPPORT 
  
  input             pipe_txcommonmode_disable,     // global txcommonmode_disalbe req
  input             pipe_rxelecidle_disable,       // global rxelecidle_disable req 
  input  [1:0]      pipe_clkreq_n,                 // global req to turn off pclk
  input  [3:0]      powerdown,                     // powerdown value   
    
  // to lower layers
  `ifdef GPHY_ESM_SUPPORT                                       
  output  [NL-1:0]  lane_esm_calibrt_complete,          
  `endif // GPHY_ESM_SUPPORT 
  output [NL-1:0]   lane_txcommonmode_disable,     // per lane txcommonmode_disalbe req
  output [NL-1:0]   lane_rxelecidle_disable,       // per lane rxelecidle_disable req
  output [NL*2-1:0] lane_clkreq_n                  // per lane clkreq_n req 
);

wire all_lanes_disabled;

assign all_lanes_disabled = &lane_disabled;

`ifdef GPHY_PIPE43_SUPPORT
// confirmation refclk can be gated for Pipe4.3 it is based on Powerdown
// states mapped to L1 sub-states or L2.
assign pipe_ref_clk_req_n  = &lane_pclkack_n;
`else // GPHY_PIPE43_SUPPORT
// Confirmation refclk can be gated for Pipe4.2 can be either based
// on L1 sub-states or L1/L2 CPM with sideband signalling
assign pipe_ref_clk_req_n  = (&lane_pclkack_n);
`endif // !GPHY_PIPE43_SUPPORT

assign lane_txcommonmode_disable        = {NL{pipe_txcommonmode_disable}};
assign lane_rxelecidle_disable          = {NL{pipe_rxelecidle_disable}} | {NL{powerdown == `GPHY_PDOWN_P2_NOBEACON}};

`ifdef GPHY_ESM_SUPPORT 
assign pipe_esm_enable       = &lane_esm_enable;
assign pipe_esm_calibrt_req  = (&lane_esm_calibrt_req) && !all_lanes_disabled;
assign pipe_esm_data_rate0   = lane_esm_data_rate0[6:0];
assign pipe_esm_data_rate1   = lane_esm_data_rate1[6:0];

assign lane_esm_calibrt_complete  = {NL{pipe_esm_calibrt_complete}};

assign pipe_command_ack = & lane_command_ack;  
`endif // GPHY_ESM_SUPPORT


`ifndef GPHY_PIPE43_SUPPORT
assign pipe_pclkack_n                   = ( |pipe_clkreq_n ) ? &lane_pclkack_n : |lane_pclkack_n;
assign lane_clkreq_n                    = {NL{pipe_clkreq_n}};
`else //GPHY_PIPE43_SUPPORT
// decode powerdown into sideband signals
assign lane_clkreq_n             = (powerdown inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2, `GPHY_PDOWN_P1_CPM }) ? {NL{2'b10}} : {NL{2'b00}};
//assign lane_txcommonmode_disable = ((powerdown == `GPHY_PDOWN_P1_2) ? {NL{1'b1}} : {NL{1'b0}}) | {NL{pipe_txcommonmode_disable}};
//assign lane_rxelecidle_disable   = ((powerdown inside {`GPHY_PDOWN_P1_1, `GPHY_PDOWN_P1_2}) ? {NL{1'b1}} : {NL{1'b0}}) | {NL{pipe_rxelecidle_disable}};
`endif //GPHY_PIPE43_SUPPORT

endmodule: DWC_pcie_gphy_pipe_aggr
