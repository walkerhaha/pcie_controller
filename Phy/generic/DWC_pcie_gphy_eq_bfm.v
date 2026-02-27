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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_eq_bfm.v#4 $
// -------------------------------------------------------------------------
// --- Description: Equalization PIPE model
// ----------------------------------------------------------------------------


//single lane version of EQ Evaluation
module DWC_pcie_gphy_eq_bfm
#(
  parameter TP             = -1,  
  parameter TX_PSET_WD     = -1,
  parameter TX_COEF_WD     = -1,
  parameter DIRFEEDBACK_WD = -1,
  parameter FOMFEEDBACK_WD = -1,
  parameter TX_FS_WD       = -1,
  parameter SEED           = -1
) (
input                           pclk,
input                           phy_rst_n,
input      [2:0]                mac_phy_rate,
input                           mac_phy_txswing,
input                           mac_phy_invalid_req,
input                           mac_phy_rxeqeval,
input      [TX_FS_WD-1:0]       mac_phy_fs,
input      [TX_FS_WD-1:0]       mac_phy_lf,
input      [TX_PSET_WD-1:0]     mac_phy_local_pset_index,
input                           mac_phy_getlocal_pset_coef,
input                           mac_phy_rxeqinprogress,
input                           mux_phy_mac_rxvalid,            // route rxvalid through this module
input                           mux_phy_mac_rxdatavalid,

output reg [TX_FS_WD-1:0]       phy_mac_localfs,
output reg [TX_FS_WD-1:0]       phy_mac_locallf,
output reg [TX_FS_WD-1:0]       eqpa_localfs_g3,
output reg [TX_FS_WD-1:0]       eqpa_locallf_g3,
output reg [TX_FS_WD-1:0]       eqpa_localfs_g4,
output reg [TX_FS_WD-1:0]       eqpa_locallf_g4,
output reg [TX_FS_WD-1:0]       eqpa_localfs_g5,
output reg [TX_FS_WD-1:0]       eqpa_locallf_g5,
output reg [DIRFEEDBACK_WD-1:0] phy_mac_dirfeedback,
output reg [FOMFEEDBACK_WD-1:0] phy_mac_fomfeedback,

output reg                      phy_mac_phystatus,
output reg [TX_COEF_WD-1:0]     phy_mac_local_tx_pset_coef,
output reg                      phy_mac_local_tx_coef_valid,
output reg                      eqpa_local_tx_coef_valid_g3,
output reg                      eqpa_local_tx_coef_valid_g4,
output reg                      eqpa_local_tx_coef_valid_g5,
output                          g3_mac_phy_rate_pulse, // to tell the timing when local_fs/lf is evaluted.
output                          g4_mac_phy_rate_pulse, // to tell the timing when local_fs/lf is evaluted.
output                          g5_mac_phy_rate_pulse, // to tell the timing when local_fs/lf is evaluted.
output reg                      phy_mac_rxvalid,              // 

// Command If.
input                          set_eq_feedback_delay, 
input integer                  eq_feedback_delay,
input                          set_eq_dirfeedback,
input [DIRFEEDBACK_WD-1:0]     eq_dirfeedback_value,           
input                          set_eq_fomfeedback,
input [FOMFEEDBACK_WD-1:0]     eq_fomfeedback_value,
input                          set_localfs_g3,
input [TX_FS_WD-1:0]           localfs_value_g3,
input                          set_localfs_g4,
input [TX_FS_WD-1:0]           localfs_value_g4,
input                          set_localfs_g5,
input [TX_FS_WD-1:0]           localfs_value_g5,
input                          set_locallf_g3,
input [TX_FS_WD-1:0]           locallf_value_g3,
input                          set_locallf_g4,
input [TX_FS_WD-1:0]           locallf_value_g4,
input                          set_locallf_g5,
input [TX_FS_WD-1:0]           locallf_value_g5,
input                          set_local_tx_pset_coef_delay,
input integer                  local_tx_pset_coef_delay,  
input                          set_local_tx_pset_coef,
input [TX_COEF_WD-1:0]         local_tx_pset_coef_value ,
input                          set_rxadaption
);

