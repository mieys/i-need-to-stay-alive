# Proje notu: Multiplayer'da "yeni yetenek eklerken eskisi kalıyor" hatası

Bu proje Godot 4 tabanlı, co-op multiplayer bir top-down 2D oyun
(`scripts/network_manager.gd` + `scripts/player.gd` + `scripts/remote_player.gd`
üçlüsü ağ senkronunu yönetiyor). Bu dosya, tekrar tekrar karşılaşılan TEK bir
hata sınıfını ve onu nasıl önleyeceğini anlatıyor — yeni bir yetenek/efekt/
animasyon eklerken **mutlaka** oku.

## Hata sınıfı

Kaster (yeteneği kullanan oyuncu) kendi ekranında yeni efekti/animasyonu
doğru görür, ama **diğer oyuncularda eski efekt kalır ya da hiçbir şey
görünmez.** `scripts/player.gd` içindeki geçmiş yorumlarda bunun tam olarak
aynı kök nedenle defalarca yaşandığı görülüyor (ör. `_spawn_buyucu_meteor_
strike`'ın üstündeki "ziva agent" notu, `remote_player.gd`'deki "Meteor
kanalı uzak ekranlarda donuyor" notu, eski dönen kılıcın uzak kopya notu).

**Kök neden:** Bu proje mimarisinde her oyuncunun görsel efektleri/
animasyonları KENDİ istemcisinde üretilir, sonra `NetworkManager.
broadcast_player_vfx` RPC'siyle (ya da senkronize edilen bir state/anim
adıyla) diğer istemcilere AYRICA bildirilir. Yani neredeyse her yeni yetenek
için **iki ayrı yerde** aynı bilgiye (bir sahne yolu, bir animasyon adı, bir
formül) referans verilir. Biri eklenirken/değiştirilirken diğeri unutulursa,
diğer oyuncularda eski/hiç görsel kalır.

## Yeni bir yetenek/efekt eklerken kontrol listesi

