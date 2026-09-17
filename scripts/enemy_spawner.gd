extends Node2D

## Full 15-Kademe (+ Final Kademe) creature roster, built from
## visuals/yaratıklar/. Every id here matches scenes/creatures/enemy_<id>.tscn.
const SCENES := {
	"rat1": preload("res://scenes/creatures/enemy_rat1.tscn"),
	"rat2": preload("res://scenes/creatures/enemy_rat2.tscn"),
	"rat3": preload("res://scenes/creatures/enemy_rat3.tscn"),
	"slime1": preload("res://scenes/creatures/enemy_slime1.tscn"),
	"slime2": preload("res://scenes/creatures/enemy_slime2.tscn"),
	"slime3": preload("res://scenes/creatures/enemy_slime3.tscn"),
	"slime4": preload("res://scenes/creatures/enemy_slime4.tscn"),
	"slime5": preload("res://scenes/creatures/enemy_slime5.tscn"),
	"slime6": preload("res://scenes/creatures/enemy_slime6.tscn"),
	"slime7": preload("res://scenes/creatures/enemy_slime7.tscn"),
	"iskelet1": preload("res://scenes/creatures/enemy_iskelet1.tscn"),
	"iskelet2": preload("res://scenes/creatures/enemy_iskelet2.tscn"),
	"iskelet3": preload("res://scenes/creatures/enemy_iskelet3.tscn"),
	"zombie1": preload("res://scenes/creatures/enemy_zombie1.tscn"),
	"zombie2": preload("res://scenes/creatures/enemy_zombie2.tscn"),
	"zombie3": preload("res://scenes/creatures/enemy_zombie3.tscn"),
	"lich1": preload("res://scenes/creatures/enemy_lich1.tscn"),
	"lich2": preload("res://scenes/creatures/enemy_lich2.tscn"),
	"lich3": preload("res://scenes/creatures/enemy_lich3.tscn"),
	"ork1": preload("res://scenes/creatures/enemy_ork1.tscn"),
	"ork2": preload("res://scenes/creatures/enemy_ork2.tscn"),
	"ork3": preload("res://scenes/creatures/enemy_ork3.tscn"),
	"agac1": preload("res://scenes/creatures/enemy_agac1.tscn"),
	"agac2": preload("res://scenes/creatures/enemy_agac2.tscn"),
	"agac3": preload("res://scenes/creatures/enemy_agac3.tscn"),
	"bitki1": preload("res://scenes/creatures/enemy_bitki1.tscn"),
	"bitki2": preload("res://scenes/creatures/enemy_bitki2.tscn"),
	"bitki3": preload("res://scenes/creatures/enemy_bitki3.tscn"),
	"golem1": preload("res://scenes/creatures/enemy_golem1.tscn"),
	"golem2": preload("res://scenes/creatures/enemy_golem2.tscn"),
	"golem3": preload("res://scenes/creatures/enemy_golem3.tscn"),
	"mantar1": preload("res://scenes/creatures/enemy_mantar1.tscn"),
	"mantar2": preload("res://scenes/creatures/enemy_mantar2.tscn"),
	"mantar3": preload("res://scenes/creatures/enemy_mantar3.tscn"),
	"demon1": preload("res://scenes/creatures/enemy_demon1.tscn"),
	"demon2": preload("res://scenes/creatures/enemy_demon2.tscn"),
	"demon3": preload("res://scenes/creatures/enemy_demon3.tscn"),
	"hayalet1": preload("res://scenes/creatures/enemy_hayalet1.tscn"),
	"hayalet2": preload("res://scenes/creatures/enemy_hayalet2.tscn"),
	"hayalet3": preload("res://scenes/creatures/enemy_hayalet3.tscn"),
	"rontgen1": preload("res://scenes/creatures/enemy_rontgen1.tscn"),
	"rontgen2": preload("res://scenes/creatures/enemy_rontgen2.tscn"),
	"rontgen3": preload("res://scenes/creatures/enemy_rontgen3.tscn"),
	"vampire1": preload("res://scenes/creatures/enemy_vampire1.tscn"),
	"vampire2": preload("res://scenes/creatures/enemy_vampire2.tscn"),
	"vampire3": preload("res://scenes/creatures/enemy_vampire3.tscn"),
	"iblis1": preload("res://scenes/creatures/enemy_iblis1.tscn"),
	"iblis2": preload("res://scenes/creatures/enemy_iblis2.tscn"),
	"iblis3": preload("res://scenes/creatures/enemy_iblis3.tscn"),
}

## hp/dmg multiplier per family, used only to compute a fresh, tier-appropriate
## stat block for Boss Kademe / Final Kademe spawns (see _spawn_boss_group) -
## completely independent of whatever regular-tier stats that same id's scene
## normally carries (enemy.gd's apply_boss_stats() overrides them outright).
const FAMILY_MULT := {
	"rat": {"hp": 0.5, "dmg": 0.6}, "slime": {"hp": 0.7, "dmg": 0.7},
	"iskelet": {"hp": 1.0, "dmg": 1.0}, "zombie": {"hp": 1.3, "dmg": 1.1},
	"ork": {"hp": 1.25, "dmg": 1.3}, "lich": {"hp": 1.1, "dmg": 1.1},
	"agac": {"hp": 1.8, "dmg": 1.4}, "bitki": {"hp": 1.2, "dmg": 1.0},
	"golem": {"hp": 2.3, "dmg": 1.6}, "mantar": {"hp": 1.3, "dmg": 1.1},
	"demon": {"hp": 1.6, "dmg": 1.3}, "hayalet": {"hp": 0.85, "dmg": 1.1},
	"rontgen": {"hp": 1.15, "dmg": 1.2}, "vampire": {"hp": 1.15, "dmg": 1.25},
	"iblis": {"hp": 0.8, "dmg": 1.0},
}

## Which family each id belongs to (for the FAMILY_MULT lookup above).
const ID_FAMILY := {
	"rat1": "rat", "rat2": "rat", "rat3": "rat",
	"slime1": "slime", "slime2": "slime", "slime3": "slime", "slime4": "slime",
	"slime5": "slime", "slime6": "slime", "slime7": "slime",
	"iskelet1": "iskelet", "iskelet2": "iskelet", "iskelet3": "iskelet",
	"zombie1": "zombie", "zombie2": "zombie", "zombie3": "zombie",
	"lich1": "lich", "lich2": "lich", "lich3": "lich",
	"ork1": "ork", "ork2": "ork", "ork3": "ork",
	"agac1": "agac", "agac2": "agac", "agac3": "agac",
	"bitki1": "bitki", "bitki2": "bitki", "bitki3": "bitki",
	"golem1": "golem", "golem2": "golem", "golem3": "golem",
	"mantar1": "mantar", "mantar2": "mantar", "mantar3": "mantar",
	"demon1": "demon", "demon2": "demon", "demon3": "demon",
	"hayalet1": "hayalet", "hayalet2": "hayalet", "hayalet3": "hayalet",
	"rontgen1": "rontgen", "rontgen2": "rontgen", "rontgen3": "rontgen",
	"vampire1": "vampire", "vampire2": "vampire", "vampire3": "vampire",
	"iblis1": "iblis", "iblis2": "iblis", "iblis3": "iblis",
}

