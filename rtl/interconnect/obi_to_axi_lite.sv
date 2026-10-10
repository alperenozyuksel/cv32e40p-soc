module obi_to_axi_lite (
    input logic clk_i, rst_ni,
    input logic req_i, we_i,
    input logic [31:0] addr_i, wdata_i,
    input logic [3:0] be_i,
    output logic gnt_o, rvalid_o,
    output logic [31:0] rdata_o,
    output logic error_o,
    output axi_lite_pkg::axil_req_t axi_o,
    input axi_lite_pkg::axil_rsp_t axi_i
);
    typedef enum logic [2:0] {IDLE, WRITE_SEND, WRITE_RESP,
                              READ_SEND, READ_RESP, COMPLETE} state_t;
    state_t state;
    logic [31:0] addr_q, wdata_q;
    logic [3:0] be_q;
    logic aw_done, w_done;

    assign gnt_o = rst_ni && state == IDLE && req_i;
    assign rvalid_o = rst_ni && state == COMPLETE;

    always_comb begin
        axi_o = '0;
        axi_o.awaddr = addr_q;
        axi_o.wdata = wdata_q;
        axi_o.wstrb = be_q;
        axi_o.araddr = addr_q;
        if (rst_ni) begin
            axi_o.awvalid = state == WRITE_SEND && !aw_done;
            axi_o.wvalid = state == WRITE_SEND && !w_done;
            axi_o.bready = state == WRITE_RESP;
            axi_o.arvalid = state == READ_SEND;
            axi_o.rready = state == READ_RESP;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state <= IDLE;
            addr_q <= '0;
            wdata_q <= '0;
            be_q <= '0;
            aw_done <= 0;
            w_done <= 0;
            rdata_o <= '0;
            error_o <= 0;
        end else begin
            case (state)
                IDLE: if (req_i && gnt_o) begin
                    addr_q <= addr_i;
                    wdata_q <= wdata_i;
                    be_q <= be_i;
                    aw_done <= 0;
                    w_done <= 0;
                    error_o <= 0;
                    state <= we_i ? WRITE_SEND : READ_SEND;
                end
                WRITE_SEND: begin
                    if (axi_o.awvalid && axi_i.awready) aw_done <= 1;
                    if (axi_o.wvalid && axi_i.wready) w_done <= 1;
                    if ((aw_done || axi_i.awready) && (w_done || axi_i.wready))
                        state <= WRITE_RESP;
                end
                WRITE_RESP: if (axi_i.bvalid && axi_o.bready) begin
                    rdata_o <= '0;
                    error_o <= axi_i.bresp != 2'b00;
                    state <= COMPLETE;
                end
                READ_SEND: if (axi_o.arvalid && axi_i.arready) state <= READ_RESP;
                READ_RESP: if (axi_i.rvalid && axi_o.rready) begin
                    rdata_o <= axi_i.rdata;
                    error_o <= axi_i.rresp != 2'b00;
                    state <= COMPLETE;
                end
                COMPLETE: state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
