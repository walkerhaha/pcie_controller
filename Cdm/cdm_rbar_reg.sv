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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rbar_reg.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Resizable BAR extended capability registers.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_rbar_reg (
                   // Inputs
                   core_clk,
                   sticky_rst_n,
                   non_sticky_rst_n,
                   lbc_cdm_data,
                   lbc_cdm_dbi,
                   lbc_cdm_dbi2,
                   write_pulse,
                   rbar_reg_id,
                   cx_dbi_ro_wr_en,
                   // Outputs
                   rbar_reg_data,
                   rbar_bar_resizable,
                   rbar_bar0_mask,
                   rbar_bar1_mask,
                   rbar_bar2_mask,
                   rbar_bar3_mask,
                   rbar_bar4_mask,
                   rbar_bar5_mask,
                   rbar_ctrl_update,
                   cfg_rbar_size
                  );

// *****************************************************************************
// Declare parameters
// *****************************************************************************
   parameter INST          = 0;                    // The uniquifying parameter for each block instance.
   parameter FUNC_NUM      = 0;                    // Physical Function Number
   parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
   parameter VF_BAR        = 0;                    // Determines if module is a PF or VF resizable BAR - defaults to PF

   // Maximum number of resizable BARs
   localparam MAX_NUM_RBARS = 6;
   // Min RBAR resource
   localparam RBAR_RESOURCE_1MB = 64'hFFFFFFFFFFF00000;
   // Number of resizable BARs
   localparam NUM_RBARS = (VF_BAR>0)? `CX_NUM_VF_RBARS: `CX_NUM_RBARS;
   //localparam NUM_RBARS = `CX_NUM_RBARS;

//   // RBAR vector
   localparam BAR_EQ_RBAR_VEC = (VF_BAR>0)? 
                                {`VF_BAR5_RESIZABLE,
                                 `VF_BAR4_RESIZABLE,
                                 `VF_BAR3_RESIZABLE,
                                 `VF_BAR2_RESIZABLE,
                                 `VF_BAR1_RESIZABLE,
                                 `VF_BAR0_RESIZABLE
                                } :  
                                {`CX_BAR5_RESIZABLE,
                                 `CX_BAR4_RESIZABLE,
                                 `CX_BAR3_RESIZABLE,
                                 `CX_BAR2_RESIZABLE,
                                 `CX_BAR1_RESIZABLE,
                                 `CX_BAR0_RESIZABLE
                                };

//   localparam BAR_EQ_RBAR_VEC = {`CX_BAR5_RESIZABLE,
//                                 `CX_BAR4_RESIZABLE,
//                                 `CX_BAR3_RESIZABLE,
//                                 `CX_BAR2_RESIZABLE,
//                                 `CX_BAR1_RESIZABLE,
//                                 `CX_BAR0_RESIZABLE
//                                };


//    // RBAR supported sizes
    localparam BAR0_RESOURCE_AVAIL = (VF_BAR>0)? `VF_BAR0_RESOURCE_AVAIL: `CX_BAR0_RESOURCE_AVAIL;
    localparam BAR1_RESOURCE_AVAIL = (VF_BAR>0)? `VF_BAR1_RESOURCE_AVAIL: `CX_BAR1_RESOURCE_AVAIL;
    localparam BAR2_RESOURCE_AVAIL = (VF_BAR>0)? `VF_BAR2_RESOURCE_AVAIL: `CX_BAR2_RESOURCE_AVAIL;
    localparam BAR3_RESOURCE_AVAIL = (VF_BAR>0)? `VF_BAR3_RESOURCE_AVAIL: `CX_BAR3_RESOURCE_AVAIL;
    localparam BAR4_RESOURCE_AVAIL = (VF_BAR>0)? `VF_BAR4_RESOURCE_AVAIL: `CX_BAR4_RESOURCE_AVAIL;
    localparam BAR5_RESOURCE_AVAIL = (VF_BAR>0)? `VF_BAR5_RESOURCE_AVAIL: `CX_BAR5_RESOURCE_AVAIL;

   // RBAR supported sizes
