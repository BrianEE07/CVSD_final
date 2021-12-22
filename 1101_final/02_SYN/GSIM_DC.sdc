# operating conditions and boundary conditions #

set cycle  5.4         ;#clock period defined by designer

create_clock -period $cycle [get_ports  i_clk]
set_dont_touch_network      [get_clocks i_clk]
set_fix_hold                [get_clocks i_clk]
set_ideal_network           [get_ports i_clk]
set_clock_uncertainty  0.1  [get_clocks i_clk]
set_clock_latency      0.5  [get_clocks i_clk]

set_input_delay  1      -clock i_clk [remove_from_collection [all_inputs] [get_ports i_clk]]
set_output_delay 0.5    -clock i_clk [all_outputs] 
set_load         1     [all_outputs]
set_drive        1     [all_inputs]

set_operating_conditions  -max_library slow -max slow               

set_max_fanout 20 [all_inputs]


                       
