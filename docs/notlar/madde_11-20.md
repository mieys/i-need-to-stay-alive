# CLAUDE.md maddeleri 11-20 (taşındı 2026-10-10; numaralar AYNI, başka dosyalardaki "madde N" atıfları geçerli)

11. **[2026-10-08: şu an boss yok - bkz. madde 39]** **Boss barı (2026-10-05).** Boss'un can/kalkanı SADECE ekranın üst ortasındaki TEK barda gösterilir (`scripts/boss_bar_top.gd`,
   prototip T1 "Ahşap Plaket"; **2026-10-10'dan beri 3. tur R2 "Kafatası Madalyonu"**: solda yuvarlak kafatası madalyonu, iki çubuk sağa bıçak ucu gibi sivrilir,
   isim çubuğun üstünde sola yaslı, 226x38 sanat pikseli, kırmızının arkasında "son hasar izi" (`boss_bar_top.gd trail_step`: 0,45 sn bekler, saniyede bar'ın %55'iyle iner,
   sadece görsel); eski plaket `boss_bar_art.gd top_plaque_wood` olarak duruyor, prototipler `tools/boss_bar_proto/protos_top3.py`; `main.gd` `_boss_bar_top`, CanvasLayer 38): kamera merkezine en yakın canlı boss (histerezisli
   `order_bosses`), her peer kendi ekranı için "boss" grubundan okur (ağdan bir şey gitmez). Boss'un ÜSTÜNDE artık çubuk yok, sadece
   kafatası plakası (`boss_skull_marker.gd`; kafaya göre yerleşim `boss_bar_art.gd head_top_local`, `enemy.gd get_boss_marker_offset`;
   eski `overhead_bar.gd` oyuncu/pet/ağaç için duruyor). Çizim kodla (doku yok): `boss_bar_art.gd` prototiplerin
   (`tools/boss_bar_proto/`, Python) birebir portu. Tuzaklar: (a) `get_overhead_bar_offset()` BAŞKA efektlerde (korku/sersemleme/
   zehir) kullanılıyor, boss çubuğu için DEĞİŞTİRME - ayrı `get_boss_marker_offset`; (b) üst-orta bildirimler (toast) boss barı
   görünürken `get_bottom_y()`'nin altına iner (`_show_network_toast`); (c) bar y=50'de başlar (FPS göstergesi y 8-44, sonsuz mod
   yazısı üstte); (d) boss adları `boss_bar_art.gd NAMES` tablosunda (creature_id'nin rakamsız kısmı). Telefon yerleşimi (ölçek 2,
   görev satırlarının altı) doğrulanmadı. Testler: `test_boss_bar_top`; gerçek 2 süreç + gerçek ekran görüntüsüyle doğrulandı.

