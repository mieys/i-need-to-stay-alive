# CLAUDE.md maddeleri 31-40 (taşındı 2026-10-10; numaralar AYNI, başka dosyalardaki "madde N" atıfları geçerli)

31. **Dükkan/envanter açıkken yetenek tuşları oyuna gitmez (2026-10-08).** Kullanıcı: "dükkan açıkken joystick kullanan insanlar hala yetenek kullanabiliyor... bir tuş hem seçme
   tuşu hem skill tuşu olduğu için market açıkken o tuşa basmak o skili de tetikler". Kök neden: yetenekler `Input.is_action_just_pressed` okur (global bayrak - bir ekranın
   `set_input_as_handled`'ı onu DURDURMAZ) ve dükkanlar oyunu duraklatmaz; hareket `_reading_filter_input` ile kilitliydi ama yetenek girişi hiç süzülmüyordu (seyyar satıcıda
   `is_in_merchant_zone` tesadüfen koruyordu; demirci, mini dükkan ve envanterde koruma YOKTU). Düzeltme `player.gd`: `_skill_keys_blocked()` (sohbet yazımı VEYA kayıtlı engelleyici
   panel `GameManager.is_any_blocking_panel_open()` VEYA açık okuma ekranı) Q/E/R/F girişlerinin (Hadime hayaleti dahil) hepsinde; `_refresh_ui_skill_block` her fizik karesinde (erken
   dönüşlerden önce) kilidi yeniler ve ekran kapandıktan sonra 150 ms daha tutar (KAPATAN basış aynı karede yeteneği tetiklemesin - tuş hem kapat/seç hem yetenek olabiliyor).
   YENİ bir dükkan/panel eklersen `GameManager.register_blocking_panel(self)` (+ kapanışta unregister) YAP, yoksa yetenekler yine sızar. Yeni bir yetenek girişi eklersen
   `not _skill_keys_blocked()` koşulunu ekle. Telefon düğmeleri zaten `touch_controls.gd` içinde aynı paneli kontrol ediyordu. Test: `test_ui_blocks_skills` (5; gerçek tuş basışı,
   gerçek demirci ekranı, mutasyonla 3'ü kırıldı). Gerçek kumandayla elle denenmedi.

32. **Cesedin yanında bekleyen arkadaş, diriltme hakkı sayacını hızlandırır (2026-10-08).** Kullanıcı: "bir arkadaş öldüğünde ve hiç canı kalmadığında canının 5 dakikalık bekleme
   süresi, yanında bulunan ve onu diriltmek için yanında bekleyen her arkadaş başına %80 hızlansın". Sayaç = hakkı 0 olan oyuncunun 5 dk'lık kalp yenilenmesi (`GameManager._process_revive_regen`,
   madde 21b ile birlikte: sayaç dolunca +1 hak, yakında hayatta müttefik varsa ceset "yerde yatan" olup kurtarılır). Kural `game_manager.gd`: oyuncu ÖLÜ ya da YERDE YATAN ise
   cesedinin `REVIVE_REGEN_ASSIST_RANGE` (90 px = player.gd `REVIVE_RANGE`, testle eşitliği doğrulanır) çevresindeki hayatta VE yerde yatmayan her arkadaş için sayaç hızı +0.8:
   `revive_regen_rate(n) = 1 + 0.8 n` (TOPLAMSAL: 1 arkadaş 1,8x, 2 arkadaş 2,6x, 3 arkadaş 3,4x; "çarpımsal" değil - kullanıcı sözünün benim yorumum). Yaşayan oyuncuda ya da yalnız
   cesette hız 1,0. Cesedin konumu: host'ta yerel `Player` ya da `peer_id`'li `RemotePlayer` (ceset sahnede KALIR; Hadime hayaleti için `_revive_anchor_position`). Host yakındaki arkadaşı
   0,25 sn'de bir sayar (`revive_assist_count`), hız değişince `sync_revive_regen(peer, kalan, hız)` ile HEMEN bildirir (üçüncü parametre yeni); istemci aynası sayacı o hızla geri sayar ve
   kalbin yanındaki yazı "m:ss x1.8" gösterir (`revive_hearts_hud.gd`). "Bekleyen" = menzilde durmak (hareketli olup olmaması aranmaz). Tek oyunculuda arkadaş yok -> etkisiz.
   Testler: `test_revive_regen_assist` (7, mutasyonla 3'ü kırıldı); gerçek İKİ SÜREÇ `tools/mp_audit/run_audit.ps1 -Mode revive`: istemci hakkı 0 + öldü + host yanında -> istemcide gösterilen
   sayaç saniyede 1,8 sn düştü, host uzaklaşınca 1,0'a döndü, host/istemci değerleri 0,02 sn içinde eşit, günlük temiz. Gerçek oyunda elle oynanarak (kalp yazısının dock'ta sığması dahil) denenmedi.

