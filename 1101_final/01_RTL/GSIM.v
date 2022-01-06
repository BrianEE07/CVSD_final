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

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
// state define
localparam S_IDLE = 0;
localparam S_INIT = 1;			// initialize for every different questions
// localparam S_WAIT = 2;			// wait for memory
localparam S_CALC_TERMS = 3;	// calculate one term and minus it
localparam S_CALC_NEW = 4;		// calculate new iter. value (+b, *(1/aii))
// localparam S_OUTPUT = 5;		// write the result to output memory
localparam S_FINISH = 6;		// assert o_proc_done until i_module_en == 0

// output signal
reg o_proc_done_r, o_proc_done_w;
reg o_mem_rreq_r, o_mem_rreq_w;
reg o_x_wen_r, o_x_wen_w;
reg [31:0] o_x_data_r, o_x_data_w;


// control
reg [2:0] state_r, state_w;			// state
reg [4:0] mat_cnt_r, mat_cnt_w;     // counter of question number
reg [3:0] iter_cnt_r, iter_cnt_w;	// counter of iteration times
reg [4:0] col_cnt_r, col_cnt_w;		// counter of which col does it process 

// storage
reg signed [36:0] x_r [0:15];				// array of x
reg signed [36:0] x_w [0:15];
reg signed [15:0] b_r [0:15];
reg signed [15:0] b_w [0:15];				// array of b

// multipiler
reg signed [15:0] multiplier_in1 [0:14];	// array of multiplier
reg signed [31:0] multiplier_in2 [0:14];
wire signed [47:0] multiplier_output [0:14];
reg signed [15:0] trunturated4term [0:14];
reg signed [15:0] trunturated4sum;
reg signed [15:0] trunturated4new;

integer i;
genvar j;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------

