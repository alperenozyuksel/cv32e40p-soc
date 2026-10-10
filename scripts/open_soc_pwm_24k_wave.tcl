# Source from Vivado Tcl Console after verify.ps1 -Tests tb_soc_pwm_24k.
set repo [file normalize [file join [file dirname [info script]] ..]]
open_wave_database [file join $repo build verification soc_pwm_48m_24k.wdb]
add_wave /tb_soc_pwm_24k/clk /tb_soc_pwm_24k/rst /tb_soc_pwm_24k/pin
add_wave /tb_soc_pwm_24k/dut/cpu_axi_req /tb_soc_pwm_24k/dut/cpu_axi_rsp
add_wave /tb_soc_pwm_24k/dut/u_pwm/enable_q
add_wave /tb_soc_pwm_24k/dut/u_pwm/period_q /tb_soc_pwm_24k/dut/u_pwm/high_q
add_wave /tb_soc_pwm_24k/dut/u_pwm/period_start /tb_soc_pwm_24k/dut/u_pwm/u_pwm/count