## Regular spawn roster per Kademe (1-15) - NOT cumulative: only the current
## tier's own list spawns as "trash" enemies, matching the curated per-tier
## chapters the creature folders were organized into (Kademe 9 is an all-slime
## swarm, Kademe 10-12 is forest monsters, Kademe 13-15 is the undead/demon
## chapter, etc). Tier 1 = starting enemies, tier 15 = hardest regular tier.
const TIER_ROSTER := {
	1: ["rat1", "slime1"],
	2: ["rat1", "slime1", "iskelet1"],
	3: ["rat2", "zombie1", "iskelet1", "iskelet2"],
	4: ["rat2", "rat3", "zombie1", "zombie2", "iskelet2"],
	5: ["lich1", "zombie2", "zombie3", "iskelet1", "iskelet2"],
	6: ["ork1", "rat3", "zombie3", "iskelet2"],
	7: ["lich1", "lich2", "ork1", "ork2", "iskelet2"],
	8: ["lich2", "ork2", "ork3", "slime2", "iskelet3"],
	9: ["slime1", "slime2", "slime3", "slime4", "slime5", "slime6"],
	10: ["agac1", "bitki1", "golem1", "mantar1"],
	11: ["agac1", "agac2", "bitki1", "bitki2", "mantar2"],
	12: ["agac2", "bitki3", "golem2", "mantar2"],
	13: ["demon1", "hayalet1", "rontgen1", "vampire1", "iblis1"],
	14: ["demon1", "hayalet1", "hayalet2", "vampire1", "vampire2", "iblis1", "iblis2"],
	15: ["demon2", "hayalet3", "slime7", "vampire3", "iblis3"],
}

## Boss Kademe: one guaranteed tough spawn near the end of that tier's time
## window (see boss_trigger_fraction). Stats are computed from the tier
## number itself (e.g. İskelet 3's tier-3 boss uses tier=3, not its later
## regular appearance's P=8) so each boss is scaled to when it shows up.
const BOSS_TIERS := {
	3: ["iskelet3"],
	6: ["lich3"],
	8: ["ork3"],
	12: ["agac3", "golem3"],
	15: ["rontgen2", "rontgen3"],
}

## Final Kademe: every boss-tier creature spawns at once, all 13 together.
const FINAL_TIER := 16
const FINAL_CREATURES := [
	"agac3", "demon3", "golem3", "hayalet3", "lich3", "mantar3", "ork3",
	"rat3", "rontgen3", "vampire3", "zombie3", "iblis3", "iskelet3",
]

## Kademe atlama hızı %200 yavaşlatıldı (yani her kademe eskisinin 3 katı
## sürüyor, 50 -> 150) - oyun çok hızlı ilerleyip bosslar aniden geliyordu.
## Kullanıcı isteği (yeni tur): "yüksek kademelerin gelme hızı %50 artsın" -
## 150 -> 100 (süre /1.5, yani atlama hızı %50 arttı).
@export var tier_duration: float = 100.0 ## seconds spent in each Kademe
@export var boss_trigger_fraction: float = 0.75 ## how far into a tier its boss fires

## Regular spawn-rate pacing - unrelated to WHICH creature spawns (that's the
## tier roster above), just how often and how many can be alive at once.
## DÜZELTME (kullanıcı isteği: "yaratık spawnını %150 arttır") - base_interval/
## min_interval ÷2.5, max_concurrent_enemies/EXTRA_PLAYER_ENEMY_CAP ×2.5.
## DÜZELTME (kullanıcı bildirimi: "yaratık sayısını arttırdıktan sonra oyun
## çok kasmaya başladı") - kök neden: 158 eşzamanlı CharacterBody2D (her biri
## kendi AI/fizik/çarpışma işini yapan) + çok oyunculuda bunların HEPSİNİN
## her _broadcast_enemy_states_with_interest_management turunda taranması -
## hem CPU hem ağ tarafında gerçek bir maliyet.
## DÜZELTME (kullanıcı bildirimi: "%100'e düşürdükten sonra bile hala kasıyor,
## optimize edemez misin") - %150 VE %100 ikisi de kasıyordu ama GERÇEK kök
## neden bu iki sabit DEĞİLDİ: enemy.gd'deki yaratık-yaratık ayrışma hesabı
## O(n²) idi (bkz. o dosyadaki ENEMY_SEPARATION_GAP üstündeki DÜZELTME notu -
## artık ızgara/grid tabanlı, O(n)'e yakın). O kök neden düzeltildiği için
## spawn artışı kullanıcının ASIL istediği %150'ye (×2.5) geri getirildi -
## darboğaz sayının kendisi değil, algoritmaydı.
@export var base_interval: float = 0.6
@export var min_interval: float = 0.16
## DÜZELTME (kullanıcı bildirimi: "yaratıklar çok hızlı bir şekilde çoğalıyorlar
## ve aşırı fazla oluyorlar, biraz daha yavaş ilerlemesi gerek") - eskiden
## 0.006 ile spawn aralığı base_interval'den min_interval'e (0.6 -> 0.16)
## sadece ~73 saniyede (t * difficulty_ramp), yani tier_duration=100sn olan
## Kademe 1 BİLE bitmeden, iniyordu - maçın geri kalan ~24 dakikası boyunca
## zaten en yüksek yoğunlukta düz gidiyordu. Yarıya indirilince aynı tavana
## (0.16sn, hâlâ AYNI nihai zorluk) ~147 saniyede (Kademe 2 civarı) ulaşılıyor -
## erken oyun daha kademeli hissettiriyor, nihai zorluk değişmedi.
@export var difficulty_ramp: float = 0.003
## Kullanıcı isteği: "yaratık sayısını %50 arttır" - eskiden 42, ×1.5 (63).
## Kullanıcı isteği: "yaratık spawnını %150 arttır" - 63 -> 158 (×2.5).
## DÜZELTME (kullanıcı bildirimi: optimizasyonlar sonrası bile hâlâ kasıyor,
## "şimdilik spawn sınırını 90'a düşürelim") - 158 -> 90. Performans
## iyileşmeleri (bkz. enemy.gd ayrışma ızgarası/throttle/sqrt düzeltmeleri)
## kalıcı ve gerçek (Profiler: kare süresi 39.52ms -> 18.38ms'e indi), ama
## yine de yeterli hissettirmedi - kullanıcı daha fazla algoritma ayarı
## yerine tavanı doğrudan düşürmeyi tercih etti.
## SONRAKİ TUR (kullanıcı isteği: "maksimum yaratık spawnını 150 yap tekrar
## bişey denicem") - performans düzeltmeleri kalıcı olduğu için (yukarıdaki
## not) tavan tekrar denemek amacıyla 90 -> 150 yükseltildi. EXTRA_PLAYER_
## ENEMY_CAP (aşağısı) BİLEREK dokunulmadı - sadece bu tek sayı istendi.
## SONRAKİ TUR (kullanıcı isteği: "maksimum yaratık sayısını 80'e düşür") -
## 150 -> 80. EXTRA_PLAYER_ENEMY_CAP yine BİLEREK dokunulmadı - sadece bu
## tek sayı istendi.
@export var max_concurrent_enemies: int = 80
## Multiplayer enemy scaling: solo keeps the original cap; each additional
## player adds room for more creatures and slightly increases spawn frequency.
## Kullanıcı isteği: "oyuncu başına yaratık sayısı %50 [artsın]" - eskiden 18, ×1.5 (27).
## Kullanıcı isteği: "yaratık spawnını %150 arttır" - 27 -> 68 (×2.5).
## DÜZELTME (kullanıcı isteği: "spawn sınırını 90'a düşürelim") - 68 -> 39,
## max_concurrent_enemies ile AYNI oranda (158->90, ~×0.57) küçültüldü.
const EXTRA_PLAYER_ENEMY_CAP := 39
const EXTRA_PLAYER_SPAWN_RATE := 0.25
@export var min_spawn_distance: float = 480.0
@export var max_spawn_distance: float = 640.0

## Kullanıcı isteği: "yaratıklar rasgele yönlerden rasgele sürelerde
## spawnlansın, özellikle karakterlerin gittiği yönlerde karakterin yolunu
## kesecek şekilde spawnlanmalar olmalı ekranın dışından" - min/max_spawn_
## distance zaten ekranın dışında kalacak kadar büyük (bkz. kamera zoom'u),
## bu yüzden "ekranın dışından" kısmı zaten sağlanıyordu; eksik olan
## "oyuncunun gittiği yöne doğru" kısmıydı - bkz. _anchor_movement_direction/
## _random_spawn_position'daki bias_dir parametresi.
const DIRECTIONAL_SPAWN_CHANCE := 0.6 ## bu olasılıkla dar bir açıda ÖNDEN, kalanı eskisi gibi tam rastgele 360°
const DIRECTIONAL_SPAWN_ARC_DEG := 100.0 ## yön-yanlı spawn'ın merkez yönün etrafında kaç derecelik bir yelpazeye yayılabileceği

