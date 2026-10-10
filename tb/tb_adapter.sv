`timescale 1ns/1ps
module tb_adapter;
    import axi_lite_pkg::*;
    logic clk=0,rst=0;
    always #5 clk=~clk;
    axil_req_t a;
    axil_rsp_t s;
    wire req,we;
    wire[31:0] addr,wd;
    wire[3:0] be;
    logic gnt,rv;
    logic[31:0] rd;
    logic pending=0, rv_q=0;
    logic[31:0] storage=0, response_q=0;
    int grant_delay=0, response_delay=0, waited=0, remaining=0;
    bit immediate=0;
    int accepted=0,checks=0;
    logic[31:0] expected=0;
    assign gnt = rst && req && !pending && waited>=grant_delay;
    assign rv = immediate ? gnt : rv_q;
    assign rd = immediate ? storage : response_q;
    axi_lite_to_local dut(clk,rst,a,s,req,we,addr,wd,be,gnt,rv,rd);
    axi_lite_checker checker_i(clk,rst,a,s);
    always @(posedge clk) begin
        if(!rst) begin
            pending<=0; rv_q<=0; waited<=0; remaining<=0; storage<=0; accepted<=0;
        end else begin
            rv_q<=0;
            if(req && !gnt) waited<=waited+1;
            if(gnt) begin
                accepted<=accepted+1; waited<=0;
                if(addr !== 32'h1234) $fatal(1,"adapter changed local address");
                if(we) for(int b=0;b<4;b++) if(be[b]) storage[b*8+:8]<=wd[b*8+:8];
                response_q<=storage;
                if(!immediate) begin pending<=1; remaining<=response_delay; end
            end else if(pending) begin
                if(remaining==0) begin pending<=0; rv_q<=1; end
                else remaining<=remaining-1;
            end
        end
    end
    task automatic reset_all;
        @(negedge clk); rst=0; a='0;
        repeat(3) @(negedge clk);
        rst=1;
    endtask
    task automatic send_aw;
        @(negedge clk); a.awaddr='h1234; a.awvalid=1;
        do @(posedge clk); while(!s.awready);
        @(negedge clk); a.awvalid=0;
    endtask
    task automatic send_w(input logic[31:0] d,input logic[3:0] mask);
        @(negedge clk); a.wdata=d; a.wstrb=mask; a.wvalid=1;
        do @(posedge clk); while(!s.wready);
        @(negedge clk); a.wvalid=0;
    endtask
    task automatic read_start;
        @(negedge clk); a.araddr='h1234; a.arvalid=1;
        do @(posedge clk); while(!s.arready);
        @(negedge clk); a.arvalid=0;
    endtask
    task automatic read_finish(input logic[31:0] value);
        while(!s.rvalid) @(negedge clk);
        repeat(4) @(negedge clk);
        if(s.rdata !== value || s.rresp !== 0) $fatal(1,"adapter read mismatch");
        a.rready=1;
        @(posedge clk); @(negedge clk); a.rready=0;
        checks++;
    endtask
    initial begin
        a='0; reset_all();
        for(int n=0;n<32;n++) begin
            automatic logic[31:0] data;
            automatic logic[3:0] mask;
            data=32'hbada0123 ^ (n*32'h10203); mask=4'(n);
            grant_delay=n%5; response_delay=n%7; immediate=n%3==0;
            fork
                begin if(n%2) repeat(5) @(negedge clk); send_aw(); end
                begin if(!(n%2)) repeat(5) @(negedge clk); send_w(data,mask); end
            join
            while(!s.bvalid) @(negedge clk);
            repeat(3) @(negedge clk);
            if(s.bresp !== 0) $fatal(1,"adapter write status");
            a.bready=1;
            @(posedge clk); @(negedge clk); a.bready=0;
            for(int k=0;k<4;k++) if(mask[k]) expected[k*8+:8]=data[k*8+:8];
            checks++;
            read_start(); read_finish(expected);
        end
        if(accepted!==64) $fatal(1,"adapter duplicate/missing local requests");
        // Reset while waiting for grant.
        grant_delay=100; immediate=0;
        read_start();
        while(!req) @(negedge clk);
        reset_all();
        // Reset after local acceptance, before local response.
        grant_delay=0; response_delay=100;
        read_start();
        while(!pending) @(negedge clk);
        reset_all();
        response_delay=0;
        read_start(); read_finish(0);
        $display("PASS tb_adapter checks=%0d",checks); $finish;
    end
    initial begin #1000000; $fatal(1,"adapter timeout"); end
endmodule
