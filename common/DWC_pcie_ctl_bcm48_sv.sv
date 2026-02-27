
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

//
// Filename    : DWC_pcie_ctl_bcm48_sv.v
// Revision    : $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_ctl_bcm48_sv.sv#1 $
// Author      : Rick Kelly      June 11, 2010
// Description : DWC_pcie_ctl_bcm48_sv.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 60dbdead
//
////////////////////////////////////////////////////////////////////////////////

module DWC_pcie_ctl_bcm48_sv (
        data_in,
        crc_i,
        crc_j
        );

parameter DATA_WIDTH = 16;      // RANGE 1 to 1024
parameter POLY_SIZE  = 16;      // RANGE 2 to 64
parameter POLY_COEF0 = 4129;    // RANGE 1 to 65535
parameter POLY_COEF1 = 0;       // RANGE 0 to 65535
parameter POLY_COEF2 = 0;       // RANGE 0 to 65535
parameter POLY_COEF3 = 0;       // RANGE 0 to 65535

localparam [63 : 0] THE_POLY =          ((POLY_COEF3 & 65535) << 48) +
                                        ((POLY_COEF2 & 65535) << 32) +
                                        ((POLY_COEF1 & 65535) << 16) +
                                         (POLY_COEF0 & 65535);

input  [DATA_WIDTH-1 : 0]       data_in;
input  [POLY_SIZE-1  : 0]       crc_i;
output [POLY_SIZE-1  : 0]       crc_j;

reg    [POLY_SIZE-1 : 0]        crc_j_int;

// Function: calc_matrix
//   Calculates a 2-dimensional matrix describing how
//   input bits contribute to the CRC output based on
//   the specified polynomial
function automatic [POLY_SIZE-1:0][DATA_WIDTH-1:0] calc_cm;
  begin : calc_cm_FUNC
    reg [POLY_SIZE-1:0][DATA_WIDTH-1:0] rtnval;
    integer f_i, f_j;

    for (f_j=0 ; f_j < POLY_SIZE ; f_j=f_j+1) begin
      rtnval[f_j][0] = THE_POLY[f_j];
    end

    for (f_i=0 ; f_i < DATA_WIDTH-1 ; f_i=f_i+1) begin
      if (rtnval[POLY_SIZE-1][f_i] == 1'b1) begin
        rtnval[0][f_i+1] = THE_POLY[0];
        for (f_j=0 ; f_j<POLY_SIZE-1 ; f_j=f_j+1) begin
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
          rtnval[f_j+1][f_i+1] = rtnval[f_j][f_i] ^ THE_POLY[f_j+1];
// spyglass enable_block SelfDeterminedExpr-ML
        end
      end else begin
        rtnval[0][f_i+1] = 1'b0;
        for (f_j=0 ; f_j<POLY_SIZE-1 ; f_j=f_j+1) begin
          rtnval[f_j+1][f_i+1] = rtnval[f_j][f_i];
        end
      end
    end

    calc_cm = rtnval;
  end
endfunction

localparam [POLY_SIZE-1:0][DATA_WIDTH-1:0] CM = calc_cm();


generate
  if (DATA_WIDTH < POLY_SIZE) begin : GEN_DW_LT_PS
    always @ (data_in or crc_i) begin : mk_co_int_PROC
      integer a_i;
      reg [DATA_WIDTH-1:0] in_vect;
      reg [POLY_SIZE-1:0] ci_resid;

      in_vect = data_in ^ crc_i[POLY_SIZE-1:POLY_SIZE-DATA_WIDTH];
      ci_resid = {crc_i[POLY_SIZE-DATA_WIDTH-1:0],{DATA_WIDTH{1'b0}}};

      for (a_i=0 ; a_i < POLY_SIZE ; a_i=a_i+1) begin
        crc_j_int[a_i] = ^(in_vect & CM[a_i]) ^ ci_resid[a_i];
      end
    end
  end else begin : GEN_DW_GE_PS
    always @ (data_in or crc_i) begin : mk_co_int_PROC
      integer a_i;
      reg [DATA_WIDTH-1:0] in_vect;

      in_vect = data_in ^ ({crc_i,{(DATA_WIDTH-POLY_SIZE){1'b0}}});

      for (a_i=0 ; a_i < POLY_SIZE ; a_i=a_i+1) begin
        crc_j_int[a_i] = ^(in_vect & CM[a_i]);
      end
    end
  end
endgenerate

  assign crc_j = crc_j_int;

endmodule
