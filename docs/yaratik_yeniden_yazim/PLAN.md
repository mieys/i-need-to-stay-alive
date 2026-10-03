# Yaratık sistemi yeniden yazımı - PLAN

> Bu dosya bu işin TEK planıdır. Hangi hesaptan / hangi Claude oturumundan açılırsa açılsın, işe başlamadan önce bunu ve
> `ILERLEME.md`'yi oku. Planı değiştiren bir karar alınırsa (kullanıcıyla) BU dosyayı güncelle ve `ILERLEME.md`'ye neden
> değiştiğini yaz. Oturum başı/sonu adımları: `.claude/skills/yaratik-yeniden-yazim/SKILL.md`.

## 1. Amaç

Kullanıcı (2026-10-03): "yaratıklar neden bu kadar çok fps düşürüyor, daha kalabalık yaratıkların olduğu oyunlar var
mobilde ancak hiç kastırmıyor" -> seçenekler konuşuldu -> "değer, bu ileride başımı ağrıtır" -> **tam yeniden yazım**,
aşamalı olarak. Hedef: aynı oyun hissiyle çok daha fazla yaratığı (özellikle Android'de) akıcı çalıştırmak.

Başarı ölçütü (Aşama 0'daki ölçümden sonra kesinleştirilecek): aynı sahnede (bkz. §6 ölçüm senaryosu) yaratık
simülasyon maliyetinin bugünkünün en az 1/5'ine inmesi ve oyunun davranışsal olarak aynı kalması (silahlar, efsunlar,
yetenekler, multiplayer).

## 2. Neden yavaş (ölçülmüş, 2026-09-27, 140-160 yaratık, 2560x1440, RTX 5060)

- Yaratık başına ~30 µs / fizik tiki, 160 yaratıkta ~5-6,5 ms (60 FPS bütçesinin %33-39'u). GPU darboğaz DEĞİL (~2,7 ms).
- Kırılım (yaratık başına): diğer betik mantığı ~12 µs, birbirinden itilme 7,8 µs, `move_and_slide` 5,6 µs, yol bulma 5,2 µs.
- Kök neden: her yaratık = kendi GDScript `_physics_process`'i (enemy.gd, 5644 satır) çalıştıran bir `CharacterBody2D`,
  fizik motorunda gerçek cisim, kendi A* rotası. Mobil kalabalık oyunlar yaratığı düz dizilerde tutup tek sıkı döngüde
  işler, fizik motoru ve yaratık başına yol bulma kullanmaz.

## 3. Kapsam (ölçülmüş, 2026-10-03)

- Çekirdek: `scripts/enemy.gd` 5644 satır / 183 fonksiyon; `enemy_spawner.gd` 1498; `enemy_abilities.gd` 387;
  `enemy_pathing.gd` 315; `enemy_projectile.gd`, `enemy_laser/fireball/acid_pool/thorns.gd`. Toplam ~10.600 satır.
- Yaratığa dokunan 52 dosya daha: 70 `body_entered` isabet yakalayıcısı, 55 `take_damage(`, 24 `apply_element(`,
  25 `get_enemies_near`, 119 `"enemies"` grup taraması, 15 `find_enemy_by_net_id`.
- 49 yaratık sahnesi (`scenes/creatures/*.tscn`), 21 efsun (`scripts/enchants/`), `weapon.gd` 3366 satır, 34 test dosyası.

### 3.1 Korunacak arayüz (dışarıdan kullanılan; yeni sistem bunları AYNEN sunmalı)

Fonksiyonlar (parantez = kaç dosya kullanıyor): `take_damage` (26), `apply_element` (11), `apply_slow` (7),
`apply_stun` (5), `apply_knockback_force` (4), `apply_knockback_distance` (4), `try_shaman_weapon_burn` (4),
`get_overhead_bar_offset` (3), `apply_element_host` (3), `apply_burn` (3), `take_damage_host` (2),
`set_ability_invisible` (2), `is_shocked`, `is_poisoned`, `apply_taunt`, `apply_skill_push`, `apply_root`,
`apply_poison`, `apply_mark_stack`, `apply_freeze_full`, `apply_fear_wander`, `apply_fear`, `apply_chill`, `apply_bleed`,
`apply_bee_poison`, `update_network_state`, `set_overhead_bar_always_visible`, `on_ability_vfx`, `make_elite`,
`is_frozen_now`, `is_burning`, `get_mark_damage_mult`, `enable_item_shield`, `die`, `apply_tier_scaling`,
`apply_boss_stats`. Ayrıca bazı dosyalar `_spawn_*_status_fx` / `_remove_*_status_fx` / `_take_dot_damage` /
`_spawn_floating_text` / `_update_facing` gibi ÖZEL fonksiyonları çağırıyor - bunlar ya arayüze alınacak ya da çağıran
taraf temizlenecek (Aşama 2'de listele).

Alanlar: `is_dead` (55 dosya), `speed` (34), `max_health` (23), `health` (20), `is_boss` (16), `item_shield_max` (11),
`item_shield_hp` (10), `shield_protection`, `is_ability_invisible`, `contact_damage`, `_body_radius`, `xp_value`,
`mark_stacks`, `last_attacker_peer_id`, `is_frozen`, `is_elite`, `chill_stacks`, `cell_size`, `bleed_stacks`,
`_network_velocity`, `_current_tier`; sinyaller `health_changed`, `item_shield_changed`; meta `network_enemy_id`,
`creature_id`, `spawn_tier`; gruplar `enemies`, `boss`, `elite_enemies`.

## 4. Hedef mimari

**Simülasyon veri odaklı, görünüm ve arayüz ince düğüm.**

1. **`EnemyWorld`** (Main'in çocuğu, tek düğüm): tüm yaratıkların durumunu düz dizilerde tutar (konum, hız, yarıçap,
   can, kalkan, hız çarpanları, durum etkisi sayaçları, hedef, AI durumu, aile/yetenek kimliği...). Tek bir
   `_physics_process` hepsini sırayla günceller: hedef seçimi, akış alanından yön, itilme (uzamsal ızgara), duvar
   çarpışması, saldırı, durum etkisi tikleri. Fizik motoru KULLANILMAZ.
2. **İnce yaratık düğümü (facade):** her yaratık için yine bir `Node2D` (sprite, durum simgeleri, elit yıldız/aura, ölüm
   animasyonu bunun çocukları kalır) - ama kendi `_physics_process`'i yok, fizik cismi yok. §3.1'deki fonksiyon ve
   alanlar bu düğümde durur ve `EnemyWorld`'deki satırına yönlenir. Böylece 52 dosyanın çoğu DEĞİŞMEDEN çalışır.
   (Bin+ yaratıkta düğüm sayısı sorun olursa ileride görünüm MultiMesh'e taşınabilir - şimdilik gerek yok, GPU boşta.)
3. **İsabet algılama:** mermiler/alanlar yaratığı `body_entered` ile değil `EnemyWorld.query_circle / query_segment /
   query_cone` ile bulur (uzamsal ızgara). 70 yakalayıcı tek tek taşınır; duvar/oyuncu çarpışmaları olduğu gibi kalır.
   **Ölçülen gerçek kapsam (2026-10-03):** yaratık FİZİK gövdesine dokunan sadece `projectile.gd` ve
   `boomerang_projectile.gd` (`body_entered`); `.tscn`'de bağlı sinyal yok, `world_event_manager` şekil sorgusu sadece
   StaticBody2D arar; diğer silah/yetenek isabetleri zaten `"enemies"` grubu + mesafe. Ayrıca yaratığın `HitArea`'sı
   (mask 2) CANLI: yerel oyuncu girince `_contact_timer = 0` (C++'ta `hit_radius` + `set_hit_probe` ile modellendi).
   Mermi tarafı `scripts/enemy_world/enemy_world_hits.gd`: her fizik adımının sonunda süpürülen çember sorgusu, Area2D
   giriş/çıkış anlamıyla (içeride kalan tekrar dönmez) - mevcut `_on_body_entered` gövdesine verilir, isabet kodu
   değişmez. Kayıtsız "enemies" (görev kopyası) fizik gövdesini korur, `body_entered` ile gelir.
4. **Yol bulma:** yaratık başına A* yerine ortak **akış alanı** - her canlı dış mekan oyuncusundan, mevcut
   `enemy_pathing.gd` ızgarası üzerinde BFS/Dijkstra; oyuncu hücre değiştirince karede bütçeli yeniden hesaplanır.
5. **Multiplayer:** host yetkili kalır, paket biçimi aynı (`_sync_enemy_positions`, `ENEMY_SYNC_BATCH`, net id kaydı).
   İstemcide yaratık simülasyonu çalışmaz, görünüm ağdan beslenir (bugünkü gibi).
6. **Dil: C++ GDExtension** (Aşama 0 kararı, §7). `EnemyWorld` simülasyonu (diziler, akış alanı, itilme, hareket,
   duvar, hedef, saldırı, durum etkisi sayaçları, sorgular) C++'ta; görünüm güncellemesi de (konum/kare) C++'tan
   yapılmalı - prototipte GDScript görünüm döngüsü yaratık başına ~1 µs ile en büyük kalemdi. Oyun mantığına yakın,
   sık değişen kısımlar (hasar sonrası olaylar, ödüller, yetenek tetikleri, efsun kancaları) GDScript'te kalır ve
   C++'tan sinyal/olay kuyruğu ile beslenir. Derlenmiş .dll/.so dosyaları depoya girer (arkadaşın derleyiciye ihtiyacı
   olmaz, sadece C++ değiştiren derler).

### 4.1 Aşama 1 ayrıntılı tasarım: C++ / GDScript bölüşümü (2026-10-03, enemy.gd `_physics_process` okunarak)

Bugünkü `enemy.gd _physics_process` (satır ~3896-4420) host'ta şunları yapıyor; yeni sistemde kim yapacak:

| Bugünkü iş | Yeni sistemde | Not |
|---|---|---|
| Donma / kök / yetenek kilidi / saldırı kilidi -> hız 0 | **C++** (bayraklar) | GDScript durum değişince bayrağı yazar |
| Korku (kaçış: kaynaktan uzağa; dolaşma: rastgele) | **C++** | kaynak konumu GDScript'ten |
| Tahrik (taunt) hedefi + süresi | **C++** (hedef indeksi + sayaç) | `apply_taunt` C++'a yazar |
| Hedef seçimi: "Ağacı Koru" > tahrik > Şovalye baloncuğu odağı > en yakın oyuncu / müttefik (160 px içinde x0,35 önyargı) | **C++**, `TARGET_UPDATE_INTERVAL_FRAMES`=4 kaydırmalı | Aday listesi (aşağıda) her fizik karesinde GDScript'ten |
| "Düşünme" kareleri (`AI_THINK_INTERVAL_FRAMES`=3, instance_id kaydırmalı), arada son karar | **C++** | aynı kaydırma deseni |
| Rota: düz çizgi engelliyse A* dönüş noktaları | **C++ akış alanı** (hedef başına: her oyuncu + ağaç; ≤ ~6 alan) | müttefik hedefte düz çizgi + takılma çözücü |
| Takılma çözücü (`_update_stuck_state`, `_steer_around_obstacle`) | **C++** | akış alanında nadiren gerekir; aynı sabitler |
| Hedefsiz dolaşma (`_compute_wander_velocity`) | **C++** | aynı sabitler |
| İtilme (grid, `ENEMY_SEPARATION_SMOOTH` 0,025 yumuşatma) | **C++** | |
| Geri itme hızı + sönüm (`KNOCKBACK_DECAY` 1400, tavan 400) | **C++** | `apply_knockback_*` / `apply_skill_push` C++'a yazar (formüller aynen) |
| Orman duvarı eksen probu (10 px) | **C++** (ızgara) | su/ev bugün de KAPALI, sadece orman |
| Oyuncu gövdesine / Şovalye baloncuğuna / satıcı bölgesine "sert yapıştırma" | **C++** | aday listesindeki baloncuk yarıçapları + satıcı bölgesi |
| Görüş hattı (menzilli, 150 ms önbellek) | **C++** (ızgara DDA) | |
| Yakın dövüş: menzil + `contact_timer` hazır -> saldırı | C++ tespit eder, **olay kuyruğu** -> GDScript `_enter_state(ATTACK)`, yayın, `_schedule_melee_hit` | kalkan saldırısı (paladin) aynı kuyruk, ayrı tür |
| Menzilli atış zamanlayıcısı (`_process_ranged_attack`) | C++ zamanlar, **olay** -> GDScript mermiyi atar | |
| Yaratık yetenekleri (`enemy_abilities.gd process`) | **GDScript** (sadece yeteneği olan aileler) | Aşama 4'te gözden geçir |
| Durum etkileri (`_process_burn/poison/chill/...`) | **GDScript**, ama sadece "aktif durum" bayrağı olanlar için köprüden çağrılır | `_physics_process` artık kapalı |
| Yön (facing satırı), yürüme/bekleme karesi | **C++** (Sprite2D frame'i C++'tan yazılır) | saldırı/hasar/ölüm durum geçişi GDScript `_enter_state`'te, C++'a kare sayısı/fps/döngü bildirir |
| Konum yazma | **C++** -> yaratık düğümünün `global_position`'ı | fizik cismi Aşama 2'ye kadar kalır (mermi isabetleri `body_entered`'a bağlı) |
| İstemci (host olmayan) kukla dalı | Aşama 1-4'te **eski GDScript yolu** | `USE_ENEMY_WORLD` sadece host / tek oyunculuda devreye girer; istemci Aşama 5 |

**Bilinçli farklar (2026-10-03, dilim 2):** (1) LOD YOK: enemy.gd uzak yaratıklarda (1600 px) hedef/düz çizgi/itilme
aralığını x8 seyreltiyordu; C++'ta yaratık başına 0,3 µs olduğundan herkes tam hassasiyette (davranış eşit ya da daha iyi).
(2) Önbellekteki "en yakın" hedef görünmez/ev içi olursa enemy.gd o yaratığı bir sonraki yenilemeye kadar (<=4 kare)
dolaştırıyordu; C++ hemen yeniden seçer. (3) Takılma bükmesinin ileri probu sadece ORMAN ızgarasına bakar (enemy.gd su+ev+orman;
su/ev zaten geçilebilir). (4) Tahrik süresi/kışkırtan tamamen C++'ta (`set_taunt`), görsel GDScript'te (`E_TAUNT_LOST`).
(5) Akış alanı: düz çizgi açıksa düz yürü; kapalıysa akışta 16 hücre ileri inip düz çizgiyle görülen en uzak hücreye
yönel (A* + `_smooth` eşdeğeri, yeniden planlama aralığı yok - her düşünmede taze).

**Aday (hedef) listesi** - GDScript köprüsü (`scripts/enemy_world/enemy_world_bridge.gd`) her fizik karesinde BİR kez
doldurur: yerel oyuncu, uzak oyuncular, `player_allies`, ağaç (görev). Alanlar: konum, tür, hedeflenebilir mi (ölü/
yerde/görünmez/ev içi/satıcı bölgesi değil), hayalet mi (Vampir yarasa: gövde yapıştırması yok), gövde yarıçapı,
Şovalye baloncuğu yarıçapı (0 = yok). Ayrıca satıcı bölgesi (konum, yarıçap, açık mı), `BODY_BLOCK_SCALE`.

**Yaratık başına C++ alanları:** konum, niyet hızı, geri itme hızı, gövde yarıçapı, taban hız, hız çarpanı (chill x slow
x rage - GDScript değişince yazar), bayraklar (DEAD, FROZEN, ROOTED, FEAR_FLEE, FEAR_WANDER, ATTACK_LOCK, ABILITY_LOCK,
RANGED, BOSS, GHOST_INVISIBLE, STATUS_ACTIVE), korku kaynağı, menzil (`ranged_range`), temas aralığı/zamanlayıcısı,
menzilli zamanlayıcı, tahrik hedefi+süresi, düşünme fazı, mevcut hedef, akış alanı/takılma/dolaşma durumu, yön satırı,
animasyon (kare sayısı, fps, yürüme çarpanı, döngü, süre), düğümün ObjectID'si ve Sprite2D'sinin ObjectID'si.

**Olay kuyruğu (C++ -> GDScript, her tik):** `MELEE(i, hedef)`, `BARRIER_HIT(i, hedef)`, `RANGED_FIRE(i, hedef, yön)`,
`GHOST_REVEAL(i)`. Köprü kuyruğu boşaltıp ilgili yaratığın mevcut GDScript fonksiyonunu çağırır - saldırı/hasar kodu
aynen yeniden kullanılır.

**Ölçüt (Aşama 1 sonu):** `USE_ENEMY_WORLD=true` iken tek oyunculuda 200 yaratıkla oyun aynı hissettirir (kovalama,
duvar dolanma, itilme, yakın/menzilli saldırı, donma/kök/korku/tahrik, geri itme), `bench_current` senaryosunda yaratık
başına maliyet <= 3 µs (GDScript durum etkileri dahil).

**Geçiş anahtarı:** yeni sistem eskisinin YANINDA kurulur; `scripts/enemy_world/enemy_world_config.gd` içinde
`USE_ENEMY_WORLD` sabiti. Bir aşama bitip doğrulanana kadar varsayılan eski yol; böylece master hep oynanabilir kalır ve
A/B ölçüm yapılabilir. Son aşamada eski yol silinir.

## 5. Aşamalar

Her aşamanın sonunda: oyun oynanabilir, testler geçiyor, ölçüm `ILERLEME.md`'ye yazıldı, commit atıldı (push kullanıcıya
sorulur). Aşamanın alt maddeleri `ILERLEME.md`'de işaretlenir.

### Aşama 0 - Ölçüm prototipi (karar aşaması)
- [x] `tools/enemy_rewrite/` altına kalıcı ölçüm betikleri (geçici klasör DEĞİL - diğer oturum göremez):
  - `bench_current.gd`: bugünkü sistem, §6 senaryosu, kare süresi + yaratık başına µs.
  - `bench_soa_gd.gd`: aynı sayıda yaratık, düz dizi + tek döngü GDScript (hedefe yürü + itilme + duvar + akış alanı).
  - (gerekirse) `bench_soa_cpp`: aynı döngünün C++ hali.
- [x] 200 / 500 / 1000 / 2000 yaratıkta sonuç tablosu.
- [x] Kullanıcıyla dil kararı (GDScript mi C++ mı) -> §7'ye yaz.

### Aşama 1 - EnemyWorld çekirdeği
- [x] Veri dizileri, ekle/çıkar (boş satır yeniden kullanımı), uzamsal ızgara.
- [x] Akış alanı (çok oyunculu, iç mekan / dış mekan kuralı, bütçeli güncelleme).
- [x] Hareket + itilme + duvar çarpışması + geri itme (knockback) + yavaşlatma/sersemletme etkisi.
- [x] Hedef seçimi (oyuncu/uzak oyuncu/evcil hayvan/tahrik), yakın saldırı.
- [x] İnce yaratık düğümü: sprite, yön (4 satır), yürüme/saldırı/hasar/ölüm animasyonu, y-sıralama (main.gd ayak satırı). (facade = mevcut enemy.gd düğümü, fizik gövdesi kapalı)
- [x] Ölçüm: hareket eden 1000 yaratık.

### Aşama 2 - Savaş arayüzü
- [x] §3.1 arayüzünün hepsi facade'da; özel fonksiyon çağıranları listele ve temizle.
- [x] Hasar, kalkan, kritik, hasar sayıları, ölüm, XP/altın/sandık düşürme, elit/boss ölçeklemesi. (enemy.gd'de aynen, A/B)
- [x] Durum etkileri: yanma, zehir, donma/ürperti, şok, kanama, korku, tahrik, kök, işaret, sersemletme, yavaşlatma.
- [x] 70 `body_entered` isabet yakalayıcısı -> `EnemyWorld.query_*` (gerçekte 2 dosya: projectile + boomerang).
- [x] `get_enemies_near`, `"enemies"` grup taramaları -> EnemyWorld sorguları. (`scripts/enemy_world/enemy_query.gd` `candidates`: üst küme döner, çağıranın süzgeçleri aynen; silah hedeflemesi `query_nearest`)

### Aşama 3 - Görseller
- [x] Vuruş parlaması, durum simgeleri, can barı (boss), elit yıldız + aura, ölüm kanı, gece ışığı, görüş sisi gizleme. (sis gizleme C++'ta)
- [x] Sürü hâlinde (1000+) çizim maliyeti ölçümü; gerekirse görünüm havuzu. (havuz gerekmedi; GPU sabit ~3,5 ms. Y-sıralaması C++ `draw_order` -> `canvas_item_set_draw_index`, düğüm taşınmaz; minimap noktaları C++ `minimap_points`)

### Aşama 4 - Yetenekler ve içerik
- [x] Aile yetenekleri (lazer, ateş topu, diken, asit, hayalet, vampir...), menzilli yaratıklar, öfke.
- [x] Bosslar, kademe kapısı, elit seçimi, görev dalgaları/kopya görevi, debug menüsü doğurma.

### Aşama 5 - Multiplayer, testler, temizlik
- [x] Host/istemci senkronu; iki süreçli test (LAN ENet, `tools/enemy_rewrite/run_mp.ps1`) - yeni varsayılanla eşleşiyor. (Host değişimi yok: ENet host = peer 1. Epic ile iki süreç bu işte koşulmadı - paket biçimi değişmedi.)
- [x] Testleri yeni sisteme taşı (`tests/test_enemy_world.gd`; tam paket yeni varsayılanla yeni başarısız yok); Android .so derlendi + APK'ya giriyor. [ ] Telefonda FPS (kullanıcı).
- [x] `USE_ENEMY_WORLD` varsayılan true (2026-10-03) -> CLAUDE.md ve bu planı güncelle.
- [ ] Eski HOST simülasyonunu sil (enemy.gd `_physics_process` canlı-yaratık dalı ~400 satır + ona özel yardımcılar) -
  KULLANICI ONAYIYLA, oyunu yeni yolda oynayıp onayladıktan ve iş commit edildikten sonra. (2026-10-03: kullanıcı oynadı,
  onayladı; silme denemesi Claude Code otomatik izin denetleyicisince engellendi - kullanıcı izni bekleniyor, bkz. ILERLEME.) Silinmeyecekler (yeni yolda da
  KULLANILIYOR): istemci kukla dalı, ölüm animasyonu dalı, `get_enemies_near` eski ızgarası (istemci), sis/silah GDScript
  taramaları (istemci), `enemy_pathing.gd` ızgara kurulumu (köprü kullanıyor). Eski host dalı ayrıca şu durumlarda TEK yedek:
  eklentinin derlemesi olmayan platform (Web ön ayarı, Android armv7/x86_64), eklenti yüklenemezse, `current_scene`
  olmadan kurulan birim testleri (tests/test_enemy_pathing vb. eski dalı adım adım sınıyor).

## 6. Ölçüm ve test

- Godot: `C:\Users\perva\Desktop\Arşiv\Godot_v4.7.2-stable_win64.exe` (GUI derlemesi; çıktıyı görmek için PowerShell
  `Start-Process -NoNewWindow -RedirectStandardOutput <dosya>` + `WaitForExit`). Yoldaki `ş` PowerShell betiğinde
  `"...\Ar$([char]0x015F)iv\..."` olarak yazılmalı. Bash, Türkçe karakterli yolları bozar.
- Mantık testleri: `--headless --path <proje> -s <betik.gd>`; görsel/GPU ölçümleri: `--windowed --resolution 1920x1080`
  (headless'ta shader derlenmez, `frame_post_draw` hiç gelmez).
- Kare süresini duvar saatiyle ölç (`Time.get_ticks_usec`), `Performance.TIME_*` monitörleri bu projede güvenilmez.
- §6 ölçüm senaryosu (her aşamada aynı): gerçek menü akışı -> Main, Korsan, ölümsüz oyuncu, N yaratık (200/500/1000),
  oyuncu bir kare çizerek yürüyor (yol bulma devrede), gündüz + fırtına ayrı ayrı, 20 sn; ortalama ve p95 kare süresi.
- Multiplayer: iki headless süreç, bayrak dosyalarıyla eşleme (örnek: geçmişteki `mp_runner.gd` deseni - Aşama 5'te
  `tools/enemy_rewrite/` altına kalıcı bir sürümü yazılacak).
- Yeni PNG/kaynak eklenince önce `--headless --import`. Yeni bir `.gdextension` eklenince de (`.godot/extension_list.cfg`'ye
  girmesi için) bir kez `--import`.

### 6.1 C++ araç zinciri (2026-10-03'te kuruldu, bu bilgisayarda)

Hepsi depo DIŞINDA, kurulumsuz: `%LOCALAPPDATA%\Toolchains\`.
- **llvm-mingw 20260922 ucrt-x86_64** (GitHub mstorsjo/llvm-mingw, clang 23): `%LOCALAPPDATA%\Toolchains\llvm-mingw-20260922-ucrt-x86_64\bin`
  derleme öncesi PATH'in başına eklenir.
- **godot-cpp, `4.5` dalı** (`git clone --depth 1 --branch 4.5 https://github.com/godotengine/godot-cpp.git`):
  `%LOCALAPPDATA%\Toolchains\godot-cpp`. **Yerel yama:** `src/godot.cpp`'ye `#include <cstdlib>` eklendi (clang 23 +
  libc++'ta `realloc`/`free` bulunamıyordu). Yeniden klonlanırsa yamayı tekrar uygula. 4.5 API'siyle derlenen eklenti
  Godot 4.7'de çalışıyor (EOSG de öyle).
- **SCons 4.11** (`pip install scons`).
- **Android NDK 28.1.13356709** (`sdkmanager "ndk;28.1.13356709"`, godot-cpp'nin varsayılan sürümü):
  `%LOCALAPPDATA%\Android\Sdk\ndk\28.1.13356709`.
- **TUZAK - Python takma adı:** `python` komutu `WindowsApps` takma adı (paketli uygulama) ve AppData'yı
  SANALLAŞTIRIYOR: godot-cpp'yi ve NDK'yı göremez ("missing SConscript file"). SCons'u HER ZAMAN doğrudan
  `%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe -m SCons ...` ile çalıştır.
- Komutlar (eklenti klasöründe, PowerShell):
  ```
  $env:PATH = "$env:LOCALAPPDATA\Toolchains\llvm-mingw-20260922-ucrt-x86_64\bin;" + $env:PATH
  & "$env:LOCALAPPDATA\Python\pythoncore-3.14-64\python.exe" -m SCons platform=windows use_mingw=yes use_llvm=yes target=template_debug -j8
  $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
  & "$env:LOCALAPPDATA\Python\pythoncore-3.14-64\python.exe" -m SCons platform=android arch=arm64 target=template_debug -j8
  ```
  Yayın (export) için `target=template_release` sürümleri de derlenmeli (Aşama 5).
- Örnek proje: `tools/enemy_rewrite/bench_soa_cpp/` (SConstruct + src + .gdextension).

## 7. Kararlar

| Konu | Durum |
|---|---|
| Tam yeniden yazım, aşamalı, facade + geçiş anahtarıyla | KARAR (kullanıcı, 2026-10-03) |
| GDScript mi C++ GDExtension mı | KARAR (2026-10-03, Aşama 0 ölçümü): **C++**. Yaratık başına simülasyon: eski 36 µs, GDScript düz dizi 8-11 µs (~3,5x, hedef 5x tutmadı, akış alanı 6-11 ms tepe), C++ 0,22-0,5 µs (~100x+, akış alanı ~0,01 ms). 1000 yaratık: eski 36,8 ms, GDScript 12,1 ms, C++ 1,3 ms (görünüm GDScript'te dahil). Kullanıcı araç zinciri indirmesine izin verdi ("ne gerekiyorsa yap izin veriyorum"). Windows + Android derlemesi doğrulandı |
| Ayrı git dalında mı master'da mı | KARAR (2026-10-03): **master'da**, `USE_ENEMY_WORLD` geçiş anahtarının arkasında |
| Commit/push | KARAR (2026-10-03, kullanıcı: "sormasın, ben söyleyince yapar, durmadan devam etsin hep"): commit/push SADECE kullanıcı söyleyince; bunun için soru SORMA. Kota aniden biterse iş diskte commit'siz kalır, sonraki oturum `git status` + ILERLEME.md ile toparlar - bu yüzden ILERLEME.md her alt maddeden sonra güncellenir |
| Çalışma tarzı | KARAR (aynı mesaj): aşamalar arasında onay için DURMA, plan bitene kadar sırayla devam et. Kullanıcıya sadece gerçekten onun vermesi gereken bir karar (ör. oyun davranışının değişmesi) varsa sor |
| Varsayılan yol | KARAR (2026-10-03, kullanıcı: "her şey tamamlanana kadar devam et"): `USE_ENEMY_WORLD = true`. Eski host dalının silinmesi ayrı, kullanıcı onaylı adım (yukarıda Aşama 5) |
| Arkadaşa haber | Kullanıcı verecek: bu süre boyunca `enemy*.gd`, `weapon.gd`, efsunlar, yaratık sahnelerine dokunurken önce `ILERLEME.md`'ye baksın |

## 8. Bilinen tuzaklar (bu projede daha önce yaşananlar - yeni sistemde TEKRARLAMA)

- `Packed*Array` değer tipidir: `dict[k].append()` sözlükteki kopyayı değiştirmez (itilme bir kez bu yüzden tamamen
  çalışmıyordu). Sözlükte düz `Array` kullan ya da geri yaz.
- Silinmiş nesne `== null` true döner; tipli değişkene silinmiş nesne atamak hata verir (tipsiz oku).
- Fizik sorgusu temizlenirken (`take_damage`/`die` içinden) senkron `add_child` hata verir -> ertele/kuyruğa al
  (bugün: `_queue_drop_spawn`, yüzen yazı kuyruğu, kare başına sınır).
- Bir yaratık alt kümesini itilmeden KALICI olarak çıkarmak üst üste yığılma yapar; LOD sadece aralığı genişletebilir.
- Aynı türden toplu ölümler aynı karede bitmesin (ölüm süresine rastgele sapma).
- Yön (facing) her karede güncellenmeli; istemci kuklası yönünü ayrıca hesaplar.
- Yerdeki düşmeler (XP/altın) uzaktaysa uyutulur (`drop_attraction.gd`); görüş sisi düşmeleri de gizler.
- Yaratık y-sıralaması kök değil AYAK satırına göre (`main.gd _update_creature_draw_order`).
- Ağ: `ENEMY_SYNC_BATCH` = 10 (Epic P2P paket sınırı, `fragment_peer.gd`); net id kaydı `NetworkManager.register_enemy_net_id`.
- Elit/boss ölçeklemesi tek fonksiyondan (`make_elite`, `apply_boss_stats`, `_scale_body`), host ve istemci aynı yoldan.
- Kademe kapısı: eski kademeden sağ kalan varken yeni yaratık doğmaz (`_resolve_spawn_tier`).
- Kullanıcı Godot editörünü açık tutabilir: editörde açık bir .tscn'yi dışarıdan düzenleme (eski hali üzerine yazar).
