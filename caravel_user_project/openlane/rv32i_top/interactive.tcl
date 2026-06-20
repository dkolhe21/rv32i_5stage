package require openlane
prep -design rv32i_top -overwrite
run_synthesis
run_floorplan
run_placement
run_cts
run_sta
