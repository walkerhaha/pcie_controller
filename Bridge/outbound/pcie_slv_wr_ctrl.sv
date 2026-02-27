// ----------------------------------------------------------------------------
//
// AXI Slave Write Channel Controller for PCIe Outbound Writes
//
// Module Description:
// This module implements the AXI4 slave write channel (W-channel) interface
// for the PCIe controller's slave port 0. It converts AXI write transactions
// into PCIe Posted Write TLPs via the xadm client0 interface.
//
// Root-cause fix:
//   When performing outbound writes, pcie_slv0_wvalid was raised and never
//   reset because the AXI slave write channel had no logic to assert wready
//   and track write-burst completion. Without wready, the AXI master holds
//   wvalid high indefinitely. This module provides:
//     1. Combinational wready driven directly by the write-burst FSM state
//        and xadm back-pressure (xadm_client0_halt).  Making wready
//        combinational ensures the master and this module always agree on
//        when a handshake has occurred, eliminating mid-burst race conditions.
//     2. A write-burst FSM that transitions to ST_BRESP on wlast, taking
//        the FSM out of ST_DATA and deasserting wready — the master then
//        deasserts wvalid next cycle.
//     3. client0_tlp_hv/dv/eot generation so the xadm arbiter can grant
//        client0 and eventually release xadm_client0_halt.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module pcie_slv_wr_ctrl
  #(
    parameter TP       = `TP,   // Clock-to-Q delay
    parameter DATA_WD  = 64,    // AXI write-data bus width
    parameter STRB_WD  = DATA_WD / 8,
    parameter ADDR_WD  = 64,    // AXI address width
    // LEN_WD carries the PCIe TLP byte count (13 bits per the PCIe spec
    // Length field), not the standard AXI4 beat-count awlen field.  The
    // PCIe byte-length maps directly to the TLP Length without conversion.
    parameter LEN_WD   = 13
   )
  (
    // ----- Clocks / Resets -----
    input  wire                  clk,
    input  wire                  rst_n,

    // ----- AXI4 Slave Write Address Channel (port 0) -----
    input  wire                  pcie_slv0_awvalid,
    output reg                   pcie_slv0_awready,
    input  wire [ADDR_WD-1:0]    pcie_slv0_awaddr,
    input  wire [LEN_WD-1:0]     pcie_slv0_awbyte_len, // PCIe byte length (not AXI4 awlen)
    input  wire [2:0]            pcie_slv0_awtc,       // traffic class
    input  wire [1:0]            pcie_slv0_awattr,     // PCIe attributes (relaxed-ordering, no-snoop)

    // ----- AXI4 Slave Write Data Channel (port 0) -----
    // pcie_slv0_wvalid is driven by the AXI master and stays at 1 until
    // pcie_slv0_wready is asserted.  This module provides that wready as a
    // combinational output so that the master and this module always agree on
    // when a handshake occurs, preventing mid-burst back-pressure races.
    input  wire                  pcie_slv0_wvalid,
    output wire                  pcie_slv0_wready,     // combinational output
    input  wire [DATA_WD-1:0]    pcie_slv0_wdata,
    input  wire [STRB_WD-1:0]    pcie_slv0_wstrb,
    input  wire                  pcie_slv0_wlast,      // last beat of the burst

    // ----- AXI4 Slave Write Response Channel (port 0) -----
    output reg                   pcie_slv0_bvalid,
    input  wire                  pcie_slv0_bready,

    // ----- xadm client0 TLP submission interface -----
    input  wire                  xadm_client0_halt, // back-pressure from xadm
    output reg                   client0_tlp_hv,    // TLP header valid
    output reg  [1:0]            client0_tlp_fmt,   // TLP format
    output reg  [4:0]            client0_tlp_type,  // TLP type
    output reg  [2:0]            client0_tlp_tc,    // traffic class
    output reg  [1:0]            client0_tlp_attr,  // PCIe attributes (relaxed-ordering, no-snoop)
    output reg  [LEN_WD-1:0]     client0_tlp_byte_len, // byte length
    output reg  [ADDR_WD-1:0]    client0_tlp_addr,  // target address
    output reg                   client0_tlp_dv,    // TLP data valid
    output reg  [DATA_WD-1:0]    client0_tlp_data,  // TLP data payload
    output reg  [STRB_WD-1:0]    client0_tlp_byte_en, // byte enables
    output reg                   client0_tlp_eot    // end of TLP
  );

  // -------------------------------------------------------------------------
  // PCIe TLP format/type constants for a 64-bit Memory Write
  // fmt = 2'b11 (4DW header with data), type = 5'b00000 (MWr)
  // -------------------------------------------------------------------------
  localparam [1:0] TLP_FMT_4DW_DATA  = 2'b11;
  localparam [4:0] TLP_TYPE_MWR      = 5'b00000;

  // -------------------------------------------------------------------------
  // Write-burst FSM state encoding
  // -------------------------------------------------------------------------
  localparam [1:0] ST_IDLE  = 2'b00; // waiting for AW transaction
  localparam [1:0] ST_HDR   = 2'b01; // AW latched; driving TLP header; waiting for xadm grant
  localparam [1:0] ST_DATA  = 2'b10; // accepting W data beats; driving TLP data
  localparam [1:0] ST_BRESP = 2'b11; // write complete; driving B-channel response

  reg [1:0] state;

  // Internal register for captured AW address fields
  reg [ADDR_WD-1:0]  lat_addr;
  reg [LEN_WD-1:0]   lat_len;
  reg [2:0]          lat_tc;
  reg [1:0]          lat_attr;

  // -------------------------------------------------------------------------
  // Combinational wready: master and slave share the same condition so they
  // always agree when a handshake occurs.  wready is 1 only while in ST_DATA
  // and xadm is not applying back-pressure.
  // -------------------------------------------------------------------------
  assign pcie_slv0_wready = (state == ST_DATA) && !xadm_client0_halt;

  // -------------------------------------------------------------------------
  // Write-burst FSM
  // -------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state                <= #TP ST_IDLE;
      pcie_slv0_awready    <= #TP 1'b0;
      pcie_slv0_bvalid     <= #TP 1'b0;
      client0_tlp_hv       <= #TP 1'b0;
      client0_tlp_fmt      <= #TP 2'b00;
      client0_tlp_type     <= #TP 5'b00000;
      client0_tlp_tc       <= #TP 3'b000;
      client0_tlp_attr     <= #TP 2'b00;
      client0_tlp_byte_len <= #TP {LEN_WD{1'b0}};
      client0_tlp_addr     <= #TP {ADDR_WD{1'b0}};
      client0_tlp_dv       <= #TP 1'b0;
      client0_tlp_data     <= #TP {DATA_WD{1'b0}};
      client0_tlp_byte_en  <= #TP {STRB_WD{1'b0}};
      client0_tlp_eot      <= #TP 1'b0;
      lat_addr             <= #TP {ADDR_WD{1'b0}};
      lat_len              <= #TP {LEN_WD{1'b0}};
      lat_tc               <= #TP 3'b000;
      lat_attr             <= #TP 2'b00;
    end else begin
      // Default deassertions each cycle (only held for one cycle unless re-driven)
      client0_tlp_hv  <= #TP 1'b0;
      client0_tlp_dv  <= #TP 1'b0;
      client0_tlp_eot <= #TP 1'b0;

      case (state)

        // ------------------------------------------------------------------
        // ST_IDLE: Assert awready; accept an AW request; latch address and
        //          length fields; transition to ST_HDR.
        // ------------------------------------------------------------------
        ST_IDLE: begin
          pcie_slv0_awready <= #TP 1'b1;
          pcie_slv0_bvalid  <= #TP 1'b0;

          if (pcie_slv0_awvalid) begin
            lat_addr          <= #TP pcie_slv0_awaddr;
            lat_len           <= #TP pcie_slv0_awbyte_len;
            lat_tc            <= #TP pcie_slv0_awtc;
            lat_attr          <= #TP pcie_slv0_awattr;
            pcie_slv0_awready <= #TP 1'b0;
            state             <= #TP ST_HDR;
          end
        end

        // ------------------------------------------------------------------
        // ST_HDR: Drive TLP header valid toward xadm; wait for the arbiter
        //         to grant client0 (xadm_client0_halt deasserts).
        //         Once granted, transition to ST_DATA so that
        //         pcie_slv0_wready (combinational) asserts automatically.
        // ------------------------------------------------------------------
        ST_HDR: begin
          client0_tlp_hv       <= #TP 1'b1;
          client0_tlp_fmt      <= #TP TLP_FMT_4DW_DATA;
          client0_tlp_type     <= #TP TLP_TYPE_MWR;
          client0_tlp_tc       <= #TP lat_tc;
          client0_tlp_attr     <= #TP lat_attr;
          client0_tlp_byte_len <= #TP lat_len;
          client0_tlp_addr     <= #TP lat_addr;

          if (!xadm_client0_halt) begin
            state <= #TP ST_DATA;
            // pcie_slv0_wready becomes 1 combinationally as soon as state
            // is ST_DATA, so the master may complete a handshake in this
            // same cycle.
          end
        end

        // ------------------------------------------------------------------
        // ST_DATA: Accept write data beats.
        //          pcie_slv0_wready is driven combinationally:
        //            wready = (state == ST_DATA) && !xadm_client0_halt
        //          This means:
        //          - wready deasserts immediately if xadm back-pressures,
        //            pausing the master without capturing partial data.
        //          - wready reasserts as soon as halt clears, with no gap.
        //
        //          KEY FIX: On wlast the FSM leaves ST_DATA, which
        //          deasserts wready combinationally.  The master observes
        //          wready = 0 next cycle and deasserts wvalid — ending the
        //          stuck-at-1 condition.
        // ------------------------------------------------------------------
        ST_DATA: begin
          if (pcie_slv0_wvalid && pcie_slv0_wready) begin
            // Handshake: forward data beat to xadm TLP pipeline
            client0_tlp_dv      <= #TP 1'b1;
            client0_tlp_data    <= #TP pcie_slv0_wdata;
            client0_tlp_byte_en <= #TP pcie_slv0_wstrb;

            if (pcie_slv0_wlast) begin
              // Last beat: assert TLP end-of-transaction and go to BRESP.
              // Leaving ST_DATA causes pcie_slv0_wready to deassert
              // combinationally — the master deasserts wvalid next cycle.
              client0_tlp_eot <= #TP 1'b1;
              state           <= #TP ST_BRESP;
            end
          end
        end

        // ------------------------------------------------------------------
        // ST_BRESP: Send B-channel write response and return to IDLE.
        //           pcie_slv0_wready is 0 here (state != ST_DATA).
        // ------------------------------------------------------------------
        ST_BRESP: begin
          pcie_slv0_bvalid <= #TP 1'b1;

          if (pcie_slv0_bready) begin
            pcie_slv0_bvalid <= #TP 1'b0;
            state            <= #TP ST_IDLE;
          end
        end

        default: state <= #TP ST_IDLE;

      endcase
    end
  end

endmodule
