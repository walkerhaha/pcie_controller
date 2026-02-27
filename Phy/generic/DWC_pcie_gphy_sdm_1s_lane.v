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
// ---    $DateTime: 2020/06/26 01:14:06 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_sdm_1s_lane.v#5 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:  SerDes Dependent Module (SDM)
// -----------------------------------------------------------------------------
// --- This module provides the interface reconcilliation function between
// --- the SerDes function and the remainder the PCI Express PHY digital logic.
// --- The primary function is to assume the capabilities not provided by the
// --- specific SerDes required to connect to the generic PIPE interface.
// ---
// --- referred to as the PIPE+ as it is actually a superset of information
// --- w/rt PIPE.  The SDM provides a central location to reconcile all functions
// --- of the link side of that interface and is expected to be customized for
// --- each specific SerDes vendor's implementation.
// ---
// --- In some cases a pre-qualified SDM will be created and verified for a
// --- specific SerDes core.  For the general case, this module (and sub-modules)
// --- are provided as a baseline implementation for the end-use to customize.
// -----------------------------------------------------------------------------

module DWC_pcie_gphy_sdm_1s_lane #(
  parameter TP        = -1,
  parameter PIPE_NB   = -1,
  parameter WIDTH_WD  = -1,
  parameter RXSB_WD   = -1,
  parameter PIPE_DATA_WD   = -1,   
  parameter TXEI_WD        = -1  
) (
// =====================================
// General Inputs
  input                    txclk,                                   // Port Logic tx clock
  input                    txclk_ug,
  input                    phy_rst_n,                               // Port Logic core reset; active low
  input                    serdes_arch,

// PCS to SDM Inputs
  input   [PIPE_DATA_WD-1:0]  pcs_sdm_txdata,                          // Parallel transmit data (1 or 2 bytes wide)
  input                    pcs_sdm_txdatak,                         // K char indication per byte
  input                    pcs_sdm_txdatavalid,                     // ignore a byte or word on the data interface  
  input                    pcs_sdm_rxstandby,       
  input                    pcs_sdm_txstartblock,                    // first byte of the data interface is the first 
  input   [1:0]            pcs_sdm_txsynchdr,                       // sync header to use in the next 130b block
  input                    pcs_sdm_txdetectrx_loopback,             // Enable recevie detection sequence generation  (loopback)
  input                    pcs_sdm_txelecidle,                      // Place transmitter into electrical idle
  input                    pcs_sdm_txcompliance,                    // Enable transmission of compliance sequence
  input                    pcs_sdm_rxpolarity,                      // Invert the receive data
  input   [3:0]            pcs_sdm_powerdown,                       // Signal to go to specific power state
  input                    pcs_sdm_elasticbuffermode,   
  input   [2:0]            pcs_sdm_rate,                            // 1 = change speed to 5 Gbit/s, 2 = change speed to 8 Gbit/s
  input   [2:0]            pcs_sdm_curr_rate,
  input   [WIDTH_WD-1:0]   pcs_sdm_width,    
  input                    pcs_sdm_reset_n,
  input                    pcs_sdm_set_disp,
  input                    pcs_sdm_txerror,
  input                    pcs_sdm_blockaligncontrol,               // block align control    
  input                    pcs_sdm_sris_mode,
  
  // control inputs
  input                    syncheader_random_en,
  input                    disable_skp_addrm_en,
  
    
`ifdef GPHY_ESM_SUPPORT
  input                    phy_reg_esm_enable,
  input [6:0]              phy_reg_esm_data_rate0,
  input [6:0]              phy_reg_esm_data_rate1,
`endif // GPHY_ESM_SUPPORT


  // pma to sdm  Inputs
  input   [9:0]            pma_sdm_rxdata_10b,                      // Parallel receive data from SerDes
  input                    pma_sdm_rxdetected,                      // Receive signal detected by SerDes
  input                    pma_sdm_rxelecidle,                      // Receive Idle detected
  input                    pma_sdm_recvdclk,                        // Recovered symbol clock
  input                    pma_sdm_rcvdrst_n,                       // Recovered reset_n
  input                    pma_sdm_recvdclk_stopped,
  input                    pma_serdes_rx_valid,
  
  input                    pll_sdm_ready,

  // SDM to PCS Outputs
  output  [PIPE_DATA_WD-1:0]  sdm_pcs_dec8b10b_rxdata,                 // Parallel receive data (1 or 2 bytes)
  output                   sdm_pcs_dec8b10b_rxdatak,                // K char indication
  output                   sdm_pcs_dec8b10b_rxvalid,                // Receive data valid  
  output                   sdm_pcs_dec8b10b_rxdatavalid,            
  output                   sdm_pcs_dec8b10b_rxstartblock,           // first byte of the data interface is the first byte of the block.
  output  [1:0]            sdm_pcs_dec8b10b_rxsynchdr,              // sync header that was strippend out of the 130 bit block  
  output                   sdm_pcs_dec8b10b_rxdisperror,
  output                   sdm_pcs_dec8b10b_rxcodeerror,
  output                   sdm_pcs_dec8b10b_rxunderflow,  
  output                   sdm_pcs_elasbuf_rxoverflow,   
  output                   sdm_pcs_elasbuf_rxskipadded,  
  output                   sdm_pcs_elasbuf_rxskipremoved,
  
  output                   sdm_pcs_skp_broken,
  output  [7:0]            sdm_pcs_ebuf_location,                   // Elastic Buffer Location
  
  // SDM to PMA Outputs
  output  [9:0]            sdm_pma_enc8b10b_txdata_10b,             // Transmit symbol data
  output                   sdm_pma_enc8b10b_txdatavalid_10b,        // ignore a byte or word on the data interface
  output                   sdm_pma_enc8b10b_txstartblock_10b,       // first byte of the data interface is the first byte of the block.
  output  [1:0]            sdm_pma_enc8b10b_txsynchdr_10b,          // sync header to use in the next 130b block
  output                   sdm_pma_enc8b10b_txelecidle_10b,
  
  output                   sdm_pma_loopback                         // TODO :this needs to go to pma serializer where we look at loopback to clear queues 
                                                                    // decision is now take into elastic buffer and needs to propagate down        
);

