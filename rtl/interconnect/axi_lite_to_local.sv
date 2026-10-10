module axi_lite_to_local (
    input logic clk_i, rst_ni,
    input axi_lite_pkg::axil_req_t axi_i,
    output axi_lite_pkg::axil_rsp_t axi_o,
    output logic req_o, we_o,
    output logic [31:0] addr_o, wdata_o,
    output logic [3:0] be_o,
    input logic gnt_i, rvalid_i,
    input logic [31:0] rdata_i
);
    typedef enum logic [2:0] {IDLE, LOCAL_REQ, LOCAL_WAIT, WRITE_RESP, READ_RESP} state_t;
    state_t state;
    logic aw_full, w_full, ar_full, prefer_read;
    logic [31:0] awaddr_q, wdata_q, araddr_q, response_q;
    logic [3:0] wstrb_q;

    always_comb begin
        axi_o = '0;
        axi_o.awready = rst_ni && state == IDLE && !aw_full;
        axi_o.wready = rst_ni && state == IDLE && !w_full;
        axi_o.arready = rst_ni && state == IDLE && !ar_full;
        axi_o.bvalid = rst_ni && state == WRITE_RESP;
        axi_o.rvalid = rst_ni && state == READ_RESP;
        axi_o.rdata = response_q;
        req_o = rst_ni && state == LOCAL_REQ;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state <= IDLE;
            aw_full <= 0; w_full <= 0; ar_full <= 0; prefer_read <= 0;
            awaddr_q <= '0; wdata_q <= '0; araddr_q <= '0;
            wstrb_q <= '0; response_q <= '0;
            addr_o <= '0; wdata_o <= '0; be_o <= '0; we_o <= 0;
        end else begin
            // AW and W may arrive in either order, including different cycles.
            if (axi_i.awvalid && axi_o.awready) begin
                awaddr_q <= axi_i.awaddr;
                aw_full <= 1;
            end
            if (axi_i.wvalid && axi_o.wready) begin
                wdata_q <= axi_i.wdata;
                wstrb_q <= axi_i.wstrb;
                w_full <= 1;
            end
            if (axi_i.arvalid && axi_o.arready) begin
                araddr_q <= axi_i.araddr;
                ar_full <= 1;
            end
            case (state)
                IDLE: begin
                    if (aw_full && w_full && (!ar_full || !prefer_read)) begin
                        addr_o <= awaddr_q;
                        wdata_o <= wdata_q;
                        be_o <= wstrb_q;
                        we_o <= 1;
                        aw_full <= 0; w_full <= 0; prefer_read <= 1;
                        state <= LOCAL_REQ;
                    end else if (ar_full) begin
                        addr_o <= araddr_q;
                        wdata_o <= '0;
                        be_o <= 4'hf;
                        we_o <= 0;
                        ar_full <= 0; prefer_read <= 0;
                        state <= LOCAL_REQ;
                    end
                end
                LOCAL_REQ: if (gnt_i) begin
                    // Support either same-cycle or registered local response.
                    if (rvalid_i) begin
                        response_q <= we_o ? 32'b0 : rdata_i;
                        state <= we_o ? WRITE_RESP : READ_RESP;
                    end else state <= LOCAL_WAIT;
                end
                LOCAL_WAIT: if (rvalid_i) begin
                    response_q <= we_o ? 32'b0 : rdata_i;
                    state <= we_o ? WRITE_RESP : READ_RESP;
                end
                WRITE_RESP: if (axi_i.bready) state <= IDLE;
                READ_RESP: if (axi_i.rready) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
    // PROT is intentionally ignored: this peripheral bank has no access policy.
endmodule
