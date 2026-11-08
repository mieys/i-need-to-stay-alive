# HARİTA SEÇİMİ - İLERLEME (plan: PLAN.md)

## 1. adım: profil + yükleme - BİTTİ (2026-11-07, madde 444)
- `scripts/map_profiles.gd` (preload ile, class_name YOK; autoload'lardan önce derlenebilir): `PROFILES` ("ana", "kadim_derinlikler"),
  `current_id()` (HARITA ortam değişkeni > `GameManager.selected_map` > "ana"), `feature(ad)` (tanımsız bayrak: ana haritada açık, diğerlerinde
  kapalı), `preload_paths()`, `install(main)`.
- `GameManager.selected_map` ("ana"; reset() sıfırlamaz).
- `main.gd _enter_tree`: `MapProfilesScript.install(self)` dükkan ayıklamasından ÖNCE; `_ready`'deki Harita.tmx görsel kurulumu bloğu (ot/ağaç
  sallanması, derinlik, orman tacı, gölge, renk ayarı, su, zemin geçişi, derin orman ışıkları, nehir sesi) `feature("orman_gorselleri")`.
- `loading_screen.gd start_loader`: seçili haritanın sahnesi + verisi iş parçacığında ön yüklenir.
- `main.tscn` DEĞİŞMEDİ: ana harita hâlâ gömülü (başka harita seçilince de bir kez yüklenip atılıyor - 2. ya da 3. adımda main.tscn'den
  çıkarılıp profilden yüklenebilir; editör açıkken main.tscn'i dışarıdan düzenleme).
- Test: `tests/test_map_profiles.gd` 5/5, `test_all_scripts_compile`, `test_loading_screen_script_loading` 10/10, `test_camera_map_limits` 4/4.
  Başsız duman (Main açılışı + 8 sn): ana harita değişiklik öncesiyle birebir (13,7 sn, Harita 11. sırada, 61 katman, oyuncu konumu, 139
  yaratık, oyun alanı, 0 UID dışı hata). `HARITA=kadim_derinlikler`: Harita 11. sırada 10 katmanlı zindan sahnesi, oyun alanı 4096x4096,
  0 hata; oyuncu ev açılışında (20370, 171), 0 yaratık, orman katmanı yok (= çarpışma yok).
- Duman betiği: oturum scratchpad'indeydi (`harita_smoke.gd`: buyuk_test.gd `_boot` gibi Main'i açar, 8 sn, harita/oyuncu/yaratık/oyun alanı
  yazar) - 2. adımda `tools/harita_secimi/` altına alınmalı.

## 2. adım (çekirdek): oynanabilirlik - BİTTİ (2026-11-07, madde 444)
- ÇARPIŞMA / MERMİ / GÖRÜŞ / YOL: `map_profiles.install` zindan haritasına GÖRÜNMEZ "Orman parçaları/Orman parçaları" katmanı ekler (her
  CELL_WALL hücresine tek karo, 31.630 hücre): `GameManager.get_forest_layer` / `is_position_blocked_*` / EnemyPathing (+ C++ ızgara) /
  görüş sisi / yaratık doğuş denetimi bugünkü kodla çalışır (yol ızgarası orman katmanı boşsa hiç kurulmuyordu - asıl sebep bu).
- Nesne / su / saklanma / kapı hücreleri: `DungeonWorld._register` zindan haritasında haritanın KENDİ verisini köken (0,0)'da kaydeder
  (`_add_cells`, `_dungeons` listesine girmez: harita "zindan içi" sayılmaz); üç zindan yalnız `feature("zindan_girisleri")` (ana harita).
- AÇILIŞ: `FEATURE_NODES` bayrağı kapalıysa main.tscn'den kaldırılır (HouseInterior = ev + intro + kuşatma + babaanne, TravelingMerchant,
  WorldEventManager); `main._ready` oyuncuyu `spawn_position()`'a (dogus nesnesi) koyar, diğer oyuncular çevresine.
