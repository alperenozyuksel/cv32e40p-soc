module timer (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        req_i,
    input  logic [31:0] addr_i,
    input  logic        we_i,
    input  logic [3:0]  be_i,
    input  logic [31:0] wdata_i,
    output logic        gnt_o,
    output logic        rvalid_o,
    output logic [31:0] rdata_o
);

    localparam logic [31:0] BASE_ADDR = 32'h0001_1000;
    localparam logic [31:0] END_ADDR  = 32'h0001_2000;

    localparam logic [9:0] PRE = 10'h000;
    localparam logic [9:0] ARE = 10'h001;
    localparam logic [9:0] CLR = 10'h002;
    localparam logic [9:0] ENA = 10'h003;
    localparam logic [9:0] MOD = 10'h004;
    localparam logic [9:0] CNT = 10'h005;
    localparam logic [9:0] EVN = 10'h006;
    localparam logic [9:0] EVC = 10'h007;

    logic [31:0] tim_pre, tim_are, tim_cnt, tim_evn;
    logic tim_clr, tim_ena, tim_mod, tim_evc;
    logic [31:0] prescale_count;
    logic [31:0] next_count;
    logic [9:0] word_offset;
    logic accepted, write_access, pre_write;
    logic clear_count, clear_event, tick;

    assign word_offset = addr_i[11:2];
    assign gnt_o = rst_ni && req_i
                && (addr_i >= BASE_ADDR) && (addr_i < END_ADDR);
    assign accepted = req_i && gnt_o;
    assign write_access = accepted && we_i;
    assign pre_write = write_access && (word_offset == PRE) && (|be_i);

    // Clear bits are stored RW controls, not self-clearing commands.
    // A write to these controls takes effect on the acceptance edge.
    assign clear_count = (write_access && word_offset == CLR && be_i[0])
                       ? wdata_i[0] : tim_clr;
    assign clear_event = (write_access && word_offset == EVC && be_i[0])
                       ? wdata_i[0] : tim_evc;

    // PRE=0: every clock; PRE=1: every two clocks.
    // No derived clock is generated: tick is a clock enable.
    assign tick = tim_ena && !clear_count && !pre_write
               && (prescale_count == tim_pre);
    assign next_count = tim_mod ? (tim_cnt + 32'd1)
                               : (tim_cnt - 32'd1);

    // Software-visible controls and registered bus response.
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            tim_pre  <= 32'b0;
            tim_are  <= 32'b0;
            tim_clr  <= 1'b0;
            tim_ena  <= 1'b0;
            tim_mod  <= 1'b0;
            tim_evc  <= 1'b0;
            rvalid_o <= 1'b0;
            rdata_o  <= 32'b0;
        end
        else begin
            rvalid_o <= 1'b0;
            if (accepted) begin
                rvalid_o <= 1'b1;
                rdata_o  <= 32'b0;
                if (!we_i) begin
                    case (word_offset)
                        PRE: rdata_o <= tim_pre;
                        ARE: rdata_o <= tim_are;
                        CLR: rdata_o <= {31'b0, tim_clr};
                        ENA: rdata_o <= {31'b0, tim_ena};
                        MOD: rdata_o <= {31'b0, tim_mod};
                        CNT: rdata_o <= tim_cnt;
                        EVN: rdata_o <= tim_evn;
                        EVC: rdata_o <= {31'b0, tim_evc};
                        default: rdata_o <= 32'b0;
                    endcase
                end
                else begin
                    case (word_offset)
                        PRE: begin
                            for (int b = 0; b < 4; b++) begin
                                if (be_i[b])
                                    tim_pre[b*8 +: 8] <= wdata_i[b*8 +: 8];
                            end
                        end
                        ARE: begin
                            for (int b = 0; b < 4; b++) begin
                                if (be_i[b])
                                    tim_are[b*8 +: 8] <= wdata_i[b*8 +: 8];
                            end
                        end
                        CLR: if (be_i[0]) tim_clr <= wdata_i[0];
                        ENA: if (be_i[0]) tim_ena <= wdata_i[0];
                        MOD: if (be_i[0]) tim_mod <= wdata_i[0];
                        EVC: if (be_i[0]) tim_evc <= wdata_i[0];
                        default: begin end // RO/reserved writes have no effect.
                    endcase
                end
            end
        end
    end

    // Counter datapath. Synchronous active-low reset.
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            prescale_count <= 32'b0;
            tim_cnt <= 32'b0;
            tim_evn <= 32'b0;
        end
        else begin
            if (clear_count || pre_write)
                prescale_count <= 32'b0;
            else if (tim_ena) begin
                if (tick) prescale_count <= 32'b0;
                else      prescale_count <= prescale_count + 32'd1;
            end

            // Clear works even while disabled. Disable holds the counter.
            if (clear_count)
                tim_cnt <= 32'b0;
            else if (tick) begin
                if (tim_cnt == tim_are) tim_cnt <= 32'b0;
                else                    tim_cnt <= next_count;
            end

            // Count arrivals at ARE, not the following automatic reset.
            // Explicit event clear wins over a simultaneous event.
            if (clear_event)
                tim_evn <= 32'b0;
            else if (tick && (tim_cnt != tim_are) && (next_count == tim_are))
                tim_evn <= tim_evn + 32'd1;
        end
    end

endmodule
