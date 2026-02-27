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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_regbus_arb.v#9 $
// -------------------------------------------------------------------------
// --- Description: PHY Register Bus Arbiter model
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_regbus_arb
#(
  parameter TP             = 0,  // Clock to Q delay (simulator insurance)
  parameter TX_COEF_WD     = 18, // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
  parameter DIRFEEDBACK_WD = 6,  // Width of Direction Change
  parameter FOMFEEDBACK_WD = 8,  // Width of Figure of Merit
  parameter TX_FS_WD       = 6   // Width of LF or FS
) (
input                         pclk,
input                         phy_rst_n,
input                         lane_disabled,
// For Lane Margining
input                         IndErrorSampler,
input                         SampleReportingMethod,
input                         phy_mac_margin_status,
input                         phy_mac_margin_nak,
input  [1:0]                  phy_mac_margin_respinfo,  // 0:IDLE/1:START/2:OFFSET/3:STOP
input                         phy_mac_margin_cnt_updated,
input  [6:0]                  phy_mac_margin_sampl_cnt,
input  [5:0]                  phy_mac_margin_error_cnt,
// For LowPinCount
input                         ebuf_location_upd_en,
input  [7:0]                  phy_mac_ebuf_location,
input  [TX_COEF_WD-1:0]       phy_mac_local_tx_pset_coef,
input                         eqpa_local_tx_coef_valid_g3,
input                         eqpa_local_tx_coef_valid_g4,
input                         eqpa_local_tx_coef_valid_g5,
input  [2:0]                  update_localfslf_mode,
input  [TX_FS_WD-1:0]         eqpa_localfs_g3,
input  [TX_FS_WD-1:0]         eqpa_locallf_g3,
input  [TX_FS_WD-1:0]         eqpa_localfs_g4,
input  [TX_FS_WD-1:0]         eqpa_locallf_g4,
input  [TX_FS_WD-1:0]         eqpa_localfs_g5,
input  [TX_FS_WD-1:0]         eqpa_locallf_g5,
input                         eqpa_feedback_valid,
input                         g3_mac_phy_rate_pulse,
input                         g4_mac_phy_rate_pulse,
input                         g5_mac_phy_rate_pulse,
input  [DIRFEEDBACK_WD-1:0]   phy_mac_dirfeedback,
input  [FOMFEEDBACK_WD-1:0]   phy_mac_fomfeedback,
// For CCIX
input                         phy_mac_esm_calibrt_complete,
input  [3:0]                  mac_phy_command,
input  [11:0]                 mac_phy_address,
input                         phy_mac_command_ack,
input                         phy_reg_esm_calibrt_req,
input  [7:0]                  phy_reg_ebuf_upd_freq,
// signal from sdm_1s.u0_pipe2phy to start initial message
input                         pclk_stable,
//
output reg [3:0]              phy_mac_command,
output reg [11:0]             phy_mac_address,
output reg [7:0]              phy_mac_data,
output                        write_ack_for_esm_calibrt_req,
// signal for sdm_1s.u0_pipe2phy to delay phystatus
output reg                    phy_reg_localfslf_done
);

//////////////////////////////////////////////////
// To create requests
//////////////////////////////////////////////////
// u_regbus_cont -> u_xphy_pll
reg                           wait_write_ack_for_esm_calibrt_req;
// u_regbus_slave -> u_regbus_master
wire                          wait_write_ack;
reg                           wait_write_ack_reg;
wire                          pending_write_ack;
reg                           pending_write_ack_reg;
//
reg                           during_uc_wr;
reg                           during_uc_wr_reg;

// -----------------------------------------------------------------------------
// Request for LocalLF/FS
// -----------------------------------------------------------------------------
wire                          initial_pclk_stable;
reg                           pclk_stable_d;
wire                          pclk_stable_pulse;
reg                           pclk_stable_timer_en;
wire                          pclk_stable_timer_exp;
reg                           timing_update_fslf_after_reset;
wire                          req_fslf_g3_update; // as PIPE 5.1 Figure 9-4  : TX Status3 -> TX Status4
wire                          req_fslf_g4_update; // as PIPE 5.1 Figure 9-4  : TX Status5 -> TX Status6
wire                          req_fslf_g5_update; // as PIPE 5.1 Figure 9-4  : TX Status7 -> TX Status8
// 
wire                          random_first_pipe_msg_delay_en; // will be connected to task
wire    [7:0]                 fixed_first_pipe_msg_delay_thr; // will be connected to task
wire    [7:0]                 first_pipe_msg_delay_thr;
wire    [7:0]                 first_pipe_msg_delay_lo_rnd; // low limit for randomization - before scaling
wire    [7:0]                 first_pipe_msg_delay_hi_rnd; // high limit for randomization - before scaling