- `main._ready`: MineWorld / GuardCamps / DungeonManager bayrakla; orman rüzgârı sesi yeraltında duraklatılır.
- YERALTI: `player.is_underground_now()` profilde "hava" kapalıysa true (gün-gece katmanı, bulut, yağmur, şimşek kapalı - zindanla aynı yol).
- MINIMAP: `map_profiles.minimap_texture()` hücre kodlarından tam harita (1 piksel = 1 hücre, zindan minimap renkleri, kanal kan rengi).
- Test: `test_map_profiles` 7/7 (+ duvar katmanı/doğuş/kaldırılan düğümler, zindan kaydı), `test_dungeons` 7/7, `test_enemy_pathing` 7/7,
  derleme. Duman (`tools/harita_secimi/harita_duman.gd`): ana harita öncekiyle aynı; Kadim Derinlikler: oyuncu doğuşta (2056, 2048), duvar
  engelliyor, yol bulunuyor, 18 sn'de 27 yaratık, 0 hata. Gerçek çizici (`harita_goruntu.gd`, gizli masaüstü): salon + katedral + minimap doğru.

## 2b: yeraltı aydınlatması + zindan etkileşimleri - BİTTİ (2026-11-07, madde 444)
- `DungeonManager` HARİTA KİPİ (`_setup_map`; main.gd profilde `zindan_etkilesim` varsa kurar): kök = sahnedeki Harita (yükleme yok), oyuncu
  "zindanda" sayılmaz (in_dungeon boş -> yaratık doğuşu / gün-gece / minimap etkilenmez), `_local_interactions` ve `_tick_traps` in_dungeon
  boşken haritaya bakar, `warm_done` hemen true (yükleme katmanı beklemesin). Derinlik ön kopyaları (Eşya / Eşya alt), kan shader'ı, TEK
  `DungeonLight` (ortam `zindan_tanimi` = üç zindan renginin ortası, 276 `isik` nesnesi, oyuncu feneri, ışıklı karolar tema önekli adlarla).
- Tema: nesnenin `tema` özelliği -> `MAP_THEME_DUNGEON` (kemik_mahzeni / et_kuyusu / boynuzlu_kapi): sunak teklifleri + kaynak türü
  (`_offer_id`, `_resource_of`), görsel = tema başına bir `DungeonProps` (o zindanın STYLE tablosu + kendi sayfa klasörü), anahtar -> örnek
  `_props_for`. `DungeonWorld.map_entry()` (entry(id) bulur, dungeons() görmez).
- `guard_camps.gd` harita kipi: kenar kampları (CAMPS) `kenar_bekcileri` kapalıysa yok; haritanın 56 `sakin` + 3 `avci` nesnesi zindan kampı
  (yaratık listesi / avcı nesnenin temasının zindanından), oyuncu haritadayken dolu sayılır (`_dungeon_of`).
- Test: derleme, `test_map_profiles` 7/7, `test_dungeons` 7/7, `test_guard_camps` 7/7. Duman: ana harita aynı (52 kamp, 139 bekçi);
  Kadim Derinlikler 93 etkileşim nesnesi, 59 kamp, 18 sn'de 40 sakin + 27 yaratık, host kapı kapatma yolu kesiyor, sandık bir kez açılıyor,
  kaynak +2 Ruh Közü, 0 hata. Gerçek çizici (gizli masaüstü, `tools/harita_secimi/out/`): loş ortam + ışıklar + simyacı odası doğru,
  ortalama kare 5,3-5,7 ms.
