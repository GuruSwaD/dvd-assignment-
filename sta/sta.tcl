# OpenSTA setup-timing analysis of the synthesized mult_array netlist.
# Run from the repository root:  sta sta/sta.tcl
# The clock period defaults to 10 ns; override with:  PERIOD=3.5 sta sta/sta.tcl

set lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

if {[info exists ::env(PERIOD)]} {
    set period $::env(PERIOD)
} else {
    set period 10.0
}

# 1. cell timing library (typical corner)
read_liberty $lib

# 2. read and link the netlist
read_verilog synth/mult_array_netlist.v
link_design mult_array

# 3. clock
create_clock -name clk -period $period [get_ports clk]

# 4. input arrival time (all inputs except the clock)
set_input_delay 1.0 -clock clk [delete_from_list [all_inputs] [get_ports clk]]

# 5. output required time
set_output_delay 1.0 -clock clk [all_outputs]

# 6. worst setup slack
puts "Clock period: $period ns"
report_worst_slack -max -digits 3

# 7. critical path report
report_checks -path_delay max -digits 3 > sta/mult_array_timing.rpt

exit
