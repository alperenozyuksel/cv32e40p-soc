`timescale 1ns/1ps
module tb_imem_8kb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic req = 0;
    logic [31:0] addr = 0;
    wire gnt, rvalid;
    wire [31:0] rdata;
    integer checks = 0;

    // Nonzero base tests byte-address to word-index translation.
    imem_8kb #(.BASE_ADDR(32'h1000), .INIT_FILE("program.hex")) dut (
        .clk_i(clk), .rst_ni(rst_n), .instr_req_i(req),
        .instr_addr_i(addr), .instr_gnt_o(gnt),
        .instr_rvalid_o(rvalid), .instr_rdata_o(rdata)
    );

    task automatic read_check(input logic [31:0] a, expected);
        @(negedge clk);
        addr = a;
        req = 1;
        #1;
        if (!gnt) $fatal(1, "Expected grant at address %h", a);
        @(posedge clk);
        #1;
        if (!rvalid || rdata !== expected)
            $fatal(1, "Read %h: expected %h, got %h valid=%b", a, expected, rdata, rvalid);
        if (gnt) $fatal(1, "Accepted a second request during response");
        @(negedge clk);
        req = 0;
        @(posedge clk);
        #1;
        if (rvalid) $fatal(1, "Response exceeded one cycle");
        checks = checks + 1;
    endtask

    initial begin
        $dumpfile("imem.vcd");
        $dumpvars(0, tb_imem_8kb);
        repeat (2) @(negedge clk);
        if (gnt || rvalid) $fatal(1, "Activity during reset");
        rst_n = 1;
        read_check(32'h1000, 32'h00500093);
        read_check(32'h1004, 32'h00700113);
        read_check(32'h1008, 32'h002081b3);
        read_check(32'h100c, 32'h0000006f);
        read_check(32'h1010, 32'h00000013);
        read_check(32'h2ffc, 32'h00000013);
        read_check(32'h3000, 32'h00000000);
        read_check(32'h0ffc, 32'h00000000);
        read_check(32'h1002, 32'h00000000);

        // A requester holds its next request while the memory is busy.
        @(negedge clk); req = 1; addr = 32'h1000;
        @(posedge clk); #1;
        if (!rvalid || rdata !== 32'h00500093) $fatal(1, "Stream first response");
        @(negedge clk); addr = 32'h1004;
        #1;
        if (gnt) $fatal(1, "Expected backpressure");
        @(posedge clk); #1;
        if (rvalid || !gnt) $fatal(1, "Expected ready for next request");
        @(posedge clk); #1;
        if (!rvalid || rdata !== 32'h00700113) $fatal(1, "Stream second response");
        @(negedge clk); req = 0;
        @(posedge clk); #1;
        if (rvalid) $fatal(1, "Duplicate response");
        checks = checks + 1;

        // Reset cancels a response and leaves initialized program contents intact.
        @(negedge clk); req = 1; addr = 32'h1000;
        @(posedge clk); #1;
        rst_n = 0;
        #1;
        if (rvalid || gnt) $fatal(1, "Reset did not clear interface");
        @(negedge clk); req = 0;
        @(negedge clk); rst_n = 1;
        read_check(32'h1000, 32'h00500093);
        repeat (3) begin
            @(posedge clk); #1;
            if (rvalid || gnt) $fatal(1, "Unsolicited idle activity");
        end
        $display("PASS: %0d checks; image, bounds, alignment, backpressure, reset, idle", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
