extends Node2D

## Yaratıkların duvar dolanma yol ızgarası (bkz. _ready / enemy_pathing.gd).
const EnemyPathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")
const EventSfx := preload("res://scripts/event_sfx.gd")

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
	"minotaur1": preload("res://scenes/creatures/enemy_minotaur1.tscn"), ## Kademe 3 bossu (bkz. NEW_BOSS_TIERS)
	"underground1": preload("res://scenes/creatures/enemy_underground1.tscn"), ## Kademe 5 bossu: Yeraltı Canavarı (görünmez havuz)
	"sandworm1": preload("res://scenes/creatures/enemy_sandworm1.tscn"), ## Yeraltı Canavarı'nın solucan uzvu (bkz. LIMB_IDS)
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
	"minotaur1": "minotaur",
	"underground1": "underground", "sandworm1": "sandworm",
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

## Kullanıcı isteği (2026-09-27): "oyun başlangıcındaki kademe 1 slimelar 90 saniye sonra doğmaya başlasın" - oyunun ilk
## SLIME_START_DELAY saniyesinde (game_time) rosterdeki slime'lar çıkarılır (Kademe 1'de sadece fareler doğar). Normal
## doğma ve görev dalgası aynı yardımcıyı (_spawnable_roster) kullanır.
const SLIME_START_DELAY := 90.0


func _spawnable_roster(tier: int) -> Array:
	var roster: Array = TIER_ROSTER.get(tier, TIER_ROSTER.get(1, []))
	if GameManager.game_time >= SLIME_START_DELAY:
		return roster
	return roster.filter(func(id: String) -> bool: return not id.begins_with("slime"))


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

## YENİ BOSSLAR (kullanıcı isteği 2026-10-08: eski bosslar elit oldu, yeni bosslar tek tek veriliyor). GameManager.bosses_enabled KAPALIYKEN
## (varsayılan) SADECE bu tablodaki kademelerin bossu doğar; Final, zafer ve sonsuz boss dalgası kapalı kalır. Kademe -> [yaratık kimlikleri].
## Yeni boss geldikçe buraya satır ekle (+ FIXED_BOSS_STATS'a statları, + boss_bar_art.gd NAMES'e adı). bosses_enabled AÇIKKEN eski
## BOSS_TIERS (yukarıdaki eski bosslar) çalışır - o akışı sınayan testler içindir; tüm yeni bosslar gelince BOSS_TIERS bununla değiştirilecek.
const NEW_BOSS_TIERS := {
	3: ["minotaur1"],
	5: ["underground1"],
}

## Elle belirlenmiş NİHAİ statlı bosslar (kullanıcı isteği 2026-10-08, Minotaur: "Canı 80.000, Kalkanı 90.000, Kalkan Soğurması %80, Hasarı 100",
## sonra aynı gün "Kalkanını ve canını %60 azalt" -> can 32.000, kalkan 36.000).
## boss_base_stats / FAMILY_MULT / global çarpan zinciri bu değerleri ÜRETMEZ: tablodaki sayılar tek oyunculuda AYNEN kullanılır (bkz.
## _apply_fixed_boss_stats). Çok oyunculuda can ve kalkan TÜM yaratıklarla aynı kuralla ekstra oyuncu başına +%50 büyür
## (EXTRA_PLAYER_DEFENSE_MULT); hasar büyümez. reward_ref: altın/XP ödülü bu kimlikli referans bossun (aynı Kademe) ödülüne EŞİT kalır -
## ödüller can sayısına bağlanmaz ("ödüller değişmez" ilkesi, bkz. _apply_global_buff).
const FIXED_BOSS_STATS := {
	"minotaur1": {"health": 32000.0, "shield": 36000.0, "protection": 0.8, "damage": 100.0, "reward_ref": "iskelet3"},
	## Yeraltı Canavarı (2026-10-09, "Bossun canı 50.000 Kalkanı 60.000"; kalkan soğurması verilmedi -> standart boss %90; hasarlar uzuvlarda: asit 110, savurma 130, bkz. worm_boss_math.gd).
	## Bu havuz SADECE uzuvlar üzerinden azalır: toplam ~110.000 hasar (can + kalkan) = ~55 uzuv (worm_boss_math.gd LIMB_THRESHOLD 2.000).
	"underground1": {"health": 50000.0, "shield": 60000.0, "protection": 0.9, "damage": 0.0, "reward_ref": "iskelet3"},
}

## Boss havuzuna bağlı solucan UZUVLARI: sıradan yaratık değil - tier ölçeği / kalkan / global çarpan / ödül YOK (kendi eşiği sahnede, hasarı bossa gider; bkz. worm_limb.gd).
## Hem host (underground_boss.gd _spawn_limb) hem istemci (_rpc_client_spawn_creature) bu kimlikleri çarpansız kurar.
const LIMB_IDS := ["sandworm1"]

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
## Kullanıcı bildirimi (2026-09-24): "Yaratıklar çok hızlı artıyor daha yavaş zorlanmalı oyun" - başlangıç
## aralığı 0.6 -> 0.9 (SPAWN_RATE_MULT sonrası ilk dakikada 0.4sn -> 0.6sn, dakikada ~150 -> ~100 spawn).
## min_interval (nihai/geç oyun yoğunluğu) DEĞİŞMEDİ - sadece oraya varış yavaşladı (bkz. difficulty_ramp).
@export var base_interval: float = 0.9
@export var min_interval: float = 0.16
## DÜZELTME (kullanıcı bildirimi: "yaratıklar çok hızlı bir şekilde çoğalıyorlar
## ve aşırı fazla oluyorlar, biraz daha yavaş ilerlemesi gerek") - eskiden
## 0.006 ile spawn aralığı base_interval'den min_interval'e (0.6 -> 0.16)
## sadece ~73 saniyede (t * difficulty_ramp), yani tier_duration=100sn olan
## Kademe 1 BİLE bitmeden, iniyordu - maçın geri kalan ~24 dakikası boyunca
## zaten en yüksek yoğunlukta düz gidiyordu. Yarıya indirilince aynı tavana
## (0.16sn, hâlâ AYNI nihai zorluk) ~147 saniyede (Kademe 2 civarı) ulaşılıyor -
## erken oyun daha kademeli hissettiriyor, nihai zorluk değişmedi.
## SONRAKİ TUR (kullanıcı bildirimi 2026-09-24: "Yaratıklar çok hızlı artıyor daha yavaş zorlanmalı oyun") -
## 0.003 ile tavana hâlâ ~2.5 dakikada (Kademe 2) varılıyordu. 0.001 + yeni base_interval 0.9 ile
## 0.9 -> 0.16 inişi ~740 saniye (~12 dk, Kademe 8 civarı) sürüyor - aynı nihai zorluk, çok daha yavaş yol.
## KADEME 3 DENGE TURU (kullanıcı bildirimi 2026-10-06: "kademe 3'ten sonra oyun oynanamayacak kadar zorlaşıyor, öncesi aşırı kolay - arada bariz fark"):
## 0.001 -> 0.0006. Ölçüm (tools yok, gerçek koddan: yaratık canı x doğuş sıklığı = "saniyede öldürülmesi gereken can"): Kademe 3->8 arası
## doğuş sıklığı x3.9 (2.3 -> 9.1/sn) artıp yaratık canı da x6 artıyordu (toplam x24). 0.0006 ile aynı aralıkta doğuş x1.65 (2.0 -> 3.3/sn);
## 0.16 tavanına ~1230 sn'de (Kademe 12) varılır. Kademe 1-2'de doğuş en fazla ~%8 azalır (zaten kolay), zorlaşan hiçbir şey yok.
@export var difficulty_ramp: float = 0.0006
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
## SONRAKİ TUR (kullanıcı isteği: "yaratık sayısını ciddi artır", perf
## çalışması sonrası) - enemy.gd'deki ayrışma artık toplu/düz dizi üzerinden
## hesaplanıyor VE oyuncudan uzak yaratıklar LOD ile neredeyse bedava (bkz.
## enemy.gd ENEMY_LOD_NEAR_RADIUS_SQ notu), yani eski 80/150 denemelerindeki
## darboğaz büyük ölçüde ortadan kalktı. 80 -> 220, SONRA kullanıcı isteğiyle
## 220 -> 200 (test için yuvarlak sayı) - hâlâ SADECE bir test değeri,
## profiler'la ölçüp gerekirse yine kullanıcı tercihine göre ayarlanmalı.
## 2026-09-25: bu artık 5 OYUNCULU oyunun tavanı - daha az oyuncuda düşer (bkz. player_enemy_cap).
## Kullanıcı isteği (2026-09-27): "yaratık sayısı singleplayerda 100 sonrasında her oyuncu için +20 olsun (can kalkan
## oranlarına dokunma)" - artık bu TEK OYUNCULU tavan; her ek oyuncu ENEMY_CAP_PER_EXTRA_PLAYER ekler (bkz. player_enemy_cap).
## Kullanıcı isteği (2026-10-03, C++ EnemyWorld yeniden yazımından sonra): "yaratık sınırını 500'e yükselt" - 100 -> 500.
## Oyuncu başı +20 ve kademe kısması (_tier_crowding_scale) BİLEREK aynı kaldı.
## Kullanıcı isteği (2026-10-04): "maksimum spawnlanabilecek yaratık sayısını 250 ile sınırla, oyuncu başına bu sınır 50 artsın" -
## 500 -> 250, ek oyuncu başı +20 -> +50 (ENEMY_CAP_PER_EXTRA_PLAYER). Kademe kısması (_tier_crowding_scale) aynı kaldı.
@export var max_concurrent_enemies: int = 250
## Multiplayer enemy scaling: solo keeps the original cap; each additional
## player adds room for more creatures and slightly increases spawn frequency.
## Kullanıcı isteği: "oyuncu başına yaratık sayısı %50 [artsın]" - eskiden 18, ×1.5 (27).
## Kullanıcı isteği: "yaratık spawnını %150 arttır" - 27 -> 68 (×2.5).
## DÜZELTME (kullanıcı isteği: "spawn sınırını 90'a düşürelim") - 68 -> 39,
## max_concurrent_enemies ile AYNI oranda (158->90, ~×0.57) küçültüldü.
## SONRAKİ TUR (perf çalışması sonrası, bkz. max_concurrent_enemies üstündeki
## not) - max_concurrent_enemies ile AYNI oranda (şimdi 200/80) yükseltildi,
## yine sadece başlangıç test değeri.
## KALDIRILDI (kullanıcı isteği 2026-09-25): eskiden tavan = 200 + (oyuncu - 1) x 98 idi (5 oyuncuda 592). Yeni kural:
## "maksimum yaratık sayısı 5 oyuncu varken olsun; 4 oyuncuda 180, 3'te 160, 2'de 140, tek oyunculuda 120" -
## max_concurrent_enemies (200) artık 5 oyuncunun tavanı, her eksik oyuncu için ENEMY_CAP_STEP_PER_MISSING_PLAYER düşer.
## 2026-09-27: yeni kural - tek oyuncu max_concurrent_enemies (100), her ek oyuncu +20 (2 -> 120, 3 -> 140, 4 -> 160...).
const ENEMY_CAP_PER_EXTRA_PLAYER := 50
## Kullanıcı isteği (2026-09-24 denge turu: "her kademe için oyuncu başına %30 spawn ve %50 can") - 0.25 -> 0.30.
const EXTRA_PLAYER_SPAWN_RATE := 0.30
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

## Kullanıcı isteği: "tüm yaratıkların canını ve kalkanını %10 azalt ancak tekrar spawnlanma hızlarını
## arttır" - _current_interval() bu çarpana bölünür (1.5 = %50 daha sık). Çarpan burada (export'lardan
## AYRI) tutuluyor ki sahnede/ayarlarda ezilmiş base_interval/min_interval değerleri bunu etkisiz kılmasın.
const SPAWN_RATE_MULT := 1.5

## Kullanıcı isteği: "davranışsal olarak gittiğim yönlerdeki duvarların arkasında hızlı hızlı çok sayıda
## spawnlanıp önünü kesmeye çalışsınlar oyuncuların" - oyuncu HAREKET EDERKEN, gittiği yönün önündeki bir
## orman duvarının ARKASINDA (düz çizgi duvara çarpan, dolayısıyla sisle de gizli bir nokta) bir "pusu paketi"
## (AMBUSH_PACK_MIN..MAX yaratık, dar bir kümede) belirir. Duvar-arkası uygun nokta bulunamazsa (açık arazi)
## paket YOK, normal tek spawn olur. Pakette de yaratık sayısı yine _scaled_enemy_cap() ile sınırlı.
const AMBUSH_PACK_CHANCE := 0.45 ## hareket eden oyuncu için bir spawn tetiklenişinin pusu paketi olma olasılığı
const AMBUSH_PACK_MIN := 2
const AMBUSH_PACK_MAX := 4
const AMBUSH_PACK_SPREAD := 70.0 ## paket üyelerinin pusu noktasına en fazla uzaklığı
const AMBUSH_ARC_DEG := 80.0 ## pusu noktası, oyuncunun gittiği yönün etrafında bu yelpazede aranır
const AMBUSH_EXTRA_DISTANCE := 200.0 ## max_spawn_distance'ın ÖTESİNDE de aranır (duvarın arkası daha uzakta olabilir)
const AMBUSH_ATTEMPTS := 14 ## duvar-arkası nokta için rastgele deneme sayısı

