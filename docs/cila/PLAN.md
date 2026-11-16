# CİLA PLANI (2026-11-15 denetimi)

Bu dosya, 2026-11-15'te yapılan tam oyun denetiminin bulgularını **düzeltme görevlerine** çevirir. Görevleri başka bir oturum (Sonnet) yürütecek.
Kaynak: kod okuması + oyunun koşu kayıtları (`%APPDATA%\Godot\app_userdata\Temiz Sürüm\balans\kosular.jsonl`). Oyun ve testler denetimde koşulmadı.

Her görevin başında bir kanıt etiketi var:
- **DOĞRULANDI**: planı yazan oturum iki tarafı da (metin + kod) kendi okudu.
- **DENETÇİ**: yalnız alt denetçi raporu. Düzeltmeden önce "Önce doğrula" adımını yap. Tutmuyorsa görevi ATLA, `## İlerleme`ye bir satır not yaz.

---

## 0. Bu dosya nasıl kullanılır (yürüten oturum için)

1. **Bir oturumda TEK parti.** Sıra: A, B, C, D, E, F. Parti bitince dur, kullanıcıya özet ver.
2. Her görevde sıra: oku, "Önce doğrula"yı yap, düzelt, "Kontrol"ü yap, `## İlerleme`de kutuyu işaretle.
3. **Satır numaraları 2026-11-15'e aittir ve kayar.** Yeri her zaman verilen arama metniyle (Grep) bul, numaraya güvenme.
4. **Kapsam dışına çıkma.** Görevde yazmayan yeniden adlandırma, toparlama, "bunu da düzelteyim" yok. Yeni özellik yok (cila dönemi).
5. Görevde **KARAR Kn** yazıyorsa bölüm 3'teki tabloya bak. "Cevap" sütunu boşsa "Varsayılan"ı uygula. Varsayılan "ATLA" ise görevi atla.
6. Kod görevde tarif edilenden farklı çıkarsa (fonksiyon yok, mantık başka) **tahminle düzeltme yapma**: görevi atla, ne gördüğünü `## İlerleme`ye yaz.
7. Bölüm G'deki işlere dokunma. Onlar ya tasarım kararı bekliyor ya da daha güçlü modelle yapılacak.

## 1. Ortak kurallar (CLAUDE.md'nin bu işe bakan özeti)

