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
// ---    $DateTime: 2018/04/16 07:39:02 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_regbus_master.v#5 $
// -------------------------------------------------------------------------
// --- Description: PHY Register Bus Master model
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_regbus_master
#(   
    // constants    
    parameter TP             = 0
) (
input                         pclk,
input                         phy_rst_n,
input       [3:0]             phy_mac_command,
input       [11:0]            phy_mac_address,
input       [7:0]             phy_mac_data,

output  reg                   phy_mac_command_ack,
output  reg [7:0]             phy_mac_messagebus
);

reg         [3:0]             next_bus_state;  // Combination
reg         [1:0]             next_cmd_cycle;  // Combination
reg                           next_last_cycle; // Combination
reg         [3:0]             bus_state;
reg         [1:0]             cmd_cycle;
reg                           last_cycle;      // indicate the last cycle for the command(bus_state timing)
wire                          command_valid;   // timing to set to phy_mac_messagebus
wire                          h_address_valid; // timing to set to phy_mac_messagebus
wire                          l_address_valid; // timing to set to phy_mac_messagebus
wire                          data_valid;      // timing to set to phy_mac_messagebus
reg         [11:0]            acked_address;   // latched phy_mac_address for current command
reg         [7:0]             acked_data;      // latched phy_mac_data    for current command


always @(*) begin
    if( bus_state==`GPHY_CMD_NOP || (`GPHY_SEQCMD_ALLOWED && last_cycle) ) begin
        next_bus_state = phy_mac_command;
        if(phy_mac_command==`GPHY_CMD_NOP) begin
            next_cmd_cycle = 2'b00;
        end else begin
            next_cmd_cycle = 2'b01;
        end
    end else if(!`GPHY_SEQCMD_ALLOWED && last_cycle) begin // a NOP required before next command
        next_bus_state = `GPHY_CMD_NOP;
        next_cmd_cycle = 2'b00;
    end else begin
        next_bus_state = bus_state;
        next_cmd_cycle = cmd_cycle + 2'b01;
    end
end

always @(*) begin
    if(
       (next_bus_state==`GPHY_CMD_WR_UC  && next_cmd_cycle==`GPHY_NCYCLE_WR)
     ||(next_bus_state==`GPHY_CMD_WR_C   && next_cmd_cycle==`GPHY_NCYCLE_WR)
     ||(next_bus_state==`GPHY_CMD_RD     && next_cmd_cycle==`GPHY_NCYCLE_RD)
     ||(next_bus_state==`GPHY_CMD_RD_CPL && next_cmd_cycle==`GPHY_NCYCLE_RD_CPL)
     ||(next_bus_state==`GPHY_CMD_WR_ACK && next_cmd_cycle==`GPHY_NCYCLE_WR_ACK)
    ) begin
        next_last_cycle = 1'b1;
    end else begin
        next_last_cycle = 1'b0;
    end
end

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        bus_state  <= #TP `GPHY_CMD_NOP;
        cmd_cycle  <= #TP 3'b000;
        last_cycle <= #TP 1'b0;
    end else begin
        bus_state  <= #TP next_bus_state;
        cmd_cycle  <= #TP next_cmd_cycle;
        last_cycle <= #TP next_last_cycle;
    end
end

assign command_valid =
            (next_bus_state==`GPHY_CMD_WR_UC  && next_cmd_cycle==2'b01) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_WR_C   && next_cmd_cycle==2'b01) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_RD     && next_cmd_cycle==2'b01) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_RD_CPL && next_cmd_cycle==2'b01) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_WR_ACK && next_cmd_cycle==2'b01) ? 1'b1 :
                                                                     1'b0 ;
assign h_address_valid =
            (next_bus_state==`GPHY_CMD_WR_UC  && next_cmd_cycle==2'b01) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_WR_C   && next_cmd_cycle==2'b01) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_RD     && next_cmd_cycle==2'b01) ? 1'b1 :
                                                                     1'b0 ;
