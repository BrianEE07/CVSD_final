## PrimeTime Script
set power_enable_analysis TRUE
set power_analysis_mode time_based

read_file -format verilog  ../02_SYN/Netlist/GSIM_syn.v
current_design GSIM
link

#read_sdf -load_delay net ./GSIM_syn.sdf

## ===== idle window ===== TA modify
read_vcd  -strip_path testbed/u_GSIM  ../03_GATE/gsim_eps.fsdb \
          -time {10.5  1010.5}
update_power
report_power
report_power > try_idle.power

## ===== active window ===== TA modify
read_vcd  -strip_path testbed/u_GSIM  ../03_GATE/gsim_eps.fsdb \
          -when {i_module_en}

#report_switching_activity -list_not_annotated -show_pin

update_power
report_power 
report_power > try_active.power

## ===== idle_after_active window ===== TA modify
read_vcd  -strip_path testbed/u_GSIM  ../03_GATE/gsim_eps.fsdb \
          -time {98913.5 99913.5}
update_power
report_power
report_power > try_idle_after_active.power

exit