- **Başlamadan**: `git fetch`, `git status`. Başka bir oturum aynı anda çalışıyorsa (son birkaç dakikada değişmiş `.po` ya da `scripts/` dosyası varsa) BAŞLAMA, kullanıcıya sor. Depoda başkasına ait commit edilmemiş değişiklikler olabilir: onlara dokunma.
- **Asla**: `git checkout` / `restore` / `stash` / `reset`, commit, push, export, tam test paketi, iki testi aynı anda koşmak, görünür oyun penceresi açmak.
- **Büyük dosyaları baştan sona okuma** (`player.gd` 17 bin satır): Grep + dar aralık.
- **`.po` / `.pot` dosyaları**: PowerShell `Get-Content` / `Set-Content` ile YAZMA (Türkçe harfler bozulur). Edit aracını ya da Python'u (`encoding="utf-8"`) kullan.
- **Test**: `powershell -ExecutionPolicy Bypass -File tools/enemy_rewrite/run_tests.ps1 -Filter "<dosya>.gd"`. Yalnız görevde adı geçen testler. Başarısız assert testi yarıda keser: İLK hataya bak.
- **Değiştirdiğin eski metni `tests/` içinde ara.** Bir test o metni ya da sayıyı bekliyorsa testi de güncelle.
- **Denge**: bu planın varsayılan görevleri denge sayısı DEĞİŞTİRMEZ. Bir KARAR cevabı davranışı değiştiriyorsa (K1b, K2b, K3a, K4b) `scripts/balance_log.gd BALANCE_REV`'i 1 artır ve yorumuna satır ekle.
- **MP iki-yer kuralı**: host/kaster tarafında eklediğin her görsel ya da ses diğer istemcilere de gitmeli.
- **Parti bitince**: `docs/notlar/madde_161-170.md` sonuna YENİ madde (numarayı yazma anında INDEX'in son satırından al, başka oturum almış olabilir), `docs/notlar/INDEX.md` sonuna TEK satır. Kullanıcıya: "export almayı unutma" + commit edilmemiş değişiklik var, push ister misin.

## 2. Çeviri usulü (Türkçe kaynak metin değişen HER görevde)

Türkçe metnin kendisi çeviri anahtarıdır (msgid). Metni değiştirirsen 9 dilin çevirisi kopar. Her metin değişikliğinden sonra:

1. `.gd` içindeki Türkçe metni değiştir.
2. `python -I tools/dil/dil_cikar.py` koş. Yeni metin `localization/oyun.pot` ve 9 `.po` dosyasına BOŞ `msgstr` ile eklenir, eski metin `#~` satırlarına düşer (eski çevirisiyle birlikte).
3. 9 dilin her birinde (`de en es fr it pl pt ru zh`): eski girdinin (`#~ msgstr`) çevirisini yeni girdinin `msgstr`'sine kopyala, yalnız değişen sayıyı ya da ifadeyi düzelt. Cümle yapısı değiştiyse o cümleyi 9 dilde yeniden yaz. Terimler için `localization/sozluk.md`.
4. Yüzdeler: Türkçe `%60`, diğer dillerde mevcut çeviri nasıl yazıyorsa öyle (`60%`). Bekleme notu: `(26sn bekleme)` kalıbı HUD'da otomatik siliniyor (`skill_icon.gd _strip_cooldown_note`), ondalık `17.25sn` de çalışır. Çevirideki karşılığını da aynı kalıpta bırak (`(26s cooldown)` gibi).
5. Kontrol: `python -I tools/dil/dil_cikar.py --dosya <değiştirdiğin .gd>` o dosyada çevrilmemiş aday kalmadığını göstermeli (senin dokunmadığın teknik metinler hariç).
6. `#~` satırlarını elle silme.
7. Parti sonunda: `run_tests.ps1 -Filter "test_localization.gd"`.

Bir partide birden çok metin değişecekse: önce bütün `.gd` değişikliklerini yap, `dil_cikar.py`'yi BİR kez koş, sonra çevirileri doldur.

---

## 3. Kararlar (kullanıcı doldurur; boşsa varsayılan geçerli)

| No | Soru | Varsayılan | Cevap |
|---|---|---|---|
| K1 | Arbalet, adındaki "bow" yüzünden Yay'ın %15 yavaşlatmasını yanlışlıkla alıyor. (a) metni gerçeğe uydur (1.3sn), davranış aynı (b) yavaşlatmayı kaldır, Arbalet ~%17 hızlanır | a | |
| K2 | Talon E ve Kestrel E hasarı "saldırı gücünün %X'i" değil, tüm silahların hasar toplamının %X'i. (a) metni gerçeğe uydur (b) kodu metne uydur, hasar ciddi düşer | a | |
| K3 | Bekleme azaltma Korsan bombası ve Assasin E yüklerine işlemiyor (Shaman ve Cadı yüklerine işliyor). (a) işlesin, güçlenme (b) işlemesin, metne not | ATLA | |
| K4 | Seviye kartları "+%2.5 / +%5" yazıp %3.5 / %6.5 veriyor. (a) metni gerçeğe uydur (b) kodu metne uydur, zayıflama | a | |
| K5 | Son Felaket Pençesi pasifi "Kritik hasar sınırını aşabilir" diyor, böyle bir sınır yok. (a) pasif satırını sil (b) kalsın | a | |
| K6 | Taban hali artık adını karşılamayan yetenek adları (Aldric Q "Kışkırtma", Elara Q "Gerçek Hasar", Elara E "Sıvışma") yeniden adlandırılsın mı? | hayır (dokunma) | |
| K7 | Ana menüdeki "Debug Modu" düğmesinin adı değişsin mi? Öneri: "Test Modu (Hepsi Açık)" | hayır (dokunma) | |
| K8 | Tek oyunculuda hiç çalışmayan seçenekler (Kalkan Bağı ruhanisi, Oakley "Kadim Diriliş" evrimi): (a) tek oyunculuda sunulmasın (b) dokunma | a | |
| K9 | Duraklatma menüsünde ANA MENÜ ve tek oyunculu YENİDEN BAŞLA çift basışla onay istesin mi (TESLİM OL gibi)? | evet | |
| K10 | Bildirim / bekleme / bitiş ekranındaki 4 farklı "krem" yazı rengi tek `HudTheme.TEXT`'e çekilsin mi (çok küçük görsel fark)? | evet | |
| K11 | Kapalı duran eski efsun seti (`scripts/enchants/` 20 betik) silinsin mi? | hayır (kalsın) | |
| K12 | Ses görevleri (E2) için ses dosyaları: kullanıcı `docs/cila/SESLER.md` tablosunu doldurunca yapılır | ATLA | |

---

## PARTİ A: Metinleri koda uydur (davranış değişmez)

Hepsi metin işi. Önce tüm `.gd` değişiklikleri, sonra bölüm 2'yi bir kez uygula. Parti testi: `test_localization.gd`, `test_passive_and_tooltips.gd`, `test_korsan_necromancer_skills.gd`, `test_cadi.gd`, `test_necro_evolutions.gd`, `test_oakley_evolutions.gd`, `test_new_items_486.gd`, `test_kalkan.gd`, `test_meta_upgrades.gd`.

### A1. Corvina iskelet / golem ömrü: DOĞRULANDI
- **Sorun**: metin "60sn yaşar" / "120sn yaşar", kod `NECRO_SKELETON_LIFESPAN := 30.0`, `NECRO_GOLEM_LIFESPAN := 60.0` (`scripts/player.gd`, satır ≈3707 ve ≈3714).
- **Yer**: `scripts/characters.gd`, Grep `60sn yaşar` (≈641) ve `120sn yaşar` (≈647).
- **Yap**: ÖNCE `60sn yaşar` yerine `30sn yaşar`, SONRA `120sn yaşar` yerine `60sn yaşar` (sıra ters olursa ikisi de 30 olur).

### A2. Seraphine Q / E bekleme süresi: DOĞRULANDI
- **Sorun**: metin "(20sn bekleme)" ve "(15sn bekleme)", kod `MELEK_CAN_BASMA_COOLDOWN := 26.0`, `MELEK_KALKAN_YENILEME_COOLDOWN := 17.25` (`player.gd` ≈8120, ≈8146).
- **Yer**: `scripts/characters.gd` Seraphine (Melek) tanımı, satır ≈553 (Can Basma) ve ≈563 (Kalkan Yenileme). DİKKAT: "(20sn bekleme)" başka birçok karakterde de var. Yalnız bu iki satırı değiştir (satırda `kendine+müttefiğe` geçiyor).
- **Yap**: ≈553'te `(26sn bekleme)`, ≈563'te `(17.25sn bekleme)`.

### A3. Lyra Don Nova odaklanma süresi: DOĞRULANDI
- **Sorun**: metin "1sn durup odaklanır", kod `BUYUCU_NOVA_FOCUS_TIME := 0.5` (`player.gd` ≈9814).
- **Yer**: `scripts/characters.gd` ≈269 ve `scripts/player.gd` içindeki dinamik HUD metni (Grep `durup odaklanır`, ≈9416).
- **Yap**: iki yerde de `0.5sn durup odaklanır`.

### A4. Seviye kartı sayıları (KARAR K4, varsayılan a): DOĞRULANDI
- **Sorun**: `scripts/level_up_screen.gd` `UPGRADES` (≈66-104): `crit_chance` ve `dodge` "+%2.5", `shield_amount` "+%5". Kod `_nice_up(0.025 * 1.3, 0.005)` = 0.035 ve `_nice_up(0.05 * 1.3, 0.005)` = 0.065 uyguluyor (`player.gd`, Grep `_nice_up\(0\.0`).
- **Önce doğrula**: `level_up_screen.gd` ≈1241'deki gösterim çarpanı (`rest.to_float() * (1.0 + float(tier - 1) * 0.3)`) ile `player.gd`'deki `tier_mult` aynı formül mü? Değilse dur ve not yaz.
- **Yap**: `crit_chance` "+%3.5", `dodge` "+%3.5", `shield_amount` "+%6.5". Aynı eski sayılar başka dosyada (açıklama, test) geçiyor mu Grep ile bak (`\+%2\.5`).

### A5. Ruh Mağazası "Can Çalma" açıklaması: DOĞRULANDI
- **Sorun**: `scripts/meta_upgrades.gd` ≈48: "Verdiğin hasarın bir kısmı sana can olarak döner." Gerçek davranış: isabet başına o ihtimalle 1 can (`GameManager.LIFESTEAL_HEAL := 1.0`, `scripts/game_manager.gd` ≈45). Doğru anlatım `scripts/stats_panel.gd` ≈167'de var.
- **Yap**: açıklamayı "Her isabette bu ihtimalle 1 can yenilersin (alan hasarında etkisi %33)." yap. Satırın üstüne yorum: `## "1" GameManager.LIFESTEAL_HEAL ile aynı olmalı`.

### A6. Envanterde demirciye yönlendiren metinler: DOĞRULANDI
- **Sorun**: demirci kapalı (`scripts/shops_flag.gd` `enabled = false`), silah / geliştirme / kalkan türü level pazarında satılıyor. `scripts/inventory_panel.gd`'de üç metin hâlâ demirciyi söylüyor (Grep `demirciden`, ≈1477, ≈1842, ≈1852).
- **Önce doğrula**: level pazarının oyuncuya görünen adı ne? `scripts/level_market_view.gd` ve `localization/sozluk.md` içinde bak, aynı adı kullan.
- **Yap**: üç yerde metni bayrağa bağla: `ShopsFlag.enabled` doğruysa eski metin kalsın (çevirisi zaten var), yanlışsa "demirciden" yerine "level pazarından" yazan yeni metin. Dosyada `ShopsFlag` ön yüklü değilse `const ShopsFlag := preload("res://scripts/shops_flag.gd")` ekle. Yalnız satır ≈426, ≈989, ≈1085'teki YORUMLARA dokunma.

### A7. Son Felaket Pençesi pasifi (KARAR K5, varsayılan a): DOĞRULANDI
- **Sorun**: `scripts/items.gd` ≈170 `"passive": "Kritik hasar sınırını aşabilir."`. Kodda kritik hasar sınırı yok, eşyanın tek etkisi stat satırları.
- **Önce doğrula**: `Items.describe` pasifi olmayan eşyada sorunsuz çalışıyor mu (62 eşyanın 14'ünde pasif yok, onlardan birine bak).
- **Yap**: yalnız `"passive"` anahtarını sil (stat satırı kalır). Satır sonundaki virgül / süslü parantezi bozma.

### A8. Hazel R İksir Çantası, Şifa ve Kalkan: DENETÇİ
- **Sorun**: `scripts/characters.gd` ≈826: "Şifa (üstündeki müttefikler saniyede %20 can yeniler)" ve "Kalkan (... saniyede %25 mana kalkanı yeniler)". Denetçiye göre kod saldırı gücünün %20 / %25'ini veriyor.
- **Önce doğrula**: `scripts/cadi_math.gd` `POTION_DESCS` (≈187-189) ve sabitler (≈211-213), `player.gd` ≈15664 ve ≈15677. İyileşme `damage_bonus` (saldırı gücü) üzerinden mi hesaplanıyor?
- **Yap**: doğruysa metni `POTION_DESCS`'teki ifadeyle aynı yap: "saniyede saldırı gücünün %20'si kadar can", "saniyede saldırı gücünün %25'i kadar mana kalkanı".

### A9. Silah katalog metinleri (`scripts/weapon_catalog.gd` `DESCRIPTIONS`): DENETÇİ
Her satır için önce doğrula, sonra düzelt. İki genel çarpan: her silahın aralığı = sahnedeki `fire_rate` / 0.7 (`scripts/weapon.gd` ≈273), yakın dövüş olmayan her silahın menzili = sahnedeki `range` x 0.9 (`weapon.gd` ≈1147-1149).

| Silah | Metin şimdi | Beklenen | Nasıl doğrulanır |
|---|---|---|---|
| Arbalet (KARAR K1, varsayılan a) | Ateş hızı 1.1sn | 1.3sn | `weapon.gd` ≈1143: `containsn("bow")` crossbow'u da yakalıyor. 0.8 / 0.85 / 0.7 = 1.34. Bu satırın üstüne yorum ekle: "bow" weapon_crossbow'u da kapsar (plan K1). |
| Pompalı | Ateş hızı 1.3sn | 1.9sn | `scenes/weapon_pompali.tscn` `fire_rate` 1.3, 1.3 / 0.7 = 1.86. Tüfek aynı sahne değeriyle "1.9sn" yazıyor, aynı kuralı uygula. |
| Yıldırım Asası | HASAR: %140 saldırı gücü | saniyede ~%87 saldırı gücü | `weapon.gd` ≈3357 ve ≈3369: tik hasarı x0.33. Tik aralığı = `scenes/weapon_lightning.tscn` `fire_rate` / 0.7. 1.40 x 0.33 = %46 / tik, saniyede ~1.9 tik. Sayıları kendin hesapla, Gökkuşağı metnindeki "saniyede" kalıbını kullan. |
| Menzil: Yıldırım, Tabanca, Yay, Çakram, Yin Yang, Pompalı, Makineli, Gökkuşağı | 168, 210, 266, 167, 170, 330, 200, 185 | 151, 189, 239, 150, 153, 297, 180, 167 | Her birinin sahnesindeki `range` x 0.9. Sayıyı sahneden kendin hesapla, tablodakiyle tutmuyorsa sahnedekini esas al. |

Çakram'ın "0.5sn" ateş hızına DOKUNMA (belirsiz).

### A10. Kalkan final özelliği "Yıkılmaz Duvar": DENETÇİ
- **Sorun**: `scripts/weapon_traits/weapon_traits.gd` ≈356 "saldırı gücünün %150'si kadar hasar". `scripts/weapon_traits/siper.gd` `WALL_DAMAGE_MULT := 1.5` darbeyi çarpıyor, darbe zaten %150 (`scenes/weapon_kalkan.tscn`). Gerçek: %225.
- **Önce doğrula**: `siper.gd` ≈14 ve ≈41, `weapon.gd` ≈4580. Çarpan darbenin üstüne mi biniyor?
- **Yap**: doğruysa metinde `%225`. `siper.gd`'deki eski yorumu ("%100 -> %150") güncelle.

### A11. Evrim metinleri (`scripts/skill_evolutions.gd`): DENETÇİ
| Evrim | Metin şimdi | Olması gereken | Doğrulama |
|---|---|---|---|
| `necro_q3` (≈343) | "İskeletlerin canı ve mana kalkanı %20 artar." | "İskeletlerin canı %20 artar." | `player.gd` ≈3750 yorumu ve ≈4556: yalnız can ölçekleniyor |
| `necro_ef` (≈352) | "tüm yaratıkları kışkırtarak" | "800 birim içindeki yaratıkları 6sn kışkırtarak" | `player.gd` ≈3757-3758 `EVO_NECRO_EF_TAUNT_RADIUS` / `_DURATION` |
| `oakley_qf` (≈132) | "150 birim çevresindeki yaratıklara geçer" | "150 birim çevresindeki en yakın 6 yaratığa geçer" | `scripts/enemy.gd` ≈2804 `BEE_PLAGUE_MAX_TARGETS := 6` |

### A12. Talon E ve Kestrel E hasar metni (KARAR K2, varsayılan a): DOĞRULANDI
- **Sorun**: `scripts/characters.gd` ≈68 "saldırı gücünün %60'ı kadar hasar", ≈340 "saldırı gücünün %150'si kadar hasar". Kod sahip olunan TÜM silahların `damage` toplamını çarpıyor (`player.gd` ≈12718-12724 Talon, ≈10942-10948 Kestrel).
- **Yap**: "tüm silahlarının toplam hasarının %60'ı kadar hasar" ve "tüm silahlarının toplam hasarının %150'si kadar hasar".

### A13. Küçük ekler: DENETÇİ, düşük öncelik
- Aldric E (`characters.gd` ≈383): cümlenin sonuna "Canı %25'in altındayken yansıtmaz." ekle. Doğrulama: `player.gd` `SOVALYE_E_MIN_HP_RATIO := 0.25` (≈6567) ve `take_redirected_damage`.
- Kraliçe Andrea'nın Kitabı (`items.gd` ≈265): "(Q, E, R)" yerine "(Q, E, R, F)". Doğrulama: `enemy.gd` ≈5140-5143, yuvalar `["q", "e", "r", "f"]`.

---

## PARTİ B: Çok oyunculu boss hataları

Parti testi: `test_gonca_boss.gd`, `test_pumpkin_boss.gd`, `test_kardes_boss.gd`, `test_banshee_boss.gd`, `test_demon_boss.gd`. MP gözlemi için `tools/mp_audit/run_audit.ps1`'in başındaki açıklamayı oku. Uygun mod yoksa görünür pencere AÇMA, özette "iki pencerede izlenmedi" yaz.

### B1. Gonca tohumu ve Balkabağı ateş topu istemciye nişan öndelemiyor: DOĞRULANDI
- **Sorun**: `scripts/gonca_boss.gd` `_lead(p)` (≈254) ve `scripts/pumpkin_boss.gd` `_lead_point(player)` (≈188) hedefin `velocity` alanını okuyor. Uzak oyuncu kuklası (`scripts/remote_player.gd`) `velocity`'yi hiç yazmıyor, hep sıfır. Sonuç: host'a öndelemeli, istemcilere öndelemesiz atış.
- **Örnek çözüm**: `scripts/kardes_boss.gd` ≈596-611 (`_track` + `_lead`): oyuncu konum farkından kendi hız tahminini tutuyor.
- **Yap** (iki dosyada da aynı):
  1. `var _last_pos: Dictionary = {}` ve `var _vel: Dictionary = {}` ekle.
  2. `kardes_boss.gd`'deki `_track(delta)` fonksiyonunu kopyala. `AbilitiesScript.damageable_players` bu dosyada nasıl çağrılıyorsa öyle çağır (dosyadaki mevcut kullanımına bak).
  3. `process(delta, player, dist)` fonksiyonunun EN BAŞINDA `_track(delta)` çağır (gonca ≈84, pumpkin ≈94).
  4. `_lead` / `_lead_point` içinde: `velocity` okunamıyorsa YA DA `Vector2.ZERO` ise `_vel.get(p.get_instance_id(), Vector2.ZERO)` kullan. `velocity` sıfırdan farklıysa eski davranış aynen kalsın (host'un kendi oyuncusu ve testler bozulmasın).
- **Kontrol**: iki boss testi geçmeli.

### B2. Banshee ve Uçan Şeytan'ın içinden yalnız host geçebiliyor: DOĞRULANDI
- **Sorun**: `no_body_block` yalnız boss kitinin `setup()`'ında atanıyor (`scripts/banshee_boss.gd` ≈66, `scripts/demon_boss.gd` ≈88). Kit istemcide hiç kurulmuyor (`scripts/enemy.gd` `_init_abilities()` tek çağrı yeri ≈4387, kukla erken dönüşünden sonra). İstemcinin oyuncusu bossa takılıyor.
- **Önce doğrula**: `scripts/enemy_spawner.gd` `_setup_boss_enemy` (≈1947) host doğuşunda, istemci doğuş RPC'sinde ve geç katılım yakalamasında çağrılıyor mu (Grep `_setup_boss_enemy(`, 3 çağrı beklenir)? `no_body_block` `enemy.gd`'de tanımlı bir değişken mi?
- **Yap**: `enemy_spawner.gd`'ye `const NO_BODY_BLOCK_BOSSES := ["banshee1", "ucansetan1"]` ekle. `_setup_boss_enemy` içinde, `boss_id` metası atandıktan sonra: `if id in NO_BODY_BLOCK_BOSSES: enemy.set("no_body_block", true)`. Kitlerdeki mevcut satırlar kalsın.
- **Kontrol**: `test_banshee_boss.gd`, `test_demon_boss.gd`.

### B3. Ok ve Büyü Kardeş'te "dash" klibi yok: DOĞRULANDI
- **Sorun**: ölen kardeşten devralınan Atılma `_start_move(..., "dash")` çağırıyor (`scripts/kardes_boss.gd` ≈344-352). `scenes/creatures/enemy_kardes_ok1.tscn` ve `enemy_kardes_buyu1.tscn` `special_textures` içinde yalnız `cast` ve `attack` var. Klip bulunamayınca sessizce atlanıyor, boss yürüme pozunda kayıyor.
- **Yap**: `_start_move` içinde `_anim(anim_name, ...)` çağrısından önce: sahibin (`e`) `special_textures` sözlüğünde `anim_name` yoksa `"attack"` kullan. `_anim` hem yerelde oynatıp hem ağa yolladığı için istemciler de aynı klibi görür.
- **Kontrol**: `test_kardes_boss.gd`.

---

## PARTİ C: Oyun mantığı

### C1. Tek oyunculuda çalışmayan seçenekler (KARAR K8, varsayılan a): DOĞRULANDI
**Ruhani "Kalkan Bağı"**
- **Sorun**: `player.gd` `_spirit_cast_kalkan_bagi` (≈14203) çok oyunculu değilken "ARKADAŞ YOK" yazıp dönüyor. `scripts/spiritual_picker.gd` (≈70-95) tek oyunculuda da seçtiriyor.
- **Önce oku**: seçicinin nerede kurulduğu (Grep `spiritual_picker` `scripts/` içinde) ve seçimin nerede saklandığı. Tek oyunculu karakter seçiminde `NetworkManager.is_multiplayer_active` yanlış mı?
- **Yap**:
  1. `scripts/spiritual_skills.gd`'ye `const MULTIPLAYER_ONLY := ["kalkan_bagi"]` ekle.
  2. Seçicide, çok oyunculu değilken bu kimlikler için: düğme soluk (`modulate` alfa 0.45), basınca seçilmesin, ipucuna yeni satır "Yalnız çok oyunculuda çalışır." eklensin.
  3. Tek oyunculu koşu başlarken kayıtlı seçim bu listedeyse o koşu için seçicinin varsayılanına düş. Kayıtlı tercihi SİLME (çok oyunculuda geri gelsin).
- Seçimin saklandığı yer bu tarife uymuyorsa yalnız 1 ve 2'yi yap, 3'ü `## İlerleme`ye not düş.

**Evrim "Kadim Diriliş" (`oakley_rf`)**
- **Sorun**: `player.gd` `oakley_tree_revive_ally` (≈11482) çok oyunculu değilken `false` dönüyor. `scripts/skill_evolutions.gd` `available()` (≈390-408) yine de sunuyor.
- **Yap**:
  1. `oakley_rf` tanımına `"mp_only": true` ekle.
  2. `available(char_id, owned, level)` imzasına sona `solo: bool = false` ekle. `solo` doğruysa `mp_only` girdileri atla.
  3. `available(` çağıran yerleri bul (Grep `\.available\(`), oyun içi çağrıda `not NetworkManager.is_multiplayer_active` gönder. Statik fonksiyonun içinden `NetworkManager`'a ERİŞME (parametreyle gelsin).
- Diğer müttefik evrimlerine (`melek_qf`, `melek_q3`, `melek_e4`, `sovalye_e2`) DOKUNMA: tek oyunculuda evcil / iskelet gibi müttefikleri etkileyip etkilemediği doğrulanmadı.
- **Kontrol**: `test_skill_evolutions.gd`, `test_evolution_cards.gd`, `test_oakley_evolutions.gd`, `test_spiritual_skills_and_rewards.gd`.

### C2. Tavana ulaşmış stat kartı sunulmasın: DENETÇİ
- **Sorun**: `scripts/level_up_screen.gd` `_populate_cards` (≈480-489) düz kart havuzunu yalnız "gösterildi mi / bedeli ödenir mi" diye süzüyor. Bekleme azaltma %60'ta, Sıvışma tavanında, Kritik %100'de kart boşa gidiyor. Sandık aynı durumu `player.gd is_stat_capped` (≈655) ile zaten eliyor.
- **Önce doğrula**: `player.gd apply_upgrade` içinde `cooldown_reduction`, `dodge`, `crit_chance` dalları gerçekten tavanda kırpıyor mu?
- **Yap**: `level_up_screen.gd`'ye yardımcı ekle: kart kimliği `dodge` ise `"dodge_chance"`, `crit_chance` ise `"crit_chance_bonus"`, `cooldown_reduction` ise `"cooldown_reduction_percent"` adıyla `player.is_stat_capped(...)` sorulur. Oyuncu yoksa ya da metot yoksa `false`. ≈486'daki süzgece `and not <yardımcı>(str(u["id"]), player)` ekle.
- **Kontrol**: `level_up_screen` kullanan testleri bul (Grep `level_up_screen` `tests/` içinde, dosya adlarıyla) ve koş.

### C3. HUD yetenek ipucunda yanlış bekleme süresi: DENETÇİ
- **Sorun 1 (Q, herkes)**: `scripts/skill_icon.gd` ≈149 `current_cd = player._skill_cooldown`. Bu değer ilk kullanıma kadar `DEFAULT_SKILL_COOLDOWN` (20). E için aynı dosyada ≈244-245 doğru formül var: `base_cd * (1.0 - cdr)`.
- **Yap 1**: ≈149'u E'deki formülle değiştir (`cdr` = `player.get_cooldown_reduction()`, E dalındaki korumalarla aynı).
- **Sorun 2 (Corvina Q, Flint Q, Flint E)**: bu yeteneklerin zamanlama tablosunda girdisi yok, başlık varsayılanı (20 / 15 sn) gösteriyor. Gerçek: Corvina Q `NECRO_SKELETON_COOLDOWN` (0.2), Flint E `_korsan_bomb_recharge_time()` (7), Flint Q beklemesiz.
- **Önce oku**: `scripts/hud.gd` ≈870-895 (`icon.cooldown_override` nasıl ve hangi yetenekler için veriliyor) ve `skill_icon.gd` ≈150-152, ≈246-249, `_cooldown_bbcode` (≈426).
- **Yap 2**: mevcut `cooldown_override` yolunu kullanarak bu üç yeteneğe doğru değeri ver. Flint Q için "Bekleme yok" yazısı `now < 0` iken çıkıyor: gerekirse simgeye `no_cooldown` gibi küçük bir alan ekle. Yük dolumuna bekleme azaltma işlemediği için (K3 cevaplanana kadar) Flint E'nin başlığı azaltmayla ÇARPILMAMALI.
- Mevcut `cooldown_override` yolu bu üçünü karşılamıyorsa yalnız "Yap 1"i yap, gerisini not düş.
- **Kontrol**: `test_passive_and_tooltips.gd`.

### C4. Bekleme azaltma yüklere işlesin (KARAR K3, varsayılan ATLA)
Cevap (a) ise: `player.gd` `_korsan_bomb_recharge_time()` (≈4198) sonucunu `(1.0 - get_cooldown_reduction())` ile çarp. `ASSASIN_DASH2_RECHARGE_TIME`'ın 4 kullanım yerini (Grep) aynı çarpanı uygulayan tek bir fonksiyona bağla. Shaman yükündeki uygulamaya bak (Grep `get_cooldown_reduction` Shaman bölümünde) ve aynısını yap. `BALANCE_REV` +1.

---

## PARTİ D: Arayüz tutarlılığı

### D1. Çıkışta onay (KARAR K9, varsayılan evet): DOĞRULANDI
- **Sorun**: `scripts/pause_menu.gd` `_on_menu` (≈508) ve tek oyunculu `_on_restart` (≈500-503) koşuyu onaysız bitiriyor. Host'un ANA MENÜ'sü odayı herkes için kapatıyor. TESLİM OL'da çift basış var (`_surrender_confirm`, ≈107, ≈136-140, ≈363-368, ≈397-405).
- **Yap**: aynı kalıbı kopyala.
  1. `_menu_confirm` ve `_restart_confirm` değişkenleri.
  2. İlk basış: bayrağı aç, öğenin yazısını "EMİN MİSİN?" + alt yazıya çevir (yazı değiştirme için ≈496'daki `_set_item_texts` kullanımına bak). Alt yazılar: ANA MENÜ için "Tekrar bas: koşu kaybolur", host ve çok oyunculu ise "Tekrar bas: oda herkes için kapanır", YENİDEN BAŞLA için "Tekrar bas: koşu baştan başlar".
  3. İkinci basış: bugünkü davranış.
  4. Bayrakların sıfırlanması: `_surrender_confirm` nerede sıfırlanıyorsa (odak başka öğeye geçince, menü kapanınca) orada üçü birlikte.
  5. `GameManager.is_game_over` doğruysa onay İSTEME (koşu zaten bitmiş).
  6. Çok oyunculu YENİDEN BAŞLA'ya dokunma (zaten oylama).
- Yeni metinler için bölüm 2.
- **Kontrol**: `test_pause_over_end_screens.gd`, `test_gamepad_pause_start_only.gd`.

### D2. Sabit yazılmış tuş adları: DOĞRULANDI
- **Yükleme ipuçları**: `scripts/loading_screen.gd` `TIPS` (≈117-126): "F tuşu ruhani yeteneğini kullanır." ve "Space tuşu ile etkileşime girersin." Yeniden atamayı ve kumandayı yok sayıyor.
  - **Önce doğrula**: `scripts/game_manager.gd` `_setup_input_actions` (≈589-676) içinde ruhani yeteneğin ve etkileşimin eylem adları (beklenen `skill4` ve `interact`). `tip_pool()` başka nerede kullanılıyor (Grep `tip_pool`)?
  - **Yap**: bu iki ipucunu kalıba çevir: "%s tuşu ruhani yeteneğini kullanır." ve "%s tuşu ile etkileşime girersin.". Gösterim yerinde (≈256) kalıplı ipucu seçildiyse `tr(kalıp) % GameManager.get_action_hint_label(eylem)` yaz ve o etiketin otomatik çevirisini kapat (`auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED`). Hangi ipucunun hangi eyleme bağlı olduğunu küçük bir sözlükle tut (`TIP_ACTIONS := {kalıp: eylem}`), `TIPS`'in türünü (`Array[String]`) bozma.
- **Duraklatma ipucu**: `scripts/pause_menu.gd` ≈208 `[["ESC", "devam et"], ["W/S", "seç"], ["Enter", ...]]`.
  - **Yap**: "W/S" yerine `GameManager.get_action_key_label("move_up") + "/" + GameManager.get_action_key_label("move_down")`. "ESC" ve "Enter" atanamayan tuşlar, kalsın. `GameManager.pad_hints_active()` doğruysa üçlü `["START", ...], ["↕", ...], ["A", ...]` olsun.
- Kart tuşları 1/2/3, Space, F1/F2'ye DOKUNMA (yeniden atanabilir yapmak yeni özellik).
- **Kontrol**: `test_loading_screen_script_loading.gd`, `test_loading_boot_preload.gd`, `test_pause_over_end_screens.gd`.

### D3. Palet dışı renkler (KARAR K10)
Yalnız aşağıdaki üç adım. Kitlere (`menu_kit.gd`, `ui_kit.gd`), `minimap.gd`, `boss_bar_art.gd`, `records_screen.gd` ve bütün FX dosyalarına DOKUNMA (anlamlı ya da sanat renkleri).
1. **Rolle birebir aynı olan hex'ler** (görsel fark yok): `scripts/hud_theme.gd`'deki her rolün hex'ini `scripts/game_notice.gd`, `wait_overlay.gd`, `game_over_board.gd`, `world_event_banner.gd`, `lock_badge.gd` içinde ara, bulduğunu `HudTheme.<ROL>` ile değiştir (bilinenler: `f0c070` = `ACCENT`, `4b3320` = `RIM_LO`).
2. **Yakın kremler** (K10 evet ise): `f3f0d8`, `f6e6cc`, `f6ecd2`, `ecd9b0` yalnız `game_notice.gd`, `wait_overlay.gd`, `game_over_board.gd` içinde ve yalnız YAZI rengi olarak kullanılıyorsa `HudTheme.TEXT`. Zemin ya da çizim rengi ise dokunma.
3. **Kopya tablo**: `level_up_screen.gd` `ROW_GLOW_COLORS` (≈624) ile `enchant_screen.gd` `GLOW_COLORS` (≈52) aynı 4 renk. `hud_theme.gd`'ye `const TIER_GLOW: Array = [...]` ekle (yorum: kademe parıltısı, anlamlı renk), iki dosya bunu okusun. `enchant_screen.gd` `POWER_COLOR` (`9cc4ff`) `TIER_GLOW[1]` olsun.
- **Kontrol**: `test_shop_palette.gd`. Görsel doğrulama için ekran görüntüsü alma, özette "gözle bakılmadı" yaz.

---

## PARTİ E: Ses

### E1. Ruhani yetenek sesi diğer oyunculara gitmiyor: DOĞRULANDI
- **Sorun**: `player.gd` `_spirit_play_sound(path, volume_db)` (≈13784) yalnız yerelde çalıyor, 8 çağrı yeri var. `_play_networked_sound(path, pitch, volume_db)` (≈9661) yerelde çalıp "weapon_sound" ile yayınlıyor.
- **Önce oku**: `_play_networked_sound` gövdesi (yayın satırları) ve 8 çağrı yeri. Döndürülen oynatıcıyı saklayıp sonradan durduran ya da döngülü ses çalan çağrı var mı?
- **Yap**: `_spirit_play_sound`'a sona `broadcast: bool = true` parametresi ekle. Yerel çalma ve dönüş değeri AYNI kalsın. `broadcast` doğru ve çok oyunculu etkinse `_play_networked_sound`'un yaptığı yayının aynısını yap (yerelde ikinci kez ÇALMA). Döngülü ya da erken durdurulan ses çalan çağrıya `false` geç.
- **Kontrol**: `test_spiritual_skills_and_rewards.gd`, `test_weapon_sound_net.gd`.

### E2. Eksik sesler (KARAR K12, varsayılan ATLA)
Ses seçimi kullanıcının işi (rastgele üretilen ya da işlenen ses daha önce reddedildi). Bu görev yalnız `docs/cila/SESLER.md` dolduysa yapılır. O dosya yoksa yürüten oturum yalnız BOŞ tabloyu oluşturur ve durur.

Tablonun satırları (kullanıcı her satıra `assets/audio/...` yolu yazar ya da "yok" der):

| Olay | Bağlanacağı yer |
|---|---|
| Kademe değişimi | `scripts/main.gd` `_on_creature_tier_reached` (≈2876), `EventSfx` |
| Zafer | `scripts/main.gd` zafer akışı (şu an "mission_success" çalıyor, ≈3077) |
| Düşük can uyarısı | `scripts/player.gd` hasar alma yolu, `EventSfx` |
| Efsun uygulandı | `scripts/enchant_screen.gd` |
| Altın yetmiyor | `scripts/merchant_shop_screen.gd` (≈588) |
| Hazel E ve R | `player.gd`, Grep `geçici: Cadı'ya özel ses yok` (2 satır) + `SKILL_SFX` tablosu |
| Tırpan ve Mızrak savurma | `scenes/weapon_pence.tscn`, `scenes/weapon_mizrak.tscn` `AttackSound` |
| Korsan R başlangıcı | `player.gd` ≈4382-4403 |
| Boss yetenekleri: Gonca, Medusa, Wendigo, Üç Kardeş, Balkabağı, Banshee | Her yeteneğin dünya efekti betiği (`gonca_seed.gd`, `medusa_gaze.gd`, `wendigo_rock.gd`, `kardes_shot.gd` ...). Efekt her istemcide doğduğu için ses efektin içinden çalınır, ayrıca yayın gerekmez. |
| Yaratık menzilli atışı | `scripts/enemy_projectile.gd` |

Bağlama kuralları: olay sesleri `scripts/event_sfx.gd` `SOUNDS` sözlüğüne anahtar olarak eklenir ve `EventSfx.play(get_tree(), &"anahtar")` ile çalınır. Ses düzeyi için aynı türden mevcut bir sesin dB değerini kullan. Çalışma anında `load()` ile okunan yeni ses eklendiyse `tools/gen_fx_warmup_list.ps1` koş. Sesi işleme, kırpma, efekt ekleme YOK.

---

## PARTİ F: Temizlik

Her silmeden önce adı `scripts/`, `scenes/`, `shaders/`, `tests/`, `tools/`, `assets/` ve `project.godot` içinde Grep ile ara. Kendisinden başka bir yerde geçiyorsa SİLME, not düş. Silinen `.gd` / `.gdshader` dosyasının yanındaki `.uid` dosyasını da sil.

- **F1**: `scripts/sprite_bar.gd` (denetimde yalnız kendi içinde geçiyordu).
- **F2**: `scenes/gölge.gdshader`, `scenes/çimen parçalar.gdshader`, `scenes/harita_baked.gdshader`. `tools/` içinde (harita pişirme betikleri) geçiyorsa KALSIN.
- **F3**: `player.gd` `get_skill_display()` ve `get_skill2_display()` (≈5451-5468): çağıran yoksa sil.
- **F4**: `player.gd`'de hiç kullanılmayan üç sabit: `EVO_MATTHEW_E_EXTRA_DURATION`, `EVO_MATTHEW_PATIENCE_TIME`, `EVO_MATTHEW_PATIENCE_SPEED`. Yalnız 0 kullanımı olanı sil. `matthew_haste_bonus` / `matthew_fox_stun_time` fonksiyonlarına DOKUNMA.
- **F5**: eskimiş yorumlar: `scripts/skill_evolutions.gd` ≈15 ("karıştırma YOK" artık yanlış, evrim karıştırma var), `player.gd` ≈16048 ("12 -> 16 sn" yerine 20 -> 24), `player.gd` ≈13977 ("%60" yerine %200), `characters.gd` ≈731 (Nox Q "hiçbir bedel ödemez" artık yanlış). Yalnız yorum satırı.

SİLİNMEYECEKLER (denetimde ölü sanıldı ama kullanılıyor): `assets/fonts/` altındaki `Nunito` ve `PixelifySans` (kodda geçiyor), `scenes/papagan_pet.tscn`, `scripts/weapon_shop_screen.gd`, `scripts/combat_tuning.gd` (autoload), `scenes/çimen kir.gdshader`.

---

## BÖLÜM G: Bu planda YÜRÜTÜLMEYECEK işler

### G1. Tasarım kararı bekleyenler (kullanıcı karar verince ayrı görev olur)
- **Kademe 5 Minotaur tıkanması**: kayıtlarda 7 dövüşün 2'si kazanılmış, ikisi de ~12 dk (719 ve 761 sn). K5'ten K6'ya geçiş medyan ~11 dk, diğer kademeler 2,5-3 dk. İlk bakılacak yer: 4 oyuncuda can/kalkan x2,5 (`EXTRA_PLAYER_DEFENSE_MULT`) + %80 kalkan soğurması (`enemy_spawner.gd` `FIXED_BOSS_STATS`, `BOSS_SLOT_STATS`).
- **Ölü oyuncunun beklemesi**: teslimle biten koşularda kalıcı ölen 4 oyuncu 11-19 dk izleyici kaldı.
- **Talon ve Elara'da yetenek hasar payı** %2-6 (silah %94-98).
- **Ruhani yetenek** 36 kaydın 22'sinde seçilmemiş: seçici gözden kaçıyor olabilir.
- **Proje adı "Temiz Sürüm"** ve kayıt klasörü: çıkıştan önce karar. Adı değiştirmek kayıt klasörünü değiştirir. Kayıtları korumanın yolu `application/config/use_custom_user_dir` + `custom_user_dir_name`. Kullanıcıyla birlikte, kayıt yedeği alınarak yapılır.
- **Sürüm numarası** oyunda görünmüyor (Windows 0.8.3.1, Android 0.1).
- **Öğretici**, **koşu sırasında müzik**, **ayrı SFX ses ayarı**, **vsync**, **renk körlüğü seçeneği**: yeni özellik.
- **F9 hata ayıklama paneli** (`scenes/debug_tuning_panel.tscn` hiçbir yerde kurulmuyor, tuş bağlı): silinsin mi, geri mi bağlansın?
- **"mana kalkanı harcamaz"** ifadesi bazı yeteneklerde yazıyor bazılarında yazmıyor (Talon E, Seraphine E, Aldric Q/R, Lyra Q, Matthew R de bedelsiz).
- **Savaş mana kalkanı kartı** "+110 / +%55" yazıyor ama Standart'ın yerine geçiyor (alt yazıda söylüyor, artı işareti yanıltıcı).

### G2. Daha güçlü modelle yapılacak hatalar (çekirdek sisteme dokunuyor)
- **Host devrinde boss dövüşü baştan başlıyor**, Üç Kardeş'te ölen kardeş geri geliyor (`enemy_spawner.gd` `export_handover` / `import_handover` ≈868-905). Ölen boss kimliklerinin devri + kalan kardeşlerin öfke durumu gerekir.
- **Uçan Şeytan'ın 2. faz görünümü, iyileşme rengi ve sesi istemcide yok** (boss kiti istemcide kurulmuyor, olaylar `enemy.gd` ≈477'de düşüyor).
- **Kalkan siperinde hasar azaltmayı host, kuklanın kendi yönüne göre hesaplıyor** (şüpheli).
- **Medusa taş pozu** diğer ekranlarda idle oynatmaya devam ediyor (kozmetik).
- **Ödülsüz dağıtılan Filiz / kabak / yarasa** istemcide tam ölüm oynayabiliyor (yarış durumu, şüpheli).

---

## İlerleme

Yürüten oturum her görevden sonra işaretler. Atlanan görevin yanına tek satır neden yaz.

**Parti A**
- [x] A1 Corvina ömür (2026-11-15: 30sn / 60sn)
- [x] A2 Seraphine bekleme (26sn / 17.25sn)
- [x] A3 Lyra Don Nova (0.5sn; `characters.gd` + `player.gd` dinamik HUD metni)
- [x] A4 Seviye kartı sayıları (K4=a varsayılan; formül doğrulandı: gösterim ve `tier_mult` aynı; +%3.5 / +%3.5 / +%6.5. Kart `desc`leri `Loc.pct` ile çevriliyor, .po girdisi yok)
- [x] A5 Can Çalma açıklaması
- [x] A6 Demirci metinleri (görünen ad "Pazar" / İngilizce "market"; üç metin `ShopsFlag.enabled`e bağlı, kapalıyken "level pazarından")
- [x] A7 Son Felaket Pençesi (K5=a varsayılan; `Items.describe` pasifsiz eşyada `def.has("passive")` korumalı)
- [x] A8 Hazel R (doğrulandı: `damage_bonus * CadiMath.HEAL_RATIO / SHIELD_RATIO`)
- [x] A9 Silah katalog metinleri (K1=a varsayılan). Not: Yıldırım tik aralığı planda "fire_rate / 0.7" yazıyordu, gerçekte `beam_tick_interval` 0.3704 / 0.7 = 0.53 sn (sonuç ~1.9 tik/sn, plan sayısı ~%87 doğru). Arbalet menzili 220.5 -> 220 bırakıldı. Çakram "0.5sn"e dokunulmadı.
- [x] A10 Yıkılmaz Duvar (%225; doğrulandı: sahne oranı 1.5 x `WALL_DAMAGE_MULT` 1.5)
- [x] A11 Evrim metinleri (3 evrim; hepsi kodla doğrulandı)
- [x] A12 Talon E / Kestrel E metni (K2=a varsayılan)
- [x] A13 Küçük ekler (Aldric E, Kraliçe Andrea; ikisi de kodla doğrulandı)
- [x] A çevirileri 9 dilde dolduruldu (28 metin x 9 dil + `test_localization`'ı düşüren, Parti A dışı 2 metin), not yazıldı (madde 713). Testler: 8/9 GEÇTİ. `test_oakley_evolutions::test_fruit_bonus_and_six_flowers` DÜŞÜYOR (meyve can beklenen 13.3, bulunan 19.95 = tam x1.5): Parti A yalnız `oakley_qf` metnini değiştirdi, `OakleyTree` koduna dokunulmadı; eski/başka işten sapma, incelenmedi. `test_pets::test_pet_follow_air_spring_lags_then_settles` da düştü (Peri/Kelebek kodu, ilgisiz).

**Parti B**
- [ ] B1 Nişan öndeleme
- [ ] B2 no_body_block
- [ ] B3 Kardeş dash klibi
- [ ] B testleri geçti, not yazıldı

**Parti C**
- [ ] C1 Tek oyunculuda ölü seçenekler (K8)
- [ ] C2 Tavandaki stat kartı
- [ ] C3 HUD bekleme süresi
- [ ] C4 Bekleme azaltma yüklere (K3)
- [ ] C testleri geçti, not yazıldı

**Parti D**
- [ ] D1 Çıkış onayı (K9)
- [ ] D2 Tuş adları
- [ ] D3 Palet (K10)
- [ ] D çevirileri, testler, not

**Parti E**
- [ ] E1 Ruhani ses yayını
- [ ] E2 Eksik sesler (K12)

**Parti F**
- [ ] F1 sprite_bar.gd
- [ ] F2 shader'lar
- [ ] F3 ölü fonksiyonlar
- [ ] F4 kullanılmayan sabitler
- [ ] F5 eskimiş yorumlar
