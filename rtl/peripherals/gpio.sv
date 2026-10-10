module gpio (
    // -- Sistem Sinyalleri --
    input  logic        clk_i,       // Sistem saati
    input  logic        rst_ni,      // Aktif düşük, senkron reset

    // -- Bellek / Veri Yolu (Bus) Arayüzü --
    input  logic        req_i,       // İşlem isteği
    input  logic [31:0] addr_i,      // Tam bayt adresi
    input  logic        we_i,        // 1: yazma (Write), 0: okuma (Read)
    input  logic [3:0]  be_i,        // Yazılacak baytları seçer (Byte Enable)
    input  logic [31:0] wdata_i,     // Yazma verisi
    output logic        gnt_o,       // İsteğin kabulü (Grant)
    output logic        rvalid_o,    // Yanıtın geçerli olması (Read Valid)
    output logic [31:0] rdata_o,     // Okuma sonucu (Read Data)

    // -- Dış Çevre (Peripherals) Sinyalleri --
    input  logic [15:0] gpio_in_i,   // Dışarıdan gelen dijital girişler
    output logic [15:0] gpio_out_o   // Dijital çıkışlar
);

    localparam logic [31:0] BASE_ADDR   = 32'h0001_0000;
    localparam logic [31:0] END_ADDR    = 32'h0001_1000;
    localparam logic [31:0] INPUT_ADDR  = 32'h0001_0000;
    localparam logic [31:0] OUTPUT_ADDR = 32'h0001_0004;

    // Her bağımsız giriş biti için iki aşamalı senkronizasyon.
    // Bu yapı debounce veya çok bitli veri için atomik aktarım sağlamaz.
    (* ASYNC_REG = "TRUE" *) logic [15:0] gpio_in_meta;
    (* ASYNC_REG = "TRUE" *) logic [15:0] gpio_in_sync;
    logic [15:0] gpio_out_reg;

    logic address_valid;
    logic input_select;
    logic output_select;

    assign address_valid = (addr_i >= BASE_ADDR) && (addr_i < END_ADDR);
    assign input_select  = (addr_i[31:2] == INPUT_ADDR[31:2]);
    assign output_select = (addr_i[31:2] == OUTPUT_ADDR[31:2]);

    assign gnt_o = rst_ni && req_i && address_valid;
    assign gpio_out_o = gpio_out_reg;

    // Giriş örnekleme, veri yolu isteklerinden bağımsız çalışır.
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            gpio_in_meta <= 16'b0;
            gpio_in_sync <= 16'b0;
        end
        else begin
            gpio_in_meta <= gpio_in_i;
            gpio_in_sync <= gpio_in_meta;
        end
    end

    // Kabul kenarından sonra kayıtlı yanıt üretir; yazmalara da yanıt verir.
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            gpio_out_reg <= 16'b0;
            rvalid_o     <= 1'b0;
            rdata_o      <= 32'b0;
        end
        else begin
            rvalid_o <= 1'b0;

            if (req_i && gnt_o) begin
                rvalid_o <= 1'b1;
                rdata_o  <= 32'b0;

                if (!we_i) begin
                    if (input_select) begin
                        rdata_o <= {16'b0, gpio_in_sync};
                    end
                    else if (output_select) begin
                        rdata_o <= {16'b0, gpio_out_reg};
                    end
                end
                else if (output_select) begin
                    if (be_i[0]) begin
                        gpio_out_reg[7:0] <= wdata_i[7:0];
                    end
                    if (be_i[1]) begin
                        gpio_out_reg[15:8] <= wdata_i[15:8];
                    end
                end
                // IDR ve tanımsız yazmaçlara yazmak etkisizdir.
                // Tanımsız yazmaç okumaları sıfır döndürür.
            end
        end
    end

endmodule
