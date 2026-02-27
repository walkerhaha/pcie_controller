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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/lane_flip.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: 
// --- Container module for all the mux logic for flipping the lanes.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module lane_flip #(
    parameter REGIN = `CX_LANEFLIP_RX_REGIN,
    parameter REGOUT = `CX_LANEFLIP_TX_REGOUT,
    parameter NL = `CX_NL,
    parameter L2NL = NL==1 ? 1 : `CX_LOGBASE2(NL),  // log2 number of NL
    parameter NB = `CX_NB,
    parameter TX_FS_WD   = 6,
    parameter DIRFEEDBACK_WD = 6,
    parameter FOMFEEDBACK_WD = 8,
    parameter TX_COEF_WD = 18,
    parameter RX_PSET_WD = 3,
    parameter TX_PSET_WD = 4
)
(
    // ------------------ Inputs - Controls ------------------   
    input                           core_clk,
    input                           core_clk_ug,
    input                           core_rst_n,
    input  [5:0]                    lane_under_test_i,                 //{cfg_force_lane_flip, enable lane under test, the lane_under_test[3:0]}
    input  [L2NL-1:0]               pm_rx_lane_flip_en, 
    input  [L2NL-1:0]               pm_tx_lane_flip_en,
    input  [L2NL-1:0]               pm_rx_pol_lane_flip_ctrl,

    // ------------------ Inputs - Rx Muxes ------------------   
    input  [NL-1:0]                 int_phy_mac_rxstandbystatus_i,
    input  [(NL*NB*8)-1:0]          int_phy_mac_rxdata_i,
    input  [NL*NB-1 :0]             int_phy_mac_rxdatak_i,
    input  [NL-1:0]                 int_phy_mac_rxdatavalid_i,
    input  [NL-1:0]                 int_phy_mac_rxvalid_i,
    input  [NL-1:0]                 int_phy_mac_rxelecidle_i,
    input  [(NL*3)-1:0]             int_phy_mac_rxstatus_i,
    input  [NL-1:0]                 int_phy_mac_phystatus_i,
    input  [NL-1:0]                 smlh_no_turnoff_lanes,

    // ------------------ Outputs - Rx Muxes ------------------  
    output [NL-1:0]                 tmp_phy_mac_rxstandbystatus,
    output [(NL*NB*8)-1:0]          tmp_phy_mac_rxdata,
    output [NL*NB-1 :0]             tmp_phy_mac_rxdatak,
    output [NL-1:0]                 tmp_phy_mac_rxdatavalid,
    output [NL-1:0]                 tmp_phy_mac_rxvalid,
    output [NL-1:0]                 tmp_phy_mac_rxelecidle,
    output [(NL*3)-1:0]             tmp_phy_mac_rxstatus,
    output [NL-1:0]                 tmp_phy_mac_phystatus,
    output [NL-1:0]                 laneflip_no_turnoff_lanes_o,

    // ------------------ Inputs - Tx Muxes ------------------   
    input [NL-1:0]                  tmp_mac_phy_rxstandby,
    input [1:0]                     tmp_xmlh_powerdown,
    input [2:0]                     tmp_int_mac_phy_rate,
    input  [(NL*NB*8)-1:0]          tmp_mac_phy_txdata,
    input  [(NL*NB)-1:0]            tmp_mac_phy_txdatak,
    input  [NL-1:0]                 tmp_mac_phy_txdetectrx_loopback,// Enable receiver detection sequence.  SerDes transmits
    input  [NL-1:0]                 tmp_ltssm_txelecidle,
    input  [NL-1:0]                 tmp_mac_phy_txcompliance,
    input  [NL-1:0]                 tmp_mac_phy_rxpolarity,
    input  [NL-1:0]                 smlh_lanes_active,
    input  [NL-1:0]                 smlh_rcvd_eidle_rxstandby,

    // ------------------ Outputs - Tx Muxes ------------------  
    output [NL-1:0]                 int_mac_phy_rxstandby_o,
    output [1:0]                    int_xmlh_powerdown_o,
    output [2:0]                    int_mac_phy_rate_o,
    output [(NL*NB*8)-1:0]          int_mac_phy_txdata_o,
    output [(NL*NB)-1:0]            int_mac_phy_txdatak_o,
    output [NL-1:0]                 int_mac_phy_txdetectrx_loopback_o,// Enable receiver detection sequence.  SerDes transmits
    output [NL-1:0]                 int_ltssm_txelecidle_o,
    output [NL-1:0]                 int_mac_phy_txcompliance_o,
    output [NL-1:0]                 int_mac_phy_rxpolarity_o
    ,
    output [NL-1:0]                 laneflip_lanes_active_o,
    output [NL-1:0]                 laneflip_rcvd_eidle_rxstandby_o
);

// ================================================================================
//logic below is for register pipeline at the inputs of Lane Flip block from PHY
localparam RXBW = NL+NL*NB*8+NL*NB+NL+NL+NL*3
                                           ;
wire [NL-1:0]                 int_phy_mac_rxstandbystatus;
wire [(NL*NB*8)-1:0]          int_phy_mac_rxdata;
wire [NL*NB-1 :0]             int_phy_mac_rxdatak;
wire [NL-1:0]                 int_phy_mac_rxdatavalid;
wire [NL-1:0]                 int_phy_mac_rxvalid;
wire [NL-1:0]                 int_phy_mac_rxelecidle;
wire [(NL*3)-1:0]             int_phy_mac_rxstatus;
wire [NL-1:0]                 int_phy_mac_phystatus;
wire [4:0] lane_under_test = lane_under_test_i[4:0];
wire [4:0] pol_lane_under_test = {lane_under_test_i[5], lane_under_test_i[3:0]};

reg [RXBW-1:0] rx_vec_r;
reg [NL-1:0] int_phy_mac_phystatus_r;
wire [RXBW-1:0] rx_vec_i = { int_phy_mac_rxstandbystatus_i, int_phy_mac_rxdata_i, int_phy_mac_rxdatak_i, int_phy_mac_rxdatavalid_i,
                             int_phy_mac_rxvalid_i, int_phy_mac_rxstatus_i
 
                            };

always @( posedge core_clk or negedge core_rst_n ) begin : rx_vec_r_PROC
    if ( ~core_rst_n )
        rx_vec_r <= #`TP 0;
    else
        rx_vec_r <= #`TP rx_vec_i;