// ========================================================================
// Regs & wires
// ========================================================================
// outputs from encoder / inputs to lpbk
wire  [9:0]             int_sdm_enc8b10b_txdata_10b;
wire                    int_sdm_enc8b10b_txdatavalid_10b;
wire                    int_sdm_enc8b10b_txstartblock_10b;
wire  [1:0]             int_sdm_enc8b10b_txsynchdr_10b;

// outputs from block align module / inputs to elastic buffer
wire                    int_sdm_ba_block_aligned;
wire  [9:0]             int_sdm_ba_rxdata_aligned;
wire                    int_sdm_ba_rxdata_skip;
wire                    int_sdm_ba_rxdata_start;
wire  [1:0]             int_sdm_ba_rxdata_synchdr;

// outputs from commad detect module
wire  [9:0]             int_sdm_cdt_rxdata_10b;
wire                    int_sdm_en_cdet;

// outputs from elastic buffer
wire                    int_sdm_elasbuf_startblock;
wire  [9:0]             int_sdm_elasbuf_rxdata_10b;
wire                    int_sdm_elasbuf_rxunderflow;
wire                    int_sdm_elasbuf_dv;
wire                    int_sdm_elasbuf_int_loopback;
wire  [1:0]             int_sdm_elasbuf_synchdr;
wire                    int_sdm_elasbuf_datavalid;
 
 // intermediate wires    
wire [PIPE_DATA_WD-1:0] int_sdm_pcs_dec8b10b_rxdata;         
wire                    int_sdm_pcs_dec8b10b_rxdatak;        
wire                    int_sdm_pcs_dec8b10b_rxvalid;        
wire                    int_sdm_pcs_dec8b10b_rxdatavalid;    
wire                    int_sdm_pcs_dec8b10b_rxcodeerror;    
wire                    int_sdm_pcs_dec8b10b_rxdisperror;    
wire                    int_sdm_pcs_dec8b10b_rxunderflow;    
wire                    int_sdm_pcs_dec8b10b_rxstartblock;   
wire [1:0]              int_sdm_pcs_dec8b10b_rxsynchdr; 
wire                    int_sdm_pcs_elasbuf_rxoverflow;
wire                    int_sdm_pcs_elasbuf_rxskipadded;
wire                    int_sdm_pcs_elasbuf_rxskipremoved; 
wire                    int_sdm_pcs_skp_broken;
wire [7:0]              int_sdm_pcs_ebuf_location;

