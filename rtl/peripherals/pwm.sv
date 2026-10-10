`timescale 1ns/1ps
module pwm (
    input logic clk_i,
    input logic rst_ni,
    input logic enable_i,
    input logic [31:0] period_i, // Number of clock cycles per PWM period.
    input logic [31:0] high_i,   // Number of high cycles, clamped to period.
    output logic pwm_o,
    output logic period_start_o
);
    logic running;
    logic [31:0] count;
    logic [31:0] period_q, high_q;

    // All inputs belong to clk_i domain. Configuration is sampled only when
    // starting or wrapping a period. Output is registered (no comparator glitches).
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            running <= 0;
            count <= 0;
            period_q <= 0;
            high_q <= 0;
            pwm_o <= 0;
            period_start_o <= 0;
        end else begin
            period_start_o <= 0;
            if (!enable_i) begin
                running <= 0;
                count <= 0;
                pwm_o <= 0;
            end else if (!running || count == period_q - 32'd1) begin
                count <= 0;
                period_q <= period_i;
                high_q <= (high_i > period_i) ? period_i : high_i;
                if (period_i == 0) begin
                    running <= 0;
                    pwm_o <= 0;
                end else begin
                    running <= 1;
                    period_start_o <= 1;
                    pwm_o <= high_i != 0;
                end
            end else begin
                count <= count + 32'd1;
                pwm_o <= (count + 32'd1) < high_q;
            end
        end
    end
endmodule