// output signal
assign o_proc_done = o_proc_done_r;
assign o_mem_rreq  = o_mem_rreq_r;
assign o_mem_addr  = 17*mat_cnt_r + col_cnt_r;
assign o_x_wen     = o_x_wen_r;
assign o_x_addr    = {mat_cnt_r, 4'b0} + col_cnt_r;
assign o_x_data    = o_x_data_r;

// multipiler
generate
	for (j = 0; j < 15; j = j + 1) begin: multipiler_array
		assign multiplier_output[j] = multiplier_in1[j]*multiplier_in2[j];
	end
endgenerate

// ---------------------------------------------------------------------------
// saturator and truncator
// ---------------------------------------------------------------------------
// always @(*) begin
// 	trunturated4new = 0;
// 	trunturated4term = 0;
// end
// ---------------------------------------------------------------------------
// FSM
// ---------------------------------------------------------------------------
always @(*) begin
	state_w = state_r;
	case (state_r)
		S_IDLE: if (i_module_en) state_w = S_INIT;
		S_INIT: if (i_mem_dout_vld && !col_cnt_r) state_w = S_CALC_TERMS; // after reading 1/a11~1/a1616 and b_row
		// S_WAIT: begin
			
		// end
		S_CALC_TERMS: begin
			// when iter=0, first 15 cycles(x2~x16) needed for calc_term
			// else, calc_term & calc_new take turns every 1 cycle (after read success)
			if (i_mem_dout_vld) begin
				if (iter_cnt_r || (!iter_cnt_r && col_cnt_r == 15)) begin
					state_w = S_CALC_NEW;
				end
			end
		end
		S_CALC_NEW: begin
			// stay at this state for only 1 cycle (after read success) for sure
			if (i_mem_dout_vld) begin
				if (iter_cnt_r == 15 && col_cnt_r == 15) begin
					if (mat_cnt_r == i_matrix_num - 1) state_w = S_FINISH;
					else 							   state_w = S_INIT; // next question
				end
				else begin
					state_w = S_CALC_TERMS;
				end
			end
		end
		// S_OUTPUT: begin
			
		// end
		S_FINISH: if (!i_module_en) state_w = S_IDLE;
		default: ;
	endcase
end

// ---------------------------------------------------------------------------
// Counter
// ---------------------------------------------------------------------------
// [TODO] We should change counter updating stategy, because it will stall 1 cycle now => handshaking
always @(*) begin
	mat_cnt_w = mat_cnt_r;
	iter_cnt_w = iter_cnt_r;
	col_cnt_w = col_cnt_r;
	case (state_r)
		S_IDLE: begin
			mat_cnt_w  = 0;
			iter_cnt_w = 0;
			col_cnt_w  = (i_module_en) ? 5'd16 : 5'd0;
		end
		S_INIT: begin
			if (i_mem_dout_vld) begin
				if (!col_cnt_r) begin
					col_cnt_w = 1; // since starting from x2
				end
				else begin
					col_cnt_w = col_cnt_r - 1;
				end
			end	
		end
		// S_WAIT: begin
			
		// end
		S_CALC_TERMS: begin
			if (i_mem_dout_vld) begin
				if (col_cnt_r == 15) begin
					iter_cnt_w = iter_cnt_r + 1;
					col_cnt_w  = 0;
				end
				else begin
					col_cnt_w = col_cnt_r + 1;
				end
			end
		end
		S_CALC_NEW: begin
			if (i_mem_dout_vld) begin
				if (iter_cnt_r == 15 && col_cnt_r == 15) begin
					iter_cnt_w = 0;
					col_cnt_w  = 0;
					if (mat_cnt_r == i_matrix_num - 1) begin
						mat_cnt_w = 0;
					end
					else begin
						mat_cnt_w = mat_cnt_r + 1;
					end
				end
			end
		end
		// S_OUTPUT: begin
			
		// end
		S_FINISH: ;
		default: ;
	endcase
end

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
always @(*) begin
	// TODO
	// mem_rreq control
	o_proc_done_w = 0;
	o_mem_rreq_w  = o_mem_rreq_r;
	o_x_wen_w     = 0;
	o_x_data_w    = o_x_data_r;
	for (i = 0; i < 16; i = i + 1) begin
		x_w[i] = x_r[i];
		b_w[i] = b_r[i];
	end
	for (i = 0; i < 15; i = i + 1) begin
		multiplier_in1[i] = 0;
		multiplier_in2[i] = 0;
	end
	case (state_r)
		S_IDLE: ;
		S_INIT: begin
			if (i_mem_dout_vld) begin
				if (col_cnt_r == 16) begin
					for (i = 0;i < 16;i = i + 1) begin
						b_w[i] = i_mem_dout[16*i +: 16];
					end
				end
				else begin
					multiplier_in1[0] = i_mem_dout[16*col_cnt_r +: 16]; // 1/a
					multiplier_in2[0] = b_r[col_cnt_r];
					// [TODO]: Integer asymmetric saturation
					x_w[col_cnt_r]    = (col_cnt_r) ? multiplier_output[0] : 0; // b/a
				end
			end
		end
		// S_WAIT: begin
			
		// end
		S_CALC_TERMS: begin // [Important] We should think about what is the synthesis result.
			if (i_mem_dout_vld) begin
				// [TODO]: Integer asymmetric saturation
				for (i = 0;i < 16;i = i + 1) begin
					if (i == col_cnt_r) begin // reset zero
						x_w[i] = 0;
					end
					else if (i < col_cnt_r) begin
						multiplier_in1[i] = i_mem_dout[16*i +: 16];
						multiplier_in2[i] = x_r[col_cnt_r];
						x_w[i] 			  = x_r[i] - multiplier_output[i];
					end
					else if (i > col_cnt_r && iter_cnt_r) begin // first iteration skip this part
						multiplier_in1[i - 1] = i_mem_dout[16*i +: 16];
						multiplier_in2[i - 1] = x_r[col_cnt_r];
						x_w[i] 			      = x_r[i] - multiplier_output[i - 1];
					end
				end
			end
		end
		S_CALC_NEW: begin
			if (i_mem_dout_vld) begin
				multiplier_in1[0] = i_mem_dout[16*col_cnt_r +: 16]; // 1/a
				multiplier_in2[0] = x_r[col_cnt_r] + b_r[col_cnt_r];
				// [TODO]: Integer asymmetric saturation
				x_w[col_cnt_r]    = multiplier_output[0]; // (x+b)/a
				// [TODO]: Integer asymmetric saturation
				// [TODO]: Fractional truncation

				// output
				if (iter_cnt_r == 15) begin
					o_x_wen_w  = 1;
					o_x_data_w = multiplier_output[0];
				end
			end
		end
		// S_OUTPUT: begin
			
		// end
		S_FINISH: o_proc_done_w = i_module_en;
		default: ;
	endcase
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
always @(posedge i_clk or posedge i_reset) begin
	if (i_reset) begin
		o_proc_done_r 	<= 0;
		o_mem_rreq_r 	<= 0;
		o_x_wen_r 		<= 0;
		o_x_data_r 		<= 0;
		state_r 		<= S_IDLE;
		mat_cnt_r       <= 0;
		iter_cnt_r 		<= 0;
		col_cnt_r 		<= 0;
		for (i = 0; i < 16; i = i + 1) begin
			x_r[i] 		<= 0;
			b_r[i] 		<= 0;
		end
	end
	else begin
		o_proc_done_r 	<= o_proc_done_w;
		o_mem_rreq_r 	<= o_mem_rreq_w;
		o_x_wen_r 		<= o_x_wen_w;
		o_x_data_r 		<= o_x_data_w;
		state_r 		<= state_w;
		mat_cnt_r       <= mat_cnt_w;
		iter_cnt_r 		<= iter_cnt_w;
		col_cnt_r 		<= col_cnt_w;
		for (i = 0; i < 16; i = i + 1) begin
			x_r[i] 		<= x_w[i];
			b_r[i] 		<= b_w[i];
		end
	end
end

endmodule