## Kullanıcı isteği: "karakter çok güçlüyse normalden daha fazla
## spawnlansın" - takım seviyesi o anki Kademe için "beklenenden" epey
## yüksekse (oyuncular zorluğa göre fazlasıyla güçlenmiş demektir) her
## tetiklenişte normal TEK yaratığın yanına ekstra yaratıklar da eklenir.
const POWER_LEVEL_PER_TIER := 2.5 ## bu Kademe'de "normal" sayılan kabaca takım seviyesi
const POWER_EXTRA_SPAWN_PER_LEVELS_OVER := 4.0 ## beklenenin kaç seviye üstünde her ekstra yaratık gelir
const POWER_MAX_EXTRA_SPAWNS := 4 ## tek tetiklenişte eklenebilecek en fazla ekstra yaratık

## DÜZELTME (kullanıcı isteği: "bosslar fazla güçsüz ve öldürmek ödüllendirici
## değil, statları artmalı") - hem can hem hasar belirgin şekilde arttırıldı
## (hasar önceki turda "tek vuruşta öldürme hissini azaltmak" için 2.4'ten
## 1.8'e düşürülmüştü, şimdi eskisinden de güçlü bir değere çıkarıldı).
## Kullanıcı isteği: "bossların dayanıklılığını %300 arttır (zırh/can/kalkan)"
## - can için BOSS_HEALTH_MULT ×4 (eskiden 11.0), zırh için aşağıdaki
## BOSS_ARMOR_BASE/PER_TIER ×4, kalkan için BOSS_SHIELD_RATIO ×4. Hasara
## (BOSS_DAMAGE_MULT) dokunulmadı, istek sadece dayanıklılıkla ilgiliydi.
## Kullanıcı isteği (İKİNCİ tur): "Bossların canını %100 arttır ve kalkan
## soğurmasını %90 düzeyine getir." - bir önceki turun ("can %100 ve kalkan
## %200 artış, soğurma %85'e sabitleme") ÜSTÜNE, yeniden:
## - BOSS_HEALTH_MULT 88.0 -> 176.0 (yine tam %100 artış, bu turun canı bir
##   önceki turun canının iki katı).
## - BOSS_SHIELD_PROTECTION 0.85 -> 0.90 (bu tur SADECE soğurma oranıyla
##   ilgili - kalkan HAVUZU/BOSS_SHIELD_RATIO'ya dokunulmadı, önceki turdan
##   kalan miktar aynen korunuyor).
## Kullanıcı isteği (ÜÇÜNCÜ tur): "bossların kalkanı %20 canı da %10
## azalsın" - BOSS_HEALTH_MULT 176.0 -> 158.4 (×0.9), BOSS_SHIELD_RATIO
## (aşağıda) 7.8 -> 6.24 (×0.8). İki değer BİRBİRİNDEN BAĞIMSIZ ayrı ayrı
## yüzdeyle çarpıldı (kalkan havuzu = max_health × ratio olduğu için, bkz.
## enemy.gd enable_item_shield, ikisini ÜST ÜSTE bindirmek 2. turun istediği
## %20'den daha fazla bir kalkan düşüşüne yol açardı).
const BOSS_HEALTH_MULT := 158.4 ## eskiden 176.0 (kullanıcı isteği: can %10 azalt)
const BOSS_DAMAGE_MULT := 2.4 ## eskiden 1.8
const BOSS_SCALE_MULT := 1.7

## Item shield (see enemy.gd's enable_item_shield): kullanıcı isteği -
## "yaratıkların kalkan miktarı can miktarlarından daha fazla olmalı ve
## kalkanları onların aldığı hasarı %40 azaltmalı SADECE" - hem normal hem
## boss yaratıklarda emilim oranı artık SABİT %40 (eskiden normal %50,
## boss %70 idi), ve kalkan havuzu artık max_health'ten BÜYÜK (ratio > 1.0,
## eskiden ikisi de 1.0'ın altındaydı) - shield_ratio, (tier/boss'a göre
## zaten ölçeklenmiş) max_health'in bir katsayısı.
##
## Kullanıcı isteğiyle (yeni tur): "yaratıklar aşırı dayanıklı, öldürmek çok
## zor" - kalkanın hem emilim oranı hem havuz büyüklüğü biraz aşağı çekildi
## (kalkan hâlâ var ve hâlâ candan büyük, ama eskisi kadar "ekstra can
## katmanı" hissi vermiyor).
const REGULAR_SHIELD_MIN_TIER := 3
const SHIELD_PROTECTION := 0.3 ## eskiden 0.4 - normal yaratıklarda sabit %30 hasar azaltımı
## DÜZELTME (kullanıcı isteği: "bossların kalkanlarının hasar soğurmasını
## %70'e yükselt") - bosslar bir süredir normal yaratıklarla AYNI SHIELD_
## PROTECTION'ı (bkz. yukarıdaki yorum geçmişi - eskiden bosslarda zaten
## %70'ti, sonra %30'a birleştirilmişti) kullanıyordu. Artık tekrar ayrı,
## boss'a özel bir emilim oranı var.
## Kullanıcı isteği (İKİNCİ tur): "kalkan soğurmasını %90 düzeyine getir." -
## eskiden %85'ti (bkz. yukarıdaki geçmiş notlar), artık boss kalkanı her
## vuruşun %90'ını emiyor. NORMAL yaratıkların oranı (SHIELD_PROTECTION)
## BİLEREK değiştirilmedi - istek sadece bosslarla ilgili.
## NOT: emilim oranı yükseldikçe kalkan havuzu DAHA ÇABUK tükenir (her vuruşun
## daha büyük kısmı kalkandan gider) ama can o oranda daha az hasar alır;
## bu yüzden oranla birlikte BOSS_SHIELD_RATIO da yeterince büyük olmalı -
## yoksa boss, kalkanı bitmeden canı biter ve kalkan boşa gider.
const BOSS_SHIELD_PROTECTION := 0.90
const REGULAR_SHIELD_RATIO := 1.15 ## eskiden 1.3 - kalkan canından %15 daha fazla
const BOSS_SHIELD_RATIO := 1.3 ## kullanıcı isteği: "bossların kalkanlarını canlarından %30 daha fazla olacak şekilde dengele" - shield = health * 1.3 (eskiden 6.24, ~6.2x can)

