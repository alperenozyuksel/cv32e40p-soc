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

    output wire         data_req,
    input  logic [15:0]  gpio_in_i,
    output wire  [15:0]  gpio_out_o,
    output logic        bus_error_o,
    output wire         pwm_o
);

    // Çekirdek ile veri RAM'i arasındaki bağlantılar
    wire        data_gnt;
    wire        data_rvalid;
    wire [31:0] data_rdata;
    wire        data_we;
    wire [3:0]  data_be;
    wire [31:0] data_addr;
    wire [31:0] data_wdata;

    import axi_lite_pkg::*;
    axil_req_t cpu_axi_req;
    axil_rsp_t cpu_axi_rsp;
    axil_req_t peripheral_axi_req [4];
    axil_rsp_t peripheral_axi_rsp [4];
    wire [3:0] local_req, local_we, local_gnt, local_rvalid;
    wire [31:0] local_addr [4];
    wire [31:0] local_wdata [4];
    wire [31:0] local_rdata [4];
    wire [3:0] local_be [4];
    wire bridge_error;

    // CV32E40P has no data-error input. Expose sticky error status to the top.
    // This does not generate a CPU exception; see docs/axi.md.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) bus_error_o <= 1'b0;
        else if (data_rvalid && bridge_error) bus_error_o <= 1'b1;
    end

    obi_to_axi_lite u_obi_bridge (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .req_i(data_req), .we_i(data_we), .addr_i(data_addr),
        .wdata_i(data_wdata), .be_i(data_be),
        .gnt_o(data_gnt), .rvalid_o(data_rvalid), .rdata_o(data_rdata),
        .error_o(bridge_error), .axi_o(cpu_axi_req), .axi_i(cpu_axi_rsp)
    );

    axi_lite_interconnect #(
        .N(4),
        .BASE_ADDR('{32'h4000,32'h10000,32'h11000,32'h12000}),
        .END_ADDR ('{32'h6000,32'h11000,32'h12000,32'h13000})
    ) u_axi_interconnect (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .s_axi_i(cpu_axi_req), .s_axi_o(cpu_axi_rsp),
        .m_axi_o(peripheral_axi_req), .m_axi_i(peripheral_axi_rsp)
    );

    for (genvar i = 0; i < 4; i++) begin : gen_axi_adapter
        axi_lite_to_local u_adapter (
            .clk_i(clk_i), .rst_ni(rst_ni),
            .axi_i(peripheral_axi_req[i]), .axi_o(peripheral_axi_rsp[i]),
            .req_o(local_req[i]), .we_o(local_we[i]),
            .addr_o(local_addr[i]), .wdata_o(local_wdata[i]), .be_o(local_be[i]),
            .gnt_i(local_gnt[i]), .rvalid_i(local_rvalid[i]),
            .rdata_i(local_rdata[i])
        );
    end

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

        // OBI veri portu, AXI4-Lite köprüsüne bağlıdır.
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
        .data_req_i   (local_req[0]),
        .data_addr_i  (local_addr[0]),
        .data_we_i    (local_we[0]),
        .data_be_i    (local_be[0]),
        .data_wdata_i (local_wdata[0]),
        .data_gnt_o   (local_gnt[0]),
        .data_rvalid_o(local_rvalid[0]),
        .data_rdata_o (local_rdata[0])
    );

    gpio u_gpio (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .req_i(local_req[1]), .addr_i(local_addr[1]), .we_i(local_we[1]),
        .be_i(local_be[1]), .wdata_i(local_wdata[1]),
        .gnt_o(local_gnt[1]), .rvalid_o(local_rvalid[1]), .rdata_o(local_rdata[1]),
        .gpio_in_i(gpio_in_i), .gpio_out_o(gpio_out_o)
    );

    pwm_regs u_pwm (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .req_i(local_req[3]), .addr_i(local_addr[3]), .we_i(local_we[3]),
        .be_i(local_be[3]), .wdata_i(local_wdata[3]),
        .gnt_o(local_gnt[3]), .rvalid_o(local_rvalid[3]), .rdata_o(local_rdata[3]),
        .pwm_o(pwm_o)
    );

    timer u_timer (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .req_i(local_req[2]), .addr_i(local_addr[2]), .we_i(local_we[2]),
        .be_i(local_be[2]), .wdata_i(local_wdata[2]),
        .gnt_o(local_gnt[2]), .rvalid_o(local_rvalid[2]), .rdata_o(local_rdata[2])
    );

endmodule