//   localparam BAR0_RESOURCE_AVAIL = `CX_BAR0_RESOURCE_AVAIL;
//   localparam BAR1_RESOURCE_AVAIL = `CX_BAR1_RESOURCE_AVAIL;
//   localparam BAR2_RESOURCE_AVAIL = `CX_BAR2_RESOURCE_AVAIL;
//   localparam BAR3_RESOURCE_AVAIL = `CX_BAR3_RESOURCE_AVAIL;
//   localparam BAR4_RESOURCE_AVAIL = `CX_BAR4_RESOURCE_AVAIL;
//   localparam BAR5_RESOURCE_AVAIL = `CX_BAR5_RESOURCE_AVAIL;

// *****************************************************************************
// Declare inputs
// *****************************************************************************
   input                          core_clk;     // Core clock
   input                          sticky_rst_n; // Top level sticky reset
   input                          non_sticky_rst_n; // Top level non-sticky reset
   input [31:0]                   lbc_cdm_data; // Data for write
   input                          lbc_cdm_dbi;  // DBI(cs)
   input                          lbc_cdm_dbi2; // DBI(cs2)
   input [3:0]                    write_pulse;  // LBC write pulse
   input [(NUM_RBARS*2):0]        rbar_reg_id;  // LBC reg ID
   input                          cx_dbi_ro_wr_en;

// *****************************************************************************
// Declare outputs
// *****************************************************************************
   output [31:0]                  rbar_reg_data;      // RBAR register read data bus
   output [5:0]                   rbar_bar_resizable; // BAR resizable indication
   output [63:0]                  rbar_bar0_mask;     // BAR0 mask value
   output [31:0]                  rbar_bar1_mask;     // BAR1 mask value
   output [63:0]                  rbar_bar2_mask;     // BAR2 mask value
   output [31:0]                  rbar_bar3_mask;     // BAR3 mask value
   output [63:0]                  rbar_bar4_mask;     // BAR4 mask value
   output [31:0]                  rbar_bar5_mask;     // BAR5 mask value
   output                         rbar_ctrl_update;   // indicates that RBAR control register has been updated
   output [(MAX_NUM_RBARS*6)-1:0] cfg_rbar_size;      // wire the BAR size fields to top level

// *****************************************************************************
// Declare wires/regs
// *****************************************************************************
   reg  [31:0]                  rbar_reg_data;
   wire [5:0]                   rbar_bar_resizable;
   reg  [63:0]                  rbar_bar0_mask; 
   reg  [31:0]                  rbar_bar1_mask; 
   reg  [63:0]                  rbar_bar2_mask; 
   reg  [31:0]                  rbar_bar3_mask; 
   reg  [63:0]                  rbar_bar4_mask; 
   reg  [31:0]                  rbar_bar5_mask; 
   reg                          rbar_ctrl_update;
   reg  [(MAX_NUM_RBARS*6)-1:0] cfg_rbar_size;
// *****************************************************************************
// Internal design
// *****************************************************************************
   // Detect resizable BAR's
   assign rbar_bar_resizable = BAR_EQ_RBAR_VEC; 
 
// ----------------------------------------------------------------------------
// Generate power on reset initialisation pulse
// ----------------------------------------------------------------------------
   reg  reset_r;
   reg  reset_rr;
   wire por_init_pulse;

   always @(posedge core_clk or negedge sticky_rst_n) begin : proc_seq_reset_pulse
      if (!sticky_rst_n) begin
        reset_r  <= # TP 1'b0;
        reset_rr <= # TP 1'b0;
      end else begin
        reset_r  <= # TP 1'b1;
        reset_rr <= # TP reset_r;
      end
   end

   reg  non_sticky_reset_r;
   reg  non_sticky_reset_rr;
   wire non_sticky_por_init_pulse;

   always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_non_sticky_reset_pulse
      if (!non_sticky_rst_n) begin
        non_sticky_reset_r  <= # TP 1'b0;
        non_sticky_reset_rr <= # TP 1'b0;
      end else begin
        non_sticky_reset_r  <= # TP 1'b1;
        non_sticky_reset_rr <= # TP non_sticky_reset_r;
      end
   end
  // Initialise RBAR capability registers at power on reset only.
  // Registers not initialised by a link down, low power or functional level reset.
  assign por_init_pulse = reset_r & ~reset_rr;
  assign non_sticky_por_init_pulse = non_sticky_reset_r & ~non_sticky_reset_rr;

