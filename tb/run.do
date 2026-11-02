transcript file transcript
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -sv ../rtl/apb_RAM_one.sv
vlog -sv ../rtl/apb_bridge.sv
vlog -sv ../rtl/apb_top.sv
vlog -sv apb_top_testbench.sv

vsim -voptargs=+acc work.apb_top_testbench
run -all
quit -f
