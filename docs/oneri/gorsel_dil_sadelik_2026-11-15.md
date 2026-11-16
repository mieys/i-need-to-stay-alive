# Görsel dil sadeleştirme: analiz ve öneri (2026-11-15, madde 710)

Kullanıcı: "oyunda görsel açıdan karmaşık olan, oyunun dilini karmaşıklaştıran her şey için analiz yapıp değişim önerisi sun. Oyun göz yormasın, cozy hissiyatı gitmesin."

Önceki analizler burada tekrarlanmıyor, bu belge geri kalan her şeyi tarıyor:
- Savaş MP karmaşası (madde 425, `savas_gorsel_karmasa_2026-11-06.md`). Öneri 1 ve 2 oyunda: Efekt Yoğunluğu ayarı (madde 426).
- Yüzey haritaları (madde 529, `yuzey_harita_karmasa_2026-11-09.md`). Öneri 1 hâlâ bekliyor.

**Yöntem:**
- Güncel oyundan gizli masaüstünde 3 kalabalık karesi alındı: `tools/buyuk_test/run.ps1 -Mode crowd -Label gorsel_dil_1115 -Env "BT_TIER_LIST=3,8,13;BT_N=60"`. Çıktı `tools/buyuk_test/out/gorsel_dil_1115/crowd/`.
- Kod taraması üç alanda yapıldı: ekran/kamera/ışık, dünyadaki göstergeler, arayüzün stil rehberine uyumu.
- Satır numaraları 2026-11-15 hâlidir. `player.gd` tarama sırasında değişiyordu, onun satırları yaklaşıktır.

