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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_reg.v#7 $
// -------------------------------------------------------------------------
// --- Description: PHY Register model
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_reg
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
input       [3:0]             mac_phy_command,
input       [11:0]            mac_phy_address,
input       [7:0]             mac_phy_data,
output  reg [7:0]             phy_reg_data,
output                        phy_reg_margin_sampl_cnt_clr,      // 12'h000 RX1: RX Margin Control0       [3] Sample Count Reset
output                        phy_reg_margin_error_cnt_clr,      // 12'h000 RX1: RX Margin Control0       [2] Error Count Reset
output                        phy_reg_margin_voltage_or_timing,  // 12'h000 RX1: RX Margin Control0       [1] Rx Margin Voltage or Timing
output                        phy_reg_margin_start,              // 12'h000 RX1: RX Margin Control0       [0] Start Margin
output                        phy_reg_margin_up_down,            // 12'h001 RX1: RX Margin Control1       [7] Margin Direction
output                        phy_reg_margin_left_right,         // 12'h001 RX1: RX Margin Control1       [7] Margin Direction
output      [6:0]             phy_reg_margin_offset,             // 12'h001 RX1: RX Margin Control1     [6:0] Margin Offset
output      [7:0]             phy_reg_ebuf_depth_cntrl,          // 12'h002 RX1: Elastic Buffer Control [7:0] Elastic Buffer Depth Control
output                        phy_reg_rxpolarity,                // 12'h003 RX1: PHY RX Control0          [1] RxPolarity
output                        phy_reg_ebuf_mode,                 // 12'h003 RX1: PHY RX Control0          [0] Elasticity Buffer Mode
output                        phy_reg_invalid_req,               // 12'h006 RX1: PHY RX Control3          [2] InvalidRequest
output                        phy_reg_rxeqinprogress,            // 12'h006 RX1: PHY RX Control3          [1] RxEqInProgress
output                        phy_reg_rxeqeval,                  // 12'h006 RX1: PHY RX Control3          [0] RxEqEval
output      [7:0]             phy_reg_ebuf_upd_freq,             // 12'h007 RX1:                        [7:0] ElasticBufferLocationUpdateFrequency
output                        phy_reg_ebuf_rst_control,          // 12'h008 RX1: PHY RX Control4          [1] ElasticBufferResetControl
output                        phy_reg_blockaligncontrol,         // 12'h008 RX1: PHY RX Control4          [0] BlockAlignControl
output      [17:0]            phy_reg_txdeemph,                  // 12'h402-4 TX1: PHY TX Control2-4   [17:0] TxDeemph {(C+1:404H), (C0:403H), (C-1:402H)}
output                        phy_reg_getlocal_pset_coef,        // 12'h405 TX1: PHY TX Control5          [7] GetLocalPresetCoefficients
output      [5:0]             phy_reg_local_pset_index,          // 12'h405 TX1: PHY TX Control5        [5:0] LocalPresetIndex
output      [5:0]             phy_reg_fs,                        // 12'h406 TX1: PHY TX Control6        [5:0] FS
output      [5:0]             phy_reg_lf,                        // 12'h407 TX1: PHY TX Control7        [5:0] LF
output                        phy_reg_txswing,                   // 12'h408 TX1: PHY TX Control8          [3] TxSwing
output      [2:0]             phy_reg_txmargin,                  // 12'h408 TX1: PHY TX Control8        [2:0] TxMargin
output                        phy_reg_encodedecodebypass,        // 12'h800 CMN1: PHY Common Control0     [0] EncodeDecodeBypass
output  reg [6:0]             phy_reg_esm_data_rate0,            // 12'hF00 VDR: ESM Rate0              [6:0] ESM Data Rate0
output  reg [6:0]             phy_reg_esm_data_rate1,            // 12'hF01 VDR: ESM Rate1              [6:0] ESM Data Rate1
output  reg                   phy_reg_esm_calibrt_req,           // 12'hF02 VDR: ESM Control              [1] ESM Calibration request
output  reg                   phy_reg_esm_enable                 // 12'hF02 VDR: ESM Control              [0] ESM Enable
);