assign l_address_valid =
            (next_bus_state==`GPHY_CMD_WR_UC  && next_cmd_cycle==2'b10) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_WR_C   && next_cmd_cycle==2'b10) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_RD     && next_cmd_cycle==2'b10) ? 1'b1 :
                                                                     1'b0 ;
assign data_valid =
            (next_bus_state==`GPHY_CMD_WR_UC  && next_cmd_cycle==2'b11) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_WR_C   && next_cmd_cycle==2'b11) ? 1'b1 :
            (next_bus_state==`GPHY_CMD_RD_CPL && next_cmd_cycle==2'b10) ? 1'b1 :
                                                                     1'b0 ;

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        acked_address <= #TP 12'h000;
        acked_data    <= #TP 8'h00;
    end else begin
      if(phy_mac_command_ack) begin
        acked_address <= #TP phy_mac_address;
        acked_data    <= #TP phy_mac_data;
      end
    end
end

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        phy_mac_messagebus <= #TP 8'h00; // NOP
    end else begin
      if(command_valid) begin
          phy_mac_messagebus <= #TP (h_address_valid) ? {phy_mac_command, phy_mac_address[11:8]} : {phy_mac_command, 4'h0};
      end else if(l_address_valid) begin
          phy_mac_messagebus <= #TP acked_address[7:0];
      end else if(data_valid) begin
          phy_mac_messagebus <= #TP acked_data;
      end else begin
          phy_mac_messagebus <= #TP 8'h00;
      end
    end
end

always @( posedge pclk or negedge phy_rst_n ) begin
    if ( !phy_rst_n ) begin
        phy_mac_command_ack <= #TP 1'b1;
    end else begin
        if(phy_mac_command!=`GPHY_CMD_NOP
        && phy_mac_command_ack
        && !(`GPHY_SEQCMD_ALLOWED && next_last_cycle)
        ) begin
            phy_mac_command_ack <= #TP 1'b0;
        end else if(`GPHY_SEQCMD_ALLOWED && next_last_cycle) begin
            phy_mac_command_ack <= #TP 1'b1;
        end else if(!`GPHY_SEQCMD_ALLOWED && last_cycle) begin // a NOP required before next command
            phy_mac_command_ack <= #TP 1'b1;
        end
    end
end

// -------------------------------------------------------------------------
wire [(34*8)-1:0] BUS_STATE;
wire [(34*8)-1:0] BUS_ADDRESS;
assign BUS_STATE = ( bus_state == `GPHY_CMD_NOP    ) ? "No Command"        :
                   ( bus_state == `GPHY_CMD_WR_UC  ) ? "Write Uncommitted" :
                   ( bus_state == `GPHY_CMD_WR_C   ) ? "Write Committed"   :
                   ( bus_state == `GPHY_CMD_RD     ) ? "Read"              :
                   ( bus_state == `GPHY_CMD_RD_CPL ) ? "Read Completion"   :
                   ( bus_state == `GPHY_CMD_WR_ACK ) ? "Write Ack"         : "UNKNOWN";
assign BUS_ADDRESS = ( bus_state   == `GPHY_CMD_NOP   ) ? "No Command"           :
                     ( bus_state   == `GPHY_CMD_RD_CPL) ? "No Command"           :
                     ( bus_state   == `GPHY_CMD_WR_ACK) ? "No Command"           :
                     ( acked_address == `GPHY_MAC_REG_RX_MARIN_STATUS0            ) ? "RX1: RX Margin Status0" :
                     ( acked_address == `GPHY_MAC_REG_RX_MARIN_STATUS1            ) ? "RX1: RX Margin Status1" :
                     ( acked_address == `GPHY_MAC_REG_RX_MARIN_STATUS2            ) ? "RX1: RX Margin Status2" :
                     ( acked_address == `GPHY_MAC_REG_EBUF_STATUS                 ) ? "RX1: Elastic Buffer Status" :
                     ( acked_address == `GPHY_MAC_REG_EBUF_LOCATION               ) ? "RX1: Elastic Buffer Location" :
                     ( acked_address == `GPHY_MAC_REG_RX_LINK_EVAL_STATUS0        ) ? "RX1: RX Link Evaluation Status0" :
                     ( acked_address == `GPHY_MAC_REG_RX_LINK_EVAL_STATUS1        ) ? "RX1: RX Link Evaluation Status1" :
                     ( acked_address == `GPHY_MAC_REG_TX_STATUS0                  ) ? "TX1: TX Status0" :
                     ( acked_address == `GPHY_MAC_REG_TX_STATUS1                  ) ? "TX1: TX Status1" :
                     ( acked_address == `GPHY_MAC_REG_TX_STATUS2                  ) ? "TX1: TX Status2" :
                     ( acked_address == `GPHY_MAC_REG_TX_STATUS3                  ) ? "TX1: TX Status3" :
                     ( acked_address == `GPHY_MAC_REG_TX_STATUS4                  ) ? "TX1: TX Status4" :
                     ( acked_address == `GPHY_MAC_REG_TX_STATUS5                  ) ? "TX1: TX Status5" :
                     ( acked_address == `GPHY_MAC_REG_TX_STATUS6                  ) ? "TX1: TX Status6" :
                     ( acked_address == `GPHY_MAC_REG_TX_STATUS7                  ) ? "TX1: TX Status7" :
                     ( acked_address == `GPHY_MAC_REG_TX_STATUS8                  ) ? "TX1: TX Status8" :
                     ( acked_address == `GPHY_MAC_REG_VDR_ESM_CALIBRATE_COMPLETE  ) ? "VDR : ESM Calibration Complete" :
                                                                                      "UNKNOWN";

endmodule // DWC_pcie_gphy_regbus_master
