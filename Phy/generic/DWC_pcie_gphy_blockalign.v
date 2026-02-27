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
// ---    $Revision: #21 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_blockalign.v#21 $
// -------------------------------------------------------------------------
// --- Module Description:  Generic comma detect function.  Pulled out of the
// --- generic r_phy_deser module as some SerDes vendors do not support this.
// --- SDM may or may not assume this capability.
// ---
// --- This module assumes no bit clock is available and must brute force select
// --- alignment based on the symbol clock and 10 bit data paths.  May convert
// --- selectable datapaths in a future version.
// -----------------------------------------------------------------------------

module DWC_pcie_gphy_blockalign # (
     parameter TP       = 0,
     parameter PIPE_NB  = 0,
     parameter WIDTH_WD = 0
   )
   (
   input                     recvdclk,                   // symbol clock
   input                     rst_n,                      // reset
   input   [7:0]             rxdata_nonaligned,          // non-aligned parallel receive data
   input   [2:0]             req_rate, 
   input   [2:0]             rate,                       // 1 = run at 5 Gbit/s, 2 = run at 8 Gbit/s
   input   [WIDTH_WD-1:0]    width,                      // 0 = 1s; 1 = 2s; 2 = 4s ; 3 = 8s 
   input                     rxelecidle,                 // rx electrical idle
   input                     ba_ctrl,                    // block alignment control
   input                     rxloopback,                 // tx detectrx loopback
   input                     syncheader_random_en,       // if set generate random syncheader
   `ifdef GPHY_ESM_SUPPORT
   input            esm_enable,
   input [6:0]      esm_data_rate0,
   input [6:0]      esm_data_rate1,
   `endif // GPHY_ESM_SUPPORT   
    
   output           block_aligned_out,              // block alignment achieved
   output reg [9:0] rxdata_aligned,             // aligned parallel receive data
   output reg       rxdata_skip,                // skip this cycle of data
   output reg       rxdata_start,               // sync header valid this cycle
   output reg [1:0] rxdata_synchdr,             // sync header received on wire
   output           skp_broken,
   output           skp_detected

);

timeunit 1ns;
     
parameter BA_WIDTH       = PIPE_NB*8;
parameter BA_END_CNT     = (PIPE_NB*64);
parameter BA_WRAP_CNT    = BA_END_CNT + (PIPE_NB - 1);
parameter BA_SKIP_END    = (PIPE_NB==1) ? 5 :
                           (PIPE_NB==2) ? 6 :
                           (PIPE_NB==4) ? 7 : 8;
parameter BA_SYM_CNT_END = BA_SKIP_END + 1;
parameter BA_CNT_WIDTH   = (PIPE_NB==1) ? 3 :
                           (PIPE_NB==2) ? 4 :
                           (PIPE_NB==4) ? 5 : 6;
parameter BLOCK_WIDTH    = 130;
parameter COMPARE_WIDTH  = BLOCK_WIDTH + BA_WIDTH + 8;



//==============================================================================
// Internal signals
//==============================================================================
/** enum for block align state machine */
typedef enum { S_BA_UNALIGNED, S_BA_ALIGNED, S_BA_LOCKED } t_blockalign;
t_blockalign    blockalign_state;
t_blockalign    next_blockalign_state;

wire                   eieos_detected;
reg                    sds_detected;
wire                   eios_detected;
reg                    eios_detected_r;
reg                    eios_detected_rr;
reg                    eios_detected_latch;
wire                   start_block_condition;
//wire                   skp_detected;
reg                    block_locked; 
reg  [2:0]             rate_r;     
wire                   rate_changing;  

reg                    block_aligned;
reg                    block_aligned_r; 

wire [BLOCK_WIDTH-1:0]   eieos_block;
wire [BLOCK_WIDTH-1:0]   sds_block;
wire [BLOCK_WIDTH-1:0]   eios_block;
wire [BLOCK_WIDTH-1:0]   skp_block; 


wire [BA_WIDTH-1:0]      eieos_block_detected;      
reg  [BA_WIDTH-1:0]      next_eieos_block_detected; 
wire [BA_WIDTH-1:0]      sds_block_detected;        
wire [BA_WIDTH-1:0]      eios_block_detected;       
wire [BA_WIDTH-1:0]      skp_block_detected;  

reg  [COMPARE_WIDTH-1:0] rxdata_compare_i;
reg  [COMPARE_WIDTH-1:0] rxdata_compare_shifted;
wire [COMPARE_WIDTH-1:0] rxdata_compare_for_syncheader;
wire [COMPARE_WIDTH-1:0] rxdata_compare_mux;
reg  [COMPARE_WIDTH-1:0] rxdata_compare_out;


wire [1:0]               current_synchdr;
wire                     undef_synchdr;
wire [1:0]               synchdr;
reg  [7:0]               rxdata_select;
reg                      goto_unaligned;
wire                     end_block;
wire                     skp_end;
wire                     eios_end;
reg                      dataskip;
wire                     start_block;
wire                     gen3_loopback;
wire                     first_eieos;
reg  [3:0]               eios_counter;

reg   [9:0]              first_eieos_block_detected_shift;
wire  [9:0]              eieos_block_detected_shift;
wire  [9:0]              current_block_alignment_shift;
wire  [9:0]              current_block_alignment_mux;
reg  [BA_WIDTH-1:0]      current_block_alignment;

