# CV32E40P SoC

CV32E40P RISC-V çekirdeği etrafında geliştirilen SystemVerilog öğrenme ve
mikrodenetleyici yarışması hazırlık projesi. Geliştirme devam ediyor.

## Mevcut durum

| Parça | Durum |
|---|---|
| CV32E40P | FPU kapalı, FF register file; program belleğine bağlı |
| 8 KB program belleği | Önceki yerel simülasyonlarda test edildi |
| 8 KB veri RAM'i | RTL hazır, soc_top içinde bağlı; işlevsel testi bekliyor |
| RAM/GPIO adres yönlendirici | RTL hazır; soc_top içine henüz bağlanmadı, test edilmedi |
| GPIO | Yalnızca port iskeleti; davranış henüz yazılmadı |
| Timer, UART, I2C, QSPI, boot ve hızlandırıcı | Henüz uygulanmadı |

Program belleği komut portuna, RAM veri portuna doğrudan bağlıdır. Mevcut program
yalnızca yazmaçlarla 5 + 7 hesaplar ve döngüye girer; RAM erişimini test etmez.

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
başlatmaz. Aynı proje zaten varsa onu açın; betik var olan projeyi zorla ezmez.
program.hex simülasyon kaynaklarına eklenir; testbench'ler bilgisayara özel yol
yerine program.hex adını kullanır.

Test çalıştırılacağı zaman Simulation Sources üst modülü olarak tb_soc veya
tb_imem_8kb seçilip Run Behavioral Simulation kullanılabilir. Bu aktarım sırasında
testler yeniden çalıştırılmadı. Ayrıntılar docs/verification.md içindedir.

Bu bir fiziksel FPGA uygulaması değildir. Clock gate modeli simülasyon içindir;
sentez öncesi FPGA'ya uygun saat yapısı ve constraints hazırlanmalıdır.

## Kaynak ve lisans

Hazır çekirdek OpenHW Foundation CV32E40P projesindendir. Lisans ve kaynak sürümü
bilgileri docs/third_party.md ve third_party/cv32e40p/LICENSE içindedir.
