log_wave -r /tb_pwm/*
open_vcd pwm.vcd
log_vcd /tb_pwm/*
run all
close_vcd
quit