wire [6:0]               nr_of_sym_decoded;        
wire [8:0]               nr_of_starblocks_decoded;    
reg  [9:0]               startblock_cnt;           
reg  [4:0]               sym_to_startblock_cnt;    
wire [9:0]               WRAP_CNT;                 

wire [7:0]               skip_body_sym;                

// number of symbols 
assign nr_of_sym_decoded = (width == 0) ? 1 :
                           (width == 1) ? 2 :
                           (width == 2) ? 4 : 
                           (width == 3) ? 8 : 16;
                           
//number of startblock between 2 dataskips                                     
assign nr_of_starblocks_decoded = (width == 0) ? 4 :
                                  (width == 1) ? 8 :
                                  (width == 2) ? 16 :
                                  (width == 3) ? 32 : 64;

// used to know when to clear dataskip
assign WRAP_CNT = (width == 0) ? 16 + 1 :
                  (width == 1) ? 16 + 2 :
                  (width == 2) ? 16 + 4 : 
                  (width == 3) ? 16 + 8 : 16 + 16; 
                                
// only use loopback at gen3 rate
assign  gen3_loopback = rxloopback & (rate > 1);

// rate delayed
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) rate_r <= #TP 3'b000; else
                rate_r <= #TP rate;     
end

// rate changing
assign rate_changing = (req_rate != rate);

//==============================================================================
// State machine for block alignment implementation.
// 00 = unaligned
// 01 = aligned
// 10 = locked
//==============================================================================
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
      blockalign_state   <= #TP S_BA_UNALIGNED;
      block_aligned      <= #TP 0;
      block_locked       <= #TP 0;
      goto_unaligned     <= #TP 0;     
    end else begin            
      unique case (blockalign_state)
      
      S_BA_UNALIGNED: begin
        block_locked     <= #TP 0;
        block_aligned    <= #TP (eieos_detected && ba_ctrl) ? 1 : 0;  
        goto_unaligned   <= #TP 0;   
        blockalign_state <= #TP (eieos_detected && ba_ctrl) ? S_BA_ALIGNED : S_BA_UNALIGNED;
      end          
      
      S_BA_ALIGNED: begin
        block_locked     <= #TP 0;
        block_aligned    <= #TP (eieos_detected && ba_ctrl && !undef_synchdr)                     ? 1'b1 :
                                (rate_changing)                                                   ? 1'b0 :
                                (undef_synchdr ||  (eios_detected_latch & start_block_condition)) ? 1'b0 : 
                                start_block                                                       ? 1'b1 : block_aligned;
                                
        goto_unaligned   <= #TP (rate < 2)                                                        ? 1'b1 :
                                (rate_changing)                                                   ? 1'b1 :
                                (eieos_detected && ba_ctrl && !undef_synchdr)                     ? 1'b0 : 
                                (undef_synchdr ||  (eios_detected_latch & start_block_condition)) ? 1'b1 : 1'b0;                      
      
        blockalign_state <= #TP (rate < 2)                  ? S_BA_UNALIGNED :
                                (rate_changing)             ? S_BA_UNALIGNED :
                                sds_detected                ? S_BA_LOCKED    : 
                                (eieos_detected && ba_ctrl && !undef_synchdr) ? S_BA_ALIGNED:
                                (undef_synchdr || (eios_detected_latch & start_block_condition)) ? S_BA_UNALIGNED : S_BA_ALIGNED;
                                
                                 
      end
      
      S_BA_LOCKED: begin
        block_locked     <= #TP 1;
        
        block_aligned    <= #TP (rate < 2)                                     ? 1'b0 :
                                (rate_changing)                                ? 1'b0 :  
                                (gen3_loopback & eios_detected_latch & 
                                  start_block_condition & eios_counter == 4)   ? 1'b0 :
                                 gen3_loopback                                 ? 1'b1 :
                                (eios_detected_latch & start_block_condition)  ? 1'b0 : 1'b1;
        
        goto_unaligned   <= #TP (rate < 2)                                     ? 1'b1 : 
                                (rate_changing)                                ? 1'b1 :                             
                                (gen3_loopback & eios_detected_latch & 
                                   start_block_condition & eios_counter == 4)  ? 1'b1 :
                                (gen3_loopback)                                ? 1'b0 :                                
                                (eios_detected_latch & start_block_condition)  ? 1'b1 : 
                                (undef_synchdr && ba_ctrl)                     ? 1'b0 : 1'b0;
        
        blockalign_state <= #TP (rate < 2)                                     ? S_BA_UNALIGNED :
                                (rate_changing)                                ? S_BA_UNALIGNED :
                                (gen3_loopback & eios_detected_latch & 
                                   start_block_condition & eios_counter == 4)  ? S_BA_UNALIGNED :
                                 gen3_loopback                                 ? S_BA_LOCKED    :
                                (eios_detected_latch & start_block_condition)  ? S_BA_UNALIGNED :
                                (undef_synchdr )                               ? S_BA_ALIGNED   :
                                (eieos_detected)                               ? S_BA_ALIGNED   : S_BA_LOCKED;
                                
                                
      end
      endcase
    end
end


