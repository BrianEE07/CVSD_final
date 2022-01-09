set company {NTUGIEE}
set designer {Student}

set search_path      ". /home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/SynopsysDC/db  $search_path ../ ./"
set target_library   "slow.db"              
set link_library     "* $target_library dw_foundation.sldb"
set symbol_library   "tsmc13.sdb generic.sdb"
set synthetic_library "dw_foundation.sldb"

# Setting physical lib for EPS flow
set_tlu_plus_files -max_tluplus /home/raid7_2/course/cvsd/CBDK_IC_Contest_v2.5/ICC2/tluplus/t013s8mg_fsg_typical.tluplus -tech2itf_map /home/raid7_2/course/cvsd/CBDK_IC_Contest_v2.5/ICC2/tluplus/t013s8mg_fsg.map
create_mw_lib -technology /home/raid7_2/course/cvsd/CBDK_IC_Contest_v2.5/Astro/tsmc13_CIC.tf -mw_reference_library /home/raid7_2/course/cvsd/CBDK_IC_Contest_v2.5/Astro/tsmc13gfsg_fram tsmc13_mw
open_mw_lib tsmc13_mw

set default_schematic_options {-size infinite}