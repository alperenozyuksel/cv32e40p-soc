# Doğrulama raporu — 2026-10-10

Araç: Vivado 2025.1 xvlog / xelab / xsim. Yöntem: kendini kontrol eden
SystemVerilog testbench'leri, deterministik rastgele trafik, referans bellek
modeli ve bağlı AXI arayüzlerinde işlem/sinyal izleyicileri.

## Sonuçlar

| Test | Sonuç | Kapsam |
|---|---|---|
| tb_imem_8kb | PASS, 11 kontrol | Program, sınırlar, hizalama, bekleme ve reset |
| tb_soc | PASS, iki açılış | Önceki aritmetik program, fetch enable ve döngü |
| tb_peripherals | PASS, 18493 kontrol | RAM'in 2048 satırı, 512 rastgele maskeli erişim, GPIO ve timer |
| tb_axi | PASS, 301 kontrol | AW/W sırası, read/write birlikte, R/B beklemeleri, hedefler ve DECERR |
| tb_bridge | PASS, 66 işlem sonucu | OBI kayıtları, bağımsız geciken kanallar, hatalar ve bekleyen ikinci istek |
| tb_adapter | PASS, 65 işlem sonucu | Yerel grant/yanıt gecikmesi, aynı çevrim yanıtı, reset |
| tb_soc_axi | PASS, iki açılış | Her açılışta 32 veri isteği/yanıtı, CPU RAM/GPIO/timer erişimi |
| tb_pwm | PASS, 3850 kontrol | Bağımsız PWM sınırları, reset, enable ve periyot başında ayar güncelleme |
| tb_soc_pwm | PASS, iki açılış | CPU–OBI–AXI–PWM; 242 tam periyot, 22 AXI yazması, yazmaç geri okuma |
| tb_soc_pwm_24k | PASS, iki açılış | 48 MHz SoC, 24 kHz PWM, %25/%50/%75; 72 periyot, 12 AXI yazması |

24 kHz testi ayrıca `./scripts/verify.ps1 -Tests tb_soc_pwm_24k` ile çalıştırılır.
Sonuç özeti pwm_24k_results.txt içindedir.

Kontrol sayıları coverage yüzdesi değildir. Bu testlerde RTL düzeltmesi
gerektiren bir hata bulunmadı. Ham sonuç özeti verification_results.txt içindedir.

## Tekrar çalıştırma

Depo kökünden PowerShell ile ./scripts/verify.ps1 çalıştırın.
Vivado konumu farklıysa -VivadoBin parametresini verin.
Tek test örneği: ./scripts/verify.ps1 -Tests tb_soc_axi

Testler hatalı koşulda $fatal, normal bitişte PASS üretir. Betik derleme,
elaborasyon veya simülasyon hatası ya da PASS eksikliğinde başarısız olur.
Her testte zaman aşımı vardır. Loglar build/verification altında tutulur.

## Ayrıntılı kapsam

- RAM: Her satıra word yazma/okuma; 16 strobe kombinasyonu (sıfır maske dahil),
  rastgele adres/veri, byte offset, ardışık erişim ve reset sonrası veri korunması.
  Rastgele tohum 0x12AB9876'dır.
- GPIO: İki kayıtlık giriş gecikmesi; üst bitleri sıfır okuma; tam/kısmi ODR
  yazmaları; etkisiz üst byte maskeleri, IDR yazması ve tanımsız yazmaçlar.
- Timer: PRE=0..3 için tam çevrim sayımı; yukarı/aşağı, overflow, auto-reload,
  event sayacı, enable/disable, kalıcı clear, RW byte maskeleri, RO/reserved yazmalar.
  PRE maksimum değerde yalnızca 100 çevrimlik gözlem vardır; 2^32 çevrim koşulmadı.
- AXI ağı: AW önce, W önce ve birlikte; 128 deterministik rastgele maskeli işlem,
  RREADY/BREADY gecikmeleri, eşzamanlı okuma/yazma, hedef kaydı,
  DECERR, kısmi yazmada ve yanıtta reset. Tohum 0xABCDEF01'dir.
- Köprü: 32 yazma ve 32 okuma; farklı kanal/yanıt gecikmeleri; OKAY/SLVERR/DECERR;
  sonraki OBI isteğini bekletme, sıralı tamamlama ve resetle iptal.
- Adaptör: Değişken yerel grant/yanıt gecikmeleri; kombinasyonel/kayıtlı yerel
  yanıt; AW/W ayrışması; maskeler; grant ve yanıt beklerken reset.
- CPU: word/byte/halfword, lb/lbu/lh/lhu, kelime sınırını aşan hizasız erişimler,
  GPIO giriş/çıkışları, timer ilerleme/durdurma/clear, unmapped load/store ve
  sticky bus_error_o. Her açılışta 32'şer veri isteği/yanıtı.

axi_lite_checker, beş kanalda VALID/payload kararlılığını, handshake sinyallerinde
X olmadığını ve kabul edilmiş istek olmadan yanıt üretilmediğini denetler.
Bu özel procedural monitor tam AXI VIP değildir.

## Sınırlar ve açık işler

- Sonuçlar mevcut RTL ve belirtilen senaryolar içindir; eksiksiz doğruluk veya
  yarışma kabulü garantisi değildir. Code/functional coverage yüzdesi ölçülmedi.
- UVM AXI agent/VIP, formal doğrulama ve Spike/ISS karşılaştırması yapılmadı.
  Şartnamenin protokol doğrulama teslimini bu testler tek başına karşılamaz.
- Timer'ın PRE maksimum değer çelişkisi, aşağı sayım ve clear yorumları
  timer.md içinde duruyor. Testler belgelenen yoruma göredir.
- CDC/metastabilitenin fiziksel etkileri RTL simülasyonu ile doğrulanmaz.
- FPGA sentezi, zamanlama, kart üstü test ve ASIC fiziksel doğrulama yapılmadı.
- xelab kaynakların farklı timescale bildirimleri için uyarı veriyor;
  testbench çözünürlüğü 1 ps. Derleme veya simülasyon hatası oluşmadı.