localparam MIN_TIMEOUT = `PHY_EQ_EVAL_MIN_TIMEOUT;
localparam MAX_TIMEOUT = `PHY_EQ_EVAL_MAX_TIMEOUT;


reg    [10:0]      wait_time_rand;
integer            feedback_wait_time;
wire   [31:0]      feedback_num_cycles;
reg    [31:0]      num_count;
reg                int_phy_mac_phystatus;
reg                int_phy_mac_phystatus_r;
wire               phy_mac_phystatus_pulse;
wire               eval_request_pulse;
wire               eval_request_negedge_pulse;
wire               eval_request;
reg                eval_request_r;
reg                mac_phy_rxeqeval_r;
wire               eqeval_abort;
reg                eqeval_abort_r;
reg                g3_mac_phy_rate_r;
reg                g3_mac_phy_rate_rr;
reg                g4_mac_phy_rate_r;
reg                g4_mac_phy_rate_rr;
reg                g5_mac_phy_rate_r;
reg                g5_mac_phy_rate_rr;


reg     [2:0]      mac_phy_rate_r, mac_phy_rate_rr, mac_phy_rate_rrr;
reg     [31:0]     lane;
reg     [5:0]      coverge_pre_cursor,coverge_cursor,coverge_post_cursor;
integer            local_feedback_num;
reg                inc_local_feedback_num;
reg  [FOMFEEDBACK_WD+4-1:0] local_feedback_mem [0:`MAX_FTUNE_ATTEMPTS-1];
wire [FOMFEEDBACK_WD+4-1:0] local_feedback0;
wire [FOMFEEDBACK_WD+4-1:0] local_feedback1;
wire [FOMFEEDBACK_WD+4-1:0] local_feedback2;
wire [FOMFEEDBACK_WD+4-1:0] local_feedback3;
wire [FOMFEEDBACK_WD+4-1:0] local_feedback;
wire   [31:0]      min_timeout;
wire   [31:0]      max_timeout;
integer            local_min_timeout [0:`MAX_FTUNE_ATTEMPTS-1];
integer            local_max_timeout [0:`MAX_FTUNE_ATTEMPTS-1];
reg                mac_phy_getlocal_pset_coef_d;
wire               mac_phy_getlocal_pset_coef_rising_edge;
reg [4:0]          mac_phy_getlocal_pset_coef_rising_edge_dly;
reg [TX_PSET_WD-1:0] mac_phy_local_pset_index_sample;

// Feedback delays queue - for user control
integer                    eq_feedback_delay_q[$] = {};
reg [DIRFEEDBACK_WD-1:0]   eq_dirfeedback_value_q[$] = {};
reg [FOMFEEDBACK_WD-1:0]   eq_fomfeedback_value_q[$] = {};
integer                    local_tx_pset_coef_delay_q[$] = {}; 
reg [TX_COEF_WD-1:0]       local_tx_pset_coef_value_q[$] = {}; 

reg int_rxadaption, int_rxadaption_latch;

initial begin: init_eq_controls
  integer abc;

  local_feedback_num     = 0;
  inc_local_feedback_num = 0;
  
  for (abc=0; abc < `MAX_FTUNE_ATTEMPTS; abc = abc + 1 )
  begin
    local_feedback_mem[abc] = 0;
    local_min_timeout[abc]  = MIN_TIMEOUT;
    local_max_timeout[abc]  = MAX_TIMEOUT;
  end
  lane                  = SEED;

end
 
real pclk_period_times100; initial pclk_period_times100 = 1;
real pclk_time;
always @(posedge pclk) begin
   // scale pclk period by 100 because at 25G we have a pclk period of 0.64ns, so we want to avoid fractional numbers; 
   pclk_period_times100 = ($realtime - pclk_time)*100;
   pclk_time = $realtime;
