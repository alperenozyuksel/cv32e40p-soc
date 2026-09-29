`timescale 1ns/1ps
module tb_soc;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic fetch_enable = 0;
    wire instr_req, instr_gnt, instr_rvalid, data_req;
    wire [31:0] instr_addr, instr_rdata;

    // Vivado stages program.hex from the simulation fileset.
    soc_top #(
        .BOOT_ADDR(32'h0000_1000),
        .INIT_FILE("program.hex")
    ) dut (
        .clk_i(clk), .rst_ni(rst_n), .fetch_enable_i(fetch_enable),
        .instr_req(instr_req), .instr_addr(instr_addr),
        .instr_gnt(instr_gnt), .instr_rvalid(instr_rvalid),
        .instr_rdata(instr_rdata), .data_req(data_req)
    );

    // Simulation-only probes into the downloaded FF register-file version.
    // A future core revision may require updating these hierarchy paths.
    wire [31:0] x1 = dut.u_cpu.core_i.id_stage_i.register_file_i.mem[1];
    wire [31:0] x2 = dut.u_cpu.core_i.id_stage_i.register_file_i.mem[2];
    wire [31:0] x3 = dut.u_cpu.core_i.id_stage_i.register_file_i.mem[3];
    wire [31:0] pc_id = dut.u_cpu.core_i.pc_id;
    integer accepted = 0;

    always @(posedge clk) begin
        if (!rst_n) begin
            accepted = 0;
        end else begin
            if (data_req !== 1'b0)
                $fatal(1, "Unexpected data access: this test program uses registers only");
            if (instr_req && instr_gnt) begin
                if (accepted == 0 && instr_addr !== 32'h1000)
                    $fatal(1, "Wrong first fetch address: %h", instr_addr);
                if (instr_addr < 32'h1000 || instr_addr >= 32'h3000 || instr_addr[1:0] != 0)
                    $fatal(1, "Invalid instruction address: %h", instr_addr);
                accepted = accepted + 1;
            end
        end
    end

    task automatic boot_and_check(input integer attempt);
        integer cycles;
        integer loop_hits;
        begin
            @(negedge clk); rst_n = 0; fetch_enable = 0;
            repeat (4) @(negedge clk);
            if (x1 !== 0 || x2 !== 0 || x3 !== 0)
                $fatal(1, "Register reset failed");
            rst_n = 1;
            // Verify that releasing reset alone does not start fetch.
            repeat (3) begin
                @(negedge clk);
                if (instr_req !== 0) $fatal(1, "Fetch before enable");
            end
            fetch_enable = 1;
            cycles = 0;
            while (x3 !== 32'd12 && cycles < 200) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (x1 !== 32'd5 || x2 !== 32'd7 || x3 !== 32'd12)
                $fatal(1, "Arithmetic failed: x1=%h x2=%h x3=%h", x1, x2, x3);
            loop_hits = 0;
            repeat (30) begin
                @(negedge clk);
                if (pc_id == 32'h100c) loop_hits = loop_hits + 1;
                if (x1 !== 5 || x2 !== 7 || x3 !== 12)
                    $fatal(1, "Registers changed after entering loop");
            end
            if (loop_hits == 0 || accepted < 4)
                $fatal(1, "Program did not reach final loop");
            $display("BOOT %0d PASS: x1=%0d x2=%0d x3=%0d; fetches=%0d", attempt, x1, x2, x3, accepted);
        end
    endtask

    initial begin
        boot_and_check(1);
        boot_and_check(2);
        $display("PASS: CV32E40P executed 5 + 7 = 12, looped, and restarted after reset");
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Simulation timeout");
    end
endmodule
