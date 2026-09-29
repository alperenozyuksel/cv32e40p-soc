`timescale 1ns/1ps

// Read-only instruction memory for initial CV32E40P simulation experiments.
// 2048 words x 32 bits = 8192 bytes. Not a complete boot-loadable SRAM.
module imem_8kb #(
    parameter logic [31:0] BASE_ADDR = 32'h0000_0000,
    parameter INIT_FILE = ""
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        instr_req_i,
    input  logic [31:0] instr_addr_i,
    output logic        instr_gnt_o,
    output logic        instr_rvalid_o,
    output logic [31:0] instr_rdata_o
);
    localparam integer WORDS = 2048;
    localparam logic [31:0] NOP = 32'h0000_0013;
    logic [31:0] mem [0:WORDS-1];
    logic [31:0] byte_offset;
    logic address_ok;

    // Simulation initialization: unspecified words remain NOPs.
    // HEX entries are 32-bit numeric words, not individual bytes.
    initial begin
        if ((BASE_ADDR[1:0] != 2'b00) || (BASE_ADDR > 32'hffff_e000))
            $fatal(1, "BASE_ADDR must be word aligned and leave room for 8 KiB");
        for (integer i = 0; i < WORDS; i = i + 1)
            mem[i] = NOP;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    assign byte_offset = instr_addr_i - BASE_ADDR;
    assign address_ok = (instr_addr_i >= BASE_ADDR) &&
                        (byte_offset < 32'd8192) &&
                        (instr_addr_i[1:0] == 2'b00);

    // One outstanding request; no new acceptance during the response cycle.
    // Acceptance happens on a rising edge with req && gnt.
    assign instr_gnt_o = rst_ni && instr_req_i && !instr_rvalid_o;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            instr_rvalid_o <= 1'b0;
            instr_rdata_o  <= 32'b0;
        end else begin
            instr_rvalid_o <= 1'b0;
            if (instr_req_i && instr_gnt_o) begin
                instr_rvalid_o <= 1'b1;
                if (address_ok)
                    instr_rdata_o <= mem[byte_offset[12:2]];
                else
                    // No OBI error input exists on this core's fetch port.
                    // Return an illegal instruction, rather than aliasing RAM.
                    instr_rdata_o <= 32'h0000_0000;
            end
        end
    end
endmodule