end


// sample data on the Command interface
always @(posedge pclk or negedge phy_rst_n) begin
  if ( !phy_rst_n ) begin
    eq_feedback_delay_q = {};
    eq_dirfeedback_value_q = {};     
    eq_fomfeedback_value_q = {};
    local_tx_pset_coef_delay_q = {};
    local_tx_pset_coef_value_q = {}; 
    int_rxadaption=0;
    int_rxadaption_latch=0;
  end else begin
    if (set_eq_feedback_delay)         eq_feedback_delay_q.push_back(eq_feedback_delay);
    if (set_eq_dirfeedback)            eq_dirfeedback_value_q.push_back(eq_dirfeedback_value); 
    if (set_eq_fomfeedback)            eq_fomfeedback_value_q.push_back(eq_fomfeedback_value);
    if (set_local_tx_pset_coef_delay)  local_tx_pset_coef_delay_q.push_back(local_tx_pset_coef_delay);
    if (set_local_tx_pset_coef)        local_tx_pset_coef_value_q.push_back(local_tx_pset_coef_value);
    if( set_rxadaption ) 
      int_rxadaption_latch =1;
    if( eval_request_pulse )
      int_rxadaption_latch =0;
    if( eval_request_negedge_pulse )
      int_rxadaption=int_rxadaption_latch;
    else if( (int_rxadaption_latch && eval_request_pulse) || mac_phy_rate inside {0,1} ) 
      int_rxadaption=0;


  end  
end 

reg rx_adaption_set;
always @(posedge pclk or negedge phy_rst_n) begin
  if (!phy_rst_n )                                   rx_adaption_set <= #TP 1'b0; else
  if (int_rxadaption)                                rx_adaption_set <= #TP 1'b1; else
  if (!int_rxadaption && !mux_phy_mac_rxdatavalid)   rx_adaption_set <= #TP 1'b0;
end

always @( posedge pclk or negedge phy_rst_n ) begin 
    if ( !phy_rst_n ) begin
        mac_phy_getlocal_pset_coef_d  <= #TP 0;
    end else begin
        mac_phy_getlocal_pset_coef_d <= #TP mac_phy_getlocal_pset_coef;
    end
end //always          

