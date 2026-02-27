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
// ---    $DateTime: 2020/09/11 01:49:10 $
// ---    $Revision: #29 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_elasbuf.v#29 $
// -------------------------------------------------------------------------
// --- Module Description: Receive PHY elastic buffer.
// -------------------------------------------------------------------------

module DWC_pcie_gphy_elasbuf #(
  parameter TP        = 0,
  parameter WIDTH_WD  = 0,
  parameter RXSB_WD   = 1
) (
   input                       pop_clk,                    // symbol clock
   input                       pop_rst_n,                  // ... and reset
   input                       push_clk,                   // Receive clock
   input                       push_rst_n,                 // ... and reset
 //  input                       align_en,
   input                       push_clk_off,
   input   [WIDTH_WD-1:0]      width,                      // PIPE interface width
   input                       loopback,
   input                       mac_phy_elasticbuffermode,  // 0 = empty mode ; 1 = half full mode
   input   [9:0]               rxdata_ba,                  // Rx data on 10b from block align
   input                       rxdata_ba_dv,               // Rx data valid from block align
   input   [9:0]               rxdata_cdt,                 // Rx data on 10b from comma detect
   input                       rxdata_cdt_dv,              // Rx data valid from comma detect
   input                       sdm_ready,                  // Indicates when the serdes is ready after reset
   input   [2:0]               req_rate,                   // reqested rate
   input   [2:0]               curr_rate,                  // ack rate
   input                       disable_skp_addrm_en,
   input                       sris_mode,
   input                       rxdatavalid_int,            // skip this cycle of data
   input                       rxdata_start,               // sync header valid this cycle
   input   [1:0]               rxdata_synchdr,             // sync header received on wire
   input                       skip_broken,
   input                       skip_detected_g3,
   output reg                  elasbuf_startblock,         // sync header valid this cycle
   output reg [1:0]            elasbuf_synchdr,            // sync header received on wire

   output reg [9:0]            elasbuf_rxdata_10b,         // Receive data on pop_clk domain
   output reg                  elasbuf_dv,                 // Elastic buffer output is valid
   output reg                  elasbuf_datavalid,          // skip this cycle of data
   output reg                  elasbuf_underflow,          // Buffer underflow error
   output reg                  elasbuf_overflow,           // Buffer overflow error
   output reg                  elasbuf_add_skip_out,           // Add-skip indication
   output reg                  elasbuf_drop_skip_out,          // Drop-skip indication
   output reg                  elasbuf_int_loopback,
   output     [7:0]            elasbuf_location,               // Elastic Buffer Location
   output reg                  elasbuf_skip_broken
);


//==============================================================================
// Parameters
//==============================================================================
// gen12: 4'b0 + 10b data + skip_os + valid = 16 bits
// gen34: 10b data + skip_os + valid + data_skip + data_start + sychdr(2) = 16 bits
localparam EBUF_WIDTH = 18;
localparam PW         = 6;
localparam DP    = (1<<PW);

//===================================================================================
// Regs & wires
//===================================================================================
// control of elastic buffer
wire   clear_elasbuf;

reg                   elasticbuffermode_r; initial elasticbuffermode_r = 1'b0;
wire                  elasticbuffermode_change;

wire [5:0]            mid_marker;                
wire [5:0]            below_watermark_threshold; 
wire [5:0]            above_watermark_threshold; 
   
reg                   fill_elasbuff;
wire [PW:0]           symbols_in_buf;

wire                  above_watermark;           
wire                  below_watermark;           
wire                  empty_watermark;           
wire                  full_watermark; 

wire                  elasbuf_add_skip_r;          // Add-skip indication
reg                   elasbuf_add_skip_p;
reg                   elasbuf_add_skip_rr;

// data information
wire   [9:0]          rxdata_10b;
wire                  rxdata_10b_dv;
reg    [9:0]          rxdata_10b_r;
reg                   rxdata_10b_dv_r;
reg                   rxdatavalid_int_r; 
reg                   rxdata_start_r;    
reg [1:0]             rxdata_synchdr_r;  
wire                  rxdata_10b_dv_rise;
reg                   rxdata_10b_dv_rise_r, rxdata_10b_dv_rise_rr;
reg                   skip_broken_r;

wire                  comma_detect_gen12;
reg                   comma_detect_gen12_r;
wire                  skip_detect_gen12;
wire                  skip_end_gen34;
wire                  skip_os_detect;
reg                   skip_detected_g3_r;

reg [EBUF_WIDTH-1:0]  elasbuf [0:DP-1];
reg [PW:0]            rdptr_bin;
reg [PW:0]            rdptr_bin_p1;
reg [PW:0]            rdptr_bin_p2;
reg [PW:0]            rdptr_gray;
reg [PW:0]            rdptr_gray_p1;
reg [PW:0]            rdptr_gray_p2;
reg [PW:0]            rdptr_gray_sync_wr2, rdptr_gray_sync_wr1;

reg  [PW:0]           rdptr_bin_next;
reg  [PW:0]           rdptr_bin_next_p1;
reg  [PW:0]           rdptr_bin_next_p2;
wire [PW:0]           rdptr_gray_next;
wire [PW:0]           rdptr_gray_next_p1;
wire [PW:0]           rdptr_gray_next_p2;

reg                   read_enable;
reg                   read_enable_r;
reg [4:0]             add_skip_ctr; 
reg [4:0]             add_skip_ctr_r;
reg                   skip_already_added_r;
reg                   datavalid_emptymode;
reg [4:0]             del_sym_cnt;

reg [EBUF_WIDTH-1:0]  read_entry;
reg [EBUF_WIDTH-1:0]  read_entry_r;
reg [EBUF_WIDTH-1:0]  read_entry_lkah;

reg [1:0]             store_rxsyncheader;
reg                   store_rxstartblock;


wire                  read_entry_skip_deleted;
wire                  read_entry_skip_deleted_lkah;

wire                  read_entry_skip_broken;
wire                  read_entry_skip;
wire                  read_entry_skip_lkah;
wire                  read_entry_skip_lkah2;
reg                   skip_already_added;

wire  [9:0]           read_entry_data;
wire  [9:0]           read_entry_data_lkah;
wire                  read_entry_dv;
wire                  read_entry_dv_lkah;

