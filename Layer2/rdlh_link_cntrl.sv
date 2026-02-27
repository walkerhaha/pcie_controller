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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh_link_cntrl.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Data Link Layer Handler Link Control
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rdlh_link_cntrl(
    core_clk,
    core_rst_n,
    smlh_link_up,
    cfg_dll_lnk_en,
    rtlh_fci_done,
    rtlh_fci1_fci2,

// outputs
    rdlh_link_up,
    rdlh_link_down,
    rdlh_dlcntrl_state
);
parameter   INST    = 0;                            // The uniquifying parameter for each port logic instance.
parameter   TP      = `TP;                          // Clock to Q delay (simulator insurance)
parameter   NW      = `CX_NW;                       // Number of 32-bit dwords handled by the datapath each clock.
parameter   RX_NDLLP = (NW>>1 == 0) ? 1 : NW>>1;    // Max number of DLLPs received per cycle

// =============================================================
// Parameters
// =============================================================
// The State variable encoding is moved to the include file since other
// blocks shared some of these parameters
// parameter S_DL_INACTIVE = 2'b00;
// parameter S_DL_FC_INIT  = 2'b01;
// parameter S_DL_ACTIVE   = 2'b11;
//
// Updated for Gen4.07 support
// parameter S_DL_FEATURE  = 2'b10

// =============================================================
// Inputs
// =============================================================
input           core_clk;
input           core_rst_n;
input           smlh_link_up;               // MAC layer link up
input           cfg_dll_lnk_en;             // software enable link
input           rtlh_fci_done;              // FC init done indication
input           rtlh_fci1_fci2;             // FC init1 and 2 state

// =============================================================
// Outputs
// =============================================================
output          rdlh_link_up;               // indicates link is up to receive fc2 pkt or fc update or tlps
output          rdlh_link_down;             // indicates link is in the inactive state
output  [1:0]   rdlh_dlcntrl_state;         // data link layer link status

// =============================================================
// IO Declaration
// =============================================================
// Register Outputs
reg             rdlh_link_up;
reg             rdlh_link_down;
reg    [1:0]    rdlh_dlcntrl_state;

// Registers
reg             r_rdlh_link_up;
reg             r_rdlh_link_down;
reg    [1:0]    r_rdlh_dlcntrl_state;



always@(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        r_rdlh_dlcntrl_state                <= #TP `S_DL_INACTIVE;
        r_rdlh_link_up                      <= #TP 1'b0;
        r_rdlh_link_down                    <= #TP 1'b1;
    end else
        case (rdlh_dlcntrl_state)
             `S_DL_INACTIVE: begin
                 r_rdlh_link_up             <= #TP 1'b0;
                 r_rdlh_link_down           <= #TP 1'b1;
                 if(smlh_link_up & cfg_dll_lnk_en)
                     r_rdlh_dlcntrl_state   <= #TP `S_DL_FC_INIT;
                 else
                     r_rdlh_dlcntrl_state   <= #TP `S_DL_INACTIVE;
             end
            `S_DL_FC_INIT: begin
                r_rdlh_link_up              <= #TP rtlh_fci1_fci2;
                r_rdlh_link_down            <= #TP 1'b0;
                if(!smlh_link_up)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_INACTIVE;
                else if(rtlh_fci_done)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_ACTIVE;
                else
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_FC_INIT;
            end

            `S_DL_ACTIVE : begin
                r_rdlh_link_up              <= #TP 1'b1;
                r_rdlh_link_down            <= #TP 1'b0;
                if(!smlh_link_up)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_INACTIVE;
                else
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_ACTIVE;
            end

// mapping S_DL_INACTIVE to default state to facilitate code coverage
            default: begin
                if (smlh_link_up)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_ACTIVE;
                else
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_INACTIVE;
            end

        endcase
   end


// Outputs
always @(*) begin : OUTPUTS
  rdlh_link_up          = r_rdlh_link_up;
  rdlh_link_down        = r_rdlh_link_down;
  rdlh_dlcntrl_state    = r_rdlh_dlcntrl_state;

end

endmodule
