# Denge planı (2026-11-14) - silahlar, petler, ruhani büyüler

Bu dosya uygulayacak oturum için yazıldı. Kullanıcı önerileri onayladı; buradaki sayılar karardır, yeniden tartma.
Yalnız **sayı / metin / küçük formül** değişikliği var: yeni silah, yeni efekt, yeni ağ mesajı YOK (cila dönemi).

## 0. Başlamadan

- `CLAUDE.md` kurallarını uygula: `git fetch` + `git status`; çalışma ağacında commit edilmemiş çok dosya var (`scripts/weapon_traits/siper.gd`,
  `scripts/weapon_traits/weapon_traits.gd`, `scenes/weapon_kalkan.tscn`, `scripts/weapon_catalog.gd` dahil). **Hiçbir dosyayı `git checkout` / `restore`
  etme, üzerine yazma; yalnız `Edit` ile nokta değişikliği yap.**
- Satır numaraları 2026-11-14 çalışma ağacına göredir, kayabilir: önce `Grep` ile sabiti bul.
- Her sayı için eski değeri tüm depoda ara (kopya olabilir): `scripts/`, `scenes/`, `tests/`, `scripts/characters.gd`, `scripts/level_market*.gd`,
  `scripts/weapon_shop_logic.gd`, `scripts/damage_stats.gd`.
- `scripts/enchant_defs.gd` içindeki eski efsun KART kopyalarına (kapalı sistem: "Sismik Dalga", "Wind Sword" ...) DOKUNMA; geçerli tanımlar
  `scripts/weapon_traits/weapon_traits.gd` `DEFS`.
- Silahların gerçek atış aralığı = sahnedeki `fire_rate` / 0,7 (`GameManager.WEAPON_ATTACK_SPEED_MULT`). Yakın dövüşte gerçek oran =
  sahne `card_damage_bonus_ratio` x 1,4 (`weapon.gd MELEE_EXTRA_DAMAGE_MULT`; Bıçak / Tırpan / Balyoz).

## 1. Silahlar

### 1.1 Tırpan (pence) - kırp
Alan payı zaten %50'ydi (tam hasar değil); asıl fazlalık en yüksek yakın dövüş oranı + alan + kanama birlikte.
- `scripts/player.gd` `_configure_pence_melee`: `w.configure_melee(110.0, 80.0, 0.5, ...)` üçüncü parametre (`aoe_percent`) **0.5 -> 0.35**.
- `scenes/weapon_pence.tscn`: `card_damage_bonus_ratio` **1.35 -> 1.25** (gerçek %189 -> %175).
- Kanama (`kp_ap` 0.30, `kp_area` 0.6667) ve can emme AYNI kalır.
- Metin: `weapon_catalog.gd DESCRIPTIONS["pence"]` "%189" -> "%175", sonuna alan payını yaz: "çevresine alan hasarı (80, alandakilere %35)".

### 1.2 Balyoz (topuz) - Sismik Dalga'yı kırp
- `scripts/weapon_traits/weapon_traits.gd` `sismik_dalga` base `set`: `"seis_ap"` **0.7 -> 0.5**.
- `scripts/weapon_traits/sismik_dalga.gd`: `const FULL_TARGETS` **8 -> 4** (üstündeki yorumu da güncelle).
- Metinler (aynı dosya, `DEFS`): base "en yakın 8 düşmana saldırı gücünün %70'i" -> "en yakın 4 düşmana saldırı gücünün %50'si";
  "Tok Darbe" "%70'i → %90'ı" -> "%50'si → %70'i" (`add` 0.2 aynı).
- Balyozun kendi vuruşu (`TOPUZ_AOE_PERCENT` 0.35, sahne oranı 0.945) AYNI kalır.

### 1.3 Gökkuşağı Asası - kırp
- `scenes/weapon_gokkusagi.tscn`: `card_damage_bonus_ratio` **1.1 -> 0.7** (`beam_tick_ratio` 1.0 ve `beam_tick_interval` aynı) -> saniyede %140.
- `scripts/weapon.gd`: `const RBEAM_SPLASH_MAX` **4 -> 3** (yorumlar: satır ~115 ve ~3181).
- Metin: `DESCRIPTIONS["gokkusagi"]` -> "saniyede %140 saldırı gücü (0,5 sn'de bir %70) ... en çok 3 düşmana yarım hasar".
- Özellik (`goz_kamastiran`) metinlerindeki %60 / %20 sayıları ayrı sabitlerdir, dokunma.