- Doğrulanmadı: iki görünür pencerede istemci tarafı (kapı/sandık RPC'leri zindanlarla aynı kod, `run_audit -Mode zindan` harita kipinde koşmadı),
  sunak satın alma elle denenmedi, avcı rotası gözle izlenmedi.

## 3. adım: seçim arayüzü + ağ - BİTTİ (2026-11-07, madde 444)
- Kadim Derinlikler `secilebilir: true`; `MapProfiles.selectable_ids()` / `is_selectable()` / profil `aciklama`.
- ODA KUR formu (`room_browser.gd` masaüstü): "Harita" satırı (seçilebilir haritalar, `_set_room_map`, `_style_choice`), `configure_room(..., map_id)`
  -> `GameManager.selected_map` (odanın haritası = host'un seçimi). Oda listesinde ana harita dışındaki odalar "Ad (Harita)" (`_room_title`,
  masaüstü + telefon satırı + ipucu).
- TEK OYUNCULU (`lobby_select_desktop.gd` solo): sol sütunda HARİTA kutusu (y 524, açıklamalı) -> `GameManager.selected_map`.
- AĞ (`network_manager.gd`, LOBBY_PROTOCOL lobi-19): `_rpc_start_game(map_id)` + `_rpc_join_in_progress_game(map_id)` herkese host'un
  `selected_map`'ini yazar (yüklemeden önce); LAN ilanı 9. alan = harita (`parts.size() >= 8`, eksikse "ana"); EOS lobi özniteliği `MAP`
  (`eos_online.gd host_lobby_async(..., map_id)`, listede "map"). Host devrinde yeni host aynı haritada olduğundan yeni ilanı doğru.
- Test: derleme, `test_map_profiles` 7/7, `test_lobby_rooms` 6/6, `test_multiplayer_restart_returns_to_lobby` 4/4, `test_start_weapon_pick` 4/4.
  `test_mobile_screens` 10/11: telefon ayarları GENEL listesinde "ally_fx" (madde 426, başka oturumun işi) - bu adımla ilgisiz, eski test.
  Görüntü (`tools/harita_secimi/secim_goruntu.gd`, gizli masaüstü, `out/secim_*.png`): iki ekranda yerleşim doğru.
- Yapılmadı / doğrulanmadı: iki süreçli çok oyunculu deneme (host Kadim seçip başlatınca istemci de Kadim yükler mi - RPC argümanı, elle
  koşulmadı); telefon oda kurda harita seçimi VAR (oyuncu sayısı satırının yerinde, 2026-11-07), telefon tek oyunculu ekranında YOK (GameManager.selected_map neyse o, varsayılan ana); çok
  oyunculu karakter seçimi ekranında haritanın adı gösterilmiyor (istemci oda listesinde görüyor).

## Tek temalı üç harita (madde 445)
- Kadim Derinlikler seçimden kalktı; yerine Kemik Katakombu / Kızıl Lağım / Boynuz Mağaraları (`tools/zindan/gen_tema_haritalari.py`), aynı
  harita kipi altyapısı. Ayrıntı madde 445.

## Sırada
- İki süreçli MP denetimi (harita senkronu + harita kipinde kapı/sandık RPC'leri), telefon tek oyunculu ekranına harita seçimi, MP seçim ekranında harita adı.
- Seyyar satıcı yeri + güvenli bölge; 4. adım görevler (görev alanı nesneleri).
- main.tscn'deki ana harita zindan haritası seçilince de bir kez yükleniyor (açılış ~14 sn).
- 2026-11-07 (madde 447): üç tema haritası örnek TMX odalarından baştan kuruldu (`tools/zindan/gen_ornek_haritalar.py`); kimlikler ve profiller aynı.
- 2026-11-07 (madde 449): YENİ ÜÇ HARİTA 1/3 Batık Nekropol (`batik_nekropol`, `tools/zindan/gen_batik_nekropol.py`) seçilebilir; Kemik Katakombu seçimden kalktı. 2. ve 3. harita sırada.
- 2026-11-07 (madde 449): 2/3 Taşkın Hisar (`taskin_hisar`, Dungeon1, `tools/zindan/gen_taskin_hisar.py`) seçilebilir; Boynuz Mağaraları seçimden kalktı. Haritaya özgü KÖPRÜ KOLU (`kol` nesnesi). 3. harita sırada.
- 2026-11-07 (madde 449): 3/3 Lağım Ağı (`lagim_agi`, Kanalizasyon seti, `tools/zindan/gen_lagim_agi.py`) seçilebilir; Kızıl Lağım seçimden kalktı. Haritaya özgü GAZ FIÇISI (`fici` nesnesi). Seçim: ana / Batık Nekropol / Taşkın Hisar / Lağım Ağı.
