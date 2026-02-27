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
// ---    $DateTime: 2020/09/25 02:47:54 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_tlp_ecrc.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles parsing of received Transaction Layer Packets (TLPs).
// --- Its main functions are:
// ---    (1) Report ecrc error when it is enabled by advance error report
// ---    (2) Strip off ecrc for end device
// ---    (3) Report ecrc length mismatch (i.e. too short packets)
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rtlh_tlp_ecrc(
    core_clk,
    core_rst_n,
    rdlh_rtlh_data,
    rdlh_rtlh_sot,
    rdlh_rtlh_dv,
    rdlh_rtlh_eot,
    rdlh_rtlh_abort,
    

// outputs
    rtlh_ecrc_data,
    rtlh_ecrc_sot,
    rtlh_ecrc_dv,
    rtlh_ecrc_eot,
    rtlh_ecrc_abort,
    rtlh_ecrc_err,
    rtlh_ecrc_len_mismatch,
    rtlh_ecrc_parerr
);

parameter  INST                = 0;                           // The uniquifying parameter for each port logic instance.
parameter  NW                  = `CX_NW;                      // Number of 32-bit dwords handled by the datapath each clock.
parameter  DW                  = (32*NW);                     // Width of datapath in bits.
parameter  TP                  = `TP;                         // Clock to Q delay (simulator insurance)
                               
parameter CRC_LATENCY           = `CX_CRC_LATENCY_RTLH;        // default is 1, can be set to 2 for pipelining to ease timing
parameter DATA_PROT_WD          = `TRGT_DATA_PROT_WD;
parameter RAS_PCIE_HDR_PROT_WD  = `CX_RAS_PCIE_HDR_PROT_WD;
parameter DW_W_PAR              = DW + DATA_PROT_WD;

localparam RX_TLP              = `CX_RX_TLP;                  // Number of TLPs that can be processed in a single cycle
localparam RX_TLP_LOG2         = (RX_TLP==4) ? 2 : 1;

// Slave processor parameters
localparam SNW                 = 4;                           // Number of 32-bit dwords handled by each slave processor.
localparam SNW_LOG2            = log2floor(SNW);
localparam SDW                 = (32*SNW);                    // Width of datapath processed by each slave processor in bits.


// -------------------------------- Inputs -------------------------------------
input                     core_clk;                       // Core clock
input                     core_rst_n;                     // Core system reset
// From rtlh_tlp_align
input   [DW_W_PAR-1:0]    rdlh_rtlh_data;                 // Data (hdr and payload) of TLP packet
input   [NW-1:0]          rdlh_rtlh_sot;                  // start of TLP (or, if TLP Prefixes are supported, start of ECRC protection)
input                     rdlh_rtlh_dv;                   // Data (payload/hdr) is valid this cycle
input   [NW-1:0]          rdlh_rtlh_eot;                  // End of TLP
input   [RX_TLP-1:0]      rdlh_rtlh_abort;                // Abort from DLLP layer due to error

// -------------------------------- Outputs------------------------------------

output   [DW_W_PAR-1:0] rtlh_ecrc_data;
output   [NW-1:0]       rtlh_ecrc_sot;
output                  rtlh_ecrc_dv;
output   [NW-1:0]       rtlh_ecrc_eot;
output   [RX_TLP-1:0]   rtlh_ecrc_abort;
output   [RX_TLP-1:0]   rtlh_ecrc_err;
output   [RX_TLP-1:0]   rtlh_ecrc_len_mismatch;
output                  rtlh_ecrc_parerr;                 // Parity/ECC Error flag


// ----------------------------------------------------------------------------
// internal outputs
// ----------------------------------------------------------------------------
wire   [DW_W_PAR-1:0]     pipe_rtlh_data;           // Data (payload) of TLP packet
wire   [NW-1:0]           pipe_rtlh_sot;
wire                      pipe_rtlh_dv;             // Data (payload) is valid this cycle
wire   [NW-1:0]           pipe_rtlh_eot;            // Indicates last word of payload
wire   [RX_TLP-1:0]       pipe_rtlh_abort_vec;      // _vec to indicate that each bit in the vector corresponds to a tlp, rather than a chunk of datapath
wire   [DW_W_PAR-1:0]     pipe_rdlh_rtlh_data;