## Kullanıcı isteği: "karakter çok güçlüyse normalden daha fazla
## spawnlansın" - takım seviyesi o anki Kademe için "beklenenden" epey
## yüksekse (oyuncular zorluğa göre fazlasıyla güçlenmiş demektir) her
## tetiklenişte normal TEK yaratığın yanına ekstra yaratıklar da eklenir.
## Kullanıcı isteği (2026-09-24 denge turu): 2.5 -> 4. Gerçekte Kademe başına ~5 seviye atlandığı için 2.5 ile mekanizma
## hep maksimumda (+4) çalışıyor, güçlü/zayıf takımı ayırt etmiyordu.
const POWER_LEVEL_PER_TIER := 4.0 ## bu Kademe'de "normal" sayılan kabaca takım seviyesi
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
## Kullanıcı isteği (DÖRDÜNCÜ tur): "bossların canını ve kalkanını %20 düşür (şuanki değerlerini direkt %20
## azalt)" - BOSS_HEALTH_MULT 158.4 -> 126.72 (×0.8). Boss kalkan havuzu max_health × BOSS_SHIELD_RATIO'dan
## TÜRETİLDİĞİ için (bkz. enemy.gd enable_item_shield) kalkan da kendiliğinden tam %20 iner - BOSS_SHIELD_RATIO
## BİLEREK değiştirilmedi (ikisi de çarpılsaydı kalkan %36 düşerdi, üçüncü turdaki notla AYNI tuzak).
## Bosslar ayrıca aşağıdaki "tüm yaratıklar %10" azaltmasına (HEALTH_SHIELD_MULT) DAHİL EDİLMEDİ, kendi
## çarpanları BOSS_HEALTH_SHIELD_MULT: iki azaltma üst üste binip %28 düşüş yapmasın, "direkt %20" olsun.
## Kullanıcı isteği (BEŞİNCİ tur): "Bossların canını %15 kalkanını %10 azalt" - BOSS_HEALTH_MULT 126.72 ->
## 107.712 (×0.85). Boss kalkan havuzu max_health × BOSS_SHIELD_RATIO'dan türetildiği için can düşünce kalkan da
## kendiliğinden %15 iner; kalkanın toplamda TAM %10 azalması için BOSS_SHIELD_RATIO aşağıda
## 1.3 × 0.9 / 0.85 yapıldı (yeni kalkan = 0.85 can × oran = eski kalkanın 0.9'u). Dördüncü turdaki "ikisini
## birden çarpma" tuzağının tersi: burada iki yüzde FARKLI olduğu için oran ayrıca ayarlanmak ZORUNDA.
## Kullanıcı isteği: "Bossların hasarını %10 arttırıp tüm yaratıkların hasarını %10 azalt" - BOSS_DAMAGE_MULT
## 2.4 -> 2.64 (×1.1), GLOBAL_DAMAGE_BUFF (aşağıda) 1.68 -> 1.512 (×0.9). GLOBAL_DAMAGE_BUFF _apply_global_buff
## ile bosslara da uygulandığı için bosslar için net etki ×1.1 × 0.9 = ×0.99 (kullanıcı sırasıyla "arttırıp ...
## tüm yaratıkların azalt" dedi); normal yaratıklar tam ×0.9.
const BOSS_HEALTH_MULT := 107.712 ## eskiden 126.72
## Kullanıcı isteği (2026-09-24 denge turu: "Kademe 3 ve öncesi de dahil hepsi +%60") - boss vuruşu Kademe 15'te bile sıradan
## bir geç oyun yaratığı kadardı. 2.64 -> 4.224 (x1.6), tüm bosslar.
const BOSS_DAMAGE_MULT := 4.224 ## eskiden 2.64
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


## Normal yaratığın bu Kademe'deki kalkan soğurması: Kademe 3'ten itibaren kademeli (bkz. SHIELD_PHASE_IN_TIERS). 0 = kalkan yok (Kademe 1-2).
static func regular_shield_protection(tier: int) -> float:
	if tier < REGULAR_SHIELD_MIN_TIER:
		return 0.0
	return SHIELD_PROTECTION * clampf(float(tier - REGULAR_SHIELD_MIN_TIER + 1) / float(SHIELD_PHASE_IN_TIERS), 0.0, 1.0)


## Kademe 1-2 kesintisi (EARLY_TIER_DURABILITY_CUT) ve Kademe 3-5'te yumuşayarak kalkması (EARLY_CUT_TAPER); sonrası 1.0. Boss olmayan yaratıklar için.
static func early_durability_cut(tier: int) -> float:
	if tier >= 1 and tier <= EARLY_TIER_MAX:
		return EARLY_TIER_DURABILITY_CUT
	return float(EARLY_CUT_TAPER.get(tier, 1.0))


## Normal yaratık hasar çarpanı: Kademe 3-5'te EARLY_CUT_TAPER (0.85/0.90/0.95), diğer Kademelerde 1.0 (Kademe 1-2'nin hasarı hiç değişmedi).
static func early_damage_taper(tier: int) -> float:
	return float(EARLY_CUT_TAPER.get(tier, 1.0))


## Yaratığın bu Kademe'deki NİHAİ hasar çarpanı (temas + menzilli): normal yaratıkta early_damage_taper x Kademe 3+ %10 düşüşü, bosslarda
## sadece Kademe 3+ düşüşü (boss hasarı zaten BOSS_PACING'de ayarlı). Kademe 0/geçersiz = 1.0.
static func tier_damage_mult(tier: int, is_boss: bool) -> float:
	if tier < 1:
		return 1.0
	var m: float = 1.0 if is_boss else early_damage_taper(tier)
	if tier >= LATE_TIER_DAMAGE_MIN_TIER:
		m *= LATE_TIER_DAMAGE_MULT
	return m


## Kademe 3+ can/kalkan çarpanı (bkz. LATE_TIER_DURABILITY_MULT) - EARLY_CUT_TAPER ve BOSS_PACING'in ÜSTÜNE biner. Kademe 0/1-2 = 1.0.
static func late_durability_mult(tier: int) -> float:
	return LATE_TIER_DURABILITY_MULT if tier >= LATE_TIER_DAMAGE_MIN_TIER else 1.0


## Boss can/hasar çarpanı (bkz. BOSS_PACING). Tabloda olmayan Kademe için 1.0.
static func boss_health_pacing(tier: int) -> float:
	return float((BOSS_PACING.get(tier, [1.0, 1.0]) as Array)[0])


static func boss_damage_pacing(tier: int) -> float:
	return float((BOSS_PACING.get(tier, [1.0, 1.0]) as Array)[1])


## Boss'un kalkan/global çarpanlar ÖNCESİ taban can ve hasarı - host (_spawn_boss_group) ve istemci (_rpc_client_spawn_creature) AYNI formülü
## buradan okur (eskiden iki ayrı kopyaydı; biri değişip diğeri unutulursa istemci bossu farklı canla doğardı).
static func boss_base_stats(id: String, tier: int) -> Dictionary:
	var family: String = ID_FAMILY.get(id, "")
	var mult: Dictionary = FAMILY_MULT.get(family, {"hp": 1.0, "dmg": 1.0})
	return {
		"health": (10.0 + tier * 9.0) * float(mult["hp"]) * BOSS_HEALTH_MULT * boss_health_pacing(tier),
		"damage": (3.0 + tier * 2.2) * float(mult["dmg"]) * BOSS_DAMAGE_MULT * boss_damage_pacing(tier),
	}


## Normal yaratığa (Kademe `tier` için) kalkanını verir - tüm doğuş yolları (normal, görev dalgası, debug, istemci RPC) buradan geçer.
func _enable_regular_shield(enemy: Node, tier: int) -> void:
	if tier >= REGULAR_SHIELD_MIN_TIER and enemy.has_method("enable_item_shield"):
		enemy.enable_item_shield(regular_shield_protection(tier), REGULAR_SHIELD_RATIO)
const BOSS_SHIELD_RATIO := 1.3 * 0.9 / 0.85 ## (BEŞİNCİ tur: can ×0.85, kalkan ×0.9 - bkz. BOSS_HEALTH_MULT üstündeki not) eskiden 1.3. Kullanıcı isteği: "bossların kalkanlarını canlarından %30 daha fazla olacak şekilde dengele" - shield = health * 1.3 (eskiden 6.24, ~6.2x can)

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
## Kullanıcı isteği: "Tüm yaratıkların canını ve kalkanını %10 azalt" - normal yaratıklar için 2.64 -> 2.376
## (×0.9). Bosslar için bkz. BOSS_HEALTH_SHIELD_MULT.
## Kullanıcı isteği (2026-09-25): "tüm yaratıkların canlarını ve kalkanlarını %15 azaltıp hasarlarını %20 arttır" -
## 2.376 -> 2.0196 (×0.85). Bosslar DAHİL ("tüm"): BOSS_HEALTH_SHIELD_MULT da ×0.85, GLOBAL_DAMAGE_BUFF ×1.2 (o çarpan
## bosslara da uygulanıyor). Bu çarpanlar TÜM spawn yollarının geçtiği tek yerde (_apply_global_buff) - kopya yok.
const HEALTH_SHIELD_MULT := 2.0196
## Bosslara uygulanan can/kalkan çarpanı - normal yaratıkların ESKİ değeri (2.64), yani bosslar "tüm
## yaratıklar %10" azaltmasından muaf (bkz. BOSS_HEALTH_MULT üstündeki not: bosslar TAM %20 azalır).
## 2026-09-25: 2.64 -> 2.244 (×0.85, bkz. HEALTH_SHIELD_MULT üstündeki not).
const BOSS_HEALTH_SHIELD_MULT := 2.244
## 2026-09-25 turunun can/kalkan kesintisi (×0.85). Boss altın/XP ödülü bossun NİHAİ canından hesaplanıyor (bkz.
## _apply_global_buff) - kullanıcı ödül değişikliği istemedi, bu yüzden ödül bu kesintiden ÖNCEKİ can üzerinden
## hesaplanır (ödüller aynen kalır).
const DURABILITY_CUT_2026_09_25 := 0.85
## Kullanıcı isteği (2026-09-25, ikinci tur): "tüm bossların canını ve kalkanını %15 azalt hasarını da %15 azalt" - SADECE
## bosslar, _apply_global_buff'ta can, kalkan (item_shield_max - candan ayrı çarpıldığı için ikisi de TAM %15 iner, üst üste
## binmez) ve temas/menzilli hasara x0.85. Yaratık yetenekleri (asit, lazer...) contact_damage'den türediği için onlar da
## iner. Tüm boss doğuş yolları (normal, geç katılan istemci, debug) bu fonksiyondan geçiyor - kopya yok. Ödül (altın/XP)
## DURABILITY_CUT ile AYNI gerekçeyle bu kesintiden önceki can üzerinden hesaplanır (kullanıcı ödül değişikliği istemedi).
const BOSS_CUT_2026_09_25B := 0.85
## Kullanıcı isteği (2026-09-26): "Tüm yaratıkların canını ve kalkanını %10 azalt" - normal + boss, can ve kalkana
## x0.9 (_apply_global_buff; tüm doğuş yolları oradan geçer). Boss ödülü önceki kesintilerle aynı gerekçeyle bu
## kesintiden ÖNCEKİ can üzerinden hesaplanır (ödüller değişmez).
const DURABILITY_CUT_2026_09_26 := 0.9
## Kullanıcı isteği (2026-09-26, ikinci): "ilk 2 kademedeki yaratıkların canlarını ve kalkanlarını %20 azalt" - Kademe 1-2'de
## doğan (boss olmayan; bu kademelerde boss yok) yaratıklara ek x0.8, can ve kalkana. Kademe 1-2 yaratıklarının şu an kalkanı
## yok (REGULAR_SHIELD_MIN_TIER = 3) ama çarpan kalkana da uygulanır. Kademe apply_tier_scaling ile _apply_global_buff'tan
## ÖNCE atanıyor (tüm doğuş yolları: normal, görev dalgası, pusu, debug).
const EARLY_TIER_DURABILITY_CUT := 0.8
const EARLY_TIER_MAX := 2
## KADEME 3 GEÇİŞ YUMUŞATMASI (kullanıcı bildirimi 2026-10-06, bkz. difficulty_ramp üstündeki ölçüm notu): Kademe 2 -> 3'te yaratık dayanıklılığı
## BİR ANDA ~x1.8 artıyordu (Kademe 1-2'nin x0.8 kesintisi kalkıyor + %30 soğurmalı kalkan tam güçle geliyordu) ve ortalama yaratık "etkin canı"
## 23 -> 104 (x4.5) olup tek adımda oyuncunun kapasitesini aşıyordu. Kademe 1-2 BİLEREK aynı kaldı (kullanıcı kolay istedi); geçiş basamaklandı:
##  - kalkan soğurması Kademe 3'te SHIELD_PROTECTION'ın 1/SHIELD_PHASE_IN_TIERS'i, her Kademe +1/N, Kademe 7'de tam %30 (bkz. regular_shield_protection),
##  - Kademe 1-2'nin x0.8 kesintisi Kademe 3-5'te EARLY_CUT_TAPER ile yumuşayarak kalkar (bkz. early_durability_cut).
## Etkin dayanıklılık çarpanı (kesinti / (1 - soğurma)): K2 0.80, K3 0.91, K4 1.02, K5 1.16, K6 1.32, K7+ 1.43 (eskiden K2 0.80 -> K3 1.43).
const SHIELD_PHASE_IN_TIERS := 5
## Aynı tablo HASAR için de geçerli (bkz. early_damage_taper): ortalama temas hasarı Kademe 2 -> 3'te de ~x1.9 sıçrıyordu (9 -> 17.5).
const EARLY_CUT_TAPER := {3: 0.85, 4: 0.90, 5: 0.95}
## Kullanıcı isteği (2026-10-06): "Kademe 3 ve sonrasının hasarını %10 düşür" - bu Kademe'den itibaren HER yaratığın (bosslar, sonsuz katlar, Final
## dahil) temas/menzilli hasarı x0.9; yaratık yetenekleri (asit, ateş topu, lazer) contact_damage'den türediği için onlar da düşer. EARLY_CUT_TAPER /
## BOSS_PACING'in ÜSTÜNE biner (bkz. tier_damage_mult). Kademe 1-2 hasarı değişmedi.
const LATE_TIER_DAMAGE_MIN_TIER := 3
const LATE_TIER_DAMAGE_MULT := 0.9
## Kullanıcı isteği (2026-10-06, hasar düşüşünün hemen ardından): "3. kademeden sonra zorluğu genel olarak %10 daha düşür" - hasara ek olarak
## yaratık DAYANIKLILIĞI (can + kalkan) da Kademe 3'ten itibaren x0.9 (bosslar, sonsuz katlar, Final dahil; saniyede öldürülmesi gereken can R de %10
## düşer). Doğuş sıklığına dokunulmadı. Boss ödülü (altın/XP) bu çarpana bölünür - ödüller değişmez. Bkz. late_durability_mult.
const LATE_TIER_DURABILITY_MULT := 0.9
## İLK BOSSLAR (kullanıcı bildirimi 2026-10-06): Kademe 3 bossu (iskelet3) etkin canı ~19.500 (Kademe 3'ün sıradan yaratığının ~190 katı, Kademe 6
## bossunun ~120, Kademe 8'in ~85 katı) ve vuruşu 62 idi; boss kapısı yüzünden o savaş kaçınılmazdı (Kademe 4 ancak boss ölünce açılır). Boss
## büyüklükleri Kademe'yle doğrusal arttığı için İLK bosslar orantısız güçlüydü. Kademe -> [can çarpanı, hasar çarpanı]; tabloda olmayan Kademe
## (12, 15, Final, sonsuz boss dalgaları) aynen kalır. Boss ödülü (altın/XP) BU çarpana bölünür - ödüller değişmez (bkz. _apply_global_buff).
const BOSS_PACING := {3: [0.6, 0.8], 6: [0.75, 0.9], 8: [0.85, 0.95]}
## DÜZELTME (kullanıcı isteği: "yaratıkların hasarını %60 arttır") - 1.05 ->
## 1.68 (1.05 * 1.6).
## Kullanıcı isteği: "tüm yaratıkların hasarını %10 azalt" - 1.68 -> 1.512 (×0.9), bosslar DAHİL (bkz.
## BOSS_DAMAGE_MULT üstündeki not).
## Kullanıcı isteği (2026-09-25): "hasarlarını %20 arttır" - 1.512 -> 1.8144 (×1.2), bosslar DAHİL. Yaratık yetenekleri
## (asit, ateş topu, lazer, dikenler) ve menzilli saldırılar da bu çarpanla büyüyen contact/ranged_damage'den türüyor.
const GLOBAL_DAMAGE_BUFF := 1.8144 ## sadece hasar için (eskiden 1.512, ondan önce 1.68, ondan önce ortak 1.3)

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
## GEÇİCİ TEST AYARI (kullanıcı isteği: "oyunu açtığımda 1 dakikada yavaşça
## artıcak şekilde 200 düşman spawnlansın") - stres/görsel testi için. Normal
## Kademe/roster/ölçekleme mantığına HİÇ dokunmuyor (hâlâ _current_interval'ın
## çağırdığı _spawn_regular_enemy() üzerinden, doğru tier ile spawn ediyor),
## sadece bu pencerede spawn ARALIĞINI DEBUG_RAMP_TEST_TARGET'a
## DEBUG_RAMP_TEST_SECONDS içinde ulaşacak şekilde hızlandırıyor. KALICI bir
## oyun özelliği DEĞİL - test bitince DEBUG_RAMP_TEST_ENABLED'ı false yap.
const DEBUG_RAMP_TEST_ENABLED := false
const DEBUG_RAMP_TEST_SECONDS := 60.0
const DEBUG_RAMP_TEST_TARGET := 200
var _debug_ramp_elapsed: float = 0.0
var _network_sync_timer: float = 0.0
var _next_network_enemy_id: int = 1
## ELİT HAVUZU (kullanıcı 2026-10-08: "tüm bosslar bundan sonra elit yaratıkların yerine geçsin; hafif büyük ve yıldızlı"): eski bossların 14 yaratığı.
## Her Kademe'nin TEK eliti artık rastgele roster yaratığı değil bu havuzdan gelir (elite_candidates: Kademe roster'ının ailelerine uyanlar;
## hiçbiri uymazsa komşu kademelere genişler - ör. sadece slime olan Kademe 9). Boss sistemi kapalıdır (GameManager.bosses_enabled).
const ELITE_POOL := [
	"iskelet3", "lich3", "ork3", "agac3", "golem3", "rontgen2", "rontgen3",
	"demon3", "hayalet3", "mantar3", "rat3", "vampire3", "zombie3", "iblis3",
]
var _boss_tiers_spawned: Dictionary = {}
var _final_spawned: bool = false

