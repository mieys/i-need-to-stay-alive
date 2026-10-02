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
4. **Yol bulma:** yaratık başına A* yerine ortak **akış alanı** - her canlı dış mekan oyuncusundan, mevcut
   `enemy_pathing.gd` ızgarası üzerinde BFS/Dijkstra; oyuncu hücre değiştirince karede bütçeli yeniden hesaplanır.
5. **Multiplayer:** host yetkili kalır, paket biçimi aynı (`_sync_enemy_positions`, `ENEMY_SYNC_BATCH`, net id kaydı).
   İstemcide yaratık simülasyonu çalışmaz, görünüm ağdan beslenir (bugünkü gibi).
6. **Dil:** önce GDScript (düz `Packed*Array` + tek döngü). Aşama 0 ölçümü GDScript'in yetmediğini gösterirse sıcak döngü
   C++ GDExtension'a taşınır (Windows + Android derlemesi gerekir) - KARAR AÇIK, bkz. §7.

**Geçiş anahtarı:** yeni sistem eskisinin YANINDA kurulur; `scripts/enemy_world/enemy_world_config.gd` içinde
`USE_ENEMY_WORLD` sabiti. Bir aşama bitip doğrulanana kadar varsayılan eski yol; böylece master hep oynanabilir kalır ve
A/B ölçüm yapılabilir. Son aşamada eski yol silinir.

## 5. Aşamalar

Her aşamanın sonunda: oyun oynanabilir, testler geçiyor, ölçüm `ILERLEME.md`'ye yazıldı, commit atıldı (push kullanıcıya
sorulur). Aşamanın alt maddeleri `ILERLEME.md`'de işaretlenir.

### Aşama 0 - Ölçüm prototipi (karar aşaması)
- [ ] `tools/enemy_rewrite/` altına kalıcı ölçüm betikleri (geçici klasör DEĞİL - diğer oturum göremez):
  - `bench_current.gd`: bugünkü sistem, §6 senaryosu, kare süresi + yaratık başına µs.
  - `bench_soa_gd.gd`: aynı sayıda yaratık, düz dizi + tek döngü GDScript (hedefe yürü + itilme + duvar + akış alanı).
  - (gerekirse) `bench_soa_cpp`: aynı döngünün C++ hali.
- [ ] 200 / 500 / 1000 / 2000 yaratıkta sonuç tablosu.
- [ ] Kullanıcıyla dil kararı (GDScript mi C++ mı) -> §7'ye yaz.

### Aşama 1 - EnemyWorld çekirdeği
- [ ] Veri dizileri, ekle/çıkar (boş satır yeniden kullanımı), uzamsal ızgara.
- [ ] Akış alanı (çok oyunculu, iç mekan / dış mekan kuralı, bütçeli güncelleme).
- [ ] Hareket + itilme + duvar çarpışması + geri itme (knockback) + yavaşlatma/sersemletme etkisi.
- [ ] Hedef seçimi (oyuncu/uzak oyuncu/evcil hayvan/tahrik), yakın saldırı.
- [ ] İnce yaratık düğümü: sprite, yön (4 satır), yürüme/saldırı/hasar/ölüm animasyonu, y-sıralama (main.gd ayak satırı).
- [ ] Ölçüm: hareket eden 1000 yaratık.

### Aşama 2 - Savaş arayüzü
- [ ] §3.1 arayüzünün hepsi facade'da; özel fonksiyon çağıranları listele ve temizle.
- [ ] Hasar, kalkan, kritik, hasar sayıları, ölüm, XP/altın/sandık düşürme, elit/boss ölçeklemesi.
- [ ] Durum etkileri: yanma, zehir, donma/ürperti, şok, kanama, korku, tahrik, kök, işaret, sersemletme, yavaşlatma.
- [ ] 70 `body_entered` isabet yakalayıcısı -> `EnemyWorld.query_*` (silah silah, efsun efsun işaretle).
- [ ] `get_enemies_near`, `"enemies"` grup taramaları -> EnemyWorld sorguları.

### Aşama 3 - Görseller
- [ ] Vuruş parlaması, durum simgeleri, can barı (boss), elit yıldız + aura, ölüm kanı, gece ışığı, görüş sisi gizleme.
- [ ] Sürü hâlinde (1000+) çizim maliyeti ölçümü; gerekirse görünüm havuzu.

### Aşama 4 - Yetenekler ve içerik
- [ ] Aile yetenekleri (lazer, ateş topu, diken, asit, hayalet, vampir...), menzilli yaratıklar, öfke.
- [ ] Bosslar, kademe kapısı, elit seçimi, görev dalgaları/kopya görevi, debug menüsü doğurma.

### Aşama 5 - Multiplayer, testler, temizlik
- [ ] Host/istemci senkronu, sonradan katılma (catch-up), host değişimi; iki süreçli test (LAN ENet + Epic).
- [ ] Testleri yeni sisteme taşı; Android derlemesi ve telefonda FPS.
- [ ] `USE_ENEMY_WORLD` varsayılan true -> eski yolu sil -> CLAUDE.md ve bu planı güncelle.

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
- Yeni PNG/kaynak eklenince önce `--headless --import`.

## 7. Kararlar

| Konu | Durum |
|---|---|
| Tam yeniden yazım, aşamalı, facade + geçiş anahtarıyla | KARAR (kullanıcı, 2026-10-03) |
| GDScript mi C++ GDExtension mı | Aşama 0 ölçümüne göre Claude karar verir ("durmadan devam"): GDScript hedefi (yaratık simülasyonu bugünkünün <= 1/5'i, 1000 yaratık) tutturuyorsa GDScript; tutturmuyorsa C++ - kararı ve ölçümü buraya yaz, kullanıcıya bilgi ver |
| Ayrı git dalında mı master'da mı | KARAR (2026-10-03): **master'da**, `USE_ENEMY_WORLD` geçiş anahtarının arkasında |
| Commit/push | KARAR (2026-10-03, kullanıcı: "sormasın, ben söyleyince yapar, durmadan devam etsin hep"): commit/push SADECE kullanıcı söyleyince; bunun için soru SORMA. Kota aniden biterse iş diskte commit'siz kalır, sonraki oturum `git status` + ILERLEME.md ile toparlar - bu yüzden ILERLEME.md her alt maddeden sonra güncellenir |
| Çalışma tarzı | KARAR (aynı mesaj): aşamalar arasında onay için DURMA, plan bitene kadar sırayla devam et. Kullanıcıya sadece gerçekten onun vermesi gereken bir karar (ör. oyun davranışının değişmesi) varsa sor |
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
