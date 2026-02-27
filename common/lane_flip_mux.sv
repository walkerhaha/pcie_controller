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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/lane_flip_mux.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description: 
// --- Mux for flipping the lanes. Three architectures are provided to implement 
// --- area/timing trade offs: 
// --- (1) CX_AUTO_LANE_FLIP_MUX_ARCH_1STAGE_FULL_ONLY
// ---     Single stage full flip only (simplest architecture).  
// ---     Flip is activated if the control input bit [NL-1] is set.
// --- (2) CX_AUTO_LANE_FLIP_MUX_ARCH_1STAGE_FULL_OR_PARTIAL
// ---     Single stage full or partial flips (second simplest). 
// ---     Flip is activated if one control input bit, [NL-1] or [NL/2-1] or 
// ---     [NL/4-1] etc, is set.
// --- (3) CX_AUTO_LANE_FLIP_MUX_ARCH_2STAGES_FULL_AND_PARTIAL
// ---     Two stages, first is full, second partial (most complex arch).
// ---     The first flip is activated by if the control input bit [NL-1] is set,
// ---     the second flip is activated if a second control input bit, [NL/2-1] 
// ---     or [NL/4-1] etc, is set.
// --- TODO: add an assertion that checks, depending on arch, that 0, 1 or 2 bits at 
// --- most can be set, and that the bits set are in the correct positions within the vector.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"


 module lane_flip_mux 
#(
    parameter RF = 1, // Rx Flip = 1, Tx Flip = 0
    parameter NL = 16,
    parameter WD = 16,
    parameter L2NL = NL==1 ? 1 : `CX_LOGBASE2(NL)  // log2 number of NL
) (
    input [NL*WD-1:0] data,
    input [L2NL-1:0] flip_ctrl,
    input [4:0]      lut, //{force_lane_flip, lane_under_test}
    output [NL*WD-1:0] flipped_data
);

localparam L2NLD2 = `CX_LOGBASE2(NL/2);

reg [NL*WD-1:0] flipped_data_int_1, flipped_data_int_2, flipped_data_int_3, flipped_data_int_4;
wire force_lane_flip;
wire [3:0] lane_under_test;
assign {force_lane_flip, lane_under_test} = lut;
 
always @(*) begin : flipped_data_PROC
    integer i;
    flipped_data_int_1 = data;
    flipped_data_int_2 = data;
    flipped_data_int_3 = data;
    flipped_data_int_4 = data;

  if ( force_lane_flip ) begin // force lane flip. Else the lane under test is enabled only in Loopback.Active at Gen5 rate.
    if ( RF == 1 ) begin // Rx Signals Flip
        for ( i=0; i<NL; i=i+1 ) begin
            if ( i == lane_under_test ) // Only this physical lane lane_under_test is flipped to logical lane 0
                flipped_data_int_4[0 +: WD] = data[i*WD +: WD];
        end
    end else begin // Tx Signals Flip
        for ( i=0; i<NL; i=i+1 ) begin
            if ( i == lane_under_test )
                flipped_data_int_4[i*WD +: WD] = data[0 +: WD];
        end
    end
  end else begin // no the lane under test enabled



    // logic below for CX_AUTO_LANE_FLIP_MUX_ARCH_2STAGES_FULL_AND_PARTIAL
    if ( RF == 1 ) begin // Rx Signals Flip

        // may be first stage full flip 
         if( flip_ctrl[L2NL-1] )
           for(i=0; i<NL; i=i+1) flipped_data_int_1[(NL-1-i)*WD +: WD] = data[i*WD +: WD]; // x16 or x8 or x4 or x2
         else
           flipped_data_int_1 = data;

        // second stage partial flip or single stage partial
        // may be two stages of partial flip
         if( flip_ctrl[L2NLD2-1] )
           for(i=0; i<NL/2; i=i+1) flipped_data_int_2[(NL/2-1-i)*WD +: WD] = flipped_data_int_1[i*WD +: WD]; // x8 or x4 or x2
         else
           flipped_data_int_2 = flipped_data_int_1;

           flipped_data_int_3 = flipped_data_int_2;

           flipped_data_int_4 = flipped_data_int_3;

    end else begin // if ( RF == 1, move to Tx Signals Flip

        // first stage partial flip or single stage full or partial
        // may be two stages of partial flip
           flipped_data_int_1 = data;

           flipped_data_int_2 = flipped_data_int_1;
        
         if(flip_ctrl[L2NLD2-1])
           for(i=0; i<NL/2; i=i+1) flipped_data_int_3[(NL/2-1-i)*WD +: WD] = flipped_data_int_2[i*WD +: WD]; // x8 or x4 or x2
         else
           flipped_data_int_3 = flipped_data_int_2;

        // may be second stage full flip 
         if( flip_ctrl[L2NL-1] )
           for(i=0; i<NL; i=i+1) flipped_data_int_4[(NL-1-i)*WD +: WD] = flipped_data_int_3[i*WD +: WD]; // x16 or x8 or x4 or x2
         else
           flipped_data_int_4 = flipped_data_int_3;

    end // if ( RF == 1

  end // if ( force_lane_flip )
end

assign flipped_data = flipped_data_int_4;

endmodule // lane_flip_mux