// ----------------- internal design ------------------------------------
wire  [DW_W_PAR-1:0] int_rtlh_data;
reg   [DW_W_PAR-1:0] ecc_rtlh_data;
reg   [NW-1:0]       int_rtlh_sot;
reg                  int_rtlh_dv;
reg   [NW-1:0]       int_rtlh_eot;
reg   [RX_TLP-1:0]   int_rtlh_abort;
reg   [RX_TLP-1:0]   int_rtlh_ecrc_err;
wire  [RX_TLP-1:0]   int_rtlh_ecrc_len_mismatch;
wire                 tmp_aligned_dv;
wire  [NW-1:0]       tmp_aligned_sot;
wire  [DW_W_PAR-1:0] int_rdlh_rtlh_data; 
wire                 err_detect_rdlh_rtlh_idata;
wire                 err_multpl_rdlh_rtlh_idata;

wire [NW-1:0] rdlh_rtlh_soh; // start of TLP Header indication 
assign rdlh_rtlh_soh = rdlh_rtlh_sot;

wire cfg_ecrc_strip_en; // ECRC strip enabled
assign cfg_ecrc_strip_en = 1'b1;

assign int_rdlh_rtlh_data   = rdlh_rtlh_data;
assign err_detect_rdlh_rtlh_idata = 1'b0;
assign err_multpl_rdlh_rtlh_idata = 1'b0;

//-------------------------------------------------------
// Delay the incoming data to allow time to calculate CRC

// CTRL bits
localparam CTRL_WIDTH = 1 +      // dv
                        NW +     // sot
                        NW +     // eot
                        RX_TLP;  // abort

delay_n
 #(CRC_LATENCY, CTRL_WIDTH) u_delay_n_ctrl
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({rdlh_rtlh_dv,
                  rdlh_rtlh_soh,
                  rdlh_rtlh_eot,
                  rdlh_rtlh_abort}),
    .dout       ({pipe_rtlh_dv,
                  pipe_rtlh_sot,
                  pipe_rtlh_eot,
                  pipe_rtlh_abort_vec})
);

// Datapath
localparam DATAPATH_WIDTH = DW_W_PAR; 
delay_n_w_enable

#(.N(CRC_LATENCY), .WD(DATAPATH_WIDTH)) u_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (rdlh_rtlh_dv),
    .din        (int_rdlh_rtlh_data),
    .dout       (pipe_rdlh_rtlh_data)
);

//-------------------------------------------------------

assign pipe_rtlh_data = pipe_rdlh_rtlh_data;

//--------------------------------

wire   [DW_W_PAR-1:0] latchd_aligned_data;
reg    [DW_W_PAR-1:0] latchd_aligned_data_int;
reg    [NW-1:0]       latchd_aligned_sot;
reg    [NW-1:0]       latchd_aligned_eot;
reg    [RX_TLP-1:0]   latchd_aligned_abort;
reg                   latchd_aligned_dv;
reg    [RX_TLP-1:0]   latchd_aligned_ecrc_err;
//--------------------------------

wire [RX_TLP-1:0]     ecrc_valid_vec; // _vec to indicate that each bit in the vector corresponds to a tlp, rather than a chunk of datapath
wire [RX_TLP-1:0]     ecrc_match_vec;



