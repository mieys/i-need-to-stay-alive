# STİL REHBERİ (madde 403, 2026-11-06)

Amaç: Her ekran aynı oyundan çıkmış gibi görünsün. Tasarımlar (yerleşimler) aynı kalır. **Renk, yazı ve piksel ızgarası** bu rehbere uyar.
Ölçü HUD'dur ("Kısık Ahşap", madde 207). Oyuncunun en çok gördüğü yüzey o, geri kalanı ona benzer. Kıyas için yalnız Stardew Valley ve Terraria kullanılır.

## 1. Tek palet: `scripts/hud_theme.gd`
Arayüzdeki bütün renkler buradan okunur. Kit ya da ekran dosyasına **yeni hex yazma**: gereken rol yoksa `hud_theme.gd`'ye rol ekle.
Kitler (`menu_dark_kit`, `shop_dark_kit` `PAL_WOOD`, `fire_menu_kit`, `phone_menu_kit`, `game_over_board`, `soul_shop_screen`, `records_screen`,
`wait_overlay`, telefon `PH_*` sabitleri) renklerini artık bu dosyadan alıyor. `PAL_SLATE` ve `PAL_NIGHT` yalnız eski adlar, ikisi de `PAL_WOOD`'a eşit.

| Rol | Hex | Kullanım |
|---|---|---|
| `DEEP` | #140e09 | En koyu: sahne karartması, kaydırıcı yuvası, yazı gölgesi |
| `WIN_INSET` | #1a110a | Pencere içindeki kuyu / gömme kutu |
| `OUTLINE` | #20150d | Piksel simge ve çubuk dış hattı |
| `WIN_PANEL` (= `INSET`) | #271a11 | Pencere zemini (dış panel %88 opak) |
| `WIN_PANEL2` (= `STRIPE`) | #342316 | İç kart, satır şeridi |
| `WIN_PANEL3` (= `PLATE_ON`) | #3e2b1c | Seçili / üstüne gelinen kart |
| `WIN_LINE` (= `RIM_LO`) | #4b3320 | Kenar çizgisi |
| `PANEL` | #5a4734 | HUD levhasının içi |
| `WIN_LINE_HI` (= `RIM`) | #6a4a30 | Vurgulu kenar |
| `RIM_HI` | #86623f | Ahşap kenarın parlak yüzü |
| `TEXT` | #f3e6cc | Ana yazı |
| `DIM` | #c4b090 | İkincil yazı, etiket |
| `ACCENT` | #f0c070 | Başlık, seçili öğe, birincil düğme zemini |
| `ACCENT_SOFT` | #e2c08a | Sönük altın |
| `ACCENT_DK` / `ACCENT_TEXT` | #6a4416 / #24160a | Altın düğmenin kenarı / üstündeki yazı |
| `PRICE` | #f6d27e | Altın, sayı |
| `GOOD` / `BAD` | #b5d98a / #f09a80 | Olumlu / uyarı |
| `SPOT` | #c0803a | Sıcak sahne ışığı |

**Anlamlı renkler bu kuralın dışında kalır**, çünkü oyun bilgisi taşır:
- eşya kademe çerçeveleri (`TIER_COL`), efsun kontürleri, oyuncu renkleri (`PLAYER_COLORS`)
- verilen hasar (turuncu) / alınan hasar (mavi), Ruh Kıymığı moru, silah parçacığı mavisi (`SHARD`), `INK` stat renkleri
- level pazarında KAYDET'lenen seçenek yeşili (`SAVED_*`, madde 433): pazarda yeşil kenar yalnız "kayıtlı" demek

Bunlar da tek yerde tanımlı kalır, ama zemin ya da yazı rengi olarak kullanılmaz.

## 2. Yazı: iki aile
- **m5x7**: bütün yazı (tema `assets/fonts/theme.tres`). Boylar yerel boyun tam katı: **16 / 32 / 48**. Eski ekranlardaki 24 (x1,5) kalıntı. Yeni ekranda kullanma.
- **PixeloidSans Bold**: yalnız çubuk ve sayı (can/kalkan değeri, kalp sayacı, mini stat paneli). Boylar **9 / 18 / 27**.
- Pürüzsüz font yok. Nunito mini stat panelinden kalktı.
- `PixelifySans`, `monogram`, `VonwaonBitmap` dosyaları projede duruyor ama kullanılmıyor. Kullanma.