// -----------------------------------------------------------------------------
// Generate DBI write enable
// -----------------------------------------------------------------------------
   // Determines whether RO RBAR register bits are writable through the DBI.
   wire cx_dbi_ro_wr_en;
   wire dbi_ro_wr_en = (lbc_cdm_dbi & cx_dbi_ro_wr_en);

// -----------------------------------------------------------------------------
// RBAR Extended Capability Structure
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// RBAR Extended CAP Header
// rbar_reg_id       - 0
// PCIE Offset      - `RBAR_PTR
// Length           - 4 bytes
// Default value    -
// Byte fields      - cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0
// -----------------------------------------------------------------------------
   // Next capability offset, initialised by POR only, value retained at boot time
   // if modified via DBI.
   reg  [11:0] cfg_rbar_nxt_ptr_r; 
   reg  [15:0] cfg_rbar_id;
   reg  [3:0]  cfg_rbar_ver;



   always @(posedge core_clk or negedge sticky_rst_n) begin : proc_seq_rbar_nxt_ptr
      if (!sticky_rst_n) begin
        cfg_rbar_id[15:0]  <= #TP (VF_BAR>0)?`PCIE_VF_RBAR_ECAP_ID:`PCIE_RBAR_ECAP_ID;      // Capability ID
        cfg_rbar_ver[3:0]  <= #TP (VF_BAR>0)?`PCIE_VF_RBAR_ECAP_VER:`PCIE_RBAR_ECAP_VER;     // Capability version
        cfg_rbar_nxt_ptr_r <= #TP (VF_BAR>0)? `VF_RBAR_NEXT_PTR : `RBAR_NEXT_PTR;
      end else begin
        // Read-Only register, but writable through DBI
        cfg_rbar_id[7:0]         <= #TP (rbar_reg_id[0] & write_pulse[0] & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_rbar_id[7:0];
        cfg_rbar_id[15:8]        <= #TP (rbar_reg_id[0] & write_pulse[1] & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_rbar_id[15:8];
        cfg_rbar_ver[3:0]        <= #TP (rbar_reg_id[0] & write_pulse[2] & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_rbar_ver[3:0];
        cfg_rbar_nxt_ptr_r[3:0]  <= #TP (dbi_ro_wr_en & write_pulse[2] & rbar_reg_id[0]) ? lbc_cdm_data[23:20] 
                                      : cfg_rbar_nxt_ptr_r[3:0];    
        cfg_rbar_nxt_ptr_r[11:4] <= #TP (dbi_ro_wr_en & write_pulse[3] & rbar_reg_id[0]) ? lbc_cdm_data[31:24] 
                                      : cfg_rbar_nxt_ptr_r[11:4];
      end
   end

   wire [7:0] cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0; // Byte fields
   assign {cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0} = {cfg_rbar_nxt_ptr_r,cfg_rbar_ver,cfg_rbar_id};


// Detect write to BAR size field
reg [(NUM_RBARS):1] cfg_bar_size_wr_det;

// -----------------------------------------------------------------------------
// RBAR CAP
// rbar_reg_id - 1 + (n*2) 
// PCIE Offset - `RBAR_PTR + (n*8) +04h
// n=0 to 5 depending on the number of resizable BARs
// -----------------------------------------------------------------------------
// RBAR Control
// rbar_reg_id - 2 + (n*2)
// PCIE Offset - `RBAR_PTR + (n*8)+ 08h
// n=0 to 5 depending on the number of resizable BARs
// -----------------------------------------------------------------------------
   generate
     if (NUM_RBARS > 0) begin : gen_rbar_cap // Be nice to Linting tools

       // Define RBAR vector, 1=BAR is resizable
       wire [6:1] bar_eq_rbar_vec = BAR_EQ_RBAR_VEC;
       // Define RBAR resources
       reg [47:0] bar_cap_resrc_default_val [MAX_NUM_RBARS:1];
       // Define RBAR extended capability structure
       reg [31:0] rbar_cap_ary_nxt [(NUM_RBARS*2):1];
       // Detect write to RBAR capabilty resource register
       reg [(NUM_RBARS):1] dbi_rbar_cap_resource_wr_det;
       // Record write_pulse value for capability
       reg [(NUM_RBARS):1][3:0] dbi_rbar_cap_resource_wr_det_wp;
       // Detect write to RBAR control resource register
       reg [(NUM_RBARS):1] dbi_rbar_ctrl_resource_wr_det; 
       // Record write_pulse value for control
       reg [(NUM_RBARS):1][3:0] dbi_rbar_ctrl_resource_wr_det_wp; 
       // Build RBAR capability array
       always @(*) begin : proc_comb_rbar_cap_ary
         integer i, j, k;

         // Build RBAR capabilty resource array
         bar_cap_resrc_default_val[1] = BAR0_RESOURCE_AVAIL; 
         bar_cap_resrc_default_val[2] = BAR1_RESOURCE_AVAIL; 
         bar_cap_resrc_default_val[3] = BAR2_RESOURCE_AVAIL; 
         bar_cap_resrc_default_val[4] = BAR3_RESOURCE_AVAIL; 
         bar_cap_resrc_default_val[5] = BAR4_RESOURCE_AVAIL; 
         bar_cap_resrc_default_val[6] = BAR5_RESOURCE_AVAIL; 

         // Initialise 
         for (j=1; j<=(NUM_RBARS*2); j=j+1) begin
            rbar_cap_ary_nxt[j] = 0;
         end
         cfg_bar_size_wr_det = 0;
         dbi_rbar_cap_resource_wr_det = 0;
         dbi_rbar_cap_resource_wr_det_wp = 4'h0;
         dbi_rbar_ctrl_resource_wr_det = 0;
         dbi_rbar_ctrl_resource_wr_det_wp = 4'h0;
         i = 1;
         k = 1;

