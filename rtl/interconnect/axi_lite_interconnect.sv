module axi_lite_interconnect #(
    parameter int N = 3,
    parameter logic [31:0] BASE_ADDR [N] =
        '{32'h0000_4000, 32'h0001_0000, 32'h0001_1000},
    parameter logic [31:0] END_ADDR [N] =
        '{32'h0000_6000, 32'h0001_1000, 32'h0001_2000}
) (
    input logic clk_i, rst_ni,
    input axi_lite_pkg::axil_req_t s_axi_i,
    output axi_lite_pkg::axil_rsp_t s_axi_o,
    output axi_lite_pkg::axil_req_t m_axi_o [N],
    input axi_lite_pkg::axil_rsp_t m_axi_i [N]
);
    typedef enum logic [2:0] {IDLE, WRITE_SEND, WRITE_WAIT, WRITE_RESP,
                              READ_SEND, READ_WAIT, READ_RESP} state_t;
    state_t state;
    localparam int SEL_W = (N > 1) ? $clog2(N) : 1;
    logic [SEL_W-1:0] target;
    logic aw_full, w_full, ar_full, prefer_read;
    logic aw_done, w_done;
    logic [31:0] awaddr_q, araddr_q, wdata_q;
    logic [2:0] awprot_q, arprot_q;
    logic [3:0] wstrb_q;
    logic [31:0] addr_q, data_q, response_data;
    logic [2:0] prot_q;
    logic [3:0] strb_q;
    logic [1:0] response_code;

    function automatic integer decode(input logic [31:0] address);
        decode = -1;
        for (int i = 0; i < N; i++)
            if (address >= BASE_ADDR[i] && address < END_ADDR[i])
                decode = i;
    endfunction

    // No combinational path from AXI inputs to AXI outputs.
    always_comb begin
        s_axi_o = '0;
        s_axi_o.awready = rst_ni && state == IDLE && !aw_full;
        s_axi_o.wready = rst_ni && state == IDLE && !w_full;
        s_axi_o.arready = rst_ni && state == IDLE && !ar_full;
        s_axi_o.bvalid = rst_ni && state == WRITE_RESP;
        s_axi_o.bresp = response_code;
        s_axi_o.rvalid = rst_ni && state == READ_RESP;
        s_axi_o.rresp = response_code;
        s_axi_o.rdata = response_data;
        for (int i = 0; i < N; i++) begin
            m_axi_o[i] = '0;
            m_axi_o[i].awaddr = addr_q;
            m_axi_o[i].awprot = prot_q;
            m_axi_o[i].wdata = data_q;
            m_axi_o[i].wstrb = strb_q;
            m_axi_o[i].araddr = addr_q;
            m_axi_o[i].arprot = prot_q;
            if (rst_ni && target == i) begin
                m_axi_o[i].awvalid = state == WRITE_SEND && !aw_done;
                m_axi_o[i].wvalid = state == WRITE_SEND && !w_done;
                m_axi_o[i].bready = state == WRITE_WAIT;
                m_axi_o[i].arvalid = state == READ_SEND;
                m_axi_o[i].rready = state == READ_WAIT;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state <= IDLE; target <= '0;
            aw_full <= 0; w_full <= 0; ar_full <= 0; prefer_read <= 0;
            aw_done <= 0; w_done <= 0;
            awaddr_q <= '0; araddr_q <= '0; wdata_q <= '0;
            awprot_q <= '0; arprot_q <= '0; wstrb_q <= '0;
            addr_q <= '0; data_q <= '0; prot_q <= '0; strb_q <= '0;
            response_code <= 0; response_data <= 0;
        end else begin
            if (s_axi_i.awvalid && s_axi_o.awready) begin
                aw_full <= 1; awaddr_q <= s_axi_i.awaddr; awprot_q <= s_axi_i.awprot;
            end
            if (s_axi_i.wvalid && s_axi_o.wready) begin
                w_full <= 1; wdata_q <= s_axi_i.wdata; wstrb_q <= s_axi_i.wstrb;
            end
            if (s_axi_i.arvalid && s_axi_o.arready) begin
                ar_full <= 1; araddr_q <= s_axi_i.araddr; arprot_q <= s_axi_i.arprot;
            end
            case (state)
                IDLE: begin
                    if (aw_full && w_full && (!ar_full || !prefer_read)) begin
                        aw_full <= 0; w_full <= 0; prefer_read <= 1;
                        addr_q <= awaddr_q; prot_q <= awprot_q;
                        data_q <= wdata_q; strb_q <= wstrb_q;
                        aw_done <= 0; w_done <= 0;
                        response_data <= 0;
                        if (decode(awaddr_q) < 0) begin
                            response_code <= 2'b11; // DECERR
                            state <= WRITE_RESP;
                        end else begin
                            target <= SEL_W'(decode(awaddr_q));
                            state <= WRITE_SEND;
                        end
                    end else if (ar_full) begin
                        ar_full <= 0; prefer_read <= 0;
                        addr_q <= araddr_q; prot_q <= arprot_q;
                        if (decode(araddr_q) < 0) begin
                            response_code <= 2'b11;
                            response_data <= 0;
                            state <= READ_RESP;
                        end else begin
                            target <= SEL_W'(decode(araddr_q));
                            state <= READ_SEND;
                        end
                    end
                end
                WRITE_SEND: begin
                    if (!aw_done && m_axi_i[target].awready) aw_done <= 1;
                    if (!w_done && m_axi_i[target].wready) w_done <= 1;
                    if ((aw_done || m_axi_i[target].awready) &&
                        (w_done || m_axi_i[target].wready))
                        state <= WRITE_WAIT;
                end
                WRITE_WAIT: if (m_axi_i[target].bvalid) begin
                    response_code <= m_axi_i[target].bresp;
                    state <= WRITE_RESP;
                end
                READ_SEND: if (m_axi_i[target].arready) state <= READ_WAIT;
                READ_WAIT: if (m_axi_i[target].rvalid) begin
                    response_data <= m_axi_i[target].rdata;
                    response_code <= m_axi_i[target].rresp;
                    state <= READ_RESP;
                end
                WRITE_RESP: if (s_axi_i.bready) state <= IDLE;
                READ_RESP: if (s_axi_i.rready) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
    // synthesis translate_off
    initial begin
        if (N < 1) $fatal(1, "AXI target count must be positive");
        for (int i = 0; i < N; i++) begin
            if (BASE_ADDR[i] >= END_ADDR[i])
                $fatal(1, "Invalid AXI address range");
            for (int j = i + 1; j < N; j++)
                if (BASE_ADDR[i] < END_ADDR[j] && BASE_ADDR[j] < END_ADDR[i])
                    $fatal(1, "Overlapping AXI address ranges");
        end
    end
    // synthesis translate_on
endmodule