// =================== ECRC Stripping START for 64bit interface ==========================
      reg                  clkd_dv;
      reg   [NW-1:0]       clkd_eot;
      wire  [DW-1:0]       data_to_crc;
      wire  [DW-1:0]       data_to_crc_org;
      wire                 pipe_hdr_td;
      wire  [NW-1:0]       tmp_aligned_eot;
      wire                 tmp_aligned_abort;
      wire                 tmp_aligned_ecrc_err;
      wire  [DW_W_PAR-1:0] tmp_aligned_data;
      reg                  latched_td;
      wire                 pipe_hdr_4dw;
      reg                  pipe_latchd_hdr_4dw;
      reg                  pipe_latchd_hdr_pyld;

      always @(posedge core_clk or negedge core_rst_n)
         if (!core_rst_n)  begin
              clkd_dv              <= #TP 0;
              clkd_eot             <= #TP 0;
         end else if (pipe_rtlh_dv) begin
              clkd_dv              <= #TP pipe_rtlh_dv;
              clkd_eot             <= #TP pipe_rtlh_eot;
         end else if (|clkd_eot) begin
              clkd_dv              <= #TP 0;
              clkd_eot             <= #TP 0;
         end

      reg   [NW-1:0]  clkd_sot;
      reg   [NW-1:0]  clkd_sot2;
      reg   [NW-1:0]  clkd_sot3;
      always @(posedge core_clk or negedge core_rst_n)
         if (!core_rst_n)  begin
              clkd_sot             <= #TP 0;
              clkd_sot2            <= #TP 0;
              clkd_sot3            <= #TP 0;
         end else if (pipe_rtlh_dv) begin
              clkd_sot             <= #TP pipe_rtlh_sot;
              clkd_sot2            <= #TP clkd_sot;
              clkd_sot3            <= #TP clkd_sot2;
         end else if (|clkd_eot) begin
              clkd_sot             <= #TP 0;
              clkd_sot2            <= #TP 0;
              clkd_sot3            <= #TP 0;
         end

      assign pipe_hdr_4dw =  (pipe_rtlh_sot[0]) ?  pipe_rtlh_data[5]  :
                             (pipe_rtlh_sot[1]) ?  pipe_rtlh_data[37] : 0;

      always @(posedge core_clk or negedge core_rst_n)
          if (!core_rst_n)  begin
              pipe_latchd_hdr_4dw               <= #TP 0;
              pipe_latchd_hdr_pyld              <= #TP 0;
          end else if (pipe_rtlh_sot[0]) begin
              pipe_latchd_hdr_4dw               <= #TP pipe_rtlh_data[5];
              pipe_latchd_hdr_pyld              <= #TP pipe_rtlh_data[6];
          end else if (pipe_rtlh_sot[1]) begin
              pipe_latchd_hdr_4dw               <= #TP pipe_rtlh_data[37];
              pipe_latchd_hdr_pyld              <= #TP pipe_rtlh_data[38];
          end


      // Check the ECRC against digest
      // CRC block does the tlp LCRC calculation and matching to expected CRC value.
      // tlp data input into this block has been aligned to elminate the STP.
      assign data_to_crc_org = (rdlh_rtlh_soh[1]) ? {int_rdlh_rtlh_data[63: 55], 1'b1, int_rdlh_rtlh_data[ 53:33], 1'b1, int_rdlh_rtlh_data[31:0]} :
                               (rdlh_rtlh_soh[0]) ? {int_rdlh_rtlh_data[63: 23], 1'b1, int_rdlh_rtlh_data[ 21: 1], 1'b1                      } : int_rdlh_rtlh_data[DW-1:0];

      assign pipe_hdr_td          = (pipe_rtlh_sot[0]) ? pipe_rtlh_data[23] : pipe_rtlh_data[55];
      always @(posedge core_clk or negedge core_rst_n)
      if (!core_rst_n) begin
              latched_td                     <= #TP 0;
      end else if (|pipe_rtlh_sot & pipe_rtlh_dv) begin
              latched_td                     <= #TP pipe_hdr_td;
      end

      assign tmp_aligned_sot       =  pipe_rtlh_sot;

      // don't strip the ecrc if the TD bit is set, but no ecrc
      assign tmp_aligned_eot       =   (cfg_ecrc_strip_en & pipe_rtlh_eot[1] & latched_td)            ? 2'b01 : pipe_rtlh_eot;

      assign tmp_aligned_dv        = (!cfg_ecrc_strip_en)?  pipe_rtlh_dv | (clkd_dv & (|clkd_eot)) :                 // ECRC strip disabled - no extra of ecrc and eot ended
                                                         (!(pipe_rtlh_eot[0] & latched_td) & pipe_rtlh_dv)           // pkt end,       if ecrc, strip ecrc
                                                       | (!(clkd_eot[0]      & latched_td) & clkd_dv & (|clkd_eot))  // pkt dlyed end, if no ecrc, add extra cycle of dv

                                                       | (!(pipe_rtlh_eot[0] & !clkd_sot[0]   & latched_td) & !pipe_latchd_hdr_4dw & pipe_rtlh_dv)           // pkt end, TD set, but No ECRC, don't strip
                                                       | (!(clkd_eot[0]      & !clkd_sot2[0]  & latched_td) & !pipe_latchd_hdr_4dw & clkd_dv & (|clkd_eot))  // pkt end, TD set, but No ECRC, used for next clocking on latched_aligned data
                                                       | (!(pipe_rtlh_eot[0] & !clkd_sot2[1]  & latched_td) &  pipe_latchd_hdr_4dw & pipe_rtlh_dv)           // pkt end, TD set, but No ECRC, don't strip
                                                       | (!(clkd_eot[0]      & !clkd_sot3[1]  & latched_td) &  pipe_latchd_hdr_4dw & clkd_dv & (|clkd_eot)); // pkt end, TD set, but No ECRC, used for next clocking on latched_aligned data

      // td set, but no ecrc, used only for detect ecrc not present, length problems covered in rtlh_tlp_check
      // the first 2 checks are for exact length because there is no payload
      // the last  2 checks are for short packet because the header determines minimu length.  Long packets (with payload) are
      // checked in rtlh_tlp_check.v
      assign int_rtlh_ecrc_len_mismatch  = (!cfg_ecrc_strip_en)? 0 : // ECRC strip disabled
                                           (latched_td & ((!pipe_latchd_hdr_4dw & !pipe_latchd_hdr_pyld & ( (clkd_sot[0]  & !pipe_rtlh_eot[1])   //td set, 3dw, no pay
                                                                                                          | (clkd_sot2[1] & !pipe_rtlh_eot[0])))
                                                         |(pipe_latchd_hdr_4dw & !pipe_latchd_hdr_pyld & ( (clkd_sot2[0] & !pipe_rtlh_eot[0])   //td set, 4dw, no pay
                                                                                                          | (clkd_sot2[1] & !pipe_rtlh_eot[1])))
                                                         |(!pipe_latchd_hdr_4dw &  pipe_latchd_hdr_pyld & ( (clkd_sot[0]  &  pipe_rtlh_eot[1])   //td set, 3dw,    pay
                                                                                                          | (clkd_sot2[1] &  pipe_rtlh_eot[0])))
                                                         |(pipe_latchd_hdr_4dw &  pipe_latchd_hdr_pyld & ( (clkd_sot2[0] &  pipe_rtlh_eot[0])   //td set, 4dw,    pay
                                                                                                          | (clkd_sot2[1] &  pipe_rtlh_eot[1])))))

                                         | (!latched_td& ((!pipe_latchd_hdr_4dw & !pipe_latchd_hdr_pyld & ( (clkd_sot[0]  & !pipe_rtlh_eot[0])   //td set, 3dw, no pay
                                                                                                          | (clkd_sot[1]  & !pipe_rtlh_eot[1])))
                                                         |(pipe_latchd_hdr_4dw & !pipe_latchd_hdr_pyld & ( (clkd_sot[0] & !pipe_rtlh_eot[1])   //td set, 4dw, no pay
                                                                                                          | (clkd_sot2[1] & !pipe_rtlh_eot[0])))
                                                         |(!pipe_latchd_hdr_4dw &  pipe_latchd_hdr_pyld & ( (clkd_sot[0]  &  pipe_rtlh_eot[0])   //td set, 3dw,    pay
                                                                                                          | (clkd_sot[1]  &  pipe_rtlh_eot[1])))
                                                         |(pipe_latchd_hdr_4dw &  pipe_latchd_hdr_pyld & ( (clkd_sot[0]  &  pipe_rtlh_eot[1])   //td set, 4dw,    pay
                                                                                                          | (clkd_sot2[1] &  pipe_rtlh_eot[0])))));

      assign tmp_aligned_abort     =  pipe_rtlh_abort_vec[0];    // extra cycle of just ecrc, we need to strip off the control signals

      assign tmp_aligned_ecrc_err  = !ecrc_match_vec[0] & latched_td & (|pipe_rtlh_eot);

      assign tmp_aligned_data      = pipe_rtlh_data[DW_W_PAR-1:0];