// LMD: rbar_cap_ary_nxt index out of bound
// LJ: index i is incremented only if bar_eq_rbar_vec[j] (static) is set. So can never exceed rbar_cap_ary_nxt array size
// leda E268 off
         // Configure RBAR capability, BAR index i
         for (j=1; j<=(MAX_NUM_RBARS); j=j+1) begin
            // Search for resizable BAR
            if (bar_eq_rbar_vec[j]) begin
              // RBAR Capability (supported sizes)
              // RO to configuration software, RW via DBI(cs).
              // DBI write enables device software to modify resources advertised at boot time.
              // dbi_ro_wr_en = (lbc_cdm_dbi & cx_dbi_ro_wr_en)
              if (dbi_ro_wr_en &&  rbar_reg_id[i]) begin
                if (write_pulse[0]) begin
                  rbar_cap_ary_nxt[i][7:4] = lbc_cdm_data[7:4];
                end
                if (write_pulse[1]) begin
                   rbar_cap_ary_nxt[i][15:8] = lbc_cdm_data[15:8];
                end
                if (write_pulse[2]) begin
                  rbar_cap_ary_nxt[i][23:16] = lbc_cdm_data[23:16];
                end
                if (write_pulse[3]) begin
                  rbar_cap_ary_nxt[i][31:24] = lbc_cdm_data[31:24];
                end                
                dbi_rbar_cap_resource_wr_det[k] = |write_pulse; // Detect write to RBAR cap resources
                dbi_rbar_cap_resource_wr_det_wp[k] = write_pulse; // Record write_pulse value
              end else begin
                rbar_cap_ary_nxt[i][31:4] = bar_cap_resrc_default_val[j][31:4];  // POR init value
              end
              // RBAR Control register - bits 16 to 31 (supported sizes)
              // RO to configuration software, RW via DBI(cs) when cx_dbi_ro_wr_en is set.
              // DBI write enables device software to modify resources advertised at boot time.
              //  dbi_ro_wr_en = (lbc_cdm_dbi & cx_dbi_ro_wr_en)
              if (dbi_ro_wr_en && rbar_reg_id[i+1]) begin
                if (write_pulse[2]) begin
                  rbar_cap_ary_nxt[i+1][23:16] = lbc_cdm_data[23:16];
                end
                if (write_pulse[3]) begin
                  rbar_cap_ary_nxt[i+1][31:24] = lbc_cdm_data[31:24];
                end
                dbi_rbar_ctrl_resource_wr_det[k] = |write_pulse[3:2]; // Detect write to RBAR cap resources only if bits 16-31 are written
                dbi_rbar_ctrl_resource_wr_det_wp[k] = write_pulse;               
              end else begin
                rbar_cap_ary_nxt[i+1][31:16] = bar_cap_resrc_default_val[j][47:32]; // POR init value
              end

              // BAR Index, RO to configuration software.
              rbar_cap_ary_nxt[i+1][2:0] = (j-1); 
              // Number of resizable BARs, RO to configuration software.
              rbar_cap_ary_nxt[i+1][7:5] = NUM_RBARS;
              // BAR Size, RW to configuration software and to DBI(cs).
              if (write_pulse[1] && rbar_reg_id[i+1] && !lbc_cdm_dbi2) begin
                cfg_bar_size_wr_det[k] = 1'b1; // Detect write to BAR Size
                rbar_cap_ary_nxt[i+1][13:8] = lbc_cdm_data[13:8];
              end
              // Point to next pair of resizable BAR capability registers
              i = i + 2;
              k = k + 1;
            end
         end
       end