assign initial_pclk_stable = timing_update_fslf_after_reset & pclk_stable & pclk_stable_timer_en & pclk_stable_timer_exp;
assign req_fslf_g3_update = (initial_pclk_stable)                             || (g3_mac_phy_rate_pulse & update_localfslf_mode[1]);
assign req_fslf_g4_update = (initial_pclk_stable && update_localfslf_mode[0]) || (g4_mac_phy_rate_pulse & update_localfslf_mode[1]);
assign req_fslf_g5_update = (initial_pclk_stable && update_localfslf_mode[0]) || (g5_mac_phy_rate_pulse & update_localfslf_mode[1]);

// -----------------------------------------------------------------------------
// Request for Elastic Buffer Location
// -----------------------------------------------------------------------------
reg                           req_ebuf_location; // as PIPE 5.1 Figure 9-12 : 
reg  [11:0]                   ebuf_upd_freq_timer; // To count phy_reg_ebuf_upd_freq[7:0] * 16 symbol times
wire [3:0]                    phy_mac_command_c_or_uc; // switched by req_ebuf_location
wire                          followed_by_ebuf_location; // Direct Test purpose

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        ebuf_upd_freq_timer <= #TP 12'h000;
    end else begin
        if(!ebuf_location_upd_en && timing_update_fslf_after_reset || (ebuf_upd_freq_timer >= (phy_reg_ebuf_upd_freq<<4)) ) begin
            ebuf_upd_freq_timer <= #TP 12'h000;
        end else begin
            ebuf_upd_freq_timer <= #TP ebuf_upd_freq_timer + 12'h001;
        end
    end
end
always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        req_ebuf_location <= #TP 1'b0;
    end else begin
        if(ebuf_location_upd_en && !timing_update_fslf_after_reset && (ebuf_upd_freq_timer >= (phy_reg_ebuf_upd_freq<<4)) ) begin
            req_ebuf_location <= #TP 1'b1;
        end else begin
            req_ebuf_location <= #TP 1'b0;
        end
    end
end
assign phy_mac_command_c_or_uc = (req_ebuf_location||followed_by_ebuf_location) ? `GPHY_CMD_WR_UC : `GPHY_CMD_WR_C;
assign followed_by_ebuf_location = 1'b0;

// -----------------------------------------------------------------------------
// Delay between when pclk becomes stable and when phy sends the first message
// delay to start initial message(MAC has 2 cycle pipe_rst_n timing gap by pclk)
// -----------------------------------------------------------------------------
localparam MIN_FIRST_PIPE_MSG_DLY = 8;
localparam MAX_FIRST_PIPE_MSG_DLY = 100;

assign random_first_pipe_msg_delay_en = 1'b1;
assign fixed_first_pipe_msg_delay_thr = MIN_FIRST_PIPE_MSG_DLY;
assign first_pipe_msg_delay_thr     = (random_first_pipe_msg_delay_en) ? MIN_FIRST_PIPE_MSG_DLY : fixed_first_pipe_msg_delay_thr;
assign first_pipe_msg_delay_lo_rnd  = (random_first_pipe_msg_delay_en) ? MIN_FIRST_PIPE_MSG_DLY : fixed_first_pipe_msg_delay_thr;
assign first_pipe_msg_delay_hi_rnd  = (random_first_pipe_msg_delay_en) ? MAX_FIRST_PIPE_MSG_DLY : fixed_first_pipe_msg_delay_thr;

assign pclk_stable_pulse = timing_update_fslf_after_reset & (pclk_stable==1 && pclk_stable_d==0);

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        pclk_stable_d <= #TP 1'b0;
    end else begin
        pclk_stable_d <= #TP pclk_stable;
    end