//==============================================================================
// Register the receive data for comparison... this is specific to the 1s
// implementation.
// 1. shift in data as it comes in
// 2. adjust with initial alignment => rxdata_compare_shifted
// 3. rxdata_compare_out is shifted with the block alignment shift amount (+2 bits each syncheader)
//==============================================================================
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
        rxdata_compare_i        <= #TP '0;
        rxdata_compare_shifted  <= #TP '0;
    end else begin
        rxdata_compare_i        <= #TP {rxdata_nonaligned,rxdata_compare_i[COMPARE_WIDTH-1:8]};
        rxdata_compare_shifted  <= #TP rxdata_compare_i >> (first_eieos ? eieos_block_detected_shift : first_eieos_block_detected_shift);
    end
end

// decode current syncheade from the input data stream
// we need to know this in advance for OS streams to be detected corectly in advance 
assign rxdata_compare_for_syncheader = (blockalign_state == S_BA_UNALIGNED 
                                        || (undef_synchdr && ba_ctrl && !block_locked)) ? (rxdata_compare_i >> eieos_block_detected_shift) :
                                                                                          (rxdata_compare_shifted >> eieos_block_detected_shift); 
assign current_synchdr = rxdata_compare_for_syncheader[1:0];

assign rxdata_compare_mux = (!block_aligned || (undef_synchdr && ba_ctrl && !block_locked)) ? rxdata_compare_i : rxdata_compare_shifted;
assign rxdata_compare_out = rxdata_compare_shifted >> current_block_alignment_shift;
assign synchdr            = rxdata_compare_out[1:0];
assign rxdata_select      = rxdata_compare_out[9:2];

 
//==============================================================================
// Simple compare across the bits for the right patterns and latch immediately
//==============================================================================
// this are the templates for OS streams

assign current_block_alignment_mux = (undef_synchdr && ba_ctrl && !block_locked) ? 10'b0 : current_block_alignment_shift;