### 1.4 Zehir Asası (tuftuf) - güçlendir
- `scenes/weapon_tuftuf.tscn`: `fire_rate` **1.4142 -> 1.19** (gerçek 2,0 -> 1,7 sn).
- `weapon_traits.gd` `sicrayan_zehir` base `set`: `"poison_dur"` **4.0 -> 6.0**; `scripts/weapon_traits/sicrayan_zehir.gd` `_track` içindeki
  yedek değer `f("poison_dur", 4.0)` -> `6.0`.
- Metinler: base "4 saniyelik zehir yükü" -> "6 saniyelik"; "Uzun Etki" "(4 → 6 sn)" -> "(6 → 8 sn)" (`add` 2.0 aynı);
  `DESCRIPTIONS["tuftuf"]` "Ateş hızı 2.0sn" -> "1.7sn".
- Doğrula (değiştirme, yalnız oku): `enchant_behavior.gd apply_poison_to` yüklerin süresini nasıl işliyor (her yük ayrı mı sönüyor, yeni isabet
  hepsini tazeliyor mu). Sonucu bitiş notuna bir satır yaz.

### 1.5 Yin Yang Kitabı - güçlendir
- `weapon_traits.gd` `denge` base `set`: `"ys_shield"` **0.1 -> 0.15**, `"yin_ap"` **0.2 -> 0.4**.
- `scripts/yinyang_book.gd` içinde %10 kalkanın ayrı bir sabiti / yedek değeri varsa onu da 0.15 yap (grep `0.1`, `ys_shield`).
- Metinler: base "saldırı gücünün %20'si kadar hasar" -> "%40'ı"; Yang "(saldırı gücünün %15'i)" -> "(saldırı gücünün %22,5'i)";
  "Kalın Sayfa" "%10'u → %13'ü" -> "%15'i → %18'i"; "Ağır Yin" "%20'si → %35'i" -> "%40'ı → %55'i";
  `DESCRIPTIONS["yinyang"]` "saldırı gücünün %10'u kadar mana kalkanı" -> "%15'i".
- Final (`tc_*`) aynı kalır.

### 1.6 Buz Asası - DESTEK silahına dönüşüyor (kullanıcı kararı)
Kullanıcı: "hasarını artırmak yerine daha hızlı ve daha seri dondursun, saldırı hızı daha yüksek olsun, supportive bir iteme dönüşsün."
Saniyelik hasar AYNI kalır (0,58 -> 0,60 SG/sn); değişen vuruş sıklığı ve kitle kontrolü.
- `scenes/weapon_buz_asasi.tscn`: `fire_rate` **1.09425 -> 0.70** (gerçek 1,56 -> 1,0 sn); `card_damage_bonus_ratio` **0.9 -> 0.6**.
- `weapon_traits.gd` `kirik_buz` base `set`'e ekle: `"slow_pct": 0.3, "slow_dur": 1.5` (ortak anahtarlar; `enchant_behavior.gd _generic_hit`
  `slow_pct > 0` ise her isabette yavaşlatır - yeni kod gerekmez). `freeze_after` 2, `freeze_dur` 1.5, `freeze_count_global` AYNI.
  Sonuç: her isabet %30 yavaşlatır, dondurma 3,1 sn'de bir yerine 2,0 sn'de bir gelir.
- Metinler:
  - `kirik_buz` `desc`: "Asa hızlı atar: her isabet yavaşlatır, sık sık dondurur; donmuşken ölen düşman parçalanır."
  - base `text`: "Asanın her isabeti vurduğu düşmanı 1,5 saniye %30 yavaşlatır, her 2. isabeti 1,5 saniye dondurur. Donmuşken ölen düşman
    parçalanır: 100 birim içindekilere saldırı gücünün %120'si kadar vurur ve onları 1 saniye %40 yavaşlatır."
  - `DESCRIPTIONS["buz_asasi"]`: "HASAR: %60 saldırı gücü · Ateş hızı 1.0sn · Menzil 151 · Her isabet %30 yavaşlatır, her 2. isabet dondurur"
  - `weapon_catalog.gd STAT_BARS["buz_asasi"]`: **[4, 5, 6, 7] -> [3, 7, 6, 9]** (dörtlü başka silahla aynı olmamalı: `test_start_weapon_pick`).