end
always @(posedge pclk or negedge phy_rst_n) begin
    if (!phy_rst_n) begin
        pclk_stable_timer_en  <= #TP 1'b0;
    end else begin
        pclk_stable_timer_en  <= #TP (pclk_stable_pulse)      ? 1'b1 :
                                     (pclk_stable_timer_exp)  ? 1'b0 : pclk_stable_timer_en;
    end
end

DWC_pcie_gphy_timer #(
  .WD        (8),
  .TP        (TP)
) pclk_stable_timer (
  .clk       (pclk),
  .rst_n     (phy_rst_n),
  .start     (pclk_stable_pulse),
  .thr       (first_pipe_msg_delay_thr),
  .rnd_en    (1'b0),
  .rnd_lo    (first_pipe_msg_delay_lo_rnd),
  .rnd_hi    (first_pipe_msg_delay_hi_rnd),
  .expired   (pclk_stable_timer_exp)
);

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        timing_update_fslf_after_reset <= #TP 1'b1;
    end else begin
        if(initial_pclk_stable) begin
            timing_update_fslf_after_reset <= #TP 1'b0;
        end
    end
end

// -----------------------------------------------------------------------------
// Transmit Queue
// -----------------------------------------------------------------------------
reg         [3:0]             c_que[$];
reg         [11:0]            a_que[$];
reg         [7:0]             d_que[$];
reg                           c_que_empty;

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        c_que_empty = 1'b1;
    end else begin
      if(c_que.size() > 0) begin
        c_que_empty <= #TP 1'b0;
      end else begin
        c_que_empty <= #TP 1'b1;
      end
    end
end

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        c_que = {};
        a_que = {};
        d_que = {};
    end else if(!lane_disabled) begin
        // Start        Success Independent  Ack -> SampleCount=0 -> ErrorCount=0 -> MarginStatus=1
        // Start        Success Dependent    Ack -> MarginStatus=1
        // OffsetChange Success Independent  Ack -> SampleCount=0 -> ErrorCount=0 -> MarginStatus=1
        // OffsetChange Success Dependent    Ack -> MarginStatus=1
        if(phy_mac_margin_status && phy_mac_margin_respinfo!=2'b11) begin
            if(IndErrorSampler==1 && SampleReportingMethod==0) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS1);
                d_que.push_back(8'h00); // SampleCount
            end
            if(IndErrorSampler==1) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS2);
                d_que.push_back(8'h00); // ErrorCount
            end
            c_que.push_back(phy_mac_command_c_or_uc);
            a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS0);
            d_que.push_back(8'h01); // MarginStatus
            if(followed_by_ebuf_location) begin
                c_que.push_back(`GPHY_CMD_WR_C);
                a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                d_que.push_back(phy_mac_ebuf_location);
            end
        end
        // Stop         Success Independent  Ack -> SampleCount=Final -> ErrorCount=Final -> MarginStatus=1
        // Stop         Success Dependent    Ack -> MarginStatus=1
        if(phy_mac_margin_status && phy_mac_margin_respinfo==2'b11) begin
            if(IndErrorSampler==1 && SampleReportingMethod==0) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS1);
                d_que.push_back({ 1'b0, phy_mac_margin_sampl_cnt }); // SampleCount
            end
            if(IndErrorSampler==1) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS2);
                d_que.push_back({ 2'b00, phy_mac_margin_error_cnt }); // ErrorCount
            end
            c_que.push_back(phy_mac_command_c_or_uc);
            a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS0);
            d_que.push_back(8'h01); // MarginStatus
            if(followed_by_ebuf_location) begin
                c_que.push_back(`GPHY_CMD_WR_C);
                a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                d_que.push_back(phy_mac_ebuf_location);
            end
        end
        // Start        NAK     Independent  Ack -> SampleCount=0 -> ErrorCount=0 -> MarginNak=1
        // Start        NAK     Dependent    Ack -> MarginNak=1
        // OffsetChange NAK     Independent  Ack -> SampleCount=0 -> ErrorCount=0 -> MarginNak=1
        // OffsetChange NAK     Dependent    Ack -> MarginNak=1
        if(phy_mac_margin_nak) begin
            if(IndErrorSampler==1 && SampleReportingMethod==0) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS1);
                d_que.push_back(8'h00); // SampleCount
            end
            if(IndErrorSampler==1) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS2);
                d_que.push_back(8'h00); // ErrorCount
            end
            c_que.push_back(phy_mac_command_c_or_uc);
            a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS0);
            d_que.push_back(8'h02); // MarginNak
            if(followed_by_ebuf_location) begin
                c_que.push_back(`GPHY_CMD_WR_C);
                a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                d_que.push_back(phy_mac_ebuf_location);
            end
        end
        // ClearError           Independent  Ack -> SampleCount=current -> ErrorCount=0
        // ClearError           Dependent    N/A
        // CountUpdate          Independent  SampleCount=current -> ErrorCount=current
        // CountUpdate          Dependent    N/A
        if(phy_mac_margin_cnt_updated) begin // ClearError and CountUpdate
            if(IndErrorSampler==1) begin
                if(SampleReportingMethod==0) begin
                    c_que.push_back(`GPHY_CMD_WR_UC);
                    a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS1);
                    d_que.push_back({ 1'b0, phy_mac_margin_sampl_cnt }); // SampleCount
                end
                c_que.push_back(phy_mac_command_c_or_uc);
                a_que.push_back(`GPHY_MAC_REG_RX_MARIN_STATUS2);
                d_que.push_back({ 2'b00, phy_mac_margin_error_cnt }); // ErrorCount
                if(followed_by_ebuf_location) begin
                    c_que.push_back(`GPHY_CMD_WR_C);
                    a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                    d_que.push_back(phy_mac_ebuf_location);
                end
            end
        end
        if(`GPHY_IS_PIPE_51==1) begin
            // as PIPE 5.1 Figure 9-4  : TX Status3 -> TX Status4
            if(req_fslf_g3_update) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                c_que.push_back(phy_mac_command_c_or_uc);
                a_que.push_back(`GPHY_MAC_REG_TX_STATUS3);
                a_que.push_back(`GPHY_MAC_REG_TX_STATUS4);
                d_que.push_back({2'b00, eqpa_localfs_g3});
                d_que.push_back({2'b00, eqpa_locallf_g3});
                if(followed_by_ebuf_location) begin
                    c_que.push_back(`GPHY_CMD_WR_C);
                    a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                    d_que.push_back(phy_mac_ebuf_location);
                end
            end
            // as PIPE 5.1 Figure 9-4  : TX Status5 -> TX Status6
            if(req_fslf_g4_update) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                c_que.push_back(phy_mac_command_c_or_uc);
                a_que.push_back(`GPHY_MAC_REG_TX_STATUS5);
                a_que.push_back(`GPHY_MAC_REG_TX_STATUS6);
                d_que.push_back({2'b00, eqpa_localfs_g4});
                d_que.push_back({2'b00, eqpa_locallf_g4});
                if(followed_by_ebuf_location) begin
                    c_que.push_back(`GPHY_CMD_WR_C);
                    a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                    d_que.push_back(phy_mac_ebuf_location);
                end
            end
            // as PIPE 5.1 Figure 9-4  : TX Status7 -> TX Status8
            if(req_fslf_g5_update) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                c_que.push_back(phy_mac_command_c_or_uc);
                a_que.push_back(`GPHY_MAC_REG_TX_STATUS7);
                a_que.push_back(`GPHY_MAC_REG_TX_STATUS8);
                d_que.push_back({2'b00, eqpa_localfs_g5});
                d_que.push_back({2'b00, eqpa_locallf_g5});
                if(followed_by_ebuf_location) begin
                    c_que.push_back(`GPHY_CMD_WR_C);
                    a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                    d_que.push_back(phy_mac_ebuf_location);
                end
            end
            // as PIPE 5.1 Figure 9-5  : RX Status0 -> RX Status1 -> TX Status0 -> TX Status1 -> TX Status2
            // as PIPE 5.1 Figure 9-6  : TX Status0 -> TX Status1 -> TX Status2
            if(eqpa_local_tx_coef_valid_g3||eqpa_local_tx_coef_valid_g4||eqpa_local_tx_coef_valid_g5) begin
                if(update_localfslf_mode[2]) begin
                    c_que.push_back(`GPHY_CMD_WR_UC);
                    c_que.push_back(`GPHY_CMD_WR_UC);
                    if(eqpa_local_tx_coef_valid_g3) begin // Gen3
                      a_que.push_back(`GPHY_MAC_REG_TX_STATUS3);
                      a_que.push_back(`GPHY_MAC_REG_TX_STATUS4);
                      d_que.push_back({2'b00, eqpa_localfs_g3});
                      d_que.push_back({2'b00, eqpa_locallf_g3});
                    end
                    if(eqpa_local_tx_coef_valid_g4) begin // Gen4
                      a_que.push_back(`GPHY_MAC_REG_TX_STATUS5);
                      a_que.push_back(`GPHY_MAC_REG_TX_STATUS6);
                      d_que.push_back({2'b00, eqpa_localfs_g4});
                      d_que.push_back({2'b00, eqpa_locallf_g4});
                    end
                    if(eqpa_local_tx_coef_valid_g5) begin // Gen5
                      a_que.push_back(`GPHY_MAC_REG_TX_STATUS7);
                      a_que.push_back(`GPHY_MAC_REG_TX_STATUS8);
                      d_que.push_back({2'b00, eqpa_localfs_g5});
                      d_que.push_back({2'b00, eqpa_locallf_g5});
                    end
                end
                c_que.push_back(`GPHY_CMD_WR_UC);
                c_que.push_back(`GPHY_CMD_WR_UC);
                c_que.push_back(phy_mac_command_c_or_uc);
                a_que.push_back(`GPHY_MAC_REG_TX_STATUS0);
                a_que.push_back(`GPHY_MAC_REG_TX_STATUS1);
                a_que.push_back(`GPHY_MAC_REG_TX_STATUS2);
                d_que.push_back({2'b00, phy_mac_local_tx_pset_coef[5:0]  });
                d_que.push_back({2'b00, phy_mac_local_tx_pset_coef[11:6] });
                d_que.push_back({2'b00, phy_mac_local_tx_pset_coef[17:12]});
                if(followed_by_ebuf_location) begin
                    c_que.push_back(`GPHY_CMD_WR_C);
                    a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                    d_que.push_back(phy_mac_ebuf_location);
                end
            end
            // as PIPE 5.1 Figure 9-8 : RX LinkEvaluation Status0 -> RX LinkEvaluation Status1
            if(eqpa_feedback_valid) begin
                c_que.push_back(`GPHY_CMD_WR_UC);
                c_que.push_back(phy_mac_command_c_or_uc);
                a_que.push_back(`GPHY_MAC_REG_RX_LINK_EVAL_STATUS0);
                a_que.push_back(`GPHY_MAC_REG_RX_LINK_EVAL_STATUS1);
                d_que.push_back({2'b00, phy_mac_fomfeedback});
                d_que.push_back({2'b00, phy_mac_dirfeedback});
                if(followed_by_ebuf_location) begin
                    c_que.push_back(`GPHY_CMD_WR_C);
                    a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                    d_que.push_back(phy_mac_ebuf_location);
                end
            end
        end // GPHY_IS_PIPE_51
        // VDR : ESM Calibration Complete
        if(phy_mac_esm_calibrt_complete) begin
            c_que.push_back(phy_mac_command_c_or_uc);
            a_que.push_back(`GPHY_MAC_REG_VDR_ESM_CALIBRATE_COMPLETE);
            d_que.push_back(8'h01);
            if(followed_by_ebuf_location) begin
                c_que.push_back(`GPHY_CMD_WR_C);
                a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                d_que.push_back(phy_mac_ebuf_location);
            end
        end
        // Elastic Buffer Location which can follow all pipe message.
        if(`GPHY_IS_PIPE_51==1) begin
            if(req_ebuf_location && !followed_by_ebuf_location) begin // as PIPE 5.1 Figure 9-12 :
                c_que.push_back(`GPHY_CMD_WR_C);
                a_que.push_back(`GPHY_MAC_REG_EBUF_LOCATION);
                d_que.push_back(phy_mac_ebuf_location);
            end
        end
    end // lane_disabled
end

// -----------------------------------------------------------------------------
// Tx Write Ack notification flag(to bridge from per-Lane signal to common signal)
// -----------------------------------------------------------------------------
always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        wait_write_ack_for_esm_calibrt_req <= #TP 1'b0;
    end else begin
        if(phy_reg_esm_calibrt_req) begin
            wait_write_ack_for_esm_calibrt_req <= #TP 1'b1;
        end else if(write_ack_for_esm_calibrt_req) begin
            wait_write_ack_for_esm_calibrt_req <= #TP 1'b0;
        end
    end
end
assign write_ack_for_esm_calibrt_req = ((phy_reg_esm_calibrt_req || wait_write_ack_for_esm_calibrt_req) & (phy_mac_command==`GPHY_CMD_WR_ACK) & phy_mac_command_ack) || lane_disabled;

// -----------------------------------------------------------------------------
// Rx Write Ack notification flag(to delay phystatus deassertion)
// -----------------------------------------------------------------------------
always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        phy_reg_localfslf_done <= #TP 1'b0;
    end else begin
       if(`GPHY_IS_PIPE_51==0) begin
            phy_reg_localfslf_done <= #TP 1'b1;
       end else begin
          if(req_fslf_g3_update||req_fslf_g4_update||req_fslf_g5_update) begin
            phy_reg_localfslf_done <= #TP 1'b0;
          end
          else if(!timing_update_fslf_after_reset && !wait_write_ack && c_que.size()==0 && phy_mac_command==`GPHY_CMD_NOP) begin
               phy_reg_localfslf_done <= #TP 1'b1;
          end
       end
    end
end

// -----------------------------------------------------------------------------
// Rx Write Ack waiting flag(to block next WR)
// -----------------------------------------------------------------------------
assign wait_write_ack = (mac_phy_command==`GPHY_CMD_WR_ACK                       ) ? 1'b0 :
                        (phy_mac_command==`GPHY_CMD_WR_C   && phy_mac_command_ack) ? 1'b1 : wait_write_ack_reg ;

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        wait_write_ack_reg     <= #TP 1'b0;
    end else begin
        wait_write_ack_reg     <= #TP wait_write_ack;
    end
end

// -----------------------------------------------------------------------------
// Tx Write Ack waiting flag(to transmit as high priority)
// -----------------------------------------------------------------------------
assign pending_write_ack = (phy_mac_command==`GPHY_CMD_WR_ACK && phy_mac_command_ack) ? 1'b0 :
                           (mac_phy_command==`GPHY_CMD_WR_C                         ) ? 1'b1 : pending_write_ack_reg;

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        pending_write_ack_reg     <= #TP 1'b0;
    end else begin
        pending_write_ack_reg     <= #TP pending_write_ack;
    end
end

// -----------------------------------------------------------------------------
// To guarantee wr_ack suspend sequential write command(uc_wr->c_wr)
// -----------------------------------------------------------------------------
always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        during_uc_wr_reg <= #TP 1'b0;
    end else begin
        during_uc_wr_reg <= #TP during_uc_wr;
    end
end
always @(*) begin
    if(phy_mac_command==`GPHY_CMD_WR_UC) begin
        during_uc_wr = 1'b1;
    end else if(phy_mac_command==`GPHY_CMD_WR_C) begin
        during_uc_wr = 1'b0;
    end else begin
        during_uc_wr = during_uc_wr_reg;
    end
end

// -----------------------------------------------------------------------------
// 
// -----------------------------------------------------------------------------
always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        phy_mac_command <= #TP 4'b0000;
        phy_mac_address <= #TP 12'h000;
        phy_mac_data    <= #TP 8'h00;
    end else begin
        if(phy_mac_command!=4'b0000 && !phy_mac_command_ack) begin
            phy_mac_command <= #TP phy_mac_command;
            phy_mac_address <= #TP phy_mac_address;
            phy_mac_data    <= #TP phy_mac_data;
        end else if(pending_write_ack && !during_uc_wr) begin
            phy_mac_command <= #TP `GPHY_CMD_WR_ACK;
            phy_mac_address <= #TP 12'h000;
            phy_mac_data    <= #TP 8'h00;
        end else if(wait_write_ack) begin // Waiting for Write Ack Command
            phy_mac_command <= #TP 4'b0000;
            phy_mac_address <= #TP 12'h000;
            phy_mac_data    <= #TP 8'h00;
        end else if((c_que.size() > 0) && pclk_stable) begin
            phy_mac_command <= #TP c_que.pop_front();
            phy_mac_address <= #TP a_que.pop_front();
            phy_mac_data    <= #TP d_que.pop_front();
        end else begin
            phy_mac_command <= #TP 4'b0000;
            phy_mac_address <= #TP 12'h000;
            phy_mac_data    <= #TP 8'h00;
        end
    end
end

endmodule // DWC_pcie_gphy_regbus_arb