33. **Sandık: önce altın sonra kart + kart inince ödül sesi; satış: ikon parçalanıp altına döner (2026-10-08).** Kullanıcı: "sandık açma animasyonunda önce para
   animasyonu görünsün sonra item çıksın... item satınca da itemin parçalanıp altına dönüşmesi" + "kart çıkma sesi gelmedi, kartın ekrana sabitlendiği ana ödüllendirici
   ses". (a) `chest_menu.gd _on_chest_burst`: kapak patlayınca sandığın altını ağzından fışkırır (`_release_chest_gold(.., from_chest=true)`), kart `chest_card_delay`
   (fırlama süresi + 0.2, en çok 1 sn; animasyon atlandıysa 0.15) sonra çıkar. (b) Ödül çınlaması (Reward.wav / elitte Magic Seal) artık patlamada DEĞİL kart inip
   oturunca çalar: `ChestOpenAnim.chime_on_burst = false` + inişte `ChestOpenAnim.play_reward_chime(tree, tier, elite)`; `enchant_screen.gd` (debug) varsayılanla eskisi
   gibi patlamada çalar. (c) `gold_reward_fx.gd`: `give_shattered` (altını ekler + animasyon) / `show_shatter` (altın zaten eklenmişse sadece animasyon); ikon 4x4
   AtlasTexture parçaya bölünür, bazıları paraya döner ve panele uçar (`_launch_shatter`, `_update_shards`); `coin_count`/`burst_duration` TEK kaynak. Satış:
   `chest_menu.gd _on_sat_pressed` (kart ikonu) ve `inventory_panel.gd _do_sell_item` (yuva ikonu, SADECE eşyalar - silah/yardımcı satışı eski). Testler:
   `test_sale_shatter_and_chest_gold_first` (10, mutasyonla denendi). FPS: kullanıcı "bu animasyonlarda fps düştü" dedi; geliştirme makinesinde (150 yaratıklı dünyada
   da) ölçülemedi - animasyonlu/animasyonsuz kare süresi aynı (GPU ~0.7 ms), tek seferlik 40-55 ms kare var (satış anı, `_refresh` + ilk parçalar); gerçek cihazda
   tekrar ederse `tools`/scratchpad'deki ölçüm koşucusu (kare süresi + GPU) ile bak, olası kısaltmalar: SHATTER_GRID 4->3, para üst sınırı, `_pulse_panel` tween yeniden yaratma.
   **KÜÇÜLTÜLDÜ (2026-10-08, kullanıcı: "item satınca çıkan parçalanma efekti ekranı çok kaplıyor ve göz yorucu, animasyonun ve altın dağılımının ufak olmasını istiyorum"):**
   `gold_reward_fx.gd` `SHATTER_GRID` 4 -> 3 (9 parça), parça hızı 45-115 (eskiden 150-380), yerçekimi 380 (820), yukarı tekme 15-55, parça ömrü 0,28-0,42 sn, dönüşüm 0,2 sn + 0,035/para;
   kırılma parlaması en çok 96 px'lik ikon boyunda ve 0,16 sn; para sayısı `shatter_coin_count` = `coin_count` en çok `SHATTER_MAX_COINS` (6; normal ödül 24 kalır), satış parası
   `SHATTER_COIN_SCALE` 1,35 (ödül parası 2,0), saçılma `SHATTER_SPRAY_MULT` 0,4 (paraya `"scale"` anahtarı yazılır, `_update_coins` onu okur). Panele uçuş süresi aynı. Test:
   `test_shatter_stays_small_and_uses_few_small_coins` (parçalar ikonun 1,3 katından uzağa gitmez, az+küçük para, altın TAM; mutasyonla denendi). Gerçek ekranda izlenmedi.