wire                  read_entry_dataskip;
wire                  read_entry_lkah_dataskip;
wire    [1:0]         read_entry_synchdr;
wire                  read_entry_startblock;
wire    [1:0]         read_entry_lkah_synchdr;
wire    [1:0]         read_entry_lkah2_synchdr;
wire                  read_entry_lkah_startblock;
wire                  read_entry_lkah2_startblock;
reg     [4:0]         rdptr_increment_val;
reg                   skip_deleting;

reg                   in_skip_os, in_skip_os_r;
reg                   read_entry_lkah_dataskip_r;
reg                   skip_os_at_input, skip_os_at_input_r;
reg [4:0]             skip_length;
wire                  skip_os_at_input_negedge;
integer               skip_length_q[$];

wire   in_skip_os_negedge;
assign in_skip_os_negedge = in_skip_os_r && !in_skip_os;       

reg [5:0] queue_size; // for debug purpose

reg empty_watermark_r, empty_watermark_rr;
reg full_watermark_r, full_watermark_rr,full_watermark_rrr;

// --------------------------------------------------------------------
// register push clk
// --------------------------------------------------------------------
reg  push_clk_off_r;
reg  push_clk_off_rr;
wire push_clk_off_negedge;

// synch push_clk_off 2 stages on pop domain
always @(posedge pop_clk or negedge pop_rst_n)
begin
  if (!pop_rst_n) begin
     push_clk_off_r  <=  #TP '0;
     push_clk_off_rr <=  #TP '0;
  end else begin
     push_clk_off_r  <=  #TP push_clk_off;
     push_clk_off_rr <=  #TP push_clk_off_r;  
  end   
end  

assign push_clk_off_negedge = push_clk_off_rr && !push_clk_off_r;


// --------------------------------------------------------------------
// data information mux
// --------------------------------------------------------------------
// mux rxdata, rxdatavalid        
assign rxdata_10b     = (req_rate > 1) ? rxdata_ba                  : rxdata_cdt;
assign rxdata_10b_dv  = (req_rate > 1) ? (sdm_ready & rxdata_ba_dv) : (sdm_ready & rxdata_cdt_dv);

// register data on wr domain
always @(posedge push_clk or negedge push_rst_n)
begin
   if (!push_rst_n) begin
      rxdata_10b_r       <= #TP 'b0;
      rxdata_10b_dv_r    <= #TP 'b0;
      rxdatavalid_int_r  <= #TP 'b0; 
      rxdata_start_r     <= #TP 'b0;   
      rxdata_synchdr_r   <= #TP 'b0; 
      skip_detected_g3_r <= #TP 'b0; 
      skip_broken_r      <= #TP 'b0; 
   end else begin
      rxdata_10b_r       <= #TP rxdata_10b;
      rxdata_10b_dv_r    <= #TP rxdata_10b_dv;
      rxdatavalid_int_r  <= #TP rxdatavalid_int; 
      rxdata_start_r     <= #TP rxdata_start;   
      rxdata_synchdr_r   <= #TP rxdata_synchdr;
      skip_detected_g3_r <= #TP skip_detected_g3;
      skip_broken_r      <= #TP skip_broken; 
   end
end

assign rxdata_10b_dv_rise = rxdata_10b_dv && !rxdata_10b_dv_r;
// register the rise of rx_valid 2 times on pop clk to move from push clk
always @(posedge pop_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n) begin
      rxdata_10b_dv_rise_r  <= #TP '0;
      rxdata_10b_dv_rise_rr <= #TP '0;
   end else begin
      rxdata_10b_dv_rise_r  <= #TP rxdata_10b_dv_rise;
      rxdata_10b_dv_rise_rr <= #TP rxdata_10b_dv_rise_r;
   end 
end


//===================================================================================
// Perform symbol decode on incoming data
//
// For Gen1 & Gen2: skip insertion/deletion is done on a per symbol basis
//                  COM followed by SKP identifies a SKP OS
// For Gen3 & Gen4: skip insertion/deletion is done on a per 4/8-symbol basis
//                  AA w/ synchdr and startblock identifies a SKP OS block
//                  when an insert/delete is done these signals must be moved:
//                  rxdatavalid_int,rxdata_synchdr,rxdata_start
//===================================================================================
wire [7:0] skip_body_sym;
// skip format
assign skip_body_sym =  (req_rate == 4) ? `GPHY_SKP_SYM_0_GEN5_R07_ENC  :
                                          `GPHY_SKP_SYM_0;

assign comma_detect_gen12   = (req_rate > 1) ? 1'b0 : (rxdata_10b == `GPHY_COM_10B_NEG) | (rxdata_10b == `GPHY_COM_10B_POS);

always @(posedge push_clk or negedge push_rst_n or posedge clear_elasbuf)
begin
  if (!push_rst_n)       comma_detect_gen12_r <= #TP 1'b0; else
  if (clear_elasbuf)     comma_detect_gen12_r <= #TP 1'b0;
  else                   comma_detect_gen12_r <= #TP comma_detect_gen12;
end

assign skip_detect_gen12    = comma_detect_gen12_r & ((rxdata_10b == `GPHY_SKP_10B_NEG) | (rxdata_10b == `GPHY_SKP_10B_POS));

assign skip_end_gen34       = (req_rate > 1) ? (rxdata_10b[7:0] inside {`GPHY_SKP_END_SYM , `GPHY_SKP_END_CTL_SYM }) : 1'b0; 

// final decision
assign skip_os_detect       = (req_rate > 1) ? skip_detected_g3_r : skip_detect_gen12;


reg skip_os_detect_r;
// registred version 
always @(posedge push_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n) skip_os_detect_r <= #TP 0; else
                   skip_os_detect_r <= #TP skip_os_detect;
end 
//----------------------------------------------------------------------------
// THIS IS LOGIC NEEDED FOR THE SVA CHECK
// this is for checking internal logic
// check that skip detected by block align is the same as the one detected by elastic buffer
// now we use the one comming from block align
//----------------------------------------------------------------------------
// wire                  skip_detect_gen34;
// assign skip_detect_gen34    = (req_rate > 1) ? (rxdata_10b[7:0] == skip_body_sym && rxdata_start && rxdata_synchdr == 2'b01) : 1'b0; 
// assert property (@(posedge push_clk) disable iff(!push_rst_n)  skip_detect_gen34 == skip_detected_g3_r)
// else $error ("SKIP not identical found");
//--------------------------------------------------------------------------