wire                    int_sdm_skp_broken;
wire                    int_sdm_skp_detected;
wire                    int_sdm_comma_lock;


// sdm to pcs outputs
// in serdes arch they are just a pass trough 
assign   sdm_pcs_dec8b10b_rxdata        = serdes_arch ? pma_sdm_rxdata_10b        :  int_sdm_pcs_dec8b10b_rxdata;    
assign   sdm_pcs_dec8b10b_rxdatak       = serdes_arch ?               1'b0        :  int_sdm_pcs_dec8b10b_rxdatak;     
assign   sdm_pcs_dec8b10b_rxvalid       = serdes_arch ? pma_serdes_rx_valid       :  int_sdm_pcs_dec8b10b_rxvalid;     
assign   sdm_pcs_dec8b10b_rxdatavalid   = serdes_arch ?               1'b1        :  int_sdm_pcs_dec8b10b_rxdatavalid;
assign   sdm_pcs_dec8b10b_rxstartblock  = serdes_arch ?               1'b0        :  int_sdm_pcs_dec8b10b_rxstartblock;
assign   sdm_pcs_dec8b10b_rxsynchdr     = serdes_arch ?               2'b0        :  int_sdm_pcs_dec8b10b_rxsynchdr;
assign   sdm_pcs_dec8b10b_rxdisperror   = serdes_arch ?               1'b0        :  int_sdm_pcs_dec8b10b_rxdisperror;
assign   sdm_pcs_dec8b10b_rxcodeerror   = serdes_arch ?               1'b0        :  int_sdm_pcs_dec8b10b_rxcodeerror;
assign   sdm_pcs_dec8b10b_rxunderflow   = serdes_arch ?               1'b0        :  int_sdm_pcs_dec8b10b_rxunderflow;
assign   sdm_pcs_elasbuf_rxoverflow     = serdes_arch ?               1'b0        :  int_sdm_pcs_elasbuf_rxoverflow;
assign   sdm_pcs_elasbuf_rxskipadded    = serdes_arch ?               1'b0        :  int_sdm_pcs_elasbuf_rxskipadded;
assign   sdm_pcs_elasbuf_rxskipremoved  = serdes_arch ?               1'b0        :  int_sdm_pcs_elasbuf_rxskipremoved;

assign   sdm_pcs_skp_broken             = serdes_arch ?               1'b0        :  int_sdm_pcs_skp_broken;
assign   sdm_pcs_ebuf_location          = serdes_arch ?               8'b0        :  int_sdm_pcs_ebuf_location;

// Assume don't need to register these static signals
assign int_sdm_en_cdet = !pcs_sdm_curr_rate[1] & !pma_sdm_rxelecidle; // disable comma detect  



// intermediate signals
wire         int_sdm_pma_enc8b10b_txstartblock_10b;  
wire [1:0]   int_sdm_pma_enc8b10b_txsynchdr_10b;     
wire         int_sdm_pma_enc8b10b_txdatavalid_10b;   
wire [9:0]   int_sdm_pma_enc8b10b_txdata_10b;  
wire         int_sdm_txelecidle_10b;      

// outputs to pma
// in serdes arch are just a pss trough
assign sdm_pma_enc8b10b_txstartblock_10b = serdes_arch ?                1'b0  : int_sdm_pma_enc8b10b_txstartblock_10b ;   
assign sdm_pma_enc8b10b_txsynchdr_10b    = serdes_arch ?                2'b0  : int_sdm_pma_enc8b10b_txsynchdr_10b;     
assign sdm_pma_enc8b10b_txdatavalid_10b  = serdes_arch ? pcs_sdm_txdatavalid  : int_sdm_pma_enc8b10b_txdatavalid_10b;   
assign sdm_pma_enc8b10b_txdata_10b       = serdes_arch ?      pcs_sdm_txdata  : int_sdm_pma_enc8b10b_txdata_10b;
assign sdm_pma_enc8b10b_txelecidle_10b   = serdes_arch ? pcs_sdm_txelecidle   : int_sdm_txelecidle_10b;
 
