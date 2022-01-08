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
	output [ 31:0] o_x_data   //We should take use of this
);

// ---------------------------------------------------------------------------
//Parameter
localparam IDLE        = 5'd0,  
           LOADING_0   = 5'd1,
           LOADING_1   = 5'd2,
           LOADING_2   = 5'd3,
           LOADING_3   = 5'd4,
           LOADING_4   = 5'd5,
           LOADING_5   = 5'd6,
           LOADING_6   = 5'd7,
           LOADING_7   = 5'd8,
           LOADING_8   = 5'd9,
           LOADING_9   = 5'd10,
           LOADING_10  = 5'd11,
           LOADING_11  = 5'd12,
           LOADING_12  = 5'd13,
           LOADING_13  = 5'd14,
           LOADING_14  = 5'd15,
           LOADING_15  = 5'd16,
           LOADING_b   = 5'd17;

integer    i;
genvar     j;

// ---------------------------------------------------------------------------
// Wires and Registers
//FSM
reg [4:0]   state_r, state_w;
reg [4:0]   iter_cont_r, iter_cont_w;
reg [4:0]   matrix_num_r, matrix_num_w;
reg [15:0]  mem_dout [16:1];

//===============control===============/
reg         x_refresh_r, x_refresh_w; 
reg         prefetch_r, prefetch_w;
reg         change_state;
//=====================================/

reg [36:0]  x_r [16:1];
reg [36:0]  x_w [16:1];

//Multiplier
reg  [47:0]  mul_1    [16:1];
reg  [47:0]  mul_2    [16:1];
wire [47:0]  mul_temp [16:1];
//ADDER
reg  [36:0]  add_1    [16:1];
reg  [36:0]  add_2    [16:1];
wire [36:0]  add_temp [16:1];

reg [15:0]  buff_r [16:1];
reg [15:0]  buff_w [16:1];
//OUTPUT
reg         proc_done_r, proc_done_w;
reg         mem_rreq_r, mem_rreq_w;
reg [9:0]   mem_addr_r, mem_addr_w;
reg         x_wen_r, x_wen_w;
reg [8:0]   x_addr_r, x_addr_w;
reg [31:0]  x_data_r, x_data_w;


// ---------------------------------------------------------------------------
// Continuous Assignmen
//FSM


//OUTPUT
assign o_proc_done = proc_done_r;
assign o_mem_rreq  = mem_rreq_r;
assign o_mem_addr  = mem_addr_r + 17*matrix_num_r;
assign o_x_wen     = x_wen_r;
assign o_x_addr    = x_addr_r;
assign o_x_data    = x_data_r;


// ---------------------------------------------------------------------------
// Task
// task asym_sat_3;
//     ({5{x_r[state_r][36]}} != x_r[state_r][35:31]) ? {x_r[state_r][36], {36{!x_r[state_r][36]}}} : 
//                                                                                   {{12{x_r[state_r][36]}}, x_r[state_r][35:16] , x_r[state_r][15:0]};
// endtask

// ---------------------------------------------------------------------------
// Instance

// ---------------------------------------------------------------------------
// Combinational Blocks

//DATAPATH
generate 
    for (j = 1; j <= 16; j = j + 1) begin
        assign add_temp[j] = add_1[j] + add_2[j]; //ADD
        assign mul_temp[j] = mul_1[j] * mul_2[j]; //MUL
    end 
endgenerate