## Tüm düşmanlara uygulanan global güçlendirme çarpanı - kullanıcı isteğiyle
## ("hasarlarının artışını azaltıp dayanıklılıklarını arttıralım") artık
## SAVUNMA (can/kalkan) ve HASAR için AYRI çarpanlar var, tek bir ortak
## çarpan değil. Savunma daha güçlü büyüyor, hasar çok daha yavaş büyüyor.
##
## Kullanıcı isteğiyle (yeni tur): "yaratıklar çok hızlı güçlenip zorlaşıyor
## ve aşırı dayanıklılar öldürmek çok zorlaşıyor" - önceki tur savunmayı
## fazla arttırmış, GLOBAL_DEFENSE_BUFF aşağı çekildi. Hasar çarpanına
## dokunulmadı (bu turun şikayeti hasar değil, dayanıklılık/öldürme süresi).
const GLOBAL_DEFENSE_BUFF := 1.2 ## eskiden 1.45 - can, kalkan için
## Kullanıcı isteği: "yaratıkların can/kalkan oranı %20 artsın" - sadece
## can/kalkan miktarını etkileyen ayrı bir çarpan.
## DÜZELTME (kullanıcı isteği: "yaratıkların canını ve kalkanını %100
## arttır") - 1.2 -> 2.4 (bu tek çarpan GLOBAL_DEFENSE_BUFF ile birlikte
## can/kalkana uygulandığı için, kendisini 2 katına çıkarmak toplam can/
## kalkan çıktısını da tam 2 katına çıkarıyor).
## DÜZELTME (kullanıcı isteği: "tüm yaratıkların canlarını ve kalkanlarını
## %10 arttır") - 2.4 -> 2.64 (×1.1). Bu çarpan boss'lara da _apply_global_
## buff üzerinden uygulandığı için (bkz. o fonksiyon), "tüm" isteği hem
## normal hem boss yaratıkları kapsıyor.
const HEALTH_SHIELD_MULT := 2.64
## DÜZELTME (kullanıcı isteği: "yaratıkların hasarını %60 arttır") - 1.05 ->
## 1.68 (1.05 * 1.6).
const GLOBAL_DAMAGE_BUFF := 1.68 ## sadece hasar için (eskiden ortak 1.3)

## Kullanıcı isteği (#26): "yaratıklardan çok az altın düşüyor, altın düşme
## oranını arttır." Her yaratık sahnesinin (scenes/creatures/enemy_*.tscn)
## KENDİ gold_chance/gold_min/gold_max @export değeri var (49 ayrı dosya) -
## her birini tek tek düzenlemek yerine, zaten TÜM yaratıklara tier scaling
## SONRASI uygulanan _apply_global_buff() burada da tek bir global çarpan
## ekliyor, aynı GLOBAL_DEFENSE_BUFF/GLOBAL_DAMAGE_BUFF desenindeki gibi.
## Kullanıcı isteği (yeni tur): "altın düşürme şansını %50 azalt" - bir
## önceki turda ~%80 arttırılmıştı (1.8), şimdi o çarpanın YARISINA (0.9)
## çekildi; sonuç olarak bugünkü fiili düşme şansı tam olarak %50 azalmış
## oluyor (miktar çarpanına dokunulmadı).
const GOLD_DROP_CHANCE_MULT := 0.9 ## altın düşürme İHTİMALİNİ %50 azalt (eskiden 1.8)
const GOLD_DROP_AMOUNT_MULT := 1.5 ## düşen altın MİKTARINI ~%50 arttır

var _spawn_timer: float = 0.0
var _network_sync_timer: float = 0.0
var _next_network_enemy_id: int = 1
var _boss_tiers_spawned: Dictionary = {}
var _final_spawned: bool = false

## Kullanıcı isteği: "en yaygın/en sağlıklı ne ise onu yap" - gerçek zamanlı
## çok oyunculu oyunların standart tekniği "ilgi alanı" (area of interest):
## bir oyuncuya sadece YAKININDAKİ varlıkların tam durumu gönderilir, haritanın
## öbür ucundaki bir yaratık her karede aynı ayrıntıyla herkese YAYINLANMAZ.
## Eskiden TEK bir enemy_states paketi TÜM yaratıkları içerip TEK bir
## .rpc() ile HERKESE broadcast ediliyordu - relay'in bağlantı BAŞINA byte
## bütçesi tam olarak burada zorlanıyordu (bkz. network_manager.gd dosya başı
## notu). Artık host, HER katılımcı için AYRI bir paket hazırlıyor: o
## katılımcının oyuncusuna YAKIN yaratıklar HER tikte, UZAK yaratıklar ise
## çok daha SEYREK (ENEMY_SYNC_FAR_TIER_SKIP tikte bir) gönderiliyor - uzaktaki
## bir yaratığın konumu zaten o oyuncunun ekranında görünmüyor, sık senkronize
## etmeye gerek yok. GÜVENLİK: bir yaratık TAM BU TİKTE öldüyse, mesafeden
## bağımsız HER ZAMAN dahil edilir - yoksa uzaktaki bir yaratık öldüğünü hiç
## öğrenmeyip ekranda "hayalet" gibi donuk kalabilirdi (bkz. _last_dead_sent).
const ENEMY_SYNC_NEAR_RADIUS := 1600.0
const ENEMY_SYNC_NEAR_RADIUS_SQ := ENEMY_SYNC_NEAR_RADIUS * ENEMY_SYNC_NEAR_RADIUS
const ENEMY_SYNC_FAR_TIER_SKIP := 4 ## uzak yaratıklar ~4 tikte bir (≈0.6sn)
var _far_tier_tick: int = 0
var _last_dead_sent: Dictionary = {} ## network_enemy_id -> bool


func _ready() -> void:
	NetworkManager.became_host.connect(_on_became_host)
	NetworkManager.peer_needs_game_catchup.connect(_on_peer_needs_game_catchup)


## Kullanıcı isteği: "oyundan çıkmış biri ... oyundaki son haliyle oyuna
## katılmalı" - host, hâlâ hayatta olan TÜM yaratıkları (_rpc_client_spawn_
## creature ile - normal spawn broadcast'iyle AYNI fonksiyon, sadece burada
## SADECE geç katılan bu peer'e hedefli) yeniden "doğuruyor" ki o oyuncu
## boş bir savaş alanı görmesin. Can/kalkan oranı ilk anda tam olmayabilir
## (apply_boss_stats/apply_tier_scaling tazeden hesaplar) ama bir sonraki
## _sync_enemy_positions turunda (≤0.2sn) gerçek değerlere düzelir.
func _on_peer_needs_game_catchup(peer_id: int) -> void:
	if not NetworkManager.is_host:
		return
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var net_id: int = int(enemy.get_meta("network_enemy_id", 0))
		var creature_id: String = str(enemy.get_meta("creature_id", ""))
		if net_id <= 0 or creature_id == "":
			continue
		var is_boss_enemy: bool = enemy.is_in_group("boss")
		var enemy_tier: int = int(enemy.get("_current_tier")) if "_current_tier" in enemy else 1
		_rpc_client_spawn_creature.rpc_id(peer_id, creature_id, enemy.global_position, enemy_tier, is_boss_enemy, net_id)


## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu - host migrasyonu):
## eski host ayrılıp bu peer host olduğunda _next_network_enemy_id/
## _boss_tiers_spawned/_final_spawned hâlâ İLK değerlerindeydi (bu instance
## şimdiye kadar hiç host olmadığı için _process()'teki "sadece host"
## kapısından hiç geçmemişti) - bu da (a) zaten geçmişte kalmış boss/final
## Kademelerin sahnedeki mevcut bosslarla ÇAKIŞARAK yeniden doğmasına ve
## (b) yeni doğan düşmanların network_enemy_id'sinin hâlâ hayattaki eski
## düşmanlarla çakışıp request_enemy_damage/_sync_enemy_positions'ın yanlış
## düşmanı hedeflemesine yol açıyordu. Artık host olunca sayaçlar sahnenin
## GÜNCEL durumundan (hayattaki düşmanlar + geçen oyun süresi) yeniden
## tohumlanıyor.
func _on_became_host() -> void:
	var max_enemy_id: int = 0
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_meta("network_enemy_id"):
			max_enemy_id = max(max_enemy_id, int(enemy.get_meta("network_enemy_id")))
	_next_network_enemy_id = max_enemy_id + 1

	## Tetiklenme zamanı zaten geride kalmış boss/final Kademeleri "doğdu" say
	## - aksi halde hepsi art arda (ve muhtemelen hâlâ hayatta olan bosslarla
	## çakışarak) yeniden doğardı. Zamanı henüz gelmemiş olanlara dokunulmuyor,
	## normal akışta kendi zamanında doğarlar.
	var t: float = GameManager.game_time
	for tier in BOSS_TIERS.keys():
		var trigger_time: float = (tier - 1) * tier_duration + tier_duration * boss_trigger_fraction
		if t >= trigger_time:
			_boss_tiers_spawned[tier] = true
	var final_trigger_time: float = (FINAL_TIER - 1) * tier_duration
	if t >= final_trigger_time:
		_final_spawned = true