// this is used to manage port size 
wire [7:0] mux_sdm_pcs_dec8b10b_rxdata;    
assign int_sdm_pcs_dec8b10b_rxdata =  serdes_arch ?  {2'b0, mux_sdm_pcs_dec8b10b_rxdata} : mux_sdm_pcs_dec8b10b_rxdata;  
// ========================================================================
// PCIe loopback
// ========================================================================
DWC_pcie_gphy_lpbk #(
   .TP(TP)) 
   u0_loopback (
    .clk                           ( txclk                              ),
    .rst_n                         ( pcs_sdm_reset_n                    ),
   
    // pcs inputs
    .rate                          ( pcs_sdm_rate                       ), 
    
    // loopback input coming from elastic buffer           
    .loopback                      ( int_sdm_elasbuf_int_loopback       ), 
     
    // rx inputs coming from elastic buffer 
    .rxdata_10b                    ( int_sdm_elasbuf_rxdata_10b         ),   
    .rxdatavalid_10b               ( int_sdm_elasbuf_datavalid          ),   
    .rxvalid                       ( int_sdm_elasbuf_dv                 ),   
    .rxstartblock_10b              ( int_sdm_elasbuf_startblock         ),   
    .rxsynchdr_10b                 ( int_sdm_elasbuf_synchdr            ),   
    
    // tx inputs coming from encoder        
    .txdata_10b                    ( int_sdm_enc8b10b_txdata_10b        ), 
    .txdatavalid_10b               ( int_sdm_enc8b10b_txdatavalid_10b   ),  
    .txstartblock_10b              ( int_sdm_enc8b10b_txstartblock_10b  ),
    .txsynchdr_10b                 ( int_sdm_enc8b10b_txsynchdr_10b     ), 
    
    // outputs to pcs
    .ser_txstartblock_10b          ( int_sdm_pma_enc8b10b_txstartblock_10b  ), 
    .ser_txsynchdr_10b             ( int_sdm_pma_enc8b10b_txsynchdr_10b     ), 
    .ser_txdatavalid_10b           ( int_sdm_pma_enc8b10b_txdatavalid_10b   ), 
    .ser_txdata_10b                ( int_sdm_pma_enc8b10b_txdata_10b        )  
);

// ========================================================================
// 8B10B Encode/Decode:
// ========================================================================
DWC_pcie_gphy_8b10benc #(
   .TP(TP)) 
   u0_xphy_8b10b (
    // inputs
    .clk                            (txclk                             ),
    // input from pcs
    .rst_n                          (pcs_sdm_reset_n                   ),
    .set_disp                       (pcs_sdm_set_disp                  ),
    .test_err_disp                  (pcs_sdm_txerror                   ),
    .rate                           (pcs_sdm_rate                      ),
    .txdata                         (pcs_sdm_txdata[7:0]               ),  
    .txdatak                        (pcs_sdm_txdatak                   ),
    .txdatavalid                    (pcs_sdm_txdatavalid               ), 
    .txstartblock                   (pcs_sdm_txstartblock              ),
    .txsynchdr                      (pcs_sdm_txsynchdr                 ),
    .txelecidle                     (pcs_sdm_txelecidle                ),

    // outputs going to lpbk module
    .txstartblock_10b               (int_sdm_enc8b10b_txstartblock_10b  ),
    .txsynchdr_10b                  (int_sdm_enc8b10b_txsynchdr_10b     ),
    .txdatavalid_10b                (int_sdm_enc8b10b_txdatavalid_10b   ),
    .txdata_10b                     (int_sdm_enc8b10b_txdata_10b        ),
    .txelecidle_10b                 (int_sdm_txelecidle_10b             )  
);