## ==============================================================================
## ZAFER + SONSUZ MOD (kullanıcı isteği 2026-10-05: "Final'in 13 bossunu yenince Hayatta Kaldın penceresi, Sonsuza Devam Et").
## Hepsi HOST'ta (tek oyunculu = host) çalışır; durum NetworkManager.broadcast_victory / broadcast_endless_* ile herkese
## iletilir. Hesaplar endless_math.gd'de (tek yerde, testler de oradan okur).
##  NORMAL  -> Final'in doğan bosslarının (_final_bosses) HEPSİ ölünce _check_victory -> VICTORY
##  VICTORY -> yaratıklar dağılır (dismiss_without_reward: ödül/öldürme yok), doğuş durur, zafer penceresi açık;
##             host "Sonsuza Devam Et"e basınca begin_endless -> ENDLESS
##  ENDLESS -> her tier_duration saniyede yeni KAT: yeni doğan yaratıkların istatistik kademesi 15 + kat (16, 17, ...),
##             ROSTER 15'te kalır (TIER_ROSTER'da 16+ yok, bilinmeyen kademe 1. kademeye düşerdi); her 3 katta bir boss dalgası;
##             her katta 1 elit. Kademe boss kapısı (_tier_time tutma) sonsuzda YOK.
## Kademe saati/kapısı/bildirimi (_tier_time, _check_tier_announcement) bu bloktan etkilenmez - Final'den sonra aynen donuk kalır.
## ==============================================================================
const EndlessMathScript: GDScript = preload("res://scripts/endless_math.gd")
const CameraShakeScript: GDScript = preload("res://scripts/camera_shake.gd")
enum RunPhase { NORMAL, VICTORY, ENDLESS }
var _run_phase: int = RunPhase.NORMAL
var _final_bosses: Array = [] ## Final Kademe'nin doğan boss düğümleri (host) - hepsi ölünce zafer
var _endless_start_time: float = 0.0 ## sonsuz mod başladığındaki GameManager.game_time
var _endless_layer: int = 0 ## 0 = sonsuz değil
var _endless_bosses_spawned: Dictionary = {} ## kat -> true
var _endless_elite_due: Dictionary = {} ## kat -> katın içindeki en erken elit anı (sonsuz mod başından saniye)
var _endless_elite_spawned: Dictionary = {} ## kat -> true

## ELİT YARATIK (kullanıcı isteği 2026-10-02 - kurallar enemy.gd make_elite üstünde): her Kademe'de TAM 1 elit. Kademe'nin
## ilk sıradan doğumunda o Kademe için Kademe saatinde (_tier_time) rastgele bir "vade" seçilir - ilk doğumdan
## ELITE_WINDOW_MIN..MAX x tier_duration sonra, ama Kademe bitmeden ELITE_END_MARGIN sn önceyi geçmeyecek şekilde (vade
## Kademe'nin dışına düşüp o Kademe'nin eliti hiç doğmamasın). Vadeden sonraki ilk sıradan doğum (rastgele seçilmiş
## roster yaratığı) elite dönüşür. Bosslar/görev dalgaları/debug doğumları elit olmaz. Sadece host karar verir; istemciler
## _rpc_client_spawn_creature'ın is_elite bayrağıyla öğrenir.
const ELITE_WINDOW_MIN := 0.1
const ELITE_WINDOW_MAX := 0.7
const ELITE_END_MARGIN := 10.0
var _elite_due_time: Dictionary = {} ## kademe -> elitin doğabileceği en erken Kademe saati (_tier_time)
var _elite_spawned_tiers: Dictionary = {} ## kademe -> true

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
## Tek _sync_enemy_positions paketindeki en fazla yaratık: ikili biçimde (bkz. enemy_sync_codec.gd) yaratık başına 22-26 bayt ->
## 40 yaratık ~1040 bayt, Epic P2P paket sınırına (bkz. scripts/net/fragment_peer.gd) bölünmeden sığar.
const EnemySyncCodecScript := preload("res://scripts/enemy_sync_codec.gd")
const ENEMY_SYNC_BATCH := EnemySyncCodecScript.BATCH
var _enemy_sync_tick: int = 0 ## host: tur sayacı (paketlerle gider, istemci eski turu atar)
var _enemy_sync_last_tick: int = -1 ## istemci: son uygulanan tur
var _handover_timer: float = 0.0 ## host: devir paketi yayın sayacı (bkz. export_handover)
var _far_tier_tick: int = 0
var _last_dead_sent: Dictionary = {} ## network_enemy_id -> bool


func _ready() -> void:
	add_to_group("enemy_spawner") ## yönetmenler (underground_boss.gd) uzuv doğurmak için bulur
	NetworkManager.became_host.connect(_on_became_host)
	NetworkManager.peer_needs_game_catchup.connect(_on_peer_needs_game_catchup)
	## HOST DEVRİ (bkz. network_manager.gd "HOST DEVRİ" bloğu): bu Main yeni host olan oyuncunun yeniden kurduğu koşu. Eski host'un son
	## yayınladığı devir paketi varsa gizli sayaçlar oradan, yoksa (host ilk saniyelerde düştü) oyun saatinden tahminle kurulur.
	var migrated: Dictionary = NetworkManager.peek_migration_handover()
	if not migrated.is_empty() and NetworkManager.is_host:
		var saved: Dictionary = migrated.get("spawner", {})
		if saved.is_empty():
			_on_became_host.call_deferred()
		else:
			import_handover(saved)
	## Yaratıkların duvar dolanma yol ızgarası (bkz. enemy_pathing.gd) ilk duvar
	## karşılaşmasında değil, harita yüklenirken kurulsun - ilk kurulum ~onlarca ms.
	call_deferred("_prepare_enemy_pathing")


func _prepare_enemy_pathing() -> void:
	## Sadece harita sahnede VARKEN: GameManager.get_forest_layer() harita yokken bir kez
	## "arandı" diye işaretlenip oturum boyunca bir daha aramayı bırakıyor (bkz. game_manager.gd
	## _find_terrain_layers) - ana menüde çağırıp bunu zehirlememek için.
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_node_or_null("Harita") == null:
		return
	EnemyPathingScript.prepare()


## Kullanıcı isteği: "oyundan çıkmış biri ... oyundaki son haliyle oyuna
## katılmalı" - host, hâlâ hayatta olan TÜM yaratıkları (_rpc_client_spawn_
## creature ile - normal spawn broadcast'iyle AYNI fonksiyon, sadece burada
## SADECE geç katılan bu peer'e hedefli) yeniden "doğuruyor" ki o oyuncu
## boş bir savaş alanı görmesin. Can/kalkan oranı ilk anda tam olmayabilir
## (apply_boss_stats/apply_tier_scaling tazeden hesaplar) ama bir sonraki
## _sync_enemy_positions turunda (≤0.2sn) gerçek değerlere düzelir.
## HOST DEVRİ: yeni host'un bilmesi gereken HOST'A ÖZEL sayaçlar (istemciler bunları göremez). Host bunu ~2 sn'de bir herkese yayınlar
## (NetworkManager.publish_host_handover). Yaratıklar/drop'lar devirde taze kurulduğu için YAŞAYAN boss/elit kademeleri "doğdu" sayılmaz:
## yeni host onları tetik zamanı geçmiş olduğundan hemen yeniden doğurur (can sıfırlanır ama boss atlanmaz).
func export_handover() -> Dictionary:
	var done_boss_tiers: Array = []
	for t in _boss_tiers_spawned.keys():
		if not _tier_boss_alive(int(t)):
			done_boss_tiers.append(int(t))
	var done_elite_tiers: Array = []
	var living_elite_tiers: Dictionary = {}
	for enemy: Node in get_tree().get_nodes_in_group("elite_enemies"):
		if is_instance_valid(enemy) and enemy.get("is_dead") != true:
			living_elite_tiers[int(enemy.get_meta("spawn_tier", enemy.get("_current_tier")))] = true
	for t in _elite_spawned_tiers.keys():
		if not living_elite_tiers.has(int(t)):
			done_elite_tiers.append(int(t))
	return {"boss_tiers": done_boss_tiers, "elite_tiers": done_elite_tiers, "final_spawned": _final_spawned, "final_gate_opened": _final_gate_opened,
		"run_phase": _run_phase, "held_total": _held_total, "spawn_tier": _spawn_tier, "announced_tier": _announced_tier,
		"endless_start": _endless_start_time, "endless_layer": _endless_layer, "endless_bosses": _endless_bosses_spawned.keys(),
		"endless_elite": _endless_elite_spawned.keys()}