// =================== ECRC Stripping END for 64bit interface ==========================

//--------------------------------  
assign data_to_crc = data_to_crc_org; 
lcrc
 #(.NW(NW), .NOUT(RX_TLP), .CRC_MODE(`CX_RTLH), .OPTIMIZE_FOR_1SOT_1EOT(0), .CRC_LATENCY(CRC_LATENCY)) u_lcrc (
    // inputs
    .clk                (core_clk), 
    .rst_n              (core_rst_n),
    .enable_in          (rdlh_rtlh_dv),
    .data_in            (data_to_crc),
    .sot_in             (rdlh_rtlh_sot),
    .eot_in             (rdlh_rtlh_eot),
    .seqnum_in_0        (16'h0),
    .seqnum_in_1        (16'h0),
    // outputs
    .crc_out            (),
    .crc_out_valid      (ecrc_valid_vec),
    .crc_out_match      (ecrc_match_vec),
    .crc_out_match_inv  () // unused in ecrc
);
//--------------------------------


      // a delay to enable striping off the ECRC
      always @(posedge core_clk or negedge core_rst_n)
      if (!core_rst_n) begin
        latchd_aligned_data_int           <= #TP 0;
      end else if (tmp_aligned_dv | (|tmp_aligned_sot)) begin   // The term tmp_aligned_sot is used becaue of the 128bit architecture where the sot and eot can asserted on the same cycle
        latchd_aligned_data_int           <= #TP tmp_aligned_data[DW_W_PAR-1:0];
      end

      always @(posedge core_clk or negedge core_rst_n)
      if (!core_rst_n) begin
        latchd_aligned_eot            <= #TP 0;
        latchd_aligned_abort          <= #TP 0;
        latchd_aligned_dv             <= #TP 0;
        latchd_aligned_ecrc_err       <= #TP 0;
        latchd_aligned_sot            <= #TP 0;
      // Due to the 128bit arch requirement, we need to latch the next sot
      // if it is asserted at the same cycle of eot
      // The term tmp_aligned_sot is used because of the 128bit architecture where the sot and eot can asserted on the same cycle
      end else if (tmp_aligned_dv | (|tmp_aligned_sot)) begin
        latchd_aligned_eot            <= #TP tmp_aligned_eot;
        latchd_aligned_dv             <= #TP pipe_rtlh_dv;
        latchd_aligned_abort          <= #TP tmp_aligned_abort;
        latchd_aligned_ecrc_err       <= #TP tmp_aligned_ecrc_err & !tmp_aligned_abort;  // only report one kind of error
        latchd_aligned_sot            <= #TP tmp_aligned_sot;
      // We need to clear the latch on the cycle that ecrc is stripped and ecrc is a only data valid at this cycle. (i.e ecrc extra)
      end else if (pipe_rtlh_dv) begin
        latchd_aligned_eot            <= #TP 0;
        latchd_aligned_abort          <= #TP 0;
        latchd_aligned_dv             <= #TP 0;
        latchd_aligned_ecrc_err       <= #TP 0;
        latchd_aligned_sot            <= #TP 0;
      end

      // strip off ecrc

      always @(tmp_aligned_dv or latchd_aligned_data or latchd_aligned_sot or latchd_aligned_eot or latchd_aligned_abort
                or latchd_aligned_ecrc_err
                or pipe_latchd_hdr_4dw or clkd_sot or clkd_sot2 or pipe_rtlh_sot
                or latched_td or pipe_rtlh_abort_vec or ecrc_match_vec or pipe_rtlh_eot
                or latchd_aligned_dv or cfg_ecrc_strip_en)
      begin
              int_rtlh_sot               = latchd_aligned_sot       & {NW{tmp_aligned_dv}};
              ecc_rtlh_data              = latchd_aligned_data;
              int_rtlh_eot               = latchd_aligned_eot       & {NW{tmp_aligned_dv}};
              int_rtlh_dv                = latchd_aligned_dv        & tmp_aligned_dv;
              int_rtlh_abort             = latchd_aligned_abort     & tmp_aligned_dv;
              int_rtlh_ecrc_err          = latchd_aligned_ecrc_err  & tmp_aligned_dv;

              // don't strip off ecrc if the header length error
              if (cfg_ecrc_strip_en & latched_td
                  & ( (pipe_rtlh_eot[0] & ~pipe_rtlh_sot[0] & ~clkd_sot[0]  & ~pipe_latchd_hdr_4dw & !(|latchd_aligned_eot))
                    | (pipe_rtlh_eot[0] & ~pipe_rtlh_sot[0] & ~clkd_sot2[1] &  pipe_latchd_hdr_4dw & !(|latchd_aligned_eot)))
                ) begin
                 int_rtlh_eot[NW-1]      = 1'b1;
                 int_rtlh_dv             = 1'b1;
                 int_rtlh_sot            = latchd_aligned_sot;
                 int_rtlh_abort          = pipe_rtlh_abort_vec;
                 int_rtlh_ecrc_err       = !ecrc_match_vec[0] & !pipe_rtlh_abort_vec;
              end
      end

// ----------------------------------------------------------------------------
// Support Functions
// ----------------------------------------------------------------------------

// Only used for parameter calculation
function automatic integer log2floor;
    input integer value;
    begin
        log2floor = 1;
        while(1<<log2floor < value)
            log2floor = log2floor + 1;
    end
endfunction


assign int_rtlh_data      = ecc_rtlh_data;
assign latchd_aligned_data = latchd_aligned_data_int;
assign rtlh_ecrc_parerr = 0;

assign rtlh_ecrc_data =         int_rtlh_data;
assign rtlh_ecrc_sot = 
                       int_rtlh_sot;
assign rtlh_ecrc_dv = 
                       int_rtlh_dv;
assign rtlh_ecrc_eot =          int_rtlh_eot;
assign rtlh_ecrc_abort =        int_rtlh_abort;
assign rtlh_ecrc_err =          int_rtlh_ecrc_err;
assign rtlh_ecrc_len_mismatch = int_rtlh_ecrc_len_mismatch;


`ifndef SYNTHESIS
//VCS coverage off

reg  error_sot;
always @(posedge core_clk or negedge core_rst_n)
   if (!core_rst_n)  begin
       error_sot  <= #TP 0;
   end else begin
       error_sot  <= #TP (|rdlh_rtlh_soh) & (|rdlh_rtlh_eot) & !rdlh_rtlh_abort;
   end

property p_error_sot_chk;
@(posedge core_clk) disable iff (core_rst_n !== 1'b1)
  error_sot === 0;
endproperty

ap_error_sot_chk: assert property (p_error_sot_chk)
else $display("%t: %m: ERROR: Unexpected assertion of error_sot signal: error_sot:= %0d.", $time, error_sot);

//VCS coverage on
`endif // SYNTHESIS



endmodule