- Bilinen sonuç (kabul): "Çabuk Don" geliştirmesiyle (her isabet dondurur) tek bir sıradan yaratık sürekli donuk kalır (eskiden de %96'ydı).
  Bosslar `boss_freeze_hits` yolundan gider, etkilenmez. Geliştirmelere dokunma.
- Kontrol: `tests/test_weapon_frozen_targeting.gd` (asa hedefi donmamış düşmanlara dağıtır) geçmeye devam etmeli.

### 1.7 Yıldırım Asası - güçlendir
- `weapon_traits.gd` `zincir_yildirim` base `set`: `"chain_pct"` **0.35 -> 0.50**.
- Metinler: base "hasarın %35'i" -> "hasarın %50'si"; "Güçlü Atlayış" "ışının %35'i → %50'si" -> "ışının %50'si → %65'i" (`add` 0.15 aynı).

### 1.8 Pompalı Tüfek - güçlendir
- `scenes/weapon_pompali.tscn`: `card_damage_bonus_ratio` **0.34 -> 0.38**.
- Metinler: `DESCRIPTIONS["pompali"]` "6 saçma x %34 ... %204" -> "x %38 ... %228"; `dip_atis` base "%34'ünü ... (toplam %204)" -> "%38'ini ... (toplam %228)".

### 1.9 Kalkan - güçlendir (DÜZ sayı kalır)
Kullanıcı daha önce "% lik kalkan yenilemesi çok op" demişti: azami kalkan yüzdesine ÇEVİRME, düz sayıyı büyüt.
- `weapon_traits.gd` `siper` base `set`: `"siper_per"` **6.0 -> 8.0**, `"siper_cap"` **18.0 -> 24.0**.
- `scripts/weapon_traits/siper.gd` `bash_gain` yedek değerleri `f("siper_per", 6.0)` / `f("siper_cap", 18.0)` -> 8.0 / 24.0.
- Metinler: base "düşman başına 6 ... en fazla 18" -> "8 ... 24"; "Kalın Siper" "6 → 10 ... 18 → 30" -> "8 → 12 ... 24 → 36" (`add` aynı).

### 1.10 Arcane Asası - hızlandır
- `scenes/weapon_arcane.tscn`: `fire_rate` **1.4444 -> 1.19** (gerçek 2,1 -> 1,7 sn). DİKKAT: `weapon_fire.tscn`, `weapon_lightning.tscn`,
  `weapon_gokkusagi.tscn` de 1.4444 - yalnız arcane dosyasını değiştir.
- `DESCRIPTIONS["arcane"]` "Ateş hızı 2.1sn" -> "1.7sn".

### 1.11 Dinamit (fisek) - hızlandır
- `scenes/weapon_fisek.tscn`: `fire_rate` **3.2 -> 2.66** (gerçek 4,6 -> 3,8 sn).
- `DESCRIPTIONS["fisek"]` "Ateş hızı 4.6sn" -> "3.8sn".

### Dokunulmayanlar
Yay, Makineli, Ateş Asası, Tabanca, Tüfek, Arbalet, Mızrak, Çakram, Uzunkılıç, Bıçak.

`weapon_catalog.gd` başındaki "denge turu" yorum bloğuna bu turu tek satır olarak ekle; hız / oranı belirgin değişen silahların `STAT_BARS`
puanlarını gözden geçir (Zehir, Arcane, Dinamit hız +1; hepsi benzersiz kalmalı).

## 2. Petler (`scripts/pet_catalog.gd`)

| Pet | Değişiklik |
|---|---|
| Kirpi | `KIRPI_REFLECT_RATIO` **0.05 -> 0.12**, `KIRPI_SHIELD_REDUCTION` **0.05 -> 0.08** |
| Peri | can = `max(saldırı gücü x 0.10, azami can x 0.015)` |
| Minik Cadı | `SLIME_AP_PERCENT` **0.05 -> 0.08** |
| Köpek | `scripts/player_pet.gd` `FOX_MAX_TARGETS` **5 -> 3** |
| Kelebek, Hayalet, Papağan | değişmez |

- Peri: `pet_catalog.gd`'ye `const PERI_HEAL_MAX_HP_RATIO := 0.015` ekle; `scripts/peri_pet.gd` (~satır 198) dönüş değerini
  `maxf(saldırı gücü x PERI_HEAL_RATIO, float(owner_body.get("max_health")) x PERI_HEAL_MAX_HP_RATIO)` yap. İyileşmenin "BU OYUNDA" sayacı
  (BalanceLog) zaten miktarı okuyorsa ek iş yok; kontrol et.
- Metinler (`DESCRIPTIONS` + dosya başı yorumları + `player.gd` ~4020 Kirpi yorumu):
  - kirpi: "Saldıran yaratıklar mana kalkanı gücünün %12'si kadar hasar alır. Mana kalkanın varken %8 az hasar alırsın."
  - peri: "Canın eksikken 6 saniyede bir can basar (saldırı gücünün %10'u ya da azami canının %1,5'i, hangisi büyükse)."
  - slime: "+%5 saldırı gücü" -> "+%8 saldırı gücü".
- Köpek: `player_pet.gd` satır ~45-50 ve ~864 yorumları.

## 3. Ruhani büyüler (`scripts/spiritual_skills.gd`)

### 3.1 Adc
- `ADC_COOLDOWN` **120.0 -> 75.0**; `DEFS[ADC]["desc"]` "(120sn bekleme)" -> "(75sn bekleme)".

### 3.2 Savaş Şevki - büyüyen eşik + asist
- Yeni sabitler: `SAVAS_SEVKI_STACKS_STEP := 5` (her dönüşümde eşik +5: 50, 55, 60 ...), `SAVAS_SEVKI_ASSIST_STACK := 1`.
- Yeni `static func savas_sevki_threshold(conversions: int) -> int: return SAVAS_SEVKI_STACKS_FOR_AP + SAVAS_SEVKI_STACKS_STEP * conversions`.
- `scripts/player.gd` (~3837-3848): `var _savas_sevki_conversions: int = 0` ekle; `_savas_sevki_on_kill` içindeki `while` döngüsü sabit 50 yerine
  `savas_sevki_threshold(_savas_sevki_conversions)` kullansın, her dönüşümde sayaç +1. Ortak gövdeyi `_savas_sevki_add(stacks: int)` olarak ayır.
- Asist: yeni `func _savas_sevki_on_assist()` -> `_savas_sevki_add(SAVAS_SEVKI_ASSIST_STACK)` (aynı ruhani / güvenli alan koşulları).
  Çağrı yeri: asist altını yerel oyuncuya `scripts/kill_gold.gd` `credit(...)` ile gelir (`assist` 1-3 = hasar / destek / ikisi; **4 = TAKIM payı,
  yük VERMEZ**). `credit`'in asist alan oyuncunun makinesinde çalıştığını ve yerel oyuncuya nasıl ulaşıldığını `scripts/assist.gd` + `kill_gold.gd`'den
  doğrula; öldüren oyuncu kendi öldürmesinden hem öldürme hem asist yükü ALMAMALI.
- Gösterim: `scripts/damage_stats.gd` ~403 ("%d/%d") ikinci sayı artık geçerli eşik (`savas_sevki_threshold(p._savas_sevki_conversions)`);
  `player.gd` ~3549 durum ikonu bir ilerleme oranı gösteriyorsa aynı eşiği kullansın.
- `desc`: "PASİF: Her düşman öldürmede ya da asistte 1 savaş şevki kazanırsın (bosslar 25 verir). 50 savaş şevkine ulaşınca maç boyunca kalıcı +1
  saldırı gücü kazanırsın; her dönüşümde gereken şevk 5 artar (50, 55, 60...). Ayrıca canı %6'dan az olan düşmanları (bosslarda %3) anında katledersin."
- Beklenen: 600 öldürme +12 -> +8, 1300 öldürme +26 -> +15, 3500 öldürme +70 -> +29 saldırı gücü.

### 3.3 Değişmeyenler
Para, Can, Tank, Taktiksel, Kalkan Bağı, Toplayıcı.

## 4. Balans kaydı
- `scripts/balance_log.gd`: `const BALANCE_REV`'i bir artır (şu an 165), yorumuna bu turu yaz.
- Koşu kaydına ruhani seçimini ekle: `"pet": str(GameManager.selected_pet)` satırının (~603) yanına `"spirit": <seçili ruhani kimliği>`
  (oyuncudan `get_spirit_id()` ya da GameManager'daki seçim alanı - hangisi o noktada erişilebilirse).
- `tools/balans_rapor.ps1`: "Evcil hayvan" tablosunun aynısını `spirit` alanı için "Ruhani büyü" başlığıyla ekle (alan yoksa satır atlanır).

## 5. Çeviri (madde 446: msgid = Türkçe metnin kendisi)
Türkçe metni değişen her satırın 9 dildeki çevirisi kopar. Sıra:
1. Tüm metin değişikliklerini bitir.
2. `python -I tools/dil/dil_cikar.py` çalıştır (pot + po birleştirir; eski çeviri `#~` ile saklanır, yeni msgid boş `msgstr` ile eklenir).
3. `localization/{en,de,es,fr,it,pt,pl,ru,zh}.po` içinde boş kalan yeni msgid'leri doldur: aynı dosyadaki `#~` eski çeviriyi alıp yalnız
   sayıları / değişen ifadeyi güncelle. Terimler için `localization/sozluk.md`.
4. `.po` dosyalarını PowerShell `Get-Content/Set-Content` ile yeniden yazma (UTF-8 bozulur); `Edit` ya da Python kullan.

## 6. Testler
Sabitleri kilitleyen testleri yeni değerlere çek, sonra YALNIZ ilgili dosyaları, TEK TEK koş (iki koşu aynı anda başlatılmaz):

`powershell -ExecutionPolicy Bypass -File tools/enemy_rewrite/run_tests.ps1 -Filter "<dosya>.gd"`

- `test_weapon_traits.gd`, `test_new_enchants.gd`, `test_topuz_slam.gd`, `test_gokkusagi_asasi.gd`, `test_yinyang.gd`, `test_kalkan.gd`,
  `test_pompali.gd`, `test_weapon_frozen_targeting.gd`, `test_start_weapon_pick.gd`
- `test_pets.gd` (~262 Peri, ~345 Kirpi), `test_pets_slime_hayalet.gd` (~60), `test_matthew_dog.gd` (~190: hedef sayısı 5 -> 3)
- `test_spiritual_skills_and_rewards.gd` (~87 Adc bekleme; Savaş Şevki için yeni assert: 50 yük -> +1, sonraki eşik 55, asist 1 yük, TAKIM payı 0)
- Peri için yeni assert: düşük saldırı gücü + yüksek azami canda can = azami canın %1,5'i.

Başarısız bir assert sonraki testleri zincirleme bozar: İLK hataya bak. Tam paketi koşma.

## 7. Bitiş
- `docs/notlar/madde_161-170.md` sonuna YENİ madde (numarayı yazma anında seç: başka oturumlar da numara alıyor), `docs/notlar/INDEX.md` en alta TEK satır.
- Commit / push YAPMA; kullanıcıya değişen dosyaları söyle, push isteyip istemediğini sor, "export almayı unutma" hatırlat.
- Kullanıcıya rapor: uygulanan her kalem, koşulan testler ve sonuçları, doğrulanamayan noktalar (Zehir yük davranışı, asist çağrı yeri).

## Dayanak (özet)
Kayıt: 18 koşu, revizyon 161, hepsi çok oyunculu. Saniyelik hasar ÷ saldırı gücü medyanı: Balyoz 3,49 · Tırpan 1,85 (bir koşuda 7,95, toplam hasarın
%34'ü) · Ateş 1,36 · Tüfek 1,30 · Tabanca 1,23 · Arbalet 1,21 · Mızrak 1,16 · Çakram 1,04 · Makineli 0,96 · Kalkan 0,90 · Yıldırım 0,84 ·
Pompalı 0,81 · Yay 0,74 · Buz 0,72 · Yin Yang 0,63 · Zehir 0,54. Gökkuşağı / Arcane / Dinamit / Bıçak / Uzunkılıç için kayıt yok (kâğıt hesabı).
Kirpi hasarın %0,4-1,9'u; Kelebek %4,8-7,5; Tank ruhanisi Aldric'in hasarının %18-22'si. Bu turdan sonra birkaç koşu oynanıp
`tools/balans_rapor.ps1` ile yeniden bakılmalı.
