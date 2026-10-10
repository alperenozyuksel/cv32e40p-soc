`timescale 1ns/1ps
module tb_peripherals;
    logic clk=0, rst=0;
    always #5 clk=~clk;
    logic [2:0] req=0, we=0;
    logic [31:0] addr[3], wd[3];
    logic [3:0] be[3];
    wire [2:0] gnt, rv;
    wire [31:0] rd[3];
    logic [15:0] pins=0;
    wire [15:0] outputs;
    integer checks=0;
    logic [31:0] model[2048];
    logic [31:0] got, value, before_count;
    integer idx, mask;
    int unsigned rng=32'h12ab9876;
    function automatic int unsigned random32();
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction
    dmem_8kb ram(clk,rst,req[0],addr[0],we[0],be[0],wd[0],gnt[0],rv[0],rd[0]);
    gpio gpio_dut(clk,rst,req[1],addr[1],we[1],be[1],wd[1],gnt[1],rv[1],rd[1],pins,outputs);
    timer timer_dut(clk,rst,req[2],addr[2],we[2],be[2],wd[2],gnt[2],rv[2],rd[2]);
    task automatic check(input bit ok, input string msg);
        if (!ok) $fatal(1,"%s at %t",msg,$time);
        checks++;
    endtask
    task automatic access(input int p,input bit wr,input logic[31:0] a,d,
                          input logic[3:0] st,output logic[31:0] result);
        @(negedge clk); req[p]=1; we[p]=wr; addr[p]=a; wd[p]=d; be[p]=st;
        #1; check(gnt[p]===1,"local grant");
        @(posedge clk); #1; check(rv[p]===1,"local response"); result=rd[p];
        @(negedge clk); req[p]=0;
        @(posedge clk); #1; check(rv[p]===0,"one local response");
    endtask
    task automatic read_eq(input int p,input logic[31:0] a,expected);
        logic[31:0] r;
        access(p,0,a,0,0,r);
        if(r !== expected) $fatal(1,"read %h expected %h got %h",a,expected,r);
        checks++;
    endtask
    task automatic tw(input logic[31:0] off,d);
        logic[31:0] unused;
        access(2,1,32'h11000+off,d,15,unused);
    endtask
    task automatic reset_all;
        @(negedge clk); rst=0; req=0;
        repeat(3) @(posedge clk);
        #1; check(rv===0 && gnt===0 && outputs===0,"reset outputs");
        @(negedge clk); rst=1;
    endtask

    initial begin
        for(int p=0;p<3;p++) begin addr[p]=0; wd[p]=0; be[p]=0; end
        reset_all();
        // Every RAM word, then all byte masks with deterministic random traffic.
        for(int n=0;n<2048;n++) begin
            model[n]=32'h9e370000 ^ (n*32'h10203);
            access(0,1,32'h4000+4*n,model[n],15,got);
        end
        for(int n=0;n<2048;n++) read_eq(0,32'h4000+4*n,model[n]);
        for(int n=0;n<512;n++) begin
            idx=random32()%2048; mask=n%16; value=random32();
            access(0,1,32'h4000+4*idx+(n%4),value,4'(mask),got);
            for(int b=0;b<4;b++) if(mask & (1<<b)) model[idx][8*b+:8]=value[8*b+:8];
            read_eq(0,32'h4000+4*idx,model[idx]);
        end
        // Consecutive accepted requests, no idle gap.
        @(negedge clk); req[0]=1; we[0]=0; addr[0]=32'h4000;
        for(int n=0;n<16;n++) begin
            @(posedge clk); #1;
            check(rv[0]===1 && rd[0]===model[n],"RAM back-to-back");
            @(negedge clk); addr[0]=32'h4000+4*(n+1);
        end
        req[0]=0;
        // Bounds must not alias low RAM addresses.
        foreach(addr[p]) begin
            @(negedge clk); req[p]=1; addr[p]=32'hdead0000;
            #1; check(gnt[p]===0,"unmapped local address");
            @(posedge clk); #1; check(rv[p]===0,"unmapped has no response");
            @(negedge clk); req[p]=0;
        end
        // GPIO input synchronizer latency.
        @(negedge clk); pins=16'ha55a;
        @(posedge clk); #1; check(gpio_dut.gpio_in_sync===0,"first sync stage");
        @(posedge clk); #1; check(gpio_dut.gpio_in_sync===pins,"second sync stage");
        read_eq(1,32'h10000,32'ha55a);
        access(1,1,32'h10004,32'hffff1234,15,got);
        check(outputs===16'h1234,"GPIO full write");
        access(1,1,32'h10005,32'h0000aa00,2,got);
        read_eq(1,32'h10004,32'haa34);
        access(1,1,32'h10004,32'hffff0000,12,got);
        read_eq(1,32'h10004,32'haa34);
        access(1,1,32'h10000,0,15,got);
        read_eq(1,32'h10000,32'ha55a);
        access(1,1,32'h10008,32'hffffffff,15,got);
        read_eq(1,32'h10008,0);
        reset_all();
        read_eq(0,32'h4000,model[0]); // reset does not erase SRAM

        // Timer register masks, RO and reserved writes.
        access(2,1,32'h11000,32'h11223344,15,got);
        access(2,1,32'h11001,32'h0000aa00,2,got);
        read_eq(2,32'h11000,32'h1122aa44);
        tw('h14,123); tw('h18,456);
        read_eq(2,32'h11014,0); read_eq(2,32'h11018,0);
        tw('h20,123); read_eq(2,32'h11020,0);
        // For each divisor, check a complete triangular period by exact clocks.
        for(int divisor=1;divisor<=4;divisor++) begin
            reset_all();
            tw(0,divisor-1); tw(4,3); tw('h10,1);
            // Enable takes effect after the write edge.
            @(negedge clk); req[2]=1; we[2]=1; addr[2]='h1100c; wd[2]=1; be[2]=15;
            @(posedge clk); #1; check(timer_dut.tim_cnt===0,"enable edge");
            @(negedge clk); req[2]=0;
            for(int n=1;n<=16*divisor;n++) begin
                @(posedge clk); #1;
                check(timer_dut.tim_cnt===32'((n/divisor)%4),"timer divisor/up/reload");
                check(timer_dut.tim_evn===32'(((n/divisor)+1)/4),"timer events");
            end
            tw('hc,0); before_count=timer_dut.tim_cnt;
            repeat(7) @(posedge clk);
            #1; check(timer_dut.tim_cnt===before_count,"disabled holds");
            tw(8,1); read_eq(2,'h11014,0);
            tw('h1c,1); read_eq(2,'h11018,0);
            tw('hc,1);
            repeat(7) @(posedge clk);
            #1; check(timer_dut.tim_cnt===0 && timer_dut.tim_evn===0,"clear holds");
        end
        // Down-count wrap and target arrival.
        reset_all(); tw(4,32'hfffffffd);
        @(negedge clk); req[2]=1; we[2]=1; addr[2]='h1100c; wd[2]=1; be[2]=15;
        @(posedge clk); @(negedge clk); req[2]=0;
        for(int n=1;n<=4;n++) begin
            @(posedge clk); #1;
            check(timer_dut.tim_cnt === (n==4 ? 32'b0 : (32'b0-32'(n))),"down counter");
        end
        check(timer_dut.tim_evn===1,"down event");
        // Large prescaler must not overflow into immediate ticking.
        reset_all(); tw(0,32'hffffffff); tw(4,10); tw('h10,1); tw('hc,1);
        repeat(100) @(posedge clk);
        #1; check(timer_dut.tim_cnt===0,"maximum divider short observation");
        reset_all();
        $display("PASS tb_peripherals checks=%0d seed=12ab9876",checks);
        $finish;
    end
    initial begin #1000000; $fatal(1,"timeout peripherals"); end
endmodule