// detect if we have a skip os at elastic buffer input
always @(posedge push_clk or negedge pop_rst_n or posedge clear_elasbuf)
begin
   if (!pop_rst_n)                            skip_os_at_input <= #TP '0;   else
   if (skip_detected_g3_r)                    skip_os_at_input <= #TP 1'b1; else
   if (skip_end_gen34 )                       skip_os_at_input <= #TP 1'b0; else
   if (clear_elasbuf)                         skip_os_at_input <= #TP 1'b0; else
                                              skip_os_at_input <= #TP skip_os_at_input;
end

// registred version 
always @(posedge push_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n)  skip_os_at_input_r <= #TP 0; else
                    skip_os_at_input_r <= #TP skip_os_at_input;
end 

//detect negedge
assign skip_os_at_input_negedge = skip_os_at_input_r && !skip_os_at_input;


// we measure the lenght of the skip when there is a skip at buffer input 
// we are doing this because we need to know in advance the length 
always @(posedge push_clk or negedge pop_rst_n or posedge clear_elasbuf)
begin
   if (!pop_rst_n)                                                             skip_length <= #TP '0; else
   if (clear_elasbuf)                                                          skip_length <= #TP '0; else
   if (skip_detected_g3_r && curr_rate > 1)                                    skip_length <= #TP  1; else
   if (curr_rate > 1 && rxdata_10b[7:0] == skip_body_sym && skip_os_at_input)  skip_length <= #TP skip_length + 1; else
   if (rxdata_10b[7:0] inside {`GPHY_SKP_END_SYM, `GPHY_SKP_END_CTL_SYM})      skip_length <= #TP skip_length; else             
                                                                               skip_length <= #TP skip_length;
end
                    

// push in a queue the size of each skip os
// we need this when we have back to back skip OSes so that we know the length of each skip os
always @(posedge push_clk or negedge push_rst_n or posedge clear_elasbuf)
begin
  if (!push_rst_n)               skip_length_q = {}; else
  if (clear_elasbuf)             skip_length_q = {}; else
  if (skip_os_at_input_negedge)  skip_length_q.push_back(skip_length); 
end


// we pop the size of a skip OS on pop_clk
always @(posedge pop_clk or negedge pop_rst_n)
begin
  if (!pop_rst_n)                                skip_length_q = {}; else
  if (elasticbuffermode_change || clear_elasbuf) skip_length_q = {}; else
  begin 
  if (in_skip_os_negedge)   
     void'(skip_length_q.pop_front());
 
  // debug purpose
  queue_size <= skip_length_q.size(); 
  end
end


// when we enter loopback and elastic buffer it is working in nominal empty mode
// we need to switch to half full mode when rxdatavalid it is in 1 to not lose first 
// symbol with rxstartblock in 1
reg elasticbuffermode;

always @(posedge pop_clk or negedge pop_rst_n )
begin
   if (!pop_rst_n) read_entry_lkah_dataskip_r <= #TP 0; 
   else            read_entry_lkah_dataskip_r <= #TP read_entry_lkah_dataskip;
   
end
   
wire rxdatavalid_int_posedge;
assign rxdatavalid_int_posedge = !rxdatavalid_int_r && rxdatavalid_int;


always @(posedge pop_clk or negedge pop_rst_n )
begin
   if (!pop_rst_n)                                                                         elasticbuffermode <= #TP mac_phy_elasticbuffermode; else
   if (req_rate > 1 && loopback && rxdatavalid_int_posedge  && mac_phy_elasticbuffermode)  elasticbuffermode <= #TP 0;                         else
   if (req_rate <= 1 && loopback && mac_phy_elasticbuffermode)                             elasticbuffermode <= #TP 0;                         else                  
   if (!loopback)                                                                          elasticbuffermode <= #TP mac_phy_elasticbuffermode; else  
                                                                                           elasticbuffermode <= #TP elasticbuffermode;               
end

always @(posedge pop_clk or negedge pop_rst_n )
begin
   if (!pop_rst_n) elasticbuffermode_r <= #TP elasticbuffermode; 
   else            elasticbuffermode_r <= #TP elasticbuffermode; 
end

// loopback entry

always @(posedge pop_clk or negedge pop_rst_n )
begin
   if (!pop_rst_n)                                            elasbuf_int_loopback <= #TP 0; else
   if (req_rate > 1 && loopback && rxdatavalid_int_posedge)   elasbuf_int_loopback <= #TP 1; else // half full
   if (req_rate <= 1 && loopback )                            elasbuf_int_loopback <= #TP 1; else
   if (!loopback)                                             elasbuf_int_loopback <= #TP 0; else 
                                                              elasbuf_int_loopback <= #TP elasbuf_int_loopback;        
end

// -------------------------------------------------------------------------
// if we need to perform skip delete we do it by not writing those symbols into the buffer
// we control this with signal write_en
// -------------------------------------------------------------------------
reg write_en;
reg skip_deleted;

