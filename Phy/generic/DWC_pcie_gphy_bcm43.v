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
// Filename    : DWC_pcie_gphy_bcm43.v
// Revision    : $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_bcm43.v#7 $
// Author      : Rick Kelly         Sep. 14, 1999
// Description : DWC_pcie_gphy_bcm43.v Verilog module for DWC_pcie_gphy
//
// DesignWare IP ID: 21472c09
//
////////////////////////////////////////////////////////////////////////////////

  module DWC_pcie_gphy_bcm43 (
            clk,
            rst_n,
            init_rd_n,
	    init_rd_val,
	    data_in,

	    error,
	    rd,
	    k_char,
	    data_out,
	    rd_err,
	    code_err,

`ifndef DWC_BCM43_NO_EN
	    enable,
`endif

	    rd_err_bus,
	    code_err_bus,
	    ib_rd_bus
	    );


    parameter BYTES = 2;	// number of BYTES decode per clock cycle

    parameter K28_5_ONLY = 0;	// special character control mode

`ifndef DWC_BCM43_NO_EN
`ifndef DWC_BCM43_USE_EN
    parameter EN_MODE = 0;	// enable mode
`endif
`endif

    parameter INIT_MODE = 0;	// initialization mode

input			clk;		// clock input
input			rst_n;		// active low reset
input			init_rd_n;	// active low running disp. force control
input			init_rd_val;	// running disp. value to be forced
input  [BYTES*10-1:0]	data_in;	// data to be decoded (10 bits per byte)
output			error;		// "any error" status flag
output			rd;		// current running disparity state
output [BYTES-1:0]	k_char;		// special character decode status bus
output [BYTES*8-1:0]	data_out;	// decoded output data (8 bits per byte)
output			rd_err;		// running displarity error status flag
output			code_err;	// code violation error status flag
`ifndef DWC_BCM43_NO_EN
input			enable;		// register enabl input (NC when EN_MODE = 0)
`endif
output [BYTES-1:0]	rd_err_bus;	// byte specific running disparity error flag bus
output [BYTES-1:0]	code_err_bus;	// byte specific code error flag bus
output [BYTES-1:0]	ib_rd_bus;	// inter-byte running disparity bus

reg [BYTES*8-1:0] data_out_int;
reg [BYTES-1:0] k_char_int;
reg rd_err_int, code_err_int;
reg [BYTES-1:0] rd_err_bus_int, code_err_bus_int;
reg error_int, rd_int;
reg [BYTES-1:0] ib_rd_bus_int;


localparam [1:0] K28_5_ONLY_SET = K28_5_ONLY;

reg  [BYTES*8-1:0] data_out_int_din;
reg  [BYTES-1:0] error_code, k_char_int_din, error_rd;
reg  rd_carry;
wire error_int_din, rd_int_din;
wire rd_err_int_din, code_err_int_din;
wire rd_int_selected;