12. **Kamera sarsıntısı (2026-10-05).** `scripts/camera_shake.gd`: olay yeri `CameraShakeScript.add(miktar)` / `add_at(dünya_konumu, miktar)`
   (kameraya uzaklığa göre azalır, FALLOFF_RADIUS 1300) / `add_limited(anahtar, miktar, aralık)` çağırır; sürücü düğüm main.gd'de
   (`CameraShakeDriver`) travmayı (0..1, saniyede 1.3 söner) Camera2D.offset'e "fark" olarak uygular (genlik MAX_OFFSET*travma², tam ekran
   pikseline yuvarlı, adımlı 30 Hz, dönme yok; oyun duraklayınca sıfırlanır). AĞDAN GÖNDERİLMEZ: her peer olayı zaten yerelde alıyor, kendi
   kamerasına uzaklığa göre sarsılır. Bağlı olaylar: boss doğuşu (enemy_spawner, sınırlı 3 sn) ve ölümü (enemy.gd die), zafer + Final
   kademesi (main.gd), yıldırım (weather_storm), Matthew/Korsan(büyük)/Paladin/meteor patlamaları (FX script'lerinin kendi _ready/setup'ı: yerel
   ve uzak kopya otomatik), ağır tek vuruş (player.take_damage, maks canın %12'si), kendi ölümün ve dirilmen. Sıradan yaratık ölümü, silah ateşi,
   Bombardıman mermileri BİLEREK sarsmaz (saniyede onlarca kez). Ayar: `UISound.camera_shake_percent` (0 = KAPALI), ana menü + duraklatma
   menüsü ayarlarında "Ekran Sarsıntısı" kaydırıcısı; debug menüsü atmosfer sayfasında hafif/orta/güçlü test düğmeleri. Tuzaklar: sarsıntı çağıran
   FX script'inde konum add_child'dan SONRA verilebilir -> `call_deferred("_shake")`; testlerde UISound'un kaydeden setter'ını çağırma
   (`CameraShake.set_strength_override`); yeni bir "çok sık" olayı sarsıntıya bağlama. Testler: `test_camera_shake` (21), iki süreçli çalıştırma geçti.

13. **Kademe başlangıcı, Romen rakamı, kuru kafa göstergesi, kopya silahları (2026-10-05).**
   - **Kademe, önceki kademenin yaratıkları ölünce BAŞLAR** (saat dolunca değil): `enemy_spawner.gd` `_check_tier_announcement` artık `_resolve_spawn_tier()`
     (KADEME KAPISI) sonucunu duyurur; o kademenin bossu (`_check_boss_tiers`) ve Final (`_final_gate_open`, 1-15. kademelerin sağ kalanları; beklerken
     `_resolve_spawn_tier` yeni yaratık doğurmaz) de aynı kapıya bağlı. Güvenlik: oyunculardan GATE_SURVIVOR_RADIUS (1600) uzaktaki yaratık saymaz,
     GATE_MAX_WAIT_MSEC (90 sn, eskiden 30) dolunca kapı hiç ölmese de açılır - "yaratıklar hiç doğmuyor" hatasına geri dönme. Kademe saati (`_tier_time`)
     aynen akar/boss'ta durur. Yeni "kademeye bağlı" bir şey eklersen saati değil `_spawn_tier`'ı (başlamış kademeyi) oku.
   - **Kademe numaraları Romen rakamıyla** (`scripts/tier_display.gd` `to_roman`/`title`/`ordinal`): kademe bildirimi, koşu özeti, rekor ekranı, başarım
     metinleri ("V. Kademe'ye ulaş."), sandık başlıkları ("KADEME III-IV SANDIK"). Sonsuz KAT numaraları Arapça kalır. Debug menüsü bilerek Arapça.
   - **Kademe bildirimi = sadece "KADEME <ROMEN>" + altında 6 kuru kafa** (main.gd `_tier_banner`, `tier_display.gd` Control: `skull_steps` 0..12 yarım
     adım, kademe 1 = yarım kafa, 16 (FİNAL KADEMESİ) = 6 kırmızı kafa; boss kuru kafa sanatı `boss_bar_art.gd`). Eski "BAŞLADI - güçlendi" yazısı yok.
   - **Kopyanı Öldür kopyası kendi silahlarının mermisiyle ateş eder**: `mission_player_copy.gd` `attack_info(key)` (silah sahnesinden mermi sahnesi/hız/ölçek/
     dönüş/ışın) -> `mission_copy_bolt.gd` mermi görselini kopyalar (betik/çarpışma/ses sökülür, hasar mantığı aynı, `setup` add_child'dan ÖNCE); Şimşek Asası
     anlık ışın (`fx_lightning_beam`). RPC `broadcast_world_event_copy_bolt(from, to, weapon_key)` anahtarı taşır, istemci aynı `attack_info`'dan çizer.
     Testler: `test_tier_starts_when_previous_dead` (15), `test_mission_copy_weapon_visuals` (11); gerçek 2 süreçli LAN çalıştırması geçti
     (kademe bildirimi + kafa satırı + yay oku + şimşek ışını HER İKİ tarafta); canlı görevde gerçek kopya atışı elle izlenmedi.

14. **Telefon sohbet/grup dokunma kuralları (2026-10-05).** Sol sütundaki sohbet günlüğü ve grup listesi joystick bölgesinde (`touch_controls.gd`
   JOY_ZONE) durur; üstüne konan HER kaydırılabilir/dokunulabilir HUD parçası `hud.gd _mobile_joy_exclude()` listesine girmeli, yoksa onu
   kaydırırken joystick de başlayıp karakter yürür (sohbet günlüğü sadece TAŞINCA listede). `touch_scroll.gd` joystick/düğme tutan parmağı
   (`touch_controls.gd owns_touch`) kaydırmaz. Telefonda sohbetin kaydırma çubuğu kapalı (`SHOW_NEVER`, panelin en sağında yalnız duruyordu).
   Sohbet yazma kutusu açıkken `is_chat_typing` hareketi + yetenekleri kilitler; Godot odaktaki LineEdit'i dışarı dokununca bırakmaz, bu yüzden
   `hud.gd _input` dışına dokununca kapatır, sohbet düğmesi aç/kapa çalışır - yeni bir "kutu açıkken oyuncuyu kilitleyen" arayüz eklersen aynı
   çıkış yolunu ver. Test: `test_mobile_chat_party_touch` (gerçek telefonda elle izlenmedi; `MobileUI.enabled` testte `GDScript.set(&"enabled", true)`
   ile açılır, kök `CONTENT_SCALE_ASPECT_EXPAND` olmalı yoksa enjekte edilen dokunuşlar kutuların yanına düşer; BAŞARISIZ test HUD'u serbest
   bırakmaz, sonraki testte eski HUD'un kaydırma kutusu yakalanır - ilk hataya bak).

15. **Geri katılım anlık görüntüsü, koşu kaydı, telefon pencere ölçeği, kapı taraması (2026-10-05 analiz düzeltmeleri).**
   (a) `NetworkManager.rejoin_snapshot_signature`: anlık görüntünün "değişti mi" imzası konum/can/kalkan/altın/öldürme sayısını SAYMAZ (sürekli
   değişirler; eskiden ~4 KB'lık güvenilir RPC her 6 sn'de gidiyordu); kalıcı içerik değişince ya da 30 sn'de bir gider. Anlık görüntüye yeni bir
   alan eklersen sürekli değişiyorsa `REJOIN_VOLATILE_KEYS` / `REJOIN_VOLATILE_GM_KEYS`'e yaz. (b) `GameManager.run_about_to_reset` reset()'ten
   ÖNCE yayınlanır; açık Main koşu sonu toplamlarını yazar (`main.gd _record_run_end_once`, `_exit_tree` ile ortak) - yeniden başlatma yolları
   reset()'i sahne değişmeden önce çağırdığı için o koşu eskiden kayda geçmiyordu. (c) Yeni bir modal CanvasLayer ekranı telefonda ölçeklensin
   istiyorsan `mobile_ui.gd FIT_LAYER_SCRIPTS`'e ekle (zafer + rekor pencereleri eklendi); `MenuFitter` içerik boyu ilk 0.6 sn'den sonra da
   değişirse (geç gelen takım tablosu satırları) baştan ölçer. (d) `enemy_spawner.gd _process`: boss/Final/sonsuz boss dalgası tetikleri
   0.25 sn'de bir bakılır (kapı kapalıyken "enemies" grubunu her karede taramasın); testler `_check_*` işlevlerini doğrudan çağırır.
   Testler: test_rejoin_restore, test_run_records, test_victory_and_records_ui, test_tier_starts_when_previous_dead.

16. **Yükleme ekranı takılması (2026-10-05).** `loading_screen.gd` GDScript'leri ARTIK ana iş parçacığında yükler: arka planda
   (`load_threaded_request`) derlenen player.gd/main.gd içindeki `preload("...tscn")` çağrıları rastgele "Could not preload resource
   file" ile başarısız oluyor ve görev sonsuza dek "devam ediyor" kalıyordu (bar %20-30'da sonsuz takılma, host dahil; headless
   ölçüm 10 denemenin 2-3'ü). Doku/ses/sahne arka planda kalır + 12 sn bekçi. İstemci, host yüklemesini bitirmediyse 120 sn bekler
   (`NetworkManager.is_host_loading_done`; eskiden 30 sn sonra host'suz başlayıp "Node not found: Main" RPC seli yağıyordu - log'da 1025 kez
   görülen hata bu). Yükleme akışını denemek için: `change_scene_to_file("res://scenes/loading_screen.tscn")` + `current_scene.name == "Main"`
   bekleyen `-s` çalıştırıcısını ART ARDA 10+ KEZ koş (her biri ayrı süreç; ilk koşuda hata aralıklı). Test: test_loading_screen_script_loading.
   Bedeli: betik derlenirken animasyon kısa donar (en uzun kare ~2.4 sn, main.gd).

17. **Telefon kaydırma "başa dönüyor" (2026-10-05).** `touch_scroll.gd` bırakma hızını artık son 120 ms'nin NET yer değiştirmesinden
   (`_release_velocity`) hesaplar. Eskiden her sürükleme olayında "olay arası duvar saati" ile anlık hız çıkarılıp süzülüyordu: aynı
   karede gelen olaylarda dt ~ 0 olunca hız şişiyor, parmak kalkarkenki küçük TERS titreme savrulmayı ters çevirip listeyi başa
   fırlatıyordu (headless: titremeli bırakmada kaydırma 162 -> 0). Dokunma hızı gerektiren yeni bir kod yazarsan olaylar arası duvar saatine
   değil pencereli toplam yer değiştirmeye bak. Test: test_touch_scroll_fling. Gerçek telefonda denenmedi (enjekte edilen olaylarla).

18. **Takılma kaydedici + günlük koruması (2026-10-06).** Kullanıcı "bazen seyyar satıcı dükkanı ETKİLEŞİM ile açılırken tüm oyun birkaç saniye
   donuyor (PC, çok oyunculu oda)" dedi; kod okuma + ekransız/gerçek-renderer + tek süreçli Main ölçümlerinde (150 yaratık) TEKRAR ÜRETİLEMEDİ
   (dükkan kurulumu 50-190 ms, en uzun kare 10-15 ms). `scripts/hitch_log.gd` (GameManager çocuğu) 300 ms'den uzun kareyi user://hitch_log.txt'ye
   yazar: sahne, mp/host, yaratık sayısı, kare içi script (proc) / fizik (phys) süresi, nesne/çizim sayısı, son olay işaretleri
   (`HitchLog.mark`, dükkan açılış/kurulum işaretli). proc/phys küçük ama kare uzunsa bekleme kodun DIŞINDA (GPU/disk/ses/ağ). Kullanıcı bir daha
   takılırsa `%APPDATA%\Godot\app_userdata\Temiz Sürüm\hitch_log.txt` dosyasını OKU. Başsız çalışmada kapalıdır. Ayrıca run_tests.ps1 artık
   `--log-file` ile koşar: ekransız testler eskiden kullanıcının son 10 oyun günlüğünü döndürüp EZİYORDU (gerçek takılma günlükleri kayboldu);
   kendi `-s` çalıştırıcılarında da `--log-file <scratchpad>` ver. Test: test_hitch_log. (Dükkan donması ÇÖZÜLDÜ - bkz. madde 20, kaçak yerleşim döngüsü; kaydedici hâlâ yararlı.)

19. **Kademe 3 denge yumuşatması (2026-10-06).** Kullanıcı: "kademe 3'ten sonra oynanamaz, öncesi aşırı kolay (istediğim buydu), arada bariz fark".
   Ölçüm (gerçek kodla, tek oyunculu; `R` = ortalama yaratık etkin canı / doğuş aralığı = saniyede öldürülmesi gereken can): K1 9, K2 46, **K3 242
   (x5.3)**, K4 408, K5 947, K8 5745; ilk boss (K3) etkin canı ~19.500. Kök nedenler: K1-2'nin x0.8 kesintisi K3'te bir anda kalkıyordu, %30
   soğurmalı kalkan K3'te tam güçle başlıyordu (etkin can x1.43), K3'te yeni roster (zombi/iskelet2), doğuş sıklığı K3->K8 x3.9 artıyordu ve ilk
   boss orantısızdı (boss boyutu Kademe'yle doğrusal). Yapılanlar (hepsi `enemy_spawner.gd`, Kademe 1-2 BİLEREK aynı): `difficulty_ramp` 0.001->0.0006;
   kalkan soğurması K3'te 1/5'ten K7'de tam %30'a (`regular_shield_protection`); K1-2 kesintisi K3-5'te 0.85/0.90/0.95 ile kalkar
   (`early_durability_cut`) ve aynı tablo K3-5 HASARINA uygulanır (`early_damage_taper`); `BOSS_PACING` K3 can x0.6/hasar x0.8, K6 x0.75/x0.9, K8
   x0.85/x0.95 (boss ödülü bölünerek korunur). Sonuç R: K2 43, K3 131, K4 235, K5 549, K6 740, K7 1335, K8 2108; K3 bossu ~11.700 etkin can.
   Kalkan çağrısı dört doğuş yolunda tek yardımcıda (`_enable_regular_shield`), boss can/hasar formülü host+istemci için tek yerde (`boss_base_stats`).
   **+ Hasar %10 (kullanıcı isteği 2026-10-06: "Kademe 3 ve sonrasının hasarını %10 düşür")**: `LATE_TIER_DAMAGE_MULT` 0.9 / `LATE_TIER_DAMAGE_MIN_TIER` 3, tek yer
   `enemy_spawner.gd tier_damage_mult(tier, is_boss)` (normalde `early_damage_taper` x0.9, bosslarda sadece x0.9; Kademe 1-2 aynı; sonsuz katlar/Final dahil) ->
   `_apply_global_buff` temas + menzilli hasara; yetenek hasarları contact_damage'den türediği için onlar da düşer. Test: test_tier_pacing (mutasyon denendi).
   **+ Dayanıklılık %10 (kullanıcı isteği 2026-10-06: "3. kademeden sonra zorluğu genel olarak %10 daha düşür")**: `LATE_TIER_DURABILITY_MULT` 0.9, `late_durability_mult(tier)`
   -> `_apply_global_buff` can + kalkan (K3+, bosslar/sonsuz/Final dahil; doğuş sıklığına DOKUNULMADI); boss ödülü `reward_health /= late_cut` ile aynı kalır.
   Yeni R: K3 118, K4 212, K5 494, K8 1897; K3 bossu etkin can ~10.500, vuruş 45. Hasar + dayanıklılık birlikte: K3+ yaratık ~%19 daha az tehdit.
   Daha fazla düşürmek gerekirse sıradaki kadran `difficulty_ramp` (doğuş sıklığı). Test: test_tier_pacing (mutasyon denendi).
   Hâlâ açık: K10'da roster değişimiyle R x4.6 sıçrar (orman yaratıkları; dokunulmadı), oyuncu tarafı modellenmedi (kapasite tahmini ~175-250 DPS K3'te).
   Testler: test_tier_pacing (6, "uçurum yok" değişmezleri: K2->K3 <= x3.6, sonraki adımlar <= x2.6, K1-2 değerleri sabit); güncellenenler:
   test_enemy_spawner_gate_and_ambush, test_boss_kademe_gate_and_balance. Oyun içinde OYNANARAK doğrulanmadı.

20. **Market donması + çökmesi + telefon market kaydırması (2026-10-06).** Kullanıcı: "markette donma devam ediyor, bu sefer donduktan sonra kapandı; Android'de
   marketteki kaydırma düzelmemiş". KÖK NEDEN (çökme dökümü `%LOCALAPPDATA%\CrashDumps\Lil'Slayers.exe.*.dmp` + yeniden üretim): `merchant_shop_screen.gd` detay
   panelindeki açıklama kutusu (ScrollContainer, dikey çubuk OTOMATİK) çubuk görününce en az genişliği 320 -> 338 olur; panel genişliği eşya adının satır sayısını
   (ör. "Savaşçının Kılıcı" 1 <-> 2 satır) değiştirir, bu sütunun en az yüksekliğini 26 px oynatır, açıklamaya kalan yükseklik (260 <-> 286) çubuğun gerekliliğini
   yeniden değiştirir: metin tam sınırdaysa **yerleşim döngüsü hiç bitmez**; Godot yerleşimi ertelenmiş çağrı kuyruğuyla işler, kuyruk (32 MB, ~1,4 milyon çağrı)
   dolunca oyun donar sonra çöker (`CallQueue::statistics` çıktısı: "TOTAL PAGES: 8192 ... NULL count: 1392619", konsolda milyonlarca "Object was deleted while
   awaiting a callback."). "Bazen" çünkü sadece bazı ad/açıklama uzunluklarında (10 eşya seçiminin ~3'ü). DÜZELTME: `DESC_SCROLLBAR_RESERVE` - çubuk payı baştan ayrılır
   (en az genişlik çubuk görünsün/görünmesin sabit). YENİ KURAL: bir ScrollContainer (yatay kapalı, dikey OTOMATİK) içinde otomatik satır kaydırmalı Label varsa ve
   kutunun/panelin boyutu İÇERİKTEN türüyorsa (CenterContainer'daki pencere, PanelContainer en az boyutu) çubuk payını `custom_minimum_size.x` ile ayır ya da SHOW_ALWAYS
   kullan - aksi halde genişlik <-> yükseklik döngüsü kurulabilir. Tespit aracı: ekransız bir `-s` çalıştırıcısında tüm Control'lerin `minimum_size_changed/resized/
   item_rect_changed/sort_children` sinyallerini say, bir düğüm 1500'ü geçince yolu + boyutları yazdırıp `OS.kill` (düzeltmeden önce 10 koşunun 3'ünde yakaladı, sonra 30/30
   temiz); aynı çalıştırıcı telefon kipinde de 12/12 temiz. Çökme dökümü çözümü: minidump'ı Python ile ayrıştır (istisna adresi, RIP baytları, yığındaki dönüş adresleri),
   exe'nin .text bölümünde `lea reg,[rip+disp]` ile başvurulan dize sabitlerine bak (hangi motor işlevi/dosyası olduğu anlaşılır: burada `callable.cpp` + MessageQueue + Container).
   TELEFON MARKET KAYDIRMASI: detay ve stat panelleri doğrudan PanelContainer'daydı, uzun adlı/tarifli eşyada en az yükseklikleri (868 birim, alan 564) pencereyi ekrandan
   uzun yapıyor, kart ızgarasının kaydırma sınırı 826 <-> 522 oynuyor, liste sıçrıyordu (kaydırmaya başlarken parmak karta basıp seçimi değiştiriyordu). Düzeltme: telefonda yan
   paneller kendi ScrollContainer'ında (`_attach_side_panel_content`, en az yükseklik 0), pencere hep `_phone_rect()` boyunda. Testler: test_shop_layout_loop (2, mutasyonla
   çökmeyi de yeniden üretti), test_shop_phone_layout (3). Gerçek telefonda ve gerçek oyunda elle denenmedi.
