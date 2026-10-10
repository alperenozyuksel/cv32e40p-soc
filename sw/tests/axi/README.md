# AXI entegrasyon programı

Program 0x1000'den çalışır, yalnızca RV32I komutları kullanır.
program.S okunabilir assembly kaynağı, program.lst adres/makine kodu listesi,
axi_program.hex ise testte yüklenen 2048 kelimelik bellek görüntüsüdür.
Assembly kaynağı listeden türetilmiştir; bu çalışmada harici assembler ile
yeniden derlenmemiştir. Çalıştırılıp doğrulanan dosya axi_program.hex'tir.

- RAM word/byte/halfword yazma ve okuma; lb/lbu/lh/lhu işaret genişletmesi.
- İki kelimeyi aşan hizasız sw/lw ve lh erişimi.
- GPIO ODR, byte write ve IDR=0x5AA5.
- Timer yapılandırma, enable/disable, sayaç ilerlemesi ve clear.
- Eşleşmeyen adrese load/store; okuma sıfır ve üst seviyede sticky hata.
- Her beklenmeyen sonuç fail etiketine dallanır, x20=-1 olur.
- Başarı x20=1, RAM 0x4100=1, GPIO=0xAA44 ve 0x1138'de sonsuz döngüdür.

Kaynak değişirse program görüntüsü, liste ve tb_soc_axi içindeki son PC kontrolü
birlikte güncellenmelidir. Bu test Spike lockstep veya tam ISA doğrulaması değildir.
