# CV32E40P kaynakları

Kaynak proje: https://github.com/openhwfoundation/cv32e40p

Bu depodaki third_party/cv32e40p, mevcut yerel Vivado projesinde kullanılan
cv32e40p-master indirmesinden alınan rtl/ ve bhv/ kaynaklarının kopyasıdır.
Kaynak indirmesi Git geçmişi içermediğinden upstream commit kimliği bilinmiyor;
güncel master ile aynı olduğu iddia edilmez. Dosyalar core_snapshot.sha256 ile
kayıt altına alınmıştır. Çekirdek kodu bu aktarımda değiştirilmemiştir.

Orijinal LICENSE, README.md, dosya lisans başlıkları ve temel manifest korunmuştur.
Sentez/simülasyon kaynak seçimi scripts/core_sources.flist içinde mevcut Vivado
projesinden alınmıştır. Latch register file ve FPU wrapper derlemeye eklenmez;
FF register file ve simülasyon clock gate kullanılır.

Bu kopya tüm upstream deposunu içermez. rtl/vendor altındaki mevcut kaynaklar
lisanslarıyla korunmuştur; FPU bağımlılıklarının tamamlığı test edilmemiştir.
Üçüncü taraf lisansı proje sahibinin kendi RTL dosyalarına otomatik uygulanmaz.