localparam pRESERVED_BIT_000H = (`GPHY_IS_PIPE_44==0) ? 8'h70 : 8'hF0;
localparam pVOLATILE_BIT_000H = (`GPHY_IS_PIPE_44==0) ? 8'h18 : 8'h0C;
localparam pRESERVED_BIT_001H = (`GPHY_IS_PIPE_44==0) ? 8'h80 : 8'h00;

wire                          write_uncommitted;
wire                          write_committed;
wire                          read_command;
reg         [7:0]             phy_reg_000;
reg         [7:0]             phy_reg_001;
reg         [7:0]             phy_reg_002;
reg         [7:0]             phy_reg_003;
reg         [7:0]             phy_reg_006;
reg         [7:0]             phy_reg_007;
reg         [7:0]             phy_reg_008;
reg         [7:0]             phy_reg_402;
reg         [7:0]             phy_reg_403;
reg         [7:0]             phy_reg_404;
reg         [7:0]             phy_reg_405;
reg         [7:0]             phy_reg_406;
reg         [7:0]             phy_reg_407;
reg         [7:0]             phy_reg_408;
reg         [7:0]             phy_reg_800;

// -----------------------------------------------------------------------------
// Command Flags
// -----------------------------------------------------------------------------
assign write_uncommitted = (mac_phy_command==`GPHY_CMD_WR_UC) ? 1'b1 : 1'b0 ;
assign write_committed   = (mac_phy_command==`GPHY_CMD_WR_C)  ? 1'b1 : 1'b0 ;
assign read_command      = (mac_phy_command==`GPHY_CMD_RD)    ? 1'b1 : 1'b0 ;

// -----------------------------------------------------------------------------
// Read Data
// -----------------------------------------------------------------------------
always @(posedge pclk or negedge phy_rst_n) begin
  if (!phy_rst_n) begin
    phy_reg_data <= #TP 8'h00;
  end
  else begin
    if(read_command) begin
      case(mac_phy_address)
          12'h000 : phy_reg_data <= #TP phy_reg_000;
          12'h001 : phy_reg_data <= #TP phy_reg_001;
          12'h002 : phy_reg_data <= #TP phy_reg_002;
          12'h003 : phy_reg_data <= #TP phy_reg_003;
          12'h006 : phy_reg_data <= #TP phy_reg_006;
          12'h007 : phy_reg_data <= #TP phy_reg_007;
          12'h409 : phy_reg_data <= #TP phy_reg_008;
          12'h402 : phy_reg_data <= #TP phy_reg_402;
          12'h403 : phy_reg_data <= #TP phy_reg_403;
          12'h404 : phy_reg_data <= #TP phy_reg_404;
          12'h405 : phy_reg_data <= #TP phy_reg_405;
          12'h406 : phy_reg_data <= #TP phy_reg_406;
          12'h407 : phy_reg_data <= #TP phy_reg_407;
          12'h408 : phy_reg_data <= #TP phy_reg_408;
          12'h408 : phy_reg_data <= #TP phy_reg_408;
          12'h800 : phy_reg_data <= #TP phy_reg_800;
          default : phy_reg_data <= #TP 8'hFF;
      endcase
    end else begin
      phy_reg_data <= #TP phy_reg_data;
    end
  end
end

