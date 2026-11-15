# HARİTA İÇERİĞİ PLANI: 10 kademe, haritaya özel yaratık havuzu / elit / boss, anahtar sistemi

Yazıldı: 2026-11-11. Kullanıcı kararlarıyla hazırlandı; uygulayan model bu dosyayı ve `ILERLEME.md`'yi okuyarak çalışır.
Bu iş kullanıcının açık isteğidir (cila dönemi hatırlatması yapıldı, kullanıcı devam dedi) - yeniden hatırlatma.

## 0. Çalışma kuralları (uygulayan için)

- Her oturumda TEK aşama. Aşama bitince `ILERLEME.md`'ye ne yapıldığını, hangi testlerin geçtiğini, açık kalanları yaz.
- "KULLANICIYA SOR" yazan yerde tahmin yürütme, sor. "BAŞLANGIÇ DEĞERİ" yazan sayılar benim (planı yazanın) tahminidir: uygula, notta
  "tahmin" diye belirt, kullanıcı oynayıp ayarlar.
- CLAUDE.md kuralları aynen geçerli: ilgili testler `-Filter` ile, denge sabiti değişince `balance_log.gd BALANCE_REV` artır, RPC imzası /
  durum alanı değişince `network_manager.gd LOBBY_PROTOCOL` artır, host'tan gelmesi gereken RPC'ye `_from_host()`, otomatik commit/export yok.
- Her aşama sonunda `docs/notlar/madde_161-170.md`'ye yeni madde + CLAUDE.md dizinine tek satır.
- Aşağıdaki satır numaraları 2026-11-11 hâlidir, kayabilir: işlev/sabit ADIYLA ara.
- Kapsam dışı, DOKUNMA: zindan sakinleri/avcıları (DungeonManager harita kipi), bekçi kampları, görev dalgalarının kuralları, C++ yaratık
  AI'ı, seçilemeyen haritalar (`secilebilir: false`).

## 1. Verilen kararlar

1. TÜM haritalarda oyun 10 kademe (eski 15 + Final). Kademe süresi aynı (`tier_duration` 150 sn).
2. Her haritada 2 boss: Kademe 5'te 1. boss, Kademe 10'da 2. boss. 2. boss ölünce o haritada ZAFER (harita başına kaydedilir). Ayrı
   "Final kademesi" (16) yok. Zaferden sonra sonsuz mod bugünkü gibi ("Sonsuza Devam Et").
3. Her haritanın kendi sıradan yaratık havuzu var (bölüm 3).
4. Elitler: 2 kademede 1 (K2, K4, K6, K8, K10), haritanın kendi 5 eliti, zayıftan güçlüye (bölüm 4). Eskiden kademe başına 1 elitti.
5. Yaratık can/hasar/XP'si doğduğu kademeye göre HESAPLANIR (bölüm 5); aynı yaratık farklı haritada farklı kademede doğabilir.
6. Anahtar sistemi: her haritanın TEK anahtar türü var, o haritanın bossları her öldürmede düşürür (K5: 1, K10: 2); bazı karakter ve
   evciller Ruh Kıymığı + anahtar ile alınır (anahtar ek şart, fiyatın yerine geçmez). Ayrıntı: Aşama 4.
7. Seçilebilir haritalar: `ana`, `bataklik`, `col`, `batik_nekropol`, `lagim_agi`.

## 2. Bosslar

| Harita | K5 | K10 |
|---|---|---|
| ana | `minotaur1` | `wendigo1` |
| bataklik | `balkabagi1` | `banshee1` |
| col | `underground1` | `ucansetan1` |
| batik_nekropol | YENİ (Aşama 5) | YENİ (Aşama 5) |
| lagim_agi | YENİ (Aşama 5) | YENİ (Aşama 5) |

- Yeni bosslar gelene kadar `batik_nekropol` ve `lagim_agi` geçici olarak ana haritanın bosslarını kullanır (`minotaur1` / `wendigo1`).
  Zindan haritasında düzgün çalıştıkları DOĞRULANMADI: Aşama 1 sonunda her seçilebilir haritada dene.