// leda E268 on

       // Build BAR Index and Number of RBARs RO register fields
       reg [2:0] bar_index_ary [(NUM_RBARS):1];
       reg [2:0] num_rbars [(NUM_RBARS):1];

       always @(*) begin : proc_comb_rbar_regs
         integer i;

         // Initialise
         for (i=1; i<=(NUM_RBARS); i=i+1) begin
            bar_index_ary[i] = 0;
            num_rbars[i] = 0;
         end

         for (i=1; i<=(NUM_RBARS); i=i+1) begin
            // RBAR[i] index
            bar_index_ary[i] = rbar_cap_ary_nxt[(i*2)][2:0];
            // Number of RBARs
            if (i==1) begin // Only valid for first BAR control register
              num_rbars[i] = rbar_cap_ary_nxt[(i*2)][7:5];
            end
         end
       end

       // Build BAR resource register field, 
       // Reset by POR only. If function level or link down reset fires
       // then BAR resource configuration maintained if modified via DBI.
       reg [43:0] rbar_cap_resource_ary_r [(NUM_RBARS):1];

       always @(posedge core_clk or negedge sticky_rst_n) begin : proc_seq_rbar_regs
         integer i;

         if (!sticky_rst_n) begin 
           for (i=1; i<=(NUM_RBARS); i=i+1) begin
              rbar_cap_resource_ary_r[i] <= #TP 0;
           end
         end else begin
           for (i=1; i<=(NUM_RBARS); i=i+1) begin
              if (por_init_pulse || dbi_rbar_cap_resource_wr_det[i] || dbi_rbar_ctrl_resource_wr_det[i]) begin
                // RBAR[i] size supported, 1MB to 512MB
                if (dbi_rbar_cap_resource_wr_det[i]) begin                                         // only update bits from capability register
                  rbar_cap_resource_ary_r[i][0 +:4] <= #TP dbi_rbar_cap_resource_wr_det_wp[i][0] ? rbar_cap_ary_nxt[(i*2)-1][7:4] : rbar_cap_resource_ary_r[i][0 +:4];
                  rbar_cap_resource_ary_r[i][4 +:8] <= #TP dbi_rbar_cap_resource_wr_det_wp[i][1] ? rbar_cap_ary_nxt[(i*2)-1][15:8] : rbar_cap_resource_ary_r[i][4 +:8];

                  rbar_cap_resource_ary_r[i][12 +:8] <= #TP dbi_rbar_cap_resource_wr_det_wp[i][2] ? rbar_cap_ary_nxt[(i*2)-1][23:16] : rbar_cap_resource_ary_r[i][12 +:8];

                  rbar_cap_resource_ary_r[i][20 +:8] <= #TP dbi_rbar_cap_resource_wr_det_wp[i][3] ? rbar_cap_ary_nxt[(i*2)-1][31:24] : rbar_cap_resource_ary_r[i][20 +:8];

                end else if (dbi_rbar_ctrl_resource_wr_det[i]) begin                                 // only  update bits from control register
                  rbar_cap_resource_ary_r[i][28 +:8] <= #TP dbi_rbar_ctrl_resource_wr_det_wp[i][2] ? rbar_cap_ary_nxt[(i*2)][23:16] : rbar_cap_resource_ary_r[i][28 +:8];
                  rbar_cap_resource_ary_r[i][36 +:8] <= #TP dbi_rbar_ctrl_resource_wr_det_wp[i][3] ? rbar_cap_ary_nxt[(i*2)][31:24] : rbar_cap_resource_ary_r[i][36 +:8];
                end else
                  rbar_cap_resource_ary_r[i] <= #TP {rbar_cap_ary_nxt[i*2][31:16], rbar_cap_ary_nxt[(i*2)-1][31:4]};
             end
           end
         end
       end

       // Calculate default bar size value when resource capabilty updated via DBI
       reg [5:0] bar_size_eq_max_resrc_val [(NUM_RBARS):1];

       always @(*) begin : proc_comb_bar_size_eq_max_resrc_val
         integer i;
         // Initialise
         for (i=1; i<=(NUM_RBARS); i=i+1) begin
            bar_size_eq_max_resrc_val[i] = 0;
         end
         // Determine the default bar size value (max resource capability) 
         for (i=1; i<=(NUM_RBARS); i=i+1) begin
            if (non_sticky_por_init_pulse || dbi_rbar_cap_resource_wr_det[i] || dbi_rbar_ctrl_resource_wr_det[i]) begin
              if (dbi_rbar_cap_resource_wr_det[i])                                           // only update bits from capability register
                bar_size_eq_max_resrc_val[i] = first_bit_eq2one_pos({rbar_cap_resource_ary_r[i][28+:16], rbar_cap_ary_nxt[(i*2)-1][31:4]});
              else if (dbi_rbar_ctrl_resource_wr_det[i])                                     // only  update bits from control register
                bar_size_eq_max_resrc_val[i] = first_bit_eq2one_pos({rbar_cap_ary_nxt[i*2][31:16], rbar_cap_resource_ary_r[i][0 +:28]});
              else
                bar_size_eq_max_resrc_val[i] = first_bit_eq2one_pos({rbar_cap_ary_nxt[i*2][31:16], rbar_cap_ary_nxt[(i*2)-1][31:4]});
            end
         end
       end

       // Build BAR size register field, RW via DBI(cs), indirectly updated if resource
       // capability modified by software prior to device discovery. 
       // Reset by power on reset only. If function level or link down reset fires
       // then BAR size configuration maintained.
       // Note: if the BAR is disabled in the u_cdm_cfg block then RBAR size is
       // "don't care, mechanism to disable resizable BARs not specified on base
       // spec 3.0.
       reg [5:0]  bar_size_ary_r [(NUM_RBARS):1];

       always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_bar_size
         integer i;

         if (!non_sticky_rst_n) begin 
           for (i=1; i<=(NUM_RBARS); i=i+1) begin
              bar_size_ary_r[i] <= #TP 0;
           end
         end else begin
           for (i=1; i<=(NUM_RBARS); i=i+1) begin
              // RBAR[i] size indirectly updated if device software re-programs 
              // the max resizable resource.
              // if resouce sizes are written in RBAR control they will only update BAR size
              // if the BAR size field is not written in the same access, otherwise the direct write to the field will prevail
              if (non_sticky_por_init_pulse || dbi_rbar_cap_resource_wr_det[i] || (dbi_rbar_ctrl_resource_wr_det[i] && (!cfg_bar_size_wr_det[i]))) begin
                bar_size_ary_r[i] <= #TP bar_size_eq_max_resrc_val[i];
              end else if (cfg_bar_size_wr_det[i]) begin
                // RBAR[i] size updated by configuration software
                bar_size_ary_r[i] <= #TP rbar_cap_ary_nxt[(i*2)][13:8];
              end
           end
         end
       end


       // wire the BAR size fields to top level
       always @ (*)
       begin: proc_cfg_rbar_size
         integer m;
           for (m=0; m<MAX_NUM_RBARS; m=m+1)
           begin
             if (m < NUM_RBARS)
               cfg_rbar_size[6*m +: 6] = bar_size_ary_r[m+1];
             else
               cfg_rbar_size[6*m +: 6] = 6'd0;
           end
       end

       // -----------------------------------------------------------------------
       // Convert RBAR size to BAR mask value
       // -----------------------------------------------------------------------
       reg [63:0] bar_resource_1mb;
       reg [63:0] bar_mask_ary [(NUM_RBARS):1];

       // Calculate BAR mask
       always @(*) begin : proc_comb_bar_mask_ary
         integer i;

         bar_resource_1mb = RBAR_RESOURCE_1MB;

         for (i=1; i<=(NUM_RBARS); i=i+1) begin
            // Initialise
            bar_mask_ary[i] = 0;
            // Calculate BAR index mask value
            bar_mask_ary[i] = ~(bar_resource_1mb << bar_size_ary_r[i]);
         end
       end

       // Map BAR[n] mask to indexed RBAR mask, where n=0 to 5.
       // Note: the BAR mask is deemed don't care when the BAR is disabled
       // in the u_cdm_cfg block. 
       always @(*) begin : proc_comb_rbar_bar_mask
         integer i;
         rbar_bar0_mask = 0;
         rbar_bar1_mask = 0;
         rbar_bar2_mask = 0;
         rbar_bar3_mask = 0;
         rbar_bar4_mask = 0;
         rbar_bar5_mask = 0;

         for (i=1; i<=(NUM_RBARS); i=i+1) begin
            case (bar_index_ary[i])
              0: begin
                rbar_bar0_mask = bar_mask_ary[i];
              end
              1: begin
                rbar_bar1_mask = bar_mask_ary[i][31:0];
              end
              2: begin
                rbar_bar2_mask = bar_mask_ary[i];
              end
              3: begin
                rbar_bar3_mask = bar_mask_ary[i][31:0];
              end
              4: begin
                rbar_bar4_mask = bar_mask_ary[i];
              end
              5: begin
                rbar_bar5_mask = bar_mask_ary[i][31:0];
              end
              default : begin
                 rbar_bar0_mask = 0; 
                 rbar_bar1_mask = 0; 
                 rbar_bar2_mask = 0; 
                 rbar_bar3_mask = 0; 
                 rbar_bar4_mask = 0; 
                 rbar_bar5_mask = 0; 
              end
            endcase
         end
       end
            
       // -----------------------------------------------------------------------
       // Read mux
       // -----------------------------------------------------------------------
       always @(*) begin : proc_comb_rbar_reg_read_mux
         reg rd_rbar_cap_eq_true;
         reg rd_rbar_ctrl_eq_true;
         integer i, j, k;
         // Initialise 
         rbar_reg_data = `PCIE_UNUSED_RESPONSE;
         rd_rbar_cap_eq_true = 0;
         rd_rbar_ctrl_eq_true = 0;
         j = 0;
         k = 1;

         if (rbar_reg_id[0]) begin
           rbar_reg_data = {cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0};
         end else begin
           // RBAR capability
           for (i=1; i<=(NUM_RBARS*2); i=i+2) begin
              if (rbar_reg_id[i] && !rd_rbar_cap_eq_true) begin 
                rbar_reg_data = {rbar_cap_resource_ary_r[(i-j)][27:0], 4'b0}; 
                rd_rbar_cap_eq_true = 1'b1;
              end
              j = j + 1;
           end
           // RBAR control
           for (i=2; i<=(NUM_RBARS*2); i=i+2) begin
              if (rbar_reg_id[i] && !rd_rbar_ctrl_eq_true) begin
                rbar_reg_data = {rbar_cap_resource_ary_r[(i-k)][43:28] , 2'd0, bar_size_ary_r[(i-k)], num_rbars[(i-k)], 2'b0, bar_index_ary[(i-k)]};
                rd_rbar_ctrl_eq_true = 1'b1;
              end
              k = k + 1;
           end
         end
       end

     end // gen_rbar_cap 
   endgenerate

  always @(posedge core_clk or negedge sticky_rst_n) 
  begin : rbar_ctrl_update_PROC
    if (!sticky_rst_n)
      rbar_ctrl_update <= #TP 1'b0;
    else 
      rbar_ctrl_update <= #TP |cfg_bar_size_wr_det;
  end

// -----------------------------------------------------------------------
// Functions
// -----------------------------------------------------------------------
  // Returns the position of first one in the bit vector, searching from MSB to LSB 
  function automatic [5:0] first_bit_eq2one_pos;

    input [43:0] vec;
    reg first_bit_eq2one;
    reg [5:0] first_bit_eq2one_pos_i;
    integer j;

    begin
     // Initialise 
     first_bit_eq2one = 1'b0;
     first_bit_eq2one_pos_i = 6'b0;

     for (j=43; j>0; j=j-1) begin
        if (vec[j]==1'b1 && first_bit_eq2one==1'b0) begin
          first_bit_eq2one = 1'b1;
          first_bit_eq2one_pos_i = j;
        end
     end

     first_bit_eq2one_pos = first_bit_eq2one_pos_i;

    end
  endfunction

endmodule
