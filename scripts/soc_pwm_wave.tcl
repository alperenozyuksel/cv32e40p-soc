log_wave /tb_soc_pwm/clk /tb_soc_pwm/rst /tb_soc_pwm/pin
log_wave /tb_soc_pwm/dut/cpu_axi_req /tb_soc_pwm/dut/cpu_axi_rsp
log_wave -r /tb_soc_pwm/dut/u_pwm/*
open_vcd soc_pwm.vcd
log_vcd /tb_soc_pwm/clk /tb_soc_pwm/rst /tb_soc_pwm/pin
log_vcd /tb_soc_pwm/dut/u_pwm/*
log_vcd /tb_soc_pwm/dut/u_pwm/u_pwm/*
run all
close_vcd
quit
