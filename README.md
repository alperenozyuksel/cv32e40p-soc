# CV32E40P SoC

CV32E40P RISC-V çekirdeği etrafında geliştirilen SystemVerilog öğrenme ve
mikrodenetleyici yarışması hazırlık projesi. Geliştirme devam ediyor.

## Mevcut durum

| Parça | Durum |
|---|---|
| CV32E40P | FPU kapalı, FF register file; program belleğine bağlı |
| 8 KB program belleği | Önceki yerel simülasyonlarda test edildi |
| 8 KB veri RAM'i | Tüm satırlar, byte maskeleri ve CPU erişimleri simülasyonda kontrol edildi |
| AXI4-Lite ağı | Kanal beklemeleri, yanıt kararlılığı, hata ve reset senaryoları geçti |
| GPIO | Yazmaçlar, byte yazmaları, giriş senkronizasyonu ve CPU erişimleri geçti |
| Timer | Belgelenen davranış için testler geçti; şartname varsayımları docs/timer.md içinde |
| PWM | AXI4-Lite üzerinden CV32E40P kontrolü; bağımsız ve CPU testleri, docs/pwm.md |
| UART, I2C, QSPI, boot ve hızlandırıcı | Henüz uygulanmadı |

Program belleği komut portuna doğrudan bağlıdır. Veri portu OBI–AXI4-Lite köprüsü
ve AXI4-Lite interconnect üzerinden RAM, GPIO, timer ve PWM'e ulaşır.
Mevcut program yalnızca yazmaçlarla 5 + 7 hesaplar ve döngüye girer;
AXI, RAM veya çevre birimi erişimini test etmez. Bunlar için ayrı
sw/tests/axi/axi_program.hex ve tb_soc_axi vardır. Ayrıntılar docs/axi.md içindedir.

48 MHz SoC saatiyle 24 kHz PWM denemesi için
`./scripts/verify.ps1 -Tests tb_soc_pwm_24k` çalıştırın. CPU, AXI üzerinden
%25/%50/%75 görev oranlarını ayarlar; iki açılışta 72 tam periyot ve 12 AXI
yazması doğrulandı. Dalga kaydını Vivado'da açmak için
`source scripts/open_soc_pwm_24k_wave.tcl` kullanın (depo kökünden).
Ayrıntılar [PWM belgesinde](docs/pwm.md).

## Klasörler

- rtl/: sistem, bellek, yönlendirici ve çevre birimi kaynakları
- tb/: mevcut testbench'ler
- sw/tests/basic/program.hex: 2048 kelimelik başlangıç programı
- third_party/cv32e40p/: mevcut projede kullanılan çekirdek kaynak kopyası ve lisansı
- scripts/: Vivado proje oluşturma betiği ve çekirdek kaynak listesi
- docs/: adres haritası, doğrulama durumu ve kaynak kökeni
- constraints/: kart seçimi sonrası eklenecek XDC dosyaları
- build/: üretilen dosyalar; Git tarafından izlenmez

## Vivado projesini oluşturma

Mevcut geliştirme aracı Vivado 2025.1'dir. Vivado komutlarının erişilebilir olduğu
bir terminalde depo kökünden çalıştırın:

```sh
vivado -mode batch -source scripts/create_project.tcl
```

Ardından build/vivado/cv32e40p_soc.xpr dosyasını açın. Betik simülasyon veya sentez
başlatmaz. Depodaki proje zaten varsa betik onu açıp kaynak listesini günceller.
program.hex simülasyon kaynaklarına eklenir; testbench'ler bilgisayara özel yol
yerine program.hex adını kullanır.

Test çalıştırılacağı zaman Simulation Sources üst modülü olarak tb_soc veya
tb_imem_8kb seçilip Run Behavioral Simulation kullanılabilir. Güncel regresyonun kapsamı
ve sınırları docs/verification.md içindedir.

## Doğrulama

Depo kökünde PowerShell ile:

```powershell
./scripts/verify.ps1
```

Varsayılan Vivado yolu C:/Xilinx/2025.1/Vivado/bin; farklı kurulum için
-VivadoBin parametresi verin. Tek test örneği:
`./scripts/verify.ps1 -Tests tb_soc_axi`.
Loglar build/verification altında oluşur.

Bu bir fiziksel FPGA uygulaması değildir. Clock gate modeli simülasyon içindir;
sentez öncesi FPGA'ya uygun saat yapısı ve constraints hazırlanmalıdır.

## Kaynak ve lisans

Hazır çekirdek OpenHW Foundation CV32E40P projesindendir. Lisans ve kaynak sürümü
bilgileri docs/third_party.md ve third_party/cv32e40p/LICENSE içindedir.
