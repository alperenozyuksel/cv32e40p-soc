`timescale 1ns/1ps
// AXI4-Lite connects through the shared axi_lite_to_local adapter.
module pwm_regs (
    input logic clk_i, rst_ni,
    input logic req_i, we_i,
    input logic [31:0] addr_i, wdata_i,
    input logic [3:0] be_i,
    output logic gnt_o, rvalid_o,
    output logic [31:0] rdata_o,
    output wire pwm_o
);
    logic enable_q;
    logic [31:0] period_q, high_q;
    wire period_start;
    assign gnt_o = rst_ni && req_i &&
                   addr_i >= 32'h12000 && addr_i < 32'h13000;
    pwm u_pwm (
        .clk_i(clk_i), .rst_ni(rst_ni), .enable_i(enable_q),
        .period_i(period_q), .high_i(high_q),
        .pwm_o(pwm_o), .period_start_o(period_start)
    );
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            enable_q <= 0;
            period_q <= 0;
            high_q <= 0;
            rvalid_o <= 0;
            rdata_o <= 0;
        end else begin
            rvalid_o <= 0;
            if (req_i && gnt_o) begin
                rvalid_o <= 1;
                rdata_o <= 0;
                if (we_i) begin
                    case (addr_i[11:2])
                        0: if (be_i[0]) enable_q <= wdata_i[0];
                        1: for (int b=0;b<4;b++)
                            if (be_i[b]) period_q[b*8+:8] <= wdata_i[b*8+:8];
                        2: for (int b=0;b<4;b++)
                            if (be_i[b]) high_q[b*8+:8] <= wdata_i[b*8+:8];
                        default: ;
                    endcase
                end else begin
                    case (addr_i[11:2])
                        0: rdata_o <= {31'b0,enable_q};
                        1: rdata_o <= period_q;
                        2: rdata_o <= high_q;
                        3: rdata_o <= {31'b0,pwm_o};
                        default: rdata_o <= 0;
                    endcase
                end
            end
        end
    end
endmodule
