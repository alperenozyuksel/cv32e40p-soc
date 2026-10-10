`timescale 1ns/1ps
module tb_bridge;
    import axi_lite_pkg::*;
    logic clk=0,rst=0,req=0,we=0;
    always #5 clk=~clk;
    logic [31:0] addr=0,wd=0;
    logic [3:0] be=0;
    wire gnt,rv,err;
    wire[31:0] rd;
    axil_req_t a;
    axil_rsp_t s;
    integer checks=0;
    obi_to_axi_lite dut(clk,rst,req,we,addr,wd,be,gnt,rv,rd,err,a,s);
    axi_lite_checker checker_i(clk,rst,a,s);
    task automatic reset_all;
        @(negedge clk); rst=0; req=0; s='0;
        repeat(3) @(negedge clk);
        rst=1;
    endtask
    task automatic start(input bit wr,input logic[31:0] address,data,input logic[3:0] st);
        @(negedge clk); req=1; we=wr; addr=address; wd=data; be=st;
        do @(posedge clk); while(!gnt);
        @(negedge clk); req=0; addr='1; wd='1; be=0;
    endtask
    task automatic accept_aw(input logic[31:0] expected,input int delay_cycles);
        repeat(delay_cycles) @(negedge clk);
        s.awready=1;
        do @(posedge clk); while(!a.awvalid);
        if(a.awaddr !== expected) $fatal(1,"bridge AW payload");
        @(negedge clk); s.awready=0;
    endtask
    task automatic accept_w(input logic[31:0] expected,input logic[3:0] st,input int delay_cycles);
        repeat(delay_cycles) @(negedge clk);
        s.wready=1;
        do @(posedge clk); while(!a.wvalid);
        if(a.wdata !== expected || a.wstrb !== st) $fatal(1,"bridge W payload");
        @(negedge clk); s.wready=0;
    endtask
    task automatic get_result(input logic[31:0] expected,input bit error_expected);
        while(!rv) @(negedge clk);
        if(rd !== expected || err !== error_expected) $fatal(1,"OBI response mismatch");
        if(gnt) $fatal(1,"OBI grants while completing");
        @(posedge clk); @(negedge clk);
        if(rv) $fatal(1,"duplicate OBI response");
        checks++;
    endtask
    initial begin
        s='0; reset_all();
        for(int n=0;n<32;n++) begin
            start(1,'h4000+4*n,'h12340000+n,4'(n));
            fork
                accept_aw('h4000+4*n,n%6);
                accept_w('h12340000+n,4'(n),(n+3)%7);
            join
            repeat(n%5) @(negedge clk);
            s.bresp=(n%3==0)?2'b10:2'b00; s.bvalid=1;
            do @(posedge clk); while(!a.bready);
            @(negedge clk); s.bvalid=0;
            get_result(0,n%3==0);
            start(0,'h5000+4*n,0,15);
            repeat(n%8) @(negedge clk);
            s.arready=1;
            do @(posedge clk); while(!a.arvalid);
            if(a.araddr !== ('h5000+4*n)) $fatal(1,"bridge AR payload");
            @(negedge clk); s.arready=0;
            repeat(n%7) @(negedge clk);
            s.rdata='hdead0000+n; s.rresp=(n%4==0)?3:0; s.rvalid=1;
            do @(posedge clk); while(!a.rready);
            @(negedge clk); s.rvalid=0;
            get_result('hdead0000+n,n%4==0);
        end
        // Hold a second OBI request while the first awaits a response.
        start(0,'h6000,0,15);
        s.arready=1;
        do @(posedge clk); while(!a.arvalid);
        @(negedge clk); s.arready=0; req=1; we=0; addr='h6004;
        repeat(5) begin @(posedge clk); if(gnt) $fatal(1,"early OBI grant"); end
        @(negedge clk); s.rvalid=1; s.rresp=0; s.rdata=11;
        do @(posedge clk); while(!a.rready);
        @(negedge clk); s.rvalid=0;
        get_result(11,0);
        do @(posedge clk); while(!gnt);
        @(negedge clk); req=0; s.arready=1;
        do @(posedge clk); while(!a.arvalid);
        if(a.araddr !== 'h6004) $fatal(1,"held request lost");
        @(negedge clk); s.arready=0; s.rvalid=1; s.rdata=22;
        do @(posedge clk); while(!a.rready);
        @(negedge clk); s.rvalid=0;
        get_result(22,0);
        // Reset before accepting a write and during a read response wait.
        start(1,'h4000,42,15); reset_all();
        if(a.awvalid || a.wvalid || rv) $fatal(1,"reset write");
        start(0,'h4000,0,15); s.arready=1;
        do @(posedge clk); while(!a.arvalid);
        reset_all();
        repeat(8) @(negedge clk);
        if(rv || a.rready || a.arvalid) $fatal(1,"reset read");
        $display("PASS tb_bridge checks=%0d",checks); $finish;
    end
    initial begin #1000000; $fatal(1,"bridge timeout"); end
endmodule
