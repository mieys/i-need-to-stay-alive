# CLAUDE.md maddeleri 1-10 (taşındı 2026-10-10; numaralar AYNI, başka dosyalardaki "madde N" atıfları geçerli)

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
