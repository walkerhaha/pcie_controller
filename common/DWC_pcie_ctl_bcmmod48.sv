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
// ---    $DateTime: 2020/09/18 02:33:28 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_ctl_bcmmod48.sv#1 $
// -------------------------------------------------------------------------
// --- Description: modified version of BCM48 part to allow output of
// --- intermediate results - should not be used if DATA_WIDTH is less than
// --- POLY_SIZE
// -------------------------------------------------------------------------

module DWC_pcie_ctl_bcmmod48 (
  data_in,
  // crc_i, // not needed because contribution is already incorporated into data_in, see below
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
//input  [POLY_SIZE-1  : 0]     crc_i; // not needed because contribution is already incorporated into data_in, see below
output [DATA_WIDTH-1  : 0]      crc_j;
reg    [DATA_WIDTH-1  : 0]      crc_j;


// spyglass disable_block W415a
// SMD: Signal may be multiply assigned (beside initialization) in the same scope
// SJ: The design checked and verified that not any one of a single bit of the bus is assigned more than once beside initialization or the multiple assignments are intentional.
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
generate
  if (POLY_SIZE <= DATA_WIDTH) begin :  GEN_ps_le_dw
    always @ (data_in) begin : PROC_mk_mtrx
      integer data_indx;
      reg [POLY_SIZE-1 : 0]     ppsr;
      reg [POLY_SIZE-1 : 0]     tnc;
      integer i, j;


      ppsr = THE_POLY[POLY_SIZE-1:0];
      tnc = {POLY_SIZE{1'b0}};

      for (i=0 ; i < DATA_WIDTH ; i=i+1) begin
        for (j=0 ; j < POLY_SIZE ; j=j+1) begin
          if (ppsr[j] == 1'b1) begin
            tnc[j] = tnc[j] ^ data_in[i]; // the crc_i contribution is already incorporated into data_in that must be equal to flip(data ^ flip32(crc_i)), the flip must be done from dword 0 to the dword with eot
          end
        end // for (j=0...

          if (i==31||i==63||i==95||i==127||i==159||i==191||i==223||i==255||i==287||i==319||i==351||i==383||i==415||i==447||i==479||i==511) crc_j[i+1-POLY_SIZE +: POLY_SIZE] = tnc;
        if (ppsr[POLY_SIZE-1] == 1'b1)
          ppsr = THE_POLY[POLY_SIZE-1:0] ^ {ppsr[POLY_SIZE-2:0], 1'b0};
        else
          ppsr = {ppsr[POLY_SIZE-2:0], 1'b0};

      end // for (i=0...

      // crc_j = tnc;
    end // always
  end else begin :                      GEN_ps_gt_dw
    `ifndef SYNTHESIS
      initial begin
        if(POLY_SIZE > DATA_WIDTH)
        begin
          $display("%0d (%m) ERROR: DATA_WIDTH=%0d is less than POLY_SIZE=%0d, this module does not support this", $time, DATA_WIDTH, POLY_SIZE);
          $finish;
        end
      end
    `endif // SYNTHESIS
  end
endgenerate
// spyglass enable_block W415a
// spyglass enable_block SelfDeterminedExpr-ML

endmodule

