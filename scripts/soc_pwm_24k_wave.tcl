log_wave /tb_soc_pwm_24k/clk /tb_soc_pwm_24k/rst /tb_soc_pwm_24k/pin
log_wave /tb_soc_pwm_24k/dut/cpu_axi_req /tb_soc_pwm_24k/dut/cpu_axi_rsp
log_wave -r /tb_soc_pwm_24k/dut/u_pwm/*
open_vcd soc_pwm_48m_24k.vcd
log_vcd /tb_soc_pwm_24k/clk /tb_soc_pwm_24k/rst /tb_soc_pwm_24k/pin
log_vcd /tb_soc_pwm_24k/dut/u_pwm/*
log_vcd /tb_soc_pwm_24k/dut/u_pwm/u_pwm/*
run all
close_vcd
quit