always @(posedge push_clk or negedge pop_rst_n or posedge clear_elasbuf)
begin
    if (!pop_rst_n) begin
      write_en      <= #TP 1'b0; 
      skip_deleted  <= #TP 1'b0;
      skip_deleting <= #TP 1'b0;  
      del_sym_cnt   <= #TP '0; 
    end else if (!sdm_ready || clear_elasbuf)  begin  
      write_en      <= #TP 1'b0; 
      skip_deleted  <= #TP 1'b0;
      skip_deleting <= #TP 1'b0;  
      del_sym_cnt   <= #TP '0;  
    end else begin    
        // if we are not 16s and startblock 1, we delete in block of 4s or 8s
        if ( (!(width == 4 && RXSB_WD == 1)) && 
              ((above_watermark && skip_os_detect && !disable_skp_addrm_en )  ||
               (skip_os_detect && elasticbuffermode) || skip_deleting ))
                         begin

          // store syncheader and startblock
          if (skip_os_detect) begin      
                store_rxsyncheader <= #TP rxdata_synchdr;
                store_rxstartblock <= #TP rxdata_start;    
          end   

          // HALF FULL delete one symbols or block of 4/8 symbols
          if (!elasticbuffermode) begin
             // skip over a symbol or a block
             if (req_rate < 2) begin
                // gen1/2 skip 1 symbol
               write_en        <= #TP 1'b0; 
               skip_deleting   <= #TP 1'b0;
               skip_deleted    <= #TP 1'b0; 
             end else begin
                  // for GEN3/GEN4 skip in block of 4 or 8
                  if (del_sym_cnt != 0 || skip_os_detect) begin
                    skip_deleting <= #TP 1'b1;
                    write_en      <= #TP 1'b0;
                  end else begin
                    skip_deleting <= #TP 1'b0;
                    write_en      <= #TP 1'b1; 
                  end   
                    
                  skip_deleted     <= #TP 1'b1; 
                  
                  if (skip_os_detect)
                     del_sym_cnt   <= #TP (width == 3 && RXSB_WD == 1) ? 7 : 3;
                  else if (del_sym_cnt > 0) 
                     del_sym_cnt   <= #TP del_sym_cnt - 1;
                  else
                     del_sym_cnt   <= #TP del_sym_cnt;   

             end

          end else begin      
          // EMPTY MODE: delete all SKIP symbols from buffer until buffer is empty or no more skip symbols in buffer
               
             if ((req_rate > 1 && skip_os_detect || (skip_os_at_input && !(rxdata_10b[7:0] inside {`GPHY_SKP_END_SYM , `GPHY_SKP_END_CTL_SYM })))  || 
                 (req_rate < 2 && ((rxdata_10b == `GPHY_SKP_10B_NEG) | (rxdata_10b == `GPHY_SKP_10B_POS)))) begin
                write_en      <= #TP 1'b0; 
                skip_deleting <= #TP 1'b1;
                skip_deleted     <= #TP (req_rate > 1) ? 1'b1 : 1'b0;                
             end else begin
                write_en      <= #TP 1'b1;
                skip_deleting <= #TP 1'b0;
                skip_deleted     <= #TP (req_rate > 1) ? 1'b1 : 1'b0;
             end            

          end
          
        // on half full mode 
        // if 16s and startblock width == 1 we do not do skip remove when above_watermark
        // but we skip the data that has rx_datavalid == 0 
        // SKIP DELETE is not performed for 16s and startblock one bit, but we do not output the data that has datavalid 0
        end else if ((width > 3 && RXSB_WD == 1 && above_watermark && req_rate > 1 && !elasticbuffermode && rxdatavalid_int) ||
                     (skip_deleting))
        begin
             // for GEN3/GEN4
             if (above_watermark && !skip_deleting)
                 del_sym_cnt   <= #TP 15;
              else if (del_sym_cnt > 0) 
                 del_sym_cnt   <= #TP del_sym_cnt - 1;
              else
                 del_sym_cnt   <= #TP del_sym_cnt;  
                                         
              skip_deleted  <= #TP 1'b1;
              
              if (above_watermark || del_sym_cnt > 0)
              begin
                 skip_deleting <= #TP 1'b1;
                 write_en      <= #TP 1'b0;
              end else begin
                 skip_deleting <= #TP 1'b0;
                 write_en      <= #TP 1'b1;
              end
       end else if (rxdata_10b_dv || elasbuf_dv) begin
           write_en      <= #TP 1'b1; 
           skip_deleting <= #TP 1'b0;
           if (write_en)
              skip_deleted     <= #TP 1'b0;
       end else begin
           write_en      <= #TP 1'b0; 
           skip_deleting <= #TP 1'b0;
           if (write_en)
              skip_deleted     <= #TP 1'b0;
       end
    end
end
//================================================================================
// Setup and increment write pointers into buffer
// Note we continuously write into the elastic buffer, as long as there is
// a clock. This is to avoid scenario across power states transition where
// this buffer would naturally drain itself. We want to keep the buffer as
// 'half-full' as possible
//===================================================================================
reg  [PW:0]         wrptr_bin;
wire [PW:0]         wrptr_bin_next;

reg  [PW:0]         wrptr_gray;
wire [PW:0]         wrptr_gray_next;

assign wrptr_bin_next  = write_en ? wrptr_bin + 1 : wrptr_bin ;
assign wrptr_gray_next = (wrptr_bin_next>>1)^wrptr_bin_next;


always @(posedge push_clk or negedge push_rst_n or posedge clear_elasbuf)
    if (!push_rst_n)             {wrptr_bin, wrptr_gray}  <= #TP '0;
    else if (clear_elasbuf)      {wrptr_bin, wrptr_gray}  <= #TP '0;
    else                         {wrptr_bin, wrptr_gray}  <= #TP {wrptr_bin_next, wrptr_gray_next};


// Synchronize the write pointer into the read domain 2 times
reg  [PW:0] wrptr_gray_sync_rd2, wrptr_gray_sync_rd1;
always @(posedge pop_clk or negedge pop_rst_n)
begin
    if (!pop_rst_n) begin
        wrptr_gray_sync_rd1        <= #TP 0;
        wrptr_gray_sync_rd2        <= #TP 0;
    end else if (clear_elasbuf) begin
        wrptr_gray_sync_rd1        <= #TP 0;
        wrptr_gray_sync_rd2        <= #TP 0;
    end else begin
        wrptr_gray_sync_rd1        <= #TP wrptr_gray; 
        wrptr_gray_sync_rd2        <= #TP wrptr_gray_sync_rd1;
    end
end