end // rx_vec_r_PROC

assign { int_phy_mac_rxstandbystatus, int_phy_mac_rxdata, int_phy_mac_rxdatak, int_phy_mac_rxdatavalid,
         int_phy_mac_rxvalid, int_phy_mac_rxstatus
 
        } = REGIN ? rx_vec_r : rx_vec_i;
assign tmp_phy_mac_rxstandbystatus = int_phy_mac_rxstandbystatus; //no lane flip

always @( posedge core_clk_ug or negedge core_rst_n ) begin : int_phy_mac_phystatus_PROC //use core_clk_ug
    if ( ~core_rst_n )
        int_phy_mac_phystatus_r <= #`TP {NL{1'b1}};
    else
        int_phy_mac_phystatus_r <= #`TP int_phy_mac_phystatus_i;
end // int_phy_mac_phystatus_PROC

assign int_phy_mac_phystatus = REGIN ? int_phy_mac_phystatus_r : int_phy_mac_phystatus_i;
assign int_phy_mac_rxelecidle = int_phy_mac_rxelecidle_i; //no pipeline to phy_mac_rxelecidle
//end of RX pipeline

//logic below is for register pipeline at the outputs of Lane Flip block to PHY
localparam TXBW =   NL*NB*8+NL*NB+3*NL +1*NL // CX_NL_GTR_1
                                       ;