func _process(delta: float) -> void:
	## PERF DÜZELTMESİ (bkz. enemy.gd _queue_drop_spawn/drain_drop_spawn_queue
	## üstündeki DÜZELTME notu): ölüm-kaynaklı drop spawn kuyruğu burada,
	## enemy_spawner.gd'nin _process'inde boşaltılıyor - aşağıdaki erken
	## return'lerden (game_over/indoor/host) ÖNCE, çünkü bu node (Enemy'nin
	## aksine) sahnede hep var; son yaratık ölse ya da tüm oyuncular eve
	## girse bile kuyruk burada tıkanmadan boşalmaya devam eder.
	Enemy.drain_drop_spawn_queue()

	if GameManager.is_game_over:
		return

	## Kullanıcı isteği: "içerideyken yaratıklar içeri saldıramamalı" - enemy.gd
	## zaten ev içindeki oyuncuyu hiç hedeflemiyor, ama burada spawn'ın da
	## durdurulması gerekiyor: yeni yaratıklar canlı bir oyuncunun GÜNCEL
	## konumuna göre (bkz. _find_any_living_player_position) belirir - eğer
	## TÜM canlı oyuncular ev içindeyse (dışarıda kimse yoksa) spawn tamamen
	## duruyor; ama çok oyunculuda başka bir oyuncu hâlâ dışarıdaysa onun
	## için spawn NORMAL devam ediyor (bkz. _any_living_player_outdoors).
	if not _any_living_player_outdoors():
		return

	# In multiplayer, only the host manages enemy spawning and triggers
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return

	if NetworkManager.is_multiplayer_active:
		_network_sync_timer += delta
		## Relay her bağlantıya saniyelik mesaj/byte bütçesi uyguluyor ve bunu
		## aşan "sel" durumunda bağlantıyı KAPATIYOR (bkz. NetworkManager.gd
		## dosya başı notu). Çok sayıda düşman varken (yoğun aksiyon) bu tek
		## paket zaten büyük olduğu için eskiden 0.10sn'de bir (10/sn)
		## gönderiliyordu - 0.15sn'ye (~6.7/sn) çekilerek bant genişliği
		## kullanımı azaltıldı, pozisyon senkronizasyonu hâlâ akıcı kalır.
		if _network_sync_timer >= 0.15:
			_network_sync_timer = 0.0
			_far_tier_tick += 1
			_broadcast_enemy_states_with_interest_management()
			# Sync game time so clients use the same difficulty scaling as host.
			NetworkManager.sync_game_time.rpc(GameManager.game_time)

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _current_interval()
		_spawn_regular_enemy()

	_check_boss_tiers()
	_check_final_tier()


## Her gerçek uzak katılımcı için AYRI bir yaratık-durumu paketi hazırlar
## (bkz. yukarıdaki "ilgi alanı" notu). Host'un KENDİSİ için hiçbir şey
## göndermez - host'un kendi yaratık node'ları zaten yetkili/gerçek veri.
func _broadcast_enemy_states_with_interest_management() -> void:
	var all_enemies: Array = []
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_meta("network_enemy_id"):
			all_enemies.append(enemy)
	if all_enemies.is_empty():
		return

	var main_node: Node = get_tree().current_scene
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var is_far_tick: bool = (_far_tier_tick % ENEMY_SYNC_FAR_TIER_SKIP) == 0

	for pid in NetworkManager.lobby_players.keys():
		var peer_id: int = int(pid)
		if peer_id == local_id or peer_id <= 0:
			continue
		var target_pos: Vector2 = Vector2.ZERO
		var has_target_pos: bool = false
		if main_node and main_node.has_method("_get_remote_player"):
			var rp: Node = main_node._get_remote_player(peer_id)
			if rp and is_instance_valid(rp):
				target_pos = rp.global_position
				has_target_pos = true

		var states: Array = []
		for enemy in all_enemies:
			var net_id: int = int(enemy.get_meta("network_enemy_id"))
			var is_dead_now: bool = enemy.get("is_dead") == true
			## Bu tikte YENİ ölmüşse (bkz. _last_dead_sent) mesafeden bağımsız
			## HER ZAMAN dahil et - "hayalet yaratık" riskini tamamen kapatır.
			var just_died: bool = is_dead_now and not _last_dead_sent.get(net_id, false)
			if has_target_pos and not just_died:
				var dist_sq: float = enemy.global_position.distance_squared_to(target_pos)
				var is_near: bool = dist_sq <= ENEMY_SYNC_NEAR_RADIUS_SQ
				if not is_near and not is_far_tick:
					continue
			states.append([
				net_id,
				enemy.global_position,
				is_dead_now,
				enemy.get("health"),
				enemy.get("item_shield_hp"),
				enemy.get("is_raging") == true,
				int(enemy.get("chill_stacks") if "chill_stacks" in enemy else 0),
				## Korsan'ın öldürme-özel altın pasifi (bkz. enemy.gd
				## last_attacker_peer_id) host olmayan istemcilere de ulaşsın diye.
				int(enemy.get("last_attacker_peer_id") if "last_attacker_peer_id" in enemy else 0)
			])
		if not states.is_empty():
			_sync_enemy_positions.rpc_id(peer_id, states)

	## BAKIM (kullanıcı bildirimi: "oyun ~4-5 dakikada bir donuyor" araştırması
	## sırasında fark edildi - kesin donma nedeni DEĞİL, ama bir sızıntıydı):
	## bir düşman queue_free() ile sahneden tamamen kalkınca "enemies"
	## grubundan da düşer ve bir daha ASLA bu döngüye girmez, yani
	## _last_dead_sent'teki kaydı SONSUZA KADAR orada kalırdı - uzun bir
	## oturumda (özellikle yüksek düşman sayımı olan geç oyun) yavaşça
	## büyüyen, hiç temizlenmeyen bir sözlük. Artık her yayın turunda SADECE
	## halen var olan düşmanların kayıtları tutulup geri kalanı atılıyor.
	var _next_last_dead_sent: Dictionary = {}
	for enemy in all_enemies:
		var net_id: int = int(enemy.get_meta("network_enemy_id"))
		_next_last_dead_sent[net_id] = enemy.get("is_dead") == true
	_last_dead_sent = _next_last_dead_sent


## Which Kademe (1-15) the run is currently in, based on elapsed game_time.
## Clamped at 15 so TIER_ROSTER lookups stay valid even once the Final Kademe
## has been reached (tier 15's roster keeps providing "trash" spawns
## alongside the one-time Final Kademe boss dump).
func _current_tier() -> int:
	var t: float = GameManager.game_time
	var tier: int = 1 + int(t / tier_duration)
	return clamp(tier, 1, 15)


func _player_count() -> int:
	if not NetworkManager.is_multiplayer_active:
		return 1
	return max(1, NetworkManager.lobby_players.size())


## DÜZELTME (kullanıcı bildirimi: "Yaratıklar ilk tierlarda çok gereksiz
## kalabalık geliyor kalabalıklaşma olayı ilerleyen tierlarda artsın") - eski
## tavan (max_concurrent_enemies + oyuncu başı ekstra) Kademe 1'den itibaren
## SABİTTİ, yani ilk dakikalarda bile ekran 150 yaratığa kadar dolabiliyordu.
## Artık bu tavan Kademe 1'de TIER_1_CAP_SCALE oranına sıkışıyor ve Kademe
## 15'e kadar doğrusal olarak tam tavana çıkıyor - kalabalıklaşma artık
## erken değil, geç oyunda hissediliyor.
const TIER_1_CAP_SCALE := 0.35