## export_handover'ın tersi (yeni host'un Main'inde, oyun saati geri yüklendikten SONRA). Final: koşu zaferden önceyse bosslar yeni Main'de yok
## -> Final yeniden doğar (_final_spawned false); zaferden sonraysa (VICTORY/ENDLESS) bayrak kalır.
func import_handover(d: Dictionary) -> void:
	for t in d.get("boss_tiers", []):
		_boss_tiers_spawned[int(t)] = true
	for t in d.get("elite_tiers", []):
		_elite_spawned_tiers[int(t)] = true
	_run_phase = int(d.get("run_phase", RunPhase.NORMAL))
	_final_gate_opened = bool(d.get("final_gate_opened", false))
	_final_spawned = bool(d.get("final_spawned", false)) and _run_phase != RunPhase.NORMAL
	_held_total = float(d.get("held_total", 0.0))
	## (Varsayılan değerleri .get'in içinde hesaplama: _current_tier() -> _tier_time() _held_total'ı game_time'a göre sıfırlayabilir.)
	_spawn_tier = maxi(1, int(d["spawn_tier"])) if d.has("spawn_tier") else _current_tier()
	_announced_tier = maxi(1, int(d["announced_tier"])) if d.has("announced_tier") else _spawn_tier
	_endless_start_time = float(d.get("endless_start", 0.0))
	_endless_layer = int(d.get("endless_layer", 0))
	for k in d.get("endless_bosses", []):
		_endless_bosses_spawned[int(k)] = true
	for k in d.get("endless_elite", []):
		_endless_elite_spawned[int(k)] = true
	if _run_phase == RunPhase.VICTORY:
		_reopen_victory_window.call_deferred()


## Zafer penceresi açıkken host düştüyse yeni host'un penceresi de açılsın ("Sonsuza Devam Et" kararı host'ta).
func _reopen_victory_window() -> void:
	NetworkManager.victory_reached.emit(GameManager.game_time)


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
		_rpc_client_spawn_creature.rpc_id(peer_id, creature_id, enemy.global_position, enemy_tier, is_boss_enemy, net_id, false,
				enemy.get("is_elite") == true, int(enemy.get_meta("mp_player_count", 0)))
		## ÇOK OYUNCULU DÜZELTME (2026-09-24 senkron analizi): istemci maks can/kalkanı kendisi hesaplıyor, ama sonradan
		## katılan oyuncu için bu hesap ŞİMDİKİ oyun saati (Kademe 3+ zamanla artan can) ve ŞİMDİKİ oyuncu sayısıyla
		## yapılıyor - eski yaratıkların barı dolu can'da bile boş görünüyordu. Host'un gerçek değerleri + görünmez hayalet
		## durumu ayrıca gönderilir (aynı düğümden reliable RPC'ler sırayla varır).
		_rpc_client_catchup_enemy_state.rpc_id(peer_id, net_id, float(enemy.max_health), float(enemy.item_shield_max),
				enemy.get("is_ability_invisible") == true)
		if enemy.has_method("send_catchup_to_peer"):
			enemy.send_catchup_to_peer(peer_id) ## uzuvun türü + görünen pozu (worm_limb.gd)
	## Koşunun evresi (zafer penceresi açık mı / sonsuz kat kaç / en yüksek kademe) - bkz. NetworkManager.sync_run_phase_state.
	NetworkManager.sync_run_phase_state.rpc_id(peer_id, _run_phase != RunPhase.NORMAL, _run_phase == RunPhase.ENDLESS,
			_endless_layer, _announced_tier)


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
	_announced_tier = mini(1 + int(_tier_time() / tier_duration), FINAL_TIER) ## yeni host geçmiş Kademeleri yeniden duyurmasın
	_spawn_tier = _current_tier() ## kapı (bkz. KADEME KAPISI): yeni host'ta eski kademenin sayımı yok, kademe başlamış sayılır
	for tier in _active_boss_tiers().keys():
		var trigger_time: float = (tier - 1) * tier_duration + tier_duration * boss_trigger_fraction
		if t >= trigger_time:
			_boss_tiers_spawned[tier] = true
	var final_trigger_time: float = (FINAL_TIER - 1) * tier_duration
	if t >= final_trigger_time:
		_final_spawned = true
		_final_gate_opened = true
	## Elit: hâlâ yaşayan elitlerin kademeleri "doğdu" sayılır (yeni host aynı kademede ikinci bir elit doğurmasın).
	for enemy: Node in get_tree().get_nodes_in_group("elite_enemies"):
		if is_instance_valid(enemy):
			_elite_spawned_tiers[int(enemy.get_meta("spawn_tier", enemy.get("_current_tier")))] = true


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

	## Kademe bildirimi: spawn kapılarından (içerideyken spawn durur) ÖNCE - Kademe saati oyuncular evdeyken de akar.
	if not NetworkManager.is_multiplayer_active or NetworkManager.is_host:
		_check_tier_announcement()
		## Zafer/sonsuz kat da aynı sebeple (oyuncular evdeyken de saat akar, bkz. ZAFER + SONSUZ MOD bloğu) spawn kapılarından önce.
		_check_victory()
		_process_endless()

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
			## Host devri için gizli sayaçlar ~2 sn'de bir herkese (bkz. export_handover)
			_handover_timer += 0.15
			if _handover_timer >= 2.0:
				_handover_timer = 0.0
				NetworkManager.publish_host_handover({"spawner": export_handover()})
			# Sync game time so clients use the same difficulty scaling as host.
			NetworkManager.sync_game_time.rpc(GameManager.game_time)

	if DEBUG_RAMP_TEST_ENABLED and _debug_ramp_elapsed < DEBUG_RAMP_TEST_SECONDS:
		_debug_ramp_elapsed += delta

	## Debug modu (kullanıcı isteği: "düşman spawnlarını aktif/kapalı" - bkz. GameManager.
	## debug_enemy_spawns_enabled notu) - bu satırdan yukarısı zaten host-authoritative kapının
	## İÇİNDE (bkz. fonksiyon başındaki "sadece host" erken dönüşü), o yüzden host kapatınca
	## herkes için gerçekten kapanmış olur.
	if GameManager.debug_enemy_spawns_enabled and _run_phase != RunPhase.VICTORY: ## zafer penceresi açıkken doğuş durur
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _current_interval()
			_spawn_regular_enemy()

		## Boss/Final/sonsuz boss dalgası tetikleri çeyrek saniyede bir bakılır: kapı kapalıyken (en çok GATE_MAX_WAIT_MSEC) bunlar
		## _resolve_spawn_tier -> _older_tier_survivor_count ile "enemies" grubunu tarıyordu ve her karede çalışıyordu (CLAUDE.md
		## #9b). Tetikler saniye mertebesinde zaman eşikleri - 0.25 sn gecikme fark edilmez. İlk karede hemen çalışır.
		_gate_check_accum += delta
		if _gate_check_accum >= GATE_CHECK_SECONDS:
			_gate_check_accum = 0.0
			_check_boss_tiers()
			_check_final_tier()
			_check_endless_boss_wave()


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
	_enemy_sync_tick = (_enemy_sync_tick + 1) & 0xFFFF

	## Sadece oyunda VE Main'i hazır peer'lere (bkz. NetworkManager.game_ready_peers): yüklemedeki geri katılana / lobideki yabancıya yağmasın.
	for pid in NetworkManager.game_ready_peers():
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
		## Küçük paketler halinde gönder (2026-10-02, Epic internet odası): 100+ yaratık tek pakette ~10 KB ediyordu; Epic
		## P2P bunu ~10 parçaya bölmek zorunda ve "güvenilmez" pakette TEK parça kaybı tüm turu düşürüyordu. Her paket kendi
		## başına işlenir (kayıp sadece o grubu etkiler); LAN'da da aynı şekilde daha dayanıklı.
		for i in range(0, states.size(), ENEMY_SYNC_BATCH):
			_sync_enemy_positions.rpc_id(peer_id, _enemy_sync_tick, EnemySyncCodecScript.encode(_enemy_sync_tick, states.slice(i, i + ENEMY_SYNC_BATCH)))

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
	var tier: int = 1 + int(_tier_time() / tier_duration)
	return clamp(tier, 1, 15)


## Kademe bildirimi (kullanıcı isteği 2026-10-04): Kademe saati (boss kapısı dahil - _tier_time) yeni bir Kademe'ye geçince
## host numarayı herkese yayar (NetworkManager.broadcast_creature_tier_reached -> main.gd toast). Final Kademe (16) de
## kendi numarasıyla gelir (_current_tier 15'te kısıldığı için burada ham değer okunur).
## KULLANICI İSTEĞİ (2026-10-05): "kademe atlamaları önceki kademenin yaratıkları tamamen öldüğünde başlamalı" - bir Kademe artık
## SAAT dolunca değil, KAPI açılınca (önceki kademenin yaratıkları ölünce, bkz. KADEME KAPISI bloğu) başlar: bildirim, yeni roster,
## o kademenin bossu ve Final hep kapıya bağlı. Saat (_tier_time) yine akar; sadece "başlama" bekler.
var _announced_tier: int = 1
var _announce_poll_msec: int = 0
const ANNOUNCE_POLL_MSEC := 250 ## kapı beklerken ölü sayımı en çok bu aralıkla yenilenir (her karede yaratık taramasın)
const GATE_CHECK_SECONDS := 0.25 ## _process'te boss/Final/sonsuz boss dalgası tetiklerinin bakış aralığı (bkz. _process)
var _gate_check_accum: float = GATE_CHECK_SECONDS ## ilk karede hemen bak


func _check_tier_announcement() -> void:
	var top_tier: int = FINAL_TIER if GameManager.bosses_enabled else FINAL_TIER - 1 ## Final kapalıyken "Kademe XVI" bildirimi yok
	var time_tier: int = mini(1 + int(_tier_time() / tier_duration), top_tier)
	if time_tier < _announced_tier: ## yeni oyun: saat sıfırlandı
		_announced_tier = time_tier
		_spawn_tier = mini(_spawn_tier, _current_tier())
		_final_gate_opened = false
		_gate_wait_started_msec = 0
		_final_gate_wait_started_msec = 0
		return
	var now_msec: int = Time.get_ticks_msec()
	if (_gate_wait_started_msec != 0 or _final_gate_wait_started_msec != 0) and now_msec - _announce_poll_msec < ANNOUNCE_POLL_MSEC:
		return
	_announce_poll_msec = now_msec
	_resolve_spawn_tier() ## kapı açıksa _spawn_tier zaman kademesine yetişir
	_gate_rush_tick()
	var started: int = _spawn_tier
	if GameManager.bosses_enabled and time_tier >= FINAL_TIER and _final_gate_open():
		started = FINAL_TIER
	if started > _announced_tier:
		_announced_tier = started
		NetworkManager.broadcast_creature_tier_reached.rpc(started)


## ==============================================================================
## KADEME BOSS KAPISI (kullanıcı isteği: "mevcut kademenin boss'unu öldürmeden diğer kademeye atlanmamalı")
## Kademe (roster, ölçekleme, sonraki bossların ve Final Kademe'nin tetik zamanı) artık ham game_time'a değil,
## _tier_time()'a bağlı: game_time ile birlikte akar AMA bir kademenin (BOSS_TIERS) boss'u/bosslarından biri
## HÂLÂ SAĞKEN o kademenin bitiş sınırında (kademe N için N * tier_duration) DURUR - boss(lar) ölene kadar
## kademe N'de kalınır (yeni kademenin yaratıkları, sonraki kademenin bossu, Final gelmez), ölünce saat kaldığı
## yerden devam eder (kademe atlamaz, birden fazla kademe birden atlanmaz). Boss sınırdan ÖNCE öldürülürse
## hiçbir şey değişmez. Boss hiç doğmadıysa (ör. spawn anında canlı oyuncu çapası yoktu) tutulacak boss da yok,
## kapı açık kalır (oyun kilitlenmez). Oyun süresi/zorluk ramp'i (game_time) etkilenmez, sadece Kademe saati.
## ==============================================================================
const TIER_HOLD_EPSILON := 0.001
var _tier_bosses: Dictionary = {} ## kademe -> o kademenin doğan boss node'ları
var _held_total: float = 0.0 ## Kademe saatinin bosslar yüzünden geride tutulduğu toplam süre (sn)


func _tier_boss_alive(tier: int) -> bool:
	for b in _tier_bosses.get(tier, []):
		if is_instance_valid(b) and b.get("is_dead") != true:
			return true
	return false


## Kademe saati: game_time - bosslar yüzünden tutulan süre. Her çağrıda (ucuz: en fazla 5 kademe) sınır kontrol
## edildiği için çağıran hangi karede olursa olsun tutarlı sonuç alır.
func _tier_time() -> float:
	var effective: float = GameManager.game_time - _held_total
	if effective < 0.0: ## yeni oyun: game_time sıfırlandı
		_held_total = 0.0
		effective = GameManager.game_time
	for tier in _tier_bosses.keys():
		if not _tier_boss_alive(int(tier)):
			continue
		var boundary: float = float(tier) * tier_duration - TIER_HOLD_EPSILON
		if effective > boundary:
			_held_total += effective - boundary
			effective = boundary
	return effective