34. **Kalıcı silah özellikleri (efsun) + demirci geliştirmeleri (2026-10-08).** Kullanıcı: "bu efsunlar silahlarda kalıcı olacak tıpkı onlara göre bir özellik
   gibi" (seçimler artifact "Silah Efsunları"nda yapıldı) + "bu efsunlı özellik olarak kendine alan silahların geliştirmeleri blacksmithde 5 parçacık + bir miktar
   altın ile alınabilecek". (a) `EnchantDefs.TRAITS` (silah anahtarı -> efsun, TEK tablo): Bıçak kanayan_kesikler, Pençe kanli_pence, Topuz sismik_dalga, Uzunkılıç
   wind_sword, Ateş Asası destiny, Yıldırım zincir_yildirim, Tabanca seri_parmak, Tüftüf bulasici_salgi, Tüfek delici_mermi, Arcane yankilanan_buyu, Yay uclu_ok,
   Arbalet zincir_civata, Bumerang cifte_donus, Buz Asası kirik_buz, Fişek kivilcim_yagmuru. Silahı alan HERKES doğuştan bu efsunla başlar: tüm ekleme yolları
   `EnchantDefs.new_weapon_entry(key, level, spent)` kullanır (owned_weapons girdisinde "enchant": {"id","ups":[],"final":false}); yeni bir silah ekleme yolu yazarsan onu kullan
   (unutursan `player.gd _apply_enchant_to_weapon` -> `EnchantDefs.ensure_trait` kaydı sonradan ekler). `EnchantDefs.enabled` (kart havuzu) KAPALI kalır, bununla ilgisiz.
   (b) 12 YENİ tanım (DEFS'te, 4 geliştirme + final, metinleri Claude yazdı - kullanıcı "ben yazayım" seçti): davranışlar `scripts/enchants/<id>.gd`, delici_mermi tamamen
   ortak anahtarlarla (script yok). Ortak yeni altyapı `enchant_behavior.gd` "süreli yığınlı hasar" (`dot_add/dot_stacks/dot_remaining/dot_clear/dot_transfer`, 0,5 sn tik, yalnız kasterde;
   kanama elementi ölene kadar sürdüğü için "4 sn kanama" bununla). Kırık Buz: Buz Asası eskiden hiç dondurmuyordu -> özellik her 3. isabette dondurma da içerir (kullanıcının seçim
   sayfasında önizleme "dondur -> parçalan" gösteriyordu); parçalanma `GameManager.enemy_died` + kayıtlı donmuş düşman eşlemesiyle (enemy.gd'ye dokunulmadı). Seri Parmak/Kanlı Pençe öldürme
   algısı `mark_kill` (enemy.gd "evo_kill") + `on_event`. (c) DEMİRCİ: `weapon_shop_screen.gd` yeni 3. sekme "EFSUNLAR" (üstte sahip olunan silah kopyaları seçici, altında 4 geliştirme + final
   plakası); kurallar `weapon_shop_logic.gd` (`wupgrade_*`, `buy_wupgrade`): normal geliştirme 5 parçacık + 100 + 30 x (o kopyada alınan) altın, FİNAL 10 parçacık + 400 altın ve 4
   geliştirme bitmeden satılmaz; geliştirmeler o silah KOPYASINA özel (iki Tabanca ayrı), alım `player.apply_enchant_choice({"type":"step"|"final","slot",...})` yolundan. Altın tutarlarını
   kullanıcı vermedi (benim seçimim, sabitler `WUPGRADE_*`/`WFINAL_PRICE`). Silahı envanterden satınca geliştirmeler iade edilmez. Envanter ipucu kutusu efsun adı + (n/5) gösterir.
   (d) Görünüş: 12 yeni efsun için ÖZEL pixel sanatı YOK (kullanıcı "önce mevcut sanatla" seçti): mevcut sprite sayfaları + `fx()` halkaları kullanılır; özel sanat istenirse
   `tools/gen_enchant_fx.py` desenini izle. Testler: `test_weapon_traits` (8: tablo, tanım şekli, doğuştan kayıt, demirci kuralları + ekran, GERÇEK silah/yaratıkla her özelliğin kendi
   gözlemi - mutasyonla denendi), `test_new_enchants` (21 eski efsun duman testi, yeni 12 hariç). Gerçek iki süreçli çok oyunculu doğrulama YAPILMADI (yeni efsunlar mevcut
   `fx()/sprite()/blast()` yayın yollarını kullanır; kanama tik görselleri bilerek yerel).

35. **Silah kademe göstergesi artık KONTÜR (2026-10-08).** Kullanıcı: "efsun leveline göre verdiğimiz parıltı efektinin daha sade olmasını istiyorum" -> artifact
   "Parıltı Prototipleri"nden **A · Kontür** seçildi; "final hali hafif yanıp sönerken diğer versiyonlar yanıp sönmüyor onun gibi" -> hafif nefes alma TÜM kademelerde.
   `scripts/enchant_weapon_glow.gd` yeniden yazıldı: silüetin dışına kontür (ilk sürüm dünya pikseli dokusuydu; şimdiki yöntem aşağıda: ekran uzayı shader'ı), kademe rengi. **Temel (kademe 1) KONTÜRSÜZ** (kullanıcı: "1. level aynı kalsın" - her silah efsunlu doğuyor, olduğu gibi görünür);
   2 yeşil, 3 mavi, 4 mor, 5 (final) kırmızı, sarı kalktı; renkler ilk başta bilerek SÖNÜK/doygunluğu kısıktı ("silahlarla uyuşmazlık yaşamasın") ama oyunda kayboldu
   (aşağıdaki "OYUN İÇİ GÖRÜNÜRLÜK" notu): TIER_COLORS tek yerden ayarlanır, MIN_TIER = 2; artifact "Kademe Kontürleri" 15 silah x 5 kademeyi çim/toprak/gece zemininde gösterir. FİNAL: ikinci, koyu halka daha.
   **EKRAN UZAYI KONTÜR (2026-10-08, kullanıcı: "bazı silahların dışı pürüzlü ve asimetrik" -> dünya pikseli yumuşatması -> "dünkü parıltı smooth efekti hiç güzel
   olmadı" -> sorulunca "çizgi ince ve kesik kesik"):** kontür artık DOKUYA YAZILMIYOR. Kök neden: kontür dünya pikseli çözünürlüğünde bir dokuydu; oyun 1920x1080
   tuvalini pencereye ölçekleyince (ve ikonlar x0,2-0,5 küçültülünce) o 1 dünya pikseli ekranda bir yerde 1 bir yerde 2 piksel çıkıyordu, silüet pürüzü de çizgiyi kesik gösteriyordu;
   yumuşatma (`_clean_mask`, LANCZOS + 3x3 kapama) ise kenarları şişirip pençe/diken aralarını dolduruyordu - SİLİNDİ. Şimdi doku = ikonun ALFA kapsamı (kaynak çözünürlükte,
   kenarlarda `PAD_WORLD_PX` 9 dünya pikseli boşluk, mip zincirli, `_build_coverage`), ölçek 1 (ikonun ölçeğini devralır) ve shader her ekran pikselinde `dFdx/dFdy(UV)` ile
   "ekranda `OUTLINE_PX` (2,4) piksel çevrede silüet var mı" diye 8 yönde bakar (`ring`) -> kalınlık ölçekten/dönmeden/aynalamadan BAĞIMSIZ sabit, çizgi kesintisiz;
   mip düzeyi ekran pikselinin kapsadığı doku sayısından seçilir (küçültülmüş ikonun gürültülü kenarı süzülür); tam iç pikseller erken `discard` (performans). Final (5):
   `double_ring` -> dışında aynı kalınlıkta ikinci, koyu (x0,55) halka. Parlaklık nefesi shader'da (0,82..1,0, ~2,7 sn). Dış API aynı (`attach(icon, tier)`, `tier_for(ench)`;
   weapon.gd + remote_player.gd dokunulmadı). Tuzaklar: shader'da `TEXTURE` sadece `fragment()` içinde var, yardımcı işlevlere `sampler2D` parametresiyle geçilir; kenar payı
   ikon küçülürse (pad = 9/ölçek doku pikseli, ÖLÇEK `_rebuild`'de okunur) azalır - ikon ölçeği oyunda sonradan %27'den fazla küçülürse en dış halka kesilir. Test:
   `test_enchant_weapon_glow` (6; kademe kuralları, doku kenar payı + mip + alfa korunumu, hizalama, animasyonlu ikon yeniden kurma; mutasyonla 2'si kırıldı; shader'ın kendisi ekransızda
   derlenmez - gerçek renderer'da 0/30/90/135/180/-60 derece, aynalama ve 4 ölçekle ekran görüntüsü alındı, kalınlık sabit). Oyunda hareket halinde, telefonda ve çok oyunculu uzak
   kopyada elle izlenmedi (uzak kopya AYNI attach yolundan geçer).
   **OYUN İÇİ GÖRÜNÜRLÜK (2026-10-08, kullanıcı oyun içi ekran görüntüsüyle: "kontürler oyunda hiç belli olmuyor"):** 1,7 px çizgi + sönük tonlar gerçek çimen/toprak
   zeminde kayboluyordu (özellikle kademe 2 yeşili çimle aynı renkti). Gerçek zemin renkleriyle (çimen 126,176,84 / toprak 150,122,92) 4 varyant yan yana denendi: çizgi 2,4 px +
   canlı tonlar EN İYİ çıktı (şimdiki hâl: yeşil 120,232,90 / mavi 80,160,255 / mor 186,124,255 / kırmızı 255,84,72); koyu dış çizgi ("rim") zemin üstünde KİRLİ göründü, atıldı. Kalınlık/renk
   ayarı `OUTLINE_PX` + `TIER_COLORS` (iki satır). Gerçek oyunda yeniden izlenmedi.

36. **Dükkan pencereleri grup panelinin soluna sığar (2026-10-08).** Kullanıcı: "oyundaki bazı arayüzler içeriğine göre büyüyüp küçülüyor dükkanlar gibi.
   grup panelinin altında kalınca çarpıya basamıyorum". KÖK NEDEN: grup paneli `hud.gd` "PartyPanelLayer" = CanvasLayer 96 (bilerek TÜM modallerin üstünde: hangi ekran
   açık olursa olsun müttefike altın gönderilsin); içeriğe göre boyutlanan, ekran ortasına konan dükkan penceresi (layer 80) kısaldıkça başlık çubuğu/X sağ sütundaki
   grup levhalarının altına düşüyordu. DÜZELTME: `scripts/modal_safe_area.gd` (`reserved_right(tree, view)` / `rect(tree, view)`): panel `party_panel` grubunda
   (party_panel.gd `_ready`), görünürse `Background` çocuğunun sol kenarına + 16 px boşluğa kadar sağ şerit ayrılır (en çok ekranın %40'ı); `weapon_shop_screen.gd` ve
   `merchant_shop_screen.gd` `_apply_window_scale` pencereyi o GÜVENLİ ALANDA ortalar ve gerekirse küçültür, `_refit_if_party_changed` (0,25 sn'lik sayaçta, sadece PC)
   panel sonradan görünür/gizlenir ya da genişlik değişirse yeniden sığdırır. Panel yoksa (tek oyunculu) alan tüm ekran = eski davranış; telefon yolu (`_phone`) BİLEREK
   dokunulmadı. KATMAN SIRASI DEĞİŞMEDİ: grup paneli yine 96'da; seviye atlama/evrim kartları, sandık, ölüm ekranı vb. ekranlara DOKUNULMADI (kullanıcı: "level atlama
   kartlarının falan üstte olması gerekiyor onlara dokunma"). Yeni içerik-boyutlu bir modal pencere eklersen yerleşiminde `ModalSafeArea.rect(...)` kullan. Hâlâ
   kapsam dışı: `mini_shop_screen.gd`, `shop_panel.gd`, envanter/istatistik panelleri (aynı sorun orada görülürse aynı yardımcıyla çözülür). Test: `test_modal_safe_area`
   (6; şerit hesabı, demirci + satıcı pencere kenarı ve X düğmesi şeritle kesişmiyor, sekme değişince, panel sonradan görünür/gizli; mutasyonla 4'ü kırıldı). Gerçek
   pencerede elle denenmedi.

37. **Ateş/Buz Asası alevi asanın BAKIŞINA bağlı (2026-10-08).** Kullanıcı: "ateş asasının alevi ateş asasıyla ayrı yerlerde olabiliyor birbiriyle senkronize değil".
   Ateş/Buz Asası artık doğuştan Destiny özelliğiyle (madde 34) sürekli alev püskürtüyor (`scripts/enchants/destiny.gd`). KÖK NEDEN: alevin yönü dünyada SABİT bir açıydı (`rot`, tikte
   hedeften hesaplanıp 0,25 sn'de bir yenilenir): (1) uzak ekranda kuklanın asası KENDİ yerel hedefine döner (`remote_player.gd _update_local_weapon_aim`), alev ise kasterin yayınladığı
   açıya bakardı -> asa bir yöne, alev başka yöne; (2) yerelde asa yumuşak döner (`AIM_EASE_RATE` 12) ama alev yalnız tikte yön alırdı (mutasyonla ölçüldü: 8,6° sapma). DÜZELTME:
   `fx_enchant_sprite.gd` yeni `follow_aim` + `rot_offset` verisi: yön HER KARE asanın çizili bakışından (`icon_aim_angle(icon, ileri_açı)` = ikon dönüşü + ileri açı, flip_h için PI - ileri)
   + `rot_offset` (koni alt alevinin eksenden açısı) alınır; `destiny.gd` bunu yollar (`part_off`). Konum zaten asanın ucundaydı (weapon_tip.gd). Yerel ve uzak kopya AYNI yoldan geçtiği için iki
   ekranda da alev asanın ucundan asanın baktığı yöne çıkar; hasar konisi (host/kaster) eski yönle (tip->hedef) aynen çalışır - uzak ekranda alev kuklanın asasının baktığı yere gider, hasar yönü değil
   (ikisi aynı "en yakın düşman" algoritmasıyla zaten çoğunlukla aynı yere bakar). `follow_aim` olmayan eski kullanımlar (mutlak `rot`) değişmedi. Yeni bir silaha-bağlı sürekli efekt yazarsan
   yönünü dünyada sabit bırakma, `follow_aim` kullan. Test: `test_destiny_spray_follow` (3: yerel alev yönü asanın bakışıyla ±2°, asa elle çevrilince alev döner, uzak kuklada asa döndükçe alev de
   döner + yenilenen istek açı farkını günceller; mutasyonla 2'si kırıldı). Gerçek iki süreçli oyunda gözle izlenmedi.

38. **Matthew'in evcil hayvanı artık KÖPEK + yeni takip/savaş yapay zekâsı (2026-10-08).** Kullanıcı: "masaüstünde wolf-hellhound spritesheet'i ve wolf-guide resmi var, guide'dan
   öğrendiklerinle matthewin tilkisini bununla değiştir; yetenek açıklamaları isimleri de buna göre" + "adını köpek yapalım hatta kurt değil bu sanırım" + "yeni köpeğin hareket anlayışını
   değiştir, çok bugluydu tilkiyken. Matthewi takip etmesi, çevresindeki yaratıklara saldırması gerekiyordu. takip anlayışı çok tuhaf". (a) SPRITE: `assets/pets/dog/dog_sheet.png`
   (Desktop/wolf-hellhound.png kopyası: 48x48 hücre, 5 sütun, 19 satır: yürüme/koşma 4 yön x 4 kare, yeme/ısırma 4 yön x 5, uluma sol/sağ, uyku) + `dog_frames.tres`;
   ikisini de `tools/import_dog_sheet.py` üretir (kılavuz düzeni orada yazılı). Pet sözleşmesi tilkiden kalma `idle/walk/run/hurt/death x 4 yön`: köpek sayfasında idle/hurt/death YOK ->
   idle = yürüyüşün 0. karesi, hurt = aynı kare, death = uyku (yatma) kareleri; `bite_<yön>` (5 kare, 16 fps) saldırı klibi; eat/howl/sleep hazır ama kullanılmıyor. `scenes/player_pet.tscn`:
   köpek kareleri, ölçek 1, ofset (0,2), + `Shadow` düğümü (köpek sayfasında gömülü gölge yok: `GroundShadow.apply_to` piksel elips, `SHADOW_RADIUS/SHADOW_Y`; sprite gizlenince
   `_set_body_visible` ile birlikte gizlenir). Eski `assets/pets/fox/` DURUYOR (kullanılmıyor, istenirse silinir). (b) İSİMLER: "Tilki Hücumu" -> "Köpek Hücumu" (characters.gd, skill id 43 aynı),
   açıklamalar (köpeğini/köpeğine/köpeğin), evrim kartları (skill_evolutions.gd: Çevik Köpek, Köpek Ruhu, "Köpek vurduğu...", "Köpeğin..."), Q ikonu `matthew_kopek_hucumu_icon.png`
   (`tools/gen_matthew_icons.py` `kopek_hucumu()`: köpek yüzü, hellhound paleti; eski tilki ikonu silindi). KOD İÇİ `fox`/`_matthew_fox_*`/`fx_matthew_fox_*` adları ve Feda Kalkanı kubbesinin
   (kulaklı) görseli BİLEREK aynı kaldı. (c) YAPAY ZEKÂ (`scripts/player_pet.gd` "HEDEF SEÇİMİ + TAKİP + SAVAŞ" notu): eski sorunlar = sahibe 90 px kala durup her adımda 0,2 sn bekletmeli
   DUR-KALK, 220 px'te "kayarak ışınlanma", savaşta hedefe DÖNMEDEN ısırma, anlık hız değişimiyle fırlama, sadece hedef ölünce hedef yenileme. Yeni: TAKİP = sahibin hareket yönünün arkasındaki
   yan "topuk noktası" (HEEL_*), hedef hız = sahibin hızı + hata x HEEL_GAIN (sahip yürürken DURMADAN akar, durunca yumuşakça yavaşlayıp durur; durma 20 px / kalkış 64 px histerezis), hız
   ACCEL ile değişir; SAVAŞ = AKIN (sortie; kullanıcı 2. tur: "silahlarım yakına gelenleri hemen öldürdüğü için köpek hemen hedef değiştirmek zorunda kalıyor, gittiği yönde kararlı bir
   şekilde yaratık öldürüp sonra gelsin, zigzag çizerek kararsızca hedef aramasın"; ilk sürüm "sahibe en yakın yaratık + 70 px daha yakın aday çıkınca hedef değiştir" idi ve silahlar hedefi
   ölünce köpek sürekli başka yöne dönüyordu): köpek sahibinin yanındayken (`SORTIE_REGROUP_RADIUS` 120 px, bekleme `SORTIE_COOLDOWN` 1 sn bitmiş) sahibin FOCUS_RADIUS 240'ındaki yaratıkların
   EN YOĞUN yönünü seçer (`_choose_sortie_dir`: 12 pencere x +-45 derece, eşitlikte en yakın), o yönün +-`SORTIE_SECTOR_HALF_DEG` 55 derece konisinde (sahibe 45 px yakın olanlar her zaman dahil, tasma
   LEASH_RADIUS 360) YAPIŞKAN hedeflerle saldırır: hedef ölene / koniden çıkana kadar değişmez, ölünce AYNI koniden KÖPEĞE en yakın yaratığa geçer (`_pick_sortie_target`, sahibe değil: köpek
   ileri ilerler). Akın biter: koni `SORTIE_END_EMPTY` 1 sn boş kalırsa, köpek tasmayı aşarsa, ya da `SORTIE_MAX` 9 sn dolunca en yoğun yön DEĞİŞMİŞSE (aynı yöndeyse
   `SORTIE_SAME_DIR_DEG` 60 sürer - dönüp aynı yöne çıkmak ters dönüş olurdu); bitince topuk noktasına döner. Yaklaşırken yavaşlar, durunca hedefe DÖNER ve ısırır (`_play_bite` + `_do_cone_attack`); uzak (>480 px: ışınlanma/ev girişi) ya da sıkışmış (1,5 sn ilerleyemedi) köpek topuk
   noktasına ATLAR (`_warp_to_heel`, kopyalara teleport bayrağı), sıkışınca hedef 3 sn yok sayılır; seyyar satıcı güvenli bölgesinde kovalamaz. Animasyon: hız süzülür (`_speed_smooth`),
   idle<->walk<->run eşikleri histerezisli + en az `ANIM_HOLD` sn (klip titremesi yok). (d) ÇOK OYUNCULU: ısırma `broadcast_pet_state(is_attacking=true, sprite_row=yön dizini FACINGS)` ile
   kopyalara gider (yeni RPC yok; kopya `update_network_pet_state` aynı yönde `bite_<yön>` oynar); kopya konumu paketler arası hızdan (`_net_velocity`) AKARAK izler (eski üstel lerp hız
   dalgalanması yaratıp walk/run titretiyordu), durmuş paket ileri besleme hızını hemen sıfırlar, durunca aşma geri geri yürümek yerine kayarak düzelir (`NET_SLIDE_*`). Testler:
   `test_matthew_dog` (12: sayfa/klip sözleşmesi, sahip yürürken durmadan akış, sahip durunca yumuşak duruş + titremesiz bekleme, uzak atlayış, yakın yaratığa koşup dönüp ısırma, AKIN: silahlar
   sürekli öldürürken tek yöne bağlı kalma + boşalan yönden dönüş + tasma + süre sonrası devam kuralı (mutasyonla koni 180 derece açılınca kırılıyor), güvenli bölge, kopya akışı + ısırma klibi + teleport; ESKİ yapay zekâyla 6'sı kırılıyor: 170 karede 52 duraklama, hiç atlamama, hiç saldırmama) + GERÇEK İKİ SÜREÇ
   `tools/mp_audit/run_audit.ps1 -Mode dog` (host = Matthew; `dog_audit.gd` + `dog_audit_compare.py`; host köpeği vs istemci kopyası kare kare): konum hatası ort 4,4 px (p95 17), ısırma 5'e 5,
   günlük temiz. AKIN ÖLÇÜMÜ (sentetik: dört yönde sürekli yaratık, silahlar 0,4 sn'de bir sahibe en yakını öldürüyor, 30 sn, headless): eski mantık 15 hedef değişimi / köpek 2285 px yürüdü; akın 6 hedef değişimi /
   806 px, 3 akın (gerçek iki süreçli denetimde savaş fazında yaratık çok az olduğundan fark ölçülemedi: ikisinde de ~0 ters dönüş). Tuzak: başarısız bir `assert` testi yarıda keser ve `_cleanup()`'a ulaşılmaz -
   sızan yaratıklar SONRAKİ testleri bozar (köpek akın testlerinde yaşandı: ilk hataya bak). Tuzak: klip titremesi/aşma gibi ağ kopyası sorunları TEK süreçli testte görünmedi, iki süreçli denetim ve kare kare hız dökümü buldu. Gerçek oyunda uzun oynanarak
   (özellikle engelli arazide takılma, kapıdan eve girip çıkma, 4 oyuncu) izlenmedi.

39. **Bosslar elit oldu, boss/Final/zafer geçici KAPALI (2026-10-08).** Kullanıcı: "tüm bosslar bundan sonra elit yaratıkların yerine geçsin, elitler gibi hafif büyük ve yıldızlı
   olacaklar, yeni bossları sana sonradan atacağım" + "canları ve kalkanları o kademedeki yaratıkların 15 katı olsun, şuanki halleri boss haliyle çok güçlü olur" + (soruya cevap)
   "her kademenin tek eliti boss havuzundan gelsin" + "Final ve zafer geçici kapansın". (a) ANAHTAR `GameManager.bosses_enabled` (varsayılan **false**, ağdan gitmez): kapalıyken
   `enemy_spawner.gd` `_check_boss_tiers` (Kademe bossları), `_check_final_tier` (13'lü Final), `_final_pending`, "Kademe XVI" bildirimi (`_check_tier_announcement` tavanı 15) ve sonsuzdaki boss
   dalgaları (`_check_endless_boss_wave`) çalışmaz; main.gd'deki "boss dalgası" yazıları da çıkmaz. Kademe saati 15. kademeyi (15 x tier_duration) bitirince `_check_auto_endless` -> `_enter_endless`
   (`begin_endless` ile ortak gövde) oyunu zafer penceresi OLMADAN doğrudan sonsuz Kat 1'e geçirir (yaratık doğumu kesilmez, kapı/bekleme yok). (b) ELİT HAVUZU `ELITE_POOL` = eski 14 boss
   yaratığı (iskelet3, lich3, ork3, agac3, golem3, rontgen2/3, demon3, hayalet3, mantar3, rat3, vampire3, zombie3, iblis3): her Kademe'nin (ve sonsuz katın) TEK eliti artık rastgele roster
   yaratığı değil `elite_candidates(roster_kademesi)` listesinden gelir = havuzdan o kademenin roster AİLELERİNE uyanlar (Kademe 1: fare; 12: ağaç/golem/mantar; 13-15: demon/hayalet/vampir/iblis/röntgen);
   hiçbiri uymazsa (Kademe 9 = sadece slime) komşu kademelere genişler. `_spawn_regular_enemy` elit vadesini id seçiminden ÖNCE atar (`_roll_elite_for`), doğum başarısızsa vade geri verilir
   (`_unroll_elite`). Elit kuralları aynen: yıldız + aura, boy x1,5, hasar x1,5, hız x0,85, garanti elit sandık, sersemletmeye açık; DEĞİŞEN: `enemy.gd ELITE_DEFENSE_MULT` 4 -> **15** (can VE
   kalkan, "o kademedeki aynı aileden sıradan yaratığın 15 katı": testle ölçüldü). Boss koduna/verisine (BOSS_TIERS, FINAL_CREATURES, boss barı/kafatası, zafer penceresi, boss dengesi,
   endless_math boss dalgası) DOKUNULMADI - yeni bosslar gelince `bosses_enabled = true` yap, BOSS_TIERS/FINAL_CREATURES'ı yeni bosslarla doldur (ELITE_POOL elit kalır). Boss akışını sınayan 4 test
   dosyası (`test_boss_kademe_gate_and_balance`, `test_tier_starts_when_previous_dead`, `test_endless_mode`, `test_creature_tier_announcement`) `_spawner()` içinde anahtarı geçici açar.
   Testler: `test_elite_pool_and_bosses_off` (9: havuz = eski boss listesi, aday kuralı, 15 kat can/kalkan, boss yok, otomatik sonsuz, XVI bildirimi/boss dalgası yok, sonsuz elit havuzdan; mutasyonla
   denendi). KAPANAN OYUN ÖZELLİKLERİ (bosslar dönene kadar): "Hayatta Kaldım!" ve 3 zafer başarımı (achievements.gd victory*), "Final Karşılaşması" (tier 16), zafer penceresi/zafer rekoru.
   Gerçek oyunda ve iki süreçli MP'de elit görünümü/yeni havuz izlenmedi (elit RPC yolu eskisiyle aynı: id + is_elite).

40. **Kademe 3 bossu: MINOTAUR (2026-10-08).** Kullanıcı: masaüstü `minotaur` paketi = Kademe 3'ün yeni bossu; "oyuncuya doğru hızlı, geniş çizgi halinde,
   oyuncuya yetişebilecek boynuz dashi; bazen durur hızlanarak koşar; boynuz darbesi hasar verip etrafa savurur (kimse collision'ın içine giremez); Canı 80.000
   Kalkanı 90.000 Kalkan Soğurması %80 Hasarı 100" - aynı gün "kalkanını ve canını %60 azalt" dedi -> NİHAİ can 32.000, kalkan 36.000. Soru sorulabilirdi, sorulmadı - aşağıdaki "Benim seçimlerim" listesi.
   (a) **YENİ BOSS MEKANİZMASI:** `enemy_spawner.gd` `NEW_BOSS_TIERS = {3: ["minotaur1"]}` `GameManager.bosses_enabled` KAPALIYKEN de çalışır (Final, zafer,
   sonsuz boss dalgası, diğer kademelerin bossu kapalı kalır; `_active_boss_tiers()`); `bosses_enabled` açıkken eski `BOSS_TIERS` (testler için). Yeni boss geldikçe
   `NEW_BOSS_TIERS` + `FIXED_BOSS_STATS` (nihai statlar) + `boss_bar_art.gd NAMES` + `SCENES`/`ID_FAMILY` satırı ekle; HEPSİ gelince `BOSS_TIERS` onlarla değişir. Boss
   kurulumu host + istemci için TEK yerde: `_setup_boss_enemy` (eskiden iki kopyaydı). Kademe boss kapısı aynen çalışır: boss ölmeden Kademe IV açılmaz (saat 300 sn'de durur).
   `_spawn_boss_group` boş dönerse (canlı çapa yok) tetik "doğdu" sayılmaz, sonraki 0,25 sn'de yeniden dener.
   (b) **STATLAR** `FIXED_BOSS_STATS["minotaur1"]`: can 32.000, kalkan 36.000 (ilk verilen 80.000/90.000 idi, %60 azaltıldı), soğurma 0,8, hasar 100 - global çarpan zincirini ATLAR (tek oyunculu = tam bu sayılar). Çok oyunculuda
   can/kalkan, tüm yaratıklarla aynı kuralla ekstra oyuncu başına +%50 (hasar büyümez). Altın/XP ödülü Kademe 3'ün eski referans bossuyla (`reward_ref` iskelet3) AYNI. Etkin
   dayanıklılık: kalkanın %80 emmesiyle kalkan 45.000 hasarı yutar (9.000'i cana gider) + kalan 23.000 can = ~68.000 hasar (eski K3 bossu ~10.500; ilk sayılarla ~170.000 idi) - tek tablo, istenirse düşür.
   (c) **HÜCUMLAR** (`minotaur_math.gd` = TÜM sayılar + saf hesaplar; `minotaur_charge.gd` = host durum makinesi, `enemy_abilities.gd`'de "minotaur" ailesi): CHASE (C++ kovalama +
   normal temas saldırısı) -> WINDUP (durur, eğilir; 0,4 sn hedefi izler sonra yön KİLİTLENİR ve yerde uyarı şeridi çıkar, 0,55 sn tepki) -> CHARGE (hareketi BU betik sürer:
   `ability_move_lock` C++ hareketini kapatır, konum her karede elle ilerler - C++ benimser, vampir ışınlanmasıyla aynı yol) -> RECOVER (1 sn; duvara çarptıysa 1,7 sn sersemleme).
   BOYNUZ HÜCUMU: 640 px/sn (oyuncu 252), 76 px geniş şerit, ilk 0,35 sn hafif kıvrılır. BOĞA KOŞUSU (hedef >= 240 px'te %35): 1,25 sn durup kazır, 70 -> 520 px/sn ~1,5 sn'de hızlanır,
   80 derece/sn kavisle kovalar, vurunca 0,5 sn sonra biter. Her hücum her oyuncuya EN FAZLA BİR vuruş (`_hit_ids`). Hücum/toparlanma sırasında C++ temas olayı
   `enemy.gd _ew_on_event EW_E_MELEE` başında `_abilities.melee_blocked()` ile bastırılır (yoksa hasar üst üste biner). Boss düğümü duvar/engele GİRMEZ (`MinotaurMath.step_blocked`,
   `GameManager.is_position_blocked_by_walls`, 22 px pay).
   (d) **SAVRULMA:** hasar `deal_special_damage(kind "minotaur")`, ardından yerel oyuncuda `player.apply_boss_fling(dir, 190)`, uzak oyuncuda yeni RPC `NetworkManager.forward_player_fling_to_peer`
   (`_from_host` korumalı). Savrulma SADECE hasar gerçekten işlendiyse (`player.gd take_special_damage` damgası `_minotaur_hit_msec`, 600 ms) - kaçınan/dokunulmaz/ölü savrulmaz. Mesafe o makinenin duvar
   haritasıyla ÖNCEDEN kısaltılır (`clip_fling_distance`) + `_block_movement_into_terrain` yoklaması savrulma boyunca da çalışır; hız tavanı 560 px/sn (karede <= 9,3 px: 10 px'lik yoklama hücreyi
   atlayamaz). `apply_knockback_force` (400 tavan) DEĞİŞMEDİ.
   (e) **ÇOK OYUNCULU:** karar + hasar + savrulma host'ta. İstemcilere: uyarı şeridi `spawn_synced_world_fx("charge_lane")` (hasarsız kopya), poz `broadcast_enemy_vfx "minotaur_pose"` (host ve istemci AYNI
   `enemy.gd _apply_minotaur_pose`'u çalıştırır; hücum pozunda istemci kuklasının ağ hızı tavanı `_net_speed_cap_override` 760 px/sn'e çıkar - yoksa 3,5x hız sınırında kalıp geriden gelir), toz/sarsıntı
   `"minotaur_impact"`. Konum her zamanki yaratık paketiyle (0,15 sn; kukla ölü hesaplama ile akar). Pozlar saldırı sayfasının kare aralıkları (`enemy.gd _advance_frame_sprite`): eğilme 1-2, hücum 0-2 döngü, doğrulma 3-5.
   (f) **SANAT:** `tools/import_minotaur_sheets.py` (paketin "black outline / 100% (80x80)" sayfaları; paket satır sırası aşağı/SOL/SAĞ/yukarı -> projenin aşağı/YUKARI/sol/sağ düzenine çevrilir) ->
   `assets/enemies/minotaur/`; sahne `scenes/creatures/enemy_minotaur1.tscn` (hücre 80, ölçek 1,6 x boss 1,7). Kullanılmayan paket sayfaları: punch/stomp attack, hitbox sayfaları. Ölüm sesi ork'tan ödünç
   (`creature_death_sound.gd ALIASES`), kan rengi `creature_blood.gd`, boss adı "MİNOTAUR".
   **Benim seçimlerim (kullanıcı vermedi):** çok oyunculu can/kalkan ölçeği; ödül = eski K3 bossu; normal temas saldırısı da 100 hasar / 1,6 sn (sahne `contact_interval`); iki hücumun sayıları/oranları; duvara çarpınca uzun
   sersemleme; savrulma 190 px; "bazen durur hızlanarak koşar" = boğa koşusu yorumu. Hepsi `minotaur_math.gd` / `FIXED_BOSS_STATS` / sahnede tek satır.
   **Testler:** `test_minotaur_boss` (saf hesaplar, durum makinesi sahte yaratıkla: zamanlama/şerit/isabet/duvar/ivmelenme/iptal; gerçek boss statları + ödül eşitliği + kalkan %80 + kademe kapısı; pozlar; ağ hız tavanı;
   şerit; gerçek Player savrulması; GERÇEK HARİTADA duvar kenarında savrulma + boss hücumu, mutasyonla 4'ü kırıldı; debug menüsünden gerçek boss) = 23 test, `test_elite_pool_and_bosses_off` güncellendi.
   **İKİ SÜREÇLİ GERÇEK DENETİM** `tools/mp_audit/run_audit.ps1 -Mode minotaur -Secs 60` (+ `minotaur_audit.gd`, `minotaur_audit_compare.py`; host boss'u istemcinin yakınında doğurur, istemci dört yöne yürür):
   ~9 tam hücum döngüsünde poz dizisi host ve istemcide AYNI, istemcideki boss kuklası hücum süresince ortalama 13 px / p95 35 px (hücum dışı 1,5 px) sapma, ağ gecikmesi ~0,04 sn, istemci oyuncusu her
   isabette tam 100 hasar aldı + 70-310 px savruldu (yürüyüşle birlikte), hiçbir karede duvar hücresine girmedi, uyarı şeridi ve ağ hızı tavanı (760) istemcide göründü. Can/kalkan 2 oyuncuda 120.000/135.000 (x1,5; bu koşu %60 kesintiden ÖNCE alındı, şimdi 48.000/54.000).
   Not: boss oyuncunun >= 15 px yanında durur (C++ gövde engeli küçük) ve hedef < 90 px'teyken hücum etmez (RANGE_MIN) - yerinde duran bir oyuncu sadece temas saldırısı alır; hücumlar oyuncu uzaklaşınca gelir.
   Denetimin sonunda istemcide "harita_baked.tscn:31 Parse Error" görünür: host denetimi bitirip çıkınca istemcide host devri yükleme ekranı açılır, çıkışta yarım kalan yükleme - düzenek artığı, oyun hatası değil.
   **Doğrulanmayan:** gerçek oyunda elle oynanış hissi (hücum/dash hissi, savrulmanın göze nasıl göründüğü), 3-4 oyuncu, telefon, boss savaş süresi/denge (kullanıcıya uyarıldı; ~68.000 etkin hasar). Tam paket: 900 test, tek hata
   `test_endless_mode::test_regular_spawns_in_endless_use_the_scaled_tier_but_the_tier_15_roster` (rastgele: sonsuz katın elit'i havuzdan demon3 gelirse roster kontrolü düşer, 3 koşunun 1'inde; Minotaur'dan bağımsız, madde 39'dan kalma).
