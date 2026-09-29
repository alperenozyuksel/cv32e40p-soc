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







endmodule