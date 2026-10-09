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
   prototip T1 "Ahşap Plaket"; `main.gd` `_boss_bar_top`, CanvasLayer 38): kamera merkezine en yakın canlı boss (histerezisli
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
   peer id'ye bağlı hiçbir durum taşınmaz. Koşu rekoru çift yazılmasın diye `GameManager.run_record_suppressed`. Tuzaklar: (1) Epic'te istek aday sunucuyu kurmadan gönderilirse ENet gibi yeniden
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
