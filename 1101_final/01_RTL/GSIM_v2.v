// `timescale 1ns/100ps
module GSIM (                       //Don't modify interface
	input          i_clk,
	input          i_reset,
	input          i_module_en,
	input  [  4:0] i_matrix_num,
	output         o_proc_done,

	// matrix memory
	output         o_mem_rreq,
	output [  9:0] o_mem_addr,
	input          i_mem_rrdy,
	input  [255:0] i_mem_dout,
	input          i_mem_dout_vld,
	
	// output result
	output         o_x_wen,
	output [  8:0] o_x_addr,
	output [ 31:0] o_x_data  
);
/* GSIM Version 2
	COMB: 8 multipliers (high utilization rate)
	SEQ:  x_r[37x16], prev_x_r[37x16], abuf_r[16x7], x15_r[37x1], b15_r[16x1]
	always mem request
	early stop
*/

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
// state define
localparam S_IDLE        = 0;
localparam S_INIT        = 1;	// initialize for every different questions
localparam S_CALC_FIRST1 = 2;	// calculate first iteration's term 1
localparam S_CALC_FIRST2 = 3;	// calculate first iteration's term 2
localparam S_CALC_TERMS  = 4;	// calculate one term and minus it
localparam S_CALC_NEW    = 5;	// calculate new iter. value (+b, *(1/aii))
localparam S_ADDB        = 6;	// add bi to all x_reg, col_cnt_r is 16
localparam S_FINISH      = 7;	// assert o_proc_done until i_module_en == 0

// max and min
localparam MAX_32BITS = 32'h7FFF_FFFF;
localparam MIN_32BITS = 32'h8000_0000;

// output signal
reg o_proc_done_r, o_proc_done_w;
reg o_x_wen_r, o_x_wen_w;
reg [8:0]  o_x_addr_r, o_x_addr_w;
reg [31:0] o_x_data_r, o_x_data_w;


// control
reg [2:0] state_r, state_w;			// state
reg [4:0] mat_cnt_r, mat_cnt_w;     // counter of question number
reg [4:0] iter_cnt_r, iter_cnt_w;	// counter of iteration times
reg [4:0] col_cnt_r, col_cnt_w;		// counter of which col does it process

// storage
reg signed [36:0] x_r [0:15];				// array of x
reg signed [36:0] x_w [0:15];

// buffer
reg signed [15:0] abuf_r [0:6];
reg signed [15:0] abuf_w [0:6];
reg signed [36:0] x15_r, x15_w;
reg signed [15:0] b15_r, b15_w;

// buffer for early stop
reg signed [31:0] prev_x_r [0:15];
reg signed [31:0] prev_x_w [0:15];
reg 	   [15:0] eq_r, eq_w;
reg 			  earlyout_r, earlyout_w;

// multipiler & subtractor
reg signed  [15:0] multiplier_in1    [0:7]; // array of multiplier
reg signed  [31:0] multiplier_in2    [0:7];
reg signed  [47:0] multiplier_output [0:7];
reg signed  [36:0] subtractor_in1    [0:7]; // array of subtractor
reg signed  [31:0] subtractor_in2    [0:7];
reg signed  [37:0] subtractor_output [0:7];

// truncate and saturate
reg signed [47:0] truncated [0:8];			// truncated also means the saturator's input
reg signed [31:0] saturated [0:8];
reg signed [48:0] psum_49bits[0:15];		// for Lint	
reg [9:0]	addr_10bits;					// for Lint	

integer i;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------

