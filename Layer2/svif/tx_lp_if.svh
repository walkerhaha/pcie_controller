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
// ---    $Revision: #1 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/svif/tx_lp_if.svh#1 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__TX_LP_IF__SVH__
`define __GUARD__TX_LP_IF__SVH__

// PCIe Controller Link Layer Physical Layer Transmit Data Transfer Interface
interface tx_lp_if
  
  #(
    NW = `CX_NW
  );

  logic [32 * NW - 1 : 0] data_out;           // Data to be transferred
  logic                   data_valid;         // Data valid indication
  logic                   halt_in;            // Halt the transmission
  logic                   skip_pending;       // SKP OS Pending
  logic                   cmd_is_data;        // Physical layer is waiting for packet start or packet end
  logic [NW - 1 : 0]      stp;                // Indicates which DW contains start of TLP
  logic [NW - 1 : 0]      eot;                // Indicates which DW contains end of TLP/DLLP
  logic [NW - 1 : 0]      sdp;                // Indicates which DW contains start of DLLP
  logic [NW - 1 : 0]      pad;                // Indicates which DW contains PAD symbol
  logic [NW - 1 : 0]      next_stp;           // Indicates the DW containing the next STP
  logic [NW - 1 : 0]      next_eot;           // Indicates the DW containing the next EOT
  logic [NW - 1 : 0]      next_sdp;           // Indicates the DW containing the next SDP

  modport master_mp (
    input   halt_in,
    input   skip_pending,
    input   cmd_is_data,
    output  data_out,
    output  data_valid,
    output  stp,
    output  eot,
    output  sdp,
    output  pad,
    output  next_stp,
    output  next_eot,
    output  next_sdp
  );

  modport slave_mp (
    output  halt_in,
    output  skip_pending,
    output  cmd_is_data,
    input   data_out,
    input   data_valid,
    input   stp,
    input   eot,
    input   sdp,
    input   pad,
    input   next_stp,
    input   next_eot,
    input   next_sdp
  );