assign eieos_block = `ifdef GPHY_ESM_SUPPORT
                     (rate>=3 && esm_enable && esm_data_rate1 != `GPHY_ESM_RATE1_16GT)? {{2{`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_1,
                                                  `GPHY_EIEOS_SYM_0, `GPHY_EIEOS_SYM_0, `GPHY_EIEOS_SYM_0, `GPHY_EIEOS_SYM_0}},`GPHY_BASYNC_OS_BLOCK}:
                                                  
                     (rate==3 && esm_enable && esm_data_rate1 == `GPHY_ESM_RATE1_16GT) ? {{4{`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_0,`GPHY_EIEOS_SYM_0}},`GPHY_BASYNC_OS_BLOCK}:                                                                               
                     (rate==2 && esm_enable && esm_data_rate0 == `GPHY_ESM_RATE0_16GT) ? {{4{`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_0,`GPHY_EIEOS_SYM_0}},`GPHY_BASYNC_OS_BLOCK}:
                     `endif //GPHY_ESM_SUPPORT
                     (rate==4)? {{2{`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_1, 
                                    `GPHY_EIEOS_SYM_0,`GPHY_EIEOS_SYM_0,`GPHY_EIEOS_SYM_0,`GPHY_EIEOS_SYM_0}},`GPHY_BASYNC_OS_BLOCK}:                                     
                     (rate==3)? {{4{`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_0,`GPHY_EIEOS_SYM_0}},`GPHY_BASYNC_OS_BLOCK}: 
                     {{8{`GPHY_EIEOS_SYM_1,`GPHY_EIEOS_SYM_0}},`GPHY_BASYNC_OS_BLOCK};
                     
                     
assign sds_block   =    (rate==4) ? {{15{`GPHY_SDS_SYM_1_GEN5_R07_ENC}},`GPHY_SDS_SYM_0,`GPHY_BASYNC_OS_BLOCK}  :
                                    {{15{`GPHY_SDS_SYM_1}},`GPHY_SDS_SYM_0,`GPHY_BASYNC_OS_BLOCK};

assign eios_block  = {96'H0,{4{`GPHY_EIOS_SYM_0}},`GPHY_BASYNC_OS_BLOCK};

assign skp_block   =    (rate==4) ? {96'H0,{4{`GPHY_SKP_SYM_0_GEN5_R07_ENC}},`GPHY_BASYNC_OS_BLOCK}  :
                                    {96'H0,{4{`GPHY_SKP_SYM_0}},`GPHY_BASYNC_OS_BLOCK};

assign skip_body_sym =    (rate==4) ? `GPHY_SKP_SYM_0_GEN5_R07_ENC  :
                                      `GPHY_SKP_SYM_0;

// we detect an OS in an OS stream and the position where the OS was found in the input data stream is returned
assign skp_block_detected   = (rate < 2) ? 0 : match_block(current_block_alignment_mux,skp_block,  rxdata_compare_mux[COMPARE_WIDTH-1:0],{{96{1'b0}},{34{1'b1}}} ,0,0,block_aligned);

assign eieos_block_detected = (rate < 2) ? 0 : match_block(current_block_alignment_mux,eieos_block,rxdata_compare_mux[COMPARE_WIDTH-1:0],            {130{1'b1}} ,1,0,block_aligned);

assign sds_block_detected   = (rate < 2) ? 0 : match_block(current_block_alignment_mux,sds_block,  rxdata_compare_mux[COMPARE_WIDTH-1:0],            {130{1'b1}} ,0,0,block_aligned);


assign eios_block_detected  =   (rate==4)  ? match_block(current_block_alignment_mux,eios_block, rxdata_compare_mux[COMPARE_WIDTH-1:0],{{96{1'b0}},{34{1'b1}}} ,0,1,block_aligned) :
                                (rate < 2) ? 0 : match_block(current_block_alignment_mux,eios_block, rxdata_compare_mux[COMPARE_WIDTH-1:0],{{96{1'b0}},{34{1'b1}}} ,0,0,block_aligned);

assign eieos_detected = (|eieos_block_detected) && (current_synchdr == 2'b01) && (eieos_block_detected_shift != 10'h8 || block_aligned) 
                                                                              && (((eieos_block_detected_shift + first_eieos_block_detected_shift)!=10'h8 || block_aligned));
assign sds_detected   = |sds_block_detected  & block_aligned;
assign eios_detected  = |eios_block_detected & block_aligned & (synchdr == 2'b01) & start_block;

assign skp_detected   = (|skp_block_detected)  & block_aligned & (synchdr == 2'b01) & start_block;

// we need to flag a new EIEOS only when the alignment has been changes
reg  eieos_detected_d;
wire eieos_detected_posedge;
wire new_eieos_alignment_detected;

// signal when we detect the first EIEOS
assign first_eieos = (eieos_detected & !block_aligned & (current_block_alignment == 128'b0) & ba_ctrl);// || 
                   //  (eieos_detected & (undef_synchdr || goto_unaligned) & ba_ctrl & !block_locked ); 

// detect the amount we have to shift the input data to be aligned
// we always have to shift the input data with this amount
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n)                first_eieos_block_detected_shift <= 6'b0;
    else if (goto_unaligned)   first_eieos_block_detected_shift <= 6'b0;
    else if (first_eieos)      first_eieos_block_detected_shift <= #TP eieos_block_detected_shift;
    else                       first_eieos_block_detected_shift <= #TP first_eieos_block_detected_shift;
end

// register eieos_detected
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n)   eieos_detected_d <= #TP 1'b0;
    else          eieos_detected_d <= #TP eieos_detected;
end

assign eieos_detected_posedge       = eieos_detected & !eieos_detected_d;          
assign new_eieos_alignment_detected = eieos_detected_posedge && (current_block_alignment != eieos_block_detected) && (current_block_alignment_shift != '0) ;


// at 8Gbit/s we have a 128/130 bit encoding
// every time a 2-bit sync header is received, the alignment changes
// rxdata_compare_shifted is shifted with this amount to get rxdata_compare_out 
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
        current_block_alignment   <= #TP 0;
    end else if (first_eieos) begin
        current_block_alignment   <= #TP 1;
    end else if (goto_unaligned || rate_changing) begin
        current_block_alignment   <= #TP 0;
    end else if (!block_locked && (new_eieos_alignment_detected)) begin
        current_block_alignment   <= #TP eieos_block_detected;
    end else if (end_block && (startblock_cnt == nr_of_starblocks_decoded)) begin
        current_block_alignment   <= #TP 1;
    end else if (end_block) begin
        current_block_alignment   <= #TP current_block_alignment << 2;
    end
end

//==============================================================================
// EIOS detection
//  
// once and EIOS is detected, then de-assert rx_valid (block_aligned)
//==============================================================================
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
        eios_detected_r  <= #TP 0;
        eios_detected_rr <= #TP 0;
    end else begin
        eios_detected_r  <= #TP eios_detected;
        eios_detected_rr <= #TP eios_detected_r;
    end
end


always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
        eios_detected_latch  <= #TP 0;
        eios_counter         <= #TP 4'b0;
    end else if (blockalign_state == S_BA_UNALIGNED) begin
        eios_detected_latch  <= #TP 0;
        eios_counter         <= #TP 4'b0;  
    end else if (eios_detected_rr & !gen3_loopback) begin 
        eios_detected_latch  <= #TP 1; 
        eios_counter         <= #TP eios_counter;
    end else if (eios_detected_rr & (eios_counter >= 4) & gen3_loopback) begin
        eios_detected_latch  <= #TP 1;   
        eios_counter         <= #TP eios_counter;
    end else if (eios_detected_r & rxdata_start) begin
        eios_counter         <= #TP eios_counter + 1;
        eios_detected_latch  <= #TP 0;
    end
end

//==============================================================================
// SKP detection
//==============================================================================
// latch the fact that we have seen a SKP
// once a SKP is seen look for the end
// once SKP_END is seen, then wait 3 cycles (for LFSR) and move alignment
// once skp is detected, then wait until maximum length of skip to go by (24 symbols)
// when skip detected, 4 symbols have gone by
// if no end then unaligned
reg    in_skp_os;
reg    latch_skp_end_sym_seen;
wire   skp_end_sym_seen;
wire   no_skp_end_sym_seen;
reg [7:0] skp_end_count;
reg [7:0] skp_count;

//---------------------------------------------------
reg skip_detected_but_broken;
reg in_data_block;

always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n)                                 in_data_block <= #TP 0;
    else if (start_block && synchdr == 2'b01)   in_data_block <= #TP 0;
    else if (start_block && synchdr == 2'b10)   in_data_block <= #TP 1;
    else                                        in_data_block <= #TP in_data_block;        
end 

always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin                   
        skip_detected_but_broken <= #TP 0;
    end else begin
      if (rxdata_start &&  rxdata_synchdr == 2'b01 && 
           ((rxdata_compare_out[9:2] != 'hAA && rxdata_compare_out[17:10] == 'hAA && rxdata_compare_out[25:18] == 'hAA && rxdata_compare_out[33:26] == 'hAA) || 
            (rxdata_compare_out[9:2] == 'hAA && rxdata_compare_out[17:10] != 'hAA && rxdata_compare_out[25:18] == 'hAA && rxdata_compare_out[33:26] == 'hAA) ||
            (rxdata_compare_out[9:2] == 'hAA && rxdata_compare_out[17:10] == 'hAA && rxdata_compare_out[25:18] != 'hAA && rxdata_compare_out[33:26] == 'hAA) ||
            (rxdata_compare_out[9:2] == 'hAA && rxdata_compare_out[17:10] == 'hAA && rxdata_compare_out[25:18] == 'hAA && rxdata_compare_out[33:26] != 'hAA)  )) 
                                   
         skip_detected_but_broken <= #TP 1;   
      else if ((rxdata_select == `GPHY_SKP_END_SYM) || (rxdata_select == `GPHY_SKP_END_CTL_SYM) || (skp_count == 25) )  
         skip_detected_but_broken <= #TP 0;
      else  skip_detected_but_broken <= #TP skip_detected_but_broken;  
      
    end
end    
        


//--------------------------------------------------



// this should be looking for module 4 SKP symbols and then SKP_END
assign skp_end_sym_seen    = in_skp_os && !latch_skp_end_sym_seen && ((rxdata_select == `GPHY_SKP_END_SYM) || (rxdata_select == `GPHY_SKP_END_CTL_SYM));
assign no_skp_end_sym_seen = in_skp_os && (skp_count == 25);

// decide when receiving a skp os
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n)                         in_skp_os <= #TP 0;
    else if (goto_unaligned || skp_end) in_skp_os <= #TP 0;
    else if (skp_detected)              in_skp_os <= #TP 1;
    else if (skip_detected_but_broken)  in_skp_os <= #TP 1;
    else                                in_skp_os <= #TP in_skp_os;
end

// count the number of cycles in skp
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n)          skp_count <= #TP 0;
    else if (in_skp_os)  skp_count <= #TP skp_count + 1;
    else                 skp_count <= #TP 0;   
end

// SKP gen3 check
reg skp_broken_int, skp_broken_int_r;
wire skp_broken_pulse;
assign skp_broken_pulse = skp_broken_int && !skp_broken_int_r;

always @(posedge recvdclk or negedge rst_n)
begin
   if (!rst_n) skp_broken_int <= #TP 1'b0;    
   else if (in_skp_os && !latch_skp_end_sym_seen)
   begin
      if (!(rxdata_select == skip_body_sym || rxdata_select ==`GPHY_SKP_END_SYM || rxdata_select ==`GPHY_SKP_END_CTL_SYM ))
         skp_broken_int <= #TP 1'b1;         
   end else if (skip_detected_but_broken) begin
         skp_broken_int <= #TP 1'b1;
   end else if (!in_skp_os)  begin
         skp_broken_int <= #TP 1'b0;
   end   
end

always @(posedge recvdclk or negedge rst_n)
begin
   if (!rst_n) skp_broken_int_r <= #TP 1'b0;    
   else        skp_broken_int_r <= #TP skp_broken_int;   
end

// latch where the end of the skp os should be
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n)                             skp_end_count <= #TP 32;
    else if (in_skp_os && skp_end_sym_seen) skp_end_count <= #TP skp_count + 3;
    else if (goto_unaligned || skp_end)     skp_end_count <= #TP 32;    
end

// latch the fact that the skp end symbol has been seen
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n)                             latch_skp_end_sym_seen <= #TP 0;
    else if (in_skp_os && skp_end_sym_seen) latch_skp_end_sym_seen <= #TP 1;
    else if (goto_unaligned || skp_end)     latch_skp_end_sym_seen <= #TP 0;    
end

// detect skip end adn skip broken
assign skp_end    = in_skp_os && (skp_count == skp_end_count);
assign skp_broken = skp_broken_pulse;

//==============================================================================
// create start and end block signals to be used
// bits[3:0] are used for every block.
//==============================================================================
assign  start_block            = start_block_condition && !goto_unaligned;
assign  undef_synchdr          = ((synchdr==2'b00) || (synchdr==2'b11)) && start_block_condition && !dataskip;
assign  start_block_condition  = ((sym_to_startblock_cnt == 16) && (!dataskip));
assign  end_block              = ((sym_to_startblock_cnt == 15) & !in_skp_os) || skp_end;
                
//==============================================================================
// skip data (rxdatavalid to 0 for one clock cycle)
// during this cycle we output the backlog data (previous N syncheaders): N * 2 bits
// rxdatavalid == !dataskip
//==============================================================================
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
      dataskip <= #TP 0;
    end else if (first_eieos) begin
      dataskip <= #TP 0;
    end else if ((startblock_cnt == nr_of_starblocks_decoded) && (skp_end | end_block)) begin
      dataskip <= #TP 1;
    end else if (sym_to_startblock_cnt == WRAP_CNT - 1) begin
      dataskip <= #TP 0;
    end else if (!block_aligned) begin
      dataskip <= #TP 1;
    end
    
end

//==============================================================================
// count 16 symbols between 2 startblocks
// if skip is shorter force startblock
// if skip is longer delay statblock till skip end
//==============================================================================
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n)                                  sym_to_startblock_cnt <= #TP 0;                     else
    if (first_eieos)                             sym_to_startblock_cnt <= #TP 16;                    else
    if (start_block)                             sym_to_startblock_cnt <= #TP 1;                     else
    if (sym_to_startblock_cnt == WRAP_CNT - 1)   sym_to_startblock_cnt <= #TP 16;                    else
    if (skp_end)                                 sym_to_startblock_cnt <= #TP 16;                    else 
    if (in_skp_os  && (skp_count >= 12))         sym_to_startblock_cnt <= #TP sym_to_startblock_cnt; else 
    if (block_aligned)                           sym_to_startblock_cnt <= #TP sym_to_startblock_cnt + 1;  else
    if (!block_aligned)                          sym_to_startblock_cnt <= #TP 0;                     
end

//==============================================================================
// count number of startblocks
// reset when dataskip
//==============================================================================
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n)           startblock_cnt <= #TP 0; else  
    if (dataskip)         startblock_cnt <= #TP 0; else 
    if (start_block)      startblock_cnt <= #TP startblock_cnt + 1;  else
    if (!block_aligned)   startblock_cnt <= #TP 0;      
end

//==============================================================================
// Register aligned RX data
// This are the outputs of the module
//==============================================================================
// extend output data on 9 bits
always @(posedge recvdclk or negedge rst_n)
    if (!rst_n) rxdata_aligned <= #TP 0;
    else        rxdata_aligned <= #TP {2'h0,rxdata_select};

// when syncheader_random_en is through, the syncheader it is passed through 
// (not gated with start_block), so that it looks like random. This helps in 
// testing the robustness of the attached controller
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
        rxdata_synchdr <= #TP 0;
    end else if (start_block || syncheader_random_en) begin
        rxdata_synchdr <= #TP synchdr;
    end else begin
        rxdata_synchdr <= #TP 0;
    end
end

// output signals: startblock and datavalid = !dataskip
always @(posedge recvdclk or negedge rst_n)
begin
    if (!rst_n) begin
      rxdata_skip     <= #TP 0;
      rxdata_start    <= #TP 0;
      block_aligned_r <= #TP 0;
    end else begin
      rxdata_skip     <= #TP dataskip;
      rxdata_start    <= #TP start_block;
      block_aligned_r <= #TP block_aligned;
    end
end

 assign block_aligned_out = block_aligned && block_aligned_r;
 

 assign current_block_alignment_shift = shifter(current_block_alignment);
 assign eieos_block_detected_shift    = shifter(eieos_block_detected);

// ==============================================================================
// this function is searching a  specific data block in a stream of data
// the function it is reaturning the position where the data block was found, it is was found
// ==============================================================================
function [BA_WIDTH-1:0]    match_block;
input integer              current_alignment_int; // this is amount data needs to be shift to be aligned
input [BLOCK_WIDTH-1:0]    block_to_match;        // this is the block that needs to be found
input [COMPARE_WIDTH-1:0]  data_to_compare;       // this is the stream of data in whih we need to search
input [BLOCK_WIDTH-1:0]    bit_mask;              // this is the mask of the steam in which to search
input integer              search_for_eieos;      // enable search of EIEOS
input integer              search_for_eios;       // enable search of EIOS
input                      block_aligned;              // if dataskip need to add offset to the shift amount 
reg   [BLOCK_WIDTH-1:0]    loc_data_to_compare;   // data steam + mask
integer                    ii,ii_end,ii_start;  

// make this the width of the maximum count so that wrap around works
// i.e. if current_alignment=16'h8000, then the next start should equal 16'h0002;
//      if current_alignment=16'h4000, then the next start should equal 16'h0001;
reg   [BA_WIDTH-1:0]  valid;
begin 
  match_block = 0;
  ii_start = current_alignment_int;
  ii_end   = (search_for_eieos || !block_aligned ) ? current_alignment_int + 8 : current_alignment_int;
  valid    = {BA_WIDTH{1'b1}}; 
  
 //  if ($time() > 36740ns && $time() < 36750ns)
//   begin
//    $display ("time:  , ii_start = %0t, %0h", $time() ,ii_start);
//    
//   end
  
  for (ii=ii_start;ii<=ii_end;ii=ii+1) begin
    loc_data_to_compare = (data_to_compare >> ii) & bit_mask;
    match_block[ii] =  (loc_data_to_compare == block_to_match) && valid[ii];
    if (match_block[ii])
      break;
  end
end
endfunction

// ==============================================================================
// Decode the alignment
// ==============================================================================
function [9:0] shifter;
input [127:0] current_block_alignment_int;
begin

// decode the block_alignment nr of bits to shift
case (current_block_alignment_int)
    128'h0000_0000_0000_0000_0000_0000_0000_0001:    shifter =  0;
    128'h0000_0000_0000_0000_0000_0000_0000_0002:    shifter =  1;
    128'h0000_0000_0000_0000_0000_0000_0000_0004:    shifter =  2;
    128'h0000_0000_0000_0000_0000_0000_0000_0008:    shifter =  3;
    128'h0000_0000_0000_0000_0000_0000_0000_0010:    shifter =  4;
    128'h0000_0000_0000_0000_0000_0000_0000_0020:    shifter =  5;
    128'h0000_0000_0000_0000_0000_0000_0000_0040:    shifter =  6;
    128'h0000_0000_0000_0000_0000_0000_0000_0080:    shifter =  7;
    128'h0000_0000_0000_0000_0000_0000_0000_0100:    shifter =  8;
    128'h0000_0000_0000_0000_0000_0000_0000_0200:    shifter =  9;
    128'h0000_0000_0000_0000_0000_0000_0000_0400:    shifter = 10;
    128'h0000_0000_0000_0000_0000_0000_0000_0800:    shifter = 11;
    128'h0000_0000_0000_0000_0000_0000_0000_1000:    shifter = 12;
    128'h0000_0000_0000_0000_0000_0000_0000_2000:    shifter = 13;
    128'h0000_0000_0000_0000_0000_0000_0000_4000:    shifter = 14;
    128'h0000_0000_0000_0000_0000_0000_0000_8000:    shifter = 15;
    128'h0000_0000_0000_0000_0000_0000_0001_0000:    shifter = 16;
    128'h0000_0000_0000_0000_0000_0000_0002_0000:    shifter = 17;
    128'h0000_0000_0000_0000_0000_0000_0004_0000:    shifter = 18;
    128'h0000_0000_0000_0000_0000_0000_0008_0000:    shifter = 19;
    128'h0000_0000_0000_0000_0000_0000_0010_0000:    shifter = 20;
    128'h0000_0000_0000_0000_0000_0000_0020_0000:    shifter = 21;
    128'h0000_0000_0000_0000_0000_0000_0040_0000:    shifter = 22;
    128'h0000_0000_0000_0000_0000_0000_0080_0000:    shifter = 23;
    128'h0000_0000_0000_0000_0000_0000_0100_0000:    shifter = 24;
    128'h0000_0000_0000_0000_0000_0000_0200_0000:    shifter = 25;
    128'h0000_0000_0000_0000_0000_0000_0400_0000:    shifter = 26;
    128'h0000_0000_0000_0000_0000_0000_0800_0000:    shifter = 27;
    128'h0000_0000_0000_0000_0000_0000_1000_0000:    shifter = 28;
    128'h0000_0000_0000_0000_0000_0000_2000_0000:    shifter = 29;
    128'h0000_0000_0000_0000_0000_0000_4000_0000:    shifter = 30;
    128'h0000_0000_0000_0000_0000_0000_8000_0000:    shifter = 31;
    128'h0000_0000_0000_0000_0000_0001_0000_0000:    shifter = 32+ 0;
    128'h0000_0000_0000_0000_0000_0002_0000_0000:    shifter = 32+ 1;
    128'h0000_0000_0000_0000_0000_0004_0000_0000:    shifter = 32+ 2;
    128'h0000_0000_0000_0000_0000_0008_0000_0000:    shifter = 32+ 3;
    128'h0000_0000_0000_0000_0000_0010_0000_0000:    shifter = 32+ 4;
    128'h0000_0000_0000_0000_0000_0020_0000_0000:    shifter = 32+ 5;
    128'h0000_0000_0000_0000_0000_0040_0000_0000:    shifter = 32+ 6;
    128'h0000_0000_0000_0000_0000_0080_0000_0000:    shifter = 32+ 7;
    128'h0000_0000_0000_0000_0000_0100_0000_0000:    shifter = 32+ 8;
    128'h0000_0000_0000_0000_0000_0200_0000_0000:    shifter = 32+ 9;
    128'h0000_0000_0000_0000_0000_0400_0000_0000:    shifter = 32+10;
    128'h0000_0000_0000_0000_0000_0800_0000_0000:    shifter = 32+11;
    128'h0000_0000_0000_0000_0000_1000_0000_0000:    shifter = 32+12;
    128'h0000_0000_0000_0000_0000_2000_0000_0000:    shifter = 32+13;
    128'h0000_0000_0000_0000_0000_4000_0000_0000:    shifter = 32+14;
    128'h0000_0000_0000_0000_0000_8000_0000_0000:    shifter = 32+15;
    128'h0000_0000_0000_0000_0001_0000_0000_0000:    shifter = 32+16;
    128'h0000_0000_0000_0000_0002_0000_0000_0000:    shifter = 32+17;
    128'h0000_0000_0000_0000_0004_0000_0000_0000:    shifter = 32+18;
    128'h0000_0000_0000_0000_0008_0000_0000_0000:    shifter = 32+19;
    128'h0000_0000_0000_0000_0010_0000_0000_0000:    shifter = 32+20;
    128'h0000_0000_0000_0000_0020_0000_0000_0000:    shifter = 32+21;
    128'h0000_0000_0000_0000_0040_0000_0000_0000:    shifter = 32+22;
    128'h0000_0000_0000_0000_0080_0000_0000_0000:    shifter = 32+23;
    128'h0000_0000_0000_0000_0100_0000_0000_0000:    shifter = 32+24;
    128'h0000_0000_0000_0000_0200_0000_0000_0000:    shifter = 32+25;
    128'h0000_0000_0000_0000_0400_0000_0000_0000:    shifter = 32+26;
    128'h0000_0000_0000_0000_0800_0000_0000_0000:    shifter = 32+27;
    128'h0000_0000_0000_0000_1000_0000_0000_0000:    shifter = 32+28;
    128'h0000_0000_0000_0000_2000_0000_0000_0000:    shifter = 32+29;
    128'h0000_0000_0000_0000_4000_0000_0000_0000:    shifter = 32+30;
    128'h0000_0000_0000_0000_8000_0000_0000_0000:    shifter = 32+31;
    
    128'h0000_0000_0000_0001_0000_0000_0000_0000:    shifter =  64;
    128'h0000_0000_0000_0002_0000_0000_0000_0000:    shifter =  64+1;
    128'h0000_0000_0000_0004_0000_0000_0000_0000:    shifter =  64+2;
    128'h0000_0000_0000_0008_0000_0000_0000_0000:    shifter =  64+3;
    128'h0000_0000_0000_0010_0000_0000_0000_0000:    shifter =  64+4;
    128'h0000_0000_0000_0020_0000_0000_0000_0000:    shifter =  64+5;
    128'h0000_0000_0000_0040_0000_0000_0000_0000:    shifter =  64+6;
    128'h0000_0000_0000_0080_0000_0000_0000_0000:    shifter =  64+7;
    128'h0000_0000_0000_0100_0000_0000_0000_0000:    shifter =  64+8;
    128'h0000_0000_0000_0200_0000_0000_0000_0000:    shifter =  64+9;
    128'h0000_0000_0000_0400_0000_0000_0000_0000:    shifter = 64+10;
    128'h0000_0000_0000_0800_0000_0000_0000_0000:    shifter = 64+11;
    128'h0000_0000_0000_1000_0000_0000_0000_0000:    shifter = 64+12;
    128'h0000_0000_0000_2000_0000_0000_0000_0000:    shifter = 64+13;
    128'h0000_0000_0000_4000_0000_0000_0000_0000:    shifter = 64+14;
    128'h0000_0000_0000_8000_0000_0000_0000_0000:    shifter = 64+15;
    128'h0000_0000_0001_0000_0000_0000_0000_0000:    shifter = 64+16;
    128'h0000_0000_0002_0000_0000_0000_0000_0000:    shifter = 64+17;
    128'h0000_0000_0004_0000_0000_0000_0000_0000:    shifter = 64+18;
    128'h0000_0000_0008_0000_0000_0000_0000_0000:    shifter = 64+19;
    128'h0000_0000_0010_0000_0000_0000_0000_0000:    shifter = 64+20;
    128'h0000_0000_0020_0000_0000_0000_0000_0000:    shifter = 64+21;
    128'h0000_0000_0040_0000_0000_0000_0000_0000:    shifter = 64+22;
    128'h0000_0000_0080_0000_0000_0000_0000_0000:    shifter = 64+23;
    128'h0000_0000_0100_0000_0000_0000_0000_0000:    shifter = 64+24;
    128'h0000_0000_0200_0000_0000_0000_0000_0000:    shifter = 64+25;
    128'h0000_0000_0400_0000_0000_0000_0000_0000:    shifter = 64+26;
    128'h0000_0000_0800_0000_0000_0000_0000_0000:    shifter = 64+27;
    128'h0000_0000_1000_0000_0000_0000_0000_0000:    shifter = 64+28;
    128'h0000_0000_2000_0000_0000_0000_0000_0000:    shifter = 64+29;
    128'h0000_0000_4000_0000_0000_0000_0000_0000:    shifter = 64+30;
    128'h0000_0000_8000_0000_0000_0000_0000_0000:    shifter = 64+31;
    128'h0000_0001_0000_0000_0000_0000_0000_0000:    shifter = 64+32;
    128'h0000_0002_0000_0000_0000_0000_0000_0000:    shifter = 64+33;
    128'h0000_0004_0000_0000_0000_0000_0000_0000:    shifter = 64+34;
    128'h0000_0008_0000_0000_0000_0000_0000_0000:    shifter = 64+35;
    128'h0000_0010_0000_0000_0000_0000_0000_0000:    shifter = 64+36;
    128'h0000_0020_0000_0000_0000_0000_0000_0000:    shifter = 64+37;
    128'h0000_0040_0000_0000_0000_0000_0000_0000:    shifter = 64+38;
    128'h0000_0080_0000_0000_0000_0000_0000_0000:    shifter = 64+39;
    128'h0000_0100_0000_0000_0000_0000_0000_0000:    shifter = 64+40;
    128'h0000_0200_0000_0000_0000_0000_0000_0000:    shifter = 64+41;
    128'h0000_0400_0000_0000_0000_0000_0000_0000:    shifter = 64+42;
    128'h0000_0800_0000_0000_0000_0000_0000_0000:    shifter = 64+43;
    128'h0000_1000_0000_0000_0000_0000_0000_0000:    shifter = 64+44;
    128'h0000_2000_0000_0000_0000_0000_0000_0000:    shifter = 64+45;
    128'h0000_4000_0000_0000_0000_0000_0000_0000:    shifter = 64+46;
    128'h0000_8000_0000_0000_0000_0000_0000_0000:    shifter = 64+47;
    128'h0001_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+48;
    128'h0002_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+49;
    128'h0004_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+50;
    128'h0008_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+51;
    128'h0010_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+52;
    128'h0020_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+53;
    128'h0040_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+54;
    128'h0080_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+55;
    128'h0100_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+56;
    128'h0200_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+57;
    128'h0400_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+58;
    128'h0800_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+59;
    128'h1000_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+60;
    128'h2000_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+61;
    128'h4000_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+62;
    128'h8000_0000_0000_0000_0000_0000_0000_0000:    shifter = 64+63;    
    default:                    shifter = 0;
endcase
end
endfunction

endmodule