// -----------------------------------------------------------------------------
// Rx Margin Control 0 (offset 000H)
// PIPE44:
// [7:4] : Reserved
//   [3] : Sample Count Reset(1-cycle)
//   [2] : Error Count Reset(1-cycle)
//   [1] : Rx Margin Voltage or Timing(Level)
//   [0] : Start Margin(Level)
// PRE PIPE44:
// [7:5] : Reserved
//   [4] : Rx Margin Sample Count Reset(1-cycle)
//   [3] : Rx Margin Error Count Reset(1-cycle)
// [2:1] : Rx Margin Direction(Level)
//   [0] : Rx Margin Start/Change(Level)
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h000),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (pRESERVED_BIT_000H),
    .pVOLATILE_BIT (pVOLATILE_BIT_000H)
) u_reg_000H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_000)
);
assign phy_reg_margin_sampl_cnt_clr     = (`GPHY_IS_PIPE_44==0) ?  phy_reg_000[4] : phy_reg_000[3];
assign phy_reg_margin_error_cnt_clr     = (`GPHY_IS_PIPE_44==0) ?  phy_reg_000[3] : phy_reg_000[2];
assign phy_reg_margin_voltage_or_timing = (`GPHY_IS_PIPE_44==0) ? ~phy_reg_000[2] : phy_reg_000[1];
assign phy_reg_margin_start             = phy_reg_000[0];
// -----------------------------------------------------------------------------
// Rx Margin Control 1 (offset 001H)
// PIPE44:
//   [7] : Margin Direction(Level)
// [6:0] : Margin Offset(Level)
// PRE PIPE44:
//   [7] : Reserved
// [6:0] : Rx Margin Offset(Level)
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h001),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (pRESERVED_BIT_001H),
    .pVOLATILE_BIT (8'h00)
) u_reg_001H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_001)
);
assign phy_reg_margin_up_down    = (`GPHY_IS_PIPE_44==0) ?  phy_reg_000[1] : phy_reg_001[7];
assign phy_reg_margin_left_right = (`GPHY_IS_PIPE_44==0) ?  phy_reg_000[1] : phy_reg_001[7];
assign phy_reg_margin_offset     = phy_reg_001[6:0];
// -----------------------------------------------------------------------------
// Elastic Buffer Control (offset 002H)
// [7:0] : Elastic Buffer Depth Control
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h002),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'h00),
    .pVOLATILE_BIT (8'h00)
) u_reg_002H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_002)
);
assign phy_reg_ebuf_depth_cntrl = phy_reg_002[7:0];
// -----------------------------------------------------------------------------
// RX1: PHY RX Control0 (offset 003H)
// [7:2] : Reserved
//   [1] : RxPolarity
//   [0] : Elasticity Buffer Mode
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h003),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'hFC),
    .pVOLATILE_BIT (8'h00)
) u_reg_003H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_003)
);
assign phy_reg_rxpolarity = phy_reg_003[1];
assign phy_reg_ebuf_mode  = phy_reg_003[0];
// -----------------------------------------------------------------------------
// RX1: PHY RX Control3 (offset 006H)
// [7:3] : Reserved
// [2]   : InvalidRequest
// [1]   : RxEqInProgress
// [0]   : RxEqEval
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h006),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'hF8),
    .pVOLATILE_BIT (8'h00)
) u_reg_006H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_006)
);
assign phy_reg_invalid_req    = phy_reg_006[2];
assign phy_reg_rxeqinprogress = phy_reg_006[1];
assign phy_reg_rxeqeval       = phy_reg_006[0];
// -----------------------------------------------------------------------------
// RX1: Elastic Buffer Location Update Frequency (offset 007H)
// [7:0] : ElasticBufferLocationUpdateFrequency
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h007),
    .pRESET_VALUE  (8'h05),
    .pRESERVED_BIT (8'h00),
    .pVOLATILE_BIT (8'h00)
) u_reg_007H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_007)
);
assign phy_reg_ebuf_upd_freq = phy_reg_007;
// -----------------------------------------------------------------------------
// RX1: PHY RX Control4 (offset 008H)
// [7:2] : Reserved
//   [1] : ElasticBufferResetControl(1-cycle)
//   [0] : BlockAlignControl
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h008),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'hFC),
    .pVOLATILE_BIT (8'h02)
) u_reg_409H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_008)
);
assign phy_reg_ebuf_rst_control  = phy_reg_008[1];
assign phy_reg_blockaligncontrol = phy_reg_008[0];
// -----------------------------------------------------------------------------
// TX1: PHY TX Control2 (offset 402H)
// [7:6] : Reserved
// [5:0] : TxDeemph[5:0]
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h402),
    .pRESET_VALUE  (8'h01),
    .pRESERVED_BIT (8'hC0),
    .pVOLATILE_BIT (8'h00)
) u_reg_402H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_402)
);
assign phy_reg_txdeemph[5:0] = phy_reg_402[5:0];
// -----------------------------------------------------------------------------
// TX1: PHY TX Control3 (offset 403H)
// [7:6] : Reserved
// [5:0] : TxDeemph[11:6]
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h403),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'hC0),
    .pVOLATILE_BIT (8'h00)
) u_reg_403H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_403)
);
assign phy_reg_txdeemph[11:6] = phy_reg_403[5:0];
// -----------------------------------------------------------------------------
// TX1: PHY TX Control4 (offset 404H)
// [7:6] : Reserved
// [5:0] : TxDeemph[17:12]
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h404),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'hC0),
    .pVOLATILE_BIT (8'h00)
) u_reg_404H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_404)
);
assign phy_reg_txdeemph[17:12] = phy_reg_404[5:0];
// -----------------------------------------------------------------------------
// TX1: PHY TX Control5 (offset 405H)
// [7]   : GetLocalPresetCoefficients(1-cycle)
// [6]   : Reserved
// [5:0] : LocalPresetIndex
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h405),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'h40),
    .pVOLATILE_BIT (8'h80)
) u_reg_405H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_405)
);
assign phy_reg_getlocal_pset_coef = phy_reg_405[7];
assign phy_reg_local_pset_index   = phy_reg_405[5:0];
// -----------------------------------------------------------------------------
// TX1: PHY TX Control6 (offset 406H)
// [7:6] : Reserved
// [5:0] : FS
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h406),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'hC0),
    .pVOLATILE_BIT (8'h00)
) u_reg_406H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_406)
);
assign phy_reg_fs = phy_reg_406[5:0];
// -----------------------------------------------------------------------------
// TX1: PHY TX Control7 (offset 407H)
// [7:6] : Reserved
// [5:0] : LF
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h407),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'hC0),
    .pVOLATILE_BIT (8'h00)
) u_reg_407H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_407)
);
assign phy_reg_lf = phy_reg_407[5:0];
// -----------------------------------------------------------------------------
// TX1: PHY TX Control8 (offset 408H)
// [7:4] : Reserved
//   [3] : TxSwing
// [2:0] : TxMargin
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h408),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'hF0),
    .pVOLATILE_BIT (8'h00)
) u_reg_408H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_408)
);
assign phy_reg_txswing  = phy_reg_408[3];
assign phy_reg_txmargin = phy_reg_408[2:0];
// -----------------------------------------------------------------------------
// CMN1: PHY Common Control0 (offset 800H)
// [7:1] : Reserved
//   [0] : EncodeDecodeBypass
// -----------------------------------------------------------------------------
DWC_pcie_gphy_reg_sub #(
    .TP            (TP),
    .pREG_ADDRESS  (12'h800),
    .pRESET_VALUE  (8'h00),
    .pRESERVED_BIT (8'hF7),
    .pVOLATILE_BIT (8'h00)
) u_reg_800H (
  .pclk            (pclk),
  .phy_rst_n       (phy_rst_n),
  .mac_phy_command (mac_phy_command),
  .mac_phy_address (mac_phy_address),
  .mac_phy_data    (mac_phy_data),
  .phy_reg         (phy_reg_800)
);
assign phy_reg_encodedecodebypass = phy_reg_800[0];

// -----------------------------------------------------------------------------
// VDR: (offset C00H-FFFH)
// -----------------------------------------------------------------------------
genvar G_REG_ADDR;
generate
for (G_REG_ADDR = `GPHY_CCIX_OFFSET; G_REG_ADDR<=`GPHY_CCIX_OFFSET+12'h002; G_REG_ADDR=G_REG_ADDR+12'h001) begin : gen_ccix_reg
reg        phy_reg_uc_valid;
reg [7:0]  phy_reg_uc;
reg [7:0]  phy_reg;

if( (G_REG_ADDR==`GPHY_CCIX_OFFSET) || (G_REG_ADDR==`GPHY_CCIX_OFFSET+12'h001) ) begin
    // -----------------------------------------------------------------------------
    // ESM Rate0 (offset F00H)
    //   [7] : Reserved
    // [6:0] : ESM Data Rate0
    // -----------------------------------------------------------------------------
    // ESM Rate1 (offset F01H)
    //   [7] : Reserved
    // [6:0] : ESM Data Rate1
    // -----------------------------------------------------------------------------
    always @(posedge pclk or negedge phy_rst_n) begin
      if (!phy_rst_n) begin
        phy_reg_uc_valid <= #TP 1'b0;
        phy_reg_uc       <= #TP 8'h00;
        phy_reg          <= #TP 8'h00;
      end
      else begin
        phy_reg_uc_valid <= #TP (write_uncommitted & mac_phy_address==G_REG_ADDR) ?              1'b1 :
                                (write_committed                                ) ?              1'b0 : phy_reg_uc_valid;
        phy_reg_uc[6:0]  <= #TP (write_uncommitted & mac_phy_address==G_REG_ADDR) ? mac_phy_data[6:0] : phy_reg_uc[6:0];
        phy_reg[6:0]     <= #TP (write_committed   & mac_phy_address==G_REG_ADDR) ? mac_phy_data[6:0] : 
                                (write_committed   & phy_reg_uc_valid           ) ? phy_reg_uc[6:0]   : phy_reg[6:0];
      end
    end
    if(G_REG_ADDR==`GPHY_CCIX_OFFSET)         assign phy_reg_esm_data_rate0 = phy_reg[6:0];
    if(G_REG_ADDR==`GPHY_CCIX_OFFSET+12'h001) assign phy_reg_esm_data_rate1 = phy_reg[6:0];
end // G_REG_ADDR
if(G_REG_ADDR==`GPHY_CCIX_OFFSET+12'h002) begin
    // -----------------------------------------------------------------------------
    // ESM Control (offset F02H)
    // [7:2] : Reserved
    //   [1] : ESM Calibration request(1-cycle)
    //   [0] : ESM Enable
    // -----------------------------------------------------------------------------
    always @(posedge pclk or negedge phy_rst_n) begin
      if (!phy_rst_n) begin
        phy_reg_uc_valid <= #TP 1'b0;
        phy_reg_uc       <= #TP 8'h00;
        phy_reg          <= #TP 8'h00;
      end
      else begin
        phy_reg_uc_valid <= #TP (write_uncommitted & mac_phy_address==G_REG_ADDR) ?              1'b1 :
                                (write_committed                                ) ?              1'b0 : phy_reg_uc_valid;
        phy_reg_uc[1:0]  <= #TP (write_uncommitted & mac_phy_address==G_REG_ADDR) ? mac_phy_data[1:0] : phy_reg_uc[1:0];
        phy_reg[1:0]     <= #TP (write_committed   & mac_phy_address==G_REG_ADDR) ? mac_phy_data[1:0] : 
                                (write_committed   & phy_reg_uc_valid           ) ? phy_reg_uc[1:0]   : {1'b0, phy_reg[0]};
      end
    end
    assign phy_reg_esm_calibrt_req = phy_reg[1] || lane_disabled;
    assign phy_reg_esm_enable      = phy_reg[0] || lane_disabled;
end // G_REG_ADDR
end // for
endgenerate

endmodule // DWC_pcie_gphy_reg