- Banshee gece bossu: `NIGHT_BOSS_TIERS` kademe yerine KİMLİĞE bağlanmalı (ör. `NIGHT_BOSS_IDS := ["banshee1"]`); yeraltı haritasında gece yok.
- Stat BAŞLANGIÇ DEĞERLERİ (`FIXED_BOSS_STATS`; gerçek koşu kayıtlarından hesaplandı, gerekçe bölüm 5b; kullanıcı oynayıp ayarlar):
  - K5 yuvası: can 50.000, kalkan 60.000. Soğurma (`protection`) her bossun bugünkü değeri.
    İSTİSNA Yeraltı Canavarı (col K5): can 36.000, kalkan 44.000 ve uzuv hasarları x0,8 (asit 110 -> 88, savurma 130 -> 104) - kayıtlarda
    K5'teki 8 kalıcı ölümün 8'i de bu bossun uzvundan; bugünkü hâli ortalama takım için duvar.
  - K10 yuvası (haritanın SON bossu): can 300.000, kalkan 400.000.
  - Hasar: boss betiklerindeki sabitler ESKİ kademeye göre yazılı. Yeni hasar = eski x (3 + 2,2 x yeni kademe) / (3 + 2,2 x eski kademe).
    (Bu oran kayıtlardaki oyuncu canı büyümesiyle örtüşüyor: vuruş başına can yüzdesi eski kademesindekiyle aynı kalır.)
    Eski kademeler: Minotaur 3, Yeraltı 5, Balkabağı 8, Wendigo 12, Banshee 15, Uçan Şeytan 16. Çarpanı tek tabloda tut (boss kimliği ->
    çarpan), boss betikleri (`pumpkin_boss.gd`, `wendigo_boss.gd`, `banshee_boss.gd`, `demon_boss.gd`, `worm_boss_math.gd`, minyonlar)
    oradan okusun; sabitleri tek tek elle değiştirme. Bugünkü değerler: `enemy_spawner.gd FIXED_BOSS_STATS`.
- Boss minyonları (`SUMMON_STATS`) kademeden ölçeklenir, ayrıca dokunma.

## 3. Sıradan yaratık havuzları (kademe -> kimlik listesi; seçim eşit olasılıklı, tekrar = ağırlık)

### ana (genel `TIER_ROSTER`, 10 kademeye iner; K1-8 BUGÜNKÜ, K9 = eski K10, K10 = eski K11-12 + 3. haller)
```
1: slime1, slime1, iskelet1        6: ork1, slime1, zombie3, iskelet2
2: slime1, iskelet1                7: lich1, lich2, ork1, ork2, iskelet2
3: slime1, zombie1, iskelet1, iskelet2   8: lich2, ork2, ork3, slime2, iskelet3
4: slime1, zombie1, zombie2, iskelet2    9: agac1, bitki1, golem1, mantar1
5: lich1, zombie2, zombie3, iskelet1, iskelet2   10: agac2, bitki2, bitki3, golem2, golem3, mantar2, mantar3
```
Eski K9 slime sürüsü ve K13-15 (demon/hayalet/röntgen/vampir/iblis) ana haritadan çıkar; o aileler diğer haritalarda.

### bataklik
```
1: slime1, slime1, zombie1         6: kertenkele1, kertenkele2, bitki2, mantar1
2: slime1, zombie1                 7: kertenkele2, bitki2, mantar1, agac1
3: zombie1, zombie2, kertenkele1   8: kertenkele2, bitki2, mantar2, agac1
4: zombie2, kertenkele1, bitki1    9: kertenkele2, mantar2, agac2, hayalet1
5: zombie2, kertenkele1, bitki1    10: kertenkele2, agac2, agac3, mantar2, hayalet2, hayalet3
```
### col
```
1: iskelet1, iskelet1, rat1        6: gnoll1, gnoll2, lich2, golem1
2: iskelet1, rat1, rat2            7: gnoll2, lich2, golem1, demon1
3: iskelet1, iskelet2, gnoll1      8: gnoll2, lich2, golem2, demon1, iblis1
4: iskelet2, gnoll1, lich1         9: gnoll2, golem2, iblis2, demon2
5: iskelet2, gnoll1, lich1         10: gnoll2, golem2, iblis2, iblis3, demon2
```
### batik_nekropol
```
1: iskelet1, iskelet1, zombie1     6: lich1, lich2, iskelet3, hayalet1
2: iskelet1, zombie1               7: lich2, iskelet3, hayalet1, vampire1
3: iskelet1, iskelet2, zombie2     8: lich2, hayalet2, vampire1, rontgen1
4: iskelet2, zombie2, lich1        9: hayalet2, vampire2, rontgen1, rontgen2, demon2
5: iskelet2, zombie2, lich1        10: vampire2, rontgen2, hayalet2, demon2, demon3
```
### lagim_agi
```
1: rat1, rat1, slime1              6: rat2, goblin2, pelte1, slime3
2: rat1, slime1                    7: goblin2, pelte1, slime4, zombie2
3: rat1, rat2, slime2, goblin1     8: goblin2, pelte1, pelte2, slime5, zombie2
4: rat2, slime2, goblin1           9: goblin2, pelte2, slime6, mantar1, mantar2
5: rat2, slime2, goblin1, goblin2  10: goblin2, pelte2, slime6, mantar2, mantar3
```
Notlar: fareler (`rat1..3`) sahneleriyle hazır, 17 Ekim'den beri doğmuyordu. Goblin/Gnoll/Kertenkele/Pelte (madde 575) ilk kez doğacak;
`tests/test_new_creature_pool.gd` "doğuş listesinde olmamalı" diyor, güncellenecek.