DWC_pcie_gphy_10b8bdec #(
   .TP(TP)) 
   u0_rphy_8b10b (
// inputs
    .clk                            (txclk                              ),
    .rst_n                          (pcs_sdm_reset_n                    ),
    // inputs from pcs
    .rxdata_rate                    (pcs_sdm_rate                       ),
    .set_disp                       (1'b0                               ),
    .invert_polarity                (1'b0                               ),  // assume in SerDes
    
    // inputs from elastic buffer
    .elasbuf_underflow              (int_sdm_elasbuf_rxunderflow        ),
    .rxdata_10b                     (int_sdm_elasbuf_rxdata_10b         ),  
    .rxdata_10b_dv                  (int_sdm_elasbuf_dv                 ),  
    .rxdata_10b_datavalid           (int_sdm_elasbuf_datavalid          ),
    .rxdata_10b_startblock          (int_sdm_elasbuf_startblock         ),
    .rxdata_10b_synchdr             (int_sdm_elasbuf_synchdr            ),

    // outputs to pcs
    .rxdata                         (mux_sdm_pcs_dec8b10b_rxdata            ),
    .rxdatak                        (int_sdm_pcs_dec8b10b_rxdatak           ),
    .rxdata_dv                      (int_sdm_pcs_dec8b10b_rxvalid           ),
    .rxdata_datavalid               (int_sdm_pcs_dec8b10b_rxdatavalid       ),
    .rxcodeerror                    (int_sdm_pcs_dec8b10b_rxcodeerror       ),
    .rxdisperror                    (int_sdm_pcs_dec8b10b_rxdisperror       ),
    .underflow_p                    (int_sdm_pcs_dec8b10b_rxunderflow       ),   
    .rxdata_startblock              (int_sdm_pcs_dec8b10b_rxstartblock      ),
    .rxdata_synchdr                 (int_sdm_pcs_dec8b10b_rxsynchdr         )
);


// ========================================================================
// Receive Elastic Buffer
// ========================================================================

DWC_pcie_gphy_elasbuf #(
    .TP (TP),
    .WIDTH_WD (WIDTH_WD),
    .RXSB_WD  (RXSB_WD)
) u0_rphy_elasbuf (
// inputs
    // pop clk/rst  
    .pop_clk                        (txclk                              ),
    .pop_rst_n                      (phy_rst_n                          ),
    
    // push clk/rst
    .push_clk                       (pma_sdm_recvdclk                   ), 
    .push_rst_n                     (pma_sdm_rcvdrst_n                  ), 
    .push_clk_off                   (pma_sdm_recvdclk_stopped           ),
    
    // inputs from pcs  
    .loopback                       (pcs_sdm_txdetectrx_loopback        ), 
    .width                          (pcs_sdm_width                      ),
    .mac_phy_elasticbuffermode      (pcs_sdm_elasticbuffermode          ), 
    .req_rate                       (pcs_sdm_rate                       ),
    .curr_rate                      (pcs_sdm_curr_rate                  ),
    .sris_mode                      (pcs_sdm_sris_mode                  ),
    
    // input from pll
    .sdm_ready                      (pll_sdm_ready                      ),
    
    // control input
    .disable_skp_addrm_en           (disable_skp_addrm_en               ),  
    
    // inputs from block align module         
    .rxdata_ba                      (int_sdm_ba_rxdata_aligned          ),
    .rxdata_ba_dv                   (int_sdm_ba_block_aligned           ),
    .rxdatavalid_int                (int_sdm_ba_rxdata_skip             ),
    .rxdata_start                   (int_sdm_ba_rxdata_start            ),
    .rxdata_synchdr                 (int_sdm_ba_rxdata_synchdr          ),  
    .skip_broken                    (int_sdm_skp_broken                 ), 
    .skip_detected_g3               (int_sdm_skp_detected               ),
    
    // inputas from comma detect    
    .rxdata_cdt                     (int_sdm_cdt_rxdata_10b             ),
    .rxdata_cdt_dv                  (int_sdm_comma_lock                 ),

    // outputs
    .elasbuf_rxdata_10b             (int_sdm_elasbuf_rxdata_10b         ),
    .elasbuf_dv                     (int_sdm_elasbuf_dv                 ),
    .elasbuf_datavalid              (int_sdm_elasbuf_datavalid          ),
    .elasbuf_startblock             (int_sdm_elasbuf_startblock         ),
    .elasbuf_synchdr                (int_sdm_elasbuf_synchdr            ),
    .elasbuf_underflow              (int_sdm_elasbuf_rxunderflow        ),
    .elasbuf_overflow               (int_sdm_pcs_elasbuf_rxoverflow     ),
    .elasbuf_add_skip_out           (int_sdm_pcs_elasbuf_rxskipadded    ),
    .elasbuf_drop_skip_out          (int_sdm_pcs_elasbuf_rxskipremoved  ),
    .elasbuf_int_loopback           (int_sdm_elasbuf_int_loopback       ),
    .elasbuf_location               (int_sdm_pcs_ebuf_location          ),
    .elasbuf_skip_broken            (int_sdm_pcs_skp_broken             )  // For Pipe Message to update Elastic Buffer Location
);

// ========================================================================
// Comma Detection (gen1/2)
// ========================================================================
DWC_pcie_gphy_cdet #(
    .TP (TP)
) u_rphy_cdet (
    //inputs from pma
    .recvdclk                       (pma_sdm_recvdclk           ),
    .rst_n                          (pma_sdm_rcvdrst_n          ),
    .rxdata_10b_nonaligned          (pma_sdm_rxdata_10b         ),
    // inputs from pcs
    .req_rate                       (pcs_sdm_rate               ),
    .curr_rate                      (pcs_sdm_curr_rate          ),
    // internal control
    .en_cdet                        (int_sdm_en_cdet            ),    
    // outputs going to elastic buffer
    .comma_lock                     (int_sdm_comma_lock         ),  // rx_valid
    .rxdata_10b                     (int_sdm_cdt_rxdata_10b     )   // aligned 10 bit data
);

