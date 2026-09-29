# Adres haritası

| Arayüz / birim | Başlangıç | Son (dahil) | Durum |
|---|---|---|---|
| Komut portu / program belleği | 0x00001000 | 0x00002FFF | Doğrudan bağlı, 8 KB |
| Veri portu / RAM | 0x00004000 | 0x00005FFF | Doğrudan bağlı, 8 KB |
| Veri portu / GPIO | 0x00010000 | 0x00010FFF | Yönlendiricide ayrılmış; henüz bağlı değil |

GPIO giriş yazmacı 0x00010000, çıkış yazmacı 0x00010004 olarak planlanmıştır.
GPIO dosyası şu an yalnızca port tanımlarından oluşur.

Program belleği veri yönlendiricisine bağlı değildir; veri portundan program
belleğine erişim veya bootloader ile yazma desteği henüz yoktur.
Mevcut RAM/yönlendirici tanımsız adreslere grant/yanıt üretmez; erişim bekler.
Adresler proje tercihidir; nihai yarışma şartnamesine göre güncellenebilir.
