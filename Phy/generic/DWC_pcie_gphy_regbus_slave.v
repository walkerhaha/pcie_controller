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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_regbus_slave.v#5 $
// -------------------------------------------------------------------------
// --- Description: PHY Register Bus Slave model
// ----------------------------------------------------------------------------

module DWC_pcie_gphy_regbus_slave
#(
    parameter TP             = 0
) (
input                         pclk,
input                         phy_rst_n,
input       [7:0]             mac_phy_messagebus,

output  reg [3:0]             mac_phy_command,
output  reg [11:0]            mac_phy_address,
output  reg [7:0]             mac_phy_data
);

reg         [3:0]             next_bus_state;  // Combination
reg         [1:0]             next_cmd_cycle;  // Combination
reg                           next_last_cycle; // Combination
reg         [3:0]             bus_state;
reg         [1:0]             cmd_cycle;
reg                           last_cycle;      // indicate the last cycle for the command(bus_state timing)
wire                          command_valid;   // timing to get from mac_phy_messagebus
wire                          h_address_valid; // timing to get from mac_phy_messagebus
wire                          l_address_valid; // timing to get from mac_phy_messagebus
wire                          data_valid;      // timing to get from mac_phy_messagebus
reg         [11:0]            latched_address; // latched mac_phy_messagebus for current command


always @(*) begin
    if( bus_state==`GPHY_CMD_NOP || (`GPHY_SEQCMD_ALLOWED && last_cycle) ) begin
        next_bus_state = mac_phy_messagebus[7:4];
        if(mac_phy_messagebus[7:4]==`GPHY_CMD_NOP) begin
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
        latched_address <= #TP 12'h000;
    end else begin
      if(h_address_valid) begin
        latched_address <= #TP {mac_phy_messagebus[3:0], 8'h00};
      end else if(l_address_valid) begin
        latched_address <= #TP {latched_address[11:8], mac_phy_messagebus};
      end else if(next_last_cycle) begin
        latched_address <= #TP 12'h000;
      end
    end
end

always @(*) begin
    if(next_last_cycle) begin
        mac_phy_command = next_bus_state;
        mac_phy_address = (l_address_valid) ? {latched_address[11:8], mac_phy_messagebus} : latched_address;
        mac_phy_data    = (data_valid)      ?                         mac_phy_messagebus  :           8'h00;
    end else begin
        mac_phy_command = `GPHY_CMD_NOP;
        mac_phy_address = 12'h000;
        mac_phy_data    = 8'h00;
    end
end

// -------------------------------------------------------------------------
wire [(34*8)-1:0] BUS_STATE;
wire [(34*8)-1:0] BUS_ADDRESS;
assign BUS_STATE   = ( bus_state == `GPHY_CMD_NOP    ) ? "No Command"        :
                     ( bus_state == `GPHY_CMD_WR_UC  ) ? "Write Uncommitted" :
                     ( bus_state == `GPHY_CMD_WR_C   ) ? "Write Committed"   :
                     ( bus_state == `GPHY_CMD_RD     ) ? "Read"              :
                     ( bus_state == `GPHY_CMD_RD_CPL ) ? "Read Completion"   :
                     ( bus_state == `GPHY_CMD_WR_ACK ) ? "Write Ack"         : "UNKNOWN";
assign BUS_ADDRESS = ( bus_state == `GPHY_CMD_NOP    ) ? "N/A" :
                     ( bus_state == `GPHY_CMD_RD_CPL ) ? "N/A" :
                     ( bus_state == `GPHY_CMD_WR_ACK ) ? "N/A" :
                     ( mac_phy_address == `GPHY_PHY_REG_RX_MARGIN_CONTROL0  ) ? "RX1: RX Margin Control0" :
                     ( mac_phy_address == `GPHY_PHY_REG_RX_MARGIN_CONTROL1  ) ? "RX1: RX Margin Control1" :
                     ( mac_phy_address == `GPHY_PHY_REG_EBUF_CONTROL        ) ? "Elastic Buffer Control" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_RX_CONTROL0     ) ? "RX1: PHY RX Control0" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_RX_CONTROL3     ) ? "RX1: PHY RX Control3" :
                     ( mac_phy_address == `GPHY_PHY_REG_EBUF_LOC_UPD_FREQ   ) ? "RX1: Elastic Buffer Location Update Frequency" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_RX_CONTROL4     ) ? "RX1: PHY RX Control4" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_TX_CONTROL2     ) ? "TX1: PHY TX Control2" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_TX_CONTROL3     ) ? "TX1: PHY TX Control3" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_TX_CONTROL4     ) ? "TX1: PHY TX Control4" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_TX_CONTROL5     ) ? "TX1: PHY TX Control5" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_TX_CONTROL6     ) ? "TX1: PHY TX Control6" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_TX_CONTROL7     ) ? "TX1: PHY TX Control7" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_TX_CONTROL8     ) ? "TX1: PHY TX Control8" :
                     ( mac_phy_address == `GPHY_PHY_REG_PHY_CMN_CONTROL0    ) ? "CMN1: PHY Common Control0" :
                     ( mac_phy_address == `GPHY_PHY_REG_VDR_ESM_RATE0       ) ? "VDR: ESM Rate0" :
                     ( mac_phy_address == `GPHY_PHY_REG_VDR_ESM_RATE1       ) ? "VDR: ESM Rate1" :
                     ( mac_phy_address == `GPHY_PHY_REG_VDR_ESM_CONTROL     ) ? "VDR: ESM Control" :
                                                                                "UNKNOWN";
endmodule // DWC_pcie_gphy_regbus_slave
