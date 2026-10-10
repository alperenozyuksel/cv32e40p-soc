`timescale 1ns/1ps
module tb_soc_pwm;
    logic clk=0,rst=0,fetch=0;
    always #5 clk=~clk;
    wire pin,err;
    int seen[4];
    int cycles=0, highs=0, expected=0, periods=0, writes=0;
    bit tracking=0;
    soc_top #(.INIT_FILE("pwm_program.hex")) dut (
        .clk_i(clk),.rst_ni(rst),.fetch_enable_i(fetch),
        .gpio_in_i(16'b0),.pwm_o(pin),.bus_error_o(err)
    );
    axi_lite_checker check_cpu(clk,rst,dut.cpu_axi_req,dut.cpu_axi_rsp);
    for(genvar i=0;i<4;i++) begin: monitors
        axi_lite_checker check_target(clk,rst,dut.peripheral_axi_req[i],dut.peripheral_axi_rsp[i]);
    end
    always @(posedge clk) begin
        if(rst && dut.peripheral_axi_req[3].wvalid &&
                  dut.peripheral_axi_rsp[3].wready) writes++;
    end
    // Measure complete periods at the output; no testbench writes to the DUT.
    always @(negedge clk) begin
        if(!rst || !dut.u_pwm.enable_q) begin
            tracking=0; cycles=0; highs=0;
        end else if(dut.u_pwm.period_start) begin
            if(tracking) begin
                if(cycles!=100 || highs!=expected)
                    $fatal(1,"PWM measurement period=%0d high=%0d expected=%0d",cycles,highs,expected);
                case(expected)
                    0: seen[0]++;
                    25: seen[1]++;
                    50: seen[2]++;
                    100: seen[3]++;
                    default: $fatal(1,"Unexpected duty");
                endcase
                periods++;
            end
            expected=dut.u_pwm.high_q;
            tracking=1; cycles=1; highs=int'(pin);
        end else if(tracking) begin
            cycles++; highs+=int'(pin);
        end
        if(rst && err) $fatal(1,"AXI error");
    end
    initial begin
        for(int boot=0;boot<2;boot++) begin
            @(posedge clk); #2; rst=0;fetch=0;
            repeat(5) @(posedge clk);
            #2;
            if(pin!==0 || dut.u_pwm.period_q!==0 || dut.u_pwm.high_q!==0)
                $fatal(1,"PWM reset");
            for(int i=0;i<4;i++) seen[i]=0;
            rst=1;fetch=1;
            wait(dut.u_cpu.core_i.id_stage_i.register_file_i.mem[20]===1 ||
                 dut.u_cpu.core_i.id_stage_i.register_file_i.mem[20]===32'hffffffff);
            if(dut.u_cpu.core_i.id_stage_i.register_file_i.mem[20]!==1)
                $fatal(1,"CPU register readback failed");
            repeat(3) @(posedge clk);
            #2;
            if(pin!==0) $fatal(1,"CPU disable failed");
            for(int i=0;i<4;i++) if(seen[i]<2) $fatal(1,"Duty %0d not observed",i);
            $display("BOOT %0d PWM PASS periods per duty=%0d,%0d,%0d,%0d",boot,seen[0],seen[1],seen[2],seen[3]);
        end
        if(writes<20) $fatal(1,"PWM AXI writes missing");
        $display("PASS tb_soc_pwm measured_periods=%0d AXI_writes=%0d",periods,writes);
        $finish;
    end
    initial begin #2000000; $fatal(1,"CPU PWM timeout"); end
endmodule