## Kademe şu an sağ bir boss yüzünden bekletiliyor mu (HUD/test için).
func is_tier_held_by_boss() -> bool:
	var effective: float = _tier_time()
	for tier in _tier_bosses.keys():
		if _tier_boss_alive(int(tier)) and effective >= float(tier) * tier_duration - TIER_HOLD_EPSILON * 2.0:
			return true
	return false


func _player_count() -> int:
	return NetworkManager.game_player_count()


## DÜZELTME (kullanıcı bildirimi: "Yaratıklar ilk tierlarda çok gereksiz
## kalabalık geliyor kalabalıklaşma olayı ilerleyen tierlarda artsın") - eski
## tavan (max_concurrent_enemies + oyuncu başı ekstra) Kademe 1'den itibaren
## SABİTTİ, yani ilk dakikalarda bile ekran 150 yaratığa kadar dolabiliyordu.
## Artık bu tavan Kademe 1'de TIER_1_CAP_SCALE oranına sıkışıyor ve Kademe
## 15'e kadar doğrusal olarak tam tavana çıkıyor - kalabalıklaşma artık
## erken değil, geç oyunda hissediliyor.
## SONRAKİ TUR (kullanıcı bildirimi 2026-09-24: "Yaratıklar çok hızlı artıyor daha yavaş zorlanmalı oyun") -
## 0.35 -> 0.25 (solo oyun başında 70 -> 50 yaratık) VE tavan artık Kademe sınırlarında basamak basamak
## zıplamıyor: Kademe saatine (_tier_time, boss kapısında durur) göre SÜREKLİ büyüyor, Kademe 15'in başında
## (14 x tier_duration) tam tavana ulaşıyor. Nihai tavan (max_concurrent_enemies) değişmedi.
const TIER_1_CAP_SCALE := 0.25

func _tier_crowding_scale() -> float:
	var progress: float = clampf(_tier_time() / (14.0 * tier_duration), 0.0, 1.0)
	return lerp(TIER_1_CAP_SCALE, 1.0, progress)

func _scaled_enemy_cap() -> int:
	## bkz. DEBUG_RAMP_TEST_ENABLED üstündeki GEÇİCİ TEST notu - Kademe 1'in
	## kasıtlı TIER_1_CAP_SCALE (0.35) kısıtlaması olmasa 200 hedefine hiç
	## ulaşılamazdı (Kademe 1 süresi 100sn, test penceresi 60sn - tier hiç
	## ilerlemeden 200'e çıkmak isteniyor). Test penceresinde bu kısıtlama
	## BİLEREK atlanıyor, kalıcı davranış DEĞİL.
	if DEBUG_RAMP_TEST_ENABLED and _debug_ramp_elapsed < DEBUG_RAMP_TEST_SECONDS:
		return DEBUG_RAMP_TEST_TARGET
	return max(1, int(round(player_enemy_cap(_player_count()) * _tier_crowding_scale())))


## Oyuncu sayısına göre NİHAİ (Kademe 15) yaratık tavanı: 1->250, 2->300, 3->350, 4->400, 5->450 (2026-10-04, bkz.
## max_concurrent_enemies notu). Erken kademelerde bu tavan _tier_crowding_scale ile ayrıca kısılır (değişmedi).
## Yaratık canı/kalkanı oyuncu sayısından BAĞIMSIZ olarak ayrı ölçeklenir - burası sadece sayı.
func player_enemy_cap(players: int) -> int:
	return maxi(1, max_concurrent_enemies + (maxi(1, players) - 1) * ENEMY_CAP_PER_EXTRA_PLAYER)


func _current_interval() -> float:
	## bkz. DEBUG_RAMP_TEST_ENABLED üstündeki GEÇİCİ TEST notu.
	if DEBUG_RAMP_TEST_ENABLED and _debug_ramp_elapsed < DEBUG_RAMP_TEST_SECONDS:
		return DEBUG_RAMP_TEST_SECONDS / float(DEBUG_RAMP_TEST_TARGET)
	var t: float = GameManager.game_time
	var solo_interval: float = max(min_interval, base_interval - t * difficulty_ramp)
	var player_multiplier: float = 1.0 + float(_player_count() - 1) * EXTRA_PLAYER_SPAWN_RATE
	return max(min_interval * 0.65, solo_interval / player_multiplier) / SPAWN_RATE_MULT


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
			## Yerde yatan uzak oyuncu (kuklada is_dead=false gelir, bkz. main.gd state_snapshot) yerel oyuncuyla AYNI
			## kuralla sayılmaz - host kendi yerdeki oyuncusunu is_dead ile zaten dışlıyordu (çok oyunculu senkron
			## denetimi 2026-09-25; Suriyeli Hadime'nin gezen hayaleti de böylece spawn çapası olmaz).
			if not is_instance_valid(rp) or rp.get("is_dead") == true or rp.get("is_downed") == true:
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
			## Yerde yatan uzak oyuncu (kuklada is_dead=false gelir, bkz. main.gd state_snapshot) yerel oyuncuyla AYNI
			## kuralla sayılmaz - host kendi yerdeki oyuncusunu is_dead ile zaten dışlıyordu (çok oyunculu senkron
			## denetimi 2026-09-25; Suriyeli Hadime'nin gezen hayaleti de böylece spawn çapası olmaz).
			if not is_instance_valid(rp) or rp.get("is_dead") == true or rp.get("is_downed") == true:
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


## ==============================================================================
## KADEME KAPISI (kullanıcı isteği: "Kademe ilerlemelerinde öldüremediğim yaratıkların yerini yeni kademe
## yaratıklar alıyor, eskilerini öldürmeden yeni kademedekilerin gelememesi lazım")
## Kademe zamana göre ilerler (_current_tier) ama SPAWN kademesi (_spawn_tier) ona ancak önceki kademelerin
## SAĞ KALAN normal yaratıkları öldürülünce yetişir. Kapı kapalıyken yeni yaratık HİÇ doğmaz (eski kademeyi
## sonsuz doğurmak temizlemeyi imkânsız kılardı); son yaratık ölünce yeni kademenin listesiyle spawn başlar.
## Bosslar bu kapıya tabi DEĞİL: kendi zaman tetikleyicileriyle (BOSS_TIERS/FINAL_TIER) gelmeye devam eder ve
## sağ kalan bir boss kapıyı tutmaz. Oyun süresi/boss zamanlaması hiçbir zaman durmaz - en kötü ihtimalle
## (ör. ulaşılamayan tek bir eski yaratık) yeni yaratık gelmez, oyun kilitlenmez.
## Sağ kalan yaratık "spawn_tier" meta'sıyla (bkz. _spawn_regular_enemy) işaretlenir; meta'sı olmayanlar
## (bosslar, sonradan çağrılanlar, test yaratıkları) saymaz.
## ==============================================================================
var _spawn_tier: int = 1

## KULLANICI BİLDİRİMİ: "bazen seyyar satıcı spawnlandığında veya kademe atlandığında yaratıklar spawnlanmamaya başlıyor".
## KÖK NEDEN (Kademe kapısı, yukarıdaki not): kapı, eski kademeden sağ kalan HER yaratık ölene kadar kapalı kalıyordu.
## Kademe geçişinde ekranda hep onlarca eski yaratık vardır; biri bile ulaşılamaz/uzakta takılı kalırsa (satıcı bariyerinin
## kenarında, oyuncular bölgeye girip onu hedef dışı bırakınca terk edilmiş, duvar dibinde sıkışmış, çok uzağa savrulmuş...)
## kapı SÜRESİZ kapalı kalıp hiçbir yeni yaratık doğmuyordu - üstelik tek kalan yaratığın nerede olduğunu oyuncu göremiyor.
## İki güvenlik eklendi (kapının asıl amacı - "eskiler temizlenmeden yenileri gelmesin" - yakındaki yaratıklar için aynen duruyor):
##  1) SADECE herhangi bir canlı oyuncunun GATE_SURVIVOR_RADIUS'u içindeki eski yaratıklar kapıyı tutar; çok uzaktakiler sayılmaz.
##  2) Kapı en fazla GATE_MAX_WAIT_MSEC bekler; süre dolunca (kimse öldürmese bile) yeni kademe için açılır.
## 2026-10-05: kullanıcı "kademe, önceki kademenin yaratıkları TAMAMEN öldüğünde başlamalı" dedi; 30 sn'lik bekleme sınırı kalabalık
## bir kademeyi temizlemeye yetmiyordu (kademe yaratıklar sağken başlıyordu) -> 90 sn. Uzaktakiler/ulaşılamazlar için güvenlik hâlâ var.
const GATE_SURVIVOR_RADIUS := 1600.0
const GATE_MAX_WAIT_MSEC := 90000
var _gate_wait_started_msec: int = 0

## 2026-10-06 KULLANICI BİLDİRİMİ: "kademe aralarında yaratıklar bi anda gelmemeye başlıyor". Kök neden (ölçüldü, headless gerçek akış): kapı
## kapalıyken HİÇ yaratık doğmuyor ve kapıyı tutanlar hep oyuncunun GÖRÜŞ ALANI DIŞINDA (görüş ~250x350 px, doğuş halkası 480-840 px)
## yavaş (~40 px/sn) yürüyen eski kademe yaratıkları: oyuncu görmediği/vuramadığı yaratığı bekliyor, boş geçen süre onların yürüme süresi
## (kusursuz öldürücüyle bile ~8 sn, gerçek oyunda çok daha uzun). Düzeltme: kapı GATE_RUSH_DELAY_MSEC'ten uzun beklerse kapıyı tutan,
## HİÇBİR oyuncunun görüş elipsinde olmayan eski yaratıklar GATE_RUSH_SPEED_MULT kat hızlı yaklaşır; görüşe girince normal hıza döner
## (oyuncu hızlanmış yaratık görmez, sadece yürüme süresi kısalır). Kapı açılınca/zaman aşımında hepsi sıfırlanır. Kural (eskiler
## ölmeden yeni kademe başlamaz) aynı; sadece boş süre kısalır. Hız, C++ "rage" çarpan kanalından gider (enemy.gd set_gate_rush).
const VisionFogScript := preload("res://scripts/vision_fog.gd")
const GATE_RUSH_DELAY_MSEC := 1000
const GATE_RUSH_SPEED_MULT := 3.0
const GATE_RUSH_VISION_MARGIN := 1.3 ## görüş elipsinin (normalleştirilmiş 1.0) bu kadar katından uzaktakiler hızlanır
var _gate_rush_active: bool = false


## Kapı beklerken kapıyı tutan, görüş dışındaki eski yaratıkları hızlandırır; bekleme bitince (ya da hiç yokken) hızları sıfırlar.
## _check_tier_announcement'tan çağrılır (kapı beklerken 250 ms'de bir, bekleme yokken her kare ama hemen çıkar).
func _gate_rush_tick() -> void:
	var now_msec: int = Time.get_ticks_msec()
	var wait_started: int = _gate_wait_started_msec if _gate_wait_started_msec != 0 else _final_gate_wait_started_msec
	var waiting: bool = wait_started != 0 and now_msec - wait_started >= GATE_RUSH_DELAY_MSEC
	if not waiting and not _gate_rush_active:
		return
	var gate_tier: int = _current_tier()
	if _gate_wait_started_msec == 0 and _final_gate_wait_started_msec != 0:
		gate_tier = FINAL_TIER ## Final kapısı: 1-15. kademenin hepsi eski sayılır (bkz. _final_gate_open)
	var anchors: Array[Vector2] = _living_player_positions()
	var vision_r: float = VisionFogScript.current_radius(get_tree())
	var any_rushed: bool = false
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("set_gate_rush"):
			continue
		var want: float = 1.0
		if waiting and e.get("is_dead") != true and not e.is_in_group("boss"):
			var t: int = int(e.get_meta("spawn_tier", 0))
			if t > 0 and t < gate_tier and not anchors.is_empty():
				var holds_gate: bool = false ## _older_tier_survivor_count ile aynı: bir oyuncunun GATE_SURVIVOR_RADIUS'u içinde
				var in_sight: bool = false
				for ap: Vector2 in anchors:
					var off: Vector2 = (e as Node2D).global_position - ap
					if off.length_squared() <= GATE_SURVIVOR_RADIUS * GATE_SURVIVOR_RADIUS:
						holds_gate = true
					if VisionFogScript.normalized_distance(off, vision_r, VisionFogScript.VISION_WIDTH_SCALE) <= GATE_RUSH_VISION_MARGIN:
						in_sight = true
				if holds_gate and not in_sight:
					want = GATE_RUSH_SPEED_MULT
					any_rushed = true
		e.set_gate_rush(want)
	_gate_rush_active = any_rushed


## Canlı TÜM oyuncuların (yerel + uzak; ev içi/satıcı bölgesi dahil) dünya konumları - kapının "yakınlık" ölçütü için.
func _living_player_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var local_p: Node = get_tree().get_first_node_in_group("player")
	if local_p and is_instance_valid(local_p) and local_p.get("is_dead") != true:
		out.append((local_p as Node2D).global_position)
	if NetworkManager.is_multiplayer_active:
		for rp: Node in get_tree().get_nodes_in_group("remote_players"):
			if is_instance_valid(rp) and rp.get("is_dead") != true:
				out.append((rp as Node2D).global_position)
	return out


