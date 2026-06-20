drc off
gds read /project/gds/sky130_sram_2kbyte_1rw1r_32x512_8.gds
load sky130_sram_2kbyte_1rw1r_32x512_8
drc on
select top cell
drc catchup
drc count
set drc_result [drc listall why]
set f [open drc_results.txt w]
puts $f $drc_result
close $f
quit -noprompt