// output signal
assign o_proc_done = o_proc_done_r;
assign o_mem_rreq  = 1;
assign o_mem_addr  = {mat_cnt_w, 4'b0} + mat_cnt_w + col_cnt_w;
assign o_x_wen     = o_x_wen_r;
assign o_x_addr    = o_x_addr_r;
assign o_x_data    = o_x_data_r;

// multiplier & subtractor
always @(*) begin
	for (i = 0; i < 8; i = i + 1) begin
		multiplier_output[i] = multiplier_in1[i]*multiplier_in2[i];
		subtractor_output[i] = subtractor_in1[i]-subtractor_in2[i];
	end
end

// saturator
always @(*) begin	
	for (i = 0; i < 9; i = i + 1) begin
		if (truncated[i][47] && ~(&truncated[i][47:31])) begin // negative overflow
			saturated[i] = $signed(MIN_32BITS);
		end
		else if (~truncated[i][47] && |truncated[i][47:31]) begin // positive overflow // 47:31(v) or 47:32?
			saturated[i] = $signed(MAX_32BITS);
		end
		else begin
			saturated[i] = $signed(truncated[i][31:0]);
		end
	end
end

// ---------------------------------------------------------------------------
// FSM
// ---------------------------------------------------------------------------
always @(*) begin
	state_w = state_r;
	case (state_r)
		S_IDLE: if (i_module_en) state_w = S_INIT;
		S_INIT: if (i_mem_dout_vld && !col_cnt_r) state_w = S_CALC_FIRST1; // after reading 1/a11~1/a1616 and b_row
		S_CALC_FIRST1: begin
			if (i_mem_dout_vld) begin
				if (col_cnt_r == 15)     state_w = S_ADDB;
				else if (col_cnt_r >= 9) state_w = S_CALC_FIRST2;
			end
		end
		S_CALC_FIRST2: if (i_mem_dout_vld) state_w = S_CALC_FIRST1;
		S_CALC_TERMS: begin
			if (i_mem_dout_vld) begin
				state_w = (col_cnt_r == 15) ? S_ADDB : S_CALC_NEW;
			end
		end
		S_CALC_NEW: begin
			if (i_mem_dout_vld) begin
				if ((iter_cnt_r == 16 || earlyout_r) && col_cnt_r == 15) begin
					if (mat_cnt_r == i_matrix_num - 1) state_w = S_FINISH;
					else 							   state_w = S_INIT; // next question
				end
				else begin
					state_w = S_CALC_TERMS;
				end
			end
		end
		S_ADDB:   if (i_mem_dout_vld) state_w = S_CALC_NEW;
		S_FINISH: if (!i_module_en) state_w = S_IDLE;
		// default: ;
	endcase
end

// ---------------------------------------------------------------------------
// Counter
// ---------------------------------------------------------------------------
always @(*) begin
	mat_cnt_w  = mat_cnt_r;
	iter_cnt_w = iter_cnt_r;
	col_cnt_w  = col_cnt_r;
	case (state_r)
		S_IDLE: begin
			mat_cnt_w  = 0;
			iter_cnt_w = 0;
			col_cnt_w  = (i_module_en) ? 5'd16 : 5'd0;
		end
		S_INIT: begin
			if (i_mem_dout_vld) begin
				if (!col_cnt_r) begin
					col_cnt_w = 1; // since starting from x[1] not x[0]
				end
				else begin
					col_cnt_w = col_cnt_r - 1;
				end
			end	
		end
		S_CALC_FIRST1: begin
			if (i_mem_dout_vld) begin
				if (col_cnt_r == 15 || col_cnt_r <= 8) begin
					col_cnt_w = col_cnt_r + 1;
				end
			end
		end
		S_CALC_FIRST2: col_cnt_w = col_cnt_r + 1;
		S_CALC_TERMS: begin
			if (i_mem_dout_vld) begin
				col_cnt_w = col_cnt_r + 1;
			end
		end
		S_CALC_NEW: begin
			if (i_mem_dout_vld) begin
				if ((iter_cnt_r == 16 || earlyout_r) && col_cnt_r == 15) begin
					iter_cnt_w = 0;
					col_cnt_w  = 5'd16;
					if (mat_cnt_r == i_matrix_num - 1) begin
						mat_cnt_w = 0;
						col_cnt_w = 0;
					end
					else begin
						mat_cnt_w = mat_cnt_r + 1;
					end
				end
			end
		end
		S_ADDB: begin
			if (i_mem_dout_vld) begin
				iter_cnt_w = iter_cnt_r + 1;
				col_cnt_w  = 0;
			end
		end
		S_FINISH: ;
		// default: ;
	endcase
end

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
always @(*) begin
	// for Lint
	if (i_mem_rrdy) begin
	end
	else begin
	end
	o_proc_done_w = 0;
	o_x_wen_w     = 0;
	o_x_addr_w	  = o_x_addr_r;
	o_x_data_w    = o_x_data_r;
	x15_w		  = x15_r;
	b15_w		  = b15_r;
	eq_w		  = eq_r;
	earlyout_w    = earlyout_r;
	for (i = 0; i < 16; i = i + 1) begin
		x_w[i]      = x_r[i];
		prev_x_w[i] = prev_x_r[i];
	end
	for (i = 0; i < 7; i = i + 1) begin
		abuf_w[i] = abuf_r[i];
	end
	for (i = 0; i < 8; i = i + 1) begin
		multiplier_in1[i] = 0;
		multiplier_in2[i] = 0;
	end
	for (i = 0; i < 8; i = i + 1) begin
		subtractor_in1[i] = 0;
		subtractor_in2[i] = 0;
	end
	for (i = 0; i < 8; i = i + 1) begin  // [truncator]
		truncated[i] = multiplier_output[i];
	end
	truncated[8] = 0;
	for (i = 0;i < 16;i = i + 1) begin
		psum_49bits[i] = 0;
	end
	case (state_r)
		S_IDLE: ;
		S_INIT: begin
			eq_w = 0;
			earlyout_w = 0;
			for (i = 0; i < 16; i = i + 1) begin
				prev_x_w[i] = 32'b0;
			end
			if (i_mem_dout_vld) begin
				if (col_cnt_r == 16) begin
					for (i = 0;i < 16;i = i + 1) begin
						x_w[i] = $signed({{21{i_mem_dout[16*i+15]}}, i_mem_dout[16*i +: 16]}); // b
					end
					// buffer b15
					b15_w = $signed(i_mem_dout[16*15 +: 16]);
				end
				else begin
					multiplier_in1[0] = $signed(i_mem_dout[16*col_cnt_r +: 16]); // 1/a
					multiplier_in2[0] = $signed(x_r[col_cnt_r][31:0]); // b
					// truncate (add 2 bits) and saturate
					truncated[0]      = $signed({multiplier_output[0][45:0], 2'b0});
					x_w[col_cnt_r]    = (|col_cnt_r) ? $signed({{5{saturated[0][31]}}, saturated[0]}) : $signed(37'b0); // b/a
				end
			end
		end
		S_CALC_FIRST1: begin
			if (i_mem_dout_vld) begin
				for (i = 0;i < 8;i = i + 1) begin
					if (i < col_cnt_r) begin
						multiplier_in1[i] = $signed(i_mem_dout[16*i +: 16]);
						multiplier_in2[i] = $signed(x_r[col_cnt_r][31:0]);
						subtractor_in1[i] = x_r[i];
						subtractor_in2[i] = saturated[i];
						x_w[i] 			  = $signed(subtractor_output[i][36:0]);
					end
				end
				if (col_cnt_r <= 8) begin
					x_w[col_cnt_r] = $signed(37'b0); // reset zero
				end
				else begin
					// buffer
					if (col_cnt_r == 15) begin
						x15_w = x_r[15];
					end
					for (i = 0;i < 7;i = i + 1) begin
						if (i < col_cnt_r - 8) begin
							abuf_w[i] = $signed(i_mem_dout[16*(i+8) +: 16]);
						end
					end
				end
			end
		end
		S_CALC_FIRST2: begin
			if (i_mem_dout_vld) begin
				// col_cnt_r is bigger than 8
				x_w[col_cnt_r] = $signed(37'b0); // reset zero
				for (i = 0;i < 7;i = i + 1) begin
					if (i < col_cnt_r - 8) begin
						multiplier_in1[i] = $signed(abuf_r[i]);
						multiplier_in2[i] = $signed(x_r[col_cnt_r][31:0]);
						subtractor_in1[i] = x_r[i + 8];
						subtractor_in2[i] = saturated[i];
						x_w[i + 8] 		  = $signed(subtractor_output[i][36:0]);
					end
				end
			end
		end
		S_CALC_TERMS: begin
			if (i_mem_dout_vld) begin
				// for early stop
				prev_x_w[col_cnt_r] = x_r[col_cnt_r][31:0];
				eq_w[col_cnt_r]     = (prev_x_r[col_cnt_r] == x_r[col_cnt_r][31:0]);
				for (i = 0;i < 8;i = i + 1) begin 
					multiplier_in2[i] = $signed(x_r[col_cnt_r][31:0]);
				end
				case (col_cnt_r)
					0: begin
						// multiplication
						for (i = 1;i <= 8;i = i + 1) begin // 1~8 to 0~7 mul
							multiplier_in1[i - 1] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 1] = x_r[i];
							subtractor_in2[i - 1] = saturated[i - 1];
							if (i == 1) begin // (only x1 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 1][36:0]);
						end
						// buffer
						for (i = 9;i <= 15;i = i + 1) begin // 9~15 to 0~6 abuf
							abuf_w[i - 9] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					1: begin
						// multiplication
						for (i = 2;i <= 9;i = i + 1) begin // 2~9 to 0~7 mul
							multiplier_in1[i - 2] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 2] = x_r[i];
							subtractor_in2[i - 2] = saturated[i - 2];
							if (i == 2) begin // (only x2 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 2][36:0]);
						end
						// buffer
						abuf_w[6] = $signed(i_mem_dout[16*0 +: 16]);
						for (i = 10;i <= 15;i = i + 1) begin // 10~15, 0 to 0~6 abuf
							abuf_w[i - 10] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					2: begin
						// multiplication
						for (i = 3;i <= 10;i = i + 1) begin // 3~10 to 0~7 mul
							multiplier_in1[i - 3] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 3] = x_r[i];
							subtractor_in2[i - 3] = saturated[i - 3];
							if (i == 3) begin // (only x3 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 3][36:0]);
						end
						// buffer
						abuf_w[5] = $signed(i_mem_dout[16*0 +: 16]);
						abuf_w[6] = $signed(i_mem_dout[16*1 +: 16]);
						for (i = 11;i <= 15;i = i + 1) begin // 11~15, 0, 1 to 0~6 abuf
							abuf_w[i - 11] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					3: begin
						// multiplication
						for (i = 4;i <= 11;i = i + 1) begin // 4~11 to 0~7 mul
							multiplier_in1[i - 4] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 4] = x_r[i];
							subtractor_in2[i - 4] = saturated[i - 4];
							if (i == 4) begin // (only x4 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 4][36:0]);
						end
						// buffer
						abuf_w[4] = $signed(i_mem_dout[16*0 +: 16]);
						abuf_w[5] = $signed(i_mem_dout[16*1 +: 16]);
						abuf_w[6] = $signed(i_mem_dout[16*2 +: 16]);
						for (i = 12;i <= 15;i = i + 1) begin // 12~15, 0, 1, 2 to 0~6 abuf
							abuf_w[i - 12] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					4: begin
						// multiplication
						for (i = 5;i <= 12;i = i + 1) begin // 5~12 to 0~7 mul
							multiplier_in1[i - 5] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 5] = x_r[i];
							subtractor_in2[i - 5] = saturated[i - 5];
							if (i == 5) begin // (only x5 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 5][36:0]);
						end
						// buffer
						abuf_w[0] = $signed(i_mem_dout[16*13 +: 16]);
						abuf_w[1] = $signed(i_mem_dout[16*14 +: 16]);
						abuf_w[2] = $signed(i_mem_dout[16*15 +: 16]);
						for (i = 0;i <= 3;i = i + 1) begin // 13, 14, 15, 0~3 to 0~6 abuf
							abuf_w[i + 3] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					5: begin
						// multiplication
						for (i = 6;i <= 13;i = i + 1) begin // 6~13 to 0~7 mul
							multiplier_in1[i - 6] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 6] = x_r[i];
							subtractor_in2[i - 6] = saturated[i - 6];
							if (i == 6) begin // (only x6 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 6][36:0]);
						end
						// buffer
						abuf_w[0] = $signed(i_mem_dout[16*14 +: 16]);
						abuf_w[1] = $signed(i_mem_dout[16*15 +: 16]);
						for (i = 0;i <= 4;i = i + 1) begin // 14, 15, 0~4 to 0~6 abuf
							abuf_w[i + 2] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					6: begin
						// multiplication
						for (i = 7;i <= 14;i = i + 1) begin // 7~14 to 0~7 mul
							multiplier_in1[i - 7] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 7] = x_r[i];
							subtractor_in2[i - 7] = saturated[i - 7];
							if (i == 7) begin // (only x7 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 7][36:0]);
						end
						// buffer
						abuf_w[0] = $signed(i_mem_dout[16*15 +: 16]);
						for (i = 0;i <= 5;i = i + 1) begin // 15, 0~5 to 0~6 abuf
							abuf_w[i + 1] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					7: begin
						// multiplication
						for (i = 8;i <= 15;i = i + 1) begin // 8~15 to 0~7 mul
							multiplier_in1[i - 8] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 8] = x_r[i];
							subtractor_in2[i - 8] = saturated[i - 8];
							if (i == 8) begin // (only x8 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 8][36:0]);
						end
						// buffer
						for (i = 0;i <= 6;i = i + 1) begin // 0~6 to 0~6 abuf
							abuf_w[i] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					8: begin
						// multiplication
						multiplier_in1[7] = $signed(i_mem_dout[16*0 +: 16]);
						subtractor_in1[7] = x_r[0];
						subtractor_in2[7] = saturated[7];
						x_w[0] 			  = $signed(subtractor_output[7][36:0]);
						for (i = 9;i <= 15;i = i + 1) begin // 9~15, 0 to 0~7 mul
							multiplier_in1[i - 9] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 9] = x_r[i];
							subtractor_in2[i - 9] = saturated[i - 9];
							if (i == 9) begin // (only x9 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 9][36:0]);
						end
						// buffer
						for (i = 1;i <= 7;i = i + 1) begin // 1~7 to 0~6 abuf
							abuf_w[i - 1] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					9: begin
						// multiplication
						multiplier_in1[6] = $signed(i_mem_dout[16*0 +: 16]);
						subtractor_in1[6] = x_r[0];
						subtractor_in2[6] = saturated[6];
						x_w[0] 			  = $signed(subtractor_output[6][36:0]);
						multiplier_in1[7] = $signed(i_mem_dout[16*1 +: 16]);
						subtractor_in1[7] = x_r[1];
						subtractor_in2[7] = saturated[7];
						x_w[1] 			  = $signed(subtractor_output[7][36:0]);
						for (i = 10;i <= 15;i = i + 1) begin // 10~15, 0, 1 to 0~7 mul
							multiplier_in1[i - 10] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 10] = x_r[i];
							subtractor_in2[i - 10] = saturated[i - 10];
							if (i == 10) begin // (only x10 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 10][36:0]);
						end
						// buffer
						for (i = 2;i <= 8;i = i + 1) begin // 2~8 to 0~6 abuf
							abuf_w[i - 2] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					10: begin
						// multiplication
						multiplier_in1[5] = $signed(i_mem_dout[16*0 +: 16]);
						subtractor_in1[5] = x_r[0];
						subtractor_in2[5] = saturated[5];
						x_w[0] 			  = $signed(subtractor_output[5][36:0]);
						multiplier_in1[6] = $signed(i_mem_dout[16*1 +: 16]);
						subtractor_in1[6] = x_r[1];
						subtractor_in2[6] = saturated[6];
						x_w[1] 			  = $signed(subtractor_output[6][36:0]);
						multiplier_in1[7] = $signed(i_mem_dout[16*2 +: 16]);
						subtractor_in1[7] = x_r[2];
						subtractor_in2[7] = saturated[7];
						x_w[2] 			  = $signed(subtractor_output[7][36:0]);
						for (i = 11;i <= 15;i = i + 1) begin // 11~15, 0, 1, 2 to 0~7 mul
							multiplier_in1[i - 11] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 11] = x_r[i];
							subtractor_in2[i - 11] = saturated[i - 11];
							if (i == 11) begin // (only x11 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 11][36:0]);
						end
						// buffer
						for (i = 3;i <= 9;i = i + 1) begin // 3~9 to 0~6 abuf
							abuf_w[i - 3] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					11: begin
						// multiplication
						for (i = 0;i <= 3;i = i + 1) begin // 12~15, 0~3 to 0~7 mul
							multiplier_in1[i + 4] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i + 4] = x_r[i];
							subtractor_in2[i + 4] = saturated[i + 4];
							x_w[i] 			  	  = $signed(subtractor_output[i + 4][36:0]);
						end
						for (i = 12;i <= 15;i = i + 1) begin
							multiplier_in1[i - 12] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i - 12] = x_r[i];
							subtractor_in2[i - 12] = saturated[i - 12];
							if (i == 12) begin // (only x12 need truncate and saturate after subtract)
								truncated[8] = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
								x_w[i] 	     = $signed({{5{saturated[8][31]}}, saturated[8]});
							end
							else x_w[i] = $signed(subtractor_output[i - 12][36:0]);
						end
						// buffer
						for (i = 4;i <= 10;i = i + 1) begin // 4~10 to 0~6 abuf
							abuf_w[i - 4] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					12: begin
						// multiplication
						multiplier_in1[0] = $signed(i_mem_dout[16*13 +: 16]);
						subtractor_in1[0] = x_r[13];
						subtractor_in2[0] = saturated[0];
						// (only x13 need truncate and saturate after subtract)
						truncated[8]      = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
						x_w[13] 		  = $signed({{5{saturated[8][31]}}, saturated[8]});
						multiplier_in1[1] = $signed(i_mem_dout[16*14 +: 16]);
						subtractor_in1[1] = x_r[14];
						subtractor_in2[1] = saturated[1];
						x_w[14] 		  = $signed(subtractor_output[1][36:0]);
						multiplier_in1[2] = $signed(i_mem_dout[16*15 +: 16]);
						subtractor_in1[2] = x_r[15];
						subtractor_in2[2] = saturated[2];
						x_w[15] 		  = $signed(subtractor_output[2][36:0]);
						for (i = 0;i <= 4;i = i + 1) begin // 13, 14, 15, 0~4 to 0~7 mul
							multiplier_in1[i + 3] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i + 3] = x_r[i];
							subtractor_in2[i + 3] = saturated[i + 3];
							x_w[i] 			  	  = $signed(subtractor_output[i + 3][36:0]);
						end
						// buffer
						for (i = 5;i <= 11;i = i + 1) begin // 5~11 to 0~6 abuf
							abuf_w[i - 5] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					13: begin
						// multiplication
						multiplier_in1[0] = $signed(i_mem_dout[16*14 +: 16]);
						subtractor_in1[0] = x_r[14];
						subtractor_in2[0] = saturated[0];
						// (only x14 need truncate and saturate after subtract)
						truncated[8]      = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
						x_w[14] 		  = $signed({{5{saturated[8][31]}}, saturated[8]});
						multiplier_in1[1] = $signed(i_mem_dout[16*15 +: 16]);
						subtractor_in1[1] = x_r[15];
						subtractor_in2[1] = saturated[1];
						x_w[15] 		  = $signed(subtractor_output[1][36:0]);
						for (i = 0;i <= 5;i = i + 1) begin // 14, 15, 0~5 to 0~7 mul
							multiplier_in1[i + 2] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i + 2] = x_r[i];
							subtractor_in2[i + 2] = saturated[i + 2];
							x_w[i] 			  	  = $signed(subtractor_output[i + 2][36:0]);
						end
						// buffer
						for (i = 6;i <= 12;i = i + 1) begin // 6~12 to 0~6 abuf
							abuf_w[i - 6] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					14: begin
						// multiplication
						multiplier_in1[0] = $signed(i_mem_dout[16*15 +: 16]);
						subtractor_in1[0] = x_r[15];
						subtractor_in2[0] = saturated[0];
						// (only x15 need truncate and saturate after subtract)
						truncated[8]      = $signed({{10{subtractor_output[0][37]}}, subtractor_output[0]});
						x_w[15] 		  = $signed({{5{saturated[8][31]}}, saturated[8]});
						for (i = 0;i <= 6;i = i + 1) begin // 15, 0~6 to 0~7 mul
							multiplier_in1[i + 1] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i + 1] = x_r[i];
							subtractor_in2[i + 1] = saturated[i + 1];
							x_w[i] 			  	  = $signed(subtractor_output[i + 1][36:0]);
						end
						// buffer
						for (i = 7;i <= 13;i = i + 1) begin // 7~13 to 0~6 abuf
							abuf_w[i - 7] = $signed(i_mem_dout[16*i +: 16]);
						end
					end
					15: begin
						for (i = 0;i <= 7;i = i + 1) begin // 0~7 to 0~7 mul
							multiplier_in1[i] = $signed(i_mem_dout[16*i +: 16]);
							subtractor_in1[i] = x_r[i];
							subtractor_in2[i] = saturated[i];
							x_w[i] 			  = $signed(subtractor_output[i][36:0]);
						end
						// buffer
						for (i = 8;i <= 14;i = i + 1) begin // 8~14 to 0~6 abuf
							abuf_w[i - 8] = $signed(i_mem_dout[16*i +: 16]);
						end
						// buffer x15
						x15_w = x_r[15];
					end
					// default: ;
				endcase
			end
		end
		S_CALC_NEW: begin
			if (i_mem_dout_vld) begin
				// reset zero
				if (|col_cnt_r) begin
					x_w[col_cnt_r - 1] = $signed(37'b0);
				end
				else begin
					x_w[15] = $signed({{5{b15_r[15]}}, b15_r, 16'b0}); // reset x15 to b15
				end
				// multiply 1/a
				multiplier_in1[7] = $signed(i_mem_dout[16*col_cnt_r +: 16]); // 1/a
				multiplier_in2[7] = $signed(x_r[col_cnt_r][31:0]);
				// truncate and saturate
				truncated[7] 	  = {{14{multiplier_output[7][47]}}, multiplier_output[7][47:14]};
				x_w[col_cnt_r]    = $signed({{5{saturated[7][31]}}, saturated[7]}); // (final x)/a
				// output
				earlyout_w = (!col_cnt_r && &eq_r) || earlyout_r;
				if (iter_cnt_r == 16 || (!col_cnt_r && &eq_r) || earlyout_r) begin
					o_x_wen_w   = 1;
					addr_10bits = {mat_cnt_r, 4'b0} + col_cnt_r;
					o_x_addr_w  = addr_10bits[8:0];
					o_x_data_w  = saturated[7];
				end
				// buffer multiplication
				for (i = 0;i < 7;i = i + 1) begin
					multiplier_in1[i] = $signed(abuf_r[i]);
					multiplier_in2[i] = (|col_cnt_r) ? $signed(x_r[col_cnt_r - 1][31:0]) : $signed(x15_r[31:0]); // from buffer or not
				end
				case (col_cnt_r)
					0: begin
						for (i = 8;i <= 14;i = i + 1) begin
							subtractor_in1[i - 8] = x_r[i];
							subtractor_in2[i - 8] = saturated[i - 8];
							x_w[i]      = $signed(subtractor_output[i - 8][36:0]); // 0~6 to 8~14
						end
					end
					1: begin
						for (i = 9;i <= 15;i = i + 1) begin
							subtractor_in1[i - 9] = x_r[i];
							subtractor_in2[i - 9] = saturated[i - 9];
							x_w[i]      = $signed(subtractor_output[i - 9][36:0]); // 0~6 to 9~15
						end
					end
					2: begin
						subtractor_in1[6] = x_r[0];
						subtractor_in2[6] = saturated[6];
						x_w[0]  = $signed(subtractor_output[6][36:0]);
						for (i = 10;i <= 15;i = i + 1) begin
							subtractor_in1[i - 10] = x_r[i];
							subtractor_in2[i - 10] = saturated[i - 10];
							x_w[i]       = $signed(subtractor_output[i - 10][36:0]); // 0~6 to 10~15, 0
						end
					end
					3: begin
						subtractor_in1[5] = x_r[0];
						subtractor_in2[5] = saturated[5];
						x_w[0]  = $signed(subtractor_output[5][36:0]);
						subtractor_in1[6] = x_r[1];
						subtractor_in2[6] = saturated[6];
						x_w[1]  = $signed(subtractor_output[6][36:0]);
						for (i = 11;i <= 15;i = i + 1) begin
							subtractor_in1[i - 11] = x_r[i];
							subtractor_in2[i - 11] = saturated[i - 11];
							x_w[i]       = $signed(subtractor_output[i - 11][36:0]); // 0~6 to 11~15, 0, 1
						end
					end
					4: begin
						subtractor_in1[4] = x_r[0];
						subtractor_in2[4] = saturated[4];
						x_w[0] = $signed(subtractor_output[4][36:0]);
						subtractor_in1[5] = x_r[1];
						subtractor_in2[5] = saturated[5];
						x_w[1] = $signed(subtractor_output[5][36:0]);
						subtractor_in1[6] = x_r[2];
						subtractor_in2[6] = saturated[6];
						x_w[2] = $signed(subtractor_output[6][36:0]);
						for (i = 12;i <= 15;i = i + 1) begin
							subtractor_in1[i - 12] = x_r[i];
							subtractor_in2[i - 12] = saturated[i - 12];
							x_w[i]       = $signed(subtractor_output[i - 12][36:0]); // 0~6 to 12~15, 0, 1, 2
						end
					end
					5: begin
						subtractor_in1[0] = x_r[13];
						subtractor_in2[0] = saturated[0];
						x_w[13] = $signed(subtractor_output[0][36:0]);
						subtractor_in1[1] = x_r[14];
						subtractor_in2[1] = saturated[1];
						x_w[14] = $signed(subtractor_output[1][36:0]);
						subtractor_in1[2] = x_r[15];
						subtractor_in2[2] = saturated[2];
						x_w[15] = $signed(subtractor_output[2][36:0]);
						for (i = 0;i <= 3;i = i + 1) begin
							subtractor_in1[i + 3] = x_r[i];
							subtractor_in2[i + 3] = saturated[i + 3];
							x_w[i]      = $signed(subtractor_output[i + 3][36:0]); // 0~6 to 13, 14, 15, 0~3
						end
					end
					6: begin
						subtractor_in1[0] = x_r[14];
						subtractor_in2[0] = saturated[0];
						x_w[14] = $signed(subtractor_output[0][36:0]);
						subtractor_in1[1] = x_r[15];
						subtractor_in2[1] = saturated[1];
						x_w[15] = $signed(subtractor_output[1][36:0]);
						for (i = 0;i <= 4;i = i + 1) begin
							subtractor_in1[i + 2] = x_r[i];
							subtractor_in2[i + 2] = saturated[i + 2];
							x_w[i]      = $signed(subtractor_output[i + 2][36:0]); // 0~6 to 14, 15, 0~4
						end
					end
					7: begin
						subtractor_in1[0] = x_r[15];
						subtractor_in2[0] = saturated[0];
						x_w[15] = $signed(subtractor_output[0][36:0]);
						for (i = 0;i <= 5;i = i + 1) begin
							subtractor_in1[i + 1] = x_r[i];
							subtractor_in2[i + 1] = saturated[i + 1];
							x_w[i]      = $signed(subtractor_output[i + 1][36:0]); // 0~6 to 15, 0~5
						end
					end
					8: begin
						for (i = 0;i <= 6;i = i + 1) begin
							subtractor_in1[i] = x_r[i];
							subtractor_in2[i] = saturated[i];
							x_w[i]  = $signed(subtractor_output[i][36:0]); // 0~6 to 0~6
						end
					end
					9: begin
						for (i = 1;i <= 7;i = i + 1) begin
							subtractor_in1[i - 1] = x_r[i];
							subtractor_in2[i - 1] = saturated[i - 1];
							x_w[i]      = $signed(subtractor_output[i - 1][36:0]); // 0~6 to 1~7
						end
					end
					10: begin
						for (i = 2;i <= 8;i = i + 1) begin
							subtractor_in1[i - 2] = x_r[i];
							subtractor_in2[i - 2] = saturated[i - 2];
							x_w[i]      = $signed(subtractor_output[i - 2][36:0]); // 0~6 to 2~8
						end
					end
					11: begin
						for (i = 3;i <= 9;i = i + 1) begin
							subtractor_in1[i - 3] = x_r[i];
							subtractor_in2[i - 3] = saturated[i - 3];
							x_w[i]      = $signed(subtractor_output[i - 3][36:0]); // 0~6 to 3~9
						end
					end
					12: begin
						for (i = 4;i <= 10;i = i + 1) begin
							subtractor_in1[i - 4] = x_r[i];
							subtractor_in2[i - 4] = saturated[i - 4];
							x_w[i]      = $signed(subtractor_output[i - 4][36:0]); // 0~6 to 4~10
						end
					end
					13: begin
						for (i = 5;i <= 11;i = i + 1) begin
							subtractor_in1[i - 5] = x_r[i];
							subtractor_in2[i - 5] = saturated[i - 5];
							x_w[i]      = $signed(subtractor_output[i - 5][36:0]); // 0~6 to 5~11
						end
					end
					14: begin
						for (i = 6;i <= 12;i = i + 1) begin
							subtractor_in1[i - 6] = x_r[i];
							subtractor_in2[i - 6] = saturated[i - 6];
							x_w[i]      = $signed(subtractor_output[i - 6][36:0]); // 0~6 to 6~12
						end
					end
					15: begin
						for (i = 7;i <= 13;i = i + 1) begin
							subtractor_in1[i - 7] = x_r[i];
							subtractor_in2[i - 7] = saturated[i - 7];
							x_w[i]      = $signed(subtractor_output[i - 7][36:0]); // 0~6 to 7~13
						end
					end
					// default: ;
				endcase
			end
		end
		S_ADDB: begin
			if (i_mem_dout_vld) begin
				// truncate and saturate only x0 (b is the last added to x0)
				psum_49bits[0] = x_r[0] + $signed({{16{i_mem_dout[16*0+15]}}, i_mem_dout[16*0 +: 16], 16'b0});
				truncated[0]   = $signed(psum_49bits[0][47:0]);
				x_w[0]		   = $signed({{5{saturated[0][31]}}, saturated[0]});
				for (i = 1;i < 16;i = i + 1) begin
					psum_49bits[i] = x_r[i] + $signed({{16{i_mem_dout[16*i+15]}}, i_mem_dout[16*i +: 16], 16'b0});
					x_w[i]		   = $signed(psum_49bits[i][36:0]);
				end
			end
		end
		S_FINISH: o_proc_done_w = i_module_en;
		// default: ;
	endcase
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
always @(posedge i_clk or posedge i_reset) begin
	if (i_reset) begin
		o_proc_done_r 	<= 0;
		o_x_wen_r 		<= 0;
		o_x_addr_r		<= 0;
		o_x_data_r 		<= 0;
		state_r 		<= S_IDLE;
		mat_cnt_r       <= 0;
		iter_cnt_r 		<= 0;
		col_cnt_r 		<= 0;
		x15_r			<= 0;
		b15_r			<= 0;
		eq_r			<= 0;
		earlyout_r 		<= 0;
		for (i = 0; i < 16; i = i + 1) begin
			x_r[i] 		<= 37'b0;
			prev_x_r[i] <= 32'b0;
		end
		for (i = 0; i < 7; i = i + 1) begin
			abuf_r[i]   <= 0;
		end
	end
	else begin
		o_proc_done_r 	<= o_proc_done_w;
		o_x_wen_r 		<= o_x_wen_w;
		o_x_addr_r		<= o_x_addr_w;
		o_x_data_r 		<= o_x_data_w;
		state_r 		<= state_w;
		mat_cnt_r       <= mat_cnt_w;
		iter_cnt_r 		<= iter_cnt_w;
		col_cnt_r 		<= col_cnt_w;
		x15_r			<= x15_w;
		b15_r			<= b15_w;
		eq_r			<= eq_w;
		earlyout_r 		<= earlyout_w;
		for (i = 0; i < 16; i = i + 1) begin
			x_r[i] 		<= x_w[i];
			prev_x_r[i] <= prev_x_w[i];
		end
		for (i = 0; i < 7; i = i + 1) begin
			abuf_r[i]   <= abuf_w[i];
		end
	end
end

endmodule
