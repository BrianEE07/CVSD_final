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
reg [4:0] mat_cnt_r, mat_cnt_w;     // counter of quetion number
reg [3:0] iter_cnt_r, iter_cnt_w;	// counter of iteration times
reg [4:0] col_cnt_r, col_cnt_w;		// counter of which col does it process 

// storage
reg signed [36:0] x_r [0:15];				// array of x
reg signed [36:0] x_w [0:15];
reg signed [15:0] b_r [0:15];
reg signed [15:0] b_w [0:15];				// array of b

// multipiler
reg signed [15:0] multiplier_in1 [0:14];	// array of multiplier
reg signed [31:0] multpilier_in2 [0:14];
wire signed [47:0] multiplier_output [0:14];

integer i;

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
for (i = 0; i < 15; i = i + 1) begin
	assign multiplier_output[i] = multiplier_in1[i]*multpilier_in2[i];
end

// ---------------------------------------------------------------------------
// FSM
// ---------------------------------------------------------------------------
always @(*) begin
	state_w = state_r;
	case (state_r)
		S_IDLE: begin
			if (i_module_en) state_w = S_INIT;
		end
		S_INIT: begin
			// after reading 1/a11~1/a1616 and b_row
			if (i_mem_dout_vld && col_cnt_r == 16) state_w = S_CALC_TERMS;
		end
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
		S_FINISH: begin
			if (!i_module_en) state_w = S_IDLE;
		end
		default: ;
	endcase
end

// ---------------------------------------------------------------------------
// Counter
// ---------------------------------------------------------------------------
always @(*) begin
	mat_cnt_w = mat_cnt_r;
	iter_cnt_w = iter_cnt_r;
	col_cnt_w = col_cnt_r;
	case (state_r)
		S_IDLE: begin
			mat_cnt_w  = 0;
			iter_cnt_w = 0;
			col_cnt_w  = 0;
		end
		S_INIT: begin
			if (i_mem_dout_vld) begin
				if (col_cnt_r == 16) begin
					col_cnt_w = 1; // since starting from x2
				end
				else begin
					col_cnt_w = col_cnt_r + 1;
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
		default: 
	endcase
end

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
always @(*) begin
	o_proc_done_w = 0;
	o_mem_rreq_w  = o_mem_rreq_r;
	o_x_wen_w     = 0;
	o_x_data_w    = o_x_data_r;
	for (i = 0; i < 16; i = i + 1) begin
		x_w[i] = x_r[i];
		b_w[i] = b_r[i];
	end
	case (state_r)
		S_IDLE: ;
		S_INIT: begin
			
		end
		// S_WAIT: begin
			
		// end
		S_CALC_TERMS: begin
			
		end
		S_CALC_NEW: begin
			
		end
		// S_OUTPUT: begin
			
		// end
		S_FINISH: begin
			o_proc_done_w = i_module_en;
		end
		default: 
	endcase
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
always @(posedge i_clk or posedge i_rst) begin
	if (i_rst) begin
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