// ========================================================================
// Block Alignment (gen3/4)
// ========================================================================
DWC_pcie_gphy_blockalign #(
    .TP                             (TP),
    .PIPE_NB                        (PIPE_NB),
    .WIDTH_WD                       (WIDTH_WD)
) u_rphy_blockalign (
    // inputs from pma 
    .recvdclk                       (pma_sdm_recvdclk            ),
    .rst_n                          (pma_sdm_rcvdrst_n           ),
    .rxdata_nonaligned              (pma_sdm_rxdata_10b[7:0]     ),
    .rxelecidle                     (pma_sdm_rxelecidle          ),
    
    // inputs from pcs
    .req_rate                       (pcs_sdm_rate                ),
    .rate                           (pcs_sdm_curr_rate           ),
    .width                          (pcs_sdm_width               ),
    .ba_ctrl                        (pcs_sdm_blockaligncontrol   ),
    .rxloopback                     (pcs_sdm_txdetectrx_loopback ),
    
    `ifdef GPHY_ESM_SUPPORT
    .esm_enable                     (phy_reg_esm_enable          ),
    .esm_data_rate0                 (phy_reg_esm_data_rate0      ),
    .esm_data_rate1                 (phy_reg_esm_data_rate1      ),
    `endif // GPHY_ESM_SUPPORT 
    
    // control signal     
    .syncheader_random_en           (syncheader_random_en        ),
    
    // outputs going to elastic buffer    
    .block_aligned_out              (int_sdm_ba_block_aligned    ),
    .rxdata_aligned                 (int_sdm_ba_rxdata_aligned   ),
    .rxdata_skip                    (int_sdm_ba_rxdata_skip      ),
    .rxdata_start                   (int_sdm_ba_rxdata_start     ),
    .rxdata_synchdr                 (int_sdm_ba_rxdata_synchdr   ),
    // output going to pcs (pipe2phy)  
    .skp_broken                     (int_sdm_skp_broken          ),
    .skp_detected                   (int_sdm_skp_detected        )

);

endmodule
