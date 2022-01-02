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
localparam S_WAIT = 2;			// wait for memory
localparam S_CALC_TERMS = 3;	// calculate one term and minus it
localparam S_CALC_NEW = 4;		// calculate new iter. value (+b, *(1/aii))
localparam S_OUTPUT = 5;		// write the result to output memory
localparam S_FINISH = 6;		// assert o_proc_done until i_module_en == 0

// output signal
reg o_proc_done_r, o_proc_done_w;
reg o_mem_rreq_r, o_mem_rreq_w;
reg o_x_wen_r, o_x_wen_w;
reg [31:0] o_x_data_r, o_x_data_w;


// control
reg [2:0] state_r, state_w;			// state
reg [3:0] iter_cnt_r, iter_cnt_w;	// counter of iteration times
reg [4:0] col_cnt_r, col_cnt_w;		// counter of which col does it process 

// storage
reg [36:0] x_r [0:15];				// array of x
reg [36:0] x_w [0:15];
reg [15:0] b_r [0:15];
reg [15:0] b_w [0:15];				// array of b

// multipiler
reg [15:0] multiplier_in1 [0:14];	// array of multiplier
reg [31:0] multpilier_in2 [0:14];
wire [47:0] multiplier_output [0:14];

integer i;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------

// output signal
assign o_proc_done = o_proc_done_r;
assign o_mem_rreq = o_mem_rreq_r;
assign o_mem_addr = 17*iter_cnt_r + col_cnt_r;
assign o_x_wen = o_x_wen_r;
assign o_x_addr = {iter_cnt_r, 4'b0} + col_cnt_r;
assign o_x_data = o_x_data_r;

// multipiler
for (i = 0; i < 15; i = i + 1) begin
	assign multiplier_output[i] = multiplier_in1[i]*multpilier_in2[i];
end
// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
always @(*) begin
	o_proc_done_w = 0;
	o_mem_rreq_w = o_mem_rreq_r;
	o_x_wen_w = 0;
	o_x_data_w = o_x_data_r;
	state_w = state_r;
	iter_cnt_w = iter_cnt_r;
	col_cnt_w = col_cnt_r;
	for (i = 0; i < 15; i = i + 1) begin
		x_w[i] = x_r[i];
		b_w[i] = b_r[i];
	end
	case (state_r)
		S_IDLE: begin
			
		end
		S_INIT: begin
			
		end
		S_WAIT: begin
			
		end
		S_CALC_TERMS: begin
			
		end
		S_CALC_NEW: begin
			
		end
		S_OUTPUT: begin
			
		end
		S_FINISH: begin
			
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
		iter_cnt_r 		<= 0;
		col_cnt_r 		<= 0;
		for (i = 0; i < 15; i = i + 1) begin
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
		iter_cnt_r 		<= iter_cnt_w;
		col_cnt_r 		<= col_cnt_w;
		for (i = 0; i < 15; i = i + 1) begin
			x_r[i] 		<= x_w[i];
			b_r[i] 		<= b_w[i];
		end
	end
end

endmodule
