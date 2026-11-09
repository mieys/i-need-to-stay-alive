# Yüzey haritaları neden yoruyor, zindanlar neden huzurlu? (2026-11-09, madde 529)

Kullanıcı: "ana harita, bataklık ve çöl nedensizce karmaşık ve göz yorucu; zindanlar çok huzurlu. Yüzeydeki haritaları zindanlardaki gibi
göz yormayan hale nasıl getiririz, nedenlerini incele."

**Yöntem:** gerçek oyun çizicisi, gizli masaüstü, her haritada 6 nokta (yüzeyde oyun alanına yayılmış 3x2 ızgara; zindanda görüş penceresinin
%45-80'i zemin olan hücreler), HUD gizli, gün başı, açık hava. 960x540 = 1 piksel 1 dünya pikseli. Araç `tools/harita_karmasa/cek.ps1`
(önce/sonra için aynı noktalar). Görsel: `yuzey_harita_karmasa_2026-11-09.png` (sağ sütun = 1 piksellik ayrıntı haritası, parlak = ince desen).

## Ölçüler (6 nokta ortalaması)

| harita | parlaklık | parlak alan (>0,62) | doygun piksel | renklilik | 1 px benek | kenar yoğunluğu | yoğun blok | sakin blok | hareket |
|---|---|---|---|---|---|---|---|---|---|
| Ana Harita | 0,46 | %0,7 | **%99** | 0,18 | 0,037 | **%12,6** | %12,9 | %59 | %1,2 |
| Kara Bataklık | 0,39 | %0,5 | **%95** | 0,15 | 0,037 | **%13,3** | %9,0 | %61 | %1,0 |
| Altın Kumlar | **0,57** | **%45** | **%97** | 0,18 | 0,028 | %8,7 | %12,6 | %68 | %1,0 |
| Batık Nekropol | 0,13 | %0,1 | %7 | 0,04 | 0,011 | %1,8 | %1,5 | %85 | %1,3 |
| Taşkın Hisar | 0,19 | %0,4 | %63 | 0,10 | 0,017 | %3,8 | %2,7 | %74 | %5,8* |
| Lağım Ağı | 0,14 | %0,1 | %31 | 0,07 | 0,016 | %3,1 | %1,3 | %78 | %1,8 |

doygun piksel = doygunluk >0,25 ve değer >0,15; kenar = komşuya göre >0,10 parlaklık sıçraması; yoğun/sakin blok = 16x16 blok parlaklık
sapması >0,10 / <0,035; hareket = 0,45 sn arayla >0,03 değişen piksel (*Hisar'da yürüyen goblinler).

## Nedenler (etkisine göre sıralı)

1. **Zindanlar daha az ayrıntılı DEĞİL, kısılmış.** Benek / parlaklık oranı her haritada aynı aralıkta (yüzey 0,05-0,10, zindan 0,08-0,11).
   Fark: zindanlarda `CanvasModulate` ortamı (`map_profiles.gd zindan_tanimi ambient_day` 0,42-0,46 + hafif soğuk ton) HER pikseli ~yarıya
   çarpıyor -> tüm kenarlar ve desenler yarı kontrastla görünüyor; oyuncu ışığı + meşaleler etrafta doğal bir odak (vinyet) yapıyor.
   Yüzeyde gündüz atmosfer ayarı kimlik (hiçbir şey kısılmıyor) ve harita renk ayarı (`harita_renk.gdshaderinc`) yalnız yeşili %12 koyulaştırıyor.
   Sonuç: yüzeyde ekran 3 kat parlak, piksellerin **%95-99'u doygun renk** (zindanda %7-63) - gözün dinlendiği gri/nötr alan yok.
2. **Ayrıntı her yere eşit serpilmiş ("konfeti").** Ana haritada çiçek/mantar/filiz/taşçık, bataklıkta ot tutamı + çalı, çölde kaktüs/ot öbeği
   ekranın her yerinde birkaç hücrede bir; ayrıntı haritasında yüzeyler baştan sona noktalı. Zindanda süsler duvar diplerinde toplanmış,
   oda ortası boş, aradaki boşluk düz siyah - göz neye bakacağını hemen buluyor (sakin blok %74-85 / yüzey %59-68, yoğun blok 5-9 kat az).
3. **Kenarlar kıvrımlı ve çift çizgi.** Yol/uçurum/su sınırları iki yanlı tırtıklı çimen saçağı: ekranı boydan boya kesen uzun, yüksek
   kontrastlı, düzensiz çizgiler (ayrıntı haritasında en parlak şeyler). Zindanın sınırları düz ve dik açılı; göz onları "yapı" olarak tek
   bakışta okuyor, takip etmiyor.
4. **Zemin desenleri tüm zemine 1 pikselde işliyor.** Ana harita çimen shader'ı (çiçek/yonca beneği), bataklık "Ot Tutamları" (5 tonlu palet,
   0,36 -> 0,82 parlaklık aralığı = tutamlar yüksek kontrast), çöl rüzgâr kıvrımı kum çizgileri. Zindan zemini (`zindan_zemin.gdshader`)
   düşük kontrastlı (derz 0,16, taş tonu 0,05) düzenli bir ağ - göz düzenli deseni "doku" olarak süzer, rastgele beneği süzemez.
5. **Figür / zemin ayrımı zayıf.** Yüzeyde karakter, yaratık, süs ve zemin aynı değer ve ton ailesinde (yeşil zemin üstünde yeşil goblin /
   slime; kaktüs, slime ile aynı boyda ve renkte). Zindanda gri zemin üstünde her renkli şey öne çıkıyor - aramak gerekmiyor.
6. **Çölde parlama.** Ekranın %45'i 0,62 parlaklığın üstünde açık kum (diğer haritalarda <%1). En yorucu tek etken çölde bu.
7. **Görüş elipsi** (bataklık + çöl çekimlerinde): içi parlak / dışı koyu büyük oval - ekranın ortasında hep duran bir parlaklık sınırı.
   Zindanda aynı sınır zaten karanlık alana düştüğü için görünmüyor.
8. *Küçük:* hareket ölçülen durağan sahnelerde yüzeyde ve zindanda AYNI (%1-2); sallanma/rüzgâr çizgileri (her havada 9 akıntı + 8 yaprak,
   `weather_wind.gd BREEZE_*`) ana neden değil.

## Öneriler (etki / iş sırasıyla; hepsi ayar, yeni sistem yok)

1. **Yüzey ortamı (en büyük etki, en ucuz):** yalnız HARİTA piksellerine (karakter/yaratık/efekt tam renk kalır -> figür/zemin ayrımı da
   kendiliğinden düzelir) harita başına parlaklık + doygunluk kısma. Yer: `harita_renk.gdshaderinc` sonuna harita başına global shader
   parametresi (profil `yuzey_ortam` gibi). Hedef zindan kadar karanlık değil, gündüz hissi kalmalı: parlaklık ~0,30-0,34, doygun piksel
   <%75, çölde parlak alan <%10. Ders (madde 179): saf doygunluk kısma griye/sise döner - KOYULAŞTIR + yeşili gerçek yeşile çek.
2. **Zemin desenlerini kıs:** çimen çiçek/yonca beneği, bataklık tutam paletinin üst iki tonu (`BC_ACIK`/`BC_PARLAK`), çöl kum kıvrımının
   kontrastı - yoğunluğu değil önce KONTRASTI yarıya.
3. **Süsleri öbekle, boşluk bırak:** bataklık/çöl üreteçlerinde (`gen_bataklik.py`, `gen_col.py`) süsleri tek tek serpmek yerine ağaç/kaya/su
   kenarında öbeklere topla, açık alanların ortası boş kalsın (zindan odası gibi). Ana harita Tiled'da kullanıcının - aynı kural elle ya da
   md5 kapılı bir betikle "açık alan ortasındaki tekil küçük süsleri sil".
4. **Saçak kenarlarını yumuşat:** çimen saçağının en açık / en koyu pikselini zemine yaklaştır (kenar şekli aynı, kontrast düşer).
5. **Görüş elipsi:** dış kararmayı daha geniş geçişle, iç parlaklığı artırmadan.

Önerilen sıra: 1'in 4 prototipi (A hafif / B orta / C sıcak akşamüstü / D serin gölge) üç haritada gerçek oyunda + bu aracın ölçüsü, sonra 2-4.