func _older_tier_survivor_count(time_tier: int) -> int:
	var n: int = 0
	var anchors: Array[Vector2] = _living_player_positions()
	var radius_sq: float = GATE_SURVIVOR_RADIUS * GATE_SURVIVOR_RADIUS
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true or e.is_in_group("boss"):
			continue
		var t: int = int(e.get_meta("spawn_tier", 0))
		if t > 0 and t < time_tier:
			## Hiçbir oyuncunun yakınında olmayan yaratık kapıyı tutmaz (oyuncu listesi boşsa - ör. testler - hepsi sayılır).
			if not anchors.is_empty():
				var near: bool = false
				for ap in anchors:
					if ap.distance_squared_to((e as Node2D).global_position) <= radius_sq:
						near = true
						break
				if not near:
					continue
			n += 1
	return n


## Şu an spawn'da kullanılacak kademe; kapı kapalıysa (eski kademeden yakında sağ kalan var) 0.
func _resolve_spawn_tier() -> int:
	var time_tier: int = _current_tier()
	if _spawn_tier < time_tier:
		if _older_tier_survivor_count(time_tier) == 0:
			_spawn_tier = time_tier
			_gate_wait_started_msec = 0
		else:
			var now_msec: int = Time.get_ticks_msec()
			if _gate_wait_started_msec == 0:
				_gate_wait_started_msec = now_msec
			elif now_msec - _gate_wait_started_msec >= GATE_MAX_WAIT_MSEC:
				_spawn_tier = time_tier ## zaman aşımı: eski yaratıklar yüzünden spawn asla durmasın
				_gate_wait_started_msec = 0
	else:
		_gate_wait_started_msec = 0
	if _final_pending():
		return 0 ## Final, 15. kademenin son yaratığını bekliyor: yeni yaratık doğmaz (yoksa sayım hiç sıfırlanmazdı)
	return _spawn_tier if _spawn_tier >= time_tier else 0


## FİNAL KAPISI: Final Kademe (16) de diğer kademeler gibi önceki kademelerin (1-15) sağ kalan yaratıkları ölünce başlar.
## Bekleme süresince _resolve_spawn_tier yeni yaratık doğurmaz; aynı güvenlik (yakınlık süzgeci + GATE_MAX_WAIT_MSEC) geçerli.
var _final_gate_opened: bool = false
var _final_gate_wait_started_msec: int = 0


func _final_pending() -> bool:
	if not GameManager.bosses_enabled:
		return false ## Final yok: yeni yaratık doğumu 15. kademeden sonra durmaz
	return not _final_gate_opened and not _final_spawned and _tier_time() >= (FINAL_TIER - 1) * tier_duration


func _final_gate_open() -> bool:
	if _final_gate_opened or _final_spawned:
		return true
	if _tier_time() < (FINAL_TIER - 1) * tier_duration:
		return false
	if _older_tier_survivor_count(FINAL_TIER) == 0:
		_final_gate_opened = true
		_final_gate_wait_started_msec = 0
		return true
	var now_msec: int = Time.get_ticks_msec()
	if _final_gate_wait_started_msec == 0:
		_final_gate_wait_started_msec = now_msec
	elif now_msec - _final_gate_wait_started_msec >= GATE_MAX_WAIT_MSEC:
		_final_gate_opened = true
		_final_gate_wait_started_msec = 0
		return true
	return false


## Yeni kademe şu an eski kademenin sağ kalanlarını mı bekliyor (HUD/test için).
func is_tier_gate_waiting() -> bool:
	var time_tier: int = _current_tier()
	return _spawn_tier < time_tier and _older_tier_survivor_count(time_tier) > 0


## Spawn çapası olabilecek TÜM canlı, dışarıdaki oyuncular (yerel + uzak) - bkz. _find_any_living_player_anchor
## (aynı "içerideki/satıcı bölgesindeki oyuncu dışarıda sayılmaz" kuralı).
func _outdoor_living_players() -> Array[Node]:
	var out: Array[Node] = []
	var local_p: Node = get_tree().get_first_node_in_group("player")
	if local_p and is_instance_valid(local_p) and local_p.get("is_dead") != true:
		var indoors: bool = local_p.has_method("is_indoors_now") and local_p.is_indoors_now()
		var in_zone: bool = local_p.has_method("is_in_merchant_zone_now") and local_p.is_in_merchant_zone_now()
		if not indoors and not in_zone:
			out.append(local_p)
	if NetworkManager.is_multiplayer_active:
		for rp: Node in get_tree().get_nodes_in_group("remote_players"):
			## Yerde yatan uzak oyuncu (kuklada is_dead=false gelir, bkz. main.gd state_snapshot) yerel oyuncuyla AYNI
			## kuralla sayılmaz - host kendi yerdeki oyuncusunu is_dead ile zaten dışlıyordu (çok oyunculu senkron
			## denetimi 2026-09-25; Suriyeli Hadime'nin gezen hayaleti de böylece spawn çapası olmaz).
			if not is_instance_valid(rp) or rp.get("is_dead") == true or rp.get("is_downed") == true:
				continue
			var rp_indoors: bool = rp.get("is_indoors") if "is_indoors" in rp else false
			var rp_zone: bool = rp.get("is_in_merchant_zone") if "is_in_merchant_zone" in rp else false
			if not rp_indoors and not rp_zone:
				out.append(rp)
	return out


## Kullanıcı isteği: "önünü kesmeye çalışsınlar oyuncuların" (çoğul) - birden fazla dışarıdaki oyuncu varsa
## her spawn için biri rastgele seçilir, böylece baskı sadece host'un karakterine değil herkese dağılır.
## Tek oyuncu / kimse dışarıda değilse eski davranış (_find_any_living_player_anchor).
func _pick_spawn_anchor() -> Node:
	var candidates: Array[Node] = _outdoor_living_players()
	if candidates.size() > 1:
		return candidates[randi() % candidates.size()]
	return _find_any_living_player_anchor()


## Pusu noktası: center'dan bias_dir yönünde, oyuncuyla arasında bir orman duvarı olan (düz çizgi duvara
## çarpan) serbest bir konum. Bulunamazsa null (çağıran normal spawn'a düşer).
func _ambush_spawn_position(center: Vector2, bias_dir: Vector2) -> Variant:
	var half_arc: float = deg_to_rad(AMBUSH_ARC_DEG) * 0.5
	for _attempt in range(AMBUSH_ATTEMPTS):
		var angle: float = bias_dir.angle() + randf_range(-half_arc, half_arc)
		var dist: float = randf_range(min_spawn_distance, max_spawn_distance + AMBUSH_EXTRA_DISTANCE)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		if GameManager.is_position_blocked_by_terrain(pos):
			continue
		if EnemyPathingScript.line_blocked(center, pos):
			return pos
	return null


## Paketin i. üyesinin konumu: 0. üye pusu noktasının kendisi, diğerleri çevresinde dar bir kümede.
func _ambush_pack_member_position(base: Vector2, index: int) -> Vector2:
	if index == 0:
		return base
	for _attempt in range(6):
		var candidate: Vector2 = base + Vector2.from_angle(randf() * TAU) * randf_range(20.0, AMBUSH_PACK_SPREAD)
		if not GameManager.is_position_blocked_by_terrain(candidate):
			return candidate
	return base


func _spawn_regular_enemy() -> void:
	var anchor: Node = _pick_spawn_anchor()
	if not anchor:
		return
	var anchor_pos: Vector2 = anchor.global_position
	var bias_dir: Vector2 = _anchor_movement_direction(anchor)

	## Kademe kapısı (bkz. yukarıdaki not): eski kademeden sağ kalan varken yeni yaratık doğmaz.
	var tier: int = _resolve_spawn_tier()
	if tier <= 0:
		return
	var roster: Array = _spawnable_roster(tier)
	if roster.is_empty():
		return
	## Sonsuz modda roster 15'te kalır ama istatistik kademesi katla büyür (bkz. ZAFER + SONSUZ MOD bloğu); normalde scale_tier == tier.
	var scale_tier: int = _scale_tier_for(tier)
	## kullanıcı isteği: "karakter çok güçlüyse normalden daha fazla
	## spawnlansın" - bkz. _power_extra_spawn_count üstündeki not.
	var spawn_count: int = 1 + _power_extra_spawn_count()
	## Pusu paketi (bkz. AMBUSH_PACK_CHANCE): oyuncu hareket ediyorsa ve gittiği yönde duvar-arkası uygun bir
	## nokta varsa tek yaratık yerine 2-4 kişilik bir küme orada doğar.
	var ambush_pos: Variant = null
	if bias_dir != Vector2.ZERO and randf() < AMBUSH_PACK_CHANCE:
		ambush_pos = _ambush_spawn_position(anchor_pos, bias_dir)
		if ambush_pos != null:
			spawn_count += randi_range(AMBUSH_PACK_MIN, AMBUSH_PACK_MAX) - 1
	for i in range(spawn_count):
		if get_tree().get_nodes_in_group("enemies").size() >= _scaled_enemy_cap():
			return
		## ELİT önce atılır: elitse yaratık kimliği ELİT HAVUZUNDAN (eski bosslar) seçilir, değilse roster'dan.
		var elite: bool = _roll_elite_for(tier)
		var elite_ids: Array = elite_candidates(tier) if elite else []
		var id: String = (elite_ids[randi() % elite_ids.size()] if elite else roster[randi() % roster.size()])
		var spawn_pos: Vector2
		if ambush_pos != null:
			spawn_pos = _ambush_pack_member_position(Vector2(ambush_pos), i)
		else:
			spawn_pos = _random_spawn_position(anchor_pos, false, bias_dir)
		var network_id: int = _next_network_enemy_id
		_next_network_enemy_id += 1
		var enemy = _spawn_creature(id, spawn_pos, network_id)
		if not enemy:
			if elite:
				_unroll_elite(tier)
			continue
		enemy.set_meta("spawn_tier", tier) ## bkz. Kademe kapısı notu (_older_tier_survivor_count) - ROSTER kademesi, ölçek değil
		if enemy.has_method("apply_tier_scaling"):
			enemy.apply_tier_scaling(scale_tier)
		_enable_regular_shield(enemy, tier)
		# Global güçlendirme - tier scaling SONRASI uygulanır (zaten ölçeklenmiş
		# değerlerin üstüne eklenir, katlanarak büyümez)
		_apply_global_buff(enemy)
		if elite:
			_apply_elite(enemy)

		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			## İstemci istatistiği bu sayıdan hesaplıyor (apply_tier_scaling) - sonsuzda host'la AYNI ölçek kademesi gitmeli.
			_announce_spawn(enemy, id, spawn_pos, scale_tier, false, network_id, false, elite)



## Şu an doğabilecek kademe bossları: bosses_enabled kapalıyken sadece yeni bosslar (NEW_BOSS_TIERS), açıkken eski tablo (BOSS_TIERS).
func _active_boss_tiers() -> Dictionary:
	return BOSS_TIERS if GameManager.bosses_enabled else NEW_BOSS_TIERS


func _check_boss_tiers() -> void:
	var boss_tiers: Dictionary = _active_boss_tiers()
	if boss_tiers.is_empty():
		return
	var t: float = _tier_time() ## Kademe saati (boss kapısı - bkz. _tier_time)
	_resolve_spawn_tier() ## Kademe kapısı: boss, kademesi BAŞLAMADAN (önceki kademenin yaratıkları ölmeden) doğmaz
	for tier in boss_tiers.keys():
		if _boss_tiers_spawned.has(tier) or _spawn_tier < int(tier):
			continue
		var trigger_time: float = (tier - 1) * tier_duration + tier_duration * boss_trigger_fraction
		if t >= trigger_time:
			_boss_tiers_spawned[tier] = true
			var spawned: Array = _spawn_boss_group(boss_tiers[tier], tier)
			if spawned.is_empty():
				_boss_tiers_spawned.erase(tier) ## hiç doğmadı (ör. o an canlı oyuncu çapası yoktu): sonraki bakışta yeniden dene


func _check_final_tier() -> void:
	if not GameManager.bosses_enabled:
		_check_auto_endless() ## boss/Final yok: Kademe XV bitince doğrudan sonsuz mod
		return
	if _final_spawned:
		return
	## 15. kademenin bossları ölmeden Final gelmez (bkz. _tier_time) VE 1-15. kademelerin yaratıkları ölmeden de gelmez (bkz. _final_gate_open)
	if _final_gate_open():
		_final_spawned = true
		var spawned: Array = _spawn_boss_group(FINAL_CREATURES, FINAL_TIER)
		if spawned.is_empty():
			_final_spawned = false ## hiç doğmadı (ör. o an canlı oyuncu çapası yoktu): sonraki karede yeniden dene - yoksa Final ve zafer hiç gelmezdi
		else:
			_final_bosses = spawned ## hepsi ölünce zafer (bkz. _check_victory)


