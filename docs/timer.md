# Timer — ilk RTL sürümü

2026 şartnamesi EK-2 Timer tablosu esas alınmıştır. Başlangıç adresi proje
tercihi olarak 0x00011000 seçildi. Mevcut req/gnt/rvalid arayüzü kullanılır;
Modül AXI4-Lite adaptörü üzerinden soc_top'a bağlanmıştır; PWM ve kesme çıkışı yoktur. Şartnamenin
bu tablosu kesme yazmacı tanımlamaz; olaylar TIM_EVN ile sayılır.

| Offset | Yazmaç | Erişim |
|---|---|---|
| 0x00 | TIM_PRE: prescaler | RW, 32 bit |
| 0x04 | TIM_ARE: otomatik sıfırlama hedefi | RW, 32 bit |
| 0x08 | TIM_CLR: sayacı sıfırda tut | RW, bit 0 |
| 0x0C | TIM_ENA: saymayı etkinleştir | RW, bit 0 |
| 0x10 | TIM_MOD: 1 yukarı, 0 aşağı | RW, bit 0 |
| 0x14 | TIM_CNT: sayaç | RO, 32 bit |
| 0x18 | TIM_EVN: hedefe varış sayısı | RO, 32 bit |
| 0x1C | TIM_EVC: olay sayacını sıfırda tut | RW, bit 0 |

## Açık varsayımlar ve sınır durumları

- Şartnamede PRE=0 için 1, PRE=1 için 2 saat çevrimi deniyor; ancak
  PRE=0xFFFFFFFF için 0x80000000 çevrimi örneği bunlarla çelişiyor.
  Bu sürüm PRE+1 kullanır: maksimum değer 2^32 çevrimdir. Son şartname veya
  organizatör açıklamasıyla bu davranış teyit edilmelidir.
- CLR/EVC RW olarak tanımlandığından kalıcı seviye bitleri olarak uygulandı.
  Yazılım önce 1 sonra 0 yazmalıdır. Kendiliğinden temizlenen darbe değillerdir.
- Tüm kayıtlar resetle 0 olur; timer kapalı ve aşağı sayma modundadır.
  Başlatmadan önce PRE, ARE ve MOD ayarlanmalıdır.
- Her tick'te mevcut CNT ARE'ye eşitse CNT sıfırlanır. Aksi halde yönüne göre
  bir artar/azalır. Sonuç ARE'ye ulaştığında EVN artar. Aşağı sayımda 0'dan
  azalma 0xFFFFFFFF'e taşar; ARE'den yeniden yükleme yapılmaz. Bu, metindeki
  iki yönde de sıfıra dönüş kuralının literal yorumudur; teyit edilmelidir.
- ARE=0, CNT=0 durumunda sayaç sıfırda kalır ve yeni varış olayı sayılmaz.
- EVN 32 bit taşmada sıfıra döner. CLR EVN'yi temizlemez; EVC CNT'yi etkilemez.
- Disable sırasında CNT ve prescaler fazı korunur. CLR veya PRE yazması
  prescaler fazını sıfırlar. PRE yazma kenarında tick üretilmez.
- CLR/EVC yazmaları kabul kenarında etkilidir ve normal saymaya önceliklidir.
  Diğer kontrol yazmaları sonraki kenarlardan itibaren sayma davranışını etkiler;
  kabul kenarında sayım eski kontrol değerleriyle yapılır.
- Okuma, kabul kenarı öncesindeki kayıt değerini döndürür. Her kabul edilen
  okuma/yazmaya kayıtlı yanıt verilir. Byte enable RW alanlarda uygulanır.
- Aralık içindeki tanımsız yazmaç okumaları sıfır, yazmaları etkisizdir.
  Aralık dışına grant verilmez. Adresin alt iki biti yazmaç seçiminde yok sayılır.

Belgelenen davranışlar için yönlendirilmiş simülasyon testleri çalıştırıldı;
kapsam docs/verification.md içindedir. Bu testler şartname belirsizliklerini
çözmez ve yarışma uyumluluğunun teyidi yerine geçmez.