wire [NL-1:0]                 int_mac_phy_rxstandby;
wire [1:0]                    int_xmlh_powerdown;
wire [1:0]                    int_ltssm_powerdown;
wire [2:0]                    int_mac_phy_rate;
wire [1:0]                    int_mac_phy_txdeemph;
wire [2:0]                    int_mac_phy_txmargin;
wire                          int_mac_phy_txswing;
wire [(NL*NB*8)-1:0]          int_mac_phy_txdata;
wire [(NL*NB)-1:0]            int_mac_phy_txdatak;
wire [NL-1:0]                 int_mac_phy_txdetectrx_loopback;// Enable receiver detection sequence.  SerDes transmits
wire [NL-1:0]                 int_ltssm_txelecidle;
wire [NL-1:0]                 int_mac_phy_txcompliance;
wire [NL-1:0]                 int_mac_phy_rxpolarity;
wire [NL-1:0]                 laneflip_lanes_active;
wire [NL-1:0]                 laneflip_rcvd_eidle_rxstandby;
wire [NL-1:0]                 laneflip_no_turnoff_lanes;

assign int_mac_phy_rxstandby = tmp_mac_phy_rxstandby; //no lane flip
assign int_xmlh_powerdown = tmp_xmlh_powerdown;
assign int_mac_phy_rate = tmp_int_mac_phy_rate;
wire [TXBW-1:0] tx_vec_o = { int_mac_phy_txdata, int_mac_phy_txdatak,
                             int_mac_phy_txdetectrx_loopback, int_mac_phy_txcompliance, int_mac_phy_rxpolarity
 , laneflip_rcvd_eidle_rxstandby 
                           };

reg [TXBW-1:0] tx_vec_r;
always @( posedge core_clk or negedge core_rst_n ) begin : tx_vec_r_PROC
    if ( ~core_rst_n )
        tx_vec_r <= #`TP 0;
    else
        tx_vec_r <= #`TP tx_vec_o;
end // tx_vec_r_PROC

reg [1:0] int_ltssm_powerdown_r, int_xmlh_powerdown_r;
always @( posedge core_clk or negedge core_rst_n ) begin : powerdown_PROC //reset powerdown to P1
    if ( ~core_rst_n ) begin
        int_xmlh_powerdown_r  <= #`TP `P1;
    end else begin
        int_xmlh_powerdown_r  <= #`TP int_xmlh_powerdown;
    end
end // powerdown_PROC

// If CX_FREQ_STEP_EN is enabled, the int_mac_phy_rate_o should be active after L1 substate to release a clock gating logic in freq_step.
reg [2:0] int_mac_phy_rate_r;
reg [1:0] int_mac_phy_txdeemph_r;
reg [2:0] int_mac_phy_txmargin_r;
reg       int_mac_phy_txswing_r;
always @( posedge core_clk    or negedge core_rst_n ) begin : int_mac_phy_rate_r_PROC //use core_clk
    if ( ~core_rst_n ) begin
        int_mac_phy_rate_r <= #`TP 0;
    end else begin
        int_mac_phy_rate_r <= #`TP int_mac_phy_rate;
    end
end // int_mac_phy_rate_r_PROC


reg [NL-1:0] int_ltssm_txelecidle_r;
reg [NL-1:0] int_mac_phy_rxstandby_r;
always @( posedge core_clk or negedge core_rst_n ) begin : int_ltssm_txelecidle_r_PROC //reset txelecidle to 1, rxstandby to CX_RXSTANDBY_DEFAULT
    if ( ~core_rst_n ) begin
        int_ltssm_txelecidle_r  <= #`TP {NL{1'b1}};
        int_mac_phy_rxstandby_r <= #`TP {NL{`CX_RXSTANDBY_DEFAULT}};
    end else begin
        int_ltssm_txelecidle_r  <= #`TP int_ltssm_txelecidle;
        int_mac_phy_rxstandby_r <= #`TP int_mac_phy_rxstandby;
    end
end // int_ltssm_txelecidle_r_PROC

reg [NL-1:0] laneflip_lanes_active_r;
always @( posedge core_clk or negedge core_rst_n ) begin : laneflip_lanes_active_r_PROC //reset laneflip_lanes_active  to 1
    if ( ~core_rst_n ) begin
        laneflip_lanes_active_r <= #`TP {NL{1'b1}};
    end else begin
        laneflip_lanes_active_r <= #`TP laneflip_lanes_active;
    end