always @( posedge pclk or negedge phy_rst_n ) begin : map_p2c_PROC
    if ( !phy_rst_n ) begin
        phy_mac_local_tx_coef_valid                <= #TP 0;
        eqpa_local_tx_coef_valid_g3                <= #TP 0;
        eqpa_local_tx_coef_valid_g4                <= #TP 0;
        eqpa_local_tx_coef_valid_g5                <= #TP 0;
        phy_mac_local_tx_pset_coef                 <= #TP 0;
        mac_phy_getlocal_pset_coef_rising_edge_dly <= #TP 0; 
        mac_phy_local_pset_index_sample            <= #TP 0; 
    end else begin
        `ifdef GPHY_EQ_PSET_COEF_MAP_MODE_PHY
        if (mac_phy_getlocal_pset_coef) begin
          if(`GPHY_IS_PIPE_51) begin
            if(mac_phy_local_pset_index<11) begin // Gen3 pset
              mac_phy_local_pset_index_sample <= #TP mac_phy_local_pset_index;
            end else if((mac_phy_local_pset_index>10) && (mac_phy_local_pset_index<22)) begin // Gen4 pset
              mac_phy_local_pset_index_sample <= #TP mac_phy_local_pset_index - 32'd11;
            end else if((mac_phy_local_pset_index>21) && (mac_phy_local_pset_index<33)) begin // Gen5 pset
              mac_phy_local_pset_index_sample <= #TP mac_phy_local_pset_index - 32'd22;
            end
          end else if(`GPHY_IS_PIPE_44) begin
            if (mac_phy_rate >= 3'b011 && (mac_phy_local_pset_index!=5'b11111) ) begin
              mac_phy_local_pset_index_sample <= #TP mac_phy_local_pset_index - 32'd11;
            end else begin
              mac_phy_local_pset_index_sample <= #TP mac_phy_local_pset_index;
            end
          end else begin
            mac_phy_local_pset_index_sample <= #TP mac_phy_local_pset_index;
          end
        end
        // The set_local_tx_pset_coef has 2 cycle delay is setting the preset mapping
        // The set_local_tx_pset_coef_delay has 2 cycle delay is setting the preset mapping
        // So delay sampling pset_coef_rising edge by 4 clock cycles to give the user the chance to set.
        mac_phy_getlocal_pset_coef_rising_edge_dly[4:1] <= #TP mac_phy_getlocal_pset_coef_rising_edge_dly[3:0]; 
        mac_phy_getlocal_pset_coef_rising_edge_dly[0]   <= #TP mac_phy_getlocal_pset_coef_rising_edge; 
        if ( `ifdef UTB 
                  // utb is compuiting the lf/fs on the fly and they need 4 clk cycles to process this
                  // so we give 4 clk cyles more before driving the coefs
                  mac_phy_getlocal_pset_coef_rising_edge_dly[4] 
             `else 
                  mac_phy_getlocal_pset_coef_rising_edge
             `endif 
            ) begin
          if (local_tx_pset_coef_delay_q.size() > 0) begin
            repeat ((local_tx_pset_coef_delay_q.pop_front()*100) / pclk_period_times100) @(posedge pclk);
          end  
          phy_mac_local_tx_coef_valid <= #TP 1;
          eqpa_local_tx_coef_valid_g3 <= #TP (mac_phy_local_pset_index<11);
          eqpa_local_tx_coef_valid_g4 <= #TP (mac_phy_local_pset_index>10) && (mac_phy_local_pset_index<22);
          eqpa_local_tx_coef_valid_g5 <= #TP (mac_phy_local_pset_index>21) && (mac_phy_local_pset_index<33);
          phy_mac_local_tx_pset_coef  <= #TP (local_tx_pset_coef_value_q.size() > 0) ? local_tx_pset_coef_value_q.pop_front() : 
                                                                                       map_p2c(mac_phy_local_pset_index_sample, phy_mac_localfs, phy_mac_locallf);
        end else begin
          phy_mac_local_tx_coef_valid <= #TP 0;
          eqpa_local_tx_coef_valid_g3 <= #TP 0;
          eqpa_local_tx_coef_valid_g4 <= #TP 0;
          eqpa_local_tx_coef_valid_g5 <= #TP 0;
          phy_mac_local_tx_pset_coef  <= #TP 0;
        end
        `else // !GPHY_EQ_PSET_COEF_MAP_MODE_PHY
        phy_mac_local_tx_coef_valid <= #TP 0;
        eqpa_local_tx_coef_valid_g3 <= #TP 0;
        eqpa_local_tx_coef_valid_g4 <= #TP 0;
        eqpa_local_tx_coef_valid_g5 <= #TP 0;
        phy_mac_local_tx_pset_coef  <= #TP 0;
        `endif // GPHY_EQ_PSET_COEF_MAP_MODE_PHY
    end
end //always

assign mac_phy_getlocal_pset_coef_rising_edge = mac_phy_getlocal_pset_coef & !mac_phy_getlocal_pset_coef_d;

assign local_feedback  = local_feedback_mem[local_feedback_num];
assign local_feedback0 = local_feedback_mem[0];
assign local_feedback1 = local_feedback_mem[1];
assign local_feedback2 = local_feedback_mem[2];
assign local_feedback3 = local_feedback_mem[3];

assign min_timeout = local_min_timeout[local_feedback_num];
assign max_timeout = local_max_timeout[local_feedback_num];
  
