# Doğrulama durumu

- Program belleği önceki yerel çalışmada tb_imem_8kb ile 11 kontrolü geçti.
- Önceki çekirdek + program belleği çalışmasında tb_soc ile 5 + 7 = 12,
  son döngü ve reset sonrası yeniden başlama kontrol edildi.
- Bu depo oluşturulurken simülasyon tekrar çalıştırılmadı.
- create_project.tcl Vivado 2025.1 ile çalıştırıldı; proje oluşturma ve kaynak
  sıralaması tamamlandı. Bu kontrol işlevsel simülasyon veya sentez değildir.
- Veri RAM'i ve adres yönlendirici işlevsel olarak henüz doğrulanmadı.
- Güncel soc_top veri RAM'ini doğrudan bağlar; yönlendirici ve GPIO bağlı değildir.
- tb_soc yalnızca yazmaç kullanan eski programı sınar; RAM testi değildir.
  Yeni load/store programı eklenirken veri isteğini hata sayan kontrol değişmelidir.
- GPIO yalnızca arayüz iskeletidir; uygulanmış veya test edilmiş değildir.
- FPGA sentezi, zamanlama, kart üstü doğrulama ve ASIC fiziksel tasarım yapılmadı.

Planlanan testler: RAM tam kelime ve bayt yazma/okuma, reset, ardışık istekler;
yönlendiricide gecikmeli kabul/yanıt ve hedef kaydı; GPIO yazmaçları; çekirdekle
load/store entegrasyonu. Bunlar birimler birleştirildikten sonra çalıştırılacak.