## 4. Elitler (harita -> kademe -> kimlik)

| Kademe | ana | bataklik | col | batik_nekropol | lagim_agi |
|---|---|---|---|---|---|
| 2 | iskelet3 | slime2 | iskelet3 | zombie3 | rat3 |
| 4 | zombie3 | zombie3 | lich3 | lich3 | goblin3 |
| 6 | lich3 | bitki3 | gnoll3 | hayalet3 | pelte3 |
| 8 | ork3 | mantar3 | demon3 | rontgen3 | zombie3 |
| 10 | agac3 | kertenkele3 | golem3 | vampire3 | slime7 |

- Tek kademelerde elit YOK. Zamanlama bugünkü pencere (`_roll_elite`: `ELITE_WINDOW_MIN/MAX`); K10'da elit kademenin ilk yarısında, boss sonda.
- Bir haritanın 5 eliti o haritada sıradan doğmaz (bölüm 3 tabloları buna göre yazıldı). İSTİSNA: ana haritada `iskelet3`, `zombie3`, `ork3`
  bugünkü gibi hem sıradan hem elit kalır (kullanıcıya soruldu, cevap gelmedi; varsayılan = ana haritanın K1-8'ine dokunma).
- Eski `ELITE_POOL` + aile eşlemeli `elite_candidates` yerine bu tablo. Sonsuz modda kat eliti = haritanın 5 elitinden rastgele.
- Elit çarpanları (`enemy.gd make_elite`: can/kalkan x15, hasar x1,5, boy x1,5) AYNI.
- Elit ödülleri (sandık vb.) değiştirilmedi; elit sayısı azaldığı için gelir düşer: nota "izlenecek" yaz, kendiliğinden artırma.

## 5. Stat kuralı (hesaplanan taban)

Bulgu (koddan doğrulandı): yaratık sahnelerindeki taban değerler şu formülden üretilmiş, P = yaratığın "güç seviyesi":
`max_health = (10 + 9 x P) x FAMILY_MULT[aile].hp`, `contact_damage = (3 + 2,2 x P) x FAMILY_MULT[aile].dmg`, `xp_value = 2 + 2 x P`
(aynı formül `enemy_spawner.gd boss_base_stats`'ta; `FAMILY_MULT` 19 ailenin hepsini içeriyor; xp gözlem, sahnelerden doğrula).
Doğuşta üstüne `enemy.gd apply_tier_scaling(kademe)` + `_enable_regular_shield` + `_apply_global_buff` biner - bunlar AYNEN kalır.

Kural:
- **ana haritanın sıradan yaratıkları**: dokunma, sahne değerleriyle doğar (bugünkü denge korunur).
- **diğer 4 haritanın sıradan yaratıkları**: sahne tabanı yerine P = `REF_P[kademe]` ile hesaplanan taban yazılır (can, temas hasarı, varsa
  `ranged_damage` aynı oranda, `xp_value`). Hız sahnedeki gibi. Tür (1/2/3) farkı yalnız görünüş + yetenek.
- `REF_P[kademe]` = ana haritanın YENİ 10 kademelik tablosunda o kademedeki yaratıkların ortalama P'si
  (P = (sahne max_health / aile hp çarpanı - 10) / 9). Bir araç betiğiyle bir kez hesapla (`tools/harita_icerik/ref_p.gd`, `-s`), sonucu
  sabit tabloya yaz, bir test tabloyu sahnelerden yeniden hesaplayıp karşılaştırsın (kaymasın). Böylece her harita ana haritanın eğrisinde.
- **elitler (5 haritada da)**: P = kademe + 2 ve aile can çarpanı en az 1,0 (`maxf(1.0, hp)`); sonra kademe ölçeği + `make_elite`.
  Bu kuralla 5 haritada elit canı kademeyle ARTAR (elle hesaplandı); test: "her haritada sonraki elit öncekinden güçlü".
  Neden +2: bugünkü elitler eski boss sahneleri (K4'te ~P6, K10'da P12) - +2 bugünkü K4/K10 elitiyle aynı, K6/K8'de ~%25 daha dayanıklı
  (elit artık yarı sıklıkta, biraz dolgun olsun), K2'de bugünkünden zayıf (bugün K1-2'de P8 yaratık elit oluyor: hasarı ~%40 fazla, sivri).
- Tek statik işlev (ör. `EnemySpawner.pool_stats(map_id, id, tier, elite)`); host doğuşu VE istemci kurulumu (`_rpc_client_spawn_creature`)
  aynı işlevi çağırsın (boss_base_stats'taki "iki kopya ayrışır" dersi). İstemciye ölçek kademesi gidiyor; sonsuzda P için
  `mini(ölçek, LAST_TIER)` kullan.
- Tuzak: yetenek hasarları (`enemy_abilities.gd`, `creature_shot.gd`, `creature_nova.gd`, `enemy_bone.gd`...) `contact_damage`'a oranlı mı
  sabit mi - bak; sabitse aynı oranla ölçekle. Uyuyan yaratığa stat yazmadan önce `_ew_wake()` (CLAUDE.md, madde 267/278).

## 5b. Denge: veri, hedefler, kalibrasyon (kullanıcı: "fazla kolay olmasın ama imkansız gibi zor da olmasın")

Veri: `kosular.jsonl` (BALANCE_REV >= 100, 42 kayıt / 19 oyun). Yeniden üretmek için:
`python -I tools/harita_icerik/balans_takim.py 100 "<kosular.jsonl yolu>"` (oyun bazında kademe başına takım hasarı + bitişler) ve
`balans_olum.py` (ölüm sebepleri, alınan hasar payları); kayıt yolu `tools/balans_rapor.ps1` başında. ÖRNEK AZ: K7 sonrası yalnız iki 4 kişilik (güçlü) oyun var, tek oyunculu veri yok.
- Oyunların çoğu K3-K5'te bitiyor. Kalıcı ölüm: K5'te 8/8 Yeraltı Canavarı uzvu, K3'te çoğu Minotaur; güçlü 4 kişilik takım K13'te
  yaratıklardan ölüyor (K6-K12'yi rahat geçiyor).
- Takım hasarı/sn (kademe boyunca ortalama): K3 2 kişi ~830, 4 kişi ~2.200; K5 2 kişi ~3.600, 4 kişi ~7.600; K10 4 kişi ~67.000-115.000
  (Talon zayıflatması öncesi). Oyuncu gücü K5 -> K10 arasında ~10 kat büyüyor; boss canı buna göre seçilmeli.
- Oyuncu canı (bitiş): K3 ~330-400, K5 ~520-550, K7 ~700-850, K13 ~1.000-2.400.
- Boss dövüşü gerçek süresi = ham süre (havuz / takım hasarı) / ~0,5 + mekanik payı (~50 sn). Bugün: Minotaur K3 2 kişi 120-160 sn,
  zayıf 3 kişilik takım 4-5 dk; Yeraltı K5 150-235 sn; Balkabağı K8 ve Wendigo K12 güçlü 4 kişide 60-110 sn.
- Bosslara ek oyuncu başına +%50 can/kalkan biniyor, takım hasarı ise kişi sayısıyla tam katlanıyor: tek oyuncu için dövüş en uzun.

Seçilen başlangıç değerlerinin beklenen sonucu (hesap, ölçüm değil):
- K5 bossu 110.000 havuz: 2 kişi ~90 sn, 4 kişi ~70 sn, zayıf 3 kişilik takım ~3,5 dk. İlk boss artık K5'te (K3 bossu yok): erken oyun
  bugünkünden rahat, ilk gerçek sınav K5.
- K10 bossu 700.000 havuz (bugünkü Banshee dayanıklılığı): 4 kişi ~90 sn, 2 kişi ~100 sn, tek oyuncu ~2,5-4 dk (tek oyuncu hasarı tahmin).
- K1-10 sıradan yaratık ölçeği DEĞİŞMEDİ (bilinen, oynanmış eğri). Risk: güçlü 4 kişilik takım K6-K10'u rahat geçiyor -> oyun onlara kolay
  gelebilir. Bunun için `enemy_spawner.gd`'ye kademe -> çarpan tablosu koy (`LATE_PRESSURE := {6: 1.0, ..., 10: 1.0}`, can ve hasara
  ayrı), varsayılan 1,0; veri gelince buradan sıkılır. Kendiliğinden 1,0'dan farklı yazma.

HEDEFLER (öneri; kalibrasyonun ölçütü):
| Ölçü | Hedef |
|---|---|
| K5 boss dövüşü | 60-120 sn; takımın tamamen öldüğü deneme en çok ~4'te 1 |
| K10 boss dövüşü | 120-200 sn; ilk denemelerde takımların yarıya yakını kaybeder |
| K5'e ulaşan koşu | >= %60 (bugün %42) |
| K10'a ulaşan koşu | ~%30-40 |
| Zafer | tüm koşuların ~%15-25'i |

Kalibrasyon için KAYIT (Aşama 1'de eklenir): koşu kaydına harita kimliği ve boss başına dövüş süresi (`boss_fights`: kimlik -> [doğuş sn,
ölüm sn ya da -1, takım boyu]). `tools/balans_rapor.ps1`'e "Bosslar" bölümü: boss başına medyan süre, ölümle biten deneme oranı; ve harita
başına K5 / K10 / zafer oranı.
AYAR KURALI (kullanıcı ~10 gerçek oyun oynadıktan sonra, kullanıcı onayıyla): boss süresi hedef dışındaysa yeni havuz = havuz x hedef orta
nokta / ölçülen medyan (bir seferde en çok +-%30); ölüm oranı hedefin üstündeyse önce hasar -%15, altındaysa +%15. Her ayar BALANCE_REV.

## 6. Aşamalar

### Aşama 1 - 10 kademe + K5/K10 boss + K10'da zafer + yeni elit düzeni (yalnız genel tablolar; tüm haritalar ana'nın tablosunu kullanır)
1. `enemy_spawner.gd`: `LAST_TIER := 10` sabiti; "15" varsayımı olan her yer ona bağlanır: `_current_tier` (clamp 15), `TIER_ROSTER`
   (bölüm 3 ana), `elite_candidates` (15), `_scale_tier_for`, `_check_auto_endless`, host devri/geri katılım kurulumundaki
   `FINAL_TIER` zamanları (~858-864), `_check_tier_announcement`.
2. Bosslar: `NEW_BOSS_TIERS = {5: ["minotaur1"], 10: ["wendigo1"]}`. K10 bossu doğunca `_final_spawned = true`, `_final_bosses = doğanlar`
   -> `_check_victory` değişmeden zaferi verir. Ayrı Final doğuşu (`_check_final_tier`, `_final_gate_open`, `NEW_FINAL_BOSSES`, kademe 16)
   devreden çıkar. Kademe saati boss ölene kadar zaten kademe sınırında duruyor (`_tier_time`): K10 sınırında bekler.
   Eski `bosses_enabled` yolu (eski `BOSS_TIERS` + 13'lü Final) yalnız test içindi: derlenir kalsın ya da testleriyle birlikte kaldır
   (hangisi daha az iş ise; notta belirt).
3. Boss statları bölüm 2'ye göre (Minotaur K5, Wendigo K10) + hasar çarpanı tablosu.
4. Elit: kademe -> kimlik tablosu (bölüm 4 ana), yalnız çift kademede; stat bölüm 5 elit kuralı.
5. Sonsuz mod `endless_math.gd`: taban 15 -> `LAST_TIER` (ölçek kademesi `LAST_TIER + kat`, `creature_health_mult` eşikleri). Sonsuz boss
   dalgası haritanın iki bossundan kurulur.
6. `FINAL_TIER` / 15-16 geçen diğer dosyalar (grep ile hepsine bak, her kullanıma karar ver): `enemy.gd`, `tier_display.gd`,
   `records_screen.gd`, `game_over_board.gd`, `phone_game_over.gd`, `main.gd`, `network_manager.gd`, `food_drop.gd`, `shield_orb_drop.gd`,
   `tier_system.gd`, `level_special_cards.gd`, `guard_camps.gd`, `debug_menu.gd`, `banshee_boss.gd`, `balance_log.gd`, `necro_skull.gd`.
   Kademe 11+ eşikli başarım/rekor varsa 10'a göre yeniden yaz.
7. Ruh Kıymığı (`meta_progress.gd`): DEĞİŞTİRME. Hesap: eski tam koşu ~410 kıymık / ~42 dk, yeni ~300 / ~27 dk = dakika başına aynı.
7b. Denge kaydı (bölüm 5b): koşu kaydına harita kimliği + `boss_fights`, rapora "Bosslar" bölümü; `LATE_PRESSURE` tablosu (hepsi 1,0).
8. Testler: kırılacaklar `test_elite_pool_and_bosses_off`, `test_endless_mode`, `test_minotaur_boss`, `test_underground_boss`,
   `test_pumpkin_boss`, `test_wendigo_boss`, `test_banshee_boss`, `test_demon_boss`, `test_enemy_spawner_gate_and_ambush`,
   `test_boss_kademe_gate_and_balance` - yeni kurala göre güncelle (silme). Yeni test: 10 kademe tablosu dolu, K5/K10 bossu, K10 bossu
   ölünce zafer, tek kademede elit yok, elit gücü artan.
9. Doğrulama: başsız duman her seçilebilir haritada (`HARITA=<id>`, `tools/harita_secimi/`), debug ile K5 ve K10 bossunu doğurup öldür,
   zafer penceresi + "Sonsuza Devam Et". Çok oyunculu: `tools/mp_audit/run_audit.ps1 -Mode sync` (+ boss modu varsa).
BİTTİ ölçütü: ana harita baştan sona 10 kademe oynanıyor, Wendigo ölünce zafer, testler yeşil, BALANCE_REV arttı.

### Aşama 2 - Haritaya özel havuz + hesaplanan stat + haritaya özel elit
1. `map_profiles.gd PROFILES`: `yaratik_havuzu` (kademe -> liste) ve `elitler` (kademe -> kimlik) alanları, 4 harita için bölüm 3-4.
   Alan yoksa genel tablo (ana harita profiline alan EKLEME; birebir aynı kalsın).
2. `enemy_spawner.gd`: `_spawnable_roster` ve elit seçimi profile bakar; `TIER_ROSTER`'ı doğrudan okuyan her yer bu işlevden geçer.
3. Bölüm 5: `REF_P` aracı + tablo + `pool_stats`, host ve istemci yolu.
4. Balans raporu harita başına ayrılsın (harita kimliği kayda Aşama 1'de girdi): `tools/balans_rapor.ps1` harita başına ulaşma oranları.
5. Testler: `tests/test_map_pools.gd` (her harita x her kademe dolu ve kimlikler `SCENES`'te; haritanın eliti sıradan listede yok - ana
   istisnası hariç; REF_P tablosu sahnelerle tutarlı; aynı kademede havuz yaratığının canı ana haritanın o kademe ortalamasına yakın;
   elit gücü artan; ana harita tablosu = Aşama 1 tablosu). `test_new_creature_pool.gd` güncelle.
6. Doğrulama: 4 haritada başsız duman (doğan kimlikler havuzdan mı), iki süreçli denetimde istemci canı = host canı.
BİTTİ ölçütü: 4 haritada yalnız kendi yaratıkları + kendi elitleri doğuyor, ana harita Aşama 1'le birebir, BALANCE_REV arttı.

### Aşama 3 - Mevcut bossların dağıtımı + harita başına zafer
1. Profile `bosslar` alanı (bölüm 2): bataklik Balkabağı/Banshee, col Yeraltı/Uçan Şeytan; iki zindan haritası geçici ana bossları.
2. Statlar bölüm 2 başlangıç değerleri + hasar çarpanı. Banshee gece kilidi kimliğe bağlı.
3. Her bossu KENDİ haritasında dene (Yeraltı Canavarı uzuvları çölde geçerli zemine çıkıyor mu; Uçan Şeytan çöl sınırlarında).
4. Zafer kaydı harita başına: `run_records.gd record_victory` özetine harita kimliği, `victories_by_map`; rekor ekranı + harita seçiminde
   (oda kur / tek oyunculu harita kutusu) "tamamlandı" işareti. `broadcast_victory` imzası değişirse LOBBY_PROTOCOL.
5. Boss testleri + `run_audit.ps1` boss senkronu (madde 42).

### Aşama 4 - Harita anahtarları (kararlar verildi 2026-11-12; Aşama 2-3'ten BAĞIMSIZ, hemen yapılabilir)

Kullanıcı kararları: (1) her içeriğe ayrı anahtar YOK (görsel yetmez) - HARİTA başına tek anahtar türü; (2) anahtar tek seferlik kupa DEĞİL,
her boss öldürmede yeniden kazanılan ve harcanan bir birim; (3) içerik ANAHTAR + RUH KIYMIĞI ile alınır - anahtar fiyatın yerine geçmez,
"her şey parayla çözülmesin" diye ek şarttır. (Kullanıcı "altın" dedi; Ruh Mağazası'nın parası Ruh Kıymığı olduğu için öyle yorumlandı.)

**4.0 Görseller (kullanıcı hazırlıyor).** Beklenen dosyalar: `assets/ui/anahtar/<harita_kimliği>.png` = `ana.png`, `bataklik.png`, `col.png`,
`batik_nekropol.png`, `lagim_agi.png` (32x32, saydam zemin). Dosyalar YOKSA başlamadan KULLANICIYA SOR; anahtar görseli üretme/çizme.
Çizim tam katlarda (32 / 64 / 96 px; `DK.ShardIcon side_for` deseni), tek kaynak yeni `scripts/key_icon.gd` (kimlik -> doku, görünen ad).
Görünen adlar: ana "Orman Anahtarı", bataklik "Bataklık Anahtarı", col "Çöl Anahtarı", batik_nekropol "Nekropol Anahtarı", lagim_agi "Lağım Anahtarı".

**4.1 Kazanım.**
- Kademe 5 bossu ölünce o haritanın anahtarından 1, Kademe 10 bossu ölünce 2 (`KEYS_PER_BOSS := {5: 1, 10: 2}`, BAŞLANGIÇ DEĞERİ).
  Harita = `MapProfiles.current_id()`. Her koşuda yeniden kazanılır; şans yok.
- Odadaki HERKES alır (ölü / yerdeki dahil), anında KENDİ kaydına yazılır (Ruh Kıymığı gibi; sonradan kaybetmek/çıkmak geri almaz).
- Vermeyen durumlar: sonsuz mod boss dalgaları (kademe > `LAST_TIER`), debug modu açılmış koşu (`GameManager.debug_mode_unlocked`; koşu
  içinde açılıp kapansa da - gerekirse koşu bayrağı ekle).
- Ağ: boss ölümünü HOST saptar (bossun `die()`'ı; balans kancası `enemy.gd die()` `is_boss` dalında) ve kademe başına BİR kez (koruma sözlüğü)
  herkese `call_local` güvenilir RPC yollar (harita kimliği + adet; alıcıda `_from_host()`). Her eş `MetaProgress.grant_keys` çağırır.
  Tek oyunculuda aynı işlev RPC'siz. Yeni RPC -> LOBBY_PROTOCOL artır.
- Oyun içi bildirim: küçük levha (`main.gd _show_notice`, anahtar simgeli) "+1 Bataklık Anahtarı"; zafer penceresi + oyun sonu kazanımlar
  satırı (`game_over_board.gd`) bu koşuda kazanılan anahtarları gösterir (`GameManager` koşu sayacı; `reset()` sıfırlar).
- Balans kaydına `keys` (bu koşuda kazanılan adet).

**4.2 Kayıt (`scripts/meta_progress.gd`).**
- Yeni alan `keys`: harita kimliği -> adet. `_defaults`, `load_all` (ConfigFile bölümü `keys`), `_save` ÜÇÜNE de ekle. TUZAK: `_save` yalnız
  bildiği bölümleri yazar - `keys` eklenmezse ilk kayıtta anahtarlar SİLİNİR. Eski kayıt (bölüm yok) = hepsi 0.
- `keys(map_id)`, `grant_keys(map_id, n)`, `key_cost(kind, key) -> Dictionary` (`{}` = anahtar istemez; `{"map": ..., "count": ...}`).
- `can_buy` / `buy`: kıymık VE anahtar yeterliyse; `buy` ikisini birlikte düşer. `locked_items()` satırına `key_map` / `key_count` ekle.
- `lock_text`: anahtarlıysa "Kilitli - 450 Ruh Kıymığı + 3 Bataklık Anahtarı (Ruh Mağazası)" (çağıranlar: `menu_character_card.gd`,
  `menu_weapon_picker.gd`, `menu_pet_picker.gd`, `spiritual_picker.gd` - metin kendiliğinden gelir, sığmayı kontrol et).
- Daha önce açılmış her şey açık kalır (`unlocked` listesine dokunma). `_all_unlocked()` (debug) davranışı aynı.

**4.3 Anahtar isteyen içerik (kıymık fiyatı `COSTS`'ta AYNEN kalır; BAŞLANGIÇ DEĞERLERİ).**

| Anahtar | Karakter (3 anahtar) | Evcil (1 anahtar) |
|---|---|---|
| ana | Shaman (12) | `peri` |
| bataklik | Cadı (15) | `slime` (Minik Cadı) |
| col | Hadime (14) | `kirpi` |
| batik_nekropol | Necromancer (11) | `hayalet` |
| lagim_agi | Vampir Çocuk (13) | `kelebek` |

Tek tablo: `KEY_COSTS := {CHAR: {12: ["ana", 3], ...}, PET: {"peri": ["ana", 1], ...}}`. Matthew, Assasin, Elara, Korsan, Melek, `papagan`,
tüm silahlar ve ruhani yetenekler yalnız kıymıkla kalır (yeni oyuncu 1000 kıymıkla seçenek bulsun). 3 anahtar = o haritada 1 zafer ya da 3 kez
K5 bossu; 1 anahtar = 1 kez K5 bossu.

**4.4 Ruh Mağazası (`scripts/soul_shop_screen.gd`; masaüstü `_build_page` + telefon düzeni).**
- `_items()` anahtar alanlarını taşır; liste satırı + ayrıntıda fiyat = kıymık + anahtar simgesi x adet; eksik olan kırmızı (`HudTheme.BAD`),
  ayrıntıda nereden kazanılacağı: "Kara Bataklık bosslarından düşer" (harita adı `MapProfiles` profilinden).
- `_need` / `_state` / `_group` anahtarı da saysın (anahtarı eksik öğe "alınamaz" grubunda). Satın alma akışı aynı (iki basışlı onay, `_mark_bought`).
- Yeni bölüm "ANAHTARLAR" (sol bölüm listesine): 5 anahtar türü - simge, adet, hangi haritadan düştüğü, ne için gerektiği + BOZDUR düğmesi (4.5).
- Yeni renk gerekiyorsa `hud_theme.gd`'ye ROL ekle (stil rehberi, madde 403); yazı m5x7 / sayı PixeloidSans.

**4.5 Anahtarın anlamını koruyan harcama yerleri (planı yazanın önerisi; kullanıcı açıkça onaylamadı, istemezse bu madde atlanır).**
- BOZDUR: 1 anahtar -> 25 Ruh Kıymığı (`KEY_TO_SHARDS := 25`, iki basışlı onay). Fazla anahtarın taban değeri; bir zafer en çok +75 kıymık eder.
- Kalıcı geliştirmelerin (`meta_upgrades.gd LIST`, 20 satır) SON seviyesi kıymığa EK 1 anahtar ister; anahtar türü satır sırasına göre döner
  (`["ana", "bataklik", "col", "batik_nekropol", "lagim_agi"][sıra % 5]`). `next_key_cost(id)`, `can_buy`, `buy`. Ödenen anahtar kayda
  yazılır (yeni bölüm `upgrade_keys`: id -> 1); `reset_all` yalnız KAYITLI olanı iade eder (bugün zaten son seviyede olan eski kayıtlar
  anahtar ödemedi: sıfırlayınca bedava anahtar ÇIKMASIN). Mağaza satırında son seviyenin yanında anahtar simgesi.
- Sonradan eklenen her yeni karakter/evcil mevcut anahtar türleriyle fiyatlanır (yeni görsel gerekmez).

**4.6 Dil, test, denetim.**
- Yeni metinler `python -I tools/dil/dil_cikar.py` ile çıkarılır, 9 dil doldurulur (`localization/sozluk.md`; argüman sırası değişmez).
- `tests/test_meta_keys.gd`: anahtar ver/kaydet/yükle; eski (anahtarsız) kayıt yüklenir; anahtarlı öğe yalnız kıymıkla ALINAMAZ, ikisiyle alınır
  ve ikisi de düşer; açık olan açık kalır; `lock_text`; bozdurma; geliştirme son seviyesi + sıfırlama iadesi; debug koşusu / sonsuz dalga
  anahtar vermez; K5 = 1, K10 = 2. Mevcut meta/mağaza testlerinde 11-15 numaralı karakterleri ya da bu evcilleri yalnız kıymıkla alan
  varsa güncelle (`tests/` içinde `meta_progress` ara).
- TUZAK: testler ve denetimler kullanıcının GERÇEK `user://meta.cfg`'sine anahtar yazmasın: `MetaProgress.set_path_override` /
  `LILSLAYERS_META_PATH` (kıymık testleri zaten böyle yalıtılı).
- Çok oyunculu: `tools/mp_audit/run_audit.ps1`'e küçük bir kip (ör. `anahtar`): host boss ölümünü tetikler, istemcinin (yalıtılmış) kaydında
  aynı adet anahtar oluşur, ikinci tetik aynı kademede bir daha vermez.
BİTTİ ölçütü: K5 / K10 bossu her haritada o haritanın anahtarını herkese veriyor, Ruh Mağazası'nda 5 karakter + 5 evcil kıymık + anahtar
istiyor, eski kayıtlar bozulmadan açılıyor, testler + MP denetimi yeşil. Denge sabiti değiştiği için BALANCE_REV artır.

### Aşama 5 - 4 yeni boss (BAŞLAMADAN ÖNCE KULLANICIYA SOR)
batik_nekropol ve lagim_agi için K5 + K10 bossları. Kullanıcıdan: boss sanatı + mekanik/stat belgesi (önceki bosslar böyle verildi).
İlke: boss haritanın özelliğini kullansın (Lağım: gaz fıçıları, yeşil su; Nekropol: ejder başı tuzakları, su). Her boss: sahne + betik +
`SCENES` + `ID_FAMILY` + `FIXED_BOSS_STATS` + `boss_bar_art.gd NAMES` + 10 dil + test + MP denetimi + ısınma listesi
(`tools/gen_fx_warmup_list.ps1`). Sahne sayısı artınca `SCENES` preload'unu haritaya göre yüklemeye çevirmeyi değerlendir.

## 7. Açık kararlar (kullanıcı)
- Ana haritada `iskelet3` / `zombie3` / `ork3` yalnız elit mi olsun (şimdilik hem sıradan hem elit).
- Boss can/kalkan/hasar sayıları (bölüm 2 başlangıç değerleri) ve bölüm 5b hedefleri; K6-K10 yaratık baskısı (`LATE_PRESSURE`) veri gelince.
- Anahtar: 5 görsel dosyası (4.0), adetler (K5 1 / K10 2, karakter 3 / evcil 1), hangi içeriğin anahtar istediği (4.3 tablosu), 4.5'teki
  bozdurma + geliştirme son seviyesi (öneri). Yeni boss sanatı (Aşama 5).
- Pelte Lağım'da (Bataklık'a da uyar); Altın Kumlar açılışında fare; zombi dört haritada.
