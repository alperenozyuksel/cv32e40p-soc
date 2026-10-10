# PWM simülasyonu

## 24 kHz denemesi

`./scripts/verify.ps1 -Tests tb_soc_pwm_24k` CPU üzerinden sırasıyla %25, %50,
%75 ayarlarını uygular, geri okur ve sonunda çıkışı kapatır. Ayrı program:
sw/tests/pwm/pwm_24k_program.hex; üretici: generate_24k.mjs.
Bu testin SoC saati 48 MHz, PERIOD=2000 ve PWM frekansı 24 kHz'dir.
HIGH değerleri 500, 1000, 1500; görev oranları %25, %50, %75'tir.
Testbench saatinin zaman çözünürlüğü 1 fs'dir; 48 MHz periyodunun zaman
ızgarasına yuvarlanması ihmal edilebilir düzeydedir. Test, tam PWM periyotlarının
hem 2000 çevrim hem yaklaşık 41666.666667 ns olduğunu kontrol eder.
Fiziksel saat üreticisi/constraints bu simülasyonla değiştirilmez.
Dalga kaydı build/verification/soc_pwm_48m_24k.wdb dosyasındadır;
scripts/open_soc_pwm_24k_wave.tcl ile Vivado'da açılır.
Önceki 1 MHz testi korunmuştur.

rtl/peripherals/pwm.sv aynı saat alanında çalışan bir PWM üreticisidir.
SoC içinde pwm_regs ve axi_lite_to_local üzerinden AXI4-Lite hedef 3'e bağlıdır.
CV32E40P OBI veri portu, mevcut OBI–AXI köprüsüyle bu yazmaçları kontrol eder.
Çıkış soc_top.pwm_o portudur; fiziksel pin ataması henüz yoktur.
Timer modülünden bağımsızdır.

## CPU yazmaçları

| Adres | Yazmaç | Davranış |
|---|---|---|
| 0x00012000 | CTRL | RW, bit 0 enable; diğer bitler sıfır okunur |
| 0x00012004 | PERIOD | RW, 32 bit periyot çevrim sayısı |
| 0x00012008 | HIGH | RW, 32 bit yüksek süre çevrim sayısı |
| 0x0001200C | STATUS | RO, bit 0 anlık PWM çıkışı |

Hepsi resette sıfırlanır. WSTRB byte maskeleri korunur. CTRL yalnızca alt bayt
yazıldığında değişir. STATUS ve ayrılmamış yazmaçlara yazmak etkisizdir;
ayrılmamış okumalar sıfır/OKAY döner. Pencere 0x12000–0x12FFF'tir.
PERIOD/HIGH okumaları yazılmış ayarı döndürür; üreticideki aktif ayarlar bir
sonraki periyot başında alınır. İki yazmacın ayrı yazılması atomik değildir.
İkisini birlikte değiştirmek için önce disable, sonra ayarları yazıp enable yapın.
Enable yazmasının yerel kabulünden bir saat sonra PWM motoru yeni enable'ı görür.

Örneğin 100 MHz saatte PERIOD=100, HIGH=25, CTRL=1: 1 MHz, %25 PWM.
Fiziksel saat farklıysa frekans da değişir.

CPU testi için:

```powershell
./scripts/verify.ps1 -Tests tb_soc_pwm
```

sw/tests/pwm/generate.mjs, doğrudan RV32I kodlamasıyla test programını üretir:
`node sw/tests/pwm/generate.mjs`. program.lst komut/adres dökümüdür.
Bu test bir C derleyicisi kullanmaz. Testbench CPU'nun yazmaçlarına veya PWM
ayarlarına değer zorlamaz; tüm ayarlar çalışan programın load/store komutlarıdır.
CPU periyodu 100 yapar, %0/%25/%50/%100 uygular, yazmaçları geri okur, byte
yazmalarını ve etkisiz yazmaları kontrol eder; sonunda PWM'i durdurur.
İki açılışta 242 tam çıkış periyodu ve 22 AXI yazması doğrulandı.

Gerçek CPU testinin WDB/VCD dosyaları build/verification/soc_pwm.* altındadır.
Vivado Tcl Console'da scripts/open_soc_pwm_wave.tcl dosyasını source ile açın.
Önceki open_pwm_wave.tcl ise bağımsız PWM testinin kaydını açar.

period_i bir periyottaki saat çevrimi sayısını, high_i yüksek kalınacak çevrim
sayısını belirler. Ayarlar periyot başında alınır; periyot ortasındaki değişiklik
bir sonraki periyotta uygulanır. period_start_o başlangıçta bir çevrim aktiftir.
period_i=0 çıkışı kapatır; high_i>=period_i, sıfır olmayan periyotta %100 üretir.
Reset ve enable'ın kapanması sonraki yükselen saat kenarında çıkışı sıfırlar;
devam eden darbe bu durumda kesilebilir. Reset senkrondur, aktif düşüktür.

## Çalıştırma

Depo kökünde PowerShell:

```powershell
./scripts/run_pwm.ps1
./scripts/plot_pwm.ps1
```

İlk betik XSim simülasyonu, WDB, VCD ve CSV üretir. İkincisi gerçek CSV
örneklerinden dalga resmi ve ölçüm tablosu oluşturur. Dosyalar build/pwm içindedir.
Vivado Tcl Console'da scripts/open_pwm_wave.tcl dosyasını source komutuyla açın.
Bu betik kaydedilmiş WDB'yi ve ilgili sinyalleri yükler.

## Sonuçlar (2026-10-10)

Bağımsız tb_pwm testi geçti: **3850 kontrol**. Saat 100 MHz, ana test periyodu
100 çevrimdir. CSV'den elde edilen ölçümler:

| Görev oranı | Periyot | Yüksek süre | Frekans |
|---|---|---|---|
| %0 | 1000 ns | 0 ns | 1 MHz yapılandırılmış periyot |
| %25 | 1000 ns | 250 ns | 1 MHz |
| %50 | 1000 ns | 500 ns | 1 MHz |
| %100 | 1000 ns | 1000 ns | 1 MHz yapılandırılmış periyot |

%0 ve %100 çıkış sabittir; bu satırlarda frekans PWM çıkış kenarlarından ölçülmez.
Test ayrıca tek çevrimlik periyodu, sıfır periyodu, yüksek süre sınırlamasını,
periyot ortasında ayar değişimini, durdurma/yeniden başlatmayı ve reseti denetler.
Bu sonuçlar RTL simülasyonudur; fiziksel logic analyzer ölçümü değildir.