generate
  if (INIT_MODE == 0) begin :   GEN_im_eq_0
    assign rd_int_selected = rd_int;
    assign rd_int_din = (init_rd_n == 1'b1)? rd_carry : init_rd_val;
  end else begin :		GEN_im_ne_0
    assign rd_int_selected = (init_rd_n == 1'b0)? init_rd_val : rd_int;
    assign rd_int_din = rd_carry;
  end
endgenerate


    assign data_out = data_out_int;
    assign k_char   = k_char_int;
    assign error    = error_int;
    assign rd_err   = rd_err_int;
    assign code_err = code_err_int;
    assign rd_err_bus   = rd_err_bus_int;
    assign code_err_bus = code_err_bus_int;
    assign rd       = rd_int;
    assign ib_rd_bus    = ib_rd_bus_int;



// spyglass disable_block W415a
// SMD: Signal may be multiply assigned (beside initialization) in the same scope
// SJ: The design checked and verified that not any one of a single bit of the bus is assigned more than once beside initialization or the multiple assignments are intentional.
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
    always @ (data_in or rd_int_selected) begin : decode_PROC
        integer byte_id, in_bit_base, out_bit_base, pre_bit_base;
        reg  [BYTES-1:0] pt_1, pt_2, pt_3, pt_4, pt_5, pt_6, pt_7, pt_8, pt_9;
	reg  [BYTES-1:0] pt_10, pt_11, pt_12, pt_13, pt_14, pt_15, pt_16, pt_17, pt_18, pt_19;
	reg  [BYTES-1:0] pt_20, pt_21, pt_22, pt_23, pt_24, pt_25, pt_26, pt_27, pt_28, pt_29;
	reg  [BYTES-1:0] pt_30, pt_31, pt_32, pt_33, pt_34, pt_35, pt_36, pt_37, pt_38, pt_39;
	reg  [BYTES-1:0] pt_40, pt_41, pt_42, pt_43, pt_44, pt_45, pt_46, pt_47, pt_48, pt_49;
	reg  [BYTES-1:0] pt_50, pt_51, pt_52, pt_53, pt_54, pt_55, pt_56, pt_57, pt_58, pt_59;
	reg  [BYTES-1:0] pt_60, pt_61, pt_62, pt_63, pt_64, pt_65, pt_66, pt_67, pt_68, pt_69;
	reg  [BYTES-1:0] pt_70, pt_71, pt_72, pt_73, pt_74, pt_75, pt_76, pt_77, pt_78, pt_79;
	reg  [BYTES-1:0] pt_80, pt_81, pt_82, pt_83, pt_84, pt_85, pt_86, pt_87, pt_88, pt_89;
	reg  [BYTES-1:0] pt_90, pt_91, pt_92, pt_93, pt_94, pt_95, pt_96, pt_97, pt_98, pt_99;
	reg  [BYTES-1:0] pt_100, pt_101, pt_102, pt_103, pt_104, pt_105, pt_106, pt_107, pt_108, pt_109;
	reg  [BYTES-1:0] pt_110, pt_111, pt_112, pt_113, pt_114, pt_115, pt_116, pt_117, pt_118, pt_119;
	reg  [BYTES-1:0] pt_120, pt_121, pt_122, pt_123, pt_124, pt_125, pt_126, pt_127, pt_128, pt_129;
	reg  [BYTES-1:0] pt_130, pt_131, pt_132, pt_133, pt_134, pt_135, pt_136, pt_137, pt_138, pt_139;
	reg  [BYTES-1:0] pt_140, pt_141, pt_142, pt_143, pt_144, pt_145, pt_146, pt_147, pt_148, pt_149;
	reg  [BYTES-1:0] pt_150, pt_151, pt_152, pt_153, pt_154, pt_155, pt_156, pt_157, pt_158, pt_159;
	reg  [BYTES-1:0] pt_160, pt_161, pt_162;
	reg  [BYTES*3-1:0] datpreout;
	reg  [BYTES-1:0] alw_kx_7, d111314, d171820;
	reg  [BYTES-1:0] dx_7, error_hi, error_lo, invert_567, invrt_if_k28;
	reg  [BYTES-1:0] k28_x, kx_5, kx_7, lo_f_bal_hi, lo_f_bal_lo;
        reg  [BYTES-1:0] unbal_hi_0, unbal_hi_1, unbal_lo_0, unbal_lo_1;
        reg  [BYTES:0] rd_thread;

        datpreout = {BYTES*3{1'b0}};
        data_out_int_din = {BYTES*8{1'b0}};
        error_code = {BYTES{1'b0}};
        error_rd = {BYTES{1'b0}};
        k_char_int_din = {BYTES{1'b0}};
        rd_thread = {{BYTES{1'b0}},rd_int_selected};

        for (byte_id=0; byte_id < BYTES ; byte_id=byte_id+1) begin
            in_bit_base = (10*(BYTES-1-byte_id));
            pre_bit_base = (3*(BYTES-1-byte_id));
            out_bit_base = (8*(BYTES-1-byte_id));




            pt_1[byte_id] = ( ~data_in[in_bit_base+3] & data_in[in_bit_base+1] & data_in[in_bit_base+0]);
            pt_2[byte_id] = ( data_in[in_bit_base+3] & (~data_in[in_bit_base+0]));
            pt_3[byte_id] = ( ~data_in[in_bit_base+2] & (~data_in[in_bit_base+1]));
	    pt_4[byte_id] = ( data_in[in_bit_base+3] & (~data_in[in_bit_base+1]) & (~data_in[in_bit_base+0]));
	    pt_5[byte_id] = ( ~data_in[in_bit_base+3] & data_in[in_bit_base+0]);
	    pt_6[byte_id] = ( data_in[in_bit_base+2] & data_in[in_bit_base+1]);
	    pt_7[byte_id] = ( ~data_in[in_bit_base+3] & (~data_in[in_bit_base+2]) & (~data_in[in_bit_base+1]));
	    pt_8[byte_id] = ( data_in[in_bit_base+3] & data_in[in_bit_base+2] & data_in[in_bit_base+0]);
	    pt_9[byte_id] = ( ~data_in[in_bit_base+2] & (~data_in[in_bit_base+0]));
	    pt_10[byte_id] = ( ~data_in[in_bit_base+2] & (~data_in[in_bit_base+1]) & (~data_in[in_bit_base+0]));
	    pt_11[byte_id] = ( ~data_in[in_bit_base+3] & (~data_in[in_bit_base+1]) & (~data_in[in_bit_base+0]));
	    pt_12[byte_id] = ( ~data_in[in_bit_base+3] & (~data_in[in_bit_base+2]) & (~data_in[in_bit_base+0]));
	    pt_13[byte_id] = ( data_in[in_bit_base+3] & data_in[in_bit_base+2] & data_in[in_bit_base+1]);
	    pt_14[byte_id] = ( data_in[in_bit_base+3] & data_in[in_bit_base+1] & data_in[in_bit_base+0]);
	    pt_15[byte_id] = ( data_in[in_bit_base+2] & data_in[in_bit_base+1] & data_in[in_bit_base+0]);
	    pt_16[byte_id] = ( data_in[in_bit_base+3] & data_in[in_bit_base+2] & (~data_in[in_bit_base+1]) & (~data_in[in_bit_base+0]));
	    pt_17[byte_id] = ( ~data_in[in_bit_base+3] & (~data_in[in_bit_base+2]) & data_in[in_bit_base+1] & data_in[in_bit_base+0]);
	    pt_18[byte_id] = ( data_in[in_bit_base+3] & (~data_in[in_bit_base+2]) & data_in[in_bit_base+1] & (~data_in[in_bit_base+0]));
	    pt_19[byte_id] = ( ~data_in[in_bit_base+3] & data_in[in_bit_base+2] & (~data_in[in_bit_base+1]) & data_in[in_bit_base+0]);
	    pt_20[byte_id] = ( ~data_in[in_bit_base+3] & data_in[in_bit_base+2] & data_in[in_bit_base+1] & (~data_in[in_bit_base+0]));
	    pt_21[byte_id] = ( data_in[in_bit_base+3] & (~data_in[in_bit_base+2]) & (~data_in[in_bit_base+1]) & data_in[in_bit_base+0]);
	    pt_22[byte_id] = ( data_in[in_bit_base+4] & data_in[in_bit_base+3] & (~data_in[in_bit_base+2]) & data_in[in_bit_base+1] & (~data_in[in_bit_base+0]));
	    pt_23[byte_id] = ( ~data_in[in_bit_base+4] & (~data_in[in_bit_base+3]) & data_in[in_bit_base+2] & (~data_in[in_bit_base+1]) & data_in[in_bit_base+0]);
	    pt_24[byte_id] = ( data_in[in_bit_base+3] & (~data_in[in_bit_base+2]) & (~data_in[in_bit_base+1]) & (~data_in[in_bit_base+0]));
	    pt_25[byte_id] = ( ~data_in[in_bit_base+3] & data_in[in_bit_base+2] & data_in[in_bit_base+1] & data_in[in_bit_base+0]);
	    pt_26[byte_id] = ( data_in[in_bit_base+3] & data_in[in_bit_base+2] & data_in[in_bit_base+1] & (~data_in[in_bit_base+0]));
	    pt_27[byte_id] = ( ~data_in[in_bit_base+3] & (~data_in[in_bit_base+2]) & (~data_in[in_bit_base+1]) & data_in[in_bit_base+0]);
	    pt_28[byte_id] = ( ~data_in[in_bit_base+5] & (~data_in[in_bit_base+4]) & (~data_in[in_bit_base+3]) & (~data_in[in_bit_base+2]) & (~data_in[in_bit_base+1]));
	    pt_29[byte_id] = ( data_in[in_bit_base+5] & data_in[in_bit_base+4] & data_in[in_bit_base+3] & data_in[in_bit_base+2] & data_in[in_bit_base+1]);
	    pt_30[byte_id] = ( ~data_in[in_bit_base+3] & (~data_in[in_bit_base+2]) & (~data_in[in_bit_base+1]) & (~data_in[in_bit_base+0]));
	    pt_31[byte_id] = ( data_in[in_bit_base+3] & data_in[in_bit_base+2] & data_in[in_bit_base+1] & data_in[in_bit_base+0]);


	    datpreout[pre_bit_base+0] = pt_1[byte_id] | pt_2[byte_id] | pt_3[byte_id];

	    datpreout[pre_bit_base+1] = pt_4[byte_id] | pt_5[byte_id] | pt_6[byte_id];

	    datpreout[pre_bit_base+2] = pt_7[byte_id] | pt_8[byte_id] | pt_6[byte_id] | pt_9[byte_id];

	    unbal_lo_0[byte_id] = pt_10[byte_id] | pt_11[byte_id] | pt_12[byte_id] | pt_7[byte_id];

	    unbal_lo_1[byte_id] = pt_13[byte_id] | pt_8[byte_id] | pt_14[byte_id] | pt_15[byte_id];

	    lo_f_bal_lo[byte_id] = pt_16[byte_id] | pt_17[byte_id];

	    invrt_if_k28[byte_id] = pt_18[byte_id] | pt_19[byte_id] | pt_20[byte_id] | pt_21[byte_id];

	    kx_5[byte_id] = pt_22[byte_id] | pt_23[byte_id];

	    kx_7[byte_id] = pt_24[byte_id] | pt_25[byte_id];

	    dx_7[byte_id] = pt_26[byte_id] | pt_27[byte_id];

	    error_lo[byte_id] = pt_28[byte_id] | pt_29[byte_id] | pt_30[byte_id] | pt_31[byte_id];





	    pt_32[byte_id] = ( data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_33[byte_id] = ( ~data_in[in_bit_base+8] & data_in[in_bit_base+7] & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]));
	    pt_34[byte_id] = ( data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+6]) & data_in[in_bit_base+5]);
	    pt_35[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_36[byte_id] = ( data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+4]);
	    pt_37[byte_id] = ( data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);
	    pt_38[byte_id] = ( ~data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);
	    pt_39[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+5] & (~data_in[in_bit_base+4]));
	    pt_40[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+7] & (~data_in[in_bit_base+4]));
	    pt_41[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+7] & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_42[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & data_in[in_bit_base+4]);
	    pt_43[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+7]) & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_44[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+4]);
	    pt_45[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+7] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_46[byte_id] = ( data_in[in_bit_base+9] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);
	    pt_47[byte_id] = ( ~data_in[in_bit_base+9] & data_in[in_bit_base+7] & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);
	    pt_48[byte_id] = ( data_in[in_bit_base+8] & data_in[in_bit_base+5] & (~data_in[in_bit_base+4]));
	    pt_49[byte_id] = ( data_in[in_bit_base+8] & data_in[in_bit_base+6] & (~data_in[in_bit_base+4]));
	    pt_50[byte_id] = ( data_in[in_bit_base+8] & data_in[in_bit_base+6] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_51[byte_id] = ( ~data_in[in_bit_base+7] & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_52[byte_id] = ( ~data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+5]);
	    pt_53[byte_id] = ( ~data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+6] & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_54[byte_id] = ( data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]));
	    pt_55[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+6] & data_in[in_bit_base+4]);
	    pt_56[byte_id] = ( ~data_in[in_bit_base+9] & data_in[in_bit_base+8] & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);
	    pt_57[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & data_in[in_bit_base+6] & data_in[in_bit_base+4]);
	    pt_58[byte_id] = ( data_in[in_bit_base+7] & data_in[in_bit_base+5] & (~data_in[in_bit_base+4]));
	    pt_59[byte_id] = ( data_in[in_bit_base+8] & data_in[in_bit_base+6] & data_in[in_bit_base+5]);
	    pt_60[byte_id] = ( data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+5]);
	    pt_61[byte_id] = ( data_in[in_bit_base+7] & data_in[in_bit_base+6] & (~data_in[in_bit_base+4]));
	    pt_62[byte_id] = ( data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_63[byte_id] = ( ~data_in[in_bit_base+8] & data_in[in_bit_base+7] & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_64[byte_id] = ( ~data_in[in_bit_base+9] & data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+5]));
	    pt_65[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & data_in[in_bit_base+7] & (~data_in[in_bit_base+5]));
	    pt_66[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_67[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+4]);
	    pt_68[byte_id] = ( data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);
	    pt_69[byte_id] = ( data_in[in_bit_base+6] & data_in[in_bit_base+5] & (~data_in[in_bit_base+4]));
	    pt_70[byte_id] = ( data_in[in_bit_base+7] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_71[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & data_in[in_bit_base+7] & data_in[in_bit_base+6] & (~data_in[in_bit_base+4]));
	    pt_72[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+6]) & data_in[in_bit_base+4]);
	    pt_73[byte_id] = ( data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & (~data_in[in_bit_base+4]));
	    pt_74[byte_id] = ( ~data_in[in_bit_base+9] & data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & (~data_in[in_bit_base+4]));
	    pt_75[byte_id] = ( ~data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & data_in[in_bit_base+4]);
	    pt_76[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & data_in[in_bit_base+4]);
	    pt_77[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+5]);
	    pt_78[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+5]));
	    pt_79[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+7] & data_in[in_bit_base+5]);
	    pt_80[byte_id] = ( data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+5]);
	    pt_81[byte_id] = ( ~data_in[in_bit_base+8] & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_82[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_83[byte_id] = ( ~data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_84[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_85[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_86[byte_id] = ( ~data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+4]));
	    pt_87[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+4]));
	    pt_88[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+4]));
	    pt_89[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+4]));
	    pt_90[byte_id] = ( ~data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]));
	    pt_91[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]));
	    pt_92[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]));
	    pt_93[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]));
	    pt_94[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+6]);
	    pt_95[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+5]);
	    pt_96[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+6] & data_in[in_bit_base+5]);
	    pt_97[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+5]);
	    pt_98[byte_id] = ( data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+5]);
	    pt_99[byte_id] = ( data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_100[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+6] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_101[byte_id] = ( data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_102[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+7] & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_103[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_104[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_105[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_106[byte_id] = ( ~data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_107[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_108[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_109[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_110[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_111[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+6] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_112[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_113[byte_id] = ( data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_114[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_115[byte_id] = ( data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & data_in[in_bit_base+7] & data_in[in_bit_base+6] & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_116[byte_id] = ( ~data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+6] & (~data_in[in_bit_base+5]) & (~data_in[in_bit_base+4]));
	    pt_117[byte_id] = ( data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_118[byte_id] = ( ~data_in[in_bit_base+9] & data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_119[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & data_in[in_bit_base+7] & (~data_in[in_bit_base+6]) & data_in[in_bit_base+5] & data_in[in_bit_base+4]);
	    pt_120[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+7] & (~data_in[in_bit_base+6]) & data_in[in_bit_base+5] & (~data_in[in_bit_base+4]));
	    pt_121[byte_id] = ( data_in[in_bit_base+9] & data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & data_in[in_bit_base+5] & (~data_in[in_bit_base+4]));
	    pt_122[byte_id] = ( data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+5] & (~data_in[in_bit_base+4]));
	    pt_123[byte_id] = ( ~data_in[in_bit_base+9] & data_in[in_bit_base+8] & data_in[in_bit_base+7] & data_in[in_bit_base+6] & data_in[in_bit_base+5] & (~data_in[in_bit_base+4]));
	    pt_124[byte_id] = ( data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);
	    pt_125[byte_id] = ( ~data_in[in_bit_base+9] & data_in[in_bit_base+8] & (~data_in[in_bit_base+7]) & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);
	    pt_126[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & data_in[in_bit_base+7] & (~data_in[in_bit_base+6]) & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);
	    pt_127[byte_id] = ( ~data_in[in_bit_base+9] & (~data_in[in_bit_base+8]) & (~data_in[in_bit_base+7]) & data_in[in_bit_base+6] & (~data_in[in_bit_base+5]) & data_in[in_bit_base+4]);


	    data_out_int_din[out_bit_base+0] = pt_32[byte_id] | pt_33[byte_id] | pt_34[byte_id] | pt_35[byte_id] |
			pt_36[byte_id] | pt_37[byte_id] | pt_38[byte_id] | pt_39[byte_id] |
			pt_40[byte_id];

	    data_out_int_din[out_bit_base+1] = pt_41[byte_id] | pt_42[byte_id] | pt_43[byte_id] | pt_44[byte_id] |
			pt_45[byte_id] | pt_46[byte_id] | pt_47[byte_id] | pt_48[byte_id] |
			pt_49[byte_id];

	    data_out_int_din[out_bit_base+2] = pt_50[byte_id] | pt_51[byte_id] | pt_52[byte_id] | pt_53[byte_id] |
			pt_54[byte_id] | pt_55[byte_id] | pt_56[byte_id] | pt_57[byte_id] |
			pt_58[byte_id] | pt_40[byte_id];

	    data_out_int_din[out_bit_base+3] = pt_59[byte_id] | pt_60[byte_id] | pt_61[byte_id] | pt_62[byte_id] |
			pt_63[byte_id] | pt_64[byte_id] | pt_65[byte_id] | pt_66[byte_id] |
			pt_45[byte_id] | pt_67[byte_id] | pt_68[byte_id] | pt_69[byte_id];

	    data_out_int_din[out_bit_base+4] = pt_51[byte_id] | pt_70[byte_id] | pt_71[byte_id] | pt_72[byte_id] |
			pt_73[byte_id] | pt_74[byte_id] | pt_75[byte_id] | pt_76[byte_id] |
			pt_77[byte_id] | pt_78[byte_id] | pt_79[byte_id] | pt_80[byte_id];

	    unbal_hi_0[byte_id] = pt_51[byte_id] | pt_81[byte_id] | pt_82[byte_id] | pt_83[byte_id] |
			pt_84[byte_id] | pt_85[byte_id] | pt_86[byte_id] | pt_87[byte_id] |
			pt_88[byte_id] | pt_89[byte_id] | pt_90[byte_id] | pt_91[byte_id] |
			pt_92[byte_id] | pt_78[byte_id] | pt_93[byte_id];

	    unbal_hi_1[byte_id] = pt_94[byte_id] | pt_95[byte_id] | pt_96[byte_id] | pt_97[byte_id] |
			pt_98[byte_id] | pt_67[byte_id] | pt_55[byte_id] | pt_44[byte_id] |
			pt_36[byte_id] | pt_66[byte_id] | pt_45[byte_id] | pt_99[byte_id] |
			pt_100[byte_id] | pt_50[byte_id] | pt_101[byte_id];

	    lo_f_bal_hi[byte_id] = pt_102[byte_id] | pt_103[byte_id];

	    k28_x[byte_id] = pt_104[byte_id] | pt_105[byte_id];

	    error_hi[byte_id] = pt_93[byte_id] | pt_106[byte_id] | pt_107[byte_id] | pt_108[byte_id] |
			pt_109[byte_id] | pt_94[byte_id] | pt_110[byte_id] | pt_111[byte_id] |
			pt_112[byte_id] | pt_113[byte_id];

	    d111314[byte_id] = pt_114[byte_id] | pt_115[byte_id] | pt_116[byte_id];

	    d171820[byte_id] = pt_117[byte_id] | pt_118[byte_id] | pt_119[byte_id];

	    alw_kx_7[byte_id] = pt_104[byte_id] | pt_120[byte_id] | pt_121[byte_id] | pt_122[byte_id] |
			pt_123[byte_id] | pt_124[byte_id] | pt_125[byte_id] | pt_126[byte_id] |
			pt_127[byte_id] | pt_105[byte_id];





            pt_128[byte_id] = ( rd_thread[byte_id] & (~unbal_hi_0[byte_id]) & (~lo_f_bal_hi[byte_id]) & invrt_if_k28[byte_id]);
            pt_129[byte_id] = ( ~data_in[in_bit_base+9] & lo_f_bal_hi[byte_id] & invrt_if_k28[byte_id]);
            pt_130[byte_id] = ( ~data_in[in_bit_base+3] & lo_f_bal_lo[byte_id]);
	    pt_131[byte_id] = ( unbal_hi_1[byte_id] & invrt_if_k28[byte_id]);
	    pt_132[byte_id] = ( unbal_lo_1[byte_id]);


	    pt_135[byte_id] = ( alw_kx_7[byte_id] & kx_7[byte_id] & (~K28_5_ONLY_SET[0]));
	    pt_136[byte_id] = ( k28_x[byte_id] & kx_5[byte_id]);
	    pt_137[byte_id] = ( k28_x[byte_id] & (~K28_5_ONLY_SET[0]));
	    pt_138[byte_id] = ( data_in[in_bit_base+9] & lo_f_bal_hi[byte_id] & (~data_in[in_bit_base+3]) & lo_f_bal_lo[byte_id]);
	    pt_139[byte_id] = ( ~data_in[in_bit_base+9] & lo_f_bal_hi[byte_id] & data_in[in_bit_base+3] & lo_f_bal_lo[byte_id]);
	    pt_140[byte_id] = ( ~d111314[byte_id] & (~d171820[byte_id]) & (~alw_kx_7[byte_id]) & kx_7[byte_id]);
	    pt_141[byte_id] = ( alw_kx_7[byte_id] & kx_7[byte_id] & K28_5_ONLY_SET[0]);
	    pt_142[byte_id] = ( ~data_in[in_bit_base+9] & lo_f_bal_hi[byte_id] & unbal_lo_1[byte_id]);
	    pt_143[byte_id] = ( data_in[in_bit_base+9] & lo_f_bal_hi[byte_id] & unbal_lo_0[byte_id]);
	    pt_144[byte_id] = ( k28_x[byte_id] & (~kx_5[byte_id]) & K28_5_ONLY_SET[0]);
	    pt_145[byte_id] = ( d111314[byte_id] & (~data_in[in_bit_base+3]) & kx_7[byte_id]);
	    pt_146[byte_id] = ( d171820[byte_id] & data_in[in_bit_base+3] & kx_7[byte_id]);
	    pt_147[byte_id] = ( unbal_hi_0[byte_id] & (~data_in[in_bit_base+3]) & lo_f_bal_lo[byte_id]);
	    pt_148[byte_id] = ( unbal_hi_1[byte_id] & data_in[in_bit_base+3] & lo_f_bal_lo[byte_id]);
	    pt_149[byte_id] = ( k28_x[byte_id] & dx_7[byte_id]);
	    pt_150[byte_id] = ( unbal_hi_1[byte_id] & unbal_lo_1[byte_id]);
	    pt_151[byte_id] = ( unbal_hi_0[byte_id] & unbal_lo_0[byte_id]);
	    pt_152[byte_id] = ( error_lo[byte_id]);
	    pt_153[byte_id] = ( error_hi[byte_id]);
	    pt_154[byte_id] = ( ~rd_thread[byte_id] & (~unbal_hi_1[byte_id]) & (~lo_f_bal_hi[byte_id]) & (~data_in[in_bit_base+3]) & lo_f_bal_lo[byte_id]);
	    pt_155[byte_id] = ( rd_thread[byte_id] & (~unbal_hi_0[byte_id]) & (~lo_f_bal_hi[byte_id]) & data_in[in_bit_base+3] & lo_f_bal_lo[byte_id]);
	    pt_156[byte_id] = ( rd_thread[byte_id] & (~unbal_hi_0[byte_id]) & (~lo_f_bal_hi[byte_id]) & unbal_lo_1[byte_id]);
	    pt_157[byte_id] = ( ~rd_thread[byte_id] & (~unbal_hi_1[byte_id]) & (~lo_f_bal_hi[byte_id]) & unbal_lo_0[byte_id]);
	    pt_158[byte_id] = ( ~rd_thread[byte_id] & (~data_in[in_bit_base+9]) & lo_f_bal_hi[byte_id]);
	    pt_159[byte_id] = ( rd_thread[byte_id] & data_in[in_bit_base+9] & lo_f_bal_hi[byte_id]);
            pt_160[byte_id] = ( rd_thread[byte_id] & unbal_hi_1[byte_id]);
            pt_161[byte_id] = ( ~rd_thread[byte_id] & unbal_hi_0[byte_id]);
            pt_162[byte_id] = ( data_in[in_bit_base+9] & k28_x[byte_id] & invrt_if_k28[byte_id]);


            rd_thread[byte_id+1] = pt_128[byte_id] | pt_129[byte_id] | pt_130[byte_id] | pt_131[byte_id] | pt_132[byte_id];

            error_code[BYTES-1-byte_id] = pt_138[byte_id] | pt_139[byte_id] | pt_140[byte_id] | pt_141[byte_id] |
                                pt_142[byte_id] | pt_143[byte_id] | pt_144[byte_id] | pt_145[byte_id] |
				pt_146[byte_id] | pt_147[byte_id] | pt_148[byte_id] | pt_149[byte_id] |
				pt_150[byte_id] | pt_151[byte_id] | pt_152[byte_id] | pt_153[byte_id];

	    error_rd[BYTES-1-byte_id] = pt_154[byte_id] | pt_155[byte_id] | pt_156[byte_id] | pt_157[byte_id] |
				pt_158[byte_id] | pt_159[byte_id] | pt_160[byte_id] | pt_161[byte_id];

	    k_char_int_din[BYTES-1-byte_id] = (pt_135[byte_id] | pt_136[byte_id] | pt_137[byte_id]) & (~(
	    			pt_138[byte_id] | pt_139[byte_id] | pt_140[byte_id] | pt_141[byte_id] |
				pt_142[byte_id] | pt_143[byte_id] | pt_144[byte_id] | pt_145[byte_id] |
				pt_146[byte_id] | pt_147[byte_id] | pt_148[byte_id] | pt_149[byte_id] |
				pt_150[byte_id] | pt_151[byte_id] | pt_152[byte_id] | pt_153[byte_id]));

	    invert_567[byte_id] = pt_162[byte_id];



            data_out_int_din[out_bit_base+5] = datpreout[pre_bit_base+0] ^ invert_567[byte_id];

            data_out_int_din[out_bit_base+6] = datpreout[pre_bit_base+1] ^ invert_567[byte_id];

            data_out_int_din[out_bit_base+7] = datpreout[pre_bit_base+2] ^ invert_567[byte_id];

            end

	    rd_carry = rd_thread[BYTES];

            ib_rd_bus_int = rd_thread[BYTES : 1];
        end
// spyglass enable_block W415a
// spyglass enable_block SelfDeterminedExpr-ML



    assign error_int_din = (|error_code) | (|error_rd);

    assign rd_err_int_din = |error_rd;

    assign code_err_int_din = |error_code;


// Async reset
`ifndef DWC_BCM43_NO_EN
  `ifndef DWC_BCM43_USE_EN
generate if (EN_MODE == 0) begin : GEN_async_em_eq_0
    always @ (posedge clk or negedge rst_n) begin : mk_registers_a_PROC
        if (rst_n == 1'b0) begin
            data_out_int <= {BYTES*8{1'b0}};
	    error_int    <= 1'b0;
            rd_err_int   <= 1'b0;
            code_err_int <= 1'b0;
            k_char_int   <= {BYTES{1'b0}};
            rd_err_bus_int   <= {BYTES{1'b0}};
            code_err_bus_int <= {BYTES{1'b0}};
            rd_int       <= 1'b0;
        end else begin
            data_out_int     <= data_out_int_din;
            error_int        <= error_int_din;
            rd_err_int       <= rd_err_int_din;
            code_err_int     <= code_err_int_din;
            k_char_int       <= k_char_int_din;
            rd_err_bus_int   <= error_rd;
            code_err_bus_int <= error_code;
            rd_int           <= rd_int_din;
        end
    end
end else begin :                   GEN_async_em_ne_0
    always @ (posedge clk or negedge rst_n) begin : mk_registers_a_PROC
        if (rst_n == 1'b0) begin
            data_out_int     <= {BYTES*8{1'b0}};
            error_int        <= 1'b0;
            rd_err_int       <= 1'b0;
            code_err_int     <= 1'b0;
            k_char_int       <= {BYTES{1'b0}};
            rd_err_bus_int   <= {BYTES{1'b0}};
            code_err_bus_int <= {BYTES{1'b0}};
            rd_int           <= 1'b0;
        end else begin
          if (enable == 1'b1) begin
            data_out_int     <= data_out_int_din;
            error_int        <= error_int_din;
            rd_err_int       <= rd_err_int_din;
            code_err_int     <= code_err_int_din;
            k_char_int       <= k_char_int_din;
            rd_err_bus_int   <= error_rd;
            code_err_bus_int <= error_code;
            rd_int           <= rd_int_din;
          end
        end
    end
end endgenerate
`else
    always @ (posedge clk or negedge rst_n) begin : mk_registers_a_PROC
        if (rst_n == 1'b0) begin
            data_out_int     <= {BYTES*8{1'b0}};
            error_int        <= 1'b0;
            rd_err_int       <= 1'b0;
            code_err_int     <= 1'b0;
            k_char_int       <= {BYTES{1'b0}};
            rd_err_bus_int   <= {BYTES{1'b0}};
            code_err_bus_int <= {BYTES{1'b0}};
            rd_int           <= 1'b0;
        end else begin
          if (enable == 1'b1) begin
            data_out_int <= data_out_int_din;
            error_int    <= error_int_din;
            rd_err_int   <= rd_err_int_din;
            code_err_int <= code_err_int_din;
            k_char_int   <= k_char_int_din;
            rd_err_bus_int   <= error_rd;
            code_err_bus_int <= error_code;
            rd_int       <= rd_int_din;
          end
        end
          end
`endif
`else
    always @ (posedge clk or negedge rst_n) begin : mk_registers_a_PROC
        if (rst_n == 1'b0) begin
            data_out_int     <= {BYTES*8{1'b0}};
            error_int        <= 1'b0;
            rd_err_int       <= 1'b0;
            code_err_int     <= 1'b0;
            k_char_int       <= {BYTES{1'b0}};
            rd_err_bus_int   <= {BYTES{1'b0}};
            code_err_bus_int <= {BYTES{1'b0}};
            rd_int           <= 1'b0;
        end else begin
            data_out_int     <= data_out_int_din;
            error_int        <= error_int_din;
            rd_err_int       <= rd_err_int_din;
            code_err_int     <= code_err_int_din;
            k_char_int       <= k_char_int_din;
            rd_err_bus_int   <= error_rd;
            code_err_bus_int <= error_code;
            rd_int           <= rd_int_din;
        end
    end
`endif



endmodule
// reuse-pragma process_ifdef all_branches