## Doğan boss düğümlerini döner (boş = hiçbiri doğmadı).
func _spawn_boss_group(ids: Array, tier: int) -> Array:
	var anchor_pos = _find_any_living_player_position()
	if anchor_pos == null:
		return []
	var spawned_bosses: Array = []
	for id in ids:
		var network_id: int = _next_network_enemy_id
		_next_network_enemy_id += 1
		var enemy = _spawn_creature(id, _random_spawn_position(anchor_pos, true), network_id)
		if not enemy:
			continue
		spawned_bosses.append(enemy)
		enemy.add_to_group("boss")
		_setup_boss_enemy(enemy, id, tier) ## host ve istemci AYNI kurulum (bkz. _rpc_client_spawn_creature)
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			_announce_spawn(enemy, id, enemy.global_position, tier, true, network_id, true, false)
	## Kademe boss kapısı (bkz. _tier_time): bu kademenin bossları ölene kadar Kademe saati o kademenin
	## sonunda bekler. (Final Kademe'nin bossları kapıdan sonra gelir, tutulacak bir sonraki kademe yok.)
	if _active_boss_tiers().has(tier) and not spawned_bosses.is_empty():
		_tier_bosses[tier] = spawned_bosses
	if not spawned_bosses.is_empty():
		EventSfx.play(get_tree(), &"boss")
		CameraShakeScript.add_limited("boss_spawn", 0.45, 3.0) ## kamera sarsıntısı: boss geldi (bkz. camera_shake.gd)
	return spawned_bosses


## Host: yeni doğan yaratığı Main'i HAZIR istemcilere duyurur (bkz. NetworkManager.game_ready_peers - yükleme ekranındaki geri katılan ya da
## lobideki yabancı almaz; geri katılan yakalamayla hepsini birden alır). player_count: host'un o an kullandığı oyuncu sayısı.
func _announce_spawn(enemy: Node, id: String, pos: Vector2, tier: int, is_boss: bool, network_id: int, announce: bool, is_elite: bool) -> void:
	var player_count: int = int(enemy.get_meta("mp_player_count", 0))
	for pid in NetworkManager.game_ready_peers():
		_rpc_client_spawn_creature.rpc_id(int(pid), id, pos, tier, is_boss, network_id, announce, is_elite, player_count)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_catchup_enemy_state(network_id: int, max_hp: float, shield_max: float, invisible: bool) -> void:
	if not NetworkManager._from_host():
		return
	var enemy: Node = NetworkManager.find_enemy_by_net_id(network_id)
	if enemy == null or not is_instance_valid(enemy):
		return
	enemy.max_health = max_hp
	enemy.health = minf(float(enemy.health), max_hp)
	enemy.item_shield_max = shield_max
	enemy.item_shield_hp = minf(float(enemy.item_shield_hp), shield_max)
	enemy.health_changed.emit(enemy.health, enemy.max_health)
	enemy.item_shield_changed.emit(enemy.item_shield_hp, enemy.item_shield_max)
	if invisible and enemy.has_method("set_ability_invisible"):
		enemy.set_ability_invisible(true)


@rpc("any_peer", "call_remote", "reliable")
## announce: boss sesi çalsın mı - sonradan katılan oyuncuya hâlâ yaşayan bossları gönderen yakalama (catch-up) false geçer.
## is_elite: host bu yaratığı elit seçti (bkz. ELİT YARATIK bloğu) - istemci de AYNI _apply_elite'i çağırır.
func _rpc_client_spawn_creature(id: String, pos: Vector2, tier: int, is_boss: bool, network_id: int, announce: bool = false, is_elite: bool = false, player_count: int = 0) -> void:
	if not NetworkManager._from_host():
		return
	var enemy = _spawn_creature(id, pos, network_id)
	if not enemy:
		return
	if is_boss and announce:
		EventSfx.play(get_tree(), &"boss")
		CameraShakeScript.add_limited("boss_spawn", 0.45, 3.0) ## 13 bossun RPC'leri tek sarsıntı (host'ta aynı anahtar)
	if is_boss:
		enemy.add_to_group("boss")
		_setup_boss_enemy(enemy, id, tier, player_count)
	elif LIMB_IDS.has(id):
		return ## uzuv: kurulumu sahnede + worm_setup/worm_pose olaylarıyla (çarpan/kalkan/ödül yok)
	else:
		if enemy.has_method("apply_tier_scaling"):
			enemy.apply_tier_scaling(tier)
		_enable_regular_shield(enemy, tier)
		_apply_global_buff(enemy, player_count)
		if is_elite:
			_apply_elite(enemy)


## Boss kurulumu - host (_spawn_boss_group) ve istemci (_rpc_client_spawn_creature) AYNI işlevi çağırır (iki ayrı kopya, biri unutulursa istemci
## bossu farklı statla doğardı). Sıra: boss statı -> kalkan -> global çarpanlar -> (varsa) elle belirlenmiş nihai stat -> çubuk (çubuk SON, güncel canı okusun).
## player_count: istemci doğuşunda host'un oyuncu sayısı (0 = kendin hesapla, bkz. _apply_global_buff).
func _setup_boss_enemy(enemy: Node, id: String, tier: int, player_count: int = 0) -> void:
	var fixed: Dictionary = FIXED_BOSS_STATS.get(id, {})
	## Elle statlı bosslarda zincir referans bossun taban statıyla çalışır: ödül (altın/XP) o referansa eşit kalır, sağlık/kalkan/hasar aşağıda ezilir.
	var base_stats: Dictionary = boss_base_stats(str(fixed.get("reward_ref", id)), tier)
	if enemy.has_method("apply_boss_stats"):
		enemy.apply_boss_stats(float(base_stats["health"]), float(base_stats["damage"]), BOSS_SCALE_MULT, tier)
	if enemy.has_method("enable_item_shield"):
		enemy.enable_item_shield(BOSS_SHIELD_PROTECTION, BOSS_SHIELD_RATIO)
	# Global güçlendirme - boss stats SONRASI uygulanır
	_apply_global_buff(enemy, player_count)
	if not fixed.is_empty():
		_apply_fixed_boss_stats(enemy, fixed)
	_attach_boss_bar(enemy)


## FIXED_BOSS_STATS satırını yaratığa uygular (ödüle dokunmaz). Oyuncu sayısı _apply_global_buff'ın yazdığı "mp_player_count" metasından gelir.
func _apply_fixed_boss_stats(enemy: Node, fixed: Dictionary) -> void:
	var extra_players: int = maxi(0, int(enemy.get_meta("mp_player_count", 1)) - 1)
	var defense_mult: float = 1.0 + float(extra_players) * EXTRA_PLAYER_DEFENSE_MULT
	enemy.max_health = float(fixed["health"]) * defense_mult
	enemy.health = enemy.max_health
	enemy.item_shield_max = float(fixed["shield"]) * defense_mult
	enemy.item_shield_hp = enemy.item_shield_max
	enemy.shield_protection = float(fixed["protection"])
	enemy.contact_damage = float(fixed["damage"])
	if enemy.ranged_damage > 0.0:
		enemy.ranged_damage = float(fixed["damage"])
	enemy.health_changed.emit(enemy.health, enemy.max_health)
	enemy.item_shield_changed.emit(enemy.item_shield_hp, enemy.item_shield_max)


## Host'ta (doğumda) ve istemcide (RPC) AYNI kurulum - bkz. enemy.gd make_elite.
func _apply_elite(enemy: Node) -> void:
	if enemy.has_method("make_elite"):
		enemy.make_elite()


## Bir roster kademesinin elit adayları: ELITE_POOL'dan, o kademenin roster'ındaki AİLELERE uyanlar. Hiçbiri uymazsa (Kademe 9 = sadece slime)
## komşu kademelerin ailelerine (+-1, +-2, ...) genişler; hâlâ boşsa tüm havuz. Saf işlev (testli).
static func elite_candidates(roster_tier: int) -> Array:
	for radius in range(0, 15):
		var families: Dictionary = {}
		for t in range(maxi(1, roster_tier - radius), mini(15, roster_tier + radius) + 1):
			for rid in TIER_ROSTER.get(t, []):
				families[ID_FAMILY.get(rid, "")] = true
		var out: Array = ELITE_POOL.filter(func(id: String) -> bool: return families.has(ID_FAMILY.get(id, "")))
		if not out.is_empty():
			return out
	return ELITE_POOL.duplicate()


## Elit olarak seçilen doğum hiç gerçekleşmediyse (sahne yüklenemedi vb.) vadeyi geri verir: o kademenin/katın eliti kaybolmasın.
func _unroll_elite(roster_tier: int) -> void:
	if _run_phase == RunPhase.ENDLESS:
		_endless_elite_spawned.erase(_endless_layer)
	else:
		_elite_spawned_tiers.erase(roster_tier)


## Bu sıradan doğum, kademesinin elit yaratığı mı? (host, _spawn_regular_enemy). Kademe başına en fazla 1 kez true.
func _roll_elite(tier: int) -> bool:
	if _elite_spawned_tiers.has(tier):
		return false
	var now: float = _tier_time()
	if not _elite_due_time.has(tier):
		var latest: float = float(tier) * tier_duration - ELITE_END_MARGIN
		_elite_due_time[tier] = minf(now + randf_range(ELITE_WINDOW_MIN, ELITE_WINDOW_MAX) * tier_duration, latest)
		if now < float(_elite_due_time[tier]):
			return false
	if now < float(_elite_due_time[tier]):
		return false
	_elite_spawned_tiers[tier] = true
	return true


## ==============================================================================
## ZAFER + SONSUZ MOD işlevleri (bkz. sınıf başındaki "ZAFER + SONSUZ MOD" bloğu). Hepsi host/tek oyunculu.
## ==============================================================================

## Yeni doğan yaratığın İSTATİSTİK kademesi: normalde roster kademesiyle aynı, sonsuzda 15 + kat.
func _scale_tier_for(roster_tier: int) -> int:
	if _run_phase == RunPhase.ENDLESS:
		return EndlessMathScript.scale_tier(_endless_layer)
	return roster_tier


## Normalde Kademe başına 1 elit (_roll_elite), sonsuzda KAT başına 1 elit.
func _roll_elite_for(roster_tier: int) -> bool:
	if _run_phase == RunPhase.ENDLESS:
		return _roll_endless_elite()
	return _roll_elite(roster_tier)


func _roll_endless_elite() -> bool:
	var layer: int = _endless_layer
	if _endless_elite_spawned.has(layer):
		return false
	var elapsed: float = GameManager.game_time - _endless_start_time
	if not _endless_elite_due.has(layer):
		_endless_elite_due[layer] = EndlessMathScript.layer_start_elapsed(layer, tier_duration) \
				+ randf_range(ELITE_WINDOW_MIN, ELITE_WINDOW_MAX) * tier_duration
	if elapsed < float(_endless_elite_due[layer]):
		return false
	_endless_elite_spawned[layer] = true
	return true


## Final'in doğan 13 bossunun HEPSİ öldüyse (ya da silindiyse) zafer. Final hiç doğmadıysa (_final_bosses boş) asla tetiklenmez.
func _check_victory() -> void:
	if _run_phase != RunPhase.NORMAL or not _final_spawned or _final_bosses.is_empty():
		return
	for boss in _final_bosses:
		if is_instance_valid(boss) and boss.get("is_dead") != true:
			return
	_begin_victory()


func _begin_victory() -> void:
	_run_phase = RunPhase.VICTORY
	NetworkManager.broadcast_victory.rpc(GameManager.game_time) ## herkeste zafer penceresi (main.gd)
	_rpc_victory_dissolve.rpc() ## kalan yaratıklar herkeste ödülsüz kaybolur


## Kalan yaratıkları HER peer kendi kopyasında dağıtır (ödül/öldürme yok, bkz. enemy.gd dismiss_without_reward).
@rpc("any_peer", "call_local", "reliable")
func _rpc_victory_dissolve() -> void:
	if not NetworkManager._from_host():
		return
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("dismiss_without_reward"):
			enemy.dismiss_without_reward()


## Host "Sonsuza Devam Et"e basınca (main.gd) çağrılır; zafer evresi dışında ya da istemcide etkisiz. true = başladı.
func begin_endless() -> bool:
	if _run_phase != RunPhase.VICTORY:
		return false
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return false
	_enter_endless()
	return true


## Boss/Final KAPALIYKEN (GameManager.bosses_enabled = false) zafer penceresi yoktur: Kademe saati 15. kademeyi bitirince (host) oyun
## doğrudan sonsuz modda devam eder (kullanıcı 2026-10-08: "Final ve zafer geçici kapansın"). Yaratık doğumu kesilmez (kapı/bekleme yok).
func _check_auto_endless() -> void:
	if _run_phase != RunPhase.NORMAL:
		return
	if _tier_time() < float(FINAL_TIER - 1) * tier_duration:
		return
	_enter_endless()


func _enter_endless() -> void:
	_run_phase = RunPhase.ENDLESS
	_endless_start_time = GameManager.game_time
	_endless_layer = 1
	_endless_bosses_spawned.clear()
	_endless_elite_due.clear()
	_endless_elite_spawned.clear()
	_spawn_timer = 0.0
	NetworkManager.broadcast_endless_started.rpc() ## herkeste pencere kapanır + Kat 1 bildirimi


## Kat saati: sonsuz moddan beri geçen oyun saati / tier_duration. Yeni kat herkese duyurulur.
func _process_endless() -> void:
	if _run_phase != RunPhase.ENDLESS:
		return
	var layer: int = EndlessMathScript.layer_for_elapsed(GameManager.game_time - _endless_start_time, tier_duration)
	if layer > _endless_layer:
		_endless_layer = layer
		NetworkManager.broadcast_endless_layer.rpc(layer)