//===================================================================================
// write incoming data to buffer
//===================================================================================
integer i;
always @(posedge push_clk or negedge push_rst_n or posedge clear_elasbuf) begin
    if (!push_rst_n) begin
        for (i=0; i<DP; i=i+1)
           elasbuf[i]           <= #TP {{EBUF_WIDTH}{1'b0}};                
    end else if (clear_elasbuf) begin
        for (i=0; i<DP; i=i+1)
            elasbuf[i]           <= #TP {{EBUF_WIDTH}{1'b0}};    
    end else begin
    
       if (write_en) begin
           if (skip_deleted && req_rate > 1) // gen3 skip delete
              elasbuf[wrptr_bin[PW-1:0]]  <= #TP  {skip_deleted, skip_broken_r,rxdatavalid_int_r ,store_rxstartblock,store_rxsyncheader,
                                                                     rxdata_10b_dv_r, 1'b1,rxdata_10b_r};
           // gen1/2 skip delete
           else if ((above_watermark && skip_os_detect && !disable_skp_addrm_en && req_rate < 2 && !elasticbuffermode) ||
                    (skip_os_detect && elasticbuffermode && req_rate < 2))
              elasbuf[wrptr_bin[PW-1:0]]  <= #TP {1'b1, skip_broken,4'h0, rxdata_10b_dv_r, skip_os_detect,rxdata_10b_r};
           
           else
              elasbuf[wrptr_bin[PW-1:0]]  <= #TP (req_rate > 1) ? {skip_deleted, skip_broken_r,rxdatavalid_int_r ,rxdata_start_r,rxdata_synchdr_r,
                                                                     rxdata_10b_dv_r, skip_os_detect_r,rxdata_10b_r}
                                                         : {skip_deleted, skip_broken,4'h0, rxdata_10b_dv_r, skip_os_detect,rxdata_10b_r};
       end
    end
end


assign full_watermark  = ((wrptr_gray_next[PW]     != rdptr_gray_sync_wr2[PW])   &&
                         (wrptr_gray_next[PW-1]   != rdptr_gray_sync_wr2[PW-1]) &&
                         (wrptr_gray_next[PW-2:0] == rdptr_gray_sync_wr2[PW-2:0])) && !full_watermark_rrr;


// if the write pointer overlaps we need to do the difference using as reference the maximum 
// number of symbols in el. buff.                                                
                                                           
assign symbols_in_buf = (!read_enable & wrptr_bin[PW:0] == 0 && !fill_elasbuff) ? 16'h0000 :
                        (wrptr_bin[PW:0] >= rdptr_bin[PW:0]) ? (wrptr_bin[PW:0] - rdptr_bin[PW:0])   :
                                                           ((1<<(PW+1)) - rdptr_bin[PW:0] + wrptr_bin[PW:0]);                                                           
                                                           
                                                           
// set when we need to clear the buffer
// when we are not receiving any data (push clk it is off) and we ran out of symbols
// When we have a rate change
assign clear_elasbuf  = (push_clk_off && symbols_in_buf == {{PW}{1'b0}})                         ? 1'b1 : 
                        (elasticbuffermode_change)                                               ? 1'b1 :
                        (req_rate != curr_rate)                                                  ? 1'b1 : 
                        (!rxdata_10b_dv && !elasbuf_dv && !read_enable && symbols_in_buf >= 0)   ? 1'b1 : 
                                                                                                   1'b0;

// set when we need to hold the output of elastic buffer to fill it with symbols
always @(posedge pop_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n)   fill_elasbuff <= #TP 1'b0; else
   if ((rxdata_10b_dv_rise || rxdata_10b_dv_rise_r || rxdata_10b_dv_rise_rr) && symbols_in_buf < below_watermark_threshold) fill_elasbuff <= #TP 1'b1; else
   if (symbols_in_buf >= below_watermark_threshold) fill_elasbuff <= #TP 1'b0; else
                                                    fill_elasbuff <= #TP fill_elasbuff;    
end

assign elasticbuffermode_change = (elasticbuffermode && !elasticbuffermode_r) || (!elasticbuffermode && elasticbuffermode_r);

//===================================================================================
//
//          Everything from this point on is in the read clock domain
//
//===================================================================================

//===================================================================================
// peek current and next (lookahead) location
// We need to look ahead in the buffer for two reasons:
//
// Gen1/2 SKP ADD: we need to anticipate addition by one cycle to ensure
// sideband information is correctly aligned with the COM of the SKP OS
//===================================================================================
always @(posedge pop_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n)                                                                               in_skip_os <= #TP 0; else
   if (clear_elasbuf)                                                                            in_skip_os <= #TP 0; else
   if (read_entry_skip_lkah && curr_rate > 1 && !empty_watermark)                                in_skip_os <= #TP 1; else // empty mode   
   if ((read_entry_data inside {`GPHY_SKP_END_SYM, `GPHY_SKP_END_CTL_SYM}) && !empty_watermark)  in_skip_os <= #TP 0; else             
                                                                                                 in_skip_os <= #TP in_skip_os;
end

always @(posedge pop_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n)    in_skip_os_r <= #TP 0; else
   if (clear_elasbuf) in_skip_os_r <= #TP 0; else
                      in_skip_os_r <= #TP in_skip_os; 
end

always @(posedge pop_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n)  begin
       read_entry       <= #TP 'h0000;     // {dv, skip, data10b}
       read_entry_r     <= #TP 'h0000;     // {dv, skip, data10b}
       read_entry_lkah  <= #TP 'h0000;     // look ahead one entry for skip     
   end else if (clear_elasbuf || !read_enable_r || fill_elasbuff)  begin
       read_entry       <= #TP 'h0000;     // {dv, skip, data10b}
       read_entry_r     <= #TP 'h0000;     // {dv, skip, data10b}
       read_entry_lkah  <= #TP 'h0000;     // look ahead one entry for skip      
   end else if (read_enable_r && symbols_in_buf > 0) begin
       read_entry       <= #TP elasbuf[rdptr_bin[PW-1:0]];     // {dv, skip, data10b}
       read_entry_r     <= #TP read_entry;
       read_entry_lkah  <= #TP elasbuf[rdptr_bin_p1[PW-1:0]];  // look ahead one entry for skip       
   end    
end

assign read_entry_skip_deleted      =   read_entry[17];
assign read_entry_skip_deleted_lkah =   read_entry_lkah[17];
 
assign read_entry_skip_broken  = read_entry[16]; 
 
assign read_entry_skip         = read_entry[10]       & !skip_already_added & datavalid_emptymode;
assign read_entry_skip_lkah    = read_entry_lkah[10]  & !skip_already_added;

// split data / valid information onto separate buses
assign read_entry_data         = read_entry[9:0];
assign read_entry_data_lkah    = read_entry_lkah[9:0];

assign read_entry_dv           = read_entry[11];
assign read_entry_dv_lkah      = read_entry_lkah[11];

assign read_entry_dataskip        = read_entry[15];
assign read_entry_lkah_dataskip   = read_entry_lkah[15];

assign read_entry_synchdr         = read_entry[13:12];
assign read_entry_startblock      = read_entry[14];
assign read_entry_lkah_synchdr    = read_entry_lkah[13:12];
assign read_entry_lkah_startblock = read_entry_lkah[14];

//===================================================================================
// Symbol count and thresholds/watermarks
// SKP ADD/RM at gen1/gen2 is on a symbol basis, whereas at gen3/4 
// requires addition or deletion of multiple symbols. For this reason
// the above/below watermark are set here to define a window, 
// rather than just a point when current rate is gen3/4
//===================================================================================
assign below_watermark_threshold = (!elasticbuffermode) ? (sris_mode) ? ((req_rate > 1) ?  29 :  27) : // half full(SRIS)
                                                                        ((req_rate > 1) ?   9 :   6) : // half full(SRNS)
                                                                        1'b0;                       // empty mode 

assign above_watermark_threshold = (!elasticbuffermode) ? (sris_mode) ? (((req_rate > 1) && (width > 3))  ?  46 :
                                                                         ((req_rate > 1) && (width == 3)) ?  38 :
                                                                         ((req_rate > 1) && (width != 3)) ?  34 :  29) : // half full(SRIS)
                                                                            
                                                                        (((req_rate > 1) && (width >= 3)) ?  18 : 
                                                                         ((req_rate > 1) && (width != 3)) ?  14 :   8) : // half full(SRNS)
                                                                            
                                                                         ((req_rate > 1) ?   5 :   2) ; // empty mode 

assign mid_marker                = (!elasticbuffermode) ? (sris_mode) ? ((req_rate > 1) ?  31 :  28) : // half full(SRIS)
                                                                        ((req_rate > 1) ?  11 :   7) : // half full(SRNS)
                                                                         1'b0;                         // empty mode 



assign above_watermark = symbols_in_buf >  above_watermark_threshold;  
    
assign below_watermark = symbols_in_buf <  below_watermark_threshold;      


//===================================================================================
// manage the read enable
// if half full mode we need to start outputting data only when buffer is half full
// if nominal empty mode we output data when we receive it. buffer always as empty as possible
//===================================================================================
always @(posedge pop_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n)                                           read_enable <= #TP 1'b0;
   else if (elasticbuffermode_change)                        read_enable <= #TP 1'b0;
   // if nominal half full mode  
   else if (!elasticbuffermode) begin  
      if (push_clk_off_negedge)                                   read_enable <= #TP 1'b0;
      else if  (fill_elasbuff)                                    read_enable <= #TP 1'b0;
      else if (symbols_in_buf > mid_marker)                       read_enable <= #TP 1'b1;
      else if (push_clk_off && symbols_in_buf == 0)               read_enable <= #TP 1'b0;
      else if (clear_elasbuf)                                     read_enable <= #TP 1'b0;
   end else begin
      // if nominal empty mode
      read_enable <= #TP 1'b1;   
   end    
end

always @(posedge pop_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n) read_enable_r <= #TP 1'b0;
                   read_enable_r <= #TP read_enable;  
end


//===================================================================================
// manage the read pointer and control skp add/rm
//===================================================================================
assign rdptr_gray_next    = (rdptr_bin_next>>1)^rdptr_bin_next;
assign rdptr_gray_next_p1 = (rdptr_bin_next_p1>>1)^rdptr_bin_next_p1;

always @(posedge pop_clk or negedge pop_rst_n)
    if (!pop_rst_n)         {rdptr_bin, rdptr_gray}  <= #TP '0; else
    if (clear_elasbuf)      {rdptr_bin, rdptr_gray}  <= #TP '0; else
                            {rdptr_bin, rdptr_gray}  <= #TP {rdptr_bin_next, rdptr_gray_next};


always @(posedge pop_clk or negedge pop_rst_n)
    if (!pop_rst_n)         {rdptr_bin_p1, rdptr_gray_p1}  <= #TP '0; else
    if (clear_elasbuf)      {rdptr_bin_p1, rdptr_gray_p1}  <= #TP '0; else
                            {rdptr_bin_p1, rdptr_gray_p1}  <= #TP {rdptr_bin_next_p1, rdptr_gray_next_p1};

// Synchronize the read pointer into the write domain 2 times

always @(posedge push_clk or negedge push_rst_n or posedge clear_elasbuf)
begin
    if (!push_rst_n) begin
        rdptr_gray_sync_wr1        <= #TP 0;
        rdptr_gray_sync_wr2        <= #TP 0;        
    end else if (clear_elasbuf) begin
        rdptr_gray_sync_wr1        <= #TP 0;
        rdptr_gray_sync_wr2        <= #TP 0;    
    end else begin
        rdptr_gray_sync_wr1        <= #TP rdptr_gray; 
        rdptr_gray_sync_wr2        <= #TP rdptr_gray_sync_wr1;
    end
end

assign empty_watermark = (rdptr_gray_next == wrptr_gray_sync_rd2);



always @(posedge pop_clk or negedge pop_rst_n)
begin
    if (!pop_rst_n) begin
       empty_watermark_r  <= #TP 0;
       empty_watermark_rr <= #TP 0;
       full_watermark_r  <= #TP 0;
       full_watermark_rr <= #TP 0;
       full_watermark_rrr <= #TP 0;
    end else begin
       empty_watermark_r  <= #TP empty_watermark;
       empty_watermark_rr <= #TP empty_watermark_r;
       full_watermark_r   <= #TP full_watermark;
       full_watermark_rr  <= #TP full_watermark_r;
       full_watermark_rrr <= #TP full_watermark_rr;
    end    
end



reg pre_elasbuf_overflow;


always @(posedge pop_clk or negedge pop_rst_n or posedge clear_elasbuf)
    if (!pop_rst_n) begin
      rdptr_bin_next       <= #TP 0;
      rdptr_bin_next_p1    <= #TP 1;   
      elasbuf_add_skip_p   <= #TP 0;
      add_skip_ctr         <= #TP '0;
   //   pre_elasbuf_overflow <= #TP 0;
    end else if (clear_elasbuf)  begin
      rdptr_bin_next       <= #TP 0;
      rdptr_bin_next_p1    <= #TP 1;
      elasbuf_add_skip_p   <= #TP 0;
      add_skip_ctr         <= #TP 3'b0;
    //  pre_elasbuf_overflow <= #TP 0;
    end else if (empty_watermark && !read_entry_skip) begin
      // underflow - stall read pointers
         rdptr_bin_next       <= #TP rdptr_bin_next;
         rdptr_bin_next_p1    <= #TP rdptr_bin_next_p1;
         elasbuf_add_skip_p   <= #TP 0;
         add_skip_ctr         <= #TP '0;    
         pre_elasbuf_overflow <= #TP 0;  
    end else if (full_watermark && !full_watermark_r) begin
      // overflow - bump read pointers
      rdptr_bin_next       <= #TP rdptr_bin_next + 2;
      rdptr_bin_next_p1    <= #TP rdptr_bin_next_p1 + 2;
      elasbuf_add_skip_p   <= #TP 0;
      add_skip_ctr         <= #TP '0;
    //  pre_elasbuf_overflow <= #TP 1;
    end else if ( (!(width == 4 && RXSB_WD == 1)) && ((below_watermark && read_entry_skip_lkah && !disable_skp_addrm_en && !read_entry_skip_deleted_lkah && req_rate < 2) ||
                                (below_watermark & read_entry_skip_lkah && !disable_skp_addrm_en && !read_entry_skip_deleted_lkah && req_rate > 1) ||
                                 add_skip_ctr > 0)) begin
      // SKIP ADD is not performed for 16s and startblock one bit
      // SKP symbol/block add - do not increment the read pointer
      // so same entry is read twice - use the add_skip_ctr to
      // re-enter this branch multiple times and introduce either
      // 4 or 8 (8s configs) SKP symbols at gen3/4 rate
      rdptr_bin_next       <= #TP rdptr_bin_next;
      rdptr_bin_next_p1    <= #TP rdptr_bin_next_p1;
      elasbuf_add_skip_p  <= #TP 1;
     // pre_elasbuf_overflow <= #TP 0;
      // if we started decrementing, than keep decrementing, we will reach zero
      //   and not enter this branch anymore
      // otherwise, if the rate is gen3 or gen4, initialize the counter with
      //   the number of symbols we still need to insert
      // otherwise just keep zero, as this is not gen3/4, and we're adding on
      //   a symbol boundary
      add_skip_ctr        <= #TP ( add_skip_ctr > 0 )                          ? add_skip_ctr-1 :
                                 ( req_rate > 1 && width == 3 && RXSB_WD == 1) ? 7           :
                                 ( req_rate > 1 )                              ? 3           : 0;

    // if 16s and startblock width == 1 we do not do skip add when below_watermark
    // but we put rx_datavalid == 0 for next 16s
    // devrement between 16 and 1 and use value 0 instead of add_skip_ctr_r when rx_datavalid needs to be 0
    end else if ((width > 3 && RXSB_WD == 1 && below_watermark && read_enable && !read_entry_lkah_dataskip  && !read_entry_skip_deleted_lkah && !push_clk_off && req_rate > 1) ||
                  add_skip_ctr > 1) begin
         // for GEN3/GEN4
         rdptr_bin_next       <= #TP rdptr_bin_next;
         rdptr_bin_next_p1    <= #TP rdptr_bin_next_p1;     
         add_skip_ctr    <= #TP (add_skip_ctr > 0) ? add_skip_ctr-1 : 16;
      //   pre_elasbuf_overflow <= #TP 0;
                 
    end else begin
      // Normal case: read if there are symbols in buffer
      if (read_enable && !fill_elasbuff && !empty_watermark) begin
         rdptr_bin_next       <= #TP rdptr_bin_next + 1;
         rdptr_bin_next_p1    <= #TP rdptr_bin_next_p1 + 1;
         elasbuf_add_skip_p  <= #TP 0;
         add_skip_ctr        <= #TP '0;
       //  pre_elasbuf_overflow <= #TP 0;
      end
    end

always @(posedge pop_clk or negedge pop_rst_n)
begin
   if (!pop_rst_n) add_skip_ctr_r <= #TP '0;
   else      add_skip_ctr_r       <= #TP  add_skip_ctr;
end

//===================================================================================
// Only allow one SKP to be added/removed from a SKP ordered set
//===================================================================================
// randomize skip delete indication between the beginning of the skip OS and end of skip OS
reg [23:0] delay_skip_drop;
reg [4:0]  delay_skip_drop_value;
wire [3:0] skip_del_block_length;

// number of symbols that are deleted 
assign skip_del_block_length =  ( req_rate > 1 && width == 3 && RXSB_WD == 1) ? 8 :
                                ( req_rate > 1 )                              ? 4 : 4; 

// this value it is randomized between 0 and length of the skip 
// length of the skip is length at entry in elastic buffer - the symbols that are deleted 
// if the length at entry is minumum (4 symbols) and this are deleted then no randomization
always @(posedge pop_clk or negedge pop_rst_n)
begin
    if (!pop_rst_n)                             delay_skip_drop_value <= #TP 0; else 
    if (elasticbuffermode)                      delay_skip_drop_value <= #TP 0; else       
    if (read_entry_skip_lkah && req_rate > 1)   delay_skip_drop_value <= #TP (skip_length_q[0] - skip_del_block_length) > 0 ? $urandom_range(0, skip_length_q[0]-skip_del_block_length-1) : '0; else
                                                delay_skip_drop_value <= #TP delay_skip_drop_value;    
end    

// this is used to delay the skip delete indication
// position 0 means no delay
always @(posedge pop_clk or negedge pop_rst_n)
begin
    if (!pop_rst_n)                               delay_skip_drop    <= #TP '0; else
    if (elasticbuffermode)                        delay_skip_drop    <= #TP '0; else
    if (read_entry_skip_deleted)                  delay_skip_drop[0] <= #TP read_entry_skip_deleted; else
    if (delay_skip_drop[delay_skip_drop_value+1]) delay_skip_drop    <= #TP '0; else
                                                  delay_skip_drop    <= #TP delay_skip_drop << 1;
end

//===================================================================================
// randomize skip add indication between the beginning of the skip OS and end of skip OS 
reg [23:0] delay_skip_add;
reg [4:0]  delay_skip_add_value;
wire [3:0] skip_add_block_length;


// number of symbols that are added
assign skip_add_block_length =  ( req_rate > 1 && width == 3 && RXSB_WD == 1) ? 8 : 4; 

// this value it is randomized between 0 and length of the skip 
// length of the skip is length at entry in elastic buffer + the symbols that are deleted 
always @(posedge pop_clk or negedge pop_rst_n)
begin
    if (!pop_rst_n)                              delay_skip_add_value <= #TP 0; else 
    if (read_entry_skip_lkah && req_rate > 1)    delay_skip_add_value <= #TP $urandom_range(0, (skip_length_q.size() > 0 ? skip_length_q[0] : skip_length)+skip_add_block_length-1); else
                                                 delay_skip_add_value <= #TP delay_skip_add_value;          
end    

// this is used to delay the skip add indication
// position 0 means no delay
always @(posedge pop_clk or negedge pop_rst_n)
begin
    if (!pop_rst_n)                             delay_skip_add    <= #TP '0; else
    if (elasbuf_add_skip_r)                     delay_skip_add[0] <= #TP elasbuf_add_skip_r; else
    if (delay_skip_add[delay_skip_add_value+1]) delay_skip_add    <= #TP '0; else
                                                delay_skip_add    <= #TP delay_skip_add << 1;
end

// this is the indication of skip add in synch with startblock                                                     
assign elasbuf_add_skip_r  = (req_rate > 1)  ? elasbuf_add_skip_p && !elasbuf_add_skip_rr  : elasbuf_add_skip_p;


always @(posedge pop_clk or negedge pop_rst_n)
begin
    if (!pop_rst_n) begin
        skip_already_added   <= #TP 1'b0;
        skip_already_added_r <= #TP 1'b0;
    end else begin
        skip_already_added   <= #TP read_entry_skip || add_skip_ctr > 0;
        skip_already_added_r <= #TP skip_already_added;
    end
end    
//===================================================================================
// Read out the data and drive the sideband signals (skp add/rm and over/underflow)
// that need to be aligned with data
//
// IMPORTANT: data output from this block goes through an additional pipeline
// stage (10b8b decoder, regardless of rate) before entering pipe2phy, however
// sideband signals go straight into pipe2phy. This is why data and sideband
// signals are not aligned at the output of this block. This is not ideal and
// should be rectified in future versions of this code
//===================================================================================
reg datavalid_emptymode_r;

always @(posedge pop_clk or negedge pop_rst_n)
    if (!pop_rst_n) begin
        elasbuf_rxdata_10b       <= #TP 10'b0;
        elasbuf_dv               <= #TP 1'b0;
        elasbuf_add_skip_rr      <= #TP 1'b0;
        elasbuf_underflow        <= #TP 1'b0;
        elasbuf_overflow         <= #TP 1'b0;
        elasbuf_datavalid        <= #TP 1'b0;
        datavalid_emptymode      <= #TP 1'b0;
        datavalid_emptymode_r    <= #TP 1'b0;
        elasbuf_skip_broken      <= #TP 1'b0;
        
        elasbuf_startblock       <= #TP 1'b0;
        elasbuf_synchdr          <= #TP 2'b0;
        elasbuf_drop_skip_out    <= #TP 1'b0;
    end else if (!read_enable || elasticbuffermode_change) begin 
        elasbuf_rxdata_10b       <= #TP 10'b0;
        elasbuf_dv               <= #TP 1'b0;
        elasbuf_add_skip_rr      <= #TP 1'b0;
        elasbuf_underflow        <= #TP 1'b0;
        elasbuf_overflow         <= #TP 1'b0;
        elasbuf_skip_broken      <= #TP 1'b0;
        elasbuf_drop_skip_out    <= #TP 1'b0;
        
        elasbuf_datavalid        <= #TP (req_rate > 1) ? 1'b0 : 1'b1;
        datavalid_emptymode      <= #TP 1'b1;
        datavalid_emptymode_r    <= #TP (req_rate > 1) ? 1'b0 : 1'b1;
        
        elasbuf_startblock       <= #TP 1'b0;
        elasbuf_synchdr          <= #TP 2'b0;
    end else begin
        elasbuf_skip_broken      <= #TP read_entry_skip_broken;
        elasbuf_rxdata_10b       <= #TP read_entry_data;        
        elasbuf_dv               <= #TP (!push_clk_off && !datavalid_emptymode_r) ? elasbuf_dv :
                                        (elasbuf_add_skip_p & req_rate < 2) ? read_entry_dv_lkah : read_entry_dv;
                        
        elasbuf_add_skip_rr      <= #TP elasbuf_add_skip_p;
        elasbuf_underflow        <= #TP (read_entry_dv && !elasticbuffermode && !clear_elasbuf) ? empty_watermark_rr : 1'b0;
        elasbuf_overflow         <= #TP !full_watermark && full_watermark_r;
        // for nominal empty mode
        datavalid_emptymode      <= #TP (!clear_elasbuf) ? !empty_watermark : 1'b1;
        datavalid_emptymode_r    <= #TP datavalid_emptymode;
        
        elasbuf_datavalid        <= #TP (!elasticbuffermode && req_rate > 1 && width > 3 && RXSB_WD == 1 && add_skip_ctr_r > 0)  ? 1'b0 : // half full 16s stall 
                                        (!elasticbuffermode && req_rate > 1  ) ? ~read_entry_dataskip : // half full normal op
                                        (!elasticbuffermode && req_rate <= 1 ) ? 1'b1 :                 // half full gen1/2
                                        (elasticbuffermode && req_rate > 1) ?  ~read_entry_dataskip && datavalid_emptymode_r : // empty mode gen3/4
                                                                                datavalid_emptymode_r;  // empty mode gen1/2
                                       
         elasbuf_drop_skip_out  <= #TP (elasticbuffermode && req_rate > 1 )     ? read_entry_skip_deleted && read_entry_startblock && datavalid_emptymode_r : //empty mode we do not delay  
                                       (elasticbuffermode && req_rate < 2 )     ? read_entry_skip_deleted && datavalid_emptymode_r : //empty mode we do not delay
                                       (req_rate < 2 )                          ? read_entry_skip_deleted  : //gen1/2 we do not delay 
                                       (delay_skip_drop_value == 0 )            ? read_entry_skip_deleted && read_entry_startblock && datavalid_emptymode_r : delay_skip_drop[delay_skip_drop_value];                                                                                                                                                          

         // this is the indication of skip add that we output
         // the indication can be anywhere between the beginning of the skip and end of the skip
         elasbuf_add_skip_out <= #TP  (req_rate < 2)                              ? elasbuf_add_skip_r  : //gen1/2 we don't delay
                                      (req_rate > 1 && delay_skip_add_value == 0) ? elasbuf_add_skip_r  : delay_skip_add[delay_skip_add_value];
        
         elasbuf_synchdr          <= #TP read_entry_synchdr; 
                                        
         elasbuf_startblock       <= #TP read_entry_startblock & datavalid_emptymode_r;                                           
    end


//===================================================================================
// MAC Register 12'h004 RX1: ElasticBufferLocation
//===================================================================================
assign elasbuf_location = { {(8-PW){1'b0}}, symbols_in_buf};

endmodule: DWC_pcie_gphy_elasbuf

