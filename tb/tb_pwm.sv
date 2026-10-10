`timescale 1ns/1ps
module tb_pwm;
    logic clk=0,rst=0,enable=0;
    logic [31:0] period=100, high_cycles=25;
    wire pwm_out, period_start;
    integer checks=0, trace_file, case_id=0;
    always #5 clk=~clk; // 100 MHz
    pwm dut(clk,rst,enable,period,high_cycles,pwm_out,period_start);

    task automatic check(input bit ok,input string msg);
        if(!ok) $fatal(1,"%s at %t",msg,$time);
        checks++;
    endtask
    task automatic step;
        @(posedge clk); #1;
    endtask
    task automatic stop;
        @(negedge clk); enable=0;
        step(); check(pwm_out===0 && period_start===0,"disable");
    endtask
    task automatic configure(input int p,h,id);
        stop();
        @(negedge clk); period=p; high_cycles=h; case_id=id; enable=1;
        step();
    endtask
    // Called just after sampling the first cycle of a period.
    task automatic periods(input int p,h,n);
        integer highs;
        for(int j=0;j<n;j++) begin
            highs=0;
            for(int k=0;k<p;k++) begin
                check(pwm_out===(k<h),"PWM level at cycle");
                check(period_start===(k==0),"period marker");
                if(pwm_out) highs++;
                step();
            end
            check(highs==h,"high cycle count");
        end
    endtask

    // Samples are taken after nonblocking assignments. Export for actual trace plots.
    initial begin
        trace_file=$fopen("pwm_samples.csv","w");
        if(!trace_file) $fatal(1,"cannot open trace");
        $fwrite(trace_file,"time_ns,case_id,reset_n,enable,period,high_cycles,pwm,period_start,count\n");
        forever begin
            @(posedge clk); #2;
            $fwrite(trace_file,"%0d,%0d,%0b,%0b,%0d,%0d,%0b,%0b,%0d\n",
                $time,case_id,rst,enable,period,high_cycles,pwm_out,period_start,dut.count);
        end
    end
    initial begin
        repeat(3) step();
        check(pwm_out===0,"reset low");
        @(negedge clk); rst=1;
        configure(100,0,1); periods(100,0,4);
        configure(100,25,2); periods(100,25,4);
        configure(100,50,3); periods(100,50,4);
        configure(100,100,4); periods(100,100,4);
        configure(100,150,5); periods(100,100,2);
        configure(1,0,6); periods(1,0,5);
        configure(1,1,7); periods(1,1,5);
        configure(0,50,8);
        repeat(5) begin step(); check(pwm_out===0 && period_start===0,"zero period"); end
        // Active config must not shorten or lengthen the current pulse/period.
        configure(10,7,9);
        for(int k=0;k<10;k++) begin
            check(pwm_out===(k<7),"old config held");
            check(period_start===(k==0),"old period held");
            if(k==2) begin @(negedge clk); period=6; high_cycles=2; end
            step();
        end
        periods(6,2,4);
        // Zero period takes effect at a boundary, then a valid config restarts.
        @(negedge clk); period=0;
        for(int k=0;k<5;k++) step();
        step(); check(pwm_out===0 && !dut.running,"zero at boundary");
        @(negedge clk); period=4; high_cycles=1;
        step(); periods(4,1,3);
        // Disable interrupts a high pulse, then starts from cycle zero.
        configure(10,8,10);
        step(); stop();
        @(negedge clk); enable=1;
        step(); periods(10,8,2);
        @(negedge clk); rst=0;
        step(); check(pwm_out===0 && !period_start,"reset during pulse");
        @(negedge clk); rst=1;
        step(); periods(10,8,2);
        $fclose(trace_file);
        $display("PASS tb_pwm checks=%0d clock=100MHz period100=1MHz",checks);
        $finish;
    end
    initial begin #100000; $fatal(1,"PWM timeout"); end
endmodule