## Boss katlarında (her 3 katta bir) katın %75'inde Final'in havuzundan rastgele bir alt küme doğar; kademe/ölçek o katınki.
## Spawn kapılarının İÇİNDE çağrılır (canlı bir oyuncu dışarıdaysa); doğmadıysa sonraki karede yeniden dener.
func _check_endless_boss_wave() -> void:
	if not GameManager.bosses_enabled:
		return
	if _run_phase != RunPhase.ENDLESS or _endless_bosses_spawned.has(_endless_layer):
		return
	if not EndlessMathScript.is_boss_wave_layer(_endless_layer):
		return
	var elapsed: float = GameManager.game_time - _endless_start_time
	if elapsed < EndlessMathScript.boss_trigger_elapsed(_endless_layer, tier_duration):
		return
	var ids: Array = EndlessMathScript.pick_wave_ids(FINAL_CREATURES, EndlessMathScript.boss_wave_size(_endless_layer))
	var spawned: Array = _spawn_boss_group(ids, EndlessMathScript.scale_tier(_endless_layer))
	if not spawned.is_empty():
		_endless_bosses_spawned[_endless_layer] = true


## Test/HUD için salt-okunur durum.
func get_run_phase() -> int:
	return _run_phase


func get_endless_layer() -> int:
	return _endless_layer


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
		NetworkManager.register_enemy_net_id(enemy, network_id) ## O(1) arama - bkz. NetworkManager._enemies_by_net_id
	## Kullanıcı isteği: "oyundan çıkmış biri ... oyundaki son haliyle oyuna
	## katılmalı" - sonradan katılan bir oyuncuya hâlâ hayatta olan
	## yaratıkları "yakalama" (catch-up) yayınıyla göstermek için (bkz.
	## _on_peer_needs_game_catchup) hangi tür olduğu burada saklanıyor.
	enemy.set_meta("creature_id", id)
	return enemy


## Debug menüsü (bkz. debug_menu.gd/scripts/game_manager.gd debug_mode_unlocked notu) -
## "istediğimiz yaratığı istediğimiz kadar spawnlama" isteği. _spawn_regular_enemy()'nin AYNI
## kurulum adımlarını (tier scaling/kalkan/global güçlendirme/istemcilere yayın) izler, tek
## fark rastgele rota/kademe yerine ELLE seçilen id/tier ve rastgele bir kademe anchor'ı yerine
## oyuncunun (ya da verilen konumun) etrafında doğması. Host-authoritative (bkz. enemy_spawner.gd
## dosya başı "sadece host" deseni) - bir İSTEMCİ bunu çağırırsa (çok oyunculu, host değilse)
## hiçbir şey olmaz, host'un kendi debug menüsünden çağırması gerekir.
func debug_spawn_creature(id: String, tier: int, count: int, around_pos: Vector2) -> int:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return 0
	if not SCENES.has(id):
		return 0
	var spawned := 0
	for i in range(max(1, count)):
		var angle: float = randf() * TAU
		var dist: float = randf_range(60.0, 220.0)
		var spawn_pos: Vector2 = around_pos + Vector2(cos(angle), sin(angle)) * dist
		var network_id: int = _next_network_enemy_id
		_next_network_enemy_id += 1
		var enemy = _spawn_creature(id, spawn_pos, network_id)
		if not enemy:
			continue
		if LIMB_IDS.has(id):
			## Debug: tek başına (bosssuz) uzuv - türü rastgele, kader = parçalanma.
			if NetworkManager.is_multiplayer_active:
				_announce_spawn(enemy, id, spawn_pos, tier, false, network_id, false, false)
			enemy.begin_limb(null, randi() % 2, 0, 14.0)
			spawned += 1
			continue
		if FIXED_BOSS_STATS.has(id):
			## Yeni bosslar (Minotaur...) debug menüsünden GERÇEK boss olarak doğar: sabit statlar, boss barı, hücumlar test edilebilsin.
			enemy.add_to_group("boss")
			_setup_boss_enemy(enemy, id, tier)
			if NetworkManager.is_multiplayer_active:
				_announce_spawn(enemy, id, spawn_pos, tier, true, network_id, true, false)
			spawned += 1
			continue
		enemy.set_meta("spawn_tier", tier)
		if enemy.has_method("apply_tier_scaling"):
			enemy.apply_tier_scaling(tier)
		_enable_regular_shield(enemy, tier)
		_apply_global_buff(enemy)
		if NetworkManager.is_multiplayer_active:
			_announce_spawn(enemy, id, spawn_pos, tier, false, network_id, false, false)
		spawned += 1
	return spawned


## "Alanı Güvenceye Al" görevi (bkz. world_event_manager.gd SECURE_WAVE_*): görev bölgesinde oyuncu
## varken bölgenin kenarından, O ANKİ kademenin rosterinden ek yaratık dalgası. Normal akış (yaratıklar
## oyuncunun çevresinde, kademe kapısıyla seyrek doğar) 3 dakikada 300 öldürmeye yetmiyordu. Host-only,
## _spawn_regular_enemy ile AYNI kurulum (kademe ölçekleme/kalkan/global güç/istemcilere yayın) ve
## AYNI yaratık tavanı - tavan doluysa bu dalga da doğmaz.
func spawn_mission_wave(center: Vector2, ring_radius: float, count: int) -> int:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return 0
	if _run_phase == RunPhase.VICTORY: ## zafer penceresi açıkken yaratık yok (bkz. ZAFER + SONSUZ MOD bloğu)
		return 0
	var tier: int = max(1, _current_tier())
	var roster: Array = _spawnable_roster(tier)
	if roster.is_empty():
		return 0
	var scale_tier: int = _scale_tier_for(tier) ## sonsuzda görev dalgası da o katın ölçeğinde
	var spawned := 0
	for i in range(count):
		if get_tree().get_nodes_in_group("enemies").size() >= _scaled_enemy_cap():
			break
		var id: String = roster[randi() % roster.size()]
		var angle: float = randf() * TAU
		var spawn_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * ring_radius
		if GameManager.is_position_blocked_by_terrain(spawn_pos):
			continue
		var network_id: int = _next_network_enemy_id
		_next_network_enemy_id += 1
		var enemy = _spawn_creature(id, spawn_pos, network_id)
		if not enemy:
			continue
		enemy.set_meta("spawn_tier", tier)
		if enemy.has_method("apply_tier_scaling"):
			enemy.apply_tier_scaling(scale_tier)
		_enable_regular_shield(enemy, tier)
		_apply_global_buff(enemy)
		if NetworkManager.is_multiplayer_active:
			_announce_spawn(enemy, id, spawn_pos, scale_tier, false, network_id, false, false)
		spawned += 1
	return spawned


## Debug menüsündeki yaratık seçici listesi için - SCENES'in kendisi (const preload'lu Dictionary)
## dışarıdan doğrudan da okunabilir ama isimlendirilmiş bir erişim daha temiz.
func get_debug_creature_ids() -> Array:
	return SCENES.keys()


var _sync_enemy_map: Dictionary = {}
var _sync_enemy_map_frame: int = -1


@rpc("any_peer", "call_remote", "unreliable")
func _sync_enemy_positions(tick: int, data: PackedByteArray) -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	## Sadece host'tan gelen düşman konumu senkronizasyonu kabul edilir.
	if sender_id != 0 and sender_id != NetworkManager._host_peer_id():
		return
	## Güvenilmez kanalda paketler sırasız gelebilir: eski turun paketi yeni konumun üstüne yazılıp yaratığı geri sıçratmasın.
	if EnemySyncCodecScript.is_stale(tick, _enemy_sync_last_tick):
		return
	var tick_diff: int = (tick - _enemy_sync_last_tick) & 0xFFFF
	if _enemy_sync_last_tick < 0 or (tick_diff > 0 and tick_diff <= 0x8000):
		_enemy_sync_last_tick = tick
	var enemy_states: Array = EnemySyncCodecScript.decode(data)["states"]
	
	# Hızlı erişim için mevcut düşmanları bir dictionary'ye indeksle - durum artık küçük paketler halinde geldiği için
	# (bkz. ENEMY_SYNC_BATCH) aynı karede gelen paketler bu indeksi paylaşır.
	var frame: int = Engine.get_process_frames()
	if frame != _sync_enemy_map_frame:
		_sync_enemy_map_frame = frame
		_sync_enemy_map.clear()
		for enemy: Node in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				var nid: int = int(enemy.get_meta("network_enemy_id", 0))
				if nid > 0:
					_sync_enemy_map[nid] = enemy
	var enemy_map: Dictionary = _sync_enemy_map

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
const EXTRA_PLAYER_DEFENSE_MULT := 0.50

## Yaratık yetenekleri (kullanıcı isteği 2026-09-24) - statla çözülen aile özellikleri (bosslar dahil, çünkü tüm spawn
## yolları _apply_global_buff'tan geçer):
##  - golem: "çok dayanıklıdır fakat biraz yavaştır (kalkan ve can oranları %30 arttır, hızlarını %20 azalt)"
##  - zombie: "zombilerin canı %30 daha fazla olsun" (sadece can; ölüm asidi enemy.gd die()'da)
##  - rat (2026-09-26): "oyundaki farelerin canını ve kalkanını %30 azalt" -> aynı gün "%30 azaltmayı %50 yapalım" (x0.5;
##    rat1/2/3, normal + boss, host + client)
const FAMILY_TRAITS := {
	"golem": {"health": 1.3, "shield": 1.3, "speed": 0.8},
	"zombie": {"health": 1.3},
	"rat": {"health": 0.5, "shield": 0.5},
}

## player_count: İSTEMCİ doğuşunda host'un o an kullandığı oyuncu sayısı (RPC ile gelir - istemci kendi lobi listesinden saymaz, listeler
## ayrışabilir ve hayalet yabancılar sayıyı şişirirdi); 0 = kendin hesapla (host / tekli). Host sayıyı yaratığa yazar (catch-up için).
func _apply_global_buff(enemy: Node, player_count: int = 0) -> void:
	var counted_players: int = player_count if player_count > 0 else _player_count()
	enemy.set_meta("mp_player_count", counted_players)
	var extra_players: int = max(0, counted_players - 1)
	## Kullanıcı isteği (2026-09-24 denge turu): ekstra oyuncu başına can/kalkan +%30 -> +%50 (her kademede).
	var multiplayer_defense_mult: float = 1.0 + float(extra_players) * EXTRA_PLAYER_DEFENSE_MULT
	var health_shield_mult: float = BOSS_HEALTH_SHIELD_MULT if enemy.is_boss else HEALTH_SHIELD_MULT
	var boss_cut: float = BOSS_CUT_2026_09_25B if enemy.is_boss else 1.0
	var enemy_tier: int = int(enemy.get("_current_tier")) if "_current_tier" in enemy else 0
	var early_cut: float = early_durability_cut(enemy_tier) if (not enemy.is_boss and enemy_tier >= 1) else 1.0
	var dmg_taper: float = tier_damage_mult(enemy_tier, bool(enemy.is_boss))
	var late_cut: float = late_durability_mult(enemy_tier)
	## Aile özellikleri (bkz. FAMILY_TRAITS) - kalkan çarpanı candan AYRI tutulur (zombide sadece can artar).
	var fam_trait: Dictionary = FAMILY_TRAITS.get(Enemy.family_of_id(str(enemy.get_meta("creature_id", ""))), {})
	var trait_health: float = float(fam_trait.get("health", 1.0))
	var trait_shield: float = float(fam_trait.get("shield", 1.0))
	enemy.speed *= float(fam_trait.get("speed", 1.0))
	enemy.max_health *= GLOBAL_DEFENSE_BUFF * multiplayer_defense_mult * health_shield_mult * trait_health * boss_cut * DURABILITY_CUT_2026_09_26 * early_cut * late_cut
	enemy.health = enemy.max_health
	enemy.contact_damage *= GLOBAL_DAMAGE_BUFF * boss_cut * dmg_taper
	if enemy.ranged_damage > 0.0:
		enemy.ranged_damage *= GLOBAL_DAMAGE_BUFF * boss_cut * dmg_taper
	# Kalkan zaten max_health * shield_ratio ile hesaplandı; oranı bozmamak
	# için item_shield_max ve item_shield_hp'yi de aynı (savunma) çarpanla
	# büyütüyoruz.
	if enemy.item_shield_max > 0.0:
		## Kalkan zaten (trait'siz) candan türetilmişti: GLOBAL çarpanlar + ailenin KENDİ kalkan çarpanı.
		enemy.item_shield_max *= GLOBAL_DEFENSE_BUFF * multiplayer_defense_mult * health_shield_mult * trait_shield * boss_cut * DURABILITY_CUT_2026_09_26 * early_cut * late_cut
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
		## bkz. DURABILITY_CUT_2026_09_25: ödül, 2026-09-25 can kesintisinden önceki can üzerinden (ödüller değişmesin).
		var reward_health: float = enemy.max_health / DURABILITY_CUT_2026_09_25 / BOSS_CUT_2026_09_25B / DURABILITY_CUT_2026_09_26
		reward_health /= boss_health_pacing(enemy_tier) ## BOSS_PACING can çarpanı ödülü düşürmesin (ödüller değişmez)
		reward_health /= late_cut ## Kademe 3+ can düşüşü de ödülü düşürmesin
		enemy.xp_value = round(reward_health * Enemy.BOSS_XP_HEALTH_RATIO)
		enemy.gold_min = max(1, int(reward_health * Enemy.BOSS_GOLD_MIN_HEALTH_RATIO))
		enemy.gold_max = max(enemy.gold_min + 1, int(reward_health * Enemy.BOSS_GOLD_MAX_HEALTH_RATIO))
		enemy.gold_chance = 1.0