always @(*) begin
    for (i = 1; i <= 16; i = i + 1) begin
        mem_dout[i] = i_mem_dout[(16*i-1) -: 16];
        x_w[i]      = x_r[i];              //X_VALUE
        buff_w[i]   = (i_mem_dout_vld) ? mem_dout[i] : buff_r[i]; //BUFF

    end


    case (state_r)
        IDLE : begin
            for (i = 1; i <= 16; i = i + 1) begin
                x_w[i]      = 0;  //X_VALUE
                buff_w[i]   = 0;  //BUFF
            end
        end
        LOADING_b: begin
            //ADD                              
            if(x_refresh_r) begin
                for (i = 1; i <= 16; i = i + 1) begin
                    add_1[i] = 0;
                    add_2[i] = 0;
                end
            end
            else begin
                for (i = 1; i <= 16; i = i + 1) begin
                    add_1[i] = x_r[i];
                    add_2[i] = {{6{buff_r[i][15]}}, buff_r[i][14:0], 16'b0}; //(prefetch_r) ? {{6{buff_r[i][15]}}, buff_r[i][14:0], 16'b0} : {{6{mem_dout[i][15]}}, mem_dout[i][14:0], 16'b0}; //SSSSSS 15 16
                end
            end
            
            //MUL
            for (i = 1; i <= 16; i = i + 1) begin
                mul_1[i] = 0;
                mul_2[i] = 0;
            end

            //X_VALUE
            if(x_refresh_r) begin
                for (i = 1; i <= 16; i = i + 1) begin
                    x_w[i] = x_r[i]; 
                end
            end
            
            else begin
                if(iter_cont_r == 0) begin
                    for (i = 1; i <= 16; i = i + 1) begin
                        x_w[i] = {{22{buff_r[i][15]}}, buff_r[i][14:0]};
                    end
                end
                else begin
                    for (i = 1; i <= 16; i = i + 1) begin
                        x_w[i] = (~change_state) ? x_r[i] : add_temp[i];
                    end
                end
            end

        end

        LOADING_0: begin
            //MUL
            if(x_refresh_r) begin
                mul_1[state_r] = ({5{x_r[state_r][36]}} != x_r[state_r][35:31]) ? {{17{x_r[state_r][36]}}, {31{!x_r[state_r][36]}}} : 
                                                                                  {{17{x_r[state_r][36]}}, x_r[state_r][30:16] , x_r[state_r][15:0]};
                mul_2[state_r] = (prefetch_r)                                   ? {{33{buff_r[state_r][15]}}, buff_r[state_r][14], buff_r[state_r][13:0]} : 
                                                                                  {{33{mem_dout[state_r][15]}}, mem_dout[state_r][14], mem_dout[state_r][13:0]};
                for (i = (state_r + 1); i <= 16; i = i + 1) begin
                    mul_1[i] = 0;
                    mul_2[i] = 0;
                end
            end
            else begin
                mul_1[state_r] = 0;
                mul_2[state_r] = 0;
                for (i = (state_r + 1); i <= 16; i = i + 1) begin
                    mul_1[i] = {{12{x_r[state_r][36]}}, x_r[state_r][35:16] , x_r[state_r][15:0]};
                    mul_2[i] = {{33{buff_r[i][15]}}, buff_r[i][14:0]};
                end
            end



            //ADD
            if(x_refresh_r) begin
                for (i = 1; i <= 16; i = i + 1) begin
                    add_1[i] = 0; 
                    add_2[i] = 0;
                end
            end
            else begin
                add_1[state_r] = 0;
                add_2[state_r] = 0;
                for (i = (state_r + 1); i <= 16; i = i + 1) begin
                    add_1[i] = x_r[i];
                    add_2[i] = ({16{mul_temp[i][47]}} != mul_temp[i][46:31]) ? - {{6{mul_temp[i][47]}}, {31{!mul_temp[i][47]}}} : 
                                                                               - {{6{mul_temp[i][47]}}, mul_temp[i][30:16], mul_temp[i][15:0]};
                end
            end

            //X_VALUE
            if(x_refresh_r) begin                
                if(iter_cont_r == 0) begin
                    x_w[state_r] = ({2{mul_temp[state_r][31]}} != mul_temp[state_r][30:29]) ? {{6{mul_temp[state_r][31]}}, {31{!mul_temp[state_r][31]}}} : 
                                                                                              {{6{mul_temp[state_r][47]}}, mul_temp[state_r][28:14], mul_temp[state_r][13:0], 2'b0};
                end 
                else begin
                    x_w[state_r] = ({2{mul_temp[state_r][47]}} != mul_temp[state_r][46:45]) ? { {6{mul_temp[state_r][47]}}, {31{!mul_temp[state_r][47]}} } : 
                                                                                              { {6{mul_temp[state_r][47]}}, mul_temp[state_r][44:30], mul_temp[state_r][29:14] };
                end 

                for (i = (state_r + 1); i <= 16; i = i + 1) begin
                    x_w[i] = x_r[i];  
                end
            end
            else begin
                x_w[state_r] = (~change_state) ? x_r[state_r] : 0;
                for (i = (state_r + 1); i <= 16; i = i + 1) begin
                    x_w[i] = ((iter_cont_r == 0) || (~change_state)) ? x_r[i] : add_temp[i];  
                end
            end

        end

        default : begin
            //MUL
            if(x_refresh_r) begin
                mul_1[state_r] = ({5{x_r[state_r][36]}} != x_r[state_r][35:31]) ? {{17{x_r[state_r][36]}}, {31{!x_r[state_r][36]}}} : 
                                                                                  {{17{x_r[state_r][36]}}, x_r[state_r][30:16] , x_r[state_r][15:0]};
                mul_2[state_r] = (prefetch_r)                                   ? {{33{buff_r[state_r][15]}}, buff_r[state_r][14], buff_r[state_r][13:0]} : 
                                                                                  {{33{mem_dout[state_r][15]}}, mem_dout[state_r][14], mem_dout[state_r][13:0]};

                for (i = 1; i <= (state_r - 1); i = i + 1) begin
                    mul_1[i] = 0;
                    mul_2[i] = 0;
                end
                for (i = (state_r + 1); i <= 16; i = i + 1) begin
                    mul_1[i] = 0;
                    mul_2[i] = 0;
                end
            end
            else begin
                mul_1[state_r] = 0;
                mul_2[state_r] = 0;
                for (i = 1; i <= (state_r - 1); i = i + 1) begin
                    mul_1[i] = {{12{x_r[state_r][36]}}, x_r[state_r][35:16] , x_r[state_r][15:0]};
                    mul_2[i] = {{33{buff_r[i][15]}}, buff_r[i][14:0]};
                end
                for (i = (state_r+1); i <= 16; i = i + 1) begin
                    mul_1[i] = {{12{x_r[state_r][36]}}, x_r[state_r][35:16] , x_r[state_r][15:0]};
                    mul_2[i] = {{33{buff_r[i][15]}}, buff_r[i][14:0]};
                end
            end

            //ADD
            if(x_refresh_r) begin
                for (i = 1; i <= 16; i = i + 1) begin
                    add_1[i] = 0; 
                    add_2[i] = 0;
                end
            end
            else begin
                add_1[state_r] = 0;
                add_2[state_r] = 0;
                for (i = 1; i <= (state_r - 1); i = i + 1) begin
                    add_1[i] = x_r[i];
                    add_2[i] = ({16{mul_temp[i][47]}} != mul_temp[i][46:31]) ? - {{6{mul_temp[i][47]}}, {31{!mul_temp[i][47]}}} : 
                                                                               - {{6{mul_temp[i][47]}}, mul_temp[i][30:16], mul_temp[i][15:0]};
                end
                for (i = (state_r + 1); i <= 16; i = i + 1) begin
                    add_1[i] = x_r[i];
                    add_2[i] = ({16{mul_temp[i][47]}} != mul_temp[i][46:31]) ? - {{6{mul_temp[i][47]}}, {31{!mul_temp[i][47]}}} : 
                                                                               - {{6{mul_temp[i][47]}}, mul_temp[i][30:16], mul_temp[i][15:0]};
                end
            end

            //X_VALUE
            if(x_refresh_r) begin
                if(iter_cont_r == 0) begin
                    x_w[state_r] = ({2{mul_temp[state_r][31]}} != mul_temp[state_r][30:29]) ?   {{6{mul_temp[state_r][31]}}, {31{!mul_temp[state_r][31]}}} : 
                                                                                                {{6{mul_temp[state_r][47]}}, mul_temp[state_r][28:14], mul_temp[state_r][13:0], 2'b0};
                end 
                else begin
                    x_w[state_r] = ({2{mul_temp[state_r][47]}} != mul_temp[state_r][46:45]) ? { {6{mul_temp[state_r][47]}}, {31{!mul_temp[state_r][47]}} } : 
                                                                                              { {6{mul_temp[state_r][47]}}, mul_temp[state_r][44:30], mul_temp[state_r][29:14] };
                end 

                for (i = 1; i <= (state_r - 1); i = i + 1) begin
                    x_w[i] = x_r[i];  
                end
                for (i = (state_r + 1); i <= 16; i = i + 1) begin
                    x_w[i] = x_r[i];  
                end
            end
            else begin
                x_w[state_r] = (~change_state) ? x_r[state_r] : 0;
                for (i = 1; i <= (state_r - 1); i = i + 1) begin
                    x_w[i] = (change_state) ? add_temp[i] : x_r[i];  
                end
                for (i = (state_r + 1); i <= 16; i = i + 1) begin
                    x_w[i] = ((iter_cont_r == 0) || (~change_state)) ? x_r[i] : add_temp[i];  
                end
            end

        end

        LOADING_15: begin
            //MUL
            if(x_refresh_r) begin
                mul_1[state_r] = ({5{x_r[state_r][36]}} != x_r[state_r][35:31]) ? {{17{x_r[state_r][36]}}, {31{!x_r[state_r][36]}}} : 
                                                                                  {{17{x_r[state_r][36]}}, x_r[state_r][30:16] , x_r[state_r][15:0]};
                mul_2[state_r] = (prefetch_r)                                   ? {{33{buff_r[state_r][15]}}, buff_r[state_r][14], buff_r[state_r][13:0]} : 
                                                                                  {{33{mem_dout[state_r][15]}}, mem_dout[state_r][14], mem_dout[state_r][13:0]};
                for (i = 1; i <= (state_r-1); i = i + 1) begin
                    mul_1[i] = 0;
                    mul_2[i] = 0;
                end
            end
            else begin
                mul_1[state_r] = 0;
                mul_2[state_r] = 0;
                for (i = 1; i <= (state_r-1); i = i + 1) begin
                    mul_1[i] = {{12{x_r[state_r][36]}}, x_r[state_r][35:16] , x_r[state_r][15:0]};
                    mul_2[i] = {{33{buff_r[i][15]}}, buff_r[i][14:0]};
                end
            end

            //ADD
            if(x_refresh_r) begin
                for (i = 1; i <= 16; i = i + 1) begin
                    add_1[i] = 0; 
                    add_2[i] = 0;
                end
            end
            else begin
                add_1[state_r] = 0;
                add_2[state_r] = 0;
                for (i = 1; i <= (state_r - 1); i = i + 1) begin
                    add_1[i] = x_r[i];
                    add_2[i] = ({16{mul_temp[i][47]}} != mul_temp[i][46:31]) ? - {{6{mul_temp[i][47]}}, {31{!mul_temp[i][47]}}} :
                                                                               - {{6{mul_temp[i][47]}}, mul_temp[i][30:16], mul_temp[i][15:0]};
                end
            end

            //X_VALUE
            if(x_refresh_r) begin
                if(iter_cont_r == 0) begin
                    x_w[state_r] = ({2{mul_temp[state_r][31]}} != mul_temp[state_r][30:29]) ? {{6{mul_temp[state_r][31]}}, {31{!mul_temp[state_r][31]}}} : 
                                                                                              {{6{mul_temp[state_r][47]}}, mul_temp[state_r][28:14], mul_temp[state_r][13:0], 2'b0};
                end 
                else begin
                    x_w[state_r] = ({2{mul_temp[state_r][47]}} != mul_temp[state_r][46:45]) ? { {6{mul_temp[state_r][47]}}, {31{!mul_temp[state_r][47]}} } : 
                                                                                              { {6{mul_temp[state_r][47]}}, mul_temp[state_r][44:30], mul_temp[state_r][29:14] };
                end 

                for (i = 1; i <= (state_r - 1); i = i + 1) begin
                    x_w[i] = x_r[i];  
                end
            end
            else begin
                x_w[state_r] = (~change_state) ? x_r[state_r] : 0;
                for (i = 1; i <= (state_r - 1); i = i + 1) begin
                    x_w[i] = (change_state) ? add_temp[i] : x_r[i];  
                end
            end

        end
        
    endcase
    
end

//FSM 
always @(*) begin
    state_w      = state_r;
    iter_cont_w  = iter_cont_r; 
    matrix_num_w = matrix_num_r; 
    // x_refresh_w  = x_refresh_r;
    // prefetch_w   = prefetch_r; 

    //===============control===============//
    //only have one chance to prefetch => at the first cycle 
    if(x_refresh_r) begin
        prefetch_w = i_mem_rrdy;
    end
    else begin
        prefetch_w = prefetch_r;
    end

    //state transistion
    if (!x_refresh_r) begin
        change_state = prefetch_r || (i_mem_rrdy && mem_rreq_r);
    end
    else begin
        change_state = 0;
    end

    //at the first cycle or not
    x_refresh_w = (change_state) ? 1 : 0;



    //=====================================//
    
    //FSM
    case (state_r)
        IDLE: begin
            if(i_module_en) begin
                state_w     = (change_state) ? LOADING_b : IDLE;
                x_refresh_w = (change_state) ? 1 : 0;
                prefetch_w  = 0;
            end
        end 
        LOADING_0: begin
            state_w = (change_state) ? LOADING_1 : LOADING_0;
        end
        LOADING_1: begin
            state_w = (change_state) ? LOADING_2 : LOADING_1;
        end 
        LOADING_2: begin
            state_w = (change_state) ? LOADING_3 : LOADING_2;
        end 
        LOADING_3: begin
            state_w = (change_state) ? LOADING_4 : LOADING_3;
        end 
        LOADING_4: begin
            state_w = (change_state) ? LOADING_5 : LOADING_4;
        end 
        LOADING_5: begin
            state_w = (change_state) ? LOADING_6 : LOADING_5;
        end 
        LOADING_6: begin
            state_w = (change_state) ? LOADING_7 : LOADING_6;    
        end 
        LOADING_7: begin
            state_w = (change_state) ? LOADING_8 : LOADING_7;
        end 
        LOADING_8: begin
            state_w = (change_state) ? LOADING_9 : LOADING_8;
        end 
        LOADING_9: begin
            state_w = (change_state) ? LOADING_10 : LOADING_9;
        end 
        LOADING_10: begin
            state_w = (change_state) ? LOADING_11 : LOADING_10;
        end
        LOADING_11: begin
            state_w = (change_state) ? LOADING_12 : LOADING_11;
        end
        LOADING_12: begin
            state_w = (change_state) ? LOADING_13 : LOADING_12;
        end
        LOADING_13: begin
            state_w = (change_state) ? LOADING_14 : LOADING_13;
        end
        LOADING_14: begin
            state_w = (change_state) ? LOADING_15 : LOADING_14;
        end
        LOADING_15: begin
            if(change_state) begin
                iter_cont_w  = (iter_cont_r == 16) ? 0 : (iter_cont_r + 1);
                matrix_num_w = (iter_cont_r == 16) ? (matrix_num_r + 1)  : matrix_num_r;
                state_w      = (iter_cont_r == 16) ? IDLE : LOADING_b;
            end
            else begin
                state_w      = LOADING_15; 
            end

            // state_w = (matrix_num_r == i_matrix_num) ? IDLE : 
            //           (change_state)                 ? LOADING_b : LOADING_15; 
        end
        LOADING_b: begin
            state_w   = (change_state) ? LOADING_0 : LOADING_b; 
        end
        
    endcase
end




//OUTPUT
always @(*) begin
    // proc_done_w = proc_done_r;
    // mem_rreq_w  = mem_rreq_r;
    // mem_addr_w  = mem_addr_r; 
    // x_wen_w     = x_wen_r;    
    // x_addr_w    = x_addr_r;   
    // x_data_w    = x_data_r;

    x_addr_w    = (state_r - 1) + 16*matrix_num_r;
    x_data_w    = x_r[state_r];
    x_wen_w     = (iter_cont_r == 5'd16) && change_state;
    if(proc_done_r) proc_done_w = i_module_en;
    else            proc_done_w = (matrix_num_r == i_matrix_num) && i_module_en;

    if((i_mem_rrdy) && (x_refresh_r) || (!i_module_en)) begin //not in the first cycle but have got the newset row
        mem_rreq_w = 0;
    end
    else begin
        mem_rreq_w = 1;
    end



    case (state_r)
        IDLE: begin
            if(i_module_en) begin
                mem_addr_w = (change_state) ? 0 : 16;
            end
        end 
        LOADING_0: begin
            mem_addr_w = (change_state) ? 2 : 1;
        end
        LOADING_1: begin
            mem_addr_w = (change_state) ? 3 : 2;
        end 
        LOADING_2: begin
            mem_addr_w = (change_state) ? 4 : 3;
        end 
        LOADING_3: begin
            mem_addr_w = (change_state) ? 5 : 4;
        end 
        LOADING_4: begin
            mem_addr_w = (change_state) ? 6 : 5;
        end 
        LOADING_5: begin
            mem_addr_w = (change_state) ? 7 : 6;
        end 
        LOADING_6: begin
            mem_addr_w = (change_state) ? 8 : 7;
        end 
        LOADING_7: begin
            mem_addr_w = (change_state) ? 9 : 8;
        end 
        LOADING_8: begin
            mem_addr_w = (change_state) ? 10 : 9;
        end 
        LOADING_9: begin
            mem_addr_w = (change_state) ? 11 : 10;
        end 
        LOADING_10: begin
            mem_addr_w = (change_state) ? 12 : 11;
        end
        LOADING_11: begin
            mem_addr_w = (change_state) ? 13 : 12;
        end
        LOADING_12: begin
            mem_addr_w = (change_state) ? 14 : 13;
        end
        LOADING_13: begin
            mem_addr_w = (change_state) ? 15 : 14;
        end
        LOADING_14: begin
            mem_addr_w = (change_state) ? 16 : 15;
        end
        LOADING_15: begin
            mem_addr_w = (change_state) ? 0 : 16;
        end
        LOADING_b: begin
            mem_addr_w = (change_state) ? 1 : 0;
        end
        
    endcase  
end



// ---------------------------------------------------------------------------
// Sequential Block
always @(posedge i_clk or posedge i_reset) begin
    if(i_reset) begin
        //FSM
        state_r      <= IDLE;
        matrix_num_r <= 0;
        iter_cont_r  <= 0;
        x_refresh_r  <= 0;
        prefetch_r   <= 0;
        //OUTPUT
        proc_done_r  <= 0; 
        mem_rreq_r   <= 0;
        mem_addr_r   <= 0;
        x_wen_r      <= 0;
        x_addr_r     <= 0;
        x_data_r     <= 0;
    end
    else begin
        //FSM
        state_r      <= state_w; 
        matrix_num_r <= matrix_num_w;
        iter_cont_r  <= iter_cont_w;
        x_refresh_r  <= x_refresh_w;
        prefetch_r   <= prefetch_w;
        //OUTPUT
        proc_done_r  <= proc_done_w; 
        mem_rreq_r   <= mem_rreq_w;
        mem_addr_r   <= mem_addr_w;
        x_wen_r      <= x_wen_w;
        x_addr_r     <= x_addr_w;
        x_data_r     <= x_data_w;
    end
end


//control_signal
// always @(posedge i_clk or posedge i_reset) begin
//     if(i_reset) begin
//         prefetch_r   <= 0;
//     end
//     else if(x_refresh_r) begin
//         prefetch_r   <= prefetch_w;
//     end
// end


//stuck in the same state will mess up X_value 
always @(posedge i_clk or posedge i_reset) begin
    if(i_reset) begin
        for (i = 1; i <= 16; i = i + 1) begin
        	x_r[i]    <= 0;
        end
    end
    else begin 
        for (i = 1; i <= 16; i = i + 1) begin
        	x_r[i]    <= x_w[i];
        end
    end
end

//stuck in the same state may mess up BUFF (i_mem_rrdy,halt_r) == (1,1) in cycle1 ,  i_mem_rrdy,halt_r == (1/0,0) in cycle2 zero will flush BUFF 
always @(posedge i_clk or posedge i_reset) begin
    if(i_reset) begin
        for (i = 1; i <= 16; i = i + 1) begin
        	buff_r[i] <= 0;
        end       
    end
    else begin
        for (i = 1; i <= 16; i = i + 1) begin
        	buff_r[i] <= buff_w[i];
        end     
    end
end

/*
//GCLK for "iter_cont"
always @(posedge i_clk or posedge i_reset) begin
    if(i_reset)              iter_cont_r <= 0;
    else if(state_r == IRER) iter_cont_r <= iter_cont_w;
end
*/
/*
//GCLK for "matrix_num"
always @(posedge i_clk or posedge i_reset) begin
    if(i_reset)              matrix_num_r <= 0;
    else if(state_r == ITERATION) matrix_num_r <= matrix_num_w;
end
*/
endmodule
