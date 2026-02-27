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
// ---    $DateTime: 2018/08/30 02:24:02 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_int_req.sv#2 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles one virtual INTx
// --- (1) Assertion or deassertion of INTx would trigger assert or deassert INT MSG
// --- (2) cfg_int_disable bit set when INTx is active would trigger deassert INT MSG
// --- (2) link down status when INTx is active would trigger deassert INT MSG
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_int_req (
    // Inputs
    core_rst_n,
    core_clk,
    int_wire,
    assert_int_grt,
    deassert_int_grt,
    cfg_int_disable,

    // Outputs
    assert_int_req,
    deassert_int_req
);
parameter INST      = 0;            // The uniquifying parameter for each port logic instance.
parameter TP        = `TP;          // Clock to Q delay (simulator insurance)

input           core_rst_n;
input           core_clk;
input           int_wire;           // external interrupt signal (level)
input           assert_int_grt;     // grant assert_int MSG
input           deassert_int_grt;   // grant deassert_int MSG
input           cfg_int_disable;    // interrupt disable bit in command register

output          assert_int_req;     // assert_int req
output          deassert_int_req;   // deassrt_int req

reg             cfg_int_disable_a;
reg             int_wire_a;
reg             assert_int_req;
reg             deassert_int_req;
wire            assert_int_pulse;
wire            deassert_int_pulse;

// capture the rising edge of int_wire
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        int_wire_a          <= #TP 0;
        cfg_int_disable_a   <= #TP 0;
    end
    else begin
        int_wire_a          <= #TP int_wire;
        cfg_int_disable_a   <= #TP cfg_int_disable;
    end
end

assign assert_int_pulse = ~int_wire_a & int_wire & ~cfg_int_disable;

// Any INTx virtual wires that are active when the Interrupt Disable bit is set
// must be deasserted by transmitting the appropriate Deassert_INTx MEssages
assign deassert_int_pulse = (int_wire_a & ~int_wire & ~cfg_int_disable)
                          | (~cfg_int_disable_a & cfg_int_disable & int_wire);

//
// State machine for Interrupt
//
// inputs to state machine: assert_int_pulse, deassert_int_pulse, assert_int_grt, deassert_int_grt
// outputs of state machine: assert_int_req, deassert_int_req
//
parameter S_IDLE    = 3'b000;   // No messages requests are pending
parameter S_A_0     = 3'b001;   // Assert message request is pending
parameter S_A_D     = 3'b011;   // Assert message request followed by Deassert message are pending
parameter S_D_0     = 3'b010;   // Deassert message request is pending
parameter S_D_A     = 3'b110;   // Deassert message request followed by Assert message are pending

reg [2:0]   int_state;

always@(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        int_state       <= #TP S_IDLE;
        assert_int_req  <= #TP 0;
        deassert_int_req<= #TP 0;
    end else begin
      // spyglass disable_block STARC05-2.11.3.1
      // SMD: Combinational and sequential parts of an FSM described in same always block 
      // SJ: Legacy code
        case (int_state)
            // No messages requests are pending
            S_IDLE: begin
                if (deassert_int_pulse) begin
                    int_state       <= #TP S_D_0;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 1'b1;
                end else if (assert_int_pulse) begin
                    int_state       <= #TP S_A_0;
                    assert_int_req  <= #TP 1'b1;
                    deassert_int_req<= #TP 0;
                end else begin
                    int_state       <= #TP S_IDLE;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 0;
                end
            end
            // Assert message request is pending
            S_A_0: begin
                if (assert_int_grt & deassert_int_pulse) begin
                    int_state       <= #TP S_D_0;
                    assert_int_req  <= #TP 0;
                   deassert_int_req<= #TP 1'b1;
                end else if (assert_int_grt) begin
                    int_state       <= #TP S_IDLE;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 0;
                end else if (deassert_int_pulse) begin
                    int_state       <= #TP S_A_D;
                    assert_int_req  <= #TP 1'b1;
                    deassert_int_req<= #TP 0;
                end else begin
                    int_state       <= #TP S_A_0;
                    assert_int_req  <= #TP 1'b1;
                    deassert_int_req<= #TP 0;
                end
            end
            // Assert message request followed by Deassert message are pending
            S_A_D: begin
                if (assert_int_pulse & assert_int_grt) begin
                    int_state       <= #TP S_IDLE;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 0;
                end else if (assert_int_pulse) begin
                    int_state       <= #TP S_A_0;
                    assert_int_req  <= #TP 1'b1;
                    deassert_int_req<= #TP 0;
                end else if (assert_int_grt) begin
                    int_state       <= #TP S_D_0;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 1'b1;
                end else begin
                    int_state       <= #TP S_A_D;
                    assert_int_req  <= #TP 1'b1;
                    deassert_int_req<= #TP 0;
                end
            end
            // Deassert message request is pending
            S_D_0: begin
                if (deassert_int_grt & assert_int_pulse) begin
                    int_state       <= #TP S_A_0;
                    assert_int_req  <= #TP 1'b1;
                    deassert_int_req<= #TP 0;
                end else if (deassert_int_grt) begin
                    int_state       <= #TP S_IDLE;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 0;
                end else if (assert_int_pulse) begin
                    int_state       <= #TP S_D_A;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 1'b1;
                end else begin
                    int_state       <= #TP S_D_0;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 1'b1;
                end
            end
            // Deassert message request followed by Assert message are pending
            S_D_A: begin
                if (deassert_int_pulse & deassert_int_grt) begin
                    int_state       <= #TP S_IDLE;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 0;
                end else if (deassert_int_pulse) begin
                    int_state       <= #TP S_D_0;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 1'b1;
                end else if (deassert_int_grt) begin
                    int_state       <= #TP S_A_0;
                    assert_int_req  <= #TP 1'b1;
                    deassert_int_req<= #TP 0;
                end else begin
                    int_state       <= #TP S_D_A;
                    assert_int_req  <= #TP 0;
                    deassert_int_req<= #TP 1'b1;
                end
            end
            default: begin
                assert_int_req  <= #TP 0;
                deassert_int_req<= #TP 0;
                int_state       <= #TP S_IDLE;
            end
        endcase
      // spyglass enable_block STARC05-2.11.3.1
    end
end

`ifndef SYNTHESIS
wire [4*8:0] STATE;

assign  STATE = (int_state == S_IDLE) ? "IDLE"  :
                (int_state == S_A_0 ) ? "A_0"   :
                (int_state == S_A_D ) ? "A_D"   :
                (int_state == S_D_0 ) ? "D_0"   :
                (int_state == S_D_A ) ? "D_A"   : "BOGUS";

`endif // SYNTHESIS

endmodule
