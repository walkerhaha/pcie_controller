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
// ---    $DateTime: 2019/10/17 11:13:56 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/xadm_tracker.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module tracks TLP's through the XADM and generates a pending flag
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xadm_tracker
  // Parameters
  #(
    parameter CX_CCIX_HDR_WD  = 128,
    parameter NW              = 4,
    parameter TP              = `TP,
    parameter NVC_XALI_EXP    = `CX_NVC_XALI_EXPANSION   // Max number of Virtual Channels used on Xali Expansion
  ) (
    // Inputs
    input                      core_clk,
    input                      core_rst_n,
    input                      msg_gen_hv,           // Header valid from internal message generation
    input                      xadm_msg_halt,        // XADM halt to the msg_gen
    input                      lbc_cpl_hv,           // Header valid from internal LBC module, which handles the CPL generation
    input                      xadm_cpl_halt,        // XADM halt to the LBC
    input [NVC_XALI_EXP-1:0]   client0_tlp_hv,       // Client0 header valid
    input [NVC_XALI_EXP-1:0]   client0_tlp_bad_eot,  // Client0 bad eot
    input [NVC_XALI_EXP-1:0]   xadm_client0_halt,    // XADM halt to client0
    input [NVC_XALI_EXP-1:0]   client1_tlp_hv,       // Client1 header valid
    input [NVC_XALI_EXP-1:0]   client1_tlp_bad_eot,  // Client1 bad eot
    input [NVC_XALI_EXP-1:0]   xadm_client1_halt,    // XADM halt to client1
    input                      xadm_halted,          // XADM halt indication
    input                      xadm_xtlh_eot,        // XADM eot to XTLH
    input                      pm_block_all_tlp,     // PM request to block TLP transmission
    input                      xadm_mux_idle,        // XADM arbiter is in the IDLE state
    // Outputs
    output  logic              xadm_tlp_pending,     // XADM TLP pending indication
    output  logic              xadm_block_tlp_ack_r  // TLP transmission blocked
);


localparam XADM_FORMATION_REGIN = `CX_XADM_FORMATION_REGIN;
localparam HV_CNT_WD    = 5;
localparam HV_CNT_WD_VC = HV_CNT_WD * NVC_XALI_EXP;
//localparam CNT_WD = 3;
localparam CNT_WD = HV_CNT_WD * NVC_XALI_EXP;
localparam NVC                  = `CX_NVC;                     // Number of virtual channels

logic [CNT_WD : 0]          int_tlp_cnt_b;
logic [CNT_WD : 0]          int_tlp_cnt_r;
logic [(HV_CNT_WD_VC-1):0]  int_hv_cnt;
logic int_xtlh_grant;
logic int_dec_cnt;
logic int_inc_cnt;
logic [(HV_CNT_WD_VC - 1) : 0] int_hv_req;
logic [(HV_CNT_WD_VC - 1) : 0] int_native_hv_req;
logic                       int_block_tlp_ack_b;

logic [NVC_XALI_EXP-1:0] msg_gen_hv_int;
logic [NVC_XALI_EXP-1:0] xadm_msg_halt_int;
logic [NVC_XALI_EXP-1:0] lbc_cpl_hv_int;
logic [NVC_XALI_EXP-1:0] xadm_cpl_halt_int;



genvar k;
generate

for (k=0; k< NVC_XALI_EXP ; k = k + 1) begin

if (k==0) begin
assign msg_gen_hv_int[k]    = msg_gen_hv;
assign xadm_msg_halt_int[k] = xadm_msg_halt;
assign lbc_cpl_hv_int[k]    = lbc_cpl_hv;
assign xadm_cpl_halt_int[k] = xadm_cpl_halt;
end else begin
assign msg_gen_hv_int[k]    = 1'b0;
assign xadm_msg_halt_int[k] = 1'b1;
assign lbc_cpl_hv_int[k]    = 1'b0;
assign xadm_cpl_halt_int[k] = 1'b1;
end

assign int_native_hv_req[k*HV_CNT_WD+:HV_CNT_WD] = (
                            {(msg_gen_hv_int[k] && !xadm_msg_halt_int[k]),
                             (lbc_cpl_hv_int[k] && !xadm_cpl_halt_int[k]),
                             (client0_tlp_hv[k] && !client0_tlp_bad_eot[k] && !xadm_client0_halt[k])
                              ,(client1_tlp_hv[k] && !client1_tlp_bad_eot[k] && !xadm_client1_halt[k])
                               ,1'b0
                            }
                            );
end
endgenerate

assign int_hv_req = int_native_hv_req;

always_comb begin : hv_cnt_PROC
  integer i;
  int_hv_cnt = {HV_CNT_WD_VC{1'b0}};
  for(i = 0; i < HV_CNT_WD_VC; i = i + 1) begin
    if(int_hv_req[i])
      int_hv_cnt = int_hv_cnt + 1'b1;
  end
end : hv_cnt_PROC


// Decrement the counter when the TLP is accepted by Layer3 if no new TLP is pending
assign int_xtlh_grant = xadm_xtlh_eot && !xadm_halted;
assign int_dec_cnt = (( int_xtlh_grant )  && !(|int_hv_req));
// Increment the counter when a new TLP is pending and no TLP is being accepted by Layer3
assign int_inc_cnt = |int_hv_req;

// Track the number of TLP's requests from the XADM interfaces
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The TLP counter maximum value is constrained by the datapath so by design the counter cannot overflow.
always_comb begin : tx_cnt_PROC
  if(int_inc_cnt)
    int_tlp_cnt_b = int_tlp_cnt_r + (int_hv_cnt - int_xtlh_grant 
                                    );
  else if(int_dec_cnt)
    int_tlp_cnt_b = int_tlp_cnt_r - int_xtlh_grant
                                        ;
  else
    int_tlp_cnt_b = int_tlp_cnt_r;
end : tx_cnt_PROC
// spyglass enable_block W164a

always_ff @(posedge core_clk or negedge core_rst_n) begin : tx_mon_PROC
  if(!core_rst_n) begin
    int_tlp_cnt_r         <= #TP {CNT_WD{1'b0}};
    xadm_block_tlp_ack_r  <= #TP 1'b0;
  end else begin
    int_tlp_cnt_r         <= #TP int_tlp_cnt_b;
    xadm_block_tlp_ack_r  <= #TP int_block_tlp_ack_b;
  end
end

assign xadm_tlp_pending = !(int_tlp_cnt_r == {CNT_WD{1'b0}});

// No TLP Pending and arbiter is idle so acknowledge the request to block TLP's
assign int_block_tlp_ack_b = pm_block_all_tlp && !xadm_tlp_pending && xadm_mux_idle;



endmodule
