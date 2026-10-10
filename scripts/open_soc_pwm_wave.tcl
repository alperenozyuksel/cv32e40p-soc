# Source from Vivado Tcl Console after verify.ps1 -Tests tb_soc_pwm.
set repo [file normalize [file join [file dirname [info script]] ..]]
open_wave_database [file join $repo build verification soc_pwm.wdb]
add_wave /tb_soc_pwm/clk /tb_soc_pwm/rst /tb_soc_pwm/pin
add_wave /tb_soc_pwm/dut/cpu_axi_req /tb_soc_pwm/dut/cpu_axi_rsp
add_wave /tb_soc_pwm/dut/u_pwm/enable_q
add_wave /tb_soc_pwm/dut/u_pwm/period_q /tb_soc_pwm/dut/u_pwm/high_q
add_wave /tb_soc_pwm/dut/u_pwm/period_start /tb_soc_pwm/dut/u_pwm/u_pwm/count