## Karelerde görülen
- **Görüş elipsi** ekranın en belirgin şekli: ortası parlak bir oval, köşeleri koyu, sınırı seçiliyor. Vinyet de üstüne biniyor.
- **Zemin** hâlâ doygun yeşil, tekil süsler her yere serpili (madde 529'un 1-3. önerileri uygulanmadı).
- **Kendi karakterin** 60 yaratığın içinde kayboluyor. Madde 425'in 3. önerisi (kimlik halkası) uygulanmadı.
- **HUD** sakin ve sıcak. Tek aykırı yüzey boss barının doygun mavisi ve kırmızısı.

## Gözü yoran 6 kök neden
1. **Hızlı yanıp sönme (strobo):** şok durumu ~11 Hz, gece makineli namlu ışığı ~12 Hz, lazer ve hücum şeridi uyarısı 5,4-5,7 Hz. Bazı efektlerde dama dither'ı her kare tersine dönüyor.
2. **Durmayan küçük hareket:**
   - Yerdeki her eşya aynı 3 px / 1,57 sn ritimle ve aynı fazda zıplıyor; altın ayrıca dönüyor.
   - Kafa üstündeki "?" hem sallanıyor hem dönüyor.
   - Silah efsun konturu sürekli nefes alıyor.
3. **Saf beyaz ve aşırı parlak renk:**
   - Düşman vuruş parlaması saf beyaz.
   - Öfke tonu (1,7 / 0,3 / 0,3) 1'in üstünde, aşırı parlak bir kırmızı.
   - Şimşek tüm ekranı iki kez %30-45 parlatıyor.
   - Oyuncu tarafındaki yazılar saf beyaz, siyah konturlu.
4. **Aynı anlam, çok dil:** "burada tehlike var" uyarısı 7 renk ve 4 çizim tarzıyla gösteriliyor. Dost alan halkaları da tehlike renginde.
5. **Renk anlamı çakışıyor:**
   - Mavi: kalkan, tehlike alanı ve uyarı bildirimi.
   - Yeşil: can, zehir ve Medusa ışını.
   - Kırmızı: hem tehlike hem en iyi kademe.
   - Ayrıca üç ayrı kademe merdiveni var.
6. **Piksel dili kırık:**
   - Bazı efektler yumuşak süzgeçli (LINEAR), bazı animasyonlar ölçeği kesirli büyütüyor.
   - Efekt pikseli 0,6 ile 3,0 arasında değişiyor.
   - Kusursuz vektör daireler, basık piksel elipslerle yan yana duruyor.

## Cozy'yi taşıyanlar: silme, sadece sıklığını ve gücünü kıs
Sıcak ahşap HUD, gece ışıkları ve gündüz-gece döngüsü, ot ve ağaç sallanması, hafif rüzgâr, yaratık animasyonları.
Madde 179 dersi: rengi griye çekme, koyulaştır.

## Görsel dil kuralları (öneri; stil rehberine yeni bölüm olarak eklenebilir)
- **K1 - Yanıp sönme:** en çok 2 Hz, genlik en çok %30. "Az kaldı" bilgisi hızlanan yanıp sönmeyle değil, dolan bir şekille verilir.
- **K2 - Sürekli hareket:** yalnız canlılarda ve tehlikede. Yerdeki eşya, kafa üstü simge ve silah konturu durur; görünürken bir kez "pop" yapar, sonra sabit kalır.
- **K3 - Parlaklık:** en parlak renk krem `TEXT` #f3e6cc. Saf beyaz ve 1'in üstünde ton yok, şimşek dahil.
- **K4 - Renk = tek anlam:**
  - Sıcak kırmızı-turuncu yalnız düşman tehlikesi.
  - Mavi yalnız kalkan.
  - Yeşil yalnız can ve iyileşme.
  - Mor yalnız Ruh ve nadir.
  - Dost alan halkaları krem ya da altın (gerekirse oyuncu rengi).
  - Roller `hud_theme.gd`'ye eklenir: `DANGER`, `DANGER_HI`, `FRIEND_RING`.
- **K5 - Piksel:** tek ızgara, `NEAREST`, ölçek animasyonu yok. Stil rehberi 3. bölüm bunu zaten söylüyor ama efektlerde uygulanmıyor.

## Öneriler

### Aşama 1 - Hızlı ayarlar (her biri birkaç satır, etkisi büyük) - OYUNDA (madde 711; öfke tonu (1,3/0,65/0,6) olarak ortada tutuldu)
| # | Ne | Şu an | Öneri | Yer |
|---|---|---|---|---|
| 1 | Gece ışığında dither | Bayer 4x4, `light_dither` 0,4, her gece tam ekran (kalıcı "dither yok" kuralına aykırı) | 0 = düz bant | `shaders/atmosphere_grade.gdshader:58` |
| 2 | Her kare tersine dönen dama, Bayer çözülme | `disc_dither` paritesi `int(_t*60)`. Bayer: Assasin hayaleti, Elara ikizi/ardıl görüntüsü, ult çizgisi, görev eşyası parıltısı | Düz alfa disk ve düz alfa sönme | `fx_spirit_can.gd:104`, `fx_spirit_blink.gd:70`, `fx_totem_puff.gd:80,88`, `assasin_ghost.gdshader`, `elara_fx.gd:61-101`, `fx_assasin_ult_streak.gd`, `mission_collect_item.gd:95-116` |
| 3 | Şimşek flaşı | +%30-45, çift flaş, fırtınada 3,5-8 sn'de bir, ayarı yok | Tek flaş, +%10-12, yavaş sönüm | `weather_storm.gd:157-158`, `atmosphere_math.gd:120` |
| 4 | Şok durumu | Sarı çatlaklar 0,09 sn'de bir rastgele yeniden çiziliyor (~11 Hz), alfa 0,95, sürüye yayılıyor | 0,3 sn, alfa 0,6 | `fx_shock_status.gd:8` |
| 5 | Düşman vuruş parlaması | Saf beyaz, %100, 0,12 sn. Alan hasarında 60 yaratık birden beyazlıyor | Krem, %50-60 | `hit_flash.gdshader:11`, `enemy.gd` `flash_amount` |
| 6 | Öfke tonu | (1,7 / 0,3 / 0,3), canı düşük her yakın dövüşçüde | (1,15 / 0,8 / 0,75) ya da kaldır | `enemy.gd:315` |
| 7 | Gece namlu ışığı | Makinelide ~12 Hz yanıp sönen ışık | Ateş sürerken sabit ışık | `night_glow_catalog.gd:124` |
| 8 | Yerdeki eşyalar | Hepsi 3 px / 1,57 sn, aynı fazda; altın ayrıca 8 fps dönüyor | Rastgele faz, 1 px, 2,5 sn; altın dönmesin (birkaç saniyede bir parıltı) | `gold_drop.gd:88-92`, `food_drop.gd:118`, `magnet_drop.gd:53`, `weapon_shard_drop.gd:50`, `chest_drop.gd:48`, `mission_collect_item.gd:72` |
| 9 | "?" arama simgesi | Sallanma + ±0,2 rad dönme (dönen piksel sprite titrer) | Yalnız 1 px sallanma | `fx_brush_search_status.gd:117-119` |
| 10 | Silah efsun konturu | Sürekli nefes (0,82-1,0) | Sabit | `enchant_weapon_glow.gd:87` |

### Aşama 2 - Ekran sarsıntısı (karar senin)
- Varsayılan %100, sarsıntı 30 Hz'lik piksel titremesi. Öneri: varsayılan %60 (ayar duruyor).
- **Müttefik yetenekleri herkesin ekranını sallıyor**, çünkü sarsıntı sahnenin `_ready`'sinde her eşte çalışıyor:
  - Matthew Nova 0,85 + 3 vuruş 0,3 (`fx_matthew_sheet.gd:72-82`)
  - meteor 0,55 (`fx_meteor_strike.gd:71`)
  - Matthew patlaması 0,55, Korsan patlaması 0,4
  - Paladin kırılması 0,5
  - Öneri: yalnız kasterde sallasın, uzak kopyada sallamasın.
- **Mesafeye bakmayan sarsıntılar:**
  - Minotaur hücum 0,32 ve çarpma 0,5 herkese uygulanıyor (`enemy.gd:433,524`, `minotaur_math.gd:38`). Öneri: `add_at` ile mesafeye göre azalsın.
  - Kardeş meteoru 0,25 sn'de bir 0,3 veriyor, sarsıntı neredeyse kesintisiz (`kardes_zone.gd:82`). Öneri: her taşta değil, yalnız ilk düşüşte bir kez.

### Aşama 3 - Tek tehlike dili (orta iş; görsel dilde en büyük kazanç)
Şu an aynı anlam 4 çizim tarzı, 7 renk ve 1,4-5,7 Hz arası farklı nabızlarla gösteriliyor:
- **Çizim tarzları:**
  - basık piksel elips (0,62)
  - piksel sprite veya karo
  - kusursuz vektör daire
  - bantlı poligon
- **Renkler:** kırmızı, turuncu, sarı, mavi, yeşil, pembe, mor.

Öneri:
- **Tek biçim:** zemine yatık basık piksel şekil, dünya ızgarasında, 1 sanat px kontur ve %20-25 dolgu.
- **Tek renk ailesi:** `DANGER`. Boss kimliği halkanın rengiyle değil, içindeki küçük bir motifle verilir (Gonca'da gül yaprağı, Banshee'de dalga çizgisi gibi).
- **Zamanlama:** alan içten dışa dolar, dolunca vurur. Yanıp sönme ya hiç olmaz ya da herkeste aynı 1,5 Hz nabız olur.
- **Etkilenen dosyalar:**
  - `creature_nova.gd`, `enemy_thorns.gd`, `enemy_laser.gd:88` (10→34 rad/s), `enemy_charge_lane.gd:65` (9→36 rad/s)
  - `wendigo_rock.gd:76`, `kardes_zone.gd:138`, `pumpkin_blast.gd:42`
  - `gonca_ring.gd:73`, `banshee_wave.gd:138`, `medusa_gaze.gd:89`, `cosmic_beam.gd:96`
  - `boss_glow.gd`: yumuşak, 300 px, katkılı, nabız atan parlama. Sabit piksel parlamaya döner.
- Önce 3-4 prototip: aynı boss saldırısı gerçek oyunda yan yana.

### Aşama 4 - Renk anlamı ve dost halkaları
- **Dost ama tehlike renginde olanlar.** Öneri: hepsi krem/altın `FRIEND_RING`, piksel halka.
  - görev "ele geçir" halkası: kırmızı-turuncu, alfa 0,85 (`mission_zone.gd:17`)
  - evcil hayvan menzili: pembe, Gonca tehlikesiyle aynı aile (`slime_range_ring.gd:11`)
  - Korsan patlatma menzili: turuncu, kabak patlamasıyla aynı ton (`korsan_detonate_range.gd:13`)
  - `_spawn_burst`: neon yeşil/kırmızı parçacık + 2 yumuşak vektör halka, 18 çağrı (`player.gd` ~13121, `fx_ring.gd:22`)
- **Bildirimler:** 9 ayrı tür rengi var, "uyarı" açık mavi (`game_notice.gd:37-45`, `world_event_banner.gd:219`). Öneri: 4 ton.
  - `ACCENT`: iyi, başarı
  - `BAD`: başarısız, tehlike
  - `DIM`: bilgi
  - `SOUL`: başarım
- **Kademe merdivenleri birleşsin** (anlamlı renk, karar senin). Öneri: tek merdiven (`TIER_COL`); en üst kademe kırmızı değil altın olsun, kırmızı tehlikeye kalsın.
  - XP: yeşil / mavi / mor / sarı / kırmızı (`xp_orb.gd:73-79`)
  - silah: yok / yeşil / mavi / mor / kırmızı
  - level kartı: gri / mavi / mor / kırmızı
- **Kalkan mavisi** tehlike alanında kullanılmasın: Banshee ve Kardeş'in mavi halkaları K4'e göre değişir.

### Aşama 5 - Yazılar ve kafa üstü
- **İki ayrı hasar yazısı sistemi var.**
  - Yaratık sayıları sakin: en çok 24 tane, birleşiyor, krem/turuncu, m5x7 16.
  - Oyuncu tarafı farklı (`floating_text.gd`, `player.gd`'de ~74 çağrı): sınırsız, birleşmesiz, saf beyaz + siyah kontur, can/kalkan sayıları 24 px.
  - Hasar Sayıları ayarı oyuncu tarafını kapsamıyor.
  - Stil rehberi "alınan hasar mavi" diyor, oyunda beyaz.
  - Öneri: aynı havuz ve birleşme, rehberin renkleri, 16 px, ayar bunu da kapsasın. "BOMBA YOK" gibi durum sözleri küçük ve krem olsun.
- **Müttefik sayıları** ±15 px dağınık çıkıyor, seninkiler sabit -30'da (`remote_player.gd:3258`). Öneri: aynı yer.
- **Kafa üstü durum döngüleri sınırsız:** sersemleme 10 fps, zehir 12 fps, yanma, korku, dönen delilik spirali. Öneri: yalnız en yakın 8 yaratıkta oynasın, gerisi tek kare.
- **Üç ayrı "!" çizimi** var (`fx_brush_search_status`, `fear_emote.gd`, `chat_window.gd:53`). Öneri: tek çizim.
- **Barlarda kalkan sırası ters:** elit barında kalkan canın üstünde, oyuncu barında altında (`elite_bar.gd:90-97`, `overhead_bar.gd:299-305`). Öneri: aynı sıra.
- **Kendi karakter kimliği** (madde 425 öneri 3, bekliyor): ayağın altında ince krem bir piksel halka. Kalabalıkta yerini hemen bulursun.

### Aşama 6 - Ekran kenarı ve hava
- **Kenar karartma katmanları üst üste biniyor:**
  - vinyet 0,128, gece 0,205
  - görüş sisi: 250 px elips, karartma 0,32, doygunluk -0,30
  - gizlenme kararması 0,58
  - Öneri: sisin geçişi genişlesin (iç parlaklık artmadan), gece vinyet çarpanı 1,6'dan 1,2'ye insin (`atmosphere.gd:76`, `vision_fog.gd`). Madde 529 öneri 5 ile aynı.
- **Rüzgâr:** açık havada her havada 9 beyaz esinti + 8 yaprak var. Ayarı var, varsayılan açık. Öneri: sakin havada 4 esinti, alfa 0,4 (`weather_wind.gd:37-57`).
- **Yağmur:** ekranda 170 damla (tavan 720), ayarı yok. Öneri: Efekt Yoğunluğu "Azaltılmış"ta yarıya insin (`weather_rain.gd:22-46`).
- **Yüzey haritası parlaklık/doygunluk** (madde 529 öneri 1): hâlâ en büyük tek kalem, bu turda yeniden öneriliyor.

### Aşama 7 - Piksel dili ve arayüz kalıntıları (düşük öncelik)
- **Yumuşak süzgeçli efektler:** `baked_fx.gd:12` varsayılan olarak LINEAR.
  - Bulanık görünen 8 yetenek: `fx_assasin_stealth`, `fx_buyucu_fastfire`, `fx_kalkan_yenileme`, `fx_matthew_sacrifice`, `fx_oyku_heal`, `fx_paladin_cast`, `fx_shield_active`, `fx_talha_rage`.
  - Ayrıca `elara_fx.gd:739,848`, `enchant_weapon_glow.gd:126`, `korsan_detonate_range.gd:22`.
  - Öneri: `NEAREST`. Değişikliğin kendisi tek satır ama görünüm değişir, önce yan yana bakılmalı.
- **Kesirli ölçek animasyonu:** `weapon_crit_anim.gd` (0,72-1,3, 19 ara), `weapon_juice.gd`, boss parlaması. Öneri: konum ya da renk animasyonu.
- **Efekt pikseli 0,6-3,0 arası:** `PixelDraw.TEXEL` 1,212 ~40 dosyada, rehber 0,903 diyor. Büyük iş: yeni efektlerde kural olur, eskiler zamanla.
- **Arayüz:**
  - Dükkân ekranlarında 24 boy yazı, 43 çağrı (`inventory_panel`, `level_market_view`, `merchant_shop_screen`, `soul_shop_screen`, `weapon_shop_screen`). Öneri: 32 ya da 16.
  - Etkileşim ipuçları saf beyaz #fff, 24 px (`house_interior.gd:870`, `traveling_merchant.gd:572`, `weapon_shop.gd:440`; `dungeon_manager.gd:303` ayrıca vektör kontur kullanıyor). Öneri: `TEXT` krem, 32.
  - Boss barı (`boss_bar_art.gd:33-42`) HUD'daki tek doygun yüzey (#3065ac / #ae2730). Öneri: doygunluğu ~%20 kıs. Madalyon/çerçeve senin seçimin, ona dokunulmaz.
  - Çubuk sayılarında Nunito (madde 511, senin seçimin) piksel dilinden tek yazı sapması. Not olarak duruyor.

## Önerilen sıra
1. Aşama 1'in hepsi tek turda, sarsıntının yalnız kasterde sallaması da birlikte (ölçülebilir, geri alınabilir).
2. Aşama 3 tehlike dili: 3-4 prototip, gerçek oyunda.
3. Madde 529 öneri 1: yüzey ortamı prototipleri.
4. Aşama 4-5.
5. Aşama 6-7.

## Sınırlar
- Ölçülen şey koddaki parametreler. Gerçek göz yorgunluğu ölçülemez.
- Yalnız 3 kare alındı: tek karakter, ana harita, gündüz. Gece, fırtına ve boss saldırısı karesi bu turda yok.
- Öneriler kodla doğrulanmadı, hiçbir şey uygulanmadı.