//`ifndef SYNTHESIS
//
//// reuse-pragma process_ifdef standard
//`ifdef CX_GEN3_SPEED
//localparam  P_SDP = 16; // 16-Bit SDP Gen3 and above
//`else
//localparam  P_SDP = 8; // 8-Bit SDP in Gen1/Gen2
//`endif
//localparam  P_DLLP_TYPE = 8; // 8-Bits for DLLP Type
//
//// reuse-pragma process_ifdef all_branches
//
//// Decode DLLP Types in the Data Stream and generate a vector of enumerated types for debug purpose
//typedef enum logic [7:0] {
//  Ack                         = 8'b00000000,
//  MRInit                      = 8'b00000001,
//  Data_Link_Feature           = 8'b00000010,
//  Nak                         = 8'b00010000,
//  PM_Enter_L1                 = 8'b00100000,
//  PM_Enter_L23                = 8'b00100001,
//  PM_Active_State_Request_L1  = 8'b00100011,
//  PM_Request_Ack              = 8'b00100100,
//  Vendor                      = 8'b00110000,
//  Nop                         = 8'b00110001,
//  InitFC1_P                   = 8'b01000000,
//  InitFC1_NP                  = 8'b01010000,
//  InitFC1_Cpl                 = 8'b01100000,
//  MRInitFC1                   = 8'b01110000,
//  InitFC2_P                   = 8'b11000000,
//  InitFC2_NP                  = 8'b11010000,
//  InitFC2_Cpl                 = 8'b11100000,
//  MRInitFC2                   = 8'b11110000,
//  UpdateFC_P                  = 8'b10000000,
//  UpdateFC_NP                 = 8'b10010000,
//  UpdateFC_Cpl                = 8'b10100000,
//  MRUpdateFC                  = 8'b10110000,
//  None                        = 8'b11111111   // NO DLLP In this DW
//} dllp_type_e;
//
//// Indicates the type of DLLP per DW in the data path
//// Note this is expanded to the maximum possible NW (16 in 512-bit configurations).
//// 32 : DW0 valid
//// 64 : DW0, DW1 valid
//// 128 : DW0 - DW3 valid
//// 256 : DW0 - DW7 valid
//// 512 : DW0 - DW15 valid
//typedef struct {
//  dllp_type_e DW15;
//  dllp_type_e DW14;
//  dllp_type_e DW13;
//  dllp_type_e DW12;
//  dllp_type_e DW11;
//  dllp_type_e DW10;
//  dllp_type_e DW9;
//  dllp_type_e DW8;
//  dllp_type_e DW7;
//  dllp_type_e DW6;
//  dllp_type_e DW5;
//  dllp_type_e DW4;
//  dllp_type_e DW3;
//  dllp_type_e DW2;
//  dllp_type_e DW1;
//  dllp_type_e DW0;
//} dllp_enc_struct;
//
//// Decoded DLLP's in data stream for < Gen3
//dllp_enc_struct dllp_enc_str;
//// Decoded DLLP's in data stream for >= Gen3
//dllp_enc_struct dllp_gen3_enc_str;
//
//logic [(NW * P_DLLP_TYPE) - 1 : 0]  mask;
//logic [(NW * P_DLLP_TYPE) - 1 : 0]  dllp_type;
//logic [(NW * P_DLLP_TYPE) - 1 : 0]  dllp_type_mask;
//
//// Extract the DLLP Type from the data
//always_comb 
//begin
//  dllp_type = 'h0;
//  mask = 'h0;
//  for(int i = 0; i < NW; i = i + 1)
//  begin
//    // DLLP Type
//    dllp_type[((i*P_DLLP_TYPE) + P_DLLP_TYPE - 1) : (i*P_DLLP_TYPE)] = sdp[i] ? (data_out[(i*32) + P_SDP +: P_DLLP_TYPE]) : 8'hff;
//    // Mask the 3 LSB of the FC DLLP (VC Number)
//    mask[((i*P_DLLP_TYPE) + P_DLLP_TYPE - 1) : (i*P_DLLP_TYPE)] = |(data_out[(i*32) + P_SDP + P_DLLP_TYPE - 1 -: 2]) ? 8'hf8 : 8'hff;
//  end
//end
//
//// mask the dllp type to get rid of the VC numbers (FC DLLP's)
//assign dllp_type_mask = dllp_type & mask; 
//
//// Encode the DLLP Type
//always_comb begin
//  dllp_enc_str = '0;
//  dllp_gen3_enc_str = '0;
//  // Encode each DW of the data path
//  dllp_enc_str.DW0 = dllp_type_e'(dllp_type_mask[P_DLLP_TYPE - 1 : 0]);
//  dllp_gen3_enc_str.DW0 = dllp_type_e'(dllp_type_mask[P_DLLP_TYPE - 1 : 0]);
//  if(NW > 1) begin
//    dllp_enc_str.DW1 = dllp_type_e'(dllp_type_mask[2 * P_DLLP_TYPE - 1 : P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW1 = dllp_type_e'(dllp_type_mask[2 * P_DLLP_TYPE - 1 : P_DLLP_TYPE]);
//  end
//  if(NW > 2) begin
//    dllp_enc_str.DW2 = dllp_type_e'(dllp_type_mask[3 * P_DLLP_TYPE - 1 : 2 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW2 = dllp_type_e'(dllp_type_mask[3 * P_DLLP_TYPE - 1 : 2 * P_DLLP_TYPE]);
//    dllp_enc_str.DW3 = dllp_type_e'(dllp_type_mask[4 * P_DLLP_TYPE - 1 : 3 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW3 = dllp_type_e'(dllp_type_mask[4 * P_DLLP_TYPE - 1 : 3 * P_DLLP_TYPE]);
//  end
//  if(NW > 4) begin
//    dllp_enc_str.DW4 = dllp_type_e'(dllp_type_mask[5 * P_DLLP_TYPE - 1 : 4 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW4 = dllp_type_e'(dllp_type_mask[5 * P_DLLP_TYPE - 1 : 4 * P_DLLP_TYPE]);
//    dllp_enc_str.DW5 = dllp_type_e'(dllp_type_mask[6 * P_DLLP_TYPE - 1 : 5 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW5 = dllp_type_e'(dllp_type_mask[6 * P_DLLP_TYPE - 1 : 5 * P_DLLP_TYPE]);
//    dllp_enc_str.DW6 = dllp_type_e'(dllp_type_mask[7 * P_DLLP_TYPE - 1 : 6 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW6 = dllp_type_e'(dllp_type_mask[7 * P_DLLP_TYPE - 1 : 6 * P_DLLP_TYPE]);
//    dllp_enc_str.DW7 = dllp_type_e'(dllp_type_mask[8 * P_DLLP_TYPE - 1 : 7 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW7 = dllp_type_e'(dllp_type_mask[8 * P_DLLP_TYPE - 1 : 7 * P_DLLP_TYPE]);
//  end
//  if(NW > 8) begin
//    dllp_enc_str.DW8 = dllp_type_e'(dllp_type_mask[9 * P_DLLP_TYPE - 1 : 8 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW8 = dllp_type_e'(dllp_type_mask[9 * P_DLLP_TYPE - 1 : 8 * P_DLLP_TYPE]);
//    dllp_enc_str.DW9 = dllp_type_e'(dllp_type_mask[10 * P_DLLP_TYPE - 1 : 9 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW9 = dllp_type_e'(dllp_type_mask[10 * P_DLLP_TYPE - 1 : 9 * P_DLLP_TYPE]);
//    dllp_enc_str.DW10 = dllp_type_e'(dllp_type_mask[11 * P_DLLP_TYPE - 1 : 10 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW10 = dllp_type_e'(dllp_type_mask[11 * P_DLLP_TYPE - 1 : 10 * P_DLLP_TYPE]);
//    dllp_enc_str.DW11 = dllp_type_e'(dllp_type_mask[12 * P_DLLP_TYPE - 1 : 11 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW11 = dllp_type_e'(dllp_type_mask[12 * P_DLLP_TYPE - 1 : 11 * P_DLLP_TYPE]);
//    dllp_enc_str.DW12 = dllp_type_e'(dllp_type_mask[13 * P_DLLP_TYPE - 1 : 12 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW12 = dllp_type_e'(dllp_type_mask[13 * P_DLLP_TYPE - 1 : 12 * P_DLLP_TYPE]);
//    dllp_enc_str.DW13 = dllp_type_e'(dllp_type_mask[14 * P_DLLP_TYPE - 1 : 13 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW13 = dllp_type_e'(dllp_type_mask[14 * P_DLLP_TYPE - 1 : 13 * P_DLLP_TYPE]);
//    dllp_enc_str.DW14 = dllp_type_e'(dllp_type_mask[15 * P_DLLP_TYPE - 1 : 14 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW14 = dllp_type_e'(dllp_type_mask[15 * P_DLLP_TYPE - 1 : 14 * P_DLLP_TYPE]);
//    dllp_enc_str.DW15 = dllp_type_e'(dllp_type_mask[16 * P_DLLP_TYPE - 1 : 15 * P_DLLP_TYPE]);
//    dllp_gen3_enc_str.DW15 = dllp_type_e'(dllp_type_mask[16 * P_DLLP_TYPE - 1 : 15 * P_DLLP_TYPE]);
//  end
//end
//
//`endif // !SYNTHESIS

endinterface

`endif // __GUARD__TX_LP_IF__SVH__
