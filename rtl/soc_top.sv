`timescale 1ns/1ps

module soc_top #(
    parameter logic [31:0] BOOT_ADDR = 32'h0000_1000,
    parameter INIT_FILE = "program.hex"
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        fetch_enable_i,

    output wire         instr_req,
    output wire [31:0]  instr_addr,
    output wire         instr_gnt,
    output wire         instr_rvalid,
    output wire [31:0]  instr_rdata,

    output wire         data_req
);

    // Çekirdek ile veri RAM'i arasındaki bağlantılar
    wire        data_gnt;
    wire        data_rvalid;
    wire [31:0] data_rdata;
    wire        data_we;
    wire [3:0]  data_be;
    wire [31:0] data_addr;
    wire [31:0] data_wdata;

    cv32e40p_top #(
        .COREV_PULP   (0),
        .COREV_CLUSTER(0),
        .FPU         (0),
        .ZFINX       (0)
    ) u_cpu (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .pulp_clock_en_i(1'b0),
        .scan_cg_en_i   (1'b0),

        .boot_addr_i        (BOOT_ADDR),
        .mtvec_addr_i       (BOOT_ADDR),
        .dm_halt_addr_i     (BOOT_ADDR),
        .dm_exception_addr_i(BOOT_ADDR),
        .hart_id_i          (32'b0),

        // Program belleği bağlantıları
        .instr_req_o   (instr_req),
        .instr_addr_o  (instr_addr),
        .instr_gnt_i   (instr_gnt),
        .instr_rvalid_i(instr_rvalid),
        .instr_rdata_i (instr_rdata),

        // Veri RAM'i bağlantıları
        .data_req_o   (data_req),
        .data_gnt_i   (data_gnt),
        .data_rvalid_i(data_rvalid),
        .data_rdata_i (data_rdata),
        .data_we_o    (data_we),
        .data_be_o    (data_be),
        .data_addr_o  (data_addr),
        .data_wdata_o (data_wdata),

        .irq_i    (32'b0),
        .irq_ack_o(),
        .irq_id_o (),

        .debug_req_i      (1'b0),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (),

        .fetch_enable_i(fetch_enable_i),
        .core_sleep_o  ()
    );

    // Program belleği
    imem_8kb #(
        .BASE_ADDR(BOOT_ADDR),
        .INIT_FILE(INIT_FILE)
    ) u_imem (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .instr_req_i   (instr_req),
        .instr_addr_i  (instr_addr),
        .instr_gnt_o   (instr_gnt),
        .instr_rvalid_o(instr_rvalid),
        .instr_rdata_o (instr_rdata)
    );

    // Veri RAM'i: 0x4000-0x5FFF
    dmem_8kb u_dmem (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .data_req_i   (data_req),
        .data_addr_i  (data_addr),
        .data_we_i    (data_we),
        .data_be_i    (data_be),
        .data_wdata_i (data_wdata),
        .data_gnt_o   (data_gnt),
        .data_rvalid_o(data_rvalid),
        .data_rdata_o (data_rdata)
    );

endmodule