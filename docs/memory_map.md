# Adres haritası

| Arayüz / birim | Başlangıç | Son (dahil) | Durum |
|---|---|---|---|
| Komut portu / program belleği | 0x00001000 | 0x00002FFF | Doğrudan bağlı, 8 KB |
| Veri portu / RAM | 0x00004000 | 0x00005FFF | AXI4-Lite hedef 0, 8 KB |
| Veri portu / GPIO | 0x00010000 | 0x00010FFF | AXI4-Lite hedef 1 |
| Veri portu / Timer | 0x00011000 | 0x00011FFF | AXI4-Lite hedef 2 |
| Veri portu / PWM | 0x00012000 | 0x00012FFF | AXI4-Lite hedef 3; docs/pwm.md |

GPIO giriş yazmacı (IDR, RO) 0x00010000, çıkış yazmacı (ODR, RW) 0x00010004.
Her yazmaç dört baytlık alan kaplar; seçimde adresin alt iki biti yok sayılır.
Okumada üst 16 bit sıfırdır. ODR yazmalarında yalnızca be[0] ve be[1] etkilidir.
IDR ve GPIO aralığındaki tanımsız yazmaçlara yazmalar etkisizdir; yanıt verilir.
GPIO aralığındaki tanımsız yazmaç okumaları sıfır döndürür.
GPIO çekirdeği yerel req/gnt/rvalid arayüzünü korur; önündeki adaptör AXI4-Lite sağlar.

Program belleği veri yönlendiricisine bağlı değildir; veri portundan program
belleğine erişim veya bootloader ile yazma desteği henüz yoktur.
AXI interconnect eşleşmeyen adreslere DECERR döndürür. OBI köprüsü işlemi
tamamlar (okumada sıfır) ve soc_top.bus_error_o resetlenene kadar 1 kalır.
Bu bayrak CPU exception/interrupt değildir. Eski adres_yonlendirici aktif yolda yoktur.
Adresler proje tercihidir; nihai yarışma şartnamesine göre güncellenebilir.
