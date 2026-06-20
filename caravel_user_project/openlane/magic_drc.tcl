if {![info exists ::env(PDK_ROOT)]} {
    puts "PDK_ROOT not set, abort"
    exit
}
# Load the sky130A magicrc to ensure proper technology rules are applied
source $::env(PDK_ROOT)/sky130A/libs.tech/magic/sky130A.magicrc

gds read "rv32i_top/runs/26_06_15_09_31/results/final/gds/rv32i_top.gds"
load rv32i_top
drc style drc
drc check
set total [drc count total]
puts "=== DRC TOTAL VIOLATIONS: $total ==="
quit -noprompt