1. **Tek seferlik, karaktere bağlı bir FX sahnesi mi?** (ör. bir büyü
   overlay'i, bir buff parıltısı) → `player.gd`'deki
   **`_play_and_broadcast_skill_fx(scene: PackedScene)`** yardımcısını
   kullan. Bu fonksiyon local `instantiate()`'ı VE broadcast'i tek çağrıda
   yapar, yolu `scene.resource_path`'ten okur — elle ikinci bir String yol
   yazmana gerek YOK, yani bu iki yer birbirinden sapamaz.
   ```gdscript
   # Eskiden (İKİ ayrı referans, biri unutulabilir):
   if FxYeniEfekt:
       var fx := FxYeniEfekt.instantiate() as Node2D
       add_child(fx)
   _broadcast_skill_scene("res://scenes/fx_yeni_efekt.tscn")

   # Şimdi (TEK referans):
   _play_and_broadcast_skill_fx(FxYeniEfekt)
   ```

2. **Dünya konumunda sabit duran bir efekt mi?** (meteor, patlama,
   telegraph halkası) → `_spawn_world_explosion_fx` / `_spawn_local_
   telegraph_ring` gibi mevcut konum-tabanlı yardımcıları örnek al; bunlar
   zaten `NetworkManager.broadcast_player_vfx.rpc(...)` çağırıyor.
   `network_manager.gd`'deki `broadcast_player_vfx` fonksiyonunun `match
   vfx_type:` bloğuna yeni bir dal eklemen gerekebilir — eklersen, o dalın
   üstündeki yorumdaki `vfx_type` listesine de ekle (bkz. fonksiyonun
   hemen üstündeki liste).

3. **Sürekli/karede-karede simüle edilen bir görsel mi?** (ör. dönen
   silah, orbit eden bir mermi) → Bunlar performans için AĞDAN POZİSYON
   ALMAZ, her istemci KENDİ kopyasını AYNI formülle hesaplar (bkz.
   `scripts/talon_formation_math.gd`, `scripts/sword_swing_math.gd`). Bu tür bir şey eklersen, formülü
   `weapon.gd` (yetkili/gerçek) VE `remote_player.gd` (kozmetik kopya)
   içine AYRI AYRI YAZMA — `sword_swing_math.gd` gibi paylaşılan bir
   `static func` çıkar, iki taraf da onu çağırsın. Böylece formülü
   değiştirdiğinde tek yeri değiştirmen yeterli olur.

4. **Yeni bir animasyon adı mı ekliyorsun?** (ör. yeni bir `spellcast_*`
   ya da `attack_*` klibi) → `remote_player.gd`'nin `update_position_and_
   anim_from_net` fonksiyonu, gelen animasyon adı o karakterin
   `SpriteFrames`'inde YOKSA **sessizce hiçbir şey yapmaz** (`anim.sprite_
   frames.has_animation(cur_anim)` kontrolü) — hata vermez, sadece diğer
   oyuncuda eski kare donmuş kalır. Yeni animasyonu eklerken karakterin
   `SpriteFrames` kaynağına da (bkz. `characters.gd`) eklediğinden emin ol,
   yoksa bu TAM OLARAK "yanlış/eski animasyon" belirtisini verir.

5. **Sürekli döngüde oynaması gereken bir animasyon mu?** (kanal/channel
   efektleri, örn. büyücünün meteor kanalı) → `update_position_and_anim_
   from_net`, animasyon ADI DEĞİŞMEDİĞİ sürece `anim.play()` çağırmaz.
   Kanal boyunca aynı animasyon adını tekrar tekrar gönderiyorsan, bitince
   kendi kendine döngü yapmayan (`loop=false` / tek karede duran) bir
   animasyonsa, `player.gd`'deki ilgili `_process_*` fonksiyonunda
   `anim.play(...)`'ı `not anim.is_playing()` kontrolüyle yeniden
   tetiklediğinden VE `remote_player.gd`'de de aynı `elif cur_anim.begins_
   with("...") and not anim.is_playing(): anim.play(cur_anim)` dalının
   olduğundan emin ol (bkz. `_process_buyucu_meteor` / `update_position_
   and_anim_from_net` içindeki mevcut örnek — meteor kanalı bu yüzden
   donuyordu, aynı deseni yeni yetenekte de tekrarlama).

6. **Klip ADI kuralları artık TEK yerde: `scripts/char_anim.gd`.** Yetenek
   klibi (`shrug_<yön>` yeni setlerde, `spellcast_<yön>` eskilerde) ve
   "bitene kadar ezilmez" aksiyon klipleri (`attack`/`spellcast`/`shrug_`/
   `hurt_`/`eat_`) buradaki `CAST_PREFIXES`/`ACTION_PREFIXES`'ten okunur —
   hem `player.gd` (`_update_animation`, `_play_cast_animation`) hem
   `remote_player.gd` (`is_cast_anim`) aynı listeyi kullanır. Yeni bir
   tek seferlik aksiyon klibi (ör. `pickup_`/`strike_`) oyuna bağlarsan ön
   ekini `ACTION_PREFIXES`'e ekle, yoksa yürüme/bekleme klibi onu yarıda
   keser. Bir yetenek `_activate_skill*` makinesini bypass ediyorsa
   (Vampir R gibi toggle'lar) cast klibini kendi fonksiyonunda
   `_play_cast_animation()` ile elle oynat.
   Dükkan/kart ekranı açıkken oynayan `read_` klibi bir ekran-grubuna
   bağlıdır: yeni bir dükkan/kart ekranı eklersen `_enter_tree()`'de
   `add_to_group(ReadingUiWatcher.GROUP)` yap (bkz.
   `scripts/reading_ui_watcher.gd`) — `get_tree().paused` yapan ekranlarda
   bile çalışır, ekran kapanınca kendiliğinden biter.

7. **Gece ışığı (gün-gece sistemi, 2026-09-25).** Gece yetenek/mermi/namlu
   efektleri karanlığı azaltan ışık saçar. Hangi efektin hangi renk/boyda
   parladığı TEK listede: `scripts/night_glow_catalog.gd` (sahne yolu ya da
   script yolu -> profil). `atmosphere.gd` sahneye eklenen her düğüme bakıp
   ışığı OTOMATİK takar - yerel ve uzak kopyalar aynı yoldan üretildiği için
   ikisinde de çıkar, `remote_player.gd`'ye ayrıca bir şey yazma. Yeni bir
   `scenes/fx_*.tscn` listede yoksa hafif varsayılan bir parıltı alır; doğru
   renk için `BY_SCENE`'e ekle, parlamaması gerekiyorsa (kan/toz/duman/
   gizlilik) `NO_GLOW_SCENES`'e ekle. Kodla kurulan (sahnesiz) efekt SADECE
   `BY_SCRIPT`'teyse parlar. Efekt `top_level` olup kökü (0,0)'da duruyor ve
   dünya koordinatıyla çiziyorsa ışık yanlış yerde çıkar: efekte
   `get_glow_segment() -> [başlangıç, bitiş]` kancası ekle (bkz.
   `night_glow.gd` dosya başı, örnek `fx_lightning_beam.gd`).

8. **İnternet odası (Epic Online Services, 2026-10-02).** LAN'a ek olarak
   PC + Android crossplay: `scripts/net/eos_online.gd` (EosOnline autoload:
   anonim giriş, oda ilanı) + `network_manager.gd` `host_online`/`join_online`.
   Epic P2P tek paketi ~1170 baytla sınırlar; `scripts/net/fragment_peer.gd`
   büyük RPC'leri otomatik böler, yani RPC kodu değişmez - ama YÜKSEK
   FREKANSLI ve büyük bir senkron eklersen `enemy_spawner.gd`
   `ENEMY_SYNC_BATCH` gibi küçük gruplara böl (güvenilmez pakette tek parça
   kaybı tüm mesajı düşürür). Kimlikler `eos_credentials.cfg` (git'e GİRMEZ,
   repo herkese açık; şablon `eos_credentials.example.cfg`). Android gradle
   şablonu (`android/`, git'te yok) kurulunca `python tools/setup_android_eos.py`
   çalıştır.

9. **DEVAM EDEN BÜYÜK İŞ: yaratık sistemi yeniden yazımı (2026-10-03'ten beri).**
   Yaratıklar (enemy.gd ve ona bağlı her şey) aşamalı olarak veri odaklı bir mimariye (`EnemyWorld`) taşınıyor. İş
   birden çok oturuma VE birden çok Claude hesabına yayılıyor; önceki oturumun yaptıklarını hafızadan değil depodan
   öğrenirsin: **`docs/yaratik_yeniden_yazim/PLAN.md`** (plan, mimari, kararlar, tuzaklar) ve
   **`docs/yaratik_yeniden_yazim/ILERLEME.md`** (şu an hangi aşama, sıradaki adım, ölçümler, oturum kayıtları).
   `enemy*.gd`, `weapon.gd`, efsunlar, yaratık sahneleri veya isabet/hasar koduna dokunan HER görevden önce bu ikisini
   oku - başka bir iş yapıyor olsan bile yeniden yazımla çakışmasın. Bu işe devam ederken
   `.claude/skills/yaratik-yeniden-yazim/SKILL.md` adımlarını izle; oturum biterken ILERLEME.md'yi güncellemeyi ATLAMA.
   **2026-10-03'ten beri VARSAYILAN yeni yol** (`scripts/enemy_world/enemy_world_config.gd` `USE_ENEMY_WORLD = true`):
   host / tek oyunculuda yaratık hareketi, hedef seçimi, itilme, isabet sorguları, sis görünürlüğü, y-sıralaması C++'ta
   (`gdextension/enemy_world/`, derlenmiş .dll/.so depoda - C++'a dokunmayan derleyici kurmaz). Yeni kod yazarken:
   (a) yaratık HAREKET/AI kuralı değiştireceksen enemy.gd'deki eski dal yeni yolda ÇALIŞMAZ - `enemy_world.cpp`'yi değiştirip
   4 kütüphaneyi derle (PLAN §6.1); (b) her karede `"enemies"` grubunu tarayan yeni kod yazma - `EnemyQuery.candidates(
   tree, merkez, yarıçap)` (scripts/enemy_world/enemy_query.gd) kullan, süzgeçlerini aynen uygula; (c) yaratığın konumunu
   dışarıdan değiştirmek serbest (C++ benimser), ama fizik gövdesi/HitArea kayıtlıyken KAPALI - mermi isabeti
   `enemy_world_hits.gd` sorgusuyla. Eski GDScript host simülasyonu SİLİNDİ (kullanıcı onayı, 2026-10-03) - geçiş anahtarı
   yok, eklenti derlenmemiş bir platformda (Web, Android armv7) yaratıklar hareket etmez. İstemci (host olmayan) kuklaları da
   C++'ta (F_PUPPET: AI yok, ağ konumunu ölü hesaplamayla izler); `ENEMY_WORLD_PUPPET=0` istemciyi eski GDScript kukla dalına
   döndürür (A/B ve yedek). (d) Birim testleri `tools/enemy_rewrite/run_tests.ps1` ile: test düğümü current_scene olur, yaratıklar
   C++'a kaydolur; yaratık hareketi sınayan test köprüyü elle adımlar (`EnemyWorldBridgeScript._instance._physics_process(DT)`,
   örnek tests/test_enemy_pathing.gd).

10. **[2026-10-08: boss/Final/zafer KAPALI - bkz. madde 39; aşağıdaki akış `GameManager.bosses_enabled = true` olunca geçerli]** **Zafer + Sonsuz Mod + koşu rekorları/başarımlar (2026-10-05).** Final Kademe'nin 13 bossu da ölünce HOST zaferi ilan eder
   (`enemy_spawner.gd` "ZAFER + SONSUZ MOD" bloğu: `_check_victory` -> `NetworkManager.broadcast_victory` -> `main.gd`
   `_on_victory_reached` -> `victory_overlay.gd`). Kalan yaratıklar `enemy.gd dismiss_without_reward` ile ÖDÜLSÜZ/öldürme
   sayılmadan dağılır. Devam kararını sadece host verir ("Sonsuza Devam Et" -> `begin_endless` -> `broadcast_endless_started`).
   Tuzaklar: (a) ROSTER kademesi 15'te kalır, sadece İSTATİSTİK ölçeği büyür (`EndlessMath.scale_tier`: kat 1 = 16; `TIER_ROSTER.get(
   tier, ...)` bilinmeyen kademede 1. kademeye düşer) - yeni doğuş yolu eklersen `_scale_tier_for` kullan ve istemci doğuş
   RPC'sine (`_rpc_client_spawn_creature`) ROSTER değil ÖLÇEK kademesini ver (istemci canı bu sayıdan kendisi hesaplıyor);
   (b) sonsuzda Kademe boss kapısı (`_tier_time` tutma) YOK, kat saati `game_time - _endless_start_time`; (c) yeni bir doğuş/görev
   dalgası yoluna `_run_phase == VICTORY` kontrolü koy (zafer penceresi açıkken yaratık doğmamalı); (d) durum sonradan katılana
   `sync_run_phase_state` ile gider (`_on_peer_needs_game_catchup`). Hesaplar `scripts/endless_math.gd`'de (tek yer).
   Rekor/başarım: `scripts/run_records.gd` (user://records.cfg, her oyuncu kendi makinesinde) + `achievements.gd` (tek tablo,
   "ctx[key] >= min" kuralı - yeni başarım = bir satır). `main.gd _record_run` DEBUG modunda ve headless'ta HİÇ yazmaz; testler
   `RunRecords.set_path_override` ya da `LILSLAYERS_RECORDS_PATH` kullanmalı (gerçek rekorları kirletme). Koşu istatistikleri
   `GameManager.run_kills/run_max_tier/run_elapsed()`; takım tablosu `sync_match_stats`'ın yeni `kills` parametresiyle.
   Testler: `test_endless_math/mode`, `test_run_records`, `test_victory_and_records_ui` (hepsi `run_tests.ps1`); gerçek 2 süreçli akış
   (zafer -> devam -> kat 1/2/3 -> boss dalgası -> yakalama) 2026-10-05'te geçti. Oynarken değerlendirilecek: sonsuz zorluk eğrisi.

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

21. **Efsunlar kapalı, kalıcı ölüden kalkış, minimapte ölüler, Vampir/ork/kademe kapısı ayarları (2026-10-06/07).**
   (a) `EnchantDefs.enabled = false` (scripts/enchant_defs.gd): silah efsunları OYUNDAN çıkarıldı (kart havuzu `enchants_for()` boş) ama
   TÜM veri yerinde (21 tanım, scripts/enchants/*.gd, assets/fx/enchant, enchant_area/behavior altyapısı, testler) - geri açmak için
   anahtarı true yap; efsun kurallarını sınayan testler anahtarı geçici açıp kapatır. Kalkan seçimleri (shield_enchant_defs.gd) ve genel
   kartlar aynen çalışır (elit sandık ekranı onları sunardı; 2026-10-07'den beri elit sandık epik eşya verir, bkz. madde 22). (b) Kalıcı ölü (is_dead, is_downed değil) oyuncunun diriltme hakkı varsa
   (hak yenilenmesi 5 dk) VE hayatta bir müttefik varsa `player.gd _process_permadeath_rise` hakkı harcayıp onu "yerde yatan" (kurtarılabilir)
   duruma çevirir (`rose_from_permadeath` -> main.gd izleyici/ölüm ekranını kapatır, `NetworkManager.report_self_alive_again` host'un
   `_confirmed_dead_peers` kaydını siler; dükkandan diriltme de artık aynı kaydı siliyor - eskiden canlı oyuncu "ölü" sayılıp oyun erken
   bitebiliyordu). (c) Minimap ölü/yerde yatan oyuncuları artık atlamaz: kararmış portre + kırmızı çarpı + nabız halkası. (d) Kademe
   kapısı (eski kademe ölmeden yenisi doğmaz) beklerken kapıyı tutan, görüş dışındaki eski yaratıklar 3x hızlanır
   (`enemy_spawner.gd _gate_rush_tick`, `enemy.gd set_gate_rush`). (e) Ork öfkesi hız artışı x0.85, Vampir R can bedeli %2,5/sn, Vampir Q
   bedelsiz. Testler: test_permadeath_rise_and_dead_minimap_markers, test_enemy_spawner_gate_and_ambush, test_new_enchants,
   test_vampir_cocuk, test_enemy_abilities. Oyunda iki gerçek oyuncuyla elle denenmedi (rise yolu OfflineMultiplayerPeer'li birim testle).

22. **Sandık kuralları: normal = sırayla, elit = herkese epik eşya (2026-10-07).** Kullanıcı: "elit sandıklardan sadece epik item çıkacak çünkü efsunları
   kaldırmıştık; normal sandıklar sırayla oyunculara verilecek, alan kişi sıradaki değilse sandık grup penceresinden o kişinin barına gidecek; elit sandıklar
   herkese eşit dağıtılacak". (a) NORMAL: `NetworkManager.host_award_chest` alıcıyı `advance_chest_turn` / `next_chest_turn` ile seçer (yaşayan katılımcılar peer id'ye
   göre küçükten büyüğe döner, `_chest_turn_last_peer` host'ta tutulur, oda/oyun sıfırlanınca 0; ilk sandık en küçük peer id'ye = host). Sandığı yerden ALAN kişi
   alıcıyı belirlemez (eski "alan alır" ve "1/N rastgele" kuralları SİLİNDİ, `pick_chest_winner` kalktı). Alan ≠ alıcı ise `_rpc_announce_chest_winner(picker, winner)`
   HER peer'de `scripts/chest_pass_fx.gd`'yi oynatır: küçük sandık alanın çubuğundan (müttefik = `party_panel.gd get_row_center`, kendimiz = `hud.gd get_own_bar_center`)
   alıcınınkine uçar; konumlar her peer'de yerel okunur, ağdan koordinat gitmez; çubuk bulunamazsa (telefonda kapalı panel) efekt atlanır, yüzen yazı kalır. Sandığın
   altın payı alıcıyla gider (`_award_chest_gold([winner])` değişmedi). Sıra göstergesi (kimde sıra) kalıcı olarak ekranda YOK - sadece uçuş + yüzen yazı.
   (b) ELİT: `host_award_elite_chest` değişmedi (yaşayan HER oyuncuya birer tane, sıra ilerlemez); açılınca `main.gd _show_elite_chest` artık efsun ekranı değil
   `chest_menu.gd`'yi ELİT modda açar (`setup(player, 0, true)`: `item_pool(true)` = sadece EPİK eşyalar, destekçi-özel olanlar elenir; kart çerçevesi epik (TierSystem 3), elit
   sandık animasyonu/ışınları, başlık "ELİT SANDIK", altın `pop_pending_chest_gold(true)`). Epik de AL/SAT'lı (SAT = fiyatın %70'i); epik slotu (10) doluysa AL kapanır.
   Efsun ekranı (`enchant_screen.gd`) sadece debug menüsünden. Testler: `test_chest_turn_rotation` (10, mutasyonla sıra + epik havuz denendi), `test_chest_system`,
   `test_spiritual_skills_and_rewards`. 2026-10-07 başsız İKİ GERÇEK SÜREÇ (host + istemci, gerçek Main + gerçek kuyruk): 3 sandık -> [host, istemci, host], elit -> ikisi de
   epik aldı, uçuş iki tarafta ters yönlü doğru koordinatlarla oynadı, hata yok. Gerçek oyunda görsel olarak (uçuşun nasıl göründüğü, telefon yerleşimi) elle izlenmedi.

23. **Demirci dükkanı (silah + kalkan satıcısı) ve harita yeniden bake (2026-10-07).** Kullanıcı: "haritayı Harita.tmx üzerinden yeniden bakeler misin ama
   hiçbir şeyi kaybetmesin; yeni blacksmith yapısının kapısından içeri girince yeni bir dükkan, örse yaklaşınca etkileşimle silahlar burada satılsın, kalkanlar
   da, seyyar satıcıda silah satılmayacak". (a) HARİTA: `tools/bake_harita.gd` -> uid'leri eski dosyadan geri yaz -> eskiyle düğüm/materyal farkı (memory
   map-rebake-procedure) yapıldı; shader/materyal/y_sort aynı, 1 TileSet, hücre sayıları TMX ile birebir. Kullanıcının Tiled'da sildiği `tarla` grubu bake'te
   düştü (kodda kullanılmıyordu). Minimap + harita gölgeleri de yeniden pişirildi (`bake_map_shadows.gd` CATS "house" artık `ev/Blacksmith` + `ev/blacksmith kapı`
   içerir); `--headless --import` BİLEREK çalıştırılmadı (iki PNG editör açılınca yeniden import olur; yeni betiklerin .gd.uid dosyaları da o zaman oluşur).
   (b) GİRİŞ/İÇ MEKAN: `scripts/weapon_shop.gd` (main.tscn `WeaponShop`, house_interior.gd deseni, aynı `is_indoors` bayrağı -> yaratık saldırmaz/doğmaz, silahlar
   gizlenir, kamera sınırı kalkar): dış kapı = `ev/blacksmith kapı` katmanının alt kenarı + etkileşim tuşu + kararma geçişi; iç mekan `scenes/silah_saticisi_baked.tscn`
   (`tools/bake_silah_saticisi.gd`, kaynak `harita/silah satıcısı.tmx`) `INTERIOR_OFFSET` (24000,0)'da (ev içi 20000,0'dan 4000 birim yanda); ÇIKIŞ = iç haritadaki
   `blacksmith kapı iç` katmanı (güney duvarda 2 hücre; "içi" DEĞİL "iç"); ÖRS = `Eleman pozisyon` katmanındaki tek karo (görünmez yapılır, yarıçap 84 px
   içinde etkileşim ipucu). Tiled'da bu katman adları değişirse weapon_shop.gd sabitleri güncellenmeli. ÇARPIŞMA çalışma anında: duvarlar (`walls`, `walls_top`)
   TAM; eşya katmanlarında sadece her sütunun en alt karosu (paketin katmanları nesnelerin tüm yüksekliğini taşıyor, hepsini kaplamak kapı cebini odadan
   ayırıyordu: doğma noktasından 11 hücre erişilebiliyordu); kapı önünde yanlarda 2, kuzeyde 3 hücre eşya çarpışması kaldırılır (oyuncu 16 px, tek hücrelik geçide
   sığmaz - testle ölçüldü). Doğma noktası SOL kapı hücresinin ortasının 3 hücre üstü (iki hücrenin ortası komşu duvar karosuna değiyordu). Oda dışı evin içi gibi
   düz SİYAH (kullanıcı seçti, `OUTSIDE_STYLE = &"clean"`): duvar paketinin koyu arduvaz dolgusu (39,38,46) duvar katmanlarında bir renk anahtarı gölgelendiriciyle siyaha çevrilir
   (gri kenar kalmaz; karoyu silmek yerine renk çevrildiği için zemin sızmaz) + zemin dikdörtgeninin dışındaki dolgu karoları silinir; `&"black"`/`&"match"` (gri boşluk) karşılaştırma
   için kodda durur, `set_outside_style` çalışma anında değiştirir. Evin içine dokunulmadı (orada gri kenar zaten yoktu). Önde çizilen
   katmanlar `torches_pillar_n_front`/`walls_top` z=2 (oyuncu z=1). Harita üzerindeki bina çarpışmasızdır (oyuncu/yaratık engeli sadece orman katmanında, kullanıcının
   bilinçli tercihi, bkz. player.gd `_block_movement_into_terrain`) - dokunulmadı. (c) KURALLAR `scripts/weapon_shop_logic.gd` (TEK kaynak, testli): 15 silahın hepsi,
   eski fiyatlar (ShopPanel `_copy_cost_raw`: 2. silah 30, sonrakiler 80; indirim `apply_shop_discount`), en fazla 5 silah, aynı silahtan 2. kopya serbest, ziyaret
   başına 1 kez kuralı YOK; kalkan Savaş/Enerji/Kale 250 altın, Standart'ın yerine geçer ve KALICI (bir tür seçilince diğerleri kilitli - kullanıcı bunu söylemedi,
   eski efsun kuralı; değiştirilebilir istenirse `shield_block_reason` + geliştirme sıfırlama); geliştirmeler (ShieldEnchantDefs `upgrades`, limit 0 = sınırsız)
   tür alınınca satılır, fiyat 100 + 25 x (o satırdan zaten alınan sayı) - fiyatı kullanıcı vermedi, benim seçimim (`UPGRADE_*` sabitleri). Satın alma efsun
   kartlarıyla aynı yoldan (`player.apply_enchant_choice`). (d) EKRAN `scripts/weapon_shop_screen.gd`: solda ayrıntı, ortada SİLAHLAR (2 sütun x 8 yatay plaka) /
   KALKANLAR sekmeleri, sağda envanter (5 silah yuvası + kalkan statları); oyunu duraklatmaz (seyyar satıcı gibi), ESC/B kapatır, kumandada D-pad seçer A satın alır.
   (e) SEYYAR SATICI: artık sadece 8 eşya (`STOCK_SIZE` 8, silah kartları ve ekrandaki SİLAHLAR bölümü silindi; ENVANTER penceresi silahları göstermeye devam eder).
   Tuzaklar: `move_and_slide` coroutine içinde `physics_frame` sinyalinden çağrılınca "Body state is inaccessible" hatası verir (gövdeyi `_physics_process`'ten sür);
   testlerde yaratılan dünyaları `free()` ile sil (`queue_free` "player" grubunu bir sonraki teste sızdırır). Testler: `test_weapon_shop` (16; mutasyonla kapı
   cebi kapanınca fiziksel yürüme testinin kırıldığı görüldü), `test_merchant_*` (eşya kartlarıyla yeniden yazıldı). Gerçek oyunda elle denenmedi; telefon düzeni
   (PHONE_K, merchant'tan kopya) ve iç mekandaki meşale/ocak animasyonları doğrulanmadı.

24. **Silah parçacığı (demirci dükkanında silah almak için para birimi, 2026-10-08).** Kullanıcı: "blacksmithdeki silahların silah parçacığı ile alınmasını
   istiyorum; yaratıklardan %0.5, elitten kesin 1, bosstan 5; oyunculara eşit miktarda gitsin (biri 5 alırsa 5 tane herkese); yemek gibi yerde dursun, hafif yukarı
   aşağı olsun; pixel sanatı hazırla; silah 10 parçacık + bir miktar altın, geliştirme başına 5 parçacık + altın". Soruyla netleşti: altın kısmı AYNI (2. silah 30 /
   sonrakiler 80, kalkan türü 250, geliştirme 100+25n), ve SADECE SİLAH parçacık ister - kalkan türü + geliştirmeler parçacıksız (kullanıcının son cevabı "geliştirmeler
   de parçacıksız"). `weapon_shop_logic.gd` `SHARD_COST_WEAPON = 10`, `SHARD_COST_UPGRADE = 0`, `SHARD_COST_SHIELD = 0`: geliştirmeye 5 parçacık isterse TEK satır
   (`SHARD_COST_UPGRADE = 5`) - kurallar (`*_block_reason`, `buy_*` düşer/iade eder) ve ekran (plaka + ayrıntı) hazır. DÜŞME `enemy.gd` `_drop_weapon_shards` (die()'da,
   sadece host/tek oyunculu): sıradan %0.5 x killer şansı (`LUCK_DROP_MULT_PER_POINT`, diğer drop'larla aynı çarpım - şansın bunu da büyütmesi benim seçimim),
   elit 1, boss 5 AYRI drop (halka şeklinde saçılır, her biri 1); `weapon_shard_count` saf fonksiyon, testli. YERDEKİ DROP `scripts/weapon_shard_drop.gd` +
   `scenes/weapon_shard_drop.tscn` (food_drop deseni: kök ±3 px zıplar, gölge `drop_shadow.gd`, 300 sn sonra kaybolur, grup `weapon_shard_drops`); `WeaponShardDrop.spawn(
   tree, konum, miktar)` "drop yarat + `broadcast_drop` yayını" sözleşmesinin TEK yeri (enemy.gd + debug menüsü bunu çağırır; yeni bir kaynak eklersen onu kullan).
   PAYLAŞIM: toplayan kim olursa olsun yaşayan HER oyuncuya `amount` (BÖLÜNMEZ, altın/sandık payının aksine): `NetworkManager.host_award_weapon_shards` -> host kendine +
   uzak oyunculara `grant_weapon_shards` RPC (sadece host'tan kabul). İstemcide görsel kopya (`network_spawned`) toplanınca `request_drop_pickup(.., "weapon_shard")`.
   SAYAÇ `GameManager.weapon_shards` (+ `weapon_shards_changed` sinyali, `add_weapon_shards`; koşu durumuna/geri katılım anlık görüntüsüne ve reset'e dahil). HUD:
   altın göstergesinin altında `ShardIndicator` (hud.gd `_ensure_shard_indicator`, hud.tscn'e YAZILMADI - editör geri alıyor; grup paneli/debug düğmesi sol sütunun alt
   kenarını `_left_stack_bottom()`'dan alır, yeni bir sol sütun parçası eklersen onu da oraya kat). SANAT `tools/gen_weapon_shard.py` (deterministik, 22x22, 6 kare
   parıltı; çıktı `assets/pickups/weapon_shard/`: `shard_sheet.png`, `shard_icon.png`, `weapon_shard_frames.tres`). Debug menüsü Oyuncu sayfası: "+10/+50 parçacık",
   "Parçacık düşür". Tuzaklar: weapon_shard_drop.gd sahneyi `preload` ETMEZ (sahne betiği önyüklüyor - döngüsel başvuru), `load()` kullanır; `grant_weapon_shards`
   `is_multiplayer_active` değilken reddeder (`_host_peer_id()` bağlı değilken 0 ve yerel çağrının gönderen kimliği de 0). Testler: `test_weapon_shards` (10),
   `test_weapon_shop` (parçacık maliyeti/iade/ekran, 21 toplam); İKİ SÜREÇLİ gerçek LAN: istemcinin üstüne 3, host'un üstüne 2, istemcinin üstüne 5 ayrı drop, ve
   host'un fiziksel toplaması KAPALI iken sadece istemci RPC yolu (6) -> iki tarafta da tam +16, drop kalmadı, uzak drop'un görsel kopyası istemcide göründü.
   Gerçek oyunda elle izlenmedi: parçacığın görünüşü/HUD yerleşimi, telefon yerleşimi, dükkan ekranındaki parçacık satırı.

25. **Derinlik / y-sıralama: karakter nesnenin arkasındayken altında, önündeyken üstünde (2026-10-08).** Kullanıcı: "bir şeyin arkasındayken karakter üstünde olup
   önündeyken arkasında olma mantığı" (yani standart derinlik). Oyuncular z_index 1'de (haritanın tamamının üstünde) olduğundan eskiden hiçbir harita nesnesi
   onları örtmüyordu (sadece otlarda vardı, `grass_sway.gd`). `scripts/depth_occluders.gd` otlarla AYNI "ön kopya" yöntemini genelleştirir (Main'e Y-Sort AÇILMADI -
   FX/yaratık/küre sırası bozulurdu): ağaç ("Shader Eklenecek/Ağaç 0/1/2", sallanan ağaç shader'ına `on_katman` eklendi, kopya aynı köşe kaydırmasını yapar),
   binalar (`BUILDING_GROUPS`: Blacksmith/Ev/kapı/ayrıntı/çatı katmanları 8-komşu bağlı bileşen = TEK kök, çatı ile duvar aynı anda önde/arkada), maden/çalı/düşman üssü
   (`OBJECT_LAYERS`, atlas komşuluğu = nesne) ve demirci iç mekanı (`SMITHY_INTERIOR_LAYERS`, `setup_interior`) katmanlarının bir KOPYASI z_index 2'de çizilir;
   `scenes/derinlik_on_katman.gdshader` kopyada SADECE kökü karakterin ayağından aşağıda olan pikselleri VE sadece karakterin gövde dikdörtgeninde bırakır (yaratık/küre
   örtülmez). Kök hesapları saf işlevlerde (`object_bases`, `building_bases`) - collision de bunları kullanacak. Karakter = yerel + uzak oyuncu (ayak +15, yarım genişlik 11,
   boy 34, grass_sway ile aynı). Orman parçaları/zemin BİLEREK dışarıda. Yaratık-oyuncu: `scripts/creature_depth.gd` (main.gd `CreatureDepth`): oyuncunun ÖNÜNDE
   (ayağı aşağıda) ve örtüşen yaratık geçici z 2; histerezis 2 px; evcil/müttefik dahil değil. Tuzaklar: yassı (zemine serili) bir katmanı OBJECT_LAYERS'a ekleme -
   oyuncuyu ayağının üstünde örter; Tiled'da katman adı değişirse sabitler güncellenmeli (sessizce atlanır). Testler: `test_depth_occluders` (5), `test_creature_depth`
   (2). Gerçek pencereli ekran görüntüsüyle ağaç/ev/maden doğrulandı (oyuncu arkadayken örtülüyor, önde görünüyor); düşman üssü, iç mekan ve yaratık z'si gerçek ekranda izlenmedi.
   (Collision için bkz. madde 27. Yaratıkların ağaç/ev arkasında örtülmesi, kopyaların z 3'e alınması ve çizim sırası koruması için bkz. madde 45.)

26. **Assasin pasifi + Q bekleme, Vampir Q kalkan bedeli (2026-10-08).** (a) Assasin "Bıçak Uzmanlığı" ("yetenek kullanımından sonra 3 sn garantili kritik") HİÇ
   uygulanmamıştı (sadece açıklama metniydi) - şimdi `player.gd _assasin_passive_on_skill_used` (Q `_try_assasin_dash2`, E `_activate_skill2`, R `_activate_skill3`; her kullanım
   3 sn'ye yeniler, oyun süresiyle azalır) -> `_roll_ability_crit` kesin true + `weapon.gd _passive_guaranteed_crit` iki kritik zarında. Yeni yetenek eklerken Assasin için
   AYNI kancayı çağır. (b) Şahin Hamlesi (Q) yük başı bekleme 10 -> 8 sn (`ASSASIN_DASH2_RECHARGE_TIME`). (c) Vampir Q (Kan Emme) kalkan bedelini YENİDEN öder (2026-10-06
   muafiyeti kalktı, `_activate_skill` muaf listesinde id 40 yok); karşılığında Kan Kalkanı evrimi hasarın %3 -> %6'sı (`EVO_VAMPIR_Q_SHIELD_RATIO`) ve Q 3 -> 4 hedef
   (`VAMPIR_Q_TARGET_COUNT`; Kan Ziyafeti hâlâ 5, metni "4 yerine 5"). Testler: `test_assasin_passive` (5), `test_vampir_cocuk` (32), `test_assasin_evolutions`.

27. **Collision "herşey için yeniden hesaplandı": su + bina tabanı + ağaç gövdesi + maden + düşman üssü, oyuncu VE yaratıklar (2026-10-08).** Kullanıcı: "oyundaki collision
   shapeleri yeniden hesapla herşey için"; soruyla: OYUNCU + YARATIKLAR (yol bulma dahil), su + evler/demirci + ağaç gövdeleri + maden/düşman üssü hepsi. Haritada gerçek
   CollisionShape2D yok; hareket engeli bir hücre sorgusu (orman duvarı = `GameManager.is_position_blocked_by_forest`). `scripts/terrain_collision.gd` (TEK kaynak) oyun
   başında (~65 ms) haritadaki karolardan hesaplar: nesne tabanının alt BANDI (ağaç 9 px, ev 28 px, maden 14 px, düşman üssü 12 px; kök = depth_occluders.gd `object_bases`/
   `building_bases`) piksel piksel taranır, hareket engeli KÖK noktasıyla (ayak +15 px aşağıda) sorgulandığı için ayak izi 15 px YUKARI kaydırılır, bir hücre en az 20 piksel
   alırsa engel (orman katmanının 16 px ızgarası). Su = "Su/Su" hücreleri 1 hücre yukarı; "Köprü/Köprü alt" altındakiler açık. Kategori başına sabit `ENABLE_*` (hepsi true);
   `stats` / `by_category` hata ayıklama. API: `GameManager.is_position_blocked_by_walls(p)` = orman VEYA bu hücreler -> HAREKET: player.gd `_block_movement_into_terrain` + ışınlanma/atılış
   noktaları (blink, Elara atılışı, Golem zıplaması, ruhani yürüyüş), skeleton/golem pet, görev kopyası, Hadime kara deliği; `is_position_blocked_by_terrain` (spawn/yerleşim)
   de içerir. BİLEREK SADECE orman kalanlar: mermi, ışın kısaltma, görüş (sis), duvara çarptırma, yetenek menzili (`is_position_blocked_by_forest`) - ağaç/ev/su ateşi ve görüşü kesmez.
   YARATIKLAR + YOL BULMA: `enemy_pathing.gd _build` orman ∪ nesne hücrelerini `_blocked`'a (A* + C++ hareket/akış alanı), SADECE ormanı `_fog_blocked`'a yazar; C++ `EnemyWorld.set_grid` yeni
   6. parametre `fog_blocked` (boşsa eski davranış) ve `fog_ray_blocked` onu kullanır -> su/ağaç görüşü KESMEZ. **4 kütüphane yeniden derlendi** (Windows debug+release, Android arm64
   debug+release; araç zinciri PLAN §6.1) - yeni bir C++ değişikliğinde yine derle. Kapılar da engel (içeri etkileşimle girilir, yakınlık tabanlı). Boşluk: oyuncu duvar önünde ayağı tabandan ~10 px
   uzakta durur (yoklama 10 px, orman ile aynı); arkadan yaklaşınca ayak tabandan ~40 px kuzeyde (derinlik sırası gereği evin arkasında gizli). Zaten engel hücresinin İÇİNDEKİ oyuncu/yaratık
   serbest (hapsolmasın). Tuzaklar: Tiled'da katman adları değişirse terrain_collision.gd sabitleri (test_terrain_collision_objects hepsini sınar); yassı bir nesne katmanını ekleme; yeni bir
   "hareket eden" kod yazarsan `is_position_blocked_by_walls` kullan (mermi/görüş ise forest). Testler: `test_terrain_collision_objects` (8: kategoriler, bina önden/arkadan, ağaç, su + köprü,
   spawn, yol bulma ızgarası, C++ yaratık suya girmez, su görüşü kesmez ama orman keser; mutasyonla 5'i kırıldı), `test_map_terrain_collision` (10, eski "kapalı" iki test ters çevrildi). Gerçek
   pencerede gerçek tuş basışıyla (kırmızı bindirme) bina/ağaç/maden/göl doğrulandı. Gerçek oyunda uzun süre oynanarak izlenmedi: yaratıkların göl çevresinde takılması, kapıya yürüme akışı, telefon.


28. **Çok oyunculu senkron denetimi aracı + bulgular (2026-10-08).** `tools/mp_audit/run_audit.ps1 [-Mode sync|rejoin]`: iki GERÇEK süreç (başsız LAN, host = Assasin, istemci = Vampir),
   her 1 sn'de gerçek durum vs diğer tarafın kuklası, yaratık/drop sayıları, takım durumu, ENet trafiği (`sync_audit_compare.py` raporlar); `rejoin` modu: istemci düşer, aynı kimlikle
   geri katılır, yakalama karşılaştırılır. Yeni bir senkron özellik eklediğinde koştur. Ölçüm (2 oyuncu, ~27 yaratık): yaratık konum hatası ort. ~6 px (p95 ~11), sayılar ±1 (ölüm gecikmesi),
   kukla durumu (silah anahtarları/seviye/xp/zaman/parçacık) eşit, can/kalkan en çok ~1 sn geriden (durum kanalı), host->istemci ~22 KB/s (112 paket/s), istemci->host ~6 KB/s, günlük temiz.
   Bulgular (HEPSİ 2026-10-08'de düzeltildi, bkz. madde 29): (1) rejoin yakalamasında yerdeki drop'lar (XP/altın/yemek/sandık/parçacık) YOK, aktif görev/evcil de yok; (2) rejoin yüklemesinde host'un RPC'leri
   "Node not found: Main" (~5/sn) ve o sırada gönderilen güvenilir yayınlar kayboluyor; (3) 99 any_peer RPC'de gönderen kontrolü yok + reddedilen yabancı bağlantısı kesilmiyor ve
   `_player_count()` (lobby_players) düşman canını şişiriyor; (4) oyuncu konum RPC'si `unreliable` (sıra yok); (5) yaratık durum paketi yaratık başına ~85 B / 0,15 sn.

29. **Çok oyunculu sağlamlaştırma (2026-10-08, madde 28 bulgularının düzeltmesi).** (a) `NetworkManager._from_host()`: host'tan gelmesi gereken ~40 RPC'nin ilk satırı
   (`if not _from_host(): return`; `sync_game_over/sync_team_xp/broadcast_victory/grant_*/open_chest_for_peer/_rpc_client_spawn_creature/_rpc_victory_dissolve...`). Tekli
   oyunda (`is_multiplayer_active` false) HER ZAMAN true - OfflineMultiplayerPeer'de yerel çağrı gönderen "1" görünür ama `_host_peer` 0'dır (ilk sürüm tekli oyunu
   bozuyordu, `test_endless_mode` yakaladı). Yeni bir host->istemci RPC eklersen aynı satırı koy. (b) Başlamış odaya giren yabancı: "Bu oyun başlamış" mesajından 2 sn
   sonra host bağlantısını keser (`_kick_stranger_later`), istemci mesajı korur (`_denied_by_game`). (c) Oyuncu sayısı = `NetworkManager.game_player_count()` (`_game_peers`:
   oyun başında lobideki herkes + kabul edilen geri katılımcılar), `lobby_players.size()` DEĞİL; istemci doğuşunda sayıyı host RPC ile alır (`player_count` parametresi,
   `_apply_global_buff(enemy, player_count)`), yaratığa `mp_player_count` meta olarak yazılır. (d) Sıra numaraları uygulama düzeyinde (Epic'te unreliable_ordered/kanal
   garantisi yok): oyuncu konum paketi `seq` (main.gd `_is_stale_transform`), yaratık paketi `tick` (`EnemySyncCodec.is_stale`); kural tek yerde `enemy_sync_codec.gd seq_newer`.
   (e) Yaratık durum paketi ikili: `scripts/enemy_sync_codec.gd` (22 bayt/yaratık, eskiden ~85). Alan eklersen codec'e + `tests/test_mp_hardening.gd`'ye ekle; paket başı 40
   yaratık Epic ~1100 bayt sınırının altında kalmalı. (f) HAZIR PEER KAYDI: host'un sık yayınları (`game_ready_peers()`) ve istemcilerin Main RPC'leri
   (`main_rpc_targets()`: konum/durum paketleri) SADECE Main'i kurulmuş peer'lere gider (`notify_main_ready_for_catchup` -> `_rpc_main_ready` -> `_publish_ready_roster`);
   yükleme ekranındaki geri katılana ve lobideki yabancıya "Node not found: Main" yağmuru kesildi. Yeni bir Main-düğümü RPC'sini SIK gönderirsen `for p in NetworkManager.
   main_rpc_targets(): f.rpc_id(p, ...)` kullan. (g) Geri katılana yakalama: yerdeki drop'lar (`collect_drop_catchup` / `_rpc_drop_catchup`, aynı `_spawn_visual_drop` kurulumu,
   kimlik tekrarı yok sayılır) ve süren görev (`world_event_manager._on_peer_needs_game_catchup` -> `broadcast_world_event_catchup`, main.gd bildirimsiz kurar). Evcil
   hayvanlar yakalanmaz. (h) BİLİNÇLİ YAPILMAYANLAR: aktarım kanalı ayrımı (ENet'te güvenilmez paketler zaten sıra beklemez; ayrım sadece güvenilir-güvenilir bloklanmayı
   azaltır, Epic'te kanal desteği doğrulanmadı) ve drop yayınlarını toplu gönderme (kazanç küçük, kayıp-sıra riski var). Denetim: `tools/mp_audit/run_audit.ps1 -Mode security`
   (host + istemci + yabancı: sahte host-RPC reddi, yabancı atma, oyuncu sayısı, yaratık canı iki tarafta aynı). Testler: `test_mp_hardening` (10, mutasyonla denendi).

30. **HOST DEVRİ (2026-10-08, kullanıcı isteği: "host çıkınca host devri de olsun").** Oyun SÜRERKEN host düşerse (menüye çıktı = `close_room`, çöktü, ağı koptu ya da 12 sn
   kalp atışı sessizliği) kalan oyuncular otomatik devam eder; lobideyken eski davranış (oda kapanır). Kurallar `scripts/net/host_migration.gd` (saf, testli), ağ/sahne tarafı
   `network_manager.gd` "HOST DEVRİ" bloğu. AKIŞ: host oyun boyunca herkese SIRA LİSTESİ (`_publish_migration_roster`: kimlik, ad, ENet uzak adresi, Epic kimliği; katılım sırası, host
   ilk) + 1 sn'de bir kalp atışı + spawner'ın DEVİR PAKETİ (`publish_host_handover`, ~2 sn) yollar. Düşünce her istemci AYNI listeden aynı adayı seçer (`_try_begin_host_migration`):
   kendi durumunu yakalar (`player.get_rejoin_snapshot()` + takım ilerlemesi + koşu bayrakları), dünyayı DONDURUR (`get_tree().paused`; NetworkManager PROCESS_MODE_ALWAYS), aday kendisiyse
   AYNI portta sunucu kurar (`_migration_host_start`: LAN ENet, internet odasında yeni EOSG sunucusu + oda ilanı) ve yükleme ekranından yeniden açar; değilse adaya bağlanır
   (`_migration_try_connect`) ve BİLİNEN geri katılım akışından geçer (`_rpc_game_in_progress_state` -> otomatik HAZIR -> `request_join_in_progress_game`; yeni host'un o oyuncunun kaydı
   olmadığı için `_rpc_receive_rejoin_snapshot` istemcinin KENDİ görüntüsünü korur). Aday 10 sn (Epic 30 sn) içinde kurulamazsa sıradakine geçilir, 55 sn (Epic 100) sonra
   eski davranışa düşülür (`host_left_game`). SONUÇ (soft restart, bilinçli seçim - kesintisiz devir yerine): herkes birkaç sn yükleme ekranı görür (LAN ~5 sn, çökmede ek ~5 sn tespit;
   Epic ~15-20 sn), kartlar/silahlar/seviye/altın korunur; YARATIKLAR, YERDEKİ DROP'LAR, SÜREN GÖREVLER, evcil hayvanlar, ölü oyuncunun ölü durumu (%35 canla döner) SIFIRLANIR;
   gün/hava (`_last_atmosphere_state`), oyun saati, zafer/sonsuz mod bayrakları ve spawner'ın gizli sayaçları (`export_handover/import_handover`; yaşayan boss'un kademesi "doğdu"
   sayılmaz, hemen yeniden doğar; zaferden önce Final yeniden doğar) korunur. Peer id'ler DEĞİŞİR (yeni host = 1, diğerleri yeni rastgele id) - bu yüzden devir sahneyi yeniden kurar,
   peer id'ye bağlı hiçbir durum taşınmaz. Koşu rekoru çift yazılmasın diye `GameManager.run_record_suppressed`. Tuzaklar: (1) [2026-10-10 DÜZELTME: asıl neden bu DEĞİLDİ - bkz. madde 62f: Epic'in tik'i duraklı ağaçta durduğu için bağlantı hiç kurulamıyordu; `ONLINE_RETRY_SEC` yeniden denemesi
   zararsız ama gereksiz, kaldı] Epic'te istek aday sunucuyu kurmadan gönderilirse ENet gibi yeniden
   denenmez, ASILI kalır -> `ONLINE_RETRY_SEC` ile periyodik yeni istek (ilk deneme gerçekten böyle takıldı); (2) devir sürerken dünya donuk olmazsa silahlar bağlı olmayan eşe RPC atar
   (hata yağar) - `main_rpc_targets()` devirde boş döner; (3) host düşünce EOSG'de birkaç RPC hatası kaçınılmaz (durum "bağlı değil"e dönüp sinyal gelene kadar); (4) devir sırası
   host'tan gelen listeye bağlı: istemci oyunun ilk saniyelerinde liste gelmeden host düşerse devir başlamaz, eski davranış. Test: `test_host_migration` (8) + ÜÇ SÜREÇLİ gerçek denetim
   `tools/mp_audit/run_audit.ps1 -Mode migration [-Kill crash|close] [-Net epic] -Secs 75` (host öldürülür; yeni host ilk katılan; ikinci istemci ona bağlanır; silah/seviye/altın korunur;
   yeni host'un doğurduğu yaratıklar ikinci istemcide görünür; günlükler temiz): LAN çökme + kapanma ve gerçek Epic çökme geçti. Gerçek oyunda elle oynanarak, telefonda, 4+ oyuncuyla ve
   iki aday birden düşünce (üçüncü adaya geçiş) denenmedi.

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

41. **Kademe 5 bossu: YERALTI CANAVARI (2026-10-09).** Kullanıcı: masaüstü "solucan boss" paketi (sand worm). "Yeraltından kocaman solucanlar çıkaran ama yeryüzüne çıkamayan boss; yeryüzüne
   solucan UZUVLARI çıkarır, oyuncunun yakınında rastgele konumlarda doğarlar, bazıları asit atar bazıları saldırır; sürekli oyuncunun ÖNÜNÜ KESMEYE odaklanır, bazı yerlerde dümdüz sıralanıp yolu keser;
   oyuncular uzuvlara saldırarak bossun kendi canını azaltır (uzuvların hasar eşiği var: aşılınca parçalanır, bazıları deliğine geri döner); yeraltından korkutucu sesler; Can 50.000 Kalkan 60.000, asit
   110, solucan saldırısı 130". (Masaüstündeki `boss ve yetenekleri.txt`te aynı boss "Kademe 6 / 60.000 / 70.000 / 120 / 150" yazıyor - sohbet mesajı daha yeni olduğu için ONUNLA gidildi: Kademe 5.)
   (a) **MİMARİ:** boss = GÖRÜNMEZ, VURULAMAZ bir havuz düğümü (`scripts/underground_boss.gd`, `extends enemy.gd`; `enemy_underground1.tscn`): can + kalkan (üst boss barı), C++ EnemyWorld'e KAYITLI
   DEĞİL (`_ew_try_register` boş: mermi/alan sorgularında görünmez, mermiyi yutmaz), `take_damage/take_damage_host/_take_dot_damage` yok sayılır, minimap/silah hedeflemesi meta ile kapalı
   (`hide_on_minimap`, `untargetable`), üstünde kafatası plakası yok. Konumu 0,25 sn'de bir oyuncuların ortasına gider (ganimet/ses oraya). Hasar SADECE uzuvlardan gelir: `worm_limb.gd`
   (`extends enemy.gd`, `enemy_sandworm1.tscn`, C++'a KAYITLI normal Enemy: silahlar hedefler, mermiler vurur) `_apply_damage`'te uzvun YEDİĞİ hasarı `boss.absorb_limb_damage`'e iletir (fazla hasar: sadece
   uzvun kalan eşiği). Toplam hasar = can + kalkan = 110.000 (kalkan soğurması p ne olursa olsun). Soğurma verilmedi -> standart boss %90 (`FIXED_BOSS_STATS["underground1"]`, ödül = K5 referans bossu).
   (b) **YÖNETMEN** (`underground_boss.gd _director_tick`, sadece host/tek oyunculu; sayılar `worm_boss_math.gd`): oyuncu hızını izler; 1,3-2 sn'de bir uzvu bir oyuncunun GİTTİĞİ yönün 150-250 px önüne (+-70 yan; duruyorsa 130-230 px halka)
   çıkarır (hiçbir oyuncunun 95 px içine, başka uzvun 96 px içine, engele/satıcı bölgesine değil); 13-19 sn'de bir hareket eden oyuncunun 200-280 px önüne gidiş yönüne DİK 4-6 uzuvluk DAĞINIK SIRA
   (**2026-10-09'dan beri**: eskiden 5 uzuv 46 px aralıkla dümdüz duvardı, sprite'lar üst üste biniyordu; kullanıcı "dip dibe dizilmesini istemiyorum, daha ayrık ve rastgele olsun" dedi -> `worm_boss_math.gd scattered_line`: komşu yan
   aralığı rastgele 100-170 px, her uzuv gidiş yönünde +-45 px kayık, sıra +-60 px yana kayık, çıkış sırası KARIŞIK ve gecikmeleri rastgele 0,08-0,45 sn, hepsi yakın dövüş; engelli nokta atlanır, en az 2 uzuv kurulabilirse sıra
   başlar). Aynı anda en çok 7 (+ekstra oyuncu başına 2; sıra olayı üst sınırın ÜSTÜNE en çok 6 ekler). SERT GÖVDE: `player.gd _block_movement_into_enemies`
   artık `hard_block_radius` olan yaratıkta (uzuv = 18 px) yumuşak blok (~11 px) yerine sert yarıçapla durdurur ve uzvu itmez; sıra artık geçit BIRAKIR (komşu aralığı >= 100 px -> boşluk >= 64 px > oyuncu çapı 22,8), "yolu keser" ama duvar değil;
   içine girmiş oyuncu geri çekilebilir (tuzak yok).
   (c) **UZUV** (`worm_limb.gd`): çık (0,45 sn) -> bekle -> YAKIN DÖVÜŞ (menzil 104 px, kıvrılma+savurma 0,7 sn, isabet karesi 0,33 sn, savurmadan önce kırmızı nabız uyarısı, 130 hasar, tür "worm", bekleme 1,7 sn) ya da ASİT ATAN
   (yeşilimsi ton; 40-430 px + görüş, 0,3 sn'de ağızdan hedefin o anki konumuna `worm_acid.gd` damlası: 240 px/sn, 110 hasar, tür "worm_acid", kaçınılabilir, orman duvarı/satıcı/Şovalye kalkanına çarpınca sıçrar). Kader:
   %65 PARÇALANIR (eşik 2.000 hasar, `die()` = `dismiss_without_reward`: drop yok, öldürme sayılmaz, toz + ses), %35 DELİĞİNE DÖNER (eşiğin %55'inde, 8 karelik gömülme, gömülürken dokunulmaz/hedeflenemez); ömrü (9-14 sn, sıra 13-17) dolunca da döner.
   Boss ölünce tüm uzuvlar parçalanır. Uzuv hiç hareket etmez (`ability_move_lock` + hız 0), C++ temas saldırısı kapalı (`_ew_on_event`).
   (d) **ÇOK OYUNCULU:** karar/hasar/atış host'ta; `emit_ability_vfx` (YENİ, enemy.gd: yerelde işle + host'sa yayınla) ile "worm_setup" (tür), "worm_pose" (çıkış/savurma/tükürme/gömülme sayfası), "worm_strike" (toz+sarsıntı), boss'un
   "worm_rumble/worm_growl/worm_ambient" sesleri `broadcast_enemy_vfx`'ten HER peer'de yerelde. Uzuv `_rpc_client_spawn_creature`'da `LIMB_IDS` ile çarpansız kurulur (istemcide tier/kalkan/global çarpan yok). Geç katılana `send_catchup_to_peer`
   (tür + poz). TUZAK (bulundu, düzeltildi): uzuv poz numaraları 1-4 iken enemy.gd'nin MİNOTAUR poz dalı (`_pose_override` 1-3) onları kendi kare aralıklarına çeviriyordu -> uzuv pozları 11-14, o dal sadece 1-9.
   (e) **SES:** `underground_sound.gd` (HER peer yerelde, başsızda sessiz): `tools/gen_underground_sounds.py` (numpy) ile sentezlenen `assets/audio/underground/` (rumble_1-3 5-9 sn'de bir + çok hafif yer sarsıntısı, growl_1-2 9-15 sn'de bir, emerge/burst/spit/hiss
   uzuv sesleri) + Horror paketinden "Gore And Larvae Loop" (16-26 sn'de bir, çok kısık). Sesleri DİNLEYEMEDİM (kullanıcı beğenmezse sayılar/dosyalar tek yerde).
   (f) **SANAT:** `tools/import_sandworm_sheets.py` (paket satır sırası aşağı/SAĞ/SOL/yukarı -> projenin aşağı/yukarı/sol/sağ düzeni; minotaur paketinden FARKLI) -> `assets/enemies/sandworm/` (uzuv ölçeği 2,4 = ~115 px, oyuncu 34 px) + asit damlası
   şeritleri; `empty.png` boss düğümünün saydam sprite'ı. Kullanılmayan paket sayfaları: hit, attack hitbox, 200% sürümler.
   **Benim seçimlerim (kullanıcı vermedi):** uzuv eşiği 2.000 (toplam hasar sabit; eşik sadece kaç uzvun gerektiğini belirler ~55), %35 geri dönüş, ömür/aralık/üst sınır/sıra sayıları, sert gövde 18 px, asit hızı 240, tükürük/savurma menzilleri, boss soğurması %90,
   uzuvların kendi canı yok-eşik. **Testler:** `test_underground_boss` (19: saf hesaplar, sprite/sahne sözleşmesi, boss statları + vurulamazlık + havuz toplamı 110.000, kademe kapısı + ölüm, savurma zamanlaması/130, asit 110 + kaçınma, hasar iletimi + fazla hasar,
   ödülsüzlük, geri dönüş + dokunulmazlık + silinme, ömür, istemci kurulumu, yönetmen yol kesme/dağınık sıra (madde 45)/üst sınır/kimse dışarıda değilken, pozlar, ağ yönlendirici, sert gövde bloğu gerçek Player ile), `test_minotaur_boss` + `test_elite_pool_and_bosses_off` güncellendi.
   **İKİ SÜREÇLİ GERÇEK DENETİM** `run_audit.ps1 -Mode underground -Secs 70` (+ `underground_audit.gd/_compare.py`): 70 sn'de 43 benzersiz uzuv doğdu, istemcide HEPSİ göründü (%100, 1102/1102 kayıt), uzuv konum farkı en çok 8,6 px, tür farkı 0, poz
   farkı 4/1102; boss havuzu host/istemci ortalama 1, en çok 15 farkla AYNI; asit damlaları iki tarafta (3/3); oyuncular tam 130 (savurma) ve 110 (asit) hasar aldı, duvar hücresine girmediler; 2 oyuncuda boss 75.000/90.000 (x1,5). İlk koşuda silahlar
   havuzu sadece ~900 azalttı (başlangıç silahı + yürüyen oyuncular): gerçek savaş süresi hesaplanamadı. STRES koşusu (`$env:MP_STRESS=1`, iki oyuncu da uzuvlara doğrudan hasar basar, 45. sn'de havuz yapay düşürülür): istemci hasarı host'a RPC ile gitti, havuz iki tarafta
   aynı eğriyle erdi (fark <= 900 = bir senkron aralığı), parçalanma/geri dönüş uzuv kayıtlarının %99,3'ünde iki tarafta aynı, BOSS HER İKİ TARAFTA ~0,25 sn farkla öldü ve tüm uzuvlar dağıldı (sonda yüzeyde 0/0). **Doğrulanmayan:** elle oynanış hissi (yol kesme/sıra adil mi, uzuv ömrü/eşik/üst sınır), gerçek build'le havuzun erime hızı (110.000 hasar; uzuv
   ömrü ~11 sn içinde yeterli DPS gerekir - ağır gelirse `LIFETIME_*`/`MAX_ACTIVE`/`LIMB_THRESHOLD`), sesler (dinlenmedi), 3-4 oyuncu, geç katılan oyuncuya uzuv yakalaması, telefon.

42. **Boss çok oyunculu senkron denetimi + RPC güvenliği (2026-10-09, Minotaur + Yeraltı Canavarı sonrası "senkronda eksik var mı" sorusu).** (a) **BULUNAN + DÜZELTİLEN:** `network_manager.gd`'de host'tan gelmesi gereken
   üç RPC'de gönderen kontrolü YOKTU: `broadcast_enemy_vfx` (sahte "death_state"/"worm_pose"/"minotaur_pose" ile başkasının yaratığını öldürme/bozma), `forward_damage_to_peer` + `forward_special_damage_to_peer` (herhangi bir
   peer başkasına istediği hasarı yazabiliyordu). Üçüne de `if not _from_host(): return` konuldu (tüm çağrıcılar host tarafı: `emit_ability_vfx`, `RemotePlayer.take_damage/take_special_damage`). KANIT: `run_audit.ps1 -Mode security` artık istemciden
   99999 sahte hasar + sahte death_state yolluyor; korumalar KAPALIYKEN host oyuncusu 99.849 hasar yedi (negatif kontrol, sonra geri yüklendi, md5 doğrulandı), AÇIKKEN hiçbir şey olmadı. DİKKAT: `network_manager.gd`'de hâlâ 83 kadar `any_peer` RPC'de `_from_host()`
   YOK - çoğu meşru istemci->host isteği (request_*) ya da herkesten herkese yayın, ama bazıları host-only olabilir (`grant_weapon_shards`, `sync_ally_heal`, `sync_evo_buff`, `receive_gold_gift`, `sync_*`...): bu turda dokunulmadı, ayrı bir tarama işi (liste: network_manager.gd'de
   `@rpc("any_peer")` + gövdesinde `_from_host()` olmayanlar). (b) **YAKALAMA:** `run_audit.ps1 -Mode bosscatchup` (+`boss_catchup_audit.gd/_compare.py`): iki boss + uzuvlar varken istemci düşüp yeniden katıldı; eşzamanlı anlık görüntüde bossların kimlik/statları (x1,5 dahil)/havuzu/kademesi
   ve uzuvların kümesi/türü/pozu/gömülme durumu iki tarafta AYNI (SONUÇ: TEMİZ). Küçük boşluk kapatıldı: hücumun ortasında katılan oyuncuya Minotaur pozu + ağ hızı tavanı gitmiyordu - `enemy.gd send_catchup_to_peer` (spawner yakalama döngüsünden çağrılır; uzuv kendi sürümünü tanımlar).
   (c) **HOST'UN KENDİ OYUNCUSU HEDEFKEN:** `MP_MINO_TARGET=host` ile Minotaur denetimi (yerel hasar + yerel `apply_boss_fling` yolu): tam 100 hasar, 105-233 px savrulma, kukla hatası istemci hedefliyle aynı (ort ~11 px hücumda). (d) **STRES:** `MP_STRESS=1` ile Yeraltı Canavarı (istemci hasarı host'a RPC, havuz
   iki tarafta aynı eğri, boss iki tarafta ~0,25 sn farkla öldü, uzuvlar dağıldı). **HÂLÂ DOĞRULANMAYAN:** 3-4 GERÇEK süreç (run_audit.ps1 ikiden fazlasını başlatmıyor; oyuncu sayısı ölçekleri birim testle sınandı), host devri sırasında YAŞAYAN boss (kural: yeni host bossu tam canla yeniden doğurur, uzuvlar sıfırlanır - denenmedi),
   boss kill kredisi/ödül dağılımı (son vuruş istemcideyse `notify_kill_passive`), seslerin duyulabilirliği, hücumun ortasında yakalama (Minotaur poz yakalaması yazıldı ama o ana denk getirilip sınanmadı), boss hasarı host'taki UZAK OYUNCU KUKLASININ konumuna göre hesaplanır (diğer yaratık saldırılarıyla aynı: gecikmeli oyuncu host'un bildiği yerde vurulur).

43. **Boss ve müttefik can/kalkan SAYILARI (2026-10-09).** Kullanıcı: "bossların can ve kalkan sayısı görünmüyor, dostların can ve kalkan sayısı grup sekmesindeki barlarında görünmüyor". (a) Üst boss barı (`boss_bar_art.gd top_plaque`, `boss_bar_top.gd`): plaket
   38 -> 44 sanat pikseli, kalkan çubuğu 9, can çubuğu 11 px; ikisinin İÇİNDE "şimdiki / en çok" (binlik noktalı: `fmt_int`/`bar_text`, krem yazı + koyu anahat, m5x7). Kalkansız bossta kalkan yazısı yok. Bar imzası sayıyı içerir (oran 0,001'den az değişse de
   yeniden çizilir). `top_plaque`'a opsiyonel `hp_text`/`sh_text` (boşsa sayısız çizer). Boss havuzu 100.000+ olduğundan sayı gerekliydi (Yeraltı Canavarı 165.000). (b) Grup paneli (`party_panel.gd`): her müttefikin can ve kalkan çubuğunun içinde HUD'daki kendi sayısıyla AYNI "%d/%d". İKİ TUR: ilk sürüm 24 punto Label + 16/14 px çubuktu - kullanıcı "sayılar aşağıda kalmış, zor okunuyor, sığmıyor" dedi
   (Label satır yüksekliğine göre ortalanıp ~2-3 px aşağı oturuyordu, 1,5 kat piksel yazı bulanıktı). İkinci sürüm: `scripts/bar_value_label.gd` (Control, kendi `_draw`): yazı TAM 2x (32 punto, rakam 14 px) ve tam piksele yuvarlı, taban çizgisi
   çubuk ortası + rakam yüksekliği/2 (22 px can çubuğunda üst/alt 4'er px, 18 px kalkanda 2'şer px); sığmazsa 24 -> 16'ya düşer (panelde çubuk 130 px, PAD_X 8: 9 karaktere kadar 2x, "9999/10000" 1,5x, daha uzunu 1x). Çubuklar 10/6 -> 22/18 px (satır ~30 px uzadı).
   Kalkansız müttefikte kalkan çubuğu yerinde kalır, yazısı boş (satır zıplamaz). `PartyRow.health_label/shield_label` (.text). Test: `test_hp_numbers_on_bars` (6) +
   `test_boss_bar_top` (16) geçti; gerçek renderer görüntüsüyle 1920x1080'de boss barı ve 4 müttefik satırı (büyük sayılı dahil) doğrulandı. Telefon yerleşimi (ölçek 2) elle izlenmedi.
44. **Silah satışında parçacık iadesi (2026-10-09).** Kullanıcı: "silahı satınca harcanan silah parçacığının %70ini geri vermiyor". Silah kopyasının defteri
   artık iki alanlı: `"spent"` (altın) ve `"shards_spent"` (parçacık; anahtar yoksa 0 - başlangıç silahı/eski kayıt/sandıktan gelen silah iade etmez). Parçacık deftere
   `weapon_shop_logic.gd buy_weapon` (10) ve `buy_wupgrade` (efsun geliştirmesi 5, final 10) içinde `EnchantDefs.record_shards_spent` ile yazılır (rollback'te silinir).
   İade oranı TEK yerde: `EnchantDefs.SELL_REFUND_RATIO` (0,7) + `sell_refund_gold(entry)` / `sell_refund_shards(entry)`; iki satış yolu da (envanter `inventory_panel.gd
   _do_sell_weapon_equip`, geliştirmeler sekmesi `shop_panel.gd _on_sell_weapon`) altını ve parçacığı ikisinden de alır (`GameManager.add_weapon_shards`). Yeni bir silah
   SATIŞ yolu yazarsan aynı iki işlevi çağır. Arayüz: envanter ipucu "+N Altın, +M Silah Parçacığı", onay penceresi/telefon şeridi ek satır, geliştirmeler sekmesi SAT
   düğmesinin ipucu; envanter yuva imzası defteri de içerir (geliştirme alınca ipucu tazelenir). BİLİNÇLİ: geliştirmelere harcanan parçacık da deftere girer ("harcanan
   parçacığın %70'i" - kullanıcı sözünün benim yorumum) ama efsun geliştirmelerinin ALTINI hâlâ `spent`'e yazılmaz (iade edilmez, madde 34'teki gibi); parçacık
   iadesini sadece silahın kendi 10'una indirmek istenirse `buy_wupgrade`'deki `record_shards_spent` satırı silinir. Testler: `test_weapon_shop` (23; mutasyonla
   envanter yolu kırıldı). Gerçek oyunda elle satılarak izlenmedi.
45. **Yaratık derinliği: ağaç/ev arkasında örtülme, kendi aralarında sıra kapanışı, kare başı çizim sırası koruması (2026-10-09).** Kullanıcı: "yaratıkların Y eksenleri düzgün çalışmıyor, ağaçların ve evlerin
   üstünde yürüyorlar; yeraltı canavarı (uzuvlar) yan yana dizilince birbirinin üzerinde görünüyor, eksenler yanlış; ayrıca önümü keserken dip dibe dizilmesin" + sonra "üst üste binmiyor ama solucanlar bazen glitchlenip
   diğerinin üstünde görünüyor". ÜÇ AYRI kök neden (hepsi gerçek renderer ekran görüntüsüyle önce/sonra doğrulandı): (a) **AĞAÇ/EV ÖRTÜSÜ**: madde 25'in ön kopya katmanları SADECE oyuncuları örtüyordu, yaratıklar haritanın üstünde z 0'da çiziliyordu. Artık
   `depth_occluders.gd update_creatures` (3. karede bir, TEK karelerde) görüntüdeki, bir nesne kümesine değen en çok 32 yaratığın gövde dikdörtgenini (ayak x, ayak y, yarım genişlik, boy) kopya katmanların `yaratiklar[32]` uniform'una yazar
   (`derinlik_on_katman.gdshader` VE `sallanan ağaç.gdshader` - ikisinde AYNI `orter()` kuralı); kural: piksel kökü varlığın ayağından aşağıdaysa kopya o piksele çizilir, pikseli içeren bir varlık nesnenin ÖNÜNDEYSE (ayağı köke eşit/aşağıda)
   hep görünür kalır (oyuncu/yaratık "önde kazanır"). Ucuz ön eleme: kaba 32 px ızgara (`_coarse` en büyük kök, `_near` 3 hücre genişletilmiş): açık arazideki yaratık tek sözlük sorgusuyla elenir; yaratık gövdesi sprite karesinin OPAK alanından bir kez ölçülür
   (`creature_body`, meta `_depth_body`, x1,15 pay); oyuncu müttefikleri (köpek) de dahil. **Kopya katmanlar artık z_index 3** (oyuncu 1, oyuncunun önüne alınan yaratık 2): önündeki yaratık da ağacın arkasındaysa örtülsün. Yeni bir "nesne" katmanı eklersen madde 25'teki
   gibi OBJECT_LAYERS/BUILDING_GROUPS'a yaz, yaratık örtüsü ona OTOMATİK uygulanır. Sadece `setup()` (dış harita) yaratık örtüsünü açar; iç mekan (`setup_interior`) kapalı (yaratık içeri girmez). Ağaç sallanma shader'ındaki kopya yolu aynı uniform'ları taşımalı (kopyalanırken
   `_copy_material` hepsini aktarır). (b) **Z KAPANIŞI** (`creature_depth.gd close_over`): oyuncunun önündeki yaratık z 2'ye alınınca, onun ÖNÜNDEKİ (ayağı daha aşağıda) ve örtüşen komşusu oyuncuyla örtüşmediği için z 0'da kalıyordu -> arkadaki yaratık öndekinin üstüne
   çiziliyordu (z 2 > z 0). Artık yükselen küme ayak sırasında aşağıya doğru KAPALI (yükselen birinin önündeki örtüşebilen her yaratık da yükselir; hep doğrudur çünkü o da oyuncunun önünde). Tarama yarıçapı 130 + 240 kapanış payı; konumu karakterin ayağından 130 px'ten fazla
   yukarıdaki yaratık hiç hesaplanmaz (ABOVE_SKIP), gövde ölçüsü düğümde önbellekli (`_depth_extent`). (c) **KARE BAŞI ÇİZİM SIRASI BOZULMASI** (kullanıcının "glitch"i): yeni yolda yaratık çizim sırası düğüm taşınmadan `canvas_item_set_draw_index` ile verilir (C++ `draw_order`, 2 karede bir). Godot ise
   Main'in BİR ÇOCUĞU AĞAÇTAN ÇIKINCA (ölen yaratık, biten FX/küre/hasar yazısı - saniyede onlarca kez) ondan sonraki TÜM kardeşlerin çizim indeksini ağaç sırasına geri sarıyor (NOTIFICATION_MOVED_IN_PARENT); düzeltme en erken sonraki güncellemede
   geldiği için o kare(ler)de arkadaki yaratık öndekinin üstündeydi (ölçüldü: çocuk silinen karede ters sıra). `main.gd _install_draw_order_guard`: `child_exiting_tree`/`child_order_changed` bayrak kaldırır, `RenderingServer.frame_pre_draw` (süreç + silme kuyruğu bitti, çizim öncesi)
   sırayı hemen yeniden uygular (~0,1 ms, 150 yaratıkta). Yeni bir "Main çocuğunun sırasını bozan" kod yazarsan (move_child) aynı bayrağı zaten `child_order_changed` kaldırır. Eski GDScript yolu (move_child) bu sorundan etkilenmez. Ölçüm (150 yaratık, yoğun orman, EN KÖTÜ durum): yaratık
   örtüsü ~0,8 ms + creature_depth ~0,7 ms güncelleme başına, ikisi de 2 karede bir ve farklı karelerde (ortalama ~0,75 ms/kare); açık arazide çok daha az. Testler: `test_depth_occluders` (+3: kaba ızgara girdileri/uzak elenir, 32 üst sınırı en yakınları tutar, GERÇEK haritada ağaç arkası), `test_creature_depth` (+2: kapanış, saf kural),
   `test_underground_boss` (dağınık sıra). Gerçek pencerede doğrulandı: ağaç arkasındaki ork örtülüyor (önce/sonra), dağınık sıra ayrık, silme karesindeki ters sıra bitti. Doğrulanmayan: telefon, iki oyunculu uzak kukla örtüsü (aynı yoldan geçer), ev/maden/düşman üssü arkasında gerçek ekran
   (aynı shader yolu, ağaçla aynı kural), kapanışta yaratıkların grup sınırında (370 px) kısa z titremesi ihtimali.
46. **Yaratıklar/oyuncular %15, bosslar %20 küçüldü (2026-10-09).** Kullanıcı: "tüm yaratıkları ve oyuncuları %15 küçült, bossları %20 küçült" + "herşeyle beraber küçült ama silahlar kalkan v.b."
   (SON CÜMLE BELİRSİZDİ: "hariç" olarak yorumlandı - silahlar ve kalkan baloncuğu KÜÇÜLMEDİ; yanlışsa `EntityScale.ATTACHED_SIZE`'ı `SIZE`'a eşitle ve silah slotlarını/ikon boyunu BODY_REL ile çarp). `scripts/entity_scale.gd`: `LEGACY_SIZE` 0,95 (eski boyut), `BODY_REL` 0,85,
   `SIZE = LEGACY_SIZE x BODY_REL` = 0,8075 (yaratıklar, oyuncular, uzak kukla, evcil hayvanlar, görev kopyası - hepsi zaten SIZE'ı kullanıyordu); bosslar eski boyutun TOPLAM %80'i (`BOSS_REL` 0,80; yaratıkların %15'inin ÜSTÜNE binmez):
   `enemy.gd apply_boss_stats` `_scale_body(scale_mult x BOSS_EXTRA)` (BOSS_EXTRA = 0,80 / 0,85) ve Yeraltı Canavarı UZUVLARI (bossun görünen gövdesi) `worm_limb.gd _size_extra()` ile aynı ek çarpanı alır (enemy.gd `_size_extra()` kancası, normalde 1). Elitler (x1,5) boss
   DEĞİL, sadece SIZE alır. Gövde boyutuna bağlı ELLE YAZILMIŞ sabitler yeni boyuta uyarlandı (hepsi `EntityScale.BODY_REL` ile; yeni bir "karakter boyuna bağlı" sabit eklersen 0,8075'e göre ölç ya da BODY_REL ile çarp): `overhead_bar.gd CHARACTER_Y_OFFSET` -76 -> -68,
   isim etiketi y -128 -> -120 (`remote_player_name.gd`), `depth_occluders.gd` + `grass_sway.gd` FEET_OFFSET/BODY_HALF_WIDTH/BODY_HEIGHT (15/11/34 x BODY_REL), `ground_shadow.gd apply_to` (DEFS `ground_shadow`/`ground_shadow_y` verisi ESKİ boyutun birimindedir, çalışma anında BODY_REL ile çarpılır),
   `hadime_math.gd CHAR_TEXEL` (= 2,2368375 x SIZE). BİLEREK DEĞİŞMEDİ: FX piksel ızgarası `TEXEL` 1,212 (pixel_draw/vampir_math/hadime_math: efektler karaktere göre küçülmez), silah slotları/ikon boyu (WeaponOrbitMath, kendi ICON_SIZE_MULT'ü), kalkan baloncuğu
   (`ATTACHED_SIZE` = 0,95), terrain_collision ayak payı (15 px), oyun mekaniği sayıları (menzil, hasar alanları, sert gövde 18 px, Minotaur şerit genişliği), kamera. Testler: `test_entity_scale` (11), `test_character_size_and_shadow` (9; veri düzeyi kontroller `LEGACY_SIZE` ile), `test_minotaur_boss` (23). Gerçek pencerede doğrulandı:
   oyuncu animasyon ölçeği 1,806, ork 1,183, Minotaur 2,067 (= eski 2,584'ün %80'i), çubuk/isim/kalkan yerleşimi tutarlı. Doğrulanmayan: telefon, tüm 15 karakter tek tek (can çubuğu şapka boşluğu en uzun karakterlere göre ölçüldü, elle bakılmadı), uzuv/boss çarpışma hissi (çarpışma çemberleri de küçüldü).

47. **Orman dokusu: duvar kenarı/harita kenarı ağaç + çalı + çiçek + mantar (2026-10-09, SADECE Harita.tmx değişti - oyun sahnesi HENÜZ bake EDİLMEDİ).** Kullanıcı: "haritanın belli
   yerlerine, özellikle duvar kenarlarına zeminle uyumlu ağaç/çalı/bitki/çiçek, daha doğal gizemli orman hissi" + "yapay zekayla görsel ÜRETME, mevcut harita dosyalarını kullan". YENİ GÖRSEL YOK:
   sadece `Harita.tmx`in zaten bağlı olduğu tileset'ler (Objects, sade ağaç ve taş, sadece_agac, Flowers) kullanıldı, 7 katmanın CSV'si DEĞİŞTİ (hepsi sadece EKLEME, mevcut hücre dokunulmadı):
   `Shader Eklenecek/Ağaç 0/1/2` (+322 ağaç, neredeyse hepsi Ağaç 0'da: çarpışma + sallanma + derinlik alır), `Çalılar1` (çalı), `Çalılar` (kamış, kıyıya), `Animasyonsuz çalılar` (mantar/kütük/kaya, çarpışmasız), `Çiçekler 1`.
   YEDEK: `harita/yedek/Harita_YEDEK_2026-10-09_agac-oncesi.tmx.bak` (+ eski `scenes/harita_baked.tscn` kopyası `harita_baked_YEDEK_...tscn.bak`; .bak uzantısı Godot'a import edilmesin diye). Geri almak: .bak'ı `harita/Harita.tmx` üzerine kopyala.
   YERLEŞİM KURALLARI (sabit tohumlu üretici; kurallar oyunun kendi koduna uyar): ağaç gövdesi (alt 9 px bandı, `terrain_collision.gd` kuralıyla hesaplandı) duvar/su/ev/kapı çevresi/köprü/maden/düşman üssü/yol (2 hücre) üstüne
   GELMEZ; ağaç yalnız çimde, solgun ağaç yalnız çıplak toprak bölgelerinde (alt-sol + düşman üssü yanı); yerel+genel bağlantı denetimi (2 yaricap + oyuncu 3x3 ajan): hiçbir geçit/cep kapanmadı (verify: kopan 0). Katman sırası: aynı hücrede
   iki ağaç karosu varsa güney olan üst katmanda; aynı katmanda atlas-komşu iki ağaç YAPIŞTIRILMAZ (tree_sway.gd ayırma kuralı - doğrulandı: 400 ağaç grubu = 78 eski + 322 yeni, birleşme yok).
   V2 KURALLARI (kullanıcı geri bildirimi aynı gün: "bazı ağaç ve çalılar üst üste binmiş, bazıları tepe kenarlarındaki vadi geçişlerini kapatıyor, kumsalda bitki olmamalıydı"): (1) SIKI ÇAKIŞMA YASAĞI - yeni bir karo, ağaç/çalı/nesne/çiçek katmanlarından HERHANGİ birinde dolu bir hücreyi paylaşmaz (`occ`; verify: 0); (2) KUMSAL = sudan <=8 hücredeki çıplak toprak + Water_coasts kıyı karoları (+1): hiçbir yeni karo konmaz, kamış sadece çimde; (3) DAR VADİ KORUMASI `MX` (5 hücre çevresindeki en büyük boş disk yarıçapı): ağaç gövdesi MX>=5,2, ağaç tacı MX>=4,2 (engel olmayan hücrede), çalı/nesne/kamış MX>=4,6, çiçek MX>=3; ağaç tacı yol/toprak hücresinin üstüne de girmez. Eski v1 (432 ağaç) bunları sağlamıyordu; yalnız bağlantı denetimi (kopan hücre) vadinin GÖRSEL olarak tıkanmasını yakalamıyordu. `verify.py` artık üçünü de sayar.
   KAMIŞ YOK (aynı gün, kullanıcı resimle: "şu ikisi (Objects kamış/ot sprite'ları 83-94) haritamda olmasın, yerine oyunda mevcut animasyonlu çalılar (Çalılar, Çalılar1) yer yer konsun"): kamış yerleştirmesi rastgele akışı bozulmasın diye hâlâ çalışır ama `swap_reeds_for_tufts()` sonra o karoları SİLER ve ayrı rastgele kaynakla (SEED+7) haritanın KENDİ katmanlarındaki mevcut filiz öbeklerini (exterior.tsx; `existing_tufts`) ilgili katmana koyar: kıyıya/yer yer açık çayıra 45 öbek `Çalılar`a, 18 öbek `Çalılar1`e (ayar `tuft_reed_max`/`tuft_bush_max`/`tuft_shore_p`). Başka hiçbir katman değişmedi (v2->v3 fark sadece bu ikisi). `Çalılar` katmanında Objects.tsx karosu KALMADI - yeni bir kamış/Objects bitkisi koyarsan kullanıcı istemedi.
   ÇİÇEK AZALTMA (aynı gün, "çiçekleri biraz azaltır mısın, çok fazla"): `thin_flowers()` sadece BENİM eklediğim çiçek öbeklerini (1151 -> 558 karo; özgün 97 karoya dokunulmaz) en az `flower_gap` 2 hücre aralıkla, `flower_keep` 0,8 olasılıkla tutarak seyreltir (ayrı rastgele kaynak SEED+11; yalnız `Çiçekler 1` değişti). Daha az/çok çiçek = bu iki ayar. Uygulama öncesi kullanıcı dosyasının kopyası `harita/yedek/Harita_oncesi_cicek-azaltma.tmx.bak`.
   KULLANICI TILED'DA KAYDEDİYOR: 2026-10-09'da aynı oturumda Harita.tmx'i araya Tiled'dan iki kez kaydetti (14:21, 14:37; yalnız katman özellikleri: `Su ayrıntılar 2` opaklığı kalktı, `Su ayrıntılar 3` görünür oldu, hücre farkı YOK) - bu yüzden son düzenleme kullanıcının dosyası üzerine, SADECE iki katmanın CSV'si değiştirilerek yapıldı (md5 kapısı betik içinde; kullanıcı kaydının kopyası `harita/yedek/Harita_KULLANICI_14-37_kayit.tmx.bak`). Üreticiyi yedekten yeniden çalıştırıp çıktıyı doğrudan Harita.tmx üzerine KOPYALAMA: önce kullanıcının güncel dosyasıyla farkına bak.
   TUZAKLAR: (a) bake edince `Su/Su` -13 hücre gibi, son bake'ten beri Tiled'da YAPILMIŞ ama bake edilmemiş değişiklikler de oyuna girer (Ağaç katmanları da +20/katman) - bu benim değişikliğim değil; (b) `bake_harita.gd` sonunda "gölgeleri yeniden pişir" der:
   yeni ağaçlar için `tools/bake_map_shadows.gd` (GERÇEK pencere) + `.py` + `--headless --import` ve minimap (`bake_minimap.gd`) de yeniden çalıştırılmalı, yoksa ağaçların zemin gölgesi/minimap eski kalır; (c) çalı katmanlarına hücre eklemek seyyar satıcının
   olası doğuş noktalarını artırır (`traveling_merchant.gd BUSH_LAYER_PATHS`); (d) ÜRETİCİ depoda: `tools/forest_decor/` (kullanım + kullanılan ayar `gen_forest.py` başında; kaynak TMX `HARITA_TMX` ortam değişkeniyle, agac-öncesi yedekten çalıştırılır; aynı girdi birebir aynı TMX'i üretir - md5 doğrulandı). Yoğunluk değişikliği = yedeği Harita.tmx üzerine kopyala, ayarı değiştirip yeniden üret (üstüne tekrar çalıştırma YIĞAR).
   DURUM: `scenes/harita_baked_new.tscn` ESKİ (v1 TMX'ten pişirilmiş; ağaç/kamış değişti) - terfi öncesi `tools/bake_harita.gd` yeniden çalıştırılmalı (v1 bake'i 43 düğüm, 1 TileSet, 0 yükleme hatası verdi); canlı `harita_baked.tscn`in yerine GEÇİRİLMEDİ (uid geri yazma + gölge/minimap pişirme kullanıcı onayı bekliyor). Oyunda oynanarak izlenmedi.

48. **Vadi köprüsü: altından geçen örtülür, üstünden geçen üstte kalır + sağ uç açıldı (2026-10-09).** Kullanıcı (ekran görüntüsüyle, x 43-65 y 120-121 köprü): "buranın altından geçen insanların üstünde köprü görünmeli. ayrıca soldaki dağdan insanlar bu köprüden geçebilmeli".
   (a) DERİNLİK: `depth_occluders.gd` `BRIDGE_LAYERS` (Köprü/Köprü alt + üst, bina gibi TEK kök = güvertenin alt kenarı) için ön kopya kurar (mod "bridge", z 3) AMA kopya yalnız ZEMİN KATINDAKİ karakterlere gider: iki kat aynı ekran konumunda üst üste bindiği için karakterin köprü dikdörtgenine HANGİ KENARDAN girdiğine bakılır (`scripts/bridge_deck.gd` durum makinesi, testli): uzun eksenin ucundan (sol/sağ yamaç) = GÜVERTE (kopyaya verilmez, normal z 1'de köprünün üstünde), yandan (vadi zemini, kuzey/güney) = ALTINDA (kopya onu örter; kural bina/ağaçla aynı: kök ayağın aşağısındaysa örter), içeride belirmek (ışınlanma/doğuş) = zemin katı, dikdörtgenden çıkınca sıfırlanır. Yaratıklar köprü kopyasına dahil DEĞİL (eskisi gibi hep köprünün üstünde; `_build_coarse` köprüyü atlar), köprüden uzaktaki karakter listeye girmez (liste sabit kalınca shader parametresi her karede yazılmaz). Nehir üstündeki köprü de aynı yoldan (altı su, kimse altından geçemez). Yeni bir "altından geçilen" köprü/kemer eklersen sadece `BRIDGE_LAYERS`'a katman yolunu yaz.
   (b) GEÇİŞ: köprünün sağ ucundaki (x 68-69, y 110-126) görünmez 2 hücrelik orman dolgusu (tile 212, tam opak çim rengi; çarpışma yalnız `Orman parçaları/Orman parçaları` katmanından gelir) karşı yamaca çıkışı kapatıyordu; köprü hizasındaki 4 satır (y 119-122, 8 hücre) HEM `Harita.tmx` katmanından HEM canlı `scenes/harita_baked.tscn`'den (tile_map_data base64: başlık 2 bayt + hücre başına 12 bayt, 8 girdi silindi) silindi - TMX kaynağı doğru, sahne yaması bir sonraki bake'e kadar aynısını sağlar. Oyunun kendi sorgusuyla (`is_position_blocked_by_walls`) güverte + sağ uç + yamaç serbest. Sol uç zaten serbestti (yamak kenarı süsü çarpışmasız). Bilinen: geçidin doğusunda (x 72-73) iki kaya hücresi arasında diyagonal dar boğaz var (oyuncu çemberi 11 px için >=5 px pay; hücre düzeyinde "artı" ajan sığmaz, 4-bağlantılı yaratık yol bulma geçer).
   Testler: `test_bridge_deck` (8: dikdörtgen bileşenleri, giriş kenarı, durum makinesi, bilinmeyen köken, kurulum + yaratık hariç + tek kök, güverte/alt süzgeci, uzak karakter, GERÇEK haritada geçit açık); `test_depth_occluders`/`test_creature_depth`/`test_map_terrain_collision`/`test_terrain_collision_objects` geçti; GERÇEK haritada kurulum (2 köprü, kökler 530 ve 1952) + sahte oyuncularla durum doğrulandı. **Doğrulanmadı:** shader'ın köprüyü gerçekten oyuncunun üstüne çizmesi (mevcut bina/ağaç shader'ı aynen, gerçek pencerede bakılmadı), iki kişiyle uzak kukla geçişi, hızlı atılışla (dash) uçtan girişin tespiti.

49. **Saklanma çalısı PROTOTİPLERİ (2026-10-09, sadece görsel; mekanik YOK).** Kullanıcı: "haritanın belli bölgelerine içine girip saklanabileceğim çalılar eklemek istiyorum ama uygun bir çalı assetim yok, 4 prototip hazırlar mısın" (bu kez AÇIKÇA çizim istendi; madde 47'deki "mevcut asset kullan" kuralı haritaya eklenen süslemeler içindi).
   `tools/hide_bush_proto/gen_hide_bush_proto.py` (deterministik, KODLA çizim; renkler haritanın kendi çalı/çiçek/kök sprite'larından ölçüldü; 1 sanat pikseli = 1 dünya pikseli, kutucuk hizalı): A Sık Çalı (48x48, açık zeytin), B Dikenli Çalı (48x48, koyu deniz-yeşili, ışınsal sivri uç), C Çiçekli Çalı (48x48, mavi/mor/beyaz çiçek kümeleri), D Oyuklu Çalı (64x48, alt ortada karanlık giriş oyuğu + küçük kökler). Çıktı `tools/hide_bush_proto/out/` (`hide_bush_a..d.png` şeffaf, `karsilastirma.png` gerçek harita çimeni + gerçek oyuncu ölçeğinde boş/yanında/içinde, `yakin.png`); `out/` .gdignore + .gitignore'lu (Godot import etmez, git'e girmez, betikle yeniden üretilir).
   Ölçü bilgisi: oyuncu karesi 48 px, görünen karakter 16x38 sanat pikseli; oyunda 1 sanat pikseli ~0,54 dünya pikseli (sprite ölçeği 1,0845 x kök 0,5) -> oyuncu yaklaşık 9x21 dünya px, haritadaki en büyük çalı ~38x40; prototipler ~46x38 (D 60x40) = oyuncunun ~4 katı genişlik. Sprite tabanındaki yarı saydam gölge çalı sprite'larının kendi diliyle çizildi; harita gölgeleri (`bake_map_shadows`, 'bush' kategorisi) de ayrıca gölge ekler - seçilince biri azaltılmalı.
   **2. TUR (aynı gün, kullanıcı: "çalılar hoş fakat ben league of legends tarzı çalıları kastetmiştim, aralarında hafif boşluklar olan"):** tek büyük çalı DEĞİL, bir alana yayılmış öbeklerden (tutam) oluşan çalılık. `tools/hide_bush_proto/gen_brush_proto.py`: A Uzun Ot (haritadaki filizlerin uzun/sık hâli), B Eğrelti (koyu, yan yaprakçıklı), C Gizemli Ot (koyu ot, uçlar mor/mavi), D Geniş Yapraklı (kenarı sadece gölge yanında). Dil: konturSUZ 1-2 px eğri yaprak (Çalılar filizleri gibi), arka sıra 1 ton koyu, tutamlar arası hafif boşlukta gölgeli zemin, tabanda koyu çekirdek; jitter'lı ızgara + atlama + 2 küçük boşluk. `Brush` sınıfı tutamları taban y'ye göre tutar: içerideki oyuncu için arka tutamlar -> oyuncu (yarı saydam) -> ön tutamlar (oyunda da bu sırayla örtü kurulabilir). Çıktı `out/brush_*.png` (karşılaştırma, şekiller = şerit + L, yakın plan). Uygulama fikri: tutamlar Tiled'da boyanabilen parçalar ya da bölge -> çalışma anında üretim; seçilmedi.
   **3. TUR (aynı gün, "3 ve 1'i karıştırır mısın fakat 3 çok koyu renkli zeminle uyumsuz oluyor biraz"):** `tuft_mix` + `MYSTIC_LIGHT` (C'nin koyu deniz-yeşili yerine çime yakın açık yeşil, uçlar aynı mor/mavi): K1 Dengeli (öbeklerin %50'si gizemli), K2 Çoğunlukla Ot (%28, seyrek uç), K3 İç İçe (her öbekte iki tür yaprak); ortalama parlaklık ~101-104 (çim ~129: zeminden biraz koyu, örtü olarak okunur). Çıktı `out/brush_karisik_*.png`, `brush_k1..k3.png`. Kullanıcının seçimi bekleniyor.
   DURUM: kullanıcı seçecek (A/B/C/D, ya da boyut/renk isteği). Seçilince yapılacaklar: tileset (.png + .tsx, `Çalılar1` ya da yeni bir `Saklanma çalıları` katmanı), `GameManager.register_blocking_panel` DEĞİL ama oyuncu içine girince kapı/çalı örtüsü (depth_occluders ön kopyası ya da alfa), saklanma kuralı (yaratık hedef seçimi `enemy_world`/`enemy_query` süzgeci, çok oyunculu senkron: oyuncu durumu `report_*` ile herkese), uzak kukla görünümü. Hiçbiri başlamadı.

50. **Saklanma çalılığı Harita.tmx'te (2026-10-09; oyun sahnesi HENÜZ bake EDİLMEDİ, görünmezlik mekaniği YOK).** Kullanıcı (K1 stilini görünce): "bu çok güzel. bunun haritada yer yer bazı köşelerde toplu bir biçimde olmasını istiyorum, köşelere uygun ... oyuncuların ara sıra saklanabileceği bir yer. harita.tmx'e ekle, sonrasında bakeleyip içine girince görünmez olma özelliği üzerinde çalışırız".
   `tools/hide_bush_proto/place_brush.py`: duvar (`Orman parçaları/Orman parçaları`) İÇ KÖŞELERİ (iki kol, en az biri GÖRÜNÜR kaya - tile 212 düz çim dolgusu görünmez sayılır) + KOYLAR (görünür kaya hücreyi >200 derece sarıyor) bulunur; su/kumsal/yol/ev+kapı/köprü/maden/üs/dar vadi (MX<4.6) ve haritanın ÖZGÜN nesneleri elenir; 24 hücre aralıkla 10 yer seçilir (4 köşe + 6 koy); her yere açık yöne doğru duvara paralel elips K1 çalılığı (`gen_brush_proto.py` Brush, duvara 3 px'ten yakın tutam yok, tırtıklı kenar) çizilir ve 16 px karolara bölünür. Yeni tileset `harita/saklanma_calilik.png` + `.tsx` (firstgid 34768, 838 karo, her çalılık benzersiz karolar - Tiled'da yeniden şekillendirilecekse betik yeniden çalıştırılır; kopyala/sil serbest), yeni katman `Shader Eklenecek/Saklanma Çalılığı` (id 114, `Animasyonsuz çalılar` ile `Ağaç 0` arasında, 841 hücre, çarpışmasız). Çalılığın kapladığı yerdeki BENİM orman süslerim (madde 47) bütün damga olarak kaldırıldı (14 ağaç, 7 çalı, 9 nesne, 8 çiçek, 1 filiz); özgün nesneye dokunulmadı. Saklanma alanları (her çalılığın zemin maskesi hücreleri + px kutusu) `tools/hide_bush_proto/out/saklanma_alanlari.json` (out/ git'te yok; betikle yeniden üretilir).
   **2. YERLEŞİM (aynı gün, "çok az koymuşsun, hepsi çok büyük ve geniş, bazıları küçük olsun; vadi kenarlarındaki yol geçişlerini tamamen kapatmasınlar"):** 19 çalılık (10 küçük / 7 orta / 2 büyük; `SIZES` + `SIZE_WEIGHTS`, aralık `MIN_GAP` 15), her biri YOL TESTİNDEN geçer (`lane_ok`: çalılık zemini engel sayılınca pencere kenarları arasında 3 hücrelik şerit hâlâ bağlı mı + 25 hücreden büyük cep yok + DOLAMBAÇ yok: iki nokta arası en kısa yol 6 hücreden VE %25'ten fazla uzamaz; engeller = duvar, su, ev, maden, üs, AĞAÇ GÖVDELERİ, önceki çalılıklar ve YAMAÇ KENARI ÇİZGİLERİ (`Orman parçaları 2/3/4/-1`, kaya duvara bitişik olmayanlar: oyunda çarpışmasız ama vadi geçişlerini görsel olarak bunlar çiziyor)); geçemezse bir küçük boy denenir, yine olmazsa atlanır (bu koşuda 10 deneme). Çalılık yamaç kenarı çizgisinin üstüne taşmaz. TUZAK (bulundu, düzeltildi): 3x3 boşluk hesabında pencere dışını dolu saymak kenar hücrelerini hep kapalı yapıp testi BOŞA çıkarıyordu - sentetik koridor testiyle (tamamen kapatan/2 şerit bırakan reddedilir, 3+ şerit bırakan geçer) doğrulandı. Kaynak artık çalılık-öncesi yedek (`SRC`), uygulama canlı dosyanın md5 kapısıyla. Sonuç: 771 hücre, 768 karo (gid 34768-35535); kendi süslerimden 12 ağaç, 5 çalı, 1 nesne, 13 çiçek kaldırıldı. Önceki 10'lu sürüm `harita/yedek/Harita_calilik_ilk-surum_10adet.tmx.bak`.
   **3. DÜZELTME (aynı gün, "7-6-16 numaralı çalılıklar geçiş yollarını kapatıyor"):** üçü de iki kaya arasındaki 2 hücrelik rampalara/boğazlara oturmuştu. KÖK NEDEN: (1) koy algılayıcı iki yanı duvar olan geçidi de koy sanıyordu -> artık 40 dereceden büyük İKİ açıklık varsa geçit sayılır, aday olmaz; (2) yol testi 3x3 düzeyindeydi, 3 hücreden dar geçitler zaten "kapalı" göründüğü için kapanmaları fark edilmiyordu -> `lane_ok` artık 1 hücrelik yürüme düzeyinde de bakar (çalılık + 1 hücre payı engel sayılınca bağlantı ve dolambaç). Yeni test 6 çalılığı yakaladı (söylenen 6/7/16 + aynı durumdaki 5/8/15: geçit girişi, köprü yaklaşımı, yamaç boşluğu); `place_brush.py --replace 5,6,7,8,15,16` (diğerlerine dokunmaz; atlası son katmandan yeniden kurar; `CALILIK_GAP=12`) ile kaldırılıp yerlerine 5 yeni çalılık kondu -> toplam 18 (9 küçük / 8 orta / 1 büyük), 18'in hepsi sıkı testten geçiyor (her biri diğerleri de engelken). 739 karo (gid 34768-35506), 741 hücre. Yedek: `harita/yedek/Harita_calilik_19adet.tmx.bak` (+ png).
   **BAKE EDİLDİ (2026-10-09, kullanıcı isteği "haritayı Harita.tmx'ten yeniden bakele, shader/görsel eklentileri koru"):** madde 47 (orman dokusu) + 48 (köprü geçidi) + 50 (çalılık) HEPSİ canlı `scenes/harita_baked.tscn`e girdi (45 düğüm, 1 TileSet, orman katmanı 5510 hücre = TMX, 13 materyal korundu, shader parametre farkı sadece runtime'da yazılan 5 `= null` uniform, yeni `Saklanma Çalılığı` katmanı 741 hücre); uid'ler geri yazıldı (`harita_baked_new.tscn` silindi), yeni PNG import edildi, gölge (`harita_golgeleri.png`) + minimap yeniden pişirildi (çalılık katmanı gölge kategorilerine BİLEREK eklenmedi: sprite'ında gömülü gölge var). Yapılacak kalan: görünmezlik mekaniği. Eski not: bake (yeni PNG önce `--headless --import` ister; bu bake madde 47'nin orman dokusunu ve madde 48'in köprü geçidini de oyuna alır, gölge/minimap pencereli adımları da gerekir) + görünmezlik: alan = katmanın bağlı bileşenleri (ya da json), oyuncu içindeyken düşman hedeflemesi/sis + kopya katman örtüsü + çok oyunculu durum senkronu. Yedek: `harita/yedek/Harita_oncesi_saklanma-calilik.tmx.bak`.

51. **Ağaçlar görüşü (sis) keser, taç dahil (2026-10-09).** Kullanıcı: "ağaçların arkasının da görünmesini istemiyorum" (soruya cevap: "tüm ağaç, taç dahil görüşü kessin"). Eskiden sis/görüş SADECE
   orman/uçurum duvarı katmanıyla kesiliyordu (madde 27/vision_occluders.gd). Şimdi `GameManager.get_vision_tree_layers()` ("Harita/Shader Eklenecek/Ağaç 0/1/2", terrain_collision.gd TREE_PARENT/PREFIX ile aynı kural) dolu
   hücreleri AYNI engel ızgarasına girer: `vision_fog.gd _ensure_occluders` -> `built.build(layer, ağaç_katmanları)` (CPU gizleme + GLSL maske) ve `enemy_pathing.gd _build` `_fog_blocked`'a yazar (C++ EnemyWorld sis ışını;
   hareket/yol bulma ızgarası `_blocked` DEĞİŞMEDİ). Kapatmak: `vision_occluders.gd TREES_BLOCK_VISION = false`. YENİ KURAL (üç yerde AYNI: `vision_occluders.gd is_ray_blocked`, `vision_fog_mask.gdshader ray_blocked`,
   `enemy_world.cpp fog_ray_blocked`): kaynak bir engel karosunun İÇİNDEYSE (ağaç tacının altında duruyor) o engel kümesinden ilk çıkış "duvar arkası" sayılmaz - yoksa ağacın altında kör kalırdı; dışarıdaki başka ağaç/duvar yine keser.
   Orman duvarında kaynak normalde içeride olmadığı için eski davranış aynı. Görüş kuralını değiştirirsen ÜÇÜNÜ birlikte değiştir ve C++ için 4 kütüphaneyi derle (PLAN §6.1). Ağaç hücreleri hâlâ tacın TÜM karolarıdır (sprite
   dikdörtgeninin boş karoları dahil değil, sadece boyalı olanlar) - ağaç tacı olan bir ağacın altındaki yaratık/eşya, kaynak dışarıdaysa görünür kalır (engelin kendi yüzü görünür kuralı). Oynarken değerlendirilecek: orman çok kapalı
   hissettirirse `TREES_BLOCK_VISION` yerine sadece gövde (TerrainCollision TREE_BAND hücreleri) kullanılabilir. Testler: `test_vision_occluders` (+3), `test_vision_fog`.

52. **Saklanma çalılığı MEKANİĞİ + köşe dışı çalılıklar (2026-10-09).** Kullanıcı: "çalılara girince saklanalım; yaratıklar görürken girersek onlar da girip görebilsin, görmedikleri anda girersek istediğimiz kadar saklanırız" + "çalılar sadece köşelerde, ağaç kenarlarında v.b. de olsun, hem bake'te hem TMX'te".
   (a) HARİTA: `tools/hide_bush_proto/add_brush.py [N_AĞAÇ] [N_DUVAR]` (canlı Harita.tmx kaynak, mevcut çalılıklar aynen kalır; adaylar: ağaç öbeği kenarı - ağaç taçlarına 1-3 hücre, en az 14 ağaç karosu çevrede; düz kaya duvarı kenarı - köşe değil;
   aynı K1 stili + aynı `lane_ok` yol testi + hiçbir ağaç silinmez) -> `place_brush.py --apply <canlı md5>` (md5 kapısı) -> `preview_added.py <ilk_yeni_indeks>` önizleme. Bu tur 8 ağaç kenarı + 3 düz duvar = 11 yeni, toplam 29 çalılık (1186 hücre). Yeniden bake edildi
   (import + bake_harita + uid + terfi + gölge + minimap). KULLANICI KATMANI TILED'DA TAŞIDI (18:53): "Saklanma Çalılığı" artık "Orman parçaları" grubunda (ilk katman) - tüm kod katmanı ADIYLA arar (`HideBrush.find_layer`); üreticiler `brush_key` ile adla bulur. Yedekler `harita/yedek/*oncesi_agac-kenari-calilik*`.
   `harita/yedek/.gdignore` eklendi (yedek PNG'ler import edilmesin).
   (b) KURALLAR `scripts/hide_brush_manager.gd` (main.gd `HideBrushManager`, karar SADECE host/tekli oyunda, 0,1 sn): oyuncunun AYAĞI (`hide_brush.gd FEET_OFFSET`) çalılık katmanının dolu hücresindeyse çalıda. GİRİŞ anında `SPOT_RADIUS` (420 px) içindeki canlı yaratıklar "görenler" (hepsi en yakın oyuncuyu
   kovaladığı için görme = yakınlık); hiç gören yoksa durum 1 SAKLI (kimse hedeflemez, çalıda kaldıkça sınırsız), gören varsa durum 2 GÖRÜLMÜŞ (görenler çalıya girip kovalar). Saklıyken yanına `BUMP_RADIUS` (56 px) giren yaratık da görenlere eklenir (benim seçimim). Çıkınca/ölünce/ev içine girince/yerde yatınca
   kayıt silinir. HEDEFLEME C++'ta: yeni `EnemyWorld.set_stealth(hedef_düğüm_kimlikleri, [görebilen_yaratık_kimlikleri])`, `find_closest` + önbellekli hedef geçerlilik kontrolleri `concealed_from` ile çalıdaki oyuncuyu GÖRMEYEN yaratıktan eler (4 kütüphane yeniden derlendi). `enemy.gd`'nin eski GDScript hedefleme dalı
   çalılığı BİLMEZ (host yolunda kullanılmıyor). GÖRSEL: durum her peer'in ekranında karakter sprite'ının `anim.self_modulate.a`'sına yazılır (saklı 0,5, görülmüş 0,82; `HideBrush.alpha_for`) - host `NetworkManager.sync_brush_state` RPC'si (`_from_host` korumalı, yalnız DEĞİŞİNCE + 2 sn'de bir) -> `brush_state_received` sinyali -> yönetici
   `Player.set_brush_state` / `RemotePlayer.set_brush_state`. Çalının içindeki karakter tutamların ARKASINDA kalır: `depth_occluders.gd` çalılık katmanını (adla) nesne katmanı olarak ön kopyalar (gerçek pencerede doğrulandı: içeride gövde örtülü, önünde görünür). BİLİNÇLİ KAPSAM DIŞI: çalıdan saldırınca açığa çıkma
   (otomatik silahlar çalıdan ateş eder, hasar alan yaratık hedeflemez), alan hasarı/mermi (isabeti etkilemez, sadece hedefi), Yeraltı Canavarı uzuv yönetmeni (oyuncu konumlarına bakar). Testler: `test_hide_brush` (7: kural + gerçek C++ hedefleme; mutasyonla denendi). Gerçek oyunda iki oyuncuyla elle izlenmedi.
   **2026-10-10 GÖRÜNÜM + "GÖRENLER" DÜZELTMESİ (kullanıcı: "içine girince bedenimizin yarısı görünmüyor, sadece hafif saydam olalım; görmedikleri anda girdiysek aramayı bıraksınlar; içindeyken çalılar sallansın, bedenimiz çalıda yürüyormuş gibi görünsün").**
   (a) Çalılık artık `depth_occluders.gd` nesne kopyası DEĞİL: `scripts/hide_brush_visual.gd` katmanı komşu hücrelerin 8-bağlı KÜMELERİNE (= bir çalı) ayırır, yer katmanına + ön kopyaya `scenes/saklanma_calilik.gdshader` verir
   (tek shader: `on_katman` false = yer, true = kopya). Rüzgarla KENDİLİĞİNDEN sallanmaz (`AMBIENT_STRENGTH` 0; kullanıcı 2. tur: "içindeyken çalının her tarafı sallanıyor, ben sadece bulunduğum konumun sallanmasını istedim"); karolar atlasta benzersiz/sıralı olduğundan komşu karo atlas konumu `komsu_veri` dokusunda açıkça yazılır (sallanan ot.gdshader atlas komşuluğuna güvenir, burada yanlış olurdu).
   İçinden bir karakter yürüyünce SADECE onun çevresindeki hücreler (`RUSTLE_RADIUS` 34 px, gövde ortası merkezli, uzaklaştıkça zayıflar) hışırdar: hücre başına yay-sönüm + giriş itkisi (`step()`), eğilme dokusu hücre başına yazılır ve shader onu DOĞRUSAL süzerek okur (hücreler arası yumuşak dalga, karo dikişi yok); ağ gerekmez, uzak kuklalar da yerel konumdan okunur. (b) Ön kopya derinlik kuralı aynı (kök ayağın aşağısındaysa örter) AMA içindeki karakterin SADECE BACAK kısmını (gövdenin alt yarısı, shader `ICERDE_ORTU_ORANI` 0,5)
   yapraklar `INSIDE_FOLIAGE_ALPHA` (0,5) opaklıkla örter, üst yarı açıkta (kullanıcı 2. tur: "içinde gözükmüyoruz"; ilk sürüm 0,28 ile TÜM gövdeyi örtüyordu + sprite 0,5 soluktu = fazla koyu; `HideBrush.alpha_for` de 0,5/0,82 -> 0,7/0,9 oldu) (`karakter_orter` uniform'u, `depth_occluders.gd _update_brush_alpha`: ayağı çalılık hücresindeyse); dışarıda/arkasında eskisi gibi tam örtü; yaratıklar tam örtülür. (c) "Gören" kuralı: `hide_brush_manager.gd SPOT_RADIUS` 420 -> 340 VE C++ `is_los_clear`
   (eskiden duvar/ağaç arkasındaki ve görüş dışındaki yaratıklar da "gören" sayılıp çalıda kovalıyordu); yanından geçen (BUMP) kuralı görüş hattı aramaz. KAPSAM DIŞI KALAN: bosslar/yetenek betikleri (`enemy_abilities.damageable_players` vb.) çalıdaki saklı oyuncuyu hâlâ hedef alabilir - sadece C++ hedefleme + bekçiler saklıyı görmez.
   Testler: `test_hide_brush_visual` (6: kurulum/veri paylaşımı, küme kökü, hışırtı SADECE karakterin çevresinde + durulma, giriş itkisi/yerinde durunca sallanmaz, rüzgar sallanması kapalı, içerideki/dışarıdaki karakter yaprak opaklığı), `test_hide_brush` (7, görüş yarıçapı 340'a güncellendi). Gerçek renderer (kendi Godot penceresi) ekran görüntüsüyle doğrulandı: gövde yaprakların arkasında seçilebiliyor, yürürken çalı biçimi değişiyor, karo dikişi yok. Oyunda iki oyuncuyla elle izlenmedi.

53. **Geniş çalılar rüzgarda bölünmesin (2026-10-09).** Kullanıcı (ekran görüntüsüyle): "bazı çalılar rüzgarla hareketlenince ikiye üçe bölünüyor". KÖK NEDEN: `sallanan ot.gdshader` pikseli karonun İÇİNDE kaydırır ve taşan içeriği
   `discard` ediyordu (her karo sınırında kayma kadar boşluk -> dikey çizgiler) + her karo kendi fazını alıyordu (`hash(karo x, kök y)` + karo x'e bağlı dalga). Tek karolu ot/dikey ot buna takılmazdı. DÜZELTME: `grass_sway.gd _write_cell_data` atlasta
   bitişik (yatay +1 / çevrikte -1, dikey +1; aynı kaynak+alternatif) karoları TEK bitki grubu sayar; en az iki sütunlu gruplarda veri dokusu artık RGBA8: R/G ortak kök/boy (grubun en alt satırı), B = grup fazı, A = atlasta sol(1)/sağ(2) komşu bitleri;
   shader B>0 ise tüm karolara aynı faz (karo x dalgası yok) verir ve karo sınırından taşan içeriği komşu karonun GERÇEK pikselinden okur (`karo_hucre` aralıklı atlas hücresi). Tek karo/dikey ot AYNEN eski yolda (B=0). Gerçek renderer'da eski/yeni
   karşılaştırmalı ekran görüntüsüyle doğrulandı (eski: çalılarda dikey çizgiler, yeni: dikişsiz). Temas eğilmesi hâlâ hücre başına (geçici, dikişi bozmaz ama komşu karolar birkaç px farklı kayabilir). Test: `test_grass_sway_wide_bushes` (2). Ağaç katmanları
   (`sallanan ağaç.gdshader`) köşe kaydırmalı olduğu için bu sorunu yaşamaz.

54. **Köprü: güvertede korkuluk + altında tam örtü (2026-10-09, madde 48'in devamı).** Kullanıcı (ekran görüntüsüyle, vadiyi aşan yatay köprü): "köprünün üstündeyken yere yürüyebiliyorum; altından geçince köprünün bir kısmı üstümde görünüyor, bir kısmı görünmüyor".
   (a) GÜVERTE KORKULUĞU: `depth_occluders.gd deck_blocks(node, to_feet)` / static `deck_exit_blocked(rect, to_feet, from_feet)`: güvertede (bridge_deck.gd durumu "deck") olan karakterin ayağı yatay köprüde `DECK_TOP_INSET` (12 px, korkuluk satırı) ile `DECK_BOTTOM_INSET`
   (1 px) arasındaki ŞERİDİN dışına çıkamaz; şeritten uçlara (sol/sağ yamaç) çıkış serbest; şerit dışında doğan karakter sadece şeride DÖNEN adımı yapabilir (sıkışmaz). Çağıran: `player.gd _block_movement_into_terrain` (ayaktan `DECK_PROBE` 3 px ileri yoklar; DepthOccluders
   "depth_occluders" grubunda). KAPSAM: sadece yerel oyuncunun yürümesi (ışınlanma/atılış/savrulma ve yaratıklar köprüden hâlâ düşebilir; uzak kukla konumu ağdan gelir). (b) KÖPRÜ KÖKÜ PAYI `BRIDGE_ROOT_SLACK` 8 px: kök en alt opak satır olunca köprü dikdörtgeninin güney kenarını biraz geçen
   karakterin ayağı "önde" sayılıp tahtalar gövdeyi örtmüyor, sadece korkuluk örtüyordu; kök aşağı kaydırıldı. Korkuluğun direkleri arası şeffaf olduğu için altındaki karakter oradan hâlâ görünür (sprite'ın kendi boşlukları). Gerçek renderer görüntüleriyle doğrulandı. Testler: `test_bridge_deck` (10).

55. **Kenar bekçileri / yaratık kampları (2026-10-09).** Kullanıcı: "bazı yaratıkların haritanın kenarlarında olmasını istiyorum, özellikle sağ alt kenarda daha tehlikeli sayıda; oyuncuları görünce agrolansınlar, yerini görünce takip etsinler, görüş dışına
   çıkınca bir süre takip edip bulmaya çalışsınlar". `scripts/guard_camps.gd` (main.gd `GuardCamps`, karar SADECE host/tekli oyunda): `CAMPS` = 11 kamp (hücre koordinatı; açık alan analizi `tools/`-dışı geçici betikle, boşluk >= 6 hücre): sağ alt = düşman üssü çevresi 3 büyük kamp (12 + 9 + 8) ve
   K/KB/KD/D/B/GB/G/B2 kenarlarında 4-5'lik küçük kamplar (toplam 62 bekçi). Başlangıçta SPAWN_PER_TICK (3) ile doğar (`enemy_spawner.gd spawn_guard`: `_spawn_regular_enemy` ile aynı kurulum + "guards" grubu, "spawn_tier" meta'sı YOK = kademe kapısı/gate-rush saymaz, elit değil, o anki kademenin roster'ından);
   kamp boşalınca refill (150/210 sn) sonra, oyuncular CLEAR_RADIUS (800) dışındayken o günkü kademeden yeniden dolar. Doğuş tavanı sayımı bekçileri SAYMAZ (`_regular_enemy_count`). DURUMLAR: IDLE (kampında PATROL_RADIUS 85 gezinir; C++ "uykuda") -> oyuncuyu SIGHT (340 px) içinde + C++ `is_los_clear` ile görünce CHASE
   (uykudan çıkar, normal yaratık gibi en yakın oyuncuyu kovalar; kampında ALERT_RADIUS (420) içindeki arkadaşlarını da uyandırır) -> kimseyi göremeden MEMORY (4,5 sn) sonra SEARCH (son görülen konuma koşar, SEARCH_TIME 7 sn dolanır; görürse CHASE) -> RETURN (kampa döner, varınca canı dolar, IDLE); kovalama kampından LEASH (1000) uzağa giderse
   RETURN; 45 sn dönemeyip takılan, kimse yakında değilse kampa ışınlanır. Çalıda SAKLI (brush_state 1, madde 52) oyuncu görülmez. C++ (`EnemyWorld`): `set_dormant(slot, bool)` (uykuda: hedef yok, `find_closest` -1) + `set_goal(slot, x, y, mult)` (uykudaki yaratık o noktaya yürür, `wander_velocity` içinde; mult <= 0 = dur) - 4 kütüphane
   yeniden derlendi. İstemcide bekçi AI'sı yok (kukla). Kamp koordinatını/sayısını değiştirmek = `CAMPS` tablosu. BİLİNÇLİ YAPILMAYANLAR: kamp konumları oyuncu başlangıcından uzak ama harita çarpışmasıyla DOĞRULANMADI (sadece analiz maskesi); host devrinde kamplar sıfırdan yeniden doğar; bekçi yağma/ödül dengesi ayrıca ayarlanmadı (normal yaratık gibi XP/altın/drop).
   Testler: `test_guard_camps` (3: uyku/görüş/kovalama, kaybedince arama-dönüş-uyku, kamp arkadaşı uyandırma + saklı oyuncu; mutasyonla denendi) + gerçek Main başsız duman: 62 bekçi doğdu, hepsi IDLE. Gerçek oyunda oynanarak (denge, takılma, iki oyuncu) izlenmedi.

56. **Çiçekler çalılar gibi sallanır (2026-10-09).** Kullanıcı: "haritadaki çiçekler de çalılar gibi sallansın, y eksenine sahip olsun, dokununca sallansın". `grass_sway.gd LAYER_NAMES`'e "Çiçekler 1" eklendi: aynı shader (rüzgar sallanması, madde 53 geniş grup mantığı dahil),
   aynı yukarı/aşağı önceliği (katmanın oyuncuların üstünde çizilen `OtOnKatman` kopyası: çiçeğin önünde durunca çiçek gövdeni örter, arkasında durunca örtmez) ve aynı dokunma eğilmesi (yay-sönüm). Çiçek katmanında shader'ın yeşil renk çeşitliliği (hue/doygunluk kayması) SIFIRLANIR - çiçek renkleri
   değişmesin. Katmanın `use_parent_material` bayrağı kapatılır. Gerçek renderer görüntüsüyle sallanma, başsız denemeyle dokunma eğilmesi (bend 178 > 128) doğrulandı; testte yeni kod yok. Başka bir çiçek/ot katmanı eklemek = `LAYER_NAMES`'e adını yaz (aynı 16 px + dolgulu atlas varsayımı).

57. **Orta bölge ağaç seyreltme (2026-10-09).** Kullanıcı: "harita çok boğuk, orta kısımlarda gereksiz boğucu ağaçlar var (dış köşeler ve dağların arkası hariç), biraz azalt, Harita.tmx'e de yap". `tools/forest_decor/thin_trees.py` (canlı Harita.tmx kaynak, md5 kapılı `--apply`, sabit tohum):
   SADECE benim eklediğim ağaç damgaları (özgün yedekte olmayanlar; kullanıcının kendi ağaçlarına dokunulmaz) ve sadece haritanın `EDGE_MARGIN` (28) hücre içindeki orta bölgesinde: duvardan uzak (açık alan) ağaçların %35'i, dağ/uçurum kenarındakilerin (`WALL_NEAR` 4 hücre) %65'i kalır, kalanlar arası en az 4 hücre.
   Dış halka (28 hücre) dokunulmadı. 154 orta bölge ağacından 68 kaldırıldı (Ağaç 0'dan 857 hücre). TMX + `harita_baked.tscn` + gölge + minimap yeniden pişirildi. Yedek: `harita/yedek/Harita_oncesi_agac-seyreltme.tmx.bak`. Daha az/çok = `KEEP_OPEN` / `KEEP_NEAR_WALL` (yedeği geri koyup yeniden üret; üstüne tekrar çalıştırma ek seyreltir).
   Ağaçlar görüşü de kestiği için (madde 51) seyreltme sis görüşünü de açar.

58. **Kademe 8 bossu: BALKABAĞI KAFA (2026-10-09).** Kullanıcı: masaüstü `balkabağı herif` paketi + `boss ve yetenekleri.txt` ("yapmaya başlar mısın"; belgede 4 boss var: Balkabağı K8, Wendigo K12, Banshee K15, Uçan Şeytan FİNAL - SADECE ilki yapıldı, sıradakiler bekliyor).
   Belge: "normal halinden 2 kat büyük; belli aralıklarla bol sayıda balkabağı yaratığı ve yarasa spawnlar (ayrı aralıklarla); balkabakları %70 / yarasalar %30 stat, +%20 / +%30 hız; yarasa ısırınca kanama 5/sn; balkabağı yaklaşınca patlar alan hasarı 20;
   boss belli aralıklarla bol ateş topu (10 hasar), yaklaşırsa normal saldırı 20". Belgede CAN/KALKAN YOK -> BENİM SEÇİMİM: 100.000 / 120.000, soğurma %85 (`FIXED_BOSS_STATS["balkabagi1"]`; Minotaur 32k/36k ile Wendigo 200k/280k arası) - kullanıcı onaylamadı, gerekirse tek satır.
   (a) SANAT: `tools/import_pumpkin_sheets.py` (paket satır sırası aşağı/SOL/SAĞ/yukarı -> projenin aşağı/yukarı/sol/sağ; Minotaur ile aynı eşleme) -> `assets/enemies/pumpkin/` (boss hücre 200: walk/idle/attack/cast/summon/death/hurt; kabak + yarasa hücre 64) + `assets/fx/pumpkin/` (büyü),
   sahneler `tools/gen_pumpkin_scenes.py` -> `scenes/creatures/enemy_{balkabagi1,kabak1,yarasa1}.tscn`. Boyut: sahne 0,8 (200% sanatta = 100% sanatta 1,6 "normal" boy) x boss çarpanı 2,0 (`FIXED_BOSS_STATS "scale"`, YENİ alan: `_setup_boss_enemy` BOSS_SCALE_MULT yerine bunu okur) -> ekranda ~123 px.
   (b) YENİ ORTAK ALTYAPI (sonraki bosslar da kullanır): `enemy.gd special_textures` + `play_special_anim(ad, süre)` (boss özel animasyonu; ATTACK durumu üzerinden, süre bitince yürümeye döner) ve `emit_ability_vfx("boss_event", {"k": "anim"|"dismiss", ...})` (ağ: `broadcast_enemy_vfx` "boss_event"; "anim" = özel animasyon, "dismiss" = ödülsüz dağıl,
   diğerleri ability sınıfının `on_boss_event`'ine); `boss_spell.gd` (genel boss büyü mermisi: data dir/speed/life/radius, kind "bossfire", dünya efekti "boss_spell"), `boss_fx_util.gd` (şerit spritesheet -> SpriteFrames, tek seferlik efekt), `enemy_abilities.gd handle_melee_hit` (yaratığa özel temas vuruşu kancası),
   `enemy_spawner.gd spawn_summon(kind, pos, boss)` + `SUMMON_STATS` + `_apply_summon_stats` (boss minyonu: kademe ölçeği + kalkan + global çarpan, sonra can/kalkan oranı, hız çarpanı, ödül x0,3; "summons" grubu = doğuş tavanını doldurmaz, kademe kapısını tutmaz; meta "summoner" = boss; istemci RPC'si de aynı oranları uygular),
   `player.gd apply_enemy_bleed` (KANAMA: 4 sn x 5/sn sürekli hasar, `take_special_damage` kind "bat_bite" tetikler, "bleed" DoT kilidine/sıvışmaya tabi değil; durum rozeti `assets/ui/status/bleed.png` + `status_effect_badge.gd` "bleed").
   (c) DAVRANIŞ: `pumpkin_boss.gd` (host; ailelerden "balkabagi"): ATEŞ TOPU SALVOSU (cast animasyonu, 5 top yelpaze +-26 derece, 0,09 sn aralıkla, 190 px/sn, her biri 10 hasar, 3,2-4,8 sn'de bir, menzil 90-620 + görüş hattı), KABAK DALGASI (6 + ekstra oyuncu başına 2, en çok 20 canlı, 11-14 sn, cast animasyonu) ve
   YARASA DALGASI (4 + 2/oyuncu, en çok 12, 15-19 sn, summon animasyonu) AYRI zamanlayıcılarla, halka şeklinde doğuş; normal saldırı = C++ temas saldırısı (contact_damage 20). `pumpkin_minions.gd` ("kabak"/"yarasa" aileleri): KABAK 46 px yaklaşınca 0,5 sn fitil (saldırı animasyonu) sonra `pumpkin_blast.gd`
   (58 px alan, 20 hasar kind "blast", halka efekti) + kendi parçalanma animasyonuyla ödülsüz dağılır; YARASA temas ısırığı `bat_bite` 5 hasar + kanama; minyonlar sahipleri ölünce/silinince ödülsüz dağılır. Sayılar dosya başı sabitleri.
   (d) ÇOK OYUNCULU: karar/hasar/doğuş host'ta; animasyon `boss_event` ile, ateş topu/patlama `broadcast_enemy_ability_fx` dünya efektiyle, minyonlar normal yaratık RPC'siyle (istemci doğuşu SUMMON_STATS'ı uygular). Gece parıltısı: `night_glow_catalog.gd` boss_spell.
   Testler: `test_pumpkin_boss` (7: sayfa/sahne sözleşmesi, statlar+boyut+özel animasyon, minyon orantıları/tavan, kabak patlaması, yarasa ısırığı+kanama, salvo+iki dalga+boss ölünce dağılma, ateş topu isabeti) + gerçek Main başsız duman (6 kabak / 4 yarasa / salvo, hata yok). `test_elite_pool_and_bosses_off` Kademe 8'i kabul edecek şekilde güncellendi.
   DOĞRULANMADI: gerçek pencerede görünüş (özellikle cast/summon animasyonlarının zamanlaması, kabak/yarasa boyları, ateş topu görünümü), iki süreçli çok oyunculu, denge (boss ~220.000 etkin can; minyonlar ve 10-20 hasarlı saldırılar kademe 8 oyuncusuna karşı çok zayıf kalabilir - sayılar kullanıcının belgesinden aynen).

59. **Kademe 12 bossu: WENDİGO (2026-10-09).** Belge ("boss ve yetenekleri.txt") + kullanıcı: "wendigonun can ve kalkanını söylediğim gibi yap" -> `FIXED_BOSS_STATS["wendigo1"]` AYNEN: can 200.000, kalkan 280.000, soğurma %85, normal saldırı 120, boyut 3x ("scale" 3.0; ekranda ~180 px),
   `NEW_BOSS_TIERS[12]`. Sanat: `tools/import_wendigo_sheets.py` (aynı aşağı/SOL/SAĞ/yukarı eşlemesi) -> `assets/enemies/wendigo/` (walk 4, idle 4, attack 7 = normal pençe, vine 12 = "attack 2" sarmaşık çağırma, slam 8 = "attack 3" yere vurma, death 8, hurt 2; hücre 100) +
   `assets/fx/wendigo/vine.png` (paketin "branch - full animation": 6 kare uyarı + 13 kare çıkış); sahne `tools/gen_wendigo_scene.py` (gen_pumpkin_scenes.scene yardımcısıyla). `wendigo_boss.gd` (host; "wendigo" ailesi): SARMAŞIK ÇEVRİMİ 2,4-3,0 sn'de bir (vine animasyonu, boss durur, 3 patlama x 3 sarmaşık):
   oyuncunun HAREKET yönünün önüne (hız süzgeci `_vel`; lead = hız x (0,75 + 0,35 k) + 40, yan yana 52 px) ya da duran oyuncunun çevresine halka; `wendigo_vine.gd` (uyarı 0,7 sn + çıkış 0,8 sn, çıkış penceresinde yarıçap 26 içindeki oyuncuya BİR kez 100 "vine", en çok 16 canlı);
   KAYA YAĞMURU 9-12 sn'de bir (ilki 6 sn, slam animasyonu 0,5 sn'de): her oyuncunun TAM üstüne + çevresine (50-120 px) 4 kaya, uyarı halkası 1 sn, düşüş 0,28 sn, alan 44 px, 130 "rock" (`wendigo_rock.gd`, kaya sprite'ı pakette yok -> kodla çizilen piksel çokgen kaya + toz + kamera sarsıntısı,
   en çok 20). Dünya efektleri `spawn_world_fx` "wendigo_vine"/"wendigo_rock" + host yayını. Gece parıltısı: kaya uyarısı. Sayılar dosya başı sabitleri. Testler: `test_wendigo_boss` (5) + gerçek Main başsız duman (sarmaşık/kaya doğdu, ölçek 3,648) + gerçek renderer görüntüsü (uyarı/çıkış/düşen kaya).
   DOĞRULANMADI: iki süreçli çok oyunculu, gerçek oynanış hissi (sarmaşık yön tahmini, kaya yoğunluğu), sesler (yok).

60. **Kademe 15 bossu: BANSHEE (2026-10-09).** Belge: "normal halinden 3 kat; zifiri gece olduğunda doğar, var olduğu sürece asla gündüz olmaz; gece oyunculara doğru hızlı uçarak içlerinden geçip hasar vermeye çalışır (ivmeli uçar, yavaşlar, döner, tekrar); belli
   aralıklarla durup, oyuncudan uzakta ve yavaş uçarak çığlık atar: yön UYARILIR, düz ve kalın şeritler, duvar arkasından geçemez ama Banshee duvarların üstünden uçar; Can 300.000 Kalkan 480.000". Belgede soğurma/hasar YOK -> BENİM SEÇİMİM: soğurma %90, atılış 120 (= contact_damage), çığlık 130
   (`FIXED_BOSS_STATS["banshee1"]`, `NEW_BOSS_TIERS[15]`, scale 3.0, reward_ref rontgen3). Sanat `tools/import_banshee_sheets.py` -> `assets/enemies/banshee/` (move 4, idle 4, attack 6 = "dash", scream 7, appear 5, death 5, hurt 2; hücre 80), sahne `tools/gen_banshee_scene.py`.
   (a) GECE KİLİDİ (yeni, başka bir şey de kullanabilir): `atmosphere.gd set_night_lock(bool)` (SADECE yetkili; durumla herkese: state "nl") + `atmosphere_math.gd night_lock_step/is_deep_night/NIGHT_LOCK_*`: kilitliyken saat gece yarısına (465) 70 birim/sn akar (gündüzden ~7 sn) ve orada DURUR (istemci de yerelde durur);
   "night_lock_boss" grubunda canlı boss kalmayınca host kilidi 2 sn içinde kendisi açar (boss ölümü/silinmesi/host devri takılı bırakmasın). Doğuş kapısı: `enemy_spawner.gd NIGHT_BOSS_TIERS [15]` + `_night_ready_for_boss()` (`_check_boss_tiers` bunu bekler: kilit istenir, derin gece olunca boss doğar). Açılışta kilit
   boss kitinde de istenir; `enemy.gd die()` -> `_abilities.on_owner_died()` (yeni genel kanca) -> kit kilidi açar.
   (b) DAVRANIŞ `banshee_boss.gd` (host; "banshee" ailesi): yaratık C++'ta UYKUDA (`set_dormant`: hedef/temas yok, oyuncuların içinden geçer), konumu betik her karede ilerletir (harita dikdörtgeninde kalır, duvar engel DEĞİL). Durumlar APPEAR -> APPROACH (190 px/sn, 250 px'e kadar) -> WINDUP (0,55 sn nişan) ->
   DASH (780 px/sn² ivme, en çok 580 px/sn, mesafe+260 px, "dash" animasyonu; her atılışta oyuncu başına TEK isabet 120) -> SLOW (820 px/sn² yavaşlama) -> PAUSE; her 3 atılıştan sonra RETREAT (120 px/sn yavaş geri çekil, 380 px'e kadar) -> SCREAM ("scream" animasyonu, her hedef oyuncuya (en çok 3) 3 düz şerit: tam üstüne
   + +-18 derece; `banshee_wave.gd`: 44 px kalın, uyarı 1,0 sn soluk şerit, sonra 0,45 sn ses dalgası, şerit içindeki her oyuncuya BİR kez 130, uzunluk `clip_ray_to_walls` ile duvara kısalır). Temas saldırısı bastırılır (`blocks_melee`). `enemy.gd no_body_block` (yeni, genel): oyuncular bu yaratığın
   içinden geçebilir (`player.gd _block_movement_into_enemies` atlar). Testler: `test_banshee_boss` (7: sayfa/sahne/tablo/stat/boyut, gece kilidi matematiği, atmosfer kilidi kendi kendine açılma, doğuş kapısı, atılış (içinden geçiş + tek isabet + yavaşlama), çığlık şeritleri (6 şerit, uyarıda hasar yok, tek isabet 130), şerit geometrisi)
   + gerçek Main başsız duman (tüm 8 durum, 6 atılış, şeritler, kilit açık) + gerçek renderer görüntüsü (uyarı şeritleri + ses dalgası). DOĞRULANMADI: iki süreçli çok oyunculu (gece kilidi istemcide), gerçek oynanış hissi (atılış kaçınılabilirliği, çığlık şeritleri), sesler (yok), geceyi gündüzden değiştirmenin harita/ışık geçişinin göze nasıl göründüğü.

61. **FİNAL bossu: UÇAN ŞEYTAN + Final akışı (2026-10-09).** Kullanıcı: "final bossu öldürdükten sonra sonsuz mod açılacak" (belge: "Tüm kademeler bittikten sonra ortaya çıkar; normal halinden 4 kat büyük ve dışa doğru parıltılı; seri ateş topları 200 hasar + yanma 50/sn; geniş açılı Kozmik ışın
   yavaşça 360 derece döner, temas edene her 0,5 sn'de 100; uçarak normal saldırı 150; canı %50 altına düşünce form değiştirir (gözler hafif kırmızı), özellikleri daha sık, bazen kendini saniyede %1 iyileştiren büyü yapar (yaparken saldırmaz); Can 1.000.000 Kalkan 1.200.000 Soğurma %90").
   (a) FİNAL AKIŞI: `enemy_spawner.gd NEW_FINAL_BOSSES ["ucansetan1"]` + `new_final_enabled` (varsayılan true; false = eski "Kademe XV bitince doğrudan sonsuz"): `_final_active()` (bosses_enabled VEYA yeni final) ve `_final_ids()` artık `_check_final_tier/_final_pending/_check_tier_announcement`te kullanılır. Akış: Kademe XV bossu (Banshee) ölür -> kapı (1-15. kademe yaratıkları) -> "KADEME XVI" bildirimi +
   Uçan Şeytan `_spawn_boss_group` ile doğar (FINAL_TIER 16) -> ÖLÜNCE `_check_victory` zafer penceresi (kalan yaratıklar ödülsüz dağılır) -> host "Sonsuza Devam Et" -> `begin_endless` -> sonsuz Kat 1. Eski 13'lü Final (`bosses_enabled`) AYNEN duruyor. NOT: zafer penceresi VAR (sonsuz mod pencereden "Sonsuza Devam Et" ile açılır, kendiliğinden başlamaz) - istenirse
   doğrudan sonsuza geçilebilir (`_begin_victory` yerine `_enter_endless`). Zafer rekoru/başarımları (Hayatta Kaldım! vb.) bu akışta yeniden çalışır (zafer yolu açık).
   (b) STAT/BOYUT: `FIXED_BOSS_STATS["ucansetan1"]` AYNEN (1.000.000 / 1.200.000 / %90, saldırı 150, scale 4.0, reward_ref rontgen3). Sanat `tools/import_demon_sheets.py` -> `assets/enemies/demon/` (fly 4 = uçuş+bekleme, attack 5, cast 6, death 6, hurt 2; hücre 80) + `assets/fx/demon/fire_shot.png`; sahne `tools/gen_demon_scene.py`.
   Dışa parıltı: `boss_glow.gd` (bossun arkasında toplamalı dairesel hale, nefes alır; mavi-mor / faz 2 kızıl / iyileşme yeşil; her peer yerelde kurar).
   (c) DAVRANIŞ `demon_boss.gd` (host; "ucansetan" ailesi; Banshee gibi UYKUDA + elle uçar, oyuncuların içinden geçilir): HOVER (oyuncudan ~330 px, yavaş daire) -> seçim önceliği: iyileşme (faz 2) > kozmik ışın (ilki 8 sn, 16-20 sn'de bir) > uçarak saldırı (4 sn'de ilki, 8-11 sn: DASH_IN 620 px/sn -> STRIKE 0,2 sn'de 150 "demonslash" ->
   DASH_OUT) > ateş topu salvosu (5-7 sn: 10 top, 0,09 sn aralıkla, 300 px/sn, +-0,1 rad; faz 2'de 14). ATEŞ TOPU `demon_fireball.gd` (patlama yarıçapı 44, 200 kind "demonfire" -> `player.gd take_special_damage` 50/sn yanma `DEMON_BURN_DPS`, `apply_enemy_burn` ile 3 sn). KOZMİK IŞIN `cosmic_beam.gd`: boss'u takip eden
   40 derece (yarım açı 0,35 rad) dilim, 820 px, uyarı 1,2 sn, 10 sn'de tam tur (yön rastgele), her 0,5 sn 100 "cosmic"; boss ışın boyunca durur. FAZ 2 (can <= %50): `boss_event` "phase2" -> gözler kızıl (sprite self_modulate), tüm bekleme süreleri x0,65; iyileşme büyüsü 24-32 sn'de bir, 5 sn, azami canın %1'i/sn,
   saldırmaz (`boss_event` "heal" rengi).
   Yeni ortak parçalar: `enemy_abilities.gd on_boss_event` (kit olayları), `boss_fx_util.frames_from_strip(first, count)`. Testler: `test_demon_boss` (6: sayfa/sahne/tablo/stat/boyut/parıltı, Final akışı kademe -> Uçan Şeytan -> zafer -> sonsuz + new_final_enabled=false, salvo+isabet+yanma, ışın dönüşü/tiki, uçarak saldırı, faz 2 + iyileşme) + gerçek Main başsız duman (HOVER/FIRE/DASH/STRIKE/BEAM durumları) +
   gerçek renderer görüntüsü (boss + parıltı + ışın + toplar). `test_elite_pool_and_bosses_off` iki eski test `new_final_enabled=false` ile eski davranışı sınar. DOĞRULANMADI: iki süreçli çok oyunculu, gerçek oynanış hissi/denge (1M can + 1,2M kalkan, ışın kaçınılabilirliği), host devrinde Final (yeni host Final'i yeniden doğurur), sesler (yok).

62. **Toplu istek: 13 madde (2026-10-10).** Kullanıcı tek mesajda şunları istedi; hepsi bu oturumda yapıldı, HİÇBİRİ commit edilmedi / oyunda OYNANARAK doğrulanmadı (testler + başsız/gerçek-renderer ölçümleri).
   (a) **Vampir R** can yenileme oranı %5 -> %4 (`player.gd VAMPIR_R_HEAL_RATIO` 0,04; `characters.gd` metni, `test_vampir_cocuk`).
   (b) **Kademeler %50 uzun** (kullanıcı: "kademeler çok kısa sürüyor"): `enemy_spawner.gd tier_duration` 100 -> 150. Kademeye bağlı HER şey buna bağlı (kademe saati, boss tetikleri, sonsuz kat süresi, kalabalık ölçeği) - saniyeye bağlı eğriler KADEME BAŞINA eskisiyle aynı kalsın diye x100/150 ölçeklendi:
   `difficulty_ramp` 0,0006 -> 0,0004, `enemy.gd TIME_HEALTH_GROWTH_START` 200 -> 300 / `_PER_MIN` 0,01 -> 0,0066667, `DIFFICULTY_HEALTH_RAMP` 0,00017 -> 0,00011333, `DIFFICULTY_DAMAGE_RAMP` 0,00012 -> 0,00008; seyyar satıcı fiyat kademesi
   `merchant_shop_screen.gd MERCHANT_PRICE_TIER_DURATION` 150 (spawner'daki sayıyla AYNI olmalı; `test_tier_pacing` eşitliği sınar). Süre sabitini kopyalayan yeni bir yer eklersen onu da buraya bağla. 13 test dosyası kendi `sp.tier_duration = 100.0`'ını sabitler (kademe süresi o testlerin konusu değil).
   (c) **Yeraltı Canavarı** (kullanıcı: "uzuvlar sağa sola dönmeyi spamlıyor; çok zararsızlar, yeterince asit atmıyor, yeterince hareketli değiller, oyuncuların etrafında sürekli spawnlanmalı; boss aktifken zemin çatlaklarla dolu + hafif deprem"):
   KÖK NEDEN (bakış titremesi): uzuv C++ EnemyWorld'de normal yaratık olarak kayıtlıydı; C++ yapay zekâsı her düşünmede KENDİ hedefine çeviriyor, `worm_limb.gd` ise en yakın oyuncuya -> iki yazıcı satırı (sağ/sol/üst/alt) kare kare değiştiriyordu. Düzeltme: uzuv C++'ta UYKUDA (`set_dormant`),
   yön SADECE worm_limb.gd'den (`worm_boss_math.gd FACE_HOLD` 0,35 sn tutma + `FACE_AXIS_HYSTERESIS` 1,35, değişim "worm_face" ile istemcilere). Daha tehlikeli/hareketli (`worm_boss_math.gd`, eski değerler dosya başında): yüzeyde en çok 7 -> 10 uzuv (+3/ekstra oyuncu), çıkış aralığı 1,3-2,0 -> 0,55-0,95 sn, ömür yarıya (5-8 sn),
   asit atanlar %45 -> %60 ve ~2 kat sık, tek damla yerine 3 damlalık yelpaze (`worm_limb.gd ACID_VOLLEY*`), savurma beklemesi 1,7 -> 1,1 sn, yol kesen sıra 13-19 -> 9-13 sn. ZEMİN ÇATLAKLARI + DEPREM: `scripts/underground_cracks.gd` (HER peer yerelde, tohum bossun ağ kimliğinden = herkeste aynı; ağdan bir şey gitmez):
   haritanın "Yer" grubunun hemen üstünde (ağaç/su/bina/yaratıklar üstte; `top_level` KULLANMA - düğümü kökün üstüne çıkarıp her şeyin üstüne çizer), görüntüdeki 112 px hücrelerde zikzaklı çatlaklar yavaşça uzar, uzuv çıkışında ışınsal çatlak yıldızı, kamerada sürekli hafif titreme tabanı (`QUAKE_FLOOR`) +
   gümbürtüde (rumble 3-6 sn) kalınlaşma/toz/kısa sarsıntı; boss ölünce solar. Testler: `test_underground_boss` (24).
   (d) **Matthew NERF** (kullanıcı: "inanılmaz güçlü"): KÖK NEDEN köpek dört kanalı BİRDEN x2 çarpıyordu (hasar, saldırı hızı bonusu, kritik şansı, kritik çarpanı: orta oyunda ~380 hasar/sn yaratık başına ve yarım daire alanda kalabalığa, ortalama silahın ~2,4 katı). `player_pet.gd FOX_STAT_RATIO` 2,0 -> **1,0**
   (köpek Matthew'in statlarının %100'ü) + ısırık başına en yakın `FOX_MAX_TARGETS` (5) yaratık (`cone_targets`); aynı örnekte yaratık başına ~94 hasar/sn, en çok 5 yaratık. Q (Köpek Hücumu 110%), E, R (Feda Kalkanı) DEĞİŞMEDİ. `characters.gd` pasif metni güncellendi. Daha fazla/az güç = bu iki sabit. Test: `test_matthew_dog` (13).
   (e) **Kılıç (Uzunkılıç) NERF** (kullanıcı: "inanılmaz güçlü"): KÖK NEDEN dört yakın dövüş silahı AYNI atış aralığında (1,11 sn) ama kılıcın saldırı gücü oranı 1,62 idi (Bıçak 0,765, Pençe 0,9, Topuz 0,945) ve süpürülen alandaki HERKES tam hasar alıyordu (diğerleri %50). `weapon.gd SWORD_AP_RATIO` 1,62 -> **1,2**,
   `player.gd UZUNKILIC_AOE_PERCENT` 1,0 -> **0,7** (ana hedef tam, çevresindekiler %70). Wind Sword özelliği (rüzgar dalgası: şans/hasar/menzil) DEĞİŞMEDİ. `weapon_catalog.gd` açıklaması düzeltildi (eski "18 + %100" yanlıştı: melee silahların düz hasarı yok, sadece saldırı gücü oranı var). Test: `test_uzunkilic_swing` (6).
   (f) **HOST DEVRİ ÇALIŞMIYORDU - KÖK NEDEN BULUNDU (Epic/internet odası)** (kullanıcı: "host ayrılınca host değişimi düzgün çalışmıyor"): Epic eklentisinin `EOSGRuntime` autoload'ı her karede `IEOS.tick()` çağırır (bağlantı istekleri, P2P bildirimleri, lobi geri çağrıları HEPSİ bu tikte) ama `process_mode` PAUSABLE idi: `get_tree().paused` iken Epic TAMAMEN DURUYORDU.
   Host devri dünyayı DONDURUR (`_try_begin_host_migration`) -> yeni host'a bağlanmaya çalışan oyuncunun Epic bağlantısı HİÇ kurulamıyordu; aday pencere (30 sn) dolunca o oyuncu kendini host ilan edip AYRI bir oyun açıyordu (BÖLÜNMÜŞ OYUN: iki host, herkes yalnız) ya da 100 sn sonra ana menüye düşüyordu. 10-08'deki denetimler
   tesadüfen geçmişti: devir sırasında açık kalan seviye atlama ekranı kapanırken ağacı açıyordu. LAN (ENet) etkilenmez (SceneTree ENet'i duraklıyken de yoklar). ÖLÇÜM (`tools/mp_audit/eos_migration_probe.gd` + `run_eos_migration_probe.ps1`, 3 gerçek süreç): duraklı ağaç + pausable EOS = 100 sn / 20 deneme bağlantı YOK;
   `EOSGRuntime.process_mode = ALWAYS` = 0,77 sn. Genel bağlantı gecikmesi (`eos_connect_probe.gd`, `run_eos_probe.ps1`): sunucu hazır -> istemci bağlı ~0,7-2,2 sn, istemci sunucudan ÖNCE başlasa da (EOS bekler) 0,65 sn. DÜZELTME: `scripts/net/eos_online.gd _keep_eos_ticking()` (EosOnline `_ready` + `ensure_ready_async` + ertelenmiş çağrı): EOSGRuntime ALWAYS.
   Bu AYNI zamanda normal oyunda seviye atlama/sandık/duraklatma ekranı açıkken Epic'in durmasını da giderir. İKİNCİ düzeltme: `network_manager.gd _process_migration` devir sürerken ("hosting" hariç) ağacı her karede geri duraklatır (açık ekran kapanıp ağacı açarsa silahlar bağlantısız eşe RPC atıp hata yağdırıyordu). Küçük: aday bağlanırken
   "Yeni host: <ad> - bağlanılıyor..." bildirimi (`host_migration_state`). PENCERE KAPATMA (X / Alt+F4, menüden çıkmadan): LAN'da çıkış ENet'i düzgün kapatır (istemciler ~0,5 sn'de fark eder, ölçüldü), Epic'te süreç sessizce kaybolur ve istemci 12 sn kalp atışı sessizliğini beklerdi (devir ~16 sn); `network_manager.gd _notification(NOTIFICATION_WM_CLOSE_REQUEST)` -> `_graceful_quit_if_hosting` SADECE sürmekte olan internet odasının host'unda (`_hosting_online_game`) önce `close_room()` yapar, `QUIT_GRACE_SEC` (0,6 sn) sonra kendisi çıkar (`auto_accept_quit` geçici kapanır) -> devir ~4,5 sn (ölçüldü). Denetim modları: `run_audit.ps1 -Mode migration -Kill crash|close|quit|winclose [-Net epic]` (quit = close_room'suz düz çıkış). DENETİM de düzeltildi: `migration_audit.gd` artık `team_xp_needed`'i dev sayıya çeker (kimse seviye atlamasın - modal ağacı kendiliğinden açıp hatayı maskelemesin) ve örneklere `paused` yazar. KANIT (Epic kapanma): düzeltmeden ÖNCE iki istemci de kendini host ilan etti (`lobby=1 remotes=0` ikisinde de, bölünmüş oyun);
   SONRA yeni host t+0,5 sn'de kuruldu, duraklı istemci ~1 sn'de bağlandı, ikisi 4,5 sn'de aynı oyunda. LAN çökme + kapanma ve Epic çökme (12 sn kalp atışı sessizliği + ~4 sn) de geçti. Testler: `test_host_migration` (10: EOS ALWAYS + devir sırasında dünya donuk tutulur). Yeni bir autoload'ın duraklamada da çalışması gerekiyorsa `PROCESS_MODE_ALWAYS` ver.
   KALAN RİSK (düzeltilmedi): aday penceresi dolunca (LAN 10 sn / Epic 30 sn) sıradaki oyuncu kendini host ilan eder; ilk aday aslında yaşıyor ama ulaşılamıyorsa (güvenlik duvarı, NAT) iki host oluşabilir - bağlantı bilgisi dışında aday canlılığını öğrenmenin yolu yok. Windows güvenlik duvarı: yeni host olan oyuncunun makinesi ilk kez sunucu kuruyorsa izin penceresi çıkabilir.
   (g) **Balkabağı bossu** (kullanıcı: "boyutunu %30 küçült, daha güçlü, yeteri kadar yetenek ve yaratık spamlamıyor, hasarı 2 kat"): `FIXED_BOSS_STATS["balkabagi1"]` scale 2,0 -> 1,4, normal saldırı 20 -> 40; ateş topu 10 -> 20 ve salvo ~2 kat sık / 7 top (`pumpkin_boss.gd`), YENİ halka salvosu (16 top her yöne, `RING_*`), kabak dalgası 9 (+3/oyuncu, en çok 30, 6-8 sn),
   yarasa dalgası 6 (+3, en çok 18, 8-11 sn), canı (can+kalkan) yarıya inince bekleme süreleri x0,65 (`PHASE2_*`); kabak patlaması 20 -> 40 (`pumpkin_minions.gd BLAST_DAMAGE`), yarasa ısırığı x2 (`SUMMON_STATS["yarasa1"]["damage"]` 2,0) + kanama 5 -> 10/sn (`player.gd ENEMY_BLEED_DPS`). Test: `test_pumpkin_boss` (10).
   (h) **Banshee** (kullanıcı: "çok güçsüzdü, %30 küçült, daha agresif/hızlı, hasar 2 kat"): `FIXED_BOSS_STATS["banshee1"]` scale 3,0 -> 2,1, atılış 120 -> 240, çığlık 130 -> 260 (`banshee_boss.gd SCREAM_DAMAGE`); yaklaşma 190 -> 340, atılış en çok 580 -> 860 px/sn, nişan 0,55 -> 0,28 sn, atılış döngüsü ~3 sn -> ~1,4 sn, çığlık her 2 atılışta (eskiden 3), 5 şeritli (3), daha kalın/kısa uyarılı;
   çığlık şeritleri Şovalye baloncuğunda kesilir (j). Test: `test_banshee_boss` (8).
   (i) **Talon E (Silah Salvosu) FPS** (kullanıcı: "fpsi inanılmaz düşürüyor, nedenini anlamaya çalış"): gerçek Main + gerçek renderer ölçümü (250 yaratık, 5 silah, E açık): E atış hızını 5-6 katlar -> her isabette kalıcı silah özelliklerinin (kanama tikleri, Sismik Dalga, rüzgar kılıcı...) tek seferlik sprite efekti, gece ışığı (`atmosphere.gd _attach_glow`) ve mermi isabet sesi düğümü doğuyor:
   saniyede ~900 yeni düğüm (327'si efsun efekti), kare 12 -> 25 ms (81 -> 40 fps), 50-60 ms takılmalar (ayrıca silah başına `take_damage` ~66 µs x ~88 yaratık, bkz. yaratık sayısı (l)). BÜTÇELER (hepsi sadece kozmetik, hasar/etki düğümlere bağlı değil): `fx_enchant_sprite.gd MAX_ONESHOT` 40 (aynı anda canlı tek seferlik efsun efekti; sürekli/anahtarlı/döngülü/silaha yapışık efektler dışında;
   `enchant_fx.gd play()` bütçe doluyken yerelde doğurmaz VE ağa yollamaz), `atmosphere.gd MAX_GLOWS` 96 (dolunca yeni GEÇİCİ efekt ışık almaz, kalıcı oyuncu/silah ışıkları zaten erken girer), `projectile.gd _play_impact_sound` en çok 25 ms'de bir (`NetworkManager.should_throttle`). Test: `test_fx_budget` (2). SONRA (aynı harness: gerçek Main + gerçek renderer, E açık, 5 silah): 250 yaratıkta E kapalı 8,3 ms (120 fps) / E açık 11,2 ms (90 fps, en kötü 19,7 ms; eskiden 25 ms = 40 fps ve 50-60 ms takılma), yeni tavan olan 100 yaratıkta E açık 6,3 ms (158 fps, en kötü 15,6 ms); doğan düğüm 900/sn -> 464/sn. Geliştirme makinesinde ölçüldü, kullanıcının donanımında DEĞİL.
   (j) **Şovalye koruma baloncuğu (R)** yaratık büyülerini DIŞARIDA tutar (kullanıcı: "kalkanın içine yaratıkların bazı büyüleri girebiliyor"): menzilli mermiler zaten sınırda yok oluyordu; EKSİK olanlar `enemy_abilities.gd`'de: `dome_owner_at`/`clip_ray_to_domes`, `deal_special_damage` içerideki hedefe HİÇ işlemez, merkezi baloncuğun içinde kalan yer efektleri (`DOME_BLOCKED_FX_KINDS`: diken, asit, Wendigo sarmaşığı/kayası, kabak patlaması)
   doğmaz (`spawn_world_fx` + `_broadcast_world_fx`: host ve istemci kopyası), lazer baloncuk sınırında biter, vampir ışınlanması baloncuğun `DOME_BLINK_MARGIN` (30 px) DIŞINA iner, Banshee çığlık şeritleri kısalır. Yeni bir yaratık büyüsü/alan efekti eklersen hasar `deal_special_damage` yolundan, yer efekti `spawn_world_fx` yolundan geçsin (baloncuk kuralı otomatik uygulanır). Test: `test_sovalye_dome_blocks_creature_spells` (5).
   (k) **Kalkan geliştirmesi 1 silah parçacığı ister** (kullanıcı: "bundan sonra silah 1 parçası gerekmeli"): `weapon_shop_logic.gd SHARD_COST_UPGRADE` 0 -> 1 (kalkan TÜRÜ hâlâ parçacıksız 250 altın; silah 10 parçacık; efsun geliştirmeleri `WUPGRADE_*` 5/10 parçacık). Test: `test_weapon_shop` (23).
   (l) **Yaratık tavanı ve gücü** (kullanıcı: "maksimum yaratık sayısını 100'e düşür oyuncu başına 20 artsın; hasar ve can/kalkan %50 artsın"): `enemy_spawner.gd max_concurrent_enemies` 250 -> 100, `ENEMY_CAP_PER_EXTRA_PLAYER` 50 -> 20 (Kademe 15 tavanı 1 oyuncu 100, 2: 120, 3: 140...);
   **AYNI GÜN 2. TUR (kullanıcı: "maksimum yaratık sayısını 150 yapıp oyuncu başına 30 artması ile değiştir"): 150 / +30 (1 oyuncu 150, 2: 180, 3: 210, 5: 270); `test_tier_pacing` sabitler. (i)'deki FPS ölçümleri 100 tavanla alınmıştı - 150'de Talon E açıkken kare süresi 100 ile 250 ölçümlerinin arasında beklenir (ölçülmedi);** `CREATURE_STAT_BOOST` 1,5 `_apply_global_buff`'ta
   SIRADAN yaratıkların (elitler dahil) can, `item_shield_max` ve temas/menzilli hasarına (bosslar `FIXED_BOSS_STATS` ile global zinciri atlar, boss ödülü değişmedi). Testlerdeki sayılar buna göre güncellendi (tier_pacing, spawner kapı/pusu, elit havuzu, endless, abilities...).
   (m) **Şovalye bekleme süreleri %10 kısa** (kullanıcı): Q Kalkan Yenileme + Kışkırtma (id 45) 25 -> 22,5 (`SKILL_TIMING[45]` + `SOVALYE_KALKAN_YENILEME_COOLDOWN`), E Koruma Bariyeri (id 29) 60 -> 54 (`SKILL2_TIMING[29]`), R Koruma Baloncuğu (id 11) 120 -> 108 (`SKILL3_TIMING[11]`; eski `SKILL_TIMING[11]` kaydı da aynı); `characters.gd` metinleri 22,5 / 54 / 108 sn.
   Çözülmeyen soru: önceki turdan kalan "tepelerin üstünde oyuncu görünüyor" geri bildirimi (3 açıklayıcı soru) cevaplanmadı. Yeni araçlar: `tools/mp_audit/eos_connect_probe.gd`, `eos_migration_probe.gd` (+ `run_eos_*.ps1`: Epic P2P bağlantı süresi ölçümü, `Pause=1 Always=0/1` düzeltmenin kanıtı).
   TEST DURUMU (2026-10-10, bu partinin sonunda): tam paket `run_tests.ps1` = 133 dosya / 1018 test, hata YOK (ilk koşuda 7 hata çıkmıştı: 5'i yeni sayıların güncellenmesi - CREATURE_STAT_BOOST x1,5, kademe süresi 150, Vampir R %4; 2'si ESKİDEN BERİ rastgele düşen testlerdi ve kalıcı düzeltildi: `test_weapon_frozen_targeting` (silahın saldırı merkezi ilk karelerde ~146 px yukarı oturup +-4 px süzülüyor, menzil 151 px: yaratıklar silahın GERÇEK merkezine göre konur; ayrıca doğrudan `is_frozen` yazılan yaratık `_freeze_timer` yokken ilk fizik tikinde çözülür) ve `test_endless_mode::..._tier_15_roster` (elit ELİT HAVUZUNDAN gelir, roster'da olması gerekmez)). Yeni sabitleri sabitleyen test: `test_tier_pacing::test_tier_duration_curves_player_cap_and_stat_boost_stay_in_sync` (mutasyonla denendi).

63. **Saklanma çalılığı: LoL tarzı, kare kare boyanmış bütün çalılık (2026-10-10).** Kullanıcı sırasıyla: "toplu yerleştirilmiş, animasyonları doğal durmuyor; tek tek kare kare yerleştirilsin"
   -> (önce 598 ayrık tek karelik çalı denendi: "ayrık ayrık oldu, saklanmaya uygun bütünlük yok; görünüşü oyunla uyuşmuyor") -> "league of legends tarzı olmalı" + "içine girip saklanabilmemiz ve
   vücudumuzun uyum sağlaması için kare kare eklenmiş çalılar". SON HÂL: `harita/saklanma_calilik.png` 256x64 = 64 karo (`tools/hide_bush_proto/gen_lol_brush.py`): her karo sıkı uzun ot (K1 dili:
   haritanın ot tonları + açık gizemli ot, uçları mor/mavi, koyu opak dolgu); iç karolar yatay+dikey SARMAL çizilir -> yan yana DİKİŞSİZ birleşir. Atlas düzeni: SÜTUN = kenar maskesi
   (1 üst açık, 2 alt açık, 4 sol açık, 8 sağ açık; 0 = iç karo), SATIR = çeşit (4). Tiled'da elle boyarken iç karo = sütun 0, kenarlar ilgili sütun.
   `place_lol.py`: alan = tek karelik denemeden ÖNCEKİ 29 çalılığın 1186 hücresi (`harita/yedek/Harita_2026-10-10_oncesi_tek-hucre-calilik.tmx.bak`; yol/duvar/su/ağaç testlerinden geçmiş), HER hücre dolar,
   karo = komşulara göre kenar maskesi + rastgele çeşit (sol/üst komşuyla aynı değil); `--apply <md5>` Harita.tmx md5 kapılı, yedekler `harita/yedek/*oncesi_lol-calilik*`. Pişmiş harita: `patch_baked_single.py lol_hucreler.json 4`
   (tam bake DEĞİL: sadece çalılık atlas karo listesi + katmanın tile_map_data'sı, TMX ile aynı hücreler); yeni PNG için `--headless --import`. (`place_single.py`/`gen_single_bush.py` = terk edilen tek karelik deneme; place_lol yardımcılarını kullanır.)
   KOD (`hide_brush_visual.gd`): küme yok, HER HÜCRE kendi parçası (kendi kökü -> içerideki karakterin bacakları altındaki sıraların otlarının arkasında kalır; kendi hışırtısı); eğilen yaprak karo kenarından
   taşınca komşu karonun pikseli okunur (komsu_veri artık grup sınırı aramaz) -> hışırtıda dikiş yok. Hışırtı sadece karakterin çevresinde (`RUSTLE_RADIUS` 26, `RUSTLE_BEND` 3, `LEAN_BEND` 1,4, `BEND_LIMIT` 5);
   rüzgarla kendiliğinden sallanma KAPALI (`AMBIENT_STRENGTH` 0). Saklanma kuralı hücre tabanlı (`HideBrush.contains`): çalılık bütün olduğu için içinde yürürken örtü kesilmez. Gerçek renderer ekran görüntüsüyle
   bakıldı (bütün, dikişsiz çalılık; içerideki karakterin bacakları otların arasında); oyunda elle denenmedi. Testler: `test_hide_brush_visual` (7), `test_hide_brush`, `test_depth_occluders`, harita çarpışma/yol bulma testleri geçti.
   **RENK (2026-10-10, kullanıcı: "çok koyu yeşil, oyunla uyumsuz" -> 4 prototipten "D" seçildi):** atlas artık `tools/hide_bush_proto/gen_lol_variants.py` PROTOS["d"] "Çiçekli Çalı" (orta yeşil dolgu ~86,132,54, haritanın çim tonları,
   %12 beyaz/pembe/sarı çiçek ucu; eski dolgu ~35,70,30 idi). Karo düzeni AYNI (64 karo, kenar maskesi) -> sadece `harita/saklanma_calilik.png` değişti, TMX/bake/kod değişmedi. Atlası yeniden üretmek = `gen_lol_variants.py` -> `out/lol_proto_d.png`'yi
   `harita/saklanma_calilik.png` üzerine kopyala + `--headless --import` (`gen_lol_brush.py` artık ESKİ koyu sürümü üretir). Eski atlas: `harita/yedek/saklanma_calilik_2026-10-10_oncesi_proto-d.png.bak`. Gerçek renderer'da haritada bakıldı.

64. **Denge turu: kalkan delme, can yenilenmesi kartı, Tabanca/Yay, Minotaur boynuzu, Havai Fişek, Buz Asası (2026-10-10).**
   (a) KALKAN DELME: bir isabetteki toplam delme (silah + eşya + Ruhani "Adc" + efsun) en çok %40: `weapon.gd SHIELD_PEN_CAP` + `cap_shield_pen` (iki atış yolunda: ışın tiki ve normal atış); gerçek hasar
   silahı (Tüftüf `always_true_damage`) istisna (1,0). Level atlama "Kalkan Delme" kartı havuzdan çıktı (`level_up_screen.gd UPGRADES`; player.gd dalı eski kayıtlar için duruyor).
   (b) CAN YENİLENMESİ KARTI: kademe 1-4 = 2 / 4 / 6 / 8 (`TierSystem.regen_card_for_tier`, kart yazısı + player.gd aynı kaynaktan; eskiden 2 x paylaşılan x1,3 eğrisi).
   (c) TABANCA saldırı gücü oranı 0,891 -> 1,15 (`weapon_tabanca.tscn`; saniyedeki AP oranı Arbalet'in 1,37'sinin altında ~1,22), YAY saldırı hızı +%20 (`weapon_yay.tscn fire_rate` 0,7844 -> 0,6537; weapon.gd
   _ready'deki yay /0,85'i aynen). `weapon_catalog.gd` metinleri güncellendi.
   (d) MİNOTAUR BOYNUZU: "alanın dışından vuruyor, sıyrılamıyoruz" - iki kök neden: hücum yön kilitlendikten sonra ilk 0,35 sn oyuncuya 45 derece/sn KIVRILIYORDU (çizilen şeritten sapıyordu) ve isabet oyuncu KÖKÜ
   + tüm gövde yarıçapıyla ölçülüyordu (şeridin ~12 px dışı vuruluyordu). Şimdi `minotaur_math.gd HORN_HOMING_DEG` 0 (çizilen şerit = gerçek yol), isabet = oyuncunun AYAK noktası (`FEET_OFFSET`) şeridin
   yarı genişliği + `HIT_MARGIN` (3 px) içinde mi. Boynuz hücumu ve boğa koşusu isabet hasarı x1,3 (`HORN_DAMAGE_MULT`, normal temas vuruşu aynı: 100 -> 130). Test: `test_minotaur_boss` (24; şeridin 3 px dışına kaçan vurulmaz).
   (e) HAVAİ FİŞEK patlama yarıçapı 66 -> 79,2 (`firework_projectile.gd splash_radius`), patlama efekti aynı oranda büyür (`FX_BASE_RADIUS`; efsun alan çarpanıyla da ölçeklenir).
   (f) BUZ ASASI "hiç dondurmuyor": Kırık Buz dondurma sayacı DÜŞMAN başınaydı ama asa hedeflerini bilerek farklı donmamış düşmanlara dağıtıyor -> aynı düşman 3 kez neredeyse hiç vurulmuyordu. Yeni anahtar
   `freeze_count_global` (`enchant_behavior.gd _generic_hit`): sayaç silaha bağlı. Kırık Buz tabanı: asanın her 2. isabeti 1,5 sn dondurur (eskiden her 3.), parçalanma %120 / 100 birim (eskiden %100 / 90),
   "Çabuk Don" = her isabet, Keskin Kırıklar %160, Geniş Parçalanma 130. Testler: `test_weapon_traits` (+1: farklı düşmanlara giden isabetlerin her 2.'si dondurur), `test_health_regen_card` (+2: 2/4/6/8, %40 tavan + kart yok).
   Oyunda elle denenmedi.

65. **Yeraltı Canavarı çatlakları SPRITE oldu (FPS) + Ateş Asası buff (2026-10-10).** Kullanıcı: "çatlaklar zeminle uyumsuz, yeniden tasarla; çatlaklar olduğunda fps inanılmaz düştü" + "ateş asası aşırı güçsüz".
   (a) KÖK NEDEN: `underground_cracks.gd` görüntüdeki ~100 hücrenin yüzlerce çatlağını HER KAREDE `_draw()` ile (çokgen/çizgi/daire, nokta başına harita sınırı sorgusu) yeniden çiziyordu; uzuv çıkış yıldızları 19 sn yaşadığı için
   bu neredeyse sürekliydi. Ölçüm (gerçek renderer, gerçek harita, vsync kapalı, aynı sahne): eski ~116 ms/kare (p95 213), yeni ~2,3 ms/kare. Artık `tools/gen_underground_cracks.py` -> `assets/fx/underground_cracks/cracks.png`
   (64 px, 4 büyüme karesi x 8 çeşit) + `bursts.png` (48 px, 4 kare x 4 çeşit, ortada uzvun çıktığı çukur); görsel dil haritanın kendi çatlak-toprak karolarıyla aynı: ince koyu-kahve yarık, güneyde duvar gölgesi, kuzeyde yırtık çim
   dudağı, kırıntı (eski kalın siyah çizgiler kalktı). Düğüm hücre başına 1-2 `Sprite2D` (havuzlu; görüntüden çıkan hücre havuza döner), bölge yalnız büyüme karesi DEĞİŞİNCE yazılır, solma + gümbürtü koyulaşması tek `modulate`. `_draw()` YOK -
   yeni bir sürekli zemin efekti yazarsan aynı deseni izle (her karede yüzlerce draw_* çağrısı = FPS çöküşü). `cluster_for` artık `"decals"` döndürür (`"cracks"/"chips"` geometrisi sadece veri/test için). Test: `test_underground_boss` (+1, 25).
   (b) ATEŞ ASASI: tek hasar kaynağı doğuştan Destiny püskürtmesi (mermi atmaz). `enchant_defs.gd destiny` tabanı: `spray_ap` 0,15 -> 0,27 / 0,25 sn (saniyede %60 -> %108 saldırı gücü, konideki HERKESE), `spray_range` 110 -> 140
   (`destiny.gd` varsayılanı da), yanma `elem_ap` 0,08 -> 0,14; "Genişleyen Boğaz" +16,5 -> +21 menzil. Karşılaştırma: Tabanca ~%128/sn tek hedef menzil 210, Yay ~%98/sn menzil 266 - asa alan + kısa menzil olduğu için tek hedefte
   onlara yakın. Katalog metni (`weapon_catalog.gd`, eskiden yanlıştı: "13 + %100 · Patlayıcı mermi") düzeltildi. Test: `test_weapon_traits` (+1). Oyunda elle denenmedi; daha fazla gerekirse `spray_ap`.
   (c) **SİLAH DENGE TURU 2 (2026-10-10, kullanıcı "zayıf/güçlü silah var mı, hesapla" -> önerilerim kabul + "yıldırımın sekme menzilini de kısalt").** Ölçü: saniyede saldırı gücü yüzdesi (oran / atış aralığı + doğuştan efsun tabanı;
   kritik/kart/geliştirme hariç). Önce: Arbalet 1,37 tek hedef + delme + sersemletme, Tüfek 1,23 + 3 delme ve delişte +%10 (sırada ~3,9), Yıldırım 1,25 + 2 sekme %50 (~2,5); zayıflar Buz 0,63, Arcane ~0,83, Tüftüf ~0,88 (menzil 128),
   Pençe ~0,88, Bıçak ~0,9, Fişek ~0,65. DEĞİŞENLER: Arbalet `fire_rate` 0,7222 -> 0,8; Tüfek `delici_mermi` tabanı `pierce_ramp` 0,10 -> 0 (artış artık "Kinetik Enerji" geliştirmesinde: +%10); Yıldırım `zincir_yildirim` tabanı
   `chain_pct` 0,5 -> 0,35 ve `chain_range` 1,0 -> 0,75 (220 -> 165 birim; "Geniş Zincir" +0,3 -> 231, "Güçlü Atlayış" %35 -> %50; weapon.gd `CHAIN_JUMP_RANGE` 220 DEĞİŞMEDİ - başka sekme kaynakları da kullanır); Buz Asası oranı 0,693 -> 0,9;
   Arcane 0,99 -> 1,25; Tüftüf sahne menzili 142,8 -> 166,7 (oyunda x0,9 = 150); Bıçak 0,765 -> 0,88; Pençe 0,9 -> 1,035; Fişek `fire_rate` 3,72 -> 3,2. DOKUNULMAYAN: Kılıç (nerf sonrası makul), Bumerang (tahmini güçlü ama ölçülmedi),
   Tüftüf'ün gerçek hasarı (boss kalkanını tam deler - bilinçli). `weapon_catalog.gd` açıklamaları düzeltildi (eski "N + %X" metinleri yanlıştı). Testler: `test_weapon_traits` (zincir %35 / x0,75, tüfek tabanda artış yok). Oyunda elle denenmedi.
   (d) **KAMERA %12,5 YAKIN (2026-10-10, kullanıcı: "%15 kadar yaklaştır ama harita/oyuncu glitchli olmasın").** `player.gd DESKTOP_CAMERA_CLOSER` 1,125 -> masaüstü zoom 2,0 -> 2,25 (telefon AYNI: `_ready` mobilde çarpmaz,
   `MobileUI.CAMERA_CLOSER` 2,0 tabanından 3,25). NEDEN 2,25 (2,3 değil): proje tam ekran (window/size/mode 3), tuval 1920x1080 -> kullanıcının 2560x1440 ekranına x4/3 ölçeklenir; harita pikseli ekranda zoom x 4/3 px kaplar:
   2,25 = tam 3 px (keskin, kaydırırken dalgalanma yok), 2,3 = 3,07 px (her ~15 pikselde bir 4 px sütun), eski 2,0 = 2,67 px. Ölçüm (gerçek renderer, 2560x1440, alt piksel kaydırma): karo dikişi/boşluk pikseli 0 (2,0/2,25/2,3 hepsi);
   satır içi aynı-renk koşularının 3'ün katı olmayan oranı 2,0: %27, **2,25: %11**, 2,3: %27. 1080p ekranda 2,25 px (eskisi tam 2) olur - başka bir ekranda keskinlik bozulursa zoom'u ekran/tuval oranından türetmek gerekir. Görüş alanı %11 küçüldü
   (doğuş/sis/LOD dünya birimiyle çalışır, etkilenmez). Testler: `test_camera_shake`, `test_vision_fog` geçti. Oyunda elle denenmedi.

66. **Toplu istek: Kalkan Bağı, Şovalye E, parçacık, şans/kart kademesi, Tank, Yansıtan Kubbe, Elara, Minotaur (2026-10-10).**
   (a) **KALKAN BAĞI (ruhani) ÇALIŞMIYORDU - KÖK NEDEN:** kalkanın ana kaynağı olan doğal yenilenme `player.gd _process_shield_regen_tick`'ten geçiyor ama
   `_kalkan_bagi_mirror` çağırmıyordu (yalnız `heal_shield` yansıyordu) -> bağ pratikte sadece HASARI paylaşıyordu (partnerin kalkanını düşürüyordu). Artık regen tiki de yansır;
   bağdan gelen kalkan mavi sayıyla görünür (`receive_kalkan_bagi_shield_delta` -> `show_received_shield_number`). KANIT (`run_audit.ps1 -Mode bond`, iki gerçek süreç, host'un
   kendi yenilenmesi kapalı): düzeltmeyle host bağdan +318 kalkan aldı, satır geçici kapatılınca +25 (sadece bağın %0,5/sn'si).
   (b) **ŞOVALYE E (Koruma Bariyeri, id 29) DOSTUN HASARINI EMMİYORDU - KÖK NEDEN:** aktarım dostun `take_damage`'ında KALKAN hasarı emdikten SONRA, sadece cana giden kısımdan
   yapılıyordu (kalkanı olan dosta hiç işlemiyordu) + Şovalye tarafında aktarılan hasar temas kilidine (CONTACT_DAMAGE_IFRAME_MS) takılıp yutuluyordu. Artık aktarım kalkandan
   ÖNCE gelen hasarın tamamından (`remaining`'in hemen üstü), Şovalye `take_redirected_damage` ile alır (kilit/sıyrılma yok). KANIT (aynı denetim): kalkanı DOLU dost 100 hasardan
   70 kaybetti, Şovalye 28,5 aldı (kendi kalkan soğurmasıyla). Bariyerden geçen hasar yine Şovalye'nin kalkanı/azaltmalarından geçer.
   (c) Silah parçacığı sıradan yaratıktan %0,5 -> **%1,5** (`enemy.gd WEAPON_SHARD_CHANCE`; şansla çarpılır). (d) **ŞANS + KART KADEMESİ** (kullanıcı: "şans pek işlevsel değil,
   şanssız oyuncu hep kademe 1 görüyor"): `tier_system.gd WEIGHTS` 55/24/8/2 -> 50/32/14/4; şans artık üst kademeleri ÜSTEL büyütür (Nadir x m, Epik x m², Efsanevi x m³, m = 1 + şans x 0,04;
   eskiden hepsi x(1 + şans x 0,015)): kart başına Sıradan/Nadir/Epik/Efsanevi şans 0 = %50/32/14/4, 10 = %38/34/21/8, 20 = %28/33/26/13. Aynı zar sandık eşyası ve seyyar satıcıda da.
   (e) Ruhani **Tank** yansıtma %60 -> **%200** (`spiritual_skills.gd TANK_REFLECT` 2,0). (f) Şovalye R evrimi **"Yansıtan Kubbe"**: kalkana vuran yaratık artık Şovalye'nin AZAMİ kalkanının
   %10'u kadar hasar alır (`EVO_SOVALYE_R_REFLECT` 0,10 x `item_shield_max`; eskiden vurduğu hasarın %50'si) - "kalkanının %10'u" AZAMİ kalkan olarak yorumlandı. (g) **Elara** E (Gerçek Hasar,
   SKILL2_TIMING[11]) 25 -> 20 sn, R (Çift Tetik, SKILL3_TIMING[31]) 120 -> 100 sn. (h) **Minotaur** boynuz şeridi 76 -> 86 (`minotaur_math.gd LANE_WIDTH`; görsel uyarı şeridi aynı sayıdan);
   hücum başlarken (`_apply_minotaur_pose` POSE_CHARGE, `CHARGE_SHAKE` 0,32) ve isabet/duvar çarpmasında (`"minotaur_impact"`, `IMPACT_SHAKE` 0,5) HER peer'in kamerası uzaklıktan bağımsız sarsılır
   (ikisi de zaten herkese yayınlanan olaylar; yakındakine toz patlaması ayrıca `add_at` ekler; sarsıntı ayarı 0 ise yok). Testler: `test_spiritual_skills_and_rewards` (Tank %200), `test_weapon_shards`
   (%1,5), `test_minotaur_boss`, `test_camera_shake`. Oyunda elle oynanarak denenmedi (Kalkan Bağı/Şovalye E iki süreçli denetimle doğrulandı).

67. **Toplu istek 2 (2026-10-10): Yeraltı Canavarı, çalılık görünümü, kamera iptali, derinlik, görev ödülü, diriltme.**
   (a) Yeraltı Canavarı hasarı %40 az: `worm_boss_math.gd LASH_DAMAGE` 130 -> 78, `ACID_DAMAGE` 110 -> 66; sarsıntı daha seyrek/hafif: gümbürtü 3-6 -> 6-10 sn (`RUMBLE_MIN/MAX`), gümbürtü
   sarsıntısı 0,4 -> 0,25 (`underground_boss.gd`), sürekli deprem tabanı `underground_cracks.gd QUAKE_FLOOR` 0,24 -> 0,12, uzuv savurma tozu 0,2 -> 0,1 (`worm_limb.gd`).
   (b) **Kamera yakınlaştırması İPTAL** (madde 65d geri alındı): `player.gd DESKTOP_CAMERA_CLOSER` 1,0 (zoom yine 2,0; çarpan yerinde).
   (c) **SAKLANMA ÇALILIĞI DOĞAL KENAR + UZUN OT** (kullanıcı: "köşeleri çok keskin, blok oyunlarına benziyor" + "otlar kısa, karakter saklanmış görünmüyor"): atlas artık
   `tools/hide_bush_proto/gen_lol_variants.py` `NATURAL` ("E · Doğal Kenar"; D renkleri) -> `out/lol_proto_e.png` -> `harita/saklanma_calilik.png` (karo düzeni AYNI, TMX/bake/kod değişmedi; eski atlas
   `harita/yedek/saklanma_calilik_2026-10-10_oncesi_dogal-kenar.png.bak`). Açık kenarın sınırı karo uçlarında sabit derinlikte (komşu kenar karolarıyla dikişsiz), ortada kavisli kabarma; iki yanı açık köşeler
   12 px yarıçapla yuvarlanır; koyu dolgu sınırın 2 px içinde biter, silüeti yapraklar çizer, üst kenarda uçlar 8 px'e kadar dışarı taşar; yapraklar 9-15 px (eskiden 5-10,5). İç karolarda yaprak dipleri tüm
   yüksekliğe yayılır + çizim sırası karışık (eskiden dipler karonun altında toplanıp her 16 px'te yatay BANT çiziyordu). İçerideki karakter: yapraklar gövdenin alt %75'ini (`saklanma_calilik.gdshader ICERDE_ORTU_ORANI`
   0,5 -> 0,75) `INSIDE_FOLIAGE_ALPHA` 0,65 (0,5) opaklıkla örter. ÇOKLU KARAKTER HATASI: shader `orter()` piksel HERHANGİ bir karakterin önündeyse hemen "çizme" diyordu -> iki karakterin dikdörtgeni
   binince öndekinin dikdörtgeni arkadakinin bacak örtüsünü dikdörtgen biçiminde deliyordu; artık pikseli içeren varlıklardan ayağı EN AŞAĞIDA olan karar verir. Gerçek Main + gerçek renderer görüntüsüyle bakıldı.
   (d) **DERİNLİK: KARAKTERİN GERÇEK BOYU** (kullanıcı: "Assasin'in saçı ağaçların arkasında görünmüyor"): ön kopya katmanları her oyuncuya sabit 29 px boy veriyordu (uzun saç/şapka dışarıda kalıp ağacın önünde
   çiziliyordu). `depth_occluders.gd character_extent(n)`: karakterin AnimatedSprite2D'sinin geçerli animasyonunun ilk karesinin opak alanının tepesinden ölçer (animasyon başına meta önbelleği, en az eski sabit,
   en çok 2,2 katı; ölçülen ~47 px) - ağaç/bina/çalı/köprü kopyalarının hepsi bunu kullanır (`collect_characters`, köprü listesi). Gerçek Main'de Assasin ağaç arkasında saçı dahil örtüldü (görüntü).
   (e) **Görev ödülü**: elit sandık yerine yaşayan HER oyuncuya 5 silah parçacığı (`world_event_manager.gd MISSION_SHARD_REWARD`, `_grant_shards_to_all_players` -> host'ta `host_award_weapon_shards`); "Görev Tamamlandı"
   penceresi "+5 Silah Parçacığı" gösterir. Eski `_grant_chest_to_all_players` duruyor (kullanılmıyor).
   (f) **Diriltme %50**: `player.gd REVIVE_RESTORE_RATIO` 0,5 - arkadaş diriltmesi (`_complete_revive`) VE dükkan/kalıcı ölümden diriltme (`revive_from_permadeath`) can + kalkanı azaminin yarısıyla başlatır.
   **Diriltme kalpleri** (`fx_revive_heart`): animasyon zaten oynuyordu ama kalp 50 px karede ~14 px'ti ve -165'te (karakterler küçüldükten sonra can çubuğunun ~65 px üstünde) seçilmiyordu -> -88 + x1,75 (çubuğun hemen
   üstü; uzak kopyada isim yazısının üstünde `remote_player.gd REMOTE_HEART_Y` -142); tetik artık ölü YA DA yerde yatan -> canlı geçişi (kalıcı ölümden dönüşte de çıkar). **Diriltme saati** (`fx_revive_rewind.gd`):
   ölçek 0,5 -> `OverheadBar.WIDTH / CLOCK_CONTENT_PX` (44/60) = can/kalkan barı genişliği. Gerçek renderer görüntüleriyle bakıldı. Oyunda elle oynanarak denenmedi.

68. **Toplu istek 3 (2026-10-10): yeni görev ağacı, ağaç/konvoy çarpışma + derinlik, konvoy hızı, grup barları, minimap, çalıdan saldırı, Shaman kalkanı.**
   (a) **GÖREV AĞACI YENİ SANAT** (kullanıcının masaüstü "görev agaç" klasörü): `tools/import_mission_tree.py` -> `assets/fx/mission_tree/` (`tree_active.png` 6 x 160 döngü; büyüme sayfası
   TERS sıralı ve 94 px ızgaraya oturmuyordu -> boş sütunlardan ayrılıp küçükten büyüğe dizilir, gövde dipleri aktif ağaçla hizalanır: `tree_grow_aligned.png` 3 x 160; kaynak
   `tree_grow_source.png`). `mission_tree.gd` yeniden yazıldı: görev başında büyüme (2,5 fps, ~1,2 sn) sonra aktif döngü (7 fps), ölçek 0,7 (~105 px), gövde dibi düğüm konumunda
   (`SHEET_BASE` 87,153). KRİSTAL: aktif hâlde 0,8 sn'de bir 300 px içindeki en yakın yaratığa `mission_tree_bolt.gd` (güdümlü mavi kristal parçası, kodla piksel çizim, gece parıltısı)
   - HER istemcide yerel doğar (aynı hedef kuralı), hasarı SADECE host kopyası işler (eski `projectile.tscn` istemcide hiç görünmüyordu). KADEMEYE UYUM: görev başında host yaşayan
   SIRADAN yaratıkların (boss/minyon/bekçi hariç, en çok 60) ortalama azami canını ve temas hasarını ölçer: can = ort. hasar x 70, kalkan = x 22 (x oyuncu çarpanı 1 + 0,3/ek oyuncu;
   ~6 yaratık birlikte vururken ~10-12 sn dayanır), kristal vuruşu = ort. yaratık canının %34'ü (sıradan yaratık ~3 atış); yaratık yoksa eski 3000/800/35. Sayılar dosya başında
   (`HP_PER_ENEMY_HIT`, `SHIELD_PER_ENEMY_HIT`, `BOLT_HP_RATIO`, `ATTACK_*`). Oyunda denge için oynanarak bakılmadı.
   (b) **ÇARPIŞMA + DERİNLİK (ağaç VE konvoy arabası)**: yeni sözleşme "move_blockers" grubu = `block_center()` + `block_radius` (ağaç gövdesi 15 px, araba 20 px); `player.gd
   _block_movement_into_blockers` (her fizik karesi, `_block_movement_into_enemies`'in hemen ardından) içine doğru hız bileşenini iptal eder (uzaklaşmak serbest). Yaratıklar bu engeli
   bilmez (ağaca zaten saldırmaya gelirler). Derinlik: herhangi bir oyuncu (yerel/uzak) kökün arkasında ve genişlik içindeyse sprite z 2 (oyuncunun üstü), değilse 0
   (`mission_tree.gd/_update_depth`, `mission_van.gd/_update_depth`). Yeni bir görev nesnesi eklersen aynı grubu/kancaları ver.
   (c) **KONVOY HIZI**: oyuncu sayısına bağlıydı ama ek iten oyuncu başına +%15 fark edilmiyordu -> `ESCORT_SPEED_PER_EXTRA_PLAYER` 0,35, `ESCORT_MAX_SPEED_MULT` 2,05 (1 oyuncu x1, 2: x1,35, 3: x1,7, 4: x2,05).
   (d) **GRUP PANELİ BARLARI**: 9 parçalı görev çubuğu dokusu (TextureProgressBar) yerine `scripts/party_pixel_bar.gd` = karakter üstü çubukla AYNI çizim (`overhead_bar.gd draw_pixel_bar`),
   can 30 / kalkan 27 px yükseklik, gömme panel kalktı; sayı yine `bar_value_label.gd`. Arayüz uyumlu (`value`, `tint_progress`). Gerçek renderer görüntüsüyle bakıldı.
   (e) **MİNİMAP**: demircinin kapısı (`weapon_shop.gd get_exterior_anchor_pos`) örs simgesiyle, dairenin dışındaysa kenarda yön göstergesi olarak; dostlar büyük portre + parlak turkuaz
   halka (`COLOR_ALLY_RING`) + koyu taban, dairenin dışındaki dost için kenarda dışa bakan ok. Gerçek Main görüntüsüyle bakıldı.
   (f) **ÇALIDAN SALDIRI**: silahın sahibi saklanma çalılığındaysa SADECE ayağı çalılıkta olan yaratıklar hedeflenir (`weapon.gd _can_target` = sis görünürlüğü + çalı kuralı; silahın tüm
   hedef dalları + Ateş Asası püskürtmesi `destiny.gd _pick_target`). Yetenekler (Q/E/R) bu kurala tabi DEĞİL. Test: `test_brush_targeting`.
   (g) **SHAMAN Kalkan Totemi** saldırı gücü oranı %12 -> %7 (`totem_shield.gd ATTACK_POWER_RATIO`; kendi kalkanının %0,5'i aynı). Testler: `test_mission_tree` (6), `test_totem_shield_wave_v2`.

69. **Toplu istek 4 (2026-10-10): yeni eşyalar, 3 satırlı satıcı, sıvışma sınırı, Melek işareti, Talon zinciri, Elara titremesi, silah seçimi, dükkan ışınlanması.**
   (a) **YENİ EŞYALAR** (kullanıcının masaüstü "Yeni eşyalar.txt"i; soru-cevapla: TARİFSİZ düz fiyat, fiyatlar benim seçimim): epik `savasci_bileyi` (800; +15 AP, AP %5) ve efsanevi
   `sifa_feneri` (2300; +250 can, +100 kalkan, %25 iyileştirme/kalkan gücü), `anka_muhru` (2450; +20 AP, +100 can; ölümcül darbede ANINDA %100 can+kalkanla dirilir, 1 sn dokunulmaz, 180 sn bekleme -
   `player.gd _item_after_health_damage`, `_item_anka_revive_cd`), `bilgenin_pusulasi` (2250; +150 can, %10 bekleme azaltma, %20 EXP, toplama menzili x2 = `item_pickup_range_percent` +1,0),
   `ruzgar_yuruyen_cizmeleri` (2400; +15 AP, %15 sald. hızı, %10 sıvışma, %5 hareket; sıvışma sınırı %50), `kanli_bicer` (2400; +25 AP, %10 can çalma, +%1 can emme = `item_extra_lifesteal`),
   `ahenk_bastiyonu` (2400; +250 kalkan, %8 kalkan soğurma = `shield_protection_bonus`, azami canın %30'u ek azami kalkan - `refresh_shield_stats`), `kiyamet_bicagi` (2600; +40 AP, AP %25).
   AP YÜZDESİ (`item_ap_percent`): `player.gd _refresh_item_ap_percent` her fizik karesinde yüzde payını `damage_bonus`'un İÇİNE yazar (taban = damage_bonus - önceki pay) - AP okuyan her yer
   (silah, yetenek, köpek) etkin değeri görür; kart/eşya/Savaş Şevki tabanı değiştirse de doğru kalır. İkonlar `tools/gen_item_icons_2.py` (gen_item_icons.py yardımcılarıyla, 32x32).
   (b) **SIVIŞMA SINIRI** (kullanıcı: "sınırı %40'a düşürüp çizmelerle %50 olabilsin"): `DODGE_CHANCE_CAP` 0,6 -> 0,4, `DODGE_CHANCE_CAP_BOOTS` 0,5 (`dodge_cap()`); ham `dodge_chance` artık eklenirken 1,0'da
   kırpılır, sınır KULLANIMDA (take_damage) uygulanır (eşyayla değişebildiği için). Yetenek sıvışması (Elara Q vb.) hâlâ sınırın üstüne biner.
   (c) **SATICI 3 SATIR** (kullanıcı: "1 satır daha, yeni satır komple efsanevi; üstü epik, diğeri parçalar"): `traveling_merchant.gd ROW_ITEMS` 4, `STOCK_SIZE/ITEM_STOCK` 12; stok sırası 4 parça -> 4 epik
   -> 4 efsanevi (kademe içinde eşit olasılık; `ITEM_TIER_WEIGHTS` artık kullanılmıyor), efsanevi SADECE son satırda. Ekran 4 sütun (pencere içerikten uzar); telefonda sütun 4 ya da 2'ye yuvarlanır ki satırlar karışmasın.
   (d) **MELEK PASİF İŞARETİ** (prototip A "Artı Işıltısı" seçildi; diğer prototipler - Talon ultisi, Şovalye baloncuğu - ERTELENDİ, `tools/proto_20261010/`): her 3. iyileştirme tikinde (3 sn) Melek'in
   ve menzildeki oyuncu müttefiklerinin başında `scripts/fx_melek_heal_sparkle.gd` (iki küçük yeşil-beyaz artı yükselip söner); diğer istemcilere `send_player_vfx "melek_sparkle"` (hedef peer listesi).
   (e) **TALON E ZİNCİRİ** (kullanıcı: "gerçek zincir gibi hafif kıvrılarak dönsün"): `fx_talon_chains.gd` zincir artık ikinci derece Bezier - silahın açısal hızına göre dönüşün TERSİNE geride kalan yay
   (`LAG_*`) + merkezden silaha akan dalga (`WAVE_*`); halkalar yay uzunluğuna göre eşit aralıklı, eğrinin yönüne dönük. Gerçek renderer görüntüsüyle bakıldı.
   (f) **ELARA ULTİSİ** (Çift Tetik) aktifken tüm menzilli silah ikonları titrer (`weapon.gd _apply_ult_tremor`; uzak kopya `remote_player.gd _update_beam_tremor` "elara_double" bayrağıyla; yakın dövüş hariç).
   (g) **SİLAH SEÇİMİ** (oyun başı): istatistik satırı yerine silahın doğuştan özelliği (`WeaponCatalog.trait_text` = efsun adı + açıklaması). (h) **DÜKKANA IŞINLANMA** (ruhani) artık hasar alırken
   bölünmez (sadece hareket böler). (i) **MATTHEW ANALİZİ** (değişiklik yok, öneri verildi): köpek her ısırıkta Matthew'in AP'sinin %100'üyle 5 hedefe vurur, Matthew'in saldırı hızı bonusuyla hızlanır ->
   kalabalıkta ~5 AP/sn (orta oyunda ~440 hasar/sn) = ~4 silah kadar ek alan hasarı. -> kullanıcı "en dengeli öneri"yi seçti: ısırık ANA hedefe (odaklanılan yaratık, yoksa en yakın) tam, alandaki diğer en çok 4 yaratığa %50 (`player_pet.gd FOX_SPLASH_RATIO`; yakın dövüş silahlarının alan kuralıyla aynı) - kalabalıkta 5x -> 3x (~%40 az), tek hedef aynı. Test: `test_matthew_dog`.
   Testler: `test_spiritual_skills_and_rewards` (satıcı satırları, dükkan hasarla bölünmez), `test_mission_tree`, `test_brush_targeting`. Oyunda elle denenmedi.

70. **BÜYÜCÜ BUFF (2026-10-10, kullanıcı: "büyücü çok güçsüz diye kimse oynamıyor, neden?" -> analizdeki önerilerin HEPSİ onaylandı).** Analiz (koddan, oynanmadı): ana hasar Arcane Lanet
   ~0,8 AP/sn (diğer karakterlerin kit katkısı ~3-5 AP/sn), her 4 sn'lik kullanım kalkan bedeli ödetiyordu (dakikada ~15 kez -> savunmayı eritir), Meteor 420 px dairede RASTGELE noktaya düşüyordu
   (yaratık başına ~0,3 isabet = ~0,4 AP; 5 sn hareketsiz, 120 sn bekleme), Don Nova %100 AP / 45 sn, pasif +%30 tek atış. DEĞİŞENLER (`player.gd`): Arcane Lanet (22) kalkan HARCAMAZ
   (`is_shield_related_skill2`); Meteor kanalı 5 -> 3 sn (`BUYUCU_METEOR_CHANNEL_TIME`, `SKILL2_TIMING[25]`), kanalda YÜRÜNEBİLİR (`BUYUCU_METEOR_CAN_MOVE`, meteorlar oyuncunun o anki konumunun çevresine),
   meteorların %80'i menzildeki rastgele bir YARATIĞIN üstüne (+-18 px) düşer (`BUYUCU_METEOR_AIM_CHANCE`), bekleme 120 -> 75 sn; Don Nova %100 -> %200 AP (`BUYUCU_NOVA_DAMAGE_RATIO`), 45 -> 35 sn;
   pasif ek atış +%30 -> +%60 (`BUYUCU_PASSIVE_SHOT_MULT`). Açıklamalar `characters.gd` + `_buyucu_variation_text`. Kanalda yürürken karakter odaklanma klibinde kayar (yürüme klibi yok) - oynanınca bakılmalı.
   "Yükseliş" evrimi (kanalda havada/hedef alınamaz) aynen çalışır. Oyunda elle denenmedi.

## Test/doğrulama

Yeni bir yetenek/efekt eklediğinde, TEK bilgisayarda iki pencere açıp
(host + client, ya da `Co-op.exe` ile ikinci bir istemci) yeteneği HOST
OLMAYAN oyuncuyla kullan ve diğer pencerede doğru göründüğünü kontrol et —
kendi ekranında (kaster tarafında) her zaman doğru görünür, gerçek test
DİĞER istemcide izlemektir.

## Kod değişikliği = exe'ye otomatik yansımaz (export ELLE/KOMUTLA yapılan ayrı bir adım)

Kullanıcı bildirimi (2026-09-16): kod dosyalarını düzelttikten sonra
kullanıcı oyunu exportlayıp oynadığında değişiklikler bazen hiç görünmüyordu
- "aynı eski sürümü oynamak gibi" hissi veriyordu. Kök neden KOD hatası
DEĞİLDİ: Godot'ta script/sahne dosyalarını değiştirmek exportlanmış .exe'yi
OTOMATİK güncellemiyor - export, o ANKİ proje durumunun ELLE/KOMUTLA alınan
bir "anlık görüntüsü". Masaüstünde kullanıcının test ettiği en az iki ayrı
.exe kopyası var:
- `../../Oynanabilir versiyon/I need to stay alive.exe` (export_presets.cfg
  "Windows Desktop" preset'inin gerçek export_path'i - tek oyunculu/genel
  test için kullanılan "asıl" build)
- Proje klasörünün İÇİNDE bir "Co-op (isim değişebilir).exe" - yukarıdaki
  "Test/doğrulama" bölümünün bahsettiği İKİNCİ multiplayer test istemcisi
  (aynı .exe'nin ikinci bir kopyası, host olmayan oyuncu rolünde açılıyor)

**DÜZELTME (kullanıcı bildirimi, aynı gün): "bundan sonra bir değişiklik
yaptığında... projeyi exportlamıyosundur umarım, ben sadece export ayarı
olarak projenin güncel halini exportlasın istedim, her seferinde ben
exportladığımda Godot'tan."** - yukarıdaki "her görev sonunda otomatik
export al" kuralı YANLIŞ anlaşılmıştı ve GERİ ALINDI. Claude BUNDAN SONRA
kod değiştirdikten sonra KENDİLİĞİNDEN export ALMAZ/exe'nin üzerine
YAZMAZ - export tamamen kullanıcının kendi kontrolünde, Godot editöründen
kendisi ne zaman isterse o zaman alır. Yukarıdaki export komutu/yol bilgisi
sadece REFERANS için burada duruyor (kullanıcı "export'u sen al" diye
AÇIKÇA isterse kullanılır) - varsayılan davranış DEĞİL. Kod bir görevi
bitirdiğinde kullanıcıya sadece "değişiklikler kaydedildi, test etmeden
önce Godot'tan yeniden export almayı unutma" gibi bir hatırlatma yeterli.

Ayrıca: kullanıcı Godot EDİTÖRÜNÜ projede AÇIK tutuyor olabilir. Bir .tscn
dosyasını editör dışından (metin olarak) düzenlersen ve o sahne editörde
AÇIKKA kalıp kullanıcı sonradan editörden "Kaydet"e basarsa, editördeki ESKİ
bellek içi hali senin değişikliğinin ÜZERİNE yazıp onu sessizce geri
alabilir - bu ihtimali unutma, şüpheli bir "değişiklik kayboldu" durumunda
bunu da sorgula.

## Proje artık paylaşılıyor: arkadaşla birlikte, ikisi de kendi Claude'uyla

Kullanıcı bildirimi (2026-09-17): GitHub'daki mieys/i-need-to-stay-alive
reposu bir arkadaşla (collaborator olarak) paylaşılıyor - o da kendi Claude
Code oturumundan bu projede değişiklik yapacak. Bilinçli tercih: branch/PR
akışı YOK, ikisi de DOĞRUDAN master'a push ediyor. Bu dosyayı okuyan HER
Claude oturumu (kullanıcının ya da arkadaşının) şunları uygulamalı:

1. **Bir göreve başlamadan ÖNCE `git fetch` + `git status` çalıştır, yerel
   değişiklik yoksa `git pull` ile çek.** Diğer kişi senin son
   baktığından beri push etmiş olabilir; onu çekmeden üstüne kod yazarsan
   ya push reddedilir ya da (daha kötüsü) onun değişikliğinin üzerine
   yazarsın. Bu adım salt-okunur/geri alınabilir (fast-forward) olduğu
   için ayrıca onay gerektirmez.
2. **Görev bitince commit edilmemiş değişiklik varsa kullanıcıya söyle ve
   push etmek isteyip istemediğini SOR** - otomatik commit/push YOK, genel
   kural budur (yalnızca kullanıcı açıkça isteyince commit/push et). Ama
   bu repo artık paylaşıldığı için bu hatırlatmayı ATLAMA: değişiklik push
   edilmeden diğer kişide GÖRÜNMEZ - "sürekli güncel kalma" beklentisi tam
   burada kırılıyor.
3. **Push reddedilirse ("! [rejected]" / "fetch first")** asla `--force`
   KULLANMA - diğer kişinin işini SİLEBİLİR. Bunun yerine `git pull`
   (merge) yap; gerçek bir çakışma çıkarsa kullanıcıya göster, kendi
   başına "kazananı" seçme.
4. **Binary asset dosyaları (`.png`, ses dosyaları, `.import`) git'te satır
   satır BİRLEŞTİRİLEMEZ** - iki taraf aynı asset'i aynı anda değiştirirse
   biri diğerini sessizce ezer, git bunu bir "conflict" olarak bile
   göstermeyebilir (sadece son push kazanır). `git pull` sonrası "both
   modified" bir binary dosya görürsen kullanıcıya sor, tahmin etme.
