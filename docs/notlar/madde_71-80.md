# Madde 71-80 (CLAUDE.md dizini: madde_61-70.md'de 71-74 var; yeni maddeler buraya)

## 75. BALANS TELEMETRİSİ (2026-10-11, kullanıcı: "neyin dengesiz olduğunu anlayabileceğimiz bir sistem")
Faz 1 (veri toplama + rapor). Bot oyuncular (faz 2) HENÜZ YOK.
- **Kaydedici**: `scripts/balance_log.gd` (static sınıf). Koşu bitince (`main.gd _record_run("end")` -> `_write_balance_record`) `user://balans/kosular.jsonl`
  dosyasına TEK SATIR JSON eklenir (Windows: `%APPDATA%\Godot\app_userdata\Temiz Sürüm\balans\`). 4 MB aşınca `kosular_eski.jsonl`'e taşınır.
  Debug modunda ve headless'ta yazmaz (headless'ta yalnız `LILSLAYERS_BALANCE_PATH` ortam değişkeni verilirse - testler/ileride bot).
- **Kayıt içeriği**: karakter, süre, kademe, öldürme, seviye, ölüm/zafer, öldüren aile, silahlar (+seviye +özellik), eşyalar, evrimler, kaynak başına hasar
  (`by_src`: `[hasar, isabet, kritik]`), alınan hasar yaratık ailesine göre (`taken_by`), kademe başına verilen/alınan hasar, kademeye ilk giriş süresi.
- **Hasar kaynağı etiketi**: `enemy.take_damage` kaynağı bilmez; çağıran hemen önce `BalanceLogScript.tag_weapon(self)` / `tag(&"...")` çağırır,
  `take_damage` başında `take_src()` okuyup siler. Etiketlenenler: weapon.gd (7 yer), projectile.gd (2), boomerang_projectile.gd, firework_projectile.gd (`w:fisek`),
  DOT tiki (`dot`). **Etiketsiz = "diger"** (yetenek Q/E/R, evrim, efsun, evcil hayvan...). Yetenek kırılımı için player.gd'deki ~23 `take_damage` yerine
  `BalanceLogScript.tag(&"s:q")` gibi satır eklenebilir (henüz yapılmadı - raporda "diger" payı bunu gösterir).
- **BALANCE_REV**: denge sabitlerini (hasar/can/bekleme/yaratık gücü) değiştirince `balance_log.gd BALANCE_REV`'i BİR ARTIR; rapor yalnız en son revizyonu analiz eder.
- **Çok oyunculu (B)**: istemci koşu sonunda kaydını `NetworkManager.submit_balance_record` (any_peer, call_remote, reliable) ile host'a yollar; host `ingest_remote` ile
  doğrular (şema, 20 KB sınırı, peer başına 20 kayıt) ve kendi dosyasına `via:"host"` ile ekler. Yeni RPC = eski exe ile uyumsuz (herkes yeni sürümü almalı).
- **Elle toplama (A)**: Rekorlar ekranında "BALANS VERİSİ KLASÖRÜ" düğmesi (sadece PC) klasörü açar; arkadaşın `kosular.jsonl` dosyası `docs/balans/gelen/` içine konur.
- **Rapor**: `powershell -ExecutionPolicy Bypass -File tools/balans_rapor.ps1 [-Girdi <klasör>] [-Rev N] [-MinKosu 3]` -> `docs/balans/rapor.md`
  (karakter/silah/ölüm kademesi/yaratık/eşya tabloları + "Öne çıkanlar" aykırı değer listesi). Aynı `run_id` iki dosyada olsa bir kez sayılır.
  Silah hasar/sn'de sahip olunma zamanı bilinmediği için geç alınan silah düşük görünür (raporda not var).
- Test: `tests/test_balance_log.gd` (5 test). Faz 2 fikri: headless bot (en yakın düşmana git, yetenek bas, kart seç) + `LILSLAYERS_BALANCE_PATH`.

## 76. YAĞMUR + AKARSU SESİ (2026-10-11, kullanıcı: masaüstündeki `yağmur ambiyans.mp3` ve `akarsu hışırtı.mp3`)
- `tools/make_seamless_ambience.py` (gerekir: `pip install imageio-ffmpeg`, numpy): mp3'leri çözer, SON `X` sn'yi İLK `X` sn'ye eşit güçlü (sin/cos) çapraz geçişle
  karıştırıp kuyruğu atar -> dikişsiz döngü (uçlar sessiz değil, sıçrama yok; ölçülen dikiş/tipik örnek farkı oranı yağmur 1,27 / akarsu 0,32). Çıktı OGG
  (`assets/audio/rain_ambience_loop.ogg` 87 sn, `stream_loop.ogg` 12,8 sn); OGG `loop=true` Godot'ta örnek-hassas döner. Akarsu kaynağı çok kısıktı (-44 dBFS) -> -26 dBFS RMS'e normalize.
- **Yağmur**: `atmosphere.gd RAIN_SOUND_PATH` yeni dosyaya geçti (eski `weather_rain_loop.wav` yerinde duruyor, kullanılmıyor). `RAIN_VOLUME_DB` -15 -> -8: eski döngüyle AYNI
  etkin seviye (eski RMS -18,9 + -15 ≈ yeni -26,5 + -8). Yağmur şiddetine göre açılma/kapanma mantığı aynen (`_set_loop_volume`).
- **Akarsu**: `scripts/stream_ambient.gd` (main.gd `_ready`'de `StreamAmbient` düğümü). Oyuncunun en yakın SU karosuna (`GameManager.get_water_layer()` = Harita/Su/Su, 3679 karo)
  uzaklığı: <=80 px tam seviye (`MAX_DB` -7), >=640 px sessiz, arası smoothstep; üstel yumuşatma, -38 dB altında stop. Ev içinde (`is_indoors`) susar. Sorgu 5 Hz, ~0,16 ms.
  Ayarlar dosyanın başındaki sabitler. Test: `tests/test_stream_ambient.gd`. DİNLENEREK AYARLANMADI - seviyeler ölçümle; kullanıcı kulakla ince ayar yapabilir.

## 77. SALDIRI HIZI ÜST SINIRI %600 + TAŞMA = CANLI SALDIRI GÜCÜ (2026-10-11)
- `GameManager.ATTACK_SPEED_CAP_PERCENT = 600` (aralık çarpanı >= 1/7), `ATTACK_SPEED_OVERFLOW_AP_PER_PERCENT = 0.5` (TEK kaynak; player.gd + weapon.gd okur).
- `player.gd`: `_attack_interval_mult_uncapped()` (kart x Elara pasifi x (1 - eşya - ruhani Adc); eşya tabanı 0,1 -> 0,01 oldu ki taşma ölçülebilsin),
  `get_attack_interval_mult()` / `get_attack_speed_bonus_percent()` artık sınırlı (stat ekranı, pet, kopya, uzak oyuncu hep sınırlı değeri görür).
  Taşma = sınırsız toplam - 600; `_sync_attack_speed_overflow_ap()` (her kare, `_process_new_item_passives`) `damage_bonus`'a YALNIZ farkı ekler/çıkarır (Son Şans deseni):
  **kalıcı değil**, geçici buff (Adc, Işığın Muhafızı...) bitince/eşya satılınca kazanılan güç geri alınır; araya giren kalıcı güç (kart) korunur.
- `weapon.gd _effective_fire_wait`: kart/eşya havuzu DIŞINDAKİ hızlandırmalar (efsun, Matthew/Talon çarpanları, Elara E) da silahın taban hızının (dükkan seviyesi dahil)
  en çok 7 katına çıkabilir (aralık tabanı). Bu dış hızlandırmalar taşma/saldırı gücü hesabına GİRMEZ (silah başına olduklarından oyuncu toplamında yoklar).
- Test: `tests/test_attack_speed_cap.gd` (5). Not: `damage_bonus` yetenek hasarlarını da büyüttüğünden taşma gücü yeteneklere de yansır.

## 78. NECROMANCER EVRİMLERİ + ULTİ REWORK (2026-10-11, kullanıcı isteği)
- **Evrim kartları**: `skill_evolutions.gd` DEFS[11] (Q 4+final, E 4+final, R 2+final); `tests/test_skill_evolutions.gd` EVO_CHARS'a 11 eklendi.
- **Temel değerler kötüleşti** ("geliştirmelere eklenmeli"): yaratık sınırı 20 -> 10, iskelet ruh bedeli 5 -> 8, golem 25 -> 50, golemin 6sn'lik sersemletme vuruşu KALDIRILDI
  (`golem_pet.gd _process_golem_slam` silindi), kafatasının 3sn korkusu KALDIRILDI. Evrimler: Q1 sınır 20, Q2 iskelet 5 ruh, Q3 iskelet canı x1,2 (iskeletin kalkanı yok -> yalnız can),
  Q4 iskelet ömrü +15sn, QF "Kemik Fedası"; E1 golem 35 ruh, E2 golem saldırısı geri iter (70 px `apply_skill_push`), E3 golem can+kalkan x1,3, E4 golem x1,2 boy/alan/hasar, EF "Son Çare Golemi".
  Sayılar `player.gd EVO_NECRO_*`, `golem_pet.gd EVO_*`, `necro_skull.gd EVO_*`; erişimciler `necro_max_active_pets/necro_skeleton_soul_cost/necro_golem_soul_cost`.
- **Finaller** (`player.gd _process_necro_final_evos`, her kare): can %20'nin altına İNDİĞİ an bir kez; can %20 üstüne çıkınca yeniden kurulur (yeni iskelet hemen tüketilmesin).
  QF: tüm iskeletleri `_expire()` eder, iskelet başına `damage_bonus x %10` can VE kalkan (2026-10-11'de %5 -> %10; saldırı gücü 60 ise iskelet başına 6 can). EF: bedelsiz golem (yaratık/golem sınırına takılmaz),
  800 px içindeki tüm yaratıklara `apply_taunt(6sn, golem)`, 120sn bekleme. Çok oyunculuda host olmayan Necromancer: `enemy.gd apply_taunt` "taunt_ally" isteği yollar, host
  `network_manager.gd` o oyuncunun EN YENİ golem kopyasını (`remote_player.gd get_newest_golem_visual`) kışkırtan yapar.
- **Ulti rework** (`necro_skull.gd` baştan yazıldı): R açılınca (10. seviye, `_process_necro` -> `_ensure_necro_skull`) %50 küçük kafatası KALICI olarak sahibin etrafında döner (elips yörünge),
  `PASSIVE_SEEK_RANGE` 380 px içinde yaratık görünce çakılır (%60 AP, vuruş yarıçapı 34 px). R tuşu (`set_active(10)`) -> %100 büyür, yarıçap 68, %150 AP, arama 620 px; süre bitince (`_end_skill3_effects` 44) pasife döner.
  Evrimler: R1 `apply_fear_wander(1sn)`, R2 vuruş hızı = 1/`get_attack_interval_mult()`, RF "Lanetli Mühür" = `apply_element("vuln",{pct .10, dur 10})` + `player.gd _necro_curse_mark`:
  lanetli yaratık ölünce (kukla `is_dead` her istemcide olur, 0,1sn'de bir yoklanır) %1 ihtimalle iskelet (pet sınırına saygılı).
  Hedef taraması artık `EnemyQuery.candidates` (C++ ızgara; kafatası kalıcı olduğu için "enemies" taraması yapılmaz).
- **Ağ**: `necro_skull` (güvenilir: start/mode/hb/end) + yeni `necro_skull_leg` (güvenilmez: sık bacaklar). Kopya boştayken sahibin KUKLASININ etrafında döner (`setup_network(pos, peer)`),
  4sn'de bir "hb" paketi sonradan katılanlarda kopyayı kurar. Golem kopyası `apply_necro_evos(remote_player)` ile E4 boyutunu sahibin `has_evo` listesinden alır.
  **İKİ PENCERELİ (host olmayan Necromancer) GÖZLEM YAPILMADI** - kafatası dönüşü, aktif büyüme, golem boyutu, Son Çare kışkırtması orada izlenmeli.
- Karakter metinleri (`characters.gd`) güncellendi. Testler: `tests/test_necro_evolutions.gd` (13), `tests/test_necro_skull.gd` (13). `BALANCE_REV` 3.

## 79. MELEK ULTİ REWORK - Kutsal Korku (2026-10-11, kullanıcı isteği)
- **Yetenek** (skill3 id 32, ad/ikon aynı): `player.gd _skill_melek_fear`. TEK merkez Melek (eski "bağlı dostların etrafında da korku" kalktı).
  Yarıçap `MELEK_FEAR_RADIUS` (= `fx_melek_holy.gd RADIUS` 260). Normal yaratık: `apply_skill_push` 140 px + `apply_fear` 5 sn. Boss (`is_boss`; elitler normal sayılır):
  `apply_skill_push` 400 (enemy x0,4 -> ~160 px) + `apply_slow(0.80, 5, allow_boss=true)`. `enemy.gd apply_slow` tavanı 0.75 -> **0.80** (eşya yığılması da en fazla %80).
  Boss yavaşlatması EW yürüme hızına işler; boss özel hamleleri (Minotaur hücumu vb.) kendi hızlarıyla gider.
  Anında can + kalkan = `damage_bonus x 1.0` (kritik zarı tek): kendine `heal`+`heal_shield`, yarıçaptaki "player_ally"lere `_apply_heal_to_ally`/`_apply_shield_heal_to_ally` + "holy" aura. 120 sn.
- **Havalanma**: `SKILL3_TIMING[32].duration = MELEK_R_ASCEND_TIME = fx_melek_ascend.gd LIFE (2.0)`; `_melek_ascending()` (R aktif ve id 32) `_physics_process` hareket kilidine eklendi.
  Görsel `scenes/fx_melek_ascend.tscn` (`_play_and_broadcast_skill_fx` -> uzak kuklada da): arka katmanda PixelDraw kanatlar (omuz `SHOULDER (0,-16)`, 7 tüy, açılır/çırpar/söner),
  ön katmanda karakter karesinin ADD-blend altın kopyası (asıl `anim.modulate`'a dokunulmaz), `anim.offset` 7 sanat pikseli yukarı (çıkışta geri; Hadime'nin offset kaldırmasıyla aynı yol, karakter 10'da çakışma yok).
- **Evrimler** (kimlikler aynı): r1 "Bedelsiz Işık" = `_evo_skill_free` 10/skill3 + `EVO_MELEK_R_CD_MULT` 0.85; r2 "Kutsal Lütuf" = `get_heal_shield_power()` +0.15
  (YENİ getter: `heal_power_mult`, Aegis/Güneş, `stats_panel.gd`, `merchant_shop_screen.gd` artık bunu okur); rf "Yeniden Doğuş" = Q/E bekleme sıfır. Eski `_melek_fear_evolutions` silindi.
- Testler: `test_skill_evolutions.gd test_melek_r_rework`, `test_pixel_fx_pack.gd` (yarıçaptaki dosta parıltı + havalanma/geri dönüş). `BALANCE_REV` 5.
  **Görsel gerçek pencerede GÖZLENMEDİ** (kanat boyutu/omuz hizası `SHOULDER`/`LIFT_ART_PX` ile ayarlanır); iki pencerede host olmayan Melek ile de bakılmalı.

80. **Yaratık hasarı x0,8 İPTAL + can çalma 1 can + Balkabağı güçlendirme (2026-10-11).** Kullanıcı: "balkabağı bossu çok güçsüz" -> 1+2+3+5 paketi; "%20 hasar azaltmayı tüm yaratıklardan iptal et"; "can çalma 1 can vermeye devam etsin".
- `enemy_spawner.gd CREATURE_DAMAGE_CUT` 1.0 (çarpan kodda kaldı, etkisiz); boss sabitleri eski hâline: Balkabağı ateş topu 20 / kabak patlaması 40 (`pumpkin_*`), Wendigo 100/130, Banshee çığlık 260, Şeytan 200/100/150, yanma 50/sn, yarasa kanaması 10/sn. Yeraltı Canavarı -%40'ı AYRI istekti, dokunulmadı (46,8 / 39,6). `GameManager.LIFESTEAL_HEAL` 2 -> 1.
- Balkabağı (`pumpkin_boss.gd`): (1) ATILIŞ: 0,55 sn hazırlık, sonra `enemy.gd set_gate_rush` kanalıyla 1 sn x4,5 hız (faz 2: x5,5), 6-8 sn'de bir, 120-560 px + görüş hattı; `enemy_spawner` kapı hızlandırma döngüsü bosslara dokunmaz. (2) boss hızı 72 -> 100 (sahne), ateş topu 190 -> 250, halka 150 -> 190, nişan hedefin hareketini önden alır (`LEAD_FACTOR` 0,85). (3) FAZ 2 (can+kalkan <%50): salvo 7 -> 11 top, halka 16 -> 24 + 0,7 sn sonra kaydırılmış ikinci halka, kabak/yarasa dalgaları x1,5 (tavanlar aynı), atılış x5,5.
- Testler: test_pumpkin_boss (yeni: atılış, faz 2 salvosu), banshee/wendigo/demon/minotaur/tier_pacing/boss_kademe_gate/balance_2026_09_21 geçti. `BALANCE_REV` 6. Görsel/his gerçek oyunda denenmedi (atılış hızı x4,5 fazla/az gelirse `DASH_MULT`).
