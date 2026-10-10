# AXI4-Lite entegrasyonu

Veri yolu:

```text
CV32E40P OBI veri portu
  -> obi_to_axi_lite
  -> axi_lite_interconnect
     -> axi_lite_to_local[0] -> dmem_8kb
     -> axi_lite_to_local[1] -> gpio
     -> axi_lite_to_local[2] -> timer
     -> axi_lite_to_local[3] -> pwm_regs -> pwm -> pwm_o
```

Komut portu hâlâ doğrudan imem_8kb'ye bağlıdır. Bootloader'ın program belleğine
yazma yolu bu değişikliğin parçası değildir.

## Arayüz ve kapsam

- 32 bit adres/veri, dört byte strobe; AXI4-Lite, burst ve ID yok.
- axi_lite_pkg iki packed struct ile beş bağımsız AXI kanalını gruplar.
  Bu, AXI kanallarının el sıkışmalarını birleştirmez.
- Köprü OBI isteğini sakladıktan sonra grant verir (kabul kenarında veriyi yakalar).
  Bir işlem tamamlanmadan yeni OBI isteği kabul etmez. AW ve W bağımsız ilerler.
  B veya R alındıktan sonra bir çevrimlik OBI yanıtı üretilir.
- Interconnect AW, W ve AR'yi ayrı kayıtlarda tutar; farklı çevrim/sıralarda
  geliş desteklenir. Hazır okuma/yazma arasında dönüşümlü seçim yapar; tek
  downstream işlem yürütür. Gerekirse bir diğer tam/kısmi istek tamponda bekler.
- Hedef ve payload kabulden sonra kaydedilir. VALID, READY gelene kadar korunur.
  R ve B yanıtları backpressure altında tutulur; AXI girişinden çıkışına
  kombinasyonel yol yoktur.
- Her hedefte ortak adaptör eski yerel req/gnt/rvalid protokolünü kullanır.
  Bir yerel yanıtın bir saatlik darbesini AXI yanıt kaydında tutar.
  Yerel birim bir kabul edilmiş yazmaya da yanıt vermelidir.
- PROT interconnect üzerinden taşınır; köprü veri işlemleri için 000 üretir.
  Mevcut adaptör erişim yetkilendirmesi yapmaz ve PROT'u göz ardı eder.
- Yerel arayüzde hata girişi yok; eşleşen hedefler OKAY döndürür. Aralık
  içindeki ayrılmamış GPIO/timer yazmaçları mevcut davranışlarını korur.

## Hata ve reset politikası

Eşleşmeyen adresler interconnect tarafından DECERR ile tamamlanır, hiçbir hedefe
istek gitmez. Yanlış adresten okunan değer sıfırdır. Köprü non-OKAY cevabı
error_o ile bildirir; soc_top'taki bus_error_o resetlenene kadar 1 kalır.
CV32E40P veri portunda err girişi olmadığı için bu otomatik CPU exception
değildir; işlem yazılım açısından tamamlanır. Yazılımla okunabilir hata yazmacı
veya kesme politikası gelecekte ayrıca tasarlanmalıdır.

Tüm yapı aynı clk_i/rst_ni kullanır. AXI modüllerinde reset asenkron assert edilir;
yerel modüllerin reseti senkrondur. Sistem reseti en az bir yükselen kenarı
kapsamalı, bırakılması saate senkron olmalıdır. Reset bekleyen işlemleri iptal eder.
Kısmi reset desteklenmez. Kabul edilmiş yan etki (ör. RAM yazması) geri alınmaz.
Eşleşen bir hedef hiç yanıt vermezse timeout yoktur; işlem bekler.

## Genişletme

Interconnect N, BASE_ADDR ve END_ADDR parametreleriyle genişler (son adres hariç).
Yeni hedefte soc_top dizi boyutlarını ve generate sınırını, adres tablolarını
ve yerel modül bağlantısını güncelle. Yerel adaptörün mantığı değişmez.
Eski adres_yonlendirici.sv eğitim örneği olarak korunur; aktif projeden çıkarıldı.

Yeni soc_top portları: gpio_in_i[15:0], gpio_out_o[15:0], bus_error_o, pwm_o.
tb_soc GPIO girişlerini sıfıra bağlar; mevcut program AXI işlemi üretmez.
scripts/create_project.tcl mevcut depo projesine yeni kaynakları da ekler.

## Kontrol

İşlevsel simülasyon ve özel AXI izleyiciyle regresyon çalıştırıldı; kapsam ve
sınırlar docs/verification.md içindedir. FPGA sentezi ve AXI VIP/UVM kontrolü henüz yoktur.
Protokol referansı:
https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf
