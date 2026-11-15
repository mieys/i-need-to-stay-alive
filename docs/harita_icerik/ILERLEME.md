# HARİTA İÇERİĞİ - İLERLEME (plan: PLAN.md)

Her aşama bitince buraya: ne yapıldı, hangi dosyalar, hangi testler geçti, ölçülen/denenen, açık kalanlar, plandan sapmalar.

## Aşama 1 - 10 kademe + K5/K10 boss + K10'da zafer + yeni elit düzeni: UYGULANDI (2026-11-11, kullanıcı oynayıp ayarlayacak)

Yalnız genel tablolar: şimdilik TÜM haritalar ana haritanın tablolarını kullanır (harita profiline bağlama Aşama 2/3). CLAUDE.md madde 599, BALANCE_REV 151.

### Yapılanlar (plan bölüm 6, Aşama 1 maddeleri)
1. `scripts/enemy_spawner.gd`: `LAST_TIER := 10`; "15" varsayımı olan yerler buna bağlandı (`_current_tier`, `_check_tier_announcement`, `_on_became_host`,
   `spawn_guard` / `spawn_dungeon_creature` ileri kademe kısması). `TIER_ROSTER` ana harita 10 kademe (bölüm 3 tablosu aynen).
2. Bosslar: `NEW_BOSS_TIERS = {5: ["minotaur1"], 10: ["wendigo1"]}`. K10 bossu doğunca `_final_spawned` + `_final_bosses` (zafer `_check_victory` değişmedi).
   Kademe saati K10 sınırında bekler (zaten `_tier_time` boss tutuşu). Banshee gece kilidi KİMLİĞE bağlandı (`NIGHT_BOSS_IDS := ["banshee1"]`, `needs_night`).
   `_check_auto_endless` son boss tanımlıyken kapalı: sonsuz moda yalnız zaferden sonra "Sonsuza Devam Et" ile girilir (boss hiç doğmazsa oyun K10'da bekler,
   otomatik sonsuz ya da zafer yok - önceki Final de aynı şekilde doğana kadar bekliyordu).
   ESKİ FİNAL YOLU KALDIRILDI (planın "kalsın ya da kaldır" seçeneği, kaldırmak daha az karışıklık): `FINAL_TIER`, `BOSS_TIERS` (13'lü), `FINAL_CREATURES`,
   `NEW_FINAL_BOSSES`, `new_final_enabled`, Final kapısı (`_final_gate_open`, `_final_pending`, `_check_final_tier`, `_final_gate_wait_started_msec`).
   `GameManager.bosses_enabled` değişkeni duruyor ama spawner artık OKUMUYOR (yalnız `endless_has_boss_waves()`).
3. Boss statları: `BOSS_SLOT_STATS` (K5 50.000/60.000, K10 300.000/400.000), `BOSS_SLOT_OVERRIDES` (Yeraltı K5 36.000/44.000), `BOSS_HOME_TIER` + `boss_slot_damage_mult`
   (hasar = eski x (3+2,2·yeni)/(3+2,2·eski); Yeraltı ek x0,8) + `boss_fixed_stats(id, tier)`; host `_setup_boss_enemy` ve istemci AYNI işlevi çağırır.
   Boss betikleri `boss_damage_mult` metasından okur: Minotaur (temas hasarı `contact_damage` üstünden, otomatik) ve Wendigo (`wendigo_boss.gd _spawn_fx`) BAĞLANDI.
   Soğurma/boyut/ödül referansı bossun kendi `FIXED_BOSS_STATS` satırında kaldı. Sonsuz dalga bossları (kademe > LAST_TIER) yuva tablosuna girmez.
4. Elit: `ELITE_BY_TIER` {2 iskelet3, 4 zombie3, 6 lich3, 8 ork3, 10 agac3}; `_roll_elite` yalnız çift kademede; boss kademesinde (K10) vade en geç kademenin
   ilk yarısı. Elit tabanı `pool_stats(id, kademe, true)`: P = kademe+2, can (10+9P)·max(1, aile can çarpanı), hasar (3+2,2P)·aile hasar çarpanı, xp 2+2P
   (host: `_spawn_regular_enemy` + `spawn_mission_elite`; istemci: `_rpc_client_spawn_creature`; hepsi `_apply_base_stats` -> kademe ölçeği -> kalkan -> global -> `make_elite`).
   Eski `ELITE_POOL` + aileye göre `elite_candidates` silindi; `elite_candidates(t)` artık tablodaki elit (tek kademede en yakın alt çift kademe: Ritüeli Boz cezası).
   Sıradan yaratık SAHNE değerleriyle doğar (`pool_stats` boş döner; ana harita bugünkü denge). Test: elit canı kademeyle artıyor (46 -> 83 -> 90 -> 125 -> 212 taban).
5. Sonsuz mod: `endless_math.gd BASE_TIER` 15 -> 10 (kat 1 = ölçek kademesi 11, bileşik baskı kat 2'den); sonsuz boss dalgası HARİTANIN KENDİ bosslarından
   (`_endless_wave_pool()`: ana = Minotaur + Wendigo; dalga boyutu havuzdan büyük olamaz -> en çok 2); sonsuz kat eliti = 5 elitten rastgele (`_pick_elite_id`).
6. Diğer dosyalar: `tier_display.gd FINAL_TIER` 16 -> 10 (K10 başlığı "FİNAL KADEMESİ", 6 kırmızı kafa, kafa adımı kademe·12/10), `main.gd` kademe sarsıntısı K10'da,
   `achievements.gd` `tier_15` + `final` silindi (kalan `tier_5`, `tier_10`), `network_manager.gd` / `game_manager.gd` yorumları. `records_screen` / `game_over_board` /
   `phone_game_over` `TierDisplay.FINAL_TIER`'a bağlı olduğu için ek değişiklik gerekmedi (K10'a ulaşan "FİNAL" yazar). Başka dosyada "15"/"16" kademe varsayımı çıkmadı
   (`tier_system`, `food_drop`, `shield_orb_drop`, `level_special_cards`, `guard_camps`, `necro_skull`, `banshee_boss`, `meta_progress` tarandı).
7. Ruh Kıymığı (`meta_progress.gd`) DEĞİŞTİRİLMEDİ (plan). 7b. Denge kaydı: kayda `map` + `boss_fights` (`BalanceLog.note_boss_spawn/death`), `tools/balans_rapor.ps1`
   "Haritalar" + "Bosslar" bölümleri; `LATE_PRESSURE` K6-10 can/hasar tablosu (hepsi 1,0, `_enable_regular_shield` içinden uygulanır).
8. Testler: yeni `tests/test_map_content_phase1.gd` (eski `test_elite_pool_and_bosses_off.gd` SİLİNDİ, yerine). Güncellenenler: `test_boss_kademe_gate_and_balance`,
   `test_creature_tier_announcement`, `test_tier_starts_when_previous_dead` (Final kapısı testleri -> son boss kapısı; kafa satırı 10 kademe), `test_endless_mode`,
   `test_endless_math`, `test_minotaur_boss`, `test_underground_boss`, `test_pumpkin_boss`, `test_wendigo_boss`, `test_banshee_boss`, `test_demon_boss` (final akışı testi silindi,
   zafer akışı yeni dosyada), `test_boss_bar_top`, `test_new_creature_pool`, `test_host_migration`, `test_run_records`, `test_victory_and_records_ui`.
9. Doğrulama: `tools/harita_icerik/duman_asama1.gd` + MP denetimleri: aşağıdaki "Doğrulama sonuçları" (5 haritada da temiz).

### Kararlar / plandan sapmalar (kullanıcı bilsin)
- `_tier_crowding_scale` (yaratık tavanının kademeyle büyümesi) 14 kademelik eğriyle KALDI: K10 başında tavan ~%73 (eskiden K10'da da ~%64'tü, yani K1-10 eğrisi aynı). Tam tavan
  yalnız sonsuz modda (kademe saati 2100 sn'yi geçince). Plan "K1-10 ölçek DEĞİŞMEDİ" dediği için dokunulmadı; sıkmak istenirse `LATE_PRESSURE` ya da bu eğri.
- Debug menüsü kademe seçici 1-15 kaldı (11+ sonsuz ölçek kademelerini hata ayıklamak için işe yarar); K5/K10 yuvası debug'dan doğan bossa da uygulanır.
- `GameManager.bosses_enabled` kaldırılmadı (testler/araçlar değişkeni atıyor), yalnız etkisiz.
- `test_endless_math`: `FIRST_WAVE_SIZE` / `MAX_WAVE_SIZE` (13'lü Final) sabitleri artık spawner'ca kullanılmıyor ama testleri duruyor; temizlik Aşama 3'te.
- Sonsuz mod başlangıç ölçeği 16 -> 11: sonsuz Kat 1 eskisinden ZAYIF (yaratık ölçeği + elit/boss dalgaları). Zaferden sonra oyuncular çok güçlü olacağından bu bilinçli (plan).
  Kat bileşik baskısı (madde 269) kat 2'den aynı hızla devam eder; veri gelince ayarlanır.

### İzlenecekler (kendiliğinden değiştirilmedi)
- Elit sayısı yarıya indi (kademe başına 1 -> 2 kademede 1): elit sandık/parçacık geliri düşer.
- Ödül tabloları kademe dilimli: `enemy.gd` sandık şansı (`_current_tier <= 10` -> 0,009, 11+ -> 0,010) ve kalite dilimleri 11+ artık yalnız SONSUZDA devreye girer (normal oyun K10'da biter).
  Ödül gelirinin ters yönde değişip değişmediği kayıt verisiyle bakılmalı.
- `tools/buyuk_test` `crowd` kipi hâlâ 15 kademe tarıyor (K11-15 roster yok -> boş) ve `tools/tanitim` `kademeler` çekimi 15 kademeye göre yazılı; güncellenmedi.
- Çeviri: başarım açıklaması "Final'in tüm bosslarını yenip zafer kazan." artık tek bosslu düzene tam uymuyor ama msgid (Türkçe metin) değiştirilmedi (10 dilde .po güncellemesi gerekir).
- `test_mp_hardening.gd::test_spawner_uses_the_real_player_count_for_enemy_health` BU işten bağımsız eskimiş (madde 504); dokunulmadı.
- Boss betiklerinden Balkabağı / Banshee / Uçan Şeytan / Yeraltı uzuvları `boss_damage_mult` metasına HENÜZ bağlı değil (Aşama 3'te kendi haritalarında K5/K10'a girerken bağlanacak).
- Zafer penceresi + oyun sonu rekor/başarım ekranı gözle bakılmadı (duman testi yalnız mantığı sınar).

### Doğrulama sonuçları
- Birim testleri YEŞİL: `test_map_content_phase1` (19), `test_boss_kademe_gate_and_balance`, `test_creature_tier_announcement`, `test_tier_starts_when_previous_dead`, `test_endless_mode`,
  `test_endless_math`, `test_minotaur_boss`, `test_underground_boss`, `test_pumpkin_boss`, `test_wendigo_boss`, `test_banshee_boss`, `test_demon_boss`, `test_boss_bar_top`,
  `test_new_creature_pool`, `test_host_migration`, `test_run_records`, `test_victory_and_records_ui`, `test_balance_log`, `test_game_notice`, `test_guard_camps`,
  `test_enemy_spawner_gate_and_ambush`, `test_game_over_screen_order`, `test_mission_tree`, `test_world_event_new_missions`. TAM PAKET (`run_tests.ps1` filtresiz) KOŞULMADI (kota kuralı).
- Başsız duman `duman_asama1.gd` (gerçek Main, `HARITA=<id>`): ana, bataklik, col, batik_nekropol, lagim_agi -> 5 haritada da: yüklenen harita istenen, K5 Minotaur 50.000/60.000,
  K10 Wendigo 300.000/400.000, son boss ölünce zafer, Sonsuza Devam Et Kat 1, kademe bildirimi 10'u geçmiyor. (Not: dört haritada doğan boss hâlâ ana haritanın Minotaur/Wendigo'su;
  zindan haritalarında bile boss doğuyor = Aşama 1 sonu "zindan haritasında çalışıyor mu" sorusunun cevabı EVET. Yeni bossların kendi zindanında davranışı Aşama 5.)
- Çok oyunculu: `run_audit.ps1 -Mode bosscatchup` + `boss_catchup_audit_compare.py` TEMİZ (host/istemci boss stat/kademe/havuz aynı); `-Mode minotaur` ve `-Mode sync` koştu,
  yeni hata yok (`sync`te host'ta 17 "Lambda capture ... freed" satırı = madde 425'te kayıtlı ESKİ açık sorun, bu işle ilgisiz). Dikkat: bu denetimler boss'u elle doğurur (K3/K5),
  K10 yuvasının istemci kurulumu ayrıca denenmedi - aynı `_setup_boss_enemy` yolunu kullandığı için beklenen temiz.
- `tools/balans_rapor.ps1` yeni bölümleri sentetik rev-151 kayıtlarıyla denendi (Haritalar + Bosslar tabloları üretiliyor; gerçek veri yok).
- Gözle bakılmadı: K10 "FİNAL KADEMESİ" bildirimi / kırmızı kafalar, zafer penceresi, gerçek bir tam oyun (10 kademe ~25 dk). Kullanıcı oynayınca K5 boss süresi ve K10 zorluğu (plan bölüm 5b
  hedefleri) ölçülür; ayar kuralı planda.

## Aşama 2 - Haritaya özel havuz + hesaplanan stat + haritaya özel elit: BAŞLANMADI

## Aşama 3 - Mevcut bossların dağıtımı + harita başına zafer: BOSS DAĞITIMI YAPILDI (2026-11-14, madde 682), zafer kaydı harita başına YAPILMADI
- Profil `bosslar` + `enemy_spawner.gd boss_tiers_for_map`: ana Minotaur/Wendigo, bataklik Gonca(yeni)/Banshee, col Yeraltı/Medusa(yeni), batik_nekropol Balkabağı/Uçan Şeytan,
  kis Minotaur(ana ile ortak)/Wendigo (ana K10'u Üç Kardeş oldu). Lağım Ağı oyundan kapalı. Balkabağı + Uçan Şeytan özel hasarları `boss_damage_mult`'a bağlandı.
- Açık: 4. madde (victories_by_map, rekor/harita seçimi işareti) yapılmadı; bosslar kendi haritalarında oyun içinde denenmedi (3. madde).

## Aşama 4 - Harita anahtarları: UYGULANDI (2026-11-12, madde 605; 4.0-4.4 + 4.6 tamam, 4.5 BOZDUR/geliştirme anahtarı YAPILMADI - kullanıcıya sorulacak)
- Görseller: kullanıcının Desktop.zip'indeki 7 çizimden 5'i `assets/ui/anahtar/`'a (eşleme temaya göre benim seçimim, notta); `key_icon.gd` + `key_icon_box.gd`.
- Kayıt/kural: `meta_progress.gd` (`keys`, `KEY_COSTS`, anahtarlı `can_buy`/`buy`/`lock_text`), kazanım `GameManager.award_boss_keys` + `NetworkManager.broadcast_boss_keys` (lobi-32), `enemy.gd die()` host kancası.
- Arayüz: Ruh Mağazası fiyat satırı/düğme/ayrıntı notu + ANAHTARLAR bölümü (masaüstü; telefonda sayfa YOK), bildirim levhası, zafer + oyun bitti satırı.
- Doğrulama: `test_meta_keys` (22) + ilgili testler yeşil, `run_audit.ps1 -Mode anahtar` TEMİZ, Ruh Mağazası + levha görsel yakalaması bakıldı (`tools/anahtar_gorsel/`).
- Açık: adetler tahmin; K10 zafer penceresi anahtar satırı gözle bakılmadı; Aşama 3 bitmeden dört haritada da boss ana haritanın bossu.

## Aşama 5 - yeni bosslar: 2 / N YAPILDI (2026-11-14, madde 682)
- Zehirli Gonca (Bataklık K5) + Medusa (Çöl K10 / son). Kullanıcı bossların yerini kendisi seçti (plan tablosundaki Nekropol/Lağım YENİ yuvaları yerine);
  yeri değişen Balkabağı + Uçan Şeytan Nekropol'e gitti. Ayaz Dağı K10 Wendigo; K5'i yeni boss gelene kadar ana ile ortak Minotaur.