func _tier_crowding_scale() -> float:
	var tier: int = _current_tier()
	return lerp(TIER_1_CAP_SCALE, 1.0, float(tier - 1) / 14.0)

func _scaled_enemy_cap() -> int:
	var base_cap: int = max_concurrent_enemies + (_player_count() - 1) * EXTRA_PLAYER_ENEMY_CAP
	return max(1, int(round(base_cap * _tier_crowding_scale())))


func _current_interval() -> float:
	var t: float = GameManager.game_time
	var solo_interval: float = max(min_interval, base_interval - t * difficulty_ramp)
	var player_multiplier: float = 1.0 + float(_player_count() - 1) * EXTRA_PLAYER_SPAWN_RATE
	return max(min_interval * 0.65, solo_interval / player_multiplier)


## DÜZELTME (KRİTİK - kullanıcı bildirimi #30: "bir süre sonra yaratıklar
## spawnlanmamaya başlıyor... fakat bir oyuncu çıkınca oyun devam etmeye
## başlıyor"): _spawn_regular_enemy()/_spawn_boss_group() eskiden SADECE
## get_first_node_in_group("player") (HOST'un KENDİ karakteri) sağ mı diye
## bakıyordu. Host öldüğünde ve revive hakkı kalmadığında o node birkaç
## saniye sonra queue_free() ile TAMAMEN kalkıyor (bkz. player.gd die()) -
## diğer TÜM oyuncular hâlâ hayattayken bile spawn SONSUZA KADAR duruyordu.
## "Bir oyuncu çıkınca düzeliyor" ipucu tam olarak host göçüyle açıklanıyor
## (bkz. network_manager.gd _on_peer_disconnected -> _refresh_host): yeni
## host'un KENDİ karakteri hayattaysa spawn o anda "tesadüfen" yeniden
## başlıyordu. Artık host'un kendi karakteri ölüyse hayattaki herhangi bir
## UZAK oyuncunun konumu kullanılıyor - TÜM oyuncular ölmeden (o durumda
## zaten is_game_over/_process en başta devreye girip return eder) spawn
## asla durmuyor.
## Kullanıcı isteği: "içerideyken yaratıklar içeri saldıramamalı" - ev
## içindeki (bkz. player.gd is_indoors/house_interior.gd) bir oyuncu bu
## kontrol için "dışarıda" sayılmaz, spawn onun için tetiklenmemeli. Çok
## oyunculuda başka bir oyuncu hâlâ dışarıdaysa spawn onun için normal
## devam etsin diye TÜM canlı oyuncular (yerel + uzak) taranıyor.
## DÜZELTME: seyyar satıcının güvenli bölgesindeki (bkz. GameManager.
## merchant_zone_active, player.gd is_in_merchant_zone) bir oyuncu da is_
## indoors ile AYNI şekilde "dışarıda" sayılmaz - kullanıcı isteği: "yeni
## yaratıklar spawn olmaz" (oyuncular bölgedeyken).
func _any_living_player_outdoors() -> bool:
	var local_p: Node = get_tree().get_first_node_in_group("player")
	if local_p and is_instance_valid(local_p) and local_p.get("is_dead") != true:
		var local_indoors: bool = local_p.has_method("is_indoors_now") and local_p.is_indoors_now()
		var local_in_merchant_zone: bool = local_p.has_method("is_in_merchant_zone_now") and local_p.is_in_merchant_zone_now()
		if not local_indoors and not local_in_merchant_zone:
			return true
	if NetworkManager.is_multiplayer_active:
		for rp: Node in get_tree().get_nodes_in_group("remote_players"):
			if not is_instance_valid(rp) or rp.get("is_dead") == true:
				continue
			var rp_indoors: bool = rp.get("is_indoors") if "is_indoors" in rp else false
			var rp_in_merchant_zone: bool = rp.get("is_in_merchant_zone") if "is_in_merchant_zone" in rp else false
			if not rp_indoors and not rp_in_merchant_zone:
				return true
	return false


## BUG DÜZELTMESİ (kullanıcı bildirimi: "evin içine girince yaratıklar
## görünmeye devam ediyor ve diğer oyunculada yaratıklar spawnlanmamaya
## başlıyor") - kök neden: bu fonksiyon _any_living_player_outdoors() ile
## AYNI "içerideki oyuncu dışarıda sayılmaz" kuralını uygulamıyordu; host
## eve girince (bkz. house_interior.gd - haritanın çok uzağına, ~(20000,0)
## ofsetine ışınlanıyor) spawn konumu olarak HÂLÂ host'un (artık ev içi)
## konumu dönüyordu, bu yüzden yeni yaratıklar hâlâ dışarıda olan diğer
## oyunculardan mil ötede doğuyordu - onlara göre "spawn durdu" gibi
## görünüyordu. Artık ÖNCELİK dışarıdaki canlı bir oyuncuda (önce yerel,
## sonra uzak); kimse dışarıda değilse (normal şartlarda buraya hiç
## gelinmez, bkz. çağıran taraftaki _any_living_player_outdoors kontrolü)
## son çare olarak herhangi bir canlı oyuncu kullanılıyor.
## bkz. _any_living_player_outdoors üstündeki AYNI seyyar satıcı notu -
## bölgedeki bir oyuncunun konumu da "dışarıda" adayı olarak seçilmemeli.
## DÜZELTME (kod tekrarını önlemek için, bkz. CLAUDE.md "iki ayrı yer"
## uyarısı): eskiden _find_any_living_player_position SADECE konum
## döndürüyordu; yön-yanlı spawn (bkz. _anchor_movement_direction) için
## AYNI "hangi oyuncu/uzak oyuncu çapa olacak" öncelik sırasını İKİNCİ bir
## yerde tekrar yazmak yerine, bu öncelik mantığı TEK bir yerde (burada)
## yaşıyor ve NODE'UN KENDİSİNİ döndürüyor - konum de yön de aynı seçimden
## türüyor.
func _find_any_living_player_anchor() -> Node:
	var local_p: Node = get_tree().get_first_node_in_group("player")
	var local_alive: bool = local_p and is_instance_valid(local_p) and local_p.get("is_dead") != true
	var local_indoors: bool = local_alive and local_p.has_method("is_indoors_now") and local_p.is_indoors_now()
	var local_in_merchant_zone: bool = local_alive and local_p.has_method("is_in_merchant_zone_now") and local_p.is_in_merchant_zone_now()
	if local_alive and not local_indoors and not local_in_merchant_zone:
		return local_p
	var fallback: Node = null
	if NetworkManager.is_multiplayer_active:
		for rp: Node in get_tree().get_nodes_in_group("remote_players"):
			if not is_instance_valid(rp) or rp.get("is_dead") == true:
				continue
			var rp_indoors: bool = rp.get("is_indoors") if "is_indoors" in rp else false
			var rp_in_merchant_zone: bool = rp.get("is_in_merchant_zone") if "is_in_merchant_zone" in rp else false
			if not rp_indoors and not rp_in_merchant_zone:
				return rp
			if fallback == null:
				fallback = rp
	if local_alive:
		return local_p
	return fallback


func _find_any_living_player_position():
	var anchor: Node = _find_any_living_player_anchor()
	return anchor.global_position if anchor and is_instance_valid(anchor) else null


## Seçilen çapa oyuncunun/uzak oyuncunun O ANKİ hareket yönü - bkz.
## _spawn_regular_enemy'deki yön-yanlı spawn (kullanıcı isteği: "özellikle
## karakterlerin gittiği yönlerde karakterin yolunu kesecek şekilde
## spawnlanmalar olmalı"). Yerel oyuncu için gerçek CharacterBody2D.velocity;
## uzak oyuncu için _network_velocity (bkz. remote_player.gd - onun konumu
## move_and_slide DEĞİL dead-reckoning ile sürüklendiği için kendi built-in
## velocity'si hep sıfır kalır, _network_velocity gerçek hareketi yansıtan
## tek alan). Oyuncu duruyorsa Vector2.ZERO döner - çağıran taraf bunu "yön
## yanlılığı YOK, tam rastgele" olarak yorumlar.
func _anchor_movement_direction(anchor: Node) -> Vector2:
	if not anchor or not is_instance_valid(anchor):
		return Vector2.ZERO
	var v: Vector2 = Vector2.ZERO
	if "_network_velocity" in anchor:
		v = anchor._network_velocity
	elif "velocity" in anchor:
		v = anchor.velocity
	if v.length() > 5.0:
		return v.normalized()
	return Vector2.ZERO


