module dmem_8kb (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        data_req_i,
    input  logic [31:0] data_addr_i,
    input  logic        data_we_i,
    input  logic [3:0]  data_be_i,
    input  logic [31:0] data_wdata_i,

    output logic        data_gnt_o,
    output logic        data_rvalid_o,
    output logic [31:0] data_rdata_o
);

    // 2048 satır × 4 bayt = 8192 bayt
    logic [31:0] mem [0:2047];

    localparam logic [31:0] BASE_ADDR = 32'h0000_4000;

    logic [31:0] byte_offset;
    logic [10:0] word_index;
    logic        address_valid;

    assign byte_offset = data_addr_i - BASE_ADDR;
    assign word_index  = byte_offset[12:2];

    assign address_valid = (data_addr_i >= BASE_ADDR)
                        && (byte_offset < 32'd8192);

    assign data_gnt_o = rst_ni && data_req_i && address_valid;

    always_ff @(posedge clk_i) begin
        // Senkron, aktif düşük reset
        if (!rst_ni) begin
            data_rvalid_o <= 1'b0;
            data_rdata_o  <= 32'b0;
        end
        else begin
            // Kabul edilen istek yoksa yanıt geçerli değil.
            data_rvalid_o <= 1'b0;

            if (data_req_i && data_gnt_o) begin
                // Hem okuma hem yazma için yanıt ver.
                data_rvalid_o <= 1'b1;

                if (!data_we_i) begin
                    // Okuma: satırın tamamını döndür.
                    data_rdata_o <= mem[word_index];
                end
                else begin
                    // Yazma: yalnızca seçilen baytları değiştir.
                    if (data_be_i[0]) begin
                        mem[word_index][7:0] <= data_wdata_i[7:0];
                    end

                    if (data_be_i[1]) begin
                        mem[word_index][15:8] <= data_wdata_i[15:8];
                    end

                    if (data_be_i[2]) begin
                        mem[word_index][23:16] <= data_wdata_i[23:16];
                    end

                    if (data_be_i[3]) begin
                        mem[word_index][31:24] <= data_wdata_i[31:24];
                    end
                end
            end
        end
    end

endmodule