# Source this file from the Vivado Tcl Console after run_pwm.ps1.
set repo [file normalize [file join [file dirname [info script]] ..]]
open_wave_database [file join $repo build pwm pwm.wdb]
add_wave /tb_pwm/clk /tb_pwm/rst /tb_pwm/enable
add_wave /tb_pwm/period /tb_pwm/high_cycles
add_wave /tb_pwm/pwm_out /tb_pwm/period_start /tb_pwm/dut/count