## 3. Piksel ızgarası
- **Arayüz dokuları**: 1 sanat pikseli = **3 ekran pikseli** (`menu_kit.gd T`, HUD dokuları). Yeni doku bu ölçekte çizilir, `NEAREST` ve tam katla gösterilir.
- **Elle çizilen arayüz parçaları** (çubuk, ayraç, çerçeve) 3 px'in katı kalınlıkta olur. 1-2 px'lik ince çizgi yeni işte yok.
- **Dünya**: ölçü karakter pikseli **0,903 dünya px**. Yeni silah, efekt, sandık ve mermi sanatı bu ızgarada çizilir.
  - Bilinen istisnalar (bölüm 7): sandık 0,5, mermiler 0,575. Silah sanatı madde 402'de değişti (masaüstü çizimleri + eski ikonlar), ızgarası yeniden ölçülmeli.
- Ölçek animasyonu piksel dokuyu kesirli büyütür. Pikselli yüzeyde konum ya da renk animasyonunu tercih et.

## 4. Yüzeyler ve kontur
- Pencere = `WIN_PANEL` zemin + `WIN_LINE` kenar, iç kutular `WIN_PANEL2`, kuyular `WIN_INSET`. Karartma `DEEP`'in saydam hâli. Mavi-mor ya da gri-mavi zemin yok.
- Birincil düğme: `ACCENT` zemin, `ACCENT_TEXT` yazı, `ACCENT_DK` kenar. İkincil düğme: koyu zemin, `DIM`/`TEXT` yazı.
- Piksel simgelerin dış hattı `OUTLINE` ya da `DEEP`, kalınlığı 1 sanat pikseli. Arayüzde renkli parlama/hale yok, yalnız "hazır" anı (madde 200) istisna.
- **Pencere/kart kutusu = piksel kutu** (`scripts/pixel_box.gd`, madde 417, seçim "B - Kabartma"): renkler düz ahşap ama köşe yarıçap/3 sanat
  pikselinde piksel basamak, kenar 1 sanat px (3 ekran px), kenarın içinde 1 sanat px ışık (üst/sol) + gölge (alt/sağ). Kitlerin `sb()`'si
  (`shop_dark_kit`, `menu_dark_kit`, Ruh Mağazası `_sb`) bunu döndürür; yeni kutu için `StyleBoxFlat.new()` yazma, kitin `sb()`'sini kullan.
  `phone_menu_kit.sb()` de bunu sarar. Henüz düz kutu: telefonun `_ph_box`/`_ph_sb` (level/sandık/envanter), `ui_kit._flat`, elle `draw_rect` kutular.
- Pencereler için **"piksel ahşap"** görünüş seçeneği var: HUD levhası, kuyu ve düğme dokuları 9 dilim. Prototip: `tools/proto_20261106/stil_rehberi/piksel_arayuz.py`. **KARAR (2026-11-06): düz ahşap kalır**, dokulu levhaya geçilmeyecek.

## 5. Ton
Sıcak, kırsal, ocak başı: ahşap, krem, altın. Karanlık bölgeler ve kan yalnız vurgu olarak kullanılır, ana renk olmaz. Haritaya yeni içerik yalnız oyunun kendi tileset sanatıyla girer.
Kuzey derin orman biyomu bu yüzden kaldırılıyor (ayrı oturum).

## 6. Yeni iş kontrol listesi
1. Arayüzde yeni hex var mı? Varsa `hud_theme.gd` rolüne çevir.
2. Yazı m5x7 16/32/48 ya da Pixeloid 9/18/27 mi?
3. Doku 3 px ızgarada, `NEAREST`, tam katta mı? Dünya sanatı karakter ızgarasında (0,903) mı?
4. Telefon sürümü ayrı renk istemiyor (aynı palet).
5. Prototipte "şu an" karesi, aynı oyundaki komşu ekranla yan yana bakılarak seçilir. Tek başına güzel olması yetmez.

## 7. Kalan istisnalar (iş listesi)
- Zafer penceresi (`victory_overlay.gd`) ve buff ipucu hâlâ bej kitte (`ui_kit.gd` / `menu_kit.gd`).
- Silahlar: hepsi 0,575 ızgarasında (kullanıcının kendi çizimleri + madde 412'de oturtulan eski ikonlar). Sandık paket sanatına döndü (madde 409, 0,8). Mermi (0,575) ve silahlar karakter ızgarasından (0,903) ince. Ölçüm ve karşılaştırma: madde 406, `tools/proto_20261106/stil_rehberi/piksel_izgara.py`. Otomatik dönüşüm kullanılamıyor. Yapılacaksa mermi ve sandık üreticilerle elle çizilir, silahları kullanıcı çizer. Karar bekliyor.
- Mini stat panelinin düz glif simgeleri (madde 262) `LINEAR` süzgeçli. Kullanıcının seçimi olduğu için şimdilik duruyor.
- Ana menü arka planı (Ocak Başı) mavi-mor sıva duvarlı bir çizim. Bu sahne sanatı, panel rengi değil, o yüzden duruyor.
