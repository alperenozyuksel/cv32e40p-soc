module adres_yonlendirici (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Çekirdek veri arayüzü
    input  logic        data_req_i,
    input  logic [31:0] data_addr_i,
    input  logic        data_we_i,
    input  logic [3:0]  data_be_i,
    input  logic [31:0] data_wdata_i,

    output logic        data_gnt_o,
    output logic        data_rvalid_o,
    output logic [31:0] data_rdata_o,

    // Adres seçimleri
    output logic        ram_select,
    output logic        gpio_select,

    // RAM arayüzü
    output logic        ram_req_o,
    output logic [31:0] ram_addr_o,
    output logic        ram_we_o,
    output logic [3:0]  ram_be_o,
    output logic [31:0] ram_wdata_o,

    input  logic        ram_gnt_i,
    input  logic        ram_rvalid_i,
    input  logic [31:0] ram_rdata_i,

    // GPIO arayüzü
    output logic        gpio_req_o,
    output logic [31:0] gpio_addr_o,
    output logic        gpio_we_o,
    output logic [3:0]  gpio_be_o,
    output logic [31:0] gpio_wdata_o,

    input  logic        gpio_gnt_i,
    input  logic        gpio_rvalid_i,
    input  logic [31:0] gpio_rdata_i
);

    logic busy;
    logic target_gpio;

    // Adres çözümleme
    assign ram_select = (data_addr_i >= 32'h0000_4000)
                     && (data_addr_i <  32'h0000_6000);

    assign gpio_select = (data_addr_i >= 32'h0001_0000)
                      && (data_addr_i <  32'h0001_1000);

    // Reset sırasında veya yanıt beklerken yeni istek gönderme.
    assign ram_req_o = rst_ni && !busy
                   && data_req_i && ram_select;

    assign gpio_req_o = rst_ni && !busy
                    && data_req_i && gpio_select;

    // İşlem bilgileri iki birime de taşınır.
    // Yalnızca req ve gnt birlikte aktif olan birim işlem yapar.
    assign ram_addr_o  = data_addr_i;
    assign ram_we_o    = data_we_i;
    assign ram_be_o    = data_be_i;
    assign ram_wdata_o = data_wdata_i;

    assign gpio_addr_o  = data_addr_i;
    assign gpio_we_o    = data_we_i;
    assign gpio_be_o    = data_be_i;
    assign gpio_wdata_o = data_wdata_i;

    // Seçilen birimin kabulünü çekirdeğe ilet.
    assign data_gnt_o = (ram_req_o  && ram_gnt_i)
                    || (gpio_req_o && gpio_gnt_i);

    // Yanıtı mevcut adrese göre değil,
    // kabul sırasında kaydedilmiş hedefe göre seç.
    always_comb begin
        data_rvalid_o = 1'b0;
        data_rdata_o  = 32'b0;

        if (rst_ni && busy) begin
            if (target_gpio) begin
                data_rvalid_o = gpio_rvalid_i;
                data_rdata_o  = gpio_rdata_i;
            end
            else begin
                data_rvalid_o = ram_rvalid_i;
                data_rdata_o  = ram_rdata_i;
            end
        end
    end

    // Senkron, aktif düşük reset
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            busy        <= 1'b0;
            target_gpio <= 1'b0;
        end
        else begin
            if (busy) begin
                // Yanıt çekirdeğe ulaştı; yeni isteğe hazır ol.
                if (data_rvalid_o) begin
                    busy <= 1'b0;
                end
            end
            else if (data_req_i && data_gnt_o) begin
                busy        <= 1'b1;
                target_gpio <= gpio_select;
            end
        end
    end

endmodule