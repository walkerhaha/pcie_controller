// reuse-pragma process_ifdef standard

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

//
// Filename    : DWC_pcie_gphy_bcm44.v
// Revision    : $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_bcm44.v#7 $
// Author      : Rick Kelly         Jul. 19, 1999
// Description : DWC_pcie_gphy_bcm44.v Verilog module for DWC_pcie_gphy
//
// DesignWare IP ID: ebb0fa29
//
////////////////////////////////////////////////////////////////////////////////



  module DWC_pcie_gphy_bcm44 (
        clk,
        rst_n,
        init_rd_n,
	init_rd_val,
	k_char,
	data_in,

	rd,
`ifndef DWC_BCM44_NO_EN
	data_out,
        enable
`else
	data_out
`endif

	);


    parameter BYTES = 2;

    parameter K28_5_ONLY = 0;	// special character control mode

`ifndef DWC_BCM44_NO_EN
`ifndef DWC_BCM44_USE_EN
    parameter EN_MODE = 0;      // enable mode
`endif
`endif

    parameter INIT_MODE = 0;    // initial RD mode


input  			clk;		// clock input
input  			rst_n;		// active low reset
input                   init_rd_n;      // active low running disp. force control
input                   init_rd_val;    // running disp. value to force
input  [BYTES-1:0]      k_char;         // special character control bus (1 bit per byte)
input  [BYTES*8-1:0]    data_in;        // data to encode (8 bits per byte)

output                  rd;             // current running dispalrity
output [BYTES*10-1:0]   data_out;       // encoded data (10 bits per byte)

`ifndef DWC_BCM44_NO_EN
input			enable;		// register enable
`endif


reg			nxt_rd_enc;
wire 			new_rd;
reg    [BYTES*10-1:0]	enc_data;

reg    [BYTES*10-1:0]	data_out_int;
reg                     rd_int;


wire [BYTES-1:0] k_char_masked;

wire rd_effective;





generate
  if (INIT_MODE == 0) begin :	GEN_im_eq_0
    assign rd_effective = rd_int;
    assign new_rd = (init_rd_n == 1'b0)? init_rd_val : nxt_rd_enc;
  end else begin :		GEN_im_eq_1
    assign rd_effective = (init_rd_n == 1'b0)? init_rd_val : rd_int;
    assign new_rd = nxt_rd_enc;
  end
endgenerate

generate
  if (K28_5_ONLY == 1) begin : GEN_k28p5_only
    assign k_char_masked = {BYTES{1'b0}};
  end else begin : GEN_all_k_chars
    assign k_char_masked = k_char;
  end
endgenerate

// spyglass disable_block W415a
// SMD: Signal may be multiply assigned (beside initialization) in the same scope
// SJ: The design checked and verified that not any one of a single bit of the bus is assigned more than once beside initialization or the multiple assignments are intentional.
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.

generate
  if (K28_5_ONLY == 1) begin :  GEN_k28p5only_eq_1
    always @ * begin : encode_PROC
	integer byte_id, inbyte_base, in_k_base, outbyte_base;
	reg [BYTES-1:0] pt_0, pt_1, pt_2, pt_3, pt_4, pt_5, pt_6, pt_7, pt_8, pt_9;
	reg [BYTES-1:0] pt_10, pt_11, pt_12, pt_13, pt_14, pt_15, pt_16, pt_17, pt_18, pt_19;
	reg [BYTES-1:0] pt_20, pt_21, pt_22, pt_23, pt_24, pt_25, pt_26, pt_27, pt_28, pt_29;
	reg [BYTES-1:0] pt_30, pt_31, pt_32, pt_33, pt_34, pt_35, pt_36, pt_37, pt_38, pt_39;
	reg [BYTES-1:0] pt_40, pt_41, pt_42;
	reg [BYTES-1:0] unbal4, unbal6, rdvalbal4, encrd;
	reg [BYTES-1:0] a, b, c, d, e, f, g, h, i, j;
	reg [BYTES-1:0] unbal4_int, unbal6_int, rdvalbal4_int, encrd_int;
	reg [BYTES-1:0] a_int, b_int, c_int, d_int, e_int, f_int, g_int, h_int, i_int, j_int;
        reg [BYTES-1:0] rd_b, invrt4, invrt6;
        reg [BYTES : 0] rd_a;

        
        rd_a[0] = rd_effective;
        for (byte_id=0 ; byte_id < BYTES ; byte_id=byte_id+1) begin

            in_k_base = BYTES-byte_id-1;
            inbyte_base = 8 * (BYTES-byte_id-1);
	    outbyte_base = 10 * (BYTES-byte_id-1);

	    pt_0[byte_id] = ~k_char_masked[in_k_base] & (~rd_a[byte_id]) &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+1]) &
			    (~data_in[inbyte_base+0]);
	    pt_1[byte_id] = ~k_char_masked[in_k_base] & (~rd_a[byte_id]) &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & data_in[inbyte_base+1] &
			    (~data_in[inbyte_base+0]);
	    pt_2[byte_id] = ~k_char_masked[in_k_base] & rd_a[byte_id] &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    (~data_in[inbyte_base+4]) & data_in[inbyte_base+3] &
			    data_in[inbyte_base+2] & data_in[inbyte_base+1] &
			    (~data_in[inbyte_base+0]);
	    pt_3[byte_id] = ~k_char_masked[in_k_base] & (~rd_a[byte_id]) &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & (~data_in[inbyte_base+1]) &
			    data_in[inbyte_base+0];
	    pt_4[byte_id] = ~k_char_masked[in_k_base] & rd_a[byte_id] &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    (~data_in[inbyte_base+4]) & data_in[inbyte_base+3] &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+1]) &
			    data_in[inbyte_base+0];
	    pt_5[byte_id] = ~k_char_masked[in_k_base] & rd_a[byte_id] &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    (~data_in[inbyte_base+4]) & data_in[inbyte_base+3] &
			    (~data_in[inbyte_base+2]) & data_in[inbyte_base+1] &
			    data_in[inbyte_base+0];
	    pt_6[byte_id] = k_char_masked[in_k_base] & data_in[inbyte_base+7] &
			    (~data_in[inbyte_base+6]) & (~data_in[inbyte_base+5]);
	    pt_7[byte_id] = k_char_masked[in_k_base] & data_in[inbyte_base+6] &
			    (~data_in[inbyte_base+5]);
	    pt_8[byte_id] = k_char_masked[in_k_base] & (~data_in[inbyte_base+6]) &
			    data_in[inbyte_base+5];
	    pt_9[byte_id] = ~data_in[inbyte_base+7] & data_in[inbyte_base+6] &
			    (~data_in[inbyte_base+5]);
	    pt_10[byte_id] = ~data_in[inbyte_base+7] & (~data_in[inbyte_base+6]) &
			    data_in[inbyte_base+5];
	    pt_11[byte_id] = ~k_char_masked[in_k_base] & data_in[inbyte_base+7] &
			    (~data_in[inbyte_base+6]) & (~data_in[inbyte_base+5]);
	    pt_12[byte_id] = ~k_char_masked[in_k_base] & data_in[inbyte_base+7] &
			    data_in[inbyte_base+6] & data_in[inbyte_base+5];
	    pt_13[byte_id] = ~data_in[inbyte_base+7] & (~data_in[inbyte_base+6]);
	    pt_14[byte_id] = data_in[inbyte_base+7] & data_in[inbyte_base+6] &
			    (~data_in[inbyte_base+5]);
	    pt_15[byte_id] = ~data_in[inbyte_base+7] & data_in[inbyte_base+6] &
			    data_in[inbyte_base+5];
	    pt_16[byte_id] = data_in[inbyte_base+7] & (~data_in[inbyte_base+6]) &
			    data_in[inbyte_base+5];
	    pt_17[byte_id] = data_in[inbyte_base+3] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & (~data_in[inbyte_base+0]);
	    pt_18[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & data_in[inbyte_base+0];
	    pt_19[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+2] &
			    data_in[inbyte_base+1] & (~data_in[inbyte_base+0]);
	    pt_20[byte_id] = ~k_char_masked[in_k_base] & data_in[inbyte_base+4] &
			    data_in[inbyte_base+3] & data_in[inbyte_base+2] &
			    (~data_in[inbyte_base+1]) & (~data_in[inbyte_base+0]);
	    pt_21[byte_id] = data_in[inbyte_base+3] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & data_in[inbyte_base+0];
	    pt_22[byte_id] = data_in[inbyte_base+3] & data_in[inbyte_base+2] &
			    (~data_in[inbyte_base+1]) & data_in[inbyte_base+0];
	    pt_23[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & (~data_in[inbyte_base+1]) &
			    data_in[inbyte_base+0];
	    pt_24[byte_id] = data_in[inbyte_base+4] & data_in[inbyte_base+3] &
			    (~data_in[inbyte_base+2]) & (~data_in[inbyte_base+1]) &
			    (~data_in[inbyte_base+0]);
	    pt_25[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & (~data_in[inbyte_base+0]);
	    pt_26[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+1]) &
			    data_in[inbyte_base+0];
	    pt_27[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & data_in[inbyte_base+1];
	    pt_28[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & (~data_in[inbyte_base+0]);
	    pt_29[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+3] &
			    data_in[inbyte_base+2] & data_in[inbyte_base+1] &
			    data_in[inbyte_base+0];
	    pt_30[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    (~data_in[inbyte_base+1]) & (~data_in[inbyte_base+0]);
	    pt_31[byte_id] = data_in[inbyte_base+3] & data_in[inbyte_base+2] &
			    data_in[inbyte_base+1] & (~data_in[inbyte_base+0]);
	    pt_32[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & data_in[inbyte_base+1] &
			    data_in[inbyte_base+0];
	    pt_33[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & data_in[inbyte_base+0];
	    pt_34[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+1]) & (~data_in[inbyte_base+0]);
	    pt_35[byte_id] = data_in[inbyte_base+3] & data_in[inbyte_base+2] &
			    (~data_in[inbyte_base+0]);
	    pt_36[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & data_in[inbyte_base+1];
	    pt_37[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+0]);
	    pt_38[byte_id] = data_in[inbyte_base+4] & data_in[inbyte_base+3] &
			    (~data_in[inbyte_base+2]);
	    pt_39[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    (~data_in[inbyte_base+1]) & data_in[inbyte_base+0];
	    pt_40[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+2] &
			    (~data_in[inbyte_base+1]) & data_in[inbyte_base+0];
	    pt_41[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+3] &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+0]);
            pt_42[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+3] &
                            (~data_in[inbyte_base+2]) & data_in[inbyte_base+0];

        
            a_int[byte_id] = ~(pt_24[byte_id] | pt_25[byte_id] | pt_29[byte_id] |
                            pt_34[byte_id] | pt_35[byte_id] | pt_37[byte_id] |
			    pt_17[byte_id] | pt_19[byte_id]);

	    b_int[byte_id] = pt_25[byte_id] | pt_27[byte_id] | pt_29[byte_id] |
			    pt_30[byte_id] | pt_31[byte_id] | pt_32[byte_id] |
			    pt_33[byte_id] | pt_17[byte_id] | pt_18[byte_id] |
			    pt_19[byte_id];

	    c_int[byte_id] = ~(pt_23[byte_id] | pt_29[byte_id] | pt_33[byte_id] |
			    pt_36[byte_id] | pt_39[byte_id] | pt_42[byte_id] |
			    pt_17[byte_id] | pt_18[byte_id]);

	    d_int[byte_id] = pt_22[byte_id] | pt_28[byte_id] | pt_29[byte_id] |
			    pt_35[byte_id] | pt_38[byte_id] | pt_42[byte_id];

	    e_int[byte_id] = ~(pt_24[byte_id] | pt_28[byte_id] | pt_30[byte_id] |
			    pt_32[byte_id] | pt_40[byte_id] | pt_41[byte_id] |
			    pt_42[byte_id] | pt_18[byte_id] | pt_19[byte_id]);

	    f_int[byte_id] = pt_0[byte_id] | pt_1[byte_id] | pt_2[byte_id] |
			    pt_3[byte_id] | pt_4[byte_id] | pt_5[byte_id] |
			    pt_6[byte_id] | pt_13[byte_id] | pt_16[byte_id];

	    g_int[byte_id] = ~(pt_11[byte_id] | pt_12[byte_id] | pt_13[byte_id] |
			    pt_15[byte_id] | pt_16[byte_id]);

	    h_int[byte_id] = ~(pt_6[byte_id] | pt_9[byte_id] | pt_10[byte_id] |
			    pt_12[byte_id]);

	    i_int[byte_id] = ~(pt_20[byte_id] | pt_21[byte_id] | pt_22[byte_id] |
			    pt_23[byte_id] | pt_26[byte_id] | pt_27[byte_id] |
			    pt_31[byte_id] | pt_32[byte_id] | pt_33[byte_id] |
			    pt_34[byte_id] | pt_38[byte_id]);

	    j_int[byte_id] = ~(pt_0[byte_id] | pt_1[byte_id] | pt_2[byte_id] |
			    pt_3[byte_id] | pt_4[byte_id] | pt_5[byte_id] |
			    pt_11[byte_id] | pt_14[byte_id] | pt_16[byte_id]);

	    unbal6_int[byte_id] = ~(pt_20[byte_id] | pt_26[byte_id] | pt_32[byte_id] |
			    pt_36[byte_id] | pt_37[byte_id] | pt_39[byte_id] |
			    pt_40[byte_id] | pt_41[byte_id] | pt_42[byte_id] |
			    pt_17[byte_id] | pt_18[byte_id] | pt_19[byte_id]);

	    encrd_int[byte_id] = ~(pt_20[byte_id] | pt_23[byte_id] | pt_24[byte_id] |
			    pt_26[byte_id] | pt_34[byte_id] | pt_36[byte_id] |
			    pt_37[byte_id] | pt_39[byte_id] | pt_40[byte_id] |
			    pt_41[byte_id] | pt_42[byte_id] | pt_17[byte_id] |
			    pt_18[byte_id] | pt_19[byte_id]);

	    unbal4_int[byte_id] = ~(pt_9[byte_id] | pt_10[byte_id] | pt_14[byte_id] |
			    pt_15[byte_id] | pt_16[byte_id]);

            rdvalbal4_int[byte_id] = pt_7[byte_id] | pt_8[byte_id] | pt_11[byte_id] |
                            pt_12[byte_id] | pt_15[byte_id];

            a[byte_id] = a_int[byte_id] & (~k_char[in_k_base]);
            b[byte_id] = b_int[byte_id] & (~k_char[in_k_base]);
            c[byte_id] = c_int[byte_id] | k_char[in_k_base];
	    d[byte_id] = d_int[byte_id] | k_char[in_k_base];
	    e[byte_id] = e_int[byte_id] | k_char[in_k_base];
	    f[byte_id] = f_int[byte_id] | k_char[in_k_base];
	    g[byte_id] = g_int[byte_id] & (~k_char[in_k_base]);
	    h[byte_id] = h_int[byte_id] | k_char[in_k_base];
	    i[byte_id] = i_int[byte_id] | k_char[in_k_base];
	    j[byte_id] = j_int[byte_id] & (~k_char[in_k_base]);
	    unbal6[byte_id] = unbal6_int[byte_id] | k_char[in_k_base];
            encrd[byte_id] = encrd_int[byte_id] | k_char[in_k_base];
            unbal4[byte_id] = unbal4_int[byte_id] & (~k_char[in_k_base]);
            rdvalbal4[byte_id] = rdvalbal4_int[byte_id] | k_char[in_k_base];

        
            rd_b[byte_id] = rd_a[byte_id] ^ unbal6[byte_id];
            rd_a[byte_id+1] = rd_a[byte_id] ^ unbal4[byte_id] ^ unbal6[byte_id];

	    invrt4[byte_id] = (~rd_b[byte_id] & rdvalbal4[byte_id]) |
			    (rd_b[byte_id] & (~rdvalbal4[byte_id]) & unbal4[byte_id]);
	    invrt6[byte_id] = (rd_a[byte_id] & encrd[byte_id]) |
			    (~rd_a[byte_id] & unbal6[byte_id] & (~encrd[byte_id]));

	    enc_data[outbyte_base+0] = j[byte_id] ^ invrt4[byte_id];
	    enc_data[outbyte_base+1] = h[byte_id] ^ invrt4[byte_id];
	    enc_data[outbyte_base+2] = g[byte_id] ^ invrt4[byte_id];
	    enc_data[outbyte_base+3] = f[byte_id] ^ invrt4[byte_id];
	    enc_data[outbyte_base+4] = i[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+5] = e[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+6] = d[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+7] = c[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+8] = b[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+9] = a[byte_id] ^ invrt6[byte_id];
        end

        nxt_rd_enc = rd_a[BYTES];
    end
  end else begin :              GET_k28p5only_eq_0
    always @ * begin : encode_PROC
	integer byte_id, inbyte_base, in_k_base, outbyte_base;
	reg [BYTES-1:0] pt_0, pt_1, pt_2, pt_3, pt_4, pt_5, pt_6, pt_7, pt_8, pt_9;
	reg [BYTES-1:0] pt_10, pt_11, pt_12, pt_13, pt_14, pt_15, pt_16, pt_17, pt_18, pt_19;
	reg [BYTES-1:0] pt_20, pt_21, pt_22, pt_23, pt_24, pt_25, pt_26, pt_27, pt_28, pt_29;
	reg [BYTES-1:0] pt_30, pt_31, pt_32, pt_33, pt_34, pt_35, pt_36, pt_37, pt_38, pt_39;
	reg [BYTES-1:0] pt_40, pt_41, pt_42;
	reg [BYTES-1:0] unbal4, unbal6, rdvalbal4, encrd;
	reg [BYTES-1:0] a, b, c, d, e, f, g, h, i, j;
	reg [BYTES-1:0] unbal4_int, unbal6_int, rdvalbal4_int, encrd_int;
	reg [BYTES-1:0] a_int, b_int, c_int, d_int, e_int, f_int, g_int, h_int, i_int, j_int;
        reg [BYTES-1:0] rd_b, invrt4, invrt6;
        reg [BYTES : 0] rd_a;

        
        rd_a[0] = rd_effective;
        for (byte_id=0 ; byte_id < BYTES ; byte_id=byte_id+1) begin

            in_k_base = BYTES-byte_id-1;
            inbyte_base = 8 * (BYTES-byte_id-1);
	    outbyte_base = 10 * (BYTES-byte_id-1);

	    pt_0[byte_id] = ~k_char_masked[in_k_base] & (~rd_a[byte_id]) &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+1]) &
			    (~data_in[inbyte_base+0]);
	    pt_1[byte_id] = ~k_char_masked[in_k_base] & (~rd_a[byte_id]) &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & data_in[inbyte_base+1] &
			    (~data_in[inbyte_base+0]);
	    pt_2[byte_id] = ~k_char_masked[in_k_base] & rd_a[byte_id] &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    (~data_in[inbyte_base+4]) & data_in[inbyte_base+3] &
			    data_in[inbyte_base+2] & data_in[inbyte_base+1] &
			    (~data_in[inbyte_base+0]);
	    pt_3[byte_id] = ~k_char_masked[in_k_base] & (~rd_a[byte_id]) &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & (~data_in[inbyte_base+1]) &
			    data_in[inbyte_base+0];
	    pt_4[byte_id] = ~k_char_masked[in_k_base] & rd_a[byte_id] &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    (~data_in[inbyte_base+4]) & data_in[inbyte_base+3] &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+1]) &
			    data_in[inbyte_base+0];
	    pt_5[byte_id] = ~k_char_masked[in_k_base] & rd_a[byte_id] &
			    data_in[inbyte_base+7] & data_in[inbyte_base+5] &
			    (~data_in[inbyte_base+4]) & data_in[inbyte_base+3] &
			    (~data_in[inbyte_base+2]) & data_in[inbyte_base+1] &
			    data_in[inbyte_base+0];
	    pt_6[byte_id] = k_char_masked[in_k_base] & data_in[inbyte_base+7] &
			    (~data_in[inbyte_base+6]) & (~data_in[inbyte_base+5]);
	    pt_7[byte_id] = k_char_masked[in_k_base] & data_in[inbyte_base+6] &
			    (~data_in[inbyte_base+5]);
	    pt_8[byte_id] = k_char_masked[in_k_base] & (~data_in[inbyte_base+6]) &
			    data_in[inbyte_base+5];
	    pt_9[byte_id] = ~data_in[inbyte_base+7] & data_in[inbyte_base+6] &
			    (~data_in[inbyte_base+5]);
	    pt_10[byte_id] = ~data_in[inbyte_base+7] & (~data_in[inbyte_base+6]) &
			    data_in[inbyte_base+5];
	    pt_11[byte_id] = ~k_char_masked[in_k_base] & data_in[inbyte_base+7] &
			    (~data_in[inbyte_base+6]) & (~data_in[inbyte_base+5]);
	    pt_12[byte_id] = ~k_char_masked[in_k_base] & data_in[inbyte_base+7] &
			    data_in[inbyte_base+6] & data_in[inbyte_base+5];
	    pt_13[byte_id] = ~data_in[inbyte_base+7] & (~data_in[inbyte_base+6]);
	    pt_14[byte_id] = data_in[inbyte_base+7] & data_in[inbyte_base+6] &
			    (~data_in[inbyte_base+5]);
	    pt_15[byte_id] = ~data_in[inbyte_base+7] & data_in[inbyte_base+6] &
			    data_in[inbyte_base+5];
	    pt_16[byte_id] = data_in[inbyte_base+7] & (~data_in[inbyte_base+6]) &
			    data_in[inbyte_base+5];
	    pt_17[byte_id] = data_in[inbyte_base+3] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & (~data_in[inbyte_base+0]);
	    pt_18[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & data_in[inbyte_base+0];
	    pt_19[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+2] &
			    data_in[inbyte_base+1] & (~data_in[inbyte_base+0]);
	    pt_20[byte_id] = ~k_char_masked[in_k_base] & data_in[inbyte_base+4] &
			    data_in[inbyte_base+3] & data_in[inbyte_base+2] &
			    (~data_in[inbyte_base+1]) & (~data_in[inbyte_base+0]);
	    pt_21[byte_id] = data_in[inbyte_base+3] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & data_in[inbyte_base+0];
	    pt_22[byte_id] = data_in[inbyte_base+3] & data_in[inbyte_base+2] &
			    (~data_in[inbyte_base+1]) & data_in[inbyte_base+0];
	    pt_23[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & (~data_in[inbyte_base+1]) &
			    data_in[inbyte_base+0];
	    pt_24[byte_id] = data_in[inbyte_base+4] & data_in[inbyte_base+3] &
			    (~data_in[inbyte_base+2]) & (~data_in[inbyte_base+1]) &
			    (~data_in[inbyte_base+0]);
	    pt_25[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & (~data_in[inbyte_base+0]);
	    pt_26[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+1]) &
			    data_in[inbyte_base+0];
	    pt_27[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & data_in[inbyte_base+1];
	    pt_28[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & (~data_in[inbyte_base+0]);
	    pt_29[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+3] &
			    data_in[inbyte_base+2] & data_in[inbyte_base+1] &
			    data_in[inbyte_base+0];
	    pt_30[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    (~data_in[inbyte_base+1]) & (~data_in[inbyte_base+0]);
	    pt_31[byte_id] = data_in[inbyte_base+3] & data_in[inbyte_base+2] &
			    data_in[inbyte_base+1] & (~data_in[inbyte_base+0]);
	    pt_32[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & data_in[inbyte_base+1] &
			    data_in[inbyte_base+0];
	    pt_33[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    data_in[inbyte_base+1] & data_in[inbyte_base+0];
	    pt_34[byte_id] = ~data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+1]) & (~data_in[inbyte_base+0]);
	    pt_35[byte_id] = data_in[inbyte_base+3] & data_in[inbyte_base+2] &
			    (~data_in[inbyte_base+0]);
	    pt_36[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    (~data_in[inbyte_base+2]) & data_in[inbyte_base+1];
	    pt_37[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+3]) &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+0]);
	    pt_38[byte_id] = data_in[inbyte_base+4] & data_in[inbyte_base+3] &
			    (~data_in[inbyte_base+2]);
	    pt_39[byte_id] = data_in[inbyte_base+4] & (~data_in[inbyte_base+2]) &
			    (~data_in[inbyte_base+1]) & data_in[inbyte_base+0];
	    pt_40[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+2] &
			    (~data_in[inbyte_base+1]) & data_in[inbyte_base+0];
	    pt_41[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+3] &
			    data_in[inbyte_base+2] & (~data_in[inbyte_base+0]);
            pt_42[byte_id] = ~data_in[inbyte_base+4] & data_in[inbyte_base+3] &
                            (~data_in[inbyte_base+2]) & data_in[inbyte_base+0];

        
            a_int[byte_id] = ~(pt_24[byte_id] | pt_25[byte_id] | pt_29[byte_id] |
                            pt_34[byte_id] | pt_35[byte_id] | pt_37[byte_id] |
			    pt_17[byte_id] | pt_19[byte_id]);

	    b_int[byte_id] = pt_25[byte_id] | pt_27[byte_id] | pt_29[byte_id] |
			    pt_30[byte_id] | pt_31[byte_id] | pt_32[byte_id] |
			    pt_33[byte_id] | pt_17[byte_id] | pt_18[byte_id] |
			    pt_19[byte_id];

	    c_int[byte_id] = ~(pt_23[byte_id] | pt_29[byte_id] | pt_33[byte_id] |
			    pt_36[byte_id] | pt_39[byte_id] | pt_42[byte_id] |
			    pt_17[byte_id] | pt_18[byte_id]);

	    d_int[byte_id] = pt_22[byte_id] | pt_28[byte_id] | pt_29[byte_id] |
			    pt_35[byte_id] | pt_38[byte_id] | pt_42[byte_id];

	    e_int[byte_id] = ~(pt_24[byte_id] | pt_28[byte_id] | pt_30[byte_id] |
			    pt_32[byte_id] | pt_40[byte_id] | pt_41[byte_id] |
			    pt_42[byte_id] | pt_18[byte_id] | pt_19[byte_id]);

	    f_int[byte_id] = pt_0[byte_id] | pt_1[byte_id] | pt_2[byte_id] |
			    pt_3[byte_id] | pt_4[byte_id] | pt_5[byte_id] |
			    pt_6[byte_id] | pt_13[byte_id] | pt_16[byte_id];

	    g_int[byte_id] = ~(pt_11[byte_id] | pt_12[byte_id] | pt_13[byte_id] |
			    pt_15[byte_id] | pt_16[byte_id]);

	    h_int[byte_id] = ~(pt_6[byte_id] | pt_9[byte_id] | pt_10[byte_id] |
			    pt_12[byte_id]);

	    i_int[byte_id] = ~(pt_20[byte_id] | pt_21[byte_id] | pt_22[byte_id] |
			    pt_23[byte_id] | pt_26[byte_id] | pt_27[byte_id] |
			    pt_31[byte_id] | pt_32[byte_id] | pt_33[byte_id] |
			    pt_34[byte_id] | pt_38[byte_id]);

	    j_int[byte_id] = ~(pt_0[byte_id] | pt_1[byte_id] | pt_2[byte_id] |
			    pt_3[byte_id] | pt_4[byte_id] | pt_5[byte_id] |
			    pt_11[byte_id] | pt_14[byte_id] | pt_16[byte_id]);

	    unbal6_int[byte_id] = ~(pt_20[byte_id] | pt_26[byte_id] | pt_32[byte_id] |
			    pt_36[byte_id] | pt_37[byte_id] | pt_39[byte_id] |
			    pt_40[byte_id] | pt_41[byte_id] | pt_42[byte_id] |
			    pt_17[byte_id] | pt_18[byte_id] | pt_19[byte_id]);

	    encrd_int[byte_id] = ~(pt_20[byte_id] | pt_23[byte_id] | pt_24[byte_id] |
			    pt_26[byte_id] | pt_34[byte_id] | pt_36[byte_id] |
			    pt_37[byte_id] | pt_39[byte_id] | pt_40[byte_id] |
			    pt_41[byte_id] | pt_42[byte_id] | pt_17[byte_id] |
			    pt_18[byte_id] | pt_19[byte_id]);

	    unbal4_int[byte_id] = ~(pt_9[byte_id] | pt_10[byte_id] | pt_14[byte_id] |
			    pt_15[byte_id] | pt_16[byte_id]);

	    rdvalbal4_int[byte_id] = pt_7[byte_id] | pt_8[byte_id] | pt_11[byte_id] |
			    pt_12[byte_id] | pt_15[byte_id];

	    a[byte_id] = a_int[byte_id];
	    b[byte_id] = b_int[byte_id];
	    c[byte_id] = c_int[byte_id];
	    d[byte_id] = d_int[byte_id];
	    e[byte_id] = e_int[byte_id];
	    f[byte_id] = f_int[byte_id];
	    g[byte_id] = g_int[byte_id];
	    h[byte_id] = h_int[byte_id];
	    i[byte_id] = i_int[byte_id];
	    j[byte_id] = j_int[byte_id];
	    unbal6[byte_id] = unbal6_int[byte_id];
	    encrd[byte_id] = encrd_int[byte_id];
            unbal4[byte_id] = unbal4_int[byte_id];
            rdvalbal4[byte_id] = rdvalbal4_int[byte_id];

        
            rd_b[byte_id] = rd_a[byte_id] ^ unbal6[byte_id];
            rd_a[byte_id+1] = rd_a[byte_id] ^ unbal4[byte_id] ^ unbal6[byte_id];

	    invrt4[byte_id] = (~rd_b[byte_id] & rdvalbal4[byte_id]) |
			    (rd_b[byte_id] & (~rdvalbal4[byte_id]) & unbal4[byte_id]);
	    invrt6[byte_id] = (rd_a[byte_id] & encrd[byte_id]) |
			    (~rd_a[byte_id] & unbal6[byte_id] & (~encrd[byte_id]));

	    enc_data[outbyte_base+0] = j[byte_id] ^ invrt4[byte_id];
	    enc_data[outbyte_base+1] = h[byte_id] ^ invrt4[byte_id];
	    enc_data[outbyte_base+2] = g[byte_id] ^ invrt4[byte_id];
	    enc_data[outbyte_base+3] = f[byte_id] ^ invrt4[byte_id];
	    enc_data[outbyte_base+4] = i[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+5] = e[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+6] = d[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+7] = c[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+8] = b[byte_id] ^ invrt6[byte_id];
	    enc_data[outbyte_base+9] = a[byte_id] ^ invrt6[byte_id];
        end

        nxt_rd_enc = rd_a[BYTES];
    end
  end
endgenerate
// spyglass enable_block W415a
// spyglass enable_block SelfDeterminedExpr-ML



    // async reset
`ifndef DWC_BCM44_NO_EN
  `ifndef DWC_BCM44_USE_EN
generate if (EN_MODE == 0) begin :      GEN_async_em_eq_0
    always @ (posedge clk or negedge rst_n) begin : async_rst_ffs_PROC
        if (rst_n == 1'b0) begin
            rd_int <= 1'b0;
            data_out_int <= {10*BYTES{1'b0}};
        end else begin
// spyglass disable_block W392
// SMD: Do not use a reset or set with both positive and negative polarity within the same design unit
// SJ: The reset signal is derived from multiple signals but is not used with both positive and negative polarities within the module.
            rd_int <= new_rd;
            data_out_int <= enc_data;
// spyglass enable_block W392
        end
    end
end else begin :                        GEN_async_em_ne_0
    always @ (posedge clk or negedge rst_n) begin : async_rst_ffs_PROC
        if (rst_n == 1'b0) begin
            rd_int <= 1'b0;
            data_out_int <= {10*BYTES{1'b0}};
        end else begin
          if (enable == 1'b1) begin
// spyglass disable_block W392
// SMD: Do not use a reset or set with both positive and negative polarity within the same design unit
// SJ: The reset signal is derived from multiple signals but is not used with both positive and negative polarities within the module.
            rd_int <= new_rd;
            data_out_int <= enc_data;
// spyglass enable_block W392
          end
        end
    end
end endgenerate
`else
    always @ (posedge clk or negedge rst_n) begin : async_rst_ffs_PROC
        if (rst_n == 1'b0) begin
            rd_int <= 1'b0;
            data_out_int <= {10*BYTES{1'b0}};
        end else begin
          if (enable == 1'b1) begin
// spyglass disable_block W392
// SMD: Do not use a reset or set with both positive and negative polarity within the same design unit
// SJ: The reset signal is derived from multiple signals but is not used with both positive and negative polarities within the module.
            rd_int <= new_rd;
            data_out_int <= enc_data;   
// spyglass enable_block W392
          end
        end
          end
`endif
`else
    always @ (posedge clk or negedge rst_n) begin : async_rst_ffs_PROC
        if (rst_n == 1'b0) begin
            rd_int <= 1'b0;
            data_out_int <= {10*BYTES{1'b0}};
        end else begin
// spyglass disable_block W392
// SMD: Do not use a reset or set with both positive and negative polarity within the same design unit
// SJ: The reset signal is derived from multiple signals but is not used with both positive and negative polarities within the module.
            rd_int <= new_rd;
            data_out_int <= enc_data;
// spyglass enable_block W392
        end
    end
`endif
    

    assign data_out = data_out_int;
    assign rd = rd_int;

endmodule
// reuse-pragma process_ifdef all_branches