//gates: phy_mac_localfs and phy_mac_locallf keep unchanged after entering Gen3 rate
always @( posedge pclk or negedge phy_rst_n ) begin : local_fslf_PROC
    if ( !phy_rst_n ) begin
        phy_mac_localfs <= #TP `PHY_EQ_DEFAULT_GEN3_LOCAL_FS;
        phy_mac_locallf <= #TP `PHY_EQ_DEFAULT_GEN3_LOCAL_LF;
        g3_mac_phy_rate_r <= #TP 0;
        g3_mac_phy_rate_rr <= #TP 0;
        g4_mac_phy_rate_r <= #TP 0;
        g4_mac_phy_rate_rr <= #TP 0;
        g5_mac_phy_rate_r <= #TP 0;
        g5_mac_phy_rate_rr <= #TP 0;
        mac_phy_rate_r <= #TP 0;
        mac_phy_rate_rr <= #TP 0;
        mac_phy_rate_rrr <= #TP 0;
    end else begin
        if ( mac_phy_rate_rrr == 3'b010 ) begin
            g3_mac_phy_rate_r <= #TP 1;
            g3_mac_phy_rate_rr <= #TP g3_mac_phy_rate_r;
        end else begin
            g3_mac_phy_rate_r <= #TP 0;
            g3_mac_phy_rate_rr <= #TP 0;
        end

        if ( mac_phy_rate_rrr == 3'b011 ) begin
            g4_mac_phy_rate_r <= #TP 1;
            g4_mac_phy_rate_rr <= #TP g4_mac_phy_rate_r;
        end else begin
            g4_mac_phy_rate_r <= #TP 0;
            g4_mac_phy_rate_rr <= #TP 0;
        end
        
       if ( mac_phy_rate_rrr == 3'b100 ) begin
            g5_mac_phy_rate_r <= #TP 1;
            g5_mac_phy_rate_rr <= #TP g5_mac_phy_rate_r;
        end else begin
            g5_mac_phy_rate_r <= #TP 0;
            g5_mac_phy_rate_rr <= #TP 0;
        end
        
        if ( g3_mac_phy_rate_pulse ) begin
          phy_mac_localfs[TX_FS_WD-1:0] <= #TP eqpa_localfs_g3[TX_FS_WD-1:0];
          phy_mac_locallf[TX_FS_WD-1:0] <= #TP eqpa_locallf_g3[TX_FS_WD-1:0];
        end // if ( g3_mac_phy_rate_pulse ) begin
        else if ( g4_mac_phy_rate_pulse ) begin
          phy_mac_localfs[TX_FS_WD-1:0] <= #TP eqpa_localfs_g4[TX_FS_WD-1:0];
          phy_mac_locallf[TX_FS_WD-1:0] <= #TP eqpa_locallf_g4[TX_FS_WD-1:0];
        end // if ( g4_mac_phy_rate_pulse ) begin
        else if ( g5_mac_phy_rate_pulse ) begin
          phy_mac_localfs[TX_FS_WD-1:0] <= #TP eqpa_localfs_g5[TX_FS_WD-1:0];
          phy_mac_locallf[TX_FS_WD-1:0] <= #TP eqpa_locallf_g5[TX_FS_WD-1:0];
        end // if ( g5_mac_phy_rate_pulse ) begin
        
        // the set_locallf_cmd has 2 cycle delay is setting the user lf or fs
        // so delay sampling mac_phy_rate to give the user the chance to set
        // the user value
        mac_phy_rate_r <= #TP mac_phy_rate;
        mac_phy_rate_rr <= #TP mac_phy_rate_r;
        mac_phy_rate_rrr <= #TP mac_phy_rate_rr;
        // reg coeffs
    end
end //always
always @( posedge pclk or negedge phy_rst_n ) begin : local_fslf_per_rate_PROC
    if ( !phy_rst_n ) begin
        eqpa_localfs_g3 <= #TP `PHY_EQ_DEFAULT_GEN3_LOCAL_FS;
        eqpa_locallf_g3 <= #TP `PHY_EQ_DEFAULT_GEN3_LOCAL_LF;
        eqpa_localfs_g4 <= #TP `PHY_EQ_DEFAULT_GEN4_LOCAL_FS;
        eqpa_locallf_g4 <= #TP `PHY_EQ_DEFAULT_GEN4_LOCAL_LF;
        eqpa_localfs_g5 <= #TP `PHY_EQ_DEFAULT_GEN5_LOCAL_FS;
        eqpa_locallf_g5 <= #TP `PHY_EQ_DEFAULT_GEN5_LOCAL_LF;
    end else begin
        eqpa_localfs_g3[TX_FS_WD-1:0] <= #TP (set_localfs_g3) ? localfs_value_g3 : eqpa_localfs_g3[TX_FS_WD-1:0];
        eqpa_locallf_g3[TX_FS_WD-1:0] <= #TP (set_locallf_g3) ? locallf_value_g3 : eqpa_locallf_g3[TX_FS_WD-1:0];
        eqpa_localfs_g4[TX_FS_WD-1:0] <= #TP (set_localfs_g4) ? localfs_value_g4 : eqpa_localfs_g4[TX_FS_WD-1:0];
        eqpa_locallf_g4[TX_FS_WD-1:0] <= #TP (set_locallf_g4) ? locallf_value_g4 : eqpa_locallf_g4[TX_FS_WD-1:0];
        eqpa_localfs_g5[TX_FS_WD-1:0] <= #TP (set_localfs_g5) ? localfs_value_g5 : eqpa_localfs_g5[TX_FS_WD-1:0];
        eqpa_locallf_g5[TX_FS_WD-1:0] <= #TP (set_locallf_g5) ? locallf_value_g5 : eqpa_locallf_g5[TX_FS_WD-1:0];
    end
end //always


assign g3_mac_phy_rate_pulse = g3_mac_phy_rate_r & !g3_mac_phy_rate_rr;
assign g4_mac_phy_rate_pulse = g4_mac_phy_rate_r & !g4_mac_phy_rate_rr;
assign g5_mac_phy_rate_pulse = g5_mac_phy_rate_r & !g5_mac_phy_rate_rr;

//within 2ms after mac_phy_rxeqeval high, PHY must complete evaluation with
//phy_mac_phystatus high for 1 cycle and feed back new request indication by
//DirectionChange or FigureMerit or CustomerMode
//
// also, if invalid request is asserted, then this is also a request for evaluation
assign eval_request = (mac_phy_rxeqeval || (mac_phy_rxeqeval & mac_phy_invalid_req));
always @(posedge pclk or negedge phy_rst_n) begin : eval_request_r_PROC
    if ( !phy_rst_n ) begin
        eval_request_r <= #TP 0;
    end else begin
        eval_request_r <= #TP eval_request;
    end
end // always

// detect EQ evaluation abort
always @(posedge pclk or negedge phy_rst_n) begin : mac_phy_rxeqeval_d_PROC
    if ( !phy_rst_n ) begin
        mac_phy_rxeqeval_r <= #TP 0;
    end else begin
        mac_phy_rxeqeval_r <= #TP mac_phy_rxeqeval;
    end
end //always
assign eqeval_abort = (~mac_phy_rxeqeval & mac_phy_rxeqeval_r);

// register eq in progress to detect deassertion
reg mac_phy_rxeqinprogress_r;
wire eqinprogress_desassert;
assign eqinprogress_desassert = ~mac_phy_rxeqinprogress & mac_phy_rxeqinprogress_r;
always @(posedge pclk or negedge phy_rst_n) begin : mac_phy_rxeqinprogress_d_PROC
    if ( !phy_rst_n ) begin
        mac_phy_rxeqinprogress_r <= #TP 0;
    end else begin
        mac_phy_rxeqinprogress_r <= #TP mac_phy_rxeqinprogress;
    end
end //always

// generate 1 cycle pulse for eval_request
assign eval_request_pulse = eval_request & !eval_request_r;
assign eval_request_negedge_pulse = !eval_request & eval_request_r;

//random 1ns - 2us
always @(posedge pclk or negedge phy_rst_n) begin : feedback_wait_time_PROC
    if ( !phy_rst_n ) begin
        feedback_wait_time <= #TP 0;
    end else begin
        if ( eval_request_pulse ) begin
          if (eq_feedback_delay_q.size() > 0)
            feedback_wait_time <= #TP eq_feedback_delay_q.pop_front(); // user contraint
          else 
            feedback_wait_time <= #TP $urandom_range(min_timeout, max_timeout); //wait for 1ns - 2us for fast_link_mode
        end
    end
end // always

//bigger than 1 cycle number of cycles
assign feedback_num_cycles = ((feedback_wait_time*100) / pclk_period_times100);

//number of counts
// cleared when !eval_request_r || int_phy_mac_phystatus
always @(posedge pclk or negedge phy_rst_n) begin : num_count_PROC
    if ( !phy_rst_n ) begin
        num_count <= #TP 0;
    end else if ( int_phy_mac_phystatus || !eval_request_r )
        num_count <= #TP 0;
    else if ( eval_request_r )
        num_count <= #TP num_count + 1;
end //always

//wait for feedback_num_cycles to generate 1 cycle of phy_mac_phystatus
always @(posedge pclk or negedge phy_rst_n) begin : phy_mac_dirfeedback_PROC
    if ( !phy_rst_n ) begin
        phy_mac_dirfeedback     <= #TP 0;
        phy_mac_fomfeedback     <= #TP 0;

        int_phy_mac_phystatus   <= #TP 0;
        int_phy_mac_phystatus_r <= #TP 0;
        eqeval_abort_r          <= #TP 0;
        phy_mac_phystatus       <= #TP 0;
        local_feedback_num      <= #TP 0;
    end else begin
        phy_mac_phystatus <= #TP phy_mac_phystatus_pulse; //delay 1 cycle of phy_mac_phystatus_pulse

        //generate phy_mac_phystatus_pulse
        if ( (eval_request_r && (num_count >= feedback_num_cycles)) || eqeval_abort ) begin
            int_phy_mac_phystatus <= #TP 1;
        end else if ( !eval_request_r) begin
            //phy_mac_phystatus for 1 cycle
            int_phy_mac_phystatus <= #TP 0;
        end

        int_phy_mac_phystatus_r <= #TP int_phy_mac_phystatus;
        eqeval_abort_r          <= #TP eqeval_abort;

        if ( phy_mac_phystatus_pulse & ~eqeval_abort_r ) begin
            // drive DIR feedback
            if (eq_dirfeedback_value_q.size() > 0) begin // user constraint
               phy_mac_dirfeedback <= #TP eq_dirfeedback_value_q.pop_front();
            end else begin // default logic
              phy_mac_dirfeedback[0 +: 2] <= #TP local_feedback[1:0];
              phy_mac_dirfeedback[2 +: 2] <= #TP $random(lane) % 3;  // cursor feedback is a don't care
              phy_mac_dirfeedback[4 +: 2] <= #TP local_feedback[3:2];
              inc_local_feedback_num       = 1;
            end
            // drive FOM feedback
            if (eq_fomfeedback_value_q.size() > 0) begin // user constraint  
              phy_mac_fomfeedback <= #TP eq_fomfeedback_value_q.pop_front();
            end else begin // default logic  
              phy_mac_fomfeedback         <= #TP local_feedback[11:4];
              inc_local_feedback_num       = 1;
            end
            // increment index for default logic
            if (inc_local_feedback_num) begin 
              local_feedback_num          <= #TP local_feedback_num + 1;
              inc_local_feedback_num       = 0;
            end  
        end else if (eqinprogress_desassert) begin
            if(`GPHY_IS_PIPE_51==0) begin // In LowPinCount, they don't need to be changed randomly
                phy_mac_dirfeedback[0 +: 2] <= #TP $random(lane) % 3;
                phy_mac_dirfeedback[2 +: 2] <= #TP $random(lane) % 3;
                phy_mac_dirfeedback[4 +: 2] <= #TP $random(lane) % 3;
                phy_mac_fomfeedback         <= #TP $random(lane) % 255;
            end
            local_feedback_num          <= #TP 0;
        end else begin
            if(`GPHY_IS_PIPE_51==0) begin // In LowPinCount, they don't need to be changed randomly
                // randomize on invalid cycles
                phy_mac_dirfeedback[0 +: 2] <= #TP $random(lane) % 3;
                phy_mac_dirfeedback[2 +: 2] <= #TP $random(lane) % 3;
                phy_mac_dirfeedback[4 +: 2] <= #TP $random(lane) % 3;
                phy_mac_fomfeedback         <= #TP $random(lane) % 255;
            end
            local_feedback_num          <= #TP local_feedback_num;
        end
    end
end //always

//generate 1 cycle pulse for phy_mac_phystatus
assign phy_mac_phystatus_pulse = int_phy_mac_phystatus & !int_phy_mac_phystatus_r;

// To model PHY where continuous rx adaption is not possible, drop rxvalid
// unitl MAX asserts mac_phy_rxeqeval
always @(*) begin
   phy_mac_rxvalid = mux_phy_mac_rxvalid & !rx_adaption_set;
end

//preset to coefficients map
function [17:0] map_p2c(input [3:0] pset, input [5:0] fs, input [5:0] lf);
/*
1/10  0.100
1/8   0.125
1/6   0.166
1/5   0.200
1/4   0.250
*/
    reg [3:0] fs_div_10;
    reg [3:0] fs_div_8;
    reg [3:0] fs_div_6;
    reg [3:0] fs_div_5;
    reg [4:0] fs_div_4; //5 bits as (63+2)/4 = 16 = 5'b10000
    reg [5:0] p10_pstc; //post-coefficients for preset 10, 6 bits as (63-0+1)/2 = 32 = 6'b100000
    reg [5:0] c0,c1,c2; //C(-1), C(0), C(+1)
    begin
        //gates: for round, only p10_pstc has 6 bits and fs_div_4 has 5 bits. The others only have 4 bits
        map_p2c = 0;

        fs_div_10 = (fs+5)/10;
        fs_div_8 = (fs+4) >> 3;  //(fs+4)/8
        fs_div_6 = (fs+3)/6;
        fs_div_5 = (fs+2)/5;
        fs_div_4 = (fs+2) >> 2;  //(fs+2)/4
        p10_pstc = (fs-lf) >> 1; //(fs-lf)/2

        // from table 4-16
        case ( pset )
            4'd4 : {c0, c2} = {           6'd0,               6'd0};
            4'd1 : {c0, c2} = {           6'd0,   {2'b0, fs_div_6}};
            4'd0 : {c0, c2} = {           6'd0,   {1'b0, fs_div_4}};
            4'd9 : {c0, c2} = {{2'b0, fs_div_6},              6'd0};
            4'd8 : {c0, c2} = {{2'b0, fs_div_8},  {2'b0, fs_div_8}};
            4'd7 : {c0, c2} = {{2'b0, fs_div_10}, {2'b0, fs_div_5}};
            4'd5 : {c0, c2} = {{2'b0, fs_div_10},             6'd0};
            4'd6 : {c0, c2} = {{2'b0, fs_div_8},              6'd0};
            4'd3 : {c0, c2} = {           6'd0,   {2'b0, fs_div_8}};
            4'd2 : {c0, c2} = {           6'd0,   {2'b0, fs_div_5}};
            4'd10: {c0, c2} = {           6'd0,          p10_pstc};
            default : {c0, c2} = 0;
        endcase
        c1 = (pset > 10) ? 0 : (fs - c0 - c2);
        map_p2c = {c2, c1, c0};
    end
endfunction

endmodule //pipe_eqpa_bfm