## bkz. POWER_LEVEL_PER_TIER üstündeki not - takım o anki Kademe için
## "beklenenden" ne kadar yüksek seviyedeyse o kadar ekstra yaratık.
func _power_extra_spawn_count() -> int:
	var expected_level: float = float(_current_tier()) * POWER_LEVEL_PER_TIER
	var levels_over: float = float(GameManager.team_level) - expected_level
	if levels_over <= 0.0:
		return 0
	return clampi(int(levels_over / POWER_EXTRA_SPAWN_PER_LEVELS_OVER), 0, POWER_MAX_EXTRA_SPAWNS)


func _spawn_regular_enemy() -> void:
	var anchor: Node = _find_any_living_player_anchor()
	if not anchor:
		return
	var anchor_pos: Vector2 = anchor.global_position
	var bias_dir: Vector2 = _anchor_movement_direction(anchor)

	var tier: int = _current_tier()
	var roster: Array = TIER_ROSTER.get(tier, [])
	if roster.is_empty():
		return
	## kullanıcı isteği: "karakter çok güçlüyse normalden daha fazla
	## spawnlansın" - bkz. _power_extra_spawn_count üstündeki not.
	var spawn_count: int = 1 + _power_extra_spawn_count()
	for i in range(spawn_count):
		if get_tree().get_nodes_in_group("enemies").size() >= _scaled_enemy_cap():
			return
		var id: String = roster[randi() % roster.size()]
		var spawn_pos: Vector2 = _random_spawn_position(anchor_pos, false, bias_dir)
		var network_id: int = _next_network_enemy_id
		_next_network_enemy_id += 1
		var enemy = _spawn_creature(id, spawn_pos, network_id)
		if not enemy:
			continue
		if enemy.has_method("apply_tier_scaling"):
			enemy.apply_tier_scaling(tier)
		if tier >= REGULAR_SHIELD_MIN_TIER and enemy.has_method("enable_item_shield"):
			enemy.enable_item_shield(SHIELD_PROTECTION, REGULAR_SHIELD_RATIO)
		# Global güçlendirme - tier scaling SONRASI uygulanır (zaten ölçeklenmiş
		# değerlerin üstüne eklenir, katlanarak büyümez)
		_apply_global_buff(enemy)

		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			_rpc_client_spawn_creature.rpc(id, spawn_pos, tier, false, network_id)



func _check_boss_tiers() -> void:
	var t: float = GameManager.game_time
	for tier in BOSS_TIERS.keys():
		if _boss_tiers_spawned.has(tier):
			continue
		var trigger_time: float = (tier - 1) * tier_duration + tier_duration * boss_trigger_fraction
		if t >= trigger_time:
			_boss_tiers_spawned[tier] = true
			_spawn_boss_group(BOSS_TIERS[tier], tier)


func _check_final_tier() -> void:
	if _final_spawned:
		return
	var trigger_time: float = (FINAL_TIER - 1) * tier_duration
	if GameManager.game_time >= trigger_time:
		_final_spawned = true
		_spawn_boss_group(FINAL_CREATURES, FINAL_TIER)