end // laneflip_lanes_active_r_PROC
reg [NL-1:0] laneflip_no_turnoff_lanes_r;
always @( posedge core_clk or negedge core_rst_n ) begin : laneflip_no_turnoff_lanes_r_PROC //reset laneflip_lanes_active  to 1
    if ( ~core_rst_n ) begin
        laneflip_no_turnoff_lanes_r <= #`TP {NL{1'b1}};
    end else begin
        laneflip_no_turnoff_lanes_r <= #`TP laneflip_no_turnoff_lanes;
    end
end // laneflip_no_turnoff_lanes_r_PROC


assign int_mac_phy_rate_o = REGOUT ? int_mac_phy_rate_r : int_mac_phy_rate;
assign int_xmlh_powerdown_o  = REGOUT ? int_xmlh_powerdown_r  : int_xmlh_powerdown;
assign int_ltssm_txelecidle_o = REGOUT ? int_ltssm_txelecidle_r : int_ltssm_txelecidle;
assign int_mac_phy_rxstandby_o = REGOUT ? int_mac_phy_rxstandby_r : int_mac_phy_rxstandby;
assign laneflip_lanes_active_o = REGOUT ? laneflip_lanes_active_r : laneflip_lanes_active;
assign laneflip_no_turnoff_lanes_o = REGOUT ? laneflip_no_turnoff_lanes_r : laneflip_no_turnoff_lanes;

assign { int_mac_phy_txdata_o, int_mac_phy_txdatak_o,
                             int_mac_phy_txdetectrx_loopback_o, int_mac_phy_txcompliance_o, int_mac_phy_rxpolarity_o
 , laneflip_rcvd_eidle_rxstandby_o 
                            } = REGOUT ? tx_vec_r : tx_vec_o;
//end of TX pipeline
// =========================================================================================

// muxes added for enabling lane flip functions
// in lane_flip_mux instance, first parameter value is 1 - Rx signal flip, 0 - Tx signal flip
 lane_flip_mux
  #( 1, NL,NB*8) u_rx_lane_flip_mux_0 (.flipped_data(tmp_phy_mac_rxdata),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxdata));
 lane_flip_mux
  #( 1, NL,NB) u_rx_lane_flip_mux_1 (.flipped_data(tmp_phy_mac_rxdatak),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxdatak));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_2 (.flipped_data(tmp_phy_mac_rxdatavalid), .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxdatavalid));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_19 (.flipped_data(tmp_phy_mac_rxvalid),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxvalid));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_20 (.flipped_data(tmp_phy_mac_rxelecidle),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxelecidle));
 lane_flip_mux
  #( 1, NL,3) u_rx_lane_flip_mux_21 (.flipped_data(tmp_phy_mac_rxstatus),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxstatus));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_22 (.flipped_data(tmp_phy_mac_phystatus),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_phystatus));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_35 (.flipped_data(laneflip_no_turnoff_lanes),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(smlh_no_turnoff_lanes));

 lane_flip_mux
  #( 0, NL,NB*8) u_tx_lane_flip_mux_0 (.flipped_data(int_mac_phy_txdata),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txdata));
 lane_flip_mux
  #( 0, NL,NB) u_tx_lane_flip_mux_1 (.flipped_data(int_mac_phy_txdatak),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txdatak));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_23 (.flipped_data(int_mac_phy_txdetectrx_loopback),.lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txdetectrx_loopback));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_24 (.flipped_data(int_ltssm_txelecidle),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_ltssm_txelecidle));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_25 (.flipped_data(int_mac_phy_txcompliance), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txcompliance));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_26 (.flipped_data(int_mac_phy_rxpolarity),  .lut(pol_lane_under_test), .flip_ctrl(pm_rx_pol_lane_flip_ctrl), .data(tmp_mac_phy_rxpolarity));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_27 (.flipped_data(laneflip_lanes_active),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(smlh_lanes_active));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_28 (.flipped_data(laneflip_rcvd_eidle_rxstandby),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(smlh_rcvd_eidle_rxstandby));

endmodule
