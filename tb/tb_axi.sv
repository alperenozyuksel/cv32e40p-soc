`timescale 1ns/1ps
module tb_axi;
    import axi_lite_pkg::*;
    logic clk=0,rst=0;
    always #5 clk=~clk;
    axil_req_t master, targets[3];
    axil_rsp_t response, replies[3];
    wire [2:0] req,we,gnt,rv;
    wire [31:0] addr[3],wd[3],rd[3];
    wire [3:0] be[3];
    logic [15:0] pins=16'h5aa5;
    wire [15:0] outputs;
    int checks=0;
    logic[31:0] model[32],v;
    int unsigned rng=32'habcdef01;
    function automatic int unsigned random32();
        rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5); return rng;
    endfunction
    axi_lite_interconnect dut(clk,rst,master,response,targets,replies);
    axi_lite_checker upstream(clk,rst,master,response);
    for(genvar i=0;i<3;i++) begin : ports
        axi_lite_to_local adapter(clk,rst,targets[i],replies[i],
            req[i],we[i],addr[i],wd[i],be[i],gnt[i],rv[i],rd[i]);
        axi_lite_checker checker_i(clk,rst,targets[i],replies[i]);
    end
    dmem_8kb ram(clk,rst,req[0],addr[0],we[0],be[0],wd[0],gnt[0],rv[0],rd[0]);
    gpio gpio_dut(clk,rst,req[1],addr[1],we[1],be[1],wd[1],gnt[1],rv[1],rd[1],pins,outputs);
    timer tim(clk,rst,req[2],addr[2],we[2],be[2],wd[2],gnt[2],rv[2],rd[2]);

    task automatic aw(input logic[31:0] a,input int delay_cycles);
        repeat(delay_cycles) @(negedge clk);
        @(negedge clk); master.awvalid=1; master.awaddr=a; master.awprot=3'b010;
        do @(posedge clk); while(!response.awready);
        @(negedge clk); master.awvalid=0; master.awaddr='1;
    endtask
    task automatic w(input logic[31:0] d,input logic[3:0] st,input int delay_cycles);
        repeat(delay_cycles) @(negedge clk);
        @(negedge clk); master.wvalid=1; master.wdata=d; master.wstrb=st;
        do @(posedge clk); while(!response.wready);
        @(negedge clk); master.wvalid=0; master.wdata='1;
    endtask
    task automatic b(input logic[1:0] expected,input int stall);
        // READY intentionally waits for VALID to check no response deadlock.
        while(!response.bvalid) @(negedge clk);
        repeat(stall) @(negedge clk);
        if(response.bresp !== expected) $fatal(1,"BRESP mismatch");
        master.bready=1;
        @(posedge clk); @(negedge clk); master.bready=0;
        checks++;
    endtask
    task automatic wr(input logic[31:0] a,d,input logic[3:0] st,
                      input int ad,dd,stall,input logic[1:0] expected);
        fork aw(a,ad); w(d,st,dd); b(expected,stall); join
    endtask
    task automatic ar(input logic[31:0] a,input int delay_cycles);
        repeat(delay_cycles) @(negedge clk);
        @(negedge clk); master.arvalid=1; master.araddr=a; master.arprot=3'b001;
        do @(posedge clk); while(!response.arready);
        @(negedge clk); master.arvalid=0; master.araddr='1;
    endtask
    task automatic r(input logic[31:0] expected,input logic[1:0] status,input int stall);
        while(!response.rvalid) @(negedge clk);
        repeat(stall) @(negedge clk);
        if(response.rresp !== status || response.rdata !== expected)
            $fatal(1,"R expected %h/%b got %h/%b",expected,status,response.rdata,response.rresp);
        master.rready=1;
        @(posedge clk); @(negedge clk); master.rready=0;
        checks++;
    endtask
    task automatic read_eq(input logic[31:0] a,expected,input int stall,input logic[1:0] status);
        fork ar(a,0); r(expected,status,stall); join
    endtask
    task automatic reset_all;
        @(negedge clk); rst=0; master='0;
        repeat(3) @(negedge clk);
        rst=1;
        repeat(2) @(negedge clk);
        if(response.rvalid || response.bvalid) $fatal(1,"stale AXI response after reset");
    endtask
    initial begin
        master='0; reset_all();
        for(int n=0;n<32;n++) begin
            model[n]=random32();
            wr('h4000+4*n,model[n],15,n%4,(n+2)%5,n%7,0);
        end
        for(int n=0;n<128;n++) begin
            automatic int idx;
            automatic logic[31:0] d;
            automatic logic[3:0] st;
            idx=random32()%32; d=random32(); st=4'(n%16);
            wr('h4000+4*idx,d,st,n%7,(n+3)%7,n%8,0);
            for(int k=0;k<4;k++) if(st[k]) model[idx][8*k+:8]=d[8*k+:8];
            read_eq('h4000+4*idx,model[idx],n%6,0);
        end
        // Concurrent read and write transactions, independent locations/targets.
        fork
            wr('h10004,'h1234,15,0,8,7,0);
            read_eq('h4000,model[0],9,0);
        join
        read_eq('h10004,'h1234,3,0);
        read_eq('h10000,'h5aa5,3,0);
        wr('h11000,17,15,8,0,4,0);
        read_eq('h11000,17,5,0);
        wr('h5ffc,'h12345678,15,0,0,0,0);
        read_eq('h5ffc,'h12345678,0,0);
        wr('h6000,123,15,0,5,8,3);
        read_eq('h3ffc,0,8,3);
        read_eq('h12000,0,1,3);
        // Reset with only AW, only W, and a held response.
        aw('h4000,0); reset_all();
        w('hdeadbeef,15,0); reset_all();
        fork aw('h4000,0); w('h77777777,15,0); join
        while(!response.bvalid) @(negedge clk);
        reset_all();
        read_eq('h4000,'h77777777,0,0); // committed side effect survives reset
        ar('h4000,0);
        while(!response.rvalid) @(negedge clk);
        reset_all();
        read_eq('h4000,'h77777777,2,0);
        repeat(20) @(negedge clk);
        if(response.rvalid || response.bvalid) $fatal(1,"duplicate response");
        $display("PASS tb_axi checks=%0d seed=abcdef01",checks); $finish;
    end
    initial begin #1000000; $fatal(1,"timeout AXI"); end
endmodule