func _spawn_boss_group(ids: Array, tier: int) -> void:
	var anchor_pos = _find_any_living_player_position()
	if anchor_pos == null:
		return
	for id in ids:
		var network_id: int = _next_network_enemy_id
		_next_network_enemy_id += 1
		var enemy = _spawn_creature(id, _random_spawn_position(anchor_pos, true), network_id)
		if not enemy:
			continue
		enemy.add_to_group("boss")
		var family: String = ID_FAMILY.get(id, "")
		var mult: Dictionary = FAMILY_MULT.get(family, {"hp": 1.0, "dmg": 1.0})
		var max_health: float = (10.0 + tier * 9.0) * mult["hp"] * BOSS_HEALTH_MULT
		var damage: float = (3.0 + tier * 2.2) * mult["dmg"] * BOSS_DAMAGE_MULT
		if enemy.has_method("apply_boss_stats"):
			enemy.apply_boss_stats(max_health, damage, BOSS_SCALE_MULT, tier)
		if enemy.has_method("enable_item_shield"):
			enemy.enable_item_shield(BOSS_SHIELD_PROTECTION, BOSS_SHIELD_RATIO)
		# Global güçlendirme - boss stats SONRASI uygulanır
		_apply_global_buff(enemy)
		_attach_boss_bar(enemy)
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			_rpc_client_spawn_creature.rpc(id, enemy.global_position, tier, true, network_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_spawn_creature(id: String, pos: Vector2, tier: int, is_boss: bool, network_id: int) -> void:
	var enemy = _spawn_creature(id, pos, network_id)
	if not enemy:
		return
	if is_boss:
		enemy.add_to_group("boss")
		var family: String = ID_FAMILY.get(id, "")
		var mult: Dictionary = FAMILY_MULT.get(family, {"hp": 1.0, "dmg": 1.0})
		var max_health: float = (10.0 + tier * 9.0) * mult["hp"] * BOSS_HEALTH_MULT
		var damage: float = (3.0 + tier * 2.2) * mult["dmg"] * BOSS_DAMAGE_MULT
		if enemy.has_method("apply_boss_stats"):
			enemy.apply_boss_stats(max_health, damage, BOSS_SCALE_MULT, tier)
		if enemy.has_method("enable_item_shield"):
			enemy.enable_item_shield(BOSS_SHIELD_PROTECTION, BOSS_SHIELD_RATIO)
		_apply_global_buff(enemy)
		_attach_boss_bar(enemy)
	else:
		if enemy.has_method("apply_tier_scaling"):
			enemy.apply_tier_scaling(tier)
		if tier >= REGULAR_SHIELD_MIN_TIER and enemy.has_method("enable_item_shield"):
			enemy.enable_item_shield(SHIELD_PROTECTION, REGULAR_SHIELD_RATIO)
		_apply_global_buff(enemy)



## Boss/Final Kademe encounters get a PERMANENTLY visible health+shield bar
## above their head - artık her yaratığın KENDİ can/kalkan çubuğu var (bkz.
## enemy.gd _create_overhead_bar, kullanıcı isteği: "hasar alan yaratığın
## üstünde can ve kalkan barı görünmeli"), bu yüzden burada AYRI bir çubuk
## OLUŞTURULMUYOR - sadece o çubuğu bosslar için kalıcı görünür kılıyoruz
## (normal yaratıklarda çubuk hasarsız 1sn sonra otomatik kayboluyor, bkz.
## OVERHEAD_BAR_HIDE_DELAY - bosslarda bu davranış istenmiyor).
func _attach_boss_bar(enemy: Node) -> void:
	if enemy.has_method("set_overhead_bar_always_visible"):
		enemy.set_overhead_bar_always_visible()


func _spawn_creature(id: String, pos: Vector2, network_id: int = 0) -> Node:
	var scene: PackedScene = SCENES.get(id)
	if not scene:
		return null
	var enemy = scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos
	if network_id > 0:
		enemy.set_meta("network_enemy_id", network_id)
	## Kullanıcı isteği: "oyundan çıkmış biri ... oyundaki son haliyle oyuna
	## katılmalı" - sonradan katılan bir oyuncuya hâlâ hayatta olan
	## yaratıkları "yakalama" (catch-up) yayınıyla göstermek için (bkz.
	## _on_peer_needs_game_catchup) hangi tür olduğu burada saklanıyor.
	enemy.set_meta("creature_id", id)
	return enemy


@rpc("any_peer", "call_remote", "unreliable")
func _sync_enemy_positions(enemy_states: Array) -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	## Sadece host'tan gelen düşman konumu senkronizasyonu kabul edilir.
	if sender_id != 0 and sender_id != NetworkManager._host_peer_id():
		return
	
	# Hızlı erişim için mevcut düşmanları bir dictionary'ye indeksle
	var enemy_map: Dictionary = {}
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var nid: int = int(enemy.get_meta("network_enemy_id", 0))
			if nid > 0:
				enemy_map[nid] = enemy

	for state: Array in enemy_states:
		if state.size() < 2:
			continue
		var network_id: int = int(state[0])
		var enemy: Node = enemy_map.get(network_id, null)
		if enemy and is_instance_valid(enemy) and enemy.has_method("update_network_state"):
			var net_pos: Vector2 = state[1] as Vector2
			var net_dead: bool = state.size() > 2 and state[2] == true
			var net_health: float = state[3] as float if state.size() > 3 else -1.0
			var net_shield: float = state[4] as float if state.size() > 4 else -1.0
			var net_raging: bool = state.size() > 5 and state[5] == true
			var net_chill: int = int(state[6]) if state.size() > 6 else 0
			var net_attacker_id: int = int(state[7]) if state.size() > 7 else 0
			enemy.update_network_state(net_pos, net_dead, net_health, net_shield, net_raging, net_chill, net_attacker_id)


## Kullanıcı isteği: "haritamdaki 'su' ve 'ev' layerlarını collisionshape
## olarak atar mısın... yaratıklar orada spawnlanamaz" - bkz. GameManager.
## is_position_blocked_by_terrain. Su/ev üstüne düşen adaylar reddedilip
## yeniden denenir (halka üzerinde rastgele en fazla 10 deneme) - oyuncunun
## etrafındaki halkanın TAMAMI su/ev olması aşırı nadir bir durum olduğu
## için 10 deneme pratikte hep temiz bir nokta bulur; bulunamazsa (uç durum)
## son denenen konum kullanılır.
func _random_spawn_position(center: Vector2, is_boss: bool = false, bias_dir: Vector2 = Vector2.ZERO) -> Vector2:
	var pos: Vector2 = center
	for _attempt in range(10):
		var angle: float
		if bias_dir != Vector2.ZERO and randf() < DIRECTIONAL_SPAWN_CHANCE:
			var half_arc: float = deg_to_rad(DIRECTIONAL_SPAWN_ARC_DEG) * 0.5
			angle = bias_dir.angle() + randf_range(-half_arc, half_arc)
		else:
			angle = randf() * TAU
		var dist: float = randf_range(min_spawn_distance, max_spawn_distance)
		if is_boss:
			dist += 120.0
		pos = center + Vector2(cos(angle), sin(angle)) * dist
		if not GameManager.is_position_blocked_by_terrain(pos):
			return pos
	return pos


## Tüm düşmanlara (normal + boss) uygulanan global güçlendirme.
## Kullanıcı isteği: "hasarlarının artışını azaltıp dayanıklılıklarını
## arttıralım, özellikle kalkanlarını" - can/kalkan (savunma) ve hasar artık
## AYRI çarpanlarla büyüyor (bkz. GLOBAL_DEFENSE_BUFF/GLOBAL_DAMAGE_BUFF),
## eskiden tek bir ortak GLOBAL_BUFF kullanılıyordu. Kalkan apply_tier_
## scaling/apply_boss_stats sonrası max_health üzerinden hesaplandığından
## onu da (savunma çarpanıyla) güncelliyoruz.
func _apply_global_buff(enemy: Node) -> void:
	var extra_players: int = max(0, _player_count() - 1)
	var multiplayer_defense_mult: float = 1.0 + float(extra_players) * 0.30
	enemy.max_health *= GLOBAL_DEFENSE_BUFF * multiplayer_defense_mult * HEALTH_SHIELD_MULT
	enemy.health = enemy.max_health
	enemy.contact_damage *= GLOBAL_DAMAGE_BUFF
	if enemy.ranged_damage > 0.0:
		enemy.ranged_damage *= GLOBAL_DAMAGE_BUFF
	# Kalkan zaten max_health * shield_ratio ile hesaplandı; oranı bozmamak
	# için item_shield_max ve item_shield_hp'yi de aynı (savunma) çarpanla
	# büyütüyoruz.
	if enemy.item_shield_max > 0.0:
		enemy.item_shield_max *= GLOBAL_DEFENSE_BUFF * multiplayer_defense_mult * HEALTH_SHIELD_MULT
		enemy.item_shield_hp = enemy.item_shield_max
		enemy.item_shield_changed.emit(enemy.item_shield_hp, enemy.item_shield_max)
	enemy.health_changed.emit(enemy.health, enemy.max_health)
	## #26: altın düşme ihtimalini/miktarını her yaratığın kendi sahne
	## değerinin ÜSTÜNE tek bir global çarpanla arttır (bkz. yukarıdaki
	## GOLD_DROP_CHANCE_MULT/GOLD_DROP_AMOUNT_MULT notu).
	enemy.gold_chance = clamp(enemy.gold_chance * GOLD_DROP_CHANCE_MULT, 0.0, 1.0)
	enemy.gold_min = max(1, int(round(enemy.gold_min * GOLD_DROP_AMOUNT_MULT)))
	enemy.gold_max = max(enemy.gold_min, int(round(enemy.gold_max * GOLD_DROP_AMOUNT_MULT)))
	## DÜZELTME (kullanıcı bildirimi: "bosslar az altın ve exp düşürüyor daha
	## çok düşürmeliler"): bosslarda ödül (xp_value/gold_min/gold_max)
	## apply_boss_stats() içinde SATIR 564'teki GLOBAL_DEFENSE_BUFF/
	## multiplayer_defense_mult'tan ÖNCEKİ (daha küçük) max_health'ten
	## hesaplanmıştı - yani boss savunma amaçlı daha da güçlendirildikten
	## sonra bile ödülü hâlâ o buff'tan ÖNCEKİ, daha zayıf haliyle
	## sınırlıydı. Şimdi aynı oranlarla (bkz. enemy.gd apply_boss_stats)
	## NİHAİ (buff'lı) can üzerinden yeniden hesaplanıyor.
	## KÖK NEDEN DÜZELTMESİ (kullanıcı bildirimi: "Bossların altın düşürme
	## oranı hala çok bozuk, %92 azalt düşen expyi de %92 azalt") - buradaki
	## 0.34/0.09/0.14 SABİT KOPYALARI enemy.gd'deki apply_boss_stats() iki
	## kez güncellenirken (%50 sonra %92 azaltma) hiç güncellenmemişti - bu
	## fonksiyon apply_boss_stats()'tan SONRA çalışıp xp_value/gold_min/
	## gold_max'ı bu ESKİ/yüksek oranlarla ÜZERİNE YAZDIĞI için önceki
	## azaltmaların HİÇBİRİ oyunda gerçekten etkili olmuyordu (CLAUDE.md'nin
	## uyardığı "aynı bilgiye iki ayrı yerden referans" hata sınıfı). Artık
	## kopya YOK - enemy.gd'deki TEK kaynak sabitler doğrudan okunuyor.
	if enemy.is_boss:
		enemy.xp_value = round(enemy.max_health * Enemy.BOSS_XP_HEALTH_RATIO)
		enemy.gold_min = max(1, int(enemy.max_health * Enemy.BOSS_GOLD_MIN_HEALTH_RATIO))
		enemy.gold_max = max(enemy.gold_min + 1, int(enemy.max_health * Enemy.BOSS_GOLD_MAX_HEALTH_RATIO))
		enemy.gold_chance = 1.0
